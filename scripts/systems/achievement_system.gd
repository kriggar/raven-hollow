extends Node
## AchievementSystem -- autoload (/root/AchievementSystem). Build #55/#60 "Deed-Book".
## A WoW-style achievement ledger (design/ACHIEVEMENTS.md): 9 categories, ~60
## exemplar deeds + category metas loaded from data/achievements.json. Deeds track
## against a signal-fed event bus; earned deeds and points persist ACCOUNT-WIDE to
## user://achievements.cfg (independent of the per-slot save). Two pieces of UI are
## instanced from this autoload (mirroring MountSystem): a gold-bezel TOAST that
## slides in on every unlock, and the DEED-BOOK panel (scenes/ui/achievements.tscn,
## hotkey Y) with category tabs, per-deed progress bars and the running point total.
##
## Everything here is additive and null-safe: no other system's file is edited. The
## tracking hooks connect to signals that already exist (Quests.quest_completed,
## MapSystem.zone_revealed, TravelSystem.station_discovered, MountSystem.mount_unlocked,
## CraftingSystem.crafted/skill_up/recipe_learned) and a cheap ~4 Hz poll watches the
## player node for kills (enemy is_dead transitions), level, gold and equipped rarity.
## Nothing breaks if a source is absent -- that deed just never advances.
##
## Public API (actor = the player node, group "player"):
##   notify(actor, event, value)   feed the event bus; value = increment (counters),
##                                 absolute value (gauges: level/gold/mounts/skill),
##                                 or a String key (distinct sets: zones/stations)
##   unlock(actor, id) -> bool     idempotent earn (the only earn path)
##   is_unlocked(id) -> bool
##   progress(actor, id) -> int    current tracked value toward the threshold
##   points(actor) -> int          account point total
##   Data helpers: all_defs()/def(id)/categories()/deeds_in(cat)/threshold(id)/
##                 earned_info(id)/category_pips(cat)/total_points_possible()
## Signals: achievement_unlocked(id), progress_updated(id, value, target).

signal achievement_unlocked(id)
signal progress_updated(id, value, target)

const DATA_PATH := "res://data/achievements.json"
const PANEL_SCENE := "res://scenes/ui/achievements.tscn"
const LEDGER_PATH := "user://achievements.cfg"
const POLL_S := 0.25

## Events whose `value` is an absolute reading (progress = max seen), not a running
## total. Everything else with an int value accumulates. A String value always feeds
## a distinct set (progress = number of distinct keys).
const GAUGE_EVENTS := {
	"level": true, "gold": true, "mounts": true, "skill": true,
	"equip_rare_slots": true, "pvp_rank": true,
}

var _defs: Dictionary = {}          # id -> def dict
var _order: Array = []              # id order as authored
var _cats: Array = []               # [{id, name, epigraph}, ...]
var _event_index: Dictionary = {}   # event name -> [def ids]
var _metas: Array = []              # meta def ids

# Account-wide state (persisted to LEDGER_PATH).
var _earned: Dictionary = {}        # id -> {date, char, class}
var _points: int = 0
var _prog: Dictionary = {}          # id -> int
var _sets: Dictionary = {}          # id -> {key: true} distinct sets

# Kill / gauge poll bookkeeping.
var _poll_accum: float = 0.0
var _seen_dead: Dictionary = {}     # enemy instance_id -> true (counted)
var _last_level: int = -1
var _last_gold: int = -1
var _last_rare_slots: int = -1
var _quests_node: Node = null       # the group "quests" node (wired when present)

# UI.
var _toast_layer: CanvasLayer = null
var _toast_banner: Control = null
var _toast_pts: Label = null
var _toast_head: Label = null
var _toast_name: Label = null
var _toast_sub: Label = null
var _toast_q: Array = []
var _toasting: bool = false
var _toast_hold: float = 3.2
var _panel: Node = null

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.62, 0.57, 0.49)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.10, 0.08, 0.06, 0.97)

const BASE_W: float = 640.0
const BANNER_W: float = 272.0
const BANNER_H: float = 54.0


