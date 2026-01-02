# Managing Your Environment

This guide covers how to customize your jsh environment, manage packages, and configure your development setup.

## Environment Detection

jsh automatically detects your environment type:

- **macos-personal** - Full access to all tools and settings
- **macos-corporate** - May have restricted admin access
- **linux-generic** - Standard Linux environment
- **truenas** - Read-only system, minimal tools
- **ssh-remote** - Minimal environment for SSH sessions

Check your environment:

```bash
jsh profile
jsh profile -v   # Verbose output
jsh profile --json  # Machine-readable output
```

## Shell Configuration

### Configuration Hierarchy

1. **`.jshrc`** - Shared configuration (sourced by both bash and zsh)
   - Environment variables
   - Aliases
   - Functions
   - PATH setup

2. **`.bashrc`** / **`.zshrc`** - Shell-specific settings
   - Shell options (shopt/setopt)
   - Prompt configuration
   - Key bindings
   - Completions

3. **Local overrides** - Machine-specific settings (see [Local Overrides](./LOCAL_OVERRIDES.md))

### Key Features

#### Graceful Degradation

jsh features silently skip when tools are unavailable:

```bash
# Enable debug mode to see what's being skipped
export JSH_DEBUG=1
exec $SHELL
```

#### Tool Completions

jsh automatically loads completions for installed tools:

- direnv
- docker
- kubectl
- fzf
- zoxide
- atuin

## Package Management

### Installing Packages

```bash
# Install all packages from config files
jsh install

# Install a single package
jsh install ripgrep

# Install via specific package manager
jsh install neovim --brew
jsh install black --pip
jsh install tokei --cargo
```

### Upgrading Packages

```bash
# Upgrade everything
jsh upgrade

# With progress display disabled
jsh upgrade --no-progress
```

This upgrades:

- Homebrew/Linuxbrew packages
- Mac App Store apps (if `mas` installed)
- npm/bun packages
- Cargo packages
- Zinit plugins
- TPM (tmux plugins)

### Package Configuration

Packages are defined in `~/.jsh/configs/`:

```
configs/
├── macos/
│   ├── formulae.json    # Homebrew formulae
│   ├── casks.json       # Homebrew casks (apps)
│   └── services.json    # Services to start
├── linux/
│   ├── formulae.json    # Linuxbrew formulae
│   ├── apt.json         # Debian/Ubuntu packages
│   ├── dnf.json         # Fedora/RHEL packages
│   └── pacman.json      # Arch packages
├── npm.json             # npm/bun packages
└── cargo.json           # Rust packages
```

## Tool Discovery

### List Available Tools

```bash
# List all tools with status
jsh tools

# Show only missing tools
jsh tools -m

# Filter by category
jsh tools -c dev      # Development tools
jsh tools -c shell    # Shell enhancements
jsh tools -c k8s      # Kubernetes tools
jsh tools -c git      # Git enhancements
```

### Install Recommended Tools

```bash
# See recommendations for your environment
jsh tools recommend

# Install recommended tools
jsh tools install

# Install tools in a specific category
jsh tools install -c dev
```

## Plugin Management

### Supported Plugin Managers

- **Zinit** - Zsh plugin manager (fast, lazy-loading)
- **TPM** - Tmux Plugin Manager
- **vim-plug** - Vim plugin manager

### Managing Plugins

```bash
# List all plugins
jsh plugins

# Install plugin managers and plugins
jsh plugins install

# Update all plugins
jsh plugins update

# Check plugin health
jsh plugins check

# Manage specific plugin type
jsh plugins update --vim
jsh plugins update --tmux
jsh plugins update --shell
```

### Plugin Installation in Editors

After running `jsh plugins install`:

**Vim:**

```vim
:PlugInstall    " Install plugins
:PlugUpdate     " Update plugins
:PlugClean      " Remove unused plugins
```

**Tmux** (inside tmux session):

```
prefix + I      # Install plugins
prefix + U      # Update plugins
```

## Diagnostics

### Health Check

```bash
jsh doctor
```

This checks:

- Required commands (brew, git, curl, jq, vim)
- Recommended commands (fzf, zoxide, rg, fd, nvim, tmux)
- Dotfile symlinks
- Git repository status
- Plugin managers (Zinit, TPM, vim-plug)
- Homebrew health
- Shell configuration
- TERM settings (important for tmux)

### Status Overview

```bash
jsh status
```

Shows:

- Installed packages
- Running services
- Symlink status
- Git status

## Tmux Configuration

### Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl+A` | Prefix (instead of Ctrl+B) |
| `prefix + r` | Reload config |
| `prefix + \|` | Split horizontal |
| `prefix + -` | Split vertical |
| `h/j/k/l` | Navigate panes (vim-style) |
| `H/J/K/L` | Resize panes |
| `Alt+h/j/k/l` | Navigate panes (no prefix) |
| `prefix + g` | Floating terminal |
| `prefix + G` | Floating lazygit |
| `prefix + *` | Toggle synchronized panes |

### Vim-Tmux Navigator

Navigate seamlessly between vim splits and tmux panes with `Ctrl+h/j/k/l`. This requires:

- vim-tmux-navigator plugin in vim (included in vimrc)
- vim-tmux-navigator plugin in tmux (included in tmux.conf)

## Vim Configuration

### Key Mappings

Leader key: `,`

| Key | Action |
|-----|--------|
| `,w` | Quick save |
| `,q` | Quick quit |
| `Ctrl+h/j/k/l` | Window navigation |
| `Ctrl+p` | FZF file finder |
| `,f` | FZF files |
| `,g` | Ripgrep search |
| `,b` | Buffer list |
| `Ctrl+n` | Toggle NERDTree |

### Installed Plugins

- vim-sensible, vim-fugitive, vim-surround
- fzf.vim, NERDTree
- vim-polyglot, ALE
- coc.nvim (completion)
- lightline, gruvbox

See the full plugin list in `~/.vimrc`.
