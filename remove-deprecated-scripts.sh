#!/bin/bash
# Script to safely remove unused container run scripts

# Create a backup directory
BACKUP_DIR="/home/sad/projects/ansible/iac-scripts/deprecated_scripts_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR_WITH_TIMESTAMP="${BACKUP_DIR}_${TIMESTAMP}"

# Define colors for better visibility
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Creating backup directory: ${BACKUP_DIR_WITH_TIMESTAMP}${NC}"
mkdir -p "$BACKUP_DIR_WITH_TIMESTAMP"

# Files to be removed
FILES_TO_REMOVE=(
  "/home/sad/projects/ansible/iac-scripts/run-ros2-container.sh"
  "/home/sad/projects/ansible/iac-scripts/run-yocto-container.sh"
)

# Backup and remove each file
for file in "${FILES_TO_REMOVE[@]}"; do
  if [ -f "$file" ]; then
    echo -e "${YELLOW}Backing up:${NC} $file"
    cp "$file" "$BACKUP_DIR_WITH_TIMESTAMP/"
    echo -e "${GREEN}Removing:${NC} $file"
    rm "$file"
  else
    echo "File not found: $file"
  fi
done

echo -e "\n${GREEN}Done!${NC}"
echo "The following files have been backed up to ${BACKUP_DIR_WITH_TIMESTAMP} and removed:"
for file in "${FILES_TO_REMOVE[@]}"; do
  echo "- $(basename "$file")"
done
echo ""
echo "If you need to restore these files, you can find them in the backup directory."
