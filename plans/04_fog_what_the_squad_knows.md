# Phase 4 — Fog: what the squad knows

**Status:** 4.0–4.1 completed — sight line, Vision; §7 decisions locked (7.9 deferred to table mode)
**Tracks:** GDD v1.14 §3.1 (fog), §5.4 (LOS), §5.5 (MEDEVAC window), §8.2 (Ironman); UI/UX v0.9 §6 (fog), §5 (what commits), §4.2 (exposure), §17 (occupants are data)
**Depends on:** Phase 3 (`plans/03_second_bowl_height_on_screen.md`) — fog needs rooms to hide things in, and the terrace's interiors are the first place Known-quiet means anything. Slices 4.0–4.2 touch only `rules/` and tests and can start while Phase 3 is still landing; 4.3 onward edits `fight_view.gd` and waits for 3.4.
**Goal:** what the player is allowed to know becomes a value `rules/` returns, not something the view happens to draw. One sight line, one vision query, knowledge held per unit and shared by earshot, remembered across visits — and the fact that a move revealed something, which is the boundary `plans/05` needs for undo.

---

## 0. Why this, and why not the alternatives

**There is no vision model.** Nothing in `rules/` answers "what can the squad see?". Three places improvise their own answer:

- `Contact.machine_starts_contact` — its own comment says *"Live means some standing squad body can see it"*, and implements that inline.
- `Cones.apex_known` — loops the viewer faction asking for a clean line.
- `ExposureQuery.exposure` — runs LOS backwards, then runs it *again* to decide whether a source may be located.

Three hand-rolled versions of one question is the shape Phase 1 §0 warned about, and the reason `overlay_queries` exists at all: when two implementations of one read can disagree, Principle 3 is a lie.

**The view draws everything.** `fight_view` draws every unit in `_state.all_units()`; the only visibility test is the cutaway floor. The GDD's mission loop is *"See a sightline → spend AP to change it or use it"* (§4), and right now every Drifter on the map is visible from the first frame. There is nothing to peel, so scouting is not a decision.

**The parts are built and unplugged.** `assets/shaders/fog_ageing.gdshader` is complete — dust, flatter colour, colder marks, a `staleness` uniform, a `reduced_motion` path — and `PresentationCatalog.FOG_MAT` names it. **Nothing loads it.** `Cell.occupant` is authored, duplicated and commented in three files as "the authored occupant of a roof or deck", and read by no fight logic anywhere. UI §17 says why it exists: *"Occupants are data from the start. They sit on their roof in `BowlMap` the whole campaign. Fog decides whether they are drawn. Nothing spawns at the knock."* Fog is the missing half of a data model that already anticipated it.

**UI §5 is blocked on it.** The reversible tier is *"a move, up to the point it produces information — undoable until the unit crosses a Watch, enters an enemy line, peels fog, or acts."* Three of those four are computable today. The fourth is not, because nothing knows what fog is.

**GDD 1.11 adds a second dependent.** A Trauma Kit now starts a deterministic MEDEVAC window, and *"before committing the Trauma Kit, the player can see the valid extraction route and the evacuation window it will create. … It is never a hidden roll"* (§8.5). A route is a path over terrain, and a route through terrain the squad has never seen is not something the game can honestly show. So the MEDEVAC preview is a consumer of knowledge, and it cannot be specified until "what is known" is a value. This plan does not build the window; it supplies the set the window will plan over (§7.8).

**Why not the neighbours.**

- *Commit / undo chrome* (UI §5) is the direct successor and needs 4.5's boundary fact first.
- *Table mode* (UI §8) needs campaign-scale fog across bowls. This plan builds the state machine and the store at fight scale, where it is testable headless.
- *Interact gizmos* (hatch, sluice, pump) want the knock and the machine, and both already ask "is it Live?" — a question this plan finally answers once.

**What this phase deliberately does not buy.** The day clock, radar, thermal optics, staffed-post vision, radios as equipment, undo chrome, an AI that reasons about what it cannot see, a full save system, or a third bowl.

---

## 1. Decisions taken

The last six rows are the §7 decisions, locked.

