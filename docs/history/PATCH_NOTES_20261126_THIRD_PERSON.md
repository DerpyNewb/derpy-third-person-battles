# Third-Person Battles: splash back on modded lords, 2026-11-26

Item 3822187184. Build `122E9008`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and deployed to the
Workshop folder on 2026-11-26, then **uploaded at 05:13** (manifest 4159669248539880597, Steam log "Upload finished ... :
OK"; script and manifest in `Modding Files/Backup/pre_upload_20261126_third_person/`). The previous Modpacks build is backed up as
`Modding Files/Backup/derpy_third_person_20261126_045651.pack`. The measurements are in the 2026-11-26 entry of
`THIRD_PERSON_BUGS_20261024.md`.

## What changed

- `combat.lua` `C.splash` turns the splash off only for a unit on `data.lua` `no_splash`, which lists the 713 vanilla
  units whose melee weapon has no `splash_attack_target_size` in CA's `db.pack`. `build_third_person.py --gen` reads that
  list from `db.pack` alone, so no mod installed on the author's machine can change it. The 11-25 build did the
  opposite: it turned splash off for any unit missing from a list of splashers built with the author's mods, which took
  the splash away from every lord, hero and monster in a mod the author doesn't have.
- Running `--gen` again also picked up data for about 540 more modded units from mods installed or updated since 11-25.
  No vanilla unit's data changed. Balur's impact point moved because his pack was updated.

Against `8CAE1C72`, the files that differ are `combat.lua`, `data.lua` and the 11 stat tables. The stat tables differ
in bytes only, as in every rebuild since 11-19. The pack has 43 files, the same list as before.

Tested in game on two launches: a modded lord on foot (Reinhardt von Mackensen), a modded monster (the Rotblood Bile
Giant) and a modded lord on a monster mount (Bödvarr Ribspreader), each with normal attacks, and the two Rotblood units
with jump attacks too. The 11-25 build's behaviour, reproduced by putting the unit on the list at runtime, cut each one to
one man per swing and the Giant's jump attacks to no damage at all.

## Change note

- Splash attacks and jump attacks work again for lords, heroes and monsters from other mods.
