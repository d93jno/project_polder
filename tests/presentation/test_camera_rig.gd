extends GutTest

## PresentationCameraRig pose math (plan 2.1) — no scene required.

const Rig := preload("res://presentation/camera_rig.gd")


func test_rest_eye_sits_west_of_look_facing_plus_x() -> void:
	var offset: Vector3 = Rig.eye_offset(42.2, Rig.PITCH_DEG, 0.0)
	assert_almost_eq(offset.z, 0.0, 0.05, "yaw 0 stays on the XZ look meridian")
	assert_lt(offset.x, -30.0, "camera sits west of the look point")
	assert_gt(offset.y, 25.0, "elevated pitch clears roofs")
	## Matches legacy P0 eye (−24, 30.5, 2) − look (8, 3, 2) ≈ (−32, 27.5, 0).
	assert_almost_eq(offset.x, -32.0, 0.2)
	assert_almost_eq(offset.y, 27.5, 0.2)


func test_yaw_90_moves_eye_to_minus_z() -> void:
	var offset: Vector3 = Rig.eye_offset(42.2, Rig.PITCH_DEG, 90.0)
	assert_almost_eq(offset.x, 0.0, 0.05)
	assert_lt(offset.z, -30.0)


func test_snap_yaw_wraps_and_clears_peek() -> void:
	var rig = Rig.new()
	rig.ensure_camera()
	rig.peek_deg = 12.0
	rig.snap_yaw(1)
	assert_eq(rig.yaw_index, 1)
	assert_eq(rig.peek_deg, 0.0)
	rig.snap_yaw(1)
	rig.snap_yaw(1)
	rig.snap_yaw(1)
	assert_eq(rig.yaw_index, 0)
	rig.snap_yaw(-1)
	assert_eq(rig.yaw_index, 3)
	rig.free()


func test_zoom_clamps_to_three_levels() -> void:
	var rig = Rig.new()
	rig.ensure_camera()
	rig.set_zoom(0)
	assert_eq(rig.zoom_index, 0)
	assert_eq(rig.distance(), Rig.ZOOM_DISTANCES[0])
	rig.set_zoom(99)
	assert_eq(rig.zoom_index, 2)
	assert_eq(rig.distance(), Rig.ZOOM_DISTANCES[2])
	rig.free()


func test_toggle_projection_flips_camera_mode() -> void:
	var rig = Rig.new()
	rig.ensure_camera()
	rig.apply_pose()
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(rig.camera.fov, Rig.FOV_DEG, 0.01)
	rig.toggle_projection()
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_gt(rig.camera.size, 0.0)
	rig.toggle_projection()
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	rig.free()


func test_peek_offsets_yaw_degrees() -> void:
	var rig = Rig.new()
	rig.ensure_camera()
	rig.yaw_index = 0
	rig.peek_deg = 15.0
	assert_almost_eq(rig.yaw_degrees(), 15.0, 0.01)
	rig.free()


## Plan 2.5 — projection + peek policy locked for all later authoring.
func test_locked_policy_is_perspective_with_hold_peek() -> void:
	assert_false(Rig.LOCKED_ORTHOGRAPHIC, "perspective is the production default")
	assert_true(Rig.LOCKED_PEEK_ENABLED, "hold-to-peek stays; 90°-only would punish diagonals")
	assert_eq(Rig.FOV_DEG, 25.0)
	assert_gt(Rig.PEEK_MAX_DEG, 0.0)
	var rig = Rig.new()
	rig.ensure_camera()
	rig.apply_pose()
	assert_eq(rig.orthographic, Rig.LOCKED_ORTHOGRAPHIC)
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(rig.camera.fov, Rig.FOV_DEG, 0.01)
	rig.toggle_projection()
	assert_true(rig.orthographic)
	rig.reset_to_locked_policy()
	assert_false(rig.orthographic)
	assert_eq(rig.peek_deg, 0.0)
	assert_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	rig.free()


## Flooded-roof freeboard must stay readable at the rest arm (plan 2.5 / UI §18).
func test_rest_eye_clears_flooded_roof_freeboard() -> void:
	## scenes/p0: water Y≈2.4 m, ~3.7 m freeboard to eaves → eaves ≈ 6.1 m.
	var offset: Vector3 = Rig.eye_offset(Rig.ZOOM_DISTANCES[Rig.REST_ZOOM_INDEX], Rig.PITCH_DEG, 0.0)
	var eye_y := Rig.DEFAULT_LOOK.y + offset.y
	assert_gt(eye_y, 6.1 + 10.0, "rest eye sits well above flooded eaves so height still reads")
