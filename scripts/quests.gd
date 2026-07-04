class_name Quests
extends Node
## Phase C quest state machine (SPEC_PHASE_C_DEMO.md §4). Pure logic node —
## no UI, no scene lookups except living in group "quests". Data comes from
## QuestDefs (quest_defs.gd). Everything it needs from the world arrives via
## the report_*/set_* API below; everything the world needs from it leaves
## via signals. State is JSON-safe (to_save_dict / from_save_dict).
##
## Quest life cycle:  locked -> available -> active -> ready -> completed
##   locked     prereq quests not completed yet (giver offers nothing)
##   available  giver shows "!" and offers the quest
##   active     objectives in progress (obj_index walks the chain; a chosen
##              choice branch replaces everything after the choice)
##   ready      all objectives done, turn-in npc shows "?"
##   completed  rewards granted, journal note written (turn_in_npc "" skips
##              ready and completes on the final objective — quests 3B, 5)
##
## ------------------------------------------------------------------
## INTEGRATION (implemented by the integration pass — this file only
## DEFINES the contract; do not wire these here):
## ------------------------------------------------------------------
## main.gd
##   - After world build, before UIs:
##       var quests := Quests.new(); quests.name = "Quests"; add_child(quests)
##   - Wire tracker repaint:
##       quests.quest_started.connect(func(_q: String) -> void: hud.update_tracker(quests.tracker_lines()))
##       quests.quest_updated.connect(...)   # same repaint
##       quests.quest_completed.connect(...) # same repaint
##   - quest_started -> dialogue_ui.show_banner("New Quest", def title) (nice-to-have)
##   - quest_completed -> dialogue_ui.show_banner("Quest Complete", title);
##       if the def has finale_pages, show them via
##       dialogue_ui.show_dialogue(def.finale_speaker, def.finale_pages)
##       AFTER handling cinematic_beat (see below).
##   - rewards_granted(qid, r) -> XP system add_xp(r.xp); player gold += r.gold.
##       Items are NOT granted here (see item_granted).
##   - item_granted(item_id) -> var it := Items.get_item(item_id);
##       if not it.is_empty(): player inventory .add_item(it) + hud toast.
##       (Unknown ids — e.g. crafting mats landing later — warn and skip.)
##   - objective_note(text) -> parchment toast (dialogue_ui banner subtitle or
##       hud log line). These are the arrive_note beats — they carry lore.
##   - cinematic_beat("listener_whisper") -> dim the screen ~0.6 s (vignette
##       CanvasLayer 5 modulate tween down and back) before finale pages.
##   - Day/night system: quests.set_night(is_night) on every phase change.
##   - Save: dict["quests"] = quests.to_save_dict(); Load: call
##       quests.from_save_dict(dict.get("quests", {})) then repaint tracker.
##
## player.gd (_physics_process — THROTTLED, do not call every tick):
##   _quest_pos_t += delta
##   if _quest_pos_t >= 0.25:
##       _quest_pos_t = 0.0
##       var q := get_tree().get_first_node_in_group("quests") as Quests
##       if q != null: q.report_position(current_map_id, global_position)
##   (current_map_id comes from main.gd's map system: "town"/"wilderness".)
##
## enemy.gd (die path, exactly once, before queue_free):
##   var q := get_tree().get_first_node_in_group("quests") as Quests
##   if q != null: q.report_kill(type_name)
##   Types used by demo quests: "skeleton", "boar", "orc_shaman".
##
## npc.gd (quest markers + state-based dialogue):
##   - Marker: small Alagard Label above the head (gold, outline dark), text
##     from quests.marker_for_npc(id) — "!" offer, "?" turn-in/talk, "" none.
##     Refresh on quests.quest_updated/quest_completed/quest_started.
##   - interact(): var r := quests.npc_interact(id)
##       if r.is_empty(): fall through to default dialogue rotation
##       else:
##           ui.show_dialogue(display_name, r["pages"])
##           await ui.dialogue_finished        # connect one-shot in practice
##           quests.npc_interact_done(r)
##           var ch: Dictionary = r.get("choice", {})
##           if not ch.is_empty():
##               ui.show_choice(display_name, ch["prompt"], ch["a"], ch["b"])
##               # on ui.choice_made(opt):
##               var follow := quests.report_choice(r["quest_id"], opt)
##               if not follow.is_empty(): ui.show_dialogue(display_name, follow)
##
## dialogue_ui.gd extension (two-option prompt — GK-styled, layer 10):
##   signal choice_made(option: String)          # "a" or "b", emitted once
##   func show_choice(speaker: String, prompt: String, option_a: String,
##       option_b: String) -> void
##   Prompt in parchment, two gold option rows; keys 1/2 + mouse click;
##   closes itself after emitting. Blocks player input like show_dialogue.
##
## hud.gd (tracker panel, top-right under the minimap):
##   func update_tracker(lines: Array) -> void
##   `lines` is what tracker_lines() returns: up to MAX_TRACKED entries of
##   { "title": String, "line": String } — title Alagard gold ~11 px, line
##   parchment ~10 px. Hide the panel when the array is empty.
##
## World/wilderness builders + choice-in-the-world (quest 4):
##   - Re-bind PLACEHOLDER objective spots to builder truth:
##       quests.override_pos("q4_camp", camp_pos)
##       quests.override_pos("q5_treeline", listener_pos)
##       quests.override_pos("q5_gate", waystone_pos)
##   - When quest_updated fires and quests.pending_choice() is non-empty with
##     npc == "" (quest 4's camp overlook), main.gd shows it via
##     dialogue_ui.show_choice("", prompt, a, b) -> report_choice as above.
##   - Mira escort (quest 5): her follow controller calls
##       quests.set_flag("escort_mira", true) while she is following (within
##       40 px leash) and false when she stalls; the q5_gate reach objective
##       only fires while that flag is true.
##
## bag_ui.gd / inventory (quest 3 branch A — bury the dagger):
##   Right-click on "weeping_dagger":
##       if quests.report_use_item("weeping_dagger", map_id, player_pos):
##           remove the item from the bag (it was consumed by the burial)
##   Quest 3 branch B: on rewards, integration removes "weeping_dagger" and
##   item_granted delivers "bloody_dagger" (see quest_defs INTEGRATION §4).

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
## THE item-grant channel — integration adds Items.get_item(item_id) to the
## bag. rewards_granted lists items too but only for toast text; granting
## from both would duplicate.
signal item_granted(item_id: String)
signal rewards_granted(quest_id: String, rewards: Dictionary)
signal objective_note(text: String)
signal cinematic_beat(beat_id: String)

