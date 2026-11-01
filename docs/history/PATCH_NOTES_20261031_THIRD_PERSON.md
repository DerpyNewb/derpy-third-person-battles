# Third-Person Battles: Workshop update, 2026-10-31

Item 3822187184. Build saved 2026-10-31 18:36 to `Modding Files/Modpacks/derpy_third_person.pack`; the build before it
(`2ec7e798`, the 10-29 upload) is in `Modding Files/Backup/third_person_20261031/`.

**Deployed, not uploaded.** Copied into the Workshop folder 2026-10-31 18:57, after the game closed (it was running when
the build finished): build `03c3a381`, 4,395,342 bytes. No `loadfast_cache_*.bin` exists to delete, and `data/` has no
copy of the pack. A Steam validation (any upload) re-downloads `2ec7e798` over it; check the md5 after one.

**Superseded** in the Workshop folder on 2026-11-01 08:48 by `89091119`, then at 10:03 by `441a78a2` (`PATCH_NOTES_20261101_THIRD_PERSON.md`), which
carries this build and its own; its change note covers both.

Covers the fixes and requests in `WORKSHOP_REPORTS_20261031_THIRD_PERSON.md` ("Fixed 2026-10-31").

Pack against `2ec7e798`: one file added (`ui/derpy_tp/man_bar.twui.xml`), eight changed (`hud.lua`,
`hud_layout.lua`, `main.lua`, `rig.lua`, `settings.lua`, the MCT settings file, `hud.twui.xml`, the loc). The DB tables
differ only in RPFM's header GUID; their rows are byte-identical.

| Line | Seen in game |
|---|---|
| Morale on the panel, red from shaken | harness and preview only, so "should" |
| Kill count | harness and preview only |
| Health bars over each man | harness and preview only; the placement is calibrated against CA's projection in game and has never run there |
| Camera on hills | measured offline on stubbed terrain: worst one-frame jump 3.8 m to 0.56 m |
| Multiplayer card clicking | harness only |
| Multiplayer refusal message | harness only |

Change note:

```
[list]
[*] New: your unit's morale on the panel, the bar turns red when it starts to break
[*] New: your unit's kill count on the panel
[*] New: small health bars over each man of nearby regiments (MCT option, on by default)
[*] The camera should no longer snap when you turn on hills
[*] Multiplayer: the unit card should no longer click every frame while you play
[*] Multiplayer: a message now says why third person cannot start when you have no army of your own
[/list]
```
