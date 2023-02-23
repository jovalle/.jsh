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
  docker
  firefox
  fzf
  go
  google-chrome
  helm
  istat-menus
  iterm2
  jq
  kind
  kubecolor/tap/kubecolor
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
  python3
  qemu
  raspberry-pi-imager
  signal
  spotify
  sublime-text
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

# Install pip
if ! [ -x "$(command -v pip)" ]
then
  curl -sS https://bootstrap.pypa.io/get-pip.py | python
fi

# Install jsh
./j.sh install
