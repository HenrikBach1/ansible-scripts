# VS Code Remote Container Access

This guide explains how to connect to your ROS2 Docker container using VS Code Remote Containers.

## Prerequisites

1. Install Visual Studio Code: https://code.visualstudio.com/
2. Install the "Remote - Containers" extension in VS Code

## Connection Steps

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

## Advanced Configuration

For advanced VS Code configuration, you can create a `.devcontainer` folder in your project with custom settings.
