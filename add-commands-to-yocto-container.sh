#!/bin/bash
# add-commands-to-yocto-container.sh
# A simplified version of add-commands-to-container.sh focused on Yocto/CROPS/poky containers
#
# This script adds standardized command scripts to CROPS/poky containers to enable
# easy detaching, stopping, and removing of containers. It is specifically designed
# to handle the unique environment of CROPS/poky containers.
#
# Commands added:
#   - container-detach: Detach from container (keeps running)
#   - container-stop: Stop the container (can be restarted)
#   - container-remove: Stop and remove the container
#   - container-help: Show available commands
#
# Legacy aliases (detach, stop, remove, help) are also created.
#
# Installation locations:
#   Primary: /workdir/.container_commands/ (if /workdir exists)
#   Fallback: /tmp/.container_commands/
#   Symlinks: /usr/local/bin/ and /tmp/bin/
#
# For more details, see:
#   - CONTAINER_COMMANDS.md (Special Considerations for CROPS/Poky Containers section)
#
# Usage: add-commands-to-yocto-container.sh CONTAINER_NAME
CONTAINER_NAME="$1"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 CONTAINER_NAME"
    exit 1
fi

echo "Adding commands to CROPS/poky container $CONTAINER_NAME..."

# Create temporary directory for command scripts
TMP_DIR=$(mktemp -d)

# Create container-detach script
cat > "$TMP_DIR/container-detach" << 'EOF'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOF

# Create container-stop script
cat > "$TMP_DIR/container-stop" << 'EOF'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOF

# Create container-remove script
cat > "$TMP_DIR/container-remove" << 'EOF'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOF

# Create container-help script
cat > "$TMP_DIR/container-help" << 'EOF'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOF

# Create container-completion script
cat > "$TMP_DIR/container-completion.sh" << 'EOF'
#!/bin/bash
# Bash completion for container commands

# Complete for container commands
_container_commands_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # Complete with available container commands
    COMPREPLY=( $(compgen -W "container-detach container-stop container-remove container-help detach stop remove help" -- $curr_arg) )
}

# Register completions
complete -F _container_commands_completion container-detach
complete -F _container_commands_completion container-stop
complete -F _container_commands_completion container-remove
complete -F _container_commands_completion container-help
complete -F _container_commands_completion detach
complete -F _container_commands_completion stop
complete -F _container_commands_completion remove
complete -F _container_commands_completion help
EOF

# Create container-init script
cat > "$TMP_DIR/container-init.sh" << 'EOF'
#!/bin/bash
# Container commands initialization

# Add container commands to PATH
if [ -d "/workdir/.container_commands" ]; then
    export PATH="/workdir/.container_commands:$PATH"
elif [ -d "/tmp/.container_commands" ]; then
    export PATH="/tmp/.container_commands:$PATH"
fi

# Also add /tmp/bin as fallback
export PATH="/tmp/bin:$PATH"

# Source bash completion if available
if [ -f "/workdir/.container_commands/container-completion.sh" ]; then
    source "/workdir/.container_commands/container-completion.sh"
elif [ -f "/tmp/.container_commands/container-completion.sh" ]; then
    source "/tmp/.container_commands/container-completion.sh"
elif [ -f "/tmp/bin/container-completion.sh" ]; then
    source "/tmp/bin/container-completion.sh"
fi

# Show help if in interactive shell
if [ -t 0 ]; then
    if command -v container-help >/dev/null 2>&1; then
        container-help
    fi
fi
EOF

