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
	assert_eq(map.water_z, 0, "the water stands on the street")
	assert_true(map.has_cell(Cutaway.STREET))
	assert_true(map.has_cell(Cutaway.ROOF))
	assert_eq(map.get_cell(Cutaway.ROOF).flags & Taxonomy.CellFlags.DECK, Taxonomy.CellFlags.DECK)
	var flooded := PresentationCoords.water_surface_m(Taxonomy.WaterStep.FLOODED, map.water_z)
	assert_lt(flooded, PresentationCoords.LEVEL_M, "the roof stands clear of the Flooded surface")
	assert_true(PresentationCoords.in_water(Cutaway.STREET, Taxonomy.WaterStep.FLOODED, map.water_z))
	assert_false(PresentationCoords.in_water(Cutaway.ROOF, Taxonomy.WaterStep.FLOODED, map.water_z))


func test_falling_fixture_is_no_hide() -> void:
	var state: CombatState = Cutaway.falling_opening()
	assert_eq(state.map.water_step, Taxonomy.WaterStep.FALLING)
	state.units.erase(10)
	state.units.erase(11)
	state.watches.clear()
	var roof: Unit = state.get_unit(2)
	var exp := ExposureQuery.exposure(state.map, state, roof)
	assert_eq(exp.state, Exposure.State.NO_HIDE)


func test_flooded_fixture_can_hide_without_attackers() -> void:
	var state: CombatState = Cutaway.opening(Taxonomy.WaterStep.FLOODED)
	## Remove hostiles so exposure is not EXPOSED.
	state.units.erase(10)
	state.units.erase(11)
	state.watches.clear()
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


## The depth classes are the rules' own (GDD 5.4): deep water hides a body, chest-deep does not.
## The drawn surface has to say the same thing, so the numbers are checked against a body.
func test_flooded_surface_is_over_a_head_and_falling_is_chest_deep() -> void:
	var body_m := 1.7 ## the shared humanoid
	var flooded: float = PresentationCoords.WATER_DEPTH_M[Taxonomy.WaterStep.FLOODED]
	var falling: float = PresentationCoords.WATER_DEPTH_M[Taxonomy.WaterStep.FALLING]
	assert_gt(flooded, body_m, "deep water covers a standing body: that is what hides it")
	assert_gt(falling, body_m * 0.55, "chest-deep is above the waist")
	assert_lt(falling, body_m * 0.85, "and below the shoulders: a body still shows, so no swim-hide")


func test_water_surface_is_higher_the_wetter_the_step() -> void:
	var y := func(s): return PresentationCoords.water_surface_m(s, 0)
	assert_gt(y.call(Taxonomy.WaterStep.FLOODED), y.call(Taxonomy.WaterStep.FALLING))
	assert_gt(y.call(Taxonomy.WaterStep.FALLING), y.call(Taxonomy.WaterStep.MUD))
	assert_gt(y.call(Taxonomy.WaterStep.MUD), PresentationCoords.water_height_m(0), "a film clears the slab")


## Height is geometry: the rules apply a step's cost to every cell and never read water_z, so
## "is this cell under the drawn water" is answered from the floor and the surface.
func test_a_cell_is_in_water_when_its_floor_is_below_the_surface() -> void:
	var street := Vector3i(3, 3, 0)
	var first_floor := Vector3i(4, 5, 1) ## floor at 3 m, surface at 2 m: 1 m of freeboard
	var flooded := Taxonomy.WaterStep.FLOODED
	assert_true(PresentationCoords.in_water(street, flooded, 0))
	assert_true(PresentationCoords.in_water(street, Taxonomy.WaterStep.FALLING, 0))
	assert_false(PresentationCoords.in_water(first_floor, flooded, 0), "the first floor clears the flood")
	assert_false(PresentationCoords.in_water(street, Taxonomy.WaterStep.MUD, 0), "mud is a film, not water")
	assert_false(PresentationCoords.in_water(street, Taxonomy.WaterStep.DRY, 0))


func test_only_flooded_bodies_float() -> void:
	var street := Vector3i(3, 3, 0)
	assert_true(PresentationCoords.floats(street, Taxonomy.WaterStep.FLOODED, 0), "swimming")
	assert_false(PresentationCoords.floats(street, Taxonomy.WaterStep.FALLING, 0), "wading: feet on the bottom")
	assert_false(PresentationCoords.floats(Vector3i(4, 5, 1), Taxonomy.WaterStep.FLOODED, 0), "upstairs is dry")


func test_the_play_surface_is_the_water_for_floating_cells_and_the_floor_otherwise() -> void:
	var flooded := Taxonomy.WaterStep.FLOODED
	var surface := PresentationCoords.water_surface_m(flooded, 0)
	assert_eq(PresentationCoords.play_y(0, flooded, 0), surface, "overlays and clicks use the surface")
	assert_eq(PresentationCoords.play_y(1, flooded, 0), PresentationCoords.LEVEL_M, "a dry floor is itself")
	assert_eq(PresentationCoords.play_y(0, Taxonomy.WaterStep.FALLING, 0), 0.0, "wading: the bottom")
	## A treading (standing) body shows head and shoulders; a prone swimmer's spine rides the surface.
	## The swim clip's bones measure 0.57 to 1.06 m above the unit origin (plan 3.6).
	var tread := PresentationCoords.unit_origin(Vector3i(3, 3, 0), flooded, 0)
	assert_almost_eq(tread.y, surface - PresentationCoords.TREAD_DRAFT_M + 0.02, 0.001)
	assert_gt(PresentationCoords.TREAD_DRAFT_M, 1.0, "most of a standing body is under")
	assert_lt(PresentationCoords.TREAD_DRAFT_M, 1.6, "and the head and shoulders are not")
	var swimmer := PresentationCoords.unit_origin(Vector3i(3, 3, 0), flooded, 0, true)
	assert_almost_eq(swimmer.y, surface - PresentationCoords.SWIM_DRAFT_M + 0.02, 0.001)
	assert_gt(PresentationCoords.SWIM_DRAFT_M, 0.57, "the spine is not above the bones' lowest point")
	assert_lt(PresentationCoords.SWIM_DRAFT_M, 1.06, "so the back and head show, the belly does not")
	var waded := PresentationCoords.unit_origin(Vector3i(3, 3, 0), Taxonomy.WaterStep.FALLING, 0)
	assert_eq(waded, PresentationCoords.world_ground(Vector3i(3, 3, 0)))


func test_water_draws_first_and_writes_no_depth() -> void:
	## Overlays sit a few cm above the slabs, under the surface. The water must not cull them.
	var mat := load(PresentationCatalog.WATER_MAT) as ShaderMaterial
	assert_lt(mat.render_priority, 0, "water sorts before other transparents")
	assert_true(mat.shader.code.contains("depth_draw_never"), "water writes no depth")
