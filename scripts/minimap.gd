class_name Minimap
extends CanvasLayer
## Minimap + world map for Raven Hollow. Layer 8, group "minimap", built in code.
##
## v9 REWRITE (2026-09-23, owner: "fully revamp the mini map, dots on the maps
## is absolutely unacceptable"). The old minimap squeezed the whole 7168x5120
## city into a 70x70 thumbnail and drew everything as 2x2 coloured dots, so a
## house was one and a half pixels and nothing could be read.
##
## What it does now, following the conventions of CrossCode, Moonlighter, Core
## Keeper, Graveyard Keeper and Zelda:
##   * the minimap is a SCROLLING WINDOW that follows the player at a fixed,
##     readable scale (WORLD_PER_PX world px per minimap px) instead of a
##     squeezed whole-map thumbnail;
##   * places are ICONS with a dark outline - a keep, a church cross, a market
##     awning, a tankard, an anchor, a well, a gate arch, a mill - never dots;
##   * icons for places outside the window clamp to the rim as small arrows, so
##     the player always knows which way the harbour is;
##   * a compass N on the rim, the clock under it, and the district name fading
##     in when you walk into a new quarter;
##   * M opens a full world map on parchment: the same icons with labels, quest
##     pins, travel points, the player arrow, a legend, and zoom/pan.
##
## Public API (unchanged, main.gd::_refresh_minimap calls set_map):
##   set_map(map_id, bounds, travel_points := [], display_name := "")
##   is_world_map_open() -> bool

