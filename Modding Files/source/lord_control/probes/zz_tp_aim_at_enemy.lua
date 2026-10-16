-- Does the aim stop at a real enemy in game, 2026-10-16? For one call: the rig's look point set on the chest of the
-- nearest enemy man (the eye left where it is), E.combat.aim_point read, the look point put back. Nothing else changes.
-- No string library calls.
local E = _G.DERPY_TP
local P, F, R = E.P, E.F, E.rig
local function r1(n) return math.floor(n * 10 + 0.5) / 10 end
if not (F.on and R.ex) then return "third person is off" end
local reach = F.unit:missile_range()
local best, bu, bd
local armies = bm:get_non_player_alliance():armies()
for a = 1, armies:count() do
	local list = armies:item(a):units()
	for i = 1, list:count() do
		local u = list:item(i)
		for _, m in ipairs(P.models(u)) do
			local mx, my, mz = P.model_pos(m)
			local d = math.sqrt((mx - R.ex) ^ 2 + (mz - R.ez) ^ 2)
			if not bd or d < bd then best, bu, bd = {mx, my, mz}, u, d end
		end
	end
end
if not best then return "no enemy man" end
local body = E.D.bodies and E.D.bodies[bu:type()]
local h = body and body[2] or 1.8
local lx, ly, lz = R.lx, R.ly, R.lz
R.lx, R.ly, R.lz = best[1], best[2] + h * 0.6, best[3]
local ok, ax, ay, az = pcall(E.combat.aim_point, reach)
R.lx, R.ly, R.lz = lx, ly, lz
if not ok then return "aim_point error: " .. tostring(ax) end
return "reach " .. reach .. " | nearest enemy " .. bu:type() .. " " .. r1(bd) .. " m from the eye, body " .. tostring(body and (body[1] .. "x" .. body[2]))
	.. " | aimed at his chest " .. r1(best[1]) .. "," .. r1(best[2] + h * 0.6) .. "," .. r1(best[3]) .. " | aim stopped at "
	.. tostring(ax and (r1(ax) .. "," .. r1(ay) .. "," .. r1(az))) .. " = " .. tostring(ax and r1(math.sqrt((ax - R.ex) ^ 2 + (az - R.ez) ^ 2))) .. " m from the eye"
