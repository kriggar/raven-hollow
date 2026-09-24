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
const PANEL_BORDER := Color(0.58, 0.44, 0.22)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const FRAME_TINT := Color(0.55, 0.45, 0.38)
## Warm dark, not grey. A neutral black scrim behind a sepia sheet kills the
## colour story the moment the map opens.
const DIM_COLOR := Color(0.090, 0.071, 0.055, 0.82)
const PAPER := Color(0.847, 0.792, 0.663)
const INK_1 := Color(0.149, 0.118, 0.082)
const INK_2 := Color(0.361, 0.290, 0.196)

const VIEW := Vector2(640.0, 360.0)
## ONE sheet, full bleed. The screen used to be a 600x344 panel floating on a
## grey scrim inside four nested frames, which sliced the HUD portrait and the
## hotbar exactly in half and left a dead tan band down the right side.
const PANEL_POS := Vector2(0.0, 0.0)
const PANEL_SIZE := Vector2(640.0, 360.0)
## content viewport rect in panel-local coords, inside the inner rule
const CONTENT := Rect2(12.0, 36.0, 616.0, 284.0)
const MAP_LAYER := 13   # above legacy overlay (12) + bag/dialogue, below menus (30)

const TIER_WORLD := 0
const TIER_REGION := 1
const TIER_LOCAL := 2
const TIER_NAMES := ["World", "Region", "Local"]

const MAP_DIR := "res://assets/art/maps/"
const HINT_TEXT := "[M] close    [wheel] zoom    [Tab] gate    [Enter] travel    [1-4] filters"

var is_open: bool = false

## A COPY of alagard imported with antialiasing, hinting and subpixel
## positioning all OFF. The shipped alagard.ttf.import carries antialiasing=1,
## hinting=1, subpixel_positioning=4, so at this screen''s 3x integer scale
## every place name grew a grey fringe. alagard.ttf itself is preloaded by
## three dozen other UI scripts, so it is left alone.
var _font: FontFile = preload("res://assets/fonts/alagard_px.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/kenney_panel_ornate.png")

var _root: Control
var _panel: Panel
var _breadcrumb: Label
var _sheet: TextureRect
var _parch_bg: ColorRect
var _marks: Control
var _hit: Control
var _hint: Label
var _toast_lbl: Label
var _toast_timer: Timer
var _plus: Panel
var _minus: Panel
## Fast travel: the discovered gates of the open zone, and which one is picked.
var on_parchment: bool = false
var _gates: Array = []
var _gate_i: int = -1

var _veil: TextureRect
var _legend: Control
var _mini_root: Control
var _mini: Control

## Legend filters (1-4 while the map is open). Persisted for the session only.
var filter_places: bool = true
var filter_travel: bool = true
var filter_districts: bool = true
var filter_pins: bool = true

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
	_build_legend()
	_root.visible = false
	set_process(false)
	var env: String = OS.get_environment("RH_MAPSCREEN")
	if not env.is_empty():
		call_deferred("_qa_open", env.to_lower())


func _qa_open(which: String) -> void:
	# Wait for RH_MAP's change_map to land first. Opening on the boot frame
	# focused the screen on the starting zone and then never followed the
	# harness into the zone it was told to photograph, so every wilderness
	# capture was silently a picture of Raven Hollow.
	for i in range(30):
		await get_tree().process_frame
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
	_set_hud_visible(false)
	map_opened.emit()
	if Engine.has_singleton("MapSystem") or get_node_or_null("/root/MapSystem") != null:
		MapSystem.notify_opened()

func close_map() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	set_process(false)
	_set_hud_visible(true)
	map_closed.emit()
	if get_node_or_null("/root/MapSystem") != null:
		MapSystem.notify_closed()

func toggle_map() -> void:
	if is_open:
		close_map()
	else:
		open_map()

## The sheet is full-bleed, so anything drawn beneath it is sliced in half by
## its own edges rather than framed by a floating panel.
##
## Hiding by group was not enough: the hotbar, the bag and the quest tracker are
## separate CanvasLayers at 8 and 9 that join no group this screen knows about,
## and at 0.82 dim they stayed plainly visible through the paper. So every
## canvas layer BELOW this one is hidden while the map is open, and each one''s
## previous state is remembered so close puts back exactly what it found.
var _hidden_layers: Array[CanvasLayer] = []

