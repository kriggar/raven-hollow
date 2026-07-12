extends CanvasLayer
## OptionsMenu — the gold-bezel tabbed settings panel for Raven Hollow.
## Spawned by the OptionsSystem autoload; edits it live (apply-on-change).
## Tabs: Video / Audio / Gameplay / Controls. Fully code-built in the shared
## pause-menu kit (dark-wood panel + Alagard + gold accents + panel_brown rim).
##
## Toggle: F10 (or OptionsSystem.open()). Keyboard: Up/Down rows, Left/Right
## adjust, Enter activate/rebind, Q/E or Tab switch tab, Esc closes. Mouse:
## hover focuses, click cycles (right-click reverses), sliders drag, tabs click.
##
## QA: RH_OPTIONS=<tab> force-opens on that tab for the RH_SHOT harness
## (RH_OPTIONS=1 -> Video). Pauses the tree while open (restores prior state
## on close, so it stacks cleanly over the pause menu).

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(0.96, 0.8, 0.45)
const GOLD_DIM := Color(0.62, 0.48, 0.26)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.62, 0.57, 0.48)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.98)
const ROW_BG := Color(0.12, 0.095, 0.075, 0.9)
const ROW_BG_FOCUS := Color(0.17, 0.13, 0.09, 0.96)
const PANEL_BORDER := Color(0.58, 0.44, 0.22)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const TRACK_BG := Color(0.05, 0.04, 0.035)

const VIEW := Vector2(640.0, 360.0)
const PANEL_SIZE := Vector2(474.0, 300.0)
const MENU_LAYER := 31  # above pause/main menus (30)
const ROW_X := 20.0
const ROW_W := 434.0
const ROW_H := 22.0
const ROW_STEP := 25.0
const ROWS_TOP := 62.0

const TABS := ["video", "audio", "gameplay", "controls"]
const TAB_LABELS := {"video": "Video", "audio": "Audio", "gameplay": "Gameplay", "controls": "Controls"}

## Per-tab row schema (values live in OptionsSystem). type: cycle|slider|keybind.
const SCHEMA := {
	"video": [
		{"key": "window_mode", "label": "Window Mode", "type": "cycle",
			"opts": [["windowed", "Windowed"], ["borderless", "Borderless"], ["fullscreen", "Fullscreen"]],
			"hint": "Borderless is the friendly fullscreen; Fullscreen grabs the display."},
		{"key": "resolution", "label": "Window Size", "type": "cycle",
			"opts": [["1280x720", "1280 x 720"], ["1600x900", "1600 x 900"],
				["1920x1080", "1920 x 1080"], ["2560x1440", "2560 x 1440"]],
			"hint": "Windowed size (integer scale of the 640x360 canvas)."},
		{"key": "vsync", "label": "VSync", "type": "cycle",
			"opts": [["on", "On"], ["adaptive", "Adaptive"], ["off", "Off"]],
			"hint": "On removes tearing; Off lowers latency; Adaptive is best for VRR."},
		{"key": "pixel_scale", "label": "Pixel Scaling", "type": "cycle",
			"opts": [["integer", "Integer (crisp)"], ["fractional", "Fractional (fills)"]],
			"hint": "Integer is pixel-perfect; Fractional fills the screen (mild shimmer)."},
	],
	"audio": [
		{"key": "master", "label": "Master Volume", "type": "slider",
			"hint": "Overall loudness (drives the Master audio bus)."},
		{"key": "music", "label": "Music", "type": "slider", "hint": "The zone + menu themes."},
		{"key": "sfx", "label": "Effects", "type": "slider", "hint": "Combat and UI one-shots."},
		{"key": "ambience", "label": "Ambience", "type": "slider", "hint": "Zone soundscape beds."},
	],
	"gameplay": [
		{"key": "difficulty", "label": "Difficulty", "type": "cycle",
			"opts": [["story", "Story"], ["normal", "Normal"], ["hard", "Hard"]],
			"hint": "Combat challenge (read by the systems that support it)."},
		{"key": "tooltips", "label": "Tooltip Detail", "type": "cycle",
			"opts": [["full", "Full"], ["compact", "Compact"]],
			"hint": "Full shows flavour + set lines; Compact trims to stats."},
		{"key": "camera_smoothing", "label": "Camera Smoothing", "type": "cycle",
			"opts": [["off", "Off"], ["low", "Low"], ["standard", "Standard"], ["high", "High"]],
			"hint": "How softly the camera follows (Off locks to whole pixels)."},
	],
}

