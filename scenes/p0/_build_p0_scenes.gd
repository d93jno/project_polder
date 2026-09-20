extends SceneTree
## Headless writer for P0 lighting tests. Regenerates flooded_roof.tscn and dry_street.tscn.
## Run: $HOME/bin/godot --headless --path . --script res://scenes/p0/_build_p0_scenes.gd

const CELL := 2.0
const EAVE_Y := 6.15
const WATER_FLOODED_Y := 2.40
const WATER_DRY_Y := -0.04
const BOAT_DRAFT := 0.50

const TERRACE := "res://assets/env/kits/terrace/"
const HERO := "res://assets/env/hero/"
const PROPS := "res://assets/props/"
const VEH := "res://assets/vehicles/"
const WORLDTEXT := "res://assets/worldtext/"
const TEX := TERRACE + "textures/"

# Camera rest (UI §2): 25° perspective, 90° snap (looks +X), elevated pitch that
# still reads dikes and roofs. Same transform in both scenes for A/B projection tests.
const CAM_EYE := Vector3(-24.0, 30.5, 2.0)
const CAM_LOOK := Vector3(8.0, 3.0, 2.0)
const CAM_FOV := 25.0


func _init() -> void:
	var err_f := _save_scene(_build("FloodedRoof", true), "res://scenes/p0/flooded_roof.tscn")
	var err_d := _save_scene(_build("DryStreet", false), "res://scenes/p0/dry_street.tscn")
	if err_f != OK or err_d != OK:
		push_error("P0 scene save failed flooded=%s dry=%s" % [err_f, err_d])
		quit(1)
		return
	print("wrote scenes/p0/flooded_roof.tscn and scenes/p0/dry_street.tscn")
	quit(0)


func _save_scene(root: Node, path: String) -> Error:
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		root.free()
		return pack_err
	var save_err := ResourceSaver.save(packed, path)
	root.free()
	return save_err


func _build(root_name: String, flooded: bool) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	root.editor_description = (
		"P0 lighting test. Dusk look A (high overcast). CameraTactical 25° perspective. "
		+ ("Flooded water at Y=2.4 (streets swim, roofs walkable)." if flooded
			else "Dry ground plane at street level. Long open sightline.")
	)

	_add_environment(root)
	_add_light(root)
	_add_camera(root)

	var kit := Node3D.new()
	kit.name = "Kit"
	_owned(root, kit)

	_add_street(kit, root)
	_add_curbs(kit, root)
	_add_canal(kit, root)
	_add_levee(kit, root)
	_add_houses(kit, root)
	_add_roofs_and_shanty(kit, root)
	_add_machines(kit, root)
	_add_pier_and_boat(kit, root, flooded)
	_add_cover(kit, root)
	_add_furniture(kit, root)
	_add_ridge(kit, root)
	_add_world_text(kit, root)
	_add_water_plane(root, flooded)
	return root


func _owned(owner: Node, child: Node, parent: Node = null) -> Node:
	if parent == null:
		parent = owner
	parent.add_child(child)
	child.owner = owner
	return child


func _inst(owner: Node, parent: Node, path: String, node_name: String, origin: Vector3, yaw_deg: float = 0.0, sc: Vector3 = Vector3.ONE) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("missing PackedScene %s" % path)
		var missing := Node3D.new()
		missing.name = node_name
		missing.position = origin
		return _owned(owner, missing, parent) as Node3D
	var n := packed.instantiate() as Node3D
	n.name = node_name
	n.transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_deg), 0.0)), origin)
	if sc != Vector3.ONE:
		n.scale = sc
	return _owned(owner, n, parent) as Node3D


func _add_environment(root: Node3D) -> void:
	# Dusk look A: high overcast, no golden hour (assets §5.2 / UI §7).
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.51, 0.58)
	sky_mat.sky_horizon_color = Color(0.68, 0.71, 0.74)
	sky_mat.ground_bottom_color = Color(0.20, 0.21, 0.19)
	sky_mat.ground_horizon_color = Color(0.55, 0.56, 0.53)
	sky_mat.sky_curve = 0.11
	sky_mat.sun_angle_max = 50.0
	sky_mat.energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.25
	env.ssao_intensity = 0.50
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.70, 0.74)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.40
	env.fog_sky_affect = 0.50
	env.glow_enabled = false

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_owned(root, we)


