#!/bin/bash
# Script to update the Yocto container configuration

# Define colors for better visibility
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONTAINER_NAME="${1:-yocto_container}"

echo -e "${YELLOW}Updating Yocto container configuration for $CONTAINER_NAME${NC}"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${RED}Container '$CONTAINER_NAME' does not exist${NC}"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -w "^$CONTAINER_NAME$" > /dev/null; then
    echo -e "${YELLOW}Container '$CONTAINER_NAME' is not running${NC}"
    echo "Starting container..."
    docker start "$CONTAINER_NAME"
    sleep 1
fi

# Clean up unnecessary files
echo -e "${YELLOW}Cleaning up unnecessary files...${NC}"
docker exec "$CONTAINER_NAME" bash -c "
    # Stop any processes using the files
    pkill -f 'keep_alive.sh' || true
    
    # Remove old files
    rm -rf /projects/keepalive /projects/keep_alive.sh /projects/yocto-container-bashrc.sh 2>/dev/null || true
    rm -rf /workspace/keepalive /workspace/keep_alive.sh /workspace/yocto-container-bashrc.sh 2>/dev/null || true
    rm -rf /workdir/keepalive /workdir/keep_alive.sh /workdir/yocto-container-bashrc.sh 2>/dev/null || true
    
    # Create a separate directory for container utilities
    mkdir -p /var/lib/container-utils
    
    # Verify symlinks
    rm -f /workspace 2>/dev/null || true
    rm -f /projects 2>/dev/null || true
    ln -sf /workdir /workspace
    ln -sf /workdir /projects
"

echo -e "${GREEN}Container utilities cleaned up.${NC}"

# Now connect to the container using the yocto-connect script
echo -e "${YELLOW}Connecting to the container with the updated configuration...${NC}"
echo "This will set up the new commands: help, stop, remove, etc."
echo -e "${GREEN}Use ./yocto-connect to connect to your container in the future.${NC}"
echo ""

./yocto-connect "$CONTAINER_NAME"
