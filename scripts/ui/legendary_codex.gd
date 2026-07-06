extends CanvasLayer
## LegendaryCodex -- the gold-bezel + legendary-orange codex of the seven class
## legendaries (Build #44, design/LEGENDARY_WEAPONS.md). Self-instanced by
## LegendarySystem._ready (add_child; mirrors the MountSystem UI pattern) and
## driven entirely in code -- no .tscn. Lists all seven: owned / locked, the
## signature effect described CONCRETELY, an acquisition hint, and the lore.
##
## It is a pure VIEW: every fact is read off the LegendarySystem reference passed
## into present() (legendary_def / signature_of / acquisition_of / owns). Opened /
## closed by LegendarySystem (the ']' key owner). Exposes `is_open` + group
## "legendary_ui" so panel-blocking checks can see it.

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const LEG_ORANGE := Color(1.0, 0.55, 0.10)
const LEG_ORANGE_BRIGHT := Color(1.0, 0.70, 0.32)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.51)
const OWNED_GREEN := Color(0.55, 0.82, 0.45)
const LOCKED_GREY := Color(0.55, 0.52, 0.48)
const OUTLINE_DARK := Color(0.07, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.05, 0.98)
const ROW_BG := Color(0.13, 0.10, 0.07, 0.85)

const BASE_W: float = 640.0
const BASE_H: float = 360.0

var is_open: bool = false

var _system: Node = null
var _actor: Node = null
var _root: Control = null
var _list: VBoxContainer = null

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")


