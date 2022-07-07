#!/usr/bin/env bash

# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev zsh

# Install python3.10
if [[ ! -f /usr/bin/python3.10 && $(python3 --version) != "*3.10*" ]]; then
  pushd /tmp
  curl -LO https://www.python.org/ftp/python/3.10.5/Python-3.10.5.tgz
  tar -xf Python-3.10.*.tgz
  pushd Python-3.10.*/
  ./configure --enable-optimizations
  make -j $(nproc)
  sudo make altinstall
  popd
  rm -rf /tmp/Python-3.10.*/
  popd
fi

# Install pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# Set up python3 symlink
py3_path=$(which python3)
if [[ -L $py3_path ]]; then
  if [[ $(python3 --version | awk '{print $NF}') != "3.10*" ]]; then
    sudo unlink /usr/bin/python3
  fi
  sudo ln -s /usr/bin/python3.10 /usr/bin/python3
else
  echo "No symlink found at $py3_path. May need to manually configure to point to >=python3.10"
  exit 1
fi
[[ ! -s /usr/bin/python ]] && sudo ln -s /usr/bin/python3 /usr/bin/python

# Install jsh
./j.sh install
