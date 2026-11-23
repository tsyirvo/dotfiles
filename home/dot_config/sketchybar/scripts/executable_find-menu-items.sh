#!/usr/bin/env bash
# Lists every menu bar item SketchyBar can mirror, and previews each one in the
# bar next to its number so you can tell which app is which.
#
# On macOS 26+ third-party items are all reported as "Control Center,Item-0(N)";
# N is the item's position counted from the right edge of the native menu bar.
# Copy the exact string into settings.lua -> menu_extras[].alias.
#
# Usage: scripts/find-menu-items.sh [seconds-to-preview]   (default 20)
# Needs: jq, Screen Recording permission for SketchyBar.
set -euo pipefail

SB="${SKETCHYBAR_BIN:-sketchybar}"
PREVIEW_SECONDS="${1:-20}"

if ! command -v jq >/dev/null 2>&1; then
  echo "find-menu-items: jq is required (brew install jq)" >&2
  exit 1
fi

raw="$("$SB" --query default_menu_items 2>&1 || true)"
if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$raw"; then
  echo "find-menu-items: SketchyBar did not return a list:" >&2
  echo "$raw" >&2
  echo "Grant Screen Recording to SketchyBar (System Settings > Privacy & Security)," >&2
  echo "then restart it: brew services restart sketchybar" >&2
  exit 1
fi

count=0
entries=()
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  count=$((count + 1))
  entries+=("$entry")
  printf '%3d  %s\n' "$count" "$entry"
done < <(jq -r '.[]' <<<"$raw")

if [ "$count" -eq 0 ]; then
  echo "find-menu-items: no menu bar items found" >&2
  exit 1
fi

cleanup() {
  "$SB" --remove '/probe\.n\..*/' >/dev/null 2>&1 || true
  for entry in "${entries[@]}"; do
    "$SB" --remove "$entry" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

args=()
i=0
for entry in "${entries[@]}"; do
  i=$((i + 1))
  args+=(--add item "probe.n.$i" left
         --set "probe.n.$i" icon.drawing=off label="$i" label.color=0xfff38ba8 label.padding_left=8
         --add alias "$entry" left
         --set "$entry" alias.update_freq=1)
done
"$SB" "${args[@]}"

echo
echo "Previewing for ${PREVIEW_SECONDS}s on the left of the bar (red number = line above)."
echo "Tip: drag the apps you mirror next to Control Center (Cmd-drag) BEFORE"
echo "running this, so new apps launching later don't shift their numbers."
sleep "$PREVIEW_SECONDS"
