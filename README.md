# ansible-scripts

This repository contains Ansible scripts and supporting shell scripts for setting up and managing environments.

## ROS2 Docker Container

The `run-ros2-container.sh` script allows you to create and manage a ROS2 Docker container with X11 forwarding, GPU support, and other useful features.

### Key Features:

- **X11 Forwarding**: Run GUI applications from inside the container
- **Workspace Mounting**: Your projects directory is mounted automatically
- **Persistence**: Container state is preserved between sessions
- **GPU Support**: Optional NVIDIA GPU passthrough
- **VS Code Integration**: Remote development with VS Code

### Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./run-ros2-container.sh

# Run with a specific ROS2 distribution
./run-ros2-container.sh --distro iron

# Create a persistent container with GPU support
./run-ros2-container.sh --persistent --gpu --name my_ros2_dev
```

For detailed usage and all available options, run:
```bash
./run-ros2-container.sh --help
```

## VS Code Remote Development

For detailed information on connecting to your ROS2 container using VS Code, see [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md).

### Benefits of VS Code Remote Development:

- **Full IDE Experience**: Use all VS Code features inside the container
- **Extensions**: Install and use VS Code extensions directly in the container
- **Debugging**: Debug your ROS2 applications with full debugger support
- **Integrated Terminal**: Access the container's terminal directly from VS Code
- **File Editing**: Edit files in the container with full language support
- **Source Control**: Use Git and other SCM tools directly in the container

By default, all containers are set up to be discoverable by VS Code's Remote - Containers extension. If you don't want this feature, you can disable it with:

```bash
./run-ros2-container.sh --no-vscode
```

### ROS2 Environment Setup

All containers automatically have the ROS2 environment sourced in:
- Login shells (VS Code terminals)
- Interactive sessions

For non-interactive or non-login shells, use the provided wrapper script:
```bash
~/bin/source_ros ros2 <command>
```

## Container Environment

The ROS2 container is configured with several features to improve usability:

### Automatic ROS2 Sourcing

The container automatically sources the appropriate ROS2 setup file (`/opt/ros/<release>/setup.bash`) in:
- The user's `.bashrc` file
- Login shells
- Interactive shells

This ensures that ROS2 commands work without manual sourcing in most scenarios, especially when accessing the container through VS Code Remote Development.

### Container Commands

Custom commands available inside the container:
- `detach`: Disconnect from the container while keeping it running
- `stop`: Completely stop the container
- `container-help`: Display help information about container commands
- `source_ros`: A wrapper script to run commands with the ROS2 environment sourced

For more details on using these commands and accessing the container via VS Code, see [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md).