#!/bin/bash
# Unified container shell setup and command installation for Yocto containers
# This script combi            echo '# Set Yocto container prompt for sh shells' >> "$HOME/.profile"
            echo 'if [ -z "$BASH_VERSION" ]; then' >> "$HOME/.profile"
            echo '    export PS1="$(whoami)@(yocto):\$ "' >> "$HOME/.profile"
            echo '    # Set up aliases for sh shells' >> "$HOME/.profile"
            echo '    alias detach="container-detach"' >> "$HOME/.profile"
            echo '    alias stop="container-stop"' >> "$HOME/.profile"
            echo '    alias help="container-help"' >> "$HOME/.profile"
            echo 'fi' >> "$HOME/.profile"
            echo '' >> "$HOME/.profile"
            echo '# Set ENV for sh shells to load .shrc' >> "$HOME/.profile"
            echo 'export ENV="$HOME/.shrc"' >> "$HOME/.profile"tionality from ensure-yocto-container-commands.sh and container-shell-setup.sh

# Detect environment
RUNNING_AS_ROOT=false
if [ "$(id -u)" -eq 0 ]; then
    RUNNING_AS_ROOT=true
    echo "Running as root"
else
    echo "Running as regular user: $(id -un)"
fi

# Detect container type
IS_CROPS_CONTAINER=false
if grep -q crops/poky /etc/motd 2>/dev/null || [ -d /workdir ] || [ -f /.dockerenv ]; then
    IS_CROPS_CONTAINER=true
    echo "Detected CROPS/poky container"
fi

# Installation locations
USER_BIN="$HOME/bin"
TMP_BIN="/tmp/.container_commands"
SYSTEM_BIN="/usr/local/bin"

echo "Setting up container environment and commands..."

# Create directories
mkdir -p "$USER_BIN" 2>/dev/null || true
mkdir -p "$TMP_BIN" 2>/dev/null || true

# Create container command scripts
create_container_command() {
    local cmd_name="$1"
    local cmd_content="$2"
    local target_dir="$3"
    
    echo "#!/bin/bash" > "$target_dir/$cmd_name"
    echo "$cmd_content" >> "$target_dir/$cmd_name"
    chmod +x "$target_dir/$cmd_name" 2>/dev/null || true
    echo "Created $cmd_name in $target_dir"
}

# Command definitions
DETACH_CMD='echo "Detaching from container (container keeps running)..."
echo "Container will continue running in the background."
touch $HOME/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0'

STOP_CMD='echo "Stopping container..."
echo "Container will be stopped but can be started again."
touch $HOME/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0'

REMOVE_CMD='echo "Removing container..."
echo "Container will be stopped and removed permanently."
touch $HOME/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0'

HELP_CMD='echo "Container Commands:"
echo "  - container-detach: Detach from the container (container keeps running)"
echo "  - container-stop: Stop the container (container will be stopped but not removed)"
echo "  - container-remove: Stop and remove the container completely"
echo "  - container-help: Show this help message"'

# Install commands in user bin (primary location)
echo "Installing commands in user bin directory..."
create_container_command "container-detach" "$DETACH_CMD" "$USER_BIN"
create_container_command "container-stop" "$STOP_CMD" "$USER_BIN"
create_container_command "container-remove" "$REMOVE_CMD" "$USER_BIN"
create_container_command "container-help" "$HELP_CMD" "$USER_BIN"

# Install in tmp (backup location)
echo "Installing commands in tmp directory..."
create_container_command "container-detach" "$DETACH_CMD" "$TMP_BIN"
create_container_command "container-stop" "$STOP_CMD" "$TMP_BIN"
create_container_command "container-remove" "$REMOVE_CMD" "$TMP_BIN"
create_container_command "container-help" "$HELP_CMD" "$TMP_BIN"

# Create backwards compatibility symlinks
ln -sf "$USER_BIN/container-detach" "$USER_BIN/detach" 2>/dev/null || true
ln -sf "$USER_BIN/container-stop" "$USER_BIN/stop" 2>/dev/null || true
ln -sf "$USER_BIN/container-help" "$USER_BIN/help" 2>/dev/null || true

# Set up PATH and environment
setup_shell_environment() {
    # Update user's .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
            echo '# Container commands PATH setup' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            echo 'export PATH="/tmp/.container_commands:$PATH"' >> "$HOME/.bashrc"
        fi
        
        if ! grep -q "PS1.*yocto" "$HOME/.bashrc"; then
            echo '# Yocto container prompt' >> "$HOME/.bashrc"
            echo 'export PS1="\[\033[01;32m\]\u@\[\033[00m\]\[\033[01;33m\](yocto)\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ "' >> "$HOME/.bashrc"
        fi
    fi
    
    # Update user's .profile for login shells (VS Code compatibility)
    if [ -f "$HOME/.profile" ]; then
        # Add container setup to .profile for sh shells (VS Code)
        if ! grep -q 'Container commands PATH setup for login shells' "$HOME/.profile"; then
            echo '' >> "$HOME/.profile"
            echo '# Container commands PATH setup for login shells' >> "$HOME/.profile"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
            echo 'export PATH="/tmp/.container_commands:$PATH"' >> "$HOME/.profile"
            echo '' >> "$HOME/.profile"
            echo '# Set Yocto container prompt for sh shells' >> "$HOME/.profile"
            echo 'if [ -z "$BASH_VERSION" ]; then' >> "$HOME/.profile"
            echo '    export PS1="\$(whoami)@(yocto):\$(pwd | sed '\''s|\$HOME|~|'\'')$ "' >> "$HOME/.profile"
            echo '    # Set up aliases for sh shells' >> "$HOME/.profile"
            echo '    alias detach="container-detach"' >> "$HOME/.profile"
            echo '    alias stop="container-stop"' >> "$HOME/.profile"
            echo '    alias help="container-help"' >> "$HOME/.profile"
            echo 'fi' >> "$HOME/.profile"
        fi
    else
        # Create .profile if it doesn't exist
        cat > "$HOME/.profile" << 'PROFILE_EOF'
