# ansible-scripts

This repository contains Ansible scripts and supporting shell scripts for setting up and managing development environments in Docker containers.

> **Quick Start Tip**: If a container already exists, you can directly use `./ros2-connect` or `./yocto-connect` 
> to connect to it. These scripts will start the container if needed and provide all container commands.

## Container Types

This repository provides scripts for two types of development containers:

1. **ROS2 Development Container**: A complete development environment for ROS2 with all necessary tools and libraries
2. **Yocto Development Container**: A build environment for Yocto Project development using CROPS/poky

## Container Scripts

### Standard Scripts
- `start-ros2-container.sh`: Standard ROS2 container runner
- `start-yocto-container.sh`: Standard Yocto container runner

### Robust Container Scripts
For more reliable container lifecycle management, especially when using detached commands or VS Code:
- `robust-ros2-container.sh`: Creates robust ROS2 containers with reliable keep-alive processes
- `robust-yocto-container.sh`: Creates robust Yocto containers with reliable keep-alive processes

The robust scripts are recommended for environments where you need maximum stability with VSCode remote development.

## Common Container Features

All development containers in this repository share these common features:

- **Workspace Mounting**: Your project directories are mounted at multiple paths for compatibility:
  - `/workspace`: The primary workspace path
  - `/projects`: For compatibility with VS Code extensions (important for Remote Development)
  - Container-specific paths like `/home/ubuntu/ros2_ws` or `/workdir`
- **Persistent by Default**: Container state is preserved between sessions
- **VS Code Integration**: Remote development with VS Code
- **Configuration Persistence**: Save and reuse container configurations
- **Container Commands**:
  - `detach`: Disconnect from the container while keeping it running
  - `stop`: Completely stop the container
  - `remove`: Stop and remove the container completely
  - `help`: Show all available container commands
  - Legacy aliases: `stop_container`, `container_help`, and `container-help`
  - `remove`: Stop and remove the container
  - `help`: Show all available commands

These features are implemented through a shared script (`run-container-common.sh`) that is used by the environment-specific container scripts. This modular approach reduces code duplication and ensures consistent behavior across different development environments.

## Container Connection Methods

There are two ways to connect to containers:

1. **When starting a container**:
   ```bash
   # Start a container and automatically connect to it
   ./start-ros2-container.sh --attach
   ./start-yocto-container.sh --attach
   ```

2. **Connecting to an already running container**:
   ```bash
   # Connect to a running container
   ./ros2-connect           # Connect to the default ROS2 container
   ./yocto-connect          # Connect to the default Yocto container
   
   # Connect to a custom named container
   ./ros2-connect my_ros2_container
   ./yocto-connect my_yocto_container
   ```

> **Important**: You can use EITHER method to interact with containers. For example, you can:
> - Start a container with `./start-ros2-container.sh` (without `--attach`), then connect to it later with `./ros2-connect`
> - OR directly use `./ros2-connect` if the container already exists (it will start the container if needed)
>
> Always use these connection methods instead of direct Docker commands (like `docker exec`) to ensure all container commands (`help`, `stop`, `remove`, etc.) are available in your session.

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

The `start-ros2-container.sh` script allows you to create and manage a ROS2 Docker container with X11 forwarding, GPU support, and other useful features.

### ROS2-Specific Features:

- **X11 Forwarding**: Run GUI applications from inside the container
- **GPU Support**: Optional NVIDIA GPU passthrough
- **Automatic ROS2 Sourcing**: Environment automatically configured

### ROS2 Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./start-ros2-container.sh

# Run with a specific ROS2 distribution
./start-ros2-container.sh --distro iron

# Create a container with GPU support and custom name
./start-ros2-container.sh --gpu --name my_ros2_dev

# Stop a running container
./start-ros2-container.sh --stop

# Stop and remove a container
./start-ros2-container.sh --remove
```

For detailed usage and all available options, run:
```bash
./start-ros2-container.sh --help
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

The `start-yocto-container.sh` script allows you to create and manage a Yocto Project Docker container with all the necessary tools for embedded Linux development.

### Yocto-Specific Features:

- **Build Environment**: Container provides all necessary tools to build Yocto Project
- **CROPS/poky Base**: Uses the CROPS/poky container which provides a consistent build environment
- **Ubuntu 22.04 Base**: Based on Ubuntu 22.04 for long-term stability

### About CROPS/poky Container

The CROPS (Cross Platform Open Source) poky container is a **build environment** that contains the necessary tools to build Yocto Project, but does **not** include the actual Poky source code. When you run the container, you will need to:

1. Clone the Poky repository for your desired Yocto release (e.g., Scarthgap or Kirkstone)
2. Initialize the build environment
3. Build your Yocto images

The container tags are based on the host Linux distribution (e.g., `ubuntu-22.04`, `fedora-40`).

### Yocto Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./start-yocto-container.sh

# Create a container with a custom name
./start-yocto-container.sh --name my_yocto_dev

# Create a container with a custom workspace directory
./start-yocto-container.sh --workspace ~/my_yocto_workspace

# Stop a running container
./start-yocto-container.sh --stop

