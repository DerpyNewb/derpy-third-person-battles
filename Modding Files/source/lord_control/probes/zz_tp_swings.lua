-- Test scaffolding (2026-10-17, the author: "attacks are triggering twice when in battle and in groups of enemies").
-- Third person on one man of _G.TP_SW_TYPE (put into a melee by zz_tp_engage.lua first), through the shipped frame loop
-- with synthetic keys, facing the nearest enemy: 6 s with no click (the engine's own swings, which should be none), then
-- _G.TP_SW_CLICKS (default 8) clicks _G.TP_SW_GAP s apart (default 2.4). Every frame: each attack clip that STARTS on his
-- body (his clip changing to an attack slot: 454-463, 484-500, 1901-1950), and each clip the pack sends (P.play). Per
-- click: how many attack clips started before the next. Read with zz_tp_swings_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_SW and not _G.TP_SW.done then return "already running" end
	local P, F = E.P, E.F
	local want = _G.TP_SW_TYPE or "wh3_dlc26_chs_inf_chosen_mkho_ror"
	local CLICKS, GAP = _G.TP_SW_CLICKS or 8, _G.TP_SW_GAP or 2.4
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play"}) do saved[k] = P[k] end
	local keys, edges = {}, {}
	local T = {done = false, starts = {}, sent = {}, clicks = {}, quiet = 0, log = ""}
	_G.TP_SW = T
	function P.held(k)
		if type(k) == "table" then for _, x in ipairs(k) do if keys[x] then return true end end return false end
		return keys[k] == true
	end
	function P.pressed(k)
		local i = type(k) == "table" and k[1] or k
		if not i then return false end
		local d = P.held(k)
		local e = d and not edges[i]
		edges[i] = d
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local t0 = now()
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	P.play = function(m, slot, mask)
		T.sent[#T.sent + 1] = {r1(now() - t0), slot}
		return saved.play(m, slot, mask)
	end
	local function set(action, down)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = down or nil
	end
	local function attack(s) return s and (s >= 454 and s <= 463 or s >= 484 and s <= 500 or s >= 1901 and s <= 1950) end
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and x:type() == want and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then return "no " .. want end
	if F.on then pcall(E.main.stop, "swings test") end
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "swings test") end
		for k, f in pairs(saved) do P[k] = f end
		pcall(function() bm:remove_real_callback("tp_swings") end)
	end
	local function face()
		local q, best, bd = u:position(), nil, nil
		local all = bm:get_non_player_alliance():armies()
		for a = 1, all:count() do
			local l = all:item(a):units()
			for i = 1, l:count() do
				local e = l:item(i)
				if e:number_of_men_alive() > 0 then
					local p = e:position()
					local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
					if not bd or d < bd then best, bd = p, d end
				end
			end
		end
		if best then local y = math.atan2(best:get_x() - q:get_x(), best:get_z() - q:get_z()) E.rig.yaw, E.rig.want_yaw = y, y end
	end
	bm:clear_selection()
	u:select_in_ui()
	local step, last, n, t_click = "toggle_on", nil, 0, nil
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			-- started directly: F2 after the first unit kept picking the first (seen 2026-10-17)
			if step == "toggle_on" and t >= 0.2 then pcall(E.main.start, u) step = "check_on"
			elseif step == "check_on" and t >= 1 then
				if not (F.on and (F.model or F.single)) then finish("did not go on one man or a unit of one") return end
				T.horse = P.mount(F.model or F.single) ~= nil
				face()
				step, T.t_quiet = "quiet", t
			end
			local man = F.model or F.single -- one man, or a unit of one (2026-10-18)
			if F.on and man then
				local b = P.mount(man) or man
				local s = P.anim_slot(b)
				local r = P.mount(man) and P.anim_slot(man)
				if s ~= last then
					if attack(s) then
						T.starts[#T.starts + 1] = {r1(t), s, n}
						if step == "quiet" then T.quiet = T.quiet + 1 end
					end
					last = s
				end
				if r and attack(r) and r ~= T.rlast then T.starts[#T.starts + 1] = {r1(t), r, n, "rider"} end
				T.rlast = r
				T.in_melee = F.unit:is_in_melee()
			end
			if step == "quiet" and t >= T.t_quiet + 6 then step, t_click = "clicks", t end
			if step == "clicks" then
				if n < CLICKS and t >= t_click then
					face()
					set("attack", true)
					n = n + 1
					T.clicks[n] = r1(t)
					t_click = t + GAP
					step = "up"
				elseif n >= CLICKS and t >= t_click then
					finish("time")
				end
			elseif step == "up" and t >= T.clicks[n] + 0.05 then
				set("attack", false)
				step = "clicks"
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_swings")
	return "running on " .. want
end)
return ok and res or "ERR " .. tostring(res)
