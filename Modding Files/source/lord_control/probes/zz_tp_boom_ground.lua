-- 2026-10-15, "the camera issue is still happening when near buildings": the ground bm:get_terrain_height reports along
-- the rig's last boom, from his head to the eye. Read-only; no string library calls.
local E = _G.DERPY_TP
if not E or not E.rig then return "no DERPY_TP" end
local R = E.rig
local function f(x) return math.floor(x * 100 + 0.5) / 100 end
local out = "man " .. f(R.sx) .. "," .. f(R.sy) .. "," .. f(R.sz) .. " ground under him " .. f(bm:get_terrain_height(R.sx, R.sz))
	.. " eye " .. f(R.ex) .. "," .. f(R.ey) .. "," .. f(R.ez) .. " yaw " .. f(R.yaw) .. " pitch " .. f(R.pitch) .. " zoom " .. f(R.zoom) .. " |"
for i = 0, 10 do
	local t = i / 10
	local x, z = R.sx + (R.ex - R.sx) * t, R.sz + (R.ez - R.sz) * t
	out = out .. " " .. t .. ":" .. f(bm:get_terrain_height(x, z))
end
out = out .. " | behind 1-8 m along yaw:"
local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
for d = 1, 8 do out = out .. " " .. d .. ":" .. f(bm:get_terrain_height(R.sx - fx * d, R.sz - fz * d)) end
local u = E.F.unit
if u then local q = u:position() out = out .. " | unit at " .. f(q:get_x()) .. "," .. f(q:get_y()) .. "," .. f(q:get_z()) end
return out
