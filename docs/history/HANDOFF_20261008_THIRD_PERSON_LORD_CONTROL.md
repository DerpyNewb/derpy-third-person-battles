# Third-person lord control in battle - investigation, 2026-10-08

**2026-10-13 continuation:** maintained core source now lives in `Modding Files/source/third_person/`; this prototype investigation is historical. Start at [the current handoff](HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md) for confirmed held fire/mounted attacks, native steering corrections, and the unresolved F2 movement bug. The parked status and earlier shared-point/reload-factor assumptions below are superseded; no core pack is built or deployed.

**The goal:** control your legendary lord in battle like a third-person RPG character, with a
camera behind him, direct movement from the keyboard, and attacking yourself.

**Status: parked.** The camera already exists in vanilla. Movement is the wall: every way the
game moves a unit is a move order, and the user rejected that feel twice (once as a script
prototype, once with vanilla's own arrow keys). Real direct control is possible only through
memreader_plus. That needs reverse-engineering nobody has done, and it was **not attempted**.
Section 7 is the one-session test that would settle it.

Nothing is installed. The prototype pack was deleted from `data/` and `Modpacks/`, and every
live probe and listener was removed from the running battle.

---

## 1. What already exists

- **No Workshop mod does this.** A [2023 request thread](https://steamcommunity.com/app/1142710/discussions/0/3842178984956877144/)
  asked for exactly this, and so did a WH1 thread; neither ended with a mod. One reply linked
  Workshop item `2799316652`, which was never checked because Steam rate-limited every fetch.
- **The engine has a third-person camera: the unit camera.** Select a unit and press **Delete**
  (or Insert). The shortcut is `toggle_tracking` in `data/text/default_keys.xml`. The HUD shows
  "Press <ESCAPE> to exit unit camera", and the view sits behind the unit's back at shoulder
  height, about 4.5 m away (user screenshot, measured by probe).
- **The arrow keys move the selected unit inside the unit camera; W/A/S/D do not.**
  `battle_land_step_forward/backwards`, `battle_land_strafe_left/right` and
  `battle_both_rotate_left/right` (Up/Down, Left/Right, Ctrl+Left/Right) are all
  `repeating="1"`, not hidden, and rebindable in the Controls menu. **They behave like move
  orders** (he re-paths, turns and accelerates as from a right-click), so the user rejected
  them as third-person control.
- **Manual artillery fire is aim-only.** `land_units.first_person` keys into
  `first_person_engines_tables` (30 rows, column `allow_direct_control`). 58 of 2,679 land units
  use it: 41 artillery, 14 war machines, 3 war beasts, and no characters. Every column is about
  aiming; none is about movement. The user tested a mobile vehicle: "can only shoot".
  `toggle_first_person_mode` is commented out in `default_keys.xml` ("now part of cinematic
  system").

## 2. What scripts can and cannot do (battle)

| Need | Verdict | Evidence |
|---|---|---|
| Run code every frame | **Yes** | `bm:repeat_real_callback(fn, 1, name)`: 701 calls in 6.0 s, 1,320 in 10 s, no gap over 18 ms. CA's lib: real timers are "synchronised to UI updates", faster than the 100-200 ms model tick |
| Read discrete key presses | Yes, nine keys | `script_F2`/`F3`/`F4` plus `_shift_` and `_ctrl_` variants ("Hidden keypress listeners for script", mode "all"); `core:add_listener(..., "ShortcutPressed", ...)` with `context.string` |
| Read a key being held, or the mouse | **No** | CA documents no key-up event; `common.key_down`/`key_up`/`mouse_event` only *simulate* input |
| Order the lord around | Yes | unitcontroller `goto_location`, `attack_unit`, `perform_special_ability`, `halt`; CA's own pattern is order then `release_control()` so the player keeps control |
| Move the camera | Yes, but see §4 | `camera:move_to(pos, target, secs, linear, fov)`, `position()`, `target()`, `change_height_range(min, max)`, `enable_functionality(name, on)` |
| Control a character directly | **No** | every route is an order through the unit system |

Other facts found on the way:

- Battle mods load from `script/battle/mod/` and run their file body at load time; `bm` already
  exists (lib_header creates it before loading mods). Nothing calls a mod function later, as
  `core:execute_mods` does in campaign.
- `bm` answers every `battle:` member: `battle_manager:new()` calls `set_object_class(bm, self, b)`.
  `tools/check_lua_api.py` now knows this (it used to flag `bm:camera()`, which CA calls 810 times).
- **Shift+F2 fires `script_shift_F2` and then plain `script_F2`**, 0.1 s apart, seen twice in a
  script log. Give each action its own base key. The installed dev-tools console owns Shift+F3
  and Shift+F4, so a plain F3/F4 handler also fires whenever someone opens it.
- `unit:position()` changes every **~0.3 s** with the game focused (33 updates in 10 s) and every
  ~0.74 s in the background. A script-driven follow has to predict between updates.

## 3. The rejected prototype

`derpy_lord_control` (one battle script; single player only; the keys do nothing until
deployment ends):

- F2: select the general, script chase camera
- Shift+F2: same with the unit camera
- F3: walk where the camera faces
- F4: attack the nearest visible enemy in front

It loaded clean and toggled in game. The user rejected it: "not what I'm envisioning". The
Shift+F2 bug above came from it.

- Script: `Modding Files/source/lord_control/derpy_lord_control.lua` (moved out of `pack/` so a
  bulk add cannot ship it)
- Build and check: `tools/build_lord_control.py --selftest` runs the script under Lua 5.1 against
  stubbed battle objects and presses the keys. 9 of 9 plausible-bug mutants were caught. With no
  argument it packs to `Modpacks/` (needs RPFM open).

## 4. The camera experiment (live, through the wh3-mcp bridge)

| Probe | Result |
|---|---|
| `camera:target()` | A far look-direction point, **~576 m** from the camera and often below the terrain. Not the ground under the view, so the camera cannot be "pointed at the lord" by setting `target` to his position |
| One `move_to` with the camera's own position and target | A true no-op: 30 frames read back identical |
| The same `move_to` every frame (lord standing still) | **Fights the player's camera.** The camera was not where the script left it on 70 of 3,614 frames, by up to 71 m; the user saw it "teleporting everywhere" |
| `change_height_range(1.5, 1000)` in the unit camera | **Tipped it to stare at the ground.** `change_height_range(-1, -1)` restores CA's defaults |
| The unit camera (Delete) | Follows him, about 4.5 m behind, down to his height. This is the camera to build on |

Probes: `Modding Files/source/lord_control/probes/`. `send.py <file.lua>` writes the bridge's
command file in the F: install and prints the result (the shipped `send-eval.mjs` hardcodes
C:). Each probe is wrapped in `pcall` and avoids `string.*`; see memory
`wh3-mcp-bridge-wedges-after-eval-error`. `i_track.lua` contains the height change that tipped
the camera; take it out before reusing that probe.

## 5. memreader_plus - what it can and cannot do here

Workshop 3811098873, v0.8.1, installed and loaded in battle. It drops a native DLL and loads it
with `require`. Its README says:

- **reads and writes** any address; `find_pattern` searches the exe's code
- `call(addr, sig, ...)` works **only inside `Warhammer3.exe`**, so it cannot call Windows APIs
  (no `GetAsyncKeyState` or `GetCursorPos`)
- `hook` runs a Lua callback **only when the game calls the target on the script thread**, and
  game script functions must not be called inside a callback (one crashed a campaign)
- no per-frame callback of its own; real timers (§2) already provide one
- `ud_topointer(userdata)` returns a script interface's address, and **the game object is the
  pointer at +0x10** in it
- addresses are userdata, used through `mr.add`/`sub`/...; never apply Lua operators to them
  (the game's Lua numbers are float32)
- **no offsets ship**: every address is reverse-engineered and a patch can move it. Single
  player only

## 6. Assessment

| Part of a third-person RPG | Likelihood | Why |
|---|---|---|
| Camera behind the lord | **Done in vanilla** | the unit camera |
| Spells and abilities on hotkeys | **Done in vanilla** | vanilla hotkeys |
| Held-key WASD movement that feels like a character | Unlikely | needs memreader writes to the lord's movement state in the battle simulation, which runs in ~0.3 s steps (up to 0.3 s lag), and must not fight pathfinding or break the walk/run animation blend |
| Turning with the mouse | Unknown | the script API cannot read the mouse; would also need memreader |
| Swing, block or dodge on a click | Very unlikely | the combat simulation picks every attack and matched-kill animation itself; no script call says "attack now" |

## 7. The open next step (not started)

A one-session yes/no test of direct control:

1. In a live battle, through the bridge: `local p = memreader_plus.ud_topointer(lord)` for the
   general's `battle_unit`. Find the game object at +0x10, and dump floats around it until the
   values that match `lord:position()` and `lord:bearing()` turn up.
2. Write a new heading (then a small position offset) there, and watch for three outcomes:
   - he turns smoothly: the engine honours it
   - he snaps back: the simulation overwrites it every step
   - the game crashes: the wrong field
3. Only on "turns smoothly" is a direct-control mod worth designing.

The battle-unit interface may not follow the +0x10 rule that the README states for campaign
interfaces; checking that is step 1. One Lua error inside a bridge eval can wedge the bridge
until the game restarts, so `pcall` everything.

## Memory written this session

- `wh3-first-person-direct-fire-is-db-driven`
- `wh3-script-shift-key-also-fires-plain`
- `wh3-battle-unit-camera-and-per-frame-lua`

## 8. Addendum 2026-10-13: the first memreader pass, live

Custom battle, single player, memreader Plus 0.10.0, through the bridge and an external reader.
Probes `k_` to `w_` and `memscan.py` are in `Modding Files/source/lord_control/probes/`. Nothing
was packed; the camera preference was set back to 0.

- **Battle script interfaces do not follow the README's `+0x10` rule.** The general's
  `battle_unit` interface holds `0x20` there. Its vtable is at `+0`, and the game object is the
  pointer at `+8`. Behind that pointer, `+0x208`/`+0x20C`/`+0x210` is **the move destination**,
  not his position. It matched `unit:position()` only while he stood on it; when ordered 40 m
  forward it jumped to the goal at once and held there for 617 of 632 frames. The position
  `unit:position()` reads is at `o>168>0+136` (object `+168` -> `+0` -> `+0x88`). His smooth,
  drawn position was not within three pointer hops. Only read, never written.
- **Every `bm:camera()` call creates a new wrapper.** Slot `+0` of a wrapper links into the
  allocation pool. It points at whichever `battle_vector` the script creates next, so it is not
  the camera. Nothing within three pointer hops of the wrapper holds the camera's position.
- **The camera's render state is easy to find and useless to write.** Scanning the whole process
  for `cam:target()` and keeping the hits that followed a real move gave a struct: position at
  `+0x54`, target at `+0x60`, **FOV 1.13446 (65°) at `+0x70`**, aspect 1.77778 at `+0x74`, and
  13000 (far clip, probably) at `+0x84`. There are several copies, plus a ring of GPU constant
  buffers at `0x7ff4…`. A FOV write to one copy and a height write to another were both
  overwritten within a second: they are rebuilt every frame. The controller that owns the real
  state (probably a focus point, heading, pitch and height, since y stayed constant while panning)
  was not found. The next route is "what writes this address" (a hardware write breakpoint,
  Cheat Engine), then a `hook_site` or `code_cave` there.
- **`default_battle_camera_type`** (`0` totalwar, `1` rts, `2` debug, `3` cinematic, `4` arena)
  can be set from script with `core:set_integer_preference`, and `bm:restart_battle()` reloads
  the battle. With `4` the battle loaded and opened on the normal deployment camera, with no
  visible change. Unit camera (Delete) behaviour under `4` was not separately compared.
- **The unit camera's follow distance is not data.** `battle_cameras_tables` holds only the
  strategic camera's height and speed limits. `battlespeeches/camera_shots/*.battle_speech_camera`
  is a commander-relative keyframe system (`subject_type = COMMANDER`, `position_offset`, `fov`)
  for the old battle speeches. It is not the live camera.
- **The game's Lua treats NaN as close to everything.** `math.abs(v - w) < tol` was true for
  NaN slots against five different targets. A memory scan in Lua has to require several adjacent
  matches, or test `v ~= v` first.
- `common.take_screenshot("name.tga")` writes to `<game>/screenshots/` (3D scene only), which
  lets a probe see the battle without asking the player.

## 9. A script-owned follow camera works (2026-10-13, route 2)

`Modding Files/source/lord_control/probes/zz_follow_on.lua` (installed live through the bridge,
not packed; `zz_follow_off.lua` removes it, `zz_follow_read.lua` reads its stats). F2 toggles.

- `cam:enable_functionality("CAMERA_ALL_FUNCTIONS", false)` turns the player's camera input
  off, and that ends the "teleporting" fight in §4. `true` gives it back.
- **`move_to`'s 6th argument defaults to `true` (command queue)**, so each per-frame placement
  lands a tick late. With the queue on, the camera read back more than 5 cm from where it was put
  on 589 of 646 frames. With `false`, it was 4 of 243, max 0.31 m (the first catch-up frame).
- `unit:position()` steps every ~0.2 s (25 changes in 632 frames). **Extrapolating from the
  last step's velocity was not smooth.** A 300-frame log showed a sawtooth: 0.2-0.3 m/s between
  steps and ~1.2 m/s each time a step landed. The live version uses delayed interpolation: it
  plays him back `DELAY` seconds late and lerps position and bearing between the two real samples
  either side of that moment, with a light spring on top (k = 20 / 8). With 0.3 s, walking
  measured a steady 1.0-1.5 m/s. A gap between steps longer than `DELAY` (step gaps reach ~0.35 s
  at 60 fps) holds and then jumps (0.26 -> 2.0 m/s), so `DELAY` is now 0.45. The cost is that
  the camera trails him by `DELAY` x his speed. Bearing convention: forward = (sin b, cos b) on (x, z), so
  180 faces -z.
- Placement: 6 m behind, 2.5 m up, looking at a point 6 m ahead and 1.8 m up. Screenshots in
  melee show an over-the-shoulder view on the general.
- **`create_unitcontroller` takes units only.** CA's doc says `(army, units...)`, but the
  shipped `lib_battle_misc.lua` runs `is_unit` on every argument, so passing the army returns
  `false`.
- memreader was not needed for this. It becomes needed for mouse-look (`GetCursorPos`), the
  smooth drawn position, or writing the move destination.
- **memreader can call Windows through the exe's import table.** `probes/exe_imports.py` parses
  `Warhammer3.exe` (stdlib only) and lists IAT RVAs: `GetCursorPos 0x33a2e38`,
  `GetAsyncKeyState 0x33a2cc0`, `SetCursorPos 0x33a2c20` and `GetForegroundWindow 0x33a2b70`
  (9.0; re-run the script after a patch). In game, `read_pointer(add(add(base, 0x3300000), lo))`
  gives the function (split, because RVAs above 2^24 lose float32 bits), and
  `mr.call(p, "int32(pointer)", buf)` returned the real cursor (1374, 721). The probe refuses to
  call unless the slot points into `0x7FF…`. The follow camera uses this for middle-mouse orbit,
  which is not yet confirmed by the player.
- **Mouse-look is confirmed by the player.** While F2 is on, the mouse orbits the camera and the
  cursor is parked at the window centre (`GetClientRect` + `ClientToScreen`, re-centred each
  frame with `SetCursorPos`). Holding the middle button frees the cursor. Nothing happens unless
  `GetForegroundWindow` is the window captured at F2.
- **`bm:enable_cinematic_ui(true, false, false)` hides the cursor AND the whole battle HUD**
  (confirmed by the player). `(false, true, false)` gives both back. CA's doc says only "cursor
  and cinematic bars".

## 9b. Keyboard movement (2026-10-13): the player says "it feels good"

Same probe, `zz_follow_on.lua`. **W/A/S/D walk him relative to the camera, and tapping Shift
toggles running** (the player asked for a toggle, not a hold). Keys are read with
`GetAsyncKeyState` through memreader, only while the game window is in front.

- **The camera's yaw now belongs to the mouse alone** (`F.cyaw`). While it followed his
  bearing, steering him would have swung the camera and changed what "right" means, so pressing D
  would have circled him.
- Right vector on (x, z): `(fz, -fx)` for forward `(fx, fz) = (sin yaw, cos yaw)` (`RIGHT_SIGN = 1`).
  The player has not reported A/D reversed.
- **Steering, as built (replaces the `order`/`mem` modes, both removed):** a held key orders
  the unit to `pos + dir * LEAD` (15 m) and re-orders only when one of these happens: it gets
  within `REFRESH` (6 m), the keys or the run toggle change, or the camera turns more than
  `STEER_DEG` (12 deg) **and** `STEER_GAP` (0.5 s) has passed since the last order.
- **The player's bug, "holding W does not move him continuously", had two causes:**
  - **The destination writes did nothing.** In `mem` mode the order targeted 3 m ahead, so he
    walked 3 m and stopped. Writing `+0x208/+0x210` every frame did not extend the walk.
  - **Move orders under ~0.4 s apart stall a unit outright.** Mouse-look turns the camera a few
    pixels nearly every frame, so with no gap every small turn re-ordered. Simulated W hold plus
    a 40 deg/s camera turn on the same unit: with no gap, 20 orders in 6 s and **0 m moved**;
    with a 0.4 s gap, 13 orders and a steady 2.0-2.3 m/s for the full 6 s. Shipped at 0.5 s
    for margin. The 0.3 s vs 0.4 s cliff suggests each order takes about that long to start
    the unit moving, and a new order resets it.
- Test hook: `F.sim = {forward, right, until_os_clock, yaw_deg_per_s}` stands in for held keys
  and mouse turn. `F.why` counts why each order fired (`start`/`keys`/`run`/`near`/`steer`).
- In the Skaven horde, every method gave 0.45-0.75 m/s. The crowd, not the method, sets the
  speed in melee.
- `create_unitcontroller(lord)` is created once at install, and every order is followed by
  `release_control()`, so the player can still give him normal orders.

## 9c. Mouse attacks and any unit (2026-10-13, built, player test pending)

- **F2 takes the selected unit** when exactly one is selected (`bm:num_units_selected() == 1`),
  otherwise the general. Selection is tracked with `bm:register_unit_selection_callback` on every
  player unit, keyed by `unit:unique_ui_id()` and registered once per battle. Raw userdata is
  not used as a table key.
- **Left click = `attack_unit(target, true, running)`** (primary attack: melee for melee units,
  shooting for missile units). **Right click = `attack_unit(target, false, true)`** (secondary,
  charging). Buttons are edge-detected with `GetAsyncKeyState`, and count only while mouse-look
  is active. The target is the enemy nearest the aim: within cos 0.707 of the camera's forward
  and 150 m, or within 8 m in any direction, scored as distance x (2 - cos). Verified once from
  the bridge: the target was an enemy 96 m away and dead ahead, and the gap closed to 64 m in 3 s.
- **`bm:disable_orders(true)` blocks the player's orders but not script orders**: an 8 m script
  `goto_location` moved him 7.98 m with it on. It is on while F2 is active, so vanilla
  left/right-click orders at the parked cursor cannot override the attacks. **It also blocks the
  player's ability hotkeys.** Casting in third person needs our own keys and
  `perform_special_ability`.
- Script cannot play a swing. `attack_unit` engages; the combat simulation still picks every
  attack and matched kill.

## 9d. "Force attack in the camera direction": no script route (2026-10-13)

The player wants a click to make the model swing toward where the camera faces, whether or not a
unit is there. Tested live on an idle general in open ground, framed side-on, with screenshots
before and during and a pixel diff around him (`probes/a1_*`-`a6_*`):

- **`unit:play_anim_for_captain(key, false)`** ("compels the unit leader to play an
  animation"; CA's scripts never call it) **showed nothing** for `ATTACK_1`, `attack_1`,
  `ATTACK_2`, `CELEBRATE_1`, `TAUNT_1` or `VO_STAND_ORDER_ATTACK`. The diffs (1.8-7.5) match the
  nonsense-key control and the frames show idle shuffling only. Not yet tried: a multi-model
  regiment, whose captain is a separate model. This army had none with more than 10 men. If it
  works there, the single-model general simply has no "captain" for it.
- **`unitcontroller:attack_location(point, false)`** on the melee general: **moved 0 m**,
  nothing played. It is ground fire for missile units and artillery.
- **`attack_unit`** works but needs an enemy unit, and the simulation picks the swings. The
  probe's click-to-attack (nearest enemy to the aim) is the closest script approximation.
- Slot names come from `tools/external/TheAssetEditor/.../AnimationSlots/Warhammer3AnimationSlots_9_0.txt`
  (2,057 slots).
- **What remains is memreader reverse-engineering**: find the engine function that starts an
  entity's attack or animation (for example, the native code behind `play_anim_for_captain`) and
  call it on the general's entity. Even then, a free-played swing deals damage only if the
  simulation counts it. Melee hits are resolved by the combat simulation, not by the animation,
  except splash attacks, which come from `.anm.meta` tags on large models. Not attempted.

## 9e. REVERSE-ENGINEERED: forcing an attack animation on the general (2026-10-13)

**Result: the general swung his sword on command, in open ground with no enemy near.** A forged
copy of the engine's own play-animation command, queued through memreader. Probes: `r1`-`r6` in
`probes/`. Template: `r6_queue_anim_template.lua`. Tools: `re.py` (disassembler over the live
process, capstone) and `memscan.py`. All 9.0 addresses; re-derive them after a patch.

The chain, as disassembled:
1. **Script methods:** every `battle_unit` method is one shared dispatcher (`exe+2f12c28`)
   plus one upvalue pointing at a `{name, function}` entry in a method table. `getmetatable` and
   `tostring(u.method)` give the closure, and its C function is at closure `+0x20`. Entry for
   `play_anim_for_captain` -> `exe+2efc24c`.
2. **`play_anim_for_captain`** converts the key with `exe+1585570`, a static name -> u16 slot
   map built from the table at `exe+36c7ae0` (32-byte entries, `{u64 id, char* name, ...}`,
   2,262 slots; `MISSING_ANIM` = 0, `ATTACK_1` = `0x1c6`; a miss returns `0x8d4`; uppercase
   only). It then searches the unit object's vector at `+0x114/+0x118` for a model whose
   `vtable+0x630` answers yes. **That vector is empty for every unit in normal play** (20
   Skaven regiments of 211-309 models and the general all read 0), so the call silently does
   nothing. That is why every key looked dead.
3. It would build the command `{+0 type = exe+3901cd0, +8 model*, +0x10 u16 slot, +0x12 u8
   loop, +0x14 u32 0}`, check two gate bytes (`[[exe+4479ee0]+0x468]+0x3b0/+0x3b1` == 0) and
   push it with `exe+2e969ac(queue = [..+0x468]+0x644e8, &cmd)`. The push **serializes the
   command by value** through the type's serializer, `[exe+3901cd0]` = `exe+2ee79ec`, which
   writes the model id (`model+0x258`), the slot name and the loop flag. Commands therefore go
   through the deterministic queue (replays and multiplayer), and the caller's buffer is not
   kept.
4. **Models:** the unit object (`interface+8`) holds two model vectors, `{cap, size, data}` with
   size at `+0xa4` / data `+0xa8`, and size at `+0x184` / data `+0x188`. Model class vtable
   `exe+390d4f8`. A 291-model Skaven unit reads 291 in both; the general reads 1.
5. **The working call:** build the command with `model = [unit+0xa8][0]`, push it, and it
   returns 1. `ATTACK_1` (`0x1c6` = 454) played a full overhead swing.
   `CELEBRATE_1` (`0x446`) did nothing visible, probably because that skeleton has no such
   animation. Latency: nothing at +0.25 s or +0.55 s, the swing visible at +0.95 s; not yet
   resolved further.

**Wired into the controller (`zz_follow_on.lua`):** left click cycles `ATTACK_1-4`, right
click cycles `ATTACK_5-7`. If the unit faces more than 25 deg away from the camera, it first
turns in place (`goto_location_angle_width(own position, camera yaw, ordered_width)`) and swings
0.35 s later. The command is pushed for every model in the unit (capped at 160), so regiments
swing as well. Without memreader, clicks fall back to `attack_unit` on the enemy nearest the aim.
Verified from the bridge: one model queued with `ATTACK_1`, and the general's swing is visible
from the follow camera at +1.3-1.8 s.

**A forced swing that connects deals damage** (player, 2026-10-13), so the simulation counts
it. The controller therefore allows one swing per `ATTACK_COOLDOWN` (1.5 s); clicks inside it
are dropped and counted in `F.cooling`. Verified from the bridge: 3 clicks gave 1 swing, and
2 s later 3 more gave 1 more.

Open: latency (about 1 s, the queue plus the
wind-up?), which `ATTACK_n` each skeleton has, and how a regiment-wide swing looks.

## 9f. Zoom: the wheel through our own DirectInput mouse, and `+`/`-` (2026-10-13)

Big entities showed only their feet: the camera is a fixed rig (6 m back, 2.5 m up, looking
1.8 m up). **`F.zoom` now scales the whole rig**, from 0.6x to 6x. It is remembered per
`unit:type()` in `_G.DERPY_ZOOM` for the battle. It starts at 1 for `is_infantry()` units and 2
for everything else. The battle API has no size or height call, only `unit_class()` and
`type()`.

- **Keys:** holding `+`/`-` (main row or numpad) zooms at 1.2/s. Player-confirmed.
- **The engine's wheel zoom is useless here.** CA's docs list `MOUSE_ZOOM_CAMERA` as a separate
  functionality flag, so the test left only that flag on and read how far the engine moved the
  camera each frame. Result: one 3% step in about 27 s of scrolling. The per-frame `move_to`
  wipes the engine's zoom. The wheel does not fire `ShortcutPressed` either: a catch-all listener
  saw only `script_F2`.
- **What works: our own DirectInput 8 mouse.** The exe imports `DirectInput8Create` (IAT
  `0x33a2140`), so memreader can call it, then the COM methods through their vtables:
  - `IDirectInput8W` index 3 is `CreateDevice(GUID_SysMouse)`.
  - On the device: 11 `SetDataFormat`, 13 `SetCooperativeLevel(hwnd, NONEXCLUSIVE|BACKGROUND)`,
    7 `Acquire` and 9 `GetDeviceState`.

  The data format is hand-built with one object: `GUID_ZAxis`, `DIDFT_AXIS|DIDFT_ANYINSTANCE`,
  with `DIDF_RELAXIS` set. So `GetDeviceState(4 bytes)` returns the wheel's movement since the
  last poll, 120 per notch. The GUIDs are written byte by byte, because the bridge forbids
  backslashes.

  All five calls returned 0. The first probe caught 13 events totalling 1,680 (14 notches) while
  the player scrolled. Non-exclusive access shares the mouse with the game. Each notch scales the
  zoom by `exp(0.15)`, about 16%, and counts only while the game window is in front. The first
  poll after F2 is discarded. There is one device per battle, never released.
- `exe_imports.py` with no arguments prints only its 10 default names. Pass the names you want,
  or use `imports()` for the full 808-entry table.

## 9g. Ranged units, and one man of a regiment (2026-10-13, built, not yet tested live)

The player asked for: ranged units and lords; right click to switch between melee and ranged;
and, in a regiment, control of one man ("preferably the officer"). Measured on Cathay crossbowmen
(180 men, range 160) before the battle ended:

- **`unitcontroller:attack_location(point, false)` makes missile infantry shoot at a ground
  point.** This is the order behind artillery's "hold ALT to manually aim" (game text
  `shortcut_localisation_onscreen_adv_manual_aim`). Ammo went 3960, 3947, 3933 over 6 s with the
  point 80 m ahead, and the unit did not move. It keeps firing until halted. `uc:halt()` stopped
  it: 3522 at the halt, then 3521 and 3521 over the next 6 s.
- **It does not turn the unit.** With the point 60 deg off its facing, the unit fired nothing for
  5 s and only shuffled 1.6 m. Turning first with `goto_location_angle_width` at its own position
  took the 180-man block **9 s for 60 deg**. At 11 deg off, `attack_location` fired: 3521, then
  3512 and 3499 over 5 s. So there is a firing arc. The controller turns first when the aim is
  more than `FIRE_ARC` (20 deg) off.
- **`unit:position_of_officer()` returns nil** on a normal regiment, consistent with the empty
  captain vector (§9e) and with CA commenting out every call to it. No officer flag was found
  either. In the model object, the 8-byte fields that split 2-4 models from the rest (offsets
  188/192) hold a value pair whose product is 1 (4 and 0.25, 1.857 and 0.538). That is per-model
  animation timing, not an officer flag.
- **A model's position is model object `+0x88`** (x, y, z float32), matched against the
  general's `position()`. Near copies sit at `+0x194` and `+0x1E0`. The model vector holds **live
  models only**: a 180-man unit read 87 after casualties.

**Built in `zz_follow_on.lua`:**
- A unit that can shoot (`missile_range() > 0` and ammo left) starts in ranged mode. Right click
  switches melee/ranged.
- In ranged mode, holding left click fires at the ground point where the camera's centre ray meets
  the ground at the unit's height. Looking down aims nearer, and level or up gives full range.
  The point is clamped to `AIM_MIN`..`missile_range()`. The unit re-aims when the point moves
  `FIRE_REAIM` (5 m), no faster than `STEER_GAP`. Releasing halts. Firing holds position: WASD is
  ignored while left click is held.
- **A regiment is played as one man:** the front-centre model, where a captain stands. The camera
  follows his `+0x88` position, and the forced swing plays on him alone, without wheeling the
  regiment. He is re-picked if he leaves the live-model vector (re-checked every 30 frames).
  **Movement and fire stay regiment orders**, because no script call moves or fires one man.
  Splitting one man off would need per-entity formation steering, found by memory, and that has
  not been attempted.
- Test hooks: `F.start_fn(unit)`, `F.stop_fn(why)`, `F.fire_fn(now)` and `F.stop_fire_fn()`.

## 9h. Artillery Manual fire mode, the crosshair, over-the-shoulder (2026-10-13, partly verified)

- **The game's "Manual fire mode" (Insert) is the artillery first-person mode.**
  - The button is `root > hud_battle > porthole_parent > button_unit_manual_fire`. The shortcut
    is `toggle_first_person_mode`, and the loc is `button_unit_manual_fire_Tooltip` and
    `button_fp_mode` "Take manual control of your artillery".
  - With the unit selected, `SimulateLClick()` on the button **entered the mode**:
    `first_person_ui` became visible and the camera moved onto the gun. Measured once.
  - The button shows only for units whose engine is in `first_person_engines`. In this army
    that was the grand cannon, the rocket battery and the sky junk. It did not show for the
    gunners, grenadiers, crossbowmen or sky lanterns.
  - `first_person_ui` is created when the mode opens and destroyed later. It is a direct child
    of root, holding `controls_text_frame`, `bl_frame` and `crosshair`.
- **Wired:** on artillery, the mode key (right click) stops the controller and selects the unit.
  A watcher then waits up to 2 s for the button, clicks it, and resumes control on the same unit
  when `first_person_ui` closes, or when the mode key or F2 is pressed. Those click the button
  again 0.25 s later, only if the mode is still on. Measured: the hand-back works. Asking to exit
  resumed control (`on = true`).
- **Open: the button then stayed hidden** for the battery, though it showed at first. This held
  with the battery selected, after changing the selection, after destroying our crosshair copy,
  and with the unit not script-controlled. Suspect: while probing, `SetVisible(true)` was called
  on the game's own `first_person_ui` after the mode had closed, which may have left the game
  half in the mode. Never touch `first_person_ui` itself.
- **CA timer bug:** a one-shot `real_callback` frees its id before it runs, so a
  `repeat_real_callback` registered inside it reuses the id and never runs. The first watcher
  failed exactly this way. See MEMORY `wh3-real-callback-one-shot-id-reuse`.
- **Crosshair (ranged mode):** our own instance,
  `root:CreateComponent("derpy_crosshair_ui", "ui/battle ui/first_person_ui")`, with every child
  but `crosshair` hidden and `crosshair` (`ui/skins/default/crosshair.png`, 32x32) moved to the
  screen centre. It is shown while in ranged mode and looking. `VisibleFromRoot` reads true;
  **not yet seen by the player.** `common.take_screenshot` never captures the UI, so it cannot
  check this: an old UI-test screenshot, `zharr_panel_01.tga`, shows no UI either.
- **Over-the-shoulder (ranged mode):** the camera sits `OTS_BACK` 3.2 m behind,
  `OTS_SIDE` 1 m right and `OTS_HEIGHT` 2 m up, all scaled by zoom. Pitch tilts the view rather
  than orbiting it. It blends in and out at `OTS_RATE` 4/s. `aim_point` now takes the real
  ground hit of the centre ray, clamped from the unit to `AIM_MIN`..range. Untested in game.
- **Every key must be configurable by MCT** (author's requirement for the packaged build). Keys
  now live in one `KEYS` table of virtual-key codes. F2 is still the game's `script_F2`
  shortcut, so making it configurable means polling a key instead.

## 9i. Spike: one man of a regiment, alone (2026-10-13)

The question was whether one man can act apart from his regiment. Measured on Cathay crossbowmen
and gunners, all 9.0 model-object offsets:

- **The movement fields.** Model snapshots taken idle and during a 30 m walk show:
  - `+0x88/+0x90` is where he is.
  - `+0xE0/+0xE8` is his velocity, about 1.5 m/s.
  - `+0x1E0/+0x1E8` is a **steering point** 4-5 m ahead of him, copied at `+0x194/+0x198`,
    `+0x368/+0x370`, `+0x4E8` and `+0x7F8`.
  - `+0x1BC` is the distance to that point, matching the computed distance at all four samples.
  - `+0x1DC` is seconds since the order.
  - Speed values sit in `+0x180..+0x23C`.
- **Writing the position teleports him.** The formation code then sets his steering point back
  to his slot, and he walks back, about 5 s for 5 m.
- **An idle man ignores his steering point:** 704 frame writes, 0 m moved. After a 0.5 m position
  nudge starts his walk, holding all three copies every frame moved him 5.6 m in 5 s while his
  neighbour stayed. When the writes stopped, he walked back to his slot.
- **Wired into the probe as `man_drive`.** A held key keeps the point 3 m ahead. With no key held,
  the point stays on his own spot, so he does not return. If a held key has not moved him 0.05 m
  in 0.5 s, he is nudged again. Simulated W for 6 s: 5.3 m, slow at first inside the ranks
  (0.5 m/s), then 1.4-1.7 m/s once clear. His neighbour moved 0.3 m and the regiment got no
  orders. He held his spot after release. `unit:position()` still shifted about 2 m.
- **Forced fire animations launch no missiles.** A forced `FIRE_LEVEL` (1557) on one man, with the
  regiment's fire-at-will off and its ammo still for 3 s, was accepted three times and ammo did
  not change. To amplify, `FIRE_LEVEL` was pushed on all 180 men with an enemy regiment pinned
  35 m ahead: the rats went 300 to 298 in 8 s, the same as the background (a sentinel in melee).
  The animation plays (the player saw the man do it), but missile launch belongs to the combat
  system. Melee is different: forced swings do hit. Slots: `FIRE_LOW/LEVEL/HIGH` are 1556-1558
  and `RELOAD_1` is 1564.
- Holding an enemy for a test: `create_unitcontroller` on an AI unit does **not** take it from
  its AI (`is_script_controlled` false; it walked past its halt). Re-issue a goto to its own spot
  plus `halt()` every 0.5 s to pin it.

## 9j. One man shoots alone: scripted projectiles (2026-10-13)

- **Melee and missiles differ.** A melee hit comes from the swing animation, so a forced swing
  damages. A missile is spawned by the man's firing state, which runs only while his unit holds
  a fire order (target, firing solution, stage); the animation alone spawns nothing (§9i).
- **The per-man firing state exists in the model object.** One crossbowman snapshotted idle, then
  while his regiment ground-fired (`zz_firestate.lua`):
  - `+0x3DC/+0x3E4` and `+0xA74/+0xA7C` hold the aim point. `+0x368/+0x370`, which held the
    steering point while walking, also take it.
  - `+0xA68..+0xA70` is his launch position, at hand height (y 1.06).
  - `+0xA80..+0xA94` are two points along the arc; the second sits 2.25 m up, between him and
    the target.
  - These go from 0 to non-zero when the order arrives: `+0x2B8`, `+0x388`, `+0x3A8`,
    `+0x550`, `+0x5C0` (257), `+0xAA4` and `+0xAAC`.
  - `+0x4C8/+0x4CC/+0x4E0` cycle with aim, fire and reload.
  - `+0x854` is the seconds since the order.
- **No per-man ammo in the first 0x1000 bytes.** No int32 or float field, summed over all 180 men,
  equals `ammo_left()`, so "zero everyone else's ammo" is not available there. Ammo is a unit pool
  or lives in another per-man object.
- **`fire_at_will(false)` blocks `attack_location` ground fire completely**, which explains the
  silent cannon in §9h. Ground fire at a bare point is slow: 2-3 bolts per 6 s from 180
  crossbowmen at 40 m, against roughly 4 a second at 80 m in the first test.
- **The gate flags do not gate.** Holding `+0x2B8`, `+0x388` or `+0xAA4` at 0 on every man but one,
  against a pinned enemy with the regiment halted and firing at will, 12 s windows: controls fired
  114 and 96 bolts, gated runs 60, 44 and 105. The engine rewrites them each tick.
- **The ammo pool is the unit's, at unit object `+0x3D90`** (`{current, max, ...}`; `ammo_left`,
  `exe+2eb9200`, reads it directly). Each man's object runs past `0x1000` (sub-objects at
  `+0xC50..+0xFB0`), so the earlier per-man scan was short. RTTI names are stripped from the exe,
  and its code section is the first one (`0x1000..0x33A2000`): the section names are scrambled.
- **The working route needs no per-man gate: `bm:trigger_projectile_launch(key, from, to)`.** It
  launches a projectile with no unit behind it. 20 crossbow bolts from 40 m killed 1 Plaguebearer
  of 200, during Deployment, and used none of the shooter's ammo. CA's shipped scripts never call
  it. The controller (`man_shoot`) plays the man's `FIRE_LEVEL`, launches `delay_ms` later from
  1.5 m above his feet to the aim point, takes one bolt off with `set_current_ammo_unary`
  (3960 -> 3959 exactly), queues `RELOAD_1`, and turns the regiment's fire-at-will off until F2.
  The projectile key and `base_reload_time` come from
  `main_units -> land_units.primary_missile_weapon -> missile_weapons.default_projectile ->
  projectiles`. The probe hand-types three types; the pack generates the table, and unlisted
  types fall back to the regiment's ground fire. The reload is a quarter of `base_reload_time`
  for now, so 3.25 s for crossbows: one man on the full 13 s plays badly.
- Not yet checked in play: whether the bolt leaves in step with the animation, and turning
  him to face the aim, since he still faces where he walks.
- Battle state matters: nothing fires in the Deployment phase (`x1_start.lua` ends it), and
  regiments brought close get routed by the player's army before a test, so pin early.

## 9k. Hiding the cursor without cinematic UI (2026-10-13, measured)

Spec §10.1, plan Task 1. Cinematic UI hides the cursor but takes CA's HUD with it, and the HUD panel (plan 2)
sits beside CA's porthole. Probe `probes/zz_cursor.lua` calls `SetCursor(NULL)` (USER32, IAT `0x33a2bc0`
on build `0x6ac6d907`) once per frame while the game window is in front. That is the whole route, and it
holds no state: when the calls stop, the game's next `WM_SETCURSOR` draws its own cursor again. So a battle
that ends, or is quit, mid-look leaves nothing to undo. `GetCursorInfo` was sampled every 6th frame.

| Run | Samples with no cursor picture | Seen |
|---|---|---|
| Cursor free, moved over the field and the HUD, 8.9 s focused | 72 of 100 | the author: "the cursor disappeared"; CA's HUD stayed (screenshot) |
| Cursor parked at the window centre each frame first, as mouse-look does, 10.0 s focused (1,982 frames) | **100 of 100** | - |

The free run's 28 misses are the game re-setting its cursor between frames while the mouse is over the HUD,
which redraws it each frame. The parked run is the case the pack has, and it never missed. The `showcursor`
route (`ShowCursor`, a stateful display count that can survive a quit into the menu) was not needed and was
not run.

**Decision: `CURSOR_ROUTE = "setcursor"`** in `platform.lua`. Focus during the probe was "the foreground
window's process is the game's" (`GetWindowThreadProcessId` against `GetCurrentProcessId`), which read false
with VS Code in front and true with the game in front, as the pack's `P.focused` now does.

## 10. Next build (requested 2026-10-13, not started)

1. Turn the live probe (`zz_follow_on.lua`) into a battle script in `script/battle/mod/`, with a
   soft memreader dependency: without `_G.memreader_plus`, the camera runs with no mouse-look.
2. **A HUD for the character in third person** (author's request). Either keep CA's HUD and hide
   only the cursor some other way (a Windows cursor call through memreader, or a blank cursor
   image; both untested), or build a custom panel (portrait, health, his abilities with
   cooldowns and hotkeys, an optional crosshair) per `docs/CUSTOM_UI.md`, rendered to a preview
   before shipping. Both can be done together.
3. Still open: the camera trails him by `DELAY` x his speed, so it drifts back on fast mounts.
   Right-clicking at the parked cursor ought to order a move to where the camera looks; untested.
4. Attacks on the mouse buttons and any-unit control: built in the probe (§9c, §9e). Swings hurt, 1.5 s cooldown.
5. Ability keys while F2 blocks player orders (`perform_special_ability`).
6. **Every key configurable through MCT** (author's requirement): fill `KEYS` from MCT and poll the toggle key instead of `script_F2`.
