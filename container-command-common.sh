#!/bin/bash
# container-command-common.sh
# Common library functions for container command installation
# This library provides shared functionality for both add-commands-to-container.sh and ensure-yocto-container-commands.sh

# Detect container type (ros2, yocto, generic)
detect_container_type() {
    local container_name="$1"
    
    if docker exec "$container_name" bash -c "grep -q crops/poky /etc/motd 2>/dev/null || grep -q poky /etc/motd 2>/dev/null || [ -d /workdir ]" &>/dev/null; then
        echo "yocto"
    elif docker exec "$container_name" bash -c "grep -q ros /etc/motd 2>/dev/null || [ -d /opt/ros ]" &>/dev/null; then
        echo "ros2"
    else
        echo "generic"
    fi
}

# Create basic container command content
get_command_content() {
    local command_type="$1"
    
    case "$command_type" in
        "detach")
            echo "echo 'Detaching from container (container keeps running)...'
echo 'Container will continue running in the background.'
touch \$HOME/.container_detach_requested 2>/dev/null || touch /workdir/.container_detach_requested 2>/dev/null || touch /tmp/.container_detach_requested
exit 0"
            ;;
        "stop")
            echo "echo 'Stopping container...'
echo 'Container will be stopped but can be started again.'
touch \$HOME/.container_stop_requested 2>/dev/null || touch /workdir/.container_stop_requested 2>/dev/null || touch /tmp/.container_stop_requested
exit 0"
            ;;
        "remove")
            echo "echo 'Removing container...'
echo 'Container will be stopped and removed permanently.'
touch \$HOME/.container_remove_requested 2>/dev/null || touch /workdir/.container_remove_requested 2>/dev/null || touch /tmp/.container_remove_requested
exit 0"
            ;;
        "help")
            echo "echo 'Container Commands:'
echo \"  - container-detach: Detach from the container (container keeps running)\"
echo \"  - container-stop: Stop the container (container will be stopped but not removed)\"
echo '  - container-remove: Stop and remove the container completely'
echo '  - container-help: Show this help message'"
            ;;
        *)
            echo "echo 'Unknown command type'"
            ;;
    esac
}

# Create a command script in a specific directory
create_command_script() {
    local command_name="$1"
    local command_content="$2"
    local target_dir="$3"
    
    # Ensure the target directory exists
    mkdir -p "$target_dir" 2>/dev/null || true
    
    # Create the command script
    echo -e "#!/bin/bash\n$command_content" > "$target_dir/$command_name"
    chmod +x "$target_dir/$command_name" 2>/dev/null || true
    
    echo "Created $command_name in $target_dir"
}

# Add PATH setup to a shell initialization file
add_path_to_init_file() {
    local init_file="$1"
    local cmd_dir="$2"
    
    if [ -f "$init_file" ] && [ -w "$init_file" ]; then
        if ! grep -q "PATH=\"$cmd_dir:\$PATH\"" "$init_file"; then
            echo "export PATH=\"$cmd_dir:\$PATH\"" >> "$init_file"
            echo "Updated PATH in $init_file"
            return 0
        else
            echo "$init_file already contains PATH setup"
            return 0
        fi
    else
        echo "Cannot modify $init_file (doesn't exist or no permission)"
        return 1
    fi
}

