extends GutTest

## Occupants seated at load; fog draws Known-quiet only (plan 04 §4.4).

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
const FogView := preload("res://presentation/fog_view.gd")
const BowlDraw := preload("res://presentation/bowl_draw.gd")


func test_terrace_occupants_are_seated_on_authored_cells() -> void:
	var state := FloodedTerrace.opening()
	var errors := Occupants.assert_seated(state)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var clan: Unit = state.get_unit(FloodedTerrace.ROOF_CLAN)
	assert_ne(clan, null, "roster seats the roof-deck occupant")
	assert_eq(clan.cell, FloodedTerrace.CLAN_CELL)
	assert_eq(clan.faction, Taxonomy.Faction.NEUTRAL)
	assert_eq(state.map.get_cell(FloodedTerrace.CLAN_CELL).occupant, FloodedTerrace.ROOF_CLAN)


func test_unknown_cells_draw_no_bowl_mesh() -> void:
	var state := FloodedTerrace.opening()
	state.knowledge.peel(state.map, state)
	var known := state.knowledge.known_cells(state)
	assert_false(known.has(FloodedTerrace.CLAN_CELL), "interior clan starts Unknown to the canal squad")
	var bowl := BowlDraw.new()
	bowl.draw_map(state.map, [], known)
	assert_false(bowl.pieces.has(FloodedTerrace.CLAN_CELL), "Unknown draws nothing")
	assert_true(bowl.pieces.has(Vector3i(2, 3, 0)), "Live start tile is drawn")
	bowl.free()


func test_fog_view_only_instances_known_quiet() -> void:
	var map := BowlMap.new()
	for x in range(0, 6):
		map.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(3, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var state := CombatState.new()
	state.map = map
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	state.knowledge.peel(map, state)
	## Walk east of the wall so the west freezes Known-quiet.
	for x in range(0, 6):
		map.set_cell(Vector3i(x, 1, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	state.get_unit(1).cell = Vector3i(5, 0, 0)
	state.knowledge.peel(map, state)
	assert_eq(state.knowledge.own_sight(1, Vector3i(0, 0, 0)), Knowledge.CellSight.KNOWN_QUIET)
	assert_eq(state.knowledge.own_sight(1, Vector3i(5, 0, 0)), Knowledge.CellSight.LIVE)

	var fog := FogView.new()
	fog.redraw(map, state)
	var quiet_n := 0
	for c in fog.get_children():
		quiet_n += 1
		var mat := (c as MeshInstance3D).material_override as ShaderMaterial
		assert_ne(mat, null, "FOG_MAT is loaded")
		assert_gt(mat.get_shader_parameter("staleness"), 0.001)
	assert_gt(quiet_n, 0, "Known-quiet cells get a veil")
	fog.free()


func test_staleness_rises_with_visits_since_seen() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var state := CombatState.new()
	state.map = map
	state.add_unit(Unit.new(1, Vector3i(0, 0, 0), Taxonomy.Faction.PLAYER))
	state.knowledge.peel(map, state)
	## Freeze as Known-quiet while still stamped visit 0.
	state.knowledge._by_unit[1][Vector3i(0, 0, 0)]["sight"] = Knowledge.CellSight.KNOWN_QUIET
	var s0 := state.knowledge.staleness_of(state, Vector3i(0, 0, 0))
	assert_gt(s0, 0.0)
	state.knowledge.visit_index = RulesConstants.STALE_FULL_AFTER_VISITS
	var s1 := state.knowledge.staleness_of(state, Vector3i(0, 0, 0))
	assert_eq(s1, 1.0)
	assert_gt(s1, s0)


func test_roof_occupant_appears_only_when_live() -> void:
	## Authored occupant is a Unit from load; fog (Live) decides whether they are known.
	var state := FloodedTerrace.opening()
	var clan: Unit = state.get_unit(FloodedTerrace.ROOF_CLAN)
	assert_ne(clan, null)
	state.knowledge.peel(state.map, state)
	assert_eq(
		state.knowledge.squad_sight(state, clan.cell),
		Knowledge.CellSight.UNKNOWN,
		"canal opening has no line into the interior"
	)
	## A squad body in that room peels it Live — reveal is vision, not knock/spawn.
	var seer := state.get_unit(FloodedTerrace.P1)
	seer.cell = clan.cell
	state.knowledge.peel(state.map, state)
	assert_eq(state.knowledge.squad_sight(state, clan.cell), Knowledge.CellSight.LIVE)
