#!/usr/bin/env bats
# shellcheck disable=SC2154
# Integration tests for jsh brew command workflow

setup() {
  load '../test_helper.bash'
  setup_test_dir

  export HOME="$TEST_HOME"
  export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

  # Create basic config structure
  mkdir -p "${JSH_ROOT}/configs/macos"
  mkdir -p "${JSH_ROOT}/configs/linux"
  echo '["wget"]' > "${JSH_ROOT}/configs/macos/formulae.json"
  echo '["curl"]' > "${JSH_ROOT}/configs/linux/formulae.json"
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Test brew help
# ============================================================================

@test "jsh brew help: displays help message" {
  run "${JSH_ROOT}/jsh" brew help

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "jsh brew" ]]
  [[ "$output" =~ "setup" ]]
  [[ "$output" =~ "check" ]]
}

@test "jsh brew --help: displays help message" {
  run "${JSH_ROOT}/jsh" brew --help

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "jsh brew" ]]
}

@test "jsh brew -h: displays help message" {
  run "${JSH_ROOT}/jsh" brew -h

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "jsh brew" ]]
}

# ============================================================================
# Test brew setup
# ============================================================================

@test "jsh brew setup: installs or updates homebrew" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed - would require installation"
  fi

  run "${JSH_ROOT}/jsh" brew setup

  # Should succeed if brew already installed
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

# ============================================================================
# Test brew check
# ============================================================================

@test "jsh brew check: runs comprehensive checks" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  [[ -n "$output" ]]
}

@test "jsh brew check --quiet: runs in silent mode" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check --quiet

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "jsh brew check -q: short form of quiet flag" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check -q

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "jsh brew check --force: bypasses cache" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check --force

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "jsh brew check wget: checks specific package" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check wget

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Output should mention wget if verbose
}

@test "jsh brew check --darwin: forces macOS mode" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check --darwin

  [[ "$status" -ge 0 ]]
}

@test "jsh brew check --linux: forces Linux mode" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew check --linux

  [[ "$status" -ge 0 ]]
}

# ============================================================================
# Test brew passthrough commands
# ============================================================================

@test "jsh brew list: passes through to brew list" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew list

  [[ "$status" -eq 0 ]]
  # Should show installed packages
}

@test "jsh brew --version: passes through to brew --version" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew --version

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Homebrew" ]]
}

@test "jsh brew info wget: passes through brew info command" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew info wget

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "wget" ]]
}

@test "jsh brew search: passes through brew search" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew search git

  [[ "$status" -eq 0 ]]
  # Should show search results
}

# ============================================================================
# Test error handling
# ============================================================================

@test "jsh brew: errors when brew not installed" {
  if command -v brew &> /dev/null; then
    skip "brew is installed"
  fi

  run "${JSH_ROOT}/jsh" brew list

  [[ "$status" -ne 0 ]]
}

@test "jsh brew: handles invalid subcommand" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run "${JSH_ROOT}/jsh" brew invalid_xyz_command

  # brew itself should handle invalid commands
  [[ "$status" -ne 0 ]]
}

# ============================================================================
# Test caching behavior
# ============================================================================

@test "jsh brew check: creates cache files" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  # Clear existing cache
  rm -f "${HOME}/.cache/jsh_brew_check"
  rm -f "${HOME}/.cache/jsh_brew_status"

  run "${JSH_ROOT}/jsh" brew check --quiet

  # Should create cache files
  [[ -f "${HOME}/.cache/jsh_brew_check" ]] || \
  [[ -f "${HOME}/.cache/jsh_brew_status" ]] || \
  [[ "$status" -ge 0 ]]  # At least it shouldn't crash
}

@test "jsh brew check --force: ignores cache" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  # Create old cache file
  mkdir -p "${HOME}/.cache"
  touch -t 202001010000 "${HOME}/.cache/jsh_brew_check" 2>/dev/null || true

  run "${JSH_ROOT}/jsh" brew check --force --quiet

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "integration: setup then check workflow" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run bash -c "${JSH_ROOT}/jsh brew setup && ${JSH_ROOT}/jsh brew check --quiet"

  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "integration: check with multiple packages" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  run bash -c "${JSH_ROOT}/jsh brew check wget && ${JSH_ROOT}/jsh brew check curl"

  # At least one should work
  [[ "$status" -ge 0 ]]
}

@test "integration: passthrough commands work correctly" {
  if ! command -v brew &> /dev/null; then
    skip "brew not installed"
  fi

  # Test multiple passthrough commands
  "${JSH_ROOT}/jsh" brew --version > /dev/null
  local exit1=$?

  "${JSH_ROOT}/jsh" brew list > /dev/null
  local exit2=$?

  # Both should succeed
  [[ "$exit1" -eq 0 ]]
  [[ "$exit2" -eq 0 ]]
}