# ~/.profile: executed by the command interpreter for login shells.

# Container commands PATH setup for login shells
export PATH="$HOME/bin:$PATH"
export PATH="/tmp/.container_commands:$PATH"

# Set Yocto container prompt for sh shells
if [ -z "$BASH_VERSION" ]; then
    export PS1="$(whoami)@(yocto):\$ "
    # Set up aliases for sh shells
    alias detach="container-detach"
    alias stop="container-stop"
    alias help="container-help"
fi

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi        PROFILE_EOF
    fi
    
    # Create .shrc for non-login sh shells (VS Code compatibility)
    cat > "$HOME/.shrc" << 'SHRC_EOF'
echo '.shrc loaded'
# Shell environment for non-login sh shells (VS Code)
export PATH="$HOME/bin:/tmp/.container_commands:$PATH"

# Colored prompt using container name: green user@container, blue path
USER=$(whoami)
# Try to detect container name, fallback to generic name
CONTAINER_NAME=${CONTAINER_NAME:-$(hostname | grep -q 'yocto' && hostname || echo 'yocto_container')}
export PS1="$(printf '\033[01;32m')$USER@$CONTAINER_NAME$(printf '\033[00m'):$(printf '\033[01;34m')$(pwd | sed 's|$HOME|~|')$(printf '\033[00m')\$ "

alias detach="container-detach"
alias stop="container-stop"
alias help="container-help"
SHRC_EOF
}

# Apply environment setup
echo "Setting up shell environment..."
setup_shell_environment

# Install commands system-wide if we can (for VS Code compatibility)
if [ "$RUNNING_AS_ROOT" = true ] || [ -w "/usr/local/bin" ]; then
    echo "Installing commands system-wide for VS Code compatibility..."
    create_container_command "container-detach" "$DETACH_CMD" "/usr/local/bin"
    create_container_command "container-stop" "$STOP_CMD" "/usr/local/bin"
    create_container_command "container-remove" "$REMOVE_CMD" "/usr/local/bin"
    create_container_command "container-help" "$HELP_CMD" "/usr/local/bin"
    
    # Create system-wide profile for all shells
    cat > /etc/profile.d/yocto-container.sh << 'SYSTEM_PROFILE_EOF'
# Yocto container environment setup
# This runs for all login shells

# Set container prompt for sh shells (when BASH_VERSION is not set)
if [ -z "$BASH_VERSION" ]; then
    USER=$(whoami)
    CONTAINER_NAME=${CONTAINER_NAME:-$(hostname | grep -q 'yocto' && hostname || echo 'yocto_container')}
    export PS1="$USER@$CONTAINER_NAME:\$(pwd | sed 's|\$HOME|~|')\$ "
fi

# Convenient aliases
alias detach='container-detach'
alias stop='container-stop'  
alias help='container-help'
SYSTEM_PROFILE_EOF
    chmod +x /etc/profile.d/yocto-container.sh
    
    # Also add to system bashrc for broader compatibility
    if [ ! -f /etc/bash.bashrc ] || ! grep -q "Yocto container setup" /etc/bash.bashrc; then
        echo '# Yocto container setup for all shells' >> /etc/bash.bashrc
        echo 'if [ -z "$BASH_VERSION" ]; then' >> /etc/bash.bashrc
        echo '    USER=$(whoami)' >> /etc/bash.bashrc
        echo '    export PS1="$USER@(yocto):\$(pwd | sed '\''s|\$HOME|~|'\'')\$ "' >> /etc/bash.bashrc
        echo 'fi' >> /etc/bash.bashrc
    fi
    
    echo "System-wide yocto container profile created"
fi

# For immediate use in current shell, export the environment
export PATH="$HOME/bin:/tmp/.container_commands:$PATH"

# Set prompt for current shell
if [ -n "$BASH_VERSION" ]; then
    export PS1="\[\033[01;32m\]\u@\[\033[00m\]\[\033[01;33m\](yocto)\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ "
else
    export PS1="$(whoami)@(yocto):$(pwd | sed "s|$HOME|~|")$ "
fi

# Set up convenient aliases for current shell
alias container-detach="$HOME/bin/container-detach"
alias container-stop="$HOME/bin/container-stop"
alias container-remove="$HOME/bin/container-remove"
alias container-help="$HOME/bin/container-help"
alias detach='container-detach'
alias stop='container-stop'
alias help='container-help'

echo "Container environment setup completed!"
echo "Commands available: container-help, container-detach, container-stop, container-remove"
echo ""

# Show welcome message for interactive shells
if [ -t 0 ] && [ -t 1 ]; then
    echo "Welcome to the Yocto Container!"
    echo "Type 'container-help' for available commands."
    echo ""
    
    # Show help if available
    if command -v container-help >/dev/null 2>&1; then
        container-help
    fi
fi
