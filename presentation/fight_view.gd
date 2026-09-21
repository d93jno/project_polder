extends Node3D
## Draws CombatState with the art. Commands are the rules layer; this node only applies
## what validate() already priced and redraws the result.

const _BowlDraw := preload("res://presentation/bowl_draw.gd")
const _UnitView := preload("res://presentation/unit_view.gd")
const _ConeView := preload("res://presentation/watch_cone_view.gd")
const _Select := preload("res://presentation/selection_ring.gd")
const _Hud := preload("res://presentation/hud.gd")
const _Water := preload("res://presentation/water_plane.gd")
const _FogView := preload("res://presentation/fog_view.gd")
const _CameraRig := preload("res://presentation/camera_rig.gd")
const _Queries := preload("res://presentation/overlay_queries.gd")
const _Picking := preload("res://presentation/picking.gd")
const _WallFade := preload("res://presentation/wall_fade.gd")
const _MINT_3D := preload("res://presentation/mint_key_3d.gdshader")
const _ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")
const _FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
const _TerraceStamps := preload("res://presentation/fixtures/flooded_terrace_stamps.gd")

const _NAMES := {
	1: "Piet",
	2: "Jan",
	3: "Els",
	4: "Kees",
}
const _INVALID := Vector3i(999, 999, 999)
## env_ridge_farfield.glb is 80 x 34.3 m. Yawed 90° its depth (34.3) runs along +X.
const _RIDGE_HALF_DEPTH_M := 17.2
const _RIDGE_GAP_M := 4.0
## Hit pips sit at 1.95 m with their count above; the exposure word must clear them.
const _EXPOSURE_LABEL_Y := 2.85
## F cycles Flooded → Falling → Mud → Dry (plan 3.4).
const _WATER_CYCLE := [
	Taxonomy.WaterStep.FLOODED,
	Taxonomy.WaterStep.FALLING,
	Taxonomy.WaterStep.MUD,
	Taxonomy.WaterStep.DRY,
]

var _state: CombatState
var _bowl_id: String = "street"
var _stamps: Array = []
var _selected_id: int = 1
var _hover: Vector3i = Vector3i.ZERO
var _camera: Camera3D
var _hud
var _bowl
var _water
var _fog
var _units_root: Node3D
var _cones_root: Node3D
var _preview_root: Node3D
var _select_ring
var _dock_cells: Dictionary = {} ## cells under a piece that rides the water
var _player_ids: Array[int] = []
var _cutaway_z: int = 99
var _max_z: int = 0
var _queries
var _labels_root: Node3D
var _wall_fade
var _confirm_target_id: int = -1


func _ready() -> void:
	_bowl_id = _parse_bowl_arg()
	_state = _opening()
	## Prior visits seed Known-quiet; opening peel makes the start Live (plan 04 §4.6 / §4.4).
	KnowledgeStore.load_from().begin_fight(_state, _bowl_id)
	_state.knowledge.peel(_state.map, _state)
	_stamps = _stamps_for_bowl()
	_dock_cells = PresentationCatalog.dock_cells(_stamps)
	_player_ids = _ids_of(Taxonomy.Faction.PLAYER)
	_selected_id = _player_ids[0] if not _player_ids.is_empty() else 1
	_build_world()
	_redraw()
	_hud.set_note(
		"click walk until contact · shoot · Q Watch · Space phase · Tab select · F water step · Esc cancel · [ ] yaw · wheel zoom · MMB peek"
	)


func _parse_bowl_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bowl="):
			return arg.substr("--bowl=".length())
	return "street"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell()
		if cell != _INVALID:
			_click_cell(cell)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_end_phase()
				get_viewport().set_input_as_handled()
			KEY_Q:
				_try_watch()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_cycle_selected()
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				_set_cutaway(_cutaway_z + 1)
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN:
				_set_cutaway(_cutaway_z - 1)
				get_viewport().set_input_as_handled()
			KEY_F:
				## Four-step water cycle on the shared BowlMap (plan 3.4 / UI §3).
				_cycle_water_step()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _confirm_target_id != -1:
					_confirm_target_id = -1
					_hud.set_note("")
					_redraw()
					get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	var cell := _pick_cell()
	if cell != _hover and cell != _INVALID:
		_hover = cell
		_refresh_queries()
		_draw_cones()
		_draw_preview()
		_draw_overlay_labels()
		_sync_hud()
	_tick_wall_fade(dt)


