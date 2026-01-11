#!/usr/bin/env bash
# staged-commits.sh - Execute commits with realistic timing delays
#
# Simulates natural development timing for each commit based on complexity.
# Idempotent: safely resumes from where it left off if interrupted.
#
# Usage:
#   ./scripts/staged-commits.sh              # Full realistic timing (~12 hours)
#   SPEED_MULTIPLIER=0.1 ./scripts/staged-commits.sh   # 10x faster (~1.2 hours)
#   SPEED_MULTIPLIER=0.01 ./scripts/staged-commits.sh  # 100x faster (~7 minutes)
#   DRY_RUN=1 ./scripts/staged-commits.sh    # Show plan without executing
#   BACKDATE=1 ./scripts/staged-commits.sh   # Set commit timestamps to simulated times

set -euo pipefail

# Configuration
SPEED_MULTIPLIER="${SPEED_MULTIPLIER:-1.0}"
DRY_RUN="${DRY_RUN:-0}"
BACKDATE="${BACKDATE:-0}"  # If 1, set commit timestamps to simulated development times
LOG_FILE="${LOG_FILE:-/tmp/staged-commits-$(date +%Y%m%d-%H%M%S).log}"

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
DIM=$'\e[2m'
BOLD=$'\e[1m'
RST=$'\e[0m'

# Timing estimates (in seconds) - time to WRITE each commit's changes
# Delay happens BEFORE each commit (except first)
# Using indexed array for Bash 3.2 compatibility (macOS)
COMMIT_DELAYS=(
    0       # placeholder (1-indexed)
    0       # 1: immediate - just reviewing/deleting
    1200    # 2: 20 min - after removing legacy, write core dotfiles
    5400    # 3: 90 min - after core dotfiles, write shell modules
    18000   # 4: 5 hours - after shell sources, write config files (big one)
    4500    # 5: 75 min - after configs, set up shell libraries
    2700    # 6: 45 min - after libraries, gather binaries
    5400    # 7: 90 min - after binaries, rewrite CLI + infrastructure
)

# Commit message prefixes for idempotency detection
COMMIT_MARKERS=(
    ""
    "refactor!: remove legacy bashly-based architecture"
    "feat(core): add reorganized dotfiles foundation"
    "feat(src): add modular shell sources"
    "feat(config): add package configs and project management"
    "feat(lib): add shell libraries and plugins"
    "feat(lib): add pre-built binaries for fzf, nvim, gitstatus"
    "feat: complete CLI rewrite with new architecture"
)

# Descriptions for each commit
COMMIT_DESCRIPTIONS=(
    ""
    "Remove legacy bashly-based architecture"
    "Add core dotfiles (zshrc, gitconfig, tmux, p10k)"
    "Add modular shell sources (80+ aliases, 50+ functions)"
    "Add configuration files (packages, profiles, projects)"
    "Add shell libraries (p10k, fzf, z, zsh plugins)"
    "Add pre-built binaries (fzf, nvim, gitstatus)"
    "Update CLI and infrastructure (Makefile, CI, README)"
)

# Track commit timestamps for backdating
COMMIT_TIMESTAMPS=()

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

info() { echo "${CYAN}$1${RST}"; }
success() { echo "${GREEN}$1${RST}"; }
warn() { echo "${YELLOW}$1${RST}"; }
error() { echo "${RED}$1${RST}"; }

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if ((hours > 0)); then
        printf "%dh %dm %ds" "$hours" "$minutes" "$secs"
    elif ((minutes > 0)); then
        printf "%dm %ds" "$minutes" "$secs"
    else
        printf "%ds" "$secs"
    fi
}

format_timestamp() {
    local ts=$1
    date -r "$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null
}

format_time_only() {
    local ts=$1
    date -r "$ts" '+%H:%M' 2>/dev/null || date -d "@$ts" '+%H:%M' 2>/dev/null
}

calculate_delay() {
    local base_seconds=$1
    awk "BEGIN {printf \"%.0f\", $base_seconds * $SPEED_MULTIPLIER}"
}

