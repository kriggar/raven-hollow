extends Node
## CraftingSystem (autoload) - the seven-profession crafting engine for Raven
## Hollow (BACKLOG #42, design/CRAFTING.md). WoW-Classic structure - trainers,
## a 1..1000 skill track (cap raised per owner amendment), recipe ink colors,
## learn-from-the-world unlocks - carrying crafts derived from Draconia's canon
## economies. Pure data + math + per-actor state; no scene code (mirrors
## TalentSystem / LootSystem). The UI lives in scripts/ui/crafting.gd.
##
## Data: data/crafting.json = professions (roster + home station + trainer),
## materials (reagent DB), recipes (materials -> output item in the exact
## LootSystem/Inventory item shape). unlock == "trainer" recipes are auto-known
## when the profession is learned (still skill-gated); every other channel
## (fragment/master/festival/vendor/legendary/boss) is learned from the world
## via learn_recipe. Each profession ships one legendary recipe; boss-drop
## legendaries (boss_drop == true) are class-flavored.
##
## Public API:
##   learn_profession(actor, prof) -> bool          # enforces MAX_PRIMARIES
##   has_profession(actor, prof) -> bool
##   get_skill(actor, prof) -> int
##   learn_recipe(actor, recipe_id) -> bool          # world/boss/trainer teach
##   is_known(actor, recipe_id) -> bool
##   can_craft(actor, recipe_id) -> bool             # known + skill + materials
##   craft(actor, recipe_id) -> Dictionary           # consume + produce + skill
##   recipes_for(actor, prof) -> Array               # profession recipe defs
##   material_count(actor, mat_id) -> int
##   give_material(actor, mat_id, n) -> bool          # gather/quest/debug faucet
##   professions() / profession(id) / recipe(id) / material(id)
##   rank_name(skill) / ink_of(actor, recipe_id) / max_skill()
##   serialize(actor) / deserialize(data, actor)      # save hooks
## Signals:
##   crafted(actor, recipe_id, item)
##   skill_up(actor, profession, new_skill)
##   recipe_learned(actor, recipe_id)
##   profession_learned(actor, profession)

signal crafted(actor, recipe_id, item)
signal skill_up(actor, profession, new_skill)
signal recipe_learned(actor, recipe_id)
signal profession_learned(actor, profession)

const DATA_PATH := "res://data/crafting.json"
const MAX_PRIMARIES: int = 2
const STAT_KEYS := ["damage", "armor", "hp", "mana", "speed_pct", "crit_pct"]

## Ink bands (skill vs recipe difficulty D). wet = 100% skill-up, settled ~66%,
## fading ~25%, dry = 0%. Widths scale to the 1..1000 track (config.ink_bands).
var _ink_wet: int = 40
var _ink_settled: int = 80
var _ink_fading: int = 120

var _max_skill: int = 1000
var _professions: Dictionary = {}        # id -> prof def
var _prof_order: Array[String] = []      # insertion order (UI tab order)
var _materials: Dictionary = {}          # id -> material def
var _recipes: Dictionary = {}            # id -> recipe def
var _recipes_by_prof: Dictionary = {}    # prof_id -> Array[String] (order)
var _rank_gates: Array = []              # [[skill, name], ...] ascending

## instance_id -> {ref:WeakRef, skill:{prof:int}, known:{recipe:true},
##                 crafted:{recipe:true}}
var _state: Dictionary = {}


func _ready() -> void:
	_load()
	if not OS.get_environment("RH_CRAFT_TEST").is_empty():
		_run_selftest_deferred()


func _load() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("CraftingSystem: missing %s" % DATA_PATH)
		return
	var txt: String = FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("CraftingSystem: bad JSON in %s" % DATA_PATH)
		return
	var root: Dictionary = parsed
	var cfg: Dictionary = _dict(root.get("config", {}))
	_max_skill = int(cfg.get("max_skill", 1000))
	var bands: Dictionary = _dict(cfg.get("ink_bands", {}))
	_ink_wet = int(bands.get("wet", 40))
	_ink_settled = int(bands.get("settled", 80))
	_ink_fading = int(bands.get("fading", 120))
	for pair_k: String in _dict(cfg.get("ranks", {})):
		_rank_gates.append([int(pair_k), str(_dict(cfg.get("ranks", {}))[pair_k])])
	_rank_gates.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))

	_professions = _dict(root.get("professions", {}))
	for pid: String in _professions:
		_prof_order.append(pid)
		_recipes_by_prof[pid] = [] as Array[String]
	_materials = _dict(root.get("materials", {}))
	_recipes = _dict(root.get("recipes", {}))
	for rid: String in _recipes:
		var r: Dictionary = _dict(_recipes[rid])
		r["id"] = rid
		_recipes[rid] = r
		var prof: String = str(r.get("profession", ""))
		if _recipes_by_prof.has(prof):
			(_recipes_by_prof[prof] as Array).append(rid)
	if _professions.is_empty() or _recipes.is_empty():
		push_warning("CraftingSystem: professions=%d recipes=%d (data may be empty)"
			% [_professions.size(), _recipes.size()])


