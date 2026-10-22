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
