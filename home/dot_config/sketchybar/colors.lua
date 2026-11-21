-- Catppuccin Mocha (https://catppuccin.com/palette) in SketchyBar's 0xAARRGGBB format,
-- plus semantic roles so the rest of the config never hard-codes a hex value.
-- To try another flavour, swap the hex values in `p` (Macchiato, Frappé, Latte).

local p = {
  rosewater = 0xf5e0dc, flamingo = 0xf2cdcd, pink = 0xf5c2e7, mauve = 0xcba6f7,
  red = 0xf38ba8, maroon = 0xeba0ac, peach = 0xfab387, yellow = 0xf9e2af,
  green = 0xa6e3a1, teal = 0x94e2d5, sky = 0x89dceb, sapphire = 0x74c7ec,
  blue = 0x89b4fa, lavender = 0xb4befe,
  text = 0xcdd6f4, subtext1 = 0xbac2de, subtext0 = 0xa6adc8,
  overlay2 = 0x9399b2, overlay1 = 0x7f849c, overlay0 = 0x6c7086,
  surface2 = 0x585b70, surface1 = 0x45475a, surface0 = 0x313244,
  base = 0x1e1e2e, mantle = 0x181825, crust = 0x11111b,
}

-- Returns `rgb` (0xRRGGBB, or an existing 0xAARRGGBB) with the given alpha (0-255).
local function alpha(rgb, a)
  return ((a or 0xff) << 24) | (rgb & 0x00ffffff)
end

local c = { alpha = alpha }
for name, rgb in pairs(p) do c[name] = alpha(rgb, 0xff) end

c.transparent = 0x00000000

-- Semantic roles ------------------------------------------------------------
c.accent = c.mauve        -- focused workspace, highlights (Catppuccin's default accent)
c.accent_alt = c.lavender -- clock icon, secondary highlights

c.bar = {
  bg = alpha(p.base, 0x00),      -- transparent strip: only the "islands" are drawn
  -- bg = alpha(p.base, 0xe6),   -- uncomment for a classic solid bar
}

c.island = {
  bg = alpha(p.mantle, 0xf0),
  border = c.surface0,
}

c.workspace = {
  bg = c.surface0,
  border = c.surface1,
  fg = c.subtext0,
  apps = c.overlay2,
  focused_bg = c.accent,
  focused_fg = c.crust,
  visible_border = c.accent, -- shown on another monitor, not focused
}

c.popup = {
  bg = alpha(p.base, 0xf5),
  border = c.surface1,
}

c.state = {
  ok = c.green,
  warn = c.yellow,
  high = c.peach,
  critical = c.red,
  muted = c.overlay0,
  info = c.blue,
}

return c