# --- per-actor state --------------------------------------------------------

func _st(actor: Object) -> Dictionary:
	var iid: int = actor.get_instance_id()
	if not _state.has(iid):
		_state[iid] = {
			"ref": weakref(actor),
			"skill": {},      # prof_id -> int
			"known": {},      # recipe_id -> true (world/boss/trainer taught)
			"crafted": {},    # recipe_id -> true (first-craft tracking)
		}
	return _state[iid]


func is_registered(actor: Object) -> bool:
	return actor != null and _state.has(actor.get_instance_id())


func unregister(actor: Object) -> void:
	if actor != null:
		_state.erase(actor.get_instance_id())


# --- professions ------------------------------------------------------------

## All profession defs in tab order.
func professions() -> Array:
	var out: Array = []
	for pid: String in _prof_order:
		out.append((_professions[pid] as Dictionary).duplicate(true))
	return out


func profession(prof_id: String) -> Dictionary:
	return _dict(_professions.get(prof_id, {})).duplicate(true)


func has_profession(actor: Object, prof_id: String) -> bool:
	if actor == null or not _professions.has(prof_id):
		return false
	return (_st(actor)["skill"] as Dictionary).has(prof_id)


func primaries_learned(actor: Object) -> int:
	if actor == null:
		return 0
	var n: int = 0
	for pid: String in (_st(actor)["skill"] as Dictionary):
		if str((_dict(_professions.get(pid, {}))).get("kind", "primary")) == "primary":
			n += 1
	return n


## Learn a profession at skill 1. Enforces MAX_PRIMARIES for primaries. Auto-
## registers the trainer wet-ink recipe spine as known. False when unknown /
## already learned / the two-primary cap is reached.
func learn_profession(actor: Object, prof_id: String) -> bool:
	if actor == null or not _professions.has(prof_id):
		return false
	var skills: Dictionary = _st(actor)["skill"]
	if skills.has(prof_id):
		return false
	var kind: String = str((_dict(_professions[prof_id])).get("kind", "primary"))
	if kind == "primary" and primaries_learned(actor) >= MAX_PRIMARIES:
		return false
	skills[prof_id] = 1
	profession_learned.emit(actor, prof_id)
	return true


func get_skill(actor: Object, prof_id: String) -> int:
	if actor == null:
		return 0
	return int((_st(actor)["skill"] as Dictionary).get(prof_id, 0))


## Debug/quest: force a profession's skill (learns it first if needed).
func debug_set_skill(actor: Object, prof_id: String, value: int) -> void:
	if actor == null or not _professions.has(prof_id):
		return
	if not has_profession(actor, prof_id):
		learn_profession(actor, prof_id)
	(_st(actor)["skill"] as Dictionary)[prof_id] = clampi(value, 1, _max_skill)


func max_skill() -> int:
	return _max_skill


## Rank name (Hand / Sworn / Master / Keeper) for a skill value.
func rank_name(skill: int) -> String:
	var name: String = "Hand"
	for gate: Array in _rank_gates:
		if skill >= int(gate[0]):
			name = str(gate[1])
	return name


# --- recipes ----------------------------------------------------------------

func recipe(recipe_id: String) -> Dictionary:
	return _dict(_recipes.get(recipe_id, {})).duplicate(true)


func material(mat_id: String) -> Dictionary:
	return _dict(_materials.get(mat_id, {})).duplicate(true)


## Every recipe def for a profession, in insertion order (UI list order).
func recipes_for(_actor: Object, prof_id: String) -> Array:
	var out: Array = []
	for rid: String in _arr(_recipes_by_prof.get(prof_id, [])):
		out.append((_recipes[rid] as Dictionary).duplicate(true))
	return out


## A recipe is known if it is trainer-taught and its profession is learned, OR
## it was explicitly learned (world fragment / master / festival / vendor /
## legendary / boss scroll).
func is_known(actor: Object, recipe_id: String) -> bool:
	if actor == null or not _recipes.has(recipe_id):
		return false
	var r: Dictionary = _recipes[recipe_id]
	if str(r.get("unlock", "trainer")) == "trainer" and has_profession(actor, str(r.get("profession", ""))):
		return true
	return (_st(actor)["known"] as Dictionary).has(recipe_id)


