# Third-Person Battles: walls, bridges and army abilities (2026-10-29)

Answers two Workshop posts from 10-29, both by one player: "cant move whenever on bridge or on top of wall (sometimes for wall
working)", and "can you update for faction spell to be use when on third person mode? am playing as nagash but its soo
annoying to use it just to exit the third person mode". Built on top of the day's strike build
(`THIRD_PERSON_FIXES_20261029.md`), built 12:18 and deployed to the Workshop folder `3822187184` after the live run (about 12:33), MD5 `2ec7e798`.
**Uploaded 2026-10-29 13:18** (`PATCH_NOTES_20261029_THIRD_PERSON.md`). The copy it replaced (`a8a1c725`) is `Modding Files/Backup/derpy_third_person_20261029_121843.pack`.

## Walls and bridge decks

**Cause.** A walk's goal is a location: x, y, z and a surface ref, two qwords. The walk builder copies the mailbox
block's `+0x10/+0x18` into the walk at `+0x378/+0x380`, and the pathfinder's goal at `+0x7f8` takes them (`+0x808`).
The pack never wrote `+0x10/+0x18`, so every goal had a null surface. A null surface is the terrain. For a man on a wall
walk or a bridge deck, the goal was the ground under it, the pathfinder found no way (`+0x710` = 7), and he stood.

His own location is at `+0x910`. Its surface at `+0x920` is null on the ground and a per-section object (vtable
`exe+3ad7190`) on a wall or deck; it changes at each section. `+0x928` read 0 everywhere.

This also explains the 10-21 wall report (`WORKSHOP_REPORTS_20261021_THIRD_PERSON.md`): a native `goto_location`
built a walk with a real surface, and the pack then only rewrote its point in place, so it worked until the next walk
was built from the block.

**Fix.**