func _set_hud_visible(v: bool) -> void:
	if v:
		for cl: CanvasLayer in _hidden_layers:
			if is_instance_valid(cl):
				cl.visible = true
		_hidden_layers.clear()
		return
	_hidden_layers.clear()
	_collect_layers(get_tree().root)


func _collect_layers(n: Node) -> void:
	for c: Node in n.get_children():
		if c is CanvasLayer:
			var cl := c as CanvasLayer
			if cl != self and cl.layer < MAP_LAYER and cl.visible:
				cl.visible = false
				_hidden_layers.append(cl)
		_collect_layers(c)


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
		elif pk == KEY_TAB:
			get_viewport().set_input_as_handled()
			_cycle_gate(1)
		elif pk == KEY_ENTER or pk == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_travel_to_selected()
		elif pk == KEY_1 or pk == KEY_2 or pk == KEY_3 or pk == KEY_4:
			get_viewport().set_input_as_handled()
			match pk:
				KEY_1: filter_places = not filter_places
				KEY_2: filter_travel = not filter_travel
				KEY_3: filter_districts = not filter_districts
				KEY_4: filter_pins = not filter_pins
			if _legend != null:
				_legend.set("places", filter_places)
				_legend.set("travel", filter_travel)
				_legend.set("districts", filter_districts)
				_legend.set("pins", filter_pins)
				_legend.queue_redraw()
			_refresh_marks()