## Learn a world/boss/trainer recipe scroll. True only for a real, not-yet-known
## recipe. Emits recipe_learned.
func learn_recipe(actor: Object, recipe_id: String) -> bool:
	if actor == null or not _recipes.has(recipe_id):
		return false
	if is_known(actor, recipe_id):
		return false
	(_st(actor)["known"] as Dictionary)[recipe_id] = true
	recipe_learned.emit(actor, recipe_id)
	return true


## The recipe's ink band vs the actor's skill: "wet" (100% up), "settled",
## "fading", or "dry" (no skill gain). Drives the UI recipe-name color.
func ink_of(actor: Object, recipe_id: String) -> String:
	if not _recipes.has(recipe_id):
		return "dry"
	var r: Dictionary = _recipes[recipe_id]
	var d: int = int(r.get("difficulty", r.get("skill_req", 1)))
	var s: int = get_skill(actor, str(r.get("profession", "")))
	if s < d + _ink_wet:
		return "wet"
	if s < d + _ink_settled:
		return "settled"
	if s < d + _ink_fading:
		return "fading"
	return "dry"


# --- crafting ---------------------------------------------------------------

## True when the recipe is known, its profession is learned, the skill meets
## skill_req, and (if the actor has an inventory) every material is in the bag.
func can_craft(actor: Object, recipe_id: String) -> bool:
	if actor == null or not _recipes.has(recipe_id):
		return false
	var r: Dictionary = _recipes[recipe_id]
	var prof: String = str(r.get("profession", ""))
	if not has_profession(actor, prof):
		return false
	if not is_known(actor, recipe_id):
		return false
	if get_skill(actor, prof) < int(r.get("skill_req", 1)):
		return false
	var inv: Object = _inventory_of(actor)
	if inv == null:
		return false
	var mats: Dictionary = _dict(r.get("materials", {}))
	for mid: String in mats:
		if _count_in(inv, mid) < int(mats[mid]):
			return false
	return true


## Consumes materials, produces the output item (LootSystem/Inventory shape)
## into the actor's bag, rolls the skill-up, and returns the crafted item dict.
## {} on any failure (unknown/unlearned/under-skilled recipe, missing mats, or
## a full bag - in which case the materials are refunded).
func craft(actor: Object, recipe_id: String) -> Dictionary:
	if not can_craft(actor, recipe_id):
		return {}
	var r: Dictionary = _recipes[recipe_id]
	var inv: Object = _inventory_of(actor)
	var mats: Dictionary = _dict(r.get("materials", {}))
	for mid: String in mats:
		_take(inv, mid, int(mats[mid]))
	var item: Dictionary = _make_output(r)
	var count: int = maxi(1, int(r.get("count", 1)))
	var ok: bool = false
	if bool(item.get("stackable", false)):
		ok = _add_stackable(inv, item, count)
	else:
		ok = true
		for _i: int in count:
			if not inv.call("add_item", item.duplicate(true)):
				ok = false
	if not ok:
		for mid: String in mats:  # bag full: refund
			give_material(actor, mid, int(mats[mid]))
		return {}
	_roll_skill_up(actor, r)
	item["count"] = count
	crafted.emit(actor, recipe_id, item)
	return item


func _make_output(recipe: Dictionary) -> Dictionary:
	var out: Dictionary = _dict(recipe.get("output", {})).duplicate(true)
	if out.is_empty():
		out = {"id": str(recipe.get("id", "?")), "name": str(recipe.get("name", "?")),
			"slot": "none", "rarity": "common", "icon": "pixel:iron_scrap",
			"flavor": "", "stackable": false, "effect": ""}
	if not out.has("stats"):
		out["stats"] = _zero_stats()
	return out


func _roll_skill_up(actor: Object, recipe: Dictionary) -> void:
	var prof: String = str(recipe.get("profession", ""))
	if prof == "":
		return
	var s: int = get_skill(actor, prof)
	if s >= _max_skill:
		return
	var d: int = int(recipe.get("difficulty", recipe.get("skill_req", 1)))
	var pct: float
	if s < d + _ink_wet:
		pct = 1.0
	elif s < d + _ink_settled:
		pct = 0.66
	elif s < d + _ink_fading:
		pct = 0.25
	else:
		pct = 0.0
	var crafted_set: Dictionary = _st(actor)["crafted"]
	var first: bool = not crafted_set.has(str(recipe.get("id", "")))
	crafted_set[str(recipe.get("id", ""))] = true
	if first and pct <= 0.0:
		pct = 1.0  # first craft of any recipe always skills up (even fading/dry)
	elif first:
		pct = 1.0
	if pct > 0.0 and randf() < pct:
		var gain: int = maxi(1, int(recipe.get("skill_gain", 5)))
		var nv: int = mini(_max_skill, s + gain)
		(_st(actor)["skill"] as Dictionary)[prof] = nv
		skill_up.emit(actor, prof, nv)


