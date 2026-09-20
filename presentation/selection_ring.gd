extends MeshInstance3D
## Ground mark under the selected unit. Same for founder and everyone. Not a crown.
## Kept brighter / larger than the path tiles so it still reads on terrace slabs.


func _ready() -> void:
	var plane := PlaneMesh.new()
	## ~one cell (2 m) so it reads as “this body”, not a speck under the boots.
	plane.size = Vector2(2.0, 2.0)
	mesh = plane
	var src := load(PresentationCatalog.SELECT_MAT) as ShaderMaterial
	if src:
		var mat := src.duplicate() as ShaderMaterial
		## Paper tint vanished on light slabs; iron reads without becoming a faction colour.
		mat.set_shader_parameter("tint", Color(0.42, 0.38, 0.32, 1.0))
		mat.set_shader_parameter("alpha", 1.0)
		material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Sit above path chrome (path tiles are ~0.04 m).
	position.y = 0.08
