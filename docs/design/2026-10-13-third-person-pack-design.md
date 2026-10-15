# Third-person battle control: the Workshop pack - design

Status, 2026-10-13: maintained core source is `Modding Files/source/third_person/`, tested through the bridge; no pack built or deployed. Author confirmed gait/facing/HUD, full held fire/reload and mounted attacks. F2 movement without W remains unresolved; the latest experimental steering has one failing offline test. Read [the current handoff](../../sessions/HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md) before resuming. The earlier `source/lord_control/` prototype and its investigation are historical. The workspace root is not a Git repository.

## 1. Intent

The pack lets a player take one unit in a WH3 battle and play it from behind, as a third-person
action game: walk it with WASD, look with the mouse, swing and shoot on the mouse buttons, cast its
abilities from a hotbar. F2 toggles it. The aim, in the author's words, is "as close as a third
person game" the engine allows.

It is done when:
- a player who installs it with memreader Plus can press F2 on any unit and play it;
- every key can be changed in MCT;
- a game patch that moves an address turns off the feature behind that address, and never the
  whole mod and never the game.

Decisions (author, 2026-10-13):

| Question | Answer |
|---|---|
| Audience | a public Workshop mod |
| memreader Plus | required; without it the mod says so once and does nothing |
| Surviving patches | hybrid: a table of known builds, byte patterns for unknown builds, and a live check of every feature before use (section 8) |
| v1 scope | everything the probe does, plus ability hotkeys and a character HUD |
| HUD | a custom panel for the hotbar, health, mode and ammo, beside CA's own porthole portrait |
| A regiment | played as one man: he walks, swings and shoots alone (spike result, section 2) |
| Ranged fire | a click fires one shot; holding plays fire, then reload, then fires again, until released |
| Keys | every one configurable through MCT, the toggle included |

## 2. What the probe proved

| Feature | How | Handoff |
|---|---|---|
| Follow camera | `cam:move_to` every frame with player camera input off; plays the unit back 0.45 s late between position samples | §9 |
| Walking | a move order 15 m ahead, re-ordered no more often than every 0.5 s (orders under 0.4 s apart stall a unit) | §9b |
| Swing | a forged play-animation command on the battle command queue; the swing deals damage, so 1.5 s cooldown | §9e |
| Zoom | our own DirectInput 8 mouse for the wheel; `+`/`-` held | §9f |
| Ranged lord, single entity | ground fire (`attack_location`) at the crosshair point, turning first when the aim is outside 20 deg | §9g |
| Artillery | right click opens the game's Manual fire mode; control comes back when it closes | §9h |
| Crosshair, shoulder camera | our own instance of CA's `first_person_ui` layout showing only its crosshair | §9h |
| One man walks alone | two persistent steering copies; individual-walk point writes and native handover from regiment walk are the latest experiment, with F2 idle movement still unresolved | [current correction](../../sessions/HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md) |
| One man shoots alone | `bm:trigger_projectile_launch` from him to the aim point; the regiment holds fire | §9j |

Things the probe does that the pack must not copy:
- Windows calls through hand-copied import-table RVAs. The pack reads the import table at run time.
- `script_F2`, CA's fixed shortcut, as the toggle. The pack polls a key from MCT.
- ~~Cinematic UI to hide the cursor.~~ **Reversed 2026-10-14 by the author:** the pack now does exactly this.
  The cursor-only route (`SetCursor`) kept CA's HUD, and with it the selection markers, unit flags and hover
  panels; no script call or found memory flag hides a selected unit's marker. Cinematic UI hides all of it.
- A per-man projectile table typed by hand for one battle. The pack generates it from the DB.
- Checking that the played man is alive every 30 frames. Section 8 says every frame.

## 3. What was ruled out

- **memreader Plus as an optional dependency.** With it missing, there is no mouse-look, no
  keys and no swing. What is left is a camera that cannot be steered, and that is not the
  product.
- **Stopping the other men of a regiment from firing.** Zeroing the fields a fire order sets on
  every man but one changed nothing, because the engine rewrites them each tick. A forced fire
  animation launches nothing (§9j). The scripted projectile replaces both.
- **The engine's own wheel zoom.** The per-frame `move_to` wipes it (§9f).
- **Writing a unit's move destination in memory.** It does not keep the unit walking (§9b).
- **`play_anim_for_captain`.** It does nothing; its captain list is always empty (§9e).
- ~~**A portrait of our own.**~~ **Reversed 2026-10-14:** cinematic UI hides CA's porthole while looking, so
  plan 2's panel carries a portrait of its own (a still, not CA's live render).
