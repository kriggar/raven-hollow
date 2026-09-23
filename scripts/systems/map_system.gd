extends Node
## MapSystem (autoload) — the multi-scale atlas brain for Raven Hollow.
##
## Owns fog-of-war (which zones the player has charted), the world-map anchor
## table (hand-tuned against assets/art/ui/world_map.png, the v2 parchment
## masterpiece), and the zone/POI metadata the map screen paints. Spawns the
## 3-tier zoom map (scenes/ui/map_screen.tscn) which the M key opens.
##
## Data is read (never mutated) from the shipped systems: ZoneDefs (names,
## regions, capitals, waystations), TravelSystem (station discovery), and
## MapRegistry (playable maps). Discovery persists to user://map_progress.cfg.
##
## Public API (spec surface):
##   reveal(zone_id) -> void            # chart a zone (fog lifts), persists
##   is_revealed(zone_id) -> bool
##   open() / close() / toggle()        # the map screen
##   current_zone() -> String
## Signals:
##   zone_revealed(zone_id)
##   map_opened() / map_closed()

signal zone_revealed(zone_id)
signal map_opened
signal map_closed

const CFG_PATH := "user://map_progress.cfg"
const MAP_SCENE := "res://scenes/ui/map_screen.tscn"
const WORLD_MAP_PATH := "res://assets/art/ui/world_map.png"

## world_map.png native size; every anchor below is in this pixel space.
const WORLD_MAP_SIZE := Vector2(2048.0, 1152.0)

## Zones the player starts already knowing (the demo's home + first road).
const SEED_REVEALED := ["town", "wilderness"]

## Anchor of each zone on world_map.png (read directly off the inked labels of
## the v2 chart). Continent 1 = Draconia, continent 2 = the Collector's Coast.
const ANCHORS := {
	"town": Vector2(700, 575),
	"wilderness": Vector2(628, 600),
	"iron_vein": Vector2(548, 645),
	"vetka": Vector2(793, 620),
	"copper_wells": Vector2(865, 666),
	"stonepath": Vector2(963, 615),
	"chamber_depths": Vector2(722, 600),
	"grey_marches": Vector2(466, 543),
	"western_lowlands": Vector2(400, 471),
	"angel_wings": Vector2(300, 481),
	"famine_fields": Vector2(255, 568),
	"riverfork": Vector2(325, 645),
	"listening_steppe": Vector2(451, 266),
	"threadlands": Vector2(625, 400),
	"black_night": Vector2(635, 323),
	"gravemark_tundra": Vector2(793, 266),
	"bloodstone_pit": Vector2(720, 300),
	"whisper_passes": Vector2(978, 358),
	"eastern_ridges": Vector2(1091, 512),
	"blestem": Vector2(1106, 440),
	"lichenreach": Vector2(1193, 502),
	"transcub_vale": Vector2(1167, 558),
	"bloodroad": Vector2(865, 722),
	"basaltfang": Vector2(829, 788),
	"sangeroasa": Vector2(942, 891),
	"the_gift": Vector2(973, 727),
	"ashvents": Vector2(1060, 835),
	"greyhollow": Vector2(1649, 645),
	"drowned_quarter": Vector2(1526, 711),
	"canal_maze": Vector2(1526, 660),
	"grey_piers": Vector2(1638, 747),
	"salt_fens": Vector2(1874, 670),
	"dead_timber": Vector2(1536, 512),
	"ledger_roads": Vector2(1705, 553),
	"morven_reach": Vector2(1505, 614),
	"the_archive": Vector2(1669, 456),
	"anchorfall": Vector2(1771, 747),
	"finalized_fields": Vector2(1649, 522),
	"coldharbor_deep": Vector2(1600, 760),
	"orange_fog": Vector2(1854, 599),
	"last_hearth": Vector2(1813, 527),
}

## town + wilderness are MapRegistry maps, not ZoneDefs zones — patch their meta.
const SYNTHETIC := {
	"town": {"name": "Raven Hollow", "region": "border", "continent": 1, "capital": true},
	"wilderness": {"name": "The Emberfall Road", "region": "border", "continent": 1, "capital": false},
}

const REGION_TITLES := {
	"border": "The Border", "west": "The West", "north": "The North",
	"east": "The East", "south": "The Forge-Lands", "coast": "The Collector's Coast",
}

