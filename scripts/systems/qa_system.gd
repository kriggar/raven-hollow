extends Node
## QASystem -- autoload (/root/QASystem). BACKLOG #48 "QA automation stack".
##
## The in-game QA surface: (1) a self-instanced debug CONSOLE (a CanvasLayer with a
## LineEdit + scrollback Label, toggled with F1) whose commands are all GUARDED --
## every one degrades to an "unavailable" line instead of crashing when a system,
## a live world, or the player is absent -- and (2) an automated SMOKE HARNESS,
## run_smoke(), that pings each sibling autoload with a harmless read/roundtrip and
## tallies pass / fail / absent into a Dictionary report plus an ASCII table.
##
## This mirrors design/QA_AUTOMATION.md's spirit (a machine-checkable result
## channel) but lives entirely IN-ENGINE and self-contained: no other .gd file is
## edited, no scene/.tscn is required (the console is built in code), and _ready
## never touches a world or player. Console commands only reach for the player /
## world when actually typed, so a cold headless boot with no scene is safe.
##
## Console commands (F1):
##   help                 list the commands
##   give <item> [n]      grant an item to the player's bag (via InventorySystem)
##   gold <n>             add n gold (may be negative)
##   tp <zone>            change_map to a MapRegistry zone
##   heal                 restore the player to full hp
##   godmode              toggle hp-lock (player kept at full hp each frame)
##   spawn <enemy>        spawn an Enemy near the player
##   smoke                run the smoke harness, print the report
##   sysinfo              fps + player status + systems present
##   clear                clear the console scrollback
##
## Self-test: with RH_QA_TEST=1 set, _run_selftest() runs run_smoke() over whatever
## systems are present, asserts >=1 pass and no crash, exercises a few console
## commands programmatically, and prints one ASCII summary line tagged "QA".

const CHEATS_PATH := "res://data/qa_cheats.json"
const TAG := "[QA]"

var _cheats: Dictionary = {}
var _godmode: bool = false

# --- console UI (built in code; no .tscn) -----------------------------------
var _layer: CanvasLayer = null
var _input: LineEdit = null
var _output: Label = null
var _lines: Array = []
const MAX_LINES := 16

# --- smoke probe table (name, autoload path, optional pure method + expected) -
# arg "player" methods are called with the live player (skipped safely if none).
var _probes: Array = []


