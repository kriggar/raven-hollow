class_name TerrainPainter
## Corner-matched ("dual-grid") ground painter over the LPC Terrains v7 sheet.
##
## The sheet's Tiled export tags every tile with the terrain at its four
## CORNERS (tl,tr,bl,br). So instead of painting tiles we paint MATERIALS on
## a vertex grid ((w+1) x (h+1) corners) and let each tile resolve to the one
## sprite whose four corners match. That is how hand-painted 2D RPG ground
## gets its soft grass/dirt/cobble/water transitions — no per-tile art code.
##
## Supported pairs (see data/lpc_terrain_v7.json "pairs"): every transition
## goes through Grass as the hub (Grass<->Dirt_Roots, Mudstone_*, Stone_*,
## Soil, Water_Shallows_Dirt) plus Water_Shallows_Dirt<->Water etc. The
## sanitize pass drops any vertex that would put two non-hub materials side
## by side, so the painter never hits an unpaintable combo.
##
## Usage (see town_builder.gd):
##   var canvas := TerrainPainter.Canvas.new(w, h, TerrainPainter.mat("Grass"))
##   canvas.band([Vector2(...), ...], 40.0, TerrainPainter.mat("Dirt_Roots"), 14.0)
##   canvas.ellipse(Vector2(cx, cy), 120.0, 70.0, TerrainPainter.mat("Water"))
##   var painted: Dictionary = TerrainPainter.paint(layer, canvas, rng)
## Credits: assets/art/terrain/CREDITS_LPC_TERRAINS.txt (CC-BY-SA 3.0/4.0).

const DATA_PATH := "res://data/lpc_terrain_v7.json"
const TILE: int = 32

static var _data: Dictionary = {}
static var _name_to_id: Dictionary = {}
static var _pair_ok: Dictionary = {}     # "a,b" (a<b) -> true
static var _solo: Dictionary = {}        # id -> Array[int] tile ids (all four corners == id)
static var _priority: Dictionary = {}    # id -> int (higher wins in sanitize)
static var _bridge: Dictionary = {}      # id -> id: material to put between it and the hub


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert(parsed is Dictionary, "TerrainPainter: bad JSON at " + DATA_PATH)
	_data = parsed
	var names: Array = _data["names"]
	for i in range(names.size()):
		_name_to_id[str(names[i])] = i
	for k: Variant in (_data["pairs"] as Dictionary):
		_pair_ok[str(k)] = true
	for combo: Variant in (_data["by_combo"] as Dictionary):
		var parts: PackedStringArray = str(combo).split(",")
		if parts[0] == parts[1] and parts[1] == parts[2] and parts[2] == parts[3]:
			_solo[int(parts[0])] = (_data["by_combo"] as Dictionary)[combo]
	# Sanitize priority: water beats its shallows, shallows beat land; cobble
	# beats soil beats dirt. Grass (the hub) is never dropped.
	var order: Array = ["Water_Deep", "Water", "Water_Shallows_Dirt", "Mudstone_Gray",
		"Mudstone_Brown", "Stone_Tan", "Stone_White", "Soil", "Dirt_Roots"]
	for i in range(order.size()):
		if _name_to_id.has(order[i]):
			_priority[_name_to_id[order[i]]] = order.size() - i
	# Open water never touches grass on this sheet: a grass vertex next to
	# Water becomes its shallows automatically (authors paint water, get banks).
	if _name_to_id.has("Water") and _name_to_id.has("Water_Shallows_Dirt"):
		_bridge[_name_to_id["Water"]] = _name_to_id["Water_Shallows_Dirt"]
	if _name_to_id.has("Water_Deep") and _name_to_id.has("Water"):
		_bridge[_name_to_id["Water_Deep"]] = _name_to_id["Water"]


static func mat(name: String) -> int:
	_load()
	assert(_name_to_id.has(name), "TerrainPainter: unknown material " + name)
	return int(_name_to_id[name])


static func hub() -> int:
	return mat("Grass")


## keyed=true uses the grass-keyed copy of the sheet (grass pixels of every
## mixed tile are transparent) for OVERLAY layers: cobble/soil edges then sit
## on whatever the base layer painted underneath (dirt, grass, water bank).
static func make_tileset(keyed: bool = false) -> TileSet:
	_load()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	var sheet_path: String = str(_data["sheet_keyed"]) if keyed and _data.has("sheet_keyed") else str(_data["sheet"])
	src.texture = load(sheet_path)
	src.texture_region_size = Vector2i(TILE, TILE)
	var cols: int = int(_data["columns"])
	for tid_v: Variant in (_data["tiles"] as Dictionary):
		var tid: int = int(tid_v)
		var coords := Vector2i(tid % cols, tid / cols)
		if not src.has_tile(coords):
			src.create_tile(coords)
	ts.add_source(src, 0)
	return ts


