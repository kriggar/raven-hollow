extends CanvasLayer
## BankUI -- the banker page for Raven Hollow (BACKLOG #72). Instanced by the
## AuctionSystem autoload (scenes/ui/bank.tscn). Three tabs: GOLD (deposit /
## withdraw between purse and vault, +10 / +100 / All), VAULT (store bag items /
## take vault items), and MATERIALS (the vault filtered to crafting mats). Styled
## to the shared gold-bezel kit (panel_brown 9-patch + Alagard + GOLD). Esc/X close.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.45)

const PANEL_W: float = 420.0
const PANEL_H: float = 336.0
const PAD: float = 12.0

const RARITY := {
	"poor": Color(0.62, 0.62, 0.62), "common": Color(0.82, 0.82, 0.80),
	"uncommon": Color(0.35, 0.75, 0.35), "rare": Color(0.30, 0.50, 0.90),
	"epic": Color(0.62, 0.35, 0.85), "legendary": Color(1.0, 0.55, 0.10),
}

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _as: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _title: Label
var _summary: Label
var _tab_row: HBoxContainer
var _content: Control
var _status: Label
var _tab: String = "Gold"
var _tabs: Array = ["Gold", "Vault", "Materials"]


func _ready() -> void:
	layer = 12
	add_to_group("bank_ui")
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

	_title = _mk_label("THE BANK", 16, GOLD)
	_title.position = Vector2(PAD, 8.0)
	_title.size = Vector2(240.0, 20.0)
	frame.add_child(_title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	_summary = _mk_label("", 12, PARCHMENT)
	_summary.position = Vector2(PAD, 30.0)
	_summary.size = Vector2(PANEL_W - PAD * 2.0, 18.0)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(_summary)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 4)
	_tab_row.position = Vector2(PAD, 52.0)
	_tab_row.size = Vector2(PANEL_W - PAD * 2.0, 22.0)
	frame.add_child(_tab_row)

	_content = Control.new()
	_content.position = Vector2(PAD, 80.0)
	_content.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 96.0)
	frame.add_child(_content)

	_status = _mk_label("", 8, DIM)
	_status.position = Vector2(PAD, PANEL_H - 12.0)
	_status.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	frame.add_child(_status)


func present(as_sys: Node, actor: Node) -> void:
	_as = as_sys
	_actor = actor
	var cfg: Dictionary = _as.call("bank_config")
	var tabs_v: Variant = cfg.get("tabs")
	if tabs_v is Array and not (tabs_v as Array).is_empty():
		_tabs = tabs_v
		if not _tabs.has(_tab):
			_tab = str(_tabs[0])
	_title.text = str(cfg.get("name", "THE BANK")).to_upper()
	_refresh()
	_show()


func _refresh() -> void:
	if _as == null:
		return
	_build_tabs()
	var purse: int = _purse()
	var vault: int = int(_as.call("bank_balance", _actor))
	_summary.text = "Purse  %d g          Vault  %d g" % [purse, vault]
	for c: Node in _content.get_children():
		c.queue_free()
	match _tab:
		"Gold":
			_build_gold_tab()
		_:
			_build_vault_tab(_tab == "Materials")


func _build_tabs() -> void:
	for c: Node in _tab_row.get_children():
		c.queue_free()
	for t_v: Variant in _tabs:
		var t: String = str(t_v)
		var b := _mk_button(t)
		b.custom_minimum_size = Vector2(90.0, 20.0)
		if t == _tab:
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		b.pressed.connect(func() -> void:
			_tab = t
			_refresh())
		_tab_row.add_child(b)


func _build_gold_tab() -> void:
	var dep_hdr := _mk_label("DEPOSIT  (purse -> vault)", 11, GOLD)
	dep_hdr.position = Vector2(4.0, 4.0)
	dep_hdr.size = Vector2(_content.size.x - 8.0, 16.0)
	_content.add_child(dep_hdr)
	_gold_buttons(28.0, true)

	var wd_hdr := _mk_label("WITHDRAW  (vault -> purse)", 11, GOLD)
	wd_hdr.position = Vector2(4.0, 96.0)
	wd_hdr.size = Vector2(_content.size.x - 8.0, 16.0)
	_content.add_child(wd_hdr)
	_gold_buttons(120.0, false)


func _gold_buttons(y: float, deposit: bool) -> void:
	var amounts := [10, 100, -1]  # -1 == All
	var x: float = 4.0
	for a_v: Variant in amounts:
		var a: int = int(a_v)
		var label: String = ("All" if a < 0 else str(a))
		var b := _mk_button(("+ " if deposit else "- ") + label)
		b.position = Vector2(x, y)
		b.size = Vector2(120.0, 26.0)
		b.pressed.connect(func() -> void:
			var amount: int = a
			if a < 0:
				amount = _purse() if deposit else int(_as.call("bank_balance", _actor))
			var res: Dictionary
			if deposit:
				res = _as.call("bank_deposit", _actor, amount)
			else:
				res = _as.call("bank_withdraw", _actor, amount)
			_status.text = ("Moved %d g" % int(res.get("moved", 0))) if bool(res.get("ok", false)) else str(res.get("reason", "No."))
			_refresh())
		_content.add_child(b)
		x += 128.0


