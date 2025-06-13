# VS Code Remote Container Access

This guide explains how to connect to your Docker development containers using VS Code Remote Containers.

## Prerequisites

1. Install Visual Studio Code: https://code.visualstudio.com/
2. Install the "Dev Containers" extension in VS Code (formerly "Remote - Containers")

## Using Robust Containers with VS Code (Recommended)

For the most reliable VS Code remote development experience, we recommend using the robust container scripts:

1. Create a robust container:
   ```bash
   # For ROS2
   ./start-ros2-container.sh --name my_ros2_dev

   # For Yocto
   ./robust-yocto-container.sh --name my_yocto_dev
   ```

2. In VS Code:
   - Click the green "Remote" icon in the bottom-left corner
   - Select "Dev Containers: Attach to Running Container..."
   - Choose your container from the list

The robust containers are specifically designed to work reliably with VS Code, preventing issues where containers might stop unexpectedly during development.

## Connection Steps (Standard Containers)

1. Make sure your container is running:
   ```bash
   ./start-ros2-container.sh
   # or
   ./start-yocto-container.sh
   ```

2. In VS Code:
   - Click the green "Remote" icon in the bottom-left corner
   - Select "Dev Containers: Attach to Running Container..."
   - Choose your container (typically named `ros2_container`, `yocto_container`, or your custom name)

3. VS Code will connect to the container, and you can now:
   - Open the `/workspace` or `/projects` folder to access your mounted project files
   - Install VS Code extensions directly inside the container
   - Use the integrated terminal to run commands

## Container Commands in VS Code

When using VS Code's "Attach to Container" feature, all standard container commands are available in the integrated terminal:

- `container-detach`: Detach from the container (container keeps running in background)
- `container-stop`: Stop the container (container will be stopped but not removed)
- `container-remove`: Stop and remove the container completely
- `container-help`: Show all available container commands

These commands work in all terminal sessions, including VS Code's integrated terminal and "Attach to Container" sessions, ensuring a consistent experience across all connection methods.

> **Note about Container Commands in VS Code**:
> 
> Our container scripts now automatically add container commands to both ROS2 and Yocto containers.
> If you're connecting to a container that was created with our scripts, all commands should be
> available immediately.
>
> However, if you're connecting to a container created through other means or if commands are not available,
> you can run our command setup script to ensure all container commands are available:
>
> ```bash
> # From the host, add container commands to an existing container
> ./add-commands-to-container.sh container_name root  # Use the correct container name
> ```
>
> After running this script, the container commands (`container-help`, `container-detach`, `container-stop`, 
> `container-remove`) will be available in any VS Code terminal session.

## Command-Line Connection Methods

If you need to connect to your containers from the command line (outside of VS Code), 
there are two recommended methods:

1. **Starting a container with the `--attach` option**:
   ```bash
   # Start and immediately connect to a container
   ./start-ros2-container.sh --attach
   ./start-yocto-container.sh --attach
   ```

2. **Connecting to an already running container**:
   ```bash
   # Connect to a running container
   ./ros2-connect
   ./yocto-connect
   ```

> **Important Notes**: 
> 
> 1. You can use EITHER the `start-X-container.sh` scripts OR the `X-connect` scripts:
>    - The `start-X-container.sh` scripts create a new container if it doesn't exist
>    - The `X-connect` scripts can start existing containers if they're stopped
> 
> 2. For the quickest workflow when a container already exists:
>    - Simply run `./ros2-connect` or `./yocto-connect` directly
>    - These scripts will start the container if it's stopped and connect to it
> 
> 3. Always use these methods instead of direct Docker commands (like `docker exec -it container_name bash`) 
>    to ensure all container commands (`help`, `stop`, `remove`, etc.) are available in your session.

## Volume Mounts in Containers

Our container scripts mount the workspace directory to multiple paths:

- `/workspace`: The primary path for development work
- `/projects`: An alternate path **required** for VS Code Remote Development and many extensions
- Container-specific paths:
  - ROS2: `/home/ubuntu/ros2_ws`
  - Yocto: `/workdir`

These multiple mounts ensure maximum compatibility with different tools and workflows. The `/projects` directory is particularly important for VS Code Remote Development, as many extensions expect files to be there.

### Fixing Missing Volume Mounts

