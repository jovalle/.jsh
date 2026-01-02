# jsh tools - Discover and manage optional development tools
#
# Usage:
#   jsh tools              - List all tools and their status
#   jsh tools list         - Same as above
#   jsh tools check        - Check health of installed tools
#   jsh tools install      - Install all recommended tools
#   jsh tools recommend    - Show recommended tools for your environment
#
# Categories:
#   shell  - Shell enhancements (fzf, zoxide, atuin, eza)
#   editor - Editor tools (neovim, helix, vim plugins)
#   dev    - Development tools (git, jq, ripgrep, fd)
#   k8s    - Kubernetes tools (kubectl, k9s, kubectx, helm)
#   git    - Git enhancements (gh, lazygit, delta, forgit)

root_dir="$(get_root_dir)"
action="${args[action]:-list}"
show_missing="${args[--missing]:-}"
category_filter="${args[--category]:-}"

# Tool definitions: name|category|description|check_command|install_command
declare -a TOOLS=(
  # Shell enhancements
  "fzf|shell|Fuzzy finder for files, history, etc.|fzf --version|brew install fzf"
  "zoxide|shell|Smarter cd command with frecency|zoxide --version|brew install zoxide"
  "atuin|shell|Magical shell history with sync|atuin --version|brew install atuin"
  "eza|shell|Modern replacement for ls|eza --version|brew install eza"
  "bat|shell|Cat clone with syntax highlighting|bat --version|brew install bat"
  "starship|shell|Cross-shell prompt|starship --version|brew install starship"
  "direnv|shell|Per-directory environment variables|direnv version|brew install direnv"

  # Editor tools
  "nvim|editor|Neovim - hyperextensible Vim|nvim --version|brew install neovim"
  "hx|editor|Helix - post-modern modal editor|hx --version|brew install helix"
  "vim|editor|Vi Improved - the classic|vim --version|brew install vim"

  # Development tools
  "jq|dev|JSON processor|jq --version|brew install jq"
  "yq|dev|YAML processor|yq --version|brew install yq"
  "rg|dev|Ripgrep - fast grep replacement|rg --version|brew install ripgrep"
  "fd|dev|Fast find replacement|fd --version|brew install fd"
  "sd|dev|Intuitive find-and-replace|sd --version|brew install sd"
  "hyperfine|dev|Benchmarking tool|hyperfine --version|brew install hyperfine"
  "tokei|dev|Code statistics|tokei --version|brew install tokei"
  "just|dev|Modern make alternative|just --version|brew install just"
  "watchexec|dev|Execute commands on file changes|watchexec --version|brew install watchexec"

  # Kubernetes tools
  "kubectl|k8s|Kubernetes CLI|kubectl version --client|brew install kubernetes-cli"
  "k9s|k8s|Kubernetes TUI|k9s version|brew install k9s"
  "kubectx|k8s|Switch Kubernetes contexts|kubectx --version|brew install kubectx"
  "helm|k8s|Kubernetes package manager|helm version|brew install helm"
  "stern|k8s|Multi-pod log tailing|stern --version|brew install stern"
  "kustomize|k8s|Kubernetes config customization|kustomize version|brew install kustomize"

  # Git enhancements
  "gh|git|GitHub CLI|gh --version|brew install gh"
  "lazygit|git|Terminal UI for git|lazygit --version|brew install lazygit"
  "delta|git|Syntax-highlighting pager for git|delta --version|brew install git-delta"
  "git-lfs|git|Git Large File Storage|git lfs version|brew install git-lfs"
  "pre-commit|git|Git hook framework|pre-commit --version|brew install pre-commit"

  # Container tools
  "docker|container|Container runtime|docker --version|brew install --cask docker"
  "podman|container|Docker alternative|podman --version|brew install podman"
  "lazydocker|container|Terminal UI for Docker|lazydocker --version|brew install lazydocker"

  # Cloud tools
  "aws|cloud|AWS CLI|aws --version|brew install awscli"
  "gcloud|cloud|Google Cloud CLI|gcloud --version|brew install google-cloud-sdk"
  "az|cloud|Azure CLI|az --version|brew install azure-cli"
  "terraform|cloud|Infrastructure as Code|terraform version|brew install terraform"
)

# Check if a tool is installed
check_tool() {
  local check_cmd="$1"
  eval "$check_cmd" &>/dev/null
  return $?
}

# Get tool info
parse_tool() {
  local tool_line="$1"
  IFS='|' read -r name category description check_cmd install_cmd <<< "$tool_line"
  echo "$name|$category|$description|$check_cmd|$install_cmd"
}

# List tools
list_tools() {
  local filter_cat="$1"
  local only_missing="$2"

  echo -e "${BOLD}Development Tools${RESET}"
  echo ""

  local current_cat=""
  local installed_count=0
  local missing_count=0

  for tool_line in "${TOOLS[@]}"; do
    IFS='|' read -r name category description check_cmd install_cmd <<< "$tool_line"

    # Filter by category if specified
    [[ -n "$filter_cat" && "$category" != "$filter_cat" ]] && continue

    # Check if installed
    local status icon color
    if check_tool "$check_cmd"; then
      status="installed"
      icon="✓"
      color="${GREEN}"
      ((installed_count++)) || true
      [[ -n "$only_missing" ]] && continue
    else
      status="missing"
      icon="✗"
      color="${RED}"
      ((missing_count++)) || true
    fi

    # Print category header
    if [[ "$category" != "$current_cat" ]]; then
      [[ -n "$current_cat" ]] && echo ""
      echo -e "${BOLD}${category^^}${RESET}"
      current_cat="$category"
    fi

    # Print tool info
    printf "  ${color}${icon}${RESET} %-15s %s\n" "$name" "$description"
  done

  echo ""
  echo -e "${BOLD}Summary:${RESET} ${GREEN}$installed_count installed${RESET}, ${RED}$missing_count missing${RESET}"
}

