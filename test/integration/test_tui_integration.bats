#!/usr/bin/env bats
# Integration tests for TUI progress display

setup() {
  load '../test_helper.bash'
}

# =============================================================================
# Command Flag Integration
# =============================================================================

@test "jsh install --help shows --quiet flag" {
  run ./jsh install --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "--quiet" ]]
  [[ "$output" =~ "-q" ]]
}

@test "jsh install --help shows --no-progress flag" {
  run ./jsh install --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "--no-progress" ]]
}

@test "jsh upgrade --help shows --quiet flag" {
  run ./jsh upgrade --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "--quiet" ]]
  [[ "$output" =~ "-q" ]]
}

@test "jsh upgrade --help shows --no-progress flag" {
  run ./jsh upgrade --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "--no-progress" ]]
}

# =============================================================================
# TUI Library Loading
# =============================================================================

@test "tui.sh can be sourced without errors" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    echo 'ok'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ok" ]]
}

@test "tui.sh can be sourced multiple times safely" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    echo 'ok'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ok" ]]
}

@test "tui.sh requires colors.sh to be sourced first" {
  # TUI uses color constants like CYAN, GREEN, etc.
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    [[ -n \"\$CYAN\" ]] && echo 'colors available'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "colors available" ]]
}

# =============================================================================
# packages.sh TUI Integration
# =============================================================================

@test "packages.sh detects TUI functions when available" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    source '${JSH_ROOT}/src/lib/packages.sh'

    # Check if TUI detection works
    if declare -f tui_progress_start &>/dev/null; then
      echo 'tui detected'
    else
      echo 'tui not detected'
    fi
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "tui detected" ]]
}

@test "packages.sh works without TUI loaded" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    # Don't source tui.sh
    source '${JSH_ROOT}/src/lib/packages.sh'

    # Check TUI is not detected
    if declare -f tui_progress_start &>/dev/null; then
      echo 'tui detected'
    else
      echo 'tui not detected'
    fi
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "tui not detected" ]]
}

# =============================================================================
# Environment Variable Integration
# =============================================================================

@test "JSH_NO_TUI=1 disables TUI in fresh shell" {
  run bash -c "
    export JSH_NO_TUI=1
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'

    if tui_init; then
      echo 'tui enabled'
    else
      echo 'tui disabled'
    fi
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "tui disabled" ]]
}

@test "JSH_DEBUG_TUI=1 produces debug output" {
  run bash -c "
    export JSH_NO_TUI=1
    export JSH_DEBUG_TUI=1
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    tui_init 2>&1 || true
  " 2>&1
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "tui:debug" ]] || [[ "$output" =~ "TUI not supported" ]]
}

# =============================================================================
# Fallback Mode Full Workflow
# =============================================================================

@test "complete workflow in fallback mode" {
  run bash -c "
    export JSH_NO_TUI=1
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'

    tui_init || true

    tui_progress_start 'Installing packages' 3
    tui_progress_next 'package1'
    tui_success 'Installed package1'
    tui_progress_next 'package2'
    tui_warn 'Skipped package2'
    tui_progress_next 'package3'
    tui_success 'Installed package3'
    tui_progress_complete 'All done'

    echo 'workflow complete'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Installing packages" ]]
  [[ "$output" =~ "[1/3]" ]]
  [[ "$output" =~ "[2/3]" ]]
  [[ "$output" =~ "[3/3]" ]]
  [[ "$output" =~ "package1" ]]
  [[ "$output" =~ "package2" ]]
  [[ "$output" =~ "package3" ]]
  [[ "$output" =~ "All done" ]]
  [[ "$output" =~ "workflow complete" ]]
}

@test "spinner workflow in fallback mode" {
  run bash -c "
    export JSH_NO_TUI=1
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'

    tui_init || true

    # Spinner mode (total=0)
    tui_progress_start 'Processing' 0
    tui_log 'Working...'
    tui_progress_complete 'Done'

    echo 'spinner complete'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Processing" ]]
  [[ "$output" =~ "Working" ]]
  [[ "$output" =~ "Done" ]]
  [[ "$output" =~ "spinner complete" ]]
}

# =============================================================================
# Error Handling
# =============================================================================

@test "tui functions handle signals gracefully" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    export JSH_NO_TUI=1

    tui_init || true
    tui_progress_start 'Test' 10

    # Simulate cleanup on signal
    tui_cleanup

    echo 'signal handled'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "signal handled" ]]
}

@test "tui_cleanup removes trap safely" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    export JSH_NO_TUI=1

    tui_init || true
    tui_cleanup

    # Verify trap is removed (no error on second cleanup)
    tui_cleanup

    echo 'traps handled'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "traps handled" ]]
}

# =============================================================================
# Syntax Validation
# =============================================================================

@test "tui.sh passes shellcheck (errors only)" {
  if ! command -v shellcheck &>/dev/null; then
    skip "shellcheck not installed"
  fi

  # Only check for actual errors, not style suggestions
  # SC2154: Variables like CYAN, RESET are from colors.sh (external source)
  # SC2250: Style preference for braces around variables
  # SC2183: printf %*s is valid (width specifier)
  # SC2312: Info about return values
  run shellcheck -x -e SC2154 -e SC2250 -e SC2183 -e SC2312 --severity=error "${JSH_ROOT}/src/lib/tui.sh"
  [[ "$status" -eq 0 ]]
}

@test "install_command.sh passes bash syntax check" {
  run bash -n "${JSH_ROOT}/src/install_command.sh"
  [[ "$status" -eq 0 ]]
}

@test "upgrade_command.sh passes bash syntax check" {
  run bash -n "${JSH_ROOT}/src/upgrade_command.sh"
  [[ "$status" -eq 0 ]]
}