- **One of the two patch strategies alone.** A build table alone dies on every patch. Byte
  patterns alone can match the wrong function and write through it. Section 8 uses both, and a
  live check decides.

## 4. Files

The pack is `derpy_third_person.pack`. Every path is lowercase, per the 6.1 rule.

| In the pack | Role |
|---|---|
| `script/battle/mod/derpy_third_person.lua` | The only auto-loaded file. Checks memreader, multiplayer and replay, then loads the four modules below in order with `loadfile` and `core:get_env()`. Load order between `mod/` files is therefore never relied on. |
| `script/derpy_tp/platform.lua` | **The only file with an address, an offset or a memreader call.** Covers the import table, keys and mouse, the cursor, the DirectInput wheel, the animation command, the model list, a model's position and steering, and the build check. Its interface: `held(key)`, `pressed(key)`, `mouse_delta()`, `wheel()`, `cursor(show)`, `play(model, slot)`, `models(unit)`, `model_pos(m)`, `steer(m, x, z)`, `alive(unit, m)`, `features`. |
| `script/derpy_tp/data.lua` | Generated, never edited by hand. Maps each unit type to its projectile key, base reload time and projectiles per shot, and each ability to its icon and target kind. |
| `script/derpy_tp/main.lua` | Gameplay, written against the platform interface only: the toggle, camera rigs, movement, melee, ranged, artillery, zoom, ability keys, MCT settings and the restore. |
| `script/derpy_tp/hud.lua` + `ui/derpy_tp/hud.twui.xml` | The HUD panel (section 7). |
| `script/mct/settings/derpy_third_person.lua` | Every key and tuning value (section 5). |
| `text/db/derpy_third_person.loc` | MCT labels and HUD text. |

Splitting into modules also clears Lua 5.1's limit of 60 upvalues per function, which the probe hit
on 2026-10-13 when the solo-shot constants went in.

The source lives in `Modding Files/source/third_person/`, as the lord_control probe does.
`tools/build_third_person.py`:
- `--gen` writes `data.lua` from `db.pack` through `read_vanilla_db.py`, so RPFM can stay shut;
- `--selftest` runs the section 9 checks;
- with no flag, it packs through the RPFM MCP server and reads the saved pack back.

`tools/preview_third_person_hud.py` renders the HUD (section 9).

## 5. Controls and MCT

Every binding is an MCT dropdown of key names, stored as a Windows virtual-key code. The settings
are read again at each toggle, so a change made mid-battle applies at the next F2.

| Action | Default | Behaviour |
|---|---|---|
| Third person on/off | F2 | Polled through the platform layer, so it can be rebound |
| Move | W A S D | Camera-relative. One man of a regiment walks alone, and the regiment gets no orders |
| Run | Shift | Toggle |
| Look | mouse | Cursor hidden; hold the middle button to free it |
| Attack | left click | Melee: a swing, then a 1.5 s cooldown. Ranged: see section 6. Artillery: nothing |
| Mode | right click | Switches melee and ranged; ranged brings the shoulder camera and the crosshair. On artillery it opens the game's Manual fire mode, and closes it again |
| Zoom | wheel, `+`/`-` | 0.6x to 6x, remembered per unit type for the battle |
| Abilities 1-10 | 1 2 3 4 5 6 7 8 9 0 | Hotbar slot N |

That is 21 bindings: the toggle, four moves, run, look, attack, mode, zoom in, zoom out and ten
ability slots. Design section 2 said 18; this count is the correct one.

The MCT page has four sections:
1. **Keys:** the 21 bindings.
2. **Camera:** mouse sensitivity, invert Y, follow distance, shoulder side (left or right), zoom
   speed.
3. **Combat:**
   - swing cooldown;
   - regiments played as one man (on or off; off plays the whole regiment as before);
   - one-man firing waits for the full native fire and reload clips; no reload-time multiplier.
4. **Debug:** off by default. Logs every order and every platform check result to the script log.

Two rules apply to every binding:
- **Without MCT,** the defaults above apply and nothing errors.
- **Two actions on one key** is reported once, on the MCT page and in the script log. The later
  action falls back to its default, so one wrong choice cannot silently disable movement.

## 6. Combat

**Melee.**
- The unit turns to the camera if it is more than 25 deg off, then plays the next attack
  animation from its list.
