extends RefCounted
## Pure overlay reads for the fight view (plan 2.3). The view may draw these fields
## only — never a parallel LOS / path / cone of its own.
## Preload this script (no class_name) so headless tests do not need a global-class refresh.

var exposure: Exposure = Exposure.new()
var stack: ConeStack = ConeStack.new()
var stack_label: String = ""
var path: MovePath = MovePath.new()
var los: LosResult = null
var hover_hostile: bool = false
## One entry per live (unspent) Watch the view may draw.
var watches: Array = [] ## Dictionary


static func compute(
	map: BowlMap,
	state: CombatState,
	selected_id: int,
	hover: Vector3i,
):
	var q = load("res://presentation/overlay_queries.gd").new()
	var unit: Unit = state.get_unit(selected_id)
	if unit == null or not unit.is_active():
		return q
	q.exposure = ExposureQuery.exposure(map, state, unit)
	## Stack the hovered coordinate even if the sparse map has no cell there (open air).
	q.stack = Cones.cone_stack(map, state, hover)
	q.stack_label = format_stack(q.stack)

	var occupant := _unit_at(state, hover)
	if (
		occupant != null
		and CombatState.is_hostile(unit.faction, occupant.faction)
		and not occupant.extracted
		and not occupant.dead
	):
		q.hover_hostile = true
		q.los = Los.line_of_sight(map, unit.cell, occupant.cell, unit.weapon)
	elif map.has_cell(hover) and hover != unit.cell:
		q.path = Movement.path(map, state, unit, hover)

	var path_cells: Array[Vector3i] = []
	if q.path.reachable:
		path_cells = q.path.cells

	for watch in state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = state.get_unit(live.unit_id)
		if watcher == null or not watcher.is_active():
			continue
		var cells: Array[Vector3i] = Cones.cone(map, watcher.cell, live.facing, watcher.weapon)
		var apex := Cones.apex_known(map, state, watcher.cell, Taxonomy.Faction.PLAYER)
		var friendly := watcher.faction == Taxonomy.Faction.PLAYER
		var full_volume := true
		if friendly:
			full_volume = watcher.id == selected_id or _path_crosses(path_cells, cells)
		q.watches.append({
			"unit_id": watcher.id,
			"cell": watcher.cell,
			"facing": live.facing,
			"cells": cells,
			"apex_known": apex,
			"friendly": friendly,
			"weapon": watcher.weapon,
			"is_long": Taxonomy.is_long(watcher.weapon),
			"full_volume": full_volume,
			"label": weapon_label(watcher.weapon),
		})
	return q


## "2 watches: rifle, long, pistol" — words only, no hues (UI §4.4).
static func format_stack(stack: ConeStack) -> String:
	if stack.count <= 0:
		return ""
	var parts: Array[String] = []
	for weapon in stack.classes:
		parts.append(weapon_label(weapon))
	var noun := "watch" if stack.count == 1 else "watches"
	return "%d %s: %s" % [stack.count, noun, ", ".join(parts)]


static func weapon_label(weapon: Taxonomy.WeaponClass) -> String:
	var name := Taxonomy.weapon_class_name(weapon).to_lower()
	if Taxonomy.is_long(weapon):
		return "%s, long" % name
	return name


static func exposure_word(exp: Exposure) -> String:
	match exp.state:
		Exposure.State.HIDDEN:
			return "hidden"
		Exposure.State.NO_HIDE:
			return "no hide"
		_:
			return "exposed"


static func _path_crosses(path_cells: Array[Vector3i], cone_cells: Array[Vector3i]) -> bool:
	for c in path_cells:
		if c in cone_cells:
			return true
	return false


static func _unit_at(state: CombatState, cell: Vector3i) -> Unit:
	for u in state.all_units():
		if u.cell == cell and not u.extracted and not u.dead:
			return u
	return null
