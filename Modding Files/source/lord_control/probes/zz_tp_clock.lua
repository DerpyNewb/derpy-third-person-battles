local ok, r = pcall(function() local t = bm:time_elapsed_ms() local tp = rawget(_G, "DERPY_TP") return type(t) .. " " .. tostring(t) .. " disabled " .. tostring(tp and tp.disabled) .. " strikes " .. tostring(tp and tp.strikes) end)
return tostring(ok) .. " " .. tostring(r)
