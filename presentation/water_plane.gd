extends MeshInstance3D
## One plane per bowl. Height and look come from data; this node only draws.
## Does not read BowlMap — the caller passes step + height.

@export_enum("Flooded", "Falling", "Mud", "Dry") var water_step: int = 0:
	set(v):
		water_step = v
		_apply()

@export var water_height_m: float = 2.4:
	set(v):
		water_height_m = v
		position.y = v
		_apply()

@export var reduced_motion: bool = false:
	set(v):
		reduced_motion = v
		_apply()

@export var plane_size: Vector2 = Vector2(96.0, 80.0):
	set(v):
		plane_size = v
		_resize_mesh()


func _ready() -> void:
	if mesh == null:
		_resize_mesh()
	var src := load(PresentationCatalog.WATER_MAT) as ShaderMaterial
	if src:
		material_override = src.duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = water_height_m
	_apply()


func _resize_mesh() -> void:
	var plane := mesh as PlaneMesh
	if plane == null:
		plane = PlaneMesh.new()
		mesh = plane
	plane.size = plane_size
	plane.subdivide_width = clampi(int(plane_size.x / 2.0), 4, 24)
	plane.subdivide_depth = clampi(int(plane_size.y / 2.0), 4, 20)


func fit_map(map: BowlMap, pad_m: float = 1.0) -> void:
	var min_x := 9999
	var min_y := 9999
	var max_x := -9999
	var max_y := -9999
	for coord in map.cells.keys():
		min_x = mini(min_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_x = maxi(max_x, coord.x)
		max_y = maxi(max_y, coord.y)
	var cell := PresentationCoords.CELL_M
	var w := float(max_x - min_x + 1) * cell + pad_m * 2.0
	var d := float(max_y - min_y + 1) * cell + pad_m * 2.0
	plane_size = Vector2(w, d)
	position.x = (float(min_x + max_x) * 0.5) * cell
	position.z = (float(min_y + max_y) * 0.5) * cell


func _apply() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("step", water_step)
	mat.set_shader_parameter("water_height", water_height_m)
	mat.set_shader_parameter("reduced_motion", reduced_motion)
	mat.set_shader_parameter("displace_to_height", false)