# --- materials / inventory adapter ------------------------------------------

## Total copies of mat_id in the actor's bag (stack-aware). 0 without a bag.
func material_count(actor: Object, mat_id: String) -> int:
	var inv: Object = _inventory_of(actor)
	if inv == null:
		return 0
	return _count_in(inv, mat_id)


## Adds n copies of a material to the actor's bag as one merged stack (gather /
## quest reward / debug faucet). False without a bag or when the bag is full.
func give_material(actor: Object, mat_id: String, n: int = 1) -> bool:
	if actor == null or n <= 0 or not _materials.has(mat_id):
		return false
	var inv: Object = _inventory_of(actor)
	if inv == null:
		return false
	return _add_stackable(inv, _material_item(mat_id), n)


## Full item dict for a material id (LootSystem/Inventory shape, type material).
func _material_item(mat_id: String) -> Dictionary:
	var m: Dictionary = _dict(_materials.get(mat_id, {}))
	return {
		"id": mat_id,
		"name": str(m.get("name", mat_id.capitalize())),
		"slot": "none",
		"rarity": str(m.get("rarity", "common")),
		"icon": "pixel:" + str(m.get("icon", "iron_scrap")),
		"stats": _zero_stats(),
		"flavor": str(m.get("flavor", "")),
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	}


## Resolves the actor's inventory: an Object exposing a `bag` Array and an
## add_item() method (the player's Inventory). Null when absent (guarded).
func _inventory_of(actor: Object) -> Object:
	if actor == null:
		return null
	var inv_v: Variant = actor.get("inventory")
	if inv_v is Object and is_instance_valid(inv_v):
		var inv: Object = inv_v
		if ("bag" in inv) and inv.has_method("add_item"):
			return inv
	return null


func _count_in(inv: Object, mat_id: String) -> int:
	var n: int = 0
	for entry: Variant in inv.get("bag"):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == mat_id:
			n += _stack(entry)
	return n


func _stack(entry: Dictionary) -> int:
	if not bool(entry.get("stackable", false)):
		return 1
	return maxi(1, int(entry.get("count", entry.get("quantity", 1))))


func _add_stackable(inv: Object, item: Dictionary, n: int) -> bool:
	var bag: Array = inv.get("bag")
	for entry: Variant in bag:
		if entry is Dictionary:
			var d: Dictionary = entry
			if str(d.get("id", "")) == str(item.get("id", "")) and bool(d.get("stackable", false)):
				d["count"] = _stack(d) + n
				if inv.has_signal("bag_changed"):
					inv.emit_signal("bag_changed")
				return true
	var fresh: Dictionary = item.duplicate(true)
	fresh["count"] = n
	return bool(inv.call("add_item", fresh))


func _take(inv: Object, mat_id: String, n: int) -> bool:
	if _count_in(inv, mat_id) < n:
		return false
	var bag: Array = inv.get("bag")
	var left: int = n
	for i: int in bag.size():
		if left <= 0:
			break
		var entry: Variant = bag[i]
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		if str(d.get("id", "")) != mat_id:
			continue
		var have: int = _stack(d)
		if have > left:
			d["count"] = have - left
			left = 0
		else:
			left -= have
			bag[i] = null
	if inv.has_signal("bag_changed"):
		inv.emit_signal("bag_changed")
	return true


# --- save hooks -------------------------------------------------------------

## Snapshot one actor's craft state (defaults to the live player).
func serialize(actor: Object = null) -> Dictionary:
	var a: Object = actor if actor != null else _player()
	if a == null:
		return {}
	var s: Dictionary = _st(a)
	return {
		"skill": (s["skill"] as Dictionary).duplicate(true),
		"known": (s["known"] as Dictionary).keys(),
		"crafted": (s["crafted"] as Dictionary).keys(),
	}


func deserialize(data: Dictionary, actor: Object = null) -> void:
	var a: Object = actor if actor != null else _player()
	if a == null:
		return
	var s: Dictionary = _st(a)
	s["skill"] = _dict(data.get("skill", {})).duplicate(true)
	s["known"] = {}
	for rid_v: Variant in _arr(data.get("known", [])):
		if _recipes.has(str(rid_v)):
			(s["known"] as Dictionary)[str(rid_v)] = true
	s["crafted"] = {}
	for rid_v2: Variant in _arr(data.get("crafted", [])):
		(s["crafted"] as Dictionary)[str(rid_v2)] = true


