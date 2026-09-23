class_name MapDump
extends RefCounted
## Dump the city's OWN vector geometry to JSON, so a map can be DRAWN from it.
##
## WHY THIS EXISTS
## The first chart pipeline recovered the town's shape by classifying the pixels
## of a screenshot. That can only ever produce blobs: a roof read through a
## colour test comes back as a ragged island, a street comes back as whatever is
## left over, and no amount of cleaning turns either into the crisp deliberate
## linework that makes a map look drawn rather than generated. The owner's
## verdict on that approach was 1/10, and they were right.
##
## But the town was never a picture in the first place. `town_city.gd` lays it
## out from hand-authored vectors - every street and canal is a polyline const,
## every field and built-up block is a Rect2, every house is planned into
## `TownCity._plans` with a centre, a width and a kind before a single sprite is
## instanced. This walks that data and writes it out, so the cartographer can
## draw true rectangles, true road centrelines and a true coastline.
##
## USAGE
##   RH_MAPDUMP=<path.json>  (handled in main.gd `_run_env_hooks`)
## It is read-only: it instances nothing, changes nothing, and is safe to run
## on any boot.

## Street centrelines. The half-width is the drawn carriageway, taken from
## `TownCity._on_street`, which treats anything within 60 px of these lines as
## paving, and from the row setback that puts house doors 46 px off the line.
const STREET_HALF: float = 60.0
const LANE_HALF: float = 44.0
const CANAL_HALF: float = 40.0


