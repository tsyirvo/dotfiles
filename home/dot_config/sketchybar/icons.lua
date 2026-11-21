-- Nerd Font glyphs (Material Design set, codepoints checked against Nerd Fonts' glyphnames.json).
-- Written as escapes so the file survives any editor/encoding round-trip.

return {
  calendar = "\u{F00ED}",     -- nf-md-calendar
  cpu = "\u{F061A}",          -- nf-md-chip
  memory = "\u{F035B}",       -- nf-md-memory
  mic = "\u{F036C}",          -- nf-md-microphone
  mic_off = "\u{F036D}",      -- nf-md-microphone_off
  mic_unknown = "\u{F036E}",  -- nf-md-microphone_outline
  vpn = "\u{F0582}",          -- nf-md-vpn
  vpn_off = "\u{F099C}",      -- nf-md-shield_off_outline
  exit_node = "\u{F01E7}",    -- nf-md-earth
  dot = "\u{F0765}",          -- nf-md-circle
  dot_off = "\u{F0766}",      -- nf-md-circle_outline
  copy = "\u{F018F}",         -- nf-md-content_copy
  mode = "\u{F1064}",         -- nf-md-tools
  spotify = "\u{F04C7}",      -- nf-md-spotify
  album = "\u{F0025}",        -- nf-md-album
  prev = "\u{F04AE}",         -- nf-md-skip_previous
  next = "\u{F04AD}",         -- nf-md-skip_next
  play_pause = "\u{F040E}",   -- nf-md-play_pause
  -- Equaliser frames (Unicode block elements, present in JetBrains Mono)
  eq_frames = { "▂▅▃▇", "▅▃▇▂", "▃▇▂▅", "▇▂▅▃", "▄▆▂▅", "▆▂▅▄" },
  battery = {
    charging = "\u{F0084}",   -- nf-md-battery_charging
    plugged = "\u{F06A5}",    -- nf-md-power_plug (AC, not charging: e.g. AlDente holding)
    _100 = "\u{F0079}", _90 = "\u{F0082}", _80 = "\u{F0081}", _70 = "\u{F0080}",
    _60 = "\u{F007F}", _50 = "\u{F007E}", _40 = "\u{F007D}", _30 = "\u{F007C}",
    _20 = "\u{F007B}", _10 = "\u{F007A}", _0 = "\u{F0083}", -- battery_alert
  },
}
