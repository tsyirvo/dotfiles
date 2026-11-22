-- Remaining 5-hour session limit of Claude and OpenAI (Codex), from scripts/ai-limits.sh.
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

local cfg = settings.ai_limits
local script = os.getenv("HOME") .. "/.config/sketchybar/scripts/ai-limits.sh"

local function add(key, icon)
  return sbar.add("item", "widgets.ai." .. key, {
    position = "right",
    icon = {
      string = icon,
      font = { family = settings.font.app, style = "Regular", size = 14.0 },
      color = colors.subtext0,
      padding_left = 10,
      padding_right = 4,
    },
    label = {
      string = "–",
      font = { family = settings.font.numbers, style = "Bold", size = 12.0 },
      padding_right = 4,
    },
  })
end

-- Added right to left: on screen this reads [claude] [openai].
local openai = add("openai", ":openai:")
local claude = add("claude", ":claude:")
claude:set({ update_freq = cfg.poll_seconds, updates = true })

local function render(item, used)
  if type(used) ~= "number" then
    item:set({ label = { string = "–", color = colors.state.muted } })
    return
  end
  local remaining = math.max(0, 100 - math.floor(used + 0.5))
  item:set({ label = { string = remaining .. "%", color = util.load_color(used) } })
end

local function update()
  util.exec(script, function(result)
    local data = type(result) == "table" and result or {}
    render(claude, data.claude)
    render(openai, data.codex)
  end)
end

claude:subscribe({ "routine", "forced", "system_woke" }, update)

return { claude.name, openai.name }
