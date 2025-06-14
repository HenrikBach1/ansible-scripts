#!/bin/bash
# Script to run a Yocto Podman container with appropriate settings
file=start-yocto-container-podman.sh
echo "Running script: $file"

# Store original arguments
ORIGINAL_ARGS="$@"

# Default values
ENV_TYPE="yocto"
CONTAINER_NAME="yocto_container_podman"
WORKSPACE_DIR="$HOME/projects"
GPU_SUPPORT=false
CUSTOM_CMD="bash"
PERSISTENT=true
RUN_AS_ROOT=false
DETACH_MODE=true
AUTO_ATTACH=false
CLEAN_START=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display specialized help for Yocto
show_yocto_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run a Yocto Podman container with appropriate settings"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME        Container name (default: yocto_container_podman)"
    echo "  -w, --workspace DIR    Host workspace directory (default: $WORKSPACE_DIR)"
    echo "  -g, --gpu              Enable GPU support (if available)"
    echo "  -c, --cmd CMD          Command to run in container (default: bash)"
    echo "  -p, --persistent       Keep container after exit (enabled by default)"
    echo "  -r, --root             Run container as root user instead of current user"
    echo "  -D, --detach           Run container in detached mode (enabled by default)"
    echo "  --attach               Automatically attach to container after starting"
    echo "  --restart              Stop and remove existing container before starting"
    echo "  --stop [NAME]          Stop the container"
    echo "  --remove [NAME]        Stop and remove the container"
    echo "  --fix [NAME]           Fix a container that keeps exiting"
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
    echo "  # Restart container (stop and remove existing container first)"
    echo "  $0 --restart"
    echo ""
    echo "  # Stop the default container"
    echo "  $0 --stop"
    echo ""
    echo "  # Remove the default container (stops it first if running)"
    echo "  $0 --remove"
    echo ""
    echo "Note: By default, containers run in detached mode."
    echo "To connect to a running container:"
    echo "  - Run: podman exec -it $CONTAINER_NAME bash"
    echo ""
    echo "This Podman version may work better with Ubuntu 24.04+ user namespace restrictions."
    echo "It uses --userns=keep-id and --security-opt label=disable for compatibility."
    exit 0
}

# Stop container function
stop_container() {
    local container_name="${1:-$CONTAINER_NAME}"
    log_info "Stopping container $container_name"
    if podman ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        podman stop "$container_name"
        log_success "Container $container_name stopped"
    else
        log_warn "Container $container_name is not running"
    fi
}

# Remove container function
remove_container() {
    local container_name="${1:-$CONTAINER_NAME}"
    log_info "Stopping and removing container $container_name"
    podman stop "$container_name" 2>/dev/null || true
    podman rm "$container_name" 2>/dev/null || true
    log_success "Container $container_name removed"
}

# Check if we need to handle special options before parsing other arguments
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_yocto_help
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
        if ! podman ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_TO_FIX$" > /dev/null; then
            echo "Container '$CONTAINER_TO_FIX' does not exist."
            exit 1
        fi
        
        # Get container status
        local STATUS=$(podman inspect --format='{{.State.Status}}' "$CONTAINER_TO_FIX")
        echo "Container status: $STATUS"
        
        # If container is not running, start it
        if [ "$STATUS" != "running" ]; then
            echo "Starting container..."
            podman start "$CONTAINER_TO_FIX"
            sleep 2
        fi
        
        # Add keep-alive mechanisms
        echo "Adding robust keep-alive mechanisms to container..."
        podman exec "$CONTAINER_TO_FIX" bash -c '
            mkdir -p /workdir/keepalive
            chmod 777 /workdir/keepalive
            
            echo "#!/bin/bash" > /workdir/keepalive/keep_alive.sh
            echo "trap \"echo Keeping container alive; exec tail -f /dev/null\" EXIT" >> /workdir/keepalive/keep_alive.sh
            echo "exec tail -f /dev/null" >> /workdir/keepalive/keep_alive.sh
            chmod +x /workdir/keepalive/keep_alive.sh
            
            nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
            nohup bash -c "exec tail -f /dev/null" >/dev/null 2>&1 &
            nohup /workdir/keepalive/keep_alive.sh >/dev/null 2>&1 &
            
            echo "Robust keep-alive processes started"
        '
        
        echo "Container fixed. It should now remain running."
        echo "To connect: podman exec -it $CONTAINER_TO_FIX bash"
        exit 0
    fi
done

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --attach)
            AUTO_ATTACH=true
            shift
            ;;
        --restart)
            CLEAN_START=true
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
IMAGE_NAME="docker.io/crops/poky:${CONTAINER_BASE}"

