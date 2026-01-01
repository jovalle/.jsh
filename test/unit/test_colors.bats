#!/usr/bin/env bats
# Unit tests for src/lib/colors.sh

setup() {
  load '../test_helper.bash'
  source "${JSH_ROOT}/src/lib/colors.sh"
}

# Test color constant definitions
@test "colors: color constants are defined" {
  [[ -n "$RED" ]]
  [[ -n "$GREEN" ]]
  [[ -n "$YELLOW" ]]
  [[ -n "$BLUE" ]]
  [[ -n "$CYAN" ]]
  [[ -n "$MAGENTA" ]]
  [[ -n "$BOLD" ]]
  [[ -n "$RESET" ]]
}

# Test cmd_exists function
@test "cmd_exists: returns 0 for existing command" {
  run cmd_exists bash
  [[ "$status" -eq 0 ]]
}

@test "cmd_exists: returns 1 for non-existing command" {
  run cmd_exists nonexistent_command_12345
  [[ "$status" -eq 1 ]]
}

# Test is_macos function
@test "is_macos: correctly identifies macOS" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    run is_macos
    [[ "$status" -eq 0 ]]
  else
    run is_macos
    [[ "$status" -eq 1 ]]
  fi
}

# Test is_linux function
@test "is_linux: correctly identifies Linux" {
  if [[ "$(uname -s)" == "Linux" ]]; then
    run is_linux
    [[ "$status" -eq 0 ]]
  else
    run is_linux
    [[ "$status" -eq 1 ]]
  fi
}

# Test is_root function
@test "is_root: correctly identifies non-root user" {
  run is_root
  # Should return 1 (false) when not running as root
  [[ "$status" -eq 1 ]]
}

# Test get_root_dir function
@test "get_root_dir: returns JSH_ROOT when set" {
  export JSH_ROOT="/tmp/test_jsh"
  run get_root_dir
  [[ "$status" -eq 0 ]]
  [[ "$output" == "/tmp/test_jsh" ]]
}

@test "get_root_dir: finds root directory from script location" {
  unset JSH_ROOT
  run get_root_dir
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
  # Should return a valid directory path
  [[ -d "$output" ]]
}

# Test log function
@test "log: outputs formatted message" {
  run log "test message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test message" ]]
}

# Test info function
@test "info: outputs formatted message" {
  run info "test info"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test info" ]]
}

# Test warn function
@test "warn: outputs formatted warning" {
  run warn "test warning"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test warning" ]]
}

# Test success function
@test "success: outputs formatted success message" {
  run success "test success"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test success" ]]
}

# Test header function
@test "header: outputs formatted header" {
  run header "Test Header"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Test Header" ]]
}

# Test error function
@test "error: exits with non-zero status" {
  run error "test error"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "test error" ]]
}

# Test confirm function with mock input
@test "confirm: returns 0 for 'y' input" {
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh && echo 'y' | confirm 'Test?'"
  [[ "$status" -eq 0 ]]
}

@test "confirm: returns 1 for 'n' input" {
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh && echo 'n' | confirm 'Test?'"
  [[ "$status" -eq 1 ]]
}

@test "confirm: returns 1 for empty input (default no)" {
  run bash -c "source ${JSH_ROOT}/src/lib/colors.sh && echo '' | confirm 'Test?'"
  [[ "$status" -eq 1 ]]
}
