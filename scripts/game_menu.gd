class_name GameMenu
extends CanvasLayer
## GameMenu — the ONE discoverable hub for every panel in Raven Hollow.
##
## The problem it solves: every feature system (auction, bank, reputation,
## achievements, titles, mounts, quest log, socketing, calendar, legendary codex,
## PvP, chronicle, bestiary, options, map...) was reachable ONLY via an
## undocumented single-letter hotkey — several of which collided (N: Calendar vs
## PvP vs Narrative; Y: Achievements vs Ferry) leaving panels dead. A new player
## could never find any of it. This menu lists them all, shows each hotkey, and
## opens each one by calling its system's real public API. The per-system hotkeys
## still work; this is the front door.
##
## Open: backtick (`) toggles it, and the Pause menu has a "Menu" row that opens
## it too (main.gd wires that). Keyboard: Up/Down move, Enter opens the row (menu
## closes, panel opens), Esc/backtick closes. Mouse: hover focuses, click opens.
##
## Layer 29 — just under the pause menu (30) so Esc/pause still wins, but above
## every feature panel (11-13) so it draws over the world cleanly. It does NOT
## pause the tree (the panels it opens manage their own pausing).

signal opened
signal closed

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(0.96, 0.8, 0.45)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.60, 0.55, 0.46)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.98)
const ROW_BG := Color(0.12, 0.095, 0.075, 0.9)
const ROW_BG_FOCUS := Color(0.17, 0.13, 0.09, 0.96)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)

const VIEW := Vector2(640.0, 360.0)
const PANEL_SIZE := Vector2(300.0, 336.0)
const COL_W := 268.0
const ROW_H := 15.0
const ROW_STEP := 15.0
const ROWS_TOP := 34.0
const MENU_LAYER := 29
const TOGGLE_KEY := KEY_QUOTELEFT  # the backtick `

## Every feature, in menu order. Each entry:
##   label   — display name
##   key     — hotkey hint shown at the row's right (informational)
##   action  — id routed by _open_action()
const ENTRIES: Array[Dictionary] = [
	{"label": "Character", "key": "C", "action": "character"},
	{"label": "Inventory / Bags", "key": "I", "action": "inventory"},
	{"label": "Spellbook & Talents", "key": "P", "action": "spellbook"},
	{"label": "Quest Log", "key": "L", "action": "quests"},
	{"label": "Map", "key": "M", "action": "map"},
	{"label": "Reputation", "key": "O", "action": "reputation"},
	{"label": "Achievements", "key": "Y", "action": "achievements"},
	{"label": "Titles", "key": "T", "action": "titles"},
	{"label": "Mounts (Stable)", "key": "Shift+H", "action": "mounts"},
	{"label": "Socketing / Runewords", "key": "U", "action": "socketing"},
	{"label": "Legendary Codex", "key": "]", "action": "legendary"},
	{"label": "Bestiary", "key": "B", "action": "bestiary"},
	{"label": "Calendar", "key": "N", "action": "calendar"},
	{"label": "Chronicle (Journal)", "key": ";", "action": "chronicle"},
	{"label": "Auction House", "key": "V", "action": "auction"},
	{"label": "Bank", "key": "X", "action": "bank"},
	{"label": "PvP — Arena & Accord", "key": "'", "action": "pvp"},
	{"label": "Options / Settings", "key": "F10", "action": "options"},
]

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")

var _root: Control
var _panel: Panel
var _rows: Array[Dictionary] = []   # {root:Panel, style:StyleBoxFlat, label:Label, action:String}
var _focus: int = 0
var _hint: Label


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_menu")
	_build_ui()
	_root.visible = false
	# QA: RH_GAMEMENU=1 force-opens the hub for the RH_SHOT harness.
	# RH_GAMEMENU=<action> instead routes that action (proves the open path end-to-end).
	var gm_env: String = OS.get_environment("RH_GAMEMENU")
	if not gm_env.is_empty():
		if gm_env == "1" or gm_env.to_lower() == "open":
			call_deferred("open")
		else:
			call_deferred("_open_action", gm_env)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
			get_viewport().set_input_as_handled()
			toggle()
			return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif _nav(event, "ui_up", "move_up"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + _rows.size() - 1) % _rows.size())
	elif _nav(event, "ui_down", "move_down"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + 1) % _rows.size())
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate(_focus)


func _nav(event: InputEvent, ui_action: String, move_action: String) -> bool:
	if event.is_action_pressed(ui_action):
		return true
	return InputMap.has_action(move_action) and event.is_action_pressed(move_action)


# ---------------------------------------------------------------- open/close

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	# Never open over a modal that owns Esc (dialogue) or over the pause menu.
	if _blocking_panel_open():
		return
	is_open = true
	_focus = 0
	_apply_focus()
	_root.visible = true
	_root.modulate = Color(1, 1, 1, 0)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.95, 0.95)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.1)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	_root.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	closed.emit()


