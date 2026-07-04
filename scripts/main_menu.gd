class_name MainMenu
extends CanvasLayer
## Title screen for "Raven Hollow" (Phase C demo, spec §6). Fully code-built,
## Graveyard-Keeper mood: dark ember-lit backdrop (no shipped art required),
## drifting ember motes, Alagard gold title, New Game / Continue / Quit rows
## driven by keyboard AND mouse, quiet self-contained menu music. Emits
## menu_choice(action) with "new_game" | "continue" | "quit", then fades out
## and frees itself ("quit" also quits the tree after the fade).
##
## "Continue" only appears when a save exists. SaveSystem is a Phase C peer
## (res://scripts/save_system.gd) and is probed DYNAMICALLY so this file
## parses standalone before the save workflow lands.
##
## ============================ INTEGRATION =================================
## (expected hooks for the integration pass — nothing below is wired here)
##
## 1. main.gd boot flow (REPLACES "class select first"):
##        func _ready() -> void:
##            var action: String = await _prompt_main_menu()   # new helper
##            match action:
##                "new_game":
##                    var chosen: String = await _prompt_class_select()
##                    _bootstrap_world(chosen)
##                "continue":
##                    var state: Dictionary = SaveSystem.load_game()
##                    _bootstrap_world_from_save(state)   # skips class select
##            # "quit" never returns: the menu quits the tree after its fade.
##    _prompt_main_menu() mirrors _prompt_class_select(): create MainMenu.new()
##    (it draws its own opaque backdrop — no extra black layer needed),
##    add_child it, `await menu.menu_choice`, return the action. The menu
##    fades and frees itself after emitting.
## 2. Automation hooks: RH_CLASS / RH_SMOKE / RH_SHOT must SKIP this menu
##    exactly like they skip class select today (check the env vars BEFORE
##    adding the menu). Suggested new hook for visual QA: RH_MENU=1 shows
##    the menu, RH_SHOT captures it, then quit.
## 3. Quit-to-menu round trip: on PauseMenu.quit_to_menu, main.gd frees the
##    World + gameplay UI layers and shows a FRESH MainMenu.new() (the save
##    existence check runs at build time, so a save written this session
##    makes Continue appear on return).
## 4. Expected SaveSystem API (peer file, demo spec §6 save/load):
##        static func has_save() -> bool          # user://save1.json exists
##        static func load_game() -> Dictionary   # {} when absent/corrupt
##    Alternatively a Node in group "save_system" exposing has_save() —
##    both shapes are probed here, node first.
## 5. Layers: this menu is 30, above vignette 5 / HUD 8 / bag+sheet 9 /
##    dialogue 10 / select backdrop 15 / class select 20. Menu music is a
##    child of the menu (freed with it); main.gd's town theme starts later
##    in _bootstrap_world exactly as today.
## ===========================================================================

signal menu_choice(action: String)

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(0.96, 0.8, 0.45)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const PANEL_BG := Color(0.09, 0.07, 0.06, 0.96)
const PANEL_BG_FOCUS := Color(0.13, 0.1, 0.075, 0.96)
const PANEL_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BG_DARK := Color(0.055, 0.045, 0.04)
const EMBER_GLOW := Color(0.42, 0.26, 0.12, 0.34)
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.55)

const VIEW := Vector2(640.0, 360.0)
const TITLE_TOP := 58.0
const SUBTITLE_TOP := 116.0
const DIVIDER_TOP := 108.0
const BUTTONS_TOP := 178.0
const BUTTON_SIZE := Vector2(172.0, 26.0)
const BUTTON_GAP := 10.0
const FOCUS_SCALE := 1.04
const FADE_OUT_TIME := 0.4
const MENU_LAYER := 30

const SAVE_SYSTEM_PATH := "res://scripts/save_system.gd"
const MENU_MUSIC_PATH := "res://assets/audio/music/theme_lost_village.ogg"
const MENU_MUSIC_DB := -18.0
const MENU_MUSIC_FADE_DB := -44.0

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")

## Per-row bag: {action: String, root: Panel, style: StyleBoxFlat,
##               label: Label, tween: Tween-or-null}
var _rows: Array[Dictionary] = []
var _focus: int = 0
var _closing: bool = false

var _root: Control
var _music: AudioStreamPlayer
var _hint_label: Label


