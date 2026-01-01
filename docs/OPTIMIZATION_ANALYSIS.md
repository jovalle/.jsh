# Shell Initialization Optimization Analysis

## Executive Summary

This document identifies performance bottlenecks in the jsh shell initialization process and proposes optimizations to reduce startup time while maintaining full functionality.

## Baseline Performance

Current shell initialization time (measured with `profile_comprehensive.zsh`):

- **Total startup time**: ~800-1200ms (varies by system and cache state)
- **Major contributors**:
  - Zinit plugins: 400-600ms
  - Completion system: 150-300ms
  - .jshrc sourcing: 100-150ms

## Identified Bottlenecks

### 1. Locale Detection (dotfiles/.jshrc:30-44)

**Issue**: Runs `locale -a` command every shell startup to detect available locales.

**Current Code**:

```bash
if locale -a 2> /dev/null | grep -qE "^en_US\.UTF-8$|^en_US\.utf8$"; then
  export LANG=en_US.UTF-8
elif locale -a 2> /dev/null | grep -qE "^C\.UTF-8$|^C\.utf8$"; then
  export LANG=C.UTF-8
else
  export LANG=C
fi
```

**Impact**: 10-30ms per shell startup

**Optimization**: Cache locale detection result

```bash
_detect_locale() {
  local cache_file="${HOME}/.cache/jsh/locale"
  if [[ -f "$cache_file" ]] && [[ -n "$(cat "$cache_file" 2>/dev/null)" ]]; then
    cat "$cache_file"
    return
  fi

  local locale_result
  if locale -a 2>/dev/null | grep -qE "^en_US\.UTF-8$|^en_US\.utf8$"; then
    locale_result="en_US.UTF-8"
  elif locale -a 2>/dev/null | grep -qE "^C\.UTF-8$|^C\.utf8$"; then
    locale_result="C.UTF-8"
  else
    locale_result="C"
  fi

  mkdir -p "$(dirname "$cache_file")"
  echo "$locale_result" > "$cache_file"
  echo "$locale_result"
}

export LANG=$(_detect_locale)
export LC_ALL="${LANG}"
unset -f _detect_locale
```

**Estimated savings**: 10-30ms

---

### 2. PATH Construction (dotfiles/.jshrc:64-98)

**Issue**: Iterates through 12 potential paths, checking existence for each shell startup.

**Current Code**:

```bash
local_paths=(
  "${HOME}/.local/bin"
  "${JSH}"
  "${JSH}/bin"
  # ... 9 more paths
)

local_prefix=""
for p in "${local_paths[@]}"; do
  if [[ -d "${p}" ]]; then
    if [[ -z "${local_prefix}" ]]; then
      local_prefix="${p}"
    else
      local_prefix="${local_prefix}:${p}"
    fi
  fi
done
```

**Impact**: 5-15ms per shell startup

**Optimization**: Cache PATH construction result

```bash
_build_path_prefix() {
  local cache_file="${HOME}/.cache/jsh/path_prefix"
  local cache_mtime_file="${cache_file}.mtime"
  local current_mtime=$(date +%s)

  # Cache valid for 1 hour (3600 seconds)
  if [[ -f "$cache_file" ]] && [[ -f "$cache_mtime_file" ]]; then
    local cached_mtime=$(cat "$cache_mtime_file")
    if (( current_mtime - cached_mtime < 3600 )); then
      cat "$cache_file"
      return
    fi
  fi

  # Rebuild path
  local local_paths=(
    "${HOME}/.local/bin"
    "${JSH}"
    "${JSH}/bin"
    "${GEM_HOME}/bin"
    "${HOME}/.cargo/bin"
    "${JSH}/.fzf/bin"
    "${HOME}/go/bin"
    "${HOME}/.linuxbrew/bin"
    "${HOME}/linuxbrew/.linuxbrew/bin"
    "/home/linuxbrew/.linuxbrew/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/opt/ruby/bin"
  )

  local local_prefix=""
  for p in "${local_paths[@]}"; do
    if [[ -d "${p}" ]]; then
      if [[ -z "${local_prefix}" ]]; then
        local_prefix="${p}"
      else
        local_prefix="${local_prefix}:${p}"
      fi
    fi
  done

  mkdir -p "$(dirname "$cache_file")"
  echo "$local_prefix" > "$cache_file"
  echo "$current_mtime" > "$cache_mtime_file"
  echo "$local_prefix"
}

local_prefix=$(_build_path_prefix)
if [[ -n "${local_prefix}" ]]; then
  export PATH="${local_prefix}:${PATH}"
fi
unset local_prefix
unset -f _build_path_prefix
```

