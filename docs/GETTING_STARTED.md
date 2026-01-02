# Getting Started with jsh

This guide will help you set up jsh on a new machine and understand the basics of managing your shell environment.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/jsh.git ~/.jsh

# Run the interactive setup
~/.jsh/jsh init

# Or run non-interactively with defaults (zsh + full setup)
~/.jsh/jsh init -y
```

## What jsh Does

jsh provides:

- **Unified shell configuration** - One config that works across bash and zsh
- **Dotfile management** - Automatic symlink creation and backup
- **Package management** - Cross-platform package installation and updates
- **Tool discovery** - Find and install recommended development tools
- **Plugin management** - Manage vim, tmux, and shell plugins

## Installation Options

### Interactive Installation (Recommended)

```bash
~/.jsh/jsh init
```

This will prompt you to choose:

1. **Shell**: zsh (recommended), bash, or skip
2. **Setup type**: minimal (core tools only) or full (themes, plugins, completions)
3. **Package installation**: whether to install Homebrew and essential tools

### Non-Interactive Installation

```bash
# Default: zsh + full setup
~/.jsh/jsh init -y

# Minimal setup (no plugins, themes)
~/.jsh/jsh init -y --minimal

# Specific shell
~/.jsh/jsh init -y --shell bash

# Full setup with immediate package installation
~/.jsh/jsh init -y --setup
```

### Dry Run

Preview what would happen without making changes:

```bash
~/.jsh/jsh init --dry-run
```

## Post-Installation

After initialization:

1. **Start your new shell**:

   ```bash
   exec zsh  # or exec bash
   ```

2. **Check your environment**:

   ```bash
   jsh doctor   # Run diagnostics
   jsh profile  # View your configuration
   ```

3. **Install recommended tools**:

   ```bash
   jsh tools recommend  # See recommendations
   jsh tools install    # Install recommended tools
   ```

4. **Install plugins** (if using full setup):

   ```bash
   jsh plugins install
   ```

## Directory Structure

After installation, jsh creates:

```
~/.jsh/                  # Main jsh directory
├── jsh                  # The jsh CLI tool
├── dotfiles/            # Configuration files (symlinked to ~)
├── configs/             # Package lists and settings
├── bin/                 # Custom utilities (added to PATH)
├── src/                 # Source code for jsh CLI
└── docs/                # Documentation

~/ (home directory)
├── .bashrc -> ~/.jsh/dotfiles/.bashrc
├── .zshrc -> ~/.jsh/dotfiles/.zshrc
├── .jshrc -> ~/.jsh/dotfiles/.jshrc     # Shared config
├── .vimrc -> ~/.jsh/dotfiles/.vimrc
├── .tmux.conf -> ~/.jsh/dotfiles/.tmux.conf
├── .gitconfig -> ~/.jsh/dotfiles/.gitconfig
├── .inputrc -> ~/.jsh/dotfiles/.inputrc
└── .editorconfig -> ~/.jsh/dotfiles/.editorconfig
```

## Next Steps

- [Managing Your Environment](./ENVIRONMENT.md) - Customize your setup
- [Local Overrides](./LOCAL_OVERRIDES.md) - Machine-specific settings
- [Syncing Changes](./SYNCING.md) - Keep machines in sync
- [Command Reference](./COMMANDS.md) - All available commands
