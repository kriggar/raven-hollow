class_name DialogueUI
extends CanvasLayer
## Graveyard-Keeper-flavored UI built entirely in code: bottom dialogue box
## with typewriter text, an "[E] Talk" interact prompt, and a fading location
## banner. Registered in group "dialogue_ui" per the interface contract.

signal dialogue_finished

const TYPE_SPEED: float = 40.0
const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.96)
const BOX_BORDER := Color(0.45, 0.33, 0.18)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)

var is_open: bool = false

## Physics ticks is_open stays true after closing. The player polls
## Input.is_action_just_pressed("interact") in _physics_process, and the
## just-pressed window of the E press that closed the box is the NEXT physics
## tick (set_input_as_handled() does not affect the polled Input singleton).
## Holding is_open for two ticks guarantees that window passes before the
## player is allowed to interact again, regardless of node processing order.
const CLOSE_GUARD_TICKS: int = 2
var _close_ticks: int = 0

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _pages: Array = []
var _page_index: int = 0
var _chars_shown: float = 0.0
var _typing: bool = false
var _prompt_wanted: bool = false

var _box: PanelContainer
var _speaker_label: Label
var _body_label: RichTextLabel
var _hint_label: Label
var _prompt_label: Label
var _banner_root: VBoxContainer
var _banner_title: Label
var _banner_subtitle: Label
var _hint_timer: Timer
var _banner_tween: Tween


func _ready() -> void:
	add_to_group("dialogue_ui")
	layer = 10
	_build_dialogue_box()
	_build_prompt()
	_build_banner()
	_hint_timer = Timer.new()
	_hint_timer.wait_time = 0.45
	_hint_timer.one_shot = false
	_hint_timer.timeout.connect(_on_hint_blink)
	add_child(_hint_timer)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _close_ticks <= 0:
		set_physics_process(false)
		return
	_close_ticks -= 1
	if _close_ticks == 0:
		set_physics_process(false)
		if not _box.visible:
			is_open = false
			_update_prompt()


func _process(delta: float) -> void:
	if not _typing:
		return
	_chars_shown += TYPE_SPEED * delta
	var total: int = _body_label.get_total_character_count()
	if int(_chars_shown) >= total:
		_finish_typing()
	else:
		_body_label.visible_characters = int(_chars_shown)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_advance_dialogue") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()


func show_dialogue(speaker: String, pages: Array) -> void:
	if pages.is_empty():
		return
	_pages = pages.duplicate()
	_page_index = 0
	_speaker_label.text = speaker
	_close_ticks = 0
	is_open = true
	_box.visible = true
	_update_prompt()
	_start_page()


func show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_banner_root.visible = true
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_root, "modulate:a", 1.0, 0.6)
	_banner_tween.tween_interval(2.5)
	_banner_tween.tween_property(_banner_root, "modulate:a", 0.0, 1.2)
	_banner_tween.tween_callback(func() -> void: _banner_root.visible = false)


func set_prompt_visible(v: bool) -> void:
	_prompt_wanted = v
	_update_prompt()


func _advance() -> void:
	if _typing:
		_finish_typing()
		return
	_page_index += 1
	if _page_index >= _pages.size():
		_close()
	else:
		_start_page()


func _start_page() -> void:
	_body_label.text = str(_pages[_page_index])
	_body_label.visible_characters = 0
	_chars_shown = 0.0
	_typing = true
	_hint_label.visible = false
	_hint_timer.stop()


func _finish_typing() -> void:
	_typing = false
	_body_label.visible_characters = -1
	_hint_label.visible = true
	_hint_timer.start()


func _close() -> void:
	_typing = false
	_hint_timer.stop()
	_box.visible = false
	# Keep is_open true across the closing press's just-pressed physics window
	# so the player's polled interact cannot instantly re-open the dialogue.
	_close_ticks = CLOSE_GUARD_TICKS
	set_physics_process(true)
	dialogue_finished.emit()


func _on_hint_blink() -> void:
	_hint_label.visible = not _hint_label.visible


func _update_prompt() -> void:
	_prompt_label.visible = _prompt_wanted and not is_open


func _build_dialogue_box() -> void:
	_box = PanelContainer.new()
	_box.name = "DialogueBox"
	_box.visible = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -280.0
	_box.offset_right = 280.0
	_box.offset_top = -100.0
	_box.offset_bottom = -8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(10.0)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	_box.add_child(vbox)

	_speaker_label = Label.new()
	_style_label(_speaker_label, 16, GOLD)
	vbox.add_child(_speaker_label)

	_body_label = RichTextLabel.new()
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.bbcode_enabled = false
	_body_label.scroll_active = false
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_override("normal_font", _font)
	_body_label.add_theme_font_size_override("normal_font_size", 12)
	_body_label.add_theme_color_override("default_color", PARCHMENT)
	vbox.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.text = "..."
	_style_label(_hint_label, 12, GOLD)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.visible = false
	_box.add_child(_hint_label)


func _build_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "InteractPrompt"
	_prompt_label.text = "[E] Talk"
	_style_label(_prompt_label, 12, GOLD)
	_prompt_label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_prompt_label.add_theme_constant_override("outline_size", 3)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_top = -30.0
	_prompt_label.offset_bottom = -14.0
	_prompt_label.visible = false
	add_child(_prompt_label)


func _build_banner() -> void:
	_banner_root = VBoxContainer.new()
	_banner_root.name = "LocationBanner"
	_banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_root.anchor_left = 0.0
	_banner_root.anchor_right = 1.0
	_banner_root.anchor_top = 0.0
	_banner_root.anchor_bottom = 0.0
	_banner_root.offset_top = 26.0
	_banner_root.offset_bottom = 96.0
	_banner_root.add_theme_constant_override("separation", 2)
	_banner_root.visible = false
	add_child(_banner_root)

	_banner_title = Label.new()
	_style_label(_banner_title, 24, GOLD)
	_banner_title.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_banner_title.add_theme_constant_override("outline_size", 4)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_root.add_child(_banner_title)

	_banner_subtitle = Label.new()
	_style_label(_banner_subtitle, 12, PARCHMENT)
	_banner_subtitle.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	_banner_subtitle.add_theme_constant_override("outline_size", 2)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_root.add_child(_banner_subtitle)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
