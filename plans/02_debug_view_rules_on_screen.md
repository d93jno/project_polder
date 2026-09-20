# Phase 2 — Rules on screen (P0 kit)

**Status:** 2.0–2.5 completed — camera projection + peek locked; next is shared scripted-fight opening (2.6)
**Tracks:** GDD v1.10, UI/UX v0.6, assets inventory §16 (P0 pack)
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
  overlay_queries.gd       # last queried cone/exposure/path/los — testable without a scene
  camera_rig.gd            # rest pose, 90° snap, 3 zooms, perspective/ortho, peek
  fight_view.gd            # input -> validate/apply; draws queries.* only for overlays
  fixtures/cutaway_bowl.gd # street + roof + plank/smoke watches (2.2–2.3); not the scripted fight
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

**Status:** completed

**Ships:** one `camera_rig.gd` used by `fight_view` **and** `scenes/p0/` (regenerated via `_build_p0_scenes.gd`).

**What landed.** Fixed elevated pitch (`PITCH_DEG` 40.7°, FOV 25°). Yaw snaps 90° (`[` / `]` / `,` / `.`). Three zoom distances (wheel / `-` `=`). Perspective ↔ orthographic (`O`). Hold-to-peek (MMB or Alt+drag), release springs back. Rest eye matches the old P0 (−24, 30.5, 2) → look (8, 3, 2). `tests/presentation/test_camera_rig.gd` locks the pose math.

**Out for 2.1:** wall fade in front of friendlies (UI §2) — listed in §8. Projection / peek **policy** lock waits for 2.5.

---

### 2.2 — Units, cutaway, water from data

**Status:** completed

**What landed.** `unit_view` on the shared humanoid. Water plane Y = `LEVEL_M * water_z` via `PresentationCoords.water_height_m`; step updates the shader without rebuilding the kit (`F` toggles Falling ↔ Flooded). Floor cutaway (`PgUp` / `PgDn`) hides kit + units above N. Height-on-tile `Label3D` digits when a unit is selected. Deck cells draw `env_roof_deck_a`. Picking rays the cutaway floor so roof tiles select. Tab / fireteam still select a roof unit when cutaway is on the street. Fixture: `presentation/fixtures/cutaway_bowl.gd` (street + roof, FLOODED default). Exposure **word** in the height read (`hidden` / `exposed` / `no hide`). Tests: `tests/presentation/test_cutaway_water.gd`.

**Note.** `make run` opens the cutaway fixture for this slice. `_scripted_fight_opening()` is kept for 2.6's shared opening.

---

### 2.3 — Cones and exposure together

**Status:** completed

**What landed.** `presentation/overlay_queries.gd` is the only overlay source. Fight view draws `queries.*` for cones, path, LOS hover, stack, and exposure. Stacking label (`N watches: rifle, long, pistol`). Long is a word on each cone tip. Exposure word + count + locatable sources on the selected body and in the HUD. Path tiles show per-cell exposure words (hidden / exposed / no hide). Friendly cones: outline at rest; full volume when selected or a move preview crosses. Fixture adds plank + rifle Watch and smoke Watch (unresolved apex); `F` still toggles Falling. Tests: `tests/presentation/test_overlay_queries.gd`.

**Still open (2.4).** Path reserve **shapes**, AP cost digits, watch-crossing marks, line chrome — not colour-tinted reserves.

---

### 2.4 — Path, line, HUD, commands

**Status:** completed

**What landed.** Click tile → `FreeMoveCommand` until contact, then `MoveCommand`. Click hostile → `ShootCommand`. Q → `WatchCommand`. Space / phase plaque → `end_phase`, then a presentation-side greedy enemy. Hover path from `Movement.path` with reserve **shapes** (`ui_path_reserve_shot` T-bar, `ui_path_reserve_watch` wedge), per-tile AP cost, and Watch crossing labels (`crosses shotgun`). Line uses `ui_line_clean` / `ui_line_blocked` plus HUD outcome (pins / drops / kills / named blocker) and shot cost — unaffordable stays visible. Cover hover names `Taxonomy.stops` via `cover_stops_label`. Confirm on **kills a bleeder** (second click; Esc cancels). Hit pips on every visible body. Break telegraph on the selected unit. `validate()` before `apply()`. Overlay fields live on `overlay_queries` (tests in `test_overlay_queries.gd`).

**Still open.**

- Opening duplicated in `fight_view._opening()` — see 2.6.

**Done when:** a human can drive the scripted-fight *shape* without the debugger, and every preview is a field on `overlay_queries`.

---

### 2.5 — Camera decision lock

**Status:** completed

**What landed.** Locked on Flooded roof + Dry street (`scenes/p0/`) and the cutaway fight fixture:

- **Projection:** perspective, FOV 25° (`PresentationCameraRig.FOV_DEG`). Orthographic collapses freeboard on the flooded roof into a flat parallel frame; perspective keeps water→eaves height as an angular read. `O` stays as a diagnostic toggle only; `reset_to_locked_policy()` returns to perspective.
- **Peek:** hold-to-peek (MMB or Alt+drag, springs back). 90°-only would punish diagonal levees and force axis-aligned authorship (UI §2). Peek max 35°.

Defaults in `camera_rig.gd` (`LOCKED_ORTHOGRAPHIC`, `LOCKED_PEEK_ENABLED`) match. Raised into UI §2 / §18. Tests in `test_camera_rig.gd` assert the lock and rest-eye clearance over flooded eaves.

**Still open.** Wall fade (UI §2) — after this lock (§8).

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

**Locked (2.5):** perspective, FOV 25°. Orthographic is diagnostic only (`O`), not the fight or authoring default. Height on Flooded roof (water → eaves freeboard) stays readable; ortho flattened it.

### 7.2 — Peek yaw (blocks second bowl — UI §18)

**Locked (2.5):** hold-to-peek (MMB / Alt+drag, spring-back). Not 90°-only — diagonals stay authorable.
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

Do not start a second production bowl until §7.1 and §7.2 are locked — **they are** (2.5).
