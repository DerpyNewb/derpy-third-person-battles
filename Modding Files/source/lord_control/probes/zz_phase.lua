local ok, res = pcall(function() return bm:get_current_phase_name() end) if ok then return res end return "ERR " .. tostring(res)
