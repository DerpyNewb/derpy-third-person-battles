# Third-Person Battles: entity switching, 2026-11-02

Item 3822187184. Build saved 2026-11-02 08:41 to `Modding Files/Modpacks/derpy_third_person.pack`: `4d51f65b`, 4,612,138
bytes. The build before it (`441a78a2`, the 11-01 upload) is in `Modding Files/Backup/third_person_entity_switch_20261102/`
and `Modding Files/Backup/derpy_third_person_20261102_084133.pack`.

**Deployed 08:49, not uploaded.** The game was running when the build finished. It had been started at 08:02, after the
last live test, so it was the author's session. A background job copied the pack into the Workshop folder once the game
closed, with the game check and the copy in one command; the Workshop folder's md5 is now `4d51f65b`. No
`loadfast_cache_*.bin` exists, and `data/` has no copy of the pack. The two packs carry the same 43 files. A Steam
validation (any upload) re-downloads the published `441a78a2` over it, so check the md5 after one.

Asked for by the author on 2026-11-02: "implement entity switching on a regiment using available keys".

## What changed

- **Entity switching.** With one entity of a regiment played (F2, "Play one entity of a regiment" on), C plays the entity
  to his right and X the one to his left, right and left of the camera's view.
  - It picks the nearest entity that way. A step forward or back counts as two steps aside, so his own rank comes first
    (`move.lua` `M.beside`, `SIDE_DEPTH`).
  - When nobody is further that way, it picks the far end of the regiment, so the keys go round it. Dead entities are
    passed over.
  - The one let go is handled as at the end of third person: held where he stands, his own swings given back
    (`P.arm`), and his regiment orders him again. A shot under way is dropped and its reload still counts, so switching
    cannot skip a reload.
  - What the new entity can do is read again (jump, charge, cheer, solo fire, reload clip). This is the same code the
    death take-over runs, now one function, `take()` in `main.lua`.
  - The keys do nothing in command mode, while paused, for a unit played whole or for a unit of one.
- **Keys.** `man_left` = X and `man_right` = C, on the MCT page through `K.order`. They are last in the list, so a
  player who already gave X or C to another action keeps it, and the switch key goes unbound.
  - X and C were free of the mod's own keys. The game binds bare X to `cam_up` and bare C to `rot_d` (camera raise and
    tilt, `default_keys.xml` read 2026-11-02), and both are now off while third person is on (`K.game`).
  - With Alt as the guide key, Alt+X (`toggle_sfx`) is off too, through the existing `K.game_alt` rule.

## Checks

- Harness 702 + 47 lockstep, 43/43 cave mutants, `check_lua_api` and `check_lua_literal_left` clean (`--selftest`).
- Eight new tests: both keys and the hold and arm records; the view's frame; own rank first; going round and passing the
  dead; command mode and a unit of one; the reload kept; the X and C shortcuts; the key conflict. One old assertion
  changed: Alt+X is now off, because X is one of the mod's keys.
- 11 hand mutants, all caught (no hold, no arm, no drop, each key reversed, rank weight 0, no wrap, dead men picked, the
  regiment's frame instead of the view's, the game shortcuts left on, the switch keys first in the list). Script in the
  session scratchpad, not kept.
- **Not seen in game.**

## Second build: translations, card numbers, regiment attacks

Build saved 2026-11-02 10:45: `762cb4b3`, verified from the saved pack (28 files, 119 loc rows, 11 stat tables), the same
43 files as `4d51f65b`. `4d51f65b` is backed up as `Modding Files/Backup/derpy_third_person_20261102_104519.pack`. **Deployed
10:54, not uploaded:** the game was running again, and the same gated background job copied it in once the game closed.
The Workshop folder's md5 is `762cb4b3`, no `loadfast_cache_*.bin` exists, and `data/` has no copy.

Asked for by the author on 2026-11-02, after the open-report list: "do the request by [a translator] for easier translation, do the
number label on units when in command mode, regiment mode only lets attack for the one entity you are controlling, not
the whole regiment attacking, it should use vanilla attacking targetting, same as shooting use vanilla shoot the
regiment". The third part was read as the list's open item "no melee damage for a regiment played whole": the click
played the pack's attack clips on every man, which deal no damage, while the regiment's volley already used CA's attack
order. Not the opposite reading, one entity's click ordering his whole regiment: that would break the 2026-10-15 rule
that one entity gives his regiment no orders.

