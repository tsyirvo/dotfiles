#!/usr/bin/env bash
set -euo pipefail
# usage: ./tasks/ci/test.sh [role] [image]
# Full e2e: boots a container, installs from this checkout via the README install
# command, with the role forced (no prompts). Assert a few postconditions.
role=${1:-devbox}
image=${2:-debian:bookworm}
# some images are amd64-only (archlinux) — pass DOCKER_PLATFORM=linux/amd64 from
# an arm64 Mac so CI and local runs cover the same jobs
docker_platform=()
if [ -n "${DOCKER_PLATFORM:-}" ]; then
  docker_platform=(--platform "$DOCKER_PLATFORM")
fi

# The container script is a quoted heredoc — no escaping soup, and shellcheck
# parses it verbatim. ROLE is passed via -e (heredoc content is not
# interpolated by this script).
docker run --rm -i ${docker_platform[@]+"${docker_platform[@]}"} \
  -e ROLE="$role" \
  -v "$PWD:/dotfiles:ro" \
  "$image" bash <<'EOF'
set -euo pipefail
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq git curl sudo >/dev/null 2>&1
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed git curl sudo >/dev/null 2>&1
else
  echo 'test: no apt-get/pacman in image' >&2
  exit 1
fi
useradd -m -s /bin/bash test
echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
# runner-checkout is owned by a different uid inside the container → git's
# dubious-ownership guard fires on any git op in /dotfiles. chezmoi doctor
# runs git without the user's global config, so set it system-wide too.
su - test -s /bin/bash -c 'git config --global --add safe.directory /dotfiles'
git config --system --add safe.directory /dotfiles
su - test -c "DOTFILES_ROLE=$ROLE sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init --apply --source=/dotfiles"
# assert: fish exists, chezmoi doctor exit 0, mise install reproduces tools
# (run under bash: the bootstrap's 50-shell chsh'd test's login shell to fish;
# explicit PATH because /etc/skel's ~/.local/bin addition varies by distro)
su - test -s /bin/bash -c '
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
  command -v fish >/dev/null || { echo "FAIL: fish missing"; exit 1; }
  command -v mise >/dev/null || { echo "FAIL: mise missing"; exit 1; }
  chezmoi --source=/dotfiles doctor >/dev/null || { echo "FAIL: chezmoi doctor"; exit 1; }
  echo OK
'
EOF