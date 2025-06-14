#!/bin/bash
# Ensure container commands are available in Yocto Podman containers
# This script adds standardized container commands to any Podman container

CONTAINER_NAME="${1:-yocto_container_podman}"
TARGET_USER="${2:-usersetup}"  # Default CROPS user

echo "Adding container commands to Podman container: $CONTAINER_NAME"

# Check if container exists and is running
if ! podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    if podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container exists but is not running. Starting it..."
        podman start "$CONTAINER_NAME"
        sleep 2
    else
        echo "Error: Container $CONTAINER_NAME does not exist"
        exit 1
    fi
fi

# Source the common container command library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/container-command-common.sh" ]; then
    source "$SCRIPT_DIR/container-command-common.sh"
    
    # Install commands using the shared library with Podman
    install_container_commands_podman "$CONTAINER_NAME" "$TARGET_USER"
    
    echo "Container commands have been added to $CONTAINER_NAME"
    echo "Available commands: container-help, container-detach, container-stop, container-remove"
    echo ""
    echo "To test, connect to the container and run: container-help"
    echo "Connect with: podman exec -it $CONTAINER_NAME bash"
else
    echo "Warning: container-command-common.sh not found, using fallback installation"
    
    # Fallback: Copy and run the container shell setup directly
    if [ -f "$SCRIPT_DIR/container-shell-setup.sh" ]; then
        podman cp "$SCRIPT_DIR/container-shell-setup.sh" "$CONTAINER_NAME:/tmp/container-shell-setup.sh"
        
        # Run setup as root first
        podman exec -u root "$CONTAINER_NAME" bash /tmp/container-shell-setup.sh
        
        # Run setup as regular user
        podman exec "$CONTAINER_NAME" bash /tmp/container-shell-setup.sh
        
        echo "Container commands installed using fallback method"
    else
        echo "Error: No container setup scripts found"
        exit 1
    fi
fi
