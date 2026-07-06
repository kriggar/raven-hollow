extends Node
## AdminSystem -- autoload (/root/AdminSystem). BACKLOG #92
## "Owner CONTROL INTERFACE + easy ADMIN PANEL for manual QA".
##
## An in-game, AAA-studio-style ADMIN / QA panel: a self-instanced tabbed
## CanvasLayer GUI toggled with F2. Where QASystem (F1) is a TEXT console, this
## is a point-and-click PANEL exposing the knobs of the sibling autoloads through
## dropdowns / spinners / buttons. Four tabs:
##   WORLD    -- teleport to any registered zone, set time-of-day, set weather.
##   PLAYER   -- set level / gold / hp, grant an item, learn an ability.
##   SYSTEMS  -- live toggles (seamless-world, fog, godmode), a registered-autoload
##               readout, and a "run smoke" button that calls QASystem.run_smoke().
##   CONTENT  -- spawn an enemy, start a dungeon, fire a cinematic, give a quest.
##
## SAFETY CONTRACT (same spirit as every sibling system):
##  * Fully self-contained: no other .gd file is edited, no .tscn/asset is loaded
##    (the whole panel is built in code), and _ready never touches a world/player,
##    so a cold headless boot is safe. The panel is built lazily on first open.
##  * Every control is GUARDED. A missing autoload / method / live world / player
##    disables (greys) that control or makes its action return a "safely
##    unavailable" result -- it NEVER crashes.
##  * Read-only status readouts refresh on open (and after each action).
##
## Public API:
##   open_admin() / close_admin() / toggle_admin() / is_open() -> bool
##   do_action(name, args := {}) -> Dictionary   {ok, available, msg}
## Signals:
##   admin_opened
##   admin_action(name, args)
##
## Self-test: with RH_ADMIN_TEST=1, _run_selftest() opens the panel (asserting all
## tabs instanced), invokes a spread of actions across tabs (each must perform or
## safely report unavailable), closes (asserting the panel frees), and prints one
## ASCII line tagged "ADMIN".

signal admin_opened
signal admin_action(name, args)

const TAG := "[ADMIN]"
const CONFIG_PATH := "res://data/admin_config.json"

## Weather type ids -> WeatherController.Type enum index.
const WEATHER_TYPES: Array = ["clear", "rain", "storm", "snow", "fog", "ash"]

## Sibling autoloads surfaced in the SYSTEMS readout (name -> /root path).
const KNOWN_SYSTEMS: Array = [
	"StatsSystem", "InventorySystem", "QuestSystem", "FactionSystem",
	"CalendarSystem", "WorldStreamSystem", "MapSystem", "DungeonSystem",
	"CinematicSystem", "TalentSystem", "RenderFXSystem", "QASystem",
	"LootSystem", "MountSystem", "LegendarySystem", "StatusSystem",
]

var _config: Dictionary = {}
var _godmode: bool = false

# --- panel (built in code; no .tscn) ----------------------------------------
var _layer: CanvasLayer = null
var _tabs: TabContainer = null
var _log: Label = null

# Live control references (read at action time; guarded if null).
var _zone_opt: OptionButton = null
var _time_spin: SpinBox = null
var _weather_opt: OptionButton = null
var _level_spin: SpinBox = null
var _gold_spin: SpinBox = null
var _hp_spin: SpinBox = null
var _item_edit: LineEdit = null
var _ability_opt: OptionButton = null
var _enemy_edit: LineEdit = null
var _dungeon_opt: OptionButton = null
var _cine_opt: OptionButton = null
var _quest_opt: OptionButton = null

# Status readout labels (refreshed on open + after each action).
var _status_world: Label = null
var _status_player: Label = null
var _status_systems: Label = null
var _status_content: Label = null

# Live-toggle buttons (text updated to reflect current state).
var _btn_seamless: Button = null
var _btn_fog: Button = null
var _btn_godmode: Button = null


func _ready() -> void:
	_load_config()
	set_process(false)  # only ticks while godmode is ON
	if not OS.get_environment("RH_ADMIN_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_ADMIN").is_empty():
		call_deferred("open_admin")  # QA/screenshot: open the hub on boot


