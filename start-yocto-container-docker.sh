#!/bin/bash
# Script to run a Yocto Docker container with appropriate settings
file=start-yocto-container-docker.sh
echo "Running script: $file"

# Check for Ubuntu 24.04 and warn about BitBake compatibility issues
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "24.04" ]]; then
        echo "⚠️  WARNING: Ubuntu 24.04 Detected ⚠️"
        echo ""
        echo "Ubuntu 24.04 introduces user namespace restrictions that can cause"
        echo "BitBake builds to fail in Docker containers with errors like:"
        echo "  - 'unable to set up user namespaces'"
        echo "  - 'newuidmap/newgidmap permission issues'"
        echo "  - 'pseudo: FATAL: execvp failed'"
        echo ""
        echo "🐋 RECOMMENDED SOLUTION: Use Podman instead of Docker"
        echo ""
        echo "Podman runs rootless by default and avoids these namespace conflicts."
        echo "This repository includes equivalent Podman scripts:"
        echo ""
        echo "  Instead of: ./start-yocto-container-docker.sh"
        echo "  Use:        ./start-yocto-container-podman.sh"
        echo ""
        echo "To install Podman and set up Yocto development:"
        echo "  1. ansible-playbook podman-install.yml"
        echo "  2. ansible-playbook yocto-in-podman-install.yml"
        echo "  3. ./start-yocto-container-podman.sh"
        echo ""
        echo "For VS Code integration:"
        echo "  ./setup-vscode-podman.sh"
        echo "  ./vscode-with-podman.sh"
        echo ""
        read -p "Continue with Docker anyway? (not recommended) [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Exiting. Please use the Podman-based scripts for Ubuntu 24.04."
            echo ""
            echo "Quick setup:"
            echo "  ansible-playbook podman-install.yml"
            echo "  ./start-yocto-container-podman.sh"
            exit 0
        fi
        echo ""
        echo "⚠️  Proceeding with Docker (may encounter BitBake issues)..."
        echo ""
    fi
fi

# Store original arguments
ORIGINAL_ARGS="$@"

# Source the common container runner
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/run-container-common.sh"

# Default values
ENV_TYPE="yocto"
CONTAINER_NAME="yocto_container"
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
    echo "  --restart              Stop and remove existing container before starting"
    echo "  --save-config          Save current configuration for future use"
    echo "  --list-configs         List all saved container configurations"
    echo "  --show-config NAME     Show detailed configuration for a specific container"
    echo "  --show-running         Show configurations for all running containers"
    echo "  --remove-config NAME   Remove a saved container configuration"
    echo "  --cleanup-configs [N]  Remove configurations not used in N days (default: 30)"
    echo "  --fix [NAME]           Fix a container that keeps exiting"
    echo "  --stop [NAME]          Stop the container"
    echo "  --restart [NAME]       Stop and restart the container (same as --stop then start)"
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
    echo "  # Restart container (stop and remove existing container first)"
    echo "  $0 --restart"
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
    echo "  # Restart the default container"
    echo "  $0 --restart"
    echo ""
    echo "  # Restart a specific container"
    echo "  $0 --restart my_yocto_dev"
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
    echo ""
    echo "Development Tools:"
    echo "The container automatically installs nano, vim, curl, wget, and git for development."
    echo ""
    echo "Ubuntu 24.04+ Compatibility:"
    echo "This script includes security options to handle Ubuntu 24.04+ user namespace restrictions"
    echo "that can affect BitBake builds. If you encounter namespace errors, consider using the"
    echo "Podman-based alternative: ./start-yocto-container-podman.sh"
    echo ""
    echo "For Ubuntu 24.04+, Podman is recommended over Docker for Yocto development:"
    echo "  ./start-yocto-container-podman.sh  # Recommended for Ubuntu 24.04+"
    echo "  ./setup-vscode-podman.sh           # For VS Code integration"
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
    if [[ "$arg" == "--verify" ]]; then
        # If a container name is provided, use it
        if [[ -n "$2" ]]; then
            VERIFY_CONTAINER="$2"
            shift
        else
            # Otherwise, use the default container name
            VERIFY_CONTAINER="$CONTAINER_NAME"
        fi
        verify_container "$VERIFY_CONTAINER"
        exit 0
    fi
