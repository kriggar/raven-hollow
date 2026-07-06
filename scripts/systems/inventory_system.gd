extends Node
## InventorySystem (autoload) — the loot -> stats connective layer for
## Raven Hollow (BACKLOG: inventory + equipment + proficiencies, #30 item
## progression / gear score, #45 armor proficiencies + WYSIWYG hook).
##
## Actor-keyed, like StatsSystem. Every actor owns a fixed-size bag and the nine
## equip slots (head/chest/legs/boots/main_hand/off_hand/ring1/ring2/trinket —
## the exact slot family loot_system.gd rolls and inventory.gd uses). Equipping
## an item folds its rolled stats into the actor's derived stats through
## StatsSystem.add_modifier(actor, "inv_equip:<iid>:<slot>", stat, amount); the
## per-(actor,slot) source key makes re-equip and unequip perfectly clean.
##
## It listens to LootSystem.loot_generated and files gear into the player's bag
## (guarded — no player, no crash). Proficiency (cloth/leather/mail/plate + the
## weapon families, WoW class rules from design/PROFICIENCY_WYSIWYG.md) gates
## can_equip alongside the item level requirement. Equipping a visible slot emits
## equipped_visual for the future character-sprite layer (WYSIWYG); this system
## only emits it — the visual wiring is Fable's.
##
## Pure systems code: bags, equipment, proficiency verdicts, gear score, signals.
## No scene/UI code (scripts/ui/inventory.gd renders this).

signal inventory_changed(actor)
signal item_equipped(actor, slot, item)
signal item_unequipped(actor, slot, item)
signal equipped_visual(actor, slot, item)   # WYSIWYG hook (visible slots only)

const BAG_SIZE: int = 30

## Nine equip slots (matches inventory.gd / the loot slot family). Item "slot"
## values are TYPES: ring -> ring1/ring2, everything else is name==type.
const EQUIP_SLOTS: Array[String] = [
	"head", "chest", "legs", "boots",
	"main_hand", "off_hand", "ring1", "ring2", "trinket",
]
## Slots whose gear reads on the character sprite (WYSIWYG, W3/W6). Rings are
## sub-pixel and emit no geometry — see PROFICIENCY_WYSIWYG.md §7 W6.
const VISIBLE_SLOTS: Array[String] = [
	"head", "chest", "legs", "boots", "main_hand", "off_hand",
]

const STAT_KEYS: Array[String] = [
	"damage", "armor", "hp", "mana", "speed_pct", "crit_pct", "mana_regen",
]

const SLOT_LABELS: Dictionary = {
	"head": "Head", "chest": "Chest", "legs": "Legs", "boots": "Feet",
	"main_hand": "Main Hand", "off_hand": "Off Hand",
	"ring1": "Ring", "ring2": "Ring", "trinket": "Trinket",
}

## Rarity color language (mirrors LootSystem.RARITY / ItemTooltip).
const RARITY_COLORS: Dictionary = {
	"poor":      Color(0.62, 0.62, 0.62),
	"common":    Color(0.82, 0.82, 0.80),
	"uncommon":  Color(0.35, 0.75, 0.35),
	"rare":      Color(0.30, 0.50, 0.90),
	"epic":      Color(0.62, 0.35, 0.85),
	"legendary": Color(1.0, 0.55, 0.10),
}
const RARITY_ORDER: Array[String] = ["poor", "common", "uncommon", "rare", "epic", "legendary"]

# --- item-level & gear-score math (design/ITEM_PROGRESSION.md §2) ------------
const RARITY_M: Dictionary = {
	"poor": 0.5, "common": 1.0, "uncommon": 1.2,
	"rare": 1.45, "epic": 1.7, "legendary": 2.0,
}
const SLOT_W: Dictionary = {
	"main_hand": 1.00, "chest": 0.90, "legs": 0.80, "head": 0.75,
	"off_hand": 0.70, "boots": 0.60, "trinket": 0.55, "ring": 0.50,
}
## Budget-point cost per unit of each stat (ITEM_PROGRESSION §2.3).
const STAT_POINTS: Dictionary = {
	"damage": 1.0, "armor": 1.0, "hp": 0.2, "mana": 0.2,
	"speed_pct": 1.0, "crit_pct": 1.0, "mana_regen": 4.0,
}

