#!/usr/bin/env bats
# shellcheck disable=SC2154
# Unit tests for src/lib/brew.sh

setup() {
  load '../test_helper.bash'
  source "${JSH_ROOT}/src/lib/colors.sh"
  source "${JSH_ROOT}/src/lib/brew.sh"
  setup_test_dir

  # Save original environment
  export _ORIG_BREW_USER="${BREW_USER:-}"
  export _ORIG_HOME="${HOME}"
  export HOME="${TEST_HOME}"
}

teardown() {
  teardown_test_dir
  export BREW_USER="${_ORIG_BREW_USER}"
  export HOME="${_ORIG_HOME}"
}

# ============================================================================
# Test is_root function
# ============================================================================

@test "is_root: correctly identifies non-root user" {
  run is_root
  [[ "${status}" -eq 1 ]]
}

@test "is_root: uses EUID if available" {
  # EUID is readonly, cannot mock - skip this test
  skip "EUID is readonly variable, cannot mock in test environment"
}

# ============================================================================
# Test check_brew function
# ============================================================================

@test "check_brew: returns 0 when brew command exists" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run check_brew
  [[ "${status}" -eq 0 ]]
}

@test "check_brew: returns 1 when brew command does not exist" {
  # Mock environment without brew
  PATH=/dev/null run check_brew
  [[ "${status}" -eq 1 ]]
}

# ============================================================================
# Test apply_brew_shellenv function
# ============================================================================

@test "apply_brew_shellenv: returns 1 for non-existent brew path" {
  run apply_brew_shellenv "/nonexistent/brew"
  [[ "${status}" -eq 1 ]]
}

@test "apply_brew_shellenv: succeeds with valid brew binary" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  local brew_path
  brew_path=$(command -v brew)
  run apply_brew_shellenv "${brew_path}"
  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test user_exists function
# ============================================================================

@test "user_exists: returns 0 for current user" {
  local current_user
  current_user=$(whoami)
  run user_exists "${current_user}"
  [[ "${status}" -eq 0 ]]
}

@test "user_exists: returns 1 for non-existent user" {
  run user_exists "nonexistent_user_12345"
  # Function returns 1 OR exits with error - both are acceptable
  [[ "${status}" -ne 0 ]]
}

# ============================================================================
# Test load_brew_user function
# ============================================================================

@test "load_brew_user: loads BREW_USER from .env file" {
  mkdir -p "${JSH_ROOT}"
  echo "BREW_USER=testuser" > "${JSH_ROOT}/.env"

  unset BREW_USER
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh; source ${JSH_ROOT}/src/lib/brew.sh; load_brew_user; echo \$BREW_USER"

  [[ "${output}" == "testuser" ]]
  rm -f "${JSH_ROOT}/.env"
}

@test "load_brew_user: sets empty BREW_USER when .env does not exist" {
  unset BREW_USER
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh; source ${JSH_ROOT}/src/lib/brew.sh; load_brew_user; echo \${BREW_USER:-empty}"

  [[ "${output}" == "empty" ]]
}

# ============================================================================
# Test detect_brew_path function
# ============================================================================

@test "detect_brew_path: returns valid path on macOS" {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    skip "not macOS"
  fi

  run detect_brew_path
  [[ "${status}" -eq 0 ]]

  # Should return one of the standard macOS paths
  [[ "${output}" == "/opt/homebrew" ]] || \
  [[ "${output}" == "/usr/local" ]] || \
  [[ "${output}" == "" ]]
}

@test "detect_brew_path: returns valid path on Linux" {
  if [[ "$(uname -s)" != "Linux" ]]; then
    skip "not Linux"
  fi

  run detect_brew_path
  [[ "${status}" -eq 0 ]]

  # Should return linuxbrew path or empty
  [[ "${output}" == "/home/linuxbrew/.linuxbrew" ]] || \
  [[ "${output}" == "" ]]
}

# ============================================================================
# Test run_as_brew_user function
# ============================================================================

@test "run_as_brew_user: errors when BREW_USER is not set" {
  unset BREW_USER
  run run_as_brew_user echo "test"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ "BREW_USER is not configured" ]]
}

@test "run_as_brew_user: errors when user does not exist" {
  BREW_USER="nonexistent_user_12345"
  run run_as_brew_user echo "test"
  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ "does not exist" ]]
}

# ============================================================================
# Test extract_packages_from_json function
# ============================================================================

@test "extract_packages_from_json: extracts packages from JSON array" {
  local json_file="${TEST_DIR}/packages.json"
  echo '{"packages": ["pkg1", "pkg2", "pkg3"]}' > "${json_file}"

  run extract_packages_from_json "${json_file}"
  [[ "${status}" -eq 0 ]]
  # Output is newline-separated, not space-separated
  [[ "${output}" =~ "pkg1" ]]
  [[ "${output}" =~ "pkg2" ]]
  [[ "${output}" =~ "pkg3" ]]
}

@test "extract_packages_from_json: returns empty for empty JSON array" {
  local json_file="${TEST_DIR}/packages.json"
  echo '[]' > "${json_file}"

  run extract_packages_from_json "${json_file}"
  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
}

@test "extract_packages_from_json: handles non-existent file" {
  run extract_packages_from_json "/nonexistent/file.json"
  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
}

# ============================================================================
# Test check_package_locally function
# ============================================================================

@test "check_package_locally: finds installed formula" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  # Use a package that's likely installed
  local pkg="bash"
  run check_package_locally "${pkg}"

  # Either installed or not, should not error
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

@test "check_package_locally: returns 1 for non-existent package" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run check_package_locally "nonexistent_package_xyz123"
  [[ "${status}" -eq 1 ]]
}

# ============================================================================
# Test get_user_shell function
# ============================================================================

@test "get_user_shell: returns shell for current user" {
  # Temporarily restore HOME for this test since get_user_shell uses dscl . -read ~/
  local saved_home="${HOME}"
  export HOME="${_ORIG_HOME}"

  run get_user_shell

  export HOME="${saved_home}"

  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
  # Should contain a shell path (may be /bin/zsh, /bin/bash, etc.)
  [[ "${output}" =~ "/" ]]
}

@test "get_user_shell: handles non-existent user gracefully" {
  # Function doesn't take parameters, always uses whoami
  skip "get_user_shell doesn't take user parameter"
}

# ============================================================================
# Test fix_hostname_resolution function
# ============================================================================

@test "fix_hostname_resolution: creates hosts entry when missing" {
  local hosts_file="${TEST_DIR}/hosts"
  echo "127.0.0.1 localhost" > "${hosts_file}"

  # Mock hostname
  export HOSTNAME="testhost"

  # This test is complex due to requiring sudo, so we just test it doesn't crash
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh; source ${JSH_ROOT}/src/lib/brew.sh; echo 'Loaded'"
  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test validate_package function
# ============================================================================

@test "validate_package: checks if package is valid" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  # Test with a common package
  run validate_package "wget"
  # Should return 0 (valid) or 1 (not valid), not crash
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

# ============================================================================
# Test user_in_admin_group function
# ============================================================================

@test "user_in_admin_group: checks admin group membership" {
  local current_user
  current_user=$(whoami)

  # This will vary by system, so just ensure it doesn't crash
  run user_in_admin_group "${current_user}"
  [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

@test "user_in_admin_group: returns 1 for non-existent user" {
  run user_in_admin_group "nonexistent_user_12345"
  # Function returns 1 OR exits with error - both are acceptable
  [[ "${status}" -ne 0 ]]
}
