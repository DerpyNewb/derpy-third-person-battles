-- Read-only: the parts of the one-man check the class mismatch used to cut short - the models' centre against the
-- unit's position, and the farthest steering copy from its man. NO string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local P, mr = E.P, _G.memreader_plus
local out = {}
local units = bm:get_player_alliance():armies():item(1):units()
for i = 1, units:count() do
	local u = units:item(i)
	local ok, err = pcall(function()
		local ms = P.models(u)
		local sx, sz, worst = 0, 0, 0
		for _, m in ipairs(ms) do
			local x, _, z = P.model_pos(m)
			sx, sz = sx + x, sz + z
			for _, f in ipairs({{0x1e0, 0x1e8}, {0x194, 0x198}}) do
				local tx, tz = mr.read_float(m, f[1]), mr.read_float(m, f[2])
				if tx ~= 0 or tz ~= 0 then
					local d = (tx - x) ^ 2 + (tz - z) ^ 2
					if d ~= d then worst = 1e9 elseif d > worst then worst = d end
				end
			end
		end
		local q = u:position()
		local dx, dz = sx / #ms - q:get_x(), sz / #ms - q:get_z()
		out[i] = u:type() .. ": centre " .. math.floor(math.sqrt(dx * dx + dz * dz) * 10) / 10 .. " m, worst steer "
			.. math.floor(math.sqrt(worst)) .. " m, men " .. #ms .. "/" .. u:number_of_men_alive()
	end)
	if not ok then out[i] = "threw: " .. tostring(err) end
end
return out
