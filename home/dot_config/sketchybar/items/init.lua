local settings = require("settings")
local util = require("helpers.util")

-- Left side, in order (left to right) ---------------------------------------------
--   [ 1 ▢▢  A ▢  X ▢▢ … ]  [ spotify ▂▅▃▇ Title · Artist ]  (mode badge)
util.island("left.island", require("items.workspaces"))

if settings.spotify.enabled then require("items.spotify") end
if settings.show_front_app then require("items.front_app") end

-- Right side: the first one added is the right-most -----------------------------------
--   [tinybar lookaway claude openai tailscale]  [cpu ram]  [volume battery]  [clock]
require("items.clock")
require("items.system")       -- volume, battery island
require("items.usage")        -- cpu, ram island
if settings.enable_native_tailscale or settings.ai_limits.enabled or #settings.menu_extras > 0 then
  require("items.menu_extras") -- tailscale (native) + aliased menu bar apps island
end
