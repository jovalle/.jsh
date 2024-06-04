<div align="center">
  <img src="jsh.jpeg" width="200px" height="200px" />

  # jsh

  <p>
    A collection of files to improve life in the shell
  </p>
</div>

## 📖 Overview

A feature-rich and consistent life in the shell. This is a mono repository for my local environments in both macOS and Linux (+WSL). I sync this project/directory across my devices using [Syncthing](https://syncthing.net/).

## 📚 Core Elements

My shell of choice is `zsh` with [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) as the shell framework. Bootstrapping with [`task`](https://github.com/go-task/task) and [`stow`](https://www.gnu.org/software/stow/).

### 🔌 Shell Plugins

Plugins are either installed as git repo submodules or explicitly in the setup script:

- `fzf`: Fuzzy finder enabled in shell reverse search and in `vim`
- `oh-my-zsh`: Shell framework that enables themes and plugins
- `powerlevel10k`: Stunning yet functional shell prompt
- `zsh-autosuggestions`: Pseudo auto-completion like in `fish` shell
- `zsh-highlighting`: Emphasizes, as you write, if a command/file/directory is missing (usually due to a typo)

### 🍟 Binaries

Scripts at `./bin/` are imported into `PATH`:

- `colours`: Unlocks full 8-bit colors in the shell
- `httpstat`: Quick and easy HTTP requests with light benchmarking
- `kubectx`: Must-have script for managing local Kubernetes configuration contexts
- `kubens`: Similar to `kubectx` but for cluster namespaces
- `nukem`: Quick and dirty script for eliminating pesky finalizers in Kubernetes
- `sshrc`: Copies shell customizations to SSH targets for duration of sessions

### 📝 Configurations

Project includes custom configs for `iTerm2` and `vscode`.

### 🖍️ Customization

#### 🎨 Theme

[Night Owl](https://marketplace.visualstudio.com/items?itemName=sdras.night-owl) is the default theme. If only it was as widely supported as [Dracula](https://draculatheme.com/)... 🤷🏽‍♂️

## 🐣 Prerequisites

The only prereq not handled by this repo is the installation of `task`.

```sh
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
```

### Font

p10k recommends [Meslo Nerd Font](https://github.com/ryanoasis/nerd-fonts) and will install it (`p10k configure`) if missing and using iTerm2.

## 📲 Install

```sh
task install
```

### 🗑️ Uninstall

```sh
task uninstall
```
