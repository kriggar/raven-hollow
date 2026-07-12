extends Node
## TitleSystem -- autoload (/root/TitleSystem). Build #46 "the second name you earned".
## The titles ledger (design/PVP_RANKS_TITLES.md 10): earnable names shown before
## (prefix) or after (suffix) the player's name -- "Fog-Sergeant Kriggar", "Kriggar,
## the Untithed". The registry loads from data/titles.json (PvP rank + PvP feats +
## raid + event + hidden-debuff survivor + conduct + faction-exalted + reserved
## legendary rows). Titles are permanent once earned; one is active at a time.
##
## Titles are earned by listening to the systems that already exist -- ALL GUARDED,
## so a missing source is simply a title that never lands:
##   * PvPSystem.rank_changed(n)          -> grants the rank_NN title (and wears it
##                                           if you had none).
##   * AchievementSystem.achievement_unlocked(id) -> if that deed's reward carries a
##                                           title (data/achievements.json reward.title),
##                                           it is resolved by id or display-name and granted.
##   * FactionSystem.tier_changed(...exalted) -> grants the faction's Exalted title.
## PvPSystem also calls grant_title() directly for its feat titles (Bloodletter, etc.).
##
## Additive + null-safe: no other system's file is edited (they are only READ /
## connected-to). A gold-bezel TOAST fires on each earn; a TITLE PICKER
## (scenes/ui/titles.tscn) is self-instanced here and toggled with 'T'.
##
## Public API (actor = the player node, group "player"):
##   grant_title(actor, id) -> bool         idempotent earn; fires title_earned + toast
##   set_active(actor, id) -> void           "" = none; only owned ids stick
##   owned_titles(actor) -> Array            earned title ids (authored order)
##   active_title(actor) -> String           active title id ("" if none)
##   display_name(actor, base) -> String     applies the active prefix/suffix to a name
##   is_owned(actor, id) -> bool / title_def(id) / title_name(id) / all_titles()
##   titles_in(cat) -> Array / categories() / open_picker(actor) / close_picker()
## Signals:
##   title_earned(id)

signal title_earned(id)

const DATA_PATH := "res://data/titles.json"
const PANEL_SCENE := "res://scenes/ui/titles.tscn"

var _titles: Dictionary = {}          # id -> def {name,pos,cat,hidden,desc}
var _order: Array = []                # ids in authored order
var _name_to_id: Dictionary = {}      # display name -> id (achievement reward resolve)
var _faction_exalted: Dictionary = {} # faction_id -> title id

## Per-actor state, keyed by instance id: {known: Array, active: String}.
var _actors: Dictionary = {}

var _panel: Node = null
var _toast_layer: CanvasLayer = null
var _toast_banner: Control = null
var _toast_name: Label = null
var _toast_sub: Label = null
var _toast_q: Array = []
var _toasting: bool = false
var _toast_hold: float = 3.0

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.62, 0.57, 0.49)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.10, 0.08, 0.06, 0.97)

const CAT_ORDER := ["pvp_rank", "pvp_feat", "raid", "event", "survivor", "conduct", "faction", "legendary"]
const CAT_NAMES := {
	"pvp_rank": "Accord Roll", "pvp_feat": "Arena Feats", "raid": "Raid",
	"event": "Festivals", "survivor": "Survivor", "conduct": "Conduct",
	"faction": "Faction", "legendary": "Legendary",
}


func _ready() -> void:
	add_to_group("titles")
	_load_data()
	_build_toast()
	call_deferred("_wire_systems")
	if not OS.get_environment("RH_TITLES").is_empty() \
			or not OS.get_environment("RH_TITLE_TEST").is_empty() \
			or _shot_wants_titles():
		call_deferred("_run_env_hooks")


func _shot_wants_titles() -> bool:
	var shot: String = OS.get_environment("RH_SHOT").to_lower()
	return shot.find("title") >= 0 or shot.find("pvp") >= 0


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_titles = _dict(root.get("titles", {}))
	_faction_exalted = _dict(root.get("faction_exalted", {}))
	_order = _titles.keys()
	_name_to_id.clear()
	for id: String in _order:
		var nm: String = str(_dict(_titles[id]).get("name", ""))
		if nm != "":
			_name_to_id[nm] = id
	if _titles.is_empty():
		push_warning("TitleSystem: no titles loaded from %s" % DATA_PATH)


