local ok, res = pcall(function() return _G.DERPY_FIRE end) if ok then return res end return "ERR " .. tostring(res)
