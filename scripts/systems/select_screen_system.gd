extends Node
## SelectScreenSystem -- autoload (/root/SelectScreenSystem). BACKLOG #84,
## BLUEPRINT_84_SELECT_SCREEN. A Diablo-2-flavoured class SELECT SCREEN: a dark
## torch-lit hall, a row of class pedestals, and a central hero standing on his
## pedestal who idle-pulses under a flickering brazier glow. The right panel reads
## the class fantasy (name + title + lore), its three-to-four signature abilities
## with icons + concrete tooltips, and its primary-stat bias bars. Left/Right cycle
## the pedestals; Enter confirms and the chosen class fires class_selected(id).
##
## Everything is self-contained and boot-safe: this autoload loads its pedestal
## data (data/select_screen.json) in _ready and, on open_select(), self-instances a
## pure-code CanvasLayer child (no .tscn). It DEGRADES SAFELY -- it needs no world,
## no player, and no sibling systems; class art is optional (a class with no sheet,
## or a missing sheet, falls back to a labelled placeholder silhouette so the screen
## renders headless with zero art). Global helper classes SheetAnim (animated szadi
## frames) and IconsPixel (ability icons) are used exactly as scripts/class_select.gd
## uses them, and every fetched texture is null-guarded.
##
## Public API:
##   open_select()                open the select screen (idempotent while open)
##   close_select()               tear the layer down and free it
##   is_select_open() -> bool
##   cycle(dir)                   move the highlight -1 / +1 (wraps)
##   highlight(index)             highlight a pedestal by index
##   confirm()                    pick the highlighted class -> class_selected + close
##   highlighted_index() -> int
##   highlighted_class() -> String
##   class_ids() -> Array ; pedestal_def(id) -> Dictionary ; class_count() -> int
## Signals:
##   select_opened()
##   class_highlighted(class_id)
##   class_selected(class_id)

signal select_opened()
signal class_highlighted(class_id)
signal class_selected(class_id)

const DATA_PATH := "res://data/select_screen.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const PANEL_TEX_PATH := "res://assets/art/ui/panel_brown.png"

const BASE_W: float = 640.0
const BASE_H: float = 360.0

# --- palette (matches the ornate-UI kit used by the codex / class_select) ------
const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.70)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.62, 0.58, 0.50)
const BG_DARK := Color(0.05, 0.045, 0.05)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.97)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.07, 0.05, 0.03)
const EMBER_GLOW := Color(0.44, 0.28, 0.13, 0.34)
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.55)

var _title: String = "CHOOSE YOUR CHAMPION"
var _subtitle: String = "Raven Hollow -- Emberfall"
var _primaries: Array = ["stamina", "strength", "agility", "intellect", "spirit"]
var _stat_labels: Dictionary = {}
var _pedestals: Array = []            # ordered pedestal defs (Array[Dictionary])
var _by_id: Dictionary = {}           # id -> def

var _font: FontFile = null
var _panel_tex: Texture2D = null

# --- live UI state (only valid while open) ---------------------------------
var is_open: bool = false
var _confirmed: bool = false
var _focus: int = 0
var _layer: CanvasLayer = null
var _root: Control = null

var _rows: Array = []                 # per-pedestal {root, style, sprite, base, glow}
var _stage_holder: Control = null     # central hero mount point
var _stage_hero: Node = null          # current central hero node (sprite/placeholder)
var _stage_tween: Tween = null
var _glow_tween: Tween = null
var _name_label: Label = null
var _tagline_label: Label = null
var _playstyle_label: Label = null
var _lore_label: Label = null
var _ability_rows: Array = []         # [{icon:TextureRect, name:Label, blurb:Label}]
var _stat_bars: Array = []            # [{fill:ColorRect, label:Label, key:String}]