func _ready() -> void:
	_load_data()
	_load_ledger()
	_build_toast()
	_build_panel()
	set_process(true)
	call_deferred("_wire_autoloads")
	if not OS.get_environment("RH_ACHV").is_empty() \
			or not OS.get_environment("RH_ACHV_TEST").is_empty():
		call_deferred("_run_env_hooks")


# --- Data -------------------------------------------------------------------

func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_cats = _arr(root.get("categories", []))
	_order.clear()
	_defs.clear()
	_event_index.clear()
	_metas.clear()
	for d_v: Variant in _arr(root.get("deeds", [])):
		var d: Dictionary = _dict(d_v)
		var id: String = str(d.get("id", ""))
		if id == "":
			continue
		_defs[id] = d
		_order.append(id)
		var crit: Dictionary = _dict(d.get("criteria", {}))
		var ev: String = str(crit.get("event", ""))
		if ev == "meta":
			_metas.append(id)
		elif ev != "":
			if not _event_index.has(ev):
				_event_index[ev] = []
			(_event_index[ev] as Array).append(id)
	if _defs.is_empty():
		push_warning("AchievementSystem: no deeds loaded from %s" % DATA_PATH)


# --- The event bus ----------------------------------------------------------

## Feed an event to the ledger. `value` may be an int (counter increment or gauge
## reading) or a String (distinct-set key). Any deed whose criteria matches and
## reaches its threshold is unlocked immediately.
func notify(actor: Node, event: String, value: Variant = 1) -> void:
	var ids: Array = _event_index.get(event, [])
	if ids.is_empty():
		return
	# Snapshot ids to unlock after the loop (unlock() can mutate _earned/metas).
	var to_unlock: Array = []
	for id: String in ids:
		if _earned.has(id):
			continue
		var thr: int = threshold(id)
		var reached: bool = false
		if value is String:
			var s: Dictionary = _sets.get(id, {})
			s[str(value)] = true
			_sets[id] = s
			_prog[id] = s.size()
			reached = s.size() >= thr
		else:
			var v: int = int(value)
			if GAUGE_EVENTS.has(event):
				if v > int(_prog.get(id, 0)):
					_prog[id] = v
			else:
				_prog[id] = int(_prog.get(id, 0)) + maxi(v, 0)
			reached = int(_prog.get(id, 0)) >= thr
		progress_updated.emit(id, int(_prog.get(id, 0)), thr)
		if reached:
			to_unlock.append(id)
	for id: String in to_unlock:
		unlock(actor, id)


## The only earn path. Idempotent. Grants points, writes the ledger, fires the
## toast (via the signal) and cascades any metas that just completed.
func unlock(actor: Node, id: String) -> bool:
	if _earned.has(id) or not _defs.has(id):
		return false
	var def: Dictionary = _defs[id]
	_earned[id] = {
		"date": _today(),
		"char": _pname(actor),
		"class": _pclass(actor),
	}
	_points += int(def.get("points", 0))
	# Freeze the row's progress at its target so the panel bar reads full.
	if str(_dict(def.get("criteria", {})).get("event", "")) != "meta":
		_prog[id] = maxi(int(_prog.get(id, 0)), threshold(id))
	_route_reward(actor, _dict(def.get("reward", {})))
	_save_ledger()
	achievement_unlocked.emit(id)
	if _panel != null and _panel.has_method("on_ledger_changed"):
		_panel.call("on_ledger_changed")
	_check_metas(actor)
	return true


func is_unlocked(id: String) -> bool:
	return _earned.has(id)


func progress(_actor: Node, id: String) -> int:
	return int(_prog.get(id, 0))


func points(_actor: Node = null) -> int:
	return _points


func _check_metas(actor: Node) -> void:
	# Re-resolve metas after each earn; the grand meta chains off category metas,
	# so loop until a full pass unlocks nothing new.
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 8:
		changed = false
		guard += 1
		for id: String in _metas:
			if _earned.has(id):
				continue
			var needs: Array = _arr(_dict(_defs[id].get("criteria", {})).get("needs", []))
			var done: bool = not needs.is_empty()
			for n_v: Variant in needs:
				if not _earned.has(str(n_v)):
					done = false
					break
			if done:
				unlock(actor, id)
				changed = true


