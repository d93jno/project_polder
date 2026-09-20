class_name CombatState
extends RefCounted
## Fight state consumed by exposure / cones. Phase 1.5 grows this (AP, pins, commands).

var units: Dictionary = {} ## int id -> Unit
var watches: Array = [] ## LiveWatch


func add_unit(unit: Unit) -> void:
	units[unit.id] = unit


func get_unit(id: int) -> Unit:
	return units.get(id) as Unit


func all_units() -> Array:
	return units.values()


func add_watch(watch: LiveWatch) -> void:
	watches.append(watch)


func hostiles_of(unit: Unit) -> Array:
	var out: Array = []
	for other in units.values():
		if other.id == unit.id:
			continue
		if _is_hostile(unit.faction, other.faction):
			out.append(other)
	return out


func units_of_faction(faction: Taxonomy.Faction) -> Array:
	var out: Array = []
	for unit in units.values():
		if unit.faction == faction:
			out.append(unit)
	return out


## P0: player vs everyone else (except neutral); non-player only hostile to player.
static func _is_hostile(a: Taxonomy.Faction, b: Taxonomy.Faction) -> bool:
	if a == b:
		return false
	if a == Taxonomy.Faction.NEUTRAL or b == Taxonomy.Faction.NEUTRAL:
		return false
	if a == Taxonomy.Faction.PLAYER or b == Taxonomy.Faction.PLAYER:
		return true
	return false
