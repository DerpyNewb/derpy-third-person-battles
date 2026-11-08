# Changelog

## 2026-11-08, third update

Workshop manifest 1737806279072665617 (build `b6adf1c8`). Both fixes below were found broken in game after the second
update; the offline tests had passed.

- Attacking an enemy gate walks to it and damages it. A unit of one is held on his spot every frame no move key is
  down, and that held him 9 m out under the game's order on the gate; the hold now stands aside for that order alone.
  Seen in game: 1.00 to 0.84, and a step ends it.
- The Sisters of Twilight's ranged click also swings the dragon. Two riders on one mount are a crew, which the first
  version left out; crews are in, war machines (chariots) stay out. Seen in game: three blows for 1,102 hp.
- The 1 hp report is still open: a lethal blow under the mod's shield could not be produced on demand, and one stall
  at 1 hp came with the shield off.

## 2026-11-08, second update

Workshop manifest 1907773830457288151 (build `36d4c69b`).

- A killing blow no longer leaves the entity you play standing at 1 hp. The game's invincibility does not block damage,
  it stops a lethal blow at 1 hp, and the mod shields a unit of one while he blocks or reels. A hit that leaves him at
  1 hp inside that window, or 0.3 s after it, now kills him.
- A lord, hero or other single entity damages enemy gates: a click with an enemy gate within 12 m ahead and no enemy
  where the blow lands is the game's own attack order on the gate. A step ends it. A building's owner number counts
  from 0 and the player's alliance number from 1 (measured attacking and defending).
- A rider who shoots from a mount that fights (the Sisters of Twilight): in ranged mode a click fires, and the mount
  swings too when an enemy is where its blow lands.
- Seen in game before the upload: the owner numbers, and the game's order on a gate (1.00 to 0.53). Not seen: the 1 hp
  kill and the mount's swing in game, the gate through the mod's own click. Not fixed: barricades (in a custom siege
  every barricade slot refuses the attack order, none is built), the Soul Grinder's sprint, the flamethrower's column.

## 2026-11-08

Workshop manifest 574328921042259151 (build `dc93af35`).

- With the numpad unit keys, each card shows only its digit, and a key label is never wider than its card.
- F2 with nobody to play says so.
- Seen working in game before the upload.

## 2026-11-07

Workshop manifest 6088154110788324478 (build `a2ded00a`).

- Better frame rate in third person, most of all with the bars over each entity on: the entities under the bars are
  read ten times a second and placed every frame, the game's HUD is hidden again four times a second under the
  cinematic UI instead of every frame, and the panel's parts are looked up once.
- Command mode (vanilla style): the target line names the key that frees the cursor.
- Mounted entities you play keep their block animations (1911-1930 are no longer counted as swings).

## 2026-11-03

Workshop manifest 3181060629449301078 (build `45a97df2`).

- Game patch 9.0.5 (exe build `6ae2a00b`). With no address row for it, the mod played every regiment whole. All 32
  addresses in `platform.lua` were carried from the previous build's code: masked byte signatures for code, and the
  instructions that reference them for data and vtables. Every function the mod hooks or calls is byte-identical apart
  from its RIP-relative operands, so the field offsets inside them did not move.
- Multiplayer was gated on the previous build's stamp, so it stayed off on 9.0.5. It now follows the row: any build
  whose row carries the queued-command addresses.
- `data.lua` regenerated for 9.0.5's database: the Stormfiend Windlaunchers' reload, the Ratling Cannons' shot speed,
  and the Necromancer on Nightmare's new key.
- Seen working in game on 9.0.5 before the upload: the build known, the battle and model-list checks on every unit, one
  entity walking alone, switching, melee blows, a shot and its reload, a lord as a unit of one, the gate and camera
  floor patched. Not seen: multiplayer.

## 2026-11-02

Workshop manifest 6519745943830383711 (build `0595ecdc`).

- Switch which entity of your regiment you play with X (left) and C (right), right and left of the view. The one let go
  is held where he stands, and a shot's reload carries over. The game's own X and C camera keys are off while third
  person is on.
- In command mode (vanilla style), each unit card shows the number key that selects it.
- The HUD's words are loc rows (`derpy_tp_ui_*`), so a translation pack can translate them.
- A regiment played whole attacks by the game's own order, on the enemy unit under the crosshair or nearest the aim,
  and deals damage. With no enemy ahead it says so.

## 2026-11-01

Workshop manifest 6262936272307300740 (build `441a78a2`). It carries the 2026-10-31 build too, which was never uploaded
on its own.

- Fire on the move, for the 348 units with the game's fire whilst moving (horse archers, skirmishers and the like). One
  entity plays its moving-fire animation by where the aim is from where it walks, and keeps walking. A regiment
  played whole, or a unit of one, fires at will while it moves, at targets the game picks.
- Morale on the panel: the percent, the game's word for shaken and wavering, and a red fill from shaken.
- Kill count on the panel (the unit's).
- A small health bar over each entity of nearby regiments (MCT option, on by default). Positions come from memreader
  and a pinhole projection, calibrated once a second against the game's own `WorldSpaceToScreenSpace`.
- Blows in the air and from the saddle land at their own animation's impact point (the `FLY_ATTACK`, `RIDER_ATTACK`
  and `RIDER_FLY_ATTACK` tables), not 2.5 m ahead.
