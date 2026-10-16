-- Reads back zz_tp_speed_diff.lua: the m/s each phase ran, and the model's floats that moved with the scale (phase 2
-- over phase 1 within 1.1-1.3, or phase 3 over phase 1 within 0.5-0.7). No string library calls.
local T = _G.TP_SPEED_DIFF
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " m/s " .. tostring(T.dist[1]) .. " "
	.. tostring(T.dist[2]) .. " " .. tostring(T.dist[3])
for i = 4, 6 do out = out .. " " .. tostring(T.dist[i]) end
for i, sn in ipairs(T.snap) do
	out = out .. " | phase " .. i .. ": asked " .. math.floor(sn[0x180] * 100) / 100 .. ", moving " .. math.floor(sn[0x1a0] * 100) / 100
		.. ", +1b8 " .. math.floor(sn[0x1b8] * 100) / 100 .. ", +238 " .. math.floor(sn[0x238] * 100) / 100
end
local a, b, c = T.snap[1], T.snap[3], T.snap[5]
if not (a and b and c) then return out .. " (snapshots missing)" end
local function r(x, y) return math.floor(x / y * 1000) / 1000 end
for o = 0, 0xb40, 4 do
	local v1, v2, v3 = a[o], b[o], c[o]
	if v1 and v2 and v3 and v1 > 0.5 and v1 < 50 then
		local k2, k3 = v2 / v1, v3 / v1
		if (k2 > 1.1 and k2 < 1.3) or (k3 > 0.5 and k3 < 0.7) then
			out = out .. " | +" .. o .. ": " .. math.floor(v1 * 1000) / 1000 .. " " .. r(v2, v1) .. "x " .. r(v3, v1) .. "x"
		end
	end
end
return out
