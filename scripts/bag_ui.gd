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
##
## WoW bag button (Phase B.2): a 34x34 dark slot button pinned to the
## bottom-right viewport corner with the Shikashi pixel backpack icon and an
## "I" keybind caption. Always visible during gameplay (player exists with a
## chosen class), hidden while class-select runs (no player yet) or a
## dialogue is open. Click toggles the bag exactly like the I key; hovering
## (or the bag being open) lights the border gold with a soft glow. The bag
## panel now opens ABOVE the button so the two never overlap.
##
## Item icons: legacy "res://..." paths load directly; "pixel:<id>" ids are
## resolved through IconsPixel (scripts/icons_pixel.gd), loaded dynamically
## so this file parses standalone.

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

# WoW corner bag button.
const BTN_SIZE: float = 34.0
const BTN_GAP: float = 4.0         # vertical gap between the button and the open bag
const BTN_ICON_SIZE: float = 26.0
const BTN_GLOW := Color(0.85, 0.68, 0.35, 0.30)
const BTN_ICON_HOVER := Color(1.15, 1.12, 1.05)
## Button icon: the IconsPixel "backpack" registry entry (Shikashi v2 knapsack,
## cell col 0 row 10) — resolved through _pixel_icon like every item icon, so
## the registry stays the single source of truth for pixel iconography.
const BTN_ICON_ID := "backpack"

# "pixel:<id>" item icons resolve through IconsPixel, loaded dynamically so
# this script parses even before/without scripts/icons_pixel.gd.
const PIXEL_PREFIX := "pixel:"
const ICONS_PIXEL_PATH := "res://scripts/icons_pixel.gd"

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

var _bag_button: Panel
var _btn_icon: TextureRect
var _btn_sb_normal: StyleBoxFlat
var _btn_sb_hover: StyleBoxFlat
var _btn_hovered: bool = false
var _btn_press_tween: Tween

static var _pixel_script: GDScript = null


func _ready() -> void:
	layer = 9
	add_to_group("bag_ui")
	_build_panel()
	_build_bag_button()
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
	_update_button_state()
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
		var count_label: Label = slot["count"]
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
			var n: int = Crafting.stack_count(item)
			if n > 1:
				count_label.text = str(n)
				count_label.modulate = Color(1.0, 1.0, 1.0, alpha)
				count_label.visible = true
			else:
				count_label.visible = false
		else:
			icon.texture = null
			rim.visible = false
			count_label.visible = false
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
		_on_slot_right_click(idx)


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


## Right-click routing (Phase C item types). Consumables are USED, recipe
## scrolls are LEARNED, and the quest 3 wrapped dagger is buried at the
## witness-stone; everything else (equipment, plain quest junk, materials —
## all slot "none" for the last two) falls through to the existing auto-equip,
## which no-ops non-equippable items exactly as before. The Crafting hooks
## mutate the bag and emit inv.bag_changed, so _refresh repaints on its own.
func _on_slot_right_click(idx: int) -> void:
	if _inv == null or Inventory.DragCtx.item != null:
		return
	var it_v: Variant = _bag_item(idx)
	if it_v is Dictionary:
		var item: Dictionary = it_v
		var kind: String = str(item.get("type", ""))
		if kind == "consumable":
			Crafting.use_consumable(
				get_tree().get_first_node_in_group("player"), _inv, idx)
			return
		if kind == "recipe":
			var rid: String = Crafting.learn_from_scroll(_inv, idx)
			var cui: Node = get_tree().get_first_node_in_group("crafting_ui")
			if cui != null:
				var msg: String = ("Recipe learned: %s" % Crafting.recipe_name(rid)) \
					if rid != "" else "Already known."
				cui.call("show_toast", msg, GOLD)
			return
		if str(item.get("id", "")) == "weeping_dagger" and _try_bury_dagger(idx):
			return
	_auto_equip(idx)


