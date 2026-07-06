extends Node
## MountSystem -- autoload (/root/MountSystem). Build #38 "tons of mounts".
## A WoW-Classic-spirit mount collection (design/MOUNTS.md): 31 lore-grounded
## mounts loaded from data/mounts.json, per-actor collection + active mount,
## summon/dismiss that raises the rider's move speed (guarded write to
## player.gd's `speed`), stablemaster trainers that SELL mounts for gold,
## Witcher-style TROPHY mounts unlocked by killing certain elites, and a
## per-class riding advantage. A stable/collection UI lives in
## scenes/ui/mounts.tscn.
##
## Everything here is additive and null-safe: no other system's file is edited.
## The rider's mount SPRITE (the animal under the player) is Fable-only art --
## this system emits `mount_visual_requested` for that later pass and, for now,
## drops a rarity-tinted placeholder silhouette under the rider so the mounted
## state reads on screen. Art is a TODO; the SPEED and the COLLECTION are live.
##
## Public API (actor = the player node, group "player"):
##   unlock(actor, mount_id) -> bool          add a mount to the collection
##   owned(actor) -> Array                      known mount ids
##   is_owned(actor, mount_id) -> bool
##   summon(actor, mount_id) -> bool            mount up (applies speed)
##   dismiss(actor) -> bool                     dismount (restores speed)
##   is_mounted(actor) -> bool
##   active_mount(actor) -> String
##   toggle(actor)                              summon active / dismiss
##   open_stable(actor)                         show the collection UI
##   trainer_stock(trainer_id) -> Array         mount ids a stablemaster sells
##   buy_from_trainer(actor, trainer_id, mount_id) -> Dictionary  {ok, reason}
##   notify_kill(actor, type_name, rank)        trophy hook (also auto-polled)
##   all_mounts() / mount_def(id) / mount_count() / effective_speed_mult(...)
## Signals: mount_summoned, mount_dismissed, mount_unlocked, mount_trophy_earned,
##   mount_visual_requested (all carry (actor, mount_id)).

signal mount_summoned(actor, mount_id)
signal mount_dismissed(actor, mount_id)
signal mount_unlocked(actor, mount_id)
signal mount_trophy_earned(actor, mount_id)
signal mount_visual_requested(actor, mount_id)

const DATA_PATH := "res://data/mounts.json"
const STABLE_SCENE := "res://scenes/ui/mounts.tscn"
const TROPHY_POLL_S := 0.3
## Riding ranks: 1 = Apprentice (tier-I speed), 2 = Journeyman (tier-II speed).
## Demo-kind default: everyone rides at Apprentice; a tier-II mount ridden by an
## Apprentice runs at tier-I speed until they train Journeyman (MOUNTS.md 1.1).
const DEFAULT_RIDING_RANK := 1

var _mounts: Dictionary = {}            # mount_id -> def dict
var _tiers: Dictionary = {}             # "1"/"2" -> {name, speed_bonus}
var _trophy_by_enemy: Dictionary = {}   # enemy type_name -> mount_id
var _class_adv_bonus: float = 0.1

## Per-actor state, keyed by instance id. {known: Array, active: String,
## mounted: bool, riding_rank: int, orig_speed: float}.
var _actors: Dictionary = {}

var _stable_ui: Node = null
var _alive_elites: Dictionary = {}      # instance_id -> type_name (trophy poll)
var _poll_accum: float = 0.0


func _ready() -> void:
	_load_data()
	set_process(true)
	# Env self-test / screenshot hooks fire once the world + player exist.
	if not OS.get_environment("RH_MOUNTS").is_empty() \
			or not OS.get_environment("RH_MOUNT_TEST").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_mounts = _dict(root.get("mounts", {}))
	_tiers = _dict(root.get("tiers", {}))
	_class_adv_bonus = float(root.get("class_advantage_bonus", 0.1))
	_trophy_by_enemy.clear()
	for mid: String in _mounts.keys():
		var m: Dictionary = _dict(_mounts[mid])
		var te: String = str(m.get("trophy_enemy", ""))
		if te != "":
			_trophy_by_enemy[te] = mid
	if _mounts.is_empty():
		push_warning("MountSystem: no mounts loaded from %s" % DATA_PATH)


# --- Collection -------------------------------------------------------------

func unlock(actor: Node, mount_id: String) -> bool:
	if actor == null or not _mounts.has(mount_id):
		return false
	var st: Dictionary = _state(actor)
	var known: Array = st["known"]
	if known.has(mount_id):
		return false
	known.append(mount_id)
	mount_unlocked.emit(actor, mount_id)
	return true


func owned(actor: Node) -> Array:
	return (_state(actor)["known"] as Array).duplicate()


func is_owned(actor: Node, mount_id: String) -> bool:
	return (_state(actor)["known"] as Array).has(mount_id)


