-- System island: [volume] [battery]   (added right-to-left)
local util = require("helpers.util")

local battery = require("items.widgets.battery")
local volume = require("items.widgets.volume")

util.island("system.island", { volume.name, battery.name })
util.gap("right")
