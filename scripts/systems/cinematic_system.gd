extends Node
## CinematicSystem -- autoload (/root/CinematicSystem). Backlog #51 "Cinematics".
## A data-driven in-world cutscene PLAYER (design/CINEMATICS.md Part B, the
## in-engine sequences). Named cinematics load from data/cinematics.json as flat
## lists of STEPS; play(id) runs them in order via await get_tree timers, drives a
## self-instanced CanvasLayer (two letterbox bars + a subtitle Label + a fade
## ColorRect + a flash ColorRect) and a dedicated CineCam that pans/zooms/shakes,
## then hands control back. No AnimationPlayer authoring, no per-scene tooling --
## the sequences ARE the data, exactly like the rest of Raven Hollow.
##
## Everything here is additive and null-safe: no other system's file is edited.
## Player input is blocked during playback (guarded: only if a player node
## exists), the camera is commandeered by a temporary CineCam and restored on
## finish, and every op degrades to a no-op when its target is missing (sfx skips
## if the audio file is absent; camera ops skip with no viewport camera).
##
## Step ops (data/cinematics.json): letterbox_in, letterbox_out, camera_pan
## {to:[dx,dy], duration}, camera_zoom {zoom, duration}, show_text {speaker, line,
## duration}, fade_to_black {duration}, fade_from_black {duration}, wait
## {duration}, spawn_actor {id, pos:[x,y], color}, move_actor {id, to:[x,y],
## duration}, sfx {path}, flash {duration, color}, shake {amp, duration}.
##
## Public API:
##   play(id) -> void            run a cinematic to completion (awaitable coroutine)
##   skip() -> void              abort the running cinematic (Esc)
##   is_playing() -> bool
##   current() -> String         id of the running cinematic ("" if idle)
##   has_cinematic(id) -> bool
##   ids() -> Array / cinematic_def(id) -> Dictionary / count() -> int
##   was_seen(id) -> bool
## Signals: cinematic_started(id), cinematic_finished(id).

signal cinematic_started(id)
signal cinematic_finished(id)

const DATA_PATH := "res://data/cinematics.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const CANVAS_LAYER := 88

var _cines: Dictionary = {}             # id -> def dict
var _cfg: Dictionary = {}

var _playing: bool = false
var _skip: bool = false
var _current: String = ""
var _time_scale: float = 1.0            # <1.0 accelerates (selftest)
var _seen: Dictionary = {}              # id -> true

# --- Self-instanced UI (built lazily on first play) ---
var _layer: CanvasLayer = null
var _bar_top: ColorRect = null
var _bar_bot: ColorRect = null
var _fade: ColorRect = null
var _flash: ColorRect = null
var _sub_panel: PanelContainer = null
var _sub_speaker: Label = null
var _sub_line: Label = null

var _cine_cam: Camera2D = null
var _prev_cam: Camera2D = null
var _actors: Dictionary = {}            # actor id -> Node2D marker
var _sfx_player: AudioStreamPlayer = null
var _input_blocked: bool = false


func _ready() -> void:
	_load_data()
	if not OS.get_environment("RH_CINE_TEST").is_empty() \
			or not OS.get_environment("RH_CINE").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_cfg = _dict(root.get("config", {}))
	_cines = _dict(root.get("cinematics", {}))
	if _cines.is_empty():
		push_warning("CinematicSystem: no cinematics loaded from %s" % DATA_PATH)


# --- Public API -------------------------------------------------------------

func has_cinematic(id: String) -> bool:
	return _cines.has(id)


func ids() -> Array:
	return _cines.keys()


func count() -> int:
	return _cines.size()


func cinematic_def(id: String) -> Dictionary:
	return _dict(_cines.get(id, {}))


func is_playing() -> bool:
	return _playing


func current() -> String:
	return _current


func was_seen(id: String) -> bool:
	return _seen.has(id)


## Run a cinematic to completion. Awaitable: callers may `await play(id)`.
func play(id: String) -> void:
	if _playing:
		return
	var def: Dictionary = cinematic_def(id)
	if def.is_empty():
		push_warning("CinematicSystem: unknown cinematic '%s'" % id)
		return
	_playing = true
	_skip = false
	_current = id
	_seen[id] = true
	_ensure_ui()
	var use_bars: bool = bool(def.get("letterbox", true))
	_block_input(true)
	_begin_camera()
	cinematic_started.emit(id)
	if use_bars:
		await _op_letterbox(true, 0.35)
	for step_v: Variant in _arr(def.get("steps", [])):
		if _skip:
			break
		await _run_step(_dict(step_v))
	await _finish(id)


