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

For information on connecting to your ROS2 container using VS Code, see [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md).

By default, all containers are set up to be discoverable by VS Code's Remote - Containers extension. If you don't want this feature, you can disable it with:

```bash
./run-ros2-container.sh --no-vscode
```