class_name HUD
extends CanvasLayer
## Graveyard-Keeper-flavored gameplay HUD for Raven Hollow: Emberfall.
## Built entirely in code. Layer 8 (between the vignette at 5 and dialogue at
## 10), group "hud". Reads the "player" group node every frame, null-safe:
## everything stays hidden until a player with a class_def exists.
##
## Layout (640x360 design space):
##  - Bottom-left plate: class name + HP / mana bars with numeric overlays.
##    Plate = dark StyleBoxFlat fill (dialogue colors) framed by the Kenney
##    panel_brown 9-patch (draw_center off, modulated darker) for an aged-wood
##    rim that matches the parchment/gold dialogue style.
##  - Bottom-center ability bar: 3 slots of 30x30 with painterly icons,
##    keybind captions, bottom-anchored cooldown sweep + seconds label,
##    grey-blue tint when mana is insufficient.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const BOX_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const HP_FILL := Color(0.62, 0.16, 0.12)
const MANA_FILL := Color(0.2, 0.32, 0.55)
const BAR_BG := Color(0.05, 0.04, 0.03)
const SLOT_BG := Color(0.07, 0.055, 0.045, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const COOLDOWN_SHADE := Color(0.04, 0.03, 0.02, 0.62)
const MANA_LOW_TINT := Color(0.4, 0.42, 0.52)

const PLATE_W: float = 150.0
const PLATE_H: float = 54.0
const BAR_W: float = 120.0
const BAR_H: float = 9.0
const SLOT: float = 30.0
const SLOT_GAP: float = 6.0
const KEYBINDS: Array[String] = ["LMB", "Q", "R"]
const ICON_DIR := "res://assets/art/icons/"

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _root: Control
var _plate: Control
var _class_label: Label
var _hp_fill: ColorRect
var _mana_fill: ColorRect
var _hp_text: Label
var _mana_text: Label
var _ability_bar: Control
## One Dictionary per slot: {panel, icon, cd_rect, cd_label, key_label}.
var _slots: Array[Dictionary] = []
var _built_class_id: String = ""


func _ready() -> void:
	layer = 8
	add_to_group("hud")

	_root = Control.new()
	_root.name = "HudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	_build_plate()
	_build_ability_bar()


func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		_root.visible = false
		return
	var class_def_v: Variant = player.get("class_def")
	if not (class_def_v is Dictionary):
		_root.visible = false
		return
	var class_def: Dictionary = class_def_v
	if class_def.is_empty():
		_root.visible = false
		return
	_root.visible = true

	var class_id: String = str(class_def.get("id", ""))
	if class_id != _built_class_id:
		_built_class_id = class_id
		_apply_class(class_def)

	_update_bars(player)
	_update_ability_slots(player, class_def)


# --- per-frame updates -------------------------------------------------------

func _update_bars(player: Node) -> void:
	var hp: float = _as_float(player.get("hp"))
	var max_hp: float = maxf(_as_float(player.get("max_hp")), 1.0)
	var mana: float = _as_float(player.get("mana"))
	var max_mana: float = maxf(_as_float(player.get("max_mana")), 1.0)

	var inner_w: float = BAR_W - 2.0
	_hp_fill.size.x = roundf(inner_w * clampf(hp / max_hp, 0.0, 1.0))
	_mana_fill.size.x = roundf(inner_w * clampf(mana / max_mana, 0.0, 1.0))
	_hp_text.text = "%d/%d" % [int(roundf(hp)), int(roundf(max_hp))]
	_mana_text.text = "%d/%d" % [int(roundf(mana)), int(roundf(max_mana))]


func _update_ability_slots(player: Node, class_def: Dictionary) -> void:
	var abilities: Array = []
	var abilities_v: Variant = class_def.get("abilities")
	if abilities_v is Array:
		abilities = abilities_v
	_ability_bar.visible = not abilities.is_empty()

	var mana: float = _as_float(player.get("mana"))
	var can_query_cd: bool = player.has_method("cooldown_frac")

	for i in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var panel: Panel = slot["panel"]
		var key_label: Label = slot["key_label"]
		if i >= abilities.size():
			panel.visible = false
			key_label.visible = false
			continue
		panel.visible = true
		key_label.visible = true

		var ability: Dictionary = {}
		var ability_v: Variant = abilities[i]
		if ability_v is Dictionary:
			ability = ability_v

		# Cooldown sweep: dark rect rising from the slot bottom.
		var frac: float = 0.0
		if can_query_cd:
			frac = clampf(_as_float(player.call("cooldown_frac", i)), 0.0, 1.0)
		var cd_rect: ColorRect = slot["cd_rect"]
		var cd_label: Label = slot["cd_label"]
		if frac > 0.0:
			var h: float = roundf(frac * SLOT)
			cd_rect.visible = h >= 1.0
			cd_rect.position = Vector2(0.0, SLOT - h)
			cd_rect.size = Vector2(SLOT, h)
		else:
			cd_rect.visible = false
		var remaining: float = frac * _as_float(ability.get("cooldown"))
		cd_label.visible = remaining > 0.3
		if cd_label.visible:
			cd_label.text = "%d" % int(ceilf(remaining)) if remaining >= 9.95 else "%.1f" % remaining

		# Mana-insufficient tint.
		var icon: TextureRect = slot["icon"]
		var cost: float = _as_float(ability.get("mana_cost"))
		icon.modulate = MANA_LOW_TINT if mana < cost else Color.WHITE


func _apply_class(class_def: Dictionary) -> void:
	_class_label.text = str(class_def.get("name", "Adventurer"))
	var abilities: Array = []
	var abilities_v: Variant = class_def.get("abilities")
	if abilities_v is Array:
		abilities = abilities_v
	for i in range(_slots.size()):
		var icon: TextureRect = _slots[i]["icon"]
		icon.texture = null
		if i < abilities.size() and abilities[i] is Dictionary:
			icon.texture = _load_icon((abilities[i] as Dictionary).get("icon"))


# --- construction ------------------------------------------------------------

func _build_plate() -> void:
	_plate = Control.new()
	_plate.name = "StatusPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.anchor_left = 0.0
	_plate.anchor_right = 0.0
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.offset_left = 8.0
	_plate.offset_right = 8.0 + PLATE_W
	_plate.offset_top = -8.0 - PLATE_H
	_plate.offset_bottom = -8.0
	_root.add_child(_plate)

	# Dark fill, inset so the wooden 9-patch rim overlaps its edges.
	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(PLATE_W - 6.0, PLATE_H - 6.0)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = BOX_BG
	fill_sb.set_border_width_all(0)
	fill_sb.set_corner_radius_all(0)
	fill.add_theme_stylebox_override("panel", fill_sb)
	_plate.add_child(fill)

	# Kenney aged-wood rim, tinted darker to sit in the dusk palette.
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
	_plate.add_child(frame)

	_class_label = Label.new()
	_class_label.name = "ClassName"
	_style_label(_class_label, 12, GOLD)
	_class_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_class_label.add_theme_constant_override("outline_size", 2)
	_class_label.position = Vector2(15.0, 4.0)
	_class_label.size = Vector2(PLATE_W - 30.0, 15.0)
	_plate.add_child(_class_label)

	var bar_x: float = (PLATE_W - BAR_W) * 0.5
	var hp_parts: Array = _build_bar(_plate, Vector2(bar_x, 23.0), HP_FILL)
	_hp_fill = hp_parts[0]
	_hp_text = hp_parts[1]
	var mana_parts: Array = _build_bar(_plate, Vector2(bar_x, 37.0), MANA_FILL)
	_mana_fill = mana_parts[0]
	_mana_text = mana_parts[1]


## Builds one 120x9 resource bar (1px border, fill, tiny numeric overlay).
## Returns [fill ColorRect, text Label].
func _build_bar(parent: Control, pos: Vector2, fill_color: Color) -> Array:
	var back := Panel.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = pos
	back.size = Vector2(BAR_W, BAR_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	back.add_theme_stylebox_override("panel", sb)
	parent.add_child(back)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = fill_color
	fill.position = Vector2(1.0, 1.0)
	fill.size = Vector2(BAR_W - 2.0, BAR_H - 2.0)
	back.add_child(fill)

	var text := Label.new()
	_style_label(text, 8, PARCHMENT)
	text.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	text.add_theme_constant_override("outline_size", 1)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.position = Vector2.ZERO
	text.size = Vector2(BAR_W, BAR_H)
	back.add_child(text)

	return [fill, text]


func _build_ability_bar() -> void:
	var total_w: float = SLOT * 3.0 + SLOT_GAP * 2.0
	var caption_h: float = 10.0
	_ability_bar = Control.new()
	_ability_bar.name = "AbilityBar"
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_bar.anchor_left = 0.5
	_ability_bar.anchor_right = 0.5
	_ability_bar.anchor_top = 1.0
	_ability_bar.anchor_bottom = 1.0
	_ability_bar.offset_left = -total_w * 0.5
	_ability_bar.offset_right = total_w * 0.5
	_ability_bar.offset_top = -8.0 - caption_h - 2.0 - SLOT
	_ability_bar.offset_bottom = -8.0
	_root.add_child(_ability_bar)

	for i in range(3):
		var x: float = float(i) * (SLOT + SLOT_GAP)

		var panel := Panel.new()
		panel.name = "Slot%d" % i
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.position = Vector2(x, 0.0)
		panel.size = Vector2(SLOT, SLOT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = SLOT_BG
		sb.border_color = SLOT_BORDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(0)
		panel.add_theme_stylebox_override("panel", sb)
		_ability_bar.add_child(panel)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(2.0, 2.0)
		icon.size = Vector2(SLOT - 4.0, SLOT - 4.0)
		panel.add_child(icon)

		var cd_rect := ColorRect.new()
		cd_rect.name = "CooldownShade"
		cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_rect.color = COOLDOWN_SHADE
		cd_rect.visible = false
		panel.add_child(cd_rect)

		var cd_label := Label.new()
		cd_label.name = "CooldownSeconds"
		_style_label(cd_label, 9, GOLD)
		cd_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		cd_label.add_theme_constant_override("outline_size", 2)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.position = Vector2.ZERO
		cd_label.size = Vector2(SLOT, SLOT)
		cd_label.visible = false
		panel.add_child(cd_label)

		var key_label := Label.new()
		key_label.name = "Key%d" % i
		_style_label(key_label, 8, PARCHMENT)
		key_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		key_label.add_theme_constant_override("outline_size", 2)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.text = KEYBINDS[i]
		key_label.position = Vector2(x, SLOT + 2.0)
		key_label.size = Vector2(SLOT, caption_h)
		_ability_bar.add_child(key_label)

		_slots.append({
			"panel": panel,
			"icon": icon,
			"cd_rect": cd_rect,
			"cd_label": cd_label,
			"key_label": key_label,
		})


# --- helpers -----------------------------------------------------------------

func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


## Accepts "res://..." paths, bare icon names ("fireball-red-1") or file names
## ("fireball-red-1.png") per the class_defs icon field. Returns null if the
## resource does not exist so a bad id never crashes the HUD.
static func _load_icon(icon_v: Variant) -> Texture2D:
	var s: String = str(icon_v) if icon_v != null else ""
	if s.is_empty():
		return null
	if not s.begins_with("res://"):
		if not s.ends_with(".png"):
			s += ".png"
		s = ICON_DIR + s
	if ResourceLoader.exists(s, "Texture2D"):
		return load(s)
	return null


static func _as_float(v: Variant) -> float:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return float(v)
	return 0.0