# Check if a commit has already been made (for idempotency)
commit_exists() {
    local marker="$1"
    git log --oneline --grep="$marker" -n 1 2>/dev/null | grep -q .
}

# Calculate all commit timestamps based on current time + delays
calculate_timestamps() {
    local now=$(date +%s)
    local cumulative=0

    COMMIT_TIMESTAMPS=(0)  # placeholder for index 0

    for i in 1 2 3 4 5 6 7; do
        if should_run_commit $i; then
            cumulative=$((cumulative + $(calculate_delay "${COMMIT_DELAYS[$i]}")))
            COMMIT_TIMESTAMPS+=($((now + cumulative)))
        else
            COMMIT_TIMESTAMPS+=(0)  # Already done
        fi
    done
}

sleep_with_progress() {
    local total_seconds=$1
    local description=$2

    if ((total_seconds <= 0)); then
        return
    fi

    local start_time=$(date +%s)
    local end_time=$((start_time + total_seconds))

    echo ""
    info "Simulating development time: $(format_duration "$total_seconds")"
    info "Working on: $description"
    echo ""

    while true; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local remaining=$((end_time - now))

        if ((remaining <= 0)); then
            break
        fi

        local percent=$((elapsed * 100 / total_seconds))
        local bar_width=40
        local filled=$((percent * bar_width / 100))
        local empty=$((bar_width - filled))

        printf "\r${DIM}[${RST}"
        printf "${GREEN}%${filled}s${RST}" | tr ' ' '='
        printf "${DIM}%${empty}s${RST}" | tr ' ' '-'
        printf "${DIM}]${RST} "
        printf "%3d%% " "$percent"
        printf "${DIM}(${RST}$(format_duration "$remaining") remaining${DIM})${RST}  "

        sleep 1
    done

    printf "\r${GREEN}[%${bar_width}s]${RST} 100%% ${GREEN}Done!${RST}%20s\n" | tr ' ' '='
    echo ""
}

run_cmd() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "${DIM}[DRY RUN] Would execute:${RST}"
        echo "$1"
        return 0
    fi

    log "Executing: $1"
    eval "$1"
}

# Run git commit with optional backdating
run_commit() {
    local commit_num=$1
    local commit_msg="$2"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "${DIM}[DRY RUN] Would execute:${RST}"
        echo "git commit -m \"...\""
        return 0
    fi

    if [[ "$BACKDATE" == "1" ]] && [[ -n "${COMMIT_TIMESTAMPS[$commit_num]:-}" ]] && ((COMMIT_TIMESTAMPS[$commit_num] > 0)); then
        local ts="${COMMIT_TIMESTAMPS[$commit_num]}"
        local date_str=$(format_timestamp "$ts")
        log "Backdating commit to: $date_str"
        GIT_AUTHOR_DATE="$date_str" GIT_COMMITTER_DATE="$date_str" git commit -m "$commit_msg"
    else
        git commit -m "$commit_msg"
    fi
}

# Returns 0 if commit should run, 1 if already done
should_run_commit() {
    local num=$1
    local marker="${COMMIT_MARKERS[$num]}"

    if [[ "$DRY_RUN" == "1" ]]; then
        # In dry run, check if commit exists to show accurate status
        if commit_exists "$marker"; then
            return 1
        fi
        return 0
    fi

    if commit_exists "$marker"; then
        return 1  # Already done
    fi

    return 0  # Should run
}

print_skip() {
    local num=$1
    echo "${DIM}[SKIP] Commit $num already exists, skipping...${RST}"
}

