-- Read zz_tp_tank_fire.lua's result. No string library calls.
local T = _G.TP_TF
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, mode = T.mode, whole = T.whole, enemy = T.enemy, enemy_d = T.enemy_d,
	range = T.range, ammo0 = T.ammo0, fired = T.fired, ammo = T.ammo, log = T.log, facing = T.facing}
