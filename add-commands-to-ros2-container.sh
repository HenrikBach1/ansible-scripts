#!/bin/bash
# add-commands-to-ros2-container.sh
# This script adds standardized container commands to a ROS2 Docker container
# It creates commands with consistent naming (container-*) and fixes the heredoc issues

# Usage: add-commands-to-ros2-container.sh CONTAINER_NAME [USER]
# If USER is not provided, it defaults to 'ubuntu' for ROS2 containers

CONTAINER_NAME="$1"
CONTAINER_USER="${2:-ubuntu}"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Usage: $0 CONTAINER_NAME [USER]"
    echo "If USER is not provided, it defaults to 'ubuntu'"
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

# Function to install commands for all users in the container
install_for_all_users() {
    echo "Installing commands for all users in the container..."
    
    # Create a temporary directory that will be writable
    docker exec "$CONTAINER_NAME" bash -c "
        # Create directory for container commands that will be writable
        COMMANDS_DIR=/tmp/container-commands
        mkdir -p \$COMMANDS_DIR
        
        echo 'Creating container command scripts in \$COMMANDS_DIR...'
        
        # Create the command scripts
        cat > \$COMMANDS_DIR/container-detach << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC

        cat > \$COMMANDS_DIR/container-stop << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC

        cat > \$COMMANDS_DIR/container-remove << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC

        cat > \$COMMANDS_DIR/container-help << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC

        # Create bash completion script for container commands
        cat > \$COMMANDS_DIR/container-completion.sh << 'EOC'
#!/bin/bash
# Bash completion for container commands

# Complete for container commands
_container_commands_completion() {
    local curr_arg;
    curr_arg="\${COMP_WORDS[COMP_CWORD]}"
    
    # Complete with available container commands
    COMPREPLY=( \$(compgen -W "container-detach container-stop container-remove container-help detach stop remove help" -- \$curr_arg) )
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
EOC

        # Make all command scripts executable
        chmod 755 \$COMMANDS_DIR/container-* || true
        
        # Create init script that users can source
        cat > \$COMMANDS_DIR/container-init.sh << 'EOC'
#!/bin/bash
# Container commands initialization
# Source this file to add container commands to your PATH

# Add commands directory to PATH if not already there
if [[ \":$PATH:\" != *\":/tmp/container-commands:\"* ]]; then
    export PATH=/tmp/container-commands:$PATH
fi

# Also add fallback location
if [[ \":$PATH:\" != *\":/tmp/.container_commands:\"* ]]; then
    export PATH=/tmp/.container_commands:$PATH
fi

# Show help if we're in an interactive shell
if [ -t 0 ]; then
    if [ -x /tmp/container-commands/container-help ]; then
        /tmp/container-commands/container-help
    fi
fi
EOC
        chmod 755 \$COMMANDS_DIR/container-init.sh || true
        
        # Try to create a profile.d script, but don't fail if we can't
        if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
            echo 'Creating global profile script...'
            cat > /etc/profile.d/container-init.sh << 'EOC'
#!/bin/bash
# Container commands initialization

# Add commands directory to PATH if not already there
if [[ \":$PATH:\" != *\":/tmp/container-commands:\"* ]]; then
    export PATH=/tmp/container-commands:$PATH
fi

# Also add fallback location
if [[ \":$PATH:\" != *\":/tmp/.container_commands:\"* ]]; then
    export PATH=/tmp/.container_commands:$PATH
fi

# Show help if we're in an interactive shell
if [ -t 0 ]; then
    if [ -x /tmp/container-commands/container-help ]; then
        /tmp/container-commands/container-help
    fi
fi
EOC
            chmod 755 /etc/profile.d/container-init.sh 2>/dev/null || true
            echo 'Created global profile script.'
        else
            echo 'Unable to create global profile script (no permission). Using fallback.'
        fi
        
        # Try to add to /etc/bash.bashrc if we can
        if [ -f /etc/bash.bashrc ] && [ -w /etc/bash.bashrc ]; then
            if ! grep -q 'container-commands' /etc/bash.bashrc; then
                echo 'Adding to global bash.bashrc...'
                echo '
# Container commands initialization
if [ -f /tmp/container-commands/container-init.sh ]; then
    source /tmp/container-commands/container-init.sh
fi' >> /etc/bash.bashrc
                echo 'if [ -d /tmp/bin ]; then export PATH=\"/tmp/bin:\$PATH\"; fi' >> /etc/bash.bashrc
                echo 'if [ -t 0 ] && command -v container-help > /dev/null 2>&1; then container-help; fi' >> /etc/bash.bashrc
                echo 'if [ -f /tmp/bin/container-completion.sh ]; then source /tmp/bin/container-completion.sh; fi' >> /etc/bash.bashrc
                echo 'Updated /etc/bash.bashrc'
            fi
        else
            echo 'Cannot modify /etc/bash.bashrc (no permission).'
        fi
        
        # Add to all user bashrc files we can find and have permission to modify
        echo 'Adding to user bashrc files...'
        
        # Detect root home directory
        ROOT_HOME=\$(getent passwd root | cut -d: -f6)
        if [ -z \"\$ROOT_HOME\" ]; then
            ROOT_HOME=\"/root\"  # Default if we couldn't detect it
        fi
        
        for bashrc in /home/*/.bashrc \"\$ROOT_HOME/.bashrc\"; do
            if [ -f \"\$bashrc\" ] && [ -w \"\$bashrc\" ]; then
                username=\$(dirname \"\$bashrc\" | xargs basename)
                echo \"Setting up commands for user \$username...\"
                
                # Remove any existing entries to avoid duplication
                sed -i '/container-commands/d' \"\$bashrc\" 2>/dev/null || true
                sed -i '/container-help/d' \"\$bashrc\" 2>/dev/null || true
                
                # Add new entry
                echo '
# Container commands initialization
if [ -f /tmp/container-commands/container-init.sh ]; then
    source /tmp/container-commands/container-init.sh
fi' >> \"\$bashrc\"
                echo \"Updated \$bashrc\"
            fi
        done
        
        # Add to /etc/skel/.bashrc if possible for new users
        if [ -f /etc/skel/.bashrc ] && [ -w /etc/skel/.bashrc ]; then
            echo 'Adding to skeleton bashrc for new users...'
            if ! grep -q 'container-commands' /etc/skel/.bashrc; then
                echo '
# Container commands initialization
if [ -f /tmp/container-commands/container-init.sh ]; then
    source /tmp/container-commands/container-init.sh
fi' >> /etc/skel/.bashrc
                echo 'Updated skeleton bashrc.'
            fi
        fi
        
        # Create symlinks in /usr/local/bin if we have permissions
        if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
            echo 'Creating symlinks in /usr/local/bin...'
            ln -sf /tmp/container-commands/container-detach /usr/local/bin/container-detach 2>/dev/null || true
            ln -sf /tmp/container-commands/container-stop /usr/local/bin/container-stop 2>/dev/null || true
            ln -sf /tmp/container-commands/container-remove /usr/local/bin/container-remove 2>/dev/null || true
            ln -sf /tmp/container-commands/container-help /usr/local/bin/container-help 2>/dev/null || true
            echo 'Created symlinks in /usr/local/bin.'
        else
            echo 'Cannot create symlinks in /usr/local/bin (no permission).'
        fi
        
        # Create symlinks in /workdir if it exists
        if [ -d /workdir ] && [ -w /workdir ]; then
            echo 'Creating symlinks in /workdir...'
            mkdir -p /workdir/bin 2>/dev/null || true
            ln -sf /tmp/container-commands/container-detach /workdir/bin/container-detach 2>/dev/null || true
            ln -sf /tmp/container-commands/container-stop /workdir/bin/container-stop 2>/dev/null || true
            ln -sf /tmp/container-commands/container-remove /workdir/bin/container-remove 2>/dev/null || true
            ln -sf /tmp/container-commands/container-help /workdir/bin/container-help 2>/dev/null || true
            echo 'Created symlinks in /workdir/bin.'
        fi
        
        # Additional fallback location in /tmp/.container_commands for very restricted environments
        mkdir -p /tmp/.container_commands 2>/dev/null || true
        ln -sf /tmp/container-commands/container-detach /tmp/.container_commands/container-detach 2>/dev/null || true
        ln -sf /tmp/container-commands/container-stop /tmp/.container_commands/container-stop 2>/dev/null || true
        ln -sf /tmp/container-commands/container-remove /tmp/.container_commands/container-remove 2>/dev/null || true
        ln -sf /tmp/container-commands/container-help /tmp/.container_commands/container-help 2>/dev/null || true
        chmod +x /tmp/.container_commands/* 2>/dev/null || true
        echo 'Created fallback commands in /tmp/.container_commands'
        
        echo 'Container commands installed successfully in /tmp/container-commands'
    "
    
    # Create a simple init script that can be added directly to the container
    cat > "$TMP_COMMANDS_DIR/container-init.sh" << 'EOF'
#!/bin/bash
# Container commands initialization script
# This is added by add-commands-to-ros2-container.sh

# Add container commands to PATH
if [[ ":$PATH:" != *":/tmp/container-commands:"* ]]; then
    export PATH=/tmp/container-commands:$PATH
fi

# Also add fallback location
if [[ ":$PATH:" != *":/tmp/.container_commands:"* ]]; then
    export PATH=/tmp/.container_commands:$PATH
fi

# Show help if in interactive shell
if [ -t 0 ]; then
    if [ -x /tmp/container-commands/container-help ]; then
        /tmp/container-commands/container-help
    fi
fi
EOF

    # Copy the init script to the container with fallback locations
    docker cp "$TMP_COMMANDS_DIR/container-init.sh" "$CONTAINER_NAME:/tmp/container-init.sh" 2>/dev/null || true
    docker exec "$CONTAINER_NAME" bash -c "mkdir -p /tmp/container-commands/ 2>/dev/null || true"
    docker exec "$CONTAINER_NAME" bash -c "cp /tmp/container-init.sh /tmp/container-commands/container-init.sh 2>/dev/null || true"
    docker exec "$CONTAINER_NAME" bash -c "chmod 755 /tmp/container-init.sh /tmp/container-commands/container-init.sh 2>/dev/null || true"
    docker cp "$TMP_COMMANDS_DIR/container-init.sh" "$CONTAINER_NAME:/etc/profile.d/container-init.sh" 2>/dev/null || true
    
    # Try to make it executable, but don't fail if we can't
    docker exec "$CONTAINER_NAME" bash -c "chmod 755 /etc/profile.d/container-init.sh" 2>/dev/null || true
    
    return 0
}

# Create script to install the commands
cat > "$TMP_COMMANDS_DIR/install-commands.sh" << 'EOF'
#!/bin/bash
# Script to install container commands within the container

# Detect if we're running as root
if [ "$(id -u)" -eq 0 ]; then
  RUNNING_AS_ROOT=true
  echo "Running installation as root"
  
  # Detect root home directory explicitly
  ROOT_HOME=$(getent passwd root | cut -d: -f6)
  if [ -z "$ROOT_HOME" ]; then
      ROOT_HOME="/root"  # Default if we couldn't detect it
  fi
  echo "Root home directory: $ROOT_HOME"
  
  # Make sure we have home directory and bin subdirectory
  mkdir -p "$ROOT_HOME/bin" || { echo "Failed to create $ROOT_HOME/bin directory"; exit 1; }
  mkdir -p "$ROOT_HOME/.container" || { echo "Failed to create $ROOT_HOME/.container directory"; exit 1; }
else
  RUNNING_AS_ROOT=false
  echo "Running installation as regular user"
  
  # Make sure we have home directory and bin subdirectory
  mkdir -p "$HOME/bin" || { echo "Failed to create $HOME/bin directory"; exit 1; }
  mkdir -p "$HOME/.container" || { echo "Failed to create $HOME/.container directory"; exit 1; }
fi

# Set home directory based on whether we're root or not
if [ "$RUNNING_AS_ROOT" = true ]; then
  USER_HOME="$ROOT_HOME"
else
  USER_HOME="$HOME"
fi

# Copy the commands file
cp /tmp/container-commands.sh "$USER_HOME/.container/" || { echo "Failed to copy container-commands.sh"; exit 1; }

# Make it executable
chmod +x "$USER_HOME/.container/container-commands.sh" || { echo "Failed to make container-commands.sh executable"; exit 1; }

# Add source to bashrc if not already there
if ! grep -q "source.*container-commands.sh" "$USER_HOME/.bashrc"; then
  echo "source \$HOME/.container/container-commands.sh" >> "$USER_HOME/.bashrc" || { echo "Failed to update .bashrc"; exit 1; }
fi

# Create bin scripts with proper error handling
echo "Creating container-detach script..."
cat > "$USER_HOME/bin/container-detach" << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC
chmod +x "$USER_HOME/bin/container-detach" || { echo "Failed to make container-detach executable"; exit 1; }

echo "Creating container-stop script..."
cat > "$USER_HOME/bin/container-stop" << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC
chmod +x "$USER_HOME/bin/container-stop" || { echo "Failed to make container-stop executable"; exit 1; }

echo "Creating container-remove script..."
cat > "$USER_HOME/bin/container-remove" << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC
chmod +x "$USER_HOME/bin/container-remove" || { echo "Failed to make container-remove executable"; exit 1; }

echo "Creating container-help script..."
cat > "$USER_HOME/bin/container-help" << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC
chmod +x "$USER_HOME/bin/container-help" || { echo "Failed to make container-help executable"; exit 1; }

# Make sure bin directory is in the PATH
if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$USER_HOME/.bashrc"; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$USER_HOME/.bashrc" || { echo "Failed to update PATH in .bashrc"; exit 1; }
fi

# Show help when a user logs in (if not already set)
if ! grep -q 'container-help' "$USER_HOME/.bashrc"; then
  echo 'container-help' >> "$USER_HOME/.bashrc" || { echo "Failed to add container-help to .bashrc"; exit 1; }
fi

# Try to create system-wide command links if we have permissions
if [ "$RUNNING_AS_ROOT" = true ] || [ -w /usr/local/bin ]; then
  echo "Creating system-wide command links in /usr/local/bin..."
  ln -sf "$USER_HOME/bin/container-detach" /usr/local/bin/container-detach
  ln -sf "$USER_HOME/bin/container-stop" /usr/local/bin/container-stop
  ln -sf "$USER_HOME/bin/container-remove" /usr/local/bin/container-remove
  ln -sf "$USER_HOME/bin/container-help" /usr/local/bin/container-help
  echo "System-wide command links created."
else
  echo "No permission to create system-wide command links in /usr/local/bin."
  echo "Commands will only be available for the current user."
fi

# Add additional fallback directories for command files
if [ -w /workdir ]; then
  echo "Adding fallback commands to /workdir..."
  mkdir -p /workdir/.container-commands || true
  
  # Copy the container commands to the fallback location
  cp "$USER_HOME/bin/container-detach" /workdir/.container-commands/ || true
  cp "$USER_HOME/bin/container-stop" /workdir/.container-commands/ || true
  cp "$USER_HOME/bin/container-remove" /workdir/.container-commands/ || true
  cp "$USER_HOME/bin/container-help" /workdir/.container-commands/ || true
  chmod +x /workdir/.container-commands/* || true
  
  echo "Fallback commands added to /workdir/.container-commands/"
fi

# Create additional fallback in /tmp for all users
mkdir -p /tmp/.container_commands || true
cp "$USER_HOME/bin/container-detach" /tmp/.container_commands/ || true
cp "$USER_HOME/bin/container-stop" /tmp/.container_commands/ || true
cp "$USER_HOME/bin/container-remove" /tmp/.container_commands/ || true
cp "$USER_HOME/bin/container-help" /tmp/.container_commands/ || true
chmod +x /tmp/.container_commands/* || true
echo "Universal fallback commands added to /tmp/.container_commands/"

echo "Container commands installed successfully for user $(whoami)."
EOF

# Copy the install script to the container and ensure it's executable
docker cp "$TMP_COMMANDS_DIR/install-commands.sh" "$CONTAINER_NAME:/tmp/install-commands.sh"

# Make sure the script is executable by everyone (can be run by any user)
docker exec "$CONTAINER_NAME" bash -c "chmod 755 /tmp/install-commands.sh 2>/dev/null || true"

# Try to make /tmp world-writable if possible to overcome permission issues
docker exec "$CONTAINER_NAME" bash -c "chmod 1777 /tmp 2>/dev/null || true"

# First, attempt to install the commands system-wide for all users
echo "Attempting to install container commands for all users..."
install_for_all_users

# Then, run the install script for the specified user if they exist
if docker exec "$CONTAINER_NAME" bash -c "id -u $CONTAINER_USER" >/dev/null 2>&1; then
    # If the user exists, try to run as that user
    echo "Installing commands for user $CONTAINER_USER..."
    
    # First attempt: Try using su directly
    if ! docker exec "$CONTAINER_NAME" bash -c "su - $CONTAINER_USER -c '/tmp/install-commands.sh'" >/dev/null 2>&1; then
        echo "Warning: Failed to run with 'su', trying with 'sudo -u'..."
        
        # Second attempt: Try using sudo -u if available
        if docker exec "$CONTAINER_NAME" bash -c "command -v sudo >/dev/null 2>&1"; then
            if ! docker exec "$CONTAINER_NAME" bash -c "sudo -u $CONTAINER_USER /tmp/install-commands.sh" >/dev/null 2>&1; then
                echo "Warning: Failed to run with 'sudo -u', trying as root..."
                # Third attempt: Run as root and fix ownership
                docker exec "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh && chown -R $CONTAINER_USER:$CONTAINER_USER /home/$CONTAINER_USER/bin /home/$CONTAINER_USER/.container 2>/dev/null || true"
            fi
        else
            echo "Warning: 'sudo' not available, trying as root..."
            # Fallback: Run as root and fix ownership
            docker exec "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh && chown -R $CONTAINER_USER:$CONTAINER_USER /home/$CONTAINER_USER/bin /home/$CONTAINER_USER/.container 2>/dev/null || true"
        fi
    fi
else
    # If the user doesn't exist, just install for root
    echo "User $CONTAINER_USER doesn't exist in the container, installing for root..."
    docker exec "$CONTAINER_NAME" bash -c "/tmp/install-commands.sh"
fi

# Try the more robust direct command approach if the script method fails
if [ $? -ne 0 ]; then
    echo "Falling back to direct command approach..."
    
    # Check if user exists
    if docker exec "$CONTAINER_NAME" bash -c "id -u $CONTAINER_USER" >/dev/null 2>&1; then
        # Create directories as root
        echo "Creating directories for user $CONTAINER_USER..."
        docker exec "$CONTAINER_NAME" bash -c "mkdir -p /home/$CONTAINER_USER/bin /home/$CONTAINER_USER/.container"
        
        # Copy the commands file
        echo "Installing container commands..."
        docker cp "$TMP_COMMANDS_FILE" "$CONTAINER_NAME:/home/$CONTAINER_USER/.container/container-commands.sh"
        docker exec "$CONTAINER_NAME" bash -c "chmod +x /home/$CONTAINER_USER/.container/container-commands.sh"
        
        # Add source to bashrc if not already there
        echo "Updating bashrc..."
        docker exec "$CONTAINER_NAME" bash -c "grep -q 'source.*container-commands.sh' /home/$CONTAINER_USER/.bashrc || echo 'source \$HOME/.container/container-commands.sh' >> /home/$CONTAINER_USER/.bashrc"
        
        # Create the bin scripts with a heredoc-like approach
        echo "Creating command scripts..."
        docker exec "$CONTAINER_NAME" bash -c "cat > /home/$CONTAINER_USER/bin/container-detach << 'EOC'
#!/bin/bash
echo \"Detaching from container (container keeps running)...\"
echo \"Container will continue running in the background.\"
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC"
        docker exec "$CONTAINER_NAME" bash -c "chmod +x /home/$CONTAINER_USER/bin/container-detach"

        docker exec "$CONTAINER_NAME" bash -c "cat > /home/$CONTAINER_USER/bin/container-stop << 'EOC'
#!/bin/bash
echo \"Stopping container...\"
echo \"Container will be stopped but can be started again.\"
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC"
        docker exec "$CONTAINER_NAME" bash -c "chmod +x /home/$CONTAINER_USER/bin/container-stop"

        docker exec "$CONTAINER_NAME" bash -c "cat > /home/$CONTAINER_USER/bin/container-remove << 'EOC'
#!/bin/bash
echo \"Removing container...\"
echo \"Container will be stopped and removed permanently.\"
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC"
        docker exec "$CONTAINER_NAME" bash -c "chmod +x /home/$CONTAINER_USER/bin/container-remove"

        docker exec "$CONTAINER_NAME" bash -c "cat > /home/$CONTAINER_USER/bin/container-help << 'EOC'
#!/bin/bash
echo \"Container Commands:\"
echo \"  - container-detach: Detach from the container (container keeps running)\"
echo \"  - container-stop: Stop the container (container will be stopped but not removed)\"
echo \"  - container-remove: Stop and remove the container completely\"
echo \"  - container-help: Show this help message\"
EOC"
        docker exec "$CONTAINER_NAME" bash -c "chmod +x /home/$CONTAINER_USER/bin/container-help"
        
        # Add PATH if needed
        echo "Updating PATH..."
        docker exec "$CONTAINER_NAME" bash -c "grep -q 'export PATH=\"\$HOME/bin:\$PATH\"' /home/$CONTAINER_USER/.bashrc || echo 'export PATH=\"\$HOME/bin:\$PATH\"' >> /home/$CONTAINER_USER/.bashrc"
        
        # Add container-help to bashrc
        docker exec "$CONTAINER_NAME" bash -c "grep -q 'container-help' /home/$CONTAINER_USER/.bashrc || echo 'container-help' >> /home/$CONTAINER_USER/.bashrc"
        
        # Fix ownership
        echo "Setting correct ownership..."
        docker exec "$CONTAINER_NAME" bash -c "chown -R $CONTAINER_USER:$CONTAINER_USER /home/$CONTAINER_USER/bin /home/$CONTAINER_USER/.container"
        
        # Try to install system-wide commands if possible
        echo "Attempting to install system-wide commands..."
        docker exec "$CONTAINER_NAME" bash -c "if [ -w /usr/local/bin ]; then ln -sf /home/$CONTAINER_USER/bin/container-detach /usr/local/bin/; ln -sf /home/$CONTAINER_USER/bin/container-stop /usr/local/bin/; ln -sf /home/$CONTAINER_USER/bin/container-remove /usr/local/bin/; ln -sf /home/$CONTAINER_USER/bin/container-help /usr/local/bin/; fi"
        
        echo "Container commands installed directly for user $CONTAINER_USER."
    else
        echo "User $CONTAINER_USER does not exist in the container. Please specify a valid user."
        exit 1
    fi
fi

# Run the global system-wide installer one more time to ensure commands are available for all users
install_for_all_users

# Special handling for CROPS/poky containers
if docker exec "$CONTAINER_NAME" bash -c "grep -q crops/poky /etc/motd 2>/dev/null || grep -q poky /etc/motd 2>/dev/null || docker --version | grep -q Docker 2>/dev/null || [ -d /workdir ]"; then
    echo "Detected CROPS/poky container or container with /workdir, using special handling..."
    
    # Create simplified command scripts that will be copied to the container
    TMP_POKY_DIR=$(mktemp -d)
    
    # Create container-detach script
    cat > "$TMP_POKY_DIR/container-detach" << 'EOF'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOF
    
    # Create container-stop script
    cat > "$TMP_POKY_DIR/container-stop" << 'EOF'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOF
    
    # Create container-remove script
    cat > "$TMP_POKY_DIR/container-remove" << 'EOF'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOF
    
    # Create container-help script
    cat > "$TMP_POKY_DIR/container-help" << 'EOF'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOF
    
    # Make all scripts executable
    chmod +x "$TMP_POKY_DIR"/*
    
    # Create init script that will be sourced to add scripts to PATH
    cat > "$TMP_POKY_DIR/container-init.sh" << 'EOF'
#!/bin/bash
# Container commands initialization script
# This will be added to profile.d or bashrc

# Add container commands to PATH if they exist
if [ -d "/workdir/.container_commands" ]; then
    CMD_DIR="/workdir/.container_commands"
    export PATH="$CMD_DIR:$PATH"
elif [ -d "/tmp/.container_commands" ]; then
    CMD_DIR="/tmp/.container_commands"
    export PATH="$CMD_DIR:$PATH"
fi

# Show help message if this is an interactive shell and help script exists
if [ -t 0 ]; then
    if command -v container-help >/dev/null 2>&1; then
        container-help
    fi
fi
EOF
    
    # Copy all scripts to the container
    docker cp "$TMP_POKY_DIR/." "$CONTAINER_NAME:/tmp/poky_commands/"
    
    # Execute script in container to set up commands
    docker exec "$CONTAINER_NAME" bash -c '
        # Try workdir first, but if it is not writable, fall back to tmp
        if [ -d /workdir ] && [ -w /workdir ]; then
            CMD_DIR=/workdir/.container_commands
            mkdir -p "$CMD_DIR"
        else
            CMD_DIR=/tmp/.container_commands
            mkdir -p "$CMD_DIR"
        fi
        
        echo "Using command directory: $CMD_DIR"
        
        # Copy command scripts from temporary location
        if [ -d /tmp/poky_commands ]; then
            cp -f /tmp/poky_commands/container-* "$CMD_DIR/" 2>/dev/null || true
            chmod +x "$CMD_DIR"/* 2>/dev/null || true
            
            # Fallback direct copying if wildcard fails
            for cmd in container-detach container-stop container-remove container-help container-init.sh; do
                if [ -f "/tmp/poky_commands/$cmd" ]; then
                    cp -f "/tmp/poky_commands/$cmd" "$CMD_DIR/" 2>/dev/null || true
                    chmod +x "$CMD_DIR/$cmd" 2>/dev/null || true
                fi
            done
        fi
        
        # Create system-wide symlinks if possible
        if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
            ln -sf "$CMD_DIR/container-detach" /usr/local/bin/container-detach 2>/dev/null || true
            ln -sf "$CMD_DIR/container-stop" /usr/local/bin/container-stop 2>/dev/null || true
            ln -sf "$CMD_DIR/container-remove" /usr/local/bin/container-remove 2>/dev/null || true
            ln -sf "$CMD_DIR/container-help" /usr/local/bin/container-help 2>/dev/null || true
            echo "Created system-wide symlinks in /usr/local/bin"
        fi
    '
fi

# Clean up temporary files
rm -rf "$TMP_COMMANDS_DIR"
[ -d "$TMP_POKY_DIR" ] && rm -rf "$TMP_POKY_DIR"

echo "Container commands successfully added to $CONTAINER_NAME for all users."
echo "Commands will be available in all new shell sessions."
echo "In VS Code Attach to Container sessions, these commands will also be available."