func _process(_delta: float) -> void:
	if is_open:
		_refresh_marks()
		_sync_chart()
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

	# The panel keeps its type so the open/close tween still drives it, but it
	# is now an invisible container: the paper is a full-bleed ColorRect and the
	# only frame is the neatline drawn in _Furniture.
	_panel = Panel.new()
	_panel.name = "Sheet"
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0, 0, 0, 0)
	psb.set_border_width_all(0)
	_panel.add_theme_stylebox_override("panel", psb)
	_root.add_child(_panel)

	_parch_bg = ColorRect.new()
	_parch_bg.name = "Paper"
	_parch_bg.color = PAPER
	_parch_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parch_bg.position = Vector2.ZERO
	_parch_bg.size = PANEL_SIZE
	_panel.add_child(_parch_bg)

	_sheet = TextureRect.new()
	_sheet.name = "Plate"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NEAREST. The plate is authored at the size it is shown and zoomed by whole
	# steps; linear filtering was only ever there to hide a fractional rescale.
	# The plate is now rendered vector art, supersampled and downsampled with
	# Lanczos, so it wants smooth filtering. NEAREST was right for the pixel
	# plate it replaced and is wrong for this one.
	_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sheet.stretch_mode = TextureRect.STRETCH_SCALE
	_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.add_child(_sheet)

	# Marks layer, clipped to the MAP. The veil goes INSIDE this clip and BEFORE
	# the marks: it used to be added to the panel after the clip, so the fog of
	# war drew on top of every pin and name it exists to protect.
	var clip := Control.new()
	clip.name = "Clip"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = CONTENT.position
	clip.size = CONTENT.size
	clip.clip_contents = true
	_panel.add_child(clip)

	_veil = TextureRect.new()
	_veil.name = "Veil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.stretch_mode = TextureRect.STRETCH_SCALE
	_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_veil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_veil.visible = false
	clip.add_child(_veil)

	_marks = _MapMarks.new()
	_marks.set("font", _font)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# shifted back by the clip's own offset so marks keep panel-local coords
	_marks.position = -CONTENT.position
	_marks.size = PANEL_SIZE
	clip.add_child(_marks)

	# The only frame on the screen, ruled straight onto the paper.
	var furn := _Furniture.new()
	furn.name = "Furniture"
	furn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	furn.position = Vector2.ZERO
	furn.size = PANEL_SIZE
	_panel.add_child(furn)

	_breadcrumb = _label(_panel, 16, INK_1, HORIZONTAL_ALIGNMENT_LEFT)
	_breadcrumb.position = Vector2(14, 12)
	_breadcrumb.size = Vector2(460, 18)
	_breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_minus = _zoom_button("-", Vector2(PANEL_SIZE.x - 58, 11))
	_minus.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_zoom_out())
	_plus = _zoom_button("+", Vector2(PANEL_SIZE.x - 32, 11))
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

	# The key line is PERMANENT. It used to double as the toast target, so the
	# first Tab press destroyed the control legend for the rest of the session.
	_hint = _label(_panel, 16, INK_2, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(0, PANEL_SIZE.y - 21)
	_hint.size = Vector2(PANEL_SIZE.x, 18)
	_hint.text = HINT_TEXT

	_toast_lbl = _label(_panel, 16, INK_1, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_lbl.position = Vector2(0, PANEL_SIZE.y - 38)
	_toast_lbl.size = Vector2(PANEL_SIZE.x, 18)
	_toast_lbl.modulate = Color(1, 1, 1, 0)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 2.5
	_toast_timer.timeout.connect(func() -> void:
		if _toast_lbl != null:
			create_tween().tween_property(_toast_lbl, "modulate:a", 0.0, 0.2))
	add_child(_toast_timer)

	_build_minimap_widget()


## The whole frame: one neatline, one inner rule, four corner flourishes and
## two hairlines. Drawn with integer draw_rect so nothing lands off the grid.
class _Furniture extends Control:
	const INK_A := Color(0.149, 0.118, 0.082)
	const INK_B := Color(0.361, 0.290, 0.196)

	func _draw() -> void:
		draw_rect(Rect2(6, 6, 628, 348), INK_A, false, 2.0)
		draw_rect(Rect2(10, 10, 620, 340), INK_B, false, 1.0)
		for c: Vector2 in [Vector2(6, 6), Vector2(627, 6), Vector2(6, 347), Vector2(627, 347)]:
			draw_rect(Rect2(c.x - 3.0, c.y - 3.0, 7.0, 7.0), INK_A, true)
		draw_rect(Rect2(12, 31, 616, 1), INK_B, true)
		draw_rect(Rect2(12, 322, 616, 1), INK_B, true)

func _zoom_button(txt: String, pos: Vector2) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.position = pos
	p.size = Vector2(20, 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.085)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(2)
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


## The chart fills in while the map is open (you can walk with it up in this
## game''s flow), so the veil and the surveyed readout track it every frame.
## veil_texture() returns its cache unless the chart actually changed.
func _sync_chart() -> void:
	if _tier != TIER_LOCAL or _veil == null:
		return
	var tex: Texture2D = MapSystem.veil_texture(_focus_zone)
	if tex != _veil.texture:
		_veil.texture = tex
		_veil.visible = tex != null
	if _breadcrumb != null:
		var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
		_breadcrumb.text = "%s  >  %s   -   surveyed %d%%" % [MapSystem.region_title(str(meta.region)),
			MapSystem.display_name(_focus_zone), int(round(MapSystem.chart_fraction(_focus_zone) * 100.0))]


## Only gates you have actually stood at can be travelled to - the rule every
## stag/waypoint system uses, and the reason discovery matters.
func _rebuild_gates() -> void:
	_gates.clear()
	if _tier != TIER_LOCAL:
		_gate_i = -1
		return
	for tp_v: Variant in MapSystem.zone_travel_points(_focus_zone):
		var tp: Dictionary = tp_v
		var pos: Vector2 = tp.get("pos", Vector2.ZERO)
		if not MapSystem.is_surveyed(_focus_zone, pos):
			continue
		_gates.append(tp)
	if _gates.is_empty():
		_gate_i = -1
	else:
		_gate_i = clampi(_gate_i, 0, _gates.size() - 1)


func _cycle_gate(step: int) -> void:
	_rebuild_gates()
	if _gates.is_empty():
		_toast("No charted gate in this zone")
		return
	_gate_i = wrapi(_gate_i + step, 0, _gates.size())
	var g: Dictionary = _gates[_gate_i]
	_toast("%s   [Enter] travel" % _gate_label(g))
	_refresh_marks()


func _gate_label(g: Dictionary) -> String:
	var to_map: String = str(g.get("to_map", ""))
	if to_map.is_empty():
		return str(g.get("id", "gate")).capitalize().replace("_", " ")
	return MapSystem.display_name(to_map)


func _travel_to_selected() -> void:
	if _gate_i < 0 or _gate_i >= _gates.size():
		_toast("Pick a gate with [Tab] first")
		return
	var g: Dictionary = _gates[_gate_i]
	var to_map: String = str(g.get("to_map", ""))
	var to_point: String = str(g.get("to_point", ""))
	if to_map.is_empty():
		return
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("change_map"):
		_toast("Cannot travel from here")
		return
	if bool(main.get("_changing_map")):
		return
	close_map()
	main.call_deferred("change_map", to_map, to_point)


## Transient. It has its own line and its own timer; writing it into _hint was
## what made the control legend vanish permanently on the first Tab press.
func _toast(msg: String) -> void:
	if _toast_lbl == null:
		return
	_toast_lbl.text = msg
	_toast_lbl.modulate.a = 1.0
	if _toast_timer != null:
		_toast_timer.start()


func _hide_veil() -> void:
	if _veil != null:
		_veil.visible = false


func _build_world() -> void:
	_hide_veil()
	var tex: Texture2D = MapSystem.world_texture()
	_fit = _fit_rect(MapSystem.WORLD_MAP_SIZE, CONTENT)
	_apply_sheet(tex, true)
	_breadcrumb.text = "Draconia  &  the Collector's Coast"


func _build_region() -> void:
	_hide_veil()
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
	MapSystem.ensure_chart(_focus_zone, bounds)
	_rebuild_gates()
	if _hint != null:
		_hint.text = HINT_TEXT
	_fit = _fit_rect(bounds.size, CONTENT)
	_apply_sheet(_local_tex, _local_tex != null)
	# the unsurveyed ground, veiled. One texel per 64 px chart cell stretched
	# over the sheet with LINEAR filtering, which feathers the frontier.
	if _veil != null:
		_veil.texture = MapSystem.veil_texture(_focus_zone)
		_veil.position = _fit.position
		_veil.size = _fit.size
		_veil.visible = _veil.texture != null
	var meta: Dictionary = MapSystem.zone_meta(_focus_zone)
	_breadcrumb.text = "%s  >  %s   -   surveyed %d%%" % [MapSystem.region_title(str(meta.region)),
		MapSystem.display_name(_focus_zone), int(round(MapSystem.chart_fraction(_focus_zone) * 100.0))]
	if _legend != null:
		_legend.visible = true


func _apply_sheet(tex: Texture2D, has_art: bool) -> void:
	_sheet.texture = tex
	_sheet.visible = tex != null
	_sheet.position = _fit.position
	_sheet.size = _fit.size
	# parchment leaf backdrop when there is no chart art (generated local leaf)
	_parch_bg.visible = not has_art or tex == null
	_parch_bg.position = _fit.position
	_parch_bg.size = _fit.size


## A baked parchment CHART (tools/chart/bake_chart.ps1) if the zone has one,
## else the raw plate. A screenshot on a panel reads as a photograph; the
## chart reads as an artefact, which is what every reference map is.
## The engraved PLAN if the zone has one, else the older baked chart, else the
## raw painter plate. The plan is drawn from the zone''s own vector geometry
## (tools/chart/draw_plan.ps1 over an RH_MAPDUMP export) and composited from
## public-domain engraving, so it is preferred over everything else.
func _load_local_tex(zone_id: String) -> Texture2D:
	on_parchment = false
	for suffix: String in ["sheets/%s_0.png", "%s_plan.png", "%s_chart.png"]:
		var sheet: String = MAP_DIR + (suffix % zone_id)
		if ResourceLoader.exists(sheet, "Texture2D"):
			on_parchment = true
			return load(sheet) as Texture2D
		var sheet_gp: String = ProjectSettings.globalize_path(sheet)
		if FileAccess.file_exists(sheet_gp):
			var simg: Image = Image.load_from_file(sheet_gp)
			if simg != null:
				on_parchment = true
				return ImageTexture.create_from_image(simg)
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
	_marks.set("view_rect", CONTENT)
	_marks.set("plate_named", _tier != TIER_LOCAL)
	_marks.set("on_parchment", on_parchment)
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
	# v10: the named places of the zone, drawn with the shared icon vocabulary
	# (Minimap._draw_icon) and labelled. Landmark DOTS were the owner''s
	# complaint; a keep, a church, an anchor and a tankard are not dots.
	if filter_places:
		var places: Array = Minimap.PLACES.get(_focus_zone, [])
		var idx: int = 0
		for p_v: Variant in places:
			var p: Dictionary = p_v
			var lab: String = str(p.get("label", ""))
			# A place you have not walked to is not on your chart yet.
			if not MapSystem.is_place_known(_focus_zone, lab):
				idx += 1
				continue
			items.append({"pos": _local_to_screen(p["pos"] as Vector2, bounds), "revealed": true,
				"is_current": false, "kind": str(p["kind"]), "label": lab,
				"radius": 5.0, "zone": "", "below": (idx % 2) == 1})
			idx += 1
	# quarter names, so the chart reads as districts and not as one sprawl
	if filter_districts:
		for d_v: Variant in (Minimap.DISTRICTS.get(_focus_zone, []) as Array):
			var d: Dictionary = d_v
			# a quarter you have not set foot in is not named on your chart
			if not MapSystem.is_surveyed(_focus_zone, d["pos"] as Vector2):
				continue
			items.append({"pos": _local_to_screen(d["pos"] as Vector2, bounds), "revealed": true,
				"is_current": false, "kind": "district", "label": str(d["text"]),
				"radius": 0.0, "zone": ""})
	for lm: Dictionary in MapSystem.zone_landmarks(_focus_zone):
		items.append({"pos": _local_to_screen(lm.pos, bounds), "revealed": true,
			"is_current": false, "kind": "landmark", "label": "", "radius": 2.0, "zone": ""})
	var sel_pos: Vector2 = Vector2(-9999, -9999)
	if _gate_i >= 0 and _gate_i < _gates.size():
		sel_pos = (_gates[_gate_i] as Dictionary).get("pos", sel_pos)
	for tp: Dictionary in (MapSystem.zone_travel_points(_focus_zone) if filter_travel else []):
		var tpos: Vector2 = tp.get("pos", Vector2.ZERO)
		var charted: bool = MapSystem.is_surveyed(_focus_zone, tpos)
		items.append({"pos": _local_to_screen(tpos, bounds), "revealed": charted,
			"is_current": tpos.distance_to(sel_pos) < 1.0, "kind": "travel",
			"label": (_gate_label(tp) if charted else ""), "radius": 4.5, "zone": "",
			"below": true})
	for ws: Dictionary in (MapSystem.zone_waystations(_focus_zone) if filter_travel else []):
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

## The legend doubles as the filter list (1-4 toggle), which is how Hollow
## Knight and the Stardew map mods keep a dense map readable.
func _build_legend() -> void:
	_legend = _MapLegend.new()
	_legend.name = "Legend"
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.position = Vector2(CONTENT.position.x, CONTENT.end.y + 4.0)
	_legend.size = Vector2(CONTENT.size.x, 14.0)
	_legend.set("font", _font)
	_panel.add_child(_legend)


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
	# A 1px PAPER knockout, not a dark ring. At 3x an outline_size of 2 is six
	# device pixels of near-black around every place name.
	l.add_theme_color_override("font_outline_color", PAPER)
	l.add_theme_constant_override("outline_size", 1)
	l.horizontal_alignment = align
	l.clip_text = true
	parent.add_child(l)
	return l


# ================================================================ inner draw

## Marker layer for the open map tier: fog veils, POI pins, zone names, the
## player marker. Everything is pushed in panel-local screen coords.
## The legend rail: the glyph vocabulary, doubling as the filter list. Hollow
## Knight and the Stardew map mods both keep a dense map readable this way.
class _MapLegend extends Control:
	var font: Font = null
	var places: bool = true
	var travel: bool = true
	var districts: bool = true
	var pins: bool = true

	# This strip is drawn BELOW the map on the panel''s near-black ground, so it
	# is keyed to the frame''s gold, not to the parchment''s ink.
	const INK := Color(0.85, 0.70, 0.40)
	const INK_OFF := Color(0.42, 0.36, 0.28)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if font == null:
			return
		var groups: Array = [
			["1", "Places", places, "keep"],
			["2", "Travel", travel, "gate"],
			["3", "Quarters", districts, "church"],
			["4", "Pins", pins, "quest"],
		]
		var x: float = 0.0
		for g_v: Variant in groups:
			var g: Array = g_v
			var on: bool = bool(g[2])
			var col: Color = INK if on else INK_OFF
			var tint: Color = Color(0.94, 0.80, 0.48) if on else Color(0.44, 0.39, 0.31)
			Minimap._draw_icon(self, str(g[3]), Vector2(x + 7.0, 10.0), 0.85, tint)
			var txt: String = "[%s] %s" % [str(g[0]), str(g[1])]
			draw_string(font, Vector2(x + 15.0, 14.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
			x += 15.0 + font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14.0


class _MapMarks extends Control:
	var _label_rects: Array = []
	var items: Array = []
	var player: Dictionary = {"show": false, "pos": Vector2.ZERO, "angle": 0.0}
	var on_parchment: bool = false
	var draw_grid: bool = false
	var grid_rect: Rect2 = Rect2()
	## True when the plate underneath already letters itself and carries its own
	## rose and scale - the shipped Draconia world map. Then the engine draws
	## marks only, because a second name beside every kingdom in a different
	## face at a different size is worse than no name at all.
	var plate_named: bool = false
	## The window the map is seen through, in this layer''s own coordinates.
	## Names are kept inside it; without it a name near the south edge stepped
	## down out of the map and was sliced in half by the clip.
	var view_rect: Rect2 = Rect2()
	var font: Font = null

	const GOLD := Color(0.87, 0.7, 0.36)
	const GOLD_BRIGHT := Color(0.98, 0.84, 0.5)
	const PARCHMENT := Color(0.9, 0.85, 0.74)
	const INK := Color(0.18, 0.13, 0.09)
	const INK_SOFT := Color(0.34, 0.26, 0.16)
	const BLOOD := Color(0.62, 0.16, 0.12)
	const FOG := Color(0.45, 0.41, 0.34)
	const OUTLINE := Color(0.06, 0.04, 0.02)

	## Kenney Cartography Pack (CC0, assets/art/maps/carto) symbol per place
	## kind. The baked chart underneath is drawn from this same set, so the
	## mill inked on the paper and the pin that names it are one drawing
	## instead of two unrelated ones - which is the whole reason a real map
	## feels authored rather than assembled.
	const CARTO_DIR := "res://assets/art/maps/carto/pin/"
	const CARTO := {
		"home": "houseChimney", "anvil": "house", "inn": "houseTall",
		"grave": "graveyard", "gate": "gate", "horse": "stable",
		"garrison": "runis", "market": "tent", "keep": "castleTall",
		"church": "church", "candle": "towerLow", "well": "well",
		"boat": "ship", "anchor": "dock", "granary": "houses",
		"mill": "waterWheel", "burned": "skull", "compass": "compass",
	}
	static var _carto_cache: Dictionary = {}

	static func carto_tex(kind: String) -> Texture2D:
		if _carto_cache.has(kind):
			return _carto_cache[kind] as Texture2D
		var tex: Texture2D = null
		var nm: String = str(CARTO.get(kind, ""))
		if nm != "":
			var path: String = CARTO_DIR + nm + ".png"
			if ResourceLoader.exists(path, "Texture2D"):
				tex = load(path) as Texture2D
		_carto_cache[kind] = tex
		return tex

	## Draw a symbol standing ON the point, with a pale ghost a pixel behind it
	## so it survives over hatching, water or a dense terrace. Always blitted at
	## its own size: tools/chart/make_pins.ps1 already resampled it to the size
	## it is shown at, because the project draws canvas textures with NEAREST
	## and any rescale here would tear the strokes apart.
	func _carto(tex: Texture2D, at: Vector2, halo: bool = true, a: float = 1.0) -> void:
		var w: float = float(tex.get_width())
		var h: float = float(tex.get_height())
		var dst := Rect2((at - Vector2(w * 0.5, h * 0.84)).round(), Vector2(w, h))
		# NO HALO. The spec is explicit: paper does not glow, and a soft radial
		# bloom behind every symbol was named a fatal defect by both critiques.
		# A mark separates from its ground by its own 1px outline, not by light.
		if false:
			# The chart is already full of drawn buildings in this same ink, so
			# a pin with nothing behind it simply joins the terrain. A wiped
			# patch of paper under it is how an annotated map has always kept
			# its added marks separable from its survey - but it has to fade
			# out, because a hard-edged disc reads as a sticker laid on top.
			var cen: Vector2 = at - Vector2(0.0, h * 0.34)
			for step in range(5):
				var rr: float = h * (0.66 - float(step) * 0.075)
				draw_circle(cen, rr, Color(0.96, 0.92, 0.81, 0.13))
		draw_texture_rect(tex, Rect2(dst.position + Vector2(1.0, 1.0), dst.size), false,
			Color(0.95, 0.90, 0.76, 0.6 * a) if on_parchment else Color(0.05, 0.03, 0.02, 0.7 * a))
		draw_texture_rect(tex, dst, false,
			Color(0.19, 0.13, 0.08, 0.96 * a) if on_parchment else Color(0.94, 0.88, 0.75, 0.96 * a))

	## The paper a pin occupies, so names can be kept off it.
	func _carto_box(tex: Texture2D, at: Vector2) -> Rect2:
		var w: float = maxf(float(tex.get_width()), float(tex.get_height()) * 1.25)
		var h: float = float(tex.get_height())
		return Rect2(at - Vector2(w * 0.5, h * 0.9), Vector2(w, h * 1.05))

	func _draw() -> void:
		if draw_grid:
			_draw_parchment_grid()
		# Two passes, because a name has to dodge the SYMBOLS as well as the
		# other names. Drawing each mark with its own name attached meant a name
		# only ever avoided what had already been written, and then printed
		# straight across the next symbol along. So: every mark and every piece
		# of furniture claims its paper first, and nothing is named until all of
		# it is claimed. Names that still cannot find room are dropped, which is
		# what a cartographer does too.
		_label_rects.clear()
		for it_v: Variant in items:
			_draw_mark(it_v as Dictionary)
		if on_parchment and not plate_named:
			_draw_furniture()
		for it_v2: Variant in items:
			_draw_name(it_v2 as Dictionary)
		if bool(player.get("show", false)):
			var c: Vector2 = player.pos
			draw_circle(c, 8.0, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.22))
			draw_arc(c, 7.0, 0.0, TAU, 20, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.7), 1.0)
			draw_colored_polygon(_arrow(c, float(player.angle), 6.5), OUTLINE)
			draw_colored_polygon(_arrow(c, float(player.angle), 5.0), GOLD_BRIGHT)

	## Pass one: the symbol only.
	func _draw_mark(it: Dictionary) -> void:
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
				if plate_named:
					# open mark: the plate's lettering shows through it
					_diamond_ring(p, r * 0.98, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.75), 1.0)
					_diamond_ring(p, r * 0.82, col, 1.0)
					if kind == "capital":
						_dot(p, r * 0.30, BLOOD)
				else:
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
				if not rev:
					_chevron(p, r * 0.8, FOG)
				else:
					_chevron(p, r + 1.0, OUTLINE)
					_chevron(p, r, GOLD_BRIGHT)
					if bool(it.is_current):
						draw_arc(p, r + 4.0, 0.0, TAU, 20, GOLD_BRIGHT, 1.0)
			"landmark":
				_dot(p, r, INK_SOFT)
			"district":
				return
			_:
				# Every named place: a drawn cartography symbol where the pack
				# has one, else the shared pixel glyph. Never a dot.
				var sym: Texture2D = carto_tex(kind)
				if sym != null:
					_carto(sym, p)
					_label_rects.append(_carto_box(sym, p))
				else:
					Minimap._draw_icon(self, kind, p, 1.15, PARCHMENT if not on_parchment else Color(0.31, 0.23, 0.15))
					_label_rects.append(Rect2(p - Vector2(r + 2.0, r + 2.0), Vector2(r * 2.0 + 4.0, r * 2.0 + 4.0)))

	## Pass two: the name beside the symbol, or the quarter name on its own.
	func _draw_name(it: Dictionary) -> void:
		if font == null:
			return
		var p: Vector2 = it.pos
		var kind: String = str(it.kind)
		if plate_named and (kind == "zone" or kind == "capital" or kind == "district"):
			return
		if kind == "district":
			var dtxt: String = str(it.get("label", ""))
			if dtxt == "":
				return
			var dw: float = font.get_string_size(dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var dat: Vector2 = p - Vector2(dw * 0.5, 0.0)
			# A quarter is the biggest word on the sheet, so it is the one that
			# must give way: it steps down past anything already written and is
			# dropped if it still cannot fit.
			var dlim: Rect2 = view_rect if view_rect.size.x > 8.0 else Rect2(Vector2.ZERO, size)
			var dbox := Rect2(dat + Vector2(0.0, -10.0), Vector2(dw, 13.0))
			var dtry: int = 0
			while (_collides(dbox) or not dlim.encloses(dbox)) and dtry < 4:
				dat.y += 13.0
				dbox.position.y += 13.0
				dtry += 1
			if _collides(dbox) or not dlim.encloses(dbox):
				return
			_label_rects.append(dbox)
			draw_string_outline(font, dat, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 1, Color(0.847, 0.792, 0.663, 0.95) if on_parchment else OUTLINE)
			draw_string(font, dat, dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.26, 0.18, 0.11, 0.95) if on_parchment else Color(0.94, 0.88, 0.74, 0.92))
			return
		var lbl: String = str(it.get("label", ""))
		if lbl == "":
			return
		var carto_mark: bool = carto_tex(kind) != null
		var col2: Color = INK if (on_parchment or draw_grid) else PARCHMENT
		var below: bool = bool(it.get("below", false)) or carto_mark
		var tw: float = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var dy: float = (float(it.get("radius", 4.0)) + (16.0 if carto_mark else 12.0)) if below else (-float(it.get("radius", 4.0)) - 4.0)
		var at: Vector2 = p + Vector2(-tw * 0.5, dy)
		var lim: Rect2 = view_rect if view_rect.size.x > 8.0 else Rect2(Vector2.ZERO, size)
		var box := Rect2(at + Vector2(0.0, -8.0), Vector2(tw, 10.0))
		var tries: int = 0
		while (_collides(box) or not lim.encloses(box)) and tries < 4:
			at.y += 11.0
			box.position.y += 11.0
			tries += 1
		if _collides(box) or not lim.encloses(box):
			# no room under the mark - try the other side before giving up
			at = p + Vector2(-tw * 0.5, -float(it.get("radius", 4.0)) - (19.0 if carto_mark else 5.0))
			box = Rect2(at + Vector2(0.0, -8.0), Vector2(tw, 10.0))
			if _collides(box) or not lim.encloses(box):
				return
		_label_rects.append(box)
		draw_string_outline(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 1, Color(0.847, 0.792, 0.663, 0.95) if on_parchment else OUTLINE)
		draw_string(font, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col2)

	## True when `r` overlaps a label already drawn this frame.
	func _collides(r: Rect2) -> bool:
		for o_v: Variant in _label_rects:
			if r.intersects(o_v as Rect2):
				return true
		return false
	## Compass rose and scale bar - the two marks that say "chart" more than any
	## other, and the reason a plan reads as surveyed rather than screenshotted.
	func _draw_furniture() -> void:
		var ink := Color(0.24, 0.17, 0.11, 0.85)
		var r: float = 15.0
		var fr: Rect2 = grid_rect if grid_rect.size.x > 8.0 else Rect2(Vector2.ZERO, size)
		var c := Vector2(fr.end.x - r - 10.0, fr.position.y + r + 10.0)
		var rose: Texture2D = carto_tex("compass")
		if rose != null:
			_carto(rose, c + Vector2(0.0, float(rose.get_height()) * 0.34), false, 0.78)
			_label_rects.append(_carto_box(rose, c + Vector2(0.0, float(rose.get_height()) * 0.34)))
		else:
			_rose_drawn(c, r, ink)
		if font != null:
			draw_string(font, c + Vector2(-3.0, -r - 3.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
		# scale bar, bottom-left: five ticks of a furlong each
		var bx: float = fr.position.x + 10.0
		var by: float = fr.end.y - 12.0
		var seg: float = 13.0
		for s in range(5):
			var x0: float = bx + float(s) * seg
			draw_rect(Rect2(Vector2(x0, by), Vector2(seg, 3.0)),
				ink if s % 2 == 0 else Color(ink.r, ink.g, ink.b, 0.25))
		draw_rect(Rect2(Vector2(bx, by), Vector2(seg * 5.0, 3.0)), ink, false, 1.0)
		_label_rects.append(Rect2(Vector2(bx, by - 12.0), Vector2(seg * 5.0, 18.0)))
		if font != null:
			draw_string(font, Vector2(bx, by - 3.0), "500 paces", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)

	## The hand-inked rose, kept for any build where the CC0 symbols are absent.
	func _rose_drawn(c: Vector2, r: float, ink: Color) -> void:
		draw_arc(c, r, 0.0, TAU, 28, ink, 1.0)
		draw_arc(c, r * 0.62, 0.0, TAU, 22, Color(ink.r, ink.g, ink.b, 0.45), 1.0)
		for i in range(4):
			var a: float = -PI * 0.5 + float(i) * PI * 0.5
			var tip := c + Vector2(cos(a), sin(a)) * r
			var lft := c + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * (r * 0.20)
			var rgt := c + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * (r * 0.20)
			draw_colored_polygon(PackedVector2Array([tip, lft, c, rgt]),
				ink if i == 0 else Color(ink.r, ink.g, ink.b, 0.50))
		for i2 in range(4):
			var a2: float = -PI * 0.25 + float(i2) * PI * 0.5
			draw_line(c + Vector2(cos(a2), sin(a2)) * (r * 0.30),
				c + Vector2(cos(a2), sin(a2)) * (r * 0.92), Color(ink.r, ink.g, ink.b, 0.40), 1.0)


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

	## An open lozenge, for marking a plate that already carries its own names.
	func _diamond_ring(at: Vector2, r: float, color: Color, w: float = 1.0) -> void:
		draw_polyline(PackedVector2Array([
			at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r),
			at + Vector2(-r, 0), at + Vector2(0, -r)]), color, w)

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
