#!/bin/bash
# Utility script to quickly verify container setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
CONTAINER_NAME=""

if [ $# -eq 0 ]; then
    # No arguments provided - list running containers and let user choose
    echo "Running containers:"
    CONTAINERS=$(docker ps --format '{{.Names}}')
    
    if [ -z "$CONTAINERS" ]; then
        echo "No running containers found."
        exit 1
    fi
    
    # Number the containers for selection
    i=1
    declare -a CONTAINER_ARRAY
    while read -r container; do
        echo "$i) $container"
        CONTAINER_ARRAY[i]="$container"
        ((i++))
    done <<< "$CONTAINERS"
    
    echo
    echo "Enter container number to verify (or press Enter to verify all):"
    read -r container_choice
    
    if [ -z "$container_choice" ]; then
        # Verify all containers
        source ./run-container-common.sh
        verify_container
        exit 0
    elif [[ "$container_choice" =~ ^[0-9]+$ ]] && [ "$container_choice" -ge 1 ] && [ "$container_choice" -lt "$i" ]; then
        CONTAINER_NAME="${CONTAINER_ARRAY[$container_choice]}"
    else
        echo "Invalid selection."
        exit 1
    fi
else
    CONTAINER_NAME="$1"
fi

# Determine container type and use appropriate verification
if [[ "$CONTAINER_NAME" == *"ros2"* ]]; then
    ./start-ros2-container.sh --verify "$CONTAINER_NAME"
elif [[ "$CONTAINER_NAME" == *"yocto"* ]]; then
    ./start-yocto-container-docker.sh --verify "$CONTAINER_NAME"
else
    echo "Unknown container type. Using generic verification."
    source ./run-container-common.sh
    verify_container "$CONTAINER_NAME"
fi
