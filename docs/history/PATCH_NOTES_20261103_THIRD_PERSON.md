# Third-Person Battles: game patch 9.0.5, 2026-11-03

Item 3822187184. Patch 9.0.5 replaced `Warhammer3.exe` at 19:06 Manila: PE stamp `6acec6f4` -> `6ae2a00b`, Steam
build 26403568. With no BUILDS row for the new stamp, the pack plays every regiment whole.

Build saved 2026-11-03 20:56 to `Modding Files/Modpacks/derpy_third_person.pack`: `45a97df2`, 4,642,061 bytes, verified
from the saved pack (28 files, 119 loc rows, 11 stat tables), the same 43 files as the Workshop copy. The first build
of the day, `ed6580bc` (20:14), lacked the multiplayer gate fix below and was never deployed. The build before both
(`0595ecdc`, the 11-02 upload) is `Modding Files/Backup/derpy_third_person_20261103_200606.pack`.

**Deployed 21:02, uploaded 21:17.** It went through the steamworks binding (`updateItem`, contentPath = the Workshop
folder, change note only). The script, manifest and a copy of the pack are in
`Modding Files/Backup/pre_upload_20261103_third_person/`.
- Steam's log reads `Uploaded new content ( ManifestID 3181060629449301078 )` and `Upload finished ... : OK` at 21:17:02.
- `GetPublishedFileDetails` gives file_size 5,611,046 (the pack plus the preview exactly) and time_updated 21:17:04.
- Before the upload, only this item's folder differed from its published size, out of 34 derpy Workshop folders.
  Afterwards all 34 matched, and the folder still holds `45a97df2`.
- The artillery-walls session's game was running during the upload (launched 21:16, `used_mods_artwalls.txt`). Its
  list does not load this pack, so the upload went ahead.
- The newest note on Steam before this one was 11-02's, so nothing below had been told to players.
- The title was left as it was: it still says "( Vanilla 9.0.4 )".

## What changed

- **`platform.lua`: a BUILDS row for `6ae2a00b`**, all 32 fields. The struct offsets in it (`battle_sub` 0x468,
  `gate_a` 0x3b0, `gate_b` 0x3b1, `queue` 0x644e8) are unchanged. `reload_hook` and `reload_resume` are no longer
  float32-exact, so they are written as `{high, low}` pairs, the way `g_reload` already was. The `6acec6f4` row stays.

  | Field | 6acec6f4 | 6ae2a00b | Found by |
  |---|---|---|---|
  | cmd_type, battle, cmd_push | 39077e8, 4480da0, 2e9b974 | 39131c0, 448f208, 2ea2be8 | the byte pattern (`third_person_patterns.py`), and the migration below |
  | walk_a, walk_b | 3919350, 3ae2400 | 39242f8, 3aed8c8 | migrated xrefs; `tp_find_walk_rvas.py` agrees |
  | walk_start, walk_speed, walk_stop | 306f954, 303b744, 306edd4 | 3076e90, 3042b48, 3076310 | signatures; the finder agrees; still `walk_start - 0xb80` |
  | move_a, move_b, melee | 39199f8, 3ae1928, 3ad24b8 | 3925368, 3aecc28, 3ade470 | migrated xrefs |
  | queued_gate, update | 3087378, 3086f04 | 308e8bc, 308e448 | signatures; the gate byte at +0x11 is still `5c` |
  | cam_collide, cam_terrain | 2ee841c, 2ec2710 | 2eef574, 2ec9938 | signatures |
  | g_move, g_halt, g_reload | 406c798, 406cea8, 406cda4 | 4078338, 4078a48, 4078944 | migrated xrefs |
  | rec_header, rec_field, rec_length, registry | 1bca278, 1bb1924, 1bcd5e4, 668ad4 | 1bd09b0, 1bb80a0, 1bd3c84, 6665a0 | signatures |
  | follow_vt, follow_push | 3ab25a8, 2d919dc | 3abc200, 2d98aac | migrated xref; signature |
  | reload_hook, reload_resume | 2ecfcb7, 2ecfcbd | 2ed6e57, 2ed6e5d | signatures; still 6 apart, `skip` = resume + 8 = 2ed6e65 |
  | map_lookup, roll | 17aece4, 30a8ab0 | 17b49f0, 30b008c | signatures |

