# Container Commands and Management

This document provides a comprehensive guide to working with our development containers, including all available commands, connection methods, and troubleshooting techniques.

## Standard Container Commands

These are the primary commands available in all containers:

| Command | Description |
|---------|-------------|
| `container-detach` | Detach from the container (container keeps running in the background) |
| `container-stop` | Stop the container (container will be stopped but not removed) |
| `container-remove` | Stop and remove the container completely |
| `container-help` | Show all available container commands |

## How These Commands Work

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

# Container Management Options

The `start-ros2-container.sh` and `start-yocto-container.sh` scripts now provide direct options for container management:

```bash
# Stop a container
./start-ros2-container.sh --stop [CONTAINER_NAME]
./start-yocto-container.sh --stop [CONTAINER_NAME]

# Remove a container (stops it first if running)
./start-ros2-container.sh --remove [CONTAINER_NAME]
./start-yocto-container.sh --remove [CONTAINER_NAME]
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

# Working with Detached Commands

When working with containers, sometimes you need to run commands in detached mode (in the background). 
This is especially useful for long-running processes that you don't want to block your terminal.

## The Issue with Detached Commands

In some Docker container setups, when a detached command is issued (using `docker exec -d`), the container
might stop after the command completes if the command was the last active process in the container. This
happens because Docker containers are designed to exit when their main process exits.

Our container scripts have been enhanced to prevent this issue, but if you're still experiencing problems,
you can use the provided helper scripts and techniques below.

## Solution: Using docker-exec-detached

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

## Using Robust Container Scripts

The robust container scripts also provide built-in support for running detached commands:

```bash
# For Yocto containers
./robust-yocto-container.sh --name my_yocto_dev --command "cd build && bitbake core-image-minimal"
```

This approach is recommended for the most reliable detached command execution.

## Additional Keep-Alive Mechanisms

The containers include multiple keep-alive mechanisms to ensure they stay running:

1. A background sleep process that runs indefinitely
2. A more resilient keep-alive script that is designed to be difficult to terminate accidentally
3. A container watcher script that monitors the container and restarts it if needed

## Manually Ensuring Container Stays Running

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

## Debugging Container Lifecycle Issues

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

# VS Code Container Integration

## VS Code Container Integration Issues

When using Visual Studio Code with containers, you might encounter issues when trying to reattach to a container that has exited unexpectedly, especially after running detached commands. This is due to several factors:

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

# Container Repair and Recovery

## Easy Container Recreation

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

## Complete Container Fix Script

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

## Container Mount Conflict Issue

In some cases, when trying to restart a container, you might encounter an error related to mount conflicts:

```
Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: 
runc create failed: unable to start container process: error during container init: error mounting "...entrypoint.sh" to rootfs...
```

This happens because:

1. The container was started with a volume mount that maps a host script to the container's entrypoint
2. When trying to restart, Docker can't recreate the exact same mount conditions
3. This creates a conflict where Docker tries to mount a file over another file

### Solution

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

### Prevention

To prevent this issue in future container setups:

1. Make sure your entrypoint scripts are copied into the container during build time rather than mounted at runtime
2. Use the `--save-config` option when creating containers so they can be easily recreated
3. Consider using Docker Compose for more complex container setups with consistent volume mounts

## Direct Container Creation with create-robust-ros2-container.sh

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

# Bash Completion for Container Commands

To enhance usability, we provide a bash completion script for container commands. This allows you to use the `Tab` key to auto-complete container names and commands.

## Installation

Source the completion script in your `.bashrc` or run it before using container commands:

```bash
source ./container-commands-completion.sh
```

To make the completion permanent, add it to your `.bashrc`:

```bash
echo "source $(pwd)/container-commands-completion.sh" >> ~/.bashrc
```

## Supported Commands

The bash completion supports:

- Container management scripts (`add-commands-to-container.sh`, `add-commands-to-poky-container.sh`, etc.)
- Docker exec wrappers (`docker-exec-it`, `docker-exec-detached`)
- Container connection scripts (`ros2-connect`, `yocto-connect`)
- Container maintenance scripts (`restart-ros2-container.sh`, `fix-container-volumes.sh`, etc.)
- In-container commands (`container-detach`, `container-stop`, etc.)

## Usage Examples

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

# Special Considerations for CROPS/Poky Containers

CROPS/Poky containers (used for Yocto development) have some unique characteristics that require special handling of container commands.

## CROPS/Poky Container Command Installation

The standard container commands (`container-detach`, `container-stop`, etc.) are installed in CROPS/Poky containers using a specialized installation process that accommodates their environment constraints.

### Using the Dedicated Poky Script

For CROPS/Poky containers, we provide a dedicated script that handles their specific requirements:

```bash
./add-commands-to-poky-container.sh CONTAINER_NAME
```

For example:
```bash
./add-commands-to-poky-container.sh yocto_container
```

This script:
- Handles the unique environment of CROPS/Poky containers
- Works with restricted permissions common in these containers
- Uses appropriate installation locations (/workdir or /tmp)
- Creates necessary symlinks and aliases
- Configures PATH to include command locations

### Example Script Usage

For a quick example of using these commands with Poky containers, we provide an example script:

```bash
./example-add-commands-to-poky.sh
```

This script demonstrates:
1. Checking if a Yocto container is running and starting it if needed
2. Adding container commands to the container
3. Connecting to the container with proper setup

### Implementation Details

The `add-commands-to-poky-container.sh` script:

1. Creates temporary command scripts
2. Copies them to the container
3. Sets up the commands in appropriate directories based on what's writable
4. Creates necessary symlinks and aliases
5. Configures bashrc files to include the commands in PATH
6. Adds bash completion for easy command usage

### How It Works

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

### Installation Locations

Commands are installed in the following locations (in order of preference):

1. `/workdir/.container_commands/` (if /workdir exists and is writable)
2. `/tmp/.container_commands/` (fallback location)

Symlinks are also created in:
- `/usr/local/bin/` (if writable)
- `/tmp/bin/` (fallback location)

## Troubleshooting CROPS/Poky Container Commands

If commands are not available after installation:

1. Check if the commands exist in the container:
   ```bash
   docker exec CONTAINER_NAME ls -la /tmp/.container_commands/
   ```

2. Ensure the scripts are executable:
   ```bash
   docker exec CONTAINER_NAME chmod +x /tmp/.container_commands/*
   ```

3. Manually add the commands to your PATH:
   ```bash
   docker exec -it CONTAINER_NAME bash -c 'export PATH=/tmp/.container_commands:$PATH; bash'
   ```

4. For permission issues, try running the installation script with:
   ```bash
   sudo ./add-commands-to-poky-container.sh CONTAINER_NAME
   ```
