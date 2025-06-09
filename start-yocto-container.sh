#!/bin/bash
# Script to run a Yocto Docker container with appropriate settings
file=start-yocto-container.sh
echo "Running script: $file"

# Store original arguments
ORIGINAL_ARGS="$@"

# Source the common container runner
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run-container-common.sh"

# Default values
ENV_TYPE="yocto"
CONTAINER_NAME="yocto_container"
WORKSPACE_DIR="$HOME/yocto_ws"
GPU_SUPPORT=false
CUSTOM_CMD="bash"
PERSISTENT=true
RUN_AS_ROOT=false
DETACH_MODE=true
AUTO_ATTACH=false
CLEAN_START=false
SAVE_CONFIG=false
LIST_CONFIGS=false
STOP_CONTAINER=false
REMOVE_CONTAINER=false

# Function to display specialized help for Yocto
show_yocto_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run a Yocto Docker container with appropriate settings"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME        Container name (default: yocto_container)"
    echo "  -w, --workspace DIR    Host workspace directory (default: $WORKSPACE_DIR)"
    echo "  -g, --gpu              Enable NVIDIA GPU support (if available)"
    echo "  -c, --cmd CMD          Command to run in container (default: bash)"
    echo "  -p, --persistent       Keep container after exit (enabled by default)"
    echo "  -r, --root             Run container as root user instead of current user"
    echo "  -D, --detach           Run container in detached mode (enabled by default)"
    echo "  --attach               Automatically attach to container after starting"
    echo "  --clean                Stop and remove existing container before starting"
    echo "  --save-config          Save current configuration for future use"
    echo "  --list-configs         List all saved container configurations"
    echo "  --show-config NAME     Show detailed configuration for a specific container"
    echo "  --show-running         Show configurations for all running containers"
    echo "  --remove-config NAME   Remove a saved container configuration"
    echo "  --cleanup-configs [N]  Remove configurations not used in N days (default: 30)"
    echo "  --fix [NAME]           Fix a container that keeps exiting"
    echo "  --stop [NAME]          Stop the container"
    echo "  --remove [NAME]        Stop and remove the container"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Basic usage (runs in detached mode by default)"
    echo "  $0"
    echo ""
    echo "  # Create a container with a custom name"
    echo "  $0 --name my_yocto_dev"
    echo ""
    echo "  # Run in attached mode (interactive session)"
    echo "  $0 --attach"
    echo ""
    echo "  # Clean start (stop and remove existing container first)"
    echo "  $0 --clean"
    echo ""
    echo "  # Save current configuration for future use"
    echo "  $0 --save-config"
    echo ""
    echo "  # Fix a stopped container and make it keep running"
    echo "  $0 --fix"
    echo ""
    echo "  # Stop the default container"
    echo "  $0 --stop"
    echo ""
    echo "  # Stop a specific container"
    echo "  $0 --stop my_yocto_dev"
    echo ""
    echo "  # Remove the default container (stops it first if running)"
    echo "  $0 --remove"
    echo ""
    echo "  # Remove a specific container"
    echo "  $0 --remove my_yocto_dev"
    echo ""
    echo "Note: By default, containers run in detached mode."
    echo "To connect to a running container:"
    echo "  - Run: ./yocto-connect"
    echo "  - Or run: docker exec -it yocto_container bash"
    echo ""
    echo "In the container, you can use these commands:"
    echo "  - Type 'detach' to detach from the container (container keeps running)"
    echo "  - Type 'stop' to stop the container"
    echo "  - Type 'remove' to stop and remove the container"
    echo "  - Type 'help' for more information"
    echo ""
    echo "Legacy commands for backward compatibility:"
    echo "  - Type 'stop_container' (same as 'stop')"
    echo "  - Type 'container_help' or 'container-help' (same as 'help')"
    echo ""
    echo "Note: CROPS/poky containers use the workdir permissions to set up the container user."
    echo "Make sure your workspace directory has the correct permissions."
    exit 0
}

