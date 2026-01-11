#!/usr/bin/env bash
# jsh - JSH Shell Management CLI
# Install, configure, and manage your shell environment
#
# Quick Install:
#   curl -fsSL https://raw.githubusercontent.com/jovalle/jsh/main/jsh | bash

set -euo pipefail

VERSION="1.1.0"
JSH_REPO="${JSH_REPO:-https://github.com/jovalle/jsh.git}"
JSH_BRANCH="${JSH_BRANCH:-main}"
JSH_DIR="${JSH_DIR:-${HOME}/.jsh}"
JSH_CONFIGS="${JSH_DIR}/config"
JSH_DEPS_CONFIG="${JSH_DIR}/config/dependencies.json"

# =============================================================================
# Colors
# =============================================================================

if [[ -t 1 ]]; then
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    BLUE=$'\e[34m'
    MAGENTA=$'\e[35m'
    CYAN=$'\e[36m'
    BOLD=$'\e[1m'
    DIM=$'\e[2m'
    RST=$'\e[0m'
else
    # shellcheck disable=SC2034  # Colors kept for consistency, some may be unused
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" BOLD="" DIM="" RST=""
fi

# =============================================================================
# Helpers
# =============================================================================

# Plain colored output
info()    { echo "${BLUE}$*${RST}"; }
success() { echo "${GREEN}$*${RST}"; }
warn()    { echo "${YELLOW}$*${RST}" >&2; }
error()   { echo "${RED}$*${RST}" >&2; }
die()     { error "$@"; exit 1; }

# Prefixed output (for status lists, validation results)
prefix_info()    { echo "${BLUE}◆${RST} $*"; }
prefix_success() { echo "${GREEN}✔${RST} $*"; }
prefix_warn()    { echo "${YELLOW}⚠${RST} $*" >&2; }
prefix_error()   { echo "${RED}✘${RST} $*" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# =============================================================================
# Dotfile Discovery
# =============================================================================

# Discover dotfiles from core/ directory
# Returns entries in format: "target:source" (e.g., ".gitconfig:core/gitconfig")
_discover_root_dotfiles() {
    local core_dir="${JSH_DIR}/core"
    [[ -d "${core_dir}" ]] || return

    # Include hidden files in glob
    local file
    for file in "${core_dir}"/* "${core_dir}"/.*; do
        [[ -f "${file}" ]] || continue
        local name
        name=$(basename "${file}")

        # Skip . and ..
        [[ "${name}" == "." || "${name}" == ".." ]] && continue

        local target
        # Files already starting with dot -> use as-is
        if [[ "${name}" == .* ]]; then
            target="${name}"
        else
            # Special mappings for files without leading dot
            case "${name}" in
                gitconfig)        target=".gitconfig" ;;
                gitignore_global) target=".gitignore_global" ;;
                tmux.conf)        target=".tmux.conf" ;;
                inputrc)          target=".inputrc" ;;
                p10k.zsh)         target=".p10k.zsh" ;;
                *)                target=".${name}" ;;
            esac
        fi

        echo "${target}:core/${name}"
    done
}

# Discover XDG config directories from core/.config/
_discover_xdg_configs() {
    local xdg_source="${JSH_DIR}/core/.config"
    [[ -d "${xdg_source}" ]] || return

    for config_dir in "${xdg_source}"/*; do
        [[ -d "${config_dir}" ]] || continue
        basename "${config_dir}"
    done
}

# Check dotfile link status
# Args: $1 = target path
# Returns: 0=linked to jsh, 1=linked elsewhere, 2=exists not linked, 3=not present
_check_dotfile_status() {
    local dest="$1"

    if [[ -L "${dest}" ]]; then
        local link_target
        link_target=$(readlink "${dest}")
        if [[ "${link_target}" == *"jsh"* ]]; then
            return 0
        else
            return 1
        fi
    elif [[ -e "${dest}" ]]; then
        return 2
    else
        return 3
    fi
}

# Get submodules from .gitmodules
_get_submodules() {
    local gitmodules="${JSH_DIR}/.gitmodules"
    [[ -f "${gitmodules}" ]] || return

    grep -E '^\s*path\s*=' "${gitmodules}" | sed 's/.*=\s*//' | tr -d ' \t'
}

# =============================================================================
# Dependencies (lib/ components)
# =============================================================================

# Get list of dependency names from config
_get_deps() {
    if [[ ! -f "${JSH_DEPS_CONFIG}" ]]; then
        return
    fi
    if has jq; then
        jq -r '.components | keys[]' "${JSH_DEPS_CONFIG}" 2>/dev/null
    fi
}

# Get dependency info by name
# Args: $1 = component name, $2 = field (type, submodule, repo, notes, etc.)
_get_dep_field() {
    local name="$1"
    local field="$2"
    if [[ ! -f "${JSH_DEPS_CONFIG}" ]] || ! has jq; then
        return
    fi
    jq -r --arg name "${name}" --arg field "${field}" \
        '.components[$name][$field] // empty' "${JSH_DEPS_CONFIG}" 2>/dev/null
}

# Check if a dependency is installed
# Args: $1 = component name
# Returns: 0 if installed, 1 if not
_check_dep_installed() {
    local name="$1"
    local dep_type submodule_path

    dep_type=$(_get_dep_field "${name}" "type")
    submodule_path=$(_get_dep_field "${name}" "submodule")

    case "${dep_type}" in
        submodule-only|build-from-source)
            # Check if submodule directory exists and is populated
            local full_path="${JSH_DIR}/${submodule_path}"
            [[ -d "${full_path}" ]] && [[ -n "$(ls -A "${full_path}" 2>/dev/null)" ]]
            ;;
        download-release)
            # Check if binary exists for current platform
            local platform
            platform="$(_get_platform)"
            [[ -x "${JSH_DIR}/lib/bin/${platform}/${name}" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# OS Detection and Package Manager
# =============================================================================

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }

# Detect available package managers (returns list)
detect_package_managers() {
    local managers=()
    if has brew; then managers+=("brew"); fi
    if has apt-get; then managers+=("apt"); fi
    if has dnf; then managers+=("dnf"); fi
    if has yum; then managers+=("yum"); fi
    if has pacman; then managers+=("pacman"); fi
    if has apk; then managers+=("apk"); fi
    if has zypper; then managers+=("zypper"); fi
    if has npm; then managers+=("npm"); fi
    if has cargo; then managers+=("cargo"); fi
    if has pip3 || has pip; then managers+=("pip"); fi
    echo "${managers[*]}"
}

# Get default package manager for current OS
get_default_pm() {
    if is_macos; then
        has brew && echo "brew" && return
    elif is_linux; then
        has apt-get && echo "apt" && return
        has dnf && echo "dnf" && return
        has yum && echo "yum" && return
        has pacman && echo "pacman" && return
        has apk && echo "apk" && return
        has zypper && echo "zypper" && return
        has brew && echo "brew" && return
    fi
    echo ""
}

# Load packages from JSON file (one per line)
_load_packages_json() {
    local json_file="$1"
    if [[ ! -f "${json_file}" ]]; then
        return 1
    fi
    if has jq; then
        jq -r '.[]' "${json_file}" 2>/dev/null
    else
        grep -o '"[^"]*"' "${json_file}" | tr -d '"'
    fi
}

# Add package to JSON array file
_add_package_json() {
    local json_file="$1"
    local package="$2"

    if ! has jq; then
        error "jq is required for package management"
        return 1
    fi

    if [[ ! -f "${json_file}" ]]; then
        echo "[]" > "${json_file}"
    fi

    if jq -e --arg pkg "${package}" 'index($pkg) != null' "${json_file}" >/dev/null 2>&1; then
        info "Package '${package}' already in $(basename "${json_file}")"
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)
    if jq --arg pkg "${package}" '. + [$pkg] | sort' "${json_file}" > "${temp_file}"; then
        mv "${temp_file}" "${json_file}"
        success "Added '${package}' to $(basename "${json_file}")"
        return 0
    fi
    rm -f "${temp_file}"
    return 1
}

# Remove package from JSON array file
_remove_package_json() {
    local json_file="$1"
    local package="$2"

    if ! has jq; then
        error "jq is required for package management"
        return 1
    fi

    if [[ ! -f "${json_file}" ]]; then
        return 1
    fi

    if ! jq -e --arg pkg "${package}" 'index($pkg) != null' "${json_file}" >/dev/null 2>&1; then
        return 1
    fi

    local temp_file
    temp_file=$(mktemp)
    if jq --arg pkg "${package}" 'map(select(. != $pkg))' "${json_file}" > "${temp_file}"; then
        mv "${temp_file}" "${json_file}"
        return 0
    fi
    rm -f "${temp_file}"
    return 1
}

# Get config file path for package manager
_get_pm_config() {
    local pm="$1"
    local pkg_dir="${JSH_CONFIGS}/packages"

    case "${pm}" in
        brew)
            if is_macos; then
                echo "${pkg_dir}/macos/formulae.json"
            else
                echo "${pkg_dir}/linux/brew.json"
            fi
            ;;
        cask)
            echo "${pkg_dir}/macos/casks.json"
            ;;
        apt)
            echo "${pkg_dir}/linux/apt.json"
            ;;
        dnf|yum)
            echo "${pkg_dir}/linux/dnf.json"
            ;;
        npm)
            echo "${pkg_dir}/common/npm.json"
            ;;
        cargo)
            echo "${pkg_dir}/common/cargo.json"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Install via specific package manager
_pm_install() {
    local pm="$1"
    local pkg="$2"
    local result=1

    case "${pm}" in
        brew)
            brew install "${pkg}" && result=0
            ;;
        cask)
            brew install --cask "${pkg}" && result=0
            ;;
        apt)
            sudo apt-get install -y "${pkg}" && result=0
            ;;
        dnf)
            sudo dnf install -y "${pkg}" && result=0
            ;;
        yum)
            sudo yum install -y "${pkg}" && result=0
            ;;
        pacman)
            sudo pacman -S --noconfirm "${pkg}" && result=0
            ;;
        apk)
            sudo apk add "${pkg}" && result=0
            ;;
        zypper)
            sudo zypper install -y "${pkg}" && result=0
            ;;
        npm)
            npm install -g "${pkg}" && result=0
            ;;
        cargo)
            cargo install "${pkg}" && result=0
            ;;
        pip)
            pip3 install --user "${pkg}" && result=0
            ;;
        *)
            error "Unknown package manager: ${pm}"
            return 1
            ;;
    esac

    return "${result}"
}