func _blocking_panel_open() -> bool:
	for grp: String in ["dialogue_ui", "pause_menu", "options_menu"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# ---------------------------------------------------------------- routing

func _activate(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var action: String = str(_rows[index].action)
	close()
	# Defer one frame so this menu is fully hidden before the target panel's own
	# input gating evaluates (several panels refuse to open while another is up).
	call_deferred("_open_action", action)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


## Route a menu action to the real open API of its owning system. Every call is
## guarded — a missing autoload or panel is a silent no-op (never a crash).
func _open_action(action: String) -> void:
	var pl: Node = _player()
	match action:
		"character":
			_open_group("sheet_ui")
		"inventory":
			_open_group("bag_ui")
		"spellbook":
			_open_group("spellbook_ui")
		"quests":
			_call_sys("/root/QuestSystem", "open_log", [pl])
		"map":
			_call_sys("/root/MapSystem", "open", [])
		"reputation":
			_call_sys("/root/FactionSystem", "open_reputation", [pl])
		"achievements":
			_call_sys("/root/AchievementSystem", "open_panel", [pl])
		"titles":
			_call_sys("/root/TitleSystem", "open_picker", [pl])
		"mounts":
			_call_sys("/root/MountSystem", "open_stable", [pl])
		"socketing":
			_call_sys("/root/RunewordSystem", "open_socketing", [pl])
		"legendary":
			_call_sys("/root/LegendarySystem", "open_codex", [pl])
		"bestiary":
			_call_sys("/root/BestiarySystem", "open_codex", [])
		"calendar":
			_call_sys("/root/CalendarSystem", "open_calendar", [pl])
		"chronicle":
			_call_sys("/root/NarrativeSystem", "open_journal", [])
		"auction":
			_call_sys("/root/AuctionSystem", "open_auction", [pl])
		"bank":
			_call_sys("/root/AuctionSystem", "open_bank", [pl])
		"pvp":
			_call_sys("/root/PvPSystem", "open_panel", [pl])
		"options":
			_call_sys("/root/OptionsSystem", "open", [])


## Open a _spawn_ui panel (bag/sheet/spellbook) via its group, tolerant of the
## method name it exposes.
func _open_group(group: String) -> void:
	var node: Node = get_tree().get_first_node_in_group(group)
	if node == null:
		push_warning("game_menu.gd: no node in group '%s'." % group)
		return
	for method: String in ["open", "force_open", "toggle"]:
		if node.has_method(method):
			node.call(method)
			return


## Call `method` on the autoload at `path` with `args`, dropping trailing null
## args the method may not accept. Guarded against a missing autoload/method.
func _call_sys(path: String, method: String, args: Array) -> void:
	var sys: Node = get_node_or_null(path)
	if sys == null:
		push_warning("game_menu.gd: autoload '%s' absent." % path)
		return
	if not sys.has_method(method):
		push_warning("game_menu.gd: %s has no %s()." % [path, method])
		return
	match args.size():
		0: sys.call(method)
		1: sys.call(method, args[0])
		_: sys.callv(method, args)


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_scrim_input)
	_root.add_child(dim)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 6
	_panel = Panel.new()
	_panel.name = "MenuPanel"
	_panel.position = (VIEW - PANEL_SIZE) * 0.5
	_panel.size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var title := Label.new()
	title.text = "Menu"
	_style_label(title, 16, GOLD)
	title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 8.0)
	title.size = Vector2(PANEL_SIZE.x, 20.0)
	_panel.add_child(title)

	for i in range(ENTRIES.size()):
		_add_row(i, ENTRIES[i])

	_hint = Label.new()
	_style_label(_hint, 8, DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(8.0, PANEL_SIZE.y - 18.0)
	_hint.size = Vector2(PANEL_SIZE.x - 16.0, 12.0)
	_hint.text = "Enter open   Esc close   ` toggles this menu"
	_panel.add_child(_hint)

	_apply_focus()


func _add_row(index: int, entry: Dictionary) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)

	var panel := Panel.new()
	panel.name = "Row_%d" % index
	panel.position = Vector2((PANEL_SIZE.x - COL_W) * 0.5, ROWS_TOP + float(index) * ROW_STEP)
	panel.size = Vector2(COL_W, ROW_H)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(_on_row_hover.bind(index))
	panel.gui_input.connect(_on_row_input.bind(index))
	_panel.add_child(panel)

	var label := Label.new()
	label.text = str(entry.label)
	_style_label(label, 11, PARCHMENT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(8.0, 0.0)
	label.size = Vector2(COL_W - 60.0, ROW_H)
	panel.add_child(label)

	var keyl := Label.new()
	keyl.text = str(entry.key)
	_style_label(keyl, 9, GOLD)
	keyl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keyl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyl.position = Vector2(COL_W - 58.0, 0.0)
	keyl.size = Vector2(50.0, ROW_H)
	panel.add_child(keyl)

	_rows.append({"root": panel, "style": style, "label": label, "action": str(entry.action)})


# ---------------------------------------------------------------- focus / mouse

func _on_row_hover(index: int) -> void:
	if is_open:
		_set_focus(index)


func _on_row_input(event: InputEvent, index: int) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_set_focus(index)
			_activate(index)


func _on_scrim_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func _set_focus(index: int) -> void:
	if index == _focus or index < 0 or index >= _rows.size():
		return
	_focus = index
	_apply_focus()


func _apply_focus() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var focused: bool = i == _focus
		var style: StyleBoxFlat = row.style
		style.border_color = GOLD if focused else PANEL_BORDER
		style.bg_color = ROW_BG_FOCUS if focused else ROW_BG
		(row.label as Label).add_theme_color_override(
			"font_color", GOLD_BRIGHT if focused else PARCHMENT)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
