#!/usr/bin/env bash
#  -------------------------------------------------------------------------------------
#
#  Description:  This file holds many useful BASH commands to improve life in the shell
#
#  Sections:
#  1.   Environment Variables 
#  2.   Aliases 
#  3.   Shell Modifications
#  4.   Functions
#  5.   Completions
#  6.   Extras
#  7.   Initialization
#  8.   Prompt
#
#  -------------------------------------------------------------------------------------

#   -------------------------------
#   0. PRECHECK
#   -------------------------------

#   Use colors, the ol' fashioned way
#   -------------------------------------------------------------------
    case $- in
      *i*) ;;
        *) return;;
    esac

#   -------------------------------
#   1. ENVIRONMENT VARIABLES
#   -------------------------------
export PROMPT_DIRTRIM=2                 # Trim long paths in prompt to x levels (requires BASH>=4)
export CDPATH="."                       # Colon-separate list of cd targets
export GOPATH=~/.go/
export GPG_TTY=$(tty)
export JSH=/root/.jsh
export JSH_CUSTOM="${HOME}/.bash_local"
export JSH_THEME=font
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PLATFORM=$(uname -s)
export TERM="xterm-256color"
export VISUAL=vim
export SHM=/dev/shm/$USER

#   Use colors, the ol' fashioned way
#   -------------------------------------------------------------------
    bold="\[\e[1m\]"
    underline="\[\033[4m\]"
    reset="\[\033[0m\]"
    black="\[\033[30m\]"
    red="\[\033[31m\]"
    green="\[\033[32m\]"
    yellow="\[\033[33m\]"
    blue="\[\033[34m\]"
    purple="\[\033[35m\]"
    cyan="\[\033[36m\]"
    white="\[\033[37m\]"

#   PATH
#   -----------------------------------------------------
paths=(
  "$JSH/bin"
  "$HOME/go/bin"
  "$HOME/google-cloud-sdk/bin"
)
for path in ${paths[@]}; do 
  [ -d "${path}" ] && export PATH="$PATH:$path"
  export PATH=$(echo $PATH | sed -r 's/:/\n/g' | awk '!seen[$0]++' | tr '\n' ':' | sed -r 's/:*$|^:*//g')
done


#   ---------------------------
#   2. ALIASES
#   ---------------------------
alias numFiles='echo $(ls -1 | wc -l)'      # numFiles: Count of non-hidden files in current dir
alias make1mb='truncate -s 1m ./1MB.dat'    # make1mb:  Creates a file of 1mb size (all zeros)
alias make5mb='truncate -s 5m ./5MB.dat'    # make5mb:  Creates a file of 5mb size (all zeros)
alias make10mb='truncate -s 10m ./10MB.dat' # make10mb: Creates a file of 10mb size (all zeros)
alias qfind="find . -name "                 # qfind:    Quickly search for file
alias cp='cp -iv'                           # Preferred 'cp' implementation
alias mv='mv -iv'                           # Preferred 'mv' implementation
alias mkdir='mkdir -pv'                     # Preferred 'mkdir' implementation
alias ll='ls -lAFh'                         # Preferred 'ls' implementation
alias less='less -FSRXc'                    # Preferred 'less' implementation
alias nano='nano -W'                        # Preferred 'nano' implementation
alias wget='wget -c'                        # Preferred 'wget' implementation (resume download)
alias c='clear'                             # c:            Clear terminal display
alias path='echo -e ${PATH//:/\\n}'         # path:         Echo all executable Paths
alias show_options='shopt'                  # Show_options: display bash options settings
alias fix_stty='stty sane'                  # fix_stty:     Restore terminal settings when screwed up
alias cic='set completion-ignore-case On'   # cic:          Make tab-completion case-insensitive
alias src='source ~/.bashrc'                # src:          Reload .bashrc file
alias perm='stat --printf "%a %n \n "'      # perm: Show permission of target in number
alias 000='chmod 000'                       # ---------- (nobody)
alias 640='chmod 640'                       # -rw-r----- (user: rw, group: r, other: -)
alias 644='chmod 644'                       # -rw-r--r-- (user: rw, group: r, other: -)
alias 755='chmod 755'                       # -rwxr-xr-x (user: rwx, group: rx, other: x)
alias 775='chmod 775'                       # -rwxrwxr-x (user: rwx, group: rwx, other: rx)
alias mx='chmod a+x'                        # ---x--x--x (user: --x, group: --x, other: --x)
alias ux='chmod u+x'                        # ---x------ (user: --x, group: -, other: -)
alias mountReadWrite='/sbin/mount -uw /'    # mountReadWrite: For use when booted into single-user 
alias cd..='cd ../'                         # Go back 1 directory level (for fast typers)
alias -- -='cd -'                           # Return to base dir
alias ..='cd ../'                           # Go back 1 directory level
alias ...='cd ../../'                       # Go back 2 directory levels
alias .3='cd ../../../'                     # Go back 3 directory levels
alias .4='cd ../../../../'                  # Go back 4 directory levels
alias .5='cd ../../../../../'               # Go back 5 directory levels
alias .6='cd ../../../../../../'            # Go back 6 directory levels
alias md='mkdir -p'                         # Create directory
alias rd='rmdir'                            # Remove directory (no force)
alias d='dirs -v | head -10'                # Display dir
alias _='sudo'                              # Evolve into superuser
alias please='sudo'                         # Politely ask for superuser
alias tmux='tmux -2'                        # tmux with 256 colors

