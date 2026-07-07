extends Node
## SmartNPCSystem -- autoload (/root/SmartNPCSystem). Build #40 "smart NPCs".
## The town-that-breathes layer (design/SMART_NPCS.md), implemented ADDITIVELY
## on top of the shipped npc.gd without editing it:
##   * daily SCHEDULES (data/npc_schedules.json) -- registered NPCs relocate
##     their activity area by the DayNight clock (their wander re-centers);
##     NPCs with no schedule keep their shipped behavior, untouched.
##   * VENDORS (data/vendors.json) -- typed shops with buy/sell over the
##     player's Inventory + gold; a shop UI in scenes/ui/shop.tscn.
##   * REACTIONS -- NPCs greet the player nearby and cry out when combat is
##     close, as short floating barks (no npc.gd change; guarded per-instance).
##
## Public API:
##   register_npc(npc_or_id, schedule := {})    add/refresh a schedule
##   has_schedule(npc_id) -> bool
##   get_activity(npc_id, hour) -> String       activity at a given game-hour
##   current_activity(npc_id) -> String         activity right now
##   is_vendor(npc_id) -> bool / vendor_def(npc_id) -> Dictionary
##   is_open(npc_id) -> bool                     within the vendor's hours
##   open_shop(vendor_id, actor := null)         show the shop UI
##   buy(vendor_id, stock_idx, actor) -> Dictionary
##   sell(bag_idx, actor) -> Dictionary
## Signals: npc_registered, block_changed(npc_id, activity), npc_reacted(npc_id,
##   kind), shop_opened(vendor_id), shop_closed(vendor_id), transaction(...).

signal npc_registered(npc_id)
signal block_changed(npc_id, activity)
signal npc_reacted(npc_id, kind)
signal shop_opened(vendor_id)
signal shop_closed(vendor_id)
signal transaction(vendor_id, kind, item_id, gold)

const SCHEDULES_PATH := "res://data/npc_schedules.json"
const VENDORS_PATH := "res://data/vendors.json"
const SHOP_SCENE := "res://scenes/ui/shop.tscn"

const TICK_S := 0.5
const GREET_RANGE := 60.0
const COMBAT_RANGE := 150.0
const GREET_CD := 18.0
const COMBAT_CD := 6.0

const GREET_LINES := [
	"Good day to you.", "Well met, traveler.", "Mind how you go.",
	"Saints keep you.", "You again -- welcome.",
]
const COMBAT_LINES := [
	"Trouble!", "Get inside!", "To arms!", "Saints preserve us!", "Run!",
]

var _schedules: Dictionary = {}    # npc_id -> {blocks: Array}
var _vendors: Dictionary = {}      # npc_id -> vendor def
var _sell_prices: Dictionary = {}  # rarity -> gold

## Registered NPCs: npc_id -> {node: Node, base_home: Vector2, cur_block: int}.
var _reg: Dictionary = {}
## Reaction cooldowns keyed by node instance id -> {greet: float, combat: float}.
var _react_cd: Dictionary = {}

var _shop_ui: Node = null
var _accum: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_data()
	set_process(true)
	call_deferred("_boot_hooks")


func _load_data() -> void:
	var sched: Dictionary = _read_json(SCHEDULES_PATH)
	_schedules = _dict(sched.get("schedules", {}))
	var vend: Dictionary = _read_json(VENDORS_PATH)
	_vendors = _dict(vend.get("vendors", {}))
	_sell_prices = _dict(vend.get("sell_prices", {}))
	if _schedules.is_empty() and _vendors.is_empty():
		push_warning("SmartNPCSystem: no schedule/vendor data loaded")


func _boot_hooks() -> void:
	# Wait for the town cast, then env self-test / screenshot hooks.
	for _i in range(240):
		if not get_tree().get_nodes_in_group("npcs").is_empty():
			break
		await get_tree().process_frame
	if not OS.get_environment("RH_NPC_TEST").is_empty():
		_self_test()
	if not OS.get_environment("RH_SHOP").is_empty():
		# Give the player some coin so the buy path is exercisable in the shot.
		var pl: Node = _player()
		if pl != null and _has_prop(pl, "gold"):
			pl.set("gold", maxi(int(pl.get("gold")), 200))
		open_shop(OS.get_environment("RH_SHOP") if _vendors.has(OS.get_environment("RH_SHOP")) else "blacksmith", pl)