- **The HUD's words are loc rows** (the translator's request, 2026-11-01). 26 strings that were plain text in the Lua:
  - the bar's page names: Abilities, Spells, Army abilities;
  - "Back to third person", Hidden, Unspottable, Crumbling;
  - command mode's group names (Infantry, Ranged, Cavalry, Monsters, Artillery, Heroes, All), "none" and "Pick units: 1
    to 6, 0 for all";
  - the two overcast refusals;
  - the armed ability's target lines ("On himself", "Click to cast", "Ground, %s m", "No ground in sight", "No ally in
    sight", "Out of range", "No lord or hero in sight", "No enemy in sight"). These were not in the request but are the same kind of text.
  - How it works: each goes through `E.loc("derpy_tp_ui_...", "English")` (`derpy_third_person.lua`), which reads the
    loc row and falls back to the English. `build_third_person.py` reads every such call, writes the English into
    `text/db/derpy_third_person.loc`, and refuses a call whose key or text is not a literal, or one key with two texts.
  - A translation pack overrides the `derpy_tp_ui_*` keys, as it already does the `derpy_tp_*` messages. Key names
    (Left mouse, Space) stay plain, as do the MCT page's.
- **Number keys on CA's unit cards** in command mode's Vanilla style. Each card of the page shows the key that selects it
  (`cmd_unit_1`-`10`, the number row by default), on the slots' key lozenge (`number_frame_lozenge_18px`, body_12 cream),
  centred on the card's top edge and half over it. **Moved in the third build** (below): the live check found the
  lozenges covering CA's status icons and health bar.
  - The top edge was chosen because CA's card was read as keeping its category icon top-left and its health bar along
    its foot (`land_unit_card.twui.xml`, read 2026-11-02). That reading was wrong: in game the health bar is along the
    top and the category badge at the foot. No CA card has a number slot.
  - The lozenges are 10 parts of `hud.twui.xml` (`card_N_keyplate` / `card_N_key`). `H.cards` moves them onto the cards,
    and `H.place` leaves them alone. They are re-read every 0.2 s and at once on the page key.
  - His own card has none. A dead unit's card keeps its number, as its key does. A longer key name widens the lozenge.
  - None in the Bannerlord style, which hides CA's cards. They are hidden when the mode ends.
- **A regiment played whole attacks by CA's own order.** The click, either button, is `attack_unit` on the enemy unit
  under the crosshair, else the one nearest the aim (`pick_target`, 150 m, 45 deg or 8 m any way), as its volley does.
  - No range gate: out of reach the regiment walks in. A click on the unit it is already attacking sends nothing, which
    would restart the charge. A move key lets the attack go, and the next click orders again.
  - No enemy ahead: no order, and the message "No enemy ahead to attack." (`derpy_tp_no_enemy`, a new loc row, 93 now).
  - Unchanged: one entity of a regiment and a unit of one still swing their own clips, and the regiment gets no order.
    The jump, the charge attack and the cheer of a regiment played whole still play the pack's clips on its men, with
    the turn order before them. Shooting was already CA's order.

**Checks.**

- Harness 708 + 47, 43/43 cave mutants, `check_lua_api` and `check_lua_literal_left` clean, the HUD layout validated
  (`preview_third_person_hud.py --check`, `gen_third_person_hud.py --selftest`).
- Six new tests: the loc row over the English; the card numbers placed, moved with their card, hidden on leaving and in
  the Bannerlord style; a long key widening its lozenge; the regiment's order, not sent twice, re-sent after a walk; no
  enemy ahead; one entity still swinging alone. One old test gained a check: the attack order just after a halt is not
  dropped.
- Four old tests changed with the behaviour. Two whole-regiment turn tests now use the jump. The flying-mount test now
  plays a rider alone. The multiplayer-strike test now expects the order, with no clip and no blow.
- 13 hand mutants caught, and the loc check proven against a non-literal key and a key with two texts.
- Added after the deploy, test-only (the pack is unchanged): two lockstep tests, 49 now.
  - `ls_switching_entities_stays_in_step`: C and X hand the guard, ARM and DISARM over by id through the queue, B
    decides nothing, no divergence.
  - `ls_a_regiment_played_whole_attacks_alike_on_both`: the click's `attack_unit` runs once on each machine, on the same
    regiment and enemy, with no clip.
  - Three mutants caught: no ARM on a switch, no unguard on a change of body, no order.
  - Also checked against CA's docs and scripts: a card's name is the unit's `unique_ui_id` (`battle_main.lua:349`), and
    `attack_unit`'s argument order (target, primary, move fast). `check_lua_undeclared` is clean over the 17 files.
  - Neither `hud_battle` nor `derpy_tp_hud` sets a priority, and ours is created later under root, so the lozenges
    should draw over the cards. Still not seen in game.
- **Not seen in game:** where the lozenges land on CA's real cards (a card's box is not always its art), and whether
  CA's order makes a whole regiment's charge feel right under the camera.

## Live check, 2026-11-02 14:00-14:20, and the third build

`762cb4b3` from the Workshop folder, under the minimal list: the intro skip, the bridge, both memreaders, MCT and the
pack. A campaign battle from the `derpy_vfx_min_ie_t1` fixture: Astragoth against the Slaves of Zharr, the enemy held by a
controller. Keys came from the Lua stub of 11-01 (`tpv.lua`, plus `tpv2.lua` for this check, both in the session
scratchpad and not kept). The real keyboard and mouse were never used. Afterwards the game was quit, the preferences
reverted and the list deleted.

