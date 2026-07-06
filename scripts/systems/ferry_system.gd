extends Node
## FerrySystem -- autoload (/root/FerrySystem). Backlog #75 "Grey Ferry travel
## routes" + #102 "the Voyage Interlude cinematic".
##
## The Grey Ferry is the canon era-crossing that links the two continents of the
## world: the Iron Vein delta on Draconia (Year 0) and the Collector's Coast (the
## drowned-ledger era) across the Grey. Routes load from data/ferry.json as a
## small fast-travel node graph over the REAL ferry docks authored in
## scripts/zone_defs.gd (riverfork.ferry_dock <-> grey_piers.ferry_landing). Each
## route carries a fare, a travel time, an optional unlock gate, and a VOYAGE id
## whose interlude (#102) plays before you land: a fog-crossing over the water with
## era-crossfade subtitle lines.
##
## Everything here is additive and null-safe: no other system's file is edited.
## The fare is charged through a GUARDED write to the player's `gold` (the same
## property MountSystem's stablemaster uses); if the actor has no gold the fare is
## treated as affordable (degrade-open). The map change reuses the SAME path the
## rest of the game changes maps with -- main.change_map(map_id, entry_point_id)
## on get_tree().current_scene -- guarded by has_method; when no such host exists
## (self-test / no world) it emits map_change_requested instead and still lands.
##
## The voyage interlude prefers CinematicSystem.play(id) when that autoload holds a
## matching cinematic (future-proof; we do not edit its data), otherwise it drives
## a fully self-contained CanvasLayer: a fog ColorRect that fades in over the
## crossing and a subtitle panel that steps the era-crossfade lines, then fades out.
##
## A small ferry/route UI (dock list + per-route fares + a Depart button) is
## self-instanced here as a CanvasLayer and toggled with the 'Y' key.
##
## Public API (actor = the player node, group "player"):
##   list_routes(dock) -> Array           route defs departing from a dock id
##   all_routes() -> Array / route_def(id) -> Dictionary / route_count() -> int
##   docks() -> Array / dock_def(id) -> Dictionary / dock_links(id) -> Array
##   can_travel(actor, route) -> bool     fare + unlock check (route id or def)
##   travel(actor, route) -> bool         voyage interlude, then map change (async)
##   fare(route) -> int / is_unlocked(actor, route) -> bool
##   open_ferry(actor) / close_ferry() / toggle_ferry()
## Signals:
##   ferry_opened(actor)
##   voyage_started(actor, route_id)
##   ferry_arrived(actor, route_id, to_dock)
##   map_change_requested(map_id, point_id)   (fallback when no map host exists)

signal ferry_opened(actor)
signal voyage_started(actor, route_id)
signal ferry_arrived(actor, route_id, to_dock)
signal map_change_requested(map_id, point_id)

const DATA_PATH := "res://data/ferry.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const UI_LAYER := 80
const VOYAGE_LAYER := 86

var _cfg: Dictionary = {}
var _docks: Dictionary = {}        # dock_id -> def
var _routes: Dictionary = {}       # route_id -> def
var _voyages: Dictionary = {}      # voyage_id -> {name, fog_color, steps}

# Self-instanced UI (built lazily) -----------------------------------------
var _ui: CanvasLayer = null
var _ui_list: VBoxContainer = null
var _ui_actor: Node = null
var _ui_open: bool = false

# Voyage interlude overlay (built lazily) ----------------------------------
var _voy_layer: CanvasLayer = null
var _voy_fog: ColorRect = null
var _voy_panel: PanelContainer = null
var _voy_speaker: Label = null
var _voy_line: Label = null

var _in_voyage: bool = false
var _time_scale: float = 1.0       # <1.0 accelerates the interlude (self-test)
var _suppress_map_change: bool = false  # self-test: skip the real change_map


func _ready() -> void:
	set_process(false)
	_load_data()
	if not OS.get_environment("RH_FERRY_TEST").is_empty() \
			or not OS.get_environment("RH_FERRY").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_cfg = _dict(root.get("config", {}))
	_docks = _dict(root.get("docks", {}))
	_routes = _dict(root.get("routes", {}))
	_voyages = _dict(root.get("voyages", {}))
	# Stamp ids onto the route defs so callers can pass the def around freely.
	for rid: String in _routes.keys():
		var r: Dictionary = _dict(_routes[rid])
		r["id"] = rid
		_routes[rid] = r
	if _routes.is_empty():
		push_warning("FerrySystem: no ferry routes loaded from %s" % DATA_PATH)


