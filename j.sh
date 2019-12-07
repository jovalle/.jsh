#!/usr/bin/env bash

MODE=none
TARGETS=(
  ".bin"
  ".gitconfig"
  ".inputrc"
  ".jshrc"
  ".sshrc"
  ".tmux.conf"
  ".vimrc"
  ".vim"
)

if [[ -z "$JSH" ]]
then
  JSH=$HOME/.jsh
fi

if which tput >/dev/null 2>&1
then
    ncolors=$(tput colors)
fi
if [[ -t 1 ]] && [[ -n "$ncolors" ]] && [[ "$ncolors" -ge 8 ]]
then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NORMAL=""
fi

usage() {
  echo "Usage:"
  echo "  j.sh [flags]"
  echo "Options:"
  echo "  install    update bash, vim, tmux configs for jsh"
  echo "  uninstall  remove all changes for jsh"
}

install() {
  for t in ${TARGETS[@]}; do
    if [[ ! -f $HOME/$t && ! -d $HOME/$t ]]; then
      echo "${BLUE}$HOME/$t -> $JSH/$t${NORMAL}"
      ln -s $JSH/$t $HOME/$t
    else
      if [[ -L $HOME/$t ]]; then
        unlink $HOME/$t
        ln -s $JSH/$t $HOME/$t
      else
        echo "${RED}File found for $HOME/$t. Please backup and remove before executing j.sh${NORMAL}"
        exit
      fi
    fi
  done

  printf '%s'   "$YELLOW"
  printf '%s\n' '          _____                _____       __     __        '
  printf '%s\n' '         |\    \_         _____\    \     /  \   /  \       '
  printf '%s\n' '         \ \     \       /    / \    |   /   /| |\   \      '
  printf '%s\n' '          \|      |     |    |  /___/|  /   //   \\   \     '
  printf '%s\n' '           |      |  ____\    \ |   || /    \_____/    \    '
  printf '%s\n' '   ______  |      | /    /\    \|___|//    /\_____/\    \   '
  printf '%s\n' '  /     / /      /||    |/ \    \    /    //\_____/\\    \  '
  printf '%s\n' ' |      |/______/ ||\____\ /____/|  /____/ |       | \____\ '
  printf '%s\n' ' |\_____\      | / | |   ||    | |  |    | |       | |    | '
  printf '%s\n' ' | |     |_____|/   \|___||____|/   |____|/         \|____| '
  printf '%s\n' '  \|_____|                                                   ....is now installed!'
  printf '%s\n' 'jsh is shell agnostic. Update your shell profile (i.e. .bash_profile) to include sourcing .jshrc and reload your shell'
  printf '%s\n' 'Sample .bash_profile:'
  printf '%s\n' '[[ -f ~/.jshrc ]] && . ~/.jshrc'
  printf '%s'   "$NORMAL"
}

uninstall() {
  read -r -p "Are you sure you want to remove jsh? [y/N] " confirmation
  if [[ "$confirmation" != y ]] && [[ "$confirmation" != Y ]]
  then
    echo "${ORANGE}Uninstall cancelled${NORMAL}"
    exit
  else
    for t in ${TARGETS[@]}; do
      unlink $HOME/$t
      if [[ $? == 0 ]]; then
        echo "${GREEN}Symlink at $HOME/$t removed.${NORMAL}"
      else
        echo "${YELLOW}Symlink at $HOME/$t not found. Ignoring.${NORMAL}"
      fi
    done
  fi
  printf '%s\n' 'Uninstalled. Revert your shell profile (i.e. .bash_profile) and reload your shell.'
}

if [[ $# == 1 ]]
then
  if [[ $1 == 'install' ]]
  then
    MODE=install
    install
  elif [[ $1 == 'uninstall' ]]
  then
    MODE=uninstall
    uninstall
  else
    usage
  fi
else
  usage
fi