# --- Schedules --------------------------------------------------------------

## Register an NPC (node or id string). A node captures its spawn home so the
## schedule offsets are relative. An explicit `schedule` dict overrides the
## data file for this id (blocks: [{from,to,activity,dx,dy,radius}]).
func register_npc(npc_or_id: Variant, schedule: Dictionary = {}) -> void:
	var id: String = ""
	var node: Node = null
	if npc_or_id is Node:
		node = npc_or_id
		id = str((node as Node).name)
	else:
		id = str(npc_or_id)
		node = _npc_node(id)
	if id == "":
		return
	if not schedule.is_empty():
		_schedules[id] = schedule
	var base: Vector2 = Vector2.ZERO
	if node != null:
		var h: Variant = node.get("_home")
		base = h if h is Vector2 else (node as Node2D).global_position
	_reg[id] = {"node": node, "base_home": base, "cur_block": -1}
	npc_registered.emit(id)


func has_schedule(npc_id: String) -> bool:
	return _schedules.has(npc_id)


## The activity string for `npc_id` at game-hour `hour` (0..24), "" if none.
func get_activity(npc_id: String, hour: float) -> String:
	var blocks: Array = _arr(_dict(_schedules.get(npc_id, {})).get("blocks", []))
	var b: Dictionary = _block_at(blocks, hour)
	return str(b.get("activity", "")) if not b.is_empty() else ""


func current_activity(npc_id: String) -> String:
	return get_activity(npc_id, _now_hour())


func _block_at(blocks: Array, hour: float) -> Dictionary:
	for b_v: Variant in blocks:
		var b: Dictionary = _dict(b_v)
		var f: float = float(b.get("from", 0.0))
		var t: float = float(b.get("to", 24.0))
		if f <= t:
			if hour >= f and hour < t:
				return b
		else:  # wrap past midnight (e.g. 23 -> 6)
			if hour >= f or hour < t:
				return b
	return {}


func _block_index(blocks: Array, hour: float) -> int:
	for i in range(blocks.size()):
		var b: Dictionary = _dict(blocks[i])
		var f: float = float(b.get("from", 0.0))
		var t: float = float(b.get("to", 24.0))
		if f <= t:
			if hour >= f and hour < t:
				return i
		elif hour >= f or hour < t:
			return i
	return -1


# --- Vendors ----------------------------------------------------------------

func is_vendor(npc_id: String) -> bool:
	return _vendors.has(npc_id)


func vendor_def(npc_id: String) -> Dictionary:
	return _dict(_vendors.get(npc_id, {}))


func is_open(npc_id: String) -> bool:
	var v: Dictionary = vendor_def(npc_id)
	if v.is_empty():
		return false
	var f: float = float(v.get("open_from", 0.0))
	var t: float = float(v.get("open_to", 24.0))
	var h: float = _now_hour()
	if f <= t:
		return h >= f and h < t
	return h >= f or h < t


## Live stock for a vendor: Array of {item: Dictionary, price: int}. Prices are
## final; the UI renders them straight.
func stock_for(vendor_id: String) -> Array:
	var out: Array = []
	var v: Dictionary = vendor_def(vendor_id)
	for entry_v: Variant in _arr(v.get("stock", [])):
		var entry: Dictionary = _dict(entry_v)
		var item: Dictionary = _resolve_item(str(entry.get("id", "")))
		if item.is_empty():
			continue
		out.append({"item": item, "price": int(entry.get("price", 1))})
	return out


func sell_price(item: Dictionary) -> int:
	var v: Variant = item.get("value")
	if v is int or v is float:
		return maxi(1, int(v))
	return maxi(1, int(_sell_prices.get(str(item.get("rarity", "common")), 3)))


