extends Node
## RunewordSystem -- autoload (/root/RunewordSystem). Build #37
## "RUNEWORDS / SOCKETS / RUNES" (design/RUNEWORDS.md + owner amendment:
## recolor the whole feature to D2 DARK GOLD).
##
## The artifact class ABOVE legendary. 12 carved Underlanguage runes
## (data/runes.json), socketed items (extension keys "sockets"/"runes" that
## ride items.json dicts for free), and 10 runeword recipes (data/runewords.json)
## -- an ORDERED rune sequence filling every socket of an eligible base grants
## that runeword's combined stat bonuses. Bonuses are folded into the wearer's
## derived stats through StatsSystem.add_modifier when a word completes on an
## EQUIPPED item; partial (socketed but unfinished) items grant the sum of their
## runes' individual socket bonuses instead. Every write is guarded and reversible
## by a per-(actor,slot) source key -- no other system's file is edited (they are
## READ only: StatsSystem, InventorySystem, items.json).
##
## A socketing panel (scenes/ui/socketing.tscn) self-instances from _ready (a
## CanvasLayer add_child, mirroring MountSystem) -- drag/click runes from a pouch
## into an item's sockets with a live runeword-match preview, D2 dark-gold styled.
## Open with 'U' (raw keycode -- no project.godot edit) or open_socketing(...).
##
## Public API (actor = the player node, group "player"; item = an item dict):
##   -- runes / data --
##   all_runes() -> Dictionary            rune_ids() -> Array
##   rune_def(id) -> Dictionary           rune_color(id) -> Color
##   all_runewords() -> Dictionary        runeword_def(key) -> Dictionary
##   dark_gold() -> Color
##   -- sockets on items --
##   socketable_slot(item) -> bool        max_sockets(slot) -> int
##   socket_count(item) -> int            item_runes(item) -> Array
##   make_socketed(item, n) -> Dictionary  (stamps sockets/runes; demo/tools)
##   can_socket(item, socket_idx, rune_id) -> Dictionary {ok, reason}
##   socket_rune(actor, item, socket_idx, rune_id) -> Dictionary {ok, reason, runeword}
##   remove_rune(actor, item, socket_idx) -> bool
##   sequence_of(item) -> Array           preview(item) -> Dictionary
##   -- runewords --
##   check_runeword(item) -> String       ("" or the matched runewords key)
##   apply_runeword(actor, item)          clear_runeword(actor, item)
##   -- UI --
##   open_socketing(actor, item)          close_socketing()
## Signals: rune_socketed(actor, item, socket_idx, rune_id),
##   socket_changed(actor, item), runeword_formed(actor, item, runeword_id).

signal rune_socketed(actor, item, socket_idx, rune_id)
signal socket_changed(actor, item)
signal runeword_formed(actor, item, runeword_id)

const RUNES_PATH := "res://data/runes.json"
const RUNEWORDS_PATH := "res://data/runewords.json"
const SOCKET_SCENE := "res://scenes/ui/socketing.tscn"

## D2 dark-gold fallback if runes.json is missing its palette keys.
const DARK_GOLD_DEFAULT := Color(0.80, 0.62, 0.26)

## Only these slots can hold sockets (owner mandate: weapons/chest/helm).
const SOCKETABLE := {"main_hand": 3, "chest": 3, "head": 2}
## Rarities that may COMPLETE a runeword (epics refuse the word -- D2 law).
const RUNEWORD_RARITIES := ["common", "uncommon", "rare"]
## StatsSystem modifier stat keys (the exact set InventorySystem folds in).
const STAT_KEYS := ["damage", "armor", "hp", "mana", "speed_pct", "crit_pct", "mana_regen"]

var _runes: Dictionary = {}          # id -> def dict
var _runewords: Dictionary = {}      # key -> def dict
var _dark_gold: Color = DARK_GOLD_DEFAULT
var _dark_gold_rim: Color = Color(0.54, 0.39, 0.15)
var _dark_gold_bright: Color = Color(1.0, 0.85, 0.45)

var _ui: Node = null


