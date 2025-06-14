#!/bin/bash
# Simple VS Code launcher with Podman environment
# Usage: ./vscode-with-podman.sh [path/to/workspace]

# Set up Podman environment for VS Code
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"

# Ensure Podman socket is running
systemctl --user start podman.socket 2>/dev/null || true

# Show environment info
echo "🐋 Podman environment for VS Code:"
echo "   DOCKER_HOST=$DOCKER_HOST"

# Test API connection
if curl --unix-socket "/run/user/$(id -u)/podman/podman.sock" \
   -s "http://localhost/v1.40/version" >/dev/null 2>&1; then
    echo "   ✅ Podman API accessible"
else
    echo "   ⚠️  Podman API not responding"
fi

# Show available containers
echo "📦 Available containers:"
podman ps -a --format "   {{.Names}} ({{.Status}})" 2>/dev/null || echo "   No containers found"

echo ""
echo "🚀 Launching VS Code..."

# Launch VS Code with the workspace or current directory
if [ $# -gt 0 ]; then
    exec code "$1"
else
    exec code .
fi
