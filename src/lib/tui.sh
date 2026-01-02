# TUI Progress Display Library for jsh
#
# Provides cargo-style progress displays with:
# - Scrolling log region (top)
# - Fixed status bar (bottom) with progress bar, count, current item, elapsed time
#
# Environment Variables:
#   JSH_NO_TUI=1     - Disable TUI, use simple line output
#   JSH_FORCE_TUI=1  - Force TUI even in non-interactive mode (testing)
#   JSH_DEBUG_TUI=1  - Debug TUI operations
#
# Usage:
#   source "$root_dir/src/lib/tui.sh"
#   tui_init || true  # OK if fails, uses fallback
#   tui_progress_start "Installing packages" 10
#   for pkg in "${packages[@]}"; do
#     tui_progress_next "$pkg"
#     # ... install ...
#   done
#   tui_progress_complete

# shellcheck disable=SC2034

# =============================================================================
# State Variables
# =============================================================================

_TUI_ENABLED=""         # Whether TUI mode is active
_TUI_SCROLLING_TOP=1    # Top line of scrolling region
_TUI_SCROLLING_BOTTOM=0 # Bottom line of scrolling region
_TUI_STATUS_LINE=0      # Line number for status bar
_TUI_TERM_HEIGHT=0      # Terminal height
_TUI_TERM_WIDTH=0       # Terminal width

# Progress state
_TUI_OPERATION=""    # Current operation name
_TUI_CURRENT=0       # Current item number
_TUI_TOTAL=0         # Total items (0 = indeterminate/spinner)
_TUI_CURRENT_ITEM="" # Name of current item being processed
_TUI_START_TIME=0    # Epoch timestamp when operation started

# Spinner state
_TUI_SPINNER_IDX=0 # Current spinner frame index

# Background animation state
_TUI_ANIM_PID=""  # PID of background animation process
_TUI_ANIM_FIFO="" # FIFO for state communication

# =============================================================================
# Terminal Control Sequences
# =============================================================================

# These are set during tui_init based on terminal capabilities
_TUI_SAVE_CURSOR=""
_TUI_RESTORE_CURSOR=""
_TUI_HIDE_CURSOR=""
_TUI_SHOW_CURSOR=""

# =============================================================================
# Capability Detection
# =============================================================================

# Check if terminal supports TUI features
# Returns: 0 if supported, 1 if not
tui_is_supported() {
  # Already determined?
  if [[ "${_TUI_SUPPORTED:-}" == "1" ]]; then
    return 0
  elif [[ "${_TUI_SUPPORTED:-}" == "0" ]]; then
    return 1
  fi

  # Check for forced disable
  if [[ -n "${JSH_NO_TUI:-}" ]]; then
    _TUI_SUPPORTED=0
    return 1
  fi

  # Must be interactive terminal (unless forced)
  if [[ ! -t 1 ]] && [[ -z "${JSH_FORCE_TUI:-}" ]]; then
    _TUI_SUPPORTED=0
    return 1
  fi

  # Check TERM is set and not dumb
  if [[ -z "${TERM:-}" ]] || [[ "$TERM" == "dumb" ]]; then
    _TUI_SUPPORTED=0
    return 1
  fi

  # Check for tput availability
  if ! command -v tput &> /dev/null; then
    _TUI_SUPPORTED=0
    return 1
  fi

  # Check required tput capabilities
  if ! tput lines &> /dev/null || ! tput cols &> /dev/null; then
    _TUI_SUPPORTED=0
    return 1
  fi

  # Check for scrolling region support (csr capability)
  # Note: Not all terminals support this, fall back to simpler approach if not
  if ! tput csr 0 10 &> /dev/null 2>&1; then
    # Try ANSI escape directly
    if ! printf '\033[1;10r' &> /dev/null 2>&1; then
      _TUI_SUPPORTED=0
      return 1
    fi
    # Reset scrolling region
    printf '\033[r' > /dev/null 2>&1
  else
    # Reset scrolling region
    tput csr 0 "$(tput lines)" > /dev/null 2>&1
  fi

  _TUI_SUPPORTED=1
  return 0
}

# =============================================================================
# Initialization and Cleanup
# =============================================================================

