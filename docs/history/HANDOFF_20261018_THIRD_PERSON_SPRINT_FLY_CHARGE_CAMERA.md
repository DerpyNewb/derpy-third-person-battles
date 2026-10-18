# Third person: the sprint for units of one, the fly charge, the camera (2026-10-17 late - 2026-10-18)

**Current state (end of 2026-10-18):** deployed `8a2e0ab0` to `data/` (section 12); 412 tests, all pass; mutation
rounds 45-50 all killed; still open, section 6. Sections 1-6 are the morning's work, 7-12 the day's later requests,
each with its own deploy.

Continues `HANDOFF_20261017_THIRD_PERSON_RELOAD_AND_TRANSFORM.md` (its section 10, the mailbox, is what this builds on).
Deployed `bd383804` to `data/` at 09:20 with the game shut, same 18 files as `b240e792`; the pack before is
`Modding Files/Backup/derpy_third_person_20261018_091714.pack`. Tests 395, all pass; round 45, 18 mutants, all killed.

The author's morning requests, in order:

- "attacks are triggering twice when in battle and in groups of enemies" - **not reproduced**, section 4
- "can thje camera center be at the character?" then "center when melee, shoulder either left right or top on
  options, right as default" - done, section 3
- "disable charge when flying", then "is there acharge run for flying units? charging belakors triggers his land
  charge run thus making it very weird" - done as a fly charge, section 2
- "charging doesnt even speedup units. check chaos units in your testing" - done for units of one, section 1

## 1. The sprint for a unit of one

**Cause.** A lord, hero or monster walked by move orders (`F.uc:goto_location`), and the sprint was CA's
`change_current_walk_speed(1.5)` after each order. That call does nothing to a single entity, at any scale, run or
walk. Measured with no third person, `probes/zz_tp_walk_scalar.lua`, one 150 m order from the same clear start:

| Unit | Order | none | x1.5 | x(run/walk) | x3 |
|---|---|---|---|---|---|
| Harald | run | 2.75 | 2.74 | 2.74 | 2.74 |
| Harald | walk | 1.19 | 1.19 | 1.19 | - |
| Mutalith | run | 5.63 | 5.72 | 5.70 | 5.70 |
| Mutalith | walk | 2.87 | 2.85 | 2.83 | - |
| Chaos Marauders (whole) | run | 2.41 | 4.14 | 2.90 | 4.02 |
| Chaos Marauders (whole) | walk | 1.32 | 1.14 | 1.34 | - |

m/s over 1.5-4.5 s after the order. A regiment played whole does speed up at x1.5, unevenly; the order route stays
for it. **Withdrawn:** my first fix read CA's doc ("applied to the default walk speed") as "a run order gets
walk x scale" and sent `1.5 * fast_speed / slow_speed`. The table above disproves it; it never shipped.

**What does work** is the mailbox: `P.steer` writes the speed into his own walk command. On a unit of one,
`probes/zz_tp_entity_steer.lua`:

| Unit | Lead | x1 | x1.5 | |
|---|---|---|---|---|
| Be'lakor, flying | 15 m | 8.77 | 13.0 | no guard |
| Be'lakor, flying | 3 m | 7.01 | 7.01 | no guard |
| Harald | 3 / 15 m | 3.03 / 1.86 | 3.22 / 1.18 | no guard |
| Harald | 3 / 15 m | 2.93 / 2.89 | 4.16 / 4.11 | **guarded** |
| Mutalith | 3 / 15 m | 2.97 / 5.60 | 3.28 / 7.45 | **guarded** |

Two things decide it: **the guard** (`P.guard` each frame stops his own unit's orders on him, as for one man - without
it a ground entity went no faster, or slower) and **a 15 m lead** (`MOUNT_LEAD`; at 3 m the Mutalith ran at half
his speed, the horse finding of 2026-10-16 again).

