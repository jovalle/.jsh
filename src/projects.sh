# projects.sh - Project directory navigation and status
#
# Provides:
#   project <name>  - cd to a project directory by name (zoxide-like)
#   project -l      - List all projects with git status summaries
#   projects        - Alias for 'project -l -v' (verbose listing)
#
# Configuration:
#   JSH_PROJECTS - Comma-separated list of paths to scan for projects
#                  Supports glob patterns for directories containing projects
#                  and direct paths for individual projects
#
#   Default: "~/.jsh,~/projects/*"
#
# Examples:
#   JSH_PROJECTS="~/.jsh,~/projects/*,~/work/*,/opt/myproject"
#
# Git status format (zsh-style):
#   ~/.jsh    main *9 !9 ?18
#   - * = staged changes
#   - ! = unstaged changes
#   - ? = untracked files

# shellcheck disable=SC2034

# =============================================================================
# Configuration
# =============================================================================

# Ensure essential paths are available (script may load before PATH is configured)
[[ ":${PATH}:" != *":/bin:"* ]] && PATH="/bin:${PATH}"
[[ ":${PATH}:" != *":/usr/bin:"* ]] && PATH="/usr/bin:${PATH}"
[[ ":${PATH}:" != *":/usr/local/bin:"* ]] && PATH="/usr/local/bin:${PATH}"
[[ -d /opt/homebrew/bin && ":${PATH}:" != *":/opt/homebrew/bin:"* ]] && PATH="/opt/homebrew/bin:${PATH}"

# Default project paths if JSH_PROJECTS not set
_PROJECTS_DEFAULT_PATHS="${HOME}/.jsh,${HOME}/projects/*"

# Remote projects config file
_PROJECTS_REMOTE_CONFIG="${JSH_DIR:-${HOME}/.jsh}/config/projects.json"

# Portable lowercase conversion (works in both bash and zsh)
_projects_lowercase() {
  printf '%s' "$1" | /usr/bin/tr '[:upper:]' '[:lower:]'
}

# =============================================================================
# Helper Functions
# =============================================================================

# Expand a path pattern to actual directories
# Arguments:
#   $1 - Path pattern (may contain ~ and *)
# Output: List of directories, one per line
_projects_expand_path() {
  local pattern="$1"

  # Expand ~ to $HOME
  pattern="${pattern/#\~/${HOME}}"

  # If pattern contains *, expand it
  if [[ "${pattern}" == *"*"* ]]; then
    # Use eval for portable glob expansion (works in both bash and zsh)
    # shellcheck disable=SC2034  # expanded is used within eval
    local expanded
    eval "for expanded in ${pattern}; do [[ -d \"\$expanded\" ]] && printf '%s\n' \"\$expanded\"; done" 2>/dev/null
  else
    # Direct path - just check if it exists
    [[ -d "${pattern}" ]] && printf '%s\n' "${pattern}"
  fi
}

# Get all project directories from JSH_PROJECTS
# Output: List of project directories, one per line
_projects_get_all() {
  local paths="${JSH_PROJECTS:-${_PROJECTS_DEFAULT_PATHS}}"
  local path

  # Split on comma using parameter substitution (portable between bash and zsh)
  # Use literal newline for compatibility
  local newline='
'
  local paths_newline="${paths//,/${newline}}"

  while IFS= read -r path; do
    # Skip empty entries
    [[ -z "${path}" ]] && continue

    # Trim whitespace
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"

    _projects_expand_path "${path}"
  done <<< "${paths_newline}"
}

