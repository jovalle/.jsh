" ==============================================================================
" Vim Configuration
" ==============================================================================
" Merged from top GitHub dotfiles and Vim communities:
" - amix/vimrc (30k+ stars) - The ultimate Vim configuration
" - junegunn/vim-plug - Modern plugin manager
" - tpope's vim plugins - Essential Vim tooling
" - thoughtbot/dotfiles - Developer-focused settings
" - vim-sensible defaults - Reasonable starting points
"
" Organization:
"   1. Core Settings - Essential Vim behavior
"   2. User Interface - Visual appearance and feedback
"   3. Search & Navigation - Finding and moving through code
"   4. Editing & Formatting - Text manipulation settings
"   5. Key Mappings - Custom shortcuts and commands
"   6. File Types - Language-specific configurations
"   7. Plugins - Plugin manager and plugin configuration
"   8. Local Overrides - Machine-specific customizations
" ==============================================================================

" ==============================================================================
" 1. CORE SETTINGS
" ==============================================================================

" Disable Vi compatibility for full Vim functionality
" This must be first - it changes other options as a side effect
set nocompatible

" Enable syntax highlighting with performance optimizations
syntax enable
set synmaxcol=300              " Don't highlight past 300 columns (performance)
set redrawtime=10000           " Allow more time for loading syntax in large files

" File encoding - UTF-8 everywhere for internationalization
set encoding=utf-8             " Internal encoding
set fileencoding=utf-8         " File write encoding
set fileencodings=utf-8,latin1 " Detection order
scriptencoding utf-8           " Script encoding

" File format detection and handling
set fileformats=unix,dos,mac   " Detection order (Unix preferred)
filetype plugin indent on      " Enable filetype detection, plugins, and indentation

" Persistent undo - survive restarts (requires Vim 7.3+)
" Undo history is saved to disk, allowing undo across sessions
if has('persistent_undo')
  set undofile                 " Enable persistent undo
  set undodir=~/.vim/undodir   " Store undo files in dedicated directory
  set undolevels=10000         " Maximum number of changes to remember
  set undoreload=100000        " Save entire buffer for undo on reload
  " Create undo directory if it doesn't exist
  silent !mkdir -p ~/.vim/undodir > /dev/null 2>&1
endif

" Disable backup and swap files - use version control instead
" These cause more problems than they solve in modern workflows
set nobackup                   " Don't create backup files
set nowritebackup              " Don't create backup before overwriting
set noswapfile                 " Don't create swap files

" Command history - remember more commands
set history=1000               " Store 1000 lines of command history

" Clipboard integration - seamless copy/paste with system
if has('clipboard')
  if has('unnamedplus')
    set clipboard=unnamedplus  " Use + register (X11 clipboard)
  else
    set clipboard=unnamed      " Use * register (primary selection)
  endif
endif

" Auto-reload files changed outside Vim
set autoread                   " Reload when file changes externally
augroup auto_reload
  autocmd!
  " Check for changes when gaining focus or switching buffers
  autocmd FocusGained,BufEnter * checktime
  " Also trigger when cursor is idle
  autocmd CursorHold * checktime
augroup END

" Session and view options - what to remember
set sessionoptions-=options    " Don't save options in sessions
set viewoptions-=options       " Don't save options in views

" Hidden buffers - allow switching without saving
set hidden                     " Allow unsaved buffers in background

" Security - disable modelines (potential security risk)
set modelines=0                " Don't check any lines for modelines
set nomodeline                 " Disable modeline parsing

" Performance tuning
set lazyredraw                 " Don't redraw during macros (performance)
set updatetime=300             " Faster completion and CursorHold (default: 4000)
set timeout                    " Enable timeout for mappings
set timeoutlen=500             " Time to wait for mapped sequence (ms)
set ttimeout                   " Enable timeout for key codes
set ttimeoutlen=10             " Time to wait for key code sequence (ms)

" Memory limits for pattern matching (helps with large files)
set maxmempattern=5000000      " Max memory for pattern matching (5MB)

" ==============================================================================
" 2. USER INTERFACE
" ==============================================================================

" Terminal colors - true color support (24-bit)
if has('termguicolors')
  set termguicolors            " Enable 24-bit RGB colors
endif
set t_Co=256                   " Use 256 colors as fallback
set background=dark            " Optimize colors for dark background