# --- proficiency law (design/PROFICIENCY_WYSIWYG.md Part I) -------------------
const PLATE_TRAIN_LEVEL: int = 40
const MAIL_TRAIN_LEVEL: int = 40
const ARMOR_RANK: Dictionary = {"cloth": 0, "leather": 1, "mail": 2, "plate": 3}

## class_id -> armor classes wearable from level 1 (cumulative: warrior lists
## cloth+leather+mail because a higher tier always allows the lower ones).
const ARMOR_BASE: Dictionary = {
	"warrior":     ["cloth", "leather", "mail"],
	"paladin":     ["cloth", "leather", "mail"],
	"rogue":       ["cloth", "leather"],
	"druid":       ["cloth", "leather"],
	"rookwarden":  ["cloth", "leather"],
	"mage":        ["cloth"],
	"necromancer": ["cloth"],
}
## class_id -> {armor_class: min level} trained upgrades (the level-40 gate).
const ARMOR_TRAINED: Dictionary = {
	"warrior":    {"plate": PLATE_TRAIN_LEVEL},
	"paladin":    {"plate": PLATE_TRAIN_LEVEL},
	"rookwarden": {"mail": MAIL_TRAIN_LEVEL},
}
## class_id -> equippable weapon families ("relic" is universal, handled apart).
const WEAPONS: Dictionary = {
	"warrior":     ["sword", "axe", "mace", "dagger", "shield"],
	"paladin":     ["sword", "mace", "shield"],
	"rogue":       ["dagger", "sword"],
	"druid":       ["staff", "mace", "dagger", "fetish"],
	"rookwarden":  ["bow", "sword", "dagger", "quiver"],
	"mage":        ["staff", "dagger", "tome"],
	"necromancer": ["staff", "dagger", "fetish"],
}

# Keyword inference for the rolled loot DB (items.json carries no class keys;
# the exemplar DB in ITEM_PROGRESSION.md will carry them explicitly and win).
const _ARMOR_KW: Array = [
	["plate",   ["cuirass", "plate", "plated", "pavise", "apron", "facemask", "sabaton", "bulwark"]],
	["mail",    ["mail", "chain", "ringmail", "hauberk", "halfhelm", "coif", "scale", "riveted"]],
	["cloth",   ["robe", "quilted", "padded", "cloth", "cord", "wrap", "kerchief", "shawl", "cowl", "hemp", "footwrap", "gambeson", "silk"]],
	["leather", ["leather", "hide", "jerkin", "hood", "boiled", "studded", "pelt", "scout", "sole", "tread", "strider", "poacher", "boot", "shoe", "cloak", "mantle", "ruff"]],
]
const _WEAPON_KW: Array = [
	["shield",  ["shield", "buckler", "targe", "ward", "kite", "pavise", "aegis"]],
	["tome",    ["tome", "book", "grimoire", "codex"]],
	["fetish",  ["fetish", "totem", "idol", "skull", "focus"]],
	["quiver",  ["quiver"]],
	["dagger",  ["dagger", "knife", "dirk", "stiletto", "claw", "kris", "shiv"]],
	["axe",     ["axe", "cleaver", "hatchet", "hook"]],
	["mace",    ["mace", "hammer", "cudgel", "maul", "flail", "spade", "club"]],
	["bow",     ["bow", "selfbow", "longbow", "talon"]],
	["staff",   ["staff", "rod", "wand", "switch", "stave", "cane"]],
	["sword",   ["sword", "blade", "sabre", "saber", "sickle", "spear", "greatblade", "shortsword", "falchion"]],
]

## instance_id -> {ref, class_id, level, bag: Array(BAG_SIZE, null), equipment: Dict}
var _actors: Dictionary = {}


func _ready() -> void:
	# Autoloads load in registration order and InventorySystem is first, so
	# LootSystem/StatsSystem are not in-tree yet. Wire the loot feed deferred.
	call_deferred("_connect_loot")


func _connect_loot() -> void:
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_signal("loot_generated"):
		if not ls.is_connected("loot_generated", _on_loot_generated):
			ls.connect("loot_generated", _on_loot_generated)


# --- actor registry ---------------------------------------------------------