| Decision | Choice | Consequence |
| --- | --- | --- |
| Sight vs shot | **Two lines, one walk** | `Los.line_of_sight` is weapon-class dependent — a plank stops a pistol and not a rifle. Eyes are not a weapon. Sight gets its own material predicate and entry point; both use the same supercover walk. |
| Where knowledge lives | **`rules/`, as fight state** | It is deterministic, per-cell, and must survive `duplicate_state`. A view flag could not be asserted headless, and the view would be hiding something the rules returned — the lie Principle 1 forbids. |
| Direction of travel | **Monotonic within a fight** | GDD §3.1: *"Leaving live vision freezes the tile. It does not wipe it."* Unknown → Known-quiet → Live, and Live → Known-quiet when vision leaves. Never back to Unknown. |
| What fog gates | **Queries, not commands** | `ShootCommand` already requires a clean weapon line, and 4.0 proves a weapon line implies a sight line — you can never shoot what you cannot see. Fog filters what is *offered* and drawn, and adds no new refusal. |
| Actors vs terrain | **Split, as GDD §3.1 says** | Known-quiet keeps terrain and last-seen water step; actors are hidden. Two reads on one cell, not one visibility bit. A third read, *map facts* (structures such as survey marks, a causeway, FOBs), is table-scale and not built here; the store nests its bowls so a `facts` sibling can be added (§7.9). |
| Fixtures | **Both existing bowls** | The scripted street proves peel on a flat map; the terrace proves rooms, roofs and interiors. No new bowl. |
| **7.1 Sight blockers** | **`CRATE` and `DEPLOYED_BARRIER` do not block sight** | Matches every other soft-cover row: you crouch behind a crate and can still be seen over it. The barrier stays pure shot-cover, so no GDD change is needed. |
| **7.2 Enemy fog** | **Player-only** | The enemy stays a presentation-side driver and `Contact` stays one-sided by design. No enemy knowledge state in `rules/`. |
| **7.3 Sharing** | **Per-unit knowledge, shared by earshot** | Each unit holds what it saw. Units within earshot share it; radios later widen the rule. Working default: Chebyshev 3. **The player's map is the union of the squad** (*"the squad is the camera"*, GDD §3.1); per-unit knowledge gates unit-level reads — the selected unit's exposure sources — not what the map draws. |
| **7.4 Persistence** | **A simple store, built now** | Knowledge survives past the fight, per bowl. See 4.6. |
| **7.5 Staleness** | **Visits-since-seen, stored** | The store records when each cell was last seen; staleness is a curve over visits since. Internal float only, never a digit (UI §6). Days replace visits behind the same curve when a clock exists. |
| **7.6 Occupants** | **Become Units at bowl load** | Matches UI §17 (*"nothing spawns at the knock"*) and keeps the fixed-roster assumption every command makes. Fog alone hides them. |
| **7.8 MEDEVAC route** | **Priced over known cells only; a fixed floor window when none exists** | Keeps GDD 1.11's *"never a hidden roll"* true with no preview leaking unseen terrain. A Trauma Kit is never refused; with no known route it starts a small fixed window (working default 1 round, tunable). |
| **7.10 Wipe** | **A wiped squad's intel is sealed until another squad finds it** | The intel is neither lost nor free: a wipe writes a sealed record at the place the squad fell, and a later squad that sees that place recovers it. See 4.6. |
| **7.11 Watch order** | **Oldest Watch first** | Stacked Watches resolve in the order they were set. Fixed, and it reveals nothing about where a hidden watcher stands, so a preview of it does not leak. |
| **Save timing** | **At fight end only** | Ironman is one save the game writes (GDD §8.2). If intel persisted mid-fight, a player could scout, quit, restart from the opening and keep the intel for free. An abandoned fight discards what it peeled. |

---

## 2. Layout

