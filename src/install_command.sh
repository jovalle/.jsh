# jsh install - Package installation command
#
# Usage:
#   jsh install                  - Install all packages from config files
#   jsh install <package>        - Install a single package (auto-detect package manager)
#   jsh install <package> --brew - Install via specific package manager
#
# Behavior:
#   - Single package: Uses Homebrew/Linuxbrew by default, or specified package manager
#   - Bulk install: Uses config JSONs (system package managers + brew formulae)
#   - Root delegation: When running as root, delegates brew commands to BREW_USER
#
# Environment Variables:
#   - BREW_USER: User to run Homebrew as when executing as root (loaded from .env)

root_dir="$(get_root_dir)"
package="${args[package]:-}"

# Source TUI library if available
# shellcheck source=src/lib/tui.sh
[[ -f "$root_dir/src/lib/tui.sh" ]] && source "$root_dir/src/lib/tui.sh"

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
_install_log() {
  if [[ "$use_tui" == "true" ]] && declare -f tui_log &>/dev/null; then
    tui_log "$@"
  else
    log "$@"
  fi
}

_install_success() {
  if [[ "$use_tui" == "true" ]] && declare -f tui_success &>/dev/null; then
    tui_success "$@"
  else
    success "$@"
  fi
}

# Determine which package manager to use based on flags
detect_package_manager() {
  [[ "${args[--brew]}" ]] && echo "brew" && return
  [[ "${args[--gem]}" ]] && echo "gem" && return
  [[ "${args[--bun]}" ]] && echo "bun" && return
  [[ "${args[--npm]}" ]] && echo "npm" && return
  [[ "${args[--pip]}" ]] && echo "pip" && return
  [[ "${args[--cargo]}" ]] && echo "cargo" && return
  [[ "${args[--apt]}" ]] && echo "apt" && return
  [[ "${args[--dnf]}" ]] && echo "dnf" && return
  [[ "${args[--pacman]}" ]] && echo "pacman" && return
  [[ "${args[--yum]}" ]] && echo "yum" && return
  [[ "${args[--zypper]}" ]] && echo "zypper" && return
  echo "auto"
}

# Install a package via specified package manager
install_via_package_manager() {
  local pkg="$1"
  local pm="$2"

  case "$pm" in
    brew)
      if is_macos; then
        # Try cask first, then formula
        if brew_cmd install --cask "$pkg" 2>/dev/null; then
          success "Installed cask: $pkg"
          add_package_to_json "$root_dir/configs/macos/casks.json" "$pkg"
          return 0
        elif brew_cmd install "$pkg" 2>/dev/null; then
          success "Installed formula: $pkg"
          add_package_to_json "$root_dir/configs/macos/formulae.json" "$pkg"
          return 0
        fi
      else
        if brew_cmd install "$pkg" 2>/dev/null; then
          success "Installed via brew: $pkg"
          add_package_to_json "$root_dir/configs/linux/formulae.json" "$pkg"
          return 0
        fi
      fi
      return 1
      ;;
    gem)
      if command -v gem &>/dev/null; then
        gem install "$pkg" && success "Installed gem: $pkg" && return 0
      else
        error "gem not found. Install Ruby first."
      fi
      return 1
      ;;
    bun)
      if command -v bun &>/dev/null; then
        if bun install -g "$pkg"; then
          success "Installed bun package: $pkg"
          add_package_to_json "$root_dir/configs/npm.json" "$pkg"
          return 0
        fi
      else
        error "bun not found. Install from https://bun.sh"
      fi
      return 1
      ;;
    npm)
      if command -v npm &>/dev/null; then
        if npm install -g "$pkg"; then
          success "Installed npm package: $pkg"
          add_package_to_json "$root_dir/configs/npm.json" "$pkg"
          return 0
        fi
      else
        error "npm not found. Install Node.js first."
      fi
      return 1
      ;;
    pip)
      if command -v pip3 &>/dev/null; then
        pip3 install --user "$pkg" && success "Installed pip package: $pkg" && return 0
      elif command -v pip &>/dev/null; then
        pip install --user "$pkg" && success "Installed pip package: $pkg" && return 0
      else
        error "pip not found. Install Python first."
      fi
      return 1
      ;;
    cargo)
      if command -v cargo &>/dev/null; then
        cargo install "$pkg" && success "Installed cargo package: $pkg" && return 0
      else
        error "cargo not found. Install Rust first."
      fi
      return 1
      ;;
    apt)
      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y "$pkg" && success "Installed apt package: $pkg" && return 0
      else
        error "apt-get not found."
      fi
      return 1
      ;;
    dnf)
      if command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg" && success "Installed dnf package: $pkg" && return 0
      else
        error "dnf not found."
      fi
      return 1
      ;;
    pacman)
      if command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm "$pkg" && success "Installed pacman package: $pkg" && return 0
      else
        error "pacman not found."
      fi
      return 1
      ;;
    yum)
      if command -v yum &>/dev/null; then
        sudo yum install -y "$pkg" && success "Installed yum package: $pkg" && return 0
      else
        error "yum not found."
      fi
      return 1
      ;;
    zypper)
      if command -v zypper &>/dev/null; then
        sudo zypper install -y "$pkg" && success "Installed zypper package: $pkg" && return 0
      else
        error "zypper not found."
      fi
      return 1
      ;;
    *)
      error "Unknown package manager: $pm"
      return 1
      ;;
  esac
}

