# Task Reference Guide

Quick reference for commonly used jsh tasks.

## Setup & Installation

### `task setup`

Complete installation and configuration of jsh. This is the main command to run.

**What it does:**
- Runs pre-flight checks (verifies prerequisites)
- Installs dependencies (homebrew, packages, fonts)
- Configures applications (Firefox, VSCode, etc.)
- Sets up git hooks and shell configurations

**Usage:**
```sh
task setup
```

**First-time setup:**
1. Clone the repository: `git clone https://github.com/jovalle/.jsh.git ~/.jsh`
2. Navigate to the directory: `cd ~/.jsh`
3. Run the setup script: `./setup.sh` (installs Task)
4. Run setup: `task setup`

### `task preflight`

Verify prerequisites before running setup. Automatically called by `task setup`.

**Checks:**
- Required commands: `git`, `stow`, `curl`, `wget`
- Internet connectivity

**Usage:**
```sh
task preflight
```

## Maintenance Tasks

### `task backup`

Backup current configuration files before applying jsh changes.

**What it backs up:**
- `.zshrc`
- `.vimrc`
- `.tmux.conf`
- `.gitconfig`
- `.inputrc`

**Location:** `~/.jsh/backup/YYYYMMDD_HHMMSS/`

**Usage:**
```sh
task backup
```

**Note:** Run this before `task setup` if you want to preserve existing configs.

### `task cleanup`

Clean up local paths known for accumulating excessive files.

**What it cleans:**
- Sync conflict files (`.sync-conflict-*`)
- kubectl cache files
- Git objects (with `git gc`)

**Usage:**
```sh
task cleanup
```

### `task update`

Update brew and system package lists. Does not upgrade packages.

**Usage:**
```sh
task update
```

### `task upgrade`

Upgrade installed packages and plugins.

**What it upgrades:**
- Homebrew packages (`brew upgrade`)
- System packages (apt/dnf)
- Zinit plugins
- Powerlevel10k theme

**Usage:**
```sh
task upgrade
```

## Configuration Tasks

### `task configure`

Apply configurations to OS-specific settings and applications. Part of `task setup`.

**What it configures:**
- Creates symlinks with `stow`
- Sets zsh as default shell
- Configures git hooks
- Mounts SMB shares
- OS-specific configurations (Firefox, VSCode, iTerm2, etc.)

**Usage:**
```sh
task configure
```

### `task uninstall`

Remove symlinks created by stow. Does not uninstall packages.

**Usage:**
```sh
task uninstall
```

**Warning:** This only removes symlinks. Original config files are not automatically restored.

## Development Tasks

### `task lint`

Run all linters on the codebase.

**Linters:**
- `shellcheck` - Shell script linter (required)
- `yamllint` - YAML linter (optional)
- `markdownlint` - Markdown linter (optional)

**Usage:**
```sh
task lint
```

**Dependencies:**
- shellcheck (required): pre-installed on most systems
- yamllint (optional): `pip install yamllint`
- markdownlint (optional): `npm install -g markdownlint-cli`

### `task commit` (alias: `task cz`)

Interactive conventional commit using commitizen.

**Usage:**
```sh
task commit
# or
task cz
```

**Dependencies:** `commitizen` (installed via `pip_packages` in Linux taskfile)

## Git Tasks

### `task git-hooks`

Install pre-commit hooks for commit message validation.

**Usage:**
```sh
task git-hooks
```

### `task git-submodules`

Update git submodules (fzf, vim plugins, etc.).

**Usage:**
```sh
task git-submodules
```

## Utility Tasks

### `task mount`

Configure and mount SMB shares interactively.

**Usage:**
```sh
task mount [mount_name]
```

**Example:**
```sh
task mount media
```

## Getting Help

List all available tasks:
```sh
task -l
```

View task details:
```sh
task --summary [task-name]
```

## Tips

1. **Run backup first**: Always run `task backup` before `task setup` if you have existing configurations you want to preserve.

2. **Check prerequisites**: Run `task preflight` to verify all required tools are installed.

3. **Idempotency**: All tasks are designed to be run multiple times safely.

4. **Customization**: See `CONTRIBUTING.md` for details on how to customize jsh for your needs.

5. **Troubleshooting**: If a task fails, check:
   - Internet connectivity
   - Required commands are installed
   - Sufficient disk space
   - Permissions for creating symlinks

## Common Workflows

### First-time setup
```sh
cd ~/.jsh
./setup.sh          # Install Task
task backup         # Backup existing configs
task setup          # Full setup
```

### Update existing installation
```sh
cd ~/.jsh
git pull            # Get latest changes
task backup         # Backup current state
task update         # Update package lists
task upgrade        # Upgrade packages
task configure      # Apply new configs
```

### Development workflow
```sh
# Make changes to shell scripts
task lint           # Check for issues

# Commit changes
task commit         # Use commitizen for conventional commits
```

## Platform-Specific Tasks

Tasks prefixed with `os:` are platform-specific and automatically selected based on your operating system:

- **macOS**: `task os:*` calls tasks from `.taskfiles/darwin/taskfile.yaml`
- **Linux**: `task os:*` calls tasks from `.taskfiles/linux/taskfile.yaml`
- **Windows/WSL**: `task wsl:*` calls tasks from `.taskfiles/windows/taskfile.yaml`

You typically don't need to call these directly; they're invoked by main tasks like `task setup`.
