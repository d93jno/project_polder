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


func test_terrace_passes_authoring_lint() -> void:
	var failures := BowlAuthoring.lint(
		FloodedTerrace.map(), TerraceStamps.stamps(), TerraceStamps.swim_columns()
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


func test_street_to_roof_costs_swim_plus_surcharge_per_level() -> void:
	var s := FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	s.units.erase(P4) ## destination must be empty
	var u: Unit = s.get_unit(P1)
	u.cell = Vector3i(4, 4, 0) ## canal tile south of the stair column
	var path := Movement.path(s.map, s, u, FloodedTerrace.ROOF_A)
	assert_true(path.reachable)
	var swim := RulesConstants.MOVE_COST_SWIM
	var surcharge := RulesConstants.MOVE_COST_VERTICAL_SURCHARGE
	## (4,4,0)→(4,5,0) swim; then two vertical steps at swim+surcharge each.
	assert_eq(path.total_cost, swim + 2 * (swim + surcharge))
	assert_gt(path.total_cost, RulesConstants.AP_POOL, "roof is not a one-phase swim from the street")


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
	assert_eq(p_m.total_cost, RulesConstants.MOVE_COST_MUD + 2 * (RulesConstants.MOVE_COST_MUD + RulesConstants.MOVE_COST_VERTICAL_SURCHARGE))
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
