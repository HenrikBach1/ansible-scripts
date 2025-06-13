#!/bin/bash
# Unified container shell setup and command installation for Yocto containers
# This script combines functionality from ensure-yocto-container-commands.sh and container-shell-setup.sh

# SAFETY CHECK: Only run inside containers, never on host
if [ ! -f /.dockerenv ] && [ ! -d /workdir ] && ! grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "ERROR: This script should only run inside Docker containers, not on the host!"
    echo "It appears you're running this on the host system."
    echo "This script is automatically run by start-yocto-container.sh when creating containers."
    exit 1
fi

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

echo "Setting up container environment and commands..."

# Fix workspace permissions for current user in CROPS containers
if [ "$IS_CROPS_CONTAINER" = true ]; then
    echo "Fixing workspace permissions for current user..."
    
    # If running as root, add the target user to pokyuser group
    if [ "$RUNNING_AS_ROOT" = true ]; then
        # Find the actual user that will be using the container
        target_user="usersetup"  # Default CROPS user
        if getent group pokyuser >/dev/null 2>&1; then
            if ! groups "$target_user" 2>/dev/null | grep -q pokyuser; then
                echo "Adding $target_user to pokyuser group..."
                usermod -a -G pokyuser "$target_user" 2>/dev/null || {
                    echo "Warning: Could not add user to pokyuser group"
                }
            fi
        fi
        
        # Change ownership of workspace files to be accessible
        for workspace_path in /workspace /projects /workdir; do
            if [ -d "$workspace_path" ]; then
                echo "Fixing ownership and permissions in $workspace_path..."
                # Change ownership to usersetup:pokyuser so usersetup can write
                find "$workspace_path" -exec chown usersetup:pokyuser {} + 2>/dev/null || true
                # Make sure directories are writable by owner and group
                find "$workspace_path" -type d -exec chmod 775 {} + 2>/dev/null || true
                find "$workspace_path" -type f -exec chmod 664 {} + 2>/dev/null || true
                # Make script files executable (common script extensions and shebangs)
                find "$workspace_path" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" -o -name "*-env" \) -exec chmod 775 {} + 2>/dev/null || true
                # Also make files with shebang executable
                find "$workspace_path" -type f -exec grep -l "^#!" {} + 2>/dev/null | xargs chmod 775 2>/dev/null || true
            fi
        done
    elif [ "$RUNNING_AS_ROOT" = false ]; then
        # Running as regular user - try to fix what we can
        for workspace_path in /workspace /projects /workdir; do
            if [ -d "$workspace_path" ] && [ -w "$workspace_path" ]; then
                # Fix permissions to allow current user to work with existing files
                find "$workspace_path" -type d -exec chmod g+w {} + 2>/dev/null || true
                find "$workspace_path" -type f -exec chmod g+w {} + 2>/dev/null || true
            fi
        done
    fi
fi

# Define directories
USER_BIN="$HOME/bin"
TMP_BIN="/tmp/.container_commands"
SYSTEM_BIN="/usr/local/bin"

# Create directories
mkdir -p "$USER_BIN" 2>/dev/null || true
mkdir -p "$TMP_BIN" 2>/dev/null || true
# Ensure tmp directory is writable by all users
chmod 755 "$TMP_BIN" 2>/dev/null || true
if [ "$RUNNING_AS_ROOT" = true ]; then
    mkdir -p "$SYSTEM_BIN" 2>/dev/null || true
    # When root creates the tmp directory, make it accessible to all users
    chmod 777 "$TMP_BIN" 2>/dev/null || true
fi

# Function to create container command
create_container_command() {
    local cmd_name="$1"
    local cmd_content="$2"
    local target_dir="$3"
    local file_path="$target_dir/$cmd_name"
    
    # Skip if we don't have write permissions to the directory
    if [ ! -w "$target_dir" ]; then
        echo "Skipping $cmd_name in $target_dir (no write permission to directory)"
        return 0
    fi
    
    # If file already exists and we can't write to it, skip
    if [ -f "$file_path" ] && [ ! -w "$file_path" ]; then
        echo "Skipping $cmd_name in $target_dir (file exists, no write permission)"
        return 0
    fi
    
    # Create the file
    if cat > "$file_path" << EOF
#!/bin/bash
$cmd_content
EOF
    then
        # Try to make it executable
        if chmod +x "$file_path" 2>/dev/null; then
            echo "Created $cmd_name in $target_dir"
        else
            echo "Created $cmd_name in $target_dir (chmod failed)"
        fi
        
        # If we're root and creating in tmp, make it accessible to all users
        if [ "$RUNNING_AS_ROOT" = true ] && [ "$target_dir" = "/tmp/.container_commands" ]; then
            chmod 755 "$file_path" 2>/dev/null || true
        fi
    else
        echo "Failed to create $cmd_name in $target_dir"
    fi
}

