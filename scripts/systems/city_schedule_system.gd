extends Node
## CityScheduleSystem (autoload) — a real daily timetable for the 90 city folk.
##
## Why it exists: SmartNPCSystem's schedules are keyed to the TEN VILLAGE ids
## (data/npc_schedules.json), so not one city folk was scheduled; NPCLifeSystem's
## "routes" and "rest" only nudge an NPC's home by up to 60 px, so nobody ever
## went anywhere; and npc.gd's night handler pulls everyone home on its own. All
## three wrote the same private `_home` every second and fought each other.
##
## Design follows the shape the reference games converged on (Ultima VII's
## 3-hour slots, Kingdom Come's cap of eight activities, Stardew's
## time/place/facing/animation entry with an arrive-by variant, Gothic's
## resume-don't-restart interrupt contract, The Sims' "the place owns the
## activity"): 4-7 stops a day, each a PLACE plus an ACTIVITY, with the wander
## radius a property of the stop rather than of the NPC. At CYCLE_SECONDS 600
## one game hour is 25 real seconds, so stops are long (>= 1.5 game hours) and
## departures are staggered by a per-id hash instead of everyone leaving at once.
##
## It owns only the NPCs it claims (meta "rh_sched_owned"); the other systems
## stand down for exactly those. With the autoload absent, nothing changes.
##
## Data: res://data/city_schedules.json (hot-tunable; roles + a few one-offs).
## QA: RH_SCHED_TEST=1 runs a whole simulated day headless and prints a report.

const DATA_PATH := "res://data/city_schedules.json"
const TICK_S := 0.25
const ARRIVE_R := 10.0
const WAYPOINT_R := 14.0
const REPATH_S := 3.0
const STUCK_PX := 6.0
const STUCK_S := 6.0
const BOOT_GRACE_S := 2.0
const MAX_BLOCKS := 8
const DOOR_STAND_DY := -14.0
const HOURS_PER_REAL_S := 24.0 / 600.0

enum {MODE_AT, MODE_TRAVEL}

## Shared anchors, all derived from the city generator's published constants so
## this file never has to be re-tuned when the city moves. Never edits it.
const PLACES := {
	"trade_sq": Vector2(3300, 1180),
	"bank_row": Vector2(3560, 1060),
	"keep_door": Vector2(3600, 700),
	"keep_yard": Vector2(3600, 540),
	"cath_sq": Vector2(5400, 1020),
	"cath_door": Vector2(5400, 700),
	"churchyard": Vector2(5800, 510),
	"ward_sq": Vector2(5420, 2560),
	"well_sq": Vector2(2380, 2560),
	"tavern_sq": Vector2(3080, 3690),
	"harbor_sq": Vector2(3080, 4400),
	"quay_e": Vector2(4300, 4330),
	"east_gate": Vector2(6890, 2600),
	"old_gate": Vector2(2420, 810),
	"horse_fair": Vector2(2620, 1410),
	"allot_w": Vector2(4830, 1765),
	"allot_e": Vector2(5810, 1765),
	"allot_far": Vector2(6400, 1825),
	"field_n": Vector2(1630, 2425),
	"field_w": Vector2(620, 2885),
	"field_s": Vector2(1740, 2740),
	"field_sw": Vector2(630, 3210),
	"mill": Vector2(1390, 4436),
	"paddock": Vector2(1900, 3062),
	"shrine_ward": Vector2(5502, 3176),
	"stocks": Vector2(6880, 2860),
	"hospice": Vector2(6340, 1438),
}

## Activity -> default wander radius when a block does not give one.
const ACT_R := {
	"sleep": 0.0, "doorstep": 12.0, "stall": 6.0, "setup": 10.0, "packup": 12.0,
	"work": 20.0, "haul": 46.0, "browse": 34.0, "gossip": 26.0, "eat": 14.0,
	"drink": 16.0, "guard_post": 0.0, "patrol": 70.0, "pray": 0.0, "greet": 14.0,
}

var enabled: bool = true

var _cfg: Dictionary = {}
var _roles: Dictionary = {}
var _districts: Dictionary = {}
var _npc_cfg: Dictionary = {}
var _walk_speed: float = 56.0
var _stagger_min: float = 40.0
var _min_dwell: float = 1.5
var _far_snap: float = 900.0

## id -> {node, work, home, district, blocks, ats, bi, mode, dest, path,
##        path_i, repath_t, stuck_t, last_p, bad, spawn_radius}
var _st: Dictionary = {}
var _accum: float = 0.0
var _grace: float = BOOT_GRACE_S
var _booted: bool = false

