#!/usr/bin/env bash
set -euo pipefail
# Shellcheck harness: renders every .chezmoiscripts/*.tmpl for all machine
# classes, verifies Darwin-only Brewfile/MAS routing, and shellchecks the static
# scripts under tasks/. Requires: chezmoi + shellcheck (mise.toml provides both
# — run `mise install` first, CI does this).
cd "$(dirname "$0")/../.."
repo_root="$PWD"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
for role in macbook omarchy devbox; do
  case "$role" in
    macbook)
      os_id="darwin"
      is_darwin=true is_linux=false is_macbook=true is_omarchy=false is_devbox=false is_headless=false personal=true
      ;;
    omarchy)
      os_id="linux-arch"
      is_darwin=false is_linux=true is_macbook=false is_omarchy=true is_devbox=false is_headless=false personal=true
      ;;
    devbox)
      os_id="linux-debian"
      is_darwin=false is_linux=true is_macbook=false is_omarchy=false is_devbox=true is_headless=true personal=false
      ;;
  esac
  cat > "$tmp/$role.toml" <<EOF
[data]
role = "$role"
osID = "$os_id"
isDarwin = $is_darwin
isLinux = $is_linux
isMacbook = $is_macbook
isOmarchy = $is_omarchy
isDevbox = $is_devbox
isHeadless = $is_headless
personal = $personal
EOF
  mkdir -p "$tmp/$role"
  for t in home/.chezmoiscripts/*.tmpl; do
    # shellcheck disable=SC2094 # Input is under home/; output is under a unique temp directory.
    chezmoi --config "$tmp/$role.toml" --source "$repo_root" execute-template < "$t" \
      > "$tmp/$role/$(basename "$t" .tmpl)" \
      || { echo "render failed: $t ($role)"; fail=1; }
  done
  for f in "$tmp/$role"/*.sh; do
    shellcheck "$f" || fail=1
  done

  chezmoi --config "$tmp/$role.toml" --source "$repo_root" execute-template < home/dot_Brewfile.tmpl > "$tmp/$role/Brewfile" \
    || { echo "render failed: home/dot_Brewfile.tmpl ($role)"; fail=1; }
  chezmoi --config "$tmp/$role.toml" --source "$repo_root" execute-template < home/.chezmoiignore > "$tmp/$role/chezmoiignore" \
    || { echo "render failed: home/.chezmoiignore ($role)"; fail=1; }

  if [ "$role" = macbook ]; then
    grep -q '^mas ' "$tmp/$role/Brewfile" || { echo "missing MAS apps for macbook"; fail=1; }
    grep -q '^cask "font-jetbrains-mono-nerd-font"' "$tmp/$role/Brewfile" || { echo "missing Nerd Font cask for macbook"; fail=1; }
    if grep -qxF '.Brewfile' "$tmp/$role/chezmoiignore"; then
      echo "Brewfile incorrectly ignored for macbook"
      fail=1
    fi
  else
    if grep -q '^mas ' "$tmp/$role/Brewfile"; then
      echo "MAS apps incorrectly rendered for $role"
      fail=1
    fi
    grep -qxF '.Brewfile' "$tmp/$role/chezmoiignore" || { echo "Brewfile not ignored for $role"; fail=1; }
    grep -q 'JetBrainsMono.zip' "$tmp/$role/run_onchange_before_15-install-nerd-font.sh" || { echo "missing Nerd Font installer for $role"; fail=1; }
  fi
done

# static scripts (unrendered)
while IFS= read -r f; do
  shellcheck "$f" || fail=1
done < <(find tasks -name '*.sh' -type f | sort)

[ "$fail" -eq 0 ] && echo "shellcheck-rendered: OK"
exit $fail
