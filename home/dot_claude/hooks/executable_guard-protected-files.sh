#!/usr/bin/env bash
#
# PreToolUse hook: guards sensitive files from being read or modified.
#   - Secrets (.env*): blocked from Read, Edit, and Write
#   - Lock files: blocked from Edit and Write only
#
# Receives JSON on stdin with tool_name and tool_input.file_path
# Exit 0 = allow, Exit 2 = block (stderr sent to Claude as feedback)
#

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Extract the tool name and file path
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# If no file path found, allow the action
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Normalize to just the basename for matching
BASENAME=$(basename "$FILE_PATH")

# Allow .example files — these are safe templates without real secrets
if [[ "$BASENAME" =~ \.example$ ]]; then
  exit 0
fi

# ─── Protected patterns ───────────────────────────────
# Secrets: blocked from ALL access (read + write)
SECRET_PATTERNS=(
  '\.env$'
  '\.env\.'
  '\.dev.vars$'
  '\.dev.vars\.'
)

# Lock files: blocked from WRITE only (read is allowed)
WRITE_ONLY_PATTERNS=(
  'package-lock\.json$'
  'pnpm-lock\.yaml$'
  'yarn\.lock$'
)
# ──────────────────────────────────────────────────────

# Determine the human-readable action from the tool name
case "$TOOL_NAME" in
  Read)  ACTION="reading" ;;
  Edit)  ACTION="editing" ;;
  Write) ACTION="writing" ;;
  *)     ACTION="accessing" ;;
esac

# Check secrets — blocked from all access
for PATTERN in "${SECRET_PATTERNS[@]}"; do
  if echo "$BASENAME" | grep -qE "$PATTERN"; then
    bash "$HOME/.claude/hooks/notify.sh" "Claude Code Guard" "Blocked $ACTION: $BASENAME" 2>/dev/null || true
    echo "BLOCKED: $ACTION '$BASENAME' is not allowed. This file contains secrets and must not be sent to third-party services." >&2
    exit 2
  fi
done

# Check lock files — blocked from writes only
if [[ "$TOOL_NAME" != "Read" ]]; then
  for PATTERN in "${WRITE_ONLY_PATTERNS[@]}"; do
    if echo "$BASENAME" | grep -qE "$PATTERN"; then
      bash "$HOME/.claude/hooks/notify.sh" "Claude Code Guard" "Blocked $ACTION: $BASENAME" 2>/dev/null || true
      echo "BLOCKED: $ACTION '$BASENAME' is not allowed. Lock files must not be modified directly." >&2
      exit 2
    fi
  done
fi

# File is not protected — allow the action
exit 0
