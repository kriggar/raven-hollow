extends CanvasLayer
## PvPUI -- the Accord Roll / arena panel (design/PVP_RANKS_TITLES.md 7 + 10.4).
## Instanced by the PvPSystem autoload (scenes/ui/pvp.tscn). Shows the player's
## standing (active-title name, rank, rating, RP), a progress bar to the next rung,
## the 14-rung Accord Roll ladder with the current rank lit, and an "Enter the
## Reckoning Floor" button that runs a best-of-3 and narrates the result. Styled to
## the shared gold-bezel kit (panel_brown 9-patch + Alagard + GOLD) like mounts_ui.
## Esc or the X closes. present() takes a side ("center"|"left"|"right") so the
## boot screenshot can sit it beside the title picker.

const GOLD := Color(0.85, 0.68, 0.35)
const GOLD_BRIGHT := Color(1.0, 0.92, 0.7)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.98)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const ROW_CUR := Color(0.16, 0.12, 0.05, 0.98)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const TRACK := Color(0.04, 0.03, 0.02, 1.0)
const FILL := Color(0.80, 0.30, 0.20, 1.0)
const WIN_C := Color(0.55, 0.85, 0.45)
const LOSE_C := Color(0.88, 0.42, 0.36)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)

const PANEL_W: float = 300.0
const PANEL_H: float = 330.0
const PAD: float = 12.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _pvp: Node = null
var _actor: Node = null
var _scrim: ColorRect
var _panel: Control
var _list: VBoxContainer
var _ident: Label
var _stat: Label
var _bar_fill: ColorRect
var _bar_lbl: Label
var _result: Label


func _ready() -> void:
	layer = 12
	add_to_group("pvp_ui")
	_build()
	_hide()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	var frame := NinePatchRect.new()
	frame.texture = _panel_tex
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	frame.size = Vector2(PANEL_W, PANEL_H)
	add_child(frame)
	_panel = frame

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	var title := _mk_label("THE ACCORD ROLL", 15, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(PAD, 8.0)
	title.size = Vector2(PANEL_W - PAD * 2.0, 18.0)
	frame.add_child(title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(close)
	frame.add_child(close_btn)

	_ident = _mk_label("", 11, GOLD_BRIGHT)
	_ident.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ident.position = Vector2(PAD, 28.0)
	_ident.size = Vector2(PANEL_W - PAD * 2.0, 15.0)
	frame.add_child(_ident)

	_stat = _mk_label("", 9, PARCHMENT)
	_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat.position = Vector2(PAD, 44.0)
	_stat.size = Vector2(PANEL_W - PAD * 2.0, 12.0)
	frame.add_child(_stat)

	# Progress-to-next bar.
	var track := ColorRect.new()
	track.color = TRACK
	track.position = Vector2(PAD, 60.0)
	track.size = Vector2(PANEL_W - PAD * 2.0, 10.0)
	frame.add_child(track)
	_bar_fill = ColorRect.new()
	_bar_fill.color = FILL
	_bar_fill.position = Vector2(0, 0)
	_bar_fill.size = Vector2(0, 10.0)
	track.add_child(_bar_fill)
	_bar_lbl = _mk_label("", 8, PARCHMENT)
	_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(_bar_lbl)

	# The ladder.
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 76.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 76.0 - 52.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 12.0, 0.0)
	scroll.add_child(_list)

	# Enter button + result line.
	var enter := _mk_button("Enter the Reckoning Floor")
	enter.position = Vector2(PAD, PANEL_H - 48.0)
	enter.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	enter.add_theme_font_size_override("font_size", 11)
	enter.pressed.connect(_on_enter)
	frame.add_child(enter)

	_result = _mk_label("A drained floor, first blood thrice, filed and done.", 8, DIM)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.position = Vector2(PAD, PANEL_H - 24.0)
	_result.size = Vector2(PANEL_W - PAD * 2.0, 14.0)
	frame.add_child(_result)


func present(pvp: Node, actor: Node, side: String = "center") -> void:
	_pvp = pvp
	_actor = actor
	_place(side)
	_scrim.visible = side == "center"
	_refresh()
	_show()


func _place(side: String) -> void:
	var y: float = (360.0 - PANEL_H) * 0.5
	match side:
		"left":
			_panel.position = Vector2(8.0, y)
		"right":
			_panel.position = Vector2(640.0 - 8.0 - PANEL_W, y)
		_:
			_panel.position = Vector2((640.0 - PANEL_W) * 0.5, y)


func _refresh() -> void:
	if _pvp == null or _actor == null:
		return
	var rank: int = int(_pvp.call("get_rank", _actor))
	var rp: int = int(_pvp.call("get_points", _actor))
	var rating: float = float(_pvp.call("get_rating", _actor))
	var wins: int = int(_pvp.call("wins", _actor))
	var losses: int = int(_pvp.call("losses", _actor))
	_ident.text = _display_name()
	_stat.text = "Rank %d  %s" % [rank, str(_pvp.call("rank_name", rank))]
	var prog: Dictionary = _pvp.call("rank_progress", _actor)
	var track_w: float = PANEL_W - PAD * 2.0
	if bool(prog.get("is_max", false)):
		_bar_fill.size.x = track_w
		_bar_lbl.text = "Rating %d   RP %d   %d-%d   (max rank)" % [int(rating), rp, wins, losses]
	else:
		_bar_fill.size.x = track_w * clampf(float(prog.get("frac", 0.0)), 0.0, 1.0)
		_bar_lbl.text = "Rating %d   RP %d   %d-%d   next: %d RP" % [
			int(rating), rp, wins, losses, int(prog.get("next_req", 0))]
	_build_ladder(rank)


func _build_ladder(cur_rank: int) -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var ranks: Array = _pvp.call("all_ranks")
	for r_v: Variant in ranks:
		var r: Dictionary = r_v
		_add_rank_row(r, int(r.get("n", 0)) == cur_rank, int(r.get("n", 0)) <= cur_rank)


func _add_rank_row(r: Dictionary, is_cur: bool, earned: bool) -> void:
	var n: int = int(r.get("n", 0))
	var row := Control.new()
	var rw: float = PANEL_W - PAD * 2.0 - 14.0
	row.custom_minimum_size = Vector2(rw, 26.0)
	var box := ColorRect.new()
	box.color = ROW_CUR if is_cur else SLOT_BG
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)

	var name_col: Color = GOLD_BRIGHT if is_cur else (PARCHMENT if earned else DIM)
	var mark: String = "> " if is_cur else "  "
	var nm := _mk_label("%s%d  %s" % [mark, n, str(r.get("name", "Rank"))], 10, name_col)
	nm.position = Vector2(4.0, 2.0)
	nm.size = Vector2(rw - 8.0, 13.0)
	row.add_child(nm)

	var reward := _mk_label(str(r.get("reward", "")), 8, DIM if not is_cur else PARCHMENT)
	reward.position = Vector2(10.0, 14.0)
	reward.size = Vector2(rw - 60.0, 11.0)
	row.add_child(reward)

	var rp_lbl := _mk_label("%d RP" % int(r.get("rp_required", 0)), 8, GOLD if earned else DIM)
	rp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rp_lbl.position = Vector2(rw - 54.0, 14.0)
	rp_lbl.size = Vector2(50.0, 11.0)
	row.add_child(rp_lbl)

	_list.add_child(row)


