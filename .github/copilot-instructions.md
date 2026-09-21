# Project Polder agent instructions

Single source for Claude Code (`CLAUDE.md`), `AGENTS.md` tools and Copilot. Edit
`.github/copilot-instructions.md`; the other two are symlinks to it.

## Local workflow

- This is a Godot **4.7.2** project (`.godot-version`) using GDScript and the
  Forward+ renderer. `make check-godot` verifies the default
  `$HOME/bin/godot`; override it with `GODOT=/path/to/godot`.
- Use the Makefile targets from the repository root:

  ```bash
  make editor
  make run
  make import
  make test
  make build
  ```

  `make build` exports the Linux x86_64 release to
  `build/linux/project_polder.x86_64`.
- Tests use the vendored GUT 9.7.1 runner. Run one test file with
  `make test ARGS="-gselect=test_scripted_fight.gd"` and one test by name with
  `make test ARGS="-gselect=test_scripted_fight.gd -gunit_test_name=test_the_scripted_fight"`.
  `scripts/test.sh` deliberately fails when GUT reports load errors or an
  empty selection, even if GUT itself exits successfully.

## Architecture

- `scenes/main.tscn` starts `presentation/fight_view.gd`, which programmatically
  composes the P0 tactical scene, HUD, camera, meshes, water, and overlays.
- `rules/` is the deterministic tactical domain. `BowlMap` is sparse,
  read-only authored grid data; `CombatState` owns mutable fight state and
  copies units for every evolved state. Units' live positions belong in
  `CombatState.units`, never in `Cell.occupant`, which is authored map data.
- Model player actions as subclasses of `rules/commands/command.gd`.
  `validate(state)` must not mutate and returns `CommandResult`; `apply(state)`
  validates, evolves a duplicate state, starts contact when appropriate, and
  resolves break effects. Do not mutate an input state or its shared map.
- Query rules directly from the shared data model: `Los`, `Movement`, `Cones`,
  `Contact`, `ExposureQuery`, and `BreakRule`. LOS is a grid calculation, not
  a physics raycast; exposure is LOS evaluated from hostile units.
- `presentation/` draws state and applies already-validated commands; it decides
  nothing. `fight_view.gd` does `validate()` then `apply()`. For fight overlays, use
  `presentation/overlay_queries.gd`, which delegates to `rules/`; do not add a
  presentation-specific implementation of LOS, paths, cone volumes, exposure,
  AP pricing, or shot outcomes.
- `rules/fixtures/scripted_fight.gd` is the shared opening state for both
  `fight_view.gd` and the end-to-end fight test. Keep the fixture as state
  construction only; keep its action sequence and assertions in
  `tests/fights/test_scripted_fight.gd`.

## Project conventions

- The GDD owns mechanics; `docs/UI_UX_Document.md` owns their presentation.
  When adding or changing a deterministic rule, keep the rule, preview, and
  tests aligned. Previews show capabilities and outcomes before commitment,
  rather than intent or probabilities.
- Preserve state isolation. `CombatState.duplicate_state()` intentionally
  shares the read-only `BowlMap` while duplicating units and watches. Command
  results must be independently branchable; cover this with targeted
  `tests/unit/test_state_isolation.gd` coverage when changing state behavior.
- Paths must use `Movement.path`/`Movement.reachable`, and presentation
  previews must use the resulting per-cell costs, exposure, watch crossings,
  and reserve marks. Do not duplicate pathfinding for UI behavior.
- Live Watch reactions resolve one grid step at a time. The Watch is spent when
  a hostile steps into its cone from outside it, and one Watch fires one shot.
  Keep command processing ordered and deterministic.
- Test organization reflects the behavior under test: pure rules in
  `tests/unit/`, cross-rule guarantees in `tests/invariants/`, rendering and
  overlay contracts in `tests/presentation/`, and the shared end-to-end
  opening in `tests/fights/`.
- Asset paths are part of the production contract. Add assets beneath the
  existing `assets/` categories using lowercase `kind_kit_piece_variant`
  names; do not create parallel asset trees or placeholder meshes. The one
  sanctioned placeholder is the magenta marker `bowl_draw.gd` draws for a cell
  with no kit piece.
- Cover tags are asserted, not assumed: `PresentationCatalog.cover_of` must stay
  in lockstep with the `assets/*/MANIFEST.md` cover tables and with
  `tests/presentation/test_catalog_bowl.gd`.

## Docs and plans

- Docs in `docs/` keep one stable filename. The version lives in the
  `**Version:**` header line; bump that line, never rename the file. Precedence
  on conflict: GDD (rules) > UI/UX (how a rule is drawn) > assets doc.
- A UI idea that needs a new rule is raised to the GDD, never shipped as "just
  UI". If a preview and a rule function disagree, the rule wins and the preview
  is the bug (UI §1).
- Implementation work is planned in `plans/NN_*.md`, in slices with a
  Status, "Ships", and "Done when". Read the current plan and its "Decisions
  still needed" before starting a slice. When one lands, update its status and
  "What landed" in the same commit; recent commits are titled `Complete 2.6: ...`.

## Gotchas

- **Headless tests cannot see rendering bugs.** A shader that fails to compile
  or a HUD element that never updates passes `make test`. For visual changes,
  capture a frame (`make shots` for the regression setups; `scripts/shots.sh`
  with `--do=...` for one state, see `.claude/skills/screenshot/SKILL.md`); do
  not treat a green suite as proof of what is on screen.
- **Shader comments are `//` and `/* */`.** `##` is GDScript; in a shader it is
  a preprocessor token and the whole shader fails to compile, so the material
  silently falls back to an opaque default.
- **In a `canvas_item` shader, `COLOR` already holds texture x the node's
  `modulate`.** Assigning `COLOR = texture(...)` drops `modulate` (the HUD dims
  spent pips with it); change `COLOR.a` or multiply, do not overwrite.
- **The water plane must never be coplanar with the slab tops.** They fight per pixel and
  the Flooded wave turns it into shards. Draw it at `PresentationCoords.water_surface_m`, not
  `water_height_m`. It writes no depth and sorts first so ground overlays stay visible.
- **Fixtures and query helpers are preloaded, not `class_name`d**
  (`rules/fixtures/scripted_fight.gd`, `presentation/overlay_queries.gd`), so
  headless tests do not depend on a global-class cache refresh. Follow that for
  new ones.
- `.gd.uid` files are tracked. `make test` does not create them; run
  `make import` after adding a script and commit the `.uid` next to it.
- `fight_view.gd`'s `F` key cycles `map.water_step` on the shared `BowlMap`
  through Flooded → Falling → Mud → Dry. That is a debug toggle and the one
  sanctioned exception to "the map is read-only"; commands must never do it.
  `make run BOWL=terrace` passes `--bowl=terrace` for the flooded terrace.

