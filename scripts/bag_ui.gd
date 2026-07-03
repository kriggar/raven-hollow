class_name BagUI
extends CanvasLayer
## WoW-style backpack for Raven Hollow: Emberfall — bottom-right anchored
## 4x5 grid of 24 px item slots on the dark aged-wood panel shared with
## hud.gd / dialogue_ui.gd (dark fill + Kenney panel_brown rim, gold Alagard
## title). Layer 9 (above HUD 8, below dialogue 10), group "bag_ui".
## Toggled by the "inventory" action (I); ui_cancel (Esc) closes.
##
## Reads the player's Inventory via the "player" group node's `inventory`
## property, null-safe: the grid stays empty until it exists. Refreshes on
## the inventory's bag_changed / equipment_changed signals.
##
## Drag & drop is a custom pixel-look drag (NOT Godot's OS drag) shared with
## the character sheet through Inventory.DragCtx static state. Each UI fully
## owns the drags it initiates (the pressed Control keeps Godot's mouse
## capture, so the initiator always sees the release):
##  - LMB press on an occupied slot lifts the item: DragCtx is set and a
##    ghost icon (modulate 0.8) follows the mouse on a layer-15 CanvasLayer
##    so it rides above both the bag and the character sheet panels.
##  - Release (watched in _input): over one of OUR bag slots -> Inventory
##    .swap_bag_slots; elsewhere -> offered to the paper-doll via the sheet's
##    try_drop(screen_pos) (which equips or flashes red); unclaimed -> cancel.
##    Either way we clear DragCtx and drop the ghost.
##  - Sheet-initiated drags ("equip" kind) are deliberately NOT claimed here:
##    the sheet's _end_drag already returns them to the bag, and claiming the
##    same release twice would double-resolve.
##  - Right-click auto-equips via Inventory.equip_from_bag(idx).

const GOLD := Color(0.85, 0.68, 0.35)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SLOT_BORDER_HOVER := Color(0.62, 0.48, 0.26)

const COLS: int = 4
const ROWS: int = 5
const SLOT: float = 24.0
const GAP: float = 3.0
const PAD: float = 12.0        # side/bottom inset, clear of the 9-patch rim
const GRID_TOP: float = 27.0   # title strip height
const PANEL_W: float = 129.0   # PAD*2 + COLS*SLOT + (COLS-1)*GAP
const PANEL_H: float = 171.0   # GRID_TOP + ROWS*SLOT + (ROWS-1)*GAP + PAD
const MARGIN: float = 8.0      # gap to the viewport edges

const DRAG_LAYER: int = 15     # ghost + tooltip: above both UIs (9), below class select (20)
const GHOST_SIZE: float = 20.0
const GHOST_ALPHA: float = 0.8
const DRAG_DIM: float = 0.35   # source-slot icon alpha while its item is lifted

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _panel: Control
## One Dictionary per bag index: {panel, rim, rim_sb, icon, sb_normal, sb_hover}.
var _slots: Array[Dictionary] = []
var _inv: Variant = null       # the player's Inventory (RefCounted), duck-typed
var _tooltip: ItemTooltip
var _drag_layer: CanvasLayer
var _ghost: TextureRect = null
var _drag_mine: bool = false
var _drag_src_idx: int = -1
var _hover_idx: int = -1
var _icon_cache: Dictionary = {}
var _open_tween: Tween


func _ready() -> void:
	layer = 9
	add_to_group("bag_ui")
	_build_panel()
	_drag_layer = CanvasLayer.new()
	_drag_layer.name = "BagDragLayer"
	_drag_layer.layer = DRAG_LAYER
	add_child(_drag_layer)
	_tooltip = ItemTooltip.new()
	_tooltip.name = "BagTooltip"
	_drag_layer.add_child(_tooltip)


