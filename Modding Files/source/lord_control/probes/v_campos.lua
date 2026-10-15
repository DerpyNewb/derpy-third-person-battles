local ok, res = pcall(function() local p = bm:camera():position() return {p:get_x(), p:get_y(), p:get_z()} end) if ok then return res end return "ERR " .. tostring(res)
