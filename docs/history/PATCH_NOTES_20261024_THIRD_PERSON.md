# Patch notes, Third-Person Battles, 2026-10-24

Steam change note for item 3822187184, build `6d48215c` (2026-10-24 12:40), the first upload since `4063e08a`
(2026-10-23 23:25). Casual tone, one short line per change. Every line below was seen working in game on 2026-10-24
except the multiplayer freeze, which was measured on one machine and never with two players
(`THIRD_PERSON_BUGS_20261024.md`).

```
[list]
[*] New: Unit stats in MCT, buff or debuff the unit you play (melee attack, melee defence, weapon strength, charge, armour, missile strength, speed, leadership), all None by default
[*] Spells show their winds cost on the ability bar, and the overcast cost while overcast is armed
[*] Multiplayer: your third person should no longer freeze the other player's camera, UI and selection
[*] Multiplayer: clearer message when the other player seems to be missing the mod (both need the same update)
[*] Command mode: crosshair no longer goes missing
[*] Command mode: mouse wheel and +/- zoom now
[*] Smoother zoom
[*] Health and stamina bars come back after leaving command mode
[*] Attack button says Left / Right for units that can't shoot
[*] Charge animation loops without the one-frame glitch
[*] Number row not picking units in command mode? Set "Command mode: select unit 1-10" back to 1-0 in MCT, an old saved setting overrides the new default
[/list]
```

Uploaded 2026-10-24 13:37 Manila through the steamworks binding (`updateItem`, contentPath = the Workshop folder, pack and
preview, and changeNote only): `{"itemId":"3822187184","needsToAcceptAgreement":false}`, Steam log `Uploaded new
content ( ManifestID 2509739784260720151 )`, `Upload finished ... : OK`. `GetPublishedFileDetails`: file_size 4832734
(pack 3863749 + preview 968985), time_updated 1792820258, title, tags and visibility unchanged. The pack doubled from
1.95 MB on the faction rows the unit stats need (29,560). No repo push.
