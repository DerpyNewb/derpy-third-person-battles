# Handoff 2026-10-14: F2 drift fixed with the engine's own stop

Continues [held fire, mounted attacks, and unresolved F2 movement](HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md).
Task 13 of `docs/superpowers/plans/2026-10-13-third-person-pack-core.md`.

## Current state

- **Fixed and measured live:** F2 no longer moves the controlled soldier, and releasing the keys stops him
  within one 100 ms model tick. Selftest **109/109**; mutants **28/28 steering, 14/14 fire-cycle killed**.
- The maintained source is bridge-loaded in the running battle. No pack is built, deployed or enabled.
- Pending: the author's hand test, and the self-target ability cast left open by the previous handoff.

## Root cause

Measured with `probes/tp_cmd_trace.py`, which reads one model's command fields from outside the game every
~5 ms, against the scripted stages of `probes/zz_tp_f2_drift.lua`:

1. **A walk keeps the man moving until its command is replaced.** On reaching its point a walk reports done
   (`model+0x710` = 6, command `+0x10` = 1) and he coasts on at full speed. Outside third person the formation
   replaces the finished command within ~0.4 s; while F2 held him nothing did, so he walked on for good.
2. **A walk refreshed toward his own feet never finishes.** Release and F2 off wrote the hold point (his own
   position) into the walk and cleared its init byte (`+0x3c0`); `3255ff0` then re-ran the locomotion
   (`3071e04`) with a zero-length path, and he walked along his facing, which we rewrite every frame to the
   camera yaw. Turning the camera while standing re-armed the same refresh. F2 start hit it too: `uc:halt`
   leaves `390cba8`, the formation then starts its own slot walk, and we took it over with the hold point.
3. The locomotion is built at (re)init toward the point at that moment; points written in place afterwards do
   not steer it (wrapper v5: W during an order moved him 0.2 m).

`3255ff0` re-inits whenever `cmd+0x90` is 0 **or** `model+0x710` is 0. Its caller `325d9e0` sets done only on
`+0x710` 6 with `cmd+0x82` set or a running gait, or on 7.

## The fix

- `exe+3069d7c(model)` is the engine's own stop: it reads his animation state (`+0x318`), destroys the command
  (`2db0a10`) and builds `390cba8`, "stand in state X" (state at `+0x368`). It is the command `uc:halt` leaves
  on each man. Found by scanning the live code for each command vtable's one constructor (the exe on disk is
  packed; the code lies in the first section, `0x1000`-`0x33a2000`, whose name is scrambled).
- `platform.lua`: BUILDS gains `walk_stop = 0x3069d7c` (float32-exact) and `features.steer` requires it.
  New `P.hold(m, x, z, yaw)`: slot copies take the hold point; a running walk (`walk_a` or `walk_b`) gets the
  native stop; then his facing. No command payload is written. `P.steer` is now for walking only; its doubled
  `walk_b` check and the `walk_a` exception in its own-spot guard are gone.
- `move.lua`: no keys and F2 off call `P.hold`; only a held key calls `P.steer`.

| Stage (iron hail gunners, 2 s each) | Before | Fixed |
|---|---:|---:|
| F2 on, no keys | 1.40 m | 0.00 m |
| W held | walks | 2.60 m |
| W released | 2.85 m, walking on | 0.15 m, one tick |
| F2 off | walks on | 0.00 m, back to idle |
| F2 during a prior order, no keys | 2.47 m | 0.06 m |

Zero strikes. Evidence in `Modding Files/source/lord_control/probes/`: `tp_f2_drift_before_20261014.json`,
`tp_f2_drift_fixed_20261014.json`, and the field traces `tp_cmd_trace_before_`, `_native_stop_` and
`_fixed_20261014.json`. Summaries: `py tp_f2_drift.py <file>`.

## Tests

- New: `holding_still_stops_a_running_walk_natively`, `holding_still_leaves_a_standing_man_alone`.
- `steering_writes_the_walk_command_point` (the one red test) is now
  `steering_writes_his_own_walk_and_replaces_a_regiment_walk`: the regiment walk is replaced natively, never
  written, which the live runs verified.
