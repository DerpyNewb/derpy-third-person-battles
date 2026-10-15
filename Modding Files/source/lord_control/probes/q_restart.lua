local ok, res = pcall(function() bm:restart_battle() return "restarting" end) if ok then return res end return "ERR " .. tostring(res)