const GOLD := Color(0.88, 0.72, 0.38)
const GOLD_DIM := Color(0.62, 0.50, 0.26)
const PARCHMENT := Color(0.90, 0.85, 0.74)
const INK := Color(0.16, 0.11, 0.08)
const INK_SOFT := Color(0.28, 0.20, 0.14)
const HOSTILE_RED := Color(0.86, 0.28, 0.22)
const QUEST_GOLD := Color(1.0, 0.84, 0.35)
const BOX_BG := Color(0.07, 0.06, 0.05, 0.98)
const OUTLINE_DARK := Color(0.06, 0.04, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const PARCH_BG := Color(0.74, 0.67, 0.52)
const MAP_FALLBACK := Color(0.30, 0.33, 0.22)

const MAP_DIR := "res://assets/art/maps/"
const DEFAULT_MAP_ID := "town"
const DEFAULT_BOUNDS := Rect2(0.0, 0.0, 7168.0, 5120.0)

## Minimap geometry in the 640x360 design space (top-right).
const MARGIN: float = 8.0
const MAP_SIZE: float = 84.0
const RIM_PAD: float = 5.0
const FRAME: float = MAP_SIZE + RIM_PAD * 2.0
const CLOCK_H: float = 12.0
## World px per minimap px. 13 -> the 84 px window shows ~1090 world px, about
## three screens wide: a house is 12 px and a street reads as a street.
const WORLD_PER_PX: float = 13.0

const OVERLAY_LAYER: int = 12
const PANEL_W: float = 560.0
const PANEL_H: float = 340.0
const CONTENT := Rect2(14.0, 34.0, 532.0, 258.0)

const DISPLAY_NAMES: Dictionary = {
	"town": "Raven Hollow",
	"wilderness": "The Emberfall Road",
}

## Places worth an icon. kind drives the glyph (see _draw_icon).
## {pos, kind, label, minimap: show on the small map too}
const PLACES: Dictionary = {
	"town": [
		{"pos": Vector2(1120, 800), "kind": "home", "label": "The Hollow", "minimap": true},
		{"pos": Vector2(1548, 864), "kind": "anvil", "label": "Smithy", "minimap": true},
		{"pos": Vector2(1120, 640), "kind": "inn", "label": "The Ember Hearth", "minimap": true},
		{"pos": Vector2(448, 470), "kind": "grave", "label": "Old Cemetery", "minimap": true},
		{"pos": Vector2(2240, 816), "kind": "gate", "label": "The Old Gate", "minimap": true},
		{"pos": Vector2(2620, 1330), "kind": "horse", "label": "Horse Fair", "minimap": true},
		{"pos": Vector2(2500, 440), "kind": "garrison", "label": "Burned Garrison", "minimap": true},
		{"pos": Vector2(3300, 1180), "kind": "market", "label": "Trade Square", "minimap": true},
		{"pos": Vector2(3600, 560), "kind": "keep", "label": "The Vigil Keep", "minimap": true},
		{"pos": Vector2(5400, 900), "kind": "church", "label": "The Cathedral", "minimap": true},
		{"pos": Vector2(6620, 900), "kind": "candle", "label": "The Candle-House", "minimap": true},
		{"pos": Vector2(2380, 2560), "kind": "well", "label": "Well Square", "minimap": true},
		{"pos": Vector2(3080, 3690), "kind": "inn", "label": "The Drowned Rat", "minimap": true},
		{"pos": Vector2(5420, 2560), "kind": "market", "label": "Ward Square", "minimap": true},
		{"pos": Vector2(3080, 4400), "kind": "anchor", "label": "The Harbour", "minimap": true},
		{"pos": Vector2(7000, 2600), "kind": "gate", "label": "The East Gate", "minimap": true},
		{"pos": Vector2(1100, 3060), "kind": "granary", "label": "The Granary", "minimap": true},
		{"pos": Vector2(1320, 4420), "kind": "mill", "label": "The Mill", "minimap": true},
		{"pos": Vector2(520, 2010), "kind": "church", "label": "Ashen Chapel", "minimap": true},
		{"pos": Vector2(6840, 3900), "kind": "burned", "label": "Burned Farmstead", "minimap": true},
		{"pos": Vector2(1900, 4960), "kind": "boat", "label": "The Ferry", "minimap": true},
	],
}

## Quarter names drawn on the world map and announced under the minimap.
const DISTRICTS: Dictionary = {
	"town": [

		{"pos": Vector2(2650, 980), "text": "The Approach", "r": 520.0},
		{"pos": Vector2(3150, 2800), "text": "Old Town", "r": 1150.0},
		{"pos": Vector2(5600, 3300), "text": "The East Ward", "r": 1300.0},
		{"pos": Vector2(1100, 3000), "text": "The Fields", "r": 1500.0},
		{"pos": Vector2(6650, 3800), "text": "The SE Commons", "r": 800.0},
	],
}

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _map_id: String = DEFAULT_MAP_ID
var _bounds: Rect2 = DEFAULT_BOUNDS
var _travel_world: PackedVector2Array = PackedVector2Array()
var _map_tex: Texture2D = null

var _root: Control
var _view: MapView
var _clock: Label
var _district: Label

var _overlay: CanvasLayer
var _overlay_title: Label
var _overlay_map: WorldMapView
var _legend: LegendStrip

var _player_angle: float = 0.0
var _district_name: String = ""
var _district_fade: float = 0.0


func _init() -> void:
	name = "Minimap"


func _ready() -> void:
	layer = 8
	add_to_group("minimap")

	_root = Control.new()
	_root.name = "MinimapRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	_build_frame()
	_build_overlay()
	set_map(DEFAULT_MAP_ID, DEFAULT_BOUNDS)
	# QA hook: RH_MAPOPEN=1 boots with the world map up so a screenshot can
	# check it without a key press.
	if OS.get_environment("RH_MAPOPEN") != "":
		_overlay.visible = true


func _process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var alive: bool = player != null and is_instance_valid(player)
	_root.visible = alive
	if not alive:
		if _overlay.visible:
			_overlay.visible = false
		return

	var vel_v: Variant = player.get("velocity")
	if vel_v is Vector2 and (vel_v as Vector2).length_squared() > 16.0:
		_player_angle = (vel_v as Vector2).angle()

	_view.map_id = _map_id
	_view.player_pos = player.global_position
	_view.player_angle = _player_angle
	_view.enemy_pts = _collect_group_points("enemies", true)
	_view.pins = _collect_quest_pins()
	_view.queue_redraw()

	_clock.text = _clock_text()
	_clock.visible = not _clock.text.is_empty()
	_tick_district(player.global_position, delta)

	if _overlay.visible:
		_overlay_map.player_pos = player.global_position
		_overlay_map.player_angle = _player_angle
		_overlay_map.pins = _view.pins
		_overlay_map.queue_redraw()


## The quarter name fades in for a few seconds when the player crosses into it.
func _tick_district(pos: Vector2, delta: float) -> void:
	var here: String = ""
	var best: float = INF
	for d_v: Variant in (DISTRICTS.get(_map_id, []) as Array):
		var d: Dictionary = d_v
		var dist: float = pos.distance_to(d["pos"] as Vector2)
		if dist < float(d["r"]) and dist < best:
			best = dist
			here = str(d["text"])
	if here != _district_name:
		_district_name = here
		_district_fade = 3.6 if not here.is_empty() else 0.0
		_district.text = here
	if _district_fade > 0.0:
		_district_fade -= delta
		var a: float = clampf(_district_fade, 0.0, 1.0)
		_district.modulate = Color(1, 1, 1, a if _district_fade < 1.0 else 1.0)
		_district.visible = true
	else:
		_district.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action("map"):
		return
	if event.is_action_pressed("map"):
		if _root.visible or _overlay.visible:
			_overlay.visible = not _overlay.visible
			if _overlay.visible:
				_overlay_map.zoom = 1.0
				_overlay_map.pan = Vector2.ZERO
			get_viewport().set_input_as_handled()
	elif _overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_overlay.visible = false
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and (event as InputEventKey).pressed:
			var k: int = (event as InputEventKey).keycode
			if k == KEY_EQUAL or k == KEY_KP_ADD:
				_overlay_map.zoom = minf(_overlay_map.zoom * 1.5, 4.0)
				_overlay_map.queue_redraw()
				get_viewport().set_input_as_handled()
			elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
				_overlay_map.zoom = maxf(_overlay_map.zoom / 1.5, 1.0)
				_overlay_map.pan = Vector2.ZERO if _overlay_map.zoom <= 1.0 else _overlay_map.pan
				_overlay_map.queue_redraw()
				get_viewport().set_input_as_handled()


func is_world_map_open() -> bool:
	return _overlay.visible


func set_map(map_id: String, bounds: Rect2, travel_points: Array = [],
		display_name: String = "") -> void:
	_map_id = map_id
	_bounds = bounds if bounds.size.x > 0.0 and bounds.size.y > 0.0 else DEFAULT_BOUNDS
	_travel_world = PackedVector2Array()
	for tp_v: Variant in travel_points:
		if tp_v is Dictionary:
			var pos_v: Variant = (tp_v as Dictionary).get("pos")
			if pos_v is Vector2:
				_travel_world.append(pos_v)
	_map_tex = _load_map_texture(map_id)

	var places: Array = PLACES.get(map_id, [])
	_view.tex = _map_tex
	_view.bounds = _bounds
	_view.travel_pts = _travel_world
	_view.places = places
	_view.queue_redraw()

	_overlay_map.tex = _map_tex
	_overlay_map.bounds = _bounds
	_overlay_map.travel_pts = _travel_world
	_overlay_map.places = places
	_overlay_map.districts = DISTRICTS.get(map_id, [])
	_overlay_map.queue_redraw()

	var title: String = display_name
	if title.is_empty():
		title = str(DISPLAY_NAMES.get(map_id, map_id.capitalize()))
	_overlay_title.text = title


# --- construction ------------------------------------------------------------

func _build_frame() -> void:
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.offset_left = -(MARGIN + FRAME)
	frame.offset_right = -MARGIN
	frame.offset_top = MARGIN
	frame.offset_bottom = MARGIN + FRAME
	_root.add_child(frame)

	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(FRAME - 6.0, FRAME - 6.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	fill.add_theme_stylebox_override("panel", sb)
	frame.add_child(fill)

	_view = MapView.new()
	_view.name = "MapView"
	_view.position = Vector2(RIM_PAD, RIM_PAD)
	_view.size = Vector2(MAP_SIZE, MAP_SIZE)
	_view.font = _font
	frame.add_child(_view)

	var rim := NinePatchRect.new()
	rim.name = "Rim"
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture = _panel_tex
	rim.draw_center = false
	rim.patch_margin_left = 10
	rim.patch_margin_right = 10
	rim.patch_margin_top = 10
	rim.patch_margin_bottom = 10
	rim.modulate = FRAME_TINT
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(rim)

	var ring := TextureRect.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.texture = load("res://assets/art/ui/minimap_ring.png")
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.position = Vector2(RIM_PAD, RIM_PAD)
	ring.size = Vector2(MAP_SIZE, MAP_SIZE)
	frame.add_child(ring)

	_clock = Label.new()
	_clock.name = "Clock"
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.add_theme_font_override("font", _font)
	_clock.add_theme_font_size_override("font_size", 10)
	_clock.add_theme_color_override("font_color", PARCHMENT)
	_clock.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_clock.add_theme_constant_override("outline_size", 2)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -(MARGIN + FRAME)
	_clock.offset_right = -MARGIN
	_clock.offset_top = MARGIN + FRAME + 1.0
	_clock.offset_bottom = MARGIN + FRAME + 1.0 + CLOCK_H
	_root.add_child(_clock)

	_district = Label.new()
	_district.name = "District"
	_district.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_district.add_theme_font_override("font", _font)
	_district.add_theme_font_size_override("font_size", 11)
	_district.add_theme_color_override("font_color", GOLD)
	_district.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_district.add_theme_constant_override("outline_size", 3)
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_district.anchor_left = 1.0
	_district.anchor_right = 1.0
	_district.offset_left = -(MARGIN + FRAME + 130.0)
	_district.offset_right = -MARGIN
	_district.offset_top = MARGIN + FRAME + CLOCK_H + 2.0
	_district.offset_bottom = MARGIN + FRAME + CLOCK_H + 16.0
	_district.visible = false
	_root.add_child(_district)


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "WorldMapOverlay"
	_overlay.layer = OVERLAY_LAYER
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var panel := Control.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-PANEL_W * 0.5, -PANEL_H * 0.5)
	panel.size = Vector2(PANEL_W, PANEL_H)
	_overlay.add_child(panel)

	var parch := TextureRect.new()
	parch.name = "Parchment"
	parch.texture = load("res://assets/art/ui/parchment_free.png")
	parch.stretch_mode = TextureRect.STRETCH_SCALE
	parch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parch.set_anchors_preset(Control.PRESET_FULL_RECT)
	parch.modulate = Color(0.94, 0.90, 0.82)
	parch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(parch)

	var edge := NinePatchRect.new()
	edge.texture = _panel_tex
	edge.draw_center = false
	edge.patch_margin_left = 12
	edge.patch_margin_right = 12
	edge.patch_margin_top = 12
	edge.patch_margin_bottom = 12
	edge.modulate = FRAME_TINT
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(edge)

	_overlay_title = Label.new()
	_overlay_title.add_theme_font_override("font", _font)
	_overlay_title.add_theme_font_size_override("font_size", 20)
	_overlay_title.add_theme_color_override("font_color", INK)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.position = Vector2(0.0, 6.0)
	_overlay_title.size = Vector2(PANEL_W, 24.0)
	_overlay_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_overlay_title)

	_overlay_map = WorldMapView.new()
	_overlay_map.name = "WorldMapView"
	_overlay_map.position = CONTENT.position
	_overlay_map.size = CONTENT.size
	_overlay_map.font = _font
	panel.add_child(_overlay_map)

	_legend = LegendStrip.new()
	_legend.name = "Legend"
	_legend.position = Vector2(14.0, CONTENT.end.y + 4.0)
	_legend.size = Vector2(PANEL_W - 28.0, 34.0)
	_legend.font = _font
	panel.add_child(_legend)


