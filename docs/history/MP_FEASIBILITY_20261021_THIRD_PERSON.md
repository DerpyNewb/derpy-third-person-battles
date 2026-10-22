# Third person in multiplayer: feasibility record, build 6acec6f4

**As built (2026-10-21, read this first).** The provisional verdict below, a carrier on the play command with
`CARRIER_SLOT` and `READER_HOOK`, was withdrawn by Rulings 5 and 6: the play command keeps only 11 bits besides its
slot on the wire, and Task 1b found CA's own per-man overrides on the same queue. What was built instead: steer is a
forged MOVE, hold a HALT, a standing turn CA's FOLLOW_FIRST_PERSON, a clip the play command as before, and the guard,
disarm and arm a 32-bit carrier word in a forged RELOAD_TIME, read on every machine by a cave at `exe+2ecfcb7` that
keeps a 16-entry guard table and points men at a fragment copy table built at "Deployed". A HELLO carrier from every
human army's machine gates it all (Rulings 25 and 26), and none is sent until a player presses F2: the order gate goes
in on every machine once the last one lands (one tick everywhere is inferred) and stays to the battle's end, and play
waits for it. Nothing writes a man's fields outside the queue. It is tested
offline only (the caves under an emulator, the sending rules in a two-machine simulation); no two machines have run it,
and nothing is
uploaded until checklist items 10 and 12 are answered (Ruling 15). The format, the caves and the sending rules are
`docs/BATTLE_ENGINE_RE.md` section 13, "As built (2026-10-21)"; the decisions are "Rulings" and the session's
measurements "Live session checklist", both at the end of this record. The sections between are the historical record
and are not rewritten.

2026-10-21. Task 1 of `docs/superpowers/plans/2026-10-21-third-person-multiplayer.md`. Static only: the exe on disk,
`tools/exe_re.py`, `tools/ghidra_decompile.py` and the slot data of every animation bin installed here. No game was
run. Each row below names the functions its answer was read from and says how sure it is; "read" means the
decompiled or disassembled code says so, "inferred" means it follows from the code read but one link was not
followed. The engine half, with the registry, the wire format and the tick path, is `docs/BATTLE_ENGINE_RE.md`
section 13.

*Historical: the next two paragraphs, "Static" and "What this changes for the plan" are Task 1 as written, before Task
1b and Task 2. Their play-command carrier, `CARRIER_SLOT` and `READER_HOOK` were withdrawn by Rulings 5 and 6. What they
hand to Task 2 is answered under "Replay" ("Reads"); what they hand to Task 3 is on the live checklist (items 1, 2, 3
and 12). Kept unchanged.*

**Provisional verdict: a route exists, and the play command is already on it.** `cmd_push` (`exe+2e9b974`) only
writes into the battle's local command buffer, but that buffer is the one the tick manager hands on every frame
(`exe+2d7b4a8`), and in multiplayer the tick manager is EMPIRE_MP's (traced to one link, see the Q1 row; Task 3's
two-machine run confirms it): its submit (`exe+21d7290`) copies the buffer into
the outgoing tick data that `submit_tick_data` (`exe+21d9280`) sends as network message `0xa2`/`0xa1`, and its
`p_get_tick` (`exe+21c8188`) decodes those messages from every player into the tick bundle that every machine runs.
**But the plan's wire format does not survive that route.** The play command is serialized as version 1: the slot
travels as its *name*, the byte as a raw byte, and the mask as one of eight *names*. The vanilla reader then
collapses the byte to a bool before anything after it sees it. So a carrier carries 8 bits (byte) and 3 bits (mask)
besides its slot if the cave reads the raw byte out of the record, and only 1 + 3 at `READER_HOOK` as placed now;
never a u32. Task 4's encoding has to be redesigned before Task 5 builds on it (see "What this changes" below).

**Task 2 must confirm** that `CARRIER_SLOT` reads `0xffff` in every fragment of an all-races battle, and what the
gate byte `+0x3b1` is. **Task 3 must confirm** that a play command pushed on A is executed on B, the delay in ticks,
that the gates `+0x3b0` / `+0x3b1` are 0 on a non-host player (else `P.play` refuses there), and what a vanilla B
does with a carrier.

## Static

| Q | Answer | Confidence |
|---|---|---|
| Q1 `cmd_push` | `exe+2e9b974` only serializes into the battle's local queue (battle `+0x644e8`, vtable `exe+3904438`, a 0x5000-byte buffer at `+0x8`, length at `+0x5008`): header from `exe+1bca278` (u16 length, the type id from global `exe+406cc98`, a version byte from the registry entry), then the command's own serializer (its vtable slot 0, `exe+2eecc50` for the play command). There is no separate wire serializer: the buffer's bytes are what is sent, and the send happens downstream, once per frame, in `exe+2d7b4a8` -> tick manager slot `+0x10` -> EMPIRE_MP `exe+21d7290` -> `exe+21a3a9c` -> `exe+21d9280`. Which tick manager `exe+2d7b4a8` holds (its `+0x28`) is set by the factory `exe+2db833c` through the base constructor `exe+2d1735c`: not a replay and the battle's `+0x645c8` null (single player) gives a new local tick manager (`exe+1b9c678`, vtable `exe+3a2e0c0`); `+0x645c8` set (`battle:is_multiplayer()`) gives `[battle+0x645c8] + 0x140`, and EMPIRE_MP's constructor `exe+2196d24` writes vtable `exe+3a5c888` (slot 0 `p_get_tick`, slot `+0x10` `exe+21d7290`) at its own `+0x140`. The one link not followed: that `+0x645c8`, a battle constructor argument (`exe+2d98420`), holds that EMPIRE_MP object. | read, last link inferred; Task 3 confirms |
| Q2 player's move | A right-click move is `BCQ_MULTIPLE_SELECTION_ORDER_MOVE` (type global `exe+406c8bc`, handler `exe+2ed22b4`), pushed by `exe+1cae60c`, a function of the same shape as `cmd_push` into the same queue; the UI reaches it from `exe+1cf8d04`, script `goto_location` through `exe+2ed8a10`. It is not a different send: **SEND is `cmd_push` (`exe+2e9b974`) itself**. | read |
| Q3 sender check | None found. The executor `exe+2f041c0` hands each handler only the record and the battle (`+0x440`), never which player's buffer it came from (`exe+2dd3910` loops the bundle's buffers without passing the index), the play handler `exe+2ecf4dc` checks only a read error and a non-null model, and the network decode `exe+21aff1c` appends the bytes unread. A host-side check before relaying was not traced. | read (executor, handler, decode); host relay not traced |
| Q4 slot with no clip | The reader never consults the fragment: it parks the clip action regardless. When it starts, the man's `+0x4a8` (`exe+306e850`) **destroys his current command** and installs the forced-clip command (`exe+3911fb0`), whose play (`exe+3081c28` -> `exe+3081d40` / `exe+30835f4`) asks `exe+14828c0` (slot below 2260 and fragment `+0x50 + 2*slot` not `0xffff`) and plays nothing; its update `exe+308779c` then ends it, or, when the byte is exactly 1 (loop), retries it every tick, so he holds a clipless command until something replaces it. **CARRIER_SLOT candidates** (named, below 2260, bound by none of the 1,899 bins of CA's anim packs and the installed mods): **2123 `RIDER_TESTUDO`**, then 2126 `RIDER_TESTUDO_IDLE_1`, then 2127 `RIDER_TESTUDO_IDLE_2`. **READER_HOOK** `exe+2ecf58f`, 7 bytes `48 8B 5D 38 48 85 DB` (`mov rbx,[rbp+0x38]; test rbx,rbx`), resuming at the `je` at `exe+2ecf596`: the first place where the model pointer (`[rbp+0x38]`), slot (`edi`), byte (`[rbp+0x20]`, already collapsed to 0/1) and mask (`esi`) are all decoded and the read-error byte checked. **The raw byte** is gone from the stack by then (`exe+2ecf55d` calls `exe+1b9fc58`, which stores `byte != 0`) but not from the record: the record (`rbx` until `exe+2ecf58f`) keeps its buffer pointer at `+0x10` and its read cursor at `+0x20`, and the byte field is a tag byte `1` then the value. A hook at `exe+2ecf556` (7 bytes `48 8D 55 20 48 8B CB`, before the call) finds the raw byte at `[rbx+0x10] + [rbx+0x20] + 1`; one at `exe+2ecf562` (8 bytes `83 65 F0 00 83 65 F4 00`, right after it, mask not yet read) at `[rbx+0x10] + [rbx+0x20] - 1`. Neither range holds a jump or a rip-relative operand. At `exe+2ecf58f` the mask's name has moved the cursor by a variable length, so the byte's place is no longer known there: a design that wants all 11 bits needs a hook at one of these two sites, alone or beside `exe+2ecf58f`. | read; candidates from bin data, Task 2 measures |
| Q5 model time | `bm:time_elapsed_ms()` (`exe+2f17fb8`) returns the u32 at `[exe+4480da0] + 0x4a4`. It is written each tick by `exe+2f17df0` (called from the tick step at `exe+2dd3613`) as the battle's tick count (the u32 at `[[[exe+4480da0]+0x468]+0x440]+0x98`) times the u32 tick length at `exe+3d0e294` (100 on disk). **MODEL_CLOCK**: `[exe+4480da0] + 0x4a4`, or from inside a man's update his own `+0x58` -> `+0x440` -> `+0x98` times `[exe+3d0e294]`. | read |
| Q6 `halt` | `exe+2ee7a5c` -> `exe+1bc31b0`, `BCQ_MULTIPLE_SELECTION_ORDER_HALT`: queued. | read |
| Q6 `goto_location` | `exe+2ee7818` -> `exe+2ed8a10` -> `exe+1cae60c`, `BCQ_MULTIPLE_SELECTION_ORDER_MOVE`: queued. | read |
| Q6 `attack_location` | `exe+2ec20e8` -> `exe+2ed8148` -> `exe+2df5864`, `BCQ_MULTIPLE_SELECTION_ATTACK_LOCATION`: queued. | read |
| Q6 `attack_unit` | `exe+2ec21b8` -> `exe+2ed82a8` -> `exe+2df5a24`, `BCQ_MULTIPLE_SELECTION_ORDER_ATTACK_UNIT`: queued. | read |
| Q6 `fire_at_will` | `exe+2ee2924` -> `exe+2e9dfec` -> `exe+1bc3530`, `BCQ_MULTIPLE_SELECTION_UNIT_BEHAVIOUR_TOGGLE`: queued. | read |
| Q6 `set_invincible` | `exe+2f10784` -> each unit through `exe+2ef03ac` (true) / `exe+2eefac8` (false) -> `exe+2e9e228` -> `exe+2e9d7a4`, `BCQ_UNIT_SET_INVINCIBLE`: queued. | read |
| Q6 `trigger_projectile_launch` | `exe+2f1aef8` -> `exe+2f1ad84` -> `exe+2e9b9e4`, `BCQ_FIRE_PROJECTILE`: queued. | read |
| Q6 `melee` | `exe+2ef4828` -> `exe+1bc2ea0`, `BCQ_MULTIPLE_SELECTION_ORDER_CHANGE_MELEE_MODE`: queued. | read |
| Q6 `change_behaviour_active` | `exe+2ec47c4` -> `exe+2e9dfec` -> `exe+1bc3530`, `BCQ_MULTIPLE_SELECTION_UNIT_BEHAVIOUR_TOGGLE`: queued. | read |
| Q6 `change_current_walk_speed` | `exe+2ec4948` -> `exe+2e9c0e4`, `BCQ_MULTIPLE_SELECTION_ORDER_CHANGE_WALK_SPEED`: queued. | read |
| Q6 `set_current_ammo_unary` | `exe+2f0fba4` -> `exe+2e9d654`, `BCQ_UNIT_SET_AMMO_AMOUNT`: queued. | read |
| Q6 ability (`abilities.lua:94`, `hud.lua:287`) | CCO `PerformAbilityForOwner` (`exe+1c10b14`, registered at `exe+1a21e0`) -> `exe+1bc2ff0`, `BCQ_MULTIPLE_SELECTION_ORDER_CHANGE_SPECIAL_ABILITY`; the fallback `uc:perform_special_ability` (`exe+2f008c8`) -> `exe+2e9df94` -> the same pusher: queued. | read |
| Q6 `take_control` / `release_control` | `exe+2f16dd0` / `exe+2f09874` -> each unit through `exe+2ef045c` / `exe+2ef0364` -> `exe+2e9e120` -> `exe+1bc3680`, `BCQ_UNIT_CHANGE_CONTROL_STATUS`: queued. | read |