func _ready() -> void:
	_load_data()
	# Keep runeword bonuses correct across equip/unequip of a socketed item.
	call_deferred("_connect_inventory")
	# Env self-test / screenshot hooks fire once the world + player exist.
	if not OS.get_environment("RH_RUNEWORD").is_empty() \
			or not OS.get_environment("RH_RUNEWORDS").is_empty() \
			or not OS.get_environment("RH_RUNEWORD_TEST").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var rroot: Dictionary = _read_json(RUNES_PATH)
	_runes = _dict(rroot.get("runes", {}))
	_dark_gold = _color_from(rroot.get("dark_gold", []), DARK_GOLD_DEFAULT)
	_dark_gold_rim = _color_from(rroot.get("dark_gold_rim", []), _dark_gold_rim)
	_dark_gold_bright = _color_from(rroot.get("dark_gold_bright", []), _dark_gold_bright)
	var wroot: Dictionary = _read_json(RUNEWORDS_PATH)
	_runewords = _dict(wroot.get("runewords", {}))
	if _runes.is_empty():
		push_warning("RunewordSystem: no runes loaded from %s" % RUNES_PATH)
	if _runewords.is_empty():
		push_warning("RunewordSystem: no runewords loaded from %s" % RUNEWORDS_PATH)


func _connect_inventory() -> void:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null:
		return
	if inv.has_signal("item_equipped") and not inv.is_connected("item_equipped", _on_item_equipped):
		inv.connect("item_equipped", _on_item_equipped)
	if inv.has_signal("item_unequipped") and not inv.is_connected("item_unequipped", _on_item_unequipped):
		inv.connect("item_unequipped", _on_item_unequipped)


# --- Rune / runeword data ---------------------------------------------------

func all_runes() -> Dictionary:
	return _runes


func rune_ids() -> Array:
	return _runes.keys()


func rune_def(rune_id: String) -> Dictionary:
	return _dict(_runes.get(rune_id, {}))


## Rune glyph/rim color. Owner amendment: everything renders D2 dark gold; a
## rune may carry its own dark-gold shade in runes.json, else the base gold.
func rune_color(rune_id: String) -> Color:
	var r: Dictionary = rune_def(rune_id)
	return _color_from(r.get("color", []), _dark_gold)


func rune_name(rune_id: String) -> String:
	return str(rune_def(rune_id).get("name", rune_id.to_upper()))


func all_runewords() -> Dictionary:
	return _runewords


func runeword_def(key: String) -> Dictionary:
	return _dict(_runewords.get(key, {}))


func dark_gold() -> Color:
	return _dark_gold


func dark_gold_rim() -> Color:
	return _dark_gold_rim


func dark_gold_bright() -> Color:
	return _dark_gold_bright


# --- Sockets on items -------------------------------------------------------

func max_sockets(slot: String) -> int:
	return int(SOCKETABLE.get(slot, 0))


func socketable_slot(item: Dictionary) -> bool:
	return SOCKETABLE.has(str(item.get("slot", "")))


func socket_count(item: Dictionary) -> int:
	return maxi(0, int(item.get("sockets", 0)))


## The item's rune array, normalized to size == socket_count (missing = "").
func item_runes(item: Dictionary) -> Array:
	var n: int = socket_count(item)
	var raw: Array = item.get("runes", []) if item.get("runes") is Array else []
	var out: Array = []
	for i: int in n:
		out.append(str(raw[i]) if i < raw.size() else "")
	return out


## Stamp `n` empty sockets onto an item (clamped to its slot cap). Demo/tools
## helper -- normally the loot roll writes these keys. Mutates + returns item.
func make_socketed(item: Dictionary, n: int) -> Dictionary:
	var cap: int = max_sockets(str(item.get("slot", "")))
	var count: int = clampi(n, 0, cap)
	item["sockets"] = count
	var runes: Array = []
	for _i in count:
		runes.append("")
	item["runes"] = runes
	return item


