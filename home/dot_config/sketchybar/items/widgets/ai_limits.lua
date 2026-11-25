-- Remaining 5-hour session limit of Claude and OpenAI (Codex), from Pupitre's
-- `agent-usage` CLI. It reads a cache shared with the Stream Deck, and it calls
-- the APIs at most once per 5 minutes, whoever asks. So this item polls often.
-- A click on either item shows the 5-hour and weekly limits of both providers.
local colors = require("colors")
local settings = require("settings")
local util = require("helpers.util")

local cfg = settings.ai_limits

-- Same rule as Pupitre: an error, or a snapshot older than 15 minutes, is stale.
local STALE_AFTER_SECONDS = 15 * 60

local PROVIDERS = {
  { key = "claude", title = "Anthropic", icon = ":claude:" },
  { key = "codex", title = "OpenAI", icon = ":openai:" },
}
local WINDOWS = {
  { key = "fiveHour", title = "5 hours" },
  { key = "weekly", title = "Weekly" },
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

local bar_items = { claude = claude, codex = openai }

local rows = {}
for _, provider in ipairs(PROVIDERS) do
  rows[provider.key] = sbar.add("item", "widgets.ai.popup." .. provider.key, {
    position = "popup." .. openai.name,
    icon = {
      string = provider.icon,
      font = { family = settings.font.app, style = "Regular", size = 14.0 },
      color = colors.subtext0,
    },
    label = { string = provider.title, font = { family = settings.font.text, style = "Bold", size = 12.0 } },
  })
  for _, window in ipairs(WINDOWS) do
    rows[provider.key .. "." .. window.key] = sbar.add("item", "widgets.ai.popup." .. provider.key .. "." .. window.key, {
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

local function remaining(used)
  return math.max(0, 100 - math.floor(used + 0.5))
end

-- "42m", "4h43", "17h", "5 days (Mon 16:00)"
local function format_reset(resets_at_ms)
  local at = math.floor(resets_at_ms / 1000)
  local left = math.max(0, at - os.time())
  local hours = left // 3600
  local minutes = (left % 3600) // 60
  if hours < 1 then return minutes .. "m" end
  if hours < 6 then return string.format("%dh%02d", hours, minutes) end
  if hours < 24 then return hours .. "h" end
  local days = math.floor(left / 86400 + 0.5)
  return string.format("%d %s (%s)", days, days == 1 and "day" or "days", os.date("%a %H:%M", at))
end

local function is_stale(entry)
  local snapshot = entry and entry.snapshot
  if not snapshot or entry.error then return true end
  return os.time() - snapshot.asOf / 1000 > STALE_AFTER_SECONDS
end

local function render(provider, entry)
  local snapshot = entry and entry.snapshot or {}
  local stale = is_stale(entry)
  local error = entry and entry.error

  local five_hour = snapshot.fiveHour
  bar_items[provider.key]:set({
    label = {
      string = five_hour and (remaining(five_hour.usedPercent) .. "%") or "–",
      color = (stale or not five_hour) and colors.state.muted or util.load_color(five_hour.usedPercent),
    },
  })

  rows[provider.key]:set({
    label = {
      string = error and (provider.title .. " · " .. error) or provider.title,
      color = stale and colors.state.muted or colors.text,
    },
  })
  for _, window in ipairs(WINDOWS) do
    local limit = snapshot[window.key]
    local text = "–"
    if limit then
      text = string.format("%3d%% left", remaining(limit.usedPercent))
      if limit.resetsAt then text = text .. " · resets in " .. format_reset(limit.resetsAt) end
    end
    rows[provider.key .. "." .. window.key]:set({
      label = { string = text, color = (stale or not limit) and colors.state.muted or util.load_color(limit.usedPercent) },
    })
  end
end

local function update()
  util.exec("agent-usage --format json", function(cache)
    local providers = type(cache) == "table" and cache.providers or {}
    for _, provider in ipairs(PROVIDERS) do
      render(provider, providers[provider.key])
    end
  end)
end

claude:subscribe({ "routine", "forced", "system_woke" }, update)

-- Each open gets a new number. A timer from an earlier open must not close a newer one.
local popup_opened = 0

local function hide_popup()
  openai:set({ popup = { drawing = false } })
end

for _, item in ipairs({ claude, openai }) do
  item:subscribe("mouse.clicked", function()
    if openai:query().popup.drawing == "on" then
      hide_popup()
      return
    end
    update()
    openai:set({ popup = { drawing = true } })
    popup_opened = popup_opened + 1
    local this_open = popup_opened
    sbar.delay(cfg.popup_seconds, function()
      if this_open == popup_opened then hide_popup() end
    end)
  end)
  item:subscribe("mouse.exited.global", hide_popup)
end

return { claude.name, openai.name }