# Verify the crops/poky image exists or pull it
if [ -z "$(podman images -q $IMAGE_NAME 2>/dev/null)" ]; then
    echo "Pulling CROPS/poky image: $IMAGE_NAME..."
    podman pull $IMAGE_NAME || {
        echo "ERROR: Failed to pull $IMAGE_NAME image."
        echo "Available tags include: ubuntu-22.04, ubuntu-20.04, debian-11, fedora-36, etc."
        exit 1
    }
fi

# Check if container already exists and handle CLEAN_START
CONTAINER_EXISTS=$(podman ps -a --format "{{.Names}}" | grep -w "^$CONTAINER_NAME$")
if [ "$CLEAN_START" = true ] && [ -n "$CONTAINER_EXISTS" ]; then
    log_info "Cleaning up existing container $CONTAINER_NAME"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
    CONTAINER_EXISTS=""
fi

# If container exists but is not running, start it
if [ -n "$CONTAINER_EXISTS" ]; then
    CONTAINER_STATUS=$(podman inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$CONTAINER_STATUS" = "running" ]; then
        log_info "Container $CONTAINER_NAME is already running"
        if [ "$AUTO_ATTACH" = true ]; then
            log_info "Attaching to running container..."
            podman exec -it "$CONTAINER_NAME" bash
        fi
        exit 0
    else
        log_info "Starting existing container $CONTAINER_NAME"
        podman start "$CONTAINER_NAME"
        if [ "$AUTO_ATTACH" = true ]; then
            log_info "Attaching to container..."
            podman exec -it "$CONTAINER_NAME" bash
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

# Set GPU options (if supported)
GPU_OPTIONS=""
if [ "$GPU_SUPPORT" = true ]; then
    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_OPTIONS="--device nvidia.com/gpu=all"
        log_info "GPU support enabled"
    else
        log_warn "GPU support requested but nvidia-smi not found"
    fi
fi

# Create a startup script for the container
cat > /tmp/yocto-container-startup.sh << 'EOF'
#!/bin/bash
cd /workdir || cd /
echo "Yocto Development Environment (Podman)"
echo "------------------------------------"
echo ""
echo "This is a CROPS/poky build environment container for Yocto development using Podman."
echo "It provides the tools needed to build Yocto but does not include Poky source code."
echo ""
echo "To get started:"
echo "1. Clone Poky with your desired version:"
echo "   git clone -b <branch-name> git://git.yoctoproject.org/poky"
echo "   (Examples: scarthgap, kirkstone, langdale, etc.)"
echo "2. Initialize: source poky/oe-init-build-env"
echo "3. Build: bitbake core-image-minimal"
echo ""
echo "Container is now running with Podman and ready for development."
echo ""
# Keep the container running with a simple approach
exec tail -f /dev/null
EOF

# Get current user and group IDs for CROPS container
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Set user options
if [ "$RUN_AS_ROOT" = true ]; then
    USER_OPTIONS="--user root"
else
    USER_OPTIONS="--user $USER_ID:$GROUP_ID --userns=keep-id"
fi

# Run the container with Podman-specific parameters
log_info "Creating Yocto container with Podman..."
log_info "Container: $CONTAINER_NAME"
log_info "Image: $IMAGE_NAME"
log_info "Workspace: $WORKSPACE_DIR"

podman run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
    --name "$CONTAINER_NAME" \
    --hostname yocto-podman \
    $USER_OPTIONS \
    --workdir /workdir \
    --security-opt label=disable \
    --cap-add SYS_ADMIN \
    --tmpfs /tmp \
    --tmpfs /var/tmp \
    -v "$WORKSPACE_DIR:/workdir" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v /tmp/yocto-container-startup.sh:/container-startup.sh \
    -e "TEMPLATECONF=" \
    -e "OE_TERMINAL=screen" \
    --privileged \
    "$IMAGE_NAME" \
    bash /container-startup.sh

if [ $? -eq 0 ]; then
    log_success "Container $CONTAINER_NAME started successfully with Podman"
    
    # Add container shell setup if available
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/container-shell-setup.sh" ]; then
        log_info "Setting up container environment..."
        podman cp "$SCRIPT_DIR/container-shell-setup.sh" "$CONTAINER_NAME:/tmp/"
        podman exec "$CONTAINER_NAME" bash -c 'chmod +x /tmp/container-shell-setup.sh && /tmp/container-shell-setup.sh' || true
    fi
    
    # If auto-attach is enabled, connect to the container
    if [ "$AUTO_ATTACH" = true ]; then
        log_info "Attaching to container..."
        podman exec -it "$CONTAINER_NAME" bash
    else
        echo ""
        echo "Container is running in detached mode."
        echo "To connect: podman exec -it $CONTAINER_NAME bash"
        echo ""
    fi
else
    log_error "Failed to start container with Podman"
    exit 1
fi

exit 0