func _process(_delta: float) -> void:
	_sync_inventory()
	_sync_drag()
	# Dialogue (layer 10) must read over everything: our tooltip rides the
	# layer-15 drag layer, so force it away while a conversation runs.
	if _tooltip.visible and _dialogue_open():
		_tooltip.hide_tip()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open():
		return  # I (and Esc-close) are inert mid-conversation
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		# Not marked handled: an open character sheet closes on the same Esc.
		close()


## Global LMB-release watcher for OUR drags (the sheet owns its own — see the
## class comment): resolves over a bag slot, otherwise offers the drop to the
## paper-doll, otherwise cancels. Runs in _input because the release is
## delivered to whichever Control captured the press, not necessarily to the
## slot under the mouse.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	if not _drag_mine or Inventory.DragCtx.item == null:
		return
	var target: int = _slot_under_mouse()
	if target >= 0:
		_resolve_drop(target)
		return
	var sheet: Node = get_tree().get_first_node_in_group("sheet_ui")
	if sheet != null and sheet.has_method("try_drop"):
		sheet.call("try_drop", _mouse_pos())  # consumes drops on equip slots
	_clear_dragctx()
	_end_my_drag()


# --- open / close ------------------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	is_open = true
	_sync_inventory()
	_refresh()
	_panel.visible = true
	_panel.pivot_offset = _panel.size  # scale in from the anchored corner
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.scale = Vector2(0.88, 0.88)
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.visible = false
	_panel.scale = Vector2.ONE
	_panel.modulate = Color.WHITE
	if _drag_mine:
		_clear_dragctx()
		_end_my_drag()
	_tooltip.hide_tip()
	if _hover_idx >= 0 and _hover_idx < _slots.size():
		var slot: Dictionary = _slots[_hover_idx]
		(slot["panel"] as Panel).add_theme_stylebox_override("panel", slot["sb_normal"])
	_hover_idx = -1


# --- inventory hookup --------------------------------------------------------

func _sync_inventory() -> void:
	var inv: Variant = null
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var inv_v: Variant = player.get("inventory")
		if inv_v is Object and is_instance_valid(inv_v):
			inv = inv_v
	if inv == _inv:
		return
	_disconnect_inv()
	_inv = inv
	if _inv != null:
		_inv.bag_changed.connect(_refresh)
		_inv.equipment_changed.connect(_refresh)
	_refresh()


func _disconnect_inv() -> void:
	if _inv == null or not is_instance_valid(_inv):
		return
	if _inv.bag_changed.is_connected(_refresh):
		_inv.bag_changed.disconnect(_refresh)
	if _inv.equipment_changed.is_connected(_refresh):
		_inv.equipment_changed.disconnect(_refresh)


func _refresh() -> void:
	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var icon: TextureRect = slot["icon"]
		var rim: Panel = slot["rim"]
		var item: Variant = _bag_item(i)
		if item is Dictionary:
			var dim: bool = _drag_mine and i == _drag_src_idx
			var alpha: float = DRAG_DIM if dim else 1.0
			icon.texture = _icon_for(item)
			icon.modulate = Color(1.0, 1.0, 1.0, alpha)
			var rim_sb: StyleBoxFlat = slot["rim_sb"]
			rim_sb.border_color = ItemTooltip.rarity_color(str(item.get("rarity", "common")))
			rim.modulate = Color(1.0, 1.0, 1.0, alpha)
			rim.visible = true
		else:
			icon.texture = null
			rim.visible = false
	if _hover_idx >= 0:
		_update_tooltip_for(_hover_idx)


# --- slot interaction --------------------------------------------------------

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if _dialogue_open():
		return  # no drags / right-click equips under an open conversation
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_try_begin_drag(idx)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_auto_equip(idx)


func _on_slot_entered(idx: int) -> void:
	_hover_idx = idx
	var slot: Dictionary = _slots[idx]
	(slot["panel"] as Panel).add_theme_stylebox_override("panel", slot["sb_hover"])
	_update_tooltip_for(idx)


