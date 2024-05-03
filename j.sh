#!/usr/bin/env bash

#
# j.sh - Shell augmentation tool
# Released under the MIT License.
#
# https://github.com/jovalle/.jsh
#

[[ -z $JSH ]] && JSH=$HOME/.jsh

VERSION="$(cat $JSH/VERSION)"
NO_BACKUP=0
TARGETS=(
  ".bin"
  ".gitconfig"
  ".inputrc"
  ".jshrc"
  ".kube"
  ".oh-my-zsh"
  ".p10k.zsh"
  ".sops"
  ".ssh"
  ".sshrc"
  ".talos"
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
  uninstall            uninstall jsh symlinks and restore from backups
Options:
  -v, --version        output program version
  -h, --help           output help information
  -n, --no-backup      skip backup creation/restoration
EOF
}

# Output color-coded message
abort() { echo ; echo "${red}$@${reset}" 1>&2; exit 1 ; }
error() { echo -e $(tput setaf 1)$@$(tput sgr0); return 1 ; }
warn() { echo -e $(tput setaf 3)$@$(tput sgr0) ; }
success() { echo -e $(tput setaf 2)$@$(tput sgr0) ; }
info() { echo -e $(tput setaf 4)$@$(tput sgr0) ; }

# Exit if jsh dir not found
[[ -d $JSH ]] || abort "jsh not found at $JSH. Cannot continue."

# Output version
version() { echo $VERSION; }

# Install targets
install() {
  set -e
  git submodule init
  git submodule update

  # Symlink sourceable scripts
  for t in ${TARGETS[@]}; do
    TS=$(date '+%F')
    if [[ -f $JSH/$t || -d $JSH/$t ]]; then
      if [[ ! -f $HOME/$t && ! -d $HOME/$t ]]; then
        info "$HOME/$t -> $JSH/$t"
        ln -s $JSH/$t $HOME/$t
      else
        if [[ -L $HOME/$t ]]; then
          unlink $HOME/$t
          ln -s $JSH/$t $HOME/$t
        elif [[ -f $HOME/$t || -d $HOME/$t ]]; then
          mv $HOME/$t $HOME/${t}-${TS}
          success "Backing up $HOME/$t to $HOME/${t}-${TS}"
          ln -s $JSH/$t $HOME/$t
        else
          warn "File found for $HOME/$t. Please backup and remove before executing j.sh"
          exit
        fi
      fi
    else
      warn "$JSH/$t not found. Skipping symlink"
    fi
  done

  # Install autojump (shortcuts to recent dirs)
  if ! [ -x "$(command -v autojump)" ]; then
    echo "Install autojump..."
    pushd ${JSH}/custom/plugins/autojump && ./install.py && popd || popd
  fi

  # Install fzf (fuzzy search)
  if ! [ -x "$(command -v fzf)" ]; then
    echo "Installing fzf..."
    .fzf/install --key-bindings --completion --no-update-rc
  fi

  if [[ $SHELL != "/bin/zsh" ]]; then
    echo "Changing shell to zsh..."
    sudo chsh -s /bin/zsh
  fi

  set +e

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
  printf '%s\n' '  \|_____|                                                   ....is installed!'
  printf '%s\n' 'You may reload your terminal now.'
  printf '%s'   "$(tput sgr0)"
}

# Revert targets
uninstall() {
  read -r -p "Are you sure you want to uninstall jsh? [y/N] " confirmation
  if [[ "$confirmation" != y ]] && [[ "$confirmation" != Y ]]; then
    abort "Removal process cancelled by user"
  else
    for t in ${TARGETS[@]}; do

      # check for and remove files
      if [[ -L $HOME/$t ]]; then
        unlink $HOME/$t && \
          success "Symlink at $HOME/$t removed." || \
          warn "Symlink at $HOME/$t not found. Ignoring"
      fi

      # Delete instead of restoring from backup
      if [[ $NO_BACKUP == 1 ]]; then
        warn "Backup restoration skipped by user"
        if [[ -f $HOME/$t || -d $HOME/$t ]]; then
          rm -rf $HOME/$t && success "Deleted $HOME/$t"
        fi
      else
        # get backup file/dir with latest timestamp
        LATEST_BACKUP=$(ls -d ${HOME}/${t}-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] 2>/dev/null | tail -n 1)
        if [[ -f $LATEST_BACKUP || -d $LATEST_BACKUP ]]; then
          if [[ -f $HOME/$t || -d $HOME/$t ]]; then
            warn "Non-symlink found at $HOME/$t. Cannot overwrite with backup from $LATEST_BACKUP. Moving on."
          else
            mv $LATEST_BACKUP $HOME/$t && success "Backup at $HOME/$t restored from $LATEST_BACKUP"
          fi
        fi
      fi

    done

    # Uninstall autojump
    echo "Uninstalling autojump..."
    pushd ${JSH}/custom/plugins/autojump && ./uninstall.py && popd || popd

    # Uninstall fzf
    echo "Uninstalling fzf..."
    yes | .fzf/uninstall

    success "jsh uninstalled"
  fi
}

# Parse argv
while test $# -ne 0; do
  arg=$1
  shift
  case $arg in
    -h|--help) usage; exit 0 ;;
    -v|--version) version; exit 0 ;;
    -n|--no-backup) NO_BACKUP=1; ;;
    install) INSTALL=1; ;;
    uninstall) UNINSTALL=1; ;;
    *) usage; exit 1 ;;
  esac
done

if [[ "$INSTALL" -eq 1 ]]; then
  install
  exit $?
elif [[ "$UNINSTALL" -eq 1 ]]; then
  uninstall
  exit $?
fi

usage