- `one_man_walks_alone` checks no walk is steered after release; `one_man_stop_cancels_its_lead_point` counts
  the hold F2 off makes (a mutant that skipped it survived the last-call check); the unknown-build test checks
  no 9.0 function is called.
- `mutants/mutants_steer.py` rewritten for the new code: 28 mutants, including both halves of the hold gate.

## Probes added

`zz_tp_f2_drift.lua` / `_read.lua` / `tp_f2_drift.py` (staged drift test, 1-based unit lists, top level never
throws), `zz_tp_hold_enemy.lua` (takes the enemy off AI and halts it), `tp_cmd_trace.py`, `zz_tp_front_man.lua`,
`zz_tp_heading_toggle.lua` (last held the v6 wrapper; superseded by source) and `zz_tp_steer_restore.lua`.

## Next

1. Author's hand test: F2 idle, WASD, release, Shift, camera turn while standing, F2 off; then held fire and a
   mounted lord again, since `move.lua` changed. Cast a self-target ability (potion of speed) once.
2. Open: in a prior-order battle the regiment around him still drifted 1-3 m during F2 (neighbour and unit
   centre columns); the controlled man did not. Not reported by the author.
3. Tasks 13 Steps 3 and 5, Tasks 14-16 as listed in the previous handoff.

## Same day, after the author's first hand test

The author confirmed movement and the self-target cast (Potion of Speed on the General). Reported: panels
still visible (a unit hover panel), the portrait clipped bottom-left, no aim before fire, and no way to land a
flyer. The UI survey's unguarded readback then wedged the bridge (06:55); the game needs a restart.

- **Aim before fire (source, offline-tested):** 9.0 slot ids are AssetEditor's dlc24 list + 2, so 1554 is
  `SHOOT_READY_TO_AIM_LEVEL` - the clip the cycle played AFTER each shot as the crossbow "reload". The cycle
  is now aim 1554 (mask 6) -> fire 1557 (mask 0) -> reload 1564 (mask 6) when the fragment has `RELOAD_1`;
  a crossbow's raise to aim is its reload, matching the game's own crossbow cycle. New test
  `solo_aims_fires_then_reloads` (red first); eight solo tests retimed for the 1 s aim, the reload tests
  moved to a `RELOAD_1` unit to keep their meaning. Released during a crossbow's next aim, he still fires.
- **Fly or land (source, offline-tested):** no script call lands a flyer; the game's own control is
  `button_toggle_flying` ("When turned off, flying units will land and stay on the ground", from
  `uied_component_texts`). New action `fly`, default Space, MCT-configurable, presses it while the mouse is
  captured; logs once when the unit has no such button. Whether a click on the hidden button acts is
  **unverified live**.
- Selftest 112/112; mutants 31/31 steering (fly included), 19/19 fire-cycle.
- **Hover panel and clipped portrait:** need `zz_tp_ui_tree.lua` (rewritten: pcall'd readback in
  `zz_tp_ui_tree_read.lua`, ids reduced to `[%w_]`, one-string result) after the restart.

## After the restart (same day)

The survey wedges were string-library calls in the eval chunks, not the UI walk (memory
`wh3-mcp-bridge-wedges-on-interface-walks`, sixth trigger). Survey v4 and every later probe use only `..`,
`tostring`, `type`, `math.*` and `==`; the clock stayed a number throughout.

- **Hover panel (source + live call):** `bm.battle:enable_tooltips(false)` on start, `true` on stop. The
  survey found `SpecialTooltip` absent while nothing was hovered, so whether the call stops it showing is
  for the hand test; the fallback is adding `SpecialTooltip` to `hud()`'s root list.
- **Fly key, verified live** (`zz_tp_fly_click.lua`): with `battle_orders` hidden by third person, a
  `SimulateLClick` on `button_toggle_flying` (state `selected`) landed the flying General -
  `is_currently_flying()` true at 0.1 s, click at 0.5 s, false at 2.3 s. A click on a button inside a
  hidden pane still acts.
