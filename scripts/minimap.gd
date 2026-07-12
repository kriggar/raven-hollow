class_name Minimap
extends CanvasLayer
## Minimap + world-map overlay for Raven Hollow (Phase C, SPEC_PHASE_C_DEMO.md §6).
## Layer 8 (same band as the HUD), group "minimap". Built entirely in code.
##
## Top-right: 64px dark-wood-framed minimap — prerendered map texture from
## res://assets/art/maps/<map_id>.png (aspect-fit, letterboxed on the dark
## fill), gold player arrow (rotates to the last movement direction), yellow
## NPC dots, red enemy dots, gold travel-point diamonds — with the day/night
## clock ("17:20", Alagard 10) right under the frame, fed by the DayNight node
## (group "day_night", duck-typed).
##
## M ("map" action) toggles the world-map overlay: a parchment-framed large
## map with Alagard district labels, the player arrow, travel-point diamonds
## and quest pins (gold "!") pulled duck-typed from the Quests singleton.
##
## ============================ INTEGRATION (main.gd — integrator implements)
## 1. _bootstrap_world(): add_child(Minimap.new()) right after add_child(HUD.new()).
##    Zero-config: it boots showing the town map over TownBuilder's bounds.
## 2. change_map(map_id, entry_point_id): after the new map is built, feed the
##    minimap from the MapRegistry def + builder info:
##        var mm: Node = get_tree().get_first_node_in_group("minimap")
##        if mm != null:
##            mm.call("set_map", map_id, info.bounds, def.get("travel_points", []),
##                    str(def.get("display_name", "")))
##    travel_points entries are the MapRegistry dicts ({id, pos, radius, to_map,
##    to_point, prompt}) — only "pos" (Vector2, world px) is read here.
## 3. Input action "map" (M) already exists in project.godot — nothing to add.
## 4. quests.gd (group "quests") MAY implement:
##        func map_pins(map_id: String) -> Array   # of {"pos": Vector2, "label": String}
##    Pins render as gold "!" on the world-map overlay. Duck-typed; absent → no pins.
## 5. hud.gd quest tracker (spec §4) goes "under the minimap": the frame owns
##    design-space (558,8)-(632,82) and the clock runs to y≈96 — start the
##    tracker at y >= 100 on the right edge.
## 6. Pause menu: skip its ui_cancel handling while is_world_map_open() is true
##    (the overlay consumes Esc to close itself when it sees the event first,
##    but _unhandled_input order is not guaranteed across siblings).
## 7. Map textures: res://assets/art/maps/<map_id>.png. town.png is SHIPPED
##    (256x183, cut from _screens/b3_full.png; covers world (0,0)-(2240,1600)
##    exactly, HUD overlays patched out). wilderness.png is DEFERRED to the
##    integration pass (same pipeline: full-map screenshot → crop to world
##    rect → ~256px downscale); until it exists the wilderness map draws its
##    dots over a muted olive fallback, nothing breaks.
## 8. New maps: add district label entries to DISTRICTS and a display name to
##    DISPLAY_NAMES below (or pass display_name through set_map).
## ===========================================================================

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const HOSTILE_RED := Color(0.85, 0.25, 0.2)
const NPC_YELLOW := Color(0.93, 0.83, 0.34)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const PARCH_BG := Color(0.72, 0.65, 0.5)
const MAP_FALLBACK := Color(0.34, 0.37, 0.24)  # muted olive "unmapped" ground

const MAP_DIR := "res://assets/art/maps/"
const DEFAULT_MAP_ID := "town"
const DEFAULT_BOUNDS := Rect2(0.0, 0.0, 2240.0, 1600.0)  # TownBuilder 70x50 @32

## Minimap frame geometry (640x360 design space, top-right).
const MARGIN: float = 8.0
const MAP_SIZE: float = 70.0
const RIM_PAD: float = 5.0
const FRAME: float = MAP_SIZE + RIM_PAD * 2.0  # 74
const CLOCK_H: float = 12.0

## World-map overlay geometry.
const OVERLAY_LAYER: int = 12  # above bag/sheet (9) + dialogue (10), below menus (30)
const PANEL_W: float = 520.0
const PANEL_H: float = 330.0
const CONTENT := Rect2(12.0, 36.0, 496.0, 270.0)  # map area inside the panel

const DISPLAY_NAMES: Dictionary = {
	"town": "Raven Hollow",
	"wilderness": "The Emberfall Road",
}

