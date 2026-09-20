# Phase 1 — BowlMap and the rules layer, headless

**Status:** not started
**Tracks:** GDD v1.8, UI/UX v0.4
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

**Ships:** GUT vendored and pinned. `make test` target. One deliberately failing test, then one passing, to prove the loop.

**Done when:** `make test` reports pass/fail and exits non-zero on failure, headless, with no editor open.

---

### 1.1 — BowlMap and the taxonomies

**Ships:** `taxonomy.gd`, `cell.gd`, `bowl_map.gd`.

```
Cell:
  material : Material     # what it stops
  flags    : int          # SHELTER | DECK | SWIMMABLE | INTERIOR ...
  occupant : int          # unit id, -1 for none

BowlMap (Resource):
  cells      : Dictionary[Vector3i, Cell]
  water_step : WaterStep  # FLOODED | FALLING | MUD | DRY
  water_z    : int        # surface level; one plane per bowl (UI §3)
```

Material set for P0, from the assets doc §1 shared cover language: `AIR, PLANK, CRATE, MASONRY, METAL, DEPLOYED_BARRIER, SMOKE, WATER_DEEP, WATER_CHEST, GROUND`.

Weapon classes from assets §6.2: `PISTOL, MELEE, SPEAR, SHOTGUN, RIFLE, LMG, SNIPER`.

One table, `Material × WeaponClass -> bool stops`, and it is the single source of truth. A plank stops a pistol and not a rifle (GDD §5.4); the hover read in UI §4.3 names whatever this table says.

**Done when:** a bowl can be built in code, round-tripped through `ResourceSaver`/`ResourceLoader`, and the stopping table is exhaustively tested.

**Watch for:** levee maps hold two water surfaces (UI §3). Either `water_step`/`water_z` become per-region now, or the type carries a `TODO` and a test that documents the limitation. Do not discover this in phase 4.

---

### 1.2 — Line of sight

The keystone. Everything after this consumes it.

**Ships:** `los.gd`.

```
line3d(a: Vector3i, b: Vector3i) -> Array[Vector3i]
line_of_sight(map, from, to, weapon) -> LosResult
    LosResult: { clean: bool, blocker: Material, blocker_cell: Vector3i }
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

**Decision needed before this ships** — see §7.1, the corner tie-break.

---

### 1.3 — Exposure and cones

Both are LOS derivatives, so they ship together and share tests.

**Ships:** `exposure.gd`, `cones.gd`.

```
exposure(map, state, unit) -> Exposure
    Exposure:
      state   : HIDDEN | EXPOSED | NO_HIDE
      count   : int                  # every hostile with a clean line
      sources : Array[Vector3i]      # only those the viewer can see

cone(map, watcher, facing, weapon) -> Array[Vector3i]
cone_stack(map, state, cell) -> { count: int, classes: Array[WeaponClass] }
```

`count` and `sources.size()` differ exactly when a hostile is hidden. That gap **is** the decision from §1 — it is the data the UI needs to say "seen by 2" while placing only one.

`NO_HIDE` is a property of where the unit stands (Falling, open Dry), not of who is looking. It is returned in words so it survives greyscale (UI §14).

Cones carry `apex_known: bool`. When false the renderer dissolves the near end (UI §4.4); this layer just reports it.

**The invariant that matters most:**

```
exposure(map, state, u).count > 0
  <==>  exists h in hostiles(u): los(map, h.cell, u.cell, h.weapon).clean
```

UI §17: *"One implementation, two directions — if they can ever disagree, Principle 3 is a lie."* Test it as a property over generated maps, not as three hand-written cases.

**Done when:** exposure and cone stacking agree with LOS on randomised bowls, and the hidden-watcher gap is asserted directly.

---

### 1.4 — Movement, AP, and the reserve read

**Ships:** `movement.gd`.

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

**Working default needed:** AP digits. GDD §5.3 says exact digits are prototype work, so pick one set, mark it `working default` in the code, and keep it in one constants file so tuning is a single edit.

---

### 1.5 — Combat state and commands

**Ships:** `combat_state.gd`, `commands/`.

```
Command:
  validate(state) -> Result       # never mutates; this is what previews call
  apply(state)    -> CombatState  # returns new state
