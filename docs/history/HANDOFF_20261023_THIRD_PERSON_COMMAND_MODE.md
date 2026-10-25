# Third person: command mode, the lord orders the army from third person (2026-10-23)

Built offline from the [spec](../superpowers/specs/2026-10-22-third-person-command-mode-design.md) and its
[7-task plan](../superpowers/plans/2026-10-22-third-person-command-mode.md). **Packed as `453d7cc2` and deployed to the
Workshop folder (item 3822187184) on 2026-10-23; not uploaded.** It carries session a1's multiplayer player-list fix in
`platform.lua`. The uploaded `f9a972df` is backed up in `Modding Files/Backup/tp_command_mode_20261022/`.

The author's rulings, asked before building: only the lord can enter command mode (spec Ruling 12, "the player lord when
pressing a button, will switch to command mode"); the key is Q; the orders are F1 follow, F3 charge, F4 hold. After the
build the author widened it: "add command mode for only heroes and general, configurable by mct if the player wants all
units to command". The general and his heroes command; the MCT checkbox "Any unit can command" (off) opens it to every
unit. The mouse stays as built (asked 2026-10-23): it turns the view, middle held frees it for CA's orders.

## What it does

Playing his general or a hero in third person (any unit, with the setting on), Q slows the battle (a quarter speed by default; never in multiplayer, and a battle at
speed 0 stays at 0), moves the eye 20 m back and up, and shows the crosshair as the order point. 1-6 pick Bannerlord's
groups (Infantry, Ranged, Cavalry, Monsters, Artillery, Heroes), 0 picks all, never his own unit; the pick wears CA's
chevrons. Left click moves the pick to the ground under the crosshair (Shift held: at the run), right click attacks the
enemy under it, both with CA's ping for two seconds. F1 has the pick follow 10 m behind him every 3 s until another
order, F3 sends each unit at its nearest enemy, F4 halts them and gives the shooters fire at will back. An order that
reaches a unit ordered under 0.5 s of model time ago waits, whole, until the last of its units may take it, so one order
is still one controller. Holding the middle mouse in the mode frees the cursor with CA's own orders on, for the rest of
the army only; a unit selected there leaves follow me. Q again gives the speed back, if the player has not picked another
meanwhile.

## What changed

| File | Change |
|---|---|
| `script/derpy_tp/command.lua` | new: the mode, groups, picks, orders, the 0.5 s order gap (a second order waits; the latest wins), follow me, pings |
| `script/derpy_tp/main.lua` | the pause read takes the battle speed (`PAUSE_AFTER / speed`, speed 0 at once); Q; no lock-on, wheel, fighting or first person in the mode; the crosshair; the freed mouse's `F.free_orders` and its selection guard; `E.command.stop()` at the stop |
| `script/derpy_tp/rig.lua` | `R.command(on)` and the command eye: 20 m at 0.45 rad, look floor 0.03 rad, entered at pitch 0.2, his pitch given back |
| `script/derpy_tp/hud.lua` | the pick's chevrons, refreshed when the pick changes |
| `script/derpy_tp/keys.lua`, `settings.lua`, MCT page, `battle/mod/derpy_third_person.lua` | four keys (Q, F1, F3, F4); "Command mode" section: speed (Normal/Half/Quarter/Paused), view distance (0-40 m, 20) and "Any unit can command" (off) |
| `script/derpy_tp/data.lua` | regenerated: `castes`, the card's `main_units.caste` per land unit (1,831) |
| `tools/build_third_person.py` | the `general_and_heroes` subtitle; `castes` in `--gen`; four caste probes |
| `tools/third_person_harness.lua` | battle speed, pings, the four unit getters, controllers over several units |
| `tools/third_person_lockstep.lua` | its net-mode `create_unitcontroller` took one unit and dropped the rest; it takes any number now |

Groups go by the unit card's category because CA's getters follow `land_units.category`, which files 218 of 271
monster-caste units as `inf_melee`. A unit `--gen` never saw falls back to the getters.

`--gen` also picked up 65 rows from two mods installed since 2026-10-20 (Greybeards, hkrul): abilities 30, bodies 7,
shots 5, speeds 5, fires 5, gravities 4, charges 3, runs 3, fires_low 1, fires_high 1, raises 1. Nothing was removed.

## Counts

- Suite 573 to 597 passed, 0 failed (24 tests); lockstep 41/41. With session a1's multiplayer player-list fix in the
  same tree: 598 and 42.
- Mutants `probes/mutants_round59.py`: 67, all killed (the heroes gate added four and replaced one). The first run left 7 survivors and 1 stale anchor. Six were
  missing assertions, now in the tests: the look floor, the pitch on entering, a war machine that is not artillery, F3
  passing over an untargetable enemy, follow me ending with third person, pings removed at the stop. The seventh was
  dead code, cut: `can_order`'s check against his own unit, which no pick ever holds.
- A fresh review found three faults, each fixed with a test that failed first: follow me sent back a unit the player
  had ordered with the freed mouse; one order split over two controllers when part of the pick was inside the gap; and
  the pause wait fell below its old half second above normal speed (0.17 s at 3x), so a heavy battle's slow ticks read
  as a pause. Ten minor findings are deferred, listed in the session's final report.
