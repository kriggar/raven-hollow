extends CanvasLayer
## ShopUI -- the vendor shop for Raven Hollow (design/SMART_NPCS.md 3.4).
## Instanced by the SmartNPCSystem autoload (scenes/ui/shop.tscn). A dumb view
## over SmartNPCSystem: a FOR-SALE list (icon + name + price + Buy) and a YOUR-
## BAG list (icon + name + sell price + Sell), with the player's live gold in
## the header. Styled to the shared gold-bezel bag kit (panel_brown 9-patch +
## Alagard + GOLD). Buy/sell round-trip through SmartNPCSystem.buy/sell, which
## own the gold + Inventory writes. Esc or the X closes.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)

const PANEL_W: float = 320.0
const PANEL_H: float = 320.0
const PAD: float = 12.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _sns: Node = null
var _actor: Node = null
var _vendor_id: String = ""
var _scrim: ColorRect
var _panel: Control
var _title: Label
var _gold_lbl: Label
var _list: VBoxContainer


func _ready() -> void:
	layer = 11
	add_to_group("shop_ui")
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

	_title = _mk_label("SHOP", 15, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(PANEL_W - PAD * 2.0, 18.0)
	frame.add_child(_title)

	_gold_lbl = _mk_label("Gold: 0", 10, GOLD)
	_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_lbl.position = Vector2(PAD, 26.0)
	_gold_lbl.size = Vector2(PANEL_W - PAD * 2.0, 14.0)
	frame.add_child(_gold_lbl)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 44.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 56.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 12.0, 0.0)
	scroll.add_child(_list)


func present(sns: Node, vendor_id: String, actor: Node) -> void:
	_sns = sns
	_vendor_id = vendor_id
	_actor = actor
	_refresh()
	_show()


func _refresh() -> void:
	if _sns == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var v: Dictionary = _sns.call("vendor_def", _vendor_id)
	_title.text = str(v.get("name", "Shop")).to_upper()
	_gold_lbl.text = "Gold: %d" % _gold()

	# Closed-for-hours note, but still browsable (kindness).
	if not bool(_sns.call("is_open", _vendor_id)):
		_add_note("The shop is shut for the night. Come back by day.")

	_add_header("FOR SALE   (%s)" % str(v.get("type", "")))
	var stock: Array = _sns.call("stock_for", _vendor_id)
	if stock.is_empty():
		_add_note("Nothing in stock today.")
	for i in range(stock.size()):
		_add_buy_row(i, _dict(stock[i]))

	_add_header("YOUR BAG   (right-side sells)")
	var sold_any: bool = false
	var inv: Object = _inv()
	if inv != null:
		var bag_v: Variant = inv.get("bag")
		if bag_v is Array:
			for bi in range((bag_v as Array).size()):
				var entry: Variant = (bag_v as Array)[bi]
				if entry is Dictionary:
					_add_sell_row(bi, entry)
					sold_any = true
	if not sold_any:
		_add_note("Your bag is empty.")


func _add_buy_row(idx: int, row: Dictionary) -> void:
	var item: Dictionary = _dict(row.get("item", {}))
	var price: int = int(row.get("price", 0))
	var cont := _row_container()
	_add_icon(cont, str(item.get("icon", "")))
	var name_lbl := _mk_label(str(item.get("name", "Item")), 11, _rarity_color(str(item.get("rarity", "common"))))
	name_lbl.size = Vector2(170.0, 16.0)
	name_lbl.position = Vector2(30.0, 3.0)
	cont.add_child(name_lbl)
	var price_lbl := _mk_label("%d g" % price, 9, GOLD)
	price_lbl.size = Vector2(170.0, 12.0)
	price_lbl.position = Vector2(30.0, 17.0)
	cont.add_child(price_lbl)
	var afford: bool = _gold() >= price
	var btn := _mk_button("Buy")
	btn.size = Vector2(54.0, 22.0)
	btn.position = Vector2(_row_w() - 60.0, 4.0)
	btn.disabled = not afford
	btn.pressed.connect(func() -> void:
		_sns.call("buy", _vendor_id, idx, _actor)
		_refresh())
	cont.add_child(btn)
	_list.add_child(cont)


func _add_sell_row(bag_idx: int, item: Dictionary) -> void:
	var cont := _row_container()
	_add_icon(cont, str(item.get("icon", "")))
	var name_lbl := _mk_label(str(item.get("name", "Item")), 11, _rarity_color(str(item.get("rarity", "common"))))
	name_lbl.size = Vector2(170.0, 16.0)
	name_lbl.position = Vector2(30.0, 3.0)
	cont.add_child(name_lbl)
	var price: int = int(_sns.call("sell_price", item))
	var price_lbl := _mk_label("sell %d g" % price, 9, DIM)
	price_lbl.size = Vector2(170.0, 12.0)
	price_lbl.position = Vector2(30.0, 17.0)
	cont.add_child(price_lbl)
	var btn := _mk_button("Sell")
	btn.size = Vector2(54.0, 22.0)
	btn.position = Vector2(_row_w() - 60.0, 4.0)
	btn.pressed.connect(func() -> void:
		_sns.call("sell", bag_idx, _actor)
		_refresh())
	cont.add_child(btn)
	_list.add_child(cont)


# --- builders ---------------------------------------------------------------

func _add_icon(cont: Control, icon_id: String) -> void:
	if icon_id == "":
		return
	var tex: Texture2D = IconsPixel.get_tex(icon_id)
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size = Vector2(22.0, 22.0)
	tr.position = Vector2(5.0, 4.0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.add_child(tr)


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
	l.custom_minimum_size = Vector2(_row_w(), 22.0)
	_list.add_child(l)


func _row_w() -> float:
	return PANEL_W - PAD * 2.0 - 14.0


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


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.35, 0.75, 0.35)
		"rare": return Color(0.30, 0.50, 0.90)
		"epic": return Color(0.62, 0.35, 0.85)
		"legendary": return Color(1.0, 0.55, 0.1)
		_: return Color(0.72, 0.72, 0.72)


func _gold() -> int:
	if _actor != null:
		var g: Variant = _actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _inv() -> Object:
	if _actor == null:
		return null
	var inv: Variant = _actor.get("inventory")
	return inv if inv is Object else null


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func close() -> void:
	_hide()
	if _sns != null and _sns.has_signal("shop_closed"):
		_sns.emit_signal("shop_closed", _vendor_id)


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