func _opening() -> CombatState:
	## Shared fixtures: street (2.6) or terrace (3.3). View never rebuilds the map.
	if _bowl_id == "terrace":
		return _FloodedTerrace.opening(Taxonomy.WaterStep.FLOODED)
	return _ScriptedFight.opening()


func _stamps_for_bowl() -> Array:
	if _bowl_id == "terrace":
		return _TerraceStamps.stamps()
	return _ScriptedFight.stamps()


func _look_at_for_bowl() -> Vector3:
	if _bowl_id == "terrace":
		## Between the squad on the canal and the terrace run, so the opening frame holds the
		## squad, the stair, the roof body and the levee rifle. Centred on the canal's far end, the
		## squad (and the pier) fell below the bottom edge of the frame.
		return PresentationCoords.world(Vector3i(5, 4, 0)) + Vector3(0.0, 2.0, 0.0)
	return PresentationCoords.world(Vector3i(8, 3, 0)) + Vector3(0.0, 1.5, 0.0)


func _build_world() -> void:
	_add_environment()
	_bowl = _BowlDraw.new()
	_bowl.name = "Bowl"
	add_child(_bowl)
	_draw_bowl()
	_max_z = _map_max_z(_state.map)
	_cutaway_z = _max_z
	_bowl.set_cutaway_z(_cutaway_z)

	_water = _Water.new()
	_water.name = "Water"
	add_child(_water)
	_water.fit_map(_state.map)
	_sync_water_from_map()

	_fog = _FogView.new()
	_fog.name = "Fog"
	add_child(_fog)

	var ridge := (load("res://assets/env/hero/env_ridge_farfield.glb") as PackedScene).instantiate()
	ridge.name = "Ridge"
	(ridge as Node3D).position = _ridge_position(_state.map)
	## Its 80 m axis runs across the street so it reads as a horizon, not a slab.
	(ridge as Node3D).rotation_degrees.y = 90.0
	add_child(ridge)

	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)
	_cones_root = Node3D.new()
	_cones_root.name = "Cones"
	add_child(_cones_root)
	_preview_root = Node3D.new()
	_preview_root.name = "Preview"
	add_child(_preview_root)
	_labels_root = Node3D.new()
	_labels_root.name = "OverlayLabels"
	add_child(_labels_root)

	_select_ring = _Select.new()
	_select_ring.name = "Selection"
	add_child(_select_ring)

	_hud = _Hud.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.slot_pressed.connect(_on_slot)
	_hud.end_phase_pressed.connect(_end_phase)

	_wall_fade = _WallFade.new()
	_wall_fade.name = "WallFade"
	add_child(_wall_fade)

	var names := PackedStringArray()
	for id in _player_ids:
		names.append(_NAMES.get(id, "Unit %d" % id))
	_hud.set_fireteam(names)


## Far-field ridge sits past the street's far end (+X, where the camera looks), never over
## the tiles. Sideways offset keeps it off dead-centre (assets brief: not framed centre).
func _ridge_position(map: BowlMap) -> Vector3:
	var max_x := 0
	var sum_y := 0.0
	for coord in map.cells.keys():
		max_x = maxi(max_x, coord.x)
		sum_y += coord.y
	var mid_z := (sum_y / float(maxi(map.cells.size(), 1))) * PresentationCoords.CELL_M
	var edge_x := (float(max_x) + 0.5) * PresentationCoords.CELL_M
	return Vector3(edge_x + _RIDGE_GAP_M + _RIDGE_HALF_DEPTH_M, 0.0, mid_z - 8.0)