# --- Data helpers -----------------------------------------------------------

func all_titles() -> Dictionary:
	return _titles


func title_def(id: String) -> Dictionary:
	return _dict(_titles.get(id, {}))


func title_name(id: String) -> String:
	return str(title_def(id).get("name", id))


func title_count() -> int:
	return _titles.size()


func categories() -> Array:
	return CAT_ORDER.duplicate()


func category_name(cat: String) -> String:
	return str(CAT_NAMES.get(cat, cat.capitalize()))


func titles_in(cat: String) -> Array:
	var out: Array = []
	for id: String in _order:
		if str(_dict(_titles[id]).get("cat", "")) == cat:
			out.append(id)
	return out


# --- Earn / activate --------------------------------------------------------

## The only earn path. Idempotent. Fires title_earned + a toast, and wears the
## title automatically if the actor had no active title (so it shows at once).
func grant_title(actor: Node, id: String) -> bool:
	if id == "":
		return false
	# Resolve an achievement reward that arrived as a display name, not an id.
	if not _titles.has(id):
		if _name_to_id.has(id):
			id = str(_name_to_id[id])
		else:
			# Unknown title: register it dynamically so it still earns + displays.
			_register_dynamic(id)
	if not _titles.has(id):
		return false
	var st: Dictionary = _state(actor)
	var known: Array = st["known"]
	if known.has(id):
		return false
	known.append(id)
	if str(st.get("active", "")) == "":
		st["active"] = id
	title_earned.emit(id)
	_enqueue_toast(id)
	return true


func set_active(actor: Node, id: String) -> void:
	var st: Dictionary = _state(actor)
	if id == "":
		st["active"] = ""
		return
	if (st["known"] as Array).has(id):
		st["active"] = id


func owned_titles(actor: Node) -> Array:
	# Return in authored order for a stable picker layout.
	var known: Array = _state(actor)["known"]
	var out: Array = []
	for id: String in _order:
		if known.has(id):
			out.append(id)
	# Include any dynamically-registered ids not in _order (defensive).
	for id_v: Variant in known:
		if not out.has(str(id_v)):
			out.append(str(id_v))
	return out


func active_title(actor: Node) -> String:
	return str(_state(actor).get("active", ""))


func is_owned(actor: Node, id: String) -> bool:
	return (_state(actor)["known"] as Array).has(id)


## Apply the actor's active title to `base` (a bare name). Prefix -> "Title Name";
## suffix -> "Name, Title".
func display_name(actor: Node, base: String) -> String:
	var id: String = active_title(actor)
	if id == "" or not _titles.has(id):
		return base
	var d: Dictionary = title_def(id)
	var nm: String = str(d.get("name", ""))
	if nm == "":
		return base
	if str(d.get("pos", "suffix")) == "prefix":
		return "%s %s" % [nm, base]
	return "%s, %s" % [base, nm]


func _register_dynamic(id: String) -> void:
	# id here is a display name string (achievement reward without a matching def).
	var key: String = id.to_lower().replace(" ", "_").replace(",", "").replace("'", "")
	if _titles.has(key):
		return
	_titles[key] = {"name": id, "pos": "suffix", "cat": "conduct", "hidden": true,
		"desc": "Earned in the field."}
	_order.append(key)
	_name_to_id[id] = key


# --- Wiring: earn from ranks / achievements / faction (all guarded) ---------

func _wire_systems() -> void:
	var pvp: Node = get_node_or_null("/root/PvPSystem")
	if pvp != null and pvp.has_signal("rank_changed"):
		var cb_rank := Callable(self, "_on_rank_changed")
		if not pvp.is_connected("rank_changed", cb_rank):
			pvp.connect("rank_changed", cb_rank)
	var achv: Node = get_node_or_null("/root/AchievementSystem")
	if achv != null and achv.has_signal("achievement_unlocked"):
		var cb_achv := Callable(self, "_on_achievement_unlocked")
		if not achv.is_connected("achievement_unlocked", cb_achv):
			achv.connect("achievement_unlocked", cb_achv)
	var fac: Node = get_node_or_null("/root/FactionSystem")
	if fac != null and fac.has_signal("tier_changed"):
		var cb_fac := Callable(self, "_on_faction_tier_changed")
		if not fac.is_connected("tier_changed", cb_fac):
			fac.connect("tier_changed", cb_fac)