# Initialize TUI mode with scrolling region
# Arguments:
#   $1 - status_lines: Number of lines to reserve for status bar (default: 1)
# Returns: 0 on success, 1 if TUI not supported (falls back to simple mode)
tui_init() {
  local status_lines="${1:-1}"

  # Check if TUI should be enabled
  if ! tui_is_supported; then
    _TUI_ENABLED=""
    [[ -n "${JSH_DEBUG_TUI:-}" ]] && echo "[tui:debug] TUI not supported, using fallback" >&2
    return 1
  fi

  # Set up terminal control sequences
  _TUI_HIDE_CURSOR=$(tput civis 2> /dev/null || printf '\033[?25l')
  _TUI_SHOW_CURSOR=$(tput cnorm 2> /dev/null || printf '\033[?25h')

  # Get terminal dimensions
  local size_output
  if size_output=$(stty size 2> /dev/null) && [[ -n "$size_output" ]]; then
    _TUI_TERM_HEIGHT="${size_output%% *}"
    _TUI_TERM_WIDTH="${size_output##* }"
  else
    _TUI_TERM_HEIGHT=$(tput lines 2> /dev/null || echo 24)
    _TUI_TERM_WIDTH=$(tput cols 2> /dev/null || echo 80)
  fi

  # Ensure we have valid numbers
  [[ "$_TUI_TERM_HEIGHT" =~ ^[0-9]+$ ]] || _TUI_TERM_HEIGHT=24
  [[ "$_TUI_TERM_WIDTH" =~ ^[0-9]+$ ]] || _TUI_TERM_WIDTH=80

  # Hide cursor during TUI operations
  printf '%b' "$_TUI_HIDE_CURSOR"

  # Calculate regions (all 1-indexed for ANSI)
  # We'll use the bottom of the current viewport for the status bar
  # Scrolling region: rows 1 to (height - status_lines)
  # Status bar: last row (height)
  _TUI_SCROLLING_TOP=1
  _TUI_SCROLLING_BOTTOM=$((_TUI_TERM_HEIGHT - status_lines))
  _TUI_STATUS_LINE=$_TUI_TERM_HEIGHT

  # Push existing content up and create space for our TUI
  # Print enough newlines to ensure we have a clean working area
  local i
  for ((i = 0; i < _TUI_TERM_HEIGHT; i++)); do
    printf '\n'
  done

  # Move to top of screen
  printf '\033[H'

  # Set up scrolling region using ANSI DECSTBM (1-indexed)
  # This makes the status bar line fixed while content above scrolls
  printf '\033[%d;%dr' "$_TUI_SCROLLING_TOP" "$_TUI_SCROLLING_BOTTOM"

  # Move cursor to top of scrolling region
  printf '\033[%d;1H' "$_TUI_SCROLLING_TOP"

  # Draw initial empty status bar at the fixed bottom position
  _tui_draw_status_bar

  # Set trap for cleanup
  trap 'tui_cleanup' EXIT INT TERM

  _TUI_ENABLED=1
  [[ -n "${JSH_DEBUG_TUI:-}" ]] && echo "[tui:debug] TUI initialized: ${_TUI_TERM_WIDTH}x${_TUI_TERM_HEIGHT}, scroll region ${_TUI_SCROLLING_TOP}-${_TUI_SCROLLING_BOTTOM}, status at row ${_TUI_STATUS_LINE}" >&2
  return 0
}

# Cleanup TUI mode and restore terminal
tui_cleanup() {
  # Remove trap to prevent recursion
  trap - EXIT INT TERM

  # Stop background animation
  _tui_anim_stop

  if [[ -n "$_TUI_ENABLED" ]]; then
    # Get current cursor row before resetting (this is where content ended)
    # Use escape sequence to query, with fallback
    local cursor_row=""
    if read -rs -t0.1 -d'R' -p $'\033[6n' cursor_pos 2> /dev/null; then
      cursor_row="${cursor_pos#*[}"
      cursor_row="${cursor_row%;*}"
    fi

    # Reset scrolling region to full terminal
    printf '\033[r'

    # Clear the status bar line (move there, clear, move back)
    printf '\033[%d;1H\033[2K' "$_TUI_STATUS_LINE"

    # Return to content position (or stay at bottom-1 if query failed)
    if [[ -n "$cursor_row" && "$cursor_row" =~ ^[0-9]+$ ]]; then
      printf '\033[%d;1H' "$cursor_row"
    else
      printf '\033[%d;1H' "$_TUI_SCROLLING_BOTTOM"
    fi

    # Show cursor
    printf '%b' "$_TUI_SHOW_CURSOR"

    _TUI_ENABLED=""
    [[ -n "${JSH_DEBUG_TUI:-}" ]] && echo "[tui:debug] TUI cleanup complete" >&2
  fi

  # Reset state
  _TUI_OPERATION=""
  _TUI_CURRENT=0
  _TUI_TOTAL=0
  _TUI_CURRENT_ITEM=""
  _TUI_START_TIME=0
}