# Command definitions
DETACH_CMD='echo "Detaching from container (container keeps running)..."
echo "Container will continue running in the background."
# Try multiple locations to ensure the watcher finds the detach request
touch /workdir/.container_detach_requested 2>/dev/null || touch $HOME/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
echo "Detach requested, exiting..."
exit 0'

STOP_CMD='echo "Stopping container..."
echo "Container will be stopped but can be started again."
# Try multiple locations to ensure the watcher finds the stop request
touch /workdir/.container_stop_requested 2>/dev/null || touch $HOME/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0'

REMOVE_CMD='echo "Removing container..."
echo "Container will be stopped and removed permanently."
# Try multiple locations to ensure the watcher finds the remove request
touch /workdir/.container_remove_requested 2>/dev/null || touch $HOME/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0'

HELP_CMD='echo "Container Commands:"
echo "  - container-detach: Detach from the container (container keeps running)"
echo "  - container-stop: Stop the container (container will be stopped but not removed)"
echo "  - container-remove: Stop and remove the container completely"
echo "  - container-help: Show this help message"
echo ""
echo "Aliases available:"
echo "  - detach (same as container-detach)"
echo "  - stop (same as container-stop)"
echo "  - help (same as container-help)"'

# Install commands in user bin (primary location)
echo "Installing commands in user bin directory..."
create_container_command "container-detach" "$DETACH_CMD" "$USER_BIN"
create_container_command "container-stop" "$STOP_CMD" "$USER_BIN"
create_container_command "container-remove" "$REMOVE_CMD" "$USER_BIN"
create_container_command "container-help" "$HELP_CMD" "$USER_BIN"

# Install in tmp (backup location) - only for root to avoid conflicts
if [ "$RUNNING_AS_ROOT" = true ]; then
    echo "Installing commands in tmp directory..."
    create_container_command "container-detach" "$DETACH_CMD" "$TMP_BIN"
    create_container_command "container-stop" "$STOP_CMD" "$TMP_BIN"
    create_container_command "container-remove" "$REMOVE_CMD" "$TMP_BIN"
    create_container_command "container-help" "$HELP_CMD" "$TMP_BIN"
else
    echo "Skipping tmp directory installation (not root, avoiding conflicts)"
fi

# Install system-wide if running as root
if [ "$RUNNING_AS_ROOT" = true ]; then
    echo "Installing commands system-wide..."
    create_container_command "container-detach" "$DETACH_CMD" "$SYSTEM_BIN"
    create_container_command "container-stop" "$STOP_CMD" "$SYSTEM_BIN"
    create_container_command "container-remove" "$REMOVE_CMD" "$SYSTEM_BIN"
    create_container_command "container-help" "$HELP_CMD" "$SYSTEM_BIN"
fi

# Create backwards compatibility symlinks
ln -sf "$USER_BIN/container-detach" "$USER_BIN/detach" 2>/dev/null || true
ln -sf "$USER_BIN/container-stop" "$USER_BIN/stop" 2>/dev/null || true
ln -sf "$USER_BIN/container-help" "$USER_BIN/help" 2>/dev/null || true

# Set up shell environment for user
echo "Setting up shell environment..."

# Update user's .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
        echo '# Container commands PATH setup' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="/tmp/.container_commands:$PATH"' >> "$HOME/.bashrc"
        echo '' >> "$HOME/.bashrc"
    fi
    
    # Add aliases to .bashrc
    if ! grep -q 'alias detach=' "$HOME/.bashrc"; then
        echo '# Container command aliases' >> "$HOME/.bashrc"
        echo 'alias detach="container-detach"' >> "$HOME/.bashrc"
        echo 'alias stop="container-stop"' >> "$HOME/.bashrc"
        echo 'alias help="container-help"' >> "$HOME/.bashrc"
        echo '' >> "$HOME/.bashrc"
    fi
fi

# Set up .profile for login shells (includes sh)
if [ -f "$HOME/.profile" ]; then
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.profile"; then
        echo '# Container commands PATH setup' >> "$HOME/.profile"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
        echo 'export PATH="/tmp/.container_commands:$PATH"' >> "$HOME/.profile"
        echo '' >> "$HOME/.profile"
    fi
