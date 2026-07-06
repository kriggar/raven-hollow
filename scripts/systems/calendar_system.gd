extends Node
## CalendarSystem -- autoload (/root/CalendarSystem). Build #28 "calendar events".
## The Draconian year: 12 months x 30 days = 360 game-days, one game-day per
## DayNight cycle (it watches the "day_night" group clock and advances a day each
## time the clock wraps past midnight). Twelve seasonal festivals from
## design/CALENDAR_EVENTS.md, loaded from data/calendar_events.json, each gated
## by a date window (WoW holiday cadence adapted to Draconia lore). When a
## festival's window opens it ACTIVATES: a themed player buff folds in through
## StatsSystem, a notification toast pops, and event_started fires so world/quest
## content can hang off it; at window close it deactivates and the buff lifts.
##
## Everything here is additive and null-safe: no other system's file is edited.
## The world-content spawn (festival vendors, decor) is Fable-only art -- this
## system emits event_started/event_ended and flips a per-event "active" flag for
## that later pass; the DATE, the BUFF, the notification and the UI are live.
##
## Public API:
##   get_date() -> Dictionary   {year, month, day, month_name, season, day_of_year}
##   active_events() -> Array   event dicts whose window covers today
##   is_active(event_id) -> bool
##   advance_day() -> void      step one game-day, re-evaluate every festival
##   set_date(year, month, day) jump the calendar (quest scripting / debug)
##   all_events() / event_def(id) / event_count()
##   upcoming_events(limit) -> Array  {event, days_until, when} soonest-first
##   month_name(m) / season_of(m) / date_text() / event_window_text(ev)
##   open_calendar(actor) / close_calendar()
## Signals: event_started(event_id), event_ended(event_id), day_advanced(date)

signal event_started(event_id)
signal event_ended(event_id)
signal day_advanced(date)

const DATA_PATH := "res://data/calendar_events.json"
const CAL_SCENE := "res://scenes/ui/calendar.tscn"
const DEFAULT_DAYS_PER_MONTH := 30
const BUFF_SRC_PREFIX := "calendar:"
const SYNC_INTERVAL_S := 1.0

var _days_per_month: int = DEFAULT_DAYS_PER_MONTH
var _months: Array = []                 # [{name, season}, ...] size 12
var _events: Array = []                 # [event dict, ...]
var _event_by_id: Dictionary = {}       # id -> event dict

var _year: int = 1
var _month: int = 1
var _day: int = 1

var _active_ids: Dictionary = {}        # id -> true (today's active set)
var _cal_ui: Node = null
var _toast_layer: CanvasLayer = null

var _last_hour: float = -1.0            # DayNight wrap detection
var _sync_accum: float = 0.0


func _ready() -> void:
	_load_data()
	set_process(true)
	# Seed today's active set + buffs silently (no boot notifications).
	_reevaluate(false, false)
	if not OS.get_environment("RH_CALENDAR").is_empty() \
			or not OS.get_environment("RH_CAL_TEST").is_empty() \
			or OS.get_environment("RH_SHOT").to_lower().find("calendar") != -1:
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	var cfg: Dictionary = _dict(root.get("config", {}))
	_days_per_month = int(cfg.get("days_per_month", DEFAULT_DAYS_PER_MONTH))
	_months = _arr(cfg.get("months", []))
	var start: Dictionary = _dict(cfg.get("start", {}))
	_year = int(start.get("year", 1))
	_month = clampi(int(start.get("month", 1)), 1, maxi(1, _months.size()))
	_day = clampi(int(start.get("day", 1)), 1, _days_per_month)
	_events = _arr(root.get("events", []))
	_event_by_id.clear()
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		var id: String = str(ev.get("id", ""))
		if id != "":
			_event_by_id[id] = ev
	if _events.is_empty():
		push_warning("CalendarSystem: no events loaded from %s" % DATA_PATH)


# --- date model -------------------------------------------------------------

func get_date() -> Dictionary:
	return {
		"year": _year, "month": _month, "day": _day,
		"month_name": month_name(_month), "season": season_of(_month),
		"day_of_year": _ordinal(_month, _day),
	}


