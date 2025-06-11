# Container Commands and Management

This document provides a comprehensive guide to working with our development containers, including all available commands, troubleshooting techniques, and verification procedures.

## Standard Container Commands

These commands are available in all containers:

| Command | Description |
|---------|-------------|
| `container-detach` | Detach from the container (container keeps running in the background) |
| `container-stop` | Stop the container (container will be stopped but not removed) |
| `container-remove` | Stop and remove the container completely |
| `container-help` | Show all available container commands |

### Keyboard Shortcuts

The system provides keyboard shortcuts for quickly detaching from containers:

- `Ctrl+X` followed by `d`: Execute the container-detach command
- `Ctrl+\`: Alternative shortcut to execute the container-detach command
- `Ctrl+X` followed by `q`: Direct detach (bypasses container-detach command)
- `Ctrl+D`: Exit the shell (which also detaches if you're in a container session)

These shortcuts are enabled when the container-commands-completion.sh script is sourced. If keyboard shortcuts don't work, you can always manually run the `container-detach` command.

> **Note:** For detaching to work properly, the container watcher script must be monitoring for the marker files in all possible locations: $HOME/.container_detach_requested, /workdir/.container_detach_requested, and /tmp/.container_detach_requested.

## How Container Commands Work

When you run any of these commands, the container creates a marker file that is detected by the container watcher script:

1. For `container-detach`:
   - Creates a marker file in one of these locations (in order of preference):
     - `$HOME/.container_detach_requested`
     - `/workdir/.container_detach_requested`
     - `/tmp/.container_detach_requested`

2. For `container-stop`:
   - Creates a marker file in one of these locations (in order of preference):
     - `$HOME/.container_stop_requested`
     - `/workdir/.container_stop_requested`
     - `/tmp/.container_stop_requested`

3. For `container-remove`:
   - Creates a marker file in one of these locations (in order of preference):
     - `$HOME/.container_remove_requested`
     - `/workdir/.container_remove_requested`
     - `/tmp/.container_remove_requested`

The container watcher script (`container-watch.sh`) monitors for these marker files and takes the appropriate action.

## Examples

```bash
# Detach from the container while keeping it running
container-detach

# Stop the container
container-stop

# Stop and remove the container
container-remove

# Show help about available commands
container-help
```

## Container Management Options

The `start-ros2-container.sh` and `start-yocto-container.sh` scripts provide direct options for container management:

```bash
# Stop a container
./start-ros2-container.sh --stop [CONTAINER_NAME]
./start-yocto-container.sh --stop [CONTAINER_NAME]

# Remove a container (stops it first if running)
./start-ros2-container.sh --remove [CONTAINER_NAME]
./start-yocto-container.sh --remove [CONTAINER_NAME]

