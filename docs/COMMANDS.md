# Command Reference

Complete reference for all jsh commands.

## Command Overview

| Command | Description |
|---------|-------------|
| `jsh init` | Set up shell environment |
| `jsh install` | Install packages |
| `jsh upgrade` | Upgrade all packages |
| `jsh dotfiles` | Manage dotfile symlinks |
| `jsh configure` | Apply OS and app settings |
| `jsh status` | Show system status |
| `jsh doctor` | Run diagnostics |
| `jsh tools` | Discover and manage tools |
| `jsh plugins` | Manage plugins |
| `jsh sync` | Sync with remote repository |
| `jsh profile` | Show environment profile |
| `jsh brew` | Homebrew wrapper |
| `jsh clean` | Remove caches and temp files |
| `jsh deinit` | Remove jsh configuration |
| `jsh completions` | Generate shell completions |

---

## jsh init

Set up shell environment on a new machine.

```bash
jsh init                    # Interactive setup
jsh init -y                 # Non-interactive with defaults
jsh init --shell zsh        # Pre-select shell
jsh init --minimal          # Lightweight setup
jsh init --full             # Full setup with plugins
jsh init --setup            # Also run install + configure
jsh init --skip-brew        # Skip Homebrew installation
jsh init --dry-run          # Preview changes
```

**Flags:**

- `-y, --non-interactive` - Use defaults (zsh + full)
- `--shell <shell>` - Pre-select shell: zsh, bash, or skip
- `--minimal` - Lightweight setup, no plugins
- `--full` - Full setup with themes, plugins, completions
- `--setup` - Also run install + configure after init
- `--no-install` - Skip package installation
- `--skip-brew` - Skip Homebrew installation
- `--dry-run` - Preview changes without applying

---

## jsh install

Install packages from configuration or individually.

```bash
jsh install                 # Install all packages from config
jsh install ripgrep         # Install single package (auto-detect manager)
jsh install neovim --brew   # Install via Homebrew
jsh install black --pip     # Install via pip
jsh install tokei --cargo   # Install via Cargo
```

**Arguments:**

- `package` - Package to install (omit to install all from config)

**Flags:**

- `--brew` - Install via Homebrew/Linuxbrew
- `--gem` - Install via Ruby gem
- `--bun` - Install via bun
- `--npm` - Install via npm
- `--pip` - Install via pip
- `--cargo` - Install via Cargo
- `--apt` - Install via apt (Debian/Ubuntu)
- `--dnf` - Install via dnf (Fedora/RHEL)
- `--pacman` - Install via pacman (Arch)
- `--yum` - Install via yum
- `--zypper` - Install via zypper
- `--no-progress` - Disable TUI progress display
- `-q, --quiet` - Minimal output

---

## jsh upgrade

Upgrade all packages and plugins.

```bash
jsh upgrade                 # Upgrade everything
jsh upgrade --no-progress   # Without TUI display
jsh upgrade -q              # Quiet mode
```

Upgrades:

- Homebrew/Linuxbrew packages
- Mac App Store apps (if mas installed)
- npm/bun packages
- Cargo packages
- Zinit plugins
- TPM (tmux plugins)

**Flags:**

- `--no-progress` - Disable TUI progress display
- `-q, --quiet` - Minimal output

**Alias:** `jsh update`

---

## jsh dotfiles

Manage dotfile symlinks.

```bash
jsh dotfiles                # Create symlinks
jsh dotfiles -s             # Show current status
jsh dotfiles -d             # Remove symlinks
```

**Flags:**

- `-s, --status` - Show current symlink status
- `-d, --remove` - Remove dotfile symlinks

---

## jsh configure

Apply dotfiles, OS settings, and app configurations.

```bash
jsh configure
```

Applies:

- macOS system defaults (if on macOS)
- Application settings
- Service configurations

---

## jsh status

Show system status overview.

```bash
jsh status
```

Shows:

- Installed Homebrew packages
- Running services
- Symlink status
- Git repository status

---

## jsh doctor

Run comprehensive diagnostics.

```bash
jsh doctor
```

Checks:

- Required commands (brew, git, curl, jq, vim)
- Recommended commands (fzf, zoxide, rg, fd, nvim, tmux)
- Dotfile symlinks
- Git repository status and sync
- Plugin managers (Zinit, TPM, vim-plug)
- Homebrew health
- Shell configuration
- TERM settings