- **Portrait cut bottom-left, fixed and verified live** (`zz_tp_cup.lua`): CA's `porthole_mask`
  (`ui/battle ui/hud_battle.twui.xml`, ui3.pack) draws four images - chain, frame, a 16x140 side strip
  `porthole_add.png` and the 50x88 cup `battle_porthole_buttons_holder.png` - and the cup holds
  `button_toggle_infopanel` and `button_unit_camera` / `button_unit_manual_fire`. `hud()` hides those
  buttons (re-hidden every tick, so showing them would bring back one button that fights our camera and
  one that flickers), which left two empty black sockets. `hud()` now fades state images 2 and 3 with
  `SetCurrentStateImageOpacity` and restores the read values on stop. Live: before `255 255 255`, on
  `255 0 0`, off `255 255 255`. Test `third_person_fades_the_empty_button_cup` (red first); mutants
  `mutants/mutants_cup.py` 8/8.
- Selftest 114/114. Bridge regenerated and loaded with all of this. Nothing built or deployed.

**Next:** the author's hand test - no hover panel, aim then fire (Ironhail), Space to land and lift (the
General is on the ground after the fly probe), the portrait whole. Then Task 13's remaining steps and
Tasks 14-16.

## Second hand test: flag, arrows, the lord's star

- **Unit flags (source + live call present):** the 3D flag over the unit is CA's "unit ID". `bm.battle:set_banners_enabled(false)`
  on start, `true` on stop - its twin `enable_unit_ids` would write the change into the replay. Test
  `third_person_switches_banners_off_and_back`.
- **Selection markers: NOT fixed, and the preference route is withdrawn.** `ui_selection_markers` read back 0
  in game, but paired screenshots (`zz_tp_marker_shots.lua`, `wh3-mcp/tools/screenshot.ps1`) showed the star
  under the selected General with it at 0, after deselecting and reselecting under 0, and after the restore.
  The option covers hover and hold-Space markers only; CA's tour sets it in lessons where nothing is
  selected. The code, its two tests and its mutants are removed. No documented call hides a selected unit's
  marker. `bm:clear_selection()` does (screenshot), and it also removes the green outline, while the
  portrait falls back to the army's General and loses its ability ring. **That trade is the author's call.**
- **Sliding while aiming (source):** while a shot runs the tick does not drive him, but a walk already under
  way kept carrying him under the aim clip. `man_shot` now calls `P.hold` before the aim plays. Test
  `solo_shot_stops_his_walk_before_aiming` (red first); fire-cycle mutants 21/21.
- **Voice lines when moving (source + live call present):** `bm.battle:suppress_unit_voices(true)` on start,
  `false` on stop, as CA's cutscenes do. One-man movement makes no unit order, so the lines are the ambient
  voices the game plays on each start and stop of his walk. All unit chatter is silent in third person. Test
  `third_person_silences_unit_voices_and_back`.
- Verified by screenshot in third person (`zz_tp_view_shot.lua`): no unit flags, the portrait whole, the
  star still there. The author confirmed no hover panel.
- Selftest 117/117; `mutants_cup.py` 12/12, `mutants_fire_cycle.py` 21/21. Bridge loaded with all of it.

## Third hand test: clicks, gun sound, and the marker hunt

- **Why yesterday's probe had no star, flags or panels:** `zz_follow_on.lua` hid the cursor with
  `bm:enable_cinematic_ui(true, false, false)`, which hides the whole battle interface, 3D markers included.
  The pack moved to `SetCursor(NULL)` on 2026-10-13 to keep the portrait and abilities, and the markers came
  back with the HUD. The author chose to keep the portrait and hunt the markers.
- **Clicks selecting other units (source):** orders are off but selection is not. Each tick, if another unit
  is selected, or the controlled one was deselected (a click on the ground), the selection is cleared and the
  controlled unit reselected. Tests `clicking_another_unit_keeps_the_controlled_one_selected`,
  `shift_clicking_another_unit_drops_it_again`, `clicking_empty_ground_keeps_the_controlled_one_selected`;
  `mutants/mutants_select.py` 5/5. The harness's `select_in_ui` now selects and a click deselects the previous
  unit, as the game does; the older mutant sets were re-run green (33, 24, 12).
