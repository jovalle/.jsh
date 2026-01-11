#!/usr/bin/env bash
# commit-wizard.sh - Interactive commit executor using fzf
# Parses .github/CHANGES.md and executes commits sequentially

set -euo pipefail

JSH_DIR="${JSH_DIR:-$HOME/.jsh}"
CHANGES_FILE="${JSH_DIR}/.github/CHANGES.md"
STATE_FILE="${JSH_DIR}/.github/.commits-done"
CYAN=$'\033[36m'
GREEN=$'\033[32m'
RED=$'\033[31m'
DIM=$'\033[2m'
STRIKE=$'\033[9m'
RESET=$'\033[0m'

# Detect platform for bundled binaries
detect_platform() {
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *)      os="unknown" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             arch="unknown" ;;
    esac
    echo "${os}-${arch}"
}

# Find fzf binary (bundled or system)
find_fzf() {
    # Check system PATH first
    if command -v fzf &>/dev/null; then
        echo "fzf"
        return
    fi
    # Use bundled fzf
    local platform
    platform=$(detect_platform)
    local bundled="${JSH_DIR}/lib/bin/${platform}/fzf"
    if [[ -x "$bundled" ]]; then
        echo "$bundled"
        return
    fi
    # Not found
    return 1
}

FZF_CMD=$(find_fzf) || {
    echo "${RED}Error: fzf not found${RESET}"
    echo "Install fzf or run 'make lib ACTION=build C=fzf'"
    exit 1
}