func _route_reward(actor: Node, reward: Dictionary) -> void:
	# Honor title / mount / item rewards through their real systems (all ship
	# now). Guarded so a missing system or key is harmless — the reward stays
	# recorded in the def ledger regardless.
	if reward.is_empty():
		return
	if actor == null:
		actor = _player()
	var title_id: String = str(reward.get("title", ""))
	if not title_id.is_empty():
		var ts: Node = get_node_or_null("/root/TitleSystem")
		if ts != null and ts.has_method("grant_title"):
			ts.call("grant_title", actor, title_id)
	var mount_id: String = str(reward.get("mount", ""))
	if not mount_id.is_empty():
		var ms: Node = get_node_or_null("/root/MountSystem")
		if ms != null and ms.has_method("unlock"):
			ms.call("unlock", actor, mount_id)
	var item_id: String = str(reward.get("item", ""))
	if not item_id.is_empty() and actor != null:
		var inv_v: Variant = actor.get("inventory")
		if inv_v is Object and (inv_v as Object).has_method("add_item"):
			var it: Dictionary = Items.get_item(item_id)
			if not it.is_empty():
				(inv_v as Object).call("add_item", it)


# --- Wiring (guarded; connects to signals that already exist) ----------------

func _wire_autoloads() -> void:
	_connect(get_node_or_null("/root/MapSystem"), "zone_revealed",
			func(zone_id: Variant) -> void: notify(_player(), "zones_visited", str(zone_id)))
	_connect(get_node_or_null("/root/TravelSystem"), "station_discovered",
			func(sid: Variant) -> void: notify(_player(), "stations", str(sid)))
	_connect(get_node_or_null("/root/MountSystem"), "mount_unlocked",
			func(actor: Variant, _mid: Variant) -> void:
				var pl: Node = actor if actor is Node else _player()
				var ms: Node = get_node_or_null("/root/MountSystem")
				var cnt: int = (ms.call("owned", pl) as Array).size() if ms != null and pl != null else 0
				notify(pl, "mounts", cnt))
	var cs: Node = get_node_or_null("/root/CraftingSystem")
	_connect(cs, "crafted",
			func(actor: Variant, _r: Variant, item: Variant) -> void:
				var pl: Node = actor if actor is Node else _player()
				notify(pl, "craft", 1)
				if item is Dictionary and bool((item as Dictionary).get("condition_met", false)):
					notify(pl, "craft_condition", 1))
	_connect(cs, "skill_up",
			func(actor: Variant, _prof: Variant, new_skill: Variant) -> void:
				notify(actor if actor is Node else _player(), "skill", int(new_skill)))
	_connect(cs, "recipe_learned",
			func(actor: Variant, _rid: Variant) -> void:
				notify(actor if actor is Node else _player(), "recipes_learned", 1))
	_wire_quests()


func _wire_quests() -> void:
	# The quest tracker (group "quests") is a world node, created after boot and
	# possibly rebuilt on map change. Reconnect whenever it appears fresh.
	var q: Node = get_tree().get_first_node_in_group("quests")
	if q == null or q == _quests_node:
		return
	_quests_node = q
	_connect(q, "quest_completed",
			func(qid: Variant) -> void: notify(_player(), "quests", 1))


func _connect(src: Object, sig: String, cb: Callable) -> void:
	if src == null or not src.has_signal(sig):
		return
	if not src.is_connected(sig, cb):
		src.connect(sig, cb)


# --- Poll (kills / level / gold / equipped rarity) --------------------------

func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_S:
		return
	_poll_accum = 0.0
	if _quests_node == null or not is_instance_valid(_quests_node):
		_wire_quests()
	var pl: Node = _player()
	if pl == null:
		return
	_poll_kills()
	_poll_gauges(pl)


