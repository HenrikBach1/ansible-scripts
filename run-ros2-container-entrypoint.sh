#!/bin/bash
# Container entrypoint script with command overrides
file="run-ros2-container-entrypoint.sh"

# Source ROS2 setup
source /opt/ros/$1/setup.bash

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

# Set a trap to handle Ctrl+C and other signals
trap '' INT QUIT TSTP
EOF

# Make sure aliases are loaded
echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> $HOME/.bashrc

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

# Create executable scripts in bin directory
cat > $HOME/bin/detach << 'EOF'
#!/bin/bash
echo "Detaching from container (container keeps running)..."
echo "Container will continue running in the background."

# Create a marker file to signal we want to detach
touch $HOME/.container_detach_requested

# Force disconnect from tty while ensuring container keeps running
kill -HUP $PPID || builtin exit 0
EOF

cat > $HOME/bin/stop << 'EOF'
#!/bin/bash
echo "Stopping container..."
echo "Container will be completely stopped (not just detached)."

# Create a marker file to indicate we want to stop the container
touch $HOME/.container_stop_requested

# Kill any background processes keeping the container alive
pkill -f "sleep 3600" || true

# Output a clear message about what's happening
echo "Container stop requested. Container will shut down completely."
echo "Terminating session now..."

# Use exit directly - this will terminate the bash session
builtin exit 0
EOF

# Create a help script
cat > $HOME/bin/container-help << 'EOF'
#!/bin/bash
echo "ROS2 Container Command Guide:"
echo "-----------------------------"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container completely (container will shut down)"
echo "  - Type 'container-help': Show this help message"
echo ""
echo "Note: When you detach, a helper script on the host will monitor and restart"
echo "      the container if needed, ensuring it continues running in the background."
echo ""
echo "Note: When you use 'stop', the container will be completely shut down and"
echo "      will not continue running in the background."
EOF

chmod +x $HOME/bin/container-help

# Make the scripts executable
chmod +x $HOME/bin/detach
chmod +x $HOME/bin/stop

# Create a symbolic link for exit -> detach
ln -sf $HOME/bin/detach $HOME/bin/exit

# Add the bin directory to PATH
export PATH="$HOME/bin:$PATH"

# Run container-help at login, but only add it once
if ! grep -q "container-help" $HOME/.bashrc; then
    echo '# Display container help at login (only once)' >> $HOME/.bashrc
    echo 'container-help' >> $HOME/.bashrc
fi

# Execute the provided command or fallback to bash
shift
if [ $# -gt 0 ]; then
  exec "$@"
else
  exec bash
fi
