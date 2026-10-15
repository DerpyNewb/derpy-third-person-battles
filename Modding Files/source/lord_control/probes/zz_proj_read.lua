local ok, res = pcall(function() return _G.DERPY_PROJ end) if ok then return res end return "ERR " .. tostring(res)
