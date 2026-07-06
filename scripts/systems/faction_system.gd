extends Node
## FactionSystem -- autoload (/root/FactionSystem). Build #71 "factions + reputation".
##
## The player's standing with the powers of Draconia (design canon:
## ../_lore_extract.txt -> The Four Factions + V. Cross-Faction Institutions).
## Six factions load from data/factions.json: the four cold-war races
## (Strigoi/Blestem, Varcolaci/Sangeroasa, Iele/Black Night, Angel Wings/Humans)
## plus the two institutions (the Accord, the Morven). Reputation runs on the
## WoW-Classic ladder -- Hated, Hostile, Unfriendly, Neutral, Friendly, Honored,
## Revered, Exalted -- stored as a signed int per actor per faction where 0 is
## the Neutral boundary the player starts on.
##
## Rep is earned from quests and kills through GUARDED hooks (grant_quest_rep,
## notify_kill + an enemy-death poll that mirrors MountSystem's trophy poll), and
## gates content: per-tier vendor discounts and access unlocks read straight from
## the faction defs. Every faction carries an EMBLEM -- for now a placeholder
## colored badge + glyph the reputation panel draws; the real 2D pixel emblem is
## Fable art at emblem.path, requested via emblem_requested on boot.
##
## This autoload also HOSTS the resting system (BACKLOG #70): it can't register a
## second autoload without touching project.godot, so it instances a RestManager
## child (scripts/systems/rest_system.gd) in _ready and forwards start_rest /
## is_resting / stop_rest to it. See rest_system.gd.
##
## Additive + null-safe: no other system's file is edited (StatsSystem/StatusSystem
## are only READ/called). The reputation panel (scenes/ui/reputation.tscn) is
## self-instanced here and toggled with the 'O' key.
##
## Public API (actor optional -> defaults to the player):
##   add_rep(actor, faction, amount) -> int      apply a rep delta, return new value
##   get_rep(actor, faction) -> int
##   get_tier(actor, faction) -> String          tier id (e.g. "honored")
##   get_tier_def(actor, faction) -> Dictionary  {id,name,color,index}
##   is_at_least(faction, tier, actor=null) -> bool
##   tier_progress(actor, faction) -> Dictionary bar data for the UI
##   vendor_discount(faction, actor=null) -> float   fractional price cut (0.0..)
##   unlocks_at(faction, tier) -> String ; current_unlocks(faction, actor) -> Array
##   emblem_def(faction) -> Dictionary ; emblem_color(faction) -> {bg,fg,glyph}
##   grant_quest_rep(actor, quest_id) -> Dictionary   quest_rep map hook (guarded)
##   notify_kill(actor, enemy_type) -> Dictionary     enemy_bounties hook (guarded)
##   all_factions() / faction_def(id) / faction_ids() / tiers()
##   open_reputation(actor) / close_reputation()
##   start_rest(actor, quality) / is_resting(actor) / stop_rest(actor)  (-> RestManager)
## Signals:
##   rep_changed(actor, faction_id, new_value, delta)
##   tier_changed(actor, faction_id, old_tier_id, new_tier_id)
##   emblem_requested(faction_id, path)      (Fable pixel-emblem art hook)

signal rep_changed(actor, faction_id, new_value, delta)
signal tier_changed(actor, faction_id, old_tier_id, new_tier_id)
signal emblem_requested(faction_id, path)

const DATA_PATH := "res://data/factions.json"
const PANEL_SCENE := "res://scenes/ui/reputation.tscn"
const REST_SCRIPT := "res://scripts/systems/rest_system.gd"
const KILL_POLL_S := 0.3

var _factions: Dictionary = {}       # faction_id -> def dict
var _order: Array = []               # faction_ids in file order
var _tiers: Array = []               # [{id,name,floor,color}] ascending by floor
var _exalted_span: int = 1000
var _bounties: Dictionary = {}       # enemy_type -> {faction_id: amount}
var _quest_rep: Dictionary = {}      # quest_id -> {faction_id: amount}

