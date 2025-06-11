#!/bin/bash
# add-commands-to-container.sh
# Unified script to add standardized commands to Docker containers
# Uses the container-command-common.sh shared library for functionality
# Supports all container types including ROS2, Yocto/CROPS/Poky with appropriate detection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/container-command-common.sh"

# Usage: add-commands-to-container.sh CONTAINER_NAME [USER]
# If USER is not provided, it defaults to 'ubuntu' for ROS2 containers and the current user for Yocto containers

SCRIPT_NAME=$(basename "$0")
CONTAINER_NAME="$1"
CONTAINER_USER="${2:-ubuntu}"

# Set default container type if not specified by script name
CONTAINER_TYPE="generic"

# Auto-detect container type from script name
if [[ "$SCRIPT_NAME" == *"ros2"* ]]; then
    CONTAINER_TYPE="ros2"
elif [[ "$SCRIPT_NAME" == *"yocto"* || "$SCRIPT_NAME" == *"poky"* ]]; then
    CONTAINER_TYPE="yocto"
    # For Yocto containers, default to current user if not specified
    if [ "$#" -eq 1 ]; then
        CONTAINER_USER="$(id -un)"
    fi
else
    # Auto-detect from container if not specified by script name
    CONTAINER_TYPE=$(detect_container_type "$CONTAINER_NAME")
    
    # For Yocto containers, default to current user if not specified
    if [ "$CONTAINER_TYPE" = "yocto" ] && [ "$#" -eq 1 ]; then
        CONTAINER_USER="$(id -un)"
    fi
fi

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 CONTAINER_NAME [USER]"
    echo "If USER is not provided, it defaults to 'ubuntu' for ROS2 containers or current user for Yocto containers"
    exit 1
fi

echo "Adding container commands to $CONTAINER_NAME for user $CONTAINER_USER (Container type: $CONTAINER_TYPE)..."

# Create a temporary commands directory
TMP_DIR=$(mktemp -d)
COMMANDS_DIR="$TMP_DIR/commands"
mkdir -p "$COMMANDS_DIR"

# Create all the container command scripts
echo "Creating container command scripts..."
create_command_script "container-detach" "$(get_command_content "detach")" "$COMMANDS_DIR"
create_command_script "container-stop" "$(get_command_content "stop")" "$COMMANDS_DIR"
create_command_script "container-remove" "$(get_command_content "remove")" "$COMMANDS_DIR"
create_command_script "container-help" "$(get_command_content "help")" "$COMMANDS_DIR"

# Create initialization script
create_init_script "$COMMANDS_DIR" "$CONTAINER_TYPE"

# Create completion script
create_completion_script "$COMMANDS_DIR"

# Create install script for the container
cat > "$TMP_DIR/install-commands.sh" << 'EOF'
#!/bin/bash
# Script to install container commands within the container

# Source the command library if available
if [ -f /tmp/container-command-common.sh ]; then
    source /tmp/container-command-common.sh
fi

# Detect if we're running as root
if [ "$(id -u)" -eq 0 ]; then
    RUNNING_AS_ROOT=true
    echo "Running as root"
else
    RUNNING_AS_ROOT=false
    echo "Running as regular user: $(id -un)"
fi

# Detect container type
CONTAINER_TYPE="generic"
if grep -q crops/poky /etc/motd 2>/dev/null || grep -q poky /etc/motd 2>/dev/null || [ -d /workdir ]; then
    CONTAINER_TYPE="yocto"
    echo "Detected Yocto/CROPS container"
elif grep -q ros /etc/motd 2>/dev/null || [ -d /opt/ros ]; then
    CONTAINER_TYPE="ros2"
    echo "Detected ROS2 container"
fi

# Determine installation locations
SYSTEM_BIN="/usr/local/bin"
USER_BIN="$HOME/bin"
TMP_BIN="/tmp/container-commands"
TMP_FALLBACK="/tmp/.container_commands"

# Add Yocto-specific locations
if [ "$CONTAINER_TYPE" = "yocto" ]; then
    WORKDIR_BIN="/workdir/.container_commands"
else
    WORKDIR_BIN=""
fi

echo "Creating container command directories..."
mkdir -p "$USER_BIN" 2>/dev/null || true
mkdir -p "$TMP_BIN" 2>/dev/null || true
mkdir -p "$TMP_FALLBACK" 2>/dev/null || true
if [ -n "$WORKDIR_BIN" ] && ($RUNNING_AS_ROOT || [ -w /workdir ]); then
    mkdir -p "$WORKDIR_BIN" 2>/dev/null || true
fi

# Copy command files from /tmp/commands to appropriate locations
echo "Installing commands in user's bin directory..."
cp -f /tmp/commands/container-* "$USER_BIN/" 2>/dev/null || true
chmod +x "$USER_BIN/container-"* 2>/dev/null || true

echo "Installing commands in temporary locations..."
cp -f /tmp/commands/container-* "$TMP_BIN/" 2>/dev/null || true
chmod +x "$TMP_BIN/container-"* 2>/dev/null || true

cp -f /tmp/commands/container-* "$TMP_FALLBACK/" 2>/dev/null || true
chmod +x "$TMP_FALLBACK/container-"* 2>/dev/null || true

# Install in workdir if it exists and we're dealing with a Yocto container
if [ -n "$WORKDIR_BIN" ] && ($RUNNING_AS_ROOT || [ -w /workdir ]); then
    echo "Installing commands in workdir..."
    cp -f /tmp/commands/container-* "$WORKDIR_BIN/" 2>/dev/null || true
    chmod +x "$WORKDIR_BIN/container-"* 2>/dev/null || true
fi