#   Directory Listing aliases
#   -----------------------------------------------------
    alias dir='ls -hFx'
    alias l.='ls -d .* --color=tty' # short listing, only hidden files - .*
    alias L='ls -lAthF'             # long, sort by newest to oldest
    alias l='ls -lAtrhF'            # long, sort by oldest to newest
    alias la='ls -Al'               # show hidden files
    alias lc='ls -lcr'              # sort by change time
    alias lk='ls -lSr'              # sort by size
    alias lh='ls -lSrh'             # sort by size human readable
    alias lm='ls -al | more'        # pipe through 'more'
    alias lo='ls -laSFh'            # sort by size largest to smallest
    alias lr='ls -lR'               # recursive ls
    alias lt='ls -ltr'              # sort by date
    alias lu='ls -lur'              # sort by access time

#   lr:  Full Recursive Directory Listing
#   ------------------------------------------
    alias lr='ls -R | grep ":$" | sed -e '\''s/:$//'\'' -e '\''s/[^-][^\/]*\//--/g'\'' -e '\''s/^/   /'\'' -e '\''s/-/|/'\'' | less'
    alias dud='du -d 1 -h' # Short and human-readable file listing
    alias duf='du -sh *'   # Short and human-readable directory listing

#   memHogsTop, memHogsPs:  Find memory hogs
#   -----------------------------------------------------
    alias memHogsTop='top -l 1 -o rsize | head -20'
    alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'

#   cpuHogs:  Find CPU hogs
#   -----------------------------------------------------
    alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'

#   topForever:  Continual 'top' listing (every 10 seconds)
#   -----------------------------------------------------
    alias topForever='top -l 9999999 -s 10 -o cpu'

#   ttop:  Recommended 'top' invocation to minimize resources
#   ------------------------------------------------------------
#       Taken from this macosxhints article
#       http://www.macosxhints.com/article.php?story=20060816123853639
#   ------------------------------------------------------------
    alias ttop="top -R -F -s 10 -o rsize"

#   grep: With color and flag support
#   ------------------------------------------------------------
    grep_flag_available() {
        echo | grep $1 "" >/dev/null 2>&1
    }
    
    GREP_OPTIONS=""
    
    # color grep results
    if grep_flag_available --color=auto; then
        GREP_OPTIONS+=( " --color=auto" )
    fi
    
    # ignore VCS folders (if the necessary grep flags are available)
    VCS_FOLDERS="{.bzr,CVS,.git,.hg,.svn}"
    
    if grep_flag_available --exclude-dir=.cvs; then
        GREP_OPTIONS+=( " --exclude-dir=$VCS_FOLDERS" )
    elif grep_flag_available --exclude=.cvs; then
        GREP_OPTIONS+=( " --exclude=$VCS_FOLDERS" )
    fi
    
    # export grep settings
    alias grep="grep $GREP_OPTIONS"
    
    # clean up
    unset GREP_OPTIONS
    unset VCS_FOLDERS
    unset -f grep_flag_available