if [[ -z "$package" ]]; then
  # Install all packages from config (brew + system packages)
  header "Installing packages"

  if is_linux; then
    # Install Linux system packages from config
    # Note: These are managed via system package managers (apt, dnf, pacman)
    _install_log "Updating package cache..."
    update_package_cache

    # Determine package manager
    packages=()
    if command -v apt-get &> /dev/null; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && packages+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/linux/apt.json")
    elif command -v dnf &> /dev/null; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && packages+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/linux/dnf.json")
    elif command -v pacman &> /dev/null; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && packages+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/linux/pacman.json")
    fi

    if [[ ${#packages[@]} -gt 0 ]]; then
      if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
        tui_progress_start "Installing system packages" "${#packages[@]}"
        local i=0
        for pkg in "${packages[@]}"; do
          ((i++))
          tui_progress_next "$pkg"
          install_package "$pkg" || warn "Failed to install $pkg"
        done
        tui_progress_complete "System packages installed"
      else
        for pkg in "${packages[@]}"; do
          install_package "$pkg" || warn "Failed to install $pkg"
        done
      fi
    fi
  fi

  if is_macos && check_brew; then
    # Install casks
    casks=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && casks+=("$line")
    done < <(load_packages_from_json "$root_dir/configs/macos/casks.json")

    if [[ ${#casks[@]} -gt 0 ]]; then
      if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
        tui_progress_start "Installing casks" "${#casks[@]}"
        local i=0
        for cask in "${casks[@]}"; do
          ((i++))
          tui_progress_next "$cask"
          brew install --force --cask "$cask" || warn "Failed to install cask: $cask"
        done
        tui_progress_complete "Casks installed"
      else
        _install_log "Installing Casks..."
        for cask in "${casks[@]}"; do
          brew install --force --cask "$cask" || warn "Failed to install cask: $cask"
        done
      fi
    fi
  fi

  if check_brew; then
    # Install formulae
    formulae=()
    if is_macos; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && formulae+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/macos/formulae.json")
    else
      while IFS= read -r line; do
        [[ -n "$line" ]] && formulae+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/linux/formulae.json")
    fi

    if [[ ${#formulae[@]} -gt 0 ]]; then
      if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
        tui_progress_start "Installing formulae" "${#formulae[@]}"
        local i=0
        for formula in "${formulae[@]}"; do
          ((i++))
          tui_progress_next "$formula"
          brew install --force "$formula" || warn "Failed to install formula: $formula"
        done
        tui_progress_complete "Formulae installed"
      else
        _install_log "Installing Formulae..."
        for formula in "${formulae[@]}"; do
          brew install --force "$formula" || warn "Failed to install formula: $formula"
        done
      fi
    fi

    # Start services
    services=()
    if is_macos; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && services+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/macos/services.json")
    else
      while IFS= read -r line; do
        [[ -n "$line" ]] && services+=("$line")
      done < <(load_packages_from_json "$root_dir/configs/linux/services.json")
    fi

    if [[ ${#services[@]} -gt 0 ]]; then
      if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
        tui_progress_start "Starting services" "${#services[@]}"
        local i=0
        for svc in "${services[@]}"; do
          ((i++))
          tui_progress_next "$svc"
          brew services start "$svc" || warn "Failed to start service: $svc"
        done
        tui_progress_complete "Services started"
      else
        _install_log "Starting Services..."
        for svc in "${services[@]}"; do
          brew services start "$svc" || warn "Failed to start service: $svc"
        done
      fi
    fi
  fi

  # Install npm/bun packages from config
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
        tui_progress_start "Installing $pkg_cmd packages" "${#npm_packages[@]}"
        for pkg in "${npm_packages[@]}"; do
          tui_progress_next "$pkg"
          $pkg_install "$pkg" || warn "Failed to install $pkg"
        done
        tui_progress_complete "${pkg_cmd^} packages installed"
      else
        _install_log "Installing $pkg_cmd packages..."
        for pkg in "${npm_packages[@]}"; do
          $pkg_install "$pkg" || warn "Failed to install $pkg"
        done
      fi
    fi
  fi

  # Install cargo packages from config
  if command -v cargo &>/dev/null && [[ -f "$root_dir/configs/cargo.json" ]]; then
    # Count cargo packages
    local cargo_count=0
    if command -v jq &>/dev/null; then
      cargo_count=$(jq 'length' "$root_dir/configs/cargo.json" 2>/dev/null || echo 0)
    fi

    if [[ "$cargo_count" -gt 0 ]]; then
      if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
        tui_progress_start "Installing cargo packages" "$cargo_count"

        # Parse and install each cargo package
        while IFS= read -r pkg_json; do
          [[ -z "$pkg_json" ]] && continue

          local git_url features pkg_name install_cmd
          git_url=$(echo "$pkg_json" | jq -r '.git // empty')
          features=$(echo "$pkg_json" | jq -r '.features // [] | join(",")')

          if [[ -n "$git_url" ]]; then
            pkg_name=$(basename "$git_url" .git)
            tui_progress_next "$pkg_name"

            install_cmd="cargo install --git $git_url"
            [[ -n "$features" ]] && install_cmd+=" --features $features"

            eval "$install_cmd" || warn "Failed to install $pkg_name"
          fi
        done < <(jq -c '.[]' "$root_dir/configs/cargo.json" 2>/dev/null)

        tui_progress_complete "Cargo packages installed"
      else
        _install_log "Installing cargo packages..."
        while IFS= read -r pkg_json; do
          [[ -z "$pkg_json" ]] && continue

          local git_url features install_cmd
          git_url=$(echo "$pkg_json" | jq -r '.git // empty')
          features=$(echo "$pkg_json" | jq -r '.features // [] | join(",")')

          if [[ -n "$git_url" ]]; then
            install_cmd="cargo install --git $git_url"
            [[ -n "$features" ]] && install_cmd+=" --features $features"

            eval "$install_cmd" || warn "Failed to install from $git_url"
          fi
        done < <(jq -c '.[]' "$root_dir/configs/cargo.json" 2>/dev/null)
      fi
    fi
  fi

  # Cleanup TUI
  if [[ "$use_tui" == "true" ]] && declare -f tui_cleanup &>/dev/null; then
    tui_cleanup
  fi

  _install_success "Package installation complete"
else
  # Install single package
  header "Installing package: $package"

  # Detect package manager
  pm=$(detect_package_manager)

  if [[ "$pm" == "auto" ]]; then
    # Auto-detect: prefer brew on both platforms
    if is_macos; then
      if ! check_brew; then
        error "Homebrew is required on macOS for auto-install"
        exit 1
      fi
      pm="brew"
    elif is_linux; then
      if ! check_brew; then
        error "Homebrew/Linuxbrew is required for auto-install. Run 'jsh init' to install it."
        exit 1
      fi
      pm="brew"
    else
      error "Unsupported operating system"
      exit 1
    fi
  fi

  # Start TUI spinner for single package install
  if [[ "$use_tui" == "true" ]] && declare -f tui_progress_start &>/dev/null; then
    tui_progress_start "Installing $package" 0
    tui_progress_update 0 "$package via $pm"
  fi

  # Install via specified package manager
  if install_via_package_manager "$package" "$pm"; then
    # Package installed successfully - don't search for cross-platform equivalents
    if [[ "$use_tui" == "true" ]] && declare -f tui_progress_complete &>/dev/null; then
      tui_progress_complete "Installed $package"
      tui_cleanup
    fi
    _install_success "Installation complete"
  else
    if [[ "$use_tui" == "true" ]] && declare -f tui_cleanup &>/dev/null; then
      tui_cleanup
    fi
    error "Failed to install '$package' via $pm"
    # Only search for alternatives if installation failed
    search_cross_platform_packages "$package"
    exit 1
  fi
fi
