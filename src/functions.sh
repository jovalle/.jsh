#!/usr/bin/env bash
# functions.sh - Utility functions
# Pure shell, portable across bash/zsh
# shellcheck disable=SC2034

[[ -n "${_JSH_FUNCTIONS_LOADED:-}" ]] && return 0
_JSH_FUNCTIONS_LOADED=1

# =============================================================================
# Directory Navigation
# =============================================================================

# Make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return 1
}

# Go up N directories
up() {
    local count="${1:-1}"
    local path=""
    for ((i = 0; i < count; i++)); do
        path="../${path}"
    done
    cd "${path:-.}" || return 1
}

# Quick cd to parent with matching name
# Usage: bd foo -> cd to nearest parent containing "foo"
bd() {
    local target="$1"
    local path="${PWD}"

    while [[ "${path}" != "/" ]]; do
        if [[ "$(basename "${path}")" == *"${target}"* ]]; then
            cd "${path}" || return 1
            return 0
        fi
        path="$(dirname "${path}")"
    done

    echo "No parent directory matching '${target}'" >&2
    return 1
}

# =============================================================================
# File Operations
# =============================================================================

# Create backup with timestamp
bak() {
    local file="$1"
    [[ -z "${file}" ]] && { echo "Usage: bak <file>" >&2; return 1; }
    [[ -e "${file}" ]] || { echo "File not found: ${file}" >&2; return 1; }

    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    cp -a "${file}" "${file}.${timestamp}.bak"
    echo "Backed up: ${file}.${timestamp}.bak"
}

# Batch backup multiple files
backup() {
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    for file in "$@"; do
        if [[ -e "${file}" ]]; then
            cp -a "${file}" "${file}.${timestamp}.bak"
            echo "Backed up: ${file}.${timestamp}.bak"
        else
            echo "Skipped (not found): ${file}" >&2
        fi
    done
}

# Extract any archive format
extract() {
    local file="$1"
    [[ -z "${file}" ]] && { echo "Usage: extract <file>" >&2; return 1; }
    [[ -f "${file}" ]] || { echo "File not found: ${file}" >&2; return 1; }

    case "${file,,}" in
        *.tar.bz2|*.tbz2)   tar xjf "${file}" ;;
        *.tar.gz|*.tgz)     tar xzf "${file}" ;;
        *.tar.xz|*.txz)     tar xJf "${file}" ;;
        *.tar.zst)          tar --zstd -xf "${file}" ;;
        *.tar)              tar xf "${file}" ;;
        *.bz2)              bunzip2 "${file}" ;;
        *.gz)               gunzip "${file}" ;;
        *.xz)               unxz "${file}" ;;
        *.zst)              unzstd "${file}" ;;
        *.zip)              unzip "${file}" ;;
        *.rar)              unrar x "${file}" ;;
        *.7z)               7z x "${file}" ;;
        *.z)                uncompress "${file}" ;;
        *.deb)              ar x "${file}" ;;
        *.rpm)              rpm2cpio "${file}" | cpio -idmv ;;
        *)
            echo "Unknown archive format: ${file}" >&2
            return 1
            ;;
    esac
}

# Create archive (auto-detect format from name)
compress() {
    local archive="$1"
    shift
    [[ -z "${archive}" ]] && { echo "Usage: compress <archive> <files...>" >&2; return 1; }
    [[ $# -eq 0 ]] && { echo "No files specified" >&2; return 1; }

    case "${archive,,}" in
        *.tar.bz2|*.tbz2)   tar cjf "${archive}" "$@" ;;
        *.tar.gz|*.tgz)     tar czf "${archive}" "$@" ;;
        *.tar.xz|*.txz)     tar cJf "${archive}" "$@" ;;
        *.tar.zst)          tar --zstd -cf "${archive}" "$@" ;;
        *.tar)              tar cf "${archive}" "$@" ;;
        *.zip)              zip -r "${archive}" "$@" ;;
        *.7z)               7z a "${archive}" "$@" ;;
        *)
            echo "Unknown archive format: ${archive}" >&2
            return 1
            ;;
    esac
}

# =============================================================================
# Search Functions
# =============================================================================

# Find files by name
ff() {
    local pattern="$1"
    local dir="${2:-.}"

    if has fd; then
        fd "${pattern}" "${dir}"
    elif has find; then
        find "${dir}" -type f -iname "*${pattern}*" 2>/dev/null
    fi
}

# Find directories by name
ffd() {
    local pattern="$1"
    local dir="${2:-.}"

    if has fd; then
        fd -t d "${pattern}" "${dir}"
    elif has find; then
        find "${dir}" -type d -iname "*${pattern}*" 2>/dev/null
    fi
}

# Grep recursively (uses rg if available)
gr() {
    local pattern="$1"
    local dir="${2:-.}"

    if has rg; then
        rg "${pattern}" "${dir}"
    else
        grep -r --color=auto "${pattern}" "${dir}"
    fi
}

