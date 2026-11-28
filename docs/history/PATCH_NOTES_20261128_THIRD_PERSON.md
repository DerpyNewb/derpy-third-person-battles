# Third-Person Battles: the block raises the shield, and lords show their portrait, 2026-11-28

Item 3822187184. Build `AF3C8902`, saved to `Modding Files/Modpacks/derpy_third_person.pack`. **Tested in game and
uploaded 2026-11-28 11:57** (manifest 6692448949493379052; `Modding Files/Backup/pre_upload_20261128_third_person/`
holds the upload script, the pinned md5 and the before and after hashes of every derpy Workshop pack, none of which
changed). The previously uploaded build, `1F016454`, is backed up as
`Modding Files/Backup/derpy_third_person_20261128_071731.pack`, and the edited sources before the block change are in
`Modding Files/Backup/third_person_shield_block_20261128/`.

The day's builds, in order:

- `495C14B8` (`derpy_third_person_20261128_092242.pack`) judged the raise by the clip's name alone and let 17 vanilla
  lords and heroes block instead of 120.
- `621F976D` (`_100752.pack`) had the right list but let a walking block slide on after the player stopped. The in-game
  test below found it.
- `F670375F` (`_103453.pack`) fixed the slide.
- `846B0058` (`_111243.pack`) let the animation slot decide who blocks, at the author's choice, and fixed the generator
  so modded tables can see CA's clips. Tested in game.
- `BFD15A31` (`_111905.pack`) added the portrait border and the character portrait. Never run in game: a portrait
  path in capitals kept the card, fixed in the next build.
- `AF3C8902` is the current build. Tested in game and uploaded.

The block report came from a player on the Workshop (11-28 04:39 and the bugs thread 11-28 05:51): the block key plays the getting-hit
animation. It played DEFEND_1-10, which is also what `react()` plays when a lord is hit, so a block and a hit looked the
same. The author asked for the shield-up animation, no block for a unit without one, and movement while blocking. The
portrait was the author's own request the same morning: "add borders around the unit portrait, should also use the
character portrait IF the unit is a hero or lord".

## What changed: the block

- `combat.lua` `C.block` plays CA's shield-up set: STAND_SHIELD_UP (1257) standing, WALK_SHIELD_UP_1 (1268) or
  RUN_SHIELD_UP_1 (1273) on the move, each sent again at its length (a clip latched under a walk never reports its end)
  or as soon as the engine's own clip takes its place. The block lasts while F is held and stamina lasts. A press needs
  a quarter of the bar. Letting go, an empty bar or a knock lowers the shield. The old rule that a tap played one whole
  defend clip is gone.
- The block's lock carries `runs`, so `main.lua` drives him while it is up. No sprint under it (`C.sprint`). `C.locked`
  no longer ends a block lock when his clip changes; `C.block` decides that, so the engine's late report of a replayed
  clip (0.19-0.31 s) cannot drop him into his walk for a frame.
- **Who can block: the slot decides.** Any unit of one on foot, not mounted or flying, whose battle animation table has
  a STAND_SHIELD_UP row can block. `data.lua` `shields` lists the tables CA and the mods installed here ship with that
  row: 287 with the lengths of their shield-up clips, and 9 marked `false` because their row holds a plain stand that
  raises nothing. Those 9 refuse. A table the list has never seen, which means a mod that wasn't installed when
  `data.lua` was built, blocks on its slot alone and is timed by `shield_default`: no fixed length standing, 1.1 s
  walking and 0.9 s running, the medians of the listed tables.
- The generator (`third_person_fires.shield_ups`) finds a raise three ways. The clip itself can be a shield-up pose
  (Boris's `hu1_boris_todbringer_stand_shield_up_01`, the Ogre Bruiser's `shields_up`, the `tigashield1up` clips of one
  mod). The row's `.anm.meta` can `SPLICE` a shield-up clip over a plain stand, which is how the Dwarfs
  (`hu3_axs_shield_up_01.anm.meta`), the Empire, Chaos and the Orcs do it. Or the meta can carry a `TRANSFORM` that moves
  the shield, which is how the High Elf Prince's `hu1d_sps_shield_up_01.anm.meta` does it. The first list read neither
  the transforms nor the custom clip names.
