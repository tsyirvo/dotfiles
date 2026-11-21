-- CPU usage graph fed by stats_provider (brew install joncrangle/tap/sketchybar-system-stats).
-- stats_provider is a tiny Rust daemon that fires the `system_stats` event every
-- N seconds, so nothing is spawned per sample.
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.cpu

sbar.add("event", "system_stats")
util.exec("killall stats_provider >/dev/null 2>&1; stats_provider --cpu usage --memory ram_usage --no-units --interval "
  .. cfg.interval)

local cpu = sbar.add("graph", "widgets.cpu", cfg.graph_width, {
  position = "right",
  graph = { color = colors.blue, fill_color = colors.alpha(colors.blue, 0x40), line_width = 1.0 },
  background = { height = 22, color = colors.transparent, drawing = true },
  icon = { string = icons.cpu, color = colors.subtext0, padding_left = 10 },
  label = {
    string = "··%",
    font = { family = settings.font.numbers, style = "Bold", size = 9.0 },
    align = "right",
    width = 0,         -- overlay the % on top of the graph instead of beside it
    padding_right = 0,
    y_offset = 5,
  },
  padding_right = 8,
  updates = true,      -- keep pushing samples so the history is continuous
})

local ram = sbar.add("item", "widgets.cpu.ram", {
  position = "popup." .. cpu.name,
  icon = { string = icons.memory .. "  Memory", width = 110, align = "left", color = colors.subtext0 },
  label = { string = "…", width = 60, align = "right" },
})

cpu:subscribe("system_stats", function(env)
  local load = tonumber(env.CPU_USAGE)
  if not load then return end
  local color = util.load_color(load)
  cpu:push({ math.min(load, 100) / 100.0 })
  cpu:set({
    graph = { color = color, fill_color = colors.alpha(color, 0x40) },
    label = { string = string.format("%d%%", math.floor(load + 0.5)) },
  })
  if env.RAM_USAGE then ram:set({ label = { string = env.RAM_USAGE .. "%" } }) end
end)

cpu:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    cpu:set({ popup = { drawing = "toggle" } })
  else
    sbar.exec("open -a " .. util.quote(cfg.click_app))
  end
end)

cpu:subscribe("mouse.exited.global", function()
  cpu:set({ popup = { drawing = false } })
end)

return cpu