## instance_id -> {faction_id: int}
var _rep: Dictionary = {}

var _panel: Node = null
var _rest: Node = null               # RestManager child (rest_system.gd)
var _alive_enemies: Dictionary = {}  # instance_id -> enemy_type (kill poll)
var _poll_accum: float = 0.0


func _ready() -> void:
	_load_data()
	_spawn_rest_manager()
	set_process(true)
	# Announce the emblem art manifest for the Fable pixel-emblem pass.
	for fid: String in _order:
		var em: Dictionary = _dict(_dict(_factions[fid]).get("emblem", {}))
		var p: String = str(em.get("path", ""))
		if p != "":
			emblem_requested.emit(fid, p)
	# Env self-test / screenshot hooks fire once the world + player exist.
	if _wants_env_hooks():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_factions = _dict(root.get("factions", {}))
	_order = _dict(root.get("factions", {})).keys()
	_tiers = _arr(root.get("tiers", []))
	_tiers.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float(_dict(a).get("floor", 0.0)) < float(_dict(b).get("floor", 0.0)))
	_exalted_span = int(root.get("exalted_span", 1000))
	_bounties = _dict(root.get("enemy_bounties", {}))
	_quest_rep = _dict(root.get("quest_rep", {}))
	if _factions.is_empty():
		push_warning("FactionSystem: no factions loaded from %s" % DATA_PATH)
	if _tiers.is_empty():
		push_warning("FactionSystem: no reputation tiers loaded from %s" % DATA_PATH)


# --- Reputation core --------------------------------------------------------

## Apply a rep delta for `actor` with `faction`. Emits rep_changed always and
## tier_changed when the standing crosses a ladder boundary. Returns the new value.
func add_rep(actor: Node, faction: String, amount: int) -> int:
	if not _factions.has(faction):
		push_warning("FactionSystem.add_rep: unknown faction '%s'" % faction)
		return 0
	var a: Node = _resolve(actor)
	if a == null:
		return 0
	var old_v: int = get_rep(a, faction)
	var old_tier: String = _tier_id_for(old_v)
	var new_v: int = clampi(old_v + amount, _floor_value(), _cap_value())
	_store(a)[faction] = new_v
	var new_tier: String = _tier_id_for(new_v)
	rep_changed.emit(a, faction, new_v, new_v - old_v)
	if new_tier != old_tier:
		tier_changed.emit(a, faction, old_tier, new_tier)
	return new_v


func get_rep(actor: Node, faction: String) -> int:
	var a: Node = _resolve(actor)
	if a == null:
		return _start_rep(faction)
	var st: Dictionary = _store(a)
	return int(st.get(faction, _start_rep(faction)))


## Tier id for the actor's standing (e.g. "neutral", "honored", "exalted").
func get_tier(actor: Node, faction: String) -> String:
	return _tier_id_for(get_rep(actor, faction))


func get_tier_def(actor: Node, faction: String) -> Dictionary:
	var idx: int = _tier_index_for(get_rep(actor, faction))
	var t: Dictionary = _dict(_tiers[idx]) if idx >= 0 and idx < _tiers.size() else {}
	return {
		"id": str(t.get("id", "neutral")),
		"name": str(t.get("name", "Neutral")),
		"color": _color(t.get("color", [0.85, 0.8, 0.35])),
		"index": idx,
	}


## Does the actor stand at `tier` or higher with `faction`? Signature matches the
## build spec (faction, tier first); actor defaults to the player.
func is_at_least(faction: String, tier: String, actor: Node = null) -> bool:
	if not _factions.has(faction):
		return false
	var have: int = _tier_index_for(get_rep(actor, faction))
	var want: int = _tier_index_of(tier)
	return want >= 0 and have >= want


