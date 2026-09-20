# Phase 2 — Rules on screen (P0 kit)

**Status:** 2.0 completed — kit draws via catalog; next is overlay honesty (2.3 remainder) then a shared camera (2.1 / 2.5)
**Tracks:** GDD v1.10, UI/UX v0.5, assets inventory §16 (P0 pack)
**Depends on:** Phase 1 complete (`plans/01_bowlmap_functions_headless.md`); P0 art under `assets/`
**Filename:** "debug" is historical. The surface is the P0 kit, not a coloured GridMap. Do not rename mid-phase; links already point here.
**Goal:** every load-bearing tactical read is a drawing of a value `rules/` already returns — on the terrace kit, water shader, humanoid, cone shaders, and HUD chrome — and projection + peek yaw are decided before a second bowl is authored.

---

## 0. Why this, and why not coloured tiles

Phase 1 bought the only thing Principle 1 can stand on: *"a preview that disagrees with the rule function is a bug"* (UI §1). Headless green is not enough; the draw has to be forced to use those functions.

An earlier draft proposed a **coloured `GridMap` blockout** as the first visible join. That was right when there was no art. There is art now. Camera decisions (UI §18) and cone soup (UI §4.4) have to be judged on roofs, water height, and real cone volumes. A colour GridMap remains an optional **diagnostic overlay** (toggle: show rule cell vs mesh), not the shipped Phase 2 surface.

**What this phase buys.** Walk and fight one bowl with:

- Kit / props from `BowlMap` (cover tags honest)
- Water plane from `water_z` / `water_step`
- Live enemy cones and player exposure from `Cones.*` / `ExposureQuery`
- Move path and line hover from `Movement.path` / `Los.line_of_sight`
- HUD from unit / pin / bleed / break telegraph
- Projection + peek yaw decided on Flooded roof + Dry street

**What it deliberately does not buy.** Table mode, fog ageing as a finished system, undo stack UI, First Gauge, controller support, a second production bowl, or new rules to flatter a mesh (meshes lose).

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| Join point | **`presentation/` draws; `rules/` decides** | Hover and confirm call the same functions tests use. No parallel LOS in the view. `gallery.gd` stays art-only. `make run` → `fight_view.gd`. |
| Geometry | **P0 terrace kit + props**, driven by `BowlMap` | Cell size **2 m**. `presentation/coords.gd` owns world mapping (data `z` = level, Godot Y-up). Coloured GridMap is an optional toggle. |
| Overlays | **Existing shaders / HUD from `assets/`** | Inputs are rule return values. Colour never carries a load-bearing read (UI §14). |
| Data in | **Same types Phase 1 ships** | `BowlMap`, `CombatState`, commands. No view-model that recomputes sight. |
| Camera scope | **Decide projection + peek yaw here** | UI §18 blocks a second authored bowl until both are settled. |
| Interaction | **Mouse + keyboard only** | Controller stays out (UI §18). |
| Picking | **Math ray vs the ground plane**, not physics | Input-only. `rules/` still has no raycasts. A pick that disagrees with `coords.cell_on_ground` is a view bug. |
| Enemy turn in the view | **Presentation driver**, not a rule | Greedy legal `ShootCommand`s then `end_phase`. Do not put AI in `rules/`. |
| Fixture | **One opening, two consumers** | The scripted-fight street is the fight view's default map. Do not fork the opening in `fight_view._opening()`. |

---

## 2. Layout

