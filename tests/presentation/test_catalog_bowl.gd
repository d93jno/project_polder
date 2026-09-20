extends GutTest

## Catalog piece picks stay locked to CoverMaterial tags (plan 2.0).


func test_air_gets_slab_with_no_cover_tag() -> void:
	var map := _flat_air(3, 3)
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(1, 1, 0))
	assert_true(str(choice.id).begins_with("env_street_slab_"), "AIR draws a terrace slab")
	assert_eq(PresentationCatalog.cover_of(choice.id), -1, "slabs are not cover")


func test_cover_materials_tag_matches_catalog() -> void:
	var cases := {
		Taxonomy.CoverMaterial.PLANK: PresentationCatalog.PLANK_ID,
		Taxonomy.CoverMaterial.CRATE: PresentationCatalog.CRATE_ID,
		Taxonomy.CoverMaterial.METAL: PresentationCatalog.METAL_ID,
	}
	for material in cases:
		var map := BowlMap.new()
		map.set_cell(Vector3i(0, 0, 0), Cell.new(material))
		var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(0, 0, 0))
		assert_eq(choice.id, cases[material], "piece for %s" % Taxonomy.material_name(material))
		assert_eq(
			PresentationCatalog.cover_of(choice.id),
			material,
			"cover_of(%s) matches cell material" % choice.id
		)


func test_isolated_masonry_uses_corner_prop() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(2, 2, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(2, 2, 0))
	assert_eq(choice.id, PresentationCatalog.MASONRY_CORNER_ID)
	assert_eq(PresentationCatalog.cover_of(choice.id), Taxonomy.CoverMaterial.MASONRY)


func test_masonry_run_along_y_uses_wall_with_yaw_90() -> void:
	## Scripted-fight wall: x=6, y=0..3 — runs along data y (Godot Z).
	var map := BowlMap.new()
	for y in range(0, 4):
		map.set_cell(Vector3i(6, y, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(6, 1, 0))
	assert_eq(choice.id, PresentationCatalog.MASONRY_RUN_ID)
	assert_eq(choice.yaw, 90.0)
	assert_eq(PresentationCatalog.cover_of(choice.id), Taxonomy.CoverMaterial.MASONRY)


func test_masonry_run_along_x_keeps_yaw_0() -> void:
	var map := BowlMap.new()
	for x in range(0, 4):
		map.set_cell(Vector3i(x, 2, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(1, 2, 0))
	assert_eq(choice.id, PresentationCatalog.MASONRY_RUN_ID)
	assert_eq(choice.yaw, 0.0)


func test_unsupported_material_returns_empty_piece() -> void:
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.SMOKE))
	var choice: Dictionary = PresentationCatalog.piece_for_cell(map, Vector3i(0, 0, 0))
	assert_eq(choice.id, "")
	assert_true(PresentationCatalog.path_for_piece("env_canal_wall_tall").ends_with("env_canal_wall_tall.glb"))


func test_drifter_humanoid_alternates_a_b() -> void:
	assert_eq(
		PresentationCatalog.humanoid_for(Taxonomy.Faction.DRIFTER, 10),
		PresentationCatalog.HUMANOID_DRIFTER_A
	)
	assert_eq(
		PresentationCatalog.humanoid_for(Taxonomy.Faction.DRIFTER, 11),
		PresentationCatalog.HUMANOID_DRIFTER_B
	)
	assert_eq(
		PresentationCatalog.humanoid_for(Taxonomy.Faction.PLAYER, 10),
		PresentationCatalog.HUMANOID
	)
	assert_true(
		FileAccess.file_exists(PresentationCatalog.HUMANOID_DRIFTER_A),
		"Drifter A glb on disk"
	)
	assert_true(
		FileAccess.file_exists(PresentationCatalog.HUMANOID_DRIFTER_B),
		"Drifter B glb on disk"
	)


func test_path_for_piece_routes_props_and_kit() -> void:
	assert_true(PresentationCatalog.path_for_piece("prop_plank_wood").begins_with("res://assets/props/"))
	assert_true(PresentationCatalog.path_for_piece("env_street_slab_a").begins_with("res://assets/env/kits/terrace/"))
	assert_eq(PresentationCatalog.path_for_piece("unknown_thing"), "")


func _flat_air(w: int, h: int) -> BowlMap:
	var map := BowlMap.new()
	for x in range(w):
		for y in range(h):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	return map
