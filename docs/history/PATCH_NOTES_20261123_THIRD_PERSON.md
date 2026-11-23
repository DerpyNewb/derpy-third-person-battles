# Third-Person Battles: a locked group and F2, and Space during a landing, 2026-11-23

Item 3822187184. Two Workshop reports from 11-21 and 11-22, both reproduced live on 2026-11-23 before the fix. Game
`6ae2a00b` (9.0.5).

Build `70C6EEF4`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and deployed to the Workshop folder
`3822187184` on 2026-11-23 at 20:33. Against the published `6BD96B57` (the 11-21 upload), `main.lua` and the loc
differ. The 11 stat tables differ only in the GUID header RPFM writes on save, and the build's own read-back
verified 28 files, 127 loc rows and 11 stat tables. The published build is backed up in
`Modding Files/Backup/third_person_20261123/`.

## What changed

- **F2 on a locked group no longer switches the mod off** (`main.lua` `start`). CA's `add_units` throws for a unit
  in a locked group: `lib_battle_misc.lua:215: calling 'add_units' on bad self (unit is already in another group)`.
  F2 on a locked group holding the general threw it every press, and the third press hit `MAX_ERRORS` and switched
  the mod off until the battle ended. The error is now caught and the player sees the new loc line
  `derpy_tp_locked_group`: "A unit in a locked group can't be played. Unlock the group, then press %s." It is not
  counted as an error. A locked group without the general, and an unlocked group with him, worked before and still
  do. The pack does not unlock the group itself.
- **A Space press during a landing is kept** (`main.lua` `fly`). In a landing `is_currently_flying()` stays true for
  its 3 s, so a press then to go back up matched "already where you asked" and was cleared the same tick. A press is
  now done only once he is where it asked and no order the other way, which the pack did not click, is under way (CA's
  `IsFlying`). A press during a take-off already worked.

## Measured live before the fix

On `6BD96B57`, minimal list (bridge, both memreaders, the pack):

- Locked group (Ctrl+G) of two skeleton units with the general: F2 failed every press with the line above, and the
  third press switched the mod off. Unlocked group (G) of the same units: F2 started, no error.
- Space on a flying lord: a press 1.1 s into a landing was cleared the same tick, and he stayed on the ground. A press
  during a take-off was kept.

**Not checked live on `70C6EEF4`.** The harness covers both.

## Checks

- Harness 751 + 49 lockstep. Two new tests, `f2_on_a_locked_group_says_so_and_stays_on` and
  `a_fly_press_during_a_landing_takes_off_once_landed`; the harness's `create_unitcontroller` now throws CA's message
  for a unit marked `_locked_group`. Both new tests fail on the published `main.lua` for the reported reasons and pass
  on the fix. 43 of 43 cave mutants caught.

## Upload

**Uploaded 2026-11-23 20:53** at the author's request, through the steamworks binding (contentPath and the change
note below only). The script re-checked the pack's md5 against the pinned `70c6eef4...` right before the call. Steam's
log: `Uploaded new content ( ManifestID 6295079254768579642 )`, then `: OK` at 20:53:00; published `file_size` matches
the folder. Kit: `Modding Files/Backup/pre_upload_20261123_lords_and_third_person/`.

## Change note

```
[list]
[*]Pressing Space during a landing is no longer ignored, it takes off again once landed
[*]F2 on a locked group now asks you to unlock the group instead of switching the mod off
[/list]
```
