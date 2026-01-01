#!/usr/bin/env zsh
# Profile .jshrc sections

typeset -F SECONDS=0

echo "=== .jshrc Section Timing ==="
echo

# Section 1: Essential Exports
local before=$SECONDS
export CLICOLORS=1
export EDITOR=vim
export VISUAL=vim
export TERM=xterm-256color
export SH=${SHELL##*/}
export GIT_BASE=${HOME}/projects
export WORK_DIR=${GIT_BASE}
export JSH=${JSH_ROOT:-${HOME}}/.jsh
export JSH_CUSTOM=${HOME}/.jsh_local
export GEM_HOME="${HOME}/.gem"
export DIRENV_LOG_FORMAT=
export GITSTATUS_RESPONSE_TIMEOUT=5
export DIRENV_WARN_TIMEOUT=30s
export PYTHONDONTWRITEBYTECODE=1
local after=$SECONDS
printf "%-40s %6.0f ms\n" "1. Essential exports" $(((after - before) * 1000))

# Section 2: Locale setup
before=$SECONDS
if locale -a 2> /dev/null | grep -qE "^en_US\.UTF-8$|^en_US\.utf8$"; then
  export LANG=en_US.UTF-8
elif locale -a 2> /dev/null | grep -qE "^C\.UTF-8$|^C\.utf8$"; then
  export LANG=C.UTF-8
else
  export LANG=C
fi
if locale -a 2> /dev/null | grep -qE "^en_US\.UTF-8$|^en_US\.utf8$"; then
  export LC_ALL=en_US.UTF-8
elif locale -a 2> /dev/null | grep -qE "^C\.UTF-8$|^C\.utf8$"; then
  export LC_ALL=C.UTF-8
else
  unset LC_ALL
fi
export XDG_CONFIG_HOME="${HOME}/.config"
export LESS="-RXE"
after=$SECONDS
printf "%-40s %6.0f ms\n" "   Locale detection (locale -a calls)" $(((after - before) * 1000))

# Section 3: Color functions
before=$SECONDS
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
after=$SECONDS
printf "%-40s %6.0f ms\n" "2. Color helper functions" $(((after - before) * 1000))

# Section 4: PATH setup
before=$SECONDS
local_paths=(
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

if [[ -n "${local_prefix}" ]]; then
  export PATH="${local_prefix}:${PATH}"
fi
unset local_paths local_prefix
after=$SECONDS
printf "%-40s %6.0f ms\n" "3. PATH setup" $(((after - before) * 1000))

# Section 5: Homebrew initialization
before=$SECONDS
_init_brew_env() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 0

  local brew_candidates=(
    "/home/linuxbrew/.linuxbrew/bin/brew"
    "/opt/homebrew/bin/brew"
    "/usr/local/bin/brew"
    "${HOME}/.linuxbrew/bin/brew"
  )

  for brew_bin in "${brew_candidates[@]}"; do
    if [[ -x "${brew_bin}" ]]; then
      eval "$("${brew_bin}" shellenv 2> /dev/null)"
      return 0
    fi
  done
  return 1
}
_init_brew_env
unset -f _init_brew_env
after=$SECONDS
printf "%-40s %6.0f ms\n" "4. Homebrew environment init (brew shellenv)" $(((after - before) * 1000))

echo
printf "%-40s %6.0f ms\n" "TOTAL (sections 1-4)" $(($SECONDS * 1000))
