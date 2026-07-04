class_name Crafting
## Crafting slice for Raven Hollow: Emberfall — Phase C demo (SPEC_PHASE_C_DEMO.md §6b).
## Pure static data + logic, no scene code (mirrors items.gd / class_defs.gd).
##
## items.gd has no "material"/"consumable"/"recipe" item types, and it may NOT
## be edited by this pass — so those item dicts are defined HERE in the exact
## same shape Items uses ({id, name, slot, rarity, icon, stats, flavor,
## stackable, effect}) plus two extra keys the rest of the game safely
## ignores:
##   type:  "material" | "consumable" | "recipe"   (absent on crafted gear —
##          an item without "type" is ordinary equipment)
##   count: int stack size (only meaningful when stackable == true)
## All crafting items flow through Inventory.add_item UNCHANGED — slot is
## "none" so they can never be equipped, Inventory/BagUI/ItemTooltip treat
## them like any junk-slot item, and stacking is layered on top by this class
## alone (grant/_take mutate "count" on the bag dicts and emit
## inv.bag_changed so the UIs repaint; Inventory itself needs no edits).
##
## Recipe knowledge is session-global static state (one player), same pattern
## as Inventory.DragCtx: _known survives map changes and serializes into the
## save via serialize()/deserialize(). reset() restores the fresh-start set
## for New Game.
##
## ============================= INTEGRATION =============================
## Hooks EXPECTED from the integration pass (this file compiles and works
## standalone; nothing below is required for --check-only):
##
## 1. icons_pixel.gd — add these entries to IconsPixel.REGISTRY (cells
##    PIL-verified on shikashi_v2.png at 4x, same 16-col/32px grid):
##        "wolf_pelt": Vector2i(5, 17),        # pale fur wad (cotton cell)
##        "boar_hide": Vector2i(8, 17),        # stretched brown hide
##        "bone": Vector2i(11, 16),            # white skeleton bones
##        "ember_dust": Vector2i(4, 20),       # rust-red powder pile
##        "iron_scrap": Vector2i(11, 19),      # rusted iron billet
##        "healing_draught": Vector2i(4, 9),   # red potion, green cross
##        "hunters_stew": Vector2i(9, 19),     # dark iron cauldron
##        "recipe_wolf_fang_dagger": Vector2i(4, 21),  # sparkle scroll, teal ribbon
##        "recipe_hunters_stew": Vector2i(1, 21),      # sparkle scroll, green ribbon
##        "iron_sword": Vector2i(1, 5),        # plain steel sword
##        "boarhide_jerkin": Vector2i(6, 7),   # ribbed leather cuirass (NOTE:
##                                             #  shared with patched_jerkin —
##                                             #  re-pick if the double-use reads
##                                             #  badly in the bag)
##        "bone_ring": Vector2i(8, 8),         # fang-and-bone talisman
##        "wolf_fang_dagger": Vector2i(7, 5),  # dark fanged dagger
##    Until then the SAME cells ship here as FALLBACK_ICON_CELLS and
##    Crafting.icon_texture() serves them, so CraftingUI renders icons NOW;
##    BagUI (which resolves item["icon"] through IconsPixel only) shows these
##    items iconless until the registry entries land.
##
## 2. enemy.gd (die path) — in _die(), before/with the death anim:
##        var player: Node = get_tree().get_first_node_in_group("player")
##        var inv_v: Variant = player.get("inventory") if player != null else null
##        if inv_v is Inventory:
##            var got: Array[Dictionary] = Crafting.drop_for_kill(inv_v, type_name)
##            # optional: toast each item via the "crafting_ui" group node's
##            # show_toast("+ " + str(item["name"])) — see crafting_ui.gd.
##    drop_for_kill resolves type_name prefixes itself ("skeleton_mage" ->
##    skeleton table, "orc_shaman" -> orc, wolf/boar/bear incl. "Old Mother").
##
## 3. bag_ui.gd (right-click) — in _on_slot_gui_input's RIGHT branch, BEFORE
##    _auto_equip(idx):
##        var it_v: Variant = _bag_item(idx)
##        if it_v is Dictionary:
##            var kind: String = str((it_v as Dictionary).get("type", ""))
##            if kind == "consumable":
##                Crafting.use_consumable(
##                    get_tree().get_first_node_in_group("player"), _inv, idx)
##                return
##            if kind == "recipe":
##                var rid: String = Crafting.learn_from_scroll(_inv, idx)
##                # toast "Recipe learned: %s" % Crafting.recipe_name(rid) on
##                # success, "Already known." when rid == "" — via crafting_ui.
##                return
##    Optional polish: a small stack-count label per bag slot when
##    Crafting.stack_count(item) > 1 (materials stack; equipment never does).
##
## 4. player.gd (optional) — func apply_regen_buff(per_second: float,
##    duration: float): if present it is preferred for hunters_stew so the
##    WoW buff tracker can show the buff; when absent this file attaches a
##    self-contained "StewRegen" child node to the player instead (works
##    today, invisible to the tracker).
##
## 5. save_system.gd — persist Crafting.serialize() (known recipes) and call
##    Crafting.deserialize(d) on load / Crafting.reset() on New Game. When
##    rebuilding bag items from ids, resolve through Items.get_item first and
##    fall back to Crafting.get_item; store {"id": id, "count": n} for
##    stackables and restore the count onto the rebuilt dict.
##
## 6. Quest/world hooks — quest 2 reward materials: e.g.
##    Crafting.grant(inv, "boar_hide", 2); hunter's-camp chest loot:
##    Crafting.grant(inv, "recipe_hunters_stew", 1). "Old Mother" already
##    drops recipe_wolf_fang_dagger via the bear drop table.
## =======================================================================

