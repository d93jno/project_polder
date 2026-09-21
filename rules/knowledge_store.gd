class_name KnowledgeStore
extends RefCounted
## Campaign fog memory across fights (plan 04 §4.6). Injectable path — tests never touch
## the real user:// file. Written at fight end only; abandoned fights leave the file alone.


const VERSION := 1
const DEFAULT_PATH := "user://knowledge_store.json"

var path: String = DEFAULT_PATH
## bowl_id -> { visit_index: int, cells: { cell_key -> { last_seen_visit, water_step } }, unrecovered: Array }
var bowls: Dictionary = {}
## Indices into the current bowl's unrecovered list recovered during this fight (in memory only).
var _recovered_ids: Array[int] = []


static func fresh(p_path: String = DEFAULT_PATH) -> KnowledgeStore:
	var store := KnowledgeStore.new()
	store.path = p_path
	return store


## Missing / corrupt / wrong-version → empty store with a warning. Never crashes a fight.
static func load_from(p_path: String = DEFAULT_PATH) -> KnowledgeStore:
	if not FileAccess.file_exists(p_path):
		return fresh(p_path)
	var text := FileAccess.get_file_as_string(p_path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("KnowledgeStore: corrupt or non-object file at %s — starting fresh" % p_path)
		return fresh(p_path)
	var data: Dictionary = json.data
	if int(data.get("version", -1)) != VERSION:
		push_warning(
			"KnowledgeStore: unsupported version %s at %s — starting fresh"
			% [str(data.get("version", "?")), p_path]
		)
		return fresh(p_path)
	var store := from_dict(data)
	store.path = p_path
	return store


func to_dict() -> Dictionary:
	var bowls_out: Dictionary = {}
	for bowl_id in bowls.keys():
		var b: Dictionary = bowls[bowl_id]
		bowls_out[str(bowl_id)] = {
			"visit_index": int(b.get("visit_index", 0)),
			"cells": (b.get("cells", {}) as Dictionary).duplicate(true),
			"unrecovered": (b.get("unrecovered", []) as Array).duplicate(true),
		}
	return {"version": VERSION, "bowls": bowls_out}


static func from_dict(data: Dictionary) -> KnowledgeStore:
	var store := KnowledgeStore.new()
	if data.is_empty():
		return store
	var bowls_in: Dictionary = data.get("bowls", {})
	for bowl_id in bowls_in.keys():
		var raw: Variant = bowls_in[bowl_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = raw
		store.bowls[str(bowl_id)] = {
			"visit_index": int(b.get("visit_index", 0)),
			"cells": (b.get("cells", {}) as Dictionary).duplicate(true),
			"unrecovered": (b.get("unrecovered", []) as Array).duplicate(true),
		}
	return store


func save() -> void:
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("KnowledgeStore: could not write %s (%s)" % [tmp, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("KnowledgeStore: rename failed %s → %s (%s)" % [tmp, path, err])


func file_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _ensure_bowl(bowl_id: String) -> Dictionary:
	if not bowls.has(bowl_id):
		bowls[bowl_id] = {"visit_index": 0, "cells": {}, "unrecovered": []}
	return bowls[bowl_id]


## Seed Known-quiet from prior visits and attach this store to the fight.
func begin_fight(state: CombatState, bowl_id: String) -> void:
	if state == null or bowl_id.is_empty():
		return
	state.bowl_id = bowl_id
	state.knowledge_store = self
	_recovered_ids.clear()
	var bowl := _ensure_bowl(bowl_id)
	if state.knowledge == null:
		state.knowledge = Knowledge.new()
	state.knowledge.visit_index = int(bowl["visit_index"])
	var cells: Dictionary = bowl["cells"]
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		for cell_key in cells.keys():
			var cell := Knowledge._parse_cell_key(str(cell_key))
			var rec: Dictionary = cells[cell_key]
			state.knowledge.observe(
				unit.id,
				cell,
				Knowledge.CellSight.KNOWN_QUIET,
				int(rec.get("last_seen_visit", 0)),
			)


## If Live reaches a sealed wipe anchor, merge that record as Known-quiet (aged).
func try_recover(state: CombatState) -> void:
	if state == null or state.bowl_id.is_empty() or state.knowledge == null:
		return
	if not bowls.has(state.bowl_id):
		return
	var bowl: Dictionary = bowls[state.bowl_id]
	var unrecovered: Array = bowl["unrecovered"]
	for i in range(unrecovered.size()):
		if i in _recovered_ids:
			continue
		var rec: Variant = unrecovered[i]
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = rec
		var anchor := Knowledge._parse_cell_key(str(record.get("anchor", "0,0,0")))
		if not _anchor_is_live(state, anchor):
			continue
		var sealed: Dictionary = record.get("cells", {})
		for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
			for cell_key in sealed.keys():
				var cell := Knowledge._parse_cell_key(str(cell_key))
				var cell_rec: Dictionary = sealed[cell_key]
				state.knowledge.observe(
					unit.id,
					cell,
					Knowledge.CellSight.KNOWN_QUIET,
					int(cell_rec.get("last_seen_visit", 0)),
				)
		_recovered_ids.append(i)


static func _anchor_is_live(state: CombatState, anchor: Vector3i) -> bool:
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		if not unit.is_active():
			continue
		if state.knowledge.own_sight(unit.id, anchor) == Knowledge.CellSight.LIVE:
			return true
	return false


## Persist only when the fight ended. ONGOING / abandon → no write.
func commit_fight(state: CombatState) -> void:
	if state == null or state.bowl_id.is_empty():
		return
	var result := state.outcome()
	if result == CombatState.FightOutcome.ONGOING:
		return
	var bowl := _ensure_bowl(state.bowl_id)
	var fight_visit := state.knowledge.visit_index if state.knowledge != null else 0
	match result:
		CombatState.FightOutcome.EXTRACTED:
			_apply_extracted(state, bowl, fight_visit)
		CombatState.FightOutcome.WIPED:
			_apply_wiped(state, bowl, fight_visit)
	bowl["visit_index"] = int(bowl["visit_index"]) + 1
	_drop_recovered(bowl)
	_recovered_ids.clear()
	save()


func _apply_extracted(state: CombatState, bowl: Dictionary, _fight_visit: int) -> void:
	var cells: Dictionary = bowl["cells"]
	var water := int(state.map.water_step) if state.map != null else 0
	if state.knowledge == null:
		return
	for cell in state.knowledge.known_cells(state).keys():
		var key := Knowledge._cell_key(cell)
		var last := state.knowledge.squad_last_seen_visit(state, cell)
		if cells.has(key):
			var prev: Dictionary = cells[key]
			last = maxi(last, int(prev.get("last_seen_visit", 0)))
		cells[key] = {"last_seen_visit": last, "water_step": water}
	bowl["cells"] = cells


func _apply_wiped(state: CombatState, bowl: Dictionary, fight_visit: int) -> void:
	## Peeled cells are sealed, not applied to the bowl map (§7.10).
	var sealed: Dictionary = {}
	var water := int(state.map.water_step) if state.map != null else 0
	if state.knowledge != null:
		for cell in state.knowledge.known_cells(state).keys():
			var last := state.knowledge.squad_last_seen_visit(state, cell)
			sealed[Knowledge._cell_key(cell)] = {
				"last_seen_visit": last,
				"water_step": water,
			}
	var unrecovered: Array = bowl["unrecovered"]
	unrecovered.append({
		"visit": fight_visit,
		"anchor": Knowledge._cell_key(state.wipe_anchor()),
		"cells": sealed,
	})
	bowl["unrecovered"] = unrecovered


func _drop_recovered(bowl: Dictionary) -> void:
	if _recovered_ids.is_empty():
		return
	var unrecovered: Array = bowl["unrecovered"]
	var keep: Array = []
	for i in range(unrecovered.size()):
		if i in _recovered_ids:
			continue
		keep.append(unrecovered[i])
	bowl["unrecovered"] = keep
