#!/usr/bin/env bash

# Install prerequisites
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev zsh

# Install python3.10
if [[ ! -f /usr/local/bin/python3.10 && $(python3 --version) != "*3.10*" ]]; then
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
common_paths=(
  /usr/bin/python
  /usr/bin/python3
  /usr/local/bin/python
  /usr/local/bin/python3
)
for path in ${common_paths[@]}; do
  sudo unlink $path &>/dev/null
  if [[ $path == *local* ]]; then
    if [[ -f /usr/local/bin/python3.10 ]]; then
      sudo ln -s /usr/local/bin/python3.10 $path
    elif [[ -f /usr/bin/python3.10 ]]; then
      sudo ln -s /usr/bin/python3.10 $path
    fi
  fi
done

# Install jsh
./j.sh install