const MAX_TRACKED: int = 2

const ST_LOCKED := "locked"
const ST_AVAILABLE := "available"
const ST_ACTIVE := "active"
const ST_READY := "ready"
const ST_COMPLETED := "completed"

var _defs: Dictionary = {}
## quest_id -> {"state": String, "obj_index": int, "progress": int,
##              "choice": String ("" | "a" | "b")}  — JSON-safe.
var _states: Dictionary = {}
var _tracked: Array[String] = []
## World flags fed by integration: "night": bool, "escort_<npc>": bool.
var _flags: Dictionary = {}
## objective_id -> Vector2 re-binds from builders (override_pos).
var _pos_overrides: Dictionary = {}


func _ready() -> void:
	add_to_group("quests")
	_defs = QuestDefs.all()
	for qid: String in _defs.keys():
		if not _states.has(qid):
			_states[qid] = _fresh_state(qid)
	_refresh_locks()


# ----------------------------------------------------------------------
# World flags (integration feeds these)
# ----------------------------------------------------------------------

func set_night(is_night_now: bool) -> void:
	_flags["night"] = is_night_now


func is_night() -> bool:
	return bool(_flags.get("night", false))


func set_flag(key: String, value: bool) -> void:
	_flags[key] = value


## Builders re-bind placeholder objective positions to built-world truth.
func override_pos(objective_id: String, pos: Vector2) -> void:
	_pos_overrides[objective_id] = pos


