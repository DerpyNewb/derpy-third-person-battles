# Third person: morale and effects on the bars, Alt brings CA's banners, the spell target marked (2026-10-22)

Three player requests from the 2026-10-22 Workshop triage (`WORKSHOP_REPORTS_20261022_THIRD_PERSON.md`, rows "Unit
info" and "Friend from foe"). Built offline, then checked live over the bridge the same day. **Packed as `f9a972df`,
uploaded to item 3822187184 on 2026-10-22 19:52 (manifest 3618937761616428547).** The multiplayer handshake fix (Ruling 30 in
`MP_FEASIBILITY_20261021_THIRD_PERSON.md`) ships in the same build.

The author's two rulings, asked before building:

- **Alt brings CA's banners back.** While the guide key shows its markers, CA's own unit banners show over every unit
  (type, side, health, morale, status in CA's art) and the pack's health bars step aside, so nothing shows twice.
- **Chevrons on the spell's target, his own units too.** No script call draws an outline; the unit an armed ability
  would hit gets CA's markers (`uc:highlight`), green on his own, red on an enemy.

## What changed

| File | Change |
|---|---|
| `tools/gen_tp_emitter.py` | state tags start with a letter (`<_0 name="0">`, as CA writes them); `kw["states"]` adds named states with their own image layers |
| `tools/gen_third_person_hud.py` | `bar_N` gains a morale strip (40x6 under the 40x10 bar, `MoralePercent`, CA's ui_colours "yellow" `#FFB900`) and two icons on their own pins: the morale state (CA's leadership/rout/shattered art, shown from `MoraleState` 4) and the effect arrow (`ActiveEffectState`, refreshed on CA's two ability-effect events). `check_bar` rewritten, 10 new selftest breaks (26 in all) |
| `ui/derpy_tp/bar_1..9.twui.xml` | regenerated; `hud.twui.xml` and `hud_layout.lua` unchanged |
| `script/derpy_tp/main.lua` | `banners(on)`: `set_banners_enabled` while `F.guide and S.guide_banners and not F.ui_off`; `hud()` shows `unit_id_holder` while on; `cursor()` re-sets them (the cinematic switch brings them back); the stop restores them |
| `script/derpy_tp/hud.lua` | bars hide while `F.banners`; `mark()` also marks `F.armed.unit`, his own included, and refreshes at once when it changes |
| `script/derpy_tp/settings.lua`, MCT page, `keys.lua` | `display_guide_banners` (on by default; off, Alt is the markers alone and "Health bars: With the markers key" works as before); the bars tooltip names the strip and icons; the guide key's label |
| `tools/preview_third_person_hud.py` | draws the strip and both icons per pin, bottom-centre rule; `--bars` writes `.skilltree_cache/ui_preview/tp_bars_<w>.png` |

The strip was first coloured by `MoraleColour` (CA's `morale_*`, green to steady). The preview drew our own units' green
health bar and the green strip as one thick bar, so it is a fixed colour that no side uses, and the icon carries the
state's colour.

## Checks

- `third_person_tests.lua`: **573 passed, 0 failed**. New: `the_guide_key_brings_cas_banners_back_and_the_bars_step_aside`
  (hold, hide, release, F2 off with the key held and with it up, press mode, the switch off, the guide bars setting,
  the default) and `an_armed_abilitys_target_is_marked_one_of_his_own_too`.
- Mutants, `probes/mutants_round58.py`: **12 of 12 killed**. The first run left two survivors. One was a test gap: F2 off
  was only tested with Alt held, so the banners were already on. The test now also covers it with the key up. The other
  was dead code: a bar refresh when only the banners changed. The banners change only with the guide key, or while the
  interface is hidden, and `H.show` restarts the refresh on the way back. The term was cut.
- `gen_third_person_hud.py --check` clean, `--selftest` 26 of 26 caught; TWUI Studio's reader finds no fault in the
  nine bars; `luac -p`, `check_lua_api.py` (0 suspect), `check_lua_literal_left.py` (0 sites).
- Preview at 1600/1920/2560: strip, morale icon and effect arrow clear of each other and of the bar on all three sides.

Backups of every edited file before the change: `Modding Files/Backup/tp_bars_banners_20261022/` (not `settings.lua`,
one added line).

## Live check (2026-10-22, build `f9a972df`)

One custom battle, Astragoth (Cascading Fire Cloak on a friend, Burning Wrath on an enemy) against orcs, the pack loaded
from the scratchpad with the minimal list. The game ran in the background and the author was not interrupted:
`E.P.focused` returned true, the look and wheel calls did nothing, and the keys came from a Lua table
(`P.held` reading `_G.TPK[vk]`). `E.settings` was wrapped to force `bars_range` 1000, and `create_unitcontroller` to log
every `highlight` call. Pictures came from `PrintWindow` on the game window, and per-unit values from
`common.get_context_value("CcoBattleUnit", uid, ...)`.

All five open items answered:

1. **CA's banners do draw under the cinematic UI**, and `unit_id_holder` holds them: one child per unit, named by its
   `unique_ui_id`. Alt held: banners on, our bars hidden. Released: the reverse. P with Alt held, then F2 off with the
   key up, also left the right one showing.
2. **`MoralePercent` is NOT 0..1.** It is morale over the best it could be: 1.06-1.57 across both armies at deploy, so
   the strip reads full at the start. Real losses took it to 0.21 (`MoraleState` 4), 0.135 (5) and 0.027 (6, "Broken").
   A forced rout (`uc:morale_behavior_rout`) gives 7, "Shattered", with the percent unchanged, and 1 is "Eager". The
   strip is still right as built: full until morale is truly hurt, then it falls. The generator comment is corrected.
3. **The morale icon shows from 4**, in the right state, and is hidden below it. **The effect arrow** showed `positive`
   under the cloak and hid when the cloak ran out. A `negative` state was not seen live: Burning Wrath does damage only
   and leaves no effect behind.
4. **Chevrons on the armed target:** green on his own unit with the cloak armed, red on the orcs with Burning Wrath, both
   cleared on the cast.
5. **The icons read at battle distance** at 720p (pictures in the session scratchpad, not kept).

Also seen: Ruling 30's single-player read (`MultiplayerRootContext.PlayerList` has size 0, so `players()` is empty and
nothing waits for an answer); `E.strikes` 0; no derpy line in the script log.

## Patch notes

The final wording is in `PATCH_NOTES_20261022_THIRD_PERSON.md` under "Second update".