```

Previews call `validate()`. The UI in phase 3 renders the `Result`. Nothing draws a decision the rules layer has not already priced.

**Rules to implement, all locked in GDD 1.7/1.8:**

| Rule | Source | Note |
| --- | --- | --- |
| Any non-drop hit pins | GDD §5.4 | There is no suppression weapon class |
| Hit in own phase | GDD §5.4 | `DUCKED` — rest of phase gone, clears at end of it |
| Hit in opponent's phase | GDD §5.4 | `DUCKING_NEXT` — live Watch cancels at once, next phase spent ducked |
| One hit costs one phase at most | GDD §5.4 | Explicitly no stunlock. Test it |
| Watch: one watch, one shot | GDD §5.2 | Cancels if the watcher is Pinned first; cone shows spent |
| Health | GDD §5.4 | Rifle drops; two pistol hits drop. Pips, both sides |
| Bleeding Out | GDD §5.5 | 3 rounds *working default*; a round is one player phase + one enemy phase |
| Trauma kit | GDD §5.5 | Stops the clock |

**Done when:** a two-unit exchange can be driven entirely through commands and every state above is asserted.

---

### 1.6 — Break, contact, and the scripted fight

The proof.

**Ships:** `break_rule.gd`, `contact.gd`, `tests/fights/`.

```
break_check(map, state, unit) -> BreakResult
    BreakResult: BREAKS | WOULD_BREAK_IF_PINNED | SAFE
```

Three return values, not two, and that is the point. GDD §5.5's second clause needs the unit to *be* Pinned, which needs an enemy to choose to shoot it — intent, which UI §4.6 refuses to draw. So clause 2 returns `WOULD_BREAK_IF_PINNED` and the preview renders it as *"if hit here, breaks."* Clauses 1 and 3 return `BREAKS` unconditionally.

Also: the Agoraphobia scar makes clause 3 unconditional for that unit regardless of training (GDD §8.5, UI §4.6); units inside The Call's radius cannot break (GDD §8.4); a unit that is both Pinned and broken takes the broken move (GDD §5.5, 1.7).

**Two clauses cannot be implemented as written — see §7.2.** Clause 2 and clause 3 both rest on undefined terms. This phase is blocked on that raise.

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

1.6 is blocked on the §7.2 raise. Everything before it is not, so the raise can be resolved while 1.0–1.5 are built.

---

## 7. Decisions still needed

### 7.1 — The corner tie-break (blocks 1.2)

A 3D line walk that passes exactly through the corner between two blocking cells is ambiguous: does the line pass, or is it stopped? Every grid tactics game answers this and the answer is felt constantly — it decides whether a diagonal peek works.

This is not an implementation detail. Under Principle 1 the preview and the rule are the same function, so whatever is chosen is *the rule*, and it should be written down rather than discovered in the walk implementation.

Options: permissive (passes unless both corners block), strict (blocked if either blocks), or a documented offset that makes the case unreachable. **Recommend strict** — it is the one a player can predict from looking, and an honest "blocked" is cheaper than a shot that looked legal.

**Raise to:** GDD §5.4 or UI §4.3. It is a rule, so probably the GDD.

### 7.2 — Break clause 2 and 3 rest on undefined terms (blocks 1.6)

GDD §5.5, verbatim: *"it is pinned and outnumbered in the open"* and *"stands on Dry with CQB kit while a long cone sees it."*

Three terms carry the rule and none is defined anywhere in the GDD:

| Term | Question |
| --- | --- |
| **outnumbered** | Ratio of what, within what radius? Whole map, or local? |
| **in the open** | No adjacent cover? Exposure `NO_HIDE`? Both? |
| **long cone** | What length makes a cone long? A fixed threshold, a per-weapon property, or relative to the map? |

`break_check` cannot be written without all three, and UI §4.6 promises the ingredients are telegraphed before the click — which means the player has to be able to *count* them. Whatever is chosen has to be countable on screen.

**Raise to:** GDD §5.5, as working defaults. Suggest: outnumbered = more hostiles than friendlies with a clean line on this unit; in the open = exposure is `NO_HIDE` or no adjacent cover cell; long cone = a per-weapon-class property, since Vanguard cone length is already the thing that makes their streets deadly (GDD §5.2).

### 7.3 — Two smaller ones

- **Exposure wording (non-blocking).** UI §4.2 says exposure shows "the count and where from." Add a line saying a hidden hostile contributes to the count without being located, mirroring §4.4's apex rule. Documentation, not a code change.
- **Levee maps (blocks 1.1 if deferred badly).** UI §3 allows two water surfaces on one map. Decide now whether `BowlMap` carries one water plane or a list, even if the second is unused until Act II.

---

## 8. What comes after

Phase 2 is the ugly debug view: a GridMap blockout with coloured tiles and text labels, no art, driven entirely by this layer. That is where the camera questions get settled (peek yaw, perspective vs orthographic — UI §18 wants both decided before a second bowl is authored), and where enemy cones and player exposure are seen on screen together for the first time.

That pairing is the real test of this design, since UI §4.4 already warns cones are *"the easiest to turn into soup"* and v0.4 put a second volumetric read on top of them. Reaching it quickly is the point of keeping phase 1 headless and small.
