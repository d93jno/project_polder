extends MeshInstance3D
## Ground mark under a unit. Same for founder and everyone. Not a crown.


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.4, 1.4)
	mesh = plane
	var src := load(PresentationCatalog.SELECT_MAT) as ShaderMaterial
	if src:
		material_override = src.duplicate()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = 0.04