# --- Data queries -----------------------------------------------------------

func all_routes() -> Array:
	var out: Array = []
	for rid: String in _routes.keys():
		out.append(_dict(_routes[rid]))
	return out


func route_count() -> int:
	return _routes.size()


func route_def(route_id: String) -> Dictionary:
	return _dict(_routes.get(route_id, {}))


## Route defs that DEPART from `dock` (a dock id like "riverfork.ferry_dock").
func list_routes(dock: String) -> Array:
	var out: Array = []
	for rid: String in _routes.keys():
		var r: Dictionary = _dict(_routes[rid])
		if str(r.get("from_dock", "")) == dock:
			out.append(r)
	return out


func docks() -> Array:
	return _docks.keys()


func dock_def(dock_id: String) -> Dictionary:
	return _dict(_docks.get(dock_id, {}))


## Fast-travel node graph: the docks reachable by ferry from `dock_id`.
func dock_links(dock_id: String) -> Array:
	return _arr(dock_def(dock_id).get("links", [])).duplicate()


func fare(route: Variant) -> int:
	return int(_resolve_route(route).get("fare", int(_cfg.get("default_fare", 15))))


# --- Travel gating ----------------------------------------------------------

## True when the actor may board this route right now: the route exists, its
## unlock gate (if any) is satisfied, and the fare is affordable. Every external
## read is guarded and degrades OPEN so a bare boot never falsely blocks travel.
func can_travel(actor: Node, route: Variant) -> bool:
	var r: Dictionary = _resolve_route(route)
	if r.is_empty():
		return false
	if not is_unlocked(actor, r):
		return false
	return _gold(actor) >= int(r.get("fare", 0))


## Unlock gate: an empty `unlocked_by` is always open. A non-empty gate is checked
## against QuestSystem when present (guarded); if no quest host exists the route
## degrades OPEN (the canon ferry lane is a public road).
func is_unlocked(actor: Node, route: Variant) -> bool:
	var r: Dictionary = _resolve_route(route)
	var gate: String = str(r.get("unlocked_by", ""))
	if gate == "":
		return true
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs == null:
		return true
	if qs.has_method("is_complete"):
		return bool(qs.call("is_complete", gate))
	if qs.has_method("is_quest_complete"):
		return bool(qs.call("is_quest_complete", gate))
	return true


func travel_blocked_reason(actor: Node, route: Variant) -> String:
	var r: Dictionary = _resolve_route(route)
	if r.is_empty():
		return "no such route"
	if not is_unlocked(actor, r):
		return "route locked"
	if _gold(actor) < int(r.get("fare", 0)):
		return "not enough gold"
	return ""


# --- Board a ferry ----------------------------------------------------------

## Charge the fare, play the voyage interlude to completion, then hand off to the
## game's map-change path (or emit map_change_requested when none exists) and land
## on the far dock. Awaitable: callers may `await travel(actor, route)`.
func travel(actor: Node, route: Variant) -> bool:
	var r: Dictionary = _resolve_route(route)
	if r.is_empty():
		return false
	if not can_travel(actor, r):
		return false
	if _in_voyage:
		return false
	var rid: String = str(r.get("id", ""))
	# Charge the fare (guarded; no-op if the actor has no gold property).
	_spend_gold(actor, int(r.get("fare", 0)))
	if _ui_open:
		close_ferry()
	voyage_started.emit(actor, rid)
	await _run_voyage(str(r.get("voyage", "")))
	# Hand off to the shared map-change path, guarded.
	var to_map: String = str(r.get("to_map", ""))
	var to_point: String = str(r.get("to_point", ""))
	var to_dock: String = str(r.get("to_dock", ""))
	var host: Node = _map_host()
	if not _suppress_map_change and host != null and host.has_method("change_map"):
		host.call("change_map", to_map, to_point)
	else:
		map_change_requested.emit(to_map, to_point)
	ferry_arrived.emit(actor, rid, to_dock)
	return true