func _add_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.51, 0.58)
	sky_mat.sky_horizon_color = Color(0.58, 0.61, 0.63)
	## Empty cells must not read as a white table. Wet silt, thin ground band.
	sky_mat.ground_bottom_color = Color(0.07, 0.08, 0.07)
	sky_mat.ground_horizon_color = Color(0.16, 0.17, 0.16)
	sky_mat.ground_curve = 0.12
	sky_mat.sky_curve = 0.09
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.20, 0.20)
	env.fog_density = 0.008
	env.fog_aerial_perspective = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.name = "LightDay"
	light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	light.light_energy = 1.05
	light.light_color = Color(0.92, 0.94, 0.96)
	add_child(light)

	var rig = _CameraRig.new()
	rig.name = "CameraRig"
	rig.look_at_point = _look_at_for_bowl()
	add_child(rig)
	_camera = rig.ensure_camera()


func _redraw() -> void:
	_draw_bowl()
	_draw_fog()
	_refresh_queries()
	_draw_units()
	_draw_cones()
	_draw_preview()
	_draw_overlay_labels()
	_sync_hud()
	var sel: Unit = _state.get_unit(_selected_id)
	if sel and _select_ring:
		var show_ring := not sel.extracted and sel.cell.z <= _cutaway_z
		_select_ring.visible = show_ring
		## Match selection_ring's own lift so path tiles do not bury it.
		_select_ring.position = _ground(sel.cell) + Vector3(0, 0.08, 0)


func _draw_bowl() -> void:
	if _bowl == null:
		return
	## Known-quiet ∪ Live only — Unknown draws nothing (plan 04 §4.4).
	var known := _state.knowledge.known_cells(_state)
	_bowl.draw_map(_state.map, _stamps, known)
	_bowl.set_cutaway_z(_cutaway_z)


func _draw_fog() -> void:
	if _fog == null:
		return
	if _water != null:
		_fog.reduced_motion = _water.reduced_motion
	_fog.redraw(_state.map, _state)


func _refresh_queries() -> void:
	_queries = _Queries.compute(_state.map, _state, _selected_id, _hover)


func _draw_units() -> void:
	for c in _units_root.get_children():
		c.queue_free()
	for u in _state.all_units():
		if not _actor_visible(u):
			continue
		var view := _UnitView.new()
		view.name = "U%d" % u.id
		_units_root.add_child(view)
		view.bind_unit(u, _state.live_watch_for(u.id) != null, _body_origin(u))
		var loco := _locomotion_clip(u)
		if loco != "":
			view.play(loco)
		## Cutaway hides floors above N; units on those floors hide with them.
		## Tab / fireteam still select a roof unit while the street cutaway is up.
		view.visible = view.visible and u.cell.z <= _cutaway_z
		if view.visible and not u.extracted and not u.dead:
			_spawn_hit_pips(view, u)


## Squad always drawn. Other actors only on Live cells — reveal is not arrival (UI §6).
func _actor_visible(u: Unit) -> bool:
	if u.extracted:
		return false
	if u.faction == Taxonomy.Faction.PLAYER:
		return true
	return (
		_state.knowledge != null
		and _state.knowledge.squad_sight(_state, u.cell) == Knowledge.CellSight.LIVE
	)


func _draw_cones() -> void:
	for c in _cones_root.get_children():
		c.queue_free()
	if _queries == null:
		return
	for entry in _queries.watches:
		var cells: Array = entry["cells"]
		if cells.is_empty():
			continue
		var from_cell: Vector3i = entry["cell"]
		var facing: Vector3i = entry["facing"]
		var far := _farthest_in_facing(from_cell, facing, cells)
		var view := _ConeView.new()
		if entry["friendly"]:
			view.mode = 1 if entry["full_volume"] else 0
		elif entry["apex_known"]:
			view.mode = 1
		else:
			view.mode = 2
		_cones_root.add_child(view)
		view.aim(
			_unit_origin(from_cell) + Vector3(0, 1.4, 0),
			_ground(far) + Vector3(0, 1.4, 0)
		)


## Tip of the drawn shell: down the facing axis, as far as the wedge reaches. The wedge's
## far edge is a row of cells; picking one of them would skew the shell sideways.
func _farthest_in_facing(from_cell: Vector3i, facing: Vector3i, cells: Array) -> Vector3i:
	var reach := 1
	for c in cells:
		var cell: Vector3i = c
		reach = maxi(reach, (cell.x - from_cell.x) * facing.x + (cell.y - from_cell.y) * facing.y)
	return from_cell + Vector3i(facing.x, facing.y, 0) * reach


