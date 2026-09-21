extends SceneTree
## Render smoke for `make shots` (plan 3.0). Not a GUT test — driven by scripts/shots.sh.
## Opens the fight view in a real window, applies a named setup, waits, writes a PNG,
## and fails on two pixel probes that caught the cream-cone and muted-pip regressions.
##
## Ad-hoc mode, for looking at one state while troubleshooting layout (scripts/shots.sh with
## arguments, or the screenshot skill). Any of these options selects `--setup=adhoc`:
##   --scene=res://scenes/main.tscn   scene to instance (default: the fight view)
##   --do=EXPR                        GDScript expression run on the scene root, in order (repeat):
##                                    --do='set_process(false)' --do='set("_hover", Vector3i(10,5,0))'
##                                    Expressions cannot assign; use set() or call methods.
##   --hook=res://x.gd                script with a synchronous `func setup(scene: Node)`
##   --crop=x,y,w,h --zoom=3          also write <out>_crop.png of that region, scaled up
##   --probe=x,y                      print the pixel colour there (repeat); checks HUD without eyes
##   --warmup=N --settle=N            frames before setup (default 2) and after it (default 20)
## Needs a display. The headless renderer draws nothing, and an empty frame fails the run.

## Hover cell that aims Piet's rifle Watch down the street (plan 3.0 street_watch).
const _WATCH_HOVER := Vector3i(10, 5, 0)
## Luminance spread across street corners under Falling water. Slabs and joints differ when the
## bottom shows through; an opaque sheet is flat.
const FALLING_BOTTOM_MIN_SPREAD := 0.075

var _setup: String = "street_watch"
var _setup_given: bool = false
var _scene_path: String = "res://scenes/main.tscn"
var _boot_frames: int = 2
var _wait_frames: int = 20
var _dos: PackedStringArray = []
var _hook_path: String = ""
var _crop: PackedStringArray = []
var _zoom: int = 3
var _pixel_probes: PackedStringArray = []
var _out_path: String = "res://build/shots/shot.png"
var _fight: Node
var _frame: int = 0
var _phase: String = "boot"
var _exit_code: int = 0


func _initialize() -> void:
	_parse_args()
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("shots: failed to load %s" % _scene_path)
		quit(1)
		return
	_fight = packed.instantiate()
	root.add_child(_fight)


func _process(_dt: float) -> bool:
	_frame += 1
	match _phase:
		"boot":
			## fight_view._ready has run after the first idle frame.
			if _frame >= _boot_frames:
				if not _apply_setup():
					quit(_exit_code)
					return true
				_frame = 0
				_phase = "settle"
		"settle":
			if _frame >= _wait_frames:
				_capture_and_probe()
				_phase = "done"
				quit(_exit_code)
				return true
	return false


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--setup="):
			_setup = arg.substr("--setup=".length())
			_setup_given = true
		elif arg.begins_with("--out="):
			_out_path = arg.substr("--out=".length())
		elif arg.begins_with("--scene="):
			_scene_path = arg.substr("--scene=".length())
		elif arg.begins_with("--do="):
			_dos.append(arg.substr("--do=".length()))
		elif arg.begins_with("--hook="):
			_hook_path = arg.substr("--hook=".length())
		elif arg.begins_with("--crop="):
			_crop = arg.substr("--crop=".length()).split(",")
		elif arg.begins_with("--zoom="):
			_zoom = maxi(1, int(arg.substr("--zoom=".length())))
		elif arg.begins_with("--probe="):
			_pixel_probes.append(arg.substr("--probe=".length()))
		elif arg.begins_with("--warmup="):
			_boot_frames = maxi(1, int(arg.substr("--warmup=".length())))
		elif arg.begins_with("--settle="):
			_wait_frames = maxi(1, int(arg.substr("--settle=".length())))
	## Any ad-hoc option means "just show me this state", not the named regression setup.
	if not _setup_given and (
		not _dos.is_empty() or not _hook_path.is_empty() or not _crop.is_empty()
		or not _pixel_probes.is_empty() or _scene_path != "res://scenes/main.tscn"
	):
		_setup = "adhoc"


