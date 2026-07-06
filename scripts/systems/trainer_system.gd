extends Node
## TrainerSystem -- autoload (/root/TrainerSystem). One system cluster covering
## three BACKLOG items with a single, additive, null-safe file:
##
##   #58 SPELL / ABILITY TRAINERS -- data/trainers.json. Trainer NPCs per class /
##       zone teach kit abilities (ids verbatim from class_defs.gd) at a gold +
##       level cost. learn_ability(actor, id) checks level (StatsSystem/actor) and
##       gold (actor purse), records the known set, and (guarded) appends to the
##       player's unlocked_abilities. A Trainer panel (learnable list + cost +
##       Learn buttons) self-instances as a CanvasLayer child, hidden until
##       open_trainer(trainer_id). Emits ability_learned.
##
##   #43 STARTING-ZONE NEW-PLAYER FLOW -- data/starting_flow.json. Per-class start
##       zone + mentor + a short ORDERED onboarding checklist (move, attack, loot,
##       talk-to-trainer, equip). Runtime tracks first-session progress; on the
##       last step it grants a starter reward through LootSystem. GUARDED: the
##       auto-begin only fires for a fresh actor (level 1, no xp). Emits
##       starting_step_done / starting_flow_complete.
##
##   #36 HIDDEN DEBUFFS / CURSES -- data/hidden_debuffs.json. Afflictions applied
##       SILENTLY (no toast, no icon) whose small stat mods ride the SAME
##       StatsSystem modifier bus StatusSystem uses -- so they are real and
##       provable while never surfacing. reveal_debuff() flips them visible and,
##       when the def names a status_mirror, routes the reveal THROUGH
##       StatusSystem.apply so the shipped debuff bar picks it up. cleanse()
##       strips the mods (and any mirror). Emits hidden_debuff_revealed.
##
## Everything here is additive: no other system's .gd is edited (StatsSystem,
## StatusSystem, LootSystem are only READ / called). Guarded throughout -- a null
## actor, a host missing gold/level, or an absent sibling autoload is a no-op.
##
## Public API (actor = the player node, group "player"; optional -> the player):
##   learn_ability(actor, ability_id) -> Dictionary   {ok, reason, rank, gold}
##   knows_ability(actor, ability_id) -> bool ; known_abilities(actor) -> Array
##   open_trainer(trainer_id) / close_trainer()
##   trainer_def(id) / trainers_in_zone(zone) / teaches_for_class(class_id)
##   begin_starting_flow(actor, force=false) -> bool
##   complete_step(actor, step_id) -> bool ; flow_progress(actor) -> Dictionary
##   is_flow_active(actor) -> bool ; is_flow_complete(actor) -> bool
##   apply_hidden_debuff(actor, id) -> bool ; reveal_debuff(actor, id) -> bool
##   cleanse(actor, id) -> bool ; is_hidden(actor,id) / is_revealed(actor,id)
##   hidden_debuffs(actor) -> Array (revealed only) ; debuff_def(id)
## Signals:
##   ability_learned(actor, ability_id, rank)
##   starting_step_done(actor, step_id) ; starting_flow_complete(actor)
##   hidden_debuff_applied(actor, debuff_id)      (silent -- for systems, no UI)
##   hidden_debuff_revealed(actor, debuff_id)
##   hidden_debuff_cleansed(actor, debuff_id)

signal ability_learned(actor, ability_id, rank)
signal starting_step_done(actor, step_id)
signal starting_flow_complete(actor)
signal hidden_debuff_applied(actor, debuff_id)
signal hidden_debuff_revealed(actor, debuff_id)
signal hidden_debuff_cleansed(actor, debuff_id)

const TRAINERS_PATH := "res://data/trainers.json"
const FLOW_PATH := "res://data/starting_flow.json"
const DEBUFFS_PATH := "res://data/hidden_debuffs.json"

const MOVE_STEP_PX := 48.0        # flow "move" auto-completes past this from spawn
const FLOW_POLL_S := 0.25

# --- Trainers (#58) ---
var _trainers: Dictionary = {}                 # trainer_id -> def
var _ability_index: Dictionary = {}            # ability_id -> Array[{trainer, class_id, rank, level_req, gold_cost}]

