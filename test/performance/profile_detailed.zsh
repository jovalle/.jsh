#!/usr/bin/env zsh
# Detailed shell startup timing analysis

typeset -F SECONDS=0
local start=$SECONDS

echo "=== Shell Startup Timing Analysis ==="
echo

# Time sourcing .jshrc
local before=$SECONDS
source "${HOME}/.jsh/dotfiles/.jshrc"
local after=$SECONDS
printf "%-40s %6.0f ms\n" ".jshrc (exports, aliases, functions)" $(((after - before) * 1000))

# Time Zinit initialization
before=$SECONDS
export ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -d "${ZINIT_HOME}" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"
fi
after=$SECONDS
printf "%-40s %6.0f ms\n" "Zinit core initialization" $(((after - before) * 1000))

# Time Powerlevel10k instant prompt
before=$SECONDS
if [[ -r "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-${HOME}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
after=$SECONDS
printf "%-40s %6.0f ms\n" "Powerlevel10k instant prompt" $(((after - before) * 1000))

# Time loading Powerlevel10k theme
before=$SECONDS
zinit ice depth=1
zinit light romkatv/powerlevel10k
after=$SECONDS
printf "%-40s %6.0f ms\n" "Powerlevel10k theme" $(((after - before) * 1000))

# Time each plugin
declare -A plugin_times=(
    "Aloxaf/fzf-tab" "fzf-tab"
    "zsh-users/zsh-completions" "zsh-completions"
    "zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
    "zdharma-continuum/fast-syntax-highlighting" "fast-syntax-highlighting"
    "akarzim/zsh-docker-aliases" "zsh-docker-aliases"
    "MichaelAquilina/zsh-you-should-use" "zsh-you-should-use"
    "wfxr/forgit" "forgit"
    "lukechilds/zsh-nvm" "zsh-nvm"
    "mafredri/zsh-async" "zsh-async"
    "supercrabtree/k" "k"
)

for plugin in Aloxaf/fzf-tab zsh-users/zsh-completions zsh-users/zsh-autosuggestions \
              zdharma-continuum/fast-syntax-highlighting akarzim/zsh-docker-aliases \
              MichaelAquilina/zsh-you-should-use wfxr/forgit lukechilds/zsh-nvm \
              mafredri/zsh-async supercrabtree/k; do
    before=$SECONDS
    zinit light $plugin
    after=$SECONDS
    printf "%-40s %6.0f ms\n" "Plugin: ${plugin##*/}" $(((after - before) * 1000))
done

# Time shell options and keybindings
before=$SECONDS
bindkey -v
setopt AUTO_CD COMPLETE_IN_WORD extended_history hist_find_no_dups
after=$SECONDS
printf "%-40s %6.0f ms\n" "Shell options & keybindings" $(((after - before) * 1000))

# Time completions loading
before=$SECONDS
if declare -f _jsh_load_completions > /dev/null 2>&1; then
  _jsh_load_completions zsh
fi
after=$SECONDS
printf "%-40s %6.0f ms\n" "_jsh_load_completions" $(((after - before) * 1000))

# Individual completion timings
echo
echo "=== Individual Completion Sources ==="
for cmd in direnv docker task zoxide kubectl fzf atuin; do
    if command -v $cmd > /dev/null 2>&1; then
        before=$SECONDS
        case $cmd in
            direnv) eval "$(direnv hook zsh)" ;;
            docker) eval "$(docker completion zsh)" ;;
            task) source <(task --completion zsh) ;;
            zoxide) eval "$(zoxide init zsh)" ;;
            kubectl) source <(kubectl completion zsh) ;;
            fzf) source <(command fzf --zsh) ;;
            atuin)
                export ATUIN_NOBIND="true"
                eval "$(atuin init zsh)"
                ;;
        esac
        after=$SECONDS
        printf "%-40s %6.0f ms\n" "  $cmd completion" $(((after - before) * 1000))
    fi
done

# Time p10k config loading
before=$SECONDS
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
after=$SECONDS
printf "\n%-40s %6.0f ms\n" "p10k config" $(((after - before) * 1000))

# Total time
local total=$SECONDS
echo
printf "%-40s %6.0f ms\n" "=== TOTAL STARTUP TIME ===" $((total * 1000))
