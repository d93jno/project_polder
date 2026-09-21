extends Node3D
## Instances the shared humanoid and a held weapon. Plays named clips.
## Does not own Unit / CombatState. Mesh path comes from PresentationCatalog.humanoid_for.

@export_enum("machete", "pistol", "none") var weapon: String = "machete"
@export var clip: String = "idle"
var body_path: String = PresentationCatalog.HUMANOID
var unit_id: int = -1


func _ready() -> void:
	_ensure_body()


## `origin` is where the body stands: the floor, or below the surface while it swims. Omitted, it
## stands on the floor.
func bind_unit(u: Unit, watching: bool, origin: Vector3 = Vector3.INF) -> void:
	unit_id = u.id
	weapon = "machete" if u.weapon == Taxonomy.WeaponClass.MELEE else "pistol"
	_ensure_body(PresentationCatalog.humanoid_for(u.faction, u.id))
	position = PresentationCoords.world_ground(u.cell) if origin == Vector3.INF else origin
	rotation_degrees = Vector3(0.0, PresentationCoords.yaw_degrees(u.facing), 0.0)
	visible = not u.extracted
	if u.dead:
		play("downed")
	elif u.bleeding:
		play("downed")
	elif u.pin == Unit.PinState.DUCKED:
		play("flinch")
	elif watching:
		play("watch" if Taxonomy.is_long(u.weapon) else "aim_pistol")
	else:
		play("idle")


func play(clip_name: String) -> void:
	clip = clip_name
	var body := get_node_or_null("Body")
	if body:
		_play(body, clip_name)


func _ensure_body(path: String = "") -> void:
	if not path.is_empty():
		body_path = path
	var existing := get_node_or_null("Body")
	if existing and existing.get_meta("polder_body_path", "") == body_path:
		return
	if existing:
		existing.free()
	var packed := load(body_path) as PackedScene
	if packed == null:
		packed = load(PresentationCatalog.HUMANOID) as PackedScene
	var body := packed.instantiate()
	body.name = "Body"
	body.set_meta("polder_body_path", body_path)
	add_child(body)
	_attach_weapon(body)
	_play(body, clip)


func _play(root: Node, clip_name: String) -> void:
	var ap := _find_anim(root)
	if ap == null:
		return
	if ap.has_animation(clip_name):
		ap.play(clip_name)


func _attach_weapon(root: Node) -> void:
	if weapon == "none":
		return
	var path := PresentationCatalog.MACHETE if weapon == "machete" else PresentationCatalog.PISTOL
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var socket := root.find_child("hand_r", true, false)
	if socket == null:
		push_warning("unit_view: hand_r socket missing")
		return
	var held := packed.instantiate() as Node3D
	held.name = "HeldWeapon"
	socket.add_child(held)
	held.transform = Transform3D.IDENTITY


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null
