extends CanvasLayer
## AuctionUI -- the auction house page for Raven Hollow (BACKLOG #72). Instanced
## by the AuctionSystem autoload (scenes/ui/auction.tscn). Left: a searchable,
## category-filtered listings grid (name + rarity color, seller, price, Buy).
## Right: the SELL column -- the player's own bag items with a List button at the
## suggested buyout, plus the live gold purse. Styled to the shared gold-bezel
## kit (panel_brown 9-patch + Alagard + GOLD). Esc or the X closes.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.45)

const PANEL_W: float = 500.0
const PANEL_H: float = 356.0
const PAD: float = 12.0

const RARITY := {
	"poor": Color(0.62, 0.62, 0.62), "common": Color(0.82, 0.82, 0.80),
	"uncommon": Color(0.35, 0.75, 0.35), "rare": Color(0.30, 0.50, 0.90),
	"epic": Color(0.62, 0.35, 0.85), "legendary": Color(1.0, 0.55, 0.10),
}

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _as: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _title: Label
var _gold_lbl: Label
var _cat_row: HBoxContainer
var _search: LineEdit
var _list: VBoxContainer
var _sell_list: VBoxContainer
var _filter_cat: String = "all"
var _status: Label


func _ready() -> void:
	layer = 12
	add_to_group("auction_ui")
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

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	_title = _mk_label("AUCTION HOUSE", 16, GOLD)
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(280.0, 20.0)
	frame.add_child(_title)

	_gold_lbl = _mk_label("", 12, GOLD)
	_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_lbl.position = Vector2(PANEL_W - 190.0, 9.0)
	_gold_lbl.size = Vector2(150.0, 18.0)
	frame.add_child(_gold_lbl)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	# category filter row
	_cat_row = HBoxContainer.new()
	_cat_row.add_theme_constant_override("separation", 3)
	_cat_row.position = Vector2(PAD, 30.0)
	_cat_row.size = Vector2(310.0, 20.0)
	frame.add_child(_cat_row)

	# search field
	_search = LineEdit.new()
	_search.placeholder_text = "search..."
	_search.position = Vector2(PAD, 52.0)
	_search.size = Vector2(300.0, 22.0)
	_search.add_theme_font_override("font", _font)
	_search.add_theme_font_size_override("font_size", 11)
	_search.add_theme_color_override("font_color", PARCHMENT)
	var lesb := StyleBoxFlat.new()
	lesb.bg_color = SLOT_BG
	lesb.border_color = SLOT_BORDER
	lesb.set_border_width_all(2)
	lesb.content_margin_left = 6
	_search.add_theme_stylebox_override("normal", lesb)
	_search.add_theme_stylebox_override("focus", lesb)
	_search.text_changed.connect(func(_t: String) -> void: _refresh_listings())
	frame.add_child(_search)

	# listings scroll (left)
	var l_scroll := ScrollContainer.new()
	l_scroll.position = Vector2(PAD, 78.0)
	l_scroll.size = Vector2(306.0, PANEL_H - 90.0)
	l_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(l_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(292.0, 0.0)
	l_scroll.add_child(_list)

	# SELL column (right)
	var sell_hdr := _mk_label("YOUR WARES  (list to sell)", 10, GOLD)
	sell_hdr.position = Vector2(PAD + 316.0, 30.0)
	sell_hdr.size = Vector2(160.0, 16.0)
	frame.add_child(sell_hdr)
	var r_scroll := ScrollContainer.new()
	r_scroll.position = Vector2(PAD + 316.0, 52.0)
	r_scroll.size = Vector2(PANEL_W - PAD * 2.0 - 316.0, PANEL_H - 88.0)
	r_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(r_scroll)
	_sell_list = VBoxContainer.new()
	_sell_list.add_theme_constant_override("separation", 3)
	_sell_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 332.0, 0.0)
	r_scroll.add_child(_sell_list)

	_status = _mk_label("", 8, DIM)
	_status.position = Vector2(PAD, PANEL_H - 12.0)
	_status.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	frame.add_child(_status)


func present(as_sys: Node, actor: Node) -> void:
	_as = as_sys
	_actor = actor
	_build_cat_row()
	_refresh_all()
	_show()


func _build_cat_row() -> void:
	for c: Node in _cat_row.get_children():
		c.queue_free()
	if _as == null:
		return
	for cat_v: Variant in _as.call("categories"):
		var cat: String = str(cat_v)
		var b := _mk_button(cat.capitalize())
		b.custom_minimum_size = Vector2(50.0, 18.0)
		if cat == _filter_cat:
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		b.pressed.connect(func() -> void:
			_filter_cat = cat
			_build_cat_row()
			_refresh_listings())
		_cat_row.add_child(b)


