#!/usr/bin/env bash
set -euo pipefail
# curl-able bootstrap for a fresh machine of any class.
# This is role-inference sugar over the CI-verified install command (README +
# tasks/ci/test.sh): it picks the role from the OS, then runs the exact same
# chezmoi init --apply one-liner with DOTFILES_ROLE exported so the config
# template (§5) never prompts.
#
#   curl -fsSL https://raw.githubusercontent.com/tsyirvo/dotfiles/master/install.sh | sh
#   DOTFILES_ROLE=devbox curl -fsSL ... | sh        # force a role explicitly
#
repo=tsyirvo
role="${DOTFILES_ROLE:-}"
if [ -z "$role" ]; then
  case "$(uname -s)" in
    Darwin)
      role=macbook
      ;;
    Linux)
      if grep -qi '^ID=arch' /etc/os-release 2>/dev/null; then
        role=omarchy
      else
        role=devbox
      fi
      ;;
    *)
      role=devbox
      ;;
  esac
fi
export DOTFILES_ROLE="$role"
echo "bootstrap: role=$role"
exec sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply "$repo"
