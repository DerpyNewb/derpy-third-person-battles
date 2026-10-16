-- The idle frame in a shot (the author, 2026-10-16: "animation when shooting still reverts to idle for 1 frame, then
-- shooting animation"). The pack plays one man of _G.TP_SF_TYPE (default the Hochland Long Rifles RoR); one click, then
-- every frame for 5 s: his clip, and each clip the pack sends, with model ms. Counts the frames with no clip between the
-- raise's first frame and the fire's. Test scaffolding, not shipped. Read with zz_tp_shot_frames_read.lua. No string
-- library calls.
local ok, result = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and mr) then return "load the pack in a battle first" end
	if _G.TP_SF and not _G.TP_SF.done then return "already running" end
	local P, F = E.P, E.F
	local function ms() return bm:time_elapsed_ms() end
	local want = _G.TP_SF_TYPE or "wh3_dlc25_emp_inf_hochland_long_rifles_ror"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x break end
	end
	if not u then return "no " .. want end
	if F.on then E.main.stop("shot frames test") end
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play"}) do saved[k] = P[k] end
	local attack = E.S.keys.attack
	local id = type(attack) == "table" and attack[1] or attack
	local function ours(k) return (type(k) == "table" and k[1] or k) == id end
	local down, was = false, false
	P.held = function(k) return down and ours(k) end
	P.pressed = function(k)
		if not ours(k) then return false end
		local e = down and not was
		was = down
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local T = {done = false, type = want, seq = {}, sent = {}, frames = 0, gap_frames = 0}
	_G.TP_SF = T
	P.play = function(m, slot, mask)
		if #T.sent < 20 then T.sent[#T.sent + 1] = ms() .. " send " .. slot .. " mask " .. tostring(mask) end
		return saved.play(m, slot, mask)
	end
	local function finish()
		down = false
		if F.on then pcall(E.main.stop, "shot frames test") end
		for k, f in pairs(saved) do P[k] = f end
		T.done = true
		bm:remove_real_callback("tp_shot_frames")
	end
	E.main.start(u)
	if not F.on or not F.model or not F.solo then finish() T.err = "not shooting alone" return T.err end
	if not F.ranged then T.err = "not in ranged mode" end
	local began, last = ms(), "start"
	local raised, fired = false, false
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = ms()
			if t - began > 6000 then finish() return end
			down = t - began >= 1000 and t - began < 1100
			local m = F.model
			if not m then return end
			local cl = tostring(P.anim_slot(m))
			if cl ~= last then
				if #T.seq < 40 then T.seq[#T.seq + 1] = t .. " " .. cl end
				last = cl
			end
			if F.shot and F.shot.aim_slot and cl == tostring(F.shot.aim_slot) then raised = true end
			if F.shot and F.shot.fire_slot and cl == tostring(F.shot.fire_slot) then fired = true end
			if raised and not fired then
				T.frames = T.frames + 1
				if cl == "nil" then T.gap_frames = T.gap_frames + 1 end
			end
		end)
		if not worked then T.err = tostring(err) pcall(finish) end
	end, 1, "tp_shot_frames")
	return "shot frames on " .. want
end)
return ok and result or "ERR " .. tostring(result)
