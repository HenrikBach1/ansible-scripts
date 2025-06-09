#!/bin/bash
# Script to run a ROS2 Docker container with X11 forwarding
file=start-ros2-container.sh
echo "Running script: $file"

# Store original arguments
ORIGINAL_ARGS="$@"

# Source the common container runner
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run-container-common.sh"

# Default values
ENV_TYPE="ros2"
ROS2_DISTRO="jazzy"
CONTAINER_NAME="ros2_container"
WORKSPACE_DIR="$HOME/projects"
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

# Function to display specialized help for ROS2
show_ros2_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run a ROS2 Docker container with appropriate settings"
    echo ""
    echo "Options:"
    echo "  -d, --distro DISTRO    ROS2 distro (default: $ROS2_DISTRO)"
    echo "  -n, --name NAME        Container name (default: $CONTAINER_NAME)"
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
    echo "  # Create a container with a specific ROS2 distro"
    echo "  $0 --distro humble"
    echo ""
    echo "  # Create a container with a custom name"
    echo "  $0 --name my_ros2_dev"
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
    echo "  $0 --stop my_ros2_dev"
    echo ""
    echo "  # Remove the default container (stops it first if running)"
    echo "  $0 --remove"
    echo ""
    echo "  # Remove a specific container"
    echo "  $0 --remove my_ros2_dev"
    echo ""
    echo "Note: By default, containers run in detached mode."
    echo "To connect to a running container:"
    echo "  - Run: ./ros2-connect"
    echo "  - Or run: docker exec -it ros2_container bash"
    echo ""
    echo "In the container, you can use these commands:"
    echo "  - Type 'detach' to detach from the container (container keeps running)"
    echo "  - Type 'stop' to stop the container"
    echo "  - Type 'remove' to stop and remove the container"
    echo "  - Type 'help' for more information"
    echo ""
    echo "Legacy commands for backward compatibility:"
    echo "  - Type 'stop_container' (same as 'stop')"
    echo "  - Type 'container_help' (same as 'help')"
    echo ""
    exit 0
}

# Display help message
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_ros2_help
    exit 0
fi

# Check if we need to handle configuration options before parsing other arguments
for arg in "$@"; do
    if [[ "$arg" == "--list-configs" ]]; then
        list_container_configs
        exit 0
    fi
    if [[ "$arg" == "--fix" ]]; then
        if [[ -n "$2" ]]; then
            fix_container_exit "$2"
            exit $?
        else
            fix_container_exit "$CONTAINER_NAME"
            exit $?
        fi
    fi
    if [[ "$arg" == "--stop" ]]; then
        if [[ -n "$2" && "$2" != -* ]]; then
            stop_container "$2"
            exit $?
        else
            stop_container "$CONTAINER_NAME"
            exit $?
        fi
    fi
    if [[ "$arg" == "--remove" ]]; then
        if [[ -n "$2" && "$2" != -* ]]; then
            remove_container "$2"
            exit $?
        else
            remove_container "$CONTAINER_NAME"
            exit $?
        fi
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
        -d|--distro)
            ROS2_DISTRO="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            # Check if we have a saved configuration for this container name
            if [ "$(container_config_exists "$CONTAINER_NAME")" = "true" ]; then
                # Get saved config values
                ENV_TYPE=$(load_container_config "$CONTAINER_NAME" "env_type" "$ENV_TYPE")
                ROS2_DISTRO=$(load_container_config "$CONTAINER_NAME" "env_version" "$ROS2_DISTRO")
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
            debug_container_config
            exit 0
            ;;
        --list-configs)
            list_container_configs
            exit 0
            ;;
        -h|--help)
            show_ros2_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Container image selection
# For custom builds, use ros2_workspace:$ROS2_DISTRO
# For standard builds, use osrf/ros:$ROS2_DISTRO-desktop
IMAGE_NAME="osrf/ros:$ROS2_DISTRO-desktop"
if [ -n "$(docker images -q ros2_workspace:$ROS2_DISTRO 2>/dev/null)" ]; then
    IMAGE_NAME="ros2_workspace:$ROS2_DISTRO"
    echo "Using custom ROS2 image: $IMAGE_NAME"
else
    echo "Using standard OSRF ROS2 image: $IMAGE_NAME"
fi

# Additional environment variables
ADDITIONAL_ARGS="-e ROS_DOMAIN_ID=0"

# Entrypoint script path
ENTRYPOINT_SCRIPT="$SCRIPT_DIR/run-ros2-container-entrypoint.sh"

# Run the container
run_container \
    "$ENV_TYPE" \
    "$ROS2_DISTRO" \
    "$CONTAINER_NAME" \
    "$WORKSPACE_DIR" \
    "$PERSISTENT" \
    "$RUN_AS_ROOT" \
    "$DETACH_MODE" \
    "$AUTO_ATTACH" \
    "$CLEAN_START" \
    "$GPU_SUPPORT" \
    "$IMAGE_NAME" \
    "$CUSTOM_CMD" \
    "$ADDITIONAL_ARGS" \
    "$ENTRYPOINT_SCRIPT" \
    "$SAVE_CONFIG" \
    "$ORIGINAL_ARGS"

exit 0
