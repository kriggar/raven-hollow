extends Node
## NPCLifeSystem -- autoload (/root/NPCLifeSystem). BACKLOG #88
## "NPC life layer": bark bubbles ("Fresh bread!"), organic chatter/friendships,
## and jobs/routes/inn-rest. The town-that-talks pass, built ADDITIVELY on top of
## the shipped npc.gd + SmartNPCSystem without editing either.
##
## What it does, all guarded and inert with no world/player:
##   * BARKS -- a registered NPC occasionally says a role/zone/region-flavored line
##     as a short floating speech bubble above its head (self-instanced Label; if the
##     node has no position it falls back to a signal-only bark). Pulls extra ambient
##     colour from NarrativeSystem.bark(key) when present (guarded).
##   * CHATTER -- two nearby registered NPCs whose roles are a seeded FRIEND pair
##     trade a short scripted exchange (alternating bubbles). Friendship state is a
##     per-id-pair score you can read/adjust.
##   * ROUTES -- each registered NPC walks a home-relative daily job route by slowly
##     re-homing (guarded write to npc.gd's `_home`, exactly like SmartNPCSystem), and
##     at night is sent to the inn to rest (guarded on a DayNight clock source).
##
## Nothing here edits another system's file; every external call is guarded
## (get_node_or_null / has_method / _has_prop) so a cold headless boot never crashes.
##
## Public API (node = a Node2D NPC, or a bare string id):
##   register_npc(node_or_id, role := "", zone := "")   add/refresh an NPC
##   is_registered(id) -> bool ; registered_ids() -> Array ; npc_count() -> int
##   bark(id_or_node, text := "") -> bool               force a bark bubble now
##   run_chatter(id_a, id_b) -> bool                    play an exchange between two
##   advance_route(id) -> int                           step the job route, new index
##   send_to_rest(id) -> bool                           route the NPC to the inn
##   friendship(id_a, id_b) -> int                      current pair score
##   adjust_friendship(id_a, id_b, delta) -> int        change + return the score
##   are_friends(id_a, id_b) -> bool
## Signals: bark_bubbled(id, text), chatter_started(id_a, id_b, topic),
##   npc_routed(id, waypoint_label), npc_rested(id).

signal bark_bubbled(id, text)
signal chatter_started(id_a, id_b, topic)
signal npc_routed(id, waypoint_label)
signal npc_rested(id)

const DATA_PATH := "res://data/npc_life.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"

const TICK_S := 0.7                 # ~1.4 Hz director poll
const ROUTE_ADVANCE_S := 22.0       # seconds between route waypoints (day)
const BUBBLE_SECONDS := 2.6
const KNOWN_ROLES := [
	"blacksmith", "merchant", "innkeeper", "baker", "farmer", "fisher",
	"herbalist", "gravekeeper", "priest", "guard", "gatewarden", "maid",
	"hunter", "wanderer", "child", "drunk",
]

# --- data (loaded in _ready) -------------------------------------------------
var _barks: Dictionary = {}         # {role:{}, region:{}, zone:{}, generic:[]}
var _chatter: Array = []            # [{topic, lines:[...]}]
var _routes: Dictionary = {}        # {role:{...}, default:[...]}
var _friend_pairs: Dictionary = {}  # "roleA|roleB" -> true
var _rival_pairs: Dictionary = {}   # "roleA|roleB" -> true
var _bark_cd_range := Vector2(11.0, 24.0)
var _chatter_cd_range := Vector2(20.0, 44.0)
var _chatter_range := 96.0
var _rest_from := 22.0
var _rest_to := 6.0
var _inn_offset := Vector2(-60.0, -20.0)
var _narr_bark_chance := 0.22

