# Changelog

## 2026-10-18

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
