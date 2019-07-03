#!/usr/bin/env bash

read -r -p "Are you sure you want to remove jsh? [y/N] " confirmation
if [ "$confirmation" != y ] && [ "$confirmation" != Y ]; then
  echo "Uninstall cancelled"
  exit
fi

echo "Removing ~/.jsh"
if [ -d $HOME/.jsh ]; then
  rm -rf $HOME/.jsh
fi

echo "Looking for original bash config..."
if [ -f $HOME/.bashrc.pre-jsh ] || [ -h $HOME/.bashrc.pre-jsh ]; then
  echo "Found ~/.bashrc.pre-jsh -- Restoring to ~/.bashrc";

  if [ -f $HOME/.bashrc ] || [ -h $HOME/.bashrc ]; then
    bashrc_SAVE=".bashrc.jsh-uninstalled-$(date +%Y%m%d%H%M%S)";
    echo "Found ~/.bashrc -- Renaming to ~/${bashrc_SAVE}";
    mv $HOME/.bashrc $HOME/"${bashrc_SAVE}";
  fi

  mv $HOME/.bashrc.pre-jsh $HOME/.bashrc;
  exec bash; source $HOME/.bashrc

  echo "Your original bash config was restored. Please restart your session."
else
  if hash chsh >/dev/null 2>&1; then
    echo "Switching back to bash"
    chsh -s /bin/bash
  else
    echo "You can edit /etc/passwd to switch your default shell back to bash"
  fi
fi

echo "Uninstallation complete."