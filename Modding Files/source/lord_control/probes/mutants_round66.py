# Round 66 (2026-10-24): the author, "now add mct unit stats buff or debuff, add options for stats, default is none". Each
# step is an army ability cast at the unit played, and cast again to take it off (buffs.lua).
BUFFS = "script/derpy_tp/buffs.lua"
SETTINGS = "script/derpy_tp/settings.lua"
MAIN = "script/derpy_tp/main.lua"
PAGE = "script/mct/settings/derpy_third_person.lua"
ON = "a_stat_chosen_goes_on_the_unit_played_and_comes_off_after"
MUTANTS = [
    # never trusts what is on him: casts again, which takes it off
    (BUFFS, "if target and has(target, key) then", "if false then", ON),
    # never takes it off the unit let go
    (BUFFS, "elseif last and last ~= target and alive(last) and has(last, key) then", "elseif false then", ON),
    # the unit let go still counts as played
    (BUFFS, "local unit = F.on and alive(F.unit) and F.unit or nil", "local unit = F.unit", ON),
    # a second cast before the first has landed: the second takes it off again
    (BUFFS, "local GAP = 0.5", "local GAP = 0", ON),
    # the frame never asks
    (MAIN, "\t\t\tE.buffs.tick(gnow)\n", "", ON),
    # the steps never counted as wanted
    (BUFFS, "for key in pairs(want) do used[key] = true end", "", ON),
    # let go: believed off with no cast. The next start's check would put it right (a_stat_on_a_unit_not_looked_at...),
    # so it shows where nothing starts again
    (BUFFS, "cast(last) -- off, from the unit that has it", "-- off, from the unit that has it", ON),
    # a phase put there by something else is left, and he never gets his
    (BUFFS, "cast(target) -- on; or, were it on a unit not looked at, off", "-- on; or, were it on a unit not looked at, off",
     "a_stat_on_a_unit_not_looked_at_is_put_right"),
    # aimed at the regiment's centre, not the man played
    (BUFFS, "if F.model and unit == F.unit then", "if false then", "one_man_is_aimed_at_himself"),
    # cast in a multiplayer battle
    (BUFFS, "if refused or P.features.net then return end", "if refused then return end",
     "unit_stats_stay_out_of_multiplayer"),
    # no look at what the army owns: casts for a faction that owns none
    (BUFFS, "if not list(unit, 'ArmyContext", "if false and not list(unit, 'ArmyContext",
     "a_faction_without_the_stats_is_told_once"),
    # the player never told
    (BUFFS, "\t\t\t\tE.say(\"derpy_tp_stats_faction\")\n", "", "a_faction_without_the_stats_is_told_once"),
    # MCT's value read as the wrong step
    (SETTINGS, "if T.step_key(step) == chosen then S.stats[stat] = step end", "if T.step_key(step) == chosen then S.stats[stat] = -step end",
     "unit_stats_page_offers_none_and_every_step"),
    # a step the default, not None
    (PAGE, "text = T.text(stat, step), tt = \"\", is_default = false}", "text = T.text(stat, step), tt = \"\", is_default = true}",
     "unit_stats_page_offers_none_and_every_step"),
]
