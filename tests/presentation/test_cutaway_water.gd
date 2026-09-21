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


## The extract dock is a floating dock on guide piles. Its deck is 0.38 m above its origin (measured
## from env_pier: the posts drop to -1.4 m), built for water near street level. Under a 2.0 m Flooded
## surface it is 1.6 m underwater, and the extract place cannot be found. It rides the water instead.
func test_a_dock_rides_the_water_and_never_goes_under() -> void:
	for step in [Taxonomy.WaterStep.FLOODED, Taxonomy.WaterStep.FALLING]:
		var surface := PresentationCoords.water_surface_m(step, 0)
		assert_almost_eq(
			PresentationCoords.dock_deck_y(0, step, 0) - surface,
			PresentationCoords.DOCK_FREEBOARD_M, 0.001, "the deck stands a freeboard clear of the water"
		)
	assert_almost_eq(PresentationCoords.dock_deck_y(0, Taxonomy.WaterStep.DRY, 0), PresentationCoords.DOCK_DECK_TOP_M, 0.001, "dry: it stands as built")
	assert_eq(PresentationCoords.dock_lift_m(Taxonomy.WaterStep.DRY, 0), 0.0)
	assert_eq(PresentationCoords.dock_lift_m(Taxonomy.WaterStep.MUD, 0), 0.0, "a film of mud does not lift it")
	assert_gt(
		PresentationCoords.dock_lift_m(Taxonomy.WaterStep.FLOODED, 0),
		PresentationCoords.dock_lift_m(Taxonomy.WaterStep.FALLING, 0)
	)


func test_a_body_on_the_dock_stands_on_the_deck_and_does_not_swim() -> void:
	var cell := Vector3i(2, 0, 0)
	var flooded := Taxonomy.WaterStep.FLOODED
	var deck := PresentationCoords.dock_deck_y(0, flooded, 0)
	assert_almost_eq(PresentationCoords.world_play(cell, flooded, 0, true).y, deck + 0.02, 0.001)
	assert_almost_eq(PresentationCoords.unit_origin(cell, flooded, 0, false, true).y, deck + 0.02, 0.001, "no draft: feet on the boards")
	assert_lt(PresentationCoords.unit_origin(cell, flooded, 0).y, deck, "the same cell without a dock is water")


func test_dock_cells_come_from_the_stamps_that_ride_the_water() -> void:
	const TerraceStamps := preload("res://presentation/fixtures/flooded_terrace_stamps.gd")
	const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
	var cells: Dictionary = PresentationCatalog.dock_cells(TerraceStamps.stamps())
	for extract in FloodedTerrace.opening().extract_cells:
		assert_true(cells.has(extract), "the extract cell %s is on the dock" % extract)
	assert_eq(cells.size(), 3, "1 x 3 cells and nothing else rides")


func test_the_pier_deck_is_lifted_with_the_water_and_the_piles_are_not() -> void:
	const TerraceStamps := preload("res://presentation/fixtures/flooded_terrace_stamps.gd")
	var BowlDraw = load("res://presentation/bowl_draw.gd")
	var deck_y := {}
	var piles_y := {}
	for step in [Taxonomy.WaterStep.DRY, Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.FLOODED]:
		var bowl = BowlDraw.new()
		add_child_autofree(bowl)
		bowl.draw_map(_terrace_map(step), TerraceStamps.stamps())
		for n in bowl.get_children():
			if n.has_meta("polder_piece") and str(n.get_meta("polder_piece")) == "env_pier":
				deck_y[step] = (n.find_child("pier_deck", true, false) as Node3D).position.y
				piles_y[step] = (n.find_child("pier_piles", true, false) as Node3D).position.y
	assert_gt(deck_y[Taxonomy.WaterStep.FLOODED], deck_y[Taxonomy.WaterStep.FALLING])
	assert_gt(deck_y[Taxonomy.WaterStep.FALLING], deck_y[Taxonomy.WaterStep.DRY])
	assert_almost_eq(
		deck_y[Taxonomy.WaterStep.FLOODED] - deck_y[Taxonomy.WaterStep.DRY],
		PresentationCoords.dock_lift_m(Taxonomy.WaterStep.FLOODED, 0), 0.001
	)
	for step in piles_y.keys():
		assert_eq(piles_y[step], 0.0, "the piles were driven into the bed and do not move")


