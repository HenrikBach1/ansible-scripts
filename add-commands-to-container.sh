#!/bin/bash
# add-commands-to-container.sh
# This script adds standardized container commands to a Docker container
# It creates commands with consistent naming (container-*) and adds legacy aliases for compatibility

# Usage: add-commands-to-container.sh CONTAINER_NAME [USER]
# If USER is not provided, it defaults to 'ubuntu' for ROS2 containers and the current user for Yocto containers

CONTAINER_NAME="$1"
CONTAINER_USER="${2:-ubuntu}"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 CONTAINER_NAME [USER]"
    echo "If USER is not provided, it defaults to 'ubuntu' for ROS2 containers or current user for Yocto containers"
    exit 1
fi

echo "Adding container commands to $CONTAINER_NAME for user $CONTAINER_USER..."

# Create a temporary commands file
TMP_COMMANDS_DIR=$(mktemp -d)
TMP_COMMANDS_FILE="$TMP_COMMANDS_DIR/container-commands.sh"

# Create the commands script
cat > "$TMP_COMMANDS_FILE" << 'EOF'
#!/bin/bash
# Container command functions

# Main container commands with container- prefix
container-detach() {
  echo "Detaching from container (container keeps running)..."
  echo "Container will continue running in the background."
  touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
  exit 0
}

container-stop() {
  echo "Stopping container..."
  echo "Container will be stopped but can be started again."
  touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
  exit 0
}

container-remove() {
  echo "Removing container..."
  echo "Container will be stopped and removed permanently."
  touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
  exit 0
}

container-help() {
  echo "Container Commands:"
  echo "  - container-detach: Detach from the container (container keeps running)"
  echo "  - container-stop: Stop the container (container will be stopped but not removed)"
  echo "  - container-remove: Stop and remove the container completely"
  echo "  - container-help: Show this help message"
}

# Export all functions
export -f container-detach
export -f container-stop
export -f container-remove
export -f container-help
EOF

# Copy the commands file to the container
docker cp "$TMP_COMMANDS_FILE" "$CONTAINER_NAME:/tmp/container-commands.sh"

# Create script to install the commands
cat > "$TMP_COMMANDS_DIR/install-commands.sh" << 'EOF'
#!/bin/bash

# Make sure we have home directory and bin subdirectory
mkdir -p $HOME/bin
mkdir -p $HOME/.container

# Copy the commands file
cp /tmp/container-commands.sh $HOME/.container/

# Make it executable
chmod +x $HOME/.container/container-commands.sh

# Add source to bashrc if not already there
if ! grep -q "source.*container-commands.sh" $HOME/.bashrc; then
  echo "source \$HOME/.container/container-commands.sh" >> $HOME/.bashrc
fi

# Create bin scripts for container-detach
cat > $HOME/bin/container-detach << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC
chmod +x $HOME/bin/container-detach

# Create bin scripts for container-stop
cat > $HOME/bin/container-stop << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC
chmod +x $HOME/bin/container-stop

# Create bin scripts for container-remove
cat > $HOME/bin/container-remove << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC
chmod +x $HOME/bin/container-remove

# Create bin scripts for container-help
cat > $HOME/bin/container-help << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC
chmod +x $HOME/bin/container-help

# Make sure bin directory is in the PATH
if ! grep -q 'export PATH="$HOME/bin:$PATH"' $HOME/.bashrc; then
  echo 'export PATH="$HOME/bin:$PATH"' >> $HOME/.bashrc
fi

# Show help when a user logs in (if not already set)
if ! grep -q 'container-help' $HOME/.bashrc; then
  echo 'container-help' >> $HOME/.bashrc
fi

# Try to create system-wide command links if we have permissions
if [ -w /usr/local/bin ]; then
  echo "Creating system-wide command links in /usr/local/bin..."
  ln -sf $HOME/bin/container-detach /usr/local/bin/container-detach
  ln -sf $HOME/bin/container-stop /usr/local/bin/container-stop
  ln -sf $HOME/bin/container-remove /usr/local/bin/container-remove
  ln -sf $HOME/bin/container-help /usr/local/bin/container-help
fi

echo "Container commands installed successfully."
EOF

# Copy the install script to the container
docker cp "$TMP_COMMANDS_DIR/install-commands.sh" "$CONTAINER_NAME:/tmp/install-commands.sh"
docker exec "$CONTAINER_NAME" chmod +x /tmp/install-commands.sh

# Run the install script
if docker exec "$CONTAINER_NAME" bash -c "id -u $CONTAINER_USER" >/dev/null 2>&1; then
    # If the user exists, install for that user
    docker exec "$CONTAINER_NAME" su - "$CONTAINER_USER" -c "/tmp/install-commands.sh"
else
    # If the user doesn't exist, install for root
    docker exec "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh"
fi

# Clean up temporary files
rm -rf "$TMP_COMMANDS_DIR"

echo "Container commands successfully added to $CONTAINER_NAME for user $CONTAINER_USER."
echo "Commands will be available in all new shell sessions."
echo "In VS Code Attach to Container sessions, these commands will also be available."