signal npc_arrived(id: String, act: String)


func _ready() -> void:
	name = "CityScheduleSystem"
	enabled = OS.get_environment("RH_NOSCHED").is_empty()
	_load_data()
	call_deferred("_boot")


func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("CityScheduleSystem: missing " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary):
		push_warning("CityScheduleSystem: bad JSON at " + DATA_PATH)
		return
	_cfg = parsed
	_roles = _cfg.get("roles", {})
	_districts = _cfg.get("districts", {})
	_npc_cfg = _cfg.get("npcs", {})
	_walk_speed = float(_cfg.get("walk_speed", 56.0))
	_stagger_min = float(_cfg.get("stagger_minutes", 40.0))
	_min_dwell = float(_cfg.get("min_dwell_hours", 1.5))
	_far_snap = float(_cfg.get("far_snap_px", 900.0))
	var snap_env: String = OS.get_environment("RH_SCHED_SNAP")
	if not snap_env.is_empty():
		_far_snap = float(snap_env)
	if not _roles.has("default"):
		push_warning("CityScheduleSystem: roles.default is mandatory; schedules disabled")
		enabled = false


## Wait for the cast to exist, then claim every folk that has a schedule.
func _boot() -> void:
	if not enabled or _roles.is_empty():
		return
	for i in range(60):
		if not get_tree().get_nodes_in_group("npcs").is_empty():
			break
		await get_tree().process_frame
	# The navigation server bakes asynchronously; querying it before its first
	# synchronisation errors out, so give it frames before resolving doorsteps.
	for _f in range(30):
		await get_tree().process_frame
	var claimed: int = 0
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if not (node is Node2D):
			continue
		var id: String = str(node.name)
		# Only the CITY cast. The ten village folk keep their own shipped
		# SmartNPCSystem schedules and the approved village is left alone.
		if not id.begins_with("city_") and not _npc_cfg.has(id):
			continue
		var blocks: Array = _blocks_for(id)
		if blocks.is_empty():
			continue
		var n2: Node2D = node
		var work_v: Variant = n2.get("_home")
		var work: Vector2 = work_v if work_v is Vector2 else n2.global_position
		var radius_v: Variant = n2.get("_base_wander_radius")
		var cfg: Dictionary = _npc_cfg.get(id, {})
		var home: Vector2 = work
		if cfg.has("home"):
			var h: Array = cfg["home"]
			home = Vector2(float(h[0]), float(h[1]))
		else:
			home = _nearest_door(work)
		var ats := PackedFloat32Array()
		var jit: float = _jitter(id)
		for b_v: Variant in blocks:
			ats.append(fposmod(float((b_v as Dictionary).get("at", 8.0)) + jit, 24.0))
		var order: Array = []
		for i2 in range(ats.size()):
			order.append(i2)
		order.sort_custom(func(a, b): return ats[int(a)] < ats[int(b)])
		var sorted_ats := PackedFloat32Array()
		var sorted_blocks: Array = []
		for o_v: Variant in order:
			sorted_ats.append(ats[int(o_v)])
			sorted_blocks.append(blocks[int(o_v)])
		_st[id] = {
			"node": node, "work": work, "home": home,
			"district": _district_of(work),
			"blocks": sorted_blocks, "ats": sorted_ats,
			"bi": -1, "mode": MODE_AT, "dest": work,
			"path": PackedVector2Array(), "path_i": 0, "repath_t": 0.0,
			"stuck_t": 0.0, "last_p": n2.global_position, "bad": {},
			"spawn_radius": float(radius_v) if radius_v is float else 0.0,
		}
		node.set_meta("rh_sched_owned", true)
		claimed += 1
	_booted = true
	print("[CitySchedule] %d folk on a timetable" % claimed)
	if OS.get_environment("RH_SCHED_TEST") != "":
		call_deferred("_self_test")


## Blocks for an id: explicit override, else the configured role, else the role
## inferred from the id, else the mandatory default template.
func _blocks_for(id: String) -> Array:
	var cfg: Dictionary = _npc_cfg.get(id, {})
	if cfg.has("blocks"):
		return (cfg["blocks"] as Array).slice(0, MAX_BLOCKS)
	var role: String = str(cfg.get("role", ""))
	if role.is_empty():
		role = _infer_role(id)
	var tmpl: Dictionary = _roles.get(role, _roles.get("default", {}))
	return (tmpl.get("blocks", []) as Array).slice(0, MAX_BLOCKS)


