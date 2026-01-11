<div align="center">
  <img src=".github/assets/jsh.jpeg" width="200px" height="200px" alt="jsh logo" />

# jsh

> Portable, feature-rich shell environment that enhances and standardizes life in the terminal

</div>

**JSH** is a pure-shell dotfiles system designed to provide a consistent, powerful shell experience across macOS, Linux, and any SSH session. It leverages battle-tested tools (p10k, fzf, neovim) while keeping everything else in pure shell for maximum portability.

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2728/512.gif" width="24" alt="" /> Features

- **Instant Prompt** - Powerlevel10k for a beautiful, informative, zero-latency prompt
- **Fuzzy Everything** - FZF integration for files, history, git, and more
- **Vi-Mode** - Full vi editing with cursor shape indicators
- **80+ Aliases** - Tiered system: core always loads, extended aliases for detected tools
- **50+ Functions** - Productivity boosters (extract, serve, mkcd, etc.)
- **SSH Portability** - `jssh` carries your environment to any remote host, no installation required
- **Pure Shell** - No external dependencies for core functionality
- **Auto-Updates** - GitHub Actions keep lib dependencies current

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f3a1/512.gif" width="24" alt="" /> Philosophy

1. **Pure shell where possible** - Core functionality works without external tools
2. **Leverage existing tools** - Don't reinvent p10k, fzf, or neovim
3. **Portability first** - Works on macOS, Linux, and over SSH
4. **Graceful degradation** - Missing tools don't break anything
5. **No magic** - Readable, understandable configuration

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" width="24" alt="" /> Installation

```bash
git clone --depth 1 https://github.com/jovalle/jsh ~/.jsh
~/.jsh/jsh setup
exec $SHELL
```

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2705/512.gif" width="24" alt="" /> Requirements

**Required:**

- `git` - For installation and updates
- `zsh` or `bash` - Shell (zsh recommended)

**Recommended:**

- `fzf` - Fuzzy finder (bundled)
- `fd` - Better find
- `rg` (ripgrep) - Better grep
- `bat` - Better cat
- `eza` - Better ls
- `nvim` - Neovim

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f3c1/512.gif" width="24" alt="" /> Portability

Connect to any server with your full shell environment:

```bash
jssh user@server.example.com
```

This:

1. Bundles your shell config into a compressed payload
2. Transfers it through the SSH connection
3. Extracts to a temp directory on the remote
4. Launches your shell with the custom environment
5. Cleans up automatically when you disconnect

No installation, no traces left behind. Bring your own keyboard to work.

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1fa84/512.gif" width="24" alt="" /> Commands

```bash
# Setup
jsh bootstrap   # Clone/update repo and setup (for fresh installs)
jsh setup       # Setup jsh (symlink dotfiles, init submodules)
jsh teardown    # Remove jsh symlinks and optionally the installation
jsh update      # Update jsh and submodules (p10k, fzf)

# Packages
jsh install     # Install packages (brew, apt, npm, cargo, etc.)
jsh uninstall   # Uninstall packages

# Dotfiles
jsh adopt       # Adopt files/directories into jsh management
jsh dotfiles    # Manage dotfile symlinks (link/unlink/restore/status)

# Info
jsh status      # Show installation status
jsh doctor      # Check for issues and missing tools
jsh edit        # Edit jsh configuration files
jsh local       # Edit local shell customizations (~/.jshrc.local)
jsh -r          # Reload shell configuration

# SSH
jssh            # SSH with portable environment (full mode)
jssh --lite     # SSH with minimal payload (~16MB vs ~150MB)
jssh --rebuild  # Force payload rebuild
```

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1fae7/512.gif" width="24" alt="" /> Key Bindings

### Vi Mode (Insert)

| Key        | Action                   |
| ---------- | ------------------------ |
| `jj`       | Exit to normal mode      |
| `Ctrl+A/E` | Beginning/end of line    |
| `Ctrl+W`   | Delete word              |
| `Ctrl+L`   | Clear screen             |
| `Up/Down`  | History search by prefix |

### FZF

| Key      | Action          |
| -------- | --------------- |
| `Ctrl+T` | Find files      |
| `Ctrl+R` | Search history  |
| `Alt+C`  | cd to directory |

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/26a1/512.gif" width="24" alt="" /> Aliases (Highlights)

### Navigation

```bash
..      # cd ..
...     # cd ../..
-       # cd - (previous)
```

### Git

```bash
g       # git
gs      # git status -sb
gp      # git push
gpu     # git push -u origin HEAD
gl      # git log --oneline -20
gd      # git diff
gco     # git checkout
gcb     # git checkout -b
```

