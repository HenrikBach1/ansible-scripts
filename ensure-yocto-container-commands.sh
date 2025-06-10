#!/bin/bash
# ensure-yocto-container-commands.sh
# This script ensures that container commands are properly installed in Yocto containers
# and available in all shell sessions

CONTAINER_NAME="${1:-yocto_container}"
echo "Ensuring container commands are always available in $CONTAINER_NAME..."

# Create a temporary directory for our scripts
TMP_DIR=$(mktemp -d)

# Create a script to install container commands robustly
cat > "$TMP_DIR/install-yocto-commands.sh" << 'EOF'
#!/bin/bash
# This script is run inside the Yocto container to ensure commands are available

# Detect if we're running as root
if [ "$(id -u)" -eq 0 ]; then
  RUNNING_AS_ROOT=true
  echo "Running as root"
else
  RUNNING_AS_ROOT=false
  echo "Running as regular user: $(id -un)"
fi

# First, identify the container type
IS_CROPS_CONTAINER=false
if grep -q crops/poky /etc/motd 2>/dev/null || [ -d /workdir ] || [ -f /.dockerenv ]; then
  IS_CROPS_CONTAINER=true
  echo "Detected CROPS/poky container"
fi

# Determine installation locations
SYSTEM_BIN="/usr/local/bin"
USER_BIN="$HOME/bin"
WORKDIR_BIN="/workdir/.container_commands"
TMP_BIN="/tmp/.container_commands"

echo "Creating container command directories..."
mkdir -p "$USER_BIN" 2>/dev/null || true
if $RUNNING_AS_ROOT || [ -w /workdir ]; then
  mkdir -p "$WORKDIR_BIN" 2>/dev/null || true
fi
mkdir -p "$TMP_BIN" 2>/dev/null || true

# Create container commands - we'll create them in all possible locations
create_command() {
  local name="$1"
  local content="$2"
  local target_dir="$3"
  
  echo "Creating $name in $target_dir..."
  echo -e "#!/bin/bash\n$content" > "$target_dir/$name"
  chmod +x "$target_dir/$name" 2>/dev/null || true
}

# Create the container-detach command
DETACH_CONTENT="echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0"

# Create the container-stop command
STOP_CONTENT="echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0"

# Create the container-remove command
REMOVE_CONTENT="echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0"

# Create the container-help command
HELP_CONTENT="echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'"

# Install in user bin
echo "Installing in user bin directory..."
create_command "container-detach" "$DETACH_CONTENT" "$USER_BIN"
create_command "container-stop" "$STOP_CONTENT" "$USER_BIN"
create_command "container-remove" "$REMOVE_CONTENT" "$USER_BIN"
create_command "container-help" "$HELP_CONTENT" "$USER_BIN"

# Also create the legacy commands for backward compatibility
ln -sf "$USER_BIN/container-detach" "$USER_BIN/detach" 2>/dev/null || true
ln -sf "$USER_BIN/container-stop" "$USER_BIN/stop_container" 2>/dev/null || true
ln -sf "$USER_BIN/container-help" "$USER_BIN/container_help" 2>/dev/null || true

# Update the user's .bashrc if needed
if [ -f "$HOME/.bashrc" ]; then
  if ! grep -q 'PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
  fi
fi

# Install in system bin if we have permission
if $RUNNING_AS_ROOT || [ -w "$SYSTEM_BIN" ]; then
  echo "Installing in system bin directory..."
  create_command "container-detach" "$DETACH_CONTENT" "$SYSTEM_BIN"
  create_command "container-stop" "$STOP_CONTENT" "$SYSTEM_BIN"
  create_command "container-remove" "$REMOVE_CONTENT" "$SYSTEM_BIN"
  create_command "container-help" "$HELP_CONTENT" "$SYSTEM_BIN"
fi

# Install in workdir if it exists and is writable
if [ -d "/workdir" ] && ([ -w "/workdir" ] || $RUNNING_AS_ROOT); then
  echo "Installing in workdir..."
  create_command "container-detach" "$DETACH_CONTENT" "$WORKDIR_BIN"
  create_command "container-stop" "$STOP_CONTENT" "$WORKDIR_BIN"
  create_command "container-remove" "$REMOVE_CONTENT" "$WORKDIR_BIN"
  create_command "container-help" "$HELP_CONTENT" "$WORKDIR_BIN"
