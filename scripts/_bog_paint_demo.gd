extends Node2D
## BOG PAINT DEMO (owner-authorized visual, 2026-07-06)
## A standalone, dedicated demo level that paints the biome-anchored bog props
## (generated through the sorceress suit: interpret one-sprite-per-cell split ->
## bog palette-lock -> gauntlet) onto a bog-mud ground in a COMPOSED, DENSE,
## COHERENT vignette per design/LEVEL_PAINTING_BIBLE.md. It does NOT touch
## zone_defs.gd — the live zones stay untouched.
##
## Boot windowed to capture:
##   RH_TIME=dusk RH_ZOOM=0.72 RH_NOHUD=1 RH_SHOT=_screens/bog_level_painted.png \
##     "$GODOT" res://scenes/_bog_paint_demo.tscn
##
## The story: a rotted-stump cluster (hero) ringed with toadstools and tucked
## logs; a fallen hollow log below it; a ring of sunken bog-stones with a leaning
## marker to the east; reed/root brambles along a dark stagnant-water pool in the
## south-west. Cluster cohesion + footprint spacing + biome-legal (bog only), no
## repetition salad (round-robin picks), honest travel space between clusters.

const DEMO_DIR := "res://assets/art/world/dead_swamp/_bog_demo"
const MUD := "res://assets/art/world/dead_swamp/mud_96x128.png"
const WORLD_W := 1600
const WORLD_H := 920

var _rng := RandomNumberGenerator.new()
var _by_kind: Dictionary = {}     # kind -> Array[Dictionary]{tex, subject, foot}
var _cursor: Dictionary = {}      # kind -> round-robin index (no asset spam)
var _ysort: Node2D
var _sway: Array = []


func _ready() -> void:
	_rng.seed = 20260706
	get_window().size = Vector2i(1280, 720)
	_load_props()
	_build_ground()
	_build_water()
	_build_ysort()
	_paint_stump_cluster(Vector2(560, 450))
	_paint_fallen_log(Vector2(720, 610))
	_paint_mid_cluster(Vector2(990, 650))
	_paint_stone_ring(Vector2(1250, 430))
	_paint_far_anchor(Vector2(900, 235))
	_paint_reed_shore()
	_scatter_ground_life()
	_build_mood()
	_build_camera()
	_animate()
	_maybe_screenshot()


# ---------------------------------------------------------------- props
func _load_props() -> void:
	var man_path := DEMO_DIR + "/manifest.json"
	var entries: Array = []
	if FileAccess.file_exists(man_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(man_path))
		if parsed is Array:
			entries = parsed
	if entries.is_empty():
		var d := DirAccess.open(DEMO_DIR)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".png"):
					entries.append({"file": f, "subject": f, "kind": ""})
	for e in entries:
		var f := String(e.get("file", ""))
		var tex: Texture2D = load(DEMO_DIR + "/" + f)
		if tex == null:
			continue
		var subj := String(e.get("subject", f))
		var kind := String(e.get("kind", ""))
		if kind.is_empty():
			kind = _classify(subj)
		_by_kind.get_or_add(kind, [])
		_by_kind[kind].append({"tex": tex, "subject": subj, "foot": _footprint(kind)})
	# shuffle each kind so round-robin order isn't id-sorted
	for k in _by_kind:
		(_by_kind[k] as Array).shuffle()
	print("[bog_demo] loaded props by kind: ", _kind_counts())


func _kind_counts() -> Dictionary:
	var out: Dictionary = {}
	for k in _by_kind:
		out[k] = (_by_kind[k] as Array).size()
	return out


func _classify(subj: String) -> String:
	var s := subj.to_lower()
	if "stump" in s: return "stump"
	if "toadstool" in s or "mushroom" in s: return "mushroom"
	if "log" in s or "root" in s or "trunk" in s: return "log"
	if "cairn" in s or "rune" in s or "standing" in s or "marker" in s or "obelisk" in s: return "cairn"
	if "reed" in s or "cattail" in s or "bramble" in s or "vine" in s or "thorn" in s: return "reed"
	return "stone"


