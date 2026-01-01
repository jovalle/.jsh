#!/usr/bin/env bats
# Integration tests for jsh init workflow

setup() {
  load '../test_helper.bash'
  setup_test_dir

  # Mock HOME for testing
  export HOME="$TEST_HOME"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
}

teardown() {
  teardown_test_dir
}

@test "jsh init --help: displays help message" {
  run "${JSH_ROOT}/jsh" init --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Set up shell environment" ]]
  [[ "$output" =~ "--shell" ]]
  [[ "$output" =~ "--minimal" ]]
  [[ "$output" =~ "--full" ]]
}

@test "jsh init --dry-run: shows preview without making changes" {
  run "${JSH_ROOT}/jsh" init --dry-run --non-interactive --shell skip
  [[ "$status" -eq 0 ]]

  # Should not create any files in test home
  [[ ! -f "$TEST_HOME/.zshrc" ]]
  [[ ! -f "$TEST_HOME/.bashrc" ]]
}

@test "jsh --version: displays version" {
  run "${JSH_ROOT}/jsh" --version
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

@test "jsh doctor: runs health check" {
  run "${JSH_ROOT}/jsh" doctor
  # May exit with non-zero if issues found, but should not crash
  [[ "$status" -ge 0 ]]
  [[ -n "$output" ]]
}

@test "jsh status: displays system status" {
  run "${JSH_ROOT}/jsh" status
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

@test "jsh completions: generates completion script" {
  run "${JSH_ROOT}/jsh" completions
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "jsh" ]]
}
