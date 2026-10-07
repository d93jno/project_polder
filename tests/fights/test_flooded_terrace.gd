extends GutTest

## Plan 3.3 — Flooded terrace as data, headless. View loads the same opening (3.4).

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
const TerraceStamps := preload("res://presentation/fixtures/flooded_terrace_stamps.gd")

const P1 := FloodedTerrace.P1
const P2 := FloodedTerrace.P2
const P3 := FloodedTerrace.P3
const P4 := FloodedTerrace.P4
const D_RIFLE := FloodedTerrace.D_RIFLE
const D_PISTOL := FloodedTerrace.D_PISTOL


func _do(state: CombatState, cmd: Command) -> CombatState:
	var check := cmd.validate(state)
	assert_true(check.ok, "illegal command: %s" % check.reason)
	return cmd.apply(state)


func test_terrace_footprint_is_20_by_14_and_every_ground_cell_is_placed() -> void:
	var map := FloodedTerrace.map()
	for x in FloodedTerrace.WIDTH:
		for y in FloodedTerrace.DEPTH:
			assert_true(map.has_cell(Vector3i(x, y, 0)), "ground cell (%d, %d)" % [x, y])
	assert_eq(FloodedTerrace.WIDTH, 20)
	assert_eq(FloodedTerrace.DEPTH, 14)
	assert_false(map.has_cell(Vector3i(FloodedTerrace.WIDTH, 0, 0)))
	assert_false(map.has_cell(Vector3i(0, FloodedTerrace.DEPTH, 0)))


func test_terrace_passes_authoring_lint() -> void:
	var failures := BowlAuthoring.lint(
		FloodedTerrace.map(), TerraceStamps.stamps(), TerraceStamps.swim_columns(),
		FloodedTerrace.machines()
	)
	assert_eq(failures, PackedStringArray(), "\n".join(failures))


func test_flooded_vs_falling_exposure_backstop() -> void:
	## Same cell, no attackers: Flooded → Hidden, Falling → No hide (UI §3).
	var flooded := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	var falling := FloodedTerrace.opening(Taxonomy.WaterStep.FALLING)
	## Clear hostiles so the water-step word is the only signal.
	flooded.units.erase(D_RIFLE)
	flooded.units.erase(D_PISTOL)
	flooded.watches.clear()
	falling.units.erase(D_RIFLE)
	falling.units.erase(D_PISTOL)
	falling.watches.clear()
	var u_f: Unit = flooded.get_unit(P1)
	var u_a: Unit = falling.get_unit(P1)
	assert_eq(u_f.cell, u_a.cell)
	assert_eq(flooded.attackers_of(flooded.map, u_f).size(), 0)
	assert_eq(falling.attackers_of(falling.map, u_a).size(), 0)
	assert_eq(ExposureQuery.exposure(flooded.map, flooded, u_f).state, Exposure.State.HIDDEN)
	assert_eq(ExposureQuery.exposure(falling.map, falling, u_a).state, Exposure.State.NO_HIDE)


func test_roof_exposed_to_levee_rifle_interior_not() -> void:
	var s := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	var roof: Unit = s.get_unit(P4)
	var inside := Unit.new(99, FloodedTerrace.INSIDE_A, Taxonomy.Faction.PLAYER)
	s.add_unit(inside)
	assert_gt(s.attackers_of(s.map, roof).size(), 0, "roof sees the levee rifle")
	var rifle_on_roof := false
	for a in s.attackers_of(s.map, roof):
		if a.id == D_RIFLE:
			rifle_on_roof = true
	assert_true(rifle_on_roof)
	assert_eq(s.attackers_of(s.map, inside).size(), 0, "masonry volume hides the ground floor")


func test_street_to_roof_is_a_swim_then_dry_climbs() -> void:
	var s := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	s.units.erase(P4) ## destination must be empty
	var u: Unit = s.get_unit(P1)
	u.cell = Vector3i(4, 4, 0) ## canal tile south of the stair column
	var path := Movement.path(s.map, s, u, FloodedTerrace.ROOF_A)
	assert_true(path.reachable)
	var swim := RulesConstants.MOVE_COST_SWIM
	var dry := RulesConstants.MOVE_COST_DRY
	var surcharge := RulesConstants.MOVE_COST_VERTICAL_SURCHARGE
	## (4,4,0)→(4,5,0) is wet, so a swim; the two vertical steps land on dry ground above the water
	## (GDD 5.8), so each is the dry cost plus the surcharge, not another swim.
	assert_eq(path.total_cost, swim + 2 * (dry + surcharge))
	## Asserted, not assumed: the roof is reachable in one phase, but for the whole pool. Whoever
	## climbs has nothing left to shoot or Watch with.
	assert_eq(path.total_cost, RulesConstants.AP_POOL, "one phase, all of it")


