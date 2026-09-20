extends MeshInstance3D
## Draws a Watch volume. The cells come from rules later; this mesh does not call Cones.cone().
## Mode: 0 outline, 1 live, 2 unresolved apex, 3 spent (shader no-op).

@export_enum("FriendlyOutline", "EnemyLive", "UnresolvedApex", "Spent") var mode: int = 1:
	set(v):
		mode = v
		_apply()

@export var cone_height_m: float = 8.0
@export var cone_radius_m: float = 4.0


func _ready() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = cone_radius_m
	cyl.height = cone_height_m
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 24
	mesh = cyl
	var src := load(PresentationCatalog.CONE_MAT) as ShaderMaterial
	if src:
		material_override = src.duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Apex at local origin: cylinder is centred, shift down by half height.
	# Caller rotates +Y into the look direction.
	position.y = 0.0
	_apply()


func _apply() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("cone_height", cone_height_m)
	mat.set_shader_parameter("cone_radius", cone_radius_m)


## Place apex at `from_m` looking toward `to_m` on XZ. Length is cone_height_m.
func aim(from_m: Vector3, to_m: Vector3) -> void:
	var delta := to_m - from_m
	delta.y = 0.0
	var length := maxf(delta.length(), 0.5)
	cone_height_m = length
	## Visual shell, not the 90° data wedge (that would swallow the camera).
	cone_radius_m = length * 0.22
	if mesh is CylinderMesh:
		var cyl := mesh as CylinderMesh
		cyl.height = cone_height_m
		cyl.bottom_radius = cone_radius_m
	# Cylinder +Y is the apex (small radius). Point +Y back at the watcher so
	# the far disc sits on `to_m`.
	var look := delta.normalized()
	var y_axis := -look
	var x_axis := y_axis.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)
	transform = Transform3D(basis, from_m + look * (cone_height_m * 0.5))
	_apply()