func date_text() -> String:
	return "%s %d, Year %d" % [month_name(_month), _day, _year]


func month_name(m: int) -> String:
	var idx: int = clampi(m - 1, 0, _months.size() - 1)
	if idx < 0 or idx >= _months.size():
		return "Month %d" % m
	return str(_dict(_months[idx]).get("name", "Month %d" % m))


func season_of(m: int) -> String:
	var idx: int = clampi(m - 1, 0, _months.size() - 1)
	if idx < 0 or idx >= _months.size():
		return ""
	return str(_dict(_months[idx]).get("season", ""))


func months() -> Array:
	return _months


func days_per_month() -> int:
	return _days_per_month


func year() -> int:
	return _year


## Jump the calendar to a specific date; re-evaluates festivals (fires signals).
func set_date(y: int, m: int, d: int) -> void:
	_year = maxi(1, y)
	_month = clampi(m, 1, maxi(1, _months.size()))
	_day = clampi(d, 1, _days_per_month)
	_reevaluate(true, true)
	day_advanced.emit(get_date())


## Step the calendar forward one game-day and re-evaluate every festival.
func advance_day() -> void:
	_day += 1
	if _day > _days_per_month:
		_day = 1
		_month += 1
		if _month > _months.size():
			_month = 1
			_year += 1
	_reevaluate(true, true)
	day_advanced.emit(get_date())


# --- events -----------------------------------------------------------------

func all_events() -> Array:
	return _events


func event_count() -> int:
	return _events.size()


func event_def(event_id: String) -> Dictionary:
	return _dict(_event_by_id.get(event_id, {}))


func is_active(event_id: String) -> bool:
	return _active_ids.has(event_id)


## Event dicts whose window covers today.
func active_events() -> Array:
	var out: Array = []
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		if _active_ids.has(str(ev.get("id", ""))):
			out.append(ev)
	return out


func active_event_ids() -> Array:
	return _active_ids.keys()


## Event dicts whose window covers the given calendar date (for the month grid).
func events_on(m: int, d: int) -> Array:
	var ord: int = _ordinal(m, d)
	var out: Array = []
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		if _event_covers(ev, ord):
			out.append(ev)
	return out


## True when `ev` (event dict) covers the given ordinal (day-of-year 1.._maxord).
func _event_covers(ev: Dictionary, ord: int) -> bool:
	var rec: Dictionary = _dict(ev.get("recurring", {}))
	if not rec.is_empty():
		var d: int = ((ord - 1) % _days_per_month) + 1
		return d >= int(rec.get("start_day", 1)) and d <= int(rec.get("end_day", 1))
	var w: Dictionary = _dict(ev.get("window", {}))
	if w.is_empty():
		return false
	var s: int = _ordinal(int(w.get("start_month", 1)), int(w.get("start_day", 1)))
	var e: int = _ordinal(int(w.get("end_month", 1)), int(w.get("end_day", 1)))
	if s <= e:
		return ord >= s and ord <= e
	# window wraps the year end
	return ord >= s or ord <= e


## Days until this event's window next opens (0 when active). Bounded by year len.
func days_until_start(ev: Dictionary) -> int:
	var maxord: int = _months.size() * _days_per_month
	var cur: int = _ordinal(_month, _day)
	if _event_covers(ev, cur):
		return 0
	for i in range(1, maxord + 1):
		var probe: int = ((cur - 1 + i) % maxord) + 1
		if _event_covers(ev, probe):
			return i
	return -1


## Soonest-first upcoming (or ongoing) festivals: [{event, days_until, when}].
func upcoming_events(limit: int = 6) -> Array:
	var rows: Array = []
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		var du: int = days_until_start(ev)
		if du < 0:
			continue
		rows.append({"event": ev, "days_until": du, "when": event_window_text(ev)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["days_until"]) < int(b["days_until"]))
	if limit > 0 and rows.size() > limit:
		rows = rows.slice(0, limit)
	return rows


