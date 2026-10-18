-- One session's settings, read again at every toggle: MCT's finalized values, or the defaults when MCT
-- is absent or an option is missing. return function(mct, K) -> S.
-- Two actions on one key: the later one falls back to its own default; when that default is taken too,
-- the action stays unbound. Each case goes into S.conflicts, and main.lua logs it once.
return function(mct, K)
	local mod = mct and mct:get_mod_by_key("derpy_third_person")
	local function get(key, default)
		local o = mod and mod:get_option_by_key(key)
		local val
		if o then val = o:get_finalized_setting() end
		if val == nil then return default end
		return val
	end
	local S = {keys = {}, names = {}, conflicts = {}}
	local owner = {}
	for _, action in ipairs(K.order) do
		local name = get("key_" .. action, K.defaults[action])
		if K.vk[name] == nil then name = K.defaults[action] end
		if owner[name] then
			local fallback = K.defaults[action]
			local now = not owner[fallback] and fallback or nil
			S.conflicts[#S.conflicts + 1] = {action = action, key = name, taken_by = owner[name], now = now}
			name = now
		end
		if name then
			owner[name] = action
			S.names[action], S.keys[action] = name, K.vk[name]
		end
	end
	S.sensitivity = get("camera_sensitivity", 4) / 1000
	S.smooth = get("camera_smoothing", 5) / 100
	S.invert_y = get("camera_invert_y", false) == true
	S.distance = get("camera_distance", 6)
	S.shoulder = ({left = -1, right = 1, top = 0})[get("camera_shoulder", "right")] or 1
	S.zoom_rate = get("camera_zoom_speed", 12) / 10
	S.height = get("camera_height", 25) / 10
	S.lag = get("camera_lag", 45) / 100
	S.aim_back = get("camera_aim_back", 32) / 10
	S.melee_distance = get("camera_melee_distance", 35) / 10
	S.turn_rate = math.rad(get("move_turn_rate", 360))
	S.walk_hold = get("combat_walk_hold", false) == true
	S.swing_cooldown = get("combat_swing_cooldown", 40) / 10
	S.reload_factor = get("combat_reload", 100) / 100
	S.charge_cooldown = get("combat_charge_cooldown", 100) / 10
	S.jump_cooldown = get("combat_jump_cooldown", 100) / 10
	S.spread = get("combat_spread", 15) / 10
	S.one_man = get("combat_one_man", true) == true
	S.debug = get("debug_log", false) == true
	return S
end
