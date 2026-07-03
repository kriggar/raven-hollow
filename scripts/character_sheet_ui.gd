class_name CharacterSheetUI
extends CanvasLayer
## WoW-style paper-doll character sheet for Raven Hollow: Emberfall (Phase B).
## Built entirely in code. Layer 9 (above HUD 8, below dialogue 10), group
## "sheet_ui". Toggled by the "character_sheet" action (C); Esc also closes
## (deliberately NOT consumed so an open bag closes on the same press).
##
## Left-anchored aged-wood panel per the user-approved spec: the player's
## animated class preview (SheetAnim idle_down, scale 3) stands center on a
## dark inset stage with a pulsing warm radial glow; 26 px equipment slots
## surround it (left column Head/Chest/Legs/Boots, right column Main Hand/
## Off Hand/Ring 1/Ring 2/Trinket) with engraved Alagard labels, rarity
## borders + painterly icons when filled; a live six-stat strip (Damage/
## Armor/HP/Mana/Speed/Crit from Inventory.stat_totals()) runs along the
## bottom and refreshes on equipment_changed.
##
## Drag interop (shared state = Inventory.DragCtx; custom pixel drag, NOT the
## OS drag system):
##  - Drags STARTED here (LMB press on a filled slot) are resolved here on
##    release, because Godot routes the release to the pressed Control:
##    another equip slot = move/swap via the Inventory API, anywhere outside
##    the panel = back to the bag (unequip_to_bag), an invalid slot flashes
##    its border red for 0.2 s, the panel background cancels.
##  - Drags started in the bag are released inside BagUI, which should call
##    try_drop(screen_pos) (alias handle_drop) here — returns true when the
##    drop landed on a paper-doll slot (equipped or invalid-flashed) — or do
##    its own hit test via equip_slot_at(screen_pos) (alias
##    slot_at_screen_pos) + flash_invalid(slot_name). The drag INITIATOR owns
##    DragCtx cleanup and its own ghost icon.
##  - Right-click on a filled slot = unequip straight to the bag.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const BOX_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const SLOT_BG := Color(0.07, 0.055, 0.045, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const ENGRAVE := Color(0.52, 0.42, 0.28)
const ENGRAVE_SHADOW := Color(0.02, 0.015, 0.01, 0.85)
const INVALID_RED := Color(0.85, 0.2, 0.15)
const STAGE_BG := Color(0.05, 0.04, 0.03)
const STAGE_BORDER := Color(0.24, 0.17, 0.10)
const GLOW_WARM := Color(1.0, 0.72, 0.38)
const DIM_VALUE := Color(0.5, 0.47, 0.4)
const STRIP_BG := Color(0.06, 0.05, 0.04, 0.9)

const PANEL_W: float = 200.0
const PANEL_H: float = 264.0
const PANEL_LIFT: float = 16.0  # raised above v-center so the HUD plate (y 298+) stays clear
const PAD: float = 8.0
const SLOT: float = 26.0
const SLOT_PITCH: float = 40.0
const LABEL_H: float = 10.0
const COLS_Y: float = 26.0
const STAGE_X: float = 44.0
const STAGE_W: float = 112.0
const STAGE_H: float = 196.0
const STATS_Y: float = 228.0
const STATS_H: float = 28.0
const FLASH_TIME: float = 0.2
const GHOST_SIZE: float = 24.0

# "pixel:<id>" item icons resolve through IconsPixel (Shikashi sheets); the
# script is loaded dynamically so this file parses standalone.
const PIXEL_PREFIX := "pixel:"
const ICONS_PIXEL_PATH := "res://scripts/icons_pixel.gd"

const LEFT_SLOTS: Array[String] = ["head", "chest", "legs", "boots"]
const RIGHT_SLOTS: Array[String] = ["main_hand", "off_hand", "ring1", "ring2", "trinket"]
const SLOT_LABELS := {
	"head": "Head",
	"chest": "Chest",
	"legs": "Legs",
	"boots": "Boots",
	"main_hand": "Main Hand",
	"off_hand": "Off Hand",
	"ring1": "Ring 1",
	"ring2": "Ring 2",
	"trinket": "Trinket",
}