func _apply_setup() -> bool:
	match _setup:
		"street_watch", "street_ap_spent":
			return _setup_street_watch()
		"street_yaw180":
			return _setup_street_yaw180()
		"terrace_flooded", "terrace_falling", "terrace_roof_cutaway":
			return _setup_terrace()
		"terrace_water_bare", "terrace_falling_bare":
			return _setup_terrace_water_bare()
		"terrace_fog_unknown":
			return _setup_terrace_fog_unknown()
		"terrace_fog_peeled":
			return _setup_terrace_fog_peeled()
		"street_fog_known_quiet":
			return _setup_street_fog_known_quiet()
		"adhoc":
			return _setup_adhoc()
		_:
			push_error("shots: unknown setup '%s'" % _setup)
			_exit_code = 1
			return false


func _setup_adhoc() -> bool:
	if not _hook_path.is_empty():
		var hook_script := load(_hook_path) as GDScript
		if hook_script == null:
			push_error("shots: cannot load hook %s" % _hook_path)
			_exit_code = 1
			return false
		hook_script.new().setup(_fight)
	for text in _dos:
		var expr := Expression.new()
		if expr.parse(text) != OK:
			push_error("shots: --do parse error in '%s': %s" % [text, expr.get_error_text()])
			_exit_code = 1
			return false
		expr.execute([], _fight, true)
		if expr.has_execute_failed():
			push_error("shots: --do failed: '%s': %s" % [text, expr.get_error_text()])
			_exit_code = 1
			return false
	return true


func _setup_street_watch() -> bool:
	## Piet (selected) sets a rifle Watch toward (10,5); AP drops 6 → 3.
	## A Watch needs phases (GDD §3.1) and the street opens out of contact, so start them the
	## way the rules do rather than poke a flag.
	Contact.begin(_fight._state)
	_fight._hover = _WATCH_HOVER
	_fight._try_watch()
	var piet: Unit = _fight._state.get_unit(1)
	if piet == null or _fight._state.live_watch_for(1) == null:
		push_error("shots: Watch did not land on Piet")
		_exit_code = 1
		return false
	if piet.ap != RulesConstants.AP_POOL - RulesConstants.WATCH_COST:
		push_error("shots: expected AP %d after Watch, got %d" % [
			RulesConstants.AP_POOL - RulesConstants.WATCH_COST, piet.ap
		])
		_exit_code = 1
		return false
	## Keep hover stable so the next process ticks do not wipe the read.
	_fight._hover = _WATCH_HOVER
	_fight._refresh_queries()
	_fight._draw_cones()
	_fight._draw_preview()
	_fight._draw_overlay_labels()
	_fight._sync_hud()
	return true


func _setup_street_yaw180() -> bool:
	## Yaw 180: tall quay between camera and Piet (plan 3.1). Hover a masonry cell
	## so the cover word stays masonry while the quay is faded.
	var rig = _fight.get_node_or_null("CameraRig")
	if rig == null:
		push_error("shots: CameraRig missing")
		_exit_code = 1
		return false
	rig.yaw_index = 2
	rig.peek_deg = 0.0
	rig.apply_pose()
	_fight._hover = Vector3i(6, 3, 0)
	_fight._refresh_queries()
	_fight._draw_preview()
	_fight._draw_overlay_labels()
	_fight._sync_hud()
	## Snap fade so settle frames are not racing the ease.
	if _fight._wall_fade != null and _fight._camera != null:
		_fight._wall_fade.snap(
			_fight._camera.global_position,
			_fight._friendly_heads(),
			_fight._bowl,
			_fight._cutaway_z
		)
	return true


func _setup_terrace() -> bool:
	## Terrace shots boot via --bowl=terrace on the capture command line (shots.sh).
	## Reinstate the water step / cutaway the named setup asks for.
	if str(_fight.get("_bowl_id")) != "terrace":
		push_error("shots: terrace setup needs --bowl=terrace (got bowl_id=%s)" % _fight.get("_bowl_id"))
		_exit_code = 1
		return false
	match _setup:
		"terrace_flooded", "terrace_water_bare":
			_fight._state.map.water_step = Taxonomy.WaterStep.FLOODED
		"terrace_falling", "terrace_falling_bare":
			_fight._state.map.water_step = Taxonomy.WaterStep.FALLING
		"terrace_roof_cutaway":
			_fight._state.map.water_step = Taxonomy.WaterStep.FLOODED
			_fight._set_cutaway(1)
	_fight._sync_water_from_map()
	_fight._hover = Vector3i(4, 5, 2)
	_fight._selected_id = 4 ## roof body
	_fight._redraw()
	return true