var _revealed: Dictionary = {}
var _screen: Node = null
var _last_seen_zone: String = ""
var _poll_accum: float = 0.0
var _world_tex: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	for z: String in SEED_REVEALED:
		_revealed[z] = true
	if not TravelSystem.is_connected("station_discovered", _on_station_discovered):
		TravelSystem.station_discovered.connect(_on_station_discovered)
	call_deferred("_spawn_screen")
	call_deferred("_qa_chart")
	if OS.get_environment("RH_MAPSCREEN") != "":
		call_deferred("_qa_open")


## --- chart memory (per-cell map discovery) ---------------------------------
## 64 world px per cell divides both shipped world rects exactly: the city
## 7168x5120 -> 112x80 = 8960 cells, the village 2240x1600 -> 35x25.
const CHART_CELL: float = 64.0
## Reveal radius in world px. The screen shows 640x360 world px, so 560 is
## about 1.75 screen widths - deliberately generous (the call Minecraft makes)
## and larger than the minimap half-window (546) so the minimap never fogs
## right next to the player.
const CHART_REVEAL: float = 560.0
const CHART_LANDMARK_NEAR: float = 180.0
const CHART_LANDMARK_R: float = 768.0
const CHART_TICK: float = 0.12
const CHART_MAX_CELLS: int = 65536

signal chart_changed(map_id: String)
signal place_charted(map_id: String, label: String)

var _chart: Dictionary = {}          # map_id -> PackedByteArray (1 byte/cell)
var _chart_dim: Dictionary = {}      # map_id -> Vector2i
var _chart_origin: Dictionary = {}   # map_id -> Vector2
var _chart_count: Dictionary = {}    # map_id -> int
var _places_known: Dictionary = {}   # map_id -> {label: true}
var _veil_tex: Dictionary = {}       # map_id -> ImageTexture
var _veil_dirty: Dictionary = {}     # map_id -> bool
var _chart_accum: float = 0.0


## Allocate (or keep) the chart grid for a zone. Idempotent.
func ensure_chart(map_id: String, bounds: Rect2) -> void:
	if map_id.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var w: int = maxi(1, int(ceil(bounds.size.x / CHART_CELL)))
	var h: int = maxi(1, int(ceil(bounds.size.y / CHART_CELL)))
	if _chart.has(map_id) and _chart_dim.get(map_id, Vector2i.ZERO) == Vector2i(w, h) \
			and _chart_origin.get(map_id, Vector2.ZERO) == bounds.position:
		return
	if w * h > CHART_MAX_CELLS:
		push_warning("MapSystem: chart too large for " + map_id)
		return
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	bytes.fill(0)
	_chart[map_id] = bytes
	_chart_dim[map_id] = Vector2i(w, h)
	_chart_origin[map_id] = bounds.position
	_chart_count[map_id] = 0
	if not _places_known.has(map_id):
		_places_known[map_id] = {}
	_veil_dirty[map_id] = true


func chart_dims(map_id: String) -> Vector2i:
	return _chart_dim.get(map_id, Vector2i.ZERO)


func chart_origin(map_id: String) -> Vector2:
	return _chart_origin.get(map_id, Vector2.ZERO)


func is_surveyed(map_id: String, world_pos: Vector2) -> bool:
	if not _chart.has(map_id):
		return false
	var dim: Vector2i = _chart_dim[map_id]
	var o: Vector2 = _chart_origin[map_id]
	var cx: int = int(floor((world_pos.x - o.x) / CHART_CELL))
	var cy: int = int(floor((world_pos.y - o.y) / CHART_CELL))
	if cx < 0 or cy < 0 or cx >= dim.x or cy >= dim.y:
		return false
	return (_chart[map_id] as PackedByteArray)[cy * dim.x + cx] != 0


