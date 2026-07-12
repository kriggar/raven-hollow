extends Node
## NarrativeSystem -- autoload (/root/NarrativeSystem). BACKLOG #49
## "Narrative Voice / lore delivery" (design/NARRATIVE_VOICE.md).
##
## The world's memory made deliverable. Loads data/narrative.json and hands the
## rest of the game three voices from design/NARRATIVE_VOICE.md: R1 (the world's
## chronicle -- lore + narrator + inscriptions), R2 (hearth-plain / ledger-noir
## ambient NPC barks), and R3 (the stone, quarantined to villain inscriptions).
##
## Everything is additive and null-safe: no other system's file is touched, and
## nothing here needs a live world or player. All UI is built IN CODE as a
## self-instanced CanvasLayer (a bottom parchment toast strip, and a chronicle
## journal panel), guarded so a headless boot with no scene never crashes.
##
## Public API:
##   deliver_lore(id) -> bool          unlock a lore entry ONCE: append to the
##                                     journal (dedup) + flash a parchment toast.
##   is_unlocked(id) -> bool ; journal_ids() -> Array ; journal_count() -> int
##   lore_entry(id) -> Dictionary ; all_lore() -> Dictionary
##   bark(key) -> String               an ambient NPC line for a zone or faction,
##                                     rotated by call index (deterministic, no RNG).
##   narrate(beat, key := "") -> String  narrator line on a beat (enter_zone,
##                                     boss_intro, quest_turnin, first_death) -> toast.
##   open_journal() / close_journal() / toggle_journal()   the chronicle panel.
## Signals: lore_unlocked(id, entry), bark_spoken(key, line), journal_opened().

signal lore_unlocked(id, entry)
signal bark_spoken(key, line)
signal journal_opened()

const DATA_PATH := "res://data/narrative.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const TOAST_SECONDS := 4.5
const TOAST_FADE := 0.8

# --- parchment palette (matches the gold-bezel fantasy UI kit) ----------------
const COL_PARCH_BG := Color(0.14, 0.11, 0.08, 0.94)
const COL_BEZEL := Color(0.66, 0.52, 0.28, 1.0)
const COL_INK := Color(0.91, 0.85, 0.68, 1.0)
const COL_INK_DIM := Color(0.74, 0.68, 0.54, 1.0)
const COL_R3 := Color(0.72, 0.78, 0.80, 1.0)   # the stone reads cold

var _lore: Dictionary = {}            # id -> entry dict
var _barks: Dictionary = {}           # {"zone": {...}, "faction": {...}}
var _narrator: Dictionary = {}        # beat -> (Dictionary keyed, or Array)

var _journal: Array = []              # unlocked lore ids, in unlock order
var _unlocked: Dictionary = {}        # id -> true (dedup / unlock-once)
var _bark_index: Dictionary = {}      # key -> int (rotation cursor)
var _narr_index: Dictionary = {}      # beat -> int (rotation cursor for Array beats)

var _font: FontFile = null

# self-instanced UI (all built in code, lazy, guarded)
var _toast_layer: CanvasLayer = null
var _toast_root: Control = null
var _toast_label: Label = null
var _toast_tween: Tween = null

var _panel: CanvasLayer = null
var _panel_sub: Label = null
var _panel_list: VBoxContainer = null
var _journal_open: bool = false


func _ready() -> void:
	_load_font()
	_load_data()
	# Env hooks fire once the tree is ready. Self-test needs no world/player.
	if not OS.get_environment("RH_NARR_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_NARR").is_empty():
		call_deferred("_run_env_demo")


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_lore = _dict(root.get("lore", {}))
	_barks = _dict(root.get("barks", {}))
	_narrator = _dict(root.get("narrator", {}))
	if _lore.is_empty():
		push_warning("NarrativeSystem: no lore loaded from %s" % DATA_PATH)


# --- Lore delivery (unlock-once journal + parchment toast) -------------------

