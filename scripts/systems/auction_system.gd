extends Node
## AuctionSystem -- autoload (/root/AuctionSystem). Build #72 "auction house + banker".
## A materials/items auction house and a banker, sited in the capitals. The player
## lists items from their InventorySystem bag; the browse grid is populated with
## seed/AI listings (data/auction_seed.json) since there is no multiplayer, plus
## anything the player has posted. Buying deducts player gold (actor.gold) and
## files the item back into the bag. The BANK holds a per-actor gold balance and
## an item vault (deposit/withdraw gold + item storage tabs).
##
## Everything here is additive and null-safe: no other system's file is edited.
## It READS InventorySystem for bag/equip schemas and reads/writes actor.gold
## through a guarded property write (never touches player.gd). The banker/AH
## sprites + stall placement are Fable-only art; this system self-instances the
## AH and Bank UIs (scenes/ui/auction.tscn, scenes/ui/bank.tscn).
##
## Public API:
##   list_item(actor, item, price) -> Dictionary   {ok, listing_id, reason}
##   list_from_bag(actor, bag_idx, price) -> Dictionary
##   buy(actor, listing_id) -> Dictionary           {ok, reason, item, price}
##   cancel_listing(actor, listing_id) -> Dictionary
##   browse(filter="") -> Array                     seed + player listings
##   listing(listing_id) -> Dictionary / all_listings()
##   suggested_price(item) -> int
##   bank_deposit(actor, amount) -> Dictionary      {ok, balance, reason}
##   bank_withdraw(actor, amount) -> Dictionary
##   bank_balance(actor) -> int
##   bank_store_item(actor, bag_idx) -> Dictionary  bag -> vault
##   bank_take_item(actor, vault_idx) -> Dictionary vault -> bag
##   bank_items(actor) -> Array
##   open_auction(actor) / open_bank(actor) / close_all()
## Signals: listing_posted, listing_sold, listing_cancelled, bank_changed.

signal listing_posted(listing_id)
signal listing_sold(actor, listing_id)
signal listing_cancelled(listing_id)
signal bank_changed(actor)

const DATA_PATH := "res://data/auction_seed.json"
const AH_SCENE := "res://scenes/ui/auction.tscn"
const BANK_SCENE := "res://scenes/ui/bank.tscn"

var _config: Dictionary = {}
var _bank_cfg: Dictionary = {}
var _categories: Array = ["all", "weapon", "armor", "trinket", "material"]

var _listings: Array = []               # [listing dict, ...]
var _listing_by_id: Dictionary = {}     # id -> listing
var _next_id: int = 1

## Per-actor bank, keyed by instance id: {gold: int, items: Array}.
var _banks: Dictionary = {}

var _ah_ui: Node = null
var _bank_ui: Node = null


func _ready() -> void:
	_load_data()
	if not OS.get_environment("RH_AUCTION").is_empty() \
			or not OS.get_environment("RH_AH_TEST").is_empty() \
			or not OS.get_environment("RH_BANK").is_empty() \
			or not OS.get_environment("RH_BANK_TEST").is_empty() \
			or OS.get_environment("RH_SHOT").to_lower().find("auction") != -1 \
			or OS.get_environment("RH_SHOT").to_lower().find("bank") != -1:
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_config = _dict(root.get("config", {}))
	_bank_cfg = _dict(root.get("bank", {}))
	var cats: Array = _arr(_config.get("categories", []))
	if not cats.is_empty():
		_categories = cats
	_listings.clear()
	_listing_by_id.clear()
	for seed_v: Variant in _arr(root.get("seed_listings", [])):
		var s: Dictionary = _dict(seed_v)
		var item: Dictionary = _dict(s.get("item", {}))
		if item.is_empty():
			continue
		_add_listing({
			"seller": str(s.get("seller", "Trader")),
			"category": str(s.get("category", _category_of(item))),
			"item": item,
			"price": int(s.get("price", 10)),
			"qty": int(s.get("qty", 1)),
			"is_player": false,
		})
	if _listings.is_empty():
		push_warning("AuctionSystem: no seed listings loaded from %s" % DATA_PATH)


func _add_listing(data: Dictionary) -> String:
	var id: String = "L%d" % _next_id
	_next_id += 1
	data["id"] = id
	_listings.append(data)
	_listing_by_id[id] = data
	return id


