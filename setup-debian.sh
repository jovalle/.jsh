#!/usr/bin/env bash

set +e

# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev zsh python3

# Install Meslo NF
sudo apt install fontconfig
curl -Lo /tmp/Meslo.zip $(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep "browser_download_url.*Meslo.zip" | cut -d : -f 2,3 | tr -d \")
mkdir -p $HOME/.local/share/fonts
unzip /tmp/Meslo.zip -d $HOME/.local/share/fonts
rm $HOME/.local/share/fonts/*Windows*
rm /tmp/Meslo.zip
fc-cache -fv

# Install pip
python3 --version
curl -sS https://bootstrap.pypa.io/get-pip.py | python3
if [[ ! -f $(which python) ]]; then
  echo "Creating symlink at /usr/bin/python..."
  sudo ln -s $(which python3) /usr/bin/python
fi

# Install jsh
./j.sh install

set -e
