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

# Function to install commands for all users in the container
install_for_all_users() {
    echo "Installing commands for all users in the container..."
    
    # Create system-wide commands in /usr/local/bin
    docker exec "$CONTAINER_NAME" bash -c "
        echo 'Installing system-wide commands in /usr/local/bin...'
        # Create the command scripts
        cat > /usr/local/bin/container-detach << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC

        cat > /usr/local/bin/container-stop << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC

        cat > /usr/local/bin/container-remove << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC

        cat > /usr/local/bin/container-help << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC

        # Make all command scripts executable
        chmod 755 /usr/local/bin/container-* || true
        
        # Create global profile script to display help on login
        if [ -d /etc/profile.d ]; then
            echo 'Creating global profile script...'
            cat > /etc/profile.d/container-commands.sh << 'EOC'
#!/bin/bash
# Container commands helper
if [ -x /usr/local/bin/container-help ]; then
    # Only show help if we're in an interactive shell
    if [ -t 0 ]; then
        /usr/local/bin/container-help
    fi
fi
EOC
            chmod 755 /etc/profile.d/container-commands.sh
        fi
        
        # Create a fallback directory for systems where /usr/local/bin is not in the PATH
        if [ -d /etc/profile.d ]; then
            echo 'Ensuring /usr/local/bin is in PATH for all users...'
            cat > /etc/profile.d/container-path.sh << 'EOC'
#!/bin/bash
# Ensure /usr/local/bin is in PATH
case \":${PATH}:\" in
    *:/usr/local/bin:*) ;;
    *) export PATH=/usr/local/bin:$PATH ;;
esac
EOC
            chmod 755 /etc/profile.d/container-path.sh
        fi
        
        # For systems without profile.d, add to global bashrc if possible
        if [ ! -d /etc/profile.d ] && [ -f /etc/bash.bashrc ] && [ -w /etc/bash.bashrc ]; then
            echo 'Adding container commands to global bashrc...'
            grep -q 'container-help' /etc/bash.bashrc || cat >> /etc/bash.bashrc << 'EOC'

# Container commands helper
if [ -x /usr/local/bin/container-help ]; then
    # Only show help if we're in an interactive shell
    if [ -t 0 ]; then
        /usr/local/bin/container-help
    fi
fi

# Ensure /usr/local/bin is in PATH
case \":${PATH}:\" in
    *:/usr/local/bin:*) ;;
    *) export PATH=/usr/local/bin:$PATH ;;