const SLIDER_STEP := 0.05

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _root: Control
var _panel: Panel
var _tab_host: Control
var _rows_host: Control
var _hint: Label
var _title: Label

var _tab: int = 0
var _tab_nodes: Array = []      # per-tab {root:Panel, style, label}
var _rows: Array = []           # per-row dicts
var _focus: int = 0
var _was_paused: bool = false

var _capturing: bool = false
var _capture_action: String = ""


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("options_menu")
	_build_shell()
	_root.visible = false
	var env: String = OS.get_environment("RH_OPTIONS")
	if not env.is_empty():
		_tab = maxi(0, TABS.find(env.to_lower()))
		call_deferred("_qa_open")


func _qa_open() -> void:
	# QA screenshot path: open WITHOUT pausing the tree (pausing mid-boot could
	# stall main.gd's timer-driven boot sequence before the capture frame).
	open_menu(_tab, false)


# ---------------------------------------------------------------- open/close

func open_menu(tab: int = 0, do_pause: bool = true) -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	if do_pause:
		get_tree().paused = true
	_tab = clampi(tab, 0, TABS.size() - 1)
	_focus = 0
	_refresh_tab_styles()
	_rebuild()
	_root.visible = true
	_root.modulate = Color(1, 1, 1, 0)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.12)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	_capturing = false
	_capture_action = ""
	_root.visible = false
	get_tree().paused = _was_paused

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu(_tab)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# F10 toggles from anywhere.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_F10:
		toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	# Rebind capture swallows the next key.
	if _capturing:
		if event is InputEventKey and event.pressed and not event.echo:
			var k := event as InputEventKey
			get_viewport().set_input_as_handled()
			if k.physical_keycode == KEY_ESCAPE:
				_end_capture(false)
			else:
				var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				OptionsSystem.rebind_action(_capture_action, code)
				_end_capture(true)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
		return
	# tab switching: Tab / Q / E
	if event is InputEventKey and event.pressed and not event.echo:
		var pk: int = (event as InputEventKey).physical_keycode
		if pk == KEY_TAB or pk == KEY_E:
			get_viewport().set_input_as_handled()
			_set_tab((_tab + 1) % TABS.size())
			return
		if pk == KEY_Q:
			get_viewport().set_input_as_handled()
			_set_tab((_tab + TABS.size() - 1) % TABS.size())
			return
	if _rows.is_empty():
		return
	if _nav(event, "ui_up", "move_up"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + _rows.size() - 1) % _rows.size())
	elif _nav(event, "ui_down", "move_down"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + 1) % _rows.size())
	elif _nav(event, "ui_left", "move_left"):
		get_viewport().set_input_as_handled()
		_adjust(-1)
	elif _nav(event, "ui_right", "move_right"):
		get_viewport().set_input_as_handled()
		_adjust(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate()

func _nav(event: InputEvent, ui: String, move: String) -> bool:
	if event.is_action_pressed(ui):
		return true
	return InputMap.has_action(move) and event.is_action_pressed(move)


# ---------------------------------------------------------------- build shell

func _build_shell() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.position = ((VIEW - PANEL_SIZE) * 0.5).floor()
	_panel.size = PANEL_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 7
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	_title = _label(_panel, 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = "Settings"
	_title.position = Vector2(0, 7)
	_title.size = Vector2(PANEL_SIZE.x, 20)

	_tab_host = Control.new()
	_tab_host.name = "Tabs"
	_tab_host.position = Vector2(ROW_X, 34)
	_tab_host.size = Vector2(ROW_W, 18)
	_panel.add_child(_tab_host)
	_build_tabs()

	# divider under the tabs
	var div := ColorRect.new()
	div.color = PANEL_BORDER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.position = Vector2(ROW_X, 56)
	div.size = Vector2(ROW_W, 1)
	_panel.add_child(div)

	_rows_host = Control.new()
	_rows_host.name = "Rows"
	_rows_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows_host)

	# footer hint band
	var fdiv := ColorRect.new()
	fdiv.color = PANEL_BORDER
	fdiv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fdiv.position = Vector2(ROW_X, PANEL_SIZE.y - 40)
	fdiv.size = Vector2(ROW_W, 1)
	_panel.add_child(fdiv)

	_hint = _label(_panel, 9, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(ROW_X, PANEL_SIZE.y - 36)
	_hint.size = Vector2(ROW_W, 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF

	var nav := _label(_panel, 9, GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	nav.text = "Up/Down select   Left/Right change   Q/E tabs   Enter rebind   Esc close"
	nav.position = Vector2(ROW_X, PANEL_SIZE.y - 22)
	nav.size = Vector2(ROW_W, 12)

	var rim := NinePatchRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture = _panel_tex
	rim.draw_center = false
	rim.patch_margin_left = 10
	rim.patch_margin_right = 10
	rim.patch_margin_top = 10
	rim.patch_margin_bottom = 10
	rim.modulate = FRAME_TINT
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(rim)


func _build_tabs() -> void:
	_tab_nodes.clear()
	var tw: float = ROW_W / float(TABS.size())
	for i in range(TABS.size()):
		var t: String = TABS[i]
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.position = Vector2(float(i) * tw, 0)
		p.size = Vector2(tw - 4.0, 18)
		var st := StyleBoxFlat.new()
		st.bg_color = ROW_BG
		st.border_color = PANEL_BORDER
		st.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", st)
		var l := _label(p, 11, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
		l.text = str(TAB_LABELS[t])
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.gui_input.connect(_on_tab_input.bind(i))
		_tab_host.add_child(p)
		_tab_nodes.append({"root": p, "style": st, "label": l})
	_refresh_tab_styles()


func _on_tab_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_set_tab(i)


func _refresh_tab_styles() -> void:
	for i in range(_tab_nodes.size()):
		var d: Dictionary = _tab_nodes[i]
		var on: bool = i == _tab
		(d.style as StyleBoxFlat).border_color = GOLD if on else PANEL_BORDER
		(d.style as StyleBoxFlat).bg_color = ROW_BG_FOCUS if on else ROW_BG
		(d.label as Label).add_theme_color_override("font_color", GOLD_BRIGHT if on else PARCHMENT)


func _set_tab(i: int) -> void:
	if i == _tab:
		return
	_tab = i
	_focus = 0
	_refresh_tab_styles()
	_rebuild()


# ---------------------------------------------------------------- rows

func _rebuild() -> void:
	for c: Node in _rows_host.get_children():
		c.queue_free()
	_rows.clear()
	var tab: String = TABS[_tab]
	if tab == "controls":
		_build_controls_rows()
	else:
		_build_setting_rows(tab)
	_apply_focus()
	_update_hint()


func _build_setting_rows(tab: String) -> void:
	var y: float = ROWS_TOP
	for spec_v: Variant in SCHEMA.get(tab, []):
		var spec: Dictionary = spec_v
		var row: Dictionary = _make_row(y, str(spec.get("label", "")))
		row["type"] = str(spec.get("type", "cycle"))
		row["section"] = tab
		row["key"] = str(spec.get("key", ""))
		row["hint"] = str(spec.get("hint", ""))
		row["opts"] = spec.get("opts", [])
		if row.type == "slider":
			_add_slider_widget(row)
		else:
			_add_cycle_widget(row)
		_rows.append(row)
		y += ROW_STEP
	_refresh_all_rows()


func _build_controls_rows() -> void:
	# Two columns so all 19 actions fit above the footer.
	var actions: Array = OptionsSystem.REBINDABLE
	var per_col: int = int(ceil(actions.size() / 2.0))
	var col_w: float = (ROW_W - 10.0) * 0.5
	var kb_h: float = 17.0
	var kb_step: float = 19.0
	var top: float = 60.0
	for i in range(actions.size()):
		var action: String = str(actions[i])
		var lbl: String = str(OptionsSystem.ACTION_LABELS.get(action, action.capitalize()))
		var col: int = 0 if i < per_col else 1
		var rowi: int = i if i < per_col else i - per_col
		var x: float = ROW_X + float(col) * (col_w + 10.0)
		var y: float = top + float(rowi) * kb_step
		var row: Dictionary = _make_kb_row(x, y, col_w, kb_h, lbl)
		row["type"] = "keybind"
		row["section"] = "controls"
		row["key"] = action
		row["hint"] = "Enter to rebind   Backspace resets this key"
		_rows.append(row)
	_refresh_all_rows()


func _make_kb_row(x: float, y: float, w: float, h: float, label_text: String) -> Dictionary:
	var idx: int = _rows.size()
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	var st := StyleBoxFlat.new()
	st.bg_color = ROW_BG
	st.border_color = PANEL_BORDER
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	p.gui_input.connect(_on_row_input.bind(idx))
	p.mouse_entered.connect(_on_row_hover.bind(idx))
	_rows_host.add_child(p)
	var name_lbl := _label(p, 10, PARCHMENT, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.text = label_text
	name_lbl.position = Vector2(8, 0)
	name_lbl.size = Vector2(w - 78.0, h)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var val := _label(p, 10, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.position = Vector2(w - 72.0, 0)
	val.size = Vector2(64.0, h)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {"root": p, "style": st, "name_label": name_lbl, "value_label": val, "fill": null}


func _make_row(y: float, label_text: String, h: float = ROW_H) -> Dictionary:
	var idx: int = _rows.size()
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.position = Vector2(ROW_X, y)
	p.size = Vector2(ROW_W, h)
	var st := StyleBoxFlat.new()
	st.bg_color = ROW_BG
	st.border_color = PANEL_BORDER
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	p.gui_input.connect(_on_row_input.bind(idx))
	p.mouse_entered.connect(_on_row_hover.bind(idx))
	_rows_host.add_child(p)
	var name_lbl := _label(p, 11, PARCHMENT, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.text = label_text
	name_lbl.position = Vector2(10, 0)
	name_lbl.size = Vector2(180, h)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return {"root": p, "style": st, "name_label": name_lbl, "value_label": null, "fill": null}


func _add_cycle_widget(row: Dictionary) -> void:
	var h: float = (row.root as Panel).size.y
	var lt := _label(row.root, 12, GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	lt.text = "<"
	lt.position = Vector2(ROW_W - 178.0, 0)
	lt.size = Vector2(14, h)
	lt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var val := _label(row.root, 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	val.position = Vector2(ROW_W - 164.0, 0)
	val.size = Vector2(140.0, h)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var rt := _label(row.root, 12, GOLD_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	rt.text = ">"
	rt.position = Vector2(ROW_W - 24.0, 0)
	rt.size = Vector2(14, h)
	rt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row["value_label"] = val


func _add_slider_widget(row: Dictionary) -> void:
	var h: float = (row.root as Panel).size.y
	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_STOP
	track.position = Vector2(ROW_W - 172.0, (h - 10.0) * 0.5)
	track.size = Vector2(120.0, 10.0)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = TRACK_BG
	tsb.border_color = PANEL_BORDER
	tsb.set_border_width_all(2)
	track.add_theme_stylebox_override("panel", tsb)
	track.gui_input.connect(_on_track_input.bind(_rows.size()))
	row.root.add_child(track)
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = GOLD_DIM
	fill.position = Vector2(1, 1)
	fill.size = Vector2(0, 8)
	track.add_child(fill)
	var val := _label(row.root, 11, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	val.position = Vector2(ROW_W - 46.0, 0)
	val.size = Vector2(34.0, h)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row["value_label"] = val
	row["fill"] = fill
	row["track"] = track


func _refresh_all_rows() -> void:
	for i in range(_rows.size()):
		_refresh_row(i)


func _refresh_row(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	var row: Dictionary = _rows[i]
	match str(row.type):
		"cycle":
			var cur: Variant = OptionsSystem.get_setting(str(row.section), str(row.key))
			(row.value_label as Label).text = _opt_label(row.opts, cur)
		"slider":
			var v: float = float(OptionsSystem.get_setting(str(row.section), str(row.key)))
			(row.value_label as Label).text = "%d%%" % int(round(v * 100.0))
			var track: Panel = row.track
			var fill: ColorRect = row.fill
			fill.size = Vector2(maxf(0.0, (track.size.x - 2.0) * v), 8.0)
		"keybind":
			(row.value_label as Label).text = OptionsSystem.action_display(str(row.key))


func _opt_label(opts: Array, value: Variant) -> String:
	for o_v: Variant in opts:
		var o: Array = o_v
		if o.size() >= 2 and o[0] == value:
			return str(o[1])
	return str(value)


# ---------------------------------------------------------------- interaction

func _adjust(dir: int) -> void:
	if _focus < 0 or _focus >= _rows.size():
		return
	var row: Dictionary = _rows[_focus]
	match str(row.type):
		"cycle":
			_cycle(_focus, dir)
		"slider":
			var v: float = float(OptionsSystem.get_setting(str(row.section), str(row.key)))
			v = clampf(snappedf(v + SLIDER_STEP * float(dir), SLIDER_STEP), 0.0, 1.0)
			OptionsSystem.set_setting(str(row.section), str(row.key), v)
			_refresh_row(_focus)

func _activate() -> void:
	if _focus < 0 or _focus >= _rows.size():
		return
	var row: Dictionary = _rows[_focus]
	match str(row.type):
		"cycle":
			_cycle(_focus, 1)
		"keybind":
			_begin_capture(str(row.key))
		"slider":
			pass

func _cycle(i: int, dir: int) -> void:
	var row: Dictionary = _rows[i]
	var opts: Array = row.opts
	if opts.is_empty():
		return
	var cur: Variant = OptionsSystem.get_setting(str(row.section), str(row.key))
	var at: int = 0
	for j in range(opts.size()):
		if (opts[j] as Array)[0] == cur:
			at = j
			break
	at = (at + dir + opts.size()) % opts.size()
	OptionsSystem.set_setting(str(row.section), str(row.key), (opts[at] as Array)[0])
	_refresh_row(i)


func _on_row_input(event: InputEvent, i: int) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		_set_focus(i)
		var row: Dictionary = _rows[i]
		if str(row.type) == "cycle":
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_cycle(i, 1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_cycle(i, -1)
		elif str(row.type) == "keybind" and mb.button_index == MOUSE_BUTTON_LEFT:
			_begin_capture(str(row.key))
	if event is InputEventKey and event.pressed and is_open and _focus == i \
			and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		var row2: Dictionary = _rows[i]
		if str(row2.type) == "keybind":
			OptionsSystem.reset_keybind(str(row2.key))
			_refresh_row(i)


func _on_track_input(event: InputEvent, i: int) -> void:
	if not is_open or i < 0 or i >= _rows.size():
		return
	var row: Dictionary = _rows[i]
	if str(row.type) != "slider":
		return
	var dragging: bool = event is InputEventMouseMotion \
			and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT
	var pressed: bool = event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if pressed or dragging:
		_set_focus(i)
		var track: Panel = row.track
		var local_x: float = (event as InputEventMouse).position.x
		var v: float = clampf(local_x / maxf(1.0, track.size.x), 0.0, 1.0)
		OptionsSystem.set_setting(str(row.section), str(row.key), snappedf(v, SLIDER_STEP))
		_refresh_row(i)


func _on_row_hover(i: int) -> void:
	if is_open:
		_set_focus(i)


func _set_focus(i: int) -> void:
	if i < 0 or i >= _rows.size():
		return
	_focus = i
	_apply_focus()
	_update_hint()


func _apply_focus() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var on: bool = i == _focus
		(row.style as StyleBoxFlat).border_color = GOLD if on else PANEL_BORDER
		(row.style as StyleBoxFlat).bg_color = ROW_BG_FOCUS if on else ROW_BG
		(row.name_label as Label).add_theme_color_override("font_color", GOLD_BRIGHT if on else PARCHMENT)


func _update_hint() -> void:
	if _capturing:
		_hint.text = "Press a key to bind   (Esc cancels)"
		_hint.add_theme_color_override("font_color", GOLD_BRIGHT)
		return
	_hint.add_theme_color_override("font_color", PARCHMENT)
	if _focus >= 0 and _focus < _rows.size():
		_hint.text = str(_rows[_focus].get("hint", ""))
	else:
		_hint.text = ""


# ---------------------------------------------------------------- rebind capture

func _begin_capture(action: String) -> void:
	_capturing = true
	_capture_action = action
	_update_hint()

func _end_capture(_ok: bool) -> void:
	_capturing = false
	_capture_action = ""
	_refresh_all_rows()
	_update_hint()


# ---------------------------------------------------------------- helpers

func _label(parent: Control, fsize: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = align
	l.clip_text = true
	parent.add_child(l)
	return l
