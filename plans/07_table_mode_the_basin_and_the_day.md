# Phase 7 — Table mode: the basin as a graph, and a day that ticks

**Status:** drafted, nothing built. Slices 7.0–7.5 below; §7 decisions locked.
**Tracks:** GDD v1.18 §3.1 (modes, time, the boat camp), §4.2 (logistics, the table day's verbs), §4.3 (labor board), §6.1 (the graph), §6.2 (creep), §8.5 (extraction); UI/UX v0.21 §8 (table mode), §5 (what commits), §6 (fog; map facts, decided in plan 4 §7.9).
**Depends on:** Phase 6 — `BowlMap.with_water` is how a dispatched fight reads the basin's water for its bowl; machines are what a fight changes on the way back. Phase 5 — "Day end" is one explicit commit and goes through the confirm prompt. Phase 4 — the campaign store (`KnowledgeStore`) is the save this plan extends, and map facts (§7.9) are the table's fog.
**Goal:** the other half of the game exists as a deterministic layer under a minimal surface. The basin is a graph of bowls the rules can read (step, grade, pump, feeders); a day ends and the water walks, readably; the player moves a handful of hands, sends one fireteam to one bowl, and plays that fight on the same geometry they already play; and when it ends they are home, with the morning on the table. If a table day has no decision that changes tomorrow's map, the slice has failed UI filter 10.

---

## 0. Why this, and why not the alternatives

**Nothing above one bowl exists.** `rules/` is a tactical domain: a `BowlMap` for one fight, a `CombatState`, a knowledge store keyed by bowl. There is no basin, no day, no pump upkeep, no labor and no dispatch. Plans 3 to 6 each ended by pointing at "table mode", and the open items of those plans (the water graph, creep, redirection at basin scale, map facts, the handoff, bands) all land on layers that do not exist.

**The design is mostly written and nearly all of it is rules.** GDD §6.1 gives the graph (feeders, grade, a step-down needing "two neighbors, or majority of the ring"); §6.2 gives creep and the late leak cap; §4.3 gives a labor board of six buckets; §4.2 gives the budget of a table day ("a handful of assignments plus one dispatch"). UI §8 gives the minimum surface and, as importantly, what it never shows. So the first job is a deterministic basin and a day tick, tested headless, exactly as the tactical layer was, with the screen written against it.

**The knowability clause is the testable heart.** GDD §6.1: *"A bowl that changes with no way to have seen it coming is a design bug."* That is not presentation. It is an invariant the day tick must satisfy: a step never changes on a tick unless the day before it was readable as walking. Making that a test, before the surface exists, is the cheapest way to keep the surface honest.

**Why not the neighbours.**

- *The base* (UI §9, the Citadel's three phases) shares the cutaway but is its own surface and its own set of rules (space, dredging, facilities). Out of scope.
- *Research and the handoff* (UI §11), *bands and mail* (GDD §5.12), *the causeway and FOBs* (UI §8) all tick on the day this plan builds, and none is needed to make a day decide something. They are named in §4 so they are written against this plan's tick, not beside it.
- *A 3D basin table.* UI §8 says "the table" without fixing a form. A 3D model of the basin is a large art and camera cost; a flat board of bowls and edges proves every rule and every UI claim first (§7.3).

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| Where the basin lives | **`rules/basin/`, pure and deterministic** | Same posture as the tactical layer. Value types that duplicate, commands that validate then apply, no randomness anywhere (GDD §5.4 has no dice, and the water has none either). |
| Water is support, not litres | **Steps and counts only** | GDD §6.1: "Do not simulate liters. Simulate support." A bowl has a step, a grade, a pump state, an upkeep state and a list of feeders. |
| Knowability is a test | **A tick may not change a step the day before did not flag as walking** | Written once, over the whole fixture, before any UI. |
| What a table day is | **A handful of assignments plus one dispatch or none, then one explicit Day end** | GDD §4.2. Day end is a Confirmed action (plan 05), never an End Turn with nothing decided. |
| A dispatched fight | **The existing tactical layer, fed the bowl's water through `with_water`** | No second combat model. The result comes back as a small value the campaign applies. |
| The save | **The plan 4.6 store, extended** | `bowls` already holds knowledge by bowl; `facts` and the basin and day join it (plan 4 §7.9 Q3). Written at fight end and at Day end, never mid-fight. |

---

## 2. Layout

```
rules/basin/bowl.gd                 Bowl: id, grade, step, pump, upkeep, feeders
rules/basin/basin.gd                the graph: bowls and edges, queries, duplicate
rules/basin/water_graph.gd          the knowability read: what the player may know of a bowl
rules/basin/day.gd                  Day.end(campaign) -> DayResult: wear, creep, step-downs
rules/basin/day_result.gd           what moved overnight, as data (the morning read)
rules/campaign.gd                   day, currencies, labor, bench, basin; duplicate; commands act on it
rules/commands/table/               AssignLabor, Dispatch, EndDay (same validate/apply shape)
rules/fixtures/basin_ring.gd        a small authored basin: a rim, a floor ring, a sump
presentation/table_view.gd          the surface; draws a Campaign and applies validated commands
presentation/table_queries.gd       the overlay queries for the table, delegating to rules/
scenes/table.tscn
tests/unit/basin/, tests/invariants/test_knowability.gd, tests/fights/test_a_table_week.gd
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint from 7.4.

### 7.0 — The basin as data

**Ships.** `Bowl` and `Basin`, a graph of bowls with a grade (`RIM` / `FLOOR` / `SUMP`), a water step, a pump (`ON` / `DAMAGED` / `DEAD`), an upkeep state (`KEPT` / `THIN` / `FAILING`) and a list of feeders (the neighbours that pour into it). `rules/fixtures/basin_ring.gd` authors a small basin (§7.2). `WaterGraph.read(basin, bowl_id)` returns exactly the facts GDD §6.1 says the player may always learn about a known bowl: step, grade, whether the pump is holding and kept, which feeders pour and which are still pouring, and whether the step is walking and roughly when.

**Done when.** The fixture builds and duplicates independently; `read` names each of those facts for every bowl and invents none (a plate reports its own machine and bowl, never the ring: instruments are a flag per bowl, and an uninstrumented bowl reads only itself); a bowl nobody has visited reads as unknown, not as dry.

### 7.1 — The day tick

**Ships.** `Day.end(campaign) -> DayResult`: pumps wear (an unposted pump moves toward `FAILING` by a fixed rule), a dead or failing pump starts a leak that walks its bowl one step wetter over the days (creep, GDD §6.2, with the late leak cap: one ignored late pump walks Dry to Mud and stops while the ring holds), and a bowl steps *down* only when enough of its feeders do (working default: two neighbours, or a majority of the ring). `DayResult` is data: bowls that moved, work that finished, nothing rendered.

**Done when.** `tests/invariants/test_knowability.gd` drives the fixture through many days under several labor plans and asserts no bowl changes step unless the previous day's `WaterGraph.read` flagged it walking; one hero pump in a hole in the ring does not dry a bowl (GDD §6.1); a stopped late pump walks Dry to Mud and stops; the tick is deterministic (the same campaign gives the same result twice) and never mutates its input.

### 7.2 — The campaign and the labor board

**Ships.** `Campaign` (the day, the four currencies as plain counts, the people pool, the labor board as six bucket counts, the bench, the basin) and `AssignLabor` (move hands between buckets within the people pool, never below zero, never inventing people). Labor is a short board: no individuals (GDD §4.3 anti-goals). Posted hands and scrap are what keep a pump (7.1 reads them).

**Done when.** Moving hands off a pump posting measurably moves that pump toward `THIN` over the following days (a fight-free test); the pool's total never changes through any sequence of assignments; an assignment that would go below zero fails with a reason; a table day's budget (a handful of assignments plus one dispatch) is enforced by the validator.

### 7.3 — Dispatch and the way home

**Ships.** `Dispatch` (up to four from the bench, one bowl) builds the tactical opening for that bowl: the authored `BowlMap` for it, with the basin's current water through `BowlMap.with_water` (plan 6.1), the chosen four seated, and `CombatState` handed to the existing fight. When the fight ends (`CombatState.outcome()` from plan 4.6) a small `FightOutcome` is applied back to the campaign: who is on the bench, who is down or lost, what the machines left (a sluice opened is a redirection, which the basin records as a bowl a step wetter, hanging). Only bowls that have an authored map can be dispatched to; the others refuse with "no known map".

**Done when.** Dispatching to the terrace opens the same fight `fight_view` loads today, at the basin's step for it; an opened sluice in that fight changes the basin's step for that bowl when the squad is home; a wiped squad costs its people per GDD §5.5 and seals its intel (plan 4.6); and dispatch refuses a bowl with no map, an empty bench and a fifth body.

### 7.4 — The surface

**Ships.** `scenes/table.tscn` and `table_view.gd`: a flat board of the known bowls and their feeder edges. Per bowl, in words and shapes: step, grade, pump state, upkeep (*kept / thin / failing*), which feeders pour and whether the step is walking and roughly when, and a bowl the instruments have not reached is not drawn with data. A labor board of six counts with plus and minus, the currencies as plain counts, one dispatch slot that leads with the bowl and only then the bodies, the morning read as marks in the ageing grammar of UI §6, and Day end as one confirmed action. `table_queries.gd` delegates to `rules/` (CLAUDE.md: the presentation decides nothing).

**Done when.** A shot shows each surface; UI §8's *never shows* column is asserted (no bar, percentage, target or progress pip anywhere in the table's text and nodes); every state that changes a decision is separable without hue (UI §14); the table never shows a bowl's people on Known-quiet ground; and a human can play three table days on the fixture end to end.

### 7.5 — Coming home is the switch

**Ships.** The scene flow: dispatch leaves the table for the fight, the fight's end returns to the table with the morning read, and there is no button that swaps modes mid-mission (GDD §3.1, UI §8). The campaign store is extended (`basin`, `day`, `facts` beside `bowls`) and written at fight end and at Day end only, so an abandoned fight keeps nothing, as plan 4.6 already says for knowledge.

**Done when.** A saved campaign reloads to the same day, basin and bench; an abandoned fight leaves the store as it was; the Opening still plays without a table (squad mode needs no campaign); and `make run` can start either the fight or the table.

---

## 4. Explicitly out of scope

- The base: the Citadel's three phases, dredging, facilities, the space constraint (UI §9).
- Research, the Eureka beat and the handoff landing on a hatch (UI §11); the archives verb. Research ticks on the day this plan builds, so it will read `Day.end`, but a labor bucket for it is only a count here.
- Bands and mail (GDD §5.12): rumours as marks, jobs and warmth. They are map facts and wait on the facts layer (plan 4 §7.9), which this plan only stores.
- The causeway, Vanguard FOBs and the march, the Threat Radius, and the push-has-broken check (GDD §6.6).
- Redirection at table scale: the preview of which bowls step wetter, creep into the next bowl, and the Bitter rule. A sluice opened in a dispatched fight does change the basin (7.3), but the table-side card and its hangover wait for `plans/08`.
- Fuel, boat legs and the cost of a leg in days; the reach picture; MEDEVAC chain routing; radar headings; staffed posts' Live vision. The clock is one day per dispatch and per Day end.
- Food, fields and population growth beyond the counts the labor board needs. No farm sim (GDD §4.3 anti-goals).
- Any 3D basin table, any new art, and any second fireteam.
- Enemy behaviour on the table. That is AI and stays out of `rules/`.

---

## 5. Verification

1. `make test` green.
2. **Knowable.** Over a long run of days and labor plans, no step changes without the day before flagging it walking.
3. **Deterministic and branchable.** The same campaign gives the same `DayResult`; `Day.end` and every table command return a new `Campaign` and leave their input unchanged (the isolation test, extended).
4. **People are conserved.** No sequence of assignments, dispatches and deaths creates or loses a person except through a recorded death.
5. **One combat model.** A dispatched fight is a `CombatState` built from the same fixtures the tactical tests use; nothing in `rules/basin/` computes sight, cones or AP.
6. **One water.** The basin's step reaches a fight only through `BowlMap.with_water`; no fight reads the basin.
7. **The surface decides nothing.** `table_view` validates then applies commands and reads `table_queries`; no tier, rule or water logic lives in it.
8. `make shots` shows the board, the labor board, the dispatch slot and a morning read; UI §8's *never shows* column holds; non-colour channels intact.

---

## 6. Sequencing note

**7.0 and 7.1 first, and headless.** They are the whole of the new rules, and 7.1's knowability test is the contract the screen is written against. **7.2 before 7.3:** a dispatch spends a bench the campaign owns. **7.3 is the risky slice**: it is where the basin meets the tactical layer, and it should land with the isolation and one-water tests before any screen exists. **7.4 needs 7.0 to 7.2** and can start once 7.3's interface is fixed, with the fight stubbed. **7.5 last**, because it is the only slice that touches both scenes and the save.

---

## 7. Decisions

### 7.1 — What does the first playable table day decide? **Water and labor, with a real dispatch.**

Locked (A).

- **A (chosen). Water and labor, with a real dispatch.** Read the graph, move hands, send the fireteam to the one authored bowl, end the day, read the morning. It exercises every rule in this plan and no other layer.
- **B. Add the currencies economy.** Food, fuel and scrap that actually deplete and replenish. More to balance before anything is playable, and the GDD leaves the digits to the prototype.
- **C. Dispatch only.** A menu that launches the terrace fight. Fast, but it is the "table day with no decision that changes tomorrow's map" UI §8 says is a failure.

### 7.2 — How big is the fixture basin? **About seven bowls in three rings: a rim, a floor ring and a sump.**

Locked (A).

- **A (chosen). About seven bowls in three rings: a rim, a floor ring and a sump.** Enough that a feeder list can have two or three entries, so "two neighbours or a majority of the ring" and the sump's grade both do work. Only the terrace has an authored map (7.3).
- **B. Three bowls.** Too few: the majority rule degenerates and the knowability test proves little.
- **C. A full basin of twenty or more.** Mostly authoring and balancing, with no extra rule to prove.

### 7.3 — What form does the table take? **A flat board: bowls as nodes, feeders as edges, in 2D over the existing HUD layer.**

Locked (A).

- **A (chosen). A flat board: bowls as nodes, feeders as edges, in 2D over the existing HUD layer.** Cheap, readable without hue, and it proves UI §8's claims. A 3D table can replace it later without touching the rules.
- **B. A 3D model of the basin.** The "table" of the fiction and a large art and camera cost. It should wait until the rules and the information design are settled.

### 7.4 — Is Day end the only way time passes on the table? **Yes, plus one day per dispatch.**

Locked (A).

- **A (chosen). Yes, plus one day per dispatch.** GDD §4.2: a table day spends a day when you sit, and a deployment is a day. The clock stays one number.
- **B. Also a "rest" or "skip" verb.** That is a way to end a day with nothing decided, which UI §8 names as the thing to avoid.

### 7.5 — How does a pump's upkeep state get set? **From posted hands and scrap over the previous days.**

Locked (A).

- **A (chosen). From posted hands and scrap over the previous days: fully posted holds it `KEPT`, a gap lets it fall to `THIN`, a longer gap to `FAILING`, then it breaks.** A fixed counter per pump, so wear is a clock the player can read (GDD §6.2: "Wear is the clock").
- **B. A separate upkeep action per pump.** More verbs than the labor board allows (GDD §4.3: a handful of buckets, not per-pump clicking).

### 7.6 — Does a wiped squad's loss land before or after the Day end? **At the fight's end, on the way home.**

Locked (A).

- **A (chosen). At the fight's end, on the way home.** The table opens on the morning with the bench already smaller, so the loss is the first thing read, not a surprise at the next tick.
- **B. At Day end.** Keeps the table's number steady until the commit, but hides a loss the player already knows.

---

## 8. What comes after

`plans/08` is **redirection at table scale and the rest of the day tick**: the card that names which bowls step wetter, whether creep reaches the next bowl and how long it hangs wet (UI §8, GDD §6.4); the Bitter rule; and reading the sluice a fight opened as a hanging redirection. After that, in roughly this order: **bands and mail** as map facts on the facts layer; **research and the handoff**; **the base cutaway**; **the causeway and Vanguard FOBs** with the push-has-broken check; and last, a **3D basin table** over the same rules.
