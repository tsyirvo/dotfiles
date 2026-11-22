-- Everything you are likely to tweak lives here.

return {
  -- Fonts --------------------------------------------------------------------
  font = {
    text = "JetBrainsMono Nerd Font",   -- already installed by your Brewfile
    numbers = "JetBrainsMono Nerd Font",  -- monospaced: the seconds don't make the clock jitter
    app = "sketchybar-app-font",          -- brew install --cask font-sketchybar-app-font
  },

  -- Bar geometry ---------------------------------------------------------------
  bar_height = 36,     -- ~ the notch height on a 14/16" MacBook Pro; 32 looks tighter on externals
  item_height = 26,    -- height of the "islands"
  corner_radius = 8,
  group_gap = 6,       -- space between islands

  -- PATH for commands run from Lua (launchd agents get a minimal PATH).
  env_prefix = "export PATH=/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH; ",

  -- AeroSpace ----------------------------------------------------------------
  aerospace = {
    -- Used only if `aerospace list-workspaces --all` fails at startup.
    fallback_workspaces = { "1", "2", "3", "A", "S", "X" },
    hide_empty = false,      -- true = only show workspaces that have windows (+ the focused one)
    dedupe_apps = true,      -- 3 Ghostty windows = 1 Ghostty icon
    per_display = true,      -- pin each workspace to the monitor AeroSpace put it on
  },

  -- Spotify ----------------------------------------------------------------------
  spotify = {
    enabled = true,
    max_chars = 28,           -- longer "Title · Artist" scrolls
    animate = true,           -- equaliser animation while playing
    animation_seconds = 0.35, -- frame interval; raise it to cut redraws
  },
  show_front_app = false,     -- the focused workspace pill already shows the apps

  -- Clock ----------------------------------------------------------------------
  -- Lua os.date format. Day-of-week + 24h with seconds, like your current defaults.sh.
  clock_format = "%a %d %b  %H:%M:%S",
  -- Fixed label width: the seconds otherwise move the bar by 1 px. Change it with clock_format.
  clock_label_width = 169,
  -- locale = "fr_FR.UTF-8",  -- uncomment for "sam. 21 nov."
  calendar_app = "Notion Calendar",

  -- Battery ----------------------------------------------------------------------
  battery_click_app = "AlDente", -- set to nil to only toggle the details popup

  -- Volume -----------------------------------------------------------------------
  volume = {
    scroll_step = 5,       -- % per scroll tick
  },

  -- CPU and RAM --------------------------------------------------------------------
  usage = {
    interval = 2,          -- seconds between stats_provider samples
    label_width = 31,      -- fits "99%", so 1 and 2 digits take the same room
    click_app = "Activity Monitor",
  },

  -- Tailscale ---------------------------------------------------------------------
  tailscale = {
    -- The standalone app bundles its CLI. TAILSCALE_BE_CLI=1 forces CLI mode when
    -- the caller has no terminal env (SketchyBar runs from launchd).
    cli = "TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale",
    poll_seconds = 15,
    max_peers = 14,        -- rows in the popup
    show_peer_count = false,
  },

  -- AI session limits --------------------------------------------------------------
  -- Remaining 5-hour limit of Claude and OpenAI, read with the Claude Code and Codex logins.
  ai_limits = {
    enabled = true,
    poll_seconds = 300, -- the Claude usage endpoint rejects frequent polls
  },

  -- Menu bar apps mirrored with SketchyBar aliases ----------------------------------
  -- On macOS 26+ every third-party item is reported as owned by "Control Center",
  -- so you need the indexed name. Run `scripts/find-menu-items.sh`, then paste the
  -- entries here, e.g. alias = "Control Center,Item-0(9)".
  -- On macOS 15 and earlier the plain form works: alias = "LookAway,Item-0".
  -- `process` is the app's process name, used to open its real menu on click.
  -- `tint` recolours a monochrome template icon in Catppuccin text colour.
  menu_extras = {
    { key = "tinybar", alias = nil, process = "Tinybar", tint = false },
    { key = "lookaway", alias = nil, process = "LookAway", tint = true },
    -- Prefer the native Tailscale widget (items/tailscale.lua). If you'd rather
    -- mirror the real icon, add it here and set enable_native_tailscale = false.
    -- { key = "tailscale", alias = nil, process = "Tailscale", tint = true },
  },
  enable_native_tailscale = true,
}