# --- browse / listings ------------------------------------------------------

func all_listings() -> Array:
	return _listings


func listing(listing_id: String) -> Dictionary:
	return _dict(_listing_by_id.get(listing_id, {}))


func categories() -> Array:
	return _categories


## Filter listings. `filter` may be a category id ("weapon"/"armor"/...), a free
## search string (matched against item name/seller), "" / "all" for everything,
## or a Dictionary {category, search}.
func browse(filter: Variant = "") -> Array:
	var cat: String = "all"
	var search: String = ""
	if filter is String:
		var f: String = str(filter).strip_edges().to_lower()
		if _categories.has(f):
			cat = f
		elif f != "" and f != "all":
			search = f
	elif filter is Dictionary:
		cat = str((filter as Dictionary).get("category", "all")).to_lower()
		search = str((filter as Dictionary).get("search", "")).strip_edges().to_lower()
	var out: Array = []
	for l_v: Variant in _listings:
		var l: Dictionary = _dict(l_v)
		if int(l.get("qty", 0)) <= 0:
			continue
		if cat != "all" and cat != "" and str(l.get("category", "")) != cat:
			continue
		if search != "":
			var item: Dictionary = _dict(l.get("item", {}))
			var hay: String = (str(item.get("name", "")) + " " + str(l.get("seller", ""))).to_lower()
			if hay.find(search) == -1:
				continue
		out.append(l)
	return out


# --- selling ----------------------------------------------------------------

## Suggested buyout for an item (gear score via InventorySystem, else rarity).
func suggested_price(item: Dictionary) -> int:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("item_gear_score"):
		var gs: int = int(inv.call("item_gear_score", item))
		if gs > 0:
			return maxi(5, gs * 3)
	var rmap := {"poor": 4, "common": 8, "uncommon": 24, "rare": 80, "epic": 240, "legendary": 800}
	return int(rmap.get(str(item.get("rarity", "common")), 8))


## List an item the player holds. Removes it from the bag (if present) and posts
## a player listing. Returns {ok, listing_id, reason}.
func list_item(actor: Node, item: Dictionary, price: int) -> Dictionary:
	if actor == null or item.is_empty():
		return {"ok": false, "reason": "Nothing to list.", "listing_id": ""}
	if price <= 0:
		price = suggested_price(item)
	# Pull a matching entry out of the bag if the actor owns one.
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("get_bag") and inv.has_method("remove_item"):
		var bag: Array = inv.call("get_bag", actor)
		for i in range(bag.size()):
			if bag[i] is Dictionary and (bag[i] as Dictionary) == item:
				inv.call("remove_item", actor, i)
				break
	var id: String = _add_listing({
		"seller": _actor_name(actor),
		"category": _category_of(item),
		"item": item.duplicate(true),
		"price": price,
		"qty": 1,
		"is_player": true,
		"owner": actor.get_instance_id(),
	})
	listing_posted.emit(id)
	return {"ok": true, "reason": "", "listing_id": id}


## List the bag item at `bag_idx`. Returns {ok, listing_id, reason}.
func list_from_bag(actor: Node, bag_idx: int, price: int = -1) -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("get_bag"):
		return {"ok": false, "reason": "No inventory.", "listing_id": ""}
	var bag: Array = inv.call("get_bag", actor)
	if bag_idx < 0 or bag_idx >= bag.size() or not (bag[bag_idx] is Dictionary):
		return {"ok": false, "reason": "Empty slot.", "listing_id": ""}
	var item: Dictionary = bag[bag_idx]
	if price < 0:
		price = suggested_price(item)
	return list_item(actor, item, price)


## Reclaim an unsold player listing (item returns to the bag).
func cancel_listing(actor: Node, listing_id: String) -> Dictionary:
	var l: Dictionary = listing(listing_id)
	if l.is_empty() or not bool(l.get("is_player", false)):
		return {"ok": false, "reason": "Not your listing."}
	var item: Dictionary = _dict(l.get("item", {}))
	if not _give_item(actor, item):
		return {"ok": false, "reason": "Bag full."}
	_remove_listing(listing_id)
	listing_cancelled.emit(listing_id)
	return {"ok": true, "reason": ""}


# --- buying -----------------------------------------------------------------

