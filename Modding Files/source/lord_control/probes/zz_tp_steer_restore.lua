-- puts back the E.P.steer that zz_tp_heading_toggle.lua wrapped
local E = _G.DERPY_TP
if not (E and E.P) then return "ERR load the bridge first" end
if not _G.TP_STEER_ORIG then return "nothing to restore" end
E.P.steer, _G.TP_STEER_ORIG = _G.TP_STEER_ORIG, nil
return "restored"
