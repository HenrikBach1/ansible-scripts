#!/bin/bash
# Script to run a Yocto Docker container with X11 forwarding
file=run-yocto-container.sh
echo "Running script: $file"

# Default values
YOCTO_RELEASE="kirkstone"
CONTAINER_NAME="yocto_container"
WORKSPACE_DIR="$HOME/yocto_ws"
GPU_SUPPORT=false
CUSTOM_CMD="bash"
PERSISTENT=false
RUN_AS_ROOT=false
DETACH_MODE=false
AUTO_ATTACH=true
CLEAN_START=false

# Display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run a Yocto Docker container with appropriate mounts and settings"
    echo ""
    echo "Options:"
    echo "  -d, --release RELEASE  Yocto release (default: kirkstone)"
    echo "  -n, --name NAME        Container name (default: yocto_container)"
    echo "  -w, --workspace DIR    Host workspace directory (default: $HOME/yocto_ws)"
    echo "  -g, --gpu              Enable NVIDIA GPU support (if available)"
    echo "  -c, --cmd CMD          Command to run in container (default: bash)"
    echo "  -p, --persistent       Keep container after exit (don't use --rm)"
    echo "  -r, --root             Run container as root user instead of current user"
    echo "  -D, --detach           Run container in detached mode"
    echo "  -n, --no-attach        Don't automatically attach to detached containers"
    echo "  --clean                Stop and remove existing container before starting"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Examples:"
    echo "  # Basic usage (runs bash shell in the container)"
    echo "  $0"
    echo ""
    echo "  # Run with a specific Yocto release"
    echo "  $0 --release dunfell"
    echo ""
    echo "  # Run with a custom workspace"
    echo "  $0 --workspace ~/my_custom_workspace"
    echo ""
    echo "  # Create a persistent container (won't be removed on exit)"
    echo "  $0 --persistent --name my_yocto_dev"
    echo ""
    echo "  # Run as root (useful for installing packages inside the container)"
    echo "  $0 --root"
    echo ""
    echo "  # Run in detached mode (container keeps running in background)"
    echo "  $0 --detach"
    echo ""
    echo "  # Run in detached mode without auto-attaching"
    echo "  $0 --detach --no-attach"
    echo ""
    echo "  # Clean start (stop and remove existing container first)"
    echo "  $0 --clean"
    echo ""
    echo "Note: To reattach to a detached container:"
    echo "  - Run: docker attach $CONTAINER_NAME"
    echo ""
    echo "Note: This script is idempotent. If the container already exists:"
    echo "  - If running, it will attach to it"
    echo "  - If stopped, it will start it and attach to it"
    echo "  - If it doesn't exist, it will create a new container"
    exit 0
}

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
            show_help
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
PERSISTENCE_FLAG="--rm"
if [ "$PERSISTENT" = true ]; then
    PERSISTENCE_FLAG=""
fi

# Detach mode
DETACH_FLAG=""
if [ "$DETACH_MODE" = true ]; then
    DETACH_FLAG="-d"
fi

# Prepare additional environment variables
ENV_VARS="-e DISPLAY -e TEMPLATECONF=/home/$(id -u)/yocto_ws/meta-custom/conf/templates/default"

# Copy gitconfig template if it exists
if [ -f "$WORKSPACE_DIR/.gitconfig.template" ] && [ ! -f "$HOME/.gitconfig" ]; then
    cp "$WORKSPACE_DIR/.gitconfig.template" "$HOME/.gitconfig"
    echo "Created .gitconfig from template"
fi

# Prepare entrypoint and command
ENTRYPOINT_SCRIPT="$WORKSPACE_DIR/run-yocto-container-entrypoint.sh"
ENTRYPOINT_CMD=""

if [ -f "$ENTRYPOINT_SCRIPT" ]; then
    echo "Using custom entrypoint script: $ENTRYPOINT_SCRIPT"
    ENTRYPOINT_CMD="--entrypoint $ENTRYPOINT_SCRIPT"
fi

# Run the Yocto container with appropriate options
echo "Starting Yocto container with release $YOCTO_RELEASE..."

docker run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
    $USER_OPTIONS \
    --privileged \
    --network=host \
    -v "$WORKSPACE_DIR:/home/$(id -u)/yocto_ws" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    $ENV_VARS \
    --name "$CONTAINER_NAME" \
    $ENTRYPOINT_CMD \
    "$IMAGE_NAME" $YOCTO_RELEASE "$CUSTOM_CMD"

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

exit 0
