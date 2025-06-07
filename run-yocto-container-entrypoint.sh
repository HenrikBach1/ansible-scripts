#!/bin/bash
# Yocto Container entrypoint script with command overrides
file="run-yocto-container-entrypoint.sh"

# Get Yocto release from first argument
YOCTO_RELEASE="$1"
shift

# Setup projects directory
if [ ! -d "/home/ubuntu/yocto_ws" ]; then
  mkdir -p /home/ubuntu/yocto_ws/build
  
  # If we're running as the current user, fix permissions
  if [ "$(id -u)" != "0" ]; then
    chown -R $(id -u):$(id -g) /home/ubuntu/yocto_ws
  fi

  # Create a symbolic link for convenience
  ln -sf /workspace /home/ubuntu/yocto_ws
fi

# Get container information
CONTAINER_ID=$(hostname)

# Change to workspace directory
cd /home/$(id -u)/yocto_ws

# Create a simple background daemon to keep the container running
nohup bash -c "while true; do sleep 3600; done" >/dev/null 2>&1 &
KEEP_ALIVE_PID=$!

# Display help message
echo ""
echo "Yocto Container Commands:"
echo "  - Type 'exit' or 'detach': Detach from container (container keeps running)"
echo "  - Type 'stop': Stop the container completely (container will shut down)"
echo "  - Type 'yocto_init': Helper to clone and set up Yocto automatically"
echo "  - Press Ctrl+P followed by Ctrl+Q: Standard Docker detach sequence"
echo "  - Ctrl+D: Standard shell exit (in most cases will detach instead of stopping)"
echo ""
echo "Yocto Release Target: $YOCTO_RELEASE"
echo "NOTE: This is a CROPS/poky build environment container that contains the tools"
echo "      needed to build Yocto, but DOES NOT include the Poky/Yocto source code."
echo "      You need to clone the Poky repository with the branch/tag for $YOCTO_RELEASE."
echo ""
echo "Yocto Quick Start:"
echo "  1. Clone Poky: git clone -b $YOCTO_RELEASE git://git.yoctoproject.org/poky"
echo "  2. Initialize build environment: source poky/oe-init-build-env"
echo "  3. Start a build: bitbake core-image-minimal"
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

# Define helper functions for Yocto
yocto_init() {
    if [ ! -d "poky" ]; then
        echo "Poky directory not found. Do you want to clone it? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Cloning Yocto Poky repository (branch: $YOCTO_RELEASE)..."
            git clone -b "$YOCTO_RELEASE" git://git.yoctoproject.org/poky
            if [ $? -ne 0 ]; then
                echo "Failed to clone Poky repository. Please check your network connection and the branch name."
                return 1
            fi
        else
            echo "Poky directory is required for Yocto development."
            return 1
        fi
    fi
    
    echo "Initializing Yocto build environment..."
    source poky/oe-init-build-env "$@"
}

yocto_build() {
    if [ ! -f "conf/local.conf" ]; then
        echo "Error: Not in a build directory. Run 'yocto_init' first."
        return 1
    fi
    
    echo "Building Yocto image: $1"
    bitbake "$@"
}

yocto_clean() {
    if [ ! -f "conf/local.conf" ]; then
        echo "Error: Not in a build directory. Run 'yocto_init' first."
        return 1
    fi
    
    echo "Cleaning Yocto build for: $1"
    bitbake -c cleansstate "$@"
}

yocto_status() {
    echo "Yocto Environment Status:"
    echo "------------------------"
    echo "Yocto Release: $YOCTO_RELEASE"
    echo "Workspace: $(pwd)"
    
    if [ -d "poky" ]; then
        echo "Poky directory exists: Yes"
        echo "Poky branch: $(cd poky && git branch --show-current)"
    else
        echo "Poky directory exists: No (run 'yocto_init' to set up)"
    fi
    
    if [ -d "build" ]; then
        echo "Build directory exists: Yes"
    else
        echo "Build directory exists: No"
    fi
    
    if [ -f "build/conf/local.conf" ]; then
        echo "Configuration exists: Yes"
        echo "Machine: $(grep "^MACHINE " build/conf/local.conf | cut -d'"' -f2)"
        echo "Distro: $(grep "^DISTRO " build/conf/local.conf | cut -d'"' -f2)"
    else
        echo "Configuration exists: No"
    fi
}

# Set a trap to handle Ctrl+C and other signals
trap '' INT QUIT TSTP
EOF

# Make sure aliases are loaded
echo "if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi" >> $HOME/.bashrc

# Add a custom bash logout script to prevent accidental container shutdown
cat > $HOME/.bash_logout << 'EOF'
# This script runs when the shell exits
# By default, we want to detach rather than stop the container
if [ -z "$HOME/.container_stop_requested" ]; then
    # Create a marker file to signal we want to detach
    touch $HOME/.container_detach_requested
fi
EOF

# Execute the command with trap to keep container alive
trap 'echo "Shell session ended, keeping container alive..."; while true; do sleep 3600; done' EXIT

echo "Executing command: $@"
if [ $# -gt 0 ]; then
  "$@"
else
  bash
fi

# If execution reaches here, the command has completed or exited
# The trap will keep the container running
echo "Interactive session ended, but container will keep running in the background."
echo "To reconnect: docker attach yocto_container"
