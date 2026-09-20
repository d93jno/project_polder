# Phase 1 — BowlMap and the rules layer, headless

**Status:** 1.5.1 completed — next is 1.6 (§7.2 resolved in GDD 1.9)
**Tracks:** GDD v1.9, UI/UX v0.5
**Goal:** the rules of a fight, as pure functions and a small state machine over data, with no scene loaded and no art authored.

---

## 0. Why this first

UI/UX §17 opens with it: *"Rules run on data, scenes only draw. A `BowlMap` resource holds cells... Line of sight, cones, contact, break checks, exposure and move costs are pure functions over that data, unit-tested with no scene loaded."*

Both of the other candidate starting points depend on this one. A placeholder UI drawn against fake data cannot exhibit the failure UI §1 exists to catch — *"a preview that disagrees with the rule function is a bug"* — because there is no rule function to disagree with. And authoring art before the cell and the data model are settled means authoring twice; the assets doc still lists grid size as open (§14).

**What this phase buys.** When it is done, a scripted fight runs headlessly and asserts its own outcome. Every preview built in phase 3 is then a rendering of a value this layer already returns, which is the only way Principle 1 is enforceable rather than aspirational.

**What it deliberately does not buy.** Nothing is visible at the end of this phase. That is the cost, and it is worth paying once.

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| Spatial model | **Sparse 3D grid**, `Dictionary[Vector3i, Cell]` | A cell's `z` *is* its level; UI §17's "level, height" collapse to one concept. LOS is a literal 3D line walk. Cutaway is a `z` filter. Diving is a `z` move. |
| Test runner | **GUT**, vendored into `addons/gut/` | `make test` runs `godot --headless`. Readable failures matter once LOS has hundreds of cases. |
| Scope | **Queries + combat state, actions as commands** | A whole fight is assertable headlessly. Command *shape* lands now because UI §17 says retrofitting costs more; the *undo stack* waits for phase 3, when there is a UI to drive it. |
| Exposure vs hidden watchers | **Counts, but is not located** | Mirrors the cone rule UI §4.4 already settled: the volume is drawn, the apex is not. Needs a clarifying line in UI §4.2 — see §7. |

---

## 2. Layout

```
rules/
  taxonomy.gd          # Material, WeaponClass, CellFlags, WaterStep, Faction
  cell.gd              # value type
  bowl_map.gd          # Resource: the grid, water step, authored occupants
  los.gd               # line3d + line_of_sight
  exposure.gd          # los.gd run backwards
  cones.gd             # Watch volumes, stacking, apex resolution
  movement.gd          # per-tile cost, path, reserve marks
  combat_state.gd      # units, phases, AP, Pinned, health, bleed-out
  break_rule.gd        # the three clauses
  contact.gd           # free-move -> phases
  commands/
    command.gd         # validate() -> Result, apply(state) -> state
    move.gd  shoot.gd  watch.gd  interact.gd  throw.gd
tests/
  unit/                # one file per rules/ module
  invariants/          # property tests (see §6)
  fights/              # scripted end-to-end fights
addons/gut/
```

`scripts/` already holds shell scripts, so GDScript goes in `rules/`. Do not mix them.

---

## 3. Deliverable phases

Each phase ends green and is independently checkpointable. Estimates assume this is the only thing being worked on.

### 1.0 — Harness

**Status:** completed

**Ships:** GUT vendored and pinned. `make test` target. One deliberately failing test, then one passing, to prove the loop.

**Done when:** `make test` reports pass/fail and exits non-zero on failure, headless, with no editor open.

---

### 1.1 — BowlMap and the taxonomies

**Status:** completed

**Ships:** `taxonomy.gd`, `cell.gd`, `bowl_map.gd`.

```
Cell:
  material : CoverMaterial  # what it stops (named to avoid Godot's Material class)
  flags    : int            # SHELTER | DECK | SWIMMABLE | INTERIOR ...
  occupant : int            # unit id, -1 for none

BowlMap (Resource):
  cells      : Dictionary[Vector3i, Cell]
  water_step : WaterStep  # FLOODED | FALLING | MUD | DRY
  water_z    : int        # surface level; one plane per bowl (UI §3)
```

Material set for P0, from the assets doc §1 shared cover language: `AIR, PLANK, CRATE, MASONRY, METAL, DEPLOYED_BARRIER, SMOKE, WATER_DEEP, WATER_CHEST, GROUND`.

