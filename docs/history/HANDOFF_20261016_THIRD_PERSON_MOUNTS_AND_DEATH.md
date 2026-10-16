# Third-person: physical mounts, HP-zero handover, and remaining live failures

**Current resume point, 2026-10-16.** Continues [the eight reports](HANDOFF_20261016_THIRD_PERSON_FIXES.md).
Do not describe all eight as fixed. A build and an offline test pass do not establish live melee or animation correctness.

## Source, build, and enabled copy

- Maintained source: `Modding Files/source/third_person/`; only four shipped modules changed: `platform.lua`, `move.lua`, `combat.lua`, `main.lua`.
- Generated `data.lua`, HUD assets, MCT, localisation, and the pack's file list are unchanged.
- Final build: `Modding Files/Modpacks/derpy_third_person.pack`, MD5 `6248975ae8d0defb67d77c3c04fe1d32`; deployed to the enabled `data/` copy. Experimental CHARGE preservation was removed after live failures.
- Build backed up the previous `5f4925ee7645187c27e95dac9ed083c3` Modpacks copy to `Modding Files/Backup/derpy_third_person_20261016_183001.pack`.
- Saved candidate was reopened and all 14 source files and three loc rows verified. Independent binary-index comparison found the same 18 paths as the enabled copy and all 14 source files byte-identical to maintained source.
- Deployment status is recorded at the end of this handoff. This pack is local, with its enabled copy in the game's `data/`, not a Workshop-hosted pack.

## What was established in the author's High Elf battle

The user explicitly handed over the game for automated battle tests. No battle result was saved.

1. **Tyrion's missing first rider attack is real.** His rider has slots 1902/1903/1904, but no 1901. The old `P.mount` required 1901 and therefore returned nil. The parent at `+0x2e0` is a valid horse with attacks 454–458. Before the change, clicks issued fallback unit attack orders; after parent discovery and dispatch were corrected, live clicks reported horse clips 454 and 455.
2. **The rider is not the physical actor.** Tyrion's rider has placeholder HP 16; his horse has 9800. Dragon Princes and Fireborn riders have HP 8 and horses HP 114. Their movement, stop, facing, automatic-command guard, HP, and steering-copy validation now use the physical parent. The camera/model identity remains the rider.
3. **A parent does not always mean a rider.** The fire mage and Skycutter also have physical parents, without the normal rider attack rows. Artillery crew point to their gun (HP 380, no melee attack), while the crew have their own attacks. Combat retains the crew's own clip if the parent cannot play it. Do not replace parent discovery with another single-attack-slot gate.
4. **Single entities bypassed the guard and the HP check.** The old guard ran only when `F.model` was non-nil. A fresh live run of Tyrion recorded 187 attack-clip frames and 272 native melee-command frames in its no-click phase. Injecting physical HP zero left control active for a second. The source now guards an idle single entity and stops control at physical HP zero. A deliberate native fallback attack is exempt until cancelled by movement, a new action, or standing down.
5. **The existing enemy-ray aim can work live.** Everqueen's Court Guards' view aimed at a real enemy chest stopped within about 0.0005 m of that point in one run, and the raise/hold/fire clips and one projectile launch were observed. This verifies the calculated point and the launch, not damage on the target through intervening men.
6. **Everqueen's Court Guards have no high shot pair.** Live active-fragment slots: 1548, 1551, 1554, 1557; no 1555/1558/1549. Projectile speed 55, range 180, level raise length 1.8 s. A high view uses the supported level fallback. Do not report a high animation PASS on this unit, or invent high clips it lacks. The visual flicker report remains open.

## Changes and regression coverage

`platform.lua`: parent discovery no longer depends on RIDER_ATTACK_1, but retains the known-build safety gate; physical facing/steering/holding/guard/HP and physical steering-copy validation; `P.alive` requires positive HP after confirming membership. No CHARGE-preservation branch ships.

`move.lua`: ignores HP-zero models when selecting the next front man; locomotion and clip unlatching run on the physical body; movement cancels the explicit native-attack exemption.

`combat.lua`: dispatches supported mount slots directly, including jump/moving attacks; chooses supported airborne attack candidates; preserves detached-rider and artillery-crew fallbacks; mounted celebrations/unlatching run on the physical body; CHARGE availability is separate from MOVING_ATTACK availability; ranged mode cancels an old native melee exemption.

`main.lua`: HP-zero single entities release control; idle single entities receive the guard; shared action-capability discovery runs at start and death handover; each new man's shooting permissions are recalculated.

Offline checks were added to `tools/third_person_tests.lua`; the fake platform's alive contract now includes HP in `tools/third_person_harness.lua`. Two independent review rounds found and reproduced mount-only jump/cheer, air-candidate selection, stale death capabilities, native-attack cancellation, and test-verdict defects; the production findings have regression checks.

Validation after source stopped changing:

```powershell
py tools/build_third_person.py --selftest
py "Modding Files/source/lord_control/probes/tp_mutate.py" "Modding Files/source/lord_control/probes/mutants_round32.py"
```

