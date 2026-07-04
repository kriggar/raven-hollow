class_name PauseMenu
extends CanvasLayer
## Esc pause panel for "Raven Hollow" (Phase C demo, spec §6). Fully
## code-built GK style: dim scrim + dark-wood panel with Resume / Save /
## Music-volume slider / Quit to Menu. Owns get_tree().paused (true while
## open) and persists the music volume in user://settings.cfg. Keyboard
## (arrows/WASD + Enter, Esc resumes) AND mouse.
##
## This file deliberately does NOT touch player.gd / bag_ui.gd /
## character_sheet_ui.gd — it listens for ui_cancel in its OWN
## _unhandled_input and self-gates against their existing Esc behavior
## (see INTEGRATION §3).
##
## ============================ INTEGRATION =================================
## (expected hooks for the integration pass — nothing below is wired here)
##
## 1. main.gd: add_child(PauseMenu.new()) in _bootstrap_world (with the
##    other UI layers; it is layer 30 and hidden until opened). Screenshot
##    harness can force it: get_tree().call_group("pause_menu", "open").
## 2. Pausing model: THIS file sets get_tree().paused = true in open() and
##    false in close(). Gameplay nodes keep the default
##    PROCESS_MODE_INHERIT and freeze automatically; this layer is
##    PROCESS_MODE_ALWAYS. Two integrator changes expected in main.gd:
##      a. the "Music" AudioStreamPlayer gets
##         process_mode = Node.PROCESS_MODE_ALWAYS so the theme keeps
##         playing under the pause panel (today it would freeze);
##      b. map system: after change_map() (re)creates a music player, call
##         get_tree().call_group("pause_menu", "apply_music_volume") so the
##         user's volume survives the swap.
## 3. Esc precedence (verified against the current handlers — NO changes
##    needed in player.gd / bag_ui.gd / character_sheet_ui.gd /
##    dialogue_ui.gd): dialogue consumes Esc itself; bag/sheet close on the
##    same un-consumed Esc without marking it handled; player.gd clears its
##    target on Esc when no panel was open (via its physics-tick snapshot).
##    This menu therefore OPENS only when, at the previous physics tick:
##      (a) none of groups bag_ui / sheet_ui / dialogue_ui had
##          is_open == true (that Esc belongs to them),
##      (b) the player had no target (Esc #1 clears target, Esc #2 pauses —
##          WoW-style), and at event time
##      (c) a node in group "player" exists (world built) and
##      (d) no MainMenu (group "main_menu") is showing.
##    While open, Esc closes it and IS marked handled (nothing else may
##    react — everything else is paused anyway).
## 4. Music volume: the slider drives the AudioStreamPlayer found via group
##    "music" (PREFERRED — integrator adds the group in main.gd's
##    _start_music) with a fallback to the node literally named "Music"
##    anywhere in the tree (matches main.gd today). The player's original
##    volume_db is cached in node metadata and offset by
##    linear_to_db(fraction), so main.gd's -14 dB mix baseline is what
##    "100%" means. Persisted at user://settings.cfg [audio] music_volume;
##    applied on boot (short retry window until the player exists) and on
##    every open/change.
## 5. Save button: probes a node in group "save_system" first, then the
##    static API of res://scripts/save_system.gd (peer file, loaded
##    dynamically so this script parses before it lands). Expected shape:
##        static func save_game() -> bool        # or save_game(tree)
##    void returns are treated as success. save_requested is emitted first
##    in case main.gd prefers to orchestrate the save itself.
## 6. Quit to Menu: emits quit_to_menu AFTER closing (tree unpaused).
##    main.gd connects it: free World + gameplay UIs + this menu, then show
##    a fresh MainMenu (see main_menu.gd INTEGRATION block).
## 7. project.godot: NO new input action needed — Esc is the built-in
##    ui_cancel (the spec's "pause" action is satisfied by it).
## ===========================================================================

signal opened
signal closed
signal save_requested
signal quit_to_menu

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(0.96, 0.8, 0.45)
const GOLD_DIM := Color(0.62, 0.48, 0.26)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.98)
const ROW_BG := Color(0.12, 0.095, 0.075, 0.9)
const ROW_BG_FOCUS := Color(0.16, 0.125, 0.09, 0.95)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.55)

