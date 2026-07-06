extends CanvasLayer
## MapScreen — the 3-tier zoom atlas for Raven Hollow (WoW map behaviour on the
## gothic parchment masterpiece). Spawned by the MapSystem autoload.
##
## Tiers: WORLD (the whole Draconia chart) -> REGION (a cropped sub-chart) ->
## LOCAL (the current zone leaf). M opens on the LOCAL tier centred on the
## player ("never lost"); wheel / +- / click zooms; right-click / wheel-down
## zooms out. Fog-of-war: unrevealed zones are dim veiled marks with no name;
## charted zones burn gold. Player marker rides every tier. Waystation +
## capital + travel POI pins come from ZoneDefs / TravelSystem via MapSystem.
## A minimap corner widget is included but only shows when no legacy minimap
## is present (avoids a duplicate in the shipped HUD).
##
## Input is consumed in _input() (earlier phase) so the legacy minimap's own
## M/Esc _unhandled_input never fires — this screen owns the map key cleanly
## without editing minimap.gd. Toggle key: M ("map" action). QA: RH_MAPSCREEN
## = world|region|local force-opens on that tier for the RH_SHOT harness.

signal map_opened
signal map_closed

const GOLD := Color(0.87, 0.7, 0.36)
const GOLD_BRIGHT := Color(0.98, 0.84, 0.5)
const GOLD_DIM := Color(0.6, 0.47, 0.26)
const PARCHMENT := Color(0.88, 0.83, 0.72)
const PARCH_BG := Color(0.73, 0.66, 0.51)
const INK := Color(0.2, 0.15, 0.1)
const INK_SOFT := Color(0.32, 0.24, 0.15)
const BLOOD := Color(0.62, 0.16, 0.12)
const FOG := Color(0.42, 0.38, 0.32, 0.9)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.98)
const HEADER_BG := Color(0.13, 0.1, 0.075, 1.0)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)

const VIEW := Vector2(640.0, 360.0)
const PANEL_POS := Vector2(20.0, 8.0)
const PANEL_SIZE := Vector2(600.0, 344.0)
## content viewport rect in panel-local coords
const CONTENT := Rect2(14.0, 34.0, 572.0, 276.0)
const MAP_LAYER := 13   # above legacy overlay (12) + bag/dialogue, below menus (30)

const TIER_WORLD := 0
const TIER_REGION := 1
const TIER_LOCAL := 2
const TIER_NAMES := ["World", "Region", "Local"]

const MAP_DIR := "res://assets/art/maps/"

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _root: Control
var _panel: Panel
var _breadcrumb: Label
var _sheet: TextureRect
var _parch_bg: ColorRect
var _marks: Control
var _hit: Control
var _hint: Label
var _plus: Panel
var _minus: Panel
var _mini_root: Control
var _mini: Control

var _tier: int = TIER_LOCAL
var _focus_zone: String = "town"
var _fit: Rect2 = CONTENT           # aspect-fit rect (panel-local) of the active tier
var _local_tex: Texture2D = null
var _region_crop: Rect2 = Rect2()


func _ready() -> void:
	layer = MAP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("map_screen")
	_build_shell()
	_root.visible = false
	set_process(false)
	var env: String = OS.get_environment("RH_MAPSCREEN")
	if not env.is_empty():
		call_deferred("_qa_open", env.to_lower())


func _qa_open(which: String) -> void:
	open_map()
	match which:
		"world": _set_tier(TIER_WORLD)
		"region": _set_tier(TIER_REGION)
		_: _set_tier(TIER_LOCAL)


# ---------------------------------------------------------------- open/close

func open_map() -> void:
	if is_open:
		return
	is_open = true
	_focus_zone = _current_or_default()
	_tier = TIER_LOCAL
	_rebuild_tier()
	_root.visible = true
	set_process(true)
	_root.modulate = Color(1, 1, 1, 0)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.12)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	map_opened.emit()
	if Engine.has_singleton("MapSystem") or get_node_or_null("/root/MapSystem") != null:
		MapSystem.notify_opened()

