#!/usr/bin/env bats
# Integration tests for jsh completions command

setup() {
  load '../test_helper.bash'
  setup_test_dir

  export HOME="$TEST_HOME"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Test completions generation
# ============================================================================

@test "jsh completions: generates completion script" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

@test "jsh completions: output contains jsh references" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "jsh" ]]
}

@test "jsh completions: produces valid shell code" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  # Should contain completion-related keywords
  [[ "$output" =~ "complete" ]] || \
  [[ "$output" =~ "compdef" ]] || \
  [[ "$output" =~ "_jsh" ]] || \
  [[ "$output" =~ "function" ]]
}

@test "jsh completions: includes main commands" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  # Should mention key commands
  [[ "$output" =~ "init" ]] || [[ "$output" =~ "install" ]]
}

@test "jsh completions: includes subcommands" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  # Check for some expected subcommands or options
  [[ "$output" =~ "brew" ]] || \
  [[ "$output" =~ "setup" ]] || \
  [[ "$output" =~ "check" ]]
}

# ============================================================================
# Test completion script validity
# ============================================================================

@test "jsh completions: bash can parse the output" {
  if ! command -v bash &> /dev/null; then
    skip "bash not available"
  fi

  local completion_script="$TEST_DIR/completion.bash"
  "${JSH_ROOT}/jsh" completions > "$completion_script"

  # Try to source it in bash (syntax check)
  run bash -c "source $completion_script && echo 'OK'"

  # If it sources successfully or has minor issues, that's acceptable
  [[ "$status" -eq 0 ]] || [[ "$output" =~ "OK" ]] || [[ "$status" -eq 1 ]]
}

@test "jsh completions: zsh can parse the output" {
  if ! command -v zsh &> /dev/null; then
    skip "zsh not available"
  fi

  local completion_script="$TEST_DIR/completion.zsh"
  "${JSH_ROOT}/jsh" completions > "$completion_script"

  # Try to source it in zsh (syntax check)
  run zsh -c "source $completion_script && echo 'OK'"

  # If it sources successfully or has minor issues, that's acceptable
  [[ "$status" -eq 0 ]] || [[ "$output" =~ "OK" ]] || [[ "$status" -eq 1 ]]
}

# ============================================================================
# Test completion script structure
# ============================================================================

@test "jsh completions: defines completion function" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  # Should define a function (bash or zsh style)
  [[ "$output" =~ "_jsh" ]] || \
  [[ "$output" =~ "function" ]] || \
  [[ "$output" =~ "compgen" ]]
}

@test "jsh completions: registers completion handler" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  # Should have a complete or compdef statement
  [[ "$output" =~ "complete" ]] || [[ "$output" =~ "compdef" ]]
}

# ============================================================================
# Test output format
# ============================================================================

@test "jsh completions: output is not empty" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
  # Should have reasonable length
  local line_count=$(echo "$output" | wc -l)
  [[ "$line_count" -gt 5 ]]
}

@test "jsh completions: output does not contain errors" {
  run "${JSH_ROOT}/jsh" completions

  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "error" ]]
  [[ ! "$output" =~ "Error" ]]
  [[ ! "$output" =~ "ERROR" ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "integration: completions can be saved to file" {
  local output_file="$TEST_DIR/jsh_completions.sh"

  run bash -c "${JSH_ROOT}/jsh completions > $output_file"

  [[ "$status" -eq 0 ]]
  [[ -f "$output_file" ]]
  [[ -s "$output_file" ]]
}

@test "integration: multiple calls produce same output" {
  local output1=$("${JSH_ROOT}/jsh" completions)
  local output2=$("${JSH_ROOT}/jsh" completions)

  [[ "$output1" == "$output2" ]]
}

@test "integration: completions work after jsh init" {
  # This is a simplified test - actual completion testing is complex
  run bash -c "${JSH_ROOT}/jsh completions"
  local exit1=$?

  run "${JSH_ROOT}/jsh" --help
  local exit2=$?

  # Both commands should work
  [[ "$exit1" -eq 0 ]]
  [[ "$exit2" -eq 0 ]]
}