func _map_host() -> Node:
	var tree: SceneTree = get_tree()
	return tree.current_scene if tree != null else null


# --- Voyage interlude (#102) ------------------------------------------------

## Run the fog-crossing interlude for `voyage_id`. Prefers CinematicSystem when it
## holds a cinematic of that id (we never edit its data); otherwise drives a fully
## self-contained fog + subtitle overlay. Always completes, even with no world.
func _run_voyage(voyage_id: String) -> void:
	_in_voyage = true
	var cine: Node = get_node_or_null("/root/CinematicSystem")
	if voyage_id != "" and cine != null and cine.has_method("has_cinematic") \
			and bool(cine.call("has_cinematic", voyage_id)) and cine.has_method("play"):
		await cine.call("play", voyage_id)
		_in_voyage = false
		return
	var v: Dictionary = _dict(_voyages.get(voyage_id, {}))
	_ensure_voyage_ui()
	if _voy_fog != null:
		_voy_fog.color = _color(str(v.get("fog_color", _cfg.get("fog_color", "#8a929c"))))
		_voy_fog.color.a = 0.0
	var fade: float = float(_cfg.get("fog_fade", 1.2))
	await _fog_to(0.82, fade)
	var steps: Array = _arr(v.get("steps", []))
	if steps.is_empty():
		# No authored lines -- still hold the fog a beat so the crossing reads.
		await _sleep(1.6)
	for step_v: Variant in steps:
		var step: Dictionary = _dict(step_v)
		_show_line(str(step.get("speaker", "")), str(step.get("line", "")))
		await _sleep(float(step.get("duration", _cfg.get("voyage_step_dur", 3.2))))
	if _voy_panel != null:
		_voy_panel.visible = false
	await _fog_to(0.0, fade)
	if _voy_layer != null:
		_voy_layer.visible = false
	_in_voyage = false


func _fog_to(target_a: float, dur: float) -> void:
	if _voy_fog == null:
		await _sleep(dur)
		return
	if _voy_layer != null:
		_voy_layer.visible = true
	var d: float = maxf(0.0, dur * _time_scale)
	if d <= 0.0:
		_voy_fog.color.a = target_a
		return
	var tw: Tween = create_tween()
	tw.tween_property(_voy_fog, "color:a", target_a, d)
	await _sleep(dur)


func _show_line(speaker: String, line: String) -> void:
	if _voy_panel == null:
		return
	_voy_speaker.text = speaker
	_voy_speaker.visible = speaker != ""
	_voy_line.text = line
	_voy_panel.visible = true


# --- Voyage UI construction -------------------------------------------------

func _ensure_voyage_ui() -> void:
	if _voy_layer != null and is_instance_valid(_voy_layer):
		return
	_voy_layer = CanvasLayer.new()
	_voy_layer.layer = VOYAGE_LAYER
	add_child(_voy_layer)

	_voy_fog = ColorRect.new()
	_voy_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voy_fog.color = Color(0.54, 0.57, 0.61, 0.0)
	_voy_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voy_layer.add_child(_voy_fog)

	_voy_panel = PanelContainer.new()
	_voy_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_voy_panel.position = Vector2(-300.0, -130.0)
	_voy_panel.custom_minimum_size = Vector2(600.0, 0.0)
	_voy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voy_panel.add_theme_stylebox_override("panel", _make_panel_style())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_voy_panel.add_child(vb)
	_voy_speaker = _make_label("", 15, Color(0.92, 0.78, 0.42))
	_voy_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_voy_speaker)
	_voy_line = _make_label("", 12, Color(0.9, 0.88, 0.82))
	_voy_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voy_line.custom_minimum_size = Vector2(568.0, 0.0)
	_voy_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_voy_line)
	_voy_panel.visible = false
	_voy_layer.add_child(_voy_panel)


# --- Ferry / route UI -------------------------------------------------------

func open_ferry(actor: Node = null) -> void:
	if actor == null:
		actor = _player()
	_ui_actor = actor
	_ensure_ui()
	if _ui == null:
		return
	_rebuild_ui()
	_ui.visible = true
	_ui_open = true
	ferry_opened.emit(actor)


func close_ferry() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.visible = false
	_ui_open = false


