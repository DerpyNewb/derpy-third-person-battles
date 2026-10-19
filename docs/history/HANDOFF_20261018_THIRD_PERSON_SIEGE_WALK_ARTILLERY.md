# Third person: the siege walk, the gun as the unit, the unit card report, the camera in buildings (2026-10-18 night)

**Current state:** `36c14c58` copied into the Workshop folder (item 3822187184) at 23:39 with the game shut, and
`loadfast_cache_battle.bin` deleted (section 8); **uploaded 23:54** at the author's request (manifest
2791404133276005302, `file_size` 2382006 read back; change note in `PATCH_NOTES_20261018_THIRD_PERSON.md`). It adds the camera
fix (section 4) to `dd336125` (22:15), which is backed up as `Modding Files/Backup/derpy_third_person_workshop_20261018_233900.pack`;
the pack before that is `..._221545.pack` (`8a2e0ab0`). Nothing in `data/`. 418 tests pass; `mutants_round51.py` and
`mutants_round52.py` 10/10 each; 11 anchors re-aimed (section 5). Public repo pushed as `da811c2` (README counts and
CHANGELOG updated).

Continues `HANDOFF_20261018_THIRD_PERSON_SPRINT_FLY_CHARGE_CAMERA.md`. **Overturns its section 8 in one respect:** the
steering point is no longer a fixed 15 m for everyone - 15 m is where it starts and where it goes back to.

The author's requests, in order:

- "on the derpy third person mod in sieges, the unit cannot move normally forward, as if theres a barrier" (it fails
  "everywhere in sieges", fine on field maps) - **fixed**, section 1
- "the uncontrollable unit card problem ... all types of units, once controlled, become like that and cannot be
  controlled a second time" (a player's report, "you should confirm") - **not reproduced**, section 3
- "I tested using the original Cathay grand cannon. I found that I was only controlling the gunners ... When I
  clicked the mouse, all the gunners uniformly started slashing with swords or kicking with their legs. This happens
  with all types of artillery" - **fixed**, section 2
- "why cant the camera stay on the character ? its still colliding with buildings" - **diagnosed, open**, section 4

The game was launched from the mod list (`Warhammer3.exe used_mods.txt;` in the install folder), the source loaded over
the Workshop pack with `py tools/build_third_person.py --bridge`, and every picture taken with `common.take_screenshot`
over the bridge - never a desktop capture, which got the author's own windows.

## 1. The siege walk

**Cause.** Section 8 of the previous handoff moved one man's steering point from 3 m to 15 m ahead. In a siege map
the point 15 m ahead often lies inside a wall, a gate or a building. The pathfinder finds no way there: his path state
`+0x710` goes to 7 (set in `exe+3077009`). Our walk is built from the cave's parameter block with no path of its own
(`+0x88` of the command is null), and a walk with no path ends itself in its update `exe+3262850`: done byte `+0x10` of
the command (`+0x340` of the man) and `+0x30` (`+0x360`). A walk that has a path re-plans instead (it sets `+0x91`,
which leads to `FUN_143260f14`). The ended walk **stays on him** (vtable `walk_b`, `exe+3ae2400`), and the cave, finding
his own walk there, only rewrites its point in place - so nothing moved him again until the keys let go.

Measured in a dwarf hold (`probes/zz_tp_siege_walk.lua`, a held forward key across headings): west 0.19-0.36 m in 4 s
at 15 m, 8.7 m at 3 m. The Vault Sweepers stood at z -338.3 for 6 s with W held.