## Whether `rune_id` may go into socket `socket_idx` of `item`.
func can_socket(item: Dictionary, socket_idx: int, rune_id: String) -> Dictionary:
	if not _runes.has(rune_id):
		return {"ok": false, "reason": "Unknown rune."}
	var n: int = socket_count(item)
	if n <= 0:
		return {"ok": false, "reason": "This item has no sockets."}
	if socket_idx < 0 or socket_idx >= n:
		return {"ok": false, "reason": "No such socket."}
	var runes: Array = item_runes(item)
	if str(runes[socket_idx]) != "":
		return {"ok": false, "reason": "That socket is filled."}
	# No duplicate syllable in one item (a stutter; the mark refuses).
	if runes.has(rune_id):
		return {"ok": false, "reason": "That syllable is already set here."}
	return {"ok": true, "reason": ""}


## Place `rune_id` into socket `socket_idx`. On success re-derives the item's
## stat bonus. If the placement completes a known runeword the item is stamped
## with `runeword`/`written_on` and the full artifact bonus is applied (equipped).
## Returns {ok, reason, runeword} (runeword = "" or the completed key).
func socket_rune(actor: Node, item: Dictionary, socket_idx: int, rune_id: String) -> Dictionary:
	var verdict: Dictionary = can_socket(item, socket_idx, rune_id)
	if not bool(verdict.get("ok", false)):
		return {"ok": false, "reason": str(verdict.get("reason", "Cannot socket.")), "runeword": ""}
	var runes: Array = item_runes(item)
	runes[socket_idx] = rune_id
	item["runes"] = runes
	rune_socketed.emit(actor, item, socket_idx, rune_id)
	var word: String = check_runeword(item)
	if word != "":
		item["runeword"] = word
		if not item.has("written_on"):
			item["written_on"] = str(item.get("name", ""))
		runeword_formed.emit(actor, item, word)
	_refresh_item_bonus(actor, item)
	socket_changed.emit(actor, item)
	_refresh_ui()
	return {"ok": true, "reason": "", "runeword": word}


## Pry a rune loose (canon: permanent; the UI never offers this, but the API is
## required and the sim may need it). Clears the socket + any formed word and
## re-derives the bonus. Returns false when the socket is empty/invalid.
func remove_rune(actor: Node, item: Dictionary, socket_idx: int) -> bool:
	var n: int = socket_count(item)
	if socket_idx < 0 or socket_idx >= n:
		return false
	var runes: Array = item_runes(item)
	if str(runes[socket_idx]) == "":
		return false
	runes[socket_idx] = ""
	item["runes"] = runes
	item.erase("runeword")
	_refresh_item_bonus(actor, item)
	socket_changed.emit(actor, item)
	_refresh_ui()
	return true


