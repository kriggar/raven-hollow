class_name Inventory
extends RefCounted
## Player inventory data for Raven Hollow: Emberfall — Phase B.
## Pure data + logic, NO UI code (BagUI / CharacterSheetUI render this).
##
## Layout:
##   bag: Array of BAG_SIZE (20) entries, each null or an item Dictionary
##     (shape per Items: {id, name, slot, rarity, icon, stats, flavor, effect}).
##   equipped: Dictionary equip-slot name -> item Dictionary | null, with the
##     nine slots head/chest/legs/boots/main_hand/off_hand/ring1/ring2/trinket.
##
## Item "slot" values are TYPES (head/chest/legs/boots/main_hand/off_hand/
## ring/trinket/none); note "ring" items fit either of the ring1/ring2
## equip slots, and "none" items fit nowhere (junk / quest flavor).
##
## Signals are emitted AFTER state fully settles, so handlers always read a
## consistent bag + equipped. Mutating funcs return false (and emit nothing)
## when the operation is invalid or impossible.

signal bag_changed
signal equipment_changed

const BAG_SIZE: int = 20
const EQUIP_SLOTS: Array[String] = [
	"head", "chest", "legs", "boots",
	"main_hand", "off_hand", "ring1", "ring2", "trinket",
]
## The six base item stats plus "mana_regen" (extra stat carried by the
## Gravekeeper's Band per the user-approved spec — must reach the player).
const STAT_KEYS: Array[String] = [
	"damage", "armor", "hp", "mana", "speed_pct", "crit_pct", "mana_regen",
]

var bag: Array = []
var equipped: Dictionary = {}


func _init() -> void:
	bag.resize(BAG_SIZE)  # resize fills with null
	for slot: String in EQUIP_SLOTS:
		equipped[slot] = null


## Puts `item` into the first empty bag slot. False when the bag is full.
func add_item(item: Dictionary) -> bool:
	var idx: int = _first_empty_bag_slot()
	if idx < 0:
		return false
	bag[idx] = item
	bag_changed.emit()
	return true


## Equips the item at `bag_idx`. When `target_slot` is "" the slot is
## auto-picked from the item's slot type (rings prefer ring1, then ring2;
## both full -> swap with ring1). An occupied target slot swaps its item
## back into the SAME bag slot the equipped item came from.
func equip_from_bag(bag_idx: int, target_slot: String = "") -> bool:
	if bag_idx < 0 or bag_idx >= BAG_SIZE:
		return false
	var entry: Variant = bag[bag_idx]
	if not (entry is Dictionary):
		return false
	var item: Dictionary = entry
	var slot: String = target_slot
	if slot == "":
		slot = _auto_slot_for(item)
	if slot == "" or not slot_accepts(slot, item):
		return false
	var swapped: Variant = equipped.get(slot)  # null or the displaced item
	equipped[slot] = item
	bag[bag_idx] = swapped
	bag_changed.emit()
	equipment_changed.emit()
	return true


## Moves the item in equip slot `slot` back to the first empty bag slot.
## False when the slot name is unknown / empty or the bag is full.
func unequip_to_bag(slot: String) -> bool:
	if not equipped.has(slot):
		return false
	var entry: Variant = equipped.get(slot)
	if entry == null:
		return false
	var idx: int = _first_empty_bag_slot()
	if idx < 0:
		return false
	bag[idx] = entry
	equipped[slot] = null
	bag_changed.emit()
	equipment_changed.emit()
	return true


## Drag helper (extra, not in the base contract): unequip `slot` onto a
## SPECIFIC bag slot. Empty target -> move; target occupied by an item that
## also fits `slot` -> swap in place; otherwise false.
func unequip_to_bag_index(slot: String, bag_idx: int) -> bool:
	if not equipped.has(slot):
		return false
	if bag_idx < 0 or bag_idx >= BAG_SIZE:
		return false
	var entry: Variant = equipped.get(slot)
	if entry == null:
		return false
	var target: Variant = bag[bag_idx]
	if target == null:
		bag[bag_idx] = entry
		equipped[slot] = null
	elif target is Dictionary and slot_accepts(slot, target):
		bag[bag_idx] = entry
		equipped[slot] = target
	else:
		return false
	bag_changed.emit()
	equipment_changed.emit()
	return true