const VIEW := Vector2(640.0, 360.0)
const PANEL_SIZE := Vector2(216.0, 186.0)
const ROW_SIZE := Vector2(176.0, 26.0)
const ROWS_TOP := 40.0
const ROW_STEP := 32.0
const MENU_LAYER := 30
const VOLUME_STEP := 0.05
const MUTE_DB := -80.0
const BOOT_APPLY_FRAMES := 300  # ~5 s window to catch main.gd's music player

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_SYSTEM_PATH := "res://scripts/save_system.gd"
const MUSIC_BASE_META := "rh_music_base_db"

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")

## Per-row bag: {kind: "button"|"slider", action: String, root: Panel,
##               style: StyleBoxFlat, label: Label}
var _rows: Array[Dictionary] = []
var _focus: int = 0
var _volume: float = 1.0

var _root: Control
var _panel: Panel
var _slider: HSlider
var _pct_label: Label
var _hint: Label
var _open_tween: Tween
var _toast_tween: Tween

## Physics-tick snapshot: "this Esc belongs to someone else" (a UI panel was
## open, or the player had a target to clear). Same order-independence trick
## player.gd uses for its own Esc handling.
var _esc_gate: bool = false
var _boot_apply_frames: int = BOOT_APPLY_FRAMES


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_load_settings()
	_build_ui()
	_root.visible = false


func _physics_process(_delta: float) -> void:
	# Boot-time volume apply: main.gd creates the music player after we may
	# already exist — poll briefly (every 30 frames) until it shows up.
	if _boot_apply_frames > 0:
		_boot_apply_frames -= 1
		if _boot_apply_frames % 30 == 0 and _find_music_player() != null:
			_boot_apply_frames = 0
			apply_music_volume()
	if not is_open:
		_esc_gate = _other_panel_open() or _player_has_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open:
			get_viewport().set_input_as_handled()
			close()
		elif _can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if not is_open or _rows.is_empty():
		return
	if _nav_pressed(event, "ui_up", "move_up"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + _rows.size() - 1) % _rows.size())
	elif _nav_pressed(event, "ui_down", "move_down"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + 1) % _rows.size())
	elif _nav_pressed(event, "ui_left", "move_left"):
		if String(_rows[_focus].kind) == "slider":
			get_viewport().set_input_as_handled()
			_slider.value = clampf(_slider.value - VOLUME_STEP, 0.0, 1.0)
	elif _nav_pressed(event, "ui_right", "move_right"):
		if String(_rows[_focus].kind) == "slider":
			get_viewport().set_input_as_handled()
			_slider.value = clampf(_slider.value + VOLUME_STEP, 0.0, 1.0)
	elif event.is_action_pressed("ui_accept"):
		if String(_rows[_focus].kind) == "button":
			get_viewport().set_input_as_handled()
			_activate(String(_rows[_focus].action))


func _nav_pressed(event: InputEvent, ui_action: String, move_action: String) -> bool:
	if event.is_action_pressed(ui_action):
		return true
	return InputMap.has_action(move_action) and event.is_action_pressed(move_action)


# ---------------------------------------------------------------- gating

func _can_open() -> bool:
	if is_open:
		return false
	if get_tree().get_first_node_in_group("main_menu") != null:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false  # world not built yet (boot / class select)
	return not _esc_gate


func _other_panel_open() -> bool:
	for grp: String in ["bag_ui", "sheet_ui", "dialogue_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and n.get("is_open") == true:
			return true
	return false


func _player_has_target() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var t: Variant = p.get("target")
	return t is Node and is_instance_valid(t)


# ---------------------------------------------------------------- open/close

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	_focus = 0
	_apply_focus()
	_refresh_volume_ui()
	apply_music_volume()
	_hint_default()
	_root.visible = true
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.9, 0.9)
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_root, "modulate:a", 1.0, 0.12)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_root.visible = false
	_root.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	_save_settings()
	closed.emit()


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Scrim: darkens the frozen world and swallows stray clicks.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 6
	_panel = Panel.new()
	_panel.name = "PausePanel"
	_panel.position = (VIEW - PANEL_SIZE) * 0.5
	_panel.size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "Paused"
	_style_label(title, 18, GOLD)
	title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 8.0)
	title.size = Vector2(PANEL_SIZE.x, 22.0)
	_panel.add_child(title)

	_add_button_row("Resume", "resume")
	_add_button_row("Save", "save")
	_add_slider_row()
	_add_button_row("Quit to Menu", "quit_menu")

	_hint = Label.new()
	_hint.name = "Hint"
	_style_label(_hint, 9, PARCHMENT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(10.0, PANEL_SIZE.y - 22.0)
	_hint.size = Vector2(PANEL_SIZE.x - 20.0, 14.0)
	_panel.add_child(_hint)
	_hint_default()

	_apply_focus()


func _make_row_panel(kind: String, action: String) -> Dictionary:
	var index: int = _rows.size()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)

	var panel := Panel.new()
	panel.name = "Row_" + (action if not action.is_empty() else kind)
	panel.position = Vector2((PANEL_SIZE.x - ROW_SIZE.x) * 0.5, ROWS_TOP + float(index) * ROW_STEP)
	panel.size = ROW_SIZE
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(_on_row_hover.bind(index))
	_panel.add_child(panel)

	return {"kind": kind, "action": action, "root": panel, "style": style, "label": null}


