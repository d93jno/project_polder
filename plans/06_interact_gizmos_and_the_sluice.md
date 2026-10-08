# Phase 6 — Interact gizmos and the sluice: machines you can start, and water you can point

**Status:** completed — 6.0–6.5 shipped. §7 decisions locked.
**Tracks:** GDD v1.18 §3.1 (contact), §5.3 (AP), §5.6 (objectives: start / hold / stop the machine), §6.4 (redirection), §6.5 (the first-contact sluice); UI/UX v0.19 §3 (mid-fight water), §4.4 (reaction preview), §5 (confirm tier).
**Depends on:** Phase 5 (`plans/05_commit_and_undo.md`) — a sluice is a Confirmed-tier action, and it goes through the one confirm prompt and the undo history. Phase 4 — "is it Live?" for the knock, the hatch and the machine comes from fog. Phase 3 — the terrace is the bowl the machines are authored on.
**Goal:** the three things the terrace has been waiting for. A machine is data on a bowl with a state a command can change; interacting with one prices itself, names the Watches it would trigger and whether a Live hostile contests it before the player commits; and opening the sluice changes the water the whole rules layer reads, with a preview that shows exactly which cells change and what of the squad's stands in them.

---

## 0. Why this, and why not the alternatives

**Interact is a stub with a contact rule.** `InteractCommand` has kinds `GENERIC`, `KNOCK`, `MACHINE` and `TRAUMA_KIT`. For `MACHINE` it spends AP and starts contact if a Live hostile stands on the tile; it changes nothing on the map, because there is no machine to change. The three pieces already sit in the kit (`env_pump_house`, `env_sluice_gauge`, `env_hatch` in `PresentationCatalog`) and nothing on any bowl uses a pump house or sluice.

**Water cannot change mid-fight, and the GDD says it must, once.** The map is shared and read-only (`CombatState.duplicate_state()` shares `BowlMap` on purpose), and `water_step` / `water_z` live on it. The only code that writes them is the `F` debug toggle, which CLAUDE.md names as the one sanctioned exception. GDD §3.1 says water does not change mid-fight *except a chosen redirection*; §6.5's first-contact sluice is that redirection. So the rules need a way for a command to change the water *without* mutating a map another state is still reading. That is the one real design problem in this plan (§7.1).

**The preview already has a place to live.** UI §3 says the change "plays on the map tile by tile" and is "previewed before it is spent". `overlay_queries` is the only overlay source, and the confirm prompt exists after plan 05. The preview is the rule run on a duplicate state, which is how every other preview in the game works; it must not be a second implementation of what the sluice does (UI §1: if a preview and a rule disagree, the preview is the bug).

**Why not the neighbours.**