**Fix** (the author chose it over "only while sprinting" and "no speed-up"): a unit of one walks steered alone.
`main.lua` sets `F.single_steer` at the start (no one man, men check passed, steering and the mailbox in, not
artillery, not a war machine) and `F.single`, his model, each frame. `move.lua`'s `man_drive` and `M.halt` take
`F.model or F.single`, with `MOUNT_LEAD` for a unit of one. The guard was already there: `main.lua` guards a single
entity whenever it is not driving, and with no move orders it never is. The mailbox is now put in at any start,
not only with one man on: that setting is the regiments'. Only walking changed: swings, shots, abilities and the
attack order of a unit of one are as before.

**Live, through the shipped frame loop** (`probes/zz_tp_sprint.lua`, bridge-loaded source):

| Unit | Run | Sprint | | Clips in the sprint |
|---|---|---|---|---|
| Be'lakor, flying | 8.83 | 13.49 | x1.53 | FLY_CHARGE 7, CHARGE 0 |
| Harald | 2.89 | 4.64 | x1.61 | CHARGE 7 |
| Warshrine | 3.35 | 5.34 | x1.59 | CHARGE 6 |
| Mutalith | 2.20 | 4.65 | x2.11 | CHARGE 6 |

One man of a regiment already sprinted (2026-10-17, unobstructed: hounds 14.25 posted 14.25, Rot Knights 11.72
posted 11.25), CHARGE clip and all. That day's slow one-man numbers were his own lines and the enemy in the way.

Still on move orders: a regiment played whole, artillery, a war machine of one (a steam tank: the mailbox is
unmeasured on one) and anything when the mailbox is not in.

## 2. The fly charge

Of the 123 skeletons with `FLY_STAND` (slot 87), 86 have `FLY_CHARGE_AIR_TO_AIR` (slot 102), read off CA's
animation tables with `third_person_fires.py`'s reader (same slot table as `CHARGE` 135 and `WALK_1` 42). Also
`FLY_CHARGE_AIR_TO_GROUND` 103 and `FLY_CHARGE_LAND` 104. Be'lakor's 102 is
`belakor_fly/locomotion/hu10_belakor_fly_charge_01.anim`, 1.2 s, a loop; griffons and manticores have a 5.3 s one.

`combat.lua` `C.charge_run` picks `FLY_CHARGE` when `is_currently_flying()`, else `CHARGE`; a flyer without 102
plays nothing in the air, not even the `WALK_1` that ends a charge. `C.attack` throws no charge attack in the air
(MOVING_ATTACK is a ground clip): a click is his air swing. Live: Be'lakor, 7 fly charges and 0 ground ones in a
sprint.

## 3. The camera

- **Melee mode centres on him.** `rig.lua` `R.centre` eases (`OTS_RATE`) between looking at him and looking
  `AHEAD` (6 m) past him; `main.lua` passes `not F.ranged and not F.armed`. Starts centred in melee mode.
- **An ability armed looks ahead again**, so the crosshair is where it lands. A click before the ease ends lands
  where the crosshair then is; `ability_ground_lands_on_the_crosshair` now waits a second for the view.
- **Top shoulder.** MCT `camera_shoulder` gains `top` (right stays the default); `settings.lua` maps it to 0, and
  the eye sits centred at `OTS_TOP` = 2.3 (x zoom) instead of `OTS_HEIGHT` 2.0. **3.0 was wrong**: the view is
  about 16 degrees each way vertically (measured off a right-shoulder screenshot: a head 11.5 degrees under the
  centre drew 260 px under it at 720p), and a rider starts at zoom 2, so at 3.0 he was out of the bottom of the
  frame. At 2.3 a man's head sits ~9 degrees under the crosshair and a rider's at the bottom edge.

Screenshots: the game window was under the author's browser, so a screen grab got Chrome.
`common.take_screenshot("name.tga")` over the bridge draws the 3D view whatever is on top; it lands in the
install's `screenshots/`.

