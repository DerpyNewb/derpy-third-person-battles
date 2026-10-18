# Battle engine internals - reverse-engineered, build 6acec6f4

What `Warhammer3.exe` does with one battle soldier (a "man", a model): his fields, his virtual methods, his
command, his two action slots, and the per-tick gate that decided whether a clicked swing ever played. Also the
three tools that found it, and how to use them on the next question. Every address is an RVA, written `exe+RVA`;
the image base is `0x140000000`. Everything here was read on **build 6acec6f4** (the 2026-10-16 patch) and is
marked **live** where a probe in the running game confirmed it, **code** where it is read from the
disassembly only.

The code that uses these facts is `Modding Files/source/third_person/script/derpy_tp/platform.lua`, the only
file in the third-person pack holding an address. The session record is
`docs/sessions/HANDOFF_20261016_THIRD_PERSON_MOUNTS_AND_DEATH.md`, the last section.

## 1. The tools, and which question each answers

| Question | Tool | Cost |
|---|---|---|
| Who calls this function / loads this address? | `py tools/exe_re.py refs <rva>` | seconds |
| What is in this vtable? | `py tools/exe_re.py q <rva> [n]` | instant |
| Which vtable slot holds this function? | `py tools/exe_re.py ptrs <rva>` | seconds |
| Who calls the virtual at slot `+disp`? | `py tools/exe_re.py slotcalls <disp>` | seconds |
| Who writes a constant into field `+disp`, and which constant? | `py tools/exe_re.py stores <disp>` | seconds |
| Which subclass vtable is this pointer in, at which slot? | `py tools/exe_re.py vtmatch <known_vt> <rva>` | seconds |
| What does this function do? (assembly) | `py tools/exe_re.py dis <rva> [n]` / `fn <rva>` | instant |
| What does this function do? (C) | `py tools/ghidra_decompile.py <rva> [...]` | ~8 s per call |
| Is it what the game does right now? | memreader Plus probe over the wh3 bridge (section 9) | a battle |

`exe_re.py` reads the exe **on disk** with capstone and numpy, read-only, with the game shut or running. The
on-disk code is byte-identical to the live code (checked 2026-10-16), so it is the safe way to ask. `--selftest`
checks each command against a fact of this build. Two traps it works around:

- **The section names are disguised.** The code is in `.udata` at RVA 0x1000 (0x33a6000 bytes), the vtables are
  in `.xcode`, and `.text` is a 0x200-byte stub. A tool that trusts `.text` finds nothing. `exe_re.py` takes the
  section that holds a known function.
- **There is no RTTI.** Vtables run into each other with no complete-object-locator between them, so "scan back to
  where the vtable starts" is a guess. `vtmatch` aligns the region against a vtable whose base you know instead: a
  subclass keeps most of its base class's entries at the same index. That is how slot `0x4a8` was found (section 4).

The analysis behind this document was done with `exe_re.py` (then a scratchpad script) and live reads. **Ghidra
was set up afterwards** (section 10) and its decompile of the same five functions agrees with every line of the
reading below. Ghidra gives C, so use it to read a function's logic. For "who calls / who writes / which slot",
`exe_re.py` answers in seconds with no project.

## 2. Worked example: from "the swing never plays" to the one byte

Each step is one command, and each answer is the next step's input.

1. **Find who installs the forced clip.** The forced-clip command's vtable is `exe+3911fb0` (known). `refs 3911fb0`
   finds exactly one write: inside `exe+306e850`. Its disassembly destroys the man's command (`+0x328`), constructs
   a new one at `+0x330`, writes vtable `3911fb0` and copies a 16-byte payload to `+0x368`.
2. **Find who calls that.** `refs 306e850` finds only `exe+311bd24`, and `ptrs 311bd24` finds it stored at
   `exe+3915ec8`: a vtable slot, so it is called virtually.
