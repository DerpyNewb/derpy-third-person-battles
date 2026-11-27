# Third-Person Battles: swings at an enemy not fighting you land again, 2026-11-27

Item 3822187184. Build `CBBDC8EA`, saved to `Modding Files/Modpacks/derpy_third_person.pack`, deployed to the
Workshop folder and **uploaded 2026-11-27 15:28** (Workshop manifest 7692593176784460855; published size 5,905,677 =
pack + preview). Kit in `Modding Files/Backup/pre_upload_20261127_third_person/`. The previous Modpacks build, the uploaded `122E9008`, is backed up as
`Modding Files/Backup/derpy_third_person_20261127_120221.pack`. The cause and the measurements are in the 2026-11-27
entry of `THIRD_PERSON_BUGS_20261024.md`, and the engine side is in `docs/BATTLE_ENGINE_RE.md` section 12, "The
collision interaction at `+0xb20`".

## What changed

- The update cave (`tools/third_person_cave.py`) serves a new request, `steady`. While it is on, the cave clears the
  played man's `+0xb20` at the top of his update when it holds one of the engine's two collision interactions. Set, that
  pointer sent his update down a branch that dropped a clip played by the pack one tick after it showed, so a swing at
  an enemy who was not fighting him was cut and never rolled a blow. The block grew from 0x200 to 0x218 bytes for the
  two vtables and a counter, and `check_mailbox` now zeroes the guard table only up to them.
- `platform.lua`: the 6ae2a00b BUILDS row gains `collide_vt` and `collide_vt2`, and `P.steady(on, m)` writes the
  request, single player only.
- `combat.lua` `C.steady` turns it on while one man or a unit of one is played and one of his own clips is locked or
  waits to play (`F.lock` or `F.pending`), and `main.lua` calls it every frame and turns it off at the stop. The
  first build, `33447FB5`, lacked the "one man or a unit of one" half, so a whole regiment's cheer or jump would
  have switched it on for whatever man the block last named.

Against `122E9008`, the files that differ are `combat.lua`, `main.lua`, `platform.lua` and the 11 stat tables. The stat
tables differ only in their GUIDs; their rows are identical. The pack has 43 files, the same list as before.

Checks: cave `--check`, and `--selftest` with 58 of 58 mutants caught (10 new for `steady`); harness 755 + 49, with a new
test that fails on each of three breaks of `C.steady`, on one of the stop path, and on the unguarded line. Tested in
game the same day on `33447FB5` (the guard came after, checked by the harness): a unit of one against a walking enemy went from 9 and 3 swings cut of 12 to none of 12 in both passes, and every click rolled a
blow. The held-enemy pass and one entity of a regiment were unchanged, and the cave cleared nothing in either.

## Change note

- Fixed single-entity units' attacks getting cancelled with no damage against an enemy that isn't fighting them.
