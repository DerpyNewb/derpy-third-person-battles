# Third-Person Battles in Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Third person works in a multiplayer battle (co-op and versus): each player can play one of their own units, and the battle stays in sync on every machine.

**Architecture:** A WH3 battle is lockstep. Every machine runs the same simulation and the same scripts, and anything that changes the battle has to reach every machine at the same tick, through the battle command queue. The mod today changes the battle three ways: the play command (already queued), direct memory writes (steer, heading, guard, the fragment swap, the order-gate byte) and `uc:` calls (their multiplayer behaviour is unknown). The design is **the owner decides, the queue carries it**. Only the player's own machine reads their keys and decides. Every change to the battle leaves that machine as a queued command. Moves are the engine's own unused per-man overrides (MOVE, HALT, FOLLOW_FIRST_PERSON). Clips use the play command, as today. State toggles (guard, disarm) ride a 32-bit **carrier** in a reload-time override whose value nothing reads, and a cave decodes the carrier on every machine at the same tick. (Redesigned after Tasks 1-2; see the note at the top of Phase 1.) Phase 0 measures whether such a route exists. Phase 1 is built only if it does, and its first task is an offline two-machine simulation that every later task is tested against.

**Tech Stack:** Lua 5.1 (game script, float32 numbers), memreader Plus (`mr.*`), x64 caves assembled by keystone and tested under unicorn (`tools/third_person_cave.py`), Ghidra 12.1.4 headless (`tools/ghidra_decompile.py`), the offline harness (`tools/third_person_harness.lua`, run by `py tools/build_third_person.py --selftest`), the wh3-mcp bridge for live probes.

**Spec:** None. The request is "make the third-person mod multiplayer compatible", plus "tests that simulate both local machines playing". About 30 players asked for multiplayer (`docs/sessions/WORKSHOP_REPORTS_20261021_THIRD_PERSON.md`, "Multiplayer / co-op"; Operator asks whether memreader rules it out). The original design's multiplayer stance is `docs/superpowers/specs/2026-10-13-third-person-pack-design.md` section 8. Phase 0's decision record serves as this plan's spec for Phase 1. If Phase 0 contradicts a Phase 1 task below, re-plan that task. Do not bend the measurement to fit it.

## Global Constraints