func _load_config() -> void:
	# Advisory only -- a missing/broken file is fine, the panel still works.
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var txt: String = FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_config = parsed


# --- input (F2 toggles the panel) -------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		toggle_admin()


# --- open / close -----------------------------------------------------------

func is_open() -> bool:
	return _layer != null and is_instance_valid(_layer) and _layer.visible


func toggle_admin() -> void:
	if is_open():
		close_admin()
	else:
		open_admin()


func open_admin() -> void:
	_ensure_panel()
	if _layer == null:
		return
	_repopulate_dropdowns()
	_refresh_all_status()
	_layer.visible = true
	admin_opened.emit()


func close_admin() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_tabs = null
	# Drop stale control refs so a re-open rebuilds cleanly.
	_zone_opt = null
	_time_spin = null
	_weather_opt = null
	_level_spin = null
	_gold_spin = null
	_hp_spin = null
	_item_edit = null
	_ability_opt = null
	_enemy_edit = null
	_dungeon_opt = null
	_cine_opt = null
	_quest_opt = null
	_status_world = null
	_status_player = null
	_status_systems = null
	_status_content = null
	_btn_seamless = null
	_btn_fog = null
	_btn_godmode = null
	_log = null


# --- panel construction (all in code) ---------------------------------------

func _ensure_panel() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "AdminPanel"
	_layer.layer = 130  # above the HUD, panels, and the QA console (128)
	_layer.visible = false
	add_child(_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 0.94)
	bg.anchor_left = 0.5
	bg.anchor_top = 0.5
	bg.anchor_right = 0.5
	bg.anchor_bottom = 0.5
	bg.offset_left = -300.0
	bg.offset_right = 300.0
	bg.offset_top = -220.0
	bg.offset_bottom = 220.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 12.0
	root.offset_top = 10.0
	root.offset_right = -12.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 6)
	bg.add_child(root)

	var title := Label.new()
	title.text = "RAVEN HOLLOW  --  ADMIN CONTROL PANEL   (F2 to close)"
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	root.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_build_world_tab()
	_build_player_tab()
	_build_systems_tab()
	_build_content_tab()

	_log = Label.new()
	_log.text = "ready."
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_color_override("font_color", Color(0.72, 0.86, 0.72))
	root.add_child(_log)


func _new_tab(tab_name: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.name = tab_name
	vb.add_theme_constant_override("separation", 5)
	_tabs.add_child(vb)
	return vb


func _add_status(parent: VBoxContainer) -> Label:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.68, 0.74, 0.85))
	parent.add_child(lbl)
	var sep := HSeparator.new()
	parent.add_child(sep)
	return lbl


func _row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(96.0, 0.0)
	hb.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	parent.add_child(hb)