| Line | Result |
|---|---|
| Entity switching | **Seen.** Chaos Dwarf Warriors (great weapons), 100 entities. C went from entity 2 to 1, X back to 2, X again to 4, each 1.5 m from the last, logged "switched right/left". Right and left of the view, measured with CA's `WorldSpaceToScreenSpace`: after C the one let go sat at screen x 615 of 1600 (left of the played one at 800), after X at 972. The new one walked 5.2 m in 2.5 s and the one let go stayed (0.04 m) |
| X and C shortcuts | **Seen** in the disabled list at the start: `cam_up`, `rot_d`, and `toggle_sfx` (Alt+X, Alt as the guide key) |
| HUD words as loc rows | **Seen.** `get_localised_string` reads "Spells", "none" and "No enemy ahead to attack." out of the shipped pack. The subtitle showed the localised line (script log) |
| Regiment played whole: no enemy | **Seen.** Facing away, the click said `derpy_tp_no_enemy` and sent no order and no clip |
| Regiment played whole: attack | **Seen.** Facing the Orc Boyz 100 m off: "attack order on wh_main_grn_inf_orc_boyz", `F.attack_on` 1011, no clip. The regiment walked in and fought: 15 kills, the Boyz 120 -> 105. It then routed (100 -> 57) after about 30 s alone among the army, under two units of goblin archers, which reads as the game's morale, not the pack |
| Card numbers | **Placed, and in the wrong spot.** Lozenges 1-7 on cards 1002-1008, centred, his own card (1001) none, 8-10 hidden, all hidden on leaving. The page key turns nothing with 7 cards, as designed (over 10 only). The card's own tree showed CA's status icons (braced, shaken) in a row just above the card (y -18 to 0) and the health bar along its top (y 3-17), so a lozenge at y -9 to +9 covered both |

**Third build: the card numbers moved.** Each lozenge now sits in the card's top-right corner, level with CA's rank
badge in the top-left (badge y 21-45 of 130, the lozenge centred on y 33, 1 px in from the right edge; `hud.lua`
`CARD_*`). That corner holds nothing else above y 50. A wider key name grows it to the left and never off the card,
since the cards touch.

- The two card tests now assert the corner and the clamp: a name wider than the card sits on its left edge. Three
  mutants caught (the old centred spot, no clamp, the top edge).
- Selftest: harness 708 + 49 lockstep, 43/43 cave mutants.
- Build saved 2026-11-02 14:28: `0595ecdc`, 4,640,867 bytes, verified (28 files, 119 loc rows, 11 stat tables), the same
  43 files. `762cb4b3` is backed up as `Modding Files/Backup/derpy_third_person_20261102_142850.pack`.
- **Deployed 14:29.** The Workshop folder's md5 is `0595ecdc`, no `loadfast_cache_*.bin` exists, and `data/` has no
  copy.
- **Not seen in game:** the new corner. The tree read gives the geometry, but a screenshot has no UI layer, so how it
  reads over the portrait art is for the next look.

## Upload, 2026-11-02 14:55 Manila

**Uploaded `0595ecdc`**, carrying all three builds of the day. It went through the steamworks binding (`updateItem`,
contentPath = the Workshop folder, changeNote only), with the script, manifest and a copy of the pack in
`Modding Files/Backup/pre_upload_20261102_third_person/`. Result `{"itemId":"3822187184","needsToAcceptAgreement":false}`.
Steam's log reads `Uploaded new content ( ManifestID 6519745943830383711 )` and `Upload finished ... : OK` at 14:55:50.
`GetPublishedFileDetails` gives file_size 5,609,852 (the pack plus the preview exactly) and time_updated 14:55:50.

- Before the upload all 33 derpy Workshop folders were checked against their published sizes (`check_published.cjs`).
  Only this one differed, so the validation that follows an upload had no other local deploy to revert. Afterwards
  all 33 matched.
- The change note below was revised under antislop (DURING, the author's choice) before the upload:
  - "should" dropped from the regiment line, now seen in game;
  - "HUD" and "translated by translation packs" reworded;
  - the no-enemy line limited to a whole regiment, the only case that shows it;
  - both regiment lines prefixed "Playing a whole regiment:", as "Artillery:" was on 11-01.

## Change note

```
[list]
[*] New: switch which entity of your regiment you play with X (left) and C (right), keys in MCT
[*] New: in command mode (Vanilla style), each unit card shows the number key that selects it
[*] New: translation packs can now translate the mod's on-screen text
[*] Playing a whole regiment: it now deals melee damage, using the game's own attack order
[*] Playing a whole regiment: attacking with no enemy ahead now shows a message
[*] The game's X and C camera shortcuts are off while you play in third person
[/list]
```
