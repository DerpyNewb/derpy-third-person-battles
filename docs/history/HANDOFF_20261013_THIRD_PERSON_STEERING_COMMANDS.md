# Handoff 2026-10-13: third-person steering and held fire

**Latest continuation:** [held fire, mounted attacks, and unresolved F2 movement](HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md). The author confirmed held fire and mounted attacks. The first F2 idle fix failed live; the later native handover experiment remains unverified. Fresh selftest is **106 passed, 1 failed**. The 107-test/35-mutant results below predate that experiment; generated bridge chunks are stale. No pack built or deployed.

Continues [the first live runs](HANDOFF_20261013_THIRD_PERSON_PACK_LIVE.md), Task 13 of
`docs/superpowers/plans/2026-10-13-third-person-pack-core.md`.

## Ownership and deployment

- Maintained source: `Modding Files/source/third_person/script/derpy_tp/`.
- Generated data: `script/derpy_tp/data.lua`, owned by `tools/build_third_person.py --gen`.
- Generated bridge chunks: `Modding Files/source/lord_control/probes/zz_tp_load_01..12.lua`
  and `zz_tp_load_run.lua`, owned by `--bridge`. Each part stays below the bridge size limit.
- Destination pack: `Modding Files/Modpacks/derpy_third_person.pack`. No pack built or deployed
  in this continuation; no enabled game copy. Tests run from bridge-loaded source.

## The crash's root cause

The earlier handoff called `+0x368/+0x370` a shared steering/aim point. The stronger finding is
that **`model+0x330` is an embedded polymorphic command object**. Its payload changes meaning
when the command type changes. A coordinate observed there does not establish a permanent
coordinate field.

Read the dump's **MemoryList/Memory64List** ranges for the faulting stack at
`0x7ff49441fa98`. The thread-list stack used by `dump_stackscan.py` did not expose these return
addresses in this dump. The captured stack contains:

| Stack offset | Return address in exe | Meaning |
|---|---|---|
| `+0x0` | `3079076` | state-change routine's variant-table call |
| `+0x80` | `30788b2` | wrapper calling the state-change routine |
| `+0xc0` | `3082cbf` | current command supplies its pending state |
| `+0xf0` | `3080f87` | invokes command vtable slot `+0x10` |

At `exe+3082cb7`, `mov edx, [rbx+0x38]` reads the requested state; `rbx` is the command
at `model+0x330`. Thus it reads **model+0x368**, exactly the field the unconditional steering
write corrupted. `exe+3082cba` calls `307885c`, which calls `3078b1c`; that routine stores
the resulting state at `model+0x318` and calls the variant picker at `3079071`.

The dump's model is `0x1233cb4c0`. Its command vtable is `exe+390d090`, whose slot `+0x10`
points to `exe+3082c58`, the state-change command just traced. `model+0x368` holds
`0xc21629f4`, the model's x coordinate, rather than an integer animation state.

## Live command layouts, build 6ac6d907

| Current command vtable in exe | Observed state | Meaning at command `+0x38` / model `+0x368` |
|---|---|---|
| `3914618` | idle/formation | payload is not a walking point; `+0x36c` can hold integer 129 |
| `3912b98` | regiment walking under a move order | x/z point at `+0x368/+0x370` |
| `3add278` | walking back to a formation slot | x/z point at `+0x368/+0x370` |
| `3913a68` | firing, ammo decreasing, model state 19 | firing payload, not a walking point |
| `390d090` | pending state change in the crash dump | integer animation state at `+0x368` |

Static confirmation: `3912b98` slot `+0x10` is `325fd00`, which calls `3256180` and reads
the command point at `+0x38`; `3add278` slot `+0x10` is `325d9e0`, which calls `3255ff0`.
The latter reads x at `command+0x38` and z at `command+0x40`.

`tp_walk_20261013.npz` in the probe directory captures 120 read-only external samples,
showing the idle -> move-order -> formation-walk command changes. It was recorded against
one model at `0x127242d10`; those heap addresses belong to that battle only.

## Changes and rulings

- `platform.lua`: keep the two persistent steering copies; write `+0x368/+0x370` only when
  the current command vtable matches one of the two verified walking types.
- When a movement point is requested from an idle/firing/state-change command, start a walk
  through **`exe+306a8fc`**, the engine wrapper that destroys the old embedded command and
  constructs `3add278` through `32490d0`. Do not replace a vtable or write coordinates into
  the existing command. A point within 0.1 m of the model does not start a new walk.
- `BUILDS` gains `walk_a`, `walk_b`, `walk_start` and `walk_speed`. Their literals pass the
  float32-exactness check.
- `features.steer` is false for unknown builds. `main.lua` then plays regiments whole and
  logs the reason once. The animation byte pattern still works; it does not identify walking
  command types. This intentionally narrows the earlier all-features pattern fallback.
