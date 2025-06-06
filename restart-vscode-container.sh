#!/bin/bash
# Helper script to restart and reattach to a container from VS Code
# Usage: ./restart-vscode-container.sh <container_name>

if [ -z "$1" ]; then
    echo "Usage: $0 <container_name>"
    echo "Restarts a stopped container and ensures it's in a state that VS Code can reattach to it."
    exit 1
fi

CONTAINER_NAME="$1"

# Function to create a fresh container based on the original run arguments
recreate_container_from_config() {
    local CONTAINER_NAME="$1"
    local CONFIG_DIR="$HOME/.config/iac-scripts"
    
    # Check if we have a saved configuration for this container
    if [ -d "$CONFIG_DIR/$CONTAINER_NAME" ]; then
        echo "Found saved configuration for $CONTAINER_NAME, recreating container..."
        
        # Get original arguments if available
        if [ -f "$CONFIG_DIR/$CONTAINER_NAME/original_args" ]; then
            local ORIGINAL_ARGS=$(cat "$CONFIG_DIR/$CONTAINER_NAME/original_args")
            local ENV_TYPE=$(cat "$CONFIG_DIR/$CONTAINER_NAME/env_type" 2>/dev/null || echo "ros2")
            
            echo "Recreating container with original arguments:"
            echo "./run-${ENV_TYPE}-container.sh $ORIGINAL_ARGS --clean"
            
            # Run the container with original args and --clean to start fresh
            ./run-${ENV_TYPE}-container.sh $ORIGINAL_ARGS --clean
            return $?
        fi
    fi
    
    return 1
}

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container '$CONTAINER_NAME' does not exist"
    exit 1
fi

# Check if container is already running
if docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container '$CONTAINER_NAME' is already running."
    echo "You should be able to attach to it from VS Code."
    exit 0
fi

echo "Restarting container '$CONTAINER_NAME'..."

# Check for problematic mount points directly
MOUNTS=$(docker inspect --format='{{range .Mounts}}{{.Destination}} {{end}}' "$CONTAINER_NAME")
if echo "$MOUNTS" | grep -q "entrypoint.sh"; then
    echo "Detected mount conflict with entrypoint.sh."
    echo "The container cannot be restarted due to mount conflicts."
    echo "Removing the problematic container and recreating it..."
    
    # Remove the container
    docker rm "$CONTAINER_NAME"
    
    # Recreate it from configuration
    if recreate_container_from_config "$CONTAINER_NAME"; then
        echo "Container successfully recreated from saved configuration."
    else
        echo "Could not automatically recreate container."
        echo "Please manually recreate the container using:"
        echo "./run-ros2-container.sh --name $CONTAINER_NAME --clean"
        exit 1
    fi
else
    # Try to start the container normally
    echo "Starting container normally..."
    docker start "$CONTAINER_NAME"
    
    # If start fails, try the recreation approach
    if [ $? -ne 0 ]; then
        echo "Failed to start container using normal method."
        echo "Trying to recreate container from saved configuration..."
        
        # Remove the problematic container
        docker rm "$CONTAINER_NAME"
        
        if recreate_container_from_config "$CONTAINER_NAME"; then
            echo "Container successfully recreated from saved configuration."
        else
            echo "Could not automatically recreate container."
            echo "Please manually recreate the container using:"
            echo "./run-ros2-container.sh --name $CONTAINER_NAME --clean"
            exit 1
        fi
    fi
fi

# Check if the container is actually running
if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo "Container failed to start or exited immediately."
    echo "Trying advanced recovery method..."
    
    if recreate_container_from_config "$CONTAINER_NAME"; then
        echo "Container successfully recreated from saved configuration."
    else
        echo "Could not automatically recreate container."
        echo "Please manually recreate the container using:"
        echo "./run-ros2-container.sh --name $CONTAINER_NAME --clean"
        exit 1
    fi
fi

# Ensure the keep-alive process is running
echo "Ensuring keep-alive process is running..."
docker exec "$CONTAINER_NAME" bash -c '
    # Check if keep_container_alive.sh exists and run it if not already running
    if [ -f /home/ubuntu/keep_container_alive.sh ]; then
        if ! pgrep -f "keep_container_alive.sh" >/dev/null; then
            echo "Starting keep-alive process..."
            nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 &
        else
            echo "Keep-alive process is already running."
        fi
    else
        # Fallback to basic keep-alive process
        echo "Starting basic keep-alive process..."
        nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
    fi
    
    # Create the detach marker to ensure container-watch.sh knows to keep it running
    touch /home/ubuntu/.container_detach_requested
'

echo "Container '$CONTAINER_NAME' is now running and ready for VS Code to attach."
echo ""
echo "In VS Code:"
echo "1. Click on the Remote Explorer icon in the sidebar"
echo "2. Find the container under 'Containers'"
echo "3. Right-click on '$CONTAINER_NAME' and select 'Attach to Container'"
echo ""
echo "If VS Code still can't attach, try restarting VS Code or the Docker extension."

# Start the container watcher if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/container-watch.sh" ]; then
    echo "Starting container watcher..."
    bash "$SCRIPT_DIR/container-watch.sh" "$CONTAINER_NAME" &
fi

exit 0