- **Gun sound (source):** missing since solo shooting began. A scripted `trigger_projectile_launch` plays only
  the projectile's audio (`projectiles.projectile_audio -> audio_projectiles`), and a bullet's has no fire
  event; the bang is the weapon's, `missile_weapons.audio_type -> audio_missile_weapon_types.fire_start_event`
  (Iron Hail: `Battle_Individual_Small_Arms_Hand_Cannon_Fire`; crossbow: `..._Crossbow_Release`, beside the
  bolt's own fire sound). `--gen` writes it as the 4th field of `shots` (303 of 493 ranged types), and each
  shot plays it once with `play_sound(from, new_sfx(event, false, false))`. Test
  `solo_shot_plays_the_weapons_fire_sound_once`; `check_data` pins both events. Not yet heard in game.
- **Marker hunt, not solved.** Probes `tp_sel_diff.py`, `tp_ptr_refs.py`, `tp_ptr_path.py`,
  `zz_tp_marker_chain.lua`. Found a per-unit byte that MIRRORS selection (1 selected, 0 not): battle global
  `exe+0x4479ee0` -> `+0x2f0` -> `+0x100` {u32 count +8, data +0x10} -> entry with vtable `exe+0x3ac95c8` ->
  embedded owner at `+0xa8` (vtable `exe+0x3ac9700`, {u32 count +0xa0, data +0xa8}) -> flag objects (vtable
  `exe+0x3ac9958`), unit pointer at `+0xf8`, byte at `+0xd8`. The walk works from Lua for all four player
  units. **Holding it at 0 does NOT hide a regiment's arrows** (paired screenshots, Iron Hail Gunners); an
  earlier "no star" shot of the General was taken while the author was clicking units, so it proves nothing.
  The per-entity objects with vtable `exe+0x3aaf560` (model at `+0x18`, flag object at `+0x128`, stride 0x160)
  have no byte that follows selection. RTTI is stripped. Neither the unit nor the model points forward to any
  of these within three levels.
- **Ability error seen in the log (not fixed):** `abilities.lua:47 perform_special_ability_ground ... unit '1'
  does not support this special ability`, after `can_perform_special_ability(key)` said yes. The key is not
  logged; which ability the author pressed is needed.
- Selftest 121/121. Bridge loaded with all of it.

## The author's choice: cinematic UI, our own panel

The author chose yesterday's look over the marker hunt: **cinematic UI while looking**, and **the pack's own
panel instead of CA's porthole**. `platform.lua`'s `SetCursor`/`ShowCursor` routes are deleted, and
`main.lua`'s `cursor()` switches cinematic UI on change only (test `looking_hides_the_battle_interface`;
`mutants_cup.py` 16/16; selftest 122/122). While the mouse is freed, CA's interface comes back with the
porthole, and the earlier fixes (tooltips, flags, cup, selection lock) still apply there. Spec §7 and its
rejected list record the reversal; plan 2 (the HUD) now carries a portrait of its own and is created at the
root like the crosshair. Bridge loaded. Look mode is unverified live: the game window was not focused during
the probe, so the pack stayed in the free-cursor view. **Next:** the author's hand test, then plan 2.

## Flags under cinematic UI, lowering the weapon, pinned enemies

- **Flags came back under cinematic UI.** The engine's interface switch brings the unit flags back (CA's
  cutscene library switches unit ids off only after it), so `cursor()` switches them off after every switch;
  the separate call at start went (redundant, a mutant proved it). Test
  `flags_stay_off_across_interface_switches`. **The author confirmed it works.**