func _draw_preview() -> void:
	for c in _preview_root.get_children():
		c.queue_free()
	if _queries == null:
		return
	var unit: Unit = _state.get_unit(_selected_id)
	if unit == null or not unit.is_active():
		return
	if _queries.hover_hostile:
		var occ := _unit_at(_hover)
		if occ != null and _queries.los != null:
			_draw_shot_line(
				_unit_origin(unit.cell) + Vector3(0, 1.2, 0),
				_unit_origin(occ.cell) + Vector3(0, 1.2, 0),
				_queries.los.clean
			)
		return
	var path = _queries.path
	if not path.reachable:
		return
	for i in path.cells.size():
		var cell: Vector3i = path.cells[i]
		if i > 0:
			_mark_path_tile(cell)
		if i > 0 and i < path.cost_per_cell.size() and path.cost_per_cell[i] != 1:
			_spawn_preview_label(
				_ground(cell) + Vector3(-0.55, 0.45, 0.0),
				str(path.cost_per_cell[i]),
				0.011
			)
		if i == path.shot_reserve_at:
			_spawn_mint_sprite(
				_ground(cell) + Vector3(0.0, 0.12, 0.0),
				PresentationCatalog.UI_HUD + "ui_path_reserve_shot.png",
				Vector2(0.9, 0.9),
				true,
				0.9
			)
		if i == path.watch_reserve_at:
			_spawn_mint_sprite(
				_ground(cell) + Vector3(0.0, 0.14, 0.0),
				PresentationCatalog.UI_HUD + "ui_path_reserve_watch.png",
				Vector2(0.9, 0.9),
				true,
				0.9
			)
	for crossing in path.watches_crossed:
		var xc: WatchCrossing = crossing
		if xc.cell.z > _cutaway_z:
			continue
		_spawn_preview_label(
			_ground(xc.cell) + Vector3(0.0, 0.9, 0.0),
			_Queries.crossing_label(xc),
			0.01
		)


func _mark_path_tile(cell: Vector3i) -> void:
	_spawn_mint_sprite(
		_ground(cell) + Vector3(0.0, 0.04, 0.0),
		PresentationCatalog.UI_HUD + "ui_path_tile.png",
		Vector2(1.55, 1.55),
		true,
		0.32
	)