func _poll_kills() -> void:
	var present: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n):
			continue
		var iid: int = n.get_instance_id()
		present[iid] = true
		if bool(n.get("is_dead")) and not _seen_dead.has(iid):
			_seen_dead[iid] = true
			notify(_player(), "kills", 1)
	# Drop bookkeeping for enemies that have despawned (freed corpses never return).
	for iid: int in _seen_dead.keys():
		if not present.has(iid):
			_seen_dead.erase(iid)


func _poll_gauges(pl: Node) -> void:
	var lvl: int = int(pl.get("level")) if _has(pl, "level") else -1
	if lvl >= 0 and lvl != _last_level:
		_last_level = lvl
		notify(pl, "level", lvl)
	var gold: int = int(pl.get("gold")) if _has(pl, "gold") else -1
	if gold >= 0 and gold != _last_gold:
		_last_gold = gold
		notify(pl, "gold", gold)
	var rare: int = _rare_slot_count(pl)
	if rare != _last_rare_slots:
		_last_rare_slots = rare
		notify(pl, "equip_rare_slots", rare)


func _rare_slot_count(pl: Node) -> int:
	var inv: Variant = pl.get("inventory") if _has(pl, "inventory") else null
	if inv == null or not (inv is Object):
		return 0
	var eq: Variant = inv.get("equipped")
	if not (eq is Dictionary):
		return 0
	var n: int = 0
	for slot: Variant in (eq as Dictionary).keys():
		var it: Variant = (eq as Dictionary)[slot]
		if it is Dictionary:
			var r: String = str((it as Dictionary).get("rarity", "common"))
			if r == "rare" or r == "epic" or r == "legendary":
				n += 1
	return n


# --- Ledger persistence (user://achievements.cfg) ---------------------------

func _load_ledger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LEDGER_PATH) != OK:
		return  # missing/corrupt -> clean empty ledger (defensive-load rule)
	_points = int(cfg.get_value("account", "points", 0))
	if cfg.has_section("earned"):
		for id: String in cfg.get_section_keys("earned"):
			var rec: Variant = cfg.get_value("earned", id, {})
			_earned[id] = rec if rec is Dictionary else {}
	if cfg.has_section("progress"):
		for id: String in cfg.get_section_keys("progress"):
			_prog[id] = int(cfg.get_value("progress", id, 0))
	if cfg.has_section("sets"):
		for id: String in cfg.get_section_keys("sets"):
			var keys: Variant = cfg.get_value("sets", id, [])
			var s: Dictionary = {}
			for k: Variant in _arr(keys):
				s[str(k)] = true
			_sets[id] = s
			_prog[id] = maxi(int(_prog.get(id, 0)), s.size())


func _save_ledger() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "version", 1)
	cfg.set_value("account", "points", _points)
	for id: String in _earned.keys():
		cfg.set_value("earned", id, _earned[id])
	for id: String in _prog.keys():
		cfg.set_value("progress", id, int(_prog[id]))
	for id: String in _sets.keys():
		cfg.set_value("sets", id, (_sets[id] as Dictionary).keys())
	cfg.save(LEDGER_PATH)


# --- Data helpers for the UI ------------------------------------------------

func all_defs() -> Dictionary:
	return _defs


func def(id: String) -> Dictionary:
	return _dict(_defs.get(id, {}))


func categories() -> Array:
	return _cats


func deeds_in(cat: String) -> Array:
	var out: Array = []
	for id: String in _order:
		if str(_dict(_defs[id]).get("category", "")) == cat:
			out.append(id)
	return out


func threshold(id: String) -> int:
	return int(_dict(_dict(_defs.get(id, {})).get("criteria", {})).get("threshold", 1))


func earned_info(id: String) -> Dictionary:
	return _dict(_earned.get(id, {}))


func total_points_possible() -> int:
	var t: int = 0
	for id: String in _defs.keys():
		t += int(_dict(_defs[id]).get("points", 0))
	return t


