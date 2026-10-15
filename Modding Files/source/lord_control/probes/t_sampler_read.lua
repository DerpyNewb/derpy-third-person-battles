local ok, res = pcall(function() local T = _G.DERPY_CAM_SAMPLER return {done = T.done, err = T.err, pref = T.pref, rows = T.rows} end) if ok then return res end return "ERR " .. tostring(res)
