-- Test scaffolding (2026-10-18, the author: "switching to range is also inconsistent"; measured that night: 3 of 8 real
-- right clicks did nothing in third person on a gun). Wraps P.pressed for the mode key: every call while the key is
-- down records the result, focus, F.dragging and F.on; and C.mode, each call. "read" returns them, "off" restores.
-- No string library calls.
local ok, res = pcall(function()
	local T = _G.DERPY_TP
	local mode = _G.TP_TM_MODE or "on"
	if mode == "read" then
		local s = ""
		for _, l in ipairs(_G.TP_TM or {}) do s = s .. l .. " || " end
		return s
	end
	if mode == "off" then
		if _G.TP_TM_PRESSED then T.P.pressed, T.combat.mode = _G.TP_TM_PRESSED, _G.TP_TM_CMODE end
		_G.TP_TM_PRESSED, _G.TP_TM_CMODE = nil, nil
		return "off"
	end
	_G.TP_TM = {}
	if not _G.TP_TM_PRESSED then
		local pressed, cmode = T.P.pressed, T.combat.mode
		_G.TP_TM_PRESSED, _G.TP_TM_CMODE = pressed, cmode
		local t0 = bm:time_elapsed_ms()
		local downs = 0
		T.P.pressed = function(vk)
			local r = pressed(vk)
			local key = T.S and T.S.keys and T.S.keys.mode
			if vk == key and T.P.held(vk) then
				downs = downs + 1
				if #_G.TP_TM < 60 and (r or downs % 5 == 1) then
					_G.TP_TM[#_G.TP_TM + 1] = os.clock() .. " down, pressed " .. tostring(r) .. " focused " .. tostring(T.P.focused())
						.. " dragging " .. tostring(T.F.dragging) .. " on " .. tostring(T.F.on)
				end
			end
			return r
		end
		T.combat.mode = function(now)
			_G.TP_TM[#_G.TP_TM + 1] = os.clock() .. " C.mode"
			return cmode(now)
		end
	end
	return "tracing the mode key"
end)
return ok and res or "ERR " .. tostring(res)
