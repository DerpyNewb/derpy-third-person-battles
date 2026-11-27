# Third-Person Battles: sync kills, 2026-11-27

## Outcome (later on 11-27): built, verified live, not uploaded

Sync kills are back for a unit of one (a lord, hero or monster played with F2). The engine side, with every address,
is `docs/BATTLE_ENGINE_RE.md` section 12b. In short:

- The cave's call of CA's kill-move check (option C) passed, but CA's pair pick (`exe+30af180`) then found no clips
  and the pair was released before its first tick. It refuses a man on the disarm copy of his fragment, and a man
  outside CA's melee. The update cave's guard keeps the played man outside it, enemies attacking him or not. Both
  were isolated with the battle paused, by calling the start and the pair's done check from Lua.
- The first positive control (Orc Warboss against goblins) saw nothing because CA ships no paired clips for that
  matchup. A Lord Magistrate against Orc Boyz is a pair CA plays, and its own melee started one every few seconds.
- The pack now does this: for a unit of one, a click with an enemy in the blow's reach rolls CA's own odds for one
  entity (50%). On a pass it arms him, gives CA's attack order on that enemy's unit (`F.native_attack = "sync"`, which
  drops the guard) and asks for the check every frame until the pair shows, for 1.5 s at most. With no pair by then,
  the order ends and his own swing plays. One entity of a regiment is never tried, because CA's melee is his
  regiment's order.
- Live, third person, at CA's own odds: 6 tries of 6 paired 0.3-0.9 s after the click, every orc in a pair died, and
  pairs ran 5.2-5.4 s. The built pack, at default settings: 16 clicks, 6 sync kills, every orc in them died. Unknown 1 is answered: the paired clips play outside the fragment's slots, so `P.anim_slot`
  reads nil through them. Unknown 4 (the played man as the defender) is still open: this lord has no death clip
  against orcs.
- Offline: three harness tests whose fake engine pairs only an armed, unguarded man under an attack order, and seven
  mutations of `combat.lua`, all caught.

Deployed to the Workshop folder as `FBDEF4D9` (17:40); the published build is still `CBBDC8EA`, backed up in
`Modding Files/Backup/third_person_sync_kills_20261127/`. Against it, only `combat.lua`, `platform.lua`, `settings.lua` and
the MCT settings script differ, plus the table GUIDs RPFM writes on every import.

## Later still on 11-27: only real pairs, custom lords and monsters

The author asked whether custom lords and monsters had been tested, then chose to try a sync kill only where a pair can
exist. Builds 3 to 5 do that; section 12b has the rules and every measurement.

- A click is tried only where the game's pair table (`attila_generated*.bin`, read into `data.lua` as `mc_*`) pairs
  his battle animation table, read live off his fragment (`P.anim_table`), with the enemy's. A ridden man needs an
  entry naming his mount's attack clip and his own `RIDER_COMBAT` clip together. The feral pairs of his mount's table
  do not count.
- A pair that has not started in 3 tries is not tried again that battle. Monster pairs on infantry exist in the data
  but CA's pick rarely or never plays them (a Terrorgheist once in 40 s at 100%; a feral manticore 0 of 9 starts).
- The pair's lock now holds for up to 30 s, because one of Kroll's ran 15.6 s.
- Live, 10 clicks per unit against mortal Swordsmen: Vraznak 5 of 5 tries paired, a Sorceress on a Cold One 3 of 4,
  and Kroll 4 of 4. Ghorth on foot and a Supreme Sorceress on a manticore made no tries. A feral manticore stopped
  after 3 failed tries.
- Two traps cost time. An invincible enemy gets no lethal pair, which is how Dieter Helsnicht's first zero was
  first misread. And a flying unit never tries, because it swings `FLY_ATTACK` clips; land it with third person off.
- Found on the way, not fixed: Ghorth on a Great Taurus fails the men check ("a steering copy is not near its man"),
  so third person plays his unit whole.
- Offline: four new harness tests (ridden pairs, the give-up, a 16 s pair), 761 passing; 16 mutations of the sync
  code, all caught (the runner is a scratch script and was not added to `tools/`).

Deployed to the Workshop folder as `1F016454` (21:05) and uploaded at 21:21 (manifest 6639109647013672360);
`PATCH_NOTES_20261127_THIRD_PERSON_SYNC_KILLS.md` has the change note. Against the previously published `CBBDC8EA`,
the changes are `combat.lua`, `platform.lua`, `settings.lua`, the MCT settings script and the `mc_*` sections of
`data.lua`.

The rest of this file is the record as it stood before the work.

---

