#!/usr/bin/env bats
# Unit tests for src/lib/dependencies.sh
# shellcheck disable=SC2154  # Variables from test_helper.bash

setup() {
  load '../test_helper.bash'

  # Create temp directory for testing
  setup_test_dir

  # Clear any existing SSH environment variables for clean tests
  unset SSH_CLIENT SSH_TTY SSH_CONNECTION

  # Source the dependencies library (which sources environment.sh and colors.sh)
  source "${JSH_ROOT}/src/lib/dependencies.sh"

  # Reset dependencies for each test
  _JSH_DEPS_INITIALIZED=""
  unset _JSH_DEPS
  declare -gA _JSH_DEPS
}

teardown() {
  teardown_test_dir
}

# ============================================================================
# Registration tests
# ============================================================================

@test "_register_dependency creates entry" {
  _register_dependency "test-dep" "cmd_exists ls" "true" "brew install test" "" "" "" ""

  [[ -n "${_JSH_DEPS[test-dep]:-}" ]]
}

@test "_register_dependency stores all metadata" {
  _register_dependency "my-tool" "cmd_exists my-tool" "false" "brew install my-tool" "IT install" "apt install" "ssh install" "linux install"

  local dep_data="${_JSH_DEPS[my-tool]}"

  # Verify the format contains expected fields
  [[ "$dep_data" == *"cmd_exists my-tool"* ]]
  [[ "$dep_data" == *"false"* ]]
  [[ "$dep_data" == *"brew install my-tool"* ]]
}

@test "duplicate registration is idempotent" {
  _register_dependency "dup-test" "cmd_exists ls" "true" "install1" "" "" "" ""
  local first="${_JSH_DEPS[dup-test]}"

  _register_dependency "dup-test" "cmd_exists ls" "true" "install1" "" "" "" ""
  local second="${_JSH_DEPS[dup-test]}"

  # Should be the same (second registration overwrites, but with same data)
  [[ "$first" == "$second" ]]
}

# ============================================================================
# Check function tests
# ============================================================================

@test "check_dependency returns 0 for existing command" {
  _register_dependency "existing-cmd" "cmd_exists ls" "true" "" "" "" "" ""

  run check_dependency "existing-cmd"
  [[ "$status" -eq 0 ]]
}

@test "check_dependency returns 1 for missing command" {
  _register_dependency "missing-cmd" "cmd_exists nonexistent_command_xyz123" "true" "" "" "" "" ""

  run check_dependency "missing-cmd"
  [[ "$status" -eq 1 ]]
}

@test "check_dependency returns 1 for unknown dependency" {
  run check_dependency "unknown-dep-xyz"
  [[ "$status" -eq 1 ]]
}

@test "check_all_dependencies counts missing required deps" {
  # Register some deps - ls exists, nonexistent does not
  _register_dependency "exists1" "cmd_exists ls" "true" "" "" "" "" ""
  _register_dependency "missing1" "cmd_exists nonexistent1_xyz" "true" "" "" "" "" ""
  _register_dependency "missing2" "cmd_exists nonexistent2_xyz" "true" "" "" "" "" ""
  _register_dependency "optional-missing" "cmd_exists nonexistent3_xyz" "false" "" "" "" "" ""

  run check_all_dependencies
  # Should report 2 missing required deps (missing1 and missing2)
  [[ "$output" == "2" ]]
}

@test "check_all_dependencies returns 0 when all present" {
  _register_dependency "exists1" "cmd_exists ls" "true" "" "" "" "" ""
  _register_dependency "exists2" "cmd_exists pwd" "true" "" "" "" "" ""

  run check_all_dependencies
  [[ "$output" == "0" ]]
  [[ "$status" -eq 0 ]]
}

@test "get_missing_dependencies lists missing deps" {
  _register_dependency "exists" "cmd_exists ls" "true" "" "" "" "" ""
  _register_dependency "missing" "cmd_exists nonexistent_xyz" "true" "" "" "" "" ""

  run get_missing_dependencies
  [[ "$output" == *"missing"* ]]
  [[ "$output" != *"exists"* ]]
}

@test "get_missing_dependencies --required filters to required only" {
  _register_dependency "req-missing" "cmd_exists nonexistent1_xyz" "true" "" "" "" "" ""
  _register_dependency "opt-missing" "cmd_exists nonexistent2_xyz" "false" "" "" "" "" ""

  run get_missing_dependencies --required
  [[ "$output" == *"req-missing"* ]]
  [[ "$output" != *"opt-missing"* ]]
}

