# Troubleshooting Guide

Common issues and solutions for jsh setup and usage.

## Installation Issues

### Task Not Found

**Symptom:** `task: command not found` after running `./setup.sh`

**Solution:**
1. Verify task was installed:
   ```sh
   ls -la /usr/local/bin/task
   ```
2. If missing, manually install task:
   ```sh
   sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
   ```
3. Verify installation:
   ```sh
   task --version
   ```

### Stow Not Found

**Symptom:** `stow: command not found`

**Solution:**

**On macOS:**
```sh
brew install stow
```

**On Linux (Debian/Ubuntu):**
```sh
sudo apt-get install stow
```

**On Linux (Fedora/RHEL):**
```sh
sudo dnf install stow
```

### Missing Required Commands

**Symptom:** Pre-flight check fails with missing commands

**Solution:**
Run the setup script again:
```sh
./setup.sh
```

Or manually install missing commands:

**On macOS:**
```sh
brew install curl wget git vim zsh
```

**On Linux (Debian/Ubuntu):**
```sh
sudo apt-get install curl wget git vim zsh
```

## Configuration Issues

### Font Not Loading in Terminal

**Symptom:** Special characters or icons not displaying correctly

**Solution:**
1. Verify fonts are installed:
   - JetBrains Mono Nerd Font
   - Fira Code Nerd Font
   - Meslo Nerd Font

2. **On macOS:**
   ```sh
   brew install --cask font-jetbrains-mono-nerd-font font-fira-code-nerd-font font-meslo-lg-nerd-font
   ```

