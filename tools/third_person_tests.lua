-- Offline tests for derpy_third_person, run by tools/third_person_harness.lua (see that file).
-- Each test builds what it needs; later tasks add tests above the final `return T`.
local T = {}

local function settings_with(values)
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	return settings(values and H.mct_stub(values) or nil, H.K)
end

T.settings_defaults_without_mct = function()
	local S = settings_with(nil)
	check(S.keys.toggle == 0x71, "toggle is F2")
	check(S.keys.forward == 0x57 and S.keys.back == 0x53, "W and S")
	check(type(S.keys.zoom_in) == "table" and S.keys.zoom_in[1] == 0xBB and S.keys.zoom_in[2] == 0x6B, "+ is both plus keys")
	check(S.keys.ability_10 == 0x30, "ability 10 is 0")
	check(#S.conflicts == 0, "no conflicts by default")
	check(near(S.sensitivity, 0.004) and S.one_man == true, "numbers")
	-- the author, 2026-10-17: "make default cooldonw of melee attack to 4, jumpattack to 10"
	check(S.shoulder == 1 and S.distance == 6 and near(S.swing_cooldown, 4), "camera and swing: 4 s")
end

T.settings_reads_mct = function()
	local S = settings_with({key_forward = "Up", camera_sensitivity = 8, camera_shoulder = "left", combat_one_man = false})
	check(S.keys.forward == 0x26, "forward rebound to Up")
	check(near(S.sensitivity, 0.008), "sensitivity 8 -> 0.008")
	check(S.shoulder == -1 and S.one_man == false, "shoulder and one man")
end

-- the author, 2026-10-15: "add camera customizations in the mct option, maybe add attack cooldown and other effects"
T.settings_camera_and_combat_tuning = function()
	local S = settings_with(nil)
	check(near(S.height, 2.5) and near(S.lag, 0.45) and near(S.aim_back, 3.2), "camera defaults: the old constants")
	check(near(S.smooth, 0.05), "turn smoothing 0.05 s")
	check(near(S.reload_factor, 1) and near(S.spread, 1.5), "combat defaults: the old constants")
	S = settings_with({camera_height = 40, camera_lag = 0, camera_aim_back = 60, combat_reload = 50, combat_spread = 0})
	check(near(S.height, 4) and S.lag == 0 and near(S.aim_back, 6), "camera from tenths and hundredths")
	check(near(S.reload_factor, 0.5) and S.spread == 0, "reload from a percentage, spread from tenths")
end

T.camera_height_and_lag_come_from_the_settings = function()
	H.fresh({mct = {camera_height = 40, camera_lag = 0}})
	H.tap("F2")
	H.step(2)
	check(H.eye and near(H.eye.y, 4, 0.05), "eye at the set height: " .. tostring(H.eye and H.eye.y))
end

-- the rig on its own, facing north-east so both of its axes carry the setting
local function rig_at(mct, ranged, frames)
	H.fresh() H.tap("F2")
	H.E.S = H.E.settings(H.mct_stub(mct), H.K)
	local R = H.E.rig
	R.start(0, 0, 0, 0, math.pi / 4, 1, ranged)
	for i = 1, frames do R.update(i * 0.1, 0.1, 10, 0, 0, ranged) end
	return R
end

T.the_aiming_camera_sits_the_set_distance_back = function()
	local function back(d)
		local R = rig_at({camera_aim_back = d}, true, 60)
		return math.sqrt((R.ex - 10) ^ 2 + R.ez ^ 2)
	end
	local near_, far_ = back(20), back(60)
	check(far_ - near_ > 3.5, "4 m further back: " .. near_ .. " then " .. far_)
end

T.the_follow_delay_comes_from_the_settings = function()
	local tight, loose = rig_at({camera_lag = 0}, false, 2), rig_at({camera_lag = 100}, false, 2)
	check(tight.sx > 5 and loose.sx < 1, "0 s: on him at once; 1 s: still where he was: " .. tight.sx .. ", " .. loose.sx)
end

-- a gun's reload is its own clip (1564), and the game's reload time decides the next shot, the setting's share of it:
-- a clip shorter than it does not free the shot (the author, 2026-10-16: "reload time not being followed, I can click
-- fire button when the reloading animation is finished"), shorter cuts the clip. Harness clips: aim 1, fire 4, reload
-- 7 s; the data's reload is 13 s
T.the_reload_setting_scales_one_mans_reload = function()
	local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
	local function gap(pct)
		H.fresh({mct = {combat_reload = pct}, units = {{general = true}, {type = GUN, men = 21, x = 40, range = 160, ammo = 3960}}})
		H.select(H.units[2]) H.tap("F2") H.step(0.1)
		H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
		H.down("Left mouse")
		local times = {}
		for _ = 1, 60 * 80 do
			local n = H.count("launch")
			H.step(1 / 60)
			if H.count("launch") > n then times[#times + 1] = H.game_ms end
			if #times == 3 then break end
		end
		H.up("Left mouse")
		return times[2] and times[2] - times[1], times[3] and times[3] - times[2]
	end
	local full, half = gap(100), gap(50)
	local double, double_learned = gap(200)
	-- 150 ms: a learned raise's lead counts from its send (combat.lua), a frame before its report here; 30,916 ms before that
	check(double_learned and near(double_learned, 5000 + 26000, 150), "200% of the game's time, the clip seen or not: "
		.. tostring(double_learned))
	check(full and near(full, 5000 + 13000, 100), "100%: the game's reload time, past the 7 s clip: " .. tostring(full))
	check(half and near(half, 5000 + 6500, 100), "50%: half the reload time, the clip cut: " .. tostring(half))
	check(double and near(double, 5000 + 26000, 100), "200%: held past the clip: " .. tostring(double))
end

T.the_spread_setting_can_close_the_volley = function()
	local function targets(spread)
		H.fresh({mct = {combat_spread = spread}, units = {{general = true}, {type = "zorn_test_rocket", men = 21, x = 40, range = 145, ammo = 100}}})
		local t = H.default_cco()
		t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 20
		t["ActiveProjectileContext.NumProjectiles"] = 4
		H.cco_ids = {cco_2 = t}
		H.select(H.units[2]) H.tap("F2") H.step(0.1)
		H.tap("Left mouse") H.step(3)
		local seen = {}
		for _, c in ipairs(H.all("launch")) do seen[math.floor(c[4].x * 100) .. "," .. math.floor(c[4].z * 100)] = true end
		local n = 0 for _ in pairs(seen) do n = n + 1 end
		return n, #H.all("launch")
	end
	local wide, shots = targets(15)
	local tight = targets(0)
	check(shots == 4 and wide > 1, "the default spreads the volley: " .. wide .. " points of " .. shots)
	check(tight == 1, "spread 0: one point: " .. tight)
end

T.settings_duplicate_falls_back = function()
	local S = settings_with({key_back = "W"})
	check(S.keys.back == 0x53, "back keeps its default S")
	local c = S.conflicts[1]
	check(c and c.action == "back" and c.key == "W" and c.taken_by == "forward" and c.now == "S", "conflict reported")
end

T.settings_default_taken_leaves_unbound = function()
	local S = settings_with({key_forward = "S"})
	check(S.keys.forward == 0x53, "forward took S")
	check(S.keys.back == nil, "back's choice and its default are both S, so it is unbound")
	local c = S.conflicts[1]
	check(c and c.action == "back" and c.now == nil, "reported as unbound")
	check(S.keys.left == 0x41 and S.keys.attack == 0x01, "the others still work")
end

T.settings_unknown_name_uses_default = function()
	local S = settings_with({key_attack = "Nonsense"})
	check(S.keys.attack == 0x01, "attack falls back to Left mouse")
	check(#S.conflicts == 0, "an unknown name is not a conflict")
end

-- an MCT that records what the page registers
local function recording_mct()
	local R = {options = {}, order = {}, sections = {}}
	local mod = {}
	function mod:set_title(t) R.title = t end
	function mod:set_author() end
	function mod:set_description(t) R.description = t end
	function mod:add_new_section(key) R.sections[#R.sections + 1] = key end
	function mod:add_new_option(key, kind)
		local o = {key = key, kind = kind}
		R.options[key], R.order[#R.order + 1] = o, key
		function o:set_text(t) o.text = t end
		function o:set_tooltip_text(t) o.tooltip = t end
		function o:set_default_value(val) o.default = val end
		function o:set_assigned_section(s) o.section = s end
		function o:slider_set_precision() end
		function o:slider_set_min_max(a, b) o.min, o.max = a, b end
		function o:slider_set_step_size() end
		function o:add_dropdown_values(list)
			o.values = list
			for _, val in ipairs(list) do if val.is_default then o.default = val.key end end
		end
		return o
	end
	R.mct = {register_mod = function(_, key) R.key = key return mod end}
	return R
end

local function run_page()
	local R = recording_mct()
	get_mct = function() return R.mct end
	dofile(H.file("script/mct/settings/derpy_third_person"))
	get_mct = nil
	return R
end

T.mct_page_has_every_key = function()
	local R = run_page()
	check(R.key == "derpy_third_person", "registered under the key settings.lua reads")
	for _, action in ipairs(H.K.order) do
		local o = R.options["key_" .. action]
		check(o and o.kind == "dropdown", "dropdown for " .. action)
		check(o.default == H.K.defaults[action], action .. " defaults to " .. H.K.defaults[action])
		check(#o.values == #H.K.names, action .. " offers every key name")
		check(o.text and o.text ~= "", action .. " has a label")
	end
end

T.mct_defaults_agree_with_settings = function()
	local R = run_page()
	local values = {}
	for key, o in pairs(R.options) do values[key] = o.default end
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local a, b = settings(H.mct_stub(values), H.K), settings(nil, H.K)
	-- read off settings.lua itself: a typed list went stale the first round a setting was added
	local f = assert(io.open(H.file("script/derpy_tp/settings"), "r"))
	local src = f:read("*a") f:close()
	local n = 0
	for key in src:gmatch('get%("([%w_]+)",') do n = n + 1 check(R.options[key], "the page offers " .. key) end
	check(n >= 15, "read the keys: " .. n)
	for field, v in pairs(b) do
		if type(v) ~= "table" then
			check(a[field] == v, field .. ": the page's default " .. tostring(a[field]) .. " against " .. tostring(v))
		end
	end
	for _, action in ipairs(H.K.order) do check(a.names[action] == b.names[action], "key " .. action) end
end

T.mct_text_is_plain = function()
	local R = run_page()
	local texts = {R.title or "", R.description or ""}
	for _, o in pairs(R.options) do texts[#texts + 1] = (o.text or "") .. " " .. (o.tooltip or "") end
	for _, t in ipairs(texts) do
		for _, word in ipairs({"HUD", "AI ", " cap", "rung"}) do check(not t:find(word, 1, true), "jargon '" .. word .. "' in: " .. t) end
	end
end

T.platform_split_is_float32_exact = function()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	for _, n in ipairs({0x3901cd0, 0x2e969ac, 0x4479ee0, -0x157dbc1, 0x644e8, 0, 0xffff, 0x10000}) do
		local hi, lo = M.split(n)
		check(hi + lo == n, "parts add back to " .. n)
		check(lo >= 0 and lo < 0x10000, "low part under 0x10000 for " .. n)
		check(hi % 0x10000 == 0, "high part a multiple of 0x10000 for " .. n)
		check(math.abs(hi / 0x10000) < 2 ^ 24, "high part has at most 24 significant bits for " .. n)
	end
end

local function a_rig(S)
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local E = {S = S or settings(nil, H.K)}
	return assert(loadfile("/script/derpy_tp/rig"))()(E), E
end

T.rig_sits_behind_and_above = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	local ex, ey, ez = R.update(1, 1, 0, 0, 0, false)
	check(near(ex, 0) and near(ey, 2.5) and near(ez, -6), "eye 6 m behind, 2.5 up: " .. ex .. "," .. ey .. "," .. ez)
end

T.rig_plays_the_unit_back_late = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.update(0.5, 0.01, 0, 0, 0, false)
	R.update(1.0, 0.01, 10, 0, 0, false) -- a new position sample at t=1
	R.update(1.2, 5, 10, 0, 0, false) -- 1.2 - 0.45 = 0.75; the t=0.5 call added no sample (x unchanged); dt 5 settles the spring
	check(near(R.sx, 7.5, 0.01), "target x=7.5, three quarters of the way from the t=0 sample to the t=1 one, got " .. R.sx)
end

T.rig_pitch_is_clamped = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.look(0, 100000)
	check(near(R.want_pitch, 1.1), "pitch stops at 1.1")
	R.look(0, -1000000)
	check(near(R.want_pitch, -0.25), "pitch stops at -0.25")
end

T.rig_invert_y = function()
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local R = a_rig(settings(H.mct_stub({camera_invert_y = true}), H.K))
	R.start(0, 0, 0, 0, 0, 1, false)
	R.look(0, 10)
	check(R.want_pitch < 0, "mouse down looks up when inverted")
end

T.rig_shoulder_side = function()
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	for _, side in ipairs({{"right", 1}, {"left", -1}}) do
		local R = a_rig(settings(H.mct_stub({camera_shoulder = side[1]}), H.K))
		R.start(0, 0, 0, 0, 0, 1, true)
		local ex = R.update(1, 1, 0, 0, 0, true)
		check(near(ex, side[2] * 1.0, 0.01), side[1] .. " shoulder puts the eye at x=" .. side[2] .. ", got " .. ex)
	end
end

T.rig_zoom_is_clamped = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.zoom_by(100)
	check(near(R.zoom, 6), "zoom stops at 6")
	R.zoom_by(-100)
	check(near(R.zoom, 0.6), "zoom stops at 0.6")
end

local function general_on() H.fresh() H.tap("F2") end

-- the view put somewhere at once, as if the mouse had settled there: written alone, R.yaw and R.pitch ease back
local function set_view(yaw, pitch)
	local R = H.E.rig
	if yaw then R.yaw, R.want_yaw = yaw, yaw end
	if pitch then R.pitch, R.want_pitch = pitch, pitch end
end

T.toggle_starts_and_restores = function()
	general_on()
	check(H.E.F.on, "F2 starts third person")
	check(H.last("disable_orders")[2] == true, "player orders off")
	check(H.last("camera_functions")[3] == false, "camera input off")
	H.tap("F2")
	check(not H.E.F.on, "F2 again stops it")
	check(H.last("disable_orders")[2] == false, "player orders back")
	check(H.last("camera_functions")[3] == true, "camera input back")
end

T.picks_the_selected_unit = function()
	H.fresh({units = {{general = true}, {type = "wh_test_other", x = 20}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.unit == H.units[2], "the selected unit, not the general")
end

T.camera_follows_from_behind = function()
	general_on()
	H.step(2)
	check(H.eye and near(H.eye.z, -6, 0.05) and near(H.eye.y, 2.5, 0.05), "eye behind the general")
end

-- the author, 2026-10-15: "the camera doesnt stay at the character, the camera goes up depending on the terrain".
-- Measured: asked for 75.62 over flat ground at 70, the engine put it at 76.81 - its altitude floor. CA's cutscenes lower
-- the floor with change_height_range(0, 100) and give it back with (-1, -1)
T.the_camera_floor_is_lowered_only_while_on = function()
	general_on()
	local c = H.last("camera_height_range")
	check(c and c[2] == 0 and c[3] == 100, "on: the cutscene floor, (0, 100)")
	H.tap("F2")
	c = H.last("camera_height_range")
	check(c and c[2] == -1 and c[3] == -1, "off: the game's own range back")
end

-- with the floor gone, a hill behind him would bury the camera: it comes in along its boom instead of up
T.a_hill_behind_pulls_the_camera_in_not_up = function()
	general_on()
	H.ground = function(_, z) return z < -2 and 10 or 0 end
	H.step(2)
	local g = H.ground(H.eye.x, H.eye.z)
	check(H.eye.y >= g + 0.49, "the eye clears the ground under it: " .. H.eye.y .. " over " .. g)
	check(H.eye.y < 5 and H.eye.z > -6, "pulled in toward him, not lifted over the hill: y " .. H.eye.y .. ", z " .. H.eye.z)
end

-- the author, 2026-10-15: "camera issue also not fixed, when near the buidling, it should ignore terrain and buildings"
-- (screenshots: the view on a roof). The engine's floor counts a roof where bm:get_terrain_height does not, and there is
-- no call to turn it off: the eye comes in along its boom while the engine lifts it, and goes back out once it is clear
T.a_building_behind_pulls_the_camera_in_not_up = function()
	general_on()
	H.step(2)
	local m = H.units[1]:position()
	local function boom() return math.sqrt((H.eye.x - m:get_x()) ^ 2 + (H.eye.z - m:get_z()) ^ 2) end
	local free = boom()
	H.roof = function(_, z) if z < -1.5 then return 6 end end -- a building behind him, up to 1.5 m off his back
	H.step(3)
	local got = H.cam:position()
	check(got.y - H.eye.y < 0.3, "the engine no longer lifts the eye: asked " .. H.eye.y .. ", put at " .. got.y)
	check(H.eye.z > -1.5, "it came in toward him, out of the building: z " .. H.eye.z)
	-- standing still by the wall, the eye stays in: it does not try the roof again and pop up over it
	local lifted = 0
	for _ = 1, 300 do H.step(1 / 60) if H.cam:position().y - H.eye.y > 0.3 then lifted = lifted + 1 end end
	check(lifted == 0, "no frame over the roof in 5 s by the wall: " .. lifted)
	H.roof = nil
	H.E.rig.look(60, 0) -- he turns away from it: the eye goes back out
	H.step(5)
	check(math.abs(boom() - free) < 0.05, "clear again, it goes back out: " .. boom() .. " against " .. free)
end

-- the author, 2026-10-15: "near ground the camera goes up above the unit". Measured live: with the floor at (0, 100) the
-- engine still keeps the eye ~1.55 m over the ground under it (asked 0.53, got 1.58), lifting the whole view; so the
-- rig never asks for less, and comes in along its boom instead
T.looking_up_the_camera_comes_in_rather_than_being_lifted = function()
	general_on()
	set_view(nil, -0.25)
	H.step(1)
	check(H.eye.y >= 1.6 - 0.01, "the eye keeps the engine's floor: " .. H.eye.y)
	check(H.eye.z > -6, "by coming in toward him: z " .. H.eye.z)
end

T.walking_orders_a_single_entity = function()
	general_on()
	H.step(0.5) -- clear of the start's halt: an order inside 0.5 s of it is dropped
	H.down("W")
	H.step(3)
	check(H.count("uc:goto_location") == 1, "one order: the unit has not moved within 6 m of its 15 m point")
	local c = H.last("uc:goto_location")
	check(near(c[3].z, 15) and c[4] == true, "15 m ahead, running")
	H.tap("Z")
	check(H.count("uc:goto_location") == 2 and H.last("uc:goto_location")[4] == false, "walk toggled re-orders")
	H.up("W")
	H.step(0.1)
	check(H.count("uc:halt") >= 1, "releasing W halts")
end

T.one_man_walks_alone = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2])
	H.tap("F2")
	local man = H.E.F.model
	check(man and man.id == 2011, "the front-centre man (the 11th of 21)")
	H.down("W")
	H.step(1)
	check(H.count("uc:goto_location") == 0, "the regiment gets no order")
	local s = H.last("steer")
	check(s[2] == man.id and near(s[4] - man.z, 3), "his steering point 3 m ahead")
	check(H.count("place") == 0, "the engine starts his walk without teleporting")
	H.up("W")
	local steered = H.count("steer")
	H.step(0.1)
	local hold = H.last("hold")
	check(H.count("steer") == steered, "no walk is steered once the keys are up")
	check(hold and hold[2] == man.id and near(hold[3], man.x) and near(hold[4], man.z), "with no key he holds his own spot")
end

T.focus_loss_halts_walking = function()
	general_on()
	H.down("W")
	H.step(1)
	H.focus = false
	H.step(0.2)
	check(H.count("uc:halt") >= 1, "losing focus halts")
	local orders = H.count("uc:goto_location")
	H.step(2)
	check(H.count("uc:goto_location") == orders, "no new order while unfocused")
end

T.focus_return_does_not_jump_the_camera = function()
	general_on()
	H.step(0.1)
	H.focus = false
	H.step(0.5)
	H.mouse = {500, 0} -- the cursor wandered while the game was in the background
	H.focus = true
	local before = H.count("look_begin")
	H.step(2 / 60)
	check(H.count("look_begin") == before + 1, "coming back parks the cursor again")
	check(near(H.E.rig.yaw, 0), "and the camera does not jump, yaw " .. H.E.rig.yaw)
end

-- the author, 2026-10-17: "smoothness of the camera turning". A frame's mouse step is whole pixels and comes in the
-- bursts the mouse's own rate sets: applied raw, the view turned in steps. It eases to where the mouse put it
T.mouse_turns_the_camera = function()
	general_on()
	H.step(0.1)
	H.mouse = {393, 50}
	H.step(1 / 60)
	local yaw, pitch = 393 * 0.004, 50 * 0.004
	check(H.E.rig.yaw > 0 and H.E.rig.yaw < yaw * 0.6, "eased: part of the turn in the first frame, " .. H.E.rig.yaw)
	check(H.E.rig.pitch > 0 and H.E.rig.pitch < pitch * 0.6, "and of the pitch, " .. H.E.rig.pitch)
	H.step(0.5)
	check(near(H.E.rig.yaw, yaw, 1e-3) and near(H.E.rig.pitch, pitch, 1e-3), "all of it soon after: 0.004 rad/px, "
		.. H.E.rig.yaw .. ", " .. H.E.rig.pitch)
	H.down("Middle mouse")
	H.step(0.1)
	check(not H.E.F.dragging, "the middle button frees the mouse")
end

T.turn_smoothing_off_turns_at_once = function()
	H.fresh({mct = {camera_smoothing = 0}})
	H.tap("F2")
	H.step(0.1)
	H.mouse = {393, 0}
	H.step(1 / 60)
	check(near(H.E.rig.yaw, 393 * 0.004, 1e-6), "0: the whole turn in one frame, " .. H.E.rig.yaw)
end

T.errors_switch_it_off_after_three = function()
	general_on()
	for _ = 1, 3 do
		H.units[1]._error = true
		H.step(1 / 60)
		H.units[1]._error = nil
		H.tap("F2")
	end
	check(H.E.disabled, "three errors disable it")
	check(H.last("subtitle")[2] == "derpy_tp_switched_off", "the player is told")
	H.tap("F2")
	check(not H.E.F.on, "F2 no longer starts it")
	check(H.logged("test: position() failed"), "the error is in the script log")
end

T.multiplayer_and_replays_do_nothing = function()
	for _, opts in ipairs({{mp = true}, {replay = true}}) do
		H.fresh(opts)
		H.tap("F2")
		check(H.count("disable_orders") == 0, "nothing starts")
		check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_multiplayer", "the player is told")
	end
end

T.needs_memreader = function()
	H.fresh({memreader = false})
	H.phase.Deployment()
	check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_needs_memreader", "the player is told at load")
	H.tap("F2")
	check(H.count("disable_orders") == 0, "nothing runs")
end

T.battle_end_stops_and_locks = function()
	general_on()
	H.phase.Complete()
	check(not H.E.F.on and H.last("disable_orders")[2] == false, "restored when the battle ends")
	H.tap("F2")
	check(not H.E.F.on, "and stays off")
end

T.unit_lost_stops = function()
	general_on()
	H.units[1]._routing = true
	H.step(1 / 60)
	check(not H.E.F.on, "a routing unit ends the session")
end

T.conflicts_are_logged_once = function()
	H.fresh({mct = {key_back = "W"}})
	H.tap("F2") H.tap("F2") H.tap("F2")
	local n = 0
	for _, l in ipairs(H.log) do if l:find("key W for back", 1, true) then n = n + 1 end end
	check(n == 1, "logged once, not per toggle: " .. n)
end

T.debug_logs_every_check = function()
	H.fresh({mct = {debug_log = true}})
	H.tap("F2")
	check(H.logged("anim true") and H.logged("wheel true"), "the platform checks are logged")
	check(H.logged("men check on wh_test_unit: true"), "the men check is logged")
end

T.men_check_fails_plays_the_regiment_whole = function()
	H.fresh({units = {{general = true}, {type = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", men = 20, x = 40,
		range = 160, ammo = 3960, men_ok = false}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.on and H.E.F.model == nil and not H.E.F.solo, "the regiment is played whole")
	check(H.units[2]._faw == false, "and holds its fire: it shoots when clicked (absolute control, 2026-10-15)")
	check(H.logged("regiments are played whole: test: men off"), "the failed check is logged")
end

-- one man is steered, held and guarded only through the mailbox (platform.lua): without its cave nothing on the battle
-- thread would act on him, and the script must not. It is asked again at each start: a cave refused because a thread
-- was in his update goes in at the next
T.no_mailbox_plays_the_regiment_whole_and_asks_again = function()
	H.fresh({features = {input = true, anim = true, wheel = true, mailbox = false},
		units = {{general = true}, {type = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", men = 20, x = 40, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.on and H.E.F.model == nil, "the regiment is played whole")
	check(H.logged("regiments are played whole: test: mailbox off"), "the reason is logged")
	H.tap("F2")
	H.features.mailbox = nil
	H.step(0.5)
	H.tap("F2")
	check(H.E.F.on and H.E.F.model ~= nil, "put in at the next start: one man")
end

T.wheel_fails_zoom_on_keys = function()
	H.fresh({features = {input = true, anim = true, wheel = false}})
	H.tap("F2")
	H.step(0.1)
	check(H.logged("zoom is on the keys only"), "the failed check is logged")
	H.down("+")
	H.step(0.5)
	check(H.E.rig.zoom < 1, "+ still zooms in, got " .. H.E.rig.zoom)
end

T.input_unreadable_says_memreader = function()
	H.fresh({features = {input = false}})
	H.phase.Deployment()
	check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_needs_memreader", "the player is told")
	check(H.logged("no keyboard or mouse"), "the reason is logged")
end

T.one_man_regiment_with_shots_holds_fire = function()
	H.fresh({units = {{general = true}, {type = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", men = 20, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.units[2]._faw == false, "the rest of the regiment holds fire")
	H.tap("F2")
	check(H.units[2]._faw == true, "F2 off gives it back")
end

local function playing(o, enemies)
	H.fresh({units = {{general = true}, o}, enemies = enemies})
	H.select(H.units[2])
	H.tap("F2")
	H.step(0.1)
	return H.units[2]
end

-- past the gap between two swings, whatever the setting (4 s by default)
local function past_swing_gap() H.step(H.E.S.swing_cooldown + 0.1) end

-- the author, 2026-10-17: "first person camera". V puts the eye at his head, a little ahead of his face, looking where the
-- mouse looks; V again goes back behind him
T.v_switches_to_first_person_and_back = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.step(1)
	local mx, my, mz = H.E.P.model_pos(H.E.F.model)
	check(H.eye.z < mz - 3, "behind him to begin with: " .. H.eye.z)
	H.tap("V") H.step(0.5)
	check(near(H.eye.x, mx, 0.01) and near(H.eye.y, my + 1.8 * 0.92, 0.01) and near(H.eye.z, mz + 0.35, 0.01),
		"at his head, ahead of his face: " .. H.eye.x .. "," .. H.eye.y .. "," .. H.eye.z)
	check(H.look.z > H.eye.z + 1 and near(H.look.x, H.eye.x, 0.01) and near(H.look.y, H.eye.y, 0.01), "looking level, ahead")
	set_view(math.rad(90))
	H.step(0.1)
	check(H.look.x > H.eye.x + 1 and near(H.eye.x, mx + 0.35, 0.01), "turning with the mouse, from his head")
	set_view(nil, 0.5) H.step(0.1)
	check(H.look.y < H.eye.y - 1, "the mouse down looks down: " .. H.look.y .. " from " .. H.eye.y)
	set_view(nil, 0)
	H.tap("V") H.step(2)
	check(H.eye.x < mx - 3, "V again: behind him once more, " .. H.eye.x)
end

-- the author, 2026-10-17: "the first person mode should work if the player scrolled to the lowest". Zoomed in as far as
-- it goes, the camera goes into his head; zoomed out again, it comes back out
T.zooming_in_all_the_way_goes_first_person = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local m = H.E.F.model
	H.wheel_notches = 2 H.step(0.5)
	check(not H.E.first_person and H.eye.z < m.z - 2, "two notches in: still behind him, " .. H.eye.z)
	H.wheel_notches = 20 H.step(0.5)
	check(H.E.first_person and near(H.eye.z, m.z + 0.35, 0.01), "the closest zoom: from his head, " .. H.eye.z)
	H.wheel_notches = 1 H.step(0.5)
	check(H.E.first_person, "scrolling in further stays there")
	H.wheel_notches = -1 H.step(1)
	check(not H.E.first_person and H.eye.z < m.z - 2, "a notch out: behind him again, " .. H.eye.z)
	H.down("+") H.step(2) H.up("+") H.step(0.5)
	check(H.E.first_person, "the zoom key in all the way does it too")
end

-- measured 2026-10-17 (probes/zz_tp_zoomsweep.lua): with the ground 0.4-0.7 m up behind a Hessmarine, the eye came in
-- along its boom to 0.2-0.3 m behind his head at every zoom under 0.9, so "the lowest" is where that happens
T.zooming_in_once_the_ground_brings_the_eye_in_goes_first_person = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local m, bank = H.E.F.model, 1.2
	H.ground = function(_, z) return z < m.z - 0.5 and bank or 0 end -- a bank behind him
	H.step(0.5)
	check(H.eye.z > m.z - 1 and not H.E.first_person, "the bank brings the eye in to his head, and that alone changes "
		.. "nothing: " .. H.eye.z)
	H.wheel_notches = 1 H.step(0.1)
	check(H.E.first_person and near(H.eye.z, m.z + 0.35, 0.01), "a notch in from there: first person, " .. H.eye.z)
	H.wheel_notches = -1 H.step(0.1)
	check(H.E.first_person, "a notch out with the bank still in the way stays first person: behind him is his head")
	bank = 0.7 -- the eye clears it at zoom 1 and not a notch in
	H.wheel_notches = -1 H.step(0.5)
	check(not H.E.first_person and H.eye.z < m.z - 2, "a notch out once it fits behind him: third person, " .. H.eye.z)
	H.wheel_notches = 1 H.step(0.1)
	check(not H.E.first_person and H.eye.z < m.z - 2, "a notch in that still fits: third person, " .. H.eye.z)
	H.wheel_notches = 1 H.step(0.02)
	check(H.E.first_person, "the notch in that would bring it to his head goes straight to first person")
	H.ground = function(_, z) return z < m.z - 0.5 and -2 or 0 end -- the ground falls away behind him
	H.wheel_notches = -20 H.step(0.1)
	check(not H.E.first_person, "zoomed out")
	H.wheel_notches = 20 H.step(0.1)
	check(H.E.first_person, "the eye fits behind him at the closest zoom here, and the closest is first person all the same")
	H.ground = nil
end

T.first_person_keeps_up_with_his_head = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("V") H.step(1)
	local m = H.E.F.model
	m.z = m.z + 1
	H.step(0.15)
	check(H.eye.z < m.z + 0.35 - 0.05, "between two of his position's steps (0.2 s apart, measured) it is still on the way: "
		.. H.eye.z)
	H.step(0.15) -- one step of his position behind, and no follow spring on top
	check(near(H.eye.z, m.z + 0.35, 0.01), "the eye is at his head 0.3 s after he moved: " .. H.eye.z .. " for " .. m.z + 0.35)
end

T.first_person_is_kept_and_looks_up_further = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("V") H.step(0.2)
	H.E.rig.look(0, -100000)
	check(near(H.E.rig.want_pitch, -1.2), "first person looks up to -1.2: " .. H.E.rig.want_pitch)
	H.tap("F2") H.step(0.2) H.tap("F2") H.step(0.5)
	local _, my = H.E.P.model_pos(H.E.F.model)
	check(near(H.eye.y, my + 1.8 * 0.92, 0.01), "F2 off and on keeps first person")
	H.E.rig.look(0, -100000)
	H.tap("V") H.step(0.2)
	check(H.E.rig.want_pitch >= -0.25, "third person clamps it back: " .. H.E.rig.want_pitch)
end

T.a_regiment_played_whole_stays_behind = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}, mct = {combat_one_man = false}})
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.tap("V") H.step(1)
	local q = H.units[2]:position()
	check(H.eye.z < q:get_z() - 3, "no man to look out of: the camera stays behind, " .. H.eye.z)
end

T.a_unit_of_one_sees_from_its_head = function()
	H.fresh({units = {{general = true, type = "wh_test_lord", men = 1}}})
	H.tap("F2") H.step(0.1)
	H.tap("V") H.step(0.5)
	local m = H.E.P.models(H.E.F.unit)[1]
	local _, my, mz = H.E.P.model_pos(m)
	check(near(H.eye.y, my + 1.8 * 0.92, 0.01) and near(H.eye.z, mz + 0.35, 0.01), "the lord's head: " .. H.eye.y .. ", " .. H.eye.z)
end

-- the author, 2026-10-14: "cursor is also clicking other units which should be prevented". Orders are off,
-- selection is not: a click on another unit selected it, and the portrait swapped to it.
T.clicking_another_unit_keeps_the_controlled_one_selected = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	H.select(H.units[1])
	H.step(0.1)
	check(H.selected == u, "the controlled unit is selected again")
	check(H.last("select_in_ui")[2] == u._id, "by selecting it in the UI")
end

-- the author, 2026-10-15: "there are alsop instances that the camera jumps one unit to another". Log: card 1010 clicked,
-- F2 took 1012, the unit before - the set kept from selection callbacks still held it. CA's helper runs them all from
-- one selection handler, which another script can take over, and then no callback comes. F2 asks the game
T.f2_takes_the_unit_the_game_has_selected = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}, {type = "wh_test_melee", men = 21, x = 80}}})
	H.select(H.units[2]) H.tap("F2") H.step(0.1) H.tap("F2") H.step(0.1)
	H.sel, H.selected = {[H.units[3]] = true}, H.units[3] -- the third clicked; no callback told
	H.tap("F2") H.step(0.1)
	check(H.E.F.unit == H.units[3], "the unit the game has selected: got the unit " .. H.E.F.unit._id)
	H.sel, H.selected = {[H.units[2]] = true}, H.units[2] -- in play, another clicked with no callback
	H.step(0.1)
	check(H.selected == H.units[3] and H.sel[H.units[3]] and not H.sel[H.units[2]], "his unit selected again")
end

T.shift_clicking_another_unit_drops_it_again = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	local g = H.units[1]
	H.sel[g] = true -- shift-clicked: added, his stays
	for _, cb in ipairs(H.selection_cbs) do if cb[1] == g then cb[2](g, true) end end
	local n = H.count("clear_selection")
	H.step(0.1)
	check(H.count("clear_selection") > n and H.selected == u, "only the controlled unit stays selected")
end

T.clicking_empty_ground_keeps_the_controlled_one_selected = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	H.select(nil)
	H.step(0.1)
	check(H.selected == u, "the controlled unit is selected again")
	local n = H.count("select_in_ui")
	H.step(0.5)
	check(H.count("select_in_ui") == n, "and left alone while it stays selected")
end

T.swing_plays_on_one_man_with_cooldown = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("Left mouse")
	local p = H.all("play")
	check(#p == 1 and p[1][2] == 2011 and p[1][3] == 454, "ATTACK_1 on the front man only")
	H.E.F.model.anim_end = H.game_ms + 100 H.step(0.3) -- a short clip: its hold is over, the cooldown is not
	H.tap("Left mouse")
	check(H.count("play") == 1, "no second swing inside the gap")
	past_swing_gap()
	H.tap("Left mouse")
	check(H.count("play") == 2 and H.last("play")[3] == 455, "then ATTACK_2")
end

T.swing_falls_back_to_an_attack_order = function()
	H.fresh({features = {input = true, anim = false, wheel = true}, enemies = {{z = 30, men = 10}}})
	H.tap("F2")
	H.step(0.6) -- clear of the start's halt
	H.tap("Left mouse")
	check(H.count("play") == 0, "no forged swing without the animation command")
	check(H.count("uc:attack_unit") == 1 and H.last("uc:attack_unit")[3] == H.enemies[1], "an attack order on the enemy ahead")
end

T.mounted_swings_use_rider_slots = function()
	local u = playing({type = "wh_test_mount", men = 1, slots = {[454] = true, [455] = true, [1901] = true, [1902] = true}})
	u._models[1].mount = {id = 999, slots = {[454] = true, [455] = true}}
	H.tap("Left mouse") past_swing_gap() H.tap("Left mouse")
	local p = H.all("play")
	check(#p == 2 and p[1][2] == 999 and p[2][2] == 999, "mounted swings play through the mount, which drives its rider")
	check(p[1][3] == 454 and p[2][3] == 455 and p[1][4] == nil, "mount ground attack events stay active without a second rider command")
	past_swing_gap() H.tap("Right mouse")
	check(H.last("play")[2] == 999 and H.last("play")[3] == 454, "missing rider variants fall back to a supported rider/mount pair")
end

T.flying_mount_swings_use_airborne_rider_slots = function()
	local u = playing({type = "wh_test_fly_mount", men = 2, flying = true, slots = {[454] = true, [1901] = true, [1941] = true}})
	for i, m in ipairs(u._models) do m.mount = {id = 990 + i, slots = {[454] = true, [494] = true}} end
	H.E.F.model = nil
	H.tap("Left mouse")
	local p = H.all("play")
	check(#p == 2 and p[1][2] == 991 and p[2][2] == 992 and p[1][3] == 494 and p[2][3] == 494, "each rider is driven by its mount's airborne attack")
	H.units[2]._flying = false past_swing_gap() H.tap("Left mouse")
	check(H.last("play")[3] == 454, "landing switches back to a ground mount attack")
end

T.rider_without_a_parent_keeps_its_own_clip = function()
	playing({type = "wh_test_rider", men = 1, slots = {[1901] = true}})
	H.tap("Left mouse")
	check(H.last("play")[3] == 1901 and H.last("play")[4] == 6, "a detached rider uses a full-body rider clip")
end

T.ground_fire_commits_one_shot = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.step(0.5) -- clear of the start's halt
	local halts = H.count("uc:halt")
	check(H.E.F.ranged, "a unit that can shoot starts in ranged mode")
	H.tap("Left mouse")
	check(H.count("uc:attack_location") == 1, "a click orders ground fire")
	H.step(1)
	check(H.count("uc:halt") == halts, "released early, the order stays until a shot leaves")
	u._ammo = 9
	H.step(1 / 60)
	check(H.count("uc:halt") == halts + 1, "the shot left: halted")
end

T.ground_fire_holds_while_held = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	local halts = H.count("uc:halt")
	H.down("Left mouse")
	H.step(3)
	u._ammo = 7
	H.step(1)
	check(H.count("uc:attack_location") == 1 and H.count("uc:halt") == halts, "held: the order stays, shots or not")
	H.up("Left mouse")
	H.step(1 / 60)
	check(H.count("uc:halt") == halts + 1, "released after a shot: halted")
end

T.ground_fire_turns_first = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.step(0.5) -- clear of the start's halt
	H.mouse = {393, 0} -- a quarter turn of the camera
	H.step(1 / 60)
	H.tap("Left mouse")
	check(H.count("uc:goto_location_angle_width") == 1, "turns to the aim first")
	check(H.count("uc:attack_location") == 0, "and does not fire outside its arc")
end

-- the author, 2026-10-17: "check artillery still bugging". Measured (probes/zz_tp_tank_fire.lua, the Tilean tank, an
-- enemy ahead and the aim 90 deg off): the turn began, then the tank swung back to the enemy it could already shoot -
-- the click had put fire at will on - and the fire key did nothing for 30 s. Fire at will waits for the fire order
T.ground_fire_turns_with_fire_at_will_off = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.step(0.5) -- clear of the start's halt
	H.mouse = {393, 0} -- a quarter turn of the camera
	H.step(1 / 60)
	H.tap("Left mouse") H.step(0.1)
	local faw = H.last("uc:fire_at_will")
	check(H.count("uc:goto_location_angle_width") == 1 and faw and faw[3] == false, "turning, fire at will still off: "
		.. tostring(faw and faw[3]))
	u._bearing = math.deg(H.E.rig.yaw) % 360 -- the turn done
	H.down("Left mouse") H.step(1)
	faw = H.last("uc:fire_at_will")
	check(H.count("uc:attack_location") == 1 and faw[3] == true, "facing the aim: the fire order, and fire at will on")
	H.up("Left mouse")
end

T.ground_fire_stops_on_focus_loss = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	local halts = H.count("uc:halt")
	H.down("Left mouse")
	H.step(0.5)
	H.focus = false
	u._ammo = 9
	H.step(0.1)
	check(H.count("uc:halt") == halts + 1, "unfocused with a shot gone: halted")
end

T.mode_switches_melee_and_ranged = function()
	playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.tap("Right mouse")
	check(not H.E.F.ranged, "right click: melee")
	H.tap("Right mouse")
	check(H.E.F.ranged, "and back to ranged")
end

T.crosshair_shows_in_ranged_mode_only = function()
	playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	local x = find_uicomponent(H.root, "derpy_tp_crosshair")
	check(x and x:Visible(), "ranged and aiming: the crosshair shows")
	check(not find_uicomponent(x, "bl_frame"):Visible(), "only the crosshair part")
	H.tap("Right mouse")
	check(not x:Visible(), "melee: hidden")
	H.tap("Right mouse")
	H.tap("F2")
	check(not x:Visible(), "F2 off: hidden")
end

local XBOW = "wh3_main_cth_inf_jade_warrior_crossbowmen_1"
-- how far p lies off the camera's ray, the line through the screen centre: the crosshair
local function off_crosshair(p)
	local R = H.E.rig
	local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
	local n = math.sqrt(dx * dx + dy * dy + dz * dz)
	dx, dy, dz = dx / n, dy / n, dz / n
	local wx, wy, wz = p.x - R.ex, p.y - R.ey, p.z - R.ez
	local cx, cy, cz = wy * dz - wz * dy, wz * dx - wx * dz, wx * dy - wy * dx
	return math.sqrt(cx * cx + cy * cy + cz * cz)
end

local function crossbowmen(extra)
	local o = {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}
	for k, val in pairs(extra or {}) do o[k] = val end
	return playing(o)
end

-- the author, 2026-10-14: "missing sound fx when firing". A scripted launch plays the projectile's sounds only;
-- the bang is the weapon's (audio_missile_weapon_types.fire_start_event), so the shot plays it once.
T.solo_shot_plays_the_weapons_fire_sound_once = function()
	crossbowmen({type = "wh3_main_cth_inf_iron_hail_gunners_0"})
	H.tap("Left mouse")
	H.step(1.5)
	local l, s = H.all("launch"), H.all("sound")
	check(#l == 3 and #s == 1, "three bullets, one bang: " .. #l .. " launches, " .. #s .. " sounds")
	check(s[1][2] == "Battle_Individual_Small_Arms_Hand_Cannon_Fire", "the hand cannon's own: " .. tostring(s[1][2]))
	check(s[1][3] == l[1][3], "played where the shot leaves")
	check(s[1][4] == false and s[1][5] == false, "a battle sound, not a cinematic or a voice")
end

T.solo_click_fires_one_shot = function()
	local u = crossbowmen()
	H.tap("Left mouse")
	H.step(1.5) -- 1 s raising to aim, then the bolt at the firing clip's start (its FIRE_POS is at 0)
	check(H.E.F.shot and H.E.F.shot.phase == "fire", "the bolt is off; the firing clip still runs his shot")
	local l = H.all("launch")
	check(#l == 1 and l[1][2] == "wh3_cth_crossbow_bolt", "one crossbow bolt")
	local _, my = H.E.P.model_pos(H.E.F.model)
	check(near(l[1][3].y, my + 1.06, 0.01), "from the crossbow, 1.06 m up (its FIRE_POS): " .. l[1][3].y)
	-- looking level the crosshair meets no ground in his 160 m: the bolt flies along it to his reach
	local mx, _, mz = H.E.P.model_pos(H.E.F.model)
	check(off_crosshair(l[1][4]) < 0.05 and near(math.sqrt((l[1][4].x - mx) ^ 2 + (l[1][4].z - mz) ^ 2), 160, 0.1),
		"along the crosshair to his reach: " .. off_crosshair(l[1][4]) .. " m off it")
	check(u._ammo == 3959, "one bolt off the regiment's ammo, got " .. u._ammo)
	local p = H.all("play")
	check(#p == 2 and p[1][2] == 2011 and p[1][3] == 1554 and p[2][3] == 1557, "he raised to aim; the firing animation is still playing")
	H.step(4)
	check(H.count("play") == 2 and H.E.F.shot == nil, "one click, one shot: a crossbow's next raise belongs to the next shot")
	check(H.count("uc:attack_location") == 0, "the regiment gets no fire order")
end

T.solo_hold_repeats_at_the_reload_pace = function()
	-- harness clips: aim 1 s, fire 4 s, reload 7 s, under the game's 13 s reload: shots at 1.3, 19.3, 37.3 s
	crossbowmen({reload_slot = 1564})
	H.down("Left mouse")
	H.step(7)
	check(H.count("launch") == 1, "still reloading: no timer-based repeat")
	H.step(19)
	check(H.count("launch") == 2, "held fire repeats once the reload time is over")
	H.step(18)
	check(H.count("launch") == 3, "and again a whole cycle later")
end

T.solo_click_during_reload_is_kept = function()
	crossbowmen()
	H.tap("Left mouse")
	H.step(1)
	H.tap("Left mouse")
	H.step(1)
	check(H.count("launch") == 1, "the second click waits for the reload")
	H.step(18)
	check(H.count("launch") == 2, "then fires")
end

-- the author, 2026-10-17: "some ranged units bypass the reload time" - every man with no RELOAD_1 (Hessmarine
-- Grenadiers, 7 s reload, shot every 2 s): his raise to aim was taken for his reload, so no clock held the next shot
T.solo_without_a_reload_clip_waits_the_game_reload = function()
	-- harness clips: aim 1 s, fire 4 s; the game's reload 13 s from the fire clip's end: shots at 1.3 and 19.3 s
	crossbowmen()
	H.down("Left mouse")
	H.step(17)
	check(H.count("launch") == 1, "his raise is no reload: one shot in 17 s, got " .. H.count("launch"))
	H.step(3)
	check(H.count("launch") == 2, "held fire repeats once the reload time is over")
end

-- fire held as a second session starts (seen 2026-10-17: "attempt to perform arithmetic on field 'ey'" in aim_point and
-- third person off with an error): the eye was the last session's, its height cleared, so the aim's "no eye yet" let it by
T.fire_held_as_a_session_starts_waits_for_the_camera = function()
	crossbowmen()
	H.tap("F2") H.step(0.2)
	H.down("Left mouse")
	H.tap("F2") H.step(0.5)
	check(H.E.F.on and not H.logged("error"), "on, no error: " .. tostring(H.E.F.on))
	H.step(2)
	check(H.count("launch") == 1, "and he shoots once the camera is there")
end

T.solo_waits_for_the_engine_reload_and_finishes_after_release = function()
	crossbowmen({reload_slot = 1564})
	H.down("Left mouse") H.step(5.5) -- aim 1 s, fire 4 s: reloading
	H.anim_hold = true
	H.step(20)
	check(H.count("launch") == 1, "an unfinished reload never becomes ready by elapsed time")
	H.up("Left mouse") H.anim_hold = false H.step(1)
	check(H.count("launch") == 1 and H.E.F.shot == nil, "released fire finishes reload without another shot")
end

-- the author, 2026-10-14: "not using the prefire animation first, then fire". 9.0 slot ids (AssetEditor's dlc24
-- list + 2): 1554 SHOOT_READY_TO_AIM_LEVEL, 1557 FIRE_LEVEL, 1564 RELOAD_1. A crossbow has no RELOAD_1: between
-- shots he raises to aim again, as in the game's own crossbow cycle, once the reload time is over.
T.solo_aims_fires_then_reloads = function()
	for _, case in ipairs({{nil, "1554/6 1557/0 1554/6 1557/0"}, {1564, "1554/6 1557/0 1564/6 1554/6 1557/0"}}) do
		crossbowmen(case[1] and {reload_slot = case[1]} or nil)
		H.down("Left mouse") H.step(20)
		local got = {}
		for i, c in ipairs(H.all("play")) do got[i] = c[3] .. "/" .. c[4] end
		local seq = table.concat(got, " ")
		check(seq:sub(1, #case[2]) == case[2], "aim, fire" .. (case[1] and ", reload" or "") .. ": got " .. seq)
	end
end

T.solo_queue_rejection_retries_without_a_projectile = function()
	crossbowmen()
	local play = H.P.play
	H.P.play = function() return false end
	H.down("Left mouse") H.step(1)
	check(H.count("launch") == 0 and H.E.F.shot_n == 0, "a gated animation queue fires nothing")
	H.P.play = play H.step(1.5)
	check(H.count("launch") == 1, "held fire retries when the queue opens")
end

T.solo_projectile_waits_for_the_animation_start = function()
	crossbowmen()
	H.P.anim_slot = function() return nil end
	H.down("Left mouse") H.step(2)
	check(H.count("launch") == 0, "an accepted queue request without a playing clip launches nothing")
end

T.solo_projectile_delay_uses_model_time = function()
	crossbowmen()
	H.E.D.fires[H.E.F.utype] = {{0.3}} -- a spawn into the clip (the jade crossbow's own is at 0)
	H.tap("Left mouse") H.step(1.1) -- past the 1 s raise to aim, inside the firing clip
	H.paused = true H.step(2)
	check(H.all("play")[2][3] == 1557 and H.count("launch") == 0, "pausing the firing clip pauses its release")
	H.paused = false H.step(0.5)
	check(H.count("launch") == 1, "unpausing completes the release")
end

T.solo_idle_animation_cannot_count_as_a_reload = function()
	crossbowmen({reload_slot = 1564})
	H.down("Left mouse") H.step(5.5)
	local man = H.E.F.model
	H.E.F.shot.started = false
	man.anim_slot, man.anim_end = 1439, nil
	H.step(10)
	-- round 25: an unstarted clip gives up after LOCK_WAIT, so he is not rooted; the reload's time still holds the shot
	check(H.count("launch") == 1 and H.E.F.ready_at > H.model_ms() / 1000, "an unplayed reload never counts as done")
end


T.solo_firing_keeps_facing_without_a_walk_command = function()
	crossbowmen()
	H.down("Left mouse") H.down("W") H.step(1)
	local n = H.count("steer")
	H.step(1)
	check(H.count("steer") == n and H.count("face") > 0, "movement cannot replace the firing animation")
end

T.solo_dead_man_launches_nothing = function()
	local u = crossbowmen()
	local man = H.E.F.model
	H.tap("Left mouse")
	man.alive = false
	H.step(0.5)
	check(H.count("launch") == 0 and u._ammo == 3960, "he died in his fire animation: no bolt, no ammo")
	check(H.E.F.model and H.E.F.model ~= man, "the next front-centre man took over")
end

-- a next man who cannot shoot alone is played all the same, in melee: never his regiment whole (the author, 2026-10-15,
-- of the hand-over to it: "it happens when switching to ranged", "it also triggers the whole battalion to shoot or throw")
T.a_next_man_who_cannot_shoot_alone_is_played_in_melee = function()
	local u = crossbowmen()
	local man = H.E.F.model
	for _, m in ipairs(u._models) do if m ~= man then m.slots = {[42] = true, [454] = true} end end -- no fire clip
	man.alive = false
	H.step(0.1)
	check(H.E.F.model ~= nil and H.E.F.model ~= man and not H.E.F.ranged, "the next man, in melee")
	local next_man = H.E.F.model
	H.tap("Right mouse") H.step(0.1)
	check(H.E.F.model == next_man and not H.E.F.ranged, "the mode key: still him, no ranged mode")
	check(H.count("uc:attack_location") == 0, "the regiment is never ordered to fire")
end

T.solo_ammo_runs_out = function()
	local u = crossbowmen({ammo = 1, start_ammo = 22})
	H.down("Left mouse")
	H.step(10)
	check(H.count("launch") == 1 and u._ammo == 0, "one bolt, then empty")
	check(H.E.F.ranged, "still in ranged mode")
end

T.solo_iron_hail_fires_three = function()
	playing({type = "wh3_main_cth_inf_iron_hail_gunners_0", men = 21, x = 40, range = 90, ammo = 3960})
	H.tap("Left mouse")
	H.step(1.5)
	check(H.count("launch") == 3, "projectile_number 3")
end

T.a_shooter_without_a_reload_clip_still_shoots_alone = function()
	H.fresh({units = {{general = true}, {type = XBOW, men = 21, range = 160, ammo = 3960}}})
	H.P.reload_slot = function() return nil end
	H.select(H.units[2]) H.tap("F2")
	check(H.E.F.model ~= nil and H.E.F.solo and H.E.F.ranged, "no reload clip: one man, his reload on the clock")
end

T.error_restores_everything = function()
	H.fresh({units = {{general = true}, {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	H.tap("F2")
	H.step(0.1)
	local x = find_uicomponent(H.root, "derpy_tp_crosshair")
	check(x and x:Visible() and H.units[2]._faw == false, "playing: crosshair up, the regiment holding fire")
	H.E.rig.update = function() error("test: rig failed") end
	H.step(1 / 60)
	check(not H.E.F.on, "stopped")
	check(H.last("disable_orders")[2] == false and H.last("camera_functions")[3] == true, "orders and camera back")
	check(H.units[2]._faw == true, "fire at will back")
	check(not x:Visible(), "crosshair hidden")
	local c = H.last("cinematic_ui")
	check(c[2] == false and c[3] == true, "interface and cursor shown")
end

-- the author, 2026-10-14, choosing yesterday's look: cinematic UI while looking hides CA's whole interface,
-- the selection markers, flags and panels with it; the pack draws what it needs itself
-- the author, 2026-10-14: "the flag is still up in cinematic mode". The engine's interface switch brings the
-- unit flags back (CA's cutscenes switch them off only after it), so they go off again after every switch.
T.flags_stay_off_across_interface_switches = function()
	local function last_after_switch()
		local ci, bi
		for i, c in ipairs(H.calls) do
			if c[1] == "cinematic_ui" then ci = i end
			if c[1] == "banners" then bi = i end
		end
		return ci and bi and bi > ci and H.calls[bi][2] == false
	end
	general_on()
	H.step(0.1)
	check(last_after_switch(), "looking: flags off after the switch")
	H.down("Middle mouse") H.step(0.1)
	check(last_after_switch(), "mouse freed: flags still off after the switch")
	H.up("Middle mouse") H.step(0.1)
	check(last_after_switch(), "looking again: off again")
	H.tap("F2")
	check(H.last("banners")[2] == true, "third person off: flags back")
end

T.looking_hides_the_battle_interface = function()
	general_on()
	H.step(0.1)
	local c = H.last("cinematic_ui")
	check(H.E.F.dragging and c[2] == true and c[3] == false, "looking: cinematic UI on, no cursor")
	local n = H.count("cinematic_ui")
	H.step(0.5)
	check(H.count("cinematic_ui") == n, "switched on change only, not every frame")
	H.down("Middle mouse") H.step(0.1)
	c = H.last("cinematic_ui")
	check(c[2] == false and c[3] == true, "the freed mouse brings the interface and cursor back")
	H.up("Middle mouse") H.step(0.1)
	check(H.last("cinematic_ui")[2] == true, "looking again hides it")
	H.tap("F2")
	c = H.last("cinematic_ui")
	check(c[2] == false and c[3] == true, "third person off: interface back")
end

-- the author, 2026-10-14: "absolute control of the unit and no auto attack": played whole, it still holds its fire
T.solo_regiment_down_to_one_still_holds_fire = function()
	local u = crossbowmen({men = 2})
	check(u._faw == false, "holding fire")
	H.E.F.model.alive = false
	H.step(1 / 60)
	check(u._faw == false, "one man left: played whole, and still no shot he did not ask for")
	check(H.E.F.model == nil and not H.E.F.solo, "played as a single entity")
end

-- the author, 2026-10-14: "no option to go to ground as a flying unit". No script call lands a flyer
-- (change_behaviour_active lists none); the game's own control is the HUD's Toggle flying button
-- (uied_component_texts: "When turned off, flying units will land and stay on the ground").
T.fly_key_presses_the_games_toggle_flying_button = function()
	general_on()
	H.step(0.1)
	H.comp("button_toggle_flying", H.comp("porthole_parent", find_uicomponent(H.root, "hud_battle")))
	H.tap("Space")
	check(H.count("click") == 1 and H.last("click")[2] == "button_toggle_flying", "Space presses Toggle flying once")
end

T.fly_key_without_the_button_says_so_once = function()
	general_on()
	H.step(0.1)
	H.tap("Space") H.tap("Space")
	check(H.count("click") == 0, "nothing to press")
	local n = 0
	for _, l in ipairs(H.log) do if l:find("Toggle flying", 1, true) then n = n + 1 end end
	check(n == 1, "logged once, got " .. n)
end

-- the author, 2026-10-14: the unit hover panel (SpecialTooltip > tooltip, per CA's battle_fundamentals_tour)
-- shows over the battlefield in third person. The battle interface's own switch turns tooltips off.
T.third_person_switches_tooltips_off_and_back = function()
	general_on()
	check(H.last("tooltips") and H.last("tooltips")[2] == false, "no hover panels in third person")
	H.tap("F2")
	check(H.last("tooltips")[2] == true, "hover panels come back after it")
end

-- the unit banners (the flags floating over every unit) hung over his head in the sky
T.third_person_switches_banners_off_and_back = function()
	general_on()
	check(H.last("banners") and H.last("banners")[2] == false, "no unit banners in third person")
	H.tap("F2")
	check(H.last("banners")[2] == true, "banners come back after it")
end

-- the author, 2026-10-14: "unit voicelines being played a lot when moving". Every start and stop of his walk is
-- a change of state the game voices; CA's cutscenes silence the same ambient unit voices.
T.third_person_silences_unit_voices_and_back = function()
	general_on()
	check(H.last("voices_off") and H.last("voices_off")[2] == true, "no unit voices in third person")
	H.tap("F2")
	check(H.last("voices_off")[2] == false, "unit voices come back after it")
end

local function a_battery()
	local u = playing({type = "wh_test_cannon", men = 20, x = 40, range = 400, ammo = 100, arty = true})
	local hud = find_uicomponent(H.root, "hud_battle") -- the harness makes it, with the unit cards
	local port = H.comp("porthole_parent", hud)
	H.comp("button_unit_manual_fire", port)
	return u
end

T.artillery_mode_opens_manual_fire = function()
	local u = a_battery()
	check(not H.E.F.ranged, "artillery does not start in ranged mode")
	H.tap("Right mouse")
	check(not H.E.F.on, "control steps aside")
	check(H.last("select_in_ui")[2] == u._id, "the battery is selected, so the HUD carries its button")
	H.step(1.1)
	check(H.last("click") and H.last("click")[2] == "button_unit_manual_fire", "the button is clicked")
	local fp = H.comp("first_person_ui", H.root)
	H.step(0.2)
	fp:SetVisible(false)
	H.step(0.2)
	check(H.E.F.on and H.E.F.unit == u, "the game closed it: control comes back")
end

T.f2_leaves_manual_fire = function()
	a_battery()
	H.tap("Right mouse")
	H.step(1.1)
	H.comp("first_person_ui", H.root)
	H.step(0.2)
	H.tap("F2")
	H.step(0.5)
	check(H.count("click") == 2, "F2 clicks the button again a beat later")
	check(H.E.F.on, "and control comes back")
end

-- measured 2026-10-17 (probes/zz_tp_manual.lua, a Culverin): clicked 0.1-0.3 s after third person's stop, the
-- first-person view closed again within 1.2 s, or never opened; 0.5, 1 and 2 s after, it held
T.manual_fire_waits_for_the_game_to_settle = function()
	a_battery()
	H.tap("Right mouse")
	H.step(0.8)
	check(H.count("click") == 0, "no click while what third person put back is still settling")
	H.step(0.3)
	check(H.count("click") == 1, "clicked a second after the key")
end

T.manual_fire_without_a_button_gives_control_back = function()
	playing({type = "wh_test_cannon", men = 20, x = 40, range = 400, ammo = 100, arty = true})
	H.tap("Right mouse")
	H.step(3.5)
	check(H.count("click") == 0 and H.E.F.on, "no button: back in control after 3 s")
	check(H.logged("no Manual fire button"), "and the reason is logged")
end

local BARRAGE, FIREBALL = "wh2_dlc09_army_abilities_barrage_of_the_legion", "wh_main_spell_fire_fireball"
-- an aimed ability arms on its key and goes off on the left click (the author, 2026-10-14)
local function cast_key(k) H.tap(k) H.step(1 / 60) H.tap("Left mouse") H.step(1 / 60) end

T.ability_ground_lands_on_the_crosshair = function()
	H.fresh({units = {{general = true, abilities = {BARRAGE}}}})
	H.tap("F2")
	H.step(0.1)
	cast_key("1")
	local c = H.last("uc:perform_special_ability_ground")
	check(c and c[3] == BARRAGE, "cast on the ground")
	check(c[4].z > 30 and c[4].z < 40 and near(c[4].x, 0, 0.01), "where the view meets the ground, ~37 m ahead: " .. c[4].z)
end

T.ability_enemy_goes_to_the_unit_on_the_ray = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}}}, enemies = {{x = 30, z = 50}, {x = 0, z = 50}}})
	H.tap("F2")
	H.step(0.1)
	cast_key("1")
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == FIREBALL and c[4] == H.enemies[2], "the enemy straight ahead, not the one 30 m aside")
end

T.ability_unknown_kind_casts_on_self = function()
	H.fresh({units = {{general = true, abilities = {"wh_test_modded_ability"}}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == "wh_test_modded_ability" and c[4] == H.units[1], "explicit self target required by the live engine")
end

T.ability_refused_or_missing_does_nothing = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}, can = {[FIREBALL] = false}}}, enemies = {{z = 50}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	check(H.E.F.armed == nil, "an ability that cannot go off now does not arm")
	H.tap("2")
	H.tap("Left mouse")
	check(H.count("uc:perform_special_ability") == 0 and H.count("uc:perform_special_ability_ground") == 0, "nothing cast")
end

-- the unit's own context answers how an ability aims (measured 2026-10-14), so a modded ability data.lua has never
-- seen aims right; flags as the record carries them
local MOD = "wh_test_modded_ability"
local function aims(flags)
	local t = H.default_cco()
	t["BattleAbilityList.Size"] = 1
	local at = "BattleAbilityList.At(0).SetupAbilityContext."
	t[at .. "RecordKey"] = MOD
	t[at .. "IconPath"] = "ui/battle ui/ability_icons/test.png"
	t["BattleAbilityList.At(0).RechargeTimeRemainingSecs"] = 0
	t["BattleAbilityList.At(0).IsActive"], t["BattleAbilityList.At(0).ActiveTimeRemainingSecs"] = false, 0
	t["BattleAbilityList.At(0).WindUpTimeRemainingSecs"] = -1
	for _, f in ipairs({"TargetGround", "TargetGroundUnderEnemies", "TargetGroundUnderAllies", "TargetEnemies",
		"TargetFriends", "TargetSelf"}) do
		t[at .. "UnitSpecialAbilityRecordContext." .. f] = flags[f] == true
	end
	return t
end
local ability_record = aims -- a later local aims counts aim animations
local function cast_mod(flags, o)
	o = o or {}
	H.fresh({units = {{general = true, abilities = {MOD}}, o.ally}, enemies = o.enemies})
	H.cco = aims(flags)
	H.tap("F2")
	H.step(0.1)
	local aimed = flags.TargetGround or flags.TargetGroundUnderEnemies or flags.TargetGroundUnderAllies
		or flags.TargetEnemies or flags.TargetFriends
	if aimed then cast_key("1") else H.tap("1") end
end

T.a_modded_ability_aims_by_its_own_record = function()
	cast_mod({TargetEnemies = true}, {enemies = {{x = 0, z = 50}}})
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == MOD and c[4] == H.enemies[1], "the record says enemies: the enemy on the crosshair")
	cast_mod({TargetGroundUnderEnemies = true})
	check(H.last("uc:perform_special_ability_ground"), "ground under enemies is a ground cast")
end

T.an_ability_that_targets_nothing_is_activated_through_its_context = function()
	cast_mod({})
	check(H.count("uc:perform_special_ability") == 0, "no unit order: the engine refuses one with any target")
	local c = H.last("cco_cmd")
	check(c and c[2] == "CcoBattleUnit" and c[4] == "BattleAbilityList.At(0).PerformAbilityForOwner",
		"activated for its owner, on the battle ability (measured: on SetupAbilityContext it does nothing)")
	-- seen in game 2026-10-14: releasing a controller that gave no order let the tank resume its last move
	local after = false
	for _, call in ipairs(H.calls) do
		if call == c then after = true elseif after and call[1] == "uc:release_control" then after = "released" end
	end
	check(after == true, "no controller hand-back after the activation")
end

-- a transformation replaces his unit with another (the Deithland Pyretitans' ammo modes; the author, 2026-10-17: "change
-- ammunition units will disappear when the ability is pressed"): third person ends, everything put back on the unit
-- while it is there, and only then does it go off, as CA's button sends it
T.a_transformation_ends_third_person_before_it_goes_off = function()
	H.fresh({units = {{general = true, abilities = {MOD}}}})
	H.cco = ability_record({})
	local was = H.E.D.abilities[MOD]
	H.E.D.abilities[MOD] = "transform"
	H.tap("F2") H.step(0.1)
	local ok, err = pcall(function()
		H.tap("1") H.step(0.1)
		check(not H.E.F.on, "third person is off")
		local stop, cast
		for i, call in ipairs(H.calls) do
			if call[1] == "disable_orders" and call[2] == false then stop = stop or i end
			if call[1] == "cco_cmd" and call[4] == "BattleAbilityList.At(0).PerformAbilityForOwner" then cast = cast or i end
		end
		check(stop and cast and stop < cast, "the stop's put-backs, then the cast: stop at " .. tostring(stop) .. ", cast at " .. tostring(cast))
		local touched = {}
		for i = cast or #H.calls + 1, #H.calls do
			local c = H.calls[i][1]
			if c == "steer" or c == "guard" or c == "hold" or c == "face" or c == "place" or c == "play" or c == "disarm" then touched[#touched + 1] = c end
		end
		check(#touched == 0, "nothing more on the old unit's man that frame or after: " .. table.concat(touched, " "))
		check(H.count("uc:perform_special_ability") == 0, "no unit order: the context's activation, as CA's button")
	end)
	H.E.D.abilities[MOD] = was
	assert(ok, err)
end

-- and he plays on as the new form (the author, 2026-10-17: "seems to deactivate f2 when changing ammo"). The harness's
-- swap comes in the cast; measured in game, Deithland's mortar was back 0.2 s after it under a ui id of its own
local function swapping(after)
	-- another regiment, its card there from the start: a unit in the army at the cast is no new form
	H.fresh({units = {{general = true, abilities = {MOD}}, {type = "wh_test_unit", men = 10, x = 30}}})
	H.cco = ability_record({})
	local was, cmd, new = H.E.D.abilities[MOD], common.call_context_command, nil
	H.E.D.abilities[MOD] = "transform"
	common.call_context_command = function(...)
		cmd(...)
		if after then table.remove(H.units, 1) new = H.unit({general = true, type = "wh_test_new_form"}) end
	end
	H.tap("F2") H.step(0.1)
	H.tap("1")
	return function() H.E.D.abilities[MOD], common.call_context_command = was, cmd end, function() return new end
end

-- in game the new form came a frame before its unit card (2026-10-17: taken over at once, "HUD part portrait is off: no
-- unit context for this unit", and the slots with it, for the rest of the battle): he waits for the card
T.a_transformation_plays_on_as_its_new_form = function()
	local undo, new = swapping(true)
	local ok, err = pcall(function()
		H.step(0.2)
		check(new() and not H.E.F.on, "the new form has no card yet: not taken over")
		local u = new()
		H.comp(tostring(u._id), find_uicomponent(H.root, "cards_panel")).cco = "cco_" .. u._id
		H.step(0.1)
		check(H.E.F.on and H.E.F.unit == u, "its card is there: on again, as the new form: " .. tostring(H.E.F.unit and H.E.F.unit:type()))
		check(not H.logged("is off"), "no HUD part switched off")
		H.tap("F2") H.step(0.2)
		check(not H.E.F.on, "F2 leaves it as ever: nothing more is waited for")
	end)
	undo()
	assert(ok, err)
end

T.a_transformation_that_never_comes_leaves_third_person_off = function()
	local undo = swapping(false)
	local ok, err = pcall(function()
		H.step(11)
		local late = H.unit({general = true, type = "wh_test_late_unit"}) -- a reinforcement past the wait is no new form
		H.comp(tostring(late._id), find_uicomponent(H.root, "cards_panel")).cco = "cco_" .. late._id
		H.step(0.2)
		check(not H.E.F.on, "off: nothing came in the wait, and a later unit is not taken for it")
	end)
	undo()
	assert(ok, err)
end

T.an_untargeted_ability_without_a_context_falls_back_to_the_unit_order = function()
	local RALLY = "wh2_dlc09_character_abilities_tomb_king_rally" -- data.lua: none
	H.fresh({units = {{general = true, abilities = {RALLY}}}})
	H.tap("F2") H.step(0.1) H.tap("1")
	local c = H.last("uc:perform_special_ability")
	check(H.count("cco_cmd") == 0 and c and c[3] == RALLY and c[4] == H.units[1], "no context: cast on himself")
	H.fresh({units = {{general = true, abilities = {RALLY}}}})
	local t = aims({})
	for k in pairs(t) do if k:find("UnitSpecialAbilityRecordContext", 1, true) then t[k] = nil end end
	t["BattleAbilityList.At(0).SetupAbilityContext.RecordKey"] = RALLY
	H.cco = t
	H.tap("F2") H.step(0.1) H.tap("1")
	c = H.last("cco_cmd")
	check(c and c[4] == "BattleAbilityList.At(0).PerformAbilityForOwner",
		"a context without target flags: data.lua's none, activated for its owner")
end

T.an_ally_ability_goes_to_the_ally_on_the_crosshair_else_himself = function()
	cast_mod({TargetFriends = true, TargetSelf = true}, {ally = {x = 10, z = 60}})
	local c = H.last("uc:perform_special_ability")
	check(c and c[4] == H.units[2], "the ally ahead, not the caster standing nearer the ray")
	cast_mod({TargetFriends = true, TargetSelf = true})
	c = H.last("uc:perform_special_ability")
	check(c and c[4] == H.units[1], "no ally ahead: himself")
end

-- seen in game 2026-10-14: the engine refused a cast three times and the three errors switched third person off
T.a_cast_the_game_refuses_is_logged_by_name_not_counted = function()
	H.fresh({units = {{general = true, abilities = {"wh_test_modded_ability"}}}})
	H.refuse_cast = {wh_test_modded_ability = true}
	H.tap("F2")
	H.step(0.1)
	for _ = 1, 3 do H.tap("1") H.step(0.1) end
	H.refuse_cast = nil
	check(H.E.F.on and not H.E.disabled, "third person still on after three refused casts")
	check(H.logged("the game refused wh_test_modded_ability"), "the refusal names the ability")
end

T.ability_key_n_casts_slot_n = function()
	H.fresh({units = {{general = true, abilities = {BARRAGE, "wh_test_modded_ability"}}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("2")
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == "wh_test_modded_ability", "key 2 casts the second ability")
	check(H.count("uc:perform_special_ability_ground") == 0, "not the first")
end

T.ability_ignores_units_behind_the_camera = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}}}, enemies = {{x = 10, z = 50}, {x = 0, z = -30}}})
	H.tap("F2")
	H.step(0.1)
	cast_key("1")
	local c = H.last("uc:perform_special_ability")
	check(c and c[4] == H.enemies[1], "the enemy ahead, not the one behind the camera on the ray's line")
end

-- final review fix pass (2026-10-13): one test per finding ----------------------------------------------

T.toggle_loads_no_files = function()
	H.fresh()
	H.block_loads = true -- the bridge puts loadfile back once the entry has run
	H.tap("F2")
	H.block_loads = false
	check(H.E.F.on and H.E.strikes == 0, "F2 starts with no file loaded, strikes " .. H.E.strikes)
end

T.solo_others_die_still_holds_fire = function()
	local u = crossbowmen({men = 2})
	for _, m in ipairs(u._models) do if m ~= H.E.F.model then m.alive = false end end
	H.step(1 / 60)
	check(u._faw == false, "he is the last man: played whole, still holding fire")
	H.tap("F2")
	check(u._faw == true, "third person off: fire at will back")
	check(H.E.F.model == nil and not H.E.F.solo, "played as a single entity")
end

T.stop_restores_past_a_failing_step = function()
	local u = crossbowmen()
	H.E.move.halt = function() error("test: halt failed") end
	H.tap("F2")
	check(not H.E.F.on, "stopped")
	check(H.last("disable_orders")[2] == false and H.last("camera_functions")[3] == true, "orders and camera back")
	check(u._faw == true, "fire at will back")
end

T.start_error_gives_fire_back = function()
	H.fresh({units = {{general = true}, {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	local real = bm.disable_orders
	bm.disable_orders = function(self, b) if b then error("test: disable_orders failed") end real(self, b) end
	H.tap("F2")
	check(H.units[2]._faw ~= false, "the regiment keeps its fire")
end

T.pause_holds_the_one_man = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2])
	H.tap("F2")
	H.paused = true
	H.step(1) -- a pause is noticed once model time has stood still for half a second
	local steers = H.count("steer")
	H.down("W")
	H.step(3)
	check(H.count("steer") == steers, "paused: no engine steering")
	H.paused = false
	H.step(1)
	check(H.count("steer") > steers, "unpaused: engine steering resumes")
end

T.pause_holds_fire = function()
	crossbowmen()
	H.paused = true
	H.step(1) -- a pause is noticed once model time has stood still for half a second
	H.down("Left mouse")
	H.step(5)
	check(H.count("launch") == 0 and H.count("play") == 0, "paused: no shot, no animation")
	H.paused = false
	H.step(1.5)
	check(H.count("launch") == 1, "unpaused and still held: he shoots")
end

-- the author, 2026-10-16: "battalion actions also affect the unit which shouldnt be and its moving itself the unit
-- whenever the battalion is affected". The engine's own orders on the man played alone are stopped every frame the
-- battle runs: idle, and under a swing; never paused
T.the_man_played_alone_is_kept_from_the_engines_orders = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local man = H.E.F.model
	local n = H.count("guard")
	H.step(1)
	check(man and H.count("guard") - n >= 55, "every frame: " .. H.count("guard") - n)
	check(H.last("guard")[2] == man.id, "on him")
	H.tap("Left mouse") H.step(0.1)
	n = H.count("guard")
	H.step(0.3)
	check(H.E.F.lock and H.count("guard") - n >= 15, "under a swing too: " .. H.count("guard") - n)
	H.paused = true
	H.step(1)
	n = H.count("guard")
	H.step(1)
	check(H.count("guard") == n, "paused: nothing")
end

T.a_regiment_played_whole_is_not_guarded = function()
	H.fresh({units = {{general = true, men = 20}}})
	H.P.features.steer = false
	H.tap("F2") H.step(1)
	check(H.E.F.on and H.E.F.model == nil and H.count("guard") == 0, "played whole: " .. H.count("guard"))
	check(H.count("disarm") == 0, "and not disarmed: " .. H.count("disarm"))
end

-- measured live 2026-10-16 (probes/zz_tp_auto_attack.lua, the High Elves 30 s in a lasting melee, nobody at the keys):
-- the stop above lands after the engine's swing has started, and the swing plays out - Tyrion swung 917 frames of
-- 1195, Calith 113 of 135. His fragment pointed at a copy with no attack clips: 0 and 0 (probes/zz_tp_mask_experiment.lua).
-- Disarmed every frame he is played; armed for his own swing until its clip is over, and at the end
T.the_man_played_alone_has_no_swing_but_his_own = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local man = H.E.F.model
	check(H.last("disarm") and H.last("disarm")[2] == man.id, "disarmed as he is taken")
	H.tap("Left mouse")
	check(H.last("arm") and H.last("arm")[2] == man.id, "his own swing arms him")
	local n = H.count("disarm")
	H.step(2)
	check(H.E.F.lock or H.E.F.swung, "the clip still under way")
	check(H.count("disarm") == n, "never disarmed under his own clip: " .. H.count("disarm") - n)
	H.step(3)
	check(not H.E.F.lock and not H.E.F.swung and H.count("disarm") > n, "disarmed again once it is over")
	H.step(2)
	H.tap("E") -- a jump attack: a lock, no swing kept past it
	n = H.count("disarm")
	H.step(0.5)
	check(H.E.F.lock and not H.E.F.swung and H.count("disarm") == n, "never disarmed under his jump")
	H.step(4)
	check(not H.E.F.lock and H.last("disarm")[2] == man.id, "disarmed again before the end")
	local a = H.count("arm")
	H.tap("F2")
	n = H.count("disarm")
	H.step(0.5)
	check(H.count("arm") > a and H.last("arm")[2] == man.id and H.count("disarm") == n, "armed at the end and left so")
end

-- the gate (a_queued_swing_beats_the_ticks_order) is in while a man is played alone, and only then
T.the_gate_is_in_while_a_man_is_played_alone = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	check(H.last("gate") and H.last("gate")[2] == true, "on as he is taken")
	H.tap("F2") H.step(0.5)
	check(H.last("gate")[2] == false, "off at the end")
	local n = H.count("gate")
	H.tap("F2") H.step(0.5)
	check(H.E.F.on and H.count("gate") == n + 1, "on again with the next start")
	H.fresh({units = {{general = true, men = 20}}})
	H.P.features.steer = false
	H.tap("F2") H.step(0.5)
	check(H.E.F.on and H.E.F.model == nil and H.count("gate") == 0, "a regiment played whole leaves the game's own")
	H.tap("F2") H.step(0.5)
	check(H.count("gate") == 0, "and its stop too")
end

-- a unit of one played whole: CA's attack order is his swing
T.a_single_entitys_attack_order_arms_him = function()
	H.fresh({features = {input = true, anim = false, wheel = true}, enemies = {{z = 30, men = 10}}})
	H.tap("F2") H.step(0.6)
	local man = H.units[1]._models[1]
	check(H.last("disarm") and H.last("disarm")[2] == man.id, "disarmed while nothing is ordered")
	H.tap("Left mouse") H.step(0.1)
	check(H.E.F.native_attack and H.last("arm") and H.last("arm")[2] == man.id, "armed for his attack order")
	local n = H.count("disarm")
	H.step(1)
	check(H.count("disarm") == n, "and kept so")
end

-- nothing is written to a dead man (his model may be gone); the next man is disarmed
T.the_next_man_is_disarmed_and_the_dead_left_alone = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local man = H.E.F.model
	man.hp = 0
	H.step(0.1)
	local now = H.E.F.model
	check(now and now ~= man and H.last("disarm")[2] == now.id, "the next man disarmed")
	H.tap("F2") H.step(0.1)
	for _, c in ipairs(H.all("arm")) do check(c[2] ~= man.id, "nothing written to the dead man") end
	check(H.last("arm") and H.last("arm")[2] == now.id, "the next man armed at the end")
	H.fresh() H.tap("F2") H.step(0.1)
	local lord = H.units[1]._models[1]
	check(H.last("disarm")[2] == lord.id, "a unit of one disarmed")
	lord.hp = 0
	H.step(0.1)
	check(not H.E.F.on and H.count("arm") == 0, "dead, he is left alone")
end

-- measured live 2026-10-16 (probes/zz_tp_melee_spam.lua, Teutogen Guard in a real melee, the key every 0.25 s): of 10
-- swings sent, 3 never played - each sent while he blocked (DEFEND_1/2, 474/475, under the engine's defend command 3ae2de8),
-- which holds a queued clip back until the block ends. The lock gave up after LOCK_WAIT, he was disarmed, and the swing
-- found no clip when the block ended (the author: "spamming melee button when near enemy still doesnt work"). Armed until
-- it has played, LOCK_MAX at most: 8 of 10 played, the other replaced by the next click's
T.a_swing_held_back_by_a_block_still_plays = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local man = H.E.F.model
	H.report_ms = 1500 -- held back 1.5 s, past LOCK_WAIT
	H.tap("Left mouse")
	H.step(1.2)
	check(not H.E.F.lock, "the lock gave up: he is free to move")
	local n = H.count("disarm")
	H.step(0.5)
	check(H.E.P.anim_slot(man) == 454, "the swing plays")
	H.step(2) -- 3.7 s: the 4 s clip still playing, past LOCK_MAX
	check(H.E.P.anim_slot(man) == 454, "still playing")
	check(H.count("disarm") == n, "never disarmed while it waited or played: " .. H.count("disarm") - n)
	H.step(2)
	check(H.count("disarm") > n, "disarmed once it is over")
end

T.a_swing_that_never_plays_gives_him_back_after_lock_max = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.report_ms = 60000 -- never
	H.tap("Left mouse")
	H.step(2.5)
	local n = H.count("disarm")
	H.step(0.3)
	check(H.count("disarm") == n, "still armed 2.8 s after the send")
	H.step(0.5)
	check(H.count("disarm") > n, "disarmed past LOCK_MAX")
end

-- the author, 2026-10-15: "the unit being controlled bugs out and will not respond if near an enemy". The recorder: W let
-- go and pressed again 0.4 s later; the walk order went out and the engine kept him ordered to his own spot, idle, for as
-- long as W was held. It drops an order within 0.5 s of the one before (the halt), and nothing sent it again
-- (round 25: every order the script sends now waits STEER_GAP, so the drop is the engine's own - an order the script did
-- not send, or a window wider than the 0.5 s measured)
T.a_walk_order_the_engine_dropped_is_sent_again = function()
	general_on()
	H.step(1)
	H.E.F.unit._order_t = H.T -- an order the script never saw, just now
	H.down("W") H.step(2)
	local u = H.E.F.unit
	check(H.count("dropped_order") >= 1, "the walk after the halt was dropped")
	check(u:ordered_position():get_z() > u:position():get_z() + 10, "he is ordered on, not left where he stood: ordered z "
		.. u:ordered_position():get_z())
end

T.walking_orders_keep_half_a_second_apart = function()
	general_on()
	H.step(0.5) -- clear of the start's halt: an order inside 0.5 s of it is dropped
	H.down("W")
	H.step(0.1)
	H.down("D") H.step(0.1) H.up("D") H.step(0.1) H.down("A") H.step(0.1) H.up("A") H.step(0.1)
	check(H.count("uc:goto_location") == 1, "key changes inside 0.5 s give no new order, got " .. H.count("uc:goto_location"))
	H.down("D")
	H.step(0.6)
	check(H.count("uc:goto_location") == 2, "the new direction is ordered once the gap has passed")
end

T.mode_leaves_ranged_without_ammo = function()
	local u = crossbowmen({ammo = 1, start_ammo = 22})
	H.tap("Left mouse")
	H.step(1.5)
	check(u._ammo == 0 and H.E.F.ranged, "out of ammo, still aiming")
	H.tap("Right mouse")
	check(not H.E.F.ranged, "the mode key still leaves ranged mode")
end

T.throwing_checks_fall_back_without_a_strike = function()
	H.fresh({units = {{general = true}, {type = XBOW, men = 20, x = 40, range = 160, ammo = 3960}}})
	H.P.check_anim = function() error("test: anim check threw") end
	H.P.open_wheel = function() error("test: wheel check threw") end
	H.P.check_men = function() error("test: men check threw") end
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.on and H.E.strikes == 0, "it starts, and a check that throws is not an error")
	check(H.E.F.model == nil and not H.E.P.features.anim, "the regiment is played whole, swings become orders")
	check(H.logged("anim check threw") and H.logged("men check threw") and H.logged("wheel check threw"), "each reason logged")
end

T.one_man_never_nudges_through_a_wall = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2])
	H.tap("F2")
	H.down("W")
	H.step(1)
	check(H.count("place") == 0, "no initial position shove")
	H.step(4) -- the fake steer never moves him, as a wall would not
	check(H.count("place") == 0, "a blocked engine walk never shoves him through a wall")
	H.up("W") H.step(0.1) H.down("W") H.step(0.1)
	check(H.count("place") == 0, "a new press still uses engine movement")
end

T.needs_memreader_said_after_loading = function()
	H.fresh({memreader = false})
	check(H.count("subtitle") == 0, "nothing during the loading screen")
	H.phase.Deployment()
	check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_needs_memreader", "told once the battle shows")
	H.phase.Deployed()
	check(H.count("subtitle") == 1, "and only once")
end

T.picks_a_unit_added_mid_battle = function()
	H.fresh()
	local summoned = H.unit({type = "wh_test_summoned", x = 20})
	H.step(2) -- new units are noticed within a second or two
	H.select(summoned)
	H.tap("F2")
	check(H.E.F.unit == summoned, "the summoned unit, not the general")
end

T.error_in_a_shot_still_hides_its_message = function()
	crossbowmen()
	H.E.strikes = 2
	bm.trigger_projectile_launch = function() error("test: launch failed") end
	H.tap("Left mouse")
	H.step(8)
	check(H.E.disabled, "the third error switched it off")
	check(H.count("hide_subtitles") >= 1, "and its message went away")
end

T.solo_ammo_never_goes_negative = function()
	local u = crossbowmen({ammo = 1, start_ammo = 22})
	H.tap("Left mouse")
	u._ammo = 0 -- spent between his fire animation and the launch
	H.step(0.5)
	check(u._ammo == 0, "ammo stays at 0, got " .. u._ammo)
end

T.solo_dead_man_launches_nothing_before_the_frame_sees_it = function()
	local u = crossbowmen()
	H.E.D.fires[H.E.F.utype] = {{0.3}} -- a spawn into the clip (the jade crossbow's own is at 0)
	H.tap("Left mouse") H.step(1.1) -- past the 1 s raise to aim, inside the firing clip, before its release
	check(H.E.F.shot.phase == "fire" and H.count("launch") == 0, "firing, not yet released")
	H.timers["derpy_tp"] = nil -- exercise combat without the frame's model replacement
	H.E.F.model.alive = false
	H.E.combat.solo(H.game_ms / 1000 + 0.5, false, false)
	check(H.count("launch") == 0 and u._ammo == 3960, "he died in his fire animation: no bolt, no ammo")
end

-- a fake memreader over a small PE image, rounding read_int32 the way the game does: game Lua numbers are
-- float32, exact only below 2^24, and every RVA in Warhammer3.exe is above it (live, 2026-10-13: the stamp
-- 0x6ac6d907 read back as 0x6ac6d900 and the import parse found nothing)
local function f32(n)
	if n == 0 then return 0 end
	local e = math.floor(math.log(math.abs(n)) / math.log(2)) - 23
	if e <= 0 then return n end
	return math.floor(n / 2 ^ e + 0.5) * 2 ^ e
end
local function fake_image(stamp)
	local BASE, mem = 0x14 * 2 ^ 28, {} -- Lua 5.1 on Windows reads a hex literal above 32 bits as 0xFFFFFFFF
	local function put(addr, n, bytes) for i = 0, bytes - 1 do mem[addr + i] = math.floor(n / 256 ^ i) % 256 end end
	local function str(addr, s) for i = 1, #s do mem[addr + i - 1] = s:byte(i) end mem[addr + #s] = 0 end
	local PE, IMP = 0x100, 0x1000123 -- the import directory sits above 2^24, at an odd RVA
	put(BASE + 0x3c, PE, 4)
	put(BASE + PE + 8, stamp or 0x6ac6d907, 4)
	put(BASE + PE + 0x90, IMP, 4)
	put(BASE + PE + 0x50, 0x5000000, 4) -- SizeOfImage: models live above it, like the heap
	local dlls = {
		{"USER32.dll", {"GetAsyncKeyState", "GetCursorPos", "SetCursorPos", "GetForegroundWindow", "GetClientRect",
			"ClientToScreen", "GetWindowThreadProcessId", "SetCursor", "ShowCursor"}},
		{"KERNEL32.dll", {"GetCurrentProcessId"}},
	}
	local free, fn = 0x2000001, 0x7FF8 * 2 ^ 32 + 0x12340000
	for d, dll in ipairs(dlls) do
		local desc = BASE + IMP + (d - 1) * 20
		local name, oft, ft = free, free + 0x101, free + 0x403
		str(BASE + name, dll[1])
		put(desc, oft, 4) put(desc + 12, name, 4) put(desc + 16, ft, 4)
		local hint = free + 0x805
		for k, f in ipairs(dll[2]) do
			put(BASE + oft + (k - 1) * 8, hint, 8)
			str(BASE + hint + 2, f)
			put(BASE + ft + (k - 1) * 8, fn + d * 0x1000 + k * 16, 8)
			hint = hint + #f + 3
		end
		free = free + 0x10001
	end
	local function ptr(a) return {addr = a} end
	local function u(a, bytes) local n = 0 for i = bytes - 1, 0, -1 do n = n * 256 + (mem[a + i] or 0) end return n end
	local mr = {base = ptr(BASE)}
	function mr.add(p, n) return ptr(p.addr + n) end
	function mr.read_uint8(p, o) return u(p.addr + (o or 0), 1) end
	function mr.read_uint16(p, o) return u(p.addr + (o or 0), 2) end
	function mr.read_int32(p, o) local n = u(p.addr + (o or 0), 4) if n >= 2 ^ 31 then n = n - 2 ^ 32 end return f32(n) end
	function mr.read_pointer(p, o) return ptr(u(p.addr + (o or 0), 8)) end
	mr.fl = {}
	function mr.read_float(p, o) return mr.fl[p.addr + (o or 0)] or 0 end
	function mr.ud_topointer(unit) return ptr(unit._addr) end
	function mr.tostring(p) return string.format("%08X%08X", math.floor(p.addr / 2 ^ 32), p.addr % 2 ^ 32) end -- %X is 32-bit
	function mr.is_null(p) return p.addr == 0 end
	function mr.eq(a, b) return a.addr == b.addr end
	function mr.alloc() free = free + 0x100 return ptr(BASE + free) end
	mr.calls, mr.writes = {}, {}
	function mr.call(f) mr.calls[#mr.calls + 1] = f return 4242 end
	mr.wrote = {} -- address -> value
	function mr.write(p, o, v) mr.writes[#mr.writes + 1] = v mr.wrote[p.addr + o] = v end
	function mr.uint8(n) return n end mr.uint16, mr.uint32 = mr.uint8, mr.uint8
	function mr.tonumber(n) return n end
	return mr, put, BASE
end

T.platform_reads_rvas_above_float32 = function()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local P = M.build(fake_image())
	check(P.build == "6ac6d907", "the exe stamp read exactly, got " .. tostring(P.build))
	check(P.features.input, "the import table parsed: " .. table.concat(P.problems, "; "))
	check(P.cursor == nil, "no Windows cursor route: looking hides the interface with cinematic UI")
end

-- an unknown build finds the command by its byte pattern. Its rip displacements are 32-bit fields too, and
-- 9.0's to the battle global is 0x157dbc1: read with read_int32 it rounds to an even number, one byte off
T.platform_pattern_route_reads_displacements_exactly = function()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local mr, put, BASE = fake_image(0x12345678) -- a build BUILDS does not know
	local HIT, CMD, GLOBAL, PUSH = 0x2efc2f8, 0x3901cd0, 0x4479ee0, 0x2e969ac -- 9.0's
	local function rel(o, target) put(BASE + HIT + o, target - (HIT + o + 4), 4) end
	rel(3, CMD) rel(0x23, GLOBAL) rel(0x4d, PUSH)
	put(BASE + HIT + 0x2a, 0x468, 4) put(BASE + HIT + 0x31, 0x3b0, 4) put(BASE + HIT + 0x3a, 0x3b1, 4) put(BASE + HIT + 0x48, 0x644e8, 4)
	local G, B = BASE + 0x5000000, BASE + 0x5100000
	put(BASE + GLOBAL, G, 8) put(G + 0x468, B, 8) put(B + 0x644e8, BASE + 0x5200000, 8)
	function mr.find_pattern() return mr.add(mr.base, HIT), 1 end
	local P = M.build(mr)
	local ok, why = P.check_anim()
	check(ok, "the battle object reached through the pattern: " .. tostring(why))
	check(P.play(mr.add(mr.base, 0x5300000), 7), "the command pushed")
	check(mr.calls[#mr.calls].addr == BASE + PUSH, "pushed through the push function")
	check(mr.writes[1].addr == BASE + CMD, "the command carries its type")
end

local function real_platform()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local mr, put, BASE = fake_image()
	return M.build(mr), mr, put, BASE
end

T.platform_reload_uses_the_active_fragment = function()
	local P, mr, put, BASE = real_platform()
	local m = mr.add(mr.base, 0x6300000)
	local a = BASE + 0x6400000
	put(m.addr + 0x308, a, 8)
	put(a + 0x50 + 1564 * 2, 0xffff, 2)
	put(a + 0x50 + 1554 * 2, 236, 2)
	check(P.reload_slot(m) == nil, "a crossbow's raise to aim is no reload: he reloads on the clock")
	put(a + 0x50 + 1564 * 2, 248, 2)
	check(P.reload_slot(m) == 1564, "firearm has a separate reload")
	put(a + 0x50 + 1564 * 2, 0xffff, 2)
	put(a + 0x50 + 1554 * 2, 0xffff, 2)
	check(P.reload_slot(m) == nil, "missing reload clips are refused")
end

T.platform_animation_slot_expires_with_its_native_handle = function()
	local P, mr, put, BASE = real_platform()
	local m = mr.add(mr.base, 0x6300000)
	put(m.addr + 0x278, 1557, 2)
	check(P.anim_slot(m) == nil, "a stale slot has no playing animation")
	put(m.addr + 0x898, BASE + 0x6400000, 8)
	check(P.anim_slot(m) == 1557, "the active animation carries its slot")
	put(m.addr + 0x898, 0, 8)
	put(m.addr + 0x278, 1564, 2)
	put(m.addr + 0x284, 6, 4)
	check(P.anim_slot(m) == 1564, "a reload without metadata stays active through its body mask")
end
-- one unit of men in the fake image; each man {x =, z =, marker = address, steer = three {x, z} copies}
local function fake_unit(mr, put, BASE, men, at)
	local UD, OBJ, DATA = BASE + 0x6000000, BASE + 0x6000100, BASE + 0x6001000
	put(UD + 8, OBJ, 8) put(OBJ + 0xa4, #men, 4) put(OBJ + 0xa8, DATA, 8)
	local sx, sz = 0, 0
	for k, m in ipairs(men) do
		local a = BASE + 0x6100000 + k * 0x1000
		put(DATA + (k - 1) * 8, a, 8)
		put(a, m.marker, 8)
		mr.fl[a + 0x88], mr.fl[a + 0x90] = m.x, m.z
		for i, f in ipairs({{0x1e0, 0x1e8}, {0x194, 0x198}, {0x368, 0x370}}) do mr.fl[a + f[1]], mr.fl[a + f[2]] = m.steer[i][1], m.steer[i][2] end
		sx, sz = sx + m.x, sz + m.z
	end
	return {_addr = UD, number_of_men_alive = function() return #men end,
		position = function() return {get_x = function() return at and at[1] or sx / #men end,
			get_z = function() return at and at[2] or sz / #men end} end}
end

-- measured live 2026-10-13 (Cathay, 9.0): men never ordered hold 0, 0 in their steering copies, and the
-- third copy, which also takes the aim point (handoff 9j), reads half-set
-- measured 2026-10-15: a deep block's men centre 5.4-6.2 m from the unit's position (Chosen, 160 men 16 wide;
-- Plaguebearers, 192 men 19 wide), which failed the check and played them whole. A man stands near the unit's position;
-- a model list that is not this unit's has nobody there
T.men_check_takes_a_deep_block = function()
	local P, mr, put, BASE = real_platform()
	local men = {}
	for r = 0, 14 do men[#men + 1] = {x = 0, z = -r, marker = BASE + 0x390d4f8, steer = {{0, 0}, {0, 0}, {0, 0}}} end
	local ok, why = P.check_men(fake_unit(mr, put, BASE, men, {0, 0}))
	check(ok, "a column 15 m deep, its position at the front: " .. tostring(why))
	check(not P.check_men(fake_unit(mr, put, BASE, men, {0, 30})), "nobody within 5 m of the unit: not its men")
end

T.men_check_accepts_men_never_ordered = function()
	local P, mr, put, BASE = real_platform()
	local function man(x, z) return {x = x, z = z, marker = BASE + 0x390d4f8, steer = {{0, 0}, {0, 0}, {x, 0}}} end
	local ok, why = P.check_men(fake_unit(mr, put, BASE, {man(30.1, 299), man(60.9, 303.8)}))
	check(ok, "the gunners as measured: " .. tostring(why))
end

-- measured the same day: a lord on a Longma is another model class than infantry, exe+3ac4908
T.men_check_accepts_a_lord_on_a_mount = function()
	local P, mr, put, BASE = real_platform()
	local ok, why = P.check_men(fake_unit(mr, put, BASE, {{x = 43, z = 312.7, marker = BASE + 0x3ac4908, steer = {{0, 0}, {0, 0}, {0, 2.9e32}}}}))
	check(ok, "the general as measured: " .. tostring(why))
end

-- measured live 2026-10-14 (Ironbreakers, 9.0): a regiment's two officers are another class, exe+3ac5c40, beside
-- its infantry, exe+390d4f8, with the same position, steering and command fields
T.men_check_accepts_officers_of_another_class = function()
	local P, mr, put, BASE = real_platform()
	local function man(x, marker) return {x = x, z = 300, marker = BASE + marker, steer = {{0, 0}, {0, 0}, {0, 0}}} end
	local ok, why = P.check_men(fake_unit(mr, put, BASE,
		{man(0.1, 0x3ac5c40), man(1.1, 0x3ac5c40), man(-0.6, 0x390d4f8), man(-1.6, 0x390d4f8)}))
	check(ok, "officers and their regiment as measured: " .. tostring(why))
end

T.men_check_refuses_any_man_whose_marker_is_outside_the_exe = function()
	local P, mr, put, BASE = real_platform()
	local function man(x, marker) return {x = x, z = 300, marker = marker, steer = {{0, 0}, {0, 0}, {0, 0}}} end
	check(not P.check_men(fake_unit(mr, put, BASE, {man(0, BASE + 0x390d4f8), man(1, 0x10000000)})),
		"the second man's type is a heap pointer")
end

-- a models array read at a moved offset holds no models: what it points at carries no type from the exe
T.men_check_refuses_a_marker_outside_the_exe = function()
	local P, mr, put, BASE = real_platform()
	for i, marker in ipairs({BASE + 0x6200000, 0x10000000}) do -- above the image, and below it (where the heap usually is)
		local ok = P.check_men(fake_unit(mr, put, BASE, {{x = 5, z = 5, marker = marker, steer = {{0, 0}, {0, 0}, {0, 0}}}}))
		check(not ok, "a heap pointer is no model type, " .. (i == 1 and "above" or "below"))
	end
end

T.men_check_refuses_steering_that_is_not_steering = function()
	local P, mr, put, BASE = real_platform()
	local function man(s1, s2) return {x = 200, z = 300, marker = BASE + 0x390d4f8, steer = {s1, s2, {0, 0}}} end
	check(not P.check_men(fake_unit(mr, put, BASE, {man({0 / 0, 5}, {0, 0})})), "not a number")
	check(not P.check_men(fake_unit(mr, put, BASE, {man({0, 0}, {5000, 5000})})), "kilometres from him")
	check(not P.check_men(fake_unit(mr, put, BASE, {man({1.5, 0}, {1.5, 0})})), "a speed, not a point")
end

-- +0x330 is a polymorphic command: +0x368 is a point while walking, an integer state in a transition.
T.steering_leaves_the_aim_point_alone = function()
	local P, mr, put, BASE = real_platform()
	local m = mr.add(mr.base, 0x6300000)
	for _, vt in ipairs({0x390d090, 0x3914618, 0x3912000}) do
		put(m.addr + 0x330, BASE + vt, 8)
		P.steer(m, -37.5, 294.8)
		check(mr.wrote[m.addr + 0x1e0] == -37.5 and mr.wrote[m.addr + 0x1e8] == 294.8, "the steering point")
		check(mr.wrote[m.addr + 0x194] == -37.5 and mr.wrote[m.addr + 0x198] == 294.8, "its copy")
		check(mr.wrote[m.addr + 0x368] == nil and mr.wrote[m.addr + 0x370] == nil, "non-walk command untouched")
	end
end

-- the mailbox (tools/third_person_cave.py, whose --selftest runs the cave's bytes under an emulator): a code cave at the
-- top of his update makes the stop's and the walk builder's calls on the battle thread, and the script only posts
-- requests into its block. memreader Plus's patcher, game_alloc, hook_info and read_original, as far as it uses them; a
-- cave's bytes land in memory, so a second platform on the same fake (the next battle of the session) finds it
local UPDATE_AT, UPDATE_START = 0x3086f04, {0x48, 0x8b, 0xc4, 0x48, 0x89, 0x58, 0x10}
local function with_plus(mr, put, BASE, site)
	for i, b in ipairs(site or UPDATE_START) do put(BASE + UPDATE_AT + i - 1, b, 1) end
	mr.caves, mr.cave_calls, mr.game_allocs = {}, {}, 0
	local next_cave, next_block = BASE + 0x4f00000, BASE + 0x4e00000
	function mr.read_original(p, o, n)
		local t = {} for i = 0, n - 1 do t[#t + 1] = string.char(mr.read_uint8(p, o + i)) end return table.concat(t)
	end
	function mr.hook_info(p) local c = mr.caves[p.addr] return c and {kind = "cave", cave = c.at} end
	function mr.game_alloc() mr.game_allocs = mr.game_allocs + 1 next_block = next_block + 0x1000 return mr.add(mr.base, next_block - BASE) end
	function mr.patcher(owner)
		return {cave = function(_, name, at, bytes)
			mr.cave_calls[#mr.cave_calls + 1] = {owner = owner, name = name, at = at.addr, bytes = bytes}
			if mr.refuse then return nil, mr.refuse end
			local c = mr.caves[at.addr]
			if c then
				if c.bytes ~= bytes then return nil, "the name is already used for a different change" end
				return c.at
			end
			next_cave = next_cave + 0x1000
			for i = 1, #bytes do put(next_cave + i - 1, bytes:byte(i), 1) end
			mr.caves[at.addr] = {bytes = bytes, at = mr.add(mr.base, next_cave - BASE)}
			return mr.caves[at.addr].at
		end}
	end
end

local function patched_platform(o)
	o = o or {}
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local mr, put, BASE = fake_image(0x6acec6f4)
	if not o.old_plus then with_plus(mr, put, BASE, o.site) end
	mr.refuse = o.refuse
	return M.build(mr), mr, put, BASE, M
end

-- what was last written at the block's field k (a pointer comes back as its address)
local function posted(P, M, mr, k, off)
	local v = mr.wrote[P.mailbox.addr + M.MB[k] + (off or 0)]
	if type(v) == "table" then return v.addr end
	return v
end
local STOP_AT, START_AT, SPEED_AT = 0x306edd4, 0x306f954, 0x303b744
local function script_built_or_destroyed(mr, BASE)
	for _, f in ipairs(mr.calls) do
		if type(f) == "table" and (f.addr == BASE + STOP_AT or f.addr == BASE + START_AT) then return true end
	end
	return false
end

T.the_mailbox_is_put_in_once_and_found_by_the_next_battle = function()
	local P, mr, put, BASE, M = patched_platform()
	check(P.features.mailbox and P.mailbox ~= nil, "put in as the platform loads: " .. table.concat(P.problems, "; "))
	check(#mr.cave_calls == 1 and mr.cave_calls[1].at == BASE + UPDATE_AT and mr.cave_calls[1].owner == "derpy_tp",
		"one cave, at the top of his update, owned")
	local block = P.mailbox.addr
	check(mr.read_pointer(mr.caves[BASE + UPDATE_AT].at, M.CAVE_BLOCK).addr == block, "the cave carries its block")
	for k, rva in pairs({walk_a = 0x3919350, move_a = 0x39199f8, move_b = 0x3ae1928, melee = 0x3ad24b8, walk_b = 0x3ae2400,
		walk_stop = STOP_AT, walk_start = START_AT}) do
		check(posted(P, M, mr, k) == BASE + rva, "the block's " .. k)
	end
	check(posted(P, M, mr, "man") == 0 and posted(P, M, mr, "guard") == 0 and posted(P, M, mr, "walk") == 0, "nobody, no request")
	check(posted(P, M, mr, "buf", 0x34) == 3 and posted(P, M, mr, "buf", 0x44) == 1 and posted(P, M, mr, "buf", 0x45) == 1
		and posted(P, M, mr, "buf", 0x4a) == 1, "the walk builder's straight path and movement flags")
	-- the next battle: Lua starts over, the cave and its block are the session's
	mr.wrote = {}
	local P2 = M.build(mr)
	check(P2.features.mailbox and P2.mailbox.addr == block and mr.game_allocs == 1, "the same block, read back from the cave")
	check(#mr.cave_calls == 2 and mr.cave_calls[2].bytes == mr.cave_calls[1].bytes, "asked again with the same bytes")
	check(posted(P2, M, mr, "man") == 0 and posted(P2, M, mr, "guard") == 0 and posted(P2, M, mr, "walk") == 0,
		"what an earlier battle left in it is cleared")
end

T.no_mailbox_nothing_is_posted_and_nothing_called = function()
	for _, o in ipairs({{refuse = "a thread is inside derpy_tp/mailbox"}, {site = {0xe9, 0, 0, 0, 0, 0x90, 0x90}}, {old_plus = true}}) do
		local P, mr, put, BASE = patched_platform(o)
		check(not P.features.mailbox and P.mailbox == nil, "no mailbox")
		check(table.concat(P.problems, "; "):find("mailbox", 1, true), "the reason is kept: " .. table.concat(P.problems, "; "))
		local m = mr.add(mr.base, 0x6300000)
		put(m.addr + 0x2e8, BASE + 0x6500000, 8)
		mr.calls = {}
		P.steer(m, 4, 5, true, 1)
		P.hold(m, 4, 5, 1)
		check(P.guard(m) == false and not script_built_or_destroyed(mr, BASE), "nothing native on him")
	end
	local P, mr = patched_platform({site = {0x48, 0x8b, 0xc4, 0x48, 0x89, 0x58, 0x18}})
	check(#mr.cave_calls == 0, "no cave over code it does not know")
end

-- the crash it is for: exe+7AB1DA (2026-10-17), a command's destructor reading FFFFFFFFFFFFFFFF, P.guard the script
-- log's last line - the script destroyed a command a battle thread was running
T.nothing_builds_or_destroys_his_command_from_the_script = function()
	for _, vt in ipairs({0x3919350, 0x39199f8, 0x3ae1928, 0x3ad24b8, 0x3ae2400, 0x3911fb0, 0x39126f0, 0x3919b28}) do
		local P, mr, put, BASE = patched_platform()
		local m = mr.add(mr.base, 0x6300000)
		put(m.addr + 0x330, BASE + vt, 8)
		put(m.addr + 0x2e8, BASE + 0x6500000, 8)
		put(m.addr + 0xb1c, 80, 4)
		mr.calls, mr.wrote = {}, {}
		P.guard(m)
		P.steer(m, 4, 5, true, 1)
		P.steer(m, 0, 0, false)
		P.hold(m, 4, 5, 1)
		check(not script_built_or_destroyed(mr, BASE), string.format("under 0x%x: no stop or walk builder from the script", vt))
		for off = 0x328, 0x3c0 do check(mr.wrote[m.addr + off] == nil, string.format("under 0x%x: his command untouched", vt)) end
	end
end

-- measured live 2026-10-16 (probes/zz_tp_regiment_test.lua, Kossars in a lasting melee, nobody at the keys): the
-- commands the engine itself puts on the man played alone moved him 24.1 m in 30 s; stopped with its own stop the
-- moment they are on him, 11 m, 8.5 m of it standing. On build 6acec6f4: the regiment's walk, two moves and the melee
-- attack (the auto attack; the author, 2026-10-14: "absolute control and no auto attack"). Which commands the cave
-- stops, and that a dead man's are left alone, is tools/third_person_cave.py --selftest's
T.the_guard_posts_to_his_update = function()
	local P, mr, put, BASE, M = patched_platform()
	local m = mr.add(mr.base, 0x6300000)
	check(P.guard(m) == true, "posted")
	check(posted(P, M, mr, "man") == m.addr and posted(P, M, mr, "guard") == 1, "a guard request, for him")
end

T.holding_still_posts_a_stop = function()
	local P, mr, put, BASE, M = patched_platform()
	local m = mr.add(mr.base, 0x6300000)
	P.hold(m, 4, 5, math.pi / 2)
	check(posted(P, M, mr, "man") == m.addr and posted(P, M, mr, "walk") == 1, "a hold request, for him")
	check(mr.wrote[m.addr + 0x1e0] == 4 and mr.wrote[m.addr + 0x198] == 5, "his slot copies take the hold point")
	check(mr.wrote[m.addr + 0xb0] == 16384, "he faces the camera")
end

-- the walk builder's parameter block, as platform.lua always filled it: the cave builds his walk from it, or writes its
-- point, run, speed, gait and heading into his own walk in place
T.a_steer_posts_the_walk_builders_block = function()
	local P, mr, put, BASE, M = patched_platform()
	local m = mr.add(mr.base, 0x6300000)
	put(m.addr + 0x2e8, BASE + 0x6400000, 8)
	local speed_run
	function mr.call(f, sig, a, b) if f.addr == BASE + SPEED_AT then speed_run = b return 1.5 end end
	P.steer(m, 0, 6, false)
	check(posted(P, M, mr, "man") == m.addr and posted(P, M, mr, "walk") == 2, "a steer request, for him")
	check(posted(P, M, mr, "buf", 0) == 0 and posted(P, M, mr, "buf", 8) == 6, "the point")
	check(posted(P, M, mr, "buf", 0x2c) == 1.5 and speed_run == 0 and posted(P, M, mr, "buf", 0x28) == 0
		and posted(P, M, mr, "buf", 0x46) == 0, "walking: the engine's speed, its fraction kept")
	check(posted(P, M, mr, "has_angle") == 0 and posted(P, M, mr, "buf", 0x30) == 0, "no yaw: heading toward the point")
	check(posted(P, M, mr, "near") == 0, "6 m away: a walk may be built")
	function mr.call(f, sig, u, run) if f.addr == BASE + SPEED_AT then speed_run = run return 3.5 end end
	P.steer(m, 0, 6, true, math.pi / 2, 1.5)
	check(speed_run == 1 and posted(P, M, mr, "buf", 0x2c) == 3.5 * 1.5 and posted(P, M, mr, "buf", 0x28) == 1
		and posted(P, M, mr, "buf", 0x46) == 1, "running, at a sprint's scale")
	check(posted(P, M, mr, "has_angle") == 1 and posted(P, M, mr, "buf", 0x30) == 16384 and mr.wrote[m.addr + 0xb0] == 16384,
		"he keeps his own facing")
	P.steer(m, 0, 0, false)
	check(posted(P, M, mr, "near") == 1, "at his own spot: no walk built (idle keeps its animations)")
	mr.wrote = {}
	function mr.call() end
	P.steer(m, 0, 6, false)
	check(posted(P, M, mr, "walk") == nil, "no speed, no request")
end

T.a_horse_is_steered_held_and_guarded = function()
	local P, mr, put, BASE, M = patched_platform()
	local m, horse = mr.add(mr.base, 0x6300000), BASE + 0x6400000
	put(m.addr + 0x2e0, horse, 8)
	put(horse + 0x2e8, BASE + 0x6500000, 8)
	P.steer(m, 4, 5, true, math.pi / 2)
	check(posted(P, M, mr, "man") == horse and posted(P, M, mr, "walk") == 2, "the horse is steered")
	check(mr.wrote[horse + 0xb0] == 16384, "the horse faces the move")
	P.hold(m, 4, 5, math.pi / 2)
	check(posted(P, M, mr, "man") == horse and posted(P, M, mr, "walk") == 1, "releasing the key stops the horse")
	check(P.guard(m) and posted(P, M, mr, "man") == horse and posted(P, M, mr, "guard") == 1, "the horse's auto attack, not its rider's")
end

-- his animation fragment, +0x308: a vtable, then a u16 clip index per slot from +0x50, 0xffff for none; one per
-- regiment and skeleton (measured 2026-10-16, probes/zz_tp_frag_probe.lua). Writes land in memory here, so a copy
-- reads back. The fake's qwords are doubles: slot values stay under 32 to keep 4 of them exact in one
local function fragment_platform()
	local P, mr, put, BASE = patched_platform()
	local free = 0x7000000
	function mr.alloc() free = free + 0x10000 return mr.add(mr.base, free) end
	function mr.write(p, o, v)
		mr.writes[#mr.writes + 1] = v mr.wrote[p.addr + o] = v
		if type(v) == "table" then put(p.addr + o, v.addr, 8) else put(p.addr + o, v, 2) end
	end
	local function fragment(addr) put(addr, BASE + 0x39d9448, 8) for s = 0, 2329 do put(addr + 0x50 + s * 2, s % 31, 2) end end
	return P, mr, put, BASE, fragment
end

T.the_man_played_alone_points_at_a_fragment_with_no_attack_clips = function()
	local P, mr, put, BASE, fragment = fragment_platform()
	local m, horse = mr.add(mr.base, 0x6300000), mr.add(mr.base, 0x6310000)
	local shared, hshared = BASE + 0x6400000, BASE + 0x6402000
	fragment(shared) fragment(hshared)
	put(m.addr + 0x308, shared, 8) put(horse.addr + 0x308, hshared, 8) put(m.addr + 0x2e0, horse.addr, 8)
	P.disarm(m)
	local mine, hmine = mr.read_pointer(m, 0x308), mr.read_pointer(horse, 0x308)
	check(mine.addr ~= shared and hmine.addr ~= hshared and mine.addr ~= hmine.addr, "rider and horse each on a copy")
	check(mr.read_pointer(mine, 0).addr == BASE + 0x39d9448, "the copy carries the fragment's head")
	for _, f in ipairs({mine, hmine}) do
		for _, s in ipairs({454, 459, 463, 484, 494, 500, 1901, 1941, 1950}) do
			check(mr.read_uint16(f, 0x50 + s * 2) == 0xffff, "no attack clip in slot " .. s)
		end
		for _, s in ipairs({0, 42, 135, 453, 464, 483, 501, 1094, 1557, 1564, 1900, 1951, 2329}) do
			check(mr.read_uint16(f, 0x50 + s * 2) == s % 31, "slot " .. s .. " kept")
		end
	end
	check(mr.read_uint16(mr.add(mr.base, shared - BASE), 0x50 + 454 * 2) == 454 % 31, "his regiment keeps its swings")
	check(P.has_slot(m, 454) and P.has_slot(horse, 1901), "his own swings still read as his")
	P.disarm(m)
	check(mr.read_pointer(m, 0x308).addr == mine.addr, "every frame: the same copy")
	P.arm(m)
	check(mr.read_pointer(m, 0x308).addr == shared and mr.read_pointer(horse, 0x308).addr == hshared, "armed: the regiment's again")
	P.arm(m)
	check(mr.read_pointer(m, 0x308).addr == shared, "twice is harmless")
	P.disarm(m)
	check(mr.read_pointer(m, 0x308).addr == mine.addr, "one copy per fragment, made once")
end

-- his own swing is pushed with his own table under it, or the engine finds no clip to play
T.his_own_swing_is_pushed_on_his_own_fragment = function()
	local P, mr, put, BASE, fragment = fragment_platform()
	local G, B = BASE + 0x5000000, BASE + 0x5100000
	put(BASE + 0x4480da0, G, 8) put(G + 0x468, B, 8) put(B + 0x644e8, BASE + 0x5200000, 8)
	check(P.check_anim(), "the command route")
	local m, shared = mr.add(mr.base, 0x6300000), BASE + 0x6400000
	fragment(shared)
	put(m.addr + 0x308, shared, 8)
	local under
	function mr.call(f) if f.addr == BASE + 0x2e9b974 then under = mr.read_pointer(m, 0x308).addr end end
	P.disarm(m)
	local mine = mr.read_pointer(m, 0x308).addr
	P.play(m, 42, 0)
	check(under == mine, "a walk keeps him disarmed")
	for _, s in ipairs({454, 489, 1902}) do
		P.disarm(m)
		under = nil
		check(P.play(m, s, 6) and under == shared, "his own clip " .. s .. " on his own table")
	end
end

T.no_fragment_is_touched_on_another_build = function()
	local P, mr, put, BASE = real_platform()
	P.features.steer = false
	local m = mr.add(mr.base, 0x6300000)
	put(m.addr + 0x308, BASE + 0x6400000, 8)
	P.disarm(m)
	check(mr.wrote[m.addr + 0x308] == nil, "nothing disarmed")
end

-- his queued clip against the order his regiment gives him each tick of a melee (measured 2026-10-16,
-- probes/zz_tp_melee_spam.lua, Teutogen Guard under two units, a click every 2.4 s): his update (exe+3086f04) resets a
-- queued action on a tick an order reached him, 4 and 0 of 10 swings started; its jump at exe+3087388 sent to his
-- action update instead, 10 and 10. memreader's patch writes only over the bytes it expects
local GATE_AT = 0x3087378
local GATE = {0x44, 0x38, 0xbf, 0xf8, 0x06, 0, 0, 0x75, 0x09, 0x44, 0x38, 0xbf, 0, 0x06, 0, 0, 0x75, 0x5c}
local function gate_platform(jump, stamp)
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local mr, put, BASE = fake_image(stamp or 0x6acec6f4)
	for i, b in ipairs(GATE) do put(BASE + GATE_AT + i - 1, b, 1) end
	if jump then put(BASE + GATE_AT + #GATE - 1, jump, 1) end
	local function bytes(a, n) local s = {} for i = 0, n - 1 do s[#s + 1] = mr.read_uint8(mr.base, a - BASE + i) end return s end
	mr.patches = {}
	function mr.patch(p, expected, new)
		mr.patches[#mr.patches + 1] = p.addr
		local now = bytes(p.addr, #expected)
		local function same(s) for i = 1, #s do if now[i] ~= s:byte(i) then return false end end return true end
		if same(new) then return new end
		if not same(expected) then return nil, "other bytes" end
		for i = 1, #new do put(p.addr + i - 1, new:byte(i), 1) end
		return expected
	end
	return M.build(mr), mr, BASE, function() return bytes(BASE + GATE_AT, #GATE) end
end

T.a_queued_swing_beats_the_ticks_order = function()
	local P, mr, BASE, now = gate_platform()
	local function jump() return now()[#GATE] end
	check(jump() == 0x5c, "the game's own jump while nobody is played")
	check(P.gate(true) and jump() == 0x52, "on: to his action update, got " .. string.format("%x", jump()))
	for i = 1, #GATE - 1 do check(now()[i] == GATE[i], "byte " .. i .. " of the gate untouched") end
	check(P.gate(true) and jump() == 0x52, "twice is harmless")
	check(P.gate(false) and jump() == 0x5c, "off: the game's own again")
	check(P.gate(false) and jump() == 0x5c, "twice is harmless")
end

T.a_battle_left_with_the_gate_on_finds_it_off = function()
	local P, mr, BASE, now = gate_platform(0x52)
	check(now()[#GATE] == 0x5c, "the platform puts the game's jump back as it loads")
end

T.the_gate_is_left_alone_where_it_is_not_the_gate = function()
	local P, mr, BASE, now = gate_platform(0x33) -- other bytes there: a patch moved the code
	check(not P.gate(true) and now()[#GATE] == 0x33, "nothing written over code it does not know")
	P, mr, BASE, now = gate_platform(nil, 0x6ac6d907)
	check(not P.gate(true) and #mr.patches == 0 and now()[#GATE] == 0x5c, "no gate on a build that has none")
end

T.unknown_walk_commands_play_the_regiment_whole = function()
	H.fresh({units = {{general = true, men = 20}}})
	H.P.features.steer = false
	H.tap("F2") H.step(0.5) -- clear of the start's halt
	H.down("W") H.step(0.1)
	check(H.E.F.model == nil and H.last("uc:goto_location"), "unknown steering falls back to a regiment move order")
end

-- seen in game 2026-10-14: Ironbreakers (a modded unit, range 60, not in the shot table, no firing slot) played as
-- their captain: the fire button ordered the whole regiment to shoot, it walked into range and pulled him back. Then
-- (the author, 2026-10-15) "pressing f2 will still move the entire battalion", and, with the mode key handing the shot
-- to the regiment whole: "the camera jumping is also not fixed", "it happens when switching to ranged", "it also
-- triggers the whole battalion to shoot or throw". A man who cannot shoot alone is played, in melee, with no ranged mode
T.a_man_who_cannot_shoot_alone_has_no_ranged_mode = function()
	H.fresh({units = {{general = true, type = "wh_test_mod_grenadiers", men = 20, range = 60, ammo = 10}}})
	H.tap("F2")
	H.step(0.1)
	local man = H.E.F.model
	check(man ~= nil and not H.E.F.solo and not H.E.F.ranged, "F2: one man, in melee")
	H.tap("Right mouse") H.step(0.1)
	check(H.E.F.model == man and not H.E.F.ranged, "the mode key: the same man, still in melee")
	H.tap("Left mouse") H.step(0.5)
	check(H.count("uc:attack_location") == 0 and H.count("uc:goto_location") == 0, "his regiment is never ordered")
end

-- seen in game 2026-10-14: a lord in a war machine (Greybeard's tank, 5 crew, not artillery) was steered as one
-- crewman, who cannot leave his vehicle: nothing moved
T.a_war_machine_is_played_whole = function()
	H.fresh({units = {{general = true, men = 5, war_machine = true}}})
	H.tap("F2") H.step(0.5) -- clear of the start's halt: an order inside 0.5 s of it is dropped
	H.down("W") H.step(0.1)
	check(H.E.F.model == nil and H.last("uc:goto_location"), "the war machine moves by a unit order")
end

T.unknown_build_has_no_walk_command_writes = function()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	local mr, put, BASE = fake_image(0x12345678)
	local P = M.build(mr)
	local m = mr.add(mr.base, 0x6300000)
	put(m.addr + 0x330, BASE + 0x3add278, 8)
	put(m.addr + 0x2e0, BASE + 0x6400000, 8)
	check(P.mount(m) == nil, "unknown builds do not follow 9.0's parent offset")
	mr.calls = {} -- building the platform called the game already
	P.steer(m, -37.5, 294.8)
	P.hold(m, -37.5, 294.8)
	check(P.guard(m) == false, "nothing guarded on another build")
	check(P.features.steer == false, "unknown build cannot steer one man")
	check(mr.wrote[m.addr + 0x368] == nil, "9.0's command marker is not assumed on another build")
	check(#mr.calls == 0, "no 9.0 function is called on another build")
end

T.solo_start_cancels_the_existing_attack_order = function()
	crossbowmen()
	check(H.count("uc:halt") > 0, "solo start stops a prior targeted fire order")
end

T.f2_cancels_existing_movement_before_accepting_input = function()
	for _, o in ipairs({{general = true, prior_walk = true}, {general = true, men = 21, prior_walk = true}}) do
		H.fresh({units = {o}})
		H.tap("F2")
		local u = H.units[1]
		local z = u._z
		H.step(2)
		check(near(u._z, z), "F2 with no movement keys stops the previous order for both a lord and a regiment")
	end
end

T.one_man_stop_cancels_its_lead_point = function()
	crossbowmen()
	H.down("W") H.step(0.1) H.up("W")
	local steered, held = H.count("steer"), H.count("hold")
	H.E.main.stop("test")
	local m, c = H.E.F.model, H.last("hold")
	check(H.count("hold") == held + 1 and c[3] == m.x and c[4] == m.z, "F2 off holds the soldier at his own position")
	check(H.count("steer") == steered, "F2 off steers no walk")
end

-- the author, 2026-10-14: "moving while aiming (sliding on ground)". While a shot runs nothing drives him, so a
-- walk already under way carried him along under the aim clip; the shot stops it natively first.
T.solo_shot_stops_his_walk_before_aiming = function()
	crossbowmen()
	H.down("W") H.step(0.5)
	check(H.count("steer") > 0, "walking")
	local before = #H.calls
	H.down("Left mouse") H.step(1 / 60)
	local hold, play
	for i = before + 1, #H.calls do
		local c = H.calls[i]
		if c[1] == "hold" and c[2] == H.E.F.model.id and not hold then hold = i end
		if c[1] == "play" and not play then play = i end
	end
	check(play, "the aim started")
	check(hold and hold < play, "his walk is stopped before the aim plays")
end

-- the author, 2026-10-14: "aiming -> switch melee mode -> aiming and sliding". Measured (probes/zz_tp_unclip.lua,
-- paired screenshots): a full-body clip whose shot was dropped stays latched when his walk replaces its command, and
-- he slides in its pose; WALK_1 played with mask 0 ends it, and he walks properly from the same frame.
T.a_step_after_the_mode_key_mid_aim_does_not_slide = function()
	crossbowmen()
	H.tap("Left mouse") H.step(0.3)
	check(H.last("play")[3] == 1554, "aiming")
	H.tap("Right mouse")
	check(not H.E.F.ranged and not H.E.F.shot, "melee: the shot is dropped")
	local steers = H.count("steer")
	H.down("W") H.step(1 / 60)
	check(H.count("steer") > steers, "he walks on the first frame")
	local p = H.last("play")
	check(p[3] == 42 and p[4] == 0, "a walking clip ends the aim's hold, got " .. p[3] .. "/" .. tostring(p[4]))
	H.step(1)
	check(H.count("slide") == 0, "no slide: " .. H.count("slide"))
end

T.walking_from_rest_plays_no_clip = function()
	crossbowmen()
	H.down("W") H.step(0.2)
	check(H.count("steer") > 0 and H.count("play") == 0, "nothing holds him: no clip")
end

-- the engine's own shooting idles report a clip too; one it keeps reporting must not queue a walk every frame
T.a_clip_that_keeps_reporting_is_not_queued_every_frame = function()
	crossbowmen()
	H.P.anim_slot = function() return 1441 end
	H.down("W") H.step(1)
	check(H.count("play") == 4, "one walking clip each 0.3 s: " .. H.count("play"))
end

-- the author, 2026-10-14: "the transition is not instant". The Iron Hail's reload clip runs 14 s (spec, measured
-- 2026-10-13) and nothing walked him until it ended; the old lowering clip (1461) was a draw of his sword on top.
-- A step ends the reload at once. The aim and the firing clip are not cut: firing waits for the full clips.
local GUNNERS = "wh3_main_cth_inf_iron_hail_gunners_0"
local function aims() local n = 0 for _, c in ipairs(H.all("play")) do if c[3] == 1554 then n = n + 1 end end return n end

T.a_step_cuts_the_reload_short = function()
	crossbowmen({type = GUNNERS})
	H.tap("Left mouse") H.step(6)
	check(H.E.F.shot and H.E.F.shot.phase == "reload", "reloading")
	local steers = H.count("steer")
	H.down("W") H.step(1 / 60)
	check(H.count("steer") > steers and not H.E.F.shot, "he walks on the first frame")
	H.step(1)
	check(H.count("slide") == 0, "out of the reload clip, not sliding in it: " .. H.count("slide"))
end

T.a_step_does_not_cut_the_aim_or_the_firing_clip = function()
	crossbowmen({type = GUNNERS})
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	H.tap("Left mouse")
	local steers = H.count("steer")
	H.down("W") H.step(1.4)
	check(H.count("launch") == 3, "the shot leaves: " .. H.count("launch"))
	H.step(3.4) -- the firing clip runs to 5 s
	check(H.count("steer") == steers, "he stands through the aim and the firing clip")
	H.step(0.4)
	check(H.count("steer") > steers and not H.E.F.shot, "the reload starts and the step ends it")
end

-- a cut reload still counts: the next shot waits the projectile's own base_reload_time (13 s) from the reload's
-- start (5 s in the harness: aim 1 s, firing clip 4 s)
T.a_cut_reload_still_delays_the_next_shot = function()
	crossbowmen({type = GUNNERS})
	local t0 = H.game_ms
	H.tap("Left mouse") H.step(6)
	H.down("W") H.step(0.5) H.up("W")
	H.tap("Left mouse")
	H.step(17.5 - (H.game_ms - t0) / 1000)
	check(aims() == 1, "the click waits out the reload time: " .. aims() .. " aims")
	H.step(1)
	check(aims() == 2, "then he aims")
end

-- leaving ranged and coming back skips nothing: in the reload, the wait counts from its start; in the firing
-- clip after the shot, from the switch
T.the_mode_key_does_not_skip_the_reload = function()
	for _, case in ipairs({{6, 18}, {2, 15}}) do
		crossbowmen({type = GUNNERS})
		local t0 = H.game_ms
		H.tap("Left mouse") H.step(case[1])
		H.tap("Right mouse") H.tap("Right mouse")
		check(H.E.F.ranged and not H.E.F.shot, "back to ranged, the shot dropped")
		H.tap("Left mouse")
		H.step(case[2] - 0.5 - (H.game_ms - t0) / 1000)
		check(aims() == 1, "switched at " .. case[1] .. " s: no aim before " .. case[2] .. " s, got " .. aims() .. " aims")
		H.step(1)
		check(aims() == 2, "switched at " .. case[1] .. " s: then he aims")
	end
end

T.the_mode_key_mid_aim_adds_no_wait = function()
	crossbowmen({type = GUNNERS})
	H.tap("Left mouse") H.step(0.3)
	H.tap("Right mouse") H.tap("Right mouse")
	H.tap("Left mouse") H.step(0.1)
	check(aims() == 2 and H.count("launch") == 0, "no shot left, nothing to reload: he raises to aim again at once")
end

-- a crossbow has no reload clip, and leaving ranged after its bolt skips nothing either (the author, 2026-10-17:
-- "some ranged units bypass the reload time"): the wait counts from the switch
T.a_crossbow_switching_modes_after_its_bolt_still_waits = function()
	crossbowmen()
	local t0 = H.game_ms
	H.tap("Left mouse") H.step(2) -- the bolt at 1.3 s, the firing clip until 5 s
	H.tap("Right mouse") H.tap("Right mouse")
	H.tap("Left mouse")
	H.step(14.5 - (H.game_ms - t0) / 1000)
	check(aims() == 1, "no aim before 15 s, the 13 s reload from the switch: " .. aims() .. " aims")
	H.step(1)
	check(aims() == 2, "then he aims")
end

T.solo_moves_with_own_facing_and_run_toggle = function()
	crossbowmen()
	H.down("W") H.step(1 / 60)
	local c = H.last("steer")
	check(c[5] == true and c[6] == H.E.rig.yaw, "movement passes run and camera facing to the controlled model")
end

local function battle_hud()
	H.fresh()
	local h = find_uicomponent(H.root, "hud_battle") -- the harness makes it, with the unit cards
	local radar = H.comp("radar_holder", h)
	local hidden = H.comp("defeat_notification", h) hidden:SetVisible(false)
	local port = H.comp("porthole_parent", h)
	local face = H.comp("model_parent", port)
	local abilities = H.comp("ability_parent", port)
	local button = H.comp("button_unit_camera", port)
	local banners = H.comp("unit_id_holder", H.root)
	local own = H.comp("derpy_tp_hud", H.root)
	return radar, hidden, face, abilities, button, banners, own
end

T.third_person_hides_unrequested_hud = function()
	local radar, hidden, face, abilities, button, banners, own = battle_hud()
	H.tap("F2")
	check(not radar:Visible() and not banners:Visible() and not button:Visible(), "radar, banners and portrait controls hidden")
	check(face:Visible() and abilities:Visible() and own:Visible(), "portrait, abilities and custom HUD kept")
end

T.third_person_restores_hud_visibility_after_error = function()
	local radar, hidden, face, abilities, button, banners = battle_hud()
	H.tap("F2")
	H.E.fail("test: restore UI")
	check(radar:Visible() and button:Visible() and banners:Visible(), "normal battle HUD restored")
	check(not hidden:Visible(), "an originally hidden notification stays hidden")
end

-- CA's porthole_mask draws the cup the camera and info buttons sit in (state images 2 and 3); with the
-- buttons hidden it showed as two empty black sockets cut into the bottom-left corner
T.third_person_fades_the_empty_button_cup = function()
	battle_hud()
	local mask = H.comp("porthole_mask", find_uicomponent(H.root, "porthole_parent"))
	mask:SetCurrentStateImageOpacity(2, 200)
	H.tap("F2")
	check(mask:Visible() and mask:GetCurrentStateImageOpacity(1) == 255, "the frame stays")
	check(mask:GetCurrentStateImageOpacity(2) == 0 and mask:GetCurrentStateImageOpacity(3) == 0, "the cup and its strip fade")
	H.tap("F2")
	check(mask:GetCurrentStateImageOpacity(2) == 200 and mask:GetCurrentStateImageOpacity(3) == 255, "put back as they were")
end

-- the HUD (plan 2, docs/superpowers/specs/2026-10-14-third-person-hud-design.md) ---------------------------------
local function hud_cco(keys, secs, order)
	local t = H.default_cco()
	local list = order or keys
	t["BattleAbilityList.Size"] = #list
	for i, k in ipairs(list) do
		local at = "BattleAbilityList.At(" .. (i - 1) .. ")."
		t[at .. "SetupAbilityContext.RecordKey"] = k
		t[at .. "SetupAbilityContext.IconPath"] = "ui/battle ui/ability_icons/" .. k .. ".png"
		t[at .. "RechargeTimeRemainingSecs"] = (secs or {})[k] or 0
		t[at .. "IsActive"], t[at .. "ActiveTimeRemainingSecs"] = false, 0
		t[at .. "WindUpTimeRemainingSecs"] = -1 -- -1: not winding up (measured)
	end
	return t
end

-- third person on a general with these abilities; o.cco replaces the context table before F2
local function hud_on(o)
	o = o or {}
	H.fresh({units = {{general = true, abilities = o.abilities or {}, can = o.can or {}, men = o.men or 1, hp = o.hp,
		range = o.range or 0, ammo = o.ammo or 0}}, mct = o.mct})
	H.cco = o.cco or hud_cco(o.abilities or {}, o.secs, o.order)
	H.tap("F2")
	return find_uicomponent(H.root, "derpy_tp_hud")
end
local function hud_part(id) return find_uicomponent(H.root, "derpy_tp_hud", id) end

T.the_hud_shows_with_third_person_and_hides_after = function()
	local hud = hud_on()
	check(hud and hud:Visible(), "third person on: the HUD shows")
	H.tap("F2")
	check(not hud:Visible(), "third person off: the HUD hides")
end

T.the_hud_sits_in_the_bottom_corners_and_centre = function()
	hud_on({abilities = {"a1"}})
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	local m = L.margin
	local p, f, mode = hud_part("portrait"), hud_part("slot_1_frame"), hud_part("plate_right")
	check(p.x == m and p.y + L.groups.left[2] - L.at.portrait[3] == 1080 - m, "left group at the bottom-left margin")
	check(math.abs(f.x + f.w / 2 - 960) <= 1, "one slot: centred on the screen: " .. f.x)
	check(mode.x + L.groups.right[1] == 1920 - m, "right group at the bottom-right margin")
	local a = hud_part("act_attack_frame")
	check(a.y == 1080 - m - (L.groups.right[2] + L.stack + L.groups.actions[2]), "room beside one ability: the buttons sit "
		.. "just over the right plate: " .. a.y)
end

-- seen in game 2026-10-14: four abilities sat left of centre, the bar centred for ten
T.the_hotbar_centres_on_the_slots_it_shows = function()
	hud_on({abilities = {"a1", "a2", "a3", "a4"}})
	local a, b = hud_part("slot_1_frame"), hud_part("slot_4_frame")
	check(math.abs((a.x + b.x + b.w) / 2 - 960) <= 1, "four slots centred: " .. a.x .. " to " .. (b.x + b.w))
	local ab = {} for i = 1, 11 do ab[i] = "a" .. i end
	hud_on({abilities = ab})
	a, b = hud_part("slot_1_frame"), hud_part("slot_10_frame")
	check(math.abs((a.x + b.x + b.w) / 2 - 960) <= 1, "eleven abilities: the ten slots centred")
end

T.the_hotbar_shows_one_slot_per_ability_with_its_key = function()
	hud_on({abilities = {"a1", "a2", "a3"}, mct = {key_ability_2 = "R"}})
	for n = 1, 3 do check(hud_part("slot_" .. n .. "_frame"):Visible(), "slot " .. n .. " shows") end
	check(not hud_part("slot_4_frame"):Visible() and not hud_part("slot_4_icon"):Visible()
		and not hud_part("slot_4_keyplate"):Visible(), "slot 4 is empty: hidden")
	check(hud_part("slot_1_key").text == "1" and hud_part("slot_2_key").text == "R", "the key labels follow MCT")
end

T.hotbar_icons_and_the_portrait_come_from_the_unit_context = function()
	hud_on({abilities = {"a1", "a2"}})
	check(hud_part("slot_2_icon").img[0] == "ui/battle ui/ability_icons/a2.png", "slot 2 wears a2's icon")
	check(hud_part("portrait").img[0] == "ui/units/icons/test_card.png", "the portrait is the unit's card")
	check(hud_part("name").text == "Test Regiment", "the unit's name")
	local c = H.last("cco")
	check(c[2] == "CcoBattleUnit" and c[3] == "cco_1", "read through the card's context id: " .. tostring(c[3]))
end

T.hotbar_follows_the_cast_order_not_the_context_order = function()
	hud_on({abilities = {"a1", "a2"}, order = {"a2", "a1"}})
	check(hud_part("slot_1_icon").img[0] == "ui/battle ui/ability_icons/a1.png", "slot 1 is what key 1 casts")
end

T.eleven_abilities_fill_ten_slots = function()
	local ab = {} for i = 1, 11 do ab[i] = "a" .. i end
	hud_on({abilities = ab})
	check(hud_part("slot_10_frame"):Visible() and not hud_part("slot_11_frame"), "ten slots, no eleventh")
	check(H.E.F.on and not H.logged("derpy_tp: error"), "no error")
	H.step(0.5)
	for _, c in ipairs(H.all("cco")) do
		check(c[4] ~= "BattleAbilityList.At(10).RechargeTimeRemainingSecs", "no cooldown read for an eleventh slot")
	end
end

T.a_context_read_that_gives_nothing_hides_its_part = function()
	local t = hud_cco({})
	t.IconPath = nil
	hud_on({cco = t})
	check(not hud_part("portrait"):Visible() and H.logged("HUD part portrait is off"), "no card path: the portrait hides")
end

T.no_hud_in_multiplayer = function()
	H.fresh({mp = true})
	H.tap("F2")
	check(not find_uicomponent(H.root, "derpy_tp_hud"), "no panel in multiplayer")
end

T.the_health_bar_follows_hitpoints = function()
	hud_on({hp = 1})
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	local fill = hud_part("health_fill")
	check(fill.w == L.fill.health_fill, "full health: full width, got " .. tostring(fill.w))
	H.units[1]._hp = 0.5 H.step(1 / 60)
	check(fill.w == math.floor(L.fill.health_fill * 0.5 + 0.5), "half health: half width, got " .. fill.w)
end

T.men_alive_shows_for_a_regiment_only = function()
	hud_on({men = 1})
	check(not hud_part("men"):Visible() and not hud_part("men_icon"):Visible(), "one man: no count, no icon")
	hud_on({men = 40})
	H.units[1]._models[3].alive = false H.step(1 / 60)
	check(hud_part("men"):Visible() and hud_part("men").text == "39 / 40", "a regiment: alive of initial")
end

T.shots_left_and_the_mode_icon = function()
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	hud_on({men = 1, range = 160, ammo = 12}) -- one model: played whole, so the shot is his
	check(hud_part("ammo"):Visible() and hud_part("ammo").text == "12", "shots left")
	check(hud_part("mode").img[0] == L.art.ranged, "ranged icon")
	H.units[1]._ammo = 11 H.step(1 / 60)
	check(hud_part("ammo").text == "11", "counts down")
	hud_on({men = 21})
	check(not hud_part("ammo"):Visible() and not hud_part("ammo_back"):Visible(), "no missile weapon: no ammo")
	check(hud_part("mode").img[0] == L.art.melee, "melee icon")
end

T.a_slot_dims_when_its_ability_cannot_be_cast = function()
	hud_on({abilities = {"a1", "a2"}, can = {a2 = false}})
	check(not hud_part("slot_1_dim"):Visible() and hud_part("slot_2_dim"):Visible(), "a2 cannot be cast: dimmed")
	H.units[1]._can.a2 = true H.step(1 / 60)
	check(not hud_part("slot_2_dim"):Visible(), "castable again: undimmed")
end

T.cooldown_seconds_round_up_and_clear_when_ready = function()
	hud_on({abilities = {"a1"}, secs = {a1 = 4.2}})
	H.step(0.3)
	check(hud_part("slot_1_cool").text == "5" and hud_part("slot_1_coolplate"):Visible(), "4.2 s left reads 5, on a plate")
	H.cco["BattleAbilityList.At(0).RechargeTimeRemainingSecs"] = 0 H.step(0.3)
	check(hud_part("slot_1_cool").text == "" and not hud_part("slot_1_coolplate"):Visible(), "ready: no seconds, no plate")
end

T.a_still_frame_writes_nothing = function()
	hud_on({abilities = {"a1"}, men = 21, range = 160, ammo = 12})
	H.step(0.5)
	local n = H.count("text") + H.count("img") + H.count("resize") + H.count("vis")
	H.step(0.5)
	check(H.count("text") + H.count("img") + H.count("resize") + H.count("vis") == n, "nothing changed: nothing written")
end

T.context_reads_stay_under_five_a_second = function()
	hud_on({abilities = {"a1"}})
	local before = #H.all("cco")
	H.step(1)
	local reads = 0
	for i = before + 1, #H.all("cco") do
		if H.all("cco")[i][4] == "BattleAbilityList.At(0).RechargeTimeRemainingSecs" then reads = reads + 1 end
	end
	check(reads >= 4 and reads <= 6, "about five reads of a cooldown a second, got " .. reads)
end

T.a_failed_context_read_hides_only_its_part = function()
	local t = hud_cco({})
	t.IconPath = function() error("test: no icon") end
	hud_on({cco = t, hp = 1})
	check(not hud_part("portrait"):Visible(), "the portrait hides")
	H.units[1]._hp = 0.5 H.step(1 / 60)
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	check(hud_part("health_fill").w == math.floor(L.fill.health_fill * 0.5 + 0.5), "health still updates")
	check(H.logged("HUD part portrait is off"), "logged once")
end

T.three_hud_errors_turn_the_hud_off_not_third_person = function()
	local t = hud_cco({"a1"})
	t.IconPath = function() error("test: 1") end
	t["BattleAbilityList.Size"] = function() error("test: 2") end
	hud_on({cco = t})
	H.units[1].unary_hitpoints = function() error("test: 3") end -- only the HUD reads it
	H.step(1 / 60)
	check(not find_uicomponent(H.root, "derpy_tp_hud"):Visible(), "the HUD is off")
	check(H.E.F.on and not H.E.disabled, "third person still on")
end

-- measured 2026-10-14: a layout the engine cannot build makes CreateComponent answer nil, and the HUD went missing
-- without a word in the log
T.a_layout_the_engine_refuses_logs_and_leaves_third_person_on = function()
	H.fresh({units = {{general = true, abilities = {}, men = 1, range = 0, ammo = 0}}})
	H.refuse_layout = true
	H.tap("F2")
	H.refuse_layout = nil
	check(H.E.F.on and not H.E.disabled, "third person still on")
	check(H.logged("the HUD's layout did not load"), "the refusal is in the script log")
	H.step(1 / 60)
	check(H.E.F.on and not H.E.disabled, "the tick runs without the HUD")
end

-- the author, 2026-10-14: "1 is pressed, button highlights, stop melee or shooting, left click activates on the
-- ground or unit". CA's own targeting preview and world pings are hidden by the cinematic UI (measured), so the
-- HUD is the preview: the slot shows armed, the crosshair is up in any mode, a label names the target
local function armed_on(o)
	H.fresh({units = {{general = true, abilities = o.abilities or {FIREBALL}}}, enemies = o.enemies})
	H.tap("F2") H.step(0.1)
end
local function crosshair_up() local x = find_uicomponent(H.root, "derpy_tp_crosshair") return x and x:Visible() end

T.an_aimed_ability_arms_on_its_key_and_goes_off_on_the_left_click = function()
	armed_on({enemies = {{x = 0, z = 50}}})
	check(not H.E.F.ranged and not crosshair_up(), "melee: no crosshair")
	H.tap("1") H.step(1 / 60)
	check(H.count("uc:perform_special_ability") == 0, "the key arms, it does not cast")
	check(hud_part("slot_1_armed"):Visible(), "the slot shows armed")
	check(crosshair_up(), "the crosshair is up to aim it, melee or not")
	H.tap("Left mouse") H.step(1 / 60)
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == FIREBALL and c[4] == H.enemies[1], "the left click casts at the enemy on the crosshair")
	check(H.count("uc:attack_unit") == 0 and H.count("play") == 0, "the click was the cast's, not a swing")
	check(not hud_part("slot_1_armed"):Visible() and not crosshair_up(), "cast: disarmed, back to melee")
end

T.the_key_again_or_the_mode_key_disarms = function()
	armed_on({enemies = {{x = 0, z = 50}}})
	H.tap("1") H.step(1 / 60) H.tap("1") H.step(1 / 60)
	check(not hud_part("slot_1_armed"):Visible(), "the key again: disarmed")
	H.tap("1") H.step(1 / 60) H.tap("Right mouse") H.step(1 / 60)
	check(not hud_part("slot_1_armed"):Visible() and not H.E.F.ranged, "the mode key: disarmed, the mode unchanged")
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("uc:perform_special_ability") == 0, "nothing was cast")
end

T.the_target_label_names_what_the_crosshair_is_on = function()
	armed_on({enemies = {{x = 0, z = 50}}})
	H.cco_ids = {[tostring(H.enemies[1]:unique_ui_id())] = {Name = "Chaos Lord of Nurgle"}}
	H.tap("1") H.step(0.3)
	check(hud_part("target"):Visible() and hud_part("target").text == "Chaos Lord of Nurgle", "the enemy's own name: "
		.. tostring(hud_part("target").text))
	armed_on({})
	H.tap("1") H.step(0.3)
	check(hud_part("target").text == "No enemy in sight", "nothing on the crosshair")
	armed_on({abilities = {BARRAGE}})
	H.tap("1") H.step(0.3)
	check(hud_part("target").text:match("^Ground, %d+ m$"), "a ground ability: how far: " .. tostring(hud_part("target").text))
	H.tap("1") H.step(0.3)
	check(not hud_part("target"):Visible(), "disarmed: no label")
end

-- the author, 2026-10-14: "marking works, but no unit highlight ... a custom arrow on the unit is sufficient". CA's
-- outline and pings are hidden by the cinematic UI, so the arrow is ours: the unit projected by CA's
-- WorldSpaceToScreenSpace, which answers screen px, and 0 < z < 1 in front of the camera (measured 2026-10-14)
local function project(z, dx) H.w2s = function(x, y, zz) return 960 + x * 10 + (dx or 0), 540 - y * 10 - zz, z or 0.5 end end
local function arrow() return hud_part("target_arrow") end

T.the_arrow_points_at_the_unit_an_armed_ability_would_hit = function()
	armed_on({enemies = {{x = 4, z = 50}}})
	project()
	H.tap("1") H.step(0.3)
	local a, L = arrow(), assert(loadfile("/script/derpy_tp/hud_layout"))()
	local sx, sy = 960 + 4 * 10, 540 - L.arrow_lift * 10 - 50
	check(a:Visible(), "armed on an enemy: the arrow shows")
	check(a.x == math.floor(sx - a.w / 2) and a.y == math.floor(sy - a.h),
		"its tip on the unit's projected point: " .. tostring(a.x) .. "," .. tostring(a.y))
	H.tap("1") H.step(1 / 60)
	check(not a:Visible(), "disarmed: no arrow")
end

T.the_arrow_is_hidden_until_an_ability_is_armed = function()
	armed_on({enemies = {{x = 4, z = 50}}})
	project()
	H.step(0.3)
	check(not arrow():Visible(), "third person on, nothing armed: no arrow at the screen's centre")
end

T.the_arrow_follows_the_view_every_frame = function()
	armed_on({enemies = {{x = 4, z = 50}}})
	project()
	H.tap("1") H.step(0.3)
	local x0 = arrow().x
	project(0.5, 30) H.step(1 / 60)
	check(arrow().x == x0 + 30, "the view moved: the arrow moved the same frame, " .. x0 .. " to " .. arrow().x)
end

T.no_arrow_behind_the_camera_off_a_unit_or_on_the_ground = function()
	for _, z in ipairs({1.02, -0.1}) do
		armed_on({enemies = {{x = 4, z = 50}}})
		project(z)
		H.tap("1") H.step(0.3)
		check(not arrow():Visible(), "projected depth " .. z .. ": outside the view, no arrow")
	end
	armed_on({})
	project()
	H.tap("1") H.step(0.3)
	check(not arrow():Visible(), "no enemy in sight: no arrow")
	armed_on({abilities = {BARRAGE}, enemies = {{x = 4, z = 50}}})
	project()
	H.tap("1") H.step(0.3)
	check(not arrow():Visible(), "a ground ability marks no unit")
end

-- seen in game 2026-10-14: the crosshair on empty ground armed on a regiment in the screen's top-left corner, the
-- unit least far off the ray in metres. A target has to be near the crosshair as the eye sees it: inside a cone
T.ability_enemy_far_off_the_crosshair_is_not_a_target = function()
	armed_on({enemies = {{x = 40, z = 50}}})
	project()
	H.tap("1") H.step(0.3)
	check(hud_part("target").text == "No enemy in sight" and not arrow():Visible(), "40 m aside at 50 m: nothing marked, "
		.. tostring(hud_part("target").text))
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("uc:perform_special_ability") == 0, "and nothing cast at it")
end

-- the rig looks ahead of the man it follows, so his own position is never on the crosshair; a regiment's is, when
-- the man played out of it stands behind its centre
T.a_regiment_played_by_one_man_is_not_his_own_target = function()
	H.fresh({units = {{general = true, abilities = {MOD}, men = 21, type = "wh_test_melee"}}})
	H.cco = ability_record({TargetFriends = true, TargetSelf = true})
	H.tap("F2") H.step(0.1)
	local m = H.E.F.model
	check(m, "one man of the regiment is played")
	m.z = -20 H.step(2) -- 20 m behind his regiment's centre, which is now ahead of him under the crosshair
	H.w2s = function() return 960, 500, 0.5 end
	H.tap("1") H.step(0.3)
	check(hud_part("target").text == "On himself" and not hud_part("target_arrow"):Visible(),
		"his own regiment is not named or marked: " .. tostring(hud_part("target").text))
end

T.the_hud_rewrites_everything_when_shown_again = function()
	hud_on({abilities = {"a1"}})
	H.tap("F2")
	local n = H.count("text")
	H.tap("F2")
	check(H.count("text") > n and hud_part("slot_1_key").text == "1", "shown again: every label written again")
end

local function ring_part(id) return find_uicomponent(H.root, "derpy_tp_crosshair", id) end
local function angle(frac, half)
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	local f = half == 1 and math.min(frac, 0.5) * 2 or math.max(frac - 0.5, 0) * 2
	return L.ring[half][1] + f * (L.ring[half][2] - L.ring[half][1])
end

-- measured 2026-10-14: the two halves turn opposite ways (L1 0 -> +pi, L2 0 -> -pi), and ReloadPercentMax is 1 when
-- the regiment is LOADED: a loaded regiment shows no ring
T.a_loaded_regiment_shows_no_ring = function()
	playing({type = "wh_test_gunners", men = 20, x = 40, range = 160, ammo = 100, men_ok = false}) -- played whole
	H.mouse = {1, 0} H.step(1 / 60) -- a look frame: the crosshair is up while aiming
	H.cco.ReloadPercentMax = 1 H.step(0.3)
	check(ring_part("reload_ring") and not ring_part("reload_ring"):Visible(), "loaded: no ring")
	H.cco.ReloadPercentMax = 0.25 H.step(0.3)
	check(ring_part("reload_ring"):Visible(), "reloading: the ring shows")
	check(near(ring_part("loading_ring_L1").rot[0], angle(0.25, 1), 0.01), "a quarter: half of the first half")
end

T.the_two_ring_halves_turn_opposite_ways = function()
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	check(L.ring[1][2] > L.ring[1][1] and L.ring[2][2] < L.ring[2][1], "L1 turns up to +pi, L2 down to -pi")
end

-- the harness's reload clip runs 5 s to 12 s after the click (aim 1 s, firing clip 4 s, reload 7 s); the
-- Iron Hail's base_reload_time is 13 s. In game the clip is 14 s: the ring fills at 13 and stays full to 14.
T.the_reload_ring_fills_through_the_reload_for_one_man = function()
	crossbowmen({type = GUNNERS})
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	H.tap("Left mouse") H.step(6)
	local r = ring_part("reload_ring")
	check(r:Visible(), "reloading: the ring shows")
	check(near(ring_part("loading_ring_L1").rot[0], angle(1 / 13, 1), 0.05), "1 s of 13: the first half turns")
	check(near(ring_part("loading_ring_L2").rot[0], angle(1 / 13, 2), 0.05), "the second half waits")
	H.step(7)
	check(r:Visible(), "the clip over at 12 s, the game's 13 s reload is not (2026-10-16): the ring still shows")
	H.step(5.5)
	check(not r:Visible(), "the reload is over: the ring hides")
end

T.a_cut_reload_keeps_the_ring_to_the_ready_time = function()
	crossbowmen({type = GUNNERS})
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	H.tap("Left mouse") H.step(6)
	H.down("W") H.step(1) H.up("W") -- the step cuts the reload; he is ready 13 s after it started, at 18 s
	check(ring_part("reload_ring"):Visible(), "still reloading by the clock: the ring stays")
	check(near(ring_part("loading_ring_L1").rot[0], angle(2 / 13, 1), 0.05), "2 s of 13")
	H.step(9)
	check(near(ring_part("loading_ring_L2").rot[0], angle(11 / 13, 2), 0.05), "11 s of 13: the second half turns")
	H.step(2.5)
	check(not ring_part("reload_ring"):Visible(), "ready: the ring hides")
end

T.the_ring_survives_the_shooter_dying = function()
	crossbowmen({type = GUNNERS})
	H.tap("Left mouse") H.step(6)
	H.E.F.model.alive = false H.step(1 / 60)
	H.step(0.5)
	check(H.E.F.on and not H.logged("derpy_tp: error"), "no error when the next man takes over")
end

-- the logic audit, 2026-10-14 (fresh reviewer; each reproduced in the harness before it was fixed) ---------------
local function xbow_with(abilities, extra)
	local o = {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960, abilities = abilities}
	for k, val in pairs(extra or {}) do o[k] = val end
	return playing(o)
end

-- the author's arming: "1 is pressed, button highlights, stop melee or shooting". Arming mid-shot froze the shot:
-- W did nothing, and the bolt was never loosed
T.arming_stops_the_shot_and_frees_his_feet = function()
	xbow_with({BARRAGE})
	H.tap("Left mouse") H.step(0.2)
	check(H.E.F.shot, "aiming")
	H.tap("1") H.step(1 / 60)
	check(H.E.F.armed and H.E.F.shot == nil and not H.E.F.want_shot, "armed: the shot is dropped")
	local steers = H.count("steer")
	H.down("W") H.step(1) H.up("W")
	check(H.count("steer") > steers, "and W walks him while armed")
end

T.arming_stops_ground_fire = function()
	H.fresh({units = {{general = true, type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10, abilities = {BARRAGE}}}})
	H.tap("F2") H.step(0.1)
	H.tap("Left mouse") H.step(1 / 60)
	check(H.E.F.firing, "firing at the ground")
	H.tap("1") H.step(1 / 60)
	check(H.E.F.armed and not H.E.F.firing, "armed: the fire order is stopped")
	local gotos = H.count("uc:goto_location")
	H.down("W") H.step(2) H.up("W")
	check(H.count("uc:goto_location") > gotos, "and W walks him while armed")
end

T.the_casting_click_fires_no_shot = function()
	xbow_with({BARRAGE})
	H.tap("1") H.step(1 / 60)
	H.down("Left mouse") H.step(0.1) H.up("Left mouse")
	H.step(2)
	check(H.count("uc:perform_special_ability_ground") == 1, "the click cast")
	check(H.count("launch") == 0, "and loosed nothing as the button was let go: " .. H.count("launch"))
	H.tap("Left mouse") H.step(2)
	check(H.count("launch") == 1, "the next click shoots")
end

-- measured: can_perform_special_ability stays true through a cooldown, so the order went out and the unit was
-- handed back to its last move
T.an_ability_cooling_down_does_not_arm_or_cast = function()
	H.fresh({units = {{general = true, abilities = {BARRAGE}}}})
	local t = hud_cco({BARRAGE}, {[BARRAGE] = 30})
	t["BattleAbilityList.At(0).SetupAbilityContext.UnitSpecialAbilityRecordContext.TargetGround"] = true
	H.cco = t
	H.tap("F2") H.step(0.3)
	H.tap("1") H.step(1 / 60)
	H.tap("Left mouse") H.step(1 / 60)
	check(H.E.F.armed == nil and H.count("uc:perform_special_ability_ground") == 0, "cooling: neither armed nor cast")
	t["BattleAbilityList.At(0).RechargeTimeRemainingSecs"] = -1 -- -1: no cooldown (measured)
	H.tap("1") H.step(1 / 60)
	check(H.E.F.armed, "ready again: it arms")
end

T.with_the_hud_off_the_next_unit_casts_through_its_own_context = function()
	H.fresh({units = {{general = true, abilities = {"wh_test_a"}}, {abilities = {"wh_test_b"}, x = 30}}})
	local a, b = ability_record({}), ability_record({})
	a["BattleAbilityList.At(0).SetupAbilityContext.RecordKey"] = "wh_test_a"
	b["BattleAbilityList.At(0).SetupAbilityContext.RecordKey"] = "wh_test_b"
	a.IconPath = function() error("test: portrait") end
	H.cco_ids = {cco_1 = a, cco_2 = b}
	H.tap("F2") H.step(0.1)
	H.units[1].unary_hitpoints = function() error("test: health") end
	H.units[1].initial_number_of_men = function() error("test: men") end
	H.step(1 / 60)
	check(not find_uicomponent(H.root, "derpy_tp_hud"):Visible(), "three HUD errors: the HUD is off")
	H.tap("F2")
	H.select(H.units[2])
	H.tap("F2") H.step(0.1)
	H.tap("1") H.step(1 / 60)
	local c = H.last("cco_cmd")
	check(c and c[3] == "cco_2", "unit 2's key 1 runs on unit 2's ability: " .. tostring(c and c[3]))
end

T.f2_off_and_on_keeps_the_reload = function()
	local launches = {}
	for _, cycle in ipairs({false, true}) do
		xbow_with({}, {reload_slot = 1564})
		H.tap("Left mouse") H.step(5.5)
		check(H.E.F.shot and H.E.F.shot.phase == "reload", "reloading")
		if cycle then H.tap("F2") H.tap("F2") H.step(0.1) end
		H.tap("Left mouse") H.step(1.5)
		launches[#launches + 1] = H.count("launch")
	end
	check(launches[2] == launches[1], "F2 off and on mid reload shoots no sooner: " .. launches[1] .. " vs " .. launches[2])
end

T.a_hidden_enemy_is_not_a_target = function()
	armed_on({enemies = {{x = 0, z = 50, hidden = true}}})
	project()
	H.tap("1") H.step(0.3)
	check(hud_part("target").text == "No enemy in sight" and not arrow():Visible(), "hidden: not named, not marked")
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("uc:perform_special_ability") == 0, "and not cast at")
end

T.leaving_gives_back_the_players_own_fire_setting = function()
	xbow_with({}, {hold_fire = true})
	check(H.units[2]._faw == false, "holding fire while he shoots alone")
	H.tap("F2")
	check(H.units[2]._faw == false, "the player had it on hold fire: it stays on hold fire")
	xbow_with({})
	H.tap("F2")
	check(H.units[2]._faw == true, "fire at will before: fire at will after")
end

T.paused_the_arrow_still_follows_the_camera = function()
	armed_on({enemies = {{x = 0, z = 50}}})
	H.w2s = function(x) return 960 + (x - H.eye.x) * 10, 540, 0.5 end
	H.tap("1") H.step(0.3)
	local x0 = arrow().x
	H.paused = true H.step(1)
	H.mouse = {400, 0} H.step(1)
	check(arrow().x ~= x0, "the camera turned while paused: the arrow moved with it, " .. x0 .. " to " .. arrow().x)
	H.paused = false
end

-- the author, 2026-10-15: "cannot trigger melee attack of warmachines". Measured: the Greybeard tank's crew all have
-- ATTACK_1-5 (454-458); a landship's crew have none. A swing goes to the men who have the clip; none, an order
T.a_war_machine_swings_with_a_crew_that_has_the_clip = function()
	H.fresh({units = {{general = true, men = 5, war_machine = true, type = "wh_main_dwf_cha_greybeard_tank"}},
		enemies = {{x = 0, z = 20}}})
	H.tap("F2") H.step(0.1)
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("play") == 5 and H.count("uc:attack_unit") == 0, "the crew swing: " .. H.count("play"))
	H.fresh({units = {{general = true, men = 5, war_machine = true, slots = {[1557] = true}}}, enemies = {{x = 0, z = 20}}})
	H.tap("F2") H.step(0.6) -- clear of the start's halt
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("play") == 0, "no clip sent to a crew without it")
	check(H.count("uc:attack_unit") == 1, "an attack order on the enemy ahead instead")
end

-- the author, 2026-10-15: "other ranged units lose their ranged option". Measured: 15 of the 16 ranged units in his
-- army are modded and data.lua (db.pack's) has no shot for them; each unit's own context carries it
T.a_modded_shooter_takes_his_shot_from_his_own_context = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_rifle", men = 21, x = 40, range = 145, ammo = 100}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "heavy_rifle", 12
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	check(H.E.F.model and H.E.F.solo and H.E.F.ranged, "one man, shooting alone, in ranged mode")
	H.tap("Left mouse") H.step(2)
	local c = H.last("launch")
	check(c and c[2] == "heavy_rifle", "his own projectile: " .. tostring(c and c[2]))
end

-- the author, 2026-10-15: "other units dont respond or face left/right/back when pressing the direction buttons unlike
-- single entity units". Measured: steered with the camera's facing, a man pressed left walked mostly forward; faced
-- along his walk he went left. He walks facing where he goes, and keeps that facing when he stops
T.one_man_faces_where_he_walks = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("D") H.step(0.5)
	local c = H.last("steer")
	check(c and math.abs(c[6] - H.E.rig.yaw - math.pi / 2) < 0.05, "D: facing his right, not the camera: "
		.. tostring(c and c[6]) .. " vs camera " .. H.E.rig.yaw)
	H.up("D") H.step(0.2)
	local h = H.last("hold")
	check(h and math.abs(h[5] - c[6]) < 0.05, "stopped: he keeps facing that way")
end

-- a swing turns him back to the crosshair: the walk's facing is dropped
T.a_swing_turns_a_walked_man_back_to_the_crosshair = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("D") H.step(0.5) H.up("D") H.step(0.2)
	H.tap("Left mouse") H.step(5)
	local h = H.last("hold")
	check(h and math.abs(h[5] - H.E.rig.yaw) < 0.05, "after the swing he faces the camera: "
		.. tostring(h and h[5]) .. " vs " .. H.E.rig.yaw)
end

-- and so does a shot
T.a_shot_turns_a_walked_man_back_to_the_crosshair = function()
	crossbowmen()
	H.down("D") H.step(0.5) H.up("D") H.step(0.2)
	H.tap("Left mouse") H.step(12)
	local h = H.last("hold")
	check(h and math.abs(h[5] - H.E.rig.yaw) < 0.05, "after the shot he faces the camera: "
		.. tostring(h and h[5]) .. " vs " .. H.E.rig.yaw)
end

-- the author, 2026-10-15: "projectile fired even before the animation played (previously working)". Fire is now sent
-- before the raise ends; the engine reports the fire clip at once but plays it from the raise's end, so the shot
-- leaves SHOT_DELAY after the raise's end, not after the command
T.an_early_fire_command_still_waits_for_the_fire_clip = function()
	crossbowmen()
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	local function launch_after_aim()
		local seen, aim_at = #H.all("play"), nil
		local launches = H.count("launch")
		H.down("Left mouse")
		for _ = 1, 400 do
			H.step(1 / 60)
			local all = H.all("play")
			for i = seen + 1, #all do if all[i][3] == 1554 and not aim_at then aim_at = H.game_ms end end
			seen = #all
			if H.count("launch") > launches then H.up("Left mouse") return H.game_ms - aim_at end
		end
		H.up("Left mouse")
	end
	local first = launch_after_aim()
	H.step(15)
	local second = launch_after_aim()
	check(second and second >= first - 20, "the shot leaves no sooner after the raise than the first did: "
		.. tostring(first) .. " then " .. tostring(second) .. " ms")
end

-- the author, 2026-10-14: "abilities active doesnt have a active ring on the hud, no countdown timer as well,
-- especially self buff". CA's button: the green timer ring halves while IsActive (hud_battle.twui.xml)
T.a_running_ability_shows_the_green_ring_and_its_seconds_left = function()
	hud_on({abilities = {"a1"}})
	local at = "BattleAbilityList.At(0)."
	H.cco[at .. "IsActive"], H.cco[at .. "ActiveTimeRemainingSecs"] = true, 7.3
	H.step(0.3)
	check(hud_part("slot_1_active_l"):Visible() and hud_part("slot_1_active_r"):Visible(), "running: the green ring")
	check(hud_part("slot_1_cool").text == "8" and hud_part("slot_1_coolplate"):Visible(), "and its seconds left: "
		.. tostring(hud_part("slot_1_cool").text))
	H.cco[at .. "IsActive"], H.cco[at .. "ActiveTimeRemainingSecs"] = false, 0
	H.cco[at .. "RechargeTimeRemainingSecs"] = 20.5
	H.step(0.3)
	check(not hud_part("slot_1_active_l"):Visible() and not hud_part("slot_1_active_r"):Visible(), "ended: no ring")
	check(hud_part("slot_1_cool").text == "21", "then the cooldown's seconds")
end

-- measured 2026-10-15: a ground cast (the engineers' turret) went through and sat "selected" with 84 s of wind-up,
-- and the HUD showed nothing, so it looked dead. CA's timer ring has a wind_up state: its plain ring at #C0FFFFFF
T.a_winding_up_ability_shows_the_plain_ring_and_its_seconds = function()
	hud_on({abilities = {"a1"}})
	local at = "BattleAbilityList.At(0)."
	H.cco[at .. "WindUpTimeRemainingSecs"] = 83.2
	H.step(0.3)
	check(hud_part("slot_1_windup_l"):Visible() and hud_part("slot_1_windup_r"):Visible(), "winding up: the plain ring")
	check(not hud_part("slot_1_active_l"):Visible(), "not the green one")
	check(hud_part("slot_1_cool").text == "84", "and the wind-up's seconds: " .. tostring(hud_part("slot_1_cool").text))
	H.cco[at .. "WindUpTimeRemainingSecs"] = -1
	H.cco[at .. "IsActive"], H.cco[at .. "ActiveTimeRemainingSecs"] = true, 30
	H.step(0.3)
	check(not hud_part("slot_1_windup_l"):Visible() and hud_part("slot_1_active_l"):Visible(), "then running: green")
end

-- the author, 2026-10-14: "out of range enemies using debuff spell still spells out, no enemy in range". An
-- ability reaches as far as its own TargetRange (CcoUnitAbility, "the maximum range of a target")
local function ranged_ability(flags, range, enemies)
	H.fresh({units = {{general = true, abilities = {MOD}}}, enemies = enemies})
	local t = ability_record(flags)
	t["BattleAbilityList.At(0).SetupAbilityContext.TargetRange"] = range
	H.cco = t
	project()
	H.tap("F2") H.step(0.1)
end

T.an_enemy_past_the_abilitys_range_is_out_of_range = function()
	ranged_ability({TargetEnemies = true}, 40, {{x = 0, z = 50}})
	H.tap("1") H.step(0.3)
	check(hud_part("target").text == "Out of range" and not arrow():Visible(), "50 m away, 40 m reach: "
		.. tostring(hud_part("target").text))
	H.tap("Left mouse") H.step(1 / 60)
	check(H.count("uc:perform_special_ability") == 0, "not cast")
	ranged_ability({TargetEnemies = true}, 40, {{x = 0, z = 30}})
	H.tap("1") H.step(0.3)
	check(hud_part("target").text ~= "Out of range" and arrow():Visible(), "30 m away: in reach")
	H.tap("Left mouse") H.step(1 / 60)
	local c = H.last("uc:perform_special_ability")
	check(c and c[4] == H.enemies[1], "and cast at")
end

T.a_ground_ability_lands_no_farther_than_its_range = function()
	ranged_ability({TargetGround = true}, 20)
	H.ground = function(_, z) return z * 0.01 end -- a gentle rise the view still meets ~37 m off
	H.tap("1") H.step(0.3)
	H.tap("Left mouse") H.step(1 / 60)
	local c = H.last("uc:perform_special_ability_ground")
	check(c and math.abs(c[4].z - 20) < 0.5, "the crosshair's ground is ~37 m off; a 20 m reach lands at 20: " .. tostring(c and c[4].z))
	check(math.abs(c[4].y - H.ground(c[4].x, c[4].z)) < 0.01, "on the ground there, not in the air: " .. c[4].y)
end

-- the author, 2026-10-14: "weapons teleport in transitioning from ready aim animation to fire animation". The raise to
-- aim (1554) is a transition clip: when it ends the engine settles him in its shooting idle, and a fire clip sent
-- after that starts from the idle pose. The first shot learns how long the raise runs; later shots send fire before
-- it ends, so the engine goes from the raise straight into the fire clip
local function aim_to_fire_gap()
	local aim_at, fire_at
	local seen = #H.all("play")
	H.down("Left mouse")
	for _ = 1, 400 do
		H.step(1 / 60)
		local all = H.all("play")
		for i = seen + 1, #all do
			if all[i][3] == 1554 and not aim_at then aim_at = H.game_ms end
			if all[i][3] == 1557 and aim_at and not fire_at then fire_at = H.game_ms end
		end
		seen = #all
		if fire_at then H.up("Left mouse") return fire_at - aim_at end
	end
	H.up("Left mouse")
end

T.later_shots_send_fire_before_the_raise_ends = function()
	crossbowmen()
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	local first = aim_to_fire_gap()
	check(first and first >= 1000, "the first shot waits for the raise to end: " .. tostring(first) .. " ms")
	H.step(15)
	local second = aim_to_fire_gap()
	check(second and second < 1000 and second >= 700, "the next sends fire before the 1000 ms raise ends: "
		.. tostring(second) .. " ms")
end

-- the author, 2026-10-14: "the player should always have absolute control of the unit and no auto attack". Measured
-- 2026-10-15: keeping script control changed nothing in a melee; what acts on its own is fire at will (a ranged unit
-- played whole shot whatever came in range) and pursuit. So every ranged unit holds its fire while played, and every
-- unit keeps its ground (the defend behaviour), both given back as they were
T.a_unit_played_whole_shoots_only_when_told = function()
	H.fresh({units = {{general = true, type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.1)
	check(H.units[1]._faw == false, "played: no fire at will")
	H.tap("F2")
	check(H.units[1]._faw == true, "let go: fire at will back")
end

-- measured 2026-10-15 (Heavythunder, enemy 26-36 m): with fire at will off a ground-fire order loosed nothing in 20 s;
-- the regiment's ground fire is fire at will pointed at the ground. So it is on while he shoots, off otherwise
T.fire_at_will_is_on_only_while_he_shoots = function()
	H.fresh({units = {{general = true, type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.1)
	check(H.units[1]._faw == false, "not shooting: holding fire")
	H.tap("Left mouse") H.step(1 / 60)
	check(H.E.F.firing and H.units[1]._faw == false, "the click: not yet, the order waits its half second")
	H.step(0.5)
	check(H.E.F.firing and H.units[1]._faw == true, "the fire order: fire at will, at the ground he aims at")
	H.step(6)
	check(not H.E.F.firing and H.units[1]._faw == false, "the shot done: holding fire again")
end

T.a_played_unit_keeps_its_ground_and_gets_its_setting_back = function()
	H.fresh({units = {{general = true, men = 1}}})
	H.tap("F2") H.step(0.1)
	check(H.units[1]._defend == true, "played: it keeps its ground, no pursuit")
	H.tap("F2")
	check(H.units[1]._defend == false, "let go: as the player had it")
	H.fresh({units = {{general = true, men = 1, defend = true}}})
	H.tap("F2") H.step(0.1) H.tap("F2")
	check(H.units[1]._defend == true, "the player's own guard stays on")
end

T.arming_on_the_first_frame_is_no_error = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}}}, enemies = {{x = 0, z = 50}}})
	project()
	H.down("F2") H.step(1 / 60) H.up("F2") H.down("1") H.step(1 / 60) H.up("1") H.step(0.3)
	check(not H.logged("derpy_tp: error") and not H.logged("HUD part"), "no error before the camera has a first frame")
end


-- the author, 2026-10-15: "cant move shoot or use melee attack flying helicopter" (then: a gyro gunship's crew steered
-- nothing, and flyers were played whole); 2026-10-17: "flying units still controls the whole battalion as well when
-- moving". Measured live on today's steering (probes/zz_tp_fly_one.lua, the Birdmen of Catrazza): one man went 14-17 m
-- in 3 s on W, in the air and landed, the rest of his regiment under 2 m. One man of a flyer, as of any regiment
T.a_flying_unit_is_played_one_man = function()
	playing({type = "teb_birdmen", men = 16, can_fly = true, flying = true, x = 40})
	check(H.E.F.model ~= nil, "one man, not the whole regiment")
	H.down("W") H.step(1) H.up("W")
	check(H.count("steer") > 0 and H.count("uc:goto_location") == 0, "W steers him and orders the regiment nowhere")
	playing({type = "teb_birdmen", men = 16, can_fly = true, flying = true, range = 100, ammo = 10, x = 40,
		slots = {[42] = true, [454] = true, [1557] = true}})
	check(H.E.F.model ~= nil and H.E.F.solo and H.E.F.ranged, "a shooting one too, and he shoots alone")
end

-- the author, 2026-10-15: "im still controlling the entire weapons team". Measured: each of a rocket team's 12 men has
-- FIRE_LEVEL and no raise or reload clip. One man fires the clip, and his reload is the projectile's time on the clock
local function rocket_man()
	H.fresh({units = {{general = true}, {type = "zorn_test_rockets", men = 12, x = 40, range = 255, ammo = 100,
		reload_slot = false, slots = {[454] = true, [135] = true, [489] = true, [1557] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 20
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
end
-- the author, 2026-10-15: "it happens when switching to ranged", "it also triggers the whole battalion to shoot or
-- throw" (Exalted Plaguebearers). Measured: their man has no FIRE_LEVEL; the Death's Head is thrown from GRENADIER (949,
-- hu04d_plaguebearer_favoured_missile_attack_grenadier_01, FIRE_POS at 1.962 s). He throws it alone
T.an_exalted_plaguebearer_throws_his_death_head_alone = function()
	local u = playing({type = "wh3_main_nur_inf_plaguebearers_1", men = 20, x = 40, range = 70, ammo = 10,
		reload_slot = false, slots = {[42] = true, [454] = true, [949] = true}})
	local man = H.E.F.model
	check(man ~= nil and H.E.F.solo and H.E.F.ranged, "one man, throwing alone")
	H.tap("Left mouse") H.step(0.1)
	local p = H.last("play")
	check(p and p[2] == man.id and p[3] == 949, "the grenade throw, on him only: " .. tostring(p and p[3]))
	H.step(1.7)
	check(H.count("launch") == 0, "not before the throw's release")
	H.step(0.4)
	check(H.count("launch") == 1 and u._ammo == 9, "one Death's Head at 1.96 s: " .. H.count("launch"))
	check(H.count("uc:attack_location") == 0 and H.E.F.model == man, "the regiment never fires, the camera stays on him")
end

-- the author, 2026-10-17: "are mounted archers not supported? they are missing their ranged option". Measured
-- (tools/third_person_fires.py's bins, the installed packs): 165 mounted missile units' riders have no FIRE_LEVEL or
-- GRENADIER and shoot from RIDER_FIRE_FORWARD_LEVEL (2105), Kislev's Horse Archers among them
T.a_horse_archer_shoots_from_the_saddle_alone = function()
	H.fresh({units = {{general = true}, {type = "wh3_main_ksl_cav_horse_archers_0", men = 20, x = 40, range = 160,
		ammo = 10, reload_slot = false, slots = {[42] = true, [2105] = true}}}})
	local u = H.units[2]
	for i, m in ipairs(u._models) do m.mount = {id = 990 + i, x = m.x, y = m.y, z = m.z, hp = 100, hp_max = 100} end
	H.select(u) H.tap("F2") H.step(0.1)
	local man = H.E.F.model
	check(man ~= nil and H.E.F.solo and H.E.F.ranged, "one rider, with his ranged mode")
	H.tap("Left mouse") H.step(0.1)
	local p = H.last("play")
	check(p and p[2] == man.id and p[3] == 2105, "the forward shot from the saddle, on him: " .. tostring(p and p[3]))
	H.step(3)
	check(H.count("launch") == 1 and u._ammo == 9, "one arrow: " .. H.count("launch"))
	check(H.count("uc:attack_location") == 0, "the regiment never fires")
end

T.a_weapon_team_man_fires_alone_and_reloads_on_the_clock = function()
	rocket_man()
	check(H.E.F.model ~= nil and H.E.F.solo and H.E.F.ranged, "one man of the team, shooting alone")
	H.down("Left mouse") H.step(15)
	check(H.count("launch") == 1, "one rocket, then the reload: " .. H.count("launch"))
	check(H.count("uc:attack_location") == 0, "the team is never ordered to fire")
	H.step(15) H.up("Left mouse")
	check(H.count("launch") == 2, "20 s on, the next: " .. H.count("launch"))
end

T.an_artillery_crew_swings_on_a_click = function()
	playing({type = "wh_test_mortar", men = 6, arty = true, x = 40})
	H.tap("Left mouse") H.step(1 / 60)
	local p = H.last("play")
	check(p and p[3] == 454, "the crew swing ATTACK_1: " .. tostring(p and p[3]))
end

-- the author, 2026-10-15: "q for charge animation when running", "the animation being triggered with q is not the
-- attack", then "charging running should be triggered with q as a continuious press"; 2026-10-16: "shift button as the
-- charge or sprint button". Shift held on the move is the charge:
-- CHARGE (135) at mask 6, sent again inside its sub-second cycle (measured: he keeps his speed under it); a left click
-- in the charge throws the charge attack, MOVING_ATTACK_1-2 (484-485, the only two any unit has, measured)
local function runs() local n = 0 for _, c in ipairs(H.all("play")) do if c[3] >= 484 and c[3] <= 488 then n = n + 1 end end return n end
local function plays_of(slot) local n = 0 for _, c in ipairs(H.all("play")) do if c[3] == slot then n = n + 1 end end return n end
local CHARGE = 135
local function charges() local n = 0 for _, c in ipairs(H.all("play")) do if c[3] == CHARGE and c[4] == 6 then n = n + 1 end end return n end

T.shift_held_on_the_move_charges_for_as_long_as_it_is_held = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("Shift") H.step(1) H.up("Shift")
	check(charges() == 0, "standing: no charge")
	H.down("W") H.step(0.3)
	local walks = plays_of(42)
	H.down("Shift") H.step(5)
	check(charges() >= 6, "5 s held: still charging: " .. charges())
	check(plays_of(42) == walks, "the walk does not cut the charge clip")
	H.up("Shift") H.step(0.1)
	local p = H.last("play")
	check(p and p[3] == 42 and p[4] == 0, "let go: the clip ends")
	H.up("W")
end

T.a_click_in_the_charge_throws_the_charge_attack = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.step(0.3)
	H.down("Shift") H.step(0.5)
	H.tap("Left mouse") H.step(1 / 60)
	local p = H.last("play")
	check(p and p[3] == 484, "MOVING_ATTACK_1: " .. tostring(p and p[3]))
	check(p[4] == 1, "over his torso and arms (the exe's mask 1, TORSO_AND_ARMS), his legs left to the run: " .. tostring(p[4]))
	check(plays_of(454) == 0, "not a standing swing")
	local n, walks = charges(), plays_of(42)
	H.step(1)
	check(charges() == n, "the attack plays out: no charge clip over it")
	check(plays_of(42) == walks, "nor the walk that ends the charge")
	H.up("Shift") H.up("W")
end

T.the_charge_attack_cools_down = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(4)
	H.tap("Left mouse") H.step(0.1)
	check(runs() == 1, "cooling down: the click is a plain swing, " .. runs())
	H.up("Shift") H.step(7)
	H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(0.1)
	check(runs() == 2, "cooled: the next charge attack, " .. runs())
	H.up("Shift") H.up("W")
end

T.no_charge_for_a_unit_without_the_clips = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[454] = true, [42] = true}}, {{x = 40, z = 20}})
	H.down("W") H.step(0.3)
	H.down("Shift") H.step(1) H.tap("Left mouse") H.step(0.1) H.up("Shift") H.up("W")
	check(charges() == 0 and runs() == 0, "no clips: no charge and no charge attack")
	check(plays_of(454) == 1, "the click is a plain swing")
end

-- a single entity has no steered man and no walk to end the clip: the charge ends it
T.a_lord_charges_too_and_the_charge_ends_on_release = function()
	general_on() H.step(0.1)
	H.down("W") H.down("Shift") H.step(1)
	check(charges() > 0, "the general charges")
	H.up("Shift") H.step(1 / 60)
	local p = H.last("play")
	check(p and p[3] == 42 and p[4] == 0, "let go: the clip ends")
	H.up("W")
end

-- the author, 2026-10-15: "e doesnt work effectively, it should let its animation play without being overrided with
-- different buttons". Measured: anything sent to him cuts the clip - the walk's unlatch, the next swing, a step - so
-- while a jump or charge attack runs nothing is: it ends when the clip does (or after LOCK_MAX)
T.a_jump_plays_out_whatever_is_pressed = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("E") H.step(0.1) -- Shift on the move would charge, were he free
	local steers, walks = H.count("steer"), plays_of(42)
	H.down("W") H.step(0.5) H.tap("Left mouse") H.step(0.5) H.down("Shift") H.step(0.5) H.up("Shift")
	check(plays_of(454) == 0 and charges() == 0, "no swing and no charge over it")
	check(H.count("steer") == steers and plays_of(42) == walks, "no step and no walking clip over it")
	H.step(3)
	check(H.count("steer") > steers, "the clip over: he walks again")
	H.up("W")
end

-- the author, 2026-10-15: "spamming left button while walking does nothing, melee should be prioritized". A swing held no
-- lock: the walk went on under it, and its unlatch played WALK_1 over the clip. A click while walking swings, and the
-- walk waits for the clip, as it does for the jump
T.a_swing_while_walking_plays_out = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.S.swing_cooldown = 1.5 -- a gap shorter than the clip and LOCK_MAX: the hold ends with the gap
	H.down("W") H.step(0.5)
	H.tap("Left mouse") H.step(0.1)
	local steers, walks = H.count("steer"), plays_of(42)
	H.step(0.5)
	check(plays_of(454) == 1, "the swing plays")
	check(H.count("steer") == steers and plays_of(42) == walks, "no step and no walking clip over it: steers "
		.. H.count("steer") - steers .. ", walking clips " .. plays_of(42) - walks)
	H.step(1.6) -- 2.7 s: the 4 s clip and LOCK_MAX (3 s) not over, the swing cooldown (1.5 s) is
	check(H.count("steer") > steers, "held to the swing cooldown at most: he walks again")
	H.up("W")
end

-- with no clip to swing, nothing waits on a clip that never plays; and his regiment gets no attack order in its place
-- (the author, 2026-10-15 21:46: one man gives his regiment no orders)
T.a_swing_with_no_clip_does_not_hold_the_walk = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[42] = true}}, {{x = 40, z = 30, men = 10}}) -- no ATTACK clip
	H.step(0.5)
	H.tap("Left mouse") H.step(0.1)
	check(H.count("uc:attack_unit") == 0, "no attack order to his regiment")
	local steers = H.count("steer")
	H.down("W") H.step(0.3)
	check(H.count("steer") > steers, "W walks him at once, no lock left behind")
	H.up("W")
end

T.the_charge_attack_plays_out_too = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(0.1)
	local n, walks = #H.all("play"), plays_of(42)
	H.step(1)
	check(#H.all("play") == n and plays_of(42) == walks, "no clip sent over the attack: " .. (#H.all("play") - n))
	H.up("Shift") H.up("W")
end

-- the author, 2026-10-16: "charge attack while sprinting comepletely stops the player and stops its legs". He threw it
-- standing: the lock steered nothing, and the walk ran out 3 m on. He runs on through it, at the sprint
T.the_charge_attack_is_thrown_on_the_run = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(0.1)
	check(H.last("play")[3] == 484, "the charge attack is under way")
	local steers = H.count("steer")
	H.step(1)
	check(H.count("steer") >= steers + 50, "he is steered on through it, every frame: " .. (H.count("steer") - steers))
	check(near(H.last("steer")[7], 1.5), "at the sprint: " .. tostring(H.last("steer")[7]))
	check(near(H.last("steer")[6], H.E.F.face_yaw), "along his own facing")
	H.up("Shift") H.up("W")
end

-- the jump stands him: no sprint through it, and no stamina spent on it
T.a_jump_on_the_sprint_ends_it = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	check(H.E.F.sprinting, "sprinting")
	H.tap("E") H.step(0.1)
	local st = H.E.F.stamina
	H.step(1)
	check(not H.E.F.sprinting and not hud_part("act_sprint_active_l"):Visible(), "in the jump: not sprinting")
	check(H.E.F.stamina > st, "the stamina comes back in it: " .. st .. " then " .. H.E.F.stamina)
	H.up("Shift") H.up("W")
end

-- measured 2026-10-16 (probes/zz_tp_charge_run.lua, Akshina's Ambushers): steered under it, MOVING_ATTACK at any mask
-- but 0 stays latched until WALK_1, past its 1.6 s, and his arms held its last pose to the 3 s cap. The lock ends with
-- the clip, data.lua's runs (its .anim's length) and the engine's late start, and frees it: WALK_1, or CHARGE sprinting
T.the_charge_attack_frees_his_arms_when_its_clip_ends = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.D.runs = {wh_test_melee = 1.6}
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(1 / 60)
	H.up("Shift")
	local walks = plays_of(42)
	H.step(1.6)
	check(plays_of(42) == walks, "not before the clip's 1.6 s and its late start")
	H.step(0.4)
	check(plays_of(42) == walks + 1, "then WALK_1 frees it: " .. (plays_of(42) - walks))
	H.up("W")
end

-- stopped in it: standing never unlatches (move.lua does that on the move), so the lock's end does
T.a_charge_attack_he_stops_in_frees_his_arms_too = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.D.runs = {wh_test_melee = 1.6}
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(0.1)
	H.up("Shift") H.up("W")
	local walks = plays_of(42)
	H.step(2)
	check(plays_of(42) == walks + 1, "standing, WALK_1 frees it: " .. (plays_of(42) - walks))
end

T.sprinting_on_past_the_charge_attack_the_charge_frees_it = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.D.runs = {wh_test_melee = 1.6}
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(1 / 60)
	local n = charges()
	H.step(1.6)
	check(charges() == n, "no charge clip over it")
	H.step(0.4)
	check(charges() == n + 1 and H.last("play")[3] == CHARGE, "then the charge: " .. (charges() - n))
	check(plays_of(42) == 0, "and no WALK_1 to cut between")
	H.up("Shift") H.up("W")
end

-- a modded unit data.lua has no length for: the cap
T.a_charge_attack_with_no_length_holds_to_the_cap = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.D.runs = {}
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(1 / 60)
	H.up("Shift")
	local walks = plays_of(42)
	H.step(2.8)
	check(plays_of(42) == walks, "held to the 3 s cap")
	H.step(0.4)
	check(plays_of(42) == walks + 1, "then freed")
	H.up("W")
end

-- Shift let go in the attack: the sprint ends but not the clip (WALK_1 would cut it), and he runs on at his own pace
T.letting_go_of_shift_in_the_charge_attack_does_not_cut_it = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	H.tap("Left mouse") H.step(0.1)
	local walks = plays_of(42)
	H.up("Shift") H.step(0.5)
	check(plays_of(42) == walks, "no WALK_1 over the attack")
	check(H.count("steer") > 0 and (H.last("steer")[7] or 1) == 1, "running on at his own speed")
	H.step(3)
	check(H.last("play")[3] == 42, "the clip over, the walk takes him again")
	H.up("W")
end

-- a regiment steered whole: the attack is no reason to stop its run either
T.a_regiment_throws_the_charge_attack_on_the_run = function()
	general_on() H.step(0.5)
	H.down("W") H.down("Shift") H.step(0.6)
	local halts = H.count("uc:halt")
	H.tap("Left mouse") H.step(0.1)
	check(runs() > 0, "the charge attack")
	local orders = H.count("uc:goto_location")
	H.down("D") H.step(0.6)
	check(H.count("uc:goto_location") > orders, "turned in it: a new order")
	check(H.count("uc:halt") == halts, "never halted: " .. (H.count("uc:halt") - halts))
	H.up("D") H.up("Shift") H.up("W")
end

T.the_lock_ends_with_the_clip = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("E") H.step(0.1)
	H.E.F.model.anim_end = H.game_ms + 900 -- a one-second clip
	local steers = H.count("steer")
	H.down("W") H.step(1.3)
	check(H.count("steer") > steers, "the clip over at 1 s: he walks, well before the cap")
	H.up("W")
end

T.a_clip_the_engine_never_ends_frees_him_after_the_cap = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.anim_hold = true
	H.tap("E") H.step(0.1)
	local steers = H.count("steer")
	H.down("W") H.step(3.2)
	check(H.count("steer") > steers, "3 s on, he walks again")
	H.anim_hold = false H.up("W")
end

-- the author, 2026-10-15: "e for jump attack animation". Measured: JUMPING_ATTACK_1-5 are 489-493 and play as a swing
T.e_jump_attacks_then_cools_down = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("E") H.step(1 / 60)
	local p = H.last("play")
	check(p and p[3] == 489, "JUMPING_ATTACK_1: " .. tostring(p and p[3]))
	local n = H.count("play")
	H.step(3.5) H.tap("E") H.step(1 / 60) -- past the clip, inside the 6 s
	check(H.count("play") == n, "cooling down: no second jump")
	H.step(7) H.tap("E") H.step(1 / 60)
	p = H.last("play")
	check(p and p[3] == 490, "cooled: the next one, JUMPING_ATTACK_2: " .. tostring(p and p[3]))
end

T.e_does_nothing_for_a_unit_without_the_clip = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[454] = true}}, {{x = 40, z = 20}})
	H.tap("E") H.step(1 / 60)
	check(H.count("play") == 0 and H.count("uc:attack_unit") == 0, "no clip: no swing and no attack order")
end

-- the author, 2026-10-15: "should show in the HUD the cooldown of each including melee and ranged"
T.the_action_bar_shows_what_the_unit_can_do = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	check(hud_part("act_walk_frame"):Visible() and hud_part("act_sprint_frame"):Visible()
		and hud_part("act_attack_frame"):Visible() and hud_part("act_jump_frame"):Visible(), "walk, sprint, attack and jump")
	check(not hud_part("act_fire_frame"):Visible(), "no fire for a unit that does not shoot")
	check(hud_part("act_walk_key").text == "Z" and hud_part("act_sprint_key").text == "Shift"
		and hud_part("act_jump_key").text == "E", "each with its key")
	crossbowmen()
	check(hud_part("act_fire_frame"):Visible(), "a shooter has fire")
end

-- a man who cannot shoot alone has no fire button: he has no ranged mode
T.the_action_bar_shows_no_fire_for_a_man_who_cannot_shoot_alone = function()
	H.fresh({units = {{general = true, type = "wh_test_mod_grenadiers", men = 20, range = 60, ammo = 10}}})
	H.tap("F2") H.step(0.1)
	check(H.E.F.model ~= nil and not hud_part("act_fire_frame"):Visible(), "no fire button")
end

T.the_action_bar_counts_each_cooldown_down = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	-- a swing holds him like an action: its clip over, E jumps
	H.tap("Left mouse") H.E.F.model.anim_end = H.game_ms + 100 H.step(0.2) H.tap("E") H.step(0.1)
	check(hud_part("act_attack_dim"):Visible() and hud_part("act_attack_cool").text == "4", "the swing's 4 s: "
		.. tostring(hud_part("act_attack_cool").text))
	check(hud_part("act_jump_cool").text == "10", "the jump's 10 s: " .. tostring(hud_part("act_jump_cool").text))
	H.step(4)
	check(not hud_part("act_attack_dim"):Visible() and not hud_part("act_attack_coolplate"):Visible(), "swing ready again")
	H.step(6)
	check(not hud_part("act_jump_dim"):Visible(), "jump ready again")
end

T.the_action_bar_shows_the_charge_then_its_cooldown = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.3)
	check(hud_part("act_sprint_active_l"):Visible() and not hud_part("act_sprint_dim"):Visible(), "charging: the green ring")
	H.tap("Left mouse") H.step(0.1)
	-- thrown on the run (2026-10-16), the sprint goes on: its ring stays lit
	check(hud_part("act_sprint_active_l"):Visible() and hud_part("act_sprint_cool").text == "10", "the attack thrown, still "
		.. "sprinting: 10 s to the next, " .. tostring(hud_part("act_sprint_cool").text))
	-- the seconds are its charge attack's; the sprint itself is still there, and dims only for want of stamina (lit and
	-- dimmed at once, CA's dim washed the ring out: seen in the preview, 2026-10-16)
	check(not hud_part("act_sprint_dim"):Visible(), "not dimmed: he can still sprint")
	H.up("Shift") H.up("W")
end

-- the author, 2026-10-15: "make shift be a long press or a toggable in the mct, default toggable and should be shown in
-- HUD"; 2026-10-16: "change, shift button as the charge or sprint button, add stamina bar, make z as the toggable walk,
-- all should be visible in the UI, pressing M should show mini map". He runs unless Z has him walk
T.z_toggles_walking_and_running_is_the_default = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	check(hud_part("act_walk_frame"):Visible() and hud_part("act_walk_key").text == "Z", "a Walk button, its key")
	check(not H.E.F.walking and not hud_part("act_walk_active_l"):Visible(), "running: unlit")
	H.down("W") H.step(0.6)
	check(H.last("steer")[5] == true, "he runs")
	H.tap("Z") H.step(0.1)
	check(H.E.F.walking and hud_part("act_walk_active_l"):Visible() and H.last("steer")[5] == false, "a tap: walking, lit")
	H.tap("Z") H.step(0.1)
	check(not H.E.F.walking and not hud_part("act_walk_active_l"):Visible() and H.last("steer")[5] == true,
		"a second tap: running")
	H.up("W")
end

T.walk_can_be_held_instead = function()
	H.fresh({mct = {combat_walk_hold = true}, units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.tap("Z") H.step(0.1)
	check(not H.E.F.walking, "a tap does not latch it")
	H.down("Z") H.step(0.2)
	check(H.E.F.walking and hud_part("act_walk_active_l"):Visible(), "held: walking, lit")
	H.up("Z") H.step(0.1)
	check(not H.E.F.walking, "let go: running")
end

-- Shift held on the move sprints: at the run whatever Z says, the charge clip, the charge attack on a click
T.shift_sprints_at_the_run_even_from_a_walk = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("Z") H.down("W") H.step(0.6)
	check(H.last("steer")[5] == false, "walking")
	H.down("Shift") H.step(0.3)
	check(H.E.F.sprinting and H.last("steer")[5] == true and hud_part("act_sprint_active_l"):Visible(),
		"Shift held: at the run, lit")
	H.up("Shift") H.step(0.1)
	check(not H.E.F.sprinting and H.last("steer")[5] == false and not hud_part("act_sprint_active_l"):Visible(),
		"let go: walking again")
	H.up("W")
end

-- a regiment played whole sprints too: its move order at the run
T.a_unit_played_whole_sprints_at_the_run = function()
	general_on() H.step(0.5)
	H.tap("Z") H.down("W") H.step(0.6)
	check(H.last("uc:goto_location")[4] == false, "walking")
	H.down("Shift") H.step(0.6)
	check(H.last("uc:goto_location")[4] == true, "Shift held: at the run")
	H.up("Shift") H.up("W")
end

-- stamina: a sprint empties it in 8 s; empty, the sprint stops until a quarter is back; it fills again in 12 s off it
T.a_sprint_spends_stamina_and_it_comes_back = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	check(H.E.F.stamina == 1 and hud_part("stamina_fill"):Visible() and hud_part("stamina_fill").w == L.fill.stamina_fill,
		"full at the start")
	H.down("W") H.down("Shift") H.step(4)
	local s = H.E.F.stamina
	check(s > 0.45 and s < 0.55, "4 s of sprint: half gone: " .. s)
	check(math.abs(hud_part("stamina_fill").w - L.fill.stamina_fill * s) <= 1, "the bar follows: "
		.. hud_part("stamina_fill").w)
	H.step(4.2)
	check(H.E.F.stamina < 0.05 and not H.E.F.sprinting and H.last("steer")[5] == true, "empty at 8 s: no sprint, still at the "
		.. "run: " .. H.E.F.stamina)
	local n = charges()
	H.step(1)
	check(charges() == n, "no charge clip on empty")
	check(hud_part("act_sprint_dim"):Visible(), "the sprint button dims")
	H.step(2.4)
	check(H.E.F.sprinting, "a quarter back: Shift still held sprints again")
	H.up("Shift") H.step(12)
	check(H.E.F.stamina == 1, "12 s off it: full again: " .. H.E.F.stamina)
	H.up("W")
end

-- M: CA's minimap. The cinematic UI hides CA's whole HUD, its radar with it, and not this panel: the radar moves into
-- the panel under the corner buttons while shown, and back into its holder, where it was, on M again or at the end
local function radar()
	local holder = H.comp("radar_holder", find_uicomponent(H.root, "hud_battle"))
	local r = H.comp("radar_group", holder)
	H.comp("speed_controls", holder)
	r.x, r.y, r.w, r.h = 1600, 40, 184, 184
	return holder, r
end
T.m_shows_the_minimap_and_puts_it_back = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	local holder, r = radar()
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	check(hud_part("map_frame"):Visible() and hud_part("map_key").text == "M" and not hud_part("map_active_l"):Visible(),
		"a Minimap button, on M, unlit")
	H.tap("M") H.step(0.1)
	check(r.parent == find_uicomponent(H.root, "derpy_tp_hud"), "shown: the radar is in the panel")
	local k = hud_part("hide_keyplate")
	check(math.abs(r.x + r.w - (1920 - 24)) <= 1 and r.y > k.y + k.h, "under the buttons, on the right margin: "
		.. r.x .. "," .. r.y)
	check(hud_part("map_active_l"):Visible(), "lit")
	H.tap("M") H.step(0.1)
	check(r.parent == holder and holder.kids[1] == r and r.x == 1600 and r.y == 40,
		"M again: back in its holder, first, where it was")
	check(not hud_part("map_active_l"):Visible(), "unlit")
	H.tap("M") H.step(0.1)
	H.tap("F2") H.step(0.1)
	check(r.parent == holder and holder.kids[1] == r and r.x == 1600 and r.y == 40, "third person off: back too")
end

-- three HUD errors switch the panel off: CA's radar goes back to its holder first, and M shows nothing after
T.the_hud_going_off_puts_the_minimap_back = function()
	H.fresh()
	local holder, r = radar()
	H.tap("F2") H.step(0.1)
	H.tap("M") H.step(0.1)
	check(r.parent ~= holder, "shown")
	H.units[1].unary_hitpoints = function() error("test: 1") end
	H.units[1].initial_number_of_men = function() error("test: 2") end
	H.cco.HealthValue = function() error("test: 3") end
	H.step(0.3)
	check(not find_uicomponent(H.root, "derpy_tp_hud"):Visible() and H.E.F.on, "the HUD is off, third person on")
	check(r.parent == holder and holder.kids[1] == r and r.x == 1600, "the radar back in its holder")
	H.tap("M") H.tap("M") H.step(0.1)
	check(r.parent == holder, "M shows nothing on a panel that is off")
end

-- the window lost mid-sprint: the sprint ends, and the stamina fills again rather than standing still
T.losing_the_window_ends_the_sprint = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(2)
	check(H.E.F.sprinting, "sprinting")
	H.focus = false H.step(2)
	check(not H.E.F.sprinting and H.E.F.stamina > 0.8, "unfocused: no sprint, filling again: " .. H.E.F.stamina)
	H.up("Shift") H.up("W")
end

T.with_no_minimap_m_does_nothing = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("M") H.step(0.1)
	check(H.E.F.on and not H.E.F.map and not hud_part("map_active_l"):Visible(), "nothing to show: off, and on we go")
end

-- the author, 2026-10-15: "smoother animation or turning rate when pressing side buttons and back". He turns at
-- S.turn_rate, walking along his facing, rather than snapping to the keys' direction
T.he_turns_toward_a_new_direction_at_a_rate = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.step(0.5) H.up("W")
	H.down("S") H.step(1 / 60)
	local c = H.last("steer")
	local yaw0 = H.E.rig.yaw
	local d = math.abs(((c[6] - yaw0) + math.pi) % (2 * math.pi) - math.pi)
	check(d < 0.2, "one frame into a turn about: still facing ahead, " .. d)
	local mx, _, mz = H.E.P.model_pos(H.E.F.model)
	check((c[3] - mx) * math.sin(yaw0) + (c[4] - mz) * math.cos(yaw0) > 0, "and still walking ahead, along his facing")
	H.step(1)
	c = H.last("steer")
	d = math.abs(((c[6] - yaw0) + math.pi) % (2 * math.pi) - math.pi)
	check(math.abs(d - math.pi) < 0.05, "a second on: facing back, " .. d)
	H.up("S")
end

T.after_an_action_he_still_turns_at_the_rate = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.step(0.5) H.up("W")
	local yaw0 = H.E.rig.yaw
	-- S held through the jump: the first step after it is the one measured
	H.tap("E") H.step(1 / 60) H.down("S")
	local before = H.count("steer")
	for _ = 1, 300 do H.step(1 / 60) if H.count("steer") > before then break end end
	local c = H.last("steer")
	local d = math.abs(((c[6] - yaw0) + math.pi) % (2 * math.pi) - math.pi)
	check(d < 0.4, "one frame into a turn after the jump: still near ahead, " .. d)
	H.up("S")
end

-- the author, 2026-10-15: "camera should also be close in melee"
T.in_melee_the_camera_comes_in = function()
	local function back(melee)
		H.fresh({units = {{general = true, melee = melee}}})
		H.tap("F2") H.step(2)
		return math.sqrt(H.eye.x ^ 2 + H.eye.z ^ 2)
	end
	local out, inn = back(false), back(true)
	check(near(out, 6, 0.1) and near(inn, 3.5, 0.1), "6 m out of melee, 3.5 m in: " .. out .. ", " .. inn)
end

-- the author, 2026-10-15: "rng on activating the animation". Measured: every unit has MOVING_ATTACK_1-2 only, jump
-- attacks run 1, 2 or 5 deep, an engineer lacks ATTACK_3; a list that rotates past what he has plays nothing
T.a_swing_rotates_only_through_the_clips_he_has = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[454] = true, [455] = true, [490] = true, [42] = true}})
	local got = {}
	for k = 1, 4 do H.tap("Left mouse") past_swing_gap() got[k] = H.last("play")[3] end
	check(got[1] == 454 and got[2] == 455 and got[3] == 454 and got[4] == 455, "454 455 454 455: " .. table.concat(got, " "))
	H.tap("E") H.step(1 / 60)
	check(H.last("play")[3] == 490, "a jump list of one: JUMPING_ATTACK_2 every time")
	H.step(3) H.tap("Left mouse") H.step(1 / 60)
	check(H.last("play")[3] == 454, "the jump did not move the swings on: " .. H.last("play")[3])
end

-- the author, 2026-10-15: "ironbreakers mine spawn the projectile at the start of the frame than throwing it". Measured
-- in CA's anim2.pack: both blasting-charge throws carry FIRE_POS at 2.2 and 2.3 s, rifles 0 to 0.3 s. A shot whose
-- projectile is shot type "explosives" leaves at 2.2 s into the clip
T.a_thrown_bomb_leaves_late_in_the_throw = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_bombers", men = 20, x = 40, range = 60, ammo = 10,
		slots = {[454] = true, [1557] = true, [1564] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "bomb", 10
	t["ActiveProjectileContext.NumProjectiles"], t["ActiveProjectileContext.ShotTypeKey"] = 1, "explosives"
	H.cco_ids = {cco_2 = t}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	local at = H.game_ms
	H.tap("Left mouse")
	local fired
	for _ = 1, 300 do H.step(1 / 60) if H.count("launch") > 0 then fired = H.game_ms - at break end end
	check(fired and fired >= 2200 and fired < 2400, "thrown at 2.2 s: " .. tostring(fired))
end


T.the_action_bar_counts_the_reload_down = function()
	crossbowmen({type = "wh3_main_cth_inf_iron_hail_gunners_0", reload_slot = 1564})
	H.tap("Left mouse") H.step(6)
	check(hud_part("act_fire_dim"):Visible() and hud_part("act_fire_cool").text ~= "", "reloading: dim, with seconds: "
		.. tostring(hud_part("act_fire_cool").text))
	H.step(20)
	check(not hud_part("act_fire_dim"):Visible(), "loaded")
end

T.the_action_bar_hides_jump_without_its_clips = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[454] = true, [42] = true}})
	check(hud_part("act_attack_frame"):Visible() and hud_part("act_sprint_frame"):Visible(), "attack and sprint show")
	check(not hud_part("act_jump_frame"):Visible(), "no clips: no jump")
end

-- the shown buttons sit side by side against the right edge: no hole where a hidden one would be
T.the_action_bar_packs_the_shown_buttons_to_the_right = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local c, a, j = hud_part("act_sprint_frame"), hud_part("act_attack_frame"), hud_part("act_jump_frame")
	check(a.x - c.x == j.x - a.x and a.x > c.x, "one pitch apart, with no gap for fire: " .. c.x .. ", " .. a.x .. ", " .. j.x)
	local h = hud_part("act_cheer_frame") -- the last shown
	check(math.abs(h.x + h.w - (1920 - 24)) <= 1, "the last one on the right margin: " .. (h.x + h.w))
end

T.out_of_ammo_the_fire_button_dims_without_seconds = function()
	crossbowmen({ammo = 0, start_ammo = 10})
	check(hud_part("act_fire_frame"):Visible() and hud_part("act_fire_dim"):Visible(), "a shooter with nothing left: dim")
	check(not hud_part("act_fire_coolplate"):Visible(), "and no seconds")
end

T.charge_and_jump_have_keys_and_settings = function()
	local S = settings_with(nil)
	check(S.names.walk == "Z" and S.names.sprint == "Shift" and S.names.minimap == "M" and S.names.jump == "E",
		"Z, Shift, M and E")
	check(near(S.charge_cooldown, 10) and near(S.jump_cooldown, 10), "10 s and 10 s")
	check(S.walk_hold == false and near(S.turn_rate, math.rad(360)) and near(S.melee_distance, 3.5), "toggle, 360 deg/s, 3.5 m")
	S = settings_with({combat_charge_cooldown = 300, combat_jump_cooldown = 15, combat_walk_hold = true, move_turn_rate = 180,
		camera_melee_distance = 50})
	check(near(S.charge_cooldown, 30) and near(S.jump_cooldown, 1.5), "from tenths")
	check(S.walk_hold and near(S.turn_rate, math.rad(180)) and near(S.melee_distance, 5), "hold, 180 deg/s, 5 m")
end


-- the author, 2026-10-15: "animation with multiple projectile spawn only spawns one projectile". Measured in the packs:
-- each FIRE_POS event in the fire clip's .anm.meta spawns one shot - a rocket barrage carries 18, 1.0 to 5.25 s, and
-- CA's ratling gun the same. data.lua's fires carry each unit's times; one shot of ammo for the whole clip
T.a_gun_with_many_spawns_fires_each_one = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_crank", men = 20, x = 40, range = 60, ammo = 10, start_ammo = 10,
		slots = {[454] = true, [1557] = true, [1564] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 10
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.E.D.fires = H.E.D.fires or {}
	H.E.D.fires.zorn_test_crank = {{1.0, 0.2, 1.1, 0.8}, {1.25, 0.2, 1.1, 0.8}, {1.5, 0.2, 1.1, 0.8}}
	H.E.D.shots.zorn_test_crank = {"rocket", 10, 1, "Battle_Rocket_Fire"} -- a known shot, its weapon's bang with it
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	local at, seen = H.game_ms, {}
	H.tap("Left mouse")
	for _ = 1, 240 do H.step(1 / 60) if H.count("launch") > #seen then seen[#seen + 1] = H.game_ms - at end end
	check(#seen == 3, "three spawns, three shots: " .. #seen)
	check(seen[1] and math.abs(seen[1] - 1000) < 50 and math.abs(seen[3] - 1500) < 50, "on their times: "
		.. table.concat(seen, " "))
	check(H.units[2]._ammo == 9, "one shot of ammo: " .. H.units[2]._ammo)
	-- each spawn is a discharge: the weapon's bang on every one (the author, 2026-10-15: "no sound effect when firing")
	check(H.count("sound") == 3, "a bang a spawn: " .. H.count("sound"))
end

-- the author, 2026-10-15: "the projectile spawn is mismatched to the model". FIRE_POS carries where the shot is made, in
-- metres from his animroot: x right, y up, z ahead (measured: rifles 0.1-0.4 right, 1.0-1.5 up, 0.7-1.6 ahead; a
-- ratling gun 0.38 up). It turns with him; he faces the camera through the shot
T.a_shot_leaves_from_the_fire_clips_muzzle = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_crank", men = 20, x = 40, range = 60, ammo = 10, start_ammo = 10,
		slots = {[454] = true, [1557] = true, [1564] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 10
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.E.D.fires.zorn_test_crank = {{0.2, 0.3, 0.4, 1.3}}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.E.rig.look(150, 0) H.step(0.5) -- a facing off the axes, so a swapped or mirrored axis shows; settled
	local yaw = H.E.rig.yaw
	H.tap("Left mouse") H.step(1)
	local l = H.last("launch")
	local mx, my, mz = H.E.P.model_pos(H.E.F.model)
	local c, sn = math.cos(yaw), math.sin(yaw)
	local wx, wy, wz = mx + 0.3 * c + 1.3 * sn, my + 0.4, mz - 0.3 * sn + 1.3 * c
	check(l and near(l[3].x, wx, 0.01) and near(l[3].y, wy, 0.01) and near(l[3].z, wz, 0.01), "from the muzzle: "
		.. (l and (l[3].x .. "," .. l[3].y .. "," .. l[3].z) or "no shot") .. " want " .. wx .. "," .. wy .. "," .. wz)
end

-- the author, 2026-10-15: "it also doesnt attack to the cameras direction, it redirects to the battalions facing
-- direction when attacking" - the log shows jump and charge attacks. An action turns him to the camera as it starts and
-- holds that facing until it ends
T.an_action_faces_the_camera_and_keeps_it = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("D") H.step(0.5) H.up("D") H.step(0.1) -- he faces right, the camera ahead
	H.E.rig.look(150, 0) H.step(0.1) -- a camera off the battle's axes, so a facing of 0 cannot pass for it
	local yaw0 = H.E.rig.yaw
	local function off(y) return math.abs(((y - yaw0) + math.pi) % (2 * math.pi) - math.pi) end
	local faces = H.count("face")
	H.tap("E") H.step(1 / 60)
	check(H.count("face") > faces and off(H.last("face")[3]) < 0.01, "the jump starts facing the camera")
	faces = H.count("face")
	H.E.rig.look(400, 0) H.step(1)
	check(H.count("face") > faces + 30, "held every frame of the jump: " .. (H.count("face") - faces))
	check(off(H.last("face")[3]) < 0.01, "at the facing it started with, not the camera's new one")
end

-- a unit data.lua knows keeps data.lua's shot, its weapon's bang included: its card is read only for a unit it lacks
T.a_known_unit_keeps_its_data_shot = function()
	local k = "wh3_main_cth_inf_jade_warrior_crossbowmen_1"
	H.fresh({units = {{general = true}, {type = k, men = 20, x = 40, range = 60, ammo = 10,
		slots = {[454] = true, [1554] = true, [1557] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "card_bolt", 1
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	local s = H.E.D.shots[k]
	check(s[1] == "wh3_cth_crossbow_bolt" and s[4] == "Battle_Individual_Small_Arms_Crossbow_Release", "data.lua's shot: "
		.. tostring(s[1]) .. " " .. tostring(s[4]))
end

-- the author, 2026-10-15: "pressing q then melee attacking doesnt trigger the attack charge animation at all". Measured
-- (probes/zz_tp_charge_attack.lua): the charge attack plays after CHARGE, but the engine reported it 0.19-0.31 s after it
-- was sent; the lock gave up at 0.25 s, Q still held restarted the charge, and CHARGE replaced the attack
T.a_charge_attack_reported_late_still_plays_out = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.report_ms = 310
	H.down("W") H.down("Shift") H.step(0.5)
	H.tap("Left mouse") H.step(1 / 60)
	local n = charges()
	H.step(1.5)
	check(charges() == n, "no charge over the attack: " .. (charges() - n))
	check(H.last("play")[3] == 484, "the charge attack is the last clip sent: " .. H.last("play")[3])
	H.up("Shift") H.up("W")
end

-- the author, 2026-10-15: "should be also health and winds of magic(if wizard) on the unit panel". CcoBattleUnit's
-- HealthValue and HealthMax; a caster is a unit with an ability that spends winds (CcoBattleAbility.ManaUsed > 0), and
-- the winds are his army's pool, ArmyContext.WindsOfMagicPoolContext's CurrentWind of MaxWind (CA's cco docs)
T.the_panel_shows_health_and_a_casters_winds = function()
	local t = hud_cco({"wh_main_spell_fire_fireball"})
	t.HealthValue, t.HealthMax = 1240, 1500
	t["BattleAbilityList.At(0).ManaUsed"] = 0 -- an ability that costs no winds
	hud_on({abilities = {"wh_main_spell_fire_fireball"}, cco = t})
	H.step(1 / 60)
	check(hud_part("hp"):Visible() and hud_part("hp").text == "1240 / 1500" and hud_part("hp_icon"):Visible(), "health: "
		.. tostring(hud_part("hp").text))
	check(not hud_part("winds"):Visible() and not hud_part("winds_fill"):Visible(), "no ability that costs winds: no winds")
	check(not H.logged("HUD part winds"), "and no pool read for him to fail")
	check(hud_part("plate_left_short"):Visible() and not hud_part("plate_left"):Visible(), "the short plate")
	local _, short_y = hud_part("name"):Position()
	t["BattleAbilityList.At(0).ManaUsed"] = 8
	t["ArmyContext.WindsOfMagicPoolContext.CurrentWind"], t["ArmyContext.WindsOfMagicPoolContext.MaxWind"] = 34.6, 60
	hud_on({abilities = {"wh_main_spell_fire_fireball"}, cco = t})
	H.step(1 / 60)
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	check(hud_part("winds"):Visible() and hud_part("winds").text == "34 / 60" and hud_part("winds_icon"):Visible(),
		"the winds: " .. tostring(hud_part("winds").text))
	check(hud_part("winds_fill").w == math.floor(L.fill.winds_fill * 34.6 / 60 + 0.5), "the bar at 34.6 of 60")
	check(hud_part("plate_left"):Visible() and not hud_part("plate_left_short"):Visible(), "the tall plate")
	local _, tall_y = hud_part("name"):Position()
	check(tall_y < short_y, "the rows above lift for the winds row: " .. tall_y .. " against " .. short_y)
	t["ArmyContext.WindsOfMagicPoolContext.CurrentWind"] = 12 H.step(0.25) -- the context is read every 0.2 s
	check(hud_part("winds").text == "12 / 60", "and follows the pool")
end

-- a health figure the context cannot give costs the figure, never the bar
T.no_health_figure_keeps_the_bar = function()
	local t = hud_cco({})
	t.HealthValue, t.HealthMax = nil, nil
	hud_on({hp = 0.5, cco = t})
	H.step(1 / 60)
	check(not hud_part("hp"):Visible() and hud_part("health_fill"):Visible(), "the bar, without its figure")
end

-- the author, 2026-10-15: "the projectile is not accurate, and is far off from the crosshair". The shot went 1 m over
-- the point where the view met a flat plane at his own height: off the crosshair at every range, and on a slope off
-- the ground too. It goes at the ground the crosshair is on
T.a_shot_goes_where_the_crosshair_meets_the_ground = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_crank", men = 20, x = 40, range = 120, ammo = 10, start_ammo = 10,
		slots = {[454] = true, [1557] = true, [1564] = true, [42] = true}}}})
	H.ground = function(_, z) return z * 0.1 end -- rising ahead of him
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 10
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.E.D.fires.zorn_test_crank = {{0.2, 0.3, 0.4, 0.9}}
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.E.rig.look(150, 0) H.step(1) -- turned off the axes, settled
	H.tap("Left mouse") H.step(1)
	local l = H.last("launch")
	check(l, "a shot")
	local g = l[4]
	check(off_crosshair(g) < 0.05, "on the crosshair's line: " .. off_crosshair(g) .. " m off it")
	check(math.abs(g.y - H.ground(g.x, g.z)) < 0.1, "on the ground there: " .. g.y .. " against " .. H.ground(g.x, g.z))
end

-- the author, 2026-10-15: "shooting then moving the cameras has the same bullet spawn and placement as the first shot".
-- A burst took its aim once, at the click: each spawn takes the crosshair as it is when it leaves
T.a_burst_follows_the_crosshair = function()
	H.fresh({units = {{general = true}, {type = "zorn_test_crank", men = 20, x = 40, range = 120, ammo = 10, start_ammo = 10,
		slots = {[454] = true, [1557] = true, [1564] = true, [42] = true}}}})
	local t = H.default_cco()
	t["ActiveProjectileContext.Key"], t["ActiveProjectileContext.BaseReloadTimeContext.Value"] = "rocket", 10
	t["ActiveProjectileContext.NumProjectiles"] = 1
	H.cco_ids = {cco_2 = t}
	H.E.D.fires.zorn_test_crank = {{0.2, 0.3, 0.4, 0.9}, {0.8, 0.3, 0.4, 0.9}}
	H.select(H.units[2]) H.tap("F2") H.step(1)
	H.tap("Left mouse")
	for _ = 1, 30 do H.step(1 / 60) if H.count("launch") > 0 then break end end
	check(H.count("launch") == 1, "the first spawn is off")
	H.E.rig.look(300, 0) -- the camera swings between the two
	for _ = 1, 60 do H.step(1 / 60) if H.count("launch") > 1 then break end end
	local l = H.all("launch")
	check(#l == 2, "the second spawn is off")
	local mx, _, mz = H.E.P.model_pos(H.E.F.model)
	local function bearing(p) return math.deg(math.atan2(p.x - mx, p.z - mz)) end
	check(math.abs((bearing(l[2][4]) - bearing(l[1][4]) + 540) % 360 - 180) > 20, "the second goes where he now looks: "
		.. bearing(l[1][4]) .. " then " .. bearing(l[2][4]))
	check(off_crosshair(l[2][4]) < 0.05, "on the crosshair: " .. off_crosshair(l[2][4]) .. " m off it")
end

-- the author, 2026-10-15: "should be health of the individual unit not the whole battalion". Measured: each man's model
-- holds his hit points, int32 at +0xB18 (his maximum) and +0xB1C (now); summed over his men, the current is HealthValue
-- exactly (16 units, a lord and 200 Plaguebearers among them)
T.played_as_one_man_the_panel_shows_his_own_health = function()
	local t = hud_cco({})
	t.HealthValue, t.HealthMax = 3000, 4800
	hud_on({men = 40, hp = 0.625, cco = t})
	local m = H.E.F.model
	check(m, "one man of the forty")
	m.hp, m.hp_max = 45, 120
	H.step(0.25)
	local L = assert(loadfile("/script/derpy_tp/hud_layout"))()
	check(hud_part("hp").text == "45 / 120", "his own figure: " .. tostring(hud_part("hp").text))
	check(hud_part("health_fill").w == math.floor(L.fill.health_fill * 45 / 120 + 0.5), "his own bar: "
		.. hud_part("health_fill").w)
	hud_on({men = 1, hp = 0.625, cco = t})
	H.step(0.25)
	check(hud_part("hp").text == "3000 / 4800", "played whole: the unit's figure: " .. tostring(hud_part("hp").text))
	-- another model class may keep something else there (a lord on a Longma is another class, measured 2026-10-13)
	hud_on({men = 40, hp = 0.625, cco = t})
	H.E.F.model.hp, H.E.F.model.hp_max = 5000, 120
	H.step(0.25)
	check(hud_part("hp").text == "3000 / 4800", "not a health: the unit's figure: " .. tostring(hud_part("hp").text))
end


-- the author, 2026-10-15: "add button for cheer, and hide all ui, use O and P but can be configured in MCT", then "show
-- also button huds for flying, cheer and hide UI". O cheers: a CELEBRATE clip his men have (1094-1103), held like an
-- action. Measured: about half of all land units' men have one, 1.5-7.1 s, median 2.9, each with its own sound
T.o_cheers_with_his_celebrate_clip = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("O") H.step(0.1)
	local p = H.last("play")
	check(p and p[2] == H.E.F.model.id and p[3] == 1094, "CELEBRATE_1 on him: " .. tostring(p and p[3]))
	local steers = H.count("steer")
	H.down("W") H.step(0.5)
	check(H.count("steer") == steers, "held like an action: W waits")
	H.up("W")
end

-- measured 2026-10-15: no CELEBRATE or TAUNT clip in the bins of Plaguebearers, Blightkings or Tamurkhan. Such a man has
-- no cheer, no button and nothing on O (the author, 2026-10-15 21:20: "only show cheer and fly if its applicable")
T.a_man_with_no_cheer_clip_has_no_cheer = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[42] = true, [454] = true}})
	check(not hud_part("act_cheer_frame"):Visible(), "no cheer button")
	H.tap("O") H.step(0.1)
	check(H.count("taunt") == 0 and H.count("play") == 0, "nothing on O: taunts " .. H.count("taunt") .. ", clips " .. H.count("play"))
end

-- P hides everything the pack draws, and CA's interface stays hidden with the mouse freed; paused too (a still to take
-- a picture of); P again brings it back
T.p_hides_all_the_interface_even_paused = function()
	crossbowmen()
	H.step(0.1)
	local hud = find_uicomponent(H.root, "derpy_tp_hud")
	check(hud:Visible() and crosshair_up(), "the HUD and the crosshair")
	H.paused = true
	H.tap("P") H.step(0.1)
	check(not hud:Visible() and not crosshair_up(), "P, paused: both hidden")
	H.down("Middle mouse") H.step(0.1)
	local c = H.last("cinematic_ui")
	check(c[2] == true and c[3] == true, "the freed mouse shows the cursor, not CA's interface")
	H.up("Middle mouse") H.step(0.1)
	H.tap("P") H.step(0.1)
	check(find_uicomponent(H.root, "derpy_tp_hud"):Visible() and crosshair_up(), "P again: back")
	H.paused = false
end

-- default_keys: P is the game's pause, O its radar, K its own interface toggle, Space its allied outlines. While third
-- person is on, a game shortcut on one of its keys is off, and back on at the end; a key moved in MCT frees it
local function shortcuts() local s = {} for _, c in ipairs(H.all("disable_shortcut")) do s[c[2]] = c[3] end return s end
T.the_games_shortcuts_on_its_keys_are_off_while_on = function()
	general_on()
	local s = shortcuts()
	check(s.toggle_pause == true and s.visibility_toggle_radar == true, "pause and radar off")
	check(s.toggle_ui == nil, "K is none of its keys: CA's interface toggle is left alone")
	check(s.cam_down == true, "Z walks: the camera's down key off")
	H.tap("F2")
	s = shortcuts()
	check(s.toggle_pause == false and s.visibility_toggle_radar == false, "back at the end")
	H.fresh({mct = {key_hide_ui = "K"}})
	H.tap("F2")
	s = shortcuts()
	check(s.toggle_ui == true and s.toggle_pause == nil, "hide on K: K's game shortcut off, pause left alone")
end

-- the author, 2026-10-15: "fix two modes for ranged units (should walk and idle with melee weapons if melee mode, and
-- vice versa for ranged)". The game's melee mode (unitcontroller:melee) is the whole unit's: a unit played whole takes
-- his mode, off again at the end
T.a_unit_played_whole_takes_his_melee_mode = function()
	H.fresh({units = {{general = true, men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.1)
	check(H.count("uc:melee") == 0, "ranged: melee mode left off")
	H.tap("Right mouse") H.step(0.1)
	local c = H.last("uc:melee")
	check(c and c[3] == true, "melee: melee mode on")
	H.tap("Right mouse") H.step(0.1)
	check(H.last("uc:melee")[3] == false, "ranged again: off")
	H.tap("Right mouse") H.step(0.1)
	H.tap("F2")
	check(H.last("uc:melee")[3] == false, "third person off: off again")
end

-- the author, 2026-10-15 21:46: "why does switching melee and range of one units affects the entire battalion, I thought
-- we established that the controlled unit will be dependent". The design (section 3): one man of a regiment walks, swings
-- and shoots alone, and the regiment gets no orders - its melee mode is one
T.a_regiment_played_as_one_man_keeps_its_own_mode = function()
	crossbowmen()
	H.tap("Right mouse") H.step(0.1)
	check(not H.E.F.ranged, "he is in melee")
	H.tap("Right mouse") H.step(0.1) H.tap("Right mouse") H.step(0.1)
	H.tap("F2")
	check(H.count("uc:melee") == 0, "no melee mode order to his regiment: " .. H.count("uc:melee"))
end

T.a_unit_with_no_missile_weapon_is_never_put_in_melee_mode = function()
	H.fresh({units = {{general = true, men = 1}}}) -- played whole: the one kind melee mode is ever given to
	H.tap("F2") H.step(0.1)
	H.tap("Right mouse") H.step(0.1) H.tap("F2")
	check(H.count("uc:melee") == 0, "no melee mode calls")
end

-- a man who cannot shoot alone is in melee; his regiment is not put in melee mode for it
T.a_man_who_cannot_shoot_alone_leaves_his_regiments_mode = function()
	H.fresh({units = {{general = true, type = "wh_test_mod_grenadiers", men = 20, range = 60, ammo = 10}}})
	H.tap("F2") H.step(0.1)
	check(not H.E.F.ranged and H.count("uc:melee") == 0, "in melee, no order: " .. H.count("uc:melee"))
end

-- the bar: cheer for a man with a cheer clip, fly for a unit that can fly, lit while it flies; each with its key
T.the_action_bar_shows_fly_and_cheer = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	check(hud_part("act_cheer_frame"):Visible() and hud_part("act_cheer_key").text == "O", "cheer, on O")
	check(not hud_part("act_fly_frame"):Visible(), "no fly for a unit that cannot fly")
	playing({type = "wh_test_gyro", men = 5, can_fly = true, flying = true, x = 40})
	H.step(0.3)
	check(hud_part("act_fly_frame"):Visible() and hud_part("act_fly_key").text == "Space", "fly, on Space")
	check(hud_part("act_fly_active_l"):Visible(), "lit while it flies")
end


-- all seven buttons (a flyer that shoots, with charge, jump and cheer clips) beside ten abilities on a 1280 screen: the
-- bar does not run into the ability bar, it goes up a row (seen in the preview, 2026-10-15: eight left 22 px at 1600)
T.a_full_action_bar_clears_the_ability_bar = function()
	local ab = {} for i = 1, 10 do ab[i] = "a" .. i end
	H.fresh({units = {{general = true, abilities = ab, men = 1, range = 100, ammo = 10, can_fly = true, flying = true}},
		screen = {1280, 720}})
	H.cco = hud_cco(ab)
	H.tap("F2") H.step(0.3)
	local ACTS = {"walk", "sprint", "attack", "fire", "jump", "fly", "cheer"}
	local shown = 0
	for _, a in ipairs(ACTS) do if hud_part("act_" .. a .. "_frame"):Visible() then shown = shown + 1 end end
	check(shown == 7, "all seven: " .. shown)
	local function box(id) local c = hud_part(id) return c.x, c.y, c.x + c.w, c.y + c.h end
	local hit
	for _, a in ipairs(ACTS) do
		for _, pa in ipairs({"_frame", "_keyplate"}) do
			local ax0, ay0, ax1, ay1 = box("act_" .. a .. pa)
			for k = 1, 10 do
				for _, pb in ipairs({"_frame", "_keyplate"}) do
					local bx0, by0, bx1, by1 = box("slot_" .. k .. pb)
					if not (ax1 <= bx0 or bx1 <= ax0 or ay1 <= by0 or by1 <= ay0) then hit = hit or (a .. pa .. " on slot " .. k .. pb) end
				end
			end
		end
	end
	check(hit == nil, "no button on an ability: " .. tostring(hit))
end


-- third person ended with the interface hidden: CA's comes back all the same
T.stopping_with_the_interface_hidden_brings_it_back = function()
	general_on()
	H.step(0.1)
	H.tap("P") H.step(0.1)
	H.tap("F2")
	local c = H.last("cinematic_ui")
	check(c[2] == false and c[3] == true, "CA's interface and the cursor back")
end

-- a man with a TAUNT clip and no CELEBRATE one taunts
T.a_man_with_only_a_taunt_clip_taunts = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[42] = true, [454] = true, [1104] = true}})
	check(hud_part("act_cheer_frame"):Visible(), "a cheer button")
	H.tap("O") H.step(0.1)
	local p = H.last("play")
	check(p and p[3] == 1104 and H.count("taunt") == 0, "TAUNT_1: " .. tostring(p and p[3]))
end


-- the author, 2026-10-15 21:16: "WHY IS IT SWINGING TO THE RIGHT". Measured (probes/tp_cmd_trace.py, Chosen, ATTACK_2): the
-- engine turns him through the clip - 21 deg right on the wind-up, 28-46 deg left through the blow, back by the end - and
-- the lock's facing, written every frame, undid each turn, so the blow landed 30-45 deg right of the crosshair. A swing
-- starts facing the camera; once the engine plays its clip, the clip turns him
T.a_swing_lets_its_clip_turn_him = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.rig.look(150, 0) H.step(0.1)
	local yaw0 = H.E.rig.yaw
	local faces = H.count("face")
	H.tap("Left mouse") H.step(1 / 60)
	local f = H.all("face")[faces + 1]
	check(f and f[2] == H.E.F.model.id and math.abs(f[3] - yaw0) < 0.01, "the swing starts facing the camera")
	faces = H.count("face")
	H.step(1)
	check(plays_of(454) == 1 and H.count("face") == faces, "nothing written over the clip's turn: " .. H.count("face") - faces)
end


-- the author, 2026-10-15 21:20: "move the hide ui buttons elsewhere to not crowd the actions bar". Hide sits alone in the
-- top-right corner, on its key, and is no action button
T.the_hide_button_sits_alone_in_the_top_right_corner = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	local h = hud_part("hide_frame")
	check(h and h:Visible() and hud_part("hide_key").text == "P", "hide, on P")
	check(math.abs(h.x + h.w - (1920 - 24)) <= 1 and math.abs(h.y - 24) <= 1, "on the top and right margins: " .. h.x .. "," .. h.y)
	check(hud_part("act_hide_frame") == nil, "not in the action bar")
	local k = hud_part("hide_keyplate")
	check(k.y >= h.y + h.h - 20 and k.x < h.x + h.w and k.x + k.w > h.x, "its key under it")
end


-- the author, 2026-10-15: "the camera issue is still happening when near buildings" - a head-cam. Measured
-- (probes/zz_tp_recorder.lua): the engine reports the eye two frames late (got 99.7 against asked 97.9, the y asked two
-- frames before), on open ground; read as a roof's lift, every quick drop of the eye pulled the boom in. Only a lift
-- above all three of the last asked eyes is a roof's
T.a_camera_that_reports_late_is_no_roof = function()
	H.fresh({units = {{general = true, men = 1}}, cam_lag = 2})
	H.tap("F2") H.step(0.5)
	set_view(nil, 0.6) H.step(0.5)
	-- about 0.5 m a frame, as a quick zoom drops it (measured: 1.8 m over the two frames)
	for _ = 1, 10 do set_view(nil, H.E.rig.pitch - 0.08) H.step(1 / 60) end
	check(H.E.rig.boom == 1, "the boom stays out: " .. H.E.rig.boom)
	local z = H.units[1]:position():get_z()
	H.roof = function(_, ez) if ez < z - 1.5 then return 6 end end -- a building behind him: still a roof, late or not
	H.step(3)
	check(H.E.rig.boom < 1 and H.eye.z > z - 1.5, "it comes in out of the building: boom " .. H.E.rig.boom)
end


-- the author, 2026-10-15 21:54: "the issue of unit while melee still looking at the right is still happening at the last
-- part of the animation". The swing's hold ends at the swing cooldown (1.5 s) while its clip runs on (2.6-3.5 s
-- measured): standing still, the idle hold wrote the camera's facing every frame over the clip's last turn. Nothing writes
-- his facing until the clip ends
T.a_swing_clip_turns_him_to_its_end = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.rig.look(150, 0) H.step(0.1)
	H.tap("Left mouse") H.step(1 / 60)
	local function facings()
		local n = H.count("face")
		for _, h in ipairs(H.all("hold")) do if h[5] ~= nil then n = n + 1 end end
		return n
	end
	local n = facings()
	H.step(3) -- past the 1.5 s hold, inside the 4 s clip
	check(facings() == n, "nothing written over the clip after its hold: " .. facings() - n)
	H.step(1.5) -- the clip over
	check(facings() > n, "then he holds the camera's facing again")
end


-- the author, 2026-10-15 21:54: "fire level high, level, low not fitting to the precursor fire of aim high, level and
-- low". The game has three pairs, SHOOT_READY_TO_AIM_ and FIRE_ LOW/LEVEL/HIGH (1553/1556, 1554/1557, 1555/1558); the shot
-- played LEVEL whatever it was. Now one pair per shot, by the angle it leaves at: the low arc of its projectile's speed
-- (data.lua speeds) to the aim point; past 22.5 deg up the high pair, past 22.5 down the low, with that clip's muzzle
-- (data.lua fires_high, fires_low). Empire crossbowmen: bolt 45 m/s, muzzles 0.36, 1.54 and 2.11 m up
local EMPX = "wh_main_emp_inf_crossbowmen"
local function shot_plays() local p = {} for _, c in ipairs(H.all("play")) do p[#p + 1] = c[3] end return table.concat(p, " ") end

T.a_long_shot_raises_and_fires_high = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100}) -- looking level: the aim at his 160 m reach, ~25 deg
	H.tap("Left mouse") H.step(4.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1555 and p[2][3] == 1558, "aim high, then fire high: " .. shot_plays())
	local l = H.all("launch")
	local _, my = H.E.P.model_pos(H.E.F.model)
	check(#l == 1 and math.abs(l[1][3].y - (my + 2.111)) < 0.05, "from the high clip's muzzle (moved out along the shot): "
		.. (l[1] and l[1][3].y - my or "none"))
end

-- the author, 2026-10-16: "aiming up the projectile hits the controlled unit". Measured (log): Akshina's Ambushers' high
-- muzzle is 0.45 m ahead and 2 m up, his head, and his hit points fell 77 to 48 0.2 s after the shot: a scripted launch
-- has no owner. A spawn nearer than 1.1 m ahead of him moves out along its own line to the aim (no level or low muzzle,
-- 1.12 m and out, ever hit him). The crossbowmen's high muzzle is 0.58 m ahead
T.a_muzzle_inside_him_moves_out_along_the_shot = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	set_view(nil, -0.25) H.step(0.1) -- looking up, as when it hit him: the line to the aim climbs
	local m = H.E.F.model
	H.tap("Left mouse") H.step(4.5)
	local l = H.all("launch")
	check(#l == 1, "one shot: " .. #l)
	local x, y, z = H.E.P.model_pos(m)
	local f, t = l[1][3], l[1][4]
	local h = math.sqrt((f.x - x) ^ 2 + (f.z - z) ^ 2)
	check(math.abs(h - 1.1) < 1e-3, "1.1 m from him: " .. h)
	-- on the line from the muzzle (0.211 right, 2.111 up, 0.583 ahead) to the aim
	local c, sn = math.cos(H.E.rig.yaw), math.sin(H.E.rig.yaw)
	local mx, my, mz = x + 0.211 * c + 0.583 * sn, y + 2.111, z - 0.211 * sn + 0.583 * c
	local ax, ay, az, bx, by, bz = f.x - mx, f.y - my, f.z - mz, t.x - mx, t.y - my, t.z - mz
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local nb = math.sqrt(bx * bx + by * by + bz * bz)
	check(math.sqrt(cx * cx + cy * cy + cz * cz) / nb < 0.01, "on the shot's line")
	check((f.x - mx) * bx + (f.z - mz) * bz > 0, "toward the aim, not back through him")
end

-- the author, 2026-10-16: "twitching when aiming high", "aiming high still not fixed". Measured (log): a first high shot
-- went raise 1555, no clip for 0.1 s, fire 1558 - between them he stood in his idle, the gun level: a raise's length was
-- learned on its first whole one, so the first fire went only once it had ended. data.lua raises holds each raise's length
-- off its .anim (the Streltsi's 1.1 s and Akshina's 0.8 s, as the game played them): fire goes AIM_LEAD before the end
-- on the first shot too
T.the_first_high_shot_goes_from_the_raise_into_the_fire = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100, clip_ms = {[1555] = 1100}})
	H.E.D.raises = H.E.D.raises or {}
	H.E.D.raises[EMPX] = {0.5, 0.6, 1.1} -- each raise its own: the level one's would cut the high one short
	H.report_ms = 100 -- the engine reports a new clip a model tick after it is sent (the log: 0.1 s)
	local m = H.E.F.model
	H.tap("Left mouse")
	local raised, gap, fired = nil, false, nil
	for _ = 1, 150 do
		H.step(1 / 60)
		local slot = H.E.P.anim_slot(m)
		if slot == 1555 then raised = raised or H.game_ms elseif slot == 1558 then fired = H.game_ms break elseif raised then gap = true end
	end
	check(raised and fired and not gap, "raise, then fire, with no idle between: raised " .. tostring(raised) .. ", gap "
		.. tostring(gap) .. ", fired " .. tostring(fired))
	check(fired - raised >= 950, "the whole 1.1 s raise, less the lead: " .. (fired - raised) .. " ms")
end

-- measured live 2026-10-16 (script log, the Hochland Long Rifles, three shots alike): raise 1554 sent at 91.8 s and
-- reported at 92.0, no clip at 92.8, its hold 1548 at 93.0 - the idle the author saw ("animation when shooting still
-- reverts to idle for 1 frame, then shooting animation"). The lead was timed from the raise's report, which comes up to
-- 0.31 s after it starts in a busy battle; timed from its send, the hold goes before the raise ends
T.a_raise_reported_late_still_goes_straight_into_its_hold = function()
	local RIFLES = "wh3_dlc25_emp_inf_hochland_long_rifles_ror"
	local slots = {[42] = true, [1548] = true, [1554] = true, [1557] = true, [1564] = true} -- level raise, hold, fire, reload
	playing({type = RIFLES, men = 21, x = 40, range = 260, ammo = 100, slots = slots, clip_ms = {[1554] = 800}})
	H.E.D.raises = H.E.D.raises or {}
	H.E.D.raises[RIFLES] = {0.8, 0.8, 0.8}
	H.report_ms = 250
	local m = H.E.F.model
	H.tap("Left mouse")
	local raised, gap, held = nil, false, nil
	for _ = 1, 150 do
		H.step(1 / 60)
		local slot = H.E.P.anim_slot(m)
		if slot == 1554 then raised = raised or H.game_ms elseif slot == 1548 then held = H.game_ms break elseif raised then gap = true end
	end
	local sent = {}
	for _, p in ipairs(H.all("play")) do sent[#sent + 1] = p[3] end
	check(raised and held and not gap, "raise, then hold, no idle between: raised " .. tostring(raised) .. ", gap "
		.. tostring(gap) .. ", held " .. tostring(held) .. "; sent " .. table.concat(sent, " "))
end

-- seen 2026-10-16 (probes/zz_tp_shot_side2.lua, the Streltsi from the side; the author: "strteltzi sitll suffering from
-- the same ranged animation issue, aim high -> shoot level"): his level raise ends ~20 deg up and the fire snapped it
-- level. The pair's AIM clip holds the gun level (probes/zz_tp_aim_seq.lua): raise, aim, then the fire, AIM_HOLD after
-- the aim is reported
local STRELTSI = "wh3_main_ksl_inf_streltsi_0"
local function shot_sequence(o)
	playing(o)
	if o.before then o.before() end
	H.report_ms = 100 -- the engine reports a new clip a model tick after it is sent
	H.tap("Left mouse")
	local seq, at = {}, {}
	for _ = 1, 240 do
		H.step(1 / 60)
		local p = H.last("play")
		if p and p[3] ~= seq[#seq] then seq[#seq + 1], at[#at + 1] = p[3], H.game_ms end
	end
	return seq, at
end

local AIMS = {[42] = true, [1547] = true, [1548] = true, [1549] = true, [1553] = true, [1554] = true, [1555] = true,
	[1556] = true, [1557] = true, [1558] = true, [1564] = true}

T.the_raise_goes_into_its_aim_before_the_fire = function()
	local seq, at = shot_sequence({type = STRELTSI, men = 21, x = 40, range = 160, ammo = 100, slots = AIMS,
		clip_ms = {[1554] = 1100}}) -- the Streltsi's own raise, which data.lua's length times
	check(seq[1] == 1554 and seq[2] == 1548 and seq[3] == 1557, "raise, aim, fire: " .. table.concat(seq, " "))
	check(at[2] - at[1] >= 900, "the whole raise first, less the lead: " .. tostring(at[2] - at[1]) .. " ms")
	check(at[3] - at[2] >= 290, "the fire once the aim is reported and held: " .. tostring(at[3] - at[2]) .. " ms")
end

-- the aim clip replaced before its hold is over (the engine's own, a hit): the fire all the same
T.an_aim_cut_short_still_fires = function()
	playing({type = STRELTSI, men = 21, x = 40, range = 160, ammo = 100, slots = AIMS})
	local m = H.E.F.model
	H.tap("Left mouse")
	for _ = 1, 120 do H.step(1 / 60) if H.E.F.shot and H.E.F.shot.phase == "hold" and H.E.F.shot.started then break end end
	check(H.E.F.shot and H.E.F.shot.phase == "hold", "holding the aim")
	m.anim_slot, m.anim_end = 1439, nil
	H.step(1 / 60) H.step(1 / 60)
	check(H.last("play")[3] == 1557, "the fire: " .. tostring(H.last("play")[3]))
end

-- nor does a step cut it, as it cuts neither the raise nor the fire
T.a_step_does_not_cut_the_aim_hold = function()
	playing({type = STRELTSI, men = 21, x = 40, range = 160, ammo = 100, slots = AIMS})
	H.tap("Left mouse")
	for _ = 1, 120 do H.step(1 / 60) if H.E.F.shot and H.E.F.shot.phase == "hold" then break end end
	check(H.E.F.shot and H.E.F.shot.phase == "hold", "holding the aim")
	H.down("W") H.step(0.6) H.up("W")
	check(plays_of(1557) == 1, "the fire still plays: " .. plays_of(1557))
end

-- a raise data.lua has no length for, learned on its end: into the aim as well
T.a_raise_of_no_known_length_goes_into_its_aim_too = function()
	local seq = shot_sequence({type = STRELTSI, men = 21, x = 40, range = 160, ammo = 100, slots = AIMS,
		clip_ms = {[1554] = 1100}, before = function() H.E.D.raises = H.E.D.raises or {} H.E.D.raises[STRELTSI] = {0, 0, 0} end})
	check(seq[1] == 1554 and seq[2] == 1548 and seq[3] == 1557, "raise, aim, fire: " .. table.concat(seq, " "))
end

T.a_man_with_no_aim_clip_goes_from_the_raise_into_the_fire = function()
	local seq = shot_sequence({type = STRELTSI, men = 21, x = 40, range = 160, ammo = 100,
		slots = {[42] = true, [1554] = true, [1557] = true, [1564] = true}})
	check(seq[1] == 1554 and seq[2] == 1557, "raise, fire: " .. table.concat(seq, " "))
end

-- a unit data.lua has no raise for still learns it on the first whole one
T.a_raise_data_lua_lacks_is_learned_on_the_first_shot = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100, clip_ms = {[1555] = 1100}})
	H.E.D.raises = H.E.D.raises or {}
	H.E.D.raises[EMPX] = {1.1, 1.1, 0} -- no high raise in his bin's data: 0
	H.report_ms = 100
	local m = H.E.F.model
	local function gap_on_a_shot()
		H.tap("Left mouse")
		local raised, gap = false, false
		for _ = 1, 150 do
			H.step(1 / 60)
			local slot = H.E.P.anim_slot(m)
			if slot == 1555 then raised = true elseif slot == 1558 then break elseif raised then gap = true end
		end
		H.step(16)
		return gap
	end
	check(gap_on_a_shot(), "the first: fire once the raise has ended")
	check(not gap_on_a_shot(), "the second: from the raise into the fire")
end

-- the author, 2026-10-16: "UNRESPONSIVE UNITS WHEN IN COMBAT INCL BATTALION STILL NOT FIXED", not reproduced off the
-- game, and no log line marks it. With the debug log on, a second of movement keys held with him standing logs what held
-- him, once a stall; and a clip the engine never plays logs too
local function logged_n(text) local n = 0 for _, l in ipairs(H.log) do if l:find(text, 1, true) then n = n + 1 end end return n end
T.a_stall_with_the_keys_held_is_logged = function()
	H.fresh({mct = {debug_log = true}, units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.down("W") H.step(0.6) -- the harness's steer moves nobody: he stands
	check(logged_n("stalled") == 0, "not yet")
	H.step(0.6)
	check(logged_n("stalled 1 s with a move key held") == 1, "a second still: logged")
	H.step(3)
	check(logged_n("stalled") == 1, "once a stall")
	H.up("W") H.step(0.1) H.down("W") H.step(1.2)
	check(logged_n("stalled") == 2, "the next stall logs again")
	H.up("W")
end

T.a_swing_the_engine_never_plays_is_logged = function()
	H.fresh({mct = {debug_log = true}, units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2]) H.tap("F2") H.step(0.1)
	H.report_ms = 1e9 -- the engine never reports it
	H.tap("Left mouse") H.step(1.2)
	check(logged_n("never played") == 1, "logged: " .. table.concat(H.log, " | "):sub(-300))
end

-- the author, 2026-10-16: "if no charge animation, add a 20% boost to speed", then "20% boost even with charge
-- animation"; 2026-10-17: "add 50% speed boost when charging/sprinting": a sprint is 1.5 times his run
T.a_sprint_is_half_again_as_fast = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.step(0.6)
	check((H.last("steer")[7] or 1) == 1, "running: his own speed")
	H.down("Shift") H.step(0.3)
	check(near(H.last("steer")[7], 1.5), "sprinting: 1.5 times: " .. tostring(H.last("steer")[7]))
	H.up("Shift") H.step(0.1)
	check((H.last("steer")[7] or 1) == 1, "let go: his own again")
	H.up("W")
end

-- a regiment played whole: CA's walk speed scalar, after each order at the sprint (it resets with every order)
T.a_unit_played_whole_sprints_half_again_as_fast = function()
	general_on() H.step(0.5)
	H.down("W") H.step(0.6)
	check(H.count("uc:change_current_walk_speed") == 0, "running: no scalar")
	H.down("Shift") H.step(0.6)
	local s = H.last("uc:change_current_walk_speed")
	check(s and near(s[3], 1.5), "sprinting: 1.5: " .. tostring(s and s[3]))
	local last_order, last_speed = 0, 0
	for i, c in ipairs(H.calls) do
		if c[1] == "uc:goto_location" then last_order = i elseif c[1] == "uc:change_current_walk_speed" then last_speed = i end
	end
	check(last_speed > last_order, "after its order")
	local orders = H.count("uc:goto_location")
	H.step(2)
	check(H.count("uc:goto_location") == orders, "one order for a steady sprint, not one a step")
	H.up("Shift") H.up("W")
end

-- the author, 2026-10-16: "when aiming here, it shoots above, so its aiming at the terrain not the cursor target". The
-- view ran through the Ogre under the crosshair to the ground behind him, and the arc to that far point passed over him.
-- The aim stops at the first enemy man the view passes through: a standing cylinder of his entity's radius and height
local function aim_through(o, enemies, ly)
	playing(o, enemies)
	local R = H.E.rig
	R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = 40, 3, -5, 40, ly, 30
	return H.E.combat.aim_point(160)
end

T.the_aim_stops_at_the_enemy_under_the_crosshair = function()
	local _, _, az = aim_through({type = XBOW, men = 21, x = 40, range = 160, ammo = 100}, {{x = 40, z = 30, men = 1}}, 1.2)
	check(az and math.abs(az - 30) < 1, "at the man 30 m out, not the ground behind him: " .. tostring(az))
end

T.a_view_over_his_head_goes_on_to_the_ground = function()
	local _, _, az = aim_through({type = XBOW, men = 21, x = 40, range = 160, ammo = 100}, {{x = 40, z = 30, men = 1}}, 2.4)
	check(az and az > 40, "past the man: " .. tostring(az))
end

T.a_tall_enemy_stops_a_view_a_man_would_not = function()
	local _, _, az = aim_through({type = XBOW, men = 21, x = 40, range = 160, ammo = 100},
		{{type = "wh_test_ogres", x = 40, z = 30, men = 1}}, 2.4)
	check(az and az > 40, "his height unknown, a man's: past him: " .. tostring(az))
	H.E.D.bodies = {wh_test_ogres = {1.2, 3.1}}
	local _, _, az2 = H.E.combat.aim_point(160)
	check(az2 and math.abs(az2 - 30) < 1.5, "3.1 m tall (data.lua bodies): at him: " .. tostring(az2))
end

T.an_enemy_beside_the_view_does_not_stop_it = function()
	local _, _, az = aim_through({type = XBOW, men = 21, x = 40, range = 160, ammo = 100}, {{x = 43, z = 30, men = 1}}, 1.2)
	check(az and az > 40, "3 m off the line: past him: " .. tostring(az))
end

-- looking up, the view's line runs down behind the camera: an enemy there is not under the crosshair
T.an_enemy_behind_the_camera_does_not_stop_the_aim = function()
	playing({type = XBOW, men = 21, x = 40, range = 160, ammo = 100}, {{x = 40, z = -15, men = 1}})
	local R = H.E.rig
	R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = 40, 1.5, -5, 40, 3, 30
	local _, _, az = H.E.combat.aim_point(160)
	check(az and az > 0, "ahead of the camera: " .. tostring(az))
end

T.a_friend_in_the_way_does_not_stop_the_aim = function()
	local u = playing({type = XBOW, men = 21, x = 40, range = 160, ammo = 100})
	H.unit({type = "wh_test_melee", x = 40, z = 30, men = 1})
	local R = H.E.rig
	R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = 40, 3, -5, 40, 1.2, 30
	local _, _, az = H.E.combat.aim_point(160)
	check(u and az and az > 40, "through his own side: " .. tostring(az))
end

T.a_near_shot_raises_and_fires_level = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	set_view(nil, 0.08) H.step(0.1) -- looking down a little: the aim on the ground some 40 m out
	H.tap("Left mouse") H.step(1.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1554 and p[2][3] == 1557, "aim level, then fire level: " .. shot_plays())
	local l = H.all("launch")
	local _, my = H.E.P.model_pos(H.E.F.model)
	check(#l == 1 and near(l[1][3].y, my + 1.535), "from the level clip's muzzle")
end

T.a_shot_steeply_down_raises_and_fires_low = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	set_view(nil, 1.1) H.step(0.1) -- looking down at his feet
	H.tap("Left mouse") H.step(4.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1553 and p[2][3] == 1556, "aim low, then fire low: " .. shot_plays())
end

-- a pair is played whole: a man with FIRE_HIGH and no SHOOT_READY_TO_AIM_HIGH raises level and fires level
T.a_man_without_the_whole_high_pair_keeps_the_level_one = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100,
		slots = {[42] = true, [454] = true, [1554] = true, [1557] = true, [1558] = true, [1564] = true}})
	H.tap("Left mouse") H.step(1.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1554 and p[2][3] == 1557, "aim level, then fire level: " .. shot_plays())
end


-- past the low arc's reach (the bolt's 45 m/s carries ~206 m) the shot leaves at its steepest: high
T.a_shot_past_its_arc_still_goes_high = function()
	playing({type = EMPX, men = 21, x = 40, range = 250, ammo = 100})
	H.tap("Left mouse") H.step(4.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1555 and p[2][3] == 1558, "aim high, then fire high: " .. shot_plays())
end

-- a man with FIRE_HIGH's muzzle in data.lua but no FIRE_HIGH clip keeps the level pair
T.a_man_without_the_high_fire_clip_keeps_the_level_pair = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100,
		slots = {[42] = true, [454] = true, [1554] = true, [1555] = true, [1557] = true, [1564] = true}})
	H.tap("Left mouse") H.step(1.5)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1554 and p[2][3] == 1557, "aim level, then fire level: " .. shot_plays())
end

-- a unit whose projectile speed data.lua does not know: the straight line to the aim, level for a far one
T.a_shot_with_no_known_speed_goes_by_the_straight_line = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	local v = H.E.D.speeds[EMPX]
	H.E.D.speeds[EMPX] = nil
	local ok, err = pcall(function() H.tap("Left mouse") H.step(1.5) end)
	H.E.D.speeds[EMPX] = v
	assert(ok, err)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1554 and p[2][3] == 1557, "aim level, then fire level: " .. shot_plays())
end


-- Round 25: a fresh read of the code for logic slips (2026-10-15, the author: "can you yourself double check logic
-- issues and do a full sweep so that i dont have to multiple test ingame"). One test per confirmed finding

local function facings()
	local n = H.count("face")
	for _, h in ipairs(H.all("hold")) do if h[5] ~= nil then n = n + 1 end end
	return n
end

-- the engine reports a new clip 0.19-0.31 s late, and until it starts a clip under way (the last swing's) still turns
-- him: the camera's facing is written each frame until the clip is reported, then never
T.a_swing_faces_the_camera_until_its_clip_is_reported = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.report_ms = 250
	H.E.rig.look(150, 0) H.step(0.1)
	local n = H.count("face")
	H.tap("Left mouse") H.step(0.2)
	check(H.count("face") >= n + 10, "the camera's facing each frame until it is reported: " .. H.count("face") - n)
	H.step(0.1) -- past the report, 0.25 s after the click
	n = H.count("face")
	H.step(0.5)
	check(H.count("face") == n, "then the clip turns him: " .. H.count("face") - n)
end

-- a cheer's clip turns him too, to its end (CELEBRATE runs up to 7.1 s, past its 3 s lock)
T.a_cheer_clip_turns_him_to_its_end = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.E.rig.look(150, 0) H.step(0.1)
	H.tap("O") H.step(1 / 60)
	local n = facings()
	H.step(3.5) -- past the 3 s lock, inside the 4 s clip
	check(facings() == n, "nothing written over the cheer: " .. facings() - n)
	H.step(1)
	check(facings() > n, "then he holds the camera's facing again")
end

-- a shot whose clip the engine never starts (replaced before it played) gives up after LOCK_WAIT: he is not rooted
T.a_shot_whose_clip_never_plays_gives_up = function()
	crossbowmen()
	H.report_ms = 5000
	H.tap("Left mouse") H.step(1.2)
	check(H.E.F.shot == nil, "given up")
	local steers = H.count("steer")
	H.down("W") H.step(0.6) H.up("W")
	check(H.count("steer") > steers, "and he walks again")
end

-- an action drops a shot under way: a jump in the raise does not fire the old shot after it lands
T.a_jump_drops_a_shot_under_way = function()
	crossbowmen()
	H.tap("Left mouse") H.step(0.3)
	check(H.E.F.shot and H.E.F.shot.phase == "aim", "raising to aim")
	H.tap("E") H.step(0.1)
	check(H.E.F.shot == nil, "the jump drops the shot")
	H.step(4)
	check(plays_of(1557) == 0 and H.count("launch") == 0, "no shot after the jump")
end

-- one man's right-click swing with none of ATTACK_5-7 sends his regiment no attack order
T.one_man_with_no_clip_for_a_swing_gives_no_attack_order = function()
	playing({type = "wh_test_melee", men = 21, x = 40, slots = {[42] = true, [454] = true}}, {{x = 40, z = 30, men = 10}})
	H.step(0.5)
	H.tap("Right mouse") H.step(0.6)
	check(H.count("uc:attack_unit") == 0, "no attack order to his regiment: " .. H.count("uc:attack_unit"))
end

-- E in a charge: the charge's run ends with the jump, and its stop (WALK_1 at mask 0) does not cut the jump's clip
T.a_jump_in_the_charge_plays_out = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("W") H.down("Shift") H.step(0.6)
	check(H.E.F.charging, "charging")
	local walks = plays_of(42)
	H.tap("E") H.step(0.3)
	check(plays_of(489) == 1 and plays_of(42) == walks, "the jump, not cut: walking clips " .. plays_of(42) - walks)
	H.up("Shift") H.up("W")
end

-- the mode key's swing waits for an action under way, as a click does
T.a_right_click_waits_for_a_jump = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("E") H.step(0.1)
	H.tap("Right mouse") H.step(0.1)
	check(plays_of(458) + plays_of(459) + plays_of(460) == 0, "no swing over the jump")
end

-- a unit played whole fires on the ground; a turn it never completes does not keep it firing past its commit
T.ground_fire_that_cannot_turn_gives_up_after_its_commit = function()
	H.fresh({units = {{general = true, men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.6)
	set_view(H.E.rig.yaw + 2) H.step(0.1) -- the aim far outside its arc: a turn first, which never ends here
	H.tap("Left mouse") H.step(5)
	check(not H.E.F.firing, "given up after the 4 s commit")
end

-- the walk's halt is an order: a click just after it waits the half second instead of being dropped
T.a_ground_fire_click_just_after_stopping_is_not_dropped = function()
	H.fresh({units = {{general = true, men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.6)
	H.down("W") H.step(0.6) H.up("W") H.step(1 / 60)
	H.tap("Left mouse") H.step(1)
	check(H.count("dropped_order") == 0 and H.count("uc:attack_location") >= 1, "the fire order, not dropped: dropped "
		.. H.count("dropped_order"))
end

-- a unit played whole turned before its swing: with no clip to play, its attack order comes 0.5 s after the turn's
T.a_whole_unit_turned_to_swing_keeps_its_attack_order = function()
	H.fresh({units = {{general = true, men = 1, slots = {[42] = true}}}, enemies = {{x = 3, z = 3, men = 10}}})
	H.tap("F2") H.step(0.6)
	set_view(H.E.rig.yaw + 2) H.step(0.1)
	H.tap("Left mouse") H.step(1)
	check(H.count("dropped_order") == 0 and H.count("uc:attack_unit") == 1, "turned, then the attack order: dropped "
		.. H.count("dropped_order") .. ", attacks " .. H.count("uc:attack_unit"))
end

-- on the game's 100 ms clock he turns at the set rate, not in clipped steps: 72 deg in 0.2 s at 360 deg/s
T.turning_keeps_its_rate_on_the_games_clock = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}, tick_ms = 100})
	H.select(H.units[2]) H.tap("F2") H.step(0.6)
	local yaw0 = H.E.rig.yaw
	H.down("D") H.step(0.2) H.up("D")
	local turned = ((H.E.F.face_yaw - yaw0) + math.pi) % (2 * math.pi) - math.pi
	check(math.abs(turned - math.rad(72)) < math.rad(8), "72 deg: " .. math.deg(turned))
end

-- at 10 fps (a big battle) he turns at the same rate: 72 deg in 0.2 s, not half
T.turning_keeps_its_rate_at_a_low_frame_rate = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2]) H.tap("F2") H.step(0.6)
	local yaw0 = H.E.rig.yaw
	H.down("D")
	for _ = 1, 2 do H.T = H.T + 0.1 - 1 / 60 H.step(1 / 60) end -- two frames of 0.1 s
	H.up("D")
	local turned = ((H.E.F.face_yaw - yaw0) + math.pi) % (2 * math.pi) - math.pi
	check(math.abs(turned - math.rad(72)) < math.rad(8), "72 deg: " .. math.deg(turned))
end

-- the next man is not held up by the lock of the man who died
T.the_next_man_is_not_held_by_the_dead_mans_lock = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("E") H.step(0.1)
	H.E.F.model.alive = false
	H.step(1 / 60)
	check(H.E.F.lock == nil, "the lock went with him")
end

-- a new F2 starts him facing the camera, not the last session's walk
T.a_new_session_starts_facing_the_camera = function()
	playing({type = "wh_test_melee", men = 21, x = 40})
	H.down("D") H.step(0.5) H.up("D") H.step(0.1)
	H.tap("F2") H.step(0.1) H.tap("F2") H.step(0.1)
	local h = H.last("hold")
	check(h and math.abs(((h[5] - H.E.rig.yaw) + math.pi) % (2 * math.pi) - math.pi) < 0.01, "the camera's facing")
end

-- a spawn due in the fire clip's last model tick still leaves (the rocket barrage's 5.25 s spawn)
T.a_spawn_due_as_the_fire_clip_ends_still_leaves = function()
	H.fresh({units = {{general = true}, {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}}, tick_ms = 100})
	H.select(H.units[2]) H.tap("F2") H.step(0.6)
	local f = H.E.D.fires[XBOW]
	H.E.D.fires[XBOW] = {{0, 0.15, 1.06, 0.68}, {3.95, 0.15, 1.06, 0.68}}
	local ok, err = pcall(function() H.tap("Left mouse") H.step(7) end)
	H.E.D.fires[XBOW] = f
	assert(ok, err)
	check(H.count("launch") == 2, "both spawns: " .. H.count("launch"))
end

-- each raise learns its own length: the level raise's 1 s does not cut the high one short (the harness's 4 s), or the
-- fire clip starts from the middle of the high raise
T.a_high_raise_does_not_take_the_level_ones_length = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	H.E.D.raises = {} -- the harness's raise runs 1 s, not the .anim's: learned on the first, as a modded unit's
	set_view(nil, 0.08) H.step(0.1)
	H.tap("Left mouse") H.step(20) -- a level shot and its reload: the level raise's length learned
	set_view(nil, 0) H.step(0.1)
	local raise, fire
	H.tap("Left mouse")
	for _ = 1, 300 do
		H.step(1 / 60)
		raise = raise or plays_of(1555) > 0 and H.game_ms
		fire = fire or plays_of(1558) > 0 and H.game_ms
	end
	check(raise and fire, "a high shot: " .. shot_plays())
	check(fire - raise >= 3900, "fire after the whole 4 s raise: " .. (fire - raise) .. " ms")
end

-- the pair's muzzle comes from data.lua: a man with the high clips whose unit data.lua has no high muzzle for keeps level
T.a_unit_with_no_high_muzzle_keeps_the_level_pair = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	local f = H.E.D.fires_high[EMPX]
	H.E.D.fires_high[EMPX] = nil
	local ok, err = pcall(function() H.tap("Left mouse") H.step(1.5) end)
	H.E.D.fires_high[EMPX] = f
	assert(ok, err)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1554 and p[2][3] == 1557, "aim level, then fire level: " .. shot_plays())
end

-- with no known speed the straight line still picks the pair: steeply down is low
T.a_shot_with_no_known_speed_steeply_down_goes_low = function()
	playing({type = EMPX, men = 21, x = 40, range = 160, ammo = 100})
	set_view(nil, 1.1) H.step(0.1)
	local v = H.E.D.speeds[EMPX]
	H.E.D.speeds[EMPX] = nil
	local ok, err = pcall(function() H.tap("Left mouse") H.step(4.5) end)
	H.E.D.speeds[EMPX] = v
	assert(ok, err)
	local p = H.all("play")
	check(#p == 2 and p[1][3] == 1553 and p[2][3] == 1556, "aim low, then fire low: " .. shot_plays())
end

-- every order waits STEER_GAP from the last, whichever sent it: the engine drops one inside 0.5 s of another
local function none_dropped(what, n)
	check(H.count("dropped_order") == 0 and H.count(what) == n, what .. " " .. H.count(what) .. ", dropped "
		.. H.count("dropped_order"))
end

T.a_ground_fire_click_just_after_f2_is_not_dropped = function()
	H.fresh({units = {{general = true, men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.1) -- F2's own halt
	H.tap("Left mouse") H.step(1)
	none_dropped("uc:attack_location", 1)
end

T.a_ground_fire_just_after_the_last_one_ended_is_not_dropped = function()
	H.fresh({units = {{general = true, men = 1, range = 100, ammo = 10}}})
	H.tap("F2") H.step(0.6)
	H.tap("Left mouse")
	for _ = 1, 600 do H.step(1 / 60) if not H.E.F.firing then break end end
	check(not H.E.F.firing, "the first fire over")
	H.tap("Left mouse") H.step(1) -- its halt just before
	none_dropped("uc:attack_location", 2)
end

T.a_whole_unit_click_just_after_stopping_attacks = function()
	H.fresh({units = {{general = true, men = 1, slots = {[42] = true}}}, enemies = {{x = 3, z = 3, men = 10}}})
	H.tap("F2") H.step(0.6)
	H.down("W") H.step(0.6) H.up("W") H.step(1 / 60)
	H.tap("Left mouse") H.step(1)
	none_dropped("uc:attack_unit", 1)
end

T.a_whole_unit_turn_just_after_stopping_is_not_dropped = function()
	H.fresh({units = {{general = true, men = 1}}, enemies = {{x = 3, z = 3, men = 10}}})
	H.tap("F2") H.step(0.6)
	H.down("W") H.step(0.6) H.up("W")
	set_view(H.E.rig.yaw + 2) H.step(1 / 60)
	H.tap("Left mouse") H.step(1.5)
	none_dropped("uc:goto_location_angle_width", 1)
	check(H.count("play") >= 1, "then the swing")
end

-- an order waiting for its gap when third person ends is not sent in the next session
T.an_order_waiting_at_f2_is_not_sent_later = function()
	H.fresh({units = {{general = true, men = 1, slots = {[42] = true}}}, enemies = {{x = 3, z = 3, men = 10}}})
	H.tap("F2") H.step(0.6)
	H.down("W") H.step(0.6) H.up("W") H.step(1 / 60)
	H.tap("Left mouse") H.tap("F2") H.step(0.1)
	H.tap("F2") H.step(1)
	check(H.count("uc:attack_unit") == 0, "no attack order: " .. H.count("uc:attack_unit"))
end

-- a phase starts on its own clip only: the engine reports the fire clip 0.19-0.31 s late and his shooting idle until
-- then; the shot leaves with the fire clip, never on the idle before it
T.a_shot_waits_for_its_fire_clip_not_the_idle_before_it = function()
	crossbowmen()
	H.report_ms = 300
	H.tap("Left mouse")
	local sent, left
	for _ = 1, 360 do
		H.step(1 / 60)
		local s = H.E.F.shot
		if not sent and s and s.phase == "fire" then sent = H.game_ms H.E.F.model.reported = 1439 end
		if not left and H.count("launch") > 0 then left = H.game_ms end
	end
	check(sent and left and left - sent >= 290, "the shot leaves with the fire clip, 300 ms on: "
		.. tostring(sent and left and left - sent))
end

-- a shooter's click waits for his jump, as a swing does (C.attack's lock: C.melee has its own)
T.a_shot_waits_for_a_jump = function()
	crossbowmen()
	H.tap("E") H.step(0.1)
	check(plays_of(489) + plays_of(490) + plays_of(491) + plays_of(492) + plays_of(493) >= 1, "jumping")
	H.tap("Left mouse") H.step(0.5)
	check(plays_of(1554) + plays_of(1557) == 0, "no shot over the jump")
end

-- a unit played whole without the jump clips: E gives no attack order in its place
T.e_does_nothing_for_a_whole_unit_without_the_clip = function()
	H.fresh({units = {{general = true, men = 1, slots = {[42] = true}}}, enemies = {{x = 3, z = 3, men = 10}}})
	H.tap("F2") H.step(0.6)
	H.tap("E") H.step(1)
	check(H.count("uc:attack_unit") == 0, "no attack order: " .. H.count("uc:attack_unit"))
end

T.a_mount_does_not_require_the_riders_first_attack = function()
	local P, mr, put, BASE = real_platform()
	local m, horse = mr.add(mr.base, 0x6300000), BASE + 0x6400000
	put(m.addr + 0x2e0, horse, 8)
	put(m.addr + 0x308, BASE + 0x6500000, 8)
	put(BASE + 0x6500000 + 0x50 + 1901 * 2, 0xffff, 2)
	check(P.mount(m) and P.mount(m).addr == horse, "Tyrion has a horse without RIDER_ATTACK_1")
end

T.tyrion_swings_through_his_mount_without_rider_attack_one = function()
	local u = playing({type = "wh_test_tyrion", men = 1, slots = {[1902] = true, [1903] = true, [1904] = true}})
	u._models[1].mount = {id = 999, slots = {[454] = true, [455] = true, [456] = true, [457] = true, [458] = true}}
	H.tap("Left mouse") H.step(0.3)
	local p = H.last("play")
	check(p and p[2] == 999 and p[3] >= 454 and p[3] <= 457, "the click plays a horse attack")
	check(H.count("uc:attack_unit") == 0, "no fallback order in place of his swing")
end

-- measured live 2026-10-16 (probes/zz_tp_run_speed.lua, the Knights of the White Wolf, W held): his own walk carried the
-- engine's run speed, 7.8 m/s, and the horse moved 1.25 m/s, sprinting 1.31 - never faster than it could stop in the 3 m
-- to its steering point (the author: "horse speed mismatch; running but still staying at walking speed"). The point 15 m
-- ahead: 7.35 m/s, sprinting 8.89 of 9.36. A man on foot keeps 3 m
T.a_horses_steering_point_is_far_enough_to_run = function()
	local u = playing({type = "wh_test_mount", men = 2})
	for i, m in ipairs(u._models) do m.mount = {id = 990 + i, x = m.x, y = m.y, z = m.z, hp = 100, hp_max = 100} end
	H.down("W") H.step(0.5)
	local s, horse = H.last("steer"), H.E.F.model.mount
	check(s and s[2] == horse.id, "the horse is steered")
	local d = math.sqrt((s[3] - horse.x) ^ 2 + (s[4] - horse.z) ^ 2)
	check(near(d, 15), "its point 15 m ahead: " .. d)
end

T.a_riders_health_is_the_mounts_health = function()
	local P, mr, put, BASE = real_platform()
	local m, horse = mr.add(mr.base, 0x6300000), BASE + 0x6400000
	put(m.addr + 0x2e0, horse, 8)
	put(m.addr + 0xb1c, 16, 4) put(m.addr + 0xb18, 16, 4)
	put(horse + 0xb1c, 9800, 4) put(horse + 0xb18, 9800, 4)
	local hp, max = P.model_hp(m)
	check(hp == 9800 and max == 9800, "Tyrion's health belongs to his mount, not the 16 hp rider")
end

T.a_dead_model_still_in_the_list_is_not_alive = function()
	local P, mr, put, BASE = real_platform()
	local u = fake_unit(mr, put, BASE, {{x = 0, z = 0, marker = BASE + 0x390d4f8, steer = {{0, 0}, {0, 0}, {0, 0}}}})
	local m = P.models(u)[1]
	put(m.addr + 0xb1c, 0, 4)
	check(not P.alive(u, m), "list membership does not make a dying man alive")
end

T.the_front_man_skips_a_dead_model_still_in_the_list = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	local dead = H.E.F.model
	dead.hp = 0
	check(H.E.move.front_man(u) ~= dead, "the dead front man cannot be picked again")
end

T.a_mount_can_sprint_without_a_moving_attack = function()
	local u = playing({type = "wh_test_cavalry", men = 21, slots = {[1902] = true}})
	local horse = {id = 999, x = 40, y = 0, z = 0, hp = 114, hp_max = 114, slots = {[42] = true, [135] = true, [454] = true}}
	u._models[11].mount = horse
	H.down("W") H.down("Shift") H.step(0.3)
	local p = H.last("play")
	check(p and p[2] == 999 and p[3] == 135, "the horse's CHARGE does not need MOVING_ATTACK")
	H.up("Shift") H.step(0.1)
	check(H.last("play")[2] == 999 and H.last("play")[3] == 42, "release ends the horse's charge")
end

T.a_riders_jump_plays_the_mounts_jump = function()
	H.fresh({units = {{general = true, men = 21, slots = {[1902] = true}}}})
	local horse = {id = 999, x = 0, y = 0, z = 0, hp = 114, hp_max = 114,
		slots = {[42] = true, [454] = true, [489] = true}}
	H.units[1]._models[11].mount = horse
	H.tap("F2") H.tap("E")
	local p = H.last("play")
	check(p and p[2] == 999 and p[3] == 489, "jump must not become an ordinary mount attack")
end

T.a_riders_cheer_plays_the_mounts_celebration = function()
	H.fresh({units = {{general = true, men = 21, slots = {[1902] = true}}}})
	local horse = {id = 999, x = 0, y = 0, z = 0, hp = 114, hp_max = 114, slots = {[42] = true, [1094] = true}}
	H.units[1]._models[11].mount = horse
	H.tap("F2")
	check(H.E.F.can_cheer, "the action bar offers the mount's celebration")
	H.E.combat.cheer(H.model_ms() / 1000)
	local p = H.last("play")
	check(p and p[2] == 999 and p[3] == 1094, "the offered celebration plays on its carrier")
end

T.a_new_front_man_gets_his_own_action_buttons = function()
	local u = playing({type = "wh_test_melee", men = 21, slots = {[42] = true, [454] = true}})
	local dead = H.E.F.model
	for _, m in ipairs(u._models) do
		if m ~= dead then m.slots = {[42] = true, [454] = true, [489] = true, [484] = true, [1094] = true} end
	end
	dead.hp = 0
	H.step(0.1)
	check(H.E.F.model ~= dead and H.E.F.can_jump and H.E.F.can_charge and H.E.F.can_cheer,
		"the new body determines its jump, charge and cheer buttons")
end

T.a_single_entity_at_zero_hp_releases_control = function()
	H.fresh() H.tap("F2")
	H.units[1]._models[1].hp = 0
	H.step(0.1)
	check(not H.E.F.on, "HP zero ends control while the dead entity is still listed")
end

T.an_idle_single_entity_is_guarded = function()
	H.fresh() H.tap("F2") H.step(0.1)
	check(H.count("guard") > 0, "a single entity must not accept engine attacks without a click")
end

T.the_next_shooter_does_not_inherit_a_nonshooters_restriction = function()
	local u = playing({type = XBOW, men = 21, range = 160, ammo = 3960, slots = {[42] = true, [454] = true}})
	local dead = H.E.F.model
	check(H.E.F.cannot_shoot, "the first man has no fire clip")
	for _, m in ipairs(u._models) do
		if m ~= dead then m.slots = {[42] = true, [454] = true, [1554] = true, [1557] = true, [1564] = true} end
	end
	dead.hp = 0 H.step(0.1)
	H.tap("Right mouse")
	check(H.E.F.solo and not H.E.F.cannot_shoot and H.E.F.ranged, "the next man can enter his own ranged mode")
end

T.a_flying_mount_chooses_an_available_air_attack = function()
	local u = playing({type = "wh_test_fly_mount", men = 1, flying = true, slots = {[1902] = true, [1942] = true}})
	u._models[1].mount = {id = 999, slots = {[454] = true, [455] = true, [495] = true}}
	H.tap("Left mouse")
	local p = H.last("play")
	check(p and p[2] == 999 and p[3] == 495, "the only available airborne attack plays")
end

T.switching_to_ranged_cancels_a_native_melee_attack = function()
	playing({type = "wh_test_ranged_lord", men = 1, range = 90, ammo = 20, slots = {[42] = true}}, {{z = 3, men = 10}})
	H.step(0.6) H.tap("Right mouse") H.tap("Left mouse") H.step(0.6)
	check(H.E.F.native_attack, "the clipless melee click uses a native attack")
	H.tap("Right mouse")
	check(H.E.F.ranged and not H.E.F.native_attack, "ranged mode restores the guard against the old melee order")
end

T.artillery_crew_keep_their_own_melee_clip = function()
	local u = playing({type = "wh_test_artillery", men = 4, arty = true, slots = {[42] = true, [454] = true}})
	for _, m in ipairs(u._models) do m.mount = {id = 999, slots = {[42] = true}} end
	H.tap("Left mouse")
	check(H.count("play") == 4 and H.last("play")[3] == 454 and H.last("play")[2] ~= 999,
		"a crewman's gun parent does not take his melee attack")
end

T.men_check_reads_the_mounts_steering_copies = function()
	local P, mr, put, BASE = real_platform()
	local u = fake_unit(mr, put, BASE, {{x = 0, z = 0, marker = BASE + 0x390d4f8,
		steer = {{5000, 5000}, {5000, 5000}, {0, 0}}}})
	local m, horse = P.models(u)[1], BASE + 0x6600000
	put(m.addr + 0x2e0, horse, 8)
	for _, off in ipairs({0x1e0, 0x1e8, 0x194, 0x198}) do mr.fl[horse + off] = 0 end
	check(P.check_men(u), "validate steering on the horse that receives the movement")
end

return T
