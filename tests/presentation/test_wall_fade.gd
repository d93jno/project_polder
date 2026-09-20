extends GutTest

## Plan 3.1 — wall fade is view-only segment-vs-AABB math.

const WallFade = preload("res://presentation/wall_fade.gd")
const ScriptedFight = preload("res://rules/fixtures/scripted_fight.gd")
const BowlDraw = preload("res://presentation/bowl_draw.gd")


func test_segment_hits_box() -> void:
	var box := AABB(Vector3(0, 0, 0), Vector3(2, 2, 2))
	var boxes: Array = [{"key": "wall", "aabb": box}]
	var hit: Array[String] = WallFade.occluders(Vector3(-1, 1, 1), Vector3(3, 1, 1), boxes)
	assert_eq(hit, ["wall"] as Array[String])


func test_segment_misses_box() -> void:
	var box := AABB(Vector3(0, 0, 0), Vector3(2, 2, 2))
	var boxes: Array = [{"key": "wall", "aabb": box}]
	var hit: Array[String] = WallFade.occluders(Vector3(-1, 4, 1), Vector3(3, 4, 1), boxes)
	assert_eq(hit.size(), 0)


func test_segment_grazing_counts() -> void:
	## Segment clips the top face of the box (y = 2).
	var box := AABB(Vector3(0, 0, 0), Vector3(2, 2, 2))
	var boxes: Array = [{"key": "wall", "aabb": box}]
	var hit: Array[String] = WallFade.occluders(Vector3(-1, 2, 1), Vector3(3, 2, 1), boxes)
	assert_eq(hit, ["wall"] as Array[String])


func test_camera_inside_counts() -> void:
	var box := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var boxes: Array = [{"key": "wall", "aabb": box}]
	var hit: Array[String] = WallFade.occluders(Vector3.ZERO, Vector3(5, 0, 0), boxes)
	assert_eq(hit, ["wall"] as Array[String])


func test_only_listed_keys_return() -> void:
	var a := AABB(Vector3(0, 0, 0), Vector3(1, 2, 1))
	var b := AABB(Vector3(10, 0, 0), Vector3(1, 2, 1))
	var boxes: Array = [{"key": "a", "aabb": a}, {"key": "b", "aabb": b}]
	var hit: Array[String] = WallFade.occluders(Vector3(-1, 1, 0.5), Vector3(2, 1, 0.5), boxes)
	assert_eq(hit, ["a"] as Array[String])


func test_tall_piece_allowlist() -> void:
	assert_true(WallFade.is_tall_piece("env_canal_wall_tall"))
	assert_true(WallFade.is_tall_piece("env_house_2storey_a"))
	assert_false(WallFade.is_tall_piece("env_street_slab_a"))
	assert_false(WallFade.is_tall_piece("prop_cover_masonry_corner"))
	assert_false(WallFade.is_tall_piece("prop_crate_wood"))


func test_collect_boxes_skips_above_cutaway() -> void:
	var bowl = BowlDraw.new()
	add_child_autofree(bowl)
	## Two masonry cells at z=0 and a fake tall piece at z=1 via meta on a marker.
	var map := BowlMap.new()
	map.set_cell(Vector3i(0, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	map.set_cell(Vector3i(1, 0, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	map.set_cell(Vector3i(0, 0, 1), Cell.new(Taxonomy.CoverMaterial.AIR, Taxonomy.CellFlags.DECK))
	bowl.draw_map(map)
	## Force a tall id onto the roof node so cutaway is the only filter under test.
	for n in bowl.get_children():
		if int(n.get_meta("polder_z", -1)) == 1:
			n.set_meta("polder_piece", "env_canal_wall_tall")
	var at_street: Array = WallFade.collect_boxes(bowl, 0)
	for entry in at_street:
		assert_lte(int((entry["root"] as Node).get_meta("polder_z")), 0)
	var with_roof: Array = WallFade.collect_boxes(bowl, 1)
	assert_gt(with_roof.size(), at_street.size(), "cutaway 1 includes the roof tall piece")


func test_friendlies_only_via_heads_list() -> void:
	## The fight view only passes friendly sample points; empty list → no fade.
	var cam := Vector3(12, 2, 6)
	var friendly := Vector3(4, 0.95, 6)
	var fade = WallFade.new()
	add_child_autofree(fade)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 2.4, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "quay"
	mi.mesh = mesh
	mi.set_meta("polder_piece", "env_canal_wall_tall")
	mi.set_meta("polder_z", 0)
	## Center of a 2.4 m quay sitting on the segment cam → friendly.
	mi.position = Vector3(6, 1.2, 6)
	var bowl := Node3D.new()
	add_child_autofree(bowl)
	bowl.add_child(mi)
	await get_tree().process_frame
	fade.snap(cam, [], bowl, 99)
	assert_almost_eq(mi.transparency, 0.0, 0.001, "no friendly heads → no fade")
	fade.snap(cam, [friendly], bowl, 99)
	assert_almost_eq(mi.transparency, WallFade.FADE_TRANSPARENCY, 0.001, "friendly head fades the quay")


func test_cover_tag_unchanged_when_faded() -> void:
	var bowl = BowlDraw.new()
	add_child_autofree(bowl)
	bowl.draw_map(ScriptedFight.street())
	var cell := Vector3i(6, 3, 0)
	var before: int = bowl.cover_tag_at(cell)
	assert_eq(before, Taxonomy.CoverMaterial.MASONRY)
	for n in bowl.get_children():
		if n.has_meta("polder_piece") and n.get_meta("polder_piece") == "env_canal_wall_tall":
			for gi in WallFade._geometry_under(n):
				gi.transparency = WallFade.FADE_TRANSPARENCY
	assert_eq(bowl.cover_tag_at(cell), before, "fade must not change cover_tag_at")


func test_yaw180_quay_occludes_piet_on_scripted_street() -> void:
	## Done-when geometry: yaw 180 puts the tall quay between camera and Piet.
	var Rig = load("res://presentation/camera_rig.gd")
	var look := PresentationCoords.world(Vector3i(8, 3, 0)) + Vector3(0.0, 1.5, 0.0)
	var offset: Vector3 = Rig.eye_offset(Rig.ZOOM_DISTANCES[1], Rig.PITCH_DEG, 180.0)
	var cam: Vector3 = look + offset
	var piet_chest := (
		PresentationCoords.world_ground(Vector3i(5, 3, 0)) + Vector3(0.0, WallFade.HEAD_Y_M, 0.0)
	)
	## Real kit AABB for env_canal_wall_tall at (6,3,0), yaw 90°.
	var quay := AABB(Vector3(11.61, 0.0, 5.0), Vector3(0.8, 2.4, 2.0))
	var hit: Array[String] = WallFade.occluders(cam, piet_chest, [{"key": "quay", "aabb": quay}])
	assert_eq(hit, ["quay"] as Array[String], "yaw 180: quay sits on camera → Piet")
	assert_gt(cam.x, quay.position.x + quay.size.x, "camera is east of the quay")
	assert_lt(piet_chest.x, quay.position.x, "Piet is west of the quay")
