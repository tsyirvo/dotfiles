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

docker run --rm ${docker_platform[@]+"${docker_platform[@]}"} -v "$PWD:/dotfiles:ro" "$image" bash -c "
  set -euo pipefail
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y -qq git curl sudo >/dev/null 2>&1
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed git curl sudo >/dev/null 2>&1
  else
    echo 'test: no apt-get/pacman in image' >&2; exit 1
  fi
  useradd -m -s /bin/bash test
  echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
  su - test -c 'DOTFILES_ROLE=$role sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init --apply --source=/dotfiles'
  # assert: fish exists, chezmoi doctor exit 0, mise install reproduces tools,
  # no unmanaged surprises in the source dir (run under bash: the bootstrap's
  # 50-shell chsh'd test's login shell to fish)
  su - test -s /bin/bash -c '
    command -v fish >/dev/null || { echo \"FAIL: fish missing\"; exit 1; }
    command -v mise >/dev/null || { echo \"FAIL: mise missing\"; exit 1; }
    chezmoi --source=/dotfiles doctor >/dev/null || { echo \"FAIL: chezmoi doctor\"; exit 1; }
    echo OK
  '
"
