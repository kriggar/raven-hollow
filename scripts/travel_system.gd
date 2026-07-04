extends Node
## TravelSystem (autoload) — WoW-style waystation fast travel for the 40-zone
## world (WORLD_PLAN.md). Stations are registered by ZoneBuilder as zones build
## (authored in zone defs); the player DISCOVERS a station by walking within
## range of it, and may then fast-travel between discovered stations that are
## connected in the route graph (ZoneDefs.ROUTES — coach roads, river barges,
## and the Grey Ferry era-crossing between continents).
##
## v1 scope: registry + discovery + route connectivity + travel via
## main.change_map. Coin costs recorded per hop (charged when economy hooks in).

signal station_discovered(station_id: String)

## station_id -> {zone, pos}
var _stations: Dictionary = {}
## discovered station ids
var _discovered: Dictionary = {}


func register_station(station_id: String, zone_id: String, pos: Vector2) -> void:
	if station_id.is_empty():
		return
	_stations[station_id] = {"zone": zone_id, "pos": pos}


func try_discover(player_pos: Vector2, zone_id: String) -> String:
	## Called from the main travel loop: discovers the nearest undiscovered
	## station in range (returns its id for a banner, "" otherwise).
	for sid: String in _stations:
		if _discovered.has(sid):
			continue
		var st: Dictionary = _stations[sid]
		if str(st["zone"]) != zone_id:
			continue
		if (st["pos"] as Vector2).distance_to(player_pos) <= 90.0:
			_discovered[sid] = true
			station_discovered.emit(sid)
			return sid
	return ""


func is_discovered(station_id: String) -> bool:
	return _discovered.has(station_id)


func discovered_ids() -> Array[String]:
	var out: Array[String] = []
	for sid: String in _discovered:
		out.append(sid)
	return out


func stations_in_zone(zone_id: String) -> Array[String]:
	var out: Array[String] = []
	for sid: String in _stations:
		if str((_stations[sid] as Dictionary)["zone"]) == zone_id:
			out.append(sid)
	return out


func station_pos(station_id: String) -> Vector2:
	if not _stations.has(station_id):
		return Vector2.ZERO
	return (_stations[station_id] as Dictionary)["pos"]


func station_zone(station_id: String) -> String:
	if not _stations.has(station_id):
		return ""
	return str((_stations[station_id] as Dictionary)["zone"])


## Route connectivity: BFS over ZoneDefs.ROUTES limited to discovered stations
## (start and goal must both be discovered; intermediate hops must exist but
## don't need discovery — the coach knows the road).
func can_travel(from_id: String, to_id: String) -> bool:
	if not (_discovered.has(from_id) and _discovered.has(to_id)):
		return false
	var frontier: Array[String] = [from_id]
	var seen: Dictionary = {from_id: true}
	while not frontier.is_empty():
		var cur: String = frontier.pop_front()
		if cur == to_id:
			return true
		for link: String in ZoneDefs.route_links(cur):
			if not seen.has(link):
				seen[link] = true
				frontier.append(link)
	return false


## Fast-travel: fades through fog to the target station's zone + position.
func travel_to(station_id: String) -> void:
	if not _stations.has(station_id):
		return
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("change_map_to_pos"):
		return
	var st: Dictionary = _stations[station_id]
	main.call("change_map_to_pos", str(st["zone"]), st["pos"] as Vector2)


## Save/load hooks (SaveSystem wires these).
func save_state() -> Dictionary:
	return {"discovered": _discovered.keys()}


func load_state(data: Dictionary) -> void:
	_discovered.clear()
	for sid: Variant in data.get("discovered", []):
		_discovered[str(sid)] = true
