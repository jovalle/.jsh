#!/bin/bash

test $(uname -s) = "Darwin"

# new version of brew requires sourcing
if [[ -f ${HOME}/.zprofile ]]
then
  if [[ $(grep /opt/homebrew/bin/brew ${HOME}/.zprofile) != 0 ]]
  then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/jay/.zprofile
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# rosetta needed for "legacy" apps
if [[ $(uname -m) == 'arm64' ]]
then
  sudo softwareupdate --install-rosetta
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

taps=(
  homebrew/cask-fonts
  johanhaleby/kubetail
)

casks=(
  docker
)

packages=(
  alt-tab
  ansible
  appcleaner
  archey
  autojump
  bash
  bash-completion
  bdw-gc
  caffeine
  calibre
  cdrtools
  coreutils
  ctags
  ctop
  dep
  discord
  dive
  dnsmasq
  docker
  ffmpeg
  firefox
  freetype
  fzf
  gcc
  gdbm
  gettext
  glances
  glib
  gmp
  gnu-getopt
  gnu-sed
  gnupg
  gnutls
  go
  google-chrome
  grc
  guile
  helm
  htop
  hugo
  hyperkit
  icu4c
  ilmbase
  imagemagick
  intel-power-gadget
  istat-menus
  iterm2
  jpeg
  jq
  kind
  krew
  kubernetes-cli
  kubetail
  lazydocker
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
  python@3.9
  qemu
  raspberry-pi-imager
  readline
  reattach-to-user-namespace
  rectangle
  ripgrep
  ruby
  screenresolution
  shared-mime-info
  signal
  slack
  speedtest-cli
  spotify
  spotify-tui
  sqlite
  stern
  sublime-text
  terraform
  tg-pro
  tinkertool
  tmux
  tor-browser
  tree
  unbound
  utf8proc
  vagrant
  virtualbox
  visual-studio-code
  vlc
  watch
  webp
  wget
  wifi-password
  x265
  xmlto
  xz
  youtube-dl
  zoom
  zsh-completions
)

for tap in ${taps[@]}
do
  brew tap $tap
done

for cask in ${casks[@]}
do
  brew install --cask $cask
done

for package in ${packages[@]}
do
  brew install $package
done
