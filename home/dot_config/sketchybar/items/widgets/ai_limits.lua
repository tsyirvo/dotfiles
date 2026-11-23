-- Remaining 5-hour session limit of Claude and OpenAI (Codex), from Pupitre's
-- `agent-usage` CLI. It reads a cache shared with the Stream Deck, and it calls
-- the APIs at most once per 5 minutes, whoever asks. So this item polls often.
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

local cfg = settings.ai_limits

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

-- `agent-usage --format env` prints NAME=value lines, e.g. CLAUDE_5H=42 and CLAUDE_STALE=0.
local function parse_env(output)
  local vars = {}
  for name, value in tostring(output):gmatch("([%u_][%u%d_]*)=([^\n]*)") do
    vars[name] = value:match("^'(.*)'$") or value
  end
  return vars
end

local function render(item, vars, prefix)
  local used = tonumber(vars[prefix .. "_5H"])
  if not used then
    item:set({ label = { string = "–", color = colors.state.muted } })
    return
  end
  local stale = vars[prefix .. "_STALE"] ~= "0"
  item:set({
    label = {
      string = math.max(0, 100 - math.floor(used + 0.5)) .. "%",
      color = stale and colors.state.muted or util.load_color(used),
    },
  })
end

local function update()
  util.exec("agent-usage --format env", function(output)
    local vars = parse_env(output)
    render(claude, vars, "CLAUDE")
    render(openai, vars, "CODEX")
  end)
end

claude:subscribe({ "routine", "forced", "system_woke" }, update)

return { claude.name, openai.name }
