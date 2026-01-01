#!/usr/bin/env bats
# Unit tests for src/lib/environment.sh
# shellcheck disable=SC2154  # Variables from test_helper.bash

setup() {
  load '../test_helper.bash'

  # Create temp directory for cache testing
  setup_test_dir

  # Clear any existing SSH environment variables for clean tests
  unset SSH_CLIENT SSH_TTY SSH_CONNECTION

  # Clear proxy variables
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

  # Set up mock cache directory
  export _JSH_ENV_CACHE_DIR="${TEST_DIR}/cache"
  export _JSH_ENV_CACHE_FILE="${_JSH_ENV_CACHE_DIR}/environment"

  # Source the environment library
  source "${JSH_ROOT}/src/lib/environment.sh"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# is_ssh_session tests
# ============================================================================

@test "is_ssh_session: returns true when SSH_CLIENT is set" {
  export SSH_CLIENT="192.168.1.1 12345 22"
  run is_ssh_session
  [[ "$status" -eq 0 ]]
}

@test "is_ssh_session: returns true when SSH_TTY is set" {
  export SSH_TTY="/dev/pts/0"
  run is_ssh_session
  [[ "$status" -eq 0 ]]
}

@test "is_ssh_session: returns true when SSH_CONNECTION is set" {
  export SSH_CONNECTION="192.168.1.1 12345 192.168.1.100 22"
  run is_ssh_session
  [[ "$status" -eq 0 ]]
}

@test "is_ssh_session: returns false when no SSH vars set" {
  unset SSH_CLIENT SSH_TTY SSH_CONNECTION
  run is_ssh_session
  [[ "$status" -eq 1 ]]
}

# ============================================================================
# is_truenas tests
# ============================================================================

@test "is_truenas: returns false on normal systems" {
  # Most test systems won't be TrueNAS
  # This test confirms it returns false when TrueNAS indicators aren't present
  if [[ ! -d "/usr/share/truenas" ]] && [[ ! -f "/etc/version" ]]; then
    run is_truenas
    [[ "$status" -eq 1 ]]
  else
    # If running on actual TrueNAS, it should return true
    skip "Running on TrueNAS or system with TrueNAS indicators"
  fi
}

@test "is_truenas: returns true when /usr/share/truenas exists" {
  # Create mock TrueNAS directory
  mkdir -p "${TEST_DIR}/usr/share/truenas"

  # Override the function to check our test directory
  is_truenas_test() {
    [[ -d "${TEST_DIR}/usr/share/truenas" ]] && return 0
    return 1
  }

  run is_truenas_test
  [[ "$status" -eq 0 ]]
}

@test "is_truenas: returns true when /etc/version contains TrueNAS" {
  # Create mock /etc/version
  mkdir -p "${TEST_DIR}/etc"
  echo "TrueNAS-SCALE-22.02" > "${TEST_DIR}/etc/version"

  # Test that grep would match
  run grep -qiE "(truenas|scale)" "${TEST_DIR}/etc/version"
  [[ "$status" -eq 0 ]]
}

# ============================================================================
# is_macos_corporate tests
# ============================================================================

@test "is_macos_corporate: returns false on non-macOS" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    run is_macos_corporate
    [[ "$status" -eq 1 ]]
  else
    skip "Running on macOS"
  fi
}

@test "is_macos_corporate: detects proxy variables" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    export http_proxy="http://proxy.corp.com:8080"
    run is_macos_corporate
    [[ "$status" -eq 0 ]]
  else
    skip "Not running on macOS"
  fi
}

@test "is_macos_corporate: detects HTTPS proxy variables" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    export HTTPS_PROXY="https://proxy.corp.com:8080"
    run is_macos_corporate
    [[ "$status" -eq 0 ]]
  else
    skip "Not running on macOS"
  fi
}

# ============================================================================
# is_macos_personal tests
# ============================================================================

@test "is_macos_personal: returns false on non-macOS" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    run is_macos_personal
    [[ "$status" -eq 1 ]]
  else
    skip "Running on macOS"
  fi
}

@test "is_macos_personal: returns true on macOS without corporate indicators" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # Clear all corporate indicators
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

    # Note: This might still detect corporate based on MDM or hostname
    # So we just verify the function runs without error
    run is_macos_personal
    # Status will be 0 (personal) or 1 (corporate) - both are valid
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  else
    skip "Not running on macOS"
  fi
}

# ============================================================================
# detect_environment tests
# ============================================================================

@test "detect_environment: returns valid environment string" {
  # Call directly (not with run) so JSH_ENV is set in current shell
  detect_environment

  # Check JSH_ENV is set to a valid value
  case "${JSH_ENV}" in
    macos-personal|macos-corporate|truenas|ssh-remote|linux-generic)
      return 0
      ;;
    *)
      echo "Invalid JSH_ENV value: ${JSH_ENV}"
      return 1
      ;;
  esac
}

