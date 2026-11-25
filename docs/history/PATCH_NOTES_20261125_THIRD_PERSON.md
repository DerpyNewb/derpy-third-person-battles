# Third-Person Battles: no splash on a common soldier's swing, and cut swings go again, 2026-11-25

Item 3822187184. Two Workshop reports, from 11-23 and 11-25, both reproduced live on 2026-11-25 on the published
`70C6EEF4` before the fix (the measurements are in the two rows of the "2026-11-21 to 11-25" section of
`THIRD_PERSON_BUGS_20261024.md`). Game `6ae2a00b` (9.0.5).

Build `8CAE1C72`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and deployed to the Workshop folder
`3822187184` on 2026-11-25 at about 13:25. Its file list matches the published pack's, 43 entries. The build's own
read-back verified 28 files, 127 loc rows and 11 stat tables. **Not uploaded.** The source before the edits is in
`Modding Files/Backup/third_person_src_20261125_pre_splash/`.

## What changed

- **A swing with no splash in CA's data no longer hits several men or knocks them down** (`third_person_cave.py`,
  `platform.lua` `P.nosplash`, `combat.lua` `C.splash`, `main.lua` stop). A clip the pack plays keeps its
  `SPLASH_ATTACK` metadata, so the engine's per-man splash pass (`exe+3095cb0`) hit everyone in its cone beside the
  pack's rolled blow, on a Greatsword as on a lord. The update cave now clears the man's splash bit
  (`+0xb12 & 0x10`) each tick for him and his mount while the script asks. The script asks for one man or a unit of
  one when the blow is struck by the cave, unless his weapon has a `splash_attack_target_size` (`data.lua`
  `splashers`, 3,261 units with the installed mods). It is not touched in multiplayer, where the splash is all a
  played swing deals, or for a regiment played whole, which fights with CA's own melee.
- **A swing cut by the engine's defend before its blow lands now goes again** (`combat.lua` `C.locked`). The engine
  refuses a reaction during CA's own swing by the man's action state (`+0x324`); a clip played here does not set it,
  so an enemy blow could cut the swing with a defend or hit reaction and nothing landed. When a reaction clip replaces
  the swing before its blow landed, a blow already armed is taken back (`platform.lua` `P.unblow`) and the swing goes
  again at once on the same button. That happens once per click, not after a blow that landed and not after a swing
  that found nobody.

## Measured live on the fix

Same setup as the morning's run: a practice battle with the minimal list (bridge, both memreaders, MCT, the pack from
the scratchpad), one Greatsword played against a held, fearless block of Orc Boyz.

- 10 and 26 swings standing: no swing hit more than one man. There was 1 knockdown in 36 swings, and it was the rolled
  blow's own "knocked" result. That morning, one swing hit up to 4 men and knockdowns ran 2-6 times CA's standing rate.
- 5 swings were cut by DEFEND (474-478) before their blow. Each went again 0.2 s later and each second blow resolved as
  a hit, a block or a knock. That morning, 2 of 20 cut swings dealt nothing.
- The General of the Empire (his sword has a splash): 24 killed and 76 knockdowns in 10 swings, so a splash weapon
  keeps its splash.
- No pack errors in the battle's log (`Modding Files/Backup/workshop_reports_20261125_third_person/script_log_251126_1317_fix_8CAE1C72.txt`).

## Checks

- Harness 754 + 49 lockstep. Three new tests: `one_mans_clip_splashes_only_where_his_weapon_does`,
  `a_swing_cut_by_a_reaction_before_its_blow_swings_again_once` and
  `a_swing_whose_blow_landed_or_found_nobody_is_not_swung_again`. The harness stubs `P.nosplash` and `P.unblow`.
- Cave: 48 of 48 mutants caught, five of them new for the splash clear.
- Mutation round 77 (`probes/mutants/mutants_round77.py`): 13 of 13 killed. Its first run had two survivors, both of
  which turned out to be equivalent mutants: `C.splash`'s `man ~= nil` repeated what `strikes()` already checks. That
  check was removed and the two mutants were aimed elsewhere.

## Change note

```
[list]
[*]Common soldiers no longer hit several enemies or knock them down with each swing, unless their weapon has splash
[*]A swing cut short by the enemy's blow now swings again instead of dealing nothing
[/list]
```
