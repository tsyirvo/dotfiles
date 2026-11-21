-- Spotify now playing: visible only while playing.
--   [ spotify-logo  ▂▅▃▇  Title · Artist ]
--   left click   play / pause
--   right click  popup: album, previous, play/pause, next
-- Event-driven: Spotify posts the distributed notification
-- "com.spotify.client.PlaybackStateChanged" on every play/pause/track change, and
-- SketchyBar turns it into an event whose INFO is that notification's userInfo
-- ("Player State", "Name", "Artist", "Album"). No polling, and it does not depend
-- on the MediaRemote-based media_change event deprecated on macOS 26.
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.spotify

sbar.add("event", "spotify_change", "com.spotify.client.PlaybackStateChanged")

util.gap("left")

local logo = sbar.add("item", "spotify.logo", {
  position = "left",
  drawing = false,
  icon = {
    string = icons.spotify,
    color = colors.green,
    font = { family = settings.font.text, style = "Regular", size = 16.0 },
    padding_left = 10,
    padding_right = 2,
  },
  label = { drawing = false },
  padding_left = 0,
  padding_right = 0,
})

local eq = sbar.add("item", "spotify.eq", {
  position = "left",
  drawing = false,
  icon = { drawing = false },
  label = {
    string = icons.eq_frames[1],
    color = colors.green,
    font = { family = settings.font.text, style = "Regular", size = 10.0 },
    padding_left = 2,
    padding_right = 2,
  },
  padding_left = 0,
  padding_right = 0,
})

-- The title item owns the events, clicks and popup.
local title = sbar.add("item", "spotify", {
  position = "left",
  drawing = false,
  updates = true, -- keep receiving spotify_change while hidden
  icon = { drawing = false },
  label = {
    string = "",
    max_chars = cfg.max_chars, -- longer titles scroll (scroll_texts is on by default)
    color = colors.subtext1,
    font = { family = settings.font.text, style = "SemiBold", size = 12.0 },
    padding_left = 4,
    padding_right = 10,
  },
  padding_left = 0,
  padding_right = 0,
  popup = { align = "left" },
})

local island = util.island("spotify.island", { logo.name, eq.name, title.name })
island:set({ background = { drawing = false } })

local album = sbar.add("item", "spotify.album", {
  position = "popup." .. title.name,
  icon = { string = icons.album, color = colors.subtext0, width = 26, align = "left" },
  label = { string = "", max_chars = 40, color = colors.subtext1, padding_right = 12 },
})

local controls = {
  { "prev", icons.prev, "Previous", "previous track" },
  { "toggle", icons.play_pause, "Play / pause", "playpause" },
  { "next", icons.next, "Next", "next track" },
}
for _, c in ipairs(controls) do
  local row = sbar.add("item", "spotify.ctl." .. c[1], {
    position = "popup." .. title.name,
    icon = { string = c[2], color = colors.green, width = 26, align = "left" },
    label = { string = c[3], padding_right = 12 },
  })
  row:subscribe("mouse.clicked", function()
    util.exec("osascript -e " .. util.quote('tell application "Spotify" to ' .. c[4]))
  end)
end

-- Equaliser animation loop (runs only while playing) -----------------------------
local playing = false
local frame = 1
local function tick()
  if not playing or not cfg.animate then return end
  frame = frame % #icons.eq_frames + 1
  eq:set({ label = { string = icons.eq_frames[frame] } })
  sbar.delay(cfg.animation_seconds, tick)
end

local function show(state, name, artist, album_name)
  local was_playing = playing
  playing = state == "Playing"
  local text = name or ""
  if artist and artist ~= "" then text = text .. " · " .. artist end

  sbar.animate("tanh", 10, function()
    logo:set({ drawing = playing })
    eq:set({ drawing = playing and cfg.animate })
    title:set({ drawing = playing, label = { string = text } })
    island:set({ background = { drawing = playing } })
  end)
  album:set({ label = { string = album_name or "" } })
  if not playing then title:set({ popup = { drawing = false } }) end
  if playing and not was_playing then tick() end
end

-- INFO arrives parsed into a table when it is JSON; be lenient either way.
title:subscribe("spotify_change", function(env)
  local info = env.INFO
  if type(info) ~= "table" then
    show("Stopped")
    return
  end
  show(info["Player State"], info["Name"], info["Artist"], info["Album"])
end)

-- Initial state (and after wake): ask Spotify only if it is already running, so
-- this never launches it.
local QUERY = [[osascript -e 'if application "Spotify" is running then' ]]
  .. [[-e 'tell application "Spotify" to return (player state as text) & "|" & ]]
  .. [[(name of current track) & "|" & (artist of current track) & "|" & (album of current track)' ]]
  .. [[-e 'end if' 2>/dev/null]]

local function poll_once()
  util.exec(QUERY, function(out)
    out = tostring(out or "")
    local state, name, artist, album_name = out:match("^(%a+)|([^|]*)|([^|]*)|([^\n]*)")
    if state then
      show(state:sub(1, 1):upper() .. state:sub(2), name, artist, album_name) -- "playing" -> "Playing"
    else
      show("Stopped")
    end
  end)
end

title:subscribe({ "forced", "system_woke" }, poll_once)

local function on_click(env)
  if env.BUTTON == "right" then
    title:set({ popup = { drawing = "toggle" } })
  else
    util.exec([[osascript -e 'tell application "Spotify" to playpause']])
  end
end
title:subscribe("mouse.clicked", on_click)
logo:subscribe("mouse.clicked", on_click)
eq:subscribe("mouse.clicked", on_click)

title:subscribe("mouse.exited.global", function()
  title:set({ popup = { drawing = false } })
end)

poll_once()
