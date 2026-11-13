#!/usr/bin/env bash
# Claude Code status line
#   branch · model · effort · context used · prompt-cache countdown
# Example: ⎇ feat/login │ Opus 5.5 │ ◆ high │ ctx 142k/1.0M 14% │ cache ≤15m
# Requires: jq, Claude Code v2.1.251+ (for the prompt_cache object)

input=$(cat)

# One jq call, tab-separated. Every field gets a "-" placeholder because
# bash `read` collapses consecutive tabs and would shift empty fields.
IFS=$'\t' read -r MODEL EFFORT THINKING USED SIZE PCT HAS_CACHE WARM EXPIRES RECACHE DIR < <(
  jq -r '[
    (.model.display_name // "?"),
    (.effort.level // "-"),
    (.thinking.enabled | if . == null then "-" else tostring end),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 0),
    ((.context_window.used_percentage // 0) | floor),
    (if .prompt_cache then "yes" else "no" end),
    (.prompt_cache.warm | if . == null then "-" else tostring end),
    (.prompt_cache.expires_at // "-"),
    (.prompt_cache.recache_tokens_if_cold // "-"),
    (.workspace.current_dir // .cwd // "-")
  ] | map(tostring) | @tsv' <<<"$input"
)

# ── colors ───────────────────────────────────────────────────────────
R=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RED=$'\033[31m'
GRN=$'\033[32m'
YEL=$'\033[33m'
BLU=$'\033[34m'
MAG=$'\033[35m'
CYN=$'\033[36m'
SEP="${DIM} │ ${R}"

# 142000 -> 142k, 1000000 -> 1.0M
human() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%dk", n/1000;
    else printf "%d", n }'
}

# ── git branch ───────────────────────────────────────────────────────
# --no-optional-locks keeps git from taking index.lock while Claude works
BRANCH=""
if [ "$DIR" != "-" ] && git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git --no-optional-locks -C "$DIR" branch --show-current 2>/dev/null)
  # Detached HEAD (rebase, checkout of a tag/sha): show the short sha
  [ -z "$BRANCH" ] && BRANCH="@$(git --no-optional-locks -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
fi

# ── model ────────────────────────────────────────────────────────────
OUT="${BOLD}${CYN}${MODEL}${R}"
[ -n "$BRANCH" ] && OUT="${GRN}⎇ ${BRANCH}${R}${SEP}${OUT}"

# ── effort / thinking ────────────────────────────────────────────────
if [ "$EFFORT" != "-" ]; then
  case "$EFFORT" in
  low) EC=$DIM ;;
  medium) EC=$BLU ;;
  high) EC=$MAG ;;
  xhigh | max) EC=$RED ;;
  *) EC=$R ;;
  esac
  EFF="${EC}◆ ${EFFORT}${R}"
  [ "$THINKING" = "false" ] && EFF="${EFF} ${DIM}(no think)${R}"
else
  # Model without effort support: fall back to the thinking toggle
  case "$THINKING" in
  true) EFF="${MAG}thinking on${R}" ;;
  false) EFF="${DIM}thinking off${R}" ;;
  *) EFF="${DIM}effort –${R}" ;;
  esac
fi
OUT="${OUT}${SEP}${EFF}"

# ── context ──────────────────────────────────────────────────────────
if [ "$PCT" -ge 80 ]; then
  CC=$RED
elif [ "$PCT" -ge 50 ]; then
  CC=$YEL
else CC=$GRN; fi
if [ "$SIZE" -gt 0 ]; then
  CTX="ctx ${CC}$(human "$USED")${R}${DIM}/$(human "$SIZE")${R} ${CC}${PCT}%${R}"
else
  CTX="ctx ${DIM}–${R}"
fi
OUT="${OUT}${SEP}${CTX}"

# ── prompt cache countdown ───────────────────────────────────────────
if [ "$HAS_CACHE" = "no" ]; then
  CACHE="${DIM}cache –${R}" # before the first response
elif [ "$WARM" = "true" ] && [ "$EXPIRES" != "-" ]; then
  NOW=$(date +%s)
  LEFT=$((EXPIRES - NOW))
  if [ "$LEFT" -le 0 ]; then
    CACHE="${RED}cache cold${R}"
  else
    # Rounded up so the label never promises more time than is left:
    # > 20m → ✓, 10–20m → 5-minute steps (≤20m, ≤15m), ≤ 10m → every minute
    MIN=$(((LEFT + 59) / 60))
    if [ "$MIN" -gt 20 ]; then
      CACHE="cache ${GRN}✓${R}"
    elif [ "$MIN" -gt 10 ]; then
      CACHE="cache ${YEL}≤$(((MIN + 4) / 5 * 5))m${R}"
    else
      CACHE="cache ${RED}${MIN}m${R}"
    fi
  fi
else
  # Cold: show what the next turn will have to re-cache
  if [ "$RECACHE" != "-" ]; then
    CACHE="${RED}cache cold${R} ${DIM}(re-cache $(human "$RECACHE"))${R}"
  else
    CACHE="${RED}cache cold${R}"
  fi
fi
OUT="${OUT}${SEP}${CACHE}"

printf '%s\n' "$OUT"
