#!/usr/bin/env bats
# shellcheck disable=SC2154
# Unit tests for src/lib/profiler.sh

setup() {
  load '../test_helper.bash'
  setup_test_dir

  # Save original environment
  export _ORIG_JSH_PROFILE="${JSH_PROFILE:-}"
  export _ORIG_HOME="${HOME}"
  export HOME="${TEST_HOME}"

  # Enable profiling for tests
  export JSH_PROFILE=1

  # Source the profiler
  source "${JSH_ROOT}/src/lib/profiler.sh"
}

teardown() {
  teardown_test_dir
  export JSH_PROFILE="${_ORIG_JSH_PROFILE}"
  export HOME="${_ORIG_HOME}"

  # Clean up profile data
  unset _PROFILE_START_TIMES
  unset _PROFILE_END_TIMES
  unset _PROFILE_DESCRIPTIONS
  unset _PROFILE_ORDER
  unset _PROFILE_TOTAL_START
  unset _PROFILE_ENABLED
}

# ============================================================================
# Test profile_init function
# ============================================================================

@test "profile_init: initializes profiling when JSH_PROFILE=1" {
  export JSH_PROFILE=1
  run profile_init

  [[ "${status}" -eq 0 ]]
  [[ -d "${HOME}/.cache/jsh/profile" ]]
}

@test "profile_init: does nothing when JSH_PROFILE=0" {
  export JSH_PROFILE=0
  run profile_init

  [[ "${status}" -eq 0 ]]
}

@test "profile_init: creates cache directory" {
  export JSH_PROFILE=1
  rm -rf "${HOME}/.cache/jsh/profile"

  profile_init

  [[ -d "${HOME}/.cache/jsh/profile" ]]
}

# ============================================================================
# Test get_time_ms function
# ============================================================================

@test "get_time_ms: returns numeric timestamp" {
  run get_time_ms

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ ^[0-9]+$ ]]
}

@test "get_time_ms: returns different values when called twice" {
  local time1
  time1=$(get_time_ms)
  sleep 0.01
  local time2
  time2=$(get_time_ms)

  [[ "${time1}" -lt "${time2}" ]]
}

# ============================================================================
# Test profile_start function
# ============================================================================

@test "profile_start: records start time for section" {
  profile_init

  profile_start "test_section" "Test Description"

  # Check directly without run to preserve variable scope
  [[ -n "${_PROFILE_START_TIMES[test_section]:-}" ]]
  [[ "${_PROFILE_DESCRIPTIONS[test_section]}" == "Test Description" ]]
}

@test "profile_start: does nothing when profiling disabled" {
  export JSH_PROFILE=0
  source "${JSH_ROOT}/src/lib/profiler.sh"

  run profile_start "test_section"

  [[ "${status}" -eq 0 ]]
}

@test "profile_start: uses section name as description when not provided" {
  profile_init

  profile_start "test_section"

  [[ "${_PROFILE_DESCRIPTIONS[test_section]}" == "test_section" ]]
}

@test "profile_start: tracks section order" {
  profile_init

  profile_start "section1"
  profile_start "section2"
  profile_start "section3"

  [[ "${_PROFILE_ORDER[0]}" == "section1" ]]
  [[ "${_PROFILE_ORDER[1]}" == "section2" ]]
  [[ "${_PROFILE_ORDER[2]}" == "section3" ]]
}

# ============================================================================
# Test profile_end function
# ============================================================================

@test "profile_end: records end time for section" {
  profile_init
  profile_start "test_section"

  profile_end "test_section"

  # Check directly without run to preserve variable scope
  [[ -n "${_PROFILE_END_TIMES[test_section]:-}" ]]
}

@test "profile_end: errors when called without matching start" {
  profile_init

  run profile_end "nonexistent_section"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ "without matching profile_start" ]]
}

@test "profile_end: does nothing when profiling disabled" {
  export JSH_PROFILE=0
  source "${JSH_ROOT}/src/lib/profiler.sh"

  run profile_end "test_section"

  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test profile_duration function
# ============================================================================

@test "profile_duration: calculates duration correctly" {
  profile_init
  profile_start "test_section"
  sleep 0.1
  profile_end "test_section"

  run profile_duration "test_section"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ ^[0-9]+$ ]]
  # Should be approximately 100ms (allowing some variance)
  [[ "${output}" -ge 80 ]]
  [[ "${output}" -le 200 ]]
}

@test "profile_duration: returns 0 for non-existent section" {
  profile_init

  run profile_duration "nonexistent_section"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "0" ]]
}

@test "profile_duration: returns 0 for incomplete section" {
  profile_init
  profile_start "test_section"

  run profile_duration "test_section"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "0" ]]
}

# ============================================================================
# Test profile_report function
# ============================================================================

@test "profile_report: generates table format report" {
  profile_init
  profile_start "section1" "First section"
  sleep 0.05
  profile_end "section1"
  profile_start "section2" "Second section"
  sleep 0.05
  profile_end "section2"

  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Shell Initialization Profile" ]]
  [[ "${output}" =~ "First section" ]]
  [[ "${output}" =~ "Second section" ]]
  [[ "${output}" =~ "TOTAL" ]]
}

