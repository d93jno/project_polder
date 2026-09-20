extends GutTest

## Hand-written LOS cases from plan §1.2.


func _air_bowl() -> BowlMap:
	return BowlMap.new()


func test_line3d_same_cell() -> void:
	var line := Los.line3d(Vector3i(1, 2, 3), Vector3i(1, 2, 3))
	assert_eq(line.size(), 1)
	assert_eq(line[0], Vector3i(1, 2, 3))


func test_line3d_axis_aligned() -> void:
	var line := Los.line3d(Vector3i(0, 0, 0), Vector3i(3, 0, 0))
	assert_eq(line, [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(3, 0, 0),
	] as Array[Vector3i])


func test_clean_line_across_empty_cells() -> void:
	var bowl := _air_bowl()
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(5, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_true(result.clean)


func test_plank_stops_pistol_passes_rifle() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.PLANK))
	var pistol := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_false(pistol.clean)
	assert_eq(pistol.blocker, Taxonomy.CoverMaterial.PLANK)
	assert_eq(pistol.blocker_cell, Vector3i(2, 0, 0))

	var rifle := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), Taxonomy.WeaponClass.RIFLE
	)
	assert_true(rifle.clean, "rifle punches plank")


func test_masonry_stops_pistol_and_rifle() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	for weapon in [Taxonomy.WeaponClass.PISTOL, Taxonomy.WeaponClass.RIFLE]:
		var result := Los.line_of_sight(bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), weapon)
		assert_false(result.clean, "masonry stops %s" % Taxonomy.weapon_class_name(weapon))
		assert_eq(result.blocker, Taxonomy.CoverMaterial.MASONRY)
		assert_eq(result.blocker_cell, Vector3i(2, 0, 0))


func test_smoke_blocks_every_class() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.SMOKE))
	for weapon in Taxonomy.WeaponClass.values():
		var result := Los.line_of_sight(bowl, Vector3i(0, 0, 0), Vector3i(3, 0, 0), weapon)
		assert_false(result.clean, "smoke blocks %s" % Taxonomy.weapon_class_name(weapon))
		assert_eq(result.blocker, Taxonomy.CoverMaterial.SMOKE)
		assert_eq(result.blocker_cell, Vector3i(1, 0, 0))


func test_body_in_deep_water_has_no_line_to_or_from() -> void:
	var bowl := _air_bowl()
	bowl.water_step = Taxonomy.WaterStep.FLOODED
	bowl.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.WATER_DEEP))
	bowl.set_cell(Vector3i(4, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))

	var from_deep := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_false(from_deep.clean)
	assert_eq(from_deep.blocker, Taxonomy.CoverMaterial.WATER_DEEP)
	assert_eq(from_deep.blocker_cell, Vector3i(0, 0, 0))

	var to_deep := Los.line_of_sight(
		bowl, Vector3i(4, 0, 0), Vector3i(0, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_false(to_deep.clean)
	assert_eq(to_deep.blocker, Taxonomy.CoverMaterial.WATER_DEEP)
	assert_eq(to_deep.blocker_cell, Vector3i(0, 0, 0))


func test_chest_deep_falling_water_is_fully_visible() -> void:
	## The rule the Falling step exists for (GDD §5.8 / §5.4).
	var bowl := _air_bowl()
	bowl.water_step = Taxonomy.WaterStep.FALLING
	bowl.water_z = 0
	for x in range(0, 5):
		bowl.set_cell(Vector3i(x, 0, 0), Cell.new(Taxonomy.CoverMaterial.WATER_CHEST))

	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(4, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_true(result.clean, "chest-deep Falling water does not hide or block")


func test_blocked_line_names_blocker_and_cell() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(3, 1, 0), Cell.new(Taxonomy.CoverMaterial.METAL))
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(5, 2, 0), Taxonomy.WeaponClass.SHOTGUN
	)
	assert_false(result.clean)
	assert_eq(result.blocker, Taxonomy.CoverMaterial.METAL)
	assert_eq(result.blocker_cell, Vector3i(3, 1, 0))


func test_vertical_roof_to_street_blocked_by_ground() -> void:
	var bowl := _air_bowl()
	## Street at z=0, roof deck at z=2, floor slab at z=1.
	bowl.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	bowl.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.GROUND))
	bowl.set_cell(Vector3i(0, 0, 2), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))

	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 2), Vector3i(0, 0, 0), Taxonomy.WeaponClass.RIFLE
	)
	assert_false(result.clean)
	assert_eq(result.blocker, Taxonomy.CoverMaterial.GROUND)
	assert_eq(result.blocker_cell, Vector3i(0, 0, 1))


func test_vertical_open_shaft_is_clean() -> void:
	var bowl := _air_bowl()
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 3), Vector3i(0, 0, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_true(result.clean)


func test_street_to_overpass_deck_clear_beside_pillar() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(2, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY)) ## pillar
	bowl.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(0, 0, 1), Taxonomy.WeaponClass.PISTOL
	)
	assert_true(result.clean, "vertical beside pillar, not through it")


func test_basement_isolated_by_ground() -> void:
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(0, 0, -1), Cell.new(Taxonomy.CoverMaterial.AIR)) ## basement
	bowl.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.GROUND)) ## street slab
	bowl.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR)) ## street air
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, -1), Vector3i(0, 0, 1), Taxonomy.WeaponClass.SNIPER
	)
	assert_false(result.clean)
	assert_eq(result.blocker, Taxonomy.CoverMaterial.GROUND)


func test_strict_corner_blocks_when_either_side_stops() -> void:
	## Diagonal (0,0)->(2,2) first steps through the corner of (1,0) and (0,1).
	## Strict: one masonry neighbour is enough to block.
	var bowl := _air_bowl()
	bowl.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	## (0,1,0) left air
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(2, 2, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_false(result.clean, "strict corner: either grazed cell blocks")
	assert_eq(result.blocker, Taxonomy.CoverMaterial.MASONRY)
	assert_eq(result.blocker_cell, Vector3i(1, 0, 0))


func test_strict_corner_clean_when_both_sides_air() -> void:
	var bowl := _air_bowl()
	var result := Los.line_of_sight(
		bowl, Vector3i(0, 0, 0), Vector3i(2, 2, 0), Taxonomy.WeaponClass.PISTOL
	)
	assert_true(result.clean)
