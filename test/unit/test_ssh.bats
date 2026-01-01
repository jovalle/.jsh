#!/usr/bin/env bats
# Unit tests for src/lib/ssh.sh
# shellcheck disable=SC2154  # Variables from test_helper.bash

setup() {
  load '../test_helper.bash'

  # Create temp directory for testing
  setup_test_dir

  # Source the SSH library
  source "${JSH_ROOT}/src/lib/ssh.sh"

  # Ensure JSH_DEBUG is unset by default
  unset JSH_DEBUG
}

teardown() {
  teardown_test_dir
  unset JSH_DEBUG
}

# ============================================================================
# Dependency check tests
# ============================================================================

@test "_jsh_ssh_check_deps: returns 0 when tar and base64 exist" {
  # Both tar and base64 should be available on any Unix system
  run _jsh_ssh_check_deps
  [[ "$status" -eq 0 ]]
}

@test "_jsh_ssh_check_deps: returns 1 when tar missing" {
  # Create a restricted PATH without tar
  local restricted_path="${TEST_DIR}/bin"
  mkdir -p "$restricted_path"

  # Create a mock base64 that does nothing
  echo '#!/bin/bash' > "${restricted_path}/base64"
  chmod +x "${restricted_path}/base64"

  # Run with restricted PATH (no tar)
  run bash -c "export PATH='${restricted_path}'; source '${JSH_ROOT}/src/lib/ssh.sh' && _jsh_ssh_check_deps 2>/dev/null"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_ssh_check_deps: returns 1 when base64 missing" {
  # Create a restricted PATH without base64
  local restricted_path="${TEST_DIR}/bin"
  mkdir -p "$restricted_path"

  # Create a mock tar that does nothing
  echo '#!/bin/bash' > "${restricted_path}/tar"
  chmod +x "${restricted_path}/tar"

  # Run with restricted PATH (no base64)
  run bash -c "export PATH='${restricted_path}'; source '${JSH_ROOT}/src/lib/ssh.sh' && _jsh_ssh_check_deps 2>/dev/null"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_ssh_check_deps: shows error message when dependency missing" {
  # Create a restricted PATH without tar
  local restricted_path="${TEST_DIR}/bin"
  mkdir -p "$restricted_path"

  # Create a mock base64
  echo '#!/bin/bash' > "${restricted_path}/base64"
  chmod +x "${restricted_path}/base64"

  # Run with restricted PATH and capture stderr
  run bash -c "export PATH='${restricted_path}'; source '${JSH_ROOT}/src/lib/ssh.sh' && _jsh_ssh_check_deps 2>&1"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Missing required dependencies"* ]]
  [[ "$output" == *"tar"* ]]
}

# ============================================================================
# Config file location tests
# ============================================================================

@test "_jsh_ssh_get_minimal_config: returns path to .jshrc.ssh" {
  run _jsh_ssh_get_minimal_config
  [[ "$status" -eq 0 ]]
  [[ "$output" == *".jshrc.ssh"* ]]
}

@test "_jsh_ssh_get_minimal_config: path exists and is readable" {
  local config_path
  config_path=$(_jsh_ssh_get_minimal_config)
  [[ -f "$config_path" ]]
  [[ -r "$config_path" ]]
}

@test "_jsh_ssh_get_minimal_config: returns 1 when config missing" {
  # Point to a non-existent directory
  run bash -c "export JSH='/nonexistent/path'; source '${JSH_ROOT}/src/lib/ssh.sh' && _jsh_ssh_get_minimal_config"
  [[ "$status" -eq 1 ]]
}

# ============================================================================
# Bundle creation tests
# ============================================================================