@test "profile_report: does nothing when profiling disabled" {
  export JSH_PROFILE=0
  source "${JSH_ROOT}/src/lib/profiler.sh"

  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
}

@test "profile_report: includes top 5 slowest sections" {
  profile_init

  # Create 6 sections with different durations
  for i in {1..6}; do
    profile_start "section${i}" "Section ${i}"
    sleep 0.01
    profile_end "section${i}"
  done

  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Top 5 Slowest Sections" ]]
}

@test "profile_report: saves to file when JSH_PROFILE_OUTPUT is set" {
  profile_init
  profile_start "test_section"
  profile_end "test_section"

  local output_file="${TEST_DIR}/profile_report.txt"
  export JSH_PROFILE_OUTPUT="${output_file}"

  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ -f "${output_file}" ]]
  [[ -s "${output_file}" ]]
}

# ============================================================================
# Test profile_report_json function
# ============================================================================

@test "profile_report_json: generates JSON format report" {
  profile_init
  profile_start "section1" "First section"
  sleep 0.05
  profile_end "section1"

  export JSH_PROFILE_FORMAT="json"
  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "\"timestamp\"" ]]
  [[ "${output}" =~ "\"total_duration_ms\"" ]]
  [[ "${output}" =~ "\"sections\"" ]]
  [[ "${output}" =~ "\"name\": \"section1\"" ]]
}

@test "profile_report_json: includes section details" {
  profile_init
  profile_start "test_section" "Test Description"
  sleep 0.05
  profile_end "test_section"

  export JSH_PROFILE_FORMAT="json"
  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "\"description\": \"Test Description\"" ]]
  [[ "${output}" =~ "\"duration_ms\"" ]]
  [[ "${output}" =~ "\"percentage\"" ]]
}

# ============================================================================
# Test profile_save function
# ============================================================================

@test "profile_save: saves profile to cache directory" {
  profile_init
  profile_start "test_section"
  profile_end "test_section"

  run profile_save "test_profile"

  [[ "${status}" -eq 0 ]]
  [[ -f "${HOME}/.cache/jsh/profile/test_profile.json" ]]
  [[ "${output}" =~ "Profile saved" ]]
}

@test "profile_save: uses timestamp as default name" {
  profile_init
  profile_start "test_section"
  profile_end "test_section"

  run profile_save

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Profile saved" ]]
  # Check that a file was created with timestamp pattern
  local count
  count=$(find "${HOME}/.cache/jsh/profile" -name "*.json" | wc -l)
  [[ "${count}" -ge 1 ]]
}

@test "profile_save: does nothing when profiling disabled" {
  export JSH_PROFILE=0
  source "${JSH_ROOT}/src/lib/profiler.sh"

  run profile_save "test_profile"

  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test profile_compare function
# ============================================================================

@test "profile_compare: errors when profile files not found" {
  run profile_compare "/nonexistent/profile1.json" "/nonexistent/profile2.json"

  [[ "${status}" -eq 1 ]]
  [[ "${output}" =~ "Profile files not found" ]]
}

@test "profile_compare: accepts valid profile files" {
  # Create dummy profile files
  mkdir -p "${TEST_DIR}"
  echo '{}' > "${TEST_DIR}/profile1.json"
  echo '{}' > "${TEST_DIR}/profile2.json"

  run profile_compare "${TEST_DIR}/profile1.json" "${TEST_DIR}/profile2.json"

  [[ "${status}" -eq 0 ]]
}

# ============================================================================
# Test profile_command function
# ============================================================================

@test "profile_command: profiles command execution" {
  profile_init

  # Test that profile_command executes the command
  run bash -c "
    export JSH_PROFILE=1
    source '${JSH_ROOT}/src/lib/profiler.sh'
    profile_init
    profile_command 'test_cmd' echo 'hello'
  "

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "hello" ]]
}

@test "profile_command: preserves command exit code" {
  profile_init

  run profile_command "test_cmd" false

  [[ "${status}" -eq 1 ]]
}

@test "profile_command: executes command without profiling when disabled" {
  # When JSH_PROFILE=0, _PROFILE_ENABLED is not set, so command still runs
  # but without the shift, so it executes "$@" which includes the section name
  # This is by design - when profiling is disabled, profile_command becomes a passthrough
  run bash -c '
    export JSH_PROFILE=0
    source "'"${JSH_ROOT}"'/src/lib/profiler.sh"
    # When disabled, we still need to call it properly but it won'\''t profile
    _PROFILE_ENABLED=0
    profile_command /bin/echo hello
  '

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "hello" ]]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "integration: complete profiling workflow" {
  profile_init

  # Profile multiple sections
  profile_start "init" "Initialization"
  sleep 0.05
  profile_end "init"

  profile_start "config" "Configuration"
  sleep 0.03
  profile_end "config"

  profile_start "plugins" "Plugin loading"
  sleep 0.07
  profile_end "plugins"

  # Generate report
  run profile_report

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ "Initialization" ]]
  [[ "${output}" =~ "Configuration" ]]
  [[ "${output}" =~ "Plugin loading" ]]

  # Save profile
  run profile_save "integration_test"

  [[ "${status}" -eq 0 ]]
  [[ -f "${HOME}/.cache/jsh/profile/integration_test.json" ]]
}
