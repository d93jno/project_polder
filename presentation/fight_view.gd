extends Node3D
## Draws CombatState with the art. Commands are the rules layer; this node only applies
## what validate() already priced and redraws the result.

const _BowlDraw := preload("res://presentation/bowl_draw.gd")
const _UnitView := preload("res://presentation/unit_view.gd")
const _ConeView := preload("res://presentation/watch_cone_view.gd")
const _Select := preload("res://presentation/selection_ring.gd")
const _Hud := preload("res://presentation/hud.gd")
const _Water := preload("res://presentation/water_plane.gd")

const _NAMES := {
	1: "Rifles",
	2: "Jans",
	3: "Piet",
	4: "Ria",
}

var _state: CombatState
var _selected_id: int = 1
var _hover: Vector3i = Vector3i.ZERO
var _camera: Camera3D
var _hud
var _bowl
var _units_root: Node3D
var _cones_root: Node3D
var _preview_root: Node3D
var _select_ring
var _player_ids: Array[int] = []


func _ready() -> void:
	_state = _opening()
	_player_ids = _ids_of(Taxonomy.Faction.PLAYER)
	_selected_id = _player_ids[0] if not _player_ids.is_empty() else 1
	_build_world()
	_redraw()
	_hud.set_note("click a tile to walk · click a hostile to shoot · Q Watch · Space / phase plaque ends a phase")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell()
		if cell != Vector3i(999, 999, 999):
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


func _process(_dt: float) -> void:
	var cell := _pick_cell()
	if cell != _hover and cell != Vector3i(999, 999, 999):
		_hover = cell
		_draw_preview()
		_sync_hud()


