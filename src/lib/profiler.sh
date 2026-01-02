#!/usr/bin/env bash
# Shell initialization profiling library (bash/zsh compatible)
# Usage:
#   source /path/to/profiler.sh
#   profile_init
#   profile_start "section_name" "description"
#   # ... code to profile ...
#   profile_end "section_name"
#   profile_report

# Enable profiling only if JSH_PROFILE is set
: "${JSH_PROFILE:=0}"

# Profiling data storage - file-based for shell compatibility
# Using files avoids associative array issues across bash/zsh versions
_PROFILE_DIR="${HOME}/.cache/jsh/profile/current"
_PROFILE_TOTAL_START=0
_PROFILE_ENABLED=0

# Initialize profiling
profile_init() {
  if [[ "${JSH_PROFILE}" != "1" ]]; then
    return 0
  fi

  _PROFILE_ENABLED=1

  # Clean up any previous profile run
  rm -rf "${_PROFILE_DIR}" 2> /dev/null
  mkdir -p "${_PROFILE_DIR}"

  _PROFILE_TOTAL_START=$(get_time_ms)
  echo "${_PROFILE_TOTAL_START}" > "${_PROFILE_DIR}/_total_start"
  : > "${_PROFILE_DIR}/_order" # Create empty order file
}

# Get current time in milliseconds
get_time_ms() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS
    python3 -c 'import time; print(int(time.time() * 1000))'
  else
    # Linux
    date +%s%3N
  fi
}

# Start profiling a section
profile_start() {
  [[ "${_PROFILE_ENABLED}" != "1" ]] && [[ ! -d "${_PROFILE_DIR}" ]] && return 0

  local section_name="$1"
  local description="${2:-$section_name}"

  # Store start time and description in files
  get_time_ms > "${_PROFILE_DIR}/${section_name}.start"
  echo "${description}" > "${_PROFILE_DIR}/${section_name}.desc"

  # Track order of sections
  if ! grep -qx "${section_name}" "${_PROFILE_DIR}/_order" 2> /dev/null; then
    echo "${section_name}" >> "${_PROFILE_DIR}/_order"
  fi
}

# End profiling a section
profile_end() {
  [[ "${_PROFILE_ENABLED}" != "1" ]] && [[ ! -d "${_PROFILE_DIR}" ]] && return 0

  local section_name="$1"

  if [[ ! -f "${_PROFILE_DIR}/${section_name}.start" ]]; then
    echo "Warning: profile_end called for '$section_name' without matching profile_start" >&2
    return 1
  fi

  get_time_ms > "${_PROFILE_DIR}/${section_name}.end"
}

# Get duration for a section in milliseconds
profile_duration() {
  local section_name="$1"
  local start_file="${_PROFILE_DIR}/${section_name}.start"
  local end_file="${_PROFILE_DIR}/${section_name}.end"

  if [[ ! -f "${start_file}" ]] || [[ ! -f "${end_file}" ]]; then
    echo "0"
    return 1
  fi

  local start end
  start=$(cat "${start_file}")
  end=$(cat "${end_file}")
  echo $((end - start))
}