func _ready() -> void:
	_load_data()
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile
	if ResourceLoader.exists(PANEL_TEX_PATH):
		_panel_tex = load(PANEL_TEX_PATH) as Texture2D
	# Self-test / screenshot hooks fire deferred (need no world or player).
	if not OS.get_environment("RH_SELECT_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_SELECT").is_empty() \
			or OS.get_environment("RH_SHOT").to_lower().find("select") != -1:
		call_deferred("open_select")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_title = str(root.get("title", _title))
	_subtitle = str(root.get("subtitle", _subtitle))
	if root.get("primaries", null) is Array:
		_primaries = (root["primaries"] as Array).duplicate()
	_stat_labels = _dict(root.get("stat_labels", {}))
	_pedestals.clear()
	_by_id.clear()
	for entry: Variant in _arr(root.get("pedestals", [])):
		if entry is Dictionary:
			var e: Dictionary = entry
			_pedestals.append(e)
			_by_id[str(e.get("id", ""))] = e
	if _pedestals.is_empty():
		push_warning("SelectScreenSystem: no pedestals loaded from %s" % DATA_PATH)


# --- public data queries ----------------------------------------------------

func class_count() -> int:
	return _pedestals.size()


func class_ids() -> Array:
	var out: Array = []
	for e: Dictionary in _pedestals:
		out.append(str(e.get("id", "")))
	return out


func pedestal_def(id: String) -> Dictionary:
	return _dict(_by_id.get(id, {}))


func is_select_open() -> bool:
	return is_open


func highlighted_index() -> int:
	return _focus


func highlighted_class() -> String:
	if _focus >= 0 and _focus < _pedestals.size():
		return str((_pedestals[_focus] as Dictionary).get("id", ""))
	return ""


# --- open / close -----------------------------------------------------------

func open_select() -> void:
	if is_open and _layer != null and is_instance_valid(_layer):
		return
	if _pedestals.is_empty():
		push_warning("SelectScreenSystem.open_select: nothing to show.")
		return
	_confirmed = false
	_focus = 0
	_build_layer()
	is_open = true
	_apply_focus(true)
	select_opened.emit()


func close_select() -> void:
	is_open = false
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
	_stage_tween = null
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_root = null
	_rows.clear()
	_ability_rows.clear()
	_stat_bars.clear()
	_stage_holder = null
	_stage_hero = null
	_name_label = null
	_tagline_label = null
	_playstyle_label = null
	_lore_label = null


# --- navigation -------------------------------------------------------------

func cycle(dir: int) -> void:
	if not is_open or _confirmed or _pedestals.is_empty():
		return
	var n: int = _pedestals.size()
	_focus = (_focus + (1 if dir >= 0 else -1) + n) % n
	_apply_focus(false)


func highlight(index: int) -> void:
	if not is_open or _confirmed or _pedestals.is_empty():
		return
	if index < 0 or index >= _pedestals.size() or index == _focus:
		return
	_focus = index
	_apply_focus(false)


func confirm() -> void:
	if not is_open or _confirmed or _pedestals.is_empty():
		return
	_confirmed = true
	var id: String = highlighted_class()
	class_selected.emit(id)
	close_select()


