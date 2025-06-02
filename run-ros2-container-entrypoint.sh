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

# Source ROS2 setup
source /opt/ros/$1/setup.bash

# Display help message
echo ""
echo "ROS2 Container Commands:"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container"
echo "  - Ctrl+P, Ctrl+Q: Standard Docker detach sequence (alternative method)"
echo "  - Ctrl+D: Standard shell exit (stops the container)"
echo ""

# Create a bin directory in the user's home
mkdir -p $HOME/bin

# Add bash functions to .bashrc for detach and stop
cat > $HOME/.bash_aliases << 'EOF'
# Define detach function to properly detach from container
detach() {
    echo "Detaching from container (container keeps running)..."
    # Send SIGHUP to the parent process - this is the most reliable method to detach
    # without stopping the container in various terminal environments including VS Code
    kill -HUP $PPID
}

# Override exit to behave like detach
exit() {
    echo "Using 'exit' to detach from container (container keeps running)..."
    detach
}

# Define stop function to actually exit
stop() {
    echo "Stopping container..."
    builtin exit
}

# Set a trap to handle Ctrl+C and other signals
trap '' INT QUIT TSTP
EOF

# Make sure aliases are loaded
echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> $HOME/.bashrc

# Add bash completion for our custom commands
cat > $HOME/.bash_completion << 'EOF'
# Bash completion for custom container commands
complete -W "detach stop" -f bash
EOF

echo "if [ -f ~/.bash_completion ]; then . ~/.bash_completion; fi" >> $HOME/.bashrc

# Create executable scripts in bin directory
# Create executable scripts in bin directory
cat > $HOME/bin/detach << 'EOF'
#!/bin/bash
echo "Detaching from container (container keeps running)..."
# The most reliable way to detach from a Docker container in VS Code terminal
# is to send a SIGHUP signal to the parent process
PPID_TO_KILL=$PPID
# Trap any errors
trap 'echo "Detach failed, trying alternative method..."; kill -TERM $PPID_TO_KILL' ERR

# Try SIGHUP first (most reliable method)
kill -HUP $PPID_TO_KILL
# If we get here, the first method failed, try SIGTERM as a fallback
kill -TERM $PPID_TO_KILL
EOF

cat > $HOME/bin/stop << 'EOF'
#!/bin/bash
echo "Stopping container..."
echo "Container will be stopped and session will end."
# Use exit directly - this will terminate the bash session
# and consequently stop the container if it was started with --rm
builtin exit
EOF

# Create a help script
cat > $HOME/bin/container-help << 'EOF'
# #!/bin/bash
# echo "ROS2 Container Command Guide:"
# echo "-----------------------------"
# echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
# echo "  - Type 'stop': Stop the container"
# echo "  - Type 'container-help': Show this help message"
# echo "  - Ctrl+P, Ctrl+Q: Standard Docker detach sequence (alternative method)"
# echo "  - Ctrl+D: Standard shell exit (stops the container if used outside of custom commands)"
# echo ""
# echo "Note: These commands provide the most reliable way to detach from the container"
# echo "      without stopping it in VS Code terminal."
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