func _on_enter() -> void:
	if _pvp == null or _actor == null:
		return
	var m: Dictionary = _pvp.call("enter_arena", _actor, "free")
	if not bool(m.get("ok", false)):
		_result.text = "The Floor is closed to you right now."
		return
	var won: bool = bool(m.get("won", false))
	var verb: String = "WON" if won else "LOST"
	var flaw: String = " (flawless!)" if bool(m.get("flawless", false)) else ""
	_result.text = "%s vs %s  rounds %s  dRating %+d  +%d RP%s" % [
		verb, str(m.get("opp_name", "?")), str(m.get("rounds", [])),
		int(m.get("rating_delta", 0.0)), int(m.get("rp_gain", 0)), flaw]
	_result.add_theme_color_override("font_color", WIN_C if won else LOSE_C)
	_refresh()


func _display_name() -> String:
	var base: String = _base_name()
	var ts: Node = get_node_or_null("/root/TitleSystem")
	if ts != null and ts.has_method("display_name"):
		return str(ts.call("display_name", _actor, base))
	return base


func _base_name() -> String:
	for prop: String in ["char_name", "display_name", "player_name"]:
		if _has_prop(_actor, prop):
			var v: Variant = _actor.get(prop)
			if v is String and str(v) != "":
				return str(v)
	var cd: Variant = _actor.get("class_def") if _actor != null else null
	if cd is Dictionary:
		return str((cd as Dictionary).get("name", "Wanderer"))
	return "Wanderer"


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mk_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", GOLD_BRIGHT)
	b.add_theme_color_override("font_color_disabled", DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	return b


func close() -> void:
	_hide()


func _show() -> void:
	is_open = true
	visible = true


func _hide() -> void:
	is_open = false
	visible = false
	if _scrim != null:
		_scrim.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
