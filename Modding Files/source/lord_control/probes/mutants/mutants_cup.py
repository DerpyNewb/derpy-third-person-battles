M = "script/derpy_tp/main.lua"
T = "third_person_fades_the_empty_button_cup"
MUTANTS = [
    (M, "local CUP = {2, 3}", "local CUP = {3}", T),
    (M, "local CUP = {2, 3}", "local CUP = {1, 2, 3}", T),
    (M, "local CUP = {2, 3}", "local CUP = {}", T),
    (M, "mask:SetCurrentStateImageOpacity(i, 0)", "do end", T),
    (M, "mask:SetCurrentStateImageOpacity(i, F.cup[i])", "mask:SetCurrentStateImageOpacity(i, 255)", T),
    (M, "if mask and F.cup then for _, i in ipairs(CUP) do mask:SetCurrentStateImageOpacity(i, F.cup[i]) end end", "", T),
    (M, "if F.cup[i] == nil then F.cup[i] = mask:GetCurrentStateImageOpacity(i) end", "F.cup[i] = mask:GetCurrentStateImageOpacity(i)", T),
    (M, 'find_uicomponent(root, "porthole_parent", "porthole_mask")', 'find_uicomponent(root, "porthole_parent", "model_parent")', T),
]
MUTANTS += [
    (M, "try(function() bm.battle:set_banners_enabled(true) end)", "", "third_person_switches_banners_off_and_back"),
]
MUTANTS += [
    (M, "bm.battle:suppress_unit_voices(true)", "do end", "third_person_silences_unit_voices_and_back"),
    (M, "try(function() bm.battle:suppress_unit_voices(false) end)", "", "third_person_silences_unit_voices_and_back"),
]
CIN = "if show then bm:enable_cinematic_ui(false, true, false) else bm:enable_cinematic_ui(true, false, false) end"
MUTANTS += [
    (M, CIN, "if show then bm:enable_cinematic_ui(false, true, false) end", "looking_hides_the_battle_interface"),
    (M, CIN, "if show then bm:enable_cinematic_ui(false, true, false) else bm:enable_cinematic_ui(true, true, false) end", "looking_hides_the_battle_interface"),
    (M, CIN, "if not show then bm:enable_cinematic_ui(true, false, false) end", "looking_hides_the_battle_interface"),
    (M, "if F.cursor_shown == show then return end", "", "looking_hides_the_battle_interface"),
]
MUTANTS += [
    (M, "\t\tbm.battle:set_banners_enabled(false)\n", "", "flags_stay_off_across_interface_switches"),
    (M, "\t\tbm.battle:set_banners_enabled(false)\n", "", "third_person_switches_banners_off_and_back"),
]
