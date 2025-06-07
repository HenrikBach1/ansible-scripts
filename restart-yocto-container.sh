#!/bin/bash
# Script to restart the Yocto container with proper persistence
# This addresses the issue where the container exits immediately

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-yocto_container}"
echo -e "${YELLOW}Restarting Yocto Container: $CONTAINER_NAME${NC}"

# Check if the container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Error: Container '$CONTAINER_NAME' does not exist.${NC}"
    echo "Please run ./run-yocto-container.sh first to create the container."
    exit 1
fi

# Get the container's image
IMAGE_NAME=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
echo "Container image: $IMAGE_NAME"

# Extract the base version from the image name
BASE_VERSION=$(echo "$IMAGE_NAME" | sed -n 's/.*crops\/poky:\(.*\)/\1/p')
if [ -z "$BASE_VERSION" ]; then
    BASE_VERSION="ubuntu-22.04"  # Default to ubuntu-22.04 if we can't determine
fi
echo "Yocto base version: $BASE_VERSION"

# Get the workspace directory
WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workdir"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
if [ -z "$WORKSPACE_DIR" ]; then
    # Try other mount points
    WORKSPACE_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    if [ -z "$WORKSPACE_DIR" ]; then
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

# Create a new container with better persistence
echo "Creating new container with proper persistence..."
docker run -d --privileged --network=host \
    --name "$CONTAINER_NAME" \
    -v "$WORKSPACE_DIR:/workdir" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v "$WORKSPACE_DIR:/home/ubuntu/yocto_ws" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$(realpath "$(dirname "$0")/run-yocto-container-entrypoint.sh"):/home/ubuntu/entrypoint.sh" \
    -e DISPLAY \
    -e TEMPLATECONF=/workdir/meta-custom/conf/templates/default \
    "crops/poky:$BASE_VERSION" \
    bash -c "chmod +x /home/ubuntu/entrypoint.sh && /home/ubuntu/entrypoint.sh $BASE_VERSION bash"

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

echo ""
echo "To start working with Yocto in the container:"
echo "1. Clone Poky: git clone -b <branch-name> git://git.yoctoproject.org/poky"
echo "2. Initialize build environment: source poky/oe-init-build-env"
echo "3. Start a build: bitbake core-image-minimal"