func _setup_terrace_water_bare() -> bool:
	## Flooded water with nothing drawn on it, so the water probe reads only the water.
	if not _setup_terrace():
		return false
	for overlay in ["Cones", "OverlayLabels", "Preview", "Units", "Selection"]:
		var node: Node3D = _fight.get_node_or_null(overlay)
		if node != null:
			node.visible = false
	return true


func _setup_terrace_fog_unknown() -> bool:
	## Opening peel only: far rooms stay Unknown (draw nothing). Needs --bowl=terrace.
	if str(_fight.get("_bowl_id")) != "terrace":
		push_error("shots: terrace_fog_unknown needs --bowl=terrace")
		_exit_code = 1
		return false
	_fight._hover = Vector3i(2, 3, 0)
	_fight._selected_id = 1
	_fight._redraw()
	return true


func _setup_terrace_fog_peeled() -> bool:
	## Peel a line into the authored interior clan so an occupant appears from vision, not arrival.
	if str(_fight.get("_bowl_id")) != "terrace":
		push_error("shots: terrace_fog_peeled needs --bowl=terrace")
		_exit_code = 1
		return false
	const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")
	var seer: Unit = _fight._state.get_unit(FloodedTerrace.P1)
	var clan: Unit = _fight._state.get_unit(FloodedTerrace.ROOF_CLAN)
	if seer == null or clan == null:
		push_error("shots: missing seer or roof clan")
		_exit_code = 1
		return false
	seer.cell = clan.cell
	_fight._state.knowledge.peel(_fight._state.map, _fight._state)
	_fight._selected_id = FloodedTerrace.P1
	_fight._hover = clan.cell
	_fight._cutaway_z = _fight._max_z
	_fight._redraw()
	return true


func _setup_street_fog_known_quiet() -> bool:
	## Wall mid-street, squad east of it: west freezes Known-quiet with the ageing veil.
	var map: BowlMap = _fight._state.map
	for y in range(0, 6):
		map.set_cell(Vector3i(8, y, 0), Cell.new(Taxonomy.CoverMaterial.MASONRY))
	var piet: Unit = _fight._state.get_unit(1)
	piet.cell = Vector3i(12, 3, 0)
	_fight._state.knowledge.peel(map, _fight._state)
	_fight._selected_id = 1
	_fight._hover = Vector3i(12, 3, 0)
	_fight._redraw()
	return true


func _capture_and_probe() -> void:
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("shots: viewport image is null")
		_exit_code = 1
		return
	if img.is_empty() or _is_blank(img):
		push_error("shots: the frame is empty. Headless renderer, or no display?")
		_exit_code = 1
		return
	var abs_out: String
	if _out_path.begins_with("res://") or _out_path.begins_with("user://"):
		abs_out = ProjectSettings.globalize_path(_out_path)
	elif _out_path.is_absolute_path():
		abs_out = _out_path
	else:
		abs_out = ProjectSettings.globalize_path("res://").path_join(_out_path)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var err := img.save_png(abs_out)
	if err != OK:
		push_error("shots: save_png failed (%d) → %s" % [err, abs_out])
		_exit_code = 1
		return
	print("shots: wrote %s (%dx%d)" % [abs_out, img.get_width(), img.get_height()])
	_save_crop(img, abs_out)
	_print_pixel_probes(img)

	match _setup:
		"street_watch":
			_probe_cone_not_opaque(img)
		"street_ap_spent":
			_probe_spent_ap_darker(img)
		"street_yaw180":
			_probe_quay_faded()
		"terrace_water_bare":
			_probe_water_not_zfighting(img)
		"terrace_falling_bare":
			_probe_falling_shows_bottom(img)
		_:
			pass


