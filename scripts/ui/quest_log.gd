extends CanvasLayer
## QuestLogUI -- the journal + tracker + offer surfaces for Raven Hollow's
## quest engine (BLUEPRINT_27). Instanced ONCE by the QuestSystem autoload
## (scenes/ui/quest_log.tscn) exactly the way MountSystem instances its stable
## UI. One CanvasLayer hosts three things:
##   * TRACKER   -- always-on, top-right, parchment sheet listing tracked quests
##                  with objective progress. Sits below the minimap zone.
##   * LOG PANEL -- modal journal (L / J): active quests with objectives, reward
##                  preview, track/untrack, turn-in when ready, plus the quests
##                  offerable by nearby givers.
##   * OFFER PANEL -- a small accept / turn-in panel shown when the player greets
##                  a quest giver (QuestSystem key G).
## Styled to the shared gold-bezel kit (panel_brown 9-patch + Alagard + GOLD)
## like bag_ui / mounts_ui / loot_window. Esc or the X closes a modal.

const GOLD := Color(0.85, 0.68, 0.35)
const PARCHMENT := Color(0.87, 0.82, 0.72)
const DIM := Color(0.64, 0.59, 0.50)
const GREEN := Color(0.55, 0.85, 0.45)
const OUTLINE_DARK := Color(0.08, 0.05, 0.03)
const BOX_BG := Color(0.09, 0.07, 0.06, 0.97)
const SLOT_BG := Color(0.055, 0.045, 0.035, 0.95)
const SLOT_BORDER := Color(0.30, 0.22, 0.12)
const SCRIM := Color(0.0, 0.0, 0.0, 0.42)
const TRACK_BG := Color(0.10, 0.08, 0.06, 0.86)

const PANEL_W: float = 340.0
const PANEL_H: float = 320.0
const OFFER_W: float = 320.0
const OFFER_H: float = 300.0
const PAD: float = 12.0
## Tracker sits below the minimap + clock + tutorial-tracker zone (hud.gd runs
## that to ~y150), so the two never overlap.
const TRACK_TOP: float = 168.0
const TRACK_W: float = 208.0
const TRACK_MARGIN: float = 8.0

var is_open: bool = false

var _font: FontFile = preload("res://assets/fonts/alagard.ttf")
var _panel_tex: Texture2D = preload("res://assets/art/ui/panel_brown.png")

var _qs: Node = null
var _actor: Node = null

# tracker
var _track_frame: NinePatchRect
var _track_list: VBoxContainer

# log modal
var _log_scrim: ColorRect
var _log_panel: NinePatchRect
var _log_list: VBoxContainer
var _log_open: bool = false

# offer modal
var _offer_scrim: ColorRect
var _offer_panel: NinePatchRect
var _offer_list: VBoxContainer
var _offer_title: Label
var _offer_npc: String = ""
var _offer_open: bool = false


func _ready() -> void:
	layer = 11
	add_to_group("quest_ui")
	_build_tracker()
	_build_log()
	_build_offer()


# --- public API (called by QuestSystem) -------------------------------------

func present_log(qs: Node, actor: Node) -> void:
	_qs = qs
	_actor = actor
	_close_offer()
	_refresh_log()
	_refresh_tracker()
	_log_scrim.visible = true
	_log_open = true
	_sync_open()


func present_offer(qs: Node, actor: Node, npc_id: String, npc_name: String) -> void:
	_qs = qs
	_actor = actor
	_offer_npc = npc_id
	_offer_title.text = npc_name.to_upper()
	_refresh_offer()
	_offer_scrim.visible = true
	_offer_open = true
	_sync_open()


## Continuous state refresh (tracker always, open panels if visible).
func refresh(qs: Node, actor: Node) -> void:
	_qs = qs
	_actor = actor
	_refresh_tracker()
	if _log_open:
		_refresh_log()
	if _offer_open:
		_refresh_offer()


func close_all() -> void:
	_close_log()
	_close_offer()


# --- tracker (always-on, top-right) -----------------------------------------

func _build_tracker() -> void:
	var frame := NinePatchRect.new()
	frame.texture = _panel_tex
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.offset_left = -(TRACK_MARGIN + TRACK_W)
	frame.offset_right = -TRACK_MARGIN
	frame.offset_top = TRACK_TOP
	frame.offset_bottom = TRACK_TOP + 40.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	add_child(frame)
	_track_frame = frame

	var bg := ColorRect.new()
	bg.color = TRACK_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 10
	list.offset_top = 8
	list.offset_right = -8
	list.offset_bottom = -8
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(list)
	_track_list = list


