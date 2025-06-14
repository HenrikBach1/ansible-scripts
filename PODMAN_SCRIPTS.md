# Podman Container Scripts Documentation

This document lists all the Podman-based container scripts and their purposes.

## Installation Scripts

### `podman-install.yml`
Ansible playbook to install and configure Podman on Ubuntu systems.
- Adds Podman repository (Ubuntu 22.04+)
- Installs Podman, Buildah, and Skopeo
- Configures rootless operation
- Sets up registries and lingering for user containers

### `setup-podman-user.yml`
Ansible playbook to configure Podman for a specific user.
- Creates Podman configuration directories
- Sets up storage and registries configuration
- Tests Podman functionality
- Provides troubleshooting guidance

### `yocto-in-podman-install.yml`
Complete Yocto development environment setup using Podman.
- Creates Yocto workspace directories
- Pulls CROPS/poky container image
- Creates and configures Yocto container
- Installs container management commands
- Creates project initialization scripts

### `ros2-in-podman-install.yml`
Complete ROS2 development environment setup using Podman.
- Validates ROS2 LTS releases
- Creates ROS2 workspace
- Pulls ROS2 container images
- Creates and configures ROS2 container
- Sets up ROS2 environment and build tools

## Container Management Scripts

### `start-yocto-container-podman.sh`
Main script for creating and managing Yocto containers with Podman.
- Creates CROPS/poky-based containers
- Mounts workspace directories with proper SELinux labels
- Sets up environment variables for Yocto development
- Uses shared runner library for consistency

### `restart-yocto-container-podman.sh`
Restarts Yocto Podman containers with proper persistence.
- Stops and removes existing container
- Recreates with same configuration
- Installs container commands
- Provides container status and connection info

### `restart-ros2-container-podman.sh`
Restarts ROS2 Podman containers with proper persistence.
- Detects ROS2 distribution automatically
- Preserves workspace mounts
- Sets up ROS2 environment variables
- Creates persistent container process

## Connection Scripts

### `yocto-podman-connect`
Enhanced connection script for Yocto Podman containers.
- Starts container if not running
- Installs container commands automatically
- Provides Yocto-specific welcome message
- Handles container lifecycle

### `ros2-podman-connect`
Enhanced connection script for ROS2 Podman containers.
- Detects ROS2 distribution automatically
- Sources ROS2 environment setup
- Sets up workspace environment
- Provides ROS2-specific help and commands

## Utility Scripts

### `podman-exec-it`
Interactive Podman exec wrapper with enhanced functionality.
- Provides help, detach, stop, and bash commands
- Shows container status and available containers
- Mirrors Docker exec functionality
- Includes container command guidance

### `podman-exec-detached`
Detached Podman exec wrapper for background commands.
- Runs commands in background without blocking
- Ensures container stays running
- Uses container utilities if available
- Provides fallback implementation

### `ensure-yocto-container-commands-podman.sh`
Specialized script for installing container commands in Podman containers.
- Uses shared container-command-common.sh library
- Provides robust command installation
- Handles Podman-specific container access
- Ensures container commands are available

### `setup-vscode-podman.sh`
Configures VS Code to work with Podman containers for Remote-Containers extension.
- Starts and enables Podman socket service
- Sets up DOCKER_HOST environment variable for Docker compatibility
- Configures VS Code settings.json for Podman integration
- Provides instructions for VS Code Remote-Containers usage

**Usage:**
```bash
./setup-vscode-podman.sh
```

**What it does:**
- Enables `podman.socket` systemd service for Docker API compatibility
- Adds `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock` to ~/.bashrc
- Updates VS Code settings to use Podman socket
- Configures `dev.containers.dockerPath` to use `podman`

**After running this script:**
1. Restart VS Code
2. Install "Dev Containers" extension if not already installed
3. Use `Ctrl+Shift+P` → "Dev Containers: Attach to Running Container..."
4. Select your Podman container from the list

## VS Code Launcher Script

### `vscode-with-podman.sh`
Simple, fast VS Code launcher with Podman environment setup.
- Quick environment setup with minimal output
- Shows available containers and API status
- Launches VS Code with proper Podman integration
- Essential information display without verbose logging

**Usage:**
```bash
# Launch VS Code with Podman environment (current directory)
./vscode-with-podman.sh

# Launch VS Code with specific workspace
./vscode-with-podman.sh /path/to/workspace

# Launch from project directory
cd ~/projects && ./ansible/iac-scripts/vscode-with-podman.sh
```

**What this script does:**
- Export `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock`
- Start Podman socket service if needed
- Test Podman API connectivity
- Show available containers
- Launch VS Code with proper environment for Remote-Containers extension

## Shared Libraries

### Updates to `container-command-common.sh`
Added Podman support functions:
- `detect_container_type_podman()`: Detects container type for Podman
- `install_container_commands_podman()`: Installs commands in Podman containers
- Handles Podman-specific container operations
- Maintains compatibility with Docker functions

## Usage Examples

### Basic Yocto Development
```bash
# Install Podman
ansible-playbook podman-install.yml

# Set up Yocto environment
ansible-playbook yocto-in-podman-install.yml

# Connect to container
./yocto-podman-connect yocto-workspace-container

# Start development
cd /workdir
./init-yocto-project.sh
```

### Basic ROS2 Development
```bash
# Install Podman
ansible-playbook podman-install.yml

# Set up ROS2 environment
ansible-playbook ros2-in-podman-install.yml

# Connect to container
./ros2-podman-connect ros2-workspace-container

# Build workspace
colcon build
```

### Container Management
```bash
# Interactive access
./podman-exec-it <container-name> bash

# Run background command
./podman-exec-detached <container-name> "make -j4"

# Restart container
./restart-yocto-container-podman.sh yocto-workspace-container
```

## Key Features

### Rootless Operation
- No root privileges required
- No daemon running as root
- Better security isolation
- User-specific container storage

### SELinux Compatibility
- Proper volume labeling with `:Z` flag
- Works with enforcing SELinux policies
- Maintains security context separation

### Drop-in Docker Replacement
- Same command syntax as Docker scripts
- Compatible with existing workflows
- Shared container command system
- Consistent user experience

### Full Feature Parity
- All Docker script functionality available
- Same container commands (help, detach, stop, remove)
- Same workspace mounting patterns
- Same development environment setup

## Files Created

All Podman scripts are located in the same directory as Docker scripts:
- `/home/sad/projects/ansible/iac-scripts/`

The scripts follow the same naming conventions with `-podman` suffix or `podman-` prefix to distinguish them from Docker equivalents.
