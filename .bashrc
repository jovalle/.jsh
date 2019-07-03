#!/bin/bash

export JSH="${HOME}/.jsh"

THEME="font"

completions=(
  git
  kubectl
  ssh
  system
  tmux
)

aliases=(
  chmod
  general
  ls
  misc
)

plugins=(
  bashmarks
  git
)

source $JSH/jay.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

# Universal env vars
export LANG=en_US.UTF-8
export SSH_KEY_PATH="${HOME}/.ssh/jay"

# Universal aliases
alias l='ls -la'