const STAT_KEYS: Array[String] = ["damage", "armor", "hp", "mana", "speed_pct", "crit_pct"]
const STAT_LABELS: Array[String] = ["DMG", "ARM", "HP", "MP", "SPD", "CRIT"]
const STAT_COLORS: Array[Color] = [
	Color(0.85, 0.3, 0.2),   # damage — ember red
	Color(0.55, 0.62, 0.72), # armor — steel
	Color(0.75, 0.2, 0.2),   # hp — blood
	Color(0.3, 0.45, 0.8),   # mana — deep blue
	Color(0.5, 0.75, 0.35),  # speed — green
	Color(0.85, 0.68, 0.35), # crit — gold
]

## Subtle preview tints per equipped-chest rarity (spec: leather warm, iron
## cool, legendary faint gold). Must not break the muted palette.
const CHEST_TINTS := {
	"common": Color(1.04, 0.99, 0.92),
	"uncommon": Color(0.98, 1.04, 0.94),
	"rare": Color(0.93, 0.97, 1.06),
	"epic": Color(1.0, 0.94, 1.06),
	"legendary": Color(1.08, 1.01, 0.88),
}

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _root: Control
var _panel: Control
var _title: Label
var _stage: Panel
var _glow: TextureRect
var _preview: AnimatedSprite2D
var _preview_weapon: Sprite2D
var _preview_key: String = ""
var _tooltip: ItemTooltip
var _ghost: TextureRect
## slot_name -> {panel: Panel, sb: StyleBoxFlat, icon: TextureRect, label: Label}
var _slots: Dictionary = {}
var _stat_values: Array[Label] = []
var _inv: Inventory = null
var _drag_from: String = ""
var _open_tween: Tween
var _flash_tweens: Dictionary = {}
var _placeholders: Dictionary = {}

static var _pixel_script: GDScript = null


