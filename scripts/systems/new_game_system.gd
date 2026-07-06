extends Node
## NewGameSystem -- autoload (/root/NewGameSystem). The NEW-GAME FLOW orchestrator
## that ties the shipped pieces together (BACKLOG #84 -> #43): the Diablo-2 class
## SELECT SCREEN picks a champion, the pick is recorded, the starting-zone spawn is
## kicked, and the per-class onboarding checklist (TrainerSystem #43) begins for a
## fresh actor. It is the thin conductor between two systems that already exist --
## it OWNS neither and edits neither; it only calls them, guarded.
##
## Everything here is additive, self-contained and boot-safe:
##   * loads its optional config (data/new_game.json) in _ready -- absent = defaults;
##   * needs NO world, NO player, and NO sibling systems to load;
##   * DEGRADES SAFELY -- every cross-system touch is get_node_or_null / has_method /
##     has_signal guarded. If SelectScreenSystem is absent it falls back to the
##     default class; if TrainerSystem or the player is absent the onboarding step is
##     simply skipped. Either way the chain never hangs: new_game_ready ALWAYS fires
##     with the chosen class so a boot flow that awaits it can proceed.
##
## Flow (state: idle -> choosing -> onboarding -> ready):
##   start_new_game()            open the select screen, bind class_selected once,
##                               then run the chain when a class is chosen. If no
##                               select screen exists, run immediately on the default.
##   new_game_scripted(class_id) headless path: skip the UI and run the exact same
##                               chain for the given class (used by tests / autostart).
##
## Public API:
##   start_new_game()                     -> begin the interactive flow
##   new_game_scripted(class_id) -> String   run the flow headless; returns chosen id
##   current_state() -> String            "idle" / "choosing" / "onboarding" / "ready"
##   chosen_class() -> String             the class recorded this run ("" if none yet)
##   start_zone() -> String               the zone the chosen class spawns in
##   is_choosing() / is_onboarding() / is_ready() -> bool
##   cancel()                             abort an in-progress choose (back to idle)
## Signals:
##   new_game_started()                   the flow opened (select screen up, or scripted)
##   class_chosen(class_id)               a class was recorded
##   onboarding_started(class_id)         starting-zone spawn + checklist kicked
##   new_game_ready(class_id)             the new game is live and playable

signal new_game_started()
signal class_chosen(class_id)
signal onboarding_started(class_id)
signal new_game_ready(class_id)

const DATA_PATH := "res://data/new_game.json"
const FLOW_PATH := "res://data/starting_flow.json"   # start-zone fallback source
const DEFAULT_ZONE := "raven_hollow"
const DEFAULT_CLASS := "warrior"

const ST_IDLE := "idle"
const ST_CHOOSING := "choosing"
const ST_ONBOARDING := "onboarding"
const ST_READY := "ready"

var _default_class: String = DEFAULT_CLASS
var _fallback_zone: String = DEFAULT_ZONE
var _zone_by_class: Dictionary = {}      # class_id -> zone id

var _state: String = ST_IDLE
var _chosen: String = ""
var _zone: String = DEFAULT_ZONE
var _bound: bool = false                 # class_selected connection is live