func _opening() -> CombatState:
	## Same street the scripted fight proves, drawn instead of asserted.
	var map := BowlMap.new()
	map.water_step = Taxonomy.WaterStep.DRY
	map.water_z = 0
	for x in range(0, 17):
		for y in range(0, 6):
			map.set_cell(Vector3i(x, y, 0), Cell.new(Taxonomy.CoverMaterial.AIR))
	for y in range(0, 4):
		map.set_cell(Vector3i(6, y, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var state := CombatState.new()
	state.map = map
	state.extract_cells = [Vector3i(1, 3, 0), Vector3i(1, 4, 0), Vector3i(1, 5, 0)] as Array[Vector3i]
	var p1 := Unit.new(1, Vector3i(5, 3, 0), Taxonomy.Faction.PLAYER, Taxonomy.WeaponClass.RIFLE)
	p1.adapted = true
	p1.is_founder = true
	var p3 := Unit.new(3, Vector3i(4, 3, 0), Taxonomy.Faction.PLAYER)
	p3.has_trauma_kit = true
	state.add_unit(p1)
	state.add_unit(Unit.new(2, Vector3i(3, 3, 0), Taxonomy.Faction.PLAYER))
	state.add_unit(p3)
	state.add_unit(Unit.new(4, Vector3i(3, 2, 0), Taxonomy.Faction.PLAYER))
	state.add_unit(Unit.new(10, Vector3i(9, 4, 0), Taxonomy.Faction.DRIFTER))
	state.add_unit(Unit.new(11, Vector3i(15, 4, 0), Taxonomy.Faction.DRIFTER))
	state.add_unit(Unit.new(12, Vector3i(15, 5, 0), Taxonomy.Faction.DRIFTER))
	return state


func _build_world() -> void:
	_add_environment()
	_bowl = _BowlDraw.new()
	_bowl.name = "Bowl"
	add_child(_bowl)
	_bowl.draw_map(_state.map)

	var water := _Water.new()
	water.name = "Water"
	water.water_step = int(_state.map.water_step)
	water.water_height_m = -0.04 if _state.map.water_step == Taxonomy.WaterStep.DRY else 2.4
	water.position = Vector3(16.0, 0.0, 6.0)
	add_child(water)

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
	sky_mat.sky_horizon_color = Color(0.68, 0.71, 0.74)
	sky_mat.ground_bottom_color = Color(0.20, 0.21, 0.19)
	sky_mat.ground_horizon_color = Color(0.55, 0.56, 0.53)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var light := DirectionalLight3D.new()
	light.name = "LightDay"
	light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	light.light_energy = 1.05
	light.light_color = Color(0.92, 0.94, 0.96)
	add_child(light)

	_camera = Camera3D.new()
	_camera.name = "CameraTactical"
	_camera.fov = 25.0
	var look := PresentationCoords.world(Vector3i(8, 3, 0))
	var eye := look + Vector3(-22.0, 28.0, 8.0)
	_camera.look_at_from_position(eye, look + Vector3(0.0, 1.0, 0.0))
	_camera.current = true
	add_child(_camera)


func _redraw() -> void:
	_draw_units()
	_draw_cones()
	_draw_preview()
	_sync_hud()
	var sel: Unit = _state.get_unit(_selected_id)
	if sel and _select_ring:
		_select_ring.visible = not sel.extracted
		_select_ring.position = PresentationCoords.world_ground(sel.cell) + Vector3(0, 0.02, 0)


func _draw_units() -> void:
	for c in _units_root.get_children():
		c.queue_free()
	for u in _state.all_units():
		var view := _UnitView.new()
		view.name = "U%d" % u.id
		view.weapon = "machete" if u.weapon == Taxonomy.WeaponClass.MELEE else "pistol"
		_units_root.add_child(view)
		view.bind_unit(u, _state.live_watch_for(u.id) != null)


func _draw_cones() -> void:
	for c in _cones_root.get_children():
		c.queue_free()
	for watch in _state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = _state.get_unit(live.unit_id)
		if watcher == null or not watcher.is_active():
			continue
		var cone_res := Cones.watch_cone(
			_state.map, _state, watcher, live.facing, Taxonomy.Faction.PLAYER
		)
		var far := _farthest_in_facing(watcher.cell, live.facing, cone_res.cells)
		var view := _ConeView.new()
		if watcher.faction == Taxonomy.Faction.PLAYER:
			view.mode = 0 if watcher.id != _selected_id else 1
		elif cone_res.apex_known:
			view.mode = 1
		else:
			view.mode = 2
		_cones_root.add_child(view)
		view.aim(PresentationCoords.world_ground(watcher.cell) + Vector3(0, 1.4, 0), PresentationCoords.world_ground(far) + Vector3(0, 1.4, 0))


func _farthest_in_facing(from_cell: Vector3i, facing: Vector3i, cells: Array[Vector3i]) -> Vector3i:
	var best := from_cell + facing
	var best_d := 0
	for c in cells:
		var d: int = (c.x - from_cell.x) * facing.x + (c.y - from_cell.y) * facing.y
		if d > best_d:
			best_d = d
			best = c
	return best


func _draw_preview() -> void:
	for c in _preview_root.get_children():
		c.queue_free()
	var unit: Unit = _state.get_unit(_selected_id)
	if unit == null or not unit.is_active():
		return
	if not _state.map.has_cell(_hover):
		return
	if _hover == unit.cell:
		return
	var occupant := _unit_at(_hover)
	if occupant != null and CombatState.is_hostile(unit.faction, occupant.faction):
		var los := Los.line_of_sight(_state.map, unit.cell, occupant.cell, unit.weapon)
		_mark_cell(occupant.cell, Color(0.95, 0.85, 0.7, 0.45) if los.clean else Color(0.4, 0.35, 0.3, 0.5))
		return
	var path := Movement.path(_state.map, _state, unit, _hover)
	if not path.reachable:
		return
	for i in path.cells.size():
		var col := Color(0.9, 0.88, 0.8, 0.28)
		if i == path.shot_reserve_at:
			col = Color(0.85, 0.7, 0.45, 0.5)
		if i == path.watch_reserve_at:
			col = Color(0.75, 0.55, 0.35, 0.55)
		_mark_cell(path.cells[i], col)


func _mark_cell(cell: Vector3i, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.7, 1.7)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = PresentationCoords.world_ground(cell) + Vector3(0, 0.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_root.add_child(mi)


func _click_cell(cell: Vector3i) -> void:
	var occupant := _unit_at(cell)
	if occupant != null and occupant.faction == Taxonomy.Faction.PLAYER:
		_selected_id = occupant.id
		_redraw()
		return
	var actor: Unit = _state.get_unit(_selected_id)
	if actor == null:
		return
	if occupant != null and CombatState.is_hostile(actor.faction, occupant.faction):
		_try(ShootCommand.new(actor.id, occupant.id))
		return
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
	_hud.set_selected(_player_ids.find(_selected_id))
	_hud.set_ap(u.ap, RulesConstants.AP_POOL)
	_hud.set_hits(u.hp, RulesConstants.HP_PIPS)
	_hud.set_bleed_rounds(u.bleed_rounds_left if u.bleeding else 0)
	var exp := ExposureQuery.exposure(_state.map, _state, u)
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
	var occupant := _unit_at(_hover)
	if occupant != null and CombatState.is_hostile(u.faction, occupant.faction):
		var los := Los.line_of_sight(_state.map, u.cell, occupant.cell, u.weapon)
		if los.clean:
			var dmg := RulesConstants.shot_damage(u.weapon)
			if occupant.bleeding:
				hover_txt += "  kills a bleeder"
			elif dmg >= occupant.hp:
				hover_txt += "  drops to Bleeding Out"
			else:
				hover_txt += "  pins"
			if exp.count > 0:
				hover_txt += "  seen by %d" % exp.count
		else:
			hover_txt += "  blocked: %s" % Taxonomy.material_name(los.blocker)
	var step_name := str(Taxonomy.WaterStep.keys()[_state.map.water_step])
	var bits: Array[String] = [hover_txt, "z %d" % u.cell.z, step_name]
	if break_txt != "":
		bits.append(break_txt)
	if exp.count > 0 and occupant == null:
		bits.append("seen by %d" % exp.count)
	_hud.set_height_read("  ".join(bits))


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
		return Vector3i(999, 999, 999)
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return Vector3i(999, 999, 999)
	var t := -origin.y / dir.y
	if t < 0.0:
		return Vector3i(999, 999, 999)
	var hit := origin + dir * t
	var cell := PresentationCoords.cell_on_ground(hit)
	cell.z = 0
	if not _state.map.has_cell(cell):
		return Vector3i(999, 999, 999)
	return cell


func _ids_of(faction: Taxonomy.Faction) -> Array[int]:
	var ids: Array[int] = []
	for u in _state.units_of_faction(faction):
		ids.append(u.id)
	ids.sort()
	return ids
