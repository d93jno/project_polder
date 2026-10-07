extends RefCounted
## Pure overlay reads for the fight view (plan 2.3–2.4). The view may draw these
## fields only — never a parallel LOS / path / cone of its own.
## Fog filters here, not in the view (plan 04 §4.3): hostiles and shot previews
## only for Live squad cells; cone apex from squad Live; exposure sources from
## per-unit merged knowledge inside ExposureQuery.
## Preload this script (no class_name) so headless tests do not need a global-class refresh.

var exposure: Exposure = Exposure.new()
var stack: ConeStack = ConeStack.new()
var stack_label: String = ""
var path: MovePath = MovePath.new()
var los: LosResult = null
var hover_hostile: bool = false
var hover_cover: bool = false
## One entry per live (unspent) Watch the view may draw.
var watches: Array = [] ## Dictionary
## Hostile bodies on cells that are Live in the squad's picture.
var hostiles: Array = [] ## Unit

## Shot / line preview (UI §4.1 / §4.3).
var shot_cost: int = 0
var shot_affordable: bool = true
var shot_outcome: String = "" ## pins | drops to Bleeding Out | kills a bleeder | blocked | ""
var cover_stops_label: String = ""
var kills_bleeder: bool = false

## Interact preview for a hovered machine (plan 06 §6.3). Empty when none is hovered. Read from the
## rules: the command is validated and, if legal, applied to a duplicate state and diffed.
var interact: Dictionary = {}
var interact_label: String = ""


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
	q.hostiles = _squad_live_hostiles(state)
	## Stack the hovered coordinate even if the sparse map has no cell there (open air).
	q.stack = Cones.cone_stack(map, state, hover)
	q.stack_label = format_stack(q.stack)
	q.shot_cost = RulesConstants.shot_cost(unit.weapon)
	q.shot_affordable = unit.ap >= q.shot_cost

	var occupant := _unit_at(state, hover)
	if (
		occupant != null
		and CombatState.is_hostile(unit.faction, occupant.faction)
		and not occupant.extracted
		and not occupant.dead
		and _is_squad_live(state, occupant.cell)
	):
		q.hover_hostile = true
		q.los = Los.line_of_sight(map, unit.cell, occupant.cell, unit.weapon)
		q.shot_outcome = _shot_outcome(unit, occupant, q.los)
		q.kills_bleeder = q.los.clean and occupant.bleeding
	elif map.has_cell(hover) and hover != unit.cell:
		if occupant == null:
			var cell: Cell = map.get_cell(hover)
			if cell != null and cell.material != Taxonomy.CoverMaterial.AIR:
				q.hover_cover = true
				q.cover_stops_label = format_cover_stops(cell.material)
		q.path = Movement.path(map, state, unit, hover)

	if state.machine_at(hover) != null:
		q.interact = interact_preview(map, state, unit, hover)
		q.interact_label = format_interact(q.interact)

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
		## Apex from fog: Live in the squad picture, not a parallel Vision call.
		var apex := _is_squad_live(state, watcher.cell)
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


## What using the machine at `cell` would do, from the rules alone (plan 06 §6.3). The command is
## validated; if it is legal it is applied to a duplicate state and the two are diffed, so the preview
## cannot disagree with the rule. Nothing here computes water, AP or contact itself.
static func interact_preview(map: BowlMap, state: CombatState, unit: Unit, cell: Vector3i) -> Dictionary:
	var machine: Machine = state.machine_at(cell)
	var command := MachineCommand.new(unit.id, cell, not machine.on)
	var check := command.validate(state)
	var out := {
		"kind": machine.kind,
		"turn_on": command.turn_on,
		"ok": check.ok,
		"reason": check.reason,
		"cost": RulesConstants.INTERACT_COST,
		"ap_left": unit.ap - RulesConstants.INTERACT_COST,
		"affordable": unit.ap >= RulesConstants.INTERACT_COST,
		"confirms": command.needs_confirm(state),
		"contested": Contact.machine_starts_contact(map, state, unit, cell),
		"watches": Command.hostile_watches_covering(map, state, unit.cell, unit.faction),
		"water_from": map.water_step,
		"water_to": command.water_step_after(state),
		"changed_cells": [] as Array[Vector3i],
		"bodies_in_it": [] as Array[int],
	}
	if check.ok and command.water_step_after(state) != map.water_step:
		var after := command.apply(state)
		var changed: Array[Vector3i] = []
		for coord in map.cells.keys():
			if map.step_at(coord) != after.map.step_at(coord):
				changed.append(coord)
		out["changed_cells"] = changed
		var bodies: Array[int] = []
		for body in state.units_of_faction(Taxonomy.Faction.PLAYER):
			if body.is_active() and body.cell in changed:
				bodies.append(body.id)
		out["bodies_in_it"] = bodies
	return out


