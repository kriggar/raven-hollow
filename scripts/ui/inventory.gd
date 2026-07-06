extends CanvasLayer
## InventoryUI — the paperdoll inventory + backpack window for Raven Hollow,
## reading the InventorySystem autoload (bags + the nine equip slots) and
## StatsSystem-backed gear. Styled to the gold-bezel ornate-UI HUD kit (the
## panel_brown 9-patch rim + Alagard + parchment/gold palette shared by
## loot_window.gd / item_tooltip.gd).
##
## Left: a paper-doll of the nine equip slots around a dim silhouette, each cell
## rarity-rimmed. Right: the backpack grid. Rarity-colored everywhere; hover pops
## a tooltip with concrete stats AND a "vs equipped" delta column + the
## proficiency verdict line. Click a bag item to equip it (proficiency/level
## gated, with an in-world denial toast); click an equipped slot to take it off;
## drag a bag item onto a doll slot (or a doll slot back to the bag) to move it.
##
## Opened via the "inventory" action (I) while instanced, or by open()/demo_open()
## from the QA harness (RH_INVENTORY).

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SLOT_BORDER_HOVER := Color(0.62, 0.48, 0.26)
const HOSTILE_RED := Color(0.85, 0.30, 0.26)
const GREEN_POS := Color(0.46, 0.80, 0.42)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)
const SILHOUETTE := Color(0.16, 0.14, 0.13, 0.85)

const PAD: float = 12.0
const HEADER_H: float = 28.0
const EQ_W: float = 156.0
const GAP: float = 14.0
const CELL: float = 30.0
const ICON: float = CELL - 6.0
const BAG_COLS: int = 6
const BAG_CELL: float = 30.0
const BAG_GAP: float = 3.0
const TIP_LAYER: int = 16
const DRAG_LAYER: int = 17

## Paper-doll placement: [slot, column(0=left,1=right,2=center), row].
const DOLL_LAYOUT: Array = [
	["head", 0, 0], ["chest", 0, 1], ["legs", 0, 2], ["boots", 0, 3],
	["main_hand", 1, 0], ["off_hand", 1, 1], ["ring1", 1, 2], ["ring2", 1, 3],
	["trinket", 2, 4],
]
const STAT_ROWS: Array = [
	["damage", "Damage", false], ["armor", "Armor", false],
	["hp", "Health", false], ["mana", "Mana", false],
	["mana_regen", "Mana Regen", false],
	["speed_pct", "Speed", true], ["crit_pct", "Crit", true],
]

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")
var _italic: FontVariation

var _actor: Object = null
var _is_open: bool = false
var _tween: Tween

var _root: Control
var _scrim: ColorRect
var _panel: Control
var _frame: NinePatchRect
var _title: Label
var _gs_label: Label
var _equip_host: Control
var _bag_host: Control
var _footer: Label

var _equip_cells: Dictionary = {}   # slot -> Panel
var _bag_cells: Array = []          # index -> Panel

# tooltip
var _tip: Panel
var _tip_rows: VBoxContainer

# drag state
var _press_kind: String = ""        # "bag" | "equip" | ""
var _press_key: Variant = null      # bag idx (int) or slot (String)
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_ghost: TextureRect
var _drag_layer: CanvasLayer


func _ready() -> void:
	layer = 12
	_italic = FontVariation.new()
	_italic.base_font = _font
	_italic.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2.ZERO)
	_build_shell()
	_build_tooltip()
	_build_drag_layer()
	var inv: Node = _inv()
	if inv != null and inv.has_signal("inventory_changed"):
		if not inv.is_connected("inventory_changed", _on_inventory_changed):
			inv.connect("inventory_changed", _on_inventory_changed)
	if _actor == null:
		_actor = get_tree().get_first_node_in_group("player")


# --- public API -------------------------------------------------------------

func set_actor(actor: Object) -> void:
	_actor = actor


func open() -> void:
	if _actor == null:
		_actor = get_tree().get_first_node_in_group("player")
	_refresh()
	_layout()
	_root.visible = true
	_is_open = true
	_play_intro()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_hide_tooltip()
	_end_drag(false)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.10)
	_tween.tween_callback(func() -> void: _root.visible = false)


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


# --- systems access ---------------------------------------------------------

