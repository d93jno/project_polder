class_name Knowledge
extends RefCounted
## Per-unit fog observations. Monotonic within a fight: Unknown → Known-quiet ↔ Live,
## never back to Unknown (GDD §3.1, plan 04 §4.2). Plain data — no nodes.


enum CellSight {
	UNKNOWN,
	KNOWN_QUIET,
	LIVE,
}

## Current visit ordinal. Peel stamps Live cells with this; the store (4.6) sets it.
var visit_index: int = 0
## unit_id -> { Vector3i -> { "sight": CellSight, "last_seen_visit": int } }
var _by_unit: Dictionary = {}


func duplicate_knowledge() -> Knowledge:
	return from_dict(to_dict())


## Recompute Live from Vision for every active player unit. Own eyes only — earshot is a read.
func peel(map: BowlMap, state: CombatState) -> void:
	if map == null or state == null:
		return
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		if unit.is_active():
			_peel_unit(map, state, unit)


func _peel_unit(map: BowlMap, state: CombatState, unit: Unit) -> void:
	var live := Vision.live_cells(map, state, unit)
	var obs: Dictionary = _by_unit.get(unit.id, {})
	for cell in obs.keys():
		var rec: Dictionary = obs[cell]
		if rec["sight"] == CellSight.LIVE and not live.has(cell):
			rec["sight"] = CellSight.KNOWN_QUIET
	for cell in live.keys():
		obs[cell] = {"sight": CellSight.LIVE, "last_seen_visit": visit_index}
	_by_unit[unit.id] = obs


## Own observation only. Absence is Unknown.
func own_sight(unit_id: int, cell: Vector3i) -> CellSight:
	var obs: Dictionary = _by_unit.get(unit_id, {})
	if not obs.has(cell):
		return CellSight.UNKNOWN
	return obs[cell]["sight"] as CellSight


## Own + every unit Comms.shares with. Live beats Known-quiet; newer visit wins ties.
func merged_sight(state: CombatState, unit: Unit, cell: Vector3i) -> CellSight:
	return _merged_record(state, unit, cell)["sight"] as CellSight


func merged_last_seen_visit(state: CombatState, unit: Unit, cell: Vector3i) -> int:
	return int(_merged_record(state, unit, cell)["last_seen_visit"])


func _merged_record(state: CombatState, unit: Unit, cell: Vector3i) -> Dictionary:
	var best: Dictionary = _record_or_empty(unit.id, cell)
	if state == null or unit == null:
		return best
	for other in state.units_of_faction(unit.faction):
		if other.id == unit.id:
			continue
		if not Comms.shares(state, unit, other):
			continue
		best = _better(best, _record_or_empty(other.id, cell))
	return best


func _record_or_empty(unit_id: int, cell: Vector3i) -> Dictionary:
	var obs: Dictionary = _by_unit.get(unit_id, {})
	if not obs.has(cell):
		return {"sight": CellSight.UNKNOWN, "last_seen_visit": -1}
	return {
		"sight": obs[cell]["sight"],
		"last_seen_visit": obs[cell]["last_seen_visit"],
	}


static func _better(a: Dictionary, b: Dictionary) -> Dictionary:
	var sa: int = a["sight"]
	var sb: int = b["sight"]
	if sb > sa:
		return b
	if sa > sb:
		return a
	if int(b["last_seen_visit"]) > int(a["last_seen_visit"]):
		return b
	return a


## Squad picture: union of every player unit's own observations (earshot does not change the map).
func squad_sight(state: CombatState, cell: Vector3i) -> CellSight:
	var best := CellSight.UNKNOWN
	var best_visit := -1
	if state == null:
		return best
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		var rec := _record_or_empty(unit.id, cell)
		var sight: CellSight = rec["sight"] as CellSight
		var visit: int = int(rec["last_seen_visit"])
		if sight > best or (sight == best and visit > best_visit):
			best = sight
			best_visit = visit
	return best


## Squad Known-quiet ∪ Live. MEDEVAC route pricing will plan only over this (§7.8).
func known_cells(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		var obs: Dictionary = _by_unit.get(unit.id, {})
		for cell in obs.keys():
			out[cell] = true
	return out


## Visit stamp for the squad's best observation of `cell`, or -1 if Unknown.
func squad_last_seen_visit(state: CombatState, cell: Vector3i) -> int:
	var best_sight := CellSight.UNKNOWN
	var best_visit := -1
	if state == null:
		return best_visit
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		var rec := _record_or_empty(unit.id, cell)
		var sight: CellSight = rec["sight"] as CellSight
		var visit: int = int(rec["last_seen_visit"])
		if sight > best_sight or (sight == best_sight and visit > best_visit):
			best_sight = sight
			best_visit = visit
	return best_visit


## Shader float for Known-quiet (0..1). Live and Unknown return 0 — fog_view draws neither.
## Same-visit freeze still ages: visits_since 0 → 1/STALE_FULL_AFTER_VISITS (plan 04 §4.4 / §7.5).
func staleness_of(state: CombatState, cell: Vector3i) -> float:
	if squad_sight(state, cell) != CellSight.KNOWN_QUIET:
		return 0.0
	var last := squad_last_seen_visit(state, cell)
	var since := maxi(0, visit_index - last)
	var denom := float(maxi(RulesConstants.STALE_FULL_AFTER_VISITS, 1))
	return clampf(float(since + 1) / denom, 0.0, 1.0)


func to_dict() -> Dictionary:
	var units_out: Dictionary = {}
	for unit_id in _by_unit.keys():
		var cells_out: Dictionary = {}
		var obs: Dictionary = _by_unit[unit_id]
		for cell in obs.keys():
			var c: Vector3i = cell
			var rec: Dictionary = obs[cell]
			cells_out[_cell_key(c)] = {
				"sight": int(rec["sight"]),
				"last_seen_visit": int(rec["last_seen_visit"]),
			}
		units_out[str(unit_id)] = cells_out
	return {"visit_index": visit_index, "units": units_out}


static func from_dict(data: Dictionary) -> Knowledge:
	var k := Knowledge.new()
	if data.is_empty():
		return k
	k.visit_index = int(data.get("visit_index", 0))
	var units_in: Dictionary = data.get("units", {})
	for unit_key in units_in.keys():
		var unit_id := int(unit_key)
		var cells_in: Dictionary = units_in[unit_key]
		var obs: Dictionary = {}
		for cell_key in cells_in.keys():
			var cell := _parse_cell_key(str(cell_key))
			var rec: Dictionary = cells_in[cell_key]
			obs[cell] = {
				"sight": int(rec.get("sight", CellSight.KNOWN_QUIET)) as CellSight,
				"last_seen_visit": int(rec.get("last_seen_visit", 0)),
			}
		k._by_unit[unit_id] = obs
	return k


static func _cell_key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]


static func _parse_cell_key(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