## 4. Double attacks: not reproduced

`probes/zz_tp_swings.lua` (now starts directly and plays a unit of one too) after `probes/zz_tp_engage.lua` (now
takes a unit of one): 8 clicks 2.4 s apart, counting attack clips that start on him per click.

| Played | Enemy | Per click | Swings with no click |
|---|---|---|---|
| Chosen (one man) | held, in contact | 1 x8 | 0 |
| Chosen (one man) | two Skaven regiments attacking | 1 x8 | 0 |
| Harald | two regiments ordered on him, not yet in melee | 0, then 1 x7 | 0 |

Not tested: a lord in a crowd that is fighting him, and clicks closer than 2.4 s. Asked the author what "twice"
is (two swing clips per click, one swing hitting twice, or a swing of his own after the click) and on which unit.

## 5. Test and probe fixes

- **The rig tests passed only after another test had made `bm`.** Run alone, as `tp_mutate.py` runs a test, every
  rig test failed, so a mutant aimed at one was "killed" whatever it broke. `a_rig` now calls `H.fresh()`.
- **A probe's unit controllers die with it.** Held enemies under a probe's local controllers went back to the AI
  once the probe finished and its closure was collected; the AI ended two battles (07:44, 08:16, "Crushing
  Defeat"). `probes/zz_hold_enemy.lua` holds them under controllers kept in `_G.TP_HELD_ENEMY`.
- **`send.py` says `no game`** (exit 2) when Warhammer3.exe is not running, before the send and after a timeout:
  I polled a closed game after a Rematch click (the game shut with no dump and no log line).
- **Teleporting a regiment breaks its one-man check** ("a steering copy is not near its man"), so the sprint probe
  takes units of one by default. A unit of one teleports cleanly.
- The harness fake gains `mailbox = "unchecked"` (in only once `check_mailbox` runs, as in the game) and no
  longer fakes `slow_speed`/`fast_speed` (added for the withdrawn fix, removed).
- Tests that exercised the move-order route through a general (a unit of one) now use `whole_on()`, a regiment
  played whole: `walking_orders_a_regiment_played_whole` (was `..._a_single_entity`), the dropped-order and
  half-second tests, both whole-regiment sprint tests, the charge attack on the run, and the queued attack at F2.

**Mutants.** `mutants_round45.py`, 18, all killed. Re-aimed at today's edits, all killed with no stale anchor:
`mutants_men`, `mutants_round16` (1 of 3), `mutants_round19`, `mutants_round29` (1 of 2), `mutants_round32`,
`mutants_round34`, `mutants_round44`, `mutants_steer`. Across all 60 sets (763 mutants) 38 anchors in 15 older
sets are stale from code rewritten before today (`mutants_t8`-`t10`, `_fix`, `_round21`, ...).

## 6. Open

Kept up to date through section 12.

- **The sprint's CHARGE clip restarts** (the author, 2026-10-18: "pressing charge attack as well repeats the charge
  animation randomly"; 2026-10-16: "resets the running after 1 frame then start of charge animation again"). Measured
  (section 7): on Harald the clip is 0.8 s and does not loop, and `C.charge_run` re-sent it every `CHARGE_GAP` 0.6 s,
  so each one was cut 0.2 s short and started over. **Fixed in section 10**: sent again at each unit's own CHARGE
  length (data.lua `charges`). Still open: the send lands within a model tick of the end, not on it; driving the
  engine's own charge, command `exe+3ad2d18` (`docs/BATTLE_ENGINE_RE.md` section 5), would end the re-send altogether.
- Harald's sprint (section 8): why the author saw no speed-up is not known. Of the two candidates, the CHARGE restart
  is fixed (section 10) and the stamina is not; not re-tested by the author since.
- One gated melee run of the Mutalith stalled 7.4 s (section 7). Not reproduced.
- Double attacks: waiting on the author's description; the Mutalith report below may have been the same thing.
- A war machine of one (steam tank) still sprints by the order scalar, which does nothing to a unit of one.
- The Mutalith's run through the frame loop (2.2 m/s) is under his order run (5.6) and his guarded steer (5.6 at
  15 m): measured from 1 s after W, so it is partly his acceleration. Not looked into.
