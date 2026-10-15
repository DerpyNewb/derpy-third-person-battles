local ok, res = pcall(function() local S = _G.DERPY_TGT return {dist = S.dist, men = S.men, arrived = S.arrived} end) if ok then return res end return "ERR " .. tostring(res)
