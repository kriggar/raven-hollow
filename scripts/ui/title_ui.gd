extends CanvasLayer
## TitleUI -- the title picker (design/PVP_RANKS_TITLES.md 10.4). Instanced by the
## TitleSystem autoload (scenes/ui/titles.tscn). Shows a live preview of the
## player's name with the active title applied, then the owned titles as
## category-grouped selectable rows ("None" always first). Clicking a row sets it
## active; the active row is lit gold. Tooltip = the title's earn-lore (desc).
## Styled to the shared gold-bezel kit like mounts_ui / pvp_ui. Esc or the X closes.
## present() takes a side ("center"|"left"|"right") for the side-by-side boot shot.

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.98)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const ROW_ACTIVE := Color(0.16, 0.12, 0.05, 0.98)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)

const PANEL_W: float = 300.0
const PANEL_H: float = 330.0
const PAD: float = 12.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _ts: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _panel: Control
var _list: VBoxContainer
var _preview: Label


func _ready() -> void:
	layer = 12
	add_to_group("titles_ui")
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
	frame.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	frame.size = Vector2(PANEL_W, PANEL_H)
	add_child(frame)
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

	var title := _mk_label("TITLES", 15, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(PAD, 8.0)
	title.size = Vector2(PANEL_W - PAD * 2.0, 18.0)
	frame.add_child(title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	# Preview of the name with the active title.
	var pv_bg := ColorRect.new()
	pv_bg.color = SLOT_BG
	pv_bg.position = Vector2(PAD, 30.0)
	pv_bg.size = Vector2(PANEL_W - PAD * 2.0, 24.0)
	frame.add_child(pv_bg)
	_preview = _mk_label("", 13, GOLD_BRIGHT)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	pv_bg.add_child(_preview)

	var hint := _mk_label("Choose the name you fight under.", 8, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(PAD, 56.0)
	hint.size = Vector2(PANEL_W - PAD * 2.0, 11.0)
	frame.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 70.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 70.0 - 12.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 12.0, 0.0)
	scroll.add_child(_list)


func present(ts: Node, actor: Node, side: String = "center") -> void:
	_ts = ts
	_actor = actor
	_place(side)
	_scrim.visible = side == "center"
	_refresh()
	_show()


func _place(side: String) -> void:
	var y: float = (360.0 - PANEL_H) * 0.5
	match side:
		"left":
			_panel.position = Vector2(8.0, y)
		"right":
			_panel.position = Vector2(640.0 - 8.0 - PANEL_W, y)
		_:
			_panel.position = Vector2((640.0 - PANEL_W) * 0.5, y)


func _refresh() -> void:
	if _ts == null or _actor == null:
		return
	_preview.text = str(_ts.call("display_name", _actor, _base_name()))
	for c: Node in _list.get_children():
		c.queue_free()
	var active: String = str(_ts.call("active_title", _actor))

	_add_none_row(active == "")

	var owned: Array = _ts.call("owned_titles", _actor)
	var by_cat: Dictionary = {}
	for id_v: Variant in owned:
		var id: String = str(id_v)
		var cat: String = str(_ts.call("title_def", id).get("cat", "misc"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		(by_cat[cat] as Array).append(id)

	if owned.is_empty():
		_add_note("No titles yet. Climb the Roll, clear a raid, survive a curse.")
		return

	for cat: String in _ts.call("categories"):
		if not by_cat.has(cat):
			continue
		_add_header(str(_ts.call("category_name", cat)))
		for id_v: Variant in by_cat[cat]:
			_add_title_row(str(id_v), active)


func _add_none_row(is_active: bool) -> void:
	var row := _row_container(is_active)
	var lbl := _mk_label("None", 11, GOLD_BRIGHT if is_active else PARCHMENT)
	lbl.position = Vector2(6.0, 3.0)
	lbl.size = Vector2(_row_w() - 12.0, 14.0)
	row.add_child(lbl)
	_wire_row(row, "")
	_list.add_child(row)


func _add_title_row(id: String, active: String) -> void:
	var d: Dictionary = _ts.call("title_def", id)
	var is_active: bool = id == active
	var row := _row_container(is_active)
	row.tooltip_text = str(d.get("desc", ""))
	var pos: String = str(d.get("pos", "suffix"))
	var tag: String = "[pre]" if pos == "prefix" else "[suf]"
	var lbl := _mk_label(str(d.get("name", id)), 11, GOLD_BRIGHT if is_active else PARCHMENT)
	lbl.position = Vector2(6.0, 3.0)
	lbl.size = Vector2(_row_w() - 46.0, 14.0)
	row.add_child(lbl)
	var tag_lbl := _mk_label(tag, 8, GOLD if is_active else DIM)
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag_lbl.position = Vector2(_row_w() - 42.0, 4.0)
	tag_lbl.size = Vector2(36.0, 12.0)
	row.add_child(tag_lbl)
	_wire_row(row, id)
	_list.add_child(row)


func _wire_row(row: Control, id: String) -> void:
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_ts.call("set_active", _actor, id)
			_refresh())


func _row_container(is_active: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(_row_w(), 20.0)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = ROW_ACTIVE if is_active else SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _add_header(text: String) -> void:
	var l := _mk_label(text, 9, GOLD)
	l.custom_minimum_size = Vector2(_row_w(), 14.0)
	_list.add_child(l)


func _add_note(text: String) -> void:
	var l := _mk_label(text, 8, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_row_w(), 24.0)
	_list.add_child(l)


func _row_w() -> float:
	return PANEL_W - PAD * 2.0 - 14.0


func _base_name() -> String:
	for prop: String in ["char_name", "display_name", "player_name"]:
		if _has_prop(_actor, prop):
			var v: Variant = _actor.get(prop)
			if v is String and str(v) != "":
				return str(v)
	var cd: Variant = _actor.get("class_def") if _actor != null else null
	if cd is Dictionary:
		return str((cd as Dictionary).get("name", "Wanderer"))
	return "Wanderer"


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mk_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", GOLD_BRIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func close() -> void:
	_hide()


func _show() -> void:
	is_open = true
	visible = true


func _hide() -> void:
	is_open = false
	visible = false
	if _scrim != null:
		_scrim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