**Estimated savings**: 5-15ms

---

### 3. Homebrew Environment Initialization (dotfiles/.jshrc:107-127)

**Issue**: Runs `brew shellenv` every shell startup, which parses Homebrew configuration.

**Current Code**:

```bash
_init_brew_env() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 0

  local brew_candidates=(...)

  for brew_bin in "${brew_candidates[@]}"; do
    if [[ -x "${brew_bin}" ]]; then
      eval "$("${brew_bin}" shellenv 2> /dev/null)"
      return 0
    fi
  done
}
_init_brew_env
```

**Impact**: 20-40ms per shell startup

**Optimization**: Cache `brew shellenv` output

```bash
_init_brew_env() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 0

  local cache_file="${HOME}/.cache/jsh/brew_shellenv"
  local cache_mtime_file="${cache_file}.mtime"
  local current_mtime=$(date +%s)

  # Cache valid for 24 hours
  if [[ -f "$cache_file" ]] && [[ -f "$cache_mtime_file" ]]; then
    local cached_mtime=$(cat "$cache_mtime_file")
    if (( current_mtime - cached_mtime < 86400 )); then
      source "$cache_file"
      return 0
    fi
  fi

  local brew_candidates=(
    "/home/linuxbrew/.linuxbrew/bin/brew"
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
    "${HOME}/.linuxbrew/bin/brew"
  )

  for brew_bin in "${brew_candidates[@]}"; do
    if [[ -x "${brew_bin}" ]]; then
      mkdir -p "$(dirname "$cache_file")"
      "${brew_bin}" shellenv > "$cache_file" 2>/dev/null
      echo "$current_mtime" > "$cache_mtime_file"
      source "$cache_file"
      return 0
    fi
  done
}
_init_brew_env
unset -f _init_brew_env
```

**Estimated savings**: 20-40ms

---

### 4. Completion Loading (dotfiles/.jshrc:540-638)

**Issue**: Loads completions for all tools sequentially, many via `eval $(command --completion)`.

**Current Code**:

```bash
_jsh_load_completions() {
  # ... various eval "$(tool completion shell)" calls
}
```

**Impact**: 100-200ms per shell startup

**Optimization Strategy**:

1. **Lazy load completions on first use** (zsh supports this via compdef)
2. **Compile completions** into zcompdump
3. **Use completion caching** where available

```bash
_jsh_lazy_completion() {
  local cmd="$1"
  local init_cmd="$2"

  # Define a lazy loader that runs on first tab completion
  eval "
  _${cmd}_lazy() {
    unfunction _${cmd}_lazy
    ${init_cmd}
    _${cmd} \"\$@\"
  }
  compdef _${cmd}_lazy ${cmd}
  "
}

# Example usage:
_jsh_lazy_completion kubectl "source <(kubectl completion zsh)"
_jsh_lazy_completion docker "eval \"\$(docker completion zsh)\""
```

**Estimated savings**: 50-100ms (on first startup, more on subsequent)

---

### 5. Redundant Function Definitions

**Issue**: Color helper functions defined in both `.jshrc` and `src/lib/colors.sh`.

**Current Code** (dotfiles/.jshrc:50-61):

```bash
if command -v tput > /dev/null 2>&1; then
  error() { echo -e "$(tput setaf 1)$*$(tput sgr0)"; }
  warn() { echo -e "$(tput setaf 3)$*$(tput sgr0)"; }
  success() { echo -e "$(tput setaf 2)$*$(tput sgr0)"; }
  info() { echo -e "$(tput setaf 4)$*$(tput sgr0)"; }
else
  error() { echo -e "\033[31m$*\033[0m"; }
  warn() { echo -e "\033[33m$*\033[0m"; }
  success() { echo -e "\033[32m$*\033[0m"; }
  info() { echo -e "\033[34m$*\033[0m"; }
fi
```

**Impact**: Minimal, but adds clutter