# --- Starting flow (#43) ---
var _checklist: Array = []                     # ordered [{id, text}]
var _flows: Dictionary = {}                    # class_id -> flow def
var _reward_fallback: Dictionary = {}

# --- Hidden debuffs (#36) ---
var _debuffs: Dictionary = {}                  # debuff_id -> def
var _max_hidden: int = 3

## instance_id -> {known:{id:rank}, flow:{...}, hidden:{id:{revealed,mod_keys,mirror}}}
var _actors: Dictionary = {}

var _panel: CanvasLayer = null
var _open_trainer_id: String = ""
var _flow_accum: float = 0.0
var _flow_started_for: Dictionary = {}         # iid -> true (auto-begin fired once)


func _ready() -> void:
	_load_all()
	# Auto "loot" step + graceful reward filing both ride LootSystem.
	if LootSystem != null and LootSystem.has_signal("loot_generated"):
		LootSystem.loot_generated.connect(_on_loot_generated)
	set_process(true)
	if not OS.get_environment("RH_TRAINER_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_all() -> void:
	_load_trainers()
	_load_flow()
	_load_debuffs()


func _load_trainers() -> void:
	var root: Dictionary = _read_json(TRAINERS_PATH)
	_trainers = _dict(root.get("trainers", {}))
	_ability_index.clear()
	for tid: String in _trainers.keys():
		var t: Dictionary = _dict(_trainers[tid])
		var cid: String = str(t.get("class_id", ""))
		for e_v: Variant in _arr(t.get("teaches", [])):
			var e: Dictionary = _dict(e_v)
			var aid: String = str(e.get("ability", ""))
			if aid == "":
				continue
			var list: Array = _ability_index.get(aid, [])
			list.append({
				"trainer": tid, "class_id": cid,
				"rank": int(e.get("rank", 1)),
				"level_req": int(e.get("level_req", 1)),
				"gold_cost": int(e.get("gold_cost", 0)),
			})
			_ability_index[aid] = list
	if _trainers.is_empty():
		push_warning("TrainerSystem: no trainers loaded from %s" % TRAINERS_PATH)


func _load_flow() -> void:
	var root: Dictionary = _read_json(FLOW_PATH)
	_checklist = _arr(root.get("checklist", []))
	_flows = _dict(root.get("flows", {}))
	_reward_fallback = _dict(root.get("reward_fallback", {}))
	if _checklist.is_empty():
		push_warning("TrainerSystem: starting-flow checklist empty (%s)" % FLOW_PATH)


func _load_debuffs() -> void:
	var root: Dictionary = _read_json(DEBUFFS_PATH)
	_debuffs = _dict(root.get("debuffs", {}))
	_max_hidden = int(root.get("max_hidden", 3))
	if _debuffs.is_empty():
		push_warning("TrainerSystem: no hidden debuffs loaded from %s" % DEBUFFS_PATH)


# ============================================================================
# #58 -- SPELL / ABILITY TRAINERS
# ============================================================================

func trainer_def(trainer_id: String) -> Dictionary:
	return _dict(_trainers.get(trainer_id, {}))


func trainers_in_zone(zone: String) -> Array:
	var out: Array = []
	for tid: String in _trainers.keys():
		if str(_dict(_trainers[tid]).get("zone", "")) == zone:
			out.append(tid)
	return out


## Every teach entry offered to a class (across all its trainers), lowest level first.
func teaches_for_class(class_id: String) -> Array:
	var out: Array = []
	for tid: String in _trainers.keys():
		var t: Dictionary = _dict(_trainers[tid])
		if str(t.get("class_id", "")) != class_id:
			continue
		for e_v: Variant in _arr(t.get("teaches", [])):
			var e: Dictionary = _dict(e_v).duplicate()
			e["trainer"] = tid
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level_req", 1)) < int(b.get("level_req", 1)))
	return out


func trainer_count() -> int:
	return _trainers.size()


## The teach entry for `ability_id` matching `class_id` ({} if this class can't learn it).
func _teach_entry(ability_id: String, class_id: String) -> Dictionary:
	for e_v: Variant in _arr(_ability_index.get(ability_id, [])):
		var e: Dictionary = _dict(e_v)
		if str(e.get("class_id", "")) == class_id:
			return e
	return {}


func knows_ability(actor: Node, ability_id: String) -> bool:
	return (_state(actor)["known"] as Dictionary).has(ability_id)


func known_abilities(actor: Node) -> Array:
	return (_state(actor)["known"] as Dictionary).keys()


func ability_rank(actor: Node, ability_id: String) -> int:
	return int((_state(actor)["known"] as Dictionary).get(ability_id, 0))


## Train an ability for `actor`. Checks class match, level (>= level_req) and gold
## (>= gold_cost), deducts gold, records the known rank, guardedly unlocks it on
## the player, and emits ability_learned. Returns {ok, reason, rank, gold}.
func learn_ability(actor: Node, ability_id: String) -> Dictionary:
	if actor == null:
		return {"ok": false, "reason": "no actor"}
	var cid: String = _class_id(actor)
	var e: Dictionary = _teach_entry(ability_id, cid)
	if e.is_empty():
		return {"ok": false, "reason": "no trainer teaches this to your class"}
	var rank: int = int(e.get("rank", 1))
	if ability_rank(actor, ability_id) >= rank:
		return {"ok": false, "reason": "already known"}
	var lvl_req: int = int(e.get("level_req", 1))
	if _level(actor) < lvl_req:
		return {"ok": false, "reason": "requires level %d" % lvl_req}
	var cost: int = int(e.get("gold_cost", 0))
	var purse: int = _gold(actor)
	if purse < cost:
		return {"ok": false, "reason": "not enough gold (need %d)" % cost}
	if cost > 0 and _has_prop(actor, "gold"):
		actor.set("gold", purse - cost)
	(_state(actor)["known"] as Dictionary)[ability_id] = rank
	_grant_unlock(actor, ability_id)
	ability_learned.emit(actor, ability_id, rank)
	return {"ok": true, "reason": "", "rank": rank, "gold": cost}


## Guarded: if the player tracks an unlocked_abilities Array (STARTING_ZONES sec 2),
## add the trained ability so the hotbar lights it. Absent property = no-op.
func _grant_unlock(actor: Node, ability_id: String) -> void:
	if not _has_prop(actor, "unlocked_abilities"):
		return
	var ua: Variant = actor.get("unlocked_abilities")
	if ua is Array and not (ua as Array).has(ability_id):
		(ua as Array).append(ability_id)


# --- Trainer panel (self-instanced CanvasLayer, built in code) --------------

func open_trainer(trainer_id: String) -> void:
	if not _trainers.has(trainer_id):
		push_warning("TrainerSystem.open_trainer: unknown trainer '%s'" % trainer_id)
		return
	_open_trainer_id = trainer_id
	_ensure_panel()
	if _panel == null:
		return
	_populate_panel(trainer_id)
	_panel.visible = true
	_panel.set_meta("is_open", true)
	# Talking to your own mentor satisfies the flow's talk_trainer step.
	var pl: Node = _player()
	if pl != null and _class_id(pl) == str(trainer_def(trainer_id).get("class_id", "")):
		complete_step(pl, "talk_trainer")


func close_trainer() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false
		_panel.set_meta("is_open", false)


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	var cl := CanvasLayer.new()
	cl.name = "TrainerPanel"
	cl.layer = 90
	cl.visible = false
	cl.set_meta("is_open", false)
	cl.add_to_group("trainer_ui")

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.02, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(160, 40)
	frame.custom_minimum_size = Vector2(320, 280)
	cl.add_child(frame)

	var vb := VBoxContainer.new()
	vb.name = "Body"
	vb.add_theme_constant_override("separation", 6)
	frame.add_child(vb)

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 16)
	vb.add_child(title)

	var sub := Label.new()
	sub.name = "Sub"
	sub.add_theme_font_size_override("font_size", 10)
	sub.modulate = Color(0.78, 0.72, 0.6)
	vb.add_child(sub)

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 4)
	vb.add_child(list)

	var closeb := Button.new()
	closeb.name = "Close"
	closeb.text = "Close"
	closeb.pressed.connect(close_trainer)
	vb.add_child(closeb)

	cl.set_meta("is_open", false)
	add_child(cl)
	_panel = cl


