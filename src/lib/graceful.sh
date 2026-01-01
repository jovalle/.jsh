# Graceful degradation library for jsh
# Provides safe helpers for sourcing, eval, and completion loading
# that gracefully skip unavailable features without errors
#
# Requires: Bash 4.2+
# Dependencies: Optionally uses has_dependency from dependencies.sh
#
# Usage:
#   source graceful.sh
#   _jsh_try_source "$HOME/.local/config"        # Skip if missing
#   _jsh_try_eval "direnv" "direnv hook bash"    # Skip if command missing
#   _jsh_try_completion "kubectl" "eval"         # Load completion if available
#   _jsh_with_timeout 2 "slow_command"           # Run with timeout

# Get the directory containing this script
_JSH_GRACEFUL_DIR="${_JSH_GRACEFUL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)}"

# ============================================================================
# Debug Logging
# ============================================================================

# Debug logging - only outputs when JSH_DEBUG=1
# Arguments:
#   $@ - Message to log (all arguments joined)
# Output: Writes to stderr when JSH_DEBUG=1, otherwise silent
_jsh_debug() {
  [[ "${JSH_DEBUG:-}" == "1" ]] || return 0
  echo "[jsh:debug] $*" >&2
}

# ============================================================================
# Safe Sourcing
# ============================================================================

# Safely source a file with fallback
# Arguments:
#   $1 - File path to source
#   $2 - Optional fallback value/command on failure
# Returns: 0 on success, 1 if skipped
_jsh_try_source() {
  local file="$1"
  local fallback="${2:-}"

  # Check if file exists and is readable
  if [[ ! -f "$file" ]]; then
    _jsh_debug "skip source: file not found: $file"
    [[ -n "$fallback" ]] && eval "$fallback"
    return 1
  fi

  if [[ ! -r "$file" ]]; then
    _jsh_debug "skip source: file not readable: $file"
    [[ -n "$fallback" ]] && eval "$fallback"
    return 1
  fi

  # Attempt to source the file
  # shellcheck disable=SC1090
  if source "$file"; then
    _jsh_debug "sourced: $file"
    return 0
  else
    _jsh_debug "source failed: $file"
    [[ -n "$fallback" ]] && eval "$fallback"
    return 1
  fi
}

# ============================================================================
# Safe Eval
# ============================================================================

# Safely eval a command if dependency exists
# Arguments:
#   $1 - Command name to check for
#   $2 - Expression to eval if command exists
# Returns: 0 on success, 1 if skipped
_jsh_try_eval() {
  local cmd="$1"
  local expr="$2"

  # Check if command exists using command -v (fast, builtin)
  if ! command -v "$cmd" &>/dev/null; then
    _jsh_debug "skip eval: command not found: $cmd"
    return 1
  fi

  # Attempt to eval the expression
  if eval "$expr"; then
    _jsh_debug "eval success: $cmd"
    return 0
  else
    _jsh_debug "eval failed: $cmd"
    return 1
  fi
}

# ============================================================================
# Safe Completion Loading
# ============================================================================

# Safely load shell completions for a command
# Handles both eval and source patterns
# Arguments:
#   $1 - Command name to check for
#   $2 - Load method: "eval" or "source"
#   $3 - Completion expression (for eval) or file path (for source)
#        If not provided, attempts common patterns
#   $4 - Optional shell name (defaults to current shell)
# Returns: 0 on success, 1 if skipped
_jsh_try_completion() {
  local cmd="$1"
  local method="${2:-eval}"
  local completion_arg="${3:-}"
  local shell="${4:-${SH:-bash}}"

  # Check if command exists
  if ! command -v "$cmd" &>/dev/null; then
    _jsh_debug "skip completion: command not found: $cmd"
    return 1
  fi

  case "$method" in
    eval)
      # If no expression provided, try common patterns
      if [[ -z "$completion_arg" ]]; then
        completion_arg="$cmd completion $shell"
      fi

      # Try to eval the completion command
      local completion_output
      if completion_output=$(eval "$completion_arg" 2>/dev/null); then
        if eval "$completion_output" 2>/dev/null; then
          _jsh_debug "completion loaded (eval): $cmd"
          return 0
        fi
      fi

      _jsh_debug "completion failed (eval): $cmd"
      return 1
      ;;

    source)
      # Source a completion file directly
      if [[ -n "$completion_arg" ]] && [[ -f "$completion_arg" ]] && [[ -r "$completion_arg" ]]; then
        # shellcheck disable=SC1090
        if source "$completion_arg"; then
          _jsh_debug "completion loaded (source): $cmd from $completion_arg"
          return 0
        fi
      fi

      _jsh_debug "completion failed (source): $cmd"
      return 1
      ;;

    *)
      _jsh_debug "completion: unknown method: $method"
      return 1
      ;;
  esac
}

# ============================================================================
# Timeout Execution
# ============================================================================

# Execute a command with timeout
# Arguments:
#   $1 - Timeout in seconds (default: 2)
#   $@ - Command and arguments to execute
# Returns: Command exit status, or 124 on timeout
_jsh_with_timeout() {
  local timeout_secs="${1:-2}"
  shift

  # Check if there's something to run
  if [[ $# -eq 0 ]]; then
    _jsh_debug "timeout: no command provided"
    return 1
  fi

  # Use timeout command if available (GNU coreutils)
  if command -v timeout &>/dev/null; then
    timeout "$timeout_secs" "$@"
    local exit_status=$?
    if [[ $exit_status -eq 124 ]]; then
      _jsh_debug "timeout: command timed out after ${timeout_secs}s: $*"
    fi
    return $exit_status
  fi

  # Use gtimeout (Homebrew coreutils on macOS)
  if command -v gtimeout &>/dev/null; then
    gtimeout "$timeout_secs" "$@"
    local exit_status=$?
    if [[ $exit_status -eq 124 ]]; then
      _jsh_debug "timeout: command timed out after ${timeout_secs}s: $*"
    fi
    return $exit_status
  fi

  # Fallback: run without timeout (log warning in debug mode)
  _jsh_debug "timeout: no timeout command available, running without limit: $*"
  "$@"
}

# ============================================================================
# Auto-source dependencies if needed (lazy load)
# ============================================================================

# Ensure has_dependency is available (for scripts that need it)
# This is lazy-loaded to avoid sourcing dependencies.sh unnecessarily
_jsh_ensure_has_dependency() {
  if ! declare -f has_dependency &>/dev/null; then
    if [[ -f "${_JSH_GRACEFUL_DIR}/dependencies.sh" ]]; then
      # shellcheck source=dependencies.sh
      source "${_JSH_GRACEFUL_DIR}/dependencies.sh"
      _jsh_debug "lazy loaded: dependencies.sh"
    else
      _jsh_debug "dependencies.sh not found, has_dependency unavailable"
      return 1
    fi
  fi
  return 0
}
