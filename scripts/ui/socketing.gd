extends CanvasLayer
## SocketingUI -- the rune-socketing panel for Raven Hollow (design/RUNEWORDS.md 8,
## owner amendment: D2 DARK GOLD). Instanced by the RunewordSystem autoload
## (scenes/ui/socketing.tscn). Shows a socketed item's sockets, a rune pouch you
## drag or click runes from into the sockets, and a LIVE runeword-match preview
## that lights bright gold the instant a sequence completes a known word.
## Built from the shared gold-bezel kit (panel_brown 9-patch + Alagard) recolored
## to dark gold. Esc or the X closes. Refreshed by RunewordSystem.refresh().

# --- D2 dark-gold palette ----------------------------------------------------
const GOLD := Color(0.80, 0.62, 0.26)          # dark gold (headline / rune)
const GOLD_DIM := Color(0.52, 0.42, 0.22)       # muted gold (empty socket rim)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.45)     # word-complete flash
const GOLD_RIM := Color(0.54, 0.39, 0.15)
const PARCHMENT := Color(0.85, 0.80, 0.68)
const DIM := Color(0.60, 0.54, 0.44)
const OUTLINE_DARK := Color(0.06, 0.04, 0.02)
const BOX_BG := Color(0.085, 0.065, 0.035, 0.98)   # warm near-black
const SLOT_BG := Color(0.05, 0.04, 0.02, 0.96)
const SOCKET_EMPTY_BG := Color(0.02, 0.015, 0.01, 0.98)
const SCRIM := Color(0.0, 0.0, 0.0, 0.55)

const PANEL_W: float = 342.0
const PANEL_H: float = 306.0
const PAD: float = 12.0
const SOCKET_SZ: float = 30.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _rw: Node = null
var _actor: Node = null
var _item: Dictionary = {}
var _selected_rune: String = ""

var _scrim: ColorRect
var _title: Label
var _item_name: Label
var _item_sub: Label
var _sockets_row: Control
var _preview_reads: Label
var _preview_status: Label
var _pouch: GridContainer
var _hint: Label


