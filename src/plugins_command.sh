# jsh plugins - Manage shell, vim, and tmux plugins
#
# Usage:
#   jsh plugins              - List all plugin managers and their status
#   jsh plugins list         - Same as above
#   jsh plugins install      - Install all plugin managers and their plugins
#   jsh plugins update       - Update all plugins
#   jsh plugins check        - Check plugin health
#
# Options:
#   --vim   - Only manage vim plugins (vim-plug)
#   --tmux  - Only manage tmux plugins (TPM)
#   --shell - Only manage shell plugins (zinit)

root_dir="$(get_root_dir)"
action="${args[action]:-list}"
vim_only="${args[--vim]:-}"
tmux_only="${args[--tmux]:-}"
shell_only="${args[--shell]:-}"

# Determine which plugin managers to operate on
manage_all=true
[[ -n "$vim_only" || -n "$tmux_only" || -n "$shell_only" ]] && manage_all=false

should_manage_vim() {
  [[ "$manage_all" == "true" || -n "$vim_only" ]]
}

should_manage_tmux() {
  [[ "$manage_all" == "true" || -n "$tmux_only" ]]
}

should_manage_shell() {
  [[ "$manage_all" == "true" || -n "$shell_only" ]]
}

# Plugin manager paths
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
TPM_HOME="${HOME}/.tmux/plugins/tpm"
VIM_PLUG="${HOME}/.vim/autoload/plug.vim"
VIM_PLUGGED="${HOME}/.vim/plugged"

