-- Where things stand before a probe: third person on, one man, his unit, the battle clock moving. No string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP: not in a battle, or the pack is not loaded" end
local F = E.F
local out = "on " .. tostring(F.on) .. " model " .. tostring(F.model ~= nil) .. " utype " .. tostring(F.utype)
	.. " ranged " .. tostring(F.ranged) .. " can_charge " .. tostring(F.can_charge) .. " ms " .. tostring(bm:time_elapsed_ms())
	.. " raises " .. tostring(E.D and E.D.raises ~= nil)
if F.model then out = out .. " has484 " .. tostring(E.P.has_slot(F.model, 484)) .. " clip " .. tostring(E.P.anim_slot(F.model)) end
return out
