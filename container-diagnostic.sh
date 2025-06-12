#!/bin/bash
# Diagnostic script for container shell and PATH issues

echo "=== Container Environment Diagnostic ==="
echo "Shell: $SHELL"
echo "Current user: $(whoami)"
echo "HOME directory: $HOME"
echo "Current PATH: $PATH"
echo ""

echo "=== Container Commands Availability ==="
# Check for container commands in PATH
for cmd in container-help container-detach container-stop container-remove; do
  if command -v $cmd >/dev/null 2>&1; then
    echo "✓ $cmd is in PATH"
  else
    echo "✗ $cmd is NOT in PATH"
  fi
done
echo ""

echo "=== Shell Configuration Files ==="
# Check .bashrc
if [ -f "$HOME/.bashrc" ]; then
  echo "User .bashrc exists"
  if grep -q "/tmp/.container_commands" "$HOME/.bashrc"; then
    echo "✓ .bashrc includes /tmp/.container_commands in PATH"
  else
    echo "✗ .bashrc does NOT include /tmp/.container_commands in PATH"
  fi
else
  echo "✗ User .bashrc does not exist"
fi

# Check profile.d
if [ -d "/etc/profile.d" ]; then
  echo "profile.d directory exists"
  if ls /etc/profile.d/*container* 2>/dev/null; then
    echo "✓ Container-related files found in profile.d"
  else
    echo "✗ No container-related files found in profile.d"
  fi
else
  echo "✗ profile.d directory does not exist"
fi
echo ""

echo "=== Container Files Check ==="
# Check for command files
for dir in /tmp/.container_commands /home/*/bin /usr/local/bin /workdir/.container_commands; do
  if [ -d "$dir" ]; then
    echo "Directory $dir exists"
    for cmd in container-help container-detach container-stop container-remove; do
      if [ -f "$dir/$cmd" ]; then
        echo "✓ $cmd exists in $dir"
      fi
    done
  fi
done
echo ""

echo "=== Command Library Check ==="
# Check for command library
for file in container-command-common.sh container-command-lib.sh; do
  for dir in /tmp /usr/local/share /workdir; do
    if [ -f "$dir/$file" ]; then
      echo "✓ $file found in $dir"
    fi
  done
done
