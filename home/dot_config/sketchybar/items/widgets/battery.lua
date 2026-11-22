-- Battery: event-driven on plug/unplug, polled every 2 min for the percentage.
-- Understands AlDente's "AC attached; not charging" hold state.
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  update_freq = 120,
  icon = { font = { family = settings.font.text, style = "Regular", size = 16.0 } },
  label = { font = { family = settings.font.numbers, style = "Bold", size = 12.0 }, padding_right = 10 },
  popup = { align = "right" },
})

local details = sbar.add("item", "widgets.battery.details", {
  position = "popup." .. battery.name,
  icon = { string = "State", width = 90, align = "left", color = colors.subtext0 },
  label = { string = "…", width = 170, align = "right" },
})
local remaining = sbar.add("item", "widgets.battery.remaining", {
  position = "popup." .. battery.name,
  icon = { string = "Remaining", width = 90, align = "left", color = colors.subtext0 },
  label = { string = "…", width = 170, align = "right" },
})

local function level_icon(charge)
  local b = icons.battery
  if charge >= 95 then return b._100 end
  local step = math.max(0, math.floor(charge / 10) * 10)
  return b["_" .. step] or b._0
end

local function update()
  sbar.exec("pmset -g batt", function(out)
    out = tostring(out)
    local charge = tonumber(out:match("(%d+)%%"))
    if not charge then
      battery:set({ drawing = false }) -- desktop Mac: no battery
      return
    end

    local on_ac = out:find("AC Power", 1, true) ~= nil
    local state = out:match("%d+%%;%s*([^;]+);") or (on_ac and "AC" or "battery")
    local charging = on_ac and state:find("^charging") ~= nil

    local icon, color
    if charging then
      icon, color = icons.battery.charging, colors.state.ok
    elseif on_ac then
      -- On AC but not charging: AlDente holds the charge (limit or sailing range).
      icon, color = icons.battery.plugged, colors.blue
    else
      icon = level_icon(charge)
      color = charge <= 10 and colors.state.critical or colors.peach
    end

    battery:set({
      drawing = true,
      icon = { string = icon, color = color },
      label = { string = charge .. "%" },
    })
    -- e.g. "AC attached; not charging" (AlDente hold) or "discharging; 3:12 remaining"
    local summary = out:match("%d+%%;%s*(.-)%s*present") or state
    details:set({ label = { string = summary } })
    local eta = out:match("(%d+:%d+) remaining")
    remaining:set({ label = { string = (eta and eta ~= "0:00") and (eta .. " h") or "—" } })
  end)
end

battery:subscribe({ "routine", "forced", "power_source_change", "system_woke" }, update)

battery:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" and settings.battery_click_app then
    sbar.exec("open -a " .. util.quote(settings.battery_click_app))
    return
  end
  battery:set({ popup = { drawing = "toggle" } })
  update()
end)

battery:subscribe("mouse.exited.global", function()
  battery:set({ popup = { drawing = false } })
end)

return battery