#   Networking
#   -----------------------------------------------------
    alias netCons='lsof -i'                           # netCons:     Show all open TCP/IP sockets
    alias lsock='sudo /usr/sbin/lsof -i -P'           # lsock:       Display open sockets
    alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP' # lsockU:      Display only open UDP sockets
    alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP' # lsockT:      Display only open TCP sockets
    alias ipInfo0='ifconfig getpacket en0'            # ipInfo0:     Get info on connections for en0
    alias ipInfo1='ifconfig getpacket en1'            # ipInfo1:     Get info on connections for en1
    alias openPorts='sudo lsof -i | grep LISTEN'      # openPorts:   All listening connections
    alias showBlocked='sudo ipfw list'                # showBlocked: All ipfw rules inc/ blocked IPs


#   Date & Time Management
#   -----------------------------------------------------
    alias bdate="date '+%a, %b %d %Y %T %Z'"
    alias cal3='cal -3'
    alias da='date "+%Y-%m-%d %A    %T %Z"'
    alias daysleft='echo "There are $(($(date +%j -d"Dec 31, $(date +%Y)")-$(date +%j))) left in year $(date +%Y)."'
    alias epochtime='date +%s'
    alias mytime='date +%H:%M:%S'
    alias secconvert='date -d@1234567890'
    alias stamp='date "+%Y%m%d%a%H%M"'
    alias timestamp='date "+%Y%m%dT%H%M%S"'
    alias today='date +"%A, %B %-d, %Y"'
    alias weeknum='date +%V'

#   Web development 
#   -----------------------------------------------------
    alias apacheEdit='sudo edit /etc/httpd/httpd.conf'    # apacheEdit:    Edit httpd.conf
    alias apacheRestart='sudo apachectl graceful'         # apacheRestart: Restart Apache
    alias editHosts='sudo edit /etc/hosts'                # editHosts:     Edit /etc/hosts file
    alias herr='tail /var/log/httpd/error_log'            # herr:          Tails HTTP error logs
    alias apacheLogs="less +F /var/log/apache2/error_log" # Apachelogs:    Shows apache error logs


#   ---------------------------
#   3.  SHELL MODIFICATIONS
#   ---------------------------

#   Optional shell behavior
#   -----------------------------------------------------
    set -o vi                      # Set vim mode
    shopt -s cdspell               # Autocorrect typos in path names when using `cd`
    shopt -s checkwinsize          # Check window size per command
    shopt -s nocaseglob            # Case-insensitive globbing
    shopt -s histappend            # Save history to file (~/.bash_history)
    shopt -s histreedit            # Use readline on history
    shopt -s interactive_comments  # Detect comments
    shopt -s checkwinsize          # Update window size after each command
    shopt -s globstar 2> /dev/null # Turn on recursive globbing (use ** to recurse all directories)
    shopt -s autocd 2> /dev/null   # Prepend cd on directory names
    shopt -s dirspell 2> /dev/null # Autocorrect tab-completion
    shopt -s cdspell 2> /dev/null  # Autocorrect cd arguments
    shopt -s cdable_vars           # Allow directory bookmarks (update $CDPATH, colon-separated list of targets)
    
#   History improvements
#   -----------------------------------------------------
    # Huge history. Doesn't appear to slow things down, so why not?
    HISTSIZE=500000
    HISTFILESIZE=100000
    
    # Avoid duplicate entries
    HISTCONTROL="erasedups:ignoreboth"
    
    # Don't record some commands
    export HISTIGNORE="&:[ ]*:exit:ls:bg:fg:history:clear"
    
    # Use standard ISO 8601 timestamp
    # %F equivalent to %Y-%m-%d                                                                                      
    # %T equivalent to %H:%M:%S (24-hours format)
    HISTTIMEFORMAT='%F %T '
    
    # Enable incremental history search with up/down arrows (also Readline goodness)
    # Learn more about this here: http://codeinthehole.com/writing/the-most-important-command-line-tip-incremental-hi
    # bash4 specific ??
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
    bind '"\e[C": forward-char'
    bind '"\e[D": backward-char'