```
rules/
  taxonomy.gd           # + blocks_sight(material). The one sight table, written out
  los.gd                # + sight_line(): same supercover walk, sight predicate
  vision.gd             # sees / live_cells / seers_of. Pure, no state
  comms.gd              # shares(state, a, b): earshot now, radios later. One predicate
  knowledge.gd          # per-unit observed cells + merged read; serialisable, no nodes
  knowledge_store.gd    # per-bowl memory across fights: load/save, injectable path
  combat_state.gd       # + knowledge, copied like units, never shared like the map; + outcome()
  constants.gd          # + EARSHOT_RADIUS, STALE_FULL_AFTER_VISITS
  contact.gd            # machine_starts_contact -> Vision.sees (delete the inline copy)
  cones.gd              # apex_known -> Vision.sees (delete the inline copy)
  exposure.gd           # sources located through the unit's knowledge, not a second LOS
  reveal_result.gd      # what a command revealed (4.5)
presentation/
  overlay_queries.gd    # + knowledge-filtered hostiles/cones/sources; the only overlay source
  fog_view.gd           # wires fog_ageing.tres per cell; Unknown draws nothing
  fight_view.gd         # draws the squad's picture, not all_units()
tests/
  unit/test_sight.gd
  unit/test_vision.gd
  unit/test_comms.gd
  unit/test_knowledge.gd
  unit/test_knowledge_store.gd
  invariants/test_sight_implies_shot.gd    # anything you can shoot, you can see
  fights/test_fog_peel.gd                  # headless: walk a street, watch it peel
  presentation/test_fog_queries.gd
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins from 4.4.

### 4.0 — The sight line

**Why first.** Every later slice asks "can X see Y?", and today the only answer available is a *weapon* question. `Taxonomy.stops(PLANK, PISTOL)` is `true` and `stops(PLANK, RIFLE)` is `false`: a waist-high plank stops a pistol round and not a rifle round. That is right for shooting and wrong for eyes — nobody is hidden by a plank they can see over.

**Ships:** `Taxonomy.blocks_sight(material)` and `Los.sight_line(map, from, to)`, reusing `line3d` and the existing body-hide rule (smoke and deep water hide a body both ways; chest-deep does not).

**The table (decided, §7.1).**

| Blocks sight | Does not block sight |
| --- | --- |
| `MASONRY`, `METAL`, `GROUND`, `SMOKE`, `WATER_DEEP` | `AIR`, `WATER_CHEST`, `PLANK`, `CRATE`, `DEPLOYED_BARRIER` |

Write the table out rather than deriving it from `stops(m, RIFLE)`, even where the two coincide: adding a material must force a sight decision instead of silently inheriting one.

**The invariant, verified before writing this plan.** Across all 10 materials x 7 weapon classes there is no pair where sight is blocked and the shot is not. So **anything you can shoot, you can see**, and fog can never hide a legal target from the player. Lock it in `tests/invariants/test_sight_implies_shot.gd` over every pair, not a sample — it is 70 cases. It is the guarantee that lets commands stay unchanged. The §7.1 choice keeps it true: making `CRATE` and `DEPLOYED_BARRIER` non-blocking only shrinks the sight set.

**Done when:** a plank between two units blocks a pistol shot and not the sight of them; the invariant passes over the full product; `stops` and `blocks_sight` are never confused at a call site.

---

### 4.1 — Vision as one query

**Ships:** `rules/vision.gd`:

- `Vision.sees(map, state, faction, cell) -> bool` — any active unit of `faction` with a clean sight line.
- `Vision.live_cells(map, state, unit) -> Dictionary` — the cells one unit can currently see; the peel input in 4.2.
- `Vision.seers_of(map, state, faction, cell) -> Array[Unit]` — who, for the "locate the source" read.

**Then delete the improvisations.** `Contact.machine_starts_contact` and `Cones.apex_known` call `Vision`. This is the slice's real product: three answers become one. Their existing tests stay green unchanged.

**One expected shift, stated up front.** `ExposureQuery` currently locates a source through the *exposed unit's own weapon line*. Locating by sight means a plank no longer hides a shooter you can see over — the correct answer, and a different one. If a test pins the old answer, change it and say so in the commit; do not absorb it. That change lands in 4.3, where exposure moves onto per-unit knowledge, not here.

**Cost note.** `live_cells` is O(cells) supercover walks per unit and runs on every peel. The bowls are ~160–200 cells with single-digit casts, so measure before optimising; if it bites, bound it by the longest cone length, not by caching (a stale cache is a fog bug that will be blamed on the shader).

**Done when:** `Vision` is the only implementation of "can this faction see that cell"; the two call sites are one-liners; the suite is green with no test edited in this slice.

---

### 4.2 — Knowledge, per unit, shared by earshot

**Ships:** `rules/comms.gd`, `rules/knowledge.gd`, and `CombatState.knowledge`.

**Comms — one predicate (§7.3).** `Comms.shares(state, a, b) -> bool`: same faction, both active, within `RulesConstants.EARSHOT_RADIUS` (working default **3**, Chebyshev — the same shape as `OUTNUMBERED_FRIEND_RADIUS`). Symmetric. Sound is not sight, so it ignores walls: people shout through them. Radios are **not built**; they become a `Unit` flag that widens this one predicate, and nothing else has to change. That is the point of routing every share through it.

**Knowledge shape.**

- Per unit: the cells that unit has observed, each `KnownQuiet` or `Live`, with the visit ordinal it was last seen on (§7.5).
- A unit's **merged read** = its own observations plus those of every unit `Comms.shares` with it.
- The **squad's picture** = the union over all player units. This is what the map draws (§7.3).

So earshot does not change the map. It changes what a *particular unit* knows, and therefore the reads that are per unit — chiefly exposure sources (4.3). A scout out of earshot who spots a shooter puts it on the player's map and does **not** put it in a teammate's sources.

**State rules.**

- `duplicate_state()` **copies** knowledge, the way it copies units. It must not be shared like the read-only `BowlMap`: a state that peeled fog must not leak backwards into the state it promised not to touch (the bug Phase 1 §7.5 already paid for with `Cell.occupant`).
- Peel runs where the contact check already runs: after **every step** of a free move and after every command applies. `MoveCommand` already steps cell by cell so Watch crossings resolve in order — peel rides the same loop, so a move that reveals something reveals it at the tile where it happened.
- Live is recomputed from `Vision.live_cells`. Cells that were Live and no longer are Known-quiet. Cells never return to Unknown.
- `Knowledge` is plain data with `to_dict()` / `from_dict()` and no node references, so 4.6 can persist it.
- `Knowledge.known_cells(...)` returns the squad's Known-quiet ∪ Live set. Nothing consumes it in this plan; the MEDEVAC route preview (GDD 1.11) will plan only over it (§7.8), so exposing it now avoids reopening `Knowledge` later.

**Tests:** `test_comms.gd` (symmetry, radius edge, faction and active-state gating); `test_knowledge.gd` (state machine, monotonicity, merge); extend `test_state_isolation.gd` so a peeled copy leaves its parent untouched.

**Done when:** a headless walk turns a street from Unknown to Live to Known-quiet; a room stays Unknown until a unit has a line into it; a unit in earshot of the seer knows what the seer saw and one outside earshot does not; the opening state is unchanged.

---

### 4.3 — What the player may know

**Ships:** knowledge-filtered fields on `overlay_queries` — the only overlay source (Phase 2 §1), so this is where fog reaches the screen without the view inventing anything.

- **Hostile bodies:** offered only on cells that are Live in the squad's picture.
- **Watch cones:** a cone whose watcher stands on a non-Live cell keeps its volume and loses its apex. That read **already exists** — `apex_known` and the unresolved-apex shader mode — and fog is finally what drives it honestly.
- **Exposure sources, per unit:** `count` stays truthful (you always know how many guns are on you); `sources` are located only where *that unit's merged knowledge* has the shooter Live. This generalises the split `Exposure` already documents — *"count vs sources.size() gap = hidden watchers"* — and it is where the 4.1 plank shift lands. Record it in UI §4.2.

- **Watch previews under fog.** UI 0.8 has previews name *"every Watch that will fire and its fixed order"*. A hidden watcher's cone is still drawn (volume without apex), so it can still be named. What must not leak is the *order*, and it does not: the order is oldest Watch first (§7.11), which says nothing about where a hidden watcher stands. An order based on distance to the watcher would have leaked hidden positions through the preview, which is why it was rejected.

**The honesty boundary.** Filtering happens in the query, not by the view skipping a draw. If `overlay_queries` hands the view a hostile, the view draws it; if the player must not know, the query must not offer it. A view-side `if` here is the same lie as a parallel LOS.

**Done when:** `test_fog_queries.gd` shows a hostile in a room absent from the queries until any squad member has a sight line; the same hostile located for a unit in earshot of the seer and only counted for one outside it; the shot-line preview never names a target the queries did not offer.

---

### 4.4 — Draw it

**Ships:**

- `presentation/fog_view.gd` wires `fog_ageing.tres` over Known-quiet cells, feeding the `staleness` uniform the shader already declares. Unknown draws **nothing** — not a black quad, not a dimmed tile. The shader's own header says so: *"Unknown is 'draw nothing' (engine). Live is staleness = 0."*
- Actors hidden outside Live; terrain and the last-seen water step stay (GDD §3.1).
- **Reveal is not arrival** (UI §6): an enemy walking into Live vision plays the walk; vision reaching a tile where someone already stood simply shows them, with no entrance and no pop. Two events, two draws — a reveal that plays like a spawn turns the finite basin into a spawn table.
- **Occupants seated at load (§7.6).** A load step turns each authored `Cell.occupant` id into a `Unit` standing on that cell, from a roster the fixture supplies (the smallest thing that works: a dictionary of id → faction and weapon). From then on fog alone decides whether they are drawn. `Cell.occupant` finally has a reader: an invariant test asserts every authored occupant id has a body on its cell, and fails the bowl otherwise.
- `make shots` gains `terrace_fog_unknown`, `terrace_fog_peeled`, `street_fog_known_quiet`.

**Done when:** walking the terrace peels it room by room; a roof occupant appears because the squad got a line, not because the squad arrived; reduced motion still reads (the shader's grade holds and only its drift is motion).

---

### 4.5 — The information boundary

**Ships:** `rules/reveal_result.gd` — what applying a command revealed: cells peeled, Watch reactions triggered, enemy lines entered, whether the command was an act. Returned alongside the new state; **no undo, no UI**.

**"Watch triggered" follows GDD 1.13, not "crossed".** A Watch reacts when a hostile crosses from outside a cone to inside it, **or** commits a qualifying action while already inside (shoot, interact, throw, deploy utility, First Gauge, Echo Call). Moving wholly inside a cone, turning, setting Watch and ending a phase do not trigger it. So a shot fired from inside a cone reports a triggered Watch, and a step that stays inside one reports none. The rules for resolving them are not built (`MoveCommand` only handles entry, one reaction per step); that is its own rules slice, and 4.5 reports whatever it returns.

**Why it stops here.** UI §5's reversible tier is defined by exactly this list, and its cost argument is precise: *"a move that revealed nothing could have been planned perfectly with full information the interface already owed the player, so taking it back costs the game nothing. The moment it reveals something, it stands."* This slice produces the fact. `plans/05` spends it. Shipping the fact without the chrome keeps the boundary testable headless.

**Done when:** a move through empty known ground reports nothing revealed; a move that peels one cell, triggers a Watch by entry, or steps into an enemy line reports each; an in-cone shot reports a triggered Watch; a step wholly inside a cone reports none; and a test names every case.

---

### 4.6 — The store

**Why it exists.** Known-quiet means "walked before". Across a campaign that is a bowl revisited in Act II with the water down (UI §3, *"authored once, played at four steps"*), so knowledge has to outlive the fight (§7.4). It also gives staleness a real source (§7.5) without a day clock.

**Ships:** `rules/knowledge_store.gd`, with an **injectable path** so tests never touch `user://`.

