# projects.sh - Project directory navigation and status
#
# Provides two functions:
#   project <name>  - cd to a project directory by name (zoxide-like)
#   projects        - List all projects with git status summaries
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
[[ ":$PATH:" != *":/bin:"* ]] && PATH="/bin:$PATH"
[[ ":$PATH:" != *":/usr/bin:"* ]] && PATH="/usr/bin:$PATH"
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && PATH="/usr/local/bin:$PATH"
[[ -d /opt/homebrew/bin && ":$PATH:" != *":/opt/homebrew/bin:"* ]] && PATH="/opt/homebrew/bin:$PATH"

# Default project paths if JSH_PROJECTS not set
_PROJECTS_DEFAULT_PATHS="${HOME}/.jsh,${HOME}/projects/*"

# Remote projects config file
_PROJECTS_REMOTE_CONFIG="${JSH_HOME:-${HOME}/.jsh}/configs/projects/remote.json"

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
  pattern="${pattern/#\~/$HOME}"

  # If pattern contains *, expand it
  if [[ "$pattern" == *"*"* ]]; then
    # Use eval for portable glob expansion (works in both bash and zsh)
    local expanded
    eval "for expanded in $pattern; do [[ -d \"\$expanded\" ]] && printf '%s\n' \"\$expanded\"; done" 2>/dev/null
  else
    # Direct path - just check if it exists
    [[ -d "$pattern" ]] && printf '%s\n' "$pattern"
  fi
}