func toggle_ferry() -> void:
	if _ui_open:
		close_ferry()
	else:
		open_ferry(_player())


func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	_ui = CanvasLayer.new()
	_ui.layer = UI_LAYER
	add_child(_ui)
	# Group so sibling systems' _panel_blocking() sees the ferry menu as blocking.
	_ui.add_to_group("ferry_ui")

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520.0, 300.0)
	panel.position = Vector2(-260.0, -180.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_ui.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := _make_label("The Grey Ferry", 22, Color(0.95, 0.82, 0.46))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub := _make_label("Passage between the years -- choose a crossing.", 12,
			Color(0.82, 0.80, 0.74))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var sep := HSeparator.new()
	root.add_child(sep)

	_ui_list = VBoxContainer.new()
	_ui_list.add_theme_constant_override("separation", 6)
	root.add_child(_ui_list)

	var close_btn := Button.new()
	close_btn.text = "Close  [Y]"
	_style_button(close_btn)
	close_btn.pressed.connect(close_ferry)
	root.add_child(close_btn)


func _rebuild_ui() -> void:
	if _ui_list == null:
		return
	for c: Node in _ui_list.get_children():
		c.queue_free()
	var actor: Node = _ui_actor if _ui_actor != null else _player()
	var gold: int = _gold(actor)
	var gold_lbl := _make_label("Purse: %d gold" % gold, 13, Color(0.95, 0.86, 0.5))
	_ui_list.add_child(gold_lbl)
	# One row per route: name, docks, fare, and a Depart button (gated).
	for r_v: Variant in all_routes():
		var r: Dictionary = _dict(r_v)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var from_name: String = str(dock_def(str(r.get("from_dock", ""))).get("name", r.get("from_dock", "")))
		var to_name: String = str(dock_def(str(r.get("to_dock", ""))).get("name", r.get("to_dock", "")))
		var info := _make_label("%s\n  %s  ->  %s   (%d gold)" % [
				str(r.get("name", "Ferry")), from_name, to_name, int(r.get("fare", 0))],
				12, Color(0.88, 0.86, 0.8))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var depart := Button.new()
		var reason: String = travel_blocked_reason(actor, r)
		depart.text = "Depart" if reason == "" else reason.capitalize()
		depart.disabled = reason != ""
		_style_button(depart)
		var rid: String = str(r.get("id", ""))
		depart.pressed.connect(func() -> void: _on_depart(rid))
		row.add_child(depart)
		_ui_list.add_child(row)


func _on_depart(route_id: String) -> void:
	var actor: Node = _ui_actor if _ui_actor != null else _player()
	close_ferry()
	await travel(actor, route_id)


# --- Input ('Y' toggles the ferry route menu) -------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_Y:
		return
	if _in_voyage:
		return
	if not _ui_open and (_player() == null or _panel_blocking()):
		return
	get_viewport().set_input_as_handled()
	toggle_ferry()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Styling helpers --------------------------------------------------------

func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.04, 0.94)
	sb.border_color = Color(0.62, 0.5, 0.28, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.48))
	var f: FontFile = load(FONT_PATH) as FontFile
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 13)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var f: FontFile = load(FONT_PATH) as FontFile
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01))
	l.add_theme_constant_override("outline_size", 4)
	return l


# --- Env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	# Let the world + player settle for a few frames (if any exist).
	for _i in range(30):
		if get_tree() == null:
			return
		await get_tree().process_frame
	if not OS.get_environment("RH_FERRY_TEST").is_empty():
		await _self_test()
		return
	# RH_FERRY (no _TEST): just open the ferry menu for a screenshot.
	open_ferry(_player())


