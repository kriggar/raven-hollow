class_name SaveSystem
## JSON save / load for Raven Hollow — Phase C demo (SPEC_PHASE_C_DEMO §6).
## Pure static logic, no scene code. One file per slot at user://save1.json
## (save2.json, ... future-proofed via the slot arg; the demo uses slot 1).
##
## On-disk shape (version SAVE_VERSION):
##   {
##     "v": 1,
##     "map": "town",                       # MapRegistry map id
##     "time_hours": 17.0,                  # day/night clock, 0..24
##     "player": {
##       "pos": [x, y], "class": "warrior",
##       "hp": 30.0, "mana": 20.0,
##       "xp": 0, "level": 1, "gold": 0
##     },
##     "inventory": {
##       "bag":      [null | item, ... x20],
##       "equipped": {"head": null | item, ... all 9 Inventory slots}
##     },
##     "quests":  { ... },                  # opaque: Quests.serialize()
##     "recipes": { ... }                   # opaque: Crafting.serialize()
##   }
##   where item == {"id": "...", "count": <int, only if stacked>,
##                  "data": <full item dict>}.
##   Reconstruction prefers a fresh Items db copy by id (so balance patches
##   reach old saves); "data" is the fallback for ids the db does not know
##   (e.g. crafting materials that live in Crafting's own db) — this makes
##   ids effectively always round-trippable. A "count" key survives either
##   path (stackable materials).
##
## Load is defensive: wrong/missing version, corrupt JSON, unknown class
## ids, unknown item ids and ill-fitting equipment all degrade with
## warnings instead of crashing; load_game() returns a NORMALIZED, typed
## dict (pos is a Vector2, ints are ints) or {} when there is no usable
## save. Enemies respawn on load (accepted demo behavior per spec).
##
## ============================= INTEGRATION =============================
## Contract for the integration pass — this file touches none of the files
## below; the integrator wires these exact hooks:
##
## 1. main.gd — current map id + autosave on travel. Add:
##        var current_map_id: String = "town"
##    (read here via get_tree().current_scene, i.e. the Main node). Inside
##    change_map(map_id, entry_point_id), AFTER the new map is built and
##    the player stands at the entry point:
##        SaveSystem.save_game()
##
## 2. main.gd — main-menu "Continue" boot flow (skips class select):
##        var data: Dictionary = SaveSystem.load_game()
##        if data.is_empty(): ... fall back to New Game ...
##        var cls: String = data["player"]["class"]
##        # build data["map"] instead of the default town, create the
##        # Player with cls at the map spawn, then:
##        SaveSystem.apply_player_state(data, player)  # pos/vitals/xp/bag
##        SaveSystem.apply_systems_state(data)         # quests/recipes/clock
##    The Continue button enables iff SaveSystem.has_save(). New Game over
##    an existing save may call SaveSystem.delete_save() (optional).
##    NOTE: apply_player_state expects load_game() OUTPUT (normalized),
##    never the raw on-disk dict, and must run AFTER the player is inside
##    the tree with its starting inventory seeded (Player.create does).
##
## 3. Pause menu — the Save button calls SaveSystem.save_game(); its bool
##    return drives a "Game saved." / "Save failed." toast.
##
## 4. quests.gd — autosave on quest turn-in: after rewards are granted,
##    call SaveSystem.save_game(). For persistence the Quests singleton
##    node joins group "quests" and implements:
##        func serialize() -> Dictionary        # JSON-safe: String keys,
##        func deserialize(d: Dictionary) -> void  # no Vector2/object refs
##                                                  # (encode positions as [x, y])
##    A STATIC serialize()/deserialize(d) pair directly on quests.gd also
##    works — the script is duck-loaded when no group node exists.
##
## 5. crafting.gd — known-recipe persistence, same contract via group
##    "crafting" (or static funcs on the script):
##        func serialize() -> Dictionary        # e.g. {"known": ["bone_ring", ...]}
##        func deserialize(d: Dictionary) -> void
##    Always wrap in a Dictionary (not a bare Array).
##
## 6. Day/night controller — joins group "day_night" and exposes EITHER
##        var time_hours: float                 # 0..24
##    OR  func get_time_hours() -> float  +  func set_time_hours(h: float) -> void.
##    Missing controller => saves 17.0 (dusk start) and skips restore.
##
## 7. player.gd — integration adds the progression fields serialized here
##    (SaveSystem degrades gracefully until they exist):
##        var xp: int = 0
##        var level: int = 1
##        var gold: int = 0
##    Already present and used today: group "player", global_position,
##    class_def["id"], hp/max_hp, mana/max_mana, inventory (Inventory),
##    _apply_equipment() (invoked indirectly via equipment_changed).
## =======================================================================

