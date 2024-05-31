# Color palette
if [[ $(uname) == 'Darwin' || $(command -v tput &>/dev/null) ]]; then
  black="\001$(tput setaf 0)\002"
  red="\001$(tput setaf 1)\002"
  green="\001$(tput setaf 2)\002"
  orange="\001$(tput setaf 3)\002"
  blue="\001$(tput setaf 4)\002"
  purple="\001$(tput setaf 5)\002"
  cyan="\001$(tput setaf 6)\002"
  lightgray="\001$(tput setaf 7)\002"
  darkgray="\001$(tput setaf 8)\002"
  pink="\001$(tput setaf 9)\002"
  lime="\001$(tput setaf 10)\002"
  yellow="\001$(tput setaf 11)\002"
  aqua="\001$(tput setaf 12)\002"
  lavender="\001$(tput setaf 13)\002"
  ice="\001$(tput setaf 14)\002"
  white="\001$(tput setaf 15)\002"
  bold="\001$(tput bold)\002"
  underline="\001$(tput smul)\002"
  reset="\001$(tput sgr0)\002"
else
  black="\033[30m"
  red="\033[31m"
  green="\033[32m"
  orange="\033[33m"
  blue="\033[34m"
  purple="\033[35m"
  cyan="\033[36m"
  lightgray="\033[37m"
  darkgray="\033[90m"
  pink="\033[91m"
  lime="\033[92m"
  yellow="\033[93m"
  aqua="\033[94m"
  lavender="\033[95m"
  ice="\033[96m"
  white="\033[97m"
  bold="\033[1m"
  underline="\033[4m"
  reset="\033[0m"
fi

# Color helper functions
abort() { echo; echo "${red}$@${reset}" 1>&2; exit 1; } # show
error() { echo -e ${red}$@${reset}; return 1; }
warn() { echo -e ${orange}$@${reset}; }
success() { echo -e ${green}$@${reset}; }
info() { echo -e ${blue}$@${reset}; }

# More elaborate coloring
if [[ $(which grc 2>/dev/null) == 0 ]]; then
  alias colorize="$(which grc) -es --colour=auto"
  alias as='colorize as'
  alias configure='colorize ./configure'
  alias df='colorize df'
  alias diff='colorize diff'
  alias dig='colorize dig'
  alias g++='colorize g++'
  alias gas='colorize gas'
  alias gcc='colorize gcc'
  alias head='colorize head'
  alias ld='colorize ld'
  alias make='colorize make'
  alias mount='colorize mount'
  alias mtr='colorize mtr'
  alias netstat='colorize netstat'
  alias ping='colorize ping'
  alias ps='colorize ps'
  alias tail='colorize tail'
  alias traceroute='colorize /usr/sbin/traceroute'
fi
