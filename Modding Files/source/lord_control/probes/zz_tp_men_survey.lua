-- Read-only survey: the pack's one-man check on every player unit, and for a failing unit how many model types it
-- holds and how many men carry each. Uses the loaded pack's E (_G.DERPY_TP). NO string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local P, mr = E.P, _G.memreader_plus
local out = {}
local armies = bm:get_player_alliance():armies()
for a = 1, armies:count() do
	local units = armies:item(a):units()
	for i = 1, units:count() do
		local u = units:item(i)
		local row = {type = u:type(), men = u:number_of_men_alive(), arty = u:is_artillery()}
		local ok, res, why = pcall(P.check_men, u)
		row.check = ok and (tostring(res) .. (why and (": " .. why) or "")) or ("threw: " .. tostring(res))
		if ok and not res then
			local seen, order = {}, {}
			local ok2, err2 = pcall(function()
				for _, m in ipairs(P.models(u)) do
					local vt = mr.tostring(mr.read_pointer(m, 0))
					if not seen[vt] then seen[vt] = 0 order[#order + 1] = vt end
					seen[vt] = seen[vt] + 1
				end
			end)
			local parts = {}
			for _, vt in ipairs(order) do parts[#parts + 1] = vt .. " x" .. seen[vt] end
			row.types = ok2 and table.concat(parts, ", ") or ("threw: " .. tostring(err2))
		end
		out[#out + 1] = row
	end
end
return out