# Verify container setup
./start-ros2-container.sh --verify [CONTAINER_NAME]
./start-yocto-container.sh --verify [CONTAINER_NAME]
```

If no container name is provided, these commands operate on the default container (`ros2_container` or `yocto_container`).

## Connecting to Containers

There are two recommended ways to connect to containers:

1. **Starting a container with the `--attach` option**:
   ```bash
   ./start-ros2-container.sh --attach
   ./start-yocto-container.sh --attach
   ```
   This will start the container and automatically connect to it using the appropriate connect script.

2. **Connecting to an already running container**:
   ```bash
   # Connect to default containers
   ./ros2-connect
   ./yocto-connect
   
   # Connect to custom named containers
   ./ros2-connect my_custom_ros2_container
   ./yocto-connect my_custom_yocto_container
   ```

> **Key Points**: 
>
> - You can use the `X-connect` scripts DIRECTLY instead of the `start-X-container.sh` scripts.
> - The `X-connect` scripts will start an existing container if it's stopped.
> - Both methods ensure that all container commands (`help`, `stop`, `remove`, etc.) are available.
> - If a container already exists, using `./ros2-connect` or `./yocto-connect` is often the quickest way to access it.

## Command Availability

Container commands (`detach`, `stop`, `remove`, `help`, etc.) are available regardless of how you connect to the container:

- Using `./ros2-connect` or `./yocto-connect` scripts
- Using `./start-ros2-container.sh --attach` or `./start-yocto-container.sh --attach`
- Using VS Code's "Attach to Container" feature
- Using direct `docker exec -it container_name bash` commands

These commands are set up in the container's system-wide bashrc during container creation, so they will be available in all interactive shells regardless of how you connect to the container.

> **Note**: If you're using an older container that was created before this update, you might need to recreate it to have these commands available in all connection methods.

## Container Workspace Paths

### Standard Workspace Structure

All containers mount the host workspace directory to specific locations inside the container:

| Container Type | Host Directory | Container Paths |
|---------------|----------------|-----------------|
| ROS2 | `$HOME/projects` | `/projects`, `/workspace`, `/workdir` |
| Yocto/CROPS | `$HOME/projects` | `/projects`, `/workspace`, `/workdir` |
| Generic | `$HOME/projects` | `/projects`, `/workspace`, `/workdir` |

Inside the container, symbolic links ensure compatibility across different path references:
- `/workspace` → `/projects` 
- `/workdir` → `/projects`

This consistent structure ensures that scripts and tools can work across different container types using the same paths.

### Yocto Workspace Configuration

By default, the Yocto container mounts the host's `$HOME/projects` directory to `/projects` inside the container. The container entrypoint script sets up the proper symlinks to ensure compatibility.

## Container Verification

To verify that container commands and workspace paths are properly configured, you can use the integrated verification feature:

```bash
./start-yocto-container.sh --verify [CONTAINER_NAME]
# or
./start-ros2-container.sh --verify [CONTAINER_NAME]
```

This verification will check:

1. **Workspace Path Configuration**:
   - Confirms that `/projects`, `/workdir`, and `/workspace` directories exist
   - Verifies the workspace is correctly mounted at `/projects`
   - Checks that symlinks are properly set up (`/workdir` → `/projects` and `/workspace` → `/projects`)
   - Lists workspace content to confirm it's accessible

2. **Container Commands Installation**:
   - Verifies container commands (`container-help`, `container-detach`, etc.) are in the PATH
   - Checks command directories (`/tmp/container-commands`, `/tmp/.container_commands`)
   - Tests commands to ensure they're working properly
   - Shows the PATH environment variable to help diagnose PATH-related issues

If issues are found, the verification will provide recommendations for fixing them.

You can also use the simpler verification script:

```bash
./verify-container.sh [CONTAINER_NAME]
```

If no container name is provided, you'll be prompted to select from running containers or verify all of them.

## Working with Detached Commands

When working with containers, sometimes you need to run commands in detached mode (in the background). 
This is especially useful for long-running processes that you don't want to block your terminal.

### The Issue with Detached Commands

In some Docker container setups, when a detached command is issued (using `docker exec -d`), the container
might stop after the command completes if the command was the last active process in the container. This
happens because Docker containers are designed to exit when their main process exits.

Our container scripts have been enhanced to prevent this issue, but if you're still experiencing problems,
you can use the provided helper scripts and techniques below.

### Solution: Using docker-exec-detached

We've provided a special script that ensures the container stays running even when running detached commands:

```bash
./docker-exec-detached <container_name> "<command>"
```

Examples:

```bash
# Run a ROS2 process in the background
./docker-exec-detached ros2_container "ros2 launch my_package my_launch.py"