## {done, total} counting only non-hidden pointed rows (hidden deeds stay uncounted
## until earned so the tab pip never leaks their existence).
func category_pips(cat: String) -> Dictionary:
	var done: int = 0
	var total: int = 0
	for id: String in deeds_in(cat):
		var d: Dictionary = _dict(_defs[id])
		var hidden: bool = bool(d.get("hidden", false))
		if hidden and not _earned.has(id):
			continue
		total += 1
		if _earned.has(id):
			done += 1
	return {"done": done, "total": total}


# --- Toast (gold-bezel, slides in from the top) -----------------------------

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "AchievementToast"
	_toast_layer.layer = 25
	add_child(_toast_layer)

	_toast_banner = Control.new()
	_toast_banner.custom_minimum_size = Vector2(BANNER_W, BANNER_H)
	_toast_banner.size = Vector2(BANNER_W, BANNER_H)
	_toast_banner.position = Vector2((BASE_W - BANNER_W) * 0.5, _hidden_y())
	_toast_banner.visible = false
	_toast_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_banner)

	var frame := NinePatchRect.new()
	frame.texture = _panel_tex
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_banner.add_child(frame)

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 5
	bg.offset_top = 5
	bg.offset_right = -5
	bg.offset_bottom = -5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	# Round gold-bezel medallion overhanging the left edge, holding the points.
	var medal := Panel.new()
	medal.custom_minimum_size = Vector2(44, 44)
	medal.size = Vector2(44, 44)
	medal.position = Vector2(-6, (BANNER_H - 44) * 0.5)
	var msb := StyleBoxFlat.new()
	msb.bg_color = GOLD
	msb.border_color = OUTLINE_DARK
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(22)
	medal.add_theme_stylebox_override("panel", msb)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_banner.add_child(medal)

	_toast_pts = _mk_label("0", 16, Color(0.14, 0.10, 0.05))
	_toast_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_pts.add_theme_constant_override("outline_size", 0)
	_toast_pts.set_anchors_preset(Control.PRESET_FULL_RECT)
	medal.add_child(_toast_pts)

	_toast_head = _mk_label("ACHIEVEMENT UNLOCKED", 8, GOLD)
	_toast_head.position = Vector2(48, 5)
	_toast_head.size = Vector2(BANNER_W - 58, 11)
	_toast_banner.add_child(_toast_head)

	_toast_name = _mk_label("", 12, GOLD_BRIGHT)
	_toast_name.position = Vector2(48, 17)
	_toast_name.size = Vector2(BANNER_W - 58, 16)
	_toast_banner.add_child(_toast_name)

	_toast_sub = _mk_label("", 8, PARCHMENT)
	_toast_sub.position = Vector2(48, 35)
	_toast_sub.size = Vector2(BANNER_W - 58, 12)
	_toast_banner.add_child(_toast_sub)

	achievement_unlocked.connect(_on_unlock_toast)


func _on_unlock_toast(id: String) -> void:
	_toast_q.append(id)
	if not _toasting:
		_next_toast()


func _next_toast() -> void:
	if _toast_q.is_empty():
		_toasting = false
		return
	_toasting = true
	var id: String = str(_toast_q.pop_front())
	_fill_toast(id)
	_toast_banner.position.y = _hidden_y()
	_toast_banner.visible = true
	var tw := create_tween()
	tw.tween_property(_toast_banner, "position:y", 10.0, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_toast_hold)
	tw.tween_property(_toast_banner, "position:y", _hidden_y(), 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next_toast)


func _fill_toast(id: String) -> void:
	var d: Dictionary = _dict(_defs.get(id, {}))
	var pts: int = int(d.get("points", 0))
	var is_feat: bool = str(d.get("category", "")) == "feats" or pts == 0
	_toast_pts.text = "*" if is_feat else str(pts)
	_toast_head.text = "FEAT OF STRENGTH" if is_feat else "ACHIEVEMENT UNLOCKED"
	var nm: String = str(d.get("name", "Deed"))
	if bool(d.get("hidden", false)):
		nm = "* " + nm
	_toast_name.text = nm
	var cat_name: String = _cat_name(str(d.get("category", "")))
	if is_feat:
		_toast_sub.text = cat_name
	else:
		_toast_sub.text = "%s  -  %d points" % [cat_name, pts]