## District labels per map id, world px positions (Alagard on the overlay).
const DISTRICTS: Dictionary = {
	"town": [
		{"pos": Vector2(455.0, 385.0), "text": "Old Cemetery"},
		{"pos": Vector2(1110.0, 505.0), "text": "The Inn"},
		{"pos": Vector2(1120.0, 802.0), "text": "The Square"},
		{"pos": Vector2(1520.0, 752.0), "text": "Smithy"},
		{"pos": Vector2(828.0, 768.0), "text": "Market"},
		{"pos": Vector2(1100.0, 1145.0), "text": "Cottages"},
		{"pos": Vector2(1655.0, 1300.0), "text": "Farmstead"},
		{"pos": Vector2(2035.0, 935.0), "text": "East Gate"},
	],
}

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _map_id: String = DEFAULT_MAP_ID
var _bounds: Rect2 = DEFAULT_BOUNDS
var _travel_world: PackedVector2Array = PackedVector2Array()
var _map_tex: Texture2D = null

var _root: Control
var _view: MapView
var _clock: Label

var _overlay: CanvasLayer
var _overlay_title: Label
var _overlay_map_bg: ColorRect
var _overlay_map: TextureRect
var _overlay_map_border: Panel
var _overlay_labels: Control
var _marks: OverlayMarks

var _player_angle: float = 0.0


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


