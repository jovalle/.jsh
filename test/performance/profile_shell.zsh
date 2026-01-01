#!/usr/bin/env zsh
# Shell startup profiler

# Enable profiling
zmodload zsh/zprof

# Source the actual zshrc
source ~/.zshrc

# Print profile results
zprof
