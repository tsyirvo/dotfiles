-- Wi-Fi: last octet of the IPv4 address, e.g. ".169".
local colors = require("colors")
local settings = require("settings")
local icons = require("icons")
local util = require("helpers.util")

local wifi = sbar.add("item", "widgets.wifi", {
  position = "right",
  icon = { font = { family = settings.font.text, style = "Regular", size = 16.0 } },
  label = { font = { family = settings.font.numbers, style = "Bold", size = 12.0 } },
})

local READ = [[ipconfig getifaddr "$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2 }')"]]

local function update()
  util.exec(READ, function(out)
    local octet = tostring(out):match("%d+%.%d+%.%d+%.(%d+)")
    wifi:set({
      icon = { string = octet and icons.wifi.on or icons.wifi.off, color = octet and colors.sky or colors.state.muted },
      label = { string = octet and ("." .. octet) or "", drawing = octet ~= nil },
    })
  end)
end

-- wifi_change fires on join, before DHCP gives an address: read again a bit later.
wifi:subscribe("wifi_change", function()
  update()
  sbar.delay(5, update)
end)
wifi:subscribe({ "forced", "system_woke" }, update)

update()

return wifi