3. **Which slot?** `vtmatch 3912950 3915ec8` (3912950 is an infantry man's vtable, read live) gives the subclass
   vtable `exe+3915a20` and slot 149, `+0x4a8`. The base class holds `306e850` itself at that slot.
4. **Who calls slot 0x4a8?** `slotcalls 4a8` finds three sites. The battle one, `exe+2f7809a`, is in
   `exe+2f7805c`: it builds the payload from its own object's `+0x40` and calls the man's `+0x4a8`.
5. **What object is that?** `ptrs 2f7805c` gives slot 1 of vtable `exe+390c0b8`, and `refs 390c0b8` finds its
   constructor `exe+2f641b8`. That constructor has two callers. One is `exe+2ecf4dc`, the command-stream reader for
   the pack's play command (tag 0x28). It builds this object in the man's `+0x5c8` slot. **So the play command does
   not start a clip: it parks an action.**
6. **Who runs parked actions?** Searching the battle code for instructions that test `+0x6f8` (the slot's "has"
   byte) led to the runner `exe+3088218`. `refs 3088218` gives the man's action update `exe+3075e7c`, and
   `refs 3075e7c` its regular caller, the gate in `exe+3086f04`.
7. **What does the gate test?** `+0x324`. `stores 324` lists every writer with its value. They are all
   command-start routines, one code each, so `+0x324` is the kind of order he got **this tick** (section 7).
8. **Live**, per frame (section 9): every failed swing sat parked and never started, while `+0x324` flipped 1/0
   tick by tick. The fix is the gate's one branch byte (section 8).

## 3. The man: field map

Offsets on the model object (the man; for a rider, his mount is a model too, at `+0x2e0`).

| Offset | What | Source |
|---|---|---|
| `+0x0` | vtable: `exe+3912950` an infantry man; `exe+3915a20` a subclass with children (overrides `+0x4a8`) | live / code |
| `+0x58` | -> object whose `+0x440` is the battle; the battle's `+0x98` is the tick count | code |
| `+0x88` / `+0x8c` / `+0x90` | position x, y, z (float) | live |
| `+0xb0` | facing, u16 (0x10000 = full turn) | live |
| `+0x108` | flags: bit 0x10 reaches the command/action path, bit 8 and bit 4 take other branches (read 0x33 in melee) | live / code |
| `+0x128` | an object whose `+0x78` check also sends him to the gate (null in every melee frame measured) | live |
| `+0x194/+0x198`, `+0x1e0/+0x1e8` | steering point copies x, z | live |
| `+0x278` | current animation slot, u16; valid while `+0x898` is set or `+0x284` is not 0 | live |
| `+0x2e0` | mount parent (rider -> horse); null on foot | live |
| `+0x2e8` | his unit | live |
| `+0x308` | animation fragment: u16 clip index per slot from `+0x50`, `0xffff` none, shared per regiment and skeleton | live |
| `+0x324` | **the kind of order issued to him this tick** (section 7); `3075e7c` zeroes it | live / code |
| `+0x328` | command holder; the command object itself is embedded at `+0x330` | live |
| `+0x330` | the command's vtable (section 5) | live |
| `+0x368..` | the command's payload: a walk's target x/z (`+0x368/+0x370`), run flag `+0x390`, speed `+0x394`; a forced clip's 16-byte clip payload | live |
| `+0x490` | **running** action holder: action object `+0x4a8`, its done byte `+0x4c8`, has `+0x5c0`, started `+0x5c1` | live |
| `+0x5c8` | **queued** action holder: action object `+0x5e0`, its done byte `+0x600`, has `+0x6f8`, started `+0x6f9` | live |
| `+0x884` | the tick his wait ends (compared with the battle's `+0x98`) | live |
| `+0x88a` | read 1 in every melee frame; non-zero sends the action update straight to the runner | live / code |
| `+0x898` | with `+0x284`, whether `+0x278` holds a clip (`P.anim_slot`: neither set, no clip) | live |
| `+0xb18` / `+0xb1c` | hit points max / current, int32 | live |
| `+0xb20` | when set, the update calls his virtual `+0x490` instead of the command/action path | code |
| `+0xb64` / `+0xb68` | child count / array (the subclass's `+0x4a8` repeats the clip on them) | code |

## 4. The man's virtual methods

Slot offsets into the vtable at `+0x0`, for vtable `3912950`.

| Slot | Function | What |
|---|---|---|
| `+0x18` | `exe+3086f04` | **main update**, once per tick; holds the gate (section 7) |
| `+0x490` | `exe+30915a8` | the update's other branch, taken when `+0xb20` is set |
| `+0x4a0` | `exe+30751e4` | "an action was posted": notifies `+0xb20`, sets `+0x8b0` = 2, clears order kind 0x13 |
| `+0x4a8` | `exe+306e850` | **start a forced clip**: replace his command with `3911fb0` carrying the 16-byte payload |
| `+0x4b0` | `exe+306e89c` | **issue an order** (section 7): sets order kind 1 |
| `+0x4b8` | `exe+306e9a0` | installs a command and sets order kind 0x13 |

`exe+311bd24` is the subclass's `+0x4a8`: `306e850`, then for each child at `+0xb64/+0xb68` either the same
start or command `3918e90`, chosen by its fragment's `+0x127c` bit 2.

## 5. Commands at `+0x330`

| Vtable | Command | Notes |
|---|---|---|
| `3911fb0` | forced clip | installed by `306e850`; **no order arrives while it runs** (live) |
| `3ae2400` | his own walk | built by `walk_start` `exe+306f954`; speed from `exe+303b744` |
| `3919350` | the regiment's walk | the pack's guard stops it |
| `39199f8`, `3ae1928` | the engine's moves | guard stops |
| `3ad24b8` | the engine's melee attack | guard stops |
| `3ad2d18` | the engine's charge | measured 2026-10-18 (`probes/zz_tp_charge_gait.lua`, Harald on CA's `attack_unit` from 45 m): his own walk for 0.4 s, then this for 5.4 s at 4.0 m/s against his run's 3.3, **no forced clip on him** (the charge cycle is his locomotion and loops), then MOVING_ATTACK_2 (485) at contact. The walk's gait byte `+0x3ae` stayed 0 throughout. The pack's sprint fakes it with the CHARGE clip (135), 0.8 s and not looping on Harald, re-sent every 0.6 s |
| `39126f0` | stand in his state | what `walk_stop` `exe+306edd4` leaves |
| `3919b28` | idle | |
| `3ae2de8` | defend (block) | order kind 18 under it, measured |
| `3ae2a08`, `3912820`, `3ae2b38` | fight states | kind 14 under `3ae2b38`, measured |

## 6. Actions: the two slots, the runner, the play command

An **action** is a script-like unit of work the man carries beside his command. He has two holders, running
(`+0x490`) and queued (`+0x5c8`), with the same layout:

| Holder offset | What |
|---|---|
| `+0x0` | holder vtable `exe+3917f80`; slot 0 `exe+32613f4` is **reset**: started = 0 and the action's done = 0 |
| `+0x8` | the man |
| `+0x10` | handed to `exe+2db5a20`, the routine that destroys a command, on start when `+0x132` is 1: by that use, his command holder (code only) |
| `+0x18` | the action object (vtable: slot 0 destructor, 1 **start**, 2 **update**; `+0x80` "blocks orders"; `+0x20` done; `+0x24` ticks run) |
| `+0x130` | has an action |
| `+0x131` | started |
| `+0x132` | destroy his command when it starts |
| `+0x133` | clear the holder when it is done |

**The runner**, `exe+3088218(holder)`, does nothing without an action. Otherwise, while the action is not done:
on its first run it destroys his command if `+0x132` asks (`exe+2db5a20`), zeroes the tick count, calls the
action's start (slot 1) and marks it started; then it calls the update (slot 2) and counts the tick. Once the
action is done it clears the holder if `+0x133` asks (`exe+2db5ac4`).

**The play command** (tag 0x28 in the deterministic command stream; reader `exe+2ecf4dc`; what `P.play` pushes):
it reads the man, the slot (u16), the mask (u32) and one byte, then builds a **clip action** (vtable `exe+390c0b8`,
constructor `exe+2f641b8`, base constructor `exe+3250f9c`) in the **queued** holder. For a rider
(`exe+306e490` true and `+0x2e0` set) it goes on the mount's holder with the rider flag 1. Its 16-byte payload at
`action+0x40`, which its start (`exe+2f7805c`) passes to the man's `+0x4a8`:

| Payload offset | What |
|---|---|
| `+0x0` | u16 animation slot |
| `+0x4` | u32 `0x81` (constant from the reader; meaning not traced) |
| `+0x8` | u32 body mask (the pack sends 0, or 6 to hold a full-body clip that has no event metadata) |
| `+0xc` | u8, the stream's byte (the pack sends 0) |
| `+0xd` | u8 rider flag |
| `+0xe` | u8 0 |

Other command-stream readers beside it (`exe+2ecf644` and its neighbours) park their actions in the same queued
holder, so they meet the same gate.

## 7. The man's update and the gate

`exe+3086f04`, the branch a fighting man takes (`+0x108` bit 0x10 set, bits 8 and 4 clear, `+0xb20` null), goes
one of two ways each tick:

- **His action update**, `exe+3075e7c`, which runs a queued action first. He gets it when no order reached him
  this tick (`+0x324` is 0, and `+0x128` is null or passes its `+0x78` check), or when **nothing is parked**
  (queued has is not 1, or its done is 1: the bytes at `exe+3087378 .. exe+3087388`, **the gate**) and a running
  action says it blocks orders (its `+0x80`).
- **The reset**, `exe+306d1ac`, which resets parked actions and runs his command. He gets it otherwise, and also
  whenever the order kind is 4, 0xc-0x12, 0x14 or 0x15.

So a parked action plus any order that tick means the reset. (The decompiled C of both functions is kept in a
local file, `BATTLE_ENGINE_RE_DECOMPILED.md`, and is not published.)

`+0x324`, `order_kind`, is written by each command-start routine (`exe_re.py stores 324` lists them):

| Kind | Writer | What |
|---|---|---|
| 1 | `306e89c` (`+0x4b0`, issue an order), `3070660` | an order of kind 0 reached him |
| 3 | `3084b2c` (vtable slot `+0x158`) | |
| 4 | `306f0d8` | |
| 5, 7 | `3075e7c` itself | |
| 12, 19 | `306ebd4` | |
| 13 | `306fea0` | |
| 14 | `306f1a0` | measured under fight state `3ae2b38` |
| 15, 16, 20 | `306f37c` | |
| 17 | `306ed94` | |
| 18 | `306edf8` | **the stop that `walk_stop` calls**; measured under defend `3ae2de8` |
| 19 | `306e89c`'s neighbour `306e9a0` (`+0x4b8`) | |
| 21 | `324e7e4` | |

`306e89c`, the order issuer, returns without ordering when a **running** action's `+0x80` says it blocks orders,
and it only replaces his command when the order differs from it. Either way it sets kind 1. In a melee his regiment
orders him **every tick**, so with a swing parked in the queued holder the update took the reset branch every
tick, and the swing never started. While his own forced clip plays, no order comes, which is why a swing sent
inside the previous swing always started in 200 ms. **Live** (`probes/zz_tp_melee_spam.lua`, ordered per-frame
timeline): every failed swing read "has, not started" (`c00`) for its whole 2 s. `+0x324` flipped 1/0 tick by
tick under stand, read 18 under defend and 14 under fight state `3ae2b38`. The one time the engine did start it
(`c10`), the next tick's order reset it.

## 8. The fix: one branch byte

At `exe+3087388` is `75 5c`: jne to `exe+30873e6`, the reset. Changing it to `75 52` sends a man with a parked
action to `exe+30873dc`, `call exe+3075e7c`, his action update, which starts it. The bytes checked first are
`exe+3087378`, 18 bytes: `44 38 bf f8 06 00 00 75 09 44 38 bf 00 06 00 00 75 5c`.

`platform.lua` `P.gate(on)` writes it with memreader Plus `mr.patch(address, expected, bytes)`, which writes only
when the bytes there are the expected ones, and answers the same when they already are the new ones. `main.lua`
puts it in while a man is played alone and takes it out at the stop. The platform takes it out as it loads, in
case a battle was left mid-control. A build without the `queued_gate` row gets no patch and one log line.

Result, live (Teutogen Guard under two Clanrat units, a click every 2.4 s): 4 and 0 of 10 swings started before;
10, 10 and 10 with it, in 200-400 ms; the same code with only the patch stubbed out, 10, 7 and 9 with waits to
1.8 s. Shots, the horse's run speed and the no-auto-attack fragment were re-measured with it in and are unchanged.

**A unit of one needs it too** (2026-10-18, `probes/zz_tp_one_timeline.lua`, the Mutalith, a jump then a click every
0.4 s for 8 s, in melee with two Skaven units). Ungated, against Skavenslaves: the engine's melee order came back every
tick and the guard stopped it (`melee` / stand alternating, `+0x324` = 1 on 234 frames), and the jump and four swings
all read `c00` for 11 s, none started. With the gate in: 6 of 6, then 4 of 4 and 5 of 5 against Stormvermin, each 0.2 s
after its send. **One gated run stalled**: right after a fresh engage, 7.4 s of stand (`39126f0`) with `+0x324` stuck
at 1 and the queued action `c00`, until the engine's next melee order, when the parked swing started. `+0xb20` was
not read in that run; set, it sends his update to vtable `+0x490` and past the gate. Not reproduced in two retries.

**Ceiling:** while it is in, a parked action on **any** man beats that tick's order, not only his. In a battle the
pack plays, only `P.play` parks one. A per-man version needs a code cave (memreader `code_cave`) comparing the man
with a stored pointer. Caves cannot be removed for the session, which is why the one-byte version shipped. Since
2026-10-17 the mailbox (section 9) is such a cave at the top of the same update, with the man played in its block.

## 9. Threads, and measuring it live

**The battle runs on worker threads** (fiber jobs), at the same time as the script thread. Evidence: a crash
dump's faulting thread (index 7 of 91, `exe+305B39A`, a fiber job) while the script thread kept answering the
bridge; and a guard that read `stand` at `+0x330` while its own second read, microseconds later, found an engine
command. So:

- **Do not destroy or build engine objects from Lua.** `walk_stop` / `walk_start` from the script did, and it
  crashed (exe+7AB1DA and exe+305B39A in play). Reproduced on 2026-10-17: the stop from the script on every man of a
  171-man regiment in melee, every 30 ms, crashed in 3 s (`exe+305FA54`, a man pointer of `0xc` in code comparing two
  models' units). Calling `306e850` from Lua would be the same mistake.
- **memreader Plus Lua hooks never run on other threads** (its README: "Other threads never reach links"; calls from
  other threads run the original). A Lua hook on a battle function therefore sees only script-thread calls.
- **A code byte is executed by whichever thread reaches it.** A patch moves the decision onto the battle thread with
  nothing to race. Caves likewise, but they stay for the session.

**The mailbox** (2026-10-17, the fix): a memreader Plus code cave (`p:cave`) at the top of a man's update
`exe+3086f04`. It makes the stop, the walk builder and the in-place walk writes for the one man played, on the
battle thread inside his own update, where the engine changes his command itself. The script posts requests
into a `game_alloc` block. The cave's bytes run first, then a copy of the 7 bytes its jump displaced
(`mov rax, rsp; mov [rax+0x10], rbx`), then back into the game. At that entry rax and the flags are dead, so the
fast path (not him) touches nothing else. On his path the cave saves rcx/rdx/r8/r9 and xmm0-3 and calls with rsp
16-aligned.

A cave cannot be removed, and a second one at an address is refused. `p:cave` with the same name and bytes
answers the existing cave, so a later battle reads its block pointer back out of the cave's first instruction
(`hook_info(site).cave`, offset 2) and asks again with identical bytes.

Every model class's update reaches `3086f04`: the subclass `312de40` calls it first, and so do seven other
updates. Measured on a horse. `tools/third_person_cave.py` assembles the cave with keystone and runs the shipped
bytes under unicorn: every path, register and stack alignment, plus 8 broken variants. Live, 795 stops with no
fault (session handoff 2026-10-17 section 10).

**Recipes that made the measurement work** (all in `Modding Files/source/lord_control/probes/`, test scaffolding):

- **An ordered timeline, not counts.** Per frame, the state you suspect (`+0x6f8/+0x6f9/+0x600`, `+0x324`, the
  command vtable, the clip), appended only when it changes. A count of frames per state hid that the action had
  been started and then reset.
- **The hard case.** Clicks every 0.25 s land inside the previous swing and always work. Spaced at 2.4 s
  (`PERIOD=2.4 DURATION=24 sh ms_ab.sh <tag> <modes...>`), each lands under the engine's orders.
- **Make the test last.** `zz_tp_freeze.lua` (the author's idea): every unit invincible, fearless and holding fire,
  every enemy unit halted under a script controller. `zz_tp_engage.lua` then sets two enemy units on the subject.
- **A control in the same battle.** A probe mode that stubs only the change (`nogate` stubs `P.gate`), alternated
  with the shipped path.
- **Test source before building.** `py tools/build_third_person.py --bridge <unit types>` writes `zz_tp_load_NN.lua`
  parts; sent in order with `send.py`, then `zz_tp_load_run.lua`, they load the source into the running battle. A
  battle restart (`q_restart.lua`, then `x1_start.lua` once in deployment) goes back to the deployed pack.
- **Keep the clock honest.** A battle can be left in slow motion; `zz_speed.lua` with `_G.TP_SPEED = 1` puts it
  back. The pack switches off at the battle's Complete phase, so a long test needs a restart.
- One bridge command at a time; one Lua error in an eval wedges the bridge, so every probe runs in `pcall`.

## 10. Ghidra: setup and use

Ghidra 12.1.4 is in `C:\tools\ghidra_12.1.4_PUBLIC`, with Temurin JDK 21 in `C:\tools\jdk-21`. REA's Ghidra
provider is blocked in REA 6.5.0 (`tools/external/README.md`); Ghidra itself works headless without it.

```powershell
py tools\ghidra_decompile.py --import          # once per game build: 56 s, a 333 MB project in ghidra_cache\
py tools\ghidra_decompile.py 3086f04 3088218   # C for the function holding each RVA, ~8 s
py tools\ghidra_decompile.py --selftest        # walk_stop decompiles and names its callee
```

How it works and why:

- **Imported with `-noanalysis`.** Auto-analysis of 54 MB of code would take hours, and one function's decompile
  does its own local analysis. `tools/ghidra/DecompileAt.java` disassembles at each RVA, makes a function there if
  none holds it, and decompiles it. Callees print as `FUN_14xxxxxxx` (the VA; subtract `0x140000000` for the RVA).
- **Opened `-readOnly`**, so what a run creates is not saved, and runs never conflict.
- **Three setup traps:** Ghidra refuses a project path with any element starting with `.` (hence `ghidra_cache`,
  not `.ghidra_cache`); it needs `JAVA_HOME`; `analyzeHeadless.bat` waits for a key after an error, so the wrapper
  closes stdin.
- **Reading its output:** a struct pointer typed `longlong *` indexes in qwords (`param_1[0xdf]` is `+0x6f8`); a
  virtual call prints as `(**(code **)(*plVar + 0x80))()`, the slot offset in plain sight; a byte flag compares
  with `'\x01'`. Rename nothing in the project (it is read-only); carry names in this document instead.
- **The GUI** (`ghidraRun.bat`, open `ghidra_cache\wh3_6acec6f4.gpr`) is for browsing around one function. Analyse
  a selection, never the whole program.
- **After a game patch** the project is for the old exe: re-run `--import` (it overwrites), and rename
  `PROJECT` in the wrapper to the new build.

## 11. After a game patch

1. `py tools/third_person_patterns.py` prints the new build stamp and the play command's fields.
2. Find the gate again: search the code for the 18 bytes in section 8. A patch can move them, and the `75 5c`
   displacement can change too. If the bytes are gone, `refs <action update>` on the new build finds the update's
   caller, and its two `cmp byte ptr [rdi+...]` lines are the queued holder's has/done bytes.
3. Re-check the fields in section 3 with a live probe before shipping. `P.gate` refuses on an unknown build, and
   does nothing when the bytes differ.
4. The mailbox: `py tools/third_person_cave.py --check` fails when his update moved or starts differently. The
   update is slot `+0x18` of the infantry man's vtable (`exe_re.py q <vtable+0x18> 1`). Set `SITE_RVA` and
   `SITE_BYTES` (the cave needs 5+ bytes of whole instructions, no jump or rip-relative operand among them) and
   the build row's `update`, re-check the field offsets in `MAN`, then `py tools/third_person_cave.py` and
   `--selftest`. Without a known update the pack plays regiments whole.

## 12. Open

- Which formation routine issues him an order every melee tick (the caller of `+0x4b0`): not traced. Not needed
  for the fix.
- The `0x81` in the clip payload.
- A per-man gate. The mailbox's cave (section 9) already knows the man played, so the gate's decision could move
  into it.
- The post-fire `nil` then `1557` frame after a shot.
- Which installer puts each engine command on him: the melee attack `3ad24b8` is built in the order issuer
  `306e89c` (constructor `3053684`), the regiment walk `3919350` and move `3ae1928` in `324e9dc` (from `306fea0`),
  move `39199f8` in `324e2c8` (five callers). Refusing them at the source would need a cave at each.