## Unlock a lore entry the FIRST time only. Appends it to the chronicle journal,
## emits lore_unlocked, and flashes the parchment toast. Returns true only on the
## unlock; repeat calls are a silent no-op (dedup).
func deliver_lore(id: String) -> bool:
	var entry: Dictionary = lore_entry(id)
	if entry.is_empty():
		return false
	if _unlocked.has(id):
		return false
	_unlocked[id] = true
	_journal.append(id)
	lore_unlocked.emit(id, entry)
	var line: String = str(entry.get("toast", entry.get("title", "")))
	var cold: bool = str(entry.get("register", "R1")) == "R3"
	_show_toast(line, cold)
	if _journal_open:
		_rebuild_journal_list()
	return true


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func journal_ids() -> Array:
	return _journal.duplicate()


func journal_count() -> int:
	return _journal.size()


func lore_entry(id: String) -> Dictionary:
	return _dict(_lore.get(id, {}))


func all_lore() -> Dictionary:
	return _lore


# --- Ambient barks (R2, rotated by call index -- deterministic, no RNG) -------

## An ambient NPC line for a zone or faction key. Successive calls with the same
## key walk the line list in order and wrap, so repeated barks vary without any
## RandomNumberGenerator. Returns "" when the key has no lines.
func bark(key: String) -> String:
	var lines: Array = _bark_lines(key)
	if lines.is_empty():
		return ""
	var i: int = int(_bark_index.get(key, 0))
	var line: String = str(lines[i % lines.size()])
	_bark_index[key] = i + 1
	bark_spoken.emit(key, line)
	return line


func _bark_lines(key: String) -> Array:
	var z: Dictionary = _dict(_barks.get("zone", {}))
	if z.has(key):
		return _arr(z[key])
	var f: Dictionary = _dict(_barks.get("faction", {}))
	if f.has(key):
		return _arr(f[key])
	return []


func has_barks(key: String) -> bool:
	return not _bark_lines(key).is_empty()


# --- Narrator beats (R1 chronicle voice -> toast) ---------------------------

## Fire a narrator line for a key beat. Beats whose data is a keyed map
## (enter_zone / boss_intro / quest_turnin) look up `key`, falling back to a
## "_default" line; beats whose data is a list (first_death) rotate by call
## index. Shows the line as a toast and returns it ("" when nothing matches).
func narrate(beat: String, key: String = "") -> String:
	var line: String = _narrator_line(beat, key)
	if line == "":
		return ""
	# QA harness: screenshot runs must not have the parchment strip in frame.
	if OS.get_environment("RH_NOBANNER").is_empty() and not _map_is_open():
		_show_toast(line, false)
	return line


## The parchment strip must never lie over the opened map (WoW behavior:
## flavor toasts yield to the map screen). Guarded — absent systems = false.
func _map_is_open() -> bool:
	var ms: Node = get_node_or_null("/root/MapSystem")
	if ms != null and ms.has_method("is_map_open") and bool(ms.call("is_map_open")):
		return true
	for mm: Node in get_tree().get_nodes_in_group("minimap"):
		if mm.has_method("is_world_map_open") and bool(mm.call("is_world_map_open")):
			return true
	return false


func _narrator_line(beat: String, key: String) -> String:
	var data: Variant = _narrator.get(beat, null)
	if data is Array:
		var arr: Array = data
		if arr.is_empty():
			return ""
		var i: int = int(_narr_index.get(beat, 0))
		_narr_index[beat] = i + 1
		return str(arr[i % arr.size()])
	if data is Dictionary:
		var d: Dictionary = data
		if key != "" and d.has(key):
			return str(d[key])
		return str(d.get("_default", ""))
	return ""


# --- Parchment toast (self-instanced CanvasLayer, built in code) -------------

func _show_toast(text: String, cold: bool) -> void:
	if text == "":
		return
	_ensure_toast()
	if _toast_label == null or not is_instance_valid(_toast_label):
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", COL_R3 if cold else COL_INK)
	if _toast_root != null and is_instance_valid(_toast_root):
		_toast_root.modulate.a = 1.0
		_toast_root.visible = true
		if _toast_tween != null and _toast_tween.is_valid():
			_toast_tween.kill()
		if is_inside_tree():
			_toast_tween = create_tween()
			_toast_tween.tween_interval(TOAST_SECONDS)
			_toast_tween.tween_property(_toast_root, "modulate:a", 0.0, TOAST_FADE)