func _build_vault_tab(mats_only: bool) -> void:
	# Left: bag items (store).  Right: vault items (take).
	var col_w: float = _content.size.x * 0.5 - 6.0
	var bag_hdr := _mk_label("BAG  (store ->)", 10, GOLD)
	bag_hdr.position = Vector2(0.0, 0.0)
	bag_hdr.size = Vector2(col_w, 14.0)
	_content.add_child(bag_hdr)
	var vault_hdr := _mk_label("VAULT  (<- take)", 10, GOLD)
	vault_hdr.position = Vector2(col_w + 12.0, 0.0)
	vault_hdr.size = Vector2(col_w, 14.0)
	_content.add_child(vault_hdr)

	var bag_scroll := ScrollContainer.new()
	bag_scroll.position = Vector2(0.0, 18.0)
	bag_scroll.size = Vector2(col_w, _content.size.y - 20.0)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(bag_scroll)
	var bag_list := VBoxContainer.new()
	bag_list.add_theme_constant_override("separation", 2)
	bag_list.custom_minimum_size = Vector2(col_w - 12.0, 0.0)
	bag_scroll.add_child(bag_list)

	var vault_scroll := ScrollContainer.new()
	vault_scroll.position = Vector2(col_w + 12.0, 18.0)
	vault_scroll.size = Vector2(col_w, _content.size.y - 20.0)
	vault_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(vault_scroll)
	var vault_list := VBoxContainer.new()
	vault_list.add_theme_constant_override("separation", 2)
	vault_list.custom_minimum_size = Vector2(col_w - 12.0, 0.0)
	vault_scroll.add_child(vault_list)

	# bag rows (store), tracking the true bag index
	var inv: Node = get_node_or_null("/root/InventorySystem")
	var any_bag := false
	if inv != null and inv.has_method("get_bag"):
		var bag: Array = inv.call("get_bag", _actor)
		for i in range(bag.size()):
			if not (bag[i] is Dictionary):
				continue
			var item: Dictionary = bag[i]
			if mats_only and not _is_material(item):
				continue
			any_bag = true
			_item_row(bag_list, item, "Store", col_w - 12.0, func() -> void:
				var res: Dictionary = _as.call("bank_store_item", _actor, i)
				_status.text = "Stored " + str(item.get("name", "")) if bool(res.get("ok", false)) else str(res.get("reason", "No."))
				_refresh())
	if not any_bag:
		_note(bag_list, "Nothing to store." if not mats_only else "No mats in bag.", col_w - 12.0)

	# vault rows (take)
	var items: Array = _as.call("bank_items", _actor)
	var any_vault := false
	for i in range(items.size()):
		var item2: Dictionary = _dict(items[i])
		if mats_only and not _is_material(item2):
			continue
		any_vault = true
		_item_row(vault_list, item2, "Take", col_w - 12.0, func() -> void:
			var res: Dictionary = _as.call("bank_take_item", _actor, i)
			_status.text = "Took " + str(item2.get("name", "")) if bool(res.get("ok", false)) else str(res.get("reason", "No."))
			_refresh())
	if not any_vault:
		_note(vault_list, "Vault empty." if not mats_only else "No mats stored.", col_w - 12.0)


func _item_row(host: VBoxContainer, item: Dictionary, action: String, w: float, cb: Callable) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(w, 30.0)
	var bg := ColorRect.new()
	bg.color = SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)
	var rc: Color = RARITY.get(str(item.get("rarity", "common")), PARCHMENT)
	var name_lbl := _mk_label(str(item.get("name", "?")), 10, rc)
	name_lbl.position = Vector2(4.0, 2.0)
	name_lbl.size = Vector2(w - 8.0, 14.0)
	row.add_child(name_lbl)
	var btn := _mk_button(action)
	btn.position = Vector2(4.0, 15.0)
	btn.size = Vector2(w - 8.0, 14.0)
	btn.pressed.connect(cb)
	row.add_child(btn)
	host.add_child(row)


func _note(host: VBoxContainer, text: String, w: float) -> void:
	var l := _mk_label(text, 8, DIM)
	l.custom_minimum_size = Vector2(w, 16.0)
	host.add_child(l)


func _is_material(item: Dictionary) -> bool:
	return str(item.get("type", "")) == "material" or item.has("mat_id")


func _purse() -> int:
	if _actor == null:
		return 0
	var gv: Variant = _actor.get("gold")
	return int(gv) if (gv is int or gv is float) else 0


# --- little builders --------------------------------------------------------

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
	sb.set_border_width_all(1)
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
