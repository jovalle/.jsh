root_dir="$(get_root_dir)"

header "Configuring environment"

# Deploy dotfiles
"$0" dotfiles

# Configure brew links
if check_brew; then
  log "Configuring Brew Links..."
  brew link --overwrite --force mpv tlrc || warn "Failed to link brew packages"
fi

if is_macos; then
  log "Configuring macOS..."
  bash "$root_dir/scripts/macos/configure-settings.sh" || warn "Failed to configure macOS settings"
  bash "$root_dir/scripts/macos/configure-dock.sh" || warn "Failed to configure dock"

  # VSCode
  if [[ -d "/Applications/Visual Studio Code.app" ]]; then
    log "Configuring VSCode..."
    vscode_user="$HOME/Library/Application Support/Code/User"
    mkdir -p "$vscode_user"
    ln -sf "$root_dir/configs/vscode/keybindings.json" "$vscode_user/keybindings.json"
    ln -sf "$root_dir/configs/vscode/settings.json" "$vscode_user/settings.json"
  fi
elif is_linux; then
  log "Configuring Linux..."
  bash "$root_dir/scripts/linux/configure-sudoers.sh" || warn "Failed to configure sudoers"
fi

success "Configuration complete"