- **360/360** offline tests; compile, CA API, literal-left, HUD/data/loc checks clean.
- **20/20** new mutants killed, no stale anchors. This is the round-32 set, not a fresh sweep of every historical set.
- Engine command pattern matches exactly once in exe build `6acec6f4`.
- Final logs: `probes/tp_build_20261016_round32_final.txt`, `probes/tp_mutation_20261016_round32.txt`. `tp_build_20261016_round32_charge.txt` describes the excluded experiment, not final production.

## Live input probe and corrections to early evidence

`Modding Files/source/lord_control/probes/zz_tp_input_sweep.lua` sets up a subject with `E.main.start(unit)` and drives movement, sprint, mode and clicks through swapped `P.held`/`pressed`/`focused`/look functions. It never calls `E.combat.melee` to produce the tested swing. Unit controllers, teleports, invincibility, reload waiver for the high-view shot, and optional HP-zero injection are test setup only. They do not ship.

Read with `zz_tp_input_sweep_read.lua`; `_G.TP_INPUT_TYPES` optionally limits subjects, `_G.TP_INPUT_DEATH=true` enables real HP-zero injection, `_G.TP_INPUT_STOP=true` cancels. Each run restores input functions, the projectile wrapper, guard wrapper, and controllers. **Use a fresh unsaved battle after death tests. Never restore HP to undo death state, and never save their result.**

The broad run visited all 20 player-unit rows, but its early verdicts are diagnostic, not release acceptance. Important corrections:

- `repeat_real_callback(..., 0, ...)` is invalid; the runnable probe uses 1 ms.
- A setup controller retaining player control prevents UI selection. The first F2 sweep repeatedly selected Tyrion. Those other-unit rows are invalid. Setup now explicitly starts the subject; selection/F2 itself is not being tested by this probe.
- Wait after teleporting and reset destination copies before `P.check_men`; a long artificial teleport can fail its 300 m safety check and silently test a whole regiment instead of one man.
- Move the previous subject out of the arena. Preserve hit reactions; a sprint interrupted by knockdown is not proof of the reported charge-reset cause.
- Slot ids 474–483 are DEFEND, not attacks. A previous manually forced attack still playing is not an unsolicited new attack. The final probe distinguishes the pack's clip command and reads the command immediately after the guard; incoming native commands are recorded separately.
- A shot PASS now requires raise/hold/fire playback and a projectile launch. A missing high pair is an explicit SKIP, not a PASS for the level fallback.
- **Restoring injected HP corrupted repeat tests.** HP-zero can set death state before the roster drops the model. Writing HP back does not resurrect it; a later front-man choice can then select an immobile model with positive HP. Reused-battle artifacts, especially `tp_input_20261016_zombie_invalid.json`, do not establish movement or melee regressions. The final run restarts the battle and leaves injected HP at zero.

Earlier diagnostic artifacts: `tp_input_20261016_baseline.json`, `tp_input_20261016_mount_pass1.json`, `tp_input_20261016_mount_guard.json`, `tp_input_20261016_mount_pass2.json`, `tp_input_20261016_full.json`, `tp_input_20261016_guard_all.json`, `tp_input_20261016_clear_arena.json`, `tp_input_20261016_final_six_attempt1.json`. They include intermediate source and setup faults. Do not aggregate their PASS counts as a verified all-unit result.

## Current acceptance and remaining work

The final fresh run's table and deployment outcome follow below. The original eight-report list remains the acceptance checklist. In particular, do not infer that intermittent melee, automatic attacks across every class, or the charge/high-view visual flicker are fixed merely from a correct mount receiver or a constant reported slot. No animation assets or native engine hooks were changed in this pass.


## Final fresh six-unit run

Source matches candidate `3e0953e9`. Full raw commands, clip counts, checks and launch coordinates: `Modding Files/source/lord_control/probes/tp_input_20261016_final_six.json`. The run completed with `done=true`, no Lua error.

| Unit | Walk | CHARGE clip | Outside swing | Melee swing | Idle guard | HP-zero handover |
|---|---|---|---|---|---|---|
| Calith Gatekeepers | PASS | PASS | PASS | FAIL | PASS | PASS |
| Everqueen Court Guards | PASS | PASS | PASS | FAIL | PASS | PASS |
| Tyrion | PASS | PASS | PASS | PASS | PASS | PASS |
| Dragon Princes | PASS | FAIL | PASS | PASS | PASS | PASS |
| Fireborn | PASS | FAIL | PASS | FAIL | PASS | PASS |
| Keepers of the Flame | PASS | FAIL | FAIL | PASS | PASS | PASS |

Walk distances: Calith 9.21 m, Everqueen 9.02 m, Tyrion 21.71 m, Dragon Princes 1.65 m, Fireborn 1.80 m, Keepers 1.24 m in their 3 s windows. These establish movement, not correct top speed. Cavalry remain slow in this measurement.

