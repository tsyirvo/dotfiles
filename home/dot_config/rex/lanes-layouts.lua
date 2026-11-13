-- Lanes layouts: the tabs and panes a new worktree session opens with.
-- Every field is described in lanes/layouts.example.lua.

local function has(wt, file)
  local f = io.open(wt.path .. "/" .. file, "r")
  if f then f:close() end
  return f ~= nil
end

return {
  {
    repo = "beanwise",
    tabs = {
      { name = "agent", agent = true },
      {
        name = "terminal",
        panes = {
          { command = function(wt) return has(wt, "bun.lock") and "bun install" or nil end },
          { split = "right" },
        }
      },
    },
  },
  {
    repo = "*",
    tabs = {
      { name = "agent",   agent = true },
      { name = "terminal" },
    },
  },
}