" Display settings
set number                     " Show line numbers
set relativenumber             " Show relative line numbers (hybrid mode)
set numberwidth=4              " Width of line number column
set signcolumn=yes             " Always show sign column (prevents shifting)

" Cursor and current line
set cursorline                 " Highlight current line
set nocursorcolumn             " Don't highlight current column (performance)

" Command line and status
set cmdheight=1                " Command line height
set laststatus=2               " Always show status line
set showcmd                    " Show partial commands in status line
set showmode                   " Show current mode (INSERT, VISUAL, etc.)
set ruler                      " Show cursor position in status line
set shortmess+=c               " Don't show completion messages
set shortmess-=S               " Show search count (Vim 8.1.1270+)

" Window title
set title                      " Set terminal title
set titlestring=%t\ -\ vim     " Window title format

" Scrolling context - keep cursor centered
set scrolloff=8                " Keep 8 lines above/below cursor
set sidescrolloff=8            " Keep 8 columns left/right of cursor

" Line wrapping and display
set wrap                       " Wrap long lines
set linebreak                  " Wrap at word boundaries
set breakindent                " Indent wrapped lines
set showbreak=↪\               " Character to show at start of wrapped lines
set display+=lastline          " Show as much as possible of last line
set textwidth=0                " Don't auto-break lines (use formatoptions instead)

" Invisible characters
set list                       " Show invisible characters
set listchars=tab:▸\ ,trail:·,extends:›,precedes:‹,nbsp:␣

" Split windows
set splitright                 " Open vertical splits to the right
set splitbelow                 " Open horizontal splits below

" Popup menu appearance (for completion)
set pumheight=15               " Maximum height of popup menu
set pumblend=10                " Popup menu transparency (Neovim)

" Wildmenu - enhanced command-line completion
set wildmenu                   " Show completion options in command line
set wildmode=longest:full,full " Completion behavior
set wildignorecase             " Ignore case in filename completion

" Ignore these file patterns in completions
set wildignore+=*.o,*.obj,*.exe,*.dll,*.so,*.a    " Compiled objects
set wildignore+=*.pyc,*.pyo,__pycache__           " Python bytecode
set wildignore+=*.class,*.jar                      " Java bytecode
set wildignore+=*.swp,*.swo,*~                    " Vim swap files
set wildignore+=.git,.hg,.svn                     " Version control
set wildignore+=node_modules,bower_components     " Package managers
set wildignore+=.DS_Store,Thumbs.db               " OS files

" Disable audible bell - use visual flash instead
set noerrorbells               " No error bells
set novisualbell               " No visual bell
set t_vb=                      " Disable bell entirely
set belloff=all                " Turn off all bells (Vim 8+)

" Matching brackets
set showmatch                  " Briefly jump to matching bracket
set matchtime=2                " Tenths of second to show match

" ==============================================================================
" 3. SEARCH & NAVIGATION
" ==============================================================================

" Search behavior
set ignorecase                 " Ignore case in search patterns
set smartcase                  " Override ignorecase if pattern has uppercase
set incsearch                  " Show matches as you type
set hlsearch                   " Highlight all matches
set magic                      " Enable regex special characters

" Grep program - use ripgrep if available (much faster)
if executable('rg')
  set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" Tag file locations
set tags=./tags;,tags          " Look for tags in current dir and upward

" Path for file searches (gf, :find)
set path+=**                   " Search recursively in current directory

" Include patterns for autocomplete
set complete-=i                " Don't scan included files (slow for large projects)
set completeopt=menu,menuone,noselect  " Completion popup behavior

" ==============================================================================
" 4. EDITING & FORMATTING
" ==============================================================================

" Indentation - 2 spaces (configure per filetype below)
set tabstop=2                  " Spaces per tab character
set softtabstop=2              " Spaces per Tab key press
set shiftwidth=2               " Spaces for auto-indent
set expandtab                  " Use spaces instead of tabs
set smarttab                   " Tab at start of line uses shiftwidth
set shiftround                 " Round indent to multiple of shiftwidth

" Auto-indentation
set autoindent                 " Copy indent from current line
set smartindent                " Smart auto-indenting for C-like languages

" Backspace behavior - make it work as expected
set backspace=indent,eol,start " Allow backspace over everything

" Wrapping and navigation
set whichwrap+=<,>,h,l,[,]     " Allow cursor keys to cross line boundaries

