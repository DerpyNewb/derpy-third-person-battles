# Third-Person Battles: frame rate, the cursor line, a rider's blocks, 2026-11-07

Item 3822187184. From the Workshop reports of 11-03 to 11-07 (`WORKSHOP_REPORTS_20261107_THIRD_PERSON.md`, which names
commenters and stays out of the public repo). The game is unchanged since 9.0.5 (`6ae2a00b`). memreader Plus is 0.15.2.

Build saved 2026-11-07 23:46 to `Modding Files/Modpacks/derpy_third_person.pack`: `a2ded00a`, 4,645,525 bytes,
verified from the saved pack (28 files, 121 loc rows, 11 stat tables). Against the published `45a97df2`: the same 43
files. Four Lua files and the loc changed. The 11 DB tables differ only in the GUID RPFM writes into a new table's
header. The build before it is `Modding Files/Backup/derpy_third_person_20261107_234644.pack`.

**Deployed 23:52, uploaded 23:53**, at the author's request ("push the update with patchnotes"), with no live check. It
went through the steamworks binding (`updateItem`, contentPath = the Workshop folder, change note only). The scripts,
manifest and a copy of the pack are in `Modding Files/Backup/pre_upload_20261107_third_person/`.
- Steam's log reads `Uploaded new content ( ManifestID 6088154110788324478 )` and `Upload finished ... : OK` at 23:53:13.
- `GetPublishedFileDetails` gives file_size 5,614,510 (the pack plus the preview exactly) and time_updated 23:53:18. The
  changelog page shows the note as "Update: 7 Nov @ 7:53am" (Pacific). The folder still holds `a2ded00a`.
- No battle loadfast cache was on disk to delete.
- Before the upload two folders differed from their published size:
  - this one;
  - Resource Overhaul (3833299348), deployed locally at 23:45:56 by another session and not uploaded. Its exact file,
    `a4a2fa24`, is backed up as `ro_local_deploy_before_upload.pack` in the same folder. It was still `a4a2fa24` right
    after the upload. Steam's validation can come later (21 minutes after on 11-03), so check it again.
- Iron Court (3832328087) had differed at 23:41. Another session uploaded it at 23:42:52.

## What changed

- **The bars over each entity** (`hud.lua` `H.men`): the men are read every 0.1 s (`MEN_EVERY`) instead of every
  frame. Every frame places each bar from the last read, through this frame's view, so a turn of the view still moves
  them at once. Before, each frame read every man of every unit within 70 m: his pointer and position, and the hit
  points of men within 40 m, each a memreader call. A running man's bar now moves in 0.1 s steps.
- **CA's HUD sweep** (`main.lua` tick, `HUD_EVERY` 0.25 s): under the cinematic UI (single player, mouse grabbed), where
  CA's interface is not drawn, it runs four times a second and at once on a change. Wherever CA's interface shows (the
  mouse freed, Vanilla command mode, CA's banners, multiplayer), it still runs every frame, because the game shows parts
  again on its own (a banner every tenth of a second, measured 2026-10-23).
- **The panel's parts** (`hud.lua` `part`): each found part is kept while the panel is the same one. It was about 32
  searches of the panel a frame.
- **The disarm** (`platform.lua` `is_attack`): 1901-1910 and 1931-1950, not 1901-1950. A played rider keeps
  `RIDER_ATTACK_IDLE_1-10` and `RIDER_DEFEND_1-10` (1911-1930).
- **Command mode, Vanilla style** (`command.lua` `cursor_line`): the target line says "Middle mouse: free the cursor",
  then "Middle mouse: look around" once the cursor is free, in the key's own name from MCT. Two new loc rows,
  `derpy_tp_ui_cursor_free` and `derpy_tp_ui_cursor_back`.

## Checks

- Harness 713 + 49 lockstep, cave 43/43, `third_person_patterns.py` and `third_person_cave.py --check` ok on `6ae2a00b`.
  `check_lua_api` and `check_lua_literal_left` are clean over the four files.
- New tests, each watched failing first:
  - `the_men_under_the_bars_are_read_ten_times_a_second`: 60 reads a second before, 10 after;
  - `cas_hud_is_hidden_again_four_times_a_second`: 60 passes a second before; it also checks every frame with the mouse
    freed;
  - `the_panels_parts_are_looked_up_once`;
  - `vanilla_command_mode_says_which_key_frees_the_cursor`;
  - the fragment test with seven rider slots added.
- `the_guide_key_brings_cas_banners_back_and_the_bars_step_aside` now waits 0.3 s, not 0.1 s, for the holder it makes
  after the start.
- Mutation round 71: 15 of 15 killed. Round 33's and round 60's anchors moved to the new lines, and both mutants are
  still killed.
- **Not checked live:** the frame time, the cursor line on screen, a played rider blocking.

## Change note

```
[list]
[*] Better frame rate in third person, most of all with the health bars over each entity on
[*] Command mode (Vanilla style): the screen now says which key frees the cursor
[*] Mounted entities you play: their block animations are no longer switched off
[/list]
```