- Build `6acec6f4` only. On any other build `P.features.net` is false and multiplayer gets today's message.
- `platform.lua` stays the only file with an address, an offset or an `mr.` call. Every other module calls `P.*` exactly as it does now. Its pure functions (`M.carrier`, `M.uncarrier`, `M.split`) touch no `mr`.
- Game Lua numbers are float32: every RVA must be exact in float32 (`tools/third_person_patterns.py` checks), and large values go through `M.split`.
- Code that runs on **every** machine (anything not driven by the local player's keys) uses model-time callbacks (`bm:repeat_callback`), never `bm:repeat_real_callback`. It uses `ipairs` or `dpairs`, never `pairs`, and never `math.random` (CA, `battle/lua.html`).
- Code that runs only on the owner's machine (the existing `frame()` loop) may read local state freely. It must never change the battle except through a queued command: a native override, the carrier, `P.play`, or a `uc:` / `bm:` call (Task 6).
- Camera, cursor, HUD, shortcuts, tooltips and banners are local and stay local (`set_banners_enabled`, never `enable_unit_ids`; `cam:move_to(..., false)` as now).
- Player text: plain words, no emojis, no jargon (memories `player-text-plain-words`, `no-emojis-anywhere`).
- Public repo `repos/derpy-third-person-battles`: no decompiled C and no probe dumps (memory `third-person-github-repo`). The decision record cites RVAs and behaviour, not pasted pseudocode.
- Live tests: launch with `used_mods.txt`, never `wh3_start`; pictures via `common.take_screenshot`; `tools/wh3_test_prefs.py --apply` / `--revert`; quit the game when done (memories `wh3-live-test-ingame-screenshot-and-mod-list`, `test-game-settings`, `end-game-after-live-tests`). Drive the pack over the bridge. Real keys steal the author's cursor (`third-person-real-keys-steal-the-cursor`).
- **What the two-machine simulation proves and what it does not.** It proves the MOD keeps lockstep discipline: only the owner decides, every change goes through the queue, code run on both machines is order-independent, and the queue delay drops nothing. It cannot prove the ENGINE carries a command to the other machine, or that the cave decodes correctly. Those are Task 3, the cave selftest (Task 7) and Task 10. A green simulation is never reported as "multiplayer works".
- This workspace is not a git repo. Each task ends with its selftests green instead of a commit. The public repo is synced (`py tools/sync_third_person_repo.py`) only when the user asks.

## Review Focus

1. **A peer without the mod.** It runs MOVE, HALT, FOLLOW and the clips with CA's own code, and a carrier lands in a global nothing reads. But the guard, the disarm and the gate change the battle only where the mod runs, so such a peer desyncs. Live: Task 3, step 4 (does a mismatched lobby start at all). Offline: the cave case `vanilla_value_untouched` (Task 7) and, if a handshake is needed, `T.ls_a_peer_without_the_mod_is_never_sent_to` (Task 9).
2. **The queue delay is longer than the single-player windows.** `F.pending`, the swing lock (0.19-0.31 s to see the clip) and `STEER_GAP` were measured with a one-tick delay. Task 2 measured two ticks on one machine, and the network adds more. A clip may arrive after its window closed, and the swing is dropped as never seen. Pinned by `T.ls_a_swing_survives_the_queue_delay` (Task 6).
3. **A MOVE in the same tick as a clip cancels the clip.** One parked action per man, and the later command wins (Task 2). Holding W while clicking would eat every swing. Pinned by `T.ls_a_swing_is_not_cancelled_by_a_move_in_its_tick` (Task 6).
4. **The played man dies with commands in flight.** A command naming a dead or vanished man must be dropped on every machine, never written to a freed model. Pinned by `T.ls_a_command_for_a_dead_man_is_dropped_on_both` (Task 5) and the cave cases `unknown_id_dropped` / `dead_man_dropped` (Task 7).
5. **A man whose id does not fit the carrier's 16 bits** (ids reached 4,265 in a 40-unit battle; a 4v4 on large unit sizes, or summons, can go higher). It is refused, never wrapped onto another man. Pinned by `T.an_id_past_16_bits_is_refused` (Task 4).

---

## Phase 0: Feasibility (nothing ships)

Deliverable: `docs/sessions/MP_FEASIBILITY_<YYYYMMDD>_THIRD_PERSON.md` (the decision record), plus `docs/BATTLE_ENGINE_RE.md` gaining **section 13, "Multiplayer and the command queue"**, with the current section 13 "Open" renumbered to 14. Add one line to `docs/SESSION_INDEX.md`.

### Task 1: Static RE of the queue's route to other machines

**Files:**
- Create: the decision record (above), section "Static"
- Modify: `docs/BATTLE_ENGINE_RE.md` (new section 13)

**Interfaces:**
- Produces: for build `6acec6f4`, the answer to each question below as an RVA plus one sentence, or "not found" plus what was searched. Later tasks use these names: `SEND` (the function that puts a command on every machine), `READER_HOOK` (the point in the tag-0x28 reader after the model id resolves to a pointer), `CARRIER_SLOT`, `MODEL_CLOCK` (where model time is read).

- [ ] **Step 1: Q1, what `cmd_push` (`exe+2e9b974`) does.** Decompile it and its callees with `py tools/ghidra_decompile.py`. Record whether it only enqueues locally or hands the serialized command to a send path, and name the serializer-for-the-wire if there is one.
- [ ] **Step 2: Q2, the player's own move order.** Find the command type a right-click move builds (search the command-type metadata the way `HANDOFF_20261020_THIRD_PERSON_FLAMETHROWER_PROBES.md` item 1 found `BCQ_FIRE_PROJECTILE`) and the function that pushes it. If that function is not `cmd_push`, it is the `SEND` candidate.
- [ ] **Step 3: Q3, the sender check.** On the receiving side, record any check that rejects a command naming a model outside the sender's army.
- [ ] **Step 4: Q4, a slot with no clip.** In the tag-0x28 reader (`exe+2ecf4dc` region; `BATTLE_ENGINE_RE.md` section 6), record what happens when the man's fragment reads `0xffff` at the slot. It may return before building an action, or build one that does nothing. Pick the `CARRIER_SLOT` candidate: a slot under 2330 (a fragment is 0x1284 bytes) that reads `0xffff` in every fragment of a probe battle with one army from each race. Record `READER_HOOK`: the first instruction after the model id has become a pointer, with the 5+ bytes a jump there would displace.
- [ ] **Step 5: Q5, model time.** Record where `bm:time_elapsed_ms()` reads model time, as a path from `[exe+battle]` the cave can follow. `P.steer` writes model time into the walk builder's `buf + 0x4c`, and in Phase 1 the cave writes it instead.
- [ ] **Step 6: Q6, the `uc:` calls.** For each call the mod makes (`halt`, `goto_location`, `attack_unit`, `attack_location`, `fire_at_will`, `melee`, `change_behaviour_active`, `change_current_walk_speed`, `set_invincible`, `set_current_ammo_unary`, `trigger_projectile_launch`, the ability call in `abilities.lua:19` / `hud.lua:285-287`, `take_control` / `release_control`), trace its script binding. Record whether it reaches `cmd_push`, `SEND`, or writes the battle directly.
- [ ] **Step 7: Verify.** Every row answered. `py tools/third_person_patterns.py` still exits 0 (nothing changed). Grep the record for pasted pseudocode (`{` followed by `;` on one line); none.

### Task 1b: The engine's per-man override commands as the carrier

Added 2026-10-21 by ruling. Task 1 found that the play command keeps only 11 bits on the wire besides its slot: the slot travels as one of 2,260 names, the byte raw, and the mask as one of 8 names. Task 4's byte + u32 format cannot fit in that. Task 1 also found an unused family of per-man commands that nothing pushes, `BCQ_ENTITY_USER_OVERRIDE_*`. Its MOVE handler (`exe+2ecfb0c`) reads a model, a position, a u16 and four bytes, and parks a move action in the man's queued holder. Native commands would need no reader cave, and a peer without the mod would run them with CA's own code.

**Files:**
- Modify: the decision record, new section "Override commands"; `docs/BATTLE_ENGINE_RE.md` section 13 (one subsection)

**Interfaces:**
- Produces: the carrier recommendation Task 4 is redesigned from. For each override type, which mod operation it covers. For each recommended type: its pusher recipe (type global, buffer layout).

- [ ] **Step 1: O1, the wire.** For every `BCQ_ENTITY_USER_OVERRIDE_*` type (MOVE, JUMP, TELEPORT, ATTACK, HALT, FOLLOW_FIRST_PERSON, the aim and reload overrides), record its type global, handler, version and the fields its handler reads. Find its serializer (the vtable whose slot 0 writes those fields, as `exe+39077e8` slot 0 = `exe+2eecc50` does for ANIMATE) and record each field's width on the wire: a float, a raw integer, or a name from a table.
- [ ] **Step 2: O2, what MOVE does to the man.** Which holder, which action class, and how it moves him (to the point, at what speed and gait, facing which way). When it ends. What his regiment's per-tick order does to it on vanilla, and with the order-gate patch in (`P.gate`, `BATTLE_ENGINE_RE.md` sections 7-8).
- [ ] **Step 3: O3, one row per other override:** what it does to the man, in one sentence each.
- [ ] **Step 4: O4, how to push one.** Does any pusher exist? If not, the recipe for forging one the way `P.play` forges ANIMATE: the type global, the buffer layout the serializer reads, and the push call.
- [ ] **Step 5: O5, coverage.** Map the mod's operations (steer: point, run, sprint speed, heading; hold; face; guard: stop the engine's own orders; disarm: no auto attack) to override types. List what no override covers.
- [ ] **Step 6: Recommend.** Recommend either the override commands, or the play-command carrier at 11 bits plus the slot name as data, or a mix. Give the bits per operation and the number of commands per operation for each option. No live game; Task 2 tests the recommendation live.

