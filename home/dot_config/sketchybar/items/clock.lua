-- Date + time with seconds. Pure Lua (os.date): no process is spawned each second.
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

if settings.locale then os.setlocale(settings.locale, "time") end

local clock = sbar.add("item", "widgets.clock", {
  position = "right",
  update_freq = 1,
  icon = { string = icons.calendar, color = colors.accent_alt, padding_left = 10 },
  label = {
    font = { family = settings.font.numbers, style = "Bold", size = 13.0 },
    padding_right = 10,
  },
  background = {
    color = colors.island.bg,
    border_color = colors.island.border,
    border_width = 1,
  },
  click_script = settings.calendar_app and ("open -a " .. util.quote(settings.calendar_app)) or nil,
})

clock:subscribe({ "forced", "routine", "system_woke" }, function()
  clock:set({ label = { string = os.date(settings.clock_format) } })
end)

util.gap("right")