func _ready() -> void:
	layer = 9
	add_to_group("sheet_ui")

	_root = Control.new()
	_root.name = "SheetRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	_build_panel()
	_build_slots()
	_build_stage()
	_build_stats_strip()

	_tooltip = ItemTooltip.new()
	_tooltip.name = "SheetTooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tooltip)

	_ghost = TextureRect.new()
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.stretch_mode = TextureRect.STRETCH_SCALE
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.size = Vector2(GHOST_SIZE, GHOST_SIZE)
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.8)
	_ghost.visible = false
	_root.add_child(_ghost)

	# Slow candle-like breathing on the stage glow.
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_glow, "modulate:a", 0.7, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_glow, "modulate:a", 1.0, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(_delta: float) -> void:
	_sync_inventory()
	if not is_open:
		return
	_sync_preview()
	if _drag_from != "":
		var mouse: Vector2 = _root.get_global_mouse_position()
		_ghost.position = mouse - _ghost.size * 0.5
		if Inventory.DragCtx.item == null:
			_cancel_drag()  # someone else cleared the drag context
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag(mouse)  # release slipped past the slot (e.g. off-window)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open():
		return  # C (and Esc-close) are inert mid-conversation
	if event.is_action_pressed("character_sheet"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()  # not consumed on purpose: the bag closes on the same Esc


# --- public API --------------------------------------------------------------


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh_all()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_root.visible = true
	_panel.pivot_offset = Vector2(PANEL_W, PANEL_H) * 0.5
	_panel.scale = Vector2(0.92, 0.92)
	_panel.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_cancel_drag()
	_tooltip.hide_tip()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.tween_property(_panel, "modulate:a", 0.0, 0.1)
	_open_tween.tween_callback(func() -> void:
		if not is_open:
			_root.visible = false
	)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Hit-test helper for BagUI: equip slot name at a canvas-space position, or
## "" when the sheet is closed / the point is not over a slot.
func equip_slot_at(screen_pos: Vector2) -> String:
	if not is_open:
		return ""
	return _slot_name_at(screen_pos)


## Alias of equip_slot_at (name-compatibility for the bag's drop resolution).
func slot_at_screen_pos(screen_pos: Vector2) -> String:
	return equip_slot_at(screen_pos)


## Resolves the ACTIVE Inventory.DragCtx drag at screen_pos against the
## paper-doll. Returns true when the position hit an equip slot (the drop is
## consumed: item equipped, or the slot flashed red if invalid); false when
## the sheet is closed or the point is elsewhere. The caller (drag initiator)
## keeps ownership of DragCtx cleanup and its ghost icon.
func try_drop(screen_pos: Vector2) -> bool:
	if not is_open or _inv == null:
		return false
	var slot_name: String = _slot_name_at(screen_pos)
	if slot_name == "":
		return false
	var item_v: Variant = Inventory.DragCtx.item
	if not (item_v is Dictionary):
		return false
	if not Inventory.slot_accepts(slot_name, item_v):
		flash_invalid(slot_name)
		return true
	var from_kind: String = Inventory.DragCtx.from_kind
	if from_kind == "bag":
		var idx: int = -1
		if typeof(Inventory.DragCtx.from_key) == TYPE_INT:
			idx = int(Inventory.DragCtx.from_key)
		if idx < 0 or not _inv.equip_from_bag(idx, slot_name):
			flash_invalid(slot_name)
		return true
	if from_kind == "equip":
		var from_slot: String = str(Inventory.DragCtx.from_key)
		if from_slot != slot_name and not _move_equip_to_equip(from_slot, slot_name):
			flash_invalid(slot_name)
		return true
	return false


## Alias of try_drop (name-compatibility for the bag's drop resolution).
func handle_drop(screen_pos: Vector2) -> bool:
	return try_drop(screen_pos)


## Flashes a slot's border red for FLASH_TIME (invalid drop feedback).
func flash_invalid(slot_name: String) -> void:
	if not _slots.has(slot_name):
		return
	var sb: StyleBoxFlat = _slots[slot_name]["sb"]
	var old_v: Variant = _flash_tweens.get(slot_name)
	if old_v is Tween and (old_v as Tween).is_valid():
		(old_v as Tween).kill()
	sb.border_color = INVALID_RED
	var tw: Tween = create_tween()
	tw.tween_interval(FLASH_TIME)
	tw.tween_callback(_apply_slot_visual.bind(slot_name))
	_flash_tweens[slot_name] = tw


# --- inventory binding -------------------------------------------------------


func _sync_inventory() -> void:
	var inv: Inventory = null
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var inv_v: Variant = player.get("inventory")
		if inv_v is Inventory:
			inv = inv_v
	if inv == _inv:
		return
	if _inv != null and _inv.equipment_changed.is_connected(_on_equipment_changed):
		_inv.equipment_changed.disconnect(_on_equipment_changed)
	_inv = inv
	if _inv != null:
		_inv.equipment_changed.connect(_on_equipment_changed)
	_refresh_all()


func _on_equipment_changed() -> void:
	_refresh_all()


# --- refresh -----------------------------------------------------------------


func _refresh_all() -> void:
	_refresh_title()
	for slot_name: String in _slots:
		_apply_slot_visual(slot_name)
	_refresh_stats()
	_sync_preview()
	_apply_preview_tint()
	_refresh_preview_weapon()


func _refresh_title() -> void:
	var title_text: String = "Character"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var cd_v: Variant = player.get("class_def")
		if cd_v is Dictionary and not (cd_v as Dictionary).is_empty():
			title_text = str((cd_v as Dictionary).get("name", "Character"))
	_title.text = title_text


func _apply_slot_visual(slot_name: String) -> void:
	var entry: Dictionary = _slots[slot_name]
	var sb: StyleBoxFlat = entry["sb"]
	var icon: TextureRect = entry["icon"]
	var item_v: Variant = null
	if _inv != null:
		item_v = _inv.equipped.get(slot_name)
	if item_v is Dictionary:
		var item: Dictionary = item_v
		var rc: Color = Items.rarity_color(str(item.get("rarity", "common")))
		icon.texture = _icon_or_placeholder(item)
		icon.visible = true
		sb.border_color = rc
		sb.bg_color = SLOT_BG.lerp(rc, 0.10)
	else:
		icon.texture = null
		icon.visible = false
		sb.border_color = SLOT_BORDER
		sb.bg_color = SLOT_BG
	icon.modulate = Color(1.0, 1.0, 1.0, 0.35) if _drag_from == slot_name else Color.WHITE


func _refresh_stats() -> void:
	var totals: Dictionary = {}
	if _inv != null:
		totals = _inv.stat_totals()
	for i in range(STAT_KEYS.size()):
		var raw: float = 0.0
		var raw_v: Variant = totals.get(STAT_KEYS[i])
		if typeof(raw_v) == TYPE_FLOAT or typeof(raw_v) == TYPE_INT:
			raw = float(raw_v)
		var value_label: Label = _stat_values[i]
		value_label.text = _stat_text(STAT_KEYS[i], raw)
		value_label.add_theme_color_override(
				"font_color", PARCHMENT if absf(raw) > 0.001 else DIM_VALUE)


func _stat_text(key: String, raw: float) -> String:
	var v: int = int(roundf(raw))
	if key.ends_with("_pct"):
		return ("+%d%%" % v) if v > 0 else ("%d%%" % v)
	return ("+%d" % v) if v > 0 else str(v)


func _sync_preview() -> void:
	var class_def: Dictionary = {}
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		var cd_v: Variant = player.get("class_def")
		if cd_v is Dictionary:
			class_def = cd_v
	if class_def.is_empty():
		_preview.visible = false
		_glow.visible = false
		_preview_key = ""
		return
	var sheet: String = str(class_def.get("sheet", "res://assets/art/characters/npc_male1.png"))
	if not sheet.begins_with("res://"):
		sheet = "res://assets/art/characters/npc_%s.png" % sheet
	var variant: int = int(class_def.get("variant", 0))
	var key: String = "%s#%d" % [sheet, variant]
	if key != _preview_key:
		_preview_key = key
		if ResourceLoader.exists(sheet, "Texture2D"):
			_preview.sprite_frames = SheetAnim.make_szadi_frames(sheet, variant)
			_preview.play(&"idle_down")
		else:
			_preview.sprite_frames = null
	_preview.visible = _preview.sprite_frames != null
	_glow.visible = _preview.visible


func _refresh_preview_weapon() -> void:
	## Mirrors the player's in-world weapon (same pc_wood.png crop, grip-point
	## origin and facing-down hand pose) on the paper-doll preview.
	if _preview_weapon == null:
		return
	var item_v: Variant = null
	if _inv != null:
		item_v = _inv.equipped.get("main_hand")
	if not (item_v is Dictionary) or not _preview.visible:
		_preview_weapon.visible = false
		return
	var cfg: Dictionary = Player.WEAPON_SHAPES[_preview_shape_for(item_v)]
	var reg: Rect2 = cfg["region"]
	var at := AtlasTexture.new()
	at.atlas = load(Player.WEAPON_SHEET)
	at.region = reg
	_preview_weapon.texture = at
	_preview_weapon.offset = Vector2(-reg.size.x * 0.5, -(reg.size.y - float(cfg["grip"])))
	_preview_weapon.scale = Vector2.ONE * float(cfg["scale"])
	# Player's facing-down hand pos (5,-10) is relative to a FEET-origin node
	# whose sprite draws lifted by FEET_OFFSET; our preview is frame-centered
	# with no offset, so shift by -FEET_OFFSET to keep the grip in the hand.
	_preview_weapon.position = Vector2(5.0, -10.0) - Player.FEET_OFFSET
	_preview_weapon.rotation = 0.42
	_preview_weapon.visible = true


func _preview_shape_for(item: Dictionary) -> String:
	## Keyword mapping kept in lockstep with Player._weapon_shape_for so the
	## doll always shows the same silhouette as the world sprite.
	var key: String = (str(item.get("id", "")) + " " + str(item.get("name", ""))).to_lower()
	if "bow" in key or "talon" in key:
		return "bow"
	if "staff" in key or "wand" in key or "rod" in key or "scepter" in key or "crook" in key:
		return "staff"
	if "dagger" in key or "knife" in key or "shiv" in key or "dirk" in key:
		return "dagger"
	return "sword"


func _apply_preview_tint() -> void:
	var tint: Color = Color.WHITE
	if _inv != null:
		var chest_v: Variant = _inv.equipped.get("chest")
		if chest_v is Dictionary:
			var rarity: String = str((chest_v as Dictionary).get("rarity", ""))
			tint = CHEST_TINTS.get(rarity, Color.WHITE)
	_preview.modulate = tint


# --- drag & drop -------------------------------------------------------------


func _on_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton):
		return
	if _dialogue_open():
		return  # no drags / right-click unequips under an open conversation
	var mb: InputEventMouseButton = event
	var panel: Panel = _slots[slot_name]["panel"]
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if _drag_from == "" and Inventory.DragCtx.item == null:
			if _begin_drag(slot_name):
				panel.accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _drag_from != "":
			_end_drag(panel.get_global_mouse_position())
			panel.accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if _drag_from == "" and Inventory.DragCtx.item == null and _inv != null:
			if _inv.equipped.get(slot_name) is Dictionary:
				_tooltip.hide_tip()
				if not _inv.unequip_to_bag(slot_name):
					flash_invalid(slot_name)  # bag is full
				panel.accept_event()


