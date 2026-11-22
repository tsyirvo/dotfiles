local colors = require("colors")
local settings = require("settings")

-- Equivalent to `sketchybar --bar ...`
sbar.bar({
  position = "top",
  height = settings.bar_height,
  color = colors.bar.bg,
  border_width = 0,
  padding_left = 8,
  padding_right = 8,
  margin = 0,
  y_offset = 0,
  shadow = false,
  sticky = true,   -- bar stays still during space-switch animations
  -- Clicks on the bar do not work on macOS 27 with SketchyBar 2.24.1 (issue #852).
  -- MenuBarAgent keeps a transparent window at level 25 over the top 39 px while
  -- the menu bar auto-hides. That window takes every click and reveals the native
  -- bar. The bar sits below it at level -20, so click_script never runs.
  -- No config fixes it. topmost=on (level 25) gets clicks only until the first
  -- reveal: MenuBarAgent then makes a new window above the bar. And while the
  -- native bar shows, the bar covers it. topmost="window" (level 3) stays below.
  -- The fix is upstream PR #892: level 26 while the menu bar hides, -20 while it
  -- shows (window server events 1301/1302). Keep topmost off and upgrade to the
  -- first release with that PR. The top-edge reveal keeps working above level 25.
  display = "all",
  -- notch_width = 200, -- default; items never draw under the notch on notched displays
})
