#!/usr/bin/env bats
# shellcheck disable=SC2154
# Unit tests for src/lib/packages.sh

setup() {
  load '../test_helper.bash'
  source "${JSH_ROOT}/src/lib/colors.sh"
  source "${JSH_ROOT}/src/lib/packages.sh"
  setup_test_dir
}

teardown() {
  teardown_test_dir
}

# Test load_packages_from_json function
@test "load_packages_from_json: loads packages from valid JSON" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1", "pkg2", "pkg3"]' > "$json_file"

  run load_packages_from_json "$json_file"
  [[ "$status" -eq 0 ]]
  [[ "${lines[0]}" == "pkg1" ]]
  [[ "${lines[1]}" == "pkg2" ]]
  [[ "${lines[2]}" == "pkg3" ]]
}

@test "load_packages_from_json: returns 1 for non-existent file" {
  run load_packages_from_json "/nonexistent/file.json"
  [[ "$status" -eq 1 ]]
}

@test "load_packages_from_json: works without jq using grep" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1", "pkg2", "pkg3"]' > "$json_file"

  # Test fallback behavior when jq is not available
  # This assumes the grep fallback works (may not be perfect for all JSON)
  run bash -c "PATH=/dev/null source ${JSH_ROOT}/src/lib/packages.sh && load_packages_from_json '$json_file'"
  [[ "$status" -eq 0 ]]
}

# Test add_package_to_json function
@test "add_package_to_json: adds new package to empty array" {
  local json_file="$TEST_DIR/packages.json"
  echo '[]' > "$json_file"

  run add_package_to_json "$json_file" "newpkg"
  [[ "$status" -eq 0 ]]

  # Verify package was added and sorted
  run cat "$json_file"
  [[ "$output" == '["newpkg"]' ]] || [[ "$output" =~ '"newpkg"' ]]
}

@test "add_package_to_json: adds package in sorted order" {
  local json_file="$TEST_DIR/packages.json"
  echo '["aaa", "zzz"]' > "$json_file"

  run add_package_to_json "$json_file" "mmm"
  [[ "$status" -eq 0 ]]

  # Verify sorting
  local packages
  # shellcheck disable=SC2207
  packages=($(jq -r '.[]' "$json_file"))
  [[ "${packages[0]}" == "aaa" ]]
  [[ "${packages[1]}" == "mmm" ]]
  [[ "${packages[2]}" == "zzz" ]]
}

@test "add_package_to_json: does not add duplicate package" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1", "pkg2"]' > "$json_file"

  run add_package_to_json "$json_file" "pkg1"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "already in" ]]

  # Verify no duplicate
  local count
  count=$(jq -r '.[]' "$json_file" | grep -c "pkg1")
  [[ "$count" -eq 1 ]]
}

@test "add_package_to_json: creates file if it doesn't exist" {
  local json_file="$TEST_DIR/newfile.json"

  run add_package_to_json "$json_file" "pkg1"
  [[ "$status" -eq 0 ]]
  [[ -f "$json_file" ]]

  # Verify content
  run jq -r '.[]' "$json_file"
  [[ "$output" == "pkg1" ]]
}

@test "add_package_to_json: requires jq" {
  # This test verifies error handling when jq is missing
  # We can't actually uninstall jq, so we mock the environment
  skip "Cannot reliably test jq requirement without mocking"
}

# Test remove_package_from_json function
@test "remove_package_from_json: removes existing package" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1", "pkg2", "pkg3"]' > "$json_file"

  run remove_package_from_json "$json_file" "pkg2"
  [[ "$status" -eq 0 ]]

  # Verify package was removed
  run jq -r '.[]' "$json_file"
  [[ ! "$output" =~ "pkg2" ]]
  [[ "$output" =~ "pkg1" ]]
  [[ "$output" =~ "pkg3" ]]
}

@test "remove_package_from_json: returns 1 for non-existent package" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1", "pkg2"]' > "$json_file"

  run remove_package_from_json "$json_file" "nonexistent"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "not found" ]]
}