func mount_count() -> int:
	return _mounts.size()


func all_mounts() -> Dictionary:
	return _mounts


func mount_def(mount_id: String) -> Dictionary:
	return _dict(_mounts.get(mount_id, {}))


func active_mount(actor: Node) -> String:
	return str(_state(actor).get("active", ""))


func is_mounted(actor: Node) -> bool:
	return bool(_state(actor).get("mounted", false))


func riding_rank(actor: Node) -> int:
	return int(_state(actor).get("riding_rank", DEFAULT_RIDING_RANK))


func train_riding(actor: Node, rank: int) -> void:
	_state(actor)["riding_rank"] = clampi(rank, 1, 2)


# --- Speed math -------------------------------------------------------------

## Fractional speed increase this actor gets riding `mount_id`, honoring the
## riding-rank tier cap and the per-class advantage. E.g. 0.6 -> +60%.
func mount_speed_bonus(actor: Node, mount_id: String) -> float:
	var m: Dictionary = mount_def(mount_id)
	if m.is_empty():
		return 0.0
	var tier: int = int(m.get("tier", 1))
	var bonus: float = float(m.get("speed_bonus", _tier_bonus(tier)))
	# Tier-II ridden below Journeyman rank is capped to tier-I speed.
	if tier >= 2 and riding_rank(actor) < 2:
		bonus = _tier_bonus(1)
	if _class_matches(actor, m):
		bonus += _class_adv_bonus
	return bonus


func effective_speed_mult(actor: Node, mount_id: String) -> float:
	return 1.0 + mount_speed_bonus(actor, mount_id)


func has_class_advantage(actor: Node, mount_id: String) -> bool:
	return _class_matches(actor, mount_def(mount_id))


# --- Summon / dismiss -------------------------------------------------------

func summon(actor: Node, mount_id: String) -> bool:
	if actor == null or not is_owned(actor, mount_id):
		return false
	var m: Dictionary = mount_def(mount_id)
	# Class-exclusive gate (e.g. the Gallows Rook is Rookwarden-only).
	var only: String = str(m.get("class_only", ""))
	if only != "" and _class_id(actor) != only:
		return false
	var st: Dictionary = _state(actor)
	if bool(st.get("mounted", false)):
		# Re-summon a different mount: dismount the old one first (restore speed).
		dismiss(actor)
	st["active"] = mount_id
	st["mounted"] = true
	# Guarded move-speed write: multiply the rider's live speed by the mount
	# multiplier (composes with gear speed_pct; restored exactly on dismiss).
	if _has_prop(actor, "speed"):
		var cur: float = float(actor.get("speed"))
		st["orig_speed"] = cur
		actor.set("speed", cur * effective_speed_mult(actor, mount_id))
	_apply_placeholder_visual(actor, mount_id)
	mount_visual_requested.emit(actor, mount_id)  # Fable art TODO hooks here
	mount_summoned.emit(actor, mount_id)
	return true


func dismiss(actor: Node) -> bool:
	if actor == null:
		return false
	var st: Dictionary = _state(actor)
	if not bool(st.get("mounted", false)):
		return false
	var mid: String = str(st.get("active", ""))
	st["mounted"] = false
	if _has_prop(actor, "speed") and st.has("orig_speed"):
		actor.set("speed", float(st["orig_speed"]))
	_clear_placeholder_visual(actor)
	mount_dismissed.emit(actor, mid)
	return true


func toggle(actor: Node) -> void:
	if actor == null:
		return
	if is_mounted(actor):
		dismiss(actor)
		return
	var mid: String = active_mount(actor)
	if mid == "" or not is_owned(actor, mid):
		var known: Array = _state(actor)["known"]
		if known.is_empty():
			return
		mid = str(known[0])
	summon(actor, mid)


# --- Trainers (stablemasters sell mounts) -----------------------------------

func trainer_stock(trainer_id: String) -> Array:
	var out: Array = []
	for mid: String in _mounts.keys():
		var m: Dictionary = _dict(_mounts[mid])
		if str(m.get("trainer", "")) == trainer_id and int(m.get("price", 0)) > 0:
			out.append(mid)
	return out


func mount_price(mount_id: String) -> int:
	return int(mount_def(mount_id).get("price", 0))


## Buy a mount from a stablemaster. Deducts player.gold; unlocks on success.
func buy_from_trainer(actor: Node, trainer_id: String, mount_id: String) -> Dictionary:
	var m: Dictionary = mount_def(mount_id)
	if m.is_empty() or str(m.get("trainer", "")) != trainer_id:
		return {"ok": false, "reason": "not sold here"}
	if is_owned(actor, mount_id):
		return {"ok": false, "reason": "already in your stable"}
	var price: int = int(m.get("price", 0))
	var gold: int = _gold(actor)
	if gold < price:
		return {"ok": false, "reason": "not enough gold"}
	if _has_prop(actor, "gold"):
		actor.set("gold", gold - price)
	unlock(actor, mount_id)
	return {"ok": true, "reason": "", "price": price}