# --- runtime state -----------------------------------------------------------
## id -> {node, role, zone, home:Vector2, bark_cd, route_idx, route_cd,
##        resting, bark_cursor}
var _npc: Dictionary = {}
## "min_id|max_id" -> friendship score (int)
var _friend_score: Dictionary = {}
var _chatter_cd: float = 0.0
var _accum: float = 0.0
var _font: FontFile = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_font()
	_load_data()
	set_process(true)
	if not OS.get_environment("RH_NPCLIFE_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_barks = _dict(root.get("barks", {}))
	_chatter = _arr(root.get("chatter", []))
	_routes = _dict(root.get("routes", {}))
	_chatter_range = float(root.get("chatter_range", 96.0))
	_rest_from = float(root.get("rest_from", 22.0))
	_rest_to = float(root.get("rest_to", 6.0))
	_narr_bark_chance = float(root.get("narrative_bark_chance", 0.22))
	var bc: Array = _arr(root.get("bark_cooldown", [11.0, 24.0]))
	if bc.size() >= 2:
		_bark_cd_range = Vector2(float(bc[0]), float(bc[1]))
	var cc: Array = _arr(root.get("chatter_cooldown", [20.0, 44.0]))
	if cc.size() >= 2:
		_chatter_cd_range = Vector2(float(cc[0]), float(cc[1]))
	var io: Dictionary = _dict(root.get("inn_offset", {}))
	_inn_offset = Vector2(float(io.get("x", -60.0)), float(io.get("y", -20.0)))
	for pair_v: Variant in _arr(root.get("friend_pairs", [])):
		_friend_pairs[_role_key(pair_v)] = true
	for pair_v: Variant in _arr(root.get("rival_pairs", [])):
		_rival_pairs[_role_key(pair_v)] = true
	if _barks.is_empty():
		push_warning("NPCLifeSystem: no bark data loaded from %s" % DATA_PATH)


func _role_key(pair_v: Variant) -> String:
	var a: Array = _arr(pair_v)
	if a.size() < 2:
		return ""
	var r0: String = str(a[0])
	var r1: String = str(a[1])
	return "%s|%s" % ([r0, r1] if r0 <= r1 else [r1, r0])


# --- registration ------------------------------------------------------------

## Register (or refresh) an NPC. Pass a live Node2D (its name is the id and its
## position anchors bubbles) or a bare string id. `role` drives its bark pool and
## job route; if omitted it is inferred from the node/id name (trailing digits
## stripped). `zone` selects zone/region bark colour; may be left blank.
func register_npc(node_or_id: Variant, role: String = "", zone: String = "") -> void:
	var node: Node = node_or_id if node_or_id is Node else null
	var id: String = str((node as Node).name) if node != null else str(node_or_id)
	if id == "":
		return
	if role == "":
		role = _infer_role(node, id)
	var home: Vector2 = Vector2.ZERO
	if node is Node2D:
		var h: Variant = node.get("_home")
		home = h if h is Vector2 else (node as Node2D).global_position
	var st: Dictionary = _npc.get(id, {})
	st["node"] = node
	st["role"] = role
	st["zone"] = zone
	st["home"] = home
	st["route_idx"] = int(st.get("route_idx", 0))
	st["resting"] = bool(st.get("resting", false))
	st["bark_cursor"] = int(st.get("bark_cursor", _rng.randi()))
	st["bark_cd"] = _rng.randf_range(_bark_cd_range.x, _bark_cd_range.y)
	st["route_cd"] = _rng.randf_range(ROUTE_ADVANCE_S * 0.5, ROUTE_ADVANCE_S)
	_npc[id] = st
	# Seed default friendships/rivalries with every other registered NPC by role.
	for other_id: String in _npc.keys():
		if other_id == id:
			continue
		var rk: String = _pair_role_key(role, str(_dict(_npc[other_id]).get("role", "")))
		if _friend_pairs.has(rk) and friendship(id, other_id) == 0:
			adjust_friendship(id, other_id, 20)
		elif _rival_pairs.has(rk) and friendship(id, other_id) == 0:
			adjust_friendship(id, other_id, -20)


func is_registered(id: String) -> bool:
	return _npc.has(id)


func registered_ids() -> Array:
	return _npc.keys()


func npc_count() -> int:
	return _npc.size()


func role_of(id: String) -> String:
	return str(_dict(_npc.get(id, {})).get("role", ""))


func _infer_role(node: Node, id: String) -> String:
	if node != null:
		var r: Variant = node.get("npc_role")
		if r is String and str(r) != "":
			return str(r)
		var r2: Variant = node.get("role")
		if r2 is String and str(r2) != "":
			return str(r2)
	# Strip trailing digits ("wanderer2" -> "wanderer") and match a known role.
	var base: String = id.to_lower()
	while base.length() > 0 and base[base.length() - 1] >= "0" and base[base.length() - 1] <= "9":
		base = base.substr(0, base.length() - 1)
	if KNOWN_ROLES.has(base):
		return base
	for role: String in KNOWN_ROLES:
		if base.find(role) != -1:
			return role
	return base


# --- barks -------------------------------------------------------------------

## Force a bark now. `text` empty -> a role/zone/region-flavoured line is chosen.
## Returns true if a bubble was shown or (positionless) the signal was emitted.
func bark(id_or_node: Variant, text: String = "") -> bool:
	var id: String = str((id_or_node as Node).name) if id_or_node is Node else str(id_or_node)
	if not _npc.has(id):
		# Allow a raw bark on an unregistered node too (still guarded/safe).
		if id_or_node is Node2D:
			register_npc(id_or_node)
		else:
			return false
	var st: Dictionary = _dict(_npc.get(id, {}))
	if text == "":
		text = _pick_bark(st)
	if text == "":
		return false
	bark_bubbled.emit(id, text)
	var node: Variant = st.get("node")
	if is_instance_valid(node) and node is Node2D and (node as Node2D).is_inside_tree():
		_spawn_bubble(node, text, Color(0.93, 0.88, 0.70))
		return true
	# No usable position: signal-only bark (still counts as delivered).
	return true


func _pick_bark(st: Dictionary) -> String:
	var pools: Array = []
	var role_map: Dictionary = _dict(_barks.get("role", {}))
	var role: String = str(st.get("role", ""))
	if role_map.has(role):
		pools.append(_arr(role_map[role]))
	var zone: String = str(st.get("zone", ""))
	var zone_map: Dictionary = _dict(_barks.get("zone", {}))
	if zone != "" and zone_map.has(zone):
		pools.append(_arr(zone_map[zone]))
	var region_map: Dictionary = _dict(_barks.get("region", {}))
	var region: String = _region_for_zone(zone)
	if region != "" and region_map.has(region):
		pools.append(_arr(region_map[region]))
	pools.append(_arr(_barks.get("generic", [])))
	# Occasionally borrow an ambient line from NarrativeSystem (guarded).
	if _rng.randf() < _narr_bark_chance:
		var nl: String = _narrative_bark(zone if zone != "" else region)
		if nl != "":
			return nl
	# Pick a random non-empty pool (so zone/region flavour surfaces, not just role),
	# then walk it by cursor so repeats vary without RNG-picking the same line.
	var nonempty: Array = []
	for pool_v: Variant in pools:
		var pool: Array = _arr(pool_v)
		if not pool.is_empty():
			nonempty.append(pool)
	if nonempty.is_empty():
		return ""
	var cursor: int = int(st.get("bark_cursor", 0))
	st["bark_cursor"] = cursor + 1
	var chosen: Array = nonempty[_rng.randi() % nonempty.size()]
	return str(chosen[cursor % chosen.size()])


func _narrative_bark(key: String) -> String:
	if key == "":
		return ""
	var ns: Node = get_node_or_null("/root/NarrativeSystem")
	if ns != null and ns.has_method("bark"):
		var v: Variant = ns.call("bark", key)
		if v is String:
			return str(v)
	return ""


func _spawn_bubble(node: Node2D, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.name = "LifeBubble"
	lbl.text = text
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(140.0, 12.0)
	lbl.position = Vector2(-70.0, -60.0)
	lbl.z_index = 5
	node.add_child(lbl)
	if lbl.is_inside_tree():
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "position:y", -72.0, BUBBLE_SECONDS)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, BUBBLE_SECONDS).set_delay(0.9)
		tw.tween_callback(lbl.queue_free)
	else:
		lbl.queue_free()