func test_dry_and_mud_change_cost_not_geometry() -> void:
	var flooded := FloodedTerrace.map(Taxonomy.WaterStep.FLOODED)
	var dry := FloodedTerrace.map(Taxonomy.WaterStep.DRY)
	var mud := FloodedTerrace.map(Taxonomy.WaterStep.MUD)
	assert_eq(dry.cells.size(), flooded.cells.size())
	assert_eq(mud.cells.size(), flooded.cells.size())
	for coord in flooded.cells.keys():
		assert_true(dry.has_cell(coord))
		assert_eq(dry.get_cell(coord).material, flooded.get_cell(coord).material)
		assert_eq(dry.get_cell(coord).flags, flooded.get_cell(coord).flags)
	var s_f := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	var s_d := FloodedTerrace.opening(Taxonomy.WaterStep.DRY)
	var s_m := FloodedTerrace.opening(Taxonomy.WaterStep.MUD)
	for st in [s_f, s_d, s_m]:
		st.units.erase(P4)
		st.get_unit(P1).cell = Vector3i(4, 4, 0)
	var p_f := Movement.path(s_f.map, s_f, s_f.get_unit(P1), FloodedTerrace.ROOF_A)
	var p_d := Movement.path(s_d.map, s_d, s_d.get_unit(P1), FloodedTerrace.ROOF_A)
	var p_m := Movement.path(s_m.map, s_m, s_m.get_unit(P1), FloodedTerrace.ROOF_A)
	assert_true(p_f.reachable)
	assert_eq(p_f.cells, p_d.cells)
	assert_eq(p_f.cells, p_m.cells)
	assert_eq(p_d.total_cost, RulesConstants.MOVE_COST_DRY + 2 * (RulesConstants.MOVE_COST_DRY + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE))
	assert_eq(p_m.total_cost, RulesConstants.MOVE_COST_MUD + 2 * (RulesConstants.MOVE_COST_DRY + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE), "mud is on the ground; the climb is above it")
	assert_ne(p_f.total_cost, p_d.total_cost)


func test_the_terrace_contact() -> void:
	## Roof recruit is already in the rifle's line — contact on the opening's first free move
	## that a canal body takes into view, then the rifle drops the roof body; extract via pier.
	var s := FloodedTerrace.opening(Taxonomy.WaterStep.DRY)
	## Dry so moves are cheap enough to reach the pier in-phase after the exchange.
	assert_false(s.in_contact)
	## P4 on the roof is already geometrically exposed; walking P1 along the canal into the
	## Watch cone starts phases (hostile line on a squad body the crest can see).
	assert_true(Contact.sees_out(s.map, s.get_unit(D_RIFLE)))
	assert_gt(s.attackers_of(s.map, s.get_unit(P4)).size(), 0)
	s = _do(s, FreeMoveCommand.new(P1, Vector3i(5, 3, 0)))
	assert_true(s.in_contact, "crest rifle has a line on the roof body once phases can start")
	## Player phase: dig in; enemy phase: rifle drops the roof recruit.
	s = s.end_phase()
	s = _do(s, ShootCommand.new(D_RIFLE, P4))
	assert_true(s.get_unit(P4).bleeding, "rifle drops in one hit")
	s = s.end_phase()
	## Remaining squad peels to the pier and extracts.
	s = _do(s, MoveCommand.new(P1, Vector3i(3, 0, 0)))
	s = _do(s, MoveCommand.new(P2, Vector3i(2, 0, 0)))
	s = _do(s, MoveCommand.new(P3, Vector3i(1, 0, 0)))
	for id in [P1, P2, P3]:
		s = _do(s, ExtractCommand.new(id))
		assert_true(s.get_unit(id).extracted)
	assert_true(s.get_unit(P4).bleeding and not s.get_unit(P4).extracted)
	assert_true(s.get_unit(D_PISTOL).is_active(), "upstairs pistol never saw out")


## --- Machines (plan 06 §6.5) ---


func _phases(step: Taxonomy.WaterStep) -> CombatState:
	var state := FloodedTerrace.opening(step)
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	state.knowledge.peel(state.map, state)
	return state


func test_the_terrace_authors_a_hatch_a_pump_and_a_sluice() -> void:
	var state := FloodedTerrace.opening()
	assert_eq(state.machines.size(), 3)
	assert_eq(state.machine_at(FloodedTerrace.HATCH).kind, Machine.Kind.HATCH)
	assert_true(state.machine_at(FloodedTerrace.HATCH).on, "open at the start, so the climb is as it was")
	assert_eq(state.machine_at(FloodedTerrace.PUMP).kind, Machine.Kind.PUMP)
	assert_eq(state.machine_at(FloodedTerrace.SLUICE).kind, Machine.Kind.SLUICE)
	assert_false(state.machine_at(FloodedTerrace.SLUICE).on)