func _begin_drag(slot_name: String) -> bool:
	if _inv == null:
		return false
	var item_v: Variant = _inv.equipped.get(slot_name)
	if not (item_v is Dictionary):
		return false
	var item: Dictionary = item_v
	Inventory.DragCtx.item = item
	Inventory.DragCtx.from_kind = "equip"
	Inventory.DragCtx.from_key = slot_name
	_drag_from = slot_name
	_ghost.texture = _icon_or_placeholder(item)
	var mouse: Vector2 = _root.get_global_mouse_position()
	_ghost.position = mouse - _ghost.size * 0.5
	_ghost.visible = true
	_tooltip.hide_tip()
	_apply_slot_visual(slot_name)  # dims the picked-up icon
	return true


func _end_drag(screen_pos: Vector2) -> void:
	var from_slot: String = _drag_from
	_drag_from = ""
	_ghost.visible = false
	if Inventory.DragCtx.from_kind == "equip" and str(Inventory.DragCtx.from_key) == from_slot:
		Inventory.DragCtx.item = null
		Inventory.DragCtx.from_kind = ""
		Inventory.DragCtx.from_key = null
	if _inv == null:
		_refresh_all()
		return
	var target: String = _slot_name_at(screen_pos)
	var on_panel: bool = _panel.get_global_rect().has_point(screen_pos)
	if target == from_slot or (target == "" and on_panel):
		pass  # dropped back where it started / on the panel background: cancel
	elif target != "":
		var item_v: Variant = _inv.equipped.get(from_slot)
		if item_v is Dictionary and Inventory.slot_accepts(target, item_v):
			if not _move_equip_to_equip(from_slot, target):
				flash_invalid(target)
		else:
			flash_invalid(target)
	else:
		# Released outside the sheet: an exact bag slot under the cursor wins
		# (move there / swap in place); otherwise first-empty-slot fallback.
		var placed: bool = false
		var bag: Node = get_tree().get_first_node_in_group("bag_ui")
		if bag != null and bag.has_method("bag_slot_at"):
			var idx_v: Variant = bag.call("bag_slot_at", screen_pos)
			if idx_v is int and int(idx_v) >= 0:
				placed = _inv.unequip_to_bag_index(from_slot, int(idx_v))
		if not placed and not _inv.unequip_to_bag(from_slot):
			flash_invalid(from_slot)  # bag is full
	_refresh_all()