func _ready() -> void:
	layer = 40
	add_to_group("legendary_ui")
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)  # fills the viewport
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var margin: float = 12.0
	var panel := NinePatchRect.new()
	panel.texture = _panel_tex
	panel.patch_margin_left = 8
	panel.patch_margin_right = 8
	panel.patch_margin_top = 8
	panel.patch_margin_bottom = 8
	panel.position = Vector2(margin, margin)
	panel.size = Vector2(BASE_W - margin * 2.0, BASE_H - margin * 2.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	# Legendary-orange bezel line just inside the frame.
	var bezel := Panel.new()
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.offset_left = 8
	bezel.offset_top = 8
	bezel.offset_right = -8
	bezel.offset_bottom = -8
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0)
	bsb.border_color = LEG_ORANGE
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(2)
	bezel.add_theme_stylebox_override("panel", bsb)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bezel)

	var pad: float = 18.0
	var title := _mk_label("LEGENDARY CODEX", 18, LEG_ORANGE_BRIGHT)
	title.position = Vector2(pad, 12)
	title.size = Vector2(panel.size.x - pad * 2.0, 24)
	panel.add_child(title)

	var subtitle := _mk_label(
		"Seven weapons. Seven prices. What you carry is what they see -- no transmog, ever.",
		8, GOLD)
	subtitle.position = Vector2(pad, 34)
	subtitle.size = Vector2(panel.size.x - pad * 2.0 - 60.0, 12)
	panel.add_child(subtitle)

	var hint := _mk_label("[  ]  close", 8, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(panel.size.x - pad - 80.0, 14)
	hint.size = Vector2(80, 12)
	panel.add_child(hint)

	var rule := ColorRect.new()
	rule.color = GOLD
	rule.position = Vector2(pad, 48)
	rule.size = Vector2(panel.size.x - pad * 2.0, 1)
	panel.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(pad, 54)
	scroll.size = Vector2(panel.size.x - pad * 2.0, panel.size.y - 66)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


# --- open / close / refresh -------------------------------------------------

func present(system: Node, actor: Node) -> void:
	_system = system
	_actor = actor
	is_open = true
	if _root != null:
		_root.visible = true
	# Wait a frame so the ScrollContainer/VBox have a real width before wrapping.
	call_deferred("_populate")


func close() -> void:
	is_open = false
	if _root != null:
		_root.visible = false


func refresh() -> void:
	if is_open:
		_populate()


func _populate() -> void:
	if _list == null or _system == null:
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var row_w: float = _list.size.x
	if row_w < 10.0:
		row_w = BASE_W - 60.0
	for id: String in (_system.call("all_ids") as Array):
		_list.add_child(_build_row(str(id), row_w))


func _build_row(id: String, row_w: float) -> Control:
	var d: Dictionary = _system.call("legendary_def", id)
	var sig: Dictionary = _system.call("signature_of", id)
	var acq: Dictionary = _system.call("acquisition_of", id)
	var starter: Dictionary = _system.call("starter_of", id)
	var is_owned: bool = _actor != null and bool(_system.call("owns", _actor, id))

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = ROW_BG
	rsb.border_color = LEG_ORANGE if is_owned else Color(0.32, 0.27, 0.20)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(3)
	rsb.content_margin_left = 8
	rsb.content_margin_right = 8
	rsb.content_margin_top = 6
	rsb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", rsb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	# Header: name + class, owned/locked badge on the right.
	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(head)

	var name_col: Color = LEG_ORANGE_BRIGHT if is_owned else LEG_ORANGE
	var nm := _mk_label(str(d.get("name", id)).to_upper(), 14, name_col)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)

	var cls := _mk_label(str(d.get("class", "")).capitalize(), 9, GOLD)
	cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cls.custom_minimum_size = Vector2(96, 14)
	head.add_child(cls)

	var badge := _mk_label("OWNED" if is_owned else "LOCKED", 9,
			OWNED_GREEN if is_owned else LOCKED_GREY)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.custom_minimum_size = Vector2(56, 14)
	head.add_child(badge)

	# Epithet.
	col.add_child(_mk_wrap('"' + str(d.get("epithet", "")) + '"', 8, DIM, row_w))

	# Stat line.
	col.add_child(_mk_wrap("Stats:  " + _stat_dict_line(_dict(d.get("stats", {}))), 8, PARCHMENT, row_w))

	# Signature effect (concrete).
	var sig_name: String = str(sig.get("name", "Signature"))
	var sig_desc: String = str(sig.get("desc", ""))
	col.add_child(_mk_wrap("Signature -- " + sig_name + ":  " + sig_desc, 8, LEG_ORANGE_BRIGHT, row_w))
	var passive: Dictionary = _dict(sig.get("passive", {}))
	if not passive.is_empty():
		col.add_child(_mk_wrap("   Always-on:  " + _stat_dict_line(passive)
				+ "   (" + str(sig.get("passive_note", "")) + ")", 8, GOLD, row_w))

	# Acquisition hint.
	var starter_line: String = str(starter.get("name", "?")) + " (" \
			+ str(int(round(float(starter.get("chance", 0.03)) * 100.0))) + "% starter)"
	var acq_line: String = "Acquire -- " + str(acq.get("chain", "")) + ":  " + starter_line \
			+ "  ->  " + _join(_arr(acq.get("steps", [])), " > ") \
			+ "   @ " + str(acq.get("site", ""))
	col.add_child(_mk_wrap(acq_line, 8, DIM, row_w))
	if str(acq.get("hint", "")) != "":
		col.add_child(_mk_wrap("   " + str(acq.get("hint", "")), 8, DIM, row_w))

	# Lore.
	col.add_child(_mk_wrap(str(d.get("lore", "")), 8, PARCHMENT, row_w))

	return row


# --- text helpers -----------------------------------------------------------

func _stat_dict_line(stats: Dictionary) -> String:
	var parts: Array = []
	var labels: Dictionary = {
		"damage": "dmg", "armor": "armor", "hp": "hp", "mana": "mana",
		"speed_pct": "spd%", "crit_pct": "crit%", "mana_regen": "mp5",
	}
	for k: String in ["damage", "crit_pct", "speed_pct", "armor", "hp", "mana", "mana_regen"]:
		var v: float = float(stats.get(k, 0.0))
		if absf(v) > 0.0001:
			parts.append("%s %s" % [_fmt_num(v), labels.get(k, k)])
	return "  ".join(parts) if not parts.is_empty() else "--"


func _fmt_num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(round(v)))
	return "%.1f" % v


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


func _mk_wrap(text: String, size: int, color: Color, width: float) -> Label:
	var l := _mk_label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(maxf(40.0, width - 20.0), 0)
	return l


func _join(a: Array, sep: String) -> String:
	var parts: Array = []
	for v: Variant in a:
		parts.append(str(v))
	return sep.join(parts)


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