func _draw_shot_line(from_m: Vector3, to_m: Vector3, clean: bool) -> void:
	var delta := to_m - from_m
	var length := delta.length()
	if length < 0.05:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.04, 0.08)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	var tex := load(
		PresentationCatalog.UI_HUD + ("ui_line_clean.png" if clean else "ui_line_blocked.png")
	) as Texture2D
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.uv1_scale = Vector3(maxi(1.0, length / 2.0), 1.0, 1.0)
	mi.material_override = mat
	mi.position = (from_m + to_m) * 0.5
	mi.look_at_from_position(mi.position, to_m, Vector3.UP)
	## BoxMesh extends on local X after look_at points -Z; rotate to lay along the line.
	mi.rotate_object_local(Vector3.UP, PI * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_root.add_child(mi)


func _spawn_mint_sprite(
	origin: Vector3, tex_path: String, size: Vector2, flat: bool = false, alpha: float = 1.0
) -> void:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = _MINT_3D
	mat.set_shader_parameter("albedo_tex", load(tex_path))
	mat.set_shader_parameter("alpha_mul", alpha)
	mi.material_override = mat
	mi.position = origin
	if not flat:
		mi.rotation_degrees.x = -90.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_root.add_child(mi)


func _spawn_hit_pips(parent: Node3D, u: Unit) -> void:
	## Both sides: hit pips on the body (UI §4.3).
	var max_hp := RulesConstants.HP_PIPS
	var row := Node3D.new()
	row.name = "HitPips"
	row.position = Vector3(0.0, 1.95, 0.0)
	parent.add_child(row)
	var gap := 0.3
	var start_x := -0.5 * gap * float(max_hp - 1)
	for i in max_hp:
		var mi := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(0.24, 0.24)
		mi.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = _MINT_3D
		mat.set_shader_parameter("albedo_tex", load(PresentationCatalog.UI_THEME + "ui_pip_hit.png"))
		mat.set_shader_parameter("alpha_mul", 1.0 if i < u.hp else 0.22)
		mi.material_override = mat
		mi.position = Vector3(start_x + gap * float(i), 0.0, 0.0)
		mi.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		row.add_child(mi)
	var label := Label3D.new()
	label.text = "%d/%d" % [u.hp, max_hp]
	label.font_size = 28
	label.pixel_size = 0.008
	label.position = Vector3(0.0, 0.32, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.94, 0.9, 0.8, 0.95)
	row.add_child(label)


func _click_cell(cell: Vector3i) -> void:
	var occupant := _unit_at(cell)
	if occupant != null and occupant.faction == Taxonomy.Faction.PLAYER:
		_confirm_target_id = -1
		_selected_id = occupant.id
		_redraw()
		return
	var actor: Unit = _state.get_unit(_selected_id)
	if actor == null:
		return
	if occupant != null and CombatState.is_hostile(actor.faction, occupant.faction):
		var los := Los.line_of_sight(_state.map, actor.cell, occupant.cell, actor.weapon)
		if los.clean and occupant.bleeding:
			if _confirm_target_id == occupant.id:
				_confirm_target_id = -1
				_try(ShootCommand.new(actor.id, occupant.id))
			else:
				_confirm_target_id = occupant.id
				_hud.set_note("confirm: kills a bleeder — click again · Esc cancels")
				_redraw()
			return
		_confirm_target_id = -1
		_try(ShootCommand.new(actor.id, occupant.id))
		return
	_confirm_target_id = -1
	if _state.in_contact:
		_try(MoveCommand.new(actor.id, cell))
	else:
		_try(FreeMoveCommand.new(actor.id, cell))


func _try_watch() -> void:
	var actor: Unit = _state.get_unit(_selected_id)
	if actor == null:
		return
	var face := PresentationCoords.cardinal_toward(actor.cell, _hover)
	_try(WatchCommand.new(actor.id, face))


func _try(cmd: Command) -> void:
	var check := cmd.validate(_state)
	if not check.ok:
		_hud.set_note(check.reason)
		return
	_state = cmd.apply(_state)
	_hud.set_note("")
	_redraw()


func _end_phase() -> void:
	if not _state.in_contact:
		_hud.set_note("no End Turn until contact")
		return
	_state = _state.end_phase()
	if _state.active_side == CombatState.PhaseSide.ENEMY:
		_run_enemy_phase()
	_redraw()


func _run_enemy_phase() -> void:
	var guard := 16
	while _state.active_side == CombatState.PhaseSide.ENEMY and guard > 0:
		guard -= 1
		var shot := false
		for enemy in _state.units_on_side(CombatState.PhaseSide.ENEMY):
			if not enemy.is_active():
				continue
			for player in _state.units_of_faction(Taxonomy.Faction.PLAYER):
				if not player.is_active() and not player.bleeding:
					continue
				var cmd := ShootCommand.new(enemy.id, player.id)
				if cmd.validate(_state).ok:
					_state = cmd.apply(_state)
					shot = true
					break
			if shot:
				break
		if not shot:
			_state = _state.end_phase()
			break


func _cycle_selected() -> void:
	if _player_ids.is_empty():
		return
	var i := _player_ids.find(_selected_id)
	_selected_id = _player_ids[(i + 1) % _player_ids.size()]
	_redraw()


func _on_slot(index: int) -> void:
	if index >= 0 and index < _player_ids.size():
		_selected_id = _player_ids[index]
		_redraw()


func _sync_hud() -> void:
	if _hud == null:
		return
	var u: Unit = _state.get_unit(_selected_id)
	if u == null:
		return
	if _queries == null:
		_refresh_queries()
	_hud.set_selected(_player_ids.find(_selected_id))
	_hud.set_ap(u.ap, RulesConstants.AP_POOL)
	_hud.set_hits(u.hp, RulesConstants.HP_PIPS)
	_hud.set_bleed_rounds(u.bleed_rounds_left if u.bleeding else 0)
	var exp = _queries.exposure
	match exp.state:
		Exposure.State.HIDDEN:
			_hud.set_exposure("hidden")
		Exposure.State.NO_HIDE:
			_hud.set_exposure("no_hide")
		_:
			_hud.set_exposure("exposed")
	match u.pin:
		Unit.PinState.DUCKED:
			_hud.set_pin("ducked")
		Unit.PinState.DUCKING_NEXT:
			_hud.set_pin("ducking_next")
		_:
			_hud.set_pin("none")
	var live := _state.live_watch_for(u.id)
	_hud.set_watch_spent(live == null or live.spent)
	_hud.set_phase_yours(_state.active_side == CombatState.PhaseSide.PLAYER)
	var br := BreakRule.check(_state.map, _state, u)
	var break_txt := ""
	match br:
		BreakRule.Result.BREAKS:
			break_txt = "breaks"
		BreakRule.Result.WOULD_BREAK_IF_PINNED:
			break_txt = "if hit here, breaks"
	var hover_txt := "cell %s" % _hover
	if _state.map.has_cell(_hover):
		hover_txt += "  %s" % _cover_name_at(_hover)
	if _queries.cover_stops_label != "":
		hover_txt += "  %s" % _queries.cover_stops_label
	if _queries.hover_hostile and _queries.shot_outcome != "":
		hover_txt += "  %s" % _queries.shot_outcome
		hover_txt += "  cost %d" % _queries.shot_cost
		if not _queries.shot_affordable:
			hover_txt += "  unaffordable"
	if _confirm_target_id != -1:
		hover_txt += "  CONFIRM kills a bleeder"
	var step_name := str(Taxonomy.WaterStep.keys()[_state.map.water_step])
	## Exposure word lives on the body (plan 3.5); HUD carries count and sources.
	var bits: Array[String] = [
		hover_txt,
		"z %d" % u.cell.z,
		"cutaway %d" % _cutaway_z,
		step_name,
	]
	if exp.count > 0:
		bits.append("seen by %d" % exp.count)
	if not exp.sources.is_empty():
		var src_bits: Array[String] = []
		for s in exp.sources:
			var tag := "(%d,%d)" % [s.x, s.y]
			var gun := _hostile_at(s)
			if gun != null and gun.broken:
				tag += " brk"
			src_bits.append(tag)
		bits.append("from %s" % ", ".join(src_bits))
	elif exp.count > 0:
		## Count without sources: still name broken guns among attackers (plan 3.5).
		var brk := 0
		for a in _state.attackers_of(_state.map, u):
			if a.broken:
				brk += 1
		if brk > 0:
			bits.append("%d broken still a gun" % brk)
	if _queries.stack_label != "":
		bits.append(_queries.stack_label)
	if break_txt != "":
		bits.append(break_txt)
	_hud.set_height_read("  ".join(bits))


func _draw_overlay_labels() -> void:
	if _labels_root == null:
		return
	for c in _labels_root.get_children():
		c.queue_free()
	if _queries == null:
		return
	var sel: Unit = _state.get_unit(_selected_id)
	if sel != null and sel.is_active() and sel.cell.z <= _cutaway_z:
		## Word only on the body; count/sources live in the HUD (plan 3.5).
		_spawn_label(
			_unit_origin(sel.cell) + Vector3(0.0, _EXPOSURE_LABEL_Y, 0.0),
			_Queries.exposure_word(_queries.exposure),
			0.011
		)
	## Broken hostiles that still count as guns — draw the fact, don't hide it (plan 3.5).
	if sel != null and sel.is_active():
		for hostile in _state.attackers_of(_state.map, sel):
			if not hostile.broken or hostile.cell.z > _cutaway_z:
				continue
			_spawn_label(
				_unit_origin(hostile.cell) + Vector3(0.0, 2.4, 0.0),
				"broken · still a gun",
				0.01
			)
	## Cone weapon / long words near the far tip of each drawn watch.
	for entry in _queries.watches:
		var cells: Array = entry["cells"]
		if cells.is_empty():
			continue
		var far := _farthest_in_facing(entry["cell"], entry["facing"], cells)
		if far.z > _cutaway_z:
			continue
		_spawn_label(
			_ground(far) + Vector3(0.0, 1.8, 0.0),
			entry["label"],
			0.012
		)
	if _queries.stack_label != "" and _state.map.has_cell(_hover) and _hover.z <= _cutaway_z:
		_spawn_label(
			_ground(_hover) + Vector3(0.0, 1.1, 0.0),
			_queries.stack_label,
			0.011
		)
	## Path exposure: only when the word *changes from the unit's current read*.
	## The selected body already says "exposed"; don't repeat it down the lane.
	if _queries.path.reachable:
		var prev := _Queries.exposure_word(_queries.exposure)
		for i in _queries.path.exposure_per_cell.size():
			var cell: Vector3i = _queries.path.cells[i]
			if cell.z > _cutaway_z:
				continue
			var exp: Exposure = _queries.path.exposure_per_cell[i]
			var word := _Queries.exposure_word(exp)
			if word == prev:
				continue
			prev = word
			_spawn_label(
				_ground(cell) + Vector3(0.0, 0.55, 0.0),
				word,
				0.01
			)


func _hostile_at(cell: Vector3i) -> Unit:
	for u in _state.all_units():
		if u.cell == cell and u.is_active() and CombatState.is_hostile(
			_state.get_unit(_selected_id).faction if _state.get_unit(_selected_id) else Taxonomy.Faction.PLAYER,
			u.faction
		):
			return u
	return null


func _spawn_label(origin: Vector3, text: String, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.modulate = Color(0.94, 0.9, 0.8, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = origin
	label.pixel_size = pixel
	label.outline_size = 4
	_labels_root.add_child(label)


func _spawn_preview_label(origin: Vector3, text: String, pixel: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.modulate = Color(0.94, 0.9, 0.8, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = origin
	label.pixel_size = pixel
	label.outline_size = 4
	_preview_root.add_child(label)


func _unit_at(cell: Vector3i) -> Unit:
	for u in _state.all_units():
		if u.cell == cell and not u.extracted and not u.dead and _actor_visible(u):
			return u
	return null


## Prefer the catalog tag on the drawn mesh; fall back to the cell material.
func _cover_name_at(cell: Vector3i) -> String:
	if _bowl != null:
		var tag: int = _bowl.cover_tag_at(cell)
		if tag >= 0:
			return Taxonomy.material_name(tag as Taxonomy.CoverMaterial)
	if _state.map.has_cell(cell):
		return Taxonomy.material_name(_state.map.get_cell(cell).material)
	return "?"


func _pick_cell() -> Vector3i:
	if _camera == null:
		return _INVALID
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return _INVALID
	## A body is a standing volume, not a point on the floor: pick it first, or a click on an
	## enemy's torso lands on the tile behind their feet (a move instead of a shot).
	var body := _Picking.body_under_ray(_state, _cutaway_z, origin, dir, _body_origin)
	if not body.is_empty() and not _actor_visible(body["unit"] as Unit):
		body = {}
	## Ray vs each open level's play plane, so roof tiles pick when that level is open and a
	## swimmer's tile picks where it is drawn: on the water surface, not the street below it.
	var step := _state.map.water_step
	var water_z := _state.map.water_z
	var hit := _Picking.cell_under_ray(
		_state.map, _cutaway_z, origin, dir,
		func(z: int) -> float: return PresentationCoords.play_y(z, step, water_z),
		_dock_decks()
	)
	if not hit.is_empty():
		## A floor between the camera and the body (roof over a street unit) wins.
		if not body.is_empty() and float(body["t"]) < float(hit["t"]):
			return (body["unit"] as Unit).cell
		return hit["cell"]
	if not body.is_empty():
		return (body["unit"] as Unit).cell
	return _INVALID


func _set_cutaway(level: int) -> void:
	_cutaway_z = clampi(level, 0, _max_z)
	if _bowl:
		_bowl.set_cutaway_z(_cutaway_z)
	_redraw()


## Where overlays for a cell sit: on the floor, or on the water surface where a body would float
## (UI 3). Everything the player points at is drawn on the plane a click resolves on.
func _ground(cell: Vector3i) -> Vector3:
	return PresentationCoords.world_play(
		cell, _state.map.water_step, _state.map.water_z, _dock_cells.has(cell)
	)


## Where a body's origin goes: on the floor, or a draft below the surface while it floats. The
## draft follows the pose the unit is drawn in: prone when swimming, standing when treading.
func _body_origin(u: Unit) -> Vector3:
	return PresentationCoords.unit_origin(
		u.cell, _state.map.water_step, _state.map.water_z,
		_locomotion_clip(u) == "swim", _dock_cells.has(u.cell)
	)


## Anchor for a label or line on whoever stands in `cell`, when only the cell is known.
func _unit_origin(cell: Vector3i) -> Vector3:
	return PresentationCoords.unit_origin(
		cell, _state.map.water_step, _state.map.water_z, false, _dock_cells.has(cell)
	)


## Dock cell -> Y of its deck, for picking.
func _dock_decks() -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in _dock_cells.keys():
		out[cell] = PresentationCoords.dock_deck_y(cell.z, _state.map.water_step, _state.map.water_z)
	return out


func _sync_water_from_map() -> void:
	if _water == null:
		return
	_water.water_step = int(_state.map.water_step)
	_water.water_height_m = PresentationCoords.water_surface_m(_state.map.water_step, _state.map.water_z)
	## Dry is the slabs. A ground plane at y=0 z-fights them and paints the void.
	_water.visible = _state.map.water_step != Taxonomy.WaterStep.DRY


func _cycle_water_step() -> void:
	var i := _WATER_CYCLE.find(_state.map.water_step)
	if i < 0:
		i = 0
	_state.map.water_step = _WATER_CYCLE[(i + 1) % _WATER_CYCLE.size()]
	_sync_water_from_map()
	_redraw()


## Swim on Flooded streets; climb when standing on a connector column (plan 3.4).
func _locomotion_clip(u: Unit) -> String:
	if u.dead or u.bleeding or u.pin != Unit.PinState.NONE:
		return ""
	if _state.live_watch_for(u.id) != null:
		return ""
	if _on_connector_column(u.cell):
		return "climb"
	var cell: Cell = _state.map.get_cell(u.cell)
	if cell != null and cell.has_flag(Taxonomy.CellFlags.DECK):
		return ""
	if _dock_cells.has(u.cell):
		return "" ## on the boards
	if PresentationCoords.floats(u.cell, _state.map.water_step, _state.map.water_z):
		return "swim"
	return ""


func _on_connector_column(cell: Vector3i) -> bool:
	for s in _stamps:
		var stamp: Stamp = s
		if not BowlAuthoring.is_connector(stamp.piece_id):
			continue
		if stamp.origin.x == cell.x and stamp.origin.y == cell.y:
			return true
	return false


func _map_max_z(map: BowlMap) -> int:
	var m := 0
	for coord in map.cells.keys():
		m = maxi(m, coord.z)
	return m


func _ids_of(faction: Taxonomy.Faction) -> Array[int]:
	var ids: Array[int] = []
	for u in _state.units_of_faction(faction):
		ids.append(u.id)
	ids.sort()
	return ids


func _tick_wall_fade(dt: float) -> void:
	if _wall_fade == null or _camera == null or _bowl == null:
		return
	_wall_fade.tick(dt, _camera.global_position, _friendly_heads(), _bowl, _cutaway_z)


## Head/chest/feet points for wall-fade segments. Friendlies only (UI §2).
func _friendly_heads() -> Array:
	var heads: Array = []
	for id in _player_ids:
		var u: Unit = _state.get_unit(id)
		if u == null or not u.is_active() or u.extracted:
			continue
		if u.cell.z > _cutaway_z:
			continue
		var ground := _body_origin(u)
		for y in _WallFade.BODY_SAMPLE_Y_M:
			heads.append(ground + Vector3(0.0, float(y), 0.0))
	return heads