# ----------------------------------------------------------------------
# Queries
# ----------------------------------------------------------------------

func state_of(quest_id: String) -> String:
	return str(_state(quest_id).get("state", ST_LOCKED))


func is_active(quest_id: String) -> bool:
	var s: String = state_of(quest_id)
	return s == ST_ACTIVE or s == ST_READY


func is_completed(quest_id: String) -> bool:
	return state_of(quest_id) == ST_COMPLETED


## "!" = has a quest to offer, "?" = turn-in ready or wanted for a talk
## objective, "" = nothing. Priority: turn-in > talk > offer.
func marker_for_npc(npc_id: String) -> String:
	for qid: String in _defs.keys():
		if state_of(qid) == ST_READY and _effective_turn_in(qid) == npc_id:
			return "?"
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		var kind: String = str(obj.get("kind", ""))
		if (kind == "talk" or kind == "choice") and str(obj.get("npc", "")) == npc_id:
			return "?"
	for qid: String in _defs.keys():
		if state_of(qid) == ST_AVAILABLE and str(_defs[qid].get("giver", "")) == npc_id:
			return "!"
	return ""


## Quest content for talking to an NPC, or {} to fall through to default
## dialogue. Shape: {"quest_id", "kind" ("offer"|"talk"|"turn_in"|"reminder"|
## "aftermath"), "pages": Array, "choice": {} or {"prompt","a","b"}}.
## After the pages finish, call npc_interact_done(result); if "choice" is
## non-empty, then show the two-option prompt and call report_choice.
func npc_interact(npc_id: String) -> Dictionary:
	# 1. Turn-ins first — the payoff beat always wins.
	for qid: String in _defs.keys():
		if state_of(qid) == ST_READY and _effective_turn_in(qid) == npc_id:
			return {
				"quest_id": qid,
				"kind": "turn_in",
				"pages": _effective_turn_in_pages(qid),
				"choice": {},
			}
	# 2. Active talk objectives (may chain straight into a choice).
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		var kind: String = str(obj.get("kind", ""))
		if kind == "talk" and str(obj.get("npc", "")) == npc_id:
			return {
				"quest_id": qid,
				"kind": "talk",
				"pages": obj.get("pages", []),
				"choice": _choice_preview(_next_obj(qid)),
			}
		# Player walked away from an NPC-anchored choice — re-offer it.
		if kind == "choice" and str(obj.get("npc", "")) == npc_id:
			return {
				"quest_id": qid,
				"kind": "reminder",
				"pages": obj.get("retry_pages", []),
				"choice": _choice_preview(obj),
			}
	# 3. Offers.
	for qid: String in _defs.keys():
		if state_of(qid) == ST_AVAILABLE and str(_defs[qid].get("giver", "")) == npc_id:
			return {
				"quest_id": qid,
				"kind": "offer",
				"pages": _defs[qid].get("offer_pages", []),
				"choice": {},
			}
	# 4. Giver reminder while in progress.
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		if str(_defs[qid].get("giver", "")) != npc_id:
			continue
		var pages: Array = _defs[qid].get("active_pages", [])
		if not pages.is_empty():
			return {"quest_id": qid, "kind": "reminder", "pages": pages, "choice": {}}
	# 5. Aftermath echoes replace default dialogue after completion.
	for qid: String in _defs.keys():
		if state_of(qid) != ST_COMPLETED:
			continue
		var after: Dictionary = _effective_aftermath(qid)
		if after.has(npc_id):
			return {"quest_id": qid, "kind": "aftermath", "pages": after[npc_id], "choice": {}}
	return {}


