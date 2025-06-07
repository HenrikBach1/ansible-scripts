#!/bin/bash
# Helper script to recreate the ROS2 container from scratch
# This is useful when the container is in a broken state and can't be restarted

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
            echo "Recreate a ROS2 container from scratch"
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

echo "Recreating ROS2 container: $CONTAINER_NAME"

# Check if the container exists
if docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container '$CONTAINER_NAME' exists, stopping and removing it..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Check if we have a saved configuration
CONFIG_DIR="$HOME/.config/iac-scripts"
if [ -d "$CONFIG_DIR/$CONTAINER_NAME" ] && [ -f "$CONFIG_DIR/$CONTAINER_NAME/original_args" ]; then
    ORIGINAL_ARGS=$(cat "$CONFIG_DIR/$CONTAINER_NAME/original_args")
    
    echo "Found saved configuration, recreating container with:"
    echo "./start-ros2-container.sh $ORIGINAL_ARGS --clean"
    
    # Run the container with original args and --clean to start fresh
    ./start-ros2-container.sh $ORIGINAL_ARGS --clean
else
    # Create a default ROS2 container with workspace fixes
    WORKSPACE_DIR="$HOME/projects"
    mkdir -p "$WORKSPACE_DIR"

    echo "No saved configuration found. Creating a default ROS2 container."
    echo "Running: ./start-ros2-container.sh --name $CONTAINER_NAME --workspace $WORKSPACE_DIR --save-config --clean"
    
    # Create a default ROS2 container
    ./start-ros2-container.sh --name "$CONTAINER_NAME" --workspace "$WORKSPACE_DIR" --save-config --clean
fi

echo ""
echo "Container recreation completed."
echo ""
echo "To connect from VS Code:"
echo "1. Click on the Remote Explorer icon in the sidebar"
echo "2. Find the container under 'Containers'"
echo "3. Right-click on '$CONTAINER_NAME' and select 'Attach to Container'"

exit 0