@test "get_missing_dependencies --optional filters to optional only" {
  _register_dependency "req-missing" "cmd_exists nonexistent1_xyz" "true" "" "" "" "" ""
  _register_dependency "opt-missing" "cmd_exists nonexistent2_xyz" "false" "" "" "" "" ""

  run get_missing_dependencies --optional
  [[ "$output" != *"req-missing"* ]]
  [[ "$output" == *"opt-missing"* ]]
}

# ============================================================================
# Predicate tests
# ============================================================================

@test "has_dependency returns 0 for available dep" {
  _register_dependency "has-test" "cmd_exists ls" "true" "" "" "" "" ""

  run has_dependency "has-test"
  [[ "$status" -eq 0 ]]
}

@test "has_dependency returns 1 for missing dep" {
  _register_dependency "missing-test" "cmd_exists nonexistent_xyz" "true" "" "" "" "" ""

  run has_dependency "missing-test"
  [[ "$status" -eq 1 ]]
}

@test "require_dependency succeeds for available dep" {
  _register_dependency "req-test" "cmd_exists ls" "true" "" "" "" "" ""

  run require_dependency "req-test"
  [[ "$status" -eq 0 ]]
}

@test "require_dependency returns error for missing dep" {
  _register_dependency "req-missing" "cmd_exists nonexistent_xyz" "true" "install guide" "" "" "" ""

  # Unset the error function so require_dependency falls back to echo
  unset -f error 2>/dev/null || true

  run require_dependency "req-missing"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Required dependency missing"* ]] || [[ "$output" == *"Error"* ]]
}

# ============================================================================
# Reporting tests
# ============================================================================

@test "report_missing_dependencies outputs nothing when all present" {
  _register_dependency "present1" "cmd_exists ls" "true" "" "" "" "" ""
  _register_dependency "present2" "cmd_exists pwd" "false" "" "" "" "" ""

  run report_missing_dependencies
  [[ -z "$output" ]]
  [[ "$status" -eq 0 ]]
}

@test "report_missing_dependencies lists missing with guidance" {
  export JSH_ENV="macos-personal"
  _register_dependency "missing-report" "cmd_exists nonexistent_xyz" "true" "brew install it" "" "" "" ""

  run report_missing_dependencies
  [[ "$output" == *"missing-report"* ]]
  [[ "$output" == *"brew install it"* ]]
  [[ "$output" == *"REQUIRED"* ]]
}

@test "report_missing_dependencies shows optional tag" {
  export JSH_ENV="macos-personal"
  _register_dependency "opt-dep" "cmd_exists nonexistent_xyz" "false" "some guidance" "" "" "" ""

  run report_missing_dependencies
  [[ "$output" == *"optional"* ]]
}

@test "report_missing_dependencies --quiet suppresses output" {
  _register_dependency "quiet-test" "cmd_exists nonexistent_xyz" "true" "guidance" "" "" "" ""

  run report_missing_dependencies --quiet
  [[ -z "$output" ]]
}

@test "report_missing_dependencies --quiet returns correct status" {
  _register_dependency "req-missing" "cmd_exists nonexistent_xyz" "true" "" "" "" "" ""

  run report_missing_dependencies --quiet
  [[ "$status" -eq 1 ]]  # 1 because there's a missing required dep

  _JSH_DEPS=()
  _register_dependency "opt-missing" "cmd_exists nonexistent_xyz" "false" "" "" "" "" ""

  run report_missing_dependencies --quiet
  [[ "$status" -eq 0 ]]  # 0 because only optional is missing
}

# ============================================================================
# Environment-aware guidance tests
# ============================================================================

@test "guidance differs for macos-personal vs macos-corporate" {
  _register_dependency "env-test" "cmd_exists test-cmd" "true" \
    "personal guidance" "corporate guidance" "" "" ""

  export JSH_ENV="macos-personal"
  run _get_guidance "env-test"
  [[ "$output" == "personal guidance" ]]

  export JSH_ENV="macos-corporate"
  run _get_guidance "env-test"
  [[ "$output" == "corporate guidance" ]]
}

@test "guidance differs for truenas environment" {
  _register_dependency "truenas-test" "cmd_exists test-cmd" "true" \
    "" "" "truenas specific" "" ""

  export JSH_ENV="truenas"
  run _get_guidance "truenas-test"
  [[ "$output" == "truenas specific" ]]
}

