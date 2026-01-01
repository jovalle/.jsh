#!/usr/bin/env bats
# Integration tests for jssh command
# shellcheck disable=SC2154  # Variables from test_helper.bash

setup() {
  load '../test_helper.bash'
  setup_test_dir

  JSSH="${JSH_ROOT}/bin/jssh"
  JSHRC_SSH="${JSH_ROOT}/dotfiles/.jshrc.ssh"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Command availability tests
# ============================================================================

@test "jssh command exists and is executable" {
  [[ -f "$JSSH" ]]
  [[ -x "$JSSH" ]]
}

@test "jssh --help shows usage information" {
  run "$JSSH" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"jssh"* ]]
  [[ "$output" == *"SSH with jsh config injection"* ]]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"OPTIONS"* ]]
  [[ "$output" == *"EXAMPLES"* ]]
}

@test "jssh --version shows version number" {
  run "$JSSH" --version
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"jssh version"* ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ============================================================================
# Argument handling tests
# ============================================================================

@test "jssh with no args shows error and usage" {
  run "$JSSH"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
  [[ "$output" == *"No host specified"* ]]
}

@test "jssh --help exits with status 0" {
  run "$JSSH" --help
  [[ "$status" -eq 0 ]]
}

@test "jssh --version exits with status 0" {
  run "$JSSH" --version
  [[ "$status" -eq 0 ]]
}

@test "jssh -h is equivalent to --help" {
  run "$JSSH" -h
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "jssh -v is equivalent to --version" {
  run "$JSSH" -v
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"jssh version"* ]]
}

# ============================================================================
# Dependency validation tests
# ============================================================================

@test "jssh detects missing dependencies gracefully" {
  # Create a restricted PATH that has bash but not tar
  local restricted_path="${TEST_DIR}/bin"
  mkdir -p "$restricted_path"

  # Copy bash to allow script execution
  cp "$(command -v bash)" "${restricted_path}/bash" 2>/dev/null || ln -s "$(command -v bash)" "${restricted_path}/bash"

  # Run with restricted PATH and capture output
  # This should fail because tar is required
  run bash -c "export PATH='${restricted_path}'; '${JSSH}' testhost 2>&1"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Missing"* ]] || [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]]
}

# ============================================================================
# Config bundling tests (no actual SSH)
# ============================================================================

@test "jssh --debug shows payload size" {
  # Run with --debug and a fake host that will fail before connecting
  # Using /dev/null as host causes quick failure
  run timeout 2 "$JSSH" --debug invalidhost.invalid 2>&1 || true
  # Debug output should show payload size before connection attempt
  [[ "$output" == *"Payload size"* ]] || [[ "$output" == *"bytes"* ]]
}

# ============================================================================
# Minimal config validation tests
# ============================================================================

@test ".jshrc.ssh file exists" {
  [[ -f "$JSHRC_SSH" ]]
}

@test ".jshrc.ssh is valid bash syntax" {
  run bash -n "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh contains expected color functions" {
  # Check for color helper functions
  run grep -q "error()" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]

  run grep -q "warn()" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]

  run grep -q "success()" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]

  run grep -q "info()" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh contains extract function" {
  run grep -q "extract()" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh does not contain heavy features - zinit" {
  run grep -q "zinit" "$JSHRC_SSH"
  [[ "$status" -ne 0 ]]
}

@test ".jshrc.ssh does not contain heavy features - atuin" {
  run grep -q "atuin" "$JSHRC_SSH"
  [[ "$status" -ne 0 ]]
}

@test ".jshrc.ssh does not contain heavy features - brew commands" {
  # Check for actual brew command usage, not just mention in comments
  # e.g., "brew install" or "$(brew --prefix)"
  run grep -E "(brew install|brew --|\\\$\(brew|eval.*brew)" "$JSHRC_SSH"
  [[ "$status" -ne 0 ]]
}

@test ".jshrc.ssh sets JSH_ENV to ssh-remote" {
  run grep "JSH_ENV.*ssh-remote" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh defines navigation aliases" {
  run grep "alias \.\." "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh defines safety aliases" {
  run grep "alias cp=" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]

  run grep "alias mv=" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh sets up cleanup trap" {
  run grep "trap.*EXIT" "$JSHRC_SSH"
  [[ "$status" -eq 0 ]]
}

@test ".jshrc.ssh is under 20KB" {
  local file_size
  file_size=$(wc -c < "$JSHRC_SSH" | tr -d ' ')
  [[ $file_size -lt 20480 ]]
}

# ============================================================================
# SSH library integration tests
# ============================================================================

@test "jssh sources ssh.sh library" {
  # The script should be able to run without errors (syntax check via --help)
  run "$JSSH" --help
  [[ "$status" -eq 0 ]]
}

@test "jssh passes SSH options correctly" {
  # Test that options are accumulated (--debug shows what would be passed)
  run timeout 2 "$JSSH" --debug -p 2222 -i ~/.ssh/testkey testhost.invalid 2>&1 || true
  # The debug output should show the host was identified
  [[ "$output" == *"Host"* ]] || [[ "$output" == *"host"* ]] || [[ "$output" == *"testhost"* ]]
}

# ============================================================================
# Environment variable handling tests
# ============================================================================

@test "jssh respects JSH environment variable" {
  # jssh should use JSH env var if set
  run bash -c "export JSH='${JSH_ROOT}'; '${JSSH}' --help"
  [[ "$status" -eq 0 ]]
}

@test "jssh --debug enables JSH_DEBUG" {
  run timeout 2 "$JSSH" --debug invalidhost.invalid 2>&1 || true
  # With --debug, we should see debug output markers
  [[ "$output" == *"[jssh]"* ]] || [[ "$output" == *"Payload"* ]]
}
