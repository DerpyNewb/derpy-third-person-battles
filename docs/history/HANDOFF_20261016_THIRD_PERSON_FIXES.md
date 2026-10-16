# Third-person pack: open bugs, 2026-10-16

**Continued in [physical mounts and HP-zero handover](HANDOFF_20261016_THIRD_PERSON_MOUNTS_AND_DEATH.md).** The findings below are the starting reports, not the status after that continuation.

Starting pack: `data/derpy_third_person.pack`, md5 5f4925ee (built 15:46, deployed 15:48).
Source `Modding Files/source/third_person/script/derpy_tp/`. Ledger `.superpowers/sdd/2026-10-14-third-person-hud/progress.md`,
rounds 30-31. Nothing below is fixed. **Do not call anything fixed until it is measured on the author's own units**:
the round 30 guard was measured on one Tzar Guard man, called verified, and the author still sees auto attacks.

## Why it differs by unit

Every engine address the pack uses (command vtables at model+0x330, clip rows, steering) was measured on a few
infantry men. Cavalry, riders, single-entity lords and monsters are other model classes with other commands and clip
rows, so the same code does different things on them. The fix for the inconsistency is the per-unit test run below,
not more single-unit probes.

## Open bugs (author's reports, with evidence)

| # | Report | Evidence | Lead (unmeasured) |
|---|---|---|---|
| 1 | "ITS STILL AUTO ATTACKING" | Fireborn (cavalry, one man) log: `his command other, action 454` | `P.guard` (platform.lua:351) stops only walk_a 0x3919350, move_a 0x39199f8, move_b 0x3ae1928, melee 0x3ad24b8 (exe offsets, build 6acec6f4). Cavalry and other classes put different commands on him |
| 2 | Swings do nothing in melee | Calith Gatekeepers, one man: 6x `clip 45x never played: in melee true, his clip nil` (script_log_161026_1607) | The engine's melee replaces the pack's forced clip, then the guard stops the melee, so nothing plays. Compare guard on/off |
| 3 | "no attack being triggered as tyrion" | Tyrion played whole: every click logs `attack order on ...`, re-sent every 2-3 s, he never fights | `swing()` (combat.lua:202) found no attack clip on his rider/mount, fell to `order()` (combat.lua:178). Why the attack order itself does not engage is unknown |
| 4 | "cant control individual cavalry 'Dragon Princes'" | Fireborn log: `stalled 1 s with a move key held ... his command walk` | `F.model` is the rider model; `P.steer` (platform.lua:295) steers the rider, not the horse (`P.mount`, platform.lua:278, +0x2e0). main.lua:303 excludes flyers and war machines, not cavalry |
| 5 | "headless but still controlling the character" | Screenshot: dead Calith Gatekeeper on the ground, camera still on him | Death check main.lua:172 uses `P.alive` = still in the model list (platform.lua:360). A dying man may stay in the list; no hp check. Add `P.model_hp(m) <= 0` after measuring |
| 6 | Charge: "resets the running after 1 frame then start of charge animation again, causing the weapon to flicker" | Author's eyes | `P.steer` starts a new walk whenever +0x330 is not the pack's walk_b; if CHARGE (P.play, slot 135, mask 6) takes the slot, the next frame's steer destroys it; combat.lua:654 re-sends every 0.6 s |
| 7 | Aim stop at the enemy (round 31) "doesnt work" | Akshina's Ambushers log: aims 114-150 m; `launch` re-aims per spawn at release | Not yet tested in game. `probes/zz_tp_aim_at_enemy.lua` tests one call |
| 8 | "flickering animation when aiming high" | Everqueen's Court Guards log: `shot level (25.9 deg, wanted high) ... raise 1554, fire 1557` | High pair 1555 -> 1549 -> 1558, or round 30's aim hold (1548). Not investigated |

## Probes written today (in `Modding Files/source/lord_control/probes/`)

- `zz_tp_watch.lua` / `_read`: read only, 10 min. Per unit played: model class, attack rows, every command with its clips, hp and list membership, whole-unit movement. Started 17:13; results never read (they live in `_G.TP_WATCH` and die with the game).
- `zz_tp_charge_watch.lua` / `_read`: read only, 5 min, every frame while sprinting: command and clip changes and each CHARGE re-send. Started ~17:25; never read.
- `zz_tp_sweep.lua` / `_read`: written, **never run**. Per unit: melee via scaffolding, 4 swings with the guard and 4 without, 8 s idle, then death watched. It calls `E.combat.melee` directly, so it skips the key path; replace it with the run below.

## The test run to build next

One probe over every player unit in the battle, driving the pack through **faked input**: override `E.P.held`, `E.P.pressed`, `E.P.focused` (platform.lua:104-125) and `P.look_begin` / `P.look_delta`; `F.dragging` is set by `look()` (main.lua:146) when focused. main.lua calls through `E.P`, so a field swap takes effect. Per unit, measured pass or fail:

- walk: he moves under the keys (fails today for cavalry);
- sprint: CHARGE every frame, no frame of the run between;
- swing out of melee and in melee: the attack clip is reported;
- idle in melee with no click: no attack clip and no engine attack command;
- death: control moves within 1 s of hp 0;
- missile units: shot pair and clip sequence, and the aim distance with the view on an enemy's chest.

Print a unit-by-check table. A fix counts only when its row passes on every unit.

## Running the game yourself

- Launch: `Start-Process Warhammer3.exe -ArgumentList "used_mods.txt;"` from the game folder; ping `probes/bridge.py ping '{}'` until it answers (~90 s).
- `bridge.py continue_campaign '{}'` times out but loads the last save. Today's save is a High Elf army (Tyrion, Dragon Princes, Fireborn, Calith Gatekeepers, Everqueen's Court Guards, Keepers of the Flame, a Mist Mage) against Ogres. **Do not wait for `in_campaign`** - today that wait never ended and the author started the battle. Check with `send.py zz_tp_is_battle.lua`, end deployment with `send.py x1_start.lua`.
- One Lua error in an eval wedges the bridge: pcall everything. No `string.*` in probes.
- Only drive the game when the author has handed it over; read-only probes are fine while they play. Never save the battle result.

## Rules that still hold

One man of a regiment gives his regiment no orders (no `uc:` from the pack for him; test scaffolding may). Tests first, watched RED, plus mutants (`probes/tp_mutate.py`; known stale: fix 6, t10 7, t8 3, t9 3). Build `py tools/build_third_person.py` (RPFM open); deploy to data/ only with the game shut, diff the file list first, back up to `Modding Files/Backup/`. Tests: `lua.exe tools/third_person_harness.lua "Modding Files/source/third_person" tools/third_person_tests.lua` (342/342 at 5f4925ee).
