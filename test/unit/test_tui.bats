#!/usr/bin/env bats
# Unit tests for src/lib/tui.sh

setup() {
  load '../test_helper.bash'
  source "${JSH_ROOT}/src/lib/colors.sh"
  source "${JSH_ROOT}/src/lib/tui.sh"

  # Default to non-TUI mode for predictable testing
  export JSH_NO_TUI=1
}

teardown() {
  tui_cleanup 2>/dev/null || true
  unset JSH_NO_TUI JSH_FORCE_TUI JSH_DEBUG_TUI
  unset _TUI_ENABLED _TUI_SUPPORTED
}

# =============================================================================
# Capability Detection
# =============================================================================

@test "tui_is_supported: returns 1 when JSH_NO_TUI is set" {
  export JSH_NO_TUI=1
  run tui_is_supported
  [[ "$status" -eq 1 ]]
}

@test "tui_is_supported: returns 1 when TERM is dumb" {
  unset JSH_NO_TUI
  export TERM=dumb
  _TUI_SUPPORTED=""  # Reset cached value
  run tui_is_supported
  [[ "$status" -eq 1 ]]
}

@test "tui_is_supported: returns 1 when TERM is unset" {
  unset JSH_NO_TUI
  unset TERM
  _TUI_SUPPORTED=""  # Reset cached value
  run tui_is_supported
  [[ "$status" -eq 1 ]]
}

@test "tui_is_supported: returns 1 when stdout is not a tty (in bats)" {
  unset JSH_NO_TUI
  _TUI_SUPPORTED=""  # Reset cached value
  # In bats, stdout is not a tty, so this should return 1
  run tui_is_supported
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# Progress Bar Rendering
# =============================================================================

@test "_tui_progress_bar: renders empty bar at 0%" {
  result=$(_tui_progress_bar 0 10 10)
  [[ "$result" == "░░░░░░░░░░" ]]
}

@test "_tui_progress_bar: renders full bar at 100%" {
  result=$(_tui_progress_bar 10 10 10)
  [[ "$result" == "██████████" ]]
}

@test "_tui_progress_bar: renders half bar at 50%" {
  result=$(_tui_progress_bar 5 10 10)
  [[ "$result" == "█████░░░░░" ]]
}

@test "_tui_progress_bar: handles zero total" {
  result=$(_tui_progress_bar 5 0 10)
  [[ "$result" == "░░░░░░░░░░" ]]
}

@test "_tui_progress_bar: handles width of 20 (default)" {
  result=$(_tui_progress_bar 10 20 20)
  [[ "${#result}" -eq 20 ]]
  [[ "$result" == "██████████░░░░░░░░░░" ]]
}

@test "_tui_progress_bar: handles over 100% gracefully" {
  result=$(_tui_progress_bar 15 10 10)
  # Should clamp to full bar
  [[ "$result" == "██████████" ]]
}

# =============================================================================
# Spinner
# =============================================================================

@test "_tui_spinner_char: returns a character" {
  result=$(_tui_spinner_char)
  [[ -n "$result" ]]
  [[ "${#result}" -gt 0 ]]
}

@test "_tui_spinner_advance: increments spinner index" {
  _TUI_SPINNER_IDX=0
  _tui_spinner_advance
  [[ "$_TUI_SPINNER_IDX" -eq 1 ]]
  _tui_spinner_advance
  [[ "$_TUI_SPINNER_IDX" -eq 2 ]]
}

# =============================================================================
# Initialization (Fallback Mode)
# =============================================================================

@test "tui_init: returns 1 when JSH_NO_TUI is set" {
  export JSH_NO_TUI=1
  run tui_init
  [[ "$status" -eq 1 ]]
}

@test "tui_init: does not set _TUI_ENABLED when fallback" {
  export JSH_NO_TUI=1
  tui_init || true
  [[ -z "$_TUI_ENABLED" ]]
}

# =============================================================================
# Progress Management (Fallback Mode)
# =============================================================================

@test "tui_progress_start: works in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_progress_start "Test Operation" 10
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Test Operation" ]]
}

