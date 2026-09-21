extends GutTest

## BowlMap construction, cell helpers, Resource round-trip, levee limitation.


func test_cell_defaults_and_flags() -> void:
	var cell := Cell.new()
	assert_eq(cell.material, Taxonomy.CoverMaterial.AIR)
	assert_eq(cell.flags, 0)
	assert_eq(cell.occupant, -1)
	assert_false(cell.has_flag(Taxonomy.CellFlags.DECK))

	cell.flags = Taxonomy.CellFlags.DECK | Taxonomy.CellFlags.INTERIOR
	assert_true(cell.has_flag(Taxonomy.CellFlags.DECK))
	assert_true(cell.has_flag(Taxonomy.CellFlags.INTERIOR))
	assert_false(cell.has_flag(Taxonomy.CellFlags.SHELTER))


func test_bowl_built_in_code() -> void:
	var bowl := BowlMap.new()
	bowl.water_step = Taxonomy.WaterStep.FALLING
	bowl.water_z = 1
	bowl.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.GROUND))
	bowl.set_cell(
		Vector3i(1, 0, 0),
		Cell.new(Taxonomy.CoverMaterial.PLANK, Taxonomy.CellFlags.SHELTER, 3)
	)
	bowl.set_cell(
		Vector3i(0, 0, 1),
		Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK)
	)

	assert_eq(bowl.cell_count(), 3)
	assert_true(bowl.has_cell(Vector3i(1, 0, 0)))
	assert_eq(bowl.get_cell(Vector3i(1, 0, 0)).occupant, 3)
	assert_eq(bowl.get_cell(Vector3i(0, 0, 1)).material, Taxonomy.CoverMaterial.AIR)
	assert_null(bowl.get_cell(Vector3i(9, 9, 9)))


func test_bowl_map_resource_round_trip() -> void:
	var path := "user://test_bowl_map_round_trip.tres"
	var original := BowlMap.new()
	original.water_step = Taxonomy.WaterStep.FLOODED
	original.water_z = -2
	original.set_cell(Vector3i(2, -1, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY, Taxonomy.CellFlags.INTERIOR, 7))
	original.set_cell(Vector3i(0, 0, 3), Cell.new(Taxonomy.CoverMaterial.SMOKE, 0, -1))
	original.set_cell(Vector3i(-4, 5, 1), Cell.new(Taxonomy.CoverMaterial.WATER_DEEP, Taxonomy.CellFlags.SWIMMABLE))

	var save_err: Error = ResourceSaver.save(original, path)
	assert_eq(save_err, OK, "ResourceSaver.save should succeed")

	var loaded: BowlMap = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BowlMap
	assert_not_null(loaded, "ResourceLoader should return a BowlMap")
	assert_eq(loaded.water_step, Taxonomy.WaterStep.FLOODED)
	assert_eq(loaded.water_z, -2)
	assert_eq(loaded.cell_count(), 3)

	var c1: Cell = loaded.get_cell(Vector3i(2, -1, 0))
	assert_not_null(c1)
	assert_true(c1.equals(Cell.new(Taxonomy.CoverMaterial.MASONRY, Taxonomy.CellFlags.INTERIOR, 7)))

	var c2: Cell = loaded.get_cell(Vector3i(0, 0, 3))
	assert_not_null(c2)
	assert_eq(c2.material, Taxonomy.CoverMaterial.SMOKE)
	assert_eq(c2.occupant, -1)

	var c3: Cell = loaded.get_cell(Vector3i(-4, 5, 1))
	assert_not_null(c3)
	assert_true(c3.has_flag(Taxonomy.CellFlags.SWIMMABLE))
	assert_eq(c3.material, Taxonomy.CoverMaterial.WATER_DEEP)

	DirAccess.remove_absolute(path)


func test_levee_two_surfaces_not_yet_supported() -> void:
	## Documents the §7.3 / UI §3 limitation: one water plane per BowlMap for now.
	var bowl := BowlMap.new()
	bowl.water_step = Taxonomy.WaterStep.DRY
	bowl.water_z = 0
	## A second surface would need another step/z (or a region list). The type has
	## only one of each — asserting the schema so Act II cannot silently assume two.
	var names: PackedStringArray = []
	for prop in bowl.get_property_list():
		if prop.type != TYPE_NIL:
			names.append(String(prop.name))
	assert_true("water_step" in names, "single water_step field exists")
	assert_true("water_z" in names, "single water_z field exists")
	assert_false(
		"water_regions" in names,
		"TODO(levee): no per-region water list yet — promote before Act II levee maps"
	)
	assert_false(
		"water_steps" in names,
		"TODO(levee): no plural water_steps field"
	)


## GDD 5.8: water stands at a level. A cell is wet when its floor is at or below it and it is not a
## deck. Everything above is dry ground, whatever the step.
func test_a_cell_is_wet_at_or_below_the_water_level() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	map.water_z = 1
	for z in range(0, 3):
		map.set_cell(Vector3i(0, 0, z), Cell.new(Taxonomy.CoverMaterial.AIR))
	assert_true(map.is_wet(Vector3i(0, 0, 0)))
	assert_true(map.is_wet(Vector3i(0, 0, 1)), "the level itself is wet")
	assert_false(map.is_wet(Vector3i(0, 0, 2)), "above the water is dry ground")


func test_a_deck_is_dry_at_any_level() -> void:
	## A roof deck, and the deck of a floating dock that rides the water on its piles.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	map.water_z = 0
	map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.CRATE, Taxonomy.CellFlags.DECK))
	map.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.CRATE))
	assert_false(map.is_wet(Vector3i(1, 0, 0)), "the dock's deck stands above the water")
	assert_true(map.is_wet(Vector3i(2, 0, 0)), "the same cell without the deck flag is in it")


func test_the_step_only_governs_wet_cells() -> void:
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.FLOODED
	map.water_z = 0
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR))
	assert_eq(map.step_at(Vector3i(0, 0, 0)), Taxonomy.WaterStep.FLOODED)
	assert_eq(map.step_at(Vector3i(0, 0, 1)), Taxonomy.WaterStep.DRY, "a roof is the same roof at every step")
	map.water_step = Taxonomy.WaterStep.MUD
	assert_eq(map.step_at(Vector3i(0, 0, 0)), Taxonomy.WaterStep.MUD)
	assert_eq(map.step_at(Vector3i(0, 0, 1)), Taxonomy.WaterStep.DRY)