## Buy one unit of a listing. Deducts gold, files the item into the bag.
func buy(actor: Node, listing_id: String) -> Dictionary:
	var l: Dictionary = listing(listing_id)
	if l.is_empty() or int(l.get("qty", 0)) <= 0:
		return {"ok": false, "reason": "That listing is gone."}
	var price: int = int(l.get("price", 0))
	var gold: int = _gold(actor)
	if gold < price:
		return {"ok": false, "reason": "Not enough gold."}
	var item: Dictionary = _dict(l.get("item", {})).duplicate(true)
	if not _give_item(actor, item):
		return {"ok": false, "reason": "Bag full."}
	_set_gold(actor, gold - price)
	l["qty"] = int(l.get("qty", 1)) - 1
	if int(l["qty"]) <= 0:
		_remove_listing(listing_id)
	listing_sold.emit(actor, listing_id)
	return {"ok": true, "reason": "", "item": item, "price": price}


func _remove_listing(listing_id: String) -> void:
	if _listing_by_id.has(listing_id):
		_listing_by_id.erase(listing_id)
	for i in range(_listings.size()):
		if str(_dict(_listings[i]).get("id", "")) == listing_id:
			_listings.remove_at(i)
			return


# --- bank -------------------------------------------------------------------

func bank_config() -> Dictionary:
	return _bank_cfg


