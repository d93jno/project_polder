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
) -> PackedStringArray:
	var failures: PackedStringArray = []
	failures.append_array(_cover_honesty(map, stamps))
	failures.append_array(_no_orphan_cells(map, stamps))
	failures.append_array(_no_overlaps(stamps))
	failures.append_array(_no_invisible_climb(map, stamps, swim_columns))
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
