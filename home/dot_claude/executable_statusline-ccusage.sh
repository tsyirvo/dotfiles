#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
GRAY='\033[0;90m'
LIGHT_GRAY='\033[0;37m'
RESET='\033[0m'

# Read JSON input from stdin
input=$(cat)

# Extract current session ID and model info from Claude Code input
session_id=$(echo "$input" | jq -r '.session_id // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Extract context window token counts from Claude Code input
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
context_used_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0) +
  (.context_window.current_usage.cache_read_input_tokens // 0)
')

# Get current git branch with error handling
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    if [ -z "$branch" ]; then
        branch="detached"
    fi

    # Check for pending changes (staged or unstaged)
    if ! git diff-index --quiet HEAD -- 2>/dev/null || ! git diff-index --quiet --cached HEAD -- 2>/dev/null; then
        # Get line changes for unstaged and staged changes
        unstaged_stats=$(git diff --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {print added+0, deleted+0}')
        staged_stats=$(git diff --cached --numstat 2>/dev/null | awk '{added+=$1; deleted+=$2} END {print added+0, deleted+0}')

        # Parse the stats
        unstaged_added=$(echo $unstaged_stats | cut -d' ' -f1)
        unstaged_deleted=$(echo $unstaged_stats | cut -d' ' -f2)
        staged_added=$(echo $staged_stats | cut -d' ' -f1)
        staged_deleted=$(echo $staged_stats | cut -d' ' -f2)

        # Total changes
        total_added=$((unstaged_added + staged_added))
        total_deleted=$((unstaged_deleted + staged_deleted))

        # Build the branch display with changes (with colors)
        changes=""
        if [ $total_added -gt 0 ]; then
            changes="${GREEN}+$total_added${RESET}"
        fi
        if [ $total_deleted -gt 0 ]; then
            if [ -n "$changes" ]; then
                changes="$changes ${RED}-$total_deleted${RESET}"
            else
                changes="${RED}-$total_deleted${RESET}"
            fi
        fi

        if [ -n "$changes" ]; then
            branch="$branch${PURPLE}*${RESET} ($changes)"
        else
            branch="$branch${PURPLE}*${RESET}"
        fi
    fi
else
    branch="no-git"
fi

# Get basename of current directory
dir_name=$(basename "$current_dir")

# Get today's date in YYYYMMDD format
today=$(date +%Y%m%d)

# Function to format numbers
format_cost() {
    printf "%.2f" "$1"
}

format_time() {
    local minutes=$1
    local hours=$((minutes / 60))
    local mins=$((minutes % 60))
    if [ "$hours" -gt 0 ]; then
        printf "%dh %dm" "$hours" "$mins"
    else
        printf "%dm" "$mins"
    fi
}

format_tokens() {
    local tokens=$1
    if [ "$tokens" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fM\", $tokens/1000000}"
    elif [ "$tokens" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fK\", $tokens/1000}"
    else
        printf "%d" "$tokens"
    fi
}

format_context_info() {
    local used_tokens=$1
    local total_tokens=$2
    local pct=0
    if [ "$total_tokens" -gt 0 ]; then
        pct=$(awk "BEGIN {printf \"%.0f\", $used_tokens * 100 / $total_tokens}")
    fi
    local used_fmt
    local total_fmt
    used_fmt=$(format_tokens "$used_tokens")
    total_fmt=$(format_tokens "$total_tokens")
    if [ "$pct" -lt 50 ]; then
        printf "${GREEN}${used_fmt}/${total_fmt} (${pct}%%)${RESET}"
    elif [ "$pct" -lt 80 ]; then
        printf "${YELLOW}${used_fmt}/${total_fmt} (${pct}%%)${RESET}"
    else
        printf "${RED}${used_fmt}/${total_fmt} (${pct}%%)${RESET}"
    fi
}

# Initialize variables with defaults
session_cost="0.00"
daily_cost="0.00"
block_cost="0.00"
remaining_time="N/A"

# Get current session data by finding the session JSONL file
if command -v ccusage >/dev/null 2>&1 && [ -n "$session_id" ] && [ "$session_id" != "empty" ]; then
    # Look for the session JSONL file in Claude project directories
    session_jsonl_file=""

    # Check common Claude paths
    claude_paths=(
        "$HOME/.config/claude"
        "$HOME/.claude"
    )

    for claude_path in "${claude_paths[@]}"; do
        if [ -d "$claude_path/projects" ]; then
            # Use find to search for the session file
            session_jsonl_file=$(find "$claude_path/projects" -name "${session_id}.jsonl" -type f 2>/dev/null | head -1)
            if [ -n "$session_jsonl_file" ]; then
                break
            fi
        fi
    done

    # Parse the session file if found - get session cost from ccusage
    if [ -n "$session_jsonl_file" ] && [ -f "$session_jsonl_file" ]; then
        # Use ccusage statusline to get the accurate cost for this session
        ccusage_statusline=$(echo "$input" | ccusage statusline 2>/dev/null)
        current_session_cost=$(echo "$ccusage_statusline" | sed -n 's/.*💰 \([^[:space:]]*\) session.*/\1/p')

        if [ -n "$current_session_cost" ] && [ "$current_session_cost" != "N/A" ]; then
            session_cost=$(echo "$current_session_cost" | sed 's/\$//g')
        fi
    fi
fi

if command -v ccusage >/dev/null 2>&1; then
    # Get daily data
    daily_data=$(ccusage daily --json --since "$today" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$daily_data" ]; then
        daily_cost=$(echo "$daily_data" | jq -r '.totals.totalCost // 0')
    fi

    # Get active block data
    block_data=$(ccusage blocks --active --json 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$block_data" ]; then
        active_block=$(echo "$block_data" | jq -r '.blocks[] | select(.isActive == true) // empty')
        if [ -n "$active_block" ] && [ "$active_block" != "null" ]; then
            block_cost=$(echo "$active_block" | jq -r '.costUSD // 0')
            remaining_minutes=$(echo "$active_block" | jq -r '.projection.remainingMinutes // 0')
            if [ "$remaining_minutes" != "0" ] && [ "$remaining_minutes" != "null" ]; then
                remaining_time=$(format_time "$remaining_minutes")
            fi
        fi
    fi
fi

# Format the output
formatted_session_cost=$(format_cost "$session_cost")
formatted_daily_cost=$(format_cost "$daily_cost")
formatted_block_cost=$(format_cost "$block_cost")
formatted_context_info=$(format_context_info "$context_used_tokens" "$context_window_size")

# Build the status line with colors (light gray as default)
status_line="${LIGHT_GRAY}🌿 $branch ${GRAY}|${LIGHT_GRAY} 📁 $dir_name ${GRAY}|${LIGHT_GRAY} 🤖 $model_name ${GRAY}|${LIGHT_GRAY} 🧠 ${formatted_context_info}${RESET}\n💰 \$$formatted_session_cost ${GRAY}/${LIGHT_GRAY} 📅 \$$formatted_daily_cost ${GRAY}/${LIGHT_GRAY} 🧊 \$$formatted_block_cost"


if [ "$remaining_time" != "N/A" ]; then
    status_line="$status_line ($remaining_time left)"
fi

status_line="$status_line"

printf "%b\n" "$status_line"