func _ready() -> void:
	layer = MENU_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("main_menu")
	_build_ui()
	_start_menu_music()
	if not _rows.is_empty():
		_apply_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _closing or _rows.is_empty():
		return
	if _nav_pressed(event, "ui_up", "move_up"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + _rows.size() - 1) % _rows.size())
	elif _nav_pressed(event, "ui_down", "move_down"):
		get_viewport().set_input_as_handled()
		_set_focus((_focus + 1) % _rows.size())
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_activate(String(_rows[_focus].action))


## True when either the ui_* action or (if the project maps it) the matching
## gameplay move_* action was just pressed — menus answer to arrows AND WASD.
func _nav_pressed(event: InputEvent, ui_action: String, move_action: String) -> bool:
	if event.is_action_pressed(ui_action):
		return true
	return InputMap.has_action(move_action) and event.is_action_pressed(move_action)


# ---------------------------------------------------------------- build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_backdrop()
	_build_title()
	_build_buttons()
	_build_footer()

	# Gentle fade-in from black.
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.6)


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = BG_DARK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# Warm hearth-glow rising from below the title — the ember-lit GK mood.
	var glow := TextureRect.new()
	glow.name = "EmberGlow"
	glow.texture = _make_radial_texture(EMBER_GLOW, Color(EMBER_GLOW.r, EMBER_GLOW.g, EMBER_GLOW.b, 0.0), 0.0, 1.0)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(glow)
	# Slow breathing pulse, like firelight.
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.78, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "modulate:a", 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = _make_radial_texture(Color(0.0, 0.0, 0.0, 0.0), VIGNETTE_EDGE, 0.5, 1.0)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(vignette)

	_root.add_child(_make_embers())


func _make_embers() -> CPUParticles2D:
	## A thin drift of ember motes rising off-screen — sells the fire without
	## any art asset (spec forbids deriving new sprite frames; code FX are OK).
	var p := CPUParticles2D.new()
	p.name = "Embers"
	p.position = Vector2(VIEW.x * 0.5, VIEW.y + 8.0)
	p.amount = 26
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(300.0, 6.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 10.0
	p.gravity = Vector2(0.0, -12.0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 30.0
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.66, 0.26, 0.0),
		Color(1.0, 0.62, 0.22, 0.5),
		Color(0.8, 0.28, 0.1, 0.0),
	])
	p.color_ramp = ramp
	return p


func _build_title() -> void:
	var title := Label.new()
	title.name = "Title"
	title.text = "Raven Hollow"
	_style_label(title, 40, GOLD)
	title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, TITLE_TOP)
	title.size = Vector2(VIEW.x, 46.0)
	_root.add_child(title)

	# Thin gold divider that fades out at both ends.
	var divider := TextureRect.new()
	divider.name = "Divider"
	divider.texture = _make_divider_texture()
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2((VIEW.x - 220.0) * 0.5, DIVIDER_TOP)
	divider.size = Vector2(220.0, 2.0)
	_root.add_child(divider)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Kickstarter Demo"
	_style_label(subtitle, 11, PARCHMENT)
	subtitle.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	subtitle.add_theme_constant_override("outline_size", 2)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0.0, SUBTITLE_TOP)
	subtitle.size = Vector2(VIEW.x, 14.0)
	subtitle.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_root.add_child(subtitle)


func _build_buttons() -> void:
	var defs: Array[Dictionary] = [{"action": "new_game", "label": "New Game"}]
	if _save_exists():
		defs.append({"action": "continue", "label": "Continue"})
	defs.append({"action": "quit", "label": "Quit"})

	for i in range(defs.size()):
		var def: Dictionary = defs[i]
		var row: Dictionary = _make_row(String(def.label), String(def.action), i)
		var row_root: Panel = row.root
		row_root.position = Vector2(
			(VIEW.x - BUTTON_SIZE.x) * 0.5,
			BUTTONS_TOP + float(i) * (BUTTON_SIZE.y + BUTTON_GAP)
		)
		_root.add_child(row_root)
		_rows.append(row)


func _make_row(text: String, action: String, index: int) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)

	var panel := Panel.new()
	panel.name = "Btn_" + action
	panel.custom_minimum_size = BUTTON_SIZE
	panel.size = BUTTON_SIZE
	panel.pivot_offset = BUTTON_SIZE * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(_on_row_hover.bind(index))
	panel.gui_input.connect(_on_row_gui_input.bind(index))

	var label := Label.new()
	label.text = text
	_style_label(label, 13, PARCHMENT)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)

	return {"action": action, "root": panel, "style": style, "label": label, "tween": null}


