# Container Commands and Management

This document provides a comprehensive guide to working with our development containers, including all available commands, troubleshooting techniques, and verification procedures.

## Current Working Solution (Updated June 2025)

**✅ Container commands now work correctly in all environments:**

- **CLI Connections**: Using `./yocto-connect` or `./ros2-connect`
- **VS Code Remote Containers**: Full compatibility with proper PATH and commands
- **Direct Docker Access**: Commands available when using login shells

### Architecture Overview

The container command system uses a modular architecture:

1. **Container Creation**: `start-yocto-container.sh` / `start-ros2-container.sh`
2. **Command Installation**: `ensure-yocto-container-commands.sh` / `ensure-ros2-container-commands.sh`
3. **Shared Library**: `container-command-common.sh` (provides reusable functions)
4. **Connection Scripts**: `yocto-connect` / `ros2-connect` (enhanced connection with proper environment)
5. **Container Watch**: `container-watch.sh` (monitors container state and handles command requests)

### Key Design Principles

- **Container-Specific Installation**: Commands are installed inside the container (not on host)
- **Multiple Installation Locations**: Commands installed in both `~/bin/` and `/tmp/.container_commands/`
- **Login Shell Compatibility**: Environment properly configured for login shells (VS Code compatibility)
- **Proper Tooling Usage**: Always use existing scripts rather than manual setup
- **Host-Based Monitoring**: Watch functionality remains on the host to manage containers

### Quick Start

1. **Create container with proper tooling**:
   ```bash
   ./start-yocto-container.sh --clean  # Clean slate
   ```

2. **Commands are automatically installed** during container creation

3. **Connect using proper scripts**:
   ```bash
   ./yocto-connect  # Enhanced connection with full environment
   ```

4. **VS Code Remote Containers work automatically** - no additional setup needed
   - Commands available immediately: `container-help`, `container-detach`, etc.
   - For colored prompt: `source ~/.shrc` (shows green user@container_name, blue path)

---

## Summary: Current Working State ✅

**As of June 2025, the container command system is fully functional:**

### ✅ What Works Now

1. **VS Code Remote Containers**: Full compatibility with proper environment and commands
2. **CLI Connections**: Enhanced experience with `./yocto-connect` and `./ros2-connect`
3. **Container Commands**: Available in all connection methods (`container-help`, `container-detach`, etc.)
4. **Workspace Paths**: Consistent mounting and symlinks across all container types
5. **Shell Compatibility**: Works with both `bash` and `sh` shells, login and non-login modes

### 🛠️ Proper Usage Pattern

```bash
# 1. Create container with proper tooling
./start-yocto-container.sh --clean

# Alternative: Restart existing container
./start-yocto-container.sh --restart

# 2. Commands are automatically installed
# (No manual setup needed)

# 3. Connect using enhanced scripts
./yocto-connect

# 4. VS Code Remote Containers work automatically
# (Open folder in container through VS Code Remote Explorer)
```

### 🎯 Key Success Factors

- **Always use existing tooling scripts** instead of manual Docker commands
- **Container commands installed in container** (not on host) for proper separation of concerns
- **Dual installation strategy** (`~/bin/` + `/tmp/.container_commands/`) ensures compatibility
- **Login shell support** enables VS Code Remote Container compatibility
- **Proper container lifecycle management** with watch and keep-alive processes

### 📞 Getting Help

If you encounter issues:

1. **Start with clean setup**: `./start-yocto-container.sh --clean`
2. **Verify with diagnostics**: `docker exec yocto_container sh -l -c "container-help"`
3. **Check troubleshooting section** above for specific error patterns
4. **Use proper connection scripts**: `./yocto-connect` for enhanced experience

The system has been tested and verified to work correctly with:
- CLI connections via `yocto-connect`
- VS Code Remote Containers extension
- Direct docker exec with login shells
- Multiple shell types (bash, sh)
- Container lifecycle operations (detach, stop, remove)

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

# Restart a container (stops and recreates it)
./start-ros2-container.sh --restart [CONTAINER_NAME] 
./start-yocto-container.sh --restart [CONTAINER_NAME]

# Remove a container (stops it first if running)
./start-ros2-container.sh --remove [CONTAINER_NAME]
./start-yocto-container.sh --remove [CONTAINER_NAME]

