#!/bin/bash
# Robust ROS2 container wrapper script

# Source the container utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/container-utils.sh"

# Default values
CONTAINER_TYPE="ros2"
CONTAINER_NAME="ros2_container"
WORKSPACE_DIR="$HOME/projects"
ENV_VERSION="jazzy"

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
        -d|--distro)
            ENV_VERSION="$2"
            shift 2
            ;;
        -f|--fix)
            FIX_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Create or fix a robust ROS2 container"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME        Container name (default: ros2_container)"
            echo "  -w, --workspace DIR    Host workspace directory (default: $HOME/projects)"
            echo "  -d, --distro VERSION   ROS2 distribution (default: jazzy)"
            echo "  -f, --fix              Fix an existing container instead of creating a new one"
            echo "  -h, --help             Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Either fix or create the container
if [ "$FIX_ONLY" = true ]; then
    echo "Fixing existing ROS2 container: $CONTAINER_NAME"
    fix_container "$CONTAINER_TYPE" "$CONTAINER_NAME"
else
    echo "Creating robust ROS2 container: $CONTAINER_NAME"
    create_robust_container "$CONTAINER_TYPE" "$CONTAINER_NAME" "$WORKSPACE_DIR" "$ENV_VERSION"
fi

exit $?