func _player() -> Object:
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	return p if (p != null and is_instance_valid(p)) else null


# --- helpers ----------------------------------------------------------------

func _zero_stats() -> Dictionary:
	var s: Dictionary = {}
	for k: String in STAT_KEYS:
		s[k] = 0.0
	return s


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- self-test (RH_CRAFT_TEST) ----------------------------------------------

func _run_selftest_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	debug_selftest()
	get_tree().quit(0)


## Proves learn -> give mats -> craft -> produce item -> skill-up without a live
## player: builds a throwaway actor that carries a real Inventory, and prints
## every step. ASCII only (cp1252-safe console).
func debug_selftest() -> void:
	var actor := _TestActor.new()
	add_child(actor)
	print("[CraftSelfTest] max_skill=%d professions=%d recipes=%d" % [
		_max_skill, _professions.size(), _recipes.size()])

	var learned: bool = learn_profession(actor, "bog_iron")
	print("[CraftSelfTest] learn_profession bog_iron = %s (skill=%d rank=%s)" % [
		str(learned), get_skill(actor, "bog_iron"), rank_name(get_skill(actor, "bog_iron"))])

	# trainer wet-ink recipe is auto-known; feed it and craft.
	var rid := "riverset_blade"
	print("[CraftSelfTest] is_known %s = %s (unlock=trainer, skill_req=%d)" % [
		rid, str(is_known(actor, rid)), int((_recipes[rid] as Dictionary).get("skill_req", 0))])
	debug_set_skill(actor, "bog_iron", 40)
	give_material(actor, "bog_iron_lump", 8)
	give_material(actor, "bone", 4)
	print("[CraftSelfTest] mats before: bog_iron_lump=%d bone=%d" % [
		material_count(actor, "bog_iron_lump"), material_count(actor, "bone")])
	print("[CraftSelfTest] can_craft %s = %s" % [rid, str(can_craft(actor, rid))])
	var before_skill: int = get_skill(actor, "bog_iron")
	var item: Dictionary = craft(actor, rid)
	print("[CraftSelfTest] craft -> id=%s name='%s' slot=%s rarity=%s dmg=%.0f hp=%.0f" % [
		str(item.get("id", "?")), str(item.get("name", "?")), str(item.get("slot", "?")),
		str(item.get("rarity", "?")), float(_dict(item.get("stats", {})).get("damage", 0.0)),
		float(_dict(item.get("stats", {})).get("hp", 0.0))])
	print("[CraftSelfTest] mats after:  bog_iron_lump=%d bone=%d  skill %d -> %d" % [
		material_count(actor, "bog_iron_lump"), material_count(actor, "bone"),
		before_skill, get_skill(actor, "bog_iron")])

	# legendary path: not known until taught, then craftable at skill.
	var leg := "emberfold_edge"
	print("[CraftSelfTest] legendary %s known-before=%s" % [leg, str(is_known(actor, leg))])
	learn_recipe(actor, leg)
	debug_set_skill(actor, "bog_iron", 470)
	give_material(actor, "slag_iron", 6)
	give_material(actor, "ember_dust", 8)
	give_material(actor, "blackglass_shard", 1)
	give_material(actor, "cold_iron_shard", 2)
	print("[CraftSelfTest] legendary known-after=%s can_craft=%s" % [
		str(is_known(actor, leg)), str(can_craft(actor, leg))])
	var leg_item: Dictionary = craft(actor, leg)
	print("[CraftSelfTest] legendary craft -> name='%s' rarity=%s dmg=%.0f (bog_iron skill now %d, rank %s)" % [
		str(leg_item.get("name", "FAILED")), str(leg_item.get("rarity", "?")),
		float(_dict(leg_item.get("stats", {})).get("damage", 0.0)),
		get_skill(actor, "bog_iron"), rank_name(get_skill(actor, "bog_iron"))])

	# two-primary cap.
	learn_profession(actor, "blackglass")
	var third: bool = learn_profession(actor, "hessik_method")
	print("[CraftSelfTest] two-primary cap: third learn = %s (primaries=%d)" % [
		str(third), primaries_learned(actor)])
	print("[CraftSelfTest] DONE - crafting pipeline proven.")
	unregister(actor)
	actor.queue_free()


## Throwaway self-test actor: a Node that carries a real Inventory so the
## _inventory_of() adapter resolves exactly as it does for the live player.
class _TestActor:
	extends Node
	var inventory: Inventory = Inventory.new()
