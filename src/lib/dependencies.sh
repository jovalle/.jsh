# Dependency checking library for jsh
# Validates required tools/commands and reports missing ones with environment-specific guidance
#
# Usage:
#   source dependencies.sh
#   # Core dependencies auto-registered on source
#
#   # Check if a dependency is available
#   if has_dependency "jq"; then
#     # use jq
#   fi
#
#   # Require a dependency (error if missing)
#   require_dependency "git"
#
#   # Report all missing dependencies with install guidance
#   report_missing_dependencies

# Get the directory containing this script (resolve to absolute path)
_JSH_DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Source environment detection if JSH_ENV not already set
if [[ -z "${JSH_ENV:-}" ]]; then
  # shellcheck source=environment.sh
  source "${_JSH_DEPS_DIR}/environment.sh"
  get_jsh_env > /dev/null
fi

# Source colors for cmd_exists if not already available
if ! declare -f cmd_exists &>/dev/null; then
  # shellcheck source=colors.sh
  source "${_JSH_DEPS_DIR}/colors.sh"
fi

# ============================================================================
# Internal State
# ============================================================================

# Associative array to store dependency metadata
# Key: dependency name
# Value: "check_cmd|required|guidance_macos_personal|guidance_macos_corporate|guidance_truenas|guidance_ssh_remote|guidance_linux_generic"
declare -gA _JSH_DEPS

# Track if core dependencies have been registered
_JSH_DEPS_INITIALIZED=""

# ============================================================================
# Registration Functions
# ============================================================================

# Register a dependency with its check command and install guidance
# Arguments:
#   $1 - name: Dependency identifier
#   $2 - check_cmd: Command/expression to check availability (eval'd)
#   $3 - required: "true" or "false"
#   $4 - guidance_macos_personal: Install instructions for personal macOS
#   $5 - guidance_macos_corporate: Install instructions for corporate macOS
#   $6 - guidance_truenas: Install instructions for TrueNAS
#   $7 - guidance_ssh_remote: Install instructions for SSH sessions
#   $8 - guidance_linux_generic: Install instructions for generic Linux
_register_dependency() {
  local name="$1"
  local check_cmd="$2"
  local required="$3"
  local guidance_macos_personal="${4:-}"
  local guidance_macos_corporate="${5:-}"
  local guidance_truenas="${6:-}"
  local guidance_ssh_remote="${7:-}"
  local guidance_linux_generic="${8:-}"

  # Store as pipe-delimited string
  _JSH_DEPS["$name"]="${check_cmd}|${required}|${guidance_macos_personal}|${guidance_macos_corporate}|${guidance_truenas}|${guidance_ssh_remote}|${guidance_linux_generic}"
}

# ============================================================================
# Check Functions
# ============================================================================

# Check if a single dependency is available
# Arguments:
#   $1 - name: Dependency name
# Returns: 0 if available, 1 if missing
check_dependency() {
  local name="$1"
  local dep_data="${_JSH_DEPS[$name]:-}"

  if [[ -z "$dep_data" ]]; then
    # Unknown dependency
    return 1
  fi

  local check_cmd
  check_cmd="${dep_data%%|*}"

  # Evaluate the check command
  if eval "$check_cmd" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Check all registered dependencies
# Returns: Count of missing required dependencies
check_all_dependencies() {
  local missing_required=0
  local name

  for name in "${!_JSH_DEPS[@]}"; do
    local dep_data="${_JSH_DEPS[$name]}"
    local required
    required="$(echo "$dep_data" | cut -d'|' -f2)"

    if ! check_dependency "$name"; then
      if [[ "$required" == "true" ]]; then
        ((missing_required++))
      fi
    fi
  done

  echo "$missing_required"
  return "$missing_required"
}

# Get list of missing dependencies
# Arguments:
#   --required: Only list required dependencies
#   --optional: Only list optional dependencies
# Output: Newline-separated list of missing dependency names
get_missing_dependencies() {
  local filter="${1:-}"
  local name

  for name in "${!_JSH_DEPS[@]}"; do
    if ! check_dependency "$name"; then
      local dep_data="${_JSH_DEPS[$name]}"
      local required
      required="$(echo "$dep_data" | cut -d'|' -f2)"

      case "$filter" in
        --required)
          [[ "$required" == "true" ]] && echo "$name"
          ;;
        --optional)
          [[ "$required" == "false" ]] && echo "$name"
          ;;
        *)
          echo "$name"
          ;;
      esac
    fi
  done
}

# ============================================================================
# Reporting Functions
# ============================================================================

# Get install guidance for a dependency based on current environment
# Arguments:
#   $1 - name: Dependency name
# Output: Install guidance string
_get_guidance() {
  local name="$1"
  local dep_data="${_JSH_DEPS[$name]:-}"

  if [[ -z "$dep_data" ]]; then
    echo "Unknown dependency"
    return
  fi

  local guidance=""
  case "${JSH_ENV:-linux-generic}" in
    macos-personal)
      guidance="$(echo "$dep_data" | cut -d'|' -f3)"
      ;;
    macos-corporate)
      guidance="$(echo "$dep_data" | cut -d'|' -f4)"
      ;;
    truenas)
      guidance="$(echo "$dep_data" | cut -d'|' -f5)"
      ;;
    ssh-remote)
      guidance="$(echo "$dep_data" | cut -d'|' -f6)"
      ;;
    linux-generic|*)
      guidance="$(echo "$dep_data" | cut -d'|' -f7)"
      ;;
  esac

  # Fall back to linux-generic guidance if specific guidance is empty
  if [[ -z "$guidance" ]]; then
    guidance="$(echo "$dep_data" | cut -d'|' -f7)"
  fi

  # Final fallback
  if [[ -z "$guidance" ]]; then
    guidance="Install $name"
  fi

  echo "$guidance"
}