- One man of a regiment swings alone, with no turn order to the regiment.
- If the animation command fails its check, the click becomes an attack order on the enemy
  nearest the aim.

**Ranged fire.** A click always fires one shot, even if released at once. Holding plays fire,
then reload, then fires again, until the button is released. What fires depends on the unit:

| Unit | Shot |
|---|---|
| One man of a regiment, type in `data.lua` | His own shot, below. While F2 is on, the rest of the regiment's fire-at-will is off; F2 off turns it back on |
| Single-entity unit or lord | The game's ground fire at the crosshair, so the unit's skills and buffs count. Holding keeps the order up and re-aims it as the crosshair moves; releasing stops it after the shot in flight |
| A regiment whose type is not in `data.lua` (a modded unit) | The whole regiment's ground fire, as for a single entity |
| Artillery | None from the attack key; the mode key opens Manual fire |

One man's shot:
1. He turns to face the aim point (section 10, item 3).
2. His fire animation plays (`FIRE_LEVEL`, slot 1557).
3. At the animation's release, `bm:trigger_projectile_launch(key, from, to)` fires. `from` is
   1.5 m above his feet, 1.5 m toward the aim. `to` is 1 m above the aim point. A type with
   `projectile_number` above 1 fires that many, jittered by up to 1.5 m.
4. One shot comes off the regiment's ammo with `set_current_ammo_unary`. The measured result was
   exact: 3960 went to 3959.
5. When the firing clip finishes, his active animation fragment chooses `RELOAD_1` (1564),
   or `SHOOT_READY_TO_AIM_LEVEL` (1554) for crossbows without a separate reload slot. Reload
   uses full-body mask 6; it remains active even when it has no event metadata.
6. The next shot waits for the engine to clear both event metadata and the body mask. Holding repeats
   the full cycle; release finishes the current reload without starting another shot.
   This supersedes the earlier 0.25 reload-time factor at the author's request on 2026-10-13.
7. A step ends the reload at once; it never cuts the aim or the firing clip (2026-10-14, the author: the 14 s
   reload held him in place). The mode key drops any phase. Once a shot has left, the next waits the
   projectile's `base_reload_time` from the reload's start. A crossbow's reload is its next raise to aim.
   Whatever clip was dropped, the first step plays `WALK_1` with mask 0, because a dropped mask-6 clip stays
   latched under a walk and he slides in its pose (measured 2026-10-14).

`data.lua` is generated through `main_units.land_unit -> land_units.primary_missile_weapon ->
missile_weapons.default_projectile -> projectiles`, which gives the key, `base_reload_time` and
`projectile_number`.

**Abilities.**
- The hotbar lists `unit:owned_non_passive_special_abilities()` in order, and key N casts slot N.
- A ground-targeted ability lands on the crosshair point (`perform_special_ability_ground`).
- A unit-targeted ability goes to the unit nearest the crosshair ray
  (`perform_special_ability(key, unit)`): a friend for a buff, an enemy for anything else.
- A self ability casts with no target.
- `can_perform_special_ability` gates each cast; a refused key does nothing, and the slot shows
  why.
- The target kind comes from `data.lua` for vanilla abilities and from CA's UI context objects at
  run time for modded ones. An ability with no known kind casts on self.

## 7. HUD

> **Superseded 2026-10-14** by `2026-10-14-third-person-hud-design.md` (plan 2): spread layout, reload ring
> round the crosshair, our own panel filled from Lua. The text below is the earlier design.

> **Changed 2026-10-14 (the author):** cinematic UI while looking hides CA's whole interface, porthole
> included. Everything below that keeps CA's porthole applies only while the mouse is freed. Plan 2's panel is
> created at the root, as the crosshair is (it drew under cinematic UI in the probe), and carries a portrait of
> its own beside the hotbar, health, mode and ammo. Its placement no longer follows the porthole.

**Brief.** CA's battle HUD: the selected-unit porthole at bottom left, with the unit's ability bar
beside it. The reference pictures are the author's porthole screenshot and one more in-game shot
of the HUD. That one is taken by the author, because `common.take_screenshot` never captures UI.

- **CA's porthole** stays untouched. On F2 the played unit is selected in the UI, so the porthole
  shows its face.
- While F2 is on, the remaining battle HUD and markers are hidden; the porthole's portrait and
  ability bar, the separate crosshair and our panel are kept. F2 off restores original
  visibility, including components that were already hidden. This requirement was confirmed
  during the 2026-10-13 live continuation.