fi

# Create .shrc for sh shells (used when ENV is set)
cat > "$HOME/.shrc" << 'SHRC_EOF'
# Container shell configuration for sh
echo ".shrc loaded"

# Set up PATH for container commands
export PATH="$HOME/bin:$PATH"
export PATH="/tmp/.container_commands:$PATH"

# Set up container name for prompt
CONTAINER_NAME="unknown"
if [ -f "/proc/1/cgroup" ]; then
    CONTAINER_NAME=$(grep -o '/docker/[^/]*' /proc/1/cgroup 2>/dev/null | head -1 | cut -d'/' -f3 | cut -c1-12)
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="yocto_container"
    else
        CONTAINER_NAME="yocto_container"
    fi
fi

# Set colored prompt for sh shells - format: user@hostname:path$ 
if [ -z "$BASH_VERSION" ]; then
    # Green user@hostname, colon, blue path
    export PS1="\033[01;32m\]\u@${CONTAINER_NAME}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
else
    # For bash shells, set enhanced prompt - format: user@hostname:path$
    export PS1="\[\033[01;32m\]\u@${CONTAINER_NAME}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
fi

# Set up aliases
alias detach="container-detach"
alias stop="container-stop"
alias help="container-help"

# Set ENV to this file for subshells
export ENV="$HOME/.shrc"
SHRC_EOF

# Set up system-wide profile if running as root
if [ "$RUNNING_AS_ROOT" = true ]; then
    echo "Setting up system-wide profile..."
    
    # Create system profile for all users
    cat > "/etc/profile.d/yocto-container.sh" << 'PROFILE_EOF'
# Yocto container environment setup
export PATH="/usr/local/bin:$PATH"
export PATH="/tmp/.container_commands:$PATH"

# Container command aliases
alias detach="container-detach"
alias stop="container-stop"  
alias help="container-help"
PROFILE_EOF
    
    chmod 644 "/etc/profile.d/yocto-container.sh"
    echo "Created system-wide profile: /etc/profile.d/yocto-container.sh"
fi

echo "Container environment setup completed!"
echo "Commands available: container-help, container-detach, container-stop, container-remove"
echo "Aliases available: help, detach, stop"

# Setup tab completion for container commands
setup_container_completion() {
    # Only setup completion if bash-completion is available and we're in an interactive shell
    if [ -n "$BASH_VERSION" ] && [ -t 0 ] && [ -t 1 ]; then
        # Tab completion for container commands
        _container_commands_completion() {
            local curr_arg="${COMP_WORDS[COMP_CWORD]}"
            # Complete with available container commands
            COMPREPLY=( $(compgen -W "container-detach container-stop container-remove container-help detach stop remove help" -- $curr_arg) )
        }
        
        # Register completions for container commands
        complete -F _container_commands_completion container-detach 2>/dev/null || true
        complete -F _container_commands_completion container-stop 2>/dev/null || true
        complete -F _container_commands_completion container-remove 2>/dev/null || true
        complete -F _container_commands_completion container-help 2>/dev/null || true
        complete -F _container_commands_completion detach 2>/dev/null || true
        complete -F _container_commands_completion stop 2>/dev/null || true
        complete -F _container_commands_completion remove 2>/dev/null || true
        complete -F _container_commands_completion help 2>/dev/null || true
        
        # Setup keyboard shortcuts for container operations
        if [[ "$TERM" != "" ]]; then
            # Setup Ctrl+X then d to detach from containers
            bind '"\C-xd": "container-detach\n"' 2>/dev/null || true
            # Also provide a simpler Ctrl+\ shortcut
            bind '"\C-\\": "container-detach\n"' 2>/dev/null || true
            # Direct detach command using touch marker file
            bind '"\C-xq": "touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested; exit\n"' 2>/dev/null || true
        fi
        
        echo "Tab completion and keyboard shortcuts enabled for container commands"
        echo "Keyboard shortcuts: Ctrl+X+d or Ctrl+\ to detach, Ctrl+X+q for direct exit"
    fi
}

# Setup completion
setup_container_completion

echo ""

# Show welcome message for interactive shells
if [ -t 0 ] && [ -t 1 ]; then
    echo "Welcome to the Yocto Container!"
    echo "Type 'container-help' or 'help' for available commands."
    echo ""
    
    # Show help if available
    if command -v container-help >/dev/null 2>&1; then
        container-help
    fi
fi
