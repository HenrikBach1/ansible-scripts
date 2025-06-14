#!/bin/bash
# Common Podman container runner script for development environments
# This script is called by environment-specific scripts like start-yocto-container-podman.sh
file=run-container-common-podman.sh

# Source the configuration management system (if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/container-config.sh" ]; then
    source "$SCRIPT_DIR/container-config.sh"
fi

# Setup tab completion for container management commands
# This provides tab completion for container names and command options
_setup_container_completion() {
    # Complete container names for container management commands
    _container_management_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local containers=$(podman ps -a --format '{{.Names}}' 2>/dev/null | grep -E '(yocto|ros2)' || true)
        COMPREPLY=($(compgen -W "$containers" -- "$cur"))
    }
    
    # Complete container names for simple scripts
    _container_names_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local containers=$(podman ps -a --format '{{.Names}}' 2>/dev/null || true)
        COMPREPLY=($(compgen -W "$containers" -- "$cur"))
    }
    
    # Only set up completion if we're in an interactive shell and have the complete command
    if [[ $- == *i* ]] && command -v complete >/dev/null 2>&1; then
        # Main container management scripts
        complete -F _container_management_completion start-yocto-container-podman.sh 2>/dev/null || true
        complete -F _container_management_completion restart-yocto-container-podman.sh 2>/dev/null || true
        
        # Connection scripts
        complete -F _container_names_completion yocto-podman-connect 2>/dev/null || true
        
        # Container exec wrappers
        complete -F _container_names_completion podman-exec-it 2>/dev/null || true
        complete -F _container_names_completion podman-exec-detached 2>/dev/null || true
    fi
}

# Setup completion when this script is sourced
_setup_container_completion

# Function to fix a container that keeps exiting
fix_container_exit() {
    local CONTAINER_NAME="$1"
    
    # Check if container exists
    if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container '$CONTAINER_NAME' does not exist."
        return 1
    fi
    
    # Get container status
    local STATUS=$(podman inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
    echo "Container status: $STATUS"
    
    # If container is not running, start it
    if [ "$STATUS" != "running" ]; then
        podman start "$CONTAINER_NAME"
    fi
    
    # Create a keep-alive script inside the container
    echo "Adding keep-alive trap to container..."
    podman exec "$CONTAINER_NAME" bash -c "echo 'trap \"while true; do sleep 3600; done\" EXIT' > /home/usersetup/keep_container_alive.sh && echo 'while true; do sleep 3600; done' >> /home/usersetup/keep_container_alive.sh && chmod +x /home/usersetup/keep_container_alive.sh && nohup /home/usersetup/keep_container_alive.sh >/dev/null 2>&1 &"
    
    echo "Container fixed. It should now remain running even if the main process exits."
    echo "To connect: podman exec -it $CONTAINER_NAME bash"
    
    return 0
}

# Function to stop a container
stop_container() {
    local CONTAINER_NAME="$1"
    
    # Check if container exists
    if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container '$CONTAINER_NAME' does not exist."
        return 1
    fi
    
    # Check if container is running
    if ! podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container '$CONTAINER_NAME' is not running."
        return 0
    fi
    
    echo "Stopping container '$CONTAINER_NAME'..."
    podman stop "$CONTAINER_NAME"
    
    echo "Container '$CONTAINER_NAME' has been stopped."
    return 0
}

# Function to remove a container
remove_container() {
    local CONTAINER_NAME="$1"
    
    # Check if container exists
    if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container '$CONTAINER_NAME' does not exist."
        return 1
    fi
    
    # Stop the container if it's running
    if podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        podman stop "$CONTAINER_NAME" >/dev/null
    fi
    
    echo "Removing container '$CONTAINER_NAME'..."
    podman rm "$CONTAINER_NAME"
    
    echo "Container '$CONTAINER_NAME' has been removed."
    return 0
}

# Function to verify container configuration
verify_container() {
    local CONTAINER_NAME="$1"
    
    if [ -z "$CONTAINER_NAME" ]; then
        echo "Usage: verify_container <container_name>"
        return 1
    fi
    
    echo "Verifying container configuration for: $CONTAINER_NAME"
    echo "=================================================="
    
    # Check if container exists
    if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "❌ Container '$CONTAINER_NAME' does not exist"
        return 1
    fi
    
    echo "✅ Container exists"
    
    # Check if container is running
    if podman ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "✅ Container is running"
        
        # Check container commands
        echo "Checking container commands..."
        if podman exec "$CONTAINER_NAME" which container-help >/dev/null 2>&1; then
            echo "✅ Container commands are installed"
        else
            echo "⚠️  Container commands not found"
        fi
        
        # Check workspace paths
        echo "Checking workspace paths..."
        for path in "/workspace" "/projects" "/workdir"; do
            if podman exec "$CONTAINER_NAME" test -d "$path" 2>/dev/null; then
                echo "✅ $path exists"
            else
                echo "⚠️  $path not found"
            fi
        done
        
    else
        echo "⚠️  Container is not running"
        echo "   Start with: podman start $CONTAINER_NAME"
    fi
    
    echo "=================================================="
    echo "Verification complete."
}

# This script should not be called directly
if [[ "$(basename "$0")" == "run-container-common-podman.sh" ]]; then
    echo "Error: This script should not be called directly."
    echo "Please use one of the environment-specific scripts like start-yocto-container-podman.sh."
    exit 1
fi