func _inv() -> Node:
	return get_node_or_null("/root/InventorySystem")


func _stats() -> Node:
	return get_node_or_null("/root/StatsSystem")


# --- shell ------------------------------------------------------------------

func _build_shell() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = SCRIM
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(_on_scrim_input)
	_root.add_child(_scrim)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner_w: float = EQ_W + GAP + _bag_width()
	var panel_w: float = inner_w + PAD * 2.0
	var panel_h: float = PAD + HEADER_H + _equip_height() + PAD
	_panel.size = Vector2(panel_w, panel_h)
	_root.add_child(_panel)

	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 3.0
	fill.offset_top = 3.0
	fill.offset_right = -3.0
	fill.offset_bottom = -3.0
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill.add_theme_stylebox_override("panel", fill_sb)
	_panel.add_child(fill)

	_frame = NinePatchRect.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture = _panel_tex
	_frame.draw_center = false
	_frame.patch_margin_left = 10
	_frame.patch_margin_right = 10
	_frame.patch_margin_top = 10
	_frame.patch_margin_bottom = 10
	_frame.modulate = FRAME_TINT
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_frame)

	_title = _mk_label(_panel, 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_title.text = "Inventory"
	_title.position = Vector2(PAD + 2.0, 7.0)
	_title.size = Vector2(180.0, 15.0)

	_gs_label = _mk_label(_panel, 10, PARCHMENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_gs_label.position = Vector2(_panel.size.x - 150.0 - PAD, 8.0)
	_gs_label.size = Vector2(150.0, 13.0)

	# hairline under the header
	var div := ColorRect.new()
	div.color = SLOT_BORDER_HOVER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.position = Vector2(PAD, HEADER_H)
	div.size = Vector2(_panel.size.x - PAD * 2.0, 1.0)
	_panel.add_child(div)

	# equipment host (left)
	_equip_host = Control.new()
	_equip_host.name = "Equip"
	_equip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equip_host.position = Vector2(PAD, PAD + HEADER_H)
	_panel.add_child(_equip_host)

	# silhouette behind the doll
	var silo := ColorRect.new()
	silo.color = SILHOUETTE
	silo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	silo.position = Vector2(CELL + 12.0, 6.0)
	silo.size = Vector2(EQ_W - (CELL + 12.0) * 2.0, _equip_height() - 44.0)
	_equip_host.add_child(silo)
	var silo_lbl := _mk_label(_equip_host, 8, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	silo_lbl.text = "EQUIP"
	silo_lbl.position = Vector2(silo.position.x, silo.position.y + silo.size.y * 0.5 - 6.0)
	silo_lbl.size = Vector2(silo.size.x, 12.0)

	# bag host (right)
	_bag_host = Control.new()
	_bag_host.name = "Bag"
	_bag_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_host.position = Vector2(PAD + EQ_W + GAP, PAD + HEADER_H)
	_panel.add_child(_bag_host)
	var bag_title := _mk_label(_bag_host, 9, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	bag_title.text = "Backpack"
	bag_title.position = Vector2(0.0, -1.0)
	bag_title.size = Vector2(_bag_width(), 12.0)

	_footer = _mk_label(_panel, 8, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_footer.position = Vector2(PAD + 2.0, _panel.size.y - 15.0)
	_footer.size = Vector2(_panel.size.x - PAD * 2.0, 12.0)
	_footer.text = "Click to equip / unequip  -  drag to move  -  Esc to close"

	_build_equip_cells()
	_build_bag_cells()


func _bag_width() -> float:
	return float(BAG_COLS) * BAG_CELL + float(BAG_COLS - 1) * BAG_GAP


func _equip_height() -> float:
	# 4 rows of cells (pitch 42) + trinket row + gear-score line
	return 6.0 + 4.0 * 42.0 + CELL + 16.0 + 18.0


func _doll_cell_pos(col: int, row: int) -> Vector2:
	var y: float = 6.0 + float(row) * 42.0
	match col:
		0:
			return Vector2(6.0, y)
		1:
			return Vector2(EQ_W - 6.0 - CELL, y)
		_:
			return Vector2((EQ_W - CELL) * 0.5, y)


func _build_equip_cells() -> void:
	for entry: Array in DOLL_LAYOUT:
		var slot: String = entry[0]
		var pos: Vector2 = _doll_cell_pos(int(entry[1]), int(entry[2]))
		var cell: Panel = _mk_cell(_equip_host, pos, "equip", slot)
		var lbl := _mk_label(cell, 6, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.name = "SlotLabel"
		lbl.text = str(_inv_slot_label(slot)).to_upper()
		lbl.position = Vector2(-3.0, CELL + 1.0)
		lbl.size = Vector2(CELL + 6.0, 8.0)
		_equip_cells[slot] = cell
	_gs_label.text = ""


func _build_bag_cells() -> void:
	_bag_cells.clear()
	var n: int = _bag_size()
	for i in range(n):
		var col: int = i % BAG_COLS
		var row: int = i / BAG_COLS
		var pos := Vector2(
			float(col) * (BAG_CELL + BAG_GAP),
			12.0 + float(row) * (BAG_CELL + BAG_GAP))
		var cell: Panel = _mk_cell(_bag_host, pos, "bag", i)
		_bag_cells.append(cell)


func _bag_size() -> int:
	var inv: Node = _inv()
	if inv != null:
		var v: Variant = inv.get("BAG_SIZE")
		if v is int:
			return v
	return 30


func _inv_slot_label(slot: String) -> String:
	var inv: Node = _inv()
	if inv != null:
		var labels: Variant = inv.get("SLOT_LABELS")
		if labels is Dictionary and (labels as Dictionary).has(slot):
			return str((labels as Dictionary)[slot])
	return slot.capitalize()


func _mk_cell(parent: Control, pos: Vector2, kind: String, key: Variant) -> Panel:
	var cell := Panel.new()
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.position = pos
	cell.size = Vector2(CELL, CELL)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", sb)
	cell.set_meta("kind", kind)
	cell.set_meta("key", key)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.position = Vector2(3.0, 3.0)
	ic.size = Vector2(ICON, ICON)
	cell.add_child(ic)
	var qty := _mk_label(cell, 8, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	qty.name = "Qty"
	qty.position = Vector2(0.0, CELL - 11.0)
	qty.size = Vector2(CELL - 2.0, 10.0)
	qty.visible = false
	cell.gui_input.connect(_on_cell_input.bind(cell))
	cell.mouse_entered.connect(_on_cell_hover.bind(cell, true))
	cell.mouse_exited.connect(_on_cell_hover.bind(cell, false))
	parent.add_child(cell)
	return cell


func _mk_label(parent: Control, fsize: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(l)
	return l


# --- refresh ----------------------------------------------------------------

func _on_inventory_changed(actor: Object) -> void:
	if actor == _actor and _is_open:
		_refresh()


func _refresh() -> void:
	if _actor == null:
		return
	var inv: Node = _inv()
	if inv == null:
		return
	var eq: Dictionary = inv.call("get_equipment", _actor)
	for slot: String in _equip_cells.keys():
		var item: Variant = eq.get(slot)
		_paint_cell(_equip_cells[slot], item if item is Dictionary else {}, true)
	var bag: Array = inv.call("get_bag", _actor)
	for i in range(_bag_cells.size()):
		var it: Variant = bag[i] if i < bag.size() else null
		_paint_cell(_bag_cells[i], it if it is Dictionary else {}, false)
	var gs: int = int(inv.call("gear_score", _actor))
	_gs_label.text = "Gear Score  %d" % gs


func _paint_cell(cell: Panel, item: Dictionary, is_equip: bool) -> void:
	var icon: TextureRect = cell.get_node("Icon") as TextureRect
	var qty: Label = cell.get_node("Qty") as Label
	var slot_lbl: Node = cell.get_node_or_null("SlotLabel")
	var sb: StyleBoxFlat = cell.get_theme_stylebox("panel") as StyleBoxFlat
	cell.set_meta("item", item)
	if item.is_empty():
		icon.texture = null
		qty.visible = false
		if sb != null:
			sb.border_color = SLOT_BORDER
			sb.bg_color = SLOT_BG
		if slot_lbl is Label:
			(slot_lbl as Label).visible = true
		return
	if slot_lbl is Label:
		(slot_lbl as Label).visible = false
	icon.texture = _icon_for(item)
	var rc: Color = _rarity_color(str(item.get("rarity", "common")))
	if sb != null:
		sb.border_color = rc
		sb.bg_color = SLOT_BG.lerp(Color(rc.r, rc.g, rc.b, 1.0), 0.14)
	# red rim overlay when the actor cannot equip a bag item (proficiency/level)
	if not is_equip:
		var verdict: Dictionary = _inv().call("can_equip", _actor, item)
		if not bool(verdict.get("ok", true)):
			if sb != null:
				sb.border_color = HOSTILE_RED
	var count: int = int(item.get("quantity", 1))
	if bool(item.get("stackable", false)) and count > 1:
		qty.text = "x%d" % count
		qty.visible = true
	else:
		qty.visible = false


func _icon_for(item: Dictionary) -> Texture2D:
	var icon: String = str(item.get("icon", ""))
	if icon.begins_with("pixel:"):
		var id: String = icon.trim_prefix("pixel:")
		if id != "" and IconsPixel.has_icon(id):
			return IconsPixel.get_tex(id)
	return null


func _rarity_color(rarity: String) -> Color:
	var inv: Node = _inv()
	if inv != null and inv.has_method("rarity_color"):
		return inv.call("rarity_color", rarity)
	return ItemTooltip.rarity_color(rarity)


# --- layout / intro ---------------------------------------------------------

func _layout() -> void:
	var view := Vector2(640, 360)
	var vp: Viewport = get_viewport()
	if vp != null:
		view = vp.get_visible_rect().size
	_panel.position = ((view - _panel.size) * 0.5).floor()


func _play_intro() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_root.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseMotion:
		if _dragging:
			_drag_ghost.global_position = (event as InputEventMouseMotion).position + Vector2(4, 4)
		elif _press_kind != "":
			var moved: float = (event as InputEventMouseMotion).position.distance_to(_press_pos)
			if moved > 5.0:
				_begin_drag()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _dragging:
				_resolve_drop(mb.position)
				_end_drag(true)
			elif _press_kind != "":
				_do_click()
			_press_kind = ""
			_press_key = null


func _on_cell_input(event: InputEvent, cell: Panel) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var item: Variant = cell.get_meta("item", {})
			if item is Dictionary and not (item as Dictionary).is_empty():
				_press_kind = str(cell.get_meta("kind"))
				_press_key = cell.get_meta("key")
				_press_pos = mb.position


func _do_click() -> void:
	var inv: Node = _inv()
	if inv == null:
		return
	if _press_kind == "bag":
		var verdict: Dictionary = inv.call("equip_from_bag", _actor, int(_press_key))
		if not bool(verdict.get("ok", false)):
			_toast(str(verdict.get("reason", "Cannot equip.")), HOSTILE_RED)
		else:
			_hide_tooltip()
	elif _press_kind == "equip":
		if not bool(inv.call("unequip", _actor, str(_press_key))):
			_toast("Bag is full.", HOSTILE_RED)
		else:
			_hide_tooltip()


# --- drag & drop ------------------------------------------------------------

func _build_drag_layer() -> void:
	_drag_layer = CanvasLayer.new()
	_drag_layer.layer = DRAG_LAYER
	add_child(_drag_layer)
	_drag_ghost = TextureRect.new()
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.size = Vector2(ICON + 4.0, ICON + 4.0)
	_drag_ghost.modulate = Color(1, 1, 1, 0.85)
	_drag_ghost.visible = false
	_drag_layer.add_child(_drag_ghost)


func _begin_drag() -> void:
	var item: Dictionary = _item_at(_press_kind, _press_key)
	if item.is_empty():
		return
	_dragging = true
	_hide_tooltip()
	_drag_ghost.texture = _icon_for(item)
	_drag_ghost.visible = true
	_drag_ghost.global_position = _press_pos + Vector2(4, 4)


func _end_drag(_dropped: bool) -> void:
	_dragging = false
	if _drag_ghost != null:
		_drag_ghost.visible = false
		_drag_ghost.texture = null


func _resolve_drop(pos: Vector2) -> void:
	var inv: Node = _inv()
	if inv == null:
		return
	var target: Panel = _cell_under(pos)
	if _press_kind == "bag":
		var idx: int = int(_press_key)
		if target != null and str(target.get_meta("kind", "")) == "equip":
			var verdict: Dictionary = inv.call("equip_from_bag", _actor, idx, str(target.get_meta("key")))
			if not bool(verdict.get("ok", false)):
				_toast(str(verdict.get("reason", "Cannot equip.")), HOSTILE_RED)
		elif target == null or str(target.get_meta("kind", "")) == "bag":
			# dropping onto the doll region without a valid slot -> just equip auto
			var v2: Dictionary = inv.call("equip_from_bag", _actor, idx)
			if not bool(v2.get("ok", false)) and target != null and str(target.get_meta("kind", "")) == "equip":
				_toast(str(v2.get("reason", "Cannot equip.")), HOSTILE_RED)
	elif _press_kind == "equip":
		# drag an equipped item to the bag -> unequip
		if target == null or str(target.get_meta("kind", "")) == "bag":
			if not bool(inv.call("unequip", _actor, str(_press_key))):
				_toast("Bag is full.", HOSTILE_RED)


func _cell_under(pos: Vector2) -> Panel:
	for slot: String in _equip_cells.keys():
		var c: Panel = _equip_cells[slot]
		if c.get_global_rect().has_point(pos):
			return c
	for c2: Variant in _bag_cells:
		if (c2 as Panel).get_global_rect().has_point(pos):
			return c2
	return null


func _item_at(kind: String, key: Variant) -> Dictionary:
	var inv: Node = _inv()
	if inv == null:
		return {}
	if kind == "bag":
		var bag: Array = inv.call("get_bag", _actor)
		var i: int = int(key)
		if i >= 0 and i < bag.size() and bag[i] is Dictionary:
			return bag[i]
	elif kind == "equip":
		return inv.call("get_equipped", _actor, str(key))
	return {}


# --- tooltip (with compare-to-equipped) -------------------------------------

func _build_tooltip() -> void:
	var tip_layer := CanvasLayer.new()
	tip_layer.layer = TIP_LAYER
	add_child(tip_layer)
	_tip = Panel.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = Color(0.45, 0.33, 0.18)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(7.0)
	_tip.add_theme_stylebox_override("panel", sb)
	tip_layer.add_child(_tip)
	_tip_rows = VBoxContainer.new()
	_tip_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_rows.add_theme_constant_override("separation", 1)
	_tip.add_child(_tip_rows)


func _on_cell_hover(cell: Panel, on: bool) -> void:
	var sb: StyleBoxFlat = cell.get_theme_stylebox("panel") as StyleBoxFlat
	var item: Variant = cell.get_meta("item", {})
	if on:
		if sb != null and item is Dictionary and (item as Dictionary).is_empty():
			sb.border_color = SLOT_BORDER_HOVER
		if item is Dictionary and not (item as Dictionary).is_empty() and not _dragging:
			_show_tooltip(item, str(cell.get_meta("kind")))
	else:
		if item is Dictionary and (item as Dictionary).is_empty() and sb != null:
			sb.border_color = SLOT_BORDER
		_hide_tooltip()


func _hide_tooltip() -> void:
	if _tip != null:
		_tip.visible = false


func _show_tooltip(item: Dictionary, from_kind: String) -> void:
	for c: Node in _tip_rows.get_children():
		c.queue_free()
	var inv: Node = _inv()
	var rarity: String = str(item.get("rarity", "common"))
	var rc: Color = _rarity_color(rarity)

	_tip_line(_tip_rows, str(item.get("name", "?")), 12, rc)

	# slot - rarity - ilvl
	var slot: String = str(item.get("slot", "none"))
	var slot_pretty: String = _inv_slot_label(_norm_slot(slot))
	var ilvl: int = int(inv.call("item_level", item)) if inv != null else 1
	_tip_line(_tip_rows, "%s  -  %s  -  ilvl %d" % [slot_pretty, rarity.capitalize(), ilvl], 8, DIM)

	# proficiency verdict line (armor/weapon class, colored)
	var prof: Dictionary = _prof_line(item)
	if str(prof.get("text", "")) != "":
		_tip_line(_tip_rows, str(prof["text"]), 9, prof.get("color", PARCHMENT))

	# compare vs the equipped item that would be replaced
	var equipped: Dictionary = {}
	if from_kind == "bag":
		equipped = _compare_target(item)
	var stats: Dictionary = item.get("stats", {})
	var estats: Dictionary = equipped.get("stats", {}) if not equipped.is_empty() else {}
	for row: Array in STAT_ROWS:
		var v: float = float(stats.get(row[0], 0.0))
		if absf(v) < 0.01:
			continue
		var pct: String = "%" if bool(row[2]) else ""
		var num: String = ("+" if v > 0 else "") + _fmt(v) + pct
		var line: String = "%s %s" % [num, str(row[1])]
		var delta: float = v - float(estats.get(row[0], 0.0))
		var col: Color = PARCHMENT
		if not equipped.is_empty() and absf(delta) >= 0.01:
			line += "  (%s%s%s)" % [("+" if delta > 0 else ""), _fmt(delta), pct]
			col = GREEN_POS if delta > 0 else HOSTILE_RED
		_tip_line(_tip_rows, line, 9, col)

	if not equipped.is_empty():
		_tip_line(_tip_rows, "vs equipped: %s" % str(equipped.get("name", "")), 7, DIM)

	var gs: int = int(inv.call("item_gear_score", item)) if inv != null else 0
	_tip_line(_tip_rows, "Gear Score  %d" % gs, 8, GOLD)

	var flavor: String = str(item.get("flavor", ""))
	if flavor != "":
		var fl := _tip_line(_tip_rows, "\"%s\"" % flavor, 8, Color(0.68, 0.61, 0.46))
		fl.add_theme_font_override("font", _italic)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(150.0, 0.0)

	_tip.visible = true
	_tip.reset_size()
	await get_tree().process_frame
	_place_tooltip(get_viewport().get_mouse_position())


func _tip_line(parent: Control, text: String, fsize: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 2)
	l.text = text
	parent.add_child(l)
	return l


func _place_tooltip(mouse: Vector2) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var view: Vector2 = vp.get_visible_rect().size
	var sz: Vector2 = _tip.size
	var pos := Vector2(mouse.x + 12.0, mouse.y - sz.y - 6.0)
	if pos.x + sz.x > view.x - 4.0:
		pos.x = mouse.x - sz.x - 12.0
	pos.x = clampf(pos.x, 4.0, maxf(4.0, view.x - sz.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, view.y - sz.y - 4.0))
	_tip.position = pos.floor()


## The equipped item this bag item would replace (rings compare vs ring1/slot).
func _compare_target(item: Dictionary) -> Dictionary:
	var inv: Node = _inv()
	if inv == null:
		return {}
	var kind: String = str(item.get("slot", "none"))
	var slot: String = kind
	if kind == "ring":
		var r1: Dictionary = inv.call("get_equipped", _actor, "ring1")
		slot = "ring1" if not r1.is_empty() else "ring2"
	if not ["head", "chest", "legs", "boots", "main_hand", "off_hand", "ring1", "ring2", "trinket"].has(slot):
		return {}
	return inv.call("get_equipped", _actor, slot)


func _norm_slot(slot: String) -> String:
	return "ring1" if slot == "ring" else slot


func _prof_line(item: Dictionary) -> Dictionary:
	var inv: Node = _inv()
	if inv == null:
		return {}
	var slot: String = str(item.get("slot", "none"))
	var text: String = ""
	if slot in ["head", "chest", "legs", "boots"]:
		text = str(inv.call("armor_class_of", item)).capitalize()
	elif slot == "main_hand" or slot == "off_hand":
		text = str(inv.call("weapon_class_of", item)).capitalize()
	else:
		return {}
	var verdict: Dictionary = inv.call("can_equip", _actor, item)
	var col: Color = PARCHMENT if bool(verdict.get("ok", false)) else HOSTILE_RED
	if not bool(verdict.get("ok", false)):
		text += "  -  " + str(verdict.get("reason", ""))
	return {"text": text, "color": col}


# --- misc -------------------------------------------------------------------

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()


func _toast(msg: String, color: Color) -> void:
	# route through the shared HUD toast if present, else the footer line
	var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
	if cui != null and cui.has_method("show_toast"):
		cui.call("show_toast", msg, color)
		return
	if _footer != null:
		_footer.text = msg
		_footer.add_theme_color_override("font_color", color)


func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return "%.1f" % v


# --- QA harness (RH_INVENTORY) ----------------------------------------------

## Seeds a warrior-friendly paperdoll + backpack, proves the loot->stats link
## through StatsSystem (before/after/revert prints), and opens the window.
func demo_open(actor: Object) -> void:
	if actor == null:
		actor = get_tree().get_first_node_in_group("player")
	if actor == null:
		return
	_actor = actor
	var inv: Node = _inv()
	var ss: Node = _stats()
	if inv == null:
		return
	# Give the demo character room above the gear's level requirements, then
	# register (this also syncs StatsSystem so get_derived reflects our mods).
	actor.set("level", 30)
	inv.call("register", actor, "", 30)

	# ---- SELF-TEST: prove gear raises a derived stat through StatsSystem ----
	var weapon: Dictionary = _roll("iron_shortsword", "rare")
	var d_before: float = _derived(ss, actor, "flat_damage")
	print("[INV SELFTEST] flat_damage before equip: %.2f" % d_before)
	var r: Dictionary = inv.call("equip", actor, weapon)
	print("[INV SELFTEST] equip %s -> %s (ok=%s)" % [
		str(weapon.get("name", "?")), str(r.get("slot", "?")), str(r.get("ok", false))])
	var d_after: float = _derived(ss, actor, "flat_damage")
	print("[INV SELFTEST] flat_damage after equip:  %.2f  (item damage=%s, delta=%.2f)" % [
		d_after, _fmt(float((weapon.get("stats", {}) as Dictionary).get("damage", 0.0))),
		d_after - d_before])
	inv.call("unequip", actor, "main_hand")
	var d_revert: float = _derived(ss, actor, "flat_damage")
	print("[INV SELFTEST] flat_damage after unequip: %.2f  (reverted=%s)" % [
		d_revert, str(absf(d_revert - d_before) < 0.01)])
	inv.call("equip", actor, weapon)  # put it back on for the screenshot

	# ---- fill the rest of the paperdoll ----
	_equip_demo(inv, actor, "chainmail_hauberk", "rare")
	_equip_demo(inv, actor, "hide_hood", "uncommon")
	_equip_demo(inv, actor, "studded_greaves", "uncommon")
	_equip_demo(inv, actor, "scout_boots", "uncommon")
	_equip_demo(inv, actor, "drakescale_round_shield", "")  # named rare, matte shield icon
	_equip_demo(inv, actor, "iron_signet", "uncommon")
	_equip_demo(inv, actor, "bone_ring", "uncommon")
	_equip_demo(inv, actor, "bone_totem", "rare")

	# ---- backpack spread (rarity + a proficiency denial to show red) ----
	inv.call("add_item", actor, _roll("kerbstone_greatblade", ""))   # named epic (purple)
	inv.call("add_item", actor, _roll("whitepelt_cloak", ""))        # named rare (blue)
	inv.call("add_item", actor, _roll("heavy_sabatons", "uncommon")) # plate -> warrior DENIED (red)
	inv.call("add_item", actor, _roll("copper_band", "common"))      # grey ring
	inv.call("add_item", actor, _roll("bent_dagger", "common"))      # grey dagger
	inv.call("add_item", actor, _roll("raven_charm", "uncommon"))    # green trinket

	print("[INV SELFTEST] gear_score after full kit: %d" % int(inv.call("gear_score", actor)))
	open()


func _equip_demo(inv: Node, actor: Object, item_id: String, rarity: String) -> void:
	var it: Dictionary = _roll(item_id, rarity)
	if it.is_empty():
		return
	var r: Dictionary = inv.call("equip", actor, it)
	if not bool(r.get("ok", false)):
		print("[INV SELFTEST] could not equip %s: %s" % [item_id, str(r.get("reason", ""))])


func _roll(item_id: String, rarity: String) -> Dictionary:
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null and ls.has_method("roll_item"):
		var it: Variant = ls.call("roll_item", item_id, rarity)
		if it is Dictionary:
			return it
	return {}


func _derived(ss: Node, actor: Object, name: String) -> float:
	if ss != null and ss.has_method("get_derived"):
		return float(ss.call("get_derived", actor, name))
	return 0.0