## Buy stock index `idx` from `vendor_id` for `actor`. Deducts gold, adds item.
## The faction a vendor answers to (for reputation discounts). Reads the vendor
## def's "faction", defaulting to the town hearth faction that quests build rep
## with. "" disables discounts for that vendor.
func vendor_faction(vendor_id: String) -> String:
	var def: Dictionary = _dict(_vendors.get(vendor_id, {}))
	return str(def.get("faction", "border_hearths"))


## The price `actor` actually pays for stock row `idx`, after the vendor's
## reputation discount (FactionSystem.vendor_discount). Shop UI calls this too so
## the shown price matches what buy() charges.
func price_for(vendor_id: String, idx: int, actor: Node) -> int:
	var stock: Array = stock_for(vendor_id)
	if idx < 0 or idx >= stock.size():
		return 0
	var base: int = int((stock[idx] as Dictionary).get("price", 0))
	var fac: String = vendor_faction(vendor_id)
	var fs: Node = get_node_or_null("/root/FactionSystem")
	if fac.is_empty() or fs == null or not fs.has_method("vendor_discount"):
		return base
	var disc: float = clampf(float(fs.call("vendor_discount", fac, actor)), 0.0, 0.9)
	return int(round(float(base) * (1.0 - disc)))


func buy(vendor_id: String, idx: int, actor: Node) -> Dictionary:
	var stock: Array = stock_for(vendor_id)
	if idx < 0 or idx >= stock.size():
		return {"ok": false, "reason": "no such item"}
	var row: Dictionary = stock[idx]
	var price: int = price_for(vendor_id, idx, actor)
	if _gold(actor) < price:
		return {"ok": false, "reason": "not enough gold"}
	var inv: Object = _inventory(actor)
	if inv == null or not inv.has_method("add_item"):
		return {"ok": false, "reason": "no bag"}
	if inv.has_method("free_slots") and int(inv.call("free_slots")) <= 0:
		return {"ok": false, "reason": "bag full"}
	var item: Dictionary = (row["item"] as Dictionary).duplicate(true)
	if not bool(inv.call("add_item", item)):
		return {"ok": false, "reason": "bag full"}
	if _has_prop(actor, "gold"):
		actor.set("gold", _gold(actor) - price)
	transaction.emit(vendor_id, "buy", str(item.get("id", "")), price)
	return {"ok": true, "reason": "", "price": price}


## Sell the bag item at `bag_idx` back for gold.
func sell(bag_idx: int, actor: Node) -> Dictionary:
	var inv: Object = _inventory(actor)
	if inv == null:
		return {"ok": false, "reason": "no bag"}
	var bag_v: Variant = inv.get("bag")
	if not (bag_v is Array) or bag_idx < 0 or bag_idx >= (bag_v as Array).size():
		return {"ok": false, "reason": "no such slot"}
	var entry: Variant = (bag_v as Array)[bag_idx]
	if not (entry is Dictionary):
		return {"ok": false, "reason": "empty slot"}
	var item: Dictionary = entry
	var price: int = sell_price(item)
	(bag_v as Array)[bag_idx] = null
	if inv.has_signal("bag_changed"):
		inv.emit_signal("bag_changed")
	if _has_prop(actor, "gold"):
		actor.set("gold", _gold(actor) + price)
	transaction.emit("", "sell", str(item.get("id", "")), price)
	return {"ok": true, "reason": "", "price": price, "name": str(item.get("name", "item"))}


# --- Shop UI ----------------------------------------------------------------

func open_shop(vendor_id: String, actor: Node = null) -> void:
	if not is_vendor(vendor_id):
		return
	if actor == null:
		actor = _player()
	_ensure_shop_ui()
	if _shop_ui != null and _shop_ui.has_method("present"):
		_shop_ui.call("present", self, vendor_id, actor)
		shop_opened.emit(vendor_id)


func close_shop() -> void:
	if _shop_ui != null and _shop_ui.has_method("close"):
		_shop_ui.call("close")


