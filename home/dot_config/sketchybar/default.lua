local colors = require("colors")
local settings = require("settings")

-- Equivalent to `sketchybar --default ...`: inherited by every item added afterwards.
sbar.default({
  updates = "when_shown",
  icon = {
    font = { family = settings.font.text, style = "Bold", size = 14.0 },
    color = colors.text,
    padding_left = 6,
    padding_right = 3,
  },
  label = {
    font = { family = settings.font.text, style = "SemiBold", size = 13.0 },
    color = colors.text,
    padding_left = 3,
    padding_right = 6,
  },
  background = {
    height = settings.item_height,
    corner_radius = settings.corner_radius,
    border_width = 0,
  },
  popup = {
    background = {
      color = colors.popup.bg,
      border_color = colors.popup.border,
      border_width = 2,
      corner_radius = 10,
      shadow = { drawing = true },
    },
    blur_radius = 30,
  },
  padding_left = 2,
  padding_right = 2,
  scroll_texts = true,
})