done

# Auto-install Docker if not available (but still recommend Podman for Ubuntu 24.04)
if ! command -v docker >/dev/null 2>&1; then
    echo "⚠️  Docker not found. Installing Docker automatically..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -f "$SCRIPT_DIR/docker-install.yml" ]; then
        echo "Running Docker installation playbook..."
        if ansible-playbook "$SCRIPT_DIR/docker-install.yml"; then
            echo "✅ Docker installed successfully"
            # Add user to docker group and note about logout/login
            echo "Note: You may need to log out and back in for Docker group permissions to take effect"
            # Source the new environment
            hash -r  # Clear command cache
        else
            echo "❌ Failed to install Docker automatically"
            echo "Please install Docker manually or run: ansible-playbook docker-install.yml"
            exit 1
        fi
    else
        echo "❌ Docker installation playbook not found at $SCRIPT_DIR/docker-install.yml"
        echo "Please install Docker manually or use the Podman-based scripts instead"
        exit 1
    fi
fi

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
ADDITIONAL_ARGS=""  # Clear additional args - let CROPS handle defaults
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

# Clean up any container-related files that might be in the workspace
# This prevents workspace pollution from previous container runs
if [ -d "$WORKSPACE_DIR" ]; then
    echo "Cleaning up container system files from workspace..."
    # Run the dedicated cleanup script if it exists
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -x "$SCRIPT_DIR/cleanup-container-temp-files.sh" ]; then
        "$SCRIPT_DIR/cleanup-container-temp-files.sh"
    else
        # Fallback to basic cleanup if script doesn't exist
        # Remove container system files if they exist
        rm -f "$WORKSPACE_DIR/container-init.sh" 2>/dev/null || true
        rm -rf "$WORKSPACE_DIR/keepalive" 2>/dev/null || true
    fi
fi

# Create a startup script for the container
cat > /tmp/yocto-container-startup.sh << 'EOF'
#!/bin/bash
cd /workdir || cd /
echo "Yocto Development Environment"
echo "-------------------------"
echo ""
echo "This is a CROPS/poky build environment container for Yocto development."
echo "It provides the tools needed to build Yocto but does not include Poky source code."
echo ""
echo "To get started:"
echo "1. Clone Poky with your desired version:"
echo "   git clone -b <branch-name> git://git.yoctoproject.org/poky"
echo "   (Examples: scarthgap, kirkstone, langdale, etc.)"
echo "2. Initialize: source poky/oe-init-build-env"
echo "3. Build: bitbake core-image-minimal"
echo ""
echo "Container is now running and ready for development."
echo "Use 'docker exec -it $CONTAINER_NAME bash' to connect."
echo ""
# Keep the container running with a simple approach
exec tail -f /dev/null
EOF

# Get current user and group IDs for CROPS container
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Run the container with CROPS-specific parameters
docker run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
    --privileged \
    --network=host \
    -v "$WORKSPACE_DIR:/workdir" \
    -v "$WORKSPACE_DIR:/workspace" \
    -v "$WORKSPACE_DIR:/projects" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    $ADDITIONAL_ARGS \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" \
    --workdir=/workdir \
    --id=$USER_ID:$GROUP_ID \
    bash -c 'echo "Yocto Development Environment"; echo "-------------------------"; echo "This is a CROPS/poky build environment container for Yocto development."; echo "Container is ready for development."; exec tail -f /dev/null'

# Start the container watcher in the background if this is a persistent container
if [ "$PERSISTENT" = true ] && [ -f "$(dirname "$0")/container-watch.sh" ]; then
    echo "Starting container watcher for $CONTAINER_NAME..."
    bash "$(dirname "$0")/container-watch.sh" "$CONTAINER_NAME" &