func _hidden_y() -> float:
	return -BANNER_H - 10.0


# --- Panel (Deed-Book) ------------------------------------------------------

func _build_panel() -> void:
	if not ResourceLoader.exists(PANEL_SCENE):
		push_warning("AchievementSystem: panel scene missing (%s)" % PANEL_SCENE)
		return
	var scn: PackedScene = load(PANEL_SCENE) as PackedScene
	if scn == null:
		return
	_panel = scn.instantiate()
	add_child(_panel)


func open_panel(actor: Node = null) -> void:
	if _panel == null:
		return
	if actor == null:
		actor = _player()
	if _panel.has_method("present"):
		_panel.call("present", self, actor)


func close_panel() -> void:
	if _panel != null and _panel.has_method("close"):
		_panel.call("close")


func toggle_panel() -> void:
	if _panel == null:
		return
	if bool(_panel.get("is_open")):
		close_panel()
	else:
		open_panel(_player())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_Y:
		return
	if _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_panel()


func _panel_blocking() -> bool:
	# Never steal Y while a text field / dialogue / bag / shop is capturing input.
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui", "mounts_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env self-test (RH_ACHV screenshot / RH_ACHV_TEST proof) ----------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(300):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	_toast_hold = 8.0  # hold the demo toast long enough for the RH_SHOT capture
	if not OS.get_environment("RH_ACHV_TEST").is_empty():
		_self_test(pl)
	else:
		# Fire one representative unlock so the boot shows a toast.
		notify(pl, "gold", 1500)
	# Open the Deed-Book so the screenshot catches the panel too.
	open_panel(pl)


func _self_test(pl: Node) -> void:
	print("[ACHV_TEST] ===== Raven Hollow Deed-Book self-test =====")
	print("[ACHV_TEST] deeds loaded = %d ; categories = %d" % [_defs.size(), _cats.size()])
	print("[ACHV_TEST] points possible = %d" % total_points_possible())
	print("[ACHV_TEST] points before = %d" % points())
	# 1) Counter threshold: 100 kills unlocks 'A Hundred Laid Down' (10 pts).
	var kid := "gen_hundred_slain"
	print("[ACHV_TEST] notify kills x100 (target %d)..." % threshold(kid))
	notify(pl, "kills", 100)
	print("[ACHV_TEST]   %s unlocked = %s ; progress = %d/%d" % [
			kid, str(is_unlocked(kid)), progress(pl, kid), threshold(kid)])
	# 2) Gauge threshold: gold 1500 unlocks 'The Purse Survives' (10 pts).
	var gid := "gen_purse_survives"
	notify(pl, "gold", 1500)
	print("[ACHV_TEST]   %s unlocked = %s (held 1500 gold)" % [gid, str(is_unlocked(gid))])
	# 3) Distinct set: five zone keys unlock 'First Footfalls' (5 pts).
	var zid := "expl_first_footfalls"
	for z: String in ["blestem", "sangeroasa", "greyhollow", "iron_vein", "town"]:
		notify(pl, "zones_visited", z)
	print("[ACHV_TEST]   %s unlocked = %s ; distinct zones = %d/%d" % [
			zid, str(is_unlocked(zid)), progress(pl, zid), threshold(zid)])
	print("[ACHV_TEST] points after = %d (delta +%d)" % [points(), points() - 0])
	print("[ACHV_TEST] ===== self-test complete =====")


# --- helpers ----------------------------------------------------------------

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _pname(actor: Node) -> String:
	# No dedicated display name exists yet; use the class as the earner's identity.
	return _pclass(actor).capitalize()


func _pclass(actor: Node) -> String:
	if actor == null:
		return "wanderer"
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary:
		return str((cd as Dictionary).get("id", "wanderer"))
	return "wanderer"


func _cat_name(cat: String) -> String:
	for c_v: Variant in _cats:
		var c: Dictionary = _dict(c_v)
		if str(c.get("id", "")) == cat:
			return str(c.get("name", cat))
	return cat


func _today() -> String:
	return Time.get_date_string_from_system()


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _has(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("AchievementSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