**Alias:** `jsh check`

---

## jsh tools

Discover and manage optional development tools.

```bash
jsh tools                   # List all tools
jsh tools list              # Same as above
jsh tools check             # Check health of installed tools
jsh tools install           # Install recommended tools
jsh tools recommend         # Show recommendations
jsh tools -m                # Show only missing tools
jsh tools -c dev            # Filter by category
```

**Arguments:**

- `action` - list (default), check, install, recommend

**Flags:**

- `-m, --missing` - Show only missing tools
- `-c, --category <cat>` - Filter by category: shell, editor, dev, k8s, git, container, cloud

**Categories:**

- `shell` - fzf, zoxide, atuin, eza, bat, starship, direnv
- `editor` - nvim, hx, vim
- `dev` - jq, yq, rg, fd, sd, hyperfine, tokei, just, watchexec
- `k8s` - kubectl, k9s, kubectx, helm, stern, kustomize
- `git` - gh, lazygit, delta, git-lfs, pre-commit
- `container` - docker, podman, lazydocker
- `cloud` - aws, gcloud, az, terraform

---

## jsh plugins

Manage shell, vim, and tmux plugins.

```bash
jsh plugins                 # List all plugins
jsh plugins list            # Same as above
jsh plugins install         # Install plugin managers and plugins
jsh plugins update          # Update all plugins
jsh plugins check           # Check plugin health
jsh plugins install --vim   # Only install vim plugins
jsh plugins update --tmux   # Only update tmux plugins
jsh plugins check --shell   # Only check zinit
```

**Arguments:**

- `action` - list (default), install, update, check

**Flags:**

- `--vim` - Manage vim plugins only (vim-plug)
- `--tmux` - Manage tmux plugins only (TPM)
- `--shell` - Manage shell plugins only (zinit)

---

## jsh sync

Sync jsh changes with remote repository.

```bash
jsh sync                    # Pull then push
jsh sync -p                 # Pull only
jsh sync -P                 # Push only
jsh sync -s                 # Stash local changes before sync
jsh sync -f                 # Force sync (may overwrite)
```

**Flags:**

- `-p, --pull` - Pull changes only
- `-P, --push` - Push changes only
- `-s, --stash` - Stash local changes before syncing
- `-f, --force` - Force sync (may overwrite changes)

---

## jsh profile

Show current environment profile and configuration.

```bash
jsh profile                 # Show summary
jsh profile -v              # Verbose output
jsh profile --json          # JSON output
```

Shows:

- System info (OS, architecture, hostname)
- Shell configuration
- jsh version and git status
- Package management info
- Plugin status

**Flags:**

- `-v, --verbose` - Show detailed configuration
- `--json` - Output as JSON

**Alias:** `jsh env`

---

## jsh brew

Homebrew wrapper with root delegation support.

```bash
jsh brew setup              # Install Homebrew
jsh brew check              # Check for outdated packages
jsh brew check -q           # Quiet mode
jsh brew <command>          # Pass through to brew
```

When running as root, delegates brew commands to `BREW_USER`.

**Arguments:**

- `subcommand` - Brew subcommand: setup, check, or any brew command

**Flags:**

- `-q, --quiet` - Silent mode (for check)
- `-f, --force` - Force check even if run recently

---

## jsh clean

Remove caches, temp files, and old versions.

```bash
jsh clean
```

Cleans:

- Homebrew cache and old versions
- npm/pip caches
- Vim undo files
- System caches

**Alias:** `jsh cleanup`

---

## jsh deinit

Remove jsh symlinks and restore backups.

```bash
jsh deinit
```

This will:

- Remove all jsh dotfile symlinks
- Restore original dotfiles from backups (if available)
- Not uninstall packages

---

## jsh completions

Generate shell completion script.

```bash
jsh completions             # Output completion script
jsh completions -i          # Install completions
```

**Flags:**

- `-i, --install` - Install completions to shell config

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `JSH_ROOT` | Path to jsh repository root |
| `JSH_DEBUG` | Enable debug logging (set to 1) |
| `JSH_CUSTOM` | Path to custom override directory |
| `BREW_USER` | User for Homebrew commands when running as root |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Missing dependency |
