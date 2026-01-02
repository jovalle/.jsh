#!/usr/bin/env bats
# shellcheck disable=SC2154
# Integration tests for jsh dotfiles workflow

setup() {
  load '../test_helper.bash'
  setup_test_dir

  export HOME="$TEST_HOME"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
}

teardown() {
  teardown_test_dir
}

@test "jsh dotfiles --help: displays help message" {
  run "${JSH_ROOT}/jsh" dotfiles --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Manage dotfile symlinks" ]]
  [[ "$output" =~ "--status" ]]
  [[ "$output" =~ "--remove" ]]
}

@test "jsh dotfiles --status: shows symlink status" {
  run "${JSH_ROOT}/jsh" dotfiles --status
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

@test "jsh dotfiles: creates symlinks for dotfiles" {
  # This test requires actual dotfiles directory
  skip "Requires full integration test environment"
}

@test "jsh dotfiles --remove: removes dotfile symlinks" {
  # This test requires actual dotfiles to be linked first
  skip "Requires full integration test environment"
}