## Quest 3 burial: reports a use_item for the wrapped dagger to Quests (which
## only consumes it while the player stands at the witness-stone with q3_bury
## active). On consume, the dagger leaves the bag. Returns true only when the
## quest actually took it — otherwise the item stays and falls through to the
## no-op auto-equip.
func _try_bury_dagger(idx: int) -> bool:
	var quests: Node = get_tree().get_first_node_in_group("quests")
	if quests == null or not quests.has_method("report_use_item"):
		return false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	var pos: Vector2 = Vector2.ZERO
	var pos_v: Variant = player.get("global_position")
	if pos_v is Vector2:
		pos = pos_v
	var map_id: String = "town"
	var root: Node = get_tree().current_scene
	if root != null:
		var mid_v: Variant = root.get("current_map_id")
		if mid_v is String and mid_v != "":
			map_id = mid_v
	if quests.call("report_use_item", "weeping_dagger", map_id, pos) != true:
		return false
	if _inv != null and idx >= 0 and idx < _inv.bag.size():
		_inv.bag[idx] = null
		_inv.bag_changed.emit()
	return true


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
	# Lifted clear of the corner bag button: the bag opens ABOVE it, WoW-style.
	_panel.offset_top = -MARGIN - BTN_SIZE - BTN_GAP - PANEL_H
	_panel.offset_bottom = -MARGIN - BTN_SIZE - BTN_GAP
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

	# Stack-count caption (bottom-right, WoW-style) — shown only for stacked
	# materials/consumables (Crafting.stack_count > 1); hidden on gear.
	var count := Label.new()
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_override("font", _font)
	count.add_theme_font_size_override("font_size", 8)
	count.add_theme_color_override("font_color", GOLD)
	count.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	count.add_theme_constant_override("outline_size", 2)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.position = Vector2(1.0, SLOT - 12.0)
	count.size = Vector2(SLOT - 3.0, 11.0)
	count.visible = false
	panel.add_child(count)

	panel.gui_input.connect(_on_slot_gui_input.bind(idx))
	panel.mouse_entered.connect(_on_slot_entered.bind(idx))
	panel.mouse_exited.connect(_on_slot_exited.bind(idx))

	_slots.append({
		"panel": panel,
		"rim": rim,
		"rim_sb": rim_sb,
		"icon": icon,
		"count": count,
		"sb_normal": sb_normal,
		"sb_hover": sb_hover,
	})


# --- WoW corner bag button -----------------------------------------------------

func _build_bag_button() -> void:
	_bag_button = Panel.new()
	_bag_button.name = "BagButton"
	_bag_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_button.anchor_left = 1.0
	_bag_button.anchor_right = 1.0
	_bag_button.anchor_top = 1.0
	_bag_button.anchor_bottom = 1.0
	_bag_button.offset_left = -MARGIN - BTN_SIZE
	_bag_button.offset_right = -MARGIN
	_bag_button.offset_top = -MARGIN - BTN_SIZE
	_bag_button.offset_bottom = -MARGIN
	_bag_button.pivot_offset = Vector2(BTN_SIZE, BTN_SIZE) * 0.5
	_bag_button.visible = false  # _update_button_state shows it once gameplay runs

	# Dark WoW-slot frame; the hover/open variant lights the border gold and
	# adds a soft glow halo (StyleBox shadow with zero offset).
	_btn_sb_normal = StyleBoxFlat.new()
	_btn_sb_normal.bg_color = SLOT_BG
	_btn_sb_normal.border_color = SLOT_BORDER
	_btn_sb_normal.set_border_width_all(2)
	_btn_sb_normal.set_corner_radius_all(0)
	_btn_sb_hover = _btn_sb_normal.duplicate() as StyleBoxFlat
	_btn_sb_hover.border_color = SLOT_BORDER_HOVER
	_btn_sb_hover.shadow_color = BTN_GLOW
	_btn_sb_hover.shadow_size = 4
	_btn_sb_hover.shadow_offset = Vector2.ZERO
	_bag_button.add_theme_stylebox_override("panel", _btn_sb_normal)
	add_child(_bag_button)

	_btn_icon = TextureRect.new()
	_btn_icon.name = "Icon"
	_btn_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_btn_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_btn_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_btn_icon.texture = _pixel_icon(BTN_ICON_ID)
	_btn_icon.position = Vector2.ONE * (BTN_SIZE - BTN_ICON_SIZE) * 0.5
	_btn_icon.size = Vector2(BTN_ICON_SIZE, BTN_ICON_SIZE)
	_bag_button.add_child(_btn_icon)

	# Small "I" keybind caption, WoW-style in the top-right of the slot.
	var key := Label.new()
	key.name = "Keybind"
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_font_override("font", _font)
	key.add_theme_font_size_override("font_size", 8)
	key.add_theme_color_override("font_color", GOLD)
	key.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	key.add_theme_constant_override("outline_size", 2)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.text = "I"
	key.position = Vector2(BTN_SIZE - 12.0, 1.0)
	_bag_button.add_child(key)
	key.set_deferred("size", Vector2(9.0, 9.0))

	_bag_button.gui_input.connect(_on_button_gui_input)
	_bag_button.mouse_entered.connect(_on_button_entered)
	_bag_button.mouse_exited.connect(_on_button_exited)


