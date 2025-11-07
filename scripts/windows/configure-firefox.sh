#!/bin/bash
# Create symlink for Firefox user.js (requires elevation)

USER_JS_SRC="$HOME/.jsh/configs/firefox/user.js"
FF_PROFILES_DIR="/mnt/c/Users/jay/AppData/Roaming/Mozilla/Firefox/Profiles"

# Check if Firefox is installed
if [ ! -d "$FF_PROFILES_DIR" ]; then
  echo "Error: Firefox not found (check if installed)"
  exit 1
fi

echo "Configuring Firefox settings..."

# Find the default-release profile directory
FF_PROFILE_DIR=$(find "$FF_PROFILES_DIR" -type d -name "*.default-release" | head -n 1)

if [ -z "$FF_PROFILE_DIR" ]; then
  echo "Error: Could not find Firefox default-release profile"
  exit 1
fi

echo "Found Firefox profile: $FF_PROFILE_DIR"

# Convert WSL path to Windows path
USER_JS_SRC_WIN=$(wslpath -w "$USER_JS_SRC")
USER_JS_DEST=$(realpath "$FF_PROFILE_DIR/user.js")
USER_JS_DEST_WIN=$(wslpath -w "$USER_JS_DEST")

echo "Creating symlink: $USER_JS_DEST_WIN -> $USER_JS_SRC_WIN"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"New-Item -ItemType SymbolicLink -Path ''$USER_JS_DEST_WIN'' -Target ''$USER_JS_SRC_WIN'' -Force\"' -Verb RunAs -Wait"

# Validate
echo ""
echo "Validating symlink..."
LINK_INFO=$(powershell.exe -NoProfile -Command "Get-Item '$USER_JS_DEST_WIN' | Select-Object LinkType, Target | Format-List" 2>&1)
if echo "$LINK_INFO" | grep -q "SymbolicLink"; then
  echo "✓ Symlink created successfully"
  echo "$LINK_INFO"
else
  echo "✗ Error: Symlink validation failed"
  exit 1
fi
