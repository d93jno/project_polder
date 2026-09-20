class_name PresentationCameraRig
extends Node3D
## Fixed-pitch tactical camera shared by the fight view and P0 lighting scenes.
## 90° yaw snaps, three zoom distances, perspective ↔ orthographic, hold-to-peek.
## Wall fade (UI §2) is out of scope for 2.1.

const FOV_DEG := 25.0
## Depression from horizontal. Matches scenes/p0 rest (eye −24,30.5,2 → look 8,3,2).
const PITCH_DEG := 40.7
const YAW_STEP_DEG := 90.0
const PEEK_MAX_DEG := 35.0
const PEEK_SPRING_DEG_PER_SEC := 120.0
const PEEK_MOUSE_SENS := 0.18
## Mid distance matches the P0 rest arm length (~42.2 m).
const ZOOM_DISTANCES := [30.0, 42.2, 58.0]
const DEFAULT_LOOK := Vector3(8.0, 3.0, 2.0)
## Yaw 0: camera sits west of the look point, facing +X down the street.
const REST_YAW_INDEX := 0
const REST_ZOOM_INDEX := 1

@export var look_at_point: Vector3 = DEFAULT_LOOK
@export var make_current: bool = true

var yaw_index: int = REST_YAW_INDEX
var zoom_index: int = REST_ZOOM_INDEX
var orthographic: bool = false
var peek_deg: float = 0.0

var camera: Camera3D

var _peek_held: bool = false
var _alt_held: bool = false


func _ready() -> void:
	ensure_camera()
	if make_current:
		camera.current = true
	apply_pose()


func _process(delta: float) -> void:
	if _peek_held or _alt_held:
		return
	if is_zero_approx(peek_deg):
		return
	peek_deg = move_toward(peek_deg, 0.0, PEEK_SPRING_DEG_PER_SEC * delta)
	apply_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ALT:
			_alt_held = key.pressed
			get_viewport().set_input_as_handled()
			return
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_BRACKETLEFT, KEY_COMMA:
					snap_yaw(-1)
					get_viewport().set_input_as_handled()
				KEY_BRACKETRIGHT, KEY_PERIOD:
					snap_yaw(1)
					get_viewport().set_input_as_handled()
				KEY_EQUAL, KEY_KP_ADD:
					set_zoom(zoom_index - 1)
					get_viewport().set_input_as_handled()
				KEY_MINUS, KEY_KP_SUBTRACT:
					set_zoom(zoom_index + 1)
					get_viewport().set_input_as_handled()
				KEY_O:
					toggle_projection()
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					set_zoom(zoom_index - 1)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					set_zoom(zoom_index + 1)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE:
				_peek_held = mb.pressed
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _peek_held or _alt_held:
			var motion := event as InputEventMouseMotion
			peek_deg = clampf(
				peek_deg + motion.relative.x * PEEK_MOUSE_SENS, -PEEK_MAX_DEG, PEEK_MAX_DEG
			)
			apply_pose()
			get_viewport().set_input_as_handled()


## Create or bind the Camera3D child. Safe to call from builders before _ready.
func ensure_camera() -> Camera3D:
	if camera != null and is_instance_valid(camera):
		return camera
	camera = get_node_or_null("Camera") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.near = 0.15
		camera.far = 400.0
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		add_child(camera)
	return camera


func focus(point: Vector3) -> void:
	look_at_point = point
	apply_pose()


func snap_yaw(direction: int) -> void:
	yaw_index = posmod(yaw_index + direction, 4)
	peek_deg = 0.0
	apply_pose()


func set_zoom(index: int) -> void:
	zoom_index = clampi(index, 0, ZOOM_DISTANCES.size() - 1)
	apply_pose()


func toggle_projection() -> void:
	orthographic = not orthographic
	apply_pose()


func yaw_degrees() -> float:
	return float(yaw_index) * YAW_STEP_DEG + peek_deg


func distance() -> float:
	return ZOOM_DISTANCES[zoom_index]


## Eye offset from the look point for the given arm. Pure — safe to unit-test.
static func eye_offset(dist: float, pitch_deg: float, yaw_deg: float) -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var horiz := dist * cos(pitch)
	var vert := dist * sin(pitch)
	return Vector3(-horiz * cos(yaw), vert, -horiz * sin(yaw))


func apply_pose() -> void:
	ensure_camera()
	var dist := distance()
	var offset := eye_offset(dist, PITCH_DEG, yaw_degrees())
	var eye := look_at_point + offset
	## look_at() needs the tree; builders pack offline.
	if camera.is_inside_tree():
		camera.position = eye
		camera.look_at(look_at_point)
	else:
		camera.transform = Transform3D(Basis.IDENTITY, eye).looking_at(look_at_point, Vector3.UP)
	if orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = dist * tan(deg_to_rad(FOV_DEG * 0.5))
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOV_DEG
