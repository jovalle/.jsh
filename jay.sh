#!/bin/bash

# An almost unembarrasingly  https://github.com/ohmybash/oh-my-bash

# Bail out early if non-interactive
case $- in
  *i*) ;;
    *) return;;
esac

# add a function path
fpath=($JSH/functions $fpath)

# Set JSH_CUSTOM to the path where your custom config files
# and plugins exists, or else we will use the default custom/
if [[ -z "$JSH_CUSTOM" ]]; then
  JSH_CUSTOM="$JSH/custom"
fi

# Load all of the config files in ~/.jsh/lib that end in .sh
# TIP: Add files you don't want in git to .gitignore
for config_file in $JSH/lib/*.sh; do
  custom_config_file="${JSH_CUSTOM}/lib/${config_file:t}"
  [ -f "${custom_config_file}" ] && config_file=${custom_config_file}
  source $config_file
done


is_plugin() {
  local base_dir=$1
  local name=$2
  test -f $base_dir/plugins/$name/$name.plugin.sh \
    || test -f $base_dir/plugins/$name/_$name
}
# Add all defined plugins to fpath. This must be done
# before running compinit.
for plugin in ${plugins[@]}; do
  if is_plugin $JSH_CUSTOM $plugin; then
    fpath=($JSH_CUSTOM/plugins/$plugin $fpath)
  elif is_plugin $JSH $plugin; then
    fpath=($JSH/plugins/$plugin $fpath)
  fi
done

is_completion() {
  local base_dir=$1
  local name=$2
  test -f $base_dir/completions/$name/$name.completion.sh
}
# Add all defined completions to fpath. This must be done
# before running compinit.
for completion in ${completions[@]}; do
  if is_completion $JSH_CUSTOM $completion; then
    fpath=($JSH_CUSTOM/completions/$completion $fpath)
  elif is_completion $JSH $completion; then
    fpath=($JSH/completions/$completion $fpath)
  fi
done

is_alias() {
  local base_dir=$1
  local name=$2
  test -f $base_dir/aliases/$name/$name.aliases.sh
}
# Add all defined completions to fpath. This must be done
# before running compinit.
for alias in ${aliases[@]}; do
  if is_alias $JSH_CUSTOM $alias; then
    fpath=($JSH_CUSTOM/aliases/$alias $fpath)
  elif is_alias $JSH $alias; then
    fpath=($JSH/aliases/$alias $fpath)
  fi
done

# Figure out the SHORT hostname
if [[ "$OSTYPE" = darwin* ]]; then
  # macOS's $HOST changes with dhcp, etc. Use ComputerName if possible.
  SHORT_HOST=$(scutil --get ComputerName 2>/dev/null) || SHORT_HOST=${HOST/.*/}
else
  SHORT_HOST=${HOST/.*/}
fi

# Load all of the plugins that were defined in ~/.bashrc
for plugin in ${plugins[@]}; do
  if [ -f $JSH_CUSTOM/plugins/$plugin/$plugin.plugin.sh ]; then
    source $JSH_CUSTOM/plugins/$plugin/$plugin.plugin.sh
  elif [ -f $JSH/plugins/$plugin/$plugin.plugin.sh ]; then
    source $JSH/plugins/$plugin/$plugin.plugin.sh
  fi
done

# Load all of the aliases that were defined in ~/.bashrc
for alias in ${aliases[@]}; do
  if [ -f $JSH_CUSTOM/aliases/$alias.aliases.sh ]; then
    source $JSH_CUSTOM/aliases/$alias.aliases.sh
  elif [ -f $JSH/aliases/$alias.aliases.sh ]; then
    source $JSH/aliases/$alias.aliases.sh
  fi
done

# Load all of the completions that were defined in ~/.bashrc
for completion in ${completions[@]}; do
  if [ -f $JSH_CUSTOM/completions/$completion.completion.sh ]; then
    source $JSH_CUSTOM/completions/$completion.completion.sh
  elif [ -f $JSH/completions/$completion.completion.sh ]; then
    source $JSH/completions/$completion.completion.sh
  fi
done

# Load all of your custom configurations from custom/
for config_file in $JSH_CUSTOM/*.sh; do
  if [ -f $config_file ]; then
    source $config_file
  fi
done
unset config_file

# Load colors first so they can be use in base theme
source "${JSH}/themes/colours.theme.sh"
source "${JSH}/themes/base.theme.sh"

# Load the theme
if [ ! "$JSH_THEME" = ""  ]; then
  if [ -f "$JSH_CUSTOM/$JSH_THEME/$JSH_THEME.theme.sh" ]; then
    source "$JSH_CUSTOM/$JSH_THEME/$JSH_THEME.theme.sh"
  elif [ -f "$JSH_CUSTOM/themes/$JSH_THEME/$JSH_THEME.theme.sh" ]; then
    source "$JSH_CUSTOM/themes/$JSH_THEME/$JSH_THEME.theme.sh"
  else
    source "$JSH/themes/$JSH_THEME/$JSH_THEME.theme.sh"
  fi
fi

if [[ $PROMPT ]]; then
    export PS1="\["$PROMPT"\]"
fi

if ! type_exists '__git_ps1' ; then
  source "$JSH/tools/git-prompt.sh"
fi