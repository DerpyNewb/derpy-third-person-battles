# Patch notes, Third-Person Battles, 2026-10-22

Steam change note for item 3822187184, build `906b1c92`. Casual tone, one line per change.

```
[list]
[*] Multiplayer works now (experimental), as long as everyone in the battle has this mod and memreader Plus
[*] Not tested on two PCs yet, so expect bugs, and please send logs if you hit a desync
[*] In multiplayer the first F2 checks that everyone has the mod, then turns on by itself; if someone's missing it, it tells you
[*] Spectators can't use it
[*] Single player is unchanged
[/list]
```

Smoke test before upload (single player, the deployed pack, 4 battles, 2026-10-22): a Chaos Dwarf Warrior and Astragoth
walked and swung, lock-on picked the nearest lord, the battle ended with Astragoth played, a Hobgoblin Archer walked,
died and was taken over by the next man, the new man shot twice (one arrow each), F2 switched it off. No errors in the
four battle script logs. Compared with the published `85c03b3b`, every single-player timing is unchanged: the
multiplayer waits add 0 outside net mode.

Uploaded 2026-10-22 12:18 Manila through the steamworks binding (`updateItem`, contentPath + changeNote only, folder =
pack + preview): Steam log `Uploaded new content ( ManifestID 1489569302862894756 )`, `Upload finished ... : OK`.
Title and tags unchanged. Repo push `3ac7563`.

## Second update, build `f9a972df`

```
[list]
[*] Unit bars show morale under health
[*] Icon on a bar when that unit's morale wavers or breaks
[*] Icon on a bar while a spell or ability is on that unit, up for good, down for bad
[*] Alt also brings back the game's own unit banners (MCT switch, on by default)
[*] The unit your spell or ability would hit gets marked, your own units too
[*] Multiplayer: fixed "no answer from" when everyone had the mod (battles against the AI, a friend watching)
[/list]
```

Built 2026-10-22 19:24 (`tools/build_third_person.py`: selftest, 573 + 41 lockstep tests, 29 cave mutants, then packed
and read back, 23 files and 7 loc rows). Same 27 paths as `906b1c92`. Live check: see
`HANDOFF_20261022_THIRD_PERSON_BANNERS_MORALE.md`.

Uploaded 2026-10-22 19:52 Manila, same route as the first: Steam log `Uploaded new content ( ManifestID
3618937761616428547 )`, `Upload finished ... : OK`. Title and tags unchanged. The other 91 Workshop packs had the same
size and timestamp right after. Repo not pushed.