- Locked on, a blow from one entity or a unit of one goes to the locked enemy's man when one is in reach.
- Artillery: a click with no enemy in range ahead says so on screen.
- An ability the data does not know (a mod's) that brings a new unit and aims at nothing is treated as a
  transformation: third person moves to the new unit, or stays on the caster if it turns out a summon.
- The camera boom eases in and out on hills instead of snapping in whole tenths.
- Multiplayer: the unit card is re-clicked at most every 0.5 s, and never while you look around (it made the rapid
  clicking noise). A partner with no army of their own is told why F2 does nothing.
- MCT texts say "entity" for one figure of a unit, not "man". The option keys are unchanged.
- Seen working in game before the upload: fire on the move (one entity and whole), the locked enemy first, the artillery
  message, morale and kills, the bars over each entity (0.86 px from the game's projection on average), the camera on a
  slope, and both multiplayer lines (in a solo multiplayer battle). Not seen: blows in the air or from the saddle (the
  Empire Knights tried carry the swing on the horse, which already had its point), modded transformations, and the red
  fill at shaken.

## 2026-10-29

Workshop manifest 2741433552219872419.

- Army abilities on the ability bar: T now turns through the unit's abilities, its spells and then its army's abilities,
  the ones on the game's own army-ability buttons, with their icons, cooldowns and uses. A click casts at the
  crosshair, on the unit nearest it, or where he stands. Hidden abilities, the mod's 40 unit-stat ones among them,
  never show.
- Walls and bridge decks: he walks on them now. Every walk's goal had a null surface, which is the ground under the wall
  or deck, so the game found no path and he stood. The goal now carries the surface he stands on. Single player;
  multiplayer steering is not checked there.
- Melee damage for one man of a regiment or a unit of one, single player: each swing picks the enemy man where its
  animation lands, and the update cave rolls the blow with the game's own melee roll. Those units swing all their
  attack animations again. A unit played whole and multiplayer are unchanged.
- Unit stats from the MCT work in campaign battles too: a hidden faction bundle enables the 40 stat abilities, applied by
  a new campaign script.
- Alt shows enemy unit banners again.
- Cavalry: the charge attack also counts the rider's own moving attack, so more mounted units have it.
- Flyers should no longer land when you sprint in the air.
- Multiplayer: the game's portrait and ability bar should stay hidden while you look around.
- Seen working in game: the first six. The last two were tested in the harness only.

## 2026-10-25

- Multiplayer: a player who is only watching the battle is no longer waited for. A watcher's machine cannot send
  anything into the battle, so the start waited for an answer that could never come. A watcher still needs the mod;
  one without it is not caught.
- Multiplayer: with two players on one side, F2 no longer takes the other player's general. The mod read the side's
  first army, not this machine's.
- Multiplayer: walking and turning no longer stick going forward. A turn is a queued command there, and each step was
  taken from a heading the battle had not caught up with yet.
- Multiplayer: every player needs this version (handshake version 3).
- Large ranged units like gyrocopters no longer shoot themselves: the shot leaves clear of the body.
- Wind spells go the way you are looking; the cast's direction was never passed.
- Melee: a swing skips the attack animations that cannot deal damage (no splash attack in their animation data) when
  the unit has others. A unit with none is unchanged.
- None of these was tested in game before the upload: the harness, the two-machine simulation and the mutants only.

## 2026-10-24

- Unit stats in the MCT: buff or debuff the unit you play (melee attack, melee defence, weapon strength, charge,
  armour, missile strength, speed, leadership), all off by default.
- Spells show their winds cost on the ability bar, and the overcast cost while overcast is armed.
- Multiplayer: your third person should no longer freeze the other player's camera, UI and selection.
- Multiplayer: a clearer message when the other player seems to be missing the mod.
- Command mode: the crosshair no longer goes missing, and the mouse wheel and +/- zoom.
- Smoother zoom.
- Health and stamina bars come back after leaving command mode.
- The attack button says Left / Right for units that cannot shoot.
- The charge animation loops without its one-frame glitch.

## 2026-10-23

- Command mode: Q while playing your general or a hero orders the rest of the army, with the battle slowed (speed in
  the MCT).
- Vanilla style (the default): normal clicks and drags at the crosshair and the full HUD. The number row picks unit
  cards, E the next ten; a middle click frees the cursor, Space pauses, a Shift tap toggles slow motion.
- Bannerlord style (MCT): 1-6 pick groups, left click moves, right click attacks, F1 follow, F3 charge, F4 hold.
- An MCT switch allows command mode on any unit, and 3D flags are hidden in it.
- Lord and hero only abilities, like Grimgor's, no longer target regiments.
- The Shift sprint no longer locks onto an enemy behind you.
- Multiplayer: "can't see who is in this battle" on every battle is fixed, and AI slots in lobby battles no longer block
  the start.

## 2026-10-22, second update

- Unit bars show morale under health.
- An icon on a bar when that unit's morale wavers or breaks, and one while a spell or ability is on it, up for good and
  down for bad.
- Alt also brings back the game's own unit banners, and the bars step aside (MCT switch, on by default).
- The unit an armed spell or ability would hit is marked, your own units too.
- Multiplayer: everyone having the mod no longer ends in "no answer from" when only one side is human (a battle against
  the AI with a friend watching). The handshake counts the game's network player list, not human armies.

## 2026-10-22

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