- *Table-scale redirection* (UI §8: which bowls step wetter, creep into the next bowl, how long it hangs wet) is table mode's. This plan does the fight-scale half: one bowl, one sluice, the tiles it changes.
- *First Gauge* (the founder's read that makes a sluice precise, GDD §8.3) is a trait with a once-per-fight rule. It is a plain interact here, a stub the trait can later gate. Spending it is a Confirmed action and registers with plan 05's mechanism, but the trait itself is out of scope.
- *More terrace content* (more houses, a second Watch) is authoring, and the sluice is enough authored content to prove the mechanism.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| What a machine is | **Authored data on the bowl, with its state in `CombatState`** | The same split as `Cell.occupant` (truth) and fog (knowledge): the map says a pump house is *here*; the state says whether it is *on*. A machine's state copies with `duplicate_state()`, so a command result stays independently branchable and undo needs nothing new. |
| Which machines | **Hatch, pump house, sluice** | The three kit pieces that exist. No new art (CLAUDE.md: no placeholder meshes, assets under existing categories). |
| What opening the sluice does to water | **One step wetter for the bowl, working default** | GDD §6.4: "the target sector walks one step wetter". The terrace has one plane, so the sector is the whole bowl (§7.2). |
| Preview | **The command run on a duplicate state, diffed** | One implementation. The preview lists the cells whose step changed and the squad bodies standing in them. |
| Confirm tier | **A sluice is Confirmed; a hatch and a pump are Committed** | UI §5 already lists "opening a sluice" as Confirmed. Registered through `Command.needs_confirm`, as plan 05 does for the bleeder. |

---

## 2. Layout

```
rules/machine.gd                       Machine: cell, kind, and the state a command can change
rules/combat_state.gd                  machines: Dictionary cell -> Machine, copied on duplicate
rules/commands/machine_command.gd      start, stop, open, close; one command, validated and priced
rules/bowl_map.gd                      with_water(step, z): a map sharing cells, owning its own water (§7.1)
rules/fixtures/flooded_terrace.gd      the hatch, the pump house and the sluice, as cells
presentation/fixtures/flooded_terrace_stamps.gd   their stamps (existing kit pieces)
presentation/overlay_queries.gd        the interact preview: cost, contest, watches, water diff
tests/unit/test_machines.gd            rules
tests/invariants/test_redirection.gd   the water the rules read is the water the preview diffed
tests/fights/test_flooded_terrace.gd   a fight that opens the sluice
```

---

## 3. Deliverable phases

Each slice ends with `make test` green; `make shots` joins the checkpoint from 6.3.

### 6.0 — Machines as state

**Ships.** `Machine` (cell, kind, and a small state: `OFF`/`ON` for a pump, `CLOSED`/`OPEN` for a hatch and a sluice). `CombatState.machines`, copied by `duplicate_state()`. `MachineCommand` replaces the stub `MACHINE` kind's no-op: it validates (the unit is active, adjacent, has the AP, the machine exists and the change is legal), spends `INTERACT_COST`, flips the state, and keeps the existing contact rule (a Live hostile on the machine's tile starts contact). Hatch: a hatch is already a vertical connector (plan 3.8's `LINK`); an *open* hatch is what carries the `LINK`, a closed one does not, so the rule asks the machine state and not a second flag.

**Done when.** A unit next to a closed hatch cannot climb through it, opens it, and then can (and a test says each); a contested machine still starts contact; an invalid machine command fails with a reason; copies are independent (`tests/unit/test_state_isolation.gd`).

**What landed.** `rules/machine.gd` (`Kind` HATCH / PUMP / SLUICE, `cell`, `on`), `CombatState.machines` with `add_machine` / `machine_at`, copied by `duplicate_state()`, and `rules/commands/machine_command.gd`. The command is an act (so committed under plan 05), costs `INTERACT_COST`, needs the unit within one tile (`REACH`), and fails with a reason for: no machine, too far, no AP, already in that state, and a sluice that is asked to close (§7.3). The climb rule moved to `Movement.can_step(map, state, from, to)`: a hatch at the lower cell decides alone (open carries the climb with no `LINK` flag, closed blocks it even with one), otherwise the map's `LINK` flag decides, so there is one truth and no second flag to drift. `InteractCommand.Kind.MACHINE`, which was the stub, is gone; the contested-machine contact tests in `test_contact.gd` now drive `MachineCommand`, and need the unit standing next to the machine. A sluice's water effect is 6.2. `BowlAuthoring` lint still checks `LINK` flags against connector stamps and knows nothing of machines; teaching it that is 6.5, when a bowl first has a hatch.

### 6.1 — Water the state owns

**Ships.** The mechanism of §7.1: `BowlMap.with_water(step, z)` returns a map that shares the cell store and owns its own water, and `CombatState` swaps `map` for it when a redirection lands. No `Movement`, `Exposure` or `BreakRule` call site changes, because they already read water through `map.step_at`.

**Done when.** After a redirection, the new state's `map.step_at` differs and the old state's map is untouched; `Movement` prices the new step on the new state and the old one on the old; `tests/invariants/test_water_agrees_with_drawing.gd` still passes for both; the F debug toggle is the only writer of a shared map (a test greps for it).

**What landed.** `BowlMap.with_water(step, z)` (a new map sharing the same `cells` dictionary and owning its two water fields) and `CombatState.redirect_water(step, z)`, which swaps `map` for it on a state the caller owns. No rule changed: `Movement`, exposure and break already read water through `map.step_at`. `tests/invariants/test_redirection.gd` asserts that the cell store is shared and the water is not, that a redirected state leaves its parent's map and `step_at` alone, that `Movement` prices each state's own step, that a roof stays dry, that the picture (`PresentationCoords.in_water`) still agrees with `is_wet` after a redirection, that two redirections branch independently, and that only `fight_view.gd`'s F toggle assigns `map.water_step` or `map.water_z` anywhere in `rules/` (fixtures excepted) or `presentation/`. Nothing calls `redirect_water` yet; the sluice does in 6.2.

### 6.2 — The sluice

**Ships.** Opening the sluice steps the bowl's water one step wetter (Dry→Mud→Falling→Flooded) through 6.1, as a Confirmed action that registers with plan 05's mechanism. Closing it does not put the water back (GDD §6.4: the sector "stays there for days"); it only stops further creep, and in a fight nothing creeps, so closing is a no-op the validator refuses with a reason.

**Done when.** The sluice opens once per fight and the water steps once; Flooded is the ceiling and opening there fails with a reason; the cost line names the AP and what the water does; undo cannot take it back (it is Confirmed, so the history clears); the plan 05 confirm prompt is the only path.

**What landed.** In `MachineCommand`: opening a `SLUICE` is Confirmed (`needs_confirm`), and applying it calls `redirect_water(water_step_after(state), water_z)` so the bowl steps one wetter (`FLOODED` is value 0, so wetter is one less) on a new map and leaves the parent's untouched. `validate` refuses closing ("a sluice cannot be closed again"), a second opening ("already open", which is what makes it once per fight) and opening at the ceiling ("the water is already as deep as it goes"). `water_step_after(state)` is public so 6.3's preview reads the same number the command applies. `ConfirmPrompt` learned the sluice: "confirm: opens the sluice, and the water rises from falling to flooded, 2 AP". Tests in `test_machines.gd` (each step, ceiling, once, Confirmed tier and the history clearing, preview equals apply, a pump leaves the map shared, a roof stays dry) and `test_confirm_prompt.gd`. Nothing in the view triggers a machine yet (6.3), and the water plane reads the map's step when it is synced, so it will not move on screen until 6.4 plays the change.

### 6.3 — The preview

**Ships.** `overlay_queries` gains an interact preview for a hovered machine: AP cost and what would be left, whether a Live hostile contests it (from fog, not from the view), the Watches the action would trigger (UI §4.4), and for the sluice the diff: the cells whose step changes and the squad bodies standing in them, computed by applying the command to a duplicate state and comparing `step_at`. A shot setup captures the sluice preview.

**Done when.** The preview's cell list equals the cells whose `step_at` actually differs after the command, asserted over the terrace; an unaffordable interact is drawn as unaffordable with its cost, not hidden (UI §4.1); nothing in `presentation/` computes water, LOS or AP.

**What landed.** `OverlayQueries.interact_preview(map, state, unit, cell)` validates a `MachineCommand` and, when it is legal and moves water, applies it to a duplicate state and diffs `step_at` over the map, so the list is the rule's own. It returns the cost and what is left, affordability, the refusal reason, whether it confirms, whether a Live hostile contests it (`Contact.machine_starts_contact`), the Watches an act there would trigger (`Command.hostile_watches_covering`), the water from and to, the changed cells and the squad bodies standing in them. `format_interact` turns it into words, and `compute` fills it only when the hover is over a machine. In `fight_view` the label is drawn over the machine, and clicking a machine within reach (`MachineCommand.in_reach`) tries the command through the usual `_try`, so a sluice goes through plan 05's confirm and a click out of reach still walks. `tests/invariants/test_interact_preview.gd` asserts the list equals the cells that really change, equals the wet cells by GDD 5.8 (not by the code under test), excludes a roof, names the squad in the water, changes nothing, shows an unaffordable cost, says why a flooded bowl refuses, flags a contested machine, and has no water diff for a pump. Shot `terrace_interact_sluice` adds a sluice to the terrace state (none is authored until 6.5) and probes that the label is drawn. UI 0.20 describes it. Not built here: a preview of a hatch's own effect on the climb, which the label does not yet mention.

### 6.4 — The tile-by-tile change

**Ships.** The water plane's redirection plays tile by tile (UI §3), never a fade. This is presentation: the rule is instant, and the view eases each cell's water from its old step to the new one, ordered from the sluice outward. Reduced motion collapses it to the end state. It is the first real test of the water plane.

**Done when.** A shot mid-change shows some cells at the old step and some at the new; the plane never z-fights the slabs during it (the existing `terrace_water_bare` probe still holds); reduced motion draws the end state at once.

**What landed.** `water.gdshader` gains a sweep: `sweep_origin`, `sweep_radius` (negative is off), `sweep_keep_inside` and `sweep_cell`. The fragment discards on the wrong side of a square front quantised to whole tiles (`floor(max(|dx|,|dz|) / cell + 0.5) * cell`), so it moves in rings. `WaterPlane.set_sweep` / `clear_sweep` set it. `fight_view._play_water_change(old_map, origin)` runs after a command that swapped the map: it syncs the new water, adds a second `WaterOld` plane at the old step and height, and tweens one radius from just inside the origin to the bowl's far corner (about 0.09 s a ring, clamped to 0.5 to 2 s) with the new plane keeping the inside and the old plane the outside; `_finish_water_change` frees the old plane. Reduced motion, or a change that moves nothing, skips it. `_undo` finishes any change and re-syncs. `_seek_water_change` is the one place the front is set, and how a shot freezes it. Shot `terrace_water_sweep` opens the sluice through the real arm-then-confirm path, freezes the front four tiles out and probes that the near street reads as Flooded (0.32) and the far street as Falling (0.61); the other water probes still pass. `tests/presentation/test_water_sweep.gd`. UI 0.21. The rules are instant and the bodies and overlays jump to the new play plane while the water sweeps, which is as the plan says; easing the bodies is not built.

### 6.5 — Author it on the terrace

**Ships.** A hatch on house A's stair column, a pump house and a sluice on the levee, as cells in `flooded_terrace.gd` and stamps in the stamps file, using the kit pieces that exist. A fight in `tests/fights/test_flooded_terrace.gd` opens the sluice and asserts the consequence on movement and exposure. Lint checks the machines have stamps and the stamps have machines (the same two-way check 3.8 added for connectors).

**Done when.** The terrace passes lint; the fight test opens the sluice and asserts the squad on the canal now swims where it waded, and a roof stays dry (GDD 5.8); a shot shows the three machines drawn.

**What landed.** The terrace is 20×14 with three machines (`FloodedTerrace.machines()`, added by `opening()`):

- **Hatch** at (4,5,1), replacing the ladder to the roof. It starts open, so the climb is what it was, and it carries no `LINK` flag: the machine decides alone. Closing it from the roof denies the climb, and opening it restores it.
- **Pump house** (`PUMP_ORIGIN` (14,5,0), machine cell (14,5,0)) and **sluice gauge** (`SLUICE_ORIGIN` (4,1,0), machine cell (4,2,0)), each a 2×2 block of masonry, which is what the kit's MANIFEST says both pieces are. A unit operates one from an adjacent tile.
- Stamps use the kit's own `env_hatch`, `env_pump_house` and `env_sluice_gauge`; no new art.

`BowlAuthoring.lint` takes the machines and checks them both ways, as 3.8 did for connectors: a machine must have its piece stamped over its cell; a hatch, pump house or sluice stamp must have a machine; a drawn connector is linked by either the map's `LINK` or a hatch; and a hatch that also carries `LINK` fails. `tests/fights/test_flooded_terrace.gd` asserts the three machines and their starting state, the climb through the hatch, closing it from the roof and opening it again, a pump that starts and changes no water, the default Flooded terrace refusing the sluice, and a Falling terrace where the sluice steps the water to Flooded. The fight test asserts what the rules actually change, which is not the move cost: `step_move_cost` is the same for Falling and Flooded today, and what differs is hiding (chest-deep Falling water hides no one, GDD 5.4; deep water can), so the test checks `ExposureQuery` on the canal before and after, plus that both roofs stay Dry. The shots from 6.3 and 6.4 now use the terrace's own sluice instead of one added to the state, and `terrace_machines` probes that the three pieces are drawn (fog draws nothing for a stamp with an Unknown cell, so the setup walks two of the squad up to the blocks first). What is not built: drawing the hatch's open or closed lid, the sluice leaf lifting, and the pump house's damaged dressing (the kit has the nodes; they wait on the table's pump upkeep).

---

## 4. Explicitly out of scope

- Table-scale redirection: creep into the next bowl, how long it hangs wet, the Bitter rule (GDD §6.6), the water graph. Table mode.
- First Gauge as a trait, its once-per-fight rule, and the founder-only precision (GDD §8.3). A plain interact here.
- The handoff landing: the hatch prompt naming a Pioneer (UI §18). Needs research and a roster.
- Pump upkeep (kept / thin / failing) and a pump's effect on the table's water graph. A pump here is a state a fight can flip and a rule can read, nothing more.
- A second water surface on one map (UI §3 "two bowls on one map"), so the sluice steps the whole bowl.
- New art. If a piece is missing, empty and log (Phase 2 §7.4).
- Enemy use of machines. An enemy that reasons about a sluice is AI, and AI stays out of `rules/`.

---

## 5. Verification

1. `make test` green.
2. **One water.** Every read of water goes through `BowlMap.step_at` / `is_wet`; `grep` finds no read of `water_step` outside it and the knowledge store.
3. **A map is never written during a fight.** The F toggle is the only writer of a shared `BowlMap`; a command that changes water returns a state whose `map` is a different object and leaves the old one unchanged.
4. **Preview equals rule.** The sluice preview's cell list equals the cells whose `step_at` differs after the command.
5. **Branchable.** A state before and after opening the sluice can each be played on independently, and plan 05's undo restores the old water.
6. **The machine's state is the only truth.** A hatch's `LINK` is read from its machine state; there is no second flag to drift.
7. `make shots` shows the three machines, the sluice preview, and a mid-change frame (UI §14: the change reads without colour: shape and the order of the sweep carry it).

---

## 6. Sequencing note

**6.0 before 6.1 and 6.2.** The sluice is a machine; build the state first. **6.1 is the risky slice** (it touches what every rule reads) and is small only if §7.1's choice holds; do it second, alone, with the invariant tests, before anything is built on it. **6.3 needs 6.2.** **6.4 is presentation only** and can land any time after 6.2. **6.5 last**, except that the hatch fixture in 6.0's tests can be a throwaway bowl so 6.0 does not wait on authoring.

---

## 7. Decisions

### 7.1 — How does a command change water without writing a shared map? **`BowlMap.with_water`.**

Locked (A).

The map is shared by every copy of a state and CLAUDE.md says commands must never write it.

- **A (chosen). `BowlMap.with_water(step, z)`.** A new map object that shares the cell dictionary and owns its water; the redirection swaps `state.map` for it. No call site changes, because every rule already reads water through `map.step_at`. The cells stay shared and read-only; only the two water fields differ. Smallest change that keeps every existing invariant.
- **B. Water on `CombatState`.** `state.water_step` / `state.water_z`, and every rule reads water from the state. Cleaner ownership, but it changes the signature of every function that takes a map and reads water (`Movement`, exposure, break, overlay queries, the drawing's `in_water`), a wide change for one feature.
- **C. A water overlay keyed by cell.** A per-cell step on the state, consulted before the map. Supports two surfaces later, but it is a second water model beside the map's and the two can disagree.

### 7.2 — What does the sluice change in a bowl with one plane? **The whole bowl steps one wetter.**

Locked (A).

- **A (chosen). The whole bowl steps one wetter.** Matches GDD §6.4's "one step wetter" on the only plane the terrace has.
- **B. Only cells downstream of the sluice.** Closer to a real sluice, but "downstream" needs a flow direction the map does not carry, which is a new rule and a GDD change.

### 7.3 — Can the sluice be closed again in a fight? **No: opening is one-way within a fight.**

Locked (A).

- **A (chosen). No: opening is one-way within a fight.** GDD §6.4: the sector stays wet for days. It also keeps the preview honest, because there is no "undo" the player can mistake for the sluice's own.
- **B. Yes, closing steps it back.** Easier to experiment with, but it contradicts the hangover the GDD builds the card around.

### 7.4 — What does a pump do in a fight? **A flippable state; its water effect is table mode's.**

Locked (A).

- **A (chosen). A flippable state with a rule that reads it only where the GDD asks for one: nothing yet.** Ship the machine and its interact, assert the state flips, and leave its water effect to table mode (out of scope above).
- **B. A pump lowers the step by one.** The natural gameplay, but it is the same redirection mechanism run the other way and wants the upkeep model first (GDD §6.1).

### 7.5 — Does a closed hatch block shots and sight? **No: a hatch gates the climb only.**

Locked (A).

- **A (chosen). No. A hatch is a connector, not a wall.** It gates the climb only (6.0). Sight and shot rules stay as they are.
- **B. A closed hatch blocks the line through its cell.** More tactical, but it adds a material-like state to LOS and Plan 4's one-vision-query rule would need to learn it.

---

## 8. What comes after

**Table mode** (UI §8) is `plans/07_table_mode_the_basin_and_the_day.md`: the basin as a graph, the day tick, labor, and a dispatch that plays the fight on `with_water`. It inherits the machine state and the water change; the table-scale redirection card (which bowls step wetter, creep, how long it hangs, the Bitter rule) is that plan's `plans/08`. **First Gauge** as a trait gates the sluice's precision and adds its once-per-fight spend on top of the confirm from plan 05. **Enemy phase behaviour** around machines is AI, kept out of `rules/`, and waits for whichever plan introduces it.
