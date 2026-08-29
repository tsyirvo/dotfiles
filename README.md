# tsyirvo/dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io). One repository, three machine classes.

## Machine classes

| Class           | OS                                 | role      | Packages from                                                 |
| --------------- | ---------------------------------- | --------- | ------------------------------------------------------------- |
| MacBook Pro     | macOS (Apple Silicon)              | `macbook` | Homebrew (+ casks, + Mac App Store, + Nerd Fonts)             |
| Omarchy desktop | Arch Linux + Hyprland              | `omarchy` | pacman + Omarchy's built-in package manager; shared Nerd Font |
| Dev box         | Debian/Ubuntu, headless (VM / VPS) | `devbox`  | apt + mise for modern CLIs; shared Nerd Font                  |

Routing per class (which config is installed where) lives in `home/.chezmoiignore` — **keep this
table in sync with it** (same commit).

## Install on a new machine

OS packages come from `home/.chezmoidata/packages.yaml`; runtimes + global npm tools from
`home/dot_config/mise/config.toml`. A fresh machine gets both automatically:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tsyirvo
```

The role (macbook / omarchy / devbox) is inferred from the OS; force it with
`DOTFILES_ROLE=…` (or `--promptString role=…`) when the OS guess isn't right — CI does this.
During an interactive install, chezmoi asks once for Git's `user.name` and `user.email` and stores
those values only in the machine-local chezmoi config. For scripted installs, provide
`DOTFILES_GIT_NAME` and `DOTFILES_GIT_EMAIL`; when either value is absent, no `[user]` section is
written to `.gitconfig`. On an existing machine, run `chezmoi init` interactively once after pulling
this change, then run `chezmoi apply`.

The bootstrap then runs automatically, in order:

1. **Package manager** — Homebrew on macOS, pacman/Omarchy PM on Arch, apt on Debian.
2. **Packages** — `brew bundle` / pacman / apt per the class + **all runtimes and global npm
   tools** via `mise install`.
3. **Shell** — fish becomes your login shell (added to `/etc/shells`, `chsh`).
4. **Pre-commit hook** — gitleaks guards the repo against secret leaks.

Last, the **secrets step** (2 minutes, once per machine): SSH keys are
deliberately **not** in this repo — copy them from your Mac / 1Password per
`tasks/secrets/README.md`, then `chezmoi apply` if needed.

## Managing your config

`home/` is the source of truth; `chezmoi apply` writes real files to `$HOME`.
Source-name prefixes encode behavior: `dot_` → hidden file · `private_` → 0600 ·
`executable_` → +x · `.tmpl` suffix → template rendered per machine.

| Task                                   | Command                                           |
| -------------------------------------- | ------------------------------------------------- |
| Edit a managed file, apply immediately | `chezmoi edit --apply ~/.config/fish/config.fish` |
| You edited the live file directly      | `chezmoi re-add ~/.config/zed/settings.json`      |
| What would change                      | `chezmoi diff` · `chezmoi status` (short)         |
| Apply everything                       | `chezmoi apply -v`                                |
| Pull the repo + apply updates          | `chezmoi update`                                  |
| Adopt a new tool's config              | `chezmoi add -R ~/.config/<tool>`                 |
| What's managed / not                   | `chezmoi managed` · `chezmoi unmanaged ~/.config` |
| Health check                           | `chezmoi doctor`                                  |

Also: `chezmoi cd` → shell inside `home/`; `chezmoi data` → every template variable.

### Adopting a new tool (checklist)

1. `chezmoi add -R ~/.config/<tool>` (is it a secret? then **don't add it** — see Secrets).
2. Add its package to `home/.chezmoidata/packages.yaml`, or its runtime/global to
   `mise/config.toml`.
3. Machine-specific? Add routing in `home/.chezmoiignore`.
4. `chezmoi apply`, then commit (`git add home && git commit`).

## Packages

Two manifests, no overlap. The full taxonomy (what goes where, how to remove) is the header
comment of `home/.chezmoidata/packages.yaml`.

| What                                                           | Where                              | Installed by                                                    |
| -------------------------------------------------------------- | ---------------------------------- | --------------------------------------------------------------- |
| OS packages (brew / pacman / apt / casks / mas)                | `home/.chezmoidata/packages.yaml`  | `10-install-packages` + `12-tailscale` scripts (auto, on apply) |
| Runtimes + global npm tools (`node`, `python`, `bun`, `npm:…`) | `home/dot_config/mise/config.toml` | `mise install` (auto, on apply)                                 |
| tmux plugins (8 via tpm; tpm itself an external)               | tmux.conf `@plugin` lines          | `20-install-tmux-plugins` script (auto, on apply)               |

- **Add:** one commented line in the right manifest → `chezmoi apply` installs it.
- **Remove:** delete the line → `chezmoi apply`, then uninstall from the OS
  (`brew uninstall <x>` / `sudo pacman -R <x>` / `sudo apt remove <x>`).

### Node / global npm rules

- Every global is a `npm:<pkg>` entry in `mise/config.toml` — **never** `npm i -g`.
- One pinned Node per machine; switching Node moves globals → run `mise install` (or
  `mise run fix-globals`) to restore everything.

## Shortcuts (`mise run …`)

`apply` · `diff` · `update` · `check` (unmanaged scan) · `check:shellcheck` · `check:gitleaks` ·
`fix-globals` (`mise install`) · `macos` (defaults, manual re-run) · `test` (docker e2e) ·
`update:pinact` (re-pin CI actions)

## Secrets

Out-of-band by design: SSH keys, and any future tokens are copied per machine
and **never committed**. See `tasks/secrets/README.md`. gitleaks enforces this on every commit
and in CI.

## Keeping this README honest

- No package lists here — they live in `packages.yaml` / `mise/config.toml`.
- No file inventories here — `chezmoi managed` is the truth.
- The install command above is exactly what CI runs (`tasks/ci/test.sh`); if it stops working,
  CI fails before a user does.
- Change routing? Update the machine-classes table in the same commit.
