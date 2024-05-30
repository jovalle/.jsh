#!/usr/bin/env bash

set -e

test $(uname -s) = "Darwin"

# variables
config_base=$HOME/.jsh/custom/configs
packages=(
  age
  alfred
  ansible
  ansible-lint
  awscli
  bat
  btop
  caffeine
  cilium-cli
  cloudflared
  corepack
  coreutils
  cryptography
  direnv
  discord
  exiftool
  ffmpeg
  firefox
  fluxcd/tap/flux
  fzf
  git-delta
  glances
  go
  go-task
  google-chrome
  govc
  grep
  helm
  helmfile
  ipmitool
  istat-menus
  ipmitool
  iterm2
  johanhaleby/kubetail/kubetail
  jq
  k3sup
  kind
  krew
  kubecm
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
  llvm
  lua
  mailsy
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
  nvim
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
  python-dateutil
  python-distlib
  python-filelock
  python-jinja
  python-lxml
  python-platformdirs
  python-pyparsing
  python-pytz
  python3
  pyyaml
  qemu
  raspberry-pi-imager
  rsync
  siderolabs/tap/talosctl
  signal
  slack
  sops
  sublime-text
  tailscale
  talosctl
  telegram
  terraform
  tg-pro
  thefuck
  tldr
  tmux
  vagrant
  visual-studio-code
  virtualenv
  watch
  wireshark
  zoom
  zsh-completions
)
casks=(
  docker
  mpv
  syncthing
)
links=(
  ansible
)

# If not apple silicon, add these
if [[ $(uname -m) == 'x86_64' ]]; then
  packages+=(
    hyperkit
    virtualbox
  )
fi

# Install brew if missing
[[ ! -f $HOME/.zprofile ]] && touch $HOME/.zprofile
if ! [ -x "$(command -v brew)" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# New version of brew requires sourcing
if ! grep -q /opt/homebrew/bin/brew $HOME/.zprofile; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/jay/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Rosetta needed for "legacy" apps
if [[ $(uname -m) == 'arm64' && ! -d /usr/libexec/rosetta ]]; then
 sudo softwareupdate --install-rosetta
fi

set +e

# Uninstall any packages not specified
for package in $(brew leaves); do
  if [[ ${packages[@]} != *${package}* ]]; then
    brew uninstall $package
  fi
done

# Install/upgrade packages
for package in ${packages[@]}; do
  brew install $package
done

# Install/upgrade packages of cask format
for cask in ${casks[@]}; do
  brew install $cask --cask
done

# Link packages to replace local, unmanaged copies
for link in ${links[@]}; do
  brew link $link
done

set -e

if [[ ! -L $HOME/iCloud ]]; then
  ln -s $HOME/Library/Mobile\ Documents/com~apple~CloudDocs $HOME/iCloud
fi

if [[ ! -f $HOME/.ssh/id_rsa ]]; then
  ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa
fi

# Install meslo NF font
if [[ ! -f "$HOME/Library/Fonts/Meslo LG S Regular Nerd Font Complete.ttf" ]]; then
  echo "Installing Meslo font..."
  curl -Lo /tmp/Meslo.zip $(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep "browser_download_url.*Meslo.zip" | cut -d : -f 2,3 | tr -d \")
  unzip /tmp/Meslo.zip -d $HOME/Library/Fonts
  rm -f $HOME/Library/Fonts/*Windows*
  rm -f $HOME/Library/Fonts/LICENSE.txt
  rm -f $HOME/Library/Fonts/readme.md
  rm -f /tmp/Meslo.zip
fi

# Prioritize local binaries
export PATH="/usr/local/bin:$PATH"

# Override macOS python with brew's python
targets=(
 /usr/local/bin/python
 /usr/local/bin/python3
)
if [[ -x $(brew --prefix)/opt/python3/bin/python3 && ! -L /usr/local/bin/python ]]; then
  for target in ${targets[@]}; do
    [[ -L $target ]] && sudo unlink $target
    sudo ln -s $(brew --prefix)/opt/python3/bin/python3 $target
  done
fi

# Override macOS grep with GNU grep
ln -sf /opt/homebrew/bin/ggrep /opt/homebrew/bin/grep

import_config() {
  if [[ $# != 2 ]]; then
    echo "Usage: import_config <source> <destination>"
    return 1
  fi

  config_src=${config_base}/$1
  config_dest=$2

  if [[ -f "$config_src" ]]; then
    if [[ "$config_src" -ef "$config_dest" ]]; then
      echo "$config_src already points to $config_dest"
      return 0
    fi
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

# Install jsh
./j.sh install
