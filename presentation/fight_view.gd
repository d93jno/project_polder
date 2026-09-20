extends Node3D
## Draws CombatState with the art. Commands are the rules layer; this node only applies
## what validate() already priced and redraws the result.

const _BowlDraw := preload("res://presentation/bowl_draw.gd")
const _UnitView := preload("res://presentation/unit_view.gd")
const _ConeView := preload("res://presentation/watch_cone_view.gd")
const _Select := preload("res://presentation/selection_ring.gd")
const _Hud := preload("res://presentation/hud.gd")
const _Water := preload("res://presentation/water_plane.gd")
const _CameraRig := preload("res://presentation/camera_rig.gd")
const _Queries := preload("res://presentation/overlay_queries.gd")
const _MINT_3D := preload("res://presentation/mint_key_3d.gdshader")
const _ScriptedFight := preload("res://rules/fixtures/scripted_fight.gd")

const _NAMES := {
	_ScriptedFight.P1: "Piet",
	_ScriptedFight.P2: "Jan",
	_ScriptedFight.P3: "Els",
	_ScriptedFight.P4: "Kees",
}
const _INVALID := Vector3i(999, 999, 999)

var _state: CombatState
var _selected_id: int = 1
var _hover: Vector3i = Vector3i.ZERO
var _camera: Camera3D
var _hud
var _bowl
var _water
var _units_root: Node3D
var _cones_root: Node3D
var _preview_root: Node3D
var _heights_root: Node3D
var _select_ring
var _player_ids: Array[int] = []
var _cutaway_z: int = 99
var _max_z: int = 0
var _queries
var _labels_root: Node3D
var _confirm_target_id: int = -1


func _ready() -> void:
	_state = _opening()
	_player_ids = _ids_of(Taxonomy.Faction.PLAYER)
	_selected_id = _player_ids[0] if not _player_ids.is_empty() else 1
	_build_world()
	_redraw()
	_hud.set_note(
		"click walk until contact · shoot · Q Watch · Space phase · Tab select · F Falling · Esc cancel · [ ] yaw · wheel zoom · MMB peek"
	)


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
				## A/B Falling vs Flooded on the same kit (exposure word + water step).
				_toggle_falling_flooded()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if _confirm_target_id != -1:
					_confirm_target_id = -1
					_hud.set_note("")
					_redraw()
					get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	var cell := _pick_cell()
	if cell != _hover and cell != _INVALID:
		_hover = cell
		_refresh_queries()
		_draw_cones()
		_draw_preview()
		_draw_overlay_labels()
		_sync_hud()


func _opening() -> CombatState:
	## Same opening the headless scripted fight uses (plan 2.6).
	return _ScriptedFight.opening()


func _build_world() -> void:
	_add_environment()
	_bowl = _BowlDraw.new()
	_bowl.name = "Bowl"
	add_child(_bowl)
	_bowl.draw_map(_state.map)
	_max_z = _map_max_z(_state.map)
	_cutaway_z = _max_z
	_bowl.set_cutaway_z(_cutaway_z)

	_water = _Water.new()
	_water.name = "Water"
	add_child(_water)
	_water.fit_map(_state.map)
	_sync_water_from_map()

	var ridge := (load("res://assets/env/hero/env_ridge_farfield.glb") as PackedScene).instantiate()
	ridge.name = "Ridge"
	(ridge as Node3D).position = Vector3(48.0, 0.0, 18.0)
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
	_heights_root = Node3D.new()
	_heights_root.name = "Heights"
	add_child(_heights_root)
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

	var names := PackedStringArray()
	for id in _player_ids:
		names.append(_NAMES.get(id, "Unit %d" % id))
	_hud.set_fireteam(names)


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
	## Look at the wall / contact lane — same street the scripted fight walks.
	rig.look_at_point = PresentationCoords.world(Vector3i(8, 3, 0)) + Vector3(0.0, 1.5, 0.0)
	add_child(rig)
	_camera = rig.ensure_camera()


func _redraw() -> void:
	_refresh_queries()
	_draw_units()
	_draw_cones()
	_draw_preview()
	_draw_height_labels()
	_draw_overlay_labels()
	_sync_hud()
	var sel: Unit = _state.get_unit(_selected_id)
	if sel and _select_ring:
		var show_ring := not sel.extracted and sel.cell.z <= _cutaway_z
		_select_ring.visible = show_ring
		## Match selection_ring's own lift so path tiles do not bury it.
		_select_ring.position = PresentationCoords.world_ground(sel.cell) + Vector3(0, 0.08, 0)


func _refresh_queries() -> void:
	_queries = _Queries.compute(_state.map, _state, _selected_id, _hover)


func _draw_units() -> void:
	for c in _units_root.get_children():
		c.queue_free()
	for u in _state.all_units():
		var view := _UnitView.new()
		view.name = "U%d" % u.id
		_units_root.add_child(view)
		view.bind_unit(u, _state.live_watch_for(u.id) != null)
		## Cutaway hides floors above N; units on those floors hide with them.
		## Tab / fireteam still select a roof unit while the street cutaway is up.
		view.visible = view.visible and u.cell.z <= _cutaway_z
		if view.visible and not u.extracted and not u.dead:
			_spawn_hit_pips(view, u)


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
			PresentationCoords.world_ground(from_cell) + Vector3(0, 1.4, 0),
			PresentationCoords.world_ground(far) + Vector3(0, 1.4, 0)
		)


