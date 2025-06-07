#!/bin/bash
# Script to specifically fix ROS2 containers
# This script recreates a ROS2 container with proper volume mounts while preserving settings

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get the container name from arguments or use default
if [ $# -gt 0 ]; then
    CONTAINER_NAME="$1"
else
    CONTAINER_NAME="ros2_container"
fi

echo -e "${YELLOW}ROS2 Container Fix Utility${NC}"
echo "This script will fix the volume mounts for container: $CONTAINER_NAME"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Error: Container '$CONTAINER_NAME' does not exist.${NC}"
    exit 1
fi

# Get ROS2 distribution
ROS2_DISTRO=$(docker exec $CONTAINER_NAME bash -c "printenv | grep ROS_DISTRO" 2>/dev/null | cut -d= -f2 || echo "jazzy")
if [ -z "$ROS2_DISTRO" ]; then
    ROS2_DISTRO="jazzy"
fi
echo "Detected ROS2 distribution: $ROS2_DISTRO"

# Get the workspace directory
WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
if [ -z "$WORKSPACE_DIR" ]; then
    # Try other mount points
    WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/home/ubuntu/ros2_ws"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    if [ -z "$WORKSPACE_DIR" ]; then
        # Fallback to projects
        WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/projects"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
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

# Create a new container with all the required mounts
echo "Creating new container with proper volume mounts..."
IMAGE_NAME="osrf/ros:${ROS2_DISTRO}-desktop"
echo "Using image: $IMAGE_NAME"

# Run command with proper escaping
docker run -d --privileged --network=host \
    --name "$CONTAINER_NAME" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v "$WORKSPACE_DIR:/home/ubuntu/ros2_ws" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    -e ROS_DOMAIN_ID=0 \
    "$IMAGE_NAME" \
    bash -c "source /opt/ros/${ROS2_DISTRO}/setup.bash && mkdir -p /workspace /projects && chmod 777 /workspace /projects && echo 'Container is running with proper volume mounts' && sleep infinity"

# Check if container was created successfully
if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Failed to create container.${NC}"
    exit 1
fi

echo -e "${GREEN}Container has been recreated with proper volume mounts.${NC}"
echo "Verify the container mounts:"
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}' "$CONTAINER_NAME"

echo ""
echo -e "${GREEN}Success!${NC} You should now be able to attach to this container from VS Code."
echo "To connect to the container:"
echo "1. Open VS Code"
echo "2. Click on the Remote Explorer icon in the sidebar"
echo "3. Find and attach to the container '$CONTAINER_NAME'"

# Recommend cleanup
echo ""
echo "If you have any temporary images left over from previous fix attempts,"
echo "you can clean them up by running: ./cleanup-container-images.sh"
