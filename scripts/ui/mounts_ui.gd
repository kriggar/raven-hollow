extends CanvasLayer
## MountsUI -- the stable / collection page for Raven Hollow (design/MOUNTS.md 5).
## Instanced by the MountSystem autoload (scenes/ui/mounts.tscn). Presents the
## known mounts as rarity-colored rows (name + tier pips + source + Summon), a
## "Stable: X / N" collection counter, and the local stablemaster's for-sale
## list with Buy buttons. Styled to the shared gold-bezel kit (panel_brown
## 9-patch + Alagard + GOLD) like bag_ui / loot_window. Esc or the X closes.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)

const PANEL_W: float = 300.0
const PANEL_H: float = 300.0
const PAD: float = 12.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _ms: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _panel: Control
var _list: VBoxContainer
var _title: Label
var _trainer_id: String = "angel_wings"


func _ready() -> void:
	layer = 11
	add_to_group("mounts_ui")
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

	_title = _mk_label("STABLE", 16, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	frame.add_child(_title)

	var close_btn := _mk_button("X", 40.0)
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
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 12.0, 0.0)
	scroll.add_child(_list)


func present(ms: Node, actor: Node) -> void:
	_ms = ms
	_actor = actor
	_refresh()
	_show()


func _refresh() -> void:
	if _ms == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var total: int = int(_ms.call("mount_count"))
	var known: Array = _ms.call("owned", _actor)
	_title.text = "STABLE   %d / %d" % [known.size(), total]

	_add_header("YOUR MOUNTS")
	if known.is_empty():
		_add_note("No mounts yet. Visit a stablemaster or best an elite.")
	for mid_v: Variant in known:
		_add_owned_row(str(mid_v))

	_add_header("STABLEMASTER  (Angel Wings)")
	var stock: Array = _ms.call("trainer_stock", _trainer_id)
	if stock.is_empty():
		_add_note("Nothing for sale here today.")
	for sid_v: Variant in stock:
		_add_trainer_row(str(sid_v))


func _add_owned_row(mid: String) -> void:
	var m: Dictionary = _ms.call("mount_def", mid)
	var row := _row_container()
	var mounted: bool = bool(_ms.call("is_mounted", _actor)) \
			and str(_ms.call("active_mount", _actor)) == mid
	var name_lbl := _mk_label(_row_title(m), 12, _rarity_color(str(m.get("rarity", "common"))))
	name_lbl.size = Vector2(180.0, 16.0)
	name_lbl.position = Vector2(4.0, 3.0)
	row.add_child(name_lbl)
	var src := _mk_label(_source_label(m), 8, DIM)
	src.size = Vector2(180.0, 12.0)
	src.position = Vector2(4.0, 17.0)
	row.add_child(src)
	var btn := _mk_button("RIDING" if mounted else "Summon", 34.0)
	btn.size = Vector2(60.0, 22.0)
	btn.position = Vector2(_row_w() - 66.0, 4.0)
	btn.disabled = mounted
	btn.pressed.connect(func() -> void:
		if bool(_ms.call("is_mounted", _actor)):
			_ms.call("dismiss", _actor)
		_ms.call("summon", _actor, mid)
		_refresh())
	row.add_child(btn)
	_list.add_child(row)


func _add_trainer_row(mid: String) -> void:
	var m: Dictionary = _ms.call("mount_def", mid)
	var owned_already: bool = bool(_ms.call("is_owned", _actor, mid))
	var row := _row_container()
	var name_lbl := _mk_label(_row_title(m), 12, _rarity_color(str(m.get("rarity", "common"))))
	name_lbl.size = Vector2(180.0, 16.0)
	name_lbl.position = Vector2(4.0, 3.0)
	row.add_child(name_lbl)
	var price: int = int(_ms.call("mount_price", mid))
	var price_lbl := _mk_label("%d g" % price, 8, GOLD)
	price_lbl.size = Vector2(180.0, 12.0)
	price_lbl.position = Vector2(4.0, 17.0)
	row.add_child(price_lbl)
	var btn := _mk_button("Owned" if owned_already else "Buy", 34.0)
	btn.size = Vector2(60.0, 22.0)
	btn.position = Vector2(_row_w() - 66.0, 4.0)
	btn.disabled = owned_already
	btn.pressed.connect(func() -> void:
		var r: Dictionary = _ms.call("buy_from_trainer", _actor, _trainer_id, mid)
		_refresh())
	row.add_child(btn)
	_list.add_child(row)


# --- little builders --------------------------------------------------------

func _row_container() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(_row_w(), 30.0)
	var bg := ColorRect.new()
	bg.color = SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _add_header(text: String) -> void:
	var l := _mk_label(text, 10, PARCHMENT)
	l.custom_minimum_size = Vector2(_row_w(), 16.0)
	_list.add_child(l)


func _add_note(text: String) -> void:
	var l := _mk_label(text, 8, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_row_w(), 24.0)
	_list.add_child(l)


func _row_w() -> float:
	return PANEL_W - PAD * 2.0 - 14.0


func _row_title(m: Dictionary) -> String:
	var pips: String = " I" if int(m.get("tier", 1)) <= 1 else " II"
	return str(m.get("name", "Mount")) + pips


func _source_label(m: Dictionary) -> String:
	var src: String = str(m.get("source", ""))
	var names := {
		"vendor": "Trainer", "rep": "Faction", "drop": "Drop",
		"quest": "Quest", "event": "Festival", "tame": "Wild tame",
		"trophy": "Elite trophy", "class": "Class prestige",
	}
	return str(names.get(src, src))


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


func _mk_button(text: String, _w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_color_disabled", DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	return b


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.35, 0.75, 0.35)
		"rare": return Color(0.30, 0.50, 0.90)
		"epic": return Color(0.62, 0.35, 0.85)
		"legendary": return Color(1.0, 0.55, 0.1)
		_: return Color(0.72, 0.72, 0.72)


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