func _on_rank_changed(new_rank: int) -> void:
	grant_title(_player(), "rank_%02d" % new_rank)


func _on_achievement_unlocked(id: String) -> void:
	var achv: Node = get_node_or_null("/root/AchievementSystem")
	if achv == null or not achv.has_method("def"):
		return
	var d: Dictionary = _dict(achv.call("def", id))
	var reward: Dictionary = _dict(d.get("reward", {}))
	var t: String = str(reward.get("title", ""))
	if t != "":
		grant_title(_player(), t)


func _on_faction_tier_changed(_actor: Variant, faction_id: Variant, _old: Variant, new_tier: Variant) -> void:
	if str(new_tier) != "exalted":
		return
	var tid: String = str(_faction_exalted.get(str(faction_id), ""))
	if tid != "":
		grant_title(_player(), tid)


# --- Toast (gold-bezel, slides down from the top) ---------------------------

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "TitleToast"
	_toast_layer.layer = 26
	add_child(_toast_layer)

	_toast_banner = Control.new()
	_toast_banner.custom_minimum_size = Vector2(268, 46)
	_toast_banner.size = Vector2(268, 46)
	_toast_banner.position = Vector2((640.0 - 268.0) * 0.5, _hidden_y())
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

	var head := _mk_label("TITLE EARNED", 8, GOLD)
	head.position = Vector2(12, 6)
	head.size = Vector2(244, 11)
	_toast_banner.add_child(head)

	_toast_name = _mk_label("", 13, GOLD_BRIGHT)
	_toast_name.position = Vector2(12, 17)
	_toast_name.size = Vector2(244, 16)
	_toast_banner.add_child(_toast_name)

	_toast_sub = _mk_label("", 8, PARCHMENT)
	_toast_sub.position = Vector2(12, 33)
	_toast_sub.size = Vector2(244, 11)
	_toast_banner.add_child(_toast_sub)


func _enqueue_toast(id: String) -> void:
	_toast_q.append(id)
	if not _toasting:
		_next_toast()


func _next_toast() -> void:
	if _toast_q.is_empty():
		_toasting = false
		return
	# NO-OVERLAP LAW: hold the toast while big panels are up; retry shortly.
	if is_picker_open() or _any_panel_open():
		get_tree().create_timer(2.0).timeout.connect(_next_toast, CONNECT_ONE_SHOT)
		return
	_toasting = true
	var id: String = str(_toast_q.pop_front())
	var d: Dictionary = title_def(id)
	_toast_name.text = str(d.get("name", "Title"))
	_toast_sub.text = category_name(str(d.get("cat", "")))
	_toast_banner.position.y = _hidden_y()
	_toast_banner.visible = true
	var tw := create_tween()
	tw.tween_property(_toast_banner, "position:y", 288.0, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_toast_hold)
	tw.tween_property(_toast_banner, "position:y", _hidden_y(), 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next_toast)


func _any_panel_open() -> bool:
	var pvp: Node = get_node_or_null("/root/PvPSystem")
	if pvp != null and pvp.has_method("is_panel_open") and bool(pvp.call("is_panel_open")):
		return true
	for grp: String in ["bag_ui", "sheet_ui", "quest_ui", "achievements_ui", "reputation_ui"]:
		for n: Node in get_tree().get_nodes_in_group(grp):
			var vis: Variant = n.get("is_open")
			if vis != null and bool(vis):
				return true
	return false


func _hidden_y() -> float:
	# below the viewport; the toast rises to sit above the hotbar (panels
	# live top/center — the old top slide covered their headers)
	return 370.0


# --- Picker UI --------------------------------------------------------------

func is_picker_open() -> bool:
	return _panel != null and is_instance_valid(_panel) and bool(_panel.get("is_open"))