## Role from the id's keywords (the ids carry their job: city_merchant_3).
func _infer_role(id: String) -> String:
	var l: String = id.to_lower()
	for pair: Array in [["guard", "guard"], ["warden", "guard"], ["watch", "guard"],
			["merchant", "merchant"], ["vendor", "merchant"], ["banker", "merchant"],
			["auction", "merchant"], ["trader", "merchant"], ["baker", "merchant"],
			["butcher", "merchant"], ["fish", "fisher"], ["eel", "fisher"],
			["ferry", "fisher"], ["dock", "dock"], ["porter", "dock"],
			["farm", "farmer"], ["shepherd", "farmer"], ["garden", "farmer"],
			["hay", "farmer"], ["priest", "priest"], ["nun", "priest"],
			["monk", "priest"], ["wander", "wanderer"], ["pilgrim", "wanderer"],
			["beggar", "wanderer"], ["child", "wanderer"], ["crier", "wanderer"]]:
		if l.contains(str(pair[0])):
			return str(pair[1])
	return "default"


func _district_of(p: Vector2) -> String:
	var best: String = "old_town"
	var best_d: float = INF
	for k_v: Variant in _districts:
		var d: Dictionary = _districts[k_v]
		var at_a: Array = d.get("at", [0, 0])
		var c := Vector2(float(at_a[0]), float(at_a[1]))
		var dist: float = p.distance_to(c)
		if dist < float(d.get("r", 900.0)) and dist < best_d:
			best_d = dist
			best = str(k_v)
	return best


## Deterministic per-id departure jitter in game-hours. This is the lever that
## stops ninety people leaving on the same tick.
func _jitter(id: String) -> float:
	return float(absi(id.hash()) % 997) / 997.0 * (_stagger_min / 60.0)


## The active block. `ats` is a RING: the last entry covers until the first one
## next morning, so this can never return -1 and never freezes an NPC.
func _index_for(ats: PackedFloat32Array, hour: float) -> int:
	if ats.is_empty():
		return -1
	var idx: int = ats.size() - 1
	for i in range(ats.size()):
		if hour >= ats[i]:
			idx = i
		else:
			break
	return idx


## Nearest terrace doorstep to `p`, so "home" needs no authoring for 90 folk.
func _nearest_door(p: Vector2) -> Vector2:
	var best: Vector2 = p
	var best_d: float = INF
	for row_v: Variant in TownCity.ROWS_EW:
		var row: Array = row_v
		for i in range(row.size() - 1):
			var a: Vector2 = row[i]
			var b: Vector2 = row[i + 1]
			var ab: Vector2 = b - a
			var l2: float = ab.length_squared()
			var t: float = 0.0
			if l2 > 0.0:
				t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var q: Vector2 = a + ab * t
			var d: float = p.distance_to(q)
			if d < best_d:
				best_d = d
				best = q
	if best_d > 2200.0:
		return _safe(p)
	return _safe(best + Vector2(0.0, DOOR_STAND_DY))


## A point guaranteed to be on the navmesh (obstacles are inflated at bake).
func _safe(p: Vector2) -> Vector2:
	var nav: Node = get_node_or_null("/root/NavSystem")
	if nav != null and nav.has_method("is_ready") and bool(nav.call("is_ready")) \
			and nav.has_method("closest_point"):
		return nav.call("closest_point", p)
	return p


## Resolve a block's place token to a world point.
func _place(id: String, s: Dictionary, b: Dictionary, bi: int) -> Vector2:
	var token: String = str(b.get("place", "$work"))
	if token.begins_with("@"):
		var parts: PackedStringArray = token.substr(1).split(",")
		if parts.size() == 2:
			return Vector2(float(parts[0]), float(parts[1]))
		return s["work"]
	if token == "$work":
		return s["work"]
	if token == "$home":
		return s["home"]
	var dist: Dictionary = _districts.get(str(s["district"]), {})
	if token == "$roam":
		var keys: Array = ["square", "market", "well", "shrine", "lane"]
		var pick: String = str(keys[absi((id + str(bi)).hash()) % keys.size()])
		return _resolve_key(dist, pick, s)
	if token.begins_with("$"):
		return _resolve_key(dist, token.substr(1), s)
	if PLACES.has(token):
		return PLACES[token]
	return s["work"]


## A district key with the documented fallback chain, so a folk in a district
## that has no tavern stays put instead of walking across the whole city.
func _resolve_key(dist: Dictionary, key: String, s: Dictionary) -> Vector2:
	for k: String in [key, "square", "market", "lane"]:
		if dist.has(k):
			var v: String = str(dist[k])
			if v.begins_with("@"):
				var parts: PackedStringArray = v.substr(1).split(",")
				if parts.size() == 2:
					return Vector2(float(parts[0]), float(parts[1]))
			elif PLACES.has(v):
				return PLACES[v]
	return s["home"]