- data.lua's `fires` for the Necrofex come from the crew's bin (1.16 s), not the colossus's 2.66 (section 11).

## 7. Units of one in a fight (later 2026-10-18), deployed `6935cb70`

The author, playing `bd383804`: "mutalith is spamming the melee button, its like the actions are queued or still
auto attacking", "pressing charge attack as well repeats the charge animation randomly", "harald hammerstorm
running/sprinting not even fixed". Their log: the Mutalith's `clip 455/454/489/457 never played` in and out of melee.

Measured with `probes/zz_tp_one_timeline.lua` (new; `_read`): a unit of one teleported to a clear lane, or left in
a melee `zz_tp_engage.lua` set up, played through the shipped frame loop on a key script (`walk`, `sprint`,
`sprintturn`, `turn`, `spam`, `combo`), with a row each frame his state changes: clip, command, both action slots,
`+0x324`, `+0x108`, `+0xb20`, the pack's lock and pending.

Three faults, all from today's change that steers a unit of one alone while combat still treated him as played whole:

1. **No order gate for a unit of one.** In a lasting melee the engine orders his melee attack again every tick and
   the guard stops it; a parked clip loses to that order (`docs/BATTLE_ENGINE_RE.md` section 8). Ungated: the jump
   and four swings, none started in 11 s, while `F.pending` kept him armed. Gated: all played, 0.2 s each.
   `main.lua` now puts the gate in for `F.model or F.single_steer`.
2. **The turn order.** `swing()` turned a unit more than `TURN_DEG` off the camera with `goto_location_angle_width`
   and played the clip 350 ms later, a route for a unit walked by orders. Harald standing, the camera 60 deg off his
   facing: the clip went through his queue and never played. A unit of one steered alone now takes one man's route,
   and `main.lua` holds his facing to the click's until the clip is reported, as for one man.
3. **The lock read the turn order's wait as reported.** `C.locked` set `seen` when the clip was `nil` and the lock
   had no clip yet (`nil == nil`), so the lock ended the moment the clip was sent, and the next click or the
   sprint's CHARGE cut it. Now it waits for a clip. A regiment played whole still takes the turn order.

**Harald's run and sprint measured fine** in every run: run 2.9-3.4 m/s, sprint 4.1-5.1, the charge attack once
and on through it, with the camera on his bearing and 35 deg off it. What the author saw is most likely the turn
order (2.) and the CHARGE restart (section 6), not his speed.

Not a bug: `unit:bearing()` of a unit of one follows his model's facing (read live), so the walk itself never took
the turn order. A probe artifact found on the way: the model clock steps 0.1-0.2 s, and a 50 ms press and its
release taken in one probe callback were never down; the probe now gives a press a frame of its own.

Tests: `the_gate_is_in_while_a_unit_of_one_is_steered_alone`,
`a_unit_of_one_swings_where_the_camera_looks_with_no_turn_order`,
`a_swing_after_a_turn_order_keeps_its_lock_until_its_clip_plays`, all watched failing first;
`a_whole_unit_turn_just_after_stopping_is_not_dropped` moved to `whole_on()`. 398 pass. `mutants_round46.py`, 5,
all killed (a sixth, on `act()`'s facing, survived because the lock's facing covers it, and that edit was reverted).
Re-aimed: `mutants_round35`, `mutants/mutants_round17`, `_round18`, `_round23` (its two rig.lua anchors were stale
before today). Live, the bridge-loaded fix: Harald's turned click 0.2 s, both clicks of `turn` swing, the charge
attack with the camera turned plays and he runs on through it; the Mutalith's melee combo 4 runs, 3 with every
action started (the stall is in section 6).