Weapon classes from assets §6.2: `PISTOL, MELEE, SPEAR, SHOTGUN, RIFLE, LMG, SNIPER`.

One table, `CoverMaterial × WeaponClass -> bool stops`, and it is the single source of truth. A plank stops a pistol and not a rifle (GDD §5.4); the hover read in UI §4.3 names whatever this table says.

**Done when:** a bowl can be built in code, round-tripped through `ResourceSaver`/`ResourceLoader`, and the stopping table is exhaustively tested.

**Watch for:** levee maps hold two water surfaces (UI §3). Either `water_step`/`water_z` become per-region now, or the type carries a `TODO` and a test that documents the limitation. Do not discover this in phase 4.

**Decision taken:** single `water_step`/`water_z` plane for now, with `TODO(levee)` on `BowlMap` and `test_levee_two_surfaces_not_yet_supported` documenting the gap until Act II.

---

### 1.2 — Line of sight

**Status:** completed

The keystone. Everything after this consumes it.

**Ships:** `los.gd`.

```
line3d(a: Vector3i, b: Vector3i) -> Array[Vector3i]
line_of_sight(map, from, to, weapon) -> LosResult
    LosResult: { clean: bool, blocker: CoverMaterial, blocker_cell: Vector3i }
```

No physics raycasts, ever (UI §17: *"A raycast will one day hit a balcony rail the preview ignored, and principle 1 breaks."*).

**Test cases:**

- Clean line across empty cells
- Plank stops pistol, passes rifle; masonry stops both
- Smoke blocks every class (GDD §5.4)
- A body in deep water has no line to or from it
- A body in chest-deep **Falling** water is fully visible — the rule the whole step exists for (GDD §5.8)
- Blocked lines name the blocker and the cell, since UI §4.3 requires the preview to say which
- Vertical: roof to street, street to overpass deck, basement isolation

**Invariant, tested as a property:** `los(a,b,w).clean == los(b,a,w).clean` for all a, b, w. Asymmetric sight is how "they could see me but I couldn't see them" bugs get born.

**Decision taken (§7.1):** **strict** corner tie-break. `line3d` is a geometric supercover: the center-to-center segment against closed unit cubes. A corner graze visits every neighbour that touches the corner; any stopper among them blocks.

---

### 1.3 — Exposure and cones

**Status:** completed

Both are LOS derivatives, so they ship together and share tests.

**Ships:** `exposure.gd` (`ExposureQuery`), `cones.gd`, minimal `Unit` / `CombatState` / `LiveWatch`, `RulesConstants` cone lengths.

```
exposure(map, state, unit) -> Exposure
    Exposure:
      state   : HIDDEN | EXPOSED | NO_HIDE
      count   : int                  # every hostile with a clean line
      sources : Array[Vector3i]      # only those the viewer can see

cone(map, watcher, facing, weapon) -> Array[Vector3i]
watch_cone(...) -> ConeResult { cells, apex_known }
cone_stack(map, state, cell) -> ConeStack { count, classes }
```

`count` and `sources.size()` differ exactly when a hostile is hidden. That gap **is** the decision from §1 — it is the data the UI needs to say "seen by 2" while placing only one.

`NO_HIDE` is a property of where the unit stands (Falling, open Dry), not of who is looking. It is returned in words so it survives greyscale (UI §14).

Cones carry `apex_known: bool`. When false the renderer dissolves the near end (UI §4.4); this layer just reports it. Cone generation ignores origin body-hide so a smoke/deep-water apex still throws a volume.

**The invariant that matters most:**

```
exposure(map, state, u).count > 0
  <==>  exists h in hostiles(u): los(map, h.cell, u.cell, h.weapon).clean
```

UI §17: *"One implementation, two directions — if they can ever disagree, Principle 3 is a lie."* Test it as a property over generated maps, not as three hand-written cases.

**Done when:** exposure and cone stacking agree with LOS on randomised bowls, and the hidden-watcher gap is asserted directly.

---

### 1.4 — Movement, AP, and the reserve read

**Status:** completed

**Ships:** `movement.gd`, `MovePath`, `WatchCrossing`; AP digits in `RulesConstants`.

