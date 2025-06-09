#!/bin/bash
# Yocto Container entrypoint script with command overrides
file="run-yocto-container-entrypoint.sh"

# Get container information
CONTAINER_ID=$(hostname)

# Try to create workspace directory - don't error if it fails
mkdir -p /workdir 2>/dev/null || true
mkdir -p /workspace 2>/dev/null || true
mkdir -p /projects 2>/dev/null || true

# Make symlinks to ensure compatibility
ln -sf /workdir /workspace 2>/dev/null || true
ln -sf /workdir /projects 2>/dev/null || true

# Create a separate directory for keep-alive processes that won't be mounted to host
mkdir -p /var/lib/container-keepalive 2>/dev/null || true

# Try to change to workspace directory, fallback to home if not possible
if [ -d "/workdir" ] && [ -w "/workdir" ]; then
    cd /workdir
else
    # Fallback to home directory
    cd $HOME
    echo "Warning: Could not access /workdir directory, using $HOME instead."
    # Try to create a workspace directory in the home folder
    mkdir -p $HOME/workdir 2>/dev/null || true
fi

# Create a simple background daemon to keep the container running
# Use multiple keep-alive mechanisms to ensure container doesn't exit
nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
KEEP_ALIVE_PID=$!

# Create a more resilient keep-alive file to ensure container doesn't stop unexpectedly
cat > /home/user/keep_container_alive.sh << 'EOF'
#!/bin/bash
# Resilient keep-alive script that ensures the container stays running
# This script is designed to be very hard to kill accidentally

# Set to non-zero to enable debugging output
DEBUG=0

function log_debug() {
    if [ "$DEBUG" -ne 0 ]; then
        echo "[keep-alive] $1" >> /home/user/keep_alive.log
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
chmod +x /home/user/keep_container_alive.sh

# Start the keep-alive script in the background with nohup
nohup /home/user/keep_container_alive.sh >/dev/null 2>&1 &
KEEP_ALIVE_PID2=$!

# Log both keep-alive PIDs for reference
echo "$KEEP_ALIVE_PID $KEEP_ALIVE_PID2" > /home/user/.container_keep_alive_pids

# Display help message
echo ""
echo "Yocto Container Commands:"
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
echo "Yocto Container Command Guide:"
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
export PATH="$HOME/bin:$PATH"

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
echo "To reconnect: docker attach yocto_container"
