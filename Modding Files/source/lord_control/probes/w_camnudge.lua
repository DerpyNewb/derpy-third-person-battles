local ok, res = pcall(function()
	local cam = bm:camera()
	local p, t = cam:position(), cam:target()
	cam:move_to(v(p:get_x() + 7, p:get_y() + 3, p:get_z() + 5), v(t:get_x() + 7, t:get_y() + 3, t:get_z() + 5), 0, false, -1)
	return "nudged"
end)
if ok then return res end
return "ERR " .. tostring(res)