# =============================================================================
# System Information
# =============================================================================

# Disk usage summary, sorted
duh() {
    du -cksh "${1:-.}"/* 2>/dev/null | sort -rh | head -20
}

# What's listening on ports
listening() {
    if [[ "${JSH_OS}" == "macos" ]]; then
        lsof -iTCP -sTCP:LISTEN -P -n
    else
        ss -tuln 2>/dev/null || netstat -tuln
    fi
}

# Kill process on specific port
killport() {
    local port="$1"
    [[ -z "${port}" ]] && { echo "Usage: killport <port>" >&2; return 1; }

    local pid
    if [[ "${JSH_OS}" == "macos" ]]; then
        pid=$(lsof -ti ":${port}" 2>/dev/null)
    else
        pid=$(fuser "${port}/tcp" 2>/dev/null)
    fi

    if [[ -n "${pid}" ]]; then
        echo "Killing PID ${pid} on port ${port}"
        kill -9 "${pid}"
    else
        echo "No process found on port ${port}"
    fi
}

# Show external IP
whatsmyip() {
    curl -s https://api.ipify.org && echo
}

# =============================================================================
# Development Utilities
# =============================================================================

# Git stage specific lines in a file
git-stage-range() { git diff -U0 "$1" | awk -v s="$2" -v e="$3" '/^@@/{match($0,/\+([0-9]+)/,a);in_range=(a[1]>=s&&a[1]<=e)}in_range||/^(diff|index|---|\+\+\+)/' | git apply --cached; }
git-stage-pattern() { git diff -U0 "$1" | grep -B999 -A999 "$2" | git apply --cached --recount 2>/dev/null || git diff -U0 "$1" | git apply --cached; }

# Quick HTTP server
serve() {
    local port="${1:-8000}"
    local dir="${2:-.}"

    echo "Serving ${dir} on http://localhost:${port}"

    if has python3; then
        python3 -m http.server "${port}" --directory "${dir}"
    elif has python; then
        (cd "${dir}" && python -m SimpleHTTPServer "${port}")
    elif has ruby; then
        ruby -run -ehttpd "${dir}" -p"${port}"
    elif has php; then
        php -S "localhost:${port}" -t "${dir}"
    else
        echo "No suitable HTTP server found (python, ruby, php)" >&2
        return 1
    fi
}

# JSON pretty print
jsonpp() {
    if has jq; then
        jq '.' "$@"
    elif has python3; then
        python3 -m json.tool "$@"
    elif has python; then
        python -m json.tool "$@"
    else
        echo "No JSON parser available (jq, python)" >&2
        return 1
    fi
}

# Generate random password
genpass() {
    local length="${1:-32}"

    if has openssl; then
        openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "${length}"
        echo
    else
        LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${length}"
        echo
    fi
}

# URL encode
urlencode() {
    local string="$1"
    if has python3; then
        python3 -c "import urllib.parse; print(urllib.parse.quote('${string}'))"
    else
        echo "${string}" | sed 's/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g'
    fi
}

# URL decode
urldecode() {
    local string="$1"
    if has python3; then
        python3 -c "import urllib.parse; print(urllib.parse.unquote('${string}'))"
    else
        echo "${string}" | sed 's/%20/ /g; s/%21/!/g; s/%22/"/g; s/%23/#/g; s/%24/$/g; s/%26/\&/g'
    fi
}

# =============================================================================
# Git Utilities
# =============================================================================

# Commit with optional inline message
# Usage: git_ "message" or just git_ to open editor
git_() {
    if [[ $# -eq 0 ]]; then
        git commit
    else
        git commit -m "$*"
    fi
}

# Clone and cd into repo
gclone() {
    local repo="$1"
    [[ -z "${repo}" ]] && { echo "Usage: gclone <repo-url>" >&2; return 1; }

    local dir
    dir="$(basename "${repo}" .git)"

    git clone "${repo}" && cd "${dir}" || return 1
}

# Git user profile switcher
# Usage: gu personal | gu work
gu() {
    local profile="$1"

    case "${profile}" in
        personal|home|p)
            git config user.email "jay.ovalle@gmail.com"
            git config user.name "Jay Ovalle"
            ;;
        work|w)
            git config user.email "${GIT_WORK_EMAIL:-}"
            git config user.name "${GIT_WORK_NAME:-Jay Ovalle}"
            ;;
        "")
            echo "Current git user:"
            echo "  Name:  $(git config user.name)"
            echo "  Email: $(git config user.email)"
            ;;
        *)
            echo "Unknown profile: ${profile}" >&2
            echo "Available: personal, work" >&2
            return 1
            ;;
    esac
}

# Convert HTTPS git URL to SSH
http2ssh() {
    local url="$1"
    echo "${url}" | sed -e 's|https://github.com/|git@github.com:|' \
                        -e 's|https://gitlab.com/|git@gitlab.com:|' \
                        -e 's|https://bitbucket.org/|git@bitbucket.org:|'
}

# =============================================================================
# Fun / Misc
# =============================================================================

# Weather
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?F"
}

# Cheat sheet lookup
cheat() {
    local topic="$1"
    [[ -z "${topic}" ]] && { echo "Usage: cheat <topic>" >&2; return 1; }
    curl -s "cheat.sh/${topic}"
}

# Countdown timer
timer() {
    local seconds="${1:-60}"
    local msg="${2:-Timer done!}"

    echo "Timer: ${seconds} seconds"
    while [[ "${seconds}" -gt 0 ]]; do
        printf "\r%02d:%02d " $((seconds / 60)) $((seconds % 60))
        sleep 1
        ((seconds--))
    done
    printf "\r%s\n" "${msg}"

    # Notification
    if has osascript; then
        osascript -e "display notification \"${msg}\" with title \"Timer\""
    elif has notify-send; then
        notify-send "Timer" "${msg}"
    fi
}

# Simple calculator
calc() {
    if has bc; then
        echo "scale=4; $*" | bc -l
    elif has python3; then
        python3 -c "print($*)"
    else
        echo $(($*))
    fi
}

# Quick notes
note() {
    local notes_file="${HOME}/.notes"

    if [[ $# -eq 0 ]]; then
        [[ -f "${notes_file}" ]] && cat "${notes_file}"
    else
        echo "$(date '+%Y-%m-%d %H:%M') $*" >> "${notes_file}"
        echo "Note added."
    fi
}

# =============================================================================
# FZF Integration (if available)
# =============================================================================

if has fzf; then
    # Interactive cd
    fcd() {
        local dir
        dir=$(find "${1:-.}" -type d 2>/dev/null | fzf --preview 'ls -la {}')
        [[ -n "${dir}" ]] && cd "${dir}" || return 1
    }

    # Interactive file edit
    fe() {
        local file
        file=$(fzf --preview 'head -100 {}')
        [[ -n "${file}" ]] && "${EDITOR:-vim}" "${file}"
    }

    # Interactive history search
    fh() {
        local cmd
        cmd=$(history | fzf --tac | sed 's/^[ ]*[0-9]*[ ]*//')
        [[ -n "${cmd}" ]] && eval "${cmd}"
    }

    # Interactive process kill
    fkill() {
        local pid
        pid=$(ps aux | fzf --header-lines=1 | awk '{print $2}')
        [[ -n "${pid}" ]] && kill -9 "${pid}"
    }

    # Git branch checkout
    fco() {
        local branch
        branch=$(git branch -a | fzf | sed 's/^[ *]*//' | sed 's|remotes/origin/||')
        [[ -n "${branch}" ]] && git checkout "${branch}"
    }

    # Git log browser
    fgl() {
        git log --oneline --graph --color=always | \
            fzf --ansi --preview 'git show --color=always {1}' | \
            awk '{print $1}'
    }