# Make all scripts executable
chmod +x "$TMP_DIR"/*

# Copy scripts to container
echo "Copying scripts to container..."
docker cp "$TMP_DIR/." "$CONTAINER_NAME:/tmp/container_scripts/"

# Set up commands in container
echo "Setting up commands in container..."

# First phase - create directories and copy scripts
docker exec "$CONTAINER_NAME" bash -c '
    # Determine command directory
    if [ -d /workdir ] && [ -w /workdir ]; then
        CMD_DIR=/workdir/.container_commands
    else
        CMD_DIR=/tmp/.container_commands
    fi
    
    # Ensure directory exists and is writable
    mkdir -p "$CMD_DIR"
    chmod 755 "$CMD_DIR"
    
    # Copy command scripts
    if [ -d /tmp/container_scripts ]; then
        cp -f /tmp/container_scripts/container-* "$CMD_DIR/" 2>/dev/null || true
        chmod +x "$CMD_DIR"/* 2>/dev/null || true
    fi
    
    echo "Commands installed in $CMD_DIR"
'

# Second phase - create symlinks and aliases
docker exec "$CONTAINER_NAME" bash -c '
    # Determine command directory again
    if [ -d /workdir/.container_commands ]; then
        CMD_DIR=/workdir/.container_commands
    else
        CMD_DIR=/tmp/.container_commands
    fi
    
    # Create symlinks in common locations
    mkdir -p /tmp/bin
    ln -sf "$CMD_DIR/container-detach" /tmp/bin/container-detach 2>/dev/null || true
    ln -sf "$CMD_DIR/container-stop" /tmp/bin/container-stop 2>/dev/null || true
    ln -sf "$CMD_DIR/container-remove" /tmp/bin/container-remove 2>/dev/null || true
    ln -sf "$CMD_DIR/container-help" /tmp/bin/container-help 2>/dev/null || true
    chmod +x /tmp/bin/* 2>/dev/null || true
    
    # Create legacy aliases
    ln -sf "$CMD_DIR/container-detach" "$CMD_DIR/detach" 2>/dev/null || true
    ln -sf "$CMD_DIR/container-stop" "$CMD_DIR/stop" 2>/dev/null || true
    ln -sf "$CMD_DIR/container-remove" "$CMD_DIR/remove" 2>/dev/null || true
    ln -sf "$CMD_DIR/container-help" "$CMD_DIR/help" 2>/dev/null || true
    
    echo "Created symlinks in /tmp/bin and legacy aliases"
'

# Third phase - add to profile.d and bashrc
docker exec "$CONTAINER_NAME" bash -c '
    # Determine command directory again
    if [ -d /workdir/.container_commands ]; then
        CMD_DIR=/workdir/.container_commands
    else
        CMD_DIR=/tmp/.container_commands
    fi
    
    # Add to profile.d if possible
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
        cp "$CMD_DIR/container-init.sh" /etc/profile.d/container-init.sh 2>/dev/null || true
        chmod +x /etc/profile.d/container-init.sh 2>/dev/null || true
        echo "Added to profile.d"
    fi
    
    # Add to bashrc files
    for bashrc in /home/*/.bashrc /root/.bashrc; do
        if [ -f "$bashrc" ] && [ -w "$bashrc" ]; then
            # Remove any existing entries
            grep -v "container-commands\|container_commands\|container-init.sh" "$bashrc" > "$bashrc.tmp" 2>/dev/null || true
            mv "$bashrc.tmp" "$bashrc" 2>/dev/null || true
            
            # Add new entries
            echo "" >> "$bashrc"
            echo "# Container commands setup" >> "$bashrc"
            echo "if [ -f \"$CMD_DIR/container-init.sh\" ]; then" >> "$bashrc"
            echo "    . \"$CMD_DIR/container-init.sh\"" >> "$bashrc"
            echo "elif [ -f /etc/profile.d/container-init.sh ]; then" >> "$bashrc"
            echo "    . /etc/profile.d/container-init.sh" >> "$bashrc"
            echo "elif [ -f /tmp/bin/container-help ]; then" >> "$bashrc"
            echo "    export PATH=\"/tmp/bin:\$PATH\"" >> "$bashrc"
            echo "    if [ -t 0 ]; then container-help; fi" >> "$bashrc"
            echo "fi" >> "$bashrc"
            
            echo "Updated $bashrc"
        fi
    done
    
    echo "CROPS/poky container commands installed successfully"
'

# Clean up
rm -rf "$TMP_DIR"

echo "Container commands added to $CONTAINER_NAME."
echo "Commands will be available in all new shell sessions."