Every `uc:`, `bm:` and unit-method call the mod makes (the Q6 rows) reaches the queue. The mod's direct writes
(`P.steer`, `P.hold`, `P.face`, the disarm's fragment pointer, the gate patch) are not calls and are not in these rows:
Task 2 below found that `P.steer` does not reach the replay. The script-side pushers (`exe+2e9de34`
to `exe+2e9e2ac` and the bindings that inline the same test) drop the command when the battle's `+0x3b0` or `+0x3b1`
is set (all 27 wrappers read; `P.play` copies the test). `+0x3b0` is `battle:is_spectator()` (`exe+2eeb604` reads it); `+0x3b1` is not named by any binding (EMPIRE_MP
reads it through `exe+21bc5ac`, and `exe+21c7ff8` skips the command it pushes through `exe+2eefa4c` when it is set).

## What this changes for the plan

- **The carrier's payload.** The play command's wire layout (the model id, the slot and the mask as names, the byte raw,
  the reader collapsing the byte to `!= 0`) is in `docs/BATTLE_ENGINE_RE.md` section 13, "The play command on the wire".
  So a carrier keeps 8 + 3 = 11 bits besides its slot when a hook reads the raw byte (Q4 row: at `exe+2ecf556` or
  `exe+2ecf562`), and 1 + 3 at `exe+2ecf58f` alone. A STEER of two int16 values needs 32: several carriers per change, a
  range of reserved slots (each must be clipless on every machine), or another command type.
- **Another command type is on the same route.** `BCQ_ENTITY_USER_OVERRIDE_ORDER_MOVE` (type global `exe+406c798`,
  handler `exe+2ecfb0c`, version 0) reads a model, a position, a four-byte integer and a float and parks a move action in
  the man's queued holder. Its siblings `_JUMP`, `_TELEPORT`, `_ATTACK`, `_HALT`, `_FOLLOW_FIRST_PERSON` and the
  aim/reload overrides have handlers too, and nothing in the exe pushes most of them. Traced by Task 1b: see
  "Override commands" below (FOLLOW_FIRST_PERSON and REMAINING_RELOAD_TIME do have pushers).
- **The plan's slot bound.** A slot only has a clip below 2260 (`exe+14828c0`), and only a named slot survives the
  wire, so `CARRIER_SLOT` must be below 2260, not 2330.
- **A vanilla peer is not untouched.** On a machine without the cave, a carrier destroys the man's current command
  (the forced clip replaces it), and with any non-zero byte (the vanilla reader turns it into the loop flag) holds him
  in a clipless forced clip until the next order.
  It does not crash on this reading: Task 3 step 4 confirms.

## Override commands

Task 1b, 2026-10-21, static only (the exe on disk, `exe_re.py`, `ghidra_decompile.py`). "Read" and "inferred" as above.
The engine half is `docs/BATTLE_ENGINE_RE.md` section 13, "The override commands".

*Several points below that read "inferred", "not read" or "Task 2 reads it" were answered live on one machine; the rows
are kept as written. Under "Replay", "The overrides, live" and "Reads": `+0x890` is null on every model, heading 0 is
never applied (he faces his path), `+0x340` is set 0.5 s after he arrives, and a MOVE in a lasting melee is parked
without the gate and starts with it.*

**Verdict: usable, three of them for the mod's per-tick operations.** The per-man overrides are CA's own commands on the
same queue as the play command, every field raw on the wire (no names), and a peer without the mod runs them with CA's
code. MOVE builds the same walk the mailbox builds, from a point, a run flag and a speed that cross the wire as raw
floats and integers; HALT is the engine's own stop; FOLLOW_FIRST_PERSON has a wired pusher (whether CA's mode ever runs is open) and a 16-bit heading.
None covers the guard or the disarm, and MOVE carries no heading. **That a peer without the mod runs these with CA's
code does not make such a peer safe**: the guard, the disarm and the gate patch change the battle only on machines
that run the mod, so a peer without it desyncs whatever carrier is used. Multiplayer needs the mod on every machine. Two things differ from the Task 1 summary:
FOLLOW and REMAINING_RELOAD_TIME **do** have pushers (CA's own per-man control object, below), and the tag `4` field is
a four-byte integer, not a u16.

### O1, the wire

The tags, the entity-id registries and the position layout are in `docs/BATTLE_ENGINE_RE.md` section 13, "The override
commands". What only this record has: `exe+1bab24c` reads the fields back and fails the record on a wrong tag or a short
buffer; a string is a length byte, then at most 255 characters; an unknown id reads as null; a position goes into a
32-byte block (point, two optional anchors).

| Type | Global, handler, version | Fields the handler reads, in wire order | Serializer and pusher | Confidence |
|---|---|---|---|---|
| `_ORDER_MOVE` | `exe+406c798`, `exe+2ecfb0c`, 0 | `0x23` man; position; `4` int (read with size 4, `exe+2ecfb47`); `0xa` float (`movss`, `exe+2ecfb7f`) | none found; no code loads the global but its registration | read |
| `_ORDER_HALT` | `exe+406cea8`, `exe+2ecf98c`, 0 | `0x23` man | none of its own; `BCQ_ENTITY_INSTANT_KILL`'s `exe+2eecb50` (vtable `exe+39077d0`, pushed by `exe+2e9b904`) writes the same one field; no pusher | read |
| `_ORDER_JUMP` | `exe+406cd64`, `exe+2ecf9e8`, 0 | `0x23` man; `0xc` point | none; no pusher | read |
| `_ORDER_TELEPORT` | `exe+406cd30`, `exe+2ecfbd4`, 0 | `0x23` man; position; `1` byte (kept as `!= 0`) | none; no pusher | read |
| `_ORDER_ATTACK` | `exe+406c82c`, `exe+2ecf644`, 0 | `0x23` man; `0x23` target man | none; no pusher | read |
| `_ORDER_FOLLOW_FIRST_PERSON` | `exe+406cc88`, `exe+2ecf6d0`, 1 | `0x23` man; position; `0xd` heading; `0x25`; `0x21`; `1` has-target; `0xc`, `0x23`, `0x28` (target block, `exe+2f67de8`); `4` weapon index; `0xa` float; `4` stand state; `1` skip-turn; `0xa` float; then, version 1 only, `1`, `1` | serializer `exe+2eecd44` (vtable `exe+3ab25a8`, slot 0), builder `exe+2d9b4ec`, pusher `exe+2d919dc` | read |
| `_AIM_DELAY_TIME` | `exe+406c784`, `exe+2ecf498`, 1 | `0xa` float | none; no pusher | read |
| `_RELOAD_TIME` | `exe+406cda4`, `exe+2ecfc88`, 1 | `0xa` float | none; no pusher | read |
| `BCQ_ENTITY_OVERRIDE_REMAINING_RELOAD_TIME` | `exe+406c85c`, `exe+2ecf43c`, 1 | `0x23` man; `0xa` float | serializer `exe+2eecbe4` (vtable `exe+3904430`), pusher `exe+2d9196c` | read |

(The `_` rows are `BCQ_ENTITY_USER_OVERRIDE_*`.) How the serializers were looked for: every function writing a `0x23`
tag (ten, found as `mov dl, 0x23` within six instructions of a call to `exe+1bb1924`) and every caller of the position
writer `exe+2eafa2c` (ten), each matched by its field order against the readers. That search misses a serializer that
passes the tag in a register; but the types without a match have no pusher either (a scan of every rip-relative operand
in the code finds their globals only in the registration), so nothing would call such a serializer.

**Who pushes FOLLOW.** The battle constructor (`exe+2d98420`, at `exe+2d99995`) builds a 0x820-byte object at battle
`+0x647a0`; a per-frame call (`exe+2ef594c` -> `exe+2dcb3a8`) runs its update `exe+2dcb644`, which, while its `+0x518`
(a man) is set, builds a FOLLOW with `exe+2d9b4ec` and pushes it with `exe+2d919dc`. Leaving that mode (`exe+2db96b4`)
pushes REMAINING_RELOAD_TIME. It is CA's own per-man control, still wired; what sets `+0x518` was not traced. (read)

### O2, what MOVE does to the man

| Question | Answer | Confidence |
|---|---|---|
| Holder and class | The handler clears his **queued** holder (`+0x5c8`, `exe+2db5ac4`) and builds a move action there: block `exe+2f6496c` (the position, then the int at `+0x38`, the float at `+0x3c`, `+0x44` = 3, `+0x50` = 4, `+0x51` bit 0), constructor `exe+2f647d0`, vtable `exe+390bea8` (start `exe+2f7885c`, update `exe+2f88bb0`). Its `+0x80` slot (`exe+8f5810`) reads block `+0x50` bit 4, which is 0: it does not block orders. No rider redirect, unlike the play command: on a rider (`exe+306e490` true) the action update marks a queued action done at once (`exe+3075e7c`), so MOVE must name the mount, as `P.steer` already does. | read |
| How he moves | The start (`exe+2f70178`) waits while his vslot `+0x260`, his `+0x898` and `exe+30595b0` say a clip is not to be cut (`+0x260` is a constant false on the infantry vtable `exe+3912950` and its subclass `exe+3915a20`, so on those it never waits), then branches on `exe+2f6c180` (his `+0x890` set and `exe+307a1c8` finds a navigation object). **Not set:** `exe+2f7f07c` copies the block into the walk parameter block with `exe+324e05c` (point at `+0x0`, **the int as the run flag at `+0x28`, the float as the speed at `+0x2c`**, `+0x30` heading 0, `+0x34` 3, `+0x46` 1, `+0x4a` 1, `+0x4c` the action's time) and calls his vslot `+0x568`, **`walk_start` (`exe+306f954`), the builder the mailbox calls**: his command becomes his own walk (`exe+3ae2400`). **Set:** `exe+2f7f604` builds the block with `exe+324e8bc` (run = float `!= 0`, speed = the unit's own for that gait from `exe+303b744`, heading 0) and calls vslot `+0x5b0` (`exe+306fd58`), which builds the same walk or, when his vslot `+0x440` says so, another command (`exe+324e780`). | read |
| Which branch a man in the open takes | `+0x890` is zeroed by his constructor (`exe+30530cb`) and set by his vslot `+0x388` (`exe+3071134`) from a payload pointer; what it holds was not found. Inferred null on open ground, so the walk_start branch with the sender's speed. Task 2 reads it. | inferred |
| Speed, gait, facing | Walk_start branch: the speed is whatever float was sent (the sender can send `walk_speed` times 1.5 for a sprint), run is the int, the gait byte (`+0x46`, his `+0x3ae`) is 1 whatever was sent (the mailbox writes the run flag there), `+0x44`/`+0x45` are 0 where the mailbox writes 1. **Heading is 0 on every MOVE**: block `+0x40` is zeroed by `exe+2f6496c` and no field fills it. Whether the walk turns him to 0 at the end or while walking was not read. | read; effect of heading 0 not read |
| When it ends | Walk_start branch: the action marks itself started (`+0x9c`), never re-issues the walk, and is done when his command's done byte (`+0x340`) is set (`exe+2f88bb0`, and `exe+325773c` on his command). Section 5 of `BATTLE_ENGINE_RE.md` has that byte set when a walk with no path ends itself; whether reaching the point sets it was not read. The walk it built stays on him after that, as any walk does. Other branch: `+0x9c` is never set, so each update calls `exe+2f70178` again and rebuilds the walk every tick. While MOVE is parked and not done, the action update resets his **running** holder every tick (`exe+3075e7c`). | read; end on arrival not read |
| Vanilla, the regiment ordering every tick | Any order that tick (`+0x324` not 0) with a parked, unfinished action takes the reset (`exe+306d1ac` -> `exe+30847b0`, which resets the queued holder): MOVE never starts in a melee, exactly as the swing never did (`BATTLE_ENGINE_RE.md` section 7). On a tick with no order it starts; each later order tick resets it and the next quiet tick runs its start again, i.e. a fresh `walk_start`. | read |
| With the gate patch (`P.gate`, `75 52`) | Every tick with a parked, unfinished action goes to the action update, whatever the order kind (the patched jump skips the kind test at `exe+30873a8`), so MOVE starts at his next update (its own tick, if the queue runs before the men update: inferred, since CA's FOLLOW only works that way). **But the order that tick is not refused**: the order issuer (`exe+306e89c`) ran before his update and refuses only for a **running** action that blocks orders, which MOVE is not. A regiment order that differs from his walk replaces it, the guard's stop then leaves him standing (it stops the regiment's commands, not his own walk), and MOVE on the walk_start branch does not rebuild it. **So MOVE survives the order as an action but not as a walk: in a melee the mod must re-send it every tick while steering**, as `P.steer` re-posts today. | read |
| One parked action per man | Every override handler and the play command clear the queued holder before parking theirs. A MOVE and a clip for one man in one tick: the later one in the buffer wins and the earlier is destroyed unstarted. A MOVE reaching a man whose swing is playing does not wait on the infantry vtables (the `+0x260` test above): `walk_start` replaces the forced clip and **cuts the swing**. | read for `exe+3912950` / `exe+3915a20`; other classes not read |

### O3, the other overrides

| Type | What it does to the man | Confidence |
|---|---|---|
| HALT | Parks an action (vtable `exe+390ba88`) whose constructor (`exe+2f645b4`) delays its start by a draw from the battle's random generator (`exe+1bab1b0` on battle `+0x90`, bound 3: 0 to 2 ticks if the draw is below its bound), then calls **the stop `exe+306edf8` with state `0x81`**, the routine `walk_stop` calls with his own `+0x318`; done when his new command reports done (`exe+2f88b90`). Unlike the mailbox's stop, it replaces any command, not only a walk. | read |
| JUMP | Builds a jump block from the point and his heading (`exe+2d9f998`), parks an action (vtable `exe+390b980`) whose start calls his vslot `+0x538` (`exe+306f158`): he jumps toward the point. | read; the jump inferred from the slot's use |
| TELEPORT | Action vtable `exe+390b5e8`, start `exe+2f78b30`: byte 1 puts him at the point keeping his heading, byte 0 keeps him where he is and turns him toward the point (his vslot `+0xe8`, `exe+3078268`, position and heading), then the stop with state `0x81`. Its update (`exe+8f5a70`) copies a byte the handler set to 0 into done, so it **never finishes**: parked until another override or clip replaces it, re-run after every reset. | read; vslot `+0xe8` inferred from its arguments |
| ATTACK | Builds the 0x38-byte target block from the second man (`exe+2eab460`, as the charge's), action vtable `exe+390c2c8`; its start (`exe+2f780a8` -> `exe+2f7ec44`) issues an order through his order issuer (vslot `+0x4b0`, `exe+306e89c`, kind 1), which builds the engine's melee attack the guard stops, or on its other branch calls vslot `+0x580` (`exe+306f9e8`). | inferred |
| FOLLOW_FIRST_PERSON | Action vtable `exe+390bc98`, start `exe+2f783f0`: runs **only on the tick it was executed** (compares `+0xc0` with the tick, else marks itself done); with skip-turn 0 and no target, when his command is not busy (`+0x340` set or command vslot `+0xa0` false), turns him to the u16 heading through vslot `+0x5f8` (`exe+30702b8`, with the stand state and the second float), or, when he already faces it, stops him with that state (`exe+2f6834c` -> vslot `+0x528`, `exe+306edf8`); with has-target and a weapon index not -1, an attack command (`exe+306fd1c`). Lasts 10 ticks (`exe+2f88b78`). A new FOLLOW is dropped only when an unstarted one from this tick with a target is parked (`exe+2f7ea80`). Nothing in the action reads the first position. | read; "busy" for a walk inferred |
| AIM_DELAY_TIME | No man: writes the float to the global `exe+3d10790` (default -1.0), which `exe+32580b1` uses in place of the unit's own value when not negative: every man in the battle. | read |
| RELOAD_TIME | No man: writes the float to `exe+3d10794` (default -1.0). No reader of it in the code by a full rip-relative operand scan (every four-byte displacement in the code section whose target is the address, for any opcode including `movss`, each hit re-decoded with capstone; `exe_re.py refs` alone misses `movss` operands): only the handler's store. The two references beside it do not reach it: `exe+3d10780` is a 16-byte static object with an exit-time cleanup thunk (`exe+1237850`), and `exe+3d10798` is a three-float vector read at `+0`, `+4` and `+8` (`exe+2e23ed3`). **Inert as far as the code shows**; a read through a computed pointer is not excluded. | read write; no reader inferred |
| REMAINING_RELOAD_TIME | Writes the float to his `+0xad0` (CA sends the larger of its own `+0x770` and that field when leaving the control mode). | read |

### O4, pushing one

| Type | Recipe | Confidence |
|---|---|---|
| FOLLOW_FIRST_PERSON | `P.play`'s recipe: a 0x90-byte command, vtable `exe+3ab25a8` at `+0x0`, man `+0x8`, a point `+0x10` (unused), anchors `+0x20`/`+0x28` null, heading u16 `+0x30` (0x10000 per turn, his `+0xb0`'s unit), `+0x38`/`+0x40` null, has-target u8 `+0x48` 0, target point `+0x50`, `+0x60`/`+0x68` null, weapon index i32 `+0x78` -1, float `+0x7c` 0, stand state i32 `+0x80` `0x81` (CA's default), u8 `+0x84` 0, skip-turn u8 `+0x85` 0 (1 makes it a stop with that state), aim u8 `+0x86` 0, float `+0x88` 1.0 (the third field of the turn; 1.0 is what `exe+3075e7c` passes to the same slot); then `exe+2d919dc(queue, command)`. 99 bytes on the wire. | read; the `+0x88` value assumed |
| MOVE, HALT, the rest | No pusher: forge one. Read the type's id from its global at run time (zero on disk, set by the registration; the same exe registers in the same order on every machine). A 0x18-byte writer; `exe+1bca278(writer, queue + 8, &id, version)` writes the header (u16 length placeholder, the id big-endian, the version) and fills the writer (`+0x0` error flags, `+0x8` buffer, `+0x10` start); `exe+1bb1924(writer, tag, source, size)` writes each field, checking the 0x5000 limit; `exe+1bcd5e4(writer)` patches the length, or rewinds when a write overflowed. **Because `exe+1bb1924` writes the tag then `size` raw bytes, one call can write the whole record**: the first tag, and as source the first value followed by every later tag and value. So three calls per command: header, record, length. Same queue and same `+0x3b0`/`+0x3b1` test as `P.play`. MOVE: `0x23` man id (his `+0x258`), `0x0c` x y z, `0x26` 0, `0x27` 0, `0x04` run, `0x0a` speed, 45 bytes. HALT: `0x23` man id, 12 bytes. | read |
| Float32 | `0x406c798`, `0x406cea8`, `0x406cc88`, `0x3ab25a8`, `0x2d919dc` and the three writer functions are exact in float32; `0x406cda4` (RELOAD_TIME), the cave site `0x2ecfcb7` and its resume address `0x2ecfcbd` (below) are not and go through `M.split`. | read |

### O5, coverage

| Mod operation | Override | Covered | Not covered |
|---|---|---|---|
| steer: point | MOVE `0xc` | x, y, z as raw floats | the two anchors must be 0 |
| steer: run | MOVE `4` | the run flag the walk reads | the gait byte is always 1 |
| steer: sprint speed | MOVE `0xa` | any speed, sent as computed on the owner's machine (walk_start branch) | on the `+0x890` branch the unit's own speed only |
| steer: heading | none | | MOVE sends heading 0; FOLLOW does not turn a busy man (inferred) |
| hold | HALT | the stop, state `0x81` | 0 to 2 ticks late; stops any command; state is not his `+0x318` |
| face (standing) | FOLLOW | u16 heading, 16 bits | only on its own tick, only when not busy |
| guard | none | | no override stops the engine's orders on one man |
| disarm | none | | no override touches his fragment |
| the steering copies, `+0xb0` | none | | `P.steer`, `P.hold`, `P.face` write them directly today: battle state on one machine |

### Recommendation

**A mix: native MOVE, HALT and FOLLOW for the per-tick operations, and one carrier only for the state toggles.**
Steer is one MOVE per steering update (re-sent every tick in a melee, see O2), hold one HALT, a standing face one
FOLLOW. Guard on/off, disarm and arm with their two flags, and the gate if it is not kept in for the whole
battle on every machine, go in one carrier command each. For that carrier, **RELOAD_TIME before the play command**: 32
raw bits, 12 bytes, no man resolved and no effect on any machine as far as the code shows, read by a cave at
`exe+2ecfcb7` (6 bytes `F3 0F 10 44 24 30`, `movss xmm0,[rsp+0x30]`, whole, no jump, no rip-relative operand, after the
read-error test at `exe+2ecfcb1`; the value at `[rsp+0x30]`, the record in `rbx`; resume at `exe+2ecfcbd`, after re-running the displaced `movss`, because the store at `exe+2ecfcbd` writes `xmm0`). It carries
no man, so the 32 bits hold the man's id (`+0x258`) beside the operation; whether ids fit in the bits left is for Task 2
to read. The play command with `CARRIER_SLOT` is the fallback if Task 2 finds a reader of `exe+3d10794`: 4 bits at
`READER_HOOK`, 11 at the early hooks (which run before the read-error test and the model resolve, so a cave there must
check both itself), and on a reader without the cave it replaces the man's command with a clipless forced clip.
**Heading while walking** is the one steer field nothing native carries: Task 2 first measures what the walk does with
heading 0; if it must be sent, 16 bits in the carrier.

| Operation | Option A: play-command carrier only (bits; commands at 11 / 4 bits) | Option B: overrides + carrier (recommended) | Option C: overrides only |
|---|---|---|---|
| steer | point 2 x int16 dm, run, sprint, heading 16: ~50 bits; 5 / 13 | MOVE: 160 raw bits (x y z, run, speed), 1 command, 45 bytes; heading 0, or 1 carrier more | MOVE, heading not sent |
| hold | heading 16 + op: ~17 bits; 2 / 5 | HALT: 0 bits, 1 command, 12 bytes | HALT |
| face | 16 bits; 2 / 4 | FOLLOW: 16 bits, 1 command, 99 bytes | FOLLOW |
| guard | op: 1 / 1 | carrier: 1 command (RELOAD_TIME, 32 bits, 12 bytes) | not possible |
| disarm | op + 2 flags: 1 / 1 | carrier: 1 command | not possible |

Option A's counts leave out the bits a multi-command operation spends saying which piece it is; its commands are
35-49 bytes each (two names as strings). Option C leaves the guard and the disarm out of multiplayer. In every option a peer without the mod desyncs, since the
guard, the disarm and the gate change the battle only where the mod runs. **What Task 2
tests live:** a forged MOVE, HALT and FOLLOW on a man in the open and in a melee, gate in and out; the man's `+0x890`;
what heading 0 does to the walk; whether reaching the point sets `+0x340`; the range of `+0x258` ids; and that writing
`exe+3d10794` changes nothing.

## Replay

Task 2, 2026-10-21, live, one machine. Grand Cathay (20 units: a lord on a celestial lion, a Longma, four melee
infantry, seven missile infantry, Longma riders, two sky junks, three rocket batteries, a war drum) against Skaven (20
infantry units), a custom land battle on an open desert map, test settings, the game launched from `used_mods.txt`,
everything driven over the wh3-mcp bridge with no keys or clicks. Probes: `zz_tp_mp_issue.lua` (the calls),
`zz_tp_mp_watch.lua` (the record, every 100 ms of model time, in the battle and again in its replay),
`zz_tp_mp_override.lua` (the forged overrides and the passive reads), all in `Modding Files/source/lord_control/probes/`;
the open-ground control under "The overrides, live" used `zz_tp_mp_resend.lua` from the same folder.
The replay is the game's own `Auto-save.replay`, loaded from the battle's results popup ("Load Replay", then the
requester's OK); the bridge and the pack's platform both load in a replay, and the replay starts at the tick the
battle's deployment ended. "Recorded" below means the replay reproduced the effect at the same model tick with the pack
idle. Times are model ms; run 1 started at 12800, run 2 at 20800.

**Verdict: every call class tested through `uc:`, `bm:` or a unit method, and `P.play`, is recorded; `P.steer` is
not.** The CCO cast (`PerformAbilityForOwner`) was not tested, and the `melee` row is recorded only by the indirect
argument given in its row. Two whole-battle checks back the row-by-row table. Run 2 issued only recorded commands, and
its replay matched the battle on every logged field of all 40 units (position to 0.1 m, fire at will, defend, men,
ammo, invulnerable, script control, moving, the first man's command and clip) for all 1,822 ticks compared (182 s,
20900 to 203000), the AI army's own advance included. Run 1's replay matched for 723 ticks; the steered man differed
from 92900, one tick after the first `P.steer` post (92800), and the first unit to differ, at 93100, was a halted enemy
unit 298 m from him. 19 units differed within 1.5 s and 36 of 40 in all, 25 of them first in the clip field (5 in ammo,
5 in position, 1 in men); 4 never differed (the lord, the Longma, the Longma riders, the war drum). Contact cannot carry a
change 298 m in two ticks. The route is probably a stream shared by the whole battle, such as its random draws, which
the steered man's changed situation consumed differently (inferred, not traced). Either way one unrecorded write
desyncs the battle, not only the man written, and **for Task 3 the clip chosen by men across the battlefield is
the fastest desync detector**: it differed within a tick or two where positions took seconds.

Every queued command whose effect a getter shows changed it two ticks (+200 ms) after the script call: `goto_location`,
`halt`, `attack_unit`, `fire_at_will`, defend, walk speed, `set_invincible`, ammo, `take_control` and `release_control`,
`P.play`'s parked action, an ability's use. The effects that have a lead time of their own showed later: aiming after
`attack_location` at +500, the weapon change after `melee` at +1000, the first casualty after
`trigger_projectile_launch` at +1200. That lead was not separated from the queue's delay. The steer's direct write
showed on the next tick.

| Call class | Issued at | Observed in the battle | Observed in the replay | Verdict |
|---|---|---|---|---|
| `goto_location` | 17800 | Tiger Warriors moving at +200, 7.1 m by +5 s | identical from 20800 (the replay's watch started then) | recorded |
| `halt` | 22800 (after a goto at 20800) | moving 1 to 0 at +200, held there | identical | recorded |
| `attack_location` | 27800; run 2 45800 | run 1, a melee unit: nothing changed. Run 2, Iron Hail Gunners with nothing in range: aiming at +500, first shot at +1600, ammo 1980 to 1946 by +4.1 s | identical | recorded (run 2) |
| `attack_unit` | 32800 | Dragon Guard moving at +200, 11.4 m by +5 s | identical | recorded |
| `fire_at_will` | 37800 | fire at will 1 to 0 at +200, ammo stops | identical | recorded |
| `melee` | 42800 | gunners' first man clip 1438 to 1461 at +1000, read as the weapon change; but clip slots change on their own on 36 of 40 units, and this man's went 1441 to 1438 a second before the call | identical | recorded (indirect): the observable is not specific, but run 1 matched tick for tick until the steer, and an effective unrecorded command desyncs within ticks, as the steer showed |
| `change_behaviour_active` (defend) | 47800 | defend 0 to 1 at +200 | identical | recorded |
| `change_current_walk_speed` | 52800 (with its goto) | Longma riders moving at +200, 24.6 m in 5 s | identical | recorded (the pair; the scalar's own effect was not separated from the goto's) |
| `set_invincible` | 57800 | invulnerable 0 to 1 at +200 | identical | recorded |
| `set_current_ammo_unary` | 62800 | ammo 1804 to 990 at +200 | identical | recorded |
| `trigger_projectile_launch` | 67800 | three death globes into Skavenslave spearmen: 180 to 179 men at +1200, 176 at +1300 | identical | recorded |
| ability, `uc:perform_special_ability` | 72800; run 2 55800, 171500 | run 1, fearsome roar: no logged field moved. Run 2, read through CA's unit context: potion of speed used (RemainingUses 0 afterwards); fearsome roar IsActive at 171700 | potion IsActive and RemainingUses 1 to 0 at 56000; roar IsActive at 171700, its countdown identical tick for tick | recorded |
| ability, CCO `PerformAbilityForOwner` | run 2 161500 | nothing: the potion had no uses left | nothing | not tested |
| `take_control` | 77800 | script controlled 0 to 1 at +200 | identical | recorded |
| `release_control` | 87800 | 1 to 0 at +200 | identical | recorded |
| `P.play` | 82800; 125800 | 82800: the clip action parked in his queued holder at +200 and never started (his `+0x324` read 18 every tick); 125800: forced clip, slot 454, at +200 | identical, both times | recorded |
| `P.steer` (control) | 92800 to 96800 | the man left his line under his own walk, 4.5 m by +4000 | he stayed in the line under the regiment's command | **not recorded** |

**The positive control is not the plan's.** A right-click order by hand was not made: the author's rule forbids real
input while they may be at the machine. What stands in for it: the battle's and the replay's logs are two independent
recordings (separate script logs, the replay's watch started fresh in the replay), and no issue probe ran in either
replay; run 2's replay reproduced `attack_location`'s ammo drop on the gunners at the same ticks while the Jade Warrior
Crossbowmen beside them, given no order, kept all 1,980 bolts in both; and run 1's steer shows the comparison can see a difference when one exists. The
remaining gap, a player's own order, goes to Task 3.

### The overrides, live

| Question (Task 1b) | Measured | Replayed |
|---|---|---|
| Which way a MOVE walk faces him | Run 2, a Guandao man sent 15 m to his right (east) from heading 0: his own walk (`3ae2400`) at +200, turned to 16650 (east is 16384) in 0.7 s, walked facing his path (17700 to 19300, swinging as he steered round men), stopped at the point facing his last step (29185). Heading 0 is never applied, neither while walking nor on arrival. His `+0x340` went to 1 0.5 s after he arrived; the walk stayed on him until his idle replaced it 2 s later. | identical tick for tick |
| MOVE re-sent every 0.1 s in a lasting melee, gate out | Dragon Guard against invincible Stormvermin, the front man, 50 MOVEs in 5 s: the MOVE sat parked and unstarted on 48 of 49 ticks, `+0x324` 1 every tick, his command the engine's melee attack (`3ad24b8`) throughout; 0.1 m net | the same pattern on the replay's man (the battle had diverged by then) |
| The same with the gate in | Another front man: started at once, his own walk on him on 47 of 49 ticks, `+0x324` 0; but 1.2 m net (3.9 m of path) in 5 s, his heading fixed at 63815 (facing the enemy, the target behind him) and playing his swing (454) and hit clips (917, 477). Once the gate came out and the MOVEs stopped (155700), he turned to 31279 and the walk he kept took him 19.7 m in 11.3 s. One man, 5 s: the cause is not isolated between the press, his own fight clips and the gate; the open-ground control below rules out the re-sending itself | not comparable: the gate is a memory patch, so the replay ran without it |
| Control: re-sending on open ground (`zz_tp_mp_resend.lua`, a separate battle, no replay) | Five fresh Iron Claw Guandao men of an idle unit's front rank, enemy 345 m away and halted, a forged MOVE 20 m ahead at walk speed (1.5 m/s). Sent once, re-sent every 0.1 s, every 0.3 s or every 0.5 s for 5 s with the target fixed: all four within 0.1 m of each other. Each had his own walk (`3ae2400`) and a started queued action from +200 on all 48 ticks, faced the target from +200 (64832) and kept it, and covered 1.1 m by +1 s, 7.1 m by +5 s (7.2 for every 0.5 s) and 14.6 to 14.7 m by +10 s. Re-sent every 0.1 s with the target moving 0.5 m further at each send (a steering lead): 6.6 m by +5 s, the same walk throughout, one 0.8 s side-step (58200 to 58900, 0.8 m across, heading down to 56615) while his queued action read parked and unstarted on those 8 ticks, then back on his line | not run (no replay needed) |
| A MOVE and a clip for one man in one tick | MOVE then clip: the clip won (forced clip, slot 454, about 3 s, no walk). Clip then MOVE: the MOVE won (his walk, no clip). The later command in the tick's buffer wins | identical (MOVE then clip); the clip-then-MOVE man had died in the replay |
| RELOAD_TIME changes anything visible | Pushed 0.2 at 135800, -1.0 at 160800. The global `exe+3d10794` read 0.2 within a tick and -1 after. Ammo spent in the 20 s before the push and the 20 s after, per missile unit: Dragon Guard Crossbowmen 254 / 252, Dragon Guard Crossbowmen of renown 24 / 20, crane gunners 17 / 11 and 3 / 3, sky junks 7 / 7 and 7 / 7, rocket batteries 28 / 35, 21 / 21 and 3 / 0; iron hail gunners, grenadiers and the jade crossbows 0 / 0 (out of range, melee mode or fire at will off). No run-to-run spread was measured, so these counts are the whole evidence. Reload bars were not read (an in-game screenshot has no UI layer) | the global took the same values at the same keyframes |

HALT (after 3 s of a forged MOVE): he stood (stand command `39126f0`) 300 ms after the push, then took his regiment's
move command back. FOLLOW_FIRST_PERSON, 90 degrees asked from heading 0 on a standing man: he turned to 10011 (55
degrees) in 1.3 s under a turn command, and the action ended there, its ten ticks spent. Both replayed with the same
commands at the same ticks. The forged records' headers used the registry's own versions (MOVE 0, HALT 0, FOLLOW 1,
RELOAD_TIME 1) and the type ids read at run time; no writer flagged an overflow.

### Reads

- **`CARRIER_SLOT`**: 29 fragments were reachable from the 4,185 models (6 of them mounts'). None binds 2123, 2126 or
  2127, and no mount fragment binds 129: all read `0xffff`. Only Grand Cathay and Skaven fragments were loaded; the
  all-races check is still open.
- **The gates**: `+0x3b0` 0 and `+0x3b1` 0 throughout the battle (deployment, every 5 s, the end) and throughout its
  replay. Task 3 compares a client.
- **`+0x890`**: null on all 4,185 models at the start and all 4,075 at the end, so MOVE takes the `walk_start` branch
  with the sender's speed, as inferred.
- **`+0x258` ids**: the high half is 0 on every model and mount; the ids run 1 to 4,265 across 4,185 bodies, so they
  look handed out in sequence; whether one is reused after a death was not looked at. This one 20-against-20 battle
  fits in 13 bits; bigger battles, summons and reinforcements can pass 8,191, which is why the plan now sizes the
  carrier's id field at 16 bits.

### What this means for the port

The engine side holds for what was tested: every call class above except the CCO cast reached the replay (the
`melee` row indirectly), so each reaches every machine that runs the recorded stream (Task 3 confirms the network
half). A direct write does not, and one is enough to desync the battle: `P.steer`, `P.hold`, `P.face` (`+0xb0`), the
disarm's fragment pointer and the gate patch all have to move onto queued commands or run identically on every machine.
MOVE carries the steer, and heading 0 costs nothing on the move: the man faces his path. On open ground re-sending a
MOVE every tick, every third or every fifth changes nothing against sending it once, so the port can send on change or
every tick there; a moving target costs a little ground. In a melee, MOVE does not start without the gate; with it, one
man for 5 s moved 1.2 m, cause not isolated. RELOAD_TIME has no reader in the code, and the fire counts above neither
show nor rule out an effect (no spread was measured), so it stays usable as the carrier; the built cave never stores the
value anyway (`BATTLE_ENGINE_RE.md` section 13).

## Rulings

The decisions taken while the net mode was built, 2026-10-21. Each holds until the live session says otherwise; "if
wrong" is what it costs. Code comments cite them by number. Rulings 1-12 appear here only where this record does not
already state them: Ruling 1 (`CARRIER_SLOT` picked statically, then checked live) is the Q4 row and "Reads", and
Ruling 8 (the open-ground re-send control) is the control row of "The overrides, live".

- **2.** Order of work: Tasks 1 and 2, then the offline Tasks 4 and 5, then a stop before Task 3 for the second
  machine. If wrong: two offline tasks built for a port the gate rejects. Its wait was overturned by Ruling 12.
- **3.** Until Task 3, the simulation's local-only calls are Task 2's "not recorded" classes and its delay 3 ticks, both
  provisional. If wrong: one line each to change. The delay is now Task 2's two ticks (`DELAY_TICKS = 2`).
- **4.** No test hook in the shipped entry file: the simulation ran net mode on machines loaded with `mp = false` until
  Task 9 switched them to `mp = true`. If wrong: a behaviour only `bm:is_multiplayer()` triggers went untested until then.
- **5.** Task 4's byte-plus-u32 wire format is void, since the play command keeps only 11 bits besides its slot; Task 1b
  traced the per-man overrides as a native carrier first. If wrong: one extra RE task.
- **6.** Phase 1 redesigned on Tasks 1, 1b and 2: native MOVE, HALT and FOLLOW_FIRST_PERSON for steer, hold and face, the
  play command unchanged, a RELOAD_TIME carrier (magic `0xD7`, op, flags, 16-bit id) for guard, disarm and arm, the gate
  in on every machine, one cave at `exe+2ecfcb7` with a 16-entry guard table. If wrong: FOLLOW turned a standing man 55
  of the 90 degrees asked in 1.3 s (measured) and is inferred not to turn a busy man at all (O5), so aiming a shot may
  need the carrier to carry a heading.
- **7.** Tasks 4 and 5 go ahead offline; Task 3 waits for the second machine. If wrong: as Ruling 2, offline work for a
  port the live session rejects; Ruling 12 later added Tasks 6-9 to the offline work.
- **9.** A word with the magic and an op outside 1-5 decodes to nil, and the cave drops it; the cave also drops 5, HELLO,
  which asks it for nothing. If wrong: an unknown op is ignored rather than flagged.
- **10.** Flag bits 18-19 are unassigned, and `M.uncarrier` and the cave both ignore them rather than drop the word, so
  the two never disagree. If wrong: a later flag in those bits is read as a plain op by an old cave.
- **11.** The simulation's oracle compares a per-tick snapshot of every man, every unit and the recorded battle calls,
  not what was delivered; a write a later task owns goes in a named allowlist that task empties (it is empty now). If
  wrong: an allowlisted write hides a one-sided write until its task lands.
- **12.** Overturns the wait in Ruling 2: Tasks 6-9 were built offline, and Task 3 runs with Task 10 in one two-machine
  session. If wrong: the network leg fails and four offline tasks are wasted; nothing ships before that session either way.
- **13.** In net mode no MOVE, HALT or FOLLOW goes for a body from its clip's send until the clip shows or `net_delay` plus
  one tick has passed. Cost: the swing cannot be re-aimed in that window. If wrong: swings turn less toward the
  crosshair than in single player. Amended by Ruling 19.
- **14.** The guard table's double free (the update cave and a GUARD_OFF freeing one entry at once, counting it down
  twice) was deferred to the live session. If wrong: one machine skips the update cave's guard scan and desyncs.
  Settled in code by Ruling 18.
- **15.** No HELLO handshake and no `derpy_tp_mp_needs_everyone` loc key yet: both wait for the live answer on whether a
  lobby starts when one player lacks the pack. Nothing is uploaded until checklist items 10 and 12 are answered. If
  wrong: a lobby where one player lacks the mod desyncs on the first forged command, or before it if vanilla men park
  actions (item 10), and the handshake is built then.
- **16.** The copy table takes every army's fragments, with no `is_player_controlled()` filter: what that call returns on
  each machine is unmeasured, and a local meaning would desync on the first DISARM. If wrong: about twice the memory
  and the Deployed time, nothing else.
- **17.** A replay of a multiplayer battle builds net mode too (the gate, the carrier cave, the copy table), because it
  needs them to reproduce the battle; the entry then turns the player's side off. If wrong: such a replay carries the
  mod's patches, which it needs anyway. Item 13 asks whether it reproduces.
- **18.** Ruling 14 settled in code, not live: both caves free an entry with `lock cmpxchg` on its pointer and count down
  only when the exchange won. If wrong (mis-encoded): the cave selftest and its mutants catch it offline.
- **19.** Ruling 13 amended: the block after a clip ends when the clip shows or at the clip's own give-up, which its
  caller passes, not after `net_delay` plus one tick; the queue's delay cancels out of it. If wrong: a clip parked longer
  is still cut, which item 5 shows.
- **20.** A net-mode start before "Deployed" is refused (F2 waits, silently); the guard-table clear at Deployed is
  dropped (the build already zeroes it, and a clear there runs beside the battle's threads); the copy-table builder runs
  in a `pcall` with one log line. If wrong: F2 during deployment does nothing in multiplayer, where single player allows
  it.
- **21.** Whether HALT cuts a playing clip, and what the engine does with a command for a dead man, are live
  measurements (items 15 and 6). The code change was only to make the simulation's fake engine land a command on a dead
  man who still resolves, as the handlers do. If wrong: the simulation's dead-man cases pass against an engine that
  behaves differently; items 15 and 6 settle it.
- **22.** The block for a swing that never shows runs to `LOCK_MAX + late()`, 3.2 s, the same window in which `main.lua`
  keeps him armed for a late swing. Cost: in net mode such a swing roots him about 2 s longer than single player. If
  wrong (unseen swings are common): shorten it to `LOCK_WAIT + late()`. Live: count the swings never seen in a 10-minute
  melee.
- **23.** One more offline round: the block now clears once the clip has shown (`R.watch`; without it he could not move
  until 3.2 s after each click), an unreadable unit is left out of the copy table rather than failing it, and a test pins
  the build's zero of the guard table. A peer whose table is not built yet drops the DISARMs it is sent: that goes to the
  HELLO handshake, and until then the session waits a few seconds after Deployed before F2 and logs the build time. If
  wrong: a slow peer drops a DISARM and desyncs, which the hash log shows at once.
- **24.** Three small gaps parked: no test pins the shipped `P.watch = R.watch` wiring, nor the watch's regiment-man and
  rider paths (item 18 checks them live); a null model entry inside a readable unit still fails the copy table and turns
  multiplayer off (not demonstrated). If wrong: multiplayer off for that battle on every machine, no desync, said once
  in the log.
- **25.** The HELLO handshake, built before the live session, so Ruling 15's wait is overturned and Ruling 23's gap
  closed. Each machine sends one HELLO carrier (op 5, version 1 in bits 15-8, its army's slot in bits 7-0) for its own
  army once its copy table is built, and sends it again while a push is refused. The carrier cave sets the slot's bit in
  a mask at block `+0x5c` with `lock or`, and a model callback in `platform.lua` (so a replay runs it too, Ruling 17)
  puts the order gate in once every human army's bit is set; the gate no longer goes in at build, which only checks
  its bytes. F2 starts net play only then, and before it says `derpy_tp_mp_needs_everyone`. Human means
  `army:is_player_controlled()`, whose multiplayer meaning is item 8; fewer than two human armies is refused, since a
  local meaning would start each machine alone. If wrong: a local meaning keeps the pack off in every multiplayer battle
  (safe, said once in the log); a player who controls two armies never completes it (also safe); a vanilla peer that
  reads RELOAD_TIME's global after all desyncs on A's HELLO alone (item 12); and a gate patched from the model callback
  at a different point of the tick on each machine desyncs at the handshake's tick (item 10). Amended by Ruling 26.
- **26.** The HELLO is sent only on this player's first F2 press in net mode, or as soon as another human army's HELLO
  has landed, and in both cases only after this machine's copy table is built: a modded peer answers by itself, and a
  lobby where nobody presses F2 forges nothing. The press is kept: third person starts by itself when the handshake
  completes, with no second press, and `derpy_tp_mp_needs_everyone` shows only once the handshake is 5 model s late
  (`HELLO_WAIT`, two queue delays and three 100 ms callbacks with 2.3 s a trip to spare). A press while one is kept does
  nothing (Ruling 28 changed this, and Ruling 29 restored it); a kept press is dropped 15 model s after it (`NET_DROP`), since a camera taken over
  later lands on a player who has gone back to commanding the battle. If wrong (the vanilla global is read after all): a
  mixed lobby where someone presses F2 still sends one HELLO; item 12 measures it.
- **27.** The handshake review's fixes: no HELLO from a spectator (`bm:is_spectator()`, pcall'd; a throw counts as
  watching) nor with fewer than two human armies; both log lines name the human armies' slots and the army count, so
  item 8 can compare machines; the completion tick is stated as inferred; the gate's write is proven at build, in and
  out again before the first tick, and net mode refused if either write fails, so a machine that cannot write it never
  says HELLO; one log line names the armies not heard once the handshake is late. A second human army entry for one
  player (a reinforcement) never completes and is parked as a live look (item 8). If wrong: an out-write refused after
  the in-write went leaves the gate in on a refused machine, said in its reason. The second review added: a spectator
  never starts third person either (`M.start` refuses it, a throw counting as watching, and keeps no press, while its
  handshake still puts its gate in at the players' tick); any start spends a kept press; and the late line goes only
  with an army still missing.
- **28.** Overturned by Ruling 29. A second F2 press while the handshake waits cancelled the kept press: no HELLO, nothing
  restarted, the handshake carrying on.
- **29.** Overturns Ruling 28: a second F2 press while the handshake waits is ignored. The kept press stands, no HELLO is
  resent and nothing is cancelled, so the kept press still starts third person on completion. A cancel gives no
  feedback, so a player who pressed twice to make sure would wait for a start that never comes; and with every player
  modded the wait is about a second, so a cancel buys almost nothing. If wrong: a player who pressed by mistake has
  third person start when the handshake completes, and stops it with F2.

## Live session checklist

What only two machines can answer, each with its measurement. The item numbers are fixed, since
`docs/BATTLE_ENGINE_RE.md` section 14 and the rulings cite them; the order below is the order to run them, top to
bottom. **Nothing is uploaded until items 10 and 12 are answered (Ruling 15).** The handshake is built (Rulings 25 to
27), so a lobby with one player lacking the pack never starts it and never puts the gate in, and sends nothing unless
someone presses F2; item 12 checks that A's one HELLO leaves such a battle in step, and item 10 that the gate going in
mid-battle does on every machine.

### Before the session

- **Two machines.** The author knows of no LAN mode in WH3 (not checked here), so each player needs a Steam account
  that owns WH3. One PC is an unverified option: a second Steam client and account under Sandboxie, a route reported for
  WH2 (source not recorded) and not tried on WH3. Its latency is the best case only, so item 2 measured that way is a
  lower bound.
- **The same pack on both**, built after the last code change. After copying it in, delete `loadfast_cache_<env>.bin`,
  or the old Lua keeps running. Script logging on, on both.
- **The probes** (`Modding Files/source/lord_control/probes/`): Task 2's `zz_tp_mp_watch.lua` (the per-tick record),
  `zz_tp_mp_issue.lua` and `zz_tp_mp_override.lua` (pushes and forged overrides). `zz_tp_mp_hash.lua` is not written yet:
  every 1 s of model time it logs one number per machine, the sum over every model of every army of
  `x * 31 + z * 17 + hp`, rounded to 0.01 (the plan, `docs/superpowers/plans/2026-10-21-third-person-multiplayer.md`,
  Task 3). Items 7 and 8 read the mailbox block, `_G.DERPY_TP.P.mailbox`: `count` `+0x54`, `nfrags` `+0x58`, `fragtab`
  `+0x60`, the 16 entries from `+0x100` (16 bytes each, the id at `+8`), the HELLO mask `+0x5c` (bit n for army slot
  n). Every probe runs inside `pcall`: one Lua error
  wedges the bridge.

### Battle 1: a 1v1, both players with the pack

At load and in deployment:

- **The refusals.** Neither script log has a `derpy_tp: multiplayer is off` line. If one does, its reason is the
  refusal (`BATTLE_ENGINE_RE.md` section 13, "As built", "Refusals").
- **3. The client's gate bytes.** The battle's `+0x3b0` and `+0x3b1` on the host and on the client, from load to the
  end. If either is set on the client, every push there is refused, CA's own script wrappers included.
- **16. Commands before Deployed.** F2 does nothing before Deployed by design (Ruling 20). From a probe, push a MOVE and
  a GUARD_ON during deployment, and a GUARD_OFF after. Pass: both execute at the same tick on both machines, and the
  guard is still in the table after Deployed.

At Deployed, in this order (the handshake step is the battle's first F2):

- **Build time.** Read `derpy_tp: the fragment table took <n> model ms (<r> real ms), <k> fragments` on both: the real
  ms is the cost, the model ms whether the battle waited for it. A peer whose table is not built yet does not answer a
  HELLO until it is (Rulings 25 and 26), so nobody starts before every table is there.
- **Nothing sent.** Before anyone presses F2, run 10 s and read both machines' sent records: no HELLO, no carrier, and
  the mask `+0x5c` 0 on both (Ruling 26).
- **The handshake.** Press F2 on A with a unit selected. Read `derpy_tp: human armies <slots> of <armies> all said
  HELLO by <ms> model ms: the order gate is in` on both. Pass: the same slots and the same ms on both, the mask `+0x5c`
  holding exactly those bits, B's HELLO sent without a press on B, and A in third person with no second press. If
  `derpy_tp_mp_needs_everyone` shows on A instead (5 model s after the press), the log has `multiplayer waits: human
  armies <slots> of <armies>, no HELLO from <slots>`, naming who is missing, or another `multiplayer waits:` line saying
  why.
- **8. Copy table and the human armies.** `nfrags` and the set of original fragments, by unit type, on both. Pass:
  equal, with every army's fragments present. Record what `army:is_player_controlled()`, `is_reinforcement_army()`,
  `bm:local_alliance()` and `bm:local_army()` return for each army on each machine: the first decides the handshake's
  human armies. Pass: every machine logs the same slots (the `human armies <slots> of <armies>` part of either line),
  and they are the armies with a player at a keyboard. If it is true for each machine's own army alone, both logs say
  `multiplayer waits: the battle reports human armies <its own slot> of <armies>` and the pack stays off in
  multiplayer. Run once in the 1v1 and once in the 2v2. Once, run it in a battle with an AI reinforcement army: a unit
  not yet on the field is left out, not the table. Once, a campaign battle with a player's own reinforcing army: if that
  army is a human entry of its own, the handshake never completes (safe; the message blames the other players).
- **10. The gate on vanilla units.** The gate now goes in at the handshake's tick, from a model callback, while the
  battle's workers may be updating men (`BATTLE_ENGINE_RE.md` section 14). Pass first: the per-tick clip log of every
  man stays equal on both machines across that tick. Then, while nobody plays, log every man's queued holder every tick
  (`+0x5c8`; has `+0x6f8`, started `+0x6f9`). If no vanilla man ever has a parked action, the gate is inert without the
  mod playing. Also compare a lasting AI melee with the gate in (net mode) and out (the pack off on both).

Forged commands, from probes:

- **1. The network carries the forged commands.** On A push 20 each of MOVE, HALT, FOLLOW, play and carriers (GUARD_ON,
  GUARD_OFF, DISARM with each flag pair, ARM). On B log, per tick, the named man's command vtable, queued holder,
  `+0x308` and the guard table. Pass: every command is seen on B at the model tick A saw it, the carrier's effect is
  identical, and `exe+3d10794` stays -1.0 on both, because the cave skips the store.
- **2. The delay.** For 20 pushes, the model ms from the push to the effect, on A and on B; the median and the maximum.
  Set `DELAY_TICKS` in `tools/third_person_lockstep.lua` to it and re-run the lockstep suite
  (`py tools/build_third_person.py --selftest`), and set `P.net_delay`, which `late()` uses.
- **17. Queue integrity.** Commands sent on A over the 10 minutes against the records executed on B: no gap and no read
  error. A forged push is three separate calls from Lua, not one C call, so a frame's hand-off could fall between them.
- **9. The double free.** Settled offline by Ruling 18 (`lock cmpxchg` on both free paths): no measurement.

Played, both players at the keys:

- **11. `bm:disable_orders(true)` is local.** With A in third person, B gives right-click orders to its own units.
  Pass: they execute on both and the hash stays equal.
- **4. No divergence.** `zz_tp_mp_hash.lua` every second, plus the clip of every man every tick (Task 2's fastest
  detector), on both, for 10 minutes. Pass: the logs are equal to the end. Play near buildings once: the camera-floor
  patch is taken to be camera-only (`BATTLE_ENGINE_RE.md` section 12).
- **5. Swings and shots in a melee.** A disarmed man in a lasting melee, 20 clicks and 10 shots. Log `+0x308` per tick on
  both. Pass: equal every tick, and every swing plays on both.
- **Unseen swings (Ruling 22).** Over a 10-minute melee, count the swings sent that never showed before their give-up.
  If they are common, the block shortens to `LOCK_WAIT + late()`.
- **15. HALT on a playing clip.** Release W during a swing's tail, a running swing and a jump's landing. Is the clip cut?
- **14. FOLLOW for aiming.** How far a standing man turns toward the crosshair before a shot (Task 2: 55 of 90 degrees).
- **18. The unit classes the author named.** A regiment man, a unit of one, a rider (MOVE names the mount), a
  transformation, an ability (the CCO cast was never replayed, and `perform_special_ability_ground` was never traced).
  For the regiment man and the rider, check that he walks again as soon as his swing has played (Ruling 24).
- **7. Guard table.** Every second, `count` and the 16 entries, as ids, on both. Pass: the same ids on both, and `count`
  equal to the entries in use, through deaths, F2 off and on, and a unit of one's own attack orders.
- **6. A played man dies with commands in flight** (W held, a swing queued, a hold). Pass: no crash, no corpse that walks
  or plays, and the same on both. Record whether a dead man's update still runs, which decides whether the update cave's
  free ever fires.
- **20. The battle ends mid-clip.** Complete, back to the lobby, no crash.

### Battle 2: a 2v2 against the AI, same game session

- **19. A second multiplayer battle in the same process.** The first left the gate in; the second build takes it out as
  it loads, and its own handshake, at the first F2, puts it back. Pass: no `multiplayer is off` line, the mask `+0x5c` 0
  before that press, the HELLO line at the same ms on both, and the hash stays equal.
- **4, second half.** Both humans in third person at once for 3 minutes or more. Pass: the hash logs are equal to the end.

### After the battles

- **13. A multiplayer replay.** Load battle 1's replay: what `bm:is_multiplayer()` reads inside it, what
  `army:is_player_controlled()` returns for each army there (nobody controls one in a replay; false for all leaves the
  gate out for the whole replay), whether the recorded HELLOs fill the mask `+0x5c`, whether the replay's `human armies
  ... all said HELLO by <ms> model ms` line shows the battle's slots and model ms, and whether it reproduces the battle
  (the per-tick watch log in the battle against the same in the replay).
- **12. A mismatched lobby.** Does a lobby start when B lacks the pack, or memreader Plus? If it does: first, nobody
  presses F2 for a minute; A sends nothing at all (Ruling 26) and the hash stays equal. Then A presses F2: A sends one
  HELLO and never starts, `derpy_tp_mp_needs_everyone` shows on A 5 model s after the press and not before, A's log
  names B's slot as missing, the gate never goes in on A, and A's log has no `all said HELLO` line. On B, A's HELLO is a
  vanilla reload-time order whose value lands in RELOAD_TIME's global (`exe+3d10794`), which nothing is known to read;
  read it on B. Pass: the hash equal on both for the whole battle, through A's HELLO. Then push 10 each of MOVE, HALT,
  FOLLOW and carriers from A by probe, and record whether B crashes and whether the hash diverges.

The results go into a dated session record, and each answered question comes out of `BATTLE_ENGINE_RE.md` section 14.