### Task 2: Replay measurement (one machine)

A replay re-runs the battle from its recorded commands, and the mod stays idle in replays. So whatever a replay reproduces without the mod went through the recorded stream. This is the only engine-side determinism test that needs one machine.

**Files:**
- Create: `Modding Files/source/lord_control/probes/zz_tp_mp_issue.lua` (issues the calls), `Modding Files/source/lord_control/probes/zz_tp_mp_watch.lua` (records what happened; runs in the battle and in its replay)
- Modify: the decision record, section "Replay"

**Interfaces:**
- Consumes: Task 1's RVAs.
- Produces: a table with one row per call class (the 14 of Task 1, step 6, plus `P.play` and the mailbox `P.steer` as the control that must NOT replay): issued at, observed in the battle, observed in the replay, verdict `recorded` / `not recorded`.

- [ ] **Step 1: Write `zz_tp_mp_watch.lua`.** On a model-time `repeat_callback` every 0.1 s, it logs per unit: position, `unique_ui_id`, `is_behaviour_active("fire_at_will")`, `is_behaviour_active("defend")`, men alive. For the probe's one played man it also logs `P.anim_slot`, `P.heading` and position. Lines are keyed by model time so the battle's log and the replay's line up.
- [ ] **Step 2: Write `zz_tp_mp_issue.lua`.** Each call class goes to its own unit at its own model time, 5 s apart, so every effect is attributable.
- [ ] **Step 3: Run it.** Custom land battle, one army of 8+ mixed units against an idle AI army. Run both probes over the bridge, let it run 90 s, end the battle and save the replay.
- [ ] **Step 4: Load the replay and run `zz_tp_mp_watch.lua` in it.** Compare the two logs at each issue time ±1 s.
- [ ] **Step 5: Verify.** The control must read `not recorded`; if `P.steer` replays, the probe is wrong, not the engine. A plain player right-click order made by hand during the battle must read `recorded`; if not, the replay comparison is wrong. Fill the table.
- [ ] **Step 6 (added by ruling after Task 1/1b): the carrier's own live checks, in the same session.**
  - Push each override type Task 1b recommends, forged per its recipe in the decision record's "Override commands" section, on one man. Push MOVE (steer), HALT (hold), FOLLOW_FIRST_PERSON (heading) and one RELOAD_TIME carrier. Record what he does, and whether the replay reproduces it. Answer Task 1b's open questions:
    - which way a MOVE walk faces him (it sends no heading)
    - whether MOVE re-sent every 0.1 s keeps him walking in a lasting melee, with and without the gate patch
    - whether a MOVE and a clip for the same man in one tick cancel
    - whether the RELOAD_TIME carrier changes anything visible (reload bars, fire rate) on any unit
  - Read every loaded fragment, including each mounted man's mount fragment at slot 129 (`RIDER_TESTUDO` 2123 pairs with mount slot 129 in the slot table), for Task 1's `CARRIER_SLOT` candidates 2123, 2126 and 2127, and record which read `0xffff` everywhere.
  - Log the battle's `+0x3b0` and `+0x3b1` bytes for Task 3 to compare on a client.