- **Sliding and no lowering after a shot.** Measured (`zz_tp_after_shot.lua`, `zz_tp_lower.lua`): after our
  aim (1554, a transition clip) the engine idles him in its shooting stance, `SHOOT_STAND_IDLE_3`/`_1`
  (1440/1438); a lone fire clip without the aim did not (`zz_tp_slide.lua`). `SHOOT_STAND_TO_STAND` (1461,
  in the Iron Hail's set) takes him out of it. Now a finished shot sets `F.raised`, and the first step plays
  1461 as a "lower" phase of the shot (so nothing walks him meanwhile) before he walks; a set without 1461
  walks at once. Tests `solo_lowers_the_weapon_before_walking`, `walking_before_any_shot_does_not_lower`,
  `solo_without_a_lowering_clip_walks_at_once`; `mutants/mutants_lower.py` 8/8. Not yet seen in play.
  `P.anim_slot` is nil during locomotion and plain idles: it cannot show a slide.
- **Enemies pinned for testing** (the author asked): `probes/zz_tp_pin_enemy.lua` takes every enemy unit from
  the AI, moves any within 350 m of the player army out to 400 m, and halts them every second. Re-send it
  after every battle reload.
- Selftest 126/126. Bridge loaded.

## The slide found, the sword clip dropped, the reload no longer holds him

The author: 1461 "is switching to sword not lowering weapon to idle"; "still sliding when switching to melee mode";
"the transition is not instant".

- **1461 is the sword draw.** In `hu1e_blunderbuss_sword`, SHOOT_STAND_TO_STAND plays `shoot_to_combat_idle_01`:
  that unit's plain stance IS the sword (`STAND` = `combat_ready_01`, `STAND_IDLE` = `combat_idle`), and its gun
  stance is the shooting stance. There is no gun-low idle. The lowering phase, `C.lower`, `F.raised` and
  `mutants_lower.py` are deleted.
- **The slide is a latched clip** (`probes/zz_tp_unclip.lua`, three rounds out of a running reload, full-resolution
  screenshot bursts compared for leg pose). Our mask-6 clips set `model+0x284` = 6. When the shot is dropped (the
  mode key) and a walk replaces the command, `+0x284` stays 6 and he moves in the clip's pose: same legs in four
  frames. The engine's native stop does not clear it. `WALK_1` (42) played with mask 0 does, and he walks with a real
  stride the same frame. Walking from the engine's own shooting idles does not slide (`zz_tp_stance.lua`).
- **Not instant:** the Iron Hail's reload clip runs 14 s and nothing walked him until it ended.
- **Fix (source, offline-tested):** a step ends the shot in its reload phase, never in the aim or the firing clip
  (cutting the firing clip would let a held W fire a crossbow about 40% faster). The mode key drops any phase.
  Once a shot has left, the next waits the projectile's `base_reload_time` (`data.lua` `shots[...][2]`, 13 s
  Iron Hail) from the reload's start, so neither a step nor melee-and-back skips the reload; a crossbow's reload
  is its next raise to aim. The first step plays `WALK_1` mask 0 whenever `P.anim_slot` reports a clip, spaced
  0.3 s. Spec §6 item 7.
- Tests: `a_step_after_the_mode_key_mid_aim_does_not_slide`, `walking_from_rest_plays_no_clip`,
  `a_clip_that_keeps_reporting_is_not_queued_every_frame`, `a_step_cuts_the_reload_short`,
  `a_step_does_not_cut_the_aim_or_the_firing_clip`, `a_cut_reload_still_delays_the_next_shot`,
  `the_mode_key_does_not_skip_the_reload`, `the_mode_key_mid_aim_adds_no_wait`,
  `a_crossbow_switching_modes_after_its_bolt_adds_no_wait`. The harness's `P.steer` records a `slide` when it
  starts a walk under a running mask-6 clip and latches it, as measured. Selftest 132/132;
  `mutants_unlatch.py` 21/21; fire cycle 24/24, steering 33/33, cup 17/17, select 5/5. Bridge parts regenerated,
  **not loaded**.
- **The PC crashed** between 8:52 and 8:55, a few minutes after the last probe had ended (third person off, script
  log last written 8:51:52). Bugcheck 0x1A, parameter 0x41792: a corrupted page-table entry, kernel memory that
  nothing in the game process reaches. Minidump `C:\Windows\Minidump\101426-11593-01.dmp`; no WinDbg on the machine.