- Solo start calls `halt()` after `fire_at_will(false)`. The first cycle run showed ammo
  decreasing while solo mode was active because a pre-existing targeted fire order remained.
- `move.lua` now uses the native command and **has no position nudges or stuck heuristic**.
  The earlier pre-nudge stuck sample did mistake our own shove for engine movement, but
  correcting it was insufficient from a fresh halted/firing soldier. A six-second test still
  moved only the two scripted nudges. That experimental change was superseded and removed.
- The walking command's run flag is an integer at `model+0x390`; its speed is a float at
  `model+0x394`. `exe+3036640(unit, run)` returns the native unit walk/run speed, retaining
  modifiers. **A `float(...)` memreader call returns a Lua number directly**; passing it
  through `mr.tonumber` truncates it (1.5 became 1 in the probe). Shift is passed from
  `move.lua` through `P.steer` to that native speed selector.
- Speed alone did not change the gait. For command `3add278`, the gait byte is
  `model+0x3ae` (command `+0x7e`, parameter `+0x46`). The earlier constructor hard-coded it
  to 1, so every walk played a run. It now follows Shift. A changed gait/command heading
  clears the command's initialized byte at `model+0x3c0` (`+0x90`), so `3255ff0` refreshes
  the cached movement parameters through `3071e04`.
- Individual facing is a uint16 at `model+0xb0`, full turn = 65536. Read-only samples match
  native movement headings (180 degrees initially, ~177.8 while ordered, 64.6875 when
  the model re-aligned with its regiment). The controlled model now holds camera yaw there;
  command `3add278` also receives that heading at `model+0x398` (`+0x68`). This prevents the
  controlled soldier from adopting his regiment's facing, including while idle.
- `main.lua` hides CA HUD children except the porthole, preserves its model/mask/ability
  children, and hides battle markers/menu/advisor/mod launch overlays. The crosshair and
  custom HUD remain independent. Visibility is recorded by component id and restored on
  F2 off, error, battle end and reload; originally hidden components stay hidden. No root
  or `panel_manager` is hidden, so menus remain available. Snapshot handles are resolved
  again on restore, rather than cached across redraws.
- No timed fire-at-will delay: the established corruption is a wrongly typed payload write,
  rather than a stale coordinate that needs a few frames to expire.

## Native walk constructor, measured and traced

`306a8fc(model, params)` takes two pointers. It uses `model+0x328` as the command owner,
calls `2db0a10` to destroy the old command, then calls `32490d0(model+0x330, owner, params)`.
The base constructor `304e580` sets the command's model pointer and activates the owner;
the walking constructor copies the 0x58-byte parameter block.

The initialized block follows the engine's own builder at `3249284`:

| Parameter offset | Value |
|---|---|
| `+0x0/+0x4/+0x8` | target x/y/z; y from the model |
| `+0x10/+0x18/+0x38/+0x50` | null path pointers; no borrowed path lifetime |
| `+0x28` | integer run flag |
| `+0x2c` | native speed, from `3036640(model+0x2e8, run)` |
| `+0x30` | heading as uint16, full turn = 65536 |
| `+0x34` | integer 3 |
| `+0x44/+0x45/+0x4a` | byte 1 |
| `+0x46` | byte 0 for walking, 1 for running |
| `+0x4c` | model time in seconds |

Zeroed flags alone constructed the right type but moved nothing; the engine builder's flags
made it move, with measured velocity increasing from 0.3 to 1.5 m/s. Formation logic then
returned it to its slot unless its command point was held. Combining native start with the
per-frame gated point moved the test man 6.09 m in six seconds, neighbour 0 m. This prototype
still had nudges; the maintained final implementation removes them and is tested separately.

## Verification before the final F2 experiment

- `py tools/build_third_person.py --selftest`: **107 passed, 0 failed**, exit 0, including
  luac, engine API/literal checks, data/loc checks and the exe pattern check.
- The walk-command, unknown-build fallback, prior-attack halt, native-start and native-run
  tests each went RED before implementation, then GREEN. The fallback test initially used
  an incorrect harness call name/men option; corrected before GREEN. The obsolete stuck
  test was removed with the heuristic. Wall and pause tests now measure steering/absence
  of any teleport, rather than count the removed nudges.
- `py tp_mutate.py mutants/mutants_steer.py`: **18 killed, 0 survived or stale**. Source restored
  byte for byte after every mutant.
- Temporary guarded live walk: 17.20 m in six model seconds; neighbour moved 0 m. A separate
  three-second walk followed by six seconds idle drifted 0.085 m after release.
- First eight walk/stop handovers, enemy 55 m ahead: completed, zero Lua strikes, no crash.
  This run exposed the retained attack-order issue; do not use it as proof of solo firing
  isolation. The crossbowmen/cannon were subsequently eliminated after the other enemy pin
  callbacks were removed; the author restarted the battle for final validation.