**Fix.**
- `platform.lua` `P.walk_ended(m)`: his command is `walk_b` and its done byte is set (the mount's, for a rider).
- `move.lua`: on an ended walk, `P.hold` (the engine's stop swaps it out, so the next steer builds a new walk) and the
  next point is half as far, down to `LEAD_MIN` 1.5 m. At the minimum it is retried every `LEAD_RETRY` 0.5 s.
  `LEAD_BACK` 2 s with no end puts it back to `STEER_LEAD` 15 m. Letting go of the keys resets it as well.

**Live:** Vault Sweepers with the shipped code, 19.4 m in 10 s across the same hold; without it, stuck.

Tests: `an_ended_walk_is_read_off_his_own_walk` (patched platform: both vtables, the byte at `+0x340`, a horse),
`a_walk_the_engine_ends_is_built_again_nearer` (15, 7.5, 3.75, 1.875, 1.5; a retry at the minimum only after 0.5 s;
15 again after 2 s, or when the keys are let go).

## 2. Artillery: the click is the gun's

**Cause.** `F.ranged` excluded artillery (`and not F.arty`), so a click went to `C.melee`, which played ATTACK clips
on every crewman: a crewman's parent is his gun, the gun has no swing, and the crew fallback played his own. The
charge (Shift) and jump (E) did the same.

**Fix.**
- `main.lua`: `F.ranged = E.can_shoot()` for guns too. `F.can_charge` and `F.can_jump` are false for artillery.
- `combat.lua`: a gun's click is `order(true, F.unit:missile_range())`, the attack order on the enemy nearest the
  crosshair within the gun's range (`pick_target(reach)`). No melee click for a gun ("a gun out of shot is nothing"),
  and the charge's run is never played on its crew.
- `hud.lua`: no attack button for a gun; the fire button shows for it.
- The mode key still hands the gun to CA's Manual fire, unchanged.

**Why `attack_unit` and not ground fire.** Measured with fire at will off (`probes/zz_tp_arty_order.lua`):
`uc:attack_location` on ground makes a gun **attack-move to the point** and does not fire. The first run "fired" only
because fire at will was on (`zz_tp_arty_ground.lua`, misleading). `uc:attack_unit` fires (`zz_tp_arty_attack.lua`).
Consequence: **no ground fire for a gun** - a click with no enemy in range near the crosshair does nothing.

**Live:** the great mortar through the pack's own click and frame loop (`zz_tp_arty_click.lua`): ammo 12 to 10, no
crew clip played. The flame cannon showed the ground-order attack-move.

Tests: `an_artillery_click_fires_the_gun_at_the_crosshair` (enemy at 300 m, range 400: one `attack_unit`, no
`attack_location`, no play), `an_artillery_crew_never_swings` (no swing, jump, charge or charge attack),
`artillery_mode_opens_manual_fire` now checks `F.ranged`. `artillery_crew_keep_their_own_melee_clip` is gone;
`a_war_machine_crew_keep_their_own_melee_clip` covers the crew fallback (`combat.lua` line 252, whose comment still
says "artillery"), which is still live for a tank's crew.

## 3. The unit card report: not reproduced

Real input throughout:
- `probes/tp_mouse.ps1` (new): a real click at a fraction of the client area, refusing unless the game is in front.
- A card is clicked at its own position: the card is the `cards_panel` child named by the unit's `unique_ui_id`, and
  its `Position()`/`Dimensions()` are UI pixels against `core:get_screen_resolution()` (1600x900 here).
- The ground order is a right-click at the screen centre after `probes/zz_tp_card_order.lua` "aim" puts the camera
  over the unit, looking at the ground ahead (`_G.TP_CO_AHEAD`, negative for behind). "read" reports the ordered
  position, `is_script_controlled`, `is_player_controlled` and the selection.

Two traps, each cost a false "refused":
- **The cursor must settle.** With the press 150 ms after `SetCursorPos`, a right-click registered nothing, even
  for a unit never in third person. 400 ms, a 2 px move, 400 ms, then the press: it registers.
- **A right-click on a wall or gate face is not an order.** Twice the screen centre was a gate. Take a screenshot
  before reading a refusal.

| Unit, class | Before the order | Order (ordered point before -> after) |
|---|---|---|
| Longbeards (2), never in third person | - | 56.5,-325 -> 44.2,-324.4 |
| Longbeards (2), one man | F2, W 3 s, F2 | 43.7 -> 31.5 |
| Longbeards (2), one man, again | F2 a second time: on, walked 3.4 m; F2 | card click: 31.2 -> 18.7 |
| Longbeards (3) | `change_behaviour_active("defend")` on and off, no `release_control` | card click: -380.8 -> -349.2 |
| Longbeards (3), played whole (`one_man` forced off) | F2, W 3 s, F2 | card click: -354.4 -> -308.7 |
| Grimm's gyrobomber, unit of one, flying | F2, W 3 s, F2 | card click: 305.6 -> 323 |
| Flame cannon | two sessions | card click: 178.1 -> 297.5 |

`is_script_controlled` false and `is_player_controlled` true after every stop. Every `uc:` order the pack gives is
followed by `release_control()` except `M.stop`'s defend restore, and that one leaves the unit taking orders (row 4).
The guard posted to the cave is one-shot (exchanged with 0 as it is read). The Workshop build differs from the source
only by today's edits, none of which touch orders.

**Not covered:** cavalry, a monster played as one man, a session ended by "unit lost" or by an error (`E.fail`), one
ended through Manual fire and then F2, multiplayer.

**What to ask the author:** what the player sees (a greyed card, clicks ignored, the unit doing something else),
which unit, how they ended third person, and their script log.

**One candidate, not confirmed as the report:** a unit of one steered by the keys keeps its old ordered position,
and after F2 the engine walks it back there. The gyrobomber went 24 m back to 305.6 on its own. A player could read
that as the unit ignoring them.

**Seen in passing:** the 18:14 log has `derpy_gp_landship_3_ror` going on and off with "unit lost" seven times in two
seconds: F2 on that landship does nothing. Probably the first model's HP reads 0 for that vehicle
(`main.lua` `tick`, `P.model_hp(single) <= 0`). Not looked into.

## 4. The camera in buildings: fixed (an exe patch while on)

Measured in the hold (`probes/zz_tp_watch_siege.lua`, the Hammerers, every 0.25 s):
- The rig asked for the eye 1.9-2.3 m above him; the engine put it 20.5-21.6 m up, over the gatehouse roof.
- Seeing the eye that far off, the rig pulled its boom in to 0.1.

`cam:change_height_range(0, 100)` is already set at start. CA's camera API (`battle/battle_camera.html`) has
`move_to`, `change_height_range` and `enable_functionality` (keys, mouse, edge); none is a collision switch.

**Cause (build 6acec6f4).** Camera system S = `*(*(*(exe+4480da0))+0x468)+0x64558`, the current mode M = `*(S+0xc08)`
(vtable `exe+3ab9498`). The floor `exe+2ebf734` (its sibling `exe+2ebf9e4` has the same shape) computes
`eye.y = B + max(A - B + min, h)` = `max(A + min, B + h)`:
- A = vslot `0x2e0`, `exe+2ee841c`: a raycast under the eye (`exe+2ee1240` on `M+0x438`) that counts roofs and walls.
- B = vslot `0x2f0`, `exe+2ec2710`: the terrain heightfield.
- min = vslot `0x2c8`, max = vslot `0x2d0`; h = `M+0x450`, clamped into [min, max] at the top.
Both A and B take (`rcx` = the mode, `rdx` = &(x, z)) and return a float in `xmm0`. All 18 camera vtables hold the
pair side by side (`+0x2e0`, `+0x2e8` = `exe+2edd344`, `+0x2f0`); `exe+2ea3450` and `exe+2ea4b24` call A directly.

**Measured** (`probes/zz_tp_cam_sweep.lua`: third person off, `move_to` an eye 2 m over the road every 5 m along x -60,
z -370 to -420, through the gatehouse, `change_height_range(0, 100)`):
- unpatched: +4.3 in the open, +18.7 to +24.0 under the gatehouse;
- one call site redirected (`exe+2ebf916`, `FF 90 E0 02` -> `F0 02`): **not enough**. The author played with it in
  (Thunderers, a Gyrobomber) and `probes/zz_tp_cam_lift_watch.lua` logged 57 lifts in 284 samples, up to 3.3 m, boom
  at 0.1. Other callers of A still lifted;
- a 5-byte `jmp exe+2ec2710` at A's entry (`48 8B C4 48 89` -> `E9 EF A2 FD FF`): **+2.0 at all 11 points**. From 2 m
  inside the gate passage the in-game screenshot is level, the passage walls either side.
So the low-eye lift in the open (memory `wh3-script-camera-lifted-near-ground`) was the same raycast.

**Fix.** `platform.lua` `P.terrain_floor(on)` writes that jump through `mr.patch` (only over the bytes it expects). The
rel32 is computed from the BUILDS row's `cam_collide` / `cam_terrain`, with every step exact in float32. `main.lua`
turns it on in `M.start` (`F.floored`; `E.once("floor")` if there is no row for the build) and off in `M.stop`;
the platform takes it out as it loads, for a battle left with it in. ponytail: while it is in, every battle camera
ignores buildings; only third person's moves while it is on. The rig's boom pull-in (`LIFT_TOL`) stays for builds
with no row. Trade-off: nothing now keeps the eye out of a wall he backs against.

**Not yet run on the deployed pack:** F2 near a building. The hand patch measured above writes the same bytes to the
same address (`M.split` gives `0x2ee0000 + 0x841c`, the route `P.gate` takes live), and the harness checks the jump's
target, but no F2 session has run on the pack itself yet.

## 5. Tests and mutants

- 418 pass (414 + `a_war_machine_crew_keep_their_own_melee_clip` + three for the terrain floor; the floor is also
  checked in `the_camera_floor_is_lowered_only_while_on`).
- `probes/mutants_round51.py`, 10 mutants over sections 1 and 2, all killed.
- `probes/mutants_round52.py`, 10 mutants over section 4, all killed. `u = u / 256` in the byte loop is equivalent
  (`string.char` rounds to nearest, and this jump's fractions all round back), so it is left out with a note.
- Re-aimed at today's edits, all killed with no stale anchor: `mutants_round32` (the charge-run gate; the crew-clip
  mutant now names the war machine test), `mutants_round34`, `mutants_round45` (the steer's `lead`),
  `mutants/mutants_unlatch` (`STEER`).
- Re-aimed but in sets with older stale entries: `mutants/mutants_actions` (artillery's swing, `can_charge`, the HUD's
  fire button), `mutants/mutants_round16`, `mutants/mutants_t9` (`d < reach`), `mutants/mutants_t8` (`man_hold`).
  `mutants_actions` keeps its three older entries, the same three the previous handoff counted.
- An anchor counted as staled today when it matched once in the pre-edit pack's Lua (the Workshop backup above) and
  not once now; every set was checked that way.
- **All 65 sets, 805 mutants:** 19 survived, 36 stale. Every survivor predates today: 18 survive the same way on the
  pre-edit Lua (rerun in a copy of the source with the backup's Lua put back), and the 19th, `can_charge = true` in
  `mutants_actions`, is one of the three the previous handoff counted. The previous count was 38 stale.
- After the sweep, all 14 source files are byte-identical to the deployed pack.

## 6. Probes added (test scaffolding, never shipped)

All in `Modding Files/source/lord_control/probes/`:
- `zz_tp_watch_siege.lua`: read-only. Position, the point asked, his command (`walk` / `walk_a` / other), the walk's
  point, paths, the fresh flag, speed, the camera asked/got/off/boom, ground, clip, melee and m/s.
  `_G.TP_WG_LEAD` overrides the lead; `_G.TP_WG_RAW` dumps dwords `0x338`-`0x3cc`.
- `zz_tp_siege_walk.lua`: a held forward key across headings (`TP_SW_IDX`, `TP_SW_YAWS`, `TP_SW_HOLD`).
  `TP_SW_NOFIX` stubs `walk_ended` to false, for the A/B.
- `zz_tp_arty_order.lua`, `zz_tp_arty_attack.lua`: `attack_location` and `attack_unit` with fire at will off.
- `zz_tp_arty_click.lua`: the pack's own click through the frame loop (`TP_AC_IDX`, `TP_AC_HOLD`, `TP_AC_AT_ENEMY`).
- `zz_tp_arty_ground.lua`: misleading (fire at will on); kept so nobody repeats it.
- `zz_tp_card_order.lua` and `tp_mouse.ps1`: section 3.
- `zz_tp_cam_sweep.lua`: an eye 2 m over the terrain along a line, the height it got (`TP_CS_X`, `TP_CS_Z0`,
  `TP_CS_Z1`, `TP_CS_STEP`; third person must be off, its rig overrides `move_to` every frame).
- `zz_tp_cam_lift_watch.lua`: read-only. While third person is on, counts samples and logs every lift over the rig's
  own `LIFT_TOL` test, and every boom pulled in.
- `zz_tp_trace_play.lua` (attack clips with a traceback, and clicks), `zz_tp_gun_click_watch.lua` (ammo, swings,
  blocks for 5 s), `zz_tp_watch_manual.lua` (on / Manual fire view / selection / camera jumps), `zz_tp_trace_mode.lua`
  (the mode key's `P.pressed` and `C.mode`): section 8.

## 7. Open

- F2 near a building on the deployed pack (section 4, last paragraph).
- A gun's click on an enemy too close to shoot still gives it the attack order (section 8); not changed.
- The unit card report (section 3): waiting on the author's description.
- The landship's "unit lost" at F2 (section 3).
- No ground fire for a gun (section 2): a click needs an enemy in range near the crosshair.
- Carried over from the previous handoff's section 6, untouched today.

## 8. After the 22:15 deploy: the author's reports

"is it deployed to workshop now? if so the artillery in melee still makes all the crew do a melee attack", "switching
to range is also inconsistent and the camera switches unit to unit".

- **The author's game ran the old code.** The load order has the loadfast script cache (Workshop 3816496233). It keys a
  Workshop item on Steam's acf record (size, timeupdated, manifest), not the pack, so a local copy into the Workshop
  folder left the cached pre-fix Lua running. Deleting `loadfast_cache_battle.bin` (backup in
  `Modding Files/Backup/loadfast_20261018/`) made `loadfast_log.txt` say "cache rebuilt" and the new code ran. Memory
  `loadfast-cache-hides-a-local-deploy`: delete the cache after every local deploy.
- **The crew in melee.** On the new code, a click on a flame cannon with two Skaven units on it (`zz_tp_engage.lua`)
  played no attack clip through `P.play` (`zz_tp_trace_play.lua`). The crew fighting enemies on the gun is the
  engine's own melee; `zz_tp_gun_click_watch.lua` saw it before any click. Not changed: a click on an enemy too close
  to shoot still gives the gun its attack order.
- **"The camera switches unit to unit"**: F2 6 of 6 kept the unit selected (`zz_tp_watch_manual.lua`), no camera jump
  to another unit. Not reproduced.
- **"Switching to range is inconsistent"**: Thunderers 6 of 6. The gun's mode key (Manual fire): 3 of 8 did nothing in
  one untraced run, 16 of 16 worked traced (`zz_tp_trace_mode.lua`). Not reproduced under trace.

## 9. 2026-10-19 morning: invincibility frames, units of one (built, not yet live-tested)

The author: "theres no invisibility frames on some animations (where the unit doesnt take damage after a certain". Asked
which: the charge attack, the jump attack (E) and the "defense animation when being hit"; regiments: units of one only.

- `combat.lua` `C.invincible(man)`, called each unpaused frame from `main.lua` with `single` (nil for one man of a regiment
  or a regiment played whole). It turns on `F.uc:set_invincible(true)` while the lock carries `guard` (set by `C.jump` and
  `C.charge_attack`, so from the key press to the lock's end), or while his body or mount shows one of the hit clips. The
  hit clips (`reeling`, 9.0 ids from AssetEditor's `Warhammer3AnimationSlots_9_0.txt`, id = line - 1) are
  HIT_REACTION_STAND and MELEE_BLOCK 368-387, DEFEND 474-483, FLY_DEFEND 504-513, HIT_REACTION_COMBAT_READY/SHOOT_STAND/SHOOT_READY
  1217-1246, RIDER_DEFEND 1921-1930, RIDER_FLY_DEFEND 1951-1960 and RIDER_HIT_REACTION_STAND/SHOOT 2202-2221. KNOCKBACK,
  KNOCKDOWN and the get-ups are left out.
- Each switch is followed by `release_control`, as CA's `script_unit:set_invincible_for_time_proportion` does for a
  player-controlled unit. An invincibility already on (`unit:is_invulnerable()`) when a window opens is not ours and is
  left alone. `M.stop` turns ours off.
- The whole-unit switch is why regiments are out: on one man it would cover all his men.
- Tests: 8 new, 426 pass (5 failed before the code). `mutants_round53.py` 19/19. Build `8e1ea16e` in Modpacks, verified
  14 files; it differs from the Workshop copy only in `combat.lua` and `main.lua`. The game was running (started by the
  author at 08:21), so the deploy waits for it to close: backup to `Modding Files/Backup/pre_tp_iframes_20261019/`, then
  the copy and the loadfast cache.
- **Unmeasured:** whether `is_invulnerable()` reports a `set_invincible` (if not, a battle script's own invincibility would
  be switched off at a window's end); whether HP holds still or only death is prevented; which of these clips a lord or
  monster actually plays when hit; and how much of a long melee a lord ends up covered (DEFEND plays on every blocked
  blow).

## 10. 2026-10-19: one man no longer holds his regiment's fire (built, not yet live-tested)

The author: "controlling a ranged unit disables the rest of the battalions ranged option too". The logs (07:22-07:59,
four battles, many "one man, shooting alone" sessions, no errors) do not record fire at will, so they could not show it;
the code did: `M.start` called `F.uc:fire_at_will(false)` on the whole unit for every unit with a missile range, one man
of a regiment included - a regiment-wide order, against the 2026-10-15 ruling that one man gives his regiment no orders.

- `main.lua` `hold_fire(unit)`: a unit played whole holds its fire (and gets the player's setting back at the end, as
  before); with `F.model` set it does nothing. Called at the start and when the regiment drops to its last man (played
  whole from there).
- Tests: `one_man_leaves_his_regiments_fire_setting_alone` (no `uc:fire_at_will` at all through his shot; played whole
  still holds); `one_man_regiment_with_shots_holds_fire` deleted (it pinned the bug); `stop_restores_past_a_failing_step`
  moved to a regiment played whole; three checks reworded. 426 pass. `mutants_round54.py` 6/6. Build `9c58104c`.
- **Unmeasured, and the first thing to check in game:** whether the man played now fires on his own when his regiment
  fires at will. Nothing per-man stops it: `P.guard` stops four commands (walk_a, walk_b, a move, the melee attack) and
  `P.disarm` blanks melee attack slots only (`is_attack`: 454-463, 484-500, 1901-1950), not the fire clips. If he does,
  the per-man route is to blank his fire slots in the disarmed fragment copy too and arm him for his own shot.

## 11. 2026-10-19 noon: live checks (Grand Cathay vs Skaven custom battle, fort map)

Launched from the mod list on the deployed `9c58104c`; the fixed source then loaded with `build_third_person.py --bridge`
(`6acec6f4`). The author was at the desktop (Firefox, then Steam in front), so after one real-key run lost the front,
every start, swing, jump and charge went through the pack's own functions over the bridge (`E.main.start`,
`E.combat.melee`, `.jump`, `.charge_attack`), with no keys. Game closed and test settings reverted afterwards.

**Setup lessons.** A controller's `halt` or `attack_unit` on an AI unit does nothing lasting: every Skaven unit was in the
fort within a minute. `uc:take_control()` first (as CA's intro battles do) held all 20 (`probes/zz_tp_fire_setup.lua`,
`zz_tp_engage.lua` both fixed). The getter `unit:is_behaviour_active("fire_at_will")` exists and lags one tick.

**Section 10 was not the fix.** On `9c58104c`, one man of the Dragon Guard Crossbowmen: `held` false, yet the regiment's
fire at will read false from the first frame and its ammo stood still for 25 s (50 bolts per 10 s before); it stayed off
after the stop. Bisected with third person off: `uc:fire_at_will(true)` then `uc:halt()` - off a tick later, silent;
`change_behaviour_active("defend", true)` - left on, still firing. `M.start`'s `F.uc:halt()` (and its defend) ran for
one man too. **Fixed:** both only when `not F.model`. The harness's `halt` now turns fire at will off as the engine does;
`one_man_leaves_his_regiments_fire_setting_alone` failed on the old code, now also asserts no halt or stance;
`solo_start_cancels_the_existing_attack_order` deleted (it pinned the breach); `f2_cancels_existing_movement...` keeps
its regiment as a regiment played whole. 425 pass. `mutants_round55.py` 4/4.
Live on the fix: 108 bolts in 25 s with one man played, fire at will on throughout and after.
**But the man played now fires on his own:** SHOOT_READY_TO_AIM_LEVEL 1554 / FIRE_LEVEL 1557 in 34 of 108 samples with
no clip from the pack (the halt had silenced him with everyone). The author's call: ship as is, or first blank his fire
slots in the disarmed fragment (section 10's route, unmeasured). **Not built or deployed.**

**Section 9, invincibility, on Xian Longma (a mounted unit of one, `str_xian_longma`, in melee with two regiments):** the
jump (x2) and charge attack windows opened (`ours` true, about 2 s each), `unit:is_invulnerable()` follows our switch one
tick later, and his hit points held still through all three (24 samples, 0 lost; 136 outside lost 8%). **No hit-reaction
window ever opened**: none of the `reeling` clips on him or his mount in 32 s, and across 341 men in melee about 2,400
samples showed one (DEFEND_2); `P.anim_slot` reads COMBAT_IDLE_1-9 (439-447) nearly all the time. The "defense animation
when being hit" trigger is close to inert as built; which clip the author means is the open question.

**Player reports (Workshop comments, 2026-10-19), confirmed, not fixed** (the author: "confirm and verify first"):
- "10 sets of combat animations ... left mouse cycles 4, right another 4, 2 sets cannot be triggered": `combat.lua`
  `SLOTS_LMB` = ATTACK_1-4 (454-457), `SLOTS_RMB` = ATTACK_5-7 (458-460); ATTACK_8-10 (461-463) are never played, and
  454-460 is hard-coded again in `swing()` (the air fallback, the mount and flying remaps). Right click is 3, not 4.
  Live, Xian Longma (rider ATTACK_1-8 and 10, mount ATTACK_1-3): left played the mount's 1-3, right played ATTACK_1
  four times of four - a mount without the slot falls back to 454 (line 258).
- "turned the UI off mid transformation and the HUD stayed off for the rest of the match" (Yuan Bo): **not reproduced.**
  The plain dragon-form cast through the pack works (off at the cast, the dragon taken over 7 s later, HUD and portrait
  shown). Candidates: `hud.lua` counts part failures for the whole battle (`errors` is never reset, three turn the HUD
  `off` "until this battle ends"; logs from 2026-10-17 show exactly that after a transform), and in the gap third person
  is off, so P is the game's pause and K CA's own interface toggle. Needs real K and P presses during the 5 s wind-up.

**Scope checks (SCOPE_20261019_THIRD_PERSON_UNIT_BARS section 6):** `unit:highlight(true)` drew nothing in the 3D
scene; `unitcontroller:highlight(true)` draws a marker under every man, **red on an enemy, green on ours**, kept after
`release_control()` (ours back to the player, the enemy back to the AI and moving). The banner and pin checks are
UI-layer, which the in-game screenshot cannot show: still open.

## 12. 2026-10-19 afternoon: "fix all" (deployed to the Workshop folder at 14:01, not uploaded)

The author: "fix all" - the four findings of section 11. Built, live-checked in a second custom battle (Grand Cathay vs
Skaven, test settings, fixed source over the bridge, real keys with the desktop idle), 431 pass, `mutants_round56.py`
19/19 (and round 55 still 4/4), packed, read back and copied into `3822187184` (old copy in `Modding Files/Backup/`).

- **One man's own fire.** `P.disarm(man, shots)`: one man of a regiment points at a copy of his fragment with his shot
  slots blanked as well as his attacks (`platform.lua` `is_shot`: 1547-1599, 949-952, 2104-2116; one copy per kind, keyed
  `+shots`). He is armed through his own shot (`F.shot` in main.lua's arm test), and `P.play` unpoints for a shot clip as
  for a swing. A unit of one keeps his shot clips (the engine's own order fires him). Live: 1 of 63 samples showed a shot
  clip, the first, taken mid-volley; his own click played 1554/1548/1557.
- **Attacks 8-10.** One list, ATTACK_1-10; the clips he has are halved in order, left button first (ten: 1-5 and 6-10;
  seven: 1-4 and 5-7; five: 1-3 and 4-5; two: 1 and 2; one: both play it), each button on its own count. A mounted man's
  list is his mount's when the mount has any attack clip (the engine plays mounted swings on the mount). The old fallback
  to ATTACK_1 for a clip the mount lacked was dead once the mount gives the list, and is gone. Live: Yuan Bo left
  454-457, right 458-460; Xian Longma flying left 494/495, right 496.
- **The HUD after a transformation.** Not reproduced with real K mid wind-up or F2 in the gap. Fixed defensively:
  `H.show(true)` resets the part-error count, so a session starts whole (three errors used to turn it off for the
  battle); and a session begun before the unit's card exists looks for the card every `CCO_EVERY` and starts the HUD
  over when it comes. Caveat: `Visible()` may not reflect CA's K layer, and the in-game screenshot shows no UI. F2
  pressed during the wind-up takes over the OLD form; the new one is taken after.
- **Hit-reaction invincibility.** The engine plays no DEFEND or hit reaction on a unit of one in melee (Yuan Bo: 9 blows
  in 20 s, all under his swings or no clip; in third person he stands between orders). A blow on a unit of one standing
  idle (no move key, no swing, shot or lock of ours) now plays his DEFEND_1-10 in turn (FLY_DEFEND in the air, else
  HIT_REACTION_STAND), mask 6, on the body that carries his clips, at most once per `REACT_GAP` (6 s, a constant). The
  existing window covers it. Live on Yuan Bo: DEFEND 474/475/476 at 7.2, 13.4, 22.4 s, about 2.8 s invincible each, 0
  hit points lost inside the windows, 53 outside.

Tests added: `one_man_points_at_a_fragment_with_no_shot_clips_either`,
`one_man_is_kept_from_his_regiments_volleys_and_armed_for_his_own_shot`, `both_buttons_together_reach_every_attack_clip_he_has`
(with a left/right interleave), `the_hud_comes_back_whole_with_the_next_session`,
`a_new_form_taken_before_its_card_gets_its_hud_when_the_card_comes`, `a_blow_on_a_unit_of_one_standing_idle_plays_his_defend`.
`mounted_swings_use_rider_slots` now gives the rider more clips than the mount (it passed with the mount's list removed).
Probes: `zz_tp_watch_fire_guard.lua`, `zz_tp_hit_watch.lua`, `zz_tp_hud_watch.lua`.

Open: the author's call on `REACT_GAP`, and whether DEFEND is the clip meant by "defense animation when being hit".

## 13. 2026-10-19 late afternoon: ranged attacks on the left, unit bars and side markers (deployed 15:41, not uploaded)

- **A ranged unit's attacks all on the left button** (the author: "ranged units can only use the left button"). The
  right button is a shooter's mode key (`C.mode`), so the halving applies only while `E.can_shoot()` is false; out of
  ammo the right button swings again and the clips are halved. `a_ranged_units_left_button_has_every_attack_clip`.
- **A health bar over every other unit, in its side's colour** (option B of `SCOPE_20261019_THIRD_PERSON_UNIT_BARS.md`).
  Nine generated layouts `ui/derpy_tp/bar_1..9.twui.xml` (`gen_third_person_hud.py` `BAR`, `build_bar`, `check_bar`):
  CA's banner bar, 40x10, black edge and `#3B3B3B` well, the loss behind in `#AA0000` (`ContextFillBar` on
  `DelayedHealthPercent`), the fill on `HealthPercent` coloured by `ContextColourSetter` on `AllianceColour`, the base
  hidden by `ContextVisibilitySetter` on `IsVisible`, the pin `ContextWorldSpaceComponent` on `CcoBattleUnit.Position`
  with `offset_y` = the lift (2.5 to 37 m: a unit takes the lowest at least its body height + 0.7, `data.lua` bodies).
  hud.lua makes one per unit (8 a refresh, every 0.5 s) in `bars`, the HUD's FIRST part, so the panel draws over them;
  hides the played unit's, a dead one's and one gone from its army's list. MCT "Health bars", on.
- **CA's markers under every unit the player does not command** (option C): `unitcontroller:highlight(true)` then
  `release_control()`, one cached controller per unit, an enemy only while `is_valid_target()`; never a controller on
  a player's unit; all off with `H.show(false)` (third person off, or the interface hidden). MCT "Markers under enemies
  and allies", on.

**Live (Grand Cathay vs Skaven, fort map, 720p):**
- **First run, a bug: one bar, at the screen's corner.** `_G.cco` is nil in battle. CA's context constructor
  is a callable table in the script environment, `core:get_env()`, which every pack module runs in. hud.lua shadows
  the name with its own `cco(expr)`, so it now takes `local context = cco` at file scope. The harness had passed
  `_G` as the script environment, which is why the tests stayed green. It now passes `H.env`, which holds `cco`
  while `_G` does not. Mutant round 57 has that exact bug, and it is killed.
- **Bars, on the fixed source:**
  - On-screen bars stand where the unit's lifted position projects, within 2 px (984,373 against 983,375). Later,
    with units and the camera moving, the gap was up to about 25 px.
  - The engine hides a bar whose unit is off screen or behind the camera, and does not refill a hidden one.
  - Fill widths: 38 of 40 px at 95%, 34 at 85%.
  - Not measurable: the drawn colour. `get_context_value` gives nil for a Colour value, and the screenshot has no
    UI layer.
- **Markers:** an A/B pair of in-game shots from one paused camera. A bright red marker sits under every man of the
  enemy regiments in view, none under ours, and none after `H.show(false)`.
- **Not seen:** a friendly AI ally's colour, either bar or marker. The battle had no ally.

432 + 2 tests = 434 pass; round 57 16/16 (round 56 21/21 with the ranged pair). Preview: `py
tools/preview_third_person_hud.py --bars` draws the three sides at three health levels from the shipped bar layout
(`.skilltree_cache/ui_preview/tp_bars_<w>.png`), colours from CA's `ui_colours` (ours `#A2EC17`, ally `#68CEFF`, enemy
`#FF2D2D`). Probe: `zz_tp_bars_read.lua` (each bar's box against the projection, fill against health).

Open: the author's eyes on the bars (colour, size at the third-person distance), and an allied army's colour.

## 14. 2026-10-19 evening: the markers on Alt, bars only near him (uploaded 17:17)

- **The markers on a key** (the author: "show the ally/enemy guide while holding/ toggle Alt, configurable using mct").
  New action `guide`, default Alt (`keys.lua`, 29 actions); `F.guide` follows the key held, or a press switches it
  (MCT "Hold to show enemies and allies", on). hud.lua answers a change at once, not at the next 0.5 s refresh. With
  Alt as the guide key, CA's Alt shortcuts on the pack's keys are off while third person is on (`K.game_alt`, read
  from `default_keys.xml`: Alt+M music, Alt+0 and Alt+1-6; Alt+X and Alt+K are on none of its keys).
- **Bars only near him** (the author: "currently is clogging the scene ... by default only near the character ... on
  all the time or activatable using alt"). MCT "Health bars": Always (default), With the markers key, Never; "Health
  bar distance" 40 m (10 to 1000; 1000 is every unit). Measured from the man played when he plays one man of a
  regiment, else from his unit.
- **A bug the 15:41 build shipped, found live: the engine owns a pinned component's own visibility.** It re-shows it
  every frame while it is on screen. A probe hid one pin and showed another, and both were back 2 s later. The
  first live read of the distance limit showed bars on units 300-500 m off and none on the units beside him. So
  section 13's hiding of the played unit's bar, a dead unit's, and the "Health bars" off switch never worked in game
  either. The layout is now `root > derpy_tp_bar > pin > base`: hud.lua shows and hides the plain `derpy_tp_bar`, and
  the callback sits on `pin`. `check_bar` refuses a callback on the top component (selftest break
  `_pin_on_top`, the shipped shape). The harness now resets a pinned component's visibility every frame, as the
  engine does; the two bar tests fail on the old layout and pass on the new.
- **Live, on the fixed build:** bars on exactly the units within 40 m (5, 9, 11, 18 and 29 m), none at 41 m, none on
  the played unit.
- **Not done: Alt with real keys.** The first battle ended before the Alt test. In the second, someone was playing
  (desktop idle 0 s, F2 and a dragon's jump attack in the log), so no keys were sent and the game was left running.
  A 90 s passive watch saw no Alt press. Still open: Alt held and pressed in game, and whether Alt alone stalls the
  windowed game.

436 tests (`a_bar_shows_only_near_the_man_played_and_with_the_guide_setting_only_with_the_markers` new); round 57
31/31, round 56 21/21. Build `adeef3b0` in the Workshop folder. Earlier builds are in `Modding Files/Backup/`: 15:41's
`8001998f` as `derpy_third_person_20261019_162116.pack`, and 16:21's `24b8f129` (the one with the bug) as
`..._164530.pack`. Test preferences reverted once the game was shut.

**The author tested it in game ("works") and asked for the upload.** `adeef3b0` went up at 17:17 through the steamworks
binding (`updateItem` with the content folder and change note only): Steam log "Uploaded new content ( ManifestID
6286053446665096809 )" then OK; `GetPublishedFileDetails` reads `file_size` 2461631, the pack plus its preview, tags
unchanged. All 32 derpy Workshop packs hashed the same before and right after (Steam's re-sync comes at its next poll,
so that is not yet proof). Change note: `PATCH_NOTES_20261019_THIRD_PERSON.md`. Public repo pushed as `8b8671d`: the
nine bar layouts let through beside `hud.twui.xml` (`OURS`, and the repo's `.gitignore`), the bridge's generated
`zz_tp_load_N.lua` parts dropped from the manifest and the repo, the scope doc and both patch notes in `HISTORY`;
README (it still said "not yet on the Steam Workshop") and CHANGELOG updated, 436 tests, 371 probe scripts, 72 sets /
896 mutants.