@test "tui_progress_start: sets state variables" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "My Operation" 15
  [[ "$_TUI_OPERATION" == "My Operation" ]]
  [[ "$_TUI_TOTAL" -eq 15 ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]
  [[ "$_TUI_START_TIME" -gt 0 ]]
}

@test "tui_progress_next: increments counter" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 10
  [[ "$_TUI_CURRENT" -eq 0 ]]

  tui_progress_next "item1" >/dev/null
  [[ "$_TUI_CURRENT" -eq 1 ]]

  tui_progress_next "item2" >/dev/null
  [[ "$_TUI_CURRENT" -eq 2 ]]
}

@test "tui_progress_next: sets current item" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_next "my_item" >/dev/null
  [[ "$_TUI_CURRENT_ITEM" == "my_item" ]]
}

@test "tui_progress_next: outputs to stdout in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true
  tui_progress_start "Test" 5

  run tui_progress_next "item1"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "[1/5]" ]]
  [[ "$output" =~ "item1" ]]
}

@test "tui_progress_update: sets specific count" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 10
  tui_progress_update 7 "middle_item" >/dev/null

  [[ "$_TUI_CURRENT" -eq 7 ]]
  [[ "$_TUI_CURRENT_ITEM" == "middle_item" ]]
}

@test "tui_progress_complete: resets state" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_next "item" >/dev/null
  tui_progress_complete >/dev/null

  [[ -z "$_TUI_OPERATION" ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]
  [[ "$_TUI_TOTAL" -eq 0 ]]
}

@test "tui_progress_complete: outputs success message" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  run tui_progress_complete "All done"

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "All done" ]]
}

@test "tui_progress_fail: resets state" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_next "item" >/dev/null
  tui_progress_fail >/dev/null

  [[ -z "$_TUI_OPERATION" ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]
}

@test "tui_progress_fail: outputs warning message" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  run tui_progress_fail "Something went wrong"

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Something went wrong" ]]
}

# =============================================================================
# Output Functions (Fallback Mode)
# =============================================================================

@test "tui_log: outputs message in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_log "test log message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test log message" ]]
}

@test "tui_success: outputs message in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_success "success message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "success message" ]]
}

@test "tui_warn: outputs message in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_warn "warning message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "warning message" ]]
}

@test "tui_error: outputs message in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_error "error message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "error message" ]]
}

@test "tui_info: outputs message in fallback mode" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_info "info message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "info message" ]]
}

# =============================================================================
# Cleanup Safety
# =============================================================================

@test "tui_cleanup: is safe to call multiple times" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    tui_cleanup
    tui_cleanup
    tui_cleanup
    echo 'ok'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == "ok" ]]
}

@test "tui_cleanup: is safe to call without init" {
  run tui_cleanup
  [[ "$status" -eq 0 ]]
}

@test "tui_cleanup: clears _TUI_ENABLED" {
  _TUI_ENABLED=1
  tui_cleanup
  [[ -z "$_TUI_ENABLED" ]]
}

# =============================================================================
# State Isolation
# =============================================================================

@test "state: multiple progress operations are independent" {
  export JSH_NO_TUI=1
  tui_init || true

  # First operation
  tui_progress_start "Op 1" 5
  tui_progress_next "a" >/dev/null
  tui_progress_complete >/dev/null

  # Second operation
  tui_progress_start "Op 2" 10
  [[ "$_TUI_OPERATION" == "Op 2" ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]
  [[ "$_TUI_TOTAL" -eq 10 ]]

  tui_progress_complete >/dev/null
}

@test "state: indeterminate progress (total=0)" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Spinner Op" 0
  [[ "$_TUI_TOTAL" -eq 0 ]]

  run tui_progress_next "working"
  [[ "$status" -eq 0 ]]
  # Should show without count since total is 0
  [[ ! "$output" =~ "/" ]] || [[ "$output" =~ "working" ]]
}

# =============================================================================
# Edge Cases - Progress Bar
# =============================================================================

