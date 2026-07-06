extends Node
## LootSystem — autoload. WoW-Classic-spirit loot engine for Raven Hollow.
## Owns the rarity tiers (color + drop weight + stat budget), loads the item DB
## and loot tables from data/*.json, and rolls corpse loot into full item dicts
## (the exact items.gd shape) with budget-scaled stats. Also spawns and drives
## the D2-style loot window (scenes/ui/loot_window.tscn).
##
## Public API:
##   roll_loot(table_id: String, luck := 0.0) -> Array[Dictionary]
##       Rolls a table's gold + drops into item instances, emits loot_generated,
##       returns the list. Unknown table_id -> [] (drops nothing).
##   roll_item(item_id: String, rarity := "") -> Dictionary
##       Budget-based stat roll of a base item at a target rarity, or a named
##       unique's fixed stats. {} on unknown id.
##   roll_for_enemy(type_name: String, luck := 0.0) -> Array[Dictionary]
##       Maps an enemy type to its table (enemy_tables) and rolls. [] if none.
##   debug_roll() -> Array[Dictionary]
##       A deterministic, rarity-varied showcase roll (QA / eyeballing).
## Signal:
##   loot_generated(items: Array)   # the loot window listens for this

signal loot_generated(items)

const ITEMS_PATH := "res://data/items.json"
const TABLES_PATH := "res://data/loot_tables.json"
const WINDOW_SCENE := "res://scenes/ui/loot_window.tscn"

