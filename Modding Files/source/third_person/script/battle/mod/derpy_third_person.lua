-- Third-Person Battles. The only auto-loaded file: it loads the modules in script/derpy_tp/ itself, in
-- order, so nothing relies on the load order of script/battle/mod/. Design:
-- docs/superpowers/specs/2026-10-13-third-person-pack-design.md
local function load(name)
	local chunk, err = loadfile("/script/derpy_tp/" .. name)
	if not chunk then error("cannot load " .. name .. ": " .. tostring(err)) end
	setfenv(chunk, core:get_env())
	return chunk()
end

local ok, err = pcall(function()
	local old = _G.DERPY_TP
	if old and old.main then pcall(old.main.stop, "reloaded") end
	bm:remove_real_callback("derpy_tp")
	local E = {F = {on = false}, load = load, zoom_by_type = {}, strikes = 0, logged = {}}
	_G.DERPY_TP = E
	function E.log(msg) if E.S and E.S.debug then out("derpy_tp: " .. msg) end end
	function E.once(tag, msg) if not E.logged[tag] then E.logged[tag] = true out("derpy_tp: " .. msg) end end
	function E.say(key)
		bm:show_subtitle(key, true, true)
		bm:remove_real_callback("derpy_tp_say")
		bm:real_callback(function() bm:hide_subtitles() end, 6000, "derpy_tp_say")
	end
	-- at load the loading screen is up and would hide a message: say it once the battle shows
	local function when_shown(fn)
		local done = false
		local function once() if not done then done = true fn() end end
		bm:register_phase_change_callback("Deployment", once)
		bm:register_phase_change_callback("Deployed", once)
	end
	E.K = load("keys")
	E.settings = load("settings") -- read again at every toggle, but loaded only here
	E.S = E.settings(get_mct and get_mct(), E.K)
	local mr = _G.memreader_plus
	if not mr then
		when_shown(function() E.say("derpy_tp_needs_memreader") end)
		E.once("memreader", "memreader Plus is not loaded; nothing runs")
		return
	end
	E.P = load("platform").build(mr)
	if not E.P.features.input then
		when_shown(function() E.say("derpy_tp_needs_memreader") end)
		E.once("input", "no keyboard or mouse: " .. table.concat(E.P.problems, "; "))
		return
	end
	if bm:is_multiplayer() or bm:is_replay() then -- memory writes and scripted shots would desync
		bm:repeat_real_callback(function()
			if E.P.focused() and E.P.pressed(E.S.keys.toggle) then E.say("derpy_tp_multiplayer") end
		end, 1, "derpy_tp")
		return
	end
	E.D = load("data")
	E.rig = load("rig")(E)
	E.move = load("move")(E)
	E.combat = load("combat")(E)
	E.abilities = load("abilities")(E)
	E.hud = load("hud")(E)
	E.main = load("main")(E)
end)
if not ok then out("derpy_tp: failed to load: " .. tostring(err)) end