fi

# =============================================================================
# Directory Bookmarks
# =============================================================================

# Bookmark current directory
mark() {
    local name="${1:-$(basename "${PWD}")}"
    local marks_file="${HOME}/.marks"

    # Remove existing bookmark with same name
    grep -v "^${name}:" "${marks_file}" > "${marks_file}.tmp" 2>/dev/null
    mv "${marks_file}.tmp" "${marks_file}" 2>/dev/null

    echo "${name}:${PWD}" >> "${marks_file}"
    echo "Marked: ${name} -> ${PWD}"
}

# Jump to bookmark
jump() {
    local name="$1"
    local marks_file="${HOME}/.marks"

    [[ -f "${marks_file}" ]] || { echo "No bookmarks set" >&2; return 1; }

    if [[ -z "${name}" ]]; then
        # List bookmarks
        cat "${marks_file}"
        return 0
    fi

    local path
    path=$(grep "^${name}:" "${marks_file}" | cut -d: -f2)

    if [[ -n "${path}" ]]; then
        cd "${path}" || return 1
    else
        echo "Bookmark not found: ${name}" >&2
        return 1
    fi
}

# Aliases for marks
alias j='jump'
alias m='mark'
alias marks='jump'

# =============================================================================
# Reload Function
# =============================================================================

reload_jsh() {
    # Unset load guards
    unset _JSH_CORE_LOADED _JSH_GIT_LOADED _JSH_PROMPT_LOADED
    unset _JSH_VIMODE_LOADED _JSH_ALIASES_LOADED _JSH_FUNCTIONS_LOADED
    unset _JSH_ZSH_LOADED _JSH_BASH_LOADED _JSH_INIT_LOADED

    # Re-source
    source "${JSH_DIR}/src/init.sh"
    echo "JSH reloaded"
}