## Preloaded (not the global class name) so this file validates even before
## the editor's global-class cache has scanned the new Phase C scripts.
const XP := preload("res://scripts/xp_system.gd")

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://"
const SAVE_FILE_FMT: String = "save%d.json"
const DEFAULT_MAP: String = "town"
const DEFAULT_CLASS: String = "warrior"
const DEFAULT_TIME_HOURS: float = 17.0  # spec: the demo clock starts at dusk
const QUESTS_SCRIPT: String = "res://scripts/quests.gd"
const CRAFTING_SCRIPT: String = "res://scripts/crafting.gd"


static func save_path(slot: int = 1) -> String:
	return SAVE_DIR + SAVE_FILE_FMT % maxi(1, slot)


static func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(save_path(slot))


static func delete_save(slot: int = 1) -> void:
	var path: String = save_path(slot)
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		push_warning("SaveSystem.delete_save: cannot open %s (err %d)." % [SAVE_DIR, DirAccess.get_open_error()])
		return
	var err: int = dir.remove(path.get_file())
	if err != OK:
		push_warning("SaveSystem.delete_save: remove failed (%d) for %s." % [err, path])


## Snapshots the live game (player found via group "player") and writes it
## as pretty-printed JSON. Returns false (with a warning) when there is no
## player to save or the file cannot be written.
static func save_game(slot: int = 1) -> bool:
	var data: Dictionary = collect_state()
	if data.is_empty():
		return false
	var path: String = save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem.save_game: cannot open %s for writing (err %d)." % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Reads + validates + NORMALIZES a save. Returns {} when the slot is
## empty, corrupt or of an unsupported version. The result is typed for
## direct use (see the shape comment up top, except: player.pos is a
## Vector2, player.has_pos flags whether the save carried a position, and
## bag/equipped hold fully reconstructed item dicts ready for Inventory).
static func load_game(slot: int = 1) -> Dictionary:
	var path: String = save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveSystem.load_game: cannot open %s (err %d)." % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveSystem.load_game: %s is not valid JSON — ignoring save." % path)
		return {}
	var raw: Dictionary = parsed
	var version: int = int(_num(raw.get("v"), 0.0))
	if version != SAVE_VERSION:
		push_warning("SaveSystem.load_game: unsupported save version %d in %s (want %d)." % [version, path, SAVE_VERSION])
		return {}
	return _normalize(raw)


## Builds the full save dict from the live scene tree. Public so the
## integrator can inspect/extend snapshots; save_game() is the normal path.
static func collect_state() -> Dictionary:
	var player: Node = _first_in_group("player")
	if player == null:
		push_warning("SaveSystem.collect_state: no node in group 'player' — nothing to save.")
		return {}
	var pos: Vector2 = Vector2.ZERO
	if player is Node2D:
		pos = (player as Node2D).global_position
	var class_id: String = DEFAULT_CLASS
	var def_v: Variant = player.get("class_def")
	if def_v is Dictionary:
		class_id = str((def_v as Dictionary).get("id", DEFAULT_CLASS))
	return {
		"v": SAVE_VERSION,
		"map": _current_map_id(),
		"time_hours": _current_time_hours(),
		"player": {
			"pos": [pos.x, pos.y],
			"class": class_id,
			"hp": _num(player.get("hp"), 30.0),
			"mana": _num(player.get("mana"), 20.0),
			"xp": maxi(0, int(_num(player.get("xp"), 0.0))),
			"level": clampi(int(_num(player.get("level"), 1.0)), 1, XP.MAX_LEVEL),
			"gold": maxi(0, int(_num(player.get("gold"), 0.0))),
		},
		"inventory": _collect_inventory(player),
		"quests": _system_snapshot("quests", QUESTS_SCRIPT),
		"recipes": _system_snapshot("crafting", CRAFTING_SCRIPT),
	}