- General: input/anim/wheel/men/steer true, on true, one_man false, men_ok true.
- Animation pattern route repeated live: source `byte pattern`, anim true, 0.021 s search.
- Maintained native-start source (before the final gait/facing/HUD fold): eight handovers
  completed, zero strikes/no crash, each two-second walk moved about 2.4-3.0 m with no
  position writes. Ammo stayed 1962 in that run. Later reads put the enemy about 570 m away,
  so do not label it an enemy-in-range firing restoration test.
- Author then reported running instead of walking, Shift not changing gait, too much UI,
  and the model adopting the regiment's facing. After the three live probes, the author
  selected **"All three behave correctly"** for gait, independent facing and HUD visibility.
  Those probes were folded into source and the temporary HUD callback removed before reload.

## Held fire and mounted attacks (same continuation)

The author clarified that holding left mouse must run the full fire/reload cycle and wait
until reloaded. The old code queued reload 300 ms after fire, then repeated on a guessed
`base_reload_time * 0.25` timer. It could cut both clips short.

- `combat.lua` now tracks ready -> fire -> reload -> ready, including observing the requested
  slot actually start. Only held input or a queued click starts the next cycle. Release finishes
  the current reload; F2, mode change, death/replacement and errors clear the pending cycle.
- Projectile release follows **300 model milliseconds after the firing slot starts**, rather
  than a real-time callback after queueing. Pause/game speed therefore also affect release.
  Walking commands are suppressed during a cycle; individual facing still follows the camera.
- Projectile origin is now 1.5 m forward, retaining 1.5 m height. The earlier 0.6 m source run
  switched to `HIT_REACTION_SHOOT_STAND_1` shortly after launch. The new crossbow run had no hit
  reaction interruptions; self-collision was a hypothesis, not an isolated damage measurement.
- `P.has_slot` follows the native lookup at `exe+1482074`: `[model+0x308]+0x50+slot*2`
  holds the fragment row index, or `0xffff` when absent. This reads the model's active fragment,
  including mod overrides. `P.reload_slot` prefers 1564 (`RELOAD_1`), else 1554
  (`SHOOT_READY_TO_AIM_LEVEL`). No extra generated animation table is retained.
- Crossbow fragments have 1554 and no 1564; ironhail fragments have both. Crossbow's native
  firing cycle confirmed 1554 between shots. Unit types without a supported reload or fire
  clip use the regiment's ground fire. `data.lua` retains its original three-field shot rows.
- **`model+0x898` is animation event metadata, not a universal playback handle.** The earlier
  experiment that called 1441 a resolved reload was wrong: it is `SHOOT_STAND_IDLE_4`.
  `model+0x278` can also remain stale after a clip. The `+0x18f` candidate stays 1 throughout
  forced fire and is not its completion signal.
- Reload must use **full-body playback**: the command's `+0x14` is a body-mask enum (the
  exe's enum table at `3920cd0` gives 0 NONE, 1 TORSO_AND_ARMS, ... 6 FULL_BODY).
  `P.play(model, reload_slot, 6)` takes the native `307e5a4` path and holds mask 6 at
  `model+0x284` until the clip ends. The default metadata path (`307ccf0`) immediately loses
  reloads without metadata. **Native wait command `325c7ec` checks both `+0x898` and `+0x284`**;
  `P.anim_slot` returns nil only when both are clear. Fire/melee keep mask 0 so their animation
  events still run. A direct ironhail probe held slot 1564/mask 6 for 14 model seconds and then
  mask cleared. Its shipped `.anim` header also gives 14.0 s, fire 1.4 s, ready-to-aim 0.7 s.
- Removed the MCT reload-factor slider and settings field: readiness follows complete native
  playback, not that multiplier. This follows the author's explicit full-loop requirement.
- The author also reported foot attacks on a mount. Swings now prefer supported
  `RIDER_ATTACK_1..7` (1901..1907), or `RIDER_FLY_ATTACK_1..7` (1941..1947) when CA's
  `unit:is_currently_flying()` returns true. Missing variants fall back to the first supported
  attack in that rider family; foot units retain `ATTACK_1..7`. `P.mount` reads the rider parent
  at +0x2e0, also followed by native 305468c. The parent receives matching `ATTACK_1..7` or
  `FLY_ATTACK_1..7` (494..500), retaining its metadata/hit events. The mounted rider fragment
  has an empty locomotion graph and names the mount fragment, so playback goes through the
  mount. **Do not queue both rider and mount commands: the second cancels the first.** Live
  tests proved this in both orders and with masks 1 and 6. Detached riders without a parent
  retain a mask-6 rider clip; normal mounted models receive one parent command per swing.
  Each rider/mount pair is resolved separately.
  Yang's Longma fragment contains foot and rider slots, which explains why merely requesting
  the old foot slot was accepted but visually wrong.

