# Third-Person Battles: block key, lock-on reach, the 1 hp knock, AZERTY, 2026-11-11

Item 3822187184. The four "design calls" from the 2026-11-10 review, in order: AZERTY preset, the lock-on in a crowd, a
block key (the author chose route A, a defend clip and the pack's shield, on stamina), co-op gifted units. The 1 hp
report was looked into first, as the block rides the same shield. Game `6ae2a00b` (9.0.5).

Build `509f9be2`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and verified from the saved pack (28 files,
123 loc rows, 11 stat tables; same file list as the published `b6adf1c8`). No loadfast cache existed. The build before
is in `Modding Files/Backup/pre_build_20261111_third_person/`. **Uploaded 09:10** at the author's request ("upload to
steam with patchnotes"), through the steamworks binding (contentPath + the change note below only). Steam's log:
`Uploaded new content ( ManifestID 4407525306414029598 )`, `: OK` at 09:10:48; published file_size 5,626,321 = pack +
preview. Scripts, manifest and the pack are in `Modding Files/Backup/pre_upload_20261111_third_person/`.

## What changed

- **AZERTY keyboard** (MCT checkbox `key_azerty`, Keys section; `keys.lua` `K.azerty`, `settings.lua`). On, a key left
  at its default moves to its AZERTY place: W/Z and A/Q swap, so Z Q S D move, W walks, A is command mode. Keys chosen
  by hand stay. Before, moving only forward and left by hand silently unbound walk and command mode (their defaults Z
  and Q were taken; only the log said so).
- **Lock-on in a crowd** (`combat.lua` `victim`, `LOCK_REACH`). The locked enemy's man takes a blow 1.6 m further out,
  and his direction is judged from the swing's aim at him (`F.lock.yaw`), not the body's facing mid-turn.
- **Block key** (F by default, hold; `combat.lua` `C.block`, `main.lua`). A unit of one only (CA's invincibility is
  whole-unit). A press plays his DEFEND (FLY_DEFEND in the air; a rider whose mount has none, his RIDER_DEFEND; never a
  hit reaction), shielded from the press through the existing `C.invincible` guard, and holds him like a swing: no
  attack, no step. The clip runs to its end even if let go (a tap buys no free shield); held, the next follows. Stamina
  drains while a block's clip runs (`BLOCK_DRAIN` 6 s a full bar); a new block needs a quarter. A block waits for a swing
  under way. Kept disarmed under it (`main.lua`: armed, the engine's own swing could start over it). CA's F shortcut
  (`battle_land_melee`) is off while third person is on. A regiment, one entity of one, or no defend clip: nothing,
  and loc `derpy_tp_block_single` says so once a press.
- **The 1 hp stall** (`combat.lua` `knock`/`knocked`, `move.lua` `man_drive`). Nothing of ours plays over the engine's
  knock on him or his mount (143-197: knockback, knockdown, knockdown death, knocked flying, falls, getting up, lying,
  death): not the hit-reaction defend, the block, a click, the jump, the cheer, the sprint's CHARGE or its WALK_1, the
  lock's WALK_1, and nothing is sent to his body at all while knocked (a walk under a clip latches it, which here would
  have held him knocked for good). The 2026-11-08 kill path (`C.invincible`) stays as a backstop; its comment now says
  its premise was wrong.

## Measured live (custom battle, Empire vs Greenskins, bridge, keys stubbed)

Probes: `Modding Files/source/lord_control/probes/zz_tp_reach_hp_block.lua` (new), `zz_tp_crowd_focus.lua` (gains
`TP_CF_AT_LORD`). Test prefs applied and reverted, minimal mod list, game closed.

- **Lock-on, published code:** an Empire General locked on an Orc Warboss among Orc Boyz, 8 locked swings, 3 on him.
  2 missed with him straight ahead 1.37 and 1.53 m past the blow's reach; 3 with him 1.85-3.8 m off but outside the
  blow's direction (cos -0.21 to -0.91), the clip showing while the General still turned. **New code: 12 of 12 locked
  blows on him**; 5 of them needed the change (3 at 0.11-0.81 m past the old reach, 2 off the body's facing). Caveat:
  the new run walked at the lord, the first at the regiment's centre.
- **The 1 hp stall, published code:** the General, unshielded, under the Warboss: 249 -> **1** in KNOCKDOWN_1 (153)
  with neither the pack's shield nor CA's invincibility on. The pack's defend (478) replaced the knockdown 0.1 s later;
  he stood 6.6 s at 1 hp and died at the end of the next KNOCKDOWN_1 (the 2026-11-08 Goblin Big Boss record is the same
  sequence). So the shield was never the cause, and the 11-08 kill path did not fire. **New code:** the Captain, 63 ->
  1 in KNOCKDOWN_1, nothing played over it, dead as it ended: 2.8 s at 1 hp, all of it the knockdown.
- **Block, new code:** the Captain (fearless, not invincible) under the Warboss. Held 0-8 s and 20-28 s: DEFEND 474,
  475, 476 and 478, 479, 474 chained, shielded from the press, **no damage**; let go: one blow landed in each of the
  two unblocked spans (3688 -> 3366, 3366 -> 3084). Stamina 1 -> 0 by +9.8 s, refilled 0.85 in 10 s. A Warboss
  knockback (143) broke the block twice; the next defend waited for it to end (the knock guard), unshielded for
  that ~1 s.
- Run hazards: a custom battle left at x3 speed hit the lobby's 60-minute limit and ended (pause with
  `bm:modify_battle_speed(0)` between tests); a General not made fearless routed at 1207 hp and the run said nothing.

## Checks

- Harness 724 + 49 lockstep, cave 43/43, pattern and cave checks ok on `6ae2a00b`; `check_lua_literal_left` and
  `check_lua_api` clean on the changed files.
- New tests: `settings_azerty_moves_the_defaults`, `locked_on_his_blow_reaches_further_and_follows_the_aim`,
  `a_held_block_defends_him_on_stamina`, `a_tapped_block_is_one_whole_clip`,
  `a_block_shields_from_the_press_and_waits_for_a_swing`, `only_a_single_entity_with_a_defend_clip_blocks`,
  `nothing_of_ours_plays_over_a_knock`. Each watched failing first.
- Mutation round 73 (`probes/mutants_round73.py`): 23 of 23 killed. Two earlier survivors (block over a swing, shield
  before the report) got their own test.

## Not done

- **Co-op gifted units:** needs a battle with a second human (one PC cannot show one). One session answers it: whether
  a passive participant's queued push lands, and what `local_army()` / `is_player_controlled()` read on each machine.
  Nothing built.
- No HUD button for the block (the stamina bar shows the drain). The AZERTY box and block were not seen through MCT's
  own panel; the block key was driven with stubbed keys, not a real F press.
- The block is single player and multiplayer alike in code (it is the existing shield and clip path), but untested in
  multiplayer.

## Change note

```
[list]
[*] New: block key (F, hold). A lord, hero or monster you play defends and takes no damage while blocking. Uses stamina
[*] Lock-on: blows land on the locked enemy from a little further out, and while you are still turning to face him
[*] Fixed: an entity you play no longer stands on at 1 hp after a killing knockdown
[*] New option: AZERTY keyboard (Keys section)
[/list]
```