## Register (or refresh) an actor. class_id/level default to reading them off
## the actor (Player.class_def.id / Player.level). Idempotent.
func register(actor: Object, class_id: String = "", level: int = -1) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	var rec: Dictionary = _actors.get(iid, {})
	if rec.is_empty():
		var bag: Array = []
		bag.resize(BAG_SIZE)  # null-filled
		var equipment: Dictionary = {}
		for slot: String in EQUIP_SLOTS:
			equipment[slot] = null
		rec = {"ref": weakref(actor), "class_id": "warrior", "level": 1,
				"bag": bag, "equipment": equipment}
	rec["ref"] = weakref(actor)
	rec["class_id"] = class_id if class_id != "" else _read_class_id(actor)
	rec["level"] = level if level >= 1 else _read_level(actor)
	_actors[iid] = rec
	# Keep StatsSystem's registry in sync so get_derived() reflects our mods.
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and ss.has_method("register"):
		ss.call("register", actor, str(rec["class_id"]), int(rec["level"]))


func is_registered(actor: Object) -> bool:
	return actor != null and _actors.has(actor.get_instance_id())


func unregister(actor: Object) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	if not _actors.has(iid):
		return
	# Pull every equip modifier this actor contributed before dropping the record.
	for slot: String in EQUIP_SLOTS:
		_remove_slot_mods(actor, slot)
	_actors.erase(iid)


func _rec(actor: Object) -> Dictionary:
	if actor == null:
		return {}
	var iid: int = actor.get_instance_id()
	if not _actors.has(iid):
		register(actor)
	# refresh class/level in case the actor leveled up
	var r: Dictionary = _actors[iid]
	r["class_id"] = _read_class_id(actor)
	r["level"] = _read_level(actor)
	return r


func _read_class_id(actor: Object) -> String:
	if actor == null:
		return "warrior"
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary and (cd as Dictionary).has("id"):
		return str((cd as Dictionary)["id"])
	var ci: Variant = actor.get("class_id")
	if ci is String and ci != "":
		return ci
	return "warrior"


func _read_level(actor: Object) -> int:
	if actor == null:
		return 1
	var lv: Variant = actor.get("level")
	if lv is int or lv is float:
		return maxi(1, int(lv))
	return 1


# --- bag --------------------------------------------------------------------

## First empty bag index, or -1 if the bag is full.
func first_empty(actor: Object) -> int:
	var rec: Dictionary = _rec(actor)
	if rec.is_empty():
		return -1
	var bag: Array = rec["bag"]
	for i: int in BAG_SIZE:
		if bag[i] == null:
			return i
	return -1


## Adds `item` to the first empty bag slot. False when the bag is full.
func add_item(actor: Object, item: Dictionary) -> bool:
	if actor == null or item.is_empty():
		return false
	var idx: int = first_empty(actor)
	if idx < 0:
		return false
	_actors[actor.get_instance_id()]["bag"][idx] = item
	inventory_changed.emit(actor)
	return true


## Removes the item at bag index `idx` (returns it, or {} if empty/invalid).
func remove_item(actor: Object, idx: int) -> Dictionary:
	var rec: Dictionary = _rec(actor)
	if rec.is_empty() or idx < 0 or idx >= BAG_SIZE:
		return {}
	var entry: Variant = rec["bag"][idx]
	if not (entry is Dictionary):
		return {}
	rec["bag"][idx] = null
	inventory_changed.emit(actor)
	return entry


## The fixed-size bag array (may contain nulls) — for grid rendering.
func get_bag(actor: Object) -> Array:
	var rec: Dictionary = _rec(actor)
	return rec.get("bag", []) if not rec.is_empty() else []


## Compact list of the actual items in the bag (no nulls).
func list_items(actor: Object) -> Array:
	var out: Array = []
	for entry: Variant in get_bag(actor):
		if entry is Dictionary:
			out.append(entry)
	return out


func free_slots(actor: Object) -> int:
	var n: int = 0
	for entry: Variant in get_bag(actor):
		if entry == null:
			n += 1
	return n


# --- equipment --------------------------------------------------------------

func get_equipment(actor: Object) -> Dictionary:
	var rec: Dictionary = _rec(actor)
	return rec.get("equipment", {}) if not rec.is_empty() else {}


func get_equipped(actor: Object, slot: String) -> Dictionary:
	var eq: Dictionary = get_equipment(actor)
	var v: Variant = eq.get(slot)
	return v if v is Dictionary else {}