- **File shape:** `{ "version": 1, "bowls": { <bowl_id>: { "visit_index": …, "cells": {…}, "unrecovered": […] } } }`. Bowls are nested under a `bowls` key, not at the top level, so a sibling `facts` map (§7.9) can be added later without reshaping the file.
- **Content, per bowl id:** a `visit_index` (increments once per completed fight on that bowl) and, per cell, the `last_seen_visit` ordinal and the last-seen water step. Nothing else. No unit positions, no fight state.
- **Staleness:** `staleness = clamp(visits_since_seen / STALE_FULL_AFTER_VISITS, 0, 1)`, working default 5. It feeds the shader's 0–1 float and is **never shown as a number** (UI §6: *"a digit becomes a schedule the player optimises"*). Hover may say it in words the game has: "not seen since your last visit".
- **Prerequisite: a fight end must exist.** The rules layer has none today — nothing named outcome, over or wipe. 4.6 adds the smallest one it needs, `CombatState.outcome()`: **ONGOING**, **WIPED** (no player unit is active and none has extracted) or **EXTRACTED** (no player unit is active and at least one has extracted). Objective-based endings (GDD §5.6) and the founder's campaign end are not modelled here. "Wipe" is a working definition the GDD does not give (§7.10).
- **A wipe seals its intel instead of losing it (§7.10).** On WIPED the store still counts the visit (`visit_index` increments), but the cells that squad peeled are **not** applied to the bowl's known map. They are written as a sealed `unrecovered` record on that bowl: the visit ordinal they were seen on, and an **anchor cell**, the tile where the last unit fell.
- **Found by another squad.** In a later fight on that bowl, when a unit's sight line reaches the anchor cell, the sealed cells are merged into that fight's knowledge as Known-quiet, carrying their original visit stamps, so they arrive already aged by however many visits have passed. The merge rides the same peel as 4.2. If that later fight is abandoned, the record stays sealed; if it never reaches the anchor, the record stays sealed indefinitely. Once the fight ends normally, the merged cells are written and the record is removed.
- **Written at fight end only.** An abandoned fight writes nothing and discards what it peeled. Ironman is *"one save that the game writes"* (GDD §8.2), and a mid-fight write plus a restart would let the player scout for free. Crash-safety mid-fight is the honest price; per-command saving is only honest with a full fight save, which is `plans/05`'s territory.
- **Robust to damage.** A missing file is a fresh campaign. A corrupt or wrong-version file is ignored with a warning and never crashes a fight. Writes go to a temp file and rename, so a crash mid-write cannot corrupt the last good store.
- **One module.** No quickload, no branch, no UI. When the campaign save exists this file becomes part of it, and having one `KnowledgeStore` makes that one place to change.