# Get git status summary for a directory (with color codes)
# Arguments:
#   $1 - Directory path
#   $2 - If "color", output with ANSI color codes
# Output: Status string like "main *2 !3 ?5" or empty if not a git repo
_projects_git_status() {
  local dir="$1"
  local use_color="${2:-}"

  # Check if it's a git repo
  if [[ ! -d "${dir}/.git" ]] && ! git -C "${dir}" rev-parse --git-dir &>/dev/null; then
    return
  fi

  local branch staged unstaged untracked git_status=""

  # Color codes (only used if use_color is set)
  local C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_RESET=""
  if [[ "${use_color}" == "color" ]]; then
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_RESET=$'\033[0m'
  fi

  # Get branch name
  branch=$(git -C "${dir}" branch --show-current 2>/dev/null)
  [[ -z "${branch}" ]] && branch=$(git -C "${dir}" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  # Color main/master/develop branches cyan
  if [[ "${branch}" == "main" || "${branch}" == "master" || "${branch}" == "develop" ]]; then
    git_status="${C_CYAN}${branch}${C_RESET}"
  else
    git_status="${branch}"
  fi

  # Count staged changes (green)
  staged=$(git -C "${dir}" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  [[ "${staged}" -gt 0 ]] && git_status+=" ${C_GREEN}*${staged}${C_RESET}"

  # Count unstaged changes (yellow)
  unstaged=$(git -C "${dir}" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  [[ "${unstaged}" -gt 0 ]] && git_status+=" ${C_YELLOW}!${unstaged}${C_RESET}"

  # Count untracked files (red)
  untracked=$(git -C "${dir}" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  [[ "${untracked}" -gt 0 ]] && git_status+=" ${C_RED}?${untracked}${C_RESET}"

  printf '%s\n' "${git_status}"
}

# Get display name for a project (shortened path)
# Arguments:
#   $1 - Full path
# Output: Shortened display path (e.g., ~/.jsh instead of /Users/jay/.jsh)
_projects_display_name() {
  local path="$1"

  # Replace $HOME with ~ using parameter substitution (portable)
  if [[ "${path}" == "${HOME}"* ]]; then
    printf '%s\n' "~${path#"$HOME"}"
  else
    printf '%s\n' "${path}"
  fi
}

# =============================================================================
# Remote Project Functions
# =============================================================================

# Get remote project info from config
# Arguments:
#   $1 - Project name
# Output: JSON object with host and path, or empty if not found
_projects_get_remote() {
  local name="$1"

  if [[ ! -f "${_PROJECTS_REMOTE_CONFIG}" ]]; then
    return 1
  fi

  jq -r --arg name "${name}" '.remotes[$name] // empty' "${_PROJECTS_REMOTE_CONFIG}" 2>/dev/null
}

# List all remote projects
# Output: Project names, one per line
_projects_list_remotes() {
  if [[ ! -f "${_PROJECTS_REMOTE_CONFIG}" ]]; then
    return 0
  fi

  jq -r '.remotes | keys[]' "${_PROJECTS_REMOTE_CONFIG}" 2>/dev/null
}

# Open a remote project in VS Code
# Arguments:
#   $1 - Project name
# Returns: 0 on success, 1 on failure
_projects_open_remote() {
  local name="$1"
  local remote_info host remote_path description

  remote_info="$(_projects_get_remote "${name}")"

  if [[ -z "${remote_info}" ]]; then
    printf '%s\n' "No remote project found: ${name}" >&2
    printf '%s\n' "" >&2
    printf '%s\n' "Available remote projects:" >&2
    _projects_list_remotes | while read -r proj; do
      printf '%s\n' "  ${proj}" >&2
    done
    return 1
  fi

  host=$(printf '%s' "${remote_info}" | jq -r '.host')
  remote_path=$(printf '%s' "${remote_info}" | jq -r '.path')
  description=$(printf '%s' "${remote_info}" | jq -r '.description // empty')

  if [[ -z "${host}" ]] || [[ -z "${remote_path}" ]]; then
    printf '%s\n' "Invalid remote project config for: ${name}" >&2
    return 1
  fi

  # Open in VS Code Remote SSH
  local C_CYAN=$'\033[36m' C_DIM=$'\033[2m' C_RESET=$'\033[0m'
  printf '%b\n' "Opening remote: ${C_CYAN}${name}${C_RESET} (${host}:${remote_path})"
  [[ -n "${description}" ]] && printf '%b\n' "  ${C_DIM}${description}${C_RESET}"

  code --remote "ssh-remote+${host}" "${remote_path}"
}

# =============================================================================
# Git Profiles Configuration
# =============================================================================

# Git profiles config file
_PROJECTS_GIT_PROFILES="${JSH_DIR:-${HOME}/.jsh}/config/profiles.json"

# Get default projects directory for new projects
# Prefers directories that contain projects (glob patterns like ~/projects/*)
# over config directories (like ~/.jsh)
_projects_default_dir() {
  local paths="${JSH_PROJECTS:-${_PROJECTS_DEFAULT_PATHS}}"
  local path
  local newline='
'
  local paths_newline="${paths//,/${newline}}"
  local fallback=""

  # First pass: prefer glob pattern parents (these are project containers)
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    # Trim whitespace
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    # Expand ~
    path="${path/#\~/${HOME}}"

    if [[ "${path}" == *"*"* ]]; then
      # Extract parent directory (remove /* suffix)
      path="${path%/\*}"
      path="${path%\*}"
      # Return first valid projects container directory
      if [[ -d "${path}" ]]; then
        printf '%s\n' "${path}"
        return 0
      fi
    elif [[ -z "${fallback}" ]] && [[ -d "${path}" ]]; then
      # Save first non-glob path as fallback
      fallback="${path}"
    fi
  done <<< "${paths_newline}"

  # Fallback to first existing non-glob path, or ~/projects
  if [[ -n "${fallback}" ]]; then
    printf '%s\n' "${fallback}"
  else
    printf '%s\n' "${HOME}/projects"
  fi
}

# Extract project name from git URL
# Handles: git@host:user/repo.git, https://host/user/repo.git, etc.
_projects_name_from_url() {
  local url="$1"
  local name

  # Remove trailing .git
  name="${url%.git}"
  # Get last path component
  name="${name##*/}"
  # Handle SSH format (git@host:user/repo)
  name="${name##*:}"
  name="${name##*/}"

  printf '%s\n' "${name}"
}

# Get git profile info
# Arguments:
#   $1 - Profile name
# Output: name and email for git config
_projects_get_profile() {
  local profile_name="$1"

  if [[ ! -f "${_PROJECTS_GIT_PROFILES}" ]]; then
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    return 1
  fi

  jq -r --arg name "${profile_name}" '.profiles[$name] // empty' "${_PROJECTS_GIT_PROFILES}" 2>/dev/null
}

# List available git profiles
_projects_list_profiles() {
  if [[ ! -f "${_PROJECTS_GIT_PROFILES}" ]]; then
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    return 0
  fi

  jq -r '.profiles | keys[]' "${_PROJECTS_GIT_PROFILES}" 2>/dev/null
}

# =============================================================================
# Add Subcommand (Clone)
# =============================================================================

# Clone a git repository
# Usage: project add <url> [name]
_projects_add() {
  local url="$1"
  local name="${2:-}"
  local target_dir

  if [[ -z "${url}" ]]; then
    printf '%s\n' "Usage: project add <git-url> [name]" >&2
    printf '%s\n' "" >&2
    printf '%s\n' "Clone a git repository into the projects directory." >&2
    printf '%s\n' "" >&2
    printf '%s\n' "Examples:" >&2
    printf '%s\n' "  project add git@github.com:user/repo.git" >&2
    printf '%s\n' "  project add git@github.com-work:org/repo.git" >&2
    printf '%s\n' "  project add https://github.com/user/repo.git" >&2
    printf '%s\n' "  project add git@github.com:user/repo.git custom-name" >&2
    return 1
  fi

  # Get project name from URL if not specified
  if [[ -z "${name}" ]]; then
    name="$(_projects_name_from_url "${url}")"
  fi

  if [[ -z "${name}" ]]; then
    printf '%s\n' "Could not determine project name from URL: ${url}" >&2
    return 1
  fi

  # Determine target directory
  target_dir="$(_projects_default_dir)/${name}"

  if [[ -d "${target_dir}" ]]; then
    printf '%s\n' "Directory already exists: ${target_dir}" >&2
    return 1
  fi

  # Create parent directory if needed
  local parent_dir
  parent_dir="$(dirname "${target_dir}")"
  if [[ ! -d "${parent_dir}" ]]; then
    mkdir -p "${parent_dir}" || {
      printf '%s\n' "Failed to create directory: ${parent_dir}" >&2
      return 1
    }
  fi

  local C_CYAN=$'\033[36m' C_GREEN=$'\033[32m' C_RESET=$'\033[0m'
  printf '%b\n' "Cloning ${C_CYAN}${name}${C_RESET} from ${url}..."

  # Clone the repository (git handles SSH config automatically)
  if git clone "${url}" "${target_dir}"; then
    printf '%b\n' "${C_GREEN}Successfully cloned to:${C_RESET} $(_projects_display_name "${target_dir}")"
    cd "${target_dir}" || return 1
    printf '%b\n' "${C_CYAN}$(_projects_display_name "${target_dir}")${C_RESET}"
  else
    printf '%s\n' "Failed to clone repository" >&2
    return 1
  fi
}

# =============================================================================
# Create Subcommand (Initialize)
# =============================================================================

# Create a new git project
# Usage: project create [-p profile] <name>
_projects_create() {
  local profile=""
  local name=""
  local target_dir

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--profile)
        profile="$2"
        shift 2
        ;;
      -h|--help)
        printf '%s\n' "Usage: project create [-p profile] <name>"
        printf '%s\n' ""
        printf '%s\n' "Create a new git project with boilerplate files."
        printf '%s\n' ""
        printf '%s\n' "Options:"
        printf '%s\n' "  -p, --profile <name>  Use git profile for user.name and user.email"
        printf '%s\n' ""
        if command -v jq &>/dev/null && [[ -f "${_PROJECTS_GIT_PROFILES}" ]]; then
          printf '%s\n' "Available profiles:"
          while IFS= read -r p; do
            [[ -z "${p}" ]] && continue
            local info
            info="$(_projects_get_profile "${p}")"
            local p_name p_email
            p_name=$(printf '%s' "${info}" | jq -r '.name // empty')
            p_email=$(printf '%s' "${info}" | jq -r '.email // empty')
            printf '%s\n' "  ${p}: ${p_name} <${p_email}>"
          done < <(_projects_list_profiles)
        fi
        return 0
        ;;
      -*)
        printf '%s\n' "Unknown option: $1" >&2
        return 1
        ;;
      *)
        name="$1"
        shift
        ;;
    esac
  done

  if [[ -z "${name}" ]]; then
    printf '%s\n' "Usage: project create [-p profile] <name>" >&2
    printf '%s\n' "Use 'project create --help' for more information." >&2
    return 1
  fi

  # Determine target directory
  target_dir="$(_projects_default_dir)/${name}"

  if [[ -d "${target_dir}" ]]; then
    printf '%s\n' "Directory already exists: ${target_dir}" >&2
    return 1
  fi

  local C_CYAN=$'\033[36m' C_GREEN=$'\033[32m' C_DIM=$'\033[2m' C_RESET=$'\033[0m'
  printf '%b\n' "Creating project ${C_CYAN}${name}${C_RESET}..."

  # Create directory
  mkdir -p "${target_dir}" || {
    printf '%s\n' "Failed to create directory: ${target_dir}" >&2
    return 1
  }

  cd "${target_dir}" || return 1

  # Initialize git repo
  git init -q || {
    printf '%s\n' "Failed to initialize git repository" >&2
    return 1
  }

  # Apply profile if specified
  if [[ -n "${profile}" ]]; then
    local profile_info
    profile_info="$(_projects_get_profile "${profile}")"
    if [[ -n "${profile_info}" ]]; then
      local p_name p_email
      p_name=$(printf '%s' "${profile_info}" | jq -r '.name // empty')
      p_email=$(printf '%s' "${profile_info}" | jq -r '.email // empty')
      if [[ -n "${p_name}" ]]; then
        git config user.name "${p_name}"
        printf '%b\n' "  ${C_DIM}user.name:${C_RESET} ${p_name}"
      fi
      if [[ -n "${p_email}" ]]; then
        git config user.email "${p_email}"
        printf '%b\n' "  ${C_DIM}user.email:${C_RESET} ${p_email}"
      fi
    else
      printf '%s\n' "Warning: Profile '${profile}' not found, using global git config" >&2
    fi
  fi

  # Create README.md
  cat > README.md << EOF
# ${name}

## Description

A brief description of this project.

## Getting Started

\`\`\`bash
# Installation instructions
\`\`\`

## License

MIT
EOF
  printf '%b\n' "  ${C_DIM}Created:${C_RESET} README.md"

  # Create .gitignore
  cat > .gitignore << 'EOF'
# Dependencies
node_modules/
vendor/
.venv/
__pycache__/

# Build outputs
dist/
build/
*.o
*.a
*.so
*.dylib

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local
*.local

# Logs
*.log
logs/

# Coverage
coverage/
.nyc_output/
EOF
  printf '%b\n' "  ${C_DIM}Created:${C_RESET} .gitignore"

  # Create initial commit
  git add -A
  git commit -q -m "Initial commit"

  printf '%b\n' "${C_GREEN}Project created:${C_RESET} $(_projects_display_name "${target_dir}")"
  printf '%b\n' "${C_CYAN}$(_projects_display_name "${target_dir}")${C_RESET}"
}

# =============================================================================
# Profile Subcommand
# =============================================================================

# Handle profile subcommand
# Usage: project profile [command] [args]
_projects_profile() {
  local cmd="${1:-}"

  case "${cmd}" in
    ""|status)
      _profile_cmd_status
      ;;
    list|ls)
      _profile_cmd_list
      ;;
    check)
      _profile_cmd_check
      ;;
    docs|ssh|help-ssh)
      _profile_cmd_docs
      ;;
    -h|--help|help)
      _profile_cmd_help
      ;;
    *)
      # If arg looks like a profile name, treat as apply
      if _profiles_exists "${cmd}" 2>/dev/null; then
        _profile_cmd_apply "${cmd}"
      else
        printf '%s\n' "Unknown profile command: ${cmd}" >&2
        printf '%s\n' "Use 'project profile --help' for usage." >&2
        return 1
      fi
      ;;
  esac
}

# =============================================================================
# Main Functions
# =============================================================================

# project - cd to a project directory by name
# Usage: project [-c] [-l [-v]] [-r] <name>
#        project add <url> [name]
#        project create [-p profile] <name>
#        project profile [command] [args]
#   -c  Open in VS Code after navigating
#   -l  List all projects with git status
#   -v  Show profile column (use with -l)
#   -r  Open remote project in VS Code Remote SSH
# If multiple matches, prompts for selection
project() {
  local open_code=false
  local open_remote=false
  local list_projects=false
  local verbose=false

  # Handle subcommands first
  case "${1:-}" in
    add)
      shift
      _projects_add "$@"
      return $?
      ;;
    create)
      shift
      _projects_create "$@"
      return $?
      ;;
    profile)
      shift
      _projects_profile "$@"
      return $?
      ;;
  esac

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l|--list)
        list_projects=true
        shift
        ;;
      -v|--verbose)
        verbose=true
        shift
        ;;
      -c|--code)
        open_code=true
        shift
        ;;
      -r|--remote)
        open_remote=true
        shift
        ;;
      -h|--help)
        printf '%s\n' "Usage: project [-c] [-l [-v]] [-r] <name>"
        printf '%s\n' "       project add <git-url> [name]"
        printf '%s\n' "       project create [-p profile] <name>"
        printf '%s\n' "       project profile [command]"
        printf '%s\n' ""
        printf '%s\n' "Navigate to a project directory by name."
        printf '%s\n' ""
        printf '%s\n' "Commands:"
        printf '%s\n' "  add <url> [name]            Clone a git repository"
        printf '%s\n' "  create [-p profile] <name>  Create a new git project"
        printf '%s\n' "  profile [cmd]               Manage git user profiles"
        printf '%s\n' ""
        printf '%s\n' "Options:"
        printf '%s\n' "  -c, --code     Open in VS Code after navigating"
        printf '%s\n' "  -l, --list     List all projects with git status"
        printf '%s\n' "  -v, --verbose  Show profile column (use with -l)"
        printf '%s\n' "  -r, --remote   Open remote project in VS Code Remote SSH"
        printf '%s\n' ""
        printf '%s\n' "Configure paths with \$JSH_PROJECTS (comma-separated)."
        printf '%s\n' ""
        printf '%s\n' "Current search paths:"
        local paths="${JSH_PROJECTS:-${_PROJECTS_DEFAULT_PATHS}}"
        local IFS=','
        local path
        for path in ${paths}; do
          path="${path#"${path%%[![:space:]]*}"}"
          path="${path%"${path##*[![:space:]]}"}"
          printf '%s\n' "  ${path}"
        done
        printf '%s\n' ""
        printf '%s\n' "Remote projects (from ${_PROJECTS_REMOTE_CONFIG}):"
        if [[ -f "${_PROJECTS_REMOTE_CONFIG}" ]]; then
          if command -v jq &>/dev/null; then
            jq -r '.remotes | to_entries[] | "  \(.key): \(.value.host):\(.value.path)"' "${_PROJECTS_REMOTE_CONFIG}" 2>/dev/null || \
              printf '%s\n' "  (error reading config)"
          else
            printf '%s\n' "  (jq not available)"
          fi
        else
          printf '%s\n' "  (none configured)"
        fi
        return 0
        ;;
      -*)
        printf '%s\n' "Unknown option: $1" >&2
        printf '%s\n' "" >&2
        project --help >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  # Handle list mode (after all flags parsed, so -v can be combined)
  if [[ "${list_projects}" == true ]]; then
    if [[ "${verbose}" == true ]]; then
      _projects_list verbose
    else
      _projects_list
    fi
    return $?
  fi

  if [[ $# -eq 0 ]]; then
    project --help
    return 0
  fi

  # Handle remote project mode
  if [[ "${open_remote}" == true ]]; then
    _projects_open_remote "$1"
    return $?
  fi

  local name="$1"
  local name_lower
  name_lower="$(_projects_lowercase "${name}")"
  local matches=()
  local dir basename

  # Find all matching projects
  while IFS= read -r dir; do
    [[ -z "${dir}" ]] && continue
    basename="${dir##*/}"

    # Case-insensitive match (also match without leading dot)
    if [[ "$(_projects_lowercase "${basename}")" == "${name_lower}" ]] || \
       [[ "$(_projects_lowercase "${basename#.}")" == "${name_lower}" ]]; then
      matches+=("${dir}")
    fi
  done < <(_projects_get_all)

  case ${#matches[@]} in
    0)
      printf '%s\n' "No project found matching: ${name}" >&2
      printf '%s\n' "" >&2
      printf '%s\n' "Available projects:" >&2
      while IFS= read -r dir; do
        [[ -z "${dir}" ]] && continue
        printf '%s\n' "  ${dir##*/}" >&2
      done < <(_projects_get_all | sort -u)
      return 1
      ;;
    1)
      # Use ${matches[1]} for zsh compatibility (1-indexed)
      # bash will still work because matches[1] exists after appending one element
      local target="${matches[1]:-${matches[0]}}"
      local C_CYAN=$'\033[36m' C_RESET=$'\033[0m'
      cd "${target}" || return 1
      printf '%b\n' "${C_CYAN}$(_projects_display_name "${target}")${C_RESET}"
      [[ "${open_code}" == true ]] && code .
      ;;
    *)
      local C_CYAN=$'\033[36m' C_YELLOW=$'\033[33m' C_RESET=$'\033[0m'
      printf '%s\n' "Multiple projects match '${name}':"
      local i=1
      for dir in "${matches[@]}"; do
        printf '%b\n' "  ${C_YELLOW}${i})${C_RESET} ${C_CYAN}$(_projects_display_name "${dir}")${C_RESET}"
        ((i++))
      done
      printf '%s\n' ""

      # Prompt for selection
      local selection
      read -r -p "Select (1-${#matches[@]}): " selection

      if [[ "${selection}" =~ ^[0-9]+$ ]] && [[ "${selection}" -ge 1 ]] && [[ "${selection}" -le ${#matches[@]} ]]; then
        # In zsh, selection can be used directly (1-indexed)
        # In bash, we need selection for 0-indexed, but ${matches[@]} iteration uses the right elements
        local idx="${selection}"
        # Try zsh index first, fall back to bash index
        local selected="${matches[${idx}]:-${matches[$((idx-1))]}}"
        cd "${selected}" || return 1
        printf '%b\n' "${C_CYAN}$(_projects_display_name "${selected}")${C_RESET}"
        [[ "${open_code}" == true ]] && code .
      else
        printf '%s\n' "Invalid selection" >&2
        return 1
      fi
      ;;
  esac
}

# Truncate a path in the middle if too long
# Arguments:
#   $1 - Path string
#   $2 - Max length
# Output: Truncated path with ... in middle if needed
_projects_truncate_path() {
  local input_path="$1"
  local max_len="${2:-40}"
  local len=${#input_path}

  if [[ ${len} -le ${max_len} ]]; then
    printf '%s' "${input_path}"
    return
  fi

  # Keep first part and last part, add ... in middle
  local keep=$(( (max_len - 3) / 2 ))
  local first="${input_path:0:${keep}}"
  local last="${input_path: -${keep}}"
  printf '%s' "${first}...${last}"
}

# _projects_list - List all projects with git status (internal)
# Displays a table with project paths and git status summaries
# Shows a fixed footer with scanning progress
# Arguments:
#   $1 - "verbose" to show profile column
_projects_list() {
  local verbose=false
  [[ "${1:-}" == "verbose" ]] && verbose=true

  # Collect all project directories first
  local all_dirs=()
  local dir

  while IFS= read -r dir; do
    [[ -z "${dir}" ]] && continue
    all_dirs+=("${dir}")
  done < <(_projects_get_all)

  local total=${#all_dirs[@]}

  if [[ ${total} -eq 0 ]]; then
    printf '%s\n' "No projects found."
    printf '%s\n' ""
    printf '%s\n' "Configure paths with \$JSH_PROJECTS (comma-separated)."
    printf '%s\n' "Current: ${JSH_PROJECTS:-${_PROJECTS_DEFAULT_PATHS}}"
    return 0
  fi

  # Determine if we can use TUI mode (interactive terminal)
  local use_tui=false
  local term_width

  if [[ -t 1 ]] && [[ -z "${JSH_NO_TUI:-}" ]]; then
    use_tui=true
    term_width=$(tput cols 2>/dev/null || printf '%s' 80)
  else
    term_width=80
  fi

  # ANSI color codes
  local CYAN=$'\033[36m'
  local GREEN=$'\033[32m'
  local YELLOW=$'\033[33m'
  local RED=$'\033[31m'
  local BLUE=$'\033[34m'
  local MAGENTA=$'\033[35m'
  local BOLD=$'\033[1m'
  local DIM=$'\033[2m'
  local RESET=$'\033[0m'

  # Calculate column widths - cap based on terminal width
  local max_path_len=40
  local status_col_width=25
  local profile_col_width=12

  # Adjust for narrow terminals
  if [[ ${term_width} -lt 80 ]]; then
    max_path_len=$(( term_width - status_col_width - 5 ))
    [[ ${max_path_len} -lt 20 ]] && max_path_len=20
  fi

  # Results array
  local results=()
  local current=0
  local display_name truncated_name git_status padded_name profile_name

  # Flag for graceful interrupt handling (must use return, not exit, in functions)
  local _projects_interrupted=false

  if [[ "${use_tui}" == true ]]; then
    # Clear screen and hide cursor
    tput clear
    tput civis  # Hide cursor

    # Set up cleanup trap - sets flag instead of exit (exit would kill the whole shell!)
    trap '_projects_interrupted=true; tput cnorm' INT TERM
  fi

  # Process each project
  for dir in "${all_dirs[@]}"; do
    # Check for interrupt at start of each iteration
    [[ "${_projects_interrupted}" == true ]] && break
    ((current++))

    display_name="$(_projects_display_name "${dir}")"
    truncated_name="$(_projects_truncate_path "${display_name}" "${max_path_len}")"

    # Update progress at bottom of screen
    if [[ "${use_tui}" == true ]]; then
      # Use escape sequence with high row number (clamps to actual bottom)
      printf '\033[999;1H\033[K%b' "${DIM}Scanning ${current}/${total}: ${truncated_name}${RESET}"
    fi

    # Get git status with colors
    git_status="$(_projects_git_status "${dir}" "color")"

    # Get profile if verbose mode
    local profile_display=""
    if [[ "${verbose}" == true ]]; then
      profile_name="$(_profiles_detect "${dir}" 2>/dev/null)"
      if [[ -n "${profile_name}" ]]; then
        profile_display="${GREEN}$(printf "%-${profile_col_width}s" "${profile_name}")${RESET}"
      else
        profile_display="${DIM}$(printf "%-${profile_col_width}s" "-")${RESET}"
      fi
    fi

    # Format the result with colored path
    padded_name="$(printf "%-${max_path_len}s" "${truncated_name}")"

    if [[ -n "${git_status}" ]]; then
      if [[ "${verbose}" == true ]]; then
        results+=("${CYAN}${padded_name}${RESET}  ${profile_display}  ${git_status}")
      else
        results+=("${CYAN}${padded_name}${RESET}  ${git_status}")
      fi
    else
      if [[ "${verbose}" == true ]]; then
        results+=("${DIM}${padded_name}${RESET}  ${profile_display}  ${DIM}-${RESET}")
      else
        results+=("${DIM}${padded_name}${RESET}  ${DIM}-${RESET}")
      fi
    fi
  done

  # Handle interruption - clean up and exit early
  if [[ "${_projects_interrupted}" == true ]]; then
    if [[ "${use_tui}" == true ]]; then
      tput clear
      printf '\033[?25h'  # Show cursor
      trap - INT TERM
    fi
    printf '%b\n' "${DIM}Cancelled${RESET}"
    return 130
  fi

  # Clear screen and print results
  if [[ "${use_tui}" == true ]]; then
    tput clear  # Clear screen (moves cursor to top)
  fi

  # Print legend/key
  printf '%b\n' "${DIM}Key: ${GREEN}*${RESET}${DIM}staged ${YELLOW}!${RESET}${DIM}modified ${RED}?${RESET}${DIM}untracked${RESET}"
  printf '%s\n' ""

  # Print header
  local header_project header_profile header_status total_width
  header_project="$(printf "%-${max_path_len}s" "PROJECT")"
  header_status="STATUS"

  if [[ "${verbose}" == true ]]; then
    header_profile="$(printf "%-${profile_col_width}s" "PROFILE")"
    printf '%b\n' "${BOLD}${header_project}  ${header_profile}  ${header_status}${RESET}"
    total_width=$((max_path_len + profile_col_width + status_col_width + 4))
  else
    printf '%b\n' "${BOLD}${header_project}  ${header_status}${RESET}"
    total_width=$((max_path_len + status_col_width))
  fi
  printf '%*s\n' "${total_width}" '' | /usr/bin/tr ' ' '-'

  # Print results (already colorized)
  for line in "${results[@]}"; do
    printf '%b\n' "${line}"
  done

  # Print summary footer
  printf '%*s\n' "${total_width}" '' | /usr/bin/tr ' ' '-'
  printf '%b\n' "${DIM}${total} projects${RESET}  ${DIM}Key: ${GREEN}*${RESET}${DIM}staged ${YELLOW}!${RESET}${DIM}modified ${RED}?${RESET}${DIM}untracked${RESET}"

  if [[ "${use_tui}" == true ]]; then
    # Show cursor and reset trap
    printf '\033[?25h'
    trap - INT TERM
  fi
}

# =============================================================================
# Completion Support
# =============================================================================

# Completion function for project command
_project_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local first="${COMP_WORDS[1]:-}"
  local completions=()
  local dir

  # Handle subcommand completions
  if [[ ${COMP_CWORD} -eq 1 ]]; then
    # Complete subcommands and project names
    completions=("add" "create" "profile")
    while IFS= read -r dir; do
      [[ -z "${dir}" ]] && continue
      completions+=("${dir##*/}")
    done < <(_projects_get_all)
  elif [[ "${first}" == "create" ]]; then
    # Complete -p/--profile flag and profile names
    if [[ "${prev}" == "-p" ]] || [[ "${prev}" == "--profile" ]]; then
      while IFS= read -r prof; do
        [[ -z "${prof}" ]] && continue
        completions+=("${prof}")
      done < <(_profiles_list)
    else
      completions=("-p" "--profile")
    fi
  elif [[ "${first}" == "profile" ]]; then
    # Complete profile subcommands and profile names
    completions=("list" "check" "docs")
    while IFS= read -r prof; do
      [[ -z "${prof}" ]] && continue
      completions+=("${prof}")
    done < <(_profiles_list)
  elif [[ "${first}" == "add" ]]; then
    # No completion for URLs
    return 0
  elif [[ "${prev}" == "-r" ]] || [[ "${prev}" == "--remote" ]]; then
    # Complete with remote project names
    while IFS= read -r proj; do
      [[ -z "${proj}" ]] && continue
      completions+=("${proj}")
    done < <(_projects_list_remotes)
  else
    # Complete with local project names
    while IFS= read -r dir; do
      [[ -z "${dir}" ]] && continue
      completions+=("${dir##*/}")
    done < <(_projects_get_all)
  fi

  # shellcheck disable=SC2207
  COMPREPLY=($(compgen -W "${completions[*]}" -- "${cur}"))
}

# Aliases for quick access
alias p='project'
alias projects='project -l -v'

# Register completion for bash
if [[ -n "${BASH_VERSION:-}" ]]; then
  complete -F _project_completions project
  complete -F _project_completions p
fi

# Register completion for zsh (contains zsh-specific syntax, excluded from shfmt)
if [[ -n "${ZSH_VERSION:-}" ]]; then
  # Zsh completion
  _project_zsh_completions() {
    local -a commands projects profiles options
    local dir

    # words array is provided by zsh completion system (1-indexed)
    # words[1] = "project", words[2] = first arg, etc.
    local first="${words[2]:-}"
    local current="${words[CURRENT]:-}"
    local prev="${words[CURRENT-1]:-}"

    # Handle subcommand completions
    if [[ ${CURRENT} -eq 2 ]]; then
      # Commands
      commands=(
        "add:Clone a git repository"
        "create:Create a new git project"
        "profile:Manage git user profiles"
      )
      # Projects
      while IFS= read -r dir; do
        [[ -z "${dir}" ]] && continue
        projects+=("${dir##*/}")
      done < <(_projects_get_all)

      _describe -t commands 'command' commands
      _describe -t projects 'project' projects
    elif [[ "${first}" == "create" ]]; then
      # Complete -p/--profile flag and profile names
      if [[ "${prev}" == "-p" ]] || [[ "${prev}" == "--profile" ]]; then
        while IFS= read -r prof; do
          [[ -z "${prof}" ]] && continue
          profiles+=("${prof}")
        done < <(_profiles_list)
        _describe -t profiles 'profile' profiles
      else
        options=("-p:Use git profile" "--profile:Use git profile")
        _describe -t options 'option' options
      fi
    elif [[ "${first}" == "profile" ]]; then
      # Complete profile subcommands and profile names
      local -a profile_cmds
      profile_cmds=(
        "list:List all configured profiles"
        "check:Check all projects"
        "docs:Show SSH config documentation"
      )
      while IFS= read -r prof; do
        [[ -z "${prof}" ]] && continue
        profiles+=("${prof}:Apply profile")
      done < <(_profiles_list)
      _describe -t profile_cmds 'profile command' profile_cmds
      _describe -t profiles 'profile' profiles
    elif [[ "${first}" == "add" ]]; then
      # No completion for URLs
      return 0
    elif [[ "${prev}" == "-r" ]] || [[ "${prev}" == "--remote" ]]; then
      # Complete with remote project names
      while IFS= read -r proj; do
        [[ -z "${proj}" ]] && continue
        projects+=("${proj}")
      done < <(_projects_list_remotes)
      _describe -t projects 'remote project' projects
    else
      # Complete with local project names
      while IFS= read -r dir; do
        [[ -z "${dir}" ]] && continue
        projects+=("${dir##*/}")
      done < <(_projects_get_all)
      _describe -t projects 'project' projects
    fi
  }

  # Register completions - defer if compdef not yet available (before compinit)
  _project_register_completions() {
    compdef _project_zsh_completions project
    compdef _project_zsh_completions p
  }

  if (( ${+functions[compdef]} )); then
    _project_register_completions
  else
    # Queue for later registration after compinit
    _JSH_DEFERRED_COMPLETIONS+=("_project_register_completions")
  fi
fi
