#!/bin/bash
# Container entrypoint script with command overrides
file="run-ros2-container-entrypoint.sh"

# Source ROS2 setup
source /opt/ros/$1/setup.bash

# Setup VS Code development tools
if [ ! -f "/home/ubuntu/.vscode_setup_done" ]; then
  echo "Installing VS Code dependencies for remote development..."
  apt-get update -qq > /dev/null 2>&1
  apt-get install -y -qq git curl wget python3-pip > /dev/null 2>&1
  
  # Create necessary directories for VS Code
  mkdir -p /home/ubuntu/.vscode-server/extensions
  
  # Set permissions
  if [ "$(id -u)" != "0" ]; then
    chown -R $(id -u):$(id -g) /home/ubuntu/.vscode-server
  fi
  
  # Mark VS Code setup as done
  touch /home/ubuntu/.vscode_setup_done
fi

# Setup projects directory
if [ ! -d "/home/ubuntu/projects" ]; then
  mkdir -p /home/ubuntu/projects
  
  # If we're running as the current user, fix permissions
  if [ "$(id -u)" != "0" ]; then
    chown -R $(id -u):$(id -g) /home/ubuntu/projects
  fi

  # Create a symbolic link for convenience
  ln -sf /workspace /home/ubuntu/projects
fi

# Get container information
CONTAINER_ID=$(hostname)

# Change to workspace directory
cd /workspace

# Create a simple background daemon to keep the container running
nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
KEEP_ALIVE_PID=$!

# Source ROS2 setup
source /opt/ros/$1/setup.bash

# Display help message
echo ""
echo "ROS2 Container Commands:"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container completely (container will shut down)"
echo "  - Press Ctrl+P Ctrl+Q: Standard Docker detach sequence"
echo "  - Ctrl+D: Standard shell exit (in most cases will detach instead of stopping)"
echo ""

# Create a bin directory in the user's home
mkdir -p $HOME/bin

# Add bash functions to .bashrc for detach and stop
cat > $HOME/.bash_aliases << 'EOF'
# Define detach function to properly detach from container
detach() {
    echo "Detaching from container (container keeps running)..."
    echo "Container will continue running in the background."
    
    # Create a marker file to signal we want to detach
    touch $HOME/.container_detach_requested
    
    # Force disconnect from tty while ensuring container keeps running
    # The background daemon started at container launch will keep it alive
    kill -HUP $PPID || builtin exit 0
}

# Override exit to behave like detach
exit() {
    echo "Using 'exit' to detach from container (container keeps running)..."
    
    # Call our custom detach function
    detach
}

# Define stop function to actually exit and stop the container
stop() {
    echo "Stopping container..."
    echo "Container will be completely stopped (not just detached)."
    
    # Create a marker file to indicate we want to stop the container
    # The container-watch.sh script will see this and stop the container
    touch $HOME/.container_stop_requested
    
    # Kill the keep-alive process if we have it
    if [ -n "$KEEP_ALIVE_PID" ]; then
        kill $KEEP_ALIVE_PID 2>/dev/null || true
    fi
    
    # Output a clear message about what's happening
    echo "Container stop requested. Container will completely shut down."
    echo "Terminating session now..."
    
    # Exit the shell with special status to indicate stop
    builtin exit 0
}

# Source ROS2 environment in every shell
if [ -f /opt/ros/${ROS_RELEASE:-jazzy}/setup.bash ]; then
    source /opt/ros/${ROS_RELEASE:-jazzy}/setup.bash
fi

# Set a trap to handle Ctrl+C and other signals
trap '' INT QUIT TSTP
EOF

# Make sure aliases are loaded
echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> $HOME/.bashrc

# Create a system-wide profile script that will be loaded by all shells
# This ensures commands are available even with docker exec
if [ "$(id -u)" = "0" ]; then
  # Only attempt to create system-wide files if running as root
  cat > /etc/profile.d/container-commands.sh << 'EOF'
# Add the user's bin directory to PATH for all shells
export PATH="/home/ubuntu/bin:$PATH"

# Source bash aliases if they exist
if [ -f /home/ubuntu/.bash_aliases ]; then
    . /home/ubuntu/.bash_aliases
fi
EOF

  chmod +x /etc/profile.d/container-commands.sh
else
  # If not root, just add to user's bashrc
  echo 'export PATH="/home/ubuntu/bin:$PATH"' >> $HOME/.bashrc
fi

# Add a custom bash logout script to prevent accidental container shutdown
cat > $HOME/.bash_logout << 'EOF'
# This script runs when the shell exits
# Create a marker file to signal we want to detach (unless we used 'stop')
if [ ! -f $HOME/.container_stop_requested ]; then
    touch $HOME/.container_detach_requested
    echo "Shell exiting, but container will keep running in the background."
