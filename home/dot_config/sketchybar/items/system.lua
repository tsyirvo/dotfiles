-- System island: [cpu graph] [microphone] [battery]   (added right-to-left)
local util = require("helpers.util")

local battery = require("items.widgets.battery")
local mic = require("items.widgets.mic")
local cpu = require("items.widgets.cpu")

util.island("system.island", { cpu.name, mic.name, battery.name })
util.gap("right")
