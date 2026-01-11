#!/bin/bash
# jsh test container entrypoint
# Installs jsh and validates shell initialization + portable shell (jssh)

set -e

SHELL_CMD="${JSH_TEST_SHELL:-zsh}"
JSH_DIR="${HOME}/.jsh"
TEST_PORTABLE="${JSH_TEST_PORTABLE:-1}"

# Output helpers (matches src/core.sh style)
RST=$'\e[0m' GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' CYN=$'\e[36m' BLU=$'\e[34m'
print_info()    { echo "${CYN}$*${RST}"; }
print_success() { echo "${GRN}$*${RST}"; }
print_warn()    { echo "${YLW}$*${RST}" >&2; }
print_error()   { echo "${RED}$*${RST}" >&2; }
prefix_info()    { echo "${BLU}◆${RST} $*"; }
prefix_success() { echo "${GRN}✔${RST} $*"; }
prefix_warn()    { echo "${YLW}⚠${RST} $*" >&2; }
prefix_error()   { echo "${RED}✘${RST} $*" >&2; }

# Validate shell
case "${SHELL_CMD}" in
    bash|zsh)
        ;;
    *)
        print_error "Invalid shell '${SHELL_CMD}'. Use 'bash' or 'zsh'."
        exit 1
        ;;
esac

# Install jsh if not already installed
if [[ ! -f "${JSH_DIR}/jsh" ]]; then
    print_error "jsh not mounted at ${JSH_DIR}"
    print_info "Mount jsh with: -v \$(pwd):/home/testuser/.jsh:ro"
    exit 1
fi

# Verify installation
echo ""
print_info "Verifying installation..."

# Check init.sh exists
if [[ -f "${JSH_DIR}/src/init.sh" ]]; then
    prefix_success "JSH init script: ${JSH_DIR}/src/init.sh"
else
    prefix_error "JSH init script not found"
    exit 1
fi

# Test shell initialization (non-interactive source check)
echo ""
print_info "Testing shell initialization..."
if "${SHELL_CMD}" -c "source ${JSH_DIR}/src/init.sh && echo '${GRN}✔${RST} Shell initialization successful'"; then
    :
else
    print_error "Shell initialization failed"
    exit 1
fi

# =============================================================================
# Portable Shell (jssh) Validation
# =============================================================================

if [[ "${TEST_PORTABLE}" == "1" ]]; then
    echo ""
    echo "================================================"
    echo "  Testing portable shell (jssh)"
    echo "================================================"

    JSSH_SCRIPT="${JSH_DIR}/bin/jssh"
    JSSH_CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/jssh"
    PAYLOAD_CACHE="${JSSH_CACHE_DIR}/payload.tar.gz"

    # Check jssh script exists
    if [[ -f "${JSSH_SCRIPT}" ]]; then
        prefix_success "jssh script: ${JSSH_SCRIPT}"
    else
        prefix_error "jssh script not found"
        exit 1
    fi

    # Check jssh is executable (or would be after install)
    if [[ -x "${JSSH_SCRIPT}" ]] || head -1 "${JSSH_SCRIPT}" | grep -q "bash"; then
        prefix_success "jssh is a valid bash script"
    else
        prefix_error "jssh is not executable"
        exit 1
    fi

    # Build the payload
    echo ""
    print_info "Building portable shell payload..."
    rm -rf "${JSSH_CACHE_DIR}"
    if bash "${JSSH_SCRIPT}" --rebuild; then
        prefix_success "Payload built successfully"
    else
        prefix_error "Payload build failed"
        exit 1
    fi

    # Validate payload exists
    if [[ -f "${PAYLOAD_CACHE}" ]]; then
        PAYLOAD_SIZE=$(du -h "${PAYLOAD_CACHE}" | cut -f1)
        prefix_success "Payload created: ${PAYLOAD_CACHE} (${PAYLOAD_SIZE})"
    else
        prefix_error "Payload not found after build"
        exit 1
    fi

    # Extract and validate payload structure
    echo ""
    print_info "Validating payload structure..."
    EXTRACT_DIR=$(mktemp -d)
    trap 'rm -rf "${EXTRACT_DIR}"' EXIT

    if tar -xzf "${PAYLOAD_CACHE}" -C "${EXTRACT_DIR}"; then
        prefix_success "Payload extracted successfully"
    else
        prefix_error "Payload extraction failed"
        exit 1
    fi

    JSH_EXTRACTED="${EXTRACT_DIR}/jsh"

    # Check required files in payload
    REQUIRED_FILES=(
        "src/init.sh"
        "src/core.sh"
        "src/aliases.sh"
        "core/tmux.conf"
    )

    for file in "${REQUIRED_FILES[@]}"; do
        if [[ -f "${JSH_EXTRACTED}/${file}" ]]; then
            prefix_success "Payload contains: ${file}"
        else
            prefix_error "Payload missing: ${file}"
            exit 1
        fi
    done

    # Test shell initialization from extracted payload (interactive mode for aliases)
    # Note: Don't set JSH_EPHEMERAL to avoid cleanup trap deleting the directory between tests
    echo ""
    print_info "Testing full shell init from payload..."

    if bash -i -c "
        export JSH_DIR='${JSH_EXTRACTED}'
        export JSH_SHELL='bash'
        source '${JSH_EXTRACTED}/src/init.sh'
        # Verify some aliases/functions loaded
        type ll >/dev/null 2>&1 && echo $'\e[32m✔\e[0m Bash: aliases loaded'
    " 2>/dev/null; then
        :
    else
        prefix_error "Bash shell init from payload failed"
        exit 1
    fi

    if zsh -i -c "
        export JSH_DIR='${JSH_EXTRACTED}'
        export JSH_SHELL='zsh'
        source '${JSH_EXTRACTED}/src/init.sh'
        # Verify some aliases/functions loaded
        type ll >/dev/null 2>&1 && echo $'\e[32m✔\e[0m Zsh: aliases loaded'
    " 2>/dev/null; then
        :
    else
        prefix_error "Zsh shell init from payload failed"
        exit 1
    fi

    echo ""
    prefix_success "Portable shell validation complete"
fi

# If we got here, tests passed
echo ""
echo "================================================"
prefix_success "All checks passed!"
echo "================================================"

# If running interactively, launch shell
if [[ -t 0 ]]; then
    echo ""
    print_info "Launching interactive ${SHELL_CMD} shell..."
    exec "${SHELL_CMD}" -l
fi
