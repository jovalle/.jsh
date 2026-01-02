# ==============================================================================
# Bash Configuration
# ==============================================================================
# Merged from top GitHub dotfiles and Bash best practices:
# - mathiasbynens/dotfiles (30k+ stars) - Comprehensive Bash setup
# - thoughtbot/dotfiles - Developer-focused settings
# - jessfraz/dotfiles - Container/DevOps focus
# - Bash-it framework - Community best practices
# - GNU Bash manual - Official documentation
#
# This file sources .jshrc for shell-agnostic settings (aliases, functions,
# environment variables) and adds Bash-specific configurations.
#
# Organization:
#   1. Early Exit - Non-interactive shell handling
#   2. Common Configuration - Source shared settings
#   3. Shell Options - Bash-specific shopt settings
#   4. History - Command history configuration
#   5. Completion - Tab completion setup
#   6. Prompt - PS1/PS2 configuration
#   7. Key Bindings - Readline/input bindings
#   8. Functions - Bash-specific functions
#   9. Hooks - PROMPT_COMMAND and trap handlers
#  10. Local Overrides - Machine-specific settings
# ==============================================================================

# ==============================================================================
# 1. EARLY EXIT
# ==============================================================================

# Exit early for non-interactive shells
# This prevents errors in scripts and improves performance
case $- in
  *i*) ;;      # Interactive - continue loading
  *) return ;; # Non-interactive - exit now
esac

# ==============================================================================
# 2. COMMON CONFIGURATION
# ==============================================================================

# Source shell-agnostic configuration from jsh
# Contains: exports, aliases, functions, path setup
if [[ -f "${HOME}/.jsh/dotfiles/.jshrc" ]]; then
  source "${HOME}/.jsh/dotfiles/.jshrc"
elif [[ -f "${HOME}/.jshrc" ]]; then
  source "${HOME}/.jshrc"
fi

# ==============================================================================
# 3. SHELL OPTIONS (shopt)
# ==============================================================================
# These are Bash-specific options that enhance usability

# ---- Directory Navigation ----

# cd into directory by just typing directory name
shopt -s autocd 2>/dev/null

# Correct minor spelling errors in cd
shopt -s cdspell 2>/dev/null

# Correct spelling errors during tab-completion for directories
shopt -s dirspell 2>/dev/null

# Allow ** for recursive directory globbing
# Example: ls **/*.txt finds all .txt files in subdirectories
shopt -s globstar 2>/dev/null

# ---- History ----

# Append to history instead of overwriting
# Critical for maintaining history across multiple terminals
shopt -s histappend

# Save multi-line commands as single history entry
# Makes complex commands easier to recall and edit
shopt -s cmdhist

# Re-edit a failed history substitution
shopt -s histreedit 2>/dev/null

# Verify substituted history before executing
shopt -s histverify 2>/dev/null

# ---- Globbing ----

# Include hidden files in glob patterns
# Example: * will also match .hidden files
shopt -s dotglob

# Enable extended pattern matching
# Supports: ?(pattern), *(pattern), +(pattern), @(pattern), !(pattern)
shopt -s extglob

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob 2>/dev/null

# Null glob: if no match, expand to empty string instead of literal
shopt -s nullglob 2>/dev/null

# ---- Job Control ----

# Notify about completed background jobs immediately
# Instead of waiting for next prompt
shopt -s notify 2>/dev/null

# Warn about stopped jobs on exit
shopt -s checkjobs 2>/dev/null

# ---- Shell Behavior ----

# Check window size after each command
# Updates LINES and COLUMNS values
shopt -s checkwinsize

# Allow aliases to be expanded
shopt -s expand_aliases

# Enable programmable completion
shopt -s progcomp 2>/dev/null

# Prefer hash table over PATH for command lookup
shopt -s checkhash 2>/dev/null

# Don't overwrite files with > (use >| to force)
# Prevents accidental file clobbering
set -o noclobber

# ---- Disabled Features ----

# Don't autocomplete on empty line (waste of time)
shopt -s no_empty_cmd_completion 2>/dev/null

