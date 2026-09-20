extends Node
## Wall fade (plan 3.1). Presentation only — never consulted by `rules/`.
## Pure `occluders()` decides which piece keys sit on camera → friendly head;
## this node eases those pieces' GeometryInstance3D.transparency.

## Remaining opacity when faded (UI §14: silhouette stays a non-colour channel).
const FADE_OPACITY := 0.25
## Godot transparency: 0 = opaque, 1 = invisible. 1 − opacity.
const FADE_TRANSPARENCY := 1.0 - FADE_OPACITY
const FADE_SPEED := 5.0
## Eye-level samples on the body for occlusion segments (meters above ground).
## Head alone clears the 2.4 m quay under the locked pitch; chest/feet still catch it.
const BODY_SAMPLE_Y_M := [0.2, 0.95, 1.7]
## Kept for callers/tests that want a single aim point (chest).
const HEAD_Y_M := 0.95

## key → current transparency (eased).
var _current: Dictionary = {}


## Tall kit pieces that can sit between the camera and a friendly.
static func is_tall_piece(piece_id: String) -> bool:
	match piece_id:
		"env_canal_wall_tall", "env_canal_wall", \
		"env_house_2storey_a", "env_house_2storey_b", "env_house_2storey_c", "env_house_2storey_d", \
		"env_pump_house", \
		"env_levee_straight", "env_levee_inner_corner", "env_levee_outer_corner", "env_levee_slope":
			return true
		_:
			return false


## Pure. `boxes` entries: `{ "key": String, "aabb": AABB }`.
## Returns the keys whose AABB the open segment cam → target intersects.
static func occluders(cam: Vector3, target: Vector3, boxes: Array) -> Array[String]:
	var hit: Array[String] = []
	for entry in boxes:
		var key: String = entry["key"]
		var box: AABB = entry["aabb"]
		if _segment_hits_aabb(cam, target, box):
			hit.append(key)
	return hit


static func _segment_hits_aabb(from: Vector3, to: Vector3, box: AABB) -> bool:
	## Camera or target inside the volume counts (fade the shell you're in / looking into).
	if box.has_point(from) or box.has_point(to):
		return true
	return box.intersects_segment(from, to) != null


## World AABB of every MeshInstance3D under a piece root.
static func world_aabb_of(piece_root: Node3D) -> AABB:
	var merged := AABB()
	var any := false
	for mi in _geometry_under(piece_root):
		var local: AABB = mi.get_aabb()
		var world: AABB = mi.global_transform * local
		if not any:
			merged = world
			any = true
		else:
			merged = merged.merge(world)
	if not any:
		## Degenerate fallback so a missing mesh never becomes an infinite occluder.
		merged = AABB(piece_root.global_position, Vector3(0.05, 0.05, 0.05))
	return merged


static func _geometry_under(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		out.append(root as GeometryInstance3D)
	for child in root.get_children():
		out.append_array(_geometry_under(child))
	return out


## Collect tall, cutaway-visible bowl pieces as `{ key, aabb, root }`.
static func collect_boxes(bowl: Node3D, cutaway_z: int) -> Array:
	var boxes: Array = []
	if bowl == null:
		return boxes
	for child in bowl.get_children():
		if not (child is Node3D):
			continue
		var n := child as Node3D
		if not n.visible:
			continue
		var z: int = int(n.get_meta("polder_z", 0))
		if z > cutaway_z:
			continue
		var piece_id: String = str(n.get_meta("polder_piece", ""))
		if piece_id.is_empty() or not is_tall_piece(piece_id):
			continue
		boxes.append({
			"key": n.name,
			"aabb": world_aabb_of(n),
			"root": n,
		})
	return boxes


## Drive fades for the given friendly head positions. Call once per frame.
func tick(
	delta: float,
	cam: Vector3,
	friendly_heads: Array,
	bowl: Node3D,
	cutaway_z: int,
) -> void:
	var boxes: Array = collect_boxes(bowl, cutaway_z)
	var want: Dictionary = {}
	for head in friendly_heads:
		for key in occluders(cam, head as Vector3, boxes):
			want[key] = true

	var seen: Dictionary = {}
	for entry in boxes:
		var key: String = entry["key"]
		seen[key] = true
		var goal := FADE_TRANSPARENCY if want.has(key) else 0.0
		var cur: float = float(_current.get(key, 0.0))
		cur = move_toward(cur, goal, FADE_SPEED * delta)
		_current[key] = cur
		_apply_transparency(entry["root"] as Node3D, cur)

	## Drop keys for pieces that left the bowl so a redraw cannot stick forever.
	for key in _current.keys():
		if not seen.has(key):
			_current.erase(key)


## Snap every candidate to its goal (tests / shots that cannot wait on the ease).
func snap(
	cam: Vector3,
	friendly_heads: Array,
	bowl: Node3D,
	cutaway_z: int,
) -> void:
	tick(999.0, cam, friendly_heads, bowl, cutaway_z)


func _apply_transparency(piece_root: Node3D, amount: float) -> void:
	for gi in _geometry_under(piece_root):
		gi.transparency = amount
