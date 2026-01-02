# jsh profile - Show current environment profile and configuration
#
# Usage:
#   jsh profile           - Show environment summary
#   jsh profile -v        - Show detailed configuration
#   jsh profile --json    - Output as JSON
#
# This command helps you understand your current jsh environment,
# what's configured, and what's available.

root_dir="$(get_root_dir)"
verbose="${args[--verbose]:-}"
json_output="${args[--json]:-}"

# Source environment detection if available
if [[ -f "${root_dir}/src/lib/environment.sh" ]]; then
  source "${root_dir}/src/lib/environment.sh"
fi

# Detect environment type
get_env_type() {
  if declare -f get_jsh_env &> /dev/null; then
    get_jsh_env 2> /dev/null || echo "unknown"
  else
    if is_macos; then
      echo "macos"
    elif is_linux; then
      echo "linux"
    else
      echo "unknown"
    fi
  fi
}

# Get shell info
get_shell_info() {
  local shell_name shell_version
  shell_name=$(basename "$SHELL")

  case "$shell_name" in
    zsh)
      shell_version=$(zsh --version 2> /dev/null | head -1 | awk '{print $2}')
      ;;
    bash)
      shell_version=$BASH_VERSION
      ;;
    *)
      shell_version="unknown"
      ;;
  esac

  echo "$shell_name $shell_version"
}

