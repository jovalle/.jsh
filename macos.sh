#!/bin/bash

test $(uname -s) = "Darwin"

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

taps=(
  homebrew/cask-fonts
)

casks=(
  appcleaner
  caffeine
  calibre
  cleanmymac
  discord
  docker
  edex-ui
  firefox
  gimp
  handbrake
  iterm2
  kitty
  mos
  plex
  slack
  spotify
  sublime-text
  vagrant
  virtualbox
  visual-studio-code
  vlc
  zoom
)

packages=(
  adns
  archey
  autojump
  bash
  bash-completion
  bdw-gc
  coreutils
  ctags
  ctop
  dep
  dive
  dnsmasq
  docbook
  docbook-xsl
  freetype
  font-meslo-lg-nerd-font
  fzf
  gdbm
  gettext
  ghostscript
  git
  glances
  glib
  gmp
  gnu-getopt
  gnu-sed
  gnupg
  gnutls
  go
  grc
  guile
  helm
  htop
  hugo
  hyperkit
  icu4c
  ilmbase
  imagemagick
  jpeg
  jq
  kind
  krew
  kubernetes-cli
  lazydocker
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
  libyaml
  little-cms2
  lua
  mas
  minikube
  namebench
  ncurses
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
  python@3.9
  readline
  reattach-to-user-namespace
  ripgrep
  ruby
  screenresolution
  shared-mime-info
  speedtest-cli
  sqlite
  stern
  tmux
  tree
  unbound
  utf8proc
  watch
  webp
  wget
  wifi-password
  x265
  xmlto
  xz
  youtube-dl
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

for pkg in ${packages[@]}
do
  brew install $pkg
done
