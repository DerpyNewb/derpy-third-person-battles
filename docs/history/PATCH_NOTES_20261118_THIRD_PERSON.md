# Third-Person Battles: ability readiness, refusal hints, Single Combat!, held clicks and walking out of a swing, 2026-11-18

Item 3822187184. These are fixes for the reports verified that morning (`THIRD_PERSON_BUGS_20261024.md`, "Status on
2026-11-18"): Skarbrand's Bellow of Endless Fury, Tyrion's missed attacks, the army bar beside Single Combat!
(`3831075966`), and getting stuck with larger lords. Game `6ae2a00b` (9.0.5).

Build `b5ac9ea2`, saved to `Modding Files/Modpacks/derpy_third_person.pack` and verified from the saved pack (28 files,
126 loc rows, 11 stat tables; the same file list as the published `89ceb490`). **Deployed** to the Workshop folder
`3822187184` (md5 checked, no loadfast cache). **Uploaded 13:09** at the author's request ("push the patch"), through
the steamworks binding (contentPath + the change note below only). Steam's log: `Uploaded new content ( ManifestID
1002071125206648033 )`, `: OK` at 13:09:43; published file_size 5,643,576 = pack + preview. Scripts, manifest and the
pack are in `Modding Files/Backup/pre_upload_20261118_third_person/`. The published `89ceb490` is backed up as
`Modding Files/Backup/derpy_third_person_20261118_122607.pack`; the first build of the day (`45120fc6`, before the held
click through a swing) is `derpy_third_person_20261118_125449.pack`.

## What changed

- **Ability readiness follows CA's button** (`hud.lua` `H.can`, the slot dim, the context read loop). A unit ability is
  now judged by `CanCurrentlyPerform` on his card's context, the state CA's own button greys out by. Before, the pack
  asked `can_perform_special_ability`, which stays true in melee for Bellow of Endless Fury and through a cooldown, so
  the slot looked ready, the key armed it and the click did nothing. Without a context the engine's answer is still
  the fallback. Army abilities already used CA's button.
- **Refusals are said on screen** (`abilities.lua` `ready`, `A.press`, `A.cast`, `A.fire`; `hud.lua` hides the line
  after 2 s). Three new loc lines: "Recharging", "Not enough winds" (the spell's winds above the pool) and "Cannot be
  used now". A refusal by the game is said every time; the log still names it once per battle. The dropped return at
  `main.lua` 487 no longer matters, since the hint is shown where the reason is known.
- **A click with nothing to land on stays armed** (`A.fire`). Before, it disarmed in silence. Its label already says
  why ("No enemy in sight", "Out of range"). A refusal by the game still disarms, with its hint.
- **The click casts at the unit the label names** (`abilities.lua` `target_of`), while that unit is still a valid
  target in reach. Before, the click searched again and could find nothing 0.1 s after the label had named a unit.
- **A unit's front counts on the crosshair, not only its centre** (`nearest_to_ray`, `half_width`). Half of
  `unit:ordered_width()` (at most 20 m) is taken off the distance from the ray before the 12° cone. Between two units
  both under the crosshair, the one whose centre is nearer wins.
- **Hidden army buttons get no slot** (`hud.lua` `army_shown`, `army_entries`). The Army abilities page lists only the
  buttons CA's bar shows, and is rebuilt when that set changes. Single Combat! hides its 25 duel abilities and, during
  a duel, the army's own; the pack listed and cast them all.
- **A click inside the swing gap, or during his own swing, swings when it can** (`combat.lua` `C.melee`, `C.attack`).
  The 4 s gap is unchanged (the author's default). One click is held, and it swings when the gap ends. It is dropped
  if something else holds him more than 0.5 s past the gap's end (a knock, a jump), when he arms an ability or
  changes mode (`stand_down`), and when he walks out of the swing. A click through a jump or a cheer is not held.
- **A swing takes a clip of its button that reaches someone** (`swing()`), when the button's turn would land its blow
  on nobody. Struck swings only (one entity or a unit of one, single player). With none in reach, the turn's clip as
  before.
- **A move key ends a swing once its blow has landed** (`C.locked`). Only when the key was pressed after the swing
  began, so a click while walking still plays out in full (the author's 2026-10-15 rule). Also when the blow found
  nobody. The engine's armed blow is read off him (`P.blow`) so the cut never drops a blow that is still to land.

## Measured live

Two launches on the deployed builds, minimal list (intro skip, bridge, both memreaders, the pack; then the same plus
Single Combat!). Keys stubbed with the game in the background, probes `zz_tp_live_20261108.lua`,
`zz_tp_verify_20261112.lua` and `zz_tp_verify_20261118.lua`. Test prefs applied and reverted, lists deleted, game
closed.

| Report | This morning on `89ceb490` | Now |
|---|---|---|
| Bellow in melee | Slot looked ready, key armed it, click did nothing and said nothing | Slot dimmed (`can` false while the engine says true); the key does not arm; "Cannot be used now" for 2 s |
| Bellow out of melee | Worked | Works: clip 1153 0.3 s after the click, recharge 57.2 s, Orc Boyz 120 -> 105. Key pressed during the recharge: "Recharging" |
| Stuck in a crowd (Skarbrand, Orc Boyz round him, one click, back pressed 0.3 s later) | ATTACK_1 3.9 s, under a metre moved until 4.5 s, the blow on nobody | The blow hit (666); the swing let go at 1.8 s; 7 m out by 3.7 s |
| Tyrion, a click every 3 s against Grimgor alone | 5 of 10 swung; ATTACK_1 on nobody 5 of 5 | 8 swings, one each 4 s gap with none skipped; 8 of 8 blows hit (ATTACK_2 whenever ATTACK_1 could not reach). The two clicks with no swing of their own fell in the same gap as another click |
| Army bar with Single Combat! | 3 Army abilities pages (28 entries) | 1 page, the 3 Khorne abilities |
| A duel on | CA's bar empty, the pack's showed 28, Horn of Khorne cast mid-duel | CA's bar empty, the pack's army page gone, nothing to cast |

The Tyrion row is from the second launch, which had Single Combat! loaded. The first build of the day (no held click
through a swing) gave 7 of 10 in the first launch: the three missed clicks fell during his previous clip, which is
what the held click through a swing fixes.

`ordered_width()` read live: Orc Boyz 22.1 m (40.5 m once they fought), Big 'Uns 22.4, Grimgor 2.2, Skarbrand 4.86.

**Not checked live:** the front-of-unit targeting. Two sweeps were spoiled: a callback that never removed itself ran
two sweeps at once, and the held Orc Boyz walked back to an earlier spot after a teleport and halt, then chased him
into melee. The harness covers it, with `ordered_width` read from the game as above. The army page coming back after a
duel was not seen either: Grimgor could not be killed mid-duel, so the duel never ended. The hide half ran live (3 to 0).

## Checks

- Harness 739 + 49 lockstep, cave 43/43, pattern and cave checks ok on `6ae2a00b`. `luac -p`, `check_lua_api.py` and
  `check_lua_literal_left.py` clean on `abilities.lua`, `hud.lua`, `combat.lua` and `main.lua`.
- New tests, each watched failing first: `a_unit_ability_cas_button_greys_out_is_dimmed_and_not_cast`,
  `a_refused_press_says_why_on_screen`, `a_spell_the_winds_cannot_pay_for_says_so`,
  `a_cast_the_game_refuses_says_so_every_time`, `a_click_with_nothing_to_hit_stays_armed`,
  `the_click_casts_at_the_unit_the_label_names`, `a_wide_unit_is_on_the_crosshair_when_its_flank_is`,
  `a_hidden_army_button_gets_no_slot`, `a_click_inside_the_swing_gap_swings_as_it_ends`,
  `a_click_held_for_the_gap_can_go_unswung`, `a_click_during_his_swing_swings_after_it`,
  `a_swing_takes_a_clip_of_its_button_that_reaches`, `a_move_key_walks_out_once_the_blow_has_landed`.
- `an_ability_never_for_lords_and_heroes_is_never_cast_on_him` changed with the behaviour: its second attempt is now a
  click, since the first click with nothing to hit leaves the ability armed.
- Mutation round 75 (`probes/mutants_round75.py`): 33 of 33 killed. One survivor on the first run (the clip search
  started one past the turn's clip) led to an order check in the reach test. Three older anchors went stale with
  today's edits and were re-aimed and run (round 32 `stand_down`, round 61 `target_of`, round 73 `C.attack`'s knock):
  3 of 3 killed. 64 other anchors in rounds 32-68 were already stale before today and were left alone.

## Not done

- A reason more specific than "Cannot be used now" (CA's `ValidUsageDescription` takes an expression state and was
  not tried).
- Mounted lords' clip choice: the reach search uses the body that swings, as `lands()` does, but no mounted unit was
  tested.

## Change note

```
[list]
[*] Abilities are greyed out when the game won't allow them, like Skarbrand's Bellow of Endless Fury in melee
[*] A message under the crosshair shows why an ability didn't go off
[*] Clicking with nothing to hit no longer cancels the ability
[*] Abilities now go to the unit named under the crosshair
[*] Wide units are easier to target along their front
[*] Army abilities hidden by other mods (like Single Combat!) no longer show up
[*] Clicking during a swing or its cooldown now queues the next swing
[*] Fewer swings that hit nobody
[*] A move key now walks you out of a swing once its hit lands
[/list]
```
