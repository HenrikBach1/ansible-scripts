#!/bin/bash
# Direct ROS2 container fix script - no dependencies on other scripts
# This script directly creates a properly configured ROS2 container

# Default values
CONTAINER_NAME="ros2_container"
IMAGE_NAME="osrf/ros:jazzy-desktop"
WORKSPACE_DIR="$HOME/projects"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -w|--workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Create a robust ROS2 container that stays running"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME        Container name (default: ros2_container)"
            echo "  -w, --workspace DIR    Host workspace directory (default: $HOME/projects)"
            echo "  -h, --help             Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

echo "Creating robust ROS2 container: $CONTAINER_NAME"
echo "Using workspace directory: $WORKSPACE_DIR"

# Create workspace directory if it doesn't exist
mkdir -p "$WORKSPACE_DIR"

# Check if container exists and remove it
if docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container exists, removing it..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Create the keep-alive script
KEEP_ALIVE_SCRIPT='#!/bin/bash
# Keep container alive
while true; do
    sleep 60
done
'

# Create the container with a proper entrypoint
echo "Creating new container..."
docker run -d --privileged --network=host \
    -v "$WORKSPACE_DIR:/home/ubuntu/ros2_ws" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" \
    bash -c "source /opt/ros/jazzy/setup.bash && mkdir -p /workspace && echo '$KEEP_ALIVE_SCRIPT' > /home/ubuntu/keep_alive.sh && chmod +x /home/ubuntu/keep_alive.sh && nohup /home/ubuntu/keep_alive.sh >/dev/null 2>&1 & echo 'Container is running with keep-alive process' && sleep infinity"

# Check if container started
if docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container is running properly."
    echo ""
    echo "To connect from VS Code:"
    echo "1. Click on the Remote Explorer icon in the sidebar"
    echo "2. Find the container under 'Containers'"
    echo "3. Right-click on '$CONTAINER_NAME' and select 'Attach to Container'"
    echo ""
    echo "To attach manually, run: docker exec -it $CONTAINER_NAME bash"
else
    echo "Container failed to start properly. Check Docker logs."
    docker logs "$CONTAINER_NAME"
    exit 1
fi

exit 0
