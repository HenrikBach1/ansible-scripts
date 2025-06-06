#!/bin/bash
# Robust Yocto container wrapper script

# Source the container utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/container-utils.sh"

# Default values
CONTAINER_TYPE="yocto"
CONTAINER_NAME="yocto_container"
WORKSPACE_DIR="$HOME/yocto_ws"
ENV_VERSION="ubuntu-22.04"  # CROPS/poky base image version

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
        -b|--base)
            ENV_VERSION="$2"
            shift 2
            ;;
        -f|--fix)
            FIX_ONLY=true
            shift
            ;;
        -c|--command)
            COMMAND_MODE=true
            COMMAND="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Create or fix a robust Yocto container"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME        Container name (default: yocto_container)"
            echo "  -w, --workspace DIR    Host workspace directory (default: $HOME/yocto_ws)"
            echo "  -b, --base VERSION     CROPS/poky base image version (default: ubuntu-22.04)"
            echo "  -f, --fix              Fix an existing container instead of creating a new one"
            echo "  -c, --command CMD      Run a detached command in the container"
            echo "  -h, --help             Display this help message"
            echo ""
            echo "Available base versions: ubuntu-22.04, ubuntu-20.04, debian-11, fedora-36, etc."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Run detached command if requested
if [ "$COMMAND_MODE" = true ]; then
    echo "Running detached command in container: $CONTAINER_NAME"
    run_detached_command "$CONTAINER_NAME" "$COMMAND"
    exit $?
fi

# Either fix or create the container
if [ "$FIX_ONLY" = true ]; then
    echo "Fixing existing Yocto container: $CONTAINER_NAME"
    fix_container "$CONTAINER_TYPE" "$CONTAINER_NAME"
else
    # Construct the proper image name for CROPS/poky
    IMAGE_NAME="crops/poky:${ENV_VERSION}"
    
    # Verify the crops/poky image exists or pull it
    if [ -z "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" ]; then
        echo "Pulling CROPS/poky image: $IMAGE_NAME..."
        docker pull "$IMAGE_NAME" || {
            echo "ERROR: Failed to pull $IMAGE_NAME image."
            echo "Available tags include: ubuntu-22.04, ubuntu-20.04, debian-11, fedora-36, etc."
            exit 1
        }
    fi
    
    echo "Creating robust Yocto container: $CONTAINER_NAME"
    echo "Using CROPS/poky build environment: $IMAGE_NAME"
    echo "Note: This container provides tools to build Yocto, but does not include Poky source code."
    
    create_robust_container "$CONTAINER_TYPE" "$CONTAINER_NAME" "$WORKSPACE_DIR" "$ENV_VERSION"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "Yocto Container Quick Start:"
        echo "  1. Clone Poky: git clone -b <branch-name> git://git.yoctoproject.org/poky"
        echo "     (Examples: scarthgap, kirkstone, langdale, etc.)"
        echo "  2. Initialize: source poky/oe-init-build-env"
        echo "  3. Build: bitbake core-image-minimal"
    fi
fi

exit $?
