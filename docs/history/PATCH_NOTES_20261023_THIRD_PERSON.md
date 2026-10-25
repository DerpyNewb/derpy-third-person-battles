# Patch notes, Third-Person Battles, 2026-10-23

Steam change note for item 3822187184, build `4063e08a`, the first upload since `f9a972df` (2026-10-22 19:52). Casual
tone, one short line per change.

```
[list]
[*] New: command mode, press Q while playing your general or a hero
[*] Command mode slows the battle (speed in MCT)
[*] Vanilla style (default): normal clicks and drags at the crosshair, full HUD
[*] Number row 1-0 picks unit cards, E for the next ten
[*] Middle click frees the cursor, Space pauses, Shift tap toggles slow-mo
[*] Bannerlord style (MCT): 1-6 pick groups, left click move, right click attack, F1 follow, F3 charge, F4 hold
[*] MCT switch to use command mode on any unit
[*] 3D flags hidden in command mode
[*] Lord/hero-only abilities like Grimgor's no longer target regiments
[*] Shift sprint no longer locks onto an enemy behind you
[*] Multiplayer: fixed "can't see who is in this battle" on every battle
[*] Multiplayer: AI slots in lobby battles no longer block the start
[*] Still on it: cursor flicker, missing crosshair and inconsistent slow-mo in command mode
[*] Still on it: getting out of melee is slow
[/list]
```

Built 2026-10-23 23:02 (`tools/build_third_person.py`: selftest, 634 + 45 lockstep tests, 29 cave mutants, packed and
read back, 24 files and 9 loc rows). Same 24 paths as `f9a972df`; every packed file byte-matched
`Modding Files/source/third_person/`.

Uploaded 2026-10-23 23:25 Manila through the steamworks binding (`updateItem`, contentPath = the Workshop folder):
`{"itemId":"3822187184","needsToAcceptAgreement":false}`, `timeUpdated` 1792769132. Title and tags unchanged. The note
that went up with it was a long-winded first draft; the block above is the rewrite, to paste over it on the item's
Change Notes page. No repo push.

Open, from the author at 23:07: cursor flicker, crosshair missing, inconsistent slowdown in command mode. Leads: unit
banners under the parked cursor (only his own is hidden), and a Shift tap counts only with no other key held, so Shift
with a move key held does nothing.