# Check if we need to handle configuration options before parsing other arguments
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_yocto_help
    fi
    if [[ "$arg" == "--list-configs" ]]; then
        list_container_configs
        exit 0
    fi
    if [[ "$arg" == "--stop" ]]; then
        if [[ -n "$2" && "$2" != "--"* ]]; then
            stop_container "$2"
        else
            stop_container "$CONTAINER_NAME"
        fi
        exit $?
    fi
    if [[ "$arg" == "--remove" ]]; then
        if [[ -n "$2" && "$2" != "--"* ]]; then
            remove_container "$2"
        else
            remove_container "$CONTAINER_NAME"
        fi
        exit $?
    fi
    if [[ "$arg" == "--fix" ]]; then
        if [[ -n "$2" && "$2" != "--"* ]]; then
            CONTAINER_TO_FIX="$2"
        else
            CONTAINER_TO_FIX="$CONTAINER_NAME"
        fi
        echo "Fixing container $CONTAINER_TO_FIX..."
        
        # Check if container exists
        if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_TO_FIX$" > /dev/null; then
            echo "Container '$CONTAINER_TO_FIX' does not exist."
            exit 1
        fi
        
        # Get container status
        local STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_TO_FIX")
        echo "Container status: $STATUS"
        
        # Special handling for Yocto container
        echo "Applying Yocto-specific fixes..."
        
        # If container is not running, start it
        if [ "$STATUS" != "running" ]; then
            echo "Starting container..."
            docker start "$CONTAINER_TO_FIX"
            # Wait briefly for container to start
            sleep 2
        fi
        
        # Create robust keep-alive scripts in the container
        echo "Adding robust keep-alive mechanisms to container..."
        
        # Execute commands to ensure the container stays running
        docker exec "$CONTAINER_TO_FIX" bash -c '
            # Create a directory for keep-alive scripts that we know we can write to
            mkdir -p /workdir/keepalive
            chmod 777 /workdir/keepalive
            
            # Create a robust keep-alive script
            echo "#!/bin/bash" > /workdir/keepalive/keep_alive.sh
            echo "trap \"echo Keeping container alive; exec tail -f /dev/null\" EXIT" >> /workdir/keepalive/keep_alive.sh
            echo "exec tail -f /dev/null" >> /workdir/keepalive/keep_alive.sh
            chmod +x /workdir/keepalive/keep_alive.sh
            
            # Start primary keep-alive process
            nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
            
            # Start backup keep-alive process
            nohup bash -c "exec tail -f /dev/null" >/dev/null 2>&1 &
            
            # Start the main keep-alive script in a detached process
            nohup /workdir/keepalive/keep_alive.sh >/dev/null 2>&1 &
            
            echo "Robust keep-alive processes started"
        '
        
        echo "Container fixed. It should now remain running even if the main process exits."
        echo "To connect: docker exec -it $CONTAINER_TO_FIX bash"
        exit 0
    fi
    if [[ "$arg" == "--debug-config" ]]; then
        debug_container_config
        exit 0
    fi
    if [[ "$arg" == "--show-config" ]]; then
        if [[ -n "$2" ]]; then
            show_container_config "$2"
            exit 0
        else
            echo "Error: --show-config requires a container name"
            exit 1
        fi
    fi
    if [[ "$arg" == "--remove-config" && -n "$2" ]]; then
        remove_container_config "$2"
        exit 0
    fi
    if [[ "$arg" == "--cleanup-configs" ]]; then
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            cleanup_configs "$2"
        else
            cleanup_configs
        fi
        exit 0
    fi
    if [[ "$arg" == "--show-running" ]]; then
        show_running_container_config
        exit 0
    fi