func _refresh_all() -> void:
	_refresh_gold()
	_refresh_listings()
	_refresh_sell()


func _refresh_gold() -> void:
	if _as == null or _actor == null:
		return
	var g: int = 0
	var gv: Variant = _actor.get("gold")
	if gv is int or gv is float:
		g = int(gv)
	_gold_lbl.text = "Purse: %d g" % g


func _refresh_listings() -> void:
	if _as == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var flt := {"category": _filter_cat, "search": _search.text if _search != null else ""}
	var rows: Array = _as.call("browse", flt)
	if rows.is_empty():
		_add_note(_list, "No listings match. Try another filter.")
		return
	for l_v: Variant in rows:
		_add_listing_row(_dict(l_v))


func _add_listing_row(l: Dictionary) -> void:
	var item: Dictionary = _dict(l.get("item", {}))
	var row := _row(292.0, 34.0)
	var rc: Color = RARITY.get(str(item.get("rarity", "common")), PARCHMENT)
	var name_lbl := _mk_label(str(item.get("name", "?")), 12, rc)
	name_lbl.position = Vector2(5.0, 2.0)
	name_lbl.size = Vector2(200.0, 16.0)
	row.add_child(name_lbl)
	var qty: int = int(l.get("qty", 1))
	var sub := "%s   x%d" % [str(l.get("seller", "")), qty]
	var sub_lbl := _mk_label(sub, 8, DIM)
	sub_lbl.position = Vector2(5.0, 18.0)
	sub_lbl.size = Vector2(200.0, 12.0)
	row.add_child(sub_lbl)
	var price: int = int(l.get("price", 0))
	var price_lbl := _mk_label("%d g" % price, 9, GOLD)
	price_lbl.position = Vector2(205.0, 3.0)
	price_lbl.size = Vector2(48.0, 14.0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)
	var lid: String = str(l.get("id", ""))
	var is_mine: bool = bool(l.get("is_player", false))
	var btn := _mk_button("Reclaim" if is_mine else "Buy")
	btn.position = Vector2(230.0, 8.0)
	btn.size = Vector2(56.0, 20.0)
	btn.pressed.connect(func() -> void:
		var res: Dictionary
		if is_mine:
			res = _as.call("cancel_listing", _actor, lid)
		else:
			res = _as.call("buy", _actor, lid)
		if bool(res.get("ok", false)):
			_status.text = ("Reclaimed " if is_mine else "Bought ") + str(item.get("name", ""))
		else:
			_status.text = str(res.get("reason", "No."))
		_refresh_all())
	row.add_child(btn)
	_list.add_child(row)


func _refresh_sell() -> void:
	for c: Node in _sell_list.get_children():
		c.queue_free()
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null or not inv.has_method("list_items"):
		_add_note(_sell_list, "No inventory.")
		return
	var items: Array = inv.call("list_items", _actor)
	if items.is_empty():
		_add_note(_sell_list, "Your bag is empty.")
		return
	for it_v: Variant in items:
		_add_sell_row(_dict(it_v))


func _add_sell_row(item: Dictionary) -> void:
	var w: float = _sell_list.custom_minimum_size.x
	var row := _row(w, 32.0)
	var rc: Color = RARITY.get(str(item.get("rarity", "common")), PARCHMENT)
	var name_lbl := _mk_label(str(item.get("name", "?")), 11, rc)
	name_lbl.position = Vector2(4.0, 2.0)
	name_lbl.size = Vector2(w - 8.0, 14.0)
	row.add_child(name_lbl)
	var price: int = int(_as.call("suggested_price", item))
	var btn := _mk_button("List %dg" % price)
	btn.position = Vector2(4.0, 15.0)
	btn.size = Vector2(w - 8.0, 15.0)
	btn.pressed.connect(func() -> void:
		var res: Dictionary = _as.call("list_item", _actor, item, price)
		_status.text = ("Listed " + str(item.get("name", ""))) if bool(res.get("ok", false)) else str(res.get("reason", "No."))
		_refresh_all())
	row.add_child(btn)
	_sell_list.add_child(row)


# --- little builders --------------------------------------------------------

func _row(w: float, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	var bg := ColorRect.new()
	bg.color = SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _add_note(host: VBoxContainer, text: String) -> void:
	var l := _mk_label(text, 8, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(host.custom_minimum_size.x, 20.0)
	host.add_child(l)


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