# Ensure state file exists
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# Extract commits from CHANGES.md
# Format: "NUMBER|DESCRIPTION|START_LINE"
# Handles both "#### Commit N:" and "Commit N:" patterns
extract_commits() {
    grep -n 'Commit [0-9]*:' "$CHANGES_FILE" | while IFS=: read -r line_num content; do
        # Extract commit number
        num=$(echo "$content" | sed -n 's/.*Commit \([0-9]*\):.*/\1/p')
        # Extract description (everything after "Commit N: ")
        desc=$(echo "$content" | sed 's/.*Commit [0-9]*: *//')
        # Truncate description to 55 chars
        if [[ ${#desc} -gt 55 ]]; then
            desc="${desc:0:52}..."
        fi
        if [[ -n "$num" ]]; then
            echo "$num|$desc|$line_num"
        fi
    done
}

# Extract the bash command block for a given commit
extract_command() {
    local start_line="$1"
    awk -v start="$start_line" '
        NR > start && /^```bash/ { in_block=1; next }
        NR > start && in_block && /^```/ { exit }
        in_block { print }
    ' "$CHANGES_FILE"
}

# Check if commit is done
is_done() {
    grep -qx "^$1$" "$STATE_FILE" 2>/dev/null
}

# Mark commit as done
mark_done() {
    echo "$1" >> "$STATE_FILE"
}

# Build fzf list with status indicators
build_list() {
    local next_pending=""
    while IFS='|' read -r num desc line; do
        if is_done "$num"; then
            # Strikethrough + dim for completed
            echo -e "${DIM}${STRIKE}[$num] $desc${RESET} ${GREEN}✓${RESET}"
        else
            if [[ -z "$next_pending" ]]; then
                next_pending="$num"
                # Highlight next pending
                echo -e "${CYAN}[$num] $desc${RESET} ←"
            else
                echo -e "[$num] $desc"
            fi
        fi
    done < <(extract_commits)
}

# Get line number for commit
get_commit_line() {
    local target="$1"
    extract_commits | while IFS='|' read -r num desc line; do
        if [[ "$num" == "$target" ]]; then
            echo "$line"
            return
        fi
    done
}

# Find next pending commit number
next_pending_commit() {
    extract_commits | while IFS='|' read -r num desc line; do
        if ! is_done "$num"; then
            echo "$num"
            return
        fi
    done
}

# Main loop
main() {
    if [[ ! -f "$CHANGES_FILE" ]]; then
        echo "${RED}Error: $CHANGES_FILE not found${RESET}"
        echo "Run 'make strategy' first to generate the commit strategy."
        exit 1
    fi

    while true; do
        # Find which line to highlight (next pending)
        local next=$(next_pending_commit)
        local default_line=1

        if [[ -n "$next" ]]; then
            # Count position in list
            local pos=1
            while IFS='|' read -r num desc line; do
                if [[ "$num" == "$next" ]]; then
                    default_line=$pos
                    break
                fi
                ((pos++))
            done < <(extract_commits)
        fi

        # Create temp files for list and preview script
        local list_file preview_script
        list_file=$(mktemp)
        preview_script=$(mktemp)

        # Build the list to a file first (avoids pipe issues)
        build_list > "$list_file"

        # Check if we have any commits
        if [[ ! -s "$list_file" ]]; then
            rm -f "$list_file"
            echo "${RED}No commits found in $CHANGES_FILE${RESET}"
            break
        fi

        cat > "$preview_script" << 'PREVIEW_EOF'
#!/usr/bin/env bash
input="$1"
changes_file="$2"
num=$(echo "$input" | sed -n 's/.*\[\([0-9]*\)\].*/\1/p')
if [[ -n "$num" ]]; then
    awk -v n="$num" '
        $0 ~ "Commit " n ":" { found=1 }
        found && /^```bash/ { in_block=1; next }
        found && in_block && /^```/ { exit }
        in_block { print }
    ' "$changes_file"
fi
PREVIEW_EOF
        chmod +x "$preview_script"

        # Show fzf picker (fullscreen with keybindings)
        # Keybindings use ctrl/alt to avoid interfering with search
        local selection
        selection=$("$FZF_CMD" --ansi \
            --header="ENTER=run  ESC=quit  ^F=resize  ^J/^K=scroll  ^D/^U=page" \
            --header-first \
            --no-sort \
            --height=100% \
            --preview="bash $preview_script {} $CHANGES_FILE" \
            --preview-window=down:60%:wrap \
            --bind='ctrl-f:change-preview-window(down:90%|down:60%|down:30%|hidden)' \
            --bind='ctrl-j:preview-down,ctrl-k:preview-up' \
            --bind='ctrl-d:preview-page-down,ctrl-u:preview-page-up' \
            --bind='ctrl-h:preview-top,ctrl-l:preview-bottom' \
            < "$list_file" 2>/dev/null) || { rm -f "$preview_script" "$list_file"; break; }

        rm -f "$preview_script" "$list_file"

        # Extract commit number from selection (macOS compatible)
        local commit_num
        commit_num=$(echo "$selection" | sed -n 's/.*\[\([0-9]*\)\].*/\1/p')

        if [[ -z "$commit_num" ]]; then
            continue
        fi

        # Check if already done
        if is_done "$commit_num"; then
            echo "${DIM}Commit $commit_num already completed. Select another.${RESET}"
            sleep 1
            continue
        fi

        # Get the command
        local commit_line
        commit_line=$(get_commit_line "$commit_num")

        if [[ -z "$commit_line" ]]; then
            echo "${RED}Could not find commit $commit_num${RESET}"
            sleep 1
            continue
        fi

        local cmd
        cmd=$(extract_command "$commit_line")

        if [[ -z "$cmd" ]]; then
            echo "${RED}No command block found for commit $commit_num${RESET}"
            sleep 1
            continue
        fi

        # Show command and confirm
        echo ""
        echo "${CYAN}═══ Commit $commit_num ═══${RESET}"
        echo ""
        echo "$cmd"
        echo ""
        echo -n "${CYAN}Execute this commit? [Y/n/e(dit)]: ${RESET}"
        read -r confirm

        case "${confirm,,}" in
            n|no)
                echo "Skipped."
                continue
                ;;
            e|edit)
                # Copy to clipboard or temp file for editing
                echo "$cmd" > /tmp/jsh-commit-$commit_num.sh
                echo "Command saved to /tmp/jsh-commit-$commit_num.sh"
                echo "Edit and run manually, then press Enter to mark as done."
                read -r
                mark_done "$commit_num"
                echo "${GREEN}✓ Marked commit $commit_num as done${RESET}"
                continue
                ;;
            *)
                # Execute
                echo ""
                echo "${CYAN}Executing...${RESET}"
                echo ""
                if eval "$cmd"; then
                    mark_done "$commit_num"
                    echo ""
                    echo "${GREEN}✓ Commit $commit_num completed${RESET}"
                else
                    echo ""
                    echo "${RED}✗ Commit $commit_num failed${RESET}"
                    echo -n "Mark as done anyway? [y/N]: "
                    read -r force
                    if [[ "${force,,}" == "y" ]]; then
                        mark_done "$commit_num"
                    fi
                fi
                ;;
        esac

        # Brief pause before showing fzf again
        sleep 0.5
    done

    echo ""
    echo "${GREEN}Done! Use 'make commit-reset' to start over.${RESET}"
}

# Handle arguments
case "${1:-}" in
    --reset)
        rm -f "$STATE_FILE"
        echo "Commit state reset."
        ;;
    --status)
        echo "Completed commits:"
        cat "$STATE_FILE" 2>/dev/null || echo "(none)"
        ;;
    *)
        main
        ;;
esac