Backups: `Modding Files/Backup/derpy_third_person_20261018_110649.pack` (the build's), and
`derpy_third_person_data_20261018_1107.pack` (the `data/` copy replaced).

## 8. One man's steering point 3 m -> 15 m (2026-10-18 noon), deployed `4754eb44`

The author, after `6935cb70`: "charging does not make harald faster than running", "also chaos spawn", "are you
testing it properly?". They were right about the testing: every sprint probe so far faked the keys inside the pack
(`P.held`), started third person directly, teleported a **unit of one** to an empty lane and held the enemy, and
none covered a monster played as **one man**.

**Real input now.** `probes/zz_tp_watch_sprint.lua` (new) only watches - every 0.25 s: steered alone or as one man,
walking/running/sprinting, stamina, the speed `E.move.drive` was asked for, the scale and point distance `P.steer`
carried, his command and its speed `+0x394`, the man (a switch restarts the speed), his speed over 0.5 s;
`_G.TP_WS_LEAD` rewrites only the point's distance. The keys are real: a PowerShell sender (`keybd_event`, VK and scan
code) brings the game window to the front with an Alt tap and **sends nothing unless it is in front**, stopping if it
loses the front. Its first version did not check, and its F2/W/Shift went to the editor and, the second time, into
the author's own play of the game I had launched (they had taken it over to test): look for a human first.

**What the author's own play showed** (the watcher was running): Harald sprinting 5.6-5.7 m/s against 3.2 running,
his walk at 4.95 and 3.3; Be'lakor to 15.8 against 9. The units of one were fine.

**What was not** (enemy held, F2 and real W 4 s / W+Shift 5 s, run and sprint averaged over their last 2 s; `py
probes/tp_leadrun.py <unit type>@<lead or ->`, the key sender `probes/tp_keys.ps1`):

| Played as one man | point 3 m: run / sprint | point 15 m: run / sprint | his walk asks |
|---|---|---|---|
| Spawn of Tzeentch | 1.27 / 0.56, 3.17 / 3.36 | 4.27 / 5.78, 4.41 / 6.74 | 4.2 / 6.3 |
| Champions of Slaanesh | 1.91 / 1.97 | 7.38 / 10.35 | |
| Chosen | 3.25 / 4.36, 2.73 / 4.24 | 2.56 / 4.62, 2.64 / 4.29 | |
| Chaos Marauders | 0.5-1.5 either way | | in melee: not a test |

A body runs no faster than it can stop in the distance to its point (the horse, 2026-10-16), and the 3 m kept for a
man on foot capped every big one. `move.lua` now has one `STEER_LEAD` = 15 for everyone, `MAN_LEAD` deleted.
Shipped code, real keys: Spawn 4.33 / 7.31 and 4.06 / 6.12, Champions 5.96 / 9.65, Chosen 2.38 / 3.75, Harald 3.66 /
5.09. Test: `one_man_walks_alone` asserts 15 m (watched failing at 3). 398 pass; re-aimed `mutants_round34`,
`mutants_round45`, `mutants/mutants_unlatch` (its steer anchor had been stale), 48 killed.

Harald: why the author saw no speed-up on him is not known; candidates are the stamina (8 s, then nothing until a
quarter is back; he was at 18% when the watcher caught him) and the CHARGE clip restarting (section 6).

Backups: `Modding Files/Backup/derpy_third_person_20261018_120344.pack`, `derpy_third_person_data_20261018_1204.pack`.

## 9. A flyer on his own wings swings his air attacks (2026-10-18 afternoon), deployed `91c4933a`