func _on_slot_exited(idx: int) -> void:
	var slot: Dictionary = _slots[idx]
	(slot["panel"] as Panel).add_theme_stylebox_override("panel", slot["sb_normal"])
	if _hover_idx == idx:
		_hover_idx = -1
		_tooltip.hide_tip()


func _update_tooltip_for(idx: int) -> void:
	var item: Variant = _bag_item(idx)
	if item is Dictionary and is_open and Inventory.DragCtx.item == null \
			and not _dialogue_open():
		_tooltip.show_item(item, _mouse_pos())
	else:
		_tooltip.hide_tip()


func _auto_equip(idx: int) -> void:
	if _inv == null or Inventory.DragCtx.item != null:
		return
	if _bag_item(idx) == null:
		return
	_inv.equip_from_bag(idx, "")


# --- drag & drop -------------------------------------------------------------

func _try_begin_drag(idx: int) -> void:
	if _inv == null or Inventory.DragCtx.item != null:
		return
	var item: Variant = _bag_item(idx)
	if not (item is Dictionary):
		return
	Inventory.DragCtx.item = item
	Inventory.DragCtx.from_kind = "bag"
	Inventory.DragCtx.from_key = idx
	_drag_mine = true
	_drag_src_idx = idx

	_ghost = TextureRect.new()
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.stretch_mode = TextureRect.STRETCH_SCALE
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.texture = _icon_for(item)
	_ghost.size = Vector2(GHOST_SIZE, GHOST_SIZE)
	_ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	_drag_layer.add_child(_ghost)
	_ghost.position = (_mouse_pos() - Vector2(GHOST_SIZE, GHOST_SIZE) * 0.5).floor()

	_tooltip.hide_tip()
	_refresh()


## Per-frame drag upkeep: ghost follows the mouse; the ghost and the source
## dim are dropped as soon as DragCtx stops describing OUR drag (resolved by
## us, resolved by the character sheet, or cancelled). A button-up seen with
## the ctx still ours means the release event never reached us — cancel.
func _sync_drag() -> void:
	if not _drag_mine:
		return
	var key_v: Variant = Inventory.DragCtx.from_key
	var still_mine: bool = Inventory.DragCtx.item != null \
		and Inventory.DragCtx.from_kind == "bag" \
		and key_v is int and int(key_v) == _drag_src_idx
	if not still_mine:
		_end_my_drag()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_clear_dragctx()
		_end_my_drag()
		return
	if _ghost != null:
		_ghost.position = (_mouse_pos() - Vector2(GHOST_SIZE, GHOST_SIZE) * 0.5).floor()


## Drops OUR lifted item onto bag slot t (move onto empty / swap with the
## occupant — swap_bag_slots handles both).
func _resolve_drop(t: int) -> void:
	var key_v: Variant = Inventory.DragCtx.from_key
	_clear_dragctx()
	if _inv != null and key_v is int:
		_inv.swap_bag_slots(int(key_v), t)
	_end_my_drag()
	# The mouse now rests on slot t and mouse_entered will not re-fire.
	if _slot_under_mouse() == t:
		_hover_idx = t
		_update_tooltip_for(t)


func _clear_dragctx() -> void:
	Inventory.DragCtx.item = null
	Inventory.DragCtx.from_kind = ""
	Inventory.DragCtx.from_key = null


func _end_my_drag() -> void:
	_drag_mine = false
	_drag_src_idx = -1
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_refresh()


# --- construction ------------------------------------------------------------

