extends CanvasLayer
## CalendarUI -- the month-view calendar for Raven Hollow (design/CALENDAR_EVENTS.md,
## BACKLOG #28). Instanced by the CalendarSystem autoload (scenes/ui/calendar.tscn).
## Left: a 6x5 month grid with festival days tinted their event color and today
## ringed gold, plus < > month navigation. Right: HAPPENING NOW (active festivals)
## and UPCOMING (soonest-first). Styled to the shared gold-bezel kit (panel_brown
## 9-patch + Alagard + GOLD) like mounts_ui / bag_ui. Esc or the X closes.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const CELL_BG := Color(0.055, 0.045, 0.035, 0.95)
const CELL_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.45)

const PANEL_W: float = 476.0
const PANEL_H: float = 348.0
const PAD: float = 12.0
const GRID_COLS: int = 6

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _cs: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _panel: Control
var _title: Label
var _grid_host: Control
var _side: VBoxContainer
var _view_month: int = 1
var _view_year: int = 1


func _ready() -> void:
	layer = 12
	add_to_group("calendar_ui")
	_build()
	_hide()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	var frame := NinePatchRect.new()
	frame.texture = _panel_tex
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	frame.size = Vector2(PANEL_W, PANEL_H)
	frame.position = Vector2(-PANEL_W * 0.5, -PANEL_H * 0.5)
	_scrim.add_child(frame)
	_panel = frame

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	_title = _mk_label("THE DRACONIAN YEAR", 16, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	frame.add_child(_title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	# month navigation row
	var prev_btn := _mk_button("<")
	prev_btn.position = Vector2(PAD, 32.0)
	prev_btn.size = Vector2(24.0, 18.0)
	prev_btn.pressed.connect(func() -> void: _step_month(-1))
	frame.add_child(prev_btn)

	var next_btn := _mk_button(">")
	next_btn.position = Vector2(PAD + 268.0, 32.0)
	next_btn.size = Vector2(24.0, 18.0)
	next_btn.pressed.connect(func() -> void: _step_month(1))
	frame.add_child(next_btn)

	_grid_host = Control.new()
	_grid_host.position = Vector2(PAD, 54.0)
	_grid_host.size = Vector2(294.0, PANEL_H - 66.0)
	frame.add_child(_grid_host)

	var side_scroll := ScrollContainer.new()
	side_scroll.position = Vector2(PAD + 300.0, 32.0)
	side_scroll.size = Vector2(PANEL_W - PAD * 2.0 - 300.0, PANEL_H - 44.0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(side_scroll)

	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 4)
	_side.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 316.0, 0.0)
	side_scroll.add_child(_side)


func present(cs: Node, actor: Node) -> void:
	_cs = cs
	_actor = actor
	var date: Dictionary = _cs.call("get_date")
	_view_month = int(date.get("month", 1))
	_view_year = int(date.get("year", 1))
	_refresh()
	_show()


func _step_month(dir: int) -> void:
	if _cs == null:
		return
	var n: int = int(_cs.call("months").size())
	_view_month += dir
	if _view_month < 1:
		_view_month = n
		_view_year -= 1
	elif _view_month > n:
		_view_month = 1
		_view_year += 1
	_refresh()


func _refresh() -> void:
	if _cs == null:
		return
	var date: Dictionary = _cs.call("get_date")
	var today_m: int = int(date.get("month", 1))
	var today_d: int = int(date.get("day", 1))
	var today_y: int = int(date.get("year", 1))
	var season: String = str(_cs.call("season_of", _view_month))
	_title.text = "%s   Year %d   (%s)" % [
		str(_cs.call("month_name", _view_month)), _view_year, season.capitalize()]

	for c: Node in _grid_host.get_children():
		c.queue_free()
	var dpm: int = int(_cs.call("days_per_month"))
	var cell_w: float = 47.0
	var cell_h: float = 44.0
	var gap: float = 2.0
	for d in range(1, dpm + 1):
		var idx: int = d - 1
		var cx: float = float(idx % GRID_COLS) * (cell_w + gap)
		var cy: float = float(idx / GRID_COLS) * (cell_h + gap)
		var evs: Array = _cs.call("events_on", _view_month, d)
		var is_today: bool = (_view_month == today_m and d == today_d and _view_year == today_y)
		_grid_host.add_child(_make_cell(d, evs, is_today, Vector2(cx, cy), Vector2(cell_w, cell_h)))

	# --- side panel: happening now + upcoming ---
	for c: Node in _side.get_children():
		c.queue_free()
	_add_side_header("HAPPENING NOW")
	var active: Array = _cs.call("active_events")
	if active.is_empty():
		_add_side_note("No festival today. A quiet stretch.")
	for ev_v: Variant in active:
		_add_event_row(_dict(ev_v), true, 0)

	_add_side_header("UPCOMING")
	var up: Array = _cs.call("upcoming_events", 8)
	for row_v: Variant in up:
		var row: Dictionary = _dict(row_v)
		var ev: Dictionary = _dict(row.get("event", {}))
		var du: int = int(row.get("days_until", 0))
		if du <= 0:
			continue
		_add_event_row(ev, false, du)


func _make_cell(day: int, evs: Array, is_today: bool, pos: Vector2, sz: Vector2) -> Control:
	var cell := Control.new()
	cell.position = pos
	cell.custom_minimum_size = sz
	cell.size = sz
	var col := CELL_BG
	var ev_color := Color(0, 0, 0, 0)
	if not evs.is_empty():
		ev_color = _hex(str(_dict(evs[0]).get("color", "#e6c86e")), GOLD)
		col = Color(ev_color.r * 0.5, ev_color.g * 0.5, ev_color.b * 0.5, 0.92)
	var bg := ColorRect.new()
	bg.color = col
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(bg)
	# festival color strip at bottom
	if not evs.is_empty():
		var strip := ColorRect.new()
		strip.color = ev_color
		strip.position = Vector2(0.0, sz.y - 4.0)
		strip.size = Vector2(sz.x, 4.0)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(strip)
	# today ring
	var border := ReferenceRect.new()
	border.editor_only = false
	border.border_color = GOLD if is_today else CELL_BORDER
	border.border_width = 3.0 if is_today else 1.0
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(border)
	var num := _mk_label(str(day), 11, GOLD if is_today else PARCHMENT)
	num.position = Vector2(3.0, 1.0)
	cell.add_child(num)
	if not evs.is_empty():
		var tag := _mk_label(_abbrev(str(_dict(evs[0]).get("name", ""))), 7, Color(0.95, 0.92, 0.82))
		tag.position = Vector2(3.0, 15.0)
		tag.size = Vector2(sz.x - 5.0, 24.0)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(tag)
	# tooltip
	if not evs.is_empty():
		var names: Array = []
		for e_v: Variant in evs:
			names.append(str(_dict(e_v).get("name", "")))
		cell.tooltip_text = ", ".join(names)
	return cell


func _add_event_row(ev: Dictionary, active: bool, days_until: int) -> void:
	var color := _hex(str(ev.get("color", "#e6c86e")), GOLD)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(_side.custom_minimum_size.x, 0.0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	box.add_child(vb)
	var name_lbl := _mk_label(str(ev.get("name", "")), 11, color)
	vb.add_child(name_lbl)
	var sub: String = ""
	if active:
		sub = "Now  -  ends %s" % _end_text(ev)
	else:
		sub = "In %d day%s  -  %s" % [days_until, "" if days_until == 1 else "s", str(_cs.call("event_window_text", ev))]
	var sub_lbl := _mk_label(sub, 8, DIM)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.custom_minimum_size = Vector2(_side.custom_minimum_size.x - 16.0, 0.0)
	vb.add_child(sub_lbl)
	_side.add_child(box)


func _end_text(ev: Dictionary) -> String:
	var w: Dictionary = _dict(ev.get("window", {}))
	if w.is_empty():
		return "week's end"
	return "%s %d" % [str(_cs.call("month_name", int(w.get("end_month", 1)))), int(w.get("end_day", 1))]


# --- little builders --------------------------------------------------------

func _add_side_header(text: String) -> void:
	var l := _mk_label(text, 11, GOLD)
	l.custom_minimum_size = Vector2(_side.custom_minimum_size.x, 16.0)
	_side.add_child(l)


func _add_side_note(text: String) -> void:
	var l := _mk_label(text, 8, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_side.custom_minimum_size.x, 20.0)
	_side.add_child(l)


func _abbrev(name: String) -> String:
	var s := name.replace("The ", "").replace("the ", "")
	return s


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mk_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_color_disabled", DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CELL_BG
	sb.border_color = CELL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	return b


func _hex(s: String, dflt: Color) -> Color:
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return dflt


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func close() -> void:
	_hide()


func _show() -> void:
	is_open = true
	visible = true
	if _scrim != null:
		_scrim.visible = true


func _hide() -> void:
	is_open = false
	visible = false
	if _scrim != null:
		_scrim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