func test_the_roof_is_still_reached_through_the_hatch() -> void:
	var state := _phases(Taxonomy.WaterStep.FALLING)
	var climber: Unit = state.get_unit(P4)
	climber.cell = Vector3i(4, 5, 0) ## the stair column, ground floor
	var up := Movement.path(state.map, state, climber, FloodedTerrace.ROOF_A)
	assert_true(up.reachable, "stair, then the open hatch")


func test_closing_the_hatch_from_the_roof_denies_the_climb_and_opening_it_restores_it() -> void:
	var state := _phases(Taxonomy.WaterStep.FALLING)
	var roof: Unit = state.get_unit(P4)
	assert_eq(roof.cell, FloodedTerrace.ROOF_A)
	var closed := _do(state, MachineCommand.new(P4, FloodedTerrace.HATCH, false))
	assert_false(closed.machine_at(FloodedTerrace.HATCH).on)
	var down := Movement.path(closed.map, closed, closed.get_unit(P4), Vector3i(4, 5, 1))
	assert_false(down.reachable, "a closed hatch holds the roof")
	closed.get_unit(P4).ap = RulesConstants.AP_POOL
	var reopened := _do(closed, MachineCommand.new(P4, FloodedTerrace.HATCH, true))
	assert_true(
		Movement.path(reopened.map, reopened, reopened.get_unit(P4), Vector3i(4, 5, 1)).reachable,
		"opened again, the way down is back"
	)


func test_opening_the_sluice_turns_a_canal_where_nothing_hides_into_deep_water() -> void:
	var state := _phases(Taxonomy.WaterStep.FALLING)
	var canal := FloodedTerrace.CANAL
	var cost_before := Movement.move_cost(state.map, canal, state.get_unit(P1))
	var hide_before := ExposureQuery.exposure(state.map, state, state.get_unit(P1)).state
	assert_eq(hide_before, Exposure.State.NO_HIDE, "chest-deep Falling water hides no one (GDD 5.4)")
	state = _do(state, MoveCommand.new(P2, FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)))
	assert_eq(state.get_unit(P2).cell, FloodedTerrace.SLUICE + Vector3i(-1, 0, 0))
	var open := MachineCommand.new(P2, FloodedTerrace.SLUICE)
	assert_true(open.needs_confirm(state), "the one Confirmed action on the terrace")
	var after := _do(state, open)
	assert_true(after.machine_at(FloodedTerrace.SLUICE).on)
	assert_eq(after.map.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(state.map.water_step, Taxonomy.WaterStep.FALLING, "the branch before it keeps its water")
	var cost_after := Movement.move_cost(after.map, canal, after.get_unit(P1))
	var hide_after := ExposureQuery.exposure(after.map, after, after.get_unit(P1)).state
	assert_ne(hide_after, Exposure.State.NO_HIDE, "deep water now hides a body on the canal")
	assert_eq(cost_before, RulesConstants.step_move_cost(Taxonomy.WaterStep.FALLING))
	assert_eq(cost_after, RulesConstants.step_move_cost(Taxonomy.WaterStep.FLOODED))
	assert_eq(after.map.step_at(FloodedTerrace.ROOF_A), Taxonomy.WaterStep.DRY, "a roof stays dry (GDD 5.8)")
	assert_eq(after.map.step_at(FloodedTerrace.ROOF_B), Taxonomy.WaterStep.DRY)
	assert_eq(
		Movement.move_cost(after.map, FloodedTerrace.ROOF_A, after.get_unit(P4)),
		RulesConstants.step_move_cost(Taxonomy.WaterStep.DRY),
	)


func test_the_sluice_is_refused_on_the_default_flooded_terrace() -> void:
	var state := _phases(Taxonomy.WaterStep.FLOODED)
	state.get_unit(P2).cell = FloodedTerrace.SLUICE + Vector3i(-1, 0, 0)
	var check := MachineCommand.new(P2, FloodedTerrace.SLUICE).validate(state)
	assert_false(check.ok)
	assert_eq(check.reason, "the water is already as deep as it goes")


func test_a_pump_can_be_started_and_changes_no_water() -> void:
	var state := _phases(Taxonomy.WaterStep.FALLING)
	state.get_unit(P3).cell = FloodedTerrace.PUMP + Vector3i(-1, 0, 0)
	var next := _do(state, MachineCommand.new(P3, FloodedTerrace.PUMP))
	assert_true(next.machine_at(FloodedTerrace.PUMP).on)
	assert_eq(next.map.water_step, Taxonomy.WaterStep.FALLING)
	assert_same(next.map, state.map, "a pump leaves the shared map alone (plan 06 §7.4)")