# Report missing dependencies with install guidance
# Arguments:
#   --quiet: Suppress output
# Returns: 0 if no required deps missing, 1 otherwise
report_missing_dependencies() {
  local quiet=""
  [[ "${1:-}" == "--quiet" ]] && quiet="true"

  local missing_required=0
  local missing_optional=0
  local name
  local output=""

  for name in "${!_JSH_DEPS[@]}"; do
    if ! check_dependency "$name"; then
      local dep_data="${_JSH_DEPS[$name]}"
      local required
      required="$(echo "$dep_data" | cut -d'|' -f2)"
      local guidance
      guidance="$(_get_guidance "$name")"

      if [[ "$required" == "true" ]]; then
        ((missing_required++))
        output+="  [REQUIRED] $name: $guidance\n"
      else
        ((missing_optional++))
        output+="  [optional] $name: $guidance\n"
      fi
    fi
  done

  if [[ -z "$quiet" ]] && [[ -n "$output" ]]; then
    echo "Missing dependencies:"
    echo -e "$output"

    if [[ "$missing_required" -gt 0 ]]; then
      echo "($missing_required required, $missing_optional optional)"
    else
      echo "($missing_optional optional)"
    fi
  fi

  [[ "$missing_required" -eq 0 ]]
}

# ============================================================================
# Predicate Helpers
# ============================================================================

# Boolean check if dependency is available
# Arguments:
#   $1 - name: Dependency name
# Returns: 0 if available, 1 if missing
has_dependency() {
  check_dependency "$1"
}

# Check and error if dependency is missing
# Arguments:
#   $1 - name: Dependency name
# Returns: 0 if available, exits with error if missing
require_dependency() {
  local name="$1"

  if ! check_dependency "$name"; then
    local guidance
    guidance="$(_get_guidance "$name")"
    # Use error function if available, otherwise echo and return 1
    if declare -f error &>/dev/null; then
      error "Required dependency missing: $name. $guidance"
    else
      echo "Error: Required dependency missing: $name. $guidance" >&2
      return 1
    fi
  fi
  return 0
}

# ============================================================================
# Core Dependencies
# ============================================================================

# Register jsh's core dependencies
_register_core_dependencies() {
  # Prevent double registration
  [[ -n "$_JSH_DEPS_INITIALIZED" ]] && return 0
  _JSH_DEPS_INITIALIZED="true"

  # Critical: bash 4.2+
  _register_dependency "bash" \
    '[[ "${BASH_VERSINFO[0]}" -gt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -ge 2 ]]; }' \
    "true" \
    "brew install bash (then add to /etc/shells)" \
    "Request bash 4.2+ from IT, or install manually" \
    "bash 4.2+ typically pre-installed on TrueNAS SCALE" \
    "Upgrade bash on remote host" \
    "apt install bash / dnf install bash"

  # Critical: jq
  _register_dependency "jq" \
    'cmd_exists jq' \
    "true" \
    "brew install jq" \
    "Request jq from IT, or download from https://jqlang.github.io/jq/" \
    "apt install jq (if delegate has permissions)" \
    "Install jq on remote host" \
    "apt install jq / dnf install jq"

  # Optional: brew
  _register_dependency "brew" \
    'cmd_exists brew' \
    "false" \
    "Install Homebrew: https://brew.sh" \
    "Homebrew may require IT approval" \
    "Not available on TrueNAS SCALE" \
    "Not applicable for SSH sessions" \
    "Install Linuxbrew: https://brew.sh"

  # Optional: fzf
  _register_dependency "fzf" \
    'cmd_exists fzf' \
    "false" \
    "brew install fzf" \
    "Use bundled fzf at ~/.jsh/.fzf/" \
    "Use bundled fzf at ~/.jsh/.fzf/" \
    "Feature unavailable in SSH sessions (use bundled)" \
    "apt install fzf / brew install fzf"

  # Optional: git
  _register_dependency "git" \
    'cmd_exists git' \
    "false" \
    "brew install git" \
    "Request git from IT, or use Xcode Command Line Tools" \
    "apt install git (if delegate has permissions)" \
    "Install git on remote host" \
    "apt install git / dnf install git"

  # Optional: zinit (zsh-only)
  _register_dependency "zinit" \
    '[[ -d "${ZINIT[HOME_DIR]:-$HOME/.local/share/zinit/zinit.git}" ]] || [[ -d "$HOME/.zinit" ]]' \
    "false" \
    "Installed automatically when using zsh with jsh" \
    "Installed automatically when using zsh with jsh" \
    "Not applicable (bash-only on TrueNAS)" \
    "Not applicable for SSH sessions" \
    "Installed automatically when using zsh with jsh"
}

# ============================================================================
# Auto-initialization
# ============================================================================

# Register core dependencies when this file is sourced
_register_core_dependencies
