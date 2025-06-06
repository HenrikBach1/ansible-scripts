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

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
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

# Create a bind mount for /projects using the same source as /workspace
echo "Creating bind mount for /projects using source: $WORKSPACE_SRC"

# Stop the container temporarily
docker stop "$CONTAINER_NAME"

# Commit the current container to a temporary image
TEMP_IMAGE="temp_${CONTAINER_NAME}_image"
docker commit "$CONTAINER_NAME" "$TEMP_IMAGE"

# Remove the old container
docker rm "$CONTAINER_NAME"

# Create a new container with the same configuration plus the /projects mount
# Get the existing command
CMD=$(docker inspect --format='{{.Config.Cmd}}' "$TEMP_IMAGE" | sed 's/^\[//;s/\]$//;s/\"//g')

# Run a new container with the same name but with the additional mount
docker run -d --privileged --network=host \
    --name "$CONTAINER_NAME" \
    $(docker inspect --format='{{range .Config.Env}}--env {{.}} {{end}}' "$TEMP_IMAGE") \
    $(docker inspect --format='{{range $k, $v := .HostConfig.PortBindings}}{{range $v}}--publish {{.HostPort}}:{{$k}} {{end}}{{end}}' "$TEMP_IMAGE") \
    $(docker inspect --format='{{range .Mounts}}{{if ne .Destination "/projects"}}--volume {{.Source}}:{{.Destination}} {{end}}{{end}}' "$TEMP_IMAGE") \
    --volume "$WORKSPACE_SRC:/projects" \
    "$TEMP_IMAGE" $CMD

# Clean up temporary image
docker rmi "$TEMP_IMAGE"

echo "Container has been recreated with the /projects mount."
echo "Verify the container is running and has the correct mounts:"
docker ps | grep "$CONTAINER_NAME"
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}' "$CONTAINER_NAME"
