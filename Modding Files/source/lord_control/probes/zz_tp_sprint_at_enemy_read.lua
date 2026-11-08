-- zz_tp_sprint_at_enemy.lua's result: per unit and pass, each sample's time, distance to the enemy, speed since the last sample,
-- sprinting, charge order, his command
local T = _G.TP_CH
if not T then return "not run" end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") at " .. tostring(T.target) .. (T.err and (" ERR " .. T.err) or "")}
for _, r in ipairs(T.units) do
	out[#out + 1] = tostring(r.type) .. (r.skipped and (" SKIPPED " .. r.skipped) or "") .. (r.start_err and (" START ERR " .. r.start_err) or "")
	for _, pass in ipairs({"run", "sprint"}) do
		local line = "  " .. pass .. ":"
		local s = r[pass] or {}
		for i, p in ipairs(s) do
			local v = "-"
			if i > 1 then
				local q = s[i - 1]
				v = r1(math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) / math.max(p.t - q.t, 0.01))
			end
			line = line .. " [" .. r1(p.t) .. "s " .. r1(p.d) .. "m " .. v .. "m/s" .. (p.sp and " S" or "") .. (p.co and " CO" or "")
				.. " " .. tostring(p.cmd) .. (p.melee and " M" or "") .. (p.slot and (" c" .. p.slot) or "") .. (p.na and " NA" or "") .. "]"
		end
		out[#out + 1] = line
	end
end
return out