## A vertex-material canvas in TILE units: (w+1) x (h+1) corners.
class Canvas:
	var w: int
	var h: int
	var v: PackedInt32Array
	var _noise_seed: int = 7

	func _init(tiles_w: int, tiles_h: int, base: int) -> void:
		w = tiles_w
		h = tiles_h
		v = PackedInt32Array()
		v.resize((w + 1) * (h + 1))
		v.fill(base)

	func get_v(x: int, y: int) -> int:
		return v[y * (w + 1) + x]

	func set_v(x: int, y: int, m: int) -> void:
		if x < 0 or y < 0 or x > w or y > h:
			return
		v[y * (w + 1) + x] = m

	## Low-frequency value noise in [-1,1] over vertex coords (organic edges).
	func noise(x: float, y: float, scale: float = 3.0) -> float:
		var gx: float = x / scale
		var gy: float = y / scale
		var x0: int = int(floor(gx))
		var y0: int = int(floor(gy))
		var fx: float = gx - float(x0)
		var fy: float = gy - float(y0)
		fx = fx * fx * (3.0 - 2.0 * fx)
		fy = fy * fy * (3.0 - 2.0 * fy)
		var a: float = _hash(x0, y0)
		var b: float = _hash(x0 + 1, y0)
		var c: float = _hash(x0, y0 + 1)
		var d: float = _hash(x0 + 1, y0 + 1)
		return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy) * 2.0 - 1.0

	func _hash(x: int, y: int) -> float:
		var n: int = x * 374761393 + y * 668265263 + _noise_seed * 982451653
		n = (n ^ (n >> 13)) * 1274126177
		n = n ^ (n >> 16)
		return float(n & 0xFFFF) / 65535.0

	## Axis-aligned rect in WORLD px (inclusive of touched vertices).
	func rect_px(r: Rect2, m: int) -> void:
		var x0: int = int(round(r.position.x / TILE))
		var y0: int = int(round(r.position.y / TILE))
		var x1: int = int(round(r.end.x / TILE))
		var y1: int = int(round(r.end.y / TILE))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				set_v(x, y, m)

	## Ellipse in WORLD px with a noisy rim (rim_jitter in px).
	func ellipse(center: Vector2, rx: float, ry: float, m: int, rim_jitter: float = 0.0) -> void:
		var x0: int = maxi(0, int((center.x - rx - rim_jitter) / TILE) - 1)
		var x1: int = mini(w, int((center.x + rx + rim_jitter) / TILE) + 1)
		var y0: int = maxi(0, int((center.y - ry - rim_jitter) / TILE) - 1)
		var y1: int = mini(h, int((center.y + ry + rim_jitter) / TILE) + 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var px := Vector2(x * TILE, y * TILE)
				var d := px - center
				var j: float = noise(float(x), float(y)) * rim_jitter
				var nx: float = d.x / maxf(rx + j, 1.0)
				var ny: float = d.y / maxf(ry + j, 1.0)
				if nx * nx + ny * ny <= 1.0:
					set_v(x, y, m)

	## Polyline band in WORLD px: vertices within half_w (+noise*jitter) of
	## the path get material m. Roads, lanes, worn tracks.
	func band(points: Array, half_w: float, m: int, jitter: float = 0.0) -> void:
		if points.size() < 2:
			return
		var minx: float = INF
		var miny: float = INF
		var maxx: float = -INF
		var maxy: float = -INF
		for p_v: Variant in points:
			var p: Vector2 = p_v
			minx = minf(minx, p.x)
			miny = minf(miny, p.y)
			maxx = maxf(maxx, p.x)
			maxy = maxf(maxy, p.y)
		var pad: float = half_w + jitter + TILE
		var x0: int = maxi(0, int((minx - pad) / TILE))
		var x1: int = mini(w, int((maxx + pad) / TILE) + 1)
		var y0: int = maxi(0, int((miny - pad) / TILE))
		var y1: int = mini(h, int((maxy + pad) / TILE) + 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var px := Vector2(x * TILE, y * TILE)
				var best: float = INF
				for i in range(points.size() - 1):
					var a: Vector2 = points[i]
					var b: Vector2 = points[i + 1]
					best = minf(best, _seg_dist(px, a, b))
				var limit: float = half_w + noise(float(x), float(y), 2.5) * jitter
				if best <= limit:
					set_v(x, y, m)

	static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var t: float = 0.0
		var l2: float = ab.length_squared()
		if l2 > 0.0:
			t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		return p.distance_to(a + ab * t)

	## Scattered blobs of m along a band (trampled ground, puddles).
	func blobs(rng: RandomNumberGenerator, area: Rect2, count: int, r_min: float, r_max: float, m: int) -> void:
		for i in range(count):
			var c := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			var r: float = rng.randf_range(r_min, r_max)
			ellipse(c, r, r * 0.7, m, r * 0.35)


## Paint the canvas onto `layer`. Returns {Vector2i cell: material id} for every
## cell that is not pure hub grass (callers use it as a keep-clear map).
## overlay=true leaves pure-hub cells unset (transparent) so the layer only
## carries its own materials; pair it with make_tileset(true).
static func paint(layer: TileMapLayer, canvas: Canvas, rng: RandomNumberGenerator, overlay: bool = false) -> Dictionary:
	_load()
	var hub_id: int = hub()
	_sanitize(canvas, hub_id)
	var cols: int = int(_data["columns"])
	var by_combo: Dictionary = _data["by_combo"]
	var painted: Dictionary = {}
	var missing: int = 0
	for y in range(canvas.h):
		for x in range(canvas.w):
			var c: Array[int] = [canvas.get_v(x, y), canvas.get_v(x + 1, y), canvas.get_v(x, y + 1), canvas.get_v(x + 1, y + 1)]
			if overlay and c[0] == hub_id and c[1] == hub_id and c[2] == hub_id and c[3] == hub_id:
				continue
			var tid: int = _resolve(c, by_combo, hub_id, rng)
			if tid < 0:
				missing += 1
				tid = _pick_solo(hub_id, rng)
			layer.set_cell(Vector2i(x, y), 0, Vector2i(tid % cols, tid / cols))
			if c[0] != hub_id or c[1] != hub_id or c[2] != hub_id or c[3] != hub_id:
				painted[Vector2i(x, y)] = _dominant(c, hub_id)
	if missing > 0:
		push_warning("TerrainPainter: %d cells had no matching tile (fell back to grass)" % missing)
	return painted


static func _dominant(c: Array[int], hub_id: int) -> int:
	var best: int = hub_id
	var best_p: int = -1
	for m in c:
		if m == hub_id:
			continue
		var p: int = int(_priority.get(m, 0))
		if p > best_p:
			best_p = p
			best = m
	return best


static func _key(c: Array[int]) -> String:
	return "%d,%d,%d,%d" % [c[0], c[1], c[2], c[3]]


static func _pick_solo(m: int, rng: RandomNumberGenerator) -> int:
	var list: Array = _solo.get(m, [])
	if list.is_empty():
		return -1
	if list.size() == 1 or rng.randf() < 0.62:
		return int(list[0])
	return int(list[rng.randi_range(0, list.size() - 1)])


## Corner combo -> tile id. Falls back by pushing corners to the hub, fewest
## first, so an unsupported junction paints a tiny notch instead of a hole.
static func _resolve(c: Array[int], by_combo: Dictionary, hub_id: int, rng: RandomNumberGenerator) -> int:
	if c[0] == c[1] and c[1] == c[2] and c[2] == c[3]:
		return _pick_solo(c[0], rng)
	var k: String = _key(c)
	if by_combo.has(k):
		var list: Array = by_combo[k]
		return int(list[rng.randi_range(0, list.size() - 1)])
	# fallback: hub-ify corners in every order of increasing count
	var idx: Array = [0, 1, 2, 3]
	for n in range(1, 4):
		for combo_v: Variant in _subsets(idx, n):
			var cc: Array[int] = c.duplicate()
			for i_v: Variant in (combo_v as Array):
				cc[int(i_v)] = hub_id
			var kk: String = _key(cc)
			if cc[0] == cc[1] and cc[1] == cc[2] and cc[2] == cc[3]:
				return _pick_solo(cc[0], rng)
			if by_combo.has(kk):
				var l2: Array = by_combo[kk]
				return int(l2[rng.randi_range(0, l2.size() - 1)])
	return -1


static func _subsets(items: Array, n: int) -> Array:
	var out: Array = []
	var total: int = 1 << items.size()
	for mask in range(1, total):
		var picked: Array = []
		for i in range(items.size()):
			if mask & (1 << i):
				picked.append(items[i])
		if picked.size() == n:
			out.append(picked)
	return out


## Two different non-hub materials may only meet if the sheet has that pair
## (e.g. Water<->Shallows). Otherwise the lower-priority vertex becomes hub
## grass. Checks all 8 neighbours because a tile's 4 corners are diagonal.
static func _sanitize(canvas: Canvas, hub_id: int) -> void:
	var pairs: Dictionary = _data["pairs"]
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 4:
		changed = false
		guard += 1
		for y in range(canvas.h + 1):
			for x in range(canvas.w + 1):
				var m: int = canvas.get_v(x, y)
				if m == hub_id:
					continue
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx > canvas.w or ny > canvas.h:
							continue
						var k: int = canvas.get_v(nx, ny)
						if k == m:
							continue
						if k == hub_id:
							if _bridge.has(m):
								canvas.set_v(nx, ny, int(_bridge[m]))
								changed = true
							continue
						var pk: String = "%d,%d" % [mini(m, k), maxi(m, k)]
						if pairs.has(pk):
							continue
						# unsupported neighbour: drop the weaker one to grass
						if int(_priority.get(m, 0)) >= int(_priority.get(k, 0)):
							canvas.set_v(nx, ny, hub_id)
						else:
							canvas.set_v(x, y, hub_id)
						changed = true