## Call when the dialogue pages from npc_interact() have finished.
func npc_interact_done(result: Dictionary) -> void:
	var qid: String = str(result.get("quest_id", ""))
	if qid == "" or not _defs.has(qid):
		return
	match str(result.get("kind", "")):
		"offer":
			_accept(qid)
		"talk":
			if state_of(qid) == ST_ACTIVE and str(_current_obj(qid).get("kind", "")) == "talk":
				_advance(qid)
		"turn_in":
			if state_of(qid) == ST_READY:
				_complete(qid)
		_:
			pass


## The world choice pending on any active quest (quest 4's camp overlook,
## or an NPC choice the player abandoned). {} when none.
## Shape: {"quest_id", "prompt", "a", "b", "npc"}.
func pending_choice() -> Dictionary:
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		if str(obj.get("kind", "")) != "choice":
			continue
		var preview: Dictionary = _choice_preview(obj)
		preview["quest_id"] = qid
		preview["npc"] = str(obj.get("npc", ""))
		return preview
	return {}


# ----------------------------------------------------------------------
# Reports (the world tells the quest log what happened)
# ----------------------------------------------------------------------

func report_kill(enemy_type: String) -> void:
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		if str(obj.get("kind", "")) != "kill" or str(obj.get("enemy", "")) != enemy_type:
			continue
		var st: Dictionary = _state(qid)
		st["progress"] = int(st.get("progress", 0)) + 1
		if int(st["progress"]) >= int(obj.get("count", 1)):
			_advance(qid)
		else:
			quest_updated.emit(qid)


## Throttled position ping from the player (~4 Hz). Handles reach
## objectives, escort arrival and auto-trigger zones.
func report_position(map_id: String, pos: Vector2) -> void:
	_check_auto_triggers(map_id, pos)
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		if str(obj.get("kind", "")) != "reach":
			continue
		if str(obj.get("map", "")) != map_id:
			continue
		if bool(obj.get("night_only", false)) and not is_night():
			continue
		var escort: String = str(obj.get("escort", ""))
		if escort != "" and not bool(_flags.get("escort_" + escort, false)):
			continue
		if pos.distance_to(_obj_pos(obj)) > float(obj.get("radius", 40.0)):
			continue
		_arrive(qid, obj)


## Low-level talk report (alternative to npc_interact/_done for simple
## wiring — do NOT use both paths for the same interaction, it would
## double-advance). Returns true if a talk objective advanced.
func report_talk(npc_id: String) -> bool:
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		if str(obj.get("kind", "")) == "talk" and str(obj.get("npc", "")) == npc_id:
			_advance(qid)
			return true
	return false


## Resolve a pending choice objective. `option` is "a" or "b". Returns the
## chosen option's follow-up pages (Array of String) for the UI to show —
## empty Array if none or invalid.
func report_choice(quest_id: String, option: String) -> Array:
	if option != "a" and option != "b":
		return []
	if state_of(quest_id) != ST_ACTIVE:
		return []
	var obj: Dictionary = _current_obj(quest_id)
	if str(obj.get("kind", "")) != "choice":
		return []
	var opt: Dictionary = obj.get(option, {})
	_state(quest_id)["choice"] = option
	var pages: Array = opt.get("pages", [])
	_advance(quest_id)
	return pages


## Right-click use of a quest item (quest 3 burial). Returns true if the
## item was consumed by an objective — the caller removes it from the bag.
func report_use_item(item_id: String, map_id: String, pos: Vector2) -> bool:
	for qid: String in _defs.keys():
		if state_of(qid) != ST_ACTIVE:
			continue
		var obj: Dictionary = _current_obj(qid)
		if str(obj.get("kind", "")) != "use_item" or str(obj.get("item", "")) != item_id:
			continue
		if obj.has("map") and str(obj.get("map", "")) != map_id:
			continue
		if obj.has("pos") and pos.distance_to(_obj_pos(obj)) > float(obj.get("radius", 40.0)):
			continue
		_advance(qid)
		return true
	return false


