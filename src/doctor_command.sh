root_dir="$(get_root_dir)"

header "Running jsh diagnostics"

issues=0
warnings=0

# Check for required commands
echo -e "${BOLD}Checking required commands...${RESET}"
required_cmds=(brew git curl jq vim)
for cmd in "${required_cmds[@]}"; do
  if cmd_exists "$cmd"; then
    echo -e "  ${GREEN}✓${RESET} ${cmd}"
  else
    echo -e "  ${RED}✗${RESET} ${cmd} (missing)"
    ((issues++))
  fi
done
echo

# Check for recommended commands
echo -e "${BOLD}Checking recommended commands...${RESET}"
recommended_cmds=(fzf zoxide rg fd nvim tmux)
for cmd in "${recommended_cmds[@]}"; do
  if cmd_exists "$cmd"; then
    echo -e "  ${GREEN}✓${RESET} ${cmd}"
  else
    echo -e "  ${YELLOW}○${RESET} ${cmd} (not installed - optional)"
  fi
done
echo

# Check for broken symlinks
echo -e "${BOLD}Checking dotfile symlinks...${RESET}"
dotfiles=(.bashrc .zshrc .jshrc .vimrc .tmux.conf .gitconfig .inputrc .editorconfig)
for dotfile in "${dotfiles[@]}"; do
  target="${HOME}/${dotfile}"
  if [[ -L "$target" ]]; then
    if [[ -e "$target" ]]; then
      echo -e "  ${GREEN}✓${RESET} ${dotfile} -> $(readlink "$target")"
    else
      echo -e "  ${RED}✗${RESET} ${dotfile} (broken symlink)"
      ((issues++))
    fi
  elif [[ -f "$target" ]]; then
    echo -e "  ${YELLOW}⚠${RESET} ${dotfile} (exists but not symlinked)"
    ((warnings++))
  else
    echo -e "  ${YELLOW}○${RESET} ${dotfile} (not present)"
  fi
done
echo

