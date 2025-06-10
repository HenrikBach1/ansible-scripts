# Container Command Installation System

This document describes the container command installation system used in our Docker development environment.

## Overview

The container command system provides consistent commands across all our development containers:

- `container-detach`: Detach from container while keeping it running
- `container-stop`: Stop the container
- `container-remove`: Stop and remove the container
- `container-help`: Show help for all container commands

## How Commands Are Installed

The `add-commands-to-container.sh` script automatically installs these commands in multiple ways to ensure they're always available:

1. **User-specific installation**: Commands are installed in the user's home directory
   - Adds command scripts to `$HOME/bin/`
   - Adds functions to the user's `.bashrc`
   - Updates the user's PATH

2. **System-wide installation**: When possible, commands are also installed system-wide
   - Creates symlinks in `/usr/local/bin/`
   - Adds global hooks in `/etc/profile.d/` when permissions allow

3. **Fallback mechanisms**: For containers with restrictive permissions
   - Creates commands in `/tmp/.container_commands/`
   - Creates commands in `/tmp/bin/`
   - Updates global PATH settings when possible

## Special Handling for Container Types

The script includes special handling for different container types:

- **ROS2 containers**: Commands are installed for the `ubuntu` user by default
- **Yocto/CROPS containers**: Commands are installed in `/tmp` directories to avoid workspace pollution

## Troubleshooting

If container commands are not available in your session:

1. **Check installation**:
   ```bash
   # Look for commands in standard locations
   ls -la $HOME/bin/ | grep container
   ls -la /usr/local/bin/ | grep container
   ls -la /tmp/.container_commands/ 2>/dev/null || echo "Not found"
   ```

2. **Manually install commands**:
   ```bash
   # From the host
   ./add-commands-to-container.sh container_name root
   ```

3. **For CROPS/poky containers**, ensure the commands are installed in the appropriate location:
   ```bash
   ls -la /tmp/.container_commands/
   ```

## How It Works

The command system creates special marker files when commands are executed:
- `$HOME/.container_detach_requested`
- `$HOME/.container_stop_requested`
- `$HOME/.container_remove_requested`

These files are detected by the container watcher script running on the host, which then performs the requested operation.