func _self_test() -> void:
	print("[FERRY_TEST] ===== Raven Hollow Grey Ferry self-test =====")
	var routes_n: int = route_count()
	print("[FERRY_TEST] routes loaded = %d ; docks = %d" % [routes_n, _docks.size()])
	# 1) list_routes from a real dock -- must be >= 1.
	var dock: String = "riverfork.ferry_dock"
	var from_dock: Array = list_routes(dock)
	if from_dock.is_empty() and routes_n > 0:
		# Fall back to whatever dock the first route departs from.
		dock = str(_dict(all_routes()[0]).get("from_dock", dock))
		from_dock = list_routes(dock)
	print("[FERRY_TEST] list_routes('%s') = %d route(s)" % [dock, from_dock.size()])
	for r_v: Variant in from_dock:
		var r: Dictionary = _dict(r_v)
		print("[FERRY_TEST]   route '%s' : %s -> %s  fare=%d  voyage=%s" % [
				str(r.get("id", "?")), str(r.get("from_dock", "")),
				str(r.get("to_dock", "")), int(r.get("fare", 0)), str(r.get("voyage", ""))])
	# 2) run travel() with the voyage interlude to completion, accelerated, with
	#    the real map change suppressed (asserts arrived signal, no world needed).
	var arrived := {"v": false, "dock": ""}
	var started := {"v": false}
	var requested := {"v": false}
	var vs := func(_a: Variant, _rid: Variant) -> void: started["v"] = true
	var ar := func(_a: Variant, _rid: Variant, d: Variant) -> void:
		arrived["v"] = true
		arrived["dock"] = str(d)
	var mr := func(_m: Variant, _p: Variant) -> void: requested["v"] = true
	voyage_started.connect(vs)
	ferry_arrived.connect(ar)
	map_change_requested.connect(mr)
	_time_scale = 0.03
	_suppress_map_change = true
	var route_id: String = str(_dict(from_dock[0]).get("id", "")) if not from_dock.is_empty() else ""
	var pl: Node = _player()   # may be null -- travel must survive it
	print("[FERRY_TEST] boarding route '%s' (player=%s) ..." % [route_id, str(pl != null)])
	# test-only: fund the fare so can_travel passes (shipped travel() correctly gates on gold)
	if pl != null and _has_prop(pl, "gold"):
		pl.set("gold", int(pl.get("gold")) + 100)
	var ok: bool = false
	if route_id != "":
		ok = await travel(pl, route_id)
	_time_scale = 1.0
	_suppress_map_change = false
	voyage_started.disconnect(vs)
	ferry_arrived.disconnect(ar)
	map_change_requested.disconnect(mr)
	print("[FERRY_TEST] travel ok=%s  voyage_started=%s  arrived=%s (dock=%s)  map_requested=%s" % [
			str(ok), str(started["v"]), str(arrived["v"]), str(arrived["dock"]), str(requested["v"])])
	var pass_ok: bool = routes_n >= 1 and from_dock.size() >= 1 and ok \
			and started["v"] and arrived["v"] and not _in_voyage
	print("FERRY SELFTEST %s routes=%d" % [("PASS" if pass_ok else "FAIL"), routes_n])
	print("[FERRY_TEST] ===== self-test complete =====")
	if get_tree() != null:
		get_tree().quit(0 if pass_ok else 1)


# --- fare / gold helpers (guarded) ------------------------------------------

func _gold(actor: Node) -> int:
	# Degrade OPEN: with no gold property the fare is treated as affordable so a
	# bare boot (no player) never falsely blocks travel.
	if actor == null or not _has_prop(actor, "gold"):
		return 0x7fffffff
	var g: Variant = actor.get("gold")
	return int(g) if (g is int or g is float) else 0x7fffffff


func _spend_gold(actor: Node, amount: int) -> void:
	if actor == null or amount <= 0 or not _has_prop(actor, "gold"):
		return
	var g: Variant = actor.get("gold")
	if g is int or g is float:
		actor.set("gold", maxi(0, int(g) - amount))


# --- misc helpers -----------------------------------------------------------

func _resolve_route(route: Variant) -> Dictionary:
	if route is Dictionary:
		var d: Dictionary = route
		if d.has("id") and _routes.has(str(d["id"])):
			return _dict(_routes[str(d["id"])])
		return d
	if route is String or route is StringName:
		return route_def(str(route))
	return {}


func _sleep(t: float) -> void:
	var remaining: float = maxf(0.0, t) * _time_scale
	while remaining > 0.0:
		if get_tree() == null:
			return
		var step: float = minf(0.05, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step


func _player() -> Node:
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _color(s: String) -> Color:
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return Color(0.54, 0.57, 0.61, 1.0)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("FerrySystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	return {}


func deserialize(_d: Dictionary) -> void:
	pass