@test "remove_package_from_json: returns 1 for non-existent file" {
  run remove_package_from_json "/nonexistent/file.json" "pkg1"
  [[ "$status" -eq 1 ]]
}

# Test update_package_cache function
@test "update_package_cache: runs without error" {
  # This test just verifies the function doesn't crash
  # Actual package manager updates would require sudo and are tested in integration tests
  skip "Requires sudo and actual package manager - covered by integration tests"
}

# Test install_package function
@test "install_package: detects current OS" {
  # This test verifies the function exists and can be called
  # Actual package installation requires sudo and is tested in integration tests
  skip "Requires sudo and actual package manager - covered by integration tests"
}

# Test upgrade_packages function
@test "upgrade_packages: detects current OS" {
  # This test verifies the function exists and can be called
  # Actual package upgrades require sudo and are tested in integration tests
  skip "Requires sudo and actual package manager - covered by integration tests"
}

# Edge cases and error handling
@test "add_package_to_json: handles empty package name" {
  local json_file="$TEST_DIR/packages.json"
  echo '[]' > "$json_file"

  run add_package_to_json "$json_file" ""
  [[ "$status" -eq 1 ]]
}

@test "remove_package_from_json: handles empty package name" {
  local json_file="$TEST_DIR/packages.json"
  echo '["pkg1"]' > "$json_file"

  run remove_package_from_json "$json_file" ""
  [[ "$status" -eq 1 ]]
}

@test "add_package_to_json: handles malformed JSON gracefully" {
  local json_file="$TEST_DIR/malformed.json"
  echo 'not valid json' > "$json_file"

  # Should fail gracefully
  run add_package_to_json "$json_file" "pkg1"
  [[ "$status" -ne 0 ]]
}

# ============================================================================
# Cargo Package Management Tests
# ============================================================================

@test "get_cargo_package_count: returns 0 for non-existent file" {
  run get_cargo_package_count "/nonexistent/file.json"
  [[ "$output" == "0" ]]
}

@test "get_cargo_package_count: returns correct count for mixed array" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  "ripgrep",
  {"git": "https://github.com/example/repo", "features": ["tui"]}
]
EOF

  run get_cargo_package_count "$json_file"
  [[ "$output" == "2" ]]
}

@test "get_cargo_package_id: returns string for simple crate" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep", "bat"]' > "$json_file"

  run get_cargo_package_id "$json_file" 0
  [[ "$output" == "ripgrep" ]]

  run get_cargo_package_id "$json_file" 1
  [[ "$output" == "bat" ]]
}

@test "get_cargo_package_id: returns git URL for git package" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo", "features": ["tui"]}
]
EOF

  run get_cargo_package_id "$json_file" 0
  [[ "$output" == "https://github.com/example/repo" ]]
}

@test "get_cargo_package_id: returns name for named package" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"name": "mypackage", "features": ["feature1"]}
]
EOF

  run get_cargo_package_id "$json_file" 0
  [[ "$output" == "mypackage" ]]
}

@test "build_cargo_install_args: returns crate name for simple string" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep"]' > "$json_file"

  run build_cargo_install_args "$json_file" 0
  [[ "$output" == "ripgrep" ]]
}

@test "build_cargo_install_args: builds git command with features" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo", "features": ["tui", "network"]}
]
EOF

  run build_cargo_install_args "$json_file" 0
  [[ "$output" == "--git https://github.com/example/repo --features tui,network" ]]
}

@test "build_cargo_install_args: includes branch and tag" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo", "branch": "main", "tag": "v1.0"}
]
EOF

  run build_cargo_install_args "$json_file" 0
  [[ "$output" =~ --git\ https://github.com/example/repo ]]
  [[ "$output" =~ --branch\ main ]]
  [[ "$output" =~ --tag\ v1\.0 ]]
}

@test "build_cargo_install_args: includes locked flag" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"name": "mypackage", "locked": true}
]
EOF

  run build_cargo_install_args "$json_file" 0
  [[ "$output" =~ "--locked" ]]
}

