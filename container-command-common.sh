#!/bin/bash
# container-command-common.sh
# Common library functions for container command installation
# This library provides shared functionality for both add-commands-to-container.sh and ensure-yocto-container-commands.sh

# Detect container type (ros2, yocto, generic) - Docker version
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

# Detect container type (ros2, yocto, generic) - Podman version  
detect_container_type_podman() {
    local container_name="$1"
    
    if podman exec "$container_name" bash -c "grep -q crops/poky /etc/motd 2>/dev/null || grep -q poky /etc/motd 2>/dev/null || [ -d /workdir ]" &>/dev/null; then
        echo "yocto"
    elif podman exec "$container_name" bash -c "grep -q ros /etc/motd 2>/dev/null || [ -d /opt/ros ]" &>/dev/null; then
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
export -f detect_container_type_podman
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
export -f install_container_commands_podman

# Install container commands into a Podman container
install_container_commands_podman() {
    local container_name="$1"
    local container_type="${2:-$(detect_container_type_podman "$container_name")}"
    local force_install="${3:-false}"
    
    echo "Installing container commands in Podman container '$container_name'..."
    
    # Check if container exists and is running
    if ! podman ps --format '{{.Names}}' | grep -w "^$container_name$" > /dev/null; then
        echo "Error: Container '$container_name' is not running"
        return 1
    fi
    
    # Check if commands already exist (unless forcing)
    if [ "$force_install" != "true" ]; then
        if podman exec "$container_name" bash -c "command -v container-help >/dev/null 2>&1"; then
            echo "Container commands already installed in '$container_name'"
            return 0
        fi
    fi
    
    # Create temporary directory for command installation
    local temp_dir="/tmp/container_commands_install_$$"
    mkdir -p "$temp_dir"
    
    # Create command scripts
    create_command_script "container-detach" "$(get_command_content detach)" "$temp_dir"
    create_command_script "container-stop" "$(get_command_content stop)" "$temp_dir"
    create_command_script "container-remove" "$(get_command_content remove)" "$temp_dir"
    create_command_script "container-help" "$(get_command_content help)" "$temp_dir"
    
    # Create initialization script
    create_init_script "$temp_dir" "$container_type"
    
    # Create completion script
    create_completion_script "$temp_dir"
    
    # Copy commands to container
    echo "Copying command scripts to container..."
    podman cp "$temp_dir/." "$container_name:/tmp/container_commands_staging/"
    
    # Install commands in container
    local install_script="
#!/bin/bash
set -e

echo 'Installing container commands...'

# Create target directories
mkdir -p /tmp/.container_commands
mkdir -p /usr/local/bin 2>/dev/null || true

# Copy commands from staging
cp /tmp/container_commands_staging/* /tmp/.container_commands/ 2>/dev/null || true
chmod +x /tmp/.container_commands/* 2>/dev/null || true

# Try to install in system-wide location if possible
if [ -w /usr/local/bin ]; then
    cp /tmp/.container_commands/container-* /usr/local/bin/ 2>/dev/null || true
    chmod +x /usr/local/bin/container-* 2>/dev/null || true
    echo 'Commands installed in /usr/local/bin'
else
    echo 'Commands installed in /tmp/.container_commands'
fi

# Set up PATH in shell initialization files
init_content='
# Container commands initialization
if [ -d /usr/local/bin ]; then
    export PATH=\"/usr/local/bin:\$PATH\"
fi
if [ -d /tmp/.container_commands ]; then
    export PATH=\"/tmp/.container_commands:\$PATH\"
fi
'

# Update bashrc files
for bashrc in /etc/bash.bashrc /root/.bashrc /home/*/.bashrc /etc/skel/.bashrc; do
    if [ -f \"\$bashrc\" ] && [ -w \"\$bashrc\" ]; then
        if ! grep -q 'container_commands' \"\$bashrc\"; then
            echo \"\$init_content\" >> \"\$bashrc\"
            echo \"Updated \$bashrc\"
        fi
    fi
done

# Set up profile.d if available
if [ -d /etc/profile.d ] && [ -w /etc/profile.d ]; then
    echo \"\$init_content\" > /etc/profile.d/container-commands.sh
    chmod +x /etc/profile.d/container-commands.sh
    echo 'Created /etc/profile.d/container-commands.sh'
fi

# Clean up staging
rm -rf /tmp/container_commands_staging

echo 'Container commands installation complete!'
"
    
    # Execute installation script in container
    echo "$install_script" | podman exec -i "$container_name" bash
    
    # Clean up local temporary directory
    rm -rf "$temp_dir"
    
    echo "Successfully installed container commands in '$container_name'"
    return 0
}