## Progress bar data for the reputation panel.
func tier_progress(actor: Node, faction: String) -> Dictionary:
	var rep: int = get_rep(actor, faction)
	var idx: int = _tier_index_for(rep)
	var t: Dictionary = _dict(_tiers[idx]) if idx >= 0 else {}
	var floor_v: int = int(t.get("floor", 0))
	var next_floor: int
	if idx + 1 < _tiers.size():
		next_floor = int(_dict(_tiers[idx + 1]).get("floor", floor_v + _exalted_span))
	else:
		next_floor = floor_v + _exalted_span   # top tier: fill over the exalted span
	var span: int = maxi(1, next_floor - floor_v)
	var into: int = rep - floor_v
	return {
		"rep": rep, "floor": floor_v, "next_floor": next_floor,
		"into": into, "span": span,
		"frac": clampf(float(into) / float(span), 0.0, 1.0),
		"tier_id": str(t.get("id", "neutral")),
		"tier_name": str(t.get("name", "Neutral")),
		"color": _color(t.get("color", [0.85, 0.8, 0.35])),
		"is_max": idx >= _tiers.size() - 1,
	}


# --- Rep gates (discounts + access) -----------------------------------------

## Fractional vendor price cut this actor earns from `faction` standing (0.0 = none,
## 0.15 = 15% off). Reads the faction's per-tier discounts; the best satisfied tier wins.
func vendor_discount(faction: String, actor: Node = null) -> float:
	var f: Dictionary = faction_def(faction)
	var disc: Dictionary = _dict(f.get("discounts", {}))
	var best: float = 0.0
	var have: int = _tier_index_for(get_rep(actor, faction))
	for key: Variant in disc:
		if have >= _tier_index_of(str(key)):
			best = maxf(best, float(disc[key]))
	return best


## The unlock text gated behind `tier` for a faction (or "" if none).
func unlocks_at(faction: String, tier: String) -> String:
	return str(_dict(faction_def(faction).get("unlocks", {})).get(tier, ""))


## All access unlocks the actor currently qualifies for with a faction.
func current_unlocks(faction: String, actor: Node = null) -> Array:
	var out: Array = []
	var unlocks: Dictionary = _dict(faction_def(faction).get("unlocks", {}))
	var have: int = _tier_index_for(get_rep(actor, faction))
	for key: Variant in unlocks:
		if have >= _tier_index_of(str(key)):
			out.append({"tier": str(key), "text": str(unlocks[key])})
	return out


# --- Emblems (placeholder badge now, Fable pixel art later) ------------------

func emblem_def(faction: String) -> Dictionary:
	return _dict(faction_def(faction).get("emblem", {}))


## The placeholder badge the reputation panel draws until the pixel emblem lands.
func emblem_color(faction: String) -> Dictionary:
	var em: Dictionary = emblem_def(faction)
	return {
		"bg": _color(em.get("bg", [0.12, 0.10, 0.09])),
		"fg": _color(em.get("fg", [0.85, 0.68, 0.35])),
		"glyph": str(em.get("glyph", "?")),
		"path": str(em.get("path", "")),
	}


# --- Rep-earning hooks (quests + kills) -------------------------------------

## Award the reputation a quest grants (guarded; reads data/factions.json
## quest_rep). Returns {ok, awards:{faction:new_value}}.
func grant_quest_rep(actor: Node, quest_id: String) -> Dictionary:
	var map: Dictionary = _dict(_quest_rep.get(quest_id, {}))
	if map.is_empty():
		return {"ok": false, "awards": {}}
	var awards: Dictionary = {}
	for fid: Variant in map:
		if _factions.has(str(fid)):
			awards[str(fid)] = add_rep(actor, str(fid), int(map[fid]))
	return {"ok": not awards.is_empty(), "awards": awards}