fi

# Always install in tmp as fallback
echo "Installing in tmp directory..."
create_command "container-detach" "$DETACH_CONTENT" "$TMP_BIN"
create_command "container-stop" "$STOP_CONTENT" "$TMP_BIN"
create_command "container-remove" "$REMOVE_CONTENT" "$TMP_BIN"
create_command "container-help" "$HELP_CONTENT" "$TMP_BIN"

# Create system-wide initialization script in /etc/profile.d
if $RUNNING_AS_ROOT || [ -w "/etc/profile.d" ]; then
  echo "Creating system-wide initialization script..."
  cat > /etc/profile.d/container-init.sh << 'EOT'
#!/bin/bash
# Add container command directories to PATH
if [ -d "$HOME/bin" ]; then
  export PATH="$HOME/bin:$PATH"
fi

if [ -d "/workdir/.container_commands" ]; then
  export PATH="/workdir/.container_commands:$PATH"
fi

if [ -d "/tmp/.container_commands" ]; then
  export PATH="/tmp/.container_commands:$PATH"
fi

# Show available container commands on login
if command -v container-help >/dev/null 2>&1; then
  container-help
fi
EOT
  chmod +x /etc/profile.d/container-init.sh
fi

# Create a global shell hook in /etc/bash.bashrc if possible
if $RUNNING_AS_ROOT && [ -w "/etc/bash.bashrc" ]; then
  echo "Adding global shell hook..."
  if ! grep -q "container-init.sh" /etc/bash.bashrc; then
    echo '
# Source container init script
if [ -f /etc/profile.d/container-init.sh ]; then
  source /etc/profile.d/container-init.sh
fi
' >> /etc/bash.bashrc
  fi
fi

echo "Container commands installation completed."
echo "Commands should now be available in all shell sessions."
EOF

# Copy the script to the container
echo "Copying installation script to container..."
docker cp "$TMP_DIR/install-yocto-commands.sh" "$CONTAINER_NAME:/tmp/install-yocto-commands.sh"
docker exec "$CONTAINER_NAME" chmod +x /tmp/install-yocto-commands.sh

# Try to run the script as root first
echo "Running installation script as root..."
docker exec "$CONTAINER_NAME" bash -c "bash /tmp/install-yocto-commands.sh"

# Also create a welcome script that will be used when connecting to the container
cat > "$TMP_DIR/yocto-welcome.sh" << 'EOF'
#!/bin/bash
# This script is run when connecting to the Yocto container

# Ensure container commands are in PATH
if [ -d "/usr/local/bin" ]; then
  export PATH="/usr/local/bin:$PATH"
fi

if [ -d "$HOME/bin" ]; then
  export PATH="$HOME/bin:$PATH"
fi

if [ -d "/workdir/.container_commands" ]; then
  export PATH="/workdir/.container_commands:$PATH"
fi

if [ -d "/tmp/.container_commands" ]; then
  export PATH="/tmp/.container_commands:$PATH"
fi

# Show welcome message
echo "Welcome to the Yocto Container!"
echo "Container commands available:"
echo "  - container-help: Show all available commands"
echo "  - container-detach: Detach from container (keeps running)"
echo "  - container-stop: Stop the container"
echo "  - container-remove: Stop and remove the container"
echo ""

# Run container-help if available
if command -v container-help >/dev/null 2>&1; then
  container-help
else
  echo "Warning: container commands not in PATH. You can run them directly:"
  echo "  - /tmp/.container_commands/container-help"
  echo "  - /tmp/.container_commands/container-detach"
  echo "  - /tmp/.container_commands/container-stop"
  echo "  - /tmp/.container_commands/container-remove"
fi

# Start an interactive shell
exec bash
EOF

# Copy the welcome script to the container
echo "Copying welcome script to container..."
docker cp "$TMP_DIR/yocto-welcome.sh" "$CONTAINER_NAME:/tmp/yocto-welcome.sh"
docker exec "$CONTAINER_NAME" chmod +x /tmp/yocto-welcome.sh

# Clean up temporary files
rm -rf "$TMP_DIR"

echo "Container commands setup completed for $CONTAINER_NAME."
echo "Commands should now be available in all shell sessions."
echo "To connect to the container, use: ./yocto-connect"
