local ok, res = pcall(function() return _G.DERPY_SNAP.snaps end) if ok then return res end return "ERR " .. tostring(res)