# Get all project directories from JSH_PROJECTS
# Output: List of project directories, one per line
_projects_get_all() {
  local paths="${JSH_PROJECTS:-$_PROJECTS_DEFAULT_PATHS}"
  local path

  # Split on comma using parameter substitution (portable between bash and zsh)
  # Use literal newline for compatibility
  local newline='
'
  local paths_newline="${paths//,/${newline}}"

  while IFS= read -r path; do
    # Skip empty entries
    [[ -z "$path" ]] && continue

    # Trim whitespace
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"

    _projects_expand_path "$path"
  done <<< "$paths_newline"
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
  if [[ ! -d "$dir/.git" ]] && ! git -C "$dir" rev-parse --git-dir &>/dev/null; then
    return
  fi

  local branch staged unstaged untracked git_status=""

  # Color codes (only used if use_color is set)
  local C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_RESET=""
  if [[ "$use_color" == "color" ]]; then
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_RESET=$'\033[0m'
  fi

  # Get branch name
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [[ -z "$branch" ]] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  # Color main/master/develop branches cyan
  if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "develop" ]]; then
    git_status="${C_CYAN}${branch}${C_RESET}"
  else
    git_status="$branch"
  fi

  # Count staged changes (green)
  staged=$(git -C "$dir" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  [[ "$staged" -gt 0 ]] && git_status+=" ${C_GREEN}*${staged}${C_RESET}"

  # Count unstaged changes (yellow)
  unstaged=$(git -C "$dir" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  [[ "$unstaged" -gt 0 ]] && git_status+=" ${C_YELLOW}!${unstaged}${C_RESET}"

  # Count untracked files (red)
  untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  [[ "$untracked" -gt 0 ]] && git_status+=" ${C_RED}?${untracked}${C_RESET}"

  printf '%s\n' "$git_status"
}

# Get display name for a project (shortened path)
# Arguments:
#   $1 - Full path
# Output: Shortened display path (e.g., ~/.jsh instead of /Users/jay/.jsh)
_projects_display_name() {
  local path="$1"

  # Replace $HOME with ~ using parameter substitution (portable)
  if [[ "$path" == "$HOME"* ]]; then
    printf '%s\n' "~${path#$HOME}"
  else
    printf '%s\n' "$path"
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

  if [[ ! -f "$_PROJECTS_REMOTE_CONFIG" ]]; then
    return 1
  fi

  jq -r --arg name "$name" '.remotes[$name] // empty' "$_PROJECTS_REMOTE_CONFIG" 2>/dev/null
}

# List all remote projects
# Output: Project names, one per line
_projects_list_remotes() {
  if [[ ! -f "$_PROJECTS_REMOTE_CONFIG" ]]; then
    return 0
  fi

  jq -r '.remotes | keys[]' "$_PROJECTS_REMOTE_CONFIG" 2>/dev/null
}

# Open a remote project in VS Code
# Arguments:
#   $1 - Project name
# Returns: 0 on success, 1 on failure
_projects_open_remote() {
  local name="$1"
  local remote_info host remote_path description

  remote_info="$(_projects_get_remote "$name")"

  if [[ -z "$remote_info" ]]; then
    printf '%s\n' "No remote project found: $name" >&2
    printf '%s\n' "" >&2
    printf '%s\n' "Available remote projects:" >&2
    _projects_list_remotes | while read -r proj; do
      printf '%s\n' "  $proj" >&2
    done
    return 1
  fi

  host=$(printf '%s' "$remote_info" | jq -r '.host')
  remote_path=$(printf '%s' "$remote_info" | jq -r '.path')
  description=$(printf '%s' "$remote_info" | jq -r '.description // empty')

  if [[ -z "$host" ]] || [[ -z "$remote_path" ]]; then
    printf '%s\n' "Invalid remote project config for: $name" >&2
    return 1
  fi

  # Open in VS Code Remote SSH
  local C_CYAN=$'\033[36m' C_DIM=$'\033[2m' C_RESET=$'\033[0m'
  printf '%b\n' "Opening remote: ${C_CYAN}${name}${C_RESET} (${host}:${remote_path})"
  [[ -n "$description" ]] && printf '%b\n' "  ${C_DIM}${description}${C_RESET}"

  code --remote "ssh-remote+${host}" "$remote_path"
}

# =============================================================================
# Main Functions
# =============================================================================

# project - cd to a project directory by name
# Usage: project [-c] [-l] [-r] <name>
#   -c  Open in VS Code after navigating
#   -l  List all projects (runs `projects`)
#   -r  Open remote project in VS Code Remote SSH
# If multiple matches, prompts for selection
project() {
  local open_code=false
  local open_remote=false

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l|--list)
        projects
        return $?
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
        printf '%s\n' "Usage: project [-c] [-l] [-r] <name>"
        printf '%s\n' ""
        printf '%s\n' "Navigate to a project directory by name."
        printf '%s\n' ""
        printf '%s\n' "Options:"
        printf '%s\n' "  -c, --code    Open in VS Code after navigating"
        printf '%s\n' "  -l, --list    List all projects (runs 'projects')"
        printf '%s\n' "  -r, --remote  Open remote project in VS Code Remote SSH"
        printf '%s\n' ""
        printf '%s\n' "Configure paths with \$JSH_PROJECTS (comma-separated)."
        printf '%s\n' ""
        printf '%s\n' "Current search paths:"
        local paths="${JSH_PROJECTS:-$_PROJECTS_DEFAULT_PATHS}"
        local IFS=','
        local path
        for path in $paths; do
          path="${path#"${path%%[![:space:]]*}"}"
          path="${path%"${path##*[![:space:]]}"}"
          printf '%s\n' "  $path"
        done
        printf '%s\n' ""
        printf '%s\n' "Remote projects (from $_PROJECTS_REMOTE_CONFIG):"
        if [[ -f "$_PROJECTS_REMOTE_CONFIG" ]]; then
          jq -r '.remotes | to_entries[] | "  \(.key): \(.value.host):\(.value.path)"' "$_PROJECTS_REMOTE_CONFIG" 2>/dev/null || \
            printf '%s\n' "  (jq not available)"
        else
          printf '%s\n' "  (none configured)"
        fi
        return 0
        ;;
      -*)
        printf '%s\n' "Unknown option: $1" >&2
        printf '%s\n' "Usage: project [-c] [-r] <name>" >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    printf '%s\n' "Usage: project [-c] [-r] <name>"
    printf '%s\n' "Use 'project --help' for more information."
    return 0
  fi

  # Handle remote project mode
  if [[ "$open_remote" == true ]]; then
    _projects_open_remote "$1"
    return $?
  fi

  local name="$1"
  local matches=()
  local dir basename

  # Find all matching projects
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    basename="${dir##*/}"

    # Case-insensitive match (also match without leading dot)
    local basename_nodot="${basename#.}"
    local name_lower="$(_projects_lowercase "$name")"
    local basename_lower="$(_projects_lowercase "$basename")"
    local basename_nodot_lower="$(_projects_lowercase "$basename_nodot")"

    if [[ "$basename_lower" == "$name_lower" ]] || [[ "$basename_nodot_lower" == "$name_lower" ]]; then
      matches+=("$dir")
    fi
  done < <(_projects_get_all)

  case ${#matches[@]} in
    0)
      printf '%s\n' "No project found matching: $name" >&2
      printf '%s\n' "" >&2
      printf '%s\n' "Available projects:" >&2
      while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        printf '%s\n' "  ${dir##*/}" >&2
      done < <(_projects_get_all | sort -u)
      return 1
      ;;
    1)
      # Use ${matches[1]} for zsh compatibility (1-indexed)
      # bash will still work because matches[1] exists after appending one element
      local target="${matches[1]:-${matches[0]}}"
      local C_CYAN=$'\033[36m' C_RESET=$'\033[0m'
      cd "$target" || return 1
      printf '%b\n' "${C_CYAN}$(_projects_display_name "$target")${C_RESET}"
      [[ "$open_code" == true ]] && code .
      ;;
    *)
      local C_CYAN=$'\033[36m' C_YELLOW=$'\033[33m' C_RESET=$'\033[0m'
      printf '%s\n' "Multiple projects match '$name':"
      local i=1
      for dir in "${matches[@]}"; do
        printf '%b\n' "  ${C_YELLOW}$i)${C_RESET} ${C_CYAN}$(_projects_display_name "$dir")${C_RESET}"
        ((i++))
      done
      printf '%s\n' ""

      # Prompt for selection
      local selection
      read -r -p "Select (1-${#matches[@]}): " selection

      if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#matches[@]} ]]; then
        # In zsh, selection can be used directly (1-indexed)
        # In bash, we need selection for 0-indexed, but ${matches[@]} iteration uses the right elements
        local idx="$selection"
        # Try zsh index first, fall back to bash index
        local selected="${matches[$idx]:-${matches[$((idx-1))]}}"
        cd "$selected" || return 1
        printf '%b\n' "${C_CYAN}$(_projects_display_name "$selected")${C_RESET}"
        [[ "$open_code" == true ]] && code .
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

  if [[ $len -le $max_len ]]; then
    printf '%s' "$input_path"
    return
  fi

  # Keep first part and last part, add ... in middle
  local keep=$(( (max_len - 3) / 2 ))
  local first="${input_path:0:$keep}"
  local last="${input_path: -$keep}"
  printf '%s' "${first}...${last}"
}