func _footprint(kind: String) -> float:
	match kind:
		"stump": return 168.0
		"log": return 210.0
		"stone": return 172.0
		"cairn": return 150.0
		"reed": return 120.0
		"mushroom": return 92.0
		_: return 120.0


func _pick(kind: String, fallback: Array = []) -> Dictionary:
	var arr: Array = _by_kind.get(kind, [])
	var use_kind := kind
	if arr.is_empty():
		for fb in fallback:
			if not (_by_kind.get(fb, []) as Array).is_empty():
				arr = _by_kind[fb]; use_kind = fb; break
	if arr.is_empty():
		for k in _by_kind:
			if not (_by_kind[k] as Array).is_empty():
				arr = _by_kind[k]; use_kind = k; break
	if arr.is_empty():
		return {}
	var idx := int(_cursor.get(use_kind, 0)) % arr.size()   # round-robin: cycle all before repeat
	_cursor[use_kind] = idx + 1
	return arr[idx]


func _place(entry: Dictionary, pos: Vector2, scale_jit: float = 0.12, rot: float = 0.0,
		sway: bool = false, z_bias: int = 0) -> Sprite2D:
	if entry.is_empty():
		return null
	var spr := Sprite2D.new()
	var tex: Texture2D = entry["tex"]
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var foot: float = float(entry["foot"])
	var base := foot / float(max(tex.get_width(), tex.get_height()))
	var s := base * _rng.randf_range(1.0 - scale_jit, 1.0 + scale_jit)
	spr.scale = Vector2(s, s)
	spr.position = pos
	spr.rotation = rot
	spr.offset = Vector2(0, -tex.get_height() * 0.5 + 1)   # feet-anchored for y-sort
	spr.z_index = z_bias
	# a soft contact shadow so props sit IN the mud, not float on it
	var disp := float(max(tex.get_width(), tex.get_height())) * s
	_ysort.add_child(_contact_shadow(pos, disp * 0.42))
	_ysort.add_child(spr)
	if sway:
		_sway.append(spr)
	return spr


func _contact_shadow(pos: Vector2, r: float) -> Polygon2D:
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	var steps := 12
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(pos + Vector2(cos(a) * r * 0.9, 6 + sin(a) * r * 0.34))
	sh.polygon = pts
	sh.color = Color(0.05, 0.05, 0.06, 0.34)
	sh.z_index = -2
	return sh


# ---------------------------------------------------------------- ground
func _build_ground() -> void:
	var g := Sprite2D.new()
	g.name = "Ground"
	g.texture = load(MUD)
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, WORLD_W + 400, WORLD_H + 400)
	g.centered = false
	g.position = Vector2(-200, -200)
	g.z_index = -20
	g.modulate = Color(0.92, 0.88, 0.84)
	add_child(g)
	# soft organic peat/muck stains (no wallpaper — bible III.9)
	var decals := Node2D.new()
	decals.name = "GroundDecals"
	decals.z_index = -15
	add_child(decals)
	var n := int((WORLD_W * WORLD_H) / 78000.0)
	for i in range(n):
		var cx := _rng.randf_range(40, WORLD_W - 40)
		var cy := _rng.randf_range(40, WORLD_H - 40)
		var rxr := _rng.randf_range(44, 108)
		var col: Color
		if _rng.randf() < 0.6:
			col = Color(0.15, 0.125, 0.095, _rng.randf_range(0.16, 0.30))   # wet peat
		else:
			col = Color(0.33, 0.32, 0.19, _rng.randf_range(0.09, 0.17))     # olive muck
		decals.add_child(_soft_blob(Vector2(cx, cy), rxr, rxr * _rng.randf_range(0.55, 0.8), col))