# ----------------------------------------------------------------------
# Tracking (max 2, spec §4)
# ----------------------------------------------------------------------

func set_tracked(quest_id: String, on: bool) -> bool:
	if on:
		if _tracked.has(quest_id):
			return true
		if _tracked.size() >= MAX_TRACKED:
			return false
		_tracked.append(quest_id)
	else:
		_tracked.erase(quest_id)
	quest_updated.emit(quest_id)
	return true


func is_tracked(quest_id: String) -> bool:
	return _tracked.has(quest_id)


func tracked_ids() -> Array[String]:
	return _tracked.duplicate()


## HUD tracker content: up to MAX_TRACKED of {"title": String, "line": String}.
func tracker_lines() -> Array:
	var lines: Array = []
	for qid: String in _tracked:
		var s: String = state_of(qid)
		if s != ST_ACTIVE and s != ST_READY:
			continue
		var def: Dictionary = _defs[qid]
		var line: String = ""
		if s == ST_READY:
			line = "Return to %s" % QuestDefs.npc_label(_effective_turn_in(qid))
		else:
			var obj: Dictionary = _current_obj(qid)
			line = str(obj.get("text", ""))
			if str(obj.get("kind", "")) == "kill":
				line += " (%d/%d)" % [int(_state(qid).get("progress", 0)), int(obj.get("count", 1))]
		lines.append({"title": str(def.get("title", qid)), "line": line})
	return lines


## Journal data for a future quest-log UI: active + completed quests.
func journal_entries() -> Array:
	var out: Array = []
	for qid: String in _defs.keys():
		var s: String = state_of(qid)
		if s != ST_ACTIVE and s != ST_READY and s != ST_COMPLETED:
			continue
		var def: Dictionary = _defs[qid]
		var body: String = str(def.get("summary", ""))
		if s == ST_COMPLETED:
			body = _effective_note(qid)
		out.append({
			"quest_id": qid,
			"title": str(def.get("title", qid)),
			"state": s,
			"body": body,
			"tracked": is_tracked(qid),
		})
	return out


# ----------------------------------------------------------------------
# Save / load (JSON-safe)
# ----------------------------------------------------------------------

func to_save_dict() -> Dictionary:
	return {
		"states": _states.duplicate(true),
		"tracked": _tracked.duplicate(),
	}


func from_save_dict(data: Dictionary) -> void:
	if _defs.is_empty():
		_defs = QuestDefs.all()
	var saved: Dictionary = data.get("states", {})
	_states = {}
	for qid: String in _defs.keys():
		var st: Dictionary = _fresh_state(qid)
		if saved.has(qid) and saved[qid] is Dictionary:
			var s: Dictionary = saved[qid]
			var state_name: String = str(s.get("state", st["state"]))
			if [ST_LOCKED, ST_AVAILABLE, ST_ACTIVE, ST_READY, ST_COMPLETED].has(state_name):
				st["state"] = state_name
			st["choice"] = str(s.get("choice", ""))
			st["progress"] = int(s.get("progress", 0))
			st["obj_index"] = int(s.get("obj_index", 0))
			_states[qid] = st
			# Clamp against the (possibly patched) def chain.
			var chain_size: int = _objective_chain(qid).size()
			if int(st["obj_index"]) > chain_size:
				st["obj_index"] = chain_size
		else:
			_states[qid] = st
	_tracked = []
	for t: Variant in data.get("tracked", []):
		var tid: String = str(t)
		if _defs.has(tid) and _tracked.size() < MAX_TRACKED:
			_tracked.append(tid)
	_refresh_locks()
	for qid: String in _defs.keys():
		quest_updated.emit(qid)


# ----------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------