# Uninstall via specific package manager
_pm_uninstall() {
    local pm="$1"
    local pkg="$2"
    local result=1

    case "${pm}" in
        brew)
            brew uninstall "${pkg}" && result=0
            ;;
        cask)
            brew uninstall --cask "${pkg}" && result=0
            ;;
        apt)
            sudo apt-get remove -y "${pkg}" && result=0
            ;;
        dnf)
            sudo dnf remove -y "${pkg}" && result=0
            ;;
        yum)
            sudo yum remove -y "${pkg}" && result=0
            ;;
        pacman)
            sudo pacman -R --noconfirm "${pkg}" && result=0
            ;;
        apk)
            sudo apk del "${pkg}" && result=0
            ;;
        zypper)
            sudo zypper remove -y "${pkg}" && result=0
            ;;
        npm)
            npm uninstall -g "${pkg}" && result=0
            ;;
        cargo)
            cargo uninstall "${pkg}" && result=0
            ;;
        pip)
            pip3 uninstall -y "${pkg}" && result=0
            ;;
        *)
            error "Unknown package manager: ${pm}"
            return 1
            ;;
    esac

    return "${result}"
}

show_banner() {
    echo ""
    echo "${BOLD}${CYAN}"
    echo "     ██╗███████╗██╗  ██╗"
    echo "     ██║██╔════╝██║  ██║"
    echo "     ██║███████╗███████║"
    echo "██   ██║╚════██║██╔══██║"
    echo "╚█████╔╝███████║██║  ██║"
    echo " ╚════╝ ╚══════╝╚═╝  ╚═╝"
    echo "${RST}"
    echo "${BOLD}Jay's Home in the Shell${RST}"
    echo ""
}

check_requirements() {
    info "Checking requirements..."

    # Git is required
    has git || die "git is required but not installed"

    # Check for zsh (recommended)
    if ! has zsh; then
        warn "zsh is not installed (recommended for full experience)"
    fi

    success "Requirements met"
}

show_next_steps() {
    echo ""
    echo "${BOLD}Next steps:${RST}"
    echo ""
    echo "1. Reload your shell:"
    echo ""
    echo "   ${CYAN}exec \$SHELL${RST}"
    echo ""
    echo "2. (Optional) Configure p10k:"
    echo ""
    echo "   ${CYAN}p10k configure${RST}"
    echo ""
    echo "${BOLD}Useful commands:${RST}"
    echo "  ${CYAN}jsh status${RST}   - Show installation status"
    echo "  ${CYAN}jsh doctor${RST}   - Check for issues"
    echo "  ${CYAN}jsh update${RST}   - Update to latest version"
    echo "  ${CYAN}jssh${RST}         - SSH with portable jsh environment"
    echo ""
}

# =============================================================================
# Commands
# =============================================================================

cmd_help() {
    cat << HELP
${BOLD}jsh${RST} - JSH Shell Management CLI v${VERSION}

${BOLD}QUICK INSTALL:${RST}
    curl -fsSL https://raw.githubusercontent.com/jovalle/jsh/main/jsh | bash

${BOLD}USAGE:${RST}
    jsh <command> [options]

${BOLD}SETUP COMMANDS:${RST}
    ${CYAN}bootstrap${RST}   Clone/update repo and setup (for fresh installs)
    ${CYAN}setup${RST}       Setup jsh (symlink dotfiles, init submodules)
    ${CYAN}teardown${RST}    Remove jsh symlinks and optionally the entire installation
    ${CYAN}update${RST}      Update jsh and submodules (p10k, fzf)

${BOLD}PACKAGE COMMANDS:${RST}
    ${CYAN}install${RST}     Install packages (brew, apt, npm, cargo, etc.)
    ${CYAN}uninstall${RST}   Uninstall packages

${BOLD}DOTFILE COMMANDS:${RST}
    ${CYAN}adopt${RST}       Adopt files/directories into jsh management
    ${CYAN}dotfiles${RST}    Manage dotfile symlinks (link/unlink/restore/status)

${BOLD}INFO COMMANDS:${RST}
    ${CYAN}status${RST}      Show installation status
    ${CYAN}doctor${RST}      Check for issues and missing tools
    ${CYAN}edit${RST}        Edit jsh configuration files
    ${CYAN}local${RST}       Edit local shell customizations (~/.jshrc.local)

${BOLD}SSH:${RST}
    ${CYAN}ssh${RST}         Connect to remote with portable jsh (alias: jssh)

${BOLD}OPTIONS:${RST}
    -h, --help      Show this help
    -v, --version   Show version
    -r, --reload    Reload shell configuration
    --debug         Enable debug output

${BOLD}TEARDOWN OPTIONS:${RST}
    --full          Remove entire JSH directory (default: only unlink dotfiles)
    --restore       Restore backed up dotfiles before unlinking
    --yes, -y       Skip confirmation prompt

${BOLD}INSTALL OPTIONS:${RST}
    --all, -a       Install all packages from config
    --save, -s      Save package to config after install
    --brew          Use Homebrew
    --cask          Use Homebrew Cask (macOS GUI apps)
    --apt           Use apt-get (Debian/Ubuntu)
    --npm           Use npm (Node.js packages)
    --cargo         Use cargo (Rust packages)

${BOLD}DOCTOR OPTIONS:${RST}
    --fix, -f       Fix issues (remove broken symlinks)

${BOLD}ADOPT OPTIONS:${RST}
    -p, --private       Adopt to private/ instead of core/
    --skip-symlinks     Skip paths that are symlinks (non-interactive)
    --follow-symlinks   Follow symlinks to adopt their targets
    --dry-run           Preview changes without making them
    -y, --yes           Skip confirmation prompts

${BOLD}DOTFILES SUBCOMMANDS:${RST}
    jsh dotfiles link       Create symlinks for managed dotfiles
    jsh dotfiles unlink     Remove symlinks (leaves original files)
    jsh dotfiles restore    List available backups
    jsh dotfiles restore <name|latest>  Restore from a specific backup
    jsh dotfiles status     Show status of dotfile symlinks

${BOLD}EXAMPLES:${RST}
    jsh setup                 # Setup jsh locally
    jsh install --all         # Install all configured packages
    jsh install ripgrep bat   # Install packages with default PM
    jsh install --save eza    # Install and save to config
    jsh uninstall bat         # Uninstall a package
    jsh update                # Update to latest
    jsh doctor                # Check for issues
    jsh doctor --fix          # Fix broken symlinks
    jsh adopt ~/.config/app   # Adopt config into jsh management
    jsh adopt -p ~/.ssh/config  # Adopt sensitive file to private/
    jsh adopt --dry-run ~/file  # Preview adoption without changes
    jsh teardown              # Unlink dotfiles only
    jsh teardown --restore    # Restore original dotfiles and unlink
    jsh teardown --full       # Remove everything
    jsh ssh user@host         # SSH with jsh environment

${BOLD}ENVIRONMENT:${RST}
    JSH_DIR         JSH installation directory (default: ~/.jsh)
    JSH_REPO        Git repository URL (default: github.com/jovalle/jsh)
    JSH_BRANCH      Branch to install (default: main)
    JSH_DEBUG       Enable debug output

HELP
}

cmd_version() {
    echo "jsh ${VERSION}"
}

cmd_setup() {
    show_banner
    check_requirements

    info "Setting up jsh..."

    # Initialize submodules
    if [[ -d "${JSH_DIR}/.git" ]]; then
        info "Initializing submodules..."
        git -C "${JSH_DIR}" submodule update --init --depth 1 || warn "Failed to init submodules"
    fi

    # Verify fzf is available
    _check_fzf

    # Setup protected private directory
    _setup_private_dir

    # Create symlinks
    cmd_dotfiles link

    # Create local config directory
    mkdir -p "${JSH_DIR}/local"

    success "JSH setup complete!"
    show_next_steps
}

_get_platform() {
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *)      os="unknown" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             arch="unknown" ;;
    esac
    echo "${os}-${arch}"
}

# Setup protected private directory
# Applies filesystem-level immutable flag to prevent deletion/movement
_setup_private_dir() {
    local private_dir="${JSH_DIR}/private"

    # Create directory if it doesn't exist
    if [[ ! -d "${private_dir}" ]]; then
        mkdir -p "${private_dir}"
        prefix_info "Created private directory"
    fi

    # Apply filesystem protection
    _protect_private_dir
}

# Apply filesystem-level protection to prevent accidental deletion/movement
# Uses system-level immutable flag (requires sudo to set AND remove)
_protect_private_dir() {
    local private_dir="${JSH_DIR}/private"

    [[ -d "${private_dir}" ]] || return 0

    case "$(uname -s)" in
        Darwin)
            # macOS: Use system-immutable flag (schg) - requires sudo to remove
            # This prevents the directory from being deleted/moved but allows editing contents
            if sudo chflags schg "${private_dir}"; then
                prefix_success "Protected private/ (system immutable flag set)"
            else
                prefix_warn "Could not set system immutable flag on private/"
            fi
            ;;
        Linux)
            # Linux: Use chattr +i if available
            if has chattr; then
                if sudo chattr +i "${private_dir}"; then
                    prefix_success "Protected private/ (immutable attribute set)"
                else
                    prefix_warn "Could not set immutable attribute on private/"
                fi
            fi
            ;;
    esac
}

# Remove filesystem protection (for maintenance)
_unprotect_private_dir() {
    local private_dir="${JSH_DIR}/private"

    [[ -d "${private_dir}" ]] || return 0

    case "$(uname -s)" in
        Darwin)
            sudo chflags noschg "${private_dir}" 2>/dev/null || true
            ;;
        Linux)
            if has chattr; then
                sudo chattr -i "${private_dir}" 2>/dev/null || true
            fi
            ;;
    esac
}

_check_fzf() {
    local platform
    platform="$(_get_platform)"
    local bundled_fzf="${JSH_DIR}/lib/bin/${platform}/fzf"

    # Check bundled platform-specific binary
    if [[ -x "${bundled_fzf}" ]]; then
        success "fzf bundled (${platform})"
        return 0
    fi

    # Check if fzf is available in PATH
    if has fzf; then
        info "fzf available in PATH: $(command -v fzf)"
        return 0
    fi

    warn "fzf not found for ${platform}"
    warn "Ctrl+R history search may not work"
    warn "Install fzf manually: brew install fzf"
    return 1
}