func _add_light(root: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.name = "LightDay"
	# High sun from the south, a few degrees off so shadows aren't a compass. Cool, not gold.
	light.rotation_degrees = Vector3(-74.0, 168.0, 0.0)
	light.light_color = Color(0.88, 0.91, 0.96)
	light.light_energy = 0.82
	light.light_indirect_energy = 0.70
	light.light_angular_distance = 1.8
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.5
	light.directional_shadow_max_distance = 140.0
	_owned(root, light)


func _add_camera(root: Node3D) -> void:
	var cam := Camera3D.new()
	cam.name = "CameraTactical"
	cam.transform = Transform3D(Basis.IDENTITY, CAM_EYE).looking_at(CAM_LOOK, Vector3.UP)
	cam.fov = CAM_FOV
	cam.near = 0.15
	cam.far = 400.0
	cam.current = true
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_owned(root, cam)


func _add_street(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Street"
	_owned(owner, group, kit)
	# Long east-west roadway. Two cells wide (4 m). Mix a/b/c.
	var paths := [
		TERRACE + "env_street_slab_a.glb",
		TERRACE + "env_street_slab_b.glb",
		TERRACE + "env_street_slab_c.glb",
	]
	var i := 0
	for x in range(-10, 24, 2):
		for z in [-2.0, 0.0]:
			var path: String = paths[(i + int(x) + int(z)) % 3]
			_inst(owner, group, path, "Slab_%d_%d" % [x, int(z)], Vector3(x, 0.0, z))
			i += 1
	# Paver sidewalk in front of the terrace (Z = 2).
	for x in range(-2, 24, 2):
		_inst(owner, group, TERRACE + "env_street_slab_b.glb", "Walk_%d" % x, Vector3(x, 0.0, 2.0))


func _add_curbs(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Curbs"
	_owned(owner, group, kit)
	# Curb lives on local −Z. 180° yaw puts it on the north edge of the Z=0 street cell.
	for x in range(-10, 24, 2):
		_inst(owner, group, TERRACE + "env_curb.glb", "CurbN_%d" % x, Vector3(x, 0.0, 0.0), 180.0)
	# South edge of the roadway, against the canal wall.
	for x in range(-10, 24, 2):
		_inst(owner, group, TERRACE + "env_curb.glb", "CurbS_%d" % x, Vector3(x, 0.0, -2.0), 0.0)


func _add_canal(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Canal"
	_owned(owner, group, kit)
	# Tall quay so Flooded (Y=2.4) still leaves a coping. Water-side is local −Z.
	# Leave X=-8 open for the pier land-end.
	for x in range(-10, 18, 2):
		if x == -8:
			continue
		_inst(owner, group, TERRACE + "env_canal_wall_tall.glb", "Quay_%d" % x, Vector3(x, 0.0, -4.0))
	# Sluice cuts the canal at the west end (channel along X after 90°).
	_inst(owner, group, TERRACE + "env_sluice_gauge.glb", "Sluice", Vector3(-12.0, 0.0, -4.0), 90.0)


func _add_levee(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Levee"
	_owned(owner, group, kit)
	# Far bank of the canal. Crest along X. Not dead-centre in the camera.
	for x in range(-10, 16, 2):
		_inst(owner, group, TERRACE + "env_levee_straight.glb", "Levee_%d" % x, Vector3(x, 0.0, -8.0))
	_inst(owner, group, TERRACE + "env_levee_outer_corner.glb", "LeveeOuterW", Vector3(-12.0, 0.0, -8.0), 180.0)
	_inst(owner, group, TERRACE + "env_levee_slope.glb", "LeveeSlopeE", Vector3(16.0, 0.0, -8.0), 0.0)
	_inst(owner, group, TERRACE + "env_levee_inner_corner.glb", "LeveeInnerE", Vector3(18.0, 0.0, -6.0), 0.0)
	_inst(owner, group, TERRACE + "env_levee_straight.glb", "LeveeN_%d" % 18, Vector3(18.0, 0.0, -4.0), 90.0)


func _add_houses(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Houses"
	_owned(owner, group, kit)
	# 2×2 cell shells, origins on even metres, street face local −Z (toward the road).
	_inst(owner, group, TERRACE + "env_house_2storey_a.glb", "HouseA", Vector3(0.0, 0.0, 6.0))
	_inst(owner, group, TERRACE + "env_house_2storey_b.glb", "HouseB", Vector3(4.0, 0.0, 6.0))
	_inst(owner, group, TERRACE + "env_house_2storey_c.glb", "HouseC", Vector3(8.0, 0.0, 6.0))
	_inst(owner, group, TERRACE + "env_house_2storey_d.glb", "HouseD", Vector3(12.0, 0.0, 6.0))
	# Interior plates sit at the same origin as the shell (cutaway later; present for height read).
	_inst(owner, group, TERRACE + "env_floor_interior_1.glb", "Floor1_B", Vector3(4.0, 0.0, 6.0))
	_inst(owner, group, TERRACE + "env_floor_interior_2.glb", "Floor2_B", Vector3(4.0, 0.0, 6.0))
	# Ladder on House A street face, scaled to two storeys (MANIFEST).
	_inst(owner, group, TERRACE + "env_ladder.glb", "LadderA", Vector3(0.0, 0.0, 3.88), 180.0, Vector3(1.0, 2.0, 1.0))
	# One-storey stair in the alley between House D and the pump.
	_inst(owner, group, TERRACE + "env_stair.glb", "StairAlley", Vector3(16.0, 0.0, 3.0), 180.0)


func _add_roofs_and_shanty(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Roofs"
	_owned(owner, group, kit)
	# Walkable decks at eave height. Shanty snaps to the deck (local Y=0).
	_inst(owner, group, TERRACE + "env_roof_deck_a.glb", "RoofDeckB", Vector3(4.0, EAVE_Y, 6.0))
	_inst(owner, group, TERRACE + "env_roof_deck_b.glb", "RoofDeckC", Vector3(8.0, EAVE_Y, 6.0))
	_inst(owner, group, TERRACE + "env_shanty_tarp.glb", "ShantyTarp", Vector3(3.6, EAVE_Y, 5.4))
	_inst(owner, group, TERRACE + "env_shanty_pallet_wall.glb", "ShantyPallet", Vector3(8.6, EAVE_Y, 5.2), 0.0)
	_inst(owner, group, TERRACE + "env_hatch.glb", "HatchB", Vector3(4.4, EAVE_Y, 6.5))
	_inst(owner, group, TERRACE + "env_shanty_plot_box.glb", "PlotBoxC", Vector3(7.2, EAVE_Y, 6.8))


func _add_machines(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Machines"
	_owned(owner, group, kit)
	var pump := _inst(owner, group, TERRACE + "env_pump_house.glb", "PumpHouse", Vector3(20.0, 0.0, 6.0))
	var dress := pump.find_child("dressing_damaged", true, false)
	if dress:
		dress.visible = false
		dress.owner = owner


func _add_pier_and_boat(kit: Node3D, owner: Node, flooded: bool) -> void:
	var group := Node3D.new()
	group.name = "Extract"
	_owned(owner, group, kit)
	# Pier 1×3 cells, long axis along Z after export. Land end at the quay, water end south.
	_inst(owner, group, TERRACE + "env_pier.glb", "Pier", Vector3(-8.0, 0.0, -6.0), 0.0)
	var boat_y := (WATER_FLOODED_Y - BOAT_DRAFT) if flooded else 0.0
	# Bow is −Z. Parked along the pier, offset one cell west.
	_inst(owner, group, VEH + "veh_boat_camp.glb", "BoatCamp", Vector3(-10.6, boat_y, -6.2), 0.0)


func _add_cover(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Cover"
	_owned(owner, group, kit)
	# Street cover for the Dry sightline; same nodes in Flooded (underwater) so A/B stays honest.
	_inst(owner, group, PROPS + "prop_crate_wood.glb", "CrateStreet", Vector3(6.4, 0.0, 0.6), 15.0)
	_inst(owner, group, PROPS + "prop_plank_wood.glb", "PlankStreet", Vector3(10.2, 0.0, -0.7), -20.0)
	_inst(owner, group, PROPS + "prop_cover_masonry_corner.glb", "MasonryCorner", Vector3(14.2, 0.0, 3.2), 90.0)
	# Roof-deck crate so Flooded still has a named blocker on a walkable roof.
	_inst(owner, group, PROPS + "prop_crate_wood.glb", "CrateRoof", Vector3(5.1, EAVE_Y, 6.7), -30.0)


func _add_furniture(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "Furniture"
	_owned(owner, group, kit)
	_inst(owner, group, TERRACE + "env_furn_lamp.glb", "Lamp_0", Vector3(-2.0, 0.0, 1.15), 180.0)
	_inst(owner, group, TERRACE + "env_furn_lamp.glb", "Lamp_8", Vector3(8.0, 0.0, 1.15), 180.0)
	_inst(owner, group, TERRACE + "env_furn_lamp.glb", "Lamp_16", Vector3(16.0, 0.0, 1.15), 180.0)
	_inst(owner, group, TERRACE + "env_furn_bollard.glb", "BollardPierA", Vector3(-7.3, 0.0, -3.4))
	_inst(owner, group, TERRACE + "env_furn_bollard.glb", "BollardPierB", Vector3(-8.7, 0.0, -3.4))
	_inst(owner, group, TERRACE + "env_furn_bench.glb", "Bench", Vector3(2.0, 0.0, 1.35), 180.0)
	_inst(owner, group, TERRACE + "env_furn_rail.glb", "RailQuay", Vector3(0.0, 0.0, -4.0))


func _add_ridge(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "FarField"
	_owned(owner, group, kit)
	# Horizon object, offset left of the +X vanishing point. No nameplate.
	_inst(owner, group, HERO + "env_ridge_farfield.glb", "Ridge", Vector3(52.0, 0.0, 18.0), 18.0)


func _add_world_text(kit: Node3D, owner: Node) -> void:
	var group := Node3D.new()
	group.name = "WorldText"
	_owned(owner, group, kit)
	# Pump ON plate on the street face (blank iron plate is at local z ≈ -1.77, y ≈ 2.80).
	_quad(
		owner, group, "PlatePumpHeld",
		WORLDTEXT + "worldtext_pump_held.png",
		Vector2(1.10, 0.50),
		Vector3(20.0, 2.80, 4.16),
		180.0,
	)
	# Painted waterline on House D street face. Image centre is the brush band = Flooded height.
	_quad(
		owner, group, "WaterlinePaint",
		WORLDTEXT + "worldtext_waterline_paint.png",
		Vector2(3.6, 1.8),
		Vector3(12.0, WATER_FLOODED_Y, 3.96),
		180.0,
	)
	# Terrace grade mark on the far-bank levee (own-bowl, no ring).
	_quad(
		owner, group, "PlateGradeTerrace",
		WORLDTEXT + "worldtext_grade_terrace.png",
		Vector2(1.20, 0.60),
		Vector3(4.0, 1.55, -7.35),
		180.0,
	)
	# Dirt waterline decal on House A (horizontal stain, not HUD).
	var decal := Decal.new()
	decal.name = "DecalWaterlineDirt"
	decal.texture_albedo = load("res://assets/env/decals/env_decal_waterline_dirt.png") as Texture2D
	decal.size = Vector3(4.0, 0.8, 0.55)
	decal.position = Vector3(0.0, WATER_FLOODED_Y, 3.95)
	decal.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	decal.cull_mask = 0xFFFFF
	_owned(owner, decal, group)


func _quad(owner: Node, parent: Node, node_name: String, tex_path: String, size: Vector2, origin: Vector3, yaw_deg: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(tex_path) as Texture2D
	mat.roughness = 0.86
	mat.metallic = 0.02
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_deg), 0.0)), origin)
	_owned(owner, mi, parent)


func _add_water_plane(root: Node3D, flooded: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "WaterPlane"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(96.0, 80.0)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 20
	mi.mesh = mesh
	var y := WATER_FLOODED_Y if flooded else WATER_DRY_Y
	mi.position = Vector3(12.0, y, 0.0)
	var src := load("res://assets/shaders/water.tres") as ShaderMaterial
	if src:
		var mat := src.duplicate() as ShaderMaterial
		mat.set_shader_parameter("step", 0 if flooded else 3)
		mat.set_shader_parameter("water_height", y)
		mat.set_shader_parameter("displace_to_height", false)
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_owned(root, mi)
