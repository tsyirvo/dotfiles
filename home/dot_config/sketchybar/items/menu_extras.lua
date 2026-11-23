-- Menu bar apps island: [claude] [openai] [tailscale]   (added right-to-left)
--
-- Tailscale is drawn natively from its CLI (status colour, peer count, peer popup).
-- Apps listed in settings.menu_extras are mirrored with SketchyBar *aliases*
-- (needs Screen Recording permission).
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

local members = {}

if settings.enable_native_tailscale then
  local tailscale = require("items.widgets.tailscale")
  table.insert(members, tailscale.name)
end

if settings.ai_limits.enabled then
  for _, name in ipairs(require("items.widgets.ai_limits")) do table.insert(members, name) end
end

-- Clicking an alias does nothing by itself: forward the click to the real menu
-- bar item through System Events (SketchyBar will ask for Accessibility once).
local function open_real_menu(process)
  return "osascript -e " .. util.quote(
    'tell application "System Events" to click menu bar item 1 of menu bar 2 of application process "'
      .. process .. '"')
end

for i = #settings.menu_extras, 1, -1 do -- reverse: config order = left-to-right on screen
  local extra = settings.menu_extras[i]
  if extra.alias then
    local alias = sbar.add("alias", extra.alias, {
      position = "right",
      alias = {
        color = extra.tint and colors.text or nil,
        scale = extra.scale or 1.0,
        update_freq = extra.update_freq or 1,
      },
      icon = { drawing = false },
      label = { drawing = false },
      padding_left = 0,
      padding_right = 0,
      click_script = extra.process and open_real_menu(extra.process) or nil,
    })
    table.insert(members, alias.name)
  else
    print(("[sketchybar] menu_extras.%s has no alias yet: run scripts/find-menu-items.sh"):format(extra.key))
  end
end

if #members > 0 then
  util.island("extras.island", members)
  util.gap("right")
end
