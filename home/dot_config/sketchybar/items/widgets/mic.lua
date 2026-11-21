-- Microphone (default input device).
--   left click   mute / unmute (input volume 0 <-> previous level)
--   right click  popup to switch input device (needs `brew install switchaudio-osx`)
--   scroll       input volume up/down
-- macOS has no SketchyBar event for input changes, so this polls (only while shown).
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.mic
local last_level = nil -- remembered across mute toggles

local mic = sbar.add("item", "widgets.mic", {
  position = "right",
  update_freq = cfg.poll_seconds,
  icon = { string = icons.mic, font = { family = settings.font.text, style = "Regular", size = 15.0 } },
  label = { font = { family = settings.font.numbers, style = "Bold", size = 12.0 } },
  popup = { align = "right" },
})

local READ = [[printf 'vol=%s\ndev=%s\n' ]]
  .. [["$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)" ]]
  .. [["$(SwitchAudioSource -c -t input 2>/dev/null)"]]

local function render(level, device)
  local icon, color, text
  if level == nil then
    -- Some virtual/aggregate devices (e.g. Wave Link) expose no input volume.
    icon, color, text = icons.mic_unknown, colors.subtext0, ""
  elseif level == 0 then
    icon, color, text = icons.mic_off, colors.state.critical, "muted"
  else
    icon, color, text = icons.mic, colors.state.ok, level .. "%"
  end
  if cfg.show_device and device and device ~= "" then
    text = (text ~= "" and (device .. " " .. text)) or device
  end
  mic:set({
    icon = { string = icon, color = color },
    label = { string = text, drawing = text ~= "" },
  })
end

local function update()
  util.exec(READ, function(out)
    out = tostring(out)
    local level = tonumber(out:match("vol=(%d+)"))
    local device = out:match("dev=([^\n]*)")
    if level and level > 0 then last_level = level end
    render(level, device)
  end)
end

local function set_level(level)
  level = math.max(0, math.min(100, math.floor(level)))
  util.exec("osascript -e " .. util.quote("set volume input volume " .. level), update)
end

-- Device picker popup ---------------------------------------------------------
local function close_popup()
  mic:set({ popup = { drawing = false } })
end

local function open_device_popup()
  util.exec("SwitchAudioSource -a -t input 2>/dev/null; echo '--'; SwitchAudioSource -c -t input 2>/dev/null",
    function(out)
      out = tostring(out)
      sbar.remove("/widgets\\.mic\\.device\\..*/")
      local all, current = out:match("^(.-)%-%-\n?(.*)$")
      current = (current or ""):match("^%s*(.-)%s*$")
      local n = 0
      for name in (all or ""):gmatch("[^\n]+") do
        n = n + 1
        local selected = name == current
        local row = sbar.add("item", "widgets.mic.device." .. n, {
          position = "popup." .. mic.name,
          icon = { string = selected and icons.dot or icons.dot_off,
                   color = selected and colors.accent or colors.overlay1 },
          label = { string = name, color = selected and colors.text or colors.subtext0 },
        })
        row:subscribe("mouse.clicked", function()
          util.exec("SwitchAudioSource -t input -s " .. util.quote(name), function()
            close_popup()
            update()
          end)
        end)
      end
      if n == 0 then
        sbar.add("item", "widgets.mic.device.missing", {
          position = "popup." .. mic.name,
          label = { string = "Install switchaudio-osx to switch inputs", color = colors.subtext0 },
        })
      end
      mic:set({ popup = { drawing = true } })
    end)
end

mic:subscribe({ "routine", "forced", "system_woke", "volume_change" }, update)

mic:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    open_device_popup()
    return
  end
  util.exec([[osascript -e 'input volume of (get volume settings)']], function(out)
    local level = tonumber(tostring(out):match("(%d+)"))
    if level == nil then return end
    if level > 0 then
      last_level = level
      set_level(0)
    else
      set_level(last_level or cfg.unmute_volume)
    end
  end)
end)

mic:subscribe("mouse.scrolled", function(env)
  local delta = tonumber(env.SCROLL_DELTA) or 0
  if delta == 0 then return end
  util.exec([[osascript -e 'input volume of (get volume settings)']], function(out)
    local level = tonumber(tostring(out):match("(%d+)"))
    if level == nil then return end
    set_level(level + (delta > 0 and cfg.scroll_step or -cfg.scroll_step))
  end)
end)

mic:subscribe("mouse.exited.global", close_popup)

return mic