func close_map() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	set_process(false)
	map_closed.emit()
	if get_node_or_null("/root/MapSystem") != null:
		MapSystem.notify_closed()

func toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()

func _current_or_default() -> String:
	var cur: String = MapSystem.current_zone()
	if cur != "" and MapSystem.has_anchor(cur):
		return cur
	return "town"


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# M owns the map — consume in _input so the legacy minimap overlay never fires.
	if InputMap.has_action("map") and event.is_action_pressed("map"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_map()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var pk: int = (event as InputEventKey).physical_keycode
		if pk == KEY_EQUAL or pk == KEY_KP_ADD:
			get_viewport().set_input_as_handled()
			_zoom_in(_focus_zone)
		elif pk == KEY_MINUS or pk == KEY_KP_SUBTRACT:
			get_viewport().set_input_as_handled()
			_zoom_out()


func _process(_delta: float) -> void:
	if is_open:
		_refresh_marks()
		if _mini != null and _mini.visible:
			_mini.queue_redraw()


# ---------------------------------------------------------------- shell

func _build_shell() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = BOX_BG
	psb.border_color = PANEL_BORDER
	psb.set_border_width_all(2)
	psb.shadow_color = Color(0, 0, 0, 0.5)
	psb.shadow_size = 7
	_panel.add_theme_stylebox_override("panel", psb)
	_root.add_child(_panel)

	# parchment behind the sheet (visible as the local generated leaf + letterbox)
	_parch_bg = ColorRect.new()
	_parch_bg.color = PARCH_BG
	_parch_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_parch_bg)

	_sheet = TextureRect.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sheet.stretch_mode = TextureRect.STRETCH_SCALE
	_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.add_child(_sheet)

	var content_border := Panel.new()
	content_border.name = "ContentBorder"
	content_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_border.position = CONTENT.position - Vector2(2, 2)
	content_border.size = CONTENT.size + Vector2(4, 4)
	var cbsb := StyleBoxFlat.new()
	cbsb.bg_color = Color(0, 0, 0, 0)
	cbsb.border_color = Color(0.3, 0.22, 0.12)
	cbsb.set_border_width_all(2)
	content_border.add_theme_stylebox_override("panel", cbsb)
	_panel.add_child(content_border)

	# marks layer (custom draw), clipped to the content
	var clip := Control.new()
	clip.name = "Clip"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2.ZERO
	clip.size = PANEL_SIZE
	clip.clip_contents = true
	_panel.add_child(clip)
	_marks = _MapMarks.new()
	_marks.set("font", _font)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_marks)

	# header band + breadcrumb + zoom buttons
	var header := Panel.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = Vector2(6, 6)
	header.size = Vector2(PANEL_SIZE.x - 12, 24)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = HEADER_BG
	hsb.border_color = PANEL_BORDER
	hsb.set_border_width_all(1)
	header.add_theme_stylebox_override("panel", hsb)
	_panel.add_child(header)

	_breadcrumb = _label(_panel, 13, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_breadcrumb.position = Vector2(16, 8)
	_breadcrumb.size = Vector2(480, 20)
	_breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_minus = _zoom_button("-", Vector2(PANEL_SIZE.x - 56, 9))
	_minus.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_zoom_out())
	_plus = _zoom_button("+", Vector2(PANEL_SIZE.x - 32, 9))
	_plus.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_zoom_in(_focus_zone))

	# input catcher over the content (wheel zoom + click to enter/leave)
	_hit = Control.new()
	_hit.name = "Hit"
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.position = CONTENT.position
	_hit.size = CONTENT.size
	_hit.gui_input.connect(_on_content_input)
	_panel.add_child(_hit)

	_hint = _label(_panel, 9, INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(0, PANEL_SIZE.y - 20)
	_hint.size = Vector2(PANEL_SIZE.x, 12)
	_hint.text = "[M] close   [wheel] zoom   [click] enter   [right-click] out"

	var rim := NinePatchRect.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture = _panel_tex
	rim.draw_center = false
	rim.patch_margin_left = 10
	rim.patch_margin_right = 10
	rim.patch_margin_top = 10
	rim.patch_margin_bottom = 10
	rim.modulate = FRAME_TINT
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(rim)

	_build_minimap_widget()


func _zoom_button(txt: String, pos: Vector2) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.position = pos
	p.size = Vector2(20, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.085)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(p, 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.text = txt
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(p)
	return p


# ---------------------------------------------------------------- tier build

func _set_tier(t: int) -> void:
	_tier = clampi(t, TIER_WORLD, TIER_LOCAL)
	_rebuild_tier()

func _zoom_in(zone_id: String) -> void:
	match _tier:
		TIER_WORLD:
			_focus_zone = zone_id
			_set_tier(TIER_REGION)
		TIER_REGION:
			if MapSystem.is_revealed(zone_id):
				_focus_zone = zone_id
				_set_tier(TIER_LOCAL)
		TIER_LOCAL:
			pass

func _zoom_out() -> void:
	if _tier == TIER_LOCAL:
		_set_tier(TIER_REGION)
	elif _tier == TIER_REGION:
		_set_tier(TIER_WORLD)


func _rebuild_tier() -> void:
	match _tier:
		TIER_WORLD: _build_world()
		TIER_REGION: _build_region()
		TIER_LOCAL: _build_local()
	_refresh_marks()


func _build_world() -> void:
	var tex: Texture2D = MapSystem.world_texture()
	_fit = _fit_rect(MapSystem.WORLD_MAP_SIZE, CONTENT)
	_apply_sheet(tex, true)
	_breadcrumb.text = "Draconia  &  the Collector's Coast"


func _build_region() -> void:
	var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
	var cont: int = int(meta.continent)
	var region: String = str(meta.region)
	_region_crop = MapSystem.region_bounds(cont, region)
	var world_tex: Texture2D = MapSystem.world_texture()
	var atlas: Texture2D = null
	if world_tex != null:
		var at := AtlasTexture.new()
		at.atlas = world_tex
		at.region = _region_crop
		atlas = at
	_fit = _fit_rect(_region_crop.size, CONTENT)
	_apply_sheet(atlas, true)
	_breadcrumb.text = "%s  >  %s" % ["Draconia" if cont == 1 else "The Coast", MapSystem.region_title(region)]


func _build_local() -> void:
	_local_tex = _load_local_tex(_focus_zone)
	var bounds: Rect2 = MapSystem.zone_bounds(_focus_zone)
	_fit = _fit_rect(bounds.size, CONTENT)
	_apply_sheet(_local_tex, _local_tex != null)
	var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
	_breadcrumb.text = "%s  >  %s" % [MapSystem.region_title(str(meta.region)), MapSystem.display_name(_focus_zone)]


func _apply_sheet(tex: Texture2D, has_art: bool) -> void:
	_sheet.texture = tex
	_sheet.visible = tex != null
	_sheet.position = _fit.position
	_sheet.size = _fit.size
	# parchment leaf backdrop when there is no chart art (generated local leaf)
	_parch_bg.visible = not has_art or tex == null
	_parch_bg.position = _fit.position
	_parch_bg.size = _fit.size


func _load_local_tex(zone_id: String) -> Texture2D:
	var path: String = MAP_DIR + zone_id + ".png"
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var gp: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(gp):
		var img: Image = Image.load_from_file(gp)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


# ---------------------------------------------------------------- marks

func _refresh_marks() -> void:
	var items: Array = []
	var player := {"show": false, "pos": Vector2.ZERO, "angle": 0.0}
	var grid: bool = false
	var cur: String = MapSystem.current_zone()
	match _tier:
		TIER_WORLD:
			for zid: String in MapSystem.placeable_ids():
				items.append(_zone_item(zid, MapSystem.WORLD_MAP_SIZE, Vector2.ZERO, cur, false))
			_set_player_from_anchor(player, cur, MapSystem.WORLD_MAP_SIZE, Vector2.ZERO)
		TIER_REGION:
			var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
			var ids: Array = MapSystem.zones_in_region(int(meta.continent), str(meta.region))
			for zid: String in ids:
				items.append(_zone_item(zid, _region_crop.size, _region_crop.position, cur, true))
			_set_player_from_anchor(player, cur, _region_crop.size, _region_crop.position)
		TIER_LOCAL:
			grid = _local_tex == null
			_build_local_items(items)
			var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			if pl != null and cur == _focus_zone:
				var bounds: Rect2 = MapSystem.zone_bounds(_focus_zone)
				player.show = true
				player.pos = _local_to_screen(pl.global_position, bounds)
				var vel: Variant = pl.get("velocity")
				if vel is Vector2 and (vel as Vector2).length_squared() > 16.0:
					player.angle = (vel as Vector2).angle()
	_marks.set("items", items)
	_marks.set("player", player)
	_marks.set("draw_grid", grid)
	_marks.set("grid_rect", _fit)
	_marks.queue_redraw()


func _zone_item(zid: String, src_size: Vector2, src_origin: Vector2, cur: String, big: bool) -> Dictionary:
	var a: Vector2 = MapSystem.anchor_of(zid)
	var uv: Vector2 = (a - src_origin) / Vector2(maxf(src_size.x, 1.0), maxf(src_size.y, 1.0))
	var pos: Vector2 = _fit.position + uv * _fit.size
	var rev: bool = MapSystem.is_revealed(zid)
	var meta: Dictionary = MapSystem.zone_meta(zid)
	return {
		"pos": pos, "revealed": rev, "is_current": zid == cur,
		"kind": ("capital" if bool(meta.capital) else "zone"),
		"label": (str(meta.name) if rev else ""),
		"radius": (5.0 if big else 3.5) + (1.5 if bool(meta.capital) else 0.0),
		"zone": zid,
	}


func _build_local_items(items: Array) -> void:
	var bounds: Rect2 = MapSystem.zone_bounds(_focus_zone)
	for lm: Dictionary in MapSystem.zone_landmarks(_focus_zone):
		items.append({"pos": _local_to_screen(lm.pos, bounds), "revealed": true,
			"is_current": false, "kind": "landmark", "label": "", "radius": 2.0, "zone": ""})
	for tp: Dictionary in MapSystem.zone_travel_points(_focus_zone):
		items.append({"pos": _local_to_screen(tp.pos, bounds), "revealed": true,
			"is_current": false, "kind": "travel", "label": "", "radius": 4.0, "zone": ""})
	for ws: Dictionary in MapSystem.zone_waystations(_focus_zone):
		var disc: bool = bool(ws.discovered)
		items.append({"pos": _local_to_screen(ws.pos, bounds), "revealed": disc,
			"is_current": false, "kind": ("waystation" if disc else "waystation_off"),
			"label": (str(ws.id).capitalize().replace("_", " ") if disc else ""),
			"radius": 4.5, "zone": ""})


func _local_to_screen(world_pos: Vector2, bounds: Rect2) -> Vector2:
	var uv: Vector2 = (world_pos - bounds.position) / Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	return _fit.position + uv * _fit.size


func _set_player_from_anchor(player: Dictionary, cur: String, src_size: Vector2, src_origin: Vector2) -> void:
	if cur == "" or not MapSystem.has_anchor(cur):
		return
	if not MapSystem.is_revealed(cur):
		return
	var a: Vector2 = MapSystem.anchor_of(cur)
	var uv: Vector2 = (a - src_origin) / Vector2(maxf(src_size.x, 1.0), maxf(src_size.y, 1.0))
	if uv.x < -0.05 or uv.x > 1.05 or uv.y < -0.05 or uv.y > 1.05:
		return
	player.show = true
	player.pos = _fit.position + uv * _fit.size
	player.angle = 0.0


# ---------------------------------------------------------------- content input

func _on_content_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				var z: String = _nearest_zone(CONTENT.position + mb.position)
				_zoom_in(z if z != "" else _focus_zone)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_out()
			MOUSE_BUTTON_LEFT:
				var zid: String = _nearest_zone(CONTENT.position + mb.position)
				if zid != "":
					_zoom_in(zid)
			MOUSE_BUTTON_RIGHT:
				_zoom_out()


## Nearest zone pin (panel-local click) within a grab radius; "" if none / local tier.
func _nearest_zone(panel_pos: Vector2) -> String:
	if _tier == TIER_LOCAL:
		return ""
	var best: String = ""
	var best_d: float = 18.0
	var src_size: Vector2 = MapSystem.WORLD_MAP_SIZE if _tier == TIER_WORLD else _region_crop.size
	var src_origin: Vector2 = Vector2.ZERO if _tier == TIER_WORLD else _region_crop.position
	var ids: Array = MapSystem.placeable_ids()
	if _tier == TIER_REGION:
		var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
		ids = MapSystem.zones_in_region(int(meta.continent), str(meta.region))
	for zid: String in ids:
		var a: Vector2 = MapSystem.anchor_of(zid)
		var uv: Vector2 = (a - src_origin) / Vector2(maxf(src_size.x, 1.0), maxf(src_size.y, 1.0))
		var pos: Vector2 = _fit.position + uv * _fit.size
		var d: float = pos.distance_to(panel_pos)
		if d < best_d:
			best_d = d
			best = zid
	return best


# ---------------------------------------------------------------- minimap widget

func _build_minimap_widget() -> void:
	_mini_root = Control.new()
	_mini_root.name = "MiniRoot"
	_mini_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mini_root.visible = false
	add_child(_mini_root)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(8, VIEW.y - 80)
	frame.size = Vector2(72, 72)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	_mini_root.add_child(frame)
	_mini = _MiniMap.new()
	_mini.set("font", _font)
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.position = Vector2(4, 4)
	_mini.size = Vector2(64, 64)
	frame.add_child(_mini)
	# only surface our corner map when the legacy minimap isn't present
	set_process_internal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and _mini_root != null:
		var legacy_present: bool = not get_tree().get_nodes_in_group("minimap").is_empty()
		_mini_root.visible = not legacy_present and not is_open


# ---------------------------------------------------------------- helpers

func on_zone_revealed(_zone_id: String) -> void:
	if is_open:
		_refresh_marks()

func on_station_discovered(_station_id: String) -> void:
	if is_open:
		_refresh_marks()

static func _fit_rect(content: Vector2, area: Rect2) -> Rect2:
	if content.x <= 0.0 or content.y <= 0.0:
		return area
	var s: float = minf(area.size.x / content.x, area.size.y / content.y)
	var fit_size: Vector2 = content * s
	return Rect2(area.position + (area.size - fit_size) * 0.5, fit_size)

func _label(parent: Control, fsize: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = align
	l.clip_text = true
	parent.add_child(l)
	return l


# ================================================================ inner draw

## Marker layer for the open map tier: fog veils, POI pins, zone names, the
## player marker. Everything is pushed in panel-local screen coords.
class _MapMarks extends Control:
	var items: Array = []
	var player: Dictionary = {"show": false, "pos": Vector2.ZERO, "angle": 0.0}
	var draw_grid: bool = false
	var grid_rect: Rect2 = Rect2()
	var font: Font = null

	const GOLD := Color(0.87, 0.7, 0.36)
	const GOLD_BRIGHT := Color(0.98, 0.84, 0.5)
	const PARCHMENT := Color(0.9, 0.85, 0.74)
	const INK := Color(0.18, 0.13, 0.09)
	const INK_SOFT := Color(0.34, 0.26, 0.16)
	const BLOOD := Color(0.62, 0.16, 0.12)
	const FOG := Color(0.45, 0.41, 0.34)
	const OUTLINE := Color(0.06, 0.04, 0.02)

	func _draw() -> void:
		if draw_grid:
			_draw_parchment_grid()
		for it_v: Variant in items:
			var it: Dictionary = it_v
			_draw_item(it)
		if bool(player.get("show", false)):
			var c: Vector2 = player.pos
			draw_circle(c, 8.0, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.22))
			draw_arc(c, 7.0, 0.0, TAU, 20, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.7), 1.0)
			draw_colored_polygon(_arrow(c, float(player.angle), 6.5), OUTLINE)
			draw_colored_polygon(_arrow(c, float(player.angle), 5.0), GOLD_BRIGHT)

	func _draw_item(it: Dictionary) -> void:
		var p: Vector2 = it.pos
		var rev: bool = bool(it.revealed)
		var kind: String = str(it.kind)
		var r: float = float(it.get("radius", 3.5))
		match kind:
			"zone", "capital":
				if not rev:
					_diamond(p, r * 0.7, FOG)
					_dot(p, 1.0, INK_SOFT)
					return
				var col: Color = GOLD_BRIGHT if bool(it.is_current) else GOLD
				_diamond(p, r + 1.0, OUTLINE)
				_diamond(p, r, col)
				if kind == "capital":
					_dot(p, r * 0.45, BLOOD)
				if bool(it.is_current):
					draw_arc(p, r + 3.0, 0.0, TAU, 18, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.8), 1.0)
			"waystation":
				_diamond(p, r + 1.0, OUTLINE)
				_diamond(p, r, GOLD)
				_dot(p, 1.4, BLOOD)
			"waystation_off":
				_diamond(p, r * 0.7, FOG)
			"travel":
				_chevron(p, r, GOLD_BRIGHT)
			"landmark":
				_dot(p, r, INK_SOFT)
		var lbl: String = str(it.get("label", ""))
		if font != null and lbl != "":
			var col2: Color = PARCHMENT if draw_grid == false else INK
			# labels over the dark chart read in parchment; on the parchment leaf, in ink
			var tw: float = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var at: Vector2 = p + Vector2(-tw * 0.5, -float(it.get("radius", 4.0)) - 3.0)
			draw_string_outline(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, OUTLINE)
			draw_string(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col2)

	func _draw_parchment_grid() -> void:
		var rr: Rect2 = grid_rect
		var step: float = 28.0
		var c := Color(INK.r, INK.g, INK.b, 0.14)
		var x: float = rr.position.x
		while x < rr.position.x + rr.size.x:
			draw_line(Vector2(x, rr.position.y), Vector2(x, rr.position.y + rr.size.y), c, 1.0)
			x += step
		var y: float = rr.position.y
		while y < rr.position.y + rr.size.y:
			draw_line(Vector2(rr.position.x, y), Vector2(rr.position.x + rr.size.x, y), c, 1.0)
			y += step

	func _diamond(at: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)

	func _dot(at: Vector2, r: float, color: Color) -> void:
		draw_circle(at, r, color)

	func _chevron(at: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-r, r), at + Vector2(0, -r), at + Vector2(r, r),
			at + Vector2(0, 0)]), color)

	static func _arrow(at: Vector2, angle: float, s: float) -> PackedVector2Array:
		var pts := PackedVector2Array([
			Vector2(1.0, 0.0), Vector2(-0.75, 0.65), Vector2(-0.35, 0.0), Vector2(-0.75, -0.65)])
		for i in range(pts.size()):
			pts[i] = at + (pts[i] * s).rotated(angle)
		return pts


## Compact corner minimap (only shown if no legacy minimap owns the HUD).
class _MiniMap extends Control:
	var font: Font = null
	const GOLD := Color(0.87, 0.7, 0.36)
	const OUTLINE := Color(0.06, 0.04, 0.02)
	const BOX := Color(0.09, 0.07, 0.06)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BOX)
		var ms: Node = get_node_or_null("/root/MapSystem")
		if ms == null:
			return
		var cur: String = ms.call("current_zone")
		if cur == "":
			return
		var bounds: Rect2 = ms.call("zone_bounds", cur)
		var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		# waystation dots
		for ws_v: Variant in ms.call("zone_waystations", cur):
			var ws: Dictionary = ws_v
			if bool(ws.discovered):
				_dot(_pt(ws.pos, bounds), GOLD)
		if pl != null:
			var p: Vector2 = _pt(pl.global_position, bounds)
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -3), p + Vector2(2, 3), p + Vector2(-2, 3)]), GOLD)

	func _pt(world: Vector2, bounds: Rect2) -> Vector2:
		var uv: Vector2 = (world - bounds.position) / Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
		return uv.clamp(Vector2.ZERO, Vector2.ONE) * size

	func _dot(at: Vector2, color: Color) -> void:
		draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), color)
