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


## The z-fight: a plane at exactly `water_z * LEVEL_M` is coplanar with the slab tops
## (kit MANIFEST: slab top is local Y = 0), so the two fight per pixel and the flooded wave
## turns it into shards. Headless cannot see the pixels; it can see the geometry that caused them.
func test_water_surface_clears_slab_tops_by_more_than_the_wave() -> void:
	var mat := load(PresentationCatalog.WATER_MAT) as ShaderMaterial
	var flooded_wave_m := float(mat.get_shader_parameter("flood_wave_cm")) * 0.01
	for step in [Taxonomy.WaterStep.FLOODED, Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.MUD]:
		var lift := PresentationCoords.water_surface_m(step, 0) - PresentationCoords.water_height_m(0)
		assert_gt(lift, 0.0, "%s plane sits above the slab tops" % Taxonomy.WaterStep.keys()[step])
	var flooded := PresentationCoords.water_surface_m(Taxonomy.WaterStep.FLOODED, 0)
	assert_gt(flooded, flooded_wave_m * 2.0, "Flooded clears the ±wave with margin, crests and troughs")


func test_water_surface_is_higher_the_wetter_the_step() -> void:
	var y := func(s): return PresentationCoords.water_surface_m(s, 1)
	assert_gt(y.call(Taxonomy.WaterStep.FLOODED), y.call(Taxonomy.WaterStep.FALLING))
	assert_gt(y.call(Taxonomy.WaterStep.FALLING), y.call(Taxonomy.WaterStep.MUD))
	assert_gt(y.call(Taxonomy.WaterStep.MUD), PresentationCoords.water_height_m(1))


func test_water_draws_first_and_writes_no_depth() -> void:
	## Overlays sit a few cm above the slabs, under the surface. The water must not cull them.
	var mat := load(PresentationCatalog.WATER_MAT) as ShaderMaterial
	assert_lt(mat.render_priority, 0, "water sorts before other transparents")
	assert_true(mat.shader.code.contains("depth_draw_never"), "water writes no depth")