### Docker/K8s (if installed)

```bash
d       # docker
dps     # docker ps
k       # kubectl
kgp     # kubectl get pods
kl      # kubectl logs -f
```

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2699/512.gif" width="24" alt="" /> Functions (Highlights)

```bash
mkcd dir        # mkdir && cd
extract file    # Extract any archive
serve [port]    # Quick HTTP server
ff pattern      # Find files
fcd             # FZF cd
fe              # FZF edit
genpass [len]   # Generate password
weather [loc]   # Weather forecast
cheat topic     # Cheat sheet
```

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/270f_fe0f/512.gif" width="24" alt="" /> Local Overrides

Machine-specific config goes in these files (not tracked in git):

| File | Use Case |
| ---------------------- | ----------------------------------------------------- |
| `~/.jsh/local/.jshrc` | Simple env vars and exports (keeps everything in jsh) |
| `~/.jshrc.local` | Simple overrides (if you prefer `~/` location) |
| `~/.jsh/local/init.sh` | Complex setups with multiple files |

All three are sourced automatically. Choose based on preference:

- **`local/.jshrc`** - Quick exports like `export EDITOR=code` or `export AWS_PROFILE=dev`
- **`~/.jshrc.local`** - Same purpose, but lives in home directory instead of jsh
- **`local/init.sh`** - When you need to organize into multiple files (source others from here)

Shell-specific overrides (rarely needed):

- `~/.zshrc.local` - Zsh-only overrides
- `~/.bashrc.local` - Bash-only overrides

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f30e/512.gif" width="24" alt="" /> Structure

```text
~/.jsh/
├── jsh                    # CLI tool (setup, update, doctor, etc.)
├── Makefile               # Automation targets
│
├── src/                   # Shell configuration (pure shell)
│   ├── init.sh            # Entry point (source this)
│   ├── core.sh            # Platform detection, colors, utilities
│   ├── aliases.sh         # Tiered alias system
│   ├── functions.sh       # Utility functions
│   ├── vi-mode.sh         # Vi editing with cursor shapes
│   ├── git.sh             # Git shortcuts and utilities
│   ├── prompt.sh          # Prompt configuration
│   ├── profiles.sh        # Cloud/project profile switching
│   ├── projects.sh        # Project management
│   ├── zsh.sh             # Zsh-specific config
│   ├── bash.sh            # Bash-specific config
│   ├── completions/       # Shell completions
│   └── fzf/               # FZF integration scripts
│
├── core/                  # Symlink targets (dotfiles)
│   ├── .zshrc             # Zsh entry point
│   ├── .bashrc            # Bash entry point
│   ├── .config/           # XDG config (nvim, etc.)
│   ├── gitconfig          # Git configuration
│   ├── gitignore_global   # Global gitignore
│   ├── inputrc            # Readline (vi mode)
│   ├── tmux.conf          # Tmux configuration
│   └── p10k.zsh           # Powerlevel10k theme
│
├── lib/                   # Bundled dependencies (submodules)
│   ├── p10k/              # Powerlevel10k
│   ├── fzf/               # FZF
│   ├── zsh-autosuggestions/
│   ├── zsh-completions/
│   ├── zsh-syntax-highlighting/
│   └── zsh-z/             # Directory jumping
│
├── bin/                   # Standalone tools
│   ├── jssh               # SSH with portable environment
│   └── ...                # Other utilities
│
├── config/                # JSH configuration files
│   ├── dependencies.json  # Tool dependencies
│   ├── profiles.json      # Cloud profiles
│   └── projects.json      # Project definitions
│
├── scripts/               # Helper scripts
│   ├── macos/             # macOS-specific scripts
│   ├── linux/             # Linux-specific scripts
│   └── windows/           # Windows-specific scripts
│
├── local/                 # Machine-specific config (gitignored)
│   └── .jshrc             # Local overrides
│
└── archive/               # Previous implementation (reference)
```

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f31f/512.gif" width="24" alt="" /> Credits

Built on the shoulders of:

- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) by Roman Perepelitsa
- [fzf](https://github.com/junegunn/fzf) by Junegunn Choi
- the [Neovim](https://neovim.io/) community

Inspired by countless dotfiles repos and the Unix philosophy.

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2696_fe0f/512.gif" width="24" alt="" /> License

[MIT](LICENSE) so you can do whatever you want with this. Fork it, tweak it, use it at work, sell a product built on it, whatever. Just keep the license file around so people know where it came from. No warranties, no strings attached.
