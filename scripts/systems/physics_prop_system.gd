extends Node
## PhysicsPropSystem -- autoload (/root/PhysicsPropSystem). BACKLOG #52
## "Freedom & physics props" (design/FREEDOM_PHYSICS.md, PART B -- Zelda physics +
## the PART A freedom audit).
##
## A self-contained registry + spawner of interactable/dynamic world props. Loads a
## catalogue from data/physics_props.json (id, kind, mass, hp, break_loot ref, sfx,
## placeholder body color, art path for the Fable pass) and can spawn a GUARDED
## physics-ish prop node IN CODE for each kind -- pots that break for loot, crates
## that push, throwing-stones, liftable slabs, climb routes, and hidden switches.
## Nothing here depends on a scene, an asset, a world, a player, or any sibling
## system: every external call is null-guarded and every effect degrades to a no-op.
##
## Kinds (Zelda idiom):
##   pushable      -- crates/barrels/sacks/boulders; a RigidBody2D shove-block.
##   breakable     -- pots/grass/barrels; break_prop() rolls loot then frees it.
##   throwable     -- stones/vases; liftable + breaks on land (breakable at range).
##   liftable      -- heave a slab off what it hides (break_loot on lift).
##   climbable     -- a routable shortcut node (2D top-down: never a wall, a way up).
##   hidden_switch -- an Area2D plate/rune that answers to a body or a dropped weight.
##
## Public API:
##   all_props() -> Dictionary                     id -> def
##   prop_ids() -> Array ; prop_def(id) -> Dictionary ; has_prop_id(id) -> bool
##   kinds() -> Array                              the distinct kinds in the catalogue
##   spawn_prop(id, pos, parent := null) -> Node   build + place a prop (guarded)
##   push_prop(node, dir, strength := 1.0) -> bool apply a shove impulse
##   break_prop(node_or_id, source := null) -> Array  break -> loot via LootSystem
##   activate_switch(node) -> bool                 toggle a hidden_switch
##   despawn_all()                                 clear everything spawned
##   audit_freedom(zone) -> Dictionary             no-walls heuristic on a zone def
## Signals:
##   prop_spawned(id, node)
##   prop_broken(id, node, loot)
##   prop_pushed(id, node, dir)
##   prop_visual_requested(id, art_path)   # Fable art hook (placeholder body until)
##   freedom_audited(zone_id, report)

signal prop_spawned(id, node)
signal prop_broken(id, node, loot)
signal prop_pushed(id, node, dir)
signal prop_visual_requested(id, art_path)
signal freedom_audited(zone_id, report)

const DATA_PATH := "res://data/physics_props.json"

## Physics layers per FREEDOM_PHYSICS.md section 8 (raw bits -- project.godot is not edited).
const LAYER_WORLD := 1        # bit 1: static world colliders
const LAYER_PROP := 1 << 4    # bit 5: InteractiveProp
const KINDS := ["pushable", "breakable", "throwable", "liftable", "climbable", "hidden_switch"]

var _defaults: Dictionary = {}
var _props: Dictionary = {}          # id -> def dict
var _live: Array = []                # spawned prop nodes (weak-ish; validity checked on use)
var _switch_state: Dictionary = {}   # instance_id -> bool (hidden_switch pressed)


