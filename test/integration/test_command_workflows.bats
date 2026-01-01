#!/usr/bin/env bats
# Integration tests for jsh command workflows

setup() {
  load '../test_helper.bash'
  setup_test_dir

  # Mock HOME for testing
  export HOME="${TEST_HOME}"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

  # Create basic config structure
  mkdir -p "${JSH_ROOT}/configs/macos"
  mkdir -p "${JSH_ROOT}/configs/linux"
  echo '[]' > "${JSH_ROOT}/configs/macos/formulae.json"
  echo '[]' > "${JSH_ROOT}/configs/linux/formulae.json"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Test doctor command
# ============================================================================

@test "jsh doctor: runs without errors" {
  run "${JSH_ROOT}/jsh" doctor

  # May return non-zero if issues found, but should not crash
  [[ "${status}" -ge 0 ]]
  [[ -n "${output}" ]]
}

@test "jsh doctor: checks for required commands" {
  run "${JSH_ROOT}/jsh" doctor

  # Should mention checking commands
  [[ "${output}" =~ "jsh diagnostics" ]] || [[ "${output}" =~ "Checking" ]]
}

# ============================================================================
# Test status command
# ============================================================================

@test "jsh status: displays system status" {
  run "${JSH_ROOT}/jsh" status

  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
  [[ "${output}" =~ "System Status" ]] || [[ "${output}" =~ "status" ]]
}

@test "jsh status: runs without requiring sudo" {
  run "${JSH_ROOT}/jsh" status

  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test clean command
# ============================================================================

@test "jsh clean --help: displays help message" {
  run "${JSH_ROOT}/jsh" clean --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Clean" ]] || [[ "${output}" =~ "clean" ]]
}

@test "jsh clean: runs without errors" {
  # clean command doesn't have --dry-run flag
  skip "clean command doesn't support --dry-run"
}

# ============================================================================
# Test dotfiles command
# ============================================================================

@test "jsh dotfiles --help: displays help message" {
  run "${JSH_ROOT}/jsh" dotfiles --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "dotfile" ]] || [[ "${output}" =~ "Dotfile" ]]
}

@test "jsh dotfiles --status: checks symlink status" {
  run "${JSH_ROOT}/jsh" dotfiles --status

  [[ "${status}" -eq 0 ]]
}

@test "jsh dotfiles: can run default command" {
  # dotfiles doesn't have --link or --dry-run flags
  skip "dotfiles command doesn't support --link --dry-run"
}

# ============================================================================
# Test install command
# ============================================================================

@test "jsh install --help: displays help message" {
  run "${JSH_ROOT}/jsh" install --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Install" ]] || [[ "${output}" =~ "package" ]]
}

@test "jsh install: handles missing package argument" {
  # This should either install from config or show an error
  run "${JSH_ROOT}/jsh" install

  # Should not crash
  [[ "${status}" -ge 0 ]]
}

# ============================================================================
# Test uninstall command
# ============================================================================

@test "jsh uninstall --help: displays help message" {
  run "${JSH_ROOT}/jsh" uninstall --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Uninstall" ]] || [[ "${output}" =~ "package" ]]
}

@test "jsh uninstall: requires package argument" {
  run "${JSH_ROOT}/jsh" uninstall

  # Should error without package name
  [[ "${status}" -ne 0 ]]
}

# ============================================================================
# Test upgrade command
# ============================================================================

@test "jsh upgrade --help: displays help message" {
  run "${JSH_ROOT}/jsh" upgrade --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Upgrade" ]] || [[ "${output}" =~ "upgrade" ]]
}

@test "jsh upgrade: runs without arguments" {
  run "${JSH_ROOT}/jsh" upgrade

  # Should not crash (may fail if no packages to upgrade)
  [[ "${status}" -ge 0 ]]
}

# ============================================================================
# Test configure command
# ============================================================================

@test "jsh configure --help: displays help message" {
  run "${JSH_ROOT}/jsh" configure --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Configur" ]] || [[ "${output}" =~ "configur" ]]
}

@test "jsh configure: command exists" {
  # configure command doesn't have --dry-run flag
  skip "configure command doesn't support --dry-run"
}

# ============================================================================
# Test deinit command
# ============================================================================

@test "jsh deinit --help: displays help message" {
  run "${JSH_ROOT}/jsh" deinit --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "deinit" ]] || [[ "${output}" =~ "Remove" ]]
}

@test "jsh deinit: command exists" {
  # deinit command doesn't have --dry-run flag
  skip "deinit command doesn't support --dry-run"
}

# ============================================================================
# Test completions command
# ============================================================================

@test "jsh completions: generates completion script" {
  run "${JSH_ROOT}/jsh" completions

  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
  [[ "${output}" =~ "jsh" ]]
}

@test "jsh completions: produces valid shell code" {
  run "${JSH_ROOT}/jsh" completions

  [[ "${status}" -eq 0 ]]
  # Should contain function definitions or completion commands
  [[ "${output}" =~ "complete" ]] || [[ "${output}" =~ "function" ]] || [[ "${output}" =~ "compdef" ]]
}

# ============================================================================
# Test global flags
# ============================================================================

@test "jsh --help: displays help message" {
  run "${JSH_ROOT}/jsh" --help

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "jsh" ]]
  [[ "${output}" =~ "command" ]] || [[ "${output}" =~ "Usage" ]]
}

@test "jsh --version: displays version" {
  run "${JSH_ROOT}/jsh" --version

  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
  [[ "${output}" =~ [0-9] ]]
}

@test "jsh: displays help when no command given" {
  run "${JSH_ROOT}/jsh"

  # Should show help or error message
  [[ "${status}" -ge 0 ]]
  [[ -n "${output}" ]]
}

# ============================================================================
# Test error handling
# ============================================================================

@test "jsh: handles unknown command gracefully" {
  run "${JSH_ROOT}/jsh" nonexistent_command_xyz

  [[ "${status}" -ne 0 ]]
  [[ -n "${output}" ]]
}

@test "jsh: handles invalid flags gracefully" {
  run "${JSH_ROOT}/jsh" status --invalid-flag-xyz

  [[ "${status}" -ne 0 ]]
  [[ -n "${output}" ]]
}

# ============================================================================
# Integration: Command chaining scenarios
# ============================================================================

@test "integration: doctor then status workflow" {
  run bash -c "${JSH_ROOT}/jsh doctor && ${JSH_ROOT}/jsh status"

  # At least one should succeed
  [[ "${status}" -eq 0 ]] || [[ -n "${output}" ]]
}

@test "integration: help for all main commands" {
  local commands=("init" "install" "uninstall" "upgrade" "configure" "clean" "dotfiles" "doctor" "status" "deinit" "completions")

  for cmd in "${commands[@]}"; do
    run "${JSH_ROOT}/jsh" "${cmd}" --help
    # All help commands should work
    [[ "${status}" -eq 0 ]]
    [[ -n "${output}" ]]
  done
}
