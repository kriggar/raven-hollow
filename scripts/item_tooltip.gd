class_name ItemTooltip
extends PanelContainer
## Shared, code-built hover tooltip for item Dictionaries (see items.gd).
## Both the backpack (bag_ui.gd) and the character sheet own their own
## instance. Styled per the Raven Hollow UI mandate (dark aged-wood panel,
## Alagard, gold/parchment): item name in rarity color (12), slot + rarity
## line, "+N Stat" lines in parchment, italic-ish grey-gold flavor text
## (skewed FontVariation of Alagard) and a gold "Legendary" tag line.
## show_item() sizes the panel to its content and clamps it to the viewport.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const BOX_BORDER := Color(0.45, 0.33, 0.18)
const TYPE_DIM := Color(0.64, 0.59, 0.50)
const FLAVOR_TINT := Color(0.68, 0.61, 0.46)

const WRAP_WIDTH: float = 132.0
const CURSOR_GAP: float = 10.0
const EDGE_PAD: float = 4.0
const FLAVOR_SIZE: int = 9

## Rarity palette per the user-approved Phase B spec (mirrors Items.rarity_color;
## kept local so the tooltip has zero peer dependencies).
const RARITY_COLORS: Dictionary = {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.35, 0.75, 0.35),
	"rare": Color(0.3, 0.5, 0.9),
	"epic": Color(0.62, 0.35, 0.85),
	"legendary": Color(1.0, 0.55, 0.1),
}

const SLOT_LABELS: Dictionary = {
	"head": "Head", "chest": "Chest", "legs": "Legs", "boots": "Boots",
	"main_hand": "Main Hand", "off_hand": "Off Hand", "ring": "Ring",
	"ring1": "Ring", "ring2": "Ring", "trinket": "Trinket",
}

## [stats key, display name, is_percent] — display order of the stat lines.
const STAT_ROWS: Array = [
	["damage", "Damage", false],
	["armor", "Armor", false],
	["hp", "Health", false],
	["mana", "Mana", false],
	["mana_regen", "Mana Regen", false],
	["speed_pct", "Speed", true],
	["crit_pct", "Crit", true],
]

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _italic: FontVariation
var _built: bool = false
var _name_label: Label
var _type_label: Label
var _stat_labels: Array[Label] = []
var _flavor_label: Label
var _legend_label: Label


func _ready() -> void:
	_build()


## Fills the tooltip from an item Dictionary and shows it near screen_pos
## (viewport coordinates, e.g. the mouse), clamped inside the viewport.
func show_item(item: Dictionary, screen_pos: Vector2) -> void:
	_build()
	if item.is_empty():
		hide_tip()
		return

	var rarity: String = str(item.get("rarity", "common"))
	_name_label.text = str(item.get("name", "?"))
	_name_label.add_theme_color_override("font_color", rarity_color(rarity))
	_name_label.visible = true  # labels are born hidden (_make_label)

	# Slot + rarity line ("Main Hand - Rare"). Legendaries keep just the slot
	# here — they get the dedicated gold tag line at the bottom instead.
	var parts: Array[String] = []
	var slot_pretty: String = str(SLOT_LABELS.get(str(item.get("slot", "none")), ""))
	if not slot_pretty.is_empty():
		parts.append(slot_pretty)
	if rarity != "legendary":
		parts.append(rarity.capitalize())
	_type_label.text = " - ".join(parts)
	_type_label.visible = not parts.is_empty()

	var stats: Dictionary = {}
	var stats_v: Variant = item.get("stats")
	if stats_v is Dictionary:
		stats = stats_v
	for i in range(STAT_ROWS.size()):
		var row: Array = STAT_ROWS[i]
		var label: Label = _stat_labels[i]
		var value: float = 0.0
		var value_v: Variant = stats.get(row[0])
		if value_v is float or value_v is int:
			value = float(value_v)
		if absf(value) < 0.01:
			label.visible = false
			continue
		label.visible = true
		var num: String = _fmt_num(value)
		if value > 0.0:
			num = "+" + num
		if bool(row[2]):
			num += "%"
		label.text = "%s %s" % [num, str(row[1])]

	var flavor: String = str(item.get("flavor", ""))
	_flavor_label.visible = not flavor.is_empty()
	if _flavor_label.visible:
		var quoted: String = "\"%s\"" % flavor
		_flavor_label.text = quoted
		# Autowrapped label heights settle a frame late in containers; measure
		# the wrapped text now so reset_size() is correct immediately.
		var wrapped: Vector2 = _italic.get_multiline_string_size(
			quoted, HORIZONTAL_ALIGNMENT_LEFT, WRAP_WIDTH, FLAVOR_SIZE)
		_flavor_label.custom_minimum_size = Vector2(WRAP_WIDTH, wrapped.y + 1.0)

	_legend_label.visible = rarity == "legendary"

	visible = true
	reset_size()
	_place(screen_pos)


func hide_tip() -> void:
	visible = false


static func rarity_color(rarity: String) -> Color:
	var c: Variant = RARITY_COLORS.get(rarity)
	if c is Color:
		return c
	return Color(0.62, 0.62, 0.62)


# --- construction ------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(7.0)
	add_theme_stylebox_override("panel", sb)

	# Alagard has no italic face: fake one with a slight glyph skew.
	_italic = FontVariation.new()
	_italic.base_font = _font
	_italic.variation_transform = Transform2D(
		Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2.ZERO)

	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	_name_label = _make_label(vbox, 12, GOLD)
	_type_label = _make_label(vbox, 8, TYPE_DIM)
	for _i in range(STAT_ROWS.size()):
		_stat_labels.append(_make_label(vbox, 9, PARCHMENT))
	_flavor_label = _make_label(vbox, FLAVOR_SIZE, FLAVOR_TINT)
	_flavor_label.add_theme_font_override("font", _italic)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.custom_minimum_size = Vector2(WRAP_WIDTH, 0.0)
	_legend_label = _make_label(vbox, 9, GOLD)
	_legend_label.text = "Legendary"


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.visible = false
	parent.add_child(label)
	return label


# --- helpers -----------------------------------------------------------------

## Prefers above-right of the anchor point, flips left / clamps so the panel
## never leaves the viewport.
func _place(screen_pos: Vector2) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		position = screen_pos
		return
	var view: Vector2 = vp.get_visible_rect().size
	var pos: Vector2 = Vector2(
		screen_pos.x + CURSOR_GAP, screen_pos.y - size.y - CURSOR_GAP * 0.6)
	if pos.x + size.x > view.x - EDGE_PAD:
		pos.x = screen_pos.x - size.x - CURSOR_GAP
	pos.x = clampf(pos.x, EDGE_PAD, maxf(EDGE_PAD, view.x - size.x - EDGE_PAD))
	pos.y = clampf(pos.y, EDGE_PAD, maxf(EDGE_PAD, view.y - size.y - EDGE_PAD))
	position = pos.floor()


static func _fmt_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(int(roundf(v)))
	return "%.1f" % v