# Verify container setup
./start-ros2-container.sh --verify [CONTAINER_NAME]
./start-yocto-container.sh --verify [CONTAINER_NAME]
```

**Note**: The `--restart` option is equivalent to `--clean` - it stops and removes the existing container, then creates a new one with the current configuration. This ensures a completely fresh container setup.

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

Container commands are available regardless of how you connect to the container:

- Using `./ros2-connect` or `./yocto-connect` scripts
- Using `./start-ros2-container.sh --attach` or `./start-yocto-container.sh --attach`
- Using VS Code's "Attach to Container" feature
- Using direct `docker exec -it container_name bash` commands

### How Commands Are Installed

The container command installation process follows this workflow:

1. **Container Creation**: When you use `start-yocto-container.sh` or `start-ros2-container.sh`, the script automatically calls the appropriate command installation script
2. **Command Installation**: The `ensure-yocto-container-commands.sh` (or similar) script installs commands in multiple locations:
   - `~/bin/` directory (e.g., `/home/usersetup/bin/`)
   - `/tmp/.container_commands/` directory (for backward compatibility)
3. **Shell Environment Setup**: The installation script configures the shell environment to include the command directories in PATH for login shells

### VS Code Compatibility

**✅ VS Code Remote Containers now work correctly!**

When connecting to containers via VS Code Remote Containers extension:

- **Shell Type**: VS Code typically uses `sh` as the default shell with login mode (`sh -l`)
- **PATH Configuration**: Login shells automatically include `~/bin` in the PATH
- **Command Availability**: All container commands (`container-help`, `container-detach`, etc.) are available
- **Prompt**: The shell prompt correctly shows the container context

**Testing VS Code Connection**:
To verify VS Code compatibility, you can simulate the VS Code connection:

```bash
# Test the exact shell environment VS Code uses
docker exec yocto_container sh -l -c "echo 'Shell: sh (login)' && echo 'PATH:' && echo \$PATH && container-help"
```

This should show:
- PATH includes `/home/usersetup/bin`
- All container commands work correctly
- Proper shell environment

### Connection Methods Summary

| Connection Method | Shell Type | Commands Available | Notes |
|------------------|------------|-------------------|--------|
| `./yocto-connect` | `bash --login` | ✅ All commands | Custom prompt, enhanced environment |
| VS Code Remote | `sh -l` | ✅ All commands | Standard prompt, login shell |
| Direct docker exec | `bash` | ⚠️ May need setup | Depends on shell configuration |
| Non-login shell | `sh` or `bash` | ❌ Not in PATH | Commands exist in `~/bin/` but not in PATH |

### Troubleshooting Command Availability

If container commands are not available:

1. **Check if container was created with proper tooling**:
   ```bash
   # Use the proper container creation script
   ./start-yocto-container.sh --clean
   ```

2. **Ensure commands are installed**:
   ```bash
   # Manually install/update commands
   ./ensure-yocto-container-commands.sh
   ```

3. **Verify installation**:
   ```bash
   # Check if commands exist
   docker exec yocto_container ls -la ~/bin/container-*
   
   # Test login shell (VS Code style)
   docker exec yocto_container sh -l -c "container-help"
   ```

4. **Check PATH in different shell contexts**:
   ```bash
   # Non-login shell (may not have ~/bin in PATH)
   docker exec yocto_container sh -c "echo \$PATH"
   
   # Login shell (should have ~/bin in PATH)
   docker exec yocto_container sh -l -c "echo \$PATH"
   ```

### Legacy Container Support

> **Note**: If you're using an older container that was created before this update, you might need to recreate it to have these commands available in all connection methods. Use the `--clean` option to ensure a fresh setup:
>
> ```bash
> ./start-yocto-container.sh --clean
> ```

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

2. **Missing Keep-Alvive Process**:
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

### VS Code Remote Container Fix ✅

**Issue**: VS Code remote containers use `sh` shells that don't load user profile files properly, resulting in missing container commands and basic prompts.

**Solution**: Enhanced `container-shell-setup.sh` to install commands system-wide and create system profile:

1. **System-wide Installation**: Commands installed in `/usr/local/bin/` (always in PATH)
2. **System Profile**: Created `/etc/profile.d/yocto-container.sh` for all login shells
3. **Multiple Locations**: Commands available in user bin, tmp, and system locations
4. **Shell Compatibility**: Works with both bash and sh shells

**Status**: 
- ✅ Container commands work perfectly in VS Code (`container-help`, `container-detach`, etc.)
- ✅ Commands available in system PATH  
- ✅ Aliases work (`detach`, `stop`, `help`)
- ✅ **Prompt solution available**: Source `.shrc` to get `user@(yocto):path$` prompt

**Prompt Setup for VS Code** (run once per session):
```bash
# Source the shell configuration to get colored prompt and environment:
source ~/.shrc

