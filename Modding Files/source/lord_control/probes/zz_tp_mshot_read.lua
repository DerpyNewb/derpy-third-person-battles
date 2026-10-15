local T = _G.TP_MSHOT
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " n " .. tostring(T.n) .. " error " .. tostring(T.error) .. " now " .. tostring(core:get_integer_preference("ui_selection_markers"))
