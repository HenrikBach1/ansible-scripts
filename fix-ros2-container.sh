#!/bin/bash
# Fix script for ROS2 container issues
# This script addresses common problems and ensures the container is properly configured

# Default container name
CONTAINER_NAME="ros2_container"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Fix common ROS2 container issues"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME        Container name (default: ros2_container)"
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

echo "Fixing container: $CONTAINER_NAME"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container '$CONTAINER_NAME' does not exist."
    echo "Creating a new container..."
    ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
    exit $?
fi

# Check container status
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
echo "Current container status: $CONTAINER_STATUS"

# If the container is in an inconsistent state, recreate it
if [ "$CONTAINER_STATUS" = "running" ]; then
    echo "Container is running. Checking if it's stable..."
    
    # Check if the container has the ROS setup
    if ! docker exec "$CONTAINER_NAME" bash -c "test -f /opt/ros/jazzy/setup.bash" 2>/dev/null; then
        echo "Container appears to be in an inconsistent state."
        echo "Recreating the container..."
        ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
        exit $?
    fi
    
    echo "Container appears to be healthy."
else
    echo "Container is not running. Recreating it from scratch..."
    ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
    exit $?
fi

# Fix workspace directory and permissions
echo "Fixing workspace directory..."
if ! docker exec "$CONTAINER_NAME" bash -c "mkdir -p /workspace && chmod 777 /workspace && mkdir -p /home/ubuntu/ros2_ws" 2>/dev/null; then
    echo "Failed to fix workspace directory. Container might be in a bad state."
    echo "Recreating the container..."
    ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
    exit $?
fi

# Create a simple keep-alive script
KEEP_ALIVE_SCRIPT=$(cat << 'EOF'
#!/bin/bash
# Resilient keep-alive script
while true; do
    sleep 60
done
EOF
)

# Ensure keep-alive processes are running
echo "Ensuring keep-alive processes are running..."
if ! docker exec "$CONTAINER_NAME" bash -c "echo '$KEEP_ALIVE_SCRIPT' > /home/ubuntu/keep_container_alive.sh && chmod +x /home/ubuntu/keep_container_alive.sh && nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 & nohup bash -c 'while true; do sleep 3600; done' >/dev/null 2>&1 & touch /home/ubuntu/.container_detach_requested" 2>/dev/null; then
    echo "Failed to start keep-alive processes. Container might be in a bad state."
    echo "Recreating the container..."
    ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
    exit $?
fi

# Check if container is still running
if docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container is running properly."
    
    # Start the container watcher
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/container-watch.sh" ]; then
        echo "Starting container watcher..."
        bash "$SCRIPT_DIR/container-watch.sh" "$CONTAINER_NAME" &
    fi
    
    echo "Container '$CONTAINER_NAME' has been fixed and is ready to use."
    echo ""
    echo "To connect from VS Code:"
    echo "1. Click on the Remote Explorer icon in the sidebar"
    echo "2. Find the container under 'Containers'"
    echo "3. Right-click on '$CONTAINER_NAME' and select 'Attach to Container'"
else
    echo "Container failed to stay running. Complete recreation is needed."
    echo "Running: ./recreate-ros2-container.sh --name $CONTAINER_NAME"
    ./recreate-ros2-container.sh --name "$CONTAINER_NAME"
fi

exit 0