- **Our panel** sits beside it, in the bronze art of CA's ability bar:
  - **Hotbar:** up to 10 slots. Each shows the ability's icon, its key label (1-0) in a corner,
    a dim when the ability cannot be cast, and the cooldown in seconds. The cooldown comes from
    CA's UI context objects; if they cannot be reached, the slot shows only ready or not ready.
  - **Health:** the unit's hitpoint bar, plus men alive for a regiment.
  - **Mode:** CA's melee or missile stat icon.
  - **Ammo:** shots left, and a ring that fills while the shooter reloads.
- **The crosshair** stays separate: our instance of CA's first-person crosshair, as in the probe.
- **Rules from `docs/CUSTOM_UI.md`:**
  - CA fonts only. Key labels are 12, the ammo figure 18-20.
  - Text is `#FFF8D7`, at a measured contrast of 4.5:1 or better.
  - Colours come from CA's `ui_colours` table, with one accent.
  - Every size and colour lives in one generator dict.
- **Placement.** The panel is created at run time and placed with `MoveTo` against the porthole's
  drawn art, not its component box, so it follows UI scale. It shows only while F2 is on and
  never takes mouse input.

## 8. Patch safety, multiplayer, failure handling

**What a patch can break** is all in `platform.lua`:

| Group | What depends on the build |
|---|---|
| Animation command | three exe addresses: the command type, the push function and the battle global |
| A regiment's men | the live model list, `+0xA4`/`+0xA8` of the unit object |
| One man | position `+0x88`; persistent points `+0x1E0/+0x1E8`, `+0x194/+0x198`; command type at `+0x330` gates its point at `+0x368/+0x370` |
| Windows calls | the import table, parsed at run time rather than stored |

The scripted shot, the ammo change, every order, the camera, the UI and MCT are all documented
calls, so a patch does not break them.

**The check, run once per battle at the first toggle:**
1. Read the exe build from its PE header. A known build uses its stored row.
2. An unknown build finds the three addresses by byte pattern.
3. Either way, each feature is checked live before it is used:
   - a model's first qword is the expected model type marker;
   - a model's `+0x88` lies within 5 m of its unit's `position()`;
   - the command queue pointer is non-null, and its two gate bytes read 0 or 1.

**A failed check turns off one feature and keeps the rest:**

| Failed | Falls back to |
|---|---|
| Animation command | Swings become attack orders on the enemy nearest the aim |
| Model offsets | The regiment is played whole: move orders, and the regiment's own fire |
| Walking command types unknown | The regiment is played whole; the animation byte pattern still supplies forced swings when the model checks pass |
| DirectInput | Zoom on `+`/`-` only |
| memreader missing, or the input calls unreadable | Nothing runs; one message says memreader Plus is required |

Each fallback is logged once, naming the check that failed. A new build gets its row in the table
only after every check passes on it.

**2026-10-13 correction:** `+0x330` is a polymorphic command object. Its `+0x38` is a walking x
coordinate for two measured 9.0 command types, but an integer animation state for a state-change
command. Writing three copies unconditionally caused the 19:14 crash. `features.steer` requires
known walking types and native start/speed routines; every third-copy write checks the current
type. An idle soldier starts walking through the engine's command constructor, with no position
nudges. Shift selects native speed and gait. Startup halts prior unit orders, since disabling
fire-at-will alone does not cancel targeted fire. **F2 movement without W remains unresolved.**
Latest source experiments with native handover from regiment walk to individual walk, instead
of updating both layouts in place; this branch has no valid active-control live verification
and one failing offline test. See the
[current handoff](../../sessions/HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md).

The individual facing word at `+0xb0` holds camera yaw while controlled. The native walking
command also receives that heading and the walk/run gait byte; changing speed alone did not
change the animation. These were confirmed by the author in the same live continuation.

**Multiplayer and replays.** The toggle does nothing when `battle:is_multiplayer()` or
`battle:is_replay()` is true, with a one-line message. Memory writes and scripted shots would
desync a multiplayer battle.

**Failure handling.**
- **Errors.** Each frame runs inside `pcall`. An error stops third person, logs once with the
  traceback, and restores everything:
  - player orders and the camera controls;
  - the cursor;
  - the regiment's fire-at-will;
  - the crosshair and HUD are hidden.

  The toggle works again afterwards. A third error in one battle switches the mod off until the
  battle ends.
- **Automatic stops.** The same restore runs when the battle ends, when the played unit dies or
  routs, and on quitting to the menu.
