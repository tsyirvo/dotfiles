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
  display = "all",
  -- notch_width = 200, -- default; items never draw under the notch on notched displays
})
