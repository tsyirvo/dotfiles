-- Lanes layouts: the tabs and panes a new worktree opens with. init.lua sets
-- open = "tab", so `tab` applies; `tabs` is kept for session mode.
-- Every field is described in lanes/layouts.example.lua.

local function has(wt, file)
  local f = io.open(wt.path .. "/" .. file, "r")
  if f then f:close() end
  return f ~= nil
end

local function bun_install(wt)
  return has(wt, "bun.lock") and "bun install" or nil
end

return {
  {
    repo = "beanwise",
    tabs = {
      { name = "agent", agent = true },
      {
        name = "terminal",
        panes = {
          { command = bun_install },
          { split = "right" },
        }
      },
    },
    tab = {
      panes = {
        { agent = true },
        { split = "right", command = bun_install },
        { split = "down" },
      }
    },
  },
  {
    repo = "*",
    tabs = {
      { name = "agent",   agent = true },
      { name = "terminal" },
    },
    -- The agent on the left, 65% of the width, and a shell beside it.
    tab = {
      panes = {
        { agent = true },
        { split = "right", ratio = 0.35 },
      }
    },
  },
}