func _terrace_map(step: Taxonomy.WaterStep) -> BowlMap:
	const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
	return FloodedTerrace.map(step)


## The pier art contract (assets/env/kits/terrace/MANIFEST.md): one glb, two named nodes. `pier_deck`
## rides the water and `pier_piles` stay where they were driven. The code's deck height is measured
## from the mesh here, so art and constant cannot drift apart the way the old 0.38 m dock did.
func _pier() -> Node3D:
	var packed := PresentationCatalog.scene_for_piece("env_pier")
	var pier := packed.instantiate() as Node3D
	add_child_autofree(pier)
	return pier


## The mesh nodes at or under `root`. A glb node with no children is itself the mesh.
func _meshes(root: Node) -> Array:
	var out: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		out.append(root)
	return out


func _mesh_bounds(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(root):
		var m := mi as MeshInstance3D
		var local: AABB = m.get_aabb()
		var b: AABB = m.global_transform * local if m.is_inside_tree() else local
		box = b if first else box.merge(b)
		first = false
	return box


## Y of the largest upward-facing surface in the mesh: the boards you walk on.
func _walking_surface_y(root: Node) -> float:
	var areas := {}
	for mi in _meshes(root):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for i in v.size():
					idx.append(i)
			for i in range(0, idx.size(), 3):
				var a: Vector3 = m.global_transform * v[idx[i]] if m.is_inside_tree() else v[idx[i]]
				var b: Vector3 = m.global_transform * v[idx[i + 1]] if m.is_inside_tree() else v[idx[i + 1]]
				var c: Vector3 = m.global_transform * v[idx[i + 2]] if m.is_inside_tree() else v[idx[i + 2]]
				var n: Vector3 = (b - a).cross(c - a)
				## Godot front faces wind clockwise, so this cross product points into the mesh:
				## a top face has n.y < 0.
				if n.length() < 0.0002 or absf(n.normalized().y) < 0.95 or n.y > 0.0:
					continue
				var key := snappedf((a.y + b.y + c.y) / 3.0, 0.02)
				areas[key] = float(areas.get(key, 0.0)) + n.length() * 0.5
	var best_y := 0.0
	var best_area := 0.0
	for k in areas.keys():
		if float(areas[k]) > best_area:
			best_area = float(areas[k])
			best_y = float(k)
	return best_y


func test_the_pier_has_a_deck_that_rides_and_piles_that_stay() -> void:
	var pier := _pier()
	for node_name in PresentationCatalog.RIDES_WATER.values():
		assert_not_null(pier.find_child(node_name, true, false), "the riding node %s exists" % node_name)
	assert_not_null(pier.find_child("pier_piles", true, false), "the piles are a separate node")


func test_the_deck_height_in_code_is_the_deck_height_in_the_mesh() -> void:
	var deck := _pier().find_child("pier_deck", true, false)
	assert_almost_eq(_walking_surface_y(deck), PresentationCoords.DOCK_DECK_TOP_M, 0.03, "boards are where the code says")
	assert_gte(_mesh_bounds(deck).position.y, -0.01, "the floats do not sink into the ground when the dock is dry")


func test_the_piles_run_from_below_the_bed_to_above_a_flooded_deck() -> void:
	var piles := _pier().find_child("pier_piles", true, false)
	var bounds := _mesh_bounds(piles)
	assert_lt(bounds.position.y, -1.0, "driven into the bed")
	var flooded_deck_top := PresentationCoords.dock_deck_y(0, Taxonomy.WaterStep.FLOODED, 0)
	assert_gt(bounds.end.y, flooded_deck_top + 0.8, "a Flooded deck still has piles standing over it")
	assert_lt(bounds.size.x, 2.9, "the pile row stays close to its 2 m footprint")
