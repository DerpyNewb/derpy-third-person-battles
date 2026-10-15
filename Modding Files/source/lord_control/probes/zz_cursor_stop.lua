local ok, err = pcall(function() bm:remove_real_callback("derpy_cursor") end)
return ok and "stopped" or ("ERR " .. tostring(err))