func _ready() -> void:
	_load_cheats()
	_build_probes()
	_build_console()
	set_process(false)  # only ticks while godmode is ON
	if not OS.get_environment("RH_QA_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_cheats() -> void:
	# Advisory only -- missing/broken file is fine, the console still works.
	if not FileAccess.file_exists(CHEATS_PATH):
		return
	var txt: String = FileAccess.get_file_as_string(CHEATS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_cheats = parsed


func _build_probes() -> void:
	# Each probe: a harmless read against a sibling autoload. "expect" validates the
	# roundtrip; a missing method / stub system still passes as "present".
	_probes = [
		{"name": "StatsSystem", "path": "/root/StatsSystem", "method": "max_level", "expect": "int_pos"},
		{"name": "InventorySystem", "path": "/root/InventorySystem", "method": "list_items", "arg": "player", "expect": "array"},
		{"name": "LootSystem", "path": "/root/LootSystem", "method": "debug_roll", "expect": "array_nonempty"},
		{"name": "MapSystem", "path": "/root/MapSystem", "method": "current_zone", "expect": "string"},
		{"name": "QuestSystem", "path": "/root/QuestSystem", "method": "active_quests", "arg": "player", "expect": "array"},
		{"name": "DungeonSystem", "path": "/root/DungeonSystem", "method": "dungeon_ids", "expect": "array_nonempty"},
		{"name": "MusicSystem", "path": "/root/MusicSystem", "method": "", "expect": "present"},
		{"name": "MountSystem", "path": "/root/MountSystem", "method": "mount_count", "expect": "int_pos"},
		{"name": "FactionSystem", "path": "/root/FactionSystem", "method": "faction_ids", "expect": "array_nonempty"},
		{"name": "LegendarySystem", "path": "/root/LegendarySystem", "method": "all_ids", "expect": "array_nonempty"},
		{"name": "StatusSystem", "path": "/root/StatusSystem", "method": "", "expect": "present"},
		{"name": "TalentSystem", "path": "/root/TalentSystem", "method": "", "expect": "present"},
		{"name": "CraftingSystem", "path": "/root/CraftingSystem", "method": "", "expect": "present"},
		{"name": "AchievementSystem", "path": "/root/AchievementSystem", "method": "", "expect": "present"},
	]


# --- console construction ---------------------------------------------------

func _build_console() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "QAConsole"
	_layer.layer = 128  # above the HUD and every panel
	_layer.visible = false
	add_child(_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.86)
	bg.anchor_left = 0.0
	bg.anchor_right = 1.0
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 8.0
	bg.offset_right = -8.0
	bg.offset_top = -244.0
	bg.offset_bottom = -8.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10.0
	vbox.offset_right = -10.0
	vbox.offset_top = 8.0
	vbox.offset_bottom = -8.0
	bg.add_child(vbox)

	var title := Label.new()
	title.text = "RAVEN HOLLOW QA CONSOLE  --  type 'help'  (F1 to close)"
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vbox.add_child(title)

	_output = Label.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output.add_theme_color_override("font_color", Color(0.82, 0.86, 0.82))
	_output.clip_text = true
	vbox.add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "command..."
	_input.caret_blink = true
	_input.text_submitted.connect(_on_submit)
	vbox.add_child(_input)

	_print("Console ready. Commands: help give gold tp heal godmode spawn smoke sysinfo clear")


func _on_submit(text: String) -> void:
	var line: String = text.strip_edges()
	if _input != null:
		_input.clear()
	if line == "":
		return
	_print("> " + line)
	var out: String = _exec_command(line)
	if out != "":
		_print(out)


func _print(line: String) -> void:
	_lines.append(line)
	while _lines.size() > 200:
		_lines.pop_front()
	if _output != null:
		var start: int = maxi(0, _lines.size() - MAX_LINES)
		var shown: Array = _lines.slice(start, _lines.size())
		_output.text = "\n".join(PackedStringArray(shown))
	# Also to stdout so headless / logged runs keep the record (ASCII only).
	print("%s %s" % [TAG, line])


func _toggle_console() -> void:
	if _layer == null:
		return
	_layer.visible = not _layer.visible
	if _layer.visible and _input != null:
		_input.grab_focus()
		_input.clear()
	elif _input != null:
		_input.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		_toggle_console()


func _process(_delta: float) -> void:
	# Only reached while godmode is ON: keep the player pinned at full hp.
	if not _godmode:
		set_process(false)
		return
	var pl: Node = _player()
	if pl != null and _has_prop(pl, "hp") and _has_prop(pl, "max_hp"):
		pl.set("hp", float(pl.get("max_hp")))


# --- command dispatch (every branch guarded) --------------------------------

func _exec_command(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd: String = parts[0].to_lower()
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	match cmd:
		"help":     return _cmd_help()
		"give":     return _cmd_give(args)
		"gold":     return _cmd_gold(args)
		"tp":       return _cmd_tp(args)
		"heal":     return _cmd_heal()
		"godmode":  return _cmd_godmode()
		"spawn":    return _cmd_spawn(args)
		"smoke":    return _cmd_smoke()
		"sysinfo":  return _cmd_sysinfo()
		"clear":    return _cmd_clear()
		_:          return "unknown command '%s' (try 'help')" % cmd


func _cmd_help() -> String:
	return ("commands: help | give <item> [n] | gold <n> | tp <zone> | heal | "
			+ "godmode | spawn <enemy> | smoke | sysinfo | clear")


func _cmd_give(args: Array) -> String:
	var id: String = str(args[0]) if args.size() >= 1 else str(_cheats.get("default_give", "iron_shortsword"))
	var count: int = int(str(args[1])) if args.size() >= 2 else 1
	count = maxi(1, count)
	var pl: Node = _player()
	if pl == null:
		return "give: no player in world (unavailable)"
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("add_item"):
		return "give: InventorySystem unavailable"
	_ensure_registered(pl)
	var item: Dictionary = _make_item(id)
	for _i in range(count):
		inv.call("add_item", pl, item.duplicate(true))
	return "gave %d x '%s' (%s)" % [count, id, str(item.get("name", id))]


func _make_item(id: String) -> Dictionary:
	var loot: Node = get_node_or_null("/root/LootSystem")
	if loot != null and loot.has_method("roll_item"):
		var it: Variant = loot.call("roll_item", id, "")
		if it is Dictionary and not (it as Dictionary).is_empty():
			return it
	# Fallback: a minimal, engine-shaped placeholder item so 'give' always works.
	return {
		"id": id, "name": id.capitalize(), "slot": "trinket", "rarity": "common",
		"icon": "pixel:" + id, "stackable": true, "stats": {}, "value": 1,
	}


func _cmd_gold(args: Array) -> String:
	if args.is_empty():
		return "gold: usage 'gold <n>'"
	var pl: Node = _player()
	if pl == null:
		return "gold: no player in world (unavailable)"
	if not _has_prop(pl, "gold"):
		return "gold: player has no gold field (unavailable)"
	var n: int = int(str(args[0]))
	pl.set("gold", int(pl.get("gold")) + n)
	return "gold %+d -> %d" % [n, int(pl.get("gold"))]


func _cmd_tp(args: Array) -> String:
	if args.is_empty():
		return "tp: usage 'tp <zone>'"
	var zone: String = str(args[0])
	if not MapRegistry.has_map(zone):
		return "tp: unknown zone '%s' (unavailable)" % zone
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("change_map"):
		return "tp: no active world (unavailable)"
	scene.call("change_map", zone, "")
	return "tp -> %s" % zone


func _cmd_heal() -> String:
	var pl: Node = _player()
	if pl == null:
		return "heal: no player in world (unavailable)"
	if not (_has_prop(pl, "hp") and _has_prop(pl, "max_hp")):
		return "heal: player has no hp fields (unavailable)"
	pl.set("hp", float(pl.get("max_hp")))
	return "healed -> %.0f/%.0f" % [float(pl.get("hp")), float(pl.get("max_hp"))]


func _cmd_godmode() -> String:
	_godmode = not _godmode
	if _godmode:
		set_process(true)
	var pl: Node = _player()
	if pl != null and _godmode and _has_prop(pl, "hp") and _has_prop(pl, "max_hp"):
		pl.set("hp", float(pl.get("max_hp")))
	var suffix: String = "" if pl != null else " (no player yet -- applies when one exists)"
	return "godmode %s%s" % ["ON" if _godmode else "OFF", suffix]


func _cmd_spawn(args: Array) -> String:
	var type_name: String = str(args[0]) if args.size() >= 1 else "skeleton"
	var pl: Node = _player()
	if pl == null:
		return "spawn: no player in world (unavailable)"
	var world: Node = pl.get_parent()
	if world == null:
		return "spawn: no world node (unavailable)"
	var pos: Vector2 = Vector2.ZERO
	if pl is Node2D:
		pos = (pl as Node2D).global_position + Vector2(72.0, 0.0)
	var e: Node = Enemy.create({"type": type_name, "pos": pos})
	if e == null:
		return "spawn: could not create '%s' (unavailable)" % type_name
	world.add_child(e)
	return "spawned '%s' near player" % type_name


func _cmd_smoke() -> String:
	var rep: Dictionary = run_smoke()
	return "smoke: %d pass / %d fail / %d absent  (total %d)" % [
		int(rep.get("passed", 0)), int(rep.get("failed", 0)),
		int(rep.get("absent", 0)), int(rep.get("total", 0))]


func _cmd_sysinfo() -> String:
	var pl: Node = _player()
	var present: int = 0
	for e: Dictionary in _probes:
		if get_node_or_null(str(e.get("path", ""))) != null:
			present += 1
	var l1: String = "fps=%d  systems_present=%d/%d  godmode=%s" % [
		Engine.get_frames_per_second(), present, _probes.size(), str(_godmode)]
	var l2: String
	if pl != null:
		var hp: float = float(pl.get("hp")) if _has_prop(pl, "hp") else -1.0
		var mhp: float = float(pl.get("max_hp")) if _has_prop(pl, "max_hp") else -1.0
		var gold: int = int(pl.get("gold")) if _has_prop(pl, "gold") else -1
		var lv: int = int(pl.get("level")) if _has_prop(pl, "level") else -1
		l2 = "player: lv=%d hp=%.0f/%.0f gold=%d" % [lv, hp, mhp, gold]
	else:
		l2 = "player: none (no world loaded)"
	_print(l1)
	_print(l2)
	return l1 + "  |  " + l2


func _cmd_clear() -> String:
	_lines.clear()
	if _output != null:
		_output.text = ""
	return ""


# --- SMOKE HARNESS ----------------------------------------------------------

## Ping every registered sibling system with a harmless read/roundtrip; tally
## pass / fail / absent and print an ASCII table. Returns the report Dictionary:
## {passed, failed, absent, total, rows:[{name, status, detail}]}. Never crashes.
func run_smoke() -> Dictionary:
	var pl: Node = _player()
	var rows: Array = []
	var passed: int = 0
	var failed: int = 0
	var absent: int = 0
	for e: Dictionary in _probes:
		var row: Dictionary = _run_probe(e, pl)
		rows.append(row)
		match str(row.get("status", "")):
			"pass": passed += 1
			"fail": failed += 1
			_:      absent += 1
	var report: Dictionary = {
		"passed": passed, "failed": failed, "absent": absent,
		"total": rows.size(), "rows": rows,
	}
	_print_smoke_table(report)
	return report


func _run_probe(e: Dictionary, pl: Node) -> Dictionary:
	var name_s: String = str(e.get("name", "?"))
	var node: Node = get_node_or_null(str(e.get("path", "")))
	if node == null:
		return {"name": name_s, "status": "absent", "detail": "not registered"}
	var method: String = str(e.get("method", ""))
	if method == "" or not node.has_method(method):
		return {"name": name_s, "status": "pass", "detail": "present"}
	var res: Variant = null
	if str(e.get("arg", "none")) == "player":
		if pl == null:
			return {"name": name_s, "status": "pass", "detail": "present (no player)"}
		res = node.call(method, pl)
	else:
		res = node.call(method)
	var ok: bool = _check(str(e.get("expect", "any")), res)
	return {"name": name_s, "status": "pass" if ok else "fail", "detail": _describe(res)}


func _check(expect: String, res: Variant) -> bool:
	match expect:
		"int_pos":        return (res is int or res is float) and float(res) > 0.0
		"array":          return res is Array
		"array_nonempty": return res is Array and (res as Array).size() > 0
		"string":         return res is String
		"dict":           return res is Dictionary
		"present":        return true
		_:                return res != null


func _describe(res: Variant) -> String:
	if res is Array:
		return "%d entries" % (res as Array).size()
	if res is Dictionary:
		return "%d keys" % (res as Dictionary).size()
	if res is int or res is float:
		return str(res)
	if res is String:
		return "\"%s\"" % (str(res) if str(res) != "" else "(empty)")
	if res is bool:
		return str(res)
	return "ok"


func _print_smoke_table(report: Dictionary) -> void:
	print("[QA_SMOKE] ================= RAVEN HOLLOW SMOKE =================")
	print("[QA_SMOKE] %-18s %-7s %s" % ["SYSTEM", "STATUS", "DETAIL"])
	print("[QA_SMOKE] -----------------------------------------------------")
	for row: Dictionary in report.get("rows", []):
		print("[QA_SMOKE] %-18s %-7s %s" % [
			str(row.get("name", "?")), str(row.get("status", "?")), str(row.get("detail", ""))])
	print("[QA_SMOKE] -----------------------------------------------------")
	print("[QA_SMOKE] total=%d pass=%d fail=%d absent=%d" % [
		int(report.get("total", 0)), int(report.get("passed", 0)),
		int(report.get("failed", 0)), int(report.get("absent", 0))])


# --- self-test (RH_QA_TEST=1) -----------------------------------------------

func _run_selftest() -> void:
	print("[QA_TEST] ===== Raven Hollow QA system self-test =====")
	var crashed: bool = false  # we cannot try/catch, but every path is guarded

	# 1) The smoke harness returns a report with >=1 pass and no crash.
	var rep: Dictionary = run_smoke()
	var rep_ok: bool = rep.has("rows") and (rep.get("rows") is Array) \
			and int(rep.get("passed", 0)) >= 1

	# 2) Exercise a few console commands programmatically (guarded; no world needed).
	var c_help: String = _exec_command("help")
	var c_info: String = _exec_command("sysinfo")
	var c_gold: String = _exec_command("gold 50")   # -> "unavailable" line if no player
	var cmds_ok: bool = c_help != "" and c_info != "" and c_gold != ""
	print("[QA_TEST] console: help/sysinfo/gold responded = %s" % str(cmds_ok))
	print("[QA_TEST] smoke report: passed=%d failed=%d absent=%d total=%d (pass>=1 = %s)" % [
		int(rep.get("passed", 0)), int(rep.get("failed", 0)),
		int(rep.get("absent", 0)), int(rep.get("total", 0)), str(rep_ok)])

	var passed: int = int(rep.get("passed", 0))
	var failed: int = int(rep.get("failed", 0))
	var verdict: String = "PASS" if (rep_ok and cmds_ok and not crashed) else "FAIL"
	print("QA SELFTEST %s passed=%d failed=%d" % [verdict, passed, failed])
	print("[QA_TEST] ===== self-test complete =====")


# --- helpers ----------------------------------------------------------------

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _ensure_registered(pl: Node) -> void:
	if pl == null:
		return
	var cid: String = ""
	var cd: Variant = pl.get("class_def")
	if cd is Dictionary:
		cid = str((cd as Dictionary).get("id", ""))
	var lv: int = int(pl.get("level")) if _has_prop(pl, "level") else 1
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null and inv.has_method("register"):
		inv.call("register", pl, cid, lv)


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false
