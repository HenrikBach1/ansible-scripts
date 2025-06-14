#!/bin/bash
# Script to restart the ROS2 container with proper persistence (Podman version)
# This addresses the issue where the container exits immediately

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-ros2-workspace-container}"
echo -e "${YELLOW}Restarting ROS2 Podman Container: $CONTAINER_NAME${NC}"

# Check if the container exists
if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Error: Container '$CONTAINER_NAME' does not exist.${NC}"
    echo "Please run ./start-ros2-podman-container.sh first to create the container."
    exit 1
fi

# Get the container's image
IMAGE_NAME=$(podman inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
echo "Container image: $IMAGE_NAME"

# Get the ROS2 distribution
ROS2_DISTRO=$(podman exec $CONTAINER_NAME bash -c "printenv | grep ROS_DISTRO" 2>/dev/null | cut -d= -f2 || echo "")
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
WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
if [ -z "$WORKSPACE_DIR" ]; then
    # Try other mount points
    WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/projects"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    if [ -z "$WORKSPACE_DIR" ]; then
        WORKSPACE_DIR=$(podman inspect --format='{{range .Mounts}}{{if eq .Destination "/home/ubuntu/ros2_ws"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")
    fi
fi

if [ -z "$WORKSPACE_DIR" ]; then
    echo -e "${RED}Error: Could not determine workspace directory.${NC}"
    echo "Please specify the workspace directory:"
    read -p "Workspace directory: " WORKSPACE_DIR
    if [ ! -d "$WORKSPACE_DIR" ]; then
        echo -e "${RED}Error: Directory $WORKSPACE_DIR does not exist.${NC}"
        exit 1
    fi
fi

echo "Workspace directory: $WORKSPACE_DIR"

# Stop the container if it's running
echo -e "${YELLOW}Stopping container...${NC}"
podman stop "$CONTAINER_NAME" 2>/dev/null || true
sleep 2

# Remove the container
echo -e "${YELLOW}Removing old container...${NC}"
podman rm "$CONTAINER_NAME" 2>/dev/null || true
sleep 1

# Recreate the container with proper settings for persistence
echo -e "${YELLOW}Creating new container...${NC}"

# Create the container with a command that keeps it running
podman create \
    --name "$CONTAINER_NAME" \
    --workdir /workspace \
    -v "$WORKSPACE_DIR":/workspace:Z \
    --env ROS_DISTRO="$ROS2_DISTRO" \
    --env LANG=en_US.UTF-8 \
    --env LC_ALL=en_US.UTF-8 \
    --env ROS_DOMAIN_ID=42 \
    --interactive \
    --tty \
    "$IMAGE_NAME" \
    bash -c "
    # Set up ROS2 environment
    source /opt/ros/$ROS2_DISTRO/setup.bash 2>/dev/null || true
    
    # Create a persistent process to keep container alive
    while true; do
        # Check for stop/detach requests
        if [ -f /workspace/.container_stop_requested ] || [ -f /tmp/.container_stop_requested ]; then
            echo 'Stop requested, exiting...'
            rm -f /workspace/.container_stop_requested /tmp/.container_stop_requested 2>/dev/null || true
            exit 0
        fi
        
        if [ -f /workspace/.container_detach_requested ] || [ -f /tmp/.container_detach_requested ]; then
            echo 'Detach requested, continuing in background...'
            rm -f /workspace/.container_detach_requested /tmp/.container_detach_requested 2>/dev/null || true
        fi
        
        sleep 10
    done &
    
    # Wait for any interactive sessions
    wait
    "

# Start the container
echo -e "${YELLOW}Starting container...${NC}"
podman start "$CONTAINER_NAME"

# Wait a moment for the container to start
sleep 2

# Verify the container is running
if podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${GREEN}✓ Container '$CONTAINER_NAME' restarted successfully!${NC}"
    
    # Install container commands
    if [ -f "$(dirname "$0")/container-command-common.sh" ]; then
        echo "Installing container commands..."
        source "$(dirname "$0")/container-command-common.sh"
        install_container_commands_podman "$CONTAINER_NAME" "ros2" true
    fi
    
    echo ""
    echo "Container Status:"
    podman ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Next steps:"
    echo "  - Connect: ./ros2-podman-connect $CONTAINER_NAME"
    echo "  - Or use:  ./podman-exec-it $CONTAINER_NAME bash"
    echo "  - Build:   podman exec $CONTAINER_NAME bash -c 'cd /workspace && source /opt/ros/$ROS2_DISTRO/setup.bash && colcon build'"
else
    echo -e "${RED}✗ Failed to start container '$CONTAINER_NAME'${NC}"
    echo "Container logs:"
    podman logs "$CONTAINER_NAME" --tail 20
    exit 1
fi
