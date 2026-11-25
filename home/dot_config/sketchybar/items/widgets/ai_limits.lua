-- Remaining 5-hour session limit of Claude and OpenAI (Codex), from Pupitre's
-- `agent-usage` CLI. It reads a cache shared with the Stream Deck, and it calls
-- the APIs at most once per 5 minutes, whoever asks. So this item polls often.
-- A click on either item shows the 5-hour and weekly limits of both providers.
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

local cfg = settings.ai_limits

local PROVIDERS = {
  { prefix = "CLAUDE", title = "Anthropic", icon = ":claude:" },
  { prefix = "CODEX", title = "OpenAI", icon = ":openai:" },
}
local WINDOWS = {
  { suffix = "5H", title = "5 hours" },
  { suffix = "7D", title = "Weekly" },
}

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
openai:set({ popup = { align = "right" } })

local rows = {}
for _, provider in ipairs(PROVIDERS) do
  local key = provider.prefix:lower()
  rows[provider.prefix] = sbar.add("item", "widgets.ai.popup." .. key, {
    position = "popup." .. openai.name,
    icon = {
      string = provider.icon,
      font = { family = settings.font.app, style = "Regular", size = 14.0 },
      color = colors.subtext0,
    },
    label = { string = provider.title, font = { family = settings.font.text, style = "Bold", size = 12.0 } },
  })
  for _, window in ipairs(WINDOWS) do
    rows[provider.prefix .. "_" .. window.suffix] = sbar.add("item", "widgets.ai.popup." .. key .. "." .. window.suffix:lower(), {
      position = "popup." .. openai.name,
      icon = {
        string = window.title,
        width = 76,
        align = "left",
        color = colors.subtext0,
        padding_left = 22,
        font = { family = settings.font.text, style = "Regular", size = 12.0 },
      },
      label = { string = "–", padding_right = 12, font = { family = settings.font.numbers, style = "Regular", size = 12.0 } },
    })
  end
end

-- `agent-usage --format env` prints NAME=value lines, e.g. CLAUDE_5H=42 and CLAUDE_STALE=0.
local function parse_env(output)
  local vars = {}
  for name, value in tostring(output):gmatch("([%u_][%u%d_]*)=([^\n]*)") do
    vars[name] = value:match("^'(.*)'$") or value
  end
  return vars
end

local function remaining(used)
  return math.max(0, 100 - math.floor(used + 0.5))
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
      string = remaining(used) .. "%",
      color = stale and colors.state.muted or util.load_color(used),
    },
  })
end

local function render_popup(vars)
  for _, provider in ipairs(PROVIDERS) do
    local stale = vars[provider.prefix .. "_STALE"] ~= "0"
    local error = vars[provider.prefix .. "_ERROR"] or ""
    rows[provider.prefix]:set({
      label = {
        string = error ~= "" and (provider.title .. " · " .. error) or provider.title,
        color = stale and colors.state.muted or colors.text,
      },
    })
    for _, window in ipairs(WINDOWS) do
      local name = provider.prefix .. "_" .. window.suffix
      local used = tonumber(vars[name])
      local reset = vars[name .. "_RESET"] or ""
      local text = "–"
      if used then
        text = string.format("%3d%% left", remaining(used))
        if reset ~= "" then text = text .. " · resets " .. reset end
      end
      rows[name]:set({
        label = { string = text, color = (stale or not used) and colors.state.muted or util.load_color(used) },
      })
    end
  end
end

local function update()
  util.exec("agent-usage --format env", function(output)
    local vars = parse_env(output)
    render(claude, vars, "CLAUDE")
    render(openai, vars, "CODEX")
    render_popup(vars)
  end)
end

claude:subscribe({ "routine", "forced", "system_woke" }, update)

for _, item in ipairs({ claude, openai }) do
  item:subscribe("mouse.clicked", function()
    if openai:query().popup.drawing == "on" then
      openai:set({ popup = { drawing = false } })
      return
    end
    update()
    openai:set({ popup = { drawing = true } })
  end)
  item:subscribe("mouse.exited.global", function()
    openai:set({ popup = { drawing = false } })
  end)
end

return { claude.name, openai.name }