func _build_footer() -> void:
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "Enter — confirm"
	_style_label(_hint_label, 10, GOLD)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0.0, 322.0)
	_hint_label.size = Vector2(VIEW.x, 14.0)
	_root.add_child(_hint_label)
	var blink := create_tween().set_loops()
	blink.tween_property(_hint_label, "modulate:a", 0.25, 0.55).set_delay(0.35)
	blink.tween_property(_hint_label, "modulate:a", 1.0, 0.55)

	# Demo tone-setter, bottom-left, barely there (the quest 5 journal line).
	var flavor := Label.new()
	flavor.name = "Flavor"
	flavor.text = "\"The ground is patient.\""
	_style_label(flavor, 9, PARCHMENT)
	flavor.position = Vector2(10.0, 340.0)
	flavor.size = Vector2(300.0, 12.0)
	flavor.modulate = Color(1.0, 1.0, 1.0, 0.4)
	_root.add_child(flavor)


# ---------------------------------------------------------------- focus

func _on_row_hover(index: int) -> void:
	if not _closing:
		_set_focus(index)


func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if _closing:
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
		style.bg_color = PANEL_BG_FOCUS if focused else PANEL_BG
		var label: Label = row.label
		label.add_theme_color_override("font_color", GOLD_BRIGHT if focused else PARCHMENT)
		var old_tween: Variant = row.tween
		if old_tween is Tween and (old_tween as Tween).is_valid():
			(old_tween as Tween).kill()
		var target: float = FOCUS_SCALE if focused else 1.0
		var tw := create_tween()
		tw.tween_property(row.root, "scale", Vector2(target, target), 0.1)
		row.tween = tw


# ---------------------------------------------------------------- activate

func _activate(action: String) -> void:
	if _closing:
		return
	_closing = true
	menu_choice.emit(action)
	if _music != null:
		var mt := create_tween()
		mt.tween_property(_music, "volume_db", MENU_MUSIC_FADE_DB, FADE_OUT_TIME)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT_TIME)
	if action == "quit":
		# Default behavior when nothing intercepts the signal: leave the game.
		tw.tween_callback(func() -> void: get_tree().quit())
	else:
		tw.tween_callback(queue_free)


# ---------------------------------------------------------------- save probe

func _save_exists() -> bool:
	## SaveSystem is a peer workflow's file — probe a live node first (in case
	## it ships as a node main.gd adds), then the static API on the script,
	## loaded dynamically so this file parses before save_system.gd exists.
	var node: Node = get_tree().get_first_node_in_group("save_system")
	if node != null and node.has_method("has_save"):
		return bool(node.call("has_save"))
	if not ResourceLoader.exists(SAVE_SYSTEM_PATH):
		return false
	var script: GDScript = load(SAVE_SYSTEM_PATH) as GDScript
	if script == null:
		return false
	var info: Dictionary = _method_info(script, "has_save")
	if info.is_empty() or (int(info.get("flags", 0)) & METHOD_FLAG_STATIC) == 0:
		return false
	return bool(script.call("has_save"))


func _method_info(target: Object, method_name: String) -> Dictionary:
	var script_obj := target as Script
	var list: Array = script_obj.get_script_method_list() if script_obj != null else target.get_method_list()
	for m: Variant in list:
		if m is Dictionary and String((m as Dictionary).get("name", "")) == method_name:
			return m
	return {}


# ---------------------------------------------------------------- music

func _start_menu_music() -> void:
	## Quiet title-screen loop, freed with the menu. main.gd starts the real
	## town theme later in _bootstrap_world, so there is never a double play.
	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		return
	var stream: AudioStream = load(MENU_MUSIC_PATH)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.name = "MenuMusic"
	_music.stream = stream
	_music.volume_db = MENU_MUSIC_DB
	add_child(_music)
	_music.play()


# ---------------------------------------------------------------- helpers

func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _make_radial_texture(inner: Color, outer: Color, inner_stop: float, outer_stop: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([inner_stop, outer_stop])
	gradient.colors = PackedColorArray([inner, outer])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.58)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 320
	tex.height = 180
	return tex


func _make_divider_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.55),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 220
	tex.height = 2
	return tex
