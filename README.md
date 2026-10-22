# Third-Person Battles

Play one unit of a **Total War: WARHAMMER III** battle from behind, as a third-person action
game. Press F2 on a unit, or on nothing to take your general, and you walk it with WASD, look with
the mouse, swing and shoot on the mouse buttons, and cast its abilities from a hotbar. Press F2
again to hand it back.

The mod is a beta on the Steam Workshop
([item 3822187184](https://steamcommunity.com/sharedfiles/filedetails/?id=3822187184)). This repository is its full source: the
Lua the pack is built from, the tools that build, test and check it, the probes that measured the
engine, and the design record.

## What it does

- **A follow camera.** It trails the unit a moment behind, sits over the right, left or top
  shoulder in ranged mode, centres on him in melee mode, and keeps out of the ground. Beside a
  building or under a gatehouse it stays with him instead of rising over the roof. V, or zooming
  in all the way, goes first person.
- **One man of a regiment.** In a regiment you play the front man. He walks, turns, swings and
  shoots alone while the rest hold their ground. A unit of one, such as a lord or a monster, is
  steered the same way, and so is a crew on one body (the Necrofex Colossus, the Warsphinx).
  Artillery, war machines and any regiment whose men cannot shoot alone are played whole.
- **Fighting.**
  - Left and right click swing, the attacks the man actually has split between them (a ranged
    unit has them all on the left, as its right button switches melee and ranged). A flyer in the
    air swings his flying attacks.
  - Hold Shift while moving to sprint and charge, and click during the charge to throw the charge
    attack. A flyer in the air plays his flying charge.
  - E is the jump attack.
  - In a melee a click swings at once, even with the enemy pressing in, and the man you play
    never swings on his own.
  - Each move plays out its whole animation, and the HUD counts its cooldown down.
  - A lord or monster cannot be hurt during his jump attack, his charge attack or a block, and
    blocks a blow that lands while he stands still.
- **Shooting.** A click fires one shot from the man himself: the raise, the shot and the reload.
  Hold the button and he keeps firing. Thrown bombs leave the hand late in the throw, as the
  animation does. A lord or monster fires at the crosshair through the game's own ground fire,
  waits out his reload, and plays his whole firing animation. A click on a gun fires it at the
  enemy in range nearest the crosshair, and its crew never swing; the mode key hands over to the
  game's own Manual fire view.
- **A HUD of its own.** It shows the portrait, health, men, ammo and reload, plus a ten-slot
  ability hotbar with cooldowns and an action bar for run, attack, fire, charge and jump. It uses
  the game's own fonts and art, by path.
- **Health bars and side markers.** A health bar over each unit near you, in its side's colour,
  pinned and filled by the game itself, with its morale under it. An icon beside the bar shows
  when the unit wavers or breaks, and another while a spell or ability is on it, up for good and
  down for bad. Holding Alt shows the game's own markers under the men of every unit you do not
  command, an enemy only while you can see it, and brings back the game's own unit banners in
  place of the bars. The unit an armed spell or ability would hit is marked, your own units too.
- **Every key and setting in the Mod Configuration Tool.** That covers 29 keys, the camera's
  distance, height, lag and melee distance, turning speed, hold or toggle to run, cooldowns,
  reload time, volley scatter, when the health bars show and how far, hold or press for the
  markers, and whether Alt brings the game's banners.
- **Multiplayer is experimental.** It runs when every player has the mod and memreader Plus,
  and does nothing in replays. It was built and tested offline but has not yet been run on two
  machines (`docs/history/MP_FEASIBILITY_20261021_THIRD_PERSON.md`).

It needs **memreader Plus**, a separate Workshop mod that lets Lua scripts read and write the
game's memory. That is how the mod reads the mouse and keys and sends a man an animation. Every
address lives in one file, `platform.lua`. A game patch that moves one turns off the feature
behind it, never the whole mod.

## What is here

| Path | What |
|---|---|
| `Modding Files/source/third_person/` | the pack's files: the battle script, the `derpy_tp` modules (about 3,000 lines of Lua), the MCT page and the HUD layout |
| `tools/` | the build, the Lua harness and its 573 tests, the two-machine simulation and its 41, the HUD generator and preview, and the checks |
| `tools/exe_re.py`, `tools/ghidra_decompile.py`, `docs/BATTLE_ENGINE_RE.md` | reading `Warhammer3.exe` from disk (who calls, who writes a field, which vtable slot; Ghidra headless for C), and what that found about a battle soldier |
| `Modding Files/source/lord_control/probes/` | 376 probe scripts run against the live game, and 80 mutation sets (978 mutants) |
| `docs/design/`, `docs/plans/` | the two specs, the core plan and the multiplayer plan |
| `docs/history/` | the handoffs written as each part was measured in game, the working ledger, and the multiplayer decision record |

The tools resolve paths relative to the author's workspace (`tools/`, `Modding Files/...`). This
repository keeps that layout, so they run from a clone.

`script/derpy_tp/data.lua` is generated from the game's database by
`build_third_person.py --gen`. It holds keys and numbers only: each unit's projectile, reload time
and shot count, and what each ability aims at. `script/derpy_tp/hud_layout.lua`,
`ui/derpy_tp/hud.twui.xml` and the nine unit bars `ui/derpy_tp/bar_1..9.twui.xml` (one per height
above the men) are generated by `gen_third_person_hud.py`. All of them are committed, so
the repository reads without running anything. Run the generator with `--check` and `git diff`
should stay empty.

## How it is tested

There is no test framework.

- **The shipped modules run.** `tools/third_person_harness.lua` loads the real `derpy_tp` files
  under Lua 5.1.5 against a stubbed battle: units, models, animation slots with clip lengths,
  the camera, keys, the UI tree and the MCT. `tools/third_person_tests.lua` then presses keys
  frame by frame and asserts on the commands the modules sent: 573 tests.
- **Two machines, simulated.** `tools/third_person_lockstep.lua` runs two copies of the shipped
  modules side by side, each with its own globals, and hands every queued command to both two
  ticks late, as a multiplayer battle does. `third_person_lockstep_tests.lua` fails if the two
  battles end up different: 41 tests.
- **Every rule is proven to be caught.** `probes/tp_mutate.py` plants one plausible mistake at a
  time in the shipped Lua, runs the suite, and restores the file byte for byte. It might be a
  guard dropped, a constant changed, or a branch inverted. A mutant the tests do not catch is a
  finding, and so is an anchor that no longer matches the code. 978 mutants in 80 sets; 15 of
  the oldest sets still carry stale anchors from code that was rewritten since.
- **Measured, not assumed.** Animation slot ids, clip lengths, the camera's floor and the
  projectile release point were each read from the running game through the probes, or from
  the game's own animation files. The handoffs record each measurement.
- **The pattern check.** `third_person_patterns.py` checks the byte pattern `platform.lua`
  relies on against `Warhammer3.exe` on disk, and prints the row to add for a build it does not
  know.
- **The code cave.** The engine's stop and walk calls for the man played run inside his own
  update on the battle thread, from a small machine-code cave (`third_person_cave.py` holds its
  assembly). `--check` matches the bytes in `platform.lua` and the site in the exe; `--selftest`
  runs those bytes under an x64 emulator through every path, and breaks them 29 ways. A second
  cave reads the multiplayer mode's messages on every machine, and is checked the same way.
- **The HUD.** `gen_third_person_hud.py --check` validates the generated layout.
  `preview_third_person_hud.py` draws the HUD from the shipped Lua at three resolutions, and with
  `--bars` the unit bars for each side at three health levels.

`py tools/build_third_person.py --selftest` runs all of the above except the mutants.

## Running it

You need Python 3 and [Lua 5.1.5](https://luabinaries.sourceforge.net/) (the scripts expect
`C:\Program Files (x86)\Lua\5.1\`), plus a Total War: WARHAMMER III install for the pattern check
and the HUD's art paths.

- **The API check** needs CA's scripting docs from the Assembly Kit, in
  `Modding Files/reference/ca_script_docs_wh3/`. Without them the self-test skips that step and
  says so.
- **The preview** needs the source of Backmechuisa's TWUI Studio (0.22.2) in `TWUI_Studio/src`.
  It is source-available under its own licence, so it is not included.
- **The cave's tests** need the Python packages `keystone-engine`, `unicorn` and `capstone`.
- **Building the pack** needs [RPFM](https://github.com/Frodo45127/rpfm) open with its MCP server.
- **The probes** talk to the running game through the WH3 MCP bridge (`probes/send.py`).

## Licence

MIT, see `LICENSE`.

This is an unofficial fan mod. Warhammer is a trademark of Games Workshop. Total War and Total
War: WARHAMMER III are trademarks of Creative Assembly and SEGA. Nothing of theirs is published
here: no art, no game files, no database tables, and none of CA's scripts or documentation. The
mod draws the game's own art at run time by its path.