- **A generator bug kept modded tables out.** It checked a mod's table against that mod's own files only, so a table
  that reuses CA's clips and metas looked empty. 55 modded tables were missed that way; 84 are listed now.
- Stopping from a walk with the shield up no longer slides him on. In game, `621F976D` carried the Thane 3.7-3.9 m at
  walking pace after W was released, in the standing shield-up pose, and another 1.3 m after F was let go. The engine
  keeps a man walking under a clip pushed over his walk when he walks (not when he runs), and the pack's stop
  (`P.hold`) only replaces a walk command, so it never reached him. Two parts fix it. `C.block` holds the standing
  clip back until `P.hold` has replaced his walk (up to 0.6 s), for a stop from the walk only: from the run, the clip at
  once stops him dead, as it did before. And when the release falls within a tick of a WALK_SHIELD_UP replay, the
  engine has already turned his walk into the clip's command, so `C.block` arms `F.unslide` and `move.lua` sends one
  short step of the pack's own walk, which `P.hold` can then stop. Any blocking man who drifts more than half a metre
  from where he stopped under a command that isn't a walk gets the same step.
- `F.blocked` is deleted: it only let a block chain clips below a quarter bar.
- Loc `derpy_tp_block_single`: "Only a single entity with a shield-up animation can block, and not while mounted or
  flying."

The trade-off of the slot rule: a table from an uninstalled mod that puts a plain stand in the slot will block without
raising anything, and an unlisted table whose clips are shorter than the defaults flickers for one tick at each replay
(seen in game, below).

## What changed: the portrait

- The HUD's unit card has a border: CA's battle card frame, `ui/skins/default/unit_card_frame_plain.png`, the one
  `land_unit_card.twui.xml` draws over its cards.
- A lord or hero shows his porthole, CA's character portrait, instead of his card: the centre square of the 300x164
  porthole at the card's height (130x130), on CA's card ground (`unit_card_background.png`), in the same frame nine-sliced.
  The plate beside it moves right by 70 so it stays clear. Line units are unchanged apart from the border.
- `hud.lua` reads the porthole from the campaign character when there is one
  (`UnitDetailsContext.CharacterContext.PortraitPath`). In a custom battle there is none, so it takes the porthole his
  card is named after: a character's card is `ui/portraits/units/<name>.png` and its porthole
  `ui/portraits/portholes/<name>.png`. It checks the file exists with `common.filesystem_lookup`, the same call CA's
  `all_scripted.lua` uses to look for `enable_console_logging`. 25 of CA's 1,293 cards have no porthole (Malus
  Darkblade, Gor-Rok, the Kislev general among them); those characters keep their card instead of a blank square.
  Paths are read lowercased because some of CA's are written `UI/Portraits/...`.
- The emitter (`gen_tp_emitter.py`) gained CA's `clipimagestocomponent` attribute, which cuts the wide porthole to its
  square. The preview draws a clipped layer at its own size and offset, and draws a lord's HUD as `tp_hud_<w>_lord.png`.

Against `1F016454`, the files that differ are `combat.lua`, `data.lua` (the `shields` table and `shield_default`),
`main.lua`, `move.lua`, `hud.lua`, `hud_layout.lua`, `ui/derpy_tp/hud.twui.xml`, the loc and the 11 stat tables.

## Checks

