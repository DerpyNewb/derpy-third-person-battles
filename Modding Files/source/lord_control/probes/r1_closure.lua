-- RE step 1: what is a battle_unit method? tostring gives the closure address; upvalues (if any)
-- may hold the real member function. Compared across three methods.
local ok, res = pcall(function()
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then u = units:item(i) end
	end
	local r = {mt = tostring(getmetatable(u)), has_debug = type(debug)}
	for _, name in ipairs({"play_anim_for_captain", "bearing", "position"}) do
		local f = u[name]
		local e = {fn = tostring(f), kind = type(f)}
		if debug and debug.getupvalue then
			for k = 1, 4 do
				local n, val = debug.getupvalue(f, k)
				if n == nil then break end
				e["up" .. k] = tostring(val)
			end
		end
		r[name] = e
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
