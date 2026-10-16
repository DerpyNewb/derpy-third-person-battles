local t = _G.TPSW
if not t then return "none" end
local out = {"bearing " .. t.b .. " want " .. t.want .. " rows " .. #t.rows}
for i = 1, #t.rows, 6 do out[#out + 1] = t.rows[i] end
return out
