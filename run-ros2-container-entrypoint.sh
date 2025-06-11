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

# Create a separate directory for temporary and system files that won't pollute the workspace
mkdir -p /tmp/.container_commands 2>/dev/null || true
mkdir -p /tmp/bin 2>/dev/null || true
mkdir -p /tmp/keepalive 2>/dev/null || true

# Add /tmp/bin to PATH if not already there
if [[ ":$PATH:" != *":/tmp/bin:"* ]]; then
    export PATH="/tmp/bin:$PATH"
fi

# Also add the fallback command location to PATH
if [[ ":$PATH:" != *":/tmp/.container_commands:"* ]]; then
    export PATH="/tmp/.container_commands:$PATH"
fi

# Store all keep-alive related files in this separate directory, not in the mounted volumes
KEEPALIVE_DIR="/tmp/keepalive"
mkdir -p $KEEPALIVE_DIR

# Try to create workspace directory - don't error if it fails
mkdir -p /workspace 2>/dev/null || true
mkdir -p /projects 2>/dev/null || true

# Create a separate directory for keep-alive processes that won't be mounted to host
mkdir -p /var/lib/container-keepalive 2>/dev/null || true

# Store all keep-alive related files in this separate directory, not in the mounted volumes
KEEPALIVE_DIR="/var/lib/container-keepalive"
mkdir -p $KEEPALIVE_DIR

# Try to change to workspace directory, fallback to home if not possible
if [ -d "/workspace" ] && [ -w "/workspace" ]; then
    cd /workspace
else
    # Fallback to home directory
    cd $HOME
    echo "Warning: Could not access /workspace directory, using $HOME instead."
    # Try to create a workspace directory in the home folder
    mkdir -p $HOME/workspace 2>/dev/null || true
fi

# Create container command definitions in a global bashrc file
CONTAINER_COMMANDS_FILE="/etc/container-commands.sh"
cat > $CONTAINER_COMMANDS_FILE << 'EOF'
#!/bin/bash

# Define container control functions
function detach() {
  echo "Detaching from container (container keeps running)..."
  echo "Container will continue running in the background."
  touch /home/ubuntu/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
  exit 0
}

function stop() {
  echo "Stopping container (container will be stopped)..."
  touch /home/ubuntu/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
  exit 0
}

function stop_container() {
  echo "Stopping container completely..."
  stop
}

function remove() {
  echo "Stopping and removing container..."
  touch /home/ubuntu/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
  exit 0
}

function help() {
  echo "ROS2 Container Commands:"
  echo "------------------------"
  echo "  - Type 'detach': Detach from container (container keeps running)"
  echo "  - Type 'stop': Stop the container (container will be stopped)"
  echo "  - Type 'remove': Stop and remove the container"
  echo "  - Type 'help': Show this help message"
  echo ""
  echo "Extra commands:"
  echo "  - Type 'container_help': Same as 'help'"
  echo "  - Type 'container-help': Same as 'help'"
  echo "  - Type 'stop_container': Same as 'stop'"
  echo ""
  echo "Note: When you detach, a helper script on the host will monitor and restart"
  echo "      the container if needed, ensuring it continues running in the background."
  echo ""
  echo "Note: When you use 'stop', the container will be completely shut down."
  echo "      When you use 'remove', the container will be stopped and removed."
}

function container_help() {
  help
}

function container-help() {
  help
}

# Export functions so they're available in all shells
export -f detach
export -f stop
export -f stop_container
export -f remove
export -f help
export -f container_help
export -f container-help
EOF

# Make the commands file executable
chmod +x $CONTAINER_COMMANDS_FILE

# Add the container commands to system-wide bashrc
echo "source $CONTAINER_COMMANDS_FILE" >> /etc/bash.bashrc

# Create a simple background daemon to keep the container running
# Use multiple keep-alive mechanisms to ensure container doesn't exit
nohup bash -c "while true; do sleep 3600; done" > $KEEPALIVE_DIR/keep_alive.log 2>&1 &
KEEP_ALIVE_PID=$!

# Create a more resilient keep-alive file to ensure container doesn't stop unexpectedly
cat > $KEEPALIVE_DIR/keep_container_alive.sh << 'EOF'
#!/bin/bash
# Resilient keep-alive script that ensures the container stays running
# This script is designed to be very hard to kill accidentally

# Set to non-zero to enable debugging output
DEBUG=0

function log_debug() {
    if [ "$DEBUG" -ne 0 ]; then
        echo "[keep-alive] $1" >> /home/ubuntu/keep_alive.log
    fi
}

log_debug "Starting keep-alive script at $(date)"

# Make this process harder to kill by setting a lower nice value
renice -n -10 $$ >/dev/null 2>&1 || true

