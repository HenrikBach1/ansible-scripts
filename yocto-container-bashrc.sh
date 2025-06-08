#!/bin/bash
# Custom bashrc additions for Yocto container

# Add detach function to allow easy detaching from the container
detach() {
  echo "Detaching from container (container keeps running)..."
  echo "Container will continue running in the background."
  touch /workdir/.container_detach_requested
  exit
}

# Add stop function to stop the container completely
stop_container() {
  echo "Stopping container completely..."
  touch /workdir/.container_stop_requested
  exit
}

# Add container-help function to show help message
container_help() {
  echo "Yocto Container Commands:"
  echo "------------------------"
  echo "  - Type 'detach': Detach from container (container keeps running)"
  echo "  - Type 'stop_container': Stop the container completely (container will shut down)"
  echo "  - Type 'container_help': Show this help message"
  echo ""
  echo "Note: When you detach, a helper script on the host will monitor and restart"
  echo "      the container if needed, ensuring it continues running in the background."
  echo ""
  echo "Note: When you use 'stop_container', the container will be completely shut down and"
  echo "      will not continue running in the background."
}

# Show help message on login
echo "Welcome to the Yocto Container!"
echo "Type 'container_help' for information on container-specific commands."
echo "Type 'detach' to detach from the container (container keeps running)."
echo ""