```
move_cost(map, cell, unit) -> int          # Mud doubles (GDD §5.3)
path(map, state, unit, to) -> Path
    Path:
      cells          : Array[Vector3i]
      cost_per_cell  : Array[int]
      exposure_per_cell : Array[Exposure]   # UI §4.2, per tile
      watches_crossed   : Array[WatchCrossing]
      shot_reserve_at   : int   # index past which the shot is unaffordable
      watch_reserve_at  : int   # ditto for setting a Watch
```

The two reserve indices are the whole point of UI §4.1 — *"walk to the mark and the shot is still yours; one tile further and it is not."* They belong in the rules layer so the preview cannot drift from them.

**Test cases:** mud doubling; swim cost in Flooded; climb and dive as `z` moves; the reserve index moving when the unit's AP or weapon changes; a path that crosses two Watches reporting both.

**Working defaults (in `RulesConstants`):** AP_POOL=6, dry move=1, mud/swim/falling=2, vertical surcharge=+1, shot=2 (long guns=3), watch=3.

---

### 1.5 — Combat state and commands

**Status:** completed

**Ships:** expanded `combat_state.gd` / `unit.gd`, `commands/` (`move`, `shoot`, `watch`, `interact`, `throw`).

```
Command:
  validate(state) -> Result       # never mutates; this is what previews call
  apply(state)    -> CombatState  # returns new state
```

Previews call `validate()`. The UI in phase 3 renders the `Result`. Nothing draws a decision the rules layer has not already priced.

**Rules implemented, all locked in GDD 1.7/1.8:**

| Rule | Source | Note |
| --- | --- | --- |
| Any non-drop hit pins | GDD §5.4 | There is no suppression weapon class |
| Hit in own phase | GDD §5.4 | `DUCKED` — rest of phase gone, clears at end of it |
| Hit in opponent's phase | GDD §5.4 | `DUCKING_NEXT` — live Watch cancels at once, next phase spent ducked |
| One hit costs one phase at most | GDD §5.4 | Explicitly no stunlock. Tested |
| Watch: one watch, one shot | GDD §5.2 | Cancels if the watcher is Pinned first; cone shows spent |
| Health | GDD §5.4 | Rifle drops; two pistol hits drop. Pips, both sides |
| Bleeding Out | GDD §5.5 | 3 rounds *working default*; a round is one player phase + one enemy phase |
| Trauma kit | GDD §5.5 | Stops the clock |

**Done when:** a two-unit exchange can be driven entirely through commands and every state above is asserted.

---

### 1.5.1 — The data and helpers 1.6 needs

**Status:** completed

Break reads state that no phase has built yet. This is that state, split out so 1.6 is the rule and not a scavenger hunt. Nothing here is a rules question; the rules were settled in GDD 1.9.

**Ships:** new fields on `unit.gd`, a scar enum in `taxonomy.gd`, `Taxonomy.is_long()`, `Movement.reachable()`, `CombatState.attackers_of()`, a faction filter on `Cones.cone_stack()`, `RulesConstants.CALL_RADIUS`.

#### Data on the unit

| Field | Default | Why |
| --- | --- | --- |
| `adapted: bool` | `false` | Break clause 3 is about the *unadapted*: Drifters, untrained AI, raw unclassed recruits (GDD §5.5). P0's whole cast is unadapted — basin folk against Drifters — so `false` is the honest default. Classed units set it true when training and kit arrive (GDD §8) |
| `scars: int` | `0` | Bitfield over a new `Taxonomy.Scar` enum: `AGORAPHOBIA`, `LUNG_DAMAGE`. GDD §8.5 names both. Only Agoraphobia is consumed in 1.6; Lung Damage is data until movement reads it. With `has_scar(scar) -> bool` |
| `broken: bool` | `false` | The state GDD §5.5 gives a broken unit. 1.6 sets it; the broken *move* constraint is 1.6's job |
| `is_founder: bool` | `false` | **Not in the original prerequisite list.** The Call is a radius *around the founder* (GDD §8.4), and nothing on the map currently says which body that is. Also what founder-down keys off later (GDD §8.5) |

`_init` already takes six parameters; do not add four more. Set these after construction.

