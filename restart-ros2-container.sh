#!/bin/bash
# Script to restart the ROS2 container with proper persistence
# This addresses the issue where the container exits immediately

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-ros2_container}"
echo -e "${YELLOW}Restarting ROS2 Container: $CONTAINER_NAME${NC}"

# Check if the container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Error: Container '$CONTAINER_NAME' does not exist.${NC}"
    echo "Please run ./run-ros2-container.sh first to create the container."
    exit 1
fi

# Get the container's image
IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
echo "Container image: $IMAGE_NAME"

# Get the ROS2 distribution
ROS2_DISTRO=$(docker exec $CONTAINER_NAME bash -c "printenv | grep ROS_DISTRO" 2>/dev/null | cut -d= -f2 || echo "")
if [ -z "$ROS2_DISTRO" ]; then
    # If we can't get it from the container, try to extract from the image name
    if [[ "$IMAGE_NAME" =~ :([a-z]+)- ]]; then
        ROS2_DISTRO="${BASH_REMATCH[1]}"
    else
        ROS2_DISTRO="jazzy"  # Default to jazzy if we can't determine
    fi
fi
echo "ROS2 distribution: $ROS2_DISTRO"

# Get the workspace directory
WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
if [ -z "$WORKSPACE_DIR" ]; then
    # Try other mount points
    WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/projects"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    if [ -z "$WORKSPACE_DIR" ]; then
        WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/home/ubuntu/ros2_ws"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    fi
fi

if [ -z "$WORKSPACE_DIR" ]; then
    echo -e "${RED}Error: Could not determine workspace directory.${NC}"
    echo "Please specify the workspace directory:"
    read -p "Workspace directory: " WORKSPACE_DIR
    if [ -z "$WORKSPACE_DIR" ]; then
        echo -e "${RED}No workspace directory provided. Exiting.${NC}"
        exit 1
    fi
fi
echo "Using workspace directory: $WORKSPACE_DIR"

# Stop and remove the container
echo "Stopping and removing the container..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1
docker rm "$CONTAINER_NAME" >/dev/null 2>&1

# Create a new container with better persistence
echo "Creating new container with proper persistence..."
docker run -d --privileged --network=host \
    --name "$CONTAINER_NAME" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v "$WORKSPACE_DIR:/home/ubuntu/ros2_ws" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$(realpath "$(dirname "$0")/run-ros2-container-entrypoint.sh"):/home/ubuntu/entrypoint.sh" \
    -e DISPLAY \
    -e ROS_DOMAIN_ID=0 \
    "osrf/ros:$ROS2_DISTRO-desktop" \
    bash -c "chmod +x /home/ubuntu/entrypoint.sh && /home/ubuntu/entrypoint.sh $ROS2_DISTRO bash"

# Check if container was created successfully
if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Failed to create container.${NC}"
    exit 1
fi

echo -e "${GREEN}Container has been recreated and is running properly.${NC}"
echo "To attach to the container: docker attach $CONTAINER_NAME"
echo "Or connect using VS Code Remote Explorer."

# Start the container watcher
if [ -f "$(dirname "$0")/container-watch.sh" ]; then
    echo "Starting container watcher for $CONTAINER_NAME..."
    bash "$(dirname "$0")/container-watch.sh" "$CONTAINER_NAME" &
fi