@test "guidance differs for ssh-remote environment" {
  _register_dependency "ssh-test" "cmd_exists test-cmd" "true" \
    "" "" "" "ssh remote guidance" ""

  export JSH_ENV="ssh-remote"
  run _get_guidance "ssh-test"
  [[ "$output" == "ssh remote guidance" ]]
}

@test "guidance falls back to linux-generic when specific is empty" {
  _register_dependency "fallback-test" "cmd_exists test-cmd" "true" \
    "" "" "" "" "linux fallback"

  export JSH_ENV="macos-personal"
  run _get_guidance "fallback-test"
  [[ "$output" == "linux fallback" ]]
}

# ============================================================================
# Core dependencies tests
# ============================================================================

@test "_register_core_dependencies registers expected deps" {
  _register_core_dependencies

  # Check that expected core deps are registered
  [[ -n "${_JSH_DEPS[bash]:-}" ]]
  [[ -n "${_JSH_DEPS[jq]:-}" ]]
  [[ -n "${_JSH_DEPS[brew]:-}" ]]
  [[ -n "${_JSH_DEPS[fzf]:-}" ]]
  [[ -n "${_JSH_DEPS[git]:-}" ]]
  [[ -n "${_JSH_DEPS[zinit]:-}" ]]
}

@test "_register_core_dependencies is idempotent" {
  _register_core_dependencies
  local count1="${#_JSH_DEPS[@]}"

  _register_core_dependencies
  local count2="${#_JSH_DEPS[@]}"

  [[ "$count1" -eq "$count2" ]]
}

@test "bash dependency check works" {
  _register_core_dependencies

  # We're running in bash (via bats), so bash should pass
  run check_dependency "bash"
  [[ "$status" -eq 0 ]]
}

@test "jq dependency check works" {
  _register_core_dependencies

  # This test depends on whether jq is installed
  if command -v jq &>/dev/null; then
    run check_dependency "jq"
    [[ "$status" -eq 0 ]]
  else
    run check_dependency "jq"
    [[ "$status" -eq 1 ]]
  fi
}

# ============================================================================
# Custom check command tests
# ============================================================================

@test "custom check command with expression works" {
  _register_dependency "version-check" '[[ 5 -ge 4 ]]' "true" "" "" "" "" ""

  run check_dependency "version-check"
  [[ "$status" -eq 0 ]]
}

@test "custom check command with failing expression" {
  _register_dependency "version-fail" '[[ 3 -ge 5 ]]' "true" "" "" "" "" ""

  run check_dependency "version-fail"
  [[ "$status" -eq 1 ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "dependencies library functions are available after sourcing" {
  # Verify all expected functions exist
  declare -f check_dependency > /dev/null
  declare -f check_all_dependencies > /dev/null
  declare -f get_missing_dependencies > /dev/null
  declare -f report_missing_dependencies > /dev/null
  declare -f has_dependency > /dev/null
  declare -f require_dependency > /dev/null
  declare -f _register_dependency > /dev/null
  declare -f _register_core_dependencies > /dev/null
  declare -f _get_guidance > /dev/null
}

@test "sourcing multiple times is safe" {
  source "${JSH_ROOT}/src/lib/dependencies.sh"
  source "${JSH_ROOT}/src/lib/dependencies.sh"
  source "${JSH_ROOT}/src/lib/dependencies.sh"

  # Should still work
  run check_all_dependencies
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]  # Either is valid
}

@test "JSH_ENV is set after sourcing" {
  # Should have been set by sourcing dependencies.sh
  [[ -n "${JSH_ENV:-}" ]]
}

@test "full workflow: register, check, report" {
  export JSH_ENV="linux-generic"

  _register_dependency "workflow-present" "cmd_exists ls" "true" "" "" "" "" "apt install"
  _register_dependency "workflow-missing" "cmd_exists nonexistent_xyz" "true" "" "" "" "" "apt install missing"

  # Check individual
  has_dependency "workflow-present"
  run ! has_dependency "workflow-missing"
  [[ "$status" -eq 0 ]]

  # Check all
  run check_all_dependencies
  [[ "$output" == "1" ]]  # 1 required missing

  # Report
  run report_missing_dependencies
  [[ "$output" == *"workflow-missing"* ]]
  [[ "$output" != *"workflow-present"* ]]
}
