local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local F, R = E.F, E.rig
local cam = bm:camera():position()
return "on " .. tostring(F.on) .. " unit " .. tostring(F.unit and F.unit:type()) .. " model " .. tostring(F.model) .. " boom " .. tostring(R.boom) .. " cap " .. tostring(R.cap) .. " asked y " .. tostring(R.ey) .. " got y " .. tostring(cam:get_y()) .. " head " .. tostring(R.sy) .. " eye " .. tostring(R.ex) .. "," .. tostring(R.ez) .. " got " .. tostring(cam:get_x()) .. "," .. tostring(cam:get_z())