## Guards the cream-cylinder / opaque fallback when watch_cone.gdshader fails to compile.
func _probe_cone_not_opaque(img: Image) -> void:
	var cones: Node = _fight.get_node_or_null("Cones")
	if cones == null or cones.get_child_count() == 0:
		push_error("shots: no cone mesh to probe")
		_exit_code = 1
		return
	var cone: Node3D = cones.get_child(0) as Node3D
	var cam: Camera3D = _fight._camera
	if cam == null:
		push_error("shots: no camera")
		_exit_code = 1
		return
	var screen: Vector2 = cam.unproject_position(cone.global_position)
	var c := _sample(img, screen)
	## Working shader is mostly see-through over the street (lum ~0.5 here).
	## Compile-fallback draws an opaque light shell (lum ~0.75+).
	if c.get_luminance() > 0.68:
		push_error(
			"shots: cone centre looks opaque (shader fallback?) at %s color=%s lum=%s" % [
				screen, c, c.get_luminance()
			]
		)
		_exit_code = 1
		return
	print("shots: cone probe ok at %s color=%s lum=%s" % [screen, c, c.get_luminance()])


## Guards mint_key dropping modulate (`COLOR = c`), which equalises spent and lit pips.
func _probe_spent_ap_darker(img: Image) -> void:
	var hud = _fight._hud
	var row: HBoxContainer = hud._ap_row
	if row == null or row.get_child_count() < 4:
		push_error("shots: AP row missing pips")
		_exit_code = 1
		return
	## After Watch: indices 0..2 lit, 3..5 spent (pool 6, remaining 3).
	var lit_ctrl: Control = row.get_child(0) as Control
	var spent_ctrl: Control = row.get_child(3) as Control
	var lit_l := _sample_rect_max_luminance(img, lit_ctrl.get_global_rect())
	var spent_l := _sample_rect_max_luminance(img, spent_ctrl.get_global_rect())
	if spent_l >= lit_l * 0.75:
		push_error(
			"shots: spent AP pip not darker than lit (modulate bug?) lit=%s spent=%s" % [lit_l, spent_l]
		)
		_exit_code = 1
		return
	print("shots: AP probe ok lit=%s spent=%s" % [lit_l, spent_l])


## Plan 3.1 — yaw 180 must fade the tall quay; hover cover word stays masonry.
func _probe_quay_faded() -> void:
	var best := 0.0
	var bowl = _fight._bowl
	if bowl == null:
		push_error("shots: bowl missing")
		_exit_code = 1
		return
	for n in bowl.get_children():
		if not n.has_meta("polder_piece"):
			continue
		if str(n.get_meta("polder_piece")) != "env_canal_wall_tall":
			continue
		for gi in n.find_children("*", "GeometryInstance3D", true, false):
			best = maxf(best, (gi as GeometryInstance3D).transparency)
	if best < 0.5:
		push_error("shots: tall quay not faded at yaw 180 (transparency=%s)" % best)
		_exit_code = 1
		return
	var tag: int = bowl.cover_tag_at(Vector3i(6, 3, 0))
	if tag != Taxonomy.CoverMaterial.MASONRY:
		push_error("shots: hover cover tag changed under fade (got %s)" % tag)
		_exit_code = 1
		return
	print("shots: yaw180 quay fade ok transparency=%s cover=masonry" % best)


## Street corners in frame, and how many read bright. Samples the surface at cell corners across
## the known street, clear of the HUD strips (setups terrace_water_bare / terrace_falling_bare).
## Returns {"bright", "n", "spread"}: corners over 0.40 luminance, corners sampled, and the standard
## deviation of their luminance. Empty with an error set when there is nothing to sample.
func _street_corner_brightness(img: Image) -> Dictionary:
	var cam: Camera3D = _fight._camera
	var water: Node3D = _fight.get_node_or_null("Water")
	if cam == null or water == null:
		push_error("shots: water probe needs a camera and a Water node")
		_exit_code = 1
		return {"bright": 0, "n": 0, "spread": 0.0}
	var known: Dictionary = _fight._state.knowledge.known_cells(_fight._state)
	var lums: Array[float] = []
	var bright := 0
	for cell in known.keys():
		if cell.z != 0:
			continue
		var p := PresentationCoords.world(cell) + Vector3(1.0, 0.0, 1.0)
		p.y = water.position.y
		var screen := cam.unproject_position(p)
		if screen.x < 20 or screen.x > img.get_width() - 20 or screen.y < 110 or screen.y > 560:
			continue
		var lum := _sample(img, screen).get_luminance()
		lums.append(lum)
		if lum > 0.40:
			bright += 1
	var mean := 0.0
	for l in lums:
		mean += l
	mean /= maxf(1.0, float(lums.size()))
	var variance := 0.0
	for l in lums:
		variance += (l - mean) * (l - mean)
	variance /= maxf(1.0, float(lums.size()))
	return {"bright": bright, "n": lums.size(), "spread": sqrt(variance)}