func _ensure_shop_ui() -> void:
	if _shop_ui != null and is_instance_valid(_shop_ui):
		return
	if not ResourceLoader.exists(SHOP_SCENE):
		push_warning("SmartNPCSystem: shop scene missing (%s)" % SHOP_SCENE)
		return
	var scn: PackedScene = load(SHOP_SCENE) as PackedScene
	if scn == null:
		return
	_shop_ui = scn.instantiate()
	add_child(_shop_ui)


# --- Per-frame director tick -------------------------------------------------

func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK_S:
		return
	var dt: float = _accum
	_accum = 0.0
	_tick_schedules()
	_tick_reactions(dt)


func _tick_schedules() -> void:
	# Lazy (re)registration: any scheduled town NPC not currently bound to a
	# live node gets picked up here -- survives map changes with no wiring.
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var id: String = str(n.name)
		if not _schedules.has(id):
			continue
		if not _reg.has(id) or not is_instance_valid(_reg[id].get("node")):
			register_npc(n)
	var hour: float = _now_hour()
	for id: String in _reg.keys():
		var rec: Dictionary = _reg[id]
		var node: Node = rec.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var blocks: Array = _arr(_dict(_schedules.get(id, {})).get("blocks", []))
		var bi: int = _block_index(blocks, hour)
		if bi < 0 or bi == int(rec.get("cur_block", -1)):
			continue
		rec["cur_block"] = bi
		var b: Dictionary = _dict(blocks[bi])
		var base: Vector2 = rec.get("base_home", Vector2.ZERO)
		var target: Vector2 = base + Vector2(float(b.get("dx", 0.0)), float(b.get("dy", 0.0)))
		var radius: float = float(b.get("radius", 0.0))
		# Guarded, additive re-home: the shipped wander loop orbits the new home.
		if _has_prop(node, "_home"):
			node.set("_home", target)
		if _has_prop(node, "_base_wander_radius"):
			node.set("_base_wander_radius", radius)
		if _has_prop(node, "_wander_radius"):
			node.set("_wander_radius", radius)
		block_changed.emit(id, str(b.get("activity", "")))


func _tick_reactions(dt: float) -> void:
	var pl: Node2D = _player() as Node2D
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if not (n is Node2D):
			continue
		var npc := n as Node2D
		var iid: int = npc.get_instance_id()
		var cd: Dictionary = _react_cd.get(iid, {"greet": 0.0, "combat": 0.0})
		cd["greet"] = maxf(0.0, float(cd["greet"]) - dt)
		cd["combat"] = maxf(0.0, float(cd["combat"]) - dt)
		# Combat nearby takes priority over a greeting.
		if float(cd["combat"]) <= 0.0 and _enemy_near(npc.global_position):
			_react(npc, "combat", COMBAT_LINES[_rng.randi() % COMBAT_LINES.size()])
			cd["combat"] = COMBAT_CD
			cd["greet"] = GREET_CD
		elif float(cd["greet"]) <= 0.0 and pl != null and is_instance_valid(pl) \
				and npc.global_position.distance_to(pl.global_position) <= GREET_RANGE \
				and not _player_in_combat(pl):
			_react(npc, "greet", GREET_LINES[_rng.randi() % GREET_LINES.size()])
			cd["greet"] = GREET_CD
		_react_cd[iid] = cd


func _react(npc: Node2D, kind: String, line: String) -> void:
	npc_reacted.emit(str(npc.name), kind)
	# A short floating bark above the head; auto-frees. Combat cries flash red.
	var lbl := Label.new()
	lbl.text = line
	lbl.add_theme_font_override("font", load("res://assets/fonts/alagard.ttf"))
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color",
			Color(0.95, 0.4, 0.3) if kind == "combat" else Color(0.9, 0.85, 0.65))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size = Vector2(120.0, 12.0)
	lbl.position = Vector2(-60.0, -58.0)
	lbl.z_index = 4
	npc.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", -70.0, 1.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.6).set_delay(0.8)
	tw.tween_callback(lbl.queue_free)


