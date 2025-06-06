#!/bin/bash
# Script to run a ROS2 Docker container with X11 forwarding
file=run-ros2-container.sh
echo "Running script: $file"

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
DETACH_MODE=false
AUTO_ATTACH=true
CLEAN_START=false

# Display help message
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_container_help "ROS2" "$ROS2_DISTRO" "distro" "$WORKSPACE_DIR"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--distro)
            ROS2_DISTRO="$2"
            shift 2
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
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
        --no-attach)
            AUTO_ATTACH=false
            shift
            ;;
        --clean)
            CLEAN_START=true
            shift
            ;;
        -h|--help)
            show_container_help "ROS2" "$ROS2_DISTRO" "distro" "$WORKSPACE_DIR"
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
    "$ENTRYPOINT_SCRIPT"

exit 0
