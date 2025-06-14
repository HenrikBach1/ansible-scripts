#!/bin/bash
# Restart Yocto Podman container script
# This addresses the issue where the container exits immediately

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-yocto_container_podman}"
echo -e "${YELLOW}Restarting Yocto Podman Container: $CONTAINER_NAME${NC}"

# Check if the container exists
if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Error: Container '$CONTAINER_NAME' does not exist.${NC}"
    echo "Please run ./start-yocto-container-podman.sh first to create the container."
    exit 1
fi

# Get the container's image
IMAGE_NAME=$(podman inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
echo "Container image: $IMAGE_NAME"

# Get the workspace directory
WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/workdir"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
if [ -z "$WORKSPACE_DIR" ]; then
    # Try other mount points
    WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    if [ -z "$WORKSPACE_DIR" ]; then
        WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/projects"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
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
podman stop "$CONTAINER_NAME" >/dev/null 2>&1
podman rm "$CONTAINER_NAME" >/dev/null 2>&1

# Recreate with the original startup script
echo "Recreating container with original startup script..."
"$(dirname "$0")/start-yocto-container-podman.sh" --name "$CONTAINER_NAME" --workspace "$WORKSPACE_DIR"

# Check if container was created successfully
if ! podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Failed to recreate container.${NC}"
    exit 1
fi

echo -e "${GREEN}Container has been recreated and is running properly.${NC}"
echo "To connect to the container: ./yocto-podman-connect $CONTAINER_NAME"
echo "Or connect using: podman exec -it $CONTAINER_NAME bash"