## Light every cell whose centre is within `radius` of `centre`. Returns how
## many were newly lit, and only then marks the veil dirty.
func survey_disc(map_id: String, centre: Vector2, radius: float) -> int:
	if not _chart.has(map_id):
		return 0
	var dim: Vector2i = _chart_dim[map_id]
	var o: Vector2 = _chart_origin[map_id]
	var bytes: PackedByteArray = _chart[map_id]
	var x0: int = clampi(int(floor((centre.x - radius - o.x) / CHART_CELL)), 0, dim.x - 1)
	var x1: int = clampi(int(floor((centre.x + radius - o.x) / CHART_CELL)), 0, dim.x - 1)
	var y0: int = clampi(int(floor((centre.y - radius - o.y) / CHART_CELL)), 0, dim.y - 1)
	var y1: int = clampi(int(floor((centre.y + radius - o.y) / CHART_CELL)), 0, dim.y - 1)
	var r2: float = radius * radius
	var lit: int = 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var idx: int = y * dim.x + x
			if bytes[idx] != 0:
				continue
			var cc: Vector2 = o + (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) * CHART_CELL
			if centre.distance_squared_to(cc) <= r2:
				bytes[idx] = 1
				lit += 1
	if lit > 0:
		_chart[map_id] = bytes
		_chart_count[map_id] = int(_chart_count.get(map_id, 0)) + lit
		_veil_dirty[map_id] = true
		chart_changed.emit(map_id)
	return lit


func survey_all(map_id: String) -> void:
	if not _chart.has(map_id):
		return
	var dim: Vector2i = _chart_dim[map_id]
	var bytes: PackedByteArray = _chart[map_id]
	bytes.fill(1)
	_chart[map_id] = bytes
	_chart_count[map_id] = dim.x * dim.y
	var known: Dictionary = _places_known.get(map_id, {})
	for p_v: Variant in _places_for(map_id):
		known[str((p_v as Dictionary).get("label", ""))] = true
	_places_known[map_id] = known
	_veil_dirty[map_id] = true
	chart_changed.emit(map_id)


func chart_fraction(map_id: String) -> float:
	if not _chart.has(map_id):
		return 0.0
	var dim: Vector2i = _chart_dim[map_id]
	return float(_chart_count.get(map_id, 0)) / maxf(1.0, float(dim.x * dim.y))


func is_place_known(map_id: String, label: String) -> bool:
	return bool((_places_known.get(map_id, {}) as Dictionary).get(label, false))


func mark_place_known(map_id: String, label: String) -> void:
	if label.is_empty() or is_place_known(map_id, label):
		return
	var known: Dictionary = _places_known.get(map_id, {})
	known[label] = true
	_places_known[map_id] = known
	for p_v: Variant in _places_for(map_id):
		var p: Dictionary = p_v
		if str(p.get("label", "")) == label:
			survey_disc(map_id, p["pos"] as Vector2, CHART_LANDMARK_R)
			break
	place_charted.emit(map_id, label)


func known_place_count(map_id: String) -> int:
	return (_places_known.get(map_id, {}) as Dictionary).size()


## The named places of a zone come from the one shared table in Minimap.
func _places_for(map_id: String) -> Array:
	return Minimap.PLACES.get(map_id, [])


## A veil image: one texel per chart cell, transparent where surveyed and a
## dark parchment where not. Drawn stretched with LINEAR filtering, which is
## what gives the discovered edge its feather for free.
func veil_texture(map_id: String) -> Texture2D:
	if not _chart.has(map_id):
		return null
	if not bool(_veil_dirty.get(map_id, true)) and _veil_tex.has(map_id):
		return _veil_tex[map_id]
	var dim: Vector2i = _chart_dim[map_id]
	var bytes: PackedByteArray = _chart[map_id]
	var img := Image.create(dim.x, dim.y, false, Image.FORMAT_RGBA8)
	# Not black. The reference games (Zelda's dungeon map, Minecraft's blank
	# paper, Terraria) never hide the SHAPE of a place - they drain it. Unsurveyed
	# ground becomes unfinished parchment; what discovery really gates is the
	# names, icons and gates, which _build_local_items does.
	var hidden := Color(0.74, 0.67, 0.52, 0.86)
	var clear := Color(0.74, 0.67, 0.52, 0.0)
	for y in range(dim.y):
		for x in range(dim.x):
			img.set_pixel(x, y, clear if bytes[y * dim.x + x] != 0 else hidden)
	var tex := ImageTexture.create_from_image(img)
	_veil_tex[map_id] = tex
	_veil_dirty[map_id] = false
	return tex


## QA: RH_CHART=all surveys every zone at boot so a screenshot shows the whole
## map; RH_CHART=none leaves it dark. Without it the chart fills as you walk.
func _qa_chart() -> void:
	var mode: String = OS.get_environment("RH_CHART").to_lower()
	if mode.is_empty():
		return
	for i in range(20):
		await get_tree().process_frame
	var map_id: String = current_zone()
	if map_id.is_empty():
		return
	ensure_chart(map_id, zone_bounds(map_id))
	if mode == "all":
		survey_all(map_id)


