-- a fixed test target: take the held enemy (zz_target_setup) from its AI, teleport it STOP_AT m in front
-- of the shooter facing it, fearless so it never routs, halted; the old pin watcher is dropped
local STOP_AT, WIDTH = 90, 40
local ok, res = pcall(function()
	local S = _G.DERPY_TGT
	local me = S.shooter
	bm:remove_real_callback("derpy_tgt_watch")
	local q = me:position()
	local b = me:bearing()
	local r = math.rad(b)
	local tx, tz = q:get_x() + math.sin(r) * STOP_AT, q:get_z() + math.cos(r) * STOP_AT
	S.uce:take_control()
	S.uce:teleport_to_location(v(tx, q:get_y(), tz), (b + 180) % 360, WIDTH)
	S.uce:morale_behavior_fearless()
	S.uce:halt()
	S.pin = {tx, q:get_y(), tz}
	bm:repeat_real_callback(function()
		local p, m = S.enemy:position(), me:position()
		S.dist = math.floor(math.sqrt((p:get_x() - m:get_x()) ^ 2 + (p:get_z() - m:get_z()) ^ 2))
		S.men = S.enemy:number_of_men_alive()
	end, 500, "derpy_tgt_watch")
	return {to = {tx, tz}, scripted = S.enemy:is_script_controlled(), men = S.enemy:number_of_men_alive()}
end)
if ok then return res end
return "ERR " .. tostring(res)