# =============================================================================
# Progress Bar Rendering
# =============================================================================

# Draw a progress bar
# Arguments:
#   $1 - current: Current value
#   $2 - total: Total value
#   $3 - width: Bar width in characters (default: 20)
# Output: Progress bar string like "████████░░░░░░░░░░░░"
_tui_progress_bar() {
  local current=$1
  local total=$2
  local width=${3:-20}

  if [[ $total -eq 0 ]]; then
    # Empty bar for indeterminate
    printf '%*s' "$width" "" | tr ' ' '░'
    return
  fi

  # Clamp current to valid range before calculation
  [[ $current -lt 0 ]] && current=0
  [[ $current -gt $total ]] && current=$total

  local filled=$((current * width / total))
  local empty=$((width - filled))

  # Clamp values (safety check)
  [[ $filled -gt $width ]] && filled=$width
  [[ $filled -lt 0 ]] && filled=0
  [[ $empty -lt 0 ]] && empty=0

  local bar=""
  if [[ $filled -gt 0 ]]; then
    bar+=$(printf '%*s' "$filled" "" | tr ' ' '█')
  fi
  if [[ $empty -gt 0 ]]; then
    bar+=$(printf '%*s' "$empty" "" | tr ' ' '░')
  fi

  printf '%s' "$bar"
}

