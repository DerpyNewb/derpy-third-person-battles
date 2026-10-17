# Third person, 2026-10-17: the reload bypass and the transformation that loses the unit

Two bugs the author reported from one custom battle with a Deithland army (Workshop 3502673197,
`17C_Deithland_Main.pack`): "some ranged units bypass the reload time" and "change ammunition units will
disappear when the ability is pressed". Evidence is the battle's script log, `script_log_171026_0742.txt`
(game time in seconds below), and two live reads over the bridge. Build 6acec6f4.

**State at the end of the session:** both fixed, plus artillery's Manual fire (section 5). 380 tests, round 36's 15
and round 37's 3 mutants green. Deployed 16:09 with the game shut: `data/derpy_third_person.pack` = `f0f97591`, same 18
paths. It replaced `70b00eb0` (09:05), now `Modding Files/Backup/derpy_third_person_data_before_manual_fire_wait_20261017.pack`;
before that `859fd60d` (`..._before_takeover_20261017.pack`) and `4ce7676e` (`..._before_reload_transform_20261017.pack`).
**Verified live:** the transformation keeps the unit (section 2b); the reload clock on a man with no RELOAD_1 (section
5, the Zweishot); Manual fire on the deployed pack, 3 runs of 4; the take-over both ways on the deployed pack (section 6).

## 1. The reload bypass - fixed, root cause measured