# Result: Changes prompt from 'sh-5.1$' to colored 'usersetup@yocto_container:/path$'
# - Green user@container_name (showing actual container)
# - Blue path  
# - Also loads all aliases and PATH configurations
```

**Example**:
```bash
sh-5.1$ pwd
/home/usersetup
sh-5.1$ source ~/.shrc 
.shrc loaded
usersetup@yocto_container:/home/usersetup$ container-help
# Now you have full functionality with colored prompt (green user@container, blue path)
```

**Usage in VS Code** (after sourcing .shrc):
```bash
container-help    # Show available commands
container-detach  # Detach from container (or 'detach')
container-stop    # Stop container (or 'stop')
container-remove  # Remove container
help             # Same as container-help
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
- Container maintenance scripts (`restart-ros2-container.sh`, `restart-yocto-container.sh`, etc.)
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

## Container Verification

To verify container configurations, you can use the built-in verification features:

### Individual Container Verification

For ROS2 containers:
```bash
./start-ros2-container.sh --verify [CONTAINER_NAME]
```

For Yocto containers:
```bash
./start-yocto-container.sh --verify [CONTAINER_NAME]
```

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

### Quick Diagnostic Commands

First, verify your setup with these diagnostic commands:

```bash
# Check container status
docker ps | grep yocto

# Verify command installation
docker exec yocto_container ls -la ~/bin/container-*

# Test VS Code style connection (login shell)
docker exec yocto_container sh -l -c "echo 'PATH:' && echo \$PATH && container-help"

# Test bash connection
docker exec yocto_container bash -l -c "container-help"
```

### Common Issues and Solutions

#### ❌ "Container commands not available in VS Code"

**Cause**: Container created without proper command installation or using old setup.

**Solution**:
```bash
# Recreate container with proper tooling
./start-yocto-container.sh --clean

# Verify VS Code compatibility
docker exec yocto_container sh -l -c "container-help"
```

#### ❌ "Commands not found" or "command not found"

**Cause**: Commands not in PATH or not installed.

**Solution**:
```bash
# Ensure commands are installed
./ensure-yocto-container-commands.sh

# Check if commands exist
docker exec yocto_container ls -la ~/bin/container-*

# Test in login shell (should work)
docker exec yocto_container sh -l -c "container-help"
```

#### ❌ "Wrong prompt in VS Code" (showing `sh-5.1$`)

**Cause**: Shell environment not properly configured for login shells.

**Solution**: This is expected behavior. VS Code uses `sh` by default, which shows a basic prompt. However, container commands should still be available. The enhanced prompt is available when using `./yocto-connect`.

#### ❌ "Container stops unexpectedly"

**Cause**: Container watch or keep-alive processes not running.

**Solution**:
```bash
# Use proper container creation script
./start-yocto-container.sh --name yocto_container

# Verify container is running
docker ps | grep yocto
```

### Legacy Container Issues

#### ❌ "Container created with old scripts"

**Solution**: Always recreate containers using current tooling:
```bash
# Remove old container
docker rm -f yocto_container

# Create with current scripts
./start-yocto-container.sh --clean
```

### Advanced Troubleshooting

#### Check PATH Configuration

```bash
# Non-login shell (may not have ~/bin)
docker exec yocto_container sh -c "echo 'Non-login PATH:' && echo \$PATH"

# Login shell (should have ~/bin)
docker exec yocto_container sh -l -c "echo 'Login PATH:' && echo \$PATH"
```

#### Verify Installation Locations

```bash
# Check both installation locations
docker exec yocto_container sh -c "
  echo '=== ~/bin directory ==='
  ls -la ~/bin/container-* 2>/dev/null || echo 'No commands in ~/bin'
  echo
  echo '=== /tmp/.container_commands directory ==='
  ls -la /tmp/.container_commands/ 2>/dev/null || echo 'No commands in /tmp/.container_commands'
"
```

#### Manual Command Installation

If automatic installation fails:

```bash
# Manual installation using our tooling
./ensure-yocto-container-commands.sh

# Verify it worked
docker exec yocto_container sh -l -c "container-help"
```

### When to Use Each Script

| Issue | Script to Use | Notes |
|-------|---------------|--------|
| Create new container | `./start-yocto-container.sh --clean` | Always use for fresh setup |
| Restart existing container | `./start-yocto-container.sh --restart` | Convenient restart (same as --clean) |
| Container exists but commands missing | `./ensure-yocto-container-commands.sh` | Install/update commands |
| Connect to existing container | `./yocto-connect` | Enhanced environment |
| VS Code connection issues | Recreate with `--clean` or `--restart` | VS Code works automatically after proper setup |
| Container stops unexpectedly | Use proper creation scripts | Ensures watch and keep-alive processes |

### Verification After Fixes

After applying any fix, verify the solution:

```bash
# 1. Container is running
docker ps | grep yocto

# 2. Commands are installed
docker exec yocto_container ls -la ~/bin/container-*

# 3. VS Code style connection works
docker exec yocto_container sh -l -c "container-help"

# 4. CLI connection works
./yocto-connect  # Should show enhanced prompt and available commands
```

