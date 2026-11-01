-- Floats: commands a key opens in a floating terminal, in the focused pane's
-- directory. Every field is described in floats/floats.example.lua.

return {
  {
    name    = "diff",
    title   = "Diff",
    key     = "cmd+shift+t",
    command = "tuicr",
    bounds  = { 0.02, 0.08, 0.96, 0.84 },
    cwd     = "git",
  },
  {
    name    = "lazygit",
    title   = "Lazygit",
    key     = "cmd+shift+g",
    command = { "lazygit" },
    cwd     = "git",
    bounds  = { 0.05, 0.05, 0.9, 0.9 },
  },
}