func _ready() -> void:
	_load_data()
	if not OS.get_environment("RH_NEWGAME_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_default_class = str(root.get("default_class", DEFAULT_CLASS))
	_fallback_zone = str(root.get("fallback_zone", DEFAULT_ZONE))
	_zone_by_class = _dict(root.get("start_zone_by_class", {}))
	# new_game.json is OPTIONAL -- silence is fine, defaults carry the flow.


# --- state queries ----------------------------------------------------------

func current_state() -> String:
	return _state


func chosen_class() -> String:
	return _chosen


func start_zone() -> String:
	return _zone


func is_choosing() -> bool:
	return _state == ST_CHOOSING


func is_onboarding() -> bool:
	return _state == ST_ONBOARDING


func is_ready() -> bool:
	return _state == ST_READY


# --- interactive flow -------------------------------------------------------

## Begin the interactive new-game flow: raise the select screen and wait for the
## player to confirm a class. Idempotent while already choosing. If no select
## screen is available, degrades to the default class and runs the chain at once.
func start_new_game() -> void:
	if _state == ST_CHOOSING or _state == ST_ONBOARDING:
		return   # a flow is already in progress; don't stack it
	_reset()
	_state = ST_CHOOSING
	new_game_started.emit()
	var ss: Node = _select_system()
	if ss != null and ss.has_method("open_select") and ss.has_signal("class_selected"):
		if not _bound and not ss.class_selected.is_connected(_on_class_selected):
			ss.class_selected.connect(_on_class_selected, CONNECT_ONE_SHOT)
			_bound = true
		ss.call("open_select")
	else:
		# No select screen in this build -> proceed on the default champion.
		_choose_and_run(_default_class)


## The player confirmed a class on the select screen.
func _on_class_selected(class_id: Variant) -> void:
	_bound = false
	if _state != ST_CHOOSING:
		return
	_choose_and_run(str(class_id))


## Abort an in-progress choice (e.g. the player backed out of the select screen).
func cancel() -> void:
	if _state != ST_CHOOSING:
		return
	_unbind()
	_state = ST_IDLE


# --- scripted / headless path -----------------------------------------------

## Skip the UI and run the exact same chain for `class_id`. Returns the class id
## actually used (falls back to the default when given ""). Safe to call headless.
func new_game_scripted(class_id: String) -> String:
	_reset()
	_state = ST_CHOOSING
	new_game_started.emit()
	var id: String = class_id if class_id != "" else _default_class
	_choose_and_run(id)
	return _chosen


# --- the shared chain -------------------------------------------------------

## Record the chosen class, then kick the starting-zone spawn + onboarding, then
## announce the game is ready. Runs identically for the UI and scripted paths.
func _choose_and_run(class_id: String) -> void:
	var id: String = class_id if class_id != "" else _default_class
	_chosen = id
	class_chosen.emit(id)
	_begin_onboarding(id)
	_state = ST_READY
	new_game_ready.emit(id)


## Kick the starting-zone spawn and the per-class onboarding checklist. Every touch
## is guarded: a missing player, an absent TrainerSystem, or a class with no flow
## just skips that step -- the chain still completes.
func _begin_onboarding(class_id: String) -> void:
	_state = ST_ONBOARDING
	_zone = _resolve_zone(class_id)
	var pl: Node = _player()
	# Guarded: stamp the chosen class onto a fresh player so the class-aware spawn
	# and TrainerSystem read the right id. Never clobber an already-set class.
	if pl != null:
		_apply_class_to_player(pl, class_id)
	onboarding_started.emit(class_id)
	# Kick the #43 onboarding checklist for a fresh actor (guarded no-op otherwise).
	var ts: Node = _trainer_system()
	if pl != null and ts != null and ts.has_method("begin_starting_flow"):
		ts.call("begin_starting_flow", pl, false)


func _resolve_zone(class_id: String) -> String:
	# 1) explicit map in new_game.json, 2) starting_flow.json per-class start_zone,
	# 3) the configured fallback. All guarded; returns a non-empty id.
	if _zone_by_class.has(class_id):
		var z: String = str(_zone_by_class[class_id])
		if z != "":
			return z
	var flow: Dictionary = _read_json(FLOW_PATH)
	var flows: Dictionary = _dict(flow.get("flows", {}))
	if flows.has(class_id):
		var fz: String = str(_dict(flows[class_id]).get("start_zone", ""))
		if fz != "":
			return fz
	return _fallback_zone if _fallback_zone != "" else DEFAULT_ZONE


## Guarded: give a freshly-spawned player its chosen class_def. Only fills an EMPTY
## class_def (never overwrites an existing choice) and only if ClassDefs knows the id.
func _apply_class_to_player(pl: Node, class_id: String) -> void:
	if not _has_prop(pl, "class_def"):
		return
	var cur: Variant = pl.get("class_def")
	if cur is Dictionary and not (cur as Dictionary).is_empty():
		return   # player already has a class; don't stomp it
	var def: Dictionary = ClassDefs.get_def(class_id)
	if def.is_empty():
		return
	pl.set("class_def", def)


# --- system / player lookups (all null-safe) --------------------------------

func _select_system() -> Node:
	return get_node_or_null("/root/SelectScreenSystem")


func _trainer_system() -> Node:
	return get_node_or_null("/root/TrainerSystem")


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _reset() -> void:
	_unbind()
	_state = ST_IDLE
	_chosen = ""
	_zone = _fallback_zone if _fallback_zone != "" else DEFAULT_ZONE


func _unbind() -> void:
	if not _bound:
		return
	var ss: Node = _select_system()
	if ss != null and ss.has_signal("class_selected") \
			and ss.class_selected.is_connected(_on_class_selected):
		ss.class_selected.disconnect(_on_class_selected)
	_bound = false


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	return {"chosen": _chosen, "zone": _zone, "state": _state}


func deserialize(d: Dictionary) -> void:
	_chosen = str(d.get("chosen", ""))
	_zone = str(d.get("zone", _fallback_zone))
	var s: String = str(d.get("state", ST_IDLE))
	if s in [ST_IDLE, ST_CHOOSING, ST_ONBOARDING, ST_READY]:
		_state = s


# --- self-test (RH_NEWGAME_TEST=1) -- ASCII-only prints (console is cp1252) --

func _run_selftest() -> void:
	# A couple of frames so autoloads settle (no world/player required).
	for _i in range(3):
		await get_tree().process_frame

	var got_chosen: Array = [""]
	var got_ready: Array = [""]
	var chosen_cb := func(cid: Variant) -> void: got_chosen[0] = str(cid)
	var ready_cb := func(cid: Variant) -> void: got_ready[0] = str(cid)
	class_chosen.connect(chosen_cb)
	new_game_ready.connect(ready_cb)

	# Run the full scripted chain for the warrior with pieces possibly absent.
	var returned: String = new_game_scripted("warrior")

	class_chosen.disconnect(chosen_cb)
	new_game_ready.disconnect(ready_cb)

	var ready: bool = is_ready()
	var ok: bool = true
	var notes: Array = []
	if got_chosen[0] != "warrior":
		ok = false
		notes.append("class_chosen='%s'" % got_chosen[0])
	if got_ready[0] != "warrior":
		ok = false
		notes.append("new_game_ready='%s'" % got_ready[0])
	if returned != "warrior":
		ok = false
		notes.append("returned='%s'" % returned)
	if not ready:
		ok = false
		notes.append("state='%s'" % _state)
	if chosen_class() != "warrior":
		ok = false
		notes.append("chosen_class='%s'" % chosen_class())

	var tail: String = "" if notes.is_empty() else ("  [" + "; ".join(PackedStringArray(notes)) + "]")
	print("NEWGAME SELFTEST %s class=%s ready=%s zone=%s%s" % [
		("PASS" if ok else "FAIL"), _chosen, str(ready), _zone, tail])
