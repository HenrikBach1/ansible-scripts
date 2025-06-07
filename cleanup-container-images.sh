#!/bin/bash
# Script to clean up temporary container images

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Container Image Cleanup Utility${NC}"
echo "This script will clean up temporary container images."
echo ""

# Look for temp container images
TEMP_IMAGES=$(docker images --format "{{.Repository}}" | grep "^temp_.*_image$")

if [ -z "$TEMP_IMAGES" ]; then
    echo "No temporary container images found."
    echo "Checking for other cleanup opportunities..."
    
    # Check for containers using the temp images (in case they still exist)
    CONTAINERS_USING_TEMP=$(docker ps -a --format "{{.Image}}" | grep "temp_.*_image")
    
    if [ -n "$CONTAINERS_USING_TEMP" ]; then
        echo -e "${YELLOW}Found containers using temporary images. Stopping and removing them...${NC}"
        docker ps -a --format "{{.Names}} {{.Image}}" | grep "temp_.*_image" | awk '{print $1}' | xargs -r docker stop
        docker ps -a --format "{{.Names}} {{.Image}}" | grep "temp_.*_image" | awk '{print $1}' | xargs -r docker rm
        echo "Containers removed."
    fi
    
    # Now try again to find temp images
    TEMP_IMAGES=$(docker images --format "{{.Repository}}" | grep "^temp_.*_image$")
else
    echo -e "${YELLOW}Found temporary container images:${NC}"
    docker images | grep "temp_.*_image"
    
    # Check if any containers are using these images
    echo "Checking if any containers are using these images..."
    for image in $TEMP_IMAGES; do
        CONTAINERS=$(docker ps -a --format "{{.Names}} {{.Image}}" | grep "$image" | awk '{print $1}')
        if [ -n "$CONTAINERS" ]; then
            echo -e "${YELLOW}Found containers using $image:${NC}"
            echo "$CONTAINERS"
            echo "Stopping and removing these containers..."
            for container in $CONTAINERS; do
                docker stop "$container" >/dev/null 2>&1
                docker rm "$container" >/dev/null 2>&1
                echo "Removed container: $container"
            done
        fi
    done
fi

# Now try to remove the temp images
if [ -n "$TEMP_IMAGES" ]; then
    echo -e "${YELLOW}Removing temporary images...${NC}"
    
    # Force remove the images
    for image in $TEMP_IMAGES; do
        echo "Removing image: $image"
        docker rmi -f "$image" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully removed $image${NC}"
        else
            echo -e "${RED}Failed to remove $image${NC}"
            echo "Trying more aggressive approach..."
            
            # Get the image ID
            IMAGE_ID=$(docker images --format "{{.ID}}" --filter "reference=$image")
            if [ -n "$IMAGE_ID" ]; then
                echo "Force removing image ID: $IMAGE_ID"
                docker rmi -f "$IMAGE_ID" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully removed image ID $IMAGE_ID${NC}"
                else
                    echo -e "${RED}Failed to remove image ID $IMAGE_ID${NC}"
                fi
            fi
        fi
    done
fi

# Run general cleanup
echo -e "${YELLOW}Running general Docker cleanup...${NC}"
echo "Removing dangling images..."
docker image prune -f >/dev/null 2>&1

echo -e "${GREEN}Cleanup complete!${NC}"
echo "Current Docker images:"
docker images
