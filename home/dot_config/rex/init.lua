-- Lanes: ~/.config/rex/lanes links to ~/projects/open-source/rex-lanes.
-- Agents are left out, so Lanes offers the ones Rex supports that are on PATH.
require("lanes").setup {
  layouts = require("lanes-layouts"),
}

rex.bind("cmd+alt+n", "lanes_new")
rex.bind("cmd+alt+backspace", "lanes_remove")

-- Float: ~/.config/rex/float links to ~/projects/open-source/rex-float.
-- Each float's key is bound by setup, from float-config.lua.
require("float").setup { floats = require("float-config") }