func _soft_blob(center: Vector2, rx: float, ry: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var steps := 14
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		var jit := _rng.randf_range(0.78, 1.18)
		pts.append(center + Vector2(cos(a) * rx * jit, sin(a) * ry * jit))
	p.polygon = pts
	p.color = col
	return p


func _build_water() -> void:
	# dark stagnant-water pool in the SW corner — the reed shore hangs off it.
	var pool := Polygon2D.new()
	pool.name = "Pool"
	pool.z_index = -14
	pool.polygon = PackedVector2Array([
		Vector2(-40, 690), Vector2(210, 636), Vector2(430, 656), Vector2(560, 720),
		Vector2(600, 830), Vector2(520, 960), Vector2(-40, 960)])
	pool.color = Color(0.095, 0.13, 0.12, 1.0)
	add_child(pool)
	var bank := Line2D.new()
	bank.z_index = -13
	bank.points = PackedVector2Array([
		Vector2(-40, 690), Vector2(210, 636), Vector2(430, 656), Vector2(560, 720), Vector2(600, 830)])
	bank.width = 30.0
	bank.default_color = Color(0.16, 0.135, 0.10, 0.85)
	bank.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(bank)
	var sheen := Line2D.new()
	sheen.name = "Sheen"
	sheen.z_index = -12
	sheen.points = PackedVector2Array([
		Vector2(80, 780), Vector2(280, 740), Vector2(440, 790), Vector2(520, 880)])
	sheen.width = 8.0
	sheen.default_color = Color(0.46, 0.56, 0.58, 0.16)
	sheen.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(sheen)


func _build_ysort() -> void:
	_ysort = Node2D.new()
	_ysort.name = "Props"
	_ysort.y_sort_enabled = true
	add_child(_ysort)


# ---------------------------------------------------------------- clusters
func _paint_stump_cluster(center: Vector2) -> void:
	# the hero: a rotted-stump cluster ringed with toadstools + tucked logs.
	# tight cohesion (bible II.4), the zone's curiosity site (bible V.15/16).
	var hero := _pick("stump", ["log"])
	_place(hero, center, 0.06)                                   # the biggest stump, dead centre
	var ring := [Vector2(-130, 40), Vector2(120, 20), Vector2(-40, -96), Vector2(90, 120)]
	for off in ring:
		_place(_pick("stump", ["log"]), center + off + _jit(20), 0.12)
	# two logs tucked between the stumps
	_place(_pick("log"), center + Vector2(-180, 96) + _jit(16), 0.1, _rng.randf_range(-0.18, 0.18))
	_place(_pick("log"), center + Vector2(150, 118) + _jit(16), 0.1, _rng.randf_range(-0.18, 0.18))
	# a partial ring of toadstools on the near side of the hero stump (jittered, not
	# a grid — bible II.8), so the stump reads as the star, not the fungus
	var m := 3
	for i in range(m):
		var a := PI * (0.15 + 0.7 * float(i) / float(max(1, m - 1))) + _rng.randf_range(-0.2, 0.2)
		var rr := _rng.randf_range(100, 134)
		_place(_pick("mushroom"), center + Vector2(cos(a) * rr, 52 + sin(a) * rr * 0.6), 0.16)


func _paint_fallen_log(pos: Vector2) -> void:
	# a fallen hollow log below the cluster + a couple mushrooms sprouting along it
	_place(_pick("log"), pos, 0.06, _rng.randf_range(-0.12, 0.12))
	for i in range(2):
		_place(_pick("mushroom"), pos + Vector2(_rng.randf_range(-80, 90), _rng.randf_range(10, 40)), 0.16)


func _paint_mid_cluster(center: Vector2) -> void:
	# a connective satellite between hero and the stone anchor so the centre isn't
	# dead (bible I.1 40-second rule): a log, a stump satellite, a couple toadstools
	_place(_pick("log"), center, 0.08, _rng.randf_range(-0.16, 0.16))
	_place(_pick("stump", ["log"]), center + Vector2(-70, -80) + _jit(16), 0.12)
	for i in range(2):
		_place(_pick("mushroom"), center + Vector2(_rng.randf_range(-70, 90), _rng.randf_range(6, 44)), 0.16)


func _paint_stone_ring(center: Vector2) -> void:
	# sunken bog-stones with a leaning marker — a second anchor + satellites (bible II.7)
	_place(_pick("stone", ["cairn"]), center, 0.08)
	_place(_pick("stone", ["cairn"]), center + Vector2(150, 70) + _jit(18), 0.12)
	# the single marker stands ONCE, leaning, beside the stones
	_place(_pick("cairn", ["stone"]), center + Vector2(-120, 84), 0.06, _rng.randf_range(0.05, 0.16))
	# moss + a stray toadstool creeping between the stones
	_place(_pick("mushroom"), center + Vector2(60, 128) + _jit(20), 0.16)
	_place(_pick("reed", ["mushroom"]), center + Vector2(-40, 150) + _jit(16), 0.18)


func _paint_far_anchor(pos: Vector2) -> void:
	# a lone rotted stump NE so every quadrant carries an anchor (bible II.7)
	_place(_pick("stump", ["log"]), pos, 0.08)
	_place(_pick("mushroom"), pos + Vector2(54, 60) + _jit(14), 0.16)


func _paint_reed_shore() -> void:
	# generated root/bramble props + procedural cattail reeds hugging the pool rim
	# (cluster cohesion, bible II.4; edge blending, bible III.10)
	var rim := PackedVector2Array([
		Vector2(120, 620), Vector2(280, 600), Vector2(430, 616), Vector2(540, 676), Vector2(596, 770)])
	for seg in range(rim.size() - 1):
		var a: Vector2 = rim[seg]
		var b: Vector2 = rim[seg + 1]
		for i in range(2):
			var t := (float(i) + _rng.randf_range(0.1, 0.9)) / 2.0
			var base := a.lerp(b, t)
			# generated bramble/root twig
			_place(_pick("reed", ["mushroom"]), base + Vector2(_rng.randf_range(-22, 22),
				_rng.randf_range(-10, 26)), 0.2, _rng.randf_range(-0.08, 0.08), true)
			# a clump of procedural cattail reeds beside it (tall blade + brown head)
			_reed_clump(base + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-6, 30)))
	# a few reeds standing in the shallows
	for i in range(4):
		_reed_clump(Vector2(_rng.randf_range(120, 520), _rng.randf_range(760, 900)))