func skip() -> void:
	if _playing:
		_skip = true


# --- Step dispatch ----------------------------------------------------------

func _run_step(step: Dictionary) -> void:
	var op: String = str(step.get("op", ""))
	var dur: float = float(step.get("duration", 0.0))
	match op:
		"letterbox_in":
			await _op_letterbox(true, _pos(dur, 0.5))
		"letterbox_out":
			await _op_letterbox(false, _pos(dur, 0.5))
		"camera_pan":
			await _op_camera_pan(_v2(step.get("to", [])), _pos(dur, 2.0))
		"camera_zoom":
			await _op_camera_zoom(float(step.get("zoom", 1.0)), _pos(dur, 1.5))
		"show_text":
			await _op_show_text(str(step.get("speaker", "")), str(step.get("line", "")),
					_pos(dur, float(_cfg.get("default_text_dur", 3.2))))
		"fade_to_black":
			await _op_fade(1.0, _pos(dur, 0.6))
		"fade_from_black":
			await _op_fade(0.0, _pos(dur, 0.6))
		"wait":
			await _sleep(_pos(dur, 0.5))
		"spawn_actor":
			_op_spawn_actor(str(step.get("id", "")), _v2(step.get("pos", [])),
					_color(str(step.get("color", "#c8c8c8"))))
		"move_actor":
			await _op_move_actor(str(step.get("id", "")), _v2(step.get("to", [])), _pos(dur, 1.0))
		"sfx":
			_op_sfx(str(step.get("path", "")))
		"flash":
			await _op_flash(_color(str(step.get("color", "#ffffff"))), _pos(dur, 0.4))
		"shake":
			await _op_shake(float(step.get("amp", 6.0)), _pos(dur, 0.6))
		_:
			push_warning("CinematicSystem: unknown op '%s'" % op)


# --- Ops --------------------------------------------------------------------

func _op_letterbox(on: bool, dur: float) -> void:
	if _bar_top == null:
		return
	var h: float = _bar_height()
	var top_to: float = h if on else 0.0
	var bot_to: float = -h if on else 0.0
	var d: float = _dur(dur)
	if d <= 0.0:
		_bar_top.offset_bottom = top_to
		_bar_bot.offset_top = bot_to
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", top_to, d)
	tw.tween_property(_bar_bot, "offset_top", bot_to, d)
	await _sleep(dur)


func _op_camera_pan(offset: Vector2, dur: float) -> void:
	if _cine_cam == null or not is_instance_valid(_cine_cam):
		await _sleep(dur)
		return
	var target: Vector2 = _cine_cam.global_position + offset
	var d: float = _dur(dur)
	if d <= 0.0:
		_cine_cam.global_position = target
	else:
		var tw: Tween = create_tween()
		tw.tween_property(_cine_cam, "global_position", target, d).set_trans(Tween.TRANS_SINE)
	await _sleep(dur)


func _op_camera_zoom(zoom: float, dur: float) -> void:
	if _cine_cam == null or not is_instance_valid(_cine_cam):
		await _sleep(dur)
		return
	var z: float = maxf(0.05, zoom)
	var target := Vector2(z, z)
	var d: float = _dur(dur)
	if d <= 0.0:
		_cine_cam.zoom = target
	else:
		var tw: Tween = create_tween()
		tw.tween_property(_cine_cam, "zoom", target, d).set_trans(Tween.TRANS_SINE)
	await _sleep(dur)


func _op_show_text(speaker: String, line: String, dur: float) -> void:
	if _sub_panel != null:
		_sub_speaker.text = speaker
		_sub_speaker.visible = speaker != ""
		_sub_line.text = line
		_sub_panel.visible = true
		_sub_panel.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_sub_panel, "modulate:a", 1.0, minf(_dur(0.3), _dur(dur)))
	await _sleep(dur)


func _op_fade(to_alpha: float, dur: float) -> void:
	if _fade == null:
		return
	var d: float = _dur(dur)
	if d <= 0.0:
		_fade.color.a = to_alpha
		return
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", to_alpha, d)
	await _sleep(dur)


