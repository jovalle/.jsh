root_dir="$(get_root_dir)"

# Source required libraries
# shellcheck source=src/lib/tui.sh
[[ -f "$root_dir/src/lib/tui.sh" ]] && source "$root_dir/src/lib/tui.sh"
# shellcheck source=src/lib/brew.sh
[[ -f "$root_dir/src/lib/brew.sh" ]] && source "$root_dir/src/lib/brew.sh"

# Check flags (bashly populates ${args[--flag]})
use_tui=true
if [[ -n "${args[--no-progress]:-}" ]] || [[ -n "${args[--quiet]:-}" ]]; then
  use_tui=false
fi

# Initialize TUI if available and enabled
if [[ "$use_tui" == "true" ]] && declare -f tui_init &>/dev/null; then
  tui_init || use_tui=false
fi

# Helper function for TUI-aware logging
_upgrade_log() {
  if [[ "$use_tui" == "true" ]] && declare -f tui_log &>/dev/null; then
    tui_log "$@"
  else
    log "$@"
  fi
}

_upgrade_success() {
  if [[ "$use_tui" == "true" ]] && declare -f tui_success &>/dev/null; then
    tui_success "$@"
  else
    success "$@"
  fi
}

# Update zinit if present
if command -v zsh &> /dev/null; then
  if [[ "$use_tui" == "true" ]] && declare -f tui_run_animated &>/dev/null; then
    tui_progress_start "Updating zinit" 0
    tui_progress_update 0 "cleaning"
    tui_run_animated "zsh -c 'source ~/.zshrc && zinit delete --clean' 2>/dev/null" || true
    tui_progress_update 0 "self-update"
    tui_run_animated "zsh -c 'source ~/.zshrc && zinit self-update' 2>/dev/null" || true
    tui_progress_update 0 "updating plugins"
    tui_run_animated "zsh -c 'source ~/.zshrc && zinit update --all' 2>/dev/null" || true
    tui_progress_complete "Zinit updated"
  else
    log "Cleaning zinit..."
    zsh -ic 'zinit delete --clean' 2> /dev/null || true
    log "Updating zinit..."
    zsh -ic 'zinit self-update' 2> /dev/null || true
    zsh -ic 'zinit update --all' 2> /dev/null || true
  fi
fi

# Update TPM and tmux plugins if present
tpm_home="${HOME}/.tmux/plugins/tpm"
if [[ -d "$tpm_home" ]]; then
  if [[ "$use_tui" == "true" ]] && declare -f tui_run_animated &>/dev/null; then
    tui_progress_start "Updating TPM" 0
    tui_progress_update 0 "pulling latest"
    tui_run_animated "git -C '$tpm_home' pull" || true
    tui_progress_update 0 "updating plugins"
    tui_run_animated "'$tpm_home/bin/update_plugins' all" || true
    tui_progress_complete "TPM updated"
  else
    log "Updating TPM..."
    git -C "$tpm_home" pull || true
    log "Updating tmux plugins..."
    "$tpm_home/bin/update_plugins" all 2>/dev/null || true
  fi
fi

if is_macos; then
  if command -v brew &> /dev/null; then
    if [[ "$use_tui" == "true" ]] && declare -f brew_upgrade_with_tui &>/dev/null; then
      brew_upgrade_with_tui
    else
      log "Upgrading Homebrew packages..."
      brew update && brew upgrade
    fi
  fi
  if command -v mas &> /dev/null; then
    if [[ "$use_tui" == "true" ]] && declare -f tui_run_animated &>/dev/null; then
      tui_progress_start "Upgrading Mac App Store" 0
      tui_run_animated "mas upgrade"
      tui_progress_complete "App Store updated"
    else
      log "Upgrading Mac App Store apps..."
      mas upgrade
    fi
  fi