```
assets/                    # P0 pack — do not fork
presentation/
  coords.gd                # cell <-> world (2 m, level = 3 m)
  catalog.gd               # mesh lookup by CoverMaterial + kit id
  bowl_draw.gd             # instance kit from BowlMap (must use catalog)
  water_plane.gd           # height + step from data
  unit_view.gd
  watch_cone_view.gd       # volumes from Cones.*; apex_known
  selection_ring.gd
  hud.gd                   # counts & words
  overlay_queries.gd       # NEW: last queried cone/exposure/path/los — testable without a scene
  camera_rig.gd            # NEW: rest pose, 90° snap, 3 zooms, perspective/ortho, peek
  fight_view.gd            # input -> validate/apply
  gallery.gd               # art-only flooded bowl (not a fight)
scenes/p0/
  flooded_roof.tscn        # camera-test fixture
  dry_street.tscn
rules/                     # unchanged ownership
tests/
  fights/                  # still the authority for the scripted fight
  presentation/            # overlay agreement against overlay_queries (no Node in rules/)
```

If a thin diagnostic toggle helps (cell bounds, dump `LosResult` text), parent it under the fight view. Do not build a second game in `debug/`.

---

## 3. Deliverable phases

Each slice ends with `make test` green. Checkpoint when the **read is honest**, not when the lighting is pretty.

### 2.0 — BowlMap draws the P0 kit

**Status:** completed

**Ships:** `bowl_draw` instances a mesh per cell from `BowlMap`.

**What landed.** Dry fight street: AIR → terrace slabs, MASONRY/PLANK/CRATE/METAL → tagged props. Sparse empty stays empty. `coords.gd` maps `Vector3i(x,y,z)` with `z` = level. Every instance goes through `PresentationCatalog.piece_for_cell` / `scene_for_piece`. Masonry runs use `env_canal_wall_tall` (yaw 90° for data-y runs); isolated masonry keeps the corner prop. Gap materials get one magenta marker. Hover names `cover_of` on the drawn piece. `tests/presentation/test_catalog_bowl.gd` locks the tags.

**Still open (later slices).**

- The default fight is **z = 0 only**. Roofs, interiors, and Flooded height are not drawn from data yet — see 2.2.
- `scenes/p0/` still owns lighting massing as a fixture, not as a `BowlMap`.

---

### 2.1 — Camera rest pose on real massing

**Status:** not started (fight_view has a one-off `Camera3D`, 25° look-at, no snap / zoom / ortho / peek)

**Ships:** one `camera_rig.gd` used by `fight_view` **and** `scenes/p0/` (or a thin wrapper so F6 on those scenes is the same rig).

- Fixed elevated pitch (25° *working default* until 2.5)
- Yaw snaps in 90° steps
- Zoom between 3 set levels (UI §2)
- Toggle: perspective (FOV 25°) ↔ orthographic
- Peek yaw prototype for 2.5 (hold off-snap, release springs back)

**Done when:** `flooded_roof`, `dry_street`, and the fight street share that code path.

**Out for 2.1:** wall fade in front of friendlies (UI §2) — listed in §8.

---

### 2.2 — Units, cutaway, water from data

**Status:** partial

**What landed.** `unit_view` on the shared humanoid (pistol / machete sockets). Water plane uses `water.tres`; Dry fight sets step 3 and Y ≈ 0. Selection ring under the selected body.

**Still open.** Floor cutaway by `z` (UI §2, §17). Height-on-tile numbers with a unit selected. `water_z` driving plane Y in metres (`coords.LEVEL_M * water_z`, not a magic 2.4). Step change updates the shader without rebuilding the kit. Roof units stay selectable when the camera is on the street.

**2.2 needs a z > 0 fixture.** The scripted fight cannot prove cutaway. Add a small authored `BowlMap` (or a resource) with a street + one roof deck + `water_step = FLOODED`, used only for this slice and for 2.3's Falling `NO_HIDE`. Do not wait on a second production bowl.

**Done when:** cutaway hides higher floors; a roof unit is selectable; Flooded vs Dry is the same kit, different plane; Falling vs Flooded still splits in greyscale **and** in the exposure word.

---

### 2.3 — Cones and exposure together

**Status:** partial — **this remains the visual keystone**

**What landed.** Enemy live volumes from `Cones.watch_cone`; `apex_known` picks unresolved-apex mode; spent watches skip the volume; selected-unit exposure icon from `ExposureQuery`; HUD can say `seen by N`.

