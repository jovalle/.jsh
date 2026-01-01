#!/usr/bin/env zsh
# Test command -v performance

typeset -F SECONDS=0

echo "Testing command -v performance..."
echo

# Test 1: Single command -v
before=$SECONDS
command -v gawk > /dev/null 2>&1
after=$SECONDS
printf "Single command -v check:              %6.2f ms\n" $(((after - before) * 1000))

# Test 2: 50 command -v calls
before=$SECONDS
for i in {1..50}; do
    command -v gawk > /dev/null 2>&1
done
after=$SECONDS
printf "50 command -v checks:                  %6.0f ms\n" $(((after - before) * 1000))
printf "Average per check:                     %6.2f ms\n" $(((after - before) * 1000 / 50))

# Test 3: All the GNU tool checks from .jshrc
before=$SECONDS
command -v gawk > /dev/null 2>&1
command -v gbase64 > /dev/null 2>&1
command -v gbasename > /dev/null 2>&1
command -v gcat > /dev/null 2>&1
command -v gchmod > /dev/null 2>&1
command -v gchown > /dev/null 2>&1
command -v gcp > /dev/null 2>&1
command -v gcut > /dev/null 2>&1
command -v gdate > /dev/null 2>&1
command -v gdd > /dev/null 2>&1
command -v gdf > /dev/null 2>&1
command -v gdirname > /dev/null 2>&1
command -v gdu > /dev/null 2>&1
command -v gecho > /dev/null 2>&1
command -v genv > /dev/null 2>&1
command -v gfind > /dev/null 2>&1
command -v ggrep > /dev/null 2>&1
command -v ghead > /dev/null 2>&1
command -v gln > /dev/null 2>&1
command -v gls > /dev/null 2>&1
command -v gmkdir > /dev/null 2>&1
command -v gmv > /dev/null 2>&1
command -v grm > /dev/null 2>&1
command -v gsed > /dev/null 2>&1
command -v gsort > /dev/null 2>&1
command -v gtail > /dev/null 2>&1
command -v gtar > /dev/null 2>&1
command -v gtouch > /dev/null 2>&1
command -v gtr > /dev/null 2>&1
command -v guniq > /dev/null 2>&1
command -v gwc > /dev/null 2>&1
command -v gwhich > /dev/null 2>&1
command -v gxargs > /dev/null 2>&1
command -v eza > /dev/null 2>&1
command -v hx > /dev/null 2>&1
command -v nvim > /dev/null 2>&1
command -v vim > /dev/null 2>&1
after=$SECONDS
printf "\n37 GNU tool checks (from .jshrc):      %6.0f ms\n" $(((after - before) * 1000))

# Test 4: Full .jshrc load
before=$SECONDS
source /Users/jay/.jsh/dotfiles/.jshrc
after=$SECONDS
printf "\nFull .jshrc source:                    %6.0f ms\n" $(((after - before) * 1000))
