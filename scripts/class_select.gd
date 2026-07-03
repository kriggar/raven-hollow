class_name ClassSelect
extends CanvasLayer
## Graveyard-Keeper-flavored class selection screen, built entirely in code.
## Shows the six playable classes as animated cards over a dark ember-lit
## backdrop. Emits class_chosen(id) then fades out and frees itself.
##
## ClassDefs is loaded dynamically (res://scripts/class_defs.gd) so this file
## parses standalone; the data contract is:
##   ClassDefs.all_ids() -> Array[String]
##   ClassDefs.get_def(id) -> Dictionary {id, name, title, lore, sheet,
##       variant, color, abilities:[{id, name, icon, ...} x3], ...}

signal class_chosen(id: String)

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.96)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BG_DARK := Color(0.06, 0.05, 0.045)
const EMBER_GLOW := Color(0.42, 0.27, 0.13, 0.30)
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.5)

const VIEW := Vector2(640.0, 360.0)
const CARD_SIZE := Vector2(92.0, 150.0)
const CARD_GAP := 8.0
const CARD_TOP := 84.0
const STRIP_HEIGHT := 52.0
const FOCUS_SCALE := 1.05
const FADE_OUT_TIME := 0.4

const CLASS_DEFS_PATH := "res://scripts/class_defs.gd"
const ICON_DIR := "res://assets/art/icons/"

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")

var _defs: Array[Dictionary] = []
## Per-card bag: {root: Control, style: StyleBoxFlat, sprite: AnimatedSprite2D,
##                tween: Tween-or-null}
var _cards: Array[Dictionary] = []
var _focus: int = 0
var _confirmed: bool = false

var _root: Control
var _lore_label: Label
var _ability_icons: Array[TextureRect] = []
var _ability_labels: Array[Label] = []
var _hint_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_defs()
	_build_ui()
	if not _defs.is_empty():
		_apply_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _confirmed or _defs.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + _defs.size() - 1) % _defs.size())
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + 1) % _defs.size())
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_confirm()


# ---------------------------------------------------------------- data

func _load_defs() -> void:
	if not ResourceLoader.exists(CLASS_DEFS_PATH):
		push_warning("class_select.gd: %s not found — no classes to show." % CLASS_DEFS_PATH)
		return
	var cd: GDScript = load(CLASS_DEFS_PATH) as GDScript
	if cd == null:
		push_warning("class_select.gd: could not load ClassDefs script.")
		return
	var ids: Array = cd.all_ids()
	for id: Variant in ids:
		var def: Dictionary = cd.get_def(String(id))
		if not def.is_empty():
			_defs.append(def)
	# Default focus: warrior (index 0 by contract, but be explicit).
	for i in range(_defs.size()):
		if String(_defs[i].get("id", "")) == "warrior":
			_focus = i
			break


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_backdrop()
	_build_header()
	_build_cards()
	_build_bottom_strip()


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = BG_DARK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var glow := TextureRect.new()
	glow.name = "EmberGlow"
	glow.texture = _make_radial_texture(EMBER_GLOW, Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.0), 0.0, 1.0)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(glow)

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = _make_radial_texture(Color(0.0, 0.0, 0.0, 0.0), VIGNETTE_EDGE, 0.55, 1.0)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(vignette)


func _build_header() -> void:
	var header := VBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.offset_top = 16.0
	header.offset_bottom = 76.0
	header.add_theme_constant_override("separation", 2)
	_root.add_child(header)

	var title := Label.new()
	title.text = "Raven Hollow"
	_style_label(title, 30, GOLD)
	title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Emberfall — Choose your path"
	_style_label(subtitle, 12, PARCHMENT)
	subtitle.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	subtitle.add_theme_constant_override("outline_size", 2)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(subtitle)

	# Gentle fade-in.
	header.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(header, "modulate:a", 1.0, 0.9)


func _build_cards() -> void:
	if _defs.is_empty():
		return
	var count: int = _defs.size()
	var row_width: float = float(count) * CARD_SIZE.x + float(count - 1) * CARD_GAP
	var start_x: float = (VIEW.x - row_width) * 0.5
	for i in range(count):
		var card: Dictionary = _make_card(_defs[i], i)
		var card_root: Control = card.root
		card_root.position = Vector2(start_x + float(i) * (CARD_SIZE.x + CARD_GAP), CARD_TOP)
		_root.add_child(card_root)
		_cards.append(card)


