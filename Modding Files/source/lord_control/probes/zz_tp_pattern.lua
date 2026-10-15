-- Task 13: does the byte-pattern route find the animation command on this build? Builds a second platform
-- from the sent source with the build key renamed, so it must search, and runs its check. The running mod's
-- own platform is not touched. Needs the zz_tp_load parts sent first.
local ok, res = pcall(function()
	local src = assert(_G.DERPY_TP_SRC and _G.DERPY_TP_SRC["/script/derpy_tp/platform"], "send the parts first")
	local n
	src, n = src:gsub('%["6ac6d907"%]', '["00000000"]')
	assert(n == 1, "build key not found once: " .. n)
	local f = assert(loadstring(src, "platform_unknown_build"))
	setfenv(f, core:get_env())
	local P = f().build(_G.memreader_plus)
	local t0 = os.clock()
	local good, why = P.check_anim()
	return {source = P.source, anim = good, why = why, search_s = os.clock() - t0, build = P.build}
end)
if ok then return res end
return "ERR " .. tostring(res)