cmd_teardown() {
    local full_teardown=false
    local restore_backup=false
    local skip_confirm=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full|-f)
                full_teardown=true
                shift
                ;;
            --restore|-r)
                restore_backup=true
                shift
                ;;
            --yes|-y)
                skip_confirm=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check for protected private directory
    local private_dir="${JSH_DIR}/private"
    local has_private=false
    if [[ -d "${private_dir}" ]]; then
        has_private=true
    fi

    # Confirmation prompt
    if [[ "${skip_confirm}" != true ]]; then
        echo ""
        echo "${YELLOW}Are you sure you want to teardown jsh? T_T${RST}"
        if [[ "${full_teardown}" == true ]]; then
            echo "${RED}This will completely remove ${JSH_DIR}!${RST}"
            if [[ "${has_private}" == true ]]; then
                echo ""
                echo "${CYAN}Warning:${RST} private/ directory is protected with system immutable flag."
                echo "You must first run: ${CYAN}sudo chflags noschg ${private_dir}${RST}"
            fi
        fi
        echo ""
        read -r -p "Type 'yes' to confirm: " confirm
        if [[ "${confirm}" != "yes" ]]; then
            info "Teardown cancelled. Phew! :)"
            return 0
        fi
        echo ""
    fi

    info "Tearing down jsh..."

    # If restoring, do that instead of just unlinking
    if [[ "${restore_backup}" == true ]]; then
        _dotfiles_restore "latest"
    else
        cmd_dotfiles unlink
    fi

    if [[ "${full_teardown}" == true ]]; then
        if [[ -d "${JSH_DIR}" ]]; then
            # Warn if private directory will block removal
            if [[ "${has_private}" == true ]]; then
                warn "Removing immutable flag from private/..."
                _unprotect_private_dir
            fi
            warn "Removing ${JSH_DIR}..."
            if ! rm -rf "${JSH_DIR}" 2>/dev/null; then
                error "Could not remove ${JSH_DIR}"
                error "If private/ is protected, run: sudo chflags noschg ${private_dir}"
                return 1
            fi
            success "JSH completely removed from ${JSH_DIR}"
        fi
    else
        success "jsh teardown complete (dotfiles unlinked)."
    fi

    echo ""
    echo "Don't forget to remove the 'source ~/.jsh/src/init.sh' line"
    echo "from your .zshrc or .bashrc"
}

cmd_install() {
    local pm=""
    local save=false
    local packages=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --brew)     pm="brew"; shift ;;
            --cask)     pm="cask"; shift ;;
            --apt)      pm="apt"; shift ;;
            --dnf)      pm="dnf"; shift ;;
            --yum)      pm="yum"; shift ;;
            --pacman)   pm="pacman"; shift ;;
            --apk)      pm="apk"; shift ;;
            --zypper)   pm="zypper"; shift ;;
            --npm)      pm="npm"; shift ;;
            --cargo)    pm="cargo"; shift ;;
            --pip)      pm="pip"; shift ;;
            --save|-s)  save=true; shift ;;
            --all|-a)   _install_all_packages; return $? ;;
            -*)         warn "Unknown option: $1"; shift ;;
            *)          packages+=("$1"); shift ;;
        esac
    done

    # No packages specified - show help or install all
    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "${BOLD}Package Installation${RST}"
        echo ""
        echo "Usage: jsh install [options] <package...>"
        echo ""
        echo "${CYAN}Options:${RST}"
        echo "  --all, -a     Install all packages from config"
        echo "  --save, -s    Save package to config after install"
        echo ""
        echo "${CYAN}Package Managers:${RST}"
        echo "  --brew        Use Homebrew"
        echo "  --cask        Use Homebrew Cask (macOS GUI apps)"
        echo "  --apt         Use apt-get (Debian/Ubuntu)"
        echo "  --dnf         Use dnf (Fedora/RHEL)"
        echo "  --npm         Use npm (Node.js packages)"
        echo "  --cargo       Use cargo (Rust packages)"
        echo "  --pip         Use pip (Python packages)"
        echo ""
        echo "${CYAN}Available Package Managers:${RST}"
        echo "  $(detect_package_managers)"
        echo ""
        echo "${CYAN}Examples:${RST}"
        echo "  jsh install --all           # Install all configured packages"
        echo "  jsh install ripgrep         # Install with default PM"
        echo "  jsh install --brew bat fd   # Install multiple via Homebrew"
        echo "  jsh install --save eza      # Install and save to config"
        return 0
    fi

    # Detect package manager if not specified
    if [[ -z "${pm}" ]]; then
        pm=$(get_default_pm)
        if [[ -z "${pm}" ]]; then
            die "No package manager detected. Install Homebrew or use a system package manager."
        fi
        info "Using package manager: ${pm}"
    fi

    # Install each package
    local installed=0
    local failed=0

    for pkg in "${packages[@]}"; do
        info "Installing ${pkg}..."
        if _pm_install "${pm}" "${pkg}"; then
            prefix_success "Installed ${pkg}"
            ((installed++))

            # Save to config if requested
            if [[ "${save}" == true ]]; then
                local config_file
                config_file=$(_get_pm_config "${pm}")
                if [[ -n "${config_file}" ]]; then
                    _add_package_json "${config_file}" "${pkg}"
                fi
            fi
        else
            prefix_error "Failed to install ${pkg}"
            ((failed++))
        fi
    done

    echo ""
    if [[ ${failed} -eq 0 ]]; then
        prefix_success "Installed ${installed} package(s)"
    else
        prefix_warn "Installed ${installed}, failed ${failed}"
    fi
}

cmd_uninstall() {
    local pm=""
    local remove_from_config=false
    local packages=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --brew)     pm="brew"; shift ;;
            --cask)     pm="cask"; shift ;;
            --apt)      pm="apt"; shift ;;
            --dnf)      pm="dnf"; shift ;;
            --yum)      pm="yum"; shift ;;
            --pacman)   pm="pacman"; shift ;;
            --apk)      pm="apk"; shift ;;
            --zypper)   pm="zypper"; shift ;;
            --npm)      pm="npm"; shift ;;
            --cargo)    pm="cargo"; shift ;;
            --pip)      pm="pip"; shift ;;
            --remove|-r) remove_from_config=true; shift ;;
            -*)         warn "Unknown option: $1"; shift ;;
            *)          packages+=("$1"); shift ;;
        esac
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "${BOLD}Package Uninstallation${RST}"
        echo ""
        echo "Usage: jsh uninstall [options] <package...>"
        echo ""
        echo "${CYAN}Options:${RST}"
        echo "  --remove, -r  Remove package from config after uninstall"
        echo ""
        echo "${CYAN}Package Managers:${RST}"
        echo "  --brew        Use Homebrew"
        echo "  --cask        Use Homebrew Cask"
        echo "  --apt         Use apt-get"
        echo "  --npm         Use npm"
        echo "  --cargo       Use cargo"
        echo "  --pip         Use pip"
        echo ""
        echo "${CYAN}Examples:${RST}"
        echo "  jsh uninstall ripgrep        # Uninstall with default PM"
        echo "  jsh uninstall --remove bat   # Uninstall and remove from config"
        return 0
    fi

    # Detect package manager if not specified
    if [[ -z "${pm}" ]]; then
        pm=$(get_default_pm)
        if [[ -z "${pm}" ]]; then
            die "No package manager detected."
        fi
        info "Using package manager: ${pm}"
    fi

    # Uninstall each package
    local removed=0
    local failed=0

    for pkg in "${packages[@]}"; do
        info "Uninstalling ${pkg}..."
        if _pm_uninstall "${pm}" "${pkg}"; then
            prefix_success "Uninstalled ${pkg}"
            ((removed++))

            # Remove from config if requested
            if [[ "${remove_from_config}" == true ]]; then
                local config_file
                config_file=$(_get_pm_config "${pm}")
                if [[ -n "${config_file}" ]] && _remove_package_json "${config_file}" "${pkg}"; then
                    prefix_success "Removed '${pkg}' from config"
                fi
            fi
        else
            prefix_error "Failed to uninstall ${pkg}"
            ((failed++))
        fi
    done

    echo ""
    if [[ ${failed} -eq 0 ]]; then
        prefix_success "Uninstalled ${removed} package(s)"
    else
        prefix_warn "Uninstalled ${removed}, failed ${failed}"
    fi
}

# Install all packages from config files
_install_all_packages() {
    info "Installing all configured packages..."

    local total_installed=0
    local total_failed=0

    # macOS: Homebrew formulae and casks
    if is_macos && has brew; then
        local formulae_file="${JSH_CONFIGS}/packages/macos/formulae.json"
        local casks_file="${JSH_CONFIGS}/packages/macos/casks.json"

        if [[ -f "${formulae_file}" ]]; then
            echo ""
            echo "${CYAN}Installing Homebrew formulae...${RST}"
            while IFS= read -r pkg; do
                [[ -z "${pkg}" ]] && continue
                if brew list "${pkg}" &>/dev/null; then
                    prefix_info "${pkg} already installed"
                elif _pm_install brew "${pkg}"; then
                    prefix_success "Installed ${pkg}"
                    ((total_installed++))
                else
                    prefix_error "Failed: ${pkg}"
                    ((total_failed++))
                fi
            done < <(_load_packages_json "${formulae_file}")
        fi

        if [[ -f "${casks_file}" ]]; then
            echo ""
            echo "${CYAN}Installing Homebrew casks...${RST}"
            while IFS= read -r pkg; do
                [[ -z "${pkg}" ]] && continue
                if brew list --cask "${pkg}" &>/dev/null; then
                    prefix_info "${pkg} already installed"
                elif _pm_install cask "${pkg}"; then
                    prefix_success "Installed ${pkg}"
                    ((total_installed++))
                else
                    prefix_error "Failed: ${pkg}"
                    ((total_failed++))
                fi
            done < <(_load_packages_json "${casks_file}")
        fi
    fi

    # Linux: System package manager
    if is_linux; then
        local linux_pm
        linux_pm=$(get_default_pm)
        local linux_config="${JSH_CONFIGS}/packages/linux/${linux_pm}.json"

        if [[ -n "${linux_pm}" ]] && [[ -f "${linux_config}" ]]; then
            echo ""
            echo "${CYAN}Installing ${linux_pm} packages...${RST}"
            while IFS= read -r pkg; do
                [[ -z "${pkg}" ]] && continue
                if _pm_install "${linux_pm}" "${pkg}"; then
                    prefix_success "Installed ${pkg}"
                    ((total_installed++))
                else
                    prefix_error "Failed: ${pkg}"
                    ((total_failed++))
                fi
            done < <(_load_packages_json "${linux_config}")
        fi

        # Linux: Linuxbrew if available
        if has brew; then
            local brew_file="${JSH_CONFIGS}/packages/linux/brew.json"
            if [[ -f "${brew_file}" ]]; then
                echo ""
                echo "${CYAN}Installing Linuxbrew packages...${RST}"
                while IFS= read -r pkg; do
                    [[ -z "${pkg}" ]] && continue
                    if brew list "${pkg}" &>/dev/null; then
                        prefix_info "${pkg} already installed"
                    elif _pm_install brew "${pkg}"; then
                        prefix_success "Installed ${pkg}"
                        ((total_installed++))
                    else
                        prefix_error "Failed: ${pkg}"
                        ((total_failed++))
                    fi
                done < <(_load_packages_json "${brew_file}")
            fi
        fi
    fi

    # Common: npm packages
    if has npm; then
        local npm_file="${JSH_CONFIGS}/packages/common/npm.json"
        if [[ -f "${npm_file}" ]]; then
            echo ""
            echo "${CYAN}Installing npm packages...${RST}"
            while IFS= read -r pkg; do
                [[ -z "${pkg}" ]] && continue
                if npm list -g "${pkg}" &>/dev/null; then
                    prefix_info "${pkg} already installed"
                elif _pm_install npm "${pkg}"; then
                    prefix_success "Installed ${pkg}"
                    ((total_installed++))
                else
                    prefix_error "Failed: ${pkg}"
                    ((total_failed++))
                fi
            done < <(_load_packages_json "${npm_file}")
        fi
    fi

    # Common: cargo packages
    if has cargo; then
        local cargo_file="${JSH_CONFIGS}/packages/common/cargo.json"
        if [[ -f "${cargo_file}" ]]; then
            echo ""
            echo "${CYAN}Installing cargo packages...${RST}"
            while IFS= read -r pkg; do
                [[ -z "${pkg}" ]] && continue
                if cargo install --list | grep -q "^${pkg} "; then
                    prefix_info "${pkg} already installed"
                elif _pm_install cargo "${pkg}"; then
                    prefix_success "Installed ${pkg}"
                    ((total_installed++))
                else
                    prefix_error "Failed: ${pkg}"
                    ((total_failed++))
                fi
            done < <(_load_packages_json "${cargo_file}")
        fi
    fi

    echo ""
    echo "${BOLD}Summary:${RST}"
    echo "  Installed: ${total_installed}"
    echo "  Failed:    ${total_failed}"

    [[ ${total_failed} -eq 0 ]]
}