## Gold flow / rarity language matches items.gd; flavors follow the Draconia
## tone law (dread is ambient, no clean wins).

const MATERIALS := {
	"wolf_pelt": {
		"id": "wolf_pelt",
		"name": "Wolf Pelt",
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:wolf_pelt",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Grey as the hour they hunt in.",
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	},
	"boar_hide": {
		"id": "boar_hide",
		"name": "Boar Hide",
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:boar_hide",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Thick enough to turn a thorn. Or a knife, once.",
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	},
	"bone": {
		"id": "bone",
		"name": "Bone",
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:bone",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Dry, light, patient.",
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	},
	"ember_dust": {
		"id": "ember_dust",
		"name": "Ember Dust",
		"slot": "none",
		"rarity": "uncommon",
		"icon": "pixel:ember_dust",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "It keeps a warmth the fire never gave it.",
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	},
	"iron_scrap": {
		"id": "iron_scrap",
		"name": "Iron Scrap",
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:iron_scrap",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Orc-struck. Ugly work, honest metal.",
		"stackable": true,
		"effect": "",
		"type": "material",
		"count": 1,
	},
}

## Consumables carry "use_effect" (read only by use_consumable below):
##   {kind: "heal", amount}                — instant health
##   {kind: "regen_hp", amount, duration}  — health per second for duration
const CONSUMABLES := {
	"healing_draught": {
		"id": "healing_draught",
		"name": "Healing Draught",
		"slot": "none",
		"rarity": "uncommon",
		"icon": "pixel:healing_draught",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Bitter, red, and quick about its business.",
		"stackable": true,
		"effect": "",
		"type": "consumable",
		"count": 1,
		"use_effect": {"kind": "heal", "amount": 40.0},
	},
	"hunters_stew": {
		"id": "hunters_stew",
		"name": "Hunter's Stew",
		"slot": "none",
		"rarity": "common",
		"icon": "pixel:hunters_stew",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Eat it hot. The woods notice the ones who go hungry.",
		"stackable": true,
		"effect": "",
		"type": "consumable",
		"count": 1,
		"use_effect": {"kind": "regen_hp", "amount": 2.0, "duration": 60.0},
	},
}

