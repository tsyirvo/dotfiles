-- Tailscale, read from the CLI bundled in Tailscale.app (`status --json`).
--   colour   green = connected · peach = routing through an exit node · grey = stopped · red = needs login
--   label    online peers (optional)
--   left     popup: tailnet + peers, click a peer to copy its MagicDNS name
--   right    toggle connection (tailscale up / down)
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local cfg = settings.tailscale
local backend = "Unknown"

local ts = sbar.add("item", "widgets.tailscale", {
  position = "right",
  update_freq = cfg.poll_seconds,
  icon = { string = icons.vpn, font = { family = settings.font.text, style = "Regular", size = 15.0 },
           padding_left = 10 },
  label = { font = { family = settings.font.numbers, style = "Bold", size = 12.0 }, padding_right = 8 },
  popup = { align = "right" },
})

local function short_dns(dns)
  return (dns or ""):gsub("%.$", "")
end

local function render(status)
  if type(status) ~= "table" then
    backend = "Unavailable"
    ts:set({ icon = { string = icons.vpn_off, color = colors.state.muted, padding_right = 10 },
             label = { drawing = false } })
    return
  end

  backend = status.BackendState or "Unknown"
  local online, total = 0, 0
  for _, peer in pairs(status.Peer or {}) do
    total = total + 1
    if peer.Online then online = online + 1 end
  end
  local exit = status.ExitNodeStatus

  local icon, color = icons.vpn, colors.state.ok
  if backend == "NeedsLogin" or backend == "NeedsMachineAuth" then
    icon, color = icons.vpn_off, colors.state.critical
  elseif backend ~= "Running" then
    icon, color = icons.vpn_off, colors.state.muted
  elseif exit and exit.Online then
    icon, color = icons.exit_node, colors.state.high
  end

  local show_count = cfg.show_peer_count and backend == "Running"
  ts:set({
    icon = { string = icon, color = color, padding_right = show_count and 3 or 10 },
    label = { drawing = show_count, string = tostring(online) },
  })
  return online, total
end

local function update()
  util.exec(cfg.cli .. " status --json 2>/dev/null", render)
end

local function build_popup(status)
  sbar.remove("/widgets\\.tailscale\\.row\\..*/")
  local function row(id, props)
    props.position = "popup." .. ts.name
    return sbar.add("item", "widgets.tailscale.row." .. id, props)
  end

  if type(status) ~= "table" then
    row("err", { label = { string = "Tailscale CLI unavailable", color = colors.subtext0 } })
    ts:set({ popup = { drawing = true } })
    return
  end

  local self = status.Self or {}
  local tailnet = (status.CurrentTailnet or {}).Name or "tailnet"
  row("head", {
    icon = { string = backend, color = backend == "Running" and colors.state.ok or colors.state.muted,
             font = { family = settings.font.text, style = "Bold", size = 12.0 } },
    label = { string = tailnet .. " · " .. (self.HostName or "?"), color = colors.subtext1 },
  })

  local peers = {}
  for _, peer in pairs(status.Peer or {}) do peers[#peers + 1] = peer end
  table.sort(peers, function(a, b)
    if (a.Online and true or false) ~= (b.Online and true or false) then return a.Online and true or false end
    return (a.HostName or "") < (b.HostName or "")
  end)

  for i, peer in ipairs(peers) do
    if i > cfg.max_peers then break end
    local dns = short_dns(peer.DNSName)
    local ip = (peer.TailscaleIPs or {})[1] or ""
    local name = peer.HostName or dns
    if peer.ExitNode then name = name .. "  " .. icons.exit_node end
    local r = row(i, {
      icon = { string = peer.Online and icons.dot or icons.dot_off,
               color = peer.Online and colors.state.ok or colors.overlay0 },
      label = { string = string.format("%-18s %s", name, ip),
                color = peer.Online and colors.text or colors.overlay1,
                font = { family = settings.font.numbers, style = "Regular", size = 12.0 } },
    })
    r:subscribe("mouse.clicked", function()
      util.exec("printf %s " .. util.quote(dns ~= "" and dns or ip) .. " | pbcopy")
      ts:set({ popup = { drawing = false } })
    end)
  end

  ts:set({ popup = { drawing = true } })
end

ts:subscribe({ "routine", "forced", "system_woke" }, update)

ts:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    local cmd = backend == "Running" and " down" or " up"
    util.exec(cfg.cli .. cmd .. " 2>/dev/null", function() sbar.delay(1, update) end)
    return
  end
  if ts:query().popup.drawing == "on" then
    ts:set({ popup = { drawing = false } })
    return
  end
  util.exec(cfg.cli .. " status --json 2>/dev/null", function(status)
    render(status)
    build_popup(status)
  end)
end)

ts:subscribe("mouse.exited.global", function()
  ts:set({ popup = { drawing = false } })
end)

return ts