# Check tool health
check_tools() {
  echo -e "${BOLD}Checking tool health...${RESET}"
  echo ""

  local issues=0

  for tool_line in "${TOOLS[@]}"; do
    IFS='|' read -r name category description check_cmd install_cmd <<< "$tool_line"

    if check_tool "$check_cmd"; then
      # Tool is installed, check version
      local version
      version=$(eval "$check_cmd" 2>&1 | head -1)
      echo -e "  ${GREEN}✓${RESET} $name: $version"
    fi
  done

  echo ""
  if [[ $issues -eq 0 ]]; then
    success "All installed tools are healthy"
  else
    warn "Found $issues issue(s)"
  fi
}

# Install missing recommended tools
install_tools() {
  local filter_cat="$1"

  # Check for Homebrew first
  if ! command -v brew &>/dev/null; then
    echo -e "${RED}Homebrew is not installed${RESET}"
    echo "Install Homebrew first: https://brew.sh"
    echo "Or run: jsh init"
    return 1
  fi

  # Recommended tools (installed by default without -c flag)
  local -A recommended=(
    [fzf]=1 [zoxide]=1 [eza]=1 [bat]=1 [direnv]=1
    [nvim]=1
    [jq]=1 [rg]=1 [fd]=1
    [gh]=1 [lazygit]=1 [delta]=1
  )

  # Map tool names to brew package names (when different)
  local -A brew_pkg=(
    [nvim]=neovim [rg]=ripgrep [delta]=git-delta
  )

  # Collect tools to install
  local -a to_install=()
  local -a to_install_names=()
  local name category description check_cmd install_cmd pkg

  for tool_line in "${TOOLS[@]}"; do
    IFS='|' read -r name category description check_cmd install_cmd <<< "$tool_line"

    # Filter by category if specified
    [[ -n "$filter_cat" && "$category" != "$filter_cat" ]] && continue

    # Only install recommended tools unless category filter is set
    [[ -z "$filter_cat" && -z "${recommended[$name]:-}" ]] && continue

    # Skip if already installed
    eval "$check_cmd" &>/dev/null && continue

    # Get brew package name
    pkg="${brew_pkg[$name]:-$name}"
    to_install+=("$pkg")
    to_install_names+=("$name")
  done

  # Nothing to install?
  if [[ ${#to_install[@]} -eq 0 ]]; then
    echo "All recommended tools are already installed"
    return 0
  fi

  # Show what we're installing
  echo -e "${BOLD}Installing ${#to_install[@]} tool(s):${RESET} ${to_install_names[*]}"
  echo ""

  # Install all at once
  if brew install "${to_install[@]}"; then
    echo ""
    echo -e "${GREEN}Installed ${#to_install[@]} tool(s)${RESET}"
    echo "Reload your shell to use new tools: exec \$SHELL"
  else
    echo ""
    echo -e "${YELLOW}Some tools may have failed to install${RESET}"
    echo "Run 'jsh tools list' to check status"
  fi
}

# Show recommendations
recommend_tools() {
  echo -e "${BOLD}Recommended Tools for Your Environment${RESET}"
  echo ""

  # Detect environment
  local env_type=""
  if [[ -f "${root_dir}/src/lib/environment.sh" ]]; then
    source "${root_dir}/src/lib/environment.sh"
    env_type=$(get_jsh_env 2>/dev/null || echo "unknown")
  fi

  info "Detected environment: ${env_type:-unknown}"
  echo ""

  echo -e "${BOLD}Essential (start here):${RESET}"
  echo "  fzf       - Fuzzy finder, dramatically improves productivity"
  echo "  zoxide    - Smarter cd that learns your habits"
  echo "  eza       - Beautiful ls replacement with git integration"
  echo "  rg        - Ripgrep - search code blazingly fast"
  echo ""

  echo -e "${BOLD}Developer productivity:${RESET}"
  echo "  jq        - Parse and manipulate JSON"
  echo "  fd        - Find files faster than find"
  echo "  bat       - Cat with syntax highlighting"
  echo "  delta     - Beautiful git diffs"
  echo "  lazygit   - Terminal UI for git operations"
  echo ""

  echo -e "${BOLD}For Kubernetes users:${RESET}"
  echo "  k9s       - Terminal UI for Kubernetes"
  echo "  kubectx   - Switch contexts/namespaces quickly"
  echo "  stern     - Tail logs from multiple pods"
  echo ""

  info "Run 'jsh tools install' to install recommended tools"
  info "Run 'jsh tools list -c <category>' to see all tools in a category"
}

# Main action dispatch
case "$action" in
  list)
    list_tools "$category_filter" "$show_missing"
    ;;
  check)
    check_tools
    ;;
  install)
    install_tools "$category_filter"
    ;;
  recommend)
    recommend_tools
    ;;
  *)
    error "Unknown action: $action"
    info "Valid actions: list, check, install, recommend"
    exit 1
    ;;
esac