### Task 3: Two-machine measurement

**Needs the user:** two PCs (or one PC and a second Steam account that owns WH3) and a multiplayer custom battle. Nothing in this task can be faked on one machine.

**Files:**
- Create: `Modding Files/source/lord_control/probes/zz_tp_mp_hash.lua` (desync detector)
- Modify: the decision record, section "Two machines"

**Interfaces:**
- Produces: which call classes reach machine B when issued only on A; the queue delay (A's push to execution on A, and on B, in model ticks); whether the lobby starts a battle with mismatched mod lists; whether B without the mod survives the forged overrides and the carrier. Task 5's `delay_ticks` default comes from here.

- [ ] **Step 1: Write `zz_tp_mp_hash.lua`.** Every 1.0 s of model time it logs one number per machine: the sum over every model of every army of `x * 31 + z * 17 + hp`, rounded to 0.01, keyed by model time. Equal logs mean no divergence.
- [ ] **Step 2: Run the Task 2 issue schedule on A only**, with the hash and the watch probe on both. Compare B's watch log to A's: a call class that shows on A and not on B is local-only, and the hash diverges at its issue time.
- [ ] **Step 3: Measure the delay.** For `P.play` (and `SEND`, if Task 1 found a different route): record the model time it was pushed and the model time `P.anim_slot` first reads the slot, on A and on B, over 20 pushes. Report the median and the maximum.
- [ ] **Step 4: Mismatch and the vanilla reader.** Try a lobby where B lacks the third-person pack. If the battle starts, push from A 10 each of MOVE, HALT, FOLLOW_FIRST_PERSON and RELOAD_TIME carriers (Task 2's `zz_tp_mp_override.lua`), and record whether B crashes and whether the hash diverges.
- [ ] **Step 5: Verify.** Both hash logs exist for the whole battle, and the uncontrolled part (a hand-made right-click order on each side) does not diverge. If it does, the hash probe is wrong.

### Gate

- [ ] **Write the verdict at the top of the decision record.** **GO** only if the forged MOVE, HALT, FOLLOW_FIRST_PERSON, the play command and the RELOAD_TIME carrier pushed on A run on B at the same tick with every field intact (the carrier's 32 bits unchanged), and B without the mod survives them. Otherwise **STOP**: the record says which question failed, and that answer goes to the Workshop thread (Operator's question). Then list the measured delay, any `uc:` call class that did not reach B, the `+0x3b0` / `+0x3b1` bytes on the client, and whether mismatched lobbies start.
- [ ] **Show the user the verdict and the delay** before Phase 1. A delay the user finds unplayable is a STOP as well.

---

## Phase 1: The port (only after GO)

**Redesigned 2026-10-21 by ruling, from Tasks 1, 1b and 2** (`docs/sessions/MP_FEASIBILITY_20261021_THIRD_PERSON.md`). The plan's first design piggybacked everything on the play command. Its wire keeps 11 bits, so that design is withdrawn. What replaces it:

| Mod operation | Single player today | Multiplayer |
|---|---|---|
| steer | `P.steer`: mailbox walk, the steering copies, `+0xb0` | **MOVE** (model, x y z, run, speed): the engine's own walk; he faces his path |
| hold | `P.hold`: mailbox stop | **HALT** (model) |
| face, standing | `P.face`: writes `+0xb0` | **FOLLOW_FIRST_PERSON** (model, u16 heading). Turns only a man not busy, partly (55 of 90 degrees in 1.3 s, measured) |
| swing, shot, cheer | `P.play` (ANIMATE) | unchanged: already queued |
| guard | `P.guard` each frame: the mailbox stops the engine's four orders | **carrier** GUARD_ON at start, GUARD_OFF at stop; the update cave reads a per-man flag |
| disarm, arm | `P.disarm` / `P.arm`: fragment pointer swap from the script | **carrier** DISARM / ARM; the carrier cave swaps the pointer on the battle thread |
| order gate | `P.gate` toggled per session | patched in at load on every machine, for the whole battle |
| `uc:` / `bm:` calls | as they are | unchanged: all recorded (Task 2) |

The **carrier** is a forged `BCQ_ENTITY_USER_OVERRIDE_RELOAD_TIME` whose 32-bit float field holds raw bits. The engine stores that value in a global nothing reads (Task 1b, scan; Task 2, fire rates unchanged). A cave at `exe+2ecfcb7` decodes it. On a machine without the mod the value lands in that unread global and does nothing.

### Task 4: The carrier word, as pure Lua

**Files:**
- Modify: `Modding Files/source/third_person/script/derpy_tp/platform.lua` (`M.carrier`, `M.uncarrier`, `M.OPS`; no `mr`)
- Modify: `tools/third_person_harness.lua` (`H.platform_module()` loads the real `platform.lua` and returns its `M`)
- Modify: `tools/third_person_tests.lua`

**Interfaces:**
- Produces: the one carrier format the simulation, the platform and the cave all use.

| bits | field |
|---|---|
| 31-24 | magic `0xD7`: a large negative float no vanilla reload time holds; vanilla values here are 0.2 (`0x3E4C...`) and -1.0 (`0xBF80...`) |
| 23-20 | op: 1 GUARD_ON, 2 GUARD_OFF, 3 DISARM, 4 ARM, 5 HELLO (Task 9, only if mismatched lobbies start) |
| 19-16 | flags: DISARM bit16 shots, bit17 charge |
| 15-0 | the man's id, his `+0x258` (Task 2: ids 1 to 4,265 in a 4,185-body battle) |

  `M.carrier(op: string, id: integer, flags: table|nil) -> hi: integer, lo: integer` returns the word as two u16 halves, because a u32 above 2^24 is not exact in float32 (game Lua). It errors on an id outside 0..65535. `M.uncarrier(hi: integer, lo: integer) -> table|nil` gives `{op, id, shots, charge}`, or nil when the magic is absent.

- [ ] **Step 1: Write the failing tests.**

```lua
T.the_carrier_round_trips = function()
	local M = H.platform_module()
	for _, c in ipairs({{"GUARD_ON", 1}, {"GUARD_OFF", 65535}, {"DISARM", 4265, {shots = true, charge = true}},
		{"DISARM", 7, {shots = false, charge = true}}, {"ARM", 0}}) do
		local d = M.uncarrier(M.carrier(c[1], c[2], c[3]))
		check(d and d.op == c[1] and d.id == c[2], c[1] .. " " .. c[2])
		check(d.shots == (c[3] and c[3].shots or false) and d.charge == (c[3] and c[3].charge or false), "flags")
	end
end

T.vanilla_reload_times_are_not_carriers = function()
	local M = H.platform_module()
	check(M.uncarrier(0x3E4C, 0xCCCD) == nil, "0.2")
	check(M.uncarrier(0xBF80, 0x0000) == nil, "-1.0")
end

T.an_id_past_16_bits_is_refused = function()
	local M = H.platform_module()
	check(not pcall(M.carrier, "GUARD_ON", 65536), "refused, never wrapped onto another man")
end
```

- [ ] **Step 2: Run `py tools/build_third_person.py --selftest`.** Expected: the three FAIL (`carrier` is nil).
- [ ] **Step 3: Implement.** Integer arithmetic on the two halves only (game Lua has no bit library); every intermediate under 2^24.
- [ ] **Step 4: Run the selftest.** Expected: all pass.

### Task 5: The two-machine simulation

Two copies of the shipped mod, A and B, in one Lua process. Each has its own keys, frame rate, army and fake battle, and they share one fake command queue. After every model tick the simulation compares what each machine's battle **applied**. Lockstep means the two applied logs are equal, tick by tick.

**Files:**
- Create: `tools/third_person_lockstep.lua` (defines the global `L`; loaded by the harness after its own definitions)
- Create: `tools/third_person_lockstep_tests.lua` (tests named `T.ls_*`)
- Modify: `tools/third_person_harness.lua` (two small changes, below)
- Modify: `tools/build_third_person.py` (`--selftest` runs the harness on both test files and fails if either does)

**Interfaces:**
- Consumes: `M.uncarrier` (Task 4).
- Produces, for Tasks 6-9:
  - `L.new(opts) -> world`. `opts.machines` is a list of `{name, fps, army, mod = true, pairs = "normal" | "reverse", fresh = <H.fresh opts>}`, default A at 60 fps playing army 1 and B at 40 fps playing army 2 with `pairs = "reverse"`. `opts.delay_ticks` defaults to 2: Task 2 measured every queued command taking effect two ticks after the script call on one machine. Task 3 replaces it with the network figure, marked PROVISIONAL in a comment until then.
  - `world:on(name, fn)` runs `fn` with machine `name` swapped in, for setup, reads and `H.down` / `H.up`. Never `H.tap` or `H.step` inside it: they move one machine's clock alone, and the simulation is out of step before the mod is.
  - `world:tap(name, key)` is `H.down` on that machine, one lockstep tick, then `H.up`. Keys are the harness's physical names (`"F2"`, `"W"`, `"Left mouse"`).
  - `world:run(seconds)` advances both machines in lockstep. Each 100 ms tick: deliver the due commands to every machine in (due tick, sender name, sequence) order, then run A's frames for the tick, then B's.
  - `world:diverged() -> nil | string` names the first tick and the two differing applied entries.
  - `world:sent(name)` lists the commands that machine pushed, as `{kind, model_id, fields}`. Kinds: `move`, `halt`, `follow`, `play`, `carrier` (fields decoded with `M.uncarrier`), and `uc` (method name and args). `world:applied(name)` lists that machine's applied log, entries `{tick, kind, model_id, fields}`.
  - `world:inject(name, kind, model_id, fields)` appends to ONE machine's applied log. It exists only for the oracle's own test.

Harness changes (the whole of them):
1. `fake_platform()` grows a net mode. When `H.net` is set, `P.steer` -> `H.send("move", ...)`, `P.hold` -> `"halt"`, `P.face` -> `"follow"`, `P.play` -> `"play"`, and `P.guard` / `P.disarm` / `P.arm` -> `"carrier"`. `L` provides `H.send`. Locally they record and apply nothing. Without `H.net` they behave exactly as now, so every existing test is untouched.
2. `fake_platform().features.net = H.features.net ~= false`.

How `L` keeps two machines apart without rewriting the harness: every harness function reads the global `H` when it is called, not when it was defined. So each machine gets its own `H` (`setmetatable({}, {__index = H0})`, where `H0` is the harness's table with its functions). Swapping a machine in sets `H` and every global that loading the mod added to `_G`: the set is measured at load as the keys of `_G` after `H.fresh` minus the keys before, so a new global in the mod cannot leak between machines unnoticed. B's `H.env` overrides `pairs` to yield keys in reverse sorted order, which turns any `pairs` in code both machines run into a divergence. Until Task 9 lands the real switch, every machine loads with `mp = false` and `H.net = true` (ledger Ruling 4). The shipped entry file gets no test hook.

The fake engine, run on every machine at delivery, follows Task 2's measurements:
- **One parked action per man per tick, the later command wins** (a MOVE then a clip: the clip plays; a clip then a MOVE: the MOVE runs).
- A command for a missing man, or one with `hp <= 0`, is dropped and logged `dropped`.
- A carrier is applied as its op says: GUARD flag on the man, the DISARM kind, or ARM.
- A `uc` command is applied as recorded.
- Every application goes into that machine's applied log.
- A machine with `mod = false` applies the native kinds and logs every carrier as `carrier_ignored`, standing in for the vanilla engine, which writes the unread global.

- [ ] **Step 1: Write the failing tests** in `tools/third_person_lockstep_tests.lua`.

```lua
T.ls_the_oracle_catches_a_one_sided_write = function()
	local w = L.new({})
	w:run(0.5)
	w:inject("A", "follow", 1001, {angle = 100})
	w:run(0.2)
	check(w:diverged() and w:diverged():find("follow"), "a write on one machine is reported")
end

T.ls_machines_share_nothing = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() check(H.E.F.on, "A is on") end)
	w:on("B", function() check(not H.E.F.on, "B never saw A's key") end)
end

T.ls_two_machines_stay_in_step_while_A_plays = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(2.0)
	w:on("A", function() H.up("W") end)
	w:tap("A", "Left mouse")
	w:run(2.0)
	check(#w:sent("A") > 0, "A sent")
	check(#w:sent("B") == 0, "B decided nothing for A's man")
	check(w:diverged() == nil, tostring(w:diverged()))
end

T.ls_a_command_for_a_dead_man_is_dropped_on_both = function()
	local w = L.new({delay_ticks = 3})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(0.15)
	for _, n in ipairs({"A", "B"}) do w:on(n, function() H.units[1]._models[1].hp = 0 end) end
	w:run(0.5)
	check(w:diverged() == nil, tostring(w:diverged()))
end

T.ls_both_play_at_once = function()
	local w = L.new({})
	for _, n in ipairs({"A", "B"}) do w:tap(n, "F2") w:on(n, function() H.down("W") end) end
	w:run(3.0)
	check(#w:sent("A") > 0 and #w:sent("B") > 0, "both sent")
	check(w:diverged() == nil, tostring(w:diverged()))
end
```

- [ ] **Step 2: Run `py tools/build_third_person.py --selftest`.** Expected: `ls_the_oracle_catches_a_one_sided_write` and `ls_machines_share_nothing` FAIL (no `L`). The other two FAIL as well, with `sent("A")` empty: nothing routes through `H.send` yet.
- [ ] **Step 3: Implement `tools/third_person_lockstep.lua` and the two harness changes.**
- [ ] **Step 4: Run the selftest.** Expected: all five pass. The fake platform's net mode routes everything through the queue, so the two play tests are green against the fake. The real platform's sends are Task 6's, and the cave's decoding is Task 7's. Every existing single-machine test still passes.

### Task 6: `platform.lua` pushes native commands and carriers in multiplayer

**Files:**
- Modify: `platform.lua` (`M.build(mr, net)`; `BUILDS["6acec6f4"]` gains `move`, `halt`, `follow`, `reload_time` type globals per the record's "O4, pushing one"; `P.net_delay`)
- Modify: `main.lua` (guard on at start and off at stop, instead of each frame, when `P.features.net`), `combat.lua` (the windows that wait for a clip; no MOVE in the tick a clip is sent)
- Modify: `tools/third_person_tests.lua` (delete `T.no_hud_in_multiplayer`, and replace `T.multiplayer_and_replays_do_nothing` with `T.replays_still_do_nothing`), `tools/third_person_lockstep_tests.lua`

**Interfaces:**
- Consumes: `M.carrier` (Task 4), the forging recipes in the record (Task 1b).
- Produces: `P.features.net: boolean` (true only on `6acec6f4` in a multiplayer battle) and `P.net_delay: number` (seconds; 0.2 until Task 3, PROVISIONAL). In net mode:
  - `P.steer` pushes MOVE, at most one per man per model tick. It writes no steering copies and no `+0xb0`.
  - `P.hold` pushes HALT.
  - `P.face` pushes FOLLOW.
  - `P.guard(m)` pushes GUARD_ON once per session, and `P.unguard(m)` (new) pushes GUARD_OFF.
  - `P.disarm` / `P.arm` push the carrier, only when the kind changes.
  - `P.play` is unchanged.

  The `P.*` signatures other modules call are unchanged, apart from the new `P.unguard`.

- [ ] **Step 1: Write the failing tests.**

```lua
T.ls_at_most_one_move_per_tick = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(1.0)
	local n = 0
	for _, c in ipairs(w:sent("A")) do if c.kind == "move" then n = n + 1 end end
	check(n >= 1 and n <= 11, "at most one move per man per 100 ms tick, got " .. n)
end

T.ls_a_swing_is_not_cancelled_by_a_move_in_its_tick = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(0.5)
	w:tap("A", "Left mouse")
	w:run(1.5)
	for _, n in ipairs({"A", "B"}) do
		local played = false
		for _, a in ipairs(w:applied(n)) do if a.kind == "play" then played = true end end
		check(played, n .. " played the swing")
	end
	check(w:diverged() == nil, tostring(w:diverged()))
end

T.ls_a_swing_survives_the_queue_delay = function()
	local w = L.new({delay_ticks = 4})
	w:tap("A", "F2")
	w:tap("A", "Left mouse")
	w:run(1.5)
	for _, n in ipairs({"A", "B"}) do
		local played = false
		for _, a in ipairs(w:applied(n)) do if a.kind == "play" then played = true end end
		check(played, n .. " played the swing")
	end
end

T.ls_guard_is_sent_once_per_session = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:run(2.0)
	w:tap("A", "F2")
	w:run(0.5)
	local on, off = 0, 0
	for _, c in ipairs(w:sent("A")) do
		if c.kind == "carrier" and c.fields.op == "GUARD_ON" then on = on + 1 end
		if c.kind == "carrier" and c.fields.op == "GUARD_OFF" then off = off + 1 end
	end
	check(on == 1 and off == 1, "one on, one off, got " .. on .. " and " .. off)
end

T.replays_still_do_nothing = function()
	H.fresh({replay = true})
	H.tap("F2")
	check(H.count("disable_orders") == 0, "nothing starts")
end
```

- [ ] **Step 2: Run the selftest.** Expected: the new tests FAIL, because the main loop still guards every frame and steers into the swing's tick.
- [ ] **Step 3: Implement.** Forge each command as `P.play` forges ANIMATE: the type global read at run time, the record layout the record gives, and `cmd_push`. Write the carrier's 32 bits as two u16 writes. The clip-waiting windows in `combat.lua` (`F.pending.till`, the lock's "seen" wait) add `P.net_delay` when `P.features.net`. A tick that sends a clip for a man sends him no MOVE.
- [ ] **Step 4: Run the selftest and `py tools/third_person_patterns.py`.** Expected: all pass.

### Task 7: The carrier cave and the per-man guard table

**Files:**
- Modify: `tools/third_person_cave.py`: a second assembly block `CARRIER` at `exe+2ecfcb7`, and the update cave's single man becoming a table of `ENTRIES = 16` guard entries. Plus `--check` and `--selftest`.
- Modify: `platform.lua` (the generated region; `BUILDS["6acec6f4"]` gains `reload_hook = 0x2ecfcb7`, resume `0x2ecfcbd`, both through `M.split`)

**Interfaces:**
- Consumes: the carrier word (Task 4), the cave site facts in the record: 6 bytes `F3 0F 10 44 24 30`, the value at `[rsp+0x30]`, the record in `rbx`, after the read-error test, re-run the displaced `movss` before resuming.
- Produces:
  - **The carrier cave.** On the magic it resolves the id to a model, the way the handlers do. GUARD_ON claims an entry for the man, and GUARD_OFF frees it. DISARM points his fragment at the copy of its kind, and ARM points it back. It then skips the global's store. Without the magic it resumes untouched.
  - **The update cave.** For a man with a guard entry it stops the engine's four orders, as the single-man guard does today.
  - **The copy table.** Built at "Deployed" on every machine for every fragment of every unit in every human army, in `ipairs` order. The table is `{orig, plain, shots, charge, shots_charge}` pointers in game memory. The content is the same on every machine; only the addresses differ.

- [ ] **Step 1: Write the failing selftest cases** under unicorn. Each word comes from running `M.carrier` under `lua.exe`, so the cave is tested against the same format the platform sends.
  - `vanilla_value_untouched`: 0.2 and -1.0 store into the global as before, and every register is as it came in.
  - `guard_on_claims_and_off_frees`
  - `two_men_guarded_at_once`
  - `seventeenth_man_dropped`: the other sixteen are unchanged.
  - `unknown_id_dropped` and `dead_man_dropped`: no write.
  - `disarm_swaps_to_the_kind`: each of the four flag pairs picks its column.
  - `arm_restores_orig`
  - `unknown_fragment_untouched`
  Also keep every existing case passing.
- [ ] **Step 2: Run `py tools/third_person_cave.py --selftest`.** Expected: the new cases FAIL.
- [ ] **Step 3: Write the assembly and the table builder.** The table builder is a model-time callback at "Deployed", `ipairs` only.
- [ ] **Step 4: Run `--selftest`, `--check`, and `py tools/build_third_person.py --selftest`.** Expected: all pass. Add two breaks: one that skips the magic compare, and one that guards the wrong entry. Both must be caught.

### Task 8: The order gate for the whole battle

**Files:**
- Modify: `platform.lua` (`P.gate`), `main.lua` (start and stop leave the gate alone in net mode), `tools/third_person_lockstep.lua` (the fake engine honours the gate as Task 2 measured), `tools/third_person_lockstep_tests.lua`

- [ ] **Step 1: Write the failing tests.**
  - `T.ls_the_gate_is_in_from_the_first_tick`: both machines' applied logs open with `gate on` at tick 0 and hold no `gate off` before "Complete".
  - `T.ls_a_move_in_melee_needs_the_gate`: a fake melee where the regiment orders the man each tick. Without the gate the MOVE never starts on either machine; with it, it starts on both, in the same tick.
- [ ] **Step 2: Run the selftest.** Expected: FAIL.
- [ ] **Step 3: Implement.** In net mode `P.gate(true)` runs at build and stays in until the battle ends.
- [ ] **Step 4: Run the selftest.** Expected: all pass.

### Task 9: Switch it on, and tell players what they need

**Files:**
- Modify: `Modding Files/source/third_person/script/battle/mod/derpy_third_person.lua` (the guard becomes: replays, or `bm:is_multiplayer() and not E.P.features.net`)
- Modify: `tools/third_person_lockstep.lua` (machines load with `mp = true`, dropping Ruling 4's `mp = false`)
- Modify: `tools/build_third_person.py` `LOC`: `derpy_tp_multiplayer` reads "Third-Person Battles is off in replays, and in multiplayer on this game version."; new key `derpy_tp_mp_needs_everyone`: "Third-Person Battles in multiplayer needs every player to have it and memreader Plus."
- Modify: `Modding Files/source/third_person/script/mct/settings/derpy_third_person.lua` (the description drops "It does nothing in multiplayer.")
- If Task 3 showed that mismatched lobbies start: a handshake. HELLO goes out once per human army at "Deployed". Third person in multiplayer starts only after every human army's HELLO has come back through the cave. Until then F2 says `derpy_tp_mp_needs_everyone`.

- [ ] **Step 1: Write the failing tests.**
  - `T.multiplayer_starts`: single machine, F2 with `mp = true` calls `disable_orders(true)`.
  - `T.another_build_keeps_mp_off`: `features = {net = false}` plus `mp = true` gives the subtitle `derpy_tp_multiplayer`.
  - With the handshake, `T.ls_a_peer_without_the_mod_is_never_sent_to`: B has `mod = false`, A presses F2. A sends no MOVE, A's log shows `derpy_tp_mp_needs_everyone`, and `diverged()` is nil.
  - With the handshake, `T.ls_play_starts_once_everyone_said_hello`.
- [ ] **Step 2: Run the selftest.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `py tools/build_third_person.py --selftest`, `--check` (loc keys used equal loc keys shipped) and `py tools/third_person_patterns.py`.** Expected: all exit 0.

### Task 10: Two-machine acceptance

**Needs the user**, as Task 3. The simulation has said what it can; this is the engine's answer.

**Files:**
- Create: `docs/sessions/LIVE_TEST_<YYYYMMDD>_THIRD_PERSON_MP.md`, `docs/sessions/PATCH_NOTES_<YYYYMMDD>_THIRD_PERSON.md`
- Modify: `docs/workshop/third_person/` page text (multiplayer now supported, what each player needs)

- [ ] **Step 1: Build the pack** with `py tools/build_third_person.py` and copy it to both machines (memories `always-deploy-to-workshop-folder`, `loadfast-cache-hides-a-local-deploy`).
- [ ] **Step 2: Run `zz_tp_mp_hash.lua` on both machines** through a 1v1 of 10 minutes and a 2v2 co-op against the AI, with both humans in third person at once for at least 3 minutes. On each side play: walk, sprint, a swing in a lasting melee, a shot, an ability, F2 off and on, a played man killed, a transformation. Cover a regiment played as one man and a unit of one (memory `third-person-test-with-real-input`: the unit classes the author named). Note how well a standing man turns to aim under FOLLOW. It turned 55 of 90 degrees in Task 2. Also check whether the command executor and the per-man updates run in separate phases of a tick: from the client's log, or with a probe that counts the carrier cave's and the update cave's hits per tick. If they overlap, the guard table's double free (Task 7, ledger) can desync and needs a `lock cmpxchg`. Size Task 6's swing-protection window from the measured delay.
- [ ] **Step 3: Verify.** The two hash logs are equal to the end of both battles. No desync message. Every listed action plays on both screens. Record the measured delay for steer and swing, and compare it with the `delay_ticks` the simulation used. If the live delay is larger, re-run the simulation's tests at the live figure before shipping.
- [ ] **Step 4: Patch notes** (short phrases, memory `patch-notes-short-phrases`) and the Workshop page text. Upload and repo sync only when the user asks.
