extends GutTest

## Plan 2.2: water height from water_z, deck pieces, cutaway fixture, Falling word.


const Cutaway := preload("res://presentation/fixtures/cutaway_bowl.gd")


func test_water_height_is_level_times_water_z() -> void:
	assert_eq(PresentationCoords.water_height_m(0), 0.0)
	assert_eq(PresentationCoords.water_height_m(1), PresentationCoords.LEVEL_M)
	assert_eq(PresentationCoords.water_height_m(2), PresentationCoords.LEVEL_M * 2.0)


func test_deck_flag_picks_roof_mesh() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(0, 0, 1))
	assert_eq(choice.id, PresentationCatalog.ROOF_DECK_ID)
	assert_eq(PresentationCatalog.cover_of(choice.id), -1)


func test_cutaway_fixture_has_street_and_roof() -> void:
	var map := Cutaway.map()
	assert_eq(map.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(map.water_z, 1)
	assert_true(map.has_cell(Cutaway.STREET))
	assert_true(map.has_cell(Cutaway.ROOF))
	assert_eq(map.get_cell(Cutaway.ROOF).flags & Taxonomy.CellFlags.DECK, Taxonomy.CellFlags.DECK)
	assert_eq(PresentationCoords.water_height_m(map.water_z), PresentationCoords.LEVEL_M)


func test_falling_fixture_is_no_hide() -> void:
	var state: CombatState = Cutaway.falling_opening()
	assert_eq(state.map.water_step, Taxonomy.WaterStep.FALLING)
	state.units.erase(10)
	var roof: Unit = state.get_unit(2)
	var exp := ExposureQuery.exposure(state.map, state, roof)
	assert_eq(exp.state, Exposure.State.NO_HIDE)


func test_flooded_fixture_can_hide_without_attackers() -> void:
	var state: CombatState = Cutaway.opening(Taxonomy.WaterStep.FLOODED)
	## Remove the hostile so exposure is not EXPOSED.
	state.units.erase(10)
	var street: Unit = state.get_unit(1)
	var exp := ExposureQuery.exposure(state.map, state, street)
	assert_eq(exp.state, Exposure.State.HIDDEN)


func test_bowl_cutaway_hides_higher_floor_nodes() -> void:
	var BowlDraw = load("res://presentation/bowl_draw.gd")
	var bowl = BowlDraw.new()
	add_child_autofree(bowl)
	var map := Cutaway.map()
	bowl.draw_map(map)
	assert_eq(bowl.cutaway_z, 1)
	bowl.set_cutaway_z(0)
	var roof_visible := false
	var street_visible := false
	for n in bowl.get_children():
		var z: int = n.get_meta("polder_z", -1)
		if z == 1:
			roof_visible = roof_visible or n.visible
		elif z == 0:
			street_visible = street_visible or n.visible
	assert_false(roof_visible, "cutaway 0 hides roof deck meshes")
	assert_true(street_visible, "street stays visible")
