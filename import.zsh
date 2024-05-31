[ ! -f ~/.p10k.zsh ] || source ~/.p10k.zsh
[ -d /opt/homebrew/opt/llvm/bin ] && export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.jsh_local ] && source ~/.jsh_local