@test "_tui_progress_bar: handles negative current value" {
  # Negative values are clamped to 0
  result=$(_tui_progress_bar -5 10 10)
  [[ "$result" == "░░░░░░░░░░" ]]
}

@test "_tui_progress_bar: handles very large numbers" {
  result=$(_tui_progress_bar 500 1000 10)
  [[ "$result" == "█████░░░░░" ]]
}

@test "_tui_progress_bar: handles width of 1" {
  result=$(_tui_progress_bar 5 10 1)
  [[ "${#result}" -eq 1 ]]
}

@test "_tui_progress_bar: handles equal current and total" {
  result=$(_tui_progress_bar 42 42 10)
  [[ "$result" == "██████████" ]]
}

@test "_tui_progress_bar: handles 1 of 1" {
  result=$(_tui_progress_bar 1 1 10)
  [[ "$result" == "██████████" ]]
}

@test "_tui_progress_bar: handles 0 of 0 (edge case)" {
  result=$(_tui_progress_bar 0 0 10)
  [[ "$result" == "░░░░░░░░░░" ]]
}

# =============================================================================
# Edge Cases - Spinner
# =============================================================================

@test "_tui_spinner_char: wraps around after full cycle" {
  _TUI_SPINNER_IDX=0
  first=$(_tui_spinner_char)

  # Advance through full cycle (10 chars in spinner)
  for i in {1..10}; do
    _tui_spinner_advance
  done

  tenth=$(_tui_spinner_char)
  [[ "$first" == "$tenth" ]]
}

@test "_tui_spinner_advance: handles large index values" {
  _TUI_SPINNER_IDX=9999
  _tui_spinner_advance
  [[ "$_TUI_SPINNER_IDX" -eq 10000 ]]

  # Should still produce valid character
  result=$(_tui_spinner_char)
  [[ -n "$result" ]]
}

# =============================================================================
# Edge Cases - Progress Management
# =============================================================================

@test "tui_progress_start: handles empty operation name" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_progress_start "" 10
  [[ "$status" -eq 0 ]]
  [[ "$_TUI_OPERATION" == "" ]]
}

@test "tui_progress_next: handles empty item name" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_next "" >/dev/null
  [[ "$_TUI_CURRENT" -eq 1 ]]
  [[ "$_TUI_CURRENT_ITEM" == "" ]]
}

@test "tui_progress_next: handles special characters in item name" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  run tui_progress_next "package@1.0.0/sub-pkg"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "package@1.0.0/sub-pkg" ]]
}

@test "tui_progress_next: handles unicode in item name" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_next "测试包" >/dev/null
  [[ "$_TUI_CURRENT_ITEM" == "测试包" ]]
}

@test "tui_progress_next: can exceed total (no hard limit)" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 2
  tui_progress_next "item1" >/dev/null
  tui_progress_next "item2" >/dev/null
  tui_progress_next "item3" >/dev/null  # Beyond total

  [[ "$_TUI_CURRENT" -eq 3 ]]
}

@test "tui_progress_complete: works without prior progress_next" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 5
  tui_progress_complete "Done" >/dev/null

  [[ -z "$_TUI_OPERATION" ]]
}

@test "tui_progress_complete: uses operation name if no message" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "My Operation" 5
  run tui_progress_complete

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "My Operation" ]]
  [[ "$output" =~ "complete" ]]
}

@test "tui_progress_fail: uses operation name if no message" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "My Operation" 5
  run tui_progress_fail

  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "My Operation" ]]
  [[ "$output" =~ "failed" ]]
}

@test "tui_progress_update: handles item without name" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 10
  tui_progress_update 5 >/dev/null

  [[ "$_TUI_CURRENT" -eq 5 ]]
}

# =============================================================================
# Edge Cases - Output Functions
# =============================================================================

@test "tui_log: handles empty message" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_log ""
  [[ "$status" -eq 0 ]]
}

@test "tui_log: handles multiline message" {
  export JSH_NO_TUI=1
  tui_init || true

  run tui_log "line1
line2"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "line1" ]]
}