# projects - List all projects with git status
# Displays a table with project paths and git status summaries
# Shows a fixed footer with scanning progress
projects() {
  # Collect all project directories first
  local all_dirs=()
  local dir

  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    all_dirs+=("$dir")
  done < <(_projects_get_all)

  local total=${#all_dirs[@]}

  if [[ $total -eq 0 ]]; then
    printf '%s\n' "No projects found."
    printf '%s\n' ""
    printf '%s\n' "Configure paths with \$JSH_PROJECTS (comma-separated)."
    printf '%s\n' "Current: ${JSH_PROJECTS:-$_PROJECTS_DEFAULT_PATHS}"
    return 0
  fi

  # Determine if we can use TUI mode (interactive terminal)
  local use_tui=false
  local term_height term_width

  if [[ -t 1 ]] && [[ -z "${JSH_NO_TUI:-}" ]]; then
    use_tui=true
    term_height=$(tput lines 2>/dev/null || printf '%s' 24)
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

  # Adjust for narrow terminals
  if [[ $term_width -lt 80 ]]; then
    max_path_len=$(( term_width - status_col_width - 5 ))
    [[ $max_path_len -lt 20 ]] && max_path_len=20
  fi

  # Results array
  local results=()
  local current=0

  if [[ "$use_tui" == true ]]; then
    # Clear screen and hide cursor
    tput clear
    tput civis  # Hide cursor

    # Set up cleanup trap (INT/TERM for Ctrl+C)
    trap 'tput cnorm' INT TERM
  fi

  # Process each project
  for dir in "${all_dirs[@]}"; do
    ((current++))

    local display_name="$(_projects_display_name "$dir")"
    local truncated_name="$(_projects_truncate_path "$display_name" "$max_path_len")"

    # Update progress at bottom of screen
    if [[ "$use_tui" == true ]]; then
      # Use escape sequence with high row number (clamps to actual bottom)
      printf '\033[999;1H\033[K%b' "${DIM}Scanning ${current}/${total}: ${truncated_name}${RESET}"
    fi

    # Get git status with colors
    local git_status="$(_projects_git_status "$dir" "color")"

    # Format the result with colored path
    local padded_name="$(printf "%-${max_path_len}s" "$truncated_name")"

    if [[ -n "$git_status" ]]; then
      results+=("${CYAN}${padded_name}${RESET}  ${git_status}")
    else
      results+=("${DIM}${padded_name}${RESET}  ${DIM}─${RESET}")
    fi
  done

  # Clear screen and print results
  if [[ "$use_tui" == true ]]; then
    tput clear  # Clear screen (moves cursor to top)
  fi

  # Print legend/key
  printf '%b\n' "${DIM}Key: ${GREEN}*${RESET}${DIM}staged ${YELLOW}!${RESET}${DIM}modified ${RED}?${RESET}${DIM}untracked${RESET}"
  printf '%s\n' ""

  # Print header
  local header_project header_status
  header_project="$(printf "%-${max_path_len}s" "PROJECT")"
  header_status="STATUS"
  printf '%b\n' "${BOLD}${header_project}  ${header_status}${RESET}"
  printf '%*s\n' "$((max_path_len + status_col_width))" '' | /usr/bin/tr ' ' '─'

  # Print results (already colorized)
  for line in "${results[@]}"; do
    printf '%b\n' "$line"
  done

  # Print summary footer
  printf '%*s\n' "$((max_path_len + status_col_width))" '' | /usr/bin/tr ' ' '─'
  printf '%b\n' "${DIM}${total} projects${RESET}  ${DIM}Key: ${GREEN}*${RESET}${DIM}staged ${YELLOW}!${RESET}${DIM}modified ${RED}?${RESET}${DIM}untracked${RESET}"

  if [[ "$use_tui" == true ]]; then
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
  local projects=()
  local dir

  # Check if completing after -r/--remote flag
  if [[ "$prev" == "-r" ]] || [[ "$prev" == "--remote" ]]; then
    # Complete with remote project names
    while IFS= read -r proj; do
      [[ -z "$proj" ]] && continue
      projects+=("$proj")
    done < <(_projects_list_remotes)
  else
    # Complete with local project names
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      projects+=("${dir##*/}")
    done < <(_projects_get_all)
  fi

  # shellcheck disable=SC2207
  COMPREPLY=($(compgen -W "${projects[*]}" -- "$cur"))
}

# Alias for quick access
alias p='project'

# Register completion for bash
if [[ -n "${BASH_VERSION:-}" ]]; then
  complete -F _project_completions project
  complete -F _project_completions p
fi

# Register completion for zsh
if [[ -n "${ZSH_VERSION:-}" ]]; then
  # Zsh completion
  _project_zsh_completions() {
    local projects=()
    local dir
    local -a words
    words=(${(s: :)BUFFER})

    # Check if completing after -r/--remote flag
    if [[ "${words[-1]}" == "-r" ]] || [[ "${words[-1]}" == "--remote" ]] || \
       [[ "${words[-2]}" == "-r" ]] || [[ "${words[-2]}" == "--remote" ]]; then
      # Complete with remote project names
      while IFS= read -r proj; do
        [[ -z "$proj" ]] && continue
        projects+=("$proj")
      done < <(_projects_list_remotes)
    else
      # Complete with local project names
      while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        projects+=("${dir##*/}")
      done < <(_projects_get_all)
    fi

    _describe 'project' projects
  }

  # Only set up if compdef exists
  if (( ${+functions[compdef]} )); then
    compdef _project_zsh_completions project
    compdef _project_zsh_completions p
  fi
fi
