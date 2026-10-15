-- HUD measurement (plan 2 Task 1): can script turn CA's first-person reload ring? Builds its own instance of the
-- first-person layout (the pack's crosshair is hidden by the tick when nobody aims), shows only the crosshair and its
-- ring, centred, and sets the two half rings to _G.TP_RING_A / _G.TP_RING_B (radians, as CA's lib_text_pointers
-- passes them). _G.TP_RING_OFF = true hides it again. NO string library calls.
local root = core:get_ui_root()
local ui = find_uicomponent(root, "derpy_tp_ring_probe")
if _G.TP_RING_OFF then if ui then ui:SetVisible(false) end return "hidden" end
if not ui then
	ui = UIComponent(root:CreateComponent("derpy_tp_ring_probe", "ui/battle ui/first_person_ui"))
	for i = 0, ui:ChildCount() - 1 do local c = UIComponent(ui:Find(i)) c:SetVisible(c:Id() == "crosshair") end
end
ui:SetVisible(true)
local x = find_uicomponent(ui, "crosshair")
local sw, sh = core:get_screen_resolution()
local w, h = x:Dimensions()
x:MoveTo(math.floor(sw / 2 - w / 2), math.floor(sh / 2 - h / 2))
local ring = find_uicomponent(x, "reload_ring")
local l1, l2 = ring and find_uicomponent(ring, "loading_ring_L1"), ring and find_uicomponent(ring, "loading_ring_L2")
if not (ring and l1 and l2) then return {ring = ring and true, l1 = l1 and true, l2 = l2 and true} end
local A, B = _G.TP_RING_A or 0, _G.TP_RING_B or 0
local ok1, e1 = pcall(function() ring:SetVisible(true) end)
local ok2, e2 = pcall(function() l1:SetImageRotation(0, A) end)
local ok3, e3 = pcall(function() l2:SetImageRotation(0, B) end)
local rx, ry = ring:Position()
local rw, rh = ring:Dimensions()
return {show = ok1 and "ok" or tostring(e1), r1 = ok2 and "ok" or tostring(e2), r2 = ok3 and "ok" or tostring(e3),
	at = rx .. "," .. ry, size = rw .. "x" .. rh, a = A, b = B}