func open_picker(actor: Node = null, side: String = "center") -> void:
	# Never sit on the PvP panel: if the Accord Roll is open, split the screen.
	if side == "center":
		var pvp: Node = get_node_or_null("/root/PvPSystem")
		if pvp != null and pvp.has_method("is_panel_open") and bool(pvp.call("is_panel_open")):
			side = "right"
			pvp.call("open_panel", actor, "left")
	if actor == null:
		actor = _player()
	_ensure_panel()
	if _panel != null and _panel.has_method("present"):
		_panel.call("present", self, actor, side)


func close_picker() -> void:
	if _panel != null and _panel.has_method("close"):
		_panel.call("close")


func toggle_picker() -> void:
	_ensure_panel()
	if _panel == null:
		return
	if bool(_panel.get("is_open")):
		close_picker()
	else:
		open_picker(_player())


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	if not ResourceLoader.exists(PANEL_SCENE):
		push_warning("TitleSystem: picker scene missing (%s)" % PANEL_SCENE)
		return
	var scn: PackedScene = load(PANEL_SCENE) as PackedScene
	if scn == null:
		return
	_panel = scn.instantiate()
	add_child(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_T:
		return
	if _player() == null or _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_picker()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env self-test (RH_TITLES screenshot / RH_TITLE_TEST proof) -------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(300):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	_toast_hold = 6.0
	# Seed a spread of earned titles across categories so the picker reads full.
	for tid: String in ["rank_07", "the_untithed", "pit_proven", "bloodletter",
			"pit_breaker", "of_the_four_roads", "still_walking", "emberkept",
			"exalted_accord"]:
		grant_title(pl, tid)
	set_active(pl, "rank_07")
	if not OS.get_environment("RH_TITLE_TEST").is_empty():
		_self_test(pl)
	# Open the picker on the right so it sits beside the PvP panel for the shot.
	open_picker(pl, "right")


func _self_test(pl: Node) -> void:
	print("[TITLE_TEST] ===== Raven Hollow titles self-test =====")
	print("[TITLE_TEST] titles in registry = %d" % title_count())
	# Fresh grant + activate proof.
	var base := "Kriggar"
	print("[TITLE_TEST] owned = %d ; active = '%s'" % [
		owned_titles(pl).size(), active_title(pl)])
	print("[TITLE_TEST] display (rank_07 prefix): '%s'" % display_name(pl, base))
	# Grant a suffix feat and switch to it.
	var g: bool = grant_title(pl, "the_untithed")
	print("[TITLE_TEST] grant 'the_untithed' (already owned from seed=%s) newly=%s" % [
		str(is_owned(pl, "the_untithed")), str(g)])
	set_active(pl, "the_untithed")
	print("[TITLE_TEST] active now '%s' -> display (suffix): '%s'" % [
		active_title(pl), display_name(pl, base)])
	# Grant a brand-new one and prove idempotency.
	var first: bool = grant_title(pl, "flawless")
	var again: bool = grant_title(pl, "flawless")
	print("[TITLE_TEST] grant 'flawless' first=%s again=%s (idempotent)" % [str(first), str(again)])
	# Achievement-reward resolution by display name.
	var byname: bool = grant_title(pl, "the Far-Walked")
	print("[TITLE_TEST] grant by display-name 'the Far-Walked' -> id resolved=%s owned=%s" % [
		str(byname), str(is_owned(pl, "the_far_walked"))])
	set_active(pl, "")
	print("[TITLE_TEST] cleared active -> display: '%s'" % display_name(pl, base))
	print("[TITLE_TEST] total owned = %d" % owned_titles(pl).size())
	print("[TITLE_TEST] ===== self-test complete =====")


# --- Save contract (SaveSystem group pattern; inert until wired) ------------

func serialize() -> Dictionary:
	var pl: Node = _player()
	if pl == null:
		return {}
	var st: Dictionary = _state(pl)
	return {
		"known": (st["known"] as Array).duplicate(),
		"active": str(st.get("active", "")),
	}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var st: Dictionary = _state(pl)
	var known: Array = []
	for id_v: Variant in _arr(d.get("known", [])):
		known.append(str(id_v))
	st["known"] = known
	st["active"] = str(d.get("active", ""))


# --- helpers ----------------------------------------------------------------

func _state(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _actors.has(key):
		_actors[key] = {"known": [], "active": ""}
	return _actors[key]


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


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


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("TitleSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