func _refresh_tracker() -> void:
	if _qs == null or _track_list == null:
		return
	for c: Node in _track_list.get_children():
		c.queue_free()
	var lines: Array = _qs.call("tracker_lines", _actor)
	if lines.is_empty():
		_track_frame.visible = false
		return
	# Header.
	var hdr := _mk_label("QUEST TRACKER", 9, GOLD)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_list.add_child(hdr)
	var rows: int = 1
	for entry_v: Variant in lines:
		var entry: Dictionary = entry_v
		var title: String = str(entry.get("title", ""))
		if bool(entry.get("ready", false)):
			title += "  (ready)"
		var tlbl := _mk_label(title, 10, entry.get("color", PARCHMENT))
		tlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tlbl.custom_minimum_size = Vector2(TRACK_W - 22.0, 0.0)
		_track_list.add_child(tlbl)
		rows += 1
		for step_v: Variant in entry.get("steps", []):
			var step: Dictionary = step_v
			var done: bool = bool(step.get("done", false))
			var mark: String = "  " + ("x " if done else "- ") + str(step.get("text", ""))
			var slbl := _mk_label(mark, 8, GREEN if done else DIM)
			slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			slbl.custom_minimum_size = Vector2(TRACK_W - 22.0, 0.0)
			_track_list.add_child(slbl)
			rows += 1
	var h: float = 16.0 + float(rows) * 13.0
	_track_frame.offset_bottom = TRACK_TOP + clampf(h, 40.0, 320.0)
	_track_frame.visible = true


# --- log modal ---------------------------------------------------------------

