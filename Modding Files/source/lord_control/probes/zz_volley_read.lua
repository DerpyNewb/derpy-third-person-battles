local ok, res = pcall(function() local T = _G.DERPY_VOLLEY return {pushed = T.pushed, trace = table.concat(T.trace, " | ")} end) if ok then return res end return "ERR " .. tostring(res)
