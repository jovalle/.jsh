#!/usr/bin/env bash
# make.bash - Bash completion for make
# Shows only Makefile targets (not files or variables)
# shellcheck disable=SC2207

_make_targets_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    # Check if a Makefile exists
    if [[ -f Makefile ]] || [[ -f makefile ]] || [[ -f GNUmakefile ]]; then
        # Extract targets from Makefile using make's -qp flag
        # Filter to only show actual targets (not special targets, files, or variables)
        local targets
        targets=$(make -qp 2>/dev/null | \
                  grep -E '^[a-zA-Z0-9_-]+:' | \
                  cut -d: -f1 | \
                  grep -vE '^\.|^Makefile$|^makefile$|^GNUmakefile$' | \
                  sort -u | tr '\n' ' ')

        if [[ -n "$targets" ]]; then
            COMPREPLY=($(compgen -W "$targets" -- "$cur"))
            return
        fi
    fi

    # No Makefile or no targets found - fall back to default
    COMPREPLY=()
}

# Register completion for make and gmake
complete -F _make_targets_completion make gmake
