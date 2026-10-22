# Changelog

## Unreleased (not on the Workshop)

- Multiplayer mode: every change goes through the game's own battle command queue, so both machines run the same
  battle. Built and tested offline in a two-machine simulation; not yet run on two machines.
- In multiplayer it needs the mod and memreader Plus on every machine. The first F2 asks every player; it starts by
  itself once all have answered; if not, it says so and the log names the missing armies. Nobody pressing F2 sends nothing.
- Spectators never start it.
- The multiplayer message no longer blames the game version for every refusal.

## 2026-10-21

- Mounted lords jump and charge-attack on their mount; the rider no longer plays the jump on a standing horse.
- A unit of one (an Engineer, a hero, a lord) shoots the enemy on the crosshair, or the one nearest it, by unit order:
  ground fire at the aim's far point walked him off.
- He turns to the camera at the set turn rate (twice it for swings, jumps and shots) instead of snapping.
- Space asks to fly or land and waits for CA's toggle (its cooldown, a landing under way) up to 20 s; a second press
  takes it back.
- The fly button shows the toggle's cooldown and dims while it cannot be used.
- Ability slots grey out while recharging, and show the uses left of an ability that has a count.
- Known: on a siege wall, one man the deployment placed gets no path until his regiment has made one native move.

## 2026-10-20

- One man of a chariot unit drives one chariot.
- The ability bar has pages, abilities and spells, on a key (T; MCT can change it). Passives take no slot.
- A spell pressed twice overcasts, a third time cancels; the bar says why an overcast cannot go off.
- Hidden and Unspottable show on the unit panel.
- A ranged regiment aimed at an enemy unit fires at it.
- Sprinting into an enemy charges it, for regiments and units of one; regiments no longer freeze while sprinting.
- Large single entities keep their native charge clips; aiming poses use each projectile's gravity.
- Input set-up no longer refuses an address layout only Windows gives (Wine/Proton, untested there), and says so when it
  fails instead of reporting memreader Plus missing.

## 2026-10-19

- Lords and monsters can't be hurt during jump attacks, charge attacks and blocks.
- A lord or monster standing still blocks a blow that lands on him.
- Playing one man no longer stops his regiment shooting: no halt, defend or fire order on a regiment for one man.
- The man you play no longer shoots on his own with his regiment's volleys.
- All ten attack animations are playable, split between the two mouse buttons; a ranged unit has them all on the left.
- The HUD starts whole each session, and comes back after a transformation whose card arrives late.
- Health bars over nearby units in their side's colour (MCT: always, with the markers key, or never; distance, 40 m by
  default). The engine owns a pinned component's own visibility, so the bar is shown and hidden through a plain parent.
- Hold Alt (or press, in MCT) for the game's markers under enemies and allies; the game's Alt shortcuts on the mod's keys
  are off while third person is on.
- The repository no longer carries the bridge's generated `zz_tp_load_N.lua` parts.

## 2026-10-18

- Sieges: walking into a wall, gate or building no longer stops the man dead; his steering point comes in nearer.
- Artillery: a click fires the gun at the enemy in range nearest the crosshair; the crew never swing, charge or jump.
- The camera stays with him beside buildings and under gatehouses instead of rising over the roof.
- Lords, heroes and monsters sprint faster: a unit of one is steered like the man you play.
- Flying units play their flying charge in the air, not the ground charge run; no charge attack in the air.
- Melee mode centres the camera on him; aiming an ability looks ahead again.
- Aiming shoulder setting: Right, Left or Top.
- Camera rig tests run on their own.
- Lords, heroes and monsters: swings, jumps and charge attacks play in a lasting melee.
- Lords, heroes and monsters: no turn order before a swing; the swing plays where the camera looks.
- A swing after a turn order is no longer cut by the next click or the charge run.
- One man of a regiment sprints at full speed: monsters (Spawn of Tzeentch, Champions of Slaanesh) ran no faster than their run.
- Flyers without a mount (Be'lakor) swing their flying attacks in the air; no jump attack in the air.
- Ranged lords and monsters (Ku'gath): a click's shot waits for the reload and plays its whole throw.
- A move key cancels a shot still waiting to fire.
- The sprint's charge run plays each full cycle before it repeats.
- No jump for units whose jump animation is an empty file (Great Unclean One).
- Crewed monsters (Necrofex Colossus, Warsphinx) are played as one body: ranged fire, swings and the walk work.
- A crewed monster's shot plays its whole firing animation.
- Moving the mouse during a shot no longer restarts the aim: the shot fires.

## 2026-10-17

- Ranged men without a reload animation (grenadiers, crossbows, gunshields) wait the full reload time.
- Ammo changes that swap the unit (Deithland's modes) keep third person on the new form.
- Fire held while pressing F2 no longer switches the mod off.
- Artillery's Manual fire stays open: the click waits a second for the camera to settle.
- Decompiled exe code taken out of the repo.
- Smoother camera turning, with a Turn smoothing setting (0 turns at once).
- First person view on V, or by zooming in all the way: from the man you play, or a unit of one.
- Zooming in goes first person where the camera would end up in his head (on slopes, well before the closest zoom).
- Mounted archers get their ranged mode and shoot from the saddle.
- Sprint and charge 50% faster than the run.
- Flying units are played as one man.
- Known issue: a flying unit landed in third person takes off again only after third person is turned off and on.
- War machines played whole turn to the aim and fire there, instead of swinging back to the nearest enemy.
- Fixed a crash while playing one man.
- Default time between swings 4 s, between jump attacks 10 s.
- New: `tools/third_person_cave.py`.

## 2026-10-16

- Melee clicks swing in a melee: 200-400 ms, where most were lost.
- No auto attack: the man you play swings only when you click.
- Horses run and sprint at full speed.
- No idle frame between aiming and firing.
- Mounted men steer, face and fight on the mount itself; the mount's own attacks, jumps and cheers.
- A man who dies hands over to the next man of the regiment.
- New: `docs/BATTLE_ENGINE_RE.md`, `tools/exe_re.py`, `tools/ghidra_decompile.py`.

## 2026-10-15

- First public version: the pack's source, the build and test tools, the probes and mutation sets, and the design record.
- Swings use only the attacks the man has; jump attack for units with only the second jump clip.
- Thrown bombs leave late in the throw.
- Run: toggle or hold (MCT), Run button on the HUD.
- Q held while running charges; a click in the charge throws the charge attack.
- Smooth turning, with a turning speed setting.
- Camera comes in close in melee, with a distance setting.