# --- chatter -----------------------------------------------------------------

## Play a scripted chatter exchange between two registered NPCs (alternating
## bubbles a,b,a,b...). Returns true if an exchange was staged.
func run_chatter(id_a: String, id_b: String) -> bool:
	if id_a == id_b or not _npc.has(id_a) or not _npc.has(id_b):
		return false
	if _chatter.is_empty():
		return false
	var ex: Dictionary = _dict(_chatter[_rng.randi() % _chatter.size()])
	var lines: Array = _arr(ex.get("lines", []))
	if lines.is_empty():
		return false
	var topic: String = str(ex.get("topic", ""))
	chatter_started.emit(id_a, id_b, topic)
	# Stagger the alternating lines so they read as a back-and-forth.
	for i in range(lines.size()):
		var speaker: String = id_a if (i % 2 == 0) else id_b
		var line: String = str(lines[i])
		var delay: float = float(i) * 1.4
		_bark_delayed(speaker, line, delay)
	# Friends chatting grow a little closer.
	adjust_friendship(id_a, id_b, 1)
	return true


func _bark_delayed(id: String, line: String, delay: float) -> void:
	if delay <= 0.0:
		bark(id, line)
		return
	if not is_inside_tree():
		bark(id, line)
		return
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func() -> void:
		if _npc.has(id):
			bark(id, line))