Validation: 107 offline tests pass, including queue rejection, missing reload fallback,
requested-slot start, full clip waits, release, paused projectile release, body-mask completion
and ground/air mounted attack selection. `mutants_steer.py`: 18 killed; `mutants_fire_cycle.py`:
13 killed, no survivors/stale anchors in these two sets. The release-delay mutant initially
survived a test that never supplied a playing clip; it was correctly paired with the model-time
release check, which kills it.

Live bridge probes are `zz_tp_fire_cycle.lua` and `zz_tp_mounted_attack.lua`. They store
`TP_FIRE_CYCLE_TEST` / `TP_MOUNTED_ATTACK_TEST`; the fire test holds input for 28 model seconds,
releases, and restores the original input functions after 41. Enemy controllers are retained
in `TP_AI_CONTROLLERS`; enemies are held outside range in the restarted test. Earlier native
comparison orders brought a target close and the ironhail regiment was eliminated; that
battle was restarted. Do not repeat native comparison tests beside the player without keeping
the target from fighting back.

The earlier crossbow run (before adding full-body mask 6 and runtime slot lookup) completed
nine cycles, ammo 3062 -> 3053, zero strikes, ready after release. Its full trace is
`tp_fire_cycle_crossbows_20261013.json` in the probe directory. Final-source crossbow/gun
and mounted results follow.

- Final ranged source: crossbows completed nine cycles, ammo 3960 -> 3951, zero strikes,
  ready after release; `tp_fire_cycle_crossbows_final_20261013.json`.
- Full-body/runtime-lookup gun source: two cycles, ammo 3956 -> 3954, each reload held slot
  1564 for 14 model seconds, zero strikes, ready at 31.3 s after release at 28 s;
  `tp_fire_cycle_ironhail_20261013.json`. Subsequent code changes affect mounted melee only.
- Final mount dispatch: flying Yang/Longma parent played slot 494 (`FLY_ATTACK_1`) for
  ~1.4 model seconds with zero strikes; `tp_mounted_attack_20261013.json`. The rider has no
  separate metadata handle during inherited mount playback; the author confirmed its mounted appearance.
- No pack is built or enabled. The live source has all input, animation, wheel, men and steering
  checks enabled; the author subsequently confirmed both held fire and mounted attacks.

## F2 idle movement and ability target correction

After confirming both held fire and mounted attacks, the author reported that F2 itself moved
units forward without W. The native walking cache explained the delayed stop/response:
`3255ff0` returns without copying a new destination while command+0x90 is initialized and
model+0x710 is non-zero. Earlier code invalidated this cache only for gait/heading changes.

- `P.steer` now also invalidates the walking cache when its x/z goal changes. This refreshes
  both steering and the own-position hold point immediately on the next native tick.
- F2 start halts prior orders for every unit, not just solo ranged units. It also places the
  controlled soldier's hold point at his current position before the first frame.
- `move.halt` cancels a living soldier's old forward lead point on F2 off, as well as halting
  whole-unit orders. A dead model is never read during cleanup.
- Three regression checks went red before these fixes: an existing movement order with no
  pressed keys, a changed goal with unchanged gait, and the forward lead surviving F2 off.
  Ground-fire tests now subtract the startup halt from their counts.
- A physical number-key test exposed `abilities.lua:53`: native `perform_special_ability(key)`
  throws "battle.unit expected, got no value", despite the CA doc marking its target optional.
  Self/unknown abilities now pass the caster explicitly. Harness enforces that native target
  contract; the self-target test went red before the fix.

Pre-experiment validation: **107 tests**, **21 steering mutants + 14 fire/mount/ability mutants** passed. The later experiment has one failing test; see the latest continuation.
`zz_tp_idle_handover.lua` starts during a prior walk, then measures idle -> W -> release ->
F2 off -> F2 on idle with no physical key overrides left after 10.5 model seconds. Its result
is `TP_IDLE_HANDOVER_TEST`; final live movement/ability results follow after measurement.

## Next steps

Maintained source is bridge-loaded; no pack is built or deployed. User confirmed walking,
run toggle, independent facing and HUD filtering before the ranged changes. Final held-fire
and mounted source are loaded. Automated held-fire cycles passed; the author confirmed held fire and mounted attacks. The first F2 idle/response correction failed its live test; the later steering experiment is unverified. Continue from the latest handoff linked above. No input overrides remain after the fire probes.

Tasks 14-16 still contain unmeasured projectile timing/kill attribution/buffs, other unit kinds,
manual-fire shortcut/camera drift and pack/release tests. HUD plan 2's custom health/ammo panel
is not built. Current readbacks/hashes are evidence for this build and battle only.