**Tests:** `test_knowledge_store.gd` — round-trip through `to_dict`/`from_dict`; a completed fight bumps `visit_index` and stamps peeled cells; an abandoned one leaves the store byte-identical; a wipe increments the visit, writes a sealed record and changes no known cell; a later fight that sees the anchor cell recovers the record already aged, and one that never sees it leaves it sealed; missing, corrupt and future-version files all degrade to fresh; staleness rises with visits and clamps at 1.

**Done when:** a second visit to the terrace opens with the first visit's rooms Known-quiet and aged, and abandoning a fight mid-way leaves the store unchanged.

---

## 4. Explicitly out of scope

- The day clock, and any staleness that is a count of days
- Map facts (GDD 1.12: survey marks, staged material, causeway route and progress, FOBs). Table-scale; their visibility rule is not fight-scale fog's to decide (§7.9).
- The MEDEVAC window itself (GDD 1.11): the Awaiting-MEDEVAC state, window length, route pricing and its preview. That is a rules slice of its own, not built here; this plan supplies the known-cell set it plans over.
- Recovering a fallen squad's gear, bodies or people (a recovery objective). Only the *intel* is sealed and found here (§7.10).
- Radios as equipment (`Unit.has_radio`), radar headings, thermal optics, staffed-post vision (GDD §3.1 "later"). Earshot only; the predicate is the seam.
- Symmetric fog. An enemy that reasons about what it cannot see is AI, and AI stays out of `rules/`.
- A view that follows the selected unit's picture. The player's map is the squad's union.
- Undo / commit chrome — `plans/05` (this plan ships the fact, not the interface)
- A full campaign save, quickload, or mid-fight persistence
- A fog-of-war minimap, a seen-counter, or a day digit
- A third bowl, new art, or a rule change to flatter fog
- Changing `Los.line_of_sight`'s weapon behaviour. Sight is added beside it, not instead of it