- **Multiplayer gate.** `platform.lua`'s multiplayer route was gated on a literal `P.build == "6acec6f4"`, so on 9.0.5
  multiplayer stayed off even with the new row (the artillery-walls session spotted the literal first). The gate is
  now `row and row.g_move`: any build whose row carries the queued-command fields. `M.BUILDS` is exported for the
  tests. New test `platform_net_route_follows_the_row_not_the_stamp` stands the 6acec6f4 row in under the 6ae2a00b
  stamp: net mode comes up, and with `g_move` dropped it is refused and says why. Two mutants are caught: the literal
  stamp back, and the field test removed.
- **`tools/third_person_cave.py`**: `SITE_RVA` 0x308e448, `CARRIER_RVA`/`RESUME_RVA`/`SKIP_RVA` 0x2ed6e57/0x2ed6e5d/
  0x2ed6e65, `ROLL_RVA` 0x30b008c. These feed `--check` only. The cave bytes are not tied to a build, and the site
  bytes are unchanged. The emulator's `VT` dict still has 6acec6f4 values, which is harmless because they are fake
  addresses inside the emulator.
- **`probes/tp_find_walk_rvas.py`**: ANCHORS set to 6ae2a00b. From 6acec6f4's anchors it found nothing ("walk_a/walk_b:
  0 candidates"). From the new anchors it prints the five walk fields above.
- **`data.lua` regenerated** from 9.0.5's `db.pack`. 22 lines differ, all of them CA's changes:
  - Stormfiend Windlaunchers (`shots`): base reload time 13 -> 14 s.
  - Stormfiend Ratling Cannons and their RoR (`speeds`): muzzle velocity 120 -> 100 m/s.
  - `wh3_dlc29_vmp_cha_necromancer_undeath_barded_nightmare` is now `..._undeath_nightmare` in `runs`, `charges`,
    `dulls`, `impacts`, `impacts_rider` and `bodies`.

## How the fields were found

No copy of the old exe was kept. The Ghidra project `ghidra_cache/wh3_6acec6f4`, imported before the patch, holds its
bytes. They were dumped by a headless script and laid back into a PE file in the session scratchpad. Each field was
then carried to the new exe in one of two ways:

- **Code:** the old instructions from the field's RVA, with RIP-relative displacements and rel32 branch targets masked,
  searched in the new code section until one match remains. A function with identical template twins (`cmd_push`) is
  found through its callers instead, with its bytes checked at the result.
- **Data and vtables:** each old instruction that references the field is migrated as code, its new operand is read,
  and the sites vote. A vote is unanimous in every case.

The other session working on artillery walls built the same idea as `tools/exe_migrate.py`, with its own snapshot
`Modding Files/Backup/exe_snapshots/image_6acec6f4.bin` (`tools/ghidra/DumpImage.java`). Use those for the next patch.

## Checks

- **Control:** the three pattern fields came out of the migration equal to the pattern tool's values.
- **Whole functions byte-identical** apart from RIP-relative operands: cmd_push, walk_start, walk_speed, walk_stop,
  update (2120 B, which holds queued_gate), cam_collide, rec_header, registry, follow_push, the reload site's function,
  roll (811 B), and the slot functions of walk_a, walk_b, move_a, move_b, melee and follow_vt slot 0. Every struct
  displacement inside them is therefore unchanged.
  - The leaf functions (cam_terrain, rec_field, rec_length, map_lookup) have no `.pdata`. Each matched one unique
    17-34 B signature only.
  - `cmd_type`'s slot 0 differs only in an image-relative table address (0x36ccb18 -> 0x36d3b18).
- **follow_vt:** in each exe it is the one vtable slot that points at its slot-0 function. The slots after it differ
  between builds. On the old build, slot 1 is the deleting destructor of a 0x1f4200-byte object, so it belongs to a
  neighbouring class and not to the 0x90-byte command, which the engine calls through slot 0 only.
- **Selftest:** harness 709 + 49 lockstep, 43/43 cave mutants, `third_person_cave.py --check` and
  `third_person_patterns.py` ok on 6ae2a00b. `check_lua_api` and `check_lua_literal_left` are clean over the 17 files.

## Live check, 2026-11-03 21:03-21:40

`45a97df2` from the Workshop folder, under the minimal list: the intro skip, the bridge, both memreaders, MCT and the
pack. Test settings were on. A campaign battle from the `derpy_vfx_min_ie_t1` fixture: Astragoth (8 units) against a
Slaves of Zharr army (7 units). The player shield was loaded, and the enemy was held still and immune
(`artwalls_static.lua`). Keys came from a Lua stub (`P.held`, `P.focused` and the look calls, `tpv905.lua` in the
session scratchpad, not kept). The game stayed in the background, and the real keyboard and mouse were never used.
Afterwards the game was quit without saving, the preferences were reverted and the list deleted.

| Line | Result |
|---|---|
| Build | **Seen.** `P.build` 6ae2a00b, "known build", no problems |
| Battle object, gate bytes, queue | **Seen.** `P.check_anim()` true |
| Model lists | **Seen.** `P.check_men()` true on all 8 units: Astragoth (1), Warriors (100), Orc and Goblin Labourers (140, 180, 180), Blunderbusses (80, 80), Bull Centaurs (16). Model count = men alive, every model type in the exe, the men around their centre |
| Features at start | **Seen.** anim, input, mailbox, men, steer, strike, wheel all true; `F.gated` and `F.floored` true (the gate byte and the camera floor patched); no `E.once` failure line in the log |
| One entity walks | **Seen.** Warriors: 6.4 m in 3 s, 1.2 m per half second. Measured again: he 6.2 m, the other 99 men 0 m (median and max) |
| Entity switching | **Seen.** C played another man, back in the regiment |
| Melee blow | **Seen.** Four swings at an immune Orc Boyz unit, 3.3 m then 1.3 m off: ATTACK_2 and ATTACK_3 played, and `P.struck()` 0 -> 2, the roll cave arming at the new `roll` |
| One entity shot | **Seen.** Blunderbusses: raise 1554, hold 1548, fire 1557, launch of `wh3_chd_blunderbuss_bullet`, reload clip 1564 for 11.0 s (410.8 -> 421.8 in the script log). A tap during the reload fired nothing |
| Unit of one | **Seen.** Astragoth: single steering, 10.5 m in 3 s |
| Errors | none. `E.strikes` 0; the bridge's error log holds only CA's Isabella intervention line from the campaign load |

- **Not seen:** multiplayer (it needs a second machine), a whole regiment's attack order, the camera on a slope, and
  the Windlauncher, Ratling Cannon and Necromancer rows of `data.lua`.
- **Probe note:** the Blunderbuss regiment's ammo count is no measure of the played entity's shot. Its other men fire
  at will at an enemy in range, about 80 rounds a volley. The pack's own log lines (`E.S.debug`) separate them.

## Change note

```
[list]
[*] Works with game patch 9.0.5 (since the patch it could only play whole regiments)
[*] Multiplayer no longer switches itself off on 9.0.5
[*] Stormfiend Windlaunchers and Ratling Cannons: reload and shot speed follow patch 9.0.5
[*] Necromancer on Nightmare: the mod knows its new name from patch 9.0.5
[/list]
```

The Workshop title still says "( Vanilla 9.0.4 )".
