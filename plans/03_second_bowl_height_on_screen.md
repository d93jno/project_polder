# Phase 3 — The second bowl: height, walls, water through a house

**Status:** 3.0–3.6 completed — Flooded terrace headless + on screen; wall fade; stamps/lint; render smoke; exposure split; water depth look
**Tracks:** GDD v1.10, UI/UX v0.7, assets inventory §16 (P0 pack)
**Depends on:** Phase 2 complete (`plans/02_debug_view_rules_on_screen.md`, 2.0–2.6); its §7.1–7.2 camera lock is in force.
**Naming:** "Phase 3" here is the third *implementation plan*. It is unrelated to the GDD's "Phase 3: The Compound" (§3.2), which is a base phase.
**Goal:** a second authored bowl that is not a flat street — a Flooded terrace with houses, floors, roofs and a legal way up — that is asserted headlessly and playable on screen exactly as the first is; walls fade so the camera never hides a friendly; and on-screen breakage fails a command instead of being noticed by eye.

---

## 0. Why this, and why not the alternatives

**Height has never been played.** Everything on screen in Phase 2's fight is z = 0 on one street. Cutaway, `water_z`, roofs, climb surcharge and dive-to-Hidden all exist in `rules/` and have tests, but on screen they have only appeared in an 8×4 presentation fixture (`presentation/fixtures/cutaway_bowl.gd`), not in a fight. UI §2's height reads and UI §3's "authored once, played at four steps" are unproven until a bowl needs them. Phase 2 §8 unblocked a second bowl; this is it.

**The on-screen review found bugs headless cannot see.** A GDScript `##` comment in `watch_cone.gdshader` made the shader fail to compile, so every cone drew as an opaque cream cylinder. A keying shader dropped `modulate`, so the AP and Hits pips never dimmed. The far-field ridge sat on top of the street tiles. All 226 tests were green through all of it, and all of it was found by eye. A taller bowl adds more of this, so the first slice is a render smoke check.

**Why not the neighbours.**

- *Table mode* (UI §8) is a separate spine. It needs a bowl worth deploying to before it has anything to point at.
- *Polish on the same join* (fog peel, commit chrome, gizmos, Phase 2 §8) depends on this. Fog peel needs rooms to hide things in; interact gizmos need a hatch and a sluice to act on.

**What this phase deliberately does not buy.** Fog peel, table mode, undo chrome, a third bowl, new art, or a rule change to flatter a mesh (meshes lose).

---

## 1. Decisions taken

| Decision | Choice | Consequence |
| --- | --- | --- |
| Second bowl | **Flooded terrace**, one authored bowl, played at Flooded / Falling / Mud / Dry | UI §3. The data is authored once; the water step changes cost, exposure word and plane. Ground-floor cells are swimmable. |
| Truth | **Cells are data; stamps are the draw table** | A multi-cell kit piece (house, deck, stair) is a `Stamp` over cells. It never adds a rule. A lint test proves stamps and cells agree. |
| Wall fade | **Presentation only, geometry math, no physics** | Same posture as mouse picking (Phase 2 §1): input/view only, never consulted by `rules/`. It never changes LOS, cover tags or the hover text. |
| What may fade | **Only for friendlies** | UI §2: the camera never hides a unit the player controls. A fade must never be the way a hostile becomes visible; fog will own that later. |
| Vertical moves | **No rule change in this phase** | `Movement` allows a step between any two vertically adjacent placed cells. Authoring lint enforces "connectors only"; whether the rule needs a link flag is a GDD question (§7.1). |
| Entry point | `make run BOWL=terrace` | Default stays the scripted street. Passes `-- --bowl=terrace`. No in-game bowl picker. |
| Render smoke | **`make shots`**, real renderer, not part of `make test` | Needs a GPU and a display. Fails on shader/script errors and a few pixel probes. Not golden-image diffs (driver-fragile). |
| Fixture ownership | **One opening, two consumers** (as 2.6) | `rules/fixtures/flooded_terrace.gd` is loaded by the headless fight *and* the view. The view forks nothing. |

---

## 2. Layout