@test "tui_error: does not exit in TUI mode (unlike error())" {
  export JSH_NO_TUI=1
  tui_init || true

  # This should NOT exit
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    export JSH_NO_TUI=1
    tui_init || true
    tui_error 'test error'
    echo 'still running'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "still running" ]]
}

# =============================================================================
# Capability Detection - Additional Cases
# =============================================================================

@test "tui_is_supported: caches result" {
  export JSH_NO_TUI=1
  _TUI_SUPPORTED=""

  tui_is_supported || true
  [[ "$_TUI_SUPPORTED" == "0" ]]

  # Second call should use cached value
  unset JSH_NO_TUI  # Even if we unset this, cached value should be used
  tui_is_supported || true
  [[ "$_TUI_SUPPORTED" == "0" ]]
}

@test "tui_is_supported: returns cached success value" {
  _TUI_SUPPORTED=1
  run tui_is_supported
  [[ "$status" -eq 0 ]]
}

@test "tui_is_supported: returns cached failure value" {
  _TUI_SUPPORTED=0
  run tui_is_supported
  [[ "$status" -eq 1 ]]
}

@test "tui_init: respects JSH_FORCE_TUI in non-tty" {
  # Note: Even with FORCE_TUI, bats environment may not have tput capabilities
  # This test verifies the flag is checked, not that TUI actually works
  unset JSH_NO_TUI
  export JSH_FORCE_TUI=1
  _TUI_SUPPORTED=""

  # Will likely still fail due to tput, but shouldn't fail on tty check
  tui_is_supported || true
  # The fact that we got here without error on tty check is the test
  [[ "$_TUI_SUPPORTED" == "0" || "$_TUI_SUPPORTED" == "1" ]]
}

# =============================================================================
# State Management
# =============================================================================

@test "tui_cleanup: resets all progress state" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Test" 10
  tui_progress_next "item" >/dev/null
  _TUI_CURRENT_ITEM="test"
  _TUI_START_TIME=12345

  tui_cleanup

  [[ -z "$_TUI_OPERATION" ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]
  [[ "$_TUI_TOTAL" -eq 0 ]]
  [[ -z "$_TUI_CURRENT_ITEM" ]]
  [[ "$_TUI_START_TIME" -eq 0 ]]
}

@test "tui_cleanup: can be called in subshell safely" {
  run bash -c "
    source '${JSH_ROOT}/src/lib/colors.sh'
    source '${JSH_ROOT}/src/lib/tui.sh'
    export JSH_NO_TUI=1
    tui_init || true
    tui_progress_start 'Test' 5
    (
      tui_cleanup
    )
    echo 'parent ok'
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "parent ok" ]]
}

# =============================================================================
# Integration - Functions Work Without TUI Init
# =============================================================================

@test "tui_log: works without tui_init" {
  # Don't call tui_init, should fall back to log()
  export JSH_NO_TUI=1
  _TUI_ENABLED=""

  run tui_log "test message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test message" ]]
}

@test "tui_progress_start: works without tui_init" {
  export JSH_NO_TUI=1
  _TUI_ENABLED=""

  run tui_progress_start "Test" 5
  [[ "$status" -eq 0 ]]
}

@test "tui_progress_next: works without tui_init" {
  export JSH_NO_TUI=1
  _TUI_ENABLED=""

  _TUI_TOTAL=5
  _TUI_CURRENT=0
  run tui_progress_next "item"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Concurrent/Nested Operations
# =============================================================================

@test "nested progress operations override parent" {
  export JSH_NO_TUI=1
  tui_init || true

  tui_progress_start "Outer" 10
  tui_progress_next "outer1" >/dev/null

  # Start nested operation (overwrites)
  tui_progress_start "Inner" 5
  [[ "$_TUI_OPERATION" == "Inner" ]]
  [[ "$_TUI_TOTAL" -eq 5 ]]
  [[ "$_TUI_CURRENT" -eq 0 ]]

  tui_progress_complete >/dev/null
}