# --- friendship state --------------------------------------------------------

func _pair_key(id_a: String, id_b: String) -> String:
	return "%s|%s" % ([id_a, id_b] if id_a <= id_b else [id_b, id_a])


func _pair_role_key(role_a: String, role_b: String) -> String:
	return "%s|%s" % ([role_a, role_b] if role_a <= role_b else [role_b, role_a])


func friendship(id_a: String, id_b: String) -> int:
	return int(_friend_score.get(_pair_key(id_a, id_b), 0))


func adjust_friendship(id_a: String, id_b: String, delta: int) -> int:
	var k: String = _pair_key(id_a, id_b)
	var v: int = clampi(int(_friend_score.get(k, 0)) + delta, -100, 100)
	_friend_score[k] = v
	return v


func are_friends(id_a: String, id_b: String) -> bool:
	return friendship(id_a, id_b) > 0


# --- routes / inn-rest -------------------------------------------------------

## Advance an NPC one step along its job route, re-homing it (guarded) so the
## shipped wander loop orbits the new waypoint. Returns the new waypoint index.
func advance_route(id: String) -> int:
	var st: Dictionary = _dict(_npc.get(id, {}))
	if st.is_empty():
		return -1
	var wps: Array = _route_for(str(st.get("role", "")))
	if wps.is_empty():
		return int(st.get("route_idx", 0))
	var idx: int = (int(st.get("route_idx", 0)) + 1) % wps.size()
	st["route_idx"] = idx
	st["resting"] = false
	var wp: Dictionary = _dict(wps[idx])
	var off := Vector2(float(wp.get("dx", 0.0)), float(wp.get("dy", 0.0)))
	_rehome(st, off)
	npc_routed.emit(id, str(wp.get("label", "")))
	return idx


## Send an NPC to the inn to rest for the night (re-homes to the inn offset).
func send_to_rest(id: String) -> bool:
	var st: Dictionary = _dict(_npc.get(id, {}))
	if st.is_empty():
		return false
	if bool(st.get("resting", false)):
		return false
	st["resting"] = true
	_rehome(st, _inn_offset)
	npc_rested.emit(id)
	return true


func _route_for(role: String) -> Array:
	var by_role: Dictionary = _dict(_routes.get("role", {}))
	if by_role.has(role):
		return _arr(by_role[role])
	return _arr(_routes.get("default", []))


func _rehome(st: Dictionary, offset: Vector2) -> void:
	var node: Variant = st.get("node")
	if not is_instance_valid(node) or not (node is Node2D):
		return
	var target: Vector2 = (st.get("home", Vector2.ZERO) as Vector2) + offset
	if _has_prop(node, "_home"):
		(node as Node2D).set("_home", target)


