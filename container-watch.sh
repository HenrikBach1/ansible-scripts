#!/bin/bash
# Script to monitor and restart a container if it stops after a detach command

CONTAINER_NAME="$1"
if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 CONTAINER_NAME"
    exit 1
fi

# Only show this message once
echo "Watching container $CONTAINER_NAME..."

# For debugging purposes
DEBUG=true

while true; do
    # Check if container exists
    if ! sudo docker inspect "$CONTAINER_NAME" &>/dev/null; then
        echo "Container $CONTAINER_NAME no longer exists. Stopping watch."
        exit 0
    fi
    
    # Check if container has stop marker file - CRITICAL CHECK
    # Check more frequently for stop requests (every 0.5 seconds)
    for i in {1..10}; do
        if sudo docker exec "$CONTAINER_NAME" test -f /home/ubuntu/.container_stop_requested 2>/dev/null; then
            echo "Stop marker detected, stopping container..."
            # Remove the marker file
            sudo docker exec "$CONTAINER_NAME" rm -f /home/ubuntu/.container_stop_requested 2>/dev/null || true
            
            # Make sure to forcefully stop the container
            echo "Stopping container $CONTAINER_NAME with docker stop..."
            sudo docker stop "$CONTAINER_NAME"
            
            # Verify the container is actually stopped
            if ! sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
                echo "Container $CONTAINER_NAME has been successfully stopped."
            else
                echo "Container $CONTAINER_NAME didn't stop with normal command, using force..."
                sudo docker kill "$CONTAINER_NAME"
                echo "Container $CONTAINER_NAME has been forcefully stopped."
            fi
            
            # Exit the watch loop
            exit 0
        fi
        sleep 0.1
    done
    
    # Check if container has detach marker file
    if sudo docker exec "$CONTAINER_NAME" test -f /home/ubuntu/.container_detach_requested 2>/dev/null; then
        # Only show this message if debug mode is enabled
        if [ "$DEBUG" = "true" ]; then
            echo "Detach marker detected, ensuring container stays running..."
        fi
        
        # Remove the marker file
        sudo docker exec "$CONTAINER_NAME" rm -f /home/ubuntu/.container_detach_requested 2>/dev/null
        
        # Check if container is still running
        if ! sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
            echo "Container $CONTAINER_NAME stopped after detach, restarting it..."
            sudo docker start "$CONTAINER_NAME"
            echo "Container $CONTAINER_NAME restarted and is now running in the background."
        fi
    fi
    
    # Sleep to avoid excessive CPU usage
    sleep 1
done