```
rules/fixtures/
  flooded_terrace.gd        # opening(step) -> CombatState; cells only, no art ids (rules must not know art)
presentation/
  stamp.gd                  # Resource: piece_id, origin Vector3i, yaw. Draw table entry
  fixtures/
    flooded_terrace_stamps.gd   # stamps for that opening; presentation-side
  wall_fade.gd              # occluders(cam, target, aabbs) -> pure; node applies transparency
  catalog.gd                # + FOOTPRINTS (piece -> cells x levels) and connector ids
  bowl_draw.gd              # + draw_stamps(); floors as separate nodes per level (UI §17)
  fight_view.gd             # + --bowl arg, per-bowl look point, water-step cycle key
tests/
  fights/test_flooded_terrace.gd       # headless, asserts its own outcome
  presentation/test_bowl_authoring.gd  # lint: stamps vs cells, climbs, overlaps
  presentation/test_wall_fade.gd
  shots/capture.gd                     # not a GUT test; driven by scripts/shots.sh
scripts/shots.sh                       # make shots
```

---

## 3. Deliverable phases

Each slice ends with `make test` green. `make shots` joins the checkpoint from 3.0 onward.

### 3.0 — Render smoke (`make shots`)

**Ships:** `scripts/shots.sh`, `tests/shots/capture.gd`, and a `shots` target in the `Makefile`. The script opens the fight view in a real window, applies a named setup, waits ~20 frames, and writes PNGs under `build/shots/`.

**Setups:**

- `street_watch` — Piet sets a rifle Watch, hover (10,5). This is the exact state that hid both shader-class bugs.
- `street_ap_spent` — same, asserting the HUD.

**Fails when:** stderr contains `SHADER ERROR`, `SCRIPT ERROR` or `ERROR:`; or a pixel probe fails. Two probes only: a spent AP pip is darker than a lit one (guards the `modulate` bug), and the cone's centre pixel is not opaque (guards the cream-cylinder fallback). Probes read named HUD/world positions, not whole-frame diffs.

**Done when:** temporarily restoring the `##` comment in `watch_cone.gdshader`, or the old `COLOR = c` in `mint_key.gdshader`, makes `make shots` exit non-zero. Write it against those two regressions first.

**What landed.** `scripts/shots.sh`, `tests/shots/capture.gd`, `make shots`. Setups `street_watch` / `street_ap_spent` (later `street_yaw180`, terrace shots). Pixel probes for spent AP pip and translucent cone.

**Note.** The capture script may poke `fight_view` privates (`_hover`, `_try_watch`). If that gets brittle, add one public seam, not a test-only mode.

---

### 3.1 — Wall fade

**Ships:** `presentation/wall_fade.gd`. For each visible friendly, test the segment camera → unit's head against the world AABB of each drawn bowl piece. A pure function returns the occluding piece ids; the node then eases those pieces' `GeometryInstance3D.transparency` toward the fade value and back when clear. Only pieces at or below the cutaway level are candidates; only tall pieces (masonry, houses, tall quay) can occlude at all.

**Not changed by it:** `cover_tag_at`, the hover words, `Los`, `Cones`, `Exposure`. A faded wall is still masonry and still stops the shot the preview names.

**Working default:** fade to ~25 % opacity, not zero, so the silhouette and top edge stay as a non-colour channel (UI §14) and a faded wall still reads as "there is a wall". Confirm in §7.2.

**Tests:** `test_wall_fade.gd` — segment-vs-AABB on hand-built boxes (hit, miss, grazing, camera inside); friendlies only; a hostile behind a wall does not fade it; a piece above the cutaway is never a candidate.

**Done when:** on the scripted street, yaw 180 puts the tall quay between the camera and Piet: the quay fades, Piet is visible, hover still says `masonry`, and a `street_yaw180` shot is in `make shots`.

**What landed.** `presentation/wall_fade.gd` — segment vs AABB, friendlies only, ~25 % opacity. UI §2 updated (v0.7).

---

### 3.2 — Authoring layer: stamps and lint

**Why now.** Today `piece_for_cell` maps one cell to one mesh. That is wrong for a bowl: `env_roof_deck_a` is a 4×4 m mesh (assets MANIFEST) but is instanced at *every* `DECK` cell of 2×2 m, so adjacent deck cells overlap. It is invisible in the one-cell fixture roofs and wrong the moment a roof is bigger than one cell.

**Ships:** `Stamp` (`piece_id`, `origin`, `yaw`); `PresentationCatalog.FOOTPRINTS` (house 2×2 cells, deck 2×2, stair 1 cell × 1 level, ladder 1 × 1, pump house 2×2, …); `BowlDraw.draw_stamps()`. Single-cell pieces keep `piece_for_cell`.