**Seen.** Hessmarine Grenadiers (`emp_hessmarines_grenadiers`, 7 s reload in the game's data) shot at 229.4,
233.8, 274.2, 279.0, 283.4 and 286.8 s: "shot clip nil in fire" was followed at once by the next "shot level",
with no "in reload" line. The Axelocks and the Autodragon in the same battle went through "clip 1564 in reload".

**Read live.** `P.reload_slot` per ranged unit: seven of the army's 19 ranged units have no `RELOAD_1` (1564) and
only the raise to aim (1554), so it answered 1554 for them - Mortar Muskets, Blasterkeys, Deithguard Shields,
Pyrehulk Fusilaxe and Volley, the Grenadiers, the Gunshields.

**Root cause.** `P.reload_slot` offered 1554 as a reload, on the premise that "a crossbow's reload is its next
raise to aim". On that path `combat.lua` set no `F.ready_at` when the fire clip ended, and `C.drop` exempted it
too, so the only wait between shots was the raise clip (about 1.4 s). The game's reload time was never applied
to them - the same complaint as 2026-10-16, fixed then only for men with a 1564 clip.

**Fix.** `P.reload_slot` answers 1564 or nothing. A man without it goes down the existing no-reload-clip path:
the projectile's reload time on the clock from the fire clip's end, the setting's share of it. `C.drop`'s
exemption is gone. `SLOT_AIM` is now only the high pair's check.

**Tests.** New `solo_without_a_reload_clip_waits_the_game_reload` (RED: 4 shots in 17 s where one is due).
`a_crossbow_switching_modes_after_its_bolt_adds_no_wait` was the bug written as a test and is now
`..._still_waits`. `solo_click_during_reload_is_kept` and `a_high_raise_does_not_take_the_level_ones_length` only
waited less than a crossbow's 13 s reload and were lengthened. The platform test's contract is now "a crossbow's
raise is no reload".

## 2. The transformation - fixed on the evidence, root cause NOT measured

**Seen.** Deithland's ammo modes are transformations: `unit_special_abilities.spawn_is_transformation`, the
`spawned_unit` an 8-man unit (autodragon <-> autodragon_shotgun, mortar <-> mortar_flame, halberd, zweishot,
cofferglare big/small). A multi-entity transformation has no vanilla precedent (`docs/BATTLE_UNIT_SWAPS.md` 7.3).

- 934.9 s, third person **off**, CA's button: the Pyretitans Autodragon became its shotgun form. Worked.
- 921.0 s, third person **on**, the pack's key: "cast emp_pyretitan_mortar_flame_mode (none)". Afterwards the
  army held **neither the mortar nor `emp_pyretitans_mortar_flame`**. The author left third person 3.4 s later.
- 944.3 s, third person on: "cast emp_pyretitan_autodragon_cannon_mode (none)". 2.3 s later "stalled 1 s with a
  move key held ... his command walk": the pack was still steering the old man. The cannon form was in the army
  afterwards, at the end of the list, under the original form's ui id 1009.

**Hypothesis (the fix rests on it).** After a swap the old script unit still reported men (the pack never said
"unit lost") and `P.alive` still read his man as alive off the old unit's engine object, so every frame the pack
went on writing steering, the guard's native stop and, at the stop, his melee fragment into a unit the engine
had replaced. Not proven: no per-frame read of the swap was taken.

**Fix.** `data.lua` gains the kind `transform` (`build_third_person.py ability_kind`: `spawn_is_transformation`
and a `spawned_unit`; 51 abilities among the installed mods, and CA's own, such as Yuan Bo's dragon form, which
the selftest now checks). `A.cast` on a transform ends third person first, so everything goes back on the unit
while it is real, then activates it as CA's button does (`PerformAbilityForOwner`, the 934.9 route). The tick
returns after a key that ended the session, so nothing more reaches the old man that frame.
`a_transformation_ends_third_person_before_it_goes_off` was RED on both halves (third person stayed on; the guard
and disarm still ran after the cast).

**Ceiling.** The player is left out of third person on the new form and presses the key again. Taking the new
form over by itself is the next step if that is wanted. A transformation from a mod installed after the last
`--gen` reads as `none` until the next one.

## 2b. Live, 08:44-09:01: the unit stays; then the new form taken over

The author played the 08:41 pack: "seems to deactivate f2 when changing ammo" - the swap kept the unit (the flame
form was in the army, played at 162.9 s) and third person ended, as built. Measured over the bridge with
`zz_tp_transform.lua`:

- off (CA's button): cast at 600 ms, the other form in the army by 800 ms, under its own ui id (mortar 1010, flame
  1022), all 8 men, at the regiment's spot.
- on (the source loaded over the bridge, with a take-over): third person off at the cast and on again as the flame
  form by 799 ms, one man, alive. **But** taken over the frame the new form appeared, before its unit card: "HUD part
  portrait is off: no unit context for this unit", and the slots with it - a dead HUD part stays off for the battle,
  and without the card's context the ability keys cannot switch back.

So `M.follow` (main.lua): the army's ui ids at the cast; while third person is off, the first unit not among them,
alive and **with its card in `cards_panel`**, is `M.start`ed; given up after 10 s of battle time (a wind-up
included); `M.start` clears it, so F2 wins. The new form spawns where the regiment stood, not where the played man
had walked to: the camera jumps there.

## 2c. Fire held as a session starts threw

`zz_tp_reload_hold.lua` (fire held from the first frame) stopped third person with "attempt to perform arithmetic on
field 'ey'" in `aim_point`. `rig.lua R.start` cleared the eye's height and left the last session's x, so the aim's
"no eye yet" (`if not R.ex`) let a half-eye through. A player holding the button while pressing F2 hits the same,
and it counts a strike towards switching the pack off. `R.start` now clears the whole eye.
`fire_held_as_a_session_starts_waits_for_the_camera` was RED on it.

## 3. Mutants

Round 36 (`probes/mutants_round36.py`): 15, all killed. One survived until the take-over's test had a second
regiment with a card: without it, "any unit with a card" passed for "the new form". Three anchors in older sets aimed at the deleted code
and were re-aimed (`mutants_fire_cycle.py`, `mutants_unlatch.py`). One mutant newly survived after the change and
was re-aimed: `SLOT_AIM = 1552`, whose only remaining use is the high pair's check. Five other survivors or stale
anchors in those two sets predate today: the same sets run against yesterday's source in the repo clone report
them (mounted swings, the walk's `P.steer` lines).

## 4. Open

- **Live, still to do:** the Grenadiers' reload with `zz_tp_reload_hold.lua` (`_G.TP_RH_TYPE`, `_G.TP_RH_DURATION`;
  read with `zz_tp_reload_hold_read.lua`) - expect a shot every 7 s plus the clips, against 2-4.4 s before; and a
  switch with the 09:05 pack, which should end with the HUD's portrait and slots on the new form.
- **The probes.** `probes/zz_tp_transform.lua` (`_G.TP_TF_TYPE`, `_G.TP_TF_KEY`, `_G.TP_TF_MODE` "off" or
  "on"; read with `zz_tp_transform_read.lua`) casts a transformation either way and records the army each tick
  for 6 s. Run "off" and "on" on the same unit type, on the source loaded over the bridge. For the reload: the
  Grenadiers held on fire should shoot every 7 s plus the clip.
- **The culverin and the cofferglare also left the army list** between 07:49 and 08:05 real time. The enemy broke
  at 683 s, so they may have been destroyed earlier - whether a wiped-out unit drops off `army:units()` is not
  known. The cofferglare has transform abilities, but no cast of them was logged.
- **The game exited at about 08:09** with no crash dump and no Windows event. The bridge never logged the battle
  restart sent from the results screen. A restart from the Complete phase is untried, so do not repeat it until
  that is known.
- Deployed 08:41 with the game shut: same 18-entry file list as the copy it replaced.

## 5. Artillery and war machines, 15:15-16:20 (the author: "test out artillery and warmachines with the mod")

Launched the game myself on `used_mods.txt`; it went straight into the Deithland custom battle's deployment both times
(no click from me - the lobby's last setup). `probes/zz_tp_machines.lua` drives each unit through the shipped frame loop
with synthetic keys: selected, F2, 3 s forward, then fire held (or the mode key for artillery), F2 off. Enemy held and
everyone invincible. Nine units, no Lua error, no strike, and every one got its fire at will and defend back at F2.

| Unit | Played as | Walk 3 s | Shots |
|---|---|---|---|
| Pyretitans Autodragon (8 men) | one man, alone | 6.3 m | 12.4 s apart, reload 8 |
| Pyretitans Mortar | one man, alone | 6.4 m | 18.2 s apart, reload 14 |
| Pyretitans Halberd | one man, alone | 6.1 m | 12.4 s apart, reload 8 |
| Pyretitans Zweishot (no RELOAD_1) | one man, alone | 6.1 m | 14.2 s apart, reload 10 |
| Gottzorn Knellgun (war machine, 4) | whole unit | 2.7 m | ground fire, volleys 24.4 s apart, reload 21 |
| Culverin, Armored Autofalcon, Autodragon, Cofferglare (artillery) | whole unit | 0-6 m | Manual fire: see below |

The Zweishot has no RELOAD_1, so it is section 1's path, live: the reload is now kept.

**Artillery walk.** Three of the four guns moved under 1 m in 3 s and logged "stalled 1 s". `zz_tp_arty_walk.lua` on
the Cofferglare: the game's own `goto_location` 15 m ahead and the pack's held key give the same curve - standing until
3 s, then about 10 m. That is how the gun moves, not the pack.

**Manual fire closed itself.** The mode key opened it 0.2 s after the key and the game closed it within a second, then
the watcher gave third person back: 8 of 8 in the run, 2 more through the pack after it. The author hit it too (the
script log at 912 s). `zz_tp_manual.lua` bisects it on a Culverin:

| Route | Result |
|---|---|
| third person off, CA's button clicked | held 6 s |
| third person on, then off, button 0.1 / 0.3 s after the stop | closed within 1.2 s (3 runs) |
| the same, 0.5 / 1 / 2 s after | held (1 run each) |
| the camera floor given back (`change_height_range(-1, -1)`) 0.1 s before | closed after 1 s |
| CA's cinematic interface switched off 0.1 s before | the view never opened |
| fire at will and defend given back, or the camera functions alone, 0.1 s before | held |
| the lowered floor kept through it | held |

So nothing in the stop is wrong; what it puts back takes a moment to settle (the floor and the cinematic interface's fade
both do). A first fix that kept the lowered floor was built on one of the two and failed live; it was taken out.
**Fix:** the watcher clicks no sooner than `SETTLE` = 1 s after the key (`combat.lua`), twice the shortest gap that
held. `manual_fire_waits_for_the_game_to_settle` was RED; the two older Manual fire tests now step past the wait.
Round 37: 3 mutants, all killed. **Live on the deployed pack:** 3 of 4 runs held to the end; the first closed 0.4 s after
opening, before focus and the right mouse button were sampled, so it is unexplained. If the author still sees it, the
next step is a retry when the view closes inside a second without a key, or a longer wait.

Seen and not changed: a whole unit's ground fire aimed at the horizon puts the point at the edge of its range, so the
Knellgun stepped forward and each step moved the point 5 m on (seven re-orders in 26 s). A player aiming at the ground
does not get this.

The game was closed at the end by ending the process: the bridge's exit works only on the campaign map, and a
scripted click on the battle's menu button opened nothing.

## 6. The take-over, live on the deployed pack (16:40)

`probes/zz_tp_takeover.lua`, `f0f97591` from data/, the Pyretitans Mortar, both casts through the pack's own path
(`E.abilities.cast`, which goes through the unit card's context):

- 1.0 s: flame mode cast through the card; third person off. 1.2 s: card 1010 gone. 1.4 s: card 1022 there and the
  flame form played the same frame, one man, shooting alone.
- 3.0 s: the flame form's own mortar mode cast through ITS card (so the HUD had the new form's context). 3.4 s: back on
  the mortar under its old id 1010.
- No "HUD part ... is off", no error. Game closed after.
