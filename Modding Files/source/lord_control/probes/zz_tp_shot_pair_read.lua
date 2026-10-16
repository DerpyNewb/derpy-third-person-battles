local T = _G.TPSHOT
if not T then return "none" end
local out = {"done " .. tostring(T.done) .. " err " .. tostring(T.err)}
for _, r in ipairs(T.plays) do out[#out + 1] = r end
for _, r in ipairs(T.rows) do out[#out + 1] = r end
return out
