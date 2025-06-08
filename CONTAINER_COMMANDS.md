# Container Commands Reference

This document provides a reference for all the commands available inside the ROS2 and Yocto containers.

## Standard Commands

These are the primary commands available in all containers:

| Command | Description |
|---------|-------------|
| `detach` | Detach from the container (container keeps running in the background) |
| `stop` | Stop the container (container will be stopped but not removed) |
| `remove` | Stop and remove the container completely |
| `help` | Show all available container commands |

## Legacy/Compatibility Commands

These commands are maintained for backward compatibility:

| Legacy Command | Equivalent To | Description |
|----------------|---------------|-------------|
| `stop_container` | `stop` | Stops the container |
| `container_help` | `help` | Shows command help |
| `container-help` | `help` | Shows command help (hyphen version) |

## How These Commands Work

When you run any of these commands, the container creates a marker file that is detected by the container watcher script:

1. For `detach`:
   - ROS2: Creates `/home/ubuntu/.container_detach_requested`
   - Yocto: Creates `/workdir/.container_detach_requested`

2. For `stop`:
   - ROS2: Creates `/home/ubuntu/.container_stop_requested`
   - Yocto: Creates `/workdir/.container_stop_requested`

3. For `remove`:
   - ROS2: Creates `/home/ubuntu/.container_remove_requested`
   - Yocto: Creates `/workdir/.container_remove_requested`

The container watcher script (`container-watch.sh`) monitors for these marker files and takes the appropriate action.

## Examples

```bash
# Detach from the container while keeping it running
detach

# Stop the container
stop

# Stop and remove the container
remove

# Show help about available commands
help
```

## Ensuring Command Availability

These commands are automatically set up when you connect to a container using:

- `./ros2-connect` for ROS2 containers
- `./yocto-connect` for Yocto containers

If you connect directly with `docker exec -it container_name bash`, these commands won't be available unless you've previously connected with the connect scripts.