fi
EOF

# Add bash completion for our custom commands
cat > $HOME/.bash_completion << 'EOF'
# Bash completion for custom container commands
complete -W "detach stop" -f bash
EOF

echo "if [ -f ~/.bash_completion ]; then . ~/.bash_completion; fi" >> $HOME/.bashrc

# Fix for container-help and other commands not being available in docker exec
if [ "$(id -u)" = "0" ]; then
  # Only create system-wide commands if running as root
  echo '#!/bin/bash' > /usr/local/bin/container-help
  echo 'echo "ROS2 Container Command Guide:"' >> /usr/local/bin/container-help
  echo 'echo "-----------------------------"' >> /usr/local/bin/container-help
  echo 'echo "  - Type '\''exit'\'' or '\''detach'\'': Detach from container (container keeps running)"' >> /usr/local/bin/container-help
  echo 'echo "  - Type '\''stop'\'': Stop the container completely (container will shut down)"' >> /usr/local/bin/container-help
  echo 'echo "  - Type '\''container-help'\'': Show this help message"' >> /usr/local/bin/container-help
  echo 'echo ""' >> /usr/local/bin/container-help
  echo 'echo "Note: When you detach, a helper script on the host will monitor and restart"' >> /usr/local/bin/container-help
  echo 'echo "      the container if needed, ensuring it continues running in the background."' >> /usr/local/bin/container-help
  echo 'echo ""' >> /usr/local/bin/container-help
  echo 'echo "Note: When you use '\''stop'\'', the container will be completely shut down and"' >> /usr/local/bin/container-help
  echo 'echo "      will not continue running in the background."' >> /usr/local/bin/container-help
  chmod +x /usr/local/bin/container-help

  echo '#!/bin/bash' > /usr/local/bin/detach
  echo 'echo "Detaching from container (container keeps running)..."' >> /usr/local/bin/detach
  echo 'echo "Container will continue running in the background."' >> /usr/local/bin/detach
  echo 'touch /home/ubuntu/.container_detach_requested' >> /usr/local/bin/detach
  echo 'kill -HUP $PPID || builtin exit 0' >> /usr/local/bin/detach
  chmod +x /usr/local/bin/detach

  echo '#!/bin/bash' > /usr/local/bin/stop
  echo 'echo "Stopping container..."' >> /usr/local/bin/stop
  echo 'echo "Container will be completely stopped (not just detached)."' >> /usr/local/bin/stop
  echo 'touch /home/ubuntu/.container_stop_requested' >> /usr/local/bin/stop
  echo 'pkill -f "sleep 3600" || true' >> /usr/local/bin/stop
  echo 'echo "Container stop requested. Container will shut down completely."' >> /usr/local/bin/stop
  echo 'echo "Terminating session now..."' >> /usr/local/bin/stop
  echo 'builtin exit 0' >> /usr/local/bin/stop
  chmod +x /usr/local/bin/stop
else
  # If not root, create in user's bin directory instead
  mkdir -p $HOME/bin
  
  echo '#!/bin/bash' > $HOME/bin/container-help
  echo 'echo "ROS2 Container Command Guide:"' >> $HOME/bin/container-help
  echo 'echo "-----------------------------"' >> $HOME/bin/container-help
  echo 'echo "  - Type '\''exit'\'' or '\''detach'\'': Detach from container (container keeps running)"' >> $HOME/bin/container-help
  echo 'echo "  - Type '\''stop'\'': Stop the container completely (container will shut down)"' >> $HOME/bin/container-help
  echo 'echo "  - Type '\''container-help'\'': Show this help message"' >> $HOME/bin/container-help
  echo 'echo ""' >> $HOME/bin/container-help
  echo 'echo "Note: When you detach, a helper script on the host will monitor and restart"' >> $HOME/bin/container-help
  echo 'echo "      the container if needed, ensuring it continues running in the background."' >> $HOME/bin/container-help
  echo 'echo ""' >> $HOME/bin/container-help
  echo 'echo "Note: When you use '\''stop'\'', the container will be completely shut down and"' >> $HOME/bin/container-help
  echo 'echo "      will not continue running in the background."' >> $HOME/bin/container-help
  chmod +x $HOME/bin/container-help
  
  echo '#!/bin/bash' > $HOME/bin/detach
  echo 'echo "Detaching from container (container keeps running)..."' >> $HOME/bin/detach
  echo 'echo "Container will continue running in the background."' >> $HOME/bin/detach
  echo 'touch $HOME/.container_detach_requested' >> $HOME/bin/detach
  echo 'kill -HUP $PPID || builtin exit 0' >> $HOME/bin/detach
  chmod +x $HOME/bin/detach
  
  echo '#!/bin/bash' > $HOME/bin/stop
  echo 'echo "Stopping container..."' >> $HOME/bin/stop
  echo 'echo "Container will be completely stopped (not just detached)."' >> $HOME/bin/stop
  echo 'touch $HOME/.container_stop_requested' >> $HOME/bin/stop
  echo 'pkill -f "sleep 3600" || true' >> $HOME/bin/stop
  echo 'echo "Container stop requested. Container will shut down completely."' >> $HOME/bin/stop
  echo 'echo "Terminating session now..."' >> $HOME/bin/stop
  echo 'builtin exit 0' >> $HOME/bin/stop
  chmod +x $HOME/bin/stop
  
  # Add to PATH in this session
  export PATH="$HOME/bin:$PATH"