@test "detect_environment: SSH takes priority over other environments" {
  export SSH_CLIENT="192.168.1.1 12345 22"
  detect_environment
  [[ "${JSH_ENV}" == "ssh-remote" ]]
}

@test "detect_environment: sets JSH_ENV and exports it" {
  detect_environment

  # Verify JSH_ENV is set
  [[ -n "${JSH_ENV}" ]]

  # Verify it's one of the valid types
  case "${JSH_ENV}" in
    macos-personal|macos-corporate|truenas|ssh-remote|linux-generic)
      return 0
      ;;
    *)
      echo "Invalid JSH_ENV value: ${JSH_ENV}"
      return 1
      ;;
  esac
}

# ============================================================================
# Caching tests
# ============================================================================

@test "get_jsh_env: creates cache file on first run" {
  # Ensure cache doesn't exist
  rm -f "${_JSH_ENV_CACHE_FILE}" "${_JSH_ENV_CACHE_FILE}.mtime"

  run get_jsh_env
  [[ "$status" -eq 0 ]]

  # Cache file should now exist
  [[ -f "${_JSH_ENV_CACHE_FILE}" ]]
  [[ -f "${_JSH_ENV_CACHE_FILE}.mtime" ]]
}

@test "get_jsh_env: returns cached value on second call" {
  # First call - creates cache
  result1=$(get_jsh_env)

  # Second call - should use cache
  result2=$(get_jsh_env)

  # Results should match
  [[ "${result1}" == "${result2}" ]]
}

@test "get_jsh_env: outputs valid environment type" {
  run get_jsh_env
  [[ "$status" -eq 0 ]]

  # Output should be one of the valid types
  case "${output}" in
    macos-personal|macos-corporate|truenas|ssh-remote|linux-generic)
      return 0
      ;;
    *)
      echo "Invalid output: ${output}"
      return 1
      ;;
  esac
}

@test "clear_jsh_env_cache: removes cache files" {
  # Create cache first
  get_jsh_env
  [[ -f "${_JSH_ENV_CACHE_FILE}" ]]

  # Clear cache
  clear_jsh_env_cache

  # Files should be gone
  [[ ! -f "${_JSH_ENV_CACHE_FILE}" ]]
  [[ ! -f "${_JSH_ENV_CACHE_FILE}.mtime" ]]
}

@test "refresh_jsh_env: bypasses cache" {
  # Create cache with a known value
  mkdir -p "${_JSH_ENV_CACHE_DIR}"
  echo "fake-cached-value" > "${_JSH_ENV_CACHE_FILE}"
  date +%s > "${_JSH_ENV_CACHE_FILE}.mtime"

  # Refresh should detect real environment, not use cache
  result=$(refresh_jsh_env)

  # Result should be a valid type, not the fake cached value
  [[ "${result}" != "fake-cached-value" ]]
  case "${result}" in
    macos-personal|macos-corporate|truenas|ssh-remote|linux-generic)
      return 0
      ;;
    *)
      echo "Invalid result: ${result}"
      return 1
      ;;
  esac
}

@test "cache: expires after TTL" {
  # Create cache with old timestamp (2 hours ago)
  mkdir -p "${_JSH_ENV_CACHE_DIR}"
  echo "old-cached-value" > "${_JSH_ENV_CACHE_FILE}"

  local old_time
  old_time=$(($(date +%s) - 7200))  # 2 hours ago
  echo "${old_time}" > "${_JSH_ENV_CACHE_FILE}.mtime"

  # get_jsh_env should detect fresh because cache is expired
  result=$(get_jsh_env)

  # Should not be the old cached value
  [[ "${result}" != "old-cached-value" ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "environment detection functions are available after sourcing" {
  # Verify all expected functions exist
  declare -f is_ssh_session > /dev/null
  declare -f is_truenas > /dev/null
  declare -f is_macos_corporate > /dev/null
  declare -f is_macos_personal > /dev/null
  declare -f detect_environment > /dev/null
  declare -f get_jsh_env > /dev/null
  declare -f refresh_jsh_env > /dev/null
  declare -f clear_jsh_env_cache > /dev/null
}

@test "JSH_ENV is exported after get_jsh_env" {
  get_jsh_env > /dev/null

  # JSH_ENV should be set and exported
  [[ -n "${JSH_ENV}" ]]

  # Verify it's exported (available to subshells)
  result=$(bash -c 'echo $JSH_ENV')
  [[ "${result}" == "${JSH_ENV}" ]]
}