**`duplicate_unit()` must copy every one of them.** It does not copy what it does not know about, and `Movement.path` builds a probe with `duplicate_at` for each tile's exposure — so a field that fails to copy makes every per-tile break read silently wrong, in exactly the preview the player trusts. One test per field asserting the round trip, and one asserting `duplicate_at` keeps them while changing only the cell.

#### Helpers

**`Taxonomy.is_long(weapon) -> bool`.** Rifle, LMG, sniper (GDD §5.5). The rifle/LMG/sniper `match` is currently written out four times — three in `constants.gd` (`shot_cost`, `shot_damage`, `can_fire_in_deep_water`) and once in `taxonomy.gd`'s stopping table. Fold all four into this call in the same change, so "long" has one definition and the break rule cannot drift from the damage rule.

**`CombatState.attackers_of(map, unit) -> Array[Unit]`.** The standing hostiles with a clean line on `unit`. `Exposure` gives a count; break needs the bodies, because "in the open" asks whether a tile is free of a line from *every one of them*. Build `attackers_of` as the primitive and let exposure's count fall out of it, rather than writing the LOS loop twice.

**`Movement.reachable(map, state, unit) -> Array[Vector3i]`.** Every tile the unit can stand on with the AP it holds now. The same flood `path` already runs — `move_cost`, `_neighbors`, `_pop_min` — but bounded by `unit.ap` instead of aimed at a destination, and returning the frontier rather than one route. Pull the shared flood out of `path` so there is one traversal, not two that can disagree.

Two things it must handle that `path` currently does not:

- **Occupancy.** `is_walkable(map, cell)` checks material only; `Cell.occupant` is ignored. A tile with another body on it is not somewhere you can stand, so `reachable` must exclude it. That means `path` can currently route straight through a standing enemy — an existing gap from 1.4. Fix both here or neither; a `reachable` that excludes occupied tiles while `path` walks through them is worse than either alone.
- **Pinned does not zero the AP.** GDD §5.5 is explicit. `reachable` takes `unit.ap` as it stands and does not consult `unit.pin`.

**`Cones.cone_stack(map, state, cell, hostile_to := <none>)`.** The current stack counts every live Watch, friendly ones included. Break clause 3 needs hostile long cones only. Add an optional faction filter rather than a second function, and leave the default counting everything so the two existing tests in `test_exposure_cones.gd` still describe the UI §4.4 overlay read.

**`RulesConstants.CALL_RADIUS`.** *Working default.* GDD §8.4 gives no number — "small radius" early, "full weight" late — and the scaling is explicitly a later problem. One constant now, tagged like the rest.

#### Bleeders: filtered everywhere (decided)

`CombatState.hostiles_of` currently keeps bleeding units (`if not other.is_active() and not other.bleeding: continue`), so `ExposureQuery` counts a downed rifleman as a gun on you. A bleeder cannot fire.

**Decided: filter bleeders everywhere.** One definition of hostile, shared by exposure and break. The exposure count then means *guns on you*, which is exactly what UI §4.6 draws and what "outnumbered" counts. The alternative — filtering only inside break — would have kept two notions of hostile that have to stay in step forever.

What this touches:

- `hostiles_of` drops the `and not other.bleeding` escape, so it returns standing units only. If something later genuinely needs "who could see you, firing or not", that is a separate named helper, not a flag on this one.
- `ExposureQuery` inherits the change for free. A downed hostile stops contributing to `count` and to `sources`.
- `attackers_of` is built on the same primitive, so break and exposure cannot disagree by construction.
- `tests/invariants/test_exposure_los.gd` iterates `hostiles_of` directly and its invariant still holds, since both sides of the equivalence narrow together.
- Add a test asserting the change directly: a hostile with a clean line drops to Bleeding Out and the target's exposure count falls by one. Stabilising it does not bring the count back — a stabilised unit is still down (GDD §5.5).

This is a behaviour change to shipped 1.3 code, so it lands in 1.5.1 with its own test rather than riding along inside the break rule.

**Done when:** every field round-trips through `duplicate_unit` and `duplicate_at` under test; `is_long` has one definition and the four old copies are gone; `reachable` agrees with `path` on any tile both can reach, asserted as a property; `attackers_of` agrees with `Exposure.count`, both counting standing hostiles only; and the cone filter counts hostile Watches only while the existing stack tests still pass.

**What landed, and where it differs from the spec above.**

