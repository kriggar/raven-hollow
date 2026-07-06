extends Node
## SecretSystem -- autoload (/root/SecretSystem). Build #69 "Cow-level-style SECRET".
##
## A lore-accurate, tasteful twist on Diablo 2's Secret Cow Level. Instead of
## cubing Wirt's Leg + a Tome of Town Portal, the player COMBINES specific relics
## at a specific SHRINE to tear a "discrepancy" in the Bloodstone's ledger and open
## a hidden pocket zone (design canon: the Bloodstone erases the world by making a
## perfect record; a thing it cannot file rips a seam). Three secrets ship in
## data/secrets.json -- the primary Unfiled Field (the cow-level analog: a farmable
## fold of grave-shells the famine erased), the Threadbare Fold, and the Collector's
## Office easter-egg.
##
## Every write is guarded and additive: no other system's file is edited. Inventory
## and LootSystem are READ/called through get_node_or_null with method guards; the
## discovery toast is built entirely in code as a self-instanced CanvasLayer child,
## so this boots and self-tests with no world, no player, and no sibling systems.
##
## Public API (actor = the player node, group "player"; optional):
##   try_ritual(items, shrine_id := "") -> Dictionary
##       items may be an Array of item-id Strings OR bag-item Dictionaries. Matches
##       the combination against every secret whose shrine is `shrine_id` (or any
##       secret when shrine_id is ""), on the first fully-satisfied ritual: marks it
##       discovered, grants the reward (LootSystem if present, else the fallback),
##       emits secret_unlocked, shows the discovery toast. Returns
##       {ok, secret, zone, reason, reward, already}.
##   try_ritual_from_inventory(actor, shrine_id := "") -> Dictionary
##       Same, reading the actor's bag ids through InventorySystem (guarded).
##   ritual_items(secret_id) -> Array        the relic ids a secret's ritual needs
##   secret_def(secret_id) -> Dictionary ; all_secrets() -> Dictionary
##   shrine_def(shrine_id) -> Dictionary
##   secrets_at(shrine_id) -> Array          secret ids performed at a shrine
##   is_discovered(secret_id) -> bool ; discovered_list() -> Array ; secret_count() -> int
##   grant_reward(secret_id, actor := null) -> Dictionary   (guarded LootSystem/fallback)
## Signals:
##   secret_unlocked(secret_id, zone_id)     a hidden zone/portal has been torn open
##   ritual_attempted(shrine_id, ok, secret_id)

signal secret_unlocked(secret_id, zone_id)
signal ritual_attempted(shrine_id, ok, secret_id)

const DATA_PATH := "res://data/secrets.json"

var _secrets: Dictionary = {}          # secret_id -> def dict
var _shrines: Dictionary = {}          # shrine_id -> def dict
var _by_shrine: Dictionary = {}        # shrine_id -> Array[secret_id]  (registered triggers)
var _discovered: Dictionary = {}       # secret_id -> true

var _toast: CanvasLayer = null         # self-instanced discovery toast (lazy)


