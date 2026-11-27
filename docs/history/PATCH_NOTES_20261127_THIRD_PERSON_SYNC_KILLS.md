# Third-Person Battles: sync kills for the unit you play, 2026-11-27

Item 3822187184. Build `1F016454`, saved to `Modding Files/Modpacks/derpy_third_person.pack`, deployed to the
Workshop folder and **uploaded 2026-11-27 21:21** (Workshop manifest 6639109647013672360; published size 6,040,061 =
pack + preview). Kit in `Modding Files/Backup/pre_upload_20261127_third_person_sync/`; the 40 derpy Workshop packs
hashed the same before and after. Published before it: `CBBDC8EA` (2026-11-27 15:28), backed up in
`Modding Files/Backup/third_person_sync_kills_20261127/`. The work is in
`HANDOFF_20261127_THIRD_PERSON_SYNC_KILLS.md`, and the engine side is in `docs/BATTLE_ENGINE_RE.md` section 12b.

## What changed

- `combat.lua`: for a unit of one, a click with an enemy in the blow's reach rolls CA's own 50% chance. On a pass it
  arms him, gives CA's attack order on that enemy's unit and asks the cave's kill-move check every frame until the pair
  shows, for 1.5 s at most; with none by then, his own swing plays. It is tried only where the game's pair table pairs
  his battle animation table with the enemy's, a ridden man by his mount's table and his own together. A pair that has
  not started in 3 tries is not tried again that battle. A pair holds him until it ends, 30 s at most.
- `platform.lua`: `P.anim_table` reads a fragment's battle animation table name.
- `settings.lua` and the MCT settings script: a new "Sync kills" checkbox, on by default.
- `data.lua`: the `mc_*` sections, the game's pair table by animation table.

Against `CBBDC8EA`, the files that differ are those four plus the table GUIDs RPFM writes on every import. The pack has
43 files, the same list as before.

Checks: harness 761 + 49, with seven sync-kill tests; 16 mutations of the sync code, all caught; cave 72 of 72 mutants.
Tested in game: a Lord Magistrate made 6 sync kills in 16 clicks against held Orc Boyz. Against held, mortal Empire
Swordsmen, 10 clicks each, Vraznak paired on 5 of 5 tries, a Sorceress on a Cold One on 3 of 4 and Kroll on 4 of 4. Ghorth on foot and a Supreme Sorceress on a
manticore made no tries, and a feral manticore stopped after 3 failed tries.

## Change note

- Added sync kills for the lord, hero or monster you control, where the game has one for that matchup
- New MCT option to turn sync kills off