# --- data helpers -------------------------------------------------------------

func _collect_group_points(group: String, skip_dead: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for node: Node in get_tree().get_nodes_in_group(group):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		if skip_dead and node.get("is_dead") == true:
			continue
		pts.append((node as Node2D).global_position)
	return pts


func _collect_quest_pins() -> Array[Dictionary]:
	var pins: Array[Dictionary] = []
	var quests: Node = get_tree().get_first_node_in_group("quests")
	if quests == null or not quests.has_method("map_pins"):
		return pins
	var pins_v: Variant = quests.call("map_pins", _map_id)
	if not (pins_v is Array):
		return pins
	for pin_v: Variant in (pins_v as Array):
		if pin_v is Dictionary and (pin_v as Dictionary).get("pos") is Vector2:
			pins.append(pin_v)
	return pins


func _clock_text() -> String:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn == null:
		return ""
	if dn.has_method("clock_text"):
		return str(dn.call("clock_text"))
	var t: Variant = dn.get("time_of_day")
	if t is float:
		var hh: int = int(floorf(float(t)))
		var mm: int = mini(59, int(roundf((float(t) - float(hh)) * 60.0)))
		return "%02d:%02d" % [hh, mm]
	return ""


static func _load_map_texture(map_id: String) -> Texture2D:
	var path: String = MAP_DIR + map_id + ".png"
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img: Image = Image.load_from_file(global_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


static func _fit_rect(content: Vector2, area: Rect2) -> Rect2:
	if content.x <= 0.0 or content.y <= 0.0:
		return area
	var s: float = minf(area.size.x / content.x, area.size.y / content.y)
	var fit_size: Vector2 = content * s
	return Rect2(area.position + (area.size - fit_size) * 0.5, fit_size)


# --- shared icon vocabulary ----------------------------------------------------

## Every place on either map is one of these glyphs, drawn as pixel shapes with
## a dark outline so they read at 7 px over any ground colour. Never a dot.
static func _draw_icon(ci: CanvasItem, kind: String, at: Vector2, s: float, tint: Color) -> void:
	var o := OUTLINE_DARK
	var px: float = s
	# a soft dark seat under the glyph so it reads over busy ground without
	# looking like a black box on the map
	ci.draw_circle(at, px * 3.1, Color(0.08, 0.06, 0.05, 0.34))
	match kind:
		"quest":
			# a gold lozenge with a stem: the one mark on the minimap that means
			# "go here", so it must not be mistaken for a place you have found
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -3.4) * px, at + Vector2(2.4, -0.6) * px,
				at + Vector2(0.0, 2.2) * px, at + Vector2(-2.4, -0.6) * px]), o)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -2.4) * px, at + Vector2(1.6, -0.5) * px,
				at + Vector2(0.0, 1.4) * px, at + Vector2(-1.6, -0.5) * px]), tint)
			ci.draw_rect(Rect2(at + Vector2(-0.35, 1.0) * px, Vector2(0.7, 2.2) * px), o)
		"keep":
			# crenellated tower
			ci.draw_rect(Rect2(at + Vector2(-2.2, -1.0) * px, Vector2(4.4, 3.6) * px), o)
			ci.draw_rect(Rect2(at + Vector2(-1.8, -0.6) * px, Vector2(3.6, 3.0) * px), tint)
			for bx: float in [-2.2, -0.6, 1.0]:
				ci.draw_rect(Rect2(at + Vector2(bx, -2.6) * px, Vector2(1.2, 1.8) * px), tint)
		"church":
			ci.draw_rect(Rect2(at + Vector2(-0.6, -3.0) * px, Vector2(1.2, 5.4) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.0, -1.8) * px, Vector2(4.0, 1.2) * px), tint)
		"market":
			# awning: a triangle over a counter
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-3.0, -0.4) * px, at + Vector2(0.0, -2.8) * px, at + Vector2(3.0, -0.4) * px]), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.4, -0.2) * px, Vector2(4.8, 2.2) * px), o)
			ci.draw_rect(Rect2(at + Vector2(-2.0, 0.2) * px, Vector2(4.0, 1.4) * px), tint * 0.8)
		"inn":
			# tankard
			ci.draw_rect(Rect2(at + Vector2(-1.8, -2.0) * px, Vector2(3.0, 4.2) * px), o)
			ci.draw_rect(Rect2(at + Vector2(-1.4, -1.6) * px, Vector2(2.2, 3.4) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(1.2, -1.2) * px, Vector2(1.2, 1.8) * px), tint)
		"anchor":
			ci.draw_rect(Rect2(at + Vector2(-0.5, -2.6) * px, Vector2(1.0, 4.8) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-1.8, -1.6) * px, Vector2(3.6, 0.9) * px), tint)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-2.6, 0.8) * px, at + Vector2(-0.5, 2.4) * px,
				at + Vector2(0.5, 2.4) * px, at + Vector2(2.6, 0.8) * px,
				at + Vector2(2.0, 2.0) * px, at + Vector2(0.0, 3.0) * px,
				at + Vector2(-2.0, 2.0) * px]), tint)
		"gate":
			ci.draw_rect(Rect2(at + Vector2(-2.6, -2.2) * px, Vector2(1.4, 4.6) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(1.2, -2.2) * px, Vector2(1.4, 4.6) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.6, -2.8) * px, Vector2(5.2, 1.0) * px), tint)
		"well":
			ci.draw_rect(Rect2(at + Vector2(-2.2, -0.4) * px, Vector2(4.4, 2.6) * px), o)
			ci.draw_rect(Rect2(at + Vector2(-1.8, 0.0) * px, Vector2(3.6, 1.8) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.4, -1.2) * px, Vector2(5.0, 0.9) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-0.4, -2.8) * px, Vector2(0.8, 1.8) * px), tint)
		"anvil":
			ci.draw_rect(Rect2(at + Vector2(-2.4, -1.4) * px, Vector2(4.8, 1.6) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-1.0, 0.2) * px, Vector2(2.0, 1.4) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.0, 1.6) * px, Vector2(4.0, 0.9) * px), tint)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-3.0, -0.6) * px, at + Vector2(0.0, -3.0) * px, at + Vector2(3.0, -0.6) * px]), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.2, -0.6) * px, Vector2(4.4, 3.0) * px), tint * 0.82)
		"grave":
			ci.draw_rect(Rect2(at + Vector2(-1.6, -2.4) * px, Vector2(3.2, 4.8) * px), tint * 0.9)
			ci.draw_rect(Rect2(at + Vector2(-0.5, -1.8) * px, Vector2(1.0, 2.6) * px), o)
			ci.draw_rect(Rect2(at + Vector2(-1.3, -1.0) * px, Vector2(2.6, 0.9) * px), o)
		"horse":
			ci.draw_rect(Rect2(at + Vector2(-2.6, -0.8) * px, Vector2(4.6, 2.0) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(1.2, -2.4) * px, Vector2(1.6, 2.2) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(-2.2, 1.2) * px, Vector2(0.9, 1.6) * px), tint)
			ci.draw_rect(Rect2(at + Vector2(0.8, 1.2) * px, Vector2(0.9, 1.6) * px), tint)
		"garrison":
			ci.draw_rect(Rect2(at + Vector2(-2.6, -0.6) * px, Vector2(5.2, 3.0) * px), tint * 0.75)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-1.6, -0.8) * px, at + Vector2(-0.6, -2.8) * px,
				at + Vector2(0.2, -1.4) * px, at + Vector2(1.0, -2.6) * px,
				at + Vector2(1.8, -0.8) * px]), Color(0.92, 0.46, 0.20))
		"candle":
			ci.draw_rect(Rect2(at + Vector2(-0.9, -1.2) * px, Vector2(1.8, 3.6) * px), tint)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-0.8, -1.4) * px, at + Vector2(0.0, -3.2) * px, at + Vector2(0.8, -1.4) * px]),
				Color(1.0, 0.86, 0.42))
		"granary":
			ci.draw_rect(Rect2(at + Vector2(-1.8, -0.8) * px, Vector2(3.6, 3.2) * px), tint)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-2.2, -0.8) * px, at + Vector2(0.0, -3.2) * px, at + Vector2(2.2, -0.8) * px]), tint * 0.85)
		"mill":
			ci.draw_rect(Rect2(at + Vector2(-1.4, -0.8) * px, Vector2(2.8, 3.2) * px), tint)
			ci.draw_line(at + Vector2(-2.8, -2.6) * px, at + Vector2(2.8, 0.2) * px, tint, maxf(1.0, px * 0.7))
			ci.draw_line(at + Vector2(2.8, -2.6) * px, at + Vector2(-2.8, 0.2) * px, tint, maxf(1.0, px * 0.7))
		"boat":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-2.8, 0.4) * px, at + Vector2(2.8, 0.4) * px,
				at + Vector2(1.8, 2.2) * px, at + Vector2(-1.8, 2.2) * px]), tint)
			ci.draw_rect(Rect2(at + Vector2(-0.4, -2.8) * px, Vector2(0.8, 3.0) * px), tint)
		"burned":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-2.6, 2.2) * px, at + Vector2(-1.4, -2.2) * px,
				at + Vector2(0.0, 0.6) * px, at + Vector2(1.4, -2.4) * px,
				at + Vector2(2.6, 2.2) * px]), Color(0.32, 0.26, 0.24))
		_:
			ci.draw_rect(Rect2(at - Vector2(px * 1.4, px * 1.4), Vector2(px * 2.8, px * 2.8)), tint)


