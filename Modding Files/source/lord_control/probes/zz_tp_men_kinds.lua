-- Read-only: per player unit, CA's class predicates; for the first unit of each type, every model whose type marker
-- is not the infantry one (+390d4f8) with its index and offset from the unit centre, and which man front_man picks.
-- NO string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local P, mr = E.P, _G.memreader_plus
local out, done = {}, {}
local armies = bm:get_player_alliance():armies()
for a = 1, armies:count() do
	local units = armies:item(a):units()
	for i = 1, units:count() do
		local u = units:item(i)
		local t = u:type()
		if not done[t] then
			done[t] = true
			local row = {}
			local ok, err = pcall(function()
				row.war_machine = u:is_war_machine()
				row.chariot = u:is_chariot()
				row.class = tostring(u:unit_class())
				row.cavalry = u:is_cavalry()
				row.infantry = u:is_infantry()
				local q = u:position()
				local ms = P.models(u)
				local front = E.move.front_man(u)
				local odd = {}
				for k, m in ipairs(ms) do
					local vt = mr.tostring(mr.read_pointer(m, 0))
					local x, _, z = P.model_pos(m)
					local tag = k .. " " .. vt .. " @" .. math.floor(x - q:get_x()) .. "," .. math.floor(z - q:get_z())
					if mr.eq(m, front) then tag = tag .. " FRONT" end
					if #ms <= 8 or vt ~= "000000014390D4F8" or mr.eq(m, front) then odd[#odd + 1] = tag end
				end
				row.models = odd
			end)
			if not ok then row.err = tostring(err) end
			out[t] = row
		end
	end
end
return out
