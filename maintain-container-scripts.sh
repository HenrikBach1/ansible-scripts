#!/bin/bash
# Maintenance script for cleaning up and verifying container setup
# This script removes old/temporary files and verifies container configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Bold formatting for sections
bold=$(tput bold)
normal=$(tput sgr0)

print_section() {
    echo
    echo "${bold}$1${normal}"
    echo "--------------------------------------------------------------"
}

# Function to check if a container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -w "^$1$" > /dev/null
}

# Function to check if a container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -w "^$1$" > /dev/null
}

# Parse command line arguments
VERIFY_ONLY=0
CLEANUP_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify-only)
            VERIFY_ONLY=1
            shift
            ;;
        --cleanup-only)
            CLEANUP_ONLY=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--verify-only] [--cleanup-only]"
            exit 1
            ;;
    esac
done

if [[ $CLEANUP_ONLY -eq 0 ]]; then
    # Verification section
    print_section "Checking for running containers"
    
    CONTAINERS=$(docker ps --format '{{.Names}}')
    if [ -z "$CONTAINERS" ]; then
        echo "No running containers found."
    else
        echo "Running containers:"
        echo "$CONTAINERS"
        
        # Prompt for container verification
        echo
        echo "Would you like to verify the configuration of these containers? (y/n)"
        read -r verify_choice
        
        if [[ "$verify_choice" =~ ^[Yy]$ ]]; then
            for container in $CONTAINERS; do
                echo
                echo "Verifying container: $container"
                
                if [[ "$container" == *"ros2"* ]]; then
                    ./start-ros2-container.sh --verify "$container"
                elif [[ "$container" == *"yocto"* ]]; then
                    ./start-yocto-container.sh --verify "$container"
                else
                    echo "Unknown container type. Using generic verification."
                    source ./run-container-common.sh
                    verify_container "$container"
                fi
            done
        fi
    fi
fi

if [[ $VERIFY_ONLY -eq 0 ]]; then
    # Cleanup section
    print_section "Cleaning up temporary and backup files"
    
    # Find and list backup files
    BACKUP_FILES=$(find . -name "*.bak*" -o -name "*~" -o -name "*.old" -o -name "*.orig")
    
    if [ -n "$BACKUP_FILES" ]; then
        echo "Found backup files:"
        echo "$BACKUP_FILES"
        
        echo
        echo "Would you like to remove these backup files? (y/n)"
        read -r remove_choice
        
        if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
            find . -name "*.bak*" -o -name "*~" -o -name "*.old" -o -name "*.orig" -exec rm -v {} \;
            echo "Backup files removed."
        fi
    else
        echo "No backup files found."
    fi
    
    # Find and list fix-* scripts
    FIX_SCRIPTS=$(find . -name "fix-*.sh" -not -name "fix-container-volumes.sh" -not -name "fix-ros2-container.sh" -not -name "fix-yocto-container-volumes.sh" -not -name "fix-projects-path.sh")
    
    if [ -n "$FIX_SCRIPTS" ]; then
        echo
        echo "Found temporary fix scripts:"
        echo "$FIX_SCRIPTS"
        
        echo
        echo "Would you like to remove these temporary fix scripts? (y/n)"
        read -r remove_scripts_choice
        
        if [[ "$remove_scripts_choice" =~ ^[Yy]$ ]]; then
            find . -name "fix-*.sh" -not -name "fix-container-volumes.sh" -not -name "fix-ros2-container.sh" -not -name "fix-yocto-container-volumes.sh" -not -name "fix-projects-path.sh" -exec rm -v {} \;
            echo "Temporary fix scripts removed."
        fi
    else
        echo
        echo "No temporary fix scripts found."
    fi
    
    # Check for example scripts
    EXAMPLE_SCRIPTS=$(find . -name "example-*.sh" -not -name "example-add-commands-to-container.sh")
    
    if [ -n "$EXAMPLE_SCRIPTS" ]; then
        echo
        echo "Found example scripts:"
        echo "$EXAMPLE_SCRIPTS"
        
        echo
        echo "Would you like to remove these example scripts? (y/n)"
        read -r remove_examples_choice
        
        if [[ "$remove_examples_choice" =~ ^[Yy]$ ]]; then
            find . -name "example-*.sh" -not -name "example-add-commands-to-container.sh" -exec rm -v {} \;
            echo "Example scripts removed."
        fi
    else
        echo
        echo "No example scripts found."
    fi
    
    # Check for deprecated scripts
    if [ -d "deprecated_scripts" ]; then
        echo
        echo "Found deprecated_scripts directory."
        
        DEPRECATED_FILES=$(find deprecated_scripts -type f)
        if [ -n "$DEPRECATED_FILES" ]; then
            echo "Directory contains:"
            ls -la deprecated_scripts/
            
            echo
            echo "Would you like to remove the deprecated_scripts directory? (y/n)"
            read -r remove_deprecated_choice
            
            if [[ "$remove_deprecated_choice" =~ ^[Yy]$ ]]; then
                rm -rf deprecated_scripts/
                echo "Deprecated scripts directory removed."
            fi
        else
            echo "Deprecated scripts directory is empty."
            rm -rf deprecated_scripts/
            echo "Removed empty deprecated_scripts directory."
        fi
    else
        echo
        echo "No deprecated_scripts directory found."
    fi
fi

print_section "Maintenance complete"
echo "To verify container setup anytime, use:"
echo "./start-ros2-container.sh --verify [CONTAINER_NAME]"
echo "./start-yocto-container.sh --verify [CONTAINER_NAME]"
echo "./verify-container.sh [CONTAINER_NAME]"
echo
echo "For more information on container commands and configuration,"
echo "please see CONTAINER_COMMANDS.md"
