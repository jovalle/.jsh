# jsh Quick Reference

A cheat sheet for common jsh operations.

## First-Time Setup

```bash
git clone git@github.com:USERNAME/jsh.git ~/.jsh
~/.jsh/jsh init -y
exec zsh
```

## Daily Commands

```bash
jsh doctor          # Check health
jsh upgrade         # Update everything
jsh sync            # Sync with remote
```

## Package Management

```bash
jsh install                  # Install all from config
jsh install ripgrep          # Install one package
jsh install neovim --brew    # Specify package manager
jsh tools                    # See available tools
jsh tools install            # Install recommended
```

## Configuration

```bash
jsh dotfiles        # Link dotfiles
jsh dotfiles -s     # Check symlink status
jsh profile         # View environment info
jsh configure       # Apply OS settings
```

## Plugins

```bash
jsh plugins             # List plugins
jsh plugins install     # Install all
jsh plugins update      # Update all
```

## Sync

```bash
jsh sync            # Pull + push
jsh sync -p         # Pull only
jsh sync -P         # Push only
jsh sync -s         # Stash changes first
```

## Shell Aliases (in .jshrc)

```bash
# Navigation
..              # cd ../
.2              # cd ../../
.3              # cd ../../../

# Files
l               # ls -l (or eza if installed)
ll              # ls -la
t               # k or ls -la

# Git
gl              # git log --graph --oneline
git+            # push and set upstream
git-            # reset HEAD~1
gu              # switch git user profile

# Kubernetes
k               # kubectl
kctx            # kubectx
kns             # kubens

# Safety
cp              # cp -iv (interactive, verbose)
mv              # mv -iv
rm              # rm -i
```

## Tmux Keys (prefix = Ctrl+A)

| Key | Action |
|-----|--------|
| `\|` | Split horizontal |
| `-` | Split vertical |
| `h/j/k/l` | Navigate panes |
| `H/J/K/L` | Resize panes |
| `Alt+h/j/k/l` | Navigate (no prefix) |
| `g` | Floating terminal |
| `G` | Floating lazygit |
| `t` | Floating htop |
| `*` | Sync panes toggle |
| `r` | Reload config |
| `Tab` | Last window |
| `I` | Install plugins |
| `U` | Update plugins |

## Vim Keys (leader = ,)

| Key | Action |
|-----|--------|
| `,w` | Save |
| `,q` | Quit |
| `Ctrl+h/j/k/l` | Navigate windows/tmux |
| `Ctrl+p` | Find files (fzf) |
| `,f` | Files |
| `,g` | Grep |
| `,b` | Buffers |
| `Ctrl+n` | Toggle NERDTree |
| `,n` | Find in tree |

## Local Overrides

Create these files for machine-specific settings (not tracked in git):

```
~/.jsh_local          # Shared shell overrides
~/.bashrc.local       # Bash overrides
~/.bashrc.work        # Work-specific
~/.vimrc.local        # Vim overrides
~/.tmux.conf.local    # Tmux overrides
~/.gitconfig.local    # Git overrides
```

## Debug Mode

```bash
export JSH_DEBUG=1
exec $SHELL
```

## Documentation

Full docs in `~/.jsh/docs/`:

- [GETTING_STARTED.md](./GETTING_STARTED.md)
- [ENVIRONMENT.md](./ENVIRONMENT.md)
- [LOCAL_OVERRIDES.md](./LOCAL_OVERRIDES.md)
- [SYNCING.md](./SYNCING.md)
- [COMMANDS.md](./COMMANDS.md)
