local T = _G.TP_SLIDE
if not T then return "no probe ran" end
return "phase " .. T.phase .. " played " .. tostring(T.played) .. " err " .. tostring(T.err) .. T.log
