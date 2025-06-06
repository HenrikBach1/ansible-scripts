# ansible-scripts

This repository contains Ansible scripts and supporting shell scripts for setting up and managing development environments in Docker containers.

## Common Container Features

All development containers in this repository share these common features:

- **Workspace Mounting**: Your project directories are mounted automatically
- **Persistent by Default**: Container state is preserved between sessions
- **VS Code Integration**: Remote development with VS Code
- **Container Commands**:
  - `detach`: Disconnect from the container while keeping it running
  - `stop`: Completely stop the container

These features are implemented through a shared script (`run-container-common.sh`) that is used by the environment-specific container scripts. This modular approach reduces code duplication and ensures consistent behavior across different development environments.

For detailed information on connecting to containers using VS Code, see [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md).

### Benefits of VS Code Remote Development:

- **Full IDE Experience**: Use all VS Code features inside the container
- **Extensions**: Install and use VS Code extensions directly in the container
- **Debugging**: Debug your applications with full debugger support
- **Integrated Terminal**: Access the container's terminal directly from VS Code
- **File Editing**: Edit files in the container with full language support
- **Source Control**: Use Git and other SCM tools directly in the container

By default, all containers are set up to be discoverable by VS Code's Remote - Containers extension.

## ROS2 Development Environment

The `run-ros2-container.sh` script allows you to create and manage a ROS2 Docker container with X11 forwarding, GPU support, and other useful features.

### ROS2-Specific Features:

- **X11 Forwarding**: Run GUI applications from inside the container
- **GPU Support**: Optional NVIDIA GPU passthrough
- **Automatic ROS2 Sourcing**: Environment automatically configured

### ROS2 Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./run-ros2-container.sh

# Run with a specific ROS2 distribution
./run-ros2-container.sh --distro iron

# Create a container with GPU support and custom name
./run-ros2-container.sh --gpu --name my_ros2_dev
```

For detailed usage and all available options, run:
```bash
./run-ros2-container.sh --help
```

### ROS2 Environment Setup

All ROS2 containers automatically have the ROS2 environment sourced in:
- Login shells (VS Code terminals)
- Interactive sessions

For non-interactive or non-login shells (such as `docker exec` commands), use the provided wrapper script:
```bash
~/bin/source_ros ros2 <command>
```

The container automatically sources the appropriate ROS2 setup file (`/opt/ros/<release>/setup.bash`) in:
- The user's `.bashrc` file
- Login shells
- Interactive shells

This ensures that ROS2 commands work without manual sourcing in most scenarios.

**Note**: If you encounter a password prompt when running the container, you can safely press Ctrl+C to cancel it. The container will still work correctly.

## Yocto Development Environment

The `run-yocto-container.sh` script allows you to create and manage a Yocto Project Docker container with all the necessary tools and configuration for embedded Linux development.

### Yocto-Specific Features:

- **Pre-configured Environment**: Container comes with all necessary Yocto build dependencies
- **Helper Functions**: Convenient functions for common Yocto operations

### Yocto Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./run-yocto-container.sh

# Run with a specific Yocto release
./run-yocto-container.sh --release kirkstone

# Create a container with a custom name
./run-yocto-container.sh --name my_yocto_dev
```

For detailed usage and all available options, run:
```bash
./run-yocto-container.sh --help
```

### Yocto Helper Functions

The Yocto container includes helper functions to simplify common tasks:

- `yocto_init`: Initializes the Yocto build environment (wrapper for `source poky/oe-init-build-env`)
- `yocto_build`: Builds a Yocto image (wrapper for `bitbake`)
- `yocto_clean`: Cleans a Yocto package build (wrapper for `bitbake -c cleansstate`)
- `yocto_status`: Displays current Yocto environment status

### Yocto Quick Start:

```bash
# Inside the container:
yocto_init
# Edit conf/local.conf if needed
yocto_build core-image-minimal
```