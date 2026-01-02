# Git helper functions for jsh
# Provides utilities for git operations with graceful fallbacks

# Git clone helper that forces HTTPS even if user has SSH URL rewriting configured
# This handles environments where SSH is not available (containers, restricted systems)
#
# Usage: git_clone_https <url> <destination>
#
# Returns: 0 on success, 1 on failure
git_clone_https() {
  local url="$1"
  local dest="$2"

  # Validate arguments
  if [[ -z "$url" || -z "$dest" ]]; then
    echo "Usage: git_clone_https <url> <destination>" >&2
    return 1
  fi

  # First try normal clone (works if HTTPS is properly configured)
  if git clone "$url" "$dest" 2>/dev/null; then
    return 0
  fi

  # If that fails, force HTTPS by disabling common SSH rewrites
  # This handles cases where user has url.<base>.insteadOf configured
  if declare -f log &>/dev/null; then
    log "Retrying with forced HTTPS..."
  fi

  if git -c url."https://github.com/".insteadOf="git@github.com:" \
         -c url."https://github.com/".insteadOf="ssh://git@github.com/" \
         -c url."https://gitlab.com/".insteadOf="git@gitlab.com:" \
         -c url."https://bitbucket.org/".insteadOf="git@bitbucket.org:" \
         clone "$url" "$dest" 2>/dev/null; then
    return 0
  fi

  # Final attempt: disable SSH entirely for this operation
  GIT_SSH_COMMAND="false" git clone "$url" "$dest" 2>/dev/null
}

# Update a git repository, falling back to HTTPS if SSH fails
# Usage: git_pull_https <repo_path>
git_pull_https() {
  local repo_path="$1"

  if [[ -z "$repo_path" || ! -d "$repo_path" ]]; then
    return 1
  fi

  # First try normal pull
  if git -C "$repo_path" pull 2>/dev/null; then
    return 0
  fi

  # Force HTTPS
  git -C "$repo_path" \
    -c url."https://github.com/".insteadOf="git@github.com:" \
    -c url."https://github.com/".insteadOf="ssh://git@github.com/" \
    pull 2>/dev/null
}