The author: "now flying units when using melee uses ground melee attacks e.g belakor". Read live in their battle,
read-only: Be'lakor flying, **no mount**, with ATTACK_1-5 (454-458) and FLY_ATTACK_1-4 (494-497) on his own model.
`swing()` took FLY_ATTACK (slot + 40) only for a mount's body (`local air = mount and ...`), so a flyer with no mount
fell through to his ground ATTACK. The RED test played 454 and 458 in the air.

**Fix** (`combat.lua`): the body that flies is `mount or first`; its list and the right-click fallback (no FLY_ATTACK_5-7,
so FLY_ATTACK_1-4) read that body, and a model with no mount plays slot + 40 in the air with the swing's mask. The jump
attack does nothing in the air (JUMPING_ATTACK is a ground clip, as the charge attack, which was already off there).

**Live, shipped code** (`probes/zz_tp_fly_swing.lua`, `_len.lua`, through `E.combat.attack` / `mode` / `jump` as the frame
calls them): in the air, clicks 494, 494, 495, 495, 497 and the right-click fallback 494-497, jump nothing; landed,
456, 458 and the jump 489; lifted again, 497. Lengths in the air: 494 2.6 s, 495 2.3, 496 3.5, 497 3.6, each ending on
its own. Toggle flying acts on the **selection**: with nothing selected the probe's click left him flying; his card
(`review_DY > 1001`) clicked first, it landed him.

Test `a_flyer_with_no_mount_swings_his_air_attacks`; 399 pass. `mutants_round47.py` 5/5; `mutants_round32` re-aimed
(its `has_slot(mount, s + 40)` anchor), 20/20. `mutants/mutants_actions` has 3 stale/surviving entries on lines this
change did not touch (counted in the older stale anchors, section 6).

Backups: `Modding Files/Backup/derpy_third_person_20261018_125253.pack`, `derpy_third_person_data_20261018_1254.pack`.

## 10. Clips timed per unit: Ku'gath's throw, the charge cycle, a blank jump (2026-10-18 afternoon)

The author: "Kugath cant use his ranged attack, check it ingame mcp and logs why cant the full animation play",
"looping charging animation is not goo and looks like its not looping but being cut off mid animation", and "this is
getting frustrating that you cannot acheive the goal of having a unified third person mod across all units". All three
faults below are one kind: a clip timed on a fixed number instead of the unit's own.

**Ku'gath's ground fire.** His only fire clips are a rider's (RIDER_FIRE_FORWARD/LEFT/RIGHT_LEVEL 2105/2108/2111), 5.7 s,
FIRE_POS at 3.6 s. The author's log: 13 `ground fire at` orders about 4 s apart, no shot. Live, shipped code
(`probes/zz_tp_ground_fire_clip.lua`): the click's order dropped at 4.2 s, ammo unchanged, no clip reported. The same
order sent with nothing to halt it (`probes/zz_tp_ground_fire_free.lua`): the throw began 7.0 s after the order (his
reload; base 10 s), the nurgling left at 10.8 s (3.8 s into the clip), the clip ended at 12.8. **Fix** (`combat.lua`
`C.ground`): the commit's cap is `FIRE_COMMIT` + his base reload + his first FIRE_POS (data.lua shots and fires; 17.6 s
for him, 4 s for a unit data.lua lacks). After the shot, the order stays until the clip it left in is over (`FIRE_TAIL`
6 s at most; 10 since section 11), so the throw plays out. Held, as before, it stays. A move key with the button up ends the commit
(`main.lua`), as it drops one man's shot: the walk does not run while he fires. Live, fixed code: a click at battle
start threw at 2.0 s, released at 5.8 (past the old halt), clip over and halted at 7.8; a click mid-reload with the view
turning 1 deg per 1.5 s (10 re-aims, some during the throw) threw at 6.8 s, released at 10.6, clip whole.