## Guards the water plane sitting coplanar with the slab tops (z-fight). Flooded water is dark and
## nearly opaque, so the street is gone; where it fights the slabs, pale shards cut through.
func _probe_water_not_zfighting(img: Image) -> void:
	var stats := _street_corner_brightness(img)
	print("shots: flooded probe %d of %d street corners bright, spread %.3f" % [stats.bright, stats.n, stats.spread])
	if stats.n < 20:
		push_error("shots: flooded probe found only %d street corners in frame" % stats.n)
		_exit_code = 1
		return
	if float(stats.bright) / float(stats.n) > 0.10:
		push_error("shots: Flooded water looks broken: %d of %d street corners bright (z-fight, or the bottom is showing)" % [stats.bright, stats.n])
		_exit_code = 1


## Guards UI 3's non-negotiable: Falling never reads as Flooded, and not by colour or motion alone.
## Chest-deep water is murky but the bottom shows through it, so the pale slabs read; deep water
## hides them. If Falling goes opaque and dark it becomes Flooded, and a Falling street that draws
## as ground is a lie the other way.
func _probe_falling_shows_bottom(img: Image) -> void:
	var stats := _street_corner_brightness(img)
	print("shots: falling probe %d of %d street corners bright, spread %.3f" % [stats.bright, stats.n, stats.spread])
	if stats.n < 20:
		push_error("shots: falling probe found only %d street corners in frame" % stats.n)
		_exit_code = 1
		return
	if float(stats.bright) / float(stats.n) < 0.50:
		push_error("shots: Falling water hides the bottom like Flooded: %d of %d street corners bright" % [stats.bright, stats.n])
		_exit_code = 1
	elif stats.spread < FALLING_BOTTOM_MIN_SPREAD:
		push_error("shots: Falling water is a flat sheet, not water over a street: spread %.3f" % stats.spread)
		_exit_code = 1


func _save_crop(img: Image, abs_out: String) -> void:
	if _crop.size() != 4:
		return
	var r := Rect2i(int(_crop[0]), int(_crop[1]), int(_crop[2]), int(_crop[3]))
	var part := img.get_region(r)
	part.resize(part.get_width() * _zoom, part.get_height() * _zoom, Image.INTERPOLATE_NEAREST)
	var crop_path := abs_out.get_basename() + "_crop.png"
	part.save_png(crop_path)
	print("shots: crop %s %s x%d" % [crop_path, r, _zoom])


func _print_pixel_probes(img: Image) -> void:
	for p in _pixel_probes:
		var xy := p.split(",")
		if xy.size() != 2:
			continue
		var x := int(xy[0])
		var y := int(xy[1])
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			print("shots: probe %d,%d is outside the frame" % [x, y])
			continue
		var c := img.get_pixel(x, y)
		print("shots: probe %d,%d = #%s (r%d g%d b%d)" % [x, y, c.to_html(false), c.r8, c.g8, c.b8])


## A dummy renderer returns one flat colour. Sample a grid rather than every pixel.
func _is_blank(img: Image) -> bool:
	var first := img.get_pixel(0, 0)
	for gx in range(1, 8):
		for gy in range(1, 8):
			var px := img.get_pixel(img.get_width() * gx / 8, img.get_height() * gy / 8)
			if not px.is_equal_approx(first):
				return false
	return true


func _sample(img: Image, screen: Vector2) -> Color:
	var x := clampi(int(screen.x), 0, img.get_width() - 1)
	var y := clampi(int(screen.y), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


func _sample_rect_max_luminance(img: Image, rect: Rect2) -> float:
	var x0 := clampi(int(rect.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(rect.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(rect.position.x + rect.size.x) - 1, 0, img.get_width() - 1)
	var y1 := clampi(int(rect.position.y + rect.size.y) - 1, 0, img.get_height() - 1)
	if x1 < x0 or y1 < y0:
		return 0.0
	var best := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			best = maxf(best, img.get_pixel(x, y).get_luminance())
	return best