done

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            CONTAINER_NAME="$2"
            # Check if we have a saved configuration for this container name
            if [ "$(container_config_exists "$CONTAINER_NAME")" = "true" ]; then
                # Get saved config values
                ENV_TYPE=$(load_container_config "$CONTAINER_NAME" "env_type" "$ENV_TYPE")
                WORKSPACE_DIR=$(load_container_config "$CONTAINER_NAME" "workspace_dir" "$WORKSPACE_DIR")
                GPU_SUPPORT=$(load_container_config "$CONTAINER_NAME" "gpu_support" "$GPU_SUPPORT")
                CUSTOM_CMD=$(load_container_config "$CONTAINER_NAME" "custom_cmd" "$CUSTOM_CMD")
                PERSISTENT=$(load_container_config "$CONTAINER_NAME" "persistent" "$PERSISTENT")
                RUN_AS_ROOT=$(load_container_config "$CONTAINER_NAME" "run_as_root" "$RUN_AS_ROOT")
                DETACH_MODE=$(load_container_config "$CONTAINER_NAME" "detach_mode" "$DETACH_MODE")
                AUTO_ATTACH=$(load_container_config "$CONTAINER_NAME" "auto_attach" "$AUTO_ATTACH")
                echo "Loaded saved configuration for container $CONTAINER_NAME"
            fi
            shift 2
            ;;
        -w|--workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        -g|--gpu)
            GPU_SUPPORT=true
            shift
            ;;
        -c|--cmd)
            CUSTOM_CMD="$2"
            shift 2
            ;;
        -p|--persistent)
            PERSISTENT=true
            shift
            ;;
        -r|--root)
            RUN_AS_ROOT=true
            shift
            ;;
        -D|--detach)
            DETACH_MODE=true
            shift
            ;;
        --attach)
            AUTO_ATTACH=true
            shift
            ;;
        --no-attach)
            AUTO_ATTACH=false
            shift
            ;;
        --clean)
            CLEAN_START=true
            shift
            ;;
        --save-config)
            SAVE_CONFIG=true
            shift
            ;;
        --debug-config)
            # This was already handled earlier
            shift
            ;;
        --list-configs)
            # This was already handled earlier
            shift
            ;;
        -h|--help)
            show_yocto_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Container image selection
# Use CROPS/poky with Ubuntu 22.04 base
CONTAINER_BASE="ubuntu-22.04"
IMAGE_NAME="crops/poky:${CONTAINER_BASE}"

# Verify the crops/poky image exists or pull it
if [ -z "$(docker images -q crops/poky:${CONTAINER_BASE} 2>/dev/null)" ]; then
    echo "Pulling CROPS/poky image: crops/poky:${CONTAINER_BASE}..."
    docker pull crops/poky:${CONTAINER_BASE} || {
        echo "ERROR: Failed to pull crops/poky:${CONTAINER_BASE} image."
        echo "Available tags include: ubuntu-22.04, ubuntu-20.04, debian-11, fedora-36, etc."
        exit 1
    }
fi

# CROPS/poky requires special handling - override the common container options
# to use the crops/poky-specific flags
USER_OPTIONS="--workdir=/workdir"
ADDITIONAL_ARGS="-e TEMPLATECONF=/workdir/meta-custom/conf/templates/default"
ENTRYPOINT_SCRIPT="" # Don't use our custom entrypoint for CROPS
ENTRYPOINT_MOUNT="" # Clear any mounts that were set
ENTRYPOINT_ARGS="" # Clear any args that were set

# Check if container already exists and handle CLEAN_START
CONTAINER_EXISTS=$(docker ps -a --format "{{.Names}}" | grep -w "^$CONTAINER_NAME$")
if [ "$CLEAN_START" = true ] && [ -n "$CONTAINER_EXISTS" ]; then
    echo "Stopping and removing existing container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    CONTAINER_EXISTS=""
fi