Harness 771 + 49. The four old block tests became ten: held, let go, a swing under way, walking and running, a knock
and the engine's clip, who can block, a table `data.lua` never read, a walking stop that waits for his walk to stop, the
step after a replay at the release, and the drift fallback. Four portrait tests: a lord's porthole and the plate beside
it, a line unit after a lord in the same panel, a lord whose porthole is no file, and a campaign lord's own porthole with
paths in backslashes and capitals. Mutants: round 78 12 of 12, round 79 15 of 15, round 80 3 of 3, round 81 9 of 9,
round 73 22 of 22 with five re-aimed at the new code, round 64 3 of 3. Cave 72 of 72. `gen_third_person_hud.py --check`
and `--selftest`, `preview_third_person_hud.py --check` (TWUI Studio's reader), `check_lua_api.py` and `luac -p` pass.
The preview finds no text under 4.5:1 and no text wider than its box, line unit and lord, at 1600, 1920 and 2560. At
1600 with ten abilities and the page tab, a lord's plate ends about 15 px before the tab.

## Tested in game, 2026-11-28

Minimal list each time: intro skip, bridge, both memreaders and the pack from its Workshop folder. Keys stubbed, no real
keys or mouse, the enemy held and both sides invincible. Test prefs applied and reverted, list deleted, game closed.

**The block, 09:30 to about 10:35.** Dwarfs (Dwarf Lord, Thane, Runesmith, Dwarf Warriors) against a held Greenskin
army, then a High Elf Prince. Probe: the scratchpad's `tp_block_live.lua` on top of `zz_tp_live_20261108.lua`,
recording his engine clip, his command and his position every frame. No `derpy_tp: error` in the logs.

- **The shield-up clips play and hold.** Standing, STAND_SHIELD_UP (1257) from 0.1 to 3.1 s, sent again at its
  2.1 s length. Running, RUN_SHIELD_UP (1273) every 0.7 s, 7.8 m in 3 s. Walking, WALK_SHIELD_UP (1268) every 1.0 s,
  3.6 m in 2.6 s. The engine reported the shield-up slot the whole time: CA's move order does not swap in his normal
  run or walk. Screenshots from in front show the shield raised before his face, and lowered at his side when F is
  let go. The Dwarf Lord raises his the same way.
- **The High Elf Prince raises his shield** through his meta's `TRANSFORM`, and he still did with his table taken out of
  the list in game, on the slot and the default timing. That run shows the one-tick flicker: the default is longer
  than his real clip.
- **Stamina:** a full bar holds the block for 6 s (`BLOCK_DRAIN`, unchanged), standing or moving. Empty, the shield is
  lowered; with F still held it rises again once a quarter of the bar is back, as a held sprint does.
- **The Runesmith** (`hu3_dwarf_hammer`, no STAND_SHIELD_UP row) gets the `derpy_tp_block_single` message once and plays
  nothing.
- **Stops, 621F976D:** from the walk he slid 3.7-3.9 m (three runs), from the run 0.33 m. Without the block, 0.36 m
  from the walk and 1.4 m from the run.
- **Stops, the fix, six walking and two running releases:** an ordinary walking stop 0.32-0.34 m; a release on a
  replay's tick 0.61-0.65 m (it slid 2.9 m with the wait alone); a release a tick after a replay 0.46 m; from the run
  0.29 m. Nothing moved after F was let go. Every stop ended on STAND_SHIELD_UP.

**The portrait, about 11:25, `AF3C8902`.** A custom battle with a High Elf Prince, a High Mage and Spearmen. The
engine gave the Prince and the Mage `IsCharacter` true and their `ui/portraits/units/...` cards as `IconPath`, and the
Spearmen `ui/units/icons/wh2_main_hef_spearmen.png`. `UnitDetailsContext.CharacterContext.PortraitPath` answered nothing
in the custom battle, with no error, and `filesystem_lookup` found the Prince's porthole and answered `""` for a missing
file. Frames from the game's own window are in `Modding Files/reference/third_person_portrait_20261128/`:

- The Prince (lord) and the Mage (hero, a caster) show their porthole, cut to the square and framed; the plate sits at
  x 160 against the card's 90.
- The Spearmen, played right after the Mage in the same panel, show their card in the new border, the plate back at 90.

Not checked in game: a campaign battle, where the porthole comes from the character; an Empire, Chaos or Orc lord's
block (listed through the same splice as the Dwarfs'); a block under missile fire or in melee; uneven ground;
multiplayer.

## Change note

- Block now uses the shield-up animation, and you can walk and run while blocking.
- Only lords, heroes and monsters with a shield-up animation can block, including those from other mods.
- Lords and heroes show their character portrait in the HUD.
- The HUD portrait has a border.