## The current left-to-right sequence of socketed runes (drops the empty tail
## used for the preview; check_runeword requires ALL sockets filled anyway).
func sequence_of(item: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in item_runes(item):
		if str(r) != "":
			out.append(str(r))
	return out


# --- Runewords --------------------------------------------------------------

## Returns the runewords key completed by this item, or "" if none. Enforces:
## every socket filled, exact sequence, matching slot, base rarity <= rare,
## base ilvl >= the word's min_base_ilvl (D2 law -- spare socket never completes).
func check_runeword(item: Dictionary) -> String:
	var n: int = socket_count(item)
	if n <= 0:
		return ""
	var runes: Array = item_runes(item)
	for r: Variant in runes:
		if str(r) == "":
			return ""
	var key: String = "_".join(runes)
	if not _runewords.has(key):
		return ""
	var rw: Dictionary = runeword_def(key)
	if str(item.get("slot", "")) != str(rw.get("slot", "")):
		return ""
	if not RUNEWORD_RARITIES.has(str(item.get("rarity", "common"))):
		return ""
	if _item_ilvl(item) < int(rw.get("min_base_ilvl", 55)):
		return ""
	return key


## Live UI preview state for `item`: the sequence, the matched word (if any),
## whether it is complete, and why it would/wouldn't resolve.
func preview(item: Dictionary) -> Dictionary:
	var n: int = socket_count(item)
	var runes: Array = item_runes(item)
	var filled: int = 0
	for r: Variant in runes:
		if str(r) != "":
			filled += 1
	var out: Dictionary = {
		"sockets": n, "filled": filled, "runes": runes,
		"complete": false, "word": "", "word_name": "",
		"bonuses": {}, "reason": "",
	}
	if n <= 0:
		out["reason"] = "no sockets"
		return out
	# A candidate word: the sequence-so-far as a full key, only meaningful when
	# every socket is filled -- but we also flag a would-be match for the tail.
	if filled == n:
		var key: String = "_".join(runes)
		if _runewords.has(key):
			var rw: Dictionary = runeword_def(key)
			out["word"] = key
			out["word_name"] = str(rw.get("name", key))
			out["bonuses"] = _dict(rw.get("bonuses", {}))
			var resolved: String = check_runeword(item)
			if resolved != "":
				out["complete"] = true
			else:
				out["reason"] = _mismatch_reason(item, rw)
		else:
			out["reason"] = "not a known word"
	else:
		out["reason"] = "%d of %d sockets" % [filled, n]
	return out


func _mismatch_reason(item: Dictionary, rw: Dictionary) -> String:
	if str(item.get("slot", "")) != str(rw.get("slot", "")):
		return "wrong slot for this word"
	if not RUNEWORD_RARITIES.has(str(item.get("rarity", "common"))):
		return "the word refuses a loud base"   # epic+ refuses
	if _item_ilvl(item) < int(rw.get("min_base_ilvl", 55)):
		return "base is too low (needs i%d)" % int(rw.get("min_base_ilvl", 55))
	return ""


# --- StatsSystem bonus wiring (guarded, reversible) -------------------------

## Re-derive and apply this item's stat contribution: the full runeword bonus if
## a word is formed, else the sum of its socketed runes' individual bonuses.
## No-op (and clears any stale bonus) when the item is not currently equipped.
func _refresh_item_bonus(actor: Node, item: Dictionary) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss == null or actor == null:
		return
	var slot: String = _equipped_slot_of(actor, item)
	if slot == "":
		return  # bonuses apply only while worn
	var src: String = _bonus_src(actor, slot)
	if ss.has_method("remove_modifier"):
		ss.call("remove_modifier", src)
	if not ss.has_method("add_modifier"):
		return
	var bonus: Dictionary = _effective_bonus(item)
	for stat: String in STAT_KEYS:
		var v: float = float(bonus.get(stat, 0.0))
		if absf(v) > 0.0001:
			ss.call("add_modifier", actor, src, stat, v)


## The stat dict this item currently grants (runeword bonus > socket-bonus sum).
func _effective_bonus(item: Dictionary) -> Dictionary:
	var word: String = check_runeword(item)
	if word != "":
		return _dict(runeword_def(word).get("bonuses", {}))
	var totals: Dictionary = {}
	for r: Variant in item_runes(item):
		var rid: String = str(r)
		if rid == "":
			continue
		var sb: Dictionary = _dict(rune_def(rid).get("socket_bonus", {}))
		for stat: Variant in sb:
			totals[str(stat)] = float(totals.get(str(stat), 0.0)) + float(sb[stat])
	return totals


## Public: force-apply the item's runeword/socket bonus (equipped actor).
func apply_runeword(actor: Node, item: Dictionary) -> void:
	_refresh_item_bonus(actor, item)


## Public: strip whatever runeword/socket bonus this item contributed.
func clear_runeword(actor: Node, item: Dictionary) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss == null or actor == null or not ss.has_method("remove_modifier"):
		return
	var slot: String = _equipped_slot_of(actor, item)
	if slot != "":
		ss.call("remove_modifier", _bonus_src(actor, slot))


func _bonus_src(actor: Node, slot: String) -> String:
	return "runeword:%d:%s" % [actor.get_instance_id(), slot]


## The equip slot currently holding `item` by reference, or "" if in the bag.
func _equipped_slot_of(actor: Node, item: Dictionary) -> String:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("get_equipment"):
		return ""
	var eq: Dictionary = inv.call("get_equipment", actor)
	for slot: Variant in eq:
		var v: Variant = eq[slot]
		if v is Dictionary and is_same(v, item):
			return str(slot)
	return ""


func _on_item_equipped(actor: Node, _slot: String, item: Dictionary) -> void:
	if item is Dictionary and socket_count(item) > 0:
		_refresh_item_bonus(actor, item)


func _on_item_unequipped(actor: Node, slot: String, _item: Dictionary) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and ss.has_method("remove_modifier"):
		ss.call("remove_modifier", _bonus_src(actor, slot))


# --- Socketing UI (self-instanced, mirrors MountSystem) ---------------------

func open_socketing(actor: Node, item: Dictionary = {}) -> void:
	if actor == null:
		actor = _player()
	_ensure_ui()
	if _ui != null and _ui.has_method("present"):
		_ui.call("present", self, actor, item)


func close_socketing() -> void:
	if _ui != null and _ui.has_method("close"):
		_ui.call("close")


func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	if not ResourceLoader.exists(SOCKET_SCENE):
		push_warning("RunewordSystem: socketing scene missing (%s)" % SOCKET_SCENE)
		return
	var scn: PackedScene = load(SOCKET_SCENE) as PackedScene
	if scn == null:
		return
	_ui = scn.instantiate()
	add_child(_ui)


func _refresh_ui() -> void:
	if _ui != null and is_instance_valid(_ui) and bool(_ui.get("is_open")) and _ui.has_method("refresh"):
		_ui.call("refresh")


# --- Input ('U' = socketing panel; raw keycode, no project.godot edit) ------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_U:
		return
	var pl: Node = _player()
	if pl == null or _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	if _ui != null and is_instance_valid(_ui) and bool(_ui.get("is_open")):
		close_socketing()
	else:
		open_socketing(pl, _first_socketed_equipped(pl))


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


## The first equipped item that has sockets (what 'U' opens by default), or {}.
func _first_socketed_equipped(actor: Node) -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("get_equipment"):
		return {}
	var eq: Dictionary = inv.call("get_equipment", actor)
	for slot: Variant in eq:
		var v: Variant = eq[slot]
		if v is Dictionary and socket_count(v) > 0:
			return v
	return {}


# --- Env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# A quiet rare chest base (i55) with 2 sockets -- the VETH-OM canvas.
	var demo: Dictionary = _demo_socket_base()
	_register_and_equip(pl, demo)
	if not OS.get_environment("RH_RUNEWORD_TEST").is_empty():
		_self_test(pl)
	if not OS.get_environment("RH_RUNEWORD").is_empty() \
			or not OS.get_environment("RH_RUNEWORDS").is_empty():
		# Show the panel mid-spell: one rune already set, one socket open, so the
		# screenshot catches sockets + pouch + a live preview one rune from a word.
		var it: Dictionary = _first_socketed_equipped(pl)
		if it.is_empty():
			it = demo
		if str(it.get("runes", ["", ""])[0]) == "" and sequence_of(it).is_empty():
			socket_rune(pl, it, 0, "veth")
		open_socketing(pl, it)


func _demo_socket_base() -> Dictionary:
	var item: Dictionary = {
		"id": "bog_iron_hauberk", "name": "Bog-Iron Hauberk", "slot": "chest",
		"rarity": "rare", "icon_hint": "iron_cuirass", "armor_class": "mail",
		"stats": {"armor": 6.0, "hp": 18.0},
		"flavor": "Quiet metal. It will hold what you write on it.",
		"ilvl": 55, "req_level": 1,
	}
	return make_socketed(item, 2)


func _register_and_equip(pl: Node, item: Dictionary) -> void:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	var ss: Node = get_node_or_null("/root/StatsSystem")
	var cid: String = "warrior"
	var cd: Variant = pl.get("class_def")
	if cd is Dictionary and (cd as Dictionary).has("id"):
		cid = str((cd as Dictionary)["id"])
	var lv: int = int(pl.get("level")) if _has_prop(pl, "level") else 60
	if lv < 55:
		lv = 60
	if ss != null and ss.has_method("register"):
		ss.call("register", pl, cid, lv)
	if inv != null and inv.has_method("register"):
		inv.call("register", pl, cid, lv)
		if inv.has_method("add_item"):
			inv.call("add_item", pl, item)
		if inv.has_method("equip"):
			inv.call("equip", pl, item, "chest")


func _self_test(pl: Node) -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	print("[RW_TEST] ===== Raven Hollow runeword system self-test =====")
	print("[RW_TEST] runes loaded = %d ; runewords loaded = %d" % [_runes.size(), _runewords.size()])
	var item: Dictionary = _first_socketed_equipped(pl)
	if item.is_empty():
		print("[RW_TEST] no socketed item equipped -- abort")
		return
	print("[RW_TEST] base = '%s' (%s, %s, i%d) sockets=%d" % [
		str(item.get("name", "?")), str(item.get("slot", "?")),
		str(item.get("rarity", "?")), _item_ilvl(item), socket_count(item)])
	var a0: float = _derived(ss, pl, "armor")
	var h0: float = _derived(ss, pl, "max_health")
	print("[RW_TEST] BEFORE socketing:  armor = %.1f   max_health = %.1f" % [a0, h0])
	# Spell VETH-OM into the chest, one socket at a time.
	var r1: Dictionary = socket_rune(pl, item, 0, "veth")
	var a1: float = _derived(ss, pl, "armor")
	var h1: float = _derived(ss, pl, "max_health")
	print("[RW_TEST] set VETH  -> socket 0 (partial: +30 hp socket-bonus). ok=%s" % str(r1.get("ok")))
	print("[RW_TEST]   after VETH:      armor = %.1f   max_health = %.1f   preview=%s" % [
		a1, h1, str(preview(item).get("reason", ""))])
	var r2: Dictionary = socket_rune(pl, item, 1, "om")
	var word: String = str(r2.get("runeword", ""))
	var a2: float = _derived(ss, pl, "armor")
	var h2: float = _derived(ss, pl, "max_health")
	print("[RW_TEST] set OM    -> socket 1. WORD FORMED = '%s' (%s)" % [
		word, str(runeword_def(word).get("name", "?"))])
	print("[RW_TEST]   AFTER word:      armor = %.1f   max_health = %.1f" % [a2, h2])
	print("[RW_TEST]   granted bonus = %s" % str(runeword_def(word).get("bonuses", {})))
	print("[RW_TEST]   DELTA vs before: armor +%.1f   max_health +%.1f" % [a2 - a0, h2 - h0])
	# Negative controls (spelling/socket/rarity audits).
	var wrong: Dictionary = {"slot": "chest", "rarity": "rare", "ilvl": 55,
			"sockets": 2, "runes": ["om", "veth"]}
	print("[RW_TEST] audit  OM-VETH (wrong order)  completes? '%s' (want '')" % check_runeword(wrong))
	var spare: Dictionary = {"slot": "chest", "rarity": "rare", "ilvl": 55,
			"sockets": 3, "runes": ["veth", "om", ""]}
	print("[RW_TEST] audit  VETH-OM in 3-socket    completes? '%s' (want '')" % check_runeword(spare))
	var loud: Dictionary = {"slot": "chest", "rarity": "epic", "ilvl": 55,
			"sockets": 2, "runes": ["veth", "om"]}
	print("[RW_TEST] audit  VETH-OM on epic base   completes? '%s' (want '')" % check_runeword(loud))
	print("[RW_TEST] ===== self-test complete =====")


func _derived(ss: Node, actor: Node, name: String) -> float:
	if ss != null and ss.has_method("get_derived"):
		return float(ss.call("get_derived", actor, name))
	return 0.0


# --- helpers ----------------------------------------------------------------

func _item_ilvl(item: Dictionary) -> int:
	for k: String in ["ilvl", "item_level", "req_level"]:
		if item.has(k):
			return int(item[k])
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


func _color_from(v: Variant, dflt: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var al: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), al)
	return dflt


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("RunewordSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	# Sockets/runes/runeword ride the item dicts through the existing item
	# serialization (like ilvl/set_id) -- nothing extra to persist here.
	return {}


func deserialize(_d: Dictionary) -> void:
	pass
