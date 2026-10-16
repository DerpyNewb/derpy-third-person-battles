-- Why start returns. No string library calls.
local E = _G.DERPY_TP
local s = "disabled " .. tostring(E.disabled) .. " pending " .. tostring(E.pending) .. " fails " .. tostring(E.fails)
for k, v in pairs(E) do if type(v) ~= "function" and type(v) ~= "table" then s = s .. " | " .. tostring(k) .. "=" .. tostring(v) end end
return s
