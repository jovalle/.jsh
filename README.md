# .jsh

```go
          _____                _____       __     __
         |\    \_         _____\    \     /  \   /  \
         \ \     \       /    / \    |   /   /| |\   \
          \|      |     |    |  /___/|  /   //   \\   \
           |      |  ____\    \ |   || /    \_____/    \
   ______  |      | /    /\    \|___|//    /\_____/\    \
  /     / /      /||    |/ \    \    /    //\_____/\\    \
 |      |/______/ ||\____\ /____/|  /____/ |       | \____\
 |\_____\      | / | |   ||    | |  |    | |       | |    |
 | |     |_____|/   \|___||____|/   |____|/         \|____|
  \|_____|
```

## 📖 Overview

A feature-rich and consistent life in the shell. This is a mono repository for my local environments in both macOS and Linux (+WSL). I sync this project/directory across my devices using [Syncthing](https://syncthing.net/).

## 📚 Core Elements

My shell of choice is zsh. This repository strives to be platform agnostic but given I only use zsh, and mostly on macOS, cannot guarantee support for other shells and operating systems.

### 🔌 Shell Plugins

Plugins are either installed as git repo submodules or explicitly in the setup script:

- `autojump`: Aliased to `j`, enables shortcuts to commonly used directories
- `fzf`: Fuzzy finder enabled in shell reverse search and in `vim`
- `oh-my-zsh`: Shell framework that enables themes and plugins
- `powerlevel10k`: Excellent shell theme
- `zsh-autosuggestions`: Partial auto-completion like in `fish` shell

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

Before installing the shell scripts and shell plugins mentioned above, there are numerous tweaks, fonts, and applications I like to install on my devices. Do review the list and update accordingly.

## 📲 Install

Run `setup-macos.sh` or `setup-debian.sh` to handle prerequisites and install all that this repo has to offer.

```sh
./setup-macos.sh
```

Use `j.sh` if these special install scripts are of no use to you.

### 🗑️ Uninstall

```sh
./j.sh uninstall
```