#   Preferred editor for local and remote sessions
#   -----------------------------------------------------
    if [[ -n $SSH_CONNECTION ]]; then
      export EDITOR='vim'
    else
      export EDITOR='mvim'
    fi

#   Disable CTRL-S and CTRL-Q
#   -----------------------------------------------------
    if [[ $- =~ i ]]; then
      stty -ixoff -ixon
    fi

#   Make less more friendly for non-text input files, see lesspipe(1)
#   -----------------------------------------------------
    [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

#   Set variable identifying the chroot you work in (used in the prompt below)
#   -----------------------------------------------------
    if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
      debian_chroot=$(cat /etc/debian_chroot)
    fi

#   Set a fancy prompt (non-color, unless we know we "want" color)
#   -----------------------------------------------------
    case "$TERM" in
      xterm-color|*-256color) color_prompt=yes;;
    esac

#   Uncomment for a colored prompt, if the terminal has the capability; turned
#   off by default to not distract the user: the focus in a terminal window
#   should be on the output of commands, not on the prompt
#   --------------------------------------------------------------------
    force_color_prompt=yes
    
    if [ -n "$force_color_prompt" ]; then
      if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
      else
        color_prompt=
      fi
    fi
    
    if [ "$color_prompt" = yes ]; then
      PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    else
      PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
    fi
    unset color_prompt force_color_prompt

#   If this is an xterm set the title to user@host:dir
#   --------------------------------------------------------------------
    case "$TERM" in
      xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
      *)
        ;;
    esac

#   Enable color support of ls and also add handy aliases
#   --------------------------------------------------------------------
    if [ -x /usr/bin/dircolors ]; then
      test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
      alias ls='ls --color=auto'
      alias dir='dir --color=auto'
      alias vdir='vdir --color=auto'
      alias grep='grep --color=auto'
      alias fgrep='fgrep --color=auto'
      alias egrep='egrep --color=auto'
    fi

#   Colored GCC warnings and errors
#   --------------------------------------------------------------------
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

#   Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
#   --------------------------------------------------------------------
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

#   Alias definitions.
#   You may want to put all your additions into a separate file like
#   ~/.bash_aliases, instead of adding them here directly.
#   See /usr/share/doc/bash-doc/examples in the bash-doc package.
#   --------------------------------------------------------------------
    if [ -f ~/.bash_aliases ]; then
        . ~/.bash_aliases
    fi

#   Use SHM for storing sensitive information
#   --------------------------------------------------------------------
    if [ ! -d "$SHM" ]; then
      mkdir $SHM
      chmod 700 $SHM
    fi


#   ---------------------------
#   4. FUNCTIONS 
#   ---------------------------
findPid () { lsof -t -c "$@" ; }                                             # findPid:     Find out the pid of a specified process
myps () { ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command ; } # myps:        List processes owned by my user:
httpHeaders () { /usr/bin/curl -I -L "$@" ; }                                # httpHeaders: Grabs headers from web page
zipf () { zip -r "$1".zip "$1" ; }                                           # zipf:        To create a ZIP archive of a folder

#   Checks
#   -------------------------------------------------------------------
    # Ask 
    seek_confirmation() {
      printf "\\n${bold}%s${reset}" "$@"
      read -p " (y/n) " -n 1
      printf "\\n"
    }

    # Test whether the result of an 'ask' is a confirmation
    is_confirmed() {
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        return 0
      fi
      return 1
    }
    
    # Test if command exists
    type_exists() {
      if [ "$(type -P "$1")" ]; then
        return 0
      fi
      return 1
    }

    # Test if right OS
    is_os() {
      if [[ "${OSTYPE}" == $1* ]]; then
        return 0
      fi
      return 1
    }