## Pushes a NORMALIZED save (load_game output) onto a freshly created,
## in-tree player: position, progression (level bonuses re-derived via
## XPSystem, no heal/banner), inventory (replacing the starting bag) and
## finally hp/mana clamped to the re-derived maxima.
static func apply_player_state(data: Dictionary, player: Node) -> void:
	if player == null or data.is_empty():
		return
	var p: Dictionary = {}
	var p_v: Variant = data.get("player")
	if p_v is Dictionary:
		p = p_v
	# 1. Position — only when the save carried one (else keep the map spawn).
	var pos_v: Variant = p.get("pos")
	if bool(p.get("has_pos", false)) and pos_v is Vector2 and player is Node2D:
		(player as Node2D).global_position = pos_v
	# 2. Progression. set() on a missing property is a silent no-op, so this
	#    degrades gracefully until the integration pass adds the fields.
	var level: int = clampi(int(_num(p.get("level"), 1.0)), 1, XP.MAX_LEVEL)
	player.set("level", level)
	player.set("xp", maxi(0, int(_num(p.get("xp"), 0.0))))
	player.set("gold", maxi(0, int(_num(p.get("gold"), 0.0))))
	XP.reapply_level_bonuses(player, level)
	# 3. Inventory: replace the starting bag/gear seeded by Player.create.
	var inv_v: Variant = player.get("inventory")
	if inv_v is Inventory:
		var inv: Inventory = inv_v
		inv.bag.clear()
		inv.bag.resize(Inventory.BAG_SIZE)
		var bag_v: Variant = data.get("bag")
		if bag_v is Array:
			var bag_in: Array = bag_v
			for i: int in mini(bag_in.size(), Inventory.BAG_SIZE):
				if bag_in[i] is Dictionary:
					inv.bag[i] = bag_in[i]
		var eq_in: Dictionary = {}
		var eq_v: Variant = data.get("equipped")
		if eq_v is Dictionary:
			eq_in = eq_v
		for slot: String in Inventory.EQUIP_SLOTS:
			var item_v: Variant = eq_in.get(slot)
			if item_v is Dictionary and Inventory.slot_accepts(slot, item_v):
				inv.equipped[slot] = item_v
			else:
				inv.equipped[slot] = null
		inv.bag_changed.emit()
		inv.equipment_changed.emit()  # -> player._apply_equipment()
	# 4. Vitals last, clamped to the freshly re-derived maxima.
	var max_hp: float = _num(player.get("max_hp"), 30.0)
	player.set("hp", clampf(_num(p.get("hp"), max_hp), 1.0, max_hp))
	var max_mana: float = _num(player.get("max_mana"), 20.0)
	player.set("mana", clampf(_num(p.get("mana"), max_mana), 0.0, max_mana))


## Restores the non-player systems from a NORMALIZED save: quest states,
## known recipes and the day/night clock. Call after the map is built.
static func apply_systems_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	_apply_system_state("quests", QUESTS_SCRIPT, data.get("quests"))
	_apply_system_state("crafting", CRAFTING_SCRIPT, data.get("recipes"))
	_apply_time_hours(_num(data.get("time_hours"), DEFAULT_TIME_HOURS))


# ---------------------------------------------------------------------------
# Collection helpers (live tree -> JSON-safe dict)
# ---------------------------------------------------------------------------

static func _collect_inventory(player: Node) -> Dictionary:
	var inv_v: Variant = player.get("inventory")
	if not (inv_v is Inventory):
		push_warning("SaveSystem: player has no Inventory — saving an empty bag.")
		return {"bag": [], "equipped": {}}
	var inv: Inventory = inv_v
	var bag_out: Array = []
	for entry: Variant in inv.bag:
		if entry is Dictionary:
			bag_out.append(_serialize_item(entry))
		else:
			bag_out.append(null)
	var eq_out: Dictionary = {}
	for slot: String in Inventory.EQUIP_SLOTS:
		var entry: Variant = inv.equipped.get(slot)
		if entry is Dictionary:
			eq_out[slot] = _serialize_item(entry)
		else:
			eq_out[slot] = null
	return {"bag": bag_out, "equipped": eq_out}


static func _serialize_item(item: Dictionary) -> Dictionary:
	var out: Dictionary = {"id": str(item.get("id", ""))}
	if item.has("count"):
		out["count"] = int(_num(item.get("count"), 1.0))
	# Full-dict fallback: keeps ids round-trippable even for items outside
	# the Items db (crafting materials/consumables until integration).
	out["data"] = item.duplicate(true)
	return out