If you have existing containers created with older scripts that are missing the `/projects` mount, you can recreate them with proper mounts:

### Recreate Container with Proper Mounts

Use the restart option to stop, remove, and recreate your container with the correct mounts:

```bash
./start-ros2-container.sh --restart [container_name]
./start-yocto-container.sh --restart [container_name]
```

**What this does:**
- Stops the existing container
- Removes the container completely
- Creates a new container with all proper volume mounts (including `/projects`)
- Preserves any saved configuration settings

### Alternative: Manual Recreation

If you prefer to do it step by step:

1. Stop the container: `docker stop your_container_name`
2. Remove the container: `docker rm your_container_name`
3. Recreate it with the proper script: `./start-ros2-container.sh` or `./start-yocto-container.sh`

> **Note:** The only reliable way to add mounts to a container is to recreate it. Docker does not support adding bind mounts to running containers.
## Checking Container Mounts

You can verify that your container has the correct mounts with this command:

```bash
docker exec -it your_container_name ls -la /projects
```

If this command shows your workspace files, the mount is working correctly. If it shows "No such file or directory", you need to recreate the container as described above.

## Common Issues and Solutions

### Missing /projects Directory

The most common issue with VS Code Remote Development is a missing `/projects` directory. This happens when:
1. The container was created with an older version of the scripts
2. The container was created manually without the correct volume mounts

**Solution:** Use the restart option to recreate the container with proper mounts:

```bash
./start-ros2-container.sh --restart [container_name]
./start-yocto-container.sh --restart [container_name]
```

This will recreate your container with all the necessary volume mounts including `/projects`.

```bash
./cleanup-container-images.sh
```

This script will:
1. Identify any temporary container images
2. Stop and remove containers using these images
3. Force remove the temporary images
4. Run a general Docker cleanup

If you see `temp_*_container_image` in your Docker images list, this script will help clean them up safely.

## Fixing Container Stability Issues

If your container is exiting immediately after starting, you can use the --fix option with the container scripts:

```bash
# For ROS2 containers
./start-ros2-container.sh --fix

# For Yocto containers
./start-yocto-container.sh --fix

# To fix a specific container
./start-ros2-container.sh --fix my_container_name
```

This will:
1. Create a robust keep-alive process in the container
2. Set up a trap to keep the container running even if the main process exits
3. Ensure the container stays running for VS Code to connect

## Container Commands in VS Code and Docker Exec

Container commands like `help`, `detach`, `stop`, and `remove` are now available regardless of how you connect to the container, including:

- When connecting through VS Code's "Attach to Container" feature
- When using `docker exec -it container_name bash` directly
- When using the `./ros2-connect` or `./yocto-connect` scripts

These commands are set up in the container's system-wide bashrc during container creation, so they will be available in all interactive shells.

> **Note for older containers**: If you're using a container created before this update, you may need to recreate it to have these commands available in all connection methods.

For convenience, you can also use the provided `docker-exec-it` script:

```bash
# Show container help
./docker-exec-it ros2_container help

# Start a bash session with command info
./docker-exec-it ros2_container bash

# Stop the container
./docker-exec-it ros2_container stop
```

### ROS2 Environment in Docker Exec

When using `docker exec` directly, the ROS2 environment is not automatically sourced. You have two options:

1. Use a login shell:
   ```bash
   docker exec -it ros2_container bash -l
   ```

2. Use the source_ros wrapper script:
   ```bash
   docker exec -it ros2_container ~/bin/source_ros bash
   ```

The second option is useful for one-off commands:
```bash
docker exec -it ros2_container ~/bin/source_ros ros2 topic list
```

## Recommended VS Code Extensions for ROS2 Development

Once connected to the container, consider installing these extensions:

- ROS (ms-iros.ros)
- Python (ms-python.python)
- C/C++ (ms-vscode.cpptools)
- CMake (twxs.cmake)
- XML (redhat.vscode-xml)

## Troubleshooting

If you don't see your container in the list:

1. Make sure it's running with `docker ps`
2. The container is automatically configured with labels for VS Code detection
3. Try restarting VS Code if the container was recently started

## Troubleshooting Container Reattachment

If VS Code is unable to reattach to a container that was previously attached but has exited, use our helper script:

```bash
./restart-vscode-container.sh <container_name>
```

This script:
1. Restarts the stopped container
2. Ensures the keep-alive process is running
3. Sets up the container in a state that VS Code can attach to

After running the script, follow the standard connection steps above.

### Common Issues and Solutions

1. **"Failed to connect to container" error**:
   - Run the restart-vscode-container.sh script
   - Restart VS Code
   - Make sure Docker is running properly on your host

2. **Container exits immediately after restart**:
   - This usually indicates a missing keep-alive process
   - Our restart script handles this, but you can manually check:
     ```bash
     docker exec <container_name> ps aux | grep keep
     ```

3. **VS Code doesn't show the container in the list**:
   - Refresh the containers list in VS Code
   - Restart the Docker extension
   - Run `docker ps` to verify the container is actually running

For more detailed information about container lifecycle, detached commands, and troubleshooting, see [CONTAINER_COMMANDS.md](CONTAINER_COMMANDS.md).

## Quick Recovery with start-*-container.sh --fix

If you're having issues with VS Code attaching to containers, use the built-in fix functionality:

```bash
./start-ros2-container.sh --fix [container_name]
./start-yocto-container.sh --fix [container_name]
```

This will fix containers that keep exiting and ensure they stay running.

For complete container recreation, use:

```bash
./recreate-ros2-container.sh [--name container_name]
```

This script will:
1. Stop and remove the existing container completely
2. Create a fresh container using saved settings (if available)
3. Ensure all the proper processes are running inside the container

After running these scripts, you should be able to attach to the container from VS Code without any issues.

## Alternative Troubleshooting

If you continue to have issues after using the `--fix` option, you can:

1. Use the complete recreation script for a fresh start:
   ```bash
   ./recreate-ros2-container.sh [--name container_name]
   ```

2. For missing `/projects` directory issues, recreate the container:
   ```bash
   ./start-ros2-container.sh --restart [container_name]
   ./start-yocto-container.sh --restart [container_name]
   ```

3. Check container status and logs:
   ```bash
   ./start-ros2-container.sh --verify [container_name]
   ```

If you're having persistent issues with VS Code not being able to connect to your container, try these solutions in order before attempting to attach from VS Code again.

## Advanced Configuration

For advanced VS Code configuration, you can create a `.devcontainer` folder in your project with custom settings.

## Robust Container Creation for VS Code

If you're experiencing persistent issues with VS Code not being able to connect to the container, or if the container keeps exiting, we've created a simplified script that creates a more robust container specifically designed for VS Code integration:

```bash
./create-robust-ros2-container.sh [--name container_name] [--workspace /path/to/workspace]
```

This script creates a container that:
1. Uses a direct approach without complex entrypoint scripts
2. Stays running reliably even after detaching
3. Provides proper directory permissions for VS Code
4. Has ROS2 properly sourced and ready to use

After running this script, the container should remain running and be immediately available in VS Code's Remote Explorer.

## Using Robust Containers for Troubleshooting

The robust container scripts provide built-in fixing capabilities that can solve most common container issues:

### Fixing Existing Containers

```bash
# Fix a ROS2 container
./start-ros2-container.sh --name my_ros2_dev --fix

# Fix a Yocto container
./robust-yocto-container.sh --name my_yocto_dev --fix
```

These commands will:
1. Ensure the container is running
2. Fix workspace directory issues
3. Repair keep-alive processes
4. Set proper permissions

### Container Completely Unresponsive?

If a container is completely unresponsive and can't be fixed, the easiest solution is to recreate it:

```bash
# For ROS2
docker stop my_ros2_dev
docker rm my_ros2_dev
./start-ros2-container.sh --name my_ros2_dev

# For Yocto
docker stop my_yocto_dev
docker rm my_yocto_dev
./robust-yocto-container.sh --name my_yocto_dev
```

The robust container scripts create containers that are more resilient to common issues that can cause VS Code Remote Development to fail.

## Recommended Workflow

For the best experience with VS Code Remote Development:

1. Create containers using the robust scripts
2. If issues occur, try the --fix option first
3. If fixing fails, recreate the container
4. Use the container-utils.sh functions for advanced operations

This approach minimizes disruption to your development workflow and ensures maximum reliability when working with containers in VS Code.
