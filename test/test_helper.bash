# Test helper functions for BATS tests

# Set up JSH_ROOT environment variable
export JSH_ROOT="${JSH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Helper to create temporary test directory
setup_test_dir() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export TEST_HOME="$TEST_DIR/home"
  mkdir -p "$TEST_HOME"
}

# Helper to clean up temporary test directory
teardown_test_dir() {
  if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Helper to create a temporary JSON file with content
create_temp_json() {
  local content="$1"
  local temp_file
  temp_file="$(mktemp)"
  echo "$content" > "$temp_file"
  echo "$temp_file"
}

# Helper to check if command exists (for conditional tests)
has_command() {
  command -v "$1" &>/dev/null
}

# Helper to mock uname for OS detection tests
mock_uname() {
  local os="$1"
  eval "uname() { echo '$os'; }"
  export -f uname
}

# Helper to assert file exists
assert_file_exists() {
  [[ -f "$1" ]] || {
    echo "Expected file to exist: $1"
    return 1
  }
}

# Helper to assert file does not exist
assert_file_not_exists() {
  [[ ! -f "$1" ]] || {
    echo "Expected file to not exist: $1"
    return 1
  }
}

# Helper to assert directory exists
assert_dir_exists() {
  [[ -d "$1" ]] || {
    echo "Expected directory to exist: $1"
    return 1
  }
}

# Helper to assert string contains substring
assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || {
    echo "Expected '$haystack' to contain '$needle'"
    return 1
  }
}

# Helper to assert strings are equal
assert_equals() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || {
    echo "Expected '$expected' but got '$actual'"
    return 1
  }
}

# Load bats support libraries if available
if [[ -d "/opt/homebrew/lib/bats-support" ]]; then
  load "/opt/homebrew/lib/bats-support/load.bash"
fi

if [[ -d "/opt/homebrew/lib/bats-assert" ]]; then
  load "/opt/homebrew/lib/bats-assert/load.bash"
fi