func _on_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_bag_button.accept_event()
	toggle()
	# Quick press-punch, WoW button feel.
	if _btn_press_tween != null and _btn_press_tween.is_valid():
		_btn_press_tween.kill()
	_bag_button.scale = Vector2(0.9, 0.9)
	_btn_press_tween = create_tween()
	_btn_press_tween.tween_property(_bag_button, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_button_entered() -> void:
	_btn_hovered = true


func _on_button_exited() -> void:
	_btn_hovered = false


## Per-frame button upkeep: shown only during actual gameplay (a player with a
## chosen class exists — class-select has no player yet) and never under an
## open dialogue; border/glow lights up on hover or while the bag is open.
func _update_button_state() -> void:
	if _bag_button == null:
		return
	var show_btn: bool = _gameplay_active() and not _dialogue_open()
	if _bag_button.visible != show_btn:
		_bag_button.visible = show_btn
		if not show_btn:
			_btn_hovered = false
	if not show_btn:
		return
	var lit: bool = _btn_hovered or is_open
	_bag_button.add_theme_stylebox_override(
		"panel", _btn_sb_hover if lit else _btn_sb_normal)
	_btn_icon.modulate = BTN_ICON_HOVER if lit else Color.WHITE


func _gameplay_active() -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	var cd_v: Variant = player.get("class_def")
	return cd_v is Dictionary and not (cd_v as Dictionary).is_empty()


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
	if path.begins_with(PIXEL_PREFIX):
		var pid: String = path.substr(PIXEL_PREFIX.length())
		tex = _pixel_icon(pid)
		if tex == null:
			# Crafting-owned ids (materials / consumables / recipe scrolls /
			# crafted gear) are not in IconsPixel.REGISTRY yet; Crafting serves
			# their Shikashi cells as a fallback so they aren't blank in the bag.
			tex = Crafting.icon_texture(pid)
	elif ResourceLoader.exists(path, "Texture2D"):
		tex = load(path)
	_icon_cache[path] = tex
	return tex


## Resolves a Shikashi pixel icon id through IconsPixel.get_tex(). The script
## is loaded on demand (not a compile-time reference) so bag_ui.gd parses on
## its own; a missing script or unknown id degrades to null (empty slot look).
static func _pixel_icon(icon_id: String) -> Texture2D:
	if _pixel_script == null:
		if not ResourceLoader.exists(ICONS_PIXEL_PATH, "Script"):
			return null
		_pixel_script = load(ICONS_PIXEL_PATH) as GDScript
	if _pixel_script == null:
		return null
	var tex_v: Variant = _pixel_script.call("get_tex", icon_id)
	return tex_v if tex_v is Texture2D else null


func _mouse_pos() -> Vector2:
	return get_viewport().get_mouse_position()