cmd_update() {
    info "Updating jsh..."

    if [[ -d "${JSH_DIR}/.git" ]]; then
        # Pull latest
        git -C "${JSH_DIR}" pull --rebase || warn "Failed to pull updates"

        # Update submodules
        info "Updating submodules..."
        git -C "${JSH_DIR}" submodule update --remote --merge || warn "Failed to update submodules"

        success "jsh updated!"
    else
        warn "Not a git repository, cannot update"
    fi
}

cmd_status() {
    show_banner

    # Installation info
    echo "${CYAN}Installation:${RST}"
    echo "  Directory: ${JSH_DIR}"
    echo "  Version:   ${VERSION}"

    if [[ -d "${JSH_DIR}/.git" ]]; then
        local branch commit
        branch=$(git -C "${JSH_DIR}" branch --show-current 2>/dev/null || echo "unknown")
        commit=$(git -C "${JSH_DIR}" rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo "  Branch:    ${branch}"
        echo "  Commit:    ${commit}"
    fi

    # Submodules - dynamically from .gitmodules
    echo ""
    echo "${CYAN}Submodules:${RST}"
    local submodule_count=0

    while IFS= read -r submodule_path; do
        [[ -z "${submodule_path}" ]] && continue
        ((submodule_count++))
        local submodule_name
        submodule_name=$(basename "${submodule_path}")
        local full_path="${JSH_DIR}/${submodule_path}"

        if [[ -d "${full_path}" ]] && [[ -n "$(ls -A "${full_path}" 2>/dev/null)" ]]; then
            local mod_commit
            mod_commit=$(git -C "${full_path}" rev-parse --short HEAD 2>/dev/null || echo "?")
            echo "  ${GREEN}✔${RST} ${submodule_name} (${mod_commit})"
        else
            echo "  ${RED}✘${RST} ${submodule_name} (not installed)"
        fi
    done < <(_get_submodules)

    if [[ "${submodule_count}" -eq 0 ]]; then
        echo "  ${DIM}No submodules configured${RST}"
    fi

    # Dependencies from config/dependencies.json
    echo ""
    echo "${CYAN}Dependencies (lib/):${RST}"
    local platform
    platform="$(_get_platform)"

    if [[ ! -f "${JSH_DEPS_CONFIG}" ]]; then
        echo "  ${DIM}No dependencies config found${RST}"
    elif ! has jq; then
        echo "  ${DIM}jq required to read dependencies config${RST}"
    else
        local dep_name dep_type submodule_path
        while IFS= read -r dep_name; do
            [[ -z "${dep_name}" ]] && continue
            dep_type=$(_get_dep_field "${dep_name}" "type")

            case "${dep_type}" in
                submodule-only)
                    submodule_path=$(_get_dep_field "${dep_name}" "submodule")
                    local full_path="${JSH_DIR}/${submodule_path}"
                    if [[ -d "${full_path}" ]] && [[ -n "$(ls -A "${full_path}" 2>/dev/null)" ]]; then
                        local mod_commit
                        mod_commit=$(git -C "${full_path}" rev-parse --short HEAD 2>/dev/null || echo "?")
                        echo "  ${GREEN}✔${RST} ${dep_name} (${mod_commit})"
                    else
                        echo "  ${RED}✘${RST} ${dep_name} (not installed)"
                    fi
                    ;;
                build-from-source)
                    # Check for built binary
                    if [[ -x "${JSH_DIR}/lib/bin/${platform}/${dep_name}" ]]; then
                        local version
                        version=$("${JSH_DIR}/lib/bin/${platform}/${dep_name}" --version 2>/dev/null | head -1 | cut -d' ' -f1)
                        echo "  ${GREEN}✔${RST} ${dep_name} ${version} (${platform})"
                    else
                        echo "  ${RED}✘${RST} ${dep_name} (not built for ${platform})"
                    fi
                    ;;
                download-release)
                    if [[ -x "${JSH_DIR}/lib/bin/${platform}/${dep_name}" ]]; then
                        local version
                        version=$("${JSH_DIR}/lib/bin/${platform}/${dep_name}" --version 2>/dev/null | head -1 | sed 's/NVIM //')
                        echo "  ${GREEN}✔${RST} ${dep_name} ${version} (${platform})"
                    else
                        echo "  ${DIM}-${RST} ${dep_name} (not bundled for ${platform})"
                    fi
                    ;;
            esac
        done < <(_get_deps)
    fi

    # Dotfiles - dynamically discovered
    echo ""
    echo "${CYAN}Dotfiles:${RST}"

    while IFS=: read -r df source_path; do
        [[ -z "${df}" ]] && continue
        local dest="${HOME}/${df}"

        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                echo "  ${GREEN}✔${RST} ${df} -> ${link_target}"
            else
                echo "  ${YELLOW}~${RST} ${df} -> ${link_target} (not jsh)"
            fi
        elif [[ -e "${dest}" ]]; then
            echo "  ${YELLOW}~${RST} ${df} (exists, not linked)"
        else
            echo "  ${DIM}-${RST} ${df} (not present)"
        fi
    done < <(_discover_root_dotfiles)

    # XDG configs - grouped summary
    echo ""
    echo "${CYAN}XDG Configs:${RST}"
    local xdg_config="${XDG_CONFIG_HOME:-${HOME}/.config}"
    local xdg_linked=0 xdg_total=0 xdg_other=0

    while IFS= read -r config_name; do
        [[ -z "${config_name}" ]] && continue
        ((xdg_total++))
        local dest="${xdg_config}/${config_name}"

        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                ((xdg_linked++))
            else
                ((xdg_other++))
            fi
        elif [[ -e "${dest}" ]]; then
            ((xdg_other++))
        fi
    done < <(_discover_xdg_configs)

    if [[ "${xdg_total}" -gt 0 ]]; then
        if [[ "${xdg_linked}" -eq "${xdg_total}" ]]; then
            echo "  ${GREEN}✔${RST} ${xdg_linked}/${xdg_total} configs linked"
        elif [[ "${xdg_linked}" -gt 0 ]]; then
            echo "  ${YELLOW}~${RST} ${xdg_linked}/${xdg_total} configs linked"
            [[ "${xdg_other}" -gt 0 ]] && echo "    ${DIM}(${xdg_other} exist but not linked to jsh)${RST}"
        else
            echo "  ${DIM}-${RST} 0/${xdg_total} configs linked"
        fi
    else
        echo "  ${DIM}No XDG configs found${RST}"
    fi

    # Shell info
    echo ""
    echo "${CYAN}Shell:${RST}"
    echo "  Current:   ${SHELL}"
    echo "  EDITOR:    ${EDITOR:-not set}"
}

# Find broken symlinks in a directory
# Args: $1 = directory to search, $2 = search depth (default 1)
# Outputs broken symlink paths, one per line
_find_broken_symlinks() {
    local search_dir="$1"
    local depth="${2:-1}"

    [[ -d "${search_dir}" ]] || return

    # Find symlinks and check if their targets exist
    find "${search_dir}" -maxdepth "${depth}" -type l 2>/dev/null | while read -r link; do
        # Check if the symlink target exists
        if [[ ! -e "${link}" ]]; then
            echo "${link}"
        fi
    done
}

