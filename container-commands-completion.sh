#!/bin/bash
# container-commands-completion.sh
# Bash completion for container management commands

# Complete container names for docker and container command scripts
_container_names_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # Get list of container names from docker
    COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}')" -- $curr_arg) )
}

# Complete for the main add commands
_add_commands_to_container_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # If this is the first argument, complete with container names
    if [ ${COMP_CWORD} -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}')" -- $curr_arg) )
    elif [ ${COMP_CWORD} -eq 2 ]; then
        # For second argument, offer username suggestions
        COMPREPLY=( $(compgen -W "ubuntu root $(id -un)" -- $curr_arg) )
    fi
}

# Complete for the docker exec commands
_docker_exec_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # If this is the first argument, complete with container names
    if [ ${COMP_CWORD} -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}')" -- $curr_arg) )
    elif [ ${COMP_CWORD} -eq 2 ]; then
        # For second argument, offer command suggestions
        COMPREPLY=( $(compgen -W "help detach stop bash remove" -- $curr_arg) )
    fi
}

# Complete for container restart/fix commands
_container_management_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # Handle both arguments and options
    if [[ ${curr_arg} == -* ]]; then
        # Complete with options that start with dash
        COMPREPLY=( $(compgen -W "--name --help" -- $curr_arg) )
    elif [ ${COMP_CWORD} -gt 1 ] && [ "${COMP_WORDS[COMP_CWORD-1]}" == "--name" ]; then
        # If previous arg was --name, complete with container names
        COMPREPLY=( $(compgen -W "$(docker ps -a --format '{{.Names}}')" -- $curr_arg) )
    fi
}

# Setup keyboard shortcut for container detach
_setup_container_detach_shortcut() {
    # Setup a keyboard shortcut (Ctrl+X then d) to detach from containers
    # This will be used in addition to the 'container-detach' command
    if [[ "$TERM" != "" ]]; then
        # Only setup if we're in a terminal
        bind '"\C-xd": "container-detach\n"' 2>/dev/null || true
        # Also provide a simpler Ctrl+\ shortcut
        bind '"\C-\\": "container-detach\n"' 2>/dev/null || true
        # Direct detach command using touch marker file (bypasses container-detach command)
        bind '"\C-xq": "touch $HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested; exit\n"' 2>/dev/null || true
    fi
}

# Add completions for container commands available inside containers
_container_commands_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # Complete with available container commands
    COMPREPLY=( $(compgen -W "container-detach container-stop container-remove container-help detach stop remove help" -- $curr_arg) )
}

# Register completions

# Main container command installation scripts
complete -F _add_commands_to_container_completion add-commands-to-container.sh
complete -F _container_names_completion example-add-commands-to-yocto.sh
complete -F _container_names_completion example-add-commands-to-container.sh

# Docker exec wrappers
complete -F _docker_exec_completion docker-exec-it
complete -F _docker_exec_completion docker-exec-detached

# Container connections
complete -F _container_names_completion ros2-connect
complete -F _container_names_completion yocto-connect

# Container management scripts
complete -F _container_management_completion restart-ros2-container.sh
complete -F _container_management_completion restart-yocto-container.sh
complete -F _container_management_completion restart-vscode-container.sh
complete -F _container_management_completion fix-ros2-container.sh
complete -F _container_management_completion fix-yocto-container.sh
complete -F _container_management_completion fix-container-volumes.sh
complete -F _container_management_completion recreate-ros2-container.sh
complete -F _container_management_completion robust-ros2-container.sh
complete -F _container_management_completion robust-yocto-container.sh

# In-container completion (won't be used on host, but included for completeness)
complete -F _container_commands_completion container-detach
complete -F _container_commands_completion container-stop
complete -F _container_commands_completion container-remove
complete -F _container_commands_completion container-help
complete -F _container_commands_completion detach
complete -F _container_commands_completion stop
complete -F _container_commands_completion remove
complete -F _container_commands_completion help

# Setup keyboard shortcut for container detach
_setup_container_detach_shortcut

echo "Container command completion loaded"