---

## 5. Verification

1. `make test` green. 4.1 edits no test; the one expected shift (plank vs located source) lands in 4.3 and is named in its commit.
2. **One vision implementation.** `grep` finds no clean-line loop outside `Vision` in `rules/`.
3. **Sight implies shot**, over all 10 materials x 7 weapon classes.
4. **Knowledge is copied, not shared.** A peel in a duplicated state leaves the parent untouched.
5. **Monotonic.** No cell returns to Unknown in any sequence the fight tests drive.
6. **Earshot is one predicate.** Every share goes through `Comms.shares`; `grep` finds no radius test elsewhere.
7. **No view-side filtering.** What the view draws is what `overlay_queries` offered; fog never appears as an `if` in `fight_view`.
8. **Ironman-honest store.** An abandoned fight writes nothing; a wiped one seals its intel and does not apply it (§7.10); a damaged store never crashes a fight. `CombatState.outcome()` has tests for ONGOING, WIPED and EXTRACTED, including a mixed squad.
9. **The unplugged parts are plugged.** `FOG_MAT` is loaded; `Cell.occupant` is read by something.
10. Non-colour channels intact (UI §14): Known-quiet reads as ageing *and* as absent actors, not as a colour wash; reduced motion keeps the grade.

---

## 6. Sequencing note

**4.0 before everything.** Every later slice asks a sight question, and asking it in weapon terms would bake the plank bug into four places.

**4.1 before 4.2.** Consolidate the improvisations *before* adding a new caller.

**4.2 before 4.3.** Prove the state machine headless. A fog bug found on screen costs a render cycle to see and a test to pin; found headless it costs neither.

**4.6 after 4.2, before 4.4.** The store defines the visit ordinal that staleness comes from, so 4.4 draws a real value instead of a fixture constant.

**4.4 after 4.3**, for the same reason 3.3 came before 3.4: if a number is wrong, the shader is not the place to find out.

**4.5 can land any time after 4.2**, and must land before `plans/05` is written.

**Parallel work.** 4.0–4.2 and 4.5–4.6 live in `rules/` and `tests/`; 4.3 and 4.4 edit `overlay_queries.gd` and `fight_view.gd`, which Phase 3 is also changing. Sequence those two after 3.4 rather than fight over the file.

---

## 7. Decisions

All locked. They are recorded here so the reasoning survives, and the ones that touch other documents are listed at the end as things to raise.

### 7.1 — Do crates and deployed barriers block sight? **No.**

Neither blocks. `CRATE` is ~1.5 m of pallet wall you crouch behind; a `DEPLOYED_BARRIER` stays pure shot-cover. No GDD change. If a later design wants a deployable that breaks a line of sight, that is a new rule with combat weight, raised to GDD §7 — not a table edit.

### 7.2 — Does the enemy have fog? **No, player-only.**

`Contact` is one-sided by design and the enemy driver is presentation-side. Revisit only if enemy behaviour becomes a rules module.

### 7.3 — Who knows what? **Per unit, shared by earshot; the map is the squad's union.**

Knowledge is held per unit. Units within earshot share it; a radio later makes it squad-wide. The map draws the union, so earshot changes unit-level reads (exposure sources), not what is drawn. Everything routes through `Comms.shares`, so the rule can evolve — which is what you expected it to do — without touching the rest.

**Working defaults, all tunable and all unverified against the GDD:** radius Chebyshev 3; symmetric; ignores walls; same faction only.

### 7.4 — Does knowledge survive the fight? **Yes, in a simple store (4.6).**

### 7.5 — Where does staleness come from? **Visits since seen, from the store.**

Internal float, never a digit. Days replace visits behind the same curve later.

### 7.6 — When does an occupant become a Unit? **At bowl load (4.4).**

### 7.7 — Save timing. **At fight end only.**

Locked against the Ironman rule; see 4.6.

### 7.8 — Can a MEDEVAC route cross terrain the squad does not know? **No. Known cells only; floor window if none.**

New with GDD 1.11. The route and its window must be visible *before* the Trauma Kit is committed, and *"never a hidden roll"*. A route through Unknown cells would leak unseen terrain into a preview ("route: 4 rounds" through black is a free scout), or be a window the terrain cannot keep if the unseen cells turn out to be walled off.

**Locked:**

