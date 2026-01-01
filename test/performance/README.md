# Performance Testing

This directory contains shell profiling scripts for performance analysis and optimization.

## Purpose

These scripts measure shell initialization performance, identify bottlenecks, and track performance regressions over time. They are **not automated tests** - they are manual profiling tools.

## Scripts

### profile_command_v.zsh

Measures command existence checking performance.

**Usage:**

```bash
zsh test/performance/profile_command_v.zsh
```

**What it measures:**

- Single `command -v` execution time
- Batch command checking overhead
- GNU tool detection performance
- Full .jshrc sourcing time

**When to use:**

- Optimizing command existence checks
- Reducing .jshrc load time
- Benchmarking alternative approaches

---

### profile_comprehensive.zsh

Complete shell startup profiling with detailed plugin breakdown.

**Usage:**

```bash
JSH_PROFILE=1 zsh test/performance/profile_comprehensive.zsh
```

**What it measures:**

- Environment variable exports
- .jshrc sourcing
- Zinit initialization
- Each plugin load time
- Powerlevel10k instant prompt

**Output:**

- Generates profiling report (table or JSON)
- Identifies slowest sections
- Calculates percentage breakdown

**When to use:**

- Shell startup feels slow
- After adding new plugins
- Optimizing initialization sequence

---

### profile_jshrc.zsh

Targeted profiling of .jshrc sections.

**Usage:**

```bash
zsh test/performance/profile_jshrc.zsh
```

**What it measures:**

- Essential exports
- Locale detection (locale -a calls)
- Color function definitions
- Alias definitions
- Path modifications
- Homebrew shellenv

**When to use:**

- .jshrc-specific slowdowns
- Optimizing individual sections
- Identifying expensive locale checks

---

## Performance Targets

### Shell Initialization

- **Target:** < 200ms total startup time
- **Acceptable:** 200-500ms
- **Needs optimization:** > 500ms

### Critical Sections

- `.jshrc sourcing`: < 50ms
- `Plugin loading`: < 100ms per plugin
- `Instant prompt`: < 10ms

## Workflow

1. **Baseline measurement:**

   ```bash
   zsh test/performance/profile_comprehensive.zsh > baseline.txt
   ```

2. **Make changes** (optimize code, add plugins, etc.)

3. **Compare results:**

   ```bash
   zsh test/performance/profile_comprehensive.zsh > after.txt
   diff baseline.txt after.txt
   ```

4. **Target slow sections** with specific profiling scripts

## Tips

- Run profiling scripts multiple times and average results
- Clear caches before profiling: `rm -rf ~/.cache/jsh ~/.cache/p10k*`
- Close other terminal sessions to reduce system load
- Profile in a clean environment (`zsh -f` then source configs)

## Integration with JSH_PROFILE

The profiler library (`src/lib/profiler.sh`) is enabled via:

```bash
export JSH_PROFILE=1
```

Add profiling to your shell config:

```bash
if [[ "$JSH_PROFILE" == "1" ]]; then
  source "${JSH_ROOT}/src/lib/profiler.sh"
  profile_init
  profile_start "my_section" "Description"
  # ... code to profile ...
  profile_end "my_section"
  profile_report
fi
```

## See Also

- [TESTING_GUIDE.md](../../docs/TESTING_GUIDE.md) - Automated testing
- [OPTIMIZATION_ANALYSIS.md](../../docs/OPTIMIZATION_ANALYSIS.md) - Performance findings
- [src/lib/profiler.sh](../../src/lib/profiler.sh) - Profiler library
