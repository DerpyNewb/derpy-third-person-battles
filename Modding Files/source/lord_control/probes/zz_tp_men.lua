-- why does P.check_men fail? For every unit in the player's army: men alive, models in the array, the first
-- model's type marker as an RVA (hex string halves, float32-safe), whether all models share it, and the
-- reason P.check_men gives. Read-only.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local function rva(p) -- exe-relative offset of p as hex, from the 16-digit strings (no float32 maths)
		local a, b = mr.tostring(p), mr.tostring(mr.base)
		return a, b
	end
	local out_t = {model_vt = mr.tostring(P.model_vt), base = mr.tostring(mr.base)}
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		local ms = P.models(u)
		local row = {key = u:type(), alive = u:number_of_men_alive(), models = #ms}
		if ms[1] then
			local vt = mr.read_pointer(ms[1], 0)
			row.vt = mr.tostring(vt)
			local same = 0
			for _, m in ipairs(ms) do if mr.eq(mr.read_pointer(m, 0), vt) then same = same + 1 end end
			row.same = same
		end
		local cok, pass, why = pcall(P.check_men, u)
		row.check = (cok and "" or "THREW ") .. tostring(pass) .. " " .. tostring(why)
		out_t[#out_t + 1] = row
	end
	return out_t
end)
if ok then return res end
return "ERR " .. tostring(res)