func _populate_panel(trainer_id: String) -> void:
	if _panel == null:
		return
	var frame: Node = _panel.get_node_or_null("Frame")
	if frame == null:
		return
	var body: Node = frame.get_node_or_null("Body")
	if body == null:
		return
	var t: Dictionary = trainer_def(trainer_id)
	var title: Label = body.get_node_or_null("Title") as Label
	if title != null:
		title.text = str(t.get("name", trainer_id))
	var sub: Label = body.get_node_or_null("Sub") as Label
	if sub != null:
		sub.text = "%s  --  %s trainer" % [str(t.get("title", "")), str(t.get("class_id", ""))]
	var list: Node = body.get_node_or_null("List")
	if list == null:
		return
	for c: Node in list.get_children():
		c.queue_free()
	var pl: Node = _player()
	for e_v: Variant in _arr(t.get("teaches", [])):
		var e: Dictionary = _dict(e_v)
		var aid: String = str(e.get("ability", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		var owned: bool = pl != null and knows_ability(pl, aid)
		lbl.text = "%s  (L%d, %dg)" % [aid, int(e.get("level_req", 1)), int(e.get("gold_cost", 0))]
		lbl.custom_minimum_size = Vector2(210, 0)
		row.add_child(lbl)
		var btn := Button.new()
		if owned:
			btn.text = "Known"
			btn.disabled = true
		else:
			btn.text = "Learn"
			var can: bool = pl != null and _level(pl) >= int(e.get("level_req", 1)) \
					and _gold(pl) >= int(e.get("gold_cost", 0))
			btn.disabled = not can
			btn.pressed.connect(_on_learn_pressed.bind(aid))
		row.add_child(btn)
		list.add_child(row)


func _on_learn_pressed(ability_id: String) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var res: Dictionary = learn_ability(pl, ability_id)
	if bool(res.get("ok", false)) and _open_trainer_id != "":
		_populate_panel(_open_trainer_id)   # refresh Known / affordability states


# ============================================================================
# #43 -- STARTING-ZONE NEW-PLAYER FLOW
# ============================================================================

## A fresh actor: first session (level 1, no xp), flow not already run.
func _is_fresh(actor: Node) -> bool:
	if actor == null:
		return false
	if _level(actor) > 1:
		return false
	if _has_prop(actor, "xp") and int(actor.get("xp")) > 0:
		return false
	var f: Dictionary = _state(actor)["flow"]
	return not bool(f.get("complete", false))


## Begin (or restart with force) the onboarding flow for the actor's class.
## Auto-begin (from the flow poll) only runs for a fresh actor; `force` bypasses
## the fresh guard (used by the self-test). Returns true if a flow started.
func begin_starting_flow(actor: Node, force: bool = false) -> bool:
	if actor == null or _checklist.is_empty():
		return false
	var cid: String = _class_id(actor)
	if not _flows.has(cid):
		return false
	if not force and not _is_fresh(actor):
		return false
	var f: Dictionary = _state(actor)["flow"]
	f["active"] = true
	f["complete"] = false
	f["reward_granted"] = false
	f["class"] = cid
	f["done"] = {}
	f["spawn"] = _player_pos(actor)
	_flow_started_for[actor.get_instance_id()] = true
	return true


func is_flow_active(actor: Node) -> bool:
	return bool((_state(actor)["flow"] as Dictionary).get("active", false))


func is_flow_complete(actor: Node) -> bool:
	return bool((_state(actor)["flow"] as Dictionary).get("complete", false))


## Ordered step ids from the checklist.
func flow_steps() -> Array:
	var out: Array = []
	for s_v: Variant in _checklist:
		out.append(str(_dict(s_v).get("id", "")))
	return out


func flow_progress(actor: Node) -> Dictionary:
	var f: Dictionary = _state(actor)["flow"]
	var done: Dictionary = _dict(f.get("done", {}))
	return {
		"active": bool(f.get("active", false)),
		"complete": bool(f.get("complete", false)),
		"class": str(f.get("class", "")),
		"done": done.keys(),
		"total": _checklist.size(),
		"count": done.size(),
		"reward_granted": bool(f.get("reward_granted", false)),
	}


## Mark one onboarding step done. Unknown / already-done steps are a no-op. When
## the last step lands, grants the reward via LootSystem and completes the flow.
func complete_step(actor: Node, step_id: String) -> bool:
	if actor == null:
		return false
	var f: Dictionary = _state(actor)["flow"]
	if not bool(f.get("active", false)):
		return false
	if not _is_step(step_id):
		return false
	var done: Dictionary = f["done"]
	if done.has(step_id):
		return false
	done[step_id] = true
	starting_step_done.emit(actor, step_id)
	if done.size() >= _checklist.size():
		_complete_flow(actor)
	return true


func _is_step(step_id: String) -> bool:
	for s_v: Variant in _checklist:
		if str(_dict(s_v).get("id", "")) == step_id:
			return true
	return false


func _complete_flow(actor: Node) -> void:
	var f: Dictionary = _state(actor)["flow"]
	f["active"] = false
	f["complete"] = true
	var cid: String = str(f.get("class", _class_id(actor)))
	var flow_def: Dictionary = _dict(_flows.get(cid, {}))
	var reward: Dictionary = _dict(flow_def.get("reward", _reward_fallback))
	_grant_reward(actor, reward)
	f["reward_granted"] = true
	starting_flow_complete.emit(actor)


## Grants the starter reward THROUGH LootSystem: gold onto the purse, then item
## dicts built by LootSystem.roll_item pushed through its loot_generated pipeline
## (the shipped inventory + loot-window path files them). A named loot_table, if
## present and known, rolls too. Fully guarded.
func _grant_reward(actor: Node, reward: Dictionary) -> void:
	var gold: int = int(reward.get("gold", 0))
	if gold > 0 and _has_prop(actor, "gold"):
		actor.set("gold", _gold(actor) + gold)
	if LootSystem == null:
		return
	var items: Array = []
	for it_v: Variant in _arr(reward.get("items", [])):
		var it: Dictionary = _dict(it_v)
		if not LootSystem.has_method("roll_item"):
			break
		var d: Dictionary = LootSystem.roll_item(str(it.get("id", "")), str(it.get("rarity", "")))
		if not d.is_empty():
			items.append(d)
	var table: String = str(reward.get("loot_table", ""))
	if table != "" and LootSystem.has_method("roll_loot"):
		LootSystem.roll_loot(table)   # emits loot_generated itself
	if not items.is_empty() and LootSystem.has_signal("loot_generated"):
		LootSystem.loot_generated.emit(items)


func _process(delta: float) -> void:
	_flow_accum += delta
	if _flow_accum < FLOW_POLL_S:
		return
	_flow_accum = 0.0
	var pl: Node = _player()
	if pl == null:
		return
	# Auto-begin for a fresh player once.
	if not _flow_started_for.has(pl.get_instance_id()) and _is_fresh(pl):
		begin_starting_flow(pl)
	# Auto-complete the "move" step by watching the player leave the spawn spot.
	if is_flow_active(pl):
		var f: Dictionary = _state(pl)["flow"]
		if not _dict(f.get("done", {})).has("move"):
			var spawn: Vector2 = f.get("spawn", _player_pos(pl))
			if _player_pos(pl).distance_to(spawn) > MOVE_STEP_PX:
				complete_step(pl, "move")


## LootSystem fired: file the auto "loot" step for an active flow (and this is the
## same signal the starter reward rides -- harmless after completion).
func _on_loot_generated(_items: Variant) -> void:
	var pl: Node = _player()
	if pl != null and is_flow_active(pl):
		complete_step(pl, "loot")


# ============================================================================
# #36 -- HIDDEN DEBUFFS / CURSES
# ============================================================================

func debuff_def(debuff_id: String) -> Dictionary:
	return _dict(_debuffs.get(debuff_id, {}))


func debuff_count() -> int:
	return _debuffs.size()


func is_hidden(actor: Node, debuff_id: String) -> bool:
	var h: Dictionary = _state(actor)["hidden"]
	return h.has(debuff_id) and not bool(_dict(h[debuff_id]).get("revealed", false))


func is_revealed(actor: Node, debuff_id: String) -> bool:
	var h: Dictionary = _state(actor)["hidden"]
	return h.has(debuff_id) and bool(_dict(h[debuff_id]).get("revealed", false))


func has_debuff(actor: Node, debuff_id: String) -> bool:
	return (_state(actor)["hidden"] as Dictionary).has(debuff_id)


## Effects the player can currently SEE (revealed only) -- the honest HUD contract.
func hidden_debuffs(actor: Node) -> Array:
	var out: Array = []
	var h: Dictionary = _state(actor)["hidden"]
	for did: String in h.keys():
		if bool(_dict(h[did]).get("revealed", false)):
			out.append(did)
	return out


## Count of still-incubating (hidden, unrevealed) effects on the actor.
func incubating_count(actor: Node) -> int:
	var n: int = 0
	var h: Dictionary = _state(actor)["hidden"]
	for did: String in h.keys():
		if not bool(_dict(h[did]).get("revealed", false)):
			n += 1
	return n


## Apply a hidden curse SILENTLY. Its stat mods ride StatsSystem (the same bus
## StatusSystem uses) but nothing surfaces -- no toast, no bar entry -- until
## reveal_debuff. Refuses a 4th incubating effect (oldest-first, doc sec 1.4).
## Returns true on a fresh apply.
func apply_hidden_debuff(actor: Node, debuff_id: String) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var def: Dictionary = debuff_def(debuff_id)
	if def.is_empty():
		push_warning("TrainerSystem.apply_hidden_debuff: unknown '%s'" % debuff_id)
		return false
	var h: Dictionary = _state(actor)["hidden"]
	if h.has(debuff_id):
		return false
	if incubating_count(actor) >= _max_hidden:
		return false   # symptom-soup guard
	var mod_keys: Array = _apply_debuff_mods(actor, debuff_id, def)
	h[debuff_id] = {
		"revealed": false,
		"mirror": str(def.get("status_mirror", "")),
		"mod_keys": mod_keys,
	}
	hidden_debuff_applied.emit(actor, debuff_id)   # quiet -- for systems, no UI
	return true


## Flip a hidden curse visible. Routes THROUGH StatusSystem when the def names a
## status_mirror (the effect surfaces on the shipped debuff bar); always emits
## hidden_debuff_revealed. No-op if not present or already revealed.
func reveal_debuff(actor: Node, debuff_id: String) -> bool:
	var h: Dictionary = _state(actor)["hidden"]
	if not h.has(debuff_id):
		return false
	var rec: Dictionary = h[debuff_id]
	if bool(rec.get("revealed", false)):
		return false
	rec["revealed"] = true
	var mirror: String = str(rec.get("mirror", ""))
	if mirror != "" and StatusSystem != null and StatusSystem.has_method("apply"):
		StatusSystem.apply(actor, mirror)   # visible-bar escalation, routed through StatusSystem
	hidden_debuff_revealed.emit(actor, debuff_id)
	return true


## Remove a curse (hidden or revealed): strips its StatsSystem mods and any mirror
## on the StatusSystem bar. Emits hidden_debuff_cleansed. No-op if not present.
func cleanse(actor: Node, debuff_id: String) -> bool:
	var h: Dictionary = _state(actor)["hidden"]
	if not h.has(debuff_id):
		return false
	var rec: Dictionary = _dict(h[debuff_id])
	for k_v: Variant in _arr(rec.get("mod_keys", [])):
		if StatsSystem != null and StatsSystem.has_method("remove_modifier"):
			StatsSystem.remove_modifier(str(k_v))
	var mirror: String = str(rec.get("mirror", ""))
	if mirror != "" and bool(rec.get("revealed", false)) \
			and StatusSystem != null and StatusSystem.has_method("remove"):
		StatusSystem.remove(actor, mirror)
	h.erase(debuff_id)
	hidden_debuff_cleansed.emit(actor, debuff_id)
	return true


## Push the def's small stat_mods onto the StatsSystem modifier bus, one source
## key per stat. Returns the keys so cleanse can strip them exactly.
func _apply_debuff_mods(actor: Node, debuff_id: String, def: Dictionary) -> Array:
	var keys: Array = []
	if StatsSystem == null or not StatsSystem.has_method("add_modifier"):
		return keys
	var mods: Dictionary = _dict(def.get("stat_mods", {}))
	for stat: Variant in mods:
		var amount: float = float(mods[stat])
		if amount == 0.0:
			continue
		var src: String = "hiddenfx:%s:%d:%s" % [debuff_id, actor.get_instance_id(), str(stat)]
		StatsSystem.add_modifier(actor, src, str(stat), amount)
		keys.append(src)
	return keys


# ============================================================================
# SELF-TEST (RH_TRAINER_TEST=1) -- ASCII-only prints (console is cp1252)
# ============================================================================

func _run_selftest() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	print("[TRAINER_TEST] ===== Raven Hollow trainer/flow/debuff self-test =====")
	print("[TRAINER_TEST] trainers=%d  flow_steps=%d  hidden_debuffs=%d" % [
		trainer_count(), _checklist.size(), debuff_count()])
	if pl == null:
		print("TRAINER SELFTEST FAIL no player found (boot with RH_CLASS=<class>)")
		return
	var cid: String = _class_id(pl)
	print("[TRAINER_TEST] player class = '%s'  level=%d  gold=%d" % [cid, _level(pl), _gold(pl)])

	# --- (1) STARTING FLOW (run first, while the actor is fresh) -------------
	var f_ok: bool = _test_flow(pl, cid)

	# --- (2) TRAINER LEARN ---------------------------------------------------
	var t_ok: bool = _test_learn(pl, cid)

	# --- (3) HIDDEN DEBUFF ---------------------------------------------------
	var d_ok: bool = _test_debuff(pl)

	var all_ok: bool = f_ok and t_ok and d_ok
	var verdict: String = "PASS" if all_ok else "FAIL"
	print("TRAINER SELFTEST %s trainers(#58) learn=%s | flow(#43) complete=%s | debuffs(#36) hide/reveal/cleanse=%s" % [
		verdict, str(t_ok), str(f_ok), str(d_ok)])
	print("[TRAINER_TEST] ===== self-test complete =====")


func _test_flow(pl: Node, cid: String) -> bool:
	if not _flows.has(cid):
		print("[TRAINER_TEST] flow: no flow for class '%s' -- SKIP-FAIL" % cid)
		return false
	begin_starting_flow(pl, true)
	var steps: Array = flow_steps()
	var completed_flag := {"v": false}
	var conn := func(_a: Node) -> void: completed_flag["v"] = true
	starting_flow_complete.connect(conn)
	var gold_before: int = _gold(pl)
	for sid_v: Variant in steps:
		complete_step(pl, str(sid_v))
	starting_flow_complete.disconnect(conn)
	var prog: Dictionary = flow_progress(pl)
	var ok: bool = is_flow_complete(pl) and bool(prog.get("reward_granted", false)) and bool(completed_flag["v"])
	print("[TRAINER_TEST] flow: steps=%s done=%d/%d complete=%s reward_granted=%s gold %d->%d" % [
		str(steps), int(prog.get("count", 0)), int(prog.get("total", 0)),
		str(is_flow_complete(pl)), str(prog.get("reward_granted", false)), gold_before, _gold(pl)])
	return ok


func _test_learn(pl: Node, cid: String) -> bool:
	var offers: Array = teaches_for_class(cid)
	if offers.is_empty():
		print("[TRAINER_TEST] learn: no trainer offers for class '%s' -- FAIL" % cid)
		return false
	var pick: Dictionary = _dict(offers[0])
	var aid: String = str(pick.get("ability", ""))
	# Grant the means to pay/qualify (proves the guarded gold + level checks).
	if _has_prop(pl, "level"):
		pl.set("level", maxi(_level(pl), int(pick.get("level_req", 1))))
	if _has_prop(pl, "gold"):
		pl.set("gold", _gold(pl) + int(pick.get("gold_cost", 0)) + 50)
	var known_before: bool = knows_ability(pl, aid)
	var res: Dictionary = learn_ability(pl, aid)
	var known_after: bool = knows_ability(pl, aid)
	# Also prove the guard: an out-of-class ability is refused.
	var bad: Dictionary = learn_ability(pl, "__not_a_real_ability__")
	var ok: bool = bool(res.get("ok", false)) and known_after and not known_before and not bool(bad.get("ok", false))
	print("[TRAINER_TEST] learn: ability='%s' from trainer='%s' -> ok=%s known=%s (bad-ability refused=%s)" % [
		aid, str(pick.get("trainer", "")), str(res.get("ok", false)), str(known_after), str(not bool(bad.get("ok", false)))])
	return ok


func _test_debuff(pl: Node) -> bool:
	# Pick a debuff with a status_mirror so reveal provably routes through StatusSystem.
	var did: String = ""
	for k: String in _debuffs.keys():
		if str(_dict(_debuffs[k]).get("status_mirror", "")) != "":
			did = k
			break
	if did == "":
		did = str(_debuffs.keys()[0]) if not _debuffs.is_empty() else ""
	if did == "":
		print("[TRAINER_TEST] debuff: catalogue empty -- FAIL")
		return false
	var mirror: String = str(debuff_def(did).get("status_mirror", ""))
	var applied: bool = apply_hidden_debuff(pl, did)
	var hidden_ok: bool = is_hidden(pl, did) and not is_revealed(pl, did) \
			and not hidden_debuffs(pl).has(did)   # invisible while hidden
	var revealed: bool = reveal_debuff(pl, did)
	var reveal_ok: bool = is_revealed(pl, did) and hidden_debuffs(pl).has(did)
	var mirror_ok: bool = true
	if mirror != "" and StatusSystem != null and StatusSystem.has_method("has"):
		mirror_ok = bool(StatusSystem.has(pl, mirror))   # surfaced on the real bar
	var cleansed: bool = cleanse(pl, did)
	var gone_ok: bool = not has_debuff(pl, did)
	var mirror_gone: bool = true
	if mirror != "" and StatusSystem != null and StatusSystem.has_method("has"):
		mirror_gone = not bool(StatusSystem.has(pl, mirror))
	var ok: bool = applied and hidden_ok and revealed and reveal_ok and mirror_ok and cleansed and gone_ok and mirror_gone
	print("[TRAINER_TEST] debuff: id='%s' mirror='%s' | applied=%s hidden=%s revealed=%s on_bar=%s cleansed=%s gone=%s" % [
		did, mirror, str(applied), str(hidden_ok), str(revealed), str(mirror_ok), str(cleansed), str(gone_ok and mirror_gone)])
	return ok


# ============================================================================
# HELPERS
# ============================================================================

func _state(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _actors.has(key):
		_actors[key] = {
			"known": {},
			"flow": {"active": false, "complete": false, "reward_granted": false,
				"class": "", "done": {}, "spawn": Vector2.ZERO},
			"hidden": {},
		}
	return _actors[key]


func _class_id(actor: Node) -> String:
	if actor == null:
		return ""
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary:
		return str((cd as Dictionary).get("id", ""))
	var cid: Variant = actor.get("class_id")
	if cid is String:
		return cid
	return ""


func _level(actor: Node) -> int:
	if actor == null:
		return 1
	if _has_prop(actor, "level"):
		var l: Variant = actor.get("level")
		if l is int or l is float:
			return int(l)
	return 1


func _gold(actor: Node) -> int:
	if _has_prop(actor, "gold"):
		var g: Variant = actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _player_pos(actor: Node) -> Vector2:
	if actor is Node2D:
		return (actor as Node2D).global_position
	return Vector2.ZERO


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
		push_warning("TrainerSystem: missing data file '%s'" % path)
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
	var st: Dictionary = _state(pl)
	var hidden_out: Dictionary = {}
	for did: String in (st["hidden"] as Dictionary).keys():
		hidden_out[did] = bool(_dict(st["hidden"][did]).get("revealed", false))
	return {
		"known": (st["known"] as Dictionary).duplicate(),
		"flow": {
			"complete": bool((st["flow"] as Dictionary).get("complete", false)),
			"done": (_dict((st["flow"] as Dictionary).get("done", {}))).keys(),
		},
		"hidden": hidden_out,
	}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var st: Dictionary = _state(pl)
	st["known"] = _dict(d.get("known", {})).duplicate()
	var fin: Dictionary = _dict(d.get("flow", {}))
	(st["flow"] as Dictionary)["complete"] = bool(fin.get("complete", false))
	var done: Dictionary = {}
	for sid_v: Variant in _arr(fin.get("done", [])):
		done[str(sid_v)] = true
	(st["flow"] as Dictionary)["done"] = done
	# Hidden effects re-apply their mods on load; only revealed-state is restored.
	for did_v: Variant in _dict(d.get("hidden", {})).keys():
		var did: String = str(did_v)
		if not _debuffs.has(did):
			continue
		apply_hidden_debuff(pl, did)
		if bool(_dict(d.get("hidden", {}))[did]):
			reveal_debuff(pl, did)