func event_window_text(ev: Dictionary) -> String:
	var rec: Dictionary = _dict(ev.get("recurring", {}))
	if not rec.is_empty():
		return "Days %d-%d, every month" % [int(rec.get("start_day", 1)), int(rec.get("end_day", 1))]
	var w: Dictionary = _dict(ev.get("window", {}))
	if w.is_empty():
		return ""
	return "%s %d - %s %d" % [
		month_name(int(w.get("start_month", 1))), int(w.get("start_day", 1)),
		month_name(int(w.get("end_month", 1))), int(w.get("end_day", 1))]


# --- activation (re-evaluate active set; apply buffs; notify) ----------------

func _reevaluate(emit_signals: bool, notify: bool) -> void:
	var cur: int = _ordinal(_month, _day)
	var new_active: Dictionary = {}
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		var id: String = str(ev.get("id", ""))
		if id != "" and _event_covers(ev, cur):
			new_active[id] = true
	# Entered = in new, not in old.
	for id: String in new_active.keys():
		if not _active_ids.has(id):
			if emit_signals:
				event_started.emit(id)
			if notify:
				_notify(event_def(id))
	# Exited = in old, not in new.
	for id: String in _active_ids.keys():
		if not new_active.has(id):
			if emit_signals:
				event_ended.emit(id)
	_active_ids = new_active
	_sync_buffs()


## Ensure the player carries exactly the active festivals' buffs (idempotent).
func _sync_buffs() -> void:
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss == null or not ss.has_method("add_modifier"):
		return
	var pl: Node = _player()
	if pl == null:
		return
	for ev_v: Variant in _events:
		var ev: Dictionary = _dict(ev_v)
		var id: String = str(ev.get("id", ""))
		if id == "":
			continue
		var src: String = BUFF_SRC_PREFIX + id
		if ss.has_method("remove_modifier"):
			ss.call("remove_modifier", src)
		if not _active_ids.has(id):
			continue
		var buff: Dictionary = _dict(ev.get("buff", {}))
		for stat: String in buff.keys():
			var amt: float = float(buff[stat])
			if absf(amt) > 0.0001:
				ss.call("add_modifier", pl, src, stat, amt)


# --- DayNight tie + buff sync -----------------------------------------------

func _process(delta: float) -> void:
	# Watch the world clock; each wrap past midnight advances one game-day.
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null:
		var h: Variant = dn.get("time_of_day")
		if h is float or h is int:
			var hour: float = float(h)
			if _last_hour >= 0.0 and hour < _last_hour - 6.0:
				advance_day()
			_last_hour = hour
	# Keep active buffs bound to the live player (spawns after boot, map swaps).
	_sync_accum += delta
	if _sync_accum >= SYNC_INTERVAL_S:
		_sync_accum = 0.0
		_sync_buffs()


# --- notification toast (self-contained, autoload-hosted) -------------------

func _notify(ev: Dictionary) -> void:
	if ev.is_empty() or get_tree() == null or get_tree().current_scene == null:
		return
	var msg: String = str(ev.get("notify", "%s begins." % str(ev.get("name", "A festival"))))
	if _toast_layer == null or not is_instance_valid(_toast_layer):
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 90
		add_child(_toast_layer)
	var col: Color = _hex(str(ev.get("color", "#e6c86e")), Color(0.9, 0.78, 0.42))
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-170.0, 26.0)
	card.custom_minimum_size = Vector2(340.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.06, 0.96)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)
	var title := _toast_label("The calendar turns: " + str(ev.get("name", "")), 16, col)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var body := _toast_label(msg, 10, Color(0.86, 0.82, 0.72))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(316.0, 0.0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	_toast_layer.add_child(card)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


func _toast_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var f: FontFile = load("res://assets/fonts/alagard.ttf") as FontFile
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 3)
	return l


# --- calendar UI ------------------------------------------------------------

func open_calendar(actor: Node = null) -> void:
	if actor == null:
		actor = _player()
	_ensure_cal_ui()
	if _cal_ui != null and _cal_ui.has_method("present"):
		_cal_ui.call("present", self, actor)