- The route is planned over `Knowledge.known_cells` only. Unknown cells are not passable *for route pricing*; they remain walkable for a unit.
- **A Trauma Kit is never refused for lack of a route.** If no known route reaches an extraction point, the kit still stops the bleed clock and starts a **fixed floor window** — working default **1 round**, a named constant, tunable. Deterministic and known, so still no hidden roll. The preview says so in words ("no known route — 1 round").
- Refusing the kit was rejected as too harsh (you could never stabilise a bleeder), and pausing the window until a route is known was rejected as making the kit a free pause.
- A route priced over Unknown cells at a penalty was rejected outright: it can turn out to be walled off, which is a hidden roll under another name.

**Consequences to settle when the MEDEVAC plan is written, not here:**

- `Movement.path` needs an optional cell filter so pricing can be restricted without a second pathfinder (CLAUDE.md: "do not duplicate pathfinding for UI behavior").
- **The common case is unaffected.** The squad reaches a fight by walking from the boat (GDD §3.1: the squad is the camera, and walking peels fog), so the route it walked is Known-quiet by construction. The floor window bites only for an extraction point *off* the walked route: a marked roof elsewhere, or a fight authored to open mid-bowl. That is intended pressure to scout before committing, and the floor keeps it from being a trap.
- The store (4.6) makes a previously walked route Known-quiet on a return visit, which is the payoff the store exists for.
- How window length is computed from route length, and how logistics and waystations extend it, are the MEDEVAC plan's. This decision only fixes *which terrain* it may use and *what happens with none*.

### 7.9 — How do map facts interact with fog? **Deferred to table mode. Three questions, none blocking.**

New with GDD 1.12. The causeway's approach is now readable in bands, and once it is building *"its route and progress are map facts … a loud town cannot make itself unseen again by waiting."* Survey marks and staged material are the earlier bands; FOBs are the same kind of thing (UI §8: *"places on the map, visible, targets"*). None of these is an actor (fog hides actors) and none is terrain that ages toward dust (Known-quiet). They are persistent structures the player is meant to be able to read.

**Nothing in this plan needs the answer.** Inside a fight there is no causeway to hide: a fight *on* a causeway is authored terrain like any bowl (GDD §6.5; this is my reading, the GDD only says first contact "follows Section 6.5"). The table-scale rule belongs to table mode. The questions are recorded so the plan that writes it starts from them.

**Q1 — What makes a map fact visible?** The docs already give three precedents that do not agree, and the causeway text picks none:

| Precedent | Where | Rule |
| --- | --- | --- |
| Water steps | GDD §3.1 | Visible on known bowls from the dome once instruments work. Current; no scouting needed. |
| Bands | UI §8 | *"Where it was last seen"*; marks *"age out like any other stale tile."* Last-seen, ageing. |
| Radar | UI §8 | Draws only on Known-quiet land. Needs prior scouting. |

