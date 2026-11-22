-- System island: [wifi] [volume] [battery]   (added right-to-left)
local util = require("helpers.util")

local battery = require("items.widgets.battery")
local volume = require("items.widgets.volume")
local wifi = require("items.widgets.wifi")

util.island("system.island", { wifi.name, volume.name, battery.name })
util.gap("right")