# Get package manager info
get_package_manager() {
  if command -v brew &> /dev/null; then
    local brew_version
    brew_version=$(brew --version 2> /dev/null | head -1 | awk '{print $2}')
    echo "Homebrew $brew_version"
  elif command -v apt-get &> /dev/null; then
    echo "apt"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v pacman &> /dev/null; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Count installed packages
count_packages() {
  local count=0
  if command -v brew &> /dev/null; then
    count=$(brew list --formula 2> /dev/null | wc -l | tr -d ' ')
  fi
  echo "$count"
}

# Get plugin status
get_plugin_status() {
  local zinit_status="not installed"
  local tpm_status="not installed"
  local vim_plug_status="not installed"

  # Zinit
  local zinit_home="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  if [[ -d "$zinit_home" ]]; then
    local plugin_count
    plugin_count=$(find "${zinit_home%/*}" -maxdepth 2 -type d -name "*.git" 2> /dev/null | wc -l | tr -d ' ')
    zinit_status="installed ($plugin_count plugins)"
  fi

  # TPM
  local tpm_home="${HOME}/.tmux/plugins/tpm"
  if [[ -d "$tpm_home" ]]; then
    local plugin_count
    plugin_count=$(find "${HOME}/.tmux/plugins" -maxdepth 1 -type d 2> /dev/null | wc -l | tr -d ' ')
    ((plugin_count--)) # Subtract 1 for the plugins dir itself
    tpm_status="installed ($plugin_count plugins)"
  fi

  # vim-plug
  if [[ -f "${HOME}/.vim/autoload/plug.vim" ]]; then
    local plugin_count
    plugin_count=$(find "${HOME}/.vim/plugged" -maxdepth 1 -type d 2> /dev/null | wc -l | tr -d ' ')
    ((plugin_count--)) # Subtract 1 for the plugged dir itself
    vim_plug_status="installed ($plugin_count plugins)"
  fi

  echo "zinit:$zinit_status|tpm:$tpm_status|vim-plug:$vim_plug_status"
}

# Get jsh version
get_jsh_version() {
  if [[ -f "${root_dir}/VERSION" ]]; then
    cat "${root_dir}/VERSION"
  else
    echo "unknown"
  fi
}

# Get git info
get_git_info() {
  local branch commit dirty
  if [[ -d "${root_dir}/.git" ]]; then
    branch=$(git -C "$root_dir" rev-parse --abbrev-ref HEAD 2> /dev/null || echo "unknown")
    commit=$(git -C "$root_dir" rev-parse --short HEAD 2> /dev/null || echo "unknown")
    if git -C "$root_dir" diff --quiet HEAD 2> /dev/null; then
      dirty=""
    else
      dirty=" (modified)"
    fi
    echo "$branch@$commit$dirty"
  else
    echo "not a git repo"
  fi
}

# JSON output
if [[ -n "$json_output" ]]; then
  env_type=$(get_env_type)
  shell_info=$(get_shell_info)
  pkg_manager=$(get_package_manager)
  pkg_count=$(count_packages)
  plugin_status=$(get_plugin_status)
  jsh_version=$(get_jsh_version)
  git_info=$(get_git_info)

  # Parse plugin status
  IFS='|' read -r zinit tpm vim_plug <<< "$plugin_status"

  printf '{\n'
  printf '  "version": "%s",\n' "$jsh_version"
  printf '  "environment": "%s",\n' "$env_type"
  printf '  "shell": "%s",\n' "$shell_info"
  printf '  "package_manager": "%s",\n' "$pkg_manager"
  printf '  "package_count": %s,\n' "$pkg_count"
  printf '  "jsh_root": "%s",\n' "$root_dir"
  printf '  "git": "%s",\n' "$git_info"
  printf '  "plugins": {\n'
  printf '    "zinit": "%s",\n' "${zinit#zinit:}"
  printf '    "tpm": "%s",\n' "${tpm#tpm:}"
  printf '    "vim_plug": "%s"\n' "${vim_plug#vim-plug:}"
  printf '  }\n'
  printf '}\n'
  exit 0
fi

# Normal output
header "jsh Environment Profile"

# Basic info
echo -e "${BOLD}System${RESET}"
printf "  %-20s %s\n" "Environment:" "$(get_env_type)"
printf "  %-20s %s\n" "OS:" "$(uname -s) $(uname -r)"
printf "  %-20s %s\n" "Architecture:" "$(uname -m)"
printf "  %-20s %s\n" "Hostname:" "$(hostname)"
echo ""

echo -e "${BOLD}Shell${RESET}"
printf "  %-20s %s\n" "Current Shell:" "$(get_shell_info)"
printf "  %-20s %s\n" "SHELL:" "$SHELL"
printf "  %-20s %s\n" "TERM:" "$TERM"
echo ""

echo -e "${BOLD}jsh${RESET}"
printf "  %-20s %s\n" "Version:" "$(get_jsh_version)"
printf "  %-20s %s\n" "Root:" "$root_dir"
printf "  %-20s %s\n" "Git:" "$(get_git_info)"
echo ""

echo -e "${BOLD}Package Management${RESET}"
printf "  %-20s %s\n" "Manager:" "$(get_package_manager)"
printf "  %-20s %s\n" "Installed:" "$(count_packages) packages"
echo ""

# Plugin status
echo -e "${BOLD}Plugins${RESET}"
plugin_status=$(get_plugin_status)
IFS='|' read -r zinit tpm vim_plug <<< "$plugin_status"
printf "  %-20s %s\n" "Zinit:" "${zinit#zinit:}"
printf "  %-20s %s\n" "TPM:" "${tpm#tpm:}"
printf "  %-20s %s\n" "vim-plug:" "${vim_plug#vim-plug:}"
echo ""

# Verbose output
if [[ -n "$verbose" ]]; then
  echo -e "${BOLD}Paths${RESET}"
  printf "  %-20s %s\n" "HOME:" "$HOME"
  printf "  %-20s %s\n" "JSH:" "${JSH:-not set}"
  printf "  %-20s %s\n" "JSH_CUSTOM:" "${JSH_CUSTOM:-not set}"
  printf "  %-20s %s\n" "XDG_CONFIG_HOME:" "${XDG_CONFIG_HOME:-not set}"
  echo ""

  echo -e "${BOLD}Key Tools${RESET}"
  tools=(git vim nvim tmux fzf zoxide brew docker kubectl)
  for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
      version=$("$tool" --version 2> /dev/null | head -1 | cut -c1-50)
      printf "  ${GREEN}%-20s${RESET} %s\n" "$tool:" "$version"
    else
      printf "  ${RED}%-20s${RESET} %s\n" "$tool:" "not installed"
    fi
  done
  echo ""

  echo -e "${BOLD}Configuration Files${RESET}"
  dotfiles=(.bashrc .zshrc .vimrc .tmux.conf .gitconfig .inputrc)
  for dotfile in "${dotfiles[@]}"; do
    target="${HOME}/${dotfile}"
    if [[ -L "$target" ]]; then
      link_target=$(readlink "$target")
      printf "  ${GREEN}%-20s${RESET} -> %s\n" "$dotfile:" "$link_target"
    elif [[ -f "$target" ]]; then
      printf "  ${YELLOW}%-20s${RESET} %s\n" "$dotfile:" "exists (not symlinked)"
    else
      printf "  ${RED}%-20s${RESET} %s\n" "$dotfile:" "missing"
    fi
  done
  echo ""
fi

info "Run 'jsh profile -v' for detailed information"
info "Run 'jsh profile --json' for machine-readable output"