**Next:** after the game is back, load the bridge (`zz_tp_load_run.lua`), re-send `zz_tp_pin_enemy.lua`, and the
author's hand test: aim then the mode key then W (no slide), W during the reload (walks at once), click again (waits
out the reload).

## Built as a pack and deployed (2026-10-14, evening)

The author chose the pack over the bridge for hand tests from here on. `py tools/build_third_person.py`: selftest
132/132, pack saved to `Modding Files/Modpacks/derpy_third_person.pack`, every file read back (11 Lua, 3 loc rows).
Copied to the game's `data/` (no Workshop item yet), md5 `449f6f2fc1349510be3958064fd1d481` on both.

**Do not send `zz_tp_load_*` while the pack is enabled**: the bridge load starts the mod a second time. Probes
that only read, and `zz_tp_pin_enemy.lua`, are fine.

**Next:** the author's hand test on the pack (aim, mode key, W: no slide; W during the reload: walks at once; click
again: waits out the reload), plus the three unconfirmed fixes (gun sound, selection lock, cinematic look).

**Confirmed on the pack (2026-10-14, 17:50 session):** the author's hand test passed ("works"). `script_log_141026_1750.txt`:
the mod loads cleanly from `script\battle\mod\derpy_third_person.lua`, four third-person spells (46-118 s, 120-186 s,
188-209 s, 214-283 s by the orders lock), and no `derpy_tp: error`, `putting back` or ability line. Debug logging
was off, so no per-action lines.

**Confirmed (author, 17:57):** gun sound and cinematic look work. Selection lock still unconfirmed. Next: plan 2, the HUD.

**Deferred by the author (18:11):** hold left button in melee = charge (CA slots CHARGE / CHARGE_2 / CHARGE_3, rider and fly versions exist). Author: "skip it first, prioritize hud". Open choice when it comes back: animated sprint while held (no engine charge bonus for one man) or a real engine charge order.

## HUD measurements (plan 2 Task 1, 2026-10-14)

Measured in game through the bridge (probes `zz_tp_hud_measure.lua`, `zz_tp_hud_ring.lua`), each folded into
`hud.lua` behind a failing test first. Spec: `docs/superpowers/specs/2026-10-14-third-person-hud-design.md`; plan
and ledger: `docs/superpowers/plans/2026-10-14-third-person-hud.md`, `.superpowers/sdd/2026-10-14-third-person-hud/`.

- **The unit context still answers under the cinematic UI.** The card under `hud_battle > cards_panel` keeps its
  `CcoBattleUnit` id (the uid string); `common.get_context_value("CcoBattleUnit", id, expr)` reads it. UI scale 1.
- **The unit's ability list is `BattleAbilityList`**, not `SpecialAbilitiesList` (that one is a building's and is
  nil on a unit). Per entry: `SetupAbilityContext.RecordKey` (matches `owned_non_passive_special_abilities`
  exactly, in a different order, so slots match by key), `SetupAbilityContext.IconPath`,
  `RechargeTimeRemainingSecs` (0 ready, -1 passive). A mid-cooldown value was not read: Task 10 checks it on screen.
- **`ReloadPercentMax` runs 0..1 and 1 is LOADED**, so a regiment's ring hides at 1.
- **CA's reload ring parts are ids `loading_ring_L1` / `loading_ring_L2`** (capital L; the hierarchy tag is
  lowercase and `find_uicomponent` matches the id). `SetImageRotation(0, radians)`: L1, the right half, 0 to +pi
  fills 12 to 6 clockwise; L2, the left half, 0 to -pi fills 6 back to 12. A screenshot sweep settled it.

Offline after the corrections: selftest 155/155, `mutants_hud.py` 35/35, preview clean at 1600/1920/2560.
**Next:** Task 10, the build (game shut, RPFM open), deploy to `data/`, the in-game screenshot against
`docs/mockups/tp_hud_reference.png`.