func _bank(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _banks.has(key):
		_banks[key] = {"gold": int(_bank_cfg.get("starting_gold", 0)), "items": []}
	return _banks[key]


func bank_balance(actor: Node) -> int:
	return int(_bank(actor).get("gold", 0))


## Move gold from the actor's purse into the bank. {ok, balance, reason}.
func bank_deposit(actor: Node, amount: int) -> Dictionary:
	if actor == null or amount <= 0:
		return {"ok": false, "balance": bank_balance(actor), "reason": "Nothing to deposit."}
	var gold: int = _gold(actor)
	amount = mini(amount, gold)
	if amount <= 0:
		return {"ok": false, "balance": bank_balance(actor), "reason": "Your purse is empty."}
	var b: Dictionary = _bank(actor)
	b["gold"] = int(b["gold"]) + amount
	_set_gold(actor, gold - amount)
	bank_changed.emit(actor)
	return {"ok": true, "balance": int(b["gold"]), "reason": "", "moved": amount}


## Move gold from the bank into the actor's purse. {ok, balance, reason}.
func bank_withdraw(actor: Node, amount: int) -> Dictionary:
	if actor == null or amount <= 0:
		return {"ok": false, "balance": bank_balance(actor), "reason": "Nothing to withdraw."}
	var b: Dictionary = _bank(actor)
	amount = mini(amount, int(b["gold"]))
	if amount <= 0:
		return {"ok": false, "balance": int(b["gold"]), "reason": "The vault is empty."}
	b["gold"] = int(b["gold"]) - amount
	_set_gold(actor, _gold(actor) + amount)
	bank_changed.emit(actor)
	return {"ok": true, "balance": int(b["gold"]), "reason": "", "moved": amount}


func bank_items(actor: Node) -> Array:
	return (_bank(actor)["items"] as Array).duplicate()


## Move the bag item at `bag_idx` into the vault. {ok, reason}.
func bank_store_item(actor: Node, bag_idx: int) -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("remove_item"):
		return {"ok": false, "reason": "No inventory."}
	var slots: int = int(_bank_cfg.get("vault_slots", 40))
	var b: Dictionary = _bank(actor)
	if (b["items"] as Array).size() >= slots:
		return {"ok": false, "reason": "The vault is full."}
	var item: Dictionary = inv.call("remove_item", actor, bag_idx)
	if item.is_empty():
		return {"ok": false, "reason": "Empty slot."}
	(b["items"] as Array).append(item)
	bank_changed.emit(actor)
	return {"ok": true, "reason": ""}


## Move a vault item back into the bag. {ok, reason}.
func bank_take_item(actor: Node, vault_idx: int) -> Dictionary:
	var b: Dictionary = _bank(actor)
	var items: Array = b["items"]
	if vault_idx < 0 or vault_idx >= items.size():
		return {"ok": false, "reason": "Empty slot."}
	var item: Dictionary = _dict(items[vault_idx])
	if not _give_item(actor, item):
		return {"ok": false, "reason": "Bag full."}
	items.remove_at(vault_idx)
	bank_changed.emit(actor)
	return {"ok": true, "reason": ""}


# --- UI ---------------------------------------------------------------------

func open_auction(actor: Node = null) -> void:
	if actor == null:
		actor = _player()
	_ah_ui = _ensure_ui(_ah_ui, AH_SCENE)
	if _ah_ui != null and _ah_ui.has_method("present"):
		_ah_ui.call("present", self, actor)


func open_bank(actor: Node = null) -> void:
	if actor == null:
		actor = _player()
	_bank_ui = _ensure_ui(_bank_ui, BANK_SCENE)
	if _bank_ui != null and _bank_ui.has_method("present"):
		_bank_ui.call("present", self, actor)


func close_all() -> void:
	if _ah_ui != null and _ah_ui.has_method("close"):
		_ah_ui.call("close")
	if _bank_ui != null and _bank_ui.has_method("close"):
		_bank_ui.call("close")


func _ensure_ui(existing: Node, scene_path: String) -> Node:
	if existing != null and is_instance_valid(existing):
		return existing
	if not ResourceLoader.exists(scene_path):
		push_warning("AuctionSystem: UI scene missing (%s)" % scene_path)
		return null
	var scn: PackedScene = load(scene_path) as PackedScene
	if scn == null:
		return null
	var ui: Node = scn.instantiate()
	add_child(ui)
	return ui


# --- input (V = auction house, X = bank) ------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _panel_blocking_other():
		return
	if key.keycode == KEY_V:
		get_viewport().set_input_as_handled()
		_toggle(_ah_ui, "open_auction")
	elif key.keycode == KEY_X:
		get_viewport().set_input_as_handled()
		_toggle(_bank_ui, "open_bank")


func _toggle(ui: Node, opener: String) -> void:
	if ui != null and is_instance_valid(ui) and bool(ui.get("is_open")):
		if ui.has_method("close"):
			ui.call("close")
	else:
		call(opener, _player())


func _panel_blocking_other() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# Give the tester a purse to spend if the character booted broke.
	if _gold(pl) < 500:
		_set_gold(pl, _gold(pl) + 1000)
	# Seed a couple of bag items so the SELL column and bank vault read full.
	_seed_player_bag(pl)
	if not OS.get_environment("RH_AH_TEST").is_empty():
		_self_test_ah(pl)
	if not OS.get_environment("RH_BANK_TEST").is_empty():
		_self_test_bank(pl)
	var shot: String = OS.get_environment("RH_SHOT").to_lower()
	if not OS.get_environment("RH_BANK").is_empty() or shot.find("bank") != -1:
		open_bank(pl)
	elif not OS.get_environment("RH_AUCTION").is_empty() or shot.find("auction") != -1:
		open_auction(pl)


func _seed_player_bag(pl: Node) -> void:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("add_item"):
		return
	if inv.has_method("register"):
		inv.call("register", pl)
	for it: Dictionary in [
		{"name": "Iron Shortsword", "slot": "main_hand", "rarity": "common", "icon_hint": "rusted_shortsword", "stats": {"damage": 4}, "flavor": "Plain, honest, and sharp enough."},
		{"name": "Wolf Pelt", "mat_id": "wolf_pelt", "type": "material", "slot": "none", "rarity": "common", "icon_hint": "wolf_pelt", "flavor": "The pack howled."},
		{"name": "Copper Band", "slot": "ring", "rarity": "common", "icon_hint": "tarnished_band", "stats": {"mana": 4}, "flavor": "Green where it kisses the skin."},
	]:
		inv.call("add_item", pl, it)


func _self_test_ah(pl: Node) -> void:
	print("[AH_TEST] ===== Raven Hollow auction house self-test =====")
	print("[AH_TEST] seed listings loaded = %d" % browse("all").size())
	print("[AH_TEST] materials on offer   = %d" % browse("material").size())
	var gold0: int = _gold(pl)
	print("[AH_TEST] player gold before buy = %d" % gold0)
	var cheap: Dictionary = {}
	for l_v: Variant in browse("all"):
		var l: Dictionary = _dict(l_v)
		if cheap.is_empty() or int(l.get("price", 0)) < int(cheap.get("price", 999999)):
			cheap = l
	if not cheap.is_empty():
		var lid: String = str(cheap.get("id", ""))
		var iname: String = str(_dict(cheap.get("item", {})).get("name", "?"))
		var res: Dictionary = buy(pl, lid)
		print("[AH_TEST] bought '%s' (%s) for %dg -> ok=%s" % [
			iname, lid, int(cheap.get("price", 0)), str(res.get("ok", false))])
		print("[AH_TEST] player gold after buy  = %d  (delta %d)" % [
			_gold(pl), _gold(pl) - gold0])
	# List a player-owned bag item and confirm it appears in browse.
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("list_items"):
		var items: Array = inv.call("list_items", pl)
		if not items.is_empty():
			var it: Dictionary = _dict(items[0])
			var sp: int = suggested_price(it)
			var lr: Dictionary = list_item(pl, it, sp)
			print("[AH_TEST] listed '%s' at %dg -> id=%s (browse now %d)" % [
				str(it.get("name", "?")), sp, str(lr.get("listing_id", "")), browse("all").size()])
	print("[AH_TEST] ===== self-test complete =====")


func _self_test_bank(pl: Node) -> void:
	print("[BANK_TEST] ===== Raven Hollow bank self-test =====")
	var purse0: int = _gold(pl)
	print("[BANK_TEST] purse=%d  vault=%d" % [purse0, bank_balance(pl)])
	var d: Dictionary = bank_deposit(pl, 250)
	print("[BANK_TEST] deposit 250 -> ok=%s purse=%d vault=%d" % [
		str(d.get("ok", false)), _gold(pl), bank_balance(pl)])
	var w: Dictionary = bank_withdraw(pl, 100)
	print("[BANK_TEST] withdraw 100 -> ok=%s purse=%d vault=%d" % [
		str(w.get("ok", false)), _gold(pl), bank_balance(pl)])
	# Item vault: store the first bag item, then take it back.
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("get_bag"):
		var bag: Array = inv.call("get_bag", pl)
		for i in range(bag.size()):
			if bag[i] is Dictionary:
				var name0: String = str((bag[i] as Dictionary).get("name", "?"))
				var sr: Dictionary = bank_store_item(pl, i)
				print("[BANK_TEST] stored '%s' -> ok=%s (vault items=%d)" % [
					name0, str(sr.get("ok", false)), bank_items(pl).size()])
				break
	print("[BANK_TEST] ===== self-test complete =====")


# --- helpers ----------------------------------------------------------------

func _give_item(actor: Node, item: Dictionary) -> bool:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("add_item"):
		if inv.has_method("is_registered") and not bool(inv.call("is_registered", actor)):
			if inv.has_method("register"):
				inv.call("register", actor)
		return bool(inv.call("add_item", actor, item))
	return false


func _category_of(item: Dictionary) -> String:
	if str(item.get("type", "")) == "material" or item.has("mat_id"):
		return "material"
	var slot: String = str(item.get("slot", ""))
	if slot == "main_hand":
		return "weapon"
	if slot in ["head", "chest", "legs", "boots", "off_hand"]:
		return "armor"
	if slot in ["ring", "ring1", "ring2", "trinket"]:
		return "trinket"
	return "material"


func _actor_name(actor: Node) -> String:
	if actor == null:
		return "You"
	var n: Variant = actor.get("display_name")
	if n is String and n != "":
		return n
	return "You"


func _gold(actor: Node) -> int:
	if _has_prop(actor, "gold"):
		var g: Variant = actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _set_gold(actor: Node, v: int) -> void:
	if _has_prop(actor, "gold"):
		actor.set("gold", maxi(0, v))


func _player() -> Node:
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("AuctionSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- save contract (SaveSystem group pattern; inert until wired) ------------

func serialize() -> Dictionary:
	var pl: Node = _player()
	if pl == null:
		return {}
	var b: Dictionary = _bank(pl)
	return {"bank_gold": int(b.get("gold", 0)), "bank_items": (b["items"] as Array).duplicate(true)}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var b: Dictionary = _bank(pl)
	b["gold"] = int(d.get("bank_gold", 0))
	var items: Array = []
	for it_v: Variant in _arr(d.get("bank_items", [])):
		if it_v is Dictionary:
			items.append(it_v)
	b["items"] = items