static func _arrow(c: Vector2, ang: float, r: float) -> PackedVector2Array:
	var f := Vector2(cos(ang), sin(ang))
	var s := Vector2(-f.y, f.x)
	return PackedVector2Array([c + f * r, c - f * r * 0.62 + s * r * 0.68, c - f * r * 0.62 - s * r * 0.68])


static func _diamond_pts(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


# --- the minimap canvas --------------------------------------------------------

## A scrolling window into the map texture, centred on the player, with place
## icons, quest pins and rim arrows for whatever is off the edge.
class MapView extends Control:
	var map_id: String = ""
	var tex: Texture2D = null
	var bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var places: Array = []
	var enemy_pts: PackedVector2Array = PackedVector2Array()
	var travel_pts: PackedVector2Array = PackedVector2Array()
	var pins: Array[Dictionary] = []
	var player_pos: Vector2 = Vector2.ZERO
	var player_angle: float = 0.0
	var font: FontFile = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BOX_BG)
		var half: Vector2 = size * 0.5 * WORLD_PER_PX
		var win := Rect2(player_pos - half, size * WORLD_PER_PX)
		# keep the window inside the world so the map never shows void
		win.position.x = clampf(win.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - win.size.x))
		win.position.y = clampf(win.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - win.size.y))
		if tex != null and bounds.size.x > 0.0:
			var tsize := Vector2(float(tex.get_width()), float(tex.get_height()))
			var to_tex: Vector2 = tsize / bounds.size
			var src := Rect2((win.position - bounds.position) * to_tex, win.size * to_tex)
			draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), MAP_FALLBACK)

		# the unsurveyed ground, same veil texture as the world map
		var ms: Node = get_node_or_null("/root/MapSystem")
		if ms != null and ms.has_method("veil_texture"):
			var veil: Texture2D = ms.call("veil_texture", map_id)
			if veil != null:
				var dim: Vector2i = ms.call("chart_dims", map_id)
				var org: Vector2 = ms.call("chart_origin", map_id)
				var cell: float = 64.0
				if dim.x > 0 and dim.y > 0:
					var vsrc := Rect2((win.position - org) / cell, win.size / cell)
					draw_texture_rect_region(veil, Rect2(Vector2.ZERO, size), vsrc)

		var c: Vector2 = size * 0.5
		var radius: float = size.x * 0.5 - 3.0
		# travel points
		for tp: Vector2 in travel_pts:
			_mark(_to_view(tp, win), radius, c, GOLD, "gate", 0.9)
		# places: everything inside the window gets its icon; only the three
		# nearest places OUTSIDE it get a rim arrow, or the rim becomes a fence
		# of arrows (Moonlighter/CrossCode both cap off-screen markers).
		var offs: Array = []
		var ms2: Node = get_node_or_null("/root/MapSystem")
		for p_v: Variant in places:
			var p: Dictionary = p_v
			if not bool(p.get("minimap", true)):
				continue
			if ms2 != null and ms2.has_method("is_place_known") \
					and not bool(ms2.call("is_place_known", map_id, str(p.get("label", "")))):
				continue
			var vp: Vector2 = _to_view(p["pos"] as Vector2, win)
			if vp.distance_to(c) <= radius - 4.0:
				Minimap._draw_icon(self, str(p["kind"]), vp, 0.9, PARCHMENT)
			else:
				offs.append([vp.distance_to(c), vp])
		offs.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		for i in range(mini(3, offs.size())):
			_rim_arrow(offs[i][1] as Vector2, radius, c, PARCHMENT)
		# quest pins
		for pin: Dictionary in pins:
			_mark(_to_view(pin["pos"] as Vector2, win), radius, c, QUEST_GOLD, "quest", 1.0)
		# enemies: small red chevrons, only inside the window
		for ep: Vector2 in enemy_pts:
			var q: Vector2 = _to_view(ep, win)
			if q.distance_to(c) <= radius:
				draw_colored_polygon(Minimap._arrow(q, -PI * 0.5, 2.6), OUTLINE_DARK)
				draw_colored_polygon(Minimap._arrow(q, -PI * 0.5, 1.8), HOSTILE_RED)
		# the player
		draw_colored_polygon(Minimap._arrow(c, player_angle, 5.2), OUTLINE_DARK)
		draw_colored_polygon(Minimap._arrow(c, player_angle, 3.6), GOLD)
		# compass
		if font != null:
			draw_string(font, Vector2(c.x - 3.0, 9.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD_DIM)

	func _to_view(world: Vector2, win: Rect2) -> Vector2:
		return (world - win.position) / win.size * size

	## Draw an icon, or clamp it to the rim as an arrow when it is off-window.
	func _mark(p: Vector2, radius: float, c: Vector2, tint: Color, kind: String, s: float) -> void:
		var d: Vector2 = p - c
		if d.length() <= radius - 4.0:
			Minimap._draw_icon(self, kind, p, s, tint)
			return
		_rim_arrow(p, radius, c, tint)

	func _rim_arrow(p: Vector2, radius: float, c: Vector2, tint: Color) -> void:
		var dir: Vector2 = (p - c).normalized()
		if dir == Vector2.ZERO:
			return
		var edge: Vector2 = c + dir * (radius - 3.0)
		draw_colored_polygon(Minimap._arrow(edge, dir.angle(), 3.4), OUTLINE_DARK)
		draw_colored_polygon(Minimap._arrow(edge, dir.angle(), 2.3), tint)


# --- the world map -------------------------------------------------------------

class WorldMapView extends Control:
	var tex: Texture2D = null
	var bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var places: Array = []
	var districts: Array = []
	var travel_pts: PackedVector2Array = PackedVector2Array()
	var pins: Array[Dictionary] = []
	var player_pos: Vector2 = Vector2.ZERO
	var player_angle: float = 0.0
	var font: FontFile = null
	var zoom: float = 1.0
	var pan: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), PARCH_BG)
		var fit: Rect2 = Minimap._fit_rect(bounds.size, Rect2(Vector2.ZERO, size))
		if zoom > 1.0:
			# zoom about the player
			var centre: Vector2 = _world_to_fit(player_pos, fit)
			fit = Rect2(fit.position * zoom - centre * (zoom - 1.0), fit.size * zoom)
		if tex != null:
			draw_texture_rect(tex, fit, false)
		else:
			draw_rect(fit, MAP_FALLBACK)
		# quarter names
		if font != null:
			for d_v: Variant in districts:
				var d: Dictionary = d_v
				var at: Vector2 = _world_to_fit(d["pos"] as Vector2, fit)
				var label: String = str(d["text"])
				var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				draw_string(font, at - Vector2(w * 0.5, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.20, 0.14, 0.10, 0.85))
		for tp: Vector2 in travel_pts:
			var q: Vector2 = _world_to_fit(tp, fit)
			draw_colored_polygon(Minimap._diamond_pts(q, 4.0), OUTLINE_DARK)
			draw_colored_polygon(Minimap._diamond_pts(q, 2.8), GOLD)
		for p_v: Variant in places:
			var p: Dictionary = p_v
			var at2: Vector2 = _world_to_fit(p["pos"] as Vector2, fit)
			Minimap._draw_icon(self, str(p["kind"]), at2, 1.3, PARCHMENT)
			if font != null:
				var lab: String = str(p["label"])
				var lw: float = font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				# stagger labels above/below the icon so dense corners stay readable
				var dy: float = 13.0 if (places.find(p_v) % 2) == 0 else -8.0
				draw_string(font, at2 + Vector2(-lw * 0.5, dy), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
		for pin: Dictionary in pins:
			var pp: Vector2 = _world_to_fit(pin["pos"] as Vector2, fit)
			Minimap._draw_icon(self, "quest", pp, 1.4, QUEST_GOLD)
			if font != null:
				draw_string(font, pp + Vector2(6.0, 4.0), str(pin.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		var c: Vector2 = _world_to_fit(player_pos, fit)
		draw_colored_polygon(Minimap._arrow(c, player_angle, 8.0), OUTLINE_DARK)
		draw_colored_polygon(Minimap._arrow(c, player_angle, 6.0), GOLD)

	func _world_to_fit(w: Vector2, fit: Rect2) -> Vector2:
		if bounds.size.x <= 0.0:
			return fit.position
		return fit.position + (w - bounds.position) / bounds.size * fit.size


## The bottom strip of the world map: what each glyph means, plus the controls.
class LegendStrip extends Control:
	var font: FontFile = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var items: Array = [["keep", "Keep"], ["church", "Church"], ["market", "Market"],
			["inn", "Inn"], ["anchor", "Harbour"], ["gate", "Gate"], ["well", "Well"], ["quest", "Quest"]]
		var x: float = 4.0
		for it_v: Variant in items:
			var it: Array = it_v
			Minimap._draw_icon(self, str(it[0]), Vector2(x + 6.0, 10.0), 1.0, PARCHMENT if str(it[0]) != "quest" else QUEST_GOLD)
			if font != null:
				draw_string(font, Vector2(x + 14.0, 14.0), str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
				x += 14.0 + font.get_string_size(str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
			else:
				x += 48.0
		if font != null:
			draw_string(font, Vector2(4.0, 30.0), "M close    + / -  zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK_SOFT)