All six had no unsolicited attack after the guard in the 6 s idle window and changed control within 1 s of physical HP zero (reported model-clock delta 0 s). This is a short controlled test, not a natural-death or unlimited no-auto-attack guarantee.

Everqueen: level raise/hold/fire all observed and one launch; chest aim error 0.002862 m. High-view test explicitly SKIPPED high-pair acceptance because the unit lacks the high clips; the level fallback played and launched.

At that source: Calith, Everqueen and Fireborn missed their melee swing; Keepers missed the outside swing. Three CHARGE-continuity rows failed. Later CHARGE evidence follows; do not erase these earlier failures. Inspect native state/animation scheduling and the physical actor under a failing click before changing more command classes.

## CHARGE follow-up: excluded from production

The native forced-clip command replaced the walking command on a horse; the next `P.steer` constructed a walk and destroyed that clip. A temporary wrapper preserving the clip reproduced sustained Fireborn CHARGE (0/288 sampled frames missing it). A candidate preserved slot 135 and stopped it on movement release; its offline check and two mutants passed. **Those branches and their check/mutants were removed:** later live evidence did not establish a working movement fix. Candidate `b38de8c5` is experimental and must not be deployed.

`tp_input_20261016_charge_preserve_production.json` is a repeat in the previously death-tested battle: Dragon Princes passed CHARGE (0/273 missing), moved 3.98 m, stopped with 0 m displacement after release, and passed both swings and the idle guard. Fireborn failed movement/CHARGE and never reached melee in 40 s. Do not dismiss that failure as a proven zombie: no HP was restored in that battle. A fresh restart was required to distinguish accumulated death/native state from a source defect.

The short run/sprint distances do **not** verify the requested 20% boost. The preserved native clip bypasses the walking command's speed field; its effective speed still needs a controlled steady-speed measurement. No new engine field was guessed to force that result.

Fresh unsaved restart, source `b38de8c5`, no HP injection: `tp_input_20261016_charge_fresh_three.json`. Cancelled after Fireborn's movement/outside-swing phases (`done=false` at capture):

| Unit | Run distance | Sprint / CHARGE | Stop after release | Outside / melee / idle |
|---|---|---|---|---|
| Calith | 9.30 m | 10.74 m, 0/374 missing | 0.0013 m | PASS / FAIL (knocked down) / FAIL (142 attack-clip frames) |
| Dragon Princes | 1.29 m | 0.71 m, 298/298 missing | 0.39 m | PASS / PASS / PASS |
| Fireborn | 0.54 m | 2.56 m, 173/247 missing | 0.45 m | FAIL / not completed / not completed |

The Calith failure includes attack metadata 455/456 under native stand `39126f0`, plus delayed own clip and knockdown/get-up commands. It establishes a failed acceptance check; it does not prove all those frames are newly initiated automatic attacks. Keep the report open instead of adding stand or hit reactions blindly to the stop list.

`tp_charge_20261016_pending_trace.json` shows Fireborn CHARGE being queued, while steering repeatedly sees stand/no clip and constructs walk before CHARGE can report. A second wrapper kept the command while a charge was pending: `tp_input_20261016_pending_charge_experiment.json`, cancelled in idle melee. Fireborn then reported CHARGE on all 283 sampled frames but moved only **0.064 m**, compared with 3.83 m during run; stop was 0 m. A constant clip alone is not success. This wrapper was restored before quitting.

The shipped source is the completed six-unit run's behavior plus the unknown-build parent gate (demonstrated RED/GREEN, killed mutant). Its cavalry movement and CHARGE limitations remain. Next work: trace the native locomotion/animation interaction on the physical horse, preserve real movement and the requested speed boost together, then rerun the entire acceptance table. Natural death, every-unit acceptance, projectile damage, and high-aim visual validation remain unperformed.

## Final build and deployment, 18:56

- `py tools/build_third_person.py`: **360 passed, 0 failed**; compile/API/data/HUD/loc checks clean; engine command pattern matched exactly once. Saved pack reopened and verified (14 files, three loc rows).
- `tp_mutate.py mutants_round32.py`: **20 mutants, 0 survived or stale** after excluded CHARGE branches/test/mutants were removed. Independent review confirmed their removal, then passed unknown-build safety, cavalry steering/stopping, and native run-speed checks.
- Independent binary-index comparison: same 18 paths as starting enabled pack `5f4925ee`; all 14 source files match saved pack; only `combat.lua`, `main.lua`, `move.lua`, `platform.lua` differ. Loc, data and HUD unchanged.
- Build backup `Modding Files/Backup/derpy_third_person_20261016_185554.pack` contains excluded experimental candidate `b38de8c5`.
- Restored probe input/controller wrappers and stopped control, then closed the unsaved battle by stopping the game process. `wh3_exit_windows` had returned `not in a campaign` earlier and is not a battle exit route. **No battle result saved.**
- Backed up original enabled `5f4925ee` to `Modding Files/Backup/derpy_third_person_enabled_before_mounts_20261016_185618.pack`.
- Copied final build to `F:/SteamLibrary/steamapps/common/Total War WARHAMMER III/data/derpy_third_person.pack` with game closed; source and enabled MD5 both **`6248975ae8d0defb67d77c3c04fe1d32`**. No Workshop upload. Game left closed.
- Regenerated the 11 `zz_tp_load_NN.lua` bridge parts from final source, narrowed to the current battle's 27 unit types. The bridge helper is not shipped. A new battle may need its data subset regenerated.