## Equips the item at bag index `bag_idx`. When `target_slot` is "" the slot is
## picked from the item's type (rings prefer the first empty of ring1/ring2).
## An occupied slot swaps its item back into that bag index. Returns the
## verdict dict {ok: bool, reason: String, slot: String}.
func equip_from_bag(actor: Object, bag_idx: int, target_slot: String = "") -> Dictionary:
	var rec: Dictionary = _rec(actor)
	if rec.is_empty():
		return {"ok": false, "reason": "No character.", "slot": ""}
	if bag_idx < 0 or bag_idx >= BAG_SIZE:
		return {"ok": false, "reason": "Empty slot.", "slot": ""}
	var entry: Variant = rec["bag"][bag_idx]
	if not (entry is Dictionary):
		return {"ok": false, "reason": "Empty slot.", "slot": ""}
	var item: Dictionary = entry

	var verdict: Dictionary = can_equip(actor, item)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "reason": str(verdict.get("reason", "Cannot equip.")), "slot": ""}

	var slot: String = target_slot
	if slot == "" or not slot_accepts(slot, item):
		slot = _auto_slot_for(rec, item)
	if slot == "" or not slot_accepts(slot, item):
		return {"ok": false, "reason": "Wrong slot.", "slot": ""}

	var displaced: Variant = rec["equipment"].get(slot)  # null or old item
	rec["equipment"][slot] = item
	rec["bag"][bag_idx] = displaced  # old item drops into the vacated bag cell

	# Rebind the slot's modifier source to the new item (clean re-equip).
	_apply_slot_mods(actor, slot, item)

	if displaced is Dictionary:
		item_unequipped.emit(actor, slot, displaced)
	item_equipped.emit(actor, slot, item)
	if VISIBLE_SLOTS.has(slot):
		equipped_visual.emit(actor, slot, item)
	inventory_changed.emit(actor)
	return {"ok": true, "reason": "", "slot": slot}


## Equip an item not necessarily already in the bag (finds & consumes a matching
## bag entry if present). Convenience over equip_from_bag.
func equip(actor: Object, item: Dictionary, target_slot: String = "") -> Dictionary:
	if actor == null or item.is_empty():
		return {"ok": false, "reason": "No item.", "slot": ""}
	var rec: Dictionary = _rec(actor)
	if rec.is_empty():
		return {"ok": false, "reason": "No character.", "slot": ""}
	var bag: Array = rec["bag"]
	var idx: int = -1
	for i: int in BAG_SIZE:
		if bag[i] is Dictionary and (bag[i] as Dictionary) == item:
			idx = i
			break
	if idx < 0:
		idx = first_empty(actor)
		if idx < 0:
			return {"ok": false, "reason": "Bag full.", "slot": ""}
		bag[idx] = item
	return equip_from_bag(actor, idx, target_slot)


## Moves the item in `slot` back to the bag and strips its stat modifiers.
## False when the slot is empty/unknown or the bag is full.
func unequip(actor: Object, slot: String) -> bool:
	var rec: Dictionary = _rec(actor)
	if rec.is_empty() or not rec["equipment"].has(slot):
		return false
	var entry: Variant = rec["equipment"].get(slot)
	if not (entry is Dictionary):
		return false
	var idx: int = first_empty(actor)
	if idx < 0:
		return false
	rec["bag"][idx] = entry
	rec["equipment"][slot] = null
	_remove_slot_mods(actor, slot)
	item_unequipped.emit(actor, slot, entry)
	if VISIBLE_SLOTS.has(slot):
		equipped_visual.emit(actor, slot, {})
	inventory_changed.emit(actor)
	return true


# --- stat wiring (the loot -> StatsSystem link) -----------------------------

func _equip_source(actor: Object, slot: String) -> String:
	return "inv_equip:%d:%s" % [actor.get_instance_id(), slot]


func _apply_slot_mods(actor: Object, slot: String, item: Dictionary) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss == null:
		return
	var src: String = _equip_source(actor, slot)
	if ss.has_method("remove_modifier"):
		ss.call("remove_modifier", src)  # clear whatever was in this slot
	if not ss.has_method("add_modifier"):
		return
	var stats: Dictionary = {}
	var sv: Variant = item.get("stats")
	if sv is Dictionary:
		stats = sv
	for k: String in STAT_KEYS:
		var v: float = float(stats.get(k, 0.0))
		if absf(v) > 0.0001:
			ss.call("add_modifier", actor, src, k, v)


func _remove_slot_mods(actor: Object, slot: String) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and ss.has_method("remove_modifier"):
		ss.call("remove_modifier", _equip_source(actor, slot))