func _ready() -> void:
	_load_data()
	_register_triggers()
	# Env self-test fires once autoloads are all up (LootSystem may load after us).
	if not OS.get_environment("RH_SECRET_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_secrets = _dict(root.get("secrets", {}))
	_shrines = _dict(root.get("shrines", {}))
	if _secrets.is_empty():
		push_warning("SecretSystem: no secrets loaded from %s" % DATA_PATH)


## Build the shrine -> secrets lookup so a world shrine-interaction hook (guarded,
## external) can resolve which rituals a given shrine can perform.
func _register_triggers() -> void:
	_by_shrine.clear()
	for sid: String in _secrets.keys():
		var shrine: String = str(_dict(_secrets[sid]).get("shrine", ""))
		if shrine == "":
			continue
		if not _by_shrine.has(shrine):
			_by_shrine[shrine] = []
		(_by_shrine[shrine] as Array).append(sid)


# --- Data queries -----------------------------------------------------------

func all_secrets() -> Dictionary:
	return _secrets


func secret_def(secret_id: String) -> Dictionary:
	return _dict(_secrets.get(secret_id, {}))


func shrine_def(shrine_id: String) -> Dictionary:
	return _dict(_shrines.get(shrine_id, {}))


func secret_count() -> int:
	return _secrets.size()


func secrets_at(shrine_id: String) -> Array:
	return (_arr(_by_shrine.get(shrine_id, [])) as Array).duplicate()


## The relic ids a secret's ritual requires.
func ritual_items(secret_id: String) -> Array:
	return _arr(_dict(secret_def(secret_id).get("ritual", {})).get("items", [])).duplicate()


func is_discovered(secret_id: String) -> bool:
	return bool(_discovered.get(secret_id, false))


func discovered_list() -> Array:
	return _discovered.keys()


# --- The ritual (the cow-level combine) -------------------------------------

## Attempt a ritual with an explicit set of `items` (ids or bag dicts) at an
## optional shrine. Returns the verdict; on success also fires signals + reward.
func try_ritual(items: Variant, shrine_id: String = "") -> Dictionary:
	var have: Dictionary = _count_ids(items)          # id -> count present
	var candidates: Array
	if shrine_id != "":
		candidates = secrets_at(shrine_id)
	else:
		candidates = _secrets.keys()
	var matched: String = ""
	for sid: Variant in candidates:
		if _ritual_satisfied(str(sid), have):
			matched = str(sid)
			break
	if matched == "":
		ritual_attempted.emit(shrine_id, false, "")
		return {"ok": false, "secret": "", "zone": "", "reason": "no matching ritual", "reward": {}}

	var sdef: Dictionary = secret_def(matched)
	var zone: String = str(sdef.get("hidden_zone", ""))
	var already: bool = is_discovered(matched)
	_discovered[matched] = true
	# Reward + portal on success (re-grantable: a farmable secret can be rolled again).
	var reward: Dictionary = grant_reward(matched, null)
	_show_toast(sdef)
	secret_unlocked.emit(matched, zone)
	ritual_attempted.emit(shrine_id, true, matched)
	return {"ok": true, "secret": matched, "zone": zone, "reason": "",
			"reward": reward, "already": already}


## Inventory-driven ritual: read the actor's bag ids through InventorySystem
## (guarded) and attempt. Falls back to the player when actor is null.
func try_ritual_from_inventory(actor: Node = null, shrine_id: String = "") -> Dictionary:
	var a: Node = actor if actor != null else _player()
	var ids: Array = _bag_ids(a)
	return try_ritual(ids, shrine_id)


## True when every relic a secret's ritual needs is present in `have` (id->count).
func _ritual_satisfied(secret_id: String, have: Dictionary) -> bool:
	var need: Array = ritual_items(secret_id)
	if need.is_empty():
		return false
	var want: Dictionary = {}
	for it: Variant in need:
		var id: String = str(it)
		want[id] = int(want.get(id, 0)) + 1
	for id: Variant in want.keys():
		if int(have.get(id, 0)) < int(want[id]):
			return false
	return true


# --- Reward (guarded LootSystem, else the self-contained fallback) -----------

## Roll the secret's reward. Prefers LootSystem.roll_loot(reward_table) so the loot
## window shows the drop; if LootSystem is absent, builds the documented fallback
## (gold + fixed named items) so the reward path never crashes headless.
func grant_reward(secret_id: String, actor: Node = null) -> Dictionary:
	var sdef: Dictionary = secret_def(secret_id)
	if sdef.is_empty():
		return {"source": "none", "items": []}
	var table: String = str(sdef.get("reward_table", ""))
	var loot: Node = get_node_or_null("/root/LootSystem")
	if table != "" and loot != null and loot.has_method("roll_loot"):
		var rolled: Variant = loot.call("roll_loot", table, 0.0)
		if rolled is Array:
			return {"source": "loot_system", "table": table, "items": rolled}
	# Fallback: a plain, self-contained reward bundle.
	var fb: Dictionary = _dict(sdef.get("reward_fallback", {}))
	var out: Array = []
	var gold: int = int(fb.get("gold", 0))
	if gold > 0:
		out.append({"id": "gold", "name": "%d Coins" % gold, "is_currency": true, "quantity": gold})
	for iid: Variant in _arr(fb.get("items", [])):
		out.append({"id": str(iid), "name": str(iid).capitalize(), "rarity": "rare"})
	return {"source": "fallback", "items": out}


# --- Discovery toast (self-instanced CanvasLayer, no assets) -----------------

func _show_toast(sdef: Dictionary) -> void:
	# Never touches the world; fails silently if there is no scene tree yet.
	if not is_inside_tree():
		return
	var disc: Dictionary = _dict(sdef.get("discovery", {}))
	_ensure_toast()
	if _toast == null:
		return
	var title: Label = _toast.get_node_or_null("Panel/VBox/Title") as Label
	var line: Label = _toast.get_node_or_null("Panel/VBox/Line") as Label
	var sub: Label = _toast.get_node_or_null("Panel/VBox/Sub") as Label
	if title != null:
		title.text = str(disc.get("title", "A Discrepancy Opens"))
	if line != null:
		line.text = str(disc.get("line", ""))
	if sub != null:
		sub.text = str(disc.get("subtitle", ""))
	_toast.visible = true
	var panel: Control = _toast.get_node_or_null("Panel") as Control
	if panel != null:
		panel.modulate = Color(1, 1, 1, 0)
		var tw: Tween = create_tween()
		tw.tween_property(panel, "modulate:a", 1.0, 0.35)
		tw.tween_interval(4.2)
		tw.tween_property(panel, "modulate:a", 0.0, 0.6)
		tw.tween_callback(func() -> void:
			if _toast != null and is_instance_valid(_toast):
				_toast.visible = false)


func _ensure_toast() -> void:
	if _toast != null and is_instance_valid(_toast):
		return
	var layer := CanvasLayer.new()
	layer.name = "SecretToast"
	layer.layer = 96
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-190, 40)
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.92)
	sb.border_color = Color(0.72, 0.16, 0.20, 0.95)   # bloodstone red
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_color_override("font_color", Color(0.90, 0.30, 0.32))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var line := Label.new()
	line.name = "Line"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", Color(0.86, 0.84, 0.82))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(line)
	var sub := Label.new()
	sub.name = "Sub"
	sub.add_theme_color_override("font_color", Color(0.82, 0.70, 0.36))
	sub.add_theme_font_size_override("font_size", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	panel.add_child(vbox)
	layer.add_child(panel)
	layer.visible = false
	add_child(layer)
	_toast = layer


# --- helpers ----------------------------------------------------------------

## Normalize an items payload (Array of ids or bag dicts) into an id->count map.
func _count_ids(items: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (items is Array):
		return out
	for it: Variant in (items as Array):
		var id: String = ""
		if it is String:
			id = it
		elif it is Dictionary:
			id = str((it as Dictionary).get("id", ""))
		if id != "":
			out[id] = int(out.get(id, 0)) + 1
	return out


func _bag_ids(actor: Node) -> Array:
	var out: Array = []
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or actor == null or not inv.has_method("list_items"):
		return out
	var lst: Variant = inv.call("list_items", actor)
	if lst is Array:
		for it: Variant in (lst as Array):
			if it is Dictionary:
				out.append(str((it as Dictionary).get("id", "")))
	return out


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("SecretSystem: missing data file '%s'" % path)
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
	return {"discovered": _discovered.keys()}


func deserialize(d: Dictionary) -> void:
	for sid_v: Variant in _arr(d.get("discovered", [])):
		var sid: String = str(sid_v)
		if _secrets.has(sid):
			_discovered[sid] = true


# --- Env self-test (RH_SECRET_TEST=1) ---------------------------------------

func _run_selftest() -> void:
	var ok: bool = true

	# 1) A WRONG ritual must NOT unlock anything.
	var wrong: Dictionary = try_ritual(["wolf_pelt_mat", "iron_scrap_mat"], "")
	if bool(wrong.get("ok", false)):
		ok = false
	var unlocked_after_wrong: int = _discovered.size()
	if unlocked_after_wrong != 0:
		ok = false

	# 2) The CORRECT combo must unlock + return a reward path. Use the primary
	#    cow-level secret's own ritual items at its shrine (also prove shrine gating).
	var target := "unfiled_field"
	var need: Array = ritual_items(target)
	var shrine: String = str(secret_def(target).get("shrine", ""))
	var got_signal: Array = [false, ""]
	var cb := func(sid: String, _zone: String) -> void:
		got_signal[0] = true
		got_signal[1] = sid
	if not is_connected("secret_unlocked", cb):
		connect("secret_unlocked", cb)
	var right: Dictionary = try_ritual(need, shrine)
	if is_connected("secret_unlocked", cb):
		disconnect("secret_unlocked", cb)
	var reward: Dictionary = _dict(right.get("reward", {}))
	var reward_ok: bool = _arr(reward.get("items", [])).size() > 0 or str(reward.get("source", "")) != ""
	if not bool(right.get("ok", false)):
		ok = false
	if str(right.get("secret", "")) != target:
		ok = false
	if not bool(got_signal[0]) or str(got_signal[1]) != target:
		ok = false
	if not is_discovered(target):
		ok = false
	if not reward_ok:
		ok = false

	# 3) Wrong shrine must NOT unlock (right items, mismatched shrine gate).
	var mis: Dictionary = try_ritual(ritual_items("threadbare_fold"), shrine)
	if bool(mis.get("ok", false)):
		ok = false

	# 4) loot_tables.json must still parse after the scarcity tuning pass (#73).
	var loot_ok: bool = _loot_tables_ok()
	if not loot_ok:
		ok = false

	print("SECRET SELFTEST %s secrets=%d loot_ok=%s" % [
			("PASS" if ok else "FAIL"), secret_count(), str(loot_ok)])


func _loot_tables_ok() -> bool:
	var path := "res://data/loot_tables.json"
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var tables: Dictionary = _dict((parsed as Dictionary).get("tables", {}))
	# The secret reward tables must resolve for grant_reward's LootSystem path.
	return tables.has("secret_unfiled_field") and tables.has("trash_b1")
