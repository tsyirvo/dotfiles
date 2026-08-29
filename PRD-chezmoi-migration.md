# PRD — Migrating `tsyirvo/dotfiles` from GNU Stow to chezmoi

**Status:** Draft v2 — incorporates review feedback
**Owner:** tsyirvo
**Date:** 2026-08-27
**Related:** [chezmoi docs](https://www.chezmoi.io), [old repo](https://github.com/tsyirvo/dotfiles)

---

## 1. Executive summary

Replace GNU Stow with [chezmoi](https://www.chezmoi.io) to solve three problems:

1. **Config noise.** Today `~/.config` is a single symlink _into the repo working tree_, so every
   app that writes its config (Raycast, GitHub Copilot, ngrok, fish caches, …) creates untracked
   files inside the repository. `git status` is permanent noise. chezmoi copies files from a source
   directory to `$HOME`, so the repo only ever contains what we explicitly `chezmoi add`.
2. **Multi-machine.** One repo serves three machine classes — MacBook Pro (macOS), Omarchy desktop
   (Arch + Hyprland), and headless Linux dev boxes (unRAID VM, Hetzner VPS; Debian/Ubuntu). Per-host
   differences are handled by Go templates, `.chezmoiignore` routing, and data-driven package lists.
3. **Dependency installation.** OS packages come from a single commented `packages.yaml`; language
   runtimes and global npm tools come from one pinned `mise` manifest; both are installed
   declaratively by chezmoi scripts when their contents change.

**Success criteria**

- `git status` stays clean after normal use; nothing is written into the repo by apps.
- One command (`install.sh`) bootstraps a fresh machine of any class to a working shell + tooling.
- `mise install` alone reproduces every runtime and global npm tool on a fresh machine (§8.5).
- SSH keys and tokens never appear in the repo (gitleaks-guarded).
- macOS defaults are one maintainable file instead of 8 sprawling scripts (§10.4).

---

## 2. Current state (inventory, 2026-08-27)

### 2.1 Architecture today

This is the root cause of the noise problem:

| Path                  | Symlink target                | Notes                                                                           |
| --------------------- | ----------------------------- | ------------------------------------------------------------------------------- |
| `~/.config`           | `dotfiles/.config`            | **The whole directory is one symlink into the repo.**                           |
| `~/bin`               | `dotfiles/bin`                |                                                                                 |
| `~/.gitconfig`        | `dotfiles/.gitconfig`         |                                                                                 |
| `~/.gitignore_global` | `dotfiles/.gitignore_global`  |                                                                                 |
| `~/.claude/*`         | `dotfiles/ai-tools/.claude/*` | Real dir; only 4 files are symlinked in (stow can't fold into an existing dir). |

Stow invocation: default via `.stowrc` (`--target=~/ --no-folding`), packages `.config`, `bin`,
`.gitconfig`, `.gitignore_global`, `ai-tools`.

Because `~/.config` _is_ the repo dir, apps write straight into the working tree. 10 directories in
`~/.config` are not committed (see §2.4).

### 2.2 Tracked inventory (117 files) — what carries over

| Group                  | Files                                                                                                                                                                                                                                                                                                                                            | Verdict                                                                                     |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `fish`                 | `config.fish`, aliases, `conf.d` snippets, `functions/{wc,wcp,wpi}.fish`                                                                                                                                                                                                                                                                     | Consolidate into ordered `conf.d` snippets; replace Fisher/theme state with declarative colors. |
| `zed`                  | `settings.json`, `keymap.json`                                                                                                                                                                                                                                                                                                                   | Keep verbatim; excluded from headless boxes via ignore.                                     |
| `television`           | `config.toml` + **57 cable files** (half the repo)                                                                                                                                                                                                                                                                                               | Keep all — authored channel definitions.                                                    |
| cross-platform CLIs    | `atuin/config.toml` (267 l. mostly comments), `btop/` (+theme), `eza/theme.yml`, `gh/{config,hosts}.yml`, `gh-dash/config.yml`, `git/ignore`, `mise/config.toml`, `sesh/sesh.toml`, `starship.toml`, `tmux/tmux.conf`, `worktrunk/config.toml`, `hunk/config.toml`, `herdr/config.toml`, `ghostty/config`, `bat/themes/Catppuccin Mocha.tmTheme` | Keep verbatim (plain files).                                                                |
| macOS-only             | `aerospace/aerospace.toml`                                                                                                                                                                                                                                                                                                                       | Keep; routed to darwin only.                                                                |
| `ai-tools/.claude`     | **`settings.json`, `statusline-ccusage.sh`, `hooks/notify.sh`, `hooks/guard-protected-files.sh`**                                                                                                                                                                                                                                                | Move to `dot_claude/`; these exact 4 files, nothing else (§7.3).                            |
| `bin`                  | `clean-branches`, `dns-flush`, `e`, `f`, `git-amend`, `myip`                                                                                                                                                                                                                                                                                     | Keep; `clean-branches` is **missing its exec bit** (tracked 0644) — fix with `executable_`. |
| `macos/`               | `setup.sh` + 8 numbered `_0N-*.sh` defaults scripts                                                                                                                                                                                                                                                                                              | **Consolidate** to one `tasks/macos/defaults.sh` (§10.4).                                   |
| `packages/`            | `Brewfile` (~120 lines), `setup.sh`                                                                                                                                                                                                                                                                                                              | Convert to commented `packages.yaml` + rendered `Brewfile.tmpl` + install script.           |
| `scripts/functions.sh` | colored-echo helpers                                                                                                                                                                                                                                                                                                                             | Move to `tasks/lib/functions.sh`.                                                           |
| misc                   | `.gitconfig`, `.gitignore_global`                                                                                                                                                                                                                                                                                                                | `.gitconfig` → template (identity only); `.gitignore_global` verbatim.                      |

### 2.3 Committed junk — must NOT carry over

| File                               | Why it's junk                                           |
| ---------------------------------- | ------------------------------------------------------- |
| `.config/bat/.DS_Store`            | macOS Finder junk committed to git history.             |
| `.config/hunk/state.json`          | App state (`{lastSeenCliVersion: ...}`).                |
| `.config/herdr/release-notes.json` | Release-notes cache fetched at runtime.                 |
| `.config/cmux/settings.json`       | Already deleted locally — tool evidently removed. Drop. |

### 2.4 Untracked noise inside `~/.config` — must NOT be managed

| Dir                                   | Contents                                           | Class                                        |
| ------------------------------------- | -------------------------------------------------- | -------------------------------------------- |
| `github-copilot/`                     | `auth.db` (+ WAL/SHM)                              | auth state — never track                     |
| `manus-computer-operator/`            | `config.json`, `mcp_servers.json`, `epoch`         | state — never track                          |
| `ngrok/`                              | `ngrok.yml` (**authtoken**)                        | **secret — out-of-band, never in repo** (§9) |
| `mole/`                               | 3.4 MB `operations.log`, `mole.log`, `purge_paths` | state/logs — ignore                          |
| `raycast/`                            | `config.json`, `extensions/`, `ai/`                | state — ignore                               |
| `devin/`                              | `config.json` + `.bak`                             | **decided: never track** (review feedback)   |
| `amp/`, `codexbar/`                   | plugin scaffolding                                 | **decided: never track** (review feedback)   |
| `.conductor/`, `.serena/` (repo root) | agent tooling, `serena/project.yml`                | **decided: never track** (review feedback)   |

### 2.5 Machine-specific / secret material that forces templates or routing

- `fish/config.fish`: hardcoded `/opt/homebrew/{bin,sbin,Cellar,Repository}`, `/Users/tsyirvo/Library/pnpm`.
- `.gitconfig`: real name + email committed in the clear (review: keep shared across machines, no
  per-machine signing for now); `credential.helper osxkeychain` is darwin-only; `[coderabbit] machineId`
  is per-install identity and should be dropped.
- `~/.ssh/` (currently **untracked**): `id_ed25519`, `gitlab`, `hetzner` keys; `config` with
  `github.com`, `gitlab.com`, `pihole` (192.168.10.112, LAN) hosts. **Decision: keys stay out-of-band (§9).**
- `zed/settings.json`: `ssh_connections` → `192.168.10.113` (the Omarchy desktop). Harmless on other
  machines — kept verbatim (review: no over-engineering).
- `sesh/sesh.toml`: absolute paths (`/projects/app-studio/moth`) — kept verbatim everywhere for now
  (review decision; paths simply won't resolve off-Mac).
- `mise/config.toml`: **three Node majors installed (22/24/26)**; npm globals install into the active
  version's dir → they break on version switches. Full strategy in §8.5.
- `macos/setup.sh` + `_01-general.sh`: hardcode computer name `Tsyirvo-MacBookPro` — removed in the
  consolidation (§10.4).
- `worktrunk/config.toml`: is 100% **comments containing literal `{{ }}`** (its own template) — never
  templatize it.

### 2.6 Out of scope — `~/.pi` (agent config)

Kept in its **own git repository** (user decision, D17). Not managed by chezmoi and nothing in
`~/.pi` is referenced by this setup — possible future migration into these dotfiles if it ever
makes sense (tracked in §18 follow-ups).

---

## 3. Decisions log

| #   | Decision                                            | Choice                                                                            | Rationale                                                                                                                       |
| --- | --------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Secrets                                             | **Out-of-band, never in git.** No age/encryption pipeline (§9)                    | Public repo; encrypted blobs invite offline attacks; key.txt is a SPOF; rotation is painful. Keys are already untracked today.  |
| D2  | Omarchy boundary                                    | **Omarchy owns everything GUI**                                                   | No hypr/waybar/alacritty/themes in chezmoi. No fight with `omarchy-update`; manage divergence only via Omarchy's own overrides. |
| D3  | Fish on dev boxes                                   | **Fish everywhere**                                                               | One shell config everywhere; costs fish + `chsh` per box (§8.4).                                                                |
| D4  | Host roles                                          | `macbook` / `omarchy` / `devbox` (single value)                                   | Three distinct classes; switch to feature tags only if a 4th ambiguous machine appears.                                         |
| D5  | Personal flag                                       | `personal = role != devbox`                                                       | Drives cask/MAS/font install on Mac and GUI list on Omarchy.                                                                    |
| D6  | Repo history                                        | **Keep full history; one big migration commit** (review feedback)                 | No rewrite, no force-push. `stow-final` tag marks the pre-migration state.                                                      |
| D7  | `~/.claude`                                         | Manage **exactly 4 files** (settings, statusline, 2 hooks); ignore the rest       | Confirmed by review. Negation patterns in `.chezmoiignore` (§7.3).                                                              |
| D8  | `~/.local/bin`                                      | **Not managed.** mise shims + one-off installer binaries                          | Keep `~/bin` as the managed bin. npm-based tools get folded into the mise manifest (§8.5).                                      |
| D9  | television cables                                   | Keep all 57 + config                                                              | They're authored channel configs, not generated noise.                                                                          |
| D10 | `devin`, `amp`, `codexbar`, `.serena`, `.conductor` | **Never track** (review feedback)                                                 | Listed in `.chezmoiignore` so they can't sneak in later.                                                                        |
| D11 | Debian tooling                                      | Prefer **mise over apt** for modern CLIs                                          | Debian stable ships renamed/dated tools (`batcat`, `fdfind`, old `fd`); mise gives identical binaries on all machines.          |
| D12 | Omarchy packages                                    | **Use Omarchy's built-in package manager** (review feedback)                      | Resolved; script branch uses it (§8.3).                                                                                         |
| D13 | shared configs (sesh/worktrunk/tv, zed IP)          | **Ship unchanged on all machines** for now                                        | Review: avoid over-engineering routing; headless still excludes GUI apps.                                                       |
| D14 | Task runner                                         | **mise tasks** replace Makefile (review feedback)                                 | Leverages existing mise tooling; tasks in repo-root `mise.toml` (§8.6).                                                         |
| D15 | macOS defaults                                      | **Consolidate 8 scripts → one file** + prune dead keys (§10.4)                    | Review: current config is convoluted; 165 writes, typo domains, dead keys found.                                                |
| D16 | README                                              | **Full rewrite** for the chezmoi workflow + anti-drift rules (§19)                | Review: onboarding/day-to-day/packages must live in the repo, match the code, and stop drifting.                                |
| D17 | `~/.pi` agent config                                | **Out of scope** — kept in its own git repo; maybe migrate here later (follow-up) | User confirmed pi config has a dedicated git directory already; no chezmoi surface for now.                                     |

---

## 4. Target architecture

### 4.1 Machine matrix

|                 | **macbook**                       | **omarchy**                            | **devbox** (unRAID VM + Hetzner VPS) |
| --------------- | --------------------------------- | -------------------------------------- | ------------------------------------ |
| OS              | macOS (arm64)                     | Arch Linux + Hyprland                  | Debian/Ubuntu, headless              |
| Role            | `macbook`                         | `omarchy`                              | `devbox`                             |
| `osID`          | `darwin`                          | `linux-arch`                           | `linux-debian` / `linux-ubuntu`      |
| personal        | yes                               | yes                                    | no                                   |
| Package manager | Homebrew (+casks,+mas)            | **Omarchy built-in PM** (pacman-based) | apt + mise for modern CLIs           |
| Shell           | fish                              | fish                                   | fish (D3)                            |
| GUI config      | aerospace, ghostty, zed, raycast… | **none managed** (D2)                  | ghostty/zed/fonts ignored            |

### 4.2 Repository layout

```
dotfiles/
├── .chezmoiroot                       # contains: home
├── .editorconfig  .gitattributes  .gitignore
├── README.md                          # rewritten for the new system
├── install.sh                         # curl-able bootstrap (os-aware role default)
├── AGENTS.md                          # agent-in-repo conventions (§19.5) — keeps pi/claude agents from breaking the setup
├── mise.toml                          # << task runner + pinned dev toolchain (D14): apply / diff / update / check:* / fix-globals / test
├── .github/workflows/ci.yml           # shellcheck + gitleaks + docker apply matrix
│
├── home/                              # ← chezmoi source dir (from .chezmoiroot)
│   ├── .chezmoi.toml.tmpl             # config: role prompt + data
│   ├── .chezmoiignore                 # routing + class-based never-manage
│   ├── .chezmoiversion                # 2.70.0 (pin matches [tools] chezmoi in mise.toml)
│   ├── .chezmoidata/
│   │   ├── packages.yaml              # commented brew / pacman / apt lists (§8.1)
│   │   └── hosts.yaml                 # hostname → role / IP overrides
│   ├── .chezmoiexternal.toml.tmpl     # tmux tpm
│   ├── .chezmoiscripts/
│   │   ├── 00-bootstrap.sh.tmpl       # run_once_before_ — package manager, sudo
│   │   ├── 10-install-packages.sh.tmpl# run_onchange_after_ — keyed on packages.yaml + mise config
│   │   ├── 20-install-tmux-plugins.sh.tmpl  # run_onchange_after_ — pre-fetch tpm plugins (§8.7)
│   │   ├── 45-rebuild-native-modules.sh.tmpl  # run_onchange_ — re-runs on Node ABI change (§8.5.6, joelazar trick)
│   │   ├── 50-shell.sh.tmpl           # run_once_after_ — /etc/shells + chsh
│   │   ├── 60-macos-defaults.sh.tmpl  # run_once_after_ — darwin only
│   │   └── 90-gitleaks.sh.tmpl        # run_once_after_ — pre-commit hook
│   ├── dot_gitconfig.tmpl             # identity templated (shared across machines)
│   ├── dot_gitignore_global
│   ├── dot_Brewfile.tmpl              # rendered from packages.yaml (darwin)
│   ├── dot_claude/                    # ← EXACTLY 4 files (D7)
│   │   ├── settings.json
│   │   ├── statusline-ccusage.sh
│   │   └── hooks/{notify.sh, guard-protected-files.sh}
│   ├── bin/                           # ← old bin/, every file executable_
│   ├── dot_config/                    # ← old .config/, minus junk
│   │   ├── aerospace/  atuin/  bat/  btop/  eza/  fish/  gh/  gh-dash/
│   │   ├── git/  ghostty/  herdr/  hunk/  mise/  sesh/  starship.toml
│   │   ├── television/  tmux/  worktrunk/  zed/
│   └── private_dot_ssh/
│       └── config.tmpl                # host blocks only — NO keys (out-of-band, §9)
│
└── tasks/                            # repo-only, invisible to chezmoi (outside home/)
    ├── lib/functions.sh               # former scripts/functions.sh
    ├── macos/defaults.sh              # former macos/ — ONE consolidated file (§10.4)
    ├── secrets/                       # bootstrap choreography docs + helper scripts (§9.3)
    └── ci/test.sh                     # docker e2e test
```

`tasks/` is reached from scripts via `{{ .chezmoi.workingTree }}` (repo root); `{{ .chezmoi.sourceDir }}`
is `<repo>/home`.

### 4.3 Why this solves the noise problem

chezmoi maintains **explicit source files**; it never scans `~/.config`. An app writing new
config just creates a normal untracked directory in `$HOME` — the repo stays clean. Adoption of a
new tool is a conscious `chezmoi add` (see §6).

---

## 5. Data model — `home/.chezmoi.toml.tmpl`

Runs once at `chezmoi init`, prompts only for what can't be inferred, writes
`~/.config/chezmoi/chezmoi.toml`. No encryption config — secrets are out-of-band (D1, §9).

**Role prompt behavior (verified v2.72):** the interactive `promptChoice` is a raw-mode
(bubbletea) input, **not** a plain "type and Enter" line reader. It accepts on the first
**unique-prefix letter** of each choice — `m`/`o`/`d` → macbook/omarchy/devbox — quits
immediately with **no confirmation echoed**, and `Esc`/`Ctrl-C` cancels the whole command
**silently** (exit 0, no error). Piped stdin hangs it (it waits for terminal color/cursor
replies). Rule: never select the role interactively — **set `DOTFILES_ROLE`** (bypasses the
prompt; §13.1 A3), e.g. `env DOTFILES_ROLE=devbox chezmoi init …` for a devbox config.

```toml
{{- $osID := .chezmoi.os -}}
{{- if and (eq .chezmoi.os "linux") (hasKey .chezmoi "osRelease") -}}
{{-   $osID = printf "%s-%s" .chezmoi.os .chezmoi.osRelease.id -}}
{{- end -}}

{{- $defaultRole := "devbox" -}}
{{- if eq .chezmoi.os "darwin" -}}
{{-   $defaultRole = "macbook" -}}
{{- else if eq $osID "linux-arch" -}}
{{-   $defaultRole = "omarchy" -}}
{{- end -}}

{{- $role := default $defaultRole (env "DOTFILES_ROLE") -}}
{{- /* interactive-only prompt; env → OS inference keeps CI/containers silent */ -}}
{{- if and (eq $role $defaultRole) (stdinIsATTY) -}}
{{-   $role = promptChoice "Machine role - type ONE letter (m/o/d)" (list "macbook" "omarchy" "devbox") $defaultRole -}}
{{- end -}}
{{- $role = default $defaultRole $role -}}

[git]
    autoCommit = false
    autoPush = false

[diff]
    format = "git"     # `chezmoi diff` reuses git's pager/difftool config (joelazar)
    exclude = ["scripts"]

{{ if .isDarwin }}[merge]
    command = "opendiff"   # macOS FileMerge for `chezmoi merge` — ships with the OS (kutsan/joelazar used nvim)
{{ end }}

[data]
    role = {{ $role | quote }}
    osID = {{ $osID | quote }}

    # Derived flags — use in templates, never re-derive inline.
    isDarwin  = {{ eq .chezmoi.os "darwin" }}
    isLinux   = {{ eq .chezmoi.os "linux" }}
    isMacbook = {{ eq $role "macbook" }}
    isOmarchy = {{ eq $role "omarchy" }}
    isDevbox  = {{ eq $role "devbox" }}
    isDesktop = {{ ne $role "devbox" }}
    isHeadless = {{ eq $role "devbox" }}
    personal  = {{ ne $role "devbox" }}     # D5: drives cask/MAS/font install
```

Non-interactive installs pass `DOTFILES_ROLE=macbook|omarchy|devbox` (Docker CI, VPS
bootstrap — see §13.1); interactive installs get a `promptChoice` only when stdin is a TTY
(kutsan/narze lesson: never prompt in a scripted context). Re-running `chezmoi init` never
re-prompts once data is in the config.
Name/email are **not** prompted — shared identity lives statically in `dot_gitconfig.tmpl` (D5-followup,
review decision). Change later via `chezmoi edit-config` if a machine ever diverges.

---

## 6. Tracking policy (goal #1 — manual, noise-free tracking)

**Rule:** a tool is _managed_ only when it has a source file under `home/`. Everything else in
`$HOME` is invisible to the repo. `chezmoi unmanaged ~/.config` shows candidates.

**Allowlist (from §2.2)** — the only files that will ever live in the source dir.

**Never-manage classes** (in `.chezmoiignore`, §7.3): auth DBs, caches, logs, lock files,
state dirs, app-update artifacts, and the resolved-D10 dirs.

**New-tool adoption checklist** (paste into README):

1. `chezmoi add ~/.config/<tool>` (+ `-R` for dirs, `--follow` if symlink).
2. Is it a secret? If yes → **do not add**; document in `tasks/secrets/` (§9).
3. Is it a binary/app? → add to `packages.yaml` (§8.1) or `mise/config.toml` (§8.5).
4. Machine-specific? → routing in `.chezmoiignore`.
5. `chezmoi apply`, `git add home/ && git commit`.
6. Hygiene habit: `mise run check` = `chezmoi unmanaged ~/.config` after tool installs.

---

## 7. Routing — `home/.chezmoiignore` (v1 draft)

Patterns match **target** paths. Rendered as a template automatically.

```
# ---- class-based: never managed on any machine -------------------------------
Library
.cache/**
.local/share/mise/**
.ssh/known_hosts*
.ssh/agent
.config/amp/**
.config/codexbar/**
.config/devin/**
.config/github-copilot/**
.config/manus-computer-operator/**
.config/mole/**
.config/ngrok/**
.config/raycast/**
.config/fish/completions/**
.config/fish/themes/**
.config/fish/fish_variables
.config/herdr/herdr-client.log
.config/herdr/herdr-server.log
.config/herdr/session.json
.config/herdr/release-notes.json
.config/hunk/state.json
.config/worktrunk/approvals.toml*
.config/zed/prompts/**
.conductor/**
.serena/**

# ---- macbook-only (aerospace is a macOS cask) --------------------------------
{{ if not .isDarwin }}
.config/aerospace/**
{{ end }}

# ---- headless dev boxes get no GUI configs ------------------------------------
{{ if .isHeadless }}
.config/ghostty/**
.config/zed/**
.Brewfile
{{ end }}

# ---- Omarchy: owned by Omarchy, never managed here (D2) -----------------------
# (defensive — nothing is shipped, so nothing to exclude; keep this so nobody
#  adds dot_config/hypr later without revisiting the decision)
{{ if .isOmarchy }}
.config/hypr/***
.config/waybar/***
{{ end }}
```

Notes:

- `~/.claude` needs **no ignore entry**: we cherry-pick exactly the D7 set at add time (Phase 2,
  file by file), so Claude state/backups never enter the source. **Do not** use `exact_` on
  `~/.claude`. (A blanket `.claude/**` here would also block those 4 files — `add` honors ignores.)
- `.config/ngrok/**` is defensive: the token file must never be `chezmoi add`-ed by accident.
- Adding a pattern never removes an already-applied file — use `chezmoi remove` / `.chezmoiremove`
  during the transition if needed.
- **Nested ignore files** (kutsan pattern): tool-specific rules belong in a `.chezmoiignore` _inside_
  the tool's dir (e.g. `dot_config/exact_yazi/.chezmoiignore`), not the root list. Keeps the global
  ignore readable; the root file holds only cross-tool rules.

---

## 8. Packages — data-driven installs (goal #3)

### 8.0 Package taxonomy & workflow (how to add / remove a package)

Two manifests, no duplication:

| Manifest                           | Holds                                                                                          | Managed by                                     |
| ---------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `home/.chezmoidata/packages.yaml`  | **OS packages per machine class**: brew formulae, casks, MAS apps, pacman, AUR/Omarchy-PM, apt | `10-install-packages` script (hash-keyed)      |
| `home/dot_config/mise/config.toml` | **runtimes + global npm tools** (`node`, `python`, `bun`, `npm:…`) — single source of truth    | `mise install` in the same script (hash-keyed) |

**Adding a package:** pick the manifest by the table above → add one commented line → `chezmoi
apply` (the `run_onchange_` script detects the hash change and installs it). No shell editing.

**Removing a package:** delete its line from `packages.yaml` → `chezmoi apply`. The script installs
only what's listed; to actually _uninstall_ from the OS:

- macOS: `brew uninstall <x>` / `brew uninstall --cask <x>` manually (or `brew bundle cleanup`
  with care — it removes anything not in the Brewfile).
- Arch / apt: `sudo pacman -R <x>` / `sudo apt remove <x>` manually. Not auto-purged (safe default).

### 8.1 `home/.chezmoidata/packages.yaml` (v1 draft — fully commented, Brewfile-style)

Every list has a `##` header explaining its purpose, so the "where does this go?" question answers
itself; every entry gets an inline note when it isn't self-explanatory.

```yaml
# =============================================================================
# packages.yaml — per-machine-class OS packages
# How to use:
#   add   → one commented line in the right section → `chezmoi apply` installs it
#   remove → delete the line → `chezmoi apply` stops managing it (manual uninstall, §8.0)
# Runtime tools & npm globals live in dot_config/mise/config.toml, NOT here (§8.5)
# =============================================================================

packages:
  # ---------------------------------------------------------------------------
  ## Darwin (macOS) — brew formulae -------------------------------------------
  ## Core build/runtime deps; tap'd formulae; terminal; latex
  ## Most are cross-platform CLIs mirrored in the arch/apt sections.
  darwin:
    brews:
      - openssl # TLS lib for build tooling
      - gnupg # gpg for commit signing (later) & ssh key mgmt
      - cmake # build dep (watchman, cocoapods)
      - fish # shell (D3: fish everywhere)
      - tmux # terminal multiplexer
      - starship # prompt
      - bat # cat clone
      - eza # ls replacement
      - zoxide # cd replacement
      - fd # find replacement
      - fzf # fuzzy finder
      - atuin # shell history sync
      - sesh # tmux+projects session switcher
      - tv # television — terminal fuzzy viewer
      - git # git (with git-lfs below)
      - git-extras # extra git commands (git-ignore, git-release…)
      - git-lfs # large file storage
      - difftastic # git diff tool (gitconfig: difftool)
      - gh # GitHub CLI
      - hk # hunk? rust CLI (see home dir tools)
      - worktrunk # worktree manager (wt)
      - tuicr # tailscale? update? (ask: what is tuicr — from commit log)
      - lazygit # TUI git
      - gitleaks # secret scanning guard (hooks + CI)
      - mise # runtime/env manager (node, python, java…)
      - mas # Mac App Store CLI (drives the mas section)
      - btop # system monitor
      - ripgrep # grep replacement
      - sshs # ssh config-based host picker
      - blueutil # bluetooth CLI (macOS only)
      - borders # JankyBorders — window border for Aerospace
      - mactop # mac silicon stats (macOS only)
      - terminal-notifier# finish-notify for long tasks
      - mole # Mole — local ORM (dev tool)
      - gradle # JVM build tool (Android)
      - watchman # file watching (React Native)
      - cocoapods # iOS deps
      - maven # JVM build tool
      - scrcpy # Android mirroring
      - fastlane # mobile CI/release
      - expo-orbit # Expo dev tooling
      - supabase # supabase CLI
      - doppler # env/secrets CLI
      - docker # docker CLI (orbstack cask provides engine)
      - ctop # container top
      - ollama # local LLM runtime
      - herdr # herd orchestration (Pi-adjacent tooling)
      - rtk # repo toolkit hooks (claude hooks)
      - mlx # Apple silicon ML libs

    ## Casks — GUI apps (only installed when personal=true) --------------------
    ## Terminals & editors
    casks:
      - ghostty # terminal
      - raycast # launcher
      - aerospace # tiling WM (also taps nikitabobko/tap)
      - cursor # AI editor
      - zed # editor (config shipped via dot_config/zed)
    # crascks: android-studio, zen, google-chrome, …
    # (keep the full current Brewfile list; it already has ## section headers —
    #  port the header comments verbatim into this yaml)

    ## Mac App Store (mas) — id: name ------------------------------------------
    mas:
      Spark Mail: 6445813049
      WhatsApp: 310633997
      Yubico Authenticator: 1497506650
      Transporter: 1450874784
      RocketSim: 1504940162
      Infuse: 1136220934
      Pure Paste: 1611378436
      Brother iPrint&Scan: 1193539993

    ## Fonts (casks, personal only)
    fonts_casks: ["font-jetbrains-mono-nerd-font", "font-fira-code-nerd-font"]

  # ---------------------------------------------------------------------------
  ## Arch / Omarchy — pacman + Omarchy's built-in PM (D12) ----------------------
  ## Same cross-platform CLI set as the brew list above.
  arch:
    pacman:
      - fish tmux starship bat eza zoxide fd fzf atuin ripgrep
      - git git-lfs difftastic github-cli lazygit gitleaks btop
      - gnupg cmake openssl curl
      # first-pass; validate each against the Omarchy repos on boot (§18.2)
    omarchy_extra: [] # Omarchy-specific packages via its built-in PM — fill at install time

  # ---------------------------------------------------------------------------
  ## Debian/Ubuntu dev boxes — apt ----------------------------------------------
  ## NOTE: Debian stable ships RENAMED or OLD tools → mise covers those (§8.5).
  debian:
    apt:
      - fish git curl unzip ca-certificates build-essential
      - tmux ripgrep fzf btop gnupg
    # ships as `batcat`/`fdfind` → aliases added in fish config (§8.3)
    apt_renamed:
      bat: batcat
      fd: fdfind
```

> The full Brewfile (~120 lines) is ported 1:1 into this yaml with its existing `##` section
> headers preserved as comments — nothing is dropped during the migration, only _classified_.

### 8.2 Generated file — `home/dot_Brewfile.tmpl`

Rendered only on darwin and consumed by `brew bundle --file=$HOME/.Brewfile`:

```text
tap 'FelixKratz/formulae'          # JankyBorders
tap 'nikitabobko/tap'              # aerospace
cask_args appdir: '/Applications'
{{ range .packages.darwin.brews -}}
brew {{ . | quote }}
{{ end -}}
{{ if .personal }}{{ range .packages.darwin.casks -}}
cask {{ . | quote }}
{{ end -}}
{{ range .packages.darwin.fonts_casks -}}
cask {{ . | quote }}
{{ end -}}
{{ range $name, $id := .packages.darwin.mas -}}
mas {{ $name | quote }}, id: {{ $id }}
{{ end -}}{{ end }}
```

### 8.3 Install script — `home/.chezmoiscripts/10-install-packages.sh.tmpl`

`run_onchange_after_` — runs **after** files are applied so the managed manifests it reads
(`~/.Brewfile`, `~/.config/mise/config.toml`) already exist on a fresh machine.

```bash
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# Re-runs when contents change:
#   packages.yaml:   {{ include ".chezmoidata/packages.yaml" | sha256sum }}
#   mise config:     {{ include "dot_config/mise/config.toml" | sha256sum }}
# Change either file → script re-renders → run_onchange re-runs. Nothing changed → nothing runs.

The hashes render into the **body** (they're comments) — that IS the change-detection key:
chezmoi re-runs `run_onchange_` scripts when the rendered content changes, so the digest lines
must NOT go in the filename (paths like `.chezmoidata/packages.yaml` contain `/`, which is
illegal in filenames — any `include`-based name is unbuildable, verified v2.72).

{{ if .isDarwin -}}
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$({{ if eq .chezmoi.arch "arm64" }}/opt/homebrew{{ else }}/usr/local{{ end }}/bin/brew shellenv)"
brew bundle --file="${HOME}/.Brewfile" --no-lock

{{ else if eq .osID "linux-arch" -}}
sudo pacman -S --needed --noconfirm {{ range .packages.arch.pacman }}{{ . }} {{ end }}
# Omarchy's built-in package manager for Omarchy-specific packages (D12):
#   resolve the exact command from omarchy-update / omarchy docs on first boot
{{ range .packages.arch.omarchy_extra }}<omarchy-pm> -S --noconfirm {{ . }} {{ end }}

{{ else -}}
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && sudo apt-get install -y {{ range .packages.debian.apt }}{{ . }} {{ end }}
{{ end -}}

# ---- runtimes + global npm tools ----------------------------------------------
# dot_config/mise/config.toml is the ONLY manifest for these (single source of truth).
if ! command -v mise >/dev/null 2>&1; then curl -fsSL https://mise.run | sh; fi
mise install        # idempotent; provisions every runtime + npm: tool listed
```

(On Debian, fish alias lines for `batcat`/`fdfind` are added in `dot_config/fish/aliases.fish`.)

### 8.4 Fish everywhere (D3)

`home/.chezmoiscripts/50-shell.sh.tmpl` (run*once_after*): resolves the fish binary through
Homebrew when necessary, adds it to `/etc/shells` if missing, and `chsh -s <fish>` — idempotent.
Fish configuration is split into ordered `conf.d` snippets; Catppuccin Mocha colors are declared
there, so neither Fisher nor `fish_variables` is managed. Existing machines retire old Fisher
artifacts manually after cutover (§12.6.2).

### 8.5 mise & global npm packages — strategy (review feedback, goal #3)

**The problem, verified on your machine:** mise has **three Node majors installed
(22.22.0, 24.3.0/24.18.x, 26.8.1)** and `npm prefix -g` resolves to the _active version's install
dir_ (`~/.local/share/mise/installs/node/26.8.1`). Any `npm i -g` lands in that dir — so switching
Node via mise hides/rebreaks every global. That's exactly the pain you hit.

**Policy:**

1. **One runtime manifest.** `dot_config/mise/config.toml` is the _only_ place runtimes and global
   tools are declared. `mise install` (wired into `10-install-packages`, hash-keyed) reproduces
   everything, anywhere. Never `npm i -g` ad-hoc.
2. **Global tools are mise tools.** Any package you'd `npm i -g` becomes `"npm:<name>" = "<ver>"`
   in `[tools]` (pi, ctx7, eas-cli are already there). mise installs them reproducibly and
   re-installs them when the associated Node changes.
3. **Pin what matters.** Keep one active Node per machine class (e.g. `node = "26"` on macbook) and
   let `npm:` tools float to `latest` — or pin both if a tool is ABI-sensitive (`sharp`, `esbuild`).
   During migration: decide the per-class Node version and `mise rm` the stragglers (22/24 aliases).
4. **`mise install` is the repair command.** Globals broke? Run `mise run fix-globals`
   (`mise install`) — one command, no hunting.
5. **Audit at migration time:** `npm ls -g --depth=0` per installed Node, plus the npm-installed
   binaries in `~/.local/bin` (claude-code, specify, coderabbit, …) → fold each into `[tools]`
   (`"npm:@anthropic-ai/claude-code" = "latest"`) or leave unmanaged for non-npm binaries (Go/Rust
   installers stay out of the manifest).
6. **Native addons self-heal on Node changes (joelazar trick).** `45-rebuild-native-modules.sh.tmpl`
   is a `run_onchange_` script whose body embeds
   `{{ output "node" "-p" "process.versions.modules" | trim | default "unknown" }}` as a comment line
   (the ABI becomes a *content key* — the change triggers re-run; the `2>/dev/null` guard variant
   can't live in a filename because `/` is illegal there — verified v2.72).
   No manual "I switched Node, now fix globals" step. (`mise run fix-globals` remains the manual
   hammer for everything else.)

### 8.6 Task runner — repo-root `mise.toml` (D14)

```toml
[settings]
lockfile = true        # commit mise.lock → reproducible repo toolchain (kutsan pattern)

[tools]                # pinned dev toolchain for repo work — NOT the user's runtime manifest (§8.5)
chezmoi = "2.70.5"     # must match .chezmoiversion
shellcheck = "0.11.0"
gitleaks = "8.29.0"
shfmt = "3.13.1"
actionlint = "1.7.12"
zizmor = "1.26.1"
pinact = "4.1.0"

[tasks.apply]
run = "chezmoi apply -v"
[tasks.diff]
run = "chezmoi diff"
[tasks.update]
run = "chezmoi update -v"
[tasks.check]
run = "chezmoi unmanaged ~/.config"
[tasks."check:shellcheck"]
run = "bash tasks/ci/shellcheck-rendered.sh"   # renders .tmpl then shellchecks (§13.1)
[tasks."check:gitleaks"]
run = "gitleaks git --no-banner"
[tasks."check:workflows"]   # actionlint + zizmor guard CI itself
run = "bash -c 'actionlint && zizmor --strict-collection .github/workflows/'"
[tasks."update:pinact"]
run = "pinact run --update"                    # re-pin GH Action SHAs
[tasks.fix-globals]
run = "mise install"        # §8.5: reproduce runtimes + globals
[tasks.macos]
run = "bash tasks/macos/defaults.sh"
[tasks.test]
run = "bash tasks/ci/test.sh devbox debian:bookworm"
```

`mise run apply` etc. Project-level file — invisible to chezmoi (outside `home/`).

### 8.7 tmux plugins — `.chezmoiexternal.toml.tmpl` + `20-install-tmux-plugins`

**tpm (the manager)** is applied by chezmoi as an archive external — no git submodule,
refreshed weekly. `tmux.conf` ends with `run '~/.config/tmux/plugins/tpm/tpm'`, so tpm is
sourced on every tmux start and binds its install/update keys.

**The plugins themselves are NOT auto-installed by tpm on start** (tpm's `source_plugins`
silently skips absent dirs) — without a bootstrap step a fresh machine would need a manual
`<prefix>+I`. So `20-install-tmux-plugins.sh.tmpl` (a `run_onchange_after_` script, hashed on
the tmux.conf body) pre-fetches every `@plugin` via tpm's standalone CLI
(`~/.config/tmux/plugins/tpm/bin/install_plugins`): it starts a headless server, reads the
plugin list + `TMUX_PLUGIN_MANAGER_PATH` from the freshly-sourced config, clones missing
plugins, then exits on its own (idle server with no sessions shuts down). Verified: run on a
fresh isolated HOME, it cloned all 8 plugins without any interactive session.

```toml
[".config/tmux/plugins/tpm"]
    type = "archive"
    url = "https://github.com/tmux-plugins/tpm/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "168h"
```

---

## 9. Secrets — out-of-band, never in git (D1)

### 9.1 Principle

The repo is **public**. Nothing secret is ever versioned — _including age-encrypted blobs_. This
was reviewed and decided: keeping SSH keys out of git matches today's setup, avoids a key-distribution
SPOF, removes an offline-attack surface, and makes rotation trivial (no re-encryption of blobs).

### 9.2 What IS committed (safe by design)

| File                          | Why it's safe                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------------ |
| `private_dot_ssh/config.tmpl` | Host blocks (github/gitlab/hetzner/pihole) — no keys, no passwords.                        |
| `dot_gitconfig.tmpl`          | Identity (name/email/tools). Shared across machines per review feedback; not a credential. |
| `gh/hosts.yml`                | User map only — no OAuth tokens today. If tokens ever appear, stop tracking it.            |
| `dot_config/ngrok/`           | **Nothing.** The authtoken file is excluded via `.chezmoiignore`.                          |

### 9.3 What stays out-of-band — bootstrap choreography

Per new machine, copy from the Mac / 1Password / USB:

| Item                                 | Target                                                | Source                           |
| ------------------------------------ | ----------------------------------------------------- | -------------------------------- |
| SSH private+public keys              | `~/.ssh/` (`id_ed25519`, `gitlab`, `hetzner`, `.pub`) | Mac (`scp -r`, USB) or 1Password |
| ngrok authtoken                      | `~/.config/ngrok/ngrok.yml`                           | ngrok dashboard / 1Password      |
| future tokens (`.npmrc`, cloud CLIs) | as needed                                             | 1Password                        |

`tasks/secrets/README.md` documents this checklist; `tasks/secrets/bootstrap-ssh.sh` is an optional
helper that copies from `$SECRETS_DIR` if you mount one. This is a 2-minute manual step — the exact
trade paid for never having secrets in git.

### 9.4 Guards

- `90-gitleaks.sh.tmpl` installs the gitleaks pre-commit hook (`gitleaks protect --staged`).
- CI runs `gitleaks git` on push (already in the Brewfile / Arch lists, §13).
- `.gitignore` keeps `*.key`, `*key.txt`, `*.pem`, `ngrok.yml` as a last line of defense.

---

## 10. Scripts & tasks

### 10.1 Scripts — naming & order

Rules: scripts live in `.chezmoiscripts/`, run but are never written to `$HOME`.
**The prefix must be in the FILENAME** (`run_once_before_00-bootstrap.sh.tmpl`) — chezmoi
rejects bare names like `00-bootstrap.sh.tmpl` as "not a script" (verified v2.72).
`run_once_` keyed
on content (make them idempotent anyway); `run_onchange_` keyed on content change per filename;
`before_`/`after_` relative to file apply; order is alphabetical within a group.

| Script                      | Type                       | Purpose                                                   |
| --------------------------- | -------------------------- | --------------------------------------------------------- |
| `00-bootstrap`              | `run_once_before_`         | package manager present (brew/omarchy-pm/apt), sudo -v    |
| `10-install-packages`       | `run_onchange_after_`      | §8.3, hashed on `packages.yaml` + mise config             |
| `20-install-tmux-plugins`   | `run_onchange_after_`      | §8.7, hashed on tmux.conf; tpm CLI installer               |
| `45-rebuild-native-modules` | `run_onchange_`            | Node ABI change → rebuild global native addons (§8.5.6)   |
| `50-shell`                  | `run_once_after_`          | fish → `/etc/shells` + `chsh` (all machines)              |
| `60-macos-defaults`         | `run_once_after_` (darwin) | `bash {{ .chezmoi.workingTree }}/tasks/macos/defaults.sh` |
| `90-gitleaks`               | `run_once_after_`          | pre-commit hook                                           |

### 10.2 `tasks/` split

`tasks/macos/defaults.sh` and `tasks/lib/functions.sh` are plain `.sh` (shellcheckable), reached via
`{{ .chezmoi.workingTree }}`. Everything in `tasks/` is invisible to chezmoi.

### 10.3 macOS defaults — consolidation plan (review feedback, D15)

**Current state (measured):** 8 files, **165 `defaults write` lines, 27 domains**, plus pmset calls.

**Known-dead or wrong content (verified in the repo):**

| Problem                            | Evidence                                                                   | Action                                                                                            |
| ---------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Typo'd domain**                  | `com.aipple.driver.AppleBluetoothMultitouch.trackpad` (`_08-inputs.sh:11`) | Delete — never worked.                                                                            |
| **Dashboard keys**                 | `com.apple.dashboard …`, `dashboard-in-overlay` (`_03-dock.sh:55,58`)      | Delete — Dashboard removed in Catalina (2020).                                                    |
| **iTerm2 key**                     | `com.googlecode.iterm2 PromptOnQuit` (`_05-apps.sh:243`)                   | Delete — you run Ghostty.                                                                         |
| **51 Safari keys** (`_05-apps.sh`) | Browser of choice is Zen/Chrome per Brewfile                               | Trim to the handful you actually use, or delete the block.                                        |
| **Stale mths.be-era keys**         | `NSWindowResizeTime`, `NSUseAnimatedFocusRing`, …                          | Verify each with `defaults read <domain> <key>` on current macOS; keep only keys that still work. |
| **Hardcoded computer name**        | `Tsyirvo-MacBookPro` in `setup.sh` + `_01-general.sh`                      | Remove (or take from env/`scutil`); a rename shouldn't be part of defaults.                       |
| **Commented-out cruft**            | `_07-energy.sh` keeps 6 commented `pmset` variants                         | Delete or activate; don't ship a half-disabled profile.                                           |

**Target shape — one file, readable:**

```
tasks/macos/defaults.sh
├── preflight: sudo -v, `defaults read` sanity guard
├── section General      (NSGlobalDomain survivors, ~10 keys)
├── section Dock         (auto-hide, size, magnification — ~6 keys)
├── section Finder       (show-all, path bar, extensions — ~8 keys)
├── section Trackpad/Mouse (working keys only — the aipple typo deleted)
├── section Screensaver  (idleTime, from _02)
├── section Energy       (pmset — reviewed, no commented-out variants)
├── section Spotlight (_04, if still used)
└── killall Dock Finder SystemUIServer; note "some changes need logout"
```

Process: consolidate → prune the table above → verify each remaining key on current macOS →
keep it in one file with `##` section comments. Anything you're unsure about: delete it; defaults
are re-addable in one line when you actually miss it.

---

## 11. File-by-file migration map

Source-side moves inside the repo (old → new) — nothing in `$HOME` changes until cutover (§12.6):

| Old (repo)                                                                                              | New (chezmoi source)                    | Change                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.gitconfig`                                                                                            | `home/dot_gitconfig.tmpl`               | template identity; gate `credential.helper` on darwin; **drop `[coderabbit] machineId`**; no per-machine signing                                                                      |
| `.gitignore_global`                                                                                     | `home/dot_gitignore_global`             | verbatim                                                                                                                                                                              |
| `.config/aerospace/*`                                                                                   | `home/dot_config/aerospace/*`           | verbatim, darwin-only route                                                                                                                                                           |
| `.config/atuin/config.toml`                                                                             | `home/dot_config/atuin/config.toml`     | verbatim                                                                                                                                                                              |
| `.config/bat/themes/*`                                                                                  | `home/dot_config/bat/themes/*`          | drop `.DS_Store`                                                                                                                                                                      |
| `.config/btop/*`                                                                                        | `home/dot_config/btop/*`                | verbatim                                                                                                                                                                              |
| `.config/eza/theme.yml`                                                                                 | `home/dot_config/eza/theme.yml`         | verbatim                                                                                                                                                                              |
| `.config/fish/*`                                                                                        | `home/dot_config/fish/*`                | Minimal `config.fish.tmpl`; ordered `conf.d` snippets for Homebrew, environment, Catppuccin Mocha, tools, and aliases; keep `wc`/`wcp`/`wpi`; do **not** copy Fisher or autopair artifacts. |
| `.config/gh/*` `gh-dash/*`                                                                              | `home/dot_config/gh/*`                  | verbatim                                                                                                                                                                              |
| `.config/ghostty/config`                                                                                | `home/dot_config/ghostty/config`        | verbatim; skipped on headless                                                                                                                                                         |
| `.config/git/ignore`                                                                                    | `home/dot_config/git/ignore`            | verbatim (`**/.claude/settings.local.json`)                                                                                                                                           |
| `.config/herdr/config.toml`                                                                             | `home/dot_config/herdr/config.toml`     | drop `release-notes.json`                                                                                                                                                             |
| `.config/hunk/config.toml`                                                                              | `home/dot_config/hunk/config.toml`      | drop `state.json`                                                                                                                                                                     |
| `.config/mise/config.toml`                                                                              | `home/dot_config/mise/config.toml`      | **canonical runtime manifest** (§8.5); prune stray node aliases                                                                                                                       |
| `.config/sesh/sesh.toml`                                                                                | `home/dot_config/sesh/sesh.toml`        | verbatim, **plain** (D13 — shared everywhere)                                                                                                                                         |
| `.config/starship.toml`                                                                                 | `home/dot_config/starship.toml`         | verbatim                                                                                                                                                                              |
| `.config/television/*` (58)                                                                             | `home/dot_config/television/*`          | verbatim                                                                                                                                                                              |
| `.config/tmux/tmux.conf`                                                                                | `home/dot_config/tmux/tmux.conf`        | verbatim; tpm via external                                                                                                                                                            |
| `.config/worktrunk/config.toml`                                                                         | `home/dot_config/worktrunk/config.toml` | verbatim, **plain** (contains `{{ }}`)                                                                                                                                                |
| `.config/zed/*`                                                                                         | `home/dot_config/zed/*`                 | verbatim, **plain** (D13; headless-ignored), ssh_connections IP kept                                                                                                                  |
| `ai-tools/.claude/{settings.json,statusline-ccusage.sh,hooks/notify.sh,hooks/guard-protected-files.sh}` | `home/dot_claude/…`                     | exactly these 4 (D7); rest of `.claude` ignored                                                                                                                                       |
| `bin/*`                                                                                                 | `home/bin/*`                            | all `executable_`; fix `clean-branches` bit                                                                                                                                           |
| `macos/*` (9 files)                                                                                     | `tasks/macos/defaults.sh` (1 file)      | consolidation per §10.3                                                                                                                                                               |
| `packages/Brewfile`                                                                                     | `home/dot_Brewfile.tmpl`                | rendered from commented `packages.yaml`                                                                                                                                               |
| `packages/setup.sh`                                                                                     | `.chezmoiscripts/10-*`                  | replaced by declarative install                                                                                                                                                       |
| `scripts/functions.sh`                                                                                  | `tasks/lib/functions.sh`                | sourced by task/script                                                                                                                                                                |
| `.stowrc`, `.stow-local-ignore`                                                                         | delete                                  | stow is gone                                                                                                                                                                          |
| `.gitignore`                                                                                            | rewrite                                 | repo hygiene: `.DS_Store`, `*.log`, `*.key`, `ngrok.yml`, `.conductor`, `.serena`, …                                                                                                  |
| —                                                                                                       | `mise.toml` (repo root)                 | task runner (D14)                                                                                                                                                                     |

---

## 12. Migration runbook

Phases 1–5 touch **nothing** on the Mac.

### 12.1 Phase 0 — freeze & safety (on the Mac)

```bash
git tag stow-final                     # marker for the pre-migration tree
```

### 12.2 Phase 1 — skeleton in the existing repo

```bash
# a) install chezmoi (every later phase needs it):
curl -fsSL https://get.chezmoi.io | sh -s -- -b ~/.local/bin

export PATH="$HOME/.local/bin:$PATH"

# b) skeleton, run from the repo root:
cd ~/dotfiles
mkdir -p home/.chezmoiscripts home/.chezmoidata home/.chezmoiexternals tasks
echo home > .chezmoiroot

# c) session-local alias. `cm` is defined HERE, in this shell only — it is a runbook
#    convenience, never part of your dotfiles. `--source "$PWD"` + `.chezmoiroot` resolve
#    to $PWD/home automatically (verified against v2.72; NB: there is NO CHEZMOI_SOURCE
#    env var — an earlier draft implying one was wrong).
alias cm='chezmoi --source "$PWD"'
cm source-path          # sanity check: prints <repo>/home
```

### 12.3 Phase 2 — copy real files into the source tree

**Why not `chezmoi add` here (verified against v2.72):** while `~/.config` is still the stow
symlink, `chezmoi add` cannot walk through it — `--follow` on directories is rejected
("follow and recursive are mutually exclusive for directories", and recursion is on by
default), and a plain directory add trips over the symlink and records a `symlink_dot_config`
entry, which then fails. `--follow` fails even for file symlinks like
`~/.claude/settings.json`, because the walk includes the parent dir. So Phase 2 **copies the
same bytes** straight from the working tree into `home/` (the files are already regular files
inside the repo), and Phase 3 encodes attributes with `chattr`. Everyday adoption post-cutover
uses normal `chezmoi add` (§6) — real dirs by then.

```bash
# directory trees — copied from the working tree (identical bytes to ~/.config):
mkdir -p home/dot_config home/dot_config/bat
for d in fish zed ghostty tmux television atuin btop eza gh gh-dash git mise sesh herdr hunk worktrunk; do
  cp -aL "$PWD/.config/$d" home/dot_config/
done
cp -aL "$PWD/.config/bat/themes" home/dot_config/bat/     # bat/.DS_Store NOT copied
cp -aL "$PWD/.config/starship.toml" home/dot_config/

# purge whatever a tree copy swept in that is NOT in the §2.2 allowlist (all untracked):
rm -f  home/dot_config/herdr/release-notes.json home/dot_config/hunk/state.json   # committed junk (drop)
rm -f  home/dot_config/fish/fish_variables
rm -rf home/dot_config/fish/completions home/dot_config/fish/themes
rm -f  home/dot_config/fish/fish_plugins home/dot_config/fish/conf.d/autopair.fish
rm -f  home/dot_config/fish/functions/_autopair_*.fish home/dot_config/fish/functions/fisher.fish home/dot_config/fish/functions/wt.fish
rm -rf home/dot_config/tmux/plugins                  # tpm + plugin git CLONES (~648 files!) — plugins are installed at runtime (tpm, §8.7)
rm -rf home/dot_config/zed/prompts                   # prompts-library mdb
rm -f  home/dot_config/worktrunk/approvals.toml*     # runtime state
rm -f  home/dot_config/herdr/*.log home/dot_config/herdr/session.json

# VERIFY (acceptance): home/dot_config must equal the git-tracked allowlist, modulo the
# deliberate drops (bat/.DS_Store, cmux/*, herdr/release-notes.json, hunk/state.json):
diff <(git ls-files '.config/**' | sed 's|^\.config/|home/dot_config/|' | sort) \
     <(find home/dot_config -type f | sort)

# top-level files (cp -L dereferences symlinks like ~/.gitconfig):
cp -aL .gitconfig home/dot_gitconfig
cp -aL .gitignore_global home/dot_gitignore_global
cp -aL bin home/                                          # 6 scripts; +x bits preserved by -a

# the D7 set — exactly these 4 files, nothing else from ~/.claude:
mkdir -p home/dot_claude/hooks
cp -aL ai-tools/.claude/settings.json home/dot_claude/
cp -aL ai-tools/.claude/statusline-ccusage.sh home/dot_claude/
cp -aL ai-tools/.claude/hooks/notify.sh ai-tools/.claude/hooks/guard-protected-files.sh \
  home/dot_claude/hooks/

# ssh: hosts-only config; keys/ngrok stay out-of-band (§9):
mkdir -p home/private_dot_ssh
cp -aL ~/.ssh/config home/private_dot_ssh/config
# SSH / ngrok / keys: NOT added (out-of-band, §9) — no chattr +encrypted anywhere

# The source tree must contain NO symlinks and NO symlink_ entries:
find home -type l -print        # must be empty
find home -name 'symlink_*'     # must be empty
```

### 12.4 Phase 3 — attributes & templates

```bash
cm chattr +executable ~/bin/* ~/.claude/hooks/guard-protected-files.sh ~/.claude/hooks/notify.sh ~/.claude/statusline-ccusage.sh
cm chattr +template ~/.gitconfig                     # identity templating
cm chattr +private,+template ~/.ssh/config           # 0600 + hosts templating (comma form!)
# chattr rewrites source names to encode attributes for you:
#   bin/clean-branches → bin/executable_clean-branches   dot_gitconfig → dot_gitconfig.tmpl
#   private_dot_ssh/config → private_dot_ssh/private_config.tmpl  (verified against v2.72)
```

Then hand-edit templates per the map (§11): `config.fish.tmpl`, `dot_gitconfig.tmpl`,
`private_dot_ssh/config.tmpl`, `.chezmoiignore`, `.chezmoidata/packages.yaml`, `.chezmoi.toml.tmpl`,
scripts, `tasks/` moves (incl. the macOS consolidation §10.3), Brewfile.tmpl, `mise.toml`,
**and rewrite `README.md` from the draft in §19** (ship it in the same migration commit so the
repo never points at the old stow flow).

**Beware:** `cm add` while `~/.config` is still the old symlink writes sources from the _old_ tree.
That's fine (same bytes). Do **not** delete the stow repo until after Phase 6.

### 12.5 Phase 5 — verify before applying

**Gotcha:** `execute-template` only has `.packages` (auto-loaded from `.chezmoidata/`). The
`role`/`personal`/`isDarwin` keys come from the **config file's `[data]` section** — which is
rendered by `chezmoi init` (Phase 6). Pre-cutover there is no real config, so render the
config template to a **temp** file first: nothing touches `~/.config`, and the state DB is
untouched (verified v2.72).

```bash
DOTFILES_ROLE=macbook chezmoi init --config /tmp/chezmoi.toml --source "$PWD"
# redefine `cm` for this session (overrides the §12.2 alias):
cm() { chezmoi --source "$PWD" --config /tmp/chezmoi.toml "$@"; }

cm execute-template < home/dot_Brewfile.tmpl
cm execute-template '{{ .role }} {{ .osID }} {{ .isDarwin }}'
cm cat ~/.config/git/config             # effective rendered targets
cm diff                                  # read every line
cm doctor
mise install                             # validate the runtime manifest on this machine
# verify another machine class with a fresh env + temp config: DOTFILES_ROLE=devbox
# … (re-run init → /tmp/chezmoi-devbox.toml, point cm at it)
```

Post-cutover (Phase 6 runs the real `chezmoi init`) plain `cm execute-template` works without
`--config`, because `~/.config/chezmoi/chezmoi.toml` then carries the `[data]`.

**Shell note — the runbook is bash.** In **fish** the bash-only constructs (`VAR=x cmd` prefix,
`name() { … }`) don't parse; use the fish equivalents:
```fish
env DOTFILES_ROLE=macbook chezmoi init --config /tmp/chezmoi.toml --source "$PWD"
function cm
    chezmoi --source "$PWD" --config /tmp/chezmoi.toml $argv
end
```
(`$argv` ≈ bash `"$@"`; `$PWD` resolves at call time.)

**Expected `cm doctor` output pre-cutover:** the `source-dir`/`working-tree` "dirty git tree"
and `suspicious-entries` warnings (state DB + `herdr` sockets inside `~/dotfiles/.config/…`)
are **by design** — `~/.config` *is* today's repo worktree (its untracked files are hidden
from git by the global `/.config` ignore rule) and the whole tree is deleted at decommission
(§12.6.1). `merge-command` is `opendiff` (FileMerge) on macOS — doctor reads `ok` there; on
Linux it's unset and may warn. The `age`/`1password`/`bitwarden`/… `info` rows are expected
(D1 — no secrets live in chezmoi).

### 12.6 Phase 6 — cut over the MacBook

```bash
# 0) BACK UP untracked state FIRST. Today ~/.config IS the repo dir (`dotfiles/.config`), so
#    app-written state (ngrok authtoken!, github-copilot auth.db, raycast, mole, …) physically
#    lives in the WORKING TREE and is NOT in git — `git tag stow-final` does NOT save it.
mv "$PWD/.config" "$PWD/.config.stow-backup"   # move the real dir; ~/.config link goes dangling
rm -f ~/.config
mkdir ~/.config                                 # fresh real dir — chezmoi fills it

# 1) remove the remaining stow symlinks
stow -D -t ~ .                                   # ~/bin, ~/.gitconfig, ~/.gitignore_global, ai-tools
ls -la ~/.config                                 # confirm it's a real dir now
rm -f ~/bin ~/.gitconfig ~/.gitignore_global     # only if still symlinks

# 2) apply, previews first, never blind
chezmoi init && chezmoi diff && chezmoi apply --dry-run --verbose && chezmoi apply -v

# 3) restore the UNMANAGED dirs you still need into the new real ~/.config
cp -a "$PWD/.config.stow-backup/ngrok" ~/.config/            # your authtoken lives here!
cp -a "$PWD/.config.stow-backup/github-copilot" ~/.config/   # keep existing auth + WAL
cp -a "$PWD/.config.stow-backup/raycast" ~/.config/
# ...anything else you want (mole, manus…). Every restored dir is in .chezmoiignore, so it
# stays out of the repo; nothing is re-added accidentally.

mise install                             # re-resolve tool paths post-symlink-removal
open/run every app once                  # fish, zed, ghostty, tmux, gh, tv…
# once everything works, keep the backup until apps have run once — the actual removal is the
# **decommission** step (§12.6.1), because deleting `.config.stow-backup` is what records the
# removal of all tracked `.config/*` files from git.
```

Keep the old tree reachable via `git tag stow-final` (D6 — history is kept, no rewrite).

### 12.6.1 Decommission the old repo tree (before the migration commit)

The single migration commit (§12.7) must expose **only** the chezmoi layout. Old structures stay
reachable forever via history / the `stow-final` tag — nothing is rewritten or force-pushed.
Run AFTER apps have run once and you're happy with the cutover (Phase 6 step 3).

```bash
# `.config/` removal is implicit: Phase 6 step 0 moved it to `.config.stow-backup`; deleting
# that dir now records the removal of all 89 tracked files under `.config/` on the next add.
rm -rf "$PWD/.config.stow-backup"        # ngrok authtoken & co lived here — never committed

# old stow packages + helpers (source side of the §11 map):
git rm -r -q macos packages scripts ai-tools bin
# ↑ removes 9+2+1+4+6 tracked files; `home/` already carries the replacements:
#   macos/* → tasks/macos/defaults.sh, packages/* → home/dot_Brewfile.tmpl + packages.yaml,
#   scripts/functions.sh → tasks/lib/functions.sh, ai-tools/.claude/* → home/dot_claude/*,
#   bin/* → home/bin/*
git rm -q .gitconfig .gitignore_global     # → home/dot_gitconfig.tmpl, home/dot_gitignore_global
git rm -q .stowrc .stow-local-ignore      # stow is gone; both are .gitignore'd, so `git add -A`
rm -rf .conductor .serena .DS_Store       # can never re-add them

# sanity — after this, remaining tracked paths are exactly the chezmoi layout (no output expected):
git ls-files | grep -vE '^(home/|tasks/|\.github/|mise\.toml$|install\.sh$|README\.md$|AGENTS\.md$|PRD-chezmoi-migration\.md$|\.chezmoiroot$|\.gitignore$)'
git status --porcelain                    # review: D old trees, A home/tasks/mise/…, no untracked stray
```

### 12.6.2 Retire Fisher on existing machines

Fresh machines never install Fisher. After cutover has been verified, remove only the old Fisher
artifacts from an existing machine; do not run this before the new Fish configuration is active:

```bash
rm -f ~/.config/fish/fish_plugins \
  ~/.config/fish/functions/fisher.fish \
  ~/.config/fish/completions/fisher.fish \
  ~/.config/fish/conf.d/autopair.fish \
  ~/.config/fish/functions/_autopair_{backspace,insert_left,insert_right,insert_same,tab}.fish \
  ~/.config/fish/themes/Catppuccin\ {Frappe,Macchiato,Mocha}.theme
rmdir ~/.config/fish/completions ~/.config/fish/themes 2>/dev/null || true
```

This deliberately leaves `fish_variables` untouched because it may contain credentials; it remains
ignored by chezmoi.

### 12.7 Phase 7 — the migration commit (D6)

```bash
# After §12.6.1 decommission, a bare `git add -A` is safe: it stages the new layout's additions
# (home/, tasks/, mise.toml, …) AND the old trees' deletions in ONE commit.
git add -A

# guards — the backup never hits git, and no secret is staged:
git ls-files | grep -q '\.config\.stow-backup' && echo "STOP: backup still tracked!" || true
git diff --cached --name-only | grep -iE 'authtoken|ngrok|auth\.db|\.key$|credentials' && echo "STOP: secret staged!" || true

git status --short                         # expect only A home/·tasks/·mise.toml·… and D macos/·packages/·…
git commit -m "feat: migrate from stow to chezmoi (home/ source root, packaged per machine class)"
git push                                    # normal push — history preserved
```

### 12.8 Phase 8 — bootstrap other machines

```bash
# Omarchy (role inferred from OS; forced here for clarity anyway):
DOTFILES_ROLE=omarchy sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tsyirvo
# unRAID VM / Hetzner VPS:
DOTFILES_ROLE=devbox sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tsyirvo
# then the 2-minute secrets step (§9.3): copy ssh keys + ngrok.yml out-of-band, `chezmoi apply` again
```

---

## 13. Testing & CI

### 13.1 Local e2e — `tasks/ci/test.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
# usage: ./tasks/ci/test.sh [role] [image]
role=${1:-devbox}; image=${2:-debian:bookworm}
docker run --rm -v "$PWD:/dotfiles:ro" "$image" bash -c "
  apt-get update -qq && apt-get install -y -qq git curl >/dev/null 2>&1
  useradd -m -s /bin/bash test
  echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
  su - test -c 'DOTFILES_ROLE=$role sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init --apply \
    --source=/dotfiles'
"
# assert: fish exists, `chezmoi doctor` exit 0, `mise install` reproduces tools, no unmanaged surprises
```

Run both branches: `./tasks/ci/test.sh devbox debian:bookworm` and
`./tasks/ci/test.sh omarchy archlinux:latest`.

### 13.2 CI — `.github/workflows/ci.yml`

```yaml
on: [push, pull_request]

# Security posture (kutsan pattern): least privilege, no creds, cancel stale runs
permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@<pinact-sha> # v4.x — pin with: mise run update:pinact
        with:
          persist-credentials: false
      - uses: jdx/mise-action@<pinact-sha> # v4.x — provisioning via mise.toml only
      - run: mise install
      - run: mise run check:shellcheck # renders *.tmpl scripts, shellchecks rendered + static
      - run: mise run check:gitleaks
      - run: mise run check:workflows # actionlint + zizmor safe-analysis of this workflow file
  apply-debian:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinact-sha> # v4.x
      - run: bash tasks/ci/test.sh devbox debian:bookworm # full script execution in a container
  apply-arch:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinact-sha> # v4.x
      - run: bash tasks/ci/test.sh omarchy archlinux:latest
  apply-darwin:
    runs-on: macos-26 # catches darwin-only template errors (joelazar pattern)
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@<pinact-sha> # v4.x
      - run: brew install chezmoi
      - run: |
          set -euo pipefail
          home="$RUNNER_TEMP/home"; mkdir -p "$home"
          cat > "$RUNNER_TEMP/chezmoi.toml" <<'EOF'
          [data]
              role = "macbook"
              osID = "darwin"
          EOF
          chezmoi --source "$GITHUB_WORKSPACE" --destination "$home" \
            --config "$RUNNER_TEMP/chezmoi.toml" --cache "$RUNNER_TEMP/cache" \
            --persistent-state "$RUNNER_TEMP/state/chezmoistate.boltdb" \
            --no-tty --force apply --exclude=scripts
          chezmoi --source "$GITHUB_WORKSPACE" --destination "$home" \
            --config "$RUNNER_TEMP/chezmoi.toml" --no-tty verify --exclude=scripts
      # scripts are skipped here (they install real packages); containers + real machines cover them
```

### 13.3 Security & reproducibility conventions

- All GitHub Actions pinned to full SHAs (via `mise run update:pinact` → `pinact run --update`),
  with `permissions: contents: read`, `persist-credentials: false`, `concurrency` cancel.
- Workflow files themselves are linted (**actionlint**) and security-checked (**zizmor --strict**),
  so a malicious/forgotten action can't sneak in silently.
- Every linter runs through mise (`mise install` + `mise.lock`), so CI == local toolchain exactly.
- The darwin job uses here-doc `[data]` instead of prompts — the same mechanism `install.sh` uses
  non-interactively (narze/joelazar lesson).

---

## 14. Day-to-day workflow (after migration)

```bash
chezmoi edit --apply ~/.config/fish/config.fish   # edit source, apply immediately
chezmoi re-add ~/.config/zed/settings.json        # you edited the target directly
chezmoi diff / status / apply -v                   # inspect / short / apply
chezmoi update                                     # git pull + apply
chezmoi cd                                         # shell in the source dir
chezmoi managed | less                             # what chezmoi owns
chezmoi unmanaged ~/.config                        # adoption candidates (goal #1)
chezmoi data / doctor                              # template vars / health
mise run apply | diff | update | check             # task-runner aliases (D14)
mise run fix-globals                               # §8.5: reproduce runtimes + globals
mise run macos                                     # macOS defaults, manually re-run
```

---

## 15. Risks & gotchas (ranked — specific to this repo)

1. **Omarchy owns its GUI (D2).** Never add `dot_config/hypr|waybar|…`. If you must diverge, use
   Omarchy's override mechanism, not chezmoi.
2. **`~/.config` is one symlink today.** After cutover apps write real files into `~/.config`;
   apps that rewrite config (Zed UI settings) drift → `chezmoi re-add` or accept. `exact_dot_config`
   would delete everything else — **never** use `exact_` on `.config`.
3. **mise global-config path breaks.** `mise ls` printed `~/dotfiles/.config/mise/config.toml`;
   after deletion, re-run `mise install` (Phase 6) so paths re-resolve.
4. **GitHub Copilot / manus auth lives in `~/.config` dirs we now ignore** — do NOT `chezmoi add`
   them thinking they're config; they contain tokens (auth.db). §7 keeps them blocked.
5. **Literal `{{` in configs.** `worktrunk/config.toml` is all comments with `{{ }}` — ship it
   **plain** (no `.tmpl`). Starship is safe (verified). When in doubt, don't templatize.
6. **`credential.helper osxkeychain`** in `.gitconfig` → gate on `isDarwin`.
7. **Fish plugins are retired.** Fish 4 provides autopair, and Catppuccin Mocha is declared in
   `conf.d`; do not add Fisher, plugin outputs, themes, or `fish_variables` to the source. Retire
   existing Fisher artifacts manually after cutover (§12.6.2).
8. **`clean-branches` has no exec bit** tracked today; `executable_` fixes it. Audit `~/bin` bits.
9. **Run-once scripts are content-keyed.** Keep `run_once_` scripts idempotent; editing one will
   re-run it on machines that already ran it.
10. **No secrets in the repo** means new machines need the §9.3 2-minute out-of-band step before
    ssh/ngrok work — that's the accepted trade for D1.
11. **`chezmoi update` ≠ plain pull.** It's `git pull` + apply; scripts run with a non-login,
    non-interactive shell — set explicit `PATH`/`HOME` at the top of every script.
12. **Debian renames** (`batcat`, `fdfind`) and stale versions (`fish` 3.x, old `fd`) → aliases in
    fish config + mise for modern CLIs (§8.3, §8.5).
13. **`.DS_Store` purge** is a normal commit here (no rewrite); keep `*.DS_Store` in the new
    `.gitignore`. History keeps the old file — harmless.
14. **`lastChangelogVersion`-style state keys** in tracked settings (claude, herdr, …) churn the
    repo on every app update → `chezmoi re-add` them, or drop the key from the managed file.
15. **AI agents editing this repo** must read `AGENTS.md` first (§19.5): edits in the source dir
    have no effect until `chezmoi apply`, and the ignored classes (§7) are off-limits for `chezmoi add`.
16. **The `.config` working-tree trap at cutover**: today `~/.config` IS the repo dir, so
    app-written state (ngrok token, copilot auth) is untracked but physically in the worktree.
    `git tag stow-final` does NOT preserve untracked files — Phase 6 backs up `.config` first.
17. **`chezmoi add` cannot see through symlinked dirs** (verified): `--follow` + recursion
    (default on) are mutually exclusive for directories, and plain adds record
    `symlink_dot_config` and fail. That's why Phase 2 copies bytes with `cp -aL` instead of
    `chezmoi add`; everyday `chezmoi add` returns once `~/.config` is a real dir (§12.3).

---

## 16. Non-goals / out of scope

- Migrating app **data** (fish history, atuin history DBs, Raycast state, Claude backups) — lives
  in `~/.local/share`, `~/Library`, and the untracked parts of `~/.config`. Not managed.
- Managing the Omarchy desktop environment itself (D2).
- Windows support (`.chezmoi.os` would carry it, but nothing ships for it today).
- Versioning any credential — SSH keys, ngrok token, future tokens (D1). Out-of-band only.
- Per-machine git identity/signing for now (review decision — shared config, revisit if needed).
- `~/.pi` agent config — out of scope; lives in its own git repo (D17, §2.6); possible future
  migration into these dotfiles.

---

## 17. Success criteria (acceptance)

- [ ] `git status` clean after a normal day of use; no app writes into the repo.
- [ ] `install.sh` boots a fresh `debian:bookworm` container to a working fish + tooling in CI.
- [ ] Same for `archlinux:latest` (omarchy path) with GUI config absent.
- [ ] Mac cutover complete; history preserved; `stow-final` tag exists; one migration commit.
- [ ] Old stow tree (`macos/`, `packages/`, `scripts/`, `ai-tools/`, `bin/`, root `.gitconfig`/
      `.gitignore_global`) absent from HEAD (§12.6.1) — repo exposes only the chezmoi layout;
      the old layout is reachable solely through history.
- [ ] Omarchy + at least one dev box bootstrapped; fish shell works; `mise install` reproduces
      runtimes + globals; SSH/ngrok secrets in place via out-of-band step.
- [ ] No secret ever in the repo (gitleaks clean on push and pre-commit).
- [ ] macOS defaults consolidated to one file; typo domain + dead keys gone.
- [ ] README rewritten per §19: install paths verified by the CI docker matrix; no duplicated package or file inventories; routing table in sync with `.chezmoiignore`.
- [ ] `mise install` on a fresh checkout reproduces the repo toolchain (mise.lock committed); `mise run check:*` passes in CI and locally.
- [ ] Cutover preserved all untracked state — ngrok token, github-copilot auth, raycast — verified after Phase 6 (backup + restore step).
- [ ] `chezmoi update` on all three machine classes applies cleanly.

---

## 18. Review feedback → resolutions & follow-ups

**Resolved in v2:**

| #   | Feedback                          | Resolution                                                                                     |
| --- | --------------------------------- | ---------------------------------------------------------------------------------------------- |
| 1   | AUR helper question               | **Omarchy's built-in package manager** (D12, §8.3 placeholder)                                 |
| 2   | Linux package lists (arch/debian) | First drafts shipped; **iterated after a fresh devbox install** — tracked as follow-up         |
| 3   | `devin/`, `amp/`, `codexbar/`     | **Never tracked** (D10, ignored)                                                               |
| 4   | `.serena/`, `.conductor/`         | **Never tracked** (D10, ignored)                                                               |
| 5   | Per-machine git signing           | **Shared config for now** — no signing key per machine (§9.2, §16)                             |
| 6   | sesh/worktrunk/tv on servers      | **Shipped unchanged on all machines** (D13, §11 — plain files, headless only excludes GUI)     |
| 7   | Makefile → mise                   | **mise tasks** (D14, §8.6)                                                                     |
| R1  | Keep git history                  | **One big migration commit**, no force-push (D6, §12.7)                                        |
| R2  | Claude file set                   | **Exactly 4 files** confirmed (D7, §2.2/§7.3)                                                  |
| R3  | SSH keys in git?                  | **Out-of-band, never in git** — age pipeline dropped (D1, §9)                                  |
| R4  | packages.yaml comments            | **Commented taxonomy + add/remove workflow** (§8.0, §8.1)                                      |
| R5  | mise + global npm                 | **Dedicated strategy**: single manifest, `npm:` tools, pinning, `mise install` fix path (§8.5) |
| R6  | macOS defaults cleanup            | **Consolidation + dead-key pruning** with evidence (§10.3)                                     |

**Adopted from reference repos (studied 2026-08-27 — [kutsan](https://github.com/kutsan/dotfiles),
[joelazar](https://github.com/joelazar/dotfiles), [narze](https://github.com/narze/dotfiles)):**

| #   | Lesson                                                                                                                               | Where it landed                                                 |
| --- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| A1  | Mise as the whole dev toolchain: pinned `[tools]` + `mise.lock` + `check:*` tasks                                                    | §8.6, §13.3                                                     |
| A2  | `run_onchange` keyed on runtime output (`node -p process.versions.modules`) → native addons rebuild automatically on Node ABI change | §8.5.6, `45-rebuild-native-modules`                             |
| A3  | `stdinIsATTY`-gated prompting; env-var overrides for non-interactive installs (`DOTFILES_ROLE`, narze `ASK=` style)                   | §5, §13.1                                                       |
| A4  | Security-hardened CI: pinned SHAs, `permissions: read`, no creds, actionlint + zizmor                                                | §13.2/(13.3)                                                    |
| A5  | Shellcheck harness that renders `.tmpl` scripts before linting (kutsan)                                                              | `tasks/ci/shellcheck-rendered.sh`                               |
| A6  | Apply-on-real-macOS CI with here-doc `[data]` + `--exclude=scripts` (joelazar)                                                       | §13.2 `apply-darwin`                                            |
| A7  | Nested per-tool `.chezmoiignore` files (kutsan)                                                                                      | §7 notes                                                        |
| A8  | `AGENTS.md` so AI agents maintain the repo correctly (joelazar)                                                                      | §19.5                                                           |
| A9  | joelazar's selective `~/.pi` management                                                                                              | **Not adopted** — `~/.pi` stays in its own git repo (D17, §2.6) |

**Open follow-ups (post-migration):**

1. Validate `packages.yaml` Arch/Debian lists against real repos during Phase 8 (expect churn —
   that's what `run_onchange_` is for).
2. Audit `~/.local/bin` + per-Node `npm ls -g` → fold npm-based tools into `mise/config.toml`.
3. Verify each surviving macOS `defaults` key on current macOS during consolidation (§10.3 process).
4. Revisit per-machine git identity/signing when a machine actually needs it.
5. Revisit `~/.pi` management if/when it outgrows its own repo (D17).

---

## 19. README rewrite (D16)

### 19.1 Goals

1. Onboard a machine of any class in ≤3 commands.
2. Teach day-to-day file management (edit / apply / re-add / update).
3. Teach package add/remove using the same two-manifest taxonomy as §8.0.
4. **Never drift from the repo**: no duplicated inventories; commands shown must be the ones
   CI actually tests.

### 19.2 Anti-drift rules (the drift guards)

1. The README **never lists the full package set** — it points at `packages.yaml`;
   the list lives there (with comments) so there is only one source of truth.
2. The README **never lists managed files** — `chezmoi managed` is the truth. Only a coarse
   top-level picture of `home/` may appear.
3. The **machine-classes table must mirror `home/.chezmoiignore`** routing; any routing change
   updates the table in the same commit.
4. The **install command in the README is byte-for-byte what `tasks/ci/test.sh` runs** — CI is
   the drift test; if the commands rot, CI fails before a user does.
5. Cheat-sheet commands come from `mise.toml` task names / chezmoi builtins only — no invented aliases.
6. Package add/remove instructions derive from the §8.0 taxonomy, not re-typed prose.

### 19.3 Draft README (ship as `README.md` in the migration commit)

````markdown
# tsyirvo/dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io). One repository, three machine classes.

## Machine classes

| Class           | OS                                 | role      | Packages from                               |
| --------------- | ---------------------------------- | --------- | ------------------------------------------- |
| MacBook Pro     | macOS (Apple Silicon)              | `macbook` | Homebrew (+ casks, + Mac App Store)         |
| Omarchy desktop | Arch Linux + Hyprland              | `omarchy` | pacman + Omarchy's built-in package manager |
| Dev box         | Debian/Ubuntu, headless (VM / VPS) | `devbox`  | apt + mise for modern CLIs                  |

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

The bootstrap then runs automatically, in order:

1. **Package manager** — Homebrew on macOS, pacman/Omarchy PM on Arch, apt on Debian.
2. **Packages** — `brew bundle` / pacman / apt per the class + **all runtimes and global npm
   tools** via `mise install`.
3. **Shell** — fish becomes your login shell (added to `/etc/shells`, `chsh`).
4. **Pre-commit hook** — gitleaks guards the repo against secret leaks.

Last, the **secrets step** (2 minutes, once per machine): SSH keys + the ngrok token are
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

| What                                                           | Where                              | Installed by                                  |
| -------------------------------------------------------------- | ---------------------------------- | --------------------------------------------- |
| OS packages (brew / pacman / apt / casks / mas)                | `home/.chezmoidata/packages.yaml`  | `10-install-packages` script (auto, on apply) |
| Runtimes + global npm tools (`node`, `python`, `bun`, `npm:…`) | `home/dot_config/mise/config.toml` | `mise install` (auto, on apply)               |

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

Out-of-band by design: SSH keys, the ngrok token, and any future tokens are copied per machine
and **never committed**. See `tasks/secrets/README.md`. gitleaks enforces this on every commit
and in CI.

## Keeping this README honest

- No package lists here — they live in `packages.yaml` / `mise/config.toml`.
- No file inventories here — `chezmoi managed` is the truth.
- The install command above is exactly what CI runs (`tasks/ci/test.sh`); if it stops working,
  CI fails before a user does.
- Change routing? Update the machine-classes table in the same commit.
````

### 19.4 Maintenance reminder

- Update the README in the **same commit** as any routing, taxonomy, or task-name change (drift rule 3).
- `mise run check` (unmanaged scan) and CI are the automated half of the drift guards; the rules in
  §19.2 are the manual half. Review §19.2 whenever someone proposes a new README section.

### 19.5 Agent-in-repo conventions — `AGENTS.md` (joelazar lesson, A8)

This repo is edited by AI agents (pi, claude) as much as by hand. Commit an `AGENTS.md` at the
repo root recording the rules an agent must not skip:

- Source of truth is `home/` (from `.chezmoiroot`); **edits in the source dir have no effect until
  `chezmoi apply`** — always run `chezmoi apply <target>` after editing (never `--all` on a live
  machine unless intended).
- Prefixes: `dot_` → hidden, `private_` → 0600, `executable_` → +x, `.tmpl` → rendered template.
- `tasks/` is repo-internal, never deployed; scripts inside `.chezmoiscripts/` must be bash,
  `set -euo pipefail`, sourced from `tasks/lib/functions.sh`, and shellcheck-clean.
- Never `chezmoi add` anything from the ignored classes (§7) — auth DBs, caches, logs, state,
  `devin/amp/codexbar/.serena/.conductor`, and anything secret — secrets are out-of-band (§9).
- Ask (`chezmoi diff` first) before touching routing (`.chezmoiignore`) or the packages taxonomy (§8.0).
- Update `AGENTS.md` itself in the same commit as any convention change.

`AGENTS.md` sits outside `home/`, so it is never applied to `$HOME` — it exists only for humans
and agents working in the repo.