**Lint (`test_bowl_authoring.gd`), run over every authored bowl (scripted street, cutaway fixture, terrace):**

1. **Cover honesty.** Every solid cell under a stamp has the `CoverMaterial` `cover_of(piece)` names. A house shell that says masonry over an `AIR` cell fails.
2. **No orphan cells.** Every non-`AIR` cell is under a stamp or is a single-cell prop.
3. **No overlaps.** Two stamps never claim the same cell and level.
4. **No invisible climb.** Every pair of vertically adjacent *walkable* cells has a connector stamp (stair, ladder, hatch) in that column, or is an intended swim/dive column. This is the "no walking through a ceiling" invariant (§7.1).

**Expected first failure:** `CutawayBowl` puts a roof deck at (3,1,1) directly above the street cell (3,1,0) with no connector, so lint 4 fails on it. Fix by adding a connector stamp to that fixture, not by exempting it.

**Done when:** all three bowls pass lint, and lint fails on a hand-broken map for each of the four rules.

**What landed.** `Stamp`, `FOOTPRINTS`, `BowlDraw.draw_stamps()`, `BowlAuthoring.lint`. House shells are 2×2×1 (upper storeys sparse). Connector/floor/shanty overlaps allowed with shells/decks.

---

### 3.3 — The Flooded terrace as data, and a headless fight

**Ships:** `rules/fixtures/flooded_terrace.gd` with `opening(step)`, and `tests/fights/test_flooded_terrace.gd`. Scale is a working default of about 16×10 cells.

**Shape of the bowl (data only):**

- A canal street at z = 0 (swimmable when Flooded) along the camera axis.
- One terrace run of two houses (2×2 cells each): ground floor `INTERIOR | SHELTER` at z = 0, second floor at z = 1, roof `DECK` at z = 2; one roof carries a shanty deck.
- Connectors: one stair to the first floor, one ladder to a roof.
- A levee crest with masonry cover on the far bank; a pier with the extract cells on the near edge.
- Four players (one starts on a roof), and Drifters: a rifle on the levee crest with a Watch down the canal, a pistol in an upstairs window.

**Headless assertions (the exact command list is written test-first in the slice, as 1.6 did):**

- The same squad, same cells, at Flooded vs Falling: a swimmer with no attackers reads Hidden vs No hide (exposure backstop, UI §3).
- The roof is exposed to the levee rifle across the canal and not exposed from inside the house.
- Street to roof costs exactly `swim + vertical surcharge` per level; whether one unit reaches the roof in one phase is asserted, not assumed.
- Same map at Dry and Mud: path costs and exposure words change, geometry does not.
- One authored contact plays out to a stated result, as 1.6 does.

**Done when:** the headless fight is green, and `fight_view` loads `flooded_terrace.opening()` rather than a rebuilt map (assert this like `test_shared_opening.gd`).

**What landed.** `rules/fixtures/flooded_terrace.gd`, `presentation/fixtures/flooded_terrace_stamps.gd`, `tests/fights/test_flooded_terrace.gd`. `Movement.is_walkable` allows INTERIOR masonry (room volumes).

---

### 3.4 — Draw it

**Ships:**

- Stamps drawn through `BowlDraw`; interior floors as separate nodes per level so cutaway is a visibility toggle (UI §17).
- Cutaway across three levels; the water plane visible through the ground floor; height digits on every level (UI §2).
- Connectors drawn where lint says they are. `unit_view` plays `swim` in Flooded on non-deck cells and `climb` for vertical steps (both clips exist).
- `make run BOWL=terrace`; per-bowl camera look point; the `F` key becomes a four-step cycle (Flooded → Falling → Mud → Dry).
- Per-bowl ridge placement, and a check that the ridge is actually visible from a terrace bowl (UI §2; §7.3).

**Done when:** a human can play the terrace from the canal to the roof with wall fade and cutaway working, and `make shots` has `terrace_flooded`, `terrace_falling`, `terrace_roof_cutaway`.

**What landed.** `--bowl=terrace` / `make run BOWL=terrace`; stamps drawn; per-bowl look point; `F` cycles four water steps; swim/climb clips; terrace shot setups.