## Right-click to LEARN ("teaches" names the recipe id). Consumed on learn.
const RECIPE_SCROLLS := {
	"recipe_wolf_fang_dagger": {
		"id": "recipe_wolf_fang_dagger",
		"name": "Recipe: Wolf-Fang Dagger",
		"slot": "none",
		"rarity": "rare",
		"icon": "pixel:recipe_wolf_fang_dagger",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "The hand that wrote this pressed too hard.",
		"stackable": true,
		"effect": "",
		"type": "recipe",
		"count": 1,
		"teaches": "wolf_fang_dagger",
	},
	"recipe_hunters_stew": {
		"id": "recipe_hunters_stew",
		"name": "Recipe: Hunter's Stew",
		"slot": "none",
		"rarity": "uncommon",
		"icon": "pixel:recipe_hunters_stew",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "A tidy hand. The margins list what the woods took in trade.",
		"stackable": true,
		"effect": "",
		"type": "recipe",
		"count": 1,
		"teaches": "hunters_stew",
	},
}

## Craftable equipment outputs (not in Items._DB; same exact shape, no
## "type" key — an item without "type" is ordinary gear end to end).
const CRAFTED_GEAR := {
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"slot": "main_hand",
		"rarity": "uncommon",
		"icon": "pixel:iron_sword",
		"stats": {"damage": 5.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Goran's plain pattern. It holds an edge and asks no questions.",
		"stackable": false,
		"effect": "",
	},
	"boarhide_jerkin": {
		"id": "boarhide_jerkin",
		"name": "Boarhide Jerkin",
		"slot": "chest",
		"rarity": "uncommon",
		"icon": "pixel:boarhide_jerkin",
		"stats": {"damage": 0.0, "armor": 3.0, "hp": 10.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Bristle-backed leather. Smells of the wallow when it rains.",
		"stackable": false,
		"effect": "",
	},
	"bone_ring": {
		"id": "bone_ring",
		"name": "Bone Ring",
		"slot": "ring",
		"rarity": "common",
		"icon": "pixel:bone_ring",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 8.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "The marrow remembers being warm.",
		"stackable": false,
		"effect": "",
	},
	"wolf_fang_dagger": {
		"id": "wolf_fang_dagger",
		"name": "Wolf-Fang Dagger",
		"slot": "main_hand",
		"rarity": "rare",
		"icon": "pixel:wolf_fang_dagger",
		"stats": {"damage": 5.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 10.0},
		"flavor": "The edge stays keen. Everything that stays sharp is waiting for something.",
		"stackable": false,
		"effect": "",
	},
}

## Recipe defs, keyed AND named by their output item id. Insertion order is
## the station panel's list order. "scroll" names the RECIPE_SCROLLS item
## that teaches a not-start_known recipe.
const RECIPES := {
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"station": "forge",
		"output": "iron_sword",
		"cost": {"iron_scrap": 3, "bone": 1},
		"start_known": true,
	},
	"boarhide_jerkin": {
		"id": "boarhide_jerkin",
		"name": "Boarhide Jerkin",
		"station": "forge",
		"output": "boarhide_jerkin",
		"cost": {"boar_hide": 3},
		"start_known": true,
	},
	"bone_ring": {
		"id": "bone_ring",
		"name": "Bone Ring",
		"station": "forge",
		"output": "bone_ring",
		"cost": {"bone": 2},
		"start_known": true,
	},
	"wolf_fang_dagger": {
		"id": "wolf_fang_dagger",
		"name": "Wolf-Fang Dagger",
		"station": "forge",
		"output": "wolf_fang_dagger",
		"cost": {"wolf_pelt": 2, "bone": 2, "iron_scrap": 1},
		"start_known": false,
		"scroll": "recipe_wolf_fang_dagger",
	},
	"healing_draught": {
		"id": "healing_draught",
		"name": "Healing Draught",
		"station": "hearth",
		"output": "healing_draught",
		"cost": {"wolf_pelt": 1, "ember_dust": 1},
		"start_known": true,
	},
	"hunters_stew": {
		"id": "hunters_stew",
		"name": "Hunter's Stew",
		"station": "hearth",
		"output": "hunters_stew",
		"cost": {"boar_hide": 1, "bone": 1},
		"start_known": false,
		"scroll": "recipe_hunters_stew",
	},
}