#   headers and logging
#   -------------------------------------------------------------------
    e_header() { printf "\n${bold}${purple}==========  %s  ==========${reset}\n" "$@" 
    }
    e_arrow() { printf "➜ %s\n" "$@"
    }
    e_success() { printf "${green}✔ %s${reset}\n" "$@"
    }
    e_error() { printf "${red}✖ %s${reset}\n" "$@"
     }
    e_warning() { printf "${orange}➜ %s${reset}\n" "$@"
    }
    e_underline() { printf "${underline}${bold}%s${reset}\n" "$@"
    }
    e_bold () { printf "${bold}%s${reset}\n" "$@"
    }
    e_note () { printf "${underline}${bold}${blue}Note:${reset}  ${yellow}%s${reset}\n" "$@"
    }
    
#   httpDebug:  Download a web page and show info on what took time
#   --------------------------------------------------------------------
    httpDebug () { /usr/bin/curl "$@" -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\\n" ; }

#   myip: display public IP
#   --------------------------------------------------------------------
    myip () {
      res=$(curl -s checkip.dyndns.org | grep -Eo '[0-9\.]+')
      echo -e "Your public IP is: ${green} $res ${reset}" 
    }

#   isitdown:  checks whether a website is down for you, or everybody
#   --------------------------------------------------------------------
    isitdown () { 
      curl -s "http://www.downforeveryoneorjustme.com/$1" | sed '/just you/!d;s/<[^>]*>//g' 
    }

#   mcd:   Makes new Dir and jumps inside
#   --------------------------------------------------------------------
    mcd () { mkdir -p -- "$*" ; cd -- "$*" || exit ; }

#   mans:   Search manpage given in agument '1' for term given in argument '2' (case insensitive)
#           displays paginated result with colored search terms and two lines surrounding each hit.
#           Example: mans mplayer codec
#   --------------------------------------------------------------------
    mans () { man "$1" | grep -iC2 --color=always "$2" | less ; }

#   showa: to remind yourself of an alias (given some part of it)
#   ------------------------------------------------------------
    showa () { /usr/bin/grep --color=always -i -a1 "$@" ~/Library/init/bash/aliases.bash | grep -v '^\s*$' | less -FSRXc ; }

#   quiet: mute output of a command
#   ------------------------------------------------------------
    quiet () {
        "$*" &> /dev/null &
    }

#   lsgrep: search through directory contents with grep
#   ------------------------------------------------------------
    lsgrep () { ls | grep "$*" ; }

#   show the n most used commands. defaults to 10
#   ------------------------------------------------------------
    hstats() {
      if [[ $# -lt 1 ]]; then
        NUM=10
      else
        NUM=${1}
      fi
      history | awk '{print $2}' | sort | uniq -c | sort -rn | head -"$NUM"
    }

#   extract:  Extract most know archives with one command
#   ---------------------------------------------------------
    extract () {
      if [ -f "$1" ] ; then
        case "$1" in
          *.tar.bz2)   tar xjf "$1"     ;;
          *.tar.gz)    tar xzf "$1"     ;;
          *.bz2)       bunzip2 "$1"     ;;
          *.rar)       unrar e "$1"     ;;
          *.gz)        gunzip "$1"      ;;
          *.tar)       tar xf "$1"      ;;
          *.tbz2)      tar xjf "$1"     ;;
          *.tgz)       tar xzf "$1"     ;;
          *.zip)       unzip "$1"       ;;
          *.Z)         uncompress "$1"  ;;
          *.7z)        7z x "$1"        ;;
          *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
      else
        echo "'$1' is not a valid file"
      fi
    }

#   buf:  back up file with timestamp
#   ---------------------------------------------------------
    buf () {
      local filename filetime
      filename=$1
      filetime=$(date +%Y%m%d_%H%M%S)
      cp -a "${filename}" "${filename}_${filetime}"
    }

#   del:  move files to hidden folder in tmp, that gets cleared on each reboot
#   ---------------------------------------------------------
    del() {
      mkdir -p /tmp/.trash && mv "$@" /tmp/.trash;
    }