func _enemy_near(pos: Vector2) -> bool:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if bool(e.get("is_dead")):
			continue
		if (e as Node2D).global_position.distance_to(pos) <= COMBAT_RANGE:
			return true
	return false


func _player_in_combat(pl: Node) -> bool:
	var t: Variant = pl.get("_ooc_timer")
	return (t is float or t is int) and float(t) < 2.0


# --- Input: B = barter with the nearest vendor ------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_B:
		return
	if _panel_blocking():
		return
	var pl: Node2D = _player() as Node2D
	if pl == null:
		return
	var vid: String = _nearest_vendor(pl.global_position, 48.0)
	if vid == "":
		return
	get_viewport().set_input_as_handled()
	open_shop(vid, pl)


func _nearest_vendor(pos: Vector2, radius: float) -> String:
	var best: String = ""
	var best_d: float = radius
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if not (n is Node2D) or not is_vendor(str(n.name)):
			continue
		var d: float = (n as Node2D).global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = str(n.name)
	return best


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "mounts_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Self-test (RH_NPC_TEST) ------------------------------------------------

func _self_test() -> void:
	print("[NPC_TEST] ===== Raven Hollow smart-NPC self-test =====")
	# Register a live town NPC and prove day vs night activity resolution.
	var target_id := "blacksmith"
	var node: Node = _npc_node(target_id)
	register_npc(node if node != null else target_id)
	print("[NPC_TEST] registered '%s' (schedule=%s, live_node=%s)" % [
		target_id, str(has_schedule(target_id)), str(node != null)])
	print("[NPC_TEST]   activity @ 08:00 (day)   = '%s'" % get_activity(target_id, 8.0))
	print("[NPC_TEST]   activity @ 20:00 (eve)   = '%s'" % get_activity(target_id, 20.0))
	print("[NPC_TEST]   activity @ 02:00 (night) = '%s'" % get_activity(target_id, 2.0))
	print("[NPC_TEST] farmer   @ 06:00 = '%s' | @ 23:00 = '%s'" % [
		get_activity("farmer", 6.0), get_activity("farmer", 23.0)])
	print("[NPC_TEST] gravekeeper @ 12:00 = '%s' | @ 22:00 = '%s'" % [
		get_activity("gravekeeper", 12.0), get_activity("gravekeeper", 22.0)])
	# Vendor proof.
	print("[NPC_TEST] vendors: blacksmith=%s merchant=%s innkeeper=%s" % [
		str(is_vendor("blacksmith")), str(is_vendor("merchant")), str(is_vendor("innkeeper"))])
	var stock: Array = stock_for("blacksmith")
	var names: Array = []
	for row_v: Variant in stock:
		names.append("%s(%dg)" % [str((row_v["item"] as Dictionary).get("name", "?")), int(row_v["price"])])
	print("[NPC_TEST] blacksmith stock: %s" % str(names))
	print("[NPC_TEST] ===== self-test complete =====")


# --- helpers ----------------------------------------------------------------

func _resolve_item(id: String) -> Dictionary:
	if id == "":
		return {}
	# LootSystem base ids first (full item dict + icon), then Items DB.
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_method("roll_item"):
		var it: Variant = ls.call("roll_item", id, "")
		if it is Dictionary and not (it as Dictionary).is_empty():
			return it
	var it2: Dictionary = Items.get_item(id)
	return it2 if not it2.is_empty() else {}


func _now_hour() -> float:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null:
		var t: Variant = dn.get("time_of_day")
		if t is float or t is int:
			return float(t)
	return 12.0


func _npc_node(id: String) -> Node:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if str(n.name) == id:
			return n
	return null


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _inventory(actor: Node) -> Object:
	if actor == null:
		return null
	var inv: Variant = actor.get("inventory")
	return inv if inv is Object else null


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
		push_warning("SmartNPCSystem: missing data file '%s'" % path)
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
	# Blocks derive from the clock; only registration ids need persisting.
	return {"registered": _reg.keys()}


func deserialize(_d: Dictionary) -> void:
	pass