## Words, no hues (UI §14). Cost first, then what it does, then what it risks.
static func format_interact(preview: Dictionary) -> String:
	if preview.is_empty():
		return ""
	var machine_kind: Machine.Kind = preview["kind"]
	var on: bool = preview["turn_on"]
	var verbs: Dictionary = {
		Machine.Kind.HATCH: ["close", "open"],
		Machine.Kind.PUMP: ["stop", "start"],
		Machine.Kind.SLUICE: ["close", "open"],
	}
	var verb: String = (verbs[machine_kind] as Array)[1 if on else 0]
	var noun := str(Machine.Kind.keys()[machine_kind]).to_lower()
	var head := "%s %s · %d AP" % [verb, noun, preview["cost"]]
	if preview["affordable"]:
		head += ", %d left" % preview["ap_left"]
	else:
		head += " · can't afford it"
	var lines: Array[String] = [head]
	if not preview["ok"] and preview["affordable"]:
		lines.append(str(preview["reason"]))
	var changed: Array = preview["changed_cells"]
	if not changed.is_empty():
		lines.append("water %s to %s · %d tiles" % [
			_step_word(preview["water_from"]), _step_word(preview["water_to"]), changed.size()
		])
		var bodies: Array = preview["bodies_in_it"]
		if not bodies.is_empty():
			lines.append("%d of yours stand in it" % bodies.size())
	if preview["contested"]:
		lines.append("contested: a hostile is on it")
	var watches: Array = preview["watches"]
	if not watches.is_empty():
		lines.append("%d watch%s fire" % [watches.size(), "" if watches.size() == 1 else "es"])
	if preview["confirms"]:
		lines.append("click again to confirm")
	return "\n".join(lines)


static func _step_word(step: Taxonomy.WaterStep) -> String:
	return str(Taxonomy.WaterStep.keys()[step]).to_lower()


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


## "stops pistol, melee, spear, shotgun" — material hover (UI §4.3).
static func format_cover_stops(material: Taxonomy.CoverMaterial) -> String:
	if material == Taxonomy.CoverMaterial.AIR:
		return ""
	var parts: Array[String] = []
	for weapon in Taxonomy.WeaponClass.values():
		if Taxonomy.stops(material, weapon):
			parts.append(Taxonomy.weapon_class_name(weapon).to_lower())
	if parts.is_empty():
		return "stops nothing"
	return "stops %s" % ", ".join(parts)


static func crossing_label(crossing: WatchCrossing) -> String:
	return "crosses %s" % weapon_label(crossing.weapon)


static func _shot_outcome(attacker: Unit, target: Unit, los: LosResult) -> String:
	if los == null:
		return ""
	if not los.clean:
		return "blocked: %s" % Taxonomy.material_name(los.blocker)
	var dmg := RulesConstants.shot_damage(attacker.weapon)
	if target.bleeding:
		return "kills a bleeder"
	if dmg >= target.hp:
		return "drops to Bleeding Out"
	return "pins"


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


static func _is_squad_live(state: CombatState, cell: Vector3i) -> bool:
	if state.knowledge == null:
		return false
	return state.knowledge.squad_sight(state, cell) == Knowledge.CellSight.LIVE


static func _squad_live_hostiles(state: CombatState) -> Array:
	var out: Array = []
	for u in state.all_units():
		if u.dead or u.extracted:
			continue
		if u.faction == Taxonomy.Faction.PLAYER:
			continue
		if not CombatState.is_hostile(Taxonomy.Faction.PLAYER, u.faction):
			continue
		if _is_squad_live(state, u.cell):
			out.append(u)
	return out