func _ensure_toast() -> void:
	if _toast_layer != null and is_instance_valid(_toast_layer):
		return
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "NarrativeToast"
	_toast_layer.layer = 90
	add_child(_toast_layer)

	_toast_root = Control.new()
	_toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_root)

	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# bottom-centered parchment strip
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = -380.0
	strip.offset_right = 380.0
	strip.offset_top = -150.0
	strip.offset_bottom = -78.0
	strip.add_theme_stylebox_override("panel", _parchment_box(10))
	_toast_root.add_child(strip)

	_toast_label = Label.new()
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", COL_INK)
	if _font != null:
		_toast_label.add_theme_font_override("font", _font)
	_toast_label.add_theme_font_size_override("font_size", 19)
	strip.add_child(_toast_label)


# --- Chronicle journal panel (self-instanced CanvasLayer, built in code) -----

func open_journal() -> void:
	_ensure_panel()
	if _panel == null:
		return
	_journal_open = true
	_panel.visible = true
	_rebuild_journal_list()
	journal_opened.emit()


func close_journal() -> void:
	_journal_open = false
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false


func toggle_journal() -> void:
	if _journal_open:
		close_journal()
	else:
		open_journal()


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = CanvasLayer.new()
	_panel.name = "NarrativeJournal"
	_panel.layer = 95
	_panel.visible = false
	add_child(_panel)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -360.0
	frame.offset_right = 360.0
	frame.offset_top = -260.0
	frame.offset_bottom = 260.0
	frame.add_theme_stylebox_override("panel", _parchment_box(14))
	root.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	frame.add_child(col)

	var head := Label.new()
	head.text = "THE CHRONICLE"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", COL_BEZEL)
	if _font != null:
		head.add_theme_font_override("font", _font)
	head.add_theme_font_size_override("font_size", 26)
	col.add_child(head)

	_panel_sub = Label.new()
	_panel_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_sub.add_theme_color_override("font_color", COL_INK_DIM)
	if _font != null:
		_panel_sub.add_theme_font_override("font", _font)
	_panel_sub.add_theme_font_size_override("font_size", 14)
	col.add_child(_panel_sub)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(700, 420)
	col.add_child(scroll)

	_panel_list = VBoxContainer.new()
	_panel_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_panel_list)


