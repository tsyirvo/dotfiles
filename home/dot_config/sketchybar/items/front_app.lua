-- Focused app (useful once the native menu bar, and with it the app name, is hidden).
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

util.gap("left")

local front_app = sbar.add("item", "front_app", {
  position = "left",
  icon = {
    font = { family = settings.font.app, style = "Regular", size = 15.0 },
    color = colors.accent,
    padding_left = 8,
  },
  label = {
    font = { family = settings.font.text, style = "Bold", size = 13.0 },
    color = colors.text,
    padding_right = 8,
  },
  background = { color = colors.island.bg, border_color = colors.island.border, border_width = 1 },
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({ icon = { string = util.app_icon(env.INFO) }, label = { string = env.INFO } })
end)