This handoff records why sync kills (CA's term is matched combat) never happen for the entity
the player controls, what was measured on 11-27, what is still unknown, and three ways to bring them back. The build on
the Workshop is `CBBDC8EA` (uploaded 2026-11-27 15:28).

## The request

Players have asked for sync kills four times: a question on 10-28 (`WORKSHOP_REPORTS_20261028_ALL_MODS.md`), a feature
request on 11-19, and two players on 11-26 and 11-27 (the "Sync attacks" row and the "Sync kills" paragraph in
`THIRD_PERSON_BUGS_20261024.md`). The drafted reply says that when you play one entity its swings are the mod's own, so
there are no sync kills for now. The author saw sync kills during the prototype, playing a Cathayan lord, and wants
to know what removed them.

## Why they stopped

| When | Where | Change | Sync kills |
|---|---|---|---|
| 10-08 | `HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md` | Left click was `attack_unit(target, true, running)`, so the game's own melee fought. The handoff: "`attack_unit` engages; the combat simulation still picks every attack and matched kill." | Yes |
| 10-13 | `HANDOFF_20261013_THIRD_PERSON_PACK_LIVE.md` §2c | A click plays the man's own attack clip through memreader; attack orders stay only as a fallback. The Cathayan general on a Longma failed the soldier check (mount model class `exe+3ac4908`), so his swings fell back to attack orders until that was fixed. | Only through the fallback |
| 10-14 | the author's ruling | "Absolute control and no auto attack." | - |
| 10-16 | commit `40bd7a7` | No auto attack: the played man (one entity of a regiment or a unit of one) points at a copy of his animation fragment whose attack slots are empty, re-armed only while his own swing plays. Measured in a lasting melee with nobody at the keys: the engine was still starting swings on him inside its own tick (Tyrion swung for 917 of 1,195 frames in 30 s), and on the copy it started none (`probes/zz_tp_auto_attack.lua`, `probes/zz_tp_mask_experiment.lua`). | No |
| 10-18 | commit `ef331d3` | Units of one (lords, heroes, monsters) fight as one man: the order gate, no turn order, the lock. | No |

A regiment played whole keeps CA's melee, so sync kills should still happen there. That has not been measured.

## The mechanism today

- `main.lua` (around line 550, in the per-frame block after `E.combat.strike`): the played man is armed only while one of
  his own clips is locked (not a block), swung, under an engine attack order, pending, or shooting:
  `if F.lock and not F.lock.block or F.swung or F.native_attack or F.pending or F.shot then P.arm(man) else P.disarm(...)`.
- `platform.lua` line 557, `is_attack(s)`, names the slots the copy blanks: 454-463 (`ATTACK_1`-`ATTACK_10`),
  484-503 (`MOVING_ATTACK_1`-`FLY_ATTACK_10`), 1901-1910 (`RIDER_ATTACK_1`-`10`) and 1931-1950
  (`RIDER_MOVING_ATTACK_1`-`RIDER_FLY_ATTACK_10`). `build_copy` (line 1319) makes the copy, deduplicated per fragment,
  shots flag and charge flag, and `P.disarm` / `P.arm` (lines 1350-1361) point the man and his mount at it and back.
- The mod's own swing is a clip it plays itself; `combat.lua` `C.strike` rolls the blow once the clip shows. The
  engine's choice of attack, which is where it would pick a sync kill, never runs for that swing.
- Multiplayer builds the same copies at "Deployed" on every machine, so a copy is byte-identical everywhere (the
  comment above `build_copy`). Any change to what is blanked has to keep that.

## What is known about matched combat

- **It is decided when the engine starts an attack.** CA's doc for `unitcontroller:set_matched_combat_chance`: "Sets the
  chance of units associated with this unitcontroller performing matched combat when attacking." A disarmed man has no
  attack for the engine to start, which fits the 10-16 result. This is an inference from the doc, not a measurement.
- **The chances are engine constants** in `_kv_rules`: `matched_combat_percentage` 50,
  `matched_combat_formed_vs_formed_percentage` 40, `matched_combat_formed_vs_free_percentage` 60 (`docs/FORMATIONS.md`
  §13).
- **The paired animations come from a table, not from the attack slots.** CA's `default__.animpack` holds
  `animations/matched_combat/attila_generated.bin` and about 225 clips and metas in `matched_combat` folders (the fork's
  `Shared/GameFiles/AnimationPack/AnimationPackSerializer.cs`, which reads the `.bin` as `MatchedAnimFile`).
- **Fragments also carry four generic matched slots**, ids 530-533: `GENERIC_MATCHED_HIGH_ATTACKER_1`,
  `GENERIC_MATCHED_MIDDLE_ATTACKER_1`, `GENERIC_MATCHED_HIGH_DEFENDER_1` and `GENERIC_MATCHED_MIDDLE_DEFENDER_1`
  (`Warhammer3AnimationSlots_9_0.txt` in AssetEditor's `Resources/AnimationSlots/`, where line N is slot id N - 1).
  They are outside every range `is_attack` blanks, so the disarm copy keeps them.
- Matched-combat death sounds use `SOUND_SPHERE_LINK` in their `.snd.meta` (`docs/ANM_META_TAGS.md`).

## What was measured on 11-27, and why it settles nothing

`probes/zz_tp_verify_20261127.lua` (load after `zz_tp_live_20261108.lua` and `zz_tp_verify_20261125.lua`):

- `Z.chance(me_type, c)` sets `set_matched_combat_chance` on one of my units through a kept controller.
- `Z.lock_start` / `Z.lock_read` look for a locked pair: two men within 2.2 m, headings opposite within 3 degrees and
  the distance moving under 3 cm a frame, held for 0.6 s or more.
- `Z.mc_start` / `Z.mc_read` count every animation slot each man of my unit and the enemy unit enters, and the slot
  each enemy man died in.

Results: the lock detector found **0 episodes in every run** (1,211, 2,269, 3,552 and 11,312 frames), including CA's
own melee with the chance at 100 on Greatswords. In the slot runs, enemy men died in `COMBAT_IDLE_1`-`3` (439-441),
`ATTACK_2` (455), `ATTACK_5`-`ATTACK_9` (458-462) or an unreadable slot, and men near the fight passed through
`KNOCKBACK_2` (144), `KNOCKDOWN_1`/`3`/`4` (153, 155, 156) and `DEFEND_3` (476). No `GENERIC_MATCHED_*` slot appeared.

**Neither detector has a positive control.** No run ever showed it a sync kill known to have happened, so "0" may
mean the detector is wrong, or that infantry against infantry rarely does it (in WH3 sync kills are mostly lords,
heroes and monsters). The memory `absence-claims-need-the-hardest-case` applies: prove the probe catches one first.

## Unknowns

1. Which slot, if any, a sync kill plays through, or whether it is a separate state outside the fragment's slots.
2. Where in `Warhammer3.exe` the engine rolls and starts a matched combat. A lead: the binding behind
   `set_matched_combat_chance` writes a per-unit chance, and the code that reads that field is the decision.
3. What both men carry while locked (fields on the man object; `docs/BATTLE_ENGINE_RE.md` has the field map).
4. Whether an enemy can still sync-kill the played man as the defender. His defender clips are not blanked, so
   probably yes; untested.
5. How often the engine picks a sync kill when it is given one swing to start (option A below).

## Three ways to bring them back

- **A. Let the game swing once on a click** when the man is in melee range of a badly wounded enemy: arm the slots
  for one engine-chosen swing instead of playing the mod's clip. Cheapest. Costs that click's aimed, directional swing
  and its timing, and the rate is unknown (unknown 5). Needs an MCT switch and a harness test that a normal click still
  plays the mod's own swing.
- **B. An MCT switch that leaves the slots armed in melee.** Brings CA's melee, and its sync kills, back for the played
  man, and with them the auto attack the author asked to remove. Easy, but it undoes the 10-14 ruling, so only as an
  opt-in.
- **C. Start a sync kill directly** through the update cave on a click: find the start (unknown 2), then call it on the
  battle thread with the played man as attacker and the enemy man as defender. The best result and the most work, and
  the first time the mod would drive an enemy entity's animation. Engine calls from Lua crash the game; this has to go
  through `tools/third_person_cave.py` with its own mutants, like `steady`.

## Suggested first steps

1. **A positive control.** A custom battle with a melee lord the author has seen sync-kill (a Cathayan lord) against
   weak infantry, not played, `Z.chance(..., 100)`, with `Z.mc_start` on the lord and screenshots at each stage (memory
   `look-at-the-battle-not-only-memory-reads`). Confirm a sync kill on screen, then record the slots and timings both
   men go through. The battle-test rule (memory `battle-tests-static-immune-enemy`) makes both sides invincible, but a
   sync kill needs a death, so agree a variant with the author before running it.
2. With the slots known, play the same lord with F2 and confirm the count drops to 0, and check unknown 4.
3. Prototype option A behind an MCT switch and measure the rate over a fixed number of clicks.
4. If A is too rare or loses too much control, go after C with `tools/exe_re.py`, `tools/ghidra_decompile.py` and an
   x64dbg write breakpoint on whatever field the positive control shows changing (`docs/BATTLE_ENGINE_RE.md` §10b).

Live-test rules: `docs/LIVE_TESTING.md`, the test settings (`tools/wh3_test_prefs.py`), our own mod list, no real
mouse or keys, and quit the game when done. After any change: `tools/third_person_tests.lua`,
`tools/third_person_cave.py --selftest` if the cave changes, and `tools/build_third_person.py`.