func _add_button_row(text: String, action: String) -> void:
	var row: Dictionary = _make_row_panel("button", action)
	var panel: Panel = row.root
	panel.gui_input.connect(_on_row_gui_input.bind(_rows.size()))

	var label := Label.new()
	label.text = text
	_style_label(label, 12, PARCHMENT)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

	row.label = label
	_rows.append(row)


func _add_slider_row() -> void:
	var row: Dictionary = _make_row_panel("slider", "")
	var panel: Panel = row.root

	var label := Label.new()
	label.text = "Music"
	_style_label(label, 11, PARCHMENT)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(8.0, 0.0)
	label.size = Vector2(44.0, ROW_SIZE.y)
	panel.add_child(label)

	_slider = HSlider.new()
	_slider.name = "MusicSlider"
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = VOLUME_STEP
	_slider.value = _volume
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.position = Vector2(56.0, 5.0)
	_slider.size = Vector2(84.0, 16.0)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.05, 0.04, 0.035)
	groove.border_color = PANEL_BORDER
	groove.set_border_width_all(1)
	groove.content_margin_top = 5.0
	groove.content_margin_bottom = 5.0
	_slider.add_theme_stylebox_override("slider", groove)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD_DIM
	_slider.add_theme_stylebox_override("grabber_area", fill)
	var fill_hl := StyleBoxFlat.new()
	fill_hl.bg_color = GOLD
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl)
	_slider.add_theme_icon_override("grabber", _make_grabber_icon(false))
	_slider.add_theme_icon_override("grabber_highlight", _make_grabber_icon(true))
	_slider.value_changed.connect(_on_volume_changed)
	panel.add_child(_slider)

	_pct_label = Label.new()
	_style_label(_pct_label, 10, GOLD)
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pct_label.position = Vector2(144.0, 0.0)
	_pct_label.size = Vector2(26.0, ROW_SIZE.y)
	panel.add_child(_pct_label)

	row.label = label
	_rows.append(row)
	_refresh_volume_ui()


func _make_grabber_icon(bright: bool) -> ImageTexture:
	var img := Image.create_empty(6, 12, false, Image.FORMAT_RGBA8)
	img.fill(GOLD_BRIGHT if bright else GOLD)
	for x in range(6):
		img.set_pixel(x, 0, OUTLINE_DARK)
		img.set_pixel(x, 11, OUTLINE_DARK)
	for y in range(12):
		img.set_pixel(0, y, OUTLINE_DARK)
		img.set_pixel(5, y, OUTLINE_DARK)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- focus

func _on_row_hover(index: int) -> void:
	if is_open:
		_set_focus(index)


func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_set_focus(index)
			_activate(String(_rows[index].action))


func _set_focus(index: int) -> void:
	if index == _focus or index < 0 or index >= _rows.size():
		return
	_focus = index
	_apply_focus()


func _apply_focus() -> void:
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var focused: bool = i == _focus
		var style: StyleBoxFlat = row.style
		style.border_color = GOLD if focused else PANEL_BORDER
		style.bg_color = ROW_BG_FOCUS if focused else ROW_BG
		var label_v: Variant = row.label
		if label_v is Label:
			(label_v as Label).add_theme_color_override(
				"font_color", GOLD_BRIGHT if focused else PARCHMENT)


