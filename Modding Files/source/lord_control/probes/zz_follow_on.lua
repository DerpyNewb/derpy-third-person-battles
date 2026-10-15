-- Third-person control of one unit, toggled with F2. Live probe through the wh3-mcp bridge.
-- F2 takes the selected unit when exactly one is selected, otherwise the general.
--
-- Camera: player camera input is switched off while it runs, so the per-frame move_to has nothing
-- to fight. unit:position() steps every ~0.2 s, so the camera plays the unit back DELAY seconds
-- late, sliding linearly between the two real samples either side of that moment, then a light
-- spring. Its yaw belongs to the mouse alone (action-game style), so steering does not swing it.
--
-- memreader (optional): Windows calls through Warhammer3.exe's import table (RVAs from
-- exe_imports.py, split into exact float32 parts). Mouse orbits the camera with the cursor parked
-- and hidden at the window centre; holding the middle button frees it. W/A/S/D held walk the unit
-- relative to the camera; tapping Shift toggles running. Holding a key orders the unit to a point
-- LEAD m ahead and re-orders only when it gets within REFRESH m, the keys or run toggle change, or
-- the camera turns more than STEER_DEG with STEER_GAP passed since the last order: move orders under
-- ~0.4 s apart stall a unit outright (measured: 20 orders in 6 s, 0 m moved), so mouse jitter must not
-- re-order. (Writing the move destination in memory instead did not keep it walking.) Left/right
-- click, at most once per ATTACK_COOLDOWN, turn the unit to the camera and FORCE an attack animation
-- (reverse-engineered, see handoff 9e; the swings deal damage): a forged
-- copy of the engine's own play-animation command, pushed on the battle command queue for every
-- model in the unit. Without memreader the clicks fall back to attack_unit on the enemy nearest
-- the aim.
--
-- Ranged: a unit that can shoot starts in ranged mode and right click switches melee/ranged. In
-- ranged mode, holding left click fires at the ground point under the screen centre (look down to
-- aim closer) and releasing stops; melee mode swings as above. On artillery, right click hands over
-- to the game's own Manual fire mode (Insert) and control comes back when it closes.
--
-- Zoom: the wheel or holding + / - scales the whole rig (big entities otherwise show only their
-- feet), remembered per unit type for the battle. The engine's own wheel zoom is useless here (the
-- per-frame move_to wipes it) and Windows has no polling call for the wheel, so the wheel comes from
-- our own DirectInput 8 mouse (the game imports DirectInput8Create): non-exclusive and background, so
-- it shares the mouse with the game, with a one-axis format (GUID_ZAxis, relative) whose
-- GetDeviceState is the wheel's movement since the last poll, 120 per notch. One device per battle,
-- never released (memreader's alloc has no free either).
--
-- Stats in _G.DERPY_FOLLOW; zz_follow_off.lua removes everything.
local DIST, HEIGHT, LOOK_H, AHEAD = 6, 2.5, 1.8, 6
local DELAY, K_POS = 0.45, 20
-- ranged mode's over-the-shoulder rig (m, scaled by zoom), and how fast it blends in or out per second
local OTS_BACK, OTS_SIDE, OTS_HEIGHT, OTS_AHEAD, OTS_RATE = 3.2, 1.0, 2.0, 30, 4
local ZOOM_MIN, ZOOM_MAX, ZOOM_LARGE = 0.6, 6, 2 -- rig scale; ZOOM_LARGE = first guess for non-infantry
local ZOOM_RATE, ZOOM_NOTCH = 1.2, 0.15 -- per second held + / - (main row or numpad); per wheel notch
local SENS, PITCH_MIN, PITCH_MAX = 0.004, -0.25, 1.1
local LEAD, REFRESH, STEER_DEG, RIGHT_SIGN = 15, 6, 12, 1
local STEER_GAP = 0.5 -- s between steering re-orders; orders closer than this stall the walk
local ATTACK_COOLDOWN = 1.5 -- s between swings (forced swings do deal damage)
local AIM_COS, AIM_RANGE, AIM_CLOSE = 0.707, 150, 8
local AIM_MIN, FIRE_REAIM = 10, 5 -- m: nearest point a held left click fires at; re-aim once the point moves this far
local FIRE_COMMIT = 4 -- s: a released click keeps its fire order until ammo drops (a shot left) or this long after the order
local FIRE_ARC = 20 -- deg: ground fire outside the unit's facing does not shoot at all (60 deg off: nothing), so it turns first
local MODEL_POS = 0x88 -- a model object's x, y, z (float32), matched against the general's position()
-- one man of a regiment shoots alone: his fire animation, then bm:trigger_projectile_launch from him to
-- the aim point, a projectile with no unit behind it (20 scripted bolts killed a Plaguebearer while the
-- regiment held fire), so the regiment's fire-at-will is off while he is played. A forced FIRE animation
-- launches nothing and a ground-fire order fires every man - no per-man gate was found.
-- unit type -> {projectile key, base_reload_time, projectiles per shot}, from the projectiles table;
-- a type not listed falls back to the regiment's ground fire.
-- ponytail: hand-typed for the test battle's units, generate it from db for the pack
local SOLO = {
	types = {
		wh3_main_cth_inf_jade_warrior_crossbowmen_1 = {"wh3_cth_crossbow_bolt", 13, 1},
		wh3_main_cth_inf_iron_hail_gunners_0 = {"wh3_cth_iron_hail_gun_bullet", 13, 3},
		wh3_main_cth_inf_grenadiers = {"wh3_main_cth_grenade", 10, 1},
	},
	reload_scale = 0.25, delay_ms = 300, -- reload x; the animation's start to the release
	height = 1.5, spread = 1.5, -- m above his feet; m jitter of a shot's extra projectiles
	fire = 1557, reload = 1564, -- FIRE_LEVEL, RELOAD_1
}
-- one man walking alone (spike, 9.0): his steering point's three copies, how far ahead of him it is held,
-- and the position nudge that starts his walk (an idle man ignores the point)
local STEER_FIELDS, MAN_LEAD, MAN_NUDGE, MAN_STUCK = {{0x1e0, 0x1e8}, {0x194, 0x198}, {0x368, 0x370}}, 3, 0.5, 0.05
local BLOCK_PLAYER_ORDERS = true
-- forced swings (9.0 addresses, each split into two exact float32 parts)
local SLOTS_LMB, SLOTS_RMB = {454, 455, 456, 457}, {458, 459, 460}
local TURN_DEG, TURN_WAIT_MS, MAX_MODELS = 25, 350, 160
local CMD_TYPE, CMD_PUSH, BATTLE_GLOBAL = {0x3900000, 0x1cd0}, {0x2e00000, 0x969ac}, {0x4400000, 0x79ee0}
-- every key in one place, as Windows virtual-key codes (a list means any of them): the packaged build
-- fills this from MCT. F2 itself is the game's script_F2 shortcut, not polled.
local KEYS = {forward = 87, back = 83, left = 65, right = 68, run = 16, look_free = 4, attack = 1, mode = 2,
	zoom_in = {0xBB, 0x6B}, zoom_out = {0xBD, 0x6D}}
local IAT_HI, IAT_GETCURSORPOS, IAT_SETCURSORPOS, IAT_GETASYNCKEYSTATE, IAT_GETFOREGROUNDWINDOW = 0x3300000, 0xa2e38, 0xa2c20, 0xa2cc0, 0xa2b70
local IAT_GETCLIENTRECT, IAT_CLIENTTOSCREEN, IAT_DIRECTINPUT8CREATE = 0xa2bd8, 0xa2df8, 0xa2140
local ok, res = pcall(function()
	core:remove_listener("derpy_follow_key")
	bm:remove_real_callback("derpy_follow")
	local cam = bm:camera()
	local F = {on = false, frames = 0, fought = 0, max_fight = 0, steps = 0, orders = 0, attacks = 0, swings = 0, log = {}, opitch = 0}
	_G.DERPY_FOLLOW = F
	F.running = false

	-- selection: which player units are selected, kept by unique_ui_id (one registration per battle)
	local SEL = _G.DERPY_SELECTED or {ids = {}, set = {}}
	_G.DERPY_SELECTED = SEL
	local general
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		if u:is_commanding_unit() then general = u end
		local id = u:unique_ui_id()
		if not SEL.ids[id] then
			SEL.ids[id] = true
			bm:register_unit_selection_callback(u, function(unit, selected)
				SEL.set[unit:unique_ui_id()] = selected and unit or nil
			end)
		end
	end

	local function pick_unit()
		if bm:num_units_selected() == 1 then
			for _, u in pairs(SEL.set) do return u end
		end
		return general
	end

	-- the cursor is hidden while the mouse is looking, shown whenever it is free; calls on change only
	local function show_cursor(show)
		if F.cursor_hidden == not show then return end
		F.cursor_hidden = not show
		if show then bm:enable_cinematic_ui(false, true, false) else bm:enable_cinematic_ui(true, false, false) end
	end

	-- ranged mode's aiming dot: our own instance of the first-person mode's layout, which centres
	-- ui/skins/default/crosshair.png; every other part of it hidden. The aim ray goes through it.
	local function crosshair(show)
		if F.xhair == show then return end
		F.xhair = show
		local root = core:get_ui_root()
		local ui = find_uicomponent(root, "derpy_crosshair_ui")
		if not ui then
			if not show then return end
			ui = UIComponent(root:CreateComponent("derpy_crosshair_ui", "ui/battle ui/first_person_ui"))
			for i = 0, ui:ChildCount() - 1 do local c = UIComponent(ui:Find(i)) c:SetVisible(c:Id() == "crosshair") end
			local x = find_uicomponent(ui, "crosshair")
			local sw, sh = core:get_screen_resolution()
			local w, h = x:Dimensions()
			x:MoveTo(math.floor(sw / 2 - w / 2), math.floor(sh / 2 - h / 2))
		end
		ui:SetVisible(show)
	end

	local mr = _G.memreader_plus
	local W
	if mr then
		local function iat(lo) return mr.read_pointer(mr.add(mr.add(mr.base, IAT_HI), lo)) end
		local function sysdll(p) local s = mr.tostring(p) return s >= "00007FF000000000" and s < "0000800000000000" end
		W = {gcp = iat(IAT_GETCURSORPOS), scp = iat(IAT_SETCURSORPOS), gaks = iat(IAT_GETASYNCKEYSTATE), gfw = iat(IAT_GETFOREGROUNDWINDOW),
			gcr = iat(IAT_GETCLIENTRECT), c2s = iat(IAT_CLIENTTOSCREEN), buf = mr.alloc(8), rect = mr.alloc(16)}
		for _, fn in pairs({W.gcp, W.scp, W.gaks, W.gfw, W.gcr, W.c2s}) do
			if not sysdll(fn) then W = nil break end
		end
	end
	F.mouse = W ~= nil

	-- the wheel's DirectInput mouse, kept in _G.DERPY_DI so a reload reuses it; nil when it cannot open
	local function open_wheel(hwnd)
		local D = _G.DERPY_DI
		if D and D.dev then return D end
		local create = mr.read_pointer(mr.add(mr.add(mr.base, IAT_HI), IAT_DIRECTINPUT8CREATE))
		local s = mr.tostring(create)
		if s < "00007FF000000000" or s >= "0000800000000000" then return nil end
		local m = mr.alloc(160)
		local function bytes(off, t) for i = 1, #t do mr.write(m, off + i - 1, mr.uint8(t[i])) end end
		bytes(0, {0x31, 0x80, 0x79, 0xBF, 0x3A, 0x48, 0xA2, 0x4D, 0xAA, 0x99, 0x5D, 0x64, 0xED, 0x36, 0x97, 0x00}) -- IID_IDirectInput8W
		bytes(16, {0x60, 0x2B, 0x1D, 0x6F, 0xA0, 0xD5, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_SysMouse
		bytes(32, {0xE2, 0x02, 0x6D, 0xA3, 0xF3, 0xC9, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_ZAxis
		mr.write(m, 64, mr.add(m, 32)) -- DIOBJECTDATAFORMAT: pguid, dwOfs 0, DIDFT_AXIS | DIDFT_ANYINSTANCE, dwFlags 0
		mr.write(m, 76, mr.uint32(0x00FFFF03))
		mr.write(m, 96, mr.uint32(32)) -- DIDATAFORMAT: dwSize, dwObjSize 24, DIDF_RELAXIS, dwDataSize 4, 1 object, rgodf
		mr.write(m, 100, mr.uint32(24))
		mr.write(m, 104, mr.uint32(2))
		mr.write(m, 108, mr.uint32(4))
		mr.write(m, 112, mr.uint32(1))
		mr.write(m, 120, mr.add(m, 64))
		local function method(obj, i) return mr.read_pointer(mr.read_pointer(obj, 0), i * 8) end
		if mr.tonumber(mr.call(create, "int32(pointer, uint32, pointer, pointer, pointer)", mr.base, 0x800, m, mr.add(m, 48), nil)) ~= 0 then return nil end
		local di = mr.read_pointer(m, 48)
		if mr.tonumber(mr.call(method(di, 3), "int32(pointer, pointer, pointer, pointer)", di, mr.add(m, 16), mr.add(m, 56), nil)) ~= 0 then return nil end
		local dev = mr.read_pointer(m, 56)
		if mr.tonumber(mr.call(method(dev, 11), "int32(pointer, pointer)", dev, mr.add(m, 96))) ~= 0 then return nil end
		mr.call(method(dev, 13), "int32(pointer, pointer, uint32)", dev, hwnd, 0xA) -- DISCL_NONEXCLUSIVE | DISCL_BACKGROUND
		mr.call(method(dev, 7), "int32(pointer)", dev)
		D = {dev = dev, acquire = method(dev, 7), state = method(dev, 9), buf = mr.add(m, 128)}
		_G.DERPY_DI = D
		return D
	end

	-- wheel movement since the last poll, in notches; re-acquires after a lost device
	local function wheel()
		local D = F.wheel
		if mr.tonumber(mr.call(D.state, "int32(pointer, uint32, pointer)", D.dev, 4, D.buf)) ~= 0 then
			mr.call(D.acquire, "int32(pointer)", D.dev)
			return 0
		end
		return mr.read_int32(D.buf, 0) / 120
	end

	local function down(vk)
		if type(vk) == "table" then
			for _, k in ipairs(vk) do if down(k) then return true end end
			return false
		end
		return mr.tonumber(mr.call(W.gaks, "int16(int32)", vk)) < 0
	end

	-- a key or button going down this frame (edge), tracked per virtual key
	local was = {}
	local function pressed(vk)
		local d = down(vk)
		local edge = d and not was[vk]
		was[vk] = d
		return edge
	end

	-- the window centre in screen pixels, recomputed each time looking resumes (the window can move)
	local function centre()
		mr.call(W.gcr, "int32(pointer, pointer)", F.hwnd, W.rect)
		mr.write(W.buf, 0, mr.int32(math.floor(mr.read_int32(W.rect, 8) / 2)))
		mr.write(W.buf, 4, mr.int32(math.floor(mr.read_int32(W.rect, 12) / 2)))
		mr.call(W.c2s, "int32(pointer, pointer)", F.hwnd, W.buf)
		return mr.read_int32(W.buf, 0), mr.read_int32(W.buf, 4)
	end

	local function mouse_look()
		if down(KEYS.look_free) then F.dragging = false show_cursor(true) return end
		if not F.dragging then
			show_cursor(false)
			F.dragging, F.ax, F.ay = true, centre()
			mr.call(W.scp, "int32(int32, int32)", F.ax, F.ay)
			return
		end
		mr.call(W.gcp, "int32(pointer)", W.buf)
		local mx, my = mr.read_int32(W.buf, 0), mr.read_int32(W.buf, 4)
		if mx ~= F.ax or my ~= F.ay then
			F.cyaw = F.cyaw + (mx - F.ax) * SENS
			F.opitch = math.max(PITCH_MIN, math.min(PITCH_MAX, F.opitch + (my - F.ay) * SENS))
			mr.call(W.scp, "int32(int32, int32)", F.ax, F.ay)
		end
	end

	local function halt()
		if F.driving then
			F.uc:halt()
			F.uc:release_control()
			F.driving = false
		end
	end

	-- the enemy nearest the aim: inside AIM_COS of the camera's forward and AIM_RANGE, or within
	-- AIM_CLOSE in any direction; distance weighted by how far off the aim it is
	local function pick_target()
		local q = F.unit:position()
		local qx, qz = q:get_x(), q:get_z()
		local fx, fz = math.sin(F.cyaw), math.cos(F.cyaw)
		local best, best_score
		local armies = bm:get_non_player_alliance():armies()
		for a = 1, armies:count() do
			local list = armies:item(a):units()
			for i = 1, list:count() do
				local e = list:item(i)
				if e:is_valid_target() and not e:is_routing() and e:number_of_men_alive() > 0 then
					local p = e:position()
					local dx, dz = p:get_x() - qx, p:get_z() - qz
					local d = math.sqrt(dx * dx + dz * dz)
					local c = (dx * fx + dz * fz) / math.max(d, 0.01)
					if d < AIM_CLOSE or (c > AIM_COS and d < AIM_RANGE) then
						local score = d * (2 - c)
						if not best_score or score < best_score then best, best_score = e, score end
					end
				end
			end
		end
		return best
	end

	local function models_of()
		local obj = mr.read_pointer(mr.ud_topointer(F.unit), 8)
		return mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8) -- alive models only: the size drops as men die
	end

	-- a regiment is played as one man: the camera follows him and swings play on him alone. He is the
	-- front-centre model, where the captain stands: position_of_officer() returns nil and no officer
	-- flag was found. He walks alone (man_drive) and, for a type in SOLO, shoots alone (man_shoot).
	local function pick_model()
		if not W then return nil end
		local n, models = models_of()
		if n < 2 then return nil end
		local q = F.unit:position()
		local b = math.rad(F.unit:bearing())
		local fx, fz = math.sin(b), math.cos(b)
		local best, best_score
		for k = 0, n - 1 do
			local m = mr.read_pointer(models, k * 8)
			local dx, dz = mr.read_float(m, MODEL_POS) - q:get_x(), mr.read_float(m, MODEL_POS + 8) - q:get_z()
			local score = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
			if not best_score or score < best_score then best, best_score = m, score end
		end
		return best
	end

	local function model_alive(p)
		local n, models = models_of()
		for k = 0, n - 1 do if mr.eq(mr.read_pointer(models, k * 8), p) then return true end end
		return false
	end

	-- push the engine's play-animation command for each model of the unit, or the one man followed;
	-- returns models queued
	local function queue_anim(slot)
		local function at(parts) return mr.add(mr.add(mr.base, parts[1]), parts[2]) end
		local b = mr.read_pointer(mr.read_pointer(at(BATTLE_GLOBAL)), 0x468)
		if mr.read_uint8(b, 0x3b0) ~= 0 or mr.read_uint8(b, 0x3b1) ~= 0 then F.gate_closed = (F.gate_closed or 0) + 1 return 0 end
		local queue = mr.read_pointer(b, 0x644e8)
		local n, models = models_of()
		n = math.min(n, MAX_MODELS)
		W.cmd = W.cmd or mr.alloc(32)
		mr.write(W.cmd, 0, at(CMD_TYPE))
		mr.write(W.cmd, 0x10, mr.uint16(slot))
		mr.write(W.cmd, 0x12, mr.uint8(0))
		mr.write(W.cmd, 0x14, mr.uint32(0))
		if F.model then n = 1 end
		for k = 0, n - 1 do
			mr.write(W.cmd, 8, F.model or mr.read_pointer(models, k * 8))
			mr.call(at(CMD_PUSH), "uint8(pointer, pointer)", queue, W.cmd)
		end
		return n
	end

	-- turn to the camera if more than TURN_DEG off, then force the next slot of the list
	local function swing(slots)
		local slot = slots[F.swings % #slots + 1]
		F.swings = F.swings + 1
		local want = math.deg(F.cyaw) % 360
		local off = math.abs((want - F.unit:bearing() + 540) % 360 - 180)
		local wait = 0
		if off > TURN_DEG and not F.model then
			local q = F.unit:position()
			F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
			F.uc:release_control()
			wait = TURN_WAIT_MS
		end
		F.driving = false
		local function go()
			local good, err = pcall(function() F.queued, F.last_slot = queue_anim(slot), slot end)
			if not good then F.swing_err = tostring(err) end
		end
		if wait > 0 then bm:real_callback(go, wait, "derpy_follow_swing") else go() end
	end

	local function attack(primary, fast)
		local now = os.clock()
		if now < (F.next_attack or 0) then F.cooling = (F.cooling or 0) + 1 return end
		F.next_attack = now + ATTACK_COOLDOWN
		if W then swing(primary and SLOTS_LMB or SLOTS_RMB) return end
		local target = pick_target()
		if not target then F.no_target = (F.no_target or 0) + 1 return end
		F.uc:attack_unit(target, primary, fast)
		F.uc:release_control()
		F.driving = false
		F.attacks, F.target = F.attacks + 1, target:name()
	end

	F.attack_fn = attack

	local function can_shoot() return F.unit:missile_range() > 0 and F.unit:ammo_left() > 0 end

	-- the ground point under the screen centre: last frame's camera ray (position -> look-at) meets the
	-- ground at the unit's height; looking level or up, or past the unit's range, clamps to its range
	local function aim_point()
		local q = F.unit:position()
		local ux, gy, uz = q:get_x(), q:get_y(), q:get_z()
		local reach = F.unit:missile_range()
		local dx, dy, dz = F.lx - F.ex, F.ly - F.ey, F.lz - F.ez
		local hx, hz, want = dx, dz, reach
		if dy < 0 then
			local t = (F.ey - gy) / -dy
			hx, hz = F.ex + dx * t - ux, F.ez + dz * t - uz
			want = math.max(AIM_MIN, math.min(reach, math.sqrt(hx * hx + hz * hz)))
		end
		local d = math.sqrt(hx * hx + hz * hz)
		if d < 0.01 then hx, hz, d = math.sin(F.cyaw), math.cos(F.cyaw), 1 end
		return ux + hx / d * want, gy, uz + hz / d * want
	end

	-- held left click in ranged mode: ground fire at the aim point, the order behind artillery's ALT
	-- manual aim, which works for missile infantry too (crossbowmen spent 27 bolts in 6 s at a point
	-- 80 m out). It keeps firing until halted; re-aimed when the point moves, no faster than STEER_GAP.
	local function fire(now)
		if not F.ex then return end
		local ax, ay, az = aim_point()
		local q = F.unit:position()
		local want = math.deg(math.atan2(ax - q:get_x(), az - q:get_z())) % 360
		if math.abs((want - F.unit:bearing() + 540) % 360 - 180) > FIRE_ARC then
			-- wheel to face the aim first; re-ordered only when the aim swings half an arc further
			local turned = F.turn_to and math.abs((want - F.turn_to + 540) % 360 - 180) <= FIRE_ARC / 2
			if not turned and now - (F.last_order or 0) >= STEER_GAP then
				F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
				F.uc:release_control()
				F.turn_to, F.fire_at, F.last_order, F.driving = want, nil, now, false
			end
			return
		end
		F.turn_to = nil
		if F.fire_at and ((ax - F.fire_at[1]) ^ 2 + (az - F.fire_at[2]) ^ 2 < FIRE_REAIM * FIRE_REAIM or now - F.last_order < STEER_GAP) then return end
		F.uc:attack_location(v(ax, ay, az), false)
		F.uc:release_control()
		F.fire_at, F.last_order, F.driving = {ax, az}, now, false
		F.fire_order_t = F.fire_order_t or now
		F.shots = (F.shots or 0) + 1
	end

	local function stop_fire()
		F.firing, F.fire_at, F.turn_to, F.fire_order_t = false, nil, nil, nil
		F.uc:halt()
		F.uc:release_control()
	end

	-- the one man's shot (see SOLO): no faster than his reload, launched SOLO.delay_ms into the animation
	-- from his chest towards the aim point, one bolt off the regiment's ammo
	local function man_shoot(now)
		local s = SOLO.types[F.utype]
		if now < (F.next_shot or 0) then return end
		F.next_shot = now + s[2] * SOLO.reload_scale
		local ax, ay, az = aim_point()
		queue_anim(SOLO.fire)
		F.shot_n = (F.shot_n or 0) + 1
		bm:real_callback(function()
			local good, err = pcall(function()
				local m = F.model
				if not m then return end
				local x, y, z = mr.read_float(m, MODEL_POS), mr.read_float(m, MODEL_POS + 4), mr.read_float(m, MODEL_POS + 8)
				local dx, dz = ax - x, az - z
				local d = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
				local from = v(x + dx / d * 0.6, y + SOLO.height, z + dz / d * 0.6)
				for k = 1, s[3] do
					local jx, jz = 0, 0
					if k > 1 then jx, jz = (math.random() * 2 - 1) * SOLO.spread, (math.random() * 2 - 1) * SOLO.spread end
					bm:trigger_projectile_launch(s[1], from, v(ax + jx, ay + 1, az + jz))
				end
				local ammo, full = F.unit:ammo_left(), F.unit:starting_ammo()
				if full > 0 then F.unit:set_current_ammo_unary((ammo - 1) / full) end
				F.shots = (F.shots or 0) + 1
				queue_anim(SOLO.reload)
			end)
			if not good then F.shot_err = tostring(err) end
		end, SOLO.delay_ms, "derpy_follow_shot" .. F.shot_n)
	end

	F.fire_fn, F.stop_fire_fn, F.man_shoot_fn = fire, stop_fire, man_shoot

	-- W/A/S/D relative to the camera; F.sim = {forward, right, until} stands in for held keys in a test
	-- one man of a regiment walks alone, the regiment gets no order. Each man chases his own steering
	-- point; it is held every frame, MAN_LEAD ahead while a key is held and on his own spot when none
	-- is, so he does not walk back to his slot. It is only read while he walks: when a held key has
	-- not moved him MAN_STUCK in half a second, a MAN_NUDGE shove of his position starts the walk.
	-- Measured in the spike: 5.6 m in 5 s through his own ranks while the neighbours stayed.
	local function man_drive(now, dx, dz)
		local m = F.model
		local x, z = mr.read_float(m, MODEL_POS), mr.read_float(m, MODEL_POS + 8)
		local tx, tz
		if dx == 0 and dz == 0 then
			F.man_hold = F.man_hold or {x, z}
			tx, tz, F.man_check = F.man_hold[1], F.man_hold[2], nil
		else
			F.man_hold = nil
			local c = F.man_check
			if not c or (now - c[1] > 0.5) then
				if c and (x - c[2]) ^ 2 + (z - c[3]) ^ 2 < MAN_STUCK * MAN_STUCK then
					mr.write(m, MODEL_POS, x + dx * MAN_NUDGE)
					mr.write(m, MODEL_POS + 8, z + dz * MAN_NUDGE)
					F.nudges = (F.nudges or 0) + 1
				end
				F.man_check = {now, x, z}
				if not c then -- first frame of a walk: nudge at once rather than wait half a second
					mr.write(m, MODEL_POS, x + dx * MAN_NUDGE)
					mr.write(m, MODEL_POS + 8, z + dz * MAN_NUDGE)
					F.nudges = (F.nudges or 0) + 1
				end
			end
			tx, tz = x + dx * MAN_LEAD, z + dz * MAN_LEAD
		end
		for _, f in ipairs(STEER_FIELDS) do mr.write(m, f[1], tx) mr.write(m, f[2], tz) end
	end

	local function drive(now, px, py, pz, keys)
		local kf, kr, run = 0, 0, false
		if keys then
			kf = (down(KEYS.forward) and 1 or 0) - (down(KEYS.back) and 1 or 0)
			kr = (down(KEYS.right) and 1 or 0) - (down(KEYS.left) and 1 or 0)
			if pressed(KEYS.run) then F.running = not F.running end
		end
		run = F.running
		if F.sim and now < F.sim[3] then kf, kr = F.sim[1], F.sim[2] end
		local dx, dz = 0, 0
		if kf ~= 0 or kr ~= 0 then
			local fx, fz = math.sin(F.cyaw), math.cos(F.cyaw)
			dx, dz = kf * fx + kr * fz * RIGHT_SIGN, kf * fz - kr * fx * RIGHT_SIGN
			local n = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / n, dz / n
		end
		if F.model then man_drive(now, dx, dz) return end
		if kf == 0 and kr == 0 then halt() return end
		local need = not F.driving or kf ~= F.kf or kr ~= F.kr or run ~= F.run
			or (px - F.gx) ^ 2 + (pz - F.gz) ^ 2 < REFRESH * REFRESH
			or dx * F.dx + dz * F.dz < math.cos(math.rad(STEER_DEG)) and now - F.last_order >= STEER_GAP
		if need then
			local why = not F.driving and "start" or (kf ~= F.kf or kr ~= F.kr) and "keys" or run ~= F.run and "run"
				or (px - F.gx) ^ 2 + (pz - F.gz) ^ 2 < REFRESH * REFRESH and "near" or "steer"
			F.why = F.why or {}
			F.why[why] = (F.why[why] or 0) + 1
			F.olog = F.olog or {}
			if #F.olog < 60 then F.olog[#F.olog + 1] = {now, why, math.floor(math.deg(F.cyaw)), keys and 1 or 0} end
			F.gx, F.gz, F.dx, F.dz = px + dx * LEAD, pz + dz * LEAD, dx, dz
			F.uc:goto_location(v(F.gx, py, F.gz), run)
			F.uc:release_control()
			F.kf, F.kr, F.run, F.driving, F.last_order = kf, kr, run, true, now
			F.orders = F.orders + 1
		end
	end

	local function stop(why)
		halt()
		crosshair(false)
		if F.firing then stop_fire() end
		if F.solo then F.uc:fire_at_will(true) F.uc:release_control() end
		show_cursor(true)
		if BLOCK_PLAYER_ORDERS then bm:disable_orders(false) end
		bm:remove_real_callback("derpy_follow")
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", true)
		F.on, F.stopped = false, why
	end

	local enter_manual -- defined after start(): the artillery hand-over needs it

	local function tick()
		local good, err = pcall(function()
			local now = os.clock()
			local dt = now - F.t
			F.t = now
			if dt <= 0 or dt > 0.25 then dt = 0.016 end
			local q = F.unit:position()
			local px, py, pz = q:get_x(), q:get_y(), q:get_z()
			local mx, my, mz = px, py, pz
			if F.model then
				if F.frames % 30 == 0 and not model_alive(F.model) then F.model, F.man_hold, F.man_check = pick_model(), nil, nil end -- he died
				if F.model then mx, my, mz = mr.read_float(F.model, MODEL_POS), mr.read_float(F.model, MODEL_POS + 4), mr.read_float(F.model, MODEL_POS + 8) end
			end
			local S = F.samples
			local last = S[#S]
			if mx ~= last[2] or mz ~= last[4] then
				S[#S + 1] = {now, mx, my, mz}
				if #S > 16 then table.remove(S, 1) end
				F.steps = F.steps + 1
				if #F.log < 300 then F.log[#F.log + 1] = {now, mx, mz, F.orders} end
			end
			local tp = now - DELAY
			local i = #S
			while i > 1 and S[i][1] > tp do i = i - 1 end
			local tx, ty, tz = S[i][2], S[i][3], S[i][4]
			if S[i][1] <= tp and i < #S then
				local b = S[i + 1]
				local f = (tp - S[i][1]) / (b[1] - S[i][1])
				tx, ty, tz = tx + (b[2] - tx) * f, ty + (b[3] - ty) * f, tz + (b[4] - tz) * f
			end
			local a = 1 - math.exp(-K_POS * dt)
			F.sx, F.sy, F.sz = F.sx + (tx - F.sx) * a, F.sy + (ty - F.sy) * a, F.sz + (tz - F.sz) * a
			local front = W and mr.eq(mr.call(W.gfw, "pointer()"), F.hwnd)
			if W then
				if front then mouse_look() else F.dragging = false show_cursor(true) end
				-- the mode key: artillery hands over to the game's Manual fire mode; a unit that can shoot
				-- switches melee/ranged; attack works in that mode
				local l, r = pressed(KEYS.attack), pressed(KEYS.mode)
				local aiming = front and F.dragging
				if aiming and r and F.arty then enter_manual() return end
				if aiming and r then
					if can_shoot() then
						F.ranged = not F.ranged
						if F.firing then stop_fire() end
					else
						attack(false, true)
					end
				end
				if F.solo and F.ranged and aiming and down(KEYS.attack) and can_shoot() then
					man_shoot(now) -- held: he fires again each time he has reloaded
				elseif aiming and l then
					if F.ranged and can_shoot() then
						F.firing, F.fire_ammo = true, F.unit:ammo_left()
					elseif not F.arty then
						attack(true, F.running)
					end
				end
				-- a click commits to one shot: releasing early used to halt mid wind-up and nothing fired
				if F.firing then
					local held = aiming and down(KEYS.attack)
					local shot = F.unit:ammo_left() < F.fire_ammo
					local expired = F.fire_order_t and now - F.fire_order_t > FIRE_COMMIT
					if not can_shoot() or (not held and (shot or expired)) then stop_fire() else fire(now) end
				end
			end
			if F.sim and now < F.sim[3] and F.sim[4] then F.cyaw = F.cyaw + math.rad(F.sim[4]) * dt end
			if not F.firing then drive(now, px, py, pz, front) end -- firing holds position
			crosshair(F.ranged and F.dragging and true or false)
			local fx, fz = math.sin(F.cyaw), math.cos(F.cyaw)
			if F.ex then
				local p = cam:position()
				local d = math.sqrt((p:get_x() - F.ex) ^ 2 + (p:get_y() - F.ey) ^ 2 + (p:get_z() - F.ez) ^ 2)
				if d > 0.05 then F.fought = F.fought + 1 end
				if d > F.max_fight then F.max_fight = d end
			end
			local notches = F.wheel and wheel() or 0
			if front then
				local zin = down(KEYS.zoom_in) and 1 or 0
				local zout = down(KEYS.zoom_out) and 1 or 0
				if zin ~= zout or notches ~= 0 then
					F.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, F.zoom * math.exp((zout - zin) * ZOOM_RATE * dt - notches * ZOOM_NOTCH)))
					_G.DERPY_ZOOM[F.utype] = F.zoom
				end
			end
			local zm = F.zoom
			local back, lift = DIST * zm * math.cos(F.opitch), DIST * zm * math.sin(F.opitch)
			local ex, ey, ez = F.sx - fx * back, F.sy + HEIGHT * zm + lift, F.sz - fz * back
			local lx, ly, lz = F.sx + fx * AHEAD * zm, F.sy + LOOK_H * zm, F.sz + fz * AHEAD * zm
			-- ranged mode: over the right shoulder, and the mouse tilts the view instead of orbiting it
			F.ots = F.ots + ((F.ranged and 1 or 0) - F.ots) * math.min(1, OTS_RATE * dt)
			if F.ots > 0.001 then
				local rx, rz = fz * RIGHT_SIGN, -fx * RIGHT_SIGN
				local ox, oy, oz = F.sx + (rx * OTS_SIDE - fx * OTS_BACK) * zm, F.sy + OTS_HEIGHT * zm, F.sz + (rz * OTS_SIDE - fz * OTS_BACK) * zm
				local c, sn = math.cos(F.opitch), math.sin(F.opitch)
				local ax, ay, az = ox + fx * c * OTS_AHEAD, oy - sn * OTS_AHEAD, oz + fz * c * OTS_AHEAD
				local k = F.ots
				ex, ey, ez = ex + (ox - ex) * k, ey + (oy - ey) * k, ez + (oz - ez) * k
				lx, ly, lz = lx + (ax - lx) * k, ly + (ay - ly) * k, lz + (az - lz) * k
			end
			F.ex, F.ey, F.ez, F.lx, F.ly, F.lz = ex, ey, ez, lx, ly, lz
			cam:move_to(v(F.ex, F.ey, F.ez), v(F.lx, F.ly, F.lz), 0, false, -1, false)
			F.frames = F.frames + 1
		end)
		if not good then F.err = tostring(err) stop("error") end
	end

	local function start(unit) -- unit: the Manual fire hand-back and tests; F2 takes the selection or the general
		F.unit = unit or pick_unit()
		F.uc = create_unitcontroller(F.unit)
		F.unit_name = F.unit:name()
		_G.DERPY_ZOOM = _G.DERPY_ZOOM or {}
		F.utype = F.unit:type()
		F.zoom = _G.DERPY_ZOOM[F.utype] or (F.unit:is_infantry() and 1 or ZOOM_LARGE)
		F.arty = F.unit:is_artillery()
		F.ranged, F.firing = can_shoot() and not F.arty, false -- artillery fires on its own until handed to Manual fire
		F.model = not F.arty and pick_model() or nil -- a battery is followed whole, not one crewman
		F.man_hold, F.man_check = nil, nil
		F.solo = F.model and SOLO.types[F.utype] and true or nil -- he shoots alone: the rest hold fire until F2
		if F.solo then F.uc:fire_at_will(false) F.uc:release_control() end
		F.ots = F.ranged and 1 or 0
		local q = F.unit:position()
		F.sx, F.sy, F.sz = q:get_x(), q:get_y(), q:get_z()
		F.cyaw, F.opitch, F.t, F.ex = math.rad(F.unit:bearing()), 0, os.clock(), nil
		F.samples, F.log = {{F.t, F.sx, F.sy, F.sz}}, {}
		F.on, F.stopped, F.dragging, F.driving = true, nil, false, false
		if W then
			F.hwnd = mr.call(W.gfw, "pointer()")
			F.wheel = open_wheel(F.hwnd)
			if F.wheel then wheel() end -- drop what the wheel did while F2 was off
		end
		if BLOCK_PLAYER_ORDERS then bm:disable_orders(true) end
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", false)
		bm:repeat_real_callback(tick, 1, "derpy_follow")
	end

	-- artillery: the game's own Manual fire mode (Insert), its first-person gun view. Only units whose
	-- engine is in first_person_engines have it (here the cannon, the rockets and the sky junk; no
	-- missile infantry). Control stops, the unit is selected so the HUD carries its button, the button
	-- is clicked, and a watcher gives control back when the first-person UI closes (the game's own way
	-- out) or the mode key or F2 is pressed - those click the button again a beat later, only if the
	-- mode is still on, in case the game also leaves on that key.
	local function manual_button() return find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire") end
	local function manual_on() local fp = find_uicomponent(core:get_ui_root(), "first_person_ui") return fp and fp:Visible() end

	-- registered straight from the mode key, never from inside a one-shot real_callback: CA's timer
	-- manager frees a one-shot's id BEFORE running it, so a repeat registered there reuses that id and
	-- dies with the one-shot (measured: the watcher never ran)
	local function manual_watch()
		local good, err = pcall(function()
			local now, on = os.clock(), manual_on()
			if not F.fp_clicked then -- wait for the HUD to show the selected unit's button, then click it
				local b = manual_button()
				if b and b:Visible() then
					b:SimulateLClick()
					F.fp_clicked, F.fp_t = true, now
					return
				elseif now - F.fp_t < 2 then
					return
				end
				F.fp_err = "no Manual fire button for this unit"
			end
			if on then F.fp_seen = true end
			if on and W and pressed(KEYS.mode) and not F.fp_exit_at then F.fp_exit_at = now + 0.25 end
			local timed_out = not F.fp_seen and now - F.fp_t > 3
			local asked = F.fp_exit_at and now >= F.fp_exit_at
			if timed_out or asked or (F.fp_seen and not on) then
				bm:remove_real_callback("derpy_follow_fp")
				if on and asked then local b = manual_button() if b then b:SimulateLClick() end end
				local u = F.fp_unit
				F.fp_unit, F.fp_exit_at = nil, nil
				if timed_out and not F.fp_err then F.fp_err = "manual fire mode did not open" end
				start(u)
			end
		end)
		if not good then F.fp_err = tostring(err) bm:remove_real_callback("derpy_follow_fp") end
	end

	enter_manual = function()
		local u = F.unit
		stop("manual fire")
		u:select_in_ui()
		F.fp_unit, F.fp_seen, F.fp_clicked, F.fp_t, F.fp_exit_at, F.fp_err = u, false, false, os.clock(), nil, nil
		bm:repeat_real_callback(manual_watch, 100, "derpy_follow_fp")
	end

	F.start_fn, F.stop_fn, F.manual_fn = start, stop, enter_manual

	core:add_listener("derpy_follow_key", "ShortcutPressed",
		function(context) return context.string == "script_F2" end,
		function()
			if F.fp_unit then F.fp_exit_at = F.fp_exit_at or os.clock() + 0.25 return end
			if F.on then stop("key") else start() end
		end,
		true)
	start()
	return "controlling " .. F.unit_name .. "; F2 toggles"
end)
if ok then return res end
return "ERR " .. tostring(res)
