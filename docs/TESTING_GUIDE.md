# jsh Testing Guide

## Overview

This document describes the comprehensive testing infrastructure for jsh, including unit tests, integration tests, shell tests, and performance profiling.

## Test Structure

```
test/
├── test_helper.bash           # Shared test utilities for BATS
├── unit/                      # BATS unit tests
│   ├── test_colors.bats       # Tests for src/lib/colors.sh
│   └── test_packages.bats     # Tests for src/lib/packages.sh
├── integration/               # BATS integration tests
│   ├── test_init_workflow.bats
│   └── test_dotfiles_workflow.bats
├── test_*.zsh                 # Shell-specific tests (zsh)
└── profile_*.zsh              # Performance profiling scripts
```

## Running Tests

### All Tests

```bash
make test
```

This runs:

1. BATS unit tests (`test/unit/*.bats`)
2. BATS integration tests (`test/integration/*.bats`)
3. Shell tests (`test/test_*.zsh`)
4. jsh CLI validation

### Individual Test Suites

```bash
# Unit tests only
make test-unit

# Integration tests only
make test-integration

# Shell tests only
make test-shell

# jsh CLI validation
make test-jsh
```

### Performance Testing

```bash
# Run all profiling scripts
make test-performance

# Run comprehensive profiling with detailed breakdown
make test-profile-comprehensive

# View test coverage
make test-coverage
```

### Continuous Testing

```bash
# Watch mode - reruns tests on file changes (requires fswatch)
make test-watch
```

## Test Coverage

Current test coverage (as of implementation):

- **Unit Tests**: 34 tests covering lib/colors.sh and lib/packages.sh

  - colors.sh: 17 tests (100% function coverage)
  - packages.sh: 17 tests (90% function coverage - interactive/sudo functions skipped)

- **Integration Tests**: 10 tests covering CLI workflows

  - init workflow: 6 tests
  - dotfiles workflow: 4 tests

- **Shell Tests**: 4 tests for shell-specific functionality

  - Notification system
  - Precmd hooks
  - Instant prompt integration
  - Complete flow testing

- **Profile Tests**: 5 scripts for performance analysis
  - Command version check
  - .jshrc loading
  - Shell startup
  - Detailed breakdown
  - Comprehensive profiling

## Writing Tests

### Unit Tests (BATS)

Unit tests use the BATS (Bash Automated Testing System) framework:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper.bash'
  source "${JSH_ROOT}/src/lib/colors.sh"
  setup_test_dir  # Creates isolated temp directory
}

teardown() {
  teardown_test_dir  # Cleans up temp directory
}

@test "function_name: test description" {
  run function_name arg1 arg2
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "expected output" ]]
}
```

### Integration Tests (BATS)

Integration tests verify end-to-end workflows:

```bash
@test "jsh command --flag: expected behavior" {
  run "${JSH_ROOT}/jsh" command --flag
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "expected output" ]]
}
```

### Shell Tests (zsh)

Shell-specific tests verify zsh integration:

```bash
#!/usr/bin/env zsh
# Test description

# Source configuration
source ~/.zshrc

# Test functionality
if typeset -f function_name > /dev/null; then
  echo "✓ Test passed"
else
  echo "✗ Test failed"
  exit 1
fi
```

### Performance Tests (Profiling)

Profile scripts measure shell initialization time:

```bash
#!/usr/bin/env zsh
export JSH_PROFILE=1
source "${HOME}/.jsh/src/lib/profiler.sh"

profile_init

profile_start "section" "Description"
# Code to profile
profile_end "section"

profile_report
profile_save "profile_name"
```

## Test Helpers

The `test/test_helper.bash` file provides utilities for writing tests:

- `setup_test_dir` - Creates isolated temporary directory
- `teardown_test_dir` - Cleans up temporary directory
- `create_temp_json` - Creates temporary JSON file
- `has_command` - Checks if command exists
- `assert_file_exists` - Asserts file exists
- `assert_contains` - Asserts string contains substring
- `assert_equals` - Asserts strings are equal

## Continuous Integration

The CI workflow (`make ci`) runs:

1. Syntax checking (`make check-syntax`)
2. Linting (`make lint`)
3. All tests (`make test`)
4. Build verification (`make build`)

## Performance Profiling

### Using the Profiler Library

Enable profiling in your shell:

```bash
export JSH_PROFILE=1
source ~/.zshrc
```

This will generate a detailed performance report showing time spent in each initialization section.

### Profiling Output Formats

**Table format (default)**:

```
=== Shell Initialization Profile ===
┌─────────────────────────────────────────┬──────────┬─────────┐
│ Section                                 │ Time (ms)│ % Total │
├─────────────────────────────────────────┼──────────┼─────────┤
│ .jshrc (exports, aliases, functions)    │      120 │     15% │
│ Zinit core initialization               │       80 │     10% │
│ Powerlevel10k instant prompt            │       50 │      6% │
...
```

**JSON format**:

```bash
export JSH_PROFILE=1
export JSH_PROFILE_FORMAT=json
export JSH_PROFILE_OUTPUT=/tmp/profile.json
source ~/.zshrc
```

### Interpreting Results

Key metrics to monitor:

- **Total startup time**: Target <500ms for interactive shells
- **Top slowest sections**: Focus optimization efforts here
- **Unaccounted time**: May indicate unmeasured code paths

## Cache Management

The optimization system uses caching to improve performance. Clear caches with:

```bash
make clean-cache
```

This removes:

- `~/.cache/jsh/locale` - Locale detection cache
- `~/.cache/jsh/path_prefix` - PATH construction cache
- `~/.cache/jsh/brew_shellenv` - Homebrew environment cache
- `~/.cache/jsh/profile/` - Profiling data

Caches automatically rebuild on next shell startup.

## Troubleshooting

### Tests Failing

1. **BATS not installed**: Run `brew install bats-core`
2. **JSH_ROOT not set**: Tests will auto-detect, but you can set manually:

   ```bash
   export JSH_ROOT=/path/to/.jsh
   ```

3. **Permission errors**: Ensure test files are executable:

   ```bash
   chmod +x test/**/*.bats test/**/*.zsh
   ```

### Performance Issues

1. **Clear caches**: `make clean-cache`
2. **Check for stale cache files**: Look in `~/.cache/jsh/`
3. **Run comprehensive profiling**: `make test-profile-comprehensive`
4. **Compare before/after**: Use `profile_save` to save baselines

## Best Practices

1. **Run tests before committing**: Use pre-commit hooks or `make pre-commit`
2. **Write tests for new features**: Aim for >80% coverage
3. **Profile after optimizations**: Verify performance improvements
4. **Keep tests fast**: Unit tests should run in <5s
5. **Use descriptive test names**: Follow pattern "function: expected behavior"

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Shell Testing Best Practices](https://github.com/sstephenson/bats/wiki/Best-Practices)
- [jsh Optimization Analysis](./OPTIMIZATION_ANALYSIS.md)