func _farthest_in_facing(from_cell: Vector3i, facing: Vector3i, cells: Array) -> Vector3i:
	var best := from_cell + facing
	var best_d := 0
	for c in cells:
		var cell: Vector3i = c
		var d: int = (cell.x - from_cell.x) * facing.x + (cell.y - from_cell.y) * facing.y
		if d > best_d:
			best_d = d
			best = cell
	return best


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
				PresentationCoords.world_ground(unit.cell) + Vector3(0, 1.2, 0),
				PresentationCoords.world_ground(occ.cell) + Vector3(0, 1.2, 0),
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
				PresentationCoords.world_ground(cell) + Vector3(-0.55, 0.45, 0.0),
				str(path.cost_per_cell[i]),
				0.011
			)
		if i == path.shot_reserve_at:
			_spawn_mint_sprite(
				PresentationCoords.world_ground(cell) + Vector3(0.0, 0.12, 0.0),
				PresentationCatalog.UI_HUD + "ui_path_reserve_shot.png",
				Vector2(0.9, 0.9),
				true,
				0.9
			)
		if i == path.watch_reserve_at:
			_spawn_mint_sprite(
				PresentationCoords.world_ground(cell) + Vector3(0.0, 0.14, 0.0),
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
			PresentationCoords.world_ground(xc.cell) + Vector3(0.0, 0.9, 0.0),
			_Queries.crossing_label(xc),
			0.01
		)


func _mark_path_tile(cell: Vector3i) -> void:
	_spawn_mint_sprite(
		PresentationCoords.world_ground(cell) + Vector3(0.0, 0.04, 0.0),
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
	var exp_word: String = _Queries.exposure_word(exp)
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
	var bits: Array[String] = [
		hover_txt,
		"z %d" % u.cell.z,
		"cutaway %d" % _cutaway_z,
		step_name,
		exp_word,
	]
	if exp.count > 0:
		bits.append("seen by %d" % exp.count)
	if not exp.sources.is_empty():
		var src_bits: Array[String] = []
		for s in exp.sources:
			src_bits.append("(%d,%d)" % [s.x, s.y])
		bits.append("from %s" % ", ".join(src_bits))
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
		var exp = _queries.exposure
		var text := _Queries.exposure_word(exp)
		if exp.count > 0:
			text += " · seen by %d" % exp.count
		if not exp.sources.is_empty():
			text += " · from %d" % exp.sources.size()
		_spawn_label(
			PresentationCoords.world_ground(sel.cell) + Vector3(0.0, 2.2, 0.0),
			text,
			0.014
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
			PresentationCoords.world_ground(far) + Vector3(0.0, 1.8, 0.0),
			entry["label"],
			0.012
		)
	if _queries.stack_label != "" and _state.map.has_cell(_hover) and _hover.z <= _cutaway_z:
		_spawn_label(
			PresentationCoords.world_ground(_hover) + Vector3(0.0, 1.1, 0.0),
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
				PresentationCoords.world_ground(cell) + Vector3(0.0, 0.55, 0.0),
				word,
				0.01
			)


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
		if u.cell == cell and not u.extracted and not u.dead:
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
	## Ray vs the cutaway floor plane so roof tiles pick when that level is open.
	var plane_y := float(_cutaway_z) * PresentationCoords.LEVEL_M
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return _INVALID
	var hit := origin + dir * t
	var xy := PresentationCoords.cell_on_ground(hit)
	var cell := Vector3i(xy.x, xy.y, _cutaway_z)
	if _state.map.has_cell(cell):
		return cell
	## Fall back to lower authored floors under the same footprint.
	for z in range(_cutaway_z, -1, -1):
		var c := Vector3i(xy.x, xy.y, z)
		if _state.map.has_cell(c):
			return c
	return _INVALID


func _set_cutaway(level: int) -> void:
	_cutaway_z = clampi(level, 0, _max_z)
	if _bowl:
		_bowl.set_cutaway_z(_cutaway_z)
	_redraw()


func _sync_water_from_map() -> void:
	if _water == null:
		return
	_water.water_step = int(_state.map.water_step)
	_water.water_height_m = PresentationCoords.water_height_m(_state.map.water_z)
	## Dry is the slabs. A ground plane at y=0 z-fights them and paints the void.
	_water.visible = _state.map.water_step != Taxonomy.WaterStep.DRY


func _toggle_falling_flooded() -> void:
	if _state.map.water_step == Taxonomy.WaterStep.FALLING:
		_state.map.water_step = Taxonomy.WaterStep.FLOODED
	else:
		_state.map.water_step = Taxonomy.WaterStep.FALLING
	_sync_water_from_map()
	_redraw()


func _draw_height_labels() -> void:
	for c in _heights_root.get_children():
		c.queue_free()
	var sel: Unit = _state.get_unit(_selected_id)
	if sel == null or not sel.is_active():
		return
	## Flat z=0 streets do not need a 0 on every slab. Show height when it can differ.
	if _max_z <= 0:
		return
	for coord in _state.map.cells.keys():
		if coord.z > _cutaway_z:
			continue
		var label := Label3D.new()
		label.text = str(coord.z)
		label.font_size = 48
		label.modulate = Color(0.92, 0.88, 0.78, 0.85)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = PresentationCoords.world_ground(coord) + Vector3(0.0, 0.35, 0.0)
		label.pixel_size = 0.012
		_heights_root.add_child(label)


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