- **Dead men.** A dead man is removed from the model list, and his memory can be freed. So before
  every write, the played man is checked against the live list in that same frame. If he is gone,
  the next front-centre man takes over.
- **Timers.** Every one-shot timer gets a unique id. CA's timer code frees an id before running
  its callback, so a timer registered again under the same id from inside it is dropped.

## 9. Testing

1. **Offline selftest, the build gate.** `build_third_person.py --selftest` runs every module under
   Lua 5.1.5 against a stubbed battle (`bm`, camera, units, UI) and a fake platform layer. It
   checks:
   - every binding reaches its action, and a duplicate key falls back to its default;
   - ranged fire: a click gives one shot; holding gives fire, reload, fire; release stops after
     the shot in flight;
   - the restore puts back everything section 8 lists;
   - three errors switch the mod off for the battle;
   - multiplayer and replays do nothing;
   - each failed platform check gives its fallback from the table in section 8;
   - `data.lua` holds the crossbowmen row the probe measured (`wh3_cth_crossbow_bolt`, 13, 1).

   Each check is proven by breaking the code it guards and watching it fail. `luac -p`,
   `check_lua_api.py` and `check_lua_literal_left.py` run on every module.
2. **HUD preview.** `preview_third_person_hud.py` draws the panel from CA's art at 1600, 1920 and
   2560 wide and measures text contrast. The pictures are compared with the reference shots and
   fixed before anything ships.
3. **Live run through the bridge**, one battle, one run per unit kind:

   | Unit kind | Measured |
   |---|---|
   | Melee general | swing damage; the cooldown holds |
   | Ranged lord | a hold keeps fire going; release stops it |
   | One man, melee | his neighbours move under 0.5 m |
   | One man, ranged | shots in T s match the reload pace; regiment ammo drops by exactly the shots fired; the other men fire none; F2 off gives them their fire back |
   | Artillery | Manual fire opens, closes, and control comes back |
   | Unknown modded regiment | the whole regiment fires |

4. **After each game patch,** the Debug switch prints every platform check as pass or fail.
5. **Shipping.** The saved pack is exported back and compared file by file with the source, every
   path is checked lowercase, and the pack is copied to its Workshop folder.

## 10. Open facts, measured before they are relied on

1. **Hiding the cursor without cinematic UI.** The probe uses cinematic UI, which hides the HUD
   too. `ShowCursor` (IAT `0x33a2c10`) and `SetCursor` (`0x33a2bc0`) are imported, which makes a
   route possible but untested. This is measured first, because the HUD depends on it.
2. **Reload completion, measured 2026-10-13.** Full-body mask 6 at model+0x284 holds reloads
   without metadata. Native wait checks it and metadata at +0x898; +0x278 alone can be stale.
   Crossbows use slot 1554 (~1.3 s), ironhail slot 1564 (14 s). Held fire waits for completion.
   See [the current handoff](../../sessions/HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md) for traces and limits.
3. **Individual facing, fixed 2026-10-13.** Model+0xb0 and native walk heading follow camera yaw;
   the author confirmed independence from the regiment. Facing continues during fire/reload.
4. **The bolt's timing.** Release now follows 300 model ms after the firing clip actually starts,
   respecting pause and speed. Visual alignment with each weapon remains to be calibrated.
5. **What a scripted shot carries.** Not yet measured: whether the regiment's damage
   buffs and accuracy apply, whether kills count toward its experience, and whether
   `projectiles.can_damage_allies` rows hurt the man's own regiment.
6. **One man's walk/run gait, confirmed 2026-10-13.** Native speed and gait follow Shift; the author confirmed walking and running. **F2 idle/stop responsiveness remains open:** the first correction still moved without W; the subsequent handover experiment is unverified.
7. **Ability target kind and cooldown seconds** from CA's UI context objects.
8. **The Manual fire button stays hidden** after the 2026-10-13 probing; `common.trigger_shortcut
   ("toggle_first_person_mode")` is the untested alternative to clicking it.
9. **The camera drifts back on fast mounts**, by `DELAY` times the unit's speed (handoff §10,
   item 3).

## 11. Done

- All section 9 checks pass. The live run covers all six unit kinds. The author has played it
  and approved the HUD against the reference.
- The section 10 items are measured, and each one is either fixed or written into this spec as a
  limit.
- The pack is in its Workshop folder, and the handoff and `docs/MY_MODS.md` describe it.