func _rebuild_journal_list() -> void:
	if _panel_list == null or not is_instance_valid(_panel_list):
		return
	for c: Node in _panel_list.get_children():
		c.queue_free()
	if _panel_sub != null and is_instance_valid(_panel_sub):
		_panel_sub.text = "%d entries kept" % _journal.size()
	if _journal.is_empty():
		var empty := Label.new()
		empty.text = "The chronicle is blank. The road has not yet given you anything to keep."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", COL_INK_DIM)
		if _font != null:
			empty.add_theme_font_override("font", _font)
		empty.add_theme_font_size_override("font_size", 16)
		_panel_list.add_child(empty)
		return
	for id_v: Variant in _journal:
		var e: Dictionary = lore_entry(str(id_v))
		if e.is_empty():
			continue
		var cold: bool = str(e.get("register", "R1")) == "R3"
		var title := Label.new()
		title.text = str(e.get("title", str(id_v)))
		title.add_theme_color_override("font_color", COL_R3 if cold else COL_BEZEL)
		if _font != null:
			title.add_theme_font_override("font", _font)
		title.add_theme_font_size_override("font_size", 19)
		_panel_list.add_child(title)
		var body := Label.new()
		body.text = str(e.get("body", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", COL_R3 if cold else COL_INK)
		if _font != null:
			body.add_theme_font_override("font", _font)
		body.add_theme_font_size_override("font_size", 15)
		_panel_list.add_child(body)
		var marg: String = str(e.get("marginalia", ""))
		if marg != "":
			var m := Label.new()
			m.text = "-- margin, later hand: " + marg
			m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			m.add_theme_color_override("font_color", COL_INK_DIM)
			if _font != null:
				m.add_theme_font_override("font", _font)
			m.add_theme_font_size_override("font_size", 13)
			_panel_list.add_child(m)


func _parchment_box(pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PARCH_BG
	sb.border_color = COL_BEZEL
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


# --- Input ('N' toggles the chronicle; Esc closes) --------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _journal_open:
		get_viewport().set_input_as_handled()
		close_journal()
		return
	# Was KEY_N, but N was a 3-way collision (Narrative/PvP/Calendar) that Calendar
	# won, leaving the chronicle unreachable. Reassigned to the free semicolon key;
	# the Menu panel is the discoverable path.
	if key.keycode != KEY_SEMICOLON:
		return
	if not _journal_open and _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_journal()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui", "mounts_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env demo / screenshot hook ---------------------------------------------

func _run_env_demo() -> void:
	# Seed a spread of lore so the chronicle reads full, then open it.
	for id: String in ["raven_hollow_footfall", "iron_vein_footfall", "vetka_footfall",
			"copper_wells_footfall", "book_greenmarch", "grave_magda_vetkan",
			"stone_inscription_river"]:
		deliver_lore(id)
	open_journal()


# --- Self-test (RH_NARR_TEST=1) ---------------------------------------------

func _run_selftest() -> void:
	var ok: bool = true
	var notes: Array = []

	# 1) deliver a lore entry -> journal grows + toast instanced.
	var lid: String = _first_key(_lore)
	var before: int = _journal.size()
	var delivered: bool = deliver_lore(lid)
	var grew: bool = _journal.size() == before + 1
	var toasted: bool = _toast_label != null and is_instance_valid(_toast_label)
	ok = ok and delivered and grew and toasted
	notes.append("lore ok=%s grow=%s toast=%s" % [str(delivered), str(grew), str(toasted)])

	# dedup: re-delivering the same id must be a no-op.
	var again: bool = deliver_lore(lid)
	ok = ok and not again and _journal.size() == before + 1
	notes.append("dedup=%s" % str(not again))

	# 2) fire a bark -> non-empty, and rotates by call index.
	var bkey: String = _first_key(_dict(_barks.get("zone", {})))
	var b0: String = bark(bkey)
	var b1: String = bark(bkey)
	var bark_ok: bool = b0.length() > 0
	var lines: Array = _bark_lines(bkey)
	var rotates: bool = lines.size() < 2 or b0 != b1
	ok = ok and bark_ok and rotates
	notes.append("bark len=%d rotate=%s" % [b0.length(), str(rotates)])

	# 3) narrate a beat -> non-empty line (keyed map + rotating list).
	var n_zone: String = narrate("enter_zone", "iron_vein")
	var n_death: String = narrate("first_death")
	var narr_ok: bool = n_zone.length() > 0 and n_death.length() > 0
	ok = ok and narr_ok
	notes.append("narrate zone=%d death=%d" % [n_zone.length(), n_death.length()])

	# 4) journal panel builds in code without a world/player.
	open_journal()
	var panel_ok: bool = _panel != null and is_instance_valid(_panel) \
			and _panel_list != null and _panel_list.get_child_count() > 0
	ok = ok and panel_ok
	notes.append("journal panel=%s" % str(panel_ok))
	close_journal()

	print("NARR SELFTEST %s ; lore=%d bark_keys=%d journal=%d ; %s" % [
		"PASS" if ok else "FAIL", _lore.size(),
		_dict(_barks.get("zone", {})).size() + _dict(_barks.get("faction", {})).size(),
		_journal.size(), " | ".join(notes)])


# --- helpers ----------------------------------------------------------------

func _first_key(d: Dictionary) -> String:
	for k: Variant in d.keys():
		return str(k)
	return ""


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("NarrativeSystem: missing data file '%s'" % path)
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
	return {"journal": _journal.duplicate()}


func deserialize(d: Dictionary) -> void:
	for id_v: Variant in _arr(d.get("journal", [])):
		var id: String = str(id_v)
		if _lore.has(id) and not _unlocked.has(id):
			_unlocked[id] = true
			_journal.append(id)