func _button(text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(cb)
	return b


func _build_world_tab() -> void:
	var tab := _new_tab("WORLD")
	_status_world = _add_status(tab)

	_zone_opt = OptionButton.new()
	_row(tab, "Zone", _zone_opt)
	tab.add_child(_button("Teleport", func() -> void: _ui("teleport",
		{"zone": _opt_meta(_zone_opt)})))

	_time_spin = SpinBox.new()
	_time_spin.min_value = 0.0
	_time_spin.max_value = 23.0
	_time_spin.step = 1.0
	_time_spin.value = 12.0
	_row(tab, "Hour (0-23)", _time_spin)
	tab.add_child(_button("Set time", func() -> void: _ui("set_time",
		{"hour": _time_spin.value})))

	_weather_opt = OptionButton.new()
	for i in range(WEATHER_TYPES.size()):
		_weather_opt.add_item(str(WEATHER_TYPES[i]).capitalize(), i)
	_row(tab, "Weather", _weather_opt)
	tab.add_child(_button("Set weather", func() -> void: _ui("set_weather",
		{"type": _weather_opt.get_selected_id()})))


func _build_player_tab() -> void:
	var tab := _new_tab("PLAYER")
	_status_player = _add_status(tab)

	_level_spin = SpinBox.new()
	_level_spin.min_value = 1.0
	_level_spin.max_value = 100.0
	_level_spin.step = 1.0
	_level_spin.value = 1.0
	_row(tab, "Level", _level_spin)
	tab.add_child(_button("Set level", func() -> void: _ui("set_level",
		{"level": int(_level_spin.value)})))

	_gold_spin = SpinBox.new()
	_gold_spin.min_value = 0.0
	_gold_spin.max_value = 9999999.0
	_gold_spin.step = 100.0
	_row(tab, "Gold", _gold_spin)
	tab.add_child(_button("Set gold", func() -> void: _ui("set_gold",
		{"gold": int(_gold_spin.value)})))

	_hp_spin = SpinBox.new()
	_hp_spin.min_value = 1.0
	_hp_spin.max_value = 999999.0
	_hp_spin.step = 10.0
	_hp_spin.value = 100.0
	_row(tab, "HP", _hp_spin)
	tab.add_child(_button("Set / full HP", func() -> void: _ui("set_hp",
		{"hp": _hp_spin.value})))

	_item_edit = LineEdit.new()
	_item_edit.placeholder_text = "item id (e.g. iron_shortsword)"
	_item_edit.text = str(_config.get("default_item", "iron_shortsword"))
	_row(tab, "Item id", _item_edit)
	tab.add_child(_button("Grant item", func() -> void: _ui("grant_item",
		{"id": _item_edit.text.strip_edges()})))

	_ability_opt = OptionButton.new()
	_row(tab, "Ability", _ability_opt)
	tab.add_child(_button("Learn ability", func() -> void: _ui("learn_ability",
		{"id": _opt_meta(_ability_opt)})))


func _build_systems_tab() -> void:
	var tab := _new_tab("SYSTEMS")
	_status_systems = _add_status(tab)

	_btn_seamless = _button("Seamless world: ...", func() -> void:
		_ui("toggle_seamless", {}))
	tab.add_child(_btn_seamless)

	_btn_fog = _button("Fog overlay: ...", func() -> void: _ui("toggle_fog", {}))
	tab.add_child(_btn_fog)

	_btn_godmode = _button("Godmode: ...", func() -> void:
		_ui("toggle_godmode", {}))
	tab.add_child(_btn_godmode)

	tab.add_child(_button("Run smoke test (QA)", func() -> void:
		_ui("run_smoke", {})))


func _build_content_tab() -> void:
	var tab := _new_tab("CONTENT")
	_status_content = _add_status(tab)

	_enemy_edit = LineEdit.new()
	_enemy_edit.placeholder_text = "enemy type (e.g. skeleton)"
	_enemy_edit.text = str(_config.get("default_enemy", "skeleton"))
	_row(tab, "Enemy", _enemy_edit)
	tab.add_child(_button("Spawn enemy", func() -> void: _ui("spawn_enemy",
		{"type": _enemy_edit.text.strip_edges()})))

	_dungeon_opt = OptionButton.new()
	_row(tab, "Dungeon", _dungeon_opt)
	tab.add_child(_button("Start dungeon", func() -> void: _ui("start_dungeon",
		{"id": _opt_meta(_dungeon_opt)})))

	_cine_opt = OptionButton.new()
	_row(tab, "Cinematic", _cine_opt)
	tab.add_child(_button("Fire cinematic", func() -> void: _ui("fire_cinematic",
		{"id": _opt_meta(_cine_opt)})))

	_quest_opt = OptionButton.new()
	_row(tab, "Quest", _quest_opt)
	tab.add_child(_button("Give quest", func() -> void: _ui("give_quest",
		{"id": _opt_meta(_quest_opt)})))


# --- dropdown population (live data, guarded) -------------------------------

func _repopulate_dropdowns() -> void:
	# Zones -- MapRegistry is a class_name helper (always available).
	_fill_opt_ids(_zone_opt, _zone_ids())
	# Abilities -- the player's class spellbook (empty if no player/system).
	_fill_opt_ids(_ability_opt, _ability_ids())
	# Dungeons.
	var ds: Node = _sys("DungeonSystem")
	_fill_opt_ids(_dungeon_opt, _call_ids(ds, "dungeon_ids"))
	# Cinematics.
	var cs: Node = _sys("CinematicSystem")
	_fill_opt_ids(_cine_opt, _call_ids(cs, "ids"))
	# Quests.
	var qs: Node = _sys("QuestSystem")
	_fill_opt_ids(_quest_opt, _call_ids(qs, "all_ids"))


func _fill_opt_ids(opt: OptionButton, ids: Array) -> void:
	if opt == null:
		return
	opt.clear()
	if ids.is_empty():
		opt.add_item("(none available)", 0)
		opt.set_item_metadata(0, "")
		opt.disabled = true
		return
	opt.disabled = false
	for i in range(ids.size()):
		var id_s: String = str(ids[i])
		opt.add_item(id_s, i)
		opt.set_item_metadata(i, id_s)


func _opt_meta(opt: OptionButton) -> String:
	if opt == null:
		return ""
	var idx: int = opt.get_selected()
	if idx < 0:
		return ""
	var m: Variant = opt.get_item_metadata(idx)
	return str(m) if m != null else ""


func _zone_ids() -> Array:
	# MapRegistry.map_ids() is static; wrap so a missing global never crashes.
	var out: Array = []
	for z: Variant in MapRegistry.map_ids():
		out.append(str(z))
	out.sort()
	return out


func _ability_ids() -> Array:
	var ts: Node = _sys("TalentSystem")
	var pl: Node = _player()
	if ts == null or pl == null or not ts.has_method("spellbook_for"):
		return []
	var cid: String = _class_id(pl)
	if cid == "" and ts.has_method("class_of"):
		cid = str(ts.call("class_of", pl))
	var out: Array = []
	var book: Variant = ts.call("spellbook_for", cid)
	if book is Array:
		for t: Variant in book:
			if t is Dictionary:
				out.append(str((t as Dictionary).get("id", "")))
			else:
				out.append(str(t))
	return out


func _call_ids(node: Node, method: String) -> Array:
	if node == null or not node.has_method(method):
		return []
	var res: Variant = node.call(method)
	return res if res is Array else []


# --- status readouts --------------------------------------------------------

func _refresh_all_status() -> void:
	_refresh_toggle_labels()
	var pl: Node = _player()
	var scn: Node = get_tree().current_scene
	var have_world: bool = scn != null and scn.has_method("change_map")

	if _status_world != null:
		var zone: String = _current_zone()
		_status_world.text = "world: %s | zone: %s | time: %s | weather: %s" % [
			("live" if have_world else "no world"), zone,
			_time_text(), _weather_text()]

	if _status_player != null:
		if pl == null:
			_status_player.text = "player: none (no world loaded)"
		else:
			var lv: int = int(pl.get("level")) if _has_prop(pl, "level") else -1
			var hp: float = float(pl.get("hp")) if _has_prop(pl, "hp") else -1.0
			var mhp: float = float(pl.get("max_hp")) if _has_prop(pl, "max_hp") else -1.0
			var gold: int = int(pl.get("gold")) if _has_prop(pl, "gold") else -1
			_status_player.text = "player: lv=%d  hp=%.0f/%.0f  gold=%d  class=%s" % [
				lv, hp, mhp, gold, _class_id(pl)]

	if _status_systems != null:
		var present: int = 0
		var names: Array = []
		for s: String in KNOWN_SYSTEMS:
			if _sys(s) != null:
				present += 1
				names.append(s)
		_status_systems.text = "autoloads present: %d/%d\n%s" % [
			present, KNOWN_SYSTEMS.size(), ", ".join(PackedStringArray(names))]

	if _status_content != null:
		var ds: Node = _sys("DungeonSystem")
		var qs: Node = _sys("QuestSystem")
		var cs: Node = _sys("CinematicSystem")
		var nd: int = _call_ids(ds, "dungeon_ids").size()
		var nq: int = _call_ids(qs, "all_ids").size()
		var nc: int = _call_ids(cs, "ids").size()
		_status_content.text = "dungeons: %d | quests: %d | cinematics: %d | world: %s" % [
			nd, nq, nc, ("live" if have_world else "none")]


func _refresh_toggle_labels() -> void:
	if _btn_seamless != null:
		var ws: Node = _sys("WorldStreamSystem")
		if ws == null:
			_btn_seamless.text = "Seamless world: (unavailable)"
			_btn_seamless.disabled = true
		else:
			_btn_seamless.disabled = false
			_btn_seamless.text = "Seamless world: %s" % (
				"ON" if bool(ws.get("enabled")) else "OFF")
	if _btn_fog != null:
		var fx: Node = _sys("RenderFXSystem")
		if fx == null or not fx.has_method("is_fog_on"):
			_btn_fog.text = "Fog overlay: (unavailable)"
			_btn_fog.disabled = true
		else:
			_btn_fog.disabled = false
			_btn_fog.text = "Fog overlay: %s" % (
				"ON" if bool(fx.call("is_fog_on")) else "OFF")
	if _btn_godmode != null:
		_btn_godmode.text = "Godmode: %s" % ("ON" if _godmode else "OFF")


# --- UI action wrapper (button -> do_action -> log + refresh) ---------------

func _ui(name: String, args: Dictionary) -> void:
	var res: Dictionary = do_action(name, args)
	if _log != null:
		var tag: String = "ok" if bool(res.get("ok", false)) else (
			"--" if not bool(res.get("available", true)) else "x")
		_log.text = "[%s] %s: %s" % [tag, name, str(res.get("msg", ""))]
	_refresh_all_status()


# =============================================================================
# ACTION DISPATCH -- the single guarded entry point (buttons + selftest).
# Returns {ok:bool, available:bool, msg:String}. Never crashes.
# =============================================================================
func do_action(name: String, args: Dictionary = {}) -> Dictionary:
	var res: Dictionary
	match name:
		"teleport":       res = _act_teleport(args)
		"set_time":       res = _act_set_time(args)
		"set_weather":    res = _act_set_weather(args)
		"set_level":      res = _act_set_level(args)
		"set_gold":       res = _act_set_gold(args)
		"set_hp":         res = _act_set_hp(args)
		"grant_item":     res = _act_grant_item(args)
		"learn_ability":  res = _act_learn_ability(args)
		"toggle_seamless": res = _act_toggle_seamless()
		"toggle_fog":     res = _act_toggle_fog()
		"toggle_godmode": res = _act_toggle_godmode()
		"run_smoke":      res = _act_run_smoke()
		"spawn_enemy":    res = _act_spawn_enemy(args)
		"start_dungeon":  res = _act_start_dungeon(args)
		"fire_cinematic": res = _act_fire_cinematic(args)
		"give_quest":     res = _act_give_quest(args)
		_:                res = _unavailable("unknown action '%s'" % name)
	admin_action.emit(name, args)
	return res


func _ok(msg: String) -> Dictionary:
	return {"ok": true, "available": true, "msg": msg}


func _unavailable(msg: String) -> Dictionary:
	return {"ok": false, "available": false, "msg": msg}


func _fail(msg: String) -> Dictionary:
	return {"ok": false, "available": true, "msg": msg}


# --- WORLD actions ----------------------------------------------------------

func _act_teleport(args: Dictionary) -> Dictionary:
	var zone: String = str(args.get("zone", ""))
	if zone == "":
		return _fail("no zone selected")
	if not MapRegistry.has_map(zone):
		return _fail("unknown zone '%s'" % zone)
	var scn: Node = get_tree().current_scene
	if scn == null or not scn.has_method("change_map"):
		return _unavailable("no active world")
	scn.call("change_map", zone, "")
	return _ok("teleported to '%s'" % zone)


func _act_set_time(args: Dictionary) -> Dictionary:
	var hour: float = float(args.get("hour", 12.0))
	var dn: Node = _day_night()
	if dn == null or not dn.has_method("set_time"):
		return _unavailable("day/night node absent (no world)")
	dn.call("set_time", hour)
	return _ok("time set to %02d:00" % int(hour))


func _act_set_weather(args: Dictionary) -> Dictionary:
	var t: int = int(args.get("type", 0))
	var wx: Node = _weather()
	if wx == null or not wx.has_method("set_weather"):
		return _unavailable("weather node absent (no world)")
	t = clampi(t, 0, WEATHER_TYPES.size() - 1)
	wx.call("set_weather", t, 1.0, 1.5)
	return _ok("weather -> %s" % str(WEATHER_TYPES[t]))


# --- PLAYER actions ---------------------------------------------------------

func _act_set_level(args: Dictionary) -> Dictionary:
	var level: int = maxi(1, int(args.get("level", 1)))
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	var st: Node = _sys("StatsSystem")
	if st != null and st.has_method("apply_level"):
		if st.has_method("is_registered") and not bool(st.call("is_registered", pl)):
			if st.has_method("register"):
				st.call("register", pl, _class_id(pl), level)
		st.call("apply_level", pl, level)
		return _ok("level set to %d (StatsSystem)" % level)
	if _has_prop(pl, "level"):
		pl.set("level", level)
		return _ok("level field set to %d" % level)
	return _fail("player has no level field / StatsSystem")


func _act_set_gold(args: Dictionary) -> Dictionary:
	var gold: int = maxi(0, int(args.get("gold", 0)))
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	if not _has_prop(pl, "gold"):
		return _fail("player has no gold field")
	pl.set("gold", gold)
	return _ok("gold set to %d" % gold)


func _act_set_hp(args: Dictionary) -> Dictionary:
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	if not (_has_prop(pl, "hp") and _has_prop(pl, "max_hp")):
		return _fail("player has no hp fields")
	var mhp: float = float(pl.get("max_hp"))
	var hp: float = clampf(float(args.get("hp", mhp)), 1.0, mhp)
	pl.set("hp", hp)
	return _ok("hp set to %.0f/%.0f" % [hp, mhp])


func _act_grant_item(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	if id == "":
		return _fail("no item id")
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	var inv: Node = _sys("InventorySystem")
	if inv == null or not inv.has_method("add_item"):
		return _unavailable("InventorySystem absent")
	if inv.has_method("register") and inv.has_method("list_items"):
		# Ensure the player has a bag before granting.
		var listed: Variant = inv.call("list_items", pl)
		if not (listed is Array):
			inv.call("register", pl, _class_id(pl), _level_of(pl))
	var item: Dictionary = _make_item(id)
	var ok: bool = bool(inv.call("add_item", pl, item))
	return _ok("granted '%s'" % id) if ok else _fail("bag full / rejected '%s'" % id)


func _act_learn_ability(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	if id == "":
		return _fail("no ability selected")
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	var ts: Node = _sys("TalentSystem")
	if ts == null or not ts.has_method("learn"):
		return _unavailable("TalentSystem absent")
	if ts.has_method("is_registered") and not bool(ts.call("is_registered", pl)):
		if ts.has_method("register"):
			ts.call("register", pl, _class_id(pl))
	# Give a point so the learn is affordable, then attempt it.
	if ts.has_method("grant_point"):
		ts.call("grant_point", pl, 1)
	var ok: bool = bool(ts.call("learn", pl, id))
	return _ok("learned '%s'" % id) if ok else _fail("prereqs unmet for '%s'" % id)


# --- SYSTEMS actions --------------------------------------------------------

func _act_toggle_seamless() -> Dictionary:
	var ws: Node = _sys("WorldStreamSystem")
	if ws == null:
		return _unavailable("WorldStreamSystem absent")
	var now: bool = not bool(ws.get("enabled"))
	ws.set("enabled", now)
	if not now and ws.has_method("reset"):
		ws.call("reset")
	return _ok("seamless world %s" % ("ON" if now else "OFF"))


func _act_toggle_fog() -> Dictionary:
	var fx: Node = _sys("RenderFXSystem")
	if fx == null or not fx.has_method("set_fog") or not fx.has_method("is_fog_on"):
		return _unavailable("RenderFXSystem absent")
	var now: bool = not bool(fx.call("is_fog_on"))
	fx.call("set_fog", now)
	return _ok("fog overlay %s" % ("ON" if now else "OFF"))


func _act_toggle_godmode() -> Dictionary:
	_godmode = not _godmode
	if _godmode:
		set_process(true)
		var pl: Node = _player()
		if pl != null and _has_prop(pl, "hp") and _has_prop(pl, "max_hp"):
			pl.set("hp", float(pl.get("max_hp")))
	var suffix: String = "" if _player() != null else " (applies when a player exists)"
	return _ok("godmode %s%s" % ["ON" if _godmode else "OFF", suffix])


func _act_run_smoke() -> Dictionary:
	var qa: Node = _sys("QASystem")
	if qa == null or not qa.has_method("run_smoke"):
		return _unavailable("QASystem absent")
	var rep: Variant = qa.call("run_smoke")
	if rep is Dictionary:
		var d: Dictionary = rep
		return _ok("smoke: %d pass / %d fail / %d absent" % [
			int(d.get("passed", 0)), int(d.get("failed", 0)),
			int(d.get("absent", 0))])
	return _ok("smoke run")


# --- CONTENT actions --------------------------------------------------------

func _act_spawn_enemy(args: Dictionary) -> Dictionary:
	var type_name: String = str(args.get("type", "skeleton"))
	if type_name == "":
		type_name = "skeleton"
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	var world: Node = pl.get_parent()
	if world == null:
		return _unavailable("no world node")
	var pos: Vector2 = Vector2.ZERO
	if pl is Node2D:
		pos = (pl as Node2D).global_position + Vector2(72.0, 0.0)
	var e: Node = Enemy.create({"type": type_name, "pos": pos})
	if e == null:
		return _fail("could not create '%s'" % type_name)
	world.add_child(e)
	return _ok("spawned '%s' near player" % type_name)


func _act_start_dungeon(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	if id == "":
		return _fail("no dungeon selected")
	var ds: Node = _sys("DungeonSystem")
	if ds == null or not ds.has_method("enter_dungeon"):
		return _unavailable("DungeonSystem absent")
	var out: Variant = ds.call("enter_dungeon", id, _player(), true)
	if out is Dictionary and not bool((out as Dictionary).get("ok", true)):
		return _fail("dungeon '%s': %s" % [id, str((out as Dictionary).get("reason", "declined"))])
	return _ok("entered dungeon '%s'" % id)


func _act_fire_cinematic(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	if id == "":
		return _fail("no cinematic selected")
	var cs: Node = _sys("CinematicSystem")
	if cs == null or not cs.has_method("play"):
		return _unavailable("CinematicSystem absent")
	if cs.has_method("has_cinematic") and not bool(cs.call("has_cinematic", id)):
		return _fail("unknown cinematic '%s'" % id)
	cs.call("play", id)
	return _ok("fired cinematic '%s'" % id)


func _act_give_quest(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("id", ""))
	if id == "":
		return _fail("no quest selected")
	var pl: Node = _player()
	if pl == null:
		return _unavailable("no player in world")
	var qs: Node = _sys("QuestSystem")
	if qs == null or not qs.has_method("accept"):
		return _unavailable("QuestSystem absent")
	var ok: bool = bool(qs.call("accept", pl, id))
	if not ok and qs.has_method("offer"):
		# accept() may gate on eligibility -- offer then accept as a fallback.
		qs.call("offer", pl, id)
		ok = bool(qs.call("accept", pl, id))
	return _ok("gave quest '%s'" % id) if ok else _fail("quest '%s' not grantable" % id)


# --- godmode tick (only while ON) -------------------------------------------

func _process(_delta: float) -> void:
	if not _godmode:
		set_process(false)
		return
	var pl: Node = _player()
	if pl != null and _has_prop(pl, "hp") and _has_prop(pl, "max_hp"):
		pl.set("hp", float(pl.get("max_hp")))


# --- world-node lookups (guarded; never assume a live world) ----------------

func _sys(sys_name: String) -> Node:
	return get_node_or_null("/root/" + sys_name)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _day_night() -> Node:
	var scn: Node = get_tree().current_scene
	if scn == null:
		return null
	return scn.get_node_or_null("DayNight")


func _weather() -> Node:
	var n: Node = get_tree().get_first_node_in_group("weather")
	if n != null:
		return n
	var scn: Node = get_tree().current_scene
	if scn == null:
		return null
	return scn.get_node_or_null("Weather")


func _current_zone() -> String:
	var ms: Node = _sys("MapSystem")
	if ms != null and ms.has_method("current_zone"):
		return str(ms.call("current_zone"))
	var scn: Node = get_tree().current_scene
	if scn != null and scn.get("current_map_id") != null:
		return str(scn.get("current_map_id"))
	return "(none)"


func _time_text() -> String:
	var dn: Node = _day_night()
	if dn != null and dn.has_method("clock_text"):
		return str(dn.call("clock_text"))
	return "--:--"


func _weather_text() -> String:
	var wx: Node = _weather()
	if wx != null and wx.has_method("current_type"):
		var t: int = int(wx.call("current_type"))
		if t >= 0 and t < WEATHER_TYPES.size():
			return str(WEATHER_TYPES[t])
	return "(n/a)"


func _make_item(id: String) -> Dictionary:
	var loot: Node = _sys("LootSystem")
	if loot != null and loot.has_method("roll_item"):
		var it: Variant = loot.call("roll_item", id, "")
		if it is Dictionary and not (it as Dictionary).is_empty():
			return it
	# Minimal engine-shaped placeholder so 'grant' always works.
	return {
		"id": id, "name": id.capitalize(), "slot": "trinket", "rarity": "common",
		"icon": "pixel:" + id, "stackable": true, "stats": {}, "value": 1,
	}


func _class_id(actor: Node) -> String:
	if actor == null:
		return ""
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary:
		return str((cd as Dictionary).get("id", ""))
	return ""


func _level_of(actor: Node) -> int:
	return int(actor.get("level")) if _has_prop(actor, "level") else 1


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


# --- self-test (RH_ADMIN_TEST=1) --------------------------------------------

func _run_selftest() -> void:
	print("[ADMIN_TEST] ===== Raven Hollow admin panel self-test =====")

	# 1) Open -- panel + all four tabs must instance.
	open_admin()
	var tabs_n: int = _tabs.get_child_count() if _tabs != null else 0
	var tab_names: Array = []
	if _tabs != null:
		for c in _tabs.get_children():
			tab_names.append((c as Node).name)
	print("[ADMIN_TEST] panel open=%s tabs=%d %s" % [
		str(is_open()), tabs_n, str(tab_names)])

	# 2) Invoke a spread of actions across all four tabs. Each must return a
	#    well-formed result (performed OR safely reported unavailable) -- no crash.
	var probes: Array = [
		["set_time", {"hour": 21.0}],       # WORLD
		["set_gold", {"gold": 500}],        # PLAYER
		["toggle_godmode", {}],             # SYSTEMS
		["run_smoke", {}],                  # SYSTEMS
		["give_quest", {"id": "__none__"}], # CONTENT
	]
	var actions_ok: int = 0
	for pr: Array in probes:
		var r: Dictionary = do_action(str(pr[0]), pr[1] as Dictionary)
		# Well-formed = a dict carrying an "ok" flag; performed or gracefully
		# unavailable both count (the guard held instead of crashing).
		var well_formed: bool = r.has("ok") and r.has("available")
		if well_formed:
			actions_ok += 1
		print("[ADMIN_TEST]   %-14s -> ok=%s avail=%s : %s" % [
			str(pr[0]), str(r.get("ok")), str(r.get("available")),
			str(r.get("msg", ""))])
	# Leave godmode off regardless of world state.
	if _godmode:
		do_action("toggle_godmode", {})

	# 3) Close -- the panel must free.
	close_admin()
	await get_tree().process_frame
	var freed: bool = _layer == null or not is_instance_valid(_layer)
	print("[ADMIN_TEST] closed; panel freed=%s" % str(freed))

	var pass_ok: bool = tabs_n == 4 and actions_ok == probes.size() and freed
	print("ADMIN SELFTEST %s tabs=%d actions_ok=%d" % [
		"PASS" if pass_ok else "FAIL", tabs_n, actions_ok])
	print("[ADMIN_TEST] ===== self-test complete =====")
