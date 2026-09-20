extends GutTest

## On-screen artifacts seen in `make run`: cone shell aim, ridge over the tiles, shader comments.

const FightView := preload("res://presentation/fight_view.gd")
const ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")


func test_cone_tip_follows_facing_axis_not_a_wedge_corner() -> void:
	var view = FightView.new()
	var from := Vector3i(5, 3, 0)
	var facing := Vector3i(1, 0, 0)
	var cells: Array = Cones.cone(BowlMap.new(), from, facing, Taxonomy.WeaponClass.RIFLE)
	var reach := RulesConstants.cone_length(Taxonomy.WeaponClass.RIFLE)
	assert_eq(view._farthest_in_facing(from, facing, cells), from + Vector3i(reach, 0, 0))
	view.free()


func test_cone_tip_follows_facing_axis_on_y() -> void:
	var view = FightView.new()
	var from := Vector3i(5, 3, 0)
	var facing := Vector3i(0, -1, 0)
	var cells: Array = Cones.cone(BowlMap.new(), from, facing, Taxonomy.WeaponClass.PISTOL)
	var reach := RulesConstants.cone_length(Taxonomy.WeaponClass.PISTOL)
	assert_eq(view._farthest_in_facing(from, facing, cells), from + Vector3i(0, -reach, 0))
	view.free()


func test_ridge_sits_past_the_far_end_of_the_street() -> void:
	var view = FightView.new()
	var map: BowlMap = ScriptedFight.street()
	var max_x := 0
	for coord in map.cells.keys():
		max_x = maxi(max_x, coord.x)
	var street_edge_m := (float(max_x) + 0.5) * PresentationCoords.CELL_M
	var pos: Vector3 = view._ridge_position(map)
	## Yawed 90°, the ridge's near edge is half its 34 m depth in front of its origin.
	assert_gt(pos.x - view._RIDGE_HALF_DEPTH_M, street_edge_m, "ridge must not overlap street tiles")
	view.free()


func test_shaders_use_slash_comments_only() -> void:
	## `##` is GDScript. In a shader it is a preprocessor token and the whole shader fails to
	## compile (the cone then renders as an opaque cream cylinder). Headless cannot see that.
	for path in _shader_files("res://"):
		var f := FileAccess.open(path, FileAccess.READ)
		var n := 0
		while not f.eof_reached():
			n += 1
			var line := f.get_line().strip_edges()
			assert_false(line.begins_with("##"), "%s:%d uses '##' (use '//')" % [path, n])


func _shader_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		out.append_array(_shader_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"):
			out.append(dir_path.path_join(file))
	return out