Resume with the remaining failures above. The final saved pack was not relaunched after copying; the completed six-unit live run used the same known-build production logic before the unknown-build-only safety gate was restored.

## Relaunch of the deployed pack, 19:01: crashed on Tyrion

Enabled copy MD5 `6248975a...` (matches the build); offline selftest 360/360. Launched on `used_mods.txt`, the author started the High Elf battle, deployment ended by `x1_start.lua`. The pack loaded natively (`build 6acec6f4 via known build: anim true, wheel true`). The six-unit sweep ran with `TP_INPUT_DEATH=true`, same order as the final run.

- Calith and Everqueen completed (script log only; the probe's table was not read out before the crash). Same misses as before: Calith `clip 455 never played`, Everqueen `clip 457 never played`; Everqueen's level shot played raise 1554 / hold 1548 / fire 1557 and launched; the high view fell back to level.
- **Tyrion: game crash about 6 s after `on: wh2_main_hef_cha_tyrion_1`, in the probe's 5 s settle phase, no keys faked yet.** Dump `crash_report/D2026-10-16_T19-06-14.mdmp`: access violation reading `0xc` at `exe+305B39A`, battle worker thread (index 7 of 91, fiber job), not the script thread. The battle carried on answering the bridge with the sim frozen.
- cdb unwind: `305b39a <- 308c477 <- 308d5fa <- 3087835 <- 3085fd7 <- 306d1f4 <- 30873ee <- ...`. Frame `3087835` is in `exe+308779c`, slot 2 of the forced-clip command vtable `exe+3911fb0` - the command `P.play` pushes. Its callee treats `model+0x330` as that command and reads its target at `+0x38` (`model+0x368`).
- At the crash the slot held vtable `exe+39126f0` (stand), whose `+0x368` is an integer animation state: `0xc`. **The clip command was replaced in the slot while its own update was running.** Crashed model: parent null, stand command, clip 32 - Tyrion's horse's settle state in the final run.
- Not established: where a clip on the idle horse came from in settle (the final run recorded none there), and whether the replacement was the engine itself or the pack's direct `walk_stop` (hold/guard) racing the battle thread. Intermittent: the identical sequence passed in the final run. Test setup was active (controllers, teleport 1 s before start, Everqueen HP-zero just before).

**Do not upload this build.** Next: log every `P.play` and `walk_stop` with model and `+0x330` vtable to the script log (unbuffered) so the next crash names its last write, then rerun the six in a fresh battle.

### Rerun, 19:22: no crash, and the race is real

Same pack, fresh battle, same six with HP-zero, plus `probes/zz_tp_native_log.lua` (probe-side wrappers on `P.play/hold/guard/steer` logging each native write as `tpx` lines; not shipped). Completed `done=true`, no Lua error, no dump. Raw: `probes/tp_input_20261016_rerun.json`; log `script_log_161026_1922.txt` (750 `tpx` lines).

| Unit | Walk | Sprint/CHARGE | Stop after release | Outside | Melee | Idle | Death |
|---|---|---|---|---|---|---|---|
| Calith | PASS 9.31 m | FAIL 16/358 | FAIL 1.36 m | PASS | FAIL 455 | PASS | PASS |
| Everqueen | PASS 9.24 m | PASS 0/328 | PASS | PASS | FAIL 457 | PASS | PASS |
| Tyrion | PASS 21.66 m | PASS 0/309 | FAIL 2.09 m | PASS | PASS | PASS | PASS |
| Dragon Princes | PASS 1.63 m | FAIL 301/301 | PASS | PASS | FAIL 457 | PASS | PASS |
| Fireborn | PASS 2.75 m | FAIL 205/284 | PASS | FAIL 454 | PASS | PASS | PASS |
| Keepers | PASS 4.92 m | FAIL 273/273 | PASS | PASS | PASS | PASS | PASS |

Everqueen shot PASS (level pair, 1 launch, chest aim 0.0016 m), high SKIP. Swing verdicts flipped against the final run on Dragon Princes, Fireborn and Keepers: the swing failures are intermittent, not per-unit.

Tyrion's settle this time: stand/idle only, no clip pushed, no native write - unlike the crashed run. **Guard: 406 stops (393 melee, 11 move_b, 1 move_a -> stand) and one where the wrapper read stand and the guard's own read microseconds later found an engine command: the battle thread rewrites `+0x330` while the script runs.** `walk_stop` destroys whatever is in the slot at call time, so a guard that read melee can destroy a clip the battle thread has just put there and is updating - the crash signature. Leading suspect for the crash, not proven for that run. Direction: stop through the engine's command queue (as `P.play` does) instead of direct `walk_stop` from the script thread.

### No auto attack FAILS under a sustained attack (19:35-19:45)

The sweep's `idle_melee` PASS above is too weak: one halted enemy unit, 6 s, last 3 s counted. `probes/zz_tp_auto_attack.lua`: fresh battle, the pack plays him, no key, up to three enemy units `attack_unit` his regiment for 30 s, both sides invincible; every frame his body's clip and command, rider clips (1901-1950) separately, nearest enemy man, drift. Raw: `probes/tp_auto_attack_20261016.json`, `..._cut.json`.

| Unit | Run 1: contact / unasked attack frames | Run 2 (with cut experiment): contact / frames |
|---|---|---|
| Calith | 1.26 m / 1 swing, 113 of 3225 | 0.84 m / 1 swing, 135 of 2406 |
| Everqueen | 3.27 m, no contact / 0 | 1.35 m / 1 swing, 160 of 2362 |
| Tyrion (single entity) | 0.79 m / 5 swings, 917 of 2550, incl. JUMPING_ATTACK_1 | 0.27 m / 6 swings, 1195 of 2394 |
| Dragon Princes | 1.08 m / 0 | 0.94 m / 4 swings, 427 of 2066, plus rider 1931 for 30 |
| Fireborn | 2.15 m / 1 swing, 188 of 2224 | 1.71 m / 3 swings, 258 of 2674 |
| Keepers | 2.66 m / 0 | 0.82 m / 0 |

**Every unasked swing ran under the stand `39126f0`**, the command the guard's `walk_stop` leaves; the guard stopped 59-166 engine melee orders per 30 s. Reading: the engine's melee order starts the swing in its own tick, before the script frame's guard sees the order, and "stand in his state" plays the started swing out. Carried 0.9-29.6 m with no key.

**Rejected fix: ending the swing with WALK_1 at mask 0 through the queue** (`probes/zz_tp_cut_experiment.lua`, riding on `P.guard`): 105 cuts sent, not one swing shortened - run 2's frames are no lower. A queued clip waits until the engine's fight animation lets it in, the same deferral that makes the player's own in-melee swing late (Dragon Princes: clip 457 sent at 185.2 s, lock gave up at 186.2 s, the clip then played on 65% of the window). Stopping an engine swing needs the order prevented before it is made, or the animation interrupted on the battle thread; neither has a known route.

**Diagnostic run (19:47, `..._diag.json`, Tyrion / Calith / Fireborn):** each unasked swing start was logged with the frame before it and the time since the guard's last stop. All six starts (Tyrion 4, Fireborn 2; Calith none in 47 stops): the frame before was stand with no clip, and the swing appeared in the frame of a guard stop (0 ms). Of Tyrion's 134 stops, 63 found ATTACK_2/3 already playing under the melee order being stopped; the Fireborn's 115, 23. **The engine's melee order starts its swing within its own battle tick; the script frame's guard always arrives after.** No script-thread change wins that race. The same split - battle thread drives him, script thread reacts - is behind the late in-melee swing and the `walk_stop` race. A real fix is on the battle thread: keep the engine from issuing melee orders to the controlled man (a native hook on the melee order's creation, found by pattern like `cmd_push`), which is a design decision for the author.

