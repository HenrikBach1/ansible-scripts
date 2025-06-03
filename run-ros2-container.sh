#!/bin/bash
# Script to run a ROS2 Docker container with X11 forwarding
file=run-ros2-container.sh
echo "Running script: $file"

# Default values
ROS2_DISTRO="jazzy"
CONTAINER_NAME="ros2_container"
WORKSPACE_DIR="$HOME/projects"
GPU_SUPPORT=false
CUSTOM_CMD="bash"
PERSISTENT=true # Keep the container after exit - This should become the default behavior
RUN_AS_ROOT=false
DETACH_MODE=false
AUTO_ATTACH=true
CLEAN_START=false

# Display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run a ROS2 Docker container with X11 forwarding"
    echo ""
    echo "Options:"
    echo "  -d, --distro DISTRO    ROS2 distribution (default: jazzy)"
    echo "  -n, --name NAME        Container name (default: ros2_container)"
    echo "  -w, --workspace DIR    Host workspace directory (default: $HOME/projects)"
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
    echo "  # Run with a specific ROS2 distribution"
    echo "  $0 --distro iron"
    echo ""
    echo "  # Run a ROS2 demo directly"
    echo "  $0 --cmd 'ros2 launch demo_nodes_cpp talker_listener.launch.py'"
    echo ""
    echo "  # Run with GPU support and a custom workspace"
    echo "  $0 --gpu --workspace ~/my_custom_workspace"
    echo ""
    echo "  # Create a persistent container (won't be removed on exit)"
    echo "  $0 --persistent --name my_ros2_dev"
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
        -n|--no-attach)
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
            show_help
            ;;
    esac
done

# Create workspace directory if it doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
fi

# Set the Docker image name
IMAGE_NAME="osrf/ros:${ROS2_DISTRO}-desktop"

# Check if Ansible is installed, if not install it
if ! command -v ansible &> /dev/null; then
    echo "Ansible not found. Installing Ansible..."
    sudo apt update
    sudo apt install -y ansible
    
    if ! command -v ansible &> /dev/null; then
        echo "Failed to install Ansible. Please install it manually."
        exit 1
    fi
    echo "Ansible installed successfully."
fi

# Check if the Docker image exists
if ! sudo docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo "Docker image $IMAGE_NAME not found locally."
    
    # Check if the Ansible playbook exists
    PLAYBOOK_PATH="$(dirname "$(readlink -f "$0")")/ros2-in-docker-install.yml"
    if [ -f "$PLAYBOOK_PATH" ]; then
        echo "Running Ansible playbook to set up the environment..."
        
        # Temporarily override the ROS2 distribution in the playbook
        echo "Setting up with ROS2 distribution: $ROS2_DISTRO"
        
        # Run the Ansible playbook with the selected ROS2 distribution
        ansible-playbook "$PLAYBOOK_PATH" --extra-vars "ros2_distro=$ROS2_DISTRO"
        
        # Check if the playbook succeeded
        if [ $? -ne 0 ]; then
            echo "Failed to set up the environment with the Ansible playbook."
            exit 1
        fi
    else
        echo "Ansible playbook not found at $PLAYBOOK_PATH."
        echo "Attempting to pull image directly from Docker Hub..."
        
        # Try to pull the image directly
        if ! sudo docker pull "$IMAGE_NAME"; then
            echo "Failed to pull image $IMAGE_NAME from Docker Hub."
            exit 1
        fi
    fi
fi

# Set up X11 forwarding
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# Detect if NVIDIA GPU is available
if [ "$GPU_SUPPORT" = true ]; then
    if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA GPU detected, enabling GPU support"
        GPU_OPTIONS="--gpus all"
    else
        echo "Warning: GPU support requested but NVIDIA drivers not detected"
        GPU_OPTIONS=""
    fi
else
    GPU_OPTIONS=""
fi

echo "Starting ROS2 $ROS2_DISTRO container with X11 forwarding..."
echo "Workspace directory: $WORKSPACE_DIR"
echo "Note: You can safely ignore the 'groups: cannot find name for group ID' warning."

