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


func _process(delta: float) -> void:
	# Poll the live map id so entering a new zone charts it (no main.gd edit).
	_poll_accum += delta
	if _poll_accum < 0.4:
		return
	_poll_accum = 0.0
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
	return {"revealed": _revealed.keys()}

func load_state(data: Dictionary) -> void:
	for zid: Variant in data.get("revealed", []):
		_revealed[str(zid)] = true
	for z: String in SEED_REVEALED:
		_revealed[z] = true


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