#   mkiso:  creates iso from current dir in the parent dir (unless defined)
#   ---------------------------------------------------------
    mkiso () {
      if type "mkisofs" > /dev/null; then
        if [ -z ${1+x} ]; then
          local isoname=${PWD##*/}
        else
          local isoname=$1
        fi

        if [ -z ${2+x} ]; then
          local destpath=../
        else
          local destpath=$2
        fi

        if [ -z ${3+x} ]; then
          local srcpath=${PWD}
        else
          local srcpath=$3
        fi

        if [ ! -f "${destpath}${isoname}.iso" ]; then
          echo "writing ${isoname}.iso to ${destpath} from ${srcpath}"
          mkisofs -V "${isoname}" -iso-level 3 -r -o "${destpath}${isoname}.iso" "${srcpath}"
        else
          echo "${destpath}${isoname}.iso already exists"
        fi
      else
        echo "mkisofs cmd does not exist, please install cdrtools"
      fi
    }

#   Searching
#   ---------------------------------------------------------
    ff () { /usr/bin/find . -name "$@" ; }     # ff:  Find file under the current directory
    ffs () { /usr/bin/find . -name "$@"'*' ; } # ffs: Find file whose name starts with a given string
    ffe () { /usr/bin/find . -name '*'"$@" ; } # ffe: Find file whose name ends with a given string
    bigfind() {
      if [[ $# -lt 1 ]]; then
        echo_warn "Usage: bigfind DIRECTORY"
        return
      fi
      du -a "$1" | sort -n -r | head -n 10
    }


#   ips:  display all ip addresses for this host
#   -------------------------------------------------------------------
    ips () {
      if command -v ifconfig &>/dev/null
      then
        ifconfig | awk '/inet /{ print $2 }'
      elif command -v ip &>/dev/null
      then
        ip addr | grep -oP 'inet \K[\d.]+'
      else
        echo "You don't have ifconfig or ip command installed!"
      fi
    }

#   ii:  display useful host related informaton
#   -------------------------------------------------------------------
    ii() {
      echo -e "\\nYou are logged on ${red}$HOST"
      echo -e "\\nAdditionnal information:$NC " ; uname -a
      echo -e "\\n${red}Users logged on:$NC " ; w -h
      echo -e "\\n${red}Current date :$NC " ; date
      echo -e "\\n${red}Machine stats :$NC " ; uptime
      [[ "$OSTYPE" == darwin* ]] && echo -e "\\n${red}Current network location :$NC " ; scselect
      echo -e "\\n${red}Public facing IP Address :$NC " ;myip
      [[ "$OSTYPE" == darwin* ]] && echo -e "\\n${red}DNS Configuration:$NC " ; scutil --dns
      echo
    }

#   usage: disk usage per directory, in Mac OS X and Linux
#   -------------------------------------------------------------------
    usage () {
      if [ "$(uname)" = "Darwin" ]; then
        if [ -n "$1" ]; then
          du -hd 1 "$1"
        else
          du -hd 1
        fi
      elif [ "$(uname)" = "Linux" ]; then
        if [ -n "$1" ]; then
          du -h --max-depth=1 "$1"
        else
          du -h --max-depth=1
        fi
      fi
    }

    setvaultkey () {
      if [ ! -f "$shm/.vault-$1" ]; then
        read -p "Input vault key: " -s VAULT
        echo ""
        echo $VAULT > $SHM/.vault-$1
        unset VAULT
      fi
    }
   

#   xsource: check resource before sourcing
#   -------------------------------------------------------------------
    xsource () {
      if [ -f "$JSH/lib/${1}.sh" ]; then
        source $JSH/lib/${1}.sh
      elif [ -f "$JSH/completions/${1}.completion.sh" ]; then
        source $JSH/completions/${1}.completion.sh
      elif [ -f "$JSH/plugins/${1}.plugin.sh" ]; then
        source $JSH/plugins/${1}.plugin.sh
      fi
    }

#   ---------------------------
#   5. COMPLETIONS
#   ---------------------------

#   BASH
#   --------------------------------------------------------------------
    if ! shopt -oq posix; then
      if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
      elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
      fi
    fi

#   All
#   --------------------------------------------------------------------
    for f in $(find $JSH/completions -type f); do
      . $f
    done

#   ---------------------------
#   6. EXTRAS
#   ---------------------------

#   Spinner library
#   -----------------------------------------------------
    xsource spinner 

#   Ancillary functionality
#   -----------------------------------------------------
    if [[ -n $JSH_CUSTOM && -f $JSH_CUSTOM ]]; then
      source $JSH_CUSTOM 
    fi


#   ---------------------------
#   7. INITIALIZATION
#   ---------------------------
# Get environment details
if [ ! -z $TFE_WORKSPACE ]; then
  environment=$(echo $TFE_WORKSPACE | cut -d '-' -f 3 | awk '{print substr($1,1,1)}')
  workspace="${RED}[${TFE_WORKSPACE}]${reset}"

  if [ ! -z $inv ]; then
    dynamic=" -i $inv/$workspace"
  fi

  # Get vault key for respective environment
  setvk $environment

  # Update ansible config with new vault key
  export ANSIBLE_VAULT_PASSWORD_FILE=$shm/.vault-${environment}

  # Check if key is already set
  if [ ! -f "$shm/$workspace" ]; then
    # Check inventory for key
    if [ -f "$GIT_DIR/$GIT_SAFE/$workspace/id_rsa" ]; then
      ansible-vault decrypt --output $shm/$workspace $GIT_DIR/$GIT_SAFE/$workspace/id_rsa
      export ANSIBLE_VAULT_PRIVATE_KEY_FILE=$shm/$workspace
    # If not in inventory, assume local key
    elif [ -f "$HOME/.ssh/$workspace" ]; then
      export ANSIBLE_VAULT_PRIVATE_KEY_FILE=$HOME/.ssh/$workspace
    else
      echo "${red}No SSH private key found!${reset}"
    fi
  # Key already in shm
  else
    export ANSIBLE_PRIVATE_KEY_FILE=$shm/$workspace
  fi
elif [ ! -z $WORKSPACE ]; then
  workspace="${red}[${WORKSPACE}]${reset}"
fi

# Update aliases with new info
if [[ -n $workspace ]]; then
  alias a="ansible$dynamic -i $inv/$workspace"
  alias ap="ansible-playbook$dynamic -i $inv/$workspace"
  alias ssh="ssh -i ${ANSIBLE_PRIVATE_KEY_FILE}"
  alias scp="scp -i ${ANSIBLE_PRIVATE_KEY_FILE}"
else
  unset ANSIBLE_PRIVATE_KEY_FILE
  unset ANSIBLE_VAULT_PASSWORD_FILE
fi


#   ---------------------------
#   8. PROMPT
#   ---------------------------
    prompt_cmd() {
      [[ $? == 0 ]] && ret="${green}" || ret="${red}"
      [[ -n $PROMPT_SYMBOL ]] && local prompt_symbol="$PROMPT_SYMBOL" || local prompt_symbol='>'
      local dir="${cyan}\w${reset}"
      local git="${purple}\$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/')${reset}"
      local host="${bold}${yellow}\h${reset}"
      local prompt="${ret}└─╼ ${reset}"
      local user="${yellow}\u${reset}"
      if [[ -n $PROMPT_CUSTOM ]]; then
        PS1=${PROMPT_CUSTOM}
      else
        if [[ $PROMPT == 'mini' ]]; then
          local prompt="${ret}${prompt_symbol} ${reset}"
          PS1="${prompt}${dir}${git}${workspace} "
        elif [[ $PROMPT == 'full' ]]; then
          PS1="${bold}┌─[${reset}${user}@${host}:${dir}${git}${bold}]${reset}${workspace}\n${prompt}"
        else
          PS1="${workspace}${user}@${host}:${dir}${git}${ret}$ ${reset}"
        fi
      fi
    }

export PROMPT_COMMAND=prompt_cmd
