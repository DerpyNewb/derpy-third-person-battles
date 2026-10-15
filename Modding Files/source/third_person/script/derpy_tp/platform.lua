-- The only file with an address, an offset or a memreader call (spec sections 4 and 8). The other
-- modules reach the game's memory through the table build() returns and never see a number. The 9.0
-- facts behind each group: docs/sessions/HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md - the
-- animation command 9e, the wheel 9f, one man's steering 9i, the cursor 9k.
local M = {}

-- known builds by the exe's PE TimeDateStamp as 8 hex digits: as a number it would round, since game Lua
-- numbers are float32 (0x6ac6d907 reads back as 0x6ac6d900). RVAs and offsets measured on that build; every
-- RVA here must be exact in float32, which tools/third_person_patterns.py checks.
local BUILDS = {
	["6ac6d907"] = {cmd_type = 0x3901cd0, battle = 0x4479ee0, cmd_push = 0x2e969ac, battle_sub = 0x468, gate_a = 0x3b0, gate_b = 0x3b1, queue = 0x644e8, walk_a = 0x3912b98, walk_b = 0x3add278, walk_start = 0x306a8fc, walk_speed = 0x3036640, walk_stop = 0x3069d7c},
}
-- an unknown build: play_anim_for_captain builds the command we forge (9.0: exe+2efc2f8, the only match).
-- It gives the command type (lea, disp at +3), the battle global (mov, disp at +0x23), the battle object,
-- gate and queue offsets (+0x2a, +0x31, +0x3a, +0x48) and the push call (rel32 at +0x4d).
-- tools/third_person_patterns.py checks it against the exe on disk.
local PATTERN = "48 8D 05 ?? ?? ?? ?? 48 89 44 24 30 48 89 74 24 38 66 44 89 74 24 40 44 88 7C 24 42 89 7C 24 44 "
	.. "48 8B 05 ?? ?? ?? ?? 48 8B 88 ?? ?? ?? ?? 40 38 B9 ?? ?? ?? ?? 75 ?? 40 38 B9 ?? ?? ?? ?? 75 ?? "
	.. "48 8D 54 24 30 48 8B 89 ?? ?? ?? ?? E8"

local MODELS_N, MODELS_DATA, MODEL_POS = 0xa4, 0xa8, 0x88 -- unit object: live model count and array; model: x, y, z
-- Persistent steering copies. The point at +0x368/+0x370 belongs to the polymorphic command at +0x330;
-- in a state-change command +0x368 is an integer animation state (2026-10-13 crash, exe+3082cb7).
local STEER = {{0x1e0, 0x1e8}, {0x194, 0x198}}
local WANT = {
	["USER32.DLL"] = {"GetAsyncKeyState", "GetCursorPos", "SetCursorPos", "GetForegroundWindow", "GetClientRect",
		"ClientToScreen", "GetWindowThreadProcessId"},
	["KERNEL32.DLL"] = {"GetCurrentProcessId"},
	["DINPUT8.DLL"] = {"DirectInput8Create"},
}

-- game Lua numbers are float32, exact only below 2^24, and so is what memreader passes: a larger one goes
-- in two parts, the high one a multiple of 0x10000 (at most 24 significant bits), the low one under 0x10000
function M.split(n)
	local lo = n % 0x10000
	return n - lo, lo
end

