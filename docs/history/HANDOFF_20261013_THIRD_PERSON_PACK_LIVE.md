# Handoff 2026-10-13: third-person pack, first live runs

**Current resume point:** [held fire, mounted attacks, and unresolved F2 movement](HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md). The broken-walking account and proposed fixes below are historical. Native walking replaced nudges; the author confirmed gait/facing/HUD and held fire/mounted attacks. F2 movement without W remains open; latest experimental source has one failing offline test.

**Later correction, same day:** continue from
[the command-type investigation](HANDOFF_20261013_THIRD_PERSON_STEERING_COMMANDS.md).
The third copy is inside a polymorphic command object; the dump's pending state-change command
read the overwritten x at `+0x368` as its animation state. That investigation identified two verified walking command types;
the latest experimental handover is documented in the current resume point above. The regression and proposed next steps below describe the
earlier source, not the current implementation.

Picks up `docs/superpowers/plans/2026-10-13-third-person-pack-core.md` (plan 1 of 2) at Task 13. The
spec is `docs/superpowers/specs/2026-10-13-third-person-pack-design.md`; the per-task record, with
every ruling, is the ledger at `.superpowers/sdd/2026-10-13-third-person-pack-core/progress.md`.
The investigation that produced the prototype is `HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md`.

## 1. Start here: one-man walking is broken in the source

**The last change of the session broke one-man walking.** When the mod plays a regiment's front
man alone, he no longer walks. A held key only fires the position nudge (0.5 m, every 0.5 s for
the first second of a press), so he jumps a few times and stops. The author saw it live: "the
unit is just teleporting, not moving with animations unlike earlier".

The cause is `STEER` in `script/derpy_tp/platform.lua`. It now writes two steering copies,
`+0x1e0/+0x1e8` and `+0x194/+0x198`, and no longer the third, `+0x368/+0x370`. It was cut as the
fix for the 19:14 crash (section 3). The live run proved that **the third copy is the one his
walk follows**. The prototype wrote all three, and it walked.

So the crash fix and the walk need the same field. The next session's first job is to restore the
third copy and make it crash-safe. Section 4 has the options.

**Why the author saw it work earlier:**
- The prototype (`probes/zz_follow_on.lua`) always played a regiment as one man and wrote all
  three copies. It never ran a soldier check.
- The pack's first live load ran with a soldier check that refused every unit (section 2c). Every
  regiment was played whole by move orders, and the author reported "works".
- Once the check was fixed, one-man mode switched on, wrote all three copies, walked, and then
  crashed. Cutting the third copy stopped the walk.

**To play meanwhile:** set the MCT option for one-man play (`combat_one_man`) to off. Regiments
then walk whole by move orders. Single entities such as Yang always walk by orders.

## 2. What passed live, and what was fixed

### 2a. The game's Lua numbers are float32: every exe address read rounded

**Symptom.** The first live load reported build `1791416576` and "GetAsyncKeyState not found in
the import table".

**Cause.** Game Lua numbers are float32, and every RVA in `Warhammer3.exe` is above 2^24. So
`mr.read_int32` of any PE field came back rounded: the stamp 0x6ac6d907 read as 0x6ac6d900.

**Fixed:**
- PE fields and rip displacements are read as two `read_uint16` halves and added straight onto a
  pointer.
- `BUILDS` is keyed by the hex string `"6ac6d907"`.
- `tools/third_person_patterns.py` reads the string key, and it fails a `BUILDS` literal that is
  not exact in float32. All of 9.0's are: `cmd_push` has exactly 24 significant bits.

The pattern route's `search()` had the same rounding: 9.0's displacement to the battle global,
0x157dbc1, rounds to an even number. It is fixed the same way.

Tests: `platform_reads_rvas_above_float32` and `platform_pattern_route_reads_displacements_exactly`.
Both went RED then GREEN; 4 mutants were killed. The memory note
`wh3-lua-is-single-precision-float` now carries the memreader rule.

### 2b. The load and the pattern route

- The live load returned `{"loaded": true, "build": "6ac6d907", "problems": ""}`.
  - Features: `input`, `anim` and `wheel` true.
  - Source: `known build`.
- F2 on the general and on the crossbowmen both worked.
- **The byte-pattern route works live.** `probes/zz_tp_pattern.lua` builds a second platform with
  the build key renamed and leaves the running one alone. It reported `source "byte pattern"`,
  `anim true`, and a 0.02 s search.