# If container exists but is not running, start it
if [ -n "$CONTAINER_EXISTS" ]; then
    CONTAINER_RUNNING=$(docker ps --format "{{.Names}}" | grep -w "^$CONTAINER_NAME$")
    if [ -z "$CONTAINER_RUNNING" ]; then
        echo "Container $CONTAINER_NAME exists but is not running, starting it..."
        docker start "$CONTAINER_NAME" >/dev/null
        
        # Wait for container to fully start
        sleep 2
        
        if [ "$AUTO_ATTACH" = true ]; then
            echo "Connecting to the container..."
            
            # Create a temporary function script
            cat > .yocto_temp_script.sh << 'EOF'
#!/bin/bash

# Define functions
detach() {
  echo "Detaching from container (container keeps running)..."
  echo "Container will continue running in the background."
  touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
  exit 0
}

stop_container() {
  echo "Stopping container completely..."
  touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
  exit 0
}

container_help() {
  echo "Yocto Container Commands:"
  echo "------------------------"
  echo "  - Type 'detach': Detach from container (container keeps running)"
  echo "  - Type 'stop_container': Stop the container completely (container will shut down)"
  echo "  - Type 'container_help': Show this help message"
  echo ""
  echo "Note: When you detach, a helper script on the host will monitor and restart"
  echo "      the container if needed, ensuring it continues running in the background."
  echo ""
  echo "Note: When you use 'stop_container', the container will be completely shut down and"
  echo "      will not continue running in the background."
}

# Export the functions so they're available in the shell
export -f detach
export -f stop_container
export -f container_help

# Show help message on login
echo "Welcome to the Yocto Container!"
echo "Use these commands to control the container:"
echo "  - Type 'detach' to detach from the container (container keeps running)"
echo "  - Type 'stop_container' to stop the container completely"
echo "  - Type 'container_help' for more information"
echo ""

# Start bash with the functions defined
exec bash
EOF

            chmod +x .yocto_temp_script.sh
            
            # Connect to the container with custom functions
            docker cp .yocto_temp_script.sh "$CONTAINER_NAME":/tmp/yocto_container_functions.sh
            docker exec -it "$CONTAINER_NAME" bash /tmp/yocto_container_functions.sh
            
            # Clean up
            rm -f .yocto_temp_script.sh
        else
            echo "Container $CONTAINER_NAME is now running in detached mode."
            echo "To connect to it, run: docker exec -it $CONTAINER_NAME bash"
        fi
        exit 0
    else
        if [ "$AUTO_ATTACH" = true ]; then
            echo "Container $CONTAINER_NAME is already running, connecting to it..."
            
            # Create a temporary function script
            cat > .yocto_temp_script.sh << 'EOF'
#!/bin/bash

# Define functions
detach() {
  echo "Detaching from container (container keeps running)..."
  echo "Container will continue running in the background."
  touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
  exit 0
}

stop_container() {
  echo "Stopping container completely..."
  touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
  exit 0
}

container_help() {
  echo "Yocto Container Commands:"
  echo "------------------------"
  echo "  - Type 'detach': Detach from container (container keeps running)"
  echo "  - Type 'stop_container': Stop the container completely (container will shut down)"
  echo "  - Type 'container_help': Show this help message"
  echo ""
  echo "Note: When you detach, a helper script on the host will monitor and restart"
  echo "      the container if needed, ensuring it continues running in the background."
  echo ""
  echo "Note: When you use 'stop_container', the container will be completely shut down and"
  echo "      will not continue running in the background."
}

# Export the functions so they're available in the shell
export -f detach
export -f stop_container
export -f container_help

# Show help message on login
echo "Welcome to the Yocto Container!"
echo "Use these commands to control the container:"
echo "  - Type 'detach' to detach from the container (container keeps running)"
echo "  - Type 'stop_container' to stop the container completely"
echo "  - Type 'container_help' for more information"
echo ""