func _tick_chart() -> void:
	var map_id: String = current_zone()
	if map_id.is_empty():
		return
	var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if pl == null or not is_instance_valid(pl):
		return
	if not _chart.has(map_id):
		ensure_chart(map_id, zone_bounds(map_id))
		if not _chart.has(map_id):
			return
	var p: Vector2 = pl.global_position
	survey_disc(map_id, p, CHART_REVEAL)
	var near2: float = CHART_LANDMARK_NEAR * CHART_LANDMARK_NEAR
	for pv: Variant in _places_for(map_id):
		if not (pv is Dictionary):
			continue
		var pd: Dictionary = pv
		var lab: String = str(pd.get("label", ""))
		if lab.is_empty() or is_place_known(map_id, lab):
			continue
		if p.distance_squared_to(pd["pos"] as Vector2) <= near2:
			mark_place_known(map_id, lab)


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum >= 0.4:
		_poll_accum = 0.0
		_tick_zone_poll()
	_chart_accum += delta
	if _chart_accum >= CHART_TICK:
		_chart_accum = 0.0
		_tick_chart()


func _tick_zone_poll() -> void:
	var cur: String = current_zone()
	if cur != "" and cur != _last_seen_zone:
		_last_seen_zone = cur
		reveal(cur)


# ---------------------------------------------------------------- public API

func reveal(zone_id: String) -> void:
	if zone_id.is_empty() or _revealed.has(zone_id):
		return
	_revealed[zone_id] = true
	_save()
	zone_revealed.emit(zone_id)
	if _screen != null and _screen.has_method("on_zone_revealed"):
		_screen.call("on_zone_revealed", zone_id)

func is_revealed(zone_id: String) -> bool:
	return _revealed.has(zone_id)

func revealed_ids() -> Array:
	return _revealed.keys()

func current_zone() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return ""
	var v: Variant = scene.get("current_map_id")
	return str(v) if v != null else ""

func open() -> void:
	if _screen != null and _screen.has_method("open_map"):
		_screen.call("open_map")

func close() -> void:
	if _screen != null and _screen.has_method("close_map"):
		_screen.call("close_map")

func toggle() -> void:
	if _screen != null and _screen.has_method("toggle_map"):
		_screen.call("toggle_map")

func is_map_open() -> bool:
	return _screen != null and bool(_screen.get("is_open"))


# ---------------------------------------------------------------- world art

func world_texture() -> Texture2D:
	if _world_tex == null:
		if ResourceLoader.exists(WORLD_MAP_PATH, "Texture2D"):
			_world_tex = load(WORLD_MAP_PATH) as Texture2D
		else:
			var gp: String = ProjectSettings.globalize_path(WORLD_MAP_PATH)
			if FileAccess.file_exists(gp):
				var img: Image = Image.load_from_file(gp)
				if img != null:
					_world_tex = ImageTexture.create_from_image(img)
	return _world_tex


# ---------------------------------------------------------------- zone meta

## Every zone that has a world anchor (the placeable atlas set).
func placeable_ids() -> Array:
	return ANCHORS.keys()

func anchor_of(zone_id: String) -> Vector2:
	return ANCHORS.get(zone_id, WORLD_MAP_SIZE * 0.5)

func has_anchor(zone_id: String) -> bool:
	return ANCHORS.has(zone_id)

## {name, region, continent, capital, anchor} — merges ZoneDefs + synthetics.
func zone_meta(zone_id: String) -> Dictionary:
	var meta := {
		"id": zone_id, "name": zone_id.capitalize(),
		"region": "border", "continent": 1, "capital": false,
		"anchor": anchor_of(zone_id),
	}
	if SYNTHETIC.has(zone_id):
		var s: Dictionary = SYNTHETIC[zone_id]
		meta["name"] = str(s.get("name", meta.name))
		meta["region"] = str(s.get("region", "border"))
		meta["continent"] = int(s.get("continent", 1))
		meta["capital"] = bool(s.get("capital", false))
		return meta
	var z: Dictionary = ZoneDefs.zone(zone_id)
	if not z.is_empty():
		meta["name"] = str(z.get("name", meta.name))
		meta["region"] = str(z.get("region", "border"))
		meta["continent"] = int(z.get("continent", 1))
		meta["capital"] = bool(z.get("capital", false))
	return meta