# Stop and remove a container
./start-yocto-container.sh --remove
```

For detailed usage and all available options, run:
```bash
./start-yocto-container.sh --help
```

### Yocto Quick Start:

```bash
# Inside the container:
# Clone the Poky repo for your desired release (e.g., scarthgap)
git clone -b scarthgap git://git.yoctoproject.org/poky
cd poky
# Initialize build environment
source oe-init-build-env
# Edit conf/local.conf if needed
bitbake core-image-minimal
```

### Yocto Release Information

The following Yocto Project LTS releases are recommended for development:

| Release Name | Version | Support Status         | End of Life  |
|--------------|---------|------------------------|--------------|
| Scarthgap    | 5.0     | LTS                    | April 2029   |
| Kirkstone    | 4.0     | LTS                    | April 2026   |

Note that the CROPS/poky container (e.g., `crops/poky:ubuntu-22.04`) only contains the build tools for Yocto, not Yocto itself. You'll need to clone the appropriate branch of Poky inside the container:

```bash
# Inside the container, clone the specific branch you want to work with:
git clone -b scarthgap git://git.yoctoproject.org/poky
# OR
git clone -b kirkstone git://git.yoctoproject.org/poky
```

## Configuration Persistence

The scripts now support saving and reusing container configurations. This feature allows you to define your preferred settings once and reuse them in future sessions.

### Saving Configurations

To save your current container configuration:

```bash
# Save ROS2 container configuration
./start-ros2-container.sh --name my_ros2_dev --workspace ~/my_ros2_projects --gpu --save-config

# Save Yocto container configuration
./start-yocto-container.sh --name my_yocto_dev --workspace ~/my_yocto_projects --save-config
```

### Reusing Configurations

Once saved, you can reuse your configuration by simply specifying the container name:

```bash
# Use saved ROS2 configuration
./start-ros2-container.sh --name my_ros2_dev

# Use saved Yocto configuration
./start-yocto-container.sh --name my_yocto_dev
```

### Listing Saved Configurations

To view all saved configurations:

```bash
./start-ros2-container.sh --list-configs
# or
./start-yocto-container.sh --list-configs
```

### Reproducing Containers with Original Arguments

When listing configurations with `--list-configs`, you'll see the original command-line arguments that were used to create each container. This allows you to easily reproduce a container setup exactly as it was originally configured:

```bash
$ ./start-ros2-container.sh --list-configs
Saved container configurations:
  - test_container (ros2 jazzy) - Last used: 2025-06-06 15:31:46
    Original command: ros2-container.sh --name test_container --distro jazzy --gpu
```

You can copy the original command and run it again to create a container with identical settings.

### Configuration Storage

Configurations are stored in `~/.config/iac-scripts/` and are organized by container name. Each configuration stores:

- Environment type (ROS2, Yocto)
- Environment version (for ROS2 distros)
- Workspace directory
- GPU support setting
- Custom command
- Persistence setting
- User mode (root or non-root)
- Detach mode
- Auto-attach setting
- Image name
- Additional arguments
- Original command-line arguments used to create the container

The original command-line arguments are particularly useful if you want to recreate a container with exactly the same options.

### Managing Configurations

The scripts provide several options for managing saved configurations:

```bash
# List all saved configurations
./start-ros2-container.sh --list-configs

# Show detailed configuration for a specific container
./start-ros2-container.sh --show-config my_ros2_dev

# Show configurations for all running containers
./start-ros2-container.sh --show-running

# Remove a specific configuration
./start-ros2-container.sh --remove-config old_container

# Clean up configurations not used in the last 30 days
./start-ros2-container.sh --cleanup-configs

# Clean up configurations not used in the last 60 days
./start-ros2-container.sh --cleanup-configs 60
```

## Using Robust Container Scripts

For development environments that require maximum stability, especially when working with VSCode Remote Development or using detached commands, the robust container scripts provide enhanced reliability.

### Creating Robust ROS2 Containers

```bash
# Create a robust ROS2 container with default settings
./robust-ros2-container.sh

# Create a container with custom name and workspace
./robust-ros2-container.sh --name my_ros2_dev --workspace /path/to/workspace

# Create a container with specific ROS2 distribution
./robust-ros2-container.sh --name humble_dev --distro humble

# Fix an existing container that might have issues
./robust-ros2-container.sh --name my_ros2_dev --fix
```

### Creating Robust Yocto Containers

```bash
# Create a robust Yocto container with default settings
./robust-yocto-container.sh

# Create a container with custom name and workspace
./robust-yocto-container.sh --name my_yocto_dev --workspace /path/to/workspace

# Create a container with specific base image version
./robust-yocto-container.sh --name my_yocto_dev --base debian-11

# Fix an existing container that might have issues
./robust-yocto-container.sh --name my_yocto_dev --fix

# Run a detached command in the container
./robust-yocto-container.sh --name my_yocto_dev --command "git clone -b kirkstone git://git.yoctoproject.org/poky"
```

### Benefits of Robust Containers

The robust container scripts provide these key advantages:

1. **Resilient Keep-Alive Process**: Multiple keep-alive mechanisms ensure containers don't unexpectedly stop
2. **Simplified Creation**: One-step creation of properly configured containers
3. **Consistency**: Same behavior and interface for both ROS2 and Yocto containers
4. **Easily Fixable**: Simple commands to fix containers that have become unstable
5. **Self-Healing**: Automatically fix keep-alive processes before running detached commands
6. **VS Code Friendly**: Optimized for use with VS Code Remote Development

If you encounter issues with containers stopping unexpectedly when using VS Code Remote Development or running detached commands, the robust container scripts are the recommended solution.

## Additional Documentation

* [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md) - Instructions for accessing containers from Visual Studio Code
* [CONTAINER_COMMANDS.md](CONTAINER_COMMANDS.md) - Comprehensive guide to container commands, detached operation, and troubleshooting