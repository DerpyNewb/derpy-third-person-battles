# Changelog

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