- Task 13 Step 4 is therefore done without editing `platform.lua`.

### 2c. The soldier check refused every unit; now fixed

**What was measured** (`probes/zz_tp_men.lua`, `probes/zz_tp_steer.lua`, Cathay army, 9.0):
- **The general's mount is another model class.** Yang on a Longma has model class
  `exe+3ac4908`. Infantry and artillery are `exe+390d4f8`. Both lie in the same read-only data
  section. The check demanded 9.0's one marker, so the general always failed: his swings became
  attack orders, and one-man play was off.
- **Unordered men hold 0, 0.** A man whose unit has never been ordered holds 0, 0 in steering
  copies 1 and 2. The check demanded "within 300 m", so it failed on the gunners and the cannon
  only because they stood about 300 m from the map origin. Near the origin the same zeros would
  have passed.
- **The third copy has a second meaning.** It reads half-set (x, 0) or (0, z), or 2.9e32 on the
  general. Handoff 9j records it as the firing system's aim point as well.

**Fixed (ruling in the ledger).** Any marker inside the exe image passes; `SizeOfImage` is read
from the PE header. The steering copies must lie near their man or be 0, 0. `BUILDS` lost
`model_vt`.

**Live result.** General, crossbowmen and gunners pass. The grand cannon failed once ("the models
centre 9 m from the unit") and passed in the next battle. Artillery is kept out of one-man play
anyway.

Tests: `men_check_accepts_men_never_ordered`, `men_check_accepts_a_lord_on_a_mount`,
`men_check_refuses_a_marker_outside_the_exe` and `men_check_refuses_steering_that_is_not_steering`.
8 mutants were killed.

## 3. The 19:14 crash, traced from its dump

**What the author did.** They walked a crossbowman alone and pressed F2 off. The game crashed
seconds later. Dump: `%APPDATA%\The Creative Assembly\Warhammer3\crash_report\D2026-10-13_T19-14-55.mdmp`.

**The fault.** An access violation on worker thread #5 of 86, at `exe+325c37c`.
- That code is a random-variant pick from a static table: the table pointer is `exe+4375390`, the
  rows are 129 wide with 16-byte entries, and MSVC's `rand` constants pick the variant.
- Its only caller is `exe+3079071`, inside `exe+3078b1c`. That function is a state change: it
  computes a new animation state, stores it at `obj+0x318`, and indexes `table[old][new]`.
- The new state was `0xc21629f4`, which is -37.54 as a float.
- Forty functions call `exe+3078b1c`. The requested state reaches it in `edx`.

**The object.** The dump captures heap memory, so the crashing object can be read from it with
`probes/dump_object.py`. It is an infantry model (vtable `exe+390d4f8`) standing at
(-37.54, 294.83). His x, `0xc21629f4`, sits at nine offsets:
- `+0x88`, his position;
- `+0x1e0`, `+0x194` and `+0x368`, the three steering copies the mod holds every frame (on his own
  spot while no key is held);
- `+0x318`, the bad state, just stored;
- `+0x7f8`, `+0x838`, `+0x858` and `+0x910`, the game's own copies.

**What is established.** The game took a man's x coordinate as his animation state.

**What is not established.** Which field it read the coordinate from.
- **The suspect is `+0x368`.** It is the one written field that is also the firing system's aim
  point. `M.stop` gives a solo regiment its fire-at-will back, and the crash followed F2 off by
  seconds.
- **It is not deterministic.** Four F2-offs in that session, after the check fix went live; the
  fourth crashed.

A static scan of the code for these offsets was too noisy to settle it: other structures share
the same offsets.

**Freezes with no mod code running.** Two earlier "crashes" that day were hangs, not crashes:
- **18:54 freeze, the oversized send.** The 207 KB eval through the bridge (memory
  `wh3-mcp-bridge-large-eval-crashes-game`); Windows logged it as `AppHangB1`.
- **19:02 freeze, cause unknown.** About four minutes after a failed load. No dump, no Windows
  event, no command in flight, and the failed load had registered nothing per frame.

## 4. Next steps

1. **Restore walking without bringing the crash back.** Put `+0x368/+0x370` back in `STEER`. Then
   do one of these, in order of preference:
   - **Hand the field back before fire returns.** When F2 goes off, or the man goes back to his
     regiment, stop writing for a few frames so the formation code rewrites the copies. Give
     fire-at-will back only after that (main.lua `M.stop`, and the survivor path at line ~86).
     This needs the measurement below to know what "rewritten" looks like.
   - **Write the third copy only while a key is held.** When he stands still, write copies 1 and 2
     only. Check live that he still holds his spot when idle; the handoff says an idle man
     ignores the point.
   - Keep the test `steering_leaves_the_aim_point_alone` in step with whichever is chosen. It
     currently pins the two-copy version and must be rewritten, not deleted.
2. **Measure before fixing.** Read `+0x360..+0x380` and `+0x7f8/+0x838/+0x858/+0x910` on one
   crossbowman in four states:
   - idle and never ordered;
   - walking under a regiment order;
   - firing;
   - the first frames after F2 off with three-copy writes.

   `zz_tp_steer.lua` is the starting point.
3. **Reproduce before calling it fixed.** Three copies, a crossbowman walked alone, an enemy in
   range, F2 off; repeat. Before this session's fix it crashed on the fourth F2 off. A fix with no
   reproduction behind it is a guess.
4. **Finish Task 13.**
   - Step 3: read `zz_tp_read.lua` with the mod **on**. The plan expects:
     - general: `men=true`, `one_man` false;
     - crossbowmen: `one_man`, `solo` and `men_ok` all true.

     The general's `one_man` is false by design: `front_man` needs two models.
   - Step 5: record in handoff `HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md` as a new §9l. This
     file can be its source.
5. **Tasks 14-16** are not started:
   - Task 14: one man's shot in play.
   - Task 15: the remaining live measurements.
   - Task 16: pack through RPFM, deploy, the live table, docs.

   The pack has never been built. Nothing is deployed: everything so far went through the bridge.
6. **Flying units** were asked about and are untested. Aiming takes the ground plane at the
   shooter's height, so a flyer in the air aims short. The camera may not follow altitude.
   Forced swings in the air are unknown. CA has no scripted fly/land order. Add a lord on a
   flying mount and a flying regiment to Task 16's live table.

## 5. How to work on it

**The bridge.** `py tools/build_third_person.py --bridge` writes `probes/zz_tp_load_01..12.lua`
and `zz_tp_load_run.lua`. Send each part with `py send.py <file> 20`, then the run file. Each part
is at most 20 KB; never send one big eval.
- A reload stops the old copy first.
- Read state with `zz_tp_read.lua`, the soldier check per unit with `zz_tp_men.lua`, and raw
  steering with `zz_tp_steer.lua`.
- A battle restart needs the parts sent again.

**Tests.** `py tools/build_third_person.py --selftest` runs 81 Lua tests, plus luac, the API
checkers and the patterns tool. It must exit 0.

**Mutation.** `py probes/tp_mutate.py probes/mutants/<set>.py` applies each mutant, runs its one
test, and restores the file byte for byte. The sets from this plan are kept in `probes/mutants/`.
After code moves, some anchors go stale. A stale anchor is a finding, not a skip.

**Crash forensics, in order:**
1. `py tools/read_minidump.py "<dump>"` gives the fault and its `exe+offset`.
2. `py probes/dump_stackscan.py "<dump>"` gives the registers and which thread faulted.
3. `py probes/dump_object.py "<dump>" <hex addr> <hex len> [hex needle]` gives the object behind
   a register: the offsets the mod writes, plus every place a value occurs.
4. Use `capstone` (installed) on the exe's code section (RVA 0x1000) to disassemble the fault and
   its callers.
5. With no dump, run `Get-WinEvent` on the Application log: a hang shows as `AppHangB1`.

The script log's clock starts at game launch. It is unbuffered, so its last line is the last
script output before a crash.

## 6. Rulings this session (also in the ledger)

- `BUILDS` is keyed by a string, not a number: a number key rounds in game.
- `third_person_patterns.py` fails a `BUILDS` literal that is not exact in float32.
- `check_men` accepts any marker inside the exe image, and steering copies that are near their man
  or 0, 0. The spec's "9.0's marker" assumed one model class; two were measured.
- The grand cannon's 9 m centre is not loosened: artillery is out of one-man play anyway.
- `STEER` dropped the third copy. **Wrong:** it stops the walk (section 1). To be reversed under
  section 4.

Deferred minors from the final review are unchanged and listed in the ledger.