- `platform.lua` `P.steer` copies his own `+0x920/+0x928` (the mount's, for a rider) into the block's `+0x10/+0x18` at
  every steer.
- The update cave's in-place path (`tools/third_person_cave.py`) copies them into his own walk's `+0x378/+0x380`, and a
  change clears `+0x3c0`, so the goal is set again. The change test is now 64-bit (`test r8, r8`), since two section
  objects can differ only in their upper half.

**Live, before and after** (Volksgrad siege, Astragoth, enemy halted, keys stubbed):

| Run | Before (old build, 10-29 morning) | After (this build) |
|---|---|---|
| Wall walk at (82, 110, -219), along the wall | state 7, goal surface null, 0.00 m in every direction | 61.1 m in 12 s across six wall sections and up into a tower (y 110 to 114); the goal took each new section one steer after he reached it |
| Bridge deck (-226, 107, 208), along the deck (bearing 160) | state 7, 0 m | 125.8 m: the whole deck at full pace, off the far end (his surface went null at 14.5 s) and on across the bank |
| Same deck, bearing 130 | | 53.1 m, slowing to about 1 m/s along the east railing (130 is about 30 degrees off the deck's axis). The earlier emulation run showed the same crawl at the same place |
| Same deck, an enemy cavalry unit halted on it | | stopped 13.5 m short of the unit. The enemy blocks him, as it would any unit |

The 10-29 morning emulation (a Lua callback writing the same two fields) had already moved him 4.2 m on the wall and
58.7 m on the deck. The state 7 at the end of the 125.8 m run is on open ground, both surfaces null: a point ahead the
pathfinder has no way to, not this bug.

Not covered: multiplayer, where a steer is a forged MOVE through the carrier, not the block. Whether a MOVE carries a
surface is not checked.

## Army abilities: the third page

**What the player gets.** The ability bar's page key (T) now turns through his abilities, his spells and then
**Army abilities**: the abilities his army has, as CA's army-ability buttons show them, in CA's order and with CA's
icons. A regiment with no abilities of its own opens on the army's page. Each slot shows CA's cooldown, uses left and
dimming. A ground ability arms and casts on the click, aimed at the crosshair along his view. One aimed at an enemy or
an ally goes to the unit nearest the crosshair. One with no target goes off where he stands.

**Where it is read from.** The army's live ability records are reachable through CA's buttons only:

- `hud_battle > army_ability_parent > button_holder_<key> > button_ability_<key>`.
- `GetContextObject("CcoBattleAbility")` on the button gives an object whose `:Call(expr)` answers
  `CanCurrentlyPerform`, `RechargeTimeRemainingSecs`, `RemainingUses`, `IsTargettedAbility`, `CurrentState`, and the
  `SetupAbilityContext.*` fields, target flags included.
- `common.get_context_value("CcoBattleAbility", <id>, ...)` with the button's context id answers nil, and so does
  `cco("CcoBattleArmy", <army id>)`. `ArmyContext.ArmyAbilitiesList` on his unit gives the records, but not the live
  state.
- CA leaves the hidden abilities off its buttons, so the pack's 40 `derpy_tp_stat_*` abilities never reach the page.
- The page also keeps only the keys his own unit's army owns (`ArmyAbilitiesList`), so an ally's unit played shows no
  buttons that belong to another army.

**How it casts.** `army:use_special_ability(key, position, bearing)` (CA's `battle_army` doc). Its binding,
`exe+2f263ac`, pushes a queued battle command like the unit casts do (`BATTLE_ENGINE_RE.md` section 13), so it
networks the same way. No unit order is given, so control is never handed back.

**Code.** `hud.lua`: `army_entries()`, a third kind in `build()`, `read(n, field)`, which reads a slot from his context
or from CA's button, `H.army(n)`, `H.can(n)`, and a rebuild when CA's button count changes. `abilities.lua`: `ready()`
asks `H.can`, and `A.cast` has the army branch.

**Live** (same battle; Tomb Swarm, Rod of the Storm and Man the Cannons! granted through their campaign bundles):

- Pages read "Spells, Army abilities"; the tab read "(T) Army abilities" on the spells page and "(T) Spells" on the
  army's.
- Slots: the three in CA's order with CA's icons, none of the 40 stat abilities. Tomb Swarm was dimmed with an 8 s
  countdown: CA's opening recharge, which is also why `CanCurrentlyPerform` read false at the start of the siege.
- Rod of the Storm on key 2: armed, "Ground, 110 m"; the click cast it. Uses went 3 to 2, an 88 s recharge started,
  and the slot showed "2" and "89", dimmed. Third person stayed on.
- At 1600x900, the longest tab, "(T) Army abilities", fit: a 165 px plate ending 8 px before slot 1, the bar and tab
  centred, clear of the portrait plate. `common.take_screenshot` has no UI layer, so this was measured, not seen.

Not covered: a player with two armies in one battle (whose buttons CA shows is not measured), and multiplayer live.
A unit-targeted army ability was tested in the harness only; the three granted here all aim at the ground.

## Tests

- Harness: 11 new tests. One platform test: `a_steer_carries_the_surface_he_stands_on` (wall, ground, a rider's horse).
  Ten army-page tests: the third page, a unit with none of his own, an ability his army does not own, the ground cast
  and its bearing, the enemy cast, a dimmed one not cast, cooldown and uses, a page without his list, and one granted
  mid-battle.
- Fakes: the harness fakes CA's buttons (`H.army_ability`) with the fields read live, and `army:use_special_ability`
  now records the bearing. **678 + 47 pass.**
- Mutants, Lua: 12 of 12 caught. The owned filter, the page itself, the rebuild on a new button, the dim and CA's
  `CanCurrentlyPerform`, the live read of army slots, the page without his list, `ready()` asking CA, the bearing, the
  army branch, the enemy aim and the ground aim. The platform test also fails with the surface write removed.
- Mutants, the cave's emulator: 43 of 43 caught, three of them new: the surface not copied in place, a new surface
  keeping the old goal, and the change tested in 32 bits. Three new in-place scenarios cover onto the wall, off it, and
  another section differing only in the upper half.
