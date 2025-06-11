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

# Initialize counter for periodic temp file cleanup
COUNTER=0

while true; do
    # Check if container exists
    if ! sudo docker inspect "$CONTAINER_NAME" &>/dev/null; then
        echo "Container $CONTAINER_NAME no longer exists. Stopping watch."
        exit 0
    fi
    
    # Check if container has stop marker file - CRITICAL CHECK
    # Check more frequently for stop requests (every 0.5 seconds)
    for i in {1..10}; do
        # Check for ROS2 container stop marker
        if sudo docker exec "$CONTAINER_NAME" test -f /home/ubuntu/.container_stop_requested 2>/dev/null; then
            echo "Stop marker detected (/home/ubuntu/.container_stop_requested), stopping container..."
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
        
        # Check for Yocto container stop marker
        if sudo docker exec "$CONTAINER_NAME" test -f /workdir/.container_stop_requested 2>/dev/null; then
            echo "Stop marker detected (/workdir/.container_stop_requested), stopping container..."
            # Remove the marker file
            sudo docker exec "$CONTAINER_NAME" rm -f /workdir/.container_stop_requested 2>/dev/null || true
            
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

        # Check for ROS2 container remove marker
        if sudo docker exec "$CONTAINER_NAME" test -f /home/ubuntu/.container_remove_requested 2>/dev/null; then
            echo "Remove marker detected (/home/ubuntu/.container_remove_requested), stopping and removing container..."
            # Remove the marker file
            sudo docker exec "$CONTAINER_NAME" rm -f /home/ubuntu/.container_remove_requested 2>/dev/null || true
            
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
            
            # Remove the container
            echo "Removing container $CONTAINER_NAME..."
            sudo docker rm "$CONTAINER_NAME"
            echo "Container $CONTAINER_NAME has been removed."
            
            # Exit the watch loop
            exit 0
        fi
        
        # Check for Yocto container remove marker
        if sudo docker exec "$CONTAINER_NAME" test -f /workdir/.container_remove_requested 2>/dev/null; then
            echo "Remove marker detected (/workdir/.container_remove_requested), stopping and removing container..."
            # Remove the marker file
            sudo docker exec "$CONTAINER_NAME" rm -f /workdir/.container_remove_requested 2>/dev/null || true
            
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
            
            # Remove the container
            echo "Removing container $CONTAINER_NAME..."
            sudo docker rm "$CONTAINER_NAME"
            echo "Container $CONTAINER_NAME has been removed."
            
            # Exit the watch loop
            exit 0
        fi
        
        sleep 0.1
    done
    
    # Check if container has detach marker file for ROS2
    if sudo docker exec "$CONTAINER_NAME" test -f /home/ubuntu/.container_detach_requested 2>/dev/null; then
        # Only show this message if debug mode is enabled
        if [ "$DEBUG" = "true" ]; then
            echo "ROS2 detach marker detected, ensuring container stays running..."
        fi
        
        # Remove the marker file
        sudo docker exec "$CONTAINER_NAME" rm -f /home/ubuntu/.container_detach_requested 2>/dev/null
        
        # Check if container is still running
        if ! sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
            echo "Container $CONTAINER_NAME stopped after detach, restarting it..."
            sudo docker start "$CONTAINER_NAME"
            
            # Restart the keep-alive script inside the container to ensure it's still running
            sudo docker exec "$CONTAINER_NAME" bash -c '
                if [ -f /home/ubuntu/keep_container_alive.sh ]; then
                    # Check if the keep-alive process is running
                    if ! pgrep -f "keep_container_alive.sh" >/dev/null; then
                        # If not running, start it again
                        nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 &
                        echo "Restarted keep-alive process"
                    fi
                fi
            ' || true
            
            echo "Container $CONTAINER_NAME restarted and is now running in the background."
        fi
    fi
    
    # Check if container has detach marker file for Yocto
    if sudo docker exec "$CONTAINER_NAME" test -f /workdir/.container_detach_requested 2>/dev/null; then
        # Only show this message if debug mode is enabled
        if [ "$DEBUG" = "true" ]; then
            echo "Yocto detach marker detected, ensuring container stays running..."
        fi
        
        # Remove the marker file
        sudo docker exec "$CONTAINER_NAME" rm -f /workdir/.container_detach_requested 2>/dev/null
        
        # Check if container is still running
        if ! sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
            echo "Container $CONTAINER_NAME stopped after detach, restarting it..."
            sudo docker start "$CONTAINER_NAME"
            
            # Restart the keep-alive script inside the container to ensure it's still running
            sudo docker exec "$CONTAINER_NAME" bash -c '
                if [ -f /workdir/keepalive/keep_alive.sh ]; then
                    # Check if the keep-alive process is running
                    if ! pgrep -f "/workdir/keepalive/keep_alive.sh" >/dev/null; then
                        # If not running, start it again
                        nohup /workdir/keepalive/keep_alive.sh >/dev/null 2>&1 &
                        echo "Restarted keep-alive process"
                    fi
                fi
            ' || true
            
            echo "Container $CONTAINER_NAME restarted and is now running in the background."
        fi
    fi
    
    # Periodically ensure the keep-alive process is running (every 10 cycles)
    if [ $((SECONDS % 10)) -eq 0 ]; then
        # Only execute if the container is running
        if sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
            # Execute quietly to avoid too much output
            sudo docker exec "$CONTAINER_NAME" bash -c '
                if [ -f /home/ubuntu/keep_container_alive.sh ]; then
                    # Check if the keep-alive process is running
                    if ! pgrep -f "keep_container_alive.sh" >/dev/null; then
                        # If not running, start it again
                        nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 &
                        echo "Restarted keep-alive process after detection by watcher"
                    fi
                fi
            ' >/dev/null 2>&1 || true
        fi
    fi
    
    # Periodically clean up temporary files (once every 10 checks)
    COUNTER=$((COUNTER+1))
    if [ $COUNTER -ge 10 ]; then
        # Check if the cleanup script exists and run it
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -x "$SCRIPT_DIR/cleanup-container-temp-files.sh" ]; then
            if [ "$DEBUG" = true ]; then
                echo "Running temporary file cleanup..."
            fi
            "$SCRIPT_DIR/cleanup-container-temp-files.sh" > /dev/null 2>&1
        fi
        COUNTER=0
    fi
    
    # Sleep to avoid excessive CPU usage
    sleep 1
done
