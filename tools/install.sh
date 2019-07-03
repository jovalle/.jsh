#!/usr/bin/env bash

colors() {
  # Use colors, but only if connected to a terminal, and that terminal
  # supports them.
  if which tput >/dev/null 2>&1; then
      ncolors=$(tput colors)
  fi
  if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
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
}

links() {
  pushd "$(dirname $0)/../"
  DIR="$(pwd)"
  while read line; do
    if [[ ! $line == \#* ]] && [ -n "$line" ]; then
      if [[ $line == \@* ]] && [[ $PLATFORM != 'Darwin' ]]; then
        continue
      fi
      IFS=","
      set -- $line
      dest=$(echo $1 | sed 's/^ *//g' | sed 's/^[@$%]//g' | sed 's/ *$//g')
      dest=${dest/"~"/$HOME}
      src=$(echo $2 | sed 's/^ *//g' | sed 's/^[@$%]//g' | sed 's/ *$//g')
      src=$DIR/$src
      if [[ $line == \%* ]]; then
        if [ -f "$1" ] || [ -d "$1" ]; then
          continue
        fi
      fi
      echo "dest=$dest  src=$src"
      if [ -L $dest ]; then
        printf "${YELLOW}Found $dest as symlink. Removing.${NORMAL}\n"
        unlink $dest
      fi
      if [ -a $dest ]; then
        printf "${YELLOW}Found $dest.${NORMAL} ${GREEN}Backing up to $dest.pre-jsh${NORMAL}\n";
        mv $dest $dest.pre-jsh;
      fi
      #printf "${BLUE}Creating link of ${1} and adding it to ~/${NORMAL}\n"
      mkdir -p -- "$(dirname -- "$dest")"
      ln -sfF $src $dest
      echo "$src -> $dest"
    fi
  done < $JSH/tools/links
  popd
}
  
main() {
  if [ ! -n "$JSH" ]; then
    JSH=$HOME/.jsh
  fi

  # Only enable exit-on-error after the non-critical colorization stuff,
  # which may fail on systems lacking tput or terminfo
  set -e

  links
  
  printf '%s' "$YELLOW"                                                              
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
  printf "%s${NORMAL}\n" "Please look over the ~/.bash_local file to append temporary or workspace specific functionality!"
  exec bash; source $HOME/.bashrc
}

main