## Direct kill hook (also driven by the enemy-death poll below). Awards the
## bounty rep mapped to `enemy_type` in data/factions.json. Guarded: unknown
## types are a no-op. Returns {ok, awards:{faction:new_value}}.
func notify_kill(actor: Node, enemy_type: String) -> Dictionary:
	var map: Dictionary = _dict(_bounties.get(enemy_type, {}))
	if map.is_empty():
		return {"ok": false, "awards": {}}
	var a: Node = _resolve(actor)
	var awards: Dictionary = {}
	for fid: Variant in map:
		if _factions.has(str(fid)):
			awards[str(fid)] = add_rep(a, str(fid), int(map[fid]))
	return {"ok": not awards.is_empty(), "awards": awards}


func _process(delta: float) -> void:
	# Poll living enemies whose type carries a bounty; when one leaves the group
	# or flips is_dead, credit its rep. Mirrors MountSystem's trophy poll -- cheap
	# (~3 Hz over on-screen enemies) and needs no enemy.gd edit.
	_poll_accum += delta
	if _poll_accum < KILL_POLL_S:
		return
	_poll_accum = 0.0
	if _bounties.is_empty():
		return
	var current: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or bool(n.get("is_dead")):
			continue
		var tn: String = str(n.get("type_name"))
		if _bounties.has(tn):
			current[n.get_instance_id()] = tn
	for iid: int in _alive_enemies.keys():
		if not current.has(iid):
			notify_kill(_player(), str(_alive_enemies[iid]))
	_alive_enemies = current


# --- Reputation panel UI ----------------------------------------------------

func open_reputation(actor: Node = null) -> void:
	_ensure_panel()
	if _panel != null and _panel.has_method("present"):
		_panel.call("present", self, _resolve(actor))


func close_reputation() -> void:
	if _panel != null and _panel.has_method("close"):
		_panel.call("close")


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	if not ResourceLoader.exists(PANEL_SCENE):
		push_warning("FactionSystem: reputation scene missing (%s)" % PANEL_SCENE)
		return
	var scn: PackedScene = load(PANEL_SCENE) as PackedScene
	if scn == null:
		return
	_panel = scn.instantiate()
	add_child(_panel)


# --- Resting (RestManager child; forwards to rest_system.gd) -----------------

func _spawn_rest_manager() -> void:
	if not ResourceLoader.exists(REST_SCRIPT):
		return
	var scr: Script = load(REST_SCRIPT) as Script
	if scr == null:
		return
	_rest = scr.new()
	_rest.name = "RestManager"
	add_child(_rest)


func start_rest(actor: Node, quality: String = "inn") -> bool:
	if _rest != null and _rest.has_method("start_rest"):
		return bool(_rest.call("start_rest", _resolve(actor), quality))
	return false


func is_resting(actor: Node = null) -> bool:
	if _rest != null and _rest.has_method("is_resting"):
		return bool(_rest.call("is_resting", _resolve(actor)))
	return false


func stop_rest(actor: Node = null) -> bool:
	if _rest != null and _rest.has_method("stop_rest"):
		return bool(_rest.call("stop_rest", _resolve(actor)))
	return false


func rest_manager() -> Node:
	return _rest


# --- Input ('O' toggles the reputation panel) -------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_O:
		return
	if _player() == null or _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	if _panel != null and is_instance_valid(_panel) and bool(_panel.get("is_open")):
		close_reputation()
	else:
		open_reputation(_player())


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Public getters ---------------------------------------------------------

func all_factions() -> Dictionary:
	return _factions


func faction_def(faction: String) -> Dictionary:
	return _dict(_factions.get(faction, {}))


func faction_ids() -> Array:
	return _order.duplicate()


func tiers() -> Array:
	return _tiers.duplicate()


# --- Tier math --------------------------------------------------------------

func _tier_index_for(rep: int) -> int:
	var idx: int = 0
	for i in range(_tiers.size()):
		if rep >= int(_dict(_tiers[i]).get("floor", 0)):
			idx = i
		else:
			break
	return idx


func _tier_id_for(rep: int) -> String:
	var idx: int = _tier_index_for(rep)
	return str(_dict(_tiers[idx]).get("id", "neutral")) if idx >= 0 and idx < _tiers.size() else "neutral"


