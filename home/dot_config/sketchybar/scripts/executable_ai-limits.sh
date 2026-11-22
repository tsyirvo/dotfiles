#!/usr/bin/env bash
# Prints the 5-hour session usage (percent used) of Claude and Codex as JSON:
#   {"claude": 2, "codex": 0}   (null when a login is missing or expired)
# Reads the logins of Claude Code (keychain) and Codex (~/.codex/auth.json).
# Tokens go to curl on stdin, so they never show in the process list or the output.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

claude_used() {
  local cred token
  cred="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)" || return 0
  token="$(jq -r '.claudeAiOauth.accessToken // empty' <<<"$cred")"
  [ -n "$token" ] || return 0
  printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\n' "$token" |
    curl -sf --max-time 10 -H @- https://api.anthropic.com/api/oauth/usage |
    jq -r '.five_hour.utilization // empty'
}

codex_used() {
  local auth="$HOME/.codex/auth.json"
  [ -r "$auth" ] || return 0
  jq -r '"Authorization: Bearer \(.tokens.access_token)\nChatGPT-Account-Id: \(.tokens.account_id)"' "$auth" |
    curl -sf --max-time 10 -H @- -H "User-Agent: codex-cli" https://chatgpt.com/backend-api/wham/usage |
    jq -r '.rate_limit.primary_window.used_percent // empty'
}

claude="$(claude_used)"
codex="$(codex_used)"
jq -cn --argjson claude "${claude:-null}" --argjson codex "${codex:-null}" '{claude: $claude, codex: $codex}'
