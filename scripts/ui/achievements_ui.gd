extends CanvasLayer
## AchievementsUI -- the Deed-Book panel for Raven Hollow (design/ACHIEVEMENTS.md 7.2).
## Instanced by the AchievementSystem autoload (scenes/ui/achievements.tscn), opened
## with the Y hotkey. A left rail of the nine categories (with completion pips), and
## a scrolling list of that category's deeds: name (gold when earned, parchment when
## not), the concrete `desc`, a gold progress bar with an x/y overlay, and a points
## chip. Hidden, unearned rows render as an unwritten-parchment line. The running
## account point total sits in the header. Styled to the shared gold-bezel kit
## (panel_brown 9-patch + Alagard + GOLD), like bag_ui / mounts_ui. Esc or X closes.

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.62, 0.57, 0.49)
const FAINT := Color(0.48, 0.44, 0.38)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.10, 0.08, 0.06, 0.98)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BG_DONE := Color(0.10, 0.085, 0.045, 0.96)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const BAR_BG := Color(0.05, 0.04, 0.03)
const BAR_FILL := Color(0.80, 0.62, 0.22)
const SCRIM := Color(0.0, 0.0, 0.0, 0.5)

const PANEL_W: float = 384.0
const PANEL_H: float = 276.0
const PAD: float = 10.0
const RAIL_W: float = 108.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _sys: Node = null
var _actor: Node = null
var _sel_cat: String = ""
var _scrim: ColorRect
var _panel: Control
var _title: Label
var _points_lbl: Label
var _rail: VBoxContainer
var _epigraph: Label
var _list: VBoxContainer
var _cat_buttons: Dictionary = {}   # cat id -> Button