func _ready() -> void:
	layer = 12
	add_to_group("socketing_ui")
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

	_title = _mk_label("SOCKETING", 16, GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(PAD, 7.0)
	_title.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	frame.add_child(_title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 20.0, 8.0)
	close_btn.size = Vector2(20.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	# Item identity
	_item_name = _mk_label("", 13, GOLD)
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name.position = Vector2(PAD, 30.0)
	_item_name.size = Vector2(PANEL_W - PAD * 2.0, 16.0)
	frame.add_child(_item_name)

	_item_sub = _mk_label("", 8, DIM)
	_item_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_sub.position = Vector2(PAD, 45.0)
	_item_sub.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	frame.add_child(_item_sub)

	# Sockets row (centered band)
	_sockets_row = Control.new()
	_sockets_row.position = Vector2(PAD, 60.0)
	_sockets_row.size = Vector2(PANEL_W - PAD * 2.0, SOCKET_SZ + 6.0)
	frame.add_child(_sockets_row)

	# Live runeword preview
	_preview_reads = _mk_label("", 10, PARCHMENT)
	_preview_reads.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_reads.position = Vector2(PAD, 98.0)
	_preview_reads.size = Vector2(PANEL_W - PAD * 2.0, 14.0)
	frame.add_child(_preview_reads)

	_preview_status = _mk_label("", 11, GOLD)
	_preview_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_status.position = Vector2(PAD, 113.0)
	_preview_status.size = Vector2(PANEL_W - PAD * 2.0, 16.0)
	frame.add_child(_preview_status)

	# Pouch header
	var ph := _mk_label("RUNE POUCH", 10, GOLD)
	ph.position = Vector2(PAD, 134.0)
	ph.size = Vector2(PANEL_W - PAD * 2.0, 14.0)
	frame.add_child(ph)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 150.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 150.0 - 22.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_pouch = GridContainer.new()
	_pouch.columns = 3
	_pouch.add_theme_constant_override("h_separation", 4)
	_pouch.add_theme_constant_override("v_separation", 4)
	_pouch.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 14.0, 0.0)
	scroll.add_child(_pouch)

	_hint = _mk_label("Click or drag a rune into a socket", 8, DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(PAD, PANEL_H - 18.0)
	_hint.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	frame.add_child(_hint)


# --- present / refresh -------------------------------------------------------

func present(rw: Node, actor: Node, item: Dictionary) -> void:
	_rw = rw
	_actor = actor
	_item = item
	_selected_rune = ""
	refresh()
	_show()


func refresh() -> void:
	if _rw == null:
		return
	var has_item: bool = not _item.is_empty() and int(_rw.call("socket_count", _item)) > 0
	if has_item:
		_item_name.text = str(_item.get("name", "Item"))
		_item_name.add_theme_color_override("font_color",
				_rarity_color(str(_item.get("rarity", "common"))))
		_item_sub.text = "%s  -  i%d  -  %d sockets" % [
			_slot_label(str(_item.get("slot", ""))),
			_ilvl(_item), int(_rw.call("socket_count", _item))]
	else:
		_item_name.text = "No socketed item"
		_item_name.add_theme_color_override("font_color", DIM)
		_item_sub.text = "Equip a weapon, chest or helm that carries sockets"
	_build_sockets(has_item)
	_build_preview(has_item)
	_build_pouch()


func _build_sockets(has_item: bool) -> void:
	for c: Node in _sockets_row.get_children():
		c.queue_free()
	if not has_item:
		return
	var runes: Array = _rw.call("item_runes", _item)
	var n: int = runes.size()
	var total_w: float = n * SOCKET_SZ + (n - 1) * 10.0
	var x0: float = (_sockets_row.size.x - total_w) * 0.5
	for i: int in n:
		var rid: String = str(runes[i])
		var slot := _SocketSlot.new()
		slot.setup(self, i, rid, _rw)
		slot.position = Vector2(x0 + i * (SOCKET_SZ + 10.0), 3.0)
		slot.size = Vector2(SOCKET_SZ, SOCKET_SZ)
		slot.custom_minimum_size = slot.size
		_sockets_row.add_child(slot)


func _build_preview(has_item: bool) -> void:
	if not has_item:
		_preview_reads.text = ""
		_preview_status.text = ""
		return
	var pv: Dictionary = _rw.call("preview", _item)
	var runes: Array = pv.get("runes", [])
	var parts: PackedStringArray = []
	for r: Variant in runes:
		var rid: String = str(r)
		if rid == "":
			parts.append("( )")
		else:
			parts.append(str(_rw.call("rune_name", rid)))
	_preview_reads.text = "READS:   " + "  -  ".join(parts)
	if bool(pv.get("complete", false)):
		_preview_status.text = "%s   -   WORD COMPLETE" % str(pv.get("word_name", ""))
		_preview_status.add_theme_color_override("font_color", GOLD_BRIGHT)
	elif str(pv.get("word", "")) != "":
		# All sockets filled, matches a key, but a gate blocks it.
		_preview_status.text = "%s  -  %s" % [str(pv.get("word_name", "")), str(pv.get("reason", ""))]
		_preview_status.add_theme_color_override("font_color", DIM)
	else:
		_preview_status.text = "( %s )" % str(pv.get("reason", ""))
		_preview_status.add_theme_color_override("font_color", DIM)


func _build_pouch() -> void:
	for c: Node in _pouch.get_children():
		c.queue_free()
	var runes: Dictionary = _rw.call("all_runes")
	var order: Array = ["veth", "sul", "nul", "isk", "om", "kar",
			"thar", "mor", "dra", "zev", "azh", "ur"]
	for rid_v: Variant in order:
		var rid: String = str(rid_v)
		if not runes.has(rid):
			continue
		var chip := _RuneChip.new()
		chip.setup(self, rid, _rw)
		chip.custom_minimum_size = Vector2(98.0, 30.0)
		_pouch.add_child(chip)
	_refresh_chip_selection()


func _refresh_chip_selection() -> void:
	for c: Node in _pouch.get_children():
		if c is _RuneChip:
			(c as _RuneChip).set_selected((c as _RuneChip).rune_id == _selected_rune)


# --- interaction called back from chips / sockets ---------------------------

func select_rune(rune_id: String) -> void:
	_selected_rune = "" if _selected_rune == rune_id else rune_id
	_refresh_chip_selection()


func socket_clicked(socket_idx: int) -> void:
	# Click-to-place: needs a selected rune and an empty socket.
	if _selected_rune == "":
		_flash_hint("Pick a rune first", DIM)
		return
	place_rune(socket_idx, _selected_rune)


func place_rune(socket_idx: int, rune_id: String) -> void:
	if _rw == null or _item.is_empty():
		return
	var res: Dictionary = _rw.call("socket_rune", _actor, _item, socket_idx, rune_id)
	if bool(res.get("ok", false)):
		_selected_rune = ""
		if str(res.get("runeword", "")) != "":
			_flash_hint("The word resolves. It cannot be unsaid.", GOLD_BRIGHT)
		else:
			_flash_hint("Set. The mark cannot be unmade.", GOLD)
		# RunewordSystem.socket_rune calls refresh() on us already.
	else:
		_flash_hint(str(res.get("reason", "Cannot socket.")), Color(0.85, 0.45, 0.30))


func _flash_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)


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
	b.add_theme_color_override("font_color_hover", GOLD_BRIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = GOLD_RIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.35, 0.75, 0.35)
		"rare": return Color(0.30, 0.50, 0.90)
		"epic": return Color(0.62, 0.35, 0.85)
		"legendary": return Color(1.0, 0.55, 0.1)
		"runeword": return GOLD
		_: return PARCHMENT


func _slot_label(slot: String) -> String:
	match slot:
		"main_hand": return "Main Hand"
		"chest": return "Chest"
		"head": return "Head"
		_: return slot.capitalize()


func _ilvl(item: Dictionary) -> int:
	for k: String in ["ilvl", "item_level", "req_level"]:
		if item.has(k):
			return int(item[k])
	return 0


# --- show / hide / input -----------------------------------------------------

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


# ============================================================================
# Inner controls: draggable rune chip + drop-target socket slot.
# ============================================================================

class _RuneChip extends Panel:
	var rune_id: String = ""
	var _ui: Node = null
	var _rw: Node = null
	var _selected: bool = false
	var _name_lbl: Label
	var _sub_lbl: Label

	func setup(ui: Node, rid: String, rw: Node) -> void:
		_ui = ui
		rune_id = rid
		_rw = rw
		mouse_filter = Control.MOUSE_FILTER_STOP
		_style(false)
		var col: Color = _rw.call("rune_color", rune_id)
		_name_lbl = _lbl(_rw.call("rune_name", rune_id), 11, col)
		_name_lbl.position = Vector2(6.0, 2.0)
		_name_lbl.size = Vector2(88.0, 14.0)
		add_child(_name_lbl)
		_sub_lbl = _lbl(_bonus_text(), 7, Color(0.60, 0.54, 0.44))
		_sub_lbl.position = Vector2(6.0, 16.0)
		_sub_lbl.size = Vector2(88.0, 10.0)
		add_child(_sub_lbl)

	func _bonus_text() -> String:
		var sb: Dictionary = (_rw.call("rune_def", rune_id) as Dictionary).get("socket_bonus", {})
		var parts: PackedStringArray = []
		for k: Variant in sb:
			parts.append("+%d %s" % [int(sb[k]), _abbr(str(k))])
		return " ".join(parts)

	func _abbr(stat: String) -> String:
		match stat:
			"hp": return "hp"
			"mana": return "mp"
			"armor": return "arm"
			"damage": return "dmg"
			"crit_pct": return "crit"
			"speed_pct": return "spd"
			"mana_regen": return "reg"
			_: return stat

	func set_selected(v: bool) -> void:
		if v == _selected:
			return
		_selected = v
		_style(v)

	func _style(sel: bool) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.07, 0.04, 0.98) if not sel else Color(0.16, 0.12, 0.05, 0.99)
		sb.border_color = Color(0.54, 0.39, 0.15) if not sel else Color(1.0, 0.85, 0.45)
		sb.set_border_width_all(2 if sel else 1)
		sb.set_corner_radius_all(3)
		add_theme_stylebox_override("panel", sb)

	func _lbl(text: String, size: int, color: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", preload("res://assets/fonts/alagard.ttf"))
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if _ui != null and _ui.has_method("select_rune"):
				_ui.call("select_rune", rune_id)

	func _get_drag_data(_at: Vector2) -> Variant:
		var prev := Panel.new()
		prev.custom_minimum_size = Vector2(70.0, 24.0)
		prev.size = Vector2(70.0, 24.0)
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.12, 0.09, 0.04, 0.95)
		psb.border_color = Color(1.0, 0.85, 0.45)
		psb.set_border_width_all(2)
		psb.set_corner_radius_all(3)
		prev.add_theme_stylebox_override("panel", psb)
		var pl := _lbl(_rw.call("rune_name", rune_id), 11, _rw.call("rune_color", rune_id))
		pl.position = Vector2(6.0, 4.0)
		prev.add_child(pl)
		set_drag_preview(prev)
		return {"rune_id": rune_id}


