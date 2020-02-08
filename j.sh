#!/usr/bin/env bash

#
# j.sh - Shell augmentation tool
# Released under the MIT License.
#
# https://github.com/jovalle/.jsh
#

[[ -z "$JSH" ]] && JSH=$HOME/.jsh

VERSION="0.1.8"
NO_BACKUP=0
TARGETS=(
  ".bin"
  ".gitconfig"
  ".inputrc"
  ".jshrc"
  ".oh-my-zsh"
  ".p10k.zsh"
  ".sshrc"
  ".tmux.conf"
  ".vim"
  ".vimrc"
  ".zshrc"
)

# Output usage information
usage() {
  cat <<-EOF
  Usage: j.sh command [options]
  Commands:
    install              replace shell, vim, tmux configs with jsh symlinks
    remove               remove jsh symlinks and restore from backups
  Options:
    -V, --version        output program version
    -h, --help           output help information
    -np, --no-backup     skip backup creation/restoration
EOF
}

# Output color-coded message
abort() { echo ; echo "${red}$@${reset}" 1>&2; exit 1 ; }
error() { echo -e $(tput setaf 1)$@$(tput sgr0); return 1 ; }
warn() { echo -e $(tput setaf 3)$@$(tput sgr0) ; }
success() { echo -e $(tput setaf 2)$@$(tput sgr0) ; }
info() { echo -e $(tput setaf 4)$@$(tput sgr0) ; }

# Output version
version() { echo $VERSION ; }

# Install targets
install() {
  for t in ${TARGETS[@]}; do
    TS=$(date '+%F')
    if [[ ! -f $HOME/$t && ! -d $HOME/$t ]]; then
      info "$HOME/$t -> $JSH/$t"
      ln -s $JSH/$t $HOME/$t
    else
      if [[ -L $HOME/$t ]]; then
        unlink $HOME/$t
        ln -s $JSH/$t $HOME/$t
      elif [[ -f $HOME/$t || -d $HOME/$t ]]; then
        mv $HOME/$t $HOME/${t}-${TS}
        success Backing up $HOME/$t to $HOME/${t}-${TS}
        ln -s $JSH/$t $HOME/$t
      else
        warn File found for $HOME/$t. Please backup and remove before executing j.sh
        exit
      fi
    fi
  done

  printf '%s'   "$(tput setaf 6)"
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
  printf '%s'   "$(tput sgr0)"
}

# Revert targets
remove() {
  read -r -p "Are you sure you want to remove jsh? [y/N] " confirmation
  if [[ "$confirmation" != y ]] && [[ "$confirmation" != Y ]]; then
    abort Removal process cancelled by user
  else
    for t in ${TARGETS[@]}; do

      # check for and remove files
      if [[ -L $HOME/$t ]]; then
        unlink $HOME/$t && \
          success Symlink at $HOME/$t removed. || \
          warn Symlink at $HOME/$t not found. Ignoring
      fi

      # Delete instead of restoring from backup
      if [[ $NO_BACKUP == 1 ]]; then
        warn Backup restoration skipped by user
        if [[ -f $HOME/$t || -d $HOME/$t ]]; then
          rm -rf $HOME/$t && success Deleted $HOME/$t
        fi
      else
        # get backup file/dir with latest timestamp
        LATEST_BACKUP=$(ls -d ${HOME}/${t}-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] 2>/dev/null | tail -n 1)
        if [[ -f $LATEST_BACKUP || -d $LATEST_BACKUP ]]; then
          if [[ -f $HOME/$t || -d $HOME/$t ]]; then
            warn Non-symlink found at $HOME/$t. Cannot overwrite with backup from $LATEST_BACKUP. Moving on.
          else
            mv $LATEST_BACKUP $HOME/$t && success Backup at $HOME/$t restored from $LATEST_BACKUP
          fi
        fi
      fi

    done

    success "jsh removed"
  fi
}

# Parse argv
while test $# -ne 0; do
  arg=$1
  shift
  case $arg in
    -h|--help) usage; exit ;;
    -v|--version) version; exit ;;
    -nb|--no-backup) NO_BACKUP=1; ;;
    install) install; ;;
    remove) remove; ;;
    *) usage; exit ;;
  esac
done