- Everything listed shipped: `adapted`, `scars` (`Taxonomy.Scar`: `AGORAPHOBIA`, `LUNG_DAMAGE`), `broken`, `is_founder`; `Taxonomy.is_long`; `CombatState.attackers_of`; `Movement.reachable`; the `hostile_to` filter on `Cones.cone_stack`; `RulesConstants.CALL_RADIUS` (2, working default). The four hand-written long-weapon lists are folded into `is_long`, with a test asserting cost, damage, deep-water firing and soft cover all agree with it.
- **Bleeders are filtered everywhere**, as decided. `hostiles_of` returns standing units only; exposure is built on `attackers_of`, so the two cannot disagree.
- **`reachable` takes an explicit `budget`, defaulting to `unit.ap`.** The spec said it would read `unit.ap` as it stands and ignore Pinned. The state machine gets in the way: `apply_pin` sets `ap = 0` on a ducked unit, so `reachable(unit.ap)` sees no reach for exactly the pinned units GDD §5.5 says must not have their AP zeroed for the "in the open" test. Left alone, "in the open" would be true for every pinned unit. Rather than change the pin model, `reachable` reads the budget it is given, and **1.6 must choose the budget for a pinned unit.** A test (`test_pinning_zeroes_ap_so_break_must_pass_a_budget`) pins the current behaviour so the gap stays visible. See §7.4.
- **Occupancy is read from `state.units`, not `Cell.occupant`** (and §7.5 removed the code that wrote the latter). `Movement.is_free` treats any *standing* body of anyone as blocking, and a downed or dead one as clear (matching what `apply_damage` already does to the occupant grid). `path` now uses it too, so it no longer routes through standing bodies or ends on one. This was the existing 1.4 gap.
- `duplicate_unit` copies all four new fields, and the round-trip is tested by enumerating every script variable on `Unit` rather than listing them, so a field added later that forgets to copy fails without anyone remembering to write its test.

**Verified:** 101 tests pass (66 before; the last five are the §7.5 isolation tests). Nine mutations of the real code were each caught by a test: a field dropped from `duplicate_unit` (two), bleeders counted again, standing bodies ignored, downed bodies blocking, `reachable` unbounded, LMG classed short, the cone filter removed, `attackers_of` counting friends. `rules/` has no scene, `Node` or raycast use.

---

### 1.6 — Break, contact, and the scripted fight

The proof.

**Ships:** `break_rule.gd`, `contact.gd`, `tests/fights/`.

```
break_check(map, state, unit) -> BreakResult
    BreakResult: BREAKS | WOULD_BREAK_IF_PINNED | SAFE
```

Three return values, not two, and that is the point. GDD §5.5's second clause needs the unit to *be* Pinned, which needs an enemy to choose to shoot it — intent, which UI §4.6 refuses to draw. So clause 2 returns `WOULD_BREAK_IF_PINNED` and the preview renders it as *"if hit here, breaks."* Clauses 1 and 3 return `BREAKS` unconditionally.

Also: the Agoraphobia scar is clause 3 with kit, training and terrain waived (GDD §5.5, §8.5); units inside The Call's radius cannot break (GDD §8.4); a unit that is both Pinned and broken takes the broken move (GDD §5.5, 1.7).

**Definitions** (GDD §5.5 as of 1.9, all *working default*; see §7.2 for how they were chosen). Each is a pure predicate over `map` and `state`:

| Predicate | Rule |
| --- | --- |
| `Taxonomy.is_long(weapon)` | Rifle, LMG, sniper are long. Pistol, shotgun, melee, speargun are short |
| `has_cqb_kit(unit)` | Every carried weapon is short. `Unit` carries one `weapon` today, so this is `not is_long(unit.weapon)` |
| `under_long_cone(map, state, unit)` | A hostile, **unspent** Watch of a long class whose cone contains `unit.cell`. `Cones.cone` already requires a clean line, so containment is the whole test. A long weapon with no Watch does not count |
| `outnumbered(map, state, unit)` | Standing hostiles with a clean line on `unit` **>** standing friends within 3 tiles (Chebyshev, all levels), counting `unit` itself. Downed units count for neither side |
| `in_the_open(map, state, unit)` | At least one standing hostile has a clean line on `unit`, and **no** tile in `Movement.reachable(unit)` is free of a clean line from every such hostile. Pinned does **not** zero the AP for this test |