# Generate profiling report
profile_report() {
  [[ ! -d "${_PROFILE_DIR}" ]] && return 0

  local total_end total_start total_duration
  total_end=$(get_time_ms)
  total_start=$(cat "${_PROFILE_DIR}/_total_start" 2> /dev/null || echo "$total_end")
  total_duration=$((total_end - total_start))

  # Output format
  local output_format="${JSH_PROFILE_FORMAT:-table}"
  local output_file="${JSH_PROFILE_OUTPUT:-}"

  # Generate report
  local report=""
  report+="=== Shell Initialization Profile ===\n"
  report+="\n"
  report+="Date: $(date '+%Y-%m-%d %H:%M:%S')\n"
  report+="Total Duration: ${total_duration} ms\n"
  report+="\n"

  if [[ "$output_format" == "json" ]]; then
    profile_report_json
    return
  fi

  # Table format (default) - use actual newlines for compatibility
  {
    echo "┌─────────────────────────────────────────┬──────────┬─────────┐"
    echo "│ Section                                 │ Time (ms)│ % Total │"
    echo "├─────────────────────────────────────────┼──────────┼─────────┤"

    local accumulated_time=0 duration description percentage
    while IFS= read -r section || [[ -n "$section" ]]; do
      [[ -z "$section" ]] && continue
      # Skip wrapper sections (they contain other sections, would double-count)
      [[ "$section" == *"_total" ]] && continue

      duration=$(profile_duration "$section")
      description=$(cat "${_PROFILE_DIR}/${section}.desc" 2> /dev/null || echo "$section")
      percentage=0

      if [[ "$total_duration" -gt 0 ]]; then
        percentage=$((duration * 100 / total_duration))
      fi

      accumulated_time=$((accumulated_time + duration))

      # Truncate description if too long
      if [[ ${#description} -gt 39 ]]; then
        description="${description:0:36}..."
      fi

      printf "│ %-39s │ %8d │ %6d%% │\n" "$description" "$duration" "$percentage"
    done < "${_PROFILE_DIR}/_order"

    # Calculate unaccounted time
    local unaccounted=$((total_duration - accumulated_time))
    local unaccounted_pct=0
    if [[ "$total_duration" -gt 0 ]] && [[ "$unaccounted" -gt 0 ]]; then
      unaccounted_pct=$((unaccounted * 100 / total_duration))
      printf "│ %-39s │ %8d │ %6d%% │\n" "(other: keybindings, options, etc.)" "$unaccounted" "$unaccounted_pct"
    fi

    echo "├─────────────────────────────────────────┼──────────┼─────────┤"
    printf "│ %-39s │ %8d │ %6d%% │\n" "TOTAL (wall-clock)" "$total_duration" "100"
    echo "└─────────────────────────────────────────┴──────────┴─────────┘"

    # Top 5 slowest sections
    echo ""
    echo "=== Top 5 Slowest Sections ==="

    # Build sorted list from files
    local sorted_output="" count=0
    while IFS= read -r section || [[ -n "$section" ]]; do
      [[ -z "$section" ]] && continue
      # Skip wrapper sections
      [[ "$section" == *"_total" ]] && continue
      duration=$(profile_duration "$section")
      sorted_output+="${duration}|${section}"$'\n'
    done < "${_PROFILE_DIR}/_order"

    # Sort by duration (descending) and show top 5
    count=0
    echo "$sorted_output" | sort -t'|' -k1 -rn | head -5 | while IFS='|' read -r dur sec; do
      [[ -z "$sec" ]] && continue
      description=$(cat "${_PROFILE_DIR}/${sec}.desc" 2> /dev/null || echo "$sec")
      printf "%2d. %-40s %6d ms\n" $((count + 1)) "$description" "$dur"
      count=$((count + 1))
    done
  } >&2
}

# Generate JSON format report
profile_report_json() {
  local total_end total_duration
  total_end=$(get_time_ms)
  total_duration=$((total_end - _PROFILE_TOTAL_START))
  local output_file="${JSH_PROFILE_OUTPUT:-}"

  local json="{\n"
  json+="  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\n"
  json+="  \"total_duration_ms\": $total_duration,\n"
  json+="  \"sections\": [\n"

  local first=1 section duration description percentage
  while IFS= read -r section || [[ -n "$section" ]]; do
    [[ -z "$section" ]] && continue
    duration=$(profile_duration "$section")
    description=$(cat "${_PROFILE_DIR}/${section}.desc" 2> /dev/null || echo "$section")
    percentage=0

    if [[ "$total_duration" -gt 0 ]]; then
      percentage=$((duration * 100 / total_duration))
    fi

    if [[ $first -eq 0 ]]; then
      json+=",\n"
    fi
    first=0

    json+="    {\n"
    json+="      \"name\": \"$section\",\n"
    json+="      \"description\": \"$description\",\n"
    json+="      \"duration_ms\": $duration,\n"
    json+="      \"percentage\": $percentage\n"
    json+="    }"
  done < "${_PROFILE_DIR}/_order"

  json+="\n  ]\n"
  json+="}\n"

  if [[ -n "$output_file" ]]; then
    echo -e "$json" > "$output_file"
    echo "Profile report saved to: $output_file" >&2
  else
    echo -e "$json"
  fi
}

# Save profile data for comparison
profile_save() {
  [[ "${_PROFILE_ENABLED}" != "1" ]] && return 0

  local profile_name="${1:-$(date '+%Y%m%d_%H%M%S')}"
  local profile_dir="${HOME}/.cache/jsh/profile"
  local profile_file="${profile_dir}/${profile_name}.json"

  mkdir -p "$profile_dir"

  # Save as JSON
  JSH_PROFILE_OUTPUT="$profile_file" JSH_PROFILE_FORMAT="json" profile_report > /dev/null

  echo "Profile saved: $profile_file" >&2
}

# Compare two profiles
profile_compare() {
  local profile1="$1"
  local profile2="$2"

  if [[ ! -f "$profile1" ]] || [[ ! -f "$profile2" ]]; then
    echo "Error: Profile files not found" >&2
    return 1
  fi

  echo "=== Profile Comparison ===" >&2
  echo "Profile 1: $(basename "$profile1")" >&2
  echo "Profile 2: $(basename "$profile2")" >&2
  echo >&2

  # This is a placeholder for comparison logic
  # Would require jq or python to parse JSON and compare
  echo "Comparison feature requires jq - coming soon" >&2
}

# Convenience function to profile a command
profile_command() {
  [[ "${_PROFILE_ENABLED}" != "1" ]] && {
    "$@"
    return $?
  }

  local section_name="$1"
  shift

  profile_start "$section_name" "$section_name"
  "$@"
  local exit_code=$?
  profile_end "$section_name"

  return $exit_code
}

# Export functions for use in shell configs
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Being sourced
  export -f profile_init profile_start profile_end profile_report 2> /dev/null || true
  export -f profile_save profile_compare profile_command 2> /dev/null || true
fi