func region_of(zone_id: String) -> String:
	return str(zone_meta(zone_id).get("region", "border"))

func continent_of(zone_id: String) -> int:
	return int(zone_meta(zone_id).get("continent", 1))

func region_title(region: String) -> String:
	return str(REGION_TITLES.get(region, region.capitalize()))

## The placeable zones sharing a (continent, region) pair.
func zones_in_region(continent: int, region: String) -> Array:
	var out: Array = []
	for zid: String in ANCHORS.keys():
		var m: Dictionary = zone_meta(zid)
		if int(m.continent) == continent and str(m.region) == region:
			out.append(zid)
	return out

## Bounding box (world_map px) of a region's anchors, padded — the REGION crop.
func region_bounds(continent: int, region: String) -> Rect2:
	var ids: Array = zones_in_region(continent, region)
	if ids.is_empty():
		return Rect2(Vector2.ZERO, WORLD_MAP_SIZE)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for zid: String in ids:
		var a: Vector2 = anchor_of(zid)
		mn = Vector2(minf(mn.x, a.x), minf(mn.y, a.y))
		mx = Vector2(maxf(mx.x, a.x), maxf(mx.y, a.y))
	var pad := Vector2(150.0, 120.0)
	mn -= pad
	mx += pad
	mn = mn.clamp(Vector2.ZERO, WORLD_MAP_SIZE)
	mx = mx.clamp(Vector2.ZERO, WORLD_MAP_SIZE)
	# keep a sane minimum size so a single-zone region still reads as a crop
	var sz: Vector2 = mx - mn
	if sz.x < 360.0:
		var cx: float = (mn.x + mx.x) * 0.5
		mn.x = maxf(0.0, cx - 180.0); mx.x = minf(WORLD_MAP_SIZE.x, cx + 180.0)
	if sz.y < 260.0:
		var cy: float = (mn.y + mx.y) * 0.5
		mn.y = maxf(0.0, cy - 130.0); mx.y = minf(WORLD_MAP_SIZE.y, cy + 130.0)
	return Rect2(mn, mx - mn)


# ---------------------------------------------------------------- POI / travel

## Waystations of a zone: [{id, pos(world px in-zone), discovered(bool)}].
func zone_waystations(zone_id: String) -> Array:
	var out: Array = []
	var z: Dictionary = ZoneDefs.zone(zone_id)
	for ws_v: Variant in z.get("waystations", []):
		if ws_v is Dictionary:
			var ws: Dictionary = ws_v
			var sid: String = str(ws.get("id", ""))
			out.append({
				"id": sid,
				"pos": ws.get("pos", Vector2.ZERO),
				"discovered": TravelSystem.is_discovered(sid),
			})
	return out

## Landmarks of a zone (for the local-tier chart): [{type, pos}].
func zone_landmarks(zone_id: String) -> Array:
	var out: Array = []
	var z: Dictionary = ZoneDefs.zone(zone_id)
	for lm_v: Variant in z.get("landmarks", []):
		if lm_v is Dictionary and (lm_v as Dictionary).get("pos") is Vector2:
			out.append({"type": str((lm_v as Dictionary).get("type", "")),
				"pos": (lm_v as Dictionary).get("pos")})
	return out

## Travel points of a zone (return gates): [{pos, to_map, prompt}].
func zone_travel_points(zone_id: String) -> Array:
	var out: Array = []
	for tp_v: Variant in MapRegistry.travel_points(zone_id):
		if tp_v is Dictionary and (tp_v as Dictionary).get("pos") is Vector2:
			var tp: Dictionary = tp_v
			out.append({"pos": tp.get("pos"), "to_map": str(tp.get("to_map", "")),
				"prompt": str(tp.get("prompt", ""))})
	return out

## Local display name (MapRegistry / ZoneDefs).
func display_name(zone_id: String) -> String:
	if SYNTHETIC.has(zone_id):
		return str((SYNTHETIC[zone_id] as Dictionary).get("name", zone_id.capitalize()))
	var z: Dictionary = ZoneDefs.zone(zone_id)
	if not z.is_empty():
		return str(z.get("name", zone_id.capitalize()))
	return zone_id.capitalize()