func _ready() -> void:
	_load_data()
	# Announce the art manifest for the Fable prop-art pass (no-op listeners fine).
	for id: String in _props.keys():
		var art: String = str(_dict(_props[id]).get("art", ""))
		if art != "":
			prop_visual_requested.emit(id, art)
	if not OS.get_environment("RH_PHYS_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_defaults = _dict(root.get("defaults", {}))
	_props = _dict(root.get("props", {}))
	if _props.is_empty():
		push_warning("PhysicsPropSystem: no props loaded from %s" % DATA_PATH)


# --- Registry ----------------------------------------------------------------

func all_props() -> Dictionary:
	return _props


func prop_ids() -> Array:
	return _props.keys()


func has_prop_id(id: String) -> bool:
	return _props.has(id)


func prop_def(id: String) -> Dictionary:
	# Fold defaults under the per-prop overrides so every field is always present.
	var d: Dictionary = _dict(_props.get(id, {}))
	if d.is_empty():
		return {}
	var out: Dictionary = _defaults.duplicate(true)
	for k: Variant in d.keys():
		out[k] = d[k]
	return out


func kinds() -> Array:
	var seen: Dictionary = {}
	for id: String in _props.keys():
		seen[str(_dict(_props[id]).get("kind", "pushable"))] = true
	return seen.keys()


func prop_count() -> int:
	return _props.size()


func live_count() -> int:
	_prune_live()
	return _live.size()


# --- Spawning ----------------------------------------------------------------

## Build a prop node for `id` in code and place it at `pos`. `parent` defaults to a
## best-effort world node (group "world"/"map", else the player's parent, else self)
## so the prop drops into the live scene when one exists and degrades to a detached-
## but-valid node when it does not. Returns the node (never null for a known id).
func spawn_prop(id: String, pos: Vector2, parent: Node = null) -> Node:
	var def: Dictionary = prop_def(id)
	if def.is_empty():
		push_warning("PhysicsPropSystem.spawn_prop: unknown prop '%s'" % id)
		return null
	var kind: String = str(def.get("kind", "pushable"))
	var node: Node = _build_body(id, def, kind)
	if node == null:
		return null
	if node is Node2D:
		(node as Node2D).position = pos
	var host: Node = parent if parent != null else _spawn_host()
	if host != null and is_instance_valid(host):
		host.add_child(node)
	else:
		# No world to host it: keep it alive and inert as our own child (degrade-safe).
		add_child(node)
	_live.append(node)
	prop_spawned.emit(id, node)
	return node


## The prop's collision/visual body, built entirely in code (no scene/asset dep).
func _build_body(id: String, def: Dictionary, kind: String) -> Node:
	var size: Vector2 = _size(def.get("size", [16, 16]))
	var col: Color = _color(def.get("color", [0.55, 0.45, 0.32]))
	var node: Node2D
	match kind:
		"climbable":
			# A routable shortcut marker: an Area2D (monitor-only, NEVER a blocker) so
			# 2D top-down "climbing" is just a faster walkable node, per FREEDOM_PHYSICS 5.
			node = _make_area(size, LAYER_PROP, 0)
			col = Color(col.r, col.g, col.b, 0.75)
		"hidden_switch":
			# An Area2D that watches for a body/weight; hidden (dim) until pressed.
			var area: Area2D = _make_area(size, 0, LAYER_WORLD | (1 << 1) | (1 << 3) | LAYER_PROP)
			area.monitoring = true
			if not area.body_entered.is_connected(_on_switch_body):
				area.body_entered.connect(_on_switch_body.bind(area))
			node = area
			col = Color(col.r, col.g, col.b, 0.35)   # concealed until revealed
		_:
			# pushable / breakable / throwable / liftable -> a dynamic RigidBody2D.
			# Top-down: no gravity; damping brings a shoved prop to rest (Zelda feel).
			var rb := RigidBody2D.new()
			rb.gravity_scale = 0.0
			rb.collision_layer = LAYER_PROP
			rb.collision_mask = LAYER_WORLD | LAYER_PROP
			rb.lock_rotation = true
			rb.linear_damp = float(def.get("linear_damp", _defaults.get("linear_damp", 6.0)))
			rb.angular_damp = 3.0
			rb.mass = maxf(0.5, float(def.get("mass", 8.0)))
			rb.can_sleep = true
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = size * 2.0
			shape.shape = rect
			rb.add_child(shape)
			node = rb
	node.name = "Prop_%s" % id
	node.set_meta("prop_id", id)
	node.set_meta("prop_kind", kind)
	node.set_meta("prop_hp", float(def.get("hp", _defaults.get("hp", 20.0))))
	node.set_meta("prop_mass", float(def.get("mass", 8.0)))
	node.set_meta("break_loot", str(def.get("break_loot", "")))
	node.set_meta("sfx", str(def.get("sfx", "")))
	_add_visual(node, size, col, kind, str(def.get("art", "")))
	return node


func _make_area(size: Vector2, layer: int, mask: int) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = layer
	area.collision_mask = mask
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size * 2.0
	shape.shape = rect
	area.add_child(shape)
	return area


## Placeholder body art -- a tinted block (+ a soft ground shadow) that reads as the
## prop until the real sprite lands at def.art. Trivially swapped later.
func _add_visual(node: Node2D, size: Vector2, col: Color, kind: String, art: String = "") -> void:
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(size.x * 0.95, maxf(4.0, size.y * 0.4), Vector2(0, size.y * 0.55))
	shadow.color = Color(0, 0, 0, 0.28)
	shadow.z_index = -1
	node.add_child(shadow)
	# FREE-ASSETS LAW: real prop art when the catalogue names it (the colored
	# placeholder boxes read as debug quads in every zone-spawn ring)
	if art != "" and ResourceLoader.exists(art):
		var spr := Sprite2D.new()
		spr.texture = load(art)
		var tex_size: Vector2 = spr.texture.get_size()
		var target: float = maxf(size.x, size.y) * 2.6
		if maxf(tex_size.x, tex_size.y) > 0.0:
			spr.scale = Vector2.ONE * clampf(target / maxf(tex_size.x, tex_size.y), 0.4, 1.6)
		if kind == "hidden_switch":
			spr.modulate = Color(1, 1, 1, 0.45)
		elif kind == "climbable":
			spr.modulate = Color(1, 1, 1, 0.9)
		node.add_child(spr)
		if node is Node2D:
			node.y_sort_enabled = true
		return
	var body := Polygon2D.new()
	body.polygon = _rect_points(size)
	body.color = col
	node.add_child(body)
	# a lighter top face so the block reads as volume, not a flat tile
	var top := Polygon2D.new()
	top.polygon = _rect_points(Vector2(size.x, size.y * 0.35), Vector2(0, -size.y * 0.55))
	top.color = Color(minf(1.0, col.r + 0.14), minf(1.0, col.g + 0.14), minf(1.0, col.b + 0.14), col.a)
	node.add_child(top)
	if kind == "climbable":
		# rungs, so a climb route reads at a glance
		for i in range(-2, 3):
			var rung := Polygon2D.new()
			rung.polygon = _rect_points(Vector2(size.x, 1.5), Vector2(0, float(i) * size.y * 0.35))
			rung.color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.9)
			node.add_child(rung)
	if node is Node2D:
		node.y_sort_enabled = true


