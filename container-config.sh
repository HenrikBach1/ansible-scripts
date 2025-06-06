#!/bin/bash
# Configuration management system for container scripts
# This script provides functions to save and load container configurations

# Configuration directory
CONFIG_DIR="$HOME/.config/iac-scripts"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to save container configuration
# Usage: save_container_config "container_name" "param_name" "param_value"
save_container_config() {
    local CONTAINER_NAME="$1"
    local PARAM_NAME="$2"
    local PARAM_VALUE="$3"
    
    # Create container config directory if it doesn't exist
    local CONTAINER_CONFIG_DIR="$CONFIG_DIR/$CONTAINER_NAME"
    mkdir -p "$CONTAINER_CONFIG_DIR"
    
    # Save parameter
    echo "$PARAM_VALUE" > "$CONTAINER_CONFIG_DIR/$PARAM_NAME"
}

# Function to save original command-line arguments
# Usage: save_original_args "container_name" "args..."
save_original_args() {
    local CONTAINER_NAME="$1"
    shift
    local ORIGINAL_ARGS="$@"
    
    # Create container config directory if it doesn't exist
    local CONTAINER_CONFIG_DIR="$CONFIG_DIR/$CONTAINER_NAME"
    mkdir -p "$CONTAINER_CONFIG_DIR"
    
    # Save original arguments
    echo "$ORIGINAL_ARGS" > "$CONTAINER_CONFIG_DIR/original_args"
}

# Function to get original command-line arguments
# Usage: get_original_args "container_name"
get_original_args() {
    local CONTAINER_NAME="$1"
    local CONFIG_FILE="$CONFIG_DIR/$CONTAINER_NAME/original_args"
    
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo ""
    fi
}

# Function to load container configuration
# Usage: load_container_config "container_name" "param_name" "default_value"
load_container_config() {
    local CONTAINER_NAME="$1"
    local PARAM_NAME="$2"
    local DEFAULT_VALUE="$3"
    
    local CONFIG_FILE="$CONFIG_DIR/$CONTAINER_NAME/$PARAM_NAME"
    
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "$DEFAULT_VALUE"
    fi
}

# Function to save all container configurations at once
# Usage: save_all_container_configs "container_name" "env_type" "env_version" "workspace_dir" "gpu_support" "custom_cmd" "persistent" "run_as_root" "detach_mode" "auto_attach" "image_name" "additional_args"
save_all_container_configs() {
    local CONTAINER_NAME="$1"
    local ENV_TYPE="$2"
    local ENV_VERSION="$3"
    local WORKSPACE_DIR="$4"
    local GPU_SUPPORT="$5"
    local CUSTOM_CMD="$6"
    local PERSISTENT="$7"
    local RUN_AS_ROOT="$8"
    local DETACH_MODE="$9"
    local AUTO_ATTACH="${10}"
    local IMAGE_NAME="${11}"
    local ADDITIONAL_ARGS="${12}"
    
    # Save all parameters
    save_container_config "$CONTAINER_NAME" "env_type" "$ENV_TYPE"
    save_container_config "$CONTAINER_NAME" "env_version" "$ENV_VERSION"
    save_container_config "$CONTAINER_NAME" "workspace_dir" "$WORKSPACE_DIR"
    save_container_config "$CONTAINER_NAME" "gpu_support" "$GPU_SUPPORT"
    save_container_config "$CONTAINER_NAME" "custom_cmd" "$CUSTOM_CMD"
    save_container_config "$CONTAINER_NAME" "persistent" "$PERSISTENT"
    save_container_config "$CONTAINER_NAME" "run_as_root" "$RUN_AS_ROOT"
    save_container_config "$CONTAINER_NAME" "detach_mode" "$DETACH_MODE"
    save_container_config "$CONTAINER_NAME" "auto_attach" "$AUTO_ATTACH"
    save_container_config "$CONTAINER_NAME" "image_name" "$IMAGE_NAME"
    save_container_config "$CONTAINER_NAME" "additional_args" "$ADDITIONAL_ARGS"
    
    # Save timestamp for reference
    save_container_config "$CONTAINER_NAME" "last_used" "$(date +%s)"
}