func _is_rest_hour(hour: float) -> bool:
	if _rest_from <= _rest_to:
		return hour >= _rest_from and hour < _rest_to
	return hour >= _rest_from or hour < _rest_to


# --- director poll (guarded; inert with no registered NPCs) ------------------

func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK_S:
		return
	var dt: float = _accum
	_accum = 0.0
	if _npc.is_empty():
		return
	_chatter_cd = maxf(0.0, _chatter_cd - dt)
	var hour: float = _now_hour()
	var resting: bool = _is_rest_hour(hour)
	# Prune dead nodes; tick barks + routes.
	for id: String in _npc.keys():
		var st: Dictionary = _npc[id]
		var node: Variant = st.get("node")
		if typeof(node) == TYPE_OBJECT and not is_instance_valid(node):
			_npc.erase(id)
			continue
		if resting:
			send_to_rest(id)
			continue
		# Morning: anyone still flagged resting leaves the inn for their route.
		if bool(st.get("resting", false)):
			advance_route(id)
		# Route advance timer.
		st["route_cd"] = float(st.get("route_cd", ROUTE_ADVANCE_S)) - dt
		if st["route_cd"] <= 0.0:
			st["route_cd"] = _rng.randf_range(ROUTE_ADVANCE_S * 0.7, ROUTE_ADVANCE_S * 1.3)
			advance_route(id)
		# Bark timer.
		st["bark_cd"] = float(st.get("bark_cd", 12.0)) - dt
		if st["bark_cd"] <= 0.0:
			st["bark_cd"] = _rng.randf_range(_bark_cd_range.x, _bark_cd_range.y)
			bark(id)
	# Chatter between nearby friends (at most one exchange per window).
	if not resting and _chatter_cd <= 0.0:
		if _try_chatter():
			_chatter_cd = _rng.randf_range(_chatter_cd_range.x, _chatter_cd_range.y)


func _try_chatter() -> bool:
	var ids: Array = _npc.keys()
	for i in range(ids.size()):
		var a: String = str(ids[i])
		var na: Variant = _dict(_npc[a]).get("node")
		if not is_instance_valid(na) or not (na is Node2D):
			continue
		for j in range(i + 1, ids.size()):
			var b: String = str(ids[j])
			if not are_friends(a, b):
				continue
			var nb: Variant = _dict(_npc[b]).get("node")
			if not is_instance_valid(nb) or not (nb is Node2D):
				continue
			if (na as Node2D).global_position.distance_to((nb as Node2D).global_position) <= _chatter_range:
				return run_chatter(a, b)
	return false


# --- world source helpers ----------------------------------------------------

func _now_hour() -> float:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null:
		var t: Variant = dn.get("time_of_day")
		if t is float or t is int:
			return float(t)
	return 12.0


func _region_for_zone(zone: String) -> String:
	# ZoneDefs is a global class_name (scripts/zone_defs.gd); zone() is a static
	# pure-data lookup that returns {} for unknown ids -- safe on any boot.
	if zone == "":
		return ""
	var z: Dictionary = ZoneDefs.zone(zone)
	return str(z.get("region", ""))