**Found on screen, fixed after.** The plane sat at exactly `water_z * LEVEL_M`, coplanar with the slab tops, and Flooded's ±4 cm wave turned that into jagged slab shards. `PresentationCoords.water_surface_m(step, water_z)` added a per-step clearance; slice 3.6 replaced it with real depths. The water writes no depth and sorts first (`render_priority` −10), so path tiles, fog veils and the ring under the surface still draw. The per-tile height digits (UI §2) were cut entirely: identical zeros on a flat bowl, and they labelled Unknown cells. UI 0.10; whatever replaces them is a new mechanism, not a revival. Guards: `test_cutaway_water.gd`, and the `terrace_water_bare` shot with a pixel probe. How deep each step should *look* is still open (UI §3).

---

### 3.5 — Housekeeping from the on-screen review

- **Exposure is said twice.** The world label on the body and the bottom-left HUD line both print the word, count and sources. Decide the split and stop repeating: the word on the body, count and sources in the HUD read.
- **Broken enemies still count as guns** (Phase 2 §7.5, Phase 1 §7.8). Draw it. Do not hide it.
- **Docs.** Bump the UI/UX header when wall fade lands; add a pointer from `plans/02_…` §8 to this plan. Follow the doc convention: stable filenames, version in the header line.

**What landed.** Body label = exposure word only; HUD = seen-by count + sources (`brk` when broken). Broken attackers get a world label `broken · still a gun`. UI v0.7; plan 02 §8 points here.

---

### 3.6 — The water's depth look

**Why.** After 3.4 the water was an opaque sheet a few centimetres over the slabs. Falling read as gravel, Flooded as a flat dark sheet, and nothing told deep from chest-deep except a word. UI §3 says Falling must never look like Flooded, and UI §14 says that cannot rest on colour or motion.

**Ships.**

- `PresentationCoords.WATER_DEPTH_M`: Flooded 2.0 m (over a 1.7 m head: deep water hides a body), Falling 1.2 m (chest: it does not), Mud a film. `water_z` is now the level whose floor the water stands on; the step sets how deep. `in_water` is geometry (a floor below the surface), because `Movement` prices the step on every cell and never reads `water_z`.
- Opacity per step in `water.gdshader`: Flooded near-opaque, Falling translucent, so whether the bottom shows carries the difference.
- A **play plane**: bodies in deep water float on the surface (prone swim pose, spine at the surface; standing pose treads with head and shoulders out), and overlays and clicks use that surface. `world_play`, `play_y`, `unit_origin`, and `Picking.cell_under_ray`, which casts each open level at its own plane. The old pick reused the top plane's x/y for lower floors, which shifted a street click by the cutaway height (reproduced: aimed at (3,3,0) with every level open, it picked (0,3,0)).
- Swim clip only where the water actually is (an upstairs floor no longer swims).
- Terrace opening look point moved so the squad is in frame.

**Done when.** `make shots` has `terrace_water_bare` (Flooded: the street is gone) and `terrace_falling_bare` (the slabs show through), with probes calibrated against the regressions they guard: a zero-depth plane, and Falling drawn opaque.

**What landed.** As above. **The dock.** `env_pier` was built for water near street level (deck top 0.38 m over its origin, posts to -1.4 m), so a 2.0 m Flooded surface buried the extract place. It is now a floating dock on guide piles: `PresentationCatalog.RIDES_WATER` pieces are lifted to stay `DOCK_FREEBOARD_M` clear of the surface (as built when dry), bodies on them stand on the deck and never swim, and picking casts the deck plane. Presentation only; no rule or fixture changed. `terrace_dock` shot: the deck must read pale against the water (0.60 fixed, 0.30 submerged).

Open: the rules still price every cell as the step's water (`Movement` ignores `water_z`), so a unit on the dock or a roof in Flooded reads `hidden` while standing in plain sight, and a roof costs swim; a diegetic freeboard or waterline read is the UI §2 height read the user will invent.

---

## 4. Explicitly out of scope

- Fog peel and Known-quiet ageing (needs rooms first; comes after this)
- Table mode, dispatch, research, bands, FOBs
- Undo stack UI, commit chrome, throw/interact gizmos
- A third bowl, diagonal levees, or a two-water-surface levee map
- New art. If a piece is missing, empty + log, or one magenta marker (Phase 2 §7.4)
- Golden-image screenshot diffs
- Enemy AI as a rules module
- Any rule change to flatter a mesh. §7.1 and §7.4 are raised, not slipped in.

---

## 5. Verification

