-- Lanes: ~/.config/rex/lanes links to ~/Developer/open-source/rex-lanes (chezmoi symlink).
-- Agents are left out, so Lanes offers the ones Rex supports that are on PATH.
require("lanes").setup {
  layouts = require("lanes-layouts"),
  open = "tab",
}

rex.bind("cmd+alt+n", "lanes_new")
rex.bind("cmd+alt+backspace", "lanes_remove")

-- Float: ~/.config/rex/float links to ~/Developer/open-source/rex-float (chezmoi symlink).
-- Each float's key is bound by setup, from float-config.lua.
require("float").setup { floats = require("float-config") }
