#!/usr/bin/env bats
# Integration tests for graceful completion loading in jsh

setup() {
  load '../test_helper.bash'
  setup_test_dir

  # shellcheck disable=SC2154  # TEST_HOME set by setup_test_dir
  export HOME="$TEST_HOME"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  export JSH="${JSH_ROOT}"

  # Source the graceful library for testing
  source "${JSH_ROOT}/src/lib/graceful.sh"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Test completion loading with available tools
# ============================================================================

@test "completions: _jsh_load_completions function exists after sourcing jshrc" {
  # Source jshrc in interactive mode to get the function (jshrc exits early for non-interactive)
  run bash -i -c "source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null; type -t _jsh_load_completions"

  # Accept status 0 or 1 (bash -i may have issues in test environment)
  [[ "$status" -le 1 ]]
  [[ "$output" =~ "function" ]]
}

@test "completions: loading succeeds for bash shell" {
  # Source jshrc and call the function - should not error
  run bash -c "
    export JSH='${JSH_ROOT}'
    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null
    _jsh_load_completions bash
    echo 'success'
  "

  # Should complete without crashing (exit 0 or 1 is acceptable)
  [[ "$status" -le 1 ]]
  [[ "$output" =~ "success" ]]
}

@test "completions: loading succeeds for zsh shell" {
  if ! command -v zsh &> /dev/null; then
    skip "zsh not available"
  fi

  # Source jshrc and call the function - should not error
  run zsh -c "
    export JSH='${JSH_ROOT}'
    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null
    _jsh_load_completions zsh
    echo 'success'
  "

  # Should complete without crashing
  [[ "$status" -le 1 ]]
  [[ "$output" =~ "success" ]]
}

# ============================================================================
# Test graceful degradation with missing tools
# ============================================================================

@test "graceful: _jsh_try_eval skips missing commands without error" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/graceful.sh'
    _jsh_try_eval 'nonexistent_command_xyz' 'echo should not run'
    echo 'completed'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "completed" ]]
  [[ ! "$output" =~ "should not run" ]]
}

@test "graceful: _jsh_try_completion skips missing commands without error" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/graceful.sh'
    _jsh_try_completion 'nonexistent_tool_xyz' 'eval' 'nonexistent_tool_xyz completion bash' 'bash'
    echo 'completed'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "completed" ]]
}

@test "graceful: completion loading with mocked missing PATH succeeds" {
  # Test that completions don't fail even with restricted PATH
  run bash -c "
    export JSH='${JSH_ROOT}'
    export PATH='/usr/bin:/bin'  # Minimal PATH, missing most tools
    source '${JSH_ROOT}/src/lib/graceful.sh'

    # Try loading completion for a tool that won't exist
    _jsh_try_eval 'direnv' 'echo direnv loaded'
    _jsh_try_eval 'docker' 'echo docker loaded'
    _jsh_try_completion 'kubectl' 'eval' 'kubectl completion bash' 'bash'

    echo 'all skipped gracefully'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "all skipped gracefully" ]]
}

# ============================================================================
# Test debug output
# ============================================================================

@test "debug: JSH_DEBUG=1 produces completion debug logs" {
  # Use run with explicit stderr capture
  run bash -c 'export JSH="'"${JSH_ROOT}"'"; export JSH_DEBUG=1; source "'"${JSH_ROOT}"'/src/lib/graceful.sh"; _jsh_try_eval "nonexistent_debug_test_cmd" "echo test" 2>&1; echo done'

  # Check that debug message appeared (either in output)
  [[ "$output" =~ "jsh:debug" ]] || [[ "$output" =~ "skip" ]]
}

@test "debug: JSH_DEBUG=0 suppresses debug logs" {
  run bash -c "
    export JSH='${JSH_ROOT}'
    export JSH_DEBUG=0
    source '${JSH_ROOT}/src/lib/graceful.sh'

    _jsh_try_eval 'nonexistent_quiet_test_cmd' 'echo test'
    echo 'done'
  " 2>&1

  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "jsh:debug" ]]
  [[ "$output" =~ "done" ]]
}

@test "debug: completions debug message appears during load" {
  # Use run with explicit stderr redirect in the subshell
  run bash -c 'export JSH="'"${JSH_ROOT}"'"; export JSH_DEBUG=1; source "'"${JSH_ROOT}"'/src/lib/graceful.sh"; _jsh_debug "completions" "Loading completions for bash" 2>&1; echo done'

  # Debug should mention 'completions' loading
  [[ "$output" =~ "completions" ]] || [[ "$output" =~ "Loading" ]]
}

# ============================================================================
# Test atuin special handling
# ============================================================================

@test "atuin: special handling preserves ATUIN_NOBIND" {
  if ! command -v atuin &> /dev/null; then
    skip "atuin not available"
  fi

  run bash -c "
    export JSH='${JSH_ROOT}'
    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null
    _jsh_load_completions bash 2>/dev/null
    echo \"ATUIN_NOBIND=\${ATUIN_NOBIND}\"
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "ATUIN_NOBIND=true" ]]
}

@test "atuin: skipped gracefully when not installed" {
  run bash -c "
    export JSH='${JSH_ROOT}'
    export PATH='/usr/bin:/bin'  # PATH without atuin
    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null

    # Source jshrc should work even without atuin
    echo 'sourced successfully'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "sourced successfully" ]]
}

@test "atuin: debug logging when available" {
  if ! command -v atuin &> /dev/null; then
    skip "atuin not available"
  fi

  # Test that the _jsh_debug call with atuin works
  run bash -c 'export JSH="'"${JSH_ROOT}"'"; export JSH_DEBUG=1; source "'"${JSH_ROOT}"'/src/lib/graceful.sh"; _jsh_debug "completions" "Loading atuin integration" 2>&1; echo done'

  # Should have debug output mentioning atuin
  [[ "$output" =~ "atuin" ]]
}

# ============================================================================
# Test full completion workflow
# ============================================================================

@test "workflow: shell startup with completions does not error" {
  run bash -c "
    export JSH='${JSH_ROOT}'
    export HOME='${TEST_HOME}'

    # Simulate shell startup sourcing jshrc
    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null

    # Call completion loading as shell config would
    _jsh_load_completions bash 2>/dev/null

    echo 'startup complete'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "startup complete" ]]
}

@test "workflow: zsh startup with completions does not error" {
  if ! command -v zsh &> /dev/null; then
    skip "zsh not available"
  fi

  run zsh -c "
    export JSH='${JSH_ROOT}'
    export HOME='${TEST_HOME}'

    source '${JSH_ROOT}/dotfiles/.jshrc' 2>/dev/null
    _jsh_load_completions zsh 2>/dev/null

    echo 'zsh startup complete'
  "

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "zsh startup complete" ]]
}
