# jsh Quality of Life Improvements

> **Last Updated**: 2025-11-05
>
> This document tracks potential improvements to enhance usability, maintainability, and reliability of the jsh dotfiles repository.

## Misc

## 🎯 Quick Wins (High Impact, Low Effort)

### Documentation & Onboarding

- [ ] **Create troubleshooting guide** - Common issues and solutions (e.g., font not loading, zinit errors, stow conflicts)
- [ ] **Add task reference guide** - Quick reference card showing all available tasks with examples
- [ ] **Document custom shell functions** - Create `docs/FUNCTIONS.md` explaining the 30+ custom zsh functions
- [ ] **Add screenshots/demos** - Visual examples of powerlevel10k, fzf integration, and vim setup
- [ ] **Create platform compatibility matrix** - Show which features work on macOS/Linux/WSL/Windows

### Code Cleanup

- [ ] **Remove `.zshrc copy`** - Appears to be accidental backup file
- [ ] **Clean up `.config/` directory** - Remove or gitignore app caches (31 subdirectories, some are runtime data)
- [ ] **Audit `.local/` directory** - Verify contents should be versioned vs gitignored
- [ ] **Remove hardcoded "jay" username** - Document in README as a prerequisite check before first run

### Validation & Safety

- [ ] **Add pre-flight checks to setup task** - Verify prerequisites (git, stow, internet) before running
- [ ] **Create backup task** - `task backup` to save current configs before applying jsh changes
- [ ] **Add dry-run mode** - `task setup --dry-run` to preview what would change
- [ ] **Validate taskfile syntax** - Add task to check YAML validity before running

---

## 🔧 Configuration Management

### Portability & Templating

