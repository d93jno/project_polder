extends GutTest

## The tile-by-tile water change (plan 06 §6.4): two planes keep opposite sides of one front.

const Water := preload("res://presentation/water_plane.gd")
const FightView := preload("res://presentation/fight_view.gd")
const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")


func _plane() -> Node:
	var plane = Water.new()
	add_child_autofree(plane)
	return plane


func _param(plane: Node, name: String) -> Variant:
	return (plane.material_override as ShaderMaterial).get_shader_parameter(name)


func test_a_plane_has_no_sweep_until_one_is_set() -> void:
	var plane := _plane()
	var radius = _param(plane, "sweep_radius")
	assert_true(radius == null or float(radius) < 0.0, "off by default (the shader default is negative)")


func test_the_old_and_the_new_plane_take_opposite_sides_of_the_front() -> void:
	var old := _plane()
	var new := _plane()
	var origin := Vector2(6.0, 6.0)
	new.set_sweep(origin, 8.0, true)
	old.set_sweep(origin, 8.0, false)
	assert_eq(_param(new, "sweep_keep_inside"), true)
	assert_eq(_param(old, "sweep_keep_inside"), false)
	assert_eq(_param(new, "sweep_radius"), _param(old, "sweep_radius"), "one front")
	assert_eq(_param(new, "sweep_origin"), origin)
	assert_eq(_param(new, "sweep_cell"), PresentationCoords.CELL_M, "the front steps by whole tiles")


func test_clearing_the_sweep_turns_it_off() -> void:
	var plane := _plane()
	plane.set_sweep(Vector2.ZERO, 8.0, true)
	plane.clear_sweep()
	assert_lt(float(_param(plane, "sweep_radius")), 0.0)


func test_the_front_reaches_the_farthest_cell_of_the_bowl() -> void:
	var view = FightView.new()
	view._state = FloodedTerrace.opening()
	var origin := Vector2(3, 3) * PresentationCoords.CELL_M
	var reach: float = view._farthest_ring_m(origin)
	## The terrace is 20 by 14 cells, so from (3, 3) the far corner is 16 tiles along x.
	assert_eq(reach, 16.0 * PresentationCoords.CELL_M)
	view.free()


func test_the_shader_declares_the_sweep_and_discards_with_slash_comments() -> void:
	var text := FileAccess.get_file_as_string("res://assets/shaders/water.gdshader")
	for name in ["sweep_origin", "sweep_radius", "sweep_keep_inside", "sweep_cell"]:
		assert_true(text.contains("uniform") and text.contains(name), name)
	assert_true(text.contains("discard;"))
