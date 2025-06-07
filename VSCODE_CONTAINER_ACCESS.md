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
   ./robust-ros2-container.sh --name my_ros2_dev

   # For Yocto
   ./robust-yocto-container.sh --name my_yocto_dev
   ```

2. In VS Code:
   - Click the green "Remote" icon in the bottom-left corner
   - Select "Dev Containers: Attach to Running Container..."
   - Choose your container from the list

The robust containers are specifically designed to work reliably with VS Code, preventing issues where containers might stop unexpectedly during development.

## Connection Steps (Standard Containers)

1. Make sure your ROS2 container is running:
   ```bash
   ./run-ros2-container.sh
   ```

2. In VS Code:
   - Click the green "Remote" icon in the bottom-left corner
   - Select "Remote-Containers: Attach to Running Container..."
   - Choose your container (typically named `ros2_container` or your custom name)

3. VS Code will connect to the container, and you can now:
   - Open the `/workspace` or `/projects` folder to access your mounted project files
   - Install VS Code extensions directly inside the container
   - Use the integrated terminal to run ROS2 commands

## Volume Mounts in Containers

Our container scripts mount the workspace directory to multiple paths:

- `/workspace`: The primary path for development work
- `/projects`: An alternate path for compatibility with some VS Code extensions and tools
- Container-specific paths:
  - ROS2: `/home/ubuntu/ros2_ws`
  - Yocto: `/workdir` and `/home/ubuntu/yocto_ws`

These multiple mounts ensure maximum compatibility with different tools and workflows.

### Fixing Missing Volume Mounts

If you have existing containers created with older scripts that are missing the `/projects` mount, you can use one of our fix scripts:

For ROS2 containers:
```bash
./fix-ros2-container-volumes.sh your_container_name
```

For Yocto containers:
```bash
./fix-yocto-container-volumes.sh your_container_name
```

For any container type (more general approach):
```bash
./fix-container-volumes.sh your_container_name
```

These scripts will:
1. Create the `/projects` directory in the container
2. Temporarily stop the container
3. Recreate it with the proper volume mounts
4. Preserve all other settings and configurations

The container-specific scripts (for ROS2 and Yocto) are simpler and more reliable, so they are recommended when possible.

## Cleaning Up Temporary Images

When fixing container volume mounts, temporary images can sometimes be left behind (e.g., `temp_ros2_container_image`). 
These are intermediate images created during the container fixing process.

To clean up these temporary images, use the cleanup script:

```bash
./cleanup-container-images.sh
```

This script will:
1. Identify any temporary container images
2. Stop and remove containers using these images
3. Force remove the temporary images
4. Run a general Docker cleanup

If you see `temp_*_container_image` in your Docker images list, this script will help clean them up safely.

## Using Docker Exec with the Container

When you connect to the container using `docker exec -it ros2_container bash`, custom commands like `container-help` may not be available. Use the provided `docker-exec-it` script instead:

```bash
# Show container help
./docker-exec-it ros2_container help

# Start a bash session with command info
./docker-exec-it ros2_container bash

# Stop the container
./docker-exec-it ros2_container stop
```

This script ensures that all container commands work properly when connecting directly with Docker exec.

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

For more detailed information about container lifecycle and detached commands, see [DETACHED_COMMANDS.md](DETACHED_COMMANDS.md).

## Quick Recovery with recreate-ros2-container.sh

If you're still having issues with VS Code attaching to the container, we've provided a simple recovery script:

```bash
./recreate-ros2-container.sh [--name container_name]
```

This script will:
1. Stop and remove the existing container completely
2. Create a fresh container using saved settings (if available)
3. Ensure all the proper processes are running inside the container

After running this script, you should be able to attach to the container from VS Code without any issues.

## Comprehensive Container Fixing

For the most thorough container repair, we've created a comprehensive fix script:

```bash
./fix-ros2-container.sh [--name container_name]
```

This script performs a complete check and repair of your container, fixing:
- Workspace directory issues
- Keep-alive process problems
- Permission errors
- Container lifecycle management

If you're having persistent issues with VS Code not being able to connect to your container, run this script before trying to attach from VS Code again.

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
./robust-ros2-container.sh --name my_ros2_dev --fix

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
./robust-ros2-container.sh --name my_ros2_dev

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
