extends CanvasLayer
## ReputationUI -- the faction standing page for Raven Hollow (BACKLOG #71).
## Instanced by the FactionSystem autoload (scenes/ui/reputation.tscn). Presents
## every faction as a row: an emblem badge (placeholder colored glyph now, Fable
## pixel art later), the faction name + race/capital, the WoW-tier label in its
## tier color, and a reputation bar showing progress inside the current tier.
## Styled to the shared gold-bezel kit (panel_brown 9-patch + Alagard + GOLD)
## like mounts_ui / bag_ui. Esc or the X closes; opened with the 'O' key.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const BAR_BG := Color(0.03, 0.025, 0.02, 0.98)
const BAR_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)

const PANEL_W: float = 344.0
const PANEL_H: float = 328.0
const PAD: float = 12.0
const ROW_H: float = 44.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _fs: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _panel: Control
var _list: VBoxContainer
var _title: Label


func _ready() -> void:
	layer = 11
	add_to_group("reputation_ui")
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

	_title = _mk_label("REPUTATION", 16, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	frame.add_child(_title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 34.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 46.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 12.0, 0.0)
	scroll.add_child(_list)


func present(fs: Node, actor: Node) -> void:
	_fs = fs
	_actor = actor
	_refresh()
	_show()


func _refresh() -> void:
	if _fs == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var ids: Array = _fs.call("faction_ids")
	for fid_v: Variant in ids:
		_add_faction_row(str(fid_v))


func _add_faction_row(fid: String) -> void:
	var f: Dictionary = _fs.call("faction_def", fid)
	var prog: Dictionary = _fs.call("tier_progress", _actor, fid)
	var em: Dictionary = _fs.call("emblem_color", fid)
	var tier_col: Color = em_color(prog.get("color", GOLD))

	var row := _row_container()

	# Emblem badge (placeholder colored glyph; Fable pixel art at em.path later).
	_add_badge(row, Vector2(4.0, 5.0), em, fid)

	# Faction name + race / capital subtitle.
	var name_lbl := _mk_label(str(f.get("name", fid)), 12, em_color(em.get("fg", PARCHMENT)))
	name_lbl.position = Vector2(42.0, 3.0)
	name_lbl.size = Vector2(180.0, 15.0)
	row.add_child(name_lbl)
	var sub := _mk_label("%s - %s" % [str(f.get("race", "")), str(f.get("capital", ""))], 8, DIM)
	sub.position = Vector2(42.0, 17.0)
	sub.size = Vector2(200.0, 12.0)
	row.add_child(sub)

	# Tier label (right-aligned, tier color).
	var tier_lbl := _mk_label(str(prog.get("tier_name", "Neutral")), 11, tier_col)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tier_lbl.position = Vector2(_row_w() - 118.0, 3.0)
	tier_lbl.size = Vector2(114.0, 15.0)
	row.add_child(tier_lbl)

	# Reputation bar (progress within the current tier).
	_add_bar(row, Vector2(42.0, 30.0), _row_w() - 46.0, 9.0, float(prog.get("frac", 0.0)), tier_col)
	var num: String = "MAX" if bool(prog.get("is_max", false)) and float(prog.get("frac", 0.0)) >= 1.0 \
			else "%d / %d" % [int(prog.get("into", 0)), int(prog.get("span", 1))]
	var num_lbl := _mk_label(num, 8, PARCHMENT)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_lbl.position = Vector2(_row_w() - 96.0, 18.0)
	num_lbl.size = Vector2(92.0, 12.0)
	row.add_child(num_lbl)

	_list.add_child(row)


# --- little builders --------------------------------------------------------

func _add_badge(row: Control, pos: Vector2, em: Dictionary, fid: String = "") -> void:
	# UNIQUE ICON LAW: baked faction emblem when present (icons_factions/)
	var art: String = "res://assets/art/icons_factions/%s.png" % fid
	if fid != "" and ResourceLoader.exists(art):
		var ic := TextureRect.new()
		ic.texture = load(art)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = pos
		ic.size = Vector2(32.0, 32.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		ic.add_child(_rect_border(Vector2(32.0, 32.0), em_color(em.get("fg", GOLD))))
		return
	var box := ColorRect.new()
	box.color = em_color(em.get("bg", SLOT_BG))
	box.position = pos
	box.size = Vector2(32.0, 32.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var border := _rect_border(Vector2(32.0, 32.0), em_color(em.get("fg", GOLD)))
	box.add_child(border)
	var glyph := _mk_label(str(em.get("glyph", "?")), 18, em_color(em.get("fg", GOLD)))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glyph)


func _add_bar(row: Control, pos: Vector2, w: float, h: float, frac: float, col: Color) -> void:
	var bar_bg := ColorRect.new()
	bar_bg.color = BAR_BG
	bar_bg.position = pos
	bar_bg.size = Vector2(w, h)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2(1.0, 1.0)
	fill.size = Vector2(maxf(0.0, (w - 2.0) * clampf(frac, 0.0, 1.0)), h - 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(fill)
	bar_bg.add_child(_rect_border(Vector2(w, h), BAR_BORDER))


func _rect_border(sz: Vector2, col: Color) -> Control:
	var b := Control.new()
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = col
	sb.set_border_width_all(2)
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	return b


func _row_container() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(_row_w(), ROW_H)
	var bg := ColorRect.new()
	bg.color = SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _row_w() -> float:
	return PANEL_W - PAD * 2.0 - 14.0


func em_color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() >= 4 else 1.0)
	return GOLD


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
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", Color(1.0, 0.92, 0.7))
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = BAR_BORDER
	sb.set_border_width_all(2)
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
