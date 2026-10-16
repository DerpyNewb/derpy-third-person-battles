-- Read zz_tp_melee_spam.lua's result. No string library calls.
local T = _G.TP_MS
if not T then return "not run" end
local sends = {}
for _, s in ipairs(T.sends) do
	sends[#sends + 1] = {t = s.t, slot = s.slot, ok = s.ok, clip = s.clip, cmd = s.cmd, armed_before = s.armed_before,
		armed_after = s.armed_after, started_ms = s.started_at, failed = s.failed, waits = s.waits,
		armed_frames = s.armed_frames, disarmed_frames = s.disarmed_frames, cut = s.cut, mask6 = s.mask6, any_ms = s.any_at, any_slot = s.any_slot,
		acts = s.acts, tl = s.tl}
end
return {done = T.done, err = T.err, type = T.type, nodisarm = T.nodisarm, mode = T.mode, cuts = T.cuts, presses = T.presses, frames = T.frames,
	swing_frames = T.swing_frames, unpatched = T.unpatched, other_frames = T.other_frames, others = T.others, clips = T.clips, cmds = T.cmds, sends = sends, log = T.log}
