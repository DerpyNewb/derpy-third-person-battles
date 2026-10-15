# Handoff 2026-10-13: held fire, mounted attacks, and unresolved F2 movement

**Superseded for F2 movement by [the 2026-10-14 fix](HANDOFF_20261014_THIRD_PERSON_F2_STOP.md):** the drift
was a finished walk coasting until its command is replaced; `P.hold` now calls the engine's stop. The held-fire
and mounted sections below stay current.

## Current state — read first

Continues [the steering-command investigation](HANDOFF_20261013_THIRD_PERSON_STEERING_COMMANDS.md)
and [the first live runs](HANDOFF_20261013_THIRD_PERSON_PACK_LIVE.md). This is the current
continuation record for the core third-person pack. The user requested this handoff while
the F2 movement investigation was unfinished; implementation was left in place for resumption.

- **User confirmed:** walk/run and Shift, independent facing, selective HUD hiding; later,
  full held fire/reload and correct mounted attacks ("Both behave correctly").
- **Open bug:** pressing F2 moves the controlled soldier forward without W. Input must be
  responsive, including stopping after release. The first attempted fix failed live.
- **Latest source is experimental:** `P.steer` now converts a regiment-walk command into an
  individual-walk command through the native constructor. This has no valid active-control
  live verification yet.
- **Fresh check at handoff:** `py tools/build_third_person.py --selftest` exits 1:
  **106 passed, 1 failed**, `steering_writes_the_walk_command_point` at
  `tools/third_person_tests.lua:1113`. Do not build or release from this state.
- **No pack built, deployed, or enabled.** The battle tests use bridge-loaded source.

The previous 107/107 and 35 killed mutants describe the source before the latest experimental
steering branch. They are dated evidence, not the current build gate.

## Ownership, changed files, and live loading

| Layer | Location and state |
|---|---|
| Maintained source | `Modding Files/source/third_person/script/derpy_tp/`; session changes in `platform.lua`, `main.lua`, `move.lua`, `combat.lua`, `abilities.lua`, and `settings.lua` |
| Battle entry | `Modding Files/source/third_person/script/battle/mod/derpy_third_person.lua` |
| MCT source | `Modding Files/source/third_person/script/mct/settings/derpy_third_person.lua`; removed the obsolete reload-factor slider |
| Generated data | `script/derpy_tp/data.lua`, owned by `tools/build_third_person.py --gen`; three-field shot rows retained, no generated reload table; 493 land types and 1,884 abilities |
| Offline checks | `tools/third_person_harness.lua`, `tools/third_person_tests.lua`; strict ability target contract and new fire/mount/steering checks |
| Generated bridge | `Modding Files/source/lord_control/probes/zz_tp_load_01..12.lua` and `zz_tp_load_run.lua`, owned by `--bridge`; **stale relative to the final `P.steer` experiment** |
| Live environment | `DERPY_TP`; last full reload includes the initial F2 fixes and explicit self-ability target; `zz_tp_refresh_steer.lua` then replaced only `E.P.steer` with the latest experimental closure |
| Destination pack | `Modding Files/Modpacks/derpy_third_person.pack`, absent; no deployment copy or Workshop release |

The workspace root has no Git repository. Probes and JSON evidence are under
`Modding Files/source/lord_control/probes/`. New probes used here include
`zz_tp_fire_cycle.lua`, `zz_tp_mounted_attack.lua`, `zz_tp_idle_handover.lua`, and
`zz_tp_refresh_steer.lua`. The last is a snapshot of an experimental module, not maintained
source; regenerate the full bridge when resuming.

## Confirmed held-fire behavior

The user's requirement is **hold left mouse for fire → full reload → fire**. The old guessed
reload multiplier and early reload queue could cut clips short. Source now tracks
ready → fire → reload → ready and observes the requested animation actually start.

- Launch once, **300 model milliseconds after fire starts**; remember the shot's aim.
  Model time respects pause/game speed. Ironhail's three projectiles consume one unit ammo.
- Wait for fire to finish, request the model's supported reload, then wait for full completion.
  Releasing finishes the current reload; held input or a queued click starts another cycle.
- Movement commands cannot replace an active firing/reload cycle; facing still follows the
  camera. F2, mode change, model loss, and error cleanup clear the pending cycle.
- `P.has_slot` follows native `exe+1482074`: the uint16 row at
  `[model+0x308]+0x50+slot*2` is `0xffff` when absent. It reads the active fragment, including
  mod overrides. `P.reload_slot` prefers 1564 `RELOAD_1`, otherwise 1554
  `SHOOT_READY_TO_AIM_LEVEL`. Unsupported fire/reload uses regiment ground fire.
- **Completion requires both event metadata `model+0x898` and body mask `model+0x284` clear.**
  Native wait command `325c7ec` checks both. Slot `+0x278` can remain stale, and metadata is
  not a universal playback handle. `+0x18f` stayed 1 throughout firing; slot 1441 is
  `SHOOT_STAND_IDLE_4`, not a resolved reload.
