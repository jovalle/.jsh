  #!/usr/bin/env bash
  
main() {
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

  # Only enable exit-on-error after the non-critical colorization stuff,
  # which may fail on systems lacking tput or terminfo
  set -e

  if [ ! -n "$JSH" ]; then
    JSH=$HOME/.jsh
  fi
  printf "${BLUE}Looking for an existing bash config...${NORMAL}\n"
  if [ -f $HOME/.bashrc ] || [ -h $HOME/.bashrc ]; then
    printf "${YELLOW}Found ~/.bashrc.${NORMAL} ${GREEN}Backing up to ~/.bashrc.pre-jsh${NORMAL}\n";
    mv $HOME/.bashrc $HOME/.bashrc.pre-jsh;
  fi
  
  printf "${BLUE}Using the Oh My Bash template file and adding it to ~/.bashrc${NORMAL}\n"
  cp $JSH/.bashrc $HOME/.bashrc
  sed "/^export JSH=/ c\\
export JSH=$JSH
  " $HOME/.bashrc > $HOME/.bashrc-jshtemp
  mv -f $HOME/.bashrc-jshtemp $HOME/.bashrc

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
printf '%s\n' '  \|_____|                                                   .... is now installed!'
  printf "%s\n" "Please look over the ~/.bashrc file to select plugins, themes, and options"
  exec bash; source $HOME/.bashrc
}


main