func _process(_delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var alive: bool = player != null and is_instance_valid(player)
	_root.visible = alive
	if not alive:
		if _overlay.visible:
			_overlay.visible = false
		return

	# Player arrow: keep the last movement heading while standing still.
	var vel_v: Variant = player.get("velocity")
	if vel_v is Vector2 and (vel_v as Vector2).length_squared() > 16.0:
		_player_angle = (vel_v as Vector2).angle()

	_view.has_player = true
	_view.player_pos = player.global_position
	_view.player_angle = _player_angle
	_view.npc_pts = _collect_group_points("npcs")
	_view.enemy_pts = _collect_group_points("enemies", true)
	_view.queue_redraw()

	_clock.text = _clock_text()
	_clock.visible = not _clock.text.is_empty()

	if _overlay.visible:
		_update_overlay_marks(player)


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action("map"):
		return
	if event.is_action_pressed("map"):
		if _root.visible or _overlay.visible:
			_overlay.visible = not _overlay.visible
			get_viewport().set_input_as_handled()
	elif _overlay.visible and event.is_action_pressed("ui_cancel"):
		_overlay.visible = false
		get_viewport().set_input_as_handled()


## True while the M world map is up (pause menu should ignore Esc then).
func is_world_map_open() -> bool:
	return _overlay.visible


## Point the minimap + world map at a new map. Called by main.gd on every
## change_map (see INTEGRATION). travel_points: MapRegistry dicts, "pos" read.
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

	_view.tex = _map_tex
	_view.bounds = _bounds
	_view.travel_pts = _travel_world
	_view.queue_redraw()

	var title: String = display_name
	if title.is_empty():
		title = str(DISPLAY_NAMES.get(map_id, map_id.capitalize()))
	_overlay_title.text = title
	_layout_overlay_map()
	_rebuild_district_labels()


# --- construction: minimap frame ----------------------------------------------

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

	# WoW-professional round minimap: opaque-corner ring mask over the square
	# map view (gold ring + N marker baked into the texture).
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


# --- construction: world-map overlay -------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "WorldMapOverlay"
	_overlay.layer = OVERLAY_LAYER
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks under the map
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var panel := Control.new()
	panel.name = "MapPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_W * 0.5
	panel.offset_right = PANEL_W * 0.5
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	_overlay.add_child(panel)

	# Parchment sheet inset under the wooden rim.
	var parch := Panel.new()
	parch.name = "Parchment"
	parch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parch.position = Vector2(3.0, 3.0)
	parch.size = Vector2(PANEL_W - 6.0, PANEL_H - 6.0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = PARCH_BG
	psb.border_color = Color(0.42, 0.33, 0.2)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(0)
	parch.add_theme_stylebox_override("panel", psb)
	panel.add_child(parch)

	# Dark wood header band with the map's display name in gold Alagard.
	var header := Panel.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = Vector2(6.0, 6.0)
	header.size = Vector2(PANEL_W - 12.0, 24.0)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = BOX_BG
	hsb.border_color = Color(0.42, 0.33, 0.2)
	hsb.set_border_width_all(2)
	hsb.set_corner_radius_all(0)
	header.add_theme_stylebox_override("panel", hsb)
	panel.add_child(header)

	_overlay_title = Label.new()
	_overlay_title.name = "Title"
	_overlay_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_title.add_theme_font_override("font", _font)
	_overlay_title.add_theme_font_size_override("font_size", 14)
	_overlay_title.add_theme_color_override("font_color", GOLD)
	_overlay_title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_overlay_title.add_theme_constant_override("outline_size", 2)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_title.position = Vector2(0.0, -2.0)
	_overlay_title.size = header.size
	header.add_child(_overlay_title)

	# Map image (aspect-fit inside CONTENT; sized in _layout_overlay_map).
	_overlay_map_bg = ColorRect.new()
	_overlay_map_bg.name = "MapFallback"
	_overlay_map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_map_bg.color = MAP_FALLBACK
	panel.add_child(_overlay_map_bg)

	_overlay_map = TextureRect.new()
	_overlay_map.name = "MapImage"
	_overlay_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay_map.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.add_child(_overlay_map)

	_overlay_map_border = Panel.new()
	_overlay_map_border.name = "MapBorder"
	_overlay_map_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bsb.border_color = Color(0.3, 0.22, 0.12)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(0)
	_overlay_map_border.add_theme_stylebox_override("panel", bsb)
	panel.add_child(_overlay_map_border)

	_overlay_labels = Control.new()
	_overlay_labels.name = "DistrictLabels"
	_overlay_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_overlay_labels)

	_marks = OverlayMarks.new()
	_marks.name = "Marks"
	_marks.font = _font
	panel.add_child(_marks)

	var hint := Label.new()
	hint.name = "Hint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.32, 0.24, 0.14))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "[M] close"
	hint.position = Vector2(0.0, PANEL_H - 22.0)
	hint.size = Vector2(PANEL_W, 12.0)
	panel.add_child(hint)

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
	panel.add_child(rim)


## Aspect-fit the current map bounds into CONTENT and place image/border/marks.
func _layout_overlay_map() -> void:
	var fit: Rect2 = _fit_rect(_bounds.size, CONTENT)
	_overlay_map_bg.position = fit.position
	_overlay_map_bg.size = fit.size
	_overlay_map.position = fit.position
	_overlay_map.size = fit.size
	_overlay_map.texture = _map_tex
	_overlay_map.visible = _map_tex != null
	_overlay_map_border.position = fit.position - Vector2(2.0, 2.0)
	_overlay_map_border.size = fit.size + Vector2(4.0, 4.0)
	_marks.position = fit.position
	_marks.size = fit.size
	_marks.bounds = _bounds
	_marks.travel_pts = _travel_world


func _rebuild_district_labels() -> void:
	for child: Node in _overlay_labels.get_children():
		child.queue_free()
	var fit: Rect2 = _fit_rect(_bounds.size, CONTENT)
	var entries_v: Variant = DISTRICTS.get(_map_id, [])
	if not (entries_v is Array):
		return
	for entry_v: Variant in (entries_v as Array):
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var pos_v: Variant = entry.get("pos")
		if not (pos_v is Vector2):
			continue
		var uv: Vector2 = ((pos_v as Vector2) - _bounds.position) / _bounds.size
		var at: Vector2 = fit.position + uv.clamp(Vector2.ZERO, Vector2.ONE) * fit.size
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", PARCHMENT)
		label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		label.add_theme_constant_override("outline_size", 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = str(entry.get("text", ""))
		label.position = at - Vector2(60.0, 6.0)
		label.size = Vector2(120.0, 12.0)
		_overlay_labels.add_child(label)


# --- per-frame helpers ----------------------------------------------------------

func _update_overlay_marks(player: Node2D) -> void:
	_marks.has_player = true
	_marks.player_pos = player.global_position
	_marks.player_angle = _player_angle
	_marks.pins = _collect_quest_pins()
	_marks.queue_redraw()


## World positions of a group's living Node2Ds (skip_dead: honor `is_dead`).
func _collect_group_points(group: String, skip_dead: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for node: Node in get_tree().get_nodes_in_group(group):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		if skip_dead and node.get("is_dead") == true:
			continue
		pts.append((node as Node2D).global_position)
	return pts


## Duck-typed quest pins: Quests singleton (group "quests") may expose
## map_pins(map_id) -> Array of {"pos": Vector2, "label": String}.
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


## Clock text from the DayNight node (group "day_night"), duck-typed.
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


## Map texture per map id. Prefers the imported resource; falls back to a raw
## PNG read so a freshly generated map works before the editor has imported it.
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


## Largest rect with `content` aspect that fits centered inside `area`.
static func _fit_rect(content: Vector2, area: Rect2) -> Rect2:
	if content.x <= 0.0 or content.y <= 0.0:
		return area
	var s: float = minf(area.size.x / content.x, area.size.y / content.y)
	var fit_size: Vector2 = content * s
	return Rect2(area.position + (area.size - fit_size) * 0.5, fit_size)


# --- inner draw controls ---------------------------------------------------------

## The 64px minimap canvas: map texture aspect-fit on dark wood, then travel
## diamonds, NPC/enemy dots and the player arrow. Data is pushed by Minimap
## each frame (no back-reference into the outer class).
class MapView extends Control:
	var tex: Texture2D = null
	var bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var npc_pts: PackedVector2Array = PackedVector2Array()
	var enemy_pts: PackedVector2Array = PackedVector2Array()
	var travel_pts: PackedVector2Array = PackedVector2Array()
	var player_pos: Vector2 = Vector2.ZERO
	var player_angle: float = 0.0
	var has_player: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BOX_BG)
		var fit: Rect2 = _fit_rect(bounds.size, Rect2(Vector2.ZERO, size))
		if tex != null:
			draw_texture_rect(tex, fit, false)
		for tp: Vector2 in travel_pts:
			_diamond(_map_pt(tp, fit), 2.5, GOLD)
		for np: Vector2 in npc_pts:
			var p: Vector2 = _map_pt(np, fit)
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), NPC_YELLOW)
		for ep: Vector2 in enemy_pts:
			var q: Vector2 = _map_pt(ep, fit)
			draw_rect(Rect2(q - Vector2.ONE, Vector2(2.0, 2.0)), HOSTILE_RED)
		if has_player:
			var c: Vector2 = _map_pt(player_pos, fit)
			draw_colored_polygon(_arrow(c, player_angle, 5.0), OUTLINE_DARK)
			draw_colored_polygon(_arrow(c, player_angle, 3.6), GOLD)

	func _map_pt(world: Vector2, fit: Rect2) -> Vector2:
		var uv: Vector2 = (world - bounds.position) / bounds.size
		return fit.position + uv.clamp(Vector2.ZERO, Vector2.ONE) * fit.size

	## Local copy of Minimap._fit_rect — outer statics are not visible from
	## inner classes.
	static func _fit_rect(content: Vector2, area: Rect2) -> Rect2:
		if content.x <= 0.0 or content.y <= 0.0:
			return area
		var s: float = minf(area.size.x / content.x, area.size.y / content.y)
		var fit_size: Vector2 = content * s
		return Rect2(area.position + (area.size - fit_size) * 0.5, fit_size)

	func _diamond(at: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, -r), at + Vector2(r, 0.0),
			at + Vector2(0.0, r), at + Vector2(-r, 0.0),
		]), color)

	static func _arrow(at: Vector2, angle: float, s: float) -> PackedVector2Array:
		var pts := PackedVector2Array([
			Vector2(1.0, 0.0), Vector2(-0.75, 0.65), Vector2(-0.35, 0.0),
			Vector2(-0.75, -0.65),
		])
		for i in range(pts.size()):
			pts[i] = at + (pts[i] * s).rotated(angle)
		return pts