```
break_check(map, state, unit) -> BreakResult
  1. in The Call's radius                                   -> SAFE
  2. last standing friend on this map has dropped           -> BREAKS
  3. Agoraphobia AND under_long_cone AND in_the_open        -> BREAKS   (kit, training, terrain waived)
  4. unadapted AND on Dry AND has_cqb_kit AND under_long_cone -> BREAKS
  5. outnumbered AND in_the_open:
       pinned -> BREAKS,  not pinned -> WOULD_BREAK_IF_PINNED
  6. otherwise                                              -> SAFE
```

Break is a state. Evaluate it after every command resolves and at each phase start, and let it land the moment it is true: a player unit that breaks mid-phase forfeits the rest of that phase (GDD §5.5). Pinned + broken takes the broken move.

**Prerequisites** are phase 1.5.1: the unit fields (`adapted`, `scars`, `broken`, `is_founder`), `Taxonomy.is_long`, `Movement.reachable`, `CombatState.attackers_of`, the cone-stack faction filter and `CALL_RADIUS`. 1.6 is the rule on top of them and should add no new data.

**Break tests, one per definition, taken from the examples the definitions were chosen with:**

- Outnumbered: 2 guns on B with one friend adjacent is not outnumbered; the same fight with the friend 5 tiles away is. A downed friend adds nothing to the friend count
- In the open: a plank between B and a rifleman does not help, so B is in the open; the same plank against a pistol gives B a reachable unexposed tile, so B is not. Spend AP until the plank is out of reach and the answer flips
- Pinned does not zero the AP: a pinned unit one step from cover is not in the open
- Long cone: a rifle with a loaded Watch and B inside it breaks an unadapted CQB unit on Dry; the same rifle with no Watch does not; a **spent** Watch does not; a pistol Watch does not
- Clause 2 returns `WOULD_BREAK_IF_PINNED` when outnumbered and in the open but not Pinned, and `BREAKS` once it is Pinned
- Agoraphobia breaks a trained, rifle-carrying unit in the open on Mud; a unit without the scar in the same spot is `SAFE`
- The Call overrides every clause, including Agoraphobia
- Mid-phase landing: a shot that pins the last unit needed for clause 2 breaks it in the same command, and the player unit loses the rest of that phase

```
contact_check(map, state) -> ContactResult
```

Run after every free-move step (UI §17). Seeing is never contact. Contact starts when a hostile has a clean line on a squad body, or the player acts — fires, knocks, or starts a machine on a tile with a Live hostile (GDD §3.1).

**Test the degenerate reads from UI §7 directly**, because they are the rule's real specification:

- Circling a roof deck in its occupants' line **is** contact before any knock
- Surrounding an *interior* is legal and spends daylight — deck and interior differ by `CellFlags.DECK`
- A meeting is never contact
- The squad's own line never starts a fight (one-sided, on purpose)

**Final deliverable — the scripted fight.** One bowl, four bodies, walk until contact, exchange fire, one unit pinned, one broken, one bleeding out, extract. Asserted end to end, headless. When that test is green, this phase is done.

---

## 4. Explicitly out of scope

Not in this phase, and not to be "just quickly added":

- Any rendering, scene, camera or art. Nothing is visible when this is done
- The hydrology graph — feeders, support, creep, the step walking (GDD §6.1, §6.2). The water *step* is an input to a bowl here; the basin-scale network is a separate layer
- Table mode entirely: labor, dispatch, research, bands, the base
- The undo stack (the command *shape* is in; the stack is phase 3)
- Fog as a rendering concern. `BowlMap` holds authored occupants from the start (UI §17: *"Nothing spawns at the knock"*); which of them are *drawn* is a later question
- AP, cone length and bleed-out tuning. Working defaults in one constants file, not balance work

---

## 5. Verification

1. `make test` green, headless, no editor.
2. **Invariant suite passes on randomised bowls** — LOS symmetry, and exposure agreeing with LOS in both directions. These catch what hand-written cases will not.
3. **The scripted fight in `tests/fights/` passes**, and its assertions are readable as a description of the fight.
4. **No scene is loaded anywhere in `rules/`.** Grep for `preload(`, `Node`, `get_tree`, `Camera` under `rules/` and expect nothing. If the rules layer touches a scene, the phase failed regardless of green tests.
5. **No physics raycast anywhere.** Grep for `RayCast`, `intersect_ray`. UI §17 forbids it by name.
6. Every `working default` constant is in one file and tagged as such.

