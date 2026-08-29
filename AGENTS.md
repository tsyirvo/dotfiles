# AGENTS.md — repo conventions for AI agents

This repository is edited by AI agents (pi, claude) as much as by hand. These rules are
mandatory; skip nothing before changing files here.

## The model

- `.chezmoiroot` points at `home/` — **`home/` is the source of truth**. Edits there have
  **no effect on `$HOME` until `chezmoi apply`**. Always run `chezmoi apply <target>` after
  editing a source file; never `--apply`/`apply --all` a live machine unless that's the intent.
- Prefixes encode behavior: `dot_` → hidden file, `private_` → 0600, `executable_` → +x,
  `.tmpl` suffix → rendered template (Go templates with chezmoi data).

## Boundaries

- `tasks/` is repo-internal and never deployed. Scripts in `home/.chezmoiscripts/` must be
  bash, `set -euo pipefail`, explicit `PATH` (they run with a non-login shell), and
  shellcheck-clean (`mise run check:shellcheck`).
- **Never `chezmoi add`** anything from the ignored classes (see `home/.chezmoiignore`):
  auth DBs, caches, logs, lock files, state dirs, app-update artifacts — and anything secret.
- **Secrets are out-of-band**: SSH keys, `.npmrc` and other
  credentials are never committed. Only hosts/identity-shaped config goes in the repo.
- `~/.pi` is out of scope — it lives in its own git repository.

## Changing routing / packages

- Before touching routing (`home/.chezmoiignore`) or the packages taxonomy
  (`home/.chezmoidata/packages.yaml` + `home/dot_config/mise/config.toml`), run
  `chezmoi diff` first and reason about the change out loud.
- Any routing change must update the README machine-classes table **in the same commit**.

## Hygiene

- Rendered-template whitespace is tricky: after editing a `.tmpl`, verify with
  `chezmoi execute-template` / `chezmoi cat <target>` and diff against the intended output.
- Don't duplicate inventories: package/file lists live in one place (README points at them).
- Update `AGENTS.md` itself in the same commit as any convention change.

## Reference

`PRD-chezmoi-migration.md` is the design document for the stow→chezmoi migration: decisions
(log D1–D17), routing, package taxonomy, runbook phases, and testing/CI. When in doubt, read it.
