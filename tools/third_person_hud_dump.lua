-- Not shipped. Run by tools/preview_third_person_hud.py through the harness: the SHIPPED hud.lua fills the panel on
-- the harness's fake tree, and this writes where every part ended up to the file named by TP_HUD_DUMP. The scene is
-- the hardest the HUD shows: ten abilities, three cooling, one not castable, the longest key labels, a 120-man
-- regiment at 118, a long name, 12 of 20 shots; all four action buttons counting down, the longest key label on jump.
local T = {}
T.dump = function()
	local ab = {} for i = 1, 10 do ab[i] = "wh_main_spell_test_" .. i end
	H.fresh({units = {{general = true, abilities = ab, can = {[ab[4]] = false}, men = 120, range = 160, ammo = 12,
		start_ammo = 20, hp = 0.62, type = "wh3_main_cth_inf_iron_hail_gunners_0"}},
		mct = {key_ability_9 = "Numpad 9", key_ability_10 = "Mouse 5", key_jump = "Caps Lock"}, enemies = {{x = 20, z = 80}}})
	local t = H.default_cco()
	t.Name = "Iron Hail Gunners of the Jade Fleet"
	t.IconPath = "ui/units/icons/wh3_main_cth_inf_iron_hail_gunners_0.png"
	t["BattleAbilityList.Size"] = 10
	for i, k in ipairs(ab) do
		local at = "BattleAbilityList.At(" .. (i - 1) .. ")."
		t[at .. "SetupAbilityContext.RecordKey"] = k
		t[at .. "SetupAbilityContext.IconPath"] = "ui/battle ui/ability_icons/0_placeholder_active_abilitiy&spell.png"
		t[at .. "RechargeTimeRemainingSecs"] = (i == 2 and 4.2) or (i == 6 and 37) or (i == 7 and 0.4) or 0
		t[at .. "IsActive"], t[at .. "ActiveTimeRemainingSecs"] = i == 5, i == 5 and 11.6 or 0 -- slot 5 running
		t[at .. "WindUpTimeRemainingSecs"] = i == 8 and 6.3 or -1 -- slot 8 winding up
	end
	H.cco = t
	H.units[1]._models[1].alive, H.units[1]._models[2].alive = false, false
	H.tap("F2")
	H.step(0.5)
	local F, now = H.E.F, H.game_ms / 1000
	F.next_swing, F.next_jump, F.ready_at, F.next_charge = now + 1.2, now + 4.6, now + 5.3, now + 8.4
	F.running = true -- the Run button lit
	H.step(1 / 60)
	H.E.hud.armed(3) -- an armed ability and the label naming its target, the longest name a vanilla unit has
	H.E.hud.target("Chaos Lord of Nurgle on Rot Fly")
	H.w2s = function() return 1180, 400, 0.98 end -- and the arrow over him, up and right of the crosshair
	H.E.hud.mark(H.enemies[1])
	local f = assert(io.open(os.getenv("TP_HUD_DUMP"), "w"))
	local function walk(c)
		if c.hud and c.id ~= "derpy_tp_hud" then
			f:write(table.concat({c.id, c.x, c.y, c.w or 0, c.h or 0, tostring(c.visible), (c.img or {})[0] or "",
				c.text or ""}, "\t") .. "\n")
		end
		for _, k in ipairs(c.kids) do walk(k) end
	end
	walk(H.root)
	f:close()
end
return T
