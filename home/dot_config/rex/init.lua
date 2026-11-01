-- Lanes: ~/.config/rex/lanes links to ~/projects/open-source/rex-lanes.
-- Agents are left out, so Lanes offers the ones Rex supports that are on PATH.
require("lanes").setup {
  layouts = require("lanes-layouts"),
}

rex.bind("cmd+alt+n", "lanes_new")
rex.bind("cmd+alt+backspace", "lanes_remove")

-- Floats: ~/.config/rex/floats links to ~/projects/open-source/rex-floats.
-- Each float's key is bound by setup, from floats-config.lua.
require("floats").setup { floats = require("floats-config") }
