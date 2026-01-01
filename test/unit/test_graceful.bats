#!/usr/bin/env bats
# Unit tests for src/lib/graceful.sh
# shellcheck disable=SC2154  # Variables from test_helper.bash

setup() {
  load '../test_helper.bash'

  # Create temp directory for testing
  setup_test_dir

  # Source the graceful degradation library
  source "${JSH_ROOT}/src/lib/graceful.sh"

  # Ensure JSH_DEBUG is unset by default
  unset JSH_DEBUG
}

teardown() {
  teardown_test_dir
  unset JSH_DEBUG
}

# ============================================================================
# _jsh_debug tests
# ============================================================================

@test "_jsh_debug: silent when JSH_DEBUG is unset" {
  unset JSH_DEBUG

  run _jsh_debug "test message"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "_jsh_debug: silent when JSH_DEBUG is empty" {
  JSH_DEBUG=""

  run _jsh_debug "test message"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "_jsh_debug: silent when JSH_DEBUG is 0" {
  JSH_DEBUG="0"

  run _jsh_debug "test message"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "_jsh_debug: outputs when JSH_DEBUG=1" {
  export JSH_DEBUG=1

  # Capture stderr since _jsh_debug writes to stderr
  run bash -c 'source "${JSH_ROOT}/src/lib/graceful.sh" && JSH_DEBUG=1 _jsh_debug "test message" 2>&1'
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"[jsh:debug] test message"* ]]
}

@test "_jsh_debug: outputs multiple arguments joined" {
  run bash -c 'source "${JSH_ROOT}/src/lib/graceful.sh" && JSH_DEBUG=1 _jsh_debug "hello" "world" 2>&1'
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"[jsh:debug] hello world"* ]]
}

# ============================================================================
# _jsh_try_source tests
# ============================================================================

@test "_jsh_try_source: sources existing readable file" {
  local test_file="${TEST_DIR}/test_source.sh"
  echo 'TEST_VAR="sourced_value"' > "$test_file"

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_source '$test_file' && echo \"\$TEST_VAR\""
  [[ "$status" -eq 0 ]]
  [[ "$output" == "sourced_value" ]]
}

@test "_jsh_try_source: returns 0 on successful source" {
  local test_file="${TEST_DIR}/test_source.sh"
  echo 'true' > "$test_file"

  run _jsh_try_source "$test_file"
  [[ "$status" -eq 0 ]]
}

@test "_jsh_try_source: returns 1 for missing file" {
  run _jsh_try_source "${TEST_DIR}/nonexistent_file.sh"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_source: returns 1 for unreadable file" {
  local test_file="${TEST_DIR}/unreadable.sh"
  echo 'true' > "$test_file"
  chmod 000 "$test_file"

  run _jsh_try_source "$test_file"
  [[ "$status" -eq 1 ]]

  # Cleanup
  chmod 644 "$test_file"
}

@test "_jsh_try_source: executes fallback on missing file" {
  local fallback_marker="${TEST_DIR}/fallback_executed"

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_source '${TEST_DIR}/missing.sh' 'touch ${fallback_marker}'"

  [[ -f "$fallback_marker" ]]
}

@test "_jsh_try_source: does not execute fallback on success" {
  local test_file="${TEST_DIR}/test_source.sh"
  local fallback_marker="${TEST_DIR}/fallback_executed"
  echo 'true' > "$test_file"

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_source '$test_file' 'touch ${fallback_marker}'"

  [[ ! -f "$fallback_marker" ]]
}

@test "_jsh_try_source: logs debug message when file not found" {
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && JSH_DEBUG=1 _jsh_try_source '${TEST_DIR}/missing.sh' 2>&1"
  [[ "$output" == *"skip source: file not found"* ]]
}

# ============================================================================
# _jsh_try_eval tests
# ============================================================================

@test "_jsh_try_eval: evals expression when command exists" {
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_eval 'ls' 'echo eval_worked'"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "eval_worked" ]]
}

@test "_jsh_try_eval: returns 0 when command exists and eval succeeds" {
  run _jsh_try_eval "ls" "true"
  [[ "$status" -eq 0 ]]
}

@test "_jsh_try_eval: returns 1 when command missing" {
  run _jsh_try_eval "nonexistent_command_xyz123" "echo should_not_run"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_eval: does not eval when command missing" {
  local marker="${TEST_DIR}/eval_marker"

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_eval 'nonexistent_xyz123' 'touch ${marker}'"

  [[ ! -f "$marker" ]]
}

@test "_jsh_try_eval: returns 1 when eval fails" {
  run _jsh_try_eval "ls" "false"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_eval: logs debug message when command not found" {
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && JSH_DEBUG=1 _jsh_try_eval 'nonexistent_xyz123' 'true' 2>&1"
  [[ "$output" == *"skip eval: command not found"* ]]
}

# ============================================================================
# _jsh_try_completion tests
# ============================================================================

