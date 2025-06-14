#!/bin/bash
# VS Code Podman Integration Setup Script
# This script configures VS Code to work with Podman containers

file=setup-vscode-podman.sh
echo "Running script: $file"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "Setting up VS Code integration with Podman..."

# 1. Ensure Podman socket is running
log_info "Configuring Podman socket service..."
systemctl --user is-active --quiet podman.socket || {
    log_info "Starting Podman socket..."
    systemctl --user start podman.socket
}

systemctl --user is-enabled --quiet podman.socket || {
    log_info "Enabling Podman socket..."
    systemctl --user enable podman.socket >/dev/null 2>&1
}

# 2. Set up environment variable
PODMAN_SOCKET_PATH="unix:///run/user/$(id -u)/podman/podman.sock"

if ! grep -q "DOCKER_HOST.*podman.sock" ~/.bashrc 2>/dev/null; then
    log_info "Adding DOCKER_HOST environment variable to ~/.bashrc..."
    echo "" >> ~/.bashrc
    echo "# Podman Docker compatibility for VS Code Remote-Containers" >> ~/.bashrc
    echo "export DOCKER_HOST=\"$PODMAN_SOCKET_PATH\"" >> ~/.bashrc
    log_success "Environment variable added to ~/.bashrc"
else
    log_info "DOCKER_HOST environment variable already configured"
fi

# 3. Configure VS Code settings
VSCODE_SETTINGS_DIR="$HOME/.config/Code/User"
VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_DIR/settings.json"

if [ -f "$VSCODE_SETTINGS_FILE" ]; then
    log_info "Updating VS Code settings for Podman integration..."
    
    # Check if docker.host is already configured
    if grep -q '"docker.host"' "$VSCODE_SETTINGS_FILE"; then
        log_info "VS Code docker.host already configured"
    else
        log_info "Adding Podman configuration to VS Code settings..."
        # Remove the closing brace, add our settings, then add closing brace back
        sed -i '$s/}$//' "$VSCODE_SETTINGS_FILE"
        echo '    ,' >> "$VSCODE_SETTINGS_FILE"
        echo '    "docker.host": "unix:///run/user/'$(id -u)'/podman/podman.sock",' >> "$VSCODE_SETTINGS_FILE"
        echo '    "dev.containers.dockerPath": "podman"' >> "$VSCODE_SETTINGS_FILE"
        echo '}' >> "$VSCODE_SETTINGS_FILE"
        log_success "VS Code settings updated"
    fi
else
    log_warn "VS Code settings.json not found at $VSCODE_SETTINGS_FILE"
    log_info "Creating basic VS Code settings with Podman configuration..."
    mkdir -p "$VSCODE_SETTINGS_DIR"
    cat > "$VSCODE_SETTINGS_FILE" << EOF
{
    "docker.host": "unix:///run/user/$(id -u)/podman/podman.sock",
    "dev.containers.dockerPath": "podman"
}
EOF
    log_success "VS Code settings created"
fi

# 4. Export for current session
export DOCKER_HOST="$PODMAN_SOCKET_PATH"

log_success "VS Code Podman integration setup complete!"
echo ""
echo "Next steps:"
echo "1. Restart VS Code (or reload the window)"
echo "2. Install 'Dev Containers' extension if not already installed"
echo "3. Use Ctrl+Shift+P -> 'Dev Containers: Attach to Running Container...'"
echo "4. Select your Podman container from the list"
echo ""
echo "Environment variable for current session:"
echo "  DOCKER_HOST=$DOCKER_HOST"
echo ""
echo "To test the socket connection:"
echo "  curl --unix-socket $PODMAN_SOCKET_PATH http://localhost/v1.40/containers/json"