# Install in system bin if we have permission
if $RUNNING_AS_ROOT || [ -w "$SYSTEM_BIN" ]; then
    echo "Installing commands in system bin directory..."
    cp -f /tmp/commands/container-* "$SYSTEM_BIN/" 2>/dev/null || true
    chmod +x "$SYSTEM_BIN/container-"* 2>/dev/null || true
fi

# Update the user's .bashrc
echo "Updating user's .bashrc..."
if [ -f "$HOME/.bashrc" ]; then
    # Add bin directory to PATH
    if ! grep -q 'PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    
    # Source init script
    INIT_CONTENT="
# Container commands initialization
if [ -f /tmp/container-commands/container-init.sh ]; then
    source /tmp/container-commands/container-init.sh
elif [ -f /tmp/.container_commands/container-init.sh ]; then
    source /tmp/.container_commands/container-init.sh
fi"

    if [ "$CONTAINER_TYPE" = "yocto" ] && [ -n "$WORKDIR_BIN" ]; then
        INIT_CONTENT="${INIT_CONTENT}
elif [ -f /workdir/.container_commands/container-init.sh ]; then
    source /workdir/.container_commands/container-init.sh
fi"
    else
        INIT_CONTENT="${INIT_CONTENT}
fi"
    fi
    
    if ! grep -q "container-init.sh" "$HOME/.bashrc"; then
        echo "$INIT_CONTENT" >> "$HOME/.bashrc"
    fi
fi

# Try to create system-wide profile script
if $RUNNING_AS_ROOT || [ -w "/etc/profile.d" ]; then
    echo "Creating system-wide profile script..."
    cp -f /tmp/commands/container-init.sh /etc/profile.d/container-init.sh 2>/dev/null || true
    chmod +x /etc/profile.d/container-init.sh 2>/dev/null || true
fi

# Try to add to global bashrc
if $RUNNING_AS_ROOT && [ -f /etc/bash.bashrc ] && [ -w /etc/bash.bashrc ]; then
    echo "Updating global bashrc..."
    if ! grep -q "container-init.sh" /etc/bash.bashrc; then
        echo "$INIT_CONTENT" >> /etc/bash.bashrc
    fi
fi

# Add completion script
if $RUNNING_AS_ROOT && [ -d /etc/bash_completion.d ] && [ -w /etc/bash_completion.d ]; then
    echo "Installing bash completion script..."
    cp -f /tmp/commands/container-completion.sh /etc/bash_completion.d/ 2>/dev/null || true
    chmod +x /etc/bash_completion.d/container-completion.sh 2>/dev/null || true
elif [ -d "$HOME/.bash_completion.d" ]; then
    mkdir -p "$HOME/.bash_completion.d" 2>/dev/null || true
    cp -f /tmp/commands/container-completion.sh "$HOME/.bash_completion.d/" 2>/dev/null || true
    chmod +x "$HOME/.bash_completion.d/container-completion.sh" 2>/dev/null || true
    
    # Source completion script in bashrc if not already there
    if [ -f "$HOME/.bashrc" ] && ! grep -q ".bash_completion.d/container-completion.sh" "$HOME/.bashrc"; then
        echo "
# Source container command completion
if [ -f \"$HOME/.bash_completion.d/container-completion.sh\" ]; then
    source \"$HOME/.bash_completion.d/container-completion.sh\"
fi" >> "$HOME/.bashrc"
    fi
fi

# For Yocto containers, create the welcome script
if [ "$CONTAINER_TYPE" = "yocto" ]; then
    echo "Creating Yocto welcome script..."
    cat > /tmp/yocto-welcome.sh << 'EOW'
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

if [ -d "/tmp/container-commands" ]; then
    export PATH="/tmp/container-commands:$PATH"
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
EOW
    chmod +x /tmp/yocto-welcome.sh
fi

echo "Container commands installed successfully!"
EOF

# Copy the files to the container
echo "Copying scripts to container..."
docker cp "$COMMANDS_DIR" "$CONTAINER_NAME:/tmp/commands"
docker cp "$TMP_DIR/install-commands.sh" "$CONTAINER_NAME:/tmp/install-commands.sh"
docker cp "$SCRIPT_DIR/container-command-common.sh" "$CONTAINER_NAME:/tmp/container-command-common.sh"

# Make the install script executable
docker exec "$CONTAINER_NAME" chmod +x /tmp/install-commands.sh

# Run the install script as root if possible
echo "Running installation script..."
if docker exec -u 0 "$CONTAINER_NAME" bash -c "id" &>/dev/null; then
    docker exec -u 0 "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh"
else
    # Try as the specified user
    docker exec "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh"
fi

# Also run as the specified user if we ran as root above
if [ "$CONTAINER_USER" != "root" ]; then
    if docker exec -u "$CONTAINER_USER" "$CONTAINER_NAME" bash -c "id" &>/dev/null; then
        docker exec -u "$CONTAINER_USER" "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh"
    fi
fi

# Clean up temporary files
rm -rf "$TMP_DIR"

# For Yocto containers, do an additional setup if needed
if [ "$CONTAINER_TYPE" = "yocto" ]; then
    echo "Performing additional Yocto-specific setup..."
    if [ -f "$SCRIPT_DIR/ensure-yocto-container-commands.sh" ]; then
        echo "Running Yocto-specific command installer for maximum compatibility..."
        "$SCRIPT_DIR/ensure-yocto-container-commands.sh" "$CONTAINER_NAME"
    fi
fi

echo "Container commands successfully added to $CONTAINER_NAME."
echo "Commands will be available in all new shell sessions."
echo "In VS Code Attach to Container sessions, these commands will also be available."