### No auto attack FIXED without a hook: his fragment has no attack clips (20:00-20:25)

The engine cannot start a swing it has no clip for. **`model+0x308` is the animation fragment `P.has_slot` already read**, measured read-only (`probes/zz_tp_frag_probe.lua`, `_size.lua`, `_end.lua`): vtable `exe+39d9448` at +0, clip count at +0x40, a u16 clip index per slot from +0x50 (`0xffff` = none), 2330 slots, fragments packed back to back `0x1284` apart. **One fragment per regiment and skeleton**: every man of a unit points at the same one, and a rider and his horse each at their own. Masking the shared one would disarm the whole regiment, so the man played alone points at a private copy whose attack slots - ATTACK 454-463, MOVING/JUMPING/flying 484-500, RIDER_ATTACK 1901-1950 - read `0xffff`.

Probe-side first (`probes/zz_tp_mask_experiment.lua` on `P.guard`, `tp_auto_attack_20261016_mask.json`): Tyrion 0/2296 attack frames, Calith 0/2300, Fireborn 0/2375, Dragon Princes 0/2709 (no contact that run). No crash.

Shipped in the source (`platform.lua` `P.disarm` / `P.arm`, `main.lua` tick and `M.stop`):
- every unpaused frame the man played alone (or a unit of one) is disarmed, body and rider; **armed** while `F.lock`, `F.swung` (his own clip outlives its lock) or `F.native_attack` (a unit of one's attack order is his swing);
- `P.play` of an attack slot gives the carrier his own table back **before the push**, or the engine finds no clip for his own swing; `P.has_slot` reads through the copy to the original, so capabilities and swing lists are unchanged;
- `M.stop` arms him unless dead (nothing written to a dead man's model); copies are made once per fragment, 12,088 bytes (0x50 + 6004 slots, the span a scan read safely), and kept for the battle in `_G.DERPY_TP_FRAGS` so a dead man still pointing at one never reads freed memory.

Tests: six new (`the_man_played_alone_points_at_a_fragment_with_no_attack_clips`, `his_own_swing_is_pushed_on_his_own_fragment`, `no_fragment_is_touched_on_another_build`, `the_man_played_alone_has_no_swing_but_his_own`, `a_single_entitys_attack_order_arms_him`, `the_next_man_is_disarmed_and_the_dead_left_alone`), watched RED (6 of 6), then **366 passed, 0 failed**. `probes/mutants_round33.py`: **21 mutants, 0 survived** (two survived the first pass - the stop's arm was invisible behind the jump's - and the test was tightened).

Live, the source bridge-loaded into the same battle (`py tools/build_third_person.py --bridge`), `zz_tp_auto_attack.lua`, three units 30 s in contact, both sides invincible, no key (`tp_auto_attack_20261016_pack.json`):

| Unit | Before (run 1 / run 2) | Pack source | Nearest enemy | Carried | Guard stops |
|---|---|---|---|---|---|
| Tyrion | 917 / 1195 frames | **0 / 2788** | 0.63 m | 4.88 m | 161 (158 melee) |
| Calith | 113 / 135 | **0 / 2732** | 1.82 m | 2.83 m | 192 (191 melee) |
| Fireborn | 188 / 258 | **0 / 2411** | 2.10 m | 1.75 m | 124 (119 melee) |

**Still open from this:**
- The guard still stops 124-192 engine melee orders per 30 s, each a direct `walk_stop` from the script thread - the crash race above is unchanged. Next experiment, written and not yet run: `probes/zz_tp_guard_no_melee.lua` leaves melee orders alone now that they cannot swing; read "carried" from the same test. If he stays put, melee leaves the guard list and the race loses ~97% of its calls.
- The player's own swings under the disarm are covered offline only. A clip the engine defers past `LOCK_WAIT` (Dragon Princes, 19:45) now finds his table disarmed again and never plays: late becomes never, unless the deferral was the engine's own swing, which can no longer run. Measure with `zz_tp_input_sweep.lua`.
- The battle was restarted in game at 20:24 before either ran; that battle runs the deployed `data/` pack, without this fix.

### The author's three reports, 20:34, measured live in their Empire vs Skaven battle

All three reproduced with probes driving the shipped frame loop (no direct combat calls), then fixed test-first.

**Horse at walking speed** (`probes/zz_tp_run_speed.lua`, Knights of the White Wolf RoR, W held, then W+Shift): his own walk `3ae2400` carried run flag 1 and the engine's run speed **7.8 m/s** (9.36 sprinting), and the horse moved **1.25 m/s** (1.31). Cause: `move.lua` put his steering point `MAN_LEAD` = 3 m ahead, and a horse runs no faster than it can stop in that distance; infantry turn speed instantly, so only horses showed it. Same run with the point 15 m ahead, nothing else changed (`TP_RS_LEAD`): **7.35 m/s** run, **8.89** sprint (3 s averages that include speeding up). Fix: `MOUNT_LEAD = 15` for a man with a mount. `..._wolf.json`, `..._wolf_lead15.json`.

**Idle frame before the shot** (script log, Hochland Long Rifles RoR, every shot): raise 1554 sent 91.8 s, reported 92.0, **no clip at 92.8**, hold 1548 at 93.0. The hold was timed `AIM_LEAD` before the raise's end counted from the raise's **report**, which lags its start by 0.2-0.31 s, so it went after the raise had ended. Fix: counted from the raise's **send** (`combat.lua`). The new test goes RED with the old timing and GREEN with the new (watched both ways).

**Melee spam near enemies** (`probes/zz_tp_melee_spam.lua`, Teutogen Guard in a real melee, the key every 0.25 s, 15 s; `tp_melee_spam_20261016_*.json`):

| Run | Swings sent | Started | Failed | Note |
|---|---|---|---|---|
| deployed (disarm) | 10 | 5 | 3 (+2 pending at the end) | every failure sent during DEFEND_1/2 (474/475) under the engine's defend command `3ae2de8`; disarmed 45-50 frames while it still waited |
| `pending` (armed until it plays, 3 s) | 10 | 8 | 1 (+1 pending) | the failure waited 2.3 s mid-block, then was replaced by the next click's swing, which played |
| `cut` (engine stop on the defend first) | 10 | 7 | 2 | **rejected**: the stop swapped the command for stand and the DEFEND clip played on under it 3.7 s, exactly as an engine swing does; and it is one more cross-thread write |

A block holds a queued clip back until it ends; the lock gave up after `LOCK_WAIT`, `move.lua` cleared `F.swung` (his clip was the block, not the swing), he was disarmed, and the swing found no clip when the block ended. The disarm turned a late swing into a lost one. Fix: `C.locked` keeps a swing that never started as `F.pending` and `main.lua` keeps him armed until it has played, `LOCK_MAX` from its send at most. A click during a block still waits for the block to end; nothing measured ends a block.

Slot names are AssetEditor's `Resources/AnimationSlots/Warhammer3AnimationSlots.txt`, id = line - 1 (474 DEFEND_1; its 1548/1554 names are off for 9.0).

Tests: four new (`a_horses_steering_point_is_far_enough_to_run`, `a_raise_reported_late_still_goes_straight_into_its_hold`, `a_swing_held_back_by_a_block_still_plays`, `a_swing_that_never_plays_gives_him_back_after_lock_max`), all RED first. `the_reload_setting_scales_one_mans_reload`'s 200% check widened from 100 to 150 ms: it measured 30,916 against 31,000 before, the fire now goes one harness frame earlier. **370 passed, 0 failed.** Mutants: round 34 **10/10 killed**; rounds 32 and 33 rerun clean (three round-33 anchors re-aimed at the line that gained `or F.pending`). Built 21:02, verified. **Not yet seen live after the fix**: the battle reached Complete (the pack switches off there by design) before a rerun.

### Deployed 21:05 (`0d0eec0c`) and rerun live, a fresh Empire vs Skaven custom battle

Game closed at the won battle's results screen with the author's go-ahead (no result saved); enabled `6a133776` backed up to `Modding Files/Backup/derpy_third_person_enabled_before_horse_shot_melee_20261016_2105.pack`; same 18 paths. The lobby's last setup was started from the frontend over the bridge (`button_battle` > `button_practice_battle` > `button_start_battle`).

- **Horse: FIXED live.** Knights of the White Wolf: run **8.02 m/s** (was 1.25), sprint **10.05** (was 1.31); a second run 7.22 / 7.17 further over the ground. Released, the horse goes **1.30 m** and stops (the CHARGE clip's tail), no overrun. `tp_run_speed_20261016_wolf_fixed*.json`.
- **Shot idle frame: FIXED live.** Hochland Long Rifles: raise 1554 at 95.4 s, **hold 1548 at 96.2 with no clip-less frame** (0 of 145 between raise and fire), fire 1557 at 97.2. `tp_shot_frames_20261016_fixed.json`. Open oddity: after the fire, `nil` at 98.2 then 1557 again at 98.4 with nothing sent - not chased.
- **Melee spam: NOT fixed under heavy contact.** Two invincible Stormvermin units teleported onto the Guard (`probes/zz_tp_engage.lua`), A/B back to back (`probes/ms_ab.sh`, `tp_melee_spam_20261016_ab*`):

| Mode | Runs (started of 10) |
|---|---|
| shipped (pending) | 2, 8, 7, 0, 1 |
| guard leaves melee orders alone | 1 |
| `engine` (a click lets the engine's own swing through: armed, melee order left alone 1.5 s) | 9, 8, 5 |
| `nodefend` (no DEFEND clips in his fragment, 0 block frames) | 9, 1 |

The rates follow the fight, not the mode. The failure that remains in every mode: **the engine's melee order (`3ad24b8`) is on him at the send; stopped by the guard he stands (`39126f0`) with no clip, armed, and the queued swing never starts in 2 s; left alone, he stands under the melee order and it never starts either.** Swings sent during his previous swing's clip (`3911fb0`) start in 200 ms every time: the engine issues no melee order while a forced clip runs. Every queue-side lever measured (stop the order, leave it, cut the block, mask 6, no block clips, let the engine swing) leaves this case failing. Getting a swing in under the engine's melee order needs the battle-thread side: the routine that turns a queued clip into `3911fb0`, called directly as `walk_start` is for the walk, or keeping the engine's melee orders off him at their source - both RE work.

**Built and deployed, 20:28.** `py tools/build_third_person.py`: 366 passed, pattern matched once, saved pack re-read (14 files, 3 loc rows). Same 18 paths as the enabled copy (`read_pack_index.py` diff). Enabled `6248975a` backed up to `Modding Files/Backup/derpy_third_person_enabled_before_disarm_20261016_2028.pack`; copied with the game shut; build and `data/` copy both **`6a1337766c0a31801bee2be7fcc092da`**. Not on the Workshop. Not yet relaunched.

### Melee spam FIXED: the queued clip's gate (RE, 21:20-22:30)

**Root cause, read off the exe on disk and confirmed live per frame.** `P.play`'s command (tag 0x28, deserializer `exe+2ecf4dc`) never starts a clip itself. It builds a clip action (vtable `exe+390c0b8`, ctor `exe+2f641b8`; payload u16 slot, u32 0x81, u32 mask, u8, u8 rider flag) in the man's **queued action slot** `+0x5c8` (has `+0x6f8`, started `+0x6f9`, action `+0x5e0`, done `+0x600`; the running slot is `+0x490` / `+0x5c0` / `+0x4a8` / `+0x4c8`). The runner `exe+3088218` starts it: action vfunc 1 `exe+2f7805c` -> the man's virtual 0x4a8 -> `exe+306e850`, which installs the forced clip `3911fb0`. His main update `exe+3086f04` (model vtable slot 3) reaches his action update `exe+3075e7c` only while `+0x324` is 0, and `+0x324` is **the kind of order issued to him this tick**: every command starter writes its own code (`306e89c` = 1, `306edf8`, the stop `walk_stop` calls, = 18, `306f1a0` = 14, ...). With a queued action pending, an order that tick sends him to `exe+306d1ac`, which **resets** the action (started and done cleared). In a melee his regiment orders him every tick, so the swing sat there. During his own forced clip no order comes, which is why a swing sent inside the previous one always started in 200 ms.

Measured (`probes/zz_tp_melee_spam.lua` now records an ordered per-frame timeline of both action slots, `+0x324` and the gate's other inputs): every failed swing sat **posted, never started** (`c00`) for its whole 2 s; `+0x324` flipped 1/0 tick by tick under stand, 18 under DEFEND, 14 under fight_c; the one time the engine did start it (`c10`) the next tick's order reset it.

**Fix: one byte.** `exe+3087388` `75 5c` (jne to the reset `30873e6`) becomes `75 52` (jne to `30873dc`, the action update). `platform.lua` `P.gate`: memreader Plus `mr.patch`, which writes only over the 18 bytes it expects at `exe+3087378`, both ways; `main.lua` puts it in while a man is played alone and takes it out at the stop; the platform takes it out as it loads (a battle left mid-control). Build 6acec6f4 only (`queued_gate` in BUILDS); any other build logs once and carries on without it. It is game code, so it runs on the battle thread with nothing to race (memreader's Lua hooks never run on other threads - its README). Ceiling, marked `ponytail:` in the source: while it is in, a queued action on **any** man beats that tick's order; in a battle the pack plays, only `P.play` queues one. A per-man check would need a code cave.

**Live, the hard case.** The author's suggestion (22:10) made the tests last: `probes/zz_tp_freeze.lua` makes all 40 units invincible, fearless and holding fire and halts all 20 enemy units under script controllers; `zz_tp_engage.lua` then sets two Clanrat units on the Guard. Clicks every **2.4 s** (`PERIOD=2.4 DURATION=24 sh ms_ab.sh ...`), so each lands after his last swing has ended, under the engine's orders. At 0.25 s every click lands inside the previous swing and both modes pass (shown at 21:51-21:56: 9 of 10 everywhere).

| Run | Started of 10 |
|---|---|
| deployed `0d0eec0c` (no gate) | 4, 0 |
| probe-applied gate | **10, 10** (200-400 ms; one run 414 block frames) |
| new source, shipped path (bridge-loaded) | **10, 10, 10** at normal speed (566 and 117 block frames), plus 10, 10, 10 in slow motion |
| same source, `nogate` (only `P.gate` stubbed) | 10 (0 block frames), 7, 9 (886 and 676 block frames, delays to 1.8 s) |

The battle had been left in slow motion; `zz_speed.lua` with `_G.TP_SPEED = 1` put it back (22:17).

**Regressions with the gate in, same battle:** shot 1554 -> 1548 -> 1557 with **0** clip-less frames (`tp_shot_frames_20261016_gate.json`); horse run **8.02** m/s, sprint **10.05**, stops 0.22 m after release (`tp_run_speed_20261016_wolf_gate.json`); no auto attack **PASS**, 0 attack clips in 2305 frames, enemy at 0.36 m, in melee 1833 frames (`tp_auto_attack_20261016_gate.json`). The gate byte read back `5c` after every stop.

**Tests:** four new - `a_queued_swing_beats_the_ticks_order`, `a_battle_left_with_the_gate_on_finds_it_off`, `the_gate_is_left_alone_where_it_is_not_the_gate`, `the_gate_is_in_while_a_man_is_played_alone` - all RED first, then GREEN. **374 passed, 0 failed.** Mutants: round 35 **11/11 killed**, source restored byte for byte; rounds 32-34 rerun, 51 killed, none stale.

**Built 22:27**, `Modding Files/Modpacks/derpy_third_person.pack` **`4ce7676e9f88ed6e51cfdff6cebd2367`**, re-read (14 files, 3 loc rows); same 18 paths as the deployed `0d0eec0c`. **Deployed 22:30** with the author's go-ahead: game closed (a custom battle, nothing saved), `0d0eec0c` backed up to `Modding Files/Backup/derpy_third_person_enabled_before_gate_20261016_2230.pack`, build and `data/` copy both `4ce7676e`. Not on the Workshop. Not yet relaunched; the game is still on the test settings (1280x720, muted; `Modding Files/Backup/preferences.script.txt.before_test_20261016` restores them).
