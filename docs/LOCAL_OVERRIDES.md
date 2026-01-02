# Local Overrides

jsh supports machine-specific customizations that won't be tracked in git. This allows you to have personalized settings on each machine while keeping your core configuration synchronized.

## How Local Overrides Work

Each configuration file can have a corresponding `.local` file that is:

- Loaded after the main configuration
- **Not tracked in git** (added to `.gitignore`)
- Machine-specific

## Available Override Files

| Main Config | Local Override | Purpose |
|-------------|---------------|---------|
| `~/.bashrc` | `~/.bashrc.local` | Bash-specific machine settings |
| `~/.bashrc` | `~/.bashrc.work` | Work-specific bash settings |
| `~/.zshrc` | `~/.zshrc.local` | Zsh-specific machine settings |
| `~/.jshrc` | `~/.jsh_local` | Shared shell machine settings |
| `~/.vimrc` | `~/.vimrc.local` | Vim machine settings |
| `~/.tmux.conf` | `~/.tmux.conf.local` | Tmux machine settings |
| `~/.gitconfig` | `~/.gitconfig.local` | Git machine settings |
| `~/.inputrc` | `~/.inputrc.local` | Readline machine settings |

## Creating Local Overrides

### Shell Configuration

Create `~/.jsh_local` for settings shared between bash and zsh:

```bash
# ~/.jsh_local - Machine-specific shared settings

# Custom PATH additions
export PATH="/opt/custom/bin:$PATH"

# Machine-specific aliases
alias myserver='ssh user@my-server.local'

# Work proxy settings
export PROXY_ENDPOINT="http://proxy.work.com:8080"

# Machine-specific environment
export KUBECONFIG="${HOME}/.kube/work-config"
```

Create `~/.bashrc.local` for bash-only settings:

```bash
# ~/.bashrc.local - Machine-specific Bash settings

# Custom PS1 for this machine
PS1='[\u@work \W]\$ '

# Work-specific completions
source /opt/work/completions/work.bash
```

Create `~/.bashrc.work` for work-specific settings:

```bash
# ~/.bashrc.work - Work environment settings

# Corporate proxy
export http_proxy="http://proxy.corp.com:8080"
export https_proxy="$http_proxy"

# Work-specific tools
source /opt/corp/tools/setup.sh
```

### Git Configuration

Create `~/.gitconfig.local` for machine-specific git settings:

```gitconfig
# ~/.gitconfig.local - Machine-specific Git settings

[user]
    name = Your Name
    email = your.work.email@company.com

[credential]
    helper = osxkeychain

[http]
    proxy = http://proxy.work.com:8080
```

The main `.gitconfig` includes this automatically:

```gitconfig
[include]
    path = ~/.gitconfig.local
```

### Git User Profiles

For switching git identities per repository, use the `gu` function:

```bash
# Show current git user and available profiles
gu

# Switch to a profile in current repository
gu personal
gu work
```

Configure profiles in `~/.jsh/configs/git/profiles.json`:

```json
{
  "profiles": {
    "personal": {
      "name": "Your Name",
      "email": "personal@example.com",
      "username": "personal-github"
    },
    "work": {
      "name": "Your Work Name",
      "email": "work@company.com",
      "username": "work-github"
    }
  }
}
```

### Vim Configuration

Create `~/.vimrc.local`:

```vim
" ~/.vimrc.local - Machine-specific Vim settings

" Use a different color scheme on this machine
colorscheme dracula

" Work-specific settings
let g:ale_python_flake8_executable = '/opt/python/bin/flake8'

" Machine-specific key mappings
nnoremap <leader>wt :e ~/work/todo.md<CR>
```

### Tmux Configuration

Create `~/.tmux.conf.local`:

```tmux
# ~/.tmux.conf.local - Machine-specific Tmux settings

# Different prefix on this machine
set -g prefix C-b

# Machine-specific status bar additions
set -g status-right "#[fg=#666666]work-laptop #[fg=#969896]| #[fg=#c6c8c6,bg=#282a2e] %b %d #[fg=#ffa827,bold]%H:%M "

# Additional key bindings
bind W new-window -c "~/work"
```

## Environment Variables

### JSH_CUSTOM

Set `JSH_CUSTOM` to point to your local customizations directory:

```bash
export JSH_CUSTOM="${HOME}/.jsh_custom"
```

This is sourced at the end of `.jshrc`.

### JSH_DEBUG

Enable debug logging to see what's being loaded:

```bash
export JSH_DEBUG=1
exec $SHELL
```

## Best Practices

### 1. Keep Secrets Local

Never commit secrets to the main configuration:

```bash
# In ~/.jsh_local (not tracked)
export API_KEY="your-secret-key"
export AWS_ACCESS_KEY_ID="your-key"
```

### 2. Use Environment Detection

Conditionally load settings based on environment:

```bash
# In ~/.jsh_local
case "$(hostname)" in
  work-laptop*)
    export WORK_MODE=1
    source ~/.work-config.sh
    ;;
  home-*)
    export HOME_MODE=1
    ;;
esac
```

### 3. Document Your Overrides

Add comments explaining why each override exists:

```bash
# ~/.jsh_local

# Work laptop has older Python, need to use specific version
export PATH="/opt/python3.9/bin:$PATH"

# Corporate firewall requires proxy for everything
export http_proxy="http://proxy:8080"
```

### 4. Backup Local Overrides

While not tracked in git, consider backing up your local files:

```bash
# Create a backup directory
mkdir -p ~/Backups/dotfiles-local

# Backup local overrides
cp ~/.jsh_local ~/Backups/dotfiles-local/
cp ~/.gitconfig.local ~/Backups/dotfiles-local/
cp ~/.vimrc.local ~/Backups/dotfiles-local/
```

Or use a separate private repository for local overrides.

## Syncing Local Overrides

If you want to share local overrides between similar machines:

1. Create a private gist or repository
2. Clone to a known location: `~/.jsh_local_repo`
3. Symlink the files:

```bash
ln -sf ~/.jsh_local_repo/work.sh ~/.jsh_local
ln -sf ~/.jsh_local_repo/gitconfig.local ~/.gitconfig.local
```
