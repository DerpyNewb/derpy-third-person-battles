-- 2026-10-15, three reports with nothing in the log: "the unit being controlled bugs out and will not respond if near
-- an enemy", "when near the building, it should ignore terrain and buildings", "the camera jumps one unit to another".
-- A passive recorder at 10 Hz while third person is on: the last 400 samples in a ring, and an event list for each
-- moment one of the three shows. Read with zz_tp_recorder_read.lua. Read-only towards the game; no string library
-- calls; the callback is under pcall and stops itself after an error.
local E = _G.DERPY_TP
if not E or not E.P then return "no DERPY_TP" end
local mr = _G.memreader_plus
local P, F, R, S = E.P, E.F, E.rig, E.S
bm:remove_real_callback("derpy_tp_rec")
local REC = {rows = {}, n = 0, ev = {}, err = nil}
_G.TP_REC = REC
local last = {}
local function f1(n) return math.floor(n * 10 + 0.5) / 10 end
local function nearest_enemy(x, z)
	local best = 1e9
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			if e:number_of_men_alive() > 0 then
				local p = e:position()
				local d = math.sqrt((p:get_x() - x) ^ 2 + (p:get_z() - z) ^ 2)
				if d < best then best = d end
			end
		end
	end
	return best
end
local function ev(s)
	if #REC.ev < 600 then REC.ev[#REC.ev + 1] = s end
end
local function tick()
	if not F.on or not R.ex then last = {} return end
	local t = f1(os.clock())
	local man = F.model and mr.tostring(F.model) or "whole"
	local x, y, z
	if F.model then x, y, z = P.model_pos(F.model) else local q = F.unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
	local cp = bm:camera():position()
	local cx, cy, cz = cp:get_x(), cp:get_y(), cp:get_z()
	local lift = cy - R.ey
	local slot = F.model and P.anim_slot(F.model)
	local keys = P.focused() and (P.held(S.keys.forward) or P.held(S.keys.back) or P.held(S.keys.left) or P.held(S.keys.right))
	local en = nearest_enemy(x, z)
	local row = t .. " " .. F.unit:type() .. " man " .. man .. " at " .. f1(x) .. "," .. f1(y) .. "," .. f1(z) .. " terrain under him " .. f1(bm:get_terrain_height(x, z)) .. " head " .. f1(R.sy) .. " boom " .. tostring(R.boom) .. " slot " .. tostring(slot)
		.. " lock " .. tostring(F.lock and F.lock.slot) .. " shot " .. tostring(F.shot and F.shot.phase) .. " keys "
		.. tostring(keys) .. " melee " .. tostring(F.unit:is_in_melee()) .. " enemy " .. f1(en) .. " hold "
		.. tostring(F.man_hold ~= nil) .. " eye asked " .. f1(R.ex) .. "," .. f1(R.ey) .. "," .. f1(R.ez) .. " got " .. f1(cx)
		.. "," .. f1(cy) .. "," .. f1(cz) .. " ground " .. f1(bm:get_terrain_height(R.ex, R.ez)) .. " target " .. f1(R.sx)
		.. "," .. f1(R.sz) .. " moving " .. tostring(F.unit:is_moving()) .. " idle " .. tostring(F.unit:is_idle())
		.. " rampage " .. tostring(F.unit:is_rampaging()) .. " controllable " .. tostring(F.unit:is_controllable())
		.. " scripted " .. tostring(F.unit:is_script_controlled()) .. " routing " .. tostring(F.unit:is_routing())
		.. " order " .. tostring(F.gx and f1(F.gx)) .. "," .. tostring(F.gz and f1(F.gz)) .. " driving " .. tostring(F.driving)
		.. " ordered at " .. f1(F.unit:ordered_position():get_x()) .. "," .. f1(F.unit:ordered_position():get_z())
	REC.n = REC.n + 1
	REC.rows[(REC.n - 1) % 400 + 1] = row
	-- the three moments
	if last.man and (last.man ~= man or last.unit ~= F.unit:unique_ui_id()) then
		ev("SWITCH " .. row .. " from " .. last.man)
		for k = math.max(1, REC.n - 5), REC.n - 1 do ev("  before: " .. REC.rows[(k - 1) % 400 + 1]) end
	end
	if last.sx and (R.sx - last.sx) ^ 2 + (R.sz - last.sz) ^ 2 > 16 then ev("TARGET JUMP " .. f1(last.sx) .. "," .. f1(last.sz) .. " -> " .. row) end
	if lift > 1 then ev("LIFT " .. f1(lift) .. " " .. row) end
	local up = y - bm:get_terrain_height(x, z)
	if up > 1 and not (last.up and last.up > 1) then ev("ON SOMETHING " .. f1(up) .. " m up " .. row) end
	last.up = up
	if keys and last.x and (x - last.x) ^ 2 + (z - last.z) ^ 2 < 0.0004 then
		last.stuck = (last.stuck or 0) + 1
		if last.stuck == 10 then
			ev("STUCK 1 s, keys held " .. row)
			for k = math.max(1, REC.n - 15), REC.n - 1 do ev("  before: " .. REC.rows[(k - 1) % 400 + 1]) end
		end
	else
		last.stuck = 0
	end
	last.man, last.unit, last.sx, last.sz, last.x, last.z = man, F.unit:unique_ui_id(), R.sx, R.sz, x, z