func _cancel_drag() -> void:
	if _drag_from == "":
		return
	var from_slot: String = _drag_from
	_drag_from = ""
	_ghost.visible = false
	if Inventory.DragCtx.from_kind == "equip" and str(Inventory.DragCtx.from_key) == from_slot:
		Inventory.DragCtx.item = null
		Inventory.DragCtx.from_kind = ""
		Inventory.DragCtx.from_key = null
	_apply_slot_visual(from_slot)


## Moves an equipped item between two paper-doll slots (e.g. Ring 1 -> Ring 2)
## through the bag, since the Inventory API has no direct slot-to-slot move.
## Never destroys the item: on a failed re-equip it lands back where it was
## (or stays safely in the bag).
func _move_equip_to_equip(from_slot: String, to_slot: String) -> bool:
	if _inv == null:
		return false
	var item_v: Variant = _inv.equipped.get(from_slot)
	if not (item_v is Dictionary):
		return false
	if not Inventory.slot_accepts(to_slot, item_v):
		return false
	if not _inv.unequip_to_bag(from_slot):
		return false
	var idx: int = -1
	for i in range(_inv.bag.size()):
		if is_same(_inv.bag[i], item_v):
			idx = i
			break
	if idx < 0:
		return false
	if not _inv.equip_from_bag(idx, to_slot):
		_inv.equip_from_bag(idx, from_slot)
		return false
	return true