## Fresh item dict from a saved entry, or null. Prefers the Items db copy
## (balance changes reach old saves); falls back to the stored full dict.
## Membership is checked on Items._DB directly (GDScript enforces no
## privacy) to avoid get_item()'s unknown-id warning on non-db items.
static func _reconstruct_item(entry: Variant) -> Variant:
	if not (entry is Dictionary):
		return null
	var e: Dictionary = entry
	var id: String = str(e.get("id", ""))
	var item: Dictionary = {}
	if not id.is_empty() and Items._DB.has(id):
		item = Items.get_item(id)
	if item.is_empty():
		var data_v: Variant = e.get("data")
		if data_v is Dictionary:
			item = (data_v as Dictionary).duplicate(true)
	if item.is_empty():
		push_warning("SaveSystem: could not reconstruct item '%s' — dropped." % id)
		return null
	if e.has("count"):
		item["count"] = maxi(1, int(_num(e.get("count"), 1.0)))
	return item


static func _current_map_id() -> String:
	# Contract (INTEGRATION 1): main.gd exposes current_map_id on the scene
	# root. Missing pre-integration => the only existing map, "town".
	var scene: Node = _scene_root()
	if scene != null:
		var v: Variant = scene.get("current_map_id")
		if v is String and not (v as String).is_empty():
			return v
	return DEFAULT_MAP


static func _current_time_hours() -> float:
	var dn: Node = _first_in_group("day_night")
	if dn != null:
		if dn.has_method("get_time_hours"):
			return fposmod(_num(dn.call("get_time_hours"), DEFAULT_TIME_HOURS), 24.0)
		var v: Variant = dn.get("time_hours")
		if v is float or v is int:
			return fposmod(float(v), 24.0)
	return DEFAULT_TIME_HOURS


## Snapshot of a pluggable system: a group-singleton node exposing
## serialize() -> Dictionary, else the script's own STATIC serialize()
## (duck-loaded at runtime — no compile-time dependency on files that a
## parallel workflow is still building). {} when the system is absent.
static func _system_snapshot(group: String, script_path: String) -> Dictionary:
	var node: Node = _first_in_group(group)
	if node != null and node.has_method("serialize"):
		var out_v: Variant = node.call("serialize")
		if out_v is Dictionary:
			return out_v
	if ResourceLoader.exists(script_path):
		var script_v: Variant = load(script_path)
		if script_v is Object and (script_v as Object).has_method("serialize"):
			var out2_v: Variant = (script_v as Object).call("serialize")
			if out2_v is Dictionary:
				return out2_v
	return {}


# ---------------------------------------------------------------------------
# Restore helpers (normalized dict -> live tree)
# ---------------------------------------------------------------------------

static func _apply_system_state(group: String, script_path: String, state: Variant) -> void:
	if not (state is Dictionary) or (state as Dictionary).is_empty():
		return
	var node: Node = _first_in_group(group)
	if node != null and node.has_method("deserialize"):
		node.call("deserialize", state)
		return
	if ResourceLoader.exists(script_path):
		var script_v: Variant = load(script_path)
		if script_v is Object and (script_v as Object).has_method("deserialize"):
			(script_v as Object).call("deserialize", state)
			return
	push_warning("SaveSystem: no '%s' system to restore into (group '%s' / %s)." % [group, group, script_path])


static func _apply_time_hours(hours: float) -> void:
	var dn: Node = _first_in_group("day_night")
	if dn == null:
		push_warning("SaveSystem: no 'day_night' group node — clock not restored.")
		return
	var h: float = fposmod(hours, 24.0)
	if dn.has_method("set_time_hours"):
		dn.call("set_time_hours", h)
		return
	var v: Variant = dn.get("time_hours")
	if v is float or v is int:
		dn.set("time_hours", h)
	else:
		push_warning("SaveSystem: day_night node exposes neither set_time_hours() nor time_hours.")


# ---------------------------------------------------------------------------
# Normalization (raw parsed JSON -> typed, validated dict)
# ---------------------------------------------------------------------------