@test "_jsh_ssh_bundle: produces non-empty output" {
  run _jsh_ssh_bundle
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

@test "_jsh_ssh_bundle: output is valid base64" {
  local payload
  payload=$(_jsh_ssh_bundle)
  [[ -n "$payload" ]]

  # Decode should succeed without error
  run bash -c "echo '${payload}' | base64 -d > /dev/null"
  [[ "$status" -eq 0 ]]
}

@test "_jsh_ssh_bundle: output is under 64KB" {
  local payload
  payload=$(_jsh_ssh_bundle)

  local payload_size=${#payload}
  [[ ${payload_size} -lt 65536 ]]
}

@test "_jsh_ssh_bundle: contains .jshrc.ssh when decoded" {
  local payload
  payload=$(_jsh_ssh_bundle)

  # Decode and extract to temp directory
  local extract_dir="${TEST_DIR}/extracted"
  mkdir -p "$extract_dir"

  echo "$payload" | base64 -d | tar xzf - -C "$extract_dir" 2>/dev/null

  # Check that .jshrc.ssh was extracted
  [[ -f "${extract_dir}/.jshrc.ssh" ]]
}

@test "_jsh_ssh_bundle: returns 1 when config missing" {
  run bash -c "export JSH='/nonexistent/path'; source '${JSH_ROOT}/src/lib/ssh.sh' && _jsh_ssh_bundle 2>/dev/null"
  [[ "$status" -eq 1 ]]
}

# ============================================================================
# Bundle decoding verification tests
# ============================================================================

@test "Decoded bundle extracts to valid tarball" {
  local payload
  payload=$(_jsh_ssh_bundle)

  # Decode to temp file
  local tarball="${TEST_DIR}/bundle.tar.gz"
  echo "$payload" | base64 -d > "$tarball"

  # Verify it's a valid gzipped tarball
  run file "$tarball"
  [[ "$output" == *"gzip"* ]] || [[ "$output" == *"compressed"* ]]

  # Verify tar can list contents
  run tar tzf "$tarball"
  [[ "$status" -eq 0 ]]
}

@test "Extracted tarball contains expected files" {
  local payload
  payload=$(_jsh_ssh_bundle)

  # Decode and extract
  local extract_dir="${TEST_DIR}/extracted"
  mkdir -p "$extract_dir"
  echo "$payload" | base64 -d | tar xzf - -C "$extract_dir"

  # Should contain .jshrc.ssh
  [[ -f "${extract_dir}/.jshrc.ssh" ]]

  # .jshrc.ssh should have content
  [[ -s "${extract_dir}/.jshrc.ssh" ]]
}

# ============================================================================
# Inject command building tests
# ============================================================================

@test "_jsh_ssh_inject_command: returns 1 with no arguments" {
  run _jsh_ssh_inject_command
  [[ "$status" -eq 1 ]]
}

@test "_jsh_ssh_inject_command: shows usage with no arguments" {
  run _jsh_ssh_inject_command 2>&1
  [[ "$output" == *"Usage"* ]]
}

@test "_jsh_ssh_inject_command: builds valid ssh command structure" {
  run _jsh_ssh_inject_command "testhost"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ssh"* ]]
  [[ "$output" == *"testhost"* ]]
}

@test "_jsh_ssh_inject_command: includes -t flag for TTY" {
  run _jsh_ssh_inject_command "testhost"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"-t"* ]]
}

@test "_jsh_ssh_inject_command: includes remote command with payload" {
  run _jsh_ssh_inject_command "testhost"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"JSH_PAYLOAD"* ]]
  [[ "$output" == *"base64"* ]]
  [[ "$output" == *"tar"* ]]
}

@test "_jsh_ssh_inject_command: preserves SSH arguments" {
  run _jsh_ssh_inject_command "testhost" "-p" "2222"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"-p"* ]]
  [[ "$output" == *"2222"* ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "ssh library functions are available after sourcing" {
  declare -f _jsh_ssh_check_deps > /dev/null
  declare -f _jsh_ssh_get_minimal_config > /dev/null
  declare -f _jsh_ssh_bundle > /dev/null
  declare -f _jsh_ssh_inject_command > /dev/null
  declare -f _jsh_ssh_cleanup_remote > /dev/null
}

@test "sourcing ssh.sh multiple times is safe" {
  source "${JSH_ROOT}/src/lib/ssh.sh"
  source "${JSH_ROOT}/src/lib/ssh.sh"
  source "${JSH_ROOT}/src/lib/ssh.sh"

  # Should still work
  declare -f _jsh_ssh_check_deps > /dev/null
  declare -f _jsh_ssh_bundle > /dev/null
}

@test "ssh library loads graceful.sh dependency" {
  # _jsh_debug should be available after sourcing ssh.sh
  declare -f _jsh_debug > /dev/null
}

@test "_jsh_ssh_cleanup_remote: shows cleanup information" {
  run _jsh_ssh_cleanup_remote
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"cleanup"* ]] || [[ "$output" == *"Cleanup"* ]]
}