static func collect(zone_id: String, world: Node) -> Dictionary:
	var out: Dictionary = {
		"zone": zone_id,
		"generated_by": "scripts/tools/map_dump.gd",
		"bounds": _bounds(zone_id),
		"streets": [],
		"water": [],
		"tracks": [],
		"fields": [],
		"built": [],
		"squares": [],
		"houses": [],
		"buildings": [],
		"trees": [],
		"walls": [],
		"bridges": [],
		"places": [],
		"districts": [],
	}
	if zone_id != "town":
		# Only the city is laid out from vectors; everything else has to keep
		# using the painted plate until it gets the same treatment.
		return out

	# --- streets and lanes -------------------------------------------------
	var majors: Array = [
		["APPROACH", TownCity.APPROACH, STREET_HALF],
		["AVENUE_E", TownCity.AVENUE_E, STREET_HALF],
		["AVENUE_S", TownCity.AVENUE_S, STREET_HALF],
		["EAST_ROAD", TownCity.EAST_ROAD, STREET_HALF],
		["SPINE", TownCity.SPINE, STREET_HALF],
		["KEEP_ROAD", TownCity.KEEP_ROAD, STREET_HALF],
		["CATH_FORE", TownCity.CATH_FORE, STREET_HALF],
		["BANK_ROW", TownCity.BANK_ROW, STREET_HALF],
	]
	var minors: Array = [
		["OT1", TownCity.OT1, LANE_HALF], ["OT2", TownCity.OT2, LANE_HALF],
		["OT3", TownCity.OT3, LANE_HALF], ["OT4", TownCity.OT4, LANE_HALF],
		["EW1", TownCity.EW1, LANE_HALF], ["EW2", TownCity.EW2, LANE_HALF],
		["EW3", TownCity.EW3, LANE_HALF],
		["LINK", TownCity.LINK, LANE_HALF],
		["QUAY_LANE", TownCity.QUAY_LANE, LANE_HALF],
		["CANAL_LANE", TownCity.CANAL_LANE, LANE_HALF],
		["SE_TRACK", TownCity.SE_TRACK, LANE_HALF],
		["GARDEN_LANE", TownCity.GARDEN_LANE, LANE_HALF],
	]
	for row: Array in majors:
		out["streets"].append(_line(str(row[0]), row[1] as Array, float(row[2]), "major"))
	for row2: Array in minors:
		out["streets"].append(_line(str(row2[0]), row2[1] as Array, float(row2[2]), "minor"))

	# field tracks and the towpath: drawn as thin dashed ways, not carriageways
	for row3: Array in [["F1", TownCity.F1], ["F2", TownCity.F2], ["F3", TownCity.F3],
			["F5", TownCity.F5], ["TOWPATH", TownCity.TOWPATH]]:
		out["tracks"].append(_line(str(row3[0]), row3[1] as Array, 16.0, "track"))

	# --- water -------------------------------------------------------------
	for row4: Array in [["CANAL_N", TownCity.CANAL_N], ["CANAL_E", TownCity.CANAL_E]]:
		out["water"].append(_line(str(row4[0]), row4[1] as Array, CANAL_HALF, "canal"))
	# The river is a full-width band across the south, not a polyline - it is the
	# one collider laid as a rect in `_water_colliders`, and it is the reason the
	# town has a harbour at all. A map of a port with no water is nonsense, so it
	# is dumped explicitly rather than hoped for.
	out["water"].append({
		"name": "RIVER", "class": "river", "half": TownCity.RIVER_HALF,
		"pts": [[0.0, TownCity.RIVER_Y], [TownCity.MAP_W, TownCity.RIVER_Y]],
	})
	out["quay"] = {"y0": TownCity.QUAY_Y0, "y1": TownCity.RIVER_Y - TownCity.RIVER_HALF,
		"x0": 2600.0, "x1": 4700.0}
	out["ponds"] = [{"x": TownCity.BASIN.x, "y": TownCity.BASIN.y, "rx": 236.0, "ry": 90.0,
		"name": "The Basin"}]

	# --- areas -------------------------------------------------------------
	for r: Rect2 in TownCity.FARM_FIELDS:
		out["fields"].append(_rect(r, "farm"))
	for r2: Rect2 in TownCity.ALLOT:
		out["fields"].append(_rect(r2, "allotment"))
	for r3: Rect2 in TownCity.BUILT_RECTS:
		out["built"].append(_rect(r3, "built"))

	# --- squares -----------------------------------------------------------
	for row5: Array in [["Trade Square", TownCity.TRADE_SQ], ["Cathedral Square", TownCity.CATH_SQ],
			["Ward Square", TownCity.WARD_SQ], ["The Harbour", TownCity.HARBOR_SQ],
			["Well Square", TownCity.WELL_SQ], ["Tavern Square", TownCity.TAVERN_SQ],
			["The Basin", TownCity.BASIN]]:
		var sp: Vector2 = row5[1]
		out["squares"].append({"name": str(row5[0]), "x": sp.x, "y": sp.y})
	for row6: Array in [["The Old Gate", TownCity.OLD_GATE], ["The East Gate", TownCity.EAST_GATE],
			["The Vigil Keep", TownCity.KEEP_DOOR]]:
		var gp: Vector2 = row6[1]
		out["squares"].append({"name": str(row6[0]), "x": gp.x, "y": gp.y, "gate": true})

	# --- every house, as planned (centre, width, height, kind) --------------
	if TownCity._plans.is_empty():
		TownCity._plan_all()
	for plan: Dictionary in TownCity._plans:
		var items: Array = plan.get("items", [])
		for it_v: Variant in items:
			var it: Dictionary = it_v
			if it.has("gap") or it.has("alley"):
				continue
			if not it.has("pos"):
				continue
			var pos: Vector2 = it["pos"]
			var kind: String = str(it.get("kind", "cottage"))
			var w: float = float(it.get("w", TownCity._house_w(kind, str(it.get("colour", "")))))
			var h: float = TownCity._house_h(kind)
			out["houses"].append({
				"x": snappedf(pos.x, 0.5), "y": snappedf(pos.y, 0.5),
				"w": snappedf(w, 0.5), "h": snappedf(h, 0.5),
				"kind": kind, "colour": str(it.get("colour", "")),
			})

	# --- what only the built scene knows: trees, walls, bridges ------------
	if world != null:
		_walk(world, out)

	return out


## Folders a sprite's texture can come from, and what that makes it on a map.
## The built scene is the only complete record: `_plans` covers the terraced
## rows and nothing else, so the keep, the cathedral, the market blocks, the
## harbour sheds and every gap-filled cottage are missing from it. Walking the
## scene finds all of them, with their true footprint.
const BUILDING_DIRS := ["/houses/", "/buildings/", "/world/town/", "/world/castle/"]
const BUILDING_WORDS := ["house", "cottage", "tower", "castle", "church", "chapel",
	"mill", "barn", "shed", "inn", "tavern", "shop", "keep", "manor", "hut", "stall"]
## Things that live in the building folders but are not buildings. Boats and
## quay furniture were being drawn as red blocks floating on the river.
const NOT_BUILDINGS := ["boat", "ship", "raft", "pier", "cargo", "crate", "barrel",
	"rope", "grate", "sign", "lamp", "lantern", "cart", "banner", "awning", "stair",
	"door", "window", "roof_", "chimney", "_parts", "sack", "anvil", "bench",
	"reed", "cloth", "grass", "bush", "flower", "shrub", "rock", "stone_", "post",
	"barrow", "well", "statue", "crypt", "gravestone", "stall_"]