# --- slot logic -------------------------------------------------------------

## True when `item` may sit in equip slot `slot_name` (shape contract only —
## ring items fit ring1/ring2; every other type is name==type; none/gold/etc.
## fit nothing). Mirrors inventory.gd.slot_accepts.
func slot_accepts(slot_name: String, item: Dictionary) -> bool:
	var kind: String = str(item.get("slot", "none"))
	if kind == "none" or kind == "gold" or kind == "":
		return false
	if slot_name == "ring1" or slot_name == "ring2":
		return kind == "ring"
	return EQUIP_SLOTS.has(slot_name) and slot_name == kind


func _auto_slot_for(rec: Dictionary, item: Dictionary) -> String:
	var kind: String = str(item.get("slot", "none"))
	if kind == "ring":
		if rec["equipment"].get("ring1") == null:
			return "ring1"
		if rec["equipment"].get("ring2") == null:
			return "ring2"
		return "ring1"
	if EQUIP_SLOTS.has(kind):
		return kind
	return ""


func is_equippable(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if bool(item.get("is_currency", false)):
		return false
	if str(item.get("type", "")) == "material":
		return false
	var kind: String = str(item.get("slot", "none"))
	return kind != "none" and kind != "gold" and kind != ""


# --- proficiency ------------------------------------------------------------

func armor_class_of(item: Dictionary) -> String:
	var explicit: String = str(item.get("armor_class", ""))
	if ARMOR_RANK.has(explicit):
		return explicit
	return _infer(item, _ARMOR_KW, "cloth")


func weapon_class_of(item: Dictionary) -> String:
	var explicit: String = str(item.get("weapon_class", ""))
	if explicit != "":
		return explicit
	var slot: String = str(item.get("slot", ""))
	var dflt: String = "shield" if slot == "off_hand" else "sword"
	return _infer(item, _WEAPON_KW, dflt)


func _infer(item: Dictionary, table: Array, dflt: String) -> String:
	var hay: String = (str(item.get("name", "")) + " " + str(item.get("id", "")) + " "
			+ str(item.get("flavor", ""))).to_lower()
	for row: Array in table:
		for kw: String in (row[1] as Array):
			if hay.find(kw) != -1:
				return str(row[0])
	return dflt


## Armor classes this class may wear at this level (base + trained-at-40).
func allowed_armor(class_id: String, level: int) -> Array:
	var base: Array = (ARMOR_BASE.get(class_id, ["cloth"]) as Array).duplicate()
	var trained: Dictionary = ARMOR_TRAINED.get(class_id, {})
	for ac: String in trained.keys():
		if level >= int(trained[ac]) and not base.has(ac):
			base.append(ac)
	return base


## The single equip verdict: {ok: bool, reason: String}. Checks slot -> level
## -> armor/weapon proficiency. Rings & trinkets are ungated.
func can_equip(actor: Object, item: Dictionary) -> Dictionary:
	if not is_equippable(item):
		return {"ok": false, "reason": "This cannot be worn."}
	var class_id: String = _read_class_id(actor)
	var level: int = _read_level(actor)
	var slot: String = str(item.get("slot", "none"))

	var req: int = req_level(item)
	if level < req:
		return {"ok": false, "reason": "Requires level %d." % req}

	if slot in ["head", "chest", "legs", "boots"]:
		var ac: String = armor_class_of(item)
		if not allowed_armor(class_id, level).has(ac):
			return {"ok": false, "reason": _armor_denial(class_id, level, ac)}
		return {"ok": true, "reason": ""}

	if slot == "main_hand" or slot == "off_hand":
		var wc: String = weapon_class_of(item)
		if wc == "relic":
			return {"ok": true, "reason": ""}
		var allowed: Array = WEAPONS.get(class_id, [])
		if not allowed.has(wc):
			return {"ok": false, "reason": _weapon_denial(wc)}
		return {"ok": true, "reason": ""}

	# ring1/ring2/trinket -> ungated
	return {"ok": true, "reason": ""}


func _armor_denial(class_id: String, level: int, ac: String) -> String:
	# trainable later (plate/mail at 40) reads differently from never.
	var trained: Dictionary = ARMOR_TRAINED.get(class_id, {})
	if trained.has(ac) and level < int(trained[ac]):
		if ac == "plate":
			return "You have never been fitted for plate."
		if ac == "mail":
			return "Mail is not yours to carry - yet."
		return "%s: trained at level %d." % [ac.capitalize(), int(trained[ac])]
	if ac == "plate" or ac == "mail":
		return "Cloth hands. Cloth back."
	return "Your order cannot wear %s." % ac.capitalize()


func _weapon_denial(wc: String) -> String:
	match wc:
		"shield": return "Your order does not raise shields."
		"bow": return "You were not taught the bow."
		"staff": return "That staff answers to another."
		"tome": return "The words are closed to you."
		"fetish": return "The spirits do not know your hand."
		"quiver": return "No bow, no quiver."
		_: return "You were never trained for that."


# --- item level & gear score (ITEM_PROGRESSION #30) -------------------------

func stat_points(item: Dictionary) -> float:
	var stats: Dictionary = {}
	var sv: Variant = item.get("stats")
	if sv is Dictionary:
		stats = sv
	var p: float = 0.0
	for k: String in STAT_KEYS:
		p += float(stats.get(k, 0.0)) * float(STAT_POINTS.get(k, 1.0))
	return p


## Item level: explicit ilvl/item_level/req_level if present, else solved from
## the budget formula BP = (2.4 + 0.62*ilvl) * SLOT_W * RARITY_M (inverse).
func item_level(item: Dictionary) -> int:
	for key: String in ["ilvl", "item_level"]:
		if item.has(key):
			return maxi(1, int(item[key]))
	if item.has("req_level"):
		return maxi(1, int(item["req_level"]))
	var rarity: String = str(item.get("rarity", "common"))
	var slot: String = _budget_slot(str(item.get("slot", "main_hand")))
	var denom: float = float(SLOT_W.get(slot, 0.7)) * float(RARITY_M.get(rarity, 1.0))
	if denom <= 0.0:
		return 1
	var bp: float = stat_points(item)
	var ilvl: float = ((bp / denom) - 2.4) / 0.62
	return clampi(int(round(ilvl)), 1, 60)


func req_level(item: Dictionary) -> int:
	if item.has("req_level"):
		return maxi(1, int(item["req_level"]))
	return item_level(item)


func _budget_slot(slot: String) -> String:
	if slot == "ring1" or slot == "ring2":
		return "ring"
	return slot if SLOT_W.has(slot) else "main_hand"


## Single-item gear score — rises with item level and rarity (the #30 curve).
func item_gear_score(item: Dictionary) -> int:
	if not is_equippable(item):
		return 0
	var rarity: String = str(item.get("rarity", "common"))
	var rm: float = float(RARITY_M.get(rarity, 1.0))
	return int(round(float(item_level(item)) * rm * 4.0 + stat_points(item)))


## Total gear score across all equipped slots.
func gear_score(actor: Object) -> int:
	var total: int = 0
	var eq: Dictionary = get_equipment(actor)
	for slot: String in EQUIP_SLOTS:
		var v: Variant = eq.get(slot)
		if v is Dictionary:
			total += item_gear_score(v)
	return total


## Sum of all equipped items' raw stats (for a live "equipped bonuses" strip).
func equipped_stat_totals(actor: Object) -> Dictionary:
	var totals: Dictionary = {}
	for k: String in STAT_KEYS:
		totals[k] = 0.0
	var eq: Dictionary = get_equipment(actor)
	for slot: String in EQUIP_SLOTS:
		var v: Variant = eq.get(slot)
		if v is Dictionary:
			var stats: Dictionary = (v as Dictionary).get("stats", {})
			for k: String in STAT_KEYS:
				totals[k] = float(totals[k]) + float(stats.get(k, 0.0))
	return totals


# --- helpers ----------------------------------------------------------------

func rarity_color(rarity: String) -> Color:
	var c: Variant = RARITY_COLORS.get(rarity)
	return c if c is Color else Color(0.62, 0.62, 0.62)


func rarity_rank(rarity: String) -> int:
	return RARITY_ORDER.find(rarity)


# --- loot feed --------------------------------------------------------------

## LootSystem.loot_generated -> file gear into the player's bag (guarded).
func _on_loot_generated(items: Variant) -> void:
	if not (items is Array):
		return
	var player: Node = _find_player()
	if player == null:
		return
	if not is_registered(player):
		register(player)
	for it: Variant in (items as Array):
		if it is Dictionary and is_equippable(it):
			add_item(player, it)


func _find_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")
