#!/bin/bash
# Script to fix missing /projects directory in container

# Define colors for better visibility
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-ros2_container}"
WORKSPACE_DIR="$HOME/projects"

echo -e "${YELLOW}Fixing missing /projects directory in container ${CONTAINER_NAME}${NC}"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Container '$CONTAINER_NAME' does not exist${NC}"
    exit 1
fi

echo -e "${YELLOW}The most reliable way to fix this issue is to recreate the container.${NC}"
echo -e "Would you like to stop, remove, and recreate the container? (y/n)"
read -r RECREATE

if [[ "$RECREATE" == "y" || "$RECREATE" == "Y" ]]; then
    echo -e "${YELLOW}Stopping container...${NC}"
    docker stop "$CONTAINER_NAME"
    
    echo -e "${YELLOW}Removing container...${NC}"
    docker rm "$CONTAINER_NAME"
    
    echo -e "${GREEN}Now recreating container with the correct mounts...${NC}"
    # Find the appropriate start script
    if [[ "$CONTAINER_NAME" == *"ros2"* ]]; then
        START_SCRIPT="./start-ros2-container.sh"
    elif [[ "$CONTAINER_NAME" == *"yocto"* ]]; then
        START_SCRIPT="./start-yocto-container.sh"
    else
        echo -e "${YELLOW}Unknown container type. Using ROS2 as default.${NC}"
        START_SCRIPT="./start-ros2-container.sh --name $CONTAINER_NAME"
    fi
    
    # Execute the start script
    echo -e "${GREEN}Running: $START_SCRIPT${NC}"
    $START_SCRIPT
    
    echo -e "\n${GREEN}Container has been recreated with proper mounts!${NC}"
    echo "You can now access your files at both /workspace and /projects in the container."
    echo "To connect to the container, run: docker exec -it $CONTAINER_NAME bash"
    echo "Or use: ./ros2-connect or ./yocto-connect"
else
    echo -e "${YELLOW}Skipping container recreation.${NC}"
    echo -e "${RED}Note: There is no reliable way to add mounts to a running container.${NC}"
    echo -e "To fix this properly, please recreate the container with:"
    echo "docker stop $CONTAINER_NAME"
    echo "docker rm $CONTAINER_NAME"
    echo "./start-ros2-container.sh # or the appropriate start script"
fi
