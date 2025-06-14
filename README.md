# ansible-scripts

This repository contains Ansible scripts and supporting shell scripts for setting up and managing development environments in Docker containers.

> **Quick Start Tips**: 
> - If a container already exists, you can directly use `./ros2-connect` or `./yocto-connect` to connect to it
> - These scripts will start the container if needed and provide all container commands
> - To verify a container's setup is correct, use `./start-yocto-container-docker.sh --verify` or `./start-ros2-container.sh --verify`

## Container Types

This repository provides scripts for two types of development containers:

1. **ROS2 Development Container**: A complete development environment for ROS2 with all necessary tools and libraries
2. **Yocto Development Container**: A build environment for Yocto Project development using CROPS/poky

## Container Scripts

### Standard Scripts
- `start-ros2-container.sh`: Standard ROS2 container runner
- `start-yocto-container-docker.sh`: Standard Yocto container runner (Docker)
- `start-yocto-container-podman.sh`: Yocto container runner using Podman (may work better on Ubuntu 24.04+)

### Podman Scripts (Rootless Container Alternative)

This repository now includes a complete set of Podman-based scripts that provide the same functionality as the Docker scripts but run rootless (no daemon required):

#### Installation Scripts
- `podman-install.yml`: Install and configure Podman (rootless by default)
- `setup-podman-user.yml`: Configure Podman for the current user
- `yocto-in-podman-install.yml`: Complete Yocto development environment setup with Podman
- `ros2-in-podman-install.yml`: Complete ROS2 development environment setup with Podman

#### Container Management Scripts
- `start-yocto-container-podman.sh`: Create and manage Yocto containers with Podman
- `restart-yocto-container-podman.sh`: Restart Yocto Podman containers
- `restart-ros2-container-podman.sh`: Restart ROS2 Podman containers

#### Connection Scripts
- `yocto-podman-connect`: Connect to Yocto Podman containers
- `ros2-podman-connect`: Connect to ROS2 Podman containers
- `podman-exec-it`: Interactive Podman exec wrapper with container commands
- `podman-exec-detached`: Detached Podman exec wrapper

#### Container Command Installation
- `ensure-yocto-container-commands-podman.sh`: Install container commands in Podman containers
- `container-command-common.sh`: Now includes `install_container_commands_podman()` function

#### Key Differences from Docker
- **No root required**: Podman runs completely rootless
- **No daemon**: Containers run directly as user processes
- **Better security**: Rootless containers provide better isolation
- **Systemd integration**: Can run containers as systemd user services
- **Same commands**: Most Docker commands work with Podman (`podman run`, `podman ps`, etc.)

#### Quick Start with Podman
```bash
# Install Podman
ansible-playbook podman-install.yml

# Set up Yocto development environment
ansible-playbook yocto-in-podman-install.yml

# Connect to Yocto container
./yocto-podman-connect yocto-workspace-container

# Or set up ROS2 development environment
ansible-playbook ros2-in-podman-install.yml

# Connect to ROS2 container
./ros2-podman-connect ros2-workspace-container
```

### Container Management Options
- `--attach`: Connect to the container after starting it
- `--stop`: Stop a running container
- `--remove`: Remove a container (stops it first if running)
- `--verify`: Verify container commands and workspace paths are correctly configured

### Robust Container Scripts
For more reliable container lifecycle management, especially when using detached commands or VS Code:
- `start-ros2-container.sh`: Creates and manages ROS2 containers with reliable keep-alive processes
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
  - `container-detach`: Disconnect from the container while keeping it running
  - `container-stop`: Completely stop the container
  - `container-remove`: Stop and remove the container completely
  - `container-help`: Show all available container commands

These commands are available in all containers, regardless of how you connect to them. For troubleshooting command availability, use the `--verify` option with the container start scripts.

These features are implemented through a shared script (`run-container-common.sh`) that is used by the environment-specific container scripts. This modular approach reduces code duplication and ensures consistent behavior across different development environments.

## Helper Scripts

- `container-command-common.sh`: Shared library of functions for container command installation and management
- `add-commands-to-container.sh`: Adds standardized container commands to any Docker container using the shared library
- `ensure-yocto-container-commands.sh`: Specialized script for ensuring container commands are properly installed in Yocto containers (uses the same shared library)
- `container-watch.sh`: Background process that monitors containers and handles detach/stop/remove requests
- `verify-container.sh`: Quick verification tool to check if a container's commands and workspace paths are properly configured

> **Note on Command Installation**: Both command installation scripts now use a shared library (`container-command-common.sh`) with consistent behavior. Use `add-commands-to-container.sh` for most containers and `ensure-yocto-container-commands.sh` for specialized Yocto container setups requiring extra reliability.

## Container Connection Methods

There are two ways to connect to containers:

1. **When starting a container**:
   ```bash
   # Start a container and automatically connect to it
   ./start-ros2-container.sh --attach
   ./start-yocto-container-docker.sh --attach
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
> Always use these connection methods instead of direct Docker commands (like `docker exec`) to ensure all container commands (`container-help`, `container-stop`, `container-remove`, etc.) are available in your session.

For detailed information on connecting to containers using VS Code, see [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md).

### Benefits of VS Code Remote Development:

- **Full IDE Experience**: Use all VS Code features inside the container
- **Extensions**: Install and use VS Code extensions directly in the container
- **Debugging**: Debug your applications with full debugger support
- **Integrated Terminal**: Access the container's terminal directly from VS Code
- **File Editing**: Edit files in the container with full language support
- **Source Control**: Use Git and other SCM tools directly in the container

By default, all containers are set up to be discoverable by VS Code's Remote - Containers extension.

## Command Completions

Tab completion for container commands is automatically enabled when you use the container scripts. The completion functionality is built into the main scripts and provides:

- Container name completion for all container management commands
- Command option completion (--name, --workspace, --distro, etc.)
- Keyboard shortcuts inside containers (Ctrl+X+d to detach, Ctrl+\ for quick detach)

No additional setup is required - tab completion works automatically when you run the container scripts.

For more details, see the [Container Commands documentation](CONTAINER_COMMANDS.md).

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

The `start-yocto-container-docker.sh` script allows you to create and manage a Yocto Project Docker container with all the necessary tools for embedded Linux development.

### Yocto-Specific Features:

- **Build Environment**: Container provides all necessary tools to build Yocto Project
- **CROPS/poky Base**: Uses the CROPS/poky container which provides a consistent build environment
- **Workspace Mounting**: Your projects directory is mounted automatically
- **Clean Workspace**: Container system files are kept in /tmp to avoid workspace pollution
- **Cache Sharing**: Optional caching of downloads and sstate for faster builds
- **Layer Management**: Tools for working with Yocto layers

For Yocto/CROPS-specific container commands, see the [Special Considerations for CROPS/Poky Containers](CONTAINER_COMMANDS.md#special-considerations-for-cropspoky-containers) section in the container commands documentation.

### Basic Usage:

```bash
# Basic usage (runs bash shell in the container)
./start-yocto-container-docker.sh

# Create a container with a custom name
./start-yocto-container-docker.sh --name my_yocto_dev

# Create a container with a custom workspace directory
./start-yocto-container-docker.sh --workspace ~/my_yocto_workspace

# Stop a running container
./start-yocto-container-docker.sh --stop

# Stop and remove a container
./start-yocto-container-docker.sh --remove
```

For detailed usage and all available options, run:
```bash
./start-yocto-container-docker.sh --help
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
./start-yocto-container-docker.sh --name my_yocto_dev --workspace ~/my_yocto_projects --save-config
```

### Reusing Configurations

Once saved, you can reuse your configuration by simply specifying the container name:

```bash
# Use saved ROS2 configuration
./start-ros2-container.sh --name my_ros2_dev

# Use saved Yocto configuration
./start-yocto-container-docker.sh --name my_yocto_dev
```

### Listing Saved Configurations

To view all saved configurations:

```bash
./start-ros2-container.sh --list-configs
# or
./start-yocto-container-docker.sh --list-configs
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
./start-ros2-container.sh

# Create a container with custom name and workspace
./start-ros2-container.sh --name my_ros2_dev --workspace /path/to/workspace

# Create a container with specific ROS2 distribution
./start-ros2-container.sh --name humble_dev --distro humble

# Fix an existing container that might have issues
./start-ros2-container.sh --name my_ros2_dev --fix
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

## Troubleshooting and Maintenance

### Container Commands Not Available

If container commands like `container-detach` are not available in your container session:

1. Verify the container's configuration:
   ```bash
   ./verify-container.sh CONTAINER_NAME
   ```

2. Reinstall the commands:
   ```bash
   ./add-commands-to-container.sh CONTAINER_NAME
   ```

### Workspace Path Issues

If you encounter issues with workspace paths (especially in Yocto containers):

1. Verify the container's configuration:
   ```bash
   ./verify-container.sh CONTAINER_NAME
   ```

2. Restart the container with the correct configuration:
   ```bash
   docker stop CONTAINER_NAME
   ./start-yocto-container-docker.sh --name CONTAINER_NAME
   ```

### Container Verification

To verify container configurations, use the built-in verification commands:

```bash
# Verify specific containers
./start-ros2-container.sh --verify [CONTAINER_NAME]
./start-yocto-container-docker.sh --verify [CONTAINER_NAME]

# Or use the dedicated verification tool
./verify-container.sh [CONTAINER_NAME]
```

For more detailed information about container commands, configuration, and troubleshooting, see [CONTAINER_COMMANDS.md](CONTAINER_COMMANDS.md).

## Additional Documentation

* [VSCODE_CONTAINER_ACCESS.md](VSCODE_CONTAINER_ACCESS.md) - Instructions for accessing containers from Visual Studio Code
* [CONTAINER_COMMANDS.md](CONTAINER_COMMANDS.md) - Comprehensive guide to container commands, detached operation, troubleshooting, and CROPS/Poky containers
* [CONTAINER_INSTALLATION.md](CONTAINER_INSTALLATION.md) - Detailed documentation of the container command installation system