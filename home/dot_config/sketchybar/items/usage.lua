-- Usage island: [cpu] [ram]   (added right-to-left)
-- stats_provider (brew install joncrangle/tap/sketchybar-system-stats) is a small
-- Rust daemon that fires the `system_stats` event, so nothing is spawned per sample.
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.usage

sbar.add("event", "system_stats")
util.exec("killall stats_provider >/dev/null 2>&1; stats_provider --cpu usage --memory ram_usage --no-units --interval "
  .. cfg.interval)

local function usage_item(name, icon)
  return sbar.add("item", name, {
    position = "right",
    icon = { string = icon, color = colors.subtext0, font = { family = settings.font.text, style = "Regular", size = 16.0 } },
    label = {
      string = "··%",
      font = { family = settings.font.numbers, style = "Bold", size = 12.0 },
      width = cfg.label_width,
      align = "right",
    },
  })
end

local ram = usage_item("widgets.ram", icons.memory)
local cpu = usage_item("widgets.cpu", icons.cpu)

local function render(item, value)
  value = tonumber(value)
  if not value then return end
  item:set({ label = { string = string.format("%d%%", math.floor(value + 0.5)), color = util.load_color(value) } })
end

cpu:subscribe("system_stats", function(env)
  render(cpu, env.CPU_USAGE)
  render(ram, env.RAM_USAGE)
end)

for _, item in ipairs({ cpu, ram }) do
  item:subscribe("mouse.clicked", function()
    sbar.exec("open -a " .. util.quote(cfg.click_app))
  end)
end

util.island("usage.island", { cpu.name, ram.name })
util.gap("right")