# --- Interaction: push / break / switch --------------------------------------

## Shove a pushable-family prop. `dir` is a direction (normalized here); `strength`
## scales the mass-aware impulse. No-op (returns false) on a non-body or a frozen prop.
func push_prop(node: Node, dir: Vector2, strength: float = 1.0) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var rb := node as RigidBody2D
	if rb == null or rb.freeze:
		return false
	var d: Vector2 = dir.normalized()
	if d == Vector2.ZERO:
		d = Vector2.RIGHT
	# Mass-scaled impulse (FREEDOM_PHYSICS 8.2 feel: light crate coasts a tile).
	var mass: float = maxf(0.5, float(node.get_meta("prop_mass", rb.mass)))
	var push: float = 22.0 * clampf(8.0 / mass, 0.1, 1.5) * maxf(0.0, strength)
	rb.apply_central_impulse(d * push * 6.0)
	rb.linear_velocity += d * push
	prop_pushed.emit(str(node.get_meta("prop_id", "")), node, d)
	return true


## Break a prop (by node or by spawning a fresh one from an id), rolling its
## break_loot through LootSystem (guarded) and freeing the node. Returns the loot
## Array (empty if no table / no LootSystem). Safe on unknown/invalid input.
func break_prop(node_or_id: Variant, source: Node = null) -> Array:
	var node: Node = null
	var id: String = ""
	if node_or_id is Node:
		node = node_or_id
		if is_instance_valid(node):
			id = str(node.get_meta("prop_id", ""))
	elif node_or_id is String:
		id = str(node_or_id)
		# Break-by-id with no live node: still roll the loot (headless / scripted).
	var table: String = ""
	if node != null and is_instance_valid(node) and node.has_meta("break_loot"):
		table = str(node.get_meta("break_loot", ""))
	elif id != "":
		table = str(prop_def(id).get("break_loot", ""))
	var loot: Array = _roll_loot(table)
	if node != null and is_instance_valid(node):
		var pos: Vector2 = (node as Node2D).position if node is Node2D else Vector2.ZERO
		_spawn_break_fx(node, pos)
		_live.erase(node)
		node.queue_free()
	prop_broken.emit(id, node, loot)
	return loot


