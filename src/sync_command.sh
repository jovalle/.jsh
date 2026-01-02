# jsh sync - Sync jsh changes with remote repository
#
# Usage:
#   jsh sync              - Pull then push changes
#   jsh sync --pull       - Pull changes only
#   jsh sync --push       - Push changes only
#   jsh sync --stash      - Stash local changes before syncing
#
# This command helps keep your jsh configuration synchronized across machines.
# It handles git operations safely and provides clear feedback.

root_dir="$(get_root_dir)"
pull_only="${args[--pull]:-}"
push_only="${args[--push]:-}"
do_stash="${args[--stash]:-}"
force_sync="${args[--force]:-}"

header "Syncing jsh repository"

# Ensure we're in a git repository
if [[ ! -d "${root_dir}/.git" ]]; then
  error "Not a git repository: ${root_dir}"
  exit 1
fi

cd "${root_dir}" || exit 1

# Check for remote
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$remote_url" ]]; then
  error "No remote 'origin' configured"
  info "Add a remote with: git remote add origin <url>"
  exit 1
fi

info "Remote: $remote_url"
echo ""

# Get current branch
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
info "Branch: $current_branch"

# Check for uncommitted changes
has_changes=false
if ! git diff --quiet HEAD 2>/dev/null; then
  has_changes=true
fi

if ! git diff --cached --quiet 2>/dev/null; then
  has_changes=true
fi

# Handle uncommitted changes
if [[ "$has_changes" == "true" ]]; then
  echo ""
  warn "You have uncommitted changes:"
  git status --short
  echo ""

  if [[ -n "$do_stash" ]]; then
    log "Stashing changes..."
    stash_msg="jsh sync stash $(date '+%Y-%m-%d %H:%M:%S')"
    git stash push -m "$stash_msg"
    info "Changes stashed: $stash_msg"
  elif [[ -z "$push_only" ]]; then
    # For pull operations, we need clean state
    error "Cannot pull with uncommitted changes"
    info "Options:"
    info "  1. Commit your changes first"
    info "  2. Run with --stash to stash changes"
    info "  3. Run with --push to only push (skip pull)"
    exit 1
  fi
fi

# Fetch latest from remote
log "Fetching from remote..."
if ! git fetch origin "$current_branch" 2>/dev/null; then
  warn "Could not fetch from remote (offline or no access)"
fi

# Pull changes
if [[ -z "$push_only" ]]; then
  echo ""
  log "Pulling changes..."

  # Check if we need to pull
  local_hash=$(git rev-parse HEAD 2>/dev/null)
  remote_hash=$(git rev-parse "origin/$current_branch" 2>/dev/null || echo "")

  if [[ -z "$remote_hash" ]]; then
    info "No remote branch found, skipping pull"
  elif [[ "$local_hash" == "$remote_hash" ]]; then
    info "Already up to date"
  else
    # Count commits behind
    commits_behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null || echo 0)

    if [[ "$commits_behind" -gt 0 ]]; then
      info "Pulling $commits_behind commit(s)..."

      if [[ -n "$force_sync" ]]; then
        git reset --hard "origin/$current_branch"
        success "Force updated to remote"
      else
        if git pull --rebase origin "$current_branch"; then
          success "Pulled $commits_behind commit(s)"
        else
          error "Pull failed - you may have conflicts"
          info "Resolve conflicts and run 'jsh sync' again"
          exit 1
        fi
      fi
    fi
  fi
fi

# Push changes
if [[ -z "$pull_only" ]]; then
  echo ""
  log "Pushing changes..."

  # Check if we have commits to push
  commits_ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null || echo 0)

  if [[ "$commits_ahead" -eq 0 ]]; then
    info "Nothing to push"
  else
    info "Pushing $commits_ahead commit(s)..."

    if git push origin "$current_branch"; then
      success "Pushed $commits_ahead commit(s)"
    else
      error "Push failed"
      info "Check your remote access and try again"
      exit 1
    fi
  fi
fi

# Restore stashed changes
if [[ -n "$do_stash" && "$has_changes" == "true" ]]; then
  echo ""
  log "Restoring stashed changes..."
  if git stash pop; then
    success "Stashed changes restored"
  else
    warn "Could not restore stash - conflicts may exist"
    info "Your changes are still in the stash. Run 'git stash list' to see them."
  fi
fi

# Update submodules if present
if [[ -f "${root_dir}/.gitmodules" ]]; then
  echo ""
  log "Updating submodules..."
  # Check if .git directory is writable (handles read-only mounts)
  if [[ -d "${root_dir}/.git" ]] && [[ ! -w "${root_dir}/.git" ]]; then
    warn "Git directory is read-only, skipping submodule update"
  elif git submodule update --init --recursive 2>/dev/null; then
    success "Submodules updated"
  else
    warn "Could not update submodules (read-only filesystem?)"
  fi
fi

echo ""
success "Sync complete!"

# Show current status
echo ""
info "Current status:"
git log --oneline -3
