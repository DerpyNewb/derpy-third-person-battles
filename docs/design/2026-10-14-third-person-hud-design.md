# Third-person HUD (plan 2) - design

Status, 2026-10-14: approved in conversation (layout, reload placement, approach A). Written spec awaiting the
author's review. Parent spec: `2026-10-13-third-person-pack-design.md`, whose section 7 this replaces.

## 1. What and why

While third person is on, cinematic UI hides CA's whole battle interface, porthole included (the author's choice,
2026-10-14). The pack draws its own HUD in its place, so the player still sees who he is playing, how hurt he is,
what he can fire and which abilities are ready.

Shown only while third person is on. Never takes mouse input. Follows UI scale. While the free-mouse key is held,
cinematic UI is off and CA's HUD returns; ours stays as well.

Out of scope here: the left-button charge (deferred by the author 2026-10-14, logged in the handoff), clicking the
hotbar, tooltips, any change to how abilities are cast.

## 2. Layout (the author chose "spread")

```text
+--------------------------------------------------------------+
|                                                              |
|                          .-~~-.                              |
|                         (  +   )   reload ring round the     |
|                          '-..-'    crosshair                 |
|                                                              |
| [card] ######-----   [1][2][3][4][5][6][7][8][9][0]    (o) 12 |
| [    ] Iron Hail                                     ranged  |
| [    ] 118 / 120                                             |
+--------------------------------------------------------------+
```

| Group | Anchor | Contents |
|---|---|---|
| Left | bottom-left corner | the unit's card portrait; beside it the health bar, the unit name, men alive (a regiment only) |
| Hotbar | bottom centre | up to 10 ability slots, in the order keys 1-0 cast them |
| Right | bottom-right corner | shots left and CA's melee or missile icon; hidden for a unit with no missile weapon (the mode icon stays) |
| Reload | the crosshair | CA's first-person `reload_ring`, filled while the shooter reloads |

Every group is placed with `MoveTo` from `core:get_screen_resolution()` and the margins in the generator dict,
multiplied by the UI scale. `dockpoint` is ignored on a runtime component (`docs/CUSTOM_UI.md`).

## 3. Look (brief per `docs/CUSTOM_UI.md`)

**Reference:** CA's battle HUD: the selected unit's porthole frame and its bronze ability buttons. Before the first
render, a desktop screenshot of CA's HUD with a unit selected is taken (`wh3-mcp/tools/screenshot.ps1`; the game's own
screenshot call captures no UI) and kept as `docs/mockups/tp_hud_reference.png`.

**Art, all CA's, all checked to exist by the generator:**

| Part | Art |
|---|---|
| Ability slot | `ui/skins/default/spell_dial_spell_frame.png` at 69x69 under the 59px icon, CA's own battle ability button (built 2026-10-14: `ability_frame_battle.png` is a riveted side panel, not a slot) |
| Slot that cannot be cast | `ui/skins/default/ability_inactive.png` over the icon at `#FFFFFF82`, CA's own tint |
| Slot cooldown | the seconds on `number_frame_lozenge_18px.png`, shown while cooling (the timer rings are two half arcs that only mean something rotated; dropped) |
| Key label | `number_frame_lozenge_18px.png` under the slot |
| Text plates | `ui/skins/default/tooltip_frame.png`, as CA's battle tooltips (`fill_black.png` is a ring, not a fill) |
| Ability icon | the ability's own icon path, from the unit context |
| Portrait | the unit context's `IconPath` (the unit card) |
| Health and ammo bars | `bar_back.png`, `bar_frame.png`, `ammo_bar.png` from CA's first-person UI |
| Mode | `ui/skins/default/icon_status_melee.png`; `icon_stat_ranged_damage.png` |
| Reload | the `reload_ring` of `ui/battle ui/first_person_ui` (already created for the crosshair) |

**Type:** `brand_header` and `la_gioconda_uppercase`, as CA's battle HUD uses. Key labels 12, unit name 14, shots
left 20, cooldown seconds 14. Text `#FFF8D7`; red only `FF2D2D` from `ui_colours`. Every text cell sits on a plate
(a `tooltip_frame` plate or a number lozenge), measured 4.5:1 or better.

**Avoid:** tinted-white boxes, one text size everywhere, centred everything, text on bare battlefield.

**Tokens:** every size, margin, colour and font in one dict, `HUD` in `tools/gen_third_person_hud.py`. The Lua reads
the sizes it needs from a generated `script/derpy_tp/hud_layout.lua`, so the two cannot disagree.

## 4. Data