---

## 6. Sequencing note

1.2 (LOS) is the keystone — 1.3, 1.4, 1.5 and 1.6 all consume it. Do not start 1.3 until the LOS invariant suite is green, because an asymmetric LOS bug found later reads as an exposure bug and costs a day to trace.

1.6 was blocked on the §7.2 raise; it was answered in GDD 1.9, so nothing blocks it now. 1.5.1 carries the data and helpers it reads, and exists because the original plan specified 1.6 by what it returns and never traced what it consumes. Do 1.5.1 first: writing the break rule against fields that do not exist yet is how a phase turns into a scavenger hunt.

---

## 7. Decisions still needed

### 7.1 — The corner tie-break (resolved for 1.2)

A 3D line walk that passes exactly through the corner between two blocking cells is ambiguous: does the line pass, or is it stopped? Every grid tactics game answers this and the answer is felt constantly — it decides whether a diagonal peek works.

This is not an implementation detail. Under Principle 1 the preview and the rule are the same function, so whatever is chosen is *the rule*, and it should be written down rather than discovered in the walk implementation.

Options: permissive (passes unless both corners block), strict (blocked if either blocks), or a documented offset that makes the case unreachable. **Chosen: strict** — implemented as geometric supercover (closed unit cubes). It is the one a player can predict from looking, and an honest "blocked" is cheaper than a shot that looked legal.

**Raise to:** GDD §5.4 or UI §4.3 when those docs next open — record the rule there too.

### 7.2 — Break clause 2 and 3 rest on undefined terms (resolved in GDD 1.9)

GDD §5.5, verbatim: *"it is pinned and outnumbered in the open"* and *"stands on Dry with CQB kit while a long cone sees it."*

Three terms carry the rule and none is defined anywhere in the GDD:

| Term | Question |
| --- | --- |
| **outnumbered** | Ratio of what, within what radius? Whole map, or local? |
| **in the open** | No adjacent cover? Exposure `NO_HIDE`? Both? |
| **long cone** | What length makes a cone long? A fixed threshold, a per-weapon property, or relative to the map? |

`break_check` cannot be written without all three, and UI §4.6 promises the ingredients are telegraphed before the click — which means the player has to be able to *count* them. Whatever is chosen has to be countable on screen.

**Raise to:** GDD §5.5, as working defaults.

**Resolved.** Each term was put to a choice with alternatives, and the recommended option was taken in every case. The rules are now in GDD §5.5 under *Break, defined*, and the predicates are in §1.6 above.

| Term | Chosen | Not taken |
| --- | --- | --- |
| **outnumbered** | Local: standing hostiles with a clean line **>** standing friends within 3 tiles, counting the unit itself | Squad-wide headcount (a fireteam is at most four, so nearly every fight is permanently outnumbered); flanked by two or more guns regardless of friends |
| **in the open** | No tile reachable with the AP the unit holds is free of a clean line from every hostile that has one on it | No cover one step away (cheaper, less faithful to the mud line in GDD §6.3); the `NO_HIDE` terrain state (ignores real cover, contradicts §5.4) |
| **long cone** | A loaded, unspent Watch of a long weapon class with a clean line on the unit | Any long weapon with a line, Watch or not (a rifle standing in view would rout everyone, with nothing drawn to warn the player); a fixed 8-tile length threshold |

Three more calls were made without asking and are worth a look:

- **CQB kit** was a fourth undefined term. Taken as: every carried weapon is short, from "shotguns, machetes, and sidearms" in GDD §6.3.
- **When break is evaluated** was not stated. Taken as: after every action and at each phase start, landing immediately. GDD §5.5 already has broken player units losing "the rest of the current phase," which only makes sense mid-phase.
- **Agoraphobia** uses "in the open" in GDD §8.5 where clause 3 says "on Dry". Taken as clause 3 with kit, training and terrain waived. The alternative is to keep the Dry condition. It is listed in GDD §10.

**UI follow-up, done in UI/UX 0.5.** UI §4.6 was rewritten to draw what the rule counts: guns on the unit against friends within 3 tiles, cover in reach with the AP held, and a loaded long cone. Agoraphobia now reads as the third clause with kit, training and terrain waived, and §4.4 labels long cones with a word.

