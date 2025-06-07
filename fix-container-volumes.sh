#!/bin/bash
# Script to fix the volume mounts in existing containers
# This ensures the /projects directory is available in the container

# Get the container name from arguments or use default
if [ $# -gt 0 ]; then
    CONTAINER_NAME="$1"
else
    echo "Usage: $0 <container_name>"
    echo "This script fixes the volume mounts in existing containers to ensure /projects is available."
    exit 1
fi

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container '$CONTAINER_NAME' does not exist."
    exit 1
fi

# Get the container's status before we start
ORIGINAL_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
echo "Original container status: $ORIGINAL_STATUS"

# Check if container is running
if [ "$ORIGINAL_STATUS" != "running" ]; then
    echo "Container is not running. Starting it..."
    docker start "$CONTAINER_NAME"
    
    if [ $? -ne 0 ]; then
        echo "Failed to start container. It might be in a bad state."
        exit 1
    fi
    
    sleep 2
fi

echo "Fixing volume mounts for container: $CONTAINER_NAME"

# Create the /projects directory and ensure it has the right permissions
echo "Creating /projects directory in container..."
if ! docker exec "$CONTAINER_NAME" bash -c "mkdir -p /projects && chmod 777 /projects" 2>/dev/null; then
    echo "Failed to create /projects directory."
    exit 1
fi

# Get the source directory for the /workspace mount
WORKSPACE_SRC=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")

if [ -z "$WORKSPACE_SRC" ]; then
    # Try to find an alternative mount point if /workspace doesn't exist
    WORKSPACE_SRC=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workdir"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    
    if [ -z "$WORKSPACE_SRC" ]; then
        WORKSPACE_SRC=$(docker inspect --format='{{range .Mounts}}{{if or (eq .Destination "/home/ubuntu/ros2_ws") (eq .Destination "/home/ubuntu/yocto_ws")}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    fi
fi

if [ -z "$WORKSPACE_SRC" ]; then
    echo "Could not determine the source directory for workspace mounts."
    echo "You may need to recreate the container with the updated scripts."
    exit 1
fi

echo "Found workspace source directory: $WORKSPACE_SRC"

# Get the container's image name
IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
echo "Container image: $IMAGE_NAME"

# If the image name is a temporary image, try to find the original image
if [[ "$IMAGE_NAME" == temp_*_image ]]; then
    echo "Detected temporary image. This may be from a previous fix attempt."
    echo "Attempting to find original image..."
    
    # Try to find the original image based on container type
    if [[ "$CONTAINER_NAME" == *ros2* ]]; then
        # Look for ROS2 distro
        ROS2_DISTRO=$(docker exec $CONTAINER_NAME bash -c "printenv | grep ROS_DISTRO" 2>/dev/null | cut -d= -f2 || echo "jazzy")
        if [ -z "$ROS2_DISTRO" ]; then
            ROS2_DISTRO="jazzy"
        fi
        echo "Detected ROS2 distribution: $ROS2_DISTRO"
        IMAGE_NAME="osrf/ros:${ROS2_DISTRO}-desktop"
        echo "Using ROS2 image: $IMAGE_NAME"
    elif [[ "$CONTAINER_NAME" == *yocto* ]]; then
        # Default to ubuntu-22.04 for Yocto
        IMAGE_NAME="crops/poky:ubuntu-22.04"
        echo "Using Yocto image: $IMAGE_NAME"
    else
        echo "Warning: Could not determine original image. Using current image: $IMAGE_NAME"
    fi
fi

# Get all the existing mounts
MOUNTS=""
docker inspect "$CONTAINER_NAME" | grep -A 20 "\"Mounts\":" | grep "Source" | while read line; do
    SRC=$(echo "$line" | sed 's/.*"Source": "\(.*\)",/\1/')
    DST=$(grep -A 1 "\"Source\": \"$SRC\"" <(docker inspect "$CONTAINER_NAME") | grep "Destination" | sed 's/.*"Destination": "\(.*\)",/\1/')
    
    # Skip if destination is /projects
    if [ "$DST" == "/projects" ]; then
        continue
    fi
    
    MOUNTS+=" -v $SRC:$DST"
done

# Get the command used to run the container
CMD=$(docker inspect --format='{{range .Config.Cmd}}{{.}} {{end}}' "$CONTAINER_NAME")
echo "Container command: $CMD"

# Get all environment variables
ENV_VARS=""
docker inspect --format='{{range .Config.Env}}{{.}} {{end}}' "$CONTAINER_NAME" | tr ' ' '\n' | while read env_var; do
    if [ -n "$env_var" ]; then
        ENV_VARS+=" -e $env_var"
    fi
done

# Check for privileged mode
PRIVILEGED=""
if docker inspect --format='{{.HostConfig.Privileged}}' "$CONTAINER_NAME" | grep -q "true"; then
    PRIVILEGED="--privileged"
fi

# Check for network mode
NETWORK_MODE="--network=$(docker inspect --format='{{.HostConfig.NetworkMode}}' "$CONTAINER_NAME")"

# Simple approach: use docker run with the exact same image and add the projects mount
echo "Creating a bind mount for /projects using source: $WORKSPACE_SRC"

# Stop the container
docker stop "$CONTAINER_NAME"

# Remove the container
docker rm "$CONTAINER_NAME"

# Create a new container with the same settings plus the /projects mount
echo "Recreating container with /projects mount..."
docker run -d $PRIVILEGED $NETWORK_MODE \
    --name "$CONTAINER_NAME" \
    -v "$WORKSPACE_SRC:/projects" \
    -v "$WORKSPACE_SRC:/workspace" \
    -v "$WORKSPACE_SRC:/home/ubuntu/ros2_ws" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    "$IMAGE_NAME" bash -c "mkdir -p /projects && chmod 777 /projects && exec $CMD"

# Check if container was created successfully
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Failed to recreate container."
    exit 1
fi

# If the original container was running, make sure the new one is too
if [ "$ORIGINAL_STATUS" == "running" ]; then
    if [ "$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")" != "running" ]; then
        echo "Starting container..."
        docker start "$CONTAINER_NAME"
    fi
fi

echo "Container has been recreated with the /projects mount."
echo "Verify the container is running and has the correct mounts:"
docker ps | grep "$CONTAINER_NAME"
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}' "$CONTAINER_NAME"

# Suggest using robust container scripts if needed
echo ""
echo "If the container still has issues, consider recreating it with the robust container scripts:"
echo "./robust-ros2-container.sh --name $CONTAINER_NAME --workspace $WORKSPACE_SRC"
echo "or"
echo "./robust-yocto-container.sh --name $CONTAINER_NAME --workspace $WORKSPACE_SRC"
