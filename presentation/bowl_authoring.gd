class_name BowlAuthoring
extends Object
## Bowl authoring lint (plan 3.2). Presentation-side — cells remain rules truth;
## stamps are the draw table. Pure functions; safe to call from headless tests.

const CONNECTOR_IDS := {
	"env_stair": true,
	"env_ladder": true,
	"env_hatch": true,
}


## Human-readable failures. Empty = pass.
static func lint(
	map: BowlMap,
	stamps: Array,
	swim_columns: Array = [], ## Vector2i (x, y) columns allowed to stack without a connector
	machines: Array = [], ## Machine: what the bowl authors, to be checked against its stamps
) -> PackedStringArray:
	var failures: PackedStringArray = []
	failures.append_array(_cover_honesty(map, stamps))
	failures.append_array(_no_orphan_cells(map, stamps))
	failures.append_array(_no_overlaps(stamps))
	failures.append_array(_no_invisible_climb(map, stamps, swim_columns))
	failures.append_array(_links_match_connectors(map, stamps, machines))
	failures.append_array(_machines_match_stamps(map, stamps, machines))
	return failures


static func is_connector(piece_id: String) -> bool:
	return CONNECTOR_IDS.has(piece_id)


static func _cover_honesty(map: BowlMap, stamps: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for s in stamps:
		var stamp: Stamp = s
		var cover: int = PresentationCatalog.cover_of(stamp.piece_id)
		if cover < 0:
			continue
		for cell in PresentationCatalog.stamp_cells(stamp):
			if not map.has_cell(cell):
				continue
			var mat: Taxonomy.CoverMaterial = map.get_cell(cell).material
			if int(mat) != cover:
				out.append(
					"cover honesty: stamp %s at %s expects %s over %s (got %s)" % [
						stamp.piece_id,
						stamp.origin,
						Taxonomy.material_name(cover as Taxonomy.CoverMaterial),
						cell,
						Taxonomy.material_name(mat),
					]
				)
	return out


static func _no_orphan_cells(map: BowlMap, stamps: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var claimed: Dictionary = _claimed_cells(stamps)
	for coord in map.cells.keys():
		if claimed.has(coord):
			continue
		var cell: Cell = map.get_cell(coord)
		var choice: Dictionary = PresentationCatalog.piece_for_cell(map, coord)
		var piece_id: String = choice.get("id", "")
		if piece_id.is_empty():
			## Smoke is a volume with no kit mesh; plain AIR slabs are optional art.
			if cell.material == Taxonomy.CoverMaterial.SMOKE:
				continue
			if cell.material == Taxonomy.CoverMaterial.AIR and not cell.has_flag(Taxonomy.CellFlags.DECK):
				continue
			out.append("orphan cell: %s has no stamp and no prop mesh" % coord)
			continue
		if PresentationCatalog.is_single_cell_piece(piece_id):
			continue
		out.append(
			"orphan cell: %s needs a stamp (piece %s is multi-cell)" % [coord, piece_id]
		)
	return out


static func _no_overlaps(stamps: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var seen: Dictionary = {} ## Vector3i → stamp piece_id
	for s in stamps:
		var stamp: Stamp = s
		for cell in PresentationCatalog.stamp_cells(stamp):
			if seen.has(cell):
				var other_id: String = seen[cell]
				if _overlap_allowed(other_id, stamp.piece_id):
					continue
				out.append(
					"overlap: %s claimed by %s and %s" % [cell, other_id, stamp.piece_id]
				)
			else:
				seen[cell] = stamp.piece_id
	return out


## House shell + interior floors share a footprint; connectors dress a climb column;
## shanty dressing sits on a roof deck.
static func _overlap_allowed(a: String, b: String) -> bool:
	if is_connector(a) or is_connector(b):
		return true
	var floor_a := a.begins_with("env_floor_interior")
	var floor_b := b.begins_with("env_floor_interior")
	var house_a := a.begins_with("env_house_2storey")
	var house_b := b.begins_with("env_house_2storey")
	if (floor_a and house_b) or (floor_b and house_a):
		return true
	var deck_a := a.begins_with("env_roof_deck")
	var deck_b := b.begins_with("env_roof_deck")
	var shanty_a := a.begins_with("env_shanty")
	var shanty_b := b.begins_with("env_shanty")
	if (deck_a and shanty_b) or (deck_b and shanty_a):
		return true
	return false


static func _no_invisible_climb(
	map: BowlMap, stamps: Array, swim_columns: Array
) -> PackedStringArray:
	var out: PackedStringArray = []
	var linked: Dictionary = _connector_links(stamps)
	var exempt: Dictionary = {}
	for col in swim_columns:
		exempt[col] = true
	for coord_any in map.cells.keys():
		var coord: Vector3i = coord_any
		var above: Vector3i = coord + Vector3i(0, 0, 1)
		if not map.has_cell(above):
			continue
		if not Movement.is_walkable(map, coord) or not Movement.is_walkable(map, above):
			continue
		var col := Vector2i(coord.x, coord.y)
		if exempt.has(col):
			continue
		var key := "%d,%d,%d" % [coord.x, coord.y, coord.z]
		if linked.has(key):
			continue
		out.append(
			"invisible climb: walkable %s ↔ %s with no stair/ladder/hatch" % [coord, above]
		)
	return out


## GDD 5.3: the LINK flag is the rule, the connector stamp is the picture. Each must say the same.
static func _links_match_connectors(map: BowlMap, stamps: Array, machines: Array = []) -> PackedStringArray:
	var out: PackedStringArray = []
	var linked: Dictionary = _connector_links(stamps)
	for key in linked.keys():
		var p: PackedStringArray = (key as String).split(",")
		var lower := Vector3i(int(p[0]), int(p[1]), int(p[2]))
		if not map.has_cell(lower):
			continue
		if _hatch_at(machines, lower) != null:
			continue ## the hatch decides alone (plan 06 §6.0)
		if not map.can_step(lower, lower + Vector3i(0, 0, 1)):
			out.append("connector drawn but not linked: no LINK flag at %s or above it" % lower)
	for coord_any in map.cells.keys():
		var coord: Vector3i = coord_any
		var cell: Cell = map.get_cell(coord)
		if cell.has_flag(Taxonomy.CellFlags.LINK) and not linked.has("%d,%d,%d" % [coord.x, coord.y, coord.z]):
			out.append("LINK flag with no stair/ladder/hatch drawn at %s" % coord)
	return out


## The piece each machine kind is drawn as (the kit's own ids, assets/env/kits/terrace/MANIFEST.md).
const MACHINE_PIECES := {
	Machine.Kind.HATCH: "env_hatch",
	Machine.Kind.PUMP: "env_pump_house",
	Machine.Kind.SLUICE: "env_sluice_gauge",
}


static func _hatch_at(machines: Array, cell: Vector3i) -> Machine:
	for m in machines:
		var machine: Machine = m
		if machine.kind == Machine.Kind.HATCH and machine.cell == cell:
			return machine
	return null


## Two-way, as 3.8 did for connectors: a machine must be drawn, a machine piece must be a machine,
## and a hatch is the only truth for its climb, so it must not also carry a LINK flag.
static func _machines_match_stamps(map: BowlMap, stamps: Array, machines: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in machines:
		var machine: Machine = m
		var piece: String = MACHINE_PIECES[machine.kind]
		var drawn := false
		for s in stamps:
			var stamp: Stamp = s
			if stamp.piece_id == piece and machine.cell in PresentationCatalog.stamp_cells(stamp):
				drawn = true
		if not drawn:
			out.append("machine not drawn: %s at %s has no %s stamp over it" % [
				Machine.Kind.keys()[machine.kind], machine.cell, piece
			])
		if machine.kind == Machine.Kind.HATCH and map.has_cell(machine.cell) \
				and map.get_cell(machine.cell).has_flag(Taxonomy.CellFlags.LINK):
			out.append("hatch at %s also carries LINK: the hatch decides the climb alone" % machine.cell)
	for s in stamps:
		var stamp: Stamp = s
		for kind in MACHINE_PIECES:
			if MACHINE_PIECES[kind] != stamp.piece_id:
				continue
			var found := false
			for m in machines:
				var machine: Machine = m
				if machine.kind == kind and machine.cell in PresentationCatalog.stamp_cells(stamp):
					found = true
			if not found:
				out.append("machine piece with no machine: %s at %s" % [stamp.piece_id, stamp.origin])
	return out


static func _claimed_cells(stamps: Array) -> Dictionary:
	var claimed: Dictionary = {}
	for s in stamps:
		for cell in PresentationCatalog.stamp_cells(s as Stamp):
			claimed[cell] = true
	return claimed


## Keys "x,y,z" for the lower cell of each connector link.
static func _connector_links(stamps: Array) -> Dictionary:
	var linked: Dictionary = {}
	for s in stamps:
		var stamp: Stamp = s
		if not is_connector(stamp.piece_id):
			continue
		var fp: Vector3i = PresentationCatalog.footprint_size(stamp.piece_id, stamp.yaw)
		## A connector at origin with `levels` spans origin.z .. origin.z+levels-1 and
		## links each step up to the next (levels is the rise count, usually 1).
		var rise: int = maxi(fp.z, 1)
		for step in rise:
			var lower_z: int = stamp.origin.z + step
			var key := "%d,%d,%d" % [stamp.origin.x, stamp.origin.y, lower_z]
			linked[key] = true
	return linked