# Trap signals to prevent accidental termination
trap "log_debug 'Received termination signal, ignoring'; echo 'Keep-alive process ignoring termination request'" TERM INT QUIT

# Set process name to something that looks like a system process
# This makes it less likely to be killed by automated cleanup scripts
export PS1="[system] "

# Run forever
while true; do
    log_debug "Keep-alive heartbeat at $(date)"
    sleep 60
done
EOF

# Make the script executable
chmod +x /home/ubuntu/keep_container_alive.sh

# Start the keep-alive script in the background with nohup
nohup /home/ubuntu/keep_container_alive.sh >/dev/null 2>&1 &
KEEP_ALIVE_PID2=$!

# Log both keep-alive PIDs for reference
echo "$KEEP_ALIVE_PID $KEEP_ALIVE_PID2" > /home/ubuntu/.container_keep_alive_pids

# Source ROS2 setup
source /opt/ros/$1/setup.bash

# Display help message
echo ""
echo "ROS2 Container Commands:"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container completely (container will shut down)"
echo "  - Press Ctrl+P followed by Ctrl+Q: Standard Docker detach sequence"
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

# Create executable scripts in /tmp/bin directory
cat > /tmp/bin/detach << 'EOF'
#!/bin/bash
echo "Detaching from container (container keeps running)..."
echo "Container will continue running in the background."

# Create a marker file to signal we want to detach
touch $HOME/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested

# Force disconnect from tty while ensuring container keeps running
kill -HUP $PPID || builtin exit 0
EOF

cat > /tmp/bin/stop << 'EOF'
#!/bin/bash
echo "Stopping container..."
echo "Container will be completely stopped (not just detached)."

# Create a marker file to indicate we want to stop the container
touch $HOME/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested

# Kill any background processes keeping the container alive
pkill -f "sleep 3600" || true

# Output a clear message about what's happening
echo "Container stop requested. Container will shut down completely."
echo "Terminating session now..."

# Use exit directly - this will terminate the bash session
builtin exit 0
EOF

# Add container-remove command
cat > /tmp/bin/container-remove << 'EOF'
#!/bin/bash
echo "Removing container..."
echo "Container will be stopped and removed permanently."

# Create a marker file to indicate we want to remove the container
touch $HOME/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested

# Kill any background processes keeping the container alive
pkill -f "sleep 3600" || true

# Output a clear message about what's happening
echo "Container removal requested. Container will be stopped and removed."
echo "Terminating session now..."

# Use exit directly - this will terminate the bash session
builtin exit 0
EOF

# Create a help script
cat > /tmp/bin/container-help << 'EOF'
#!/bin/bash
echo "ROS2 Container Command Guide:"
echo "-----------------------------"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container completely (container will shut down)"
echo "  - Press Ctrl+P followed by Ctrl+Q: Standard Docker detach sequence"
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
export PATH="$HOME/bin:/tmp/bin:/tmp/.container_commands:$PATH"

# Run container-help at login, but only add it once
if ! grep -q "container-help" $HOME/.bashrc; then
    echo '# Display container help at login (only once)' >> $HOME/.bashrc
    echo 'container-help' >> $HOME/.bashrc
fi

# Execute the provided command or fallback to bash with trap to keep container alive
trap 'echo "Shell session ended, keeping container alive..."; while true; do sleep 3600; done' EXIT

shift
if [ $# -gt 0 ]; then
  "$@"
else
  bash
fi

# If execution reaches here, the command has completed or exited
# The trap will keep the container running
echo "Interactive session ended, but container will keep running in the background."
echo "To reconnect: docker attach ros2_container"

# Make all scripts executable
chmod +x /tmp/bin/* 2>/dev/null || true

# Create symbolic links in user's bin directory if it exists
if [ -d "$HOME/bin" ]; then
  ln -sf /tmp/bin/detach $HOME/bin/detach 2>/dev/null || true
  ln -sf /tmp/bin/stop $HOME/bin/stop 2>/dev/null || true
  ln -sf /tmp/bin/container-remove $HOME/bin/container-remove 2>/dev/null || true
  ln -sf /tmp/bin/container-help $HOME/bin/container-help 2>/dev/null || true
fi

# Also create links in /tmp/.container_commands for consistency
ln -sf /tmp/bin/detach /tmp/.container_commands/detach 2>/dev/null || true
ln -sf /tmp/bin/stop /tmp/.container_commands/stop 2>/dev/null || true
ln -sf /tmp/bin/container-remove /tmp/.container_commands/container-remove 2>/dev/null || true
ln -sf /tmp/bin/container-help /tmp/.container_commands/container-help 2>/dev/null || true
chmod +x /tmp/.container_commands/* 2>/dev/null || true