fi

# Add container commands to the container
if [ -f "$(dirname "$0")/container-shell-setup.sh" ]; then
    echo "Setting up container environment for $CONTAINER_NAME..."
    # Give the container a moment to start and verify it's running
    sleep 3
    
    # Check if container is actually running before trying to exec
    if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        # Copy the unified setup script to container
        if docker cp "$(dirname "$0")/container-shell-setup.sh" "$CONTAINER_NAME:/tmp/container-shell-setup.sh"; then
            # Run the setup script inside the container as root to ensure system-wide installation
            docker exec -u root "$CONTAINER_NAME" bash /tmp/container-shell-setup.sh 2>/dev/null || {
                echo "Warning: Failed to run setup script as root, trying as regular user"
            }
            
            # Also run as regular user to set up user-specific files (.shrc, etc.)
            docker exec "$CONTAINER_NAME" bash /tmp/container-shell-setup.sh 2>/dev/null || {
                echo "Warning: Failed to run setup script as regular user"
            }
            
            echo "Container environment setup completed."
        else
            echo "Warning: Failed to copy setup script to container"
        fi
    else
        echo "Warning: Container $CONTAINER_NAME is not running, skipping environment setup"
        # Try to start the container if it's not running
        echo "Attempting to start container..."
        if docker start "$CONTAINER_NAME" >/dev/null 2>&1; then
            echo "Container started successfully"
            sleep 2
            # Retry the setup
            if docker cp "$(dirname "$0")/container-shell-setup.sh" "$CONTAINER_NAME:/tmp/container-shell-setup.sh"; then
                docker exec "$CONTAINER_NAME" bash /tmp/container-shell-setup.sh 2>/dev/null || true
                echo "Container environment setup completed after restart."
            fi
        else
            echo "Error: Could not start container $CONTAINER_NAME"
        fi
    fi
fi

# If auto-attach is enabled, connect to the container
if [ "$AUTO_ATTACH" = true ]; then
    echo "Connecting to the container..."
    # Wait a moment for the container to fully initialize
    sleep 2
    docker exec -it "$CONTAINER_NAME" bash
fi

exit 0

# Function to verify workspace paths
verify_workspace_paths() {
    local CONTAINER_NAME="$1"
    echo "Verifying workspace paths for $CONTAINER_NAME..."
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
        echo "Container $CONTAINER_NAME is not running. Starting it..."
        docker start "$CONTAINER_NAME" > /dev/null 2>&1
        sleep 2
    fi
    
    # Check the mount points
    echo "Checking container mount points..."
    local MOUNTS=$(docker inspect --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{printf "\n"}}{{end}}' "$CONTAINER_NAME")
    echo "$MOUNTS"
    
    # Verify workspace structure
    echo "Verifying workspace directory structure..."
    docker exec -it "$CONTAINER_NAME" bash -c "
        # Make sure all workspace directories exist
        mkdir -p /workdir 2>/dev/null || true
        mkdir -p /workspace 2>/dev/null || true
        mkdir -p /projects 2>/dev/null || true
        
        # Fix symlinks to ensure compatibility
        rm -f /workspace 2>/dev/null || true
        rm -f /workdir 2>/dev/null || true
        ln -sf /projects /workspace 2>/dev/null || true
        ln -sf /projects /workdir 2>/dev/null || true
        
        echo 'Current workspace structure:'
        ls -la / | grep -E 'projects|workdir|workspace'
    "
    
    echo "Workspace path verification complete."
}

# Add --verify-workspace option parsing
for arg in "$@"; do
    case $arg in
        --verify-workspace)
            VERIFY_WORKSPACE=true
            shift
            ;;
    esac
done

# If verify workspace is requested, run it after container is started
if [ "$VERIFY_WORKSPACE" = true ]; then
    verify_workspace_paths "$CONTAINER_NAME"
fi