func _reed_clump(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.y_sort_enabled = false
	node.z_index = 0
	_ysort.add_child(node)
	var blades := _rng.randi_range(4, 7)
	for i in range(blades):
		var bx := _rng.randf_range(-16, 16)
		var hgt := _rng.randf_range(46, 84)
		var lean := _rng.randf_range(-6, 6)
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(bx - 2.4, 0), Vector2(bx + lean - 1.0, -hgt), Vector2(bx + lean + 1.0, -hgt),
			Vector2(bx + 2.4, 0)])
		var gg := _rng.randf_range(0.30, 0.46)
		blade.color = Color(gg * 0.62, gg, gg * 0.40, 0.95)
		node.add_child(blade)
		if _rng.randf() < 0.5:                      # brown cattail seed head
			var head := Polygon2D.new()
			head.polygon = PackedVector2Array([
				Vector2(bx + lean - 2.6, -hgt), Vector2(bx + lean + 2.6, -hgt),
				Vector2(bx + lean + 2.2, -hgt - 18), Vector2(bx + lean - 2.2, -hgt - 18)])
			head.color = Color(0.32, 0.22, 0.12, 0.98)
			node.add_child(head)
	_sway.append(node)


func _scatter_ground_life() -> void:
	# low ground-clutter in the honest travel space so nothing reads dead (bible I.1).
	# Reeds belong at the water only, so dry travel space gets a few stray toadstools.
	for i in range(2):
		var p := Vector2(_rng.randf_range(300, WORLD_W - 260), _rng.randf_range(230, WORLD_H - 240))
		_place(_pick("mushroom"), p, 0.2)
	# tiny green grass tufts (matches the bog_ref grass specks)
	var tufts := Node2D.new()
	tufts.name = "Tufts"
	tufts.z_index = -1
	_ysort.add_child(tufts)
	for i in range(60):
		var t := Polygon2D.new()
		var gx := _rng.randf_range(50, WORLD_W - 50)
		var gy := _rng.randf_range(150, WORLD_H - 70)
		var hgt := _rng.randf_range(6, 13)
		t.polygon = PackedVector2Array([
			Vector2(-4, 0), Vector2(-1, -hgt), Vector2(1, -hgt * 0.8), Vector2(2, -hgt), Vector2(4, 0)])
		t.position = Vector2(gx, gy)
		var gg := _rng.randf_range(0.26, 0.42)
		t.color = Color(gg * 0.66, gg, gg * 0.4, 0.8)
		tufts.add_child(t)