# --- input (only while the screen is open) ----------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or _confirmed:
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		cycle(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		cycle(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		confirm()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_select()


# --- layer construction (pure code CanvasLayer) -----------------------------

func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 45
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_to_group("select_ui")
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_build_backdrop()
	_build_header()
	_build_stage()
	_build_pedestal_row()
	_build_info_panel()
	_build_hint()


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = BG_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	# Handcrafted kit (owner 2026-07-12): candlelit cathedral hall backdrop.
	var hall_path := "res://assets/art/ui/kit/select_backdrop.png"
	if ResourceLoader.exists(hall_path):
		var hall := TextureRect.new()
		hall.texture = load(hall_path)
		hall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hall.set_anchors_preset(Control.PRESET_FULL_RECT)
		hall.modulate = Color(0.62, 0.58, 0.60)
		hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(hall)

	var glow := TextureRect.new()
	glow.texture = _radial(EMBER_GLOW, Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.0), 0.0, 1.0)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ember pool centred on the stage, not the whole screen.
	glow.position = Vector2(40.0, 40.0)
	glow.size = Vector2(360.0, 280.0)
	_root.add_child(glow)

	var vignette := TextureRect.new()
	vignette.texture = _radial(Color(0.0, 0.0, 0.0, 0.0), VIGNETTE_EDGE, 0.55, 1.0)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(vignette)


func _build_header() -> void:
	var tshadow := _label(_title, 22, Color(0.0, 0.0, 0.0, 0.75))
	tshadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tshadow.position = Vector2(13.5, 13.5)
	tshadow.size = Vector2(BASE_W - 24.0, 26.0)
	_root.add_child(tshadow)
	var title := _label(_title, 22, GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(12.0, 12.0)
	title.size = Vector2(BASE_W - 24.0, 26.0)
	_root.add_child(title)

	var sub := _label(_subtitle, 11, GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(12.0, 36.0)
	sub.size = Vector2(BASE_W - 24.0, 14.0)
	_root.add_child(sub)


func _build_stage() -> void:
	# The central pedestal: a brazier glow, a stone dais, and the mount point where
	# the highlighted hero stands and idle-pulses.
	var stage_cx: float = 210.0
	var stage_base_y: float = 232.0

	var brazier := TextureRect.new()
	brazier.texture = _radial(Color(1.0, 0.62, 0.28, 0.30), Color(1.0, 0.5, 0.2, 0.0), 0.0, 1.0)
	brazier.stretch_mode = TextureRect.STRETCH_SCALE
	brazier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brazier.position = Vector2(stage_cx - 110.0, 70.0)
	brazier.size = Vector2(220.0, 200.0)
	_root.add_child(brazier)
	# Hot inner core behind the hero (the D2 campfire read).
	var core := TextureRect.new()
	core.texture = _radial(Color(1.0, 0.74, 0.36, 0.42), Color(1.0, 0.55, 0.2, 0.0), 0.0, 1.0)
	core.stretch_mode = TextureRect.STRETCH_SCALE
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.position = Vector2(stage_cx - 55.0, 150.0)
	core.size = Vector2(110.0, 100.0)
	_root.add_child(core)
	# Flanking animated torches (Szadi catacombs strip, 4 frames).
	var torch_tex_path := "res://assets/art/world/civic/torch_anim_strip.png"
	if ResourceLoader.exists(torch_tex_path):
		var ttex: Texture2D = load(torch_tex_path)
		var fw: int = ttex.get_width() / 4
		for side: float in [-1.0, 1.0]:
			var sfr := SpriteFrames.new()
			sfr.set_animation_speed("default", 8.0)
			for fi in range(4):
				var at := AtlasTexture.new()
				at.atlas = ttex
				at.region = Rect2(fi * fw, 0, fw, ttex.get_height())
				sfr.add_frame("default", at)
			var tspr := AnimatedSprite2D.new()
			tspr.sprite_frames = sfr
			tspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tspr.position = Vector2(stage_cx + side * 96.0, stage_base_y - 6.0)
			tspr.scale = Vector2.ONE * 1.3
			tspr.play("default")
			_root.add_child(tspr)
			var tglow := TextureRect.new()
			tglow.texture = _radial(Color(1.0, 0.66, 0.3, 0.28), Color(1.0, 0.5, 0.2, 0.0), 0.0, 1.0)
			tglow.stretch_mode = TextureRect.STRETCH_SCALE
			tglow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tglow.position = Vector2(stage_cx + side * 96.0 - 30.0, stage_base_y - 42.0)
			tglow.size = Vector2(60.0, 60.0)
			_root.add_child(tglow)
	# Rising embers over the stage.
	var embers := CPUParticles2D.new()
	embers.amount = 16
	embers.lifetime = 3.2
	embers.preprocess = 3.0
	embers.position = Vector2(stage_cx, stage_base_y + 6.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(96.0, 4.0)
	embers.direction = Vector2(0, -1)
	embers.spread = 12.0
	embers.gravity = Vector2(0, -14.0)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 0.6
	embers.scale_amount_max = 1.6
	embers.color = Color(1.0, 0.62, 0.24, 0.85)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.3, 0.9))
	ramp.set_color(1, Color(0.6, 0.2, 0.05, 0.0))
	embers.color_ramp = ramp
	_root.add_child(embers)
	# Ground shadow under the hero, ON the dais.
	var hshadow := TextureRect.new()
	hshadow.texture = _radial(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0), 0.0, 1.0)
	hshadow.stretch_mode = TextureRect.STRETCH_SCALE
	hshadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hshadow.position = Vector2(stage_cx - 34.0, stage_base_y - 4.0)
	hshadow.size = Vector2(68.0, 18.0)
	_root.add_child(hshadow)
	# Torch flicker on the brazier.
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(brazier, "modulate:a", 0.62, 0.7).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(brazier, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

	# Handcrafted stone dais (kit) — squashed for the 3/4 read; the old flat
	# pill read as an empty box (sitting finding).
	var dais_path := "res://assets/art/ui/kit/stone_dais.png"
	if ResourceLoader.exists(dais_path):
		var dais := TextureRect.new()
		dais.texture = load(dais_path)
		dais.stretch_mode = TextureRect.STRETCH_SCALE
		dais.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dais.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dais.position = Vector2(stage_cx - 60.0, stage_base_y - 34.0)
		dais.size = Vector2(120.0, 52.0)
		_root.add_child(dais)
	else:
		var dais := Panel.new()
		dais.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dais.position = Vector2(stage_cx - 52.0, stage_base_y - 4.0)
		dais.size = Vector2(104.0, 18.0)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0.17, 0.145, 0.125, 0.96)
		dsb.set_border_width_all(2)
		dais.add_theme_stylebox_override("panel", dsb)
		_root.add_child(dais)

	# Mount point for the central hero (a zero-size Control; hero node positions
	# itself so its feet meet the dais top).
	_stage_holder = Control.new()
	_stage_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_holder.position = Vector2(stage_cx, stage_base_y)
	_stage_holder.size = Vector2.ZERO
	_root.add_child(_stage_holder)

	# Name + tagline under the dais.
	_name_label = _label("", 16, GOLD_BRIGHT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(stage_cx - 130.0, stage_base_y + 14.0)
	_name_label.size = Vector2(260.0, 20.0)
	_root.add_child(_name_label)

	_tagline_label = _label("", 10, GOLD)
	_tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline_label.position = Vector2(stage_cx - 150.0, stage_base_y + 34.0)
	_tagline_label.size = Vector2(300.0, 13.0)
	_root.add_child(_tagline_label)


func _build_pedestal_row() -> void:
	_rows.clear()
	var n: int = _pedestals.size()
	if n <= 0:
		return
	# A row of small selectable pedestals across the bottom of the hall.
	var strip_left: float = 16.0
	var strip_w: float = 396.0
	var slot_w: float = strip_w / float(n)
	var row_y: float = 326.0  # cells 280..340; nameplate band ends 278
	for i in range(n):
		var e: Dictionary = _pedestals[i]
		var cx: float = strip_left + slot_w * (float(i) + 0.5)

		# Selectable hit-box / frame.
		var cell := Control.new()
		cell.position = Vector2(cx - slot_w * 0.5 + 2.0, row_y - 46.0)
		cell.size = Vector2(slot_w - 4.0, 60.0)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_entered.connect(highlight.bind(i))
		cell.gui_input.connect(_on_cell_gui_input.bind(i))
		_root.add_child(cell)

		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0.10, 0.08, 0.07, 0.85)
		fsb.border_color = PANEL_BORDER
		fsb.set_border_width_all(1)
		fsb.set_corner_radius_all(2)
		frame.add_theme_stylebox_override("panel", fsb)
		cell.add_child(frame)

		# Small hero on the mini-pedestal.
		var sprite: Node2D = _make_hero(e, 1.15, 12.0)
		if sprite != null:
			sprite.position = Vector2((slot_w - 4.0) * 0.5, 44.0)
			cell.add_child(sprite)

		_rows.append({"cell": cell, "style": fsb, "sprite": sprite})


func _build_info_panel() -> void:
	var px: float = 420.0
	var pw: float = BASE_W - px - 12.0

	var panel := NinePatchRect.new()
	var kit_frame := "res://assets/art/ui/kit/panel_frame.png"
	if ResourceLoader.exists(kit_frame):
		panel.texture = load(kit_frame)
		panel.patch_margin_left = 42
		panel.patch_margin_right = 42
		panel.patch_margin_top = 40
		panel.patch_margin_bottom = 40
	elif _panel_tex != null:
		panel.texture = _panel_tex
		panel.patch_margin_left = 8
		panel.patch_margin_right = 8
		panel.patch_margin_top = 8
		panel.patch_margin_bottom = 8
	panel.position = Vector2(px, 52.0)
	panel.size = Vector2(pw, 298.0)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 5
	bg.offset_top = 5
	bg.offset_right = -5
	bg.offset_bottom = -5
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	var pad: float = 12.0
	var inner_w: float = pw - pad * 2.0
	var content := VBoxContainer.new()
	content.position = Vector2(pad, pad)
	content.size = Vector2(inner_w, 298.0 - pad * 2.0)
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	_playstyle_label = _wrap("", 9, GOLD, inner_w)
	content.add_child(_playstyle_label)

	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(inner_w, 1.0)
	content.add_child(rule)

	_lore_label = _wrap("", 9, PARCHMENT, inner_w)
	content.add_child(_lore_label)

	content.add_child(_spacer(2.0))
	var ab_head := _label("SIGNATURE ABILITIES", 10, GOLD_BRIGHT)
	content.add_child(ab_head)

	# Up to four ability rows (icon + name + blurb).
	_ability_rows.clear()
	for j in range(4):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16.0, 16.0)
		# Without EXPAND_IGNORE_SIZE a TextureRect's minimum size is the raw
		# texture (128px painterly icons) — it detonated the whole panel layout
		# off the right screen edge. THE select-screen bug.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := _label("", 9, GOLD)
		col.add_child(nm)
		var bl := _wrap("", 8, DIM, inner_w - 22.0)
		col.add_child(bl)
		row.add_child(col)

		content.add_child(row)
		_ability_rows.append({"row": row, "icon": icon, "name": nm, "blurb": bl})

	content.add_child(_spacer(2.0))
	var st_head := _label("PRIMARY BIAS", 10, GOLD_BRIGHT)
	content.add_child(st_head)

	# Stat bias bars (one per primary).
	_stat_bars.clear()
	for key: Variant in _primaries:
		var k: String = str(key)
		var brow := HBoxContainer.new()
		brow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_theme_constant_override("separation", 4)
		brow.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var tag := _label(str(_stat_labels.get(k, k.substr(0, 3).to_upper())), 8, PARCHMENT)
		tag.custom_minimum_size = Vector2(26.0, 10.0)
		brow.add_child(tag)

		var track := Panel.new()
		track.custom_minimum_size = Vector2(inner_w - 34.0, 8.0)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.06, 0.05, 0.05, 0.9)
		tsb.border_color = Color(0.28, 0.22, 0.16)
		tsb.set_border_width_all(1)
		track.add_theme_stylebox_override("panel", tsb)
		brow.add_child(track)

		var fill := ColorRect.new()
		fill.color = GOLD
		fill.position = Vector2(1.0, 1.0)
		fill.size = Vector2(0.0, 6.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)

		content.add_child(brow)
		_stat_bars.append({"key": k, "fill": fill, "track": track})


