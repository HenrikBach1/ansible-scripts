#!/bin/bash
# Example showing how to use add-commands-to-poky-container.sh
#
# This example script demonstrates how to add container commands
# to a running Yocto/CROPS container
#
# For detailed documentation, see CONTAINER_COMMANDS.md 
# (Special Considerations for CROPS/Poky Containers section)

# Check if container is running
if ! docker ps -q --filter "name=yocto_container" | grep -q .; then
    echo "Starting yocto_container first..."
    ./start-yocto-container.sh
    # Wait a moment for container to initialize
    sleep 3
fi

# Add container commands
echo "Adding container commands to yocto_container..."
./add-commands-to-poky-container.sh yocto_container

# Connect to container
echo "Connecting to container. You can use container-help to see available commands."
echo "Use container-detach to exit the container while keeping it running."
docker exec -it yocto_container bash