**Still open (honesty, not new art).**

| Draw | Source | Gap now |
| --- | --- | --- |
| Stacking label | `Cones.cone_stack` | Missing. Need count + class words, no extra hues |
| Long | `Taxonomy.is_long` | Missing. Label "rifle, long" — word, not colour (UI §4.4) |
| Exposure on the unit | `ExposureQuery` | Icon only. Need the **word** (hidden / exposed / no hide), the count, and locatable sources — not a heat map |
| Path exposure | `MovePath.exposure_per_cell` | Path is cream planes. Per-tile hidden / exposed / no hide not drawn |
| Friendly cone | UI §4.4 | Outline at rest; full volume when selected **or** a move preview crosses it. Crossing not implemented |

**Invariant, tested without a scene.** Extract queries into `presentation/overlay_queries.gd` (pure over `map` + `state` + selection + hover). A GUT file under `tests/presentation/` asserts:

```
queries.cone_cells == Cones.cone(...)
queries.exposure.count == CombatState.attackers_of(...).size()
queries.path.shot_reserve_at == Movement.path(...).shot_reserve_at
```

The view is only allowed to draw `queries.*`. If the mesh disagrees, the overlay is wrong — not the rule.

**Done when:** Phase 1 fixtures (smoke apex, plank rifle-vs-pistol, Falling `NO_HIDE`) are visible on kit geometry **and** the overlay_queries tests match headless asserts. Path chrome on a lying exposure draw does not ship.

---

### 2.4 — Path, line, HUD, commands

**Status:** partial

**What landed.** Click tile → `FreeMoveCommand` until contact, then `MoveCommand`. Click hostile → `ShootCommand`. Q → `WatchCommand`. Space / phase plaque → `end_phase`, then a presentation-side greedy enemy. Hover path from `Movement.path` with reserve **indices**. Line hover names pins / drops / kills / named blocker in the HUD string. Break telegraph (`if hit here, breaks`) on the selected unit. `validate()` before `apply()`.

**Still open.**

- Reserve marks must be **shapes** (`ui_path_reserve_shot` T-bar, `ui_path_reserve_watch` wedge), not two cream tints. Colour-only reserves fail UI §14.
- Path shows AP **cost per tile** (Mud doubles in the step, not as a surprise at the end).
- Path shows Watch **crossings** and the one shot a crossing draws (`MovePath.watches_crossed`).
- Line uses `ui_line_clean` / `ui_line_blocked` (dash vs solid), not only a HUD sentence.
- Hovering **cover** (no unit) names which classes it stops (`Taxonomy.stops`).
- Unaffordable shot is drawn with its cost, not hidden (UI §4.1).
- Confirm on **kills a bleeder** (UI §4.3 / §5).
- Both sides' hit pips on the body, not only the selected HUD.
- Opening duplicated in `fight_view._opening()` — see 2.6.

**Done when:** a human can drive the scripted-fight *shape* without the debugger, and every preview is a field on `overlay_queries`.

---

### 2.5 — Camera decision lock

**Status:** not started (blocked on 2.1 existing)

**Ships:** written decision in §7.1–7.2; rig defaults flipped to match; raise into UI §18 on the next UI edit.

**Procedure:** same fight **and** p0 bowls under perspective vs orthographic, with and without peek, including a **diagonal** path / cone edge. Pick one projection and one peek policy for all later authoring.

**Recommend (bias, not lock):** keep perspective 25° if roof and water height read on `flooded_roof`; enable peek if diagonal authorship feels punished. Orthographic only if height collapses on that roof.

---

### 2.6 — Scripted fight smoke on screen

**Status:** not started as a shared fixture (the view *looks* like the fight but rebuilds it)

**Ships:** one function or Resource both `tests/fights/test_scripted_fight.gd` and `fight_view.gd` call for the opening `CombatState`. Stepping the recorded command list is optional; matching the opening is not.