func _build_hint() -> void:
	var hint := _label("<  >  cycle      Enter  begin      Esc  back", 9, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(12.0, BASE_H - 18.0)
	hint.size = Vector2(BASE_W - 24.0, 14.0)
	_root.add_child(hint)


# --- focus application ------------------------------------------------------

func _apply_focus(initial: bool) -> void:
	if _root == null or _pedestals.is_empty():
		return
	_focus = clampi(_focus, 0, _pedestals.size() - 1)
	# Row highlight.
	for i in range(_rows.size()):
		var r: Dictionary = _rows[i]
		var focused: bool = i == _focus
		var style: StyleBoxFlat = r.get("style")
		if style != null:
			style.border_color = GOLD_BRIGHT if focused else PANEL_BORDER
			style.set_border_width_all(2 if focused else 1)
		var spr: Variant = r.get("sprite")
		if spr is AnimatedSprite2D:
			var anim: StringName = &"walk_down" if focused else &"idle_down"
			var asp := spr as AnimatedSprite2D
			if asp.sprite_frames != null and asp.sprite_frames.has_animation(anim) and asp.animation != anim:
				asp.play(anim)
	_rebuild_stage_hero()
	_refresh_panel()
	if not initial:
		class_highlighted.emit(highlighted_class())


func _rebuild_stage_hero() -> void:
	if _stage_holder == null:
		return
	if _stage_tween != null and _stage_tween.is_valid():
		_stage_tween.kill()
		_stage_tween = null
	if _stage_hero != null and is_instance_valid(_stage_hero):
		_stage_hero.queue_free()
	_stage_hero = null
	var e: Dictionary = _pedestals[_focus]
	var hero: Node2D = _make_hero(e, 3.0, 0.0)
	if hero == null:
		return
	# Feet meet the dais (empirical +16: the szadi centre/offset math left a
	# visible hover above the slab — sitting screenshot-verified).
	hero.position = Vector2(0.0, 16.0)
	_stage_holder.add_child(hero)
	_stage_hero = hero
	# Idle pulse (a slow breathing scale on the whole hero node).
	var base: Vector2 = hero.scale
	_stage_tween = create_tween().set_loops()
	_stage_tween.tween_property(hero, "scale", base * 1.06, 0.9).set_trans(Tween.TRANS_SINE)
	_stage_tween.tween_property(hero, "scale", base, 0.9).set_trans(Tween.TRANS_SINE)


func _refresh_panel() -> void:
	var e: Dictionary = _pedestals[_focus]
	var col: Color = _color(e.get("color", [0.85, 0.68, 0.35]))
	if _name_label != null:
		_name_label.text = str(e.get("name", "")).to_upper()
		_name_label.add_theme_color_override("font_color", _lift(col))
	if _tagline_label != null:
		_tagline_label.text = str(e.get("tagline", ""))
	if _playstyle_label != null:
		_playstyle_label.text = _join(_arr(e.get("playstyle", [])), "  /  ")

	if _lore_label != null:
		_lore_label.text = str(e.get("lore", ""))

	var abilities: Array = _arr(e.get("abilities", []))
	for j in range(_ability_rows.size()):
		var ar: Dictionary = _ability_rows[j]
		var row: Control = ar.get("row")
		if j < abilities.size() and abilities[j] is Dictionary:
			var a: Dictionary = abilities[j]
			if row != null:
				row.visible = true
			(ar.get("name") as Label).text = str(a.get("name", ""))
			(ar.get("blurb") as Label).text = str(a.get("blurb", ""))
			var icon := ar.get("icon") as TextureRect
			var tex: Texture2D = _icon_tex(str(a.get("icon", "")))
			icon.texture = tex
			icon.visible = tex != null
		else:
			if row != null:
				row.visible = false

	# Stat bias bars, normalised against this class's own peak primary.
	var bias: Dictionary = _dict(e.get("stat_bias", {}))
	var peak: float = 1.0
	for key: Variant in _primaries:
		peak = maxf(peak, float(bias.get(str(key), 0.0)))
	for sb: Dictionary in _stat_bars:
		var k: String = str(sb.get("key", ""))
		var frac: float = clampf(float(bias.get(k, 0.0)) / peak, 0.0, 1.0)
		var track: Panel = sb.get("track")
		var fill: ColorRect = sb.get("fill")
		if fill != null:
			var tw: float = 40.0
			if track != null and track.size.x > 2.0:
				tw = track.size.x - 2.0
			fill.size = Vector2(maxf(2.0, tw * frac), 6.0)
			fill.color = _lift(col)


# --- hero builder (real szadi sheet, else labelled placeholder) -------------

## Returns a Node2D holding an animated hero if the class sheet resolves, else a
## Control placeholder silhouette. Never returns a node that errors headless.
func _make_hero(e: Dictionary, scale: float, _feet_pad: float) -> Node2D:
	var portrait: Dictionary = _dict(e.get("portrait", {}))
	var sheet: String = str(portrait.get("sheet", ""))
	var variant: int = int(portrait.get("variant", 0))
	var col: Color = _color(e.get("color", [0.7, 0.7, 0.7]))
	if sheet != "" and ResourceLoader.exists(sheet):
		var frames: SpriteFrames = _build_frames(sheet, variant)
		if frames != null:
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = frames
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(scale, scale)
			spr.centered = true
			# szadi frame is 32x48, node centre -> lift so feet sit near y=0.
			spr.offset = Vector2(0.0, -22.0)
			if frames.has_animation(&"idle_down"):
				spr.play(&"idle_down")
			return spr
	return _make_placeholder(e, col, scale)


func _build_frames(sheet: String, variant: int) -> SpriteFrames:
	# Use the shared szadi factory exactly like scripts/class_select.gd; guard the
	# whole call so a bad sheet degrades to the placeholder instead of erroring.
	var frames: SpriteFrames = SheetAnim.make_szadi_frames(sheet, variant)
	return frames


func _make_placeholder(e: Dictionary, col: Color, scale: float) -> Node2D:
	# A labelled silhouette: a coloured body block, a shadow, and the class initial.
	var holder := Node2D.new()
	holder.scale = Vector2(scale, scale)

	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse(13.0, 4.0, Vector2(0.0, 0.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	holder.add_child(shadow)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-7.0, -34.0), Vector2(7.0, -34.0),
		Vector2(9.0, -4.0), Vector2(-9.0, -4.0),
	])
	body.color = Color(col.r * 0.7 + 0.08, col.g * 0.7 + 0.08, col.b * 0.7 + 0.08, 0.95)
	holder.add_child(body)

	var head := Polygon2D.new()
	head.polygon = _ellipse(6.0, 6.5, Vector2(0.0, -40.0))
	head.color = Color(col.r * 0.85 + 0.1, col.g * 0.85 + 0.1, col.b * 0.85 + 0.1, 0.98)
	holder.add_child(head)

	var initial := str(e.get("name", "?"))
	var lbl := Label.new()
	lbl.text = initial.substr(0, 1).to_upper() if initial != "" else "?"
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	lbl.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-6.0, -48.0)
	lbl.size = Vector2(12.0, 14.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(lbl)
	return holder


func _on_cell_gui_input(event: InputEvent, index: int) -> void:
	if not is_open or _confirmed:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if index == _focus:
				confirm()
			else:
				highlight(index)


# --- small builders / helpers -----------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, size: int, color: Color, width: float) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(maxf(30.0, width), 0.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _icon_tex(raw: String) -> Texture2D:
	if raw == "":
		return null
	if raw.begins_with("pixel:"):
		var t: Variant = IconsPixel.get_tex(raw)
		return t as Texture2D
	if raw.begins_with("res://") and ResourceLoader.exists(raw):
		return load(raw) as Texture2D
	return null


func _radial(inner: Color, outer: Color, inner_stop: float, outer_stop: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([inner_stop, outer_stop])
	g.colors = PackedColorArray([inner, outer])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 192
	return tex


func _ellipse(rx: float, ry: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _lift(c: Color) -> Color:
	return Color(minf(1.0, c.r * 1.15 + 0.12), minf(1.0, c.g * 1.15 + 0.12), minf(1.0, c.b * 1.15 + 0.12), 1.0)


func _color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var alpha: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(1, 1, 1, 1)


func _join(a: Array, sep: String) -> String:
	var parts: Array = []
	for v: Variant in a:
		parts.append(str(v))
	return sep.join(parts)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("SelectScreenSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- self-test (RH_SELECT_TEST=1) -------------------------------------------

func _run_selftest() -> void:
	# Wait a couple of frames so the tree is ready (no world/player needed).
	for _i in range(3):
		await get_tree().process_frame
	var n: int = _pedestals.size()
	var ok: bool = true
	var notes: Array = []

	# 1) Open.
	var opened: Array = [false]
	var open_cb := func() -> void: opened[0] = true
	select_opened.connect(open_cb)
	open_select()
	await get_tree().process_frame
	if not is_open or _layer == null or not is_instance_valid(_layer):
		ok = false
		notes.append("open failed")
	if not opened[0]:
		ok = false
		notes.append("select_opened not emitted")
	select_opened.disconnect(open_cb)

	# 2) Cycle through every class; assert the highlight index moves AND the lore
	#    blurb text on the live panel changes as we go.
	var visited: Dictionary = {}
	var hi_events: Array = []
	var hi_cb := func(cid: Variant) -> void: hi_events.append(str(cid))
	class_highlighted.connect(hi_cb)
	var last_lore: String = _lore_label.text if _lore_label != null else ""
	var lore_changes: int = 0
	visited[_focus] = true
	for _k in range(n):
		var prev_idx: int = _focus
		cycle(1)
		await get_tree().process_frame
		if _focus == prev_idx and n > 1:
			ok = false
			notes.append("index did not move")
		visited[_focus] = true
		var cur_lore: String = _lore_label.text if _lore_label != null else ""
		if cur_lore != last_lore:
			lore_changes += 1
		last_lore = cur_lore
	class_highlighted.disconnect(hi_cb)
	if visited.size() != n:
		ok = false
		notes.append("visited %d of %d" % [visited.size(), n])
	if n > 1 and lore_changes < 1:
		ok = false
		notes.append("blurb never updated")
	if hi_events.size() < n:
		ok = false
		notes.append("class_highlighted fired %d < %d" % [hi_events.size(), n])

	# 3) Confirm the current class; assert class_selected carries a valid id and
	#    that the layer is torn down (freed).
	var layer_ref: CanvasLayer = _layer
	var picked: Array = [""]
	var pick_cb := func(cid: Variant) -> void: picked[0] = str(cid)
	class_selected.connect(pick_cb)
	var want: String = highlighted_class()
	confirm()
	class_selected.disconnect(pick_cb)
	if picked[0] == "" or not _by_id.has(picked[0]):
		ok = false
		notes.append("class_selected id invalid ('%s')" % picked[0])
	if picked[0] != want:
		ok = false
		notes.append("selected '%s' != highlighted '%s'" % [picked[0], want])
	if is_open:
		ok = false
		notes.append("still open after confirm")
	# Let the queued free settle.
	await get_tree().process_frame
	await get_tree().process_frame
	if layer_ref != null and is_instance_valid(layer_ref):
		ok = false
		notes.append("layer not freed")

	var tail: String = "" if notes.is_empty() else ("  [" + "; ".join(PackedStringArray(notes)) + "]")
	print("SELECT SELFTEST %s classes=%d picked=%s%s" % [
		("PASS" if ok else "FAIL"), n, picked[0], tail])