| Part | Source | When read |
|---|---|---|
| Portrait, unit name | unit context `IconPath`, `Name` | when third person starts or the played unit changes |
| Health bar | `unit:unary_hitpoints()` | every frame |
| Men alive | `unit:number_of_men_alive()` / `unit:initial_number_of_men()`; hidden when the initial count is 1 | every frame |
| Shots left | `unit:ammo_left()` | every frame |
| Mode icon | `F.ranged` | on change |
| Reload, one man shooting alone | `F.shot` and `F.ready_at` (the shot is ours, not the engine's) | every frame |
| Reload, the regiment firing | unit context `ReloadPercentMax`, 0..1, where 1 is LOADED and shows no ring | every 0.2 s |
| Hotbar list | `unit:owned_non_passive_special_abilities()`, the list `abilities.lua` casts from | when the unit changes |
| Slot castable (the dim) | `unit:can_perform_special_ability(key)`, the call `abilities.lua` already gates a cast on | every frame |
| Slot icon, cooldown | the unit context's ability list (`BattleAbilityList`; `SpecialAbilitiesList` is a building's and answers nil on a unit), matched by `SetupAbilityContext.RecordKey`: `SetupAbilityContext.IconPath`, `RechargeTimeRemainingSecs` (0 ready, -1 passive) | every 0.2 s |

**The unit context** is read as CA's own scripts do it: `common.get_context_value("CcoBattleUnit", id, expr)`.
CA's doc entry lists two parameters but its own example, and CA's battle scripts, pass these three. The
id comes from the unit's card component (`GetContextObjectId("CcoBattleUnit")`, the card found by
`unique_ui_id`), read once per unit. Context reads are expressions the engine parses, so they are held to five a
second; script-API values are read every frame.

**Writes only on change.** Every component write compares against the last value written, so a frame where nothing
moved writes nothing.

**Cooldown text:** whole seconds, rounded up; none when ready. A slot with no ability in it is hidden.

## 5. Code

| File | Role |
|---|---|
| `tools/gen_third_person_hud.py` | writes `ui/derpy_tp/hud.twui.xml` and `script/derpy_tp/hud_layout.lua` from the `HUD` dict. `--check` (GUID pairing, every art path in CA's packs, every colour from the dict), `--selftest` (breaks each check once and sees it caught) |
| `ui/derpy_tp/hud.twui.xml` | the panel, created at the root at run time |
| `script/derpy_tp/hud.lua` | `H.show(on)`, `H.update(now)`, `H.unit_changed()`; loaded by `derpy_third_person.lua` like the other modules |
| `script/derpy_tp/main.lua` | calls `H.show` where the crosshair and cursor switch, and `H.update` from the tick |
| `tools/preview_third_person_hud.py` | renders the panel over an in-game screenshot at 1600, 1920 and 2560; exit 1 on low contrast or text wider than its box |
| `tools/build_third_person.py` | packs the `.twui.xml` too, and its selftest runs the generator's `--check` |

**Failure:** a component that does not build, or a context read that errors or returns nothing, hides that one part
and logs once (`E.once`). The rest of the HUD and the rest of the pack keep working. Three HUD errors in a battle
switch the HUD off for that battle, not third person.

## 6. Measured first, in game, before the panel is built

1. **The context id under cinematic UI.** Does the card's `GetContextObjectId("CcoBattleUnit")` still answer, and
   do `IconPath` and the ability list read through `common.get_context_value`, while cinematic UI hides the cards?
   If not: try the id `tostring(unit:unique_ui_id())`. If neither: slot icons come from the ability records the
   generator writes into `hud_layout.lua`, slots keep the key and the dim (`can_perform_special_ability` needs no context) but show no cooldown
   seconds, and the portrait is dropped.
2. **The reload ring from script.** `reload_ring` sits under `crosshair`, hidden, driven by CA's
   `BattleFirstPersonUI` callback. Can script show it and set its fill (the `loading_clip_l1/l2` clips resized)? If
   not: the ring moves into the right group as our own component built from `timer_ring1_ability.png` /
   `timer_ring2_ability.png`.
3. **A root panel under cinematic UI.** The crosshair draws there; checked once more with the real panel.

Each answer is recorded in the handoff and in memory before the code depends on it.

## 7. Testing

- **Harness** (`tools/third_person_tests.lua`), against a stubbed unit, `common.get_context_value` and UI components
  that record writes:
  - a slot dims when the ability cannot be cast, and undims when it can;
  - the cooldown text is the remaining seconds rounded up, and empty when ready;
  - a frame with no change writes nothing;
  - a context read that errors hides only its part, and the rest still updates;
  - the panel hides when third person goes off, and the hotbar rebuilds when the played unit changes;
  - the reload fill follows `F.ready_at` for one man, and `ReloadPercentMax` for a regiment;
  - men alive is hidden for a single entity; the ammo group is hidden with no missile weapon;
  - context reads are made at most five times a second.
- **Mutants:** a `mutants_hud.py` set, one per rule above, each killed.
- **Generator:** `--check` and `--selftest`.
- **Preview:** `preview_third_person_hud.py` at three resolutions, contrast measured.
- **In game:** a desktop screenshot with third person on, next to the reference. The author approves the look.

## 8. Done when

The selftest, mutants and generator checks pass; the preview passes at all three resolutions; the pack is built,
deployed and the author has approved an in-game screenshot against the reference.
