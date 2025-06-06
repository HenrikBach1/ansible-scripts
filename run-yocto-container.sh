#!/bin/bash
# Script to run a Yocto Docker container with appropriate settings
file=run-yocto-container.sh
echo "Running script: $file"

# Source the common container runner
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run-container-common.sh"

# Default values
ENV_TYPE="yocto"
YOCTO_RELEASE="kirkstone"
CONTAINER_NAME="yocto_container"
WORKSPACE_DIR="$HOME/yocto_ws"
GPU_SUPPORT=false
CUSTOM_CMD="bash"
PERSISTENT=true
RUN_AS_ROOT=false
DETACH_MODE=false
AUTO_ATTACH=true
CLEAN_START=false

# Display help message
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_container_help "Yocto" "$YOCTO_RELEASE" "release" "$WORKSPACE_DIR"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--release)
            YOCTO_RELEASE="$2"
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
            show_container_help "Yocto" "$YOCTO_RELEASE" "release" "$WORKSPACE_DIR"
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Container image selection
# For custom builds, use yocto_workspace:$YOCTO_RELEASE
# For standard builds, use crops/poky:$YOCTO_RELEASE
IMAGE_NAME="crops/poky:$YOCTO_RELEASE"
if [ -n "$(docker images -q yocto_workspace:$YOCTO_RELEASE 2>/dev/null)" ]; then
    IMAGE_NAME="yocto_workspace:$YOCTO_RELEASE"
    echo "Using custom Yocto image: $IMAGE_NAME"
else
    echo "Using standard Crops Yocto image: $IMAGE_NAME"
fi

# Additional environment variables
ADDITIONAL_ARGS="-e TEMPLATECONF=/home/$(id -u)/yocto_ws/meta-custom/conf/templates/default"

# Entrypoint script path
ENTRYPOINT_SCRIPT="$SCRIPT_DIR/run-yocto-container-entrypoint.sh"

# Run the container
run_container \
    "$ENV_TYPE" \
    "$YOCTO_RELEASE" \
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