# ==============================================================================
# 4. HISTORY CONFIGURATION
# ==============================================================================

# History file location (use jsh directory for organization)
export HISTFILE="${JSH:-${HOME}}/.bash_history"

# Number of commands to keep in memory during session
export HISTSIZE=50000

# Number of commands to keep in history file
export HISTFILESIZE=100000

# Don't store duplicate commands or commands starting with space
# erasedups: Remove all previous occurrences of command
export HISTCONTROL=ignoreboth:erasedups

# Ignore common commands that clutter history
# Add commands you use frequently but don't need to recall
export HISTIGNORE="&:ls:ll:la:l:cd:cd -:pwd:exit:date:* --help:history:clear:c"

# Add timestamp to history entries
# Format: YYYY-MM-DD HH:MM:SS
export HISTTIMEFORMAT="%F %T  "

# ==============================================================================
# 5. COMPLETION SYSTEM
# ==============================================================================

# Enable programmable completion features
# Sources system completions from common locations

# Linux (Debian/Ubuntu)
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
# Linux (RHEL/CentOS)
elif [[ -r /etc/bash_completion ]]; then
  source /etc/bash_completion
# macOS with Homebrew
elif [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
  source /opt/homebrew/etc/profile.d/bash_completion.sh
# macOS Intel with Homebrew
elif [[ -r /usr/local/etc/profile.d/bash_completion.sh ]]; then
  source /usr/local/etc/profile.d/bash_completion.sh
fi

# Load tool completions from jshrc helper (if defined)
if declare -f _jsh_load_completions >/dev/null 2>&1; then
  _jsh_load_completions bash
fi

# Make Tab completion case-insensitive
bind "set completion-ignore-case on" 2>/dev/null

# Show all completions immediately if ambiguous
bind "set show-all-if-ambiguous on" 2>/dev/null

# Treat hyphens and underscores as equivalent in completion
bind "set completion-map-case on" 2>/dev/null

# ==============================================================================
# 6. PROMPT CONFIGURATION
# ==============================================================================

# Use bash-powerline if available (provides git status, exit codes, etc.)
if [[ -f "${HOME}/.jsh/scripts/unix/bash-powerline.sh" ]]; then
  source "${HOME}/.jsh/scripts/unix/bash-powerline.sh"
else
  # Fallback to a simple but informative prompt
  # Colors (using tput for portability)
  # shellcheck disable=SC2034  # Colors defined for prompt/functions
  if command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    RESET=$(tput sgr0)
    BOLD=$(tput bold)
  else
    RED='\[\033[0;31m\]'
    GREEN='\[\033[0;32m\]'
    YELLOW='\[\033[0;33m\]'
    BLUE='\[\033[0;34m\]'
    CYAN='\[\033[0;36m\]'
    RESET='\[\033[0m\]'
    BOLD='\[\033[1m\]'
  fi

  # Function to get git branch
  __git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
  }

  # Function to get exit code indicator
  __exit_code() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
      echo -e "${RED}[${exit_code}]${RESET} "
    fi
  }

  # Build the prompt
  # Format: [exit_code] user@host:directory (branch) $
  PS1='\[$BOLD\]\[$YELLOW\]\u@\h\[$RESET\]:\[$BLUE\]\w\[$CYAN\]$(__git_branch)\[$RESET\] \$ '

  # Secondary prompt for multi-line commands
  PS2='> '

  # Selection prompt for select loops
  PS3='#? '

  # Debug prompt (shows before each command in debug mode)
  PS4='+ ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

# ==============================================================================
# 7. KEY BINDINGS
# ==============================================================================

# Use Vi mode for command-line editing
# (Already set in .inputrc, but ensure it's active)
set -o vi

# Enable history expansion with space
# Type !! and press space to expand to last command
bind Space:magic-space 2>/dev/null

# Ctrl+L clears screen (works in both vi modes)
bind -m vi-insert '"\C-l": clear-screen' 2>/dev/null
bind -m vi-command '"\C-l": clear-screen' 2>/dev/null

# Ctrl+A/E for beginning/end of line (emacs-style, convenient in vi-insert)
bind -m vi-insert '"\C-a": beginning-of-line' 2>/dev/null
bind -m vi-insert '"\C-e": end-of-line' 2>/dev/null

# Up/Down arrows search history based on current line
bind '"\e[A": history-search-backward' 2>/dev/null
bind '"\e[B": history-search-forward' 2>/dev/null

# ==============================================================================
# 8. BASH-SPECIFIC FUNCTIONS
# ==============================================================================

# Enhanced cd that shows directory contents
# Uncomment if you want to see directory contents after cd
# cd() {
#   builtin cd "$@" && ls -la
# }

# Create directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1" || return 1
}

# Up: Go up n directories
# Usage: up 3 (goes up 3 directories)
up() {
  local count="${1:-1}"
  local path=""
  for ((i = 0; i < count; i++)); do
    path="../${path}"
  done
  cd "${path}" || return 1
}

# Quick note taking
# Usage: note "Remember to fix bug #123"
note() {
  local notes_file="${HOME}/notes.txt"
  if [[ $# -eq 0 ]]; then
    [[ -f "${notes_file}" ]] && cat "${notes_file}"
  else
    echo "$(date '+%Y-%m-%d %H:%M'): $*" >>"${notes_file}"
  fi
}

# Calculator
# Usage: calc "2 + 2"
calc() {
  bc -l <<<"$*"
}

# Weather
# Usage: weather [city]
weather() {
  curl -s "wttr.in/${1:-}"
}

# Show PATH entries, one per line
showpath() {
  echo "${PATH}" | tr ':' '\n' | nl
}

# Extract command that handles many archive formats
# (This is also in .jshrc, but providing bash-optimized version)
ex() {
  if [[ -z "$1" ]]; then
    echo "Usage: ex <archive>"
    return 1
  fi

  if [[ ! -f "$1" ]]; then
    echo "'$1' is not a valid file"
    return 1
  fi

  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.tar.xz) tar xJf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar x "$1" ;;
    *.gz) gunzip "$1" ;;
    *.tar) tar xf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.zip) unzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.7z) 7z x "$1" ;;
    *)
      echo "'$1' cannot be extracted via ex()"
      return 1
      ;;
  esac
}

# Bash-specific debug: time shell startup
# Usage: timebash
timebash() {
  time bash -i -c exit
}

# Reload bash configuration
reload() {
  source "${HOME}/.bashrc"
  echo "Bash configuration reloaded"
}

# ==============================================================================
# 9. HOOKS AND PROMPT_COMMAND
# ==============================================================================

# PROMPT_COMMAND runs before each prompt display
# Use it to:
# - Save history after each command
# - Update terminal title
# - Log commands

# Function to save history immediately
__save_history() {
  history -a  # Append new history to file
}

# Function to set terminal title
__set_title() {
  echo -ne "\033]0;${USER}@${HOSTNAME%%.*}: ${PWD/#${HOME}/\~}\007"
}

# Build PROMPT_COMMAND (chain multiple functions)
PROMPT_COMMAND="__save_history; __set_title; ${PROMPT_COMMAND:-}"

# Trap DEBUG for timing commands (optional, can slow things down)
# Enable with: export BASH_TIMING=1
if [[ "${BASH_TIMING:-0}" == "1" ]]; then
  trap '__timer_start' DEBUG
  __timer_start() {
    __timer=${__timer:-${SECONDS}}
  }
  PROMPT_COMMAND="__timer_stop; ${PROMPT_COMMAND}"
  __timer_stop() {
    local elapsed=$((SECONDS - __timer))
    if [[ ${elapsed} -ge 5 ]]; then
      echo "Command took ${elapsed}s"
    fi
    unset __timer
  }
fi

# ==============================================================================
# 10. LOCAL OVERRIDES
# ==============================================================================

# Source machine-specific configuration
# Create this file for settings unique to this machine
if [[ -f "${HOME}/.bashrc.local" ]]; then
  source "${HOME}/.bashrc.local"
fi

# Source work-specific configuration
if [[ -f "${HOME}/.bashrc.work" ]]; then
  source "${HOME}/.bashrc.work"
fi
