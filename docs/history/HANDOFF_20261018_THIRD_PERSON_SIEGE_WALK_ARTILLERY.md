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