- [ ] **Replace hardcoded paths with variables**
  - Extract username to `.env` or detect via `$USER`
  - Replace `/Users/jay/`, `/home/jay/`, `C:\Users\jay\` references
  - Use `{{.HOME}}` in taskfiles consistently
- [ ] **Create configuration template system**
  - Add `config.example.yaml` for user-specific settings
  - Generate personalized configs from templates on first run
  - Support for: username, email, git config, proxy settings, mount points
- [ ] **Make Firefox/VSCode configs optional** - Add flags to skip if user doesn't want custom configs
- [ ] **Add config validation task** - Check for missing variables or broken references

### Environment Detection

- [ ] **Improve OS/platform detection**
  - Add WSL-specific taskfile (currently shares Linux)
  - Detect ARM vs x86 architecture for appropriate packages
  - Add environment info command: `task info` (show OS, arch, installed tools)
- [ ] **Conditional package installation** - Skip packages that are already installed (faster reruns)
- [ ] **Detect available package managers** - Gracefully handle missing brew/apt/winget

---

## 🧪 Testing & Validation

### Automated Testing

- [ ] **Add shell script linting**
  - Run `shellcheck` on all `.bin/` scripts
  - Add to pre-commit hooks
  - Create `task lint` to run all linters
- [ ] **Create test suite for shell functions**
  - Unit tests for complex functions (kubectx+, nukem, extract)
  - Integration tests for taskfile workflows
  - Use `bats` (Bash Automated Testing System)
- [ ] **Add configuration validation tests**
  - Verify symlinks are created correctly
  - Check that all referenced paths exist
  - Validate YAML/JSON config files
- [ ] **CI/CD improvements**
  - Add linting workflow (shellcheck, yamllint, markdownlint)
  - Add test workflow that runs on PRs
  - Test installation on multiple OS platforms (GitHub Actions matrix)

### Error Handling

- [ ] **Improve error messages in taskfiles** - Add descriptive `msg:` to preconditions
- [ ] **Add error recovery** - Provide suggestions when tasks fail (e.g., "Run `task install` first")
- [ ] **Create health check task** - `task doctor` to verify setup integrity
- [ ] **Add verbose mode** - `task setup --verbose` for debugging

---

## 📦 Package & Dependency Management

### Package Organization

- [ ] **Extract package lists to separate files**
  - Move from inline YAML to `packages/darwin.yaml`, `packages/linux.yaml`
  - Allows easier package management and comparison
  - Group by category (development, shell, kubernetes, etc.)
- [ ] **Add package sync task** - `task packages:sync` to update package list files from installed
- [ ] **Create minimal vs full installation modes**
  - `task setup:minimal` - Core shell only
  - `task setup:full` - Everything including dev tools
  - `task setup:k8s` - Kubernetes-focused subset
- [ ] **Add package version pinning** - For critical tools, allow version specification

### Dependency Documentation

- [ ] **Generate dependency tree** - Show which packages depend on others
- [ ] **Add alternative packages** - Document alternatives for optional tools (e.g., `bat` vs `cat`)
- [ ] **Create minimal requirements doc** - What's absolutely required vs nice-to-have

---

## 🚀 Enhanced Automation

### New Tasks

- [ ] **`task status`** - Show what's installed, what's missing, what's outdated
- [ ] **`task sync`** - Pull from remote, update submodules, stow, reload shell
- [ ] **`task clean`** - Remove broken symlinks, clean caches
- [ ] **`task migrate`** - Migrate from old configs (upgrade path)
- [ ] **`task profile`** - Benchmark shell startup time (zsh loading performance)
- [ ] **`task diff`** - Show differences between local and repository configs

### Git Operations

- [ ] **Add git hooks taskfile** - Reference in CONTRIBUTING.md but not implemented
- [ ] **Create `task commit`** - Wrapper around commitizen for consistent commits
- [ ] **Add `task sync:upstream`** - For forks to sync with original repo
- [ ] **Implement `task release`** - Tag versions, generate changelog

### Shell Enhancements

- [ ] **Create shell reload function** - `reload-jsh` to source configs without restart
- [ ] **Add update notifications** - Notify when jsh repository has upstream changes
- [ ] **Create shell command completion** - Tab completion for custom functions

---

## 📝 Documentation Improvements

### Missing Documentation

- [ ] **Create `docs/ARCHITECTURE.md`** - Explain design decisions and file organization
- [ ] **Create `docs/CUSTOMIZATION.md`** - How to extend/modify for personal needs
- [ ] **Document all environment variables** - What's available and how to use them
- [ ] **Add `docs/WINDOWS.md`** - Windows-specific setup guide (WSL vs native)
- [ ] **Create plugin guide** - How to add new zsh plugins, vim plugins
- [ ] **Document Syncthing setup** - How to sync across devices

### Inline Documentation

- [ ] **Add function documentation** - Consistent header format for all shell functions
  ```bash
  # Usage: function_name <arg1> [arg2]
  # Description: What it does
  # Example: function_name foo bar
  ```
- [ ] **Document complex vim mappings** - Add comments explaining non-obvious keybinds
- [ ] **Add task descriptions** - Ensure all tasks have `desc:` field
- [ ] **Create decision log** - Document why certain tools were chosen over alternatives

### Auto-Generated Docs

- [ ] **Generate command reference** - Script to extract and document all aliases/functions
- [ ] **Create package manifest** - Auto-generate list of all installed packages
- [ ] **Generate keybinding reference** - Extract from vim/tmux/zsh configs

---

## 🔒 Security Improvements

### Secrets Management

- [ ] **Add secrets detection** - Pre-commit hook to prevent committing API keys
- [ ] **Create secrets template** - `.env.example` showing what secrets are needed
- [ ] **Document SOPS/age usage** - How to use existing encryption support
- [ ] **Add SSH key management guide** - Best practices for key generation and storage

### Audit & Hardening

- [ ] **Security audit task** - Check file permissions, verify no secrets in git
- [ ] **Add security policy** - `SECURITY.md` with vulnerability reporting process
- [ ] **Review Firefox hardening** - Ensure Betterfox config is up to date
- [ ] **Add GPG signing setup** - Task to configure commit signing

---

## 🎨 User Experience Enhancements

### Interactive Setup

- [ ] **Create interactive setup wizard** - Guide users through initial configuration
  - Ask for username, email, preferred tools
  - Select minimal/full installation
  - Choose which apps to configure (Firefox/VSCode)
- [ ] **Add first-run experience** - Welcome message with next steps after setup
- [ ] **Create tutorial mode** - `task tutorial` to learn custom keybindings

### Shell Improvements

- [ ] **Add more kubectl aliases** - Common operations (scale, rollout, logs -f)
- [ ] **Create terraform workspace switcher** - Like kubectx but for TF workspaces
- [ ] **Add docker compose shortcuts** - If using docker/podman compose
- [ ] **Create project navigation function** - Quick jump to common project directories
- [ ] **Add better git branch management** - Interactive branch switcher with fzf
- [ ] **Create note-taking function** - Quick shell notes/snippets system

### Vim Enhancements

- [ ] **Add language-specific snippets** - UltiSnips or LuaSnip templates
- [ ] **Create project-local vimrc support** - Load `.vimrc.local` for project overrides
- [ ] **Add session management** - Save/restore vim sessions for projects
- [ ] **Improve LSP configuration** - Add more language servers with auto-install

---

## 🔍 Monitoring & Observability

### Performance Tracking

- [ ] **Add shell startup profiling** - Automatic timing on slow startups
- [ ] **Create performance baseline** - Track if new changes slow down shell
- [ ] **Add metrics collection** - Optional telemetry for most-used commands/functions

### Logging & Debugging

- [ ] **Add debug mode** - `JSH_DEBUG=1` to enable verbose logging
- [ ] **Create log rotation for shell history** - Prevent unlimited history growth
- [ ] **Add task execution logging** - Record what tasks were run and when

---

## 🛠️ Maintenance Tasks

### Code Quality

- [ ] **Refactor long functions** - Break down complex functions into smaller pieces
- [ ] **Standardize error handling** - Consistent patterns across shell scripts
- [ ] **Add type hints where possible** - For scripts that support it
- [ ] **Remove dead code** - Audit for unused functions/aliases

### Dependency Updates

- [ ] **Create dependency update task** - `task deps:update` to check for outdated packages
- [ ] **Add changelog generation** - Auto-generate from conventional commits
- [ ] **Implement semantic versioning** - Tag releases with proper versions
- [ ] **Add deprecation warnings** - For features being phased out

### Technical Debt

- [ ] **Consolidate duplicate code** - DRY principle for repeated patterns in taskfiles
- [ ] **Standardize naming conventions** - Ensure consistency across all files
- [ ] **Review and update .gitignore** - Ensure all necessary patterns are covered
- [ ] **Update git submodules strategy** - Consider alternatives (vendor, subtree)

---

## 🌐 Cross-Platform Improvements

### Windows Support

- [ ] **Fix missing Windows scripts** - `configure-firefox.sh` referenced but doesn't exist
- [ ] **Add Windows-specific functions** - PowerShell equivalents of shell functions
- [ ] **Create WSL bridge utilities** - Easy file/command access between WSL and Windows
- [ ] **Add Windows Terminal customization** - Color schemes, profiles

### Platform Parity

- [ ] **Feature comparison matrix** - Show which features work on each platform
- [ ] **Add fallback implementations** - When tool isn't available on platform
- [ ] **Create platform-specific guides** - Best practices per OS

---

## 🎓 Community & Sharing

### Open Source Improvements

- [ ] **Add LICENSE file** - Clarify usage terms
- [ ] **Create issue templates** - For bug reports and feature requests
- [ ] **Add PR template** - Checklist for contributors
- [ ] **Create community guidelines** - CODE_OF_CONDUCT.md
- [ ] **Add contributors guide** - How to contribute, coding standards

### Sharing & Forking

- [ ] **Create fork setup guide** - How to adapt for personal use
- [ ] **Add username replacement script** - Automate the hardcoded path changes
- [ ] **Create "dotfiles as a service"** - GitHub template repository option
- [ ] **Add comparison with other dotfiles** - What makes jsh unique

---

## 📊 Metrics & Analytics (Optional)

- [ ] **Track command usage** - Which aliases/functions are most used
- [ ] **Monitor shell performance** - Average startup time over time
- [ ] **Track installation success rate** - How often does setup complete without errors
- [ ] **Generate usage reports** - Periodic summary of most-used tools

---

## 🔮 Future Enhancements

### Advanced Features

- [ ] **Add dotfile synchronization** - Beyond Syncthing (git-based sync)
- [ ] **Create multi-profile support** - Work vs personal configs
- [ ] **Add remote machine bootstrap** - SSH into new machine and auto-setup
- [ ] **Create web dashboard** - View configs, browse functions, search aliases
- [ ] **Add plugin system** - Allow third-party extensions

### Integration Ideas

- [ ] **Integrate with password manager** - 1Password/Bitwarden CLI integration
- [ ] **Add cloud storage mounting** - Easy S3/GCS mounting utilities
- [ ] **Create backup automation** - Automated backups of important configs
- [ ] **Add system monitoring** - Resource usage alerts in shell prompt

---

## 📋 Priority Matrix

### Do First (High Impact, Easy Implementation)

1. Add troubleshooting guide
2. Create `task status` command
3. Add pre-flight checks to setup
4. Remove `.zshrc copy` and clean `.config/`
5. Improve error messages in taskfiles
6. Add shellcheck to pre-commit hooks
7. Create backup task

### Do Soon (High Impact, Moderate Effort)

1. Replace hardcoded paths with variables
2. Create interactive setup wizard
3. Add test suite for shell functions
4. Create health check (`task doctor`)
5. Extract package lists to separate files
6. Add CI/CD linting workflow
7. Generate command reference documentation

### Do Later (Nice to Have)

1. Add performance monitoring
2. Create web dashboard
3. Implement plugin system
4. Add metrics collection
5. Multi-profile support

---

## 🎯 Next Steps

To get started, consider:

1. **Week 1**: Quick wins - documentation and cleanup
2. **Week 2**: Configuration management - templating and portability
3. **Week 3**: Testing - add linting and basic test suite
4. **Week 4**: Automation - new tasks and enhanced workflows

---

**Contributing**: If you implement any of these improvements, please:
- Follow conventional commit format
- Update this file to mark items as complete
- Add corresponding documentation
- Test on at least one platform before committing