func _op_spawn_actor(id: String, pos: Vector2, col: Color) -> void:
	if id == "":
		return
	var parent: Node = _world_parent()
	if parent == null:
		return
	var anchor: Vector2 = _anchor_pos()
	var holder := Node2D.new()
	holder.name = "CineActor_" + id
	holder.global_position = anchor + pos
	holder.z_index = 50
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse(14.0, 5.0, Vector2(0.0, 0.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	holder.add_child(shadow)
	var body := Polygon2D.new()
	body.polygon = _ellipse(11.0, 16.0, Vector2(0.0, -16.0))
	body.color = col
	holder.add_child(body)
	parent.add_child(holder)
	if _actors.has(id) and is_instance_valid(_actors[id]):
		(_actors[id] as Node).queue_free()
	_actors[id] = holder


func _op_move_actor(id: String, to: Vector2, dur: float) -> void:
	if not _actors.has(id) or not is_instance_valid(_actors[id]):
		await _sleep(dur)
		return
	var node := _actors[id] as Node2D
	var target: Vector2 = _anchor_pos() + to
	var d: float = _dur(dur)
	if d <= 0.0:
		node.global_position = target
	else:
		var tw: Tween = create_tween()
		tw.tween_property(node, "global_position", target, d)
	await _sleep(dur)


func _op_sfx(path: String) -> void:
	# Guarded: silent no-op if the clip is absent (audio is a later art pass).
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if _sfx_player == null or not is_instance_valid(_sfx_player):
		_sfx_player = AudioStreamPlayer.new()
		add_child(_sfx_player)
	_sfx_player.stream = stream
	_sfx_player.play()


func _op_flash(col: Color, dur: float) -> void:
	if _flash == null:
		await _sleep(dur)
		return
	_flash.color = Color(col.r, col.g, col.b, 0.0)
	var half: float = maxf(0.01, _dur(dur) * 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "color:a", 0.7, half)
	tw.tween_property(_flash, "color:a", 0.0, half)
	await _sleep(dur)


func _op_shake(amp: float, dur: float) -> void:
	var d: float = _dur(dur)
	var elapsed: float = 0.0
	while elapsed < d and not _skip:
		if _cine_cam != null and is_instance_valid(_cine_cam):
			_cine_cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		if get_tree() == null:
			break
		await get_tree().create_timer(0.03).timeout
		elapsed += 0.03
	if _cine_cam != null and is_instance_valid(_cine_cam):
		_cine_cam.offset = Vector2.ZERO


# --- Lifecycle --------------------------------------------------------------

func _finish(id: String) -> void:
	# Bars + fade off, subtitle hidden, temp actors freed, camera + input restored.
	if _bar_top != null:
		_bar_top.offset_bottom = 0.0
		_bar_bot.offset_top = 0.0
	if _sub_panel != null:
		_sub_panel.visible = false
	if _fade != null:
		_fade.color.a = 0.0
	if _flash != null:
		_flash.color.a = 0.0
	for k: Variant in _actors.keys():
		if is_instance_valid(_actors[k]):
			(_actors[k] as Node).queue_free()
	_actors.clear()
	_end_camera()
	_block_input(false)
	_playing = false
	var done_id: String = _current
	_current = ""
	cinematic_finished.emit(done_id)
	# Yield one frame so awaiters resume cleanly.
	if get_tree() != null:
		await get_tree().process_frame


# --- Camera commandeering ----------------------------------------------------

func _begin_camera() -> void:
	var vp: Viewport = get_viewport()
	_prev_cam = vp.get_camera_2d() if vp != null else null
	var parent: Node = _world_parent()
	if parent == null:
		return
	_cine_cam = Camera2D.new()
	_cine_cam.name = "CineCam"
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_cine_cam.global_position = _prev_cam.global_position
		_cine_cam.zoom = _prev_cam.zoom
	else:
		_cine_cam.zoom = Vector2.ONE
	parent.add_child(_cine_cam)
	_cine_cam.make_current()


func _end_camera() -> void:
	if _cine_cam != null and is_instance_valid(_cine_cam):
		_cine_cam.queue_free()
	_cine_cam = null
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null


func _anchor_pos() -> Vector2:
	if _cine_cam != null and is_instance_valid(_cine_cam):
		return _cine_cam.global_position
	var pl: Node = _player()
	if pl is Node2D:
		return (pl as Node2D).global_position
	return Vector2.ZERO


# --- Input block (guarded; only if a player node exists) --------------------

func _block_input(on: bool) -> void:
	var pl: Node = _player()
	if pl == null:
		_input_blocked = false
		return
	if on and not _input_blocked:
		_input_blocked = true
		if pl.has_method("set_physics_process"):
			pl.set_physics_process(false)
		if pl is Node2D and _has_prop(pl, "velocity"):
			pl.set("velocity", Vector2.ZERO)
	elif not on and _input_blocked:
		_input_blocked = false
		if is_instance_valid(pl) and pl.has_method("set_physics_process"):
			pl.set_physics_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		var def: Dictionary = cinematic_def(_current)
		if bool(def.get("skippable", true)):
			get_viewport().set_input_as_handled()
			skip()


# --- UI construction --------------------------------------------------------

func _ensure_ui() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.layer = CANVAS_LAYER
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

	_bar_top = ColorRect.new()
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.color = Color(0.0, 0.0, 0.0, 1.0)
	_bar_top.offset_top = 0.0
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_top)

	_bar_bot = ColorRect.new()
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.color = Color(0.0, 0.0, 0.0, 1.0)
	_bar_bot.offset_top = 0.0
	_bar_bot.offset_bottom = 0.0
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_bot)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)

	_build_subtitle()