# Start bash with the functions defined
exec bash
EOF

            chmod +x .yocto_temp_script.sh
            
            # Connect to the container with custom functions
            docker cp .yocto_temp_script.sh "$CONTAINER_NAME":/tmp/yocto_container_functions.sh
            docker exec -it "$CONTAINER_NAME" bash /tmp/yocto_container_functions.sh
            
            # Clean up
            rm -f .yocto_temp_script.sh
        else
            echo "Container $CONTAINER_NAME is already running in detached mode."
            echo "To connect to it, run: docker exec -it $CONTAINER_NAME bash"
        fi
        exit 0
    fi
fi

# Set detach mode
if [ "$DETACH_MODE" = true ]; then
    DETACH_FLAG="-d"
else
    DETACH_FLAG=""
fi

# Set persistence mode
if [ "$PERSISTENT" = false ]; then
    PERSISTENCE_FLAG="--rm"
else
    PERSISTENCE_FLAG=""
fi

# Run the container with a modified command that ensures it stays alive
# First, copy the bashrc file to the current directory if needed
if [ -f "$SCRIPT_DIR/yocto-container-bashrc.sh" ] && [ "$SCRIPT_DIR" != "$(pwd)" ]; then
    cp "$SCRIPT_DIR/yocto-container-bashrc.sh" ./yocto-container-bashrc.sh
fi

docker run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
    --privileged \
    --network=host \
    -v "$WORKSPACE_DIR:/workdir" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v "$SCRIPT_DIR/yocto-container-bashrc.sh:/workdir/yocto-container-bashrc.sh" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    $ADDITIONAL_ARGS \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" --workdir=/workdir \
    bash -c 'cd /workdir && \
             echo "Yocto Development Environment" && \
             echo "-------------------------" && \
             echo "Container Base Image: '"$IMAGE_NAME"'" && \
             echo "" && \
             echo "This is a CROPS/poky build environment container for Yocto development." && \
             echo "It provides the tools needed to build Yocto but does not include Poky source code." && \
             echo "" && \
             echo "To get started:" && \
             echo "1. Clone Poky with your desired version:" && \
             echo "   git clone -b <branch-name> git://git.yoctoproject.org/poky" && \
             echo "   (Examples: scarthgap, kirkstone, langdale, etc.)" && \
             echo "2. Initialize: source poky/oe-init-build-env" && \
             echo "3. Build: bitbake core-image-minimal" && \
             echo "" && \
             echo "4. Enter the environment: ./start-yocto-container.sh --name <container-name> --workspace <workspace-dir>" && \
             echo "" && \
             # First, find where we can write files
             echo "Setting up keep-alive processes..." && \
             mkdir -p /workdir/keepalive && \
             chmod 777 /workdir/keepalive && \
             # Create and run a robust keep-alive process
             echo "#!/bin/bash" > /workdir/keepalive/keep_alive.sh && \
             echo "trap \"echo Keeping container alive; exec tail -f /dev/null\" EXIT" >> /workdir/keepalive/keep_alive.sh && \
             echo "exec tail -f /dev/null" >> /workdir/keepalive/keep_alive.sh && \
             chmod +x /workdir/keepalive/keep_alive.sh && \
             echo "Starting keep-alive process to ensure container stays running..." && \
             nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 & \
             # Create a second keep-alive process as a backup
             nohup bash -c "exec tail -f /dev/null" >/dev/null 2>&1 & \
             # Use the direct command as the main process
             exec tail -f /dev/null'

# Start the container watcher in the background if this is a persistent container
if [ "$PERSISTENT" = true ] && [ -f "$(dirname "$0")/container-watch.sh" ]; then
    echo "Starting container watcher for $CONTAINER_NAME..."
    bash "$(dirname "$0")/container-watch.sh" "$CONTAINER_NAME" &
fi

# If auto-attach is enabled, connect to the container
if [ "$AUTO_ATTACH" = true ]; then
    echo "Connecting to the container..."
    # Wait a moment for the container to fully initialize
    sleep 2
    docker exec -it "$CONTAINER_NAME" bash
fi

exit 0