# List plugins
list_plugins() {
  header "Plugin Status"

  # Zinit (zsh plugins)
  if should_manage_shell; then
    echo -e "${BOLD}Shell Plugins (Zinit)${RESET}"
    if [[ -d "$ZINIT_HOME" ]]; then
      echo -e "  ${GREEN}✓${RESET} Zinit installed: $ZINIT_HOME"

      # List installed plugins
      local plugins_dir="${ZINIT_HOME%/*}/plugins"
      if [[ -d "$plugins_dir" ]]; then
        local count=$(find "$plugins_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        ((count--))  # Subtract 1 for parent dir
        echo "    Plugins installed: $count"

        # List some plugins
        local i=0
        for plugin_dir in "$plugins_dir"/*; do
          [[ -d "$plugin_dir" ]] || continue
          local plugin_name=$(basename "$plugin_dir")
          echo "    - $plugin_name"
          ((i++))
          [[ $i -ge 10 ]] && echo "    ... and more" && break
        done
      fi
    else
      echo -e "  ${RED}✗${RESET} Zinit not installed"
      echo "    Install with: jsh plugins install --shell"
    fi
    echo ""
  fi

  # TPM (tmux plugins)
  if should_manage_tmux; then
    echo -e "${BOLD}Tmux Plugins (TPM)${RESET}"
    if [[ -d "$TPM_HOME" ]]; then
      echo -e "  ${GREEN}✓${RESET} TPM installed: $TPM_HOME"

      # List installed plugins
      local plugins_dir="${HOME}/.tmux/plugins"
      if [[ -d "$plugins_dir" ]]; then
        local count=$(find "$plugins_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        ((count--))  # Subtract 1 for parent dir
        echo "    Plugins installed: $count"

        for plugin_dir in "$plugins_dir"/*; do
          [[ -d "$plugin_dir" ]] || continue
          local plugin_name=$(basename "$plugin_dir")
          echo "    - $plugin_name"
        done
      fi
    else
      echo -e "  ${RED}✗${RESET} TPM not installed"
      echo "    Install with: jsh plugins install --tmux"
    fi
    echo ""
  fi

  # vim-plug (vim plugins)
  if should_manage_vim; then
    echo -e "${BOLD}Vim Plugins (vim-plug)${RESET}"
    if [[ -f "$VIM_PLUG" ]]; then
      echo -e "  ${GREEN}✓${RESET} vim-plug installed: $VIM_PLUG"

      # List installed plugins
      if [[ -d "$VIM_PLUGGED" ]]; then
        local count=$(find "$VIM_PLUGGED" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        ((count--))  # Subtract 1 for parent dir
        echo "    Plugins installed: $count"

        local i=0
        for plugin_dir in "$VIM_PLUGGED"/*; do
          [[ -d "$plugin_dir" ]] || continue
          local plugin_name=$(basename "$plugin_dir")
          echo "    - $plugin_name"
          ((i++))
          [[ $i -ge 15 ]] && echo "    ... and more" && break
        done
      fi
    else
      echo -e "  ${RED}✗${RESET} vim-plug not installed"
      echo "    Install with: jsh plugins install --vim"
    fi
    echo ""
  fi
}

# Install plugin managers and plugins
install_plugins() {
  header "Installing Plugins"

  # Install Zinit
  if should_manage_shell; then
    if [[ ! -d "$ZINIT_HOME" ]]; then
      log "Installing Zinit..."
      mkdir -p "${ZINIT_HOME%/*}"
      if git_clone_https "https://github.com/zdharma-continuum/zinit.git" "$ZINIT_HOME"; then
        success "Zinit installed"
        info "Plugins will be installed on next zsh startup"
      else
        warn "Failed to install Zinit"
      fi
    else
      info "Zinit already installed"
    fi
    echo ""
  fi

  # Install TPM
  if should_manage_tmux; then
    if [[ ! -d "$TPM_HOME" ]]; then
      log "Installing TPM..."
      mkdir -p "${TPM_HOME%/*}"
      if git_clone_https "https://github.com/tmux-plugins/tpm.git" "$TPM_HOME"; then
        success "TPM installed"
        info "In tmux, press prefix + I to install plugins"
      else
        warn "Failed to install TPM"
      fi
    else
      info "TPM already installed"
      # Install tmux plugins
      log "Installing tmux plugins..."
      if [[ -x "${TPM_HOME}/bin/install_plugins" ]]; then
        "${TPM_HOME}/bin/install_plugins"
        success "Tmux plugins installed"
      fi
    fi
    echo ""
  fi

  # Install vim-plug
  if should_manage_vim; then
    if [[ ! -f "$VIM_PLUG" ]]; then
      log "Installing vim-plug..."
      if curl -fLo "$VIM_PLUG" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; then
        success "vim-plug installed"
        info "Open vim and run :PlugInstall to install plugins"
      else
        warn "Failed to install vim-plug"
      fi
    else
      info "vim-plug already installed"
      # Install vim plugins
      log "Installing vim plugins..."
      if command -v vim &>/dev/null; then
        vim +PlugInstall +qall 2>/dev/null
        success "Vim plugins installed"
      fi
    fi
    echo ""
  fi

  success "Plugin installation complete"
}

# Update all plugins
update_plugins() {
  header "Updating Plugins"

  # Update Zinit and plugins
  if should_manage_shell && [[ -d "$ZINIT_HOME" ]]; then
    log "Updating Zinit..."
    if command -v zsh &>/dev/null; then
      zsh -c 'source ~/.zshrc && zinit self-update' 2>/dev/null || true
      zsh -c 'source ~/.zshrc && zinit update --all' 2>/dev/null || true
      success "Zinit plugins updated"
    else
      warn "zsh not found, skipping Zinit update"
    fi
    echo ""
  fi

  # Update TPM and tmux plugins
  if should_manage_tmux && [[ -d "$TPM_HOME" ]]; then
    log "Updating TPM..."
    git_pull_https "$TPM_HOME"
    if [[ -x "${TPM_HOME}/bin/update_plugins" ]]; then
      "${TPM_HOME}/bin/update_plugins" all 2>/dev/null
      success "Tmux plugins updated"
    fi
    echo ""
  fi

  # Update vim plugins
  if should_manage_vim && [[ -f "$VIM_PLUG" ]]; then
    log "Updating vim plugins..."
    # Update vim-plug itself
    if command -v vim &>/dev/null; then
      vim +PlugUpgrade +PlugUpdate +qall 2>/dev/null
      success "Vim plugins updated"
    fi
    echo ""
  fi

  success "Plugin update complete"
}

# Check plugin health
check_plugins() {
  header "Checking Plugin Health"

  local issues=0

  # Check Zinit
  if should_manage_shell; then
    echo -e "${BOLD}Zinit${RESET}"
    if [[ -d "$ZINIT_HOME" ]]; then
      # Check if zinit is valid
      if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
        echo -e "  ${GREEN}✓${RESET} Zinit installation valid"
      else
        echo -e "  ${RED}✗${RESET} Zinit installation corrupted"
        ((issues++))
      fi

      # Check for broken plugin symlinks
      local plugins_dir="${ZINIT_HOME%/*}/plugins"
      if [[ -d "$plugins_dir" ]]; then
        local broken=$(find "$plugins_dir" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$broken" -gt 0 ]]; then
          echo -e "  ${YELLOW}⚠${RESET} $broken broken plugin symlink(s)"
          ((issues++))
        else
          echo -e "  ${GREEN}✓${RESET} All plugin symlinks valid"
        fi
      fi
    else
      echo -e "  ${YELLOW}⚠${RESET} Zinit not installed"
    fi
    echo ""
  fi

  # Check TPM
  if should_manage_tmux; then
    echo -e "${BOLD}TPM${RESET}"
    if [[ -d "$TPM_HOME" ]]; then
      if [[ -x "${TPM_HOME}/tpm" ]]; then
        echo -e "  ${GREEN}✓${RESET} TPM installation valid"
      else
        echo -e "  ${RED}✗${RESET} TPM installation corrupted"
        ((issues++))
      fi

      # Check tmux.conf for TPM initialization
      if grep -q "run.*tpm/tpm" ~/.tmux.conf 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} TPM configured in tmux.conf"
      else
        echo -e "  ${YELLOW}⚠${RESET} TPM not configured in tmux.conf"
      fi
    else
      echo -e "  ${YELLOW}⚠${RESET} TPM not installed"
    fi
    echo ""
  fi

  # Check vim-plug
  if should_manage_vim; then
    echo -e "${BOLD}vim-plug${RESET}"
    if [[ -f "$VIM_PLUG" ]]; then
      echo -e "  ${GREEN}✓${RESET} vim-plug installation valid"

      # Check for plugin directory
      if [[ -d "$VIM_PLUGGED" ]]; then
        local broken=$(find "$VIM_PLUGGED" -maxdepth 1 -type d -empty 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$broken" -gt 0 ]]; then
          echo -e "  ${YELLOW}⚠${RESET} $broken empty plugin directories"
        else
          echo -e "  ${GREEN}✓${RESET} All plugins have content"
        fi
      else
        echo -e "  ${YELLOW}⚠${RESET} No plugins installed"
      fi

      # Check vimrc for vim-plug initialization
      if grep -q "plug#begin" ~/.vimrc 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} vim-plug configured in vimrc"
      else
        echo -e "  ${YELLOW}⚠${RESET} vim-plug not configured in vimrc"
      fi
    else
      echo -e "  ${YELLOW}⚠${RESET} vim-plug not installed"
    fi
    echo ""
  fi

  # Summary
  if [[ $issues -eq 0 ]]; then
    success "All plugin systems healthy"
  else
    warn "Found $issues issue(s)"
  fi
}

# Main action dispatch
case "$action" in
  list)
    list_plugins
    ;;
  install)
    install_plugins
    ;;
  update)
    update_plugins
    ;;
  check)
    check_plugins
    ;;
  *)
    error "Unknown action: $action"
    info "Valid actions: list, install, update, check"
    exit 1
    ;;
esac