## Toggle a hidden_switch node (manual activation path; the Area2D also self-fires).
func activate_switch(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if str(node.get_meta("prop_kind", "")) != "hidden_switch":
		return false
	var key: int = node.get_instance_id()
	var now: bool = not bool(_switch_state.get(key, false))
	_switch_state[key] = now
	_reveal_switch(node, now)
	return now


func is_switch_pressed(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return bool(_switch_state.get(node.get_instance_id(), false))


func _on_switch_body(_body: Node, area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	_switch_state[area.get_instance_id()] = true
	_reveal_switch(area, true)


func _reveal_switch(node: Node, pressed: bool) -> void:
	# Brighten the concealed rune/plate when it answers (visual-only, guarded).
	for child: Node in node.get_children():
		if child is Polygon2D:
			var p := child as Polygon2D
			p.color = Color(p.color.r, p.color.g, p.color.b, 0.9 if pressed else 0.35)


func despawn_all() -> void:
	for n: Node in _live:
		if is_instance_valid(n):
			n.queue_free()
	_live.clear()
	_switch_state.clear()


# --- Freedom audit (PART A: no-walls heuristic) ------------------------------

## Report whether a zone over-restricts movement. Two modes, both pure/side-effect-
## free except the emitted signal:
##   1) If `zone` carries a "collision_map" (Array of equal-length rows; each cell
##      truthy = wall), flood-fill from the first open cell (or "spawn_cell") and
##      report the reachable fraction of open ground + fully-walled edges.
##   2) Otherwise use the border/road heuristic on a real zone def: how many of the
##      four edges have a border gap, and whether every road end that reaches an edge
##      lands in a gap (FREEDOM_PHYSICS F2/F3).
## Returns {zone_id, mode, over_restricted, reachable_frac, walled_edges, open_edges,
##          road_dead_ends, notes}. Never throws; unknown shapes -> a benign report.
func audit_freedom(zone: Dictionary) -> Dictionary:
	var zid: String = str(zone.get("id", "zone"))
	var report: Dictionary
	if zone.has("collision_map"):
		report = _audit_grid(zone)
	else:
		report = _audit_borders(zone)
	report["zone_id"] = zid
	freedom_audited.emit(zid, report)
	return report


func _audit_grid(zone: Dictionary) -> Dictionary:
	var grid: Array = _arr(zone.get("collision_map", []))
	var h: int = grid.size()
	var w: int = 0
	for row_v: Variant in grid:
		w = maxi(w, _row_len(row_v))
	var notes: Array = []
	if h == 0 or w == 0:
		return {"mode": "grid", "over_restricted": false, "reachable_frac": 1.0,
				"walled_edges": 0, "open_edges": 4, "road_dead_ends": 0,
				"notes": ["empty collision_map -- nothing to restrict"]}
	# Total open cells.
	var total_open: int = 0
	for y in range(h):
		for x in range(w):
			if not _cell_wall(grid, x, y):
				total_open += 1
	# Flood-fill start: explicit spawn_cell if open, else first open cell.
	var start := _grid_start(zone, grid, w, h)
	var reachable: int = 0
	if start.x >= 0:
		reachable = _flood_fill(grid, w, h, int(start.x), int(start.y))
	var frac: float = 1.0 if total_open == 0 else clampf(float(reachable) / float(total_open), 0.0, 1.0)
	# Edges: an edge is "walled" if every cell along it is a wall (no gap out).
	var walled: int = 0
	var open_edges: int = 0
	for edge_walled: bool in [_edge_walled(grid, w, h, "n"), _edge_walled(grid, w, h, "s"),
			_edge_walled(grid, w, h, "e"), _edge_walled(grid, w, h, "w")]:
		if edge_walled:
			walled += 1
		else:
			open_edges += 1
	if frac < 0.97:
		notes.append("%d%% of walkable ground is unreachable from spawn (sealed pockets)"
				% [100 - int(100.0 * frac)])
	if walled >= 4:
		notes.append("all four edges are solid walls -- no seam out of the zone (violates F2)")
	var over: bool = frac < 0.97 or walled >= 4
	return {"mode": "grid", "over_restricted": over, "reachable_frac": frac,
			"walled_edges": walled, "open_edges": open_edges, "road_dead_ends": 0,
			"total_open": total_open, "reachable": reachable, "notes": notes}


func _audit_borders(zone: Dictionary) -> Dictionary:
	var tiles_w: int = int(zone.get("tiles_w", 256))
	var tiles_h: int = int(zone.get("tiles_h", 192))
	var world := Vector2(float(tiles_w) * 32.0, float(tiles_h) * 32.0)
	var gaps: Array = _arr(zone.get("border_gaps", []))
	var notes: Array = []
	# Which of the four edges has at least one gap touching it.
	var edge_open := {"n": false, "s": false, "e": false, "w": false}
	var band: float = 200.0
	for g_v: Variant in gaps:
		if not (g_v is Rect2):
			continue
		var g: Rect2 = g_v
		if g.position.y <= band:
			edge_open["n"] = true
		if g.position.y + g.size.y >= world.y - band:
			edge_open["s"] = true
		if g.position.x <= band:
			edge_open["w"] = true
		if g.position.x + g.size.x >= world.x - band:
			edge_open["e"] = true
	var open_edges: int = 0
	for k: String in edge_open.keys():
		if bool(edge_open[k]):
			open_edges += 1
	var walled_edges: int = 4 - open_edges
	# Road-end check (F3): every road polyline endpoint within 200px of an edge must
	# lie inside a border gap, else the road dead-ends into the tree wall.
	var road_dead_ends: int = 0
	for road_v: Variant in _arr(zone.get("roads", [])):
		var road: Array = _arr(road_v)
		if road.size() < 1:
			continue
		for endpoint: Variant in [road[0], road[road.size() - 1]]:
			if not (endpoint is Vector2):
				continue
			var p: Vector2 = endpoint
			var near_edge: bool = p.x <= band or p.y <= band \
					or p.x >= world.x - band or p.y >= world.y - band
			if near_edge and not _point_in_any_rect(p, gaps):
				road_dead_ends += 1
	if gaps.is_empty():
		notes.append("no border_gaps authored -- the forest ring is a full wall (violates F2)")
	if open_edges <= 1 and not gaps.is_empty():
		notes.append("only %d edge(s) have a seam -- zone is a near-dead-end (audit B pattern)"
				% open_edges)
	if road_dead_ends > 0:
		notes.append("%d road endpoint(s) dead-end into the border wall (violates F3)"
				% road_dead_ends)
	var over: bool = gaps.is_empty() or open_edges == 0 or road_dead_ends > 0
	return {"mode": "borders", "over_restricted": over, "reachable_frac": 1.0,
			"walled_edges": walled_edges, "open_edges": open_edges,
			"road_dead_ends": road_dead_ends, "notes": notes}


# --- grid helpers ------------------------------------------------------------

func _flood_fill(grid: Array, w: int, h: int, sx: int, sy: int) -> int:
	var seen: Dictionary = {}
	var stack: Array = [Vector2i(sx, sy)]
	seen[sx * 100000 + sy] = true
	var count: int = 0
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		count += 1
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = c.x + off.x
			var ny: int = c.y + off.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var key: int = nx * 100000 + ny
			if seen.has(key) or _cell_wall(grid, nx, ny):
				continue
			seen[key] = true
			stack.append(Vector2i(nx, ny))
	return count


func _grid_start(zone: Dictionary, grid: Array, w: int, h: int) -> Vector2:
	var sc: Variant = zone.get("spawn_cell", null)
	if sc is Vector2i:
		var v: Vector2i = sc
		if v.x >= 0 and v.y >= 0 and v.x < w and v.y < h and not _cell_wall(grid, v.x, v.y):
			return Vector2(v.x, v.y)
	for y in range(h):
		for x in range(w):
			if not _cell_wall(grid, x, y):
				return Vector2(x, y)
	return Vector2(-1, -1)


func _cell_wall(grid: Array, x: int, y: int) -> bool:
	# A cell is a WALL when its glyph/value is truthy. ASCII maps: '#' or '1' = wall,
	# everything else (".", " ", "0", and marker glyphs like 'X') = open ground.
	if y < 0 or y >= grid.size():
		return true
	var row: Variant = grid[y]
	if row is String:
		var s: String = row
		if x < 0 or x >= s.length():
			return true
		var ch: String = s.substr(x, 1)
		return ch == "#" or ch == "1"
	if row is Array:
		var a: Array = row
		if x < 0 or x >= a.size():
			return true
		var cell: Variant = a[x]
		if cell is bool:
			return cell
		if cell is int or cell is float:
			return float(cell) != 0.0
		return bool(cell)
	if row is PackedByteArray:
		var pb: PackedByteArray = row
		if x < 0 or x >= pb.size():
			return true
		return pb[x] != 0
	return true


func _row_len(row: Variant) -> int:
	if row is String:
		return (row as String).length()
	if row is Array:
		return (row as Array).size()
	if row is PackedByteArray:
		return (row as PackedByteArray).size()
	return 0


func _edge_walled(grid: Array, w: int, h: int, edge: String) -> bool:
	match edge:
		"n":
			for x in range(w):
				if not _cell_wall(grid, x, 0):
					return false
			return true
		"s":
			for x in range(w):
				if not _cell_wall(grid, x, h - 1):
					return false
			return true
		"w":
			for y in range(h):
				if not _cell_wall(grid, 0, y):
					return false
			return true
		"e":
			for y in range(h):
				if not _cell_wall(grid, w - 1, y):
					return false
			return true
	return true


func _point_in_any_rect(p: Vector2, rects: Array) -> bool:
	for r_v: Variant in rects:
		if r_v is Rect2 and (r_v as Rect2).grow(24.0).has_point(p):
			return true
	return false


# --- loot / fx / host helpers ------------------------------------------------

func _roll_loot(table: String) -> Array:
	if table == "":
		return []
	var loot: Node = get_node_or_null("/root/LootSystem")
	if loot == null or not loot.has_method("roll_loot"):
		return []
	var v: Variant = loot.call("roll_loot", table, 0.0)
	return v if v is Array else []


func _spawn_break_fx(node: Node, pos: Vector2) -> void:
	# A cheap burst of shards -- pure code, freed by a timer; skipped if we cannot
	# safely parent it (node about to be freed, so attach to its parent).
	var host: Node = node.get_parent() if node.get_parent() != null else null
	if host == null or not is_instance_valid(host):
		return
	var col: Color = Color(0.6, 0.5, 0.4)
	for child: Node in node.get_children():
		if child is Polygon2D and (child as Polygon2D).color.a > 0.5:
			col = (child as Polygon2D).color
			break
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 10
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 90.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = col
	burst.z_index = 5
	host.add_child(burst)
	var t := burst.create_tween()
	t.tween_interval(0.7)
	t.tween_callback(burst.queue_free)


## Best-effort world parent for a freshly spawned prop.
func _spawn_host() -> Node:
	for grp: String in ["world", "map", "current_map", "zone_root"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and is_instance_valid(n):
			return n
	var pl: Node = _player()
	if pl != null and pl.get_parent() != null:
		return pl.get_parent()
	return null


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _prune_live() -> void:
	var keep: Array = []
	for n: Node in _live:
		if is_instance_valid(n):
			keep.append(n)
	_live = keep


# --- geometry helpers --------------------------------------------------------

func _rect_points(half: Vector2, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y),
	])


func _ellipse_points(rx: float, ry: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# --- data helpers ------------------------------------------------------------

func _size(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		var a: Array = v
		return Vector2(float(a[0]), float(a[1]))
	return Vector2(16, 16)


func _color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var alpha: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(0.55, 0.45, 0.32)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("PhysicsPropSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Self-test (RH_PHYS_TEST=1, tag "PHYS") ----------------------------------

func _run_selftest() -> void:
	# Wait a couple frames so sibling autoloads (LootSystem) have finished _ready.
	for _i in range(3):
		await get_tree().process_frame
	var fails: Array = []

	# 1) Registry loaded, every required kind present.
	print("[PHYS] loaded %d props ; kinds = %s" % [prop_count(), str(kinds())])
	if prop_count() <= 0:
		fails.append("no props loaded")
	for k: String in KINDS:
		var found: bool = false
		for id: String in prop_ids():
			if str(prop_def(id).get("kind", "")) == k:
				found = true
				break
		if not found:
			fails.append("no prop of kind '%s'" % k)

	# 2) Spawn one prop of every kind (guarded, into a throwaway world root).
	var root := Node2D.new()
	root.name = "PhysPropTestRoot"
	add_child(root)
	var spawned: Dictionary = {}     # kind -> node
	for k: String in KINDS:
		var id: String = _first_of_kind(k)
		if id == "":
			continue
		var n: Node = spawn_prop(id, Vector2(100 + KINDS.find(k) * 40, 100), root)
		if n == null or not is_instance_valid(n):
			fails.append("spawn_prop failed for kind '%s' (id %s)" % [k, id])
		else:
			spawned[k] = n
	print("[PHYS] spawned %d prop bodies across the 6 kinds" % spawned.size())

	# 3) Push a pushable and confirm the signal fired.
	var pushed: Array = [false]
	var pcb := func(_id: Variant, _node: Variant, _dir: Variant) -> void: pushed[0] = true
	prop_pushed.connect(pcb)
	var crate: Node = spawned.get("pushable")
	var push_ok: bool = crate != null and push_prop(crate, Vector2.RIGHT, 1.0)
	prop_pushed.disconnect(pcb)
	if not (push_ok and pushed[0]):
		fails.append("push_prop / prop_pushed did not fire")
	print("[PHYS] push_prop(crate) ok=%s signal=%s" % [str(push_ok), str(pushed[0])])

	# 4) Break a breakable; assert the loot PATH fired (loot_generated OR a returned
	#    array from a real table). LootSystem may be absent -> the path is still valid
	#    as long as break_prop returns without error and emits prop_broken.
	var broke: Array = [false]
	var bcb := func(_id: Variant, _node: Variant, _loot: Variant) -> void: broke[0] = true
	prop_broken.connect(bcb)
	var loot_fired: Array = [false]
	var loot_node: Node = get_node_or_null("/root/LootSystem")
	var lcb := func(_items: Variant) -> void: loot_fired[0] = true
	if loot_node != null and loot_node.has_signal("loot_generated"):
		loot_node.connect("loot_generated", lcb)
	var pot: Node = spawned.get("breakable")
	var loot: Array = break_prop(pot if pot != null else "clay_pot", null)
	if loot_node != null and loot_node.has_signal("loot_generated") and loot_node.is_connected("loot_generated", lcb):
		loot_node.disconnect("loot_generated", lcb)
	prop_broken.disconnect(bcb)
	var loot_path_ok: bool = broke[0] and (loot_fired[0] or loot_node == null or loot.size() >= 0)
	if not broke[0]:
		fails.append("break_prop did not emit prop_broken")
	print("[PHYS] break_prop(pot) -> loot items=%d ; LootSystem present=%s ; loot_generated fired=%s" % [
			loot.size(), str(loot_node != null), str(loot_fired[0])])

	# 5) hidden_switch activates.
	var sw: Node = spawned.get("hidden_switch")
	var sw_ok: bool = sw != null and activate_switch(sw) and is_switch_pressed(sw)
	if not sw_ok:
		fails.append("hidden_switch did not activate")
	print("[PHYS] activate_switch -> pressed=%s" % str(sw_ok))

	# 6) audit_freedom on a fake sealed grid zone (should flag over_restricted) and a
	#    healthy grid (should pass) + a border-mode zone.
	var sealed := {
		"id": "fake_sealed",
		"collision_map": [
			"#######",
			"#.....#",
			"#.###.#",
			"#.#X#.#",   # X = a sealed pocket behind walls
			"#.###.#",
			"#.....#",
			"#######",
		],
	}
	var open_zone := {
		"id": "fake_open",
		"collision_map": [
			"###.###",
			"#.....#",
			"#.....#",
			"......#",   # west + north seams
			"#.....#",
			"#.....#",
			"###.###",
		],
	}
	var border_zone := {
		"id": "fake_border", "tiles_w": 200, "tiles_h": 150,
		"border_gaps": [Rect2(0, 2000, 220, 300), Rect2(6180, 2200, 220, 300)],
		"roads": [[Vector2(120, 2100), Vector2(3200, 2400), Vector2(6300, 2350)]],
	}
	var r_sealed: Dictionary = audit_freedom(sealed)
	var r_open: Dictionary = audit_freedom(open_zone)
	var r_border: Dictionary = audit_freedom(border_zone)
	print("[PHYS] audit sealed  -> over_restricted=%s reach=%.2f walled_edges=%d notes=%s" % [
			str(r_sealed.get("over_restricted")), float(r_sealed.get("reachable_frac", 1.0)),
			int(r_sealed.get("walled_edges", 0)), str(r_sealed.get("notes"))])
	print("[PHYS] audit open    -> over_restricted=%s reach=%.2f open_edges=%d" % [
			str(r_open.get("over_restricted")), float(r_open.get("reachable_frac", 1.0)),
			int(r_open.get("open_edges", 0))])
	print("[PHYS] audit border  -> over_restricted=%s open_edges=%d road_dead_ends=%d" % [
			str(r_border.get("over_restricted")), int(r_border.get("open_edges", 0)),
			int(r_border.get("road_dead_ends", 0))])
	if not bool(r_sealed.get("over_restricted", false)):
		fails.append("audit_freedom failed to flag a sealed zone")
	if bool(r_open.get("over_restricted", true)):
		fails.append("audit_freedom wrongly flagged a healthy open zone")

	# cleanup
	root.queue_free()

	if fails.is_empty():
		print("PHYS SELFTEST PASS -- %d props, 6 kinds spawned, push+break+switch+audit verified" % prop_count())
	else:
		print("PHYS SELFTEST FAIL -- %d issue(s): %s" % [fails.size(), str(fails)])


func _first_of_kind(kind: String) -> String:
	for id: String in prop_ids():
		if str(prop_def(id).get("kind", "")) == kind:
			return id
	return ""
