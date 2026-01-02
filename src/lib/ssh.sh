# SSH portability library for jsh
# Provides bundle/inject functionality for portable SSH sessions
#
# This library enables "jssh" - SSH with your shell config.
# It creates a minimal jsh config bundle, encodes it, and injects it
# into remote SSH sessions via command substitution.
#
# Requires: Bash 4.2+
# Dependencies: tar, base64 (on local system)
# Remote needs: bash, base64, tar (ubiquitous)
#
# Usage:
#   source ssh.sh
#   _jsh_ssh_bundle           # Returns base64-encoded config payload
#   _jsh_ssh_inject_command host [ssh_args...]  # Echoes full SSH command

# Get the directory containing this script
_JSH_SSH_DIR="${_JSH_SSH_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)}"

# Load graceful.sh for _jsh_debug if not already loaded
if ! declare -f _jsh_debug &> /dev/null; then
  if [[ -f "${_JSH_SSH_DIR}/graceful.sh" ]]; then
    # shellcheck source=graceful.sh
    source "${_JSH_SSH_DIR}/graceful.sh"
  else
    # Minimal fallback if graceful.sh unavailable
    _jsh_debug() { [[ "${JSH_DEBUG:-}" == "1" ]] && echo "[jsh:debug] $*" >&2; }
  fi
fi

# ============================================================================
# Dependency Check
# ============================================================================

# Check if required dependencies exist on local system
# Returns: 0 if all deps available, 1 with error message if missing
_jsh_ssh_check_deps() {
  local missing=()

  if ! command -v tar &> /dev/null; then
    missing+=("tar")
  fi

  if ! command -v base64 &> /dev/null; then
    missing+=("base64")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing required dependencies: ${missing[*]}" >&2
    return 1
  fi

  _jsh_debug "ssh: all dependencies available"
  return 0
}

# ============================================================================
# Configuration Path
# ============================================================================

# Get path to minimal SSH config file
# Returns: Path to .jshrc.ssh (or empty if not found)
_jsh_ssh_get_minimal_config() {
  local jsh_root="${JSH:-${HOME}/.jsh}"
  local config_path="${jsh_root}/dotfiles/.jshrc.ssh"

  if [[ -f "${config_path}" ]]; then
    echo "${config_path}"
    return 0
  fi

  _jsh_debug "ssh: minimal config not found at ${config_path}"
  return 1
}

# ============================================================================
# Bundle Creation
# ============================================================================

# Maximum payload size (64KB is safe for ARG_MAX on most systems)
_JSH_SSH_MAX_PAYLOAD_SIZE=65536

# Create base64-encoded tarball of minimal SSH config
# Returns: Base64 encoded payload string (stdout)
# Errors: Returns 1 if config missing, 2 if payload too large
_jsh_ssh_bundle() {
  local config_path

  # Check dependencies first
  if ! _jsh_ssh_check_deps; then
    return 1
  fi

  # Get minimal config path
  config_path=$(_jsh_ssh_get_minimal_config)
  if [[ -z "${config_path}" ]]; then
    echo "Error: Minimal SSH config not found. Expected: ${JSH:-${HOME}/.jsh}/dotfiles/.jshrc.ssh" >&2
    return 1
  fi

  _jsh_debug "ssh: bundling config from ${config_path}"

  # Create tarball and encode
  # Use gzip for smaller payload, base64 for safe transmission
  local payload
  payload=$(tar -czf - -C "$(dirname "${config_path}")" "$(basename "${config_path}")" 2> /dev/null | base64)

  if [[ -z "${payload}" ]]; then
    echo "Error: Failed to create bundle" >&2
    return 1
  fi

  # Validate size
  local payload_size=${#payload}
  if [[ ${payload_size} -gt ${_JSH_SSH_MAX_PAYLOAD_SIZE} ]]; then
    echo "Error: Payload size (${payload_size} bytes) exceeds maximum (${_JSH_SSH_MAX_PAYLOAD_SIZE} bytes)" >&2
    return 2
  fi

  _jsh_debug "ssh: bundle created, size=${payload_size} bytes"

  # Output the payload
  echo "${payload}"
  return 0
}

# ============================================================================
# SSH Command Construction
# ============================================================================

# Build SSH command with embedded jsh config payload
# Arguments:
#   $1 - Remote host (required)
#   $@ - Additional SSH arguments (optional)
# Returns: Echoes full SSH command to execute
_jsh_ssh_inject_command() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: _jsh_ssh_inject_command <host> [ssh_args...]" >&2
    return 1
  fi

  local host="$1"
  shift
  local ssh_args=("$@")

  # Generate payload
  local payload
  payload=$(_jsh_ssh_bundle)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Construct remote command
  # This command:
  # 1. Creates temp directory for jsh config
  # 2. Decodes and extracts the payload
  # 3. Sets up cleanup trap on exit
  # 4. Sources the config
  # 5. Starts interactive bash
  local remote_script
  remote_script='
JSHHOME=$(mktemp -d)
export JSHHOME
trap "rm -rf \"$JSHHOME\"" EXIT
echo "$JSH_PAYLOAD" | base64 -d | tar xzf - -C "$JSHHOME"
bash --rcfile "$JSHHOME/.jshrc.ssh"
'

  # Build the SSH command
  # Note: Using single quotes around remote command, double quotes around payload
  local ssh_cmd="ssh"

  # Add any additional SSH arguments
  if [[ ${#ssh_args[@]} -gt 0 ]]; then
    ssh_cmd+=" ${ssh_args[*]}"
  fi

  # Add -t for interactive TTY
  ssh_cmd+=" -t"

  # Add host and remote command
  # The payload is exported as JSH_PAYLOAD, then bash executes our setup script
  ssh_cmd+=" ${host} 'export JSH_PAYLOAD=\"${payload}\"; bash -c '\''${remote_script}'\''"

  _jsh_debug "ssh: built inject command for host=${host}"

  echo "${ssh_cmd}"
  return 0
}

# ============================================================================
# Documentation: Cleanup
# ============================================================================

# Remote cleanup happens automatically via EXIT trap set in _jsh_ssh_inject_command.
# The trap `rm -rf "$JSHHOME"` removes the temporary directory containing:
# - .jshrc.ssh (the extracted config)
# - Any other files that were in the bundle
#
# This ensures no jsh artifacts are left on the remote system after disconnect.
# The trap fires on:
# - Normal shell exit (exit, logout, Ctrl-D)
# - Shell termination via signal (Ctrl-C, etc.)
# - Connection drop (SSH timeout, network failure)
_jsh_ssh_cleanup_remote() {
  echo "Remote cleanup is handled automatically via EXIT trap."
  echo "Temp directory (\$JSHHOME) is removed when the SSH session ends."
}
