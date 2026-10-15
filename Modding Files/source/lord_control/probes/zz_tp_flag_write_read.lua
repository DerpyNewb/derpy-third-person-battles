local T = _G.TP_FLAGW
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " ticks " .. T.n .. " set back " .. T.back .. " after " .. tostring(T.after) .. " selected " .. tostring(bm:is_any_unit_selected())