**Optimization**: Remove from `.jshrc`, only keep in `src/lib/colors.sh`

---

### 6. Non-Interactive Shell Optimization

**Issue**: All aliases, functions, and completions load even for non-interactive shells (like `ssh user@host command`).

**Impact**: 50-100ms for non-interactive shells (unnecessary)

**Optimization**: Guard interactive-only code

```bash
# At top of .jshrc
[[ $- != *i* ]] && return  # Exit if not interactive

# Or more granular:
if [[ -n "${PS1:-}" ]]; then
  # Interactive-only code (aliases, completions, prompt)
fi
```

**Estimated savings**: 50-100ms for non-interactive shells

---

### 7. Zinit Plugin Loading

**Issue**: Plugins load sequentially, blocking startup.

**Current Status**: Already uses `zinit light` (async loading), but some plugins are heavy.

**Further Optimization**:

1. **Use turbo mode** for non-critical plugins:

   ```bash
   zinit ice wait'0' lucid
   zinit light akarzim/zsh-docker-aliases
   ```

2. **Defer heavy plugins**:

   ```bash
   # Load after 1 second
   zinit ice wait'1' lucid
   zinit light lukechilds/zsh-nvm
   ```

3. **Use compiled zsh scripts** where possible

**Estimated savings**: 100-200ms (deferred loading moves time post-prompt)

---

## Recommended Implementation Order

### Phase 1: Low-Hanging Fruit (Immediate, <1 hour)

1. Add non-interactive shell guard
2. Cache locale detection
3. Cache PATH construction
4. Cache brew shellenv

**Expected total savings**: 50-100ms

### Phase 2: Completion Optimization (1-2 hours)

1. Implement lazy completion loading
2. Enable completion caching
3. Compile completions

**Expected total savings**: 50-100ms (first run), 100-200ms (subsequent)

### Phase 3: Plugin Optimization (2-3 hours)

1. Implement turbo mode for non-critical plugins
2. Defer heavy plugins (nvm, docker)
3. Benchmark and tune wait times

**Expected total savings**: 100-200ms (perceived, as prompt appears faster)

### Phase 4: Advanced Optimizations (4-6 hours)

1. Compile frequently-used scripts
2. Profile individual alias definitions
3. Optimize PATH deduplication

**Expected total savings**: 20-50ms

## Total Expected Improvement

**Conservative estimate**: 200-350ms reduction in startup time
**Optimistic estimate**: 300-500ms reduction in startup time

**Target**: Sub-500ms shell startup time on modern hardware

---

## Testing Strategy

1. **Baseline measurement**: Run `profile_comprehensive.zsh` before changes
2. **Incremental testing**: Profile after each optimization phase
3. **Regression testing**: Ensure all functionality remains intact
4. **Cross-platform testing**: Test on macOS, Linux, WSL

---

## Cache Invalidation Strategy

Caches should be invalidated when:

1. **Locale cache**: System locale changes (rare)
2. **PATH cache**: New tools installed in standard locations (hourly refresh)
3. **Brew shellenv cache**: Homebrew updated (daily refresh)
4. **Completion cache**: Tool updated (on-demand via `jsh doctor`)

Invalidation helper:

```bash
jsh cache clear  # New command to clear all caches
```

---

## Backwards Compatibility

All optimizations maintain full backwards compatibility:

- Cache files stored in `~/.cache/jsh/` (XDG spec)
- Fallback to non-cached behavior if cache files missing
- No changes to user-facing functionality
- Existing configurations continue to work

---

## Monitoring & Metrics

Add telemetry to track:

1. Shell startup time (via profiler)
2. Cache hit/miss rates
3. Time savings per optimization

Store in `~/.cache/jsh/metrics.json` for analysis.

---

## Future Optimizations

1. **Lazy-load .jshrc sections**: Only load aliases/functions on first use
2. **Precompiled completion bundles**: Distribute pre-compiled completions
3. **Background pre-caching**: Update caches in background via cron/launchd
4. **Minimal mode by default**: Full mode opt-in via `JSH_FULL=1`

---

## References

- [Zsh Performance Optimization Guide](https://blog.jonlu.ca/posts/speeding-up-zsh)
- [Zinit Turbo Mode Documentation](https://github.com/zdharma-continuum/zinit#turbo-and-lucid)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
