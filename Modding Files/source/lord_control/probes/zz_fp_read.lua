local ok, res = pcall(function() return _G.DERPY_FP end) if ok then return res end return "ERR " .. tostring(res)