# Get spinner character for current frame
_tui_spinner_char() {
  local spinner_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local len=${#spinner_chars}
  local idx=$((_TUI_SPINNER_IDX % len))
  printf '%s' "${spinner_chars:$idx:1}"
}

# Advance spinner to next frame
_tui_spinner_advance() {
  _TUI_SPINNER_IDX=$((_TUI_SPINNER_IDX + 1))
}

# =============================================================================
# Background Animation
# =============================================================================

# Start background animation loop
# This runs a subprocess that periodically redraws the status bar
# to keep the spinner animated and timer updated
_tui_anim_start() {
  [[ -z "$_TUI_ENABLED" ]] && return 0
  [[ -n "$_TUI_ANIM_PID" ]] && return 0 # Already running

  # Create state file for communication (faster than FIFO for reads)
  _TUI_ANIM_FIFO="${TMPDIR:-/tmp}/tui_state_$$"

  # Write initial state
  _tui_anim_write_state

  # Start background animation loop
  (
    local spinner_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local spinner_len=${#spinner_chars}
    local idx=0
    local interval=0.1 # 100ms refresh rate

    while true; do
      # Check if state file still exists (signals shutdown)
      [[ ! -f "$_TUI_ANIM_FIFO" ]] && break

      # Read current state
      local operation="" total=0 current=0 item="" start_time=0 term_width=80 status_line=1 scroll_bottom=1
      if [[ -f "$_TUI_ANIM_FIFO" ]]; then
        # shellcheck disable=SC1090
        source "$_TUI_ANIM_FIFO" 2> /dev/null || true
      fi

      # Skip if no operation
      [[ -z "$operation" ]] && {
        sleep "$interval"
        continue
      }

      # Build status line
      local spinner="${spinner_chars:$((idx % spinner_len)):1}"
      idx=$((idx + 1))

      local status=""
      local elapsed="" eta=""

      # Calculate times
      if [[ "$start_time" -gt 0 ]]; then
        local now elapsed_secs
        now=$(date +%s)
        elapsed_secs=$((now - start_time))

        # Format elapsed time
        if [[ $elapsed_secs -ge 60 ]]; then
          elapsed="$((elapsed_secs / 60))m$((elapsed_secs % 60))s"
        else
          elapsed="${elapsed_secs}s"
        fi

        # Calculate ETA if we have progress
        if [[ "$total" -gt 0 ]] && [[ "$current" -gt 0 ]]; then
          local avg_per_item=$((elapsed_secs * 100 / current)) # centiseconds
          local remaining_items=$((total - current))
          local eta_secs=$((remaining_items * avg_per_item / 100))
          if [[ $eta_secs -ge 60 ]]; then
            eta="~$((eta_secs / 60))m$((eta_secs % 60))s remaining"
          elif [[ $eta_secs -gt 0 ]]; then
            eta="~${eta_secs}s remaining"
          fi
        fi
      fi

      # Build the status string with ANSI codes
      # Operation name (cyan)
      status="\033[36m${operation}\033[0m "

      # Progress bar or spinner
      if [[ "$total" -gt 0 ]]; then
        # Determinate progress bar
        local bar_width=20
        local filled=$((current * bar_width / total))
        [[ $filled -gt $bar_width ]] && filled=$bar_width
        [[ $filled -lt 0 ]] && filled=0
        local empty=$((bar_width - filled))

        local bar=""
        [[ $filled -gt 0 ]] && bar+=$(printf '%*s' "$filled" "" | tr ' ' '█')
        [[ $empty -gt 0 ]] && bar+=$(printf '%*s' "$empty" "" | tr ' ' '░')
        status+="[${bar}] ${current}/${total}"
      else
        # Indeterminate spinner
        status+="[$spinner] "
      fi

      # Current item (bold)
      if [[ -n "$item" ]]; then
        status+=" \033[1m${item}\033[0m"
      fi

      # Time display (yellow) - show ETA if available, otherwise elapsed
      if [[ -n "$eta" ]]; then
        status+=" \033[33m(${eta})\033[0m"
      elif [[ -n "$elapsed" ]]; then
        status+=" \033[33m(${elapsed})\033[0m"
      fi

      # Draw status bar - position cursor to scroll_bottom after to avoid race with main process
      printf '\033[%d;1H' "$status_line"   # Move to status line
      printf '\033[2K'                     # Clear line
      printf '%b' "$status"                # Print status
      printf '\033[%d;1H' "$scroll_bottom" # Return to scroll region bottom

      sleep "$interval"
    done
  ) &
  _TUI_ANIM_PID=$!

  [[ -n "${JSH_DEBUG_TUI:-}" ]] && echo "[tui:debug] Animation started with PID $_TUI_ANIM_PID" >&2
}

# Write current state to file for animation process
_tui_anim_write_state() {
  [[ -z "$_TUI_ANIM_FIFO" ]] && return 0

  cat > "$_TUI_ANIM_FIFO" << EOF
operation="$_TUI_OPERATION"
total=$_TUI_TOTAL
current=$_TUI_CURRENT
item="$_TUI_CURRENT_ITEM"
start_time=$_TUI_START_TIME
term_width=$_TUI_TERM_WIDTH
status_line=$_TUI_STATUS_LINE
scroll_bottom=$_TUI_SCROLLING_BOTTOM
EOF
}

# Stop background animation
_tui_anim_stop() {
  if [[ -n "$_TUI_ANIM_PID" ]]; then
    # Remove state file first (signals the loop to exit)
    [[ -n "$_TUI_ANIM_FIFO" ]] && rm -f "$_TUI_ANIM_FIFO"

    # Kill the process if still running
    kill "$_TUI_ANIM_PID" 2> /dev/null || true
    wait "$_TUI_ANIM_PID" 2> /dev/null || true

    [[ -n "${JSH_DEBUG_TUI:-}" ]] && echo "[tui:debug] Animation stopped" >&2
    _TUI_ANIM_PID=""
    _TUI_ANIM_FIFO=""
  fi
}

# =============================================================================
# Status Bar Rendering
# =============================================================================

# Draw the status bar at the fixed bottom position
_tui_draw_status_bar() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    return 0
  fi

  # Save cursor position (ESC 7 = DECSC)
  printf '\0337'

  # Move to status line (1-indexed)
  printf '\033[%d;1H' "$_TUI_STATUS_LINE"

  # Clear the line
  printf '\033[2K'

  # Build status content if we have an active operation
  if [[ -n "$_TUI_OPERATION" ]]; then
    local status=""
    local bar_width=20
    local elapsed=""

    # Calculate elapsed time
    if [[ "$_TUI_START_TIME" -gt 0 ]]; then
      local now elapsed_secs
      now=$(date +%s)
      elapsed_secs=$((now - _TUI_START_TIME))
      if [[ $elapsed_secs -ge 60 ]]; then
        elapsed="$((elapsed_secs / 60))m$((elapsed_secs % 60))s"
      else
        elapsed="${elapsed_secs}s"
      fi
    fi

    # Operation name (cyan)
    status="${CYAN}${_TUI_OPERATION}${RESET} "

    # Progress bar or spinner
    if [[ "$_TUI_TOTAL" -gt 0 ]]; then
      # Determinate progress bar
      local bar
      bar=$(_tui_progress_bar "$_TUI_CURRENT" "$_TUI_TOTAL" "$bar_width")
      status+="[${bar}] "
      status+="${_TUI_CURRENT}/${_TUI_TOTAL}"
    else
      # Indeterminate spinner
      _tui_spinner_advance
      local spinner
      spinner=$(_tui_spinner_char)
      status+="[$spinner] "
    fi

    # Current item (bold)
    if [[ -n "$_TUI_CURRENT_ITEM" ]]; then
      status+=" ${BOLD}${_TUI_CURRENT_ITEM}${RESET}"
    fi

    # Elapsed time (yellow)
    if [[ -n "$elapsed" ]]; then
      status+=" ${YELLOW}(${elapsed})${RESET}"
    fi

    # Print the status
    printf '%b' "$status"
  fi

  # Restore cursor position (using ESC 8 which is more reliable)
  printf '\0338'
}

# Clear the status bar area (alias for backward compatibility)
_tui_clear_status_area() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    return 0
  fi

  printf '\0337'                          # Save cursor (ESC 7)
  printf '\033[%d;1H' "$_TUI_STATUS_LINE" # Move to status line
  printf '\033[2K'                        # Clear line
  printf '\0338'                          # Restore cursor (ESC 8)
}

