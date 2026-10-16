-- The aim ray against the camera the engine drew, 2026-10-16 (the author: "strteltzi sitll suffering from the same ranged
-- animation issue, aim high -> shoot level"; the shot log has both Streltsi shots aimed at the ground 12-13 m out, at his
-- height). Read only: the rig's asked eye and look-at (combat.lua's aim ray), the engine's camera position and target,
-- the angle between the two lines, and where each meets the ground. No string library calls.
local E = _G.DERPY_TP
if not (E and E.rig and E.rig.ex) then return "third person on first" end
local R, P, F = E.rig, E.P, E.F
local cam = bm:camera()
local p, t = cam:position(), cam:target()
local function r2(n) return math.floor(n * 100 + 0.5) / 100 end
local function ground(ex, ey, ez, lx, ly, lz)
	local dx, dy, dz = lx - ex, ly - ey, lz - ez
	local n = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / n, dy / n, dz / n
	for i = 1, 4000 do
		local s = i * 0.05
		local x, y, z = ex + dx * s, ey + dy * s, ez + dz * s
		if y <= bm:get_terrain_height(x, z) then return s, x, y, z, dx, dy, dz end
	end
	return nil, nil, nil, nil, dx, dy, dz
end
local s1, _, _, _, ax, ay, az = ground(R.ex, R.ey, R.ez, R.lx, R.ly, R.lz)
local s2, _, _, _, bx, by, bz = ground(p:get_x(), p:get_y(), p:get_z(), t:get_x(), t:get_y(), t:get_z())
local deg = math.deg(math.acos(math.min(1, ax * bx + ay * by + az * bz)))
local mx, my, mz = 0, 0, 0
if F.model then mx, my, mz = P.model_pos(F.model) end
return "rig eye " .. r2(R.ex - mx) .. "," .. r2(R.ey - my) .. "," .. r2(R.ez - mz) .. " look " .. r2(R.lx - mx) .. ","
	.. r2(R.ly - my) .. "," .. r2(R.lz - mz) .. " | engine eye " .. r2(p:get_x() - mx) .. "," .. r2(p:get_y() - my) .. ","
	.. r2(p:get_z() - mz) .. " target " .. r2(t:get_x() - mx) .. "," .. r2(t:get_y() - my) .. "," .. r2(t:get_z() - mz)
	.. " | the lines " .. r2(deg) .. " deg apart; rig meets the ground at " .. tostring(s1 and r2(s1)) .. " m, engine at "
	.. tostring(s2 and r2(s2)) .. " m; pitch " .. r2(math.deg(R.pitch)) .. " utype " .. tostring(F.utype)
