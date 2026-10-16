-- Why the aim passes enemies (the author, 2026-10-16: "doesnt work" - the shots still aimed 114-150 m out). Read only:
-- the rig's view line against the game camera's, the aim point, and for each enemy regiment its centre against the line,
-- how many men P.models reads, the body data.lua gives, and the nearest man to the line with his height window. No
-- string library calls.
local E = _G.DERPY_TP
local P, F, R = E.P, E.F, E.rig
local function r1(n) return math.floor(n * 10 + 0.5) / 10 end
if not (F.on and R.ex) then return "third person is off" end
local out = "on " .. F.unit:type() .. " | bodies " .. tostring(E.D.bodies ~= nil)
local cam = bm:camera()
local p, t = cam:position(), cam:target()
out = out .. " | rig eye " .. r1(R.ex) .. "," .. r1(R.ey) .. "," .. r1(R.ez) .. " look " .. r1(R.lx) .. "," .. r1(R.ly) .. "," .. r1(R.lz)
	.. " | camera " .. r1(p:get_x()) .. "," .. r1(p:get_y()) .. "," .. r1(p:get_z()) .. " target " .. r1(t:get_x()) .. ","
	.. r1(t:get_y()) .. "," .. r1(t:get_z())
local ax, ay, az = E.combat.aim_point(F.unit:missile_range())
local mx0, my0, mz0
if F.model then mx0, my0, mz0 = P.model_pos(F.model) end
out = out .. " | aim " .. (ax and (r1(ax) .. "," .. r1(ay) .. "," .. r1(az)) or "nil") .. " his " .. tostring(mx0 and (r1(mx0) .. "," .. r1(my0) .. "," .. r1(mz0)))
local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
local n = math.sqrt(dx * dx + dy * dy + dz * dz)
dx, dy, dz = dx / n, dy / n, dz / n
local hh = dx * dx + dz * dz
local armies = bm:get_non_player_alliance():armies()
for a = 1, armies:count() do
	local list = armies:item(a):units()
	for i = 1, list:count() do
		local u = list:item(i)
		if u:number_of_men_alive() > 0 then
			local q = u:position()
			local tc = ((q:get_x() - R.ex) * dx + (q:get_z() - R.ez) * dz) / hh
			local ox, oz = R.ex + dx * tc - q:get_x(), R.ez + dz * tc - q:get_z()
			local body = E.D.bodies and E.D.bodies[u:type()]
			local ok, ms = pcall(P.models, u)
			local best, bs, by, bmy
			if ok then
				for _, m in ipairs(ms) do
					local mx, my, mz = P.model_pos(m)
					local s = ((mx - R.ex) * dx + (mz - R.ez) * dz) / hh
					local cx, cz = R.ex + dx * s - mx, R.ez + dz * s - mz
					local off = math.sqrt(cx * cx + cz * cz)
					if s > 0 and (not best or off < best) then best, bs, by, bmy = off, s, R.ey + dy * s, my end
				end
			end
			out = out .. " | " .. u:type() .. " men " .. u:number_of_men_alive() .. " models " .. (ok and #ms or ("error " .. tostring(ms)))
				.. " body " .. tostring(body and (body[1] .. "x" .. body[2])) .. " centre t " .. r1(tc) .. " off " .. r1(math.sqrt(ox * ox + oz * oz))
				.. (best and (" nearest man off " .. r1(best) .. " at t " .. r1(bs) .. ", line y " .. r1(by) .. " his feet " .. r1(bmy)) or "")
		end
	end
end
return out