## Kill-drop tables per enemy family (spec: generous, 60-80%). The bear —
## "Old Mother" — always yields the dagger recipe scroll plus two pelts.
const DROP_TABLES := {
	"wolf": [{"id": "wolf_pelt", "chance": 0.75}],
	"boar": [{"id": "boar_hide", "chance": 0.75}],
	"skeleton": [{"id": "bone", "chance": 0.75}, {"id": "ember_dust", "chance": 0.6}],
	"orc": [{"id": "iron_scrap", "chance": 0.7}],
	"bear": [
		{"id": "recipe_wolf_fang_dagger", "chance": 1.0},
		{"id": "wolf_pelt", "chance": 1.0},
		{"id": "wolf_pelt", "chance": 1.0},
	],
}

## Local Shikashi cells for icon ids not (yet) in IconsPixel.REGISTRY —
## the exact cells the INTEGRATION block asks the integrator to promote.
## icon_texture() prefers the registry, so promoted entries win automatically.
const FALLBACK_ICON_CELLS := {
	"wolf_pelt": Vector2i(5, 17),
	"boar_hide": Vector2i(8, 17),
	"bone": Vector2i(11, 16),
	"ember_dust": Vector2i(4, 20),
	"iron_scrap": Vector2i(11, 19),
	"healing_draught": Vector2i(4, 9),
	"hunters_stew": Vector2i(9, 19),
	"recipe_wolf_fang_dagger": Vector2i(4, 21),
	"recipe_hunters_stew": Vector2i(1, 21),
	"iron_sword": Vector2i(1, 5),
	"boarhide_jerkin": Vector2i(6, 7),
	"bone_ring": Vector2i(8, 8),
	"wolf_fang_dagger": Vector2i(7, 5),
}

const _SHEET_PATH := "res://assets/art/icons_pixel/shikashi_v2.png"
const _CELL: int = 32

static var _known: Dictionary = {}
static var _known_seeded: bool = false
static var _fallback_cache: Dictionary = {}


# --- item lookup ---------------------------------------------------------------

## Deep copy of any crafting-owned item (material / consumable / recipe
## scroll / crafted gear); unknown ids fall through to Items.get_item so one
## call resolves EVERY item id in the game (save-load convenience).
static func get_item(id: String) -> Dictionary:
	for db: Dictionary in [MATERIALS, CONSUMABLES, RECIPE_SCROLLS, CRAFTED_GEAR]:
		if db.has(id):
			var src: Dictionary = db[id]
			return src.duplicate(true)
	return Items.get_item(id)


static func has_item(id: String) -> bool:
	return MATERIALS.has(id) or CONSUMABLES.has(id) \
		or RECIPE_SCROLLS.has(id) or CRAFTED_GEAR.has(id)


## Stack size of a bag item dict (1 for anything non-stackable / untagged).
static func stack_count(item: Dictionary) -> int:
	if not bool(item.get("stackable", false)):
		return 1
	return maxi(1, int(item.get("count", 1)))


# --- known-recipes set ---------------------------------------------------------

static func _ensure_known() -> void:
	if _known_seeded:
		return
	_known_seeded = true
	for id: String in RECIPES:
		if bool((RECIPES[id] as Dictionary).get("start_known", false)):
			_known[id] = true


static func is_known(recipe_id: String) -> bool:
	_ensure_known()
	return _known.has(recipe_id)


## Learns a recipe. True only when it is a real recipe that was NOT yet known.
static func learn_recipe(recipe_id: String) -> bool:
	_ensure_known()
	if not RECIPES.has(recipe_id) or _known.has(recipe_id):
		return false
	_known[recipe_id] = true
	return true


