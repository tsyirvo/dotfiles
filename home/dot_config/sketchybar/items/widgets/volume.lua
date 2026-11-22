-- Output volume of the default device.
--   left click   mute / unmute
--   scroll       volume up/down
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.volume

local volume = sbar.add("item", "widgets.volume", {
  position = "right",
  icon = { font = { family = settings.font.text, style = "Regular", size = 16.0 } },
  label = { font = { family = settings.font.numbers, style = "Bold", size = 12.0 } },
})

local function level_icon(level)
  if level == 0 then return icons.volume.off end
  if level < 34 then return icons.volume.low end
  if level < 67 then return icons.volume.medium end
  return icons.volume.high
end

local function render(level)
  volume:set({
    icon = { string = level_icon(level), color = level == 0 and colors.state.muted or colors.text },
    label = { string = level .. "%" },
  })
end

-- The volume_change event reports 0 while muted.
local READ = [[osascript -e 'set s to get volume settings' ]]
  .. [[-e 'if output muted of s then return 0' -e 'return output volume of s']]

local function refresh()
  util.exec(READ, function(out)
    local level = tonumber(tostring(out):match("(%d+)"))
    if level then render(level) end
  end)
end

volume:subscribe("volume_change", function(env)
  local level = tonumber(env.INFO)
  if level then render(level) end
end)
volume:subscribe({ "forced", "system_woke" }, refresh)

volume:subscribe("mouse.clicked", function()
  util.exec([[osascript -e 'set volume output muted not (output muted of (get volume settings))']], refresh)
end)

volume:subscribe("mouse.scrolled", function(env)
  local delta = tonumber(env.SCROLL_DELTA) or 0
  if delta == 0 then return end
  local step = delta > 0 and cfg.scroll_step or -cfg.scroll_step
  util.exec("osascript -e " .. util.quote(
    "set volume output volume ((output volume of (get volume settings)) + " .. step .. ")"))
end)

refresh()

return volume
