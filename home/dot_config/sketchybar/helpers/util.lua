local settings = require("settings")
local colors = require("colors")

local M = {}

-- App name -> sketchybar-app-font ligature (helpers/icon_map.lua comes from the
-- font's GitHub release; see README). Falls back to the generic icon.
local ok, icon_map = pcall(require, "helpers.icon_map")
if not ok or type(icon_map) ~= "table" then icon_map = {} end

function M.app_icon(app_name)
  return icon_map[app_name] or icon_map["Default"] or ":default:"
end

-- Single-quote a value for /bin/sh.
function M.quote(value)
  return "'" .. (tostring(value):gsub("'", "'\\''")) .. "'"
end

-- Non-blocking shell command with a usable PATH. `callback(result, exit_code)`;
-- SbarLua hands JSON output over already parsed into a Lua table.
function M.exec(cmd, callback)
  if callback then
    sbar.exec(settings.env_prefix .. cmd, callback)
  else
    sbar.exec(settings.env_prefix .. cmd)
  end
end

-- Coalesce bursts of events (AeroSpace fires several per keypress) into one call.
function M.debounce(seconds, fn)
  local pending = false
  return function()
    if pending then return end
    pending = true
    sbar.delay(seconds, function()
      pending = false
      fn()
    end)
  end
end

function M.truthy(v)
  return v == true or v == "true"
end

-- Thin spacer between islands on the given side.
function M.gap(position, width)
  return sbar.add("item", {
    position = position,
    width = width or settings.group_gap,
    icon = { drawing = false },
    label = { drawing = false },
    background = { drawing = false },
    padding_left = 0,
    padding_right = 0,
  })
end

-- Rounded "island" background around a group of items.
function M.island(name, members)
  return sbar.add("bracket", name, members, {
    background = {
      color = colors.island.bg,
      border_color = colors.island.border,
      border_width = 1,
      height = settings.item_height,
      corner_radius = settings.corner_radius,
    },
  })
end

-- Usage colour ramp shared by CPU, battery, etc. (`value` 0-100, higher = worse).
function M.load_color(value)
  if value >= 80 then return colors.state.critical end
  if value >= 60 then return colors.state.high end
  if value >= 30 then return colors.state.warn end
  return colors.blue
end

return M
