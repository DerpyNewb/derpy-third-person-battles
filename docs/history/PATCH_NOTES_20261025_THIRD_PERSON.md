# Third-Person Battles: Workshop update, 2026-10-25

Item 3822187184, build `39646933`, uploaded 2026-10-25 11:07 through the steamworks binding (content and change note
only), manifest 6746841628282873517. Details and test status: `THIRD_PERSON_BUGS_20261024.md`.

Change note as posted:

- Multiplayer: no longer waits for a player who is only watching the battle
- Multiplayer: F2 no longer takes the other player's general when you share a side (code end, no logs provided)
- Multiplayer: walking and turning no longer stuck going forward (code end, no logs provided)
- Multiplayer: every player needs this version
- Large ranged units like gyrocopters no longer shoot themselves (code end, no logs provided)
- Wind spells go the way you're looking (code end, no logs provided)
- Melee: attacks skip animations that can't deal damage, when the unit has others (code end, no logs provided)

None of these was tested in game before the upload: offline tests, lockstep and mutants only (rounds 67-70).
