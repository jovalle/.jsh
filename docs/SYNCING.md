# Syncing Changes Across Machines

This guide covers how to keep your jsh configuration synchronized across multiple machines.

## Quick Sync

```bash
# Pull changes, then push local changes
jsh sync

# Just pull (don't push)
jsh sync --pull

# Just push (don't pull)
jsh sync --push
```

## Setting Up Sync

### 1. Create Your Repository

Fork or create your own jsh repository:

```bash
# If you cloned the original jsh
cd ~/.jsh
git remote set-url origin git@github.com:YOUR_USERNAME/jsh.git

# Or start fresh
cd ~/.jsh
git remote add origin git@github.com:YOUR_USERNAME/jsh.git
git push -u origin main
```

### 2. Configure SSH Keys

Ensure SSH keys are set up for passwordless sync:

```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Add public key to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy and add to GitHub → Settings → SSH Keys
```

### 3. Set Up on Other Machines

```bash
# Clone your repository
git clone git@github.com:YOUR_USERNAME/jsh.git ~/.jsh

# Initialize
~/.jsh/jsh init -y
```

## Sync Workflow

### Daily Workflow

```bash
# Start of day: pull latest changes
jsh sync --pull

# After making changes: push them
jsh sync --push

# Or do both
jsh sync
```

### Handling Uncommitted Changes

If you have uncommitted changes:

```bash
# Stash changes, sync, then restore
jsh sync --stash

# Or commit first
cd ~/.jsh
git add .
git commit -m "Update configuration"
jsh sync --push
```

### Force Sync

If you want to override local changes with remote:

```bash
jsh sync --force
```

**Warning:** This will discard local changes!

## What Gets Synced

### Tracked (Synced)

- Shell configurations (`.bashrc`, `.zshrc`, `.jshrc`)
- Editor configs (`.vimrc`, neovim config)
- Tmux configuration
- Git configuration
- Package lists (`configs/*.json`)
- Custom utilities (`bin/`)
- jsh CLI source code

### Not Tracked (Machine-Specific)

- Local overrides (`*.local` files)
- Secrets and API keys
- Machine-specific paths
- Generated files (cache, undo history)

## Managing Conflicts

### Prevention

1. **Use local overrides** for machine-specific settings
2. **Commit regularly** to reduce drift
3. **Pull before making changes**

### Resolution

If conflicts occur:

```bash
# Check status
cd ~/.jsh
git status

# View conflicts
git diff

# Resolve manually, then
git add .
git commit -m "Resolve merge conflict"
jsh sync --push
```

### Common Conflict Patterns

**Config value conflicts:**

```bash
# Use ours (local version)
git checkout --ours path/to/file

# Use theirs (remote version)
git checkout --theirs path/to/file
```

**Package list conflicts:**

```bash
# Merge both package lists
# Edit the JSON to include packages from both versions
vim configs/macos/formulae.json
git add configs/macos/formulae.json
```

## Branching Strategy

### Simple (Single Branch)

Use `main` for everything. Simple but can cause conflicts.

### Feature Branches

```bash
# Create a feature branch for experiments
git checkout -b experiment/new-prompt

# Make changes, test
git add .
git commit -m "Try new prompt configuration"

# If it works, merge to main
git checkout main
git merge experiment/new-prompt
git push origin main

# If it doesn't work, discard
git checkout main
git branch -D experiment/new-prompt
```

### Machine Branches

For significantly different machines:

```bash
# Create machine-specific branch
git checkout -b machine/work-laptop

# Cherry-pick shared changes from main
git cherry-pick <commit>

# Or rebase on main periodically
git rebase main
```

## Automated Sync

### Cron Job

Add to crontab for automatic sync:

```bash
# Edit crontab
crontab -e

# Add daily sync at 8 AM
0 8 * * * /Users/jay/.jsh/jsh sync --pull 2>/dev/null
```

### Shell Hook

Auto-sync on shell startup (optional):

```bash
# Add to ~/.jsh_local
if command -v jsh &>/dev/null; then
  # Pull changes on shell startup (async, no wait)
  (jsh sync --pull &>/dev/null &)
fi
```

## Troubleshooting

### "Cannot pull with uncommitted changes"

```bash
# Option 1: Stash changes
jsh sync --stash

# Option 2: Commit changes
git add .
git commit -m "WIP: local changes"
jsh sync

# Option 3: Discard changes
git checkout .
jsh sync --pull
```

### "Push failed"

```bash
# Pull first
jsh sync --pull

# Resolve any conflicts
git add .
git commit -m "Merge remote changes"

# Then push
jsh sync --push
```

### "Repository not found"

```bash
# Check remote URL
git remote -v

# Update if needed
git remote set-url origin git@github.com:YOUR_USERNAME/jsh.git
```

### "Permission denied"

```bash
# Test SSH connection
ssh -T git@github.com

# If it fails, check SSH keys
ssh-add -l

# Add key if missing
ssh-add ~/.ssh/id_ed25519
```

## Migration Guide

### Moving to a New Machine

1. **On old machine:**

   ```bash
   jsh sync --push  # Push latest changes
   ```

2. **On new machine:**

   ```bash
   git clone git@github.com:YOUR_USERNAME/jsh.git ~/.jsh
   ~/.jsh/jsh init -y
   ```

3. **Copy local overrides manually:**

   ```bash
   # On old machine
   scp ~/.jsh_local ~/.gitconfig.local new-machine:~/
   ```

### Migrating from Other Dotfile Systems

If you're coming from another dotfile manager:

1. **Backup existing dotfiles**
2. **Install jsh**
3. **Merge your customizations into jsh's dotfiles**
4. **Or use local overrides for your custom settings**