elif is_linux; then
  if [[ "$use_tui" == "true" ]] && declare -f tui_run_animated &>/dev/null; then
    tui_progress_start "Upgrading system packages" 0
    tui_run_animated "upgrade_packages"
    tui_progress_complete "System packages updated"
  else
    log "Upgrading packages..."
    upgrade_packages
  fi
  if command -v brew &> /dev/null; then
    if [[ "$use_tui" == "true" ]] && declare -f brew_upgrade_with_tui &>/dev/null; then
      brew_upgrade_with_tui
    else
      log "Upgrading Homebrew packages..."
      brew update && brew upgrade
    fi
  fi
fi

# Upgrade npm/bun packages from config
npm_packages=()
if [[ -f "$root_dir/configs/npm.json" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && npm_packages+=("$line")
  done < <(load_packages_from_json "$root_dir/configs/npm.json")
fi

if [[ ${#npm_packages[@]} -gt 0 ]]; then
  # Prefer bun if available, fall back to npm
  if command -v bun &>/dev/null; then
    pkg_cmd="bun"
    pkg_install="bun install -g"
  elif command -v npm &>/dev/null; then
    pkg_cmd="npm"
    pkg_install="npm install -g"
  else
    pkg_cmd=""
  fi

  if [[ -n "$pkg_cmd" ]]; then
    if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
      tui_progress_start "Upgrading $pkg_cmd packages" "${#npm_packages[@]}"
      for pkg in "${npm_packages[@]}"; do
        tui_progress_next "$pkg"
        $pkg_install "$pkg" || warn "Failed to upgrade $pkg"
      done
      tui_progress_complete "${pkg_cmd^} packages updated"
    else
      log "Upgrading $pkg_cmd packages..."
      for pkg in "${npm_packages[@]}"; do
        $pkg_install "$pkg" || warn "Failed to upgrade $pkg"
      done
    fi
  fi
fi

# Upgrade cargo packages from config
if command -v cargo &>/dev/null && [[ -f "$root_dir/configs/cargo.json" ]]; then
  # Count cargo packages
  cargo_count=0
  if command -v jq &>/dev/null; then
    cargo_count=$(jq 'length' "$root_dir/configs/cargo.json" 2>/dev/null || echo 0)
  fi

  if [[ "$cargo_count" -gt 0 ]]; then
    if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
      tui_progress_start "Upgrading cargo packages" "$cargo_count"

      while IFS= read -r pkg_json; do
        [[ -z "$pkg_json" ]] && continue

        git_url=$(echo "$pkg_json" | jq -r '.git // empty')
        features=$(echo "$pkg_json" | jq -r '.features // [] | join(",")')

        if [[ -n "$git_url" ]]; then
          pkg_name=$(basename "$git_url" .git)
          tui_progress_next "$pkg_name"

          install_cmd="cargo install --force --git $git_url"
          [[ -n "$features" ]] && install_cmd+=" --features $features"

          eval "$install_cmd" || warn "Failed to upgrade $pkg_name"
        fi
      done < <(jq -c '.[]' "$root_dir/configs/cargo.json" 2>/dev/null)

      tui_progress_complete "Cargo packages updated"
    else
      log "Upgrading cargo packages..."
      while IFS= read -r pkg_json; do
        [[ -z "$pkg_json" ]] && continue

        git_url=$(echo "$pkg_json" | jq -r '.git // empty')
        features=$(echo "$pkg_json" | jq -r '.features // [] | join(",")')

        if [[ -n "$git_url" ]]; then
          install_cmd="cargo install --force --git $git_url"
          [[ -n "$features" ]] && install_cmd+=" --features $features"

          eval "$install_cmd" || warn "Failed to upgrade from $git_url"
        fi
      done < <(jq -c '.[]' "$root_dir/configs/cargo.json" 2>/dev/null)
    fi
  fi
fi

# Cleanup TUI
if [[ "$use_tui" == "true" ]] && declare -f tui_cleanup &>/dev/null; then
  tui_cleanup
fi

success "Upgrade complete"