1. `make test` green, including the new lint, wall-fade and terrace fight tests. No regression in `tests/fights/test_scripted_fight.gd`.
2. `make shots` green, and provably red on the two known regressions (3.0).
3. **Authoring honesty:** lint passes on every authored bowl; the cover tag the hover names is the tag of the mesh drawn.
4. **No preview lies about height:** path cost and reach shown for a climb equal `Movement.path` on the terrace fixture (extend `test_overlay_queries.gd`).
5. **Wall fade is view-only:** grep shows nothing in `rules/` reads it; hover text and `cover_tag_at` are identical with the wall faded or not.
6. **Falling never reads as Flooded**, in words, on the terrace as well as the street (UI §3).
7. Non-colour channels intact (UI §14): faded walls keep a silhouette; exposure, long, pin, break stay as words; the water step is not colour-only.

---

## 6. Sequencing note

**3.0 first.** It is small and it guards every later slice against the class of bug this phase is most likely to produce.

**3.1 is independent of 3.2–3.4** and provable on the existing street, so it can land in parallel with 3.2.

**3.2 before 3.3.** Lint should exist before the terrace is authored, so the terrace is written against it. It will fail the cutaway fixture first (see 3.2); fix that first.

**3.3 before 3.4.** Prove the bowl headless, then draw it. If a number is wrong, the mesh is not the place to find out.

**3.5 last,** except the exposure de-duplication, which may land any time.

---

## 7. Decisions still needed

### 7.1 — What makes a vertical step legal? (raise to GDD; does not block 3.3)

`Movement._neighbors` is a plain 6-neighbour flood, and `is_walkable` only checks material. So any two vertically adjacent placed cells are a legal climb for `swim + surcharge`, whatever the art between them. The kit has `env_stair`, `env_ladder`, `env_hatch`, and `humanoid` has a `climb` clip, but no rule says a climb needs one. A path preview can therefore be honest to the rules and still walk a unit through a ceiling.

**Working default:** authoring lint (3.2 rule 4) — bowls may only stack walkable cells over a connector. No rule change.
**Raise:** if the GDD wants connectors to be a rule (a `LINK` cell flag or similar), that is a Phase-1-style slice with tests, not a view change.

### 7.2 — Wall fade: how much, and what

Working default: 25 % opacity, only pieces on the camera → friendly segment. Alternatives: fully hidden (fails UI §14's non-colour channel) or fade the whole run (hides more than it needs to). Check against a real second yaw before locking; record in UI §2.

### 7.3 — Is the ridge visible from a terrace bowl at the locked pitch?

UI §2 says the ridge orients the player and is "visible from terrace bowls". At pitch 40.7° / FOV 25° / three zoom levels, the fight street shows only a thin sliver of it at the top edge. If the terrace at rest shows none either, that is a real finding for UI §18 (options: per-bowl look point or zoom, peek reveals it, or accept it is a peek/zoom-out read). It is not a reason to add a compass or move the ridge onto the tiles.

### 7.4 — Watch before contact vs GDD §3.1 (found in review; **resolved after the phase**)

**Resolved.** The GDD wording was already right, so the rule followed it: `WatchCommand.validate` refuses with "no Watch until contact". `tests/unit/test_commands.gd` has the refusal test, the two Watch tests that assumed otherwise now set `in_contact`, and the `street_watch` shot starts contact with `Contact.begin` before it sets the Watch. Only Watch is refused. Shoot and interact start contact themselves, so they stay legal. The original finding follows.

GDD §3.1: squad mode has "no AP coin, no End Turn, no Watch". `WatchCommand.validate` does not check `in_contact`, so a Watch can be set and 3 AP spent before contact. The scripted fight only Watches after contact, but `tests/unit/test_commands.gd` builds its states with `_two_unit_fight()`, which never sets `in_contact`, and applies `WatchCommand` (and other AP commands) to them. Adding the check would therefore change those fixtures too, not just one rule. Either the rule gets the check (a Phase-1-style slice: GDD wording first, then the test fixtures set `in_contact = true`) or the GDD says why pre-contact Watch is allowed.

### 7.5 — Terrace scale

Working default ~16×10 cells. Larger is more art and more cones on screen (UI §4.4 cone soup); smaller does not exercise three levels. Revisit after 3.3 shows how the numbers play.

---

## 8. What comes after

With rooms on screen: **fog peel** and Known-quiet ageing (UI §6), then commit/confirm chrome and interact gizmos — the terrace's hatch, pump house and sluice are the first things worth interacting with, and a previewed redirection (UI §3, "mid-fight water") is the first real test of the water plane. Table mode (UI §8) stays a separate spine and can start once a bowl exists that is worth deploying to.