func _build_log() -> void:
	_log_scrim = ColorRect.new()
	_log_scrim.color = SCRIM
	_log_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_scrim.visible = false
	add_child(_log_scrim)

	var frame := _mk_frame(PANEL_W, PANEL_H)
	_log_scrim.add_child(frame)
	_log_panel = frame

	var title := _mk_label("QUEST JOURNAL", 16, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(PAD, 8.0)
	title.size = Vector2(PANEL_W - PAD * 2.0, 20.0)
	frame.add_child(title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(PANEL_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(_close_log)
	frame.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 34.0)
	scroll.size = Vector2(PANEL_W - PAD * 2.0, PANEL_H - 46.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_log_list = VBoxContainer.new()
	_log_list.add_theme_constant_override("separation", 4)
	_log_list.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 14.0, 0.0)
	scroll.add_child(_log_list)


func _refresh_log() -> void:
	if _qs == null or _log_list == null:
		return
	for c: Node in _log_list.get_children():
		c.queue_free()
	var row_w: float = PANEL_W - PAD * 2.0 - 16.0

	var active: Array = _qs.call("active_quests", _actor)
	_add_section("ACTIVE  (%d)" % active.size())
	if active.is_empty():
		_add_note("No quests underway. Seek the folk of Raven Hollow -- watch for the gold mark.")
	for qid_v: Variant in active:
		_add_active_row(str(qid_v), row_w)

	var avail: Array = _qs.call("available_quests", _actor)
	if not avail.is_empty():
		_add_section("OFFERED NEARBY  (%d)" % avail.size())
		for qid_v2: Variant in avail:
			_add_available_row(str(qid_v2), row_w)


func _add_active_row(qid: String, row_w: float) -> void:
	var d: Dictionary = _qs.call("quest_def", qid)
	var ready: bool = bool(_qs.call("is_ready", _actor, qid))
	var color: Color = _qs.call("_quest_color", _actor, qid)

	var box := _row_box(row_w)
	var y: float = 4.0
	var title := _mk_label(str(d.get("title", qid)), 12, color)
	title.position = Vector2(6.0, y)
	title.size = Vector2(row_w - 130.0, 16.0)
	box.add_child(title)

	# Track / Untrack toggle.
	var tracked: bool = bool(_qs.call("is_tracked", qid))
	var tbtn := _mk_button("Untrack" if tracked else "Track")
	tbtn.position = Vector2(row_w - 122.0, 3.0)
	tbtn.size = Vector2(56.0, 18.0)
	tbtn.pressed.connect(func() -> void:
		_qs.call("toggle_track", qid)
		_refresh_log())
	box.add_child(tbtn)

	if ready:
		var gbtn := _mk_button("Turn In")
		gbtn.position = Vector2(row_w - 62.0, 3.0)
		gbtn.size = Vector2(56.0, 18.0)
		gbtn.pressed.connect(func() -> void:
			_qs.call("turn_in", _actor, qid)
			_refresh_log())
		box.add_child(gbtn)
	y += 20.0

	for step_v: Variant in _qs.call("objective_lines", _actor, qid):
		var step: Dictionary = step_v
		var done: bool = bool(step.get("done", false))
		var mark: String = ("x  " if done else "-  ") + str(step.get("text", ""))
		var s := _mk_label(mark, 9, GREEN if done else PARCHMENT)
		s.position = Vector2(12.0, y)
		s.size = Vector2(row_w - 18.0, 14.0)
		box.add_child(s)
		y += 14.0

	var rw := _mk_label("Reward:  " + str(_qs.call("rewards_text", qid)), 8, GOLD)
	rw.position = Vector2(12.0, y)
	rw.size = Vector2(row_w - 18.0, 12.0)
	box.add_child(rw)
	y += 15.0

	box.custom_minimum_size = Vector2(row_w, y)
	_log_list.add_child(box)


func _add_available_row(qid: String, row_w: float) -> void:
	var d: Dictionary = _qs.call("quest_def", qid)
	var box := _row_box(row_w)
	var title := _mk_label("!  " + str(d.get("title", qid)), 12, PARCHMENT)
	title.position = Vector2(6.0, 4.0)
	title.size = Vector2(row_w - 80.0, 16.0)
	box.add_child(title)

	var giver := _mk_label("from " + str(d.get("giver_name", d.get("giver", ""))), 8, DIM)
	giver.position = Vector2(12.0, 22.0)
	giver.size = Vector2(row_w - 18.0, 12.0)
	box.add_child(giver)

	var abtn := _mk_button("Accept")
	abtn.position = Vector2(row_w - 62.0, 4.0)
	abtn.size = Vector2(56.0, 18.0)
	abtn.pressed.connect(func() -> void:
		_qs.call("accept", _actor, qid)
		_refresh_log())
	box.add_child(abtn)

	box.custom_minimum_size = Vector2(row_w, 38.0)
	_log_list.add_child(box)


# --- offer modal -------------------------------------------------------------

func _build_offer() -> void:
	_offer_scrim = ColorRect.new()
	_offer_scrim.color = SCRIM
	_offer_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_offer_scrim.visible = false
	add_child(_offer_scrim)

	var frame := _mk_frame(OFFER_W, OFFER_H)
	_offer_scrim.add_child(frame)
	_offer_panel = frame

	_offer_title = _mk_label("", 15, GOLD)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_title.position = Vector2(PAD, 8.0)
	_offer_title.size = Vector2(OFFER_W - PAD * 2.0, 20.0)
	frame.add_child(_offer_title)

	var close_btn := _mk_button("X")
	close_btn.position = Vector2(OFFER_W - PAD - 22.0, 8.0)
	close_btn.size = Vector2(22.0, 18.0)
	close_btn.pressed.connect(_close_offer)
	frame.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAD, 32.0)
	scroll.size = Vector2(OFFER_W - PAD * 2.0, OFFER_H - 44.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	_offer_list = VBoxContainer.new()
	_offer_list.add_theme_constant_override("separation", 6)
	_offer_list.custom_minimum_size = Vector2(OFFER_W - PAD * 2.0 - 14.0, 0.0)
	scroll.add_child(_offer_list)


func _refresh_offer() -> void:
	if _qs == null or _offer_list == null:
		return
	for c: Node in _offer_list.get_children():
		c.queue_free()
	var row_w: float = OFFER_W - PAD * 2.0 - 16.0

	# Ready turn-ins for this NPC.
	var any: bool = false
	for qid_v: Variant in _qs.call("active_quests", _actor):
		var qid: String = str(qid_v)
		if bool(_qs.call("is_ready", _actor, qid)) and str(_qs.call("turn_in_npc", qid)) == _offer_npc:
			_add_offer_row(qid, row_w, true)
			any = true

	# Offers this NPC can give.
	for qid_v2: Variant in _qs.call("available_quests", _actor):
		var qid2: String = str(qid_v2)
		if str(_qs.call("quest_def", qid2).get("giver", "")) == _offer_npc:
			_add_offer_row(qid2, row_w, false)
			any = true

	if not any:
		_add_note("Nothing to discuss just now.")


func _add_offer_row(qid: String, row_w: float, turn_in: bool) -> void:
	var d: Dictionary = _qs.call("quest_def", qid)
	var box := _row_box(row_w)
	var y: float = 5.0

	var title := _mk_label(str(d.get("title", qid)), 13, GOLD if turn_in else PARCHMENT)
	title.position = Vector2(6.0, y)
	title.size = Vector2(row_w - 12.0, 16.0)
	box.add_child(title)
	y += 19.0

	var body_text: String = str(d.get("complete", "")) if turn_in else str(d.get("offer", d.get("summary", "")))
	var body := _mk_label(body_text, 9, PARCHMENT)
	body.position = Vector2(8.0, y)
	body.size = Vector2(row_w - 16.0, 10.0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var lines_est: int = int(ceil(float(body_text.length()) / 46.0)) + 1
	y += float(lines_est) * 11.0 + 4.0

	if not turn_in:
		for step_v: Variant in _qs.call("objective_lines", _actor, qid):
			var s := _mk_label("-  " + str((step_v as Dictionary).get("text", "")), 8, DIM)
			s.position = Vector2(12.0, y)
			s.size = Vector2(row_w - 18.0, 12.0)
			box.add_child(s)
			y += 12.0

	var rw := _mk_label("Reward:  " + str(_qs.call("rewards_text", qid)), 8, GOLD)
	rw.position = Vector2(12.0, y)
	rw.size = Vector2(row_w - 18.0, 12.0)
	box.add_child(rw)
	y += 16.0

	var btn := _mk_button("Turn In" if turn_in else "Accept")
	btn.position = Vector2(6.0, y)
	btn.size = Vector2(72.0, 20.0)
	btn.pressed.connect(func() -> void:
		if turn_in:
			_qs.call("turn_in", _actor, qid)
		else:
			_qs.call("accept", _actor, qid)
		_refresh_offer()
		# Nothing left to say -> close the panel.
		if _offer_empty():
			_close_offer())
	box.add_child(btn)

	if not turn_in:
		var dbtn := _mk_button("Decline")
		dbtn.position = Vector2(84.0, y)
		dbtn.size = Vector2(66.0, 20.0)
		dbtn.pressed.connect(_close_offer)
		box.add_child(dbtn)
	y += 24.0

	box.custom_minimum_size = Vector2(row_w, y)
	_offer_list.add_child(box)


func _offer_empty() -> bool:
	for qid_v: Variant in _qs.call("active_quests", _actor):
		var qid: String = str(qid_v)
		if bool(_qs.call("is_ready", _actor, qid)) and str(_qs.call("turn_in_npc", qid)) == _offer_npc:
			return false
	for qid_v2: Variant in _qs.call("available_quests", _actor):
		if str(_qs.call("quest_def", str(qid_v2)).get("giver", "")) == _offer_npc:
			return false
	return true


# --- close / open bookkeeping ------------------------------------------------

func _close_log() -> void:
	_log_open = false
	if _log_scrim != null:
		_log_scrim.visible = false
	_sync_open()


func _close_offer() -> void:
	_offer_open = false
	if _offer_scrim != null:
		_offer_scrim.visible = false
	_sync_open()


func _sync_open() -> void:
	is_open = _log_open or _offer_open


func _unhandled_input(event: InputEvent) -> void:
	if not (_log_open or _offer_open):
		return
	if event.is_action_pressed("ui_cancel"):
		close_all()
		get_viewport().set_input_as_handled()


# --- little builders ---------------------------------------------------------

func _mk_frame(w: float, h: float) -> NinePatchRect:
	var frame := NinePatchRect.new()
	frame.texture = _panel_tex
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(w, h)
	frame.size = Vector2(w, h)
	frame.position = Vector2(-w * 0.5, -h * 0.5)

	var bg := ColorRect.new()
	bg.color = BOX_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 6
	bg.offset_top = 6
	bg.offset_right = -6
	bg.offset_bottom = -6
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)
	return frame


func _row_box(row_w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(row_w, 30.0)
	var bg := ColorRect.new()
	bg.color = SLOT_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	return c


func _add_section(text: String) -> void:
	var l := _mk_label(text, 11, PARCHMENT)
	l.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 16.0, 16.0)
	_log_list.add_child(l)


func _add_note(text: String) -> void:
	var l := _mk_label(text, 8, DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - PAD * 2.0 - 16.0, 24.0)
	if _offer_open and not _log_open:
		l.custom_minimum_size = Vector2(OFFER_W - PAD * 2.0 - 16.0, 24.0)
		_offer_list.add_child(l)
	else:
		_log_list.add_child(l)


func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _mk_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_color_hover", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_color_disabled", DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SLOT_BG
	sb.border_color = SLOT_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	return b
