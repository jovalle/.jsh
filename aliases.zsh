# Conditional
# ----------------------------------------------------------
command -v eza >/dev/null 2>&1 && alias ls='eza --git --color=always --icons=always'
command -v kubecolor >/dev/null 2>&1 && alias kubectl='kubecolor'
command -v nvim >/dev/null 2>&1 && alias vim='nvim'

# Assorted
# ----------------------------------------------------------
alias ..='cd ../' # Go back 1 directory level
alias .2='cd ../../' # Go back 2 directory levels
alias .3='cd ../../../' # Go back 3 directory levels
alias .4='cd ../../../../' # Go back 4 directory levels
alias .5='cd ../../../../../' # Go back 5 directory levels
alias .6='cd ../../../../../../' # Go back 6 directory levels
alias 000='chmod 000' # ---------- (nobody)
alias 640='chmod 640' # -rw-r----- (user: rw, group: r, other: -)
alias 644='chmod 644' # -rw-r--r-- (user: rw, group: r, other: -)
alias 755='chmod 755' # -rwxr-xr-x (user: rwx, group: rx, other: x)
alias 775='chmod 775' # -rwxrwxr-x (user: rwx, group: rwx, other: rx)
alias _='sudo' # Evolve into superuser
alias a='ansible' # Abbreviation
alias ap='ansible-playbook' # Abbreviation
alias av='ansible-vault' # Abbreviation
alias c='clear' # c: Clear terminal display
alias ccd='clear && cd' # Reset shell
alias cd..='cd ../' # Go back 1 directory level (for fast typers)
alias cp='cp -iv' # Preferred 'cp' implementation
alias curl='curl -w "\n"' # Preferred 'curl' implementation
alias d='dirs -v | head -10' # Display dir
alias dud='du -d 1 -h' # Short and human-readable file listing
alias duf='du -sh *' # Short and human-readable directory listing
alias e="exit" # e: Exit
alias edit='vim' # edit: Open any file in vim
alias epochtime='date +%s' # Current epoch time
alias fix_stty='stty sane' # fix_stty: Restore terminal settings when screwed up
alias g='grep --color=auto -i' # grep > git
alias g_="git commit -m" # Git commit
alias gdiff='git diff --name-only master' # List files changed in this branch compared to master
alias gdiffcp='gdiff | xargs -I{} rsync --relative {}' # Copy modified files to another dir
alias gl="git log --graph --oneline" # Easy commit history
alias glances='glances -1 -t 0.5' # Faster output from glances
alias grep='grep --color=auto -i' # Preferred 'grep' implementation
alias gvimdiff='git difftool --tool=vimdiff --no-prompt' # Open all git changes in vimdiff
alias h='history'
alias k='kubectl' # Abbreviate kube control
alias kaf='kubectl apply -f' # Apply k8s manifest
alias kar='kubectl api-resources --verbs=list --namespaced -o name | grep -v "events.events.k8s.io" | grep -v "events" | sort | uniq' # Get all possible kinds
alias kav='kubectl api-versions' # List all APIs
alias kctx='kubectx' # Change kube context
alias kdel='kubectl delete' # Delete resource
alias kdelp='kubectl delete pods' # Delete all pods matching passed arguments
alias kdp='kubectl describe pods' # Describe all pods
alias kenc="sops --age \$(cat \${SOPS_AGE_KEY_FILE} | grep -oP \"public key: \K(.*)\") --encrypt --encrypted-regex '^(data|stringData)$' --in-place"
alias keti='kubectl exec -it' # Open terminal into pod
alias kgd='kubectl get deployments' # Get the deployment
alias kgp='kubectl get pods' # List all pods in ps output format
alias kns='kubens' # Change kube namespace
alias l='ls -la' # Long, show hidden files
alias ls='ls -G' # Show colors
alias ll='ls -lG' # Show colors
alias less='less -FSRXc' # Preferred 'less' implementation
alias md='mkdir -p' # Create directory
alias mkdir='mkdir -pv' # Preferred 'mkdir' implementation
alias mountReadWrite='/sbin/mount -uw /' # mountReadWrite: For use when booted into single-user
alias mv='mv -iv' # Preferred 'mv' implementation
alias mx='chmod a+x' # ---x--x--x (user: --x, group: --x, other: --x)
alias nano='nano -W' # Preferred 'nano' implementation
alias netshoot='kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot' # quick pod for troubleshooting
alias passgen='openssl passwd -1' # pass: Generate salted hash for passwords
alias path='echo -e ${PATH//:/\\n}' # path: Echo all executable Paths
alias perm='stat --printf "%a %n \n "' # perm: Show permission of target in number
alias please='sudo ' # Politely ask for superuser
alias pn='pnpm' # Abbreviate pnpm
alias proxy='http_proxy=$PROXY_ENDPOINT https_proxy=$PROXY_ENDPOINT no_proxy=$PROXY_EXCEPTION' # proxy: set as per env and on command
alias rm='rm -i' # Always prompt before deleting
alias show_options='shopt' # Show_options: display bash options settings
alias sshx='eval $(ssh-agent) && ssh-add 2>/dev/null' # sshx: Import SSH keys
alias stowrm='find $HOME -maxdepth 1 -type l | xargs -I {} unlink {}' # stowrm: Remove all symlinks (`stow -D` only removes existing matches)
alias sudo='sudo ' # Enable aliases to be sudo’ed
alias t="touch" # Create file
alias tf='terraform' # Abbreviation
alias timestamp='date "+%Y%m%dT%H%M%S"' # Filename ready complete time format
alias tmux="tmux -2" # Force 256 color support
alias vscode='open -a "Visual Studio Code"' # VSCode shortcut
alias vi='vim' # Preferred 'vi' implementation
alias vz='vi ~/.zshrc' # Open zshrc
alias w='watch -n1 -d -t ' # Faster watch, highlight changes and no title
alias wget='wget -c' # Preferred 'wget' implementation (resume download)
alias whatis='declare -f' # Print function definition
alias which='type -a' # Preferred 'which' implementation