**The charge cycle.** Shipped code, the Great Unclean One, real W and Shift: CHARGE sent every 0.6 s against his 1.9 s
clip, never reaching its end (the cut the author saw). The clip does not loop (section 6). **Fix** (`C.charge_run`): sent
again `CHARGE_LEAD` (0.1 s) before its own length, off its .anim (new data.lua `charges`, CHARGE and FLY_CHARGE, the
longest variant, off the body that plays it: his mount's bin via `mounts.animation`, else his own; 3,605 units), and at
once if the engine reports it over first; a length unknown, only then (`LOCK_MAX` at most). Live, fixed code, real keys:
the Great Unclean One sent at 242.0, 243.8, 245.6, 247.6, clip 135 the whole sprint, run 4.6 m/s and sprint 5.1-7.0;
Ku'gath (his palanquin's 1.7 s) every 1.6 s, run 3.7 and sprint 5.5-7.4. Releasing Shift ends it as before.

**A blank jump.** The author's log: the Great Unclean One's `clip 489 never played` four times. CA ships
`hu09b_sw_jump_attack_01.anim` as a **0-byte file**: the slot is in his fragment, so `P.has_slot` finds it, and the engine
has nothing to play. A scan of all 1,899 bins finds this the only blank slot the pack plays (the others: a manticore
slot 533 it never plays). New data.lua `blanks` (slots whose every clip is empty, 33 units); `capabilities()` counts
them as absent. Live: `has_slot(489)` true, `can_jump` false, two real E presses logged nothing.

The first live run of the fix happened after the battle had ended ("off: battle over"): units are held then, and it
showed a 1 s stall and a latched CHARGE. Relaunched, the results above are from a running battle.

Tests: `a_late_throw_is_held_to_its_release_and_plays_out`, `a_click_just_after_a_shot_waits_the_whole_reload_and_the_release`,
`a_move_key_ends_a_ground_fire_shot_still_to_come`, `the_charge_clip_plays_its_whole_cycle_before_it_goes_again`,
`a_charge_of_no_known_length_goes_again_when_it_ends`, `a_jump_whose_clip_is_an_empty_file_is_no_jump`, each watched
failing first; `shift_held_on_the_move_charges_for_as_long_as_it_is_held` now asserts the charge goes on, not six sends.
405 pass. `mutants_round48.py`, 10; its one survivor (the release term) is what the reload test was added for.
Re-aimed: `mutants_round43`, `_round45`, `mutants/mutants_round16`, `_round25`, `_t9`. `third_person_fires.py`
`blank_slots` and `Files.size` are in its selftest; `build_third_person.py check_data` pins the Great Unclean One's 1.9,
Be'lakor's 1 and 1.2, and the blank 489.

Open: the engine's own charge (`exe+3ad2d18`) loops the cycle as locomotion; driving it would end the re-send
altogether. The send still lands within a model tick of the end, not on it.

## 11. A crew on one body is a unit of one (2026-10-18 evening), deployed `1793f71e`

The author: "cannot fire range mode using necrofex, check ingame". Their log: the Necrofex Colossus RoR on as "one man,
shooting alone", 15 `shot level ... fire 2105` lines about 1 s apart and never `shot clip 2105 in fire`: the one-man
shot sent its fire clip, never saw it start, gave up at `LOCK_WAIT` and sent again while the button was held. Read live,
read-only, in their battle: **five models, all riding one mount** (the colossus); the land unit's man is his crew
(`hu1_cst_zombie_gi2_colossus_wb_crew_1`, a rider's 2105); the clip showed on the crew's first man, not the front man it
was sent to. The same log has the Khemrian Warsphinx (four crew on one sphinx) played as one man too, with four
`clip 45x never played` and two jumps.

**Fix** (`main.lua`): `crewed(unit)` - more than one model and every one's mount the same object - keeps `F.model` nil,
and the frame's `single` is the crew's first man, so the unit is played as a unit of one: `platform.lua` steers, holds,
guards and faces his mount, and its shot is the engine's ground fire. `combat.lua` `each()` takes `F.model or F.single`, so
a swing is sent once, not once per rider of the same body. Riders on mounts of their own (cavalry, chariots) are unchanged.

**The shot's tail, both clips.** Live: the colossus fires with its own FIRE_LEVEL (`gi2_cst_colossus_flame_thrower`,
9.5 s, FIRE_POS 2.66 s), and on the RoR his crewman played his own RIDER_FIRE beside it (735.2 colossus, 737.0-739.2
crewman, flame at 738.2). Releasing at the shot, then at the crewman's clip's end, cut the colossus's at 3-4 s.
`C.ground` now records, as the shot leaves, his clip and his body's, each only if it is a shooting clip (`shooting()`:
1547-1599, 949-952, 2104-2116 - an idle on the body, e.g. SHOOT_STAND_IDLE 1438-1447, holds nothing), and waits for both;
`FIRE_TAIL` 6 -> 10 s.

**Live** (a fresh battle each time; two runs fell after "phase: Complete" and were discarded - a finished battle holds
its units): the Warsphinx as a unit of one, four clicks, 454 455 456 454 on the sphinx 0.2 s after each, none lost; the
regular Necrofex, click, FIRE_LEVEL 768.8-776.4, cannon out at 773.0, released at the clip's end; the RoR, click,
FIRE_LEVEL 118.8-128.4 (its whole 9.5 s), four flame bursts, released as it ended; walking 3.5 m/s and sprinting 4.9-11 with
real keys, the colossus's CHARGE every 1.4 s (its own 1.4).

Tests: `a_crew_on_one_body_is_played_as_a_unit_of_one`, `a_crew_on_one_body_swings_once`,
`riders_on_mounts_of_their_own_are_still_one_man`, `a_crews_shot_plays_out_on_the_body`,
`a_crews_shot_waits_for_every_shooting_clip_and_no_idle`; 410 pass. `mutants_round49.py`, 10, all killed; re-aimed
`mutants/mutants_men` and two `mutants_round48` entries. data.lua's `fires` for the Necrofex still come from the crew's
bin (1.16 s) where the colossus's release is 2.66: only the commit's slack reads it on this route.

## 12. A shot under way is not re-aimed (2026-10-18 evening), deployed `8a2e0ab0`

The author: "theres a bug when moving the mouse and aiming for fire, it keeps repeating the aim animation and never
firing". Their log, the Necrofex Colossus: a fire order every 0.6 s as the crosshair moved, `fire()` re-aiming past 5 m.

**Cause, measured on the engine alone** (`zz_tp_reaim_free.lua`, the order `fire()` sends, no pack logic after it):
with no re-aims the colossus waited out its reload and started FIRE_LEVEL 1557; with the same order re-sent 10 m to
either side every 0.6 s it started FIRE_LOW 1556 eleven times in 12 s, each cut 0.2 s in, ammo 20 throughout. **A new
`attack_location` during the shot's clip restarts the clip**, and a clip that is restarted before its release never
fires. FIRE_POS is 2.66 s into the colossus's 9.5 s clip, so any mouse movement at all kept it in the aim.

**Fix** (`combat.lua`): `in_shot()` - a shooting clip (`shooting()`) on the first man or his body - and `fire()` sends no
order while one plays once an order is out (`F.fire_at`). The first click still orders at once, whatever clip is
playing.

**Live** on `8a2e0ab0`, the regular Necrofex, one click through `E.combat.attack`, the view turned 2 deg every 0.6 s for
25 s (`zz_tp_ground_fire_clip.lua`, `TP_GF_NUDGE` 2, `TP_GF_EVERY` 6): MOVING_FIRE_FORWARD_LEVEL 1570 at 414.6, ammo
20 -> 19 at 415.4, four turns during the clip and none restarted it, released 417.2.

Tests: `a_shot_under_way_is_not_re_aimed`, `a_click_in_a_shooting_clip_still_orders_at_once`; 412 pass.
`mutants_round50.py`, 3, all killed.