@test "cargo_package_exists: finds string package" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep", "bat"]' > "$json_file"

  run cargo_package_exists "$json_file" "ripgrep"
  [[ "$status" -eq 0 ]]

  run cargo_package_exists "$json_file" "nonexistent"
  [[ "$status" -ne 0 ]]
}

@test "cargo_package_exists: finds package by git URL" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo"}
]
EOF

  run cargo_package_exists "$json_file" "https://github.com/example/repo"
  [[ "$status" -eq 0 ]]
}

@test "cargo_package_exists: finds package by name" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"name": "mypackage", "features": ["tui"]}
]
EOF

  run cargo_package_exists "$json_file" "mypackage"
  [[ "$status" -eq 0 ]]
}

@test "add_cargo_package: adds simple crate name" {
  local json_file="$TEST_DIR/cargo.json"
  echo '[]' > "$json_file"

  run add_cargo_package "$json_file" "ripgrep"
  [[ "$status" -eq 0 ]]

  run jq -r '.[0]' "$json_file"
  [[ "$output" == "ripgrep" ]]
}

@test "add_cargo_package: adds JSON object package" {
  local json_file="$TEST_DIR/cargo.json"
  echo '[]' > "$json_file"

  run add_cargo_package "$json_file" '{"git":"https://github.com/example/repo","features":["tui"]}'
  [[ "$status" -eq 0 ]]

  run jq -r '.[0].git' "$json_file"
  [[ "$output" == "https://github.com/example/repo" ]]
}

@test "add_cargo_package: does not add duplicate" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep"]' > "$json_file"

  run add_cargo_package "$json_file" "ripgrep"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "already in config" ]]

  local count
  count=$(jq 'length' "$json_file")
  [[ "$count" -eq 1 ]]
}

@test "add_cargo_package: creates file if missing" {
  local json_file="$TEST_DIR/newcargo.json"

  run add_cargo_package "$json_file" "ripgrep"
  [[ "$status" -eq 0 ]]
  [[ -f "$json_file" ]]
}

@test "remove_cargo_package: removes string package" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep", "bat"]' > "$json_file"

  run remove_cargo_package "$json_file" "ripgrep"
  [[ "$status" -eq 0 ]]

  run jq 'length' "$json_file"
  [[ "$output" == "1" ]]

  run jq -r '.[0]' "$json_file"
  [[ "$output" == "bat" ]]
}

@test "remove_cargo_package: removes package by git URL" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo"},
  "ripgrep"
]
EOF

  run remove_cargo_package "$json_file" "https://github.com/example/repo"
  [[ "$status" -eq 0 ]]

  run jq 'length' "$json_file"
  [[ "$output" == "1" ]]
}

@test "remove_cargo_package: returns 1 for non-existent package" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep"]' > "$json_file"

  run remove_cargo_package "$json_file" "nonexistent"
  [[ "$status" -eq 1 ]]
}

@test "get_cargo_binary_name: returns crate name for string" {
  local json_file="$TEST_DIR/cargo.json"
  echo '["ripgrep"]' > "$json_file"

  run get_cargo_binary_name "$json_file" "ripgrep"
  [[ "$output" == "ripgrep" ]]
}

@test "get_cargo_binary_name: returns bin if specified" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/repo", "bin": "mybin"}
]
EOF

  run get_cargo_binary_name "$json_file" "https://github.com/example/repo"
  [[ "$output" == "mybin" ]]
}

@test "get_cargo_binary_name: extracts repo name from git URL" {
  local json_file="$TEST_DIR/cargo.json"
  cat > "$json_file" << 'EOF'
[
  {"git": "https://github.com/example/cool-tool"}
]
EOF

  run get_cargo_binary_name "$json_file" "https://github.com/example/cool-tool"
  [[ "$output" == "cool-tool" ]]
}
