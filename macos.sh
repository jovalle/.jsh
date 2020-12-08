#!/bin/zsh

set -e

test $(uname -s) = "Darwin"

sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
sudo xcodebuild -license accept

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install --cask \
  edex-ui \
  kitty \
  vagrant \
  virtualbox

brew install \
  adns \
  archey \
  bash \
  bash-completion \
  bdw-gc \
  coreutils \
  ctags \
  ctop \
  dep \
  dive \
  dnsmasq \
  docbook \
  docbook-xsl \
  docker \
  freetype \
  fzf \
  gdbm \
  gettext \
  ghostscript \
  git \
  glances \
  glib \
  gmp \
  gnu-getopt \
  gnu-sed \
  gnupg \
  gnutls \
  go \
  grc \
  guile \
  helm \
  htop \
  hugo \
  hyperkit \
  icu4c \
  ilmbase \
  imagemagick \
  jpeg \
  jq \
  kind \
  krew \
  kubernetes-cli \
  lazydocker \
  libassuan \
  libde265 \
  libev \
  libevent \
  libffi \
  libgcrypt \
  libgpg-error \
  libheif \
  libidn2 \
  libksba \
  liblqr \
  libomp \
  libpng \
  libtasn1 \
  libtiff \
  libtool \
  libunistring \
  libusb \
  libyaml \
  little-cms2 \
  lua \
  mas \
  minikube \
  namebench \
  ncurses \
  nettle \
  nmap \
  node \
  npth \
  oniguruma \
  openexr \
  openjpeg \
  openssl@1.1 \
  p11-kit \
  pcre \
  pcre2 \
  perl \
  pinentry \
  pkg-config \
  popeye \
  python@3.8 \
  python@3.9 \
  readline \
  reattach-to-user-namespace \
  ripgrep \
  ruby \
  screenresolution \
  shared-mime-info \
  speedtest-cli \
  sqlite \
  stern \
  tmux \
  tree \
  unbound \
  unrar \
  utf8proc \
  watch \
  webp \
  wget \
  wifi-password \
  x265 \
  xmlto \
  xz \
  youtube-dl \
  zsh-completions