" Formatting options
set formatoptions+=j           " Delete comment char when joining lines
set formatoptions+=n           " Recognize numbered lists
set formatoptions+=r           " Insert comment leader after Enter
set formatoptions-=o           " Don't insert comment leader with 'o' or 'O'
set formatoptions+=q           " Allow formatting comments with 'gq'

" Folding - fold by syntax but start unfolded
set foldmethod=indent          " Fold based on indentation
set foldnestmax=5              " Maximum fold nesting
set nofoldenable               " Start with all folds open
set foldlevelstart=99          " Open most folds by default

" Spell checking (enable with :set spell)
set spelllang=en_us            " US English spelling

" Mouse support (works in modern terminals)
if has('mouse')
  set mouse=a                  " Enable mouse in all modes
  set mousemodel=popup         " Right-click shows popup menu
  if has('mouse_sgr')
    set ttymouse=sgr           " Improved mouse handling
  else
    set ttymouse=xterm2        " Fallback for older terminals
  endif
endif

" Disable paste mode (interferes with mappings and plugins)
" Use system clipboard integration instead
set nopaste

" ==============================================================================
" 5. KEY MAPPINGS
" ==============================================================================

" Leader key - comma is ergonomic and common
let mapleader = ','
let g:mapleader = ','
let maplocalleader = '\\'

" ---- File Operations ----

" Quick save
nnoremap <leader>w :w!<CR>

" Save with sudo (when you forgot to open with sudo)
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" Quick quit
nnoremap <leader>q :q<CR>
nnoremap <leader>Q :qa!<CR>

" ---- Navigation ----