- `P.play(model, reload_slot, 6)` uses **FULL_BODY**. Command `+0x14` is the body-mask enum,
  not a boolean. Mask 6 takes native `307e5a4` and persists through metadata-free reloads.
  Default mask 0 takes metadata playback (`307ccf0`); keep it for fire/melee hit events.
  Enum table is `exe+3920cd0` (0 NONE, 1 TORSO_AND_ARMS, …, 6 FULL_BODY).
- Projectile origin changed from 0.6 to 1.5 m forward, retaining 1.5 m height. Old launches
  showed a hit-reaction interruption; new cycles did not. Self-collision remains an
  inference, not a measured damage result.

Final crossbows: nine cycles, ammo **3960 → 3951**, zero strikes, ready after release.
Ironhail: two cycles, **3956 → 3954**, reload slot 1564 held **14 model seconds**, ready at
31.3 s after release at 28 s, zero strikes. Crossbows use 1554 (~1.3 s), fire ~1.8 s.
Ironhail's native `.anim` header also gives 14 s reload; fire is 1.4 s.

Evidence files: `tp_fire_cycle_crossbows_final_20261013.json`,
`tp_fire_cycle_ironhail_20261013.json`. Earlier `tp_fire_cycle_crossbows_20261013.json`
predates full-body/runtime reload lookup and is retained as historical evidence.
The user confirmed the held-fire loop visually after the final load.

## Confirmed mounted attack dispatch

Foot slots 454..460 existed in the rider fragment and were accepted, producing the wrong pose.
Source selects supported `RIDER_ATTACK_1..7` (1901..1907), or
`RIDER_FLY_ATTACK_1..7` (1941..1947) when CA's `unit:is_currently_flying()` is true.
Missing variants fall back to the first supported member of the same family.

`P.mount` resolves the rider parent at `model+0x2e0`, also followed by native `305468c`.
**Send one animation to the mount:** selected rider slot minus 1447 gives ground 454..460 or
flying 494..500. Retain mask 0 for its hit metadata. The rider fragment has an empty
locomotion graph and inherits its named mount fragment. **Queuing both rider and mount
cancels the first**, tested in both orders and with masks 1 and 6. Detached riders without
a parent retain a mask-6 rider fallback; foot models retain ordinary foot attacks.

Yang's Longma (`wh3_dlc24_cth_cha_celestial_general_yang_longma`) played mount slot 494
`FLY_ATTACK_1` from ~100 to 1,500 ms, zero strikes. Evidence:
`tp_mounted_attack_20261013.json`. User confirmed the correct mounted appearance.
Other mounted/flying unit types remain to be tested.

## Ability target correction: offline verified, live cast pending

A physical number-key press logged `abilities.lua:53`, "battle.unit expected, got no value"
in `script_log_131026_2124.txt` (line 295). CA documentation marks the target optional, but
this native call rejected omission. Self/unknown abilities now call
`F.uc:perform_special_ability(key, F.unit)`. The strict harness target check went red, then
green. The correction is in maintained source and the last full live reload, but a successful
live cast after it has **not** been verified.

Available General examples at the last inspection: potion of speed (self), celestial sweep
(self), lord of Grand Cathay (ground). Reinspect readiness before testing.

## F2 movement: failed first fix and current experiment

First attempted fixes, loaded together:

1. Invalidate individual walk command cache `model+0x3c0` when x/z target changes, as well as
   gait/yaw. Native `3255ff0` returns without copying a new goal when command `+0x90` is set
   and `model+0x710` is nonzero.
2. `main.start` halts prior orders and releases control for all units, then sets the current
   soldier's hold point before accepting input.
3. `move.halt` replaces a living model's old forward lead with its own position, including
   F2 off. Never read a dead model during cleanup.

The three regression checks passed and the then-current suite was 107/107. **Live failed**:
`zz_tp_idle_handover.lua` induced a previous regiment move, then measured 2 s each of
F2 idle, W, release, F2 off, and F2 on idle. Input was scripted; its original functions were
restored after 10.5 model seconds. Zero strikes, but movement continued:

| Stage | Movement over sampled stage |
|---|---:|
| F2 on, no W | 2.468 m |
| W held | 2.650 m |
| W released | 2.850 m |
| F2 off | 2.850 m |
| F2 on again, no W | 2.758 m |

Saved full trace: `tp_idle_handover_20261013.json`. These figures describe the first attempt,
not the final experimental branch. Later inspection found the current command was still
**regiment walk `3912b98` (walk_a)**. Its cached motion/layout differs from individual walk
`3add278` (walk_b); `model+0x3c0` read 34 and cannot be treated as walk_b's initialized flag.
The hold goal and command point were at (-37.32, 286), while actual position was
(-38.35, 263.88), with all movement keys false. Goal writes alone were insufficient.