# --- generic helpers ---------------------------------------------------------

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("NPCLifeSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	return {"friendships": _friend_score.duplicate()}


func deserialize(d: Dictionary) -> void:
	var fs: Dictionary = _dict(d.get("friendships", {}))
	for k: Variant in fs.keys():
		_friend_score[str(k)] = int(fs[k])


# --- Self-test (RH_NPCLIFE_TEST=1) ------------------------------------------

func _run_selftest() -> void:
	var ok: bool = true
	var notes: Array = []

	# Fake NPCs as children of self so they have positions and are in-tree.
	var made: Array = []
	var specs := [
		{"id": "test_baker", "role": "baker", "pos": Vector2(100, 100)},
		{"id": "test_innkeeper", "role": "innkeeper", "pos": Vector2(140, 110)},
		{"id": "test_blacksmith", "role": "blacksmith", "pos": Vector2(160, 120)},
		{"id": "test_farmer", "role": "farmer", "pos": Vector2(600, 600)},
	]
	for s_v: Variant in specs:
		var s: Dictionary = s_v
		var n := Node2D.new()
		n.name = str(s["id"])
		add_child(n)
		n.global_position = s["pos"]
		# Give it a shipped-style _home so the route re-home path is exercised.
		n.set_meta("has_home", true)
		register_npc(n, str(s["role"]), "vetka")
		made.append(n)

	var n_reg: int = npc_count()
	ok = ok and n_reg == specs.size()
	notes.append("registered=%d" % n_reg)

	# 1) BARK: force a bark and assert a bubble Label was added AND the signal fired.
	var bark_sig := [false]
	var bcb := func(id: Variant, _t: Variant) -> void:
		if str(id) == "test_baker":
			bark_sig[0] = true
	bark_bubbled.connect(bcb)
	var barked: bool = bark("test_baker")
	var baker_node: Node = made[0]
	var has_bubble: bool = baker_node.get_node_or_null("LifeBubble") != null
	ok = ok and barked and bark_sig[0] and has_bubble
	notes.append("bark ok=%s signal=%s bubble=%s" % [str(barked), str(bark_sig[0]), str(has_bubble)])

	# 2) CHATTER: baker & innkeeper... seed a known friend pair first, then run.
	var chat_sig := [false]
	var ccb := func(a: Variant, b: Variant, _topic: Variant) -> void:
		chat_sig[0] = true
	chatter_started.connect(ccb)
	# baker+herbalist is the data friend pair; force friendship here for the two we made.
	adjust_friendship("test_baker", "test_innkeeper", 30)
	var chattered: bool = run_chatter("test_baker", "test_innkeeper")
	ok = ok and chattered and chat_sig[0] and are_friends("test_baker", "test_innkeeper")
	notes.append("chatter ok=%s friends=%s" % [str(chattered), str(are_friends("test_baker", "test_innkeeper"))])

	# 3) ROUTE: advance the farmer one waypoint -> index changes, signal fires.
	var route_sig := [""]
	var rcb := func(id: Variant, label: Variant) -> void:
		if str(id) == "test_farmer":
			route_sig[0] = str(label)
	npc_routed.connect(rcb)
	var idx0: int = int(_dict(_npc.get("test_farmer", {})).get("route_idx", 0))
	var idx1: int = advance_route("test_farmer")
	ok = ok and idx1 != idx0 and route_sig[0] != ""
	notes.append("route %d->%d '%s'" % [idx0, idx1, route_sig[0]])

	# 4) REST: send the blacksmith to the inn -> signal + resting flag.
	var rest_sig := [false]
	var rscb := func(id: Variant) -> void:
		if str(id) == "test_blacksmith":
			rest_sig[0] = true
	npc_rested.connect(rscb)
	var rested: bool = send_to_rest("test_blacksmith")
	ok = ok and rested and rest_sig[0] \
			and bool(_dict(_npc.get("test_blacksmith", {})).get("resting", false))
	notes.append("rest ok=%s" % str(rested))

	# 5) friendship get/adjust round-trip.
	var f0: int = friendship("test_farmer", "test_baker")
	var f1: int = adjust_friendship("test_farmer", "test_baker", 15)
	ok = ok and f1 == f0 + 15
	notes.append("friendship %d->%d" % [f0, f1])

	# Cleanup signal connections + fake nodes.
	if bark_bubbled.is_connected(bcb):
		bark_bubbled.disconnect(bcb)
	if chatter_started.is_connected(ccb):
		chatter_started.disconnect(ccb)
	if npc_routed.is_connected(rcb):
		npc_routed.disconnect(rcb)
	if npc_rested.is_connected(rscb):
		npc_rested.disconnect(rscb)

	print("NPCLIFE SELFTEST %s npcs=%d ; %s" % [
		"PASS" if ok else "FAIL", n_reg, " | ".join(notes)])

	for n: Node in made:
		if is_instance_valid(n):
			n.queue_free()
