-- Fly-swing probe, 2026-10-18 (the author: "flying units when using melee uses ground melee attacks e.g belakor"). On a
-- timer: third person on for Be'lakor; in the air, a left click's swing (E.combat.attack, as the frame calls it), a right
-- click's (E.combat.mode) and the jump key's; then Toggle flying lands him and the same again. Every 100 ms it logs his
-- clip when it changes and whether he flies. Expected: 494-497 in the air and no jump, 454-458 and 489-493 landed.
-- NO string.* calls. Read back with zz_tp_fly_swing_read.lua.
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local TYPE = _G.TP_FS_TYPE or "wh3_main_dae_cha_be_lakor_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == TYPE then u = units:item(i) end end
if not u then return "no " .. TYPE end
local T = {n = 0, log = {}, clips = {}}
_G.TP_FS = T
local function note(s) T.log[#T.log + 1] = s end
local function gnow() return bm:time_elapsed_ms() / 1000 end
local function land()
	local b = find_uicomponent(core:get_ui_root(), "button_toggle_flying")
	if b then b:SimulateLClick() note("toggle flying clicked") else note("no toggle button") end
end
local last_clip, last_fly
local gap = math.ceil((E.S.swing_cooldown + 0.3) * 10) -- ticks of 100 ms past the swing gap
local plan = {
	[5] = function() note("click") E.combat.attack(gnow(), true, false) end,
	[5 + gap] = function() note("right click") E.combat.mode(gnow()) end,
	[5 + 2 * gap] = function() note("jump") E.combat.jump(gnow()) end,
	[5 + 3 * gap] = land,
	[5 + 3 * gap + 60] = function() note("click") E.combat.attack(gnow(), true, false) end,
	[5 + 4 * gap + 60] = function() note("right click") E.combat.mode(gnow()) end,
	[5 + 5 * gap + 60] = function() note("jump") E.combat.jump(gnow()) end,
}
local END = 5 + 6 * gap + 60
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("third person " .. tostring(E.F.on) .. " cooldown " .. tostring(E.S.swing_cooldown))
		end
		local m = E.P.models(u)[1]
		local mount = m and E.P.mount(m)
		local clip = m and (E.P.anim_slot(mount or m))
		local fly = u:is_currently_flying()
		if clip ~= last_clip or fly ~= last_fly then
			note("t=" .. T.n .. " clip " .. tostring(clip) .. " flying " .. tostring(fly))
			last_clip, last_fly = clip, fly
		end
		if plan[T.n] then plan[T.n]() end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= END or not ok then
		bm:remove_real_callback("tp_fs")
		T.ended = true
		pcall(E.main.stop, "fly swing probe")
	end
end, 100, "tp_fs")
return "started, " .. END .. " ticks"