fi

# Run container-help at login, but only add it once

# Add the bin directory to PATH in bashrc
export PATH="$HOME/bin:/usr/local/bin:$PATH"

# Create simple bashrc for docker exec sessions that will auto-load for all sessions
if [ "$(id -u)" = "0" ]; then
  # Only attempt to modify system files if running as root
  cat > /etc/bash.bashrc << 'EOF'
# System-wide .bashrc file for interactive bash shells

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Show container help on login for interactive shells
if [ -t 0 ] && [ -t 1 ]; then
  if command -v container-help >/dev/null 2>&1; then
    container-help
  fi
fi
EOF
fi

# Simplify by removing custom exit/detach from user's .bashrc
# Just use the system-wide command that's now available everywhere

# Run container-help at login, but only add it once
if ! grep -q "container-help" $HOME/.bashrc; then
    echo '# Display container help at login (only once)' >> $HOME/.bashrc
    echo 'container-help' >> $HOME/.bashrc
fi

# Add ROS2 source command to .bashrc if not already present
ROS_RELEASE="$1"
if ! grep -q "source /opt/ros/.*setup.bash" $HOME/.bashrc; then
    echo "" >> $HOME/.bashrc
    echo "# Source ROS2 setup automatically" >> $HOME/.bashrc
    echo "source /opt/ros/${ROS_RELEASE}/setup.bash" >> $HOME/.bashrc
    echo "Added ROS2 source command to user's .bashrc file."
fi

# Also add ROS2 source command to a more reliable source location
# Create a profile script that will be loaded by all shells
echo "#!/bin/bash" > $HOME/.ros_profile
echo "source /opt/ros/${ROS_RELEASE}/setup.bash" >> $HOME/.ros_profile
chmod +x $HOME/.ros_profile

# Create a symlink in user's bin directory
mkdir -p $HOME/bin
ln -sf $HOME/.ros_profile $HOME/bin/ros_setup

# Add the script to .profile if not already there
if ! grep -q "source.*/.ros_profile" $HOME/.profile 2>/dev/null; then
    echo "" >> $HOME/.profile
    echo "# Source ROS2 setup automatically" >> $HOME/.profile
    echo "source \$HOME/.ros_profile" >> $HOME/.profile
fi

# Add to system-wide bashrc to ensure it's sourced in all shells
if [ "$(id -u)" = "0" ]; then
    # Only attempt to modify system files if running as root
    if ! grep -q "source /opt/ros/.*setup.bash" /etc/bash.bashrc; then
        echo "" >> /etc/bash.bashrc
        echo "# Source ROS2 setup for all users" >> /etc/bash.bashrc
        echo "source /opt/ros/${ROS_RELEASE}/setup.bash" >> /etc/bash.bashrc
    fi
    
    # Also add to /etc/profile.d
    echo "#!/bin/bash" > /etc/profile.d/ros_setup.sh
    echo "source /opt/ros/${ROS_RELEASE}/setup.bash" >> /etc/profile.d/ros_setup.sh
    chmod +x /etc/profile.d/ros_setup.sh
else
    # If not running as root, don't try to use sudo at all
    # Just rely on user-level configuration
    echo "# Running as non-root user, skipping system-wide configurations"
fi

# Create helper script to source ROS and run commands
echo '#!/bin/bash' > $HOME/bin/source_ros
echo "source /opt/ros/${ROS_RELEASE}/setup.bash" >> $HOME/bin/source_ros
echo 'exec "$@"' >> $HOME/bin/source_ros
chmod +x $HOME/bin/source_ros

# Execute the provided command or fallback to bash
shift
if [ $# -gt 0 ]; then
  exec "$@"
else
  exec bash
fi
