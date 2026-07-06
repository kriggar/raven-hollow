extends Node
## NPCCastSystem -- autoload (/root/NPCCastSystem). BACKLOG #29 (the ~243-NPC
## cast rollout across the 40-zone world) + #107 (the 14 Collector's-Coast
## zones of Continent 2). DATA / ROSTER layer only: this system owns the
## named cast of Raven Hollow -- who lives where, their role, faction, a
## one-line personality and two signature barks. NO art, NO sprites, NO
## spawning; the gauntlet/visual pass is out of scope.
##
## The roster is authored deterministically (index-varied, no RNG) into
## data/npc_cast.json -- an innkeeper, a smith, a merchant, wardens, a
## chronicler and commoners for every BUILT zone, plus the Coast's dockmasters,
## ledger-clerks and Morven watchers. Faction ids match data/factions.json;
## zone ids match scripts/zone_defs.gd.
##
## Everything is additive and null-safe: no other system's file is touched, and
## nothing here needs a live world or player. A headless boot with no scene must
## never crash -- every external singleton call is guarded (get_node_or_null),
## and populate() degrades to an inert announce when there is no world/spawner.
##
## Public API:
##   cast_for_zone(zone) -> Array        the roster (Array of NPC dicts) of a zone
##   npc(id) -> Dictionary               one NPC by id ({} if unknown)
##   roster_size() -> int                total NPC count
##   roles() -> Array                    distinct role names, sorted
##   zones() -> Array                    zone ids that have a cast
##   coast_zones() -> Array              the Collector's-Coast zone ids (#107)
##   has_npc(id) -> bool
##   populate(zone) -> int               guarded hand-off to a live world +
##                                       SmartNPCSystem; inert (announce-only)
##                                       headless -- returns roster size
## Signals: cast_loaded(count), zone_populated(zone, count).

signal cast_loaded(count)
signal zone_populated(zone, count)

const DATA_PATH := "res://data/npc_cast.json"

var _npcs: Array = []                # ordered Array of NPC dicts
var _by_id: Dictionary = {}          # id -> npc dict
var _by_zone: Dictionary = {}        # zone_id -> Array of npc dicts
var _coast: Array = []               # coast zone ids (from data)


func _ready() -> void:
	_load_data()
	if not OS.get_environment("RH_NPCCAST_TEST").is_empty():
		_run_selftest()


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_npcs.clear()
	_by_id.clear()
	_by_zone.clear()
	_coast = _arr(root.get("coast_zones", [])).duplicate()
	for e_v: Variant in _arr(root.get("npcs", [])):
		var e: Dictionary = _dict(e_v)
		var id: String = str(e.get("id", ""))
		if id == "" or _by_id.has(id):
			continue  # skip blank / duplicate ids defensively
		# Normalize to a stable shape so consumers never KeyError.
		var rec: Dictionary = {
			"id": id,
			"name": str(e.get("name", id)),
			"zone": str(e.get("zone", "")),
			"role": str(e.get("role", "Commoner")),
			"faction": str(e.get("faction", "")),
			"personality": str(e.get("personality", "")),
			"lines": _arr(e.get("lines", [])).duplicate(),
		}
		_npcs.append(rec)
		_by_id[id] = rec
		var z: String = rec["zone"]
		if not _by_zone.has(z):
			_by_zone[z] = []
		(_by_zone[z] as Array).append(rec)
	if _npcs.is_empty():
		push_warning("NPCCastSystem: no cast loaded from %s" % DATA_PATH)
	cast_loaded.emit(_npcs.size())


# --- Query API --------------------------------------------------------------

func cast_for_zone(zone: String) -> Array:
	return (_by_zone.get(zone, []) as Array).duplicate()


func npc(id: String) -> Dictionary:
	return _dict(_by_id.get(id, {})).duplicate(true)


func has_npc(id: String) -> bool:
	return _by_id.has(id)


func roster_size() -> int:
	return _npcs.size()


func zones() -> Array:
	return _by_zone.keys()


func coast_zones() -> Array:
	return _coast.duplicate()