# --- Trophies (Witcher-style: kill an elite, unlock a mount) -----------------

## Direct hook (also driven by the enemy-death poll below). Awards the trophy
## mount mapped to `type_name` when an elite of that type is killed.
func notify_kill(actor: Node, type_name: String, rank: String = "normal") -> bool:
	if not _trophy_by_enemy.has(type_name):
		return false
	var mid: String = str(_trophy_by_enemy[type_name])
	var req: String = str(mount_def(mid).get("trophy_rank", "elite"))
	if req != "" and rank != req:
		return false
	var pl: Node = actor if actor != null else _player()
	if pl == null or is_owned(pl, mid):
		return false
	unlock(pl, mid)
	mount_trophy_earned.emit(pl, mid)
	return true


func _process(delta: float) -> void:
	# Poll living elites; when one that maps to a trophy dies (leaves the group
	# or flips is_dead), award its mount. Cheap: runs at ~3 Hz over the handful
	# of enemies on screen. No enemy.gd edit required.
	_poll_accum += delta
	if _poll_accum < TROPHY_POLL_S:
		return
	_poll_accum = 0.0
	var current: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n):
			continue
		if str(n.get("rank")) != "elite":
			continue
		if bool(n.get("is_dead")):
			continue
		var tn: String = str(n.get("type_name"))
		if _trophy_by_enemy.has(tn):
			current[n.get_instance_id()] = tn
	# Any elite we were tracking that is gone this tick counts as killed.
	for iid: int in _alive_elites.keys():
		if not current.has(iid):
			notify_kill(_player(), str(_alive_elites[iid]), "elite")
	_alive_elites = current


# --- Stable UI --------------------------------------------------------------

func open_stable(actor: Node) -> void:
	if actor == null:
		actor = _player()
	_ensure_stable_ui()
	if _stable_ui != null and _stable_ui.has_method("present"):
		_stable_ui.call("present", self, actor)


func close_stable() -> void:
	if _stable_ui != null and _stable_ui.has_method("close"):
		_stable_ui.call("close")


func _ensure_stable_ui() -> void:
	if _stable_ui != null and is_instance_valid(_stable_ui):
		return
	if not ResourceLoader.exists(STABLE_SCENE):
		push_warning("MountSystem: stable scene missing (%s)" % STABLE_SCENE)
		return
	var scn: PackedScene = load(STABLE_SCENE) as PackedScene
	if scn == null:
		return
	_stable_ui = scn.instantiate()
	add_child(_stable_ui)


# --- Input (Shift+H = stable, H = mount/dismount) ---------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_H:
		return
	var pl: Node = _player()
	if pl == null:
		return
	if _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	if key.shift_pressed:
		if _stable_ui != null and is_instance_valid(_stable_ui) \
				and bool(_stable_ui.get("is_open")):
			close_stable()
		else:
			open_stable(pl)
	else:
		toggle(pl)


func _panel_blocking() -> bool:
	# Never steal H while a text field / dialogue / bag is capturing input.
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Placeholder mounted visual (Fable art TODO) ----------------------------

