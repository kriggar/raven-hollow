class_name DialogueUI
extends CanvasLayer
## Graveyard-Keeper-flavored UI built entirely in code: bottom dialogue box
## with typewriter text, an "[E] Talk" interact prompt, and a fading location
## banner. Registered in group "dialogue_ui" per the interface contract.

signal dialogue_finished
## Emitted once when the player resolves a two-option prompt shown via
## show_choice(); `option` is "a" or "b". npc.gd (quest choices) and main.gd
## (quest-4 world choice) connect this one-shot.
signal choice_made(option: String)

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
var _voice_id: String = ""  # npc id for TTS voice-over of the current dialogue
var _chars_shown: float = 0.0
var _typing: bool = false
var _prompt_wanted: bool = false

## Two-option choice prompt (show_choice). Blocks input like a dialogue and
## keeps is_open true so the player cannot act while a choice is open.
var _choosing: bool = false

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
var _choice_box: PanelContainer
var _choice_speaker: Label
var _choice_prompt: Label
var _choice_options: Array[Label] = []


func _ready() -> void:
	add_to_group("dialogue_ui")
	layer = 10
	_build_dialogue_box()
	_build_prompt()
	_build_banner()
	_build_choice_box()
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
		if not _box.visible and not _choice_box.visible:
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
	# While a two-option choice is open, only the number keys (1/2) resolve it
	# (mouse clicks are handled per-row via gui_input). Dialogue advance is
	# suppressed so a stray [E] cannot skip the decision.
	if _choosing:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var kc: int = (event as InputEventKey).keycode
			if kc == KEY_1 or kc == KEY_KP_1:
				get_viewport().set_input_as_handled()
				_pick_choice("a")
			elif kc == KEY_2 or kc == KEY_KP_2:
				get_viewport().set_input_as_handled()
				_pick_choice("b")
		return
	if event.is_action_pressed("ui_advance_dialogue") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()


func show_dialogue(speaker: String, pages: Array, voice_id: String = "") -> void:
	if pages.is_empty():
		return
	_voice_id = voice_id
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


## Two-option prompt (quests.gd INTEGRATION): parchment prompt over two gold
## option rows. Resolve with keys 1/2 or a mouse click on a row; emits
## choice_made("a"|"b") once and closes itself. Blocks player input like
## show_dialogue (is_open held true across the confirming press via the same
## CLOSE_GUARD_TICKS window). `speaker` may be "" for a world choice.
func show_choice(speaker: String, prompt: String, option_a: String, option_b: String) -> void:
	# A choice supersedes any open dialogue box.
	_typing = false
	_hint_timer.stop()
	_hint_label.visible = false
	_box.visible = false
	_choice_speaker.text = speaker
	_choice_speaker.visible = speaker != ""
	_choice_prompt.text = prompt
	_choice_options[0].text = "[1] " + option_a
	_choice_options[1].text = "[2] " + option_b
	_choosing = true
	_choice_box.visible = true
	_close_ticks = 0
	is_open = true
	_update_prompt()


## Resolve the choice: hide the panel, hold the close guard so the confirming
## press cannot leak to the player's polled interact, then emit. Any follow-up
## show_dialogue from the listener re-opens the box and cancels the guard.
func _pick_choice(option: String) -> void:
	if not _choosing:
		return
	_choosing = false
	_choice_box.visible = false
	_close_ticks = CLOSE_GUARD_TICKS
	set_physics_process(true)
	choice_made.emit(option)


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
	# Voice-over the page (speak() stops any prior line first).
	var vo: Node = get_node_or_null("/root/Voice")
	if vo != null and not _voice_id.is_empty():
		vo.call("speak", _voice_id, str(_pages[_page_index]))


func _finish_typing() -> void:
	_typing = false
	_body_label.visible_characters = -1
	_hint_label.visible = true
	_hint_timer.start()


func _close() -> void:
	_typing = false
	_hint_timer.stop()
	_box.visible = false
	var vo: Node = get_node_or_null("/root/Voice")
	if vo != null:
		vo.call("stop")
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


func _build_choice_box() -> void:
	# Same GK frame as the dialogue box, sitting just above it so a choice reads
	# as a continuation of the conversation.
	_choice_box = PanelContainer.new()
	_choice_box.name = "ChoiceBox"
	_choice_box.visible = false
	_choice_box.anchor_left = 0.5
	_choice_box.anchor_right = 0.5
	_choice_box.anchor_top = 1.0
	_choice_box.anchor_bottom = 1.0
	_choice_box.offset_left = -280.0
	_choice_box.offset_right = 280.0
	_choice_box.offset_top = -196.0
	_choice_box.offset_bottom = -108.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.border_color = BOX_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(10.0)
	_choice_box.add_theme_stylebox_override("panel", sb)
	add_child(_choice_box)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	_choice_box.add_child(vbox)

	_choice_speaker = Label.new()
	_style_label(_choice_speaker, 16, GOLD)
	vbox.add_child(_choice_speaker)

	_choice_prompt = Label.new()
	_style_label(_choice_prompt, 12, PARCHMENT)
	_choice_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_choice_prompt)

	_choice_options.clear()
	for i in 2:
		var opt := Label.new()
		_style_label(opt, 12, GOLD)
		opt.add_theme_color_override("font_outline_color", OUTLINE_DARK)
		opt.add_theme_constant_override("outline_size", 2)
		# Rows are clickable; the parchment prompt/labels above stay pass-through.
		opt.mouse_filter = Control.MOUSE_FILTER_STOP
		var option: String = "a" if i == 0 else "b"
		opt.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.is_pressed() \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_pick_choice(option))
		vbox.add_child(opt)
		_choice_options.append(opt)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
