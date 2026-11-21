-- AeroSpace workspaces: one pill per workspace with the app icons of its windows.
-- Driven by two custom events triggered from aerospace.toml:
--   aerospace_workspace_change  (exec-on-workspace-change, carries FOCUSED_WORKSPACE)
--   aerospace_focus_change      (on-focus-changed: windows opened/closed/moved)
-- plus aerospace_mode_change for the binding-mode badge.

local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.aerospace

sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_focus_change")
sbar.add("event", "aerospace_mode_change")

-- Workspace list is read once, synchronously, so items are created in a stable
-- order before anything else lands on the left. aerospace.toml stays the single
-- source of truth: add a workspace there and it shows up here after a reload.
local function read_workspaces()
  local names = {}
  local handle = io.popen(settings.env_prefix .. "aerospace list-workspaces --all 2>/dev/null")
  if handle then
    for line in handle:lines() do
      local name = line:match("^%s*(.-)%s*$")
      if name ~= "" then names[#names + 1] = name end
    end
    handle:close()
  end
  if #names == 0 then names = cfg.fallback_workspaces end
  return names
end

local workspaces = read_workspaces()
local items = {}
local state = { focused = nil }

for _, ws in ipairs(workspaces) do
  items[ws] = sbar.add("item", "workspace." .. ws, {
    position = "left",
    drawing = not cfg.hide_empty,
    icon = {
      string = ws,
      font = { family = settings.font.text, style = "ExtraBold", size = 13.0 },
      color = colors.workspace.fg,
      highlight_color = colors.workspace.focused_fg,
      padding_left = 10,
      padding_right = 6,
    },
    label = {
      string = "",
      drawing = false,
      font = { family = settings.font.app, style = "Regular", size = 14.0 },
      color = colors.workspace.apps,
      highlight_color = colors.workspace.focused_fg,
      padding_left = 0,
      padding_right = 10,
      y_offset = -1,
    },
    background = {
      color = colors.workspace.bg,
      border_color = colors.workspace.border,
      border_width = 1,
      height = settings.item_height - 4, -- sits inside the left island
      corner_radius = settings.corner_radius - 2,
    },
    padding_left = 2,
    padding_right = 2,
    click_script = settings.env_prefix .. "aerospace workspace " .. util.quote(ws),
  })
end

-- Binding-mode badge (hidden in "main"). Needs the bindings in aerospace.toml to
-- trigger aerospace_mode_change MODE=<name>; see README.
local mode = sbar.add("item", "aerospace.mode", {
  position = "left",
  drawing = false,
  padding_left = 6,
  icon = { string = icons.mode, color = colors.crust },
  label = { string = "", color = colors.crust },
  background = { color = colors.peach, height = settings.item_height },
})

mode:subscribe("aerospace_mode_change", function(env)
  local name = env.MODE or "main"
  mode:set({ drawing = name ~= "main", label = { string = name:upper() } })
end)

local function paint(ws_info, apps_by_ws)
  for _, ws in ipairs(workspaces) do
    local item = items[ws]
    local info = ws_info[ws] or {}
    local apps = apps_by_ws[ws] or {}
    local focused = ws == state.focused
    local has_windows = #apps > 0

    local glyphs = {}
    for i, app in ipairs(apps) do glyphs[i] = util.app_icon(app) end

    local props = {
      drawing = (not cfg.hide_empty) or focused or has_windows or info.visible == true,
      icon = { highlight = focused },
      label = { string = table.concat(glyphs, " "), drawing = has_windows, highlight = focused },
      background = {
        color = focused and colors.workspace.focused_bg or colors.workspace.bg,
        border_color = (info.visible and not focused) and colors.workspace.visible_border
          or colors.workspace.border,
      },
    }
    if cfg.per_display and info.monitor then props.display = info.monitor end

    sbar.animate("tanh", 8, function() item:set(props) end)
  end
end

local function refresh()
  util.exec(
    "aerospace list-workspaces --all --json --format "
      .. "'%{workspace} %{workspace-is-focused} %{workspace-is-visible} %{monitor-appkit-nsscreen-screens-id}'",
    function(ws_list)
      local ws_info = {}
      if type(ws_list) == "table" then
        for _, w in ipairs(ws_list) do
          local name = tostring(w.workspace)
          ws_info[name] = {
            visible = util.truthy(w["workspace-is-visible"]),
            monitor = tonumber(w["monitor-appkit-nsscreen-screens-id"]),
          }
          if util.truthy(w["workspace-is-focused"]) then state.focused = name end
        end
      end

      util.exec("aerospace list-windows --all --json --format '%{workspace} %{app-name}'", function(win_list)
        local apps_by_ws, seen = {}, {}
        if type(win_list) == "table" then
          for _, w in ipairs(win_list) do
            local ws, app = tostring(w.workspace), w["app-name"]
            if app then
              apps_by_ws[ws] = apps_by_ws[ws] or {}
              seen[ws] = seen[ws] or {}
              if not (cfg.dedupe_apps and seen[ws][app]) then
                seen[ws][app] = true
                table.insert(apps_by_ws[ws], app)
              end
            end
          end
        end
        paint(ws_info, apps_by_ws)
      end)
    end
  )
end

local schedule_refresh = util.debounce(0.05, refresh)

-- Invisible item that only listens. `updates = true` keeps it receiving events
-- even though it is never drawn.
local listener = sbar.add("item", "workspaces.listener", { drawing = false, updates = true })

listener:subscribe("aerospace_workspace_change", function(env)
  -- Fast path: move the highlight immediately, then refresh icons/visibility.
  local previous = state.focused
  state.focused = env.FOCUSED_WORKSPACE or state.focused
  if previous and items[previous] and previous ~= state.focused then
    items[previous]:set({ icon = { highlight = false }, label = { highlight = false },
      background = { color = colors.workspace.bg } })
  end
  if state.focused and items[state.focused] then
    items[state.focused]:set({ drawing = true, icon = { highlight = true }, label = { highlight = true },
      background = { color = colors.workspace.focused_bg } })
  end
  schedule_refresh()
end)

listener:subscribe(
  { "aerospace_focus_change", "front_app_switched", "display_change", "system_woke", "forced" },
  function() schedule_refresh() end
)

refresh()

-- Names for the left island bracket (items/init.lua)
local names = {}
for _, ws in ipairs(workspaces) do names[#names + 1] = items[ws].name end
return names
