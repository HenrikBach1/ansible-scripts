#!/bin/bash
# Common container runner script for development environments
# This script is called by environment-specific scripts like start-ros2-container.sh and start-yocto-container.sh
file=run-container-common.sh

# Source the configuration management system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/container-config.sh"

# Function to fix a container that keeps exiting
fix_container_exit() {
    local CONTAINER_NAME="$1"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container '$CONTAINER_NAME' does not exist."
        return 1
    fi
    
    # Get container status
    local STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
    echo "Container status: $STATUS"
    
    # If container is not running, start it
    if [ "$STATUS" != "running" ]; then
        echo "Starting container..."
        docker start "$CONTAINER_NAME"
    fi
    
    # Create a keep-alive script inside the container
    echo "Adding keep-alive trap to container..."
    docker exec "$CONTAINER_NAME" bash -c "echo 'trap \"while true; do sleep 3600; done\" EXIT' > /home/ubuntu/keep_container_alive.sh && echo 'while true; do sleep 3600; done' >> /home/ubuntu/keep_container_alive.sh && chmod +x /home/ubuntu/keep_container_alive.sh && nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 &"
    
    echo "Container fixed. It should now remain running even if the main process exits."
    echo "To connect: docker attach $CONTAINER_NAME"
    
    return 0
}

# Function to display help
show_container_help() {
    local ENV_TYPE="$1"
    local ENV_VERSION_DEFAULT="$2"
    local ENV_VERSION_PARAM="$3"
    local WORKSPACE_DIR_DEFAULT="$4"
    
    echo "Usage: $0 [OPTIONS]"
    echo "Run a ${ENV_TYPE} Docker container with appropriate settings"
    echo ""
    echo "Options:"
    if [ "${ENV_TYPE,,}" = "ros2" ]; then
        echo "  -d, --${ENV_VERSION_PARAM} ${ENV_VERSION_PARAM^^}  ${ENV_TYPE} ${ENV_VERSION_PARAM} (default: ${ENV_VERSION_DEFAULT})"
    fi
    echo "  -n, --name NAME        Container name (default: ${ENV_TYPE}_container)"
    echo "  -w, --workspace DIR    Host workspace directory (default: ${WORKSPACE_DIR_DEFAULT})"
    echo "  -g, --gpu              Enable NVIDIA GPU support (if available)"
    echo "  -c, --cmd CMD          Command to run in container (default: bash)"
    echo "  -p, --persistent       Keep container after exit (enabled by default)"
    echo "  -r, --root             Run container as root user instead of current user"
    echo "  -D, --detach           Run container in detached mode"
    echo "  --no-attach            Don't automatically attach to detached containers"
    echo "  --clean                Stop and remove existing container before starting"
    echo "  --save-config          Save current configuration for future use"
    echo "  --list-configs         List all saved container configurations"
    echo "  --show-config NAME     Show detailed configuration for a specific container"
    echo "  --show-running         Show configurations for all running containers"
    echo "  --remove-config NAME   Remove a saved container configuration"
    echo "  --cleanup-configs [N]  Remove configurations not used in N days (default: 30)"
    echo "  --fix [NAME]           Fix a container that keeps exiting"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Basic usage (runs bash shell in the container)"
    echo "  $0"
    echo ""
    if [ "${ENV_TYPE,,}" = "ros2" ]; then
        echo "  # Run with a specific ${ENV_TYPE} ${ENV_VERSION_PARAM}"
        echo "  $0 --${ENV_VERSION_PARAM} ${ENV_VERSION_DEFAULT}"
        echo ""
    fi
    echo "  # Create a container with a custom name"
    echo "  $0 --name my_${ENV_TYPE}_dev"
    echo ""
    echo "  # Run in detached mode (container keeps running in background)"
    echo "  $0 --detach"
    echo ""
    echo "  # Clean start (stop and remove existing container first)"
    echo "  $0 --clean"
    echo ""
    echo "  # Save current configuration for future use"
    echo "  $0 --save-config"
    echo ""
    echo "Note: To reattach to a detached container:"
    echo "  - Run: docker attach \${CONTAINER_NAME}"
    echo ""
    echo "Note: This script is idempotent. If the container already exists:"
    echo "  - If running, it will attach to it"
    echo "  - If stopped, it will start it and attach to it"
    echo "  - If it doesn't exist, it will create a new container"
    exit 0
}