### 7.3 — When does `broken` clear? (working default, 1.5.1)

GDD §5.5 says a broken player unit loses the rest of the current phase and that its next move must end closer to cover or extraction. It never says when the state ends.

*Working default:* `broken` clears at the end of the unit's next phase, and break is re-checked at each phase start — so a unit still standing outnumbered in the open simply breaks again. This mirrors Pinned's "one hit costs one phase of action at most" (GDD §5.4) and needs no new concept.

**Raise to:** GDD §5.5 when it next opens. Low stakes, but undefined, and 1.6 cannot be written without picking something.

### 7.4 — What AP does a pinned unit have for "in the open"? (blocks the 1.6 tests)

GDD §5.5 says Pinned does not zero the AP for the test. The state machine zeroes it anyway (`apply_pin`), so the AP a pinned unit "holds" is not recoverable from `unit.ap`. 1.6 has to hand `Movement.reachable` a budget, and the choice is a real one:

- **A full phase's AP (`RulesConstants.AP_POOL`).** "Could this unit reach cover if it were free to move." Simple, and it is the reading the GDD sentence exists to protect. **Recommended.**
- **Keep the pre-pin AP** on the unit. Faithful to "the AP it holds", but adds a field that only this test reads, and the unspent AP of a ducked unit is not obviously meaningful.
- **Zero, as the state has it.** Every pinned unit is then in the open whenever anything has a line on it, which makes "in the open" a synonym for "exposed" and is what the GDD sentence rules out.

Whatever is chosen belongs in GDD §5.5's "Break, defined" as a working default.

### 7.5 — `Cell.occupant` was shared between a state and its copies (fixed)

`CombatState.duplicate_state()` shares the `BowlMap`, but `_set_occupant` and `move_occupant` wrote a live unit's id into `Cell.occupant` on that shared map. Two consequences:

- Applying a command changed the state it was applied to, against the contract at the top of §1.5. `MoveCommand._apply` wrote to the shared map from a copy.
- It destroyed authored data. `Cell.occupant` is the *authored* occupant of a roof or deck (UI §17: "occupants are data from the start… nothing spawns at the knock"). A unit walking onto a tile overwrote it, and walking off wrote `-1`, so any fight would have erased the people placed on roofs by data. The regression test reproduced exactly that: an authored `7` became `1`, then `-1`.

**Fix.** A fight never writes to the map. `_set_occupant` and `move_occupant` are gone, along with their four call sites (`add_unit`, both branches of `apply_damage`, and `MoveCommand`). Where a live unit stands lives in `CombatState.units`, which every copy owns; `Cell.occupant` stays as authored data and is documented as such on `Cell` and in `duplicate_state`. Nothing in `rules/` read the old field, so nothing else changed.

**Tests** (`tests/unit/test_state_isolation.gd`): adding a unit, applying a move and downing a unit each leave every cell of the map equal to a snapshot taken beforehand; an authored occupant survives a unit standing on and leaving its tile; sibling states diverge without affecting each other. The four that touch the map failed before the fix, and reintroducing either write makes them fail again.

`test_validate_does_not_mutate` is how this went unnoticed: it only checked a unit's AP.

### 7.6 — Two smaller ones

- **Exposure wording (non-blocking).** UI §4.2 says exposure shows "the count and where from." Add a line saying a hidden hostile contributes to the count without being located, mirroring §4.4's apex rule. Documentation, not a code change.
- **Levee maps (resolved for 1.1).** UI §3 allows two water surfaces on one map. `BowlMap` keeps one plane with `TODO(levee)` and a documenting test; promote to a region list before Act II levee maps.

---

## 8. What comes after

Phase 2 is the ugly debug view: a GridMap blockout with coloured tiles and text labels, no art, driven entirely by this layer. That is where the camera questions get settled (peek yaw, perspective vs orthographic — UI §18 wants both decided before a second bowl is authored), and where enemy cones and player exposure are seen on screen together for the first time.

That pairing is the real test of this design, since UI §4.4 already warns cones are *"the easiest to turn into soup"* and v0.4 put a second volumetric read on top of them. Reaching it quickly is the point of keeping phase 1 headless and small.
