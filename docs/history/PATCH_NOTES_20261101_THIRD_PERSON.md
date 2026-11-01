# Third-Person Battles: Workshop update, 2026-11-01

Item 3822187184. Build saved 2026-11-01 08:40 to `Modding Files/Modpacks/derpy_third_person.pack`: `89091119`, 4,609,241
bytes. The build before it (`03c3a381`, the 10-31 build, deployed and never uploaded) is in
`Modding Files/Backup/third_person_20261101/`, with the sources this round edited.

**Deployed, not uploaded.** Copied into the Workshop folder 2026-11-01 08:48, after the game closed: `89091119`. No
`loadfast_cache_*.bin` exists, and `data/` has no copy of the pack. The game had been started at 08:37, while this was
building. The new pack went into the Workshop folder at about 08:40 by mistake and was put back to `03c3a381` within a
minute, once the running game was noticed. A Steam validation (any upload) re-downloads the published `2ec7e798` over it;
check the md5 after one.

**Rebuilt 2026-11-01 10:02: `441a78a2`**, 4,609,303 bytes, deployed 10:03 after the game closed (no loadfast cache, no `data/` copy), not
uploaded. Against `89091119` only the MCT settings file changed: its labels and tooltips say "entity" where they said
"man" or "he" (the author, 2026-11-01): "Play one entity of a regiment", "A health bar over every entity", "Reload time
(one entity)". The option keys are unchanged, so saved settings carry over. DB rows byte-identical past RPFM's GUID.
`89091119` is backed up as `Modding Files/Backup/derpy_third_person_20261101_100223.pack`. Harness 694 + 47, 43/43 cave
mutants.

**Uploaded 2026-11-01 23:17 Manila: `441a78a2`**, after the live check below. Through the steamworks binding (`updateItem`,
contentPath = the Workshop folder, changeNote only), with the script, manifest and a copy of the pack in
`Modding Files/Backup/pre_upload_20261101_third_person/`. Result `{"itemId":"3822187184","needsToAcceptAgreement":false}`.
Steam's log reads `Uploaded new content ( ManifestID 6262936272307300740 )` and `Upload finished ... : OK`.
`GetPublishedFileDetails` gives file_size 5,578,288, which is the pack plus the preview exactly, and time_updated
23:17:21. The change note is the block at the end of this file as written. Audit 015's rewrites were not applied. All
32 derpy Workshop folders matched their published sizes afterwards, so Steam's validation has no local deploy to revert.

Covers the open list checked on 2026-11-01 (`WORKSHOP_REPORTS_20261031_THIRD_PERSON.md`, "Fixed 2026-11-01"), and fire on
the move, asked for by the author the same day.

Pack against `03c3a381`: five scripts changed (`abilities.lua`, `combat.lua`, `data.lua`, `main.lua`, `move.lua`) and the
loc (one row added, 92). The DB tables differ only in RPFM's header GUID; their rows are byte-identical.

## What changed

- **Fire on the move.** For units with CA's fire whilst moving (the `mounted_fire_move` attribute): 348 of 870 missile
  units, read off `db.pack` and the installed mods.
  - One man of a regiment walks on while the shot's clip plays. The clip is MOVING_FIRE_FORWARD, LEFT, RIGHT or
    BACKWARD_LEVEL on foot, and the rider's FIRE_FORWARD, LEFT, RIGHT or BACK_LEVEL from the saddle, picked by where the aim
    is from where he walks. There is no raise to aim, and the reload runs on the clock without its clip. The spawn
    times and muzzles come from each clip's own FIRE_POS (`data.lua fires_moving`, 293 units).
  - A regiment played whole, or a unit of one, walks on with fire at will on while the button is held. The game picks
    the targets in range, not the crosshair. Standing, a click is the order it always was.
  - 58 units have a MOVING_FIRE slot without the attribute. Some of them have only the standing fire clip under that slot,
    so the attribute is the gate, not the slot.
- **Blows in the air and from the saddle.** Their landing point is now read off FLY_ATTACK, RIDER_ATTACK and
  RIDER_FLY_ATTACK clips (`impacts_fly`, `impacts_rider`, `impacts_rider_fly`: 580, 711 and 15 units). They used to land
  2.5 m ahead whatever the clip.
- **Locked on, the blow goes to the locked enemy** when one of his men is in its reach. Otherwise it goes to whoever is
  nearest where it lands, as before. Single player, one man or a unit of one, as the strike itself is.
- **Artillery.** A click with no enemy in the gun's range ahead now says "No enemy in range ahead to fire at."
  (`derpy_tp_no_target`).