## A small deterministic offset so a crowd at one anchor does not stack.
func _off(id: String, bi: int) -> Vector2:
	var a: float = deg_to_rad(float(absi((id + "o" + str(bi)).hash()) % 360))
	var r: float = 18.0 + 12.0 * float(absi(id.hash()) % 3)
	return Vector2(cos(a), sin(a)) * r


func _process(delta: float) -> void:
	if not enabled or not _booted or _st.is_empty():
		return
	if _grace > 0.0:
		_grace -= delta
		return
	_accum += delta
	if _accum < TICK_S:
		return
	var dt: float = _accum
	_accum = 0.0
	var hour: float = _hour()
	var ppos := Vector2(-1e9, -1e9)
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		ppos = player.global_position
	var dead: Array = []
	for id_v: Variant in _st:
		var id: String = id_v
		var s: Dictionary = _st[id]
		var node_v: Variant = s["node"]
		if not (node_v is Node2D) or not is_instance_valid(node_v as Node):
			dead.append(id)
			continue
		var npc: Node2D = node_v
		# Gothic's contract: an interrupt SUSPENDS the routine, never restarts it.
		if bool(npc.get("_talking")) or (npc.has_method("is_following") and bool(npc.call("is_following"))):
			npc.set("sched_active", false)
			s["stuck_t"] = 0.0
			continue
		var bi: int = _index_for(s["ats"], hour)
		if bi != int(s["bi"]):
			s["bi"] = bi
			_enter_block(id, s, npc, bi, ppos)
		elif int(s["mode"]) == MODE_TRAVEL:
			_tick_travel(id, s, npc, ppos, dt)
	for d_v: Variant in dead:
		_st.erase(d_v)


func _hour() -> float:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null:
		return 12.0
	var t: Variant = dn.get("time_of_day")
	return float(t) if t is float else 12.0


func _enter_block(id: String, s: Dictionary, npc: Node2D, bi: int, ppos: Vector2) -> void:
	if bi < 0 or bi >= (s["blocks"] as Array).size():
		return
	if (s["bad"] as Dictionary).has(bi):
		_fall_back_to_wander(s, npc)
		return
	var b: Dictionary = (s["blocks"] as Array)[bi]
	var dest: Vector2 = _safe(_place(id, s, b, bi) + _off(id, bi))
	s["dest"] = dest
	s["path"] = PackedVector2Array()
	s["path_i"] = 0
	s["repath_t"] = 0.0
	s["stuck_t"] = 0.0
	s["last_p"] = npc.global_position
	if npc.global_position.distance_to(dest) <= ARRIVE_R:
		_arrive(id, s, npc, b)
		return
	# Level-of-detail: if BOTH ends are far from the player, complete the trip
	# instantly - those frames would never be seen and cost 90 A* queries.
	if ppos.distance_to(npc.global_position) > _far_snap and ppos.distance_to(dest) > _far_snap:
		npc.global_position = dest
		_arrive(id, s, npc, b)
		return
	s["mode"] = MODE_TRAVEL
	npc.set("sched_speed", _walk_speed)
	npc.set("sched_target", dest)
	npc.set("sched_active", true)


func _tick_travel(id: String, s: Dictionary, npc: Node2D, ppos: Vector2, dt: float) -> void:
	var b: Dictionary = (s["blocks"] as Array)[int(s["bi"])]
	var dest: Vector2 = s["dest"]
	var here: Vector2 = npc.global_position
	if here.distance_to(dest) <= ARRIVE_R:
		_arrive(id, s, npc, b)
		return
	if ppos.distance_to(here) > _far_snap and ppos.distance_to(dest) > _far_snap:
		npc.global_position = dest
		_arrive(id, s, npc, b)
		return
	var path: PackedVector2Array = s["path"]
	s["repath_t"] = float(s["repath_t"]) - dt
	if path.size() < 2 or float(s["repath_t"]) <= 0.0:
		var nav: Node = get_node_or_null("/root/NavSystem")
		if nav != null and nav.has_method("path_to"):
			path = nav.call("path_to", here, dest)
		s["path"] = path
		s["path_i"] = 1
		s["repath_t"] = REPATH_S
		if path.size() < 2:
			# no route: try once more next block change, then stand down
			if bool(s.get("retried", false)):
				_abort(id, s, npc)
				return
			s["retried"] = true
			npc.set("sched_target", dest)
			npc.set("sched_active", true)
			return
	s["retried"] = false
	var pi: int = int(s["path_i"])
	while pi < path.size() - 1 and here.distance_to(path[pi]) <= WAYPOINT_R:
		pi += 1
	s["path_i"] = pi
	npc.set("sched_target", path[pi])
	npc.set("sched_active", true)
	# stuck detector
	if here.distance_to(s["last_p"]) < STUCK_PX:
		s["stuck_t"] = float(s["stuck_t"]) + dt
		if float(s["stuck_t"]) >= STUCK_S:
			_abort(id, s, npc)
	else:
		s["stuck_t"] = 0.0
		s["last_p"] = here