# Check Git repository status
echo -e "${BOLD}Checking Git repository...${RESET}"
if [[ -d "${root_dir}/.git" ]]; then
  pushd "${root_dir}" > /dev/null || exit 1
  if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} Git repository is valid"

    # Check for uncommitted changes
    if git diff --quiet HEAD 2> /dev/null; then
      echo -e "  ${GREEN}✓${RESET} Working tree is clean"
    else
      local changes
      changes=$(git status --short | wc -l | tr -d ' ')
      echo -e "  ${YELLOW}⚠${RESET} $changes uncommitted change(s)"
      ((warnings++))
    fi

    # Check remote sync status
    if git remote get-url origin &> /dev/null; then
      git fetch origin --quiet 2> /dev/null || true
      local ahead behind
      ahead=$(git rev-list --count origin/main..HEAD 2> /dev/null || echo 0)
      behind=$(git rev-list --count HEAD..origin/main 2> /dev/null || echo 0)
      if [[ "$ahead" -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${RESET} $ahead commit(s) ahead of origin"
      fi
      if [[ "$behind" -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${RESET} $behind commit(s) behind origin"
        ((warnings++))
      fi
      if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
        echo -e "  ${GREEN}✓${RESET} In sync with origin"
      fi
    fi
  else
    echo -e "  ${RED}✗${RESET} Git repository is corrupted"
    ((issues++))
  fi

  if [[ -f "${root_dir}/.gitmodules" ]]; then
    if git submodule status | grep -q '^-'; then
      echo -e "  ${YELLOW}⚠${RESET} Some submodules are not initialized"
      ((warnings++))
    else
      echo -e "  ${GREEN}✓${RESET} All submodules initialized"
    fi
  fi
  popd > /dev/null || exit 1
else
  echo -e "  ${RED}✗${RESET} Not a Git repository"
  ((issues++))
fi
echo

# Check plugin managers
echo -e "${BOLD}Checking plugin managers...${RESET}"

# Zinit
zinit_home="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -d "$zinit_home" ]]; then
  if [[ -f "${zinit_home}/zinit.zsh" ]]; then
    echo -e "  ${GREEN}✓${RESET} Zinit installed"
  else
    echo -e "  ${RED}✗${RESET} Zinit installation corrupted"
    ((issues++))
  fi
else
  echo -e "  ${YELLOW}○${RESET} Zinit not installed (optional)"
fi

# TPM
tpm_home="${HOME}/.tmux/plugins/tpm"
if [[ -d "$tpm_home" ]]; then
  if [[ -x "${tpm_home}/tpm" ]]; then
    echo -e "  ${GREEN}✓${RESET} TPM installed"
  else
    echo -e "  ${RED}✗${RESET} TPM installation corrupted"
    ((issues++))
  fi
else
  echo -e "  ${YELLOW}○${RESET} TPM not installed (optional)"
fi

# vim-plug
vim_plug="${HOME}/.vim/autoload/plug.vim"
if [[ -f "$vim_plug" ]]; then
  echo -e "  ${GREEN}✓${RESET} vim-plug installed"
else
  echo -e "  ${YELLOW}○${RESET} vim-plug not installed (optional)"
fi
echo

# Check Homebrew health
if cmd_exists brew; then
  echo -e "${BOLD}Checking Homebrew...${RESET}"
  if brew doctor > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} Homebrew is healthy"
  else
    echo -e "  ${YELLOW}⚠${RESET} Homebrew has warnings (run 'brew doctor' for details)"
    ((warnings++))
  fi

  # Check for outdated packages
  local outdated
  outdated=$(brew outdated --quiet 2> /dev/null | wc -l | tr -d ' ')
  if [[ "$outdated" -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠${RESET} $outdated outdated package(s) (run 'jsh upgrade' to update)"
  else
    echo -e "  ${GREEN}✓${RESET} All packages up to date"
  fi
fi
echo

# Check shell configuration
echo -e "${BOLD}Checking shell configuration...${RESET}"
current_shell=$(basename "$SHELL")
echo -e "  Current shell: $current_shell"

# Check if shell rc sources jshrc
case "$current_shell" in
  zsh)
    if grep -q "\.jshrc" ~/.zshrc 2> /dev/null; then
      echo -e "  ${GREEN}✓${RESET} .zshrc sources .jshrc"
    else
      echo -e "  ${YELLOW}⚠${RESET} .zshrc does not source .jshrc"
      ((warnings++))
    fi
    ;;
  bash)
    if grep -q "\.jshrc" ~/.bashrc 2> /dev/null; then
      echo -e "  ${GREEN}✓${RESET} .bashrc sources .jshrc"
    else
      echo -e "  ${YELLOW}⚠${RESET} .bashrc does not source .jshrc"
      ((warnings++))
    fi
    ;;
esac

# Check TERM setting
if [[ -n "$TMUX" ]]; then
  if [[ "$TERM" == "tmux-256color" || "$TERM" == "screen-256color" ]]; then
    echo -e "  ${GREEN}✓${RESET} TERM correctly set for tmux: $TERM"
  else
    echo -e "  ${YELLOW}⚠${RESET} TERM may not be optimal for tmux: $TERM"
    ((warnings++))
  fi
else
  echo -e "  TERM: $TERM"
fi
echo

# Summary
echo -e "${BOLD}Summary${RESET}"
if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
  success "All checks passed! No issues found."
elif [[ $issues -eq 0 ]]; then
  info "No critical issues. $warnings warning(s) found."
else
  warn "Found $issues issue(s) and $warnings warning(s)."
  echo ""
  info "Suggestions:"
  info "  - Run 'jsh dotfiles' to fix missing symlinks"
  info "  - Run 'jsh plugins install' to install plugin managers"
  info "  - Run 'jsh sync' to sync with remote repository"
  exit 1
fi