## Drag helper (extra, not in the base contract): move/swap two bag slots
## (dropping onto an empty slot moves, onto an occupied slot swaps).
func swap_bag_slots(a: int, b: int) -> bool:
	if a < 0 or a >= BAG_SIZE or b < 0 or b >= BAG_SIZE:
		return false
	if a == b:
		return true
	var tmp: Variant = bag[a]
	bag[a] = bag[b]
	bag[b] = tmp
	bag_changed.emit()
	return true


## Sum of all equipped items' stats. ALWAYS returns every STAT_KEYS key
## (damage/armor/hp/mana/speed_pct/crit_pct + mana_regen) as a float, 0.0
## when nothing contributes — safe to read without .get fallbacks.
func stat_totals() -> Dictionary:
	var totals: Dictionary = {
		"damage": 0.0,
		"armor": 0.0,
		"hp": 0.0,
		"mana": 0.0,
		"speed_pct": 0.0,
		"crit_pct": 0.0,
		"mana_regen": 0.0,
	}
	for slot: String in EQUIP_SLOTS:
		var entry: Variant = equipped.get(slot)
		if not (entry is Dictionary):
			continue
		var stats: Dictionary = entry.get("stats", {})
		for key: String in STAT_KEYS:
			totals[key] = float(totals[key]) + float(stats.get(key, 0.0))
	return totals


## True when `item` may sit in equip slot `slot_name`. Ring-type items
## ("slot": "ring") fit ring1 AND ring2; every other type only fits the
## slot with its own name; "none" fits nothing; unknown slot names fail.
static func slot_accepts(slot_name: String, item: Dictionary) -> bool:
	var kind: String = str(item.get("slot", "none"))
	if kind == "none":
		return false
	if slot_name == "ring1" or slot_name == "ring2":
		return kind == "ring"
	return EQUIP_SLOTS.has(slot_name) and slot_name == kind


## Count of empty bag slots (handy for "bag full" UI feedback).
func free_slots() -> int:
	var n: int = 0
	for entry: Variant in bag:
		if entry == null:
			n += 1
	return n


func _first_empty_bag_slot() -> int:
	for i: int in BAG_SIZE:
		if bag[i] == null:
			return i
	return -1


## Auto-picked equip slot for `item`, "" when it cannot be equipped.
## Rings prefer the first EMPTY of ring1/ring2 and fall back to ring1
## (swap) when both are occupied.
func _auto_slot_for(item: Dictionary) -> String:
	var kind: String = str(item.get("slot", "none"))
	if kind == "none":
		return ""
	if kind == "ring":
		if equipped.get("ring1") == null:
			return "ring1"
		if equipped.get("ring2") == null:
			return "ring2"
		return "ring1"
	if EQUIP_SLOTS.has(kind):
		return kind
	return ""


## Shared drag state for the custom (non-OS) drag & drop between BagUI and
## CharacterSheetUI. A drag begins by setting all three fields and ends by
## clear(); UIs draw their own ghost icon — Godot's _get_drag_data is NOT
## used so we keep full control of the pixel look.
class DragCtx:
	## The item Dictionary being dragged (null = no drag in progress).
	static var item: Variant = null
	## Where the drag started: "bag" or "equip" ("" = no drag).
	static var from_kind: String = ""
	## Bag index (int) when from_kind == "bag", equip slot name (String)
	## when from_kind == "equip", null otherwise.
	static var from_key: Variant = null

	static func begin(drag_item: Dictionary, kind: String, key: Variant) -> void:
		item = drag_item
		from_kind = kind
		from_key = key

	static func clear() -> void:
		item = null
		from_kind = ""
		from_key = null

	static func active() -> bool:
		return item != null
