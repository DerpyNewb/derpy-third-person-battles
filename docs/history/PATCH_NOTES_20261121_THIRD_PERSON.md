# Third-Person Battles: no trampling on a walk, and the co-op watcher log, 2026-11-21

Item 3822187184. This update fixes a report in the pinned bugs thread (#82, 11-20): chariots and other units with a
collision attack kill infantry just by holding W. It also ships the co-op log line from 2026-11-19, which
`GIFTED_UNITS_SCOPE_20261119_THIRD_PERSON.md` needs from a partner's machine before gifted units can be scoped any
further. Game `6ae2a00b` (9.0.5).

Build `6BD96B57`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and deployed to the Workshop folder
`3822187184` on 2026-11-21 at 08:23. Against the published `24187034` (the 11-19 upload), three scripts differ:
`move.lua`, `main.lua` and `platform.lua`. The loc is byte-identical, and the 11 stat tables differ only in the
GUID header RPFM writes on save (bytes 6-76), so their rows are unchanged. All 28 text files in the pack match
`Modding Files/source/third_person/` byte for byte. Public repo commits `878d040` (watcher log) and `8f71bac`
(trample fix).

## What changed

- **A unit of one walked on the keys no longer tramples infantry** (`move.lua` `single_order`). With no order of its
  own, the engine puts a unit of one into melee when it touches enemies, and its bumps then land as charge impacts
  (72-80 hp, `KNOCKDOWN_1` each). The pack now keeps CA's move order on the unit while the keys walk it: a point
  30 m ahead, re-sent past a 30 degree turn, within 12 m of the point or on a walk/run change, at least 0.5 s after
  the last order, and halted at the release and at F2. No order is sent while sprinting (the charge stays the pack's
  `attack_unit`), flying, firing, under another order, or for one entity of a regiment.
- **A refused co-op partner or watcher logs what decides gifted units** (`main.lua`, `platform.lua`
  `P.gate_bytes`). One line per unit selected: `is_spectator`, `IsSpectating` and `IsPassiveParticipant` kept apart,
  the battle's two push gates (`+0x3b0`, `+0x3b1`), `local_army`, how many of the side's units have a card on this
  machine, and who CA says controls the selected unit. Every read is pcall'd on its own and no player names are
  logged. Nothing changes on screen.

## Measured live

The report was reproduced on 11-20 and the fix measured on 11-21 with probe
`Modding Files/source/lord_control/probes/zz_tp_verify_20261120.lua` (`X.collide`): a Khemrian Warsphinx driven from
25 m at a point 20 m behind the centre of a held, fearless, not invincible block of 120 Orc Boyz, for 12 s.

| Pass | Published `24187034` | Build `6BD96B57` |
|---|---|---|
| Run | 10 killed | 0 killed, no knockdowns |
| Walk | 9 killed | 0 killed, no knockdowns |
| Sprint | 11 killed | 6 killed (the charge, as intended) |
| CA's run order through the same block | 0 and 1 | - |
| Skeleton Chariots played as one chariot | 0 killed | - |

Stopping and turning behaved the same as on the old module.

**Not checked live:** the watcher log line. It needs a second human player in the battle; the harness covers it.
The reporter's other suggestion, zeroing the collision quota until Shift, was not tried.

## Checks

- Harness 749 + 49 lockstep (seven new trample tests, two new watcher-log tests). Mutation round 76: 15 of 15
  caught.
- 2026-11-21, before the upload: `build_third_person.py --selftest` on the source, and the deployed pack compared
  file by file against the source and against the published pack (above).

## Upload

**Uploaded 2026-11-21 13:46** at the author's request, through the steamworks binding (contentPath and the change
note below only, so the title, tags, description and preview are unchanged). The script re-checked the pack's md5
against the pinned `6bd96b57...` right before the call. Steam's log: `Uploaded new content ( ManifestID
885213940710864631 )`, then `: OK` at 13:46:34. The item reads back with `timeUpdated` 1795239994. The upload kit (the
script, the manifest, the build and a hash of every derpy Workshop pack beforehand) is in
`Modding Files/Backup/pre_upload_20261121_third_person/`. The published `24187034` stays in
`Modding Files/Backup/pre_upload_20261119_third_person/`.

At upload time the only other derpy folder holding a build Steam does not have was the Resource Overhaul
(`3833299348`). Another session redeployed it at 13:43, and that copy is identical to its `Modpacks/` copy, so a
revalidation after Steam pulls this upload can be undone from there.

## Change note

```
[list]
[*] Single-entity units like the Warsphinx no longer kill infantry just by walking or running into them; sprinting still charges
[*] Co-op: when gifted units can't be played, the script log now records the details
[/list]
```