class _SocketSlot extends Panel:
	var socket_idx: int = 0
	var rune_id: String = ""
	var _ui: Node = null
	var _rw: Node = null

	func setup(ui: Node, idx: int, rid: String, rw: Node) -> void:
		_ui = ui
		socket_idx = idx
		rune_id = rid
		_rw = rw
		mouse_filter = Control.MOUSE_FILTER_STOP
		var filled: bool = rune_id != ""
		var sb := StyleBoxFlat.new()
		# Round the corners hard so an empty socket reads as a drilled hole.
		sb.set_corner_radius_all(13)
		if filled:
			var col: Color = _rw.call("rune_color", rune_id)
			sb.bg_color = Color(col.r * 0.22 + 0.02, col.g * 0.18 + 0.02, col.b * 0.10 + 0.01, 0.99)
			sb.border_color = Color(1.0, 0.85, 0.45)
			sb.set_border_width_all(2)
		else:
			sb.bg_color = Color(0.02, 0.015, 0.01, 0.98)
			sb.border_color = Color(0.52, 0.42, 0.22)
			sb.set_border_width_all(2)
		add_theme_stylebox_override("panel", sb)
		if filled:
			var l := Label.new()
			l.text = str(_rw.call("rune_name", rune_id))
			l.add_theme_font_override("font", preload("res://assets/fonts/alagard.ttf"))
			l.add_theme_font_size_override("font_size", 9)
			l.add_theme_color_override("font_color", _rw.call("rune_color", rune_id))
			l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02))
			l.add_theme_constant_override("outline_size", 3)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if _ui != null and _ui.has_method("socket_clicked"):
				_ui.call("socket_clicked", socket_idx)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return rune_id == "" and data is Dictionary and (data as Dictionary).has("rune_id")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if _ui != null and _ui.has_method("place_rune"):
			_ui.call("place_rune", socket_idx, str((data as Dictionary)["rune_id"]))
