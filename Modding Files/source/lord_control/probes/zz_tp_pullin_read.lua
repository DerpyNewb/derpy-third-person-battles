-- Reads the recorder's camera events (zz_tp_recorder.lua's rig.update wrapper, REC.pull). No string library calls.
local REC = _G.TP_REC
if not REC then return "not recording" end
local out = "samples " .. REC.n .. " lifts " .. tostring(REC.lifts) .. " head-cams " .. tostring(REC.heads) .. " err "
	.. tostring(REC.err)
for i = 1, math.min(#(REC.pull or {}), 80) do out = out .. " || " .. REC.pull[i] end
return out