- `build_third_person.py --selftest`: no FINDING.

## One live battle answers the open questions (spec section 5)

Single player, his lord with infantry, archers and cavalry against the AI, minimal mod list (`docs/LIVE_TESTING.md`):

- [ ] F2 on the lord, Q: the battle runs at a quarter speed; Q again: back at 1 (Q3)
- [ ] 0, left click on open ground: the units move as a block, not onto one point (Q1)
- [ ] CA's move ping shows where the click landed, under the cinematic UI (Q2)
- [ ] 0 picked at 20 m: the chevrons read as a pick (Q5)
- [ ] 2 (archers) in range of an enemy, F4: they stop and keep shooting (Q6)
- [ ] middle mouse held in the mode: a card clicked and a right click orders that unit; his own card shift-clicked is dropped from the selection and never ordered (Q4)
- [ ] 1 then a click at once, at Quarter (under 2 s of real time): the infantry move. If not, the pick's chevrons (`uc:highlight` in `hud.lua` `mark`) count toward the 0.5 s order gap and every quick pick-then-click is lost
- [ ] if F4 leaves the archers silent, `fire_at_will` right after `halt` is dropped (Q6): it then needs a second send after the gap, which the one-slot `waiting` table cannot hold
- [ ] the script log has no command-mode errors, and no "create_unitcontroller() called but unit ... belongs to army" (Q1)

### First live run, 2026-10-23 (no pack: RPFM was shut)

The source was loaded over the bridge (`build_third_person.py --bridge`) into a single-player custom battle: Empire
general, captain, swordsmen, crossbowmen, knights against Skaven. The list was the intro skip, the bridge and both
memreader packs. Keys came from a fake `P.held` with the game in the background (scratchpad probe `tp_cmd_live.lua`).
Build `6acec6f4`, every platform feature on, 0 strikes, no SCRIPT ERROR.

- Q on the general: speed 1 to 0.25, and back to 1 on leaving (Q3 answered)
- the captain reads class `com` and enters the mode; the swordsmen are refused, then let in with `command_any_unit` forced on
- a move order to all four reached every unit through one `create_unitcontroller` (no "belongs to army" error); each made for a different spot, not one point (Q1 likely, not yet seen)
- F1: the swordsmen turned back toward the general as he walked
- not checked, because the HUD layout and the loc ship only in a pack: the plate, the chevrons (Q5), the subtitle's text
  (the key fired, its text was empty). Still open: the ping (Q2), the freed mouse (Q4), F4's archers (Q6), pick then
  click at once

Session a1's player-list fix, read in this battle: `M.players()` gives an empty list with `humans` 0; `PlayerList.Size`
is 0, `At(0).IsOnline` and `IsLocalPlayer` are nil, and nothing throws. Single player shows no hello or multiplayer lines.

### Second live run, 2026-10-23: the deployed pack and its MCT page

Lizardmen custom battle (Oldblood, Skink Chief, Saurus Warriors, Skink Skirmishers, Feral and Ancient Stegadon) under the
intro skip, the bridge, both memreader packs, MCT and the deployed pack (`8a21009f`, the build before the reload text).
MCT values set as its panel saves them (`set_finalized_setting`), defaults put back; `mct_registry.lua` holds the
defaults afterwards. 0 strikes, no SCRIPT ERROR.

- the page: "Command mode" holds the speed (Quarter), distance (20) and "Any unit can command" (off), with their
  texts; the Keys page holds Q, F1, F3, F4 with their labels
- speed: Normal 1, Paused 0, Quarter 0.25, and 1 again on leaving each time
- distance: 0 keeps the view (blend 0), 20 moves it out (blend 1.0)
- the Skink Chief commands; the Saurus Warriors are refused with the full subtitle, and let in with the setting on
- the plate, now the pack's HUD loaded: "Pick units: 1 to 6, 0 for all", "All: 5", "Artillery: none"

A player's question the same day ("Reload time": does 25 mean faster, and why no change on an Ancient and a normal
stegadon?): the setting is a share of the reload time, so lower is faster, and it reaches only one man of a regiment
shooting alone. Measured in that battle: the Ancient Stegadon is played whole as a crewed unit (`F.crew`, not
`F.solo`) and the Skink Chief as a unit of one, both on the game's own reload; one Skink Skirmisher shoots alone (6 s
base). The slider is now "Reload time (one man)" and its tooltip says all of that (`453d7cc2`).

## Patch notes

```
[list]
[*] Command mode: press Q as your lord to slow the battle and order your army from third person
[*] 1-6 pick infantry, ranged, cavalry, monsters, artillery, heroes; 0 picks everyone
[*] Left click moves them to the crosshair, right click attacks the enemy on it, hold Shift to run
[*] F1 follow me, F3 charge, F4 hold
[*] Hold middle mouse in command mode for the normal orders and unit cards
[*] Your general and heroes can use it; an MCT option lets any unit
[*] Multiplayer keeps the battle speed
[*] MCT: command mode speed and view distance
[*] Slow motion no longer counts as a pause
[*] Reload time setting: clearer text, it only affects one man shooting alone (not monsters, heroes or artillery)
[/list]
```