func _slot_name_at(screen_pos: Vector2) -> String:
	for slot_name: String in _slots:
		var panel: Panel = _slots[slot_name]["panel"]
		if panel.get_global_rect().has_point(screen_pos):
			return slot_name
	return ""


func _dialogue_open() -> bool:
	var dlg: Node = get_tree().get_first_node_in_group("dialogue_ui")
	return dlg != null and dlg.get("is_open") == true


# --- tooltip -----------------------------------------------------------------


func _on_slot_hover(slot_name: String) -> void:
	if _drag_from != "" or Inventory.DragCtx.item != null or _inv == null \
			or _dialogue_open():
		return
	var item_v: Variant = _inv.equipped.get(slot_name)
	if not (item_v is Dictionary):
		return
	var panel: Panel = _slots[slot_name]["panel"]
	var pos: Vector2 = panel.get_global_rect().position + Vector2(SLOT + 4.0, 0.0)
	_tooltip.show_item(item_v, pos)


func _on_slot_unhover() -> void:
	_tooltip.hide_tip()


# --- construction ------------------------------------------------------------


func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "SheetPanel"
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = PAD
	_panel.offset_right = PAD + PANEL_W
	# Lifted PANEL_LIFT above true center so the panel's bottom clears the
	# HUD player plate (bottom-anchored at viewport_h - 8 - 54 = y 298).
	_panel.offset_top = -PANEL_H * 0.5 - PANEL_LIFT
	_panel.offset_bottom = PANEL_H * 0.5 - PANEL_LIFT
	_panel.pivot_offset = Vector2(PANEL_W, PANEL_H) * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	# Dark fill, inset so the wooden 9-patch rim overlaps its edges (HUD style).
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(PANEL_W - 6.0, PANEL_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.border_color = BOX_BORDER
	fill_sb.set_border_width_all(2)
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

	_title = Label.new()
	_title.name = "Title"
	_style_label(_title, 12, GOLD)
	_title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_title.add_theme_constant_override("outline_size", 2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.text = "Character"
	_title.position = Vector2(PAD, 5.0)
	_panel.add_child(_title)
	_title.set_deferred("size", Vector2(PANEL_W - PAD * 2.0, 14.0))

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(BOX_BORDER.r, BOX_BORDER.g, BOX_BORDER.b, 0.7)
	divider.position = Vector2(PAD, 21.0)
	divider.size = Vector2(PANEL_W - PAD * 2.0, 1.0)
	_panel.add_child(divider)


func _build_slots() -> void:
	for i in range(LEFT_SLOTS.size()):
		_build_slot(LEFT_SLOTS[i], Vector2(PAD, COLS_Y + float(i) * SLOT_PITCH))
	for i in range(RIGHT_SLOTS.size()):
		_build_slot(RIGHT_SLOTS[i],
				Vector2(PANEL_W - PAD - SLOT, COLS_Y + float(i) * SLOT_PITCH))


func _build_slot(slot_name: String, pos: Vector2) -> void:
	var panel := Panel.new()
	panel.name = "Slot_" + slot_name
	panel.position = pos
	panel.size = Vector2(SLOT, SLOT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.gui_input.connect(_on_slot_gui_input.bind(slot_name))
	panel.mouse_entered.connect(_on_slot_hover.bind(slot_name))
	panel.mouse_exited.connect(_on_slot_unhover)
	_panel.add_child(panel)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(3.0, 3.0)
	icon.size = Vector2(SLOT - 6.0, SLOT - 6.0)
	icon.visible = false
	panel.add_child(icon)

	# Engraved slot-name label under the slot: dim bronze with a dark 1 px
	# drop shadow. Alagard 8 nominal, shrunk down (min 6) for long names so
	# nothing overflows the 40 px band.
	var display: String = str(SLOT_LABELS.get(slot_name, slot_name))
	var label := Label.new()
	label.name = "Label_" + slot_name
	_style_label(label, _fit_font_size(display, 38.0, 8, 6), ENGRAVE)
	label.add_theme_color_override("font_shadow_color", ENGRAVE_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = display
	# Right-column boxes sit 4 px further left and grow LEFT on min-size
	# clamps so long names ("Main Hand") can never spill past the panel rim.
	var is_right: bool = RIGHT_SLOTS.has(slot_name)
	var box_x: float = pos.x + SLOT * 0.5 - (24.0 if is_right else 20.0)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN if is_right \
			else Control.GROW_DIRECTION_END
	label.position = Vector2(box_x, pos.y + SLOT + 1.0)
	_panel.add_child(label)
	# Deferred: Godot applies theme font overrides via a deferred THEME_CHANGED,
	# so a same-frame size assignment gets clamped to the default-font minimum
	# (~2x too wide) and never shrinks back. Re-assert after the theme settles.
	label.set_deferred("size", Vector2(40.0, LABEL_H))

	_slots[slot_name] = {"panel": panel, "sb": sb, "icon": icon, "label": label}


func _build_stage() -> void:
	_stage = Panel.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = true
	_stage.position = Vector2(STAGE_X, COLS_Y)
	_stage.size = Vector2(STAGE_W, STAGE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = STAGE_BG
	sb.border_color = STAGE_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	_stage.add_theme_stylebox_override("panel", sb)
	_panel.add_child(_stage)

	# Warm radial glow behind the character, like lantern light on the stage.
	_glow = TextureRect.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.texture = _make_glow_texture()
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.position = Vector2(4.0, 28.0)
	_glow.size = Vector2(STAGE_W - 8.0, 140.0)
	_glow.visible = false
	_stage.add_child(_glow)

	_preview = AnimatedSprite2D.new()
	_preview.name = "Preview"
	_preview.centered = true
	_preview.position = Vector2(STAGE_W * 0.5, STAGE_H * 0.5)
	_preview.scale = Vector2(3.0, 3.0)
	_preview.visible = false
	_stage.add_child(_preview)

	# Equipped main-hand weapon mirrored on the doll (spec: visible equipment
	# in world AND on the paper-doll preview). Child of the preview so it
	# inherits the 3x scale and the chest tint.
	_preview_weapon = Sprite2D.new()
	_preview_weapon.name = "PreviewWeapon"
	_preview_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_weapon.centered = false
	_preview_weapon.visible = false
	_preview.add_child(_preview_weapon)


func _build_stats_strip() -> void:
	var strip := Panel.new()
	strip.name = "StatsStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(PAD, STATS_Y)
	strip.size = Vector2(PANEL_W - PAD * 2.0, STATS_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = STRIP_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	strip.add_theme_stylebox_override("panel", sb)
	_panel.add_child(strip)

	var inner_w: float = PANEL_W - PAD * 2.0
	for i in range(STAT_KEYS.size()):
		var x: float = roundf(float(i) * inner_w / 6.0)
		var w: float = roundf(float(i + 1) * inner_w / 6.0) - x

		# Tiny procedural stat glyph: a rotated square = pixel diamond.
		var glyph := ColorRect.new()
		glyph.name = "Glyph_" + STAT_KEYS[i]
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.color = STAT_COLORS[i]
		glyph.size = Vector2(4.0, 4.0)
		glyph.pivot_offset = Vector2(2.0, 2.0)
		glyph.rotation = PI / 4.0
		glyph.position = Vector2(x + 4.0, 5.0)
		strip.add_child(glyph)

		var name_label := Label.new()
		name_label.name = "StatName_" + STAT_KEYS[i]
		_style_label(name_label, _fit_font_size(STAT_LABELS[i], w - 12.0, 8, 6), GOLD)
		name_label.add_theme_color_override("font_shadow_color", ENGRAVE_SHADOW)
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.text = STAT_LABELS[i]
		name_label.position = Vector2(x + 10.0, 1.0)
		strip.add_child(name_label)
		name_label.set_deferred("size", Vector2(w - 10.0, 10.0))

		var value_label := Label.new()
		value_label.name = "StatValue_" + STAT_KEYS[i]
		_style_label(value_label, 9, DIM_VALUE)
		value_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		value_label.add_theme_constant_override("outline_size", 1)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.text = "0"
		value_label.position = Vector2(x, 13.0)
		strip.add_child(value_label)
		value_label.set_deferred("size", Vector2(w, 12.0))
		_stat_values.append(value_label)


# --- helpers -----------------------------------------------------------------


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


## Largest font size in [min_size, start] whose rendered width fits max_w.
func _fit_font_size(text: String, max_w: float, start: int, min_size: int) -> int:
	var s: int = start
	while s > min_size:
		var w: float = _font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, s).x
		if w <= max_w:
			break
		s -= 1
	return s


## Item icon, or a small rarity-colored placeholder square when the icon path
## is missing/bad — an occupied slot must never look empty.
func _icon_or_placeholder(item: Dictionary) -> Texture2D:
	var tex: Texture2D = _load_icon(item.get("icon"))
	if tex != null:
		return tex
	var rarity: String = str(item.get("rarity", "common"))
	if _placeholders.has(rarity):
		return _placeholders[rarity]
	var img: Image = Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Items.rarity_color(rarity).darkened(0.35))
	var placeholder: ImageTexture = ImageTexture.create_from_image(img)
	_placeholders[rarity] = placeholder
	return placeholder


## Accepts "pixel:<id>" Shikashi registry ids (resolved via IconsPixel) or
## full "res://..." paths. Returns null when the resource does not exist so a
## bad icon id never crashes the sheet (the rarity placeholder covers it).
## (The painterly bare-name fallback is gone — Phase B.2 moved every icon to
## the pixel registry.)
static func _load_icon(icon_v: Variant) -> Texture2D:
	var s: String = str(icon_v) if icon_v != null else ""
	if s.is_empty():
		return null
	if s.begins_with(PIXEL_PREFIX):
		return _pixel_icon(s.substr(PIXEL_PREFIX.length()))
	if s.begins_with("res://") and ResourceLoader.exists(s, "Texture2D"):
		return load(s)
	return null


## IconsPixel.get_tex() via an on-demand load (not a compile-time reference)
## so this script parses on its own; missing script / unknown id -> null and
## the caller falls back to the rarity placeholder square.
static func _pixel_icon(icon_id: String) -> Texture2D:
	if _pixel_script == null:
		if not ResourceLoader.exists(ICONS_PIXEL_PATH, "Script"):
			return null
		_pixel_script = load(ICONS_PIXEL_PATH) as GDScript
	if _pixel_script == null:
		return null
	var tex_v: Variant = _pixel_script.call("get_tex", icon_id)
	return tex_v if tex_v is Texture2D else null


static func _make_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(GLOW_WARM.r, GLOW_WARM.g, GLOW_WARM.b, 0.30))
	grad.set_color(1, Color(GLOW_WARM.r, GLOW_WARM.g, GLOW_WARM.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 96
	tex.height = 96
	return tex