func roles() -> Array:
	var seen: Dictionary = {}
	for rec_v: Variant in _npcs:
		seen[str((rec_v as Dictionary).get("role", ""))] = true
	var out: Array = seen.keys()
	out.sort()
	return out


func faction_of(id: String) -> String:
	return str(_dict(_by_id.get(id, {})).get("faction", ""))


# --- Populate (guarded hand-off; inert headless) ----------------------------

## Announce a zone's roster to a live world. This is a DATA system: it does not
## spawn sprites. When a world scene and the SmartNPCSystem autoload both exist,
## a future spawner would instance these entries; here we simply resolve the
## roster and emit zone_populated. Fully guarded -- safe with no world/player,
## returns the number of NPCs the zone would receive.
func populate(zone: String) -> int:
	var cast: Array = cast_for_zone(zone)
	if cast.is_empty():
		return 0
	# Guarded environment probe -- everything below is optional and null-safe.
	var world: Node = _world()
	var smart: Node = get_node_or_null("/root/SmartNPCSystem")
	if world != null and smart != null:
		# A live world + the smart-NPC director are present. We do NOT fabricate
		# nodes here (no art/spawn in scope); we only announce the roster so a
		# spawner can pick it up. If SmartNPCSystem ever exposes a data intake,
		# call it defensively without assuming its signature.
		if smart.has_method("register_cast"):
			smart.call("register_cast", zone, cast.duplicate(true))
	zone_populated.emit(zone, cast.size())
	return cast.size()


func _world() -> Node:
	# A "world" is any of the usual live-scene markers; degrade to null headless.
	for grp: String in ["world", "level", "map"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null:
			return n
	var cs: Node = get_tree().current_scene
	if cs != null and not get_tree().get_nodes_in_group("player").is_empty():
		return cs
	return null


# --- Self-test (RH_NPCCAST_TEST) --------------------------------------------

func _run_selftest() -> void:
	var n_npcs: int = roster_size()
	# All ids unique (load already dedups; verify the source honored it too).
	var ids: Dictionary = {}
	var dup := false
	for rec_v: Variant in _npcs:
		var id: String = str((rec_v as Dictionary).get("id", ""))
		if ids.has(id):
			dup = true
		ids[id] = true
	# Every BUILT zone must field at least one NPC.
	var built: Array = _built_zone_ids()
	var covered: int = 0
	var missing: Array = []
	for z_v: Variant in built:
		var z: String = str(z_v)
		if int((_by_zone.get(z, []) as Array).size()) >= 1:
			covered += 1
		else:
			missing.append(z)
	# Coast zones (#107) all covered.
	var coast_ok := true
	var coast_hit: int = 0
	for c_v: Variant in _coast:
		if int((_by_zone.get(str(c_v), []) as Array).size()) >= 1:
			coast_hit += 1
		else:
			coast_ok = false
	var zones_ok: bool = missing.is_empty() and not built.is_empty()
	var ok: bool = n_npcs >= 200 and zones_ok and not dup and coast_ok \
			and _coast.size() >= 14
	print("NPCCAST SELFTEST %s npcs=%d zones=%d coast=%d" % [
		"PASS" if ok else "FAIL", n_npcs, covered, coast_hit])
	if not ok:
		print("NPCCAST detail: unique_ids=%s built=%d missing=%s coast_defs=%d" % [
			str(not dup), built.size(), str(missing), _coast.size()])


## Built-zone ids from ZoneDefs (the authoritative registry). ZoneDefs is a
## repo class_name and the static call is parse-safe; if the registry ever comes
## back empty we degrade to the zones present in our own data.
func _built_zone_ids() -> Array:
	var out: Array = []
	for z_v: Variant in ZoneDefs.built_ids():
		out.append(str(z_v))
	if out.is_empty():
		return _by_zone.keys()
	return out


# --- helpers ----------------------------------------------------------------

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("NPCCastSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Save contract (SaveSystem group pattern; inert -- roster is static) ------

func serialize() -> Dictionary:
	return {}


func deserialize(_d: Dictionary) -> void:
	pass