# Create container-init.sh script for sourcing
create_init_script() {
    local target_dir="$1"
    local container_type="$2"
    
    local init_content="#!/bin/bash
# Container commands initialization

# Add container commands to PATH
if [ -d \"\$HOME/bin\" ]; then
    export PATH=\"\$HOME/bin:\$PATH\"
fi

if [ -d \"/usr/local/bin\" ]; then
    export PATH=\"/usr/local/bin:\$PATH\"
fi

if [ -d \"/tmp/container-commands\" ]; then
    export PATH=\"/tmp/container-commands:\$PATH\"
fi

if [ -d \"/tmp/.container_commands\" ]; then
    export PATH=\"/tmp/.container_commands:\$PATH\"
fi"

    # Add Yocto-specific paths if needed
    if [ "$container_type" = "yocto" ]; then
        init_content+="

if [ -d \"/workdir/.container_commands\" ]; then
    export PATH=\"/workdir/.container_commands:\$PATH\"
fi"
    fi
    
    # Add help display
    init_content+="

# Show help if in interactive shell
if [ -t 0 ]; then
    if command -v container-help >/dev/null 2>&1; then
        container-help
    fi
fi"
    
    # Create the init script
    echo "$init_content" > "$target_dir/container-init.sh"
    chmod +x "$target_dir/container-init.sh" 2>/dev/null || true
    
    echo "Created initialization script in $target_dir"
}

# Create system-wide profile.d script
create_profile_script() {
    local script_content="$1"
    
    # Try to create a profile.d script
    if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
        echo "$script_content" > /etc/profile.d/container-init.sh
        chmod +x /etc/profile.d/container-init.sh 2>/dev/null || true
        echo "Created system-wide profile script"
        return 0
    else
        echo "Cannot create system-wide profile script (no permissions)"
        return 1
    fi
}

# Create container initialization logic
get_shell_init_content() {
    echo "
# Container commands initialization
if [ -f /tmp/container-commands/container-init.sh ]; then
    source /tmp/container-commands/container-init.sh
elif [ -f /tmp/.container_commands/container-init.sh ]; then
    source /tmp/.container_commands/container-init.sh
elif [ -f /workdir/.container_commands/container-init.sh ]; then
    source /workdir/.container_commands/container-init.sh
fi"
}

# Update system bashrc file
update_system_bashrc() {
    local init_content="$1"
    
    if [ -f /etc/bash.bashrc ] && [ -w /etc/bash.bashrc ]; then
        if ! grep -q "container-init.sh" /etc/bash.bashrc; then
            echo "$init_content" >> /etc/bash.bashrc
            echo "Updated /etc/bash.bashrc"
            return 0
        else
            echo "/etc/bash.bashrc already contains container initialization"
            return 0
        fi
    else
        echo "Cannot modify /etc/bash.bashrc (no permission)"
        return 1
    fi
}

# Update user bashrc files
update_user_bashrc_files() {
    local init_content="$1"
    local update_count=0
    
    # Get root home directory
    ROOT_HOME=$(getent passwd root | cut -d: -f6 2>/dev/null)
    if [ -z "$ROOT_HOME" ]; then
        ROOT_HOME="/root"  # Default if detection fails
    fi
    
    # Update root bashrc
    if [ -f "$ROOT_HOME/.bashrc" ] && [ -w "$ROOT_HOME/.bashrc" ]; then
        if ! grep -q "container-init.sh" "$ROOT_HOME/.bashrc"; then
            echo "$init_content" >> "$ROOT_HOME/.bashrc"
            echo "Updated root's .bashrc"
            ((update_count++))
        fi
    fi
    
    # Update other user bashrc files
    for bashrc in /home/*/.bashrc; do
        if [ -f "$bashrc" ] && [ -w "$bashrc" ]; then
            if ! grep -q "container-init.sh" "$bashrc"; then
                echo "$init_content" >> "$bashrc"
                echo "Updated $bashrc"
                ((update_count++))
            fi
        fi
    done
    
    # Update skeleton bashrc for future users
    if [ -f /etc/skel/.bashrc ] && [ -w /etc/skel/.bashrc ]; then
        if ! grep -q "container-init.sh" /etc/skel/.bashrc; then
            echo "$init_content" >> /etc/skel/.bashrc
            echo "Updated skeleton .bashrc"
            ((update_count++))
        fi
    fi
    
    return $update_count
}

# Create system-wide symlinks
create_system_symlinks() {
    local source_dir="$1"
    local success=0
    
    # Try to create symlinks in /usr/local/bin
    if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
        ln -sf "$source_dir/container-detach" /usr/local/bin/container-detach 2>/dev/null
        ln -sf "$source_dir/container-stop" /usr/local/bin/container-stop 2>/dev/null
        ln -sf "$source_dir/container-remove" /usr/local/bin/container-remove 2>/dev/null
        ln -sf "$source_dir/container-help" /usr/local/bin/container-help 2>/dev/null
        echo "Created symlinks in /usr/local/bin"
        success=1
    fi
    
    # Try to create symlinks in /workdir bin (for Yocto)
    if [ -d /workdir ] && [ -w /workdir ]; then
        mkdir -p /workdir/.container_commands 2>/dev/null || true
        ln -sf "$source_dir/container-detach" /workdir/.container_commands/container-detach 2>/dev/null
        ln -sf "$source_dir/container-stop" /workdir/.container_commands/container-stop 2>/dev/null
        ln -sf "$source_dir/container-remove" /workdir/.container_commands/container-remove 2>/dev/null
        ln -sf "$source_dir/container-help" /workdir/.container_commands/container-help 2>/dev/null
        echo "Created symlinks in /workdir/.container_commands"
        success=1
    fi
    
    return $success
}

# Create completion script for container commands
create_completion_script() {
    local target_dir="$1"
    
    cat > "$target_dir/container-completion.sh" << 'EOC'
#!/bin/bash
# Bash completion for container commands

# Complete for container commands
_container_commands_completion() {
    local curr_arg;
    curr_arg="${COMP_WORDS[COMP_CWORD]}"
    
    # Complete with available container commands
    COMPREPLY=( $(compgen -W "container-detach container-stop container-remove container-help" -- $curr_arg) )
}

# Register completions
complete -F _container_commands_completion container-detach
complete -F _container_commands_completion container-stop
complete -F _container_commands_completion container-remove
complete -F _container_commands_completion container-help
EOC

    chmod +x "$target_dir/container-completion.sh" 2>/dev/null || true
    echo "Created completion script in $target_dir"
}

# Create welcome script for Yocto containers
create_yocto_welcome_script() {
    cat > /tmp/yocto-welcome.sh << 'EOF'
#!/bin/bash
# This script is run when connecting to the Yocto container

# Ensure container commands are in PATH
if [ -d "/usr/local/bin" ]; then
    export PATH="/usr/local/bin:$PATH"
fi

if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi

if [ -d "/workdir/.container_commands" ]; then
    export PATH="/workdir/.container_commands:$PATH"
fi

if [ -d "/tmp/.container_commands" ]; then
    export PATH="/tmp/.container_commands:$PATH"
fi

if [ -d "/tmp/container-commands" ]; then
    export PATH="/tmp/container-commands:$PATH"
fi

# Show welcome message
echo "Welcome to the Yocto Container!"
echo "Container commands available:"
echo "  - container-help: Show all available commands"
echo "  - container-detach: Detach from container (keeps running)"
echo "  - container-stop: Stop the container"
echo "  - container-remove: Stop and remove the container"
echo ""

# Run container-help if available
if command -v container-help >/dev/null 2>&1; then
    container-help
else
    echo "Warning: container commands not in PATH. You can run them directly:"
    echo "  - /tmp/.container_commands/container-help"
    echo "  - /tmp/.container_commands/container-detach"
    echo "  - /tmp/.container_commands/container-stop"
    echo "  - /tmp/.container_commands/container-remove"
fi

# Start an interactive shell
exec bash
EOF

    chmod +x /tmp/yocto-welcome.sh
    echo "Created Yocto welcome script"
}

# Export all functions
export -f detect_container_type
export -f get_command_content
export -f create_command_script
export -f add_path_to_init_file
export -f create_init_script
export -f create_profile_script
export -f get_shell_init_content
export -f update_system_bashrc
export -f update_user_bashrc_files
export -f create_system_symlinks
export -f create_completion_script
export -f create_yocto_welcome_script