cmd_doctor() {
    local fix_issues=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix|-f)
                fix_issues=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    echo "${BOLD}JSH Doctor${RST}"
    echo ""

    local issues=0

    # Check shell
    echo "${CYAN}Checking shell...${RST}"
    if has zsh; then
        prefix_success "zsh available: $(zsh --version | head -1)"
    else
        prefix_warn "zsh not found (recommended)"
        ((issues++))
    fi

    # Check required tools
    echo ""
    echo "${CYAN}Checking required tools...${RST}"
    local required=("git" "curl")
    for tool in "${required[@]}"; do
        if has "${tool}"; then
            prefix_success "${tool} available"
        else
            prefix_error "${tool} not found (required)"
            ((issues++))
        fi
    done

    # Check recommended tools (fzf excluded - checked separately in bundled tools)
    echo ""
    echo "${CYAN}Checking recommended tools...${RST}"
    local recommended=("fd" "rg" "bat" "eza" "nvim" "tmux")
    for tool in "${recommended[@]}"; do
        if has "${tool}"; then
            prefix_success "${tool} available"
        else
            prefix_info "${tool} not found (optional)"
        fi
    done

    # Check dependencies from config
    echo ""
    echo "${CYAN}Checking dependencies (lib/)...${RST}"
    local platform
    platform="$(_get_platform)"

    if [[ ! -f "${JSH_DEPS_CONFIG}" ]]; then
        prefix_warn "Dependencies config not found: ${JSH_DEPS_CONFIG}"
        ((issues++))
    elif ! has jq; then
        prefix_warn "jq required to check dependencies"
        ((issues++))
    else
        local dep_name dep_type submodule_path
        while IFS= read -r dep_name; do
            [[ -z "${dep_name}" ]] && continue
            dep_type=$(_get_dep_field "${dep_name}" "type")

            case "${dep_type}" in
                submodule-only)
                    submodule_path=$(_get_dep_field "${dep_name}" "submodule")
                    local full_path="${JSH_DIR}/${submodule_path}"
                    if [[ -d "${full_path}" ]] && [[ -n "$(ls -A "${full_path}" 2>/dev/null)" ]]; then
                        prefix_success "${dep_name} installed"
                    else
                        # p10k is required, others are optional
                        if [[ "${dep_name}" == "p10k" ]]; then
                            prefix_error "${dep_name} not installed (required)"
                            ((issues++))
                        else
                            prefix_info "${dep_name} not installed (optional)"
                        fi
                    fi
                    ;;
                build-from-source)
                    if [[ -x "${JSH_DIR}/lib/bin/${platform}/${dep_name}" ]]; then
                        local version
                        version=$("${JSH_DIR}/lib/bin/${platform}/${dep_name}" --version 2>/dev/null | head -1 | cut -d' ' -f1)
                        prefix_success "${dep_name} ${version} bundled (${platform})"
                    else
                        # fzf is important for shell functionality
                        if [[ "${dep_name}" == "fzf" ]]; then
                            prefix_warn "${dep_name} not bundled for ${platform}"
                            ((issues++))
                        else
                            prefix_info "${dep_name} not bundled for ${platform} (optional)"
                        fi
                    fi
                    ;;
                download-release)
                    if [[ -x "${JSH_DIR}/lib/bin/${platform}/${dep_name}" ]]; then
                        prefix_success "${dep_name} bundled (${platform})"
                    else
                        prefix_info "${dep_name} not bundled for ${platform} (optional)"
                    fi
                    ;;
            esac
        done < <(_get_deps)
    fi

    # Check for broken symlinks
    echo ""
    echo "${CYAN}Checking for broken symlinks...${RST}"
    local broken_links=()

    # Check JSH directory (deeper search for lib, core, config)
    while IFS= read -r link; do
        [[ -n "${link}" ]] && broken_links+=("${link}")
    done < <(_find_broken_symlinks "${JSH_DIR}" 3)

    # Check home directory dotfiles (shallow search)
    while IFS= read -r link; do
        [[ -n "${link}" ]] && broken_links+=("${link}")
    done < <(_find_broken_symlinks "${HOME}" 1)

    # Check XDG config directory
    local xdg_config="${XDG_CONFIG_HOME:-${HOME}/.config}"
    while IFS= read -r link; do
        [[ -n "${link}" ]] && broken_links+=("${link}")
    done < <(_find_broken_symlinks "${xdg_config}" 2)

    if [[ ${#broken_links[@]} -eq 0 ]]; then
        prefix_success "No broken symlinks found"
    else
        for link in "${broken_links[@]}"; do
            local target
            target=$(readlink "${link}" 2>/dev/null || echo "unknown")
            if [[ "${fix_issues}" == true ]]; then
                rm -f "${link}"
                prefix_success "Fixed: ${link} -> ${target}"
            else
                prefix_error "Broken: ${link} -> ${target}"
                ((issues++))
            fi
        done

        if [[ "${fix_issues}" != true ]] && [[ ${#broken_links[@]} -gt 0 ]]; then
            echo ""
            info "Run ${CYAN}jsh doctor --fix${RST} to remove broken symlinks"
        fi
    fi

    # Summary
    echo ""
    if [[ "${issues}" -eq 0 ]]; then
        prefix_success "No issues found!"
    else
        prefix_warn "${issues} issue(s) found"
    fi
}

cmd_dotfiles() {
    local action="${1:-status}"
    shift || true

    case "${action}" in
        link)
            _dotfiles_link
            ;;
        unlink)
            _dotfiles_unlink
            ;;
        restore)
            _dotfiles_restore "$@"
            ;;
        status|*)
            _dotfiles_status
            ;;
    esac
}

_dotfiles_link() {
    local backup_dir
    backup_dir="${HOME}/.jsh_backup/$(date +%Y%m%d_%H%M%S)"

    # Define dotfiles to link (target:source pairs)
    local files=(
        # Shell configs
        ".zshrc:core/.zshrc"
        ".bashrc:core/.bashrc"
        # Git
        ".gitconfig:core/gitconfig"
        ".gitignore_global:core/gitignore_global"
        # Terminal
        ".tmux.conf:core/tmux.conf"
        ".inputrc:core/inputrc"
        # Linting/Formatting (global defaults)
        ".editorconfig:core/.editorconfig"
        ".shellcheckrc:core/.shellcheckrc"
        ".yamllint:core/.yamllint"
        ".markdownlint.json:core/.markdownlint.json"
        ".prettierrc.json:core/.prettierrc.json"
        ".eslintrc.json:core/.eslintrc.json"
        ".pylintrc:core/.pylintrc"
        ".czrc:core/.czrc"
    )

    # XDG config directories (core/.config/*)
    local xdg_config="${XDG_CONFIG_HOME:-${HOME}/.config}"
    mkdir -p "${xdg_config}"

    if [[ -d "${JSH_DIR}/core/.config" ]]; then
        for config_dir in "${JSH_DIR}/core/.config"/*; do
            [[ -d "${config_dir}" ]] || continue
            local config_name
            config_name=$(basename "${config_dir}")
            local dest="${xdg_config}/${config_name}"

            if [[ -L "${dest}" ]]; then
                local current
                current=$(readlink "${dest}")
                if [[ "${current}" == "${config_dir}" ]]; then
                    prefix_info "${config_name} config already linked"
                    continue
                fi
                rm "${dest}"
            elif [[ -d "${dest}" ]]; then
                mkdir -p "${backup_dir}"
                mv "${dest}" "${backup_dir}/"
                prefix_info "Backed up ${config_name} config to ${backup_dir}/"
            fi

            ln -s "${config_dir}" "${dest}"
            prefix_success "Linked ${config_name} config"
        done
    fi

    # VSCode config (platform-specific)
    local vscode_user_dir
    case "$(uname -s)" in
        Darwin) vscode_user_dir="${HOME}/Library/Application Support/Code/User" ;;
        *)      vscode_user_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User" ;;
    esac

    if [[ -d "$(dirname "${vscode_user_dir}")" ]] || [[ "$(uname -s)" == "Darwin" ]]; then
        mkdir -p "${vscode_user_dir}"
        for vscode_file in settings.json keybindings.json; do
            local vscode_src="${JSH_DIR}/config/vscode/${vscode_file}"
            local vscode_dest="${vscode_user_dir}/${vscode_file}"

            if [[ ! -f "${vscode_src}" ]]; then
                continue
            fi

            if [[ -L "${vscode_dest}" ]]; then
                local current
                current=$(readlink "${vscode_dest}")
                if [[ "${current}" == "${vscode_src}" ]]; then
                    prefix_info "vscode/${vscode_file} already linked"
                    continue
                fi
                rm "${vscode_dest}"
            elif [[ -f "${vscode_dest}" ]]; then
                mkdir -p "${backup_dir}"
                mv "${vscode_dest}" "${backup_dir}/"
                prefix_info "Backed up vscode/${vscode_file} to ${backup_dir}/"
            fi

            ln -s "${vscode_src}" "${vscode_dest}"
            prefix_success "Linked vscode/${vscode_file}"
        done
    fi

    for entry in "${files[@]}"; do
        local target="${entry%%:*}"
        local source_path="${entry#*:}"
        local source="${JSH_DIR}/${source_path}"
        local dest="${HOME}/${target}"

        if [[ ! -f "${source}" ]]; then
            prefix_warn "Source not found: ${source}"
            continue
        fi

        if [[ -L "${dest}" ]]; then
            # Already a symlink
            local current
            current=$(readlink "${dest}")
            if [[ "${current}" == "${source}" ]]; then
                prefix_info "${target} already linked"
                continue
            fi
            rm "${dest}"
        elif [[ -f "${dest}" ]]; then
            # Backup existing file
            mkdir -p "${backup_dir}"
            mv "${dest}" "${backup_dir}/"
            prefix_info "Backed up ${target} to ${backup_dir}/"
        fi

        ln -s "${source}" "${dest}"
        prefix_success "Linked ${target}"
    done

    # Private dotfiles (private/ directory - synced via Syncthing, never committed)
    # Structure mirrors $HOME (e.g., private/.config/foo -> ~/.config/foo)
    local private_dir="${JSH_DIR}/private"
    if [[ -d "${private_dir}" ]]; then
        _link_private_dotfiles "${private_dir}" "${HOME}" "${backup_dir}"
    fi

    # Root-level dotfiles (adopted from outside $HOME via jsh adopt)
    # Structure: core/_root/etc/hosts -> /etc/hosts (requires sudo)
    _link_root_dotfiles "${backup_dir}"
}

# Link files from _root/ directories (paths outside $HOME)
# These were adopted via 'jsh adopt /etc/something' and need sudo to link
# Args: $1 = backup directory
_link_root_dotfiles() {
    local backup_dir="$1"
    local root_paths=()

    # Collect all _root paths from core and private
    for base_dir in "${JSH_DIR}/core/_root" "${JSH_DIR}/private/_root"; do
        [[ -d "${base_dir}" ]] || continue

        while IFS= read -r item; do
            [[ -n "${item}" ]] && root_paths+=("${base_dir}:${item}")
        done < <(find "${base_dir}" -mindepth 1 \( -type f -o -type l \) 2>/dev/null)
    done

    [[ ${#root_paths[@]} -eq 0 ]] && return

    # Check if any need linking
    local needs_linking=()
    for entry in "${root_paths[@]}"; do
        local base_dir="${entry%%:*}"
        local item="${entry#*:}"
        local relative="${item#"${base_dir}"}"
        local dest="${relative}"

        if [[ -L "${dest}" ]]; then
            local current
            current=$(readlink "${dest}")
            [[ "${current}" == "${item}" ]] && continue
        fi
        needs_linking+=("${entry}")
    done

    [[ ${#needs_linking[@]} -eq 0 ]] && return

    echo ""
    echo "${CYAN}Root-level dotfiles (outside \$HOME):${RST}"
    info "The following paths need sudo to link:"
    for entry in "${needs_linking[@]}"; do
        local base_dir="${entry%%:*}"
        local item="${entry#*:}"
        local relative="${item#"${base_dir}"}"
        echo "  ${relative}"
    done
    echo ""

    # Single sudo prompt for all root symlinks
    if ! sudo -v; then
        prefix_warn "Skipping root-level dotfiles (sudo required)"
        return
    fi

    for entry in "${needs_linking[@]}"; do
        local base_dir="${entry%%:*}"
        local item="${entry#*:}"
        local relative="${item#"${base_dir}"}"
        local dest="${relative}"
        local dest_parent
        dest_parent=$(dirname "${dest}")

        # Create parent directory if needed
        if [[ ! -d "${dest_parent}" ]]; then
            sudo mkdir -p "${dest_parent}"
        fi

        if [[ -L "${dest}" ]]; then
            sudo rm "${dest}"
        elif [[ -e "${dest}" ]]; then
            # Backup existing file
            mkdir -p "${backup_dir}"
            sudo mv "${dest}" "${backup_dir}/"
            prefix_info "Backed up ${relative} to ${backup_dir}/"
        fi

        if sudo ln -s "${item}" "${dest}"; then
            prefix_success "Linked ${relative} (root)"
        else
            prefix_error "Failed to link ${relative}"
        fi
    done
}

# Recursively link private dotfiles from source directory to destination
# Args: $1 = source directory, $2 = destination directory, $3 = backup directory
_link_private_dotfiles() {
    local src_dir="$1"
    local dest_dir="$2"
    local backup_dir="$3"

    for item in "${src_dir}"/* "${src_dir}"/.*; do
        # Skip . and .. and non-existent globs
        [[ ! -e "${item}" ]] && continue
        local name
        name=$(basename "${item}")
        [[ "${name}" == "." || "${name}" == ".." ]] && continue

        local dest="${dest_dir}/${name}"

        if [[ -d "${item}" ]]; then
            # It's a directory - recurse into it
            # Create parent directory if needed
            mkdir -p "${dest_dir}"

            if [[ -L "${dest}" ]]; then
                # Already a symlink - check if it points to jsh
                local current
                current=$(readlink "${dest}")
                if [[ "${current}" == "${item}" ]]; then
                    prefix_info "${name} (private) already linked"
                    continue
                fi
                rm "${dest}"
            elif [[ -d "${dest}" ]]; then
                # Existing directory - recurse into it (don't replace entire dir)
                _link_private_dotfiles "${item}" "${dest}" "${backup_dir}"
                continue
            fi

            # Link the entire directory
            ln -s "${item}" "${dest}"
            prefix_success "Linked ${name} (private)"
        elif [[ -f "${item}" ]]; then
            # It's a file - link it
            mkdir -p "${dest_dir}"

            if [[ -L "${dest}" ]]; then
                local current
                current=$(readlink "${dest}")
                if [[ "${current}" == "${item}" ]]; then
                    prefix_info "${name} (private) already linked"
                    continue
                fi
                rm "${dest}"
            elif [[ -f "${dest}" ]]; then
                # Backup existing file
                mkdir -p "${backup_dir}"
                local relative_path="${dest#"${HOME}"/}"
                local backup_subdir
                backup_subdir=$(dirname "${backup_dir}/${relative_path}")
                mkdir -p "${backup_subdir}"
                mv "${dest}" "${backup_dir}/${relative_path}"
                prefix_info "Backed up ${relative_path} to ${backup_dir}/"
            fi

            ln -s "${item}" "${dest}"
            local relative="${dest#"${HOME}"/}"
            prefix_success "Linked ${relative} (private)"
        fi
    done
}

_dotfiles_unlink() {
    local dotfiles=(
        ".zshrc" ".bashrc"
        ".gitconfig" ".gitignore_global"
        ".tmux.conf" ".inputrc"
        ".editorconfig" ".shellcheckrc" ".yamllint"
        ".markdownlint.json" ".prettierrc.json" ".eslintrc.json"
        ".pylintrc" ".czrc"
    )

    for target in "${dotfiles[@]}"; do
        local dest="${HOME}/${target}"

        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                rm "${dest}"
                prefix_success "Unlinked ${target}"
            fi
        fi
    done

    # XDG config directories
    local xdg_config="${XDG_CONFIG_HOME:-${HOME}/.config}"
    if [[ -d "${JSH_DIR}/core/.config" ]]; then
        for config_dir in "${JSH_DIR}/core/.config"/*; do
            [[ -d "${config_dir}" ]] || continue
            local config_name
            config_name=$(basename "${config_dir}")
            local dest="${xdg_config}/${config_name}"

            if [[ -L "${dest}" ]]; then
                local link_target
                link_target=$(readlink "${dest}")
                if [[ "${link_target}" == *"jsh"* ]]; then
                    rm "${dest}"
                    prefix_success "Unlinked ${config_name} config"
                fi
            fi
        done
    fi

    # VSCode config
    local vscode_user_dir
    case "$(uname -s)" in
        Darwin) vscode_user_dir="${HOME}/Library/Application Support/Code/User" ;;
        *)      vscode_user_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User" ;;
    esac

    for vscode_file in settings.json keybindings.json; do
        local vscode_dest="${vscode_user_dir}/${vscode_file}"
        if [[ -L "${vscode_dest}" ]]; then
            local link_target
            link_target=$(readlink "${vscode_dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                rm "${vscode_dest}"
                prefix_success "Unlinked vscode/${vscode_file}"
            fi
        fi
    done

    # Private dotfiles
    local private_dir="${JSH_DIR}/private"
    if [[ -d "${private_dir}" ]]; then
        _unlink_private_dotfiles "${private_dir}" "${HOME}"
    fi
}

# Recursively unlink private dotfiles
# Args: $1 = source directory (in jsh), $2 = destination directory
_unlink_private_dotfiles() {
    local src_dir="$1"
    local dest_dir="$2"

    for item in "${src_dir}"/* "${src_dir}"/.*; do
        [[ ! -e "${item}" ]] && continue
        local name
        name=$(basename "${item}")
        [[ "${name}" == "." || "${name}" == ".." ]] && continue

        local dest="${dest_dir}/${name}"

        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                rm "${dest}"
                local relative="${dest#"${HOME}"/}"
                prefix_success "Unlinked ${relative} (private)"
            fi
        elif [[ -d "${dest}" ]] && [[ -d "${item}" ]]; then
            # Recurse into directory if both exist
            _unlink_private_dotfiles "${item}" "${dest}"
        fi
    done
}

_dotfiles_status() {
    echo "${BOLD}Dotfile Status${RST}"
    echo ""

    # Check each dotfile
    local files=(
        ".zshrc:core/.zshrc"
        ".bashrc:core/.bashrc"
        ".gitconfig:core/gitconfig"
        ".gitignore_global:core/gitignore_global"
        ".tmux.conf:core/tmux.conf"
        ".inputrc:core/inputrc"
        ".editorconfig:core/.editorconfig"
        ".shellcheckrc:core/.shellcheckrc"
        ".yamllint:core/.yamllint"
        ".markdownlint.json:core/.markdownlint.json"
        ".prettierrc.json:core/.prettierrc.json"
        ".eslintrc.json:core/.eslintrc.json"
        ".pylintrc:core/.pylintrc"
        ".czrc:core/.czrc"
    )

    for entry in "${files[@]}"; do
        local target="${entry%%:*}"
        local dest="${HOME}/${target}"

        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                echo "${GREEN}✔${RST} ${target} -> ${link_target}"
            else
                echo "${YELLOW}~${RST} ${target} -> ${link_target}"
            fi
        elif [[ -f "${dest}" ]]; then
            echo "${YELLOW}~${RST} ${target} (exists, not linked)"
        else
            echo "${DIM}-${RST} ${target}"
        fi
    done

    # XDG config directories
    local xdg_config="${XDG_CONFIG_HOME:-${HOME}/.config}"
    if [[ -d "${JSH_DIR}/core/.config" ]]; then
        for config_dir in "${JSH_DIR}/core/.config"/*; do
            [[ -d "${config_dir}" ]] || continue
            local config_name
            config_name=$(basename "${config_dir}")
            local dest="${xdg_config}/${config_name}"

            if [[ -L "${dest}" ]]; then
                local link_target
                link_target=$(readlink "${dest}")
                if [[ "${link_target}" == *"jsh"* ]]; then
                    echo "${GREEN}✔${RST} ${config_name} -> ${link_target}"
                else
                    echo "${YELLOW}~${RST} ${config_name} -> ${link_target}"
                fi
            elif [[ -d "${dest}" ]]; then
                echo "${YELLOW}~${RST} ${config_name} (exists, not linked)"
            else
                echo "${DIM}-${RST} ${config_name}"
            fi
        done
    fi

    # VSCode config
    local vscode_user_dir
    case "$(uname -s)" in
        Darwin) vscode_user_dir="${HOME}/Library/Application Support/Code/User" ;;
        *)      vscode_user_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/Code/User" ;;
    esac

    for vscode_file in settings.json keybindings.json; do
        local vscode_dest="${vscode_user_dir}/${vscode_file}"
        if [[ -L "${vscode_dest}" ]]; then
            local link_target
            link_target=$(readlink "${vscode_dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                echo "${GREEN}✔${RST} vscode/${vscode_file} -> ${link_target}"
            else
                echo "${YELLOW}~${RST} vscode/${vscode_file} -> ${link_target}"
            fi
        elif [[ -f "${vscode_dest}" ]]; then
            echo "${YELLOW}~${RST} vscode/${vscode_file} (exists, not linked)"
        else
            echo "${DIM}-${RST} vscode/${vscode_file}"
        fi
    done

    # Private dotfiles
    local private_dir="${JSH_DIR}/private"
    if [[ -d "${private_dir}" ]]; then
        echo ""
        echo "${CYAN}Private Dotfiles:${RST}"
        _status_private_dotfiles "${private_dir}" "${HOME}" ""
    fi
}

# Recursively show status of private dotfiles
# Args: $1 = source directory (in jsh), $2 = destination directory, $3 = prefix for display
_status_private_dotfiles() {
    local src_dir="$1"
    local dest_dir="$2"
    local prefix="$3"

    for item in "${src_dir}"/* "${src_dir}"/.*; do
        [[ ! -e "${item}" ]] && continue
        local name
        name=$(basename "${item}")
        [[ "${name}" == "." || "${name}" == ".." ]] && continue

        local dest="${dest_dir}/${name}"
        local display_name="${prefix}${name}"

        if [[ -d "${item}" ]]; then
            if [[ -L "${dest}" ]]; then
                local link_target
                link_target=$(readlink "${dest}")
                if [[ "${link_target}" == *"jsh"* ]]; then
                    echo "${GREEN}✔${RST} ${display_name}/ -> ${link_target}"
                else
                    echo "${YELLOW}~${RST} ${display_name}/ -> ${link_target}"
                fi
            elif [[ -d "${dest}" ]]; then
                # Recurse into existing directory
                _status_private_dotfiles "${item}" "${dest}" "${display_name}/"
            else
                echo "${DIM}-${RST} ${display_name}/"
            fi
        elif [[ -f "${item}" ]]; then
            if [[ -L "${dest}" ]]; then
                local link_target
                link_target=$(readlink "${dest}")
                if [[ "${link_target}" == *"jsh"* ]]; then
                    echo "${GREEN}✔${RST} ${display_name} -> ${link_target}"
                else
                    echo "${YELLOW}~${RST} ${display_name} -> ${link_target}"
                fi
            elif [[ -f "${dest}" ]]; then
                echo "${YELLOW}~${RST} ${display_name} (exists, not linked)"
            else
                echo "${DIM}-${RST} ${display_name}"
            fi
        fi
    done
}

_dotfiles_restore() {
    local backup_base="${HOME}/.jsh_backup"
    local selected_backup="${1:-}"

    # Check if backup directory exists
    if [[ ! -d "${backup_base}" ]]; then
        warn "No backups found at ${backup_base}"
        return 1
    fi

    # Get list of backups (sorted newest first)
    local backups=()
    while IFS= read -r dir; do
        [[ -d "${dir}" ]] && backups+=("$(basename "${dir}")")
    done < <(find "${backup_base}" -mindepth 1 -maxdepth 1 -type d | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        warn "No backups found in ${backup_base}"
        return 1
    fi

    # If no backup specified, show available backups
    if [[ -z "${selected_backup}" ]]; then
        echo "${BOLD}Available Backups${RST}"
        echo ""
        for i in "${!backups[@]}"; do
            local backup="${backups[${i}]}"
            local backup_path="${backup_base}/${backup}"
            local file_count
            file_count=$(find "${backup_path}" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [[ ${i} -eq 0 ]]; then
                echo "  ${CYAN}${backup}${RST} (${file_count} files) ${GREEN}[latest]${RST}"
            else
                echo "  ${backup} (${file_count} files)"
            fi
        done
        echo ""
        echo "Usage: ${CYAN}jsh dotfiles restore <backup_name>${RST}"
        echo "       ${CYAN}jsh dotfiles restore latest${RST}"
        return 0
    fi

    # Handle "latest" keyword
    if [[ "${selected_backup}" == "latest" ]]; then
        selected_backup="${backups[0]}"
    fi

    local backup_path="${backup_base}/${selected_backup}"

    # Validate backup exists
    if [[ ! -d "${backup_path}" ]]; then
        error "Backup not found: ${selected_backup}"
        echo ""
        echo "Available backups:"
        printf '  %s\n' "${backups[@]}"
        return 1
    fi

    info "Restoring from backup: ${selected_backup}"

    # First, unlink any jsh symlinks for files we're about to restore
    local restored=0
    while IFS= read -r backup_file; do
        local filename
        filename=$(basename "${backup_file}")
        local relative_path="${backup_file#"${backup_path}"/}"
        local dest

        # Determine destination based on file type
        if [[ "${relative_path}" == "nvim" ]] || [[ "${relative_path}" == nvim/* ]]; then
            # Nvim config goes to XDG location
            if [[ "${relative_path}" == "nvim" ]]; then
                dest="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim"
            else
                continue  # Skip files inside nvim dir, we restore the whole dir
            fi
        else
            dest="${HOME}/${filename}"
        fi

        # Remove existing symlink if it points to jsh
        if [[ -L "${dest}" ]]; then
            local link_target
            link_target=$(readlink "${dest}")
            if [[ "${link_target}" == *"jsh"* ]]; then
                rm "${dest}"
                prefix_info "Removed symlink: ${dest}"
            else
                prefix_warn "Skipping ${filename}: symlink points to non-jsh location"
                continue
            fi
        elif [[ -e "${dest}" ]]; then
            prefix_warn "Skipping ${filename}: destination exists and is not a jsh symlink"
            continue
        fi

        # Restore the file/directory
        if [[ -d "${backup_file}" ]]; then
            cp -R "${backup_file}" "${dest}"
        else
            cp "${backup_file}" "${dest}"
        fi
        prefix_success "Restored ${relative_path}"
        ((restored++))
    done < <(find "${backup_path}" -mindepth 1 -maxdepth 1)

    if [[ ${restored} -eq 0 ]]; then
        prefix_warn "No files were restored"
    else
        prefix_success "Restored ${restored} file(s) from ${selected_backup}"
    fi
}

cmd_reload() {
    info "Reloading shell..."
    exec "${SHELL}"
}

cmd_edit() {
    local file="${1:-}"
    local editor="${EDITOR:-vim}"

    case "${file}" in
        zsh|zshrc)
            ${editor} "${JSH_DIR}/src/zsh.sh"
            ;;
        bash|bashrc)
            ${editor} "${JSH_DIR}/src/bash.sh"
            ;;
        aliases)
            ${editor} "${JSH_DIR}/src/aliases.sh"
            ;;
        functions)
            ${editor} "${JSH_DIR}/src/functions.sh"
            ;;
        p10k|prompt)
            ${editor} "${JSH_DIR}/core/p10k.zsh"
            ;;
        tmux)
            ${editor} "${JSH_DIR}/core/tmux.conf"
            ;;
        git|gitconfig)
            ${editor} "${JSH_DIR}/core/gitconfig"
            ;;
        nvim|neovim)
            ${editor} "${JSH_DIR}/core/.config/nvim/init.lua"
            ;;
        vscode|code)
            ${editor} "${JSH_DIR}/config/vscode/settings.json"
            ;;
        local)
            ${editor} "${HOME}/.jshrc.local"
            ;;
        "")
            ${editor} "${JSH_DIR}"
            ;;
        *)
            if [[ -f "${JSH_DIR}/${file}" ]]; then
                ${editor} "${JSH_DIR}/${file}"
            else
                die "Unknown config: ${file}"
            fi
            ;;
    esac
}

cmd_ssh() {
    # Pass through to jssh
    exec "${JSH_DIR}/bin/jssh" "$@"
}

# =============================================================================
# Adopt Command - Move files/dirs into jsh management
# =============================================================================

cmd_adopt() {
    local use_private=false
    local skip_symlinks=false
    local follow_symlinks=false
    local dry_run=false
    local skip_confirm=false
    local paths=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--private)
                use_private=true
                shift
                ;;
            --skip-symlinks)
                skip_symlinks=true
                shift
                ;;
            --follow-symlinks)
                follow_symlinks=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            -h|--help)
                _adopt_help
                return 0
                ;;
            -*)
                warn "Unknown option: $1"
                shift
                ;;
            *)
                paths+=("$1")
                shift
                ;;
        esac
    done

    # Show help if no paths provided
    if [[ ${#paths[@]} -eq 0 ]]; then
        _adopt_help
        return 0
    fi

    local target_dir
    if [[ "${use_private}" == true ]]; then
        target_dir="${JSH_DIR}/private"
    else
        target_dir="${JSH_DIR}/core"
    fi

    # Process each path
    local adopted=0
    local skipped=0
    local failed=0

    for path in "${paths[@]}"; do
        if _adopt_single_path "${path}" "${target_dir}" "${dry_run}" "${skip_confirm}" "${skip_symlinks}" "${follow_symlinks}"; then
            ((adopted++))
        else
            local exit_code=$?
            if [[ ${exit_code} -eq 2 ]]; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
    done

    # Summary
    echo ""
    if [[ "${dry_run}" == true ]]; then
        info "Dry run complete. No changes made."
    else
        if [[ ${failed} -eq 0 ]] && [[ ${skipped} -eq 0 ]]; then
            prefix_success "Adopted ${adopted} path(s)"
        else
            echo "Adopted: ${adopted}, Skipped: ${skipped}, Failed: ${failed}"
        fi
    fi
}

_adopt_help() {
    cat << 'HELP'
Usage: jsh adopt [options] <path> [<path>...]

Move files or directories into jsh management and create symlinks.

Options:
  -p, --private       Adopt to private/ instead of core/
  --skip-symlinks     Skip paths that are symlinks (non-interactive)
  --follow-symlinks   Follow symlinks to adopt their targets (non-interactive)
  --dry-run           Show what would be done without making changes
  -y, --yes           Skip confirmation prompts
  -h, --help          Show this help

Examples:
  jsh adopt ~/.config/myapp       # Adopt config directory
  jsh adopt -p ~/.ssh/config      # Adopt to private/ (for sensitive files)
  jsh adopt ~/.config/a ~/.config/b  # Adopt multiple paths
  jsh adopt --dry-run ~/.bashrc   # Preview what would happen

Path handling:
  ~/.config/test    → core/.config/test (relative to $HOME)
  /etc/hosts        → core/_root/etc/hosts (outside $HOME, requires sudo)

After adopting, run 'jsh dotfiles link' on other machines to create symlinks.
HELP
}

# Adopt a single path into jsh management
# Args: $1=path, $2=target_dir, $3=dry_run, $4=skip_confirm, $5=skip_symlinks, $6=follow_symlinks
# Returns: 0=success, 1=error, 2=skipped
_adopt_single_path() {
    local input_path="$1"
    local target_dir="$2"
    local dry_run="$3"
    local skip_confirm="$4"
    local skip_symlinks="$5"
    local follow_symlinks="$6"

    # Resolve to absolute path
    local abs_path
    if [[ "${input_path}" == /* ]]; then
        abs_path="${input_path}"
    elif [[ "${input_path}" == ~* ]]; then
        abs_path="${input_path/#\~/${HOME}}"
    else
        abs_path="$(cd "$(dirname "${input_path}")" 2>/dev/null && pwd)/$(basename "${input_path}")"
    fi

    # Remove trailing slash
    abs_path="${abs_path%/}"

    # Check if path exists
    if [[ ! -e "${abs_path}" ]] && [[ ! -L "${abs_path}" ]]; then
        prefix_error "Path does not exist: ${abs_path}"
        return 1
    fi

    # Check if already inside jsh (use trailing slash to avoid matching .jsh-like dirs)
    if [[ "${abs_path}" == "${JSH_DIR}/"* ]] || [[ "${abs_path}" == "${JSH_DIR}" ]]; then
        prefix_error "Path is already inside jsh: ${abs_path}"
        return 1
    fi

    # Handle symlinks
    if [[ -L "${abs_path}" ]]; then
        local link_target
        link_target=$(readlink "${abs_path}")

        if [[ "${skip_symlinks}" == true ]]; then
            prefix_info "Skipping symlink: ${abs_path}"
            return 2
        elif [[ "${follow_symlinks}" == true ]]; then
            # Resolve to absolute path of target
            if [[ "${link_target}" == /* ]]; then
                abs_path="${link_target}"
            else
                abs_path="$(cd "$(dirname "${abs_path}")" && cd "$(dirname "${link_target}")" && pwd)/$(basename "${link_target}")"
            fi
            info "Following symlink to: ${abs_path}"
        else
            # Interactive prompt
            local action
            action=$(_prompt_symlink_action "${abs_path}" "${link_target}")
            case "${action}" in
                skip)
                    prefix_info "Skipped: ${abs_path}"
                    return 2
                    ;;
                follow)
                    if [[ "${link_target}" == /* ]]; then
                        abs_path="${link_target}"
                    else
                        abs_path="$(cd "$(dirname "${abs_path}")" && cd "$(dirname "${link_target}")" && pwd)/$(basename "${link_target}")"
                    fi
                    info "Following symlink to: ${abs_path}"
                    ;;
                replace)
                    # Will adopt target, original symlink location becomes the symlink
                    # The symlink itself will be removed and recreated pointing to jsh
                    local original_symlink="${abs_path}"
                    if [[ "${link_target}" == /* ]]; then
                        abs_path="${link_target}"
                    else
                        abs_path="$(cd "$(dirname "${abs_path}")" && cd "$(dirname "${link_target}")" && pwd)/$(basename "${link_target}")"
                    fi
                    # Remove the original symlink first
                    if [[ "${dry_run}" != true ]]; then
                        rm "${original_symlink}"
                    fi
                    info "Will replace symlink at: ${original_symlink}"
                    ;;
                as-is)
                    # Adopt the symlink itself
                    info "Adopting symlink as-is"
                    ;;
                *)
                    prefix_info "Skipped: ${abs_path}"
                    return 2
                    ;;
            esac
        fi
    fi

    # Calculate relative path from HOME or use _root prefix
    local relative_path
    local symlink_needs_sudo=false

    if [[ "${abs_path}" == "${HOME}"* ]]; then
        relative_path="${abs_path#"${HOME}"/}"
    else
        symlink_needs_sudo=true
        relative_path="_root${abs_path}"

        if [[ "${skip_confirm}" != true ]]; then
            echo ""
            warn "Path is outside \$HOME: ${abs_path}"
            echo "  Will be stored at: ${target_dir}/${relative_path}"
            echo "  Symlink will require sudo to create"
            echo ""
            read -r -p "Proceed? [y/N] " confirm
            if [[ "${confirm}" != [yY]* ]]; then
                prefix_info "Skipped: ${abs_path}"
                return 2
            fi
        fi
    fi

    local dest_path="${target_dir}/${relative_path}"

    # Check if destination already exists
    if [[ -e "${dest_path}" ]]; then
        prefix_error "Destination already exists: ${dest_path}"
        return 1
    fi

    # Check write permissions
    local source_parent
    source_parent=$(dirname "${abs_path}")
    if [[ ! -w "${source_parent}" ]] && [[ "${symlink_needs_sudo}" != true ]]; then
        prefix_error "No write permission on: ${source_parent}"
        return 1
    fi

    # Show what we're doing
    local target_name
    if [[ "${target_dir}" == *"/private" ]]; then
        target_name="private"
    else
        target_name="core"
    fi

    echo ""
    info "Adopting: ${abs_path}"
    echo "  → ${target_name}/${relative_path}"

    if [[ "${dry_run}" == true ]]; then
        prefix_info "[dry-run] Would move to: ${dest_path}"
        prefix_info "[dry-run] Would create symlink: ${abs_path} → ${dest_path}"
        return 0
    fi

    # Create destination parent directories
    local dest_parent
    dest_parent=$(dirname "${dest_path}")
    if [[ ! -d "${dest_parent}" ]]; then
        # Check if parent directory is protected (schg flag on macOS)
        local needs_unprotect=false
        local protect_dir=""

        if is_macos; then
            # Check if any parent in the path has schg flag
            local check_dir="${dest_parent}"
            while [[ "${check_dir}" != "/" ]] && [[ "${check_dir}" != "${JSH_DIR}" ]]; do
                if [[ -d "${check_dir}" ]]; then
                    # Use stat -f %Sf to get file flags directly (avoids ls|grep)
                    if [[ "$(stat -f %Sf "${check_dir}" 2>/dev/null)" == *schg* ]]; then
                        needs_unprotect=true
                        protect_dir="${check_dir}"
                        break
                    fi
                fi
                check_dir=$(dirname "${check_dir}")
            done
        fi

        if [[ "${needs_unprotect}" == true ]]; then
            info "Directory ${protect_dir} is protected (schg flag)"
            info "Temporarily removing protection to create subdirectory..."
            if ! sudo chflags noschg "${protect_dir}"; then
                prefix_error "Failed to unprotect directory: ${protect_dir}"
                return 1
            fi
            # Create the directory
            if mkdir -p "${dest_parent}"; then
                # Restore protection
                sudo chflags schg "${protect_dir}"
            else
                sudo chflags schg "${protect_dir}"
                prefix_error "Failed to create directory: ${dest_parent}"
                return 1
            fi
        else
            mkdir -p "${dest_parent}" || {
                prefix_error "Failed to create directory: ${dest_parent}"
                return 1
            }
        fi
    fi

    # Move the file/directory (may need to unprotect destination dir)
    local move_needs_unprotect=false
    local move_protect_dir=""

    if is_macos && [[ -d "${dest_parent}" ]]; then
        # Use stat -f %Sf to get file flags directly (avoids ls|grep)
        if [[ "$(stat -f %Sf "${dest_parent}" 2>/dev/null)" == *schg* ]]; then
            move_needs_unprotect=true
            move_protect_dir="${dest_parent}"
        fi
    fi

    if [[ "${move_needs_unprotect}" == true ]]; then
        sudo chflags noschg "${move_protect_dir}"
        if mv "${abs_path}" "${dest_path}"; then
            sudo chflags schg "${move_protect_dir}"
        else
            sudo chflags schg "${move_protect_dir}"
            prefix_error "Failed to move: ${abs_path}"
            return 1
        fi
    else
        if ! mv "${abs_path}" "${dest_path}"; then
            prefix_error "Failed to move: ${abs_path}"
            return 1
        fi
    fi

    # Create the symlink
    if [[ "${symlink_needs_sudo}" == true ]]; then
        if ! sudo ln -s "${dest_path}" "${abs_path}"; then
            # Rollback: move file back
            mv "${dest_path}" "${abs_path}"
            prefix_error "Failed to create symlink (sudo required): ${abs_path}"
            return 1
        fi
    else
        if ! ln -s "${dest_path}" "${abs_path}"; then
            # Rollback: move file back
            mv "${dest_path}" "${abs_path}"
            prefix_error "Failed to create symlink: ${abs_path}"
            return 1
        fi
    fi

    prefix_success "Adopted: ${abs_path}"
    return 0
}

# Prompt user for symlink handling action
# Args: $1=symlink_path, $2=link_target
# Outputs: action (skip, follow, replace, as-is)
_prompt_symlink_action() {
    local symlink_path="$1"
    local link_target="$2"

    echo ""
    echo "${YELLOW}${symlink_path}${RST} is a symlink → ${link_target}"
    echo "What would you like to do?"
    echo "  [s]kip     - Don't adopt this path"
    echo "  [f]ollow   - Adopt the target (${link_target}) instead"
    echo "  [r]eplace  - Move target to jsh, update symlink to point to jsh"
    echo "  [a]s-is    - Adopt the symlink itself (preserves symlink in jsh)"
    echo ""
    read -r -p "> " choice

    case "${choice}" in
        s|S|skip)    echo "skip" ;;
        f|F|follow)  echo "follow" ;;
        r|R|replace) echo "replace" ;;
        a|A|as-is)   echo "as-is" ;;
        *)           echo "skip" ;;
    esac
}

cmd_local() {
    local editor="${EDITOR:-vim}"
    local local_file="${HOME}/.jshrc.local"

    # Create the file if it doesn't exist
    if [[ ! -f "${local_file}" ]]; then
        info "Creating ${local_file}..."
        cat > "${local_file}" << 'EOF'
# ~/.jshrc.local - Local shell customizations
# This file is sourced after jsh initialization
# Use this for machine-specific settings, secrets, or personal overrides

EOF
    fi

    # Get modification time before editing
    local mtime_before
    mtime_before=$(stat -f %m "${local_file}" 2>/dev/null || stat -c %Y "${local_file}" 2>/dev/null)

    ${editor} "${local_file}"

    # Check if file was modified
    local mtime_after
    mtime_after=$(stat -f %m "${local_file}" 2>/dev/null || stat -c %Y "${local_file}" 2>/dev/null)

    if [[ "${mtime_before}" != "${mtime_after}" ]]; then
        echo ""
        info "Run ${CYAN}jsh -r${RST} to reload your shell configuration"
    fi
}

cmd_bootstrap() {
    # Bootstrap installation (for curl pipe to bash scenario)
    # This clones the repo if needed, then runs install
    show_banner
    check_requirements

    # Clone or update
    if [[ -d "${JSH_DIR}" ]]; then
        if [[ -d "${JSH_DIR}/.git" ]]; then
            info "JSH already installed, updating..."
            git -C "${JSH_DIR}" pull --rebase || warn "Failed to pull updates"
        else
            die "${JSH_DIR} exists but is not a git repository"
        fi
    else
        info "Cloning JSH..."
        git clone --depth 1 --branch "${JSH_BRANCH}" "${JSH_REPO}" "${JSH_DIR}"
    fi

    # Initialize submodules
    info "Initializing submodules (p10k)..."
    git -C "${JSH_DIR}" submodule update --init --depth 1 || warn "Failed to init submodules"

    # Verify fzf is available
    _check_fzf

    # Setup protected private directory
    _setup_private_dir

    # Run install (dotfiles linking, local dir)
    info "Setting up dotfiles..."
    cmd_dotfiles link
    mkdir -p "${JSH_DIR}/local"

    success "JSH installed successfully!"
    show_next_steps
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Detect if running from stdin (curl pipe to bash)
    # In that case, default to bootstrap
    local cmd="${1:-}"

    # If no command and script is being piped, run bootstrap
    if [[ -z "${cmd}" ]]; then
        if [[ ! -t 0 ]] || [[ ! -d "${JSH_DIR}/.git" ]]; then
            # Running from pipe OR jsh not yet installed - bootstrap
            cmd_bootstrap
            return
        fi
        # Otherwise show help
        cmd_help
        return
    fi

    shift || true

    case "${cmd}" in
        -h|--help|help)
            cmd_help
            ;;
        -v|--version|version)
            cmd_version
            ;;
        -r|--reload)
            cmd_reload
            ;;
        # Setup/teardown commands (jsh environment)
        setup|init)
            cmd_setup "$@"
            ;;
        teardown|deinit)
            cmd_teardown "$@"
            ;;
        # Package commands
        install)
            cmd_install "$@"
            ;;
        uninstall)
            cmd_uninstall "$@"
            ;;
        update|upgrade)
            cmd_update "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        doctor|check)
            cmd_doctor "$@"
            ;;
        dotfiles|dots)
            cmd_dotfiles "$@"
            ;;
        adopt)
            cmd_adopt "$@"
            ;;
        reload)
            cmd_reload "$@"
            ;;
        edit)
            cmd_edit "$@"
            ;;
        local)
            cmd_local "$@"
            ;;
        ssh)
            cmd_ssh "$@"
            ;;
        bootstrap)
            cmd_bootstrap "$@"
            ;;
        *)
            error "Unknown command: ${cmd}"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