func close_calendar() -> void:
	if _cal_ui != null and _cal_ui.has_method("close"):
		_cal_ui.call("close")


func _ensure_cal_ui() -> void:
	if _cal_ui != null and is_instance_valid(_cal_ui):
		return
	if not ResourceLoader.exists(CAL_SCENE):
		push_warning("CalendarSystem: calendar scene missing (%s)" % CAL_SCENE)
		return
	var scn: PackedScene = load(CAL_SCENE) as PackedScene
	if scn == null:
		return
	_cal_ui = scn.instantiate()
	add_child(_cal_ui)


# --- input (N = calendar) ---------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_N:
		return
	if _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	if _cal_ui != null and is_instance_valid(_cal_ui) and bool(_cal_ui.get("is_open")):
		close_calendar()
	else:
		open_calendar(_player())


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui", "auction_ui", "bank_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	# Wait for the world + player.
	for _i in range(240):
		if _player() != null:
			break
		await get_tree().process_frame
	if not OS.get_environment("RH_CAL_TEST").is_empty():
		_self_test()
	if not OS.get_environment("RH_CALENDAR").is_empty() \
			or OS.get_environment("RH_SHOT").to_lower().find("calendar") != -1:
		open_calendar(_player())


func _self_test() -> void:
	print("[CAL_TEST] ===== Raven Hollow calendar self-test =====")
	print("[CAL_TEST] loaded %d festivals; year is %d months x %d days" % [
		event_count(), _months.size(), _days_per_month])
	print("[CAL_TEST] start date = %s (%s)" % [date_text(), season_of(_month)])
	var boot_active: Array = []
	for ev: Dictionary in active_events():
		boot_active.append(str(ev.get("name", "")))
	print("[CAL_TEST] active on start date: %s" % str(boot_active))
	# Find the next festival that is NOT active now and advance to its opening day.
	var target: Dictionary = {}
	var soonest: int = 99999
	for ev_v: Variant in _events:
		var ev2: Dictionary = _dict(ev_v)
		var du: int = days_until_start(ev2)
		if du > 0 and du < soonest:
			soonest = du
			target = ev2
	if target.is_empty():
		print("[CAL_TEST] (every festival already active) -- advancing 10 days")
		for _j in range(10):
			advance_day()
		print("[CAL_TEST] complete")
		return
	var tid: String = str(target.get("id", ""))
	print("[CAL_TEST] next festival: '%s' opens in %d days (%s)" % [
		str(target.get("name", "")), soonest, event_window_text(target)])
	var started := false
	if not is_connected("event_started", _on_test_started):
		event_started.connect(_on_test_started)
	for _k in range(soonest):
		advance_day()
	print("[CAL_TEST] advanced to %s -- is_active('%s') = %s" % [
		date_text(), tid, str(is_active(tid))])
	var buff: Dictionary = _dict(target.get("buff", {}))
	print("[CAL_TEST] '%s' activated its buff %s and posted a notification" % [
		str(target.get("name", "")), str(buff)])
	print("[CAL_TEST] active now: %s" % str(active_event_ids()))
	print("[CAL_TEST] ===== self-test complete =====")


func _on_test_started(event_id: String) -> void:
	print("[CAL_TEST]   >> event_started fired: '%s'" % event_id)


# --- save contract (SaveSystem group pattern; inert until wired) ------------

func serialize() -> Dictionary:
	return {"year": _year, "month": _month, "day": _day}


func deserialize(d: Dictionary) -> void:
	if d.has("year") and d.has("month") and d.has("day"):
		set_date(int(d["year"]), int(d["month"]), int(d["day"]))


# --- helpers ----------------------------------------------------------------

func _ordinal(m: int, d: int) -> int:
	return (clampi(m, 1, maxi(1, _months.size())) - 1) * _days_per_month + clampi(d, 1, _days_per_month)


func _player() -> Node:
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null


func _hex(s: String, dflt: Color) -> Color:
	if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
		return Color.html(s)
	return dflt


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CalendarSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