## Local-tier bounds (world px). Prefers the live camera limits, then the zone
## def's tile size, then the town default.
func zone_bounds(zone_id: String) -> Rect2:
	var cam: Node = get_tree().root.find_child("PlayerCamera", true, false)
	if cam is Camera2D:
		var c := cam as Camera2D
		var w: float = float(c.limit_right - c.limit_left)
		var h: float = float(c.limit_bottom - c.limit_top)
		if w > 64.0 and h > 64.0 and w < 1.0e7:
			return Rect2(Vector2(c.limit_left, c.limit_top), Vector2(w, h))
	var z: Dictionary = ZoneDefs.zone(zone_id)
	if z.has("tiles_w") and z.has("tiles_h"):
		return Rect2(Vector2.ZERO, Vector2(float(z.tiles_w) * 32.0, float(z.tiles_h) * 32.0))
	return Rect2(0.0, 0.0, 2240.0, 1600.0)


# ---------------------------------------------------------------- discovery

func _on_station_discovered(station_id: String) -> void:
	var zid: String = TravelSystem.station_zone(station_id)
	if zid != "":
		reveal(zid)
	if _screen != null and _screen.has_method("on_station_discovered"):
		_screen.call("on_station_discovered", station_id)


# ---------------------------------------------------------------- persistence

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	for zid: Variant in cfg.get_value("fog", "revealed", []):
		_revealed[str(zid)] = true

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fog", "revealed", _revealed.keys())
	if cfg.save(CFG_PATH) != OK:
		push_warning("MapSystem: could not write %s" % CFG_PATH)

## SaveSystem-shaped hooks (mirrors TravelSystem; wired if the save pass adopts it).
func save_state() -> Dictionary:
	# The chart is stored per zone as base64 of its 1-byte-per-cell grid, which
	# is both ConfigFile- and JSON-safe and stays small (the whole city is 8960
	# cells = about 12 KB of base64).
	var charts: Dictionary = {}
	for k_v: Variant in _chart:
		var k: String = k_v
		var dim: Vector2i = _chart_dim[k]
		charts[k] = {
			"w": dim.x, "h": dim.y,
			"ox": (_chart_origin[k] as Vector2).x, "oy": (_chart_origin[k] as Vector2).y,
			"n": int(_chart_count.get(k, 0)),
			"b": Marshalls.raw_to_base64(_chart[k] as PackedByteArray),
		}
	var known: Dictionary = {}
	for m_v: Variant in _places_known:
		known[str(m_v)] = (_places_known[m_v] as Dictionary).keys()
	return {"revealed": _revealed.keys(), "charts": charts, "places": known}


func load_state(data: Dictionary) -> void:
	for zid: Variant in data.get("revealed", []):
		_revealed[str(zid)] = true
	for z: String in SEED_REVEALED:
		_revealed[z] = true
	var charts: Dictionary = data.get("charts", {})
	for k_v: Variant in charts:
		var k: String = k_v
		var c: Dictionary = charts[k_v]
		var w: int = int(c.get("w", 0))
		var h: int = int(c.get("h", 0))
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(c.get("b", "")))
		if w <= 0 or h <= 0 or bytes.size() != w * h:
			continue
		_chart[k] = bytes
		_chart_dim[k] = Vector2i(w, h)
		_chart_origin[k] = Vector2(float(c.get("ox", 0.0)), float(c.get("oy", 0.0)))
		_chart_count[k] = int(c.get("n", 0))
		_veil_dirty[k] = true
	var places: Dictionary = data.get("places", {})
	for m_v: Variant in places:
		var seen: Dictionary = {}
		for lab_v: Variant in (places[m_v] as Array):
			seen[str(lab_v)] = true
		_places_known[str(m_v)] = seen


# ---------------------------------------------------------------- screen

func _spawn_screen() -> void:
	if _screen != null and is_instance_valid(_screen):
		return
	if not ResourceLoader.exists(MAP_SCENE):
		push_warning("MapSystem: %s missing." % MAP_SCENE)
		return
	var scn: PackedScene = load(MAP_SCENE) as PackedScene
	if scn == null:
		return
	_screen = scn.instantiate()
	add_child(_screen)

## Called by the map screen so listeners (and the pause-menu Esc gate) can react.
func notify_opened() -> void:
	map_opened.emit()

func notify_closed() -> void:
	map_closed.emit()


## QA: RH_MAPSCREEN=1 opens the map screen at boot for a screenshot.
func _qa_open() -> void:
	for i in range(40):
		await get_tree().process_frame
	open()
