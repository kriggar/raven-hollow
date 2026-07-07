extends Node
## QuestSystem -- autoload (/root/QuestSystem). BLUEPRINT_27 "Quest Engine".
## A data-driven quest engine for Raven Hollow, implemented ADDITIVELY on top of
## the shipped combat / loot / inventory / travel systems WITHOUT editing any of
## them. It runs ALONGSIDE the frozen Phase-C `Quests` node (group "quests",
## which drives the five tutorial demo quests): this system owns the wider,
## data-authored quest catalog loaded from data/quests.json and never touches
## the tutorial chain.
##
## WHAT IT DOES
##   * Loads quest defs (id, title, giver, zone, level, prereq, objectives,
##     rewards, chain/follow_up) from data/quests.json.
##   * Tracks objective progress by hooking events that already fire in the
##     game, all guarded + additive so nothing breaks when no quest is active:
##       - KILL   : polls the "enemies" group and counts is_dead transitions
##                  (no enemy.gd edit; culled/leashed mobs are never miscounted).
##       - COLLECT: listens to LootSystem.loot_generated (kills/loot rolls emit
##                  the rolled item list) and counts matching item ids.
##       - REACH  : polls the player position vs an objective's map+pos+radius.
##       - TALK   : reported when the player greets a nearby NPC (offer key).
##       - USE    : reported through the public progress() API.
##   * Quest states: available -> active -> complete -> turned_in.
##   * Rewards on turn-in: XP (XPSystem.grant_xp), gold (player.gold), items
##     (LootSystem.roll_item -> the player's bag), reputation (guarded, applied
##     only if a reputation system exposes an add()/gain() method).
##   * Quest-giver NPCs get a floating "!" (offer) / "?" (turn-in) marker, and a
##     simple accept/turn-in panel opens when the player greets them (key G).
##   * A Quest Log (L or J) + a top-right tracker HUD live in one instanced
##     CanvasLayer (scenes/ui/quest_log.tscn), created from _ready() the same
##     way MountSystem/SmartNPCSystem instance their UIs.
##
## PUBLIC API (actor = the player node, group "player")
##   offer(actor, quest_id) -> bool         mark an eligible quest available
##   accept(actor, quest_id) -> bool        available/eligible -> active
##   progress(actor, event, data) -> bool   advance matching objectives
##   complete(actor, quest_id) -> bool      force objectives-done -> complete
##   turn_in(actor, quest_id) -> bool       complete -> turned_in + grant rewards
##   active_quests(actor) -> Array          active + complete quest ids
##   is_complete(actor, quest_id) -> bool   true once turned in
##   is_ready(actor, quest_id) -> bool      objectives done, awaiting turn-in
##   available_quests(actor) -> Array       eligible ids whose giver is present
##   quest_def(id) / quest_state(actor,id) / objective_lines(actor,id)
##   tracker_lines(actor) / rewards_text(id) / track/untrack/toggle_track/is_tracked
##   open_log(actor) / marker_for(npc_id)
## SIGNALS
##   quest_offered(actor, quest_id)
##   quest_accepted(actor, quest_id)
##   quest_updated(actor, quest_id)         objective progress or state change
##   quest_completed(actor, quest_id)       turned in (rewards granted)

signal quest_offered(actor, quest_id)
signal quest_accepted(actor, quest_id)
signal quest_updated(actor, quest_id)
signal quest_completed(actor, quest_id)

const DATA_PATH := "res://data/quests.json"
const LOG_SCENE := "res://scenes/ui/quest_log.tscn"

const MAX_TRACKED := 5
const POLL_S := 0.35            # kill / marker cadence
const REACH_POLL_S := 0.5       # player-position (reach) cadence
const OFFER_RANGE := 60.0       # greet distance to a quest giver

# Quest states.
const ST_AVAILABLE := "available"
const ST_ACTIVE := "active"
const ST_COMPLETE := "complete"     # all objectives done, awaiting turn-in
const ST_TURNED_IN := "turned_in"

const GOLD := Color(0.85, 0.68, 0.35)

var _defs: Dictionary = {}          # quest_id -> def dict
var _order: Array = []              # quest ids in file order (stable listing)

## Per-actor progress, keyed by instance id:
##   {quest_id: {status, counts: {obj_idx: int}, tracked: bool, rewarded: bool}}
var _states: Dictionary = {}
var _track_order: Array = []        # tracked quest ids (newest last), player only

var _ui: Node = null

var _alive_enemies: Dictionary = {} # iid -> {type, name} (kill poll bookkeeping)
var _poll_accum: float = 0.0
var _reach_accum: float = 0.0
var _loot_hooked: bool = false


func _ready() -> void:
	_load_data()
	call_deferred("_ensure_ui")
	call_deferred("_connect_loot")
	set_process(true)
	# Env self-test / screenshot hooks fire once the world + player exist.
	if not OS.get_environment("RH_QUEST_TEST").is_empty() \
			or not OS.get_environment("RH_QUESTLOG").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	var quests: Dictionary = _dict(root.get("quests", {}))
	_defs.clear()
	_order.clear()
	for qid: String in quests.keys():
		var d: Dictionary = _dict(quests[qid])
		if d.is_empty():
			continue
		d["id"] = qid
		_defs[qid] = d
		_order.append(qid)
	if _defs.is_empty():
		push_warning("QuestSystem: no quests loaded from %s" % DATA_PATH)


func _connect_loot() -> void:
	if _loot_hooked:
		return
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_signal("loot_generated"):
		if not ls.is_connected("loot_generated", _on_loot_generated):
			ls.connect("loot_generated", _on_loot_generated)
		_loot_hooked = true


# --- Definitions -------------------------------------------------------------

func quest_def(quest_id: String) -> Dictionary:
	return _dict(_defs.get(quest_id, {}))


func all_ids() -> Array:
	return _order.duplicate()


func quest_count() -> int:
	return _defs.size()


func objectives_of(quest_id: String) -> Array:
	return _arr(quest_def(quest_id).get("objectives", []))


func turn_in_npc(quest_id: String) -> String:
	var d: Dictionary = quest_def(quest_id)
	var t: String = str(d.get("turn_in_npc", ""))
	return t if t != "" else str(d.get("giver", ""))


# --- State access ------------------------------------------------------------

func _actor_states(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _states.has(key):
		_states[key] = {}
	return _states[key]


func quest_state(actor: Node, quest_id: String) -> Dictionary:
	return _dict(_actor_states(actor).get(quest_id, {}))


func status_of(actor: Node, quest_id: String) -> String:
	return str(quest_state(actor, quest_id).get("status", ""))


func is_active(actor: Node, quest_id: String) -> bool:
	var s: String = status_of(actor, quest_id)
	return s == ST_ACTIVE or s == ST_COMPLETE


func is_ready(actor: Node, quest_id: String) -> bool:
	return status_of(actor, quest_id) == ST_COMPLETE


func is_complete(actor: Node, quest_id: String) -> bool:
	return status_of(actor, quest_id) == ST_TURNED_IN


func active_quests(actor: Node) -> Array:
	var out: Array = []
	var st: Dictionary = _actor_states(actor)
	for qid: String in _order:
		var s: String = str(_dict(st.get(qid, {})).get("status", ""))
		if s == ST_ACTIVE or s == ST_COMPLETE:
			out.append(qid)
	return out


# --- Eligibility / offering --------------------------------------------------

## An actor may be offered `quest_id` when: it exists, isn't already
## active/complete/turned-in, every prereq is turned in, and the level gate
## (if any) is met.
func is_eligible(actor: Node, quest_id: String) -> bool:
	if not _defs.has(quest_id):
		return false
	var s: String = status_of(actor, quest_id)
	if s == ST_ACTIVE or s == ST_COMPLETE or s == ST_TURNED_IN:
		return false
	var d: Dictionary = quest_def(quest_id)
	for pre_v: Variant in _arr(d.get("prereq", [])):
		if not is_complete(actor, str(pre_v)):
			return false
	var min_level: int = int(d.get("min_level", 0))
	if min_level > 0 and _player_level(actor) < min_level:
		return false
	return true


## Mark an eligible quest as available (offered). Idempotent; emits once.
func offer(actor: Node, quest_id: String) -> bool:
	if actor == null or not is_eligible(actor, quest_id):
		return false
	var st: Dictionary = _actor_states(actor)
	if str(_dict(st.get(quest_id, {})).get("status", "")) == ST_AVAILABLE:
		return true
	st[quest_id] = {"status": ST_AVAILABLE, "counts": {}, "tracked": false, "rewarded": false}
	quest_offered.emit(actor, quest_id)
	return true


## Quests whose giver NPC is present in the world and that the actor may take.
func available_quests(actor: Node) -> Array:
	var out: Array = []
	for qid: String in _order:
		if not is_eligible(actor, qid):
			continue
		var giver: String = str(quest_def(qid).get("giver", ""))
		if giver == "" or _npc_present(giver):
			out.append(qid)
	return out


# --- Accept ------------------------------------------------------------------

func accept(actor: Node, quest_id: String) -> bool:
	if actor == null or not _defs.has(quest_id):
		return false
	# Accepting is allowed from available OR directly from eligible.
	if not is_eligible(actor, quest_id):
		return false
	var st: Dictionary = _actor_states(actor)
	st[quest_id] = {"status": ST_ACTIVE, "counts": {}, "tracked": true, "rewarded": false}
	_add_tracked(quest_id)
	quest_accepted.emit(actor, quest_id)
	# Some objectives can already be satisfied (e.g. an item the player carries):
	# re-evaluate immediately so freshly accepted quests reflect reality.
	_recount_collect(actor, quest_id)
	_reevaluate(actor, quest_id)
	quest_updated.emit(actor, quest_id)
	_refresh_ui()
	return true


# --- Progress ----------------------------------------------------------------

## Advance every active quest whose current objectives match (event, data).
## event: "kill" | "collect" | "talk" | "reach" | "use".
## data:  kill    {type, name}
##        collect {item, amount}
##        talk    {npc}
##        reach   {map, pos}
##        use     {id, amount}
## Returns true if any objective advanced.
func progress(actor: Node, event: String, data: Dictionary) -> bool:
	if actor == null:
		return false
	var any: bool = false
	for qid: String in active_quests(actor):
		if _progress_quest(actor, qid, event, data):
			any = true
	if any:
		_refresh_ui()
	return any


func _progress_quest(actor: Node, quest_id: String, event: String, data: Dictionary) -> bool:
	var state: Dictionary = _actor_states(actor).get(quest_id, {})
	if state.is_empty() or str(state.get("status", "")) != ST_ACTIVE:
		return false
	var objs: Array = objectives_of(quest_id)
	var counts: Dictionary = _dict(state.get("counts", {}))
	var changed: bool = false
	for i in range(objs.size()):
		var obj: Dictionary = _dict(objs[i])
		var req: int = maxi(1, int(obj.get("count", 1)))
		var cur: int = int(counts.get(str(i), 0))
		if cur >= req:
			continue
		if not _obj_matches(obj, event, data):
			continue
		var amount: int = maxi(1, int(data.get("amount", 1)))
		cur = mini(req, cur + amount)
		counts[str(i)] = cur
		changed = true
	if changed:
		state["counts"] = counts
		var became_complete: bool = _reevaluate(actor, quest_id)
		quest_updated.emit(actor, quest_id)
		if became_complete:
			_on_objectives_done(actor, quest_id)
	return changed


func _obj_matches(obj: Dictionary, event: String, data: Dictionary) -> bool:
	var kind: String = str(obj.get("kind", ""))
	if kind != event:
		return false
	match kind:
		"kill":
			return _target_matches(str(obj.get("target", "")),
					str(data.get("type", "")), str(data.get("name", "")))
		"collect":
			return str(obj.get("item", "")) == str(data.get("item", ""))
		"talk":
			return str(obj.get("npc", "")) == str(data.get("npc", ""))
		"reach":
			if str(obj.get("map", "")) != str(data.get("map", "")):
				return false
			var op: Vector2 = _obj_pos(obj)
			var pp: Variant = data.get("pos")
			if not (pp is Vector2):
				return false
			return (pp as Vector2).distance_to(op) <= float(obj.get("radius", 64.0))
		"use":
			return str(obj.get("id", "")) == str(data.get("id", ""))
	return false


## Kill target matching: an objective target ("wolf", "skeleton") matches an
## enemy by type_name family prefix OR by (lowercased) display name.
func _target_matches(target: String, type_name: String, display_name: String) -> bool:
	if target == "":
		return false
	var t: String = target.to_lower()
	var tn: String = type_name.to_lower()
	if tn == t or tn.begins_with(t):
		return false if tn == "" else true
	var dn: String = display_name.to_lower()
	return dn == t or dn.find(t) != -1


# --- Completion / turn-in ----------------------------------------------------

## Recompute whether all objectives are done; flip active->complete. Returns
## true only on the transition INTO complete this call.
func _reevaluate(actor: Node, quest_id: String) -> bool:
	var state: Dictionary = _actor_states(actor).get(quest_id, {})
	if state.is_empty() or str(state.get("status", "")) != ST_ACTIVE:
		return false
	if _all_objectives_done(actor, quest_id):
		state["status"] = ST_COMPLETE
		return true
	return false


func _all_objectives_done(actor: Node, quest_id: String) -> bool:
	var objs: Array = objectives_of(quest_id)
	if objs.is_empty():
		return true
	var counts: Dictionary = _dict(_actor_states(actor).get(quest_id, {}).get("counts", {}))
	for i in range(objs.size()):
		var req: int = maxi(1, int(_dict(objs[i]).get("count", 1)))
		if int(counts.get(str(i), 0)) < req:
			return false
	return true


func _on_objectives_done(actor: Node, quest_id: String) -> void:
	# A quest with no turn-in NPC auto-completes the moment objectives are done.
	if str(quest_def(quest_id).get("turn_in_npc", "__unset__")) == "" \
			and str(quest_def(quest_id).get("giver", "")) == "":
		turn_in(actor, quest_id)


## Force a quest's objectives to done (drives auto/scripted completions).
func complete(actor: Node, quest_id: String) -> bool:
	if not is_active(actor, quest_id):
		return false
	var state: Dictionary = _actor_states(actor).get(quest_id, {})
	var counts: Dictionary = _dict(state.get("counts", {}))
	var objs: Array = objectives_of(quest_id)
	for i in range(objs.size()):
		counts[str(i)] = maxi(1, int(_dict(objs[i]).get("count", 1)))
	state["counts"] = counts
	state["status"] = ST_COMPLETE
	quest_updated.emit(actor, quest_id)
	_refresh_ui()
	return true


## Turn a completed quest in: grant rewards, mark turned_in, unlock follow-ups.
func turn_in(actor: Node, quest_id: String) -> bool:
	if actor == null:
		return false
	var state: Dictionary = _actor_states(actor).get(quest_id, {})
	if state.is_empty():
		return false
	var s: String = str(state.get("status", ""))
	if s != ST_COMPLETE:
		# Tolerate turn-in of a quest whose objectives are done but not flagged.
		if s == ST_ACTIVE and _all_objectives_done(actor, quest_id):
			state["status"] = ST_COMPLETE
		else:
			return false
	if not bool(state.get("rewarded", false)):
		_grant_rewards(actor, quest_id)
		state["rewarded"] = true
	state["status"] = ST_TURNED_IN
	_remove_tracked(quest_id)
	_unlock_followups(actor, quest_id)
	quest_completed.emit(actor, quest_id)
	_refresh_ui()
	return true


func _unlock_followups(actor: Node, quest_id: String) -> void:
	var d: Dictionary = quest_def(quest_id)
	var nexts: Array = _arr(d.get("follow_up", []))
	var nx: String = str(d.get("next", ""))
	if nx != "":
		nexts.append(nx)
	for n_v: Variant in nexts:
		var nid: String = str(n_v)
		if not _defs.has(nid) or not is_eligible(actor, nid):
			continue
		# A giver-less follow-up force-starts as a breadcrumb; otherwise it
		# simply becomes available (its giver shows a "!").
		if str(quest_def(nid).get("giver", "")) == "":
			accept(actor, nid)
		else:
			offer(actor, nid)


# --- Rewards -----------------------------------------------------------------

func _grant_rewards(actor: Node, quest_id: String) -> void:
	var r: Dictionary = _dict(quest_def(quest_id).get("rewards", {}))
	# XP
	var xp: int = int(r.get("xp", 0))
	if xp > 0 and _has_prop(actor, "level"):
		XPSystem.grant_xp(actor, xp)
	# Gold
	var gold: int = int(r.get("gold", 0))
	if gold > 0 and _has_prop(actor, "gold"):
		actor.set("gold", _gold(actor) + gold)
	# Items (resolve full item dict via LootSystem, file into the bag).
	for item_v: Variant in _arr(r.get("items", [])):
		var item_id: String = str(item_v)
		if item_id == "":
			continue
		_grant_item(actor, item_id)
	# Reputation. The canonical hook is FactionSystem.grant_quest_rep (it reads
	# its own quest_rep map by quest id); additionally apply any rewards.rep
	# entries that name a faction FactionSystem actually knows. Unknown tracks
	# (e.g. "border_hearths", a QUEST_ARCHITECTURE reputation track not in the
	# shipped 6-faction set) stay in the data for a future Reputation autoload
	# and are skipped cleanly here -- no error, no warning.
	var fs: Node = get_node_or_null("/root/FactionSystem")
	if fs != null:
		if fs.has_method("grant_quest_rep"):
			fs.call("grant_quest_rep", actor, quest_id)
		var rep: Dictionary = _dict(r.get("rep", {}))
		if not rep.is_empty() and fs.has_method("add_rep") and fs.has_method("faction_def"):
			for faction: String in rep.keys():
				if not _dict(fs.call("faction_def", faction)).is_empty():
					fs.call("add_rep", actor, faction, int(rep[faction]))


func _grant_item(actor: Node, item_id: String) -> void:
	var item: Dictionary = {}
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_method("roll_item"):
		var it: Variant = ls.call("roll_item", item_id, "")
		if it is Dictionary:
			item = it
	if item.is_empty():
		item = {"id": item_id, "name": item_id.capitalize(), "slot": "none",
				"rarity": "common", "icon": "pixel:tarnished_band", "stats": {},
				"flavor": "", "stackable": false, "effect": ""}
	# Prefer the player's live Inventory (what the bag UI shows); fall back to
	# the InventorySystem autoload.
	var inv: Variant = actor.get("inventory")
	if inv is Object and (inv as Object).has_method("add_item"):
		(inv as Object).call("add_item", item)
		return
	var isys: Node = get_node_or_null("/root/InventorySystem")
	if isys != null and isys.has_method("add_item"):
		isys.call("add_item", actor, item)


# --- Tracking ----------------------------------------------------------------

func is_tracked(quest_id: String) -> bool:
	return _track_order.has(quest_id)


func track(quest_id: String) -> void:
	_add_tracked(quest_id)
	_refresh_ui()


func untrack(quest_id: String) -> void:
	_remove_tracked(quest_id)
	_refresh_ui()


func toggle_track(quest_id: String) -> void:
	if is_tracked(quest_id):
		_remove_tracked(quest_id)
	else:
		_add_tracked(quest_id)
	_refresh_ui()


func _add_tracked(quest_id: String) -> void:
	if _track_order.has(quest_id):
		return
	_track_order.append(quest_id)
	while _track_order.size() > MAX_TRACKED:
		_track_order.pop_front()


func _remove_tracked(quest_id: String) -> void:
	_track_order.erase(quest_id)


## Tracker HUD data: up to MAX_TRACKED tracked active/complete quests, each
## {title, color, ready, steps: [{text, done}]}.
func tracker_lines(actor: Node) -> Array:
	var out: Array = []
	for qid: String in _track_order:
		if not is_active(actor, qid):
			continue
		out.append({
			"id": qid,
			"title": str(quest_def(qid).get("title", qid)),
			"color": _quest_color(actor, qid),
			"ready": is_ready(actor, qid),
			"steps": objective_lines(actor, qid),
		})
	return out


## Per-objective render lines for a quest: {text, cur, req, done, kind}.
func objective_lines(actor: Node, quest_id: String) -> Array:
	var out: Array = []
	var objs: Array = objectives_of(quest_id)
	var counts: Dictionary = _dict(quest_state(actor, quest_id).get("counts", {}))
	for i in range(objs.size()):
		var obj: Dictionary = _dict(objs[i])
		var req: int = maxi(1, int(obj.get("count", 1)))
		var cur: int = int(counts.get(str(i), 0))
		var base: String = str(obj.get("text", _default_obj_text(obj)))
		var text: String = base
		if req > 1:
			text = "%s  (%d/%d)" % [base, cur, req]
		out.append({"text": text, "cur": cur, "req": req,
				"done": cur >= req, "kind": str(obj.get("kind", ""))})
	return out


func _default_obj_text(obj: Dictionary) -> String:
	match str(obj.get("kind", "")):
		"kill": return "Slay %s" % str(obj.get("target", "foes"))
		"collect": return "Gather %s" % str(obj.get("item", "items"))
		"talk": return "Speak with %s" % str(obj.get("npc", "someone"))
		"reach": return "Travel to %s" % str(obj.get("label", "the marked place"))
		"use": return "Use %s" % str(obj.get("id", "it"))
	return "..."


func rewards_text(quest_id: String) -> String:
	var r: Dictionary = _dict(quest_def(quest_id).get("rewards", {}))
	var parts: Array = []
	if int(r.get("xp", 0)) > 0:
		parts.append("%d XP" % int(r["xp"]))
	if int(r.get("gold", 0)) > 0:
		parts.append("%d gold" % int(r["gold"]))
	for item_v: Variant in _arr(r.get("items", [])):
		parts.append(_item_display_name(str(item_v)))
	return "  -  ".join(parts) if not parts.is_empty() else "(no reward)"


func _item_display_name(item_id: String) -> String:
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_method("roll_item"):
		var it: Variant = ls.call("roll_item", item_id, "")
		if it is Dictionary and (it as Dictionary).has("name"):
			return str((it as Dictionary)["name"])
	return item_id.capitalize().replace("_", " ")


# --- Journal color (green under-level / yellow on-level / red over) -----------

func _quest_color(actor: Node, quest_id: String) -> Color:
	if is_ready(actor, quest_id):
		return Color(0.55, 0.85, 0.45)      # ready to turn in -> green
	var lvl: int = int(quest_def(quest_id).get("level", 1))
	var pl: int = _player_level(actor)
	var d: int = lvl - pl
	if d <= -3:
		return Color(0.62, 0.62, 0.62)      # trivial -> grey
	if d < 0:
		return Color(0.60, 0.78, 0.45)      # green
	if d <= 2:
		return Color(0.92, 0.86, 0.45)      # yellow (on level)
	return Color(0.90, 0.45, 0.38)          # red (over level)


# --- Event tracking: kills (enemies poll) ------------------------------------

func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum >= POLL_S:
		_poll_accum = 0.0
		_poll_kills()
		_refresh_markers()
	_reach_accum += delta
	if _reach_accum >= REACH_POLL_S:
		_reach_accum = 0.0
		_poll_reach()


## Detect kills without touching enemy.gd: an enemy we were tracking as alive
## that now reads is_dead just died. Enemies that vanish (culled / freed) while
## still alive are dropped WITHOUT counting, so nothing is miscounted.
func _poll_kills() -> void:
	var player: Node = _player()
	if player == null:
		return
	var living: Dictionary = {}
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var iid: int = e.get_instance_id()
		if bool(e.get("is_dead")):
			if _alive_enemies.has(iid):
				var info: Dictionary = _alive_enemies[iid]
				_alive_enemies.erase(iid)
				progress(player, "kill", {"type": str(info.get("type", "")),
						"name": str(info.get("name", ""))})
		else:
			living[iid] = true
			_alive_enemies[iid] = {"type": str(e.get("type_name")),
					"name": str(e.get("display_name"))}
	# Forget any tracked enemy that is gone but never seen dead (culled/leashed).
	for iid: int in _alive_enemies.keys():
		if not living.has(iid):
			_alive_enemies.erase(iid)


## Reach objectives: dwell check against the live player position + map.
func _poll_reach() -> void:
	var player: Node2D = _player() as Node2D
	if player == null:
		return
	var map_id: String = _current_map()
	var ppos: Vector2 = player.global_position
	for qid: String in active_quests(player):
		var objs: Array = objectives_of(qid)
		var state: Dictionary = _actor_states(player).get(qid, {})
		if str(state.get("status", "")) != ST_ACTIVE:
			continue
		var has_reach: bool = false
		for o_v: Variant in objs:
			if str(_dict(o_v).get("kind", "")) == "reach":
				has_reach = true
				break
		if has_reach:
			progress(player, "reach", {"map": map_id, "pos": ppos})


## Collect objectives: every loot roll (kills, chests) emits the item list.
func _on_loot_generated(items: Variant) -> void:
	if not (items is Array):
		return
	var player: Node = _player()
	if player == null:
		return
	for it_v: Variant in (items as Array):
		if not (it_v is Dictionary):
			continue
		var it: Dictionary = it_v
		var item_id: String = str(it.get("id", ""))
		if item_id == "":
			continue
		var qty: int = maxi(1, int(it.get("quantity", 1)))
		progress(player, "collect", {"item": item_id, "amount": qty})


## When a quest is accepted, count matching items already in the bag so a
## collect quest doesn't ignore what the player is already carrying.
func _recount_collect(actor: Node, quest_id: String) -> void:
	var objs: Array = objectives_of(quest_id)
	var state: Dictionary = _actor_states(actor).get(quest_id, {})
	var counts: Dictionary = _dict(state.get("counts", {}))
	var changed: bool = false
	for i in range(objs.size()):
		var obj: Dictionary = _dict(objs[i])
		if str(obj.get("kind", "")) != "collect":
			continue
		var have: int = _count_item(actor, str(obj.get("item", "")))
		if have > 0:
			counts[str(i)] = mini(maxi(1, int(obj.get("count", 1))), have)
			changed = true
	if changed:
		state["counts"] = counts


func _count_item(actor: Node, item_id: String) -> int:
	if item_id == "":
		return 0
	var n: int = 0
	# Player's live Inventory bag.
	var inv: Variant = actor.get("inventory")
	if inv is Object:
		var bag_v: Variant = (inv as Object).get("bag")
		if bag_v is Array:
			for entry: Variant in (bag_v as Array):
				if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
					n += maxi(1, int((entry as Dictionary).get("quantity", 1)))
	# InventorySystem bag (autoload).
	var isys: Node = get_node_or_null("/root/InventorySystem")
	if isys != null and isys.has_method("list_items"):
		for entry_v: Variant in _arr(isys.call("list_items", actor)):
			if entry_v is Dictionary and str((entry_v as Dictionary).get("id", "")) == item_id:
				n += maxi(1, int((entry_v as Dictionary).get("quantity", 1)))
	return n


# --- Quest-giver markers + greet (offer / turn-in) ---------------------------

## Marker glyph for an npc id: "!" available offer, "?" ready turn-in, else "".
func marker_for(npc_id: String) -> String:
	var player: Node = _player()
	if player == null:
		return ""
	# Turn-in takes priority over a fresh offer.
	for qid: String in active_quests(player):
		if is_ready(player, qid) and turn_in_npc(qid) == npc_id:
			return "?"
	for qid: String in available_quests(player):
		if str(quest_def(qid).get("giver", "")) == npc_id:
			return "!"
	return ""


func _refresh_markers() -> void:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if not (n is Node2D):
			continue
		var glyph: String = marker_for(str(n.name))
		var lbl: Label = (n as Node2D).get_node_or_null("QuestMarkerV2") as Label
		if glyph == "":
			if lbl != null:
				lbl.visible = false
			continue
		if lbl == null:
			lbl = _make_marker_label()
			(n as Node2D).add_child(lbl)
		lbl.text = glyph
		lbl.visible = true


func _make_marker_label() -> Label:
	var lbl := Label.new()
	lbl.name = "QuestMarkerV2"
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/alagard.ttf")
	ls.font_size = 16
	ls.font_color = GOLD
	ls.outline_size = 4
	ls.outline_color = Color(0.1, 0.06, 0.04, 0.95)
	lbl.label_settings = ls
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(96.0, 16.0)
	lbl.position = Vector2(-48.0, -74.0)   # above npc.gd's own name/marker labels
	lbl.z_index = 4
	return lbl


## Greet the nearest NPC (key G): advances talk objectives and opens the
## accept / turn-in panel if that NPC has quest business with the player.
func _greet_nearest(player: Node2D) -> void:
	var npc: Node2D = _nearest_npc(player.global_position, OFFER_RANGE)
	if npc == null:
		return
	var npc_id: String = str(npc.name)
	progress(player, "talk", {"npc": npc_id})
	# Ready turn-ins first, then fresh offers.
	var ready_ids: Array = []
	for qid: String in active_quests(player):
		if is_ready(player, qid) and turn_in_npc(qid) == npc_id:
			ready_ids.append(qid)
	var offer_ids: Array = []
	for qid: String in available_quests(player):
		if str(quest_def(qid).get("giver", "")) == npc_id:
			offer_ids.append(qid)
	if ready_ids.is_empty() and offer_ids.is_empty():
		return
	_ensure_ui()
	if _ui != null and _ui.has_method("present_offer"):
		_ui.call("present_offer", self, player, npc_id,
				str(npc.get("display_name")) if _has_prop(npc, "display_name") else npc_id)


func _nearest_npc(pos: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = radius
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if not (n is Node2D):
			continue
		var d: float = (n as Node2D).global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = n as Node2D
	return best


# --- UI ----------------------------------------------------------------------

func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	if not ResourceLoader.exists(LOG_SCENE):
		push_warning("QuestSystem: quest log scene missing (%s)" % LOG_SCENE)
		return
	var scn: PackedScene = load(LOG_SCENE) as PackedScene
	if scn == null:
		return
	_ui = scn.instantiate()
	add_child(_ui)
	_refresh_ui()


func open_log(actor: Node = null) -> void:
	if actor == null:
		actor = _player()
	_ensure_ui()
	if _ui != null and _ui.has_method("present_log"):
		_ui.call("present_log", self, actor)


func _refresh_ui() -> void:
	if _ui != null and is_instance_valid(_ui) and _ui.has_method("refresh"):
		_ui.call("refresh", self, _player())


func _log_is_open() -> bool:
	return _ui != null and is_instance_valid(_ui) and bool(_ui.get("is_open"))


# --- Input (L / J = quest log, G = greet/offer) ------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_L or key.keycode == KEY_J:
		if _panel_blocking() and not _log_is_open():
			return
		get_viewport().set_input_as_handled()
		if _log_is_open():
			if _ui.has_method("close_all"):
				_ui.call("close_all")
		else:
			open_log(_player())
		return
	if key.keycode == KEY_G:
		if _panel_blocking():
			return
		var pl: Node2D = _player() as Node2D
		if pl == null:
			return
		get_viewport().set_input_as_handled()
		_greet_nearest(pl)


func _panel_blocking() -> bool:
	# Never steal keys while a dialogue / bag / other panel captures input.
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui",
			"shop_ui", "mounts_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(360):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# A couple more frames so the world/enemies finish spawning.
	for _j in range(10):
		await get_tree().process_frame
	if not OS.get_environment("RH_QUEST_TEST").is_empty():
		_self_test(pl)
	if not OS.get_environment("RH_QUESTLOG").is_empty():
		_seed_demo(pl)
		open_log(pl)
	# RH_QUESTOFFER=<npc_id>: teleport the player onto that giver and fire the
	# greet, so a screenshot proves the offer panel pops for a real zone quest.
	var off_env: String = OS.get_environment("RH_QUESTOFFER")
	if not off_env.is_empty():
		var giver: Node2D = null
		for n: Node in get_tree().get_nodes_in_group("npcs"):
			if n is Node2D and str(n.name) == off_env:
				giver = n as Node2D
				break
		if giver != null and pl is Node2D:
			(pl as Node2D).global_position = giver.global_position + Vector2(0.0, 24.0)
			for _f in range(4):
				await get_tree().process_frame
			_greet_nearest(pl as Node2D)


## Seed a representative slice so the log + tracker read full in a screenshot:
## accept several quests and drive partial progress on each objective kind.
## Chosen to NOT collide with the self-test's turned-in quest (rh_wolves_gate).
func _seed_demo(pl: Node) -> void:
	for qid: String in ["rh_graveyard_bones", "rh_fair_meat", "rh_petra_walk", "rh_old_road"]:
		if _defs.has(qid):
			offer(pl, qid)
			accept(pl, qid)
	# Partial kill progress (2 of 4 restless dead).
	for _k in range(2):
		progress(pl, "kill", {"type": "skeleton", "name": "Skeleton"})
	# Partial collect progress (2 of 4 boar haunch).
	for _m in range(2):
		progress(pl, "collect", {"item": "raw_meat_mat", "amount": 1})
	# One talk objective satisfied on rh_petra_walk (2-step: talk + reach).
	progress(pl, "talk", {"npc": "gatewarden"})
	_refresh_ui()


func _self_test(pl: Node) -> void:
	print("[QUEST_TEST] ===== Raven Hollow quest engine self-test =====")
	print("[QUEST_TEST] catalog = %d quests loaded" % quest_count())
	var qid := "rh_wolves_gate"
	var d: Dictionary = quest_def(qid)
	print("[QUEST_TEST] quest '%s' : '%s' (giver=%s, zone=%s, lvl=%d)" % [
			qid, str(d.get("title", "?")), str(d.get("giver", "")),
			str(d.get("zone", "")), int(d.get("level", 0))])
	# Offer + accept.
	var offered: bool = offer(pl, qid)
	var accepted: bool = accept(pl, qid)
	print("[QUEST_TEST] offer=%s  accept=%s  -> status=%s" % [
			str(offered), str(accepted), status_of(pl, qid)])
	var req: int = int(_dict(objectives_of(qid)[0]).get("count", 0))
	print("[QUEST_TEST] objective: kill %d wolf" % req)
	# Fire matching kill events; watch the objective count climb.
	for i in range(req):
		progress(pl, "kill", {"type": "wolf", "name": "Wolf"})
		var line: Dictionary = objective_lines(pl, qid)[0]
		print("[QUEST_TEST]   kill %d -> %s  (done=%s, status=%s)" % [
				i + 1, str(line.get("text", "")), str(line.get("done", false)),
				status_of(pl, qid)])
	print("[QUEST_TEST] ready to turn in = %s" % str(is_ready(pl, qid)))
	# Reward proof: capture gold + xp before and after turn-in.
	var gold_before: int = _gold(pl)
	var xp_before: int = int(pl.get("xp")) if _has_prop(pl, "xp") else -1
	var lvl_before: int = _player_level(pl)
	var turned: bool = turn_in(pl, qid)
	print("[QUEST_TEST] turn_in=%s  is_complete=%s" % [str(turned), str(is_complete(pl, qid))])
	print("[QUEST_TEST] reward grant: gold %d -> %d (+%d) ; level %d->%d ; xp %d->%d" % [
			gold_before, _gold(pl), _gold(pl) - gold_before,
			lvl_before, _player_level(pl), xp_before,
			int(pl.get("xp")) if _has_prop(pl, "xp") else -1])
	print("[QUEST_TEST] reward line: %s" % rewards_text(qid))
	# A non-matching kill must NOT advance the (turned-in) quest.
	var before_boar: String = status_of(pl, "rh_boar_cull")
	if offer(pl, "rh_boar_cull") and accept(pl, "rh_boar_cull"):
		progress(pl, "kill", {"type": "wolf", "name": "Wolf"})
		var l2: Dictionary = objective_lines(pl, "rh_boar_cull")[0]
		print("[QUEST_TEST] cross-check: boar quest ignores a wolf kill -> %s" % str(l2.get("text", "")))
	# Chain proof: the follow-up quest should now be available.
	print("[QUEST_TEST] follow-up 'rh_wolves_proof' eligible now = %s" % str(is_eligible(pl, "rh_wolves_proof")))
	print("[QUEST_TEST] active quests = %s" % str(active_quests(pl)))
	print("[QUEST_TEST] ===== self-test complete =====")


# --- helpers -----------------------------------------------------------------

func _obj_pos(obj: Dictionary) -> Vector2:
	var p: Variant = obj.get("pos")
	if p is Vector2:
		return p
	if p is Array and (p as Array).size() >= 2:
		return Vector2(float((p as Array)[0]), float((p as Array)[1]))
	return Vector2.ZERO


func _current_map() -> String:
	var scn: Node = get_tree().current_scene
	if scn != null:
		var m: Variant = scn.get("current_map_id")
		if m is String:
			return m
	return ""


func _npc_present(npc_id: String) -> bool:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if str(n.name) == npc_id:
			return true
	return false


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _player_level(actor: Node) -> int:
	if actor != null and _has_prop(actor, "level"):
		var lv: Variant = actor.get("level")
		if lv is int or lv is float:
			return maxi(1, int(lv))
	return 1


func _gold(actor: Node) -> int:
	if _has_prop(actor, "gold"):
		var g: Variant = actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("QuestSystem: missing data file '%s'" % path)
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
	var pl: Node = _player()
	if pl == null:
		return {}
	var states: Dictionary = _actor_states(pl)
	# JSON-safe copy: counts keys are already strings.
	var out_states: Dictionary = {}
	for qid: String in states.keys():
		var s: Dictionary = _dict(states[qid])
		out_states[qid] = {
			"status": str(s.get("status", "")),
			"counts": _dict(s.get("counts", {})).duplicate(),
			"rewarded": bool(s.get("rewarded", false)),
		}
	return {"states": out_states, "tracked": _track_order.duplicate()}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var states: Dictionary = _actor_states(pl)
	states.clear()
	for qid: String in _dict(d.get("states", {})).keys():
		if not _defs.has(qid):
			continue
		var s: Dictionary = _dict(_dict(d.get("states", {}))[qid])
		states[qid] = {
			"status": str(s.get("status", "")),
			"counts": _dict(s.get("counts", {})).duplicate(),
			"tracked": false,
			"rewarded": bool(s.get("rewarded", false)),
		}
	_track_order.clear()
	for qid_v: Variant in _arr(d.get("tracked", [])):
		if _defs.has(str(qid_v)):
			_add_tracked(str(qid_v))
	_refresh_ui()