3. **On Linux:** Download from [Nerd Fonts](https://www.nerdfonts.com/)

4. Configure terminal to use the font:
   - iTerm2: Preferences → Profiles → Text → Font
   - Terminal.app: Preferences → Profiles → Text → Font
   - Windows Terminal: Settings → Profiles → Appearance → Font face

5. Restart terminal application

### Zinit Errors on First Shell Start

**Symptom:** Errors about missing zinit or plugins on first zsh start

**Solution:**
This is normal on first run. Zinit will auto-install on first shell start.

1. Close and reopen your terminal
2. Or manually trigger zinit installation:
   ```sh
   zsh
   ```
3. Wait for zinit to complete plugin installation
4. Restart shell once more

### Powerlevel10k Configuration Not Showing

**Symptom:** Shell prompt looks basic, not customized

**Solution:**
1. Verify p10k is installed:
   ```sh
   ls ~/.oh-my-zsh/custom/themes/powerlevel10k
   ```

2. If missing, update git submodules:
   ```sh
   task git-submodules
   ```

3. Run p10k configuration wizard:
   ```sh
   p10k configure
   ```

### Stow Conflicts

**Symptom:** `stow` fails with conflicts about existing files

**Solution:**

**Option 1: Backup and remove conflicting files**
```sh
# Backup existing configs
task backup

# Remove or rename conflicting files
mv ~/.zshrc ~/.zshrc.backup
mv ~/.vimrc ~/.vimrc.backup
# etc.

# Try stow again
task configure
```

**Option 2: Use stow's adopt flag** (already in taskfile)
```sh
# This will move existing files into the jsh directory
task stow
```

## Shell Issues

### Changes Not Taking Effect

**Symptom:** Changes to config files don't appear in shell

**Solution:**
1. Source the config file:
   ```sh
   source ~/.zshrc
   ```

2. Or restart your shell:
   ```sh
   exec zsh
   ```

3. Or close and reopen terminal

### Shell Not Changing to Zsh

**Symptom:** Default shell is still bash after running setup

**Solution:**
1. Verify zsh is installed:
   ```sh
   which zsh
   ```

2. Manually change shell:
   ```sh
   chsh -s $(which zsh)
   ```

3. Log out and log back in

### Command Not Found for Custom Functions

**Symptom:** Custom functions like `kubectx+` not found

**Solution:**
1. Verify PATH includes `.bin`:
   ```sh
   echo $PATH | grep .bin
   ```

2. Source zshrc:
   ```sh
   source ~/.zshrc
   ```

3. Verify scripts are executable:
   ```sh
   chmod +x ~/.bin/*
   ```

## Platform-Specific Issues

### macOS: Firefox Configuration Fails

**Symptom:** `task configure` fails on Firefox setup

**Solution:**
1. Verify Firefox is installed:
   ```sh
   ls /Applications/Firefox.app
   ```

2. Launch Firefox at least once to create profile directory

3. Find profile directory:
   ```sh
   find ~/Library/Application\ Support/Firefox/Profiles -name "*.default-release"
   ```

4. Retry configuration:
   ```sh
   task os:configure-firefox
   ```

### Windows/WSL: Symlink Permission Denied

**Symptom:** Cannot create symlinks in Windows/WSL

**Solution:**

**Enable Developer Mode in Windows:**
1. Open Settings → Update & Security → For Developers
2. Enable "Developer Mode"
3. Restart WSL

**Or run scripts with elevated permissions:**
```powershell
# In PowerShell (as Administrator)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
```

### Linux: Homebrew Installation Fails

**Symptom:** Cannot install Homebrew

**Solution:**
1. Install dependencies:
   ```sh
   sudo apt-get install build-essential procps curl file git
   ```

2. Retry Homebrew installation:
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

3. Add Homebrew to PATH (if not automatic):
   ```sh
   echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
   ```

## Git and Version Control

### Git Submodules Not Updating

**Symptom:** Submodules like `.fzf` are empty or outdated

**Solution:**
```sh
# Initialize and update all submodules
git submodule update --init --recursive --remote

# Or use the task
task git-submodules
```

### Pre-commit Hook Errors

**Symptom:** Commits fail with pre-commit hook errors

**Solution:**
1. Verify pre-commit is installed:
   ```sh
   which pre-commit
   ```

2. Install if missing:
   ```sh
   pip install pre-commit
   # or
   pipx install pre-commit
   ```

3. Reinstall hooks:
   ```sh
   task git-hooks
   ```

4. Verify hook installation:
   ```sh
   ls -la .git/hooks/commit-msg
   ```

## Network Issues

### Cannot Download Packages

**Symptom:** Package installation fails with network errors

**Solution:**
1. Check internet connectivity:
   ```sh
   ping -c 3 google.com
   ```

2. Check DNS resolution:
   ```sh
   nslookup github.com
   ```

3. If behind proxy, configure proxy:
   ```sh
   export http_proxy="http://proxy:port"
   export https_proxy="http://proxy:port"
   ```

4. Retry with longer timeout:
   ```sh
   # For brew
   export HOMEBREW_CURL_RETRIES=3
   ```

## Performance Issues

### Slow Shell Startup

**Symptom:** Terminal takes several seconds to start

**Solution:**
1. Profile shell startup:
   ```sh
   time zsh -i -c exit
   ```

2. Disable plugins temporarily to identify culprit:
   - Comment out plugins in `.zshrc`
   - Reload shell: `exec zsh`

3. Common causes:
   - Too many zinit plugins
   - Slow network checks
   - Large history files

4. Optimize:
   - Remove unused plugins
   - Lazy-load plugins
   - Clear shell history: `task cleanup`

### High Memory Usage

**Symptom:** Terminal consuming excessive memory

**Solution:**
1. Check running processes:
   ```sh
   ps aux | grep zsh
   ```

2. Clear zinit cache:
   ```sh
   rm -rf ~/.zinit
   zsh
   ```

3. Restart terminal

## Getting More Help

### Enable Debug Mode

Add to your shell config temporarily:
```sh
set -x  # Enable debug mode
# ... commands to debug
set +x  # Disable debug mode
```

### Check Logs

View recent system logs:
```sh
# macOS
log show --predicate 'process == "zsh"' --last 1h

# Linux
journalctl -u user@$(id -u).service --since "1 hour ago"
```

### Report an Issue

If you encounter a bug or issue:

1. Create an issue at: https://github.com/jovalle/.jsh/issues
2. Include:
   - Operating system and version
   - Shell version: `echo $SHELL; $SHELL --version`
   - Task version: `task --version`
   - Error messages (full output)
   - Steps to reproduce

### Additional Resources

- [Task Documentation](https://taskfile.dev/)
- [Zinit Documentation](https://github.com/zdharma-continuum/zinit)
- [Powerlevel10k Documentation](https://github.com/romkatv/powerlevel10k)
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/)
