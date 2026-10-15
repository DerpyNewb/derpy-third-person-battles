local ok, res = pcall(function() common.take_screenshot("derpy_cam_shot.tga") return "shot" end) if ok then return res end return "ERR " .. tostring(res)