static func known_ids() -> Array[String]:
	_ensure_known()
	var out: Array[String] = []
	for id: String in RECIPES:  # RECIPES order, not learn order — stable saves
		if _known.has(id):
			out.append(id)
	return out


## Recipe defs for one station ("forge" / "hearth"), spec panel order,
## deep-copied so callers can annotate freely.
static func recipes_for_station(station_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in RECIPES:
		var r: Dictionary = RECIPES[id]
		if str(r.get("station", "")) == station_id:
			out.append(r.duplicate(true))
	return out


static func recipe_name(recipe_id: String) -> String:
	if not RECIPES.has(recipe_id):
		return ""
	return str((RECIPES[recipe_id] as Dictionary).get("name", recipe_id))


# --- save hooks ----------------------------------------------------------------

static func serialize() -> Dictionary:
	return {"known": known_ids()}


static func deserialize(data: Dictionary) -> void:
	reset()
	var ids_v: Variant = data.get("known", [])
	if ids_v is Array:
		for id_v: Variant in ids_v:
			var id: String = str(id_v)
			if RECIPES.has(id):
				_known[id] = true


## Fresh-start knowledge (New Game): only start_known recipes.
static func reset() -> void:
	_known = {}
	_known_seeded = false
	_ensure_known()


# --- inventory counting / granting ---------------------------------------------

## Total copies of item_id across the bag (stack-aware).
static func count_in(inv: Inventory, item_id: String) -> int:
	if inv == null:
		return 0
	var n: int = 0
	for entry: Variant in inv.bag:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == item_id:
			n += stack_count(entry)
	return n


## Stack-aware add: stackables merge onto an existing stack of the same id
## (mutates "count" + emits inv.bag_changed) or start a new stack; gear adds
## n separate copies through Inventory.add_item unchanged. False when the bag
## cannot hold everything (partial grants keep what fit).
static func grant(inv: Inventory, item_id: String, n: int = 1) -> bool:
	if inv == null or n <= 0:
		return false
	var template: Dictionary = get_item(item_id)
	if template.is_empty():
		return false
	if bool(template.get("stackable", false)):
		var stack: Variant = _find_stack(inv, item_id)
		if stack is Dictionary:
			(stack as Dictionary)["count"] = stack_count(stack) + n
			inv.bag_changed.emit()
			return true
		template["count"] = n
		return inv.add_item(template)
	var ok: bool = true
	for _i: int in n:
		if not inv.add_item(get_item(item_id)):
			ok = false
	return ok


static func _find_stack(inv: Inventory, item_id: String) -> Variant:
	for entry: Variant in inv.bag:
		if entry is Dictionary:
			var d: Dictionary = entry
			if str(d.get("id", "")) == item_id and bool(d.get("stackable", false)):
				return d
	return null


## Removes n copies of item_id from the bag (across stacks/slots). False and
## NO change when the bag holds fewer than n.
static func _take(inv: Inventory, item_id: String, n: int) -> bool:
	if inv == null or count_in(inv, item_id) < n:
		return false
	var left: int = n
	for i: int in inv.bag.size():
		if left <= 0:
			break
		var entry: Variant = inv.bag[i]
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		if str(d.get("id", "")) != item_id:
			continue
		var have: int = stack_count(d)
		if have > left:
			d["count"] = have - left
			left = 0
		else:
			left -= have
			inv.bag[i] = null
	inv.bag_changed.emit()
	return true


# --- craft logic ---------------------------------------------------------------

## True when the recipe is known AND every material is in the bag. (Bag room
## for the output is checked by craft itself — consuming materials can free
## the needed slot, so pre-checking here would wrongly grey valid crafts.)
static func can_craft(recipe_id: String, inv: Inventory) -> bool:
	_ensure_known()
	if inv == null or not RECIPES.has(recipe_id) or not _known.has(recipe_id):
		return false
	var cost: Dictionary = (RECIPES[recipe_id] as Dictionary).get("cost", {})
	for mat_id: String in cost:
		if count_in(inv, mat_id) < int(cost[mat_id]):
			return false
	return true


## Consumes the materials and puts the output in the bag. Returns the crafted
## item dict, or {} on any failure (unknown/unlearned recipe, missing
## materials, or a full bag — in which case the materials are refunded).
static func craft(recipe_id: String, inv: Inventory) -> Dictionary:
	if not can_craft(recipe_id, inv):
		return {}
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.get("cost", {})
	for mat_id: String in cost:
		_take(inv, mat_id, int(cost[mat_id]))
	var output_id: String = str(recipe.get("output", recipe_id))
	if not grant(inv, output_id, 1):
		for mat_id: String in cost:  # bag full: put the materials back
			grant(inv, mat_id, int(cost[mat_id]))
		return {}
	return get_item(output_id)


# --- consumables / scrolls -----------------------------------------------------

## Right-click-in-bag hook: applies the consumable at bag_idx to `user` (the
## player; duck-typed hp/max_hp) and removes one from the stack. False when
## the slot is not a consumable, the user is dead/invalid, or nothing to do.
static func use_consumable(user: Node, inv: Inventory, bag_idx: int) -> bool:
	if user == null or inv == null or bag_idx < 0 or bag_idx >= inv.bag.size():
		return false
	var entry: Variant = inv.bag[bag_idx]
	if not (entry is Dictionary):
		return false
	var item: Dictionary = entry
	if str(item.get("type", "")) != "consumable":
		return false
	var fx: Dictionary = item.get("use_effect", {})
	var applied: bool = false
	match str(fx.get("kind", "")):
		"heal":
			applied = _apply_heal(user, float(fx.get("amount", 0.0)))
		"regen_hp":
			applied = _apply_regen(
				user, float(fx.get("amount", 0.0)), float(fx.get("duration", 0.0)))
	if not applied:
		return false
	_consume_one_at(inv, bag_idx)
	return true


## Right-click-in-bag hook: learns the recipe scroll at bag_idx. Returns the
## learned recipe id ("" when the slot is no scroll or the recipe is already
## known — an already-known scroll is NOT consumed).
static func learn_from_scroll(inv: Inventory, bag_idx: int) -> String:
	if inv == null or bag_idx < 0 or bag_idx >= inv.bag.size():
		return ""
	var entry: Variant = inv.bag[bag_idx]
	if not (entry is Dictionary):
		return ""
	var item: Dictionary = entry
	if str(item.get("type", "")) != "recipe":
		return ""
	var teaches: String = str(item.get("teaches", ""))
	if not learn_recipe(teaches):
		return ""
	_consume_one_at(inv, bag_idx)
	return teaches


static func _consume_one_at(inv: Inventory, bag_idx: int) -> void:
	var entry: Variant = inv.bag[bag_idx]
	if not (entry is Dictionary):
		return
	var d: Dictionary = entry
	var have: int = stack_count(d)
	if have > 1:
		d["count"] = have - 1
	else:
		inv.bag[bag_idx] = null
	inv.bag_changed.emit()


static func _apply_heal(user: Node, amount: float) -> bool:
	var hp_v: Variant = user.get("hp")
	var max_v: Variant = user.get("max_hp")
	if not (hp_v is float) or not (max_v is float):
		return false
	if float(hp_v) <= 0.0:
		return false  # draughts do not argue with the dead
	user.set("hp", minf(float(hp_v) + amount, float(max_v)))
	return true


## Prefers player.apply_regen_buff(per_second, duration) (integration hook —
## shows in the buff tracker); otherwise attaches/refreshes a self-contained
## StewRegen child node so the buff works pre-integration.
static func _apply_regen(user: Node, per_second: float, duration: float) -> bool:
	if per_second <= 0.0 or duration <= 0.0:
		return false
	var hp_v: Variant = user.get("hp")
	if hp_v is float and float(hp_v) <= 0.0:
		return false
	if user.has_method("apply_regen_buff"):
		user.call("apply_regen_buff", per_second, duration)
		return true
	var existing: Node = user.get_node_or_null(NodePath("StewRegen"))
	if existing is RegenNode:
		(existing as RegenNode).per_second = per_second
		(existing as RegenNode).time_left = duration  # re-eating refreshes
		return true
	var node := RegenNode.new()
	node.name = "StewRegen"
	node.per_second = per_second
	node.time_left = duration
	user.add_child(node)
	return true


# --- kill drops ------------------------------------------------------------------

## Rolls the drop table for an enemy type_name. Pure roll, no inventory.
static func roll_drops(enemy_type: String) -> Array[String]:
	var out: Array[String] = []
	var family: String = _drop_family(enemy_type)
	if family.is_empty():
		return out
	var table: Array = DROP_TABLES.get(family, [])
	for row_v: Variant in table:
		var row: Dictionary = row_v
		if randf() <= float(row.get("chance", 0.0)):
			out.append(str(row.get("id", "")))
	return out


## enemy.gd _die() hook: rolls AND grants in one call; returns the granted
## item dicts (for loot toasts). A full bag silently drops the overflow —
## acceptable demo behavior.
static func drop_for_kill(inv: Inventory, enemy_type: String) -> Array[Dictionary]:
	var granted: Array[Dictionary] = []
	if inv == null:
		return granted
	for id: String in roll_drops(enemy_type):
		if grant(inv, id, 1):
			granted.append(get_item(id))
	return granted


## Maps enemy.gd type_name spellings onto a drop family: every skeleton_* /
## orc_* variant shares its family table; the bear answers to "bear",
## "grizzly" or the "Old Mother" nameplate spelling.
static func _drop_family(enemy_type: String) -> String:
	var t: String = enemy_type.to_lower()
	if t.begins_with("skeleton"):
		return "skeleton"
	if t.begins_with("orc"):
		return "orc"
	if t.begins_with("wolf"):
		return "wolf"
	if t.begins_with("boar"):
		return "boar"
	if t.contains("bear") or t.contains("grizzly") or t.contains("mother"):
		return "bear"
	return ""


# --- icons ---------------------------------------------------------------------

## Icon for any "pixel:<id>" / bare id: IconsPixel.REGISTRY first (so
## promoted entries win), then FALLBACK_ICON_CELLS on the same Shikashi
## sheet. Null when neither knows the id (callers show their placeholder).
static func icon_texture(icon_id: String) -> Texture2D:
	var id: String = icon_id.trim_prefix("pixel:")
	if IconsPixel.has_icon(id):
		return IconsPixel.get_tex(id)
	if _fallback_cache.has(id):
		return _fallback_cache[id]
	if not FALLBACK_ICON_CELLS.has(id):
		_fallback_cache[id] = null
		return null
	var sheet: Texture2D = load(_SHEET_PATH) as Texture2D
	if sheet == null:
		return null
	var cell: Vector2i = FALLBACK_ICON_CELLS[id]
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = Rect2(
		float(cell.x * _CELL), float(cell.y * _CELL), float(_CELL), float(_CELL))
	_fallback_cache[id] = tex
	return tex


## Self-contained hp-regen fallback for hunters_stew (used only when the
## player lacks apply_regen_buff). Child of the player; duck-types hp/max_hp,
## refuses to heal the dead, frees itself when the timer runs out.
class RegenNode:
	extends Node

	var per_second: float = 2.0
	var time_left: float = 60.0

	func _process(delta: float) -> void:
		var p: Node = get_parent()
		if p == null:
			queue_free()
			return
		var hp_v: Variant = p.get("hp")
		var max_v: Variant = p.get("max_hp")
		if hp_v is float and max_v is float and float(hp_v) > 0.0:
			p.set("hp", minf(float(hp_v) + per_second * delta, float(max_v)))
		time_left -= delta
		if time_left <= 0.0:
			queue_free()