# Function to run the container
run_container() {
    # Parse parameters
    local ENV_TYPE="$1"
    local ENV_VERSION="$2"
    local CONTAINER_NAME="$3"
    local WORKSPACE_DIR="$4"
    local PERSISTENT="$5"
    local RUN_AS_ROOT="$6"
    local DETACH_MODE="$7"
    local AUTO_ATTACH="$8"
    local CLEAN_START="$9"
    local GPU_SUPPORT="${10}"
    local IMAGE_NAME="${11}"
    local CUSTOM_CMD="${12}"
    local ADDITIONAL_ARGS="${13}"
    local ENTRYPOINT_SCRIPT="${14}"
    local SAVE_CONFIG="${15}"
    local ORIGINAL_ARGS="${16}"
    
    # If save config is requested, save all configurations
    if [ "$SAVE_CONFIG" = true ]; then
        echo "Saving configuration for container $CONTAINER_NAME..."
        save_all_container_configs "$CONTAINER_NAME" "$ENV_TYPE" "$ENV_VERSION" "$WORKSPACE_DIR" \
            "$GPU_SUPPORT" "$CUSTOM_CMD" "$PERSISTENT" "$RUN_AS_ROOT" "$DETACH_MODE" \
            "$AUTO_ATTACH" "$IMAGE_NAME" "$ADDITIONAL_ARGS"
        
        # Save original arguments if provided
        if [ -n "$ORIGINAL_ARGS" ]; then
            save_original_args "$CONTAINER_NAME" "$ORIGINAL_ARGS"
        fi
        
        echo "Configuration saved. You can use these settings in the future by running with --name $CONTAINER_NAME"
    fi
    
    # Create workspace directory if it doesn't exist
    mkdir -p "$WORKSPACE_DIR"

    # Check if container already exists
    CONTAINER_EXISTS=$(docker ps -a --format "{{.Names}}" | grep -w "^$CONTAINER_NAME$")

    # Check if container is running
    CONTAINER_RUNNING=$(docker ps --format "{{.Names}}" | grep -w "^$CONTAINER_NAME$")

    # Handle clean start option
    if [ "$CLEAN_START" = true ] && [ -n "$CONTAINER_EXISTS" ]; then
        echo "Stopping and removing existing container $CONTAINER_NAME..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        CONTAINER_EXISTS=""
        CONTAINER_RUNNING=""
    fi

    # If container is already running, attach to it
    if [ -n "$CONTAINER_RUNNING" ]; then
        echo "Container $CONTAINER_NAME is already running, attaching to it..."
        docker attach "$CONTAINER_NAME"
        exit 0
    fi

    # If container exists but is not running, start it
    if [ -n "$CONTAINER_EXISTS" ]; then
        echo "Container $CONTAINER_NAME exists but is not running, starting it..."
        docker start "$CONTAINER_NAME" >/dev/null
        
        if [ "$DETACH_MODE" = false ] || [ "$AUTO_ATTACH" = true ]; then
            docker attach "$CONTAINER_NAME"
        else
            echo "Container $CONTAINER_NAME is now running in detached mode."
            echo "To attach to it later, run: docker attach $CONTAINER_NAME"
        fi
        
        exit 0
    fi

    # NVIDIA GPU support
    GPU_OPTIONS=""
    if [ "$GPU_SUPPORT" = true ]; then
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "NVIDIA GPU detected, enabling GPU support..."
            GPU_OPTIONS="--gpus all"
        else
            echo "Warning: NVIDIA GPU support requested but no NVIDIA GPU detected."
            echo "Continuing without GPU support..."
        fi
    fi

    # User setup
    USER_OPTIONS=""
    if [ "$RUN_AS_ROOT" = false ]; then
        # If running as current user, set up uid/gid mapping
        USER_OPTIONS="-u $(id -u):$(id -g) -v $HOME/.gitconfig:/home/$(id -u)/.gitconfig:ro"
    fi

    # Persistence option
    PERSISTENCE_FLAG=""
    if [ "$PERSISTENT" = false ]; then
        PERSISTENCE_FLAG="--rm"
    fi

    # Detach mode
    DETACH_FLAG=""
    if [ "$DETACH_MODE" = true ]; then
        DETACH_FLAG="-d"
    fi

    # Entrypoint command
    ENTRYPOINT_ARGS=""
    if [ -n "$ENTRYPOINT_SCRIPT" ] && [ -f "$ENTRYPOINT_SCRIPT" ]; then
        echo "Using custom entrypoint script: $ENTRYPOINT_SCRIPT"
        # Instead of trying to use the host script as the entrypoint directly,
        # mount it into the container and execute it from there
        ENTRYPOINT_MOUNT="-v $ENTRYPOINT_SCRIPT:/home/$(id -u)/entrypoint.sh"
        # Make sure the script is executable
        chmod +x "$ENTRYPOINT_SCRIPT" || true
        # Run the entrypoint script as the first command
        ENTRYPOINT_ARGS="/home/$(id -u)/entrypoint.sh $ENV_VERSION"
    fi

    # Run the container with appropriate options
    echo "Starting ${ENV_TYPE} container with ${ENV_VERSION}..."

    # Create workspace directory if it doesn't exist
    mkdir -p "$WORKSPACE_DIR"
    
    # Fix permissions to ensure container can write to it
    chmod 777 "$WORKSPACE_DIR" || true

    docker run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
        $USER_OPTIONS \
        --privileged \
        --network=host \
        -v "$WORKSPACE_DIR:/home/$(id -u)/${ENV_TYPE}_ws" \
        -v "$WORKSPACE_DIR:/workspace" \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY \
        $ADDITIONAL_ARGS \
        $ENTRYPOINT_MOUNT \
        --name "$CONTAINER_NAME" \
        "$IMAGE_NAME" $ENTRYPOINT_ARGS $CUSTOM_CMD

    # If running in detach mode but auto-attach is true, attach to the container
    if [ "$DETACH_MODE" = true ] && [ "$AUTO_ATTACH" = true ]; then
        echo "Attaching to detached container..."
        docker attach "$CONTAINER_NAME"
    fi

    # Start the container watcher in the background if this is a persistent container
    if [ "$PERSISTENT" = true ] && [ -f "$(dirname "$0")/container-watch.sh" ]; then
        echo "Starting container watcher for $CONTAINER_NAME..."
        bash "$(dirname "$0")/container-watch.sh" "$CONTAINER_NAME" &
    fi
}

# This script should not be called directly
if [[ "$(basename "$0")" == "run-container-common.sh" ]]; then
    echo "Error: This script should not be called directly."
    echo "Please use one of the environment-specific scripts like start-ros2-container.sh or start-yocto-container.sh."
    exit 1
fi
