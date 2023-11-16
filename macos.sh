#!/usr/bin/env bash

test $(uname -s) = "Darwin"

[[ ! -f $HOME/.zprofile ]] && touch $HOME/.zprofile

# install brew if missing
if ! [ -x "$(command -v brew)" ]
then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# new version of brew requires sourcing
if ! grep -q /opt/homebrew/bin/brew $HOME/.zprofile
then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/jay/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# rosetta needed for "legacy" apps
if [[ $(uname -m) == 'arm64' && ! -d /usr/libexec/rosetta ]]
then
 sudo softwareupdate --install-rosetta
fi

if [[ ! -f $HOME/.ssh/id_rsa ]]
then
  ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa
fi

# install meslo NF font
if [[ ! -f "$HOME/Library/Fonts/Meslo LG S Regular Nerd Font Complete.ttf" ]]
then
  echo "Installing Meslo font..."
  curl -Lo /tmp/Meslo.zip $(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep "browser_download_url.*Meslo.zip" | cut -d : -f 2,3 | tr -d \")
  unzip /tmp/Meslo.zip -d $HOME/Library/Fonts
  rm -f $HOME/Library/Fonts/*Windows*
  rm -f $HOME/Library/Fonts/LICENSE.txt
  rm -f $HOME/Library/Fonts/readme.md
  rm -f /tmp/Meslo.zip
fi

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
  corepack
  discord
  docker
  firefox
  fzf
  glances
  go
  google-chrome
  helm
  istat-menus
  iterm2
  jq
  kind
  k3sup
  krew
  kubecolor/tap/kubecolor
  kubectx
  kubernetes-cli
  kubetail
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
  ncurses
  neofetch
  netcat
  nettle
  nmap
  node
  npm
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
  pnpm
  poetry
  python3
  qemu
  raspberry-pi-imager
  signal
  slack
  spotify
  sublime-text
  terraform
  tg-pro
  tmux
  vagrant
  visual-studio-code
  vlc
  watch
  zoom
  zsh-completions
)

s_packages=(
  hyperkit
  virtualbox
)

installed=$(brew list -1)

for tap in ${taps[@]}
do
  brew tap $tap
done

for cask in ${casks[@]}
do
  if [[ ${installed[@]} != *$cask* ]]
  then
    brew install --cask $cask
  fi
done

for package in ${packages[@]}
do
  if [[ ${installed[@]} != *$package* ]]
  then
    brew install $package
  fi
done

if [[ $(uname -m) == 'x86_64' ]]
then
  for s_package in ${s_packages[@]}
  do
    if [[ ${installed[@]} != *$s_package* ]]
    then
      brew install $s_package
    fi
  done
fi

# Prioritize local binaries
export PATH="/usr/local/bin:$PATH"

# Override macOS python with brew's python
targets=(
 /usr/local/bin/python
 /usr/local/bin/python3
)
if [[ -x $(brew --prefix)/opt/python3/bin/python3 && ! -L /usr/local/bin/python ]]
then
  for target in ${targets[@]}
  do
    [[ -L $target ]] && sudo unlink $target
    sudo ln -s $(brew --prefix)/opt/python3/bin/python3 $target
  done
fi

config_base=$HOME/.jsh/custom/configs

import_config() {
  if [[ $# != 2 ]]
  then
    echo "Usage: import_config <source> <destination>"
    return 1
  fi

  config_src=${config_base}/$1
  config_dest=$2

  if [[ -f "$config_src" ]]
  then
    [[ -f $config_dest ]] && rm -f "$config_dest" && echo "Deleted '$config_dest'"
    [[ -L $config_dest ]] && unlink "$config_dest" && echo "Unlinked '$config_dest'"
    ln -s "$config_src" "$config_dest" && echo "Linked '$config_dest' -> '$config_src'"
  else
    echo "Failed to find config at '$config_src'"
    return 2
  fi
}

# Configure iTerm2
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "${config_base}"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

# Import VSCode settings
import_config "vscode.settings.json" "$HOME/Library/Application Support/Code/User/settings.json"

# Install pip
if ! [ -x "$(command -v pip)" ]
then
  curl -sS https://bootstrap.pypa.io/get-pip.py | python
fi

# Install jsh
./j.sh install
