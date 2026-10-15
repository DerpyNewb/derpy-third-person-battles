-- Stand in for holding W for 6 s (forward relative to the camera), then read zz_follow_log.lua.
local ok, res = pcall(function() local F = _G.DERPY_FOLLOW F.log = {} F.orders = 0 F.sim = {1, 0, os.clock() + 6} return "W held for 6 s" end) if ok then return res end return "ERR " .. tostring(res)
