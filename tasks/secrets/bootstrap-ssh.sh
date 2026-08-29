#!/usr/bin/env bash
set -euo pipefail
# Optional helper: copy SSH keys from a mounted secrets dir into ~/.ssh.
# Keys are only copied, never committed. See tasks/secrets/README.md.
#   SECRETS_DIR=/path/to/keys ./tasks/secrets/bootstrap-ssh.sh
: "${SECRETS_DIR:?set SECRETS_DIR to the dir holding the key files}"
mkdir -p "$HOME/.ssh"
copied=0
missing=0
for f in id_ed25519 id_ed25519.pub gitlab gitlab.pub hetzner hetzner.pub; do
  if [ -f "$SECRETS_DIR/$f" ]; then
    case "$f" in
      *.pub) mode=644 ;;
      *)     mode=600 ;;
    esac
    install -m "$mode" "$SECRETS_DIR/$f" "$HOME/.ssh/$f"
    copied=$((copied + 1))
  else
    missing=$((missing + 1))
  fi
done
if [ "$copied" -eq 0 ]; then
  echo "bootstrap-ssh: nothing copied — nothing in SECRETS_DIR matched" >&2
  exit 1
fi
echo "bootstrap-ssh: copied $copied key file(s) into ~/.ssh ($missing not found in SECRETS_DIR)"
