#!/usr/bin/env zsh
# Comprehensive shell startup profiling with detailed breakdown
# Usage: JSH_PROFILE=1 zsh test/profile_comprehensive.zsh

# Enable profiling
export JSH_PROFILE=1

# Source the profiler library
source "${HOME}/.jsh/src/lib/profiler.sh"

# Initialize profiling
profile_init

# Profile: Essential exports and environment setup
profile_start "env_exports" "Environment exports and locale"
export CLICOLORS=1
export EDITOR=vim
export TERM=xterm-256color
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
profile_end "env_exports"

# Profile: Source .jshrc
profile_start "jshrc" "Sourcing .jshrc (aliases, functions, PATH)"
if [[ -f "${HOME}/.jsh/dotfiles/.jshrc" ]]; then
  source "${HOME}/.jsh/dotfiles/.jshrc"
fi
profile_end "jshrc"

# Profile: Zinit initialization
profile_start "zinit_init" "Zinit core initialization"
export ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -d "${ZINIT_HOME}" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"
fi
profile_end "zinit_init"

# Profile: Powerlevel10k instant prompt
profile_start "p10k_instant" "Powerlevel10k instant prompt"
if [[ -r "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
profile_end "p10k_instant"

# Profile each Zinit plugin individually
if [[ -n "${ZINIT_HOME}" ]] && [[ -d "${ZINIT_HOME}" ]]; then
  # Powerlevel10k theme
  profile_start "plugin_p10k" "Plugin: romkatv/powerlevel10k"
  zinit ice depth=1
  zinit light romkatv/powerlevel10k 2>/dev/null
  profile_end "plugin_p10k"

  # fzf-tab
  profile_start "plugin_fzf_tab" "Plugin: Aloxaf/fzf-tab"
  zinit light Aloxaf/fzf-tab 2>/dev/null
  profile_end "plugin_fzf_tab"

  # zsh-completions
  profile_start "plugin_completions" "Plugin: zsh-users/zsh-completions"
  zinit light zsh-users/zsh-completions 2>/dev/null
  profile_end "plugin_completions"

  # zsh-autosuggestions
  profile_start "plugin_autosuggestions" "Plugin: zsh-users/zsh-autosuggestions"
  zinit light zsh-users/zsh-autosuggestions 2>/dev/null
  profile_end "plugin_autosuggestions"

  # fast-syntax-highlighting
  profile_start "plugin_syntax" "Plugin: fast-syntax-highlighting"
  zinit light zdharma-continuum/fast-syntax-highlighting 2>/dev/null
  profile_end "plugin_syntax"

  # docker-aliases
  profile_start "plugin_docker" "Plugin: zsh-docker-aliases"
  zinit light akarzim/zsh-docker-aliases 2>/dev/null
  profile_end "plugin_docker"

  # you-should-use
  profile_start "plugin_ysu" "Plugin: zsh-you-should-use"
  zinit light MichaelAquilina/zsh-you-should-use 2>/dev/null
  profile_end "plugin_ysu"

  # forgit
  profile_start "plugin_forgit" "Plugin: wfxr/forgit"
  zinit light wfxr/forgit 2>/dev/null
  profile_end "plugin_forgit"

  # zsh-nvm
  profile_start "plugin_nvm" "Plugin: lukechilds/zsh-nvm"
  zinit light lukechilds/zsh-nvm 2>/dev/null
  profile_end "plugin_nvm"

  # zsh-async
  profile_start "plugin_async" "Plugin: mafredri/zsh-async"
  zinit light mafredri/zsh-async 2>/dev/null
  profile_end "plugin_async"

  # k (directory listings)
  profile_start "plugin_k" "Plugin: supercrabtree/k"
  zinit light supercrabtree/k 2>/dev/null
  profile_end "plugin_k"
fi

# Profile: Shell options and keybindings
profile_start "shell_opts" "Shell options and keybindings"
bindkey -v
setopt AUTO_CD COMPLETE_IN_WORD extended_history hist_find_no_dups
setopt INC_APPEND_HISTORY SHARE_HISTORY
profile_end "shell_opts"

# Profile: Completion system
profile_start "comp_system" "Completion system initialization"
autoload -Uz compinit
compinit -C
profile_end "comp_system"

# Profile: Individual completion sources
if declare -f _jsh_load_completions > /dev/null 2>&1; then
  profile_start "comp_direnv" "Completion: direnv"
  command -v direnv > /dev/null && eval "$(direnv hook zsh)" 2>/dev/null
  profile_end "comp_direnv"

  profile_start "comp_docker" "Completion: docker"
  command -v docker > /dev/null && eval "$(docker completion zsh)" 2>/dev/null
  profile_end "comp_docker"

  profile_start "comp_task" "Completion: task"
  command -v task > /dev/null && source <(task --completion zsh) 2>/dev/null
  profile_end "comp_task"

  profile_start "comp_zoxide" "Completion: zoxide"
  command -v zoxide > /dev/null && eval "$(zoxide init zsh)" 2>/dev/null
  profile_end "comp_zoxide"

  profile_start "comp_kubectl" "Completion: kubectl"
  command -v kubectl > /dev/null && source <(kubectl completion zsh) 2>/dev/null
  profile_end "comp_kubectl"

  profile_start "comp_fzf" "Completion: fzf"
  command -v fzf > /dev/null && source <(command fzf --zsh) 2>/dev/null
  profile_end "comp_fzf"

  profile_start "comp_atuin" "Completion: atuin"
  if command -v atuin > /dev/null; then
    export ATUIN_NOBIND="true"
    eval "$(atuin init zsh)" 2>/dev/null
  fi
  profile_end "comp_atuin"
fi

# Profile: p10k config
profile_start "p10k_config" "Powerlevel10k configuration"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
profile_end "p10k_config"

# Profile: grc colorization
profile_start "grc_setup" "grc colorization setup"
if command -v grc > /dev/null 2>&1; then
  # Simulate grc setup (simplified)
  true
fi
profile_end "grc_setup"

# Generate and display report
echo ""
profile_report

# Save profile for later comparison
profile_save "comprehensive_$(date '+%Y%m%d_%H%M%S')"