## Sprites carry their identity in their texture path, which after the build is
## the only place a building, tree, wall or bridge position survives.
static func _walk(n: Node, out: Dictionary) -> void:
	if n is Sprite2D:
		var s := n as Sprite2D
		if s.texture != null and s.visible:
			var p: String = s.texture.resource_path.to_lower()
			var g: Vector2 = s.global_position
			var sc: Vector2 = s.global_scale
			if p.contains("plant_") or p.contains("tree") or p.contains("/vegetation/"):
				out["trees"].append({"x": snappedf(g.x, 1.0), "y": snappedf(g.y, 1.0),
					"s": snappedf(maxf(sc.x, 0.01), 0.01)})
			elif p.contains("wall") or p.contains("fence") or p.contains("palisade"):
				out["walls"].append(_foot(s, g, sc))
			elif p.contains("bridge"):
				out["bridges"].append(_foot(s, g, sc))
			elif _is_building(p):
				out["buildings"].append(_foot(s, g, sc))
	for c: Node in n.get_children():
		_walk(c, out)


static func _is_building(p: String) -> bool:
	for n: String in NOT_BUILDINGS:
		if p.contains(n):
			return false
	for d: String in BUILDING_DIRS:
		if p.contains(d):
			return true
	for w: String in BUILDING_WORDS:
		if p.contains(w):
			return true
	return false


## A sprite's footprint in world pixels. Godot centres a Sprite2D on its
## position by default, so the rect is the scaled texture size around it,
## shifted by any offset the builder set.
static func _foot(s: Sprite2D, g: Vector2, sc: Vector2) -> Dictionary:
	var t: Vector2 = Vector2(s.texture.get_width(), s.texture.get_height()) * sc.abs()
	var o: Vector2 = s.offset * sc
	var tl: Vector2 = g + o - (t * 0.5 if s.centered else Vector2.ZERO)
	return {"x": snappedf(tl.x, 1.0), "y": snappedf(tl.y, 1.0),
		"w": snappedf(t.x, 1.0), "h": snappedf(t.y, 1.0),
		"tex": s.texture.resource_path.get_file().get_basename()}


static func _line(nm: String, pts: Array, half: float, cls: String) -> Dictionary:
	var arr: Array = []
	for p_v: Variant in pts:
		var p: Vector2 = p_v
		arr.append([p.x, p.y])
	return {"name": nm, "half": half, "class": cls, "pts": arr}


static func _rect(r: Rect2, cls: String) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "class": cls}


static func _bounds(zone_id: String) -> Dictionary:
	var z: Dictionary = ZoneDefs.zone(zone_id)
	var w: float = 7168.0
	var h: float = 5120.0
	if z.has("tiles_w") and z.has("tiles_h"):
		w = float(int(z["tiles_w"]) * 32)
		h = float(int(z["tiles_h"]) * 32)
	return {"x": 0.0, "y": 0.0, "w": w, "h": h}


## Landmarks and quarters live in the minimap tables; the map is the one place
## they all have to agree, so they are dumped alongside the geometry.
static func _places(zone_id: String) -> Array:
	var arr: Array = []
	var tbl: Array = Minimap.PLACES.get(zone_id, [])
	for p_v: Variant in tbl:
		var p: Dictionary = p_v
		var pos: Vector2 = p.get("pos", Vector2.ZERO)
		arr.append({"x": pos.x, "y": pos.y, "kind": str(p.get("kind", "")),
			"label": str(p.get("label", ""))})
	return arr


static func _districts(zone_id: String) -> Array:
	var arr: Array = []
	var tbl: Array = Minimap.DISTRICTS.get(zone_id, [])
	for d_v: Variant in tbl:
		var d: Dictionary = d_v
		var pos: Vector2 = d.get("pos", Vector2.ZERO)
		arr.append({"x": pos.x, "y": pos.y, "r": float(d.get("r", 600.0)),
			"text": str(d.get("text", ""))})
	return arr


## Write the dump. Returns the absolute path written, or "" on failure.
static func run(zone_id: String, world: Node, path: String) -> String:
	var data: Dictionary = collect(zone_id, world)
	data["places"] = _places(zone_id)
	data["districts"] = _districts(zone_id)
	var gp: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	var f := FileAccess.open(gp, FileAccess.WRITE)
	if f == null:
		push_warning("[MapDump] cannot write %s" % gp)
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("[MapDump] %s  streets=%d water=%d buildings=%d trees=%d built=%d fields=%d places=%d" % [
		gp, (data["streets"] as Array).size(), (data["water"] as Array).size(),
		(data["buildings"] as Array).size(), (data["trees"] as Array).size(),
		(data["built"] as Array).size(), (data["fields"] as Array).size(),
		(data["places"] as Array).size()])
	return gp
