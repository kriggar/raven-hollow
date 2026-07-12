extends CanvasLayer
## THE MICRO BAR (owner order 2026-07-12) — WoW-style quick-access strip:
## one small UNIQUE-ICON button per game panel, two rows, bottom-right above
## the bag button. Routes mirror game_menu.gd; tooltips on hover; icons from
## assets/art/ui/micro/ (generated, gate-passed, icon law).
##
## Self-contained: main.gd adds MicroBar.new() once; everything else is
## guarded lookups — absent systems just no-op their button.

const VIEW := Vector2(640.0, 360.0)
const BTN := 15.0
const GAP := 1.0
const COLS := 8
const SHIKASHI := "res://assets/art/icons_pixel/shikashi_v2.png"
## FREE-ASSETS LAW: unique icons come from Shikashi's Fantasy Icons (free,
## CC-BY via game-icons.net designs) — 32px atlas cells, one per panel.
const CELLS := {
	"character": Vector2i(3, 7), "spellbook": Vector2i(7, 4),
	"talents": Vector2i(5, 12), "quests": Vector2i(10, 13),
	"map": Vector2i(12, 13), "achievements": Vector2i(7, 12),
	"reputation": Vector2i(2, 6), "mounts": Vector2i(10, 19),
	"titles": Vector2i(5, 8), "pvp": Vector2i(9, 5),
	"calendar": Vector2i(10, 21), "crafting": Vector2i(4, 4),
	"codex": Vector2i(7, 13), "options": Vector2i(10, 11),
	"menu": Vector2i(0, 10),
}
const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const BOX_BG := Color(0.10, 0.08, 0.065, 0.94)
const BORDER := Color(0.42, 0.31, 0.17)
const OUTLINE_DARK := Color(0.07, 0.05, 0.03)

## action id -> [icon name, tooltip]
const BUTTONS := [
	["character", "Character  (C)"],
	["spellbook", "Spellbook  (P)"],
	["talents", "Talents  (N)"],
	["quests", "Quests  (L)"],
	["map", "Map  (M)"],
	["achievements", "Deed-Book  (Y)"],
	["reputation", "Reputation  (K)"],
	["mounts", "Stable  (H)"],
	["titles", "Titles"],
	["pvp", "The Accord Roll"],
	["calendar", "Calendar"],
	["crafting", "Crafting  (O)"],
	["codex", "Legendary Codex"],
	["options", "Options  (F10)"],
	["menu", "Menu  (`)"],
]

var _root: Control
var _tip: Label
var _font: FontFile = preload("res://assets/fonts/alagard.ttf")


func _ready() -> void:
	layer = 8
	add_to_group("micro_bar")
	_root = Control.new()
	_root.name = "MicroBarRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()


func _process(_dt: float) -> void:
	# Follow the HUD's lead: visible only while a player exists.
	var alive: bool = get_tree().get_first_node_in_group("player") != null
	if _root.visible != alive:
		_root.visible = alive


func _build() -> void:
	var n: int = BUTTONS.size()
	var rows: int = int(ceil(float(n) / float(COLS)))
	var bar_w: float = float(COLS) * (BTN + GAP) - GAP
	var origin := Vector2(VIEW.x - 8.0 - bar_w, VIEW.y - 50.0 - float(rows) * (BTN + GAP))

	var back := Panel.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = origin - Vector2(3.0, 3.0)
	back.size = Vector2(bar_w + 6.0, float(rows) * (BTN + GAP) - GAP + 6.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	back.add_theme_stylebox_override("panel", sb)
	_root.add_child(back)

	for i in range(n):
		var action: String = BUTTONS[i][0]
		var tip: String = BUTTONS[i][1]
		var pos := origin + Vector2(float(i % COLS) * (BTN + GAP), float(i / COLS) * (BTN + GAP))

		var cell := Control.new()
		cell.position = pos
		cell.size = Vector2(BTN, BTN)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.tooltip_text = ""  # custom tip label below (engine tips unthemed)
		_root.add_child(cell)

		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0.14, 0.11, 0.085, 0.9)
		fsb.border_color = BORDER
		fsb.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", fsb)
		cell.add_child(frame)

		if CELLS.has(action) and ResourceLoader.exists(SHIKASHI):
			var at := AtlasTexture.new()
			at.atlas = load(SHIKASHI)
			var icell: Vector2i = CELLS[action]
			at.region = Rect2(icell.x * 32, icell.y * 32, 32, 32)
			var icon := TextureRect.new()
			icon.texture = at
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 2
			icon.offset_top = 2
			icon.offset_right = -2
			icon.offset_bottom = -2
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)

		cell.mouse_entered.connect(func() -> void:
			fsb.border_color = GOLD
			_show_tip(tip, pos))
		cell.mouse_exited.connect(func() -> void:
			fsb.border_color = BORDER
			_tip.visible = false)
		cell.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_do_action(action))

	_tip = Label.new()
	_tip.add_theme_font_override("font", _font)
	_tip.add_theme_font_size_override("font_size", 9)
	_tip.add_theme_color_override("font_color", PARCHMENT)
	_tip.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_tip.add_theme_constant_override("outline_size", 3)
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tip)


func _show_tip(text: String, btn_pos: Vector2) -> void:
	_tip.text = text
	_tip.visible = true
	var w: float = _tip.get_theme_font("font").get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_tip.position = Vector2(minf(btn_pos.x, VIEW.x - w - 10.0), btn_pos.y - 14.0)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _do_action(action: String) -> void:
	var pl: Node = _player()
	match action:
		"character":
			_open_group("sheet_ui")
		"spellbook":
			_open_group("spellbook_ui")
		"talents":
			for nd: Node in get_tree().get_nodes_in_group("spellbook_ui"):
				if nd.has_method("open_tab"):
					nd.call("open_tab", "talents")
					return
			_open_group("spellbook_ui")
		"quests":
			_call_sys("/root/QuestSystem", "open_log", [pl])
		"map":
			_call_sys("/root/MapSystem", "open", [])
		"achievements":
			_call_sys("/root/AchievementSystem", "open_panel", [pl])
		"reputation":
			_call_sys("/root/FactionSystem", "open_reputation", [pl])
		"mounts":
			_call_sys("/root/MountSystem", "open_stable", [pl])
		"titles":
			_call_sys("/root/TitleSystem", "open_picker", [pl])
		"pvp":
			_call_sys("/root/PvPSystem", "open_panel", [pl])
		"calendar":
			_call_sys("/root/CalendarSystem", "open_calendar", [pl])
		"crafting":
			_open_group("profession_crafting_ui")
		"codex":
			_call_sys("/root/LegendarySystem", "open_codex", [pl])
		"options":
			_call_sys("/root/OptionsSystem", "open", [])
		"menu":
			for nd: Node in get_tree().get_nodes_in_group("game_menu"):
				if nd.has_method("open_menu"):
					nd.call("open_menu")
					return
			get_tree().call_group("pause_menu", "open_game_menu")


func _call_sys(path: String, method: String, args: Array) -> void:
	var nd: Node = get_node_or_null(path)
	if nd != null and nd.has_method(method):
		nd.callv(method, args)


func _open_group(group: String) -> void:
	var nd: Node = get_tree().get_first_node_in_group(group)
	if nd == null:
		return
	for method: String in ["open", "force_open", "toggle"]:
		if nd.has_method(method):
			nd.call(method)
			return