func _jit(r: float) -> Vector2:
	return Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))


# ---------------------------------------------------------------- mood + camera
func _build_mood() -> void:
	var mode := OS.get_environment("RH_TIME").to_lower()
	var tint := Color(0.71, 0.63, 0.66)          # dusk default (readable, moody)
	if mode == "night":
		tint = Color(0.42, 0.45, 0.58)
	elif mode.is_valid_float():
		var hh := mode.to_float()
		if hh >= 20.0 or hh <= 5.0:
			tint = Color(0.40, 0.43, 0.56)
	var cm := CanvasModulate.new()
	cm.name = "Ambience"
	cm.color = tint
	add_child(cm)
	# low bog fog band drifting over the water (cool) — mood + motion
	var fog := Polygon2D.new()
	fog.name = "Fog"
	fog.polygon = PackedVector2Array([
		Vector2(-100, 470), Vector2(WORLD_W + 100, 470),
		Vector2(WORLD_W + 100, WORLD_H + 100), Vector2(-100, WORLD_H + 100)])
	fog.color = Color(0.54, 0.58, 0.62, 0.09)
	fog.z_index = 40
	add_child(fog)
	# edge vignette so the eye lands on the clusters
	var vig := Node2D.new()
	vig.z_index = 60
	add_child(vig)
	var strips := [
		[Rect2(-100, -100, WORLD_W + 200, 130), Color(0, 0, 0, 0.42)],
		[Rect2(-100, WORLD_H - 40, WORLD_W + 200, 180), Color(0, 0, 0, 0.5)],
		[Rect2(-100, -100, 130, WORLD_H + 200), Color(0, 0, 0, 0.4)],
		[Rect2(WORLD_W - 120, -100, 240, WORLD_H + 200), Color(0, 0, 0, 0.42)]]
	for st in strips:
		var poly := Polygon2D.new()
		var r: Rect2 = st[0]
		poly.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0),
			r.position + r.size, r.position + Vector2(0, r.size.y)])
		poly.color = st[1]
		vig.add_child(poly)


func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Cam"
	var z := 0.72
	var ze := OS.get_environment("RH_ZOOM")
	if not ze.is_empty() and ze.to_float() > 0.01:
		z = ze.to_float()
	cam.zoom = Vector2(z, z)
	cam.position = Vector2(820, 468)
	add_child(cam)
	cam.make_current()


func _animate() -> void:
	for spr in _sway:
		var n := spr as Node2D
		if n == null:
			continue
		var amp := _rng.randf_range(0.025, 0.06)
		var tw := create_tween().set_loops()
		tw.tween_property(n, "rotation", amp, _rng.randf_range(1.7, 2.7)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation", -amp, _rng.randf_range(1.7, 2.7)).set_trans(Tween.TRANS_SINE)
	var sheen := get_node_or_null("Sheen")
	if sheen is CanvasItem:
		var tw2 := create_tween().set_loops()
		tw2.tween_property(sheen, "modulate:a", 0.45, 2.4).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(sheen, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- capture
func _maybe_screenshot() -> void:
	var path := OS.get_environment("RH_SHOT")
	if path.is_empty():
		return
	for i in range(12):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png(path)
		print("[bog_demo] RH_SHOT -> ", path, " (", err, ")")
	await get_tree().process_frame
	get_tree().quit()