**Done when:** contact → phases → pin → break/bleed is visible from that fixture; `make test` remains the authority. On-screen pass is smoke, not a second rules suite.

**Do not** special-case overlays if a broken enemy still counts as a gun (Phase 1 §7.8). If it feels wrong, raise the GDD.

---

## 4. Explicitly out of scope

- Replacing P0 art with a colour-GridMap game (diagnostic toggle only)
- Table mode, dispatch, research, bands, FOBs
- Finished fog peel / Known-quiet ageing
- Undo stack UI (command shape waits for commit chrome — UI §5)
- First Gauge / The Call pictures
- Off-ramp / prisoner chrome
- Controller support
- Second authored production bowl
- New rules to flatter a mesh
- Expanding `gallery.gd` into a fight
- Wall fade (UI §2) — after 2.5
- Enemy AI as a rules module

---

## 5. Verification

1. `make test` green — including `tests/presentation/` overlay agreement. No rules regressions.
2. `make run` opens the rules-driven fight view. `gallery.gd` / `scenes/p0` remain art checks.
3. **Overlay agreement:** cone cells, exposure count, path reserves, line blocker match `overlay_queries` vs `rules/` on a fixture.
4. **No LOS raycasts in `rules/`.** Picking rays for mouse selection are input-only and must not be consulted by LOS.
5. **Cover tags:** the hover names the `CoverMaterial` the catalog assigned to that mesh.
6. Camera decision recorded in §7.1–7.2 before work that assumes a second bowl layout.
7. Accessibility: every load-bearing overlay has a non-colour channel (UI §14) — words on exposure / long / pin / break; cone count text; path reserves by **shape**; water step not colour-only.

---

## 6. Sequencing note

Do not treat 2.0–2.4 as greenfield. Finish **honesty on the existing fight_view** (catalog routing, overlay_queries + tests, path/line second channel, shared opening) before camera bike-shedding.

**2.3 remainder before 2.4 chrome.** Path tiles on a lying exposure draw wastes a day.

**2.2's z>0 fixture** can land in parallel with 2.3 tests; cutaway is blocked on that fixture.

**2.1 and 2.5** share one rig. Complete 2.5 before diagonal levee authoring.

**2.6** is proof once overlays are honest and the opening is shared.

---

## 7. Decisions still needed

### 7.1 — Projection (blocks second bowl — UI §18)

Perspective (25°) vs orthographic. Test on Flooded roof + Dry street. Record in 2.5.

### 7.2 — Peek yaw (blocks second bowl — UI §18)

90° only vs hold-to-peek. Record in 2.5.

### 7.3 — Entrypoints

**Working default (landed):** `make run` → fight view. `gallery.gd` / `scenes/p0` remain art and lighting checks. Add `make run-gallery` only if people keep opening the wrong scene.

### 7.4 — Missing kit cells

**Working default:** empty + log, or one magenta marker. Never a whole-bowl colour language.

### 7.5 — Open from Phase 1 (not Phase 2's to solve)

Broken enemies still count as guns in exposure / outnumbered (Phase 1 §7.8). If on-screen play makes that feel wrong, raise the GDD — do not special-case the overlay.

Last unit out breaks on the boat (Phase 1 §7.7): same rule — draw it, don't hide it.

### 7.6 — Shared opening (blocks 2.6)

Move the scripted-fight `_street` / `_opening` to a module both the test and the view load (e.g. `rules/fixtures/scripted_fight.gd` or `tests/fights/opening.gd` preloaded by the view). A fight_view that rebuilds the map by hand will drift.

### 7.7 — Path reserve language

**Working default:** use the existing HUD shapes (T-bar = shot reserve, wedge = Watch reserve). Do not invent a third cream tint.

---

## 8. What comes after

Polish on the same join: fog peel, commit/confirm chrome, throw/interact gizmos, wall fade, animation from command outcomes. Table mode stays a separate spine (UI §8).

Do not start a second production bowl until §7.1 and §7.2 are locked.