end
-- 2026-10-15 19:50, "the camera issue is still happening when near buildings": every frame rig.update reads the camera
-- as lifted (the pull-in's trigger), what it was given: the engine's y against the last three asked eyes (a camera that
-- reports a frame late reads as lifted whenever the eye goes down), the ground under that eye and the highest within 2 m
-- (does bm:get_terrain_height count the building?), the boom before and after. In REC.pull, apart from REC.ev, so the
-- reader needs no string calls. Also HEAD-CAM: the boom at its floor. A wrapper on E.rig.update; the original is kept
-- so a re-run does not wrap twice
local orig = _G.TP_REC_RIG_UPDATE or R.update
_G.TP_REC_RIG_UPDATE = orig
REC.lifts, REC.pull, REC.heads = 0, {}, 0
local asked = {} -- the last three asked eye ys, newest first
R.update = function(now, dt, x, y, z, ranged, melee, got_y)
	local ey, ex, ez, b0 = R.ey, R.ex, R.ez, R.boom
	local r = {orig(now, dt, x, y, z, ranged, melee, got_y)}
	local ok, err = pcall(function()
		if ey and got_y and got_y - ey > 0.3 then
			REC.lifts = REC.lifts + 1
			if #REC.pull < 200 then
				local hi = -1e9
				for dx = -2, 2, 2 do for dz = -2, 2, 2 do
					local g = bm:get_terrain_height(ex + dx, ez + dz) if g > hi then hi = g end
				end end
				REC.pull[#REC.pull + 1] = "PULL-IN t " .. f1(os.clock()) .. " asked eye " .. f1(ex) .. "," .. f1(ey) .. "," .. f1(ez)
					.. " engine y " .. f1(got_y) .. " asked before " .. tostring(asked[2] and f1(asked[2])) .. ", "
					.. tostring(asked[3] and f1(asked[3])) .. " ground under eye " .. f1(bm:get_terrain_height(ex, ez))
					.. " highest within 2 m " .. f1(hi) .. " man " .. f1(x) .. "," .. f1(y) .. "," .. f1(z) .. " ground under him "
					.. f1(bm:get_terrain_height(x, z)) .. " boom " .. f1(b0) .. " -> " .. f1(R.boom) .. " pitch " .. f1(R.pitch)
					.. " zoom " .. f1(R.zoom) .. " dt " .. f1(dt * 1000) .. " ms"
			end
		end
		if R.boom <= 0.15 and b0 > 0.15 then
			REC.heads = REC.heads + 1
			if #REC.pull < 200 then
				REC.pull[#REC.pull + 1] = "HEAD-CAM t " .. f1(os.clock()) .. " man " .. f1(x) .. "," .. f1(y) .. "," .. f1(z)
					.. " eye " .. f1(R.ex) .. "," .. f1(R.ey) .. "," .. f1(R.ez)
			end
		end
		asked[3], asked[2], asked[1] = asked[2], asked[1], R.ey
	end)
	if not ok then REC.err = "wrapper: " .. tostring(err) end
	return unpack(r)
end
-- 2026-10-15 21:20, "redirecting melee attacks to the battalions direction": every click, the camera's yaw against the
-- regiment's bearing, whether it fights and how near the enemy is; the man's facing per engine tick is tp_cmd_trace.py's
local orig_melee = _G.TP_REC_MELEE or E.combat.melee
_G.TP_REC_MELEE = orig_melee
E.combat.melee = function(now, primary)
	local r = {orig_melee(now, primary)}
	pcall(function()
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = F.unit:position() x, z = q:get_x(), q:get_z() end
		ev("SWING t " .. f1(os.clock()) .. " game " .. bm:time_elapsed_ms() .. " primary " .. tostring(primary) .. " camera "
			.. f1(math.deg(R.yaw) % 360) .. " regiment " .. f1(F.unit:bearing()) .. " melee " .. tostring(F.unit:is_in_melee())
			.. " enemy " .. f1(nearest_enemy(x, z)) .. " man " .. (F.model and mr.tostring(F.model) or "whole") .. " face "
			.. tostring(F.model and mr.read_uint16(F.model, 0xb0)) .. " lock " .. tostring(F.lock and F.lock.slot)
			.. " lock yaw " .. tostring(F.lock and f1(math.deg(F.lock.yaw) % 360)))
	end)
	return unpack(r)
end
bm:repeat_real_callback(function()
	local ok, err = pcall(tick)
	if not ok then REC.err = tostring(err) bm:remove_real_callback("derpy_tp_rec") end
end, 100, "derpy_tp_rec")
return "recording"