# Render the status bar (alias for _tui_draw_status_bar)
_tui_render_status() {
  _tui_draw_status_bar
}

# =============================================================================
# Single-Process Animated Command Runner
# =============================================================================

# Run a command with animated progress (single-process, no race conditions)
# Arguments:
#   $1 - command to run (will be eval'd)
# Output lines are displayed in scroll region, status bar animates
# Returns: exit code of the command
tui_run_animated() {
  local cmd="$1"
  local output_file="${TMPDIR:-/tmp}/tui_output_$$"
  local pid_file="${TMPDIR:-/tmp}/tui_pid_$$"
  local interval=0.1
  local spinner_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local spinner_len=${#spinner_chars}
  local lines_read=0

  # Fallback if TUI not enabled
  if [[ -z "$_TUI_ENABLED" ]]; then
    eval "$cmd"
    return $?
  fi

  # Start command in background, capture output
  : > "$output_file"
  (
    eval "$cmd" > "$output_file" 2>&1
    echo $? > "$pid_file"
  ) &

  # Poll for output while command runs
  while true; do
    # Check if command finished
    if [[ -f "$pid_file" ]]; then
      # Process any remaining output
      local line
      tail -n +$((lines_read + 1)) "$output_file" 2> /dev/null | while IFS= read -r line; do
        [[ -n "$line" ]] && echo -e "${BLUE}[*]${RESET} $line"
      done
      break
    fi

    # Read new lines from output file
    local new_lines
    new_lines=$(tail -n +$((lines_read + 1)) "$output_file" 2> /dev/null)
    if [[ -n "$new_lines" ]]; then
      local line
      while IFS= read -r line; do
        [[ -n "$line" ]] && echo -e "${BLUE}[*]${RESET} $line"
        ((lines_read++))
      done <<< "$new_lines"
    fi

    # Update spinner and redraw status bar
    _tui_spinner_advance
    _tui_draw_status_bar

    sleep "$interval"
  done

  # Get exit code
  local exit_code=0
  [[ -f "$pid_file" ]] && exit_code=$(cat "$pid_file")

  # Cleanup
  rm -f "$output_file" "$pid_file"

  # Final status bar update
  _tui_draw_status_bar

  return "${exit_code:-0}"
}

# =============================================================================
# Progress Management
# =============================================================================

# Start a new progress operation
# Arguments:
#   $1 - operation: Name of the operation (e.g., "Installing packages")
#   $2 - total: Total number of items (0 for indeterminate)
tui_progress_start() {
  local operation="$1"
  local total="${2:-0}"

  _TUI_OPERATION="$operation"
  _TUI_TOTAL="$total"
  _TUI_CURRENT=0
  _TUI_CURRENT_ITEM=""
  _TUI_START_TIME=$(date +%s)
  _TUI_SPINNER_IDX=0

  if [[ -z "$_TUI_ENABLED" ]]; then
    # Fallback: use header
    header "$operation"
    return 0
  fi

  # Background animation disabled - causes issues with log output display
  # _tui_anim_start

  _tui_render_status
}

# Update progress to next item
# Arguments:
#   $1 - item_name: Name of current item
tui_progress_next() {
  local item="${1:-}"

  _TUI_CURRENT=$((_TUI_CURRENT + 1))
  _TUI_CURRENT_ITEM="$item"

  if [[ -z "$_TUI_ENABLED" ]]; then
    # Fallback: log with count
    if [[ "$_TUI_TOTAL" -gt 0 ]]; then
      log "[$_TUI_CURRENT/$_TUI_TOTAL] $item"
    else
      log "$item"
    fi
    return 0
  fi

  # Update state for background animation
  _tui_anim_write_state

  _tui_render_status
}

# Update progress with specific count
# Arguments:
#   $1 - current: Current item number
#   $2 - item_name: Name of current item (optional)
tui_progress_update() {
  local current="$1"
  local item="${2:-}"

  _TUI_CURRENT="$current"
  [[ -n "$item" ]] && _TUI_CURRENT_ITEM="$item"

  if [[ -z "$_TUI_ENABLED" ]]; then
    # Fallback: log with count
    if [[ "$_TUI_TOTAL" -gt 0 ]]; then
      log "[$_TUI_CURRENT/$_TUI_TOTAL] ${item:-processing...}"
    else
      log "${item:-processing...}"
    fi
    return 0
  fi

  # Update state for background animation
  _tui_anim_write_state

  _tui_render_status
}

# Mark progress as complete
# Arguments:
#   $1 - message: Completion message (optional)
tui_progress_complete() {
  local message="${1:-}"

  # Stop background animation first
  _tui_anim_stop

  if [[ -z "$_TUI_ENABLED" ]]; then
    # Fallback: success message
    if [[ -n "$message" ]]; then
      success "$message"
    elif [[ -n "$_TUI_OPERATION" ]]; then
      success "${_TUI_OPERATION} complete"
    fi
  else
    # Clear status and show completion in scroll area
    _tui_clear_status_area
    if [[ -n "$message" ]]; then
      tui_success "$message"
    elif [[ -n "$_TUI_OPERATION" ]]; then
      tui_success "${_TUI_OPERATION} complete"
    fi
  fi

  # Reset progress state
  _TUI_OPERATION=""
  _TUI_CURRENT=0
  _TUI_TOTAL=0
  _TUI_CURRENT_ITEM=""
  _TUI_START_TIME=0
}

# Mark progress as failed
# Arguments:
#   $1 - message: Error message (optional)
tui_progress_fail() {
  local message="${1:-}"

  # Stop background animation first
  _tui_anim_stop

  if [[ -z "$_TUI_ENABLED" ]]; then
    # Fallback: error message (but don't exit)
    if [[ -n "$message" ]]; then
      warn "$message"
    elif [[ -n "$_TUI_OPERATION" ]]; then
      warn "${_TUI_OPERATION} failed"
    fi
  else
    # Clear status and show failure in scroll area
    _tui_clear_status_area
    if [[ -n "$message" ]]; then
      tui_warn "$message"
    elif [[ -n "$_TUI_OPERATION" ]]; then
      tui_warn "${_TUI_OPERATION} failed"
    fi
  fi

  # Reset progress state
  _TUI_OPERATION=""
  _TUI_CURRENT=0
  _TUI_TOTAL=0
  _TUI_CURRENT_ITEM=""
  _TUI_START_TIME=0
}

# =============================================================================
# Output Functions (scroll-aware)
# =============================================================================

# Log message to scrolling region
tui_log() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    log "$@"
    return
  fi

  # Print message (will scroll within region)
  echo -e "${BLUE}[*]${RESET} $*"

  # Refresh status bar
  _tui_render_status
}

# Success message to scrolling region
tui_success() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    success "$@"
    return
  fi

  echo -e "${GREEN}[✓]${RESET} $*"
  _tui_render_status
}

# Warning message to scrolling region
tui_warn() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    warn "$@"
    return
  fi

  echo -e "${YELLOW}[!]${RESET} $*"
  _tui_render_status
}

# Error message to scrolling region (does NOT exit)
tui_error() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    # Note: Using warn instead of error to avoid exit
    echo -e "${RED}[✗] $*${RESET}"
    return
  fi

  echo -e "${RED}[✗]${RESET} $*"
  _tui_render_status
}

# Info message to scrolling region
tui_info() {
  if [[ -z "$_TUI_ENABLED" ]]; then
    info "$@"
    return
  fi

  echo -e "${CYAN}[i]${RESET} $*"
  _tui_render_status
}