func _apply_placeholder_visual(actor: Node, mount_id: String) -> void:
	if not (actor is Node2D):
		return
	_clear_placeholder_visual(actor)
	var holder := Node2D.new()
	holder.name = "MountPlaceholder"
	holder.z_index = -1  # drawn behind the rider
	var col: Color = _rarity_color(str(mount_def(mount_id).get("rarity", "common")))
	# A simple ellipse "shadow" + a rounded body block -- unmistakably a mount
	# under the rider, and trivially replaced by the real sheet later.
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(15.0, 6.0, Vector2(0.0, -3.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	holder.add_child(shadow)
	var body := Polygon2D.new()
	body.polygon = _ellipse_points(12.0, 7.0, Vector2(0.0, -12.0))
	body.color = Color(col.r * 0.7 + 0.1, col.g * 0.7 + 0.1, col.b * 0.7 + 0.1, 0.92)
	holder.add_child(body)
	(actor as Node2D).add_child(holder)


func _clear_placeholder_visual(actor: Node) -> void:
	if not (actor is Node2D):
		return
	var h: Node = (actor as Node2D).get_node_or_null("MountPlaceholder")
	if h != null:
		h.queue_free()


func _ellipse_points(rx: float, ry: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# --- Env self-test (RH_MOUNTS screenshot / RH_MOUNT_TEST proof) -------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# Seed a representative slice of the collection so the stable reads full.
	for mid: String in ["lowland_dun", "riverfork_courser", "bloodroad_warhorse",
			"obsidian_direwolf", "queens_grey", "great_elk", "gravemark_bone_steed",
			"gallows_rook", "thread_silver", "canal_skiff"]:
		unlock(pl, mid)
	if not OS.get_environment("RH_MOUNT_TEST").is_empty():
		_self_test(pl)
	if not OS.get_environment("RH_MOUNTS").is_empty():
		open_stable(pl)


func _self_test(pl: Node) -> void:
	print("[MOUNT_TEST] ===== Raven Hollow mount system self-test =====")
	print("[MOUNT_TEST] collection size = %d mounts" % mount_count())
	print("[MOUNT_TEST] class = %s ; owned = %d" % [_class_id(pl), owned(pl).size()])
	var base_speed: float = float(pl.get("speed")) if _has_prop(pl, "speed") else -1.0
	print("[MOUNT_TEST] move speed BEFORE summon = %.1f" % base_speed)
	var mid := "lowland_dun"
	var bonus: float = mount_speed_bonus(pl, mid)
	summon(pl, mid)
	var mounted_speed: float = float(pl.get("speed"))
	print("[MOUNT_TEST] summoned '%s' (tier %d, +%.0f%% speed, class_adv=%s)" % [
		mid, int(mount_def(mid).get("tier", 1)), bonus * 100.0,
		str(has_class_advantage(pl, mid))])
	print("[MOUNT_TEST] move speed AFTER summon  = %.1f  (x%.2f)" % [
		mounted_speed, mounted_speed / maxf(base_speed, 0.001)])
	dismiss(pl)
	print("[MOUNT_TEST] move speed AFTER dismiss = %.1f  (restored=%s)" % [
		float(pl.get("speed")), str(is_equal_approx(float(pl.get("speed")), base_speed))])
	# Trophy proof: killing a wolf elite unlocks the Obsidian Dire-Wolf logic.
	var had: bool = is_owned(pl, "obsidian_direwolf")
	var forced := false
	if had:
		# Already seeded above; prove the mapping instead on a fresh mount.
		forced = notify_kill(pl, "orc_warrior", "elite")
		print("[MOUNT_TEST] elite orc_warrior killed -> Valrom's Pit-Brute unlocked = %s" % str(forced))
	else:
		forced = notify_kill(pl, "wolf", "elite")
		print("[MOUNT_TEST] elite wolf killed -> Obsidian Dire-Wolf unlocked = %s" % str(forced))
	# Trainer proof.
	var stock: Array = trainer_stock("angel_wings")
	print("[MOUNT_TEST] angel_wings stablemaster sells: %s" % str(stock))
	print("[MOUNT_TEST] ===== self-test complete =====")


# --- helpers ----------------------------------------------------------------

func _state(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _actors.has(key):
		_actors[key] = {
			"known": [], "active": "", "mounted": false,
			"riding_rank": DEFAULT_RIDING_RANK, "orig_speed": 0.0,
		}
	return _actors[key]


func _tier_bonus(tier: int) -> float:
	var t: Dictionary = _dict(_tiers.get(str(tier), {}))
	return float(t.get("speed_bonus", 0.6 if tier <= 1 else 1.0))


func _class_id(actor: Node) -> String:
	if actor == null:
		return ""
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary:
		return str((cd as Dictionary).get("id", ""))
	return ""


func _class_matches(actor: Node, m: Dictionary) -> bool:
	var adv: Variant = m.get("class_adv", [])
	if adv is Array:
		return (adv as Array).has(_class_id(actor))
	return false


func _gold(actor: Node) -> int:
	if _has_prop(actor, "gold"):
		var g: Variant = actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.35, 0.75, 0.35)
		"rare": return Color(0.30, 0.50, 0.90)
		"epic": return Color(0.62, 0.35, 0.85)
		"legendary": return Color(1.0, 0.55, 0.1)
		_: return Color(0.62, 0.62, 0.62)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("MountSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	var pl: Node = _player()
	if pl == null:
		return {}
	var st: Dictionary = _state(pl)
	return {
		"known": (st["known"] as Array).duplicate(),
		"active": str(st.get("active", "")),
		"riding_rank": int(st.get("riding_rank", DEFAULT_RIDING_RANK)),
	}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var st: Dictionary = _state(pl)
	var known: Array = []
	for mid_v: Variant in _arr(d.get("known", [])):
		var mid: String = str(mid_v)
		if _mounts.has(mid):
			known.append(mid)
	st["known"] = known
	st["active"] = str(d.get("active", ""))
	st["riding_rank"] = int(d.get("riding_rank", DEFAULT_RIDING_RANK))


func _arr(v: Variant) -> Array:
	return v if v is Array else []