# Function to check if a container configuration exists
# Usage: container_config_exists "container_name"
container_config_exists() {
    local CONTAINER_NAME="$1"
    
    if [ -d "$CONFIG_DIR/$CONTAINER_NAME" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to list all saved container configurations
list_container_configs() {
    echo "Saved container configurations:"
    
    for dir in "$CONFIG_DIR"/*; do
        if [ -d "$dir" ]; then
            local container_name=$(basename "$dir")
            local env_type=$(load_container_config "$container_name" "env_type" "unknown")
            local env_version=$(load_container_config "$container_name" "env_version" "")
            local last_used=$(load_container_config "$container_name" "last_used" "0")
            local original_args=$(get_original_args "$container_name")
            
            # Convert timestamp to human-readable date
            local last_used_date=""
            if [ "$last_used" != "0" ]; then
                last_used_date=$(date -d "@$last_used" "+%Y-%m-%d %H:%M:%S")
            else
                last_used_date="Never"
            fi
            
            echo "  - $container_name ($env_type $env_version) - Last used: $last_used_date"
            
            if [ -n "$original_args" ]; then
                echo "    Original command: ${env_type}-container.sh $original_args"
            fi
        fi
    done
}

# Function to get container arguments from saved configuration
# Usage: get_container_args_from_config "container_name"
get_container_args_from_config() {
    local CONTAINER_NAME="$1"
    local ARGS=""
    
    # Only proceed if the container configuration exists
    if [ "$(container_config_exists "$CONTAINER_NAME")" = "true" ]; then
        local ENV_TYPE=$(load_container_config "$CONTAINER_NAME" "env_type" "")
        local ENV_VERSION=$(load_container_config "$CONTAINER_NAME" "env_version" "")
        local WORKSPACE_DIR=$(load_container_config "$CONTAINER_NAME" "workspace_dir" "")
        local GPU_SUPPORT=$(load_container_config "$CONTAINER_NAME" "gpu_support" "false")
        local CUSTOM_CMD=$(load_container_config "$CONTAINER_NAME" "custom_cmd" "")
        local PERSISTENT=$(load_container_config "$CONTAINER_NAME" "persistent" "true")
        local RUN_AS_ROOT=$(load_container_config "$CONTAINER_NAME" "run_as_root" "false")
        local DETACH_MODE=$(load_container_config "$CONTAINER_NAME" "detach_mode" "false")
        local AUTO_ATTACH=$(load_container_config "$CONTAINER_NAME" "auto_attach" "true")
        
        # Build arguments string
        if [ "$ENV_TYPE" = "ros2" ] && [ -n "$ENV_VERSION" ]; then
            ARGS="$ARGS --distro $ENV_VERSION"
        fi
        
        if [ -n "$WORKSPACE_DIR" ]; then
            ARGS="$ARGS --workspace $WORKSPACE_DIR"
        fi
        
        if [ "$GPU_SUPPORT" = "true" ]; then
            ARGS="$ARGS --gpu"
        fi
        
        if [ -n "$CUSTOM_CMD" ] && [ "$CUSTOM_CMD" != "bash" ]; then
            ARGS="$ARGS --cmd $CUSTOM_CMD"
        fi
        
        if [ "$PERSISTENT" = "false" ]; then
            ARGS="$ARGS --no-persistent"
        fi
        
        if [ "$RUN_AS_ROOT" = "true" ]; then
            ARGS="$ARGS --root"
        fi
        
        if [ "$DETACH_MODE" = "true" ]; then
            ARGS="$ARGS --detach"
        fi
        
        if [ "$AUTO_ATTACH" = "false" ]; then
            ARGS="$ARGS --no-attach"
        fi
    fi
    
    echo "$ARGS"
}

# Function to debug the container configuration system
debug_container_config() {
    echo "DEBUG: Container Configuration System"
    echo "========================================"
    echo "Config Directory: $CONFIG_DIR"
    echo "Directory exists: $([ -d "$CONFIG_DIR" ] && echo "Yes" || echo "No")"
    echo "Contents:"
    ls -la "$CONFIG_DIR"
    echo ""
    
    for dir in "$CONFIG_DIR"/*; do
        if [ -d "$dir" ]; then
            local container_name=$(basename "$dir")
            echo "Container: $container_name"
            echo "Files:"
            ls -la "$dir"
            echo ""
            
            echo "Original arguments:"
            cat "$dir/original_args" 2>/dev/null || echo "None"
            echo ""
        fi
    done
}

# Function to display configuration for a specific container
# Usage: show_container_config "container_name"
show_container_config() {
    local CONTAINER_NAME="$1"
    
    # Check if configuration exists
    if [ "$(container_config_exists "$CONTAINER_NAME")" = "false" ]; then
        echo "Error: No saved configuration found for container '$CONTAINER_NAME'"
        return 1
    fi
    
    local env_type=$(load_container_config "$CONTAINER_NAME" "env_type" "unknown")
    local env_version=$(load_container_config "$CONTAINER_NAME" "env_version" "")
    local workspace_dir=$(load_container_config "$CONTAINER_NAME" "workspace_dir" "")
    local gpu_support=$(load_container_config "$CONTAINER_NAME" "gpu_support" "false")
    local custom_cmd=$(load_container_config "$CONTAINER_NAME" "custom_cmd" "")
    local persistent=$(load_container_config "$CONTAINER_NAME" "persistent" "true")
    local run_as_root=$(load_container_config "$CONTAINER_NAME" "run_as_root" "false")
    local detach_mode=$(load_container_config "$CONTAINER_NAME" "detach_mode" "false")
    local auto_attach=$(load_container_config "$CONTAINER_NAME" "auto_attach" "true")
    local image_name=$(load_container_config "$CONTAINER_NAME" "image_name" "")
    local last_used=$(load_container_config "$CONTAINER_NAME" "last_used" "0")
    local original_args=$(get_original_args "$CONTAINER_NAME")
    
    # Convert timestamp to human-readable date
    local last_used_date=""
    if [ "$last_used" != "0" ]; then
        last_used_date=$(date -d "@$last_used" "+%Y-%m-%d %H:%M:%S")
    else
        last_used_date="Never"
    fi
    
    echo "Configuration for container: $CONTAINER_NAME"
    echo "----------------------------------------"
    echo "Environment Type: $env_type"
    [ -n "$env_version" ] && echo "Environment Version: $env_version"
    echo "Workspace Directory: $workspace_dir"
    echo "GPU Support: $gpu_support"
    echo "Custom Command: $custom_cmd"
    echo "Persistent: $persistent"
    echo "Run as Root: $run_as_root"
    echo "Detach Mode: $detach_mode"
    echo "Auto Attach: $auto_attach"
    echo "Image Name: $image_name"
    echo "Last Used: $last_used_date"
    
    if [ -n "$original_args" ]; then
        echo "Original Command: ${env_type}-container.sh $original_args"
    fi
}

# Function to remove a saved container configuration
# Usage: remove_container_config "container_name"
remove_container_config() {
    local CONTAINER_NAME="$1"
    
    # Check if configuration exists
    if [ "$(container_config_exists "$CONTAINER_NAME")" = "false" ]; then
        echo "Error: No saved configuration found for container '$CONTAINER_NAME'"
        return 1
    fi
    
    # Remove the configuration directory
    rm -rf "$CONFIG_DIR/$CONTAINER_NAME"
    
    echo "Configuration for '$CONTAINER_NAME' has been removed."
}

# Function to clean up all unused configurations (older than specified days)
# Usage: cleanup_configs [days]
cleanup_configs() {
    local DAYS=${1:-30}  # Default to 30 days if not specified
    local CURRENT_TIME=$(date +%s)
    local CUTOFF_TIME=$((CURRENT_TIME - DAYS * 86400))
    local REMOVED_COUNT=0
    
    echo "Cleaning up configurations not used in the last $DAYS days..."
    
    for dir in "$CONFIG_DIR"/*; do
        if [ -d "$dir" ]; then
            local container_name=$(basename "$dir")
            local last_used=$(load_container_config "$container_name" "last_used" "0")
            
            # Skip if never used (keep it)
            [ "$last_used" = "0" ] && continue
            
            # Check if last used time is older than cutoff
            if [ "$last_used" -lt "$CUTOFF_TIME" ]; then
                echo "  Removing configuration for '$container_name' (last used: $(date -d "@$last_used" "+%Y-%m-%d"))"
                rm -rf "$dir"
                REMOVED_COUNT=$((REMOVED_COUNT + 1))
            fi
        fi
    done
    
    if [ "$REMOVED_COUNT" -eq 0 ]; then
        echo "No unused configurations found."
    else
        echo "Removed $REMOVED_COUNT unused configuration(s)."
    fi
}

# Function to get the name of a running container for the current workspace
# Usage: get_running_container_for_workspace "workspace_dir"
get_running_container_for_workspace() {
    local WORKSPACE_DIR="$1"
    local CONTAINER_NAME=""
    
    # List all saved configurations
    for dir in "$CONFIG_DIR"/*; do
        if [ -d "$dir" ]; then
            local container_name=$(basename "$dir")
            local workspace_dir=$(load_container_config "$container_name" "workspace_dir" "")
            
            # Check if this configuration matches the current workspace
            if [ "$workspace_dir" = "$WORKSPACE_DIR" ]; then
                # Check if this container is running
                if docker ps --format "{{.Names}}" | grep -w "^$container_name$" >/dev/null; then
                    CONTAINER_NAME="$container_name"
                    break
                fi
            fi
        fi
    done
    
    echo "$CONTAINER_NAME"
}

# Function to show configuration for a running container
# Usage: show_running_container_config
show_running_container_config() {
    # Get all running containers
    local RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}")
    
    if [ -z "$RUNNING_CONTAINERS" ]; then
        echo "No running containers found."
        return 1
    fi
    
    echo "Running containers:"
    echo "------------------"
    
    # Check each running container
    while read -r container_name; do
        # Check if we have a saved configuration for this container
        if [ "$(container_config_exists "$container_name")" = "true" ]; then
            local env_type=$(load_container_config "$container_name" "env_type" "unknown")
            local env_version=$(load_container_config "$container_name" "env_version" "")
            local workspace_dir=$(load_container_config "$container_name" "workspace_dir" "")
            local original_args=$(get_original_args "$container_name")
            
            echo "  - $container_name ($env_type $env_version)"
            echo "    Workspace: $workspace_dir"
            
            if [ -n "$original_args" ]; then
                echo "    Original command: ${env_type}-container.sh $original_args"
            fi
            
            echo ""
        else
            # For containers not created with our scripts
            echo "  - $container_name (Unknown - not created with our scripts)"
            echo ""
        fi
    done <<< "$RUNNING_CONTAINERS"
}
