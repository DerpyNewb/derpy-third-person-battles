-- Set the drive mode and timings, clear the log and stand in for W held 6 s. Edit the three values per run.
local ok, res = pcall(function() local F = _G.DERPY_FOLLOW F.mode, F.order_every, F.lead = "order", 100, 12 F.log, F.orders, F.writes = {}, 0, 0 F.sim = {1, 0, os.clock() + 6} return F.mode end) if ok then return res end return "ERR " .. tostring(res)