Latest maintained **experiment** in `platform.lua:P.steer`:

- Only walk_b receives in-place point/speed/gait/heading/cache writes.
- An existing walk_a is replaced through native `306a8fc(model, params)` even when the
  requested goal is the model's own position. This is intended to take control of cached
  regiment motion. Other idle/animation commands still avoid a new walk within 0.1 m.
- Constructor flags remain `params+0x34=3`, bytes `+0x44/+0x45/+0x4a=1`;
  `+0x45` invokes path conversion through `307f5c8`. Whether these flags contribute to
  overshoot is still unverified. Do not tune them without evidence.

`zz_tp_refresh_steer.lua` installed only this function and sampled four seconds. The user
turned F2 off during that probe, so **it does not validate active idle control**. Net movement
was ~0.634 m with ~2.6 m excursion; command types included `390ce10` and walk_b. Saved:
`tp_refresh_stop_20261013.json`. Last readback had F2 off and no input overrides remaining.

The old offline point-write test expects both walk_a and walk_b to be updated in place;
it now fails for walk_a. Do not simply delete that case to obtain green: verify the proposed
native handover, then update/add the appropriate contract check. Steering mutant anchors
also still name the former two-type branch and need review if this experiment is retained.

## Safety and native facts to preserve

See the previous steering handoff for dump/disassembly detail. `model+0x330` is an embedded
**polymorphic command**, not permanent steering storage. The crash's state-change command
read `model+0x368` as an integer animation state after an unconditional x write.
Never restore unconditional third-copy writes or forge a command vtable.

Known build is `6ac6d907`; unknown builds have `features.steer=false` and use whole-regiment
movement. The native walk constructor at `306a8fc` destroys the prior owner/command and
constructs walk_b through `32490d0`. Native speed `3036640(model+0x2e8, run)` returns a Lua
float directly; `mr.tonumber` truncates it. Heading is uint16, full turn 65536, at model
`+0xb0` and walk_b `+0x398`; gait byte is walk_b `+0x3ae`. Do not apply walk_b payload/cache
semantics to other types. No maintained movement nudges remain.

HUD state is saved by component id and resolved again on restore. Keep the portrait/model,
mask/abilities, crosshair/custom root; restore original visibility on F2 off/error/reload.
`SetVisible` takes a real boolean; never hide root/panel_manager or cache stale handles.

## Resume steps and remaining scope

1. Read this handoff, the earlier native-steering evidence, current `P.steer` and its callers
   (`move.step`/`move.halt`, startup/stop). Reproduce F2 with no movement keys in a fresh battle.
   Keep enemies outside range; earlier native-comparison probes eliminated the ironhail unit.
2. Decide whether the walk_a → walk_b experiment actually stops movement. Verify an active
   idle/W/release/off/on handover without a concurrent manual F2 toggle. Measure both the
   controlled model and neighbours, command type, goal/cache, and input. Update meaningful
   harness/mutation coverage for the verified command contract; keep the build gate honest.
3. Regenerate/load the complete bridge when testing maintained changes:

   ```powershell
   py tools/build_third_person.py --selftest
   py tools/build_third_person.py --bridge
   Set-Location -LiteralPath 'Modding Files/source/lord_control/probes'
   Get-ChildItem -LiteralPath . -Filter 'zz_tp_load_*.lua' | Sort-Object Name | ForEach-Object {
       py send.py $_.Name 20
       if ($LASTEXITCODE -ne 0) { throw 'Bridge load failed' }
   }
   ```

   Run the first two commands from the workspace root. Inspect tool entry points before
   changing modes: **no-flag `build_third_person.py` builds a pack**. Do not overlap this
   loader or any `send.py` with WH3 MCP calls: they share the command file and overwrite
   one another. Wait for the loader process to finish before inspecting the live environment.
4. If retaining the new branch, revise stale mutation anchors and run
   `py tp_mutate.py mutants/mutants_steer.py` and
   `py tp_mutate.py mutants/mutants_fire_cycle.py` from the probe directory. Last pre-experiment
   results were 21 steering and 14 fire/mount/ability killed, no stale/survivors; not rerun for
   the final experiment. Verify self-target ability casting live, then recheck confirmed
   movement/facing/HUD/fire/mounted behavior after the final movement change.
5. Core Tasks 13–16 remain incomplete. Outstanding: other unit kinds, projectile release
   calibration, buffs/accuracy/kill attribution/friendly damage, firing isolation/restoration
   with an enemy in range, artillery/manual-fire shortcut, fast-mount camera drift, pack
   build/export/source comparison and release. HUD plan 2's custom health/ammo/hotbar is unbuilt.

The last battle had player General, ironhail gunners, crossbowmen, and cannon; enemy controllers
were retained in `TP_AI_CONTROLLERS`. All live heap addresses and animation/build observations
are evidence for that battle/build only. No new crash was observed after the earlier 19:14 dump.