esac
EOC
        fi
        
        # Create aliases for home directories of existing users
        echo 'Adding aliases to user home directories...'
        for user_home in /home/*/ /root/; do
            user_bashrc=\"${user_home}.bashrc\"
            if [ -f \"$user_bashrc\" ] && [ -w \"$user_bashrc\" ]; then
                username=$(basename \"$user_home\")
                echo \"Setting up commands for user $username...\"
                
                # Remove any existing entries to avoid duplication
                sed -i '/container-help/d' \"$user_bashrc\" 2>/dev/null || true
                
                # Add new entries
                cat >> \"$user_bashrc\" << 'EOC'

# Container commands helper
if [ -x /usr/local/bin/container-help ]; then
    # Only show help if we're in an interactive shell
    if [ -t 0 ]; then
        /usr/local/bin/container-help
    fi
fi

# Ensure /usr/local/bin is in PATH
case \":${PATH}:\" in
    *:/usr/local/bin:*) ;;
    *) export PATH=/usr/local/bin:$PATH ;;
esac
EOC
            fi
        done
        
        # Create fallback directory in /tmp for systems where /usr/local/bin is not writable
        echo 'Creating fallback commands in /tmp...'
        mkdir -p /tmp/container-commands
        cp /usr/local/bin/container-* /tmp/container-commands/ 2>/dev/null || true
        chmod 755 /tmp/container-commands/* 2>/dev/null || true
        
        # Add fallback to global profile
        if [ -d /etc/profile.d ]; then
            cat > /etc/profile.d/container-fallback.sh << 'EOC'
#!/bin/bash
# Fallback for container commands
if [ ! -x /usr/local/bin/container-help ] && [ -d /tmp/container-commands ]; then
    export PATH=/tmp/container-commands:$PATH
    # Only show help if we're in an interactive shell
    if [ -t 0 ] && [ -x /tmp/container-commands/container-help ]; then
        /tmp/container-commands/container-help
    fi
fi
EOC
            chmod 755 /etc/profile.d/container-fallback.sh
        fi
        
        echo 'Container commands installed system-wide successfully'
    "
    
    return $?
}

# Create script to install the commands
cat > "$TMP_COMMANDS_DIR/install-commands.sh" << 'EOF'
#!/bin/bash
# Script to install container commands within the container

# Detect if we're running as root
if [ "$(id -u)" -eq 0 ]; then
  RUNNING_AS_ROOT=true
  echo "Running installation as root"
else
  RUNNING_AS_ROOT=false
  echo "Running installation as regular user"
fi

# Make sure we have home directory and bin subdirectory
mkdir -p $HOME/bin || { echo "Failed to create $HOME/bin directory"; exit 1; }
mkdir -p $HOME/.container || { echo "Failed to create $HOME/.container directory"; exit 1; }

# Copy the commands file
cp /tmp/container-commands.sh $HOME/.container/ || { echo "Failed to copy container-commands.sh"; exit 1; }

# Make it executable
chmod +x $HOME/.container/container-commands.sh || { echo "Failed to make container-commands.sh executable"; exit 1; }

# Add source to bashrc if not already there
if ! grep -q "source.*container-commands.sh" $HOME/.bashrc; then
  echo "source \$HOME/.container/container-commands.sh" >> $HOME/.bashrc || { echo "Failed to update .bashrc"; exit 1; }
fi

# Create bin scripts with proper error handling
echo "Creating container-detach script..."
cat > $HOME/bin/container-detach << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC
chmod +x $HOME/bin/container-detach || { echo "Failed to make container-detach executable"; exit 1; }

echo "Creating container-stop script..."
cat > $HOME/bin/container-stop << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch $HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC
chmod +x $HOME/bin/container-stop || { echo "Failed to make container-stop executable"; exit 1; }

echo "Creating container-remove script..."
cat > $HOME/bin/container-remove << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch $HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC
chmod +x $HOME/bin/container-remove || { echo "Failed to make container-remove executable"; exit 1; }

echo "Creating container-help script..."
cat > $HOME/bin/container-help << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC
chmod +x $HOME/bin/container-help || { echo "Failed to make container-help executable"; exit 1; }

# Make sure bin directory is in the PATH
if ! grep -q 'export PATH="$HOME/bin:$PATH"' $HOME/.bashrc; then
  echo 'export PATH="$HOME/bin:$PATH"' >> $HOME/.bashrc || { echo "Failed to update PATH in .bashrc"; exit 1; }
fi

# Show help when a user logs in (if not already set)
if ! grep -q 'container-help' $HOME/.bashrc; then
  echo 'container-help' >> $HOME/.bashrc || { echo "Failed to add container-help to .bashrc"; exit 1; }
fi

# Try to create system-wide command links if we have permissions
if [ "$RUNNING_AS_ROOT" = true ] || [ -w /usr/local/bin ]; then
  echo "Creating system-wide command links in /usr/local/bin..."
  ln -sf $HOME/bin/container-detach /usr/local/bin/container-detach
  ln -sf $HOME/bin/container-stop /usr/local/bin/container-stop
  ln -sf $HOME/bin/container-remove /usr/local/bin/container-remove
  ln -sf $HOME/bin/container-help /usr/local/bin/container-help
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
  cp $HOME/bin/container-detach /workdir/.container-commands/ || true
  cp $HOME/bin/container-stop /workdir/.container-commands/ || true
  cp $HOME/bin/container-remove /workdir/.container-commands/ || true
  cp $HOME/bin/container-help /workdir/.container-commands/ || true
  chmod +x /workdir/.container-commands/* || true
  
  echo "Fallback commands added to /workdir/.container-commands/"
fi

echo "Container commands installed successfully for user $(whoami)."
EOF

# Copy the install script to the container and ensure it's executable
docker cp "$TMP_COMMANDS_DIR/install-commands.sh" "$CONTAINER_NAME:/tmp/install-commands.sh"

# Make sure the script is executable by everyone (can be run by any user)
docker exec "$CONTAINER_NAME" bash -c "chmod 755 /tmp/install-commands.sh || true"

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
    
    # For CROPS/poky containers, we'll try a few different locations
    docker exec "$CONTAINER_NAME" bash -c "
        # Try workdir first, but if it's not writable, fall back to tmp
        if [ -w /workdir ]; then
            CMD_DIR=/workdir/.container_commands
            mkdir -p \$CMD_DIR
        else
            CMD_DIR=/tmp/.container_commands
            mkdir -p \$CMD_DIR
        fi
        
        echo \"Using command directory: \$CMD_DIR\"
        
        # Create global command scripts
        cat > \$CMD_DIR/container-detach << 'EOC'
#!/bin/bash
echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0
EOC
        
        cat > \$CMD_DIR/container-stop << 'EOC'
#!/bin/bash
echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0
EOC
        
        cat > \$CMD_DIR/container-remove << 'EOC'
#!/bin/bash
echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0
EOC
        
        cat > \$CMD_DIR/container-help << 'EOC'
#!/bin/bash
echo 'Container Commands:'
echo '  - container-detach: Detach from the container (container keeps running)'
echo '  - container-stop: Stop the container (container will be stopped but not removed)'
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'
EOC
        
        # Make scripts executable
        chmod +x \$CMD_DIR/*
        
        # Create system-wide symlinks if possible
        if [ -w /usr/local/bin ]; then
            ln -sf \$CMD_DIR/container-detach /usr/local/bin/container-detach
            ln -sf \$CMD_DIR/container-stop /usr/local/bin/container-stop
            ln -sf \$CMD_DIR/container-remove /usr/local/bin/container-remove
            ln -sf \$CMD_DIR/container-help /usr/local/bin/container-help
            echo 'Created system-wide symlinks in /usr/local/bin'
        fi
        
        # Create a global bash hook
        if [ -w /etc/profile.d ]; then
            echo '#!/bin/bash' > /etc/profile.d/container-commands.sh
            echo "export PATH=\"\$CMD_DIR:\$PATH\"" >> /etc/profile.d/container-commands.sh
            echo "if [ -x \$CMD_DIR/container-help ] && [ -t 0 ]; then" >> /etc/profile.d/container-commands.sh
            echo "  \$CMD_DIR/container-help" >> /etc/profile.d/container-commands.sh
            echo "fi" >> /etc/profile.d/container-commands.sh
            chmod +x /etc/profile.d/container-commands.sh
            echo 'Created global profile.d hook'
        fi
        
        # Add to bashrc for all users
        for bashrc in /home/*/.bashrc /root/.bashrc; do
            if [ -w \"\$bashrc\" ]; then
                # Remove any existing entries to avoid duplication
                sed -i '/container_commands/d' \"\$bashrc\" 2>/dev/null || true
                sed -i '/container-help/d' \"\$bashrc\" 2>/dev/null || true
                
                # Add path to container commands
                echo '' >> \"\$bashrc\"
                echo '# Container command setup' >> \"\$bashrc\"
                echo 'if [ -d \"/tmp/.container_commands\" ]; then' >> \"\$bashrc\"
                echo '  export PATH=\"/tmp/.container_commands:\$PATH\"' >> \"\$bashrc\"
                echo 'elif [ -d \"/workdir/.container_commands\" ]; then' >> \"\$bashrc\"
                echo '  export PATH=\"/workdir/.container_commands:\$PATH\"' >> \"\$bashrc\"
                echo 'fi' >> \"\$bashrc\"
                echo '' >> \"\$bashrc\"
                echo 'if command -v container-help >/dev/null 2>&1 && [ -t 0 ]; then' >> \"\$bashrc\"
                echo '  container-help' >> \"\$bashrc\"
                echo 'fi' >> \"\$bashrc\"
                echo \"Updated \$bashrc\"
            fi
        done
        
        # Create a universal profile hook that will be sourced by all shells
        if [ -w /etc ]; then
            echo '#!/bin/bash' > /etc/profile.d/container-path.sh
            echo 'if [ -d \"/tmp/.container_commands\" ]; then' >> /etc/profile.d/container-path.sh
            echo '  export PATH=\"/tmp/.container_commands:\$PATH\"' >> /etc/profile.d/container-path.sh
            echo 'elif [ -d \"/workdir/.container_commands\" ]; then' >> /etc/profile.d/container-path.sh
            echo '  export PATH=\"/workdir/.container_commands:\$PATH\"' >> /etc/profile.d/container-path.sh
            echo 'fi' >> /etc/profile.d/container-path.sh
            chmod +x /etc/profile.d/container-path.sh
            echo 'Created global PATH hook in /etc/profile.d/container-path.sh'
        fi
        
        # Create convenience symlinks in common locations
        mkdir -p /tmp/bin
        ln -sf \$CMD_DIR/container-detach /tmp/bin/container-detach
        ln -sf \$CMD_DIR/container-stop /tmp/bin/container-stop
        ln -sf \$CMD_DIR/container-remove /tmp/bin/container-remove
        ln -sf \$CMD_DIR/container-help /tmp/bin/container-help
        chmod +x /tmp/bin/* 2>/dev/null || true
        echo 'Created symlinks in /tmp/bin'
        
        # Add legacy aliases for backward compatibility
        echo '#!/bin/bash' > \$CMD_DIR/detach
        echo 'exec \$CMD_DIR/container-detach' >> \$CMD_DIR/detach
        chmod +x \$CMD_DIR/detach
        
        echo '#!/bin/bash' > \$CMD_DIR/stop
        echo 'exec \$CMD_DIR/container-stop' >> \$CMD_DIR/stop
        chmod +x \$CMD_DIR/stop
        
        echo '#!/bin/bash' > \$CMD_DIR/remove
        echo 'exec \$CMD_DIR/container-remove' >> \$CMD_DIR/remove
        chmod +x \$CMD_DIR/remove
        
        echo '#!/bin/bash' > \$CMD_DIR/help
        echo 'exec \$CMD_DIR/container-help' >> \$CMD_DIR/help
        chmod +x \$CMD_DIR/help
        
        # Create a simple script that allows directly sourcing the PATH
        echo '#!/bin/bash' > \$CMD_DIR/setup-commands.sh
        echo 'export PATH=\"\$CMD_DIR:\$PATH\"' >> \$CMD_DIR/setup-commands.sh
        chmod +x \$CMD_DIR/setup-commands.sh
        
        echo 'CROPS/poky container commands installed successfully'
    "
    
    echo "Container commands added to CROPS/poky container $CONTAINER_NAME."
    echo "Commands will be available in all new shell sessions."
    
    # Run one final system-wide install to ensure maximum compatibility
    install_for_all_users
    
    # Exit early as we've handled this special case
    exit 0
fi

# Clean up temporary files
rm -rf "$TMP_COMMANDS_DIR"

echo "Container commands successfully added to $CONTAINER_NAME for all users."
echo "Commands will be available in all new shell sessions."
echo "In VS Code Attach to Container sessions, these commands will also be available."