func _build_subtitle() -> void:
	_sub_panel = PanelContainer.new()
	_sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_panel.position = Vector2(-300.0, -120.0)
	_sub_panel.custom_minimum_size = Vector2(600.0, 0.0)
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.03, 0.86)
	sb.border_color = Color(0.62, 0.5, 0.28, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_sub_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_sub_panel.add_child(vb)
	_sub_speaker = _make_label("", 15, Color(0.92, 0.78, 0.42))
	_sub_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_sub_speaker)
	_sub_line = _make_label("", 12, Color(0.9, 0.87, 0.8))
	_sub_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_line.custom_minimum_size = Vector2(568.0, 0.0)
	_sub_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_sub_line)
	_sub_panel.visible = false
	_layer.add_child(_sub_panel)


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


func _bar_height() -> float:
	var frac: float = float(_cfg.get("letterbox_fraction", 0.13))
	var vp: Viewport = get_viewport()
	var h: float = 1080.0
	if vp != null:
		h = vp.get_visible_rect().size.y
	if h <= 0.0:
		h = 1080.0
	return h * frac


# --- Env self-test / autoplay hooks -----------------------------------------

func _run_env_hooks() -> void:
	# Let the world + player settle for a few frames.
	for _i in range(30):
		if get_tree() == null:
			return
		await get_tree().process_frame
	if not OS.get_environment("RH_CINE_TEST").is_empty():
		await _selftest()
		return
	var id: String = OS.get_environment("RH_CINE")
	if has_cinematic(id):
		await play(id)


func _selftest() -> void:
	print("[CINE_TEST] ===== Raven Hollow cinematic self-test =====")
	print("[CINE_TEST] loaded %d cinematics: %s" % [count(), str(ids())])
	var started := {"v": false}
	var finished := {"v": false}
	cinematic_started.connect(func(_id: String) -> void: started["v"] = true)
	cinematic_finished.connect(func(_id: String) -> void: finished["v"] = true)
	_time_scale = 0.04
	var test_id: String = "intro"
	if not has_cinematic(test_id):
		test_id = str(ids()[0]) if count() > 0 else ""
	var step_count: int = _arr(cinematic_def(test_id).get("steps", [])).size()
	print("[CINE_TEST] playing '%s' (%d steps) at %.0f%% time..." % [
			test_id, step_count, _time_scale * 100.0])
	await play(test_id)
	var ok: bool = started["v"] and finished["v"] and step_count > 0 \
			and not _playing and was_seen(test_id)
	print("[CINE_TEST] started=%s finished=%s idle_after=%s seen=%s" % [
			str(started["v"]), str(finished["v"]), str(not _playing), str(was_seen(test_id))])
	print("CINE SELFTEST %s" % ("PASS" if ok else "FAIL"))
	print("[CINE_TEST] ===== self-test complete =====")
	if get_tree() != null:
		get_tree().quit(0 if ok else 1)


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	return {"seen": _seen.keys()}


func deserialize(d: Dictionary) -> void:
	_seen.clear()
	for id_v: Variant in _arr(d.get("seen", [])):
		_seen[str(id_v)] = true


# --- helpers ----------------------------------------------------------------

func _sleep(t: float) -> void:
	var remaining: float = t * _time_scale
	while remaining > 0.0 and not _skip:
		if get_tree() == null:
			return
		var step: float = minf(0.05, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step


func _dur(t: float) -> float:
	return maxf(0.0, t * _time_scale)


func _pos(v: float, dflt: float) -> float:
	return v if v > 0.0 else dflt


func _world_parent() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return self


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


func _ellipse(rx: float, ry: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _color(s: String) -> Color:
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return Color(1.0, 1.0, 1.0, 1.0)


func _v2(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CinematicSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
