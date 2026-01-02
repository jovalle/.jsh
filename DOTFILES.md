# Ultimate Dotfiles Reference

A comprehensive guide to the dotfiles configuration, featuring curated settings from the most popular GitHub dotfiles repositories.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration Files](#configuration-files)
  - [.vimrc - Vim Configuration](#vimrc---vim-configuration)
  - [.gitconfig - Git Configuration](#gitconfig---git-configuration)
  - [.inputrc - Readline Configuration](#inputrc---readline-configuration)
  - [.editorconfig - Editor Configuration](#editorconfig---editor-configuration)
  - [.bashrc - Bash Shell Configuration](#bashrc---bash-shell-configuration)
  - [.zshrc - Zsh Shell Configuration](#zshrc---zsh-shell-configuration)
  - [.tmux.conf - Tmux Configuration](#tmuxconf---tmux-configuration)
  - [Ghostty - Terminal Configuration](#ghostty---terminal-configuration)
- [Key Bindings Reference](#key-bindings-reference)
- [Sources & Inspiration](#sources--inspiration)

---

## Overview

These dotfiles represent a curated collection of configurations merged from the most popular and well-maintained dotfiles repositories on GitHub. Each configuration file includes:

- **Comprehensive comments** explaining every setting
- **Organized sections** for easy navigation
- **Sensible defaults** that work out of the box
- **Local override support** for machine-specific customizations
- **Cross-platform compatibility** where applicable

### Design Principles

1. **Documented**: Every setting has a comment explaining what it does and why
2. **Modular**: Files are organized into logical sections
3. **Portable**: Works across macOS, Linux, and WSL
4. **Extensible**: Local override files for machine-specific tweaks
5. **Performance**: Optimized for fast shell startup times

---

## Installation

The dotfiles are managed through jsh's symlink system. After cloning:

```bash
# Symlinks are created automatically by jsh setup
# Or manually link individual files:
ln -sf ~/.jsh/dotfiles/.vimrc ~/.vimrc
ln -sf ~/.jsh/dotfiles/.gitconfig ~/.gitconfig
ln -sf ~/.jsh/dotfiles/.inputrc ~/.inputrc
ln -sf ~/.jsh/dotfiles/.editorconfig ~/.editorconfig
```

---

## Configuration Files

### .vimrc - Vim Configuration

**Sources**: amix/vimrc (30k+ stars), tpope's plugins, thoughtbot/dotfiles, vim-sensible

#### Key Features

| Feature | Description |
|---------|-------------|
| **Persistent Undo** | Undo history survives restarts (saved to `~/.vim/undodir`) |
| **True Color** | 24-bit color support for modern terminals |
| **Hybrid Line Numbers** | Both absolute and relative line numbers |
| **Smart Search** | Case-insensitive unless uppercase is used |
| **Auto-reload** | Files reload when changed externally |
| **Plugin Manager** | vim-plug with lazy loading |

#### Leader Key Mappings

The leader key is set to `,` (comma):

| Mapping | Action |
|---------|--------|
| `,w` | Quick save |
| `,q` | Quick quit |
| `,Q` | Force quit all |
| `,<space>` | Clear search highlighting |
| `,f` | FZF file finder |
| `,b` | FZF buffer list |
| `,g` | FZF ripgrep search |
| `,ev` | Edit vimrc |
| `,rv` | Reload vimrc |
| `,n` | Find current file in NERDTree |
| `,s` | Search & replace word under cursor |
| `,cd` | Change to current file's directory |
| `,ss` | Toggle spell checking |

#### Window Navigation

| Mapping | Action |
|---------|--------|
| `Ctrl+h/j/k/l` | Move between splits |
| `Ctrl+Arrow` | Resize splits |
| `]b` / `[b` | Next/previous buffer |
| `]t` / `[t` | Next/previous tab |

#### Plugins Included

- **tpope/vim-fugitive**: Git integration (`:Git blame`, `:Git diff`)
- **tpope/vim-surround**: Surround text objects (`cs'"` changes 'x' to "x")
- **tpope/vim-commentary**: Toggle comments (`gcc` for line, `gc` for selection)
- **junegunn/fzf.vim**: Fuzzy finder integration
- **preservim/nerdtree**: File explorer sidebar
- **dense-analysis/ale**: Asynchronous linting
- **sheerun/vim-polyglot**: Syntax highlighting for 100+ languages
- **neoclide/coc.nvim**: IntelliSense engine

#### File Type Settings

| Language | Tab Size | Style |
|----------|----------|-------|
| Python | 4 spaces | PEP 8 compliant (88 char line) |
| Go | 4 tabs | gofmt compatible |
| JavaScript/TypeScript | 2 spaces | Prettier compatible |
| YAML | 2 spaces | Standard |
| Makefile | 4 tabs | Required by make |

---

### .gitconfig - Git Configuration

**Sources**: Julia Evans' git config survey, mathiasbynens/dotfiles, jessfraz/dotfiles

#### Key Features

| Feature | Description |
|---------|-------------|
| **zdiff3 Conflicts** | Shows original text in merge conflicts |
| **Auto-stash Rebase** | Automatically stash changes before rebase |
| **Histogram Diff** | Better diff algorithm for moved code |
| **Color Moved** | Highlights moved lines in diffs |
| **SSH URLs** | Automatically converts HTTPS to SSH |
| **Rerere** | Remembers conflict resolutions |

#### Aliases Quick Reference

| Alias | Expands To |
|-------|------------|
| `git s` | `status -sb` (short status) |
| `git l` | `log --oneline -20` |
| `git lg` | `log --oneline --graph --decorate` |
| `git d` | `diff` |
| `git ds` | `diff --staged` |
| `git co` | `checkout` |
| `git cb` | `checkout -b` (create branch) |
| `git ca` | `commit --amend` |
| `git can` | `commit --amend --no-edit` |
| `git pf` | `push --force-with-lease` (safe force push) |
| `git undo` | `reset --soft HEAD~1` (undo last commit) |
| `git cleanup` | Delete merged branches |

#### Recommended Workflow Settings

```ini
[pull]
    rebase = true           # Rebase instead of merge on pull

[push]
    autoSetupRemote = true  # Auto-track remote on first push
    followTags = true       # Push tags with commits

[rebase]
    autoStash = true        # Stash before rebase
    autoSquash = true       # Auto-squash fixup commits
```

---

### .inputrc - Readline Configuration

**Sources**: topbug.net "inputrc for Humans", Rican7/dotfiles, GNU Readline docs

#### Key Features

| Feature | Description |
|---------|-------------|
| **Vi Mode** | Vi-style command line editing |
| **Case-Insensitive** | Tab completion ignores case |
| **Colored Stats** | File type indicators in completions |
| **History Search** | Up/Down arrows search based on typed prefix |
| **Cursor Shapes** | Different cursor for insert vs command mode |

#### Universal Keybindings

| Key | Action |
|-----|--------|
| `Tab` | Complete |
| `Ctrl+R` | Reverse history search |
| `Ctrl+L` | Clear screen |
| `Ctrl+A` | Beginning of line |
| `Ctrl+E` | End of line |
| `Ctrl+W` | Delete word backward |
| `Ctrl+U` | Delete to beginning of line |
| `Alt+.` | Insert last argument |
| `Up/Down` | History search by prefix |

#### Vi Mode Specific

| Key | Mode | Action |
|-----|------|--------|
| `jj` | Insert | Exit to command mode |
| `v` | Command | Edit in external editor |
| `k/j` | Command | History search up/down |
| `gg` | Command | Beginning of history |
| `G` | Command | End of history |

---

### .editorconfig - Editor Configuration

**Sources**: EditorConfig spec, community best practices, major project conventions

#### Coverage

Defines consistent settings for **50+ file types** across categories:

- **Web**: JavaScript, TypeScript, HTML, CSS, Vue, Svelte
- **Data**: JSON, YAML, TOML, XML, GraphQL
- **Languages**: Python, Go, Rust, Ruby, Java, C/C++, PHP
- **Shell**: Bash, Zsh, PowerShell, Fish
- **Documentation**: Markdown, reStructuredText, AsciiDoc
- **Config**: Dockerfile, Makefile, Terraform, Kubernetes

#### Key Settings by Language

| Language | Indent | Line Length | Notes |
|----------|--------|-------------|-------|
| JavaScript/TypeScript | 2 spaces | 100 | Prettier compatible |
| Python | 4 spaces | 88 | Black compatible |
| Go | Tabs | - | gofmt compatible |
| Ruby | 2 spaces | 120 | Standard Ruby |
| YAML | 2 spaces | 120 | Required for K8s |
| Makefile | Tabs | - | Required by make |
| Markdown | 2 spaces | 80 | Trailing spaces preserved |

---

### .bashrc - Bash Shell Configuration

**Sources**: mathiasbynens/dotfiles, thoughtbot/dotfiles, Bash-it framework

#### Key Features

| Feature | Description |
|---------|-------------|
| **Vi Mode** | Vi-style command line editing |
| **Shopt Settings** | autocd, cdspell, globstar, histappend |
| **History** | 50k entries, timestamps, dedup, ignore patterns |
| **Completion** | Case-insensitive, show all on ambiguous |
| **Prompt** | Git branch, exit codes, user@host |

#### Shell Options Enabled

| Option | Description |
|--------|-------------|
| `autocd` | Type directory name to cd into it |
| `cdspell` | Correct minor cd spelling errors |
| `globstar` | `**` matches recursively |
| `histappend` | Append to history (don't overwrite) |
| `noclobber` | Prevent `>` from overwriting files |

#### Useful Functions

| Function | Usage |
|----------|-------|
| `mkcd <dir>` | Create directory and cd into it |
| `up <n>` | Go up n directories |
| `ex <file>` | Extract any archive format |
| `calc "2+2"` | Quick calculations |
| `weather [city]` | Show weather forecast |
| `showpath` | Show PATH entries, one per line |
| `reload` | Reload bash configuration |

---

### .zshrc - Zsh Shell Configuration

Located at `dotfiles/.zshrc`, sources `.jshrc` for common settings and adds Zsh-specific features.

#### Plugin Manager

Uses **Zinit** for fast, lazy-loaded plugins:

| Plugin | Purpose |
|--------|---------|
| **Powerlevel10k** | Instant prompt, git status |
| **fzf-tab** | FZF-powered tab completion |
| **zsh-autosuggestions** | Fish-like suggestions |
| **fast-syntax-highlighting** | Command highlighting |
| **forgit** | Interactive git commands |
| **zsh-nvm** | Lazy load nvm |

#### Key Features

| Feature | Description |
|---------|-------------|
| **Instant Prompt** | p10k instant prompt for zero-latency startup |
| **Vi Mode** | Vi keybindings with visual mode indicator |
| **Word Navigation** | Alt+Left/Right for word movement |
| **Magic Space** | `!!<space>` expands to last command |
| **Minimal Mode** | `ZSH_MINIMAL=1` for fast, plugin-free shell |

---

### .tmux.conf - Tmux Configuration

**Sources**: gpakosz/.tmux (24k+ stars), thoughtbot/dotfiles, tmux-sensible

#### Key Features

| Feature | Description |
|---------|-------------|
| **Prefix** | `Ctrl+A` (GNU Screen style) + backtick |
| **True Color** | 24-bit color support |
| **Vi Mode** | Vi-style copy mode and navigation |
| **Mouse Support** | Click to select panes, scroll |
| **Session Persistence** | tmux-resurrect + continuum |

#### Key Bindings

| Key | Action |
|-----|--------|
| `Prefix + r` | Reload config |
| `Prefix + \|` | Split horizontally |
| `Prefix + -` | Split vertically |
| `h/j/k/l` | Navigate panes |
| `H/J/K/L` | Resize panes |
| `Prefix + g` | Floating terminal popup |
| `Prefix + G` | Floating lazygit |
| `Prefix + t` | Floating htop |

#### Plugins

| Plugin | Purpose |
|--------|---------|
| **tmux-sensible** | Sensible defaults |
| **tmux-yank** | System clipboard integration |
| **tmux-resurrect** | Save/restore sessions |
| **tmux-continuum** | Auto-save every 10 minutes |
| **vim-tmux-navigator** | Seamless vim/tmux navigation |

---

### Ghostty - Terminal Configuration

**Sources**: linkarzu/dotfiles-latest, Ghostty official docs

Located at `dotfiles/.config/ghostty/config`

#### Key Features

| Feature | Description |
|---------|-------------|
| **GPU Accelerated** | Metal on macOS, Vulkan on Linux |
| **True Color** | Full 24-bit color support |
| **Font Ligatures** | JetBrains Mono with ligatures |
| **Quick Terminal** | Dropdown/quake-style terminal |
| **Shell Integration** | Command tracking, directory sync |

#### Key Bindings

| Key | Action |
|-----|--------|
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+D` | Split right |
| `Cmd+Shift+D` | Split down |
| `Cmd+Alt+Arrow` | Navigate splits |
| `Cmd+\`` | Toggle quick terminal |
| `Cmd+K` | Clear screen |

#### Color Scheme

Uses a VS Code Dark+ inspired palette with mango accent colors:

```
Background: #1e1e1e
Foreground: #e0e0e0
Cursor: #f0c674 (mango)
Selection: #3a3d41
```

---

## Key Bindings Reference

### Universal (All Apps)

| Key | Action |
|-----|--------|
| `Ctrl+R` | Reverse search history |
| `Ctrl+L` | Clear screen |
| `Ctrl+A/E` | Beginning/end of line |
| `Ctrl+W` | Delete word backward |
| `Alt+Left/Right` | Move by word |

### Vi Mode

| Key | Mode | Action |
|-----|------|--------|
| `Esc` | Insert | Enter command mode |
| `i/a/I/A` | Command | Enter insert mode |
| `jj` | Insert | Quick escape (configured) |
| `v` | Command | Visual selection |
| `/` | Command | Search forward |
| `n/N` | Command | Next/prev search result |

---

## Sources & Inspiration

### Primary Sources

| Repository | Stars | Focus |
|------------|-------|-------|
| [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) | 30k+ | macOS, Bash |
| [amix/vimrc](https://github.com/amix/vimrc) | 30k+ | Vim |
| [gpakosz/.tmux](https://github.com/gpakosz/.tmux) | 24k+ | Tmux |
| [thoughtbot/dotfiles](https://github.com/thoughtbot/dotfiles) | 8k+ | Full stack |
| [jessfraz/dotfiles](https://github.com/jessfraz/dotfiles) | 2k+ | Docker/DevOps |

### Specialized Resources

- [Julia Evans - Popular git config options](https://jvns.ca/blog/2024/02/16/popular-git-config-options/)
- [topbug.net - inputrc for Humans](https://www.topbug.net/blog/2017/07/31/inputrc-for-humans/)
- [EditorConfig Specification](https://spec.editorconfig.org/)
- [Ghostty Documentation](https://ghostty.org/docs/config)

---

## Local Overrides

Each configuration supports local override files that are not tracked in git:

| Config | Local Override |
|--------|---------------|
| `.vimrc` | `~/.vimrc.local` |
| `.gitconfig` | `~/.gitconfig.local` |
| `.inputrc` | `~/.inputrc.local` |
| `.bashrc` | `~/.bashrc.local` |
| `.tmux.conf` | `~/.tmux.conf.local` |
| Ghostty | `~/.config/ghostty/config.local` |

Create these files for machine-specific settings that shouldn't be synced across systems.

---

## Performance Tips

### Shell Startup

1. Use `ZSH_MINIMAL=1 zsh` for fast zsh without plugins
2. Run `timebash` or `time zsh -i -c exit` to measure startup time
3. Check for slow completions with `_jsh_debug` output

### Vim

1. Plugins are skipped over SSH (`$SSH_CLIENT` check)
2. Large files have reduced syntax highlighting (`synmaxcol=300`)
3. Completion doesn't scan includes (`complete-=i`)

### Git

1. Uses `fetch.writeCommitGraph` for faster operations
2. `core.preloadIndex` speeds up status checks
3. fsmonitor available for large repos (commented out by default)

---

*Last updated: January 2026*