func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "BagPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -MARGIN - PANEL_W
	_panel.offset_right = -MARGIN
	_panel.offset_top = -MARGIN - PANEL_H
	_panel.offset_bottom = -MARGIN
	add_child(_panel)

	# Dark fill inset under the aged-wood rim (same recipe as the HUD plate).
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(PANEL_W - 6.0, PANEL_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.set_border_width_all(0)
	fill_sb.set_corner_radius_all(0)
	fill.add_theme_stylebox_override("panel", fill_sb)
	_panel.add_child(fill)

	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = _panel_tex
	frame.draw_center = false
	frame.patch_margin_left = 10
	frame.patch_margin_right = 10
	frame.patch_margin_top = 10
	frame.patch_margin_bottom = 10
	frame.modulate = FRAME_TINT
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(frame)

	var title := Label.new()
	title.name = "Title"
	title.text = "Backpack"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 8.0)
	title.size = Vector2(PANEL_W, 14.0)
	_panel.add_child(title)

	for r in range(ROWS):
		for c in range(COLS):
			var idx: int = r * COLS + c
			var pos := Vector2(PAD + float(c) * (SLOT + GAP), GRID_TOP + float(r) * (SLOT + GAP))
			_build_slot(idx, pos)


func _build_slot(idx: int, pos: Vector2) -> void:
	var panel := Panel.new()
	panel.name = "BagSlot%d" % idx
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = pos
	panel.size = Vector2(SLOT, SLOT)
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = SLOT_BG
	sb_normal.border_color = SLOT_BORDER
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(0)
	var sb_hover: StyleBoxFlat = sb_normal.duplicate() as StyleBoxFlat
	sb_hover.border_color = SLOT_BORDER_HOVER
	panel.add_theme_stylebox_override("panel", sb_normal)
	_panel.add_child(panel)

	# 1 px rarity ring drawn around the icon while the slot is occupied.
	var rim := Panel.new()
	rim.name = "RarityRim"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.position = Vector2(2.0, 2.0)
	rim.size = Vector2(SLOT - 4.0, SLOT - 4.0)
	var rim_sb := StyleBoxFlat.new()
	rim_sb.draw_center = false
	rim_sb.set_border_width_all(1)
	rim_sb.set_corner_radius_all(0)
	rim.add_theme_stylebox_override("panel", rim_sb)
	rim.visible = false
	panel.add_child(rim)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(3.0, 3.0)
	icon.size = Vector2(SLOT - 6.0, SLOT - 6.0)
	panel.add_child(icon)

	panel.gui_input.connect(_on_slot_gui_input.bind(idx))
	panel.mouse_entered.connect(_on_slot_entered.bind(idx))
	panel.mouse_exited.connect(_on_slot_exited.bind(idx))

	_slots.append({
		"panel": panel,
		"rim": rim,
		"rim_sb": rim_sb,
		"icon": icon,
		"sb_normal": sb_normal,
		"sb_hover": sb_hover,
	})


# --- helpers -----------------------------------------------------------------

func _bag_item(i: int) -> Variant:
	if _inv == null:
		return null
	var bag_v: Variant = _inv.bag
	if not (bag_v is Array):
		return null
	var bag: Array = bag_v
	if i < 0 or i >= bag.size():
		return null
	var item: Variant = bag[i]
	return item if item is Dictionary else null


func _slot_under_mouse() -> int:
	return bag_slot_at(_mouse_pos())


## Public hit-test (used by CharacterSheetUI to route equip->bag drops onto
## the exact slot under the cursor): bag slot index at a canvas-space point,
## -1 when the bag is closed or the point misses every slot.
func bag_slot_at(screen_pos: Vector2) -> int:
	if not is_open or _panel == null or not _panel.visible:
		return -1
	for i in range(_slots.size()):
		var panel: Panel = _slots[i]["panel"]
		if panel.get_global_rect().has_point(screen_pos):
			return i
	return -1


func _dialogue_open() -> bool:
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	return dlg != null and dlg.get("is_open") == true


func _icon_for(item: Dictionary) -> Texture2D:
	var path: String = str(item.get("icon", ""))
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		tex = load(path)
	_icon_cache[path] = tex
	return tex


func _mouse_pos() -> Vector2:
	return get_viewport().get_mouse_position()