- **Modded transformations.** Some abilities are not in `data.lua`, being from a mod installed after it was generated. If
  such an ability brings a unit (CA's `SpawnedUnitLandRecordContext`) and aims at nothing, it now goes off the way a
  transformation does: third person stops, and starts again on the new unit. If the caster is still there a second
  after the new unit came, it was a summon, and he is played on.

Not done: number labels on the command-mode cards (a UI addition that needs its own design pass), wall climbing (the author:
not for now). The rest of the open list needs the game: melee for a regiment played whole and in multiplayer, the
flamethrower's visual, You're Next refused by the engine, the Shift drift in melee, the F2 crash on a swapped unit (needs
the mod), co-op gifted units.

## Checks

- 694 + 47 harness tests pass, 11 of them new.
- 23 of 23 mutants against the new tests are caught (`mutate_20261101.py` in the session scratchpad, not kept), along with
  the 43 cave mutants.
- `check_data` pins the new tables: Be'lakor's FLY_ATTACK_1 4 m ahead, the Pegasus Knights' rider-fly points, Horse
  Archers in and Jade crossbowmen out of `fire_moves`, and the Skink Skirmishers' and Horse Archers' clip spawns.
- `data.lua` was regenerated against the installed mods. Every older table is byte-identical except `abilities`: a Mixu
  update since 10-29 changed four of its Daith items.

## Live check, 2026-11-01 22:50-23:15 (both builds' lines)

The Workshop copy, `441a78a2`, was run under the minimal list: the intro skip, the bridge, both memreaders, MCT and
the pack. Single player was a campaign battle from the `derpy_vfx_min_ie_t1` fixture. Astragoth was given Kislev Horse
Archers, Skink Skirmishers, Empire Knights and a Great Cannon, then attacked Slaves of Zharr. Keys came from a Lua stub
(`P.held`, `P.focused` and the look calls), the real keyboard and mouse were never used, and the enemy was held by a
controller. The driver is `tpv.lua` in the session scratchpad and was not kept. Afterwards the game was quit, the
preferences reverted and the list deleted.

| Line | Result |
|---|---|
| MCT wording | **Seen.** MCT's own `get_text` / `get_tooltip_text` read "Play one entity of a regiment", "A health bar over every entity", "Reload time (one entity)" |
| Fire on the move, one man | **Seen.** Horse Archers: W and fire held, `2105` (RIDER_FIRE_FORWARD) played, the arrow launched 2.4 s later, ammo spent, 51 m ridden in the 6 s. Skinks: `1570` (MOVING_FIRE_FORWARD), a dart launched, 26 m walked. How the clip looks over the legs was not judged (no picture) |
| Fire on the move, whole regiment | **Seen.** Horse Archers, `one_man` forced off: "fire on the move", 45 m run across the enemy's front, ammo 843 -> 832 -> 821 while moving |
| Locked target first | **Seen.** Chaos Dwarf Warriors between Goblin Archers and Orc Boyz, locked on the goblins: the nearest man to the landing point was an Orc Boy 0.6 m off, and the blow struck the goblin 1.4 m off. With the nearest goblin 3.7 m away (out of reach) it fell back to the Orc Boy, as designed |
| Saddle blows | **Not exercised.** Empire Knights' horses have ATTACK clips of their own, so the horse carries the swing (`454`-`456`) and its blow point is the `impacts` table that existed before 11-01. Three of four blows landed (knocked 11, blocked 17, hit 14). `impacts_rider` is read only for a model with RIDER_ATTACK and no mount pointer, and no unit of that kind was tried |
| Air blows | not tested (no flyer attacking in the air) |
| Artillery message | **Seen.** Great Cannon aimed away: "No enemy in range ahead to fire at." on screen (the subtitle read back). Aimed at the enemy: an attack order on the Orc Boyz, no message |
| Morale row | **Seen.** "67%" for 0.667 and "62%" for 0.621, the fill in proportion (123 and 114 of 190 px), the red hidden at states 2 and 3. No played unit reached state 4, so the red and "Shaken" were not seen |
| Kill count | **Seen.** 0 for 0 on the knights, 40 for 40 on the warriors |
| A bar over each man | **Seen.** 129 bars over two enemy regiments, 0.86 px from CA's `WorldSpaceToScreenSpace` on average and 2.24 px at worst, so the calibration runs. Colour by side not checked (the screenshot has no UI layer) |
| Camera on hills | **Seen.** Walked 11 m up a slope with 19.9 m of relief under the eye, then turned at about 107 deg/s: worst one-frame move 1.49 m, on a 66 ms hitch frame; the eye at least 3.5 m over the ground. One earlier run, not yet logging the followed point, had one 5.5 m move in a 4 ms frame. It was not seen again in two logged runs, and its cause is unknown |
| Multiplayer clicking | **Seen** in a solo multiplayer battle (lobby with an AI). The selection cleared every 50 ms: 0 card clicks in 5 s while looking around, 10 in 5 s with the view freed, 499-506 ms apart |
| Multiplayer refusal | **Seen.** `P.net_me.watching` set: start refused, and the line shows on screen |
| Modded transformation | not tested (needs the modded ability) |

**Solo multiplayer refuses third person by design.** The handshake will not start with a list of one player ("it names 1
player"), and the player sees `derpy_tp_mp_no_players`. The two multiplayer lines were tested after completing it by
hand: `P.gate(true)`, `P.net_me = {me = true, watching = false, ...}`, `P.net_play = true`. Nothing was desynced, because
no second machine was there.

**Probe trap.** Setting `E.rig.want_yaw` to a fresh `atan2` while `E.rig.yaw` has wound up past 1,000 degrees makes the
rig spin back through the full turns: 33 m of eye movement a frame, decaying. That came from the probe, not the pack.

## Change note (both builds: 10-31 and 11-01)

```
[list]
[*] New: your unit's morale on the panel, the bar turns red when it starts to break
[*] New: your unit's kill count on the panel
[*] New: small health bars over each entity of nearby regiments (MCT option, on by default)
[*] New: shoot on the move with units that can in the base game, such as horse archers and skirmishers
[*] Blows from the air and from the saddle should land where the swing lands
[*] Locked on, your blows should land on the locked enemy
[*] Artillery: a message says when no enemy is in range
[*] Modded abilities that turn your unit into another should keep you in third person as the new form
[*] The camera should no longer snap when you turn on hills
[*] Multiplayer: the unit card should no longer click every frame while you play
[*] Multiplayer: a message now says why third person cannot start when you have no army of your own
[*] MCT: options now say entity instead of man
[/list]
```