func _arrive(id: String, s: Dictionary, npc: Node2D, b: Dictionary) -> void:
	s["mode"] = MODE_AT
	npc.set("sched_active", false)
	npc.set("velocity", Vector2.ZERO)
	var act: String = str(b.get("act", "work"))
	var r: float = float(b.get("r", ACT_R.get(act, 16.0)))
	npc.set("_home", s["dest"])
	npc.set("_base_wander_radius", r)
	npc.set("_wander_radius", r)
	npc.set("_walking", false)
	npc.set("_idle_time_left", randf_range(0.4, 2.5))
	var face: String = str(b.get("face", ""))
	if not face.is_empty() and npc.has_method("sched_face"):
		npc.call("sched_face", face)
	npc_arrived.emit(id, act)


## Oblivion's documented failure was actors stuck on unreachable targets. This
## is the ladder out: warn once, blacklist that block for the session, and
## revert to exactly the shipped wander behaviour at the folk's own spawn.
func _abort(id: String, s: Dictionary, npc: Node2D) -> void:
	var bi: int = int(s["bi"])
	(s["bad"] as Dictionary)[bi] = true
	push_warning("CityScheduleSystem: %s cannot reach block %d at %s" % [id, bi, str(s["dest"])])
	_fall_back_to_wander(s, npc)


func _fall_back_to_wander(s: Dictionary, npc: Node2D) -> void:
	s["mode"] = MODE_AT
	npc.set("sched_active", false)
	npc.set("velocity", Vector2.ZERO)
	npc.set("_home", s["work"])
	npc.set("_base_wander_radius", s["spawn_radius"])
	npc.set("_wander_radius", s["spawn_radius"])


# --- QA ------------------------------------------------------------------------

## RH_SCHED_TEST=1: walk every tracked folk through a whole simulated day at
## high speed and report anyone who never reaches a stop or ends inside a wall.
func _self_test() -> void:
	await get_tree().process_frame
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null:
		print("[SCHED_TEST] no DayNight")
		return
	var visited: Dictionary = {}
	var aborts: int = 0
	for h in range(0, 48):
		var hour: float = float(h) * 0.5
		dn.set("time_of_day", hour)
		for i in range(6):
			await get_tree().process_frame
		for id_v: Variant in _st:
			var s: Dictionary = _st[id_v]
			visited[id_v] = int(visited.get(id_v, 0)) + (1 if int(s["mode"]) == MODE_AT else 0)
			aborts += (s["bad"] as Dictionary).size()
	var stuck: Array = []
	for id_v2: Variant in _st:
		if int(visited.get(id_v2, 0)) < 6:
			stuck.append(id_v2)
	print("[SCHED_TEST] tracked=%d  never-settled=%d  blacklisted-blocks=%d" % [_st.size(), stuck.size(), aborts])
	for sid_v: Variant in stuck.slice(0, 12):
		print("[SCHED_TEST] never settled: ", sid_v)
	# collision audit: is anyone standing inside a solid body right now?
	var inside: int = 0
	var space: PhysicsDirectSpaceState2D = get_tree().root.world_2d.direct_space_state
	for id_v3: Variant in _st:
		var n_v: Variant = (_st[id_v3] as Dictionary)["node"]
		if not (n_v is Node2D) or not is_instance_valid(n_v as Node):
			continue
		var q := PhysicsPointQueryParameters2D.new()
		q.position = (n_v as Node2D).global_position
		q.collision_mask = 1
		q.collide_with_areas = false
		q.collide_with_bodies = true
		if space.intersect_point(q, 1).size() > 0:
			inside += 1
			print("[SCHED_TEST] inside a collider: ", id_v3, " @", (n_v as Node2D).global_position)
	print("[SCHED_TEST] inside-collider=%d" % inside)
