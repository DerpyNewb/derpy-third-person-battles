# Scope: a health bar on each unit and ally/enemy marking, in third person (2026-10-19)

Players ask for "a health bar each unit and a ally or enemy highlight". Scoped offline: the code, CA's 9.0 docs, CA's
shipped scripts and the UI packs in `data/`. Nothing was run in game.

**Built 2026-10-19 (B and C, both, each an MCT switch, on by default):** `HANDOFF_20261018_THIRD_PERSON_SIEGE_WALK_ARTILLERY.md`
section 13 has the design, the live results and the one bug (`cco` lives in `core:get_env()`, not `_G`).

## 1. What the mod does today

- Third person turns on CA's cinematic UI, which hides CA's whole interface, and turns off the unit banners (the flags
  over every unit) each time it switches: `main.lua` `cursor()`, `bm.battle:set_banners_enabled(false)`. That was the
  author's choice on 2026-10-14 ("the pack draws its own"). `M.stop` puts the banners back.
- The HUD shows the played unit's health only.

So the game's own per-unit health bar exists and the mod hides it. CA's banner (`ui3.pack`
`ui/battle ui/unit_banner.twui.xml`) carries `bar_health` (callback `BattleHealthBar`, 40x10), a delayed fill behind it
(`ContextFillBar` on `DelayedHealthPercent`, `#AA0000`, art `ui/skins/default/bar_white.png`), `bar_morale`, `bar_ammo`,
`bar_barrier`, the unit icon and rank.

## 2. What the game offers (offline evidence)

| Need | Where | Evidence |
|---|---|---|
| a unit's health | `CcoBattleUnit.HealthPercent`, `DelayedHealthPercent`, `BarrierHpPercent` | CCO docs |
| its place on screen | `ContextWorldSpaceComponent` with `CcoBattleUnit` / `Position` | CA's own dev UI: `ui/dev_ui/custom_dev_ui/common/example.twui.xml` `template_3d_unit` ("positions self over a unit in 3d space") and `battle/battle_team.twui.xml`; on the campaign map the same callback is measured to track (`docs/CUSTOM_UI.md`, "Pinning UI to the campaign map") |
| one per unit | `CcoBattleRoot.UnitList` (every unit in the battle), `CcoBattleArmy.UnitList` | CCO docs; CA's `world_space_list_example` is a `ContextList` over `CcoBattleArmy.UnitList` with no Lua |
| side | `CcoBattleUnit.IsEnemyUnit`, `IsPlayerUnit`, `AllianceColour` ("player/friendly/enemy/neutral") | CCO docs; `ContextColourSetter` is the callback CA's battle panels use for `AllianceColour` (10 of them) |
| no reveal | `CcoBattleUnit.IsVisible` ("taking into account hidden state and line of sight") | CCO docs |
| a bar per man | none in CCO: `CcoBattleEntity` has `Position`, `IsAlive`, `UnitContext` only | CCO docs; a man's hit points are only in memory (`+0xb18`/`+0xb1c`, `P.model_hp`) |
| an engine highlight | `unit:highlight(bool)`; `unitcontroller:highlight` ("tracker chevrons under their feet") | CA's script docs; **zero uses** in CA's 7,540 shipped scripts, so how it looks is unknown |
| a fallback projection | `WorldSpaceToScreenSpace` from Lua | already in `hud.lua` for the ability arrow, three context reads a point a frame |

## 3. Options

**A. Bring CA's banners back, as an MCT option.** Small: one setting, the `cursor()` line, its loc, tests. Players
get the health, morale and ammo bars they know from the normal game. Open: whether the banner shows which side a unit is
on (the layout file has no `AllianceColour`; the game may colour it in code), how large the banners are close to the
camera (they are sized for the strategy view), and the played unit's own banner over his head. The switch is global:
no script call hides one unit's banner.

**B. Our own thin bars, one per unit.** Medium: a generated layer in `gen_third_person_hud.py`, its preview and checks,
the Lua that makes the pins, tests, a live check. Each pin is a `ContextWorldSpaceComponent` on the unit's `Position`
with a bar on CA's `bar_white.png`: `HealthPercent` over `DelayedHealthPercent`, tinted by `AllianceColour`, hidden when
`IsVisible` is false and for the unit being played (the HUD shows his). This one answers both requests. Follow
`docs/CUSTOM_UI.md`: the holder is declared first and takes no clicks; no `ContextOpacitySetter` (a Lua-made pin with
CA's fade draws nothing); a pin is repainted, never remade. Open: whether a pin tracks in battle as it does on the
campaign map (CA's dev UI says it does; not measured here); how high above the unit it stands (`Position` is the
unit's centre on the ground, so a fixed lift either clears a man and sits in a giant, or the reverse, unless Lua sizes
it per unit from `data.lua` bodies); cost with 80 or so pins (CA's banners are the same count).

**C. CA's highlight on each unit.** Smallest, if it draws anything useful. Unknown look, and the unit-controller form
on enemy units means a controller on the AI's units (the probes made those; whether `highlight` alone takes control
away from the AI is unknown). One probe answers both.

**D. A bar per man.** Needs a per-frame Lua projection and a memory read for every man. Not worth it: for a lord or a
monster the unit's bar already is the man's, and a regiment's men have no bar of their own in CA's game either.

## 4. Recommendation

B is the feature: thin bars coloured by side cover both requests and fit the third-person view. A is the quick first
step, if the author is fine with CA's look: one live check tells whether the banners already separate the sides.
Not D.

## 5. For the author to decide

1. CA's banners were hidden for the cinematic look on 2026-10-14: is a "show unit banners" option acceptable (A), or
   should the bars be the mod's own (B)?
2. Bars on enemies only, or allies and the player's own units too? Any distance limit?
3. The bars hide units the player cannot see (`IsVisible`). Keep that?

## 6. Live checks, each one short probe once the game is free

1. Banners on while in third person: do they draw over the cinematic UI, colour by side, and how big near the camera.
   **Open:** UI-layer, and the in-game screenshot captures the 3D scene only.
2. `unit:highlight(true)` on one enemy unit: what draws, and whether its AI keeps control. **Done 2026-10-19**
   (handoff `HANDOFF_20261018_THIRD_PERSON_SIEGE_WALK_ARTILLERY.md` section 11): `unit:highlight` drew nothing in the 3D
   scene. `unitcontroller:highlight(true)` draws a marker under every man, red on an enemy regiment and green on ours,
   and keeps it after `release_control()`: the enemy went back to its AI and moved on, ours back to the player. That
   makes option C a real ally/enemy marker with no control taken. Not seen: an allied (friendly AI) unit's colour, how
   it looks at the third-person camera's distance, and whether it lasts the battle.
3. One Lua-made pin (`CreateComponent`, `SetContextObject(cco("CcoBattleUnit", id))`) with `ContextWorldSpaceComponent`:
   does it follow the unit, and where does it stand. **Open** (UI-layer, as 1).
