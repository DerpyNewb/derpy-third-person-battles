-- One session's settings, read again at every toggle: MCT's finalized values, or the defaults when MCT
-- is absent or an option is missing. return function(mct, K) -> S.
-- Two actions on one key: the later one falls back to its own default; when that default is taken too,
-- the action stays unbound. Each case goes into S.conflicts, and main.lua logs it once. K.shares names the
-- pairs that may sit on one key (a click and a hold). T: stats.lua, whose steps S.stats holds by stat ("none" leaves one out).
return function(mct, K, T)
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
		if owner[name] and owner[name] ~= K.shares[action] then
			local fallback = K.defaults[action]
			local now = (not owner[fallback] or owner[fallback] == K.shares[action]) and fallback or nil
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
	S.bars = ({always = "always", guide = "guide", off = false})[get("display_bars_show", "always")]
	S.bars_range = get("display_bars_range", 40)
	S.man_bars = get("display_man_bars", true) == true -- a bar over each man too, within bars_range, shown as the bars are
	S.guide_hold = get("display_guide_hold", true) == true
	S.guide_banners = get("display_guide_banners", true) == true
	S.command_speed = ({normal = 1, half = 0.5, quarter = 0.25, paused = 0})[get("command_speed", "quarter")] or 0.25
	S.command_distance = get("command_distance", 20)
	S.command_any_unit = get("command_any_unit", false) -- off: the general and heroes only
	-- Vanilla: CA's own controls at the crosshair; Bannerlord: the 2026-10-22 build (the author, 2026-10-23)
	S.command_style = get("command_style", "vanilla") == "bannerlord" and "bannerlord" or "vanilla"
	S.debug = get("debug_log", false) == true
	S.stats = {}
	for _, stat in ipairs(T and T.order or {}) do
		local chosen = get("stat_" .. stat, "none")
		for _, step in ipairs(T.steps(stat)) do if T.step_key(step) == chosen then S.stats[stat] = step end end
	end
	return S
end
