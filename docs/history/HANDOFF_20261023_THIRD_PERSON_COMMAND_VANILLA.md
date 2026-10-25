# Third person: command mode, Vanilla style (2026-10-23)

This was built from the [spec](../superpowers/specs/2026-10-23-third-person-command-mode-vanilla-design.md) and its
[7-task plan](../superpowers/plans/2026-10-23-third-person-command-mode-vanilla.md), following the author's call: "the
current system is not what i envision ... jsut be like the vanilla command but just in third person view".

**State:** packed as `b38ac007` and deployed to the Workshop folder (item 3822187184). It is not uploaded. It also
carries session a1's `platform.lua` change, which leaves a lobby's AI slots out of the multiplayer player list. The packs
before it are `453d7cc2` (the Bannerlord-only command mode, in
`Modding Files/Backup/tp_command_vanilla_20261023/workshop_before_deploy/`), then `0f3fdc95`, `76f15110`, `cede944c`,
`feb4e344` and `ecd73dc8` (the review fixes, before the minors). The build tool backed each one up as `Modding Files/Backup/derpy_third_person_<time>.pack`.

This entry follows [the Bannerlord-style command mode](HANDOFF_20261023_THIRD_PERSON_COMMAND_MODE.md). That build is
still there, as the second choice of the new MCT setting.

## What it does

A new MCT setting, "Command style", has two choices:
- **Vanilla** (the new default).
- **Bannerlord** (the 2026-10-22 build, unchanged).

In the Vanilla style, Q on his general or a hero gives the player CA's own battle controls at the crosshair, with the
camera still on the lord:
- **Selection and orders:** CA's selection, right-click orders, a drag for frontage, Ctrl and Shift on CA's own keys,
  and CA's whole HUD with its cards.
- **Numpad:** Numpad 1-9 and 0 select cards 1-10 in CA's order. E pages to cards 11-20 and wraps. Each page is said in
  the subtitle ("Numpad: units 11-20").
  - A dead unit's card keeps its number and selects nothing. The numbers after it do not shift.
  - His own unit is never picked, and an ally's units have no card, so they have no number.
  - Num Lock must be on. The labels say so.
- **Middle mouse:** a middle click frees the cursor, and another takes it back to the crosshair. A middle drag only
  turns the view (author, live: "middle mouse dragging should not also activate toggle"). The rule is
  `main.lua` `MID_STILL` 8 px inside `LOCK_CLICK` 0.3 s.
- **Speed:** Space pauses and unpauses. A Shift tap goes slow, and another goes back to 1x. In multiplayer neither
  touches the speed.
- **His unit:** it stays put. When a CA order takes it in, one halt goes through `F.uc`, the shared command in
  multiplayer.
- **Flags:** CA's 3D unit flags are off in the mode (the author, live: "its blocking the cursor because the lord flag is
  in the way"). CA has one banner switch for every unit. Alt still shows them.