" Window/pane navigation with Ctrl+hjkl
" These mappings work with vim-tmux-navigator for seamless navigation
" between vim splits and tmux panes. The plugin will handle tmux
" integration automatically when installed.
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize windows with arrows
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>
nnoremap <leader>bl :buffers<CR>
nnoremap ]b :bnext<CR>
nnoremap [b :bprevious<CR>

" Tab navigation
nnoremap <leader>tn :tabnew<CR>
nnoremap <leader>tc :tabclose<CR>
nnoremap ]t :tabnext<CR>
nnoremap [t :tabprevious<CR>

" ---- Search & Replace ----

" Clear search highlighting
nnoremap <leader><space> :nohlsearch<CR>

" Search for visual selection
vnoremap * y/\V<C-R>=escape(@",'/\')<CR><CR>
vnoremap # y?\V<C-R>=escape(@",'/\')<CR><CR>

" Center screen after search navigation
nnoremap n nzzzv
nnoremap N Nzzzv

" Search and replace word under cursor
nnoremap <leader>s :%s/\<<C-r><C-w>\>//g<Left><Left>
vnoremap <leader>s :s///g<Left><Left><Left>

" ---- Editing ----

" Move lines up/down in visual mode (like VS Code)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Keep visual selection when indenting
vnoremap < <gv
vnoremap > >gv

" Join lines without moving cursor
nnoremap J mzJ`z

" Y to yank to end of line (consistent with D and C)
nnoremap Y y$

" Clipboard operations
noremap <leader>y "+y
noremap <leader>Y "+Y
noremap <leader>p "+p
noremap <leader>P "+P

" ---- Quick Editing ----

" Edit vimrc
nnoremap <leader>ev :edit $MYVIMRC<CR>

" Reload vimrc
nnoremap <leader>rv :source $MYVIMRC<CR>:echo "vimrc reloaded!"<CR>

" ---- Miscellaneous ----

" Toggle spell checking
nnoremap <leader>ss :setlocal spell!<CR>

" Change working directory to current file's directory
nnoremap <leader>cd :cd %:p:h<CR>:pwd<CR>

" Quick access to command mode
nnoremap ; :
vnoremap ; :

" Disable Ex mode (rarely used, easy to trigger accidentally)
nnoremap Q <nop>

" Insert blank lines without entering insert mode
nnoremap <leader>o o<Esc>k
nnoremap <leader>O O<Esc>j

" ==============================================================================
" 6. FILE TYPES
" ==============================================================================

augroup filetypes
  autocmd!

  " ---- Python ----
  autocmd FileType python setlocal
    \ tabstop=4
    \ softtabstop=4
    \ shiftwidth=4
    \ expandtab
    \ autoindent
    \ colorcolumn=88
    \ textwidth=88

  " ---- Go ----
  autocmd FileType go setlocal
    \ tabstop=4
    \ shiftwidth=4
    \ noexpandtab

  " ---- Web (HTML, CSS, JS, TS) ----
  autocmd FileType html,css,javascript,typescript,json,vue,svelte setlocal
    \ tabstop=2
    \ softtabstop=2
    \ shiftwidth=2
    \ expandtab

  " ---- YAML/TOML/Config files ----
  autocmd FileType yaml,yml,toml setlocal
    \ tabstop=2
    \ softtabstop=2
    \ shiftwidth=2
    \ expandtab
    \ indentkeys-=0#
    \ indentkeys-=<:>

  " ---- Markdown ----
  autocmd FileType markdown setlocal
    \ spell
    \ wrap
    \ linebreak
    \ textwidth=80

  " ---- Shell scripts ----
  autocmd FileType sh,bash,zsh setlocal
    \ tabstop=2
    \ softtabstop=2
    \ shiftwidth=2
    \ expandtab

  " ---- Makefile (requires tabs) ----
  autocmd FileType make setlocal
    \ tabstop=4
    \ shiftwidth=4
    \ noexpandtab

  " ---- Git commit messages ----
  autocmd FileType gitcommit setlocal
    \ spell
    \ textwidth=72
    \ colorcolumn=50,72

  " ---- Jinja/Mako templates ----
  autocmd BufNewFile,BufRead *.jinja,*.j2 setlocal filetype=jinja
  autocmd BufNewFile,BufRead *.mako setlocal filetype=mako

augroup END

" Return to last edit position when opening files
augroup last_position
  autocmd!
  autocmd BufReadPost *
    \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
    \ |   exe "normal! g`\""
    \ | endif
augroup END

" Remove trailing whitespace on save (except for specific filetypes)
augroup trailing_whitespace
  autocmd!
  autocmd BufWritePre * if &filetype !~ 'markdown\|diff'
    \ | let save_cursor = getpos(".")
    \ | %s/\s\+$//e
    \ | call setpos(".", save_cursor)
    \ | endif
augroup END

" ==============================================================================
" 7. PLUGINS
" ==============================================================================

" Check if running on a remote host (skip heavy plugins)
if !exists('$SSH_CLIENT')
  " Install vim-plug if not installed
  let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
  if empty(glob(data_dir . '/autoload/plug.vim'))
    silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
  endif

  " Begin plugin section
  call plug#begin('~/.vim/plugged')

  " ---- Essential Plugins ----

  " Sensible defaults everyone agrees on
  Plug 'tpope/vim-sensible'

  " Git integration - :Git blame, :Git diff, etc.
  Plug 'tpope/vim-fugitive'

  " Surround text objects - cs'" to change 'word' to "word"
  Plug 'tpope/vim-surround'

  " Comment toggle - gcc for line, gc for selection
  Plug 'tpope/vim-commentary'

  " Repeat plugin commands with .
  Plug 'tpope/vim-repeat'

  " Bracket mappings - ]q for :cnext, [q for :cprevious, etc.
  Plug 'tpope/vim-unimpaired'

  " ---- Fuzzy Finding ----

  " FZF - blazing fast fuzzy finder
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'

  " ---- File Navigation ----

  " File explorer sidebar
  Plug 'preservim/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }

  " Git status in NERDTree
  Plug 'Xuyuanp/nerdtree-git-plugin'

  " ---- Syntax & Languages ----

  " Syntax highlighting for many languages
  Plug 'sheerun/vim-polyglot'

  " Asynchronous linting (requires Vim 8+ or NeoVim)
  Plug 'dense-analysis/ale'

  " Terraform support
  Plug 'hashivim/vim-terraform'

  " Go development
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries', 'for': 'go' }

  " ---- Completion ----

  " Intellisense engine (requires Node.js)
  Plug 'neoclide/coc.nvim', { 'branch': 'release' }

  " ---- Appearance ----

  " Status line
  Plug 'itchyny/lightline.vim'

  " Git diff in sign column
  Plug 'airblade/vim-gitgutter'

  " Color schemes
  Plug 'morhetz/gruvbox'
  Plug 'dracula/vim', { 'as': 'dracula' }

  " ---- Tmux Integration ----

  " Seamless navigation between vim splits and tmux panes
  " Use Ctrl+h/j/k/l to navigate regardless of vim/tmux context
  Plug 'christoomey/vim-tmux-navigator'

  " ---- Productivity ----

  " Distraction-free writing
  Plug 'junegunn/goyo.vim', { 'for': ['markdown', 'text'] }

  " Auto-pair brackets and quotes
  Plug 'jiangmiao/auto-pairs'

  " Show marks in sign column
  Plug 'kshenoy/vim-signature'

  " Initialize plugin system
  call plug#end()

  " ---- Plugin Configuration ----

  " FZF mappings
  nnoremap <C-p> :Files<CR>
  nnoremap <leader>f :Files<CR>
  nnoremap <leader>b :Buffers<CR>
  nnoremap <leader>g :Rg<CR>
  nnoremap <leader>/ :BLines<CR>
  nnoremap <leader>m :Marks<CR>
  nnoremap <leader>h :History<CR>

  " FZF layout
  let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.8 } }

  " NERDTree mappings and settings
  nnoremap <C-n> :NERDTreeToggle<CR>
  nnoremap <leader>n :NERDTreeFind<CR>
  let g:NERDTreeShowHidden = 1
  let g:NERDTreeMinimalUI = 1
  let g:NERDTreeIgnore = ['\.pyc$', '__pycache__', '\.git$', 'node_modules']

  " Open NERDTree on directory open
  autocmd StdinReadPre * let s:std_in=1
  autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in")
    \ | wincmd p | enew | execute 'NERDTree' argv()[0] | endif

  " Close Vim if NERDTree is the only window left
  autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1
    \ && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

  " ALE (Linting) configuration
  let g:ale_sign_error = '✘'
  let g:ale_sign_warning = '⚠'
  let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
  let g:ale_fix_on_save = 0
  let g:ale_lint_on_text_changed = 'never'
  let g:ale_lint_on_insert_leave = 1
  let g:ale_fixers = {
    \ '*': ['remove_trailing_lines', 'trim_whitespace'],
    \ 'python': ['black', 'isort'],
    \ 'javascript': ['prettier', 'eslint'],
    \ 'typescript': ['prettier', 'eslint'],
    \ 'go': ['gofmt', 'goimports'],
    \ }

  " Lightline configuration
  let g:lightline = {
    \ 'colorscheme': 'gruvbox',
    \ 'active': {
    \   'left': [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
    \   'right': [['lineinfo'], ['percent'], ['fileformat', 'fileencoding', 'filetype']]
    \ },
    \ 'component_function': {
    \   'gitbranch': 'FugitiveHead'
    \ },
    \ }

  " GitGutter configuration
  let g:gitgutter_sign_added = '│'
  let g:gitgutter_sign_modified = '│'
  let g:gitgutter_sign_removed = '_'
  let g:gitgutter_sign_modified_removed = '~'

  " vim-go configuration
  let g:go_fmt_command = 'goimports'
  let g:go_highlight_functions = 1
  let g:go_highlight_methods = 1
  let g:go_highlight_structs = 1
  let g:go_highlight_operators = 1
  let g:go_highlight_build_constraints = 1

  " Terraform configuration
  let g:terraform_fmt_on_save = 1
  let g:terraform_align = 1

  " vim-tmux-navigator configuration
  " Seamless navigation between vim splits and tmux panes
  " Disable tmux navigator when zooming the vim pane
  let g:tmux_navigator_disable_when_zoomed = 1
  " Save on switch (useful for autosave workflows)
  let g:tmux_navigator_save_on_switch = 0
  " Disable default mappings and let our Ctrl+hjkl work
  let g:tmux_navigator_no_mappings = 0

  " Color scheme (set after plugins load)
  silent! colorscheme gruvbox

endif " SSH_CLIENT check

" ---- netrw (built-in file explorer, fallback) ----
let g:netrw_browse_split = 4   " Open in prior window
let g:netrw_altv = 1           " Split to the right
let g:netrw_liststyle = 3      " Tree view
let g:netrw_banner = 0         " Hide banner
let g:netrw_winsize = 25       " Width percentage

" ==============================================================================
" 8. LOCAL OVERRIDES
" ==============================================================================
" Create ~/.vimrc.local for machine-specific settings

if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif

" Load any .vimrc in current directory (for project-specific settings)
" Security: Only if explicitly enabled
if exists('$VIM_LOCAL_PROJECT')
  if filereadable('.vimrc')
    source .vimrc
  endif
endif

" Generate help tags for all plugins
silent! helptags ALL
