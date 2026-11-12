# Third-Person Battles: the Deceiver's throw, abilities after a win, v5 charge lengths, 2026-11-12

Item 3822187184. These are fixes for three of the four bugs-thread reports checked that morning
(`WORKSHOP_REPORTS_20261112_THIRD_PERSON.md`). The fourth, Nagash at Nagashizzar, was not reproduced. Game `6ae2a00b`
(9.0.5).

Build `89ceb490`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and verified from the saved pack (28 files,
123 loc rows, 11 stat tables, the same file list as the published `509f9be2`; only `combat.lua`, `abilities.lua` and
`data.lua` differ, each byte-identical to source). **Deployed to the Workshop folder, not uploaded.** No loadfast
cache existed. The published `509f9be2` is in `Modding Files/Backup/pre_upload_20261111_third_person/`. The pre-edit
sources are in `Modding Files/Backup/pre_build_20261112_third_person/`, and each build's previous pack is in
`Modding Files/Backup/derpy_third_person_20261112_*.pack`.

## What changed

- **The Verminlord Deceiver throws with a moving aim** (`combat.lua` `shooting`, `in_shot`, `C.ground`). His raise is
  STAND_TO_SHOOT_READY (1465, 2.0 s) and his lowering SHOOT_READY_TO_STAND (1464, 2.0 s). Of 493 missile units he is
  the only one with either, and both sat outside the slots the re-aim guard knew. Every time the crosshair's unit
  changed, he got a new attack order, which lowered and raised him again. Now:
  - 1464 counts as a shot under way.
  - Once he has raised (1465 seen), he keeps his target until the throw leaves (his ammo drops), for one reload at
    most (`shots[2]`, 6 s for him). He holds the star up with no clip until his reload ends: 0.2 s with no reload
    pending, 0.6 and 1.2 s in the sweep below. An order in that window lowered him too.
  - **For every shooter**, a shooting clip that ended under `STEER_GAP` (0.5 s) ago still counts as under way, so the
    next target waits half a second after the clip instead of none. This covers the 100 ms gaps the engine reports
    between clips. The Colossus test now waits 0.6 s instead of 0.1 s.
  - If his target dies while he is raised, he stays on it until the reload has passed (a `ponytail:` note in
    `in_shot`).
- **Abilities aimed at an enemy work on a routing unit** (`abilities.lua` `nearest_to_ray`). Routing units were
  skipped for enemy targets, so after a won battle (every enemy routing) no such spell had a target. The game allows
  the cast. Friendly targets still skip routing units, and `is_valid_target` still applies.
- **Charge, moving-attack and raise lengths for v5 `.anim` files** (`tools/third_person_fires.py` `anim_length`,
  `data.lua` regenerated). A v5 header puts the seconds right after the skeleton name, with no u32 0 before them. The
  reader now takes those seconds when they fall between 0 and 60 s; two campaign birds read 60-67 s and stay unknown.
  `data.lua` gained `charges` for 111 units (Throgg among them) and `runs` for 58, `raises` for 27, and one `impacts` and
  `bodies` row for the mod unit `hkrul_roelef`. Four `charges` rows changed: the Carrion and Blood Vultures'
  FLY_CHARGE is now 9.1 s. That cannot open a gap, since the sprint still resends as soon as the engine reports the clip
  over (`combat.lua` `C.charge_run`).

## Measured live

Probes, all in `Modding Files/source/lord_control/probes`: `tp_lobby.lua`, `zz_tp_live_20261108.lua` (keys stubbed),
`zz_tp_verify_20261112.lua` (recorder). Minimal mod list with the pack loaded from a scratch folder, test prefs
applied and reverted, list deleted, game closed.

- **The Deceiver, fire held, aim swinging ±20° every 3 s, enemy 80 m ahead:**

  | Build | Time | Orders | Throws |
  |---|---|---|---|
  | `509f9be2` (published) | 11 s at ±8° | 9 | 0 |
  | 1464-1465 in `shooting()` only | 12 s | 7 | 0 |
  | the same plus the 0.5 s tail | 20 s | 4 | 2 (one lost: an order 500 ms after the raise ended, as the throw started) |
  | `89ceb490` | 30 s | 7 | 3, each straight after its raise (raise ends 7400, 15598, 25099 ms; throw clips 7599, 16197, 25701) |

  With a still aim, he raised from 451 to 2446 ms, played no clip for 200 ms, threw at 2648 ms (ammo dropped at 3143),
  and threw again 6.7 s later. Every new target still costs him the engine's 2 s lowering and 2 s raise. That is how
  the engine handles him under any attack order, and it was left alone.
- **After a win:** every enemy routed by script, the phase in `VictoryCountdown`, the Deceiver teleported 35 m from a
  routing unit (routing units ignore a teleport). The pack's Warp Stars (`E.abilities.cast`, as in the morning's run)
  logged `cast wh2_dlc14_spell_stealth_warp_stars (enemy)`. Winds went from 35 to 33, the spell went on cooldown, and
  the Spearmen dropped from 120 to 98. In the morning the same call came back "no enemy near the crosshair". A
  stubbed number-key press reached no cast code at all, in this run and the morning's, so the cast was driven
  directly.
- **Throgg's sprint:** forward and sprint held 7 s. CHARGE was resent every 692-703 ms (his 0.7 s), and the engine
  reported slot 135 as one unbroken 7.1 s run, against a 100 ms gap every 800 ms on `509f9be2`. Speed held at
  8.8-9.3 m/s (one half second read 10.2), the same as before.

## Checks

- Harness 726 + 49 lockstep, cave 43/43, pattern and cave checks ok on `6ae2a00b`. `luac -p` is clean on the changed
  files. `third_person_fires.py --selftest` passes, with new v5 cases (0.7 s read; a v5 layout under a v8 number gives
  None).
- New tests: `a_unit_of_one_raising_to_shoot_is_not_re_aimed` (lowering, raise, a 1 s raised wait, the throw, then
  one reload with no throw) and `an_enemy_ability_lands_on_a_routing_enemy`. Both were watched failing with their fix
  reverted. `a_shot_under_way_is_not_re_aimed` now waits 0.6 s.
- Mutation round 74 (`probes/mutants_round74.py`): 10 of 10 killed. An equivalent mutant (1465 left out of
  `shooting()`, already covered by the raise hold) showed that entry was dead, so it was deleted.

## Not done

- Golgfag's "ice skating": his clips run back to back and his speed matches CA's charge speed. Each resend restarts
  the clip's pose, and Throgg's cape snaps once a cycle. Foot sliding cannot be judged from stills, so the reply asks
  for a clip.
- The new `runs` and `raises` lengths (Tomb Kings' moving attacks, Bretonnian and Empire bowmen, Norscan hunters, a
  mammoth) were not checked in game.
- Nagash at Nagashizzar: not reproduced, and the reply asks for a crash report and mod list.

## Change note

```
[list]
[*] Fixed: the Verminlord Deceiver now throws when you move the aim while he winds up
[*] Fixed: after a battle is won, spells and abilities aimed at an enemy now work on routing units
[*] Fixed: Throgg and some other older units no longer pause briefly in every sprint stride
[/list]
```