- **The pack's panel** stays up on top of CA's HUD (the author's choice, live). It sits a margin over CA's bottom band,
  measured from the tops of `porthole_parent`, `battle_orders` and `winds_of_magic`. The corner buttons sit under CA's
  radar. A "Back to third person" plate with the command key's name sits above the bar. The freed cursor can click it
  (`back_plate`, the one interactive part of the pack's HUD), and it takes no click while hidden. P hides both HUDs and
  shows both.
- **Set aside in the mode** (the author's two answers after seeing the frames): his plate (portrait, health, men,
  winds, stamina), because CA's unit information panel covers that corner while a unit is selected; the five action
  buttons; and the ability bar's key labels and page tab, because in the mode E pages, Shift slows and the number row is
  CA's. The bar keeps his abilities and their timers. `hud.lua` `AWAY`, set in `H.back`.
- **Leaving:** Q, F2, losing his unit or the battle ending gives back CA's own controls, cursor, flags and speed, and the
  next session starts on the mouse-look.

### What changed

| File | Change |
|---|---|
| `script/derpy_tp/command.lua` | The Vanilla branch of `enter`/`leave`/`update`: cards and pages, the numpad, Space/Shift (a tap spoiled by any other key), stay-put, fire at will held again once a gap (`faw_at`), and CA's two centre holders set non-interactive in the mode (`CENTRE`) |
| `script/derpy_tp/main.lua` | Middle click versus drag (`F.mid`, `MID_STILL`); no flags in the mode; P shows CA's HUD and the pack's panel together; the way back's click taken in the tick (`F.back_click`) |
| `script/derpy_tp/hud.lua` | `H.place` stands on CA's band and under CA's radar in the mode; `H.back` (the plate, its click, the parts set aside) and the `back_plate` listener, which only asks |
| `tools/check_lua_api.py` | Its `find` rules now read receivers longer than one character (`id:find`); they read only `s:find` before |
| `script/derpy_tp/keys.lua`, `settings.lua`, MCT page | `cmd_unit_1..10`, `cmd_page` (E), `cmd_pause` (Space), `cmd_speed` (Shift), shared with jump/fly/sprint, which the mode turns off; "Command style" |
| `tools/gen_third_person_hud.py` | The back plate, text, key plate and key; `CLICKABLE = {"back_plate"}`, checked per component, with a selftest case |
| `tools/build_third_person.py` | Loc `derpy_tp_command_page`; `--selftest` refuses any `find(` in the pack's Lua |
| `tools/third_person_harness.lua` | `UNIT:is_moving`, `H.ca_order`, `u._halt_lags` and `u._faw_lags` (a halt or fire at will that lands a tick late), `COMP:IsInteractive`, CA's centre holders and `battle_orders`/`winds_of_magic` in `fresh` |

## Measured live, 2026-10-23

Two single-player custom battles on the deployed pack, with the minimal list (`docs/LIVE_TESTING.md`):

- The numpad and E work: 1 selects unit 2, 3 selects unit 4, and 0 selects unit 11. After E, 1 selects unit 12 and 4
  selects nothing. E wraps, then 2 selects unit 3. The camera stays still through all of it.
- Right- and left-clicks at the crosshair did nothing at first, and the author saw the cursor flicker. The cause was
  CA's `hud_battle > spawn_zone_icons_parent` and `reinforcement_icons_parent`. Both are 1x1 boxes on the screen's
  centre pixel and interactive. The parked cursor clicked them, and over them CA set its cursor every frame: 252 of 252
  `GetCursorInfo` samples showed it, against 0 of 493 once they were non-interactive.
  - The spike had missed this because the Bannerlord style hides CA's HUD.
  - `enable_cinematic_ui(false,false,false)` also stops the flicker, but then CA takes no world click (measured both
    ways), so it is not the fix.
  - A patch that anchors a third interactive holder there needs it added to `CENTRE`.
- A left-click selected the general, and an attack right-click landed near him. His own flag was under the crosshair,
  so the flags are now off. Not re-checked since the change.
- Three more runs on the panel, read from the component tree (`take_screenshot` gave UI frames only some of the time
  this session, unfocused both ways):
  - At 1600x900 UI, the panel's lowest part ends at 618, 24 above the porthole's top at 642. The corner buttons start
    at 268, 24 under the radar's 244. The way back is centred (661 to 939 of 1600).
  - CA's unit information panel (`info_panel_parent`, 10,56 267x574) covered his plate while a unit was selected. That
    is why it is set aside now.
  - After leaving, `back_plate` stood hidden but interactive at y 755, over CA's cards. It now takes no click while
    hidden.
  - **The game's `string.find` matches plain text only.** `find("^tab")`, `find("%d")`, `find("[b]")` and captures give
    nothing; `match` and `gsub` take patterns. `id:find("^slot_%d+_key")` left the bar's keys up while the harness
    (stock Lua) was green. It is now `match`, and the gate refuses `find`. Memory
    `wh3-string-find-anchor-returns-nothing`.
  - On `ecd73dc8`: his plate, the actions, the keys and the tab are aside in the mode, the icons are kept, the way back
    is clickable there only, and all of it is back on Q and after F2. No script errors.
  - On `b38ac007`: the way back has the states `standard,hover`, and hover draws the frame plus its lit bar. In the mode
    the panel ends at 618; after Q it ends at 876 of 900 (the 24 px margin), the keys and his plate are back, and the
    way back is hidden and takes no click. The first launch built nothing: the list lacked the two memreader packs
    (`docs/LIVE_TESTING.md` now says so).

## The final review

A fresh reviewer read the whole change: 0 Critical, 4 Important, 6 Minor. All of these were fixed test-first:
- F2 inside the mode left his unit in melee mode (leaving had cleared what the stop reads).
- The fire-at-will re-hold went out every frame until it landed, 6 a tick at 1x and a shared order each in multiplayer.
- The way back left the mode inside CA's unguarded listener.
- The hidden way back stayed clickable.
- A quick Shift+W switched the speed, which spec 4.6 rules out. The reviewer graded this Minor; I re-graded it.

The author then asked for the five Minors ("fix minor issues first"). They are fixed in `b38ac007`, each with a test:
- The stay-put halt stamps `F.last_order`, so a walk right after it waits its gap instead of being dropped.
- Leaving the mode no longer redraws the whole HUD. `H.back` gives each set-aside part back as it was last asked
  (`hud.lua` `asked`), and `leave()` re-places the panel. The ability bar keeps its page.
- The panel's floor counts only the band parts CA shows, read from `F.hidden_ui` while third person hides CA's HUD.
- F1/F3/F4 and the number-row group labels say "Bannerlord style". The MCT tooltip names the key's partner for the
  four shared pairs.
- The way back has CA's click sound and a hover state. `gen_third_person_hud.py` `check()` refuses a clickable part
  without either.

The rulings on what the reviewer set aside are in the plan ledger
(`.superpowers/sdd/2026-10-23-third-person-command-mode-vanilla/progress.md`).

## Counts

- Suite: 598 to 624 passed, 0 failed (616 with a1's test before the review fixes, 620 before the minors).
- Lockstep: 45 passed (three are session a1's).
- Mutants `probes/mutants_round60.py`: 107 of 107 killed. Dropping `E.hud.place()` from `leave()` is only visible
  with the minimap off (`E.hud.map(true)` re-places the panel), so that mutant runs against
  `leaving_the_mode_keeps_the_ability_bars_page`. Round 59 (the Bannerlord style): 67 of 67, after seven anchors
  were moved to follow the code.
- Mutant survivors became new assertions:
  - the stay-put clock (with the harness's late halt);
  - the Bannerlord panel staying up;
  - the free cursor on a middle hold.
- Four pieces of dead code were cut rather than tested. The ledger lists them.
- Checks: `build_third_person.py --selftest` has no FINDING. `gen_third_person_hud.py --check`/`--selftest`,
  `preview_third_person_hud.py --check` and `check_lua_api.py --selftest` are clean.

## Still open

- **A real mouse:** Ctrl+click, box select, a drag's frontage, Shift and Space, and a left-click no longer selecting the
  general now that the flags are off.
- **A regiment played whole, fighting in melee inside the mode:** count the stay-put halts. If `is_moving()` reads true
  in melee, he gets one every 0.5 s.
- **Multiplayer:** needs two machines.

## Patch notes

```
[list]
[*] Command mode has a new default style: the normal Total War controls while the camera stays on your lord
[*] Select, right-click, drag for frontage, Ctrl and Shift, all as normal, at the crosshair
[*] Numpad 1-0 select unit cards, E shows units 11-20 (Num Lock on)
[*] Middle click frees the cursor, again to lock it; middle drag still turns the view
[*] Space pauses, Shift taps slow time
[*] Your own unit stays where it is
[*] The mod's panel stays up above the game's, with a Back to third person button
[*] In command mode your portrait plate and action buttons step aside, ability bar stays without key numbers
[*] No unit flags in the way while in command mode (Alt still shows them)
[*] MCT: Command style, Vanilla or Bannerlord (the old 1-6 groups)
[/list]
```