# ---------------------------------------------------------------- actions

func _activate(action: String) -> void:
	match action:
		"resume":
			close()
		"save":
			_do_save()
		"quit_menu":
			_do_quit_to_menu()


func _do_save() -> void:
	save_requested.emit()
	if _try_save():
		_show_toast("Game saved.")
	else:
		_show_toast("Could not save (no SaveSystem).")


func _do_quit_to_menu() -> void:
	close()
	if quit_to_menu.get_connections().is_empty():
		push_warning("pause_menu.gd: quit_to_menu not connected — the integration pass wires it to main.gd.")
	quit_to_menu.emit()


# ---------------------------------------------------------------- save probe

func _try_save() -> bool:
	## SaveSystem is a peer workflow's file — probe a live node first, then
	## the static API on the dynamically loaded script (keeps this file
	## parsing standalone before save_system.gd lands).
	var node: Node = get_tree().get_first_node_in_group("save_system")
	if node != null:
		return _invoke_save(node)
	if not ResourceLoader.exists(SAVE_SYSTEM_PATH):
		push_warning("pause_menu.gd: %s missing — Save is a no-op until the save workflow lands." % SAVE_SYSTEM_PATH)
		return false
	var script: GDScript = load(SAVE_SYSTEM_PATH) as GDScript
	if script == null:
		return false
	return _invoke_save(script)


func _invoke_save(target: Object) -> bool:
	var info: Dictionary = _method_info(target, "save_game")
	if info.is_empty():
		push_warning("pause_menu.gd: SaveSystem exposes no save_game() — cannot save.")
		return false
	if target is Script and (int(info.get("flags", 0)) & METHOD_FLAG_STATIC) == 0:
		push_warning("pause_menu.gd: SaveSystem.save_game is not static and no node sits in group 'save_system'.")
		return false
	var args: Array = info.get("args", [])
	var defaults: Array = info.get("default_args", [])
	var required: int = args.size() - defaults.size()
	var result: Variant = target.call("save_game") if required <= 0 else target.call("save_game", get_tree())
	if result is bool:
		return bool(result)
	return true  # void save_game() = assume success


func _method_info(target: Object, method_name: String) -> Dictionary:
	var script_obj := target as Script
	var list: Array = script_obj.get_script_method_list() if script_obj != null else target.get_method_list()
	for m: Variant in list:
		if m is Dictionary and String((m as Dictionary).get("name", "")) == method_name:
			return m
	return {}


# ---------------------------------------------------------------- volume

func _on_volume_changed(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	_refresh_volume_ui()
	apply_music_volume()
	_save_settings()


func _refresh_volume_ui() -> void:
	if _slider == null or _pct_label == null:
		return
	_slider.set_value_no_signal(_volume)
	_pct_label.text = "%d%%" % int(round(_volume * 100.0))


## Public — also invoked by the integrator after map changes:
##   get_tree().call_group("pause_menu", "apply_music_volume")
func apply_music_volume() -> void:
	var music: AudioStreamPlayer = _find_music_player()
	if music == null:
		return
	if not music.has_meta(MUSIC_BASE_META):
		music.set_meta(MUSIC_BASE_META, music.volume_db)
	var base_db: float = float(music.get_meta(MUSIC_BASE_META))
	music.volume_db = MUTE_DB if _volume <= 0.01 else base_db + linear_to_db(_volume)


func _find_music_player() -> AudioStreamPlayer:
	# Preferred: group "music" (INTEGRATION §4). Fallback: main.gd names its
	# player "Music" — find it anywhere in the tree (owned=false: runtime node).
	for node: Node in get_tree().get_nodes_in_group("music"):
		if node is AudioStreamPlayer:
			return node
	var named: Node = get_tree().root.find_child("Music", true, false)
	return named as AudioStreamPlayer


# ---------------------------------------------------------------- settings

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep any keys other systems may add
	cfg.set_value("audio", "music_volume", _volume)
	if cfg.save(SETTINGS_PATH) != OK:
		push_warning("pause_menu.gd: could not write %s" % SETTINGS_PATH)


# ---------------------------------------------------------------- toast/hint

func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_hint.text = text
	_hint.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_hint_default)


func _hint_default() -> void:
	_hint.text = "Esc — resume"
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)


# ---------------------------------------------------------------- helpers

func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