### Container Verification

To verify container configurations, use the built-in verification commands:

```bash
# Verify ROS2 containers
./start-ros2-container.sh --verify [CONTAINER_NAME]

# Verify Yocto containers  
./start-yocto-container.sh --verify [CONTAINER_NAME]

# Or use the standalone verification tool
./verify-container.sh [CONTAINER_NAME]
```

### Deprecated Scripts Removed:
- `fix-yocto-container-volumes.sh` - **REMOVED**: Redundant with `start-yocto-container.sh --restart`
  - Functionality: Volume mount fixes for existing containers
  - Replacement: Use `./start-yocto-container.sh --restart` or `--clean`
  - Reason: Duplicated functionality already handled by main container script

- `yocto-container-bashrc.sh` - **REMOVED**: Never actually sourced and redundant
  - Functionality: Shell functions and environment setup for Yocto containers
  - Replacement: Fully covered by unified `container-shell-setup.sh`
  - Issues: File was mounted to `/opt/` but never sourced by any profile
  - Reason: Unified tooling handles all functionality automatically during container setup

- `fix-yocto-shell-issue.sh` - **REMOVED**: Completely superseded by unified approach
  - Functionality: Manual shell and PATH fixes for containers
  - Replacement: Fully integrated into `container-shell-setup.sh` and `yocto-connect`
  - Issues: Used old prompt format, no VS Code support, required manual execution
  - Reason: Unified approach handles all functionality automatically during container setup

### Unified Setup Architecture (Latest Update)

**Successfully merged and unified container management scripts:**

### Files Consolidated:
- `ensure-yocto-container-commands.sh` ➜ Now unified with `container-shell-setup.sh`
- `container-shell-setup.sh` ➜ Now contains all functionality
- `yocto-connect` ➜ Simplified to use unified setup script

### What Was Merged:
1. **Command Installation Logic**: Container command creation and installation
2. **Shell Environment Setup**: PATH configuration, prompt setup, and aliases
3. **Multi-location Installation**: User bin, tmp, and system directories
4. **Shell Compatibility**: Works with bash, sh, login, and non-login shells
5. **VS Code Integration**: Proper environment for remote container connections

### New Workflow:
```bash
# 1. Start container (handles creation and basic setup)
./start-yocto-container.sh

# 2. Connect (automatically runs unified setup if needed)
./yocto-connect

# 3. All commands available immediately
container-help
container-detach
container-stop
container-remove
```

### Verification:
✅ Commands installed in multiple locations for redundancy
✅ Shell environment properly configured for all shell types
✅ Backwards compatibility maintained
✅ VS Code remote container support working
✅ Diagnostic tools confirm proper setup

**The unified approach eliminates redundancy while maintaining all functionality and using proper tooling throughout.**

---

## Container Diagnostic Script

For advanced troubleshooting, use the `container-diagnostic.sh` script to get a comprehensive view of the container environment:

### **Usage**

```bash
# Copy diagnostic script to container and run it
docker cp container-diagnostic.sh CONTAINER_NAME:/tmp/
docker exec CONTAINER_NAME bash /tmp/container-diagnostic.sh

# Or run directly if the script is in a mounted volume
docker exec CONTAINER_NAME bash /workspace/container-diagnostic.sh
```

### **What the Diagnostic Script Checks**

The diagnostic script provides a comprehensive health check:

| Check Category | What It Verifies |
|---------------|------------------|
| **Environment** | Shell type, user, HOME directory, current PATH |
| **Command Availability** | Whether container commands are accessible via PATH |
| **Shell Configuration** | Presence and content of `.bashrc`, profile.d files |
| **File System** | Location of container command files and libraries |

### **Sample Output**

A healthy container environment should show:

```bash
=== Container Environment Diagnostic ===
Shell: /bin/bash
Current user: usersetup
HOME directory: /home/usersetup
Current PATH: /home/usersetup/bin:/tmp/.container_commands:/usr/local/sbin:...

=== Container Commands Availability ===
✓ container-help is in PATH
✓ container-detach is in PATH
✓ container-stop is in PATH
✓ container-remove is in PATH

=== Shell Configuration Files ===
User .bashrc exists
✓ .bashrc includes /tmp/.container_commands in PATH

=== Container Files Check ===
Directory /home/usersetup/bin exists
✓ container-help exists in /home/usersetup/bin
✓ container-detach exists in /home/usersetup/bin
...
```

### **Troubleshooting with Diagnostics**

If the diagnostic script shows issues:

1. **Commands not in PATH**: Run `./ensure-yocto-container-commands.sh`
2. **Missing command files**: Recreate container with `--restart` or `--clean`
3. **Shell configuration issues**: Check if using login shell (`sh -l` or `bash -l`)
```bash
```