static func _normalize(raw: Dictionary) -> Dictionary:
	# Map id.
	var map_id: String = DEFAULT_MAP
	var map_v: Variant = raw.get("map")
	if map_v is String and not (map_v as String).is_empty():
		map_id = map_v
	# Clock.
	var time_hours: float = DEFAULT_TIME_HOURS
	var t_v: Variant = raw.get("time_hours")
	if t_v is float or t_v is int:
		time_hours = fposmod(float(t_v), 24.0)
	# Player block.
	var p_raw: Dictionary = {}
	var p_v: Variant = raw.get("player")
	if p_v is Dictionary:
		p_raw = p_v
	var pos: Vector2 = Vector2.ZERO
	var has_pos: bool = false
	var pos_v: Variant = p_raw.get("pos")
	if pos_v is Array:
		var pos_arr: Array = pos_v
		if pos_arr.size() >= 2:
			pos = Vector2(_num(pos_arr[0], 0.0), _num(pos_arr[1], 0.0))
			has_pos = true
	var class_id: String = DEFAULT_CLASS
	var cls_v: Variant = p_raw.get("class")
	if cls_v is String and ClassDefs.all_ids().has(cls_v):
		class_id = cls_v
	elif cls_v is String:
		push_warning("SaveSystem: unknown class id '%s' in save — using '%s'." % [str(cls_v), DEFAULT_CLASS])
	# Inventory: reconstruct every item; equipment that no longer fits its
	# slot (db shifted under the save) demotes to a free bag slot.
	var inv_raw: Dictionary = {}
	var inv_v: Variant = raw.get("inventory")
	if inv_v is Dictionary:
		inv_raw = inv_v
	var bag: Array = []
	bag.resize(Inventory.BAG_SIZE)
	var bag_v: Variant = inv_raw.get("bag")
	if bag_v is Array:
		var bag_raw: Array = bag_v
		for i: int in mini(bag_raw.size(), Inventory.BAG_SIZE):
			bag[i] = _reconstruct_item(bag_raw[i])
	var equipped: Dictionary = {}
	var eq_raw: Dictionary = {}
	var eq_v: Variant = inv_raw.get("equipped")
	if eq_v is Dictionary:
		eq_raw = eq_v
	for slot: String in Inventory.EQUIP_SLOTS:
		var item_v: Variant = _reconstruct_item(eq_raw.get(slot))
		if item_v is Dictionary and not Inventory.slot_accepts(slot, item_v):
			var idx: int = _first_free_index(bag)
			if idx >= 0:
				bag[idx] = item_v
			else:
				push_warning("SaveSystem: '%s' no longer fits slot %s and the bag is full — dropped." % [str((item_v as Dictionary).get("id", "?")), slot])
			item_v = null
		equipped[slot] = item_v
	# Opaque system blocks.
	var quests: Dictionary = {}
	var q_v: Variant = raw.get("quests")
	if q_v is Dictionary:
		quests = q_v
	var recipes: Dictionary = {}
	var r_v: Variant = raw.get("recipes")
	if r_v is Dictionary:
		recipes = r_v
	return {
		"v": SAVE_VERSION,
		"map": map_id,
		"time_hours": time_hours,
		"player": {
			"pos": pos,
			"has_pos": has_pos,
			"class": class_id,
			"hp": maxf(1.0, _num(p_raw.get("hp"), 30.0)),
			"mana": maxf(0.0, _num(p_raw.get("mana"), 20.0)),
			"xp": maxi(0, int(_num(p_raw.get("xp"), 0.0))),
			"level": clampi(int(_num(p_raw.get("level"), 1.0)), 1, XP.MAX_LEVEL),
			"gold": maxi(0, int(_num(p_raw.get("gold"), 0.0))),
		},
		"bag": bag,
		"equipped": equipped,
		"quests": quests,
		"recipes": recipes,
	}


# ---------------------------------------------------------------------------
# Small shared utilities
# ---------------------------------------------------------------------------

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _scene_root() -> Node:
	var tree: SceneTree = _tree()
	if tree == null:
		return null
	return tree.current_scene


static func _first_in_group(group: String) -> Node:
	var tree: SceneTree = _tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(group)


static func _first_free_index(bag: Array) -> int:
	for i: int in bag.size():
		if bag[i] == null:
			return i
	return -1


## JSON-tolerant number read (JSON turns ints into floats): float/int pass
## through, anything else yields `fallback`.
static func _num(v: Variant, fallback: float = 0.0) -> float:
	if v is float:
		return v
	if v is int:
		return float(v)
	return fallback