func _state(quest_id: String) -> Dictionary:
	if not _states.has(quest_id):
		_states[quest_id] = _fresh_state(quest_id)
	return _states[quest_id]


func _fresh_state(quest_id: String) -> Dictionary:
	return {
		"state": ST_LOCKED if _is_locked(quest_id) else ST_AVAILABLE,
		"obj_index": 0,
		"progress": 0,
		"choice": "",
	}


func _is_locked(quest_id: String) -> bool:
	var def: Dictionary = _defs.get(quest_id, {})
	for p: Variant in def.get("prereq", []):
		if not is_completed(str(p)):
			return true
	return false


## Unlock quests whose prereqs are now met.
func _refresh_locks() -> void:
	for qid: String in _defs.keys():
		if state_of(qid) == ST_LOCKED and not _is_locked(qid):
			_state(qid)["state"] = ST_AVAILABLE
			quest_updated.emit(qid)


## The full objective list: base objectives up to and including the choice,
## then the chosen branch's objectives (once a choice was made).
func _objective_chain(quest_id: String) -> Array:
	var def: Dictionary = _defs.get(quest_id, {})
	var base: Array = def.get("objectives", [])
	var choice: String = str(_state(quest_id).get("choice", ""))
	if choice == "":
		return base
	var chain: Array = []
	for obj: Variant in base:
		chain.append(obj)
		if str((obj as Dictionary).get("kind", "")) == "choice":
			var opt: Dictionary = (obj as Dictionary).get(choice, {})
			chain.append_array(opt.get("objectives", []))
			return chain
	return chain


func _current_obj(quest_id: String) -> Dictionary:
	var chain: Array = _objective_chain(quest_id)
	var idx: int = int(_state(quest_id).get("obj_index", 0))
	if idx < 0 or idx >= chain.size():
		return {}
	return chain[idx]


func _next_obj(quest_id: String) -> Dictionary:
	var chain: Array = _objective_chain(quest_id)
	var idx: int = int(_state(quest_id).get("obj_index", 0)) + 1
	if idx < 0 or idx >= chain.size():
		return {}
	return chain[idx]


func _choice_preview(obj: Dictionary) -> Dictionary:
	if str(obj.get("kind", "")) != "choice":
		return {}
	var a: Dictionary = obj.get("a", {})
	var b: Dictionary = obj.get("b", {})
	return {
		"prompt": str(obj.get("prompt", "")),
		"a": str(a.get("label", "")),
		"b": str(b.get("label", "")),
	}


## The chosen choice option's dict, or {} before any choice.
func _chosen_option(quest_id: String) -> Dictionary:
	var choice: String = str(_state(quest_id).get("choice", ""))
	if choice == "":
		return {}
	for obj: Variant in _defs.get(quest_id, {}).get("objectives", []):
		if str((obj as Dictionary).get("kind", "")) == "choice":
			return (obj as Dictionary).get(choice, {})
	return {}


func _effective_turn_in(quest_id: String) -> String:
	var opt: Dictionary = _chosen_option(quest_id)
	if opt.has("turn_in_npc"):
		return str(opt["turn_in_npc"])
	return str(_defs.get(quest_id, {}).get("turn_in_npc", ""))


func _effective_turn_in_pages(quest_id: String) -> Array:
	var opt: Dictionary = _chosen_option(quest_id)
	if opt.has("turn_in_pages") and not (opt["turn_in_pages"] as Array).is_empty():
		return opt["turn_in_pages"]
	return _defs.get(quest_id, {}).get("turn_in_pages", [])


func _effective_rewards(quest_id: String) -> Dictionary:
	var opt: Dictionary = _chosen_option(quest_id)
	if opt.has("rewards"):
		return opt["rewards"]
	return _defs.get(quest_id, {}).get("rewards", {})


