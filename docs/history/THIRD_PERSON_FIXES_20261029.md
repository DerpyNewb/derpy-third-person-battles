# Third-Person Battles: fixes for the 10-25 to 10-28 reports (2026-10-29)

Follows `THIRD_PERSON_VERIFY_20261029.md`, which confirmed the bugs. Built as a local pack, verified through RPFM and
offline, and deployed to the Workshop folder `3822187184`. **Uploaded 2026-10-29 13:18 with the walls and army-ability
build `2ec7e798`** (`PATCH_NOTES_20261029_THIRD_PERSON.md`). The Workshop copy it replaced (`39646933`)
is backed up as `Modding Files/Backup/derpy_third_person_workshop_39646933_20261029.pack`.

The 08:09 deploy did not last. The 17-item upload, 09:21-09:23 (`PATCH_NOTES_20261029_SEVENTEEN_ITEMS.md`), was followed by
Steam's Workshop update for WH3 at 09:50. That update's full validation downloaded the published 10-25 copy over this
deploy, the one pack among the 15 it replaced that had not just been uploaded (`Steam/logs/content_log.txt`, "chunks
corrupt of"). The build with the strike (below) was deployed again at 10:20, MD5 `a8a1c725`. That deploy was replaced
at about 12:33 by `2ec7e798`, which adds walls, bridge decks and the army-ability page
(`THIRD_PERSON_WALLS_ARMY_ABILITIES_20261029.md`).

## What changed

| Report | Fix | Where | Checked |
|---|---|---|---|
| Unit stats do nothing in campaign | 40 effects, one per stat ability, enabled through `effect_bonus_value_military_force_ability_junctions` (Relentless Rage's own HIDDEN effect is the donor). One `[hidden]` faction bundle `derpy_tp_stats` carries all 40 at scope `faction_to_force_own_unseen`. A new campaign script applies it to every human faction at first tick, on every load. The custom-battle faction junction is unchanged | `build_third_person.py` `stat_rows` / `check_stats`; `script/campaign/mod/derpy_tp_stats.lua` | Live, campaign battle |
| Enemy banners gone on Alt | While CA's banners show, the cinematic UI is off, as in multiplayer. CA hides every banner under it | `main.lua` `cursor()`, `banners()` | Live |
| Multiplayer: CA's portrait and ability bar stay up (a player) | The portrait, mask and ability parts of `porthole_parent` are hidden while he looks and given back when the mouse is freed. Before, only the cinematic UI hid them, and multiplayer has none | `main.lua` `hud()` | Harness (single player live) |
| Cavalry has no charge attack | The capability check also reads the rider's `MOVING_ATTACK`, which `swing()` already plays on him when his mount has none. 468 of 1,121 mounted units carry it on the rider only. The 546 with it nowhere are unchanged | `main.lua` `capabilities()` | Live |
| Flying generals land at random | A sprint in the air sends no `attack_unit` (a melee order lands a flyer). `FLY_WAIT` is the author's design and is unchanged | `combat.lua` `C.charge` | Harness |
| Melee does no damage (414 units with no `SPLASH_ATTACK`) | **Fixed for one man (F2) and a unit of one, single player.** The engine attack order does not work as forged (below). A blow's damage is a pending-hit record that the engine's melee arms on the man at each swing, and the pack's clips never arm it. Each swing now picks the enemy man where its clip's `IMPACT_POS` lands, and the update cave rolls the blow with the engine's own roll and arms the record ("The strike", below). A unit played whole and multiplayer are unchanged | `third_person_cave.py` (the strike section), `platform.lua` `P.strike`, `combat.lua` `victim()` / `C.strike`, `data.lua` `impacts` | Live |

Tests: `third_person_hides_unrequested_hud` rewritten (hidden while looking, back when freed);
`multiplayer_hides_cas_portrait_and_abilities_while_looking`, `a_sprint_in_the_air_orders_no_charge` and
`a_riders_own_charge_attack_counts` are new. Two checks were added to
`the_guide_key_brings_cas_banners_back_and_the_bars_step_aside`. **661 + 47 pass.** Mutants round 71: each of the
seven changed lines was reverted on its own, and each revert was caught by its test (7 of 7). `check_stats` catches a
dropped bundle row, a dropped enable row, a dropped effect, and a script that does not name the bundle. The campaign
script was run under Lua 5.1 against a stubbed `cm`: it applies only to the faction that lacks the bundle, with 0 turns.

Loc: `derpy_tp_stats_faction` now reads "...In custom battles, factions added by other mods are not covered."

## Live run, 07:59-08:35

The run used the same fixture and list as the verification: `derpy_vfx_min_ie_t1`, Astragoth against Dusty, a campaign
battle, with the local pack. Keys were stubbed over `P.held` / `P.pressed`. Afterwards the game was quit, the prefs
reverted (`ui_unit_flags` 2), and the list deleted.

- **Stats.** On the campaign map, Astragoth's faction has `derpy_tp_stats` and the AI faction does not. In battle the
  army owns **40** stat abilities (0 before). With Melee attack +25% asked for, the phase
  `derpy_tp_stat_melee_attack_p25` landed on the played Peasant Spearmen. CA's banner over them lists "Melee Attack:
  +25%".
- **Banners.** With Alt held while looking: `F.banners` true, cinematic UI off, and 9 of 19 banner children visible
  (0 of 7 before; the hidden ones are presumably off screen). CA's portrait and ability parts were hidden. **Cost:**
  with the cinematic UI off, CA's green selection outlines show on his own unit while Alt is held. This is what
  multiplayer always had.
- **Cavalry.** Empire Knights: `can_charge` true. MOVING_ATTACK is on the rider and not the horse. The charge attack
  plays 484 on the rider while the horse keeps its gait (33). The frames were too far back to judge how it looks.
- The "Channel Magic! / Start deployment" panel in the captures is left over from the bridge ending deployment. It is
  there with third person off too.

## The engine attack order (BCQ_ENTITY_USER_OVERRIDE_ORDER_ATTACK): what the forge does

Forged as MOVE is: the header, then one 9-byte record (man id, tag `0x23`, target id), then the length. Global
`{0x4060000, 0xc82c}`, registered, version 0; every push returned ok. Probes:
`Modding Files/source/lord_control/probes/zz_tp_attack_probe.lua` (driver) and `TPO.attack` in `zz_tp_mp_override.lua`.

The setup was an isolated test. The enemy was under `uc:take_control()`, because `uc:halt()` alone did not keep the
battle AI off it, and the first runs were confounded by a melee between the enemy and his regiment. His regiment was
75-300 m away. The target was Orc Boyz.

| Run | Result |
|---|---|
| Idle control (guard on, no clicks) | 0 damage |
| Pack clicks, placed 0.7-2 m off | 455, 456, 454, 455 played, **0 damage** (the bug, reproduced) |
| Forge, guard lifted | 20 HP, then he was **beside his regiment, 287 m away**, within the tick |
| Forge, guard and hold on, the mailbox's melee vtable blanked so only the engine's melee runs | the same snap back |
| Walked in with W (no `P.place`), the same lift | the same: a per-frame trace shows him on `stand` (`39126f0`), then **93 ms after the push, idle (`3919b28`) 53 m away, in one frame**. No melee command ever ran on him |

The small HP losses in the forge runs came while he was 60 m away, so they were not his. That Orc Boyz unit was also
losing HP between runs from something else.

From the code (`ghidra_decompile.py`): the handler `exe+2ecf644` builds the target block (`exe+2eab460`) and parks the
action (vtable `exe+390c2c8`). The action waits out a delay (slot 1, `exe+2f780a8`), then `exe+2f7ec44` calls the man's
virtual `+0x4b0`, or `+0x580`, with the target. So it issues a real engine order, and something in that path puts a
regiment's man back with his regiment at once. That path was not traced further. **As forged it is unusable:** every
swing would teleport the played man back to his regiment.

Two routes were listed here: trace the `+0x4b0` order path, or add `SPLASH_ATTACK` to 281 metas. Neither is needed
now. The next section found what deals the damage, and it can be armed without an order and without touching CA's
animations.

## What makes a melee blow deal damage: the pending hit (second live run, 08:40-09:03)

The clip does not deal the damage. A blow is a **record on the man**. The engine's melee arms it when the swing
starts, and the man's own update lands it at the clip's impact frame. `SPLASH_ATTACK` is a second, separate path,
which is why only units with splash hurt anything under the pack.

The record. The offsets are from the code and the layout was confirmed live:

| Offset | What |
|---|---|
| `+0xaf0` | result type: 0 blocked (the victim plays a reaction, no damage), 1 hit, 3/4/5 a hit with a knock |
| `+0xaf4` | damage, final: a 35 written by hand came off as exactly 35 |
| `+0xaf8` | the swing's anim slot, u16. The impact frame is read from that slot's clip |
| `+0xb00` | the victim, a man |
| `+0xb08` | pending, 1 |

- **Armed** by `exe+3251af8`, the attack object's launch. It plays the slot (`exe+3081d40`), then rolls the blow with
  `exe+30a8ab0(resolver, &result, attacker, victim, 0)`. The resolver is the battle's `+0xf8`. The roll covers melee
  attack against defence, the damage and the result type, all from the battle's RNG. Then it writes the five fields,
  pending last.
- **Landed** by `exe+32654d0(man + 0xaf0, man)`, which the man's update `exe+3086f04` calls every tick. Once `+0x27c`
  (ticks into his clip) reaches the impact frame of the slot at `+0xaf8`, it deals the damage and clears the record.
  The path is `exe+3253204`, then `exe+3260a34`, then `exe+3075b20`, then the hit point subtract `exe+310157c`. **It
  checks neither range nor facing**, because the arm already did.
- **Cancelled** (record zeroed) when `+0x898`, `+0x284` and the `+0xb20` check are all clear. While the pack's clip
  played, `+0x898` stayed set, so a hand-armed record is not cancelled.

How the engine's melee gets there:

- The melee command `3ad24b8` holds its target at `+0x38`. Its vtable `+0xc0` is the target getter,
  `mov rax, [rcx+0x38]`. Every other command, the pack's forced clip included, returns null there.
- Each swing, the command builds an attack object (`exe+3081f18`, four kinds), stored at `cmd+0x80`. That object's
  launch is what arms the record.
- The pack's clip runs under the forced-clip command, so no attack object exists and nothing arms the record. The clip's
  `IMPACT_POS` has nothing to resolve.

| Run | Result |
|---|---|
| Engine melee: 100 Dragon Guard on Orc Boyz, 8 s, every man every frame | 42 records armed: 20 blocked, 17 hits, 5 knocks. Damage 27-44. `+0xaf8` was his playing slot in 42 of 42. `+0x898` was set in all 5,812 pending frames; `+0x284` was 0 |
| The pack, one Dragon Guard, plain clicks (`dg_click`, first run) | 0 damage |
| The pack, one Dragon Guard, each click's swing armed by hand from Lua: type 1, damage 35, his new slot, the nearest enemy man | **4 of 4 landed**: 1692, 1657, 1622, 1620 (that blow killed a man who had 2 HP left), 1585. Each landed 0.7-0.8 s into its clip. His regiment was 101 m away and the enemy was halted |

Three of those four swings were armed 3.1-3.6 m from the nearest enemy, and they still landed. The record does not
check reach.

What a fix needed, as listed before the build:

1. **A reach and facing test before arming.** The engine's test is in `exe+325fca4`.
2. **The roll.** A fixed number makes every swing a hit, with no defence, armour or bonuses. `exe+30a8ab0` is the
   engine's own roll. It reads and advances the battle's RNG and uses a shared scratch block (`exe+433fdb0`), so it
   has to run on the battle thread. That means the mailbox cave, posted the way the walk is. Engine calls made from the
   script thread have crashed before.
3. **Multiplayer.** The roll and the five writes have to happen on every machine at the same tick, or hit points and
   the RNG desync. That is the carrier cave, which already applies the guard and the arm.
4. **Splash units.** These already deal damage. `exe+3251af8` has no splash check, so vanilla arms the record for them
   too, and arming it here matches vanilla.

1, 2 and 4 are built (next section). 3 is not: the strike is refused in multiplayer.

Probes: `zz_tp_attack_probe.lua` mode `click_arm`; `zz_tp_opponent_scan.lua` `TPS.sample` and `TPS.report`. The
decompiles are reproducible with `py tools/ghidra_decompile.py <rva>`. `.pdata` gives exact function starts where
`exe_re.py`'s padding guess does not (`docs/BATTLE_ENGINE_RE.md` section 12).

## The strike: the blow rolled through the cave (third live run, 10:15-10:19)

**The script picks the victim.** `combat.lua` `victim()` places the swing's impact point, then picks a man near it:

- The point is the slot's `IMPACT_POS` (x right, z ahead, from his animroot), turned with his heading. `data.lua`
  `impacts` gives 3,815 land units this point for ATTACK_1-10, read from the first clip of each slot on the body that
  plays it. A slot with none lands 2.5 m ahead.
- The candidates are the enemy men alive, or the mount for a rider, since that is where his hit points are.
- A man qualifies when his edge is inside the blow's reach plus 0.5 m, and he is within 60 degrees of the blow's
  direction (or standing inside his own body radius). The body radius comes from `data.lua` `bodies`, else 0.5 m.
- Of those, the one nearest the impact point is struck.

**When it is posted.** `C.strike` posts the blow the first tick the clip shows on him, through `P.strike(man, victim,
slot)`. A clip that never shows by the swing's give-up time posts nothing. A stop or his death drops a blow not yet
posted.

**The cave rolls and arms it.** The update cave takes the request on that man's own update, on the battle thread:

- It checks that he is alive, the victim is alive, he plays that slot (`+0x278`), and a clip runs (`+0x898` or
  `+0x284`).
- It calls `exe+30a8ab0` with the battle's resolver (`[[[man+0x58]+0x440]+0xf8]`).
- It writes the record: slot, type, damage, pending and victim.
- It counts the roll in the block's `struck` field.

The landing is the engine's own. Block fields: `strike` `+0x6c`, `strike_man` `+0x70`, `strike_victim` `+0x78`,
`strike_slot` `+0xe0`, `struck` `+0xe4`, the roll's address `+0xf8`. `check()` refuses the build when the roll's
prologue bytes are not at `0x30a8ab0`.

**What else changes.** Where blows are struck, the clips with no splash are swung again: the dull filter only applies
where no strike is made. With the debug log on, each blow logs one of three lines: "blow 454 on a man 1.4 m from where
it lands: hit 32", "...: not armed" (the cave refused it), or "blow 455: nobody where it lands".

**Not covered:**

- A unit played whole, since every man swings and the engine's melee fights between swings.
- Multiplayer: the roll is not yet carried to every machine, and both `strikes()` and `P.strike` refuse there.
- Jump and charge attacks.
- A flyer's FLY_ATTACK and a rider's RIDER_ATTACK slots: no impact point is read for them, so they land 2.5 m ahead.
  **Fixed 2026-11-01:** read off their own clips (`data.lua impacts_fly`, `impacts_rider`, `impacts_rider_fly`;
  `PATCH_NOTES_20261101_THIRD_PERSON.md`).

Ponytail marks: the 0.5 m slack and the 60 degrees are guesses, not `exe+325fca4`'s thresholds, and only each slot's
first clip's impact point is used.

| Run (fixture as above, enemy halted, keys stubbed) | Result |
|---|---|
| Great Weapons, one man, 4 clicks on Orc Boyz | Blow 1: rolled a hit for 32 about 0.1 s after the post. The man struck went 81 -> 49 at 1.3 s, the impact frame, and the unit lost exactly 32. Blow 4: rolled blocked (28), no hit points moved. Blows 2 and 3: "nobody where it lands", because he stood 4.6 m from the nearest enemy after the first blow (the 10-29 baseline drifted 1.6 -> 3.9 m the same way) |
| Astragoth, a unit of one, 4 clicks | 3 blows rolled, 2 hits (352, 390) and 1 blocked; 10 Orc Boyz killed. His clips carry splash, so the unit's losses cannot be split between the blow and the splash: a "blocked" blow's man still lost 80 to splash |

Tests: `one_mans_swing_strikes_the_enemy_where_it_lands` (where the blow lands, the side blow, the clip reported late,
a unit of one), `a_blow_with_nobody_where_it_lands_strikes_nothing` (behind him, 30 m off, dead),
`the_cave_logs_a_blocked_blow_and_one_it_never_armed`,
`no_blow_is_struck_for_a_whole_unit_in_multiplayer_or_without_the_cave` (and a jump attack),
`a_blow_waiting_for_its_clip_goes_with_a_stop_or_his_death`, and `with_strikes_every_attack_clip_is_swung`. The
harness's fake `P.strike` takes the request on the next engine tick, as the cave does. **667 + 47 pass.**

Mutants: round 72, 19 of 19 caught. Each new script line was broken on its own, and each break was caught: the net,
whole-unit and feature gates, both directions of the dull filter, the jump gate, the reach and facing tests, the dead
check, the nearest pick, the x sign, the slot index, the impacts read, the wait for the clip, the not-armed log, the
call in `main.lua`, and both resets. The cave's emulator selftest has 40 of 40, including the 11 strike mutants.

## Still open

- Melee damage for a unit played whole and in multiplayer (the strike above covers one man and a unit of one, single
  player). Multiplayer needs the roll carried like the guard.
- Fire on the move: deferred ("Later"). **Built 2026-11-01** for the units with CA's fire whilst moving
  (`PATCH_NOTES_20261101_THIRD_PERSON.md`), harness only.
- F2 crash on a unit another mod swaps: needs the mod's name.
- Cavalry weapon animations and camera spin/jumps: not reproduced.
- Multiplayer porthole fix: harness only, no two-machine live run.
