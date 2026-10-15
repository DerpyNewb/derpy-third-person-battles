-- spike: can the game's cursor be hidden without cinematic UI (which hides CA's HUD too)?
-- Waits until the game window is in front, then for SECONDS of focused time:
-- ROUTE "setcursor": SetCursor(NULL) every frame. Nothing to undo: the game sets its own again.
-- ROUTE "showcursor": ShowCursor(FALSE) until the count is below 0, put back at the end.
-- Samples GetCursorInfo (flags 1 = showing; hCursor null = no picture) every 6th focused frame into
-- _G.DERPY_CURSOR. Gives up after LIMIT s of real time. IAT RVAs of build 0x6ac6d907, read off the exe on
-- disk; a probe may hard-code them, the pack may not.
-- PARK: hold the cursor at the window centre every frame first, as mouse-look does
local ROUTE, SECONDS, LIMIT, PARK = "setcursor", 10, 180, true
local IAT_HI = 0x3300000
local SETCURSOR, SHOWCURSOR, GETCURSORINFO = 0xa2bc0, 0xa2c10, 0xa2b20
local GETFOREGROUND, GETWINDOWPID, GETPID = 0xa2b70, 0xa2d88, 0xa29b8
local GETCLIENTRECT, CLIENTTOSCREEN, SETCURSORPOS = 0xa2bd8, 0xa2df8, 0xa2c20
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function iat(lo) return mr.read_pointer(mr.add(mr.add(mr.base, IAT_HI), lo)) end
	local set, show, info = iat(SETCURSOR), iat(SHOWCURSOR), iat(GETCURSORINFO)
	local fg, wpid, gpid = iat(GETFOREGROUND), iat(GETWINDOWPID), iat(GETPID)
	local gcr, c2s, scp = iat(GETCLIENTRECT), iat(CLIENTTOSCREEN), iat(SETCURSORPOS)
	local rect, pt = mr.alloc(16), mr.alloc(8)
	local ci, owner = mr.alloc(24), mr.alloc(8) -- CURSORINFO: cbSize, flags, hCursor at 8, ptScreenPos at 16
	local pid = mr.tonumber(mr.call(gpid, "int32()"))
	local win
	local function focused()
		local w = mr.call(fg, "pointer()")
		if mr.is_null(w) then return false end
		mr.call(wpid, "int32(pointer, pointer)", w, owner)
		win = w
		return mr.read_int32(owner, 0) == pid
	end
	local function park()
		mr.call(gcr, "int32(pointer, pointer)", win, rect)
		mr.write(pt, 0, mr.int32(math.floor(mr.read_int32(rect, 8) / 2)))
		mr.write(pt, 4, mr.int32(math.floor(mr.read_int32(rect, 12) / 2)))
		mr.call(c2s, "int32(pointer, pointer)", win, pt)
		mr.call(scp, "int32(int32, int32)", mr.read_int32(pt, 0), mr.read_int32(pt, 4))
	end
	local T = {route = ROUTE, park = PARK, flags = {}, null_cursor = {}, focused_s = 0, frames = 0}
	_G.DERPY_CURSOR = T
	local t0, last = os.clock(), os.clock()
	bm:remove_real_callback("derpy_cursor")
	bm:repeat_real_callback(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local function finish()
			bm:remove_real_callback("derpy_cursor")
			if ROUTE == "showcursor" and T.after_hide then
				local m = mr.tonumber(mr.call(show, "int32(int32)", 1))
				while m < 0 do m = mr.tonumber(mr.call(show, "int32(int32)", 1)) end
				T.after_show = m
			end
			T.done = true
		end
		if now - t0 > LIMIT then T.gave_up = true finish() return end
		if not focused() then return end
		T.focused_s = T.focused_s + dt
		T.frames = T.frames + 1
		if ROUTE == "showcursor" and not T.after_hide then
			local n = mr.tonumber(mr.call(show, "int32(int32)", 0))
			while n >= 0 do n = mr.tonumber(mr.call(show, "int32(int32)", 0)) end
			T.after_hide = n
		end
		if PARK then park() end
		if ROUTE == "setcursor" then mr.call(set, "pointer(pointer)", nil) end
		if T.frames % 6 == 0 and #T.flags < 100 then
			mr.write(ci, 0, mr.uint32(24))
			mr.call(info, "int32(pointer)", ci)
			T.flags[#T.flags + 1] = mr.read_int32(ci, 4)
			T.null_cursor[#T.null_cursor + 1] = mr.is_null(mr.read_pointer(ci, 8)) and 1 or 0
		end
		if T.focused_s > SECONDS then finish() end
	end, 1, "derpy_cursor")
	return {route = ROUTE, focused_now = focused()}
end)
if ok then return res end
return "ERR " .. tostring(res)