## Rarity tiers: color (matches Items.RARITY_COLORS / ItemTooltip), base drop
## weight (share of a gear roll), stat budget multiplier vs the common roll, and
## how many secondary stats a rolled item of that tier gains.
const RARITY := {
	"common":    {"color": Color(0.62, 0.62, 0.62), "weight": 79.0, "budget": 1.0,  "secondaries": 0},
	"uncommon":  {"color": Color(0.35, 0.75, 0.35), "weight": 18.0, "budget": 1.35, "secondaries": 0},
	"rare":      {"color": Color(0.30, 0.50, 0.90), "weight": 2.8,  "budget": 1.8,  "secondaries": 1},
	"epic":      {"color": Color(0.62, 0.35, 0.85), "weight": 0.2,  "budget": 2.3,  "secondaries": 2},
	"legendary": {"color": Color(1.0, 0.55, 0.1),   "weight": 0.0,  "budget": 3.0,  "secondaries": 2},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

const STAT_KEYS := ["damage", "armor", "hp", "mana", "speed_pct", "crit_pct"]

## Slot-appropriate secondary stat pools (rare+ gear gains one/two of these).
const SECONDARY_POOL := {
	"main_hand": ["crit_pct", "speed_pct", "hp"],
	"off_hand":  ["hp", "armor", "mana"],
	"head":      ["hp", "speed_pct", "mana"],
	"chest":     ["hp", "armor", "mana"],
	"legs":      ["hp", "armor", "speed_pct"],
	"boots":     ["speed_pct", "hp", "crit_pct"],
	"ring":      ["mana", "crit_pct", "hp"],
	"trinket":   ["crit_pct", "speed_pct", "mana"],
}
const SECONDARY_RANGE := {
	"crit_pct": [2.0, 5.0], "speed_pct": [2.0, 5.0],
	"hp": [4.0, 10.0], "mana": [4.0, 10.0], "armor": [1.0, 3.0], "damage": [1.0, 3.0],
}

var _bases: Dictionary = {}
var _named: Dictionary = {}
var _tables: Dictionary = {}
var _enemy_tables: Dictionary = {}
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _window: Node = null


func _ready() -> void:
	_rng.randomize()
	_load_data()
	call_deferred("_spawn_window")


func _load_data() -> void:
	var items: Dictionary = _read_json(ITEMS_PATH)
	_bases = _dict(items.get("bases", {}))
	_named = _dict(items.get("named_rares", {}))
	var tbl: Dictionary = _read_json(TABLES_PATH)
	_tables = _dict(tbl.get("tables", {}))
	_enemy_tables = _dict(tbl.get("enemy_tables", {}))
	_materials = _dict(tbl.get("materials", {}))
	if _bases.is_empty() or _tables.is_empty():
		push_warning("LootSystem: item/table data failed to load (bases=%d tables=%d)"
				% [_bases.size(), _tables.size()])


func _spawn_window() -> void:
	if _window != null and is_instance_valid(_window):
		return
	if not ResourceLoader.exists(WINDOW_SCENE):
		return
	var scn: PackedScene = load(WINDOW_SCENE) as PackedScene
	if scn == null:
		return
	_window = scn.instantiate()
	add_child(_window)


# --- Rolling ----------------------------------------------------------------

## Rolls a loot table into a list of item instances (gold first, then items),
## emits loot_generated, and returns the list. Unknown table -> [] (no drop).
func roll_loot(table_id: String, luck: float = 0.0) -> Array:
	var out: Array = []
	var table: Dictionary = _dict(_tables.get(table_id, {}))
	if table.is_empty():
		return out

	# Gold line (a currency pseudo-item the window renders first).
	var gold_v: Variant = table.get("gold")
	if gold_v is Dictionary:
		var g: Dictionary = gold_v
		if _rng.randf() < float(g.get("chance", 0.0)):
			var amount: int = _rng.randi_range(int(g.get("min", 0)), int(g.get("max", 0)))
			if amount > 0:
				out.append(_make_gold(amount))

	# Boss guaranteed named slot (one weighted pick, always present).
	var gnames: Array = _arr(table.get("guaranteed_named", []))
	if not gnames.is_empty():
		var pick_id: String = str(gnames[_rng.randi_range(0, gnames.size() - 1)])
		var it: Dictionary = roll_item(pick_id)
		if not it.is_empty():
			out.append(it)

	# Weighted picks from the drops list.
	var drops: Array = _arr(table.get("drops", []))
	if not drops.is_empty():
		var picks_cfg: Dictionary = _dict(table.get("picks", {"min": 1, "max": 2}))
		var n: int = _rng.randi_range(int(picks_cfg.get("min", 1)), int(picks_cfg.get("max", 2)))
		if luck > 0.0 and _rng.randf() < clampf(luck * 0.02, 0.0, 0.5):
			n += 1
		var rweights: Dictionary = _dict(table.get("rarity_weights", {}))
		for _i in range(n):
			var entry: Dictionary = _pick_weighted(drops)
			if entry.is_empty():
				continue
			var made: Dictionary = _materialize(entry, table, rweights, luck)
			if not made.is_empty():
				out.append(made)

	out = _merge_stacks(out)
	loot_generated.emit(out)
	return out


## Maps an enemy type_name to its loot table and rolls it. [] if unmapped.
func roll_for_enemy(type_name: String, luck: float = 0.0) -> Array:
	var tid: String = str(_enemy_tables.get(type_name, ""))
	if tid.is_empty():
		# longest-prefix fallback (skeleton_mage -> skeleton, orc_rogue -> orc)
		for key: String in _enemy_tables.keys():
			if type_name.begins_with(key):
				tid = str(_enemy_tables[key])
				break
	if tid.is_empty():
		return []
	return roll_loot(tid, luck)


## Budget-based stat roll of a base item at a target rarity, or a named unique.
func roll_item(item_id: String, rarity: String = "") -> Dictionary:
	if _named.has(item_id):
		return _make_named(item_id)
	if not _bases.has(item_id):
		return {}
	var base: Dictionary = _dict(_bases[item_id])
	var tier: String = rarity
	if tier.is_empty() or not RARITY.has(tier):
		tier = str(base.get("base_rarity", "common"))
	var tier_def: Dictionary = _dict(RARITY[tier])
	var budget: float = float(tier_def.get("budget", 1.0))
	var slot: String = str(base.get("slot", "none"))

	var stats: Dictionary = _zero_stats()
	var ranges: Dictionary = _dict(base.get("stat_ranges", {}))
	for k: String in ranges.keys():
		var r: Array = _arr(ranges[k])
		if r.size() < 2:
			continue
		var v: float = _rng.randf_range(float(r[0]), float(r[1])) * budget
		stats[k] = _round_stat(k, v)

	# Secondary stats for rare+ (WoW's blue/purple extra affixes).
	var secn: int = int(tier_def.get("secondaries", 0))
	if secn > 0:
		var pool: Array = _arr(SECONDARY_POOL.get(slot, ["hp"]))
		for _s in range(secn):
			if pool.is_empty():
				break
			var sk: String = str(pool[_rng.randi_range(0, pool.size() - 1)])
			var sr: Array = _arr(SECONDARY_RANGE.get(sk, [2.0, 5.0]))
			var add: float = _rng.randf_range(float(sr[0]), float(sr[1])) * (0.7 + 0.3 * budget)
			stats[sk] = _round_stat(sk, float(stats.get(sk, 0.0)) + add)

	return {
		"id": item_id,
		"name": str(base.get("name", item_id.capitalize())),
		"slot": slot,
		"rarity": tier,
		"icon": "pixel:" + str(base.get("icon_hint", "")),
		"stats": stats,
		"flavor": str(base.get("flavor", "")),
		"stackable": false,
		"effect": "",
	}


## A deterministic, rarity-varied showcase roll for QA / eyeballing the window.
func debug_roll() -> Array:
	var out: Array = []
	out.append(_make_gold(_rng.randi_range(18, 44)))
	out.append(roll_item("iron_shortsword", "common"))
	out.append(roll_item("ringmail_vest", "uncommon"))
	out.append(roll_item("iron_ward", "rare"))
	out.append(roll_item("chainmail_hauberk", "epic"))
	out.append(_make_named("kerbstone_greatblade"))    # named epic
	out.append(_make_named("whitepelt_cloak"))         # named rare
	out.append(_make_material("wolf_pelt_mat", 3))
	var clean: Array = []
	for it: Variant in out:
		if it is Dictionary and not (it as Dictionary).is_empty():
			clean.append(it)
	loot_generated.emit(clean)
	return clean


func rarity_color(rarity: String) -> Color:
	var d: Dictionary = _dict(RARITY.get(rarity, {}))
	var c: Variant = d.get("color")
	if c is Color:
		return c
	return Color(0.62, 0.62, 0.62)


func rarity_rank(rarity: String) -> int:
	return RARITY_ORDER.find(rarity)


# --- internals --------------------------------------------------------------

func _materialize(entry: Dictionary, table: Dictionary, rweights: Dictionary, luck: float) -> Dictionary:
	var kind: String = str(entry.get("rarity", "roll"))
	var item_id: String = str(entry.get("item_id", ""))
	var qty: int = _roll_qty(_arr(entry.get("quantity", [1, 1])))

	if kind == "material" or kind == "junk":
		return _make_material(item_id, qty)
	if kind == "named":
		return _make_named(item_id)
	if RARITY.has(kind):
		var forced: Dictionary = roll_item(item_id, kind)
		return forced
	# "roll": pick a rarity tier from the table weights, then budget-roll.
	var tier: String = _roll_rarity(rweights, luck)
	var pick_id: String = item_id
	if item_id == "__gear__":
		var pool: Array = _arr(table.get("gear_pool", []))
		if pool.is_empty():
			return {}
		pick_id = str(pool[_rng.randi_range(0, pool.size() - 1)])
	return roll_item(pick_id, tier)


func _roll_rarity(weights: Dictionary, luck: float) -> String:
	var src: Dictionary = weights
	if src.is_empty():
		src = {}
		for r: String in RARITY_ORDER:
			src[r] = float(_dict(RARITY[r]).get("weight", 0.0))
	var total: float = 0.0
	var adj: Dictionary = {}
	for r: String in src.keys():
		var w: float = float(src[r])
		# luck nudges the rarer tiers up a touch.
		if luck > 0.0 and (r == "rare" or r == "epic" or r == "legendary"):
			w *= (1.0 + luck * 0.1)
		adj[r] = w
		total += w
	if total <= 0.0:
		return "common"
	var roll: float = _rng.randf() * total
	for r: String in adj.keys():
		roll -= float(adj[r])
		if roll <= 0.0:
			return r
	return str(adj.keys()[0])


func _pick_weighted(entries: Array) -> Dictionary:
	var total: float = 0.0
	for e: Variant in entries:
		if e is Dictionary:
			total += float((e as Dictionary).get("weight", 1.0))
	if total <= 0.0:
		return {}
	var roll: float = _rng.randf() * total
	for e: Variant in entries:
		if e is Dictionary:
			roll -= float((e as Dictionary).get("weight", 1.0))
			if roll <= 0.0:
				return e
	return _dict(entries[entries.size() - 1])


func _make_named(item_id: String) -> Dictionary:
	if not _named.has(item_id):
		return {}
	var n: Dictionary = _dict(_named[item_id])
	var stats: Dictionary = _zero_stats()
	var src_stats: Dictionary = _dict(n.get("stats", {}))
	for k: String in src_stats.keys():
		stats[k] = float(src_stats[k])
	return {
		"id": item_id,
		"name": str(n.get("name", item_id.capitalize())),
		"slot": str(n.get("slot", "none")),
		"rarity": str(n.get("rarity", "rare")),
		"icon": "pixel:" + str(n.get("icon_hint", "")),
		"stats": stats,
		"flavor": str(n.get("flavor", "")),
		"stackable": false,
		"effect": "",
		"named": true,
	}


func _make_material(item_id: String, qty: int) -> Dictionary:
	var m: Dictionary = _dict(_materials.get(item_id, {}))
	var nm: String = str(m.get("name", item_id.capitalize()))
	var hint: String = str(m.get("icon_hint", "iron_scrap"))
	return {
		"id": item_id,
		"name": nm,
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:" + hint,
		"stats": _zero_stats(),
		"flavor": str(m.get("flavor", "")),
		"stackable": true,
		"effect": "",
		"type": "material",
		"quantity": max(1, qty),
	}


func _make_gold(amount: int) -> Dictionary:
	return {
		"id": "gold",
		"name": "%d Coins" % amount,
		"slot": "gold",
		"rarity": "common",
		"icon": "pixel:tarnished_band",
		"stats": _zero_stats(),
		"flavor": "",
		"stackable": true,
		"effect": "",
		"is_currency": true,
		"quantity": amount,
	}


func _merge_stacks(items: Array) -> Array:
	var out: Array = []
	var index: Dictionary = {}
	for it: Variant in items:
		if not (it is Dictionary):
			continue
		var d: Dictionary = it
		if bool(d.get("stackable", false)) and index.has(d.get("id")):
			var tgt: Dictionary = out[index[d.get("id")]]
			tgt["quantity"] = int(tgt.get("quantity", 1)) + int(d.get("quantity", 1))
			if bool(d.get("is_currency", false)):
				tgt["name"] = "%d Coins" % int(tgt["quantity"])
		else:
			out.append(d)
			index[d.get("id")] = out.size() - 1
	return out


func _roll_qty(r: Array) -> int:
	if r.size() >= 2:
		return _rng.randi_range(int(r[0]), int(r[1]))
	if r.size() == 1:
		return int(r[0])
	return 1


func _round_stat(key: String, v: float) -> float:
	# percent / crit stats keep to whole numbers; damage/armor allow half steps.
	if key == "speed_pct" or key == "crit_pct" or key == "hp" or key == "mana":
		return float(roundi(v))
	return snappedf(v, 0.5)


func _zero_stats() -> Dictionary:
	var s: Dictionary = {}
	for k: String in STAT_KEYS:
		s[k] = 0.0
	return s


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LootSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	push_warning("LootSystem: failed to parse '%s'" % path)
	return {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
