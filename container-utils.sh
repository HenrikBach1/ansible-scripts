#!/bin/bash
# Container utilities and shared functions for ROS2 and Yocto containers
# This script provides common functions for container management

# Container types supported
SUPPORTED_CONTAINERS=("ros2" "yocto")

# Get the absolute directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to validate container type
validate_container_type() {
    local container_type="$1"
    for valid_type in "${SUPPORTED_CONTAINERS[@]}"; do
        if [ "$container_type" = "$valid_type" ]; then
            return 0
        fi
    done
    echo "Error: Invalid container type '$container_type'. Supported types: ${SUPPORTED_CONTAINERS[*]}"
    return 1
}

# Function to create a robust container with direct approach
create_robust_container() {
    local container_type="$1"
    local container_name="$2"
    local workspace_dir="$3"
    local env_version="${4:-latest}"
    
    # Validate container type
    validate_container_type "$container_type" || return 1
    
    # Set default image based on container type
    local image_name=""
    local env_setup_command=""
    case "$container_type" in
        "ros2")
            image_name="osrf/ros:${env_version}-desktop"
            env_setup_command="source /opt/ros/${env_version}/setup.bash"
            ;;
        "yocto")
            # For Yocto, we need to specify the base image version (typically ubuntu-22.04)
            if [[ "$env_version" != *:* ]]; then
                image_name="crops/poky:${env_version}"
            else
                image_name="${env_version}"
            fi
            env_setup_command=""
            ;;
        *)
            echo "Error: Unsupported container type: $container_type"
            return 1
            ;;
    esac
    
    echo "Creating robust $container_type container: $container_name"
    echo "Using workspace directory: $workspace_dir"
    
    # Create workspace directory if it doesn't exist
    mkdir -p "$workspace_dir"
    
    # Check if container exists and remove it
    if docker ps -a --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Container exists, removing it..."
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Create the keep-alive script
    KEEP_ALIVE_SCRIPT='#!/bin/bash
# Keep container alive
while true; do
    sleep 60
done
'
    
    # Create the container with a proper entrypoint
    echo "Creating new container..."
    
    # Special handling for different container types
    local additional_args=""
    local mount_options="-v \"$workspace_dir:/home/ubuntu/${container_type}_ws\" -v \"$workspace_dir:/workspace\" -v \"$workspace_dir:/projects\""
    
    # Special handling for Yocto/CROPS container
    if [ "$container_type" = "yocto" ]; then
        # CROPS/poky uses /workdir instead of /workspace
        mount_options="-v \"$workspace_dir:/workdir\" -v \"$workspace_dir:/workspace\" -v \"$workspace_dir:/projects\""
        additional_args="-e TEMPLATECONF=/workdir/meta-custom/conf/templates/default"
    fi
    
    # Create the command to run
    local run_cmd="docker run -d --privileged --network=host \
        $mount_options \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY \
        $additional_args \
        --name \"$container_name\" \
        \"$image_name\" \
        bash -c \"$env_setup_command && mkdir -p /workspace && mkdir -p /projects && echo '$KEEP_ALIVE_SCRIPT' > /home/ubuntu/keep_alive.sh && chmod +x /home/ubuntu/keep_alive.sh && nohup /home/ubuntu/keep_alive.sh >/dev/null 2>&1 & echo 'Container is running with keep-alive process' && sleep infinity\""
    
    # Execute the command
    eval $run_cmd
    
    # Check if container started
    if docker ps --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Container is running properly."
        echo ""
        echo "To connect from VS Code:"
        echo "1. Click on the Remote Explorer icon in the sidebar"
        echo "2. Find the container under 'Containers'"
        echo "3. Right-click on '$container_name' and select 'Attach to Container'"
        echo ""
        echo "To attach manually, run: docker exec -it $container_name bash"
        return 0
    else
        echo "Container failed to start properly. Check Docker logs."
        docker logs "$container_name"
        return 1
    fi
}

# Function to fix an existing container
fix_container() {
    local container_type="$1"
    local container_name="$2"
    
    # Validate container type
    validate_container_type "$container_type" || return 1
    
    echo "Fixing $container_type container: $container_name"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Container '$container_name' does not exist."
        return 1
    fi
    
    # Check container status
    local container_status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    echo "Current container status: $container_status"
    
    if [ "$container_status" != "running" ]; then
        echo "Container is not running. Starting it..."
        docker start "$container_name"
        
        if [ $? -ne 0 ]; then
            echo "Failed to start container. It might be in a bad state."
            return 1
        fi
        
        sleep 2
    fi
    
    # Fix workspace directory and permissions
    echo "Fixing workspace directory..."
    if ! docker exec "$container_name" bash -c "mkdir -p /workspace && chmod 777 /workspace && mkdir -p /projects && chmod 777 /projects" 2>/dev/null; then
        echo "Failed to fix workspace directory."
        return 1
    fi
    
    # Create a simple keep-alive script
    local keep_alive_script='#!/bin/bash
# Resilient keep-alive script
while true; do
    sleep 60
done
'
    
    # Ensure keep-alive processes are running
    echo "Ensuring keep-alive processes are running..."
    if ! docker exec "$container_name" bash -c "echo '$keep_alive_script' > /home/ubuntu/keep_alive.sh && chmod +x /home/ubuntu/keep_alive.sh && nohup /home/ubuntu/keep_alive.sh >/dev/null 2>&1 & nohup bash -c 'while true; do sleep 3600; done' >/dev/null 2>&1 &" 2>/dev/null; then
        echo "Failed to start keep-alive processes."
        return 1
    fi
    
    echo "Container fixed successfully."
    return 0
}

# Function to run a detached command in a container
run_detached_command() {
    local container_name="$1"
    shift
    local command="$@"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Container '$container_name' does not exist"
        return 1
    fi
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Container '$container_name' is not running"
        return 1
    fi
    
    # First, ensure the keep-alive process is running
    docker exec "$container_name" bash -c '
        if [ -f /home/ubuntu/keep_alive.sh ]; then
            # Check if the keep-alive process is running
            if ! pgrep -f "keep_alive.sh" >/dev/null; then
                # If not running, start it again
                nohup /home/ubuntu/keep_alive.sh >/dev/null 2>&1 &
                echo "Restarted keep-alive process before running command"
            fi
        fi
    ' >/dev/null 2>&1 || true
    
    # Run the command in detached mode
    echo "Running command in detached mode: $command"
    docker exec -d "$container_name" bash -c "$command"
    
    echo "Command is now running in the background"
    echo "Container '$container_name' will remain running"
    
    return 0
}

# Check if this script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a utility script and should be sourced by other scripts, not run directly."
    echo "Supported container types: ${SUPPORTED_CONTAINERS[*]}"
    exit 1
fi