func _make_card(def: Dictionary, index: int) -> Dictionary:
	var card := Control.new()
	card.name = "Card_" + String(def.get("id", str(index)))
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(_on_card_hover.bind(index))
	card.gui_input.connect(_on_card_gui_input.bind(index))

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", style)
	card.add_child(panel)

	# Animated character preview (szadi 32x48 frames, node pos = frame center).
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Preview"
	var sheet: String = String(def.get("sheet", ""))
	if not sheet.is_empty() and ResourceLoader.exists(sheet):
		sprite.sprite_frames = SheetAnim.make_szadi_frames(sheet, int(def.get("variant", 0)))
		sprite.play("idle_down")
	else:
		push_warning("class_select.gd: missing sheet '%s' for class '%s'." % [sheet, String(def.get("id", "?"))])
	sprite.position = Vector2(CARD_SIZE.x * 0.5, 44.0)
	sprite.scale = Vector2(2.0, 2.0)
	card.add_child(sprite)

	var name_label := Label.new()
	name_label.text = String(def.get("name", "?"))
	_style_label(name_label, 12, GOLD)
	name_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(2.0, 94.0)
	name_label.size = Vector2(CARD_SIZE.x - 4.0, 14.0)
	card.add_child(name_label)

	var title_label := Label.new()
	title_label.text = String(def.get("title", ""))
	_style_label(title_label, 8, PARCHMENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.position = Vector2(4.0, 110.0)
	title_label.size = Vector2(CARD_SIZE.x - 8.0, 22.0)
	card.add_child(title_label)

	# Row of the three ability icons.
	var abilities: Array = def.get("abilities", [])
	var icon_count: int = mini(abilities.size(), 3)
	var icons_width: float = float(icon_count) * 16.0 + float(maxi(icon_count - 1, 0)) * 4.0
	var icon_x: float = (CARD_SIZE.x - icons_width) * 0.5
	for j in range(icon_count):
		var ability: Dictionary = abilities[j]
		var icon_rect := _make_icon_rect(String(ability.get("icon", "")), 16.0)
		icon_rect.position = Vector2(icon_x + float(j) * 20.0, 130.0)
		card.add_child(icon_rect)

	return {"root": card, "style": style, "sprite": sprite, "tween": null}


func _build_bottom_strip() -> void:
	var strip := Panel.new()
	strip.name = "InfoStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -(STRIP_HEIGHT + 6.0)
	strip.offset_bottom = -6.0
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	strip.add_theme_stylebox_override("panel", style)
	_root.add_child(strip)

	_lore_label = Label.new()
	_style_label(_lore_label, 10, PARCHMENT)
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lore_label.position = Vector2(10.0, 3.0)
	_lore_label.size = Vector2(376.0, STRIP_HEIGHT - 6.0)
	strip.add_child(_lore_label)

	for j in range(3):
		var icon_rect := _make_icon_rect("", 14.0)
		icon_rect.position = Vector2(396.0, 4.0 + float(j) * 15.0)
		strip.add_child(icon_rect)
		_ability_icons.append(icon_rect)

		var ability_label := Label.new()
		_style_label(ability_label, 9, GOLD)
		ability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ability_label.position = Vector2(414.0, 4.0 + float(j) * 15.0)
		ability_label.size = Vector2(140.0, 14.0)
		strip.add_child(ability_label)
		_ability_labels.append(ability_label)

	_hint_label = Label.new()
	_hint_label.text = "Enter — Begin"
	_style_label(_hint_label, 10, GOLD)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(552.0, 0.0)
	_hint_label.size = Vector2(84.0, STRIP_HEIGHT)
	strip.add_child(_hint_label)

	var blink := create_tween().set_loops()
	blink.tween_property(_hint_label, "modulate:a", 0.25, 0.55).set_delay(0.35)
	blink.tween_property(_hint_label, "modulate:a", 1.0, 0.55)


# ---------------------------------------------------------------- focus

func _on_card_hover(index: int) -> void:
	if not _confirmed:
		_set_focus(index)


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if _confirmed:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_set_focus(index)
			_confirm()


func _set_focus(index: int) -> void:
	if index == _focus or index < 0 or index >= _cards.size():
		return
	_focus = index
	_apply_focus()


func _apply_focus() -> void:
	for i in range(_cards.size()):
		var card: Dictionary = _cards[i]
		var focused: bool = i == _focus
		var style: StyleBoxFlat = card.style
		style.border_color = GOLD if focused else PANEL_BORDER
		var sprite: AnimatedSprite2D = card.sprite
		if sprite.sprite_frames != null:
			var anim: StringName = &"walk_down" if focused else &"idle_down"
			if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
				sprite.play(anim)
		var old_tween: Variant = card.tween
		if old_tween is Tween and (old_tween as Tween).is_valid():
			(old_tween as Tween).kill()
		var target: float = FOCUS_SCALE if focused else 1.0
		var tw := create_tween()
		tw.tween_property(card.root, "scale", Vector2(target, target), 0.12)
		card.tween = tw
	_refresh_info_strip()


func _refresh_info_strip() -> void:
	if _defs.is_empty() or _lore_label == null:
		return
	var def: Dictionary = _defs[_focus]
	_lore_label.text = String(def.get("lore", ""))
	var abilities: Array = def.get("abilities", [])
	for j in range(3):
		if j < abilities.size():
			var ability: Dictionary = abilities[j]
			_ability_icons[j].texture = _load_icon(String(ability.get("icon", "")))
			_ability_icons[j].visible = _ability_icons[j].texture != null
			_ability_labels[j].text = String(ability.get("name", ""))
		else:
			_ability_icons[j].visible = false
			_ability_labels[j].text = ""


# ---------------------------------------------------------------- confirm

func _confirm() -> void:
	if _confirmed or _defs.is_empty():
		return
	_confirmed = true
	var id: String = String(_defs[_focus].get("id", "warrior"))
	class_chosen.emit(id)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- helpers

func _make_icon_rect(raw_icon: String, px: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(px, px)
	rect.size = Vector2(px, px)
	rect.texture = _load_icon(raw_icon)
	rect.visible = rect.texture != null
	return rect


## Accepts either a bare icon name ("fireball-red-1") or a full res:// path.
func _load_icon(raw: String) -> Texture2D:
	if raw.is_empty():
		return null
	var path: String = raw
	if not path.begins_with("res://"):
		path = ICON_DIR + path
	if not path.ends_with(".png"):
		path += ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("class_select.gd: ability icon not found: %s" % path)
	return null


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _make_radial_texture(inner: Color, outer: Color, inner_stop: float, outer_stop: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([inner_stop, outer_stop])
	gradient.colors = PackedColorArray([inner, outer])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 320
	tex.height = 180
	return tex
