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

@export var plane_size: Vector2 = Vector2(96.0, 80.0)


func _ready() -> void:
	if mesh == null:
		var plane := PlaneMesh.new()
		plane.size = plane_size
		plane.subdivide_width = 24
		plane.subdivide_depth = 20
		mesh = plane
	var src := load(PresentationCatalog.WATER_MAT) as ShaderMaterial
	if src:
		material_override = src.duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = water_height_m
	_apply()


func _apply() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("step", water_step)
	mat.set_shader_parameter("water_height", water_height_m)
	mat.set_shader_parameter("reduced_motion", reduced_motion)
	mat.set_shader_parameter("displace_to_height", false)
