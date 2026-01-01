# Environment detection library for jsh
# Detects runtime environment type for graceful degradation and environment-specific behavior
#
# Environment types:
#   - macos-personal:   macOS with full admin access, no corporate signals
#   - macos-corporate:  macOS with restrictions (MDM, proxy, restricted paths)
#   - truenas:          TrueNAS SCALE appliance (Debian-based, read-only system)
#   - ssh-remote:       Remote SSH session (any OS, detected via SSH_* vars)
#   - linux-generic:    Linux fallback when no specific environment detected

# Cache configuration
_JSH_ENV_CACHE_DIR="${HOME}/.cache/jsh"
_JSH_ENV_CACHE_FILE="${_JSH_ENV_CACHE_DIR}/environment"
_JSH_ENV_CACHE_TTL=3600  # 1 hour in seconds

# ============================================================================
# Detection Predicates
# ============================================================================

# Check if running in an SSH session
# Returns: 0 (true) if SSH session, 1 (false) otherwise
is_ssh_session() {
  # Check common SSH environment variables
  [[ -n "${SSH_CLIENT:-}" ]] && return 0
  [[ -n "${SSH_TTY:-}" ]] && return 0
  [[ -n "${SSH_CONNECTION:-}" ]] && return 0
  return 1
}

# Check if running on TrueNAS SCALE
# Returns: 0 (true) if TrueNAS, 1 (false) otherwise
is_truenas() {
  # Check for TrueNAS directory
  [[ -d "/usr/share/truenas" ]] && return 0

  # Check /etc/version for TrueNAS or SCALE string
  if [[ -f "/etc/version" ]]; then
    grep -qiE "(truenas|scale)" "/etc/version" 2>/dev/null && return 0
  fi

  return 1
}

# Check for corporate macOS environment
# Returns: 0 (true) if corporate macOS, 1 (false) otherwise
is_macos_corporate() {
  # Must be macOS first
  [[ "$(uname -s)" != "Darwin" ]] && return 1

  # Check for MDM profiles directory with content
  if [[ -d "/var/db/ConfigurationProfiles" ]]; then
    # Check if it's non-empty (has enrolled profiles)
    local profile_count
    profile_count=$(find "/var/db/ConfigurationProfiles" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
    [[ "${profile_count}" -gt 0 ]] && return 0
  fi

  # Check for corporate hostname patterns
  local hostname
  hostname="$(hostname 2>/dev/null || echo '')"
  if [[ -n "${hostname}" ]]; then
    # Common corporate patterns: .corp., .internal., -mac suffix
    [[ "${hostname}" == *".corp."* ]] && return 0
    [[ "${hostname}" == *".internal."* ]] && return 0
    [[ "${hostname}" == *"-mac" ]] && return 0
  fi

  # Check for proxy environment variables (often set by corporate networks)
  [[ -n "${http_proxy:-}" ]] && return 0
  [[ -n "${https_proxy:-}" ]] && return 0
  [[ -n "${HTTP_PROXY:-}" ]] && return 0
  [[ -n "${HTTPS_PROXY:-}" ]] && return 0

  # Check if /usr/local is restricted (common in corporate environments)
  if [[ -d "/usr/local" ]] && [[ ! -w "/usr/local" ]]; then
    return 0
  fi

  return 1
}

# Check for personal macOS environment
# Returns: 0 (true) if personal macOS, 1 (false) otherwise
is_macos_personal() {
  # Must be macOS
  [[ "$(uname -s)" != "Darwin" ]] && return 1

  # Personal means macOS without corporate indicators
  is_macos_corporate && return 1

  return 0
}

# ============================================================================
# Main Detection Function
# ============================================================================

# Detect the current environment type
# Priority order: ssh-remote > truenas > macos-corporate > macos-personal > linux-generic
# Sets JSH_ENV and exports it
detect_environment() {
  local env_type=""

  # SSH detection runs first because you can SSH into any environment type
  # This takes precedence to ensure remote sessions behave appropriately
  if is_ssh_session; then
    env_type="ssh-remote"
  elif is_truenas; then
    env_type="truenas"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    if is_macos_corporate; then
      env_type="macos-corporate"
    else
      env_type="macos-personal"
    fi
  elif [[ "$(uname -s)" == "Linux" ]]; then
    env_type="linux-generic"
  else
    # Unknown OS fallback
    env_type="linux-generic"
  fi

  JSH_ENV="${env_type}"
  export JSH_ENV
}

# ============================================================================
# Caching Wrapper
# ============================================================================

# Check if cache is valid
# Returns: 0 if cache is valid, 1 if cache should be refreshed
_is_cache_valid() {
  local cache_file="${_JSH_ENV_CACHE_FILE}"
  local mtime_file="${cache_file}.mtime"

  # Cache file must exist
  [[ ! -f "${cache_file}" ]] && return 1
  [[ ! -f "${mtime_file}" ]] && return 1

  # Cache must not be empty
  [[ ! -s "${cache_file}" ]] && return 1

  # Check TTL
  local cached_mtime current_time
  cached_mtime=$(cat "${mtime_file}" 2>/dev/null || echo "0")
  current_time=$(date +%s)

  if (( current_time - cached_mtime >= _JSH_ENV_CACHE_TTL )); then
    return 1
  fi

  return 0
}

# Write cache
_write_cache() {
  local env_type="$1"

  mkdir -p "${_JSH_ENV_CACHE_DIR}"
  echo "${env_type}" > "${_JSH_ENV_CACHE_FILE}"
  date +%s > "${_JSH_ENV_CACHE_FILE}.mtime"
}

# Read cache
_read_cache() {
  cat "${_JSH_ENV_CACHE_FILE}" 2>/dev/null
}

# Get JSH environment with caching
# This is the primary entry point for shell startup
get_jsh_env() {
  if _is_cache_valid; then
    JSH_ENV=$(_read_cache)
    export JSH_ENV
  else
    detect_environment
    _write_cache "${JSH_ENV}"
  fi

  # Return the environment type for callers that want it
  echo "${JSH_ENV}"
}

# Force re-detection (bypasses cache)
refresh_jsh_env() {
  detect_environment
  _write_cache "${JSH_ENV}"
  echo "${JSH_ENV}"
}

# Clear the environment cache
clear_jsh_env_cache() {
  rm -f "${_JSH_ENV_CACHE_FILE}" "${_JSH_ENV_CACHE_FILE}.mtime" 2>/dev/null
}
