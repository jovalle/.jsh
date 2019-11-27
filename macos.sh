#!/usr/bin/env bash

# setup brew and brew cask
if ! type "brew" > /dev/null; then
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  brew tap homebrew/cask
fi

# update first
brew update
brew upgrade

# command-line programs to install with brew
declare -a brews=(
  "bash"
  "bash-completion"
  "coreutils"
  "ctags"
  "docker"
  "git"
  "gnu-sed"
  "gnupg"
  "go"
  "grc"
  "hugo"
  "jq"
  "kind"
  "kubernetes-cli"
  "kubernetes-helm"
  "minikube"
  "openssl"
  "reattach-to-user-namespace"
  "tmux"
  "vim"
  "watch"
  "wget"
)

# GUI programs to install with brew cask
declare -a casks=(
  "docker"
  "google-chrome"
  "iterm2"
  "java"
  "signal"
  "slack"
  "spotify"
  "vagrant"
  "visual-studio-code"
  "zoomus"
)

# run installation of command-line programs
for i in "${brews[@]}"
do
   brew install $i
done

# run installation of GUI programs
for i in "${casks[@]}"
do
   brew cask install $i
done

# install junegunn/vim-plugged
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
