#!/bin/bash
# Script to run a Yocto Docker container with appropriate settings
file=run-yocto-container.sh
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
DETACH_MODE=false
AUTO_ATTACH=true
CLEAN_START=false
SAVE_CONFIG=false
LIST_CONFIGS=false

# Display help message
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_container_help "yocto" "" "release" "$WORKSPACE_DIR"
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
            show_container_help "yocto" "" "release" "$WORKSPACE_DIR"
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
echo "Using CROPS/poky build environment: $IMAGE_NAME"
echo "Note: This container provides tools to build Yocto, but does not include Poky source code."

# Save configuration if requested
if [ "$SAVE_CONFIG" = true ]; then
    echo "Saving configuration for container $CONTAINER_NAME..."
    save_all_container_configs "$CONTAINER_NAME" "$ENV_TYPE" "" "$WORKSPACE_DIR" \
        "$GPU_SUPPORT" "$CUSTOM_CMD" "$PERSISTENT" "$RUN_AS_ROOT" "$DETACH_MODE" \
        "$AUTO_ATTACH" "$IMAGE_NAME" ""
    
    # Save original arguments
    save_original_args "$CONTAINER_NAME" "$ORIGINAL_ARGS"
    
    echo "Configuration saved. You can use these settings in the future by running with --name $CONTAINER_NAME"
fi

# CROPS/poky requires special handling - override the common container options
# to use the crops/poky-specific flags
USER_OPTIONS="--workdir=/workdir"
ADDITIONAL_ARGS="-e TEMPLATECONF=/workdir/meta-custom/conf/templates/default"
ENTRYPOINT_SCRIPT="" # Don't use our custom entrypoint for CROPS
ENTRYPOINT_MOUNT="" # Clear any mounts that were set
ENTRYPOINT_ARGS="" # Clear any args that were set

# Modify how we mount the workspace to match CROPS/poky expectations
docker run $DETACH_FLAG $PERSISTENCE_FLAG $GPU_OPTIONS \
    --privileged \
    --network=host \
    -v "$WORKSPACE_DIR:/workdir" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    $ADDITIONAL_ARGS \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" $USER_OPTIONS bash -c "cd /workdir && echo 'Yocto Development Environment' && echo '-------------------------' && echo 'Container Base Image: $IMAGE_NAME' && echo '' && echo 'This is a CROPS/poky build environment container for Yocto development.' && echo 'It provides the tools needed to build Yocto but does not include Poky source code.' && echo '' && echo 'To get started:' && echo '1. Clone Poky with your desired version:' && echo '   git clone -b <branch-name> git://git.yoctoproject.org/poky' && echo '   (Examples: scarthgap, kirkstone, langdale, etc.)' && echo '2. Initialize: source poky/oe-init-build-env' && echo '3. Build: bitbake core-image-minimal' && echo '' && echo '4. Enter the environment: ./run-yocto-container.sh --name <container-name> --workspace <workspace-dir>' && echo '' && bash"

# Start the container watcher in the background if this is a persistent container
if [ "$PERSISTENT" = true ] && [ -f "$(dirname "$0")/container-watch.sh" ]; then
    echo "Starting container watcher for $CONTAINER_NAME..."
    bash "$(dirname "$0")/container-watch.sh" "$CONTAINER_NAME" &
fi

exit 0