function M.build(mr)
	local P = {features = {input = false, anim = false, wheel = false, men = false}, problems = {}}
	local base = mr.base
	local function at(p, n) local hi, lo = M.split(n) return mr.add(mr.add(p, hi), lo) end
	local function problem(group, why) P.features[group] = false P.problems[#P.problems + 1] = group .. ": " .. why end
	local function sys(p) local s = mr.tostring(p) return s >= "00007FF000000000" and s < "0000800000000000" end

	-- a 32-bit field read as two exact 16-bit halves: read_int32 above 2^24 comes back rounded, and every
	-- RVA in Warhammer3.exe is above it. rva() turns the field straight into a pointer into the image.
	local function u16(p, off) return mr.read_uint16(p, off) end
	local function rva(p, off) return mr.add(mr.add(base, u16(p, off + 2) * 0x10000), u16(p, off)) end
	local function zero32(p, off) return u16(p, off) == 0 and u16(p, off + 2) == 0 end
	local pe = mr.read_int32(base, 0x3c)
	P.build = string.format("%04x%04x", u16(base, pe + 10), u16(base, pe + 8))

	-- imports, parsed from the loaded image so that no build has to store them
	local function upper(c) if c >= 97 and c <= 122 then return c - 32 end return c end
	local function cstr_is(p, s, fold)
		for i = 1, #s do
			local c = mr.read_uint8(p, i - 1)
			if fold then c = upper(c) end
			if c ~= s:byte(i) then return false end
		end
		return mr.read_uint8(p, #s) == 0
	end
	local fn = {}
	local desc = rva(base, pe + 0x90) -- PE32+ import directory: 20-byte descriptors, ended by a null one
	while not zero32(desc, 12) do
		local dll_name = rva(desc, 12)
		for dll, names in pairs(WANT) do
			if not zero32(desc, 0) and cstr_is(dll_name, dll, true) then
				local thunks, iat = rva(desc, 0), rva(desc, 16) -- names (OriginalFirstThunk), addresses (FirstThunk)
				local k = 0
				while not (zero32(thunks, k * 8) and zero32(thunks, k * 8 + 4)) do
					if u16(thunks, k * 8 + 6) < 0x8000 then -- bit 63 clear: imported by name, at hint/name + 2
						local hint = mr.add(rva(thunks, k * 8), 2)
						for _, name in ipairs(names) do
							if not fn[name] and cstr_is(hint, name) then fn[name] = mr.read_pointer(iat, k * 8) end
						end
					end
					k = k + 1
				end
			end
		end
		desc = mr.add(desc, 20)
	end

	-- input --------------------------------------------------------------------------------------------
	for _, name in ipairs({"GetAsyncKeyState", "GetCursorPos", "SetCursorPos", "GetForegroundWindow", "GetClientRect",
		"ClientToScreen", "GetWindowThreadProcessId", "GetCurrentProcessId"}) do
		if not fn[name] or not sys(fn[name]) then problem("input", name .. " not found in the import table") return P end
	end
	P.features.input = true
	local buf, rect, owner = mr.alloc(8), mr.alloc(16), mr.alloc(8)
	local pid = mr.tonumber(mr.call(fn.GetCurrentProcessId, "int32()"))
	-- focused: the foreground window belongs to this process, and it becomes the window looking parks in.
	-- Not a window captured at load: a battle loaded while the game was in the background would never focus.
	function P.focused()
		local w = mr.call(fn.GetForegroundWindow, "pointer()")
		if mr.is_null(w) then return false end
		mr.call(fn.GetWindowThreadProcessId, "int32(pointer, pointer)", w, owner)
		if mr.read_int32(owner, 0) ~= pid then return false end
		P.window = w
		return true
	end
	local function down(vk) return mr.tonumber(mr.call(fn.GetAsyncKeyState, "int16(int32)", vk)) < 0 end
	function P.held(vk)
		if vk == nil then return false end
		if type(vk) == "table" then for _, k in ipairs(vk) do if down(k) then return true end end return false end
		return down(vk)
	end
	local was = {}
	function P.pressed(vk) -- down now and up at this key's last call
		if vk == nil then return false end
		local key = type(vk) == "table" and vk[1] or vk
		local d = P.held(vk)
		local edge = d and not was[key]
		was[key] = d
		return edge
	end
	local cx, cy = 0, 0
	function P.look_begin() -- park the cursor at the window centre
		mr.call(fn.GetClientRect, "int32(pointer, pointer)", P.window, rect)
		mr.write(buf, 0, mr.int32(math.floor(mr.read_int32(rect, 8) / 2)))
		mr.write(buf, 4, mr.int32(math.floor(mr.read_int32(rect, 12) / 2)))
		mr.call(fn.ClientToScreen, "int32(pointer, pointer)", P.window, buf)
		cx, cy = mr.read_int32(buf, 0), mr.read_int32(buf, 4)
		mr.call(fn.SetCursorPos, "int32(int32, int32)", cx, cy)
	end
	function P.look_delta() -- pixels since the last park, then parked again
		mr.call(fn.GetCursorPos, "int32(pointer)", buf)
		local dx, dy = mr.read_int32(buf, 0) - cx, mr.read_int32(buf, 4) - cy
		if dx ~= 0 or dy ~= 0 then mr.call(fn.SetCursorPos, "int32(int32, int32)", cx, cy) end
		return dx, dy
	end

	-- the animation command ---------------------------------------------------------------------------
	local A
	local row = BUILDS[P.build]
	P.features.steer = row ~= nil and row.walk_a ~= nil and row.walk_b ~= nil and row.walk_start ~= nil and row.walk_speed ~= nil
		and row.walk_stop ~= nil
	local walk_a = P.features.steer and at(base, row.walk_a)
	local walk_b = P.features.steer and at(base, row.walk_b)
	local walk_start = P.features.steer and at(base, row.walk_start)
	local walk_speed = P.features.steer and at(base, row.walk_speed)
	local walk_stop = P.features.steer and at(base, row.walk_stop)
	local walk = P.features.steer and mr.alloc(0x60)
	if walk then
		for off = 0, 0x5c, 4 do mr.write(walk, off, mr.uint32(0)) end
		-- Native constructor 3249284: straight path, no borrowed path pointers, movement flags.
		mr.write(walk, 0x34, mr.uint32(3))
		for _, off in ipairs({0x44, 0x45, 0x4a}) do mr.write(walk, off, mr.uint8(1)) end
	end
	if row then
		A = {cmd_type = at(base, row.cmd_type), battle = at(base, row.battle), push = at(base, row.cmd_push),
			sub = row.battle_sub, gate_a = row.gate_a, gate_b = row.gate_b, queue = row.queue}
		P.source = "known build"
	end
	-- an unknown build searches at the first check, not here: a search that throws must cost the swing,
	-- never the load (main.lua turns a check that throws into a failed check)
	local function search()
		local hit, count = mr.find_pattern(PATTERN)
		if count ~= 1 then return end
		local function rip(o) -- a signed 32-bit displacement, in exact halves like rva()
			local hi = u16(hit, o + 2)
			if hi >= 0x8000 then hi = hi - 0x10000 end
			return mr.add(mr.add(mr.add(hit, o + 4), hi * 0x10000), u16(hit, o))
		end
		A = {cmd_type = rip(3), battle = rip(0x23), push = rip(0x4d), sub = mr.read_int32(hit, 0x2a),
			gate_a = mr.read_int32(hit, 0x31), gate_b = mr.read_int32(hit, 0x3a), queue = mr.read_int32(hit, 0x48)}
		P.source = "byte pattern"
	end
	local cmd = mr.alloc(32)
	local function battle_obj()
		local g = mr.read_pointer(A.battle, 0)
		if mr.is_null(g) then return nil end
		local b = mr.read_pointer(g, A.sub)
		if mr.is_null(b) then return nil end
		return b
	end
	function P.check_anim()
		if not A then search() end
		if not A then problem("anim", "unknown build " .. P.build .. " and the command pattern did not match once") return false, P.problems[#P.problems] end
		local b = battle_obj()
		if not b then problem("anim", "the battle object is not reachable") return false, P.problems[#P.problems] end
		local ga, gb = mr.read_uint8(b, A.gate_a), mr.read_uint8(b, A.gate_b)
		if ga > 1 or gb > 1 then problem("anim", "gate bytes read " .. ga .. " and " .. gb) return false, P.problems[#P.problems] end
		if mr.is_null(mr.read_pointer(b, A.queue)) then problem("anim", "the command queue is null") return false, P.problems[#P.problems] end
		P.features.anim = true
		return true
	end
	function P.play(m, slot, mask) -- mask 6 holds a full-body clip even when it has no event metadata
		if not P.features.anim then return false end
		local b = battle_obj()
		if not b or mr.read_uint8(b, A.gate_a) ~= 0 or mr.read_uint8(b, A.gate_b) ~= 0 then return false end
		mr.write(cmd, 0, A.cmd_type)
		mr.write(cmd, 8, m)
		mr.write(cmd, 0x10, mr.uint16(slot))
		mr.write(cmd, 0x12, mr.uint8(0))
		mr.write(cmd, 0x14, mr.uint32(mask or 0))
		mr.call(A.push, "uint8(pointer, pointer)", mr.read_pointer(b, A.queue), cmd)
		return true
	end

	-- the wheel: our own DirectInput 8 mouse, one per battle, kept in a global so a reload reuses it -----
	function P.open_wheel()
		local D = _G.DERPY_TP_DI
		if not (D and D.dev) then
			local create = fn.DirectInput8Create
			if not create or not sys(create) then problem("wheel", "DirectInput8Create not imported") return false, P.problems[#P.problems] end
			local m = mr.alloc(160)
			local function bytes(off, t) for i = 1, #t do mr.write(m, off + i - 1, mr.uint8(t[i])) end end
			bytes(0, {0x31, 0x80, 0x79, 0xBF, 0x3A, 0x48, 0xA2, 0x4D, 0xAA, 0x99, 0x5D, 0x64, 0xED, 0x36, 0x97, 0x00}) -- IID_IDirectInput8W
			bytes(16, {0x60, 0x2B, 0x1D, 0x6F, 0xA0, 0xD5, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_SysMouse
			bytes(32, {0xE2, 0x02, 0x6D, 0xA3, 0xF3, 0xC9, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_ZAxis
			mr.write(m, 64, mr.add(m, 32)) -- DIOBJECTDATAFORMAT: pguid, dwOfs 0, DIDFT_AXIS | DIDFT_ANYINSTANCE
			mr.write(m, 76, mr.uint32(0x00FFFF03))
			mr.write(m, 96, mr.uint32(32)) -- DIDATAFORMAT: size, object size 24, DIDF_RELAXIS, 4 bytes, 1 object
			mr.write(m, 100, mr.uint32(24))
			mr.write(m, 104, mr.uint32(2))
			mr.write(m, 108, mr.uint32(4))
			mr.write(m, 112, mr.uint32(1))
			mr.write(m, 120, mr.add(m, 64))
			local function method(obj, i) return mr.read_pointer(mr.read_pointer(obj, 0), i * 8) end
			if mr.tonumber(mr.call(create, "int32(pointer, uint32, pointer, pointer, pointer)", base, 0x800, m, mr.add(m, 48), nil)) ~= 0 then
				problem("wheel", "DirectInput8Create failed") return false, P.problems[#P.problems]
			end
			local di = mr.read_pointer(m, 48)
			if mr.tonumber(mr.call(method(di, 3), "int32(pointer, pointer, pointer, pointer)", di, mr.add(m, 16), mr.add(m, 56), nil)) ~= 0 then
				problem("wheel", "CreateDevice failed") return false, P.problems[#P.problems]
			end
			local dev = mr.read_pointer(m, 56)
			if mr.tonumber(mr.call(method(dev, 11), "int32(pointer, pointer)", dev, mr.add(m, 96))) ~= 0 then
				problem("wheel", "SetDataFormat failed") return false, P.problems[#P.problems]
			end
			mr.call(method(dev, 13), "int32(pointer, pointer, uint32)", dev, P.window, 0xA) -- NONEXCLUSIVE | BACKGROUND
			mr.call(method(dev, 7), "int32(pointer)", dev)
			D = {dev = dev, acquire = method(dev, 7), state = method(dev, 9), buf = mr.add(m, 128)}
			_G.DERPY_TP_DI = D
		end
		function P.wheel() -- notches since the last call; re-acquires a lost device
			if mr.tonumber(mr.call(D.state, "int32(pointer, uint32, pointer)", D.dev, 4, D.buf)) ~= 0 then
				mr.call(D.acquire, "int32(pointer)", D.dev)
				return 0
			end
			return mr.read_int32(D.buf, 0) / 120
		end
		P.features.wheel = true
		return true
	end

	-- a unit's men -------------------------------------------------------------------------------------
	local function obj_of(unit) return mr.read_pointer(mr.ud_topointer(unit), 8) end
	function P.models(unit)
		local obj = obj_of(unit)
		local n, data = mr.read_int32(obj, MODELS_N), mr.read_pointer(obj, MODELS_DATA)
		local t = {}
		for k = 0, n - 1 do t[k + 1] = mr.read_pointer(data, k * 8) end
		return t
	end
	function P.model_pos(m) return mr.read_float(m, MODEL_POS), mr.read_float(m, MODEL_POS + 4), mr.read_float(m, MODEL_POS + 8) end
	function P.has_slot(m, slot) -- engine lookup exe+1482074; checks the model's active fragment, including mods
		if not P.features.steer then return false end
		local anim = mr.read_pointer(m, 0x308)
		return not mr.is_null(anim) and mr.read_uint16(anim, 0x50 + slot * 2) ~= 0xffff
	end
	function P.reload_slot(m)
		if P.has_slot(m, 1564) then return 1564 end
		if P.has_slot(m, 1554) then return 1554 end
	end
	function P.mount(m)
		if not P.has_slot(m, 1901) then return nil end
		local parent = mr.read_pointer(m, 0x2e0) -- rider parent, also followed by native exe+305468c
		if not mr.is_null(parent) then return parent end
	end
	function P.anim_slot(m) -- native wait command exe+325c7ec checks metadata and the body mask
		if mr.is_null(mr.read_pointer(m, 0x898)) and mr.read_int32(m, 0x284) == 0 then return nil end
		return mr.read_uint16(m, 0x278)
	end
	function P.face(m, yaw)
		if not P.features.steer or not yaw then return nil end
		local angle = math.floor((yaw % (2 * math.pi)) * 0x10000 / (2 * math.pi))
		mr.write(m, 0xb0, mr.uint16(angle))
		return angle
	end
	function P.place(m, x, z) mr.write(m, MODEL_POS, x) mr.write(m, MODEL_POS + 8, z) end
	function P.steer(m, x, z, run, yaw)
		for _, f in ipairs(STEER) do mr.write(m, f[1], x) mr.write(m, f[2], z) end
		if not P.features.steer then return end
		local angle = P.face(m, yaw)
		local command = mr.read_pointer(m, 0x330)
		local unit = mr.read_pointer(m, 0x2e8)
		local speed = not mr.is_null(unit) and mr.call(walk_speed, "float(pointer, uint8)", unit, run and 1 or 0)
		if mr.eq(command, walk_b) then
			local moved = mr.read_float(m, 0x368) ~= x or mr.read_float(m, 0x370) ~= z
			mr.write(m, 0x368, x)
			mr.write(m, 0x370, z)
			if speed then mr.write(m, 0x390, mr.uint32(run and 1 or 0)) mr.write(m, 0x394, speed) end
			local gait = run and 1 or 0
			local changed = moved or mr.read_uint8(m, 0x3ae) ~= gait or (angle and mr.read_uint16(m, 0x398) ~= angle)
			mr.write(m, 0x3ae, mr.uint8(gait))
			if angle then mr.write(m, 0x398, mr.uint16(angle)) end
			if changed then mr.write(m, 0x3c0, mr.uint8(0)) end
		elseif speed then
			local mx, my, mz = P.model_pos(m)
			if (x - mx) ^ 2 + (z - mz) ^ 2 <= 0.01 then return end
			mr.write(walk, 0, x) mr.write(walk, 4, my) mr.write(walk, 8, z)
			mr.write(walk, 0x28, mr.uint32(run and 1 or 0)) mr.write(walk, 0x2c, speed)
			mr.write(walk, 0x30, mr.uint16(angle or math.floor((math.atan2(x - mx, z - mz) % (2 * math.pi)) * 0x10000 / (2 * math.pi))))
			mr.write(walk, 0x46, mr.uint8(run and 1 or 0))
			mr.write(walk, 0x4c, bm:time_elapsed_ms() / 1000)
			-- Let the engine destroy the old command and construct a walking command; never forge its vtable.
			mr.call(walk_start, "pointer(pointer, pointer)", m, walk)
		end
	end
	-- Holding still. Measured 2026-10-14 (probes/tp_cmd_trace.py): a walk that has reached its point, or was
	-- refreshed toward his own feet, keeps him moving until its command is replaced, and while F2 held him
	-- nothing replaced it. The engine's own stop, exe+3069d7c, swaps a running walk for "stand in his state"
	-- (390cba8, what uc:halt leaves on each man); any other command is the engine's to finish.
	function P.hold(m, x, z, yaw)
		for _, f in ipairs(STEER) do mr.write(m, f[1], x) mr.write(m, f[2], z) end
		if not P.features.steer then return end
		local command = mr.read_pointer(m, 0x330)
		if mr.eq(command, walk_a) or mr.eq(command, walk_b) then mr.call(walk_stop, "pointer(pointer)", m) end
		P.face(m, yaw)
	end
	function P.same(a, b) return mr.eq(a, b) end
	function P.alive(unit, m)
		for _, x in ipairs(P.models(unit)) do if mr.eq(x, m) then return true end end
		return false
	end
	-- the live check (spec section 8), run at every start: the count matches the men alive, every model's
	-- type marker lies in the exe's image, the models centre within 5 m of the unit, and
	-- the steering copies lie near their man or were never set. Measured 2026-10-13: a lord on a Longma is
	-- another model class than infantry (exe+3ac4908, not +390d4f8); a man never ordered holds 0, 0.
	local image_end = rva(base, pe + 0x50) -- SizeOfImage
	function P.check_men(unit)
		local obj = obj_of(unit)
		local n = mr.read_int32(obj, MODELS_N)
		if n < 1 or n ~= unit:number_of_men_alive() then return false, "model count " .. n .. " against " .. unit:number_of_men_alive() .. " men" end
		local ms = P.models(unit)
		local lo, hi = mr.tostring(base), mr.tostring(image_end)
		local sx, sz = 0, 0
		for _, m in ipairs(ms) do
			-- one unit may hold two classes (measured 2026-10-14: an Ironbreaker regiment's two officers are
			-- exe+3ac5c40 beside its infantry's +390d4f8, with the same fields); each must still be one of the exe's
			local s = mr.tostring(mr.read_pointer(m, 0))
			if s < lo or s >= hi then return false, "a model type is not in the game's exe" end
			local x, _, z = P.model_pos(m)
			sx, sz = sx + x, sz + z
			for _, f in ipairs(STEER) do
				local tx, tz = mr.read_float(m, f[1]), mr.read_float(m, f[2])
				if (tx ~= 0 or tz ~= 0) and (tx ~= tx or tz ~= tz or (tx - x) ^ 2 + (tz - z) ^ 2 > 90000) then return false, "a steering copy is not near its man" end
			end
		end
		local q = unit:position()
		local dx, dz = sx / n - q:get_x(), sz / n - q:get_z()
		if dx * dx + dz * dz > 25 then return false, "the models centre " .. math.floor(math.sqrt(dx * dx + dz * dz)) .. " m from the unit" end
		P.features.men = true
		return true
	end

	return P
end

return M