Options for survey marks, the causeway and FOBs: **dome-fed** (current wherever the dome reaches; the strongest "never silent", but tied to the dome working and needing a rule for before it does); **last-seen** (you must look, and the highland can advance out of sight, which conflicts with "never silent" unless the early bands arrive another way, and the GDD's "Watching" band does mention *reports* and highland lights); or **always visible** (simplest, but draws structures over Unknown, which the GDD defines as black, and removes any reason to scout the rim). **Leaning:** dome-fed on known bowls, last-seen elsewhere, which extends the GDD's own water precedent instead of inventing a rule. This is a GDD rule, not a UI detail.

**Q2 — Does a fact's progress age?** The causeway *"grows day by day"* (UI §8). If a fact is last-seen, is the progress you remember frozen and dusted over, like people, or current, like water? UI §6 draws that line for water and people and has no row for structures. Depends on Q1.

**Q3 — Where does the knowledge live?** The 4.6 store is keyed per bowl and per cell, but a causeway runs across bowls, so a per-bowl record is the wrong home. The clean model is two layers: the campaign simulation holds the *truth* of a fact, and the store holds what the player last *saw* of it, by fact id, in a top-level `facts` map beside `bowls`. That is the same split `Cell.occupant` (truth) and fog (knowledge) already make. **Done now, cheaply:** 4.6 nests bowls under a `bowls` key so `facts` can be added without reshaping the file. Nothing else is built.

**Raise to UI §6:** its fog table has three rows (Unknown, Known-quiet, Live) and one paragraph, *"Water is current, people are not."* Map facts want the same treatment: something that is current or last-seen by a stated rule, permanent once seen, and not an actor.

### 7.10 — Does a wiped squad's intel persist? **Only if found by another squad.**

GDD 1.13: *"A squad wipe without the founder ends that deployment and loses those people, but has no campaign-wide effect beyond the lost squad."* The store is campaign state, so the sentence needed a reading. Locked: the intel is **neither lost nor free**. A wipe seals what the squad saw at the place it fell, and a later squad recovers it by reaching that place (4.6). Knowledge still travels with bodies (§7.3); a fallen squad's knowledge is where its people fell, and someone has to get there.

**Working definitions, mine, that the GDD should confirm:**

- **The anchor** is the tile where the last unit to go down fell. A squad that dies across several tiles has one anchor, not one per body.
- **"Found"** means a later squad has a sight line onto the anchor (Live), not that it physically stands there. This is cheap and matches "a squad's vision reaches a tile". If the GDD wants a body to be walked to, that is a stricter rule and a different trigger.
- **What arrives** is the sealed cells as Known-quiet, stamped with the visit they were seen on, so they are already aged. Nothing arrives as Live.

**Also open, and only the GDD can settle it:** what counts as a wipe. The plan's definition (no active player unit, none extracted) treats a squad of bleeders nobody can reach as wiped. A partial outcome (two out, two dead) is EXTRACTED, not a wipe, and its intel is written normally.

### 7.11 — In what order do stacked Watches resolve? **Oldest Watch first.**

GDD 1.13 and UI 0.8 say every eligible unspent Watch resolves *"in a fixed previewed order"* and that previews name each Watch and its order, without naming the order. Locked: **the order they were set, oldest first.**

- It is fixed by construction and previewable.
- It does not depend on anything the player cannot see. Nearest-watcher-first was rejected because under fog it would leak the distance of hidden watchers, and ascending unit id was rejected as arbitrary (which of your riflemen fires first would depend on roster order).
- It applies across factions: only Watches hostile to the acting unit are eligible, and among those the oldest fires first.
- **Consequence for the rules slice** (not built here): `LiveWatch` should carry an explicit set-order stamp rather than rely on array position, so a sort or a filter cannot reorder it silently.

### Raised in other documents

All of these landed in **GDD 1.14** and **UI/UX 0.9**, except the open ones at the end.

| Item | Where it landed |
| --- | --- |
| Sight is its own line; crates and barriers do not block it (§7.1) | GDD §5.4 "Sight is its own line"; Locked in 1.14 |
| Per-body knowledge shared by earshot; fog is the player's alone (§7.2, §7.3) | GDD §3.1 Fog "Who knows"; Locked in 1.14 |
| Known-quiet carries across visits, ages by visits, written at fight end (§7.4, §7.5, §7.7) | GDD §3.1 "Memory" and §8.2 Saving; UI §5 The save and §6 "Memory across visits" |
| A wiped squad's intel is sealed until found; wipe definition (§7.10) | GDD §3.1 "A lost squad's intel" and the "Up to four bodies" bullet; UI §6 |
| MEDEVAC route priced over known ground; floor window (§7.8) | GDD §8.5; UI §4.7 "Awaiting MEDEVAC" |
| Stacked Watches resolve oldest first (§7.11) | GDD §5.2 Watch paragraph; UI §4.3 and §4.4 |
| Exposure sources located by what a unit can locate (§4.3) | UI §4.2 "Where from is what this unit can locate"; UI §6 "The squad's picture" |

**Still open, and now recorded where they will be found:**

- **Map facts against fog** (§7.9): GDD §10 and a UI §18 checklist item. Leaning is dome-fed on known bowls, last-seen elsewhere.
- **Tactical comms** (earshot radius, wall dampening, radios as equipment): GDD §10.
- **Recovering a lost squad's intel**: sight versus reaching the body on foot. GDD §10. Plan 04's working default is sight.
- **The floor MEDEVAC window** (1 round): GDD §10, tuning.
- **Committing a Trauma Kit as a Confirmed-tier action** is my inference from GDD 1.11's "before committing the Trauma Kit". It was not added to UI §5's tier table. Decide it when `plans/05` is written.

---

## 8. What comes after

`plans/05` is **commit and undo** (UI §5), written against 4.5's boundary: the four tiers, the undo of a move that revealed nothing, and the one-confirm dialogs for the ugly irreversible things (shooting a bleeder — already half-built in `fight_view`'s confirm path — and later spending First Gauge, opening a sluice, ending the day). It also owns the full fight save that makes mid-fight persistence honest, which is the piece 4.6 deliberately does not attempt.

A **MEDEVAC window** rules slice follows or runs beside it (GDD 1.11): the Awaiting-MEDEVAC state, window length from the route, expiry. Committing a Trauma Kit now reads as a Confirmed-tier action, because the player is meant to see the route and window *before* committing; add it to `plans/05`'s confirm list when that plan is written.

After that the fog work pays out twice more: **interact gizmos** get a meaningful "is it Live?" for the knock, the hatch and the machine; and **table mode** (UI §8) inherits the three-state machine and the store at basin scale, where Known-quiet finally ages in days and the dome starts updating water on bowls nobody is standing in.