func _ready() -> void:
	layer = 12
	add_to_group("achievements_ui")
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

	_title = _mk_label("THE DEED-BOOK", 15, GOLD)
	_title.position = Vector2(PAD + 2, 8.0)
	_title.size = Vector2(200.0, 20.0)
	frame.add_child(_title)

	_points_lbl = _mk_label("Points kept: 0", 11, GOLD_BRIGHT)
	_points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points_lbl.position = Vector2(PANEL_W - 190.0, 11.0)
	_points_lbl.size = Vector2(160.0, 16.0)
	frame.add_child(_points_lbl)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 20.0, 8.0)
	close_btn.size = Vector2(20.0, 17.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	# Left rail: category tabs.
	var rail_scroll := ScrollContainer.new()
	rail_scroll.position = Vector2(PAD, 32.0)
	rail_scroll.size = Vector2(RAIL_W, PANEL_H - 42.0)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(rail_scroll)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 2)
	_rail.custom_minimum_size = Vector2(RAIL_W - 4.0, 0.0)
	rail_scroll.add_child(_rail)

	# Right side: epigraph + deed list.
	_epigraph = _mk_label("", 8, DIM)
	_epigraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epigraph.position = Vector2(PAD + RAIL_W + 6.0, 30.0)
	_epigraph.size = Vector2(PANEL_W - RAIL_W - PAD * 2.0 - 6.0, 22.0)
	frame.add_child(_epigraph)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD + RAIL_W + 6.0, 52.0)
	scroll.size = Vector2(PANEL_W - RAIL_W - PAD * 2.0 - 6.0, PANEL_H - 62.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(PANEL_W - RAIL_W - PAD * 2.0 - 20.0, 0.0)
	scroll.add_child(_list)


func present(sys: Node, actor: Node) -> void:
	_sys = sys
	_actor = actor
	if _sel_cat == "" and _sys != null:
		var cats: Array = _sys.call("categories")
		if not cats.is_empty():
			_sel_cat = str((cats[0] as Dictionary).get("id", "general"))
	_rebuild_rail()
	_refresh()
	_show()


func on_ledger_changed() -> void:
	# Live refresh if the book is open when a deed is earned.
	if is_open:
		_rebuild_rail()
		_refresh()


func _rebuild_rail() -> void:
	for c: Node in _rail.get_children():
		c.queue_free()
	_cat_buttons.clear()
	if _sys == null:
		return
	for c_v: Variant in _sys.call("categories"):
		var c: Dictionary = c_v
		var cid: String = str(c.get("id", ""))
		var pips: Dictionary = _sys.call("category_pips", cid)
		var btn := _mk_tab("%s\n%d/%d" % [str(c.get("name", cid)),
				int(pips.get("done", 0)), int(pips.get("total", 0))], cid == _sel_cat)
		btn.tooltip_text = str(c.get("epigraph", ""))
		btn.pressed.connect(func() -> void:
			_sel_cat = cid
			_rebuild_rail()
			_refresh())
		_rail.add_child(btn)
		_cat_buttons[cid] = btn


func _refresh() -> void:
	if _sys == null:
		return
	_points_lbl.text = "Points kept: %d" % int(_sys.call("points", _actor))
	_epigraph.text = _epigraph_for(_sel_cat)
	for c: Node in _list.get_children():
		c.queue_free()
	var ids: Array = _sys.call("deeds_in", _sel_cat)
	if ids.is_empty():
		_add_note("No deeds in this category yet.")
		return
	for id_v: Variant in ids:
		_add_row(str(id_v))


func _add_row(id: String) -> void:
	var d: Dictionary = _sys.call("def", id)
	var earned: bool = bool(_sys.call("is_unlocked", id))
	var hidden: bool = bool(d.get("hidden", false))
	var row := _row_container(earned)

	if hidden and not earned:
		var un := _mk_label("-  a deed unwritten  -", 11, FAINT)
		un.position = Vector2(6.0, 8.0)
		un.size = Vector2(_row_w() - 12.0, 16.0)
		un.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(un)
		_list.add_child(row)
		return

	var pts: int = int(d.get("points", 0))
	var is_feat: bool = str(d.get("category", "")) == "feats" or pts == 0

	var name_lbl := _mk_label(str(d.get("name", "Deed")), 12, GOLD if earned else PARCHMENT)
	name_lbl.position = Vector2(6.0, 3.0)
	name_lbl.size = Vector2(_row_w() - 44.0, 16.0)
	row.add_child(name_lbl)

	var chip := _mk_label(("FEAT" if is_feat else str(pts)), 10, GOLD if earned else DIM)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chip.position = Vector2(_row_w() - 42.0, 3.0)
	chip.size = Vector2(36.0, 14.0)
	row.add_child(chip)

	var desc := _mk_label(str(d.get("desc", "")), 8, DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(6.0, 19.0)
	desc.size = Vector2(_row_w() - 12.0, 12.0)
	row.add_child(desc)

	if not is_feat:
		var pair: Array = _progress_pair(id)
		var cur: int = int(pair[0])
		var tgt: int = maxi(int(pair[1]), 1)
		_add_bar(row, cur, tgt, earned)

	if earned:
		var info: Dictionary = _sys.call("earned_info", id)
		var by: String = str(info.get("char", ""))
		var dt: String = str(info.get("date", ""))
		var tag := _mk_label("earned %s%s" % [dt, ("  -  " + by) if by != "" else ""], 7, FAINT)
		tag.position = Vector2(6.0, 44.0)
		tag.size = Vector2(_row_w() - 12.0, 10.0)
		row.add_child(tag)

	_list.add_child(row)


func _add_bar(row: Control, cur: int, tgt: int, earned: bool) -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = BAR_BG
	bar_bg.position = Vector2(6.0, 33.0)
	bar_bg.size = Vector2(_row_w() - 12.0, 9.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_bg)
	var frac: float = clampf(float(cur) / float(tgt), 0.0, 1.0)
	if earned:
		frac = 1.0
	var fill := ColorRect.new()
	fill.color = BAR_FILL if earned else BAR_FILL.darkened(0.25)
	fill.position = Vector2(6.0, 33.0)
	fill.size = Vector2((_row_w() - 12.0) * frac, 9.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	var ov := _mk_label("%d / %d" % [mini(cur, tgt), tgt], 7, PARCHMENT)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ov.position = Vector2(6.0, 32.0)
	ov.size = Vector2(_row_w() - 12.0, 11.0)
	row.add_child(ov)


func _progress_pair(id: String) -> Array:
	var d: Dictionary = _sys.call("def", id)
	var crit: Dictionary = d.get("criteria", {})
	if str(crit.get("event", "")) == "meta":
		var needs: Array = crit.get("needs", [])
		var done: int = 0
		for n_v: Variant in needs:
			if bool(_sys.call("is_unlocked", str(n_v))):
				done += 1
		return [done, needs.size()]
	return [int(_sys.call("progress", _actor, id)), int(_sys.call("threshold", id))]


func _epigraph_for(cat: String) -> String:
	for c_v: Variant in _sys.call("categories"):
		var c: Dictionary = c_v
		if str(c.get("id", "")) == cat:
			return str(c.get("epigraph", ""))
	return ""


# --- little builders --------------------------------------------------------

func _row_container(earned: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(_row_w(), 56.0)
	var bg := ColorRect.new()
	bg.color = SLOT_BG_DONE if earned else SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _add_note(text: String) -> void:
	var l := _mk_label(text, 9, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_row_w(), 24.0)
	_list.add_child(l)


func _row_w() -> float:
	return PANEL_W - RAIL_W - PAD * 2.0 - 22.0


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
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func _mk_tab(text: String, selected: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(RAIL_W - 6.0, 26.0)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", GOLD if selected else PARCHMENT)
	b.add_theme_color_override("font_color_hover", GOLD_BRIGHT)
	b.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	b.add_theme_constant_override("outline_size", 3)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.08, 0.98) if selected else SLOT_BG
	sb.border_color = GOLD if selected else SLOT_BORDER
	sb.set_border_width_all(2)
	if selected:
		sb.set_border_width_all(2)
		sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


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
