# Secrets — out-of-band bootstrap choreography

Secrets are **never** in this repo. On a fresh machine, run the
install first; then do this **2-minute manual step** so ssh/etc. actually work:

| Item                                 | Copy to                                          | Source                           |
| ------------------------------------ | ------------------------------------------------ | -------------------------------- |
| SSH keys (private + `.pub`)          | `~/.ssh/` (`id_ed25519`, `gitlab`, `hetzner`, …) | Mac (`scp -r`, USB) or 1Password |
| future tokens (`.npmrc`, cloud CLIs) | wherever the tool expects                        | 1Password                        |

Then re-run `chezmoi apply` so any config that references them settles.

## Optional helper

If you mount your keys in a directory (USB stick, `scp`'d folder), this copies them with
sane permissions:

```bash
SECRETS_DIR=/path/to/keys ./tasks/secrets/bootstrap-ssh.sh
```

It installs only the files it finds (`id_ed25519`/`gitlab`/`hetzner` + `.pub`, 0600/0644).
Does nothing destructive; keys are only copied, never committed.

## Guards

- `gitleaks protect --staged` runs on every commit (pre-commit hook installed by
  `90-gitleaks` chezmoi script) and `gitleaks git` runs in CI.
- `.gitignore` carries `*.key`, `*key.txt`, `*.pem`, `ngrok.yml`, `.npmrc` as a last line
  of defense — gitleaks is the real guard.
