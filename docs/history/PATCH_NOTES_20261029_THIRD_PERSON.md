# Third-Person Battles: Workshop update, 2026-10-29

Item 3822187184, build `2ec7e798` (2026-10-29 12:18), the first upload since `39646933` (2026-10-25 11:07).

**Uploaded 2026-10-29 13:18 Manila** through the steamworks binding (`updateItem`, contentPath = the Workshop folder,
which holds the pack and its preview, and changeNote only), with the script and manifest in
`Modding Files/Backup/pre_upload_20261029_third_person/`. The result was
`{"itemId":"3822187184","needsToAcceptAgreement":false}`. Steam's log reads `Uploaded new content ( ManifestID
2741433552219872419 )` and `Upload finished ... : OK`. `GetPublishedFileDetails` gives file_size 5337798 (pack 4368813
plus preview 968985) and time_updated 1793251108; title, public visibility and tags (mod, battle) are unchanged. No repo
push.

Covers
`THIRD_PERSON_FIXES_20261029.md` (the 10-28 report fixes and the melee strike) and
`THIRD_PERSON_WALLS_ARMY_ABILITIES_20261029.md`.

Each line was checked against its source before the upload. A line seen working in game states it plainly. A line
tested only in the harness says "should":

| Line | Source | Seen in game |
|---|---|---|
| Army abilities page | walls/army doc | yes, Rod of the Storm cast from key 2 |
| Walls and bridges | walls/army doc | yes, single player; multiplayer steering not checked |
| Melee damage, one man / single entity | fixes doc, "The strike" | yes, single player; a unit played whole and multiplayer still deal none |
| Unit stats in campaign | fixes doc | yes, campaign battle |
| Alt banners | fixes doc | yes |
| Cavalry charge attack | fixes doc | yes |
| Flyers landing on a sprint | fixes doc | harness only, so "should" |
| Multiplayer portrait and ability bar | fixes doc | harness only (single player live), so "should" |

Change note:

```
[list]
[*] New: army abilities on the ability bar, a third page after abilities and spells (T to switch)
[*] You can walk on walls and bridges now (single player)
[*] Melee hits deal damage now when you play one man of a regiment or a single-entity unit, and they use all their attack animations again (single player)
[*] Unit stats from MCT now work in campaign battles too
[*] Alt shows enemy unit banners again
[*] Cavalry: charge attack works for more mounted units
[*] Flying generals should no longer land when you sprint in the air
[*] Multiplayer: CA's portrait and ability bar should stay hidden while you look around
[/list]
```
