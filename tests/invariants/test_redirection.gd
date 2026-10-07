extends GutTest

## Water the state owns (plan 06 §6.1): a command can change the water the rules read without writing
## a map another state is still reading, and every rule and the picture agree on the result.

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")

const STREET := Vector3i(3, 3, 0)
const ROOF := Vector3i(4, 5, 2)


func _fight(step: Taxonomy.WaterStep) -> CombatState:
	var state := FloodedTerrace.opening(step)
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
	return state


func test_with_water_shares_the_cells_and_owns_the_water() -> void:
	var map := FloodedTerrace.map(Taxonomy.WaterStep.FALLING)
	var wetter := map.with_water(Taxonomy.WaterStep.FLOODED, 1)
	assert_same(wetter.cells, map.cells, "one cell store")
	assert_eq(wetter.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(wetter.water_z, 1)
	assert_eq(map.water_step, Taxonomy.WaterStep.FALLING, "the original map is untouched")
	assert_eq(map.water_z, 0)


func test_a_redirection_leaves_the_state_it_came_from_alone() -> void:
	var before := _fight(Taxonomy.WaterStep.FALLING)
	var after := before.duplicate_state()
	assert_same(after.map, before.map, "a copy shares the map until water changes")
	after.redirect_water(Taxonomy.WaterStep.FLOODED, before.map.water_z)
	assert_not_same(after.map, before.map, "the redirected state owns a new map")
	assert_eq(before.map.water_step, Taxonomy.WaterStep.FALLING)
	assert_eq(after.map.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(before.map.step_at(STREET), Taxonomy.WaterStep.FALLING)
	assert_eq(after.map.step_at(STREET), Taxonomy.WaterStep.FLOODED)


func test_movement_prices_each_states_own_water() -> void:
	var before := _fight(Taxonomy.WaterStep.FALLING)
	var after := before.duplicate_state()
	after.redirect_water(Taxonomy.WaterStep.FLOODED, before.map.water_z)
	var unit: Unit = before.get_unit(FloodedTerrace.P1)
	assert_eq(
		Movement.move_cost(before.map, STREET, unit),
		RulesConstants.step_move_cost(Taxonomy.WaterStep.FALLING),
	)
	assert_eq(
		Movement.move_cost(after.map, STREET, after.get_unit(FloodedTerrace.P1)),
		RulesConstants.step_move_cost(Taxonomy.WaterStep.FLOODED),
	)


func test_dry_ground_above_the_water_stays_dry_after_a_redirection() -> void:
	var state := _fight(Taxonomy.WaterStep.FALLING)
	state.redirect_water(Taxonomy.WaterStep.FLOODED, state.map.water_z)
	assert_eq(state.map.step_at(ROOF), Taxonomy.WaterStep.DRY, "GDD 5.8: a roof is dry at every step")
	assert_false(state.map.is_wet(ROOF))


func test_the_picture_still_agrees_with_the_rules_after_a_redirection() -> void:
	var state := _fight(Taxonomy.WaterStep.FALLING)
	state.redirect_water(Taxonomy.WaterStep.FLOODED, state.map.water_z)
	var map := state.map
	for coord in map.cells.keys():
		if (map.get_cell(coord) as Cell).has_flag(Taxonomy.CellFlags.DECK):
			continue
		assert_eq(
			PresentationCoords.in_water(coord, map.water_step, map.water_z), map.is_wet(coord),
			"%s after a redirection" % coord
		)


func test_a_redirection_is_independently_branchable() -> void:
	var root := _fight(Taxonomy.WaterStep.FALLING)
	var a := root.duplicate_state()
	var b := root.duplicate_state()
	a.redirect_water(Taxonomy.WaterStep.FLOODED, root.map.water_z)
	b.redirect_water(Taxonomy.WaterStep.MUD, root.map.water_z)
	assert_eq(a.map.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(b.map.water_step, Taxonomy.WaterStep.MUD)
	assert_eq(root.map.water_step, Taxonomy.WaterStep.FALLING)


func test_only_the_debug_toggle_writes_the_water_of_a_shared_map() -> void:
	## CLAUDE.md: the F toggle is the one sanctioned exception to "the map is read-only". A command
	## changes water through `with_water`, never by assigning to a map. `rules/fixtures` build maps.
	var writers: Array[String] = []
	for dir in ["res://rules", "res://presentation"]:
		_scan(dir, writers)
	assert_eq(
		writers, ["res://presentation/fight_view.gd"] as Array[String],
		"files that assign map.water_step or map.water_z: only the F debug toggle"
	)


func _scan(dir_path: String, writers: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub == "fixtures":
			continue
		_scan(dir_path.path_join(sub), writers)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var path := dir_path.path_join(file)
		if path == "res://rules/bowl_map.gd":
			continue
		var text := FileAccess.get_file_as_string(path)
		for line in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			if _assigns_map_water(code):
				writers.append(path)
				break


func _assigns_map_water(code: String) -> bool:
	for field in ["map.water_step", "map.water_z"]:
		var at := code.find(field)
		if at == -1:
			continue
		var rest := code.substr(at + field.length()).strip_edges()
		if rest.begins_with("=") and not rest.begins_with("=="):
			return true
	return false