func _tier_index_of(tier_id: String) -> int:
	for i in range(_tiers.size()):
		if str(_dict(_tiers[i]).get("id", "")) == tier_id:
			return i
	return -1


func _floor_value() -> int:
	return int(_dict(_tiers[0]).get("floor", -42000)) if not _tiers.is_empty() else -42000


func _cap_value() -> int:
	if _tiers.is_empty():
		return 42000
	return int(_dict(_tiers[_tiers.size() - 1]).get("floor", 42000)) + _exalted_span


func _start_rep(faction: String) -> int:
	return int(faction_def(faction).get("start_rep", 0))


# --- helpers ----------------------------------------------------------------

func _store(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _rep.has(key):
		var seed: Dictionary = {}
		for fid: String in _order:
			seed[fid] = _start_rep(fid)
		_rep[key] = seed
	return _rep[key]


func _resolve(actor: Node) -> Node:
	return actor if actor != null else _player()


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var alpha: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(1, 1, 1, 1)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("FactionSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Env self-test / screenshot hooks ---------------------------------------

func _wants_env_hooks() -> bool:
	if not OS.get_environment("RH_FACTION").is_empty() \
			or not OS.get_environment("RH_REP").is_empty():
		return true
	# Honor the build-spec screenshot command (no dedicated flag): open the panel
	# when the capture path is clearly a faction/reputation shot.
	var shot: String = OS.get_environment("RH_SHOT").to_lower()
	return shot.find("faction") >= 0 or shot.find("_rep") >= 0 or shot.find("reput") >= 0


func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# Seed a representative spread so the ladder reads across tiers in the panel.
	add_rep(pl, "angelwings", 24500)   # Revered
	add_rep(pl, "accord", 10200)       # Honored
	add_rep(pl, "strigoi", 4200)       # Friendly
	add_rep(pl, "varcolaci", 900)      # Neutral
	add_rep(pl, "morven", -1500)       # Unfriendly
	add_rep(pl, "iele", -7000)         # Hostile
	if not OS.get_environment("RH_FACTION_TEST").is_empty() \
			or not OS.get_environment("RH_REP").is_empty():
		_self_test(pl)
	open_reputation(pl)


func _self_test(pl: Node) -> void:
	print("[FACTION_TEST] ===== Raven Hollow faction / reputation self-test =====")
	print("[FACTION_TEST] factions loaded = %d ; tiers = %d" % [_factions.size(), _tiers.size()])
	# Tier-crossing proof: push Angel Wings from Revered over the Exalted line.
	var f := "angelwings"
	var before_v: int = get_rep(pl, f)
	var before_t: String = get_tier(pl, f)
	var crossed: Array = []
	var conn := func(_a: Node, fid: String, ot: String, nt: String) -> void:
		if fid == f:
			crossed.append("%s -> %s" % [ot, nt])
	tier_changed.connect(conn)
	var after_v: int = add_rep(pl, f, 20000)
	tier_changed.disconnect(conn)
	print("[FACTION_TEST] %s rep %d (%s) +20000 -> %d (%s) ; tier_changed: %s" % [
		f, before_v, before_t, after_v, get_tier(pl, f),
		str(crossed) if not crossed.is_empty() else "none"])
	print("[FACTION_TEST] is_at_least(%s, exalted) = %s" % [f, str(is_at_least(f, "exalted", pl))])
	print("[FACTION_TEST] %s vendor discount = %.0f%% ; unlocks = %s" % [
		f, vendor_discount(f, pl) * 100.0, str(current_unlocks(f, pl))])
	# Kill-bounty proof.
	var kr: Dictionary = notify_kill(pl, "orc_warrior")
	print("[FACTION_TEST] kill orc_warrior -> %s" % str(kr))
	# Quest-rep proof.
	var qr: Dictionary = grant_quest_rep(pl, "the_well_went_copper")
	print("[FACTION_TEST] quest 'the_well_went_copper' -> %s" % str(qr))
	print("[FACTION_TEST] ===== self-test complete =====")