commit_1_remove_legacy() {
    local num=1

    if ! should_run_commit $num; then
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 1/7: Remove legacy bashly-based architecture
================================================================================
BANNER

    info "Executing immediately (no delay for first commit)"
    echo ""

    run_cmd 'git add -u .czrc .editorconfig .env.example .eslintrc.json .fzf .gitconfig .inputrc \
    .markdownlint.json .pre-commit-config.yaml .prettierignore .prettierrc.json \
    .pylintrc .shellcheckrc .yamllint DOTFILES.md VERSION bun.lock eslint.config.js'

    run_cmd 'git add -u configs/ docs/ dotfiles/ src/ test/ scripts/unix/ docker/test.Dockerfile'

    run_commit 1 "$(cat <<'EOF'
refactor!: remove legacy bashly-based architecture

BREAKING CHANGE: Complete removal of the bashly-generated CLI system

Removed:
- Old bashly CLI source (src/bashly.yml, src/*_command.sh, src/lib/*.sh)
- Old dotfiles directory (dotfiles/)
- Old configs directory (configs/)
- Old test suite (test/)
- Old documentation (docs/)
- Legacy config files (.czrc, .eslintrc.json, .prettierrc.json, etc.)

This clears the way for the new modular shell-based architecture.
EOF
)"

    success "Commit 1 complete!"
}

commit_2_core_dotfiles() {
    local num=2

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Creating core dotfiles: zshrc, bashrc, gitconfig, tmux.conf, p10k theme"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 2/7: Add new core dotfiles
================================================================================
BANNER

    run_cmd 'git add core/'

    run_commit 2 "$(cat <<'EOF'
feat(core): add reorganized dotfiles foundation

New core/ directory with cleaned up configurations:
- .bashrc, .zshrc - shell entry points (minimal, source from src/)
- gitconfig, gitignore_global - git configuration
- inputrc - readline configuration
- tmux.conf - tmux configuration
- p10k.zsh - powerlevel10k prompt theme
- .config/ - XDG configs (atuin, btop, gh, ghostty, k9s, nvim, etc.)
- Linting configs (.editorconfig, .shellcheckrc, .pylintrc, etc.)
EOF
)"

    success "Commit 2 complete!"
}

commit_3_shell_sources() {
    local num=3

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Writing shell modules: aliases, functions, git helpers, fzf integration"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 3/7: Add modular shell sources
================================================================================
BANNER

    run_cmd 'git add src/'

    run_commit 3 "$(cat <<'EOF'
feat(src): add modular shell sources

Pure shell modules for a portable, fast-loading environment:
- init.sh - Shell initialization and bootstrap
- core.sh - Essential functions and environment setup
- aliases.sh - 80+ aliases (tiered: core always loads, extended for detected tools)
- functions.sh - 50+ productivity functions (extract, serve, mkcd, etc.)
- git.sh - Git aliases and functions
- fzf/ - FZF integration (completion, key-bindings for bash/zsh)
- profiles.sh - Git identity management
- projects.sh - Project/workspace management
- prompt.sh - Prompt customization
- vi-mode.sh - Vi editing mode with cursor indicators
- bash.sh, zsh.sh - Shell-specific configurations
- completions/ - Shell completion scripts
EOF
)"

    success "Commit 3 complete!"
}

commit_4_config_files() {
    local num=4

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Writing 80+ aliases, 50+ functions, vi-mode, profiles, projects (the big one)"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 4/7: Add configuration files
================================================================================
BANNER

    run_cmd 'git add config/ local/'

    run_commit 4 "$(cat <<'EOF'
feat(config): add package configs and project management

Configuration files for the new architecture:
- dependencies.json - Core dependency definitions
- packages/common/ - Cross-platform packages (cargo, npm)
- packages/linux/ - Linux package configs (apt, dnf, brew)
- packages/macos/ - macOS package configs (formulae, casks)
- profiles.json.example - Git identity profiles template
- projects.json - Project/workspace definitions
- vscode/ - VS Code settings and keybindings
- local/*.example - Templates for local overrides
EOF
)"

    success "Commit 4 complete!"
}

commit_5_shell_libraries() {
    local num=5

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Creating package configs, profiles system, project definitions"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 5/7: Add shell libraries
================================================================================
BANNER

    run_cmd 'git add lib/fzf lib/gitstatus lib/p10k lib/z lib/zsh-autosuggestions \
    lib/zsh-completions lib/zsh-history-substring-search \
    lib/zsh-syntax-highlighting lib/zsh-z'

    run_commit 5 "$(cat <<'EOF'
feat(lib): add shell libraries and plugins

Vendored shell plugins for consistent, fast loading:
- p10k/ - Powerlevel10k prompt theme
- fzf/ - FZF shell integration
- gitstatus - Git status for p10k (fast git info)
- z/ - Directory jumping (z.sh)
- zsh-autosuggestions/ - Fish-like suggestions
- zsh-completions/ - Additional completions
- zsh-history-substring-search/ - History search
- zsh-syntax-highlighting/ - Syntax highlighting
- zsh-z/ - Zsh port of z
EOF
)"

    success "Commit 5 complete!"
}

commit_6_prebuilt_binaries() {
    local num=6

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Setting up vendored plugins: p10k, fzf, gitstatus, z, zsh plugins"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 6/7: Add pre-built binaries
================================================================================
BANNER

    run_cmd 'git add lib/bin/'

    run_commit 6 "$(cat <<'EOF'
feat(lib): add pre-built binaries for fzf, nvim, gitstatus

Pre-compiled binaries for 4 platform/architecture combinations:
- darwin-amd64 (Intel Mac)
- darwin-arm64 (Apple Silicon)
- linux-amd64 (x86_64 Linux)
- linux-arm64 (ARM64 Linux)

Includes:
- fzf - Fuzzy finder
- nvim - Neovim with treesitter parsers
- gitstatusd - Fast git status daemon for p10k

These enable a fully portable shell environment without requiring
package managers on target systems.
EOF
)"

    success "Commit 6 complete!"
}

commit_7_cli_infrastructure() {
    local num=7

    if should_run_commit $num; then
        local delay=$(calculate_delay "${COMMIT_DELAYS[$num]}")
        if ((delay > 0)); then
            sleep_with_progress "$delay" "Rewriting CLI (9400->2700 lines), Makefile, README, CI workflows"
        fi
    else
        print_skip $num
        return 0
    fi

    cat <<'BANNER'

================================================================================
  COMMIT 7/7: Update main CLI and infrastructure
================================================================================
BANNER

    run_cmd 'git add jsh bin/ Makefile README.md .gitignore .gitmodules .gitattributes \
    .github/ .vscode/settings.json docker/ renovate.json scripts/'

    run_commit 7 "$(cat <<'EOF'
feat: complete CLI rewrite with new architecture

Major rewrite of JSH from bashly-generated to pure shell:

CLI (jsh):
- Rewritten from 9400 to 2700 lines
- install, init, update, status, doctor commands
- Cleaner, more maintainable codebase

Infrastructure:
- Makefile updated for new build/test/lint targets
- README.md rewritten with new architecture docs
- .gitignore updated for new structure
- .gitmodules updated for shell plugins

CI/CD:
- build-binaries.yml - Build fzf/nvim for all platforms
- build-fzf.yml - FZF compilation workflow
- ci.yml - Main CI pipeline
- update-submodules.yml - Keep dependencies current

Utilities:
- bin/cafe, bin/ipmi, bin/nukem, bin/proxy - New utility scripts
- bin/jssh - SSH with environment injection
- scripts/ - Development and maintenance scripts
EOF
)"

    success "Commit 7 complete!"
}

count_pending_commits() {
    local count=0
    for i in 1 2 3 4 5 6 7; do
        if should_run_commit $i; then
            count=$((count + 1))
        fi
    done
    echo $count
}

get_remaining_time() {
    local total=0
    local started=0
    for i in 1 2 3 4 5 6 7; do
        if should_run_commit $i; then
            if ((started == 0)); then
                started=1  # First pending commit has no delay
            else
                total=$((total + COMMIT_DELAYS[i]))
            fi
        fi
    done
    calculate_delay "$total"
}

print_summary() {
    local pending=$(count_pending_commits)
    local remaining_time=$(get_remaining_time)

    # Calculate timestamps for display
    calculate_timestamps

    cat <<EOF

${BOLD}Staged Commits Script${RST}
${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}

${CYAN}Configuration:${RST}
  Speed multiplier: ${BOLD}${SPEED_MULTIPLIER}x${RST}
  Backdate commits: ${BOLD}${BACKDATE}${RST}
  Log file: ${DIM}${LOG_FILE}${RST}

${CYAN}Commit Schedule:${RST}
EOF

    printf "  ${DIM}%-3s %-45s %-12s %-8s %s${RST}\n" "#" "Description" "Delay" "Status" "Est. Time"
    printf "  ${DIM}%s${RST}\n" "─────────────────────────────────────────────────────────────────────────────────"

    for i in 1 2 3 4 5 6 7; do
        local status=""
        local delay_str=""
        local time_str=""

        if should_run_commit $i; then
            status="${GREEN}pending${RST}"
            if [[ -n "${COMMIT_TIMESTAMPS[$i]:-}" ]] && ((COMMIT_TIMESTAMPS[$i] > 0)); then
                time_str=$(format_time_only "${COMMIT_TIMESTAMPS[$i]}")
            fi
        else
            status="${DIM}done${RST}"
            time_str="${DIM}--:--${RST}"
        fi

        if ((i == 1)); then
            delay_str="${DIM}immediate${RST}"
        else
            delay_str="${DIM}+$(format_duration "$(calculate_delay "${COMMIT_DELAYS[$i]}")")${RST}"
        fi

        printf "  %-3s %-45s %-20s %-16s %s\n" \
            "$i." \
            "${COMMIT_DESCRIPTIONS[$i]}" \
            "$delay_str" \
            "$status" \
            "$time_str"
    done

    cat <<EOF

${CYAN}Summary:${RST}
  Pending commits: ${BOLD}${pending}/7${RST}
  Estimated duration: ${BOLD}$(format_duration "$remaining_time")${RST}
EOF

    if ((pending > 0)); then
        local first_ts=""
        local last_ts=""
        for i in 1 2 3 4 5 6 7; do
            if should_run_commit $i && [[ -n "${COMMIT_TIMESTAMPS[$i]:-}" ]] && ((COMMIT_TIMESTAMPS[$i] > 0)); then
                if [[ -z "$first_ts" ]]; then
                    first_ts="${COMMIT_TIMESTAMPS[$i]}"
                fi
                last_ts="${COMMIT_TIMESTAMPS[$i]}"
            fi
        done

        if [[ -n "$first_ts" ]] && [[ -n "$last_ts" ]]; then
            echo "  Start time: ${BOLD}$(format_timestamp "$first_ts")${RST}"
            echo "  Finish time: ${BOLD}$(format_timestamp "$last_ts")${RST}"
        fi
    fi

    cat <<EOF

${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}
EOF

    if ((pending == 0)); then
        success "All commits already complete! Nothing to do."
        exit 0
    fi
}

main() {
    print_summary

    if [[ "$DRY_RUN" == "1" ]]; then
        echo ""
        info "DRY RUN mode - no commits will be made"
        echo ""
        exit 0
    fi

    echo ""
    echo "This will create ${BOLD}$(count_pending_commits)${RST} commits with the schedule shown above."
    if [[ "$BACKDATE" == "1" ]]; then
        warn "BACKDATE=1: Commit timestamps will be set to simulated development times"
    fi
    echo ""
    read -p "Press Enter to proceed, or Ctrl+C to cancel... "
    echo ""

    # Recalculate timestamps at actual start time
    calculate_timestamps

    log "Starting staged commits with SPEED_MULTIPLIER=$SPEED_MULTIPLIER BACKDATE=$BACKDATE"

    local start_time=$(date +%s)

    commit_1_remove_legacy
    commit_2_core_dotfiles
    commit_3_shell_sources
    commit_4_config_files
    commit_5_shell_libraries
    commit_6_prebuilt_binaries
    commit_7_cli_infrastructure

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))

    cat <<EOF

${GREEN}================================================================================
  ALL COMMITS COMPLETE!
================================================================================${RST}

Total execution time: ${BOLD}$(format_duration "$total_time")${RST}
Log file: ${DIM}${LOG_FILE}${RST}

${CYAN}Git log:${RST}
EOF

    git log --oneline -7
}

main "$@"
