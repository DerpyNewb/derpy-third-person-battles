-- Test scaffolding (2026-10-16), never the pack: every enemy unit taken off its AI and halted, so a capture is not
-- overrun. _G.TP_FROZEN keeps the controllers (release_control() to give them back). No string library calls.
local out, n = {}, 0
local armies = bm:get_non_player_alliance():armies()
_G.TP_FROZEN = {}
for a = 1, armies:count() do
	local army = armies:item(a)
	local uc = army:create_unit_controller()
	local l = army:units()
	for i = 1, l:count() do uc:add_units(l:item(i)) n = n + 1 end
	uc:take_control()
	uc:halt()
	_G.TP_FROZEN[#_G.TP_FROZEN + 1] = uc
end
return "halted " .. n .. " enemy units"