@test "_jsh_try_completion: returns 1 for missing command" {
  run _jsh_try_completion "nonexistent_command_xyz123" "eval"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_completion: logs debug when command missing" {
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && JSH_DEBUG=1 _jsh_try_completion 'nonexistent_xyz123' 'eval' 2>&1"
  [[ "$output" == *"skip completion: command not found"* ]]
}

@test "_jsh_try_completion: loads completion via source method" {
  local completion_file="${TEST_DIR}/test_completion.sh"
  echo 'COMPLETION_LOADED=1' > "$completion_file"

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_try_completion 'ls' 'source' '$completion_file' && echo \"\$COMPLETION_LOADED\""
  [[ "$status" -eq 0 ]]
  [[ "$output" == "1" ]]
}

@test "_jsh_try_completion: returns 1 for source method with missing file" {
  run _jsh_try_completion "ls" "source" "${TEST_DIR}/missing_completion.sh"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_completion: returns 1 for unknown method" {
  run _jsh_try_completion "ls" "unknown_method"
  [[ "$status" -eq 1 ]]
}

@test "_jsh_try_completion: logs debug for unknown method" {
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && JSH_DEBUG=1 _jsh_try_completion 'ls' 'badmethod' 2>&1"
  [[ "$output" == *"unknown method"* ]]
}

# ============================================================================
# _jsh_with_timeout tests
# ============================================================================

@test "_jsh_with_timeout: completes fast command normally" {
  run _jsh_with_timeout 5 echo "hello"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "hello" ]]
}

@test "_jsh_with_timeout: returns command exit status" {
  run _jsh_with_timeout 5 false
  [[ "$status" -eq 1 ]]
}

@test "_jsh_with_timeout: returns 1 for no command provided" {
  run _jsh_with_timeout 5
  [[ "$status" -eq 1 ]]
}

@test "_jsh_with_timeout: uses default timeout of 2 seconds" {
  # This just tests that default works - actual timeout tested below
  run _jsh_with_timeout "" echo "default timeout"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "default timeout" ]]
}

@test "_jsh_with_timeout: times out slow command" {
  # Only run this test if timeout command is available
  if ! command -v timeout &>/dev/null && ! command -v gtimeout &>/dev/null; then
    skip "timeout command not available"
  fi

  run _jsh_with_timeout 1 sleep 10
  [[ "$status" -eq 124 ]]
}

@test "_jsh_with_timeout: executes command with arguments" {
  run _jsh_with_timeout 5 echo "arg1" "arg2" "arg3"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "arg1 arg2 arg3" ]]
}

# ============================================================================
# _jsh_ensure_has_dependency tests
# ============================================================================

@test "_jsh_ensure_has_dependency: loads dependencies.sh when has_dependency missing" {
  # Unset has_dependency if it exists
  unset -f has_dependency 2>/dev/null || true

  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' && _jsh_ensure_has_dependency && declare -f has_dependency >/dev/null && echo 'loaded'"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "loaded" ]]
}

@test "_jsh_ensure_has_dependency: returns 0 when has_dependency already available" {
  # Mock has_dependency
  has_dependency() { return 0; }

  run _jsh_ensure_has_dependency
  [[ "$status" -eq 0 ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "graceful library functions are available after sourcing" {
  declare -f _jsh_debug > /dev/null
  declare -f _jsh_try_source > /dev/null
  declare -f _jsh_try_eval > /dev/null
  declare -f _jsh_try_completion > /dev/null
  declare -f _jsh_with_timeout > /dev/null
  declare -f _jsh_ensure_has_dependency > /dev/null
}

@test "sourcing multiple times is safe" {
  source "${JSH_ROOT}/src/lib/graceful.sh"
  source "${JSH_ROOT}/src/lib/graceful.sh"
  source "${JSH_ROOT}/src/lib/graceful.sh"

  # Should still work
  declare -f _jsh_debug > /dev/null
  declare -f _jsh_try_source > /dev/null
}

@test "library does not auto-source dependencies.sh on load" {
  # Start fresh bash to verify no auto-sourcing
  run bash -c "source '${JSH_ROOT}/src/lib/graceful.sh' 2>&1 && ! declare -f _register_core_dependencies >/dev/null 2>&1 && echo 'not_loaded'"
  [[ "$output" == "not_loaded" ]]
}

@test "library has minimal sourcing overhead" {
  # Time sourcing the library - should be fast
  local start end elapsed

  start=$(date +%s%N 2>/dev/null || date +%s)

  for _ in {1..10}; do
    bash -c "source '${JSH_ROOT}/src/lib/graceful.sh'" 2>/dev/null
  done

  end=$(date +%s%N 2>/dev/null || date +%s)

  # If nanoseconds available, check < 1s total for 10 iterations
  # Otherwise skip detailed timing check
  if [[ "$start" =~ [0-9]{10,} ]]; then
    elapsed=$(( (end - start) / 1000000 ))  # Convert to milliseconds
    # 10 iterations should take < 1000ms total (100ms each avg)
    [[ "$elapsed" -lt 1000 ]]
  fi

  # Basic check: sourcing should succeed
  [[ "$?" -eq 0 ]]
}