# Check if container already exists
CONTAINER_EXISTS=$(sudo docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$")
CONTAINER_RUNNING=$(sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$")

# Clean start if requested
if [ "$CLEAN_START" = true ] && [ -n "$CONTAINER_EXISTS" ]; then
    echo "Cleaning up: Stopping and removing existing container '$CONTAINER_NAME'..."
    if [ -n "$CONTAINER_RUNNING" ]; then
        sudo docker stop $CONTAINER_NAME
    fi
    sudo docker rm $CONTAINER_NAME
    CONTAINER_EXISTS=""
    CONTAINER_RUNNING=""
fi

# Determine if we should use --rm based on persistence option
RM_OPTION=""
if [ "$PERSISTENT" = false ]; then
    # Only use --rm if not using restart=unless-stopped
    # The two options are incompatible
    echo "Note: Container will automatically be removed when stopped (using --rm)"
else
    echo "Container will be persistent (use 'docker rm $CONTAINER_NAME' to remove it later)"
fi

# Determine interactive/detach mode
INTERACTIVE_OPTION="-it"
if [ "$DETACH_MODE" = true ]; then
    INTERACTIVE_OPTION="-d"
    echo "Container will run in detached mode"
    if [ "$AUTO_ATTACH" = true ]; then
        echo "Will automatically attach to the container after starting"
    else
        echo "To attach to the container later: docker attach $CONTAINER_NAME"
    fi
else
    echo "Container will run in interactive mode"
fi

# Determine user settings
USER_OPTIONS=""
if [ "$RUN_AS_ROOT" = false ]; then
    USER_OPTIONS="--user $(id -u):$(id -g)"
    echo "Running as current user ($(id -un))"
else
    echo "Running as root user inside container"
fi

# Check container state and handle accordingly
if [ -n "$CONTAINER_RUNNING" ]; then
    # Container is already running, just attach to it
    echo "Container '$CONTAINER_NAME' is already running, attaching to it..."
    echo ""
    
    # Start the container watcher in the background before attaching
    echo "Starting container watcher to keep container running after detach..."
    "$(dirname "$(readlink -f "$0")")/container-watch.sh" $CONTAINER_NAME &
    WATCHER_PID=$!
    # Make sure the watcher process gets terminated when this script exits
    trap "kill $WATCHER_PID 2>/dev/null" EXIT
    
    sudo docker attach $CONTAINER_NAME
elif [ -n "$CONTAINER_EXISTS" ]; then
    # Container exists but is not running, start it
    echo "Container '$CONTAINER_NAME' exists but is not running, starting it..."
    sudo docker start $CONTAINER_NAME
    
    # Start the container watcher in the background before attaching
    echo "Starting container watcher to keep container running after detach..."
    "$(dirname "$(readlink -f "$0")")/container-watch.sh" $CONTAINER_NAME &
    WATCHER_PID=$!
    # Make sure the watcher process gets terminated when this script exits
    trap "kill $WATCHER_PID 2>/dev/null" EXIT
    
    # Attach to the container after starting
    echo "Attaching to container..."
    echo ""
    sudo docker attach $CONTAINER_NAME
else
    # Container doesn't exist, create and run it
    echo "Creating and running new container '$CONTAINER_NAME'..."
    
    # Determine interactive/detach mode
    INTERACTIVE_OPTION="-it"
    if [ "$DETACH_MODE" = true ]; then
        INTERACTIVE_OPTION="-d"
        echo "Container will run in detached mode"
        if [ "$AUTO_ATTACH" = true ]; then
            echo "Will automatically attach to the container after starting"
        else
            echo "To attach to the container later: docker attach $CONTAINER_NAME"
        fi
    else
        echo "Container will run in interactive mode"
    fi

    # Run the container
    sudo docker run $INTERACTIVE_OPTION $RM_OPTION \
        --name $CONTAINER_NAME \
        --network=host \
        --privileged \
        --restart=unless-stopped \
        --detach-keys="ctrl-p,ctrl-q" \
        $GPU_OPTIONS \
        -v $XSOCK:$XSOCK:rw \
        -v $XAUTH:$XAUTH:rw \
        -v "$WORKSPACE_DIR:/workspace:rw" \
        -v "$WORKSPACE_DIR:/projects:rw" \
        -v "$(dirname "$(readlink -f "$0")")/run-ros2-container-entrypoint.sh:/entrypoint.sh:ro" \
        -e DISPLAY=$DISPLAY \
        -e XAUTHORITY=$XAUTH \
        -e QT_X11_NO_MITSHM=1 \
        $USER_OPTIONS \
        --entrypoint "/entrypoint.sh" \
        $IMAGE_NAME $ROS2_DISTRO "$CUSTOM_CMD"
    
    # Start the container watcher in the background
    echo "Starting container watcher to keep container running after detach..."
    "$(dirname "$(readlink -f "$0")")/container-watch.sh" $CONTAINER_NAME &
    WATCHER_PID=$!
    # Make sure the watcher process gets terminated when this script exits
    trap "kill $WATCHER_PID 2>/dev/null" EXIT
    
    # Automatically attach to container if in detached mode
    if [ "$DETACH_MODE" = true ] && [ "$AUTO_ATTACH" = true ]; then
        echo "Automatically attaching to container $CONTAINER_NAME..."
        echo ""
        sleep 1
        sudo docker attach $CONTAINER_NAME
    fi
fi

# Clean up temporary script
# No init script to clean up now that we use a permanent entrypoint script

# Check if the stop marker file exists inside the container (or was detected by watcher)
STOP_REQUESTED=false
if sudo docker exec $CONTAINER_NAME test -f /home/ubuntu/.container_stop_requested 2>/dev/null; then
    STOP_REQUESTED=true
fi

# If stop was requested, don't show the "still running" message
if [ "$STOP_REQUESTED" = true ]; then
    echo "Container '$CONTAINER_NAME' has been requested to stop"
    echo "Container is being stopped..."
    
    # Force container to stop
    sudo docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
    sudo docker kill $CONTAINER_NAME >/dev/null 2>&1 || true
    
    # Check if it's actually stopped
    if ! sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" &>/dev/null; then
        echo "Container has been successfully stopped."
    else
        echo "Warning: Container could not be stopped. Please try: docker stop $CONTAINER_NAME"
    fi
else
    # Check if we've exited the container and it's still running
    CONTAINER_STILL_RUNNING=$(sudo docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$")

    # Check if the detach marker file exists inside the container
    DETACH_REQUESTED=false
    if sudo docker exec $CONTAINER_NAME test -f /home/ubuntu/.container_detach_requested 2>/dev/null; then
        DETACH_REQUESTED=true
        # Remove the marker file
        sudo docker exec $CONTAINER_NAME rm -f /home/ubuntu/.container_detach_requested 2>/dev/null
    fi

    if [ -n "$CONTAINER_STILL_RUNNING" ] || [ "$DETACH_REQUESTED" = true ]; then
        echo "Container '$CONTAINER_NAME' is still running"
        echo "You have detached from the container (it continues running in the background)"
        
        # If container stopped but detach was requested, restart it
        if [ -z "$CONTAINER_STILL_RUNNING" ] && [ "$DETACH_REQUESTED" = true ]; then
            echo "Restarting container after detach..."
            sudo docker start $CONTAINER_NAME
        fi
    else
        echo "Container session ended"
    fi
fi

# Remove the duplicate container status check that was causing double messages
# (This block was redundant with the previous if-else block)
else
    echo "Container session ended"
fi

# Show additional container management information
if [ -n "$CONTAINER_STILL_RUNNING" ] || [ "$PERSISTENT" = true ] && [ "$STOP_REQUESTED" = false ]; then
    echo ""
    echo "Container Management Commands:"
    echo "  - Attach to container:  docker attach $CONTAINER_NAME"
    echo "  - List containers:      docker ps"
    echo "  - Stop container:       docker stop $CONTAINER_NAME"
    echo "  - Remove container:     docker rm $CONTAINER_NAME"
    echo ""
    echo "Once attached to the container, you can use the following commands:"
    echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
    echo "  - Press Ctrl+P Ctrl+Q: Standard Docker detach sequence"
    echo "  - Type 'stop': Stop the container completely (container will shut down)"
    echo "  - Type 'container-help': Show detailed help message"
echo ""
fi
