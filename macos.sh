#!/usr/bin/env bash

#test $(uname -s) = "Darwin"
#
## new version of brew requires sourcing
#if [[ -f ${HOME}/.zprofile ]]
#then
#  if [[ $(grep /opt/homebrew/bin/brew ${HOME}/.zprofile) != 0 ]]
#  then
#    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/jay/.zprofile
#  fi
#  eval "$(/opt/homebrew/bin/brew shellenv)"
#fi
#
## rosetta needed for "legacy" apps
#if [[ $(uname -m) == 'arm64' ]]
#then
#  sudo softwareupdate --install-rosetta
#fi
#
#/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

taps=(
  homebrew/cask-fonts
  johanhaleby/kubetail
)

casks=(
  docker
)

packages=(
  ansible
  caffeine
  docker
  firefox
  fzf
  go
  google-chrome
  helm
  hyperkit
  istat-menus
  iterm2
  jq
  kind
  kubectx
  kubernetes-cli
  lens
  libassuan
  libde265
  libev
  libevent
  libffi
  libgcrypt
  libgpg-error
  libheif
  libidn2
  libksba
  liblqr
  libomp
  libpng
  libtasn1
  libtiff
  libtool
  libunistring
  libusb
  libvirt
  libyaml
  little-cms2
  lua
  mas
  minikube
  mos
  namebench
  ncurses
  neofetch
  netcat
  nettle
  nmap
  node
  npth
  oniguruma
  openexr
  openjpeg
  openssl@1.1
  p11-kit
  pcre
  pcre2
  perl
  pinentry
  pkg-config
  plex
  podman
  poetry
  python@3.10
  qemu
  raspberry-pi-imager
  spotify
  sublime-text
  tg-pro
  tmux
  vagrant
  virtualbox
  visual-studio-code
  vlc
  watch
  zoom
  zsh-completions
)

for tap in ${taps[@]}; do
  brew tap $tap
done

for cask in ${casks[@]}; do
  brew install --cask $cask
done

for package in ${packages[@]}; do
  brew install $package
done

# Prioritize local binaries
export PATH="/usr/local/bin:$PATH"

# Override macOS python with brew's python3.10
targets=(
  /usr/local/bin/python
  /usr/local/bin/python3
  /usr/local/bin/python3.10
)
if [[ -f $(brew --prefix)/opt/python@3.10/bin/python3 ]]; then
  for target in ${targets[@]}; do
    [[ -L $target ]] && unlink $target
    ln -s $(brew --prefix)/opt/python@3.10/bin/python3 $target
  done
fi

# Install pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python

# install spf13-vim
curl http://j.mp/spf13-vim3 -L -o - | sh

# Install jsh
./j.sh install