func _effective_note(quest_id: String) -> String:
	var opt: Dictionary = _chosen_option(quest_id)
	if opt.has("note") and str(opt["note"]) != "":
		return str(opt["note"])
	return str(_defs.get(quest_id, {}).get("note", ""))


func _effective_aftermath(quest_id: String) -> Dictionary:
	var merged: Dictionary = {}
	var base: Dictionary = _defs.get(quest_id, {}).get("aftermath", {})
	for k: Variant in base.keys():
		merged[k] = base[k]
	var opt: Dictionary = _chosen_option(quest_id)
	var extra: Dictionary = opt.get("aftermath", {})
	for k: Variant in extra.keys():
		merged[k] = extra[k]
	return merged


func _obj_pos(obj: Dictionary) -> Vector2:
	var oid: String = str(obj.get("id", ""))
	if oid != "" and _pos_overrides.has(oid):
		return _pos_overrides[oid]
	return obj.get("pos", Vector2.ZERO)


func _check_auto_triggers(map_id: String, pos: Vector2) -> void:
	for qid: String in _defs.keys():
		var s: String = state_of(qid)
		# auto_trigger ignores prereq locks by design (spec quest 5: "OR").
		if s != ST_AVAILABLE and s != ST_LOCKED:
			continue
		var trig: Dictionary = _defs[qid].get("auto_trigger", {})
		if trig.is_empty():
			continue
		if str(trig.get("map", "")) != map_id:
			continue
		if bool(trig.get("night_only", false)) and not is_night():
			continue
		if pos.distance_to(trig.get("pos", Vector2.ZERO)) > float(trig.get("radius", 60.0)):
			continue
		_accept(qid)
		# Freshly accepted — the reach loop in report_position picks up its
		# first objective on this same ping (finding Mira at the treeline).


func _accept(quest_id: String) -> void:
	var st: Dictionary = _state(quest_id)
	if str(st["state"]) != ST_AVAILABLE and str(st["state"]) != ST_LOCKED:
		return
	st["state"] = ST_ACTIVE
	st["obj_index"] = 0
	st["progress"] = 0
	st["choice"] = ""
	for item: Variant in _defs.get(quest_id, {}).get("accept_items", []):
		item_granted.emit(str(item))
	if _tracked.size() < MAX_TRACKED and not _tracked.has(quest_id):
		_tracked.append(quest_id)
	quest_started.emit(quest_id)
	quest_updated.emit(quest_id)


func _advance(quest_id: String) -> void:
	var st: Dictionary = _state(quest_id)
	st["obj_index"] = int(st.get("obj_index", 0)) + 1
	st["progress"] = 0
	var chain: Array = _objective_chain(quest_id)
	if int(st["obj_index"]) >= chain.size():
		if _effective_turn_in(quest_id) == "":
			_complete(quest_id)
		else:
			st["state"] = ST_READY
			quest_updated.emit(quest_id)
	else:
		quest_updated.emit(quest_id)


func _arrive(quest_id: String, obj: Dictionary) -> void:
	var grant: String = str(obj.get("grant_item", ""))
	if grant != "":
		item_granted.emit(grant)
	var note: String = str(obj.get("arrive_note", ""))
	if note != "":
		objective_note.emit(note)
	_advance(quest_id)


func _complete(quest_id: String) -> void:
	var st: Dictionary = _state(quest_id)
	if str(st["state"]) == ST_COMPLETED:
		return
	st["state"] = ST_COMPLETED
	var def: Dictionary = _defs.get(quest_id, {})
	var beat: String = str(def.get("finale_beat", ""))
	if beat != "":
		cinematic_beat.emit(beat)
	var rewards: Dictionary = _effective_rewards(quest_id)
	rewards_granted.emit(quest_id, rewards.duplicate(true))
	for item: Variant in rewards.get("items", []):
		item_granted.emit(str(item))
	_tracked.erase(quest_id)
	_refresh_locks()
	quest_completed.emit(quest_id)
	quest_updated.emit(quest_id)
