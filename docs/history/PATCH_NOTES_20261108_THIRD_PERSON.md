# Third-Person Battles: 1 hp kills, gates, a shooting rider's mount, 2026-11-08

Item 3822187184. From the confirmed bugs of `LIVE_TEST_20261108_THIRD_PERSON_GAPS.md`. Game `6ae2a00b` (9.0.5).

Build `36d4c69b` (4,650,143 bytes), saved 13:59 to `Modding Files/Modpacks/derpy_third_person.pack` and verified from
the saved pack (28 files, 122 loc rows, 11 stat tables). Against the published `dc93af35`: the same files, only
`combat.lua` and `main.lua` differ. **Deployed 14:02, uploaded 14:03** at the author's request ("upload with
patchnotes"), through the steamworks binding (contentPath + change note only). Steam's log: `Uploaded new content
( ManifestID 1907773830457288151 )`, `: OK` at 14:03:32; published file_size 5,619,128 = pack + preview; 0 of 37 derpy
folders differ from their published size. Scripts, manifest and both packs are in
`Modding Files/Backup/pre_upload_20261108_third_person/` (the 08:18 upload's results file kept there as
`steam_upload_results_0818.json`; its manifest was overwritten). The Workshop file before this is also in
`Modding Files/Backup/third_person_pre_fix_upload_20261108/`.

## What changed

- **A killing blow inside his shielded window kills him** (`combat.lua` `C.invincible`). CA's `set_invincible` does
  not stop damage: it stops a lethal blow at 1 hp (measured: 183 -> 1 in one blow). The pack shields a unit of one
  through DEFEND and hit-reaction clips, so a blow that should have killed left him standing at 1 hp. A hit that drops
  him to 1 hp while shielded, or within 0.3 s (`INVINCIBLE_LAG`) of the shield ending, now clears the shield and kills
  him; `F.killed` keeps the next frame from shielding him again. A battle's own invincibility is left alone.
- **Enemy gates** (`combat.lua` `gate_ahead`, top of `C.melee`). No script call damages a building and a blow lands only
  on a man. A unit of one's click with an enemy gate within 12 m ahead and nobody where his blow lands is CA's
  `attack_building(gate, 1, false)`; it is not re-sent on the same gate, and a step ends it.
- **A shooting rider on a fighting mount** (`combat.lua` `mount_reaches`, `C.attack`): in ranged mode a click fires and,
  when an enemy is where the mount's blow lands, the mount swings too. Only on a click.

## Measured live today (siege, custom battle, bridge)

- **`alliance_owner_id` counts from 0; `get_player_alliance_num` / `get_non_player_alliance_num` from 1.** Attacking:
  player 1, enemy 2, every enemy gate/tower/barricade owner **1**. Defending: player 1, enemy 2, the player's own
  buildings owner **0**. The first build compared `owner ~= mine` and would never have fired for an attacker and would
  have aimed a defender at his own gate. Fixed to `owner == get_non_player_alliance_num() - 1`; the test now fails on
  the old comparison (checked by mutation).
- CA's order on a gate from 8.8 m outside its centre walked the general to 0.3 m of it and took it 1.00 -> 0.53.
- **Barricades are not covered.** In a custom siege every barricade slot exists (`glb_barricade_01`, `_monument_01`,
  `_traps_01`, `_blocker`, 56 each, category `house`, `has_gate` false, health 1) and refuses `attack_building`, even
  after `show()`. A custom-battle AI builds none, so a built one was never available; nothing read distinguishes built
  from unbuilt. Including them would make a click inside a settlement do nothing. Needs a campaign siege.
- `is_selectable()` is false on gates and barricades alike, true only on half the wooden towers.

## Checks

- Harness 717 + 49 lockstep, cave 43/43 mutants, pattern and cave checks ok on `6ae2a00b`.
- New tests: `a_killing_blow_inside_his_window_kills_him`, `a_click_at_an_enemy_gate_is_cas_attack_on_it` (owner 0 and
  2 and a barricade slot added after the live read), `a_shooting_rider_on_a_fighting_mount_does_both_on_one_click`.
- **Not checked live:** the 1 hp kill path and the Sisters click in game; the gate through the pack's own click (only
  CA's order and the owner numbers were read).

## Not fixed

- Soul Grinder sprints slower than it runs (sprint asks 11.25 m/s, above its 10 m/s charge speed; or its CHARGE clip is
  slower). Untested hypotheses, `LIVE_TEST_20261108_THIRD_PERSON_GAPS.md`.
- Flamethrower column in the sky (one man of a regiment, script launch). Unresolved since
  `HANDOFF_20261020_THIRD_PERSON_FLAMETHROWER_PROBES.md`.
- Barricades (above).

## Verified in game after the upload (14:25-14:55, the published `36d4c69b` from its Workshop folder)

Driven over the bridge with `probes/zz_tp_live_20261108.lua` (keys stubbed, enemy held), 720p test prefs, reverted.

- **Gate: broken as shipped.** The pack's click sent CA's order (`attack order on the building` in the log, three
  times), but the general stood 9 m out for 40 s and the gate stayed at 1.00. Cause: `move.lua` `man_drive` holds a
  unit of one on his spot (`P.hold`) every idle frame, which overrides the order's walk; the harness does not model
  that. With the hold skipped while the order runs (patched live), he walked to 1.6 m and took the gate 1.00 -> 0.84;
  a step cleared the order and the gate stayed at 0.77. Fixed: the gate order sets `native_attack = "building"` and
  `M.drive` skips the hold for that alone (a unit of one's other CA orders keep it).
- **Sisters of Twilight: broken as shipped.** Two riders on one dragon are `F.crew`, and `mount_reaches` excluded
  crews, so the click fired (ammo 60 -> 58) and the dragon did nothing. With crews let through and war machines kept
  out (patched live): each click fired and the dragon swung (clips 494-497), the log read `hit 387`, `hit 349`, `hit 366`
  and the Warboss lost exactly 1,102 hp; two other clicks were blocked.
- **1 hp: not proven either way.** One clean fight (Empire General vs Orc Warboss, unshielded) died 109 -> 0 with no
  1 hp stage, but the kill path did not log, so the blow simply landed unshielded. A forced test failed: holding CA's
  invincibility on every frame blocked every blow outright for 56 s (unshielded, blows landed every 4-8 s), so the
  "lethal blow clamped to 1 hp" mechanism could not be produced on demand. A Branchwraith fight then sat at **1 hp for
  7.1 s** with the pack's shield off, 4 s after the forcing ended (the forcing never released control, so that sample
  is contaminated). A third, clean run with a frame record was lost: the bridge wedged ("failed to parse command JSON"),
  and from then on `bm:time_elapsed_ms()` returned a function, so the pack's frame threw every tick (200,000 log lines)
  and switched itself off. The 1 hp cause is open; the shipped kill path is harmless but may not be the fix.

Fixed build `b6adf1c8` (717 + 49, 43/43; the gate test now fails when the hold is restored, the mount test when crews
are excluded again), deployed and **uploaded 14:56** at the author's request ("update it"): Steam log `Uploaded new content ( ManifestID 1737806279072665617 )`, `: OK`; published file_size 5,619,740 = pack + preview, 0 of 37 folders differ. Staging in `Modding Files/Backup/pre_upload_20261108b_third_person/`. Change note: "Fixed: attacking an enemy gate now walks to it and damages it (it stood still before)" / "Fixed: Sisters of Twilight, and other riders sharing one mount: in ranged mode a click now also swings the mount at an enemy in reach". Not re-run in game as a build: the live patches
were the same logic.

## Change note

```
[list]
[*] Fixed: an entity you play no longer survives a killing blow at 1 hp (beheaded but still standing)
[*] Enemy gates now take damage: a lord, hero or other single entity clicking at an enemy gate with no enemy in reach attacks the gate, any move key stops it
[*] Sisters of Twilight, and any rider who shoots from a mount that fights: in ranged mode a click fires and the mount strikes an enemy in reach
[/list]
```