# Run a Yocto build in the background
./docker-exec-detached yocto_container "cd build && bitbake core-image-minimal"
```

This script:
1. Uses the shared container utilities library
2. Ensures the keep-alive process is running before starting your command
3. Runs your command in detached mode
4. Creates the proper marker files so the container watcher knows the container should stay running

### Using Robust Container Scripts

The robust container scripts also provide built-in support for running detached commands:

```bash
# For Yocto containers
./robust-yocto-container.sh --name my_yocto_dev --command "cd build && bitbake core-image-minimal"
```

This approach is recommended for the most reliable detached command execution.

### Additional Keep-Alive Mechanisms

The containers include multiple keep-alive mechanisms to ensure they stay running:

1. A background sleep process that runs indefinitely
2. A more resilient keep-alive script that is designed to be difficult to terminate accidentally
3. A container watcher script that monitors the container and restarts it if needed

### Manually Ensuring Container Stays Running

If you're still having issues, you can manually ensure the container stays running by:

1. Creating a detach marker file before running your detached command:
   ```bash
   docker exec <container_name> touch /home/ubuntu/.container_detach_requested
   ```

2. Running your command in detached mode:
   ```bash
   docker exec -d <container_name> <command>
   ```

3. Verifying the container is still running:
   ```bash
   docker ps | grep <container_name>
   ```

### Debugging Container Lifecycle Issues

If you're experiencing container lifecycle issues, you can check:

1. If the keep-alive process is running inside the container:
   ```bash
   docker exec <container_name> ps aux | grep keep_container_alive
   ```

2. The container watcher logs:
   ```bash
   docker logs <container_name> | grep "container watch"
   ```

3. Enable debug mode in the keep-alive script by setting `DEBUG=1` at the top of the script:
   ```bash
   docker exec <container_name> sed -i 's/DEBUG=0/DEBUG=1/' /home/ubuntu/keep_container_alive.sh
   ```

## VS Code Container Integration

### VS Code Container Integration Issues

When using Visual Studio Code with containers, you might encounter issues when trying to reattach to a container that has exited unexpectedly, especially after running detached commands.

### Why VS Code Can't Reattach to Exited Containers

1. **VS Code Remote Container Extension Behavior**: 
   - The VS Code Remote Container extension expects containers to be in a consistent state
   - It may not properly handle containers that have exited unexpectedly
   - It relies on specific container metadata that might be lost when a container exits abnormally

2. **Missing Keep-Alive Process**:
   - If the container's keep-alive process was terminated, VS Code can't reattach even if you restart the container
   - The container might restart but immediately exit again if the keep-alive process isn't running

3. **Docker Socket Connection**:
   - VS Code connects to containers through the Docker socket
   - If the container's state is inconsistent, this connection might fail

### Solution: Using restart-vscode-container.sh

We've provided a special script to help VS Code reattach to containers:

```bash
./restart-vscode-container.sh <container_name>
```

This script:
1. Checks if the container exists and its current state
2. Restarts the container if it's stopped
3. Ensures the keep-alive process is running
4. Creates the proper marker files
5. Starts the container watcher

After running this script, you should be able to attach to the container from VS Code:
1. Click on the Remote Explorer icon in the sidebar
2. Find the container under 'Containers'
3. Right-click on the container and select 'Attach to Container'

### Additional VS Code Tips

If you're still having issues with VS Code and containers:

1. **Restart VS Code**: Sometimes simply restarting VS Code can resolve connection issues
2. **Reload Window**: Use Command Palette (Ctrl+Shift+P) and run "Developer: Reload Window"
3. **Check Docker Extension**: Make sure the Docker extension is up to date
4. **Check Remote Containers Extension**: Ensure the Remote Containers extension is up to date
5. **Recreate the Container**: As a last resort, you might need to recreate the container using the original run script

```bash
./start-ros2-container.sh --name <container_name> --clean
```

## Container Repair and Recovery

### Easy Container Recreation

We've provided a special script to easily recreate a ROS2 container from scratch:

```bash
./recreate-ros2-container.sh [--name container_name]
```

This script:
1. Stops and removes the existing container if it exists
2. Looks for saved configuration in `~/.config/iac-scripts/`
3. Recreates the container with the original settings if available
4. Falls back to default settings if no saved configuration is found

This is the easiest way to recover from container issues when other methods fail.

### Complete Container Fix Script

If you're experiencing persistent issues with ROS2 containers, we've created a comprehensive fix script that addresses common problems:

```bash
./fix-ros2-container.sh [--name container_name]
```

This script will:
1. Check if the container exists and create it if needed
2. Fix workspace directory issues (creating missing directories and fixing permissions)
3. Ensure all keep-alive processes are running properly
4. Start the container watcher
5. Fall back to complete recreation if other fixes fail

This is the most thorough way to fix container issues and should resolve most problems you might encounter with ROS2 containers, including:
- Containers that exit immediately after starting
- Workspace directory not found errors
- Missing keep-alive processes
- Permission issues with mounted directories

Run this script whenever you have container startup or stability problems.

### Container Mount Conflict Issue

In some cases, when trying to restart a container, you might encounter an error related to mount conflicts:

```
Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: 
runc create failed: unable to start container process: error during container init: error mounting "...entrypoint.sh" to rootfs...
```

This happens because:

1. The container was started with a volume mount that maps a host script to the container's entrypoint
2. When trying to restart, Docker can't recreate the exact same mount conditions
3. This creates a conflict where Docker tries to mount a file over another file

When you encounter this error:

1. **Remove and recreate the container**: The `restart-vscode-container.sh` script will attempt to do this automatically
   ```bash
   ./restart-vscode-container.sh <container_name>
   ```

2. **Manually recreate the container**: If automatic recreation fails, you'll need to manually recreate it
   ```bash
   ./start-ros2-container.sh --name <container_name> --clean
   ```

3. **Use saved configuration**: If you previously saved the configuration with `--save-config`, the script will try to use those settings

### Direct Container Creation

If you're still experiencing issues with the container exiting unexpectedly, we've created a standalone script that uses a more direct approach to create a robust ROS2 container:

```bash
./create-robust-ros2-container.sh [OPTIONS]
```

Options:
- `--name NAME`: Set a custom container name (default: ros2_container)
- `--workspace DIR`: Set a custom workspace directory (default: $HOME/projects)

This script:
1. Completely bypasses the entrypoint script mechanism that can sometimes cause issues
2. Uses a direct keep-alive mechanism with `sleep infinity` as the main process
3. Creates all necessary directories and permissions
4. Ensures ROS2 is properly sourced

This is the most reliable way to create a container that will stay running and be accessible from VS Code, especially useful if you're experiencing persistent issues with the other scripts.

## Bash Completion for Container Commands

To enhance usability, we provide a bash completion script for container commands. This allows you to use the `Tab` key to auto-complete container names and commands.

### Installation

Source the completion script in your `.bashrc` or run it before using container commands:

```bash
source ./container-commands-completion.sh
```

To make the completion permanent, add it to your `.bashrc`:

```bash
echo "source $(pwd)/container-commands-completion.sh" >> ~/.bashrc
```

### Supported Commands

The bash completion supports:

- Container management scripts (`add-commands-to-container.sh`)
- Docker exec wrappers (`docker-exec-it`, `docker-exec-detached`)
- Container connection scripts (`ros2-connect`, `yocto-connect`)
- Container maintenance scripts (`restart-ros2-container.sh`, `fix-container-volumes.sh`, etc.)
- In-container commands (`container-detach`, `container-stop`, etc.)

### Usage Examples

1. Auto-completing container names:
   ```
   ./add-commands-to-container.sh [TAB][TAB]
   ```
   This will show a list of all running containers.

2. Auto-completing docker-exec commands:
   ```
   ./docker-exec-it ros2_container [TAB][TAB]
   ```
   This will show available commands: `help`, `detach`, `stop`, `bash`, `remove`.

3. Auto-completing options:
   ```
   ./restart-ros2-container.sh --[TAB][TAB]
   ```
   This will show available options: `--name`, `--help`.

The completion script automatically detects running containers, making it easier to manage multiple containers.

## Special Considerations for CROPS/Poky Containers

CROPS/Poky containers (used for Yocto development) have some unique characteristics that require special handling of container commands.

### CROPS/Poky Container Command Installation

The standard container commands (`container-detach`, `container-stop`, etc.) are installed in CROPS/Poky containers using a specialized installation process that accommodates their environment constraints.

#### Using the Unified Script

For all container types, including CROPS/Poky containers, we now provide a unified script:

```bash
./add-commands-to-container.sh CONTAINER_NAME [USER]
```

For example:
```bash
./add-commands-to-container.sh yocto_container
```

This script:
- Handles the unique environment of CROPS/Poky containers
- Works with restricted permissions common in these containers
- Uses appropriate installation locations (/workdir or /tmp)
- Creates necessary symlinks and aliases
- Configures PATH to include command locations

#### Implementation Details

The `add-commands-to-container.sh` script:

1. Creates temporary command scripts
2. Copies them to the container
3. Sets up the commands in appropriate directories based on what's writable
4. Creates necessary symlinks and aliases
5. Configures bashrc files to include the commands in PATH
6. Adds bash completion for easy command usage

#### How It Works

1. **Phase 1**: Creates directories and copies scripts
   - Determines the best command directory based on what's writable
   - Creates the directory if needed
   - Copies all command scripts to this location

2. **Phase 2**: Creates symlinks and aliases
   - Sets up `/tmp/bin` symlinks for broader access
   - Creates legacy aliases (e.g., `detach` -> `container-detach`)

3. **Phase 3**: Configures system for persistence
   - Adds to `/etc/profile.d` if possible
   - Updates all user bashrc files
   - Ensures commands are available in all new shell sessions

4. **Bash Completion**: 
   - Adds tab-completion for all container commands
   - Makes it easier to discover and use available commands

#### Installation Locations

Commands are installed in the following locations:

1. `/tmp/.container_commands/` (primary location to avoid workspace pollution)

Symlinks are also created in:
- `/usr/local/bin/` (if writable)
- `/tmp/bin/` (fallback location)

This installation approach ensures your workspace remains clean and free from system files.

### Troubleshooting CROPS/Poky Container Commands

If commands are not available after installation:

1. Check if the commands exist in the container:
   ```bash
   docker exec CONTAINER_NAME ls -la /tmp/container-commands/ /tmp/.container_commands/
   ```

2. Ensure the scripts are executable:
   ```bash
   docker exec CONTAINER_NAME chmod +x /tmp/container-commands/* /tmp/.container_commands/*
   ```

3. Manually add the commands to your PATH:
   ```bash
   docker exec -it CONTAINER_NAME bash -c 'export PATH=/tmp/container-commands:/tmp/.container_commands:$PATH; bash'
   ```

4. Use our verification script for immediate diagnosis:
   ```bash
   ./verify-container.sh CONTAINER_NAME
   ```

5. Source the commands setup script inside the container:
   ```bash
   docker exec -it CONTAINER_NAME bash -c 'source /tmp/container_commands_setup.sh && bash'
   ```

6. For permission issues, try running as root inside the container:
   ```bash
   docker exec -it --user root CONTAINER_NAME bash -c 'chmod 755 /tmp/container-commands/* /tmp/.container_commands/*'
   ```

### Specialized Yocto Command Installer

While `add-commands-to-container.sh` is the main script for adding commands to any container type, we also provide a specialized script specifically for Yocto containers:

```bash
./ensure-yocto-container-commands.sh [CONTAINER_NAME]
```

If no container name is provided, it defaults to `yocto_container`.

This script addresses Yocto-specific issues and ensures container commands are available under all circumstances:

1. **Multiple Installation Locations**:
   - Installs commands in `$HOME/bin`
   - Creates system-wide commands in `/usr/local/bin` if possible
   - Adds Yocto-specific locations in `/workdir/.container_commands`
   - Sets up fallback commands in `/tmp/.container_commands`

2. **Comprehensive PATH Configuration**:
   - Updates `/etc/profile.d/container-init.sh`
   - Modifies `/etc/bash.bashrc` for system-wide availability
   - Updates user's `.bashrc` file

3. **Welcome Script Creation**:
   - Creates a welcome script that shows available commands
   - Provides fallback instructions if commands aren't in PATH

Example usage:
```bash
# Install commands in the default Yocto container
./ensure-yocto-container-commands.sh

# Install commands in a custom Yocto container
./ensure-yocto-container-commands.sh my_yocto_container
```

Use this script when you're having issues with command availability specifically in Yocto containers, or when setting up a new Yocto container environment.

### Relationship Between Container Command Installation Scripts

This repository includes a harmonized system for container command installation:

1. **`container-command-common.sh`**: A shared library providing common functions for container command installation
2. **`add-commands-to-container.sh`**: General-purpose script using the shared library for all container types
3. **`ensure-yocto-container-commands.sh`**: Specialized script using the shared library with Yocto-specific optimizations

> **Note**: For a complete overview of how these scripts relate to the overall container management system, see the [Script Architecture and Relationships](#script-architecture-and-relationships) section and the [Future Integration Plan Implementation](#future-integration-plan-implementation) section below.

#### When to Use Each Script

- **Use `add-commands-to-container.sh` when**:
  - Working with any container type (ROS2, Yocto, or general-purpose)
  - You need a script that auto-detects container type
  - You want standard command installation that works in most cases

- **Use `ensure-yocto-container-commands.sh` when**:
  - Working specifically with Yocto/CROPS containers
  - Having trouble with container commands not being found in Yocto containers
  - You need maximum reliability with multiple fallback mechanisms

#### Technical Implementation

Both scripts now:
- Use a shared library of common functions (`container-command-common.sh`)
- Implement the same core functionality with consistent behavior
- Provide graceful fallbacks when permissions are restricted
- Support system-wide and user-specific installations

The Yocto-specific script maintains its additional optimizations for the CROPS/Poky container environment, including extra fallback locations and more comprehensive system-wide configuration.

### Yocto Workspace Path Configuration

By default, the Yocto container mounts the host's `$HOME/projects` directory to `/projects` inside the container. If you're experiencing issues where the workspace is incorrectly mounted at `/projects/yocto` instead of `/projects`, you can use the following solutions:

1. Verify the current workspace path:
   ```bash
   ./verify-container.sh yocto_container
   ```

2. Manually update the workspace path:
   ```bash
   docker exec -it --user root CONTAINER_NAME bash -c "ln -sf /projects /workdir && ln -sf /projects /workspace"
   ```

3. Restart the container with the correct configuration:
   ```bash
   docker stop CONTAINER_NAME
   ./start-yocto-container.sh --name CONTAINER_NAME
   ```

#### Notes on Workspace Paths

- The container should have `/projects` as the main workspace directory
- Symlinks should be set up as: `/workdir` → `/projects` and `/workspace` → `/projects`
- All container commands should work within this directory structure
- If you have existing work in `/projects/yocto`, you might need to move it to `/projects`

## Future Integration Plan

To further harmonize the container command installation scripts, a future update could:

1. **Create a unified command installation framework**:
   - Merge the best features of both scripts into a single codebase
   - Maintain separate entry points for backward compatibility
   - Use container type detection to automatically apply the appropriate installation strategy

2. **Implement a modular approach**:
   - Create a common core library of shared functions
   - Add specialized modules for different container types
   - Allow for easy extension to new container types

3. **Improve documentation and diagnostics**:
   - Add verbose logging options
   - Provide clear feedback on installation success/failure
   - Create troubleshooting guides for common issues

This integration would maintain backward compatibility while streamlining the codebase and making maintenance easier.

### Future Integration Plan Implementation

The container command installation scripts have been harmonized with a shared library approach:

1. **Unified command installation framework**:
   - Both scripts now use a shared library (`container-command-common.sh`)
   - Each maintains its separate entry point for backward compatibility
   - Container type detection automatically applies the appropriate installation strategy

2. **Modular approach implemented**:
   - Common core library with shared functions
   - Specialized handling for different container types
   - Extensible design for future container types

3. **Improved documentation and diagnostics**:
   - Clear guidance on which script to use
   - Fallback mechanisms for better reliability
   - Consistent behavior across scripts

This integration maintains backward compatibility while streamlining the codebase and making maintenance easier.

## Repository Maintenance

To help keep your container scripts repository clean and well-maintained, we provide a maintenance utility script:

```bash
./maintain-container-scripts.sh [OPTIONS]
```

Options:
- `--verify-only`: Only run verification checks, skip cleanup
- `--cleanup-only`: Only perform cleanup, skip verification

### What the Maintenance Script Does

This script performs two main functions:

1. **Verification of Container Configurations**:
   - Detects all running containers
   - Offers to verify their configuration 
   - Runs the appropriate verification for each container type
   - Provides status of container commands and workspace paths

2. **Cleanup of Temporary and Obsolete Files**:
   - Finds and removes backup files (`.bak`, `~`, `.old`, `.orig`)
   - Cleans up temporary fix scripts while preserving core scripts
   - Removes example scripts that are no longer needed
   - Deletes the deprecated_scripts directory if present

### Usage Examples

To perform both verification and cleanup:
```bash
./maintain-container-scripts.sh
```

To only verify containers without cleanup:
```bash
./maintain-container-scripts.sh --verify-only
```

To only clean up temporary files without verification:
```bash
./maintain-container-scripts.sh --cleanup-only
```

This script is particularly useful after you've been making fixes or updates to your container setup, as it helps ensure everything is configured correctly and removes any temporary files created during the process.

### Quick Verification Tool

For a simpler verification experience, you can also use:

```bash
./verify-container.sh [CONTAINER_NAME]
```

If no container name is provided, the script will:
1. List all running containers
2. Let you select which one to verify (or verify all)
3. Run the appropriate verification for the selected container type

This is a quick way to check a container's setup without the full maintenance process.

## Troubleshooting

### Command Troubleshooting

If container commands are not available, you can:

1. **Verify command installation**:
   ```bash
   ./verify-container.sh CONTAINER_NAME
   ```

2. **Manually source the setup script**:
   ```bash
   source /tmp/container-commands/container-init.sh
   # or
   source /tmp/.container_commands/container-init.sh
   ```

3. **Check command locations**:
   ```bash
   ls -la /tmp/container-commands/ /tmp/.container_commands/ /usr/local/bin/container-*
   ```

4. **Reinstall commands**:
   ```bash
   ./add-commands-to-container.sh CONTAINER_NAME
   ```

### Workspace Path Troubleshooting

If verification shows incorrect paths, you can fix them with:

1. **Restart the container with the correct configuration**:
   ```bash
   docker stop CONTAINER_NAME
   ./start-yocto-container.sh --name CONTAINER_NAME
   ```

2. **Manually update the symlinks inside the container**:
   ```bash
   docker exec -it --user root CONTAINER_NAME bash -c "ln -sf /projects /workdir && ln -sf /projects /workspace"
   ```

The updated container scripts now ensure proper workspace path configuration automatically.

### Maintenance and Cleanup

To clean up temporary files and verify container configurations, use the maintenance script:

```bash
./maintain-container-scripts.sh
```

This script will:
- Check for running containers and verify their configurations
- Find and remove backup files (.bak, ~, .old, .orig)
- Remove temporary fix scripts
- Clean up example and deprecated scripts

### Container Commands Availability

The command installation process has been enhanced to ensure commands are always available:

1. **Multiple Installation Locations**:
   - Primary: `/tmp/container-commands/`
   - Fallback: `/tmp/.container_commands/`
   - System-wide: `/usr/local/bin/` (when permissions allow)

2. **Robust PATH Configuration**:
   - Commands are added to the PATH through multiple methods:
     - `/etc/profile.d/container-init.sh` (system-wide)
     - `/etc/bash.bashrc` (global bashrc)
     - User-specific `.bashrc` files
     - Symlinks in standard PATH locations

3. **Marker File Detection**:
   - The container watcher script now checks all possible locations for marker files:
     - `$HOME/.container_detach_requested`
     - `/workdir/.container_detach_requested`
     - `/tmp/.container_detach_requested`

These enhancements ensure that container commands are reliably available in all environments, regardless of permissions or container configuration.

## Script Architecture and Relationships

The container management system in this repository is built with a modular architecture, with several scripts working together to provide a complete solution. Understanding these relationships is key to effective maintenance and extension.

### Core Script Relationships

The container management system consists of these main script categories:

1. **Container Runtime Scripts**: Create and manage Docker containers
2. **Command Installation Scripts**: Install commands inside containers
3. **Connection Scripts**: Provide ways to connect to running containers
4. **Utility Scripts**: Perform maintenance and verification tasks

### Key Scripts and Their Roles

#### Container Runtime Management

- **`run-container-common.sh`**: The core container runtime manager
  - Creates, starts, stops, and removes Docker containers
  - Handles container lifecycle management
  - Processes command-line arguments for container creation
  - Configures volumes, GPU support, networking, etc.
  - Called by environment-specific scripts (`start-ros2-container.sh`, `start-yocto-container.sh`)

#### Command Installation

- **`container-command-common.sh`**: Shared library for command installation
  - Provides utility functions for installing command scripts inside containers
  - Manages PATH setup and shell initialization
  - Creates container command scripts
  - Handles permission fallbacks
  - Used by command installer scripts, not called directly
  
- **`add-commands-to-container.sh`**: General command installer for all container types
  - Uses `container-command-common.sh` for core functionality
  - Works with any container type (ROS2, Yocto, generic)

- **`ensure-yocto-container-commands.sh`**: Specialized installer for Yocto containers
  - Uses `container-command-common.sh` for core functionality
  - Adds Yocto-specific optimizations

### Comparison: run-container-common.sh vs. container-command-common.sh

These two scripts serve completely different purposes in the container management system:

| Feature | run-container-common.sh | container-command-common.sh |
|---------|-------------------------|--------------------------|
| Primary purpose | Container management | Command installation |
| Used by | start-ros2-container.sh, start-yocto-container.sh | add-commands-to-container.sh, ensure-yocto-container-commands.sh |
| When used | When creating/managing containers | When installing commands inside containers |
| Level of abstraction | High (manages container lifecycle) | Low (handles file operations) |
| User interaction | Indirect (through container scripts) | None (library only) |
| Key functions | run_container(), stop_container(), remove_container(), verify_container() | create_command_script(), get_command_content(), create_init_script() |
| Scope | Container lifecycle | Command availability |

### Workflow

1. User runs a container starter script (e.g., `start-ros2-container.sh`)
2. The starter script calls `run-container-common.sh` to create and manage the container
3. During container creation, `run-container-common.sh` calls `add-commands-to-container.sh` to install container commands
4. `add-commands-to-container.sh` uses `container-command-common.sh` for shared functionality
5. For Yocto containers, additional command setup may be performed with `ensure-yocto-container-commands.sh` (which also uses `container-command-common.sh`)

This modular approach allows for consistent behavior while enabling specialization for different container types.

## Container Commands

The following commands are available in all containers created with these scripts:
