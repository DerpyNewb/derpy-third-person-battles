-- undo the target tests: player units fire at will again and are released; the target goes back to its AI
local ok, res = pcall(function()
	local S = _G.DERPY_TGT
	bm:remove_real_callback("derpy_tgt_watch")
	bm:remove_real_callback("derpy_gate")
	for _, uc in ipairs(S.ucs) do uc:fire_at_will(true) uc:release_control() end
	if S.ucs2 then S.ucs2:fire_at_will(true) S.ucs2:release_control() end
	S.uce:morale_behavior_default()
	S.uce:release_control()
	return {released = #S.ucs, target_men = S.enemy:number_of_men_alive()}
end)
if ok then return res end
return "ERR " .. tostring(res)