## Marker layer over the big world map: player arrow, travel diamonds and gold
## "!" quest pins. Sized to the map image rect; data pushed by Minimap.
class OverlayMarks extends Control:
	var bounds: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var travel_pts: PackedVector2Array = PackedVector2Array()
	var player_pos: Vector2 = Vector2.ZERO
	var player_angle: float = 0.0
	var has_player: bool = false
	var pins: Array[Dictionary] = []
	var font: Font = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for tp: Vector2 in travel_pts:
			var d: Vector2 = _map_pt(tp)
			draw_colored_polygon(PackedVector2Array([
				d + Vector2(0.0, -4.0), d + Vector2(4.0, 0.0),
				d + Vector2(0.0, 4.0), d + Vector2(-4.0, 0.0),
			]), GOLD)
		if font != null:
			for pin: Dictionary in pins:
				var pos_v: Variant = pin.get("pos")
				if not (pos_v is Vector2):
					continue
				var p: Vector2 = _map_pt(pos_v)
				draw_string_outline(font, p + Vector2(-8.0, 4.0), "!",
						HORIZONTAL_ALIGNMENT_CENTER, 16.0, 13, 3, OUTLINE_DARK)
				draw_string(font, p + Vector2(-8.0, 4.0), "!",
						HORIZONTAL_ALIGNMENT_CENTER, 16.0, 13, GOLD)
		if has_player:
			var c: Vector2 = _map_pt(player_pos)
			draw_colored_polygon(_arrow(c, player_angle, 8.0), OUTLINE_DARK)
			draw_colored_polygon(_arrow(c, player_angle, 6.0), GOLD)

	func _map_pt(world: Vector2) -> Vector2:
		var uv: Vector2 = (world - bounds.position) / bounds.size
		return uv.clamp(Vector2.ZERO, Vector2.ONE) * size

	## Local copy of MapView._arrow — sibling inner statics are not reliably
	## visible across inner classes.
	static func _arrow(at: Vector2, angle: float, s: float) -> PackedVector2Array:
		var pts := PackedVector2Array([
			Vector2(1.0, 0.0), Vector2(-0.75, 0.65), Vector2(-0.35, 0.0),
			Vector2(-0.75, -0.65),
		])
		for i in range(pts.size()):
			pts[i] = at + (pts[i] * s).rotated(angle)
		return pts
