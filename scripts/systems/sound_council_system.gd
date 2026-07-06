extends Node
## SoundCouncilSystem -- autoload (/root/SoundCouncilSystem). BACKLOG #87
## "10k Sound Council system (reviews every sound)".
##
## An audio COVERAGE registry + review council. The audio pipelines already exist
## (MusicSystem states/stingers/zone-region-biome beds, UISoundSystem cues, the
## VoiceRegistry speaker roster with baked VO under res://assets/vo/), but most of
## the stems are authored LATER and simply are not on disk yet -- every one of those
## systems DEGRADES SILENTLY. This council makes that silence VISIBLE: it walks
## every declared audio cue, checks whether the file actually exists, and produces a
## coverage report of present vs MISSING (the silent ones) so the owner sees exactly
## what audio still needs authoring.
##
## Everything is additive and null-safe. No other system's file is touched: the
## sibling audio systems are READ, always guarded (get_node_or_null), and this whole
## system needs no live world/player. All UI is built IN CODE as a self-instanced
## CanvasLayer, guarded so a cold headless boot never crashes.
##
## The rubric (data/sound_council.json) scores each cue on: exists (hard/observable),
## and loudness_ok / tone_fit / no_clipping (ADVISORY -- a file that is not on disk
## cannot be metered). Four council MEMBER lenses (clarity / mood / mix / canon-fit)
## give each cue a short review stance. The verdicts are advisory; the coverage is real.
##
## Public API:
##   audit() -> Dictionary            walk every declared cue; {total, present, missing,
##                                    by_source, missing_list, cues, systems}
##   review(cue) -> Dictionary        score one cue (record Dict or id String) against
##                                    the rubric + lenses -> advisory verdict
##   coverage() -> Dictionary         the last audit report (runs audit() if never run)
##   cue_ids() -> Array               every declared cue id (source-qualified)
##   missing_cues() -> Array          just the silent ones (records)
##   open_council(actor := null)      show the coverage panel
##   close_council()
##   rubric() / members()
## Signals:
##   council_audited(report)          emitted whenever audit() finishes
##   cue_reviewed(cue_id, verdict)    emitted by review()

signal council_audited(report)
signal cue_reviewed(cue_id, verdict)

const DATA_PATH := "res://data/sound_council.json"
const MUSIC_JSON := "res://data/music.json"
const UI_JSON := "res://data/ui_sounds.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"

# --- gold-bezel parchment palette (matches the fantasy UI kit) ---------------
const COL_PARCH_BG := Color(0.14, 0.11, 0.08, 0.96)
const COL_DIM := Color(0.0, 0.0, 0.0, 0.62)
const COL_BEZEL := Color(0.66, 0.52, 0.28, 1.0)
const COL_INK := Color(0.91, 0.85, 0.68, 1.0)
const COL_INK_DIM := Color(0.74, 0.68, 0.54, 1.0)
const COL_PRESENT := Color(0.55, 0.80, 0.52, 1.0)   # authored / on disk
const COL_MISSING := Color(0.86, 0.52, 0.46, 1.0)   # silent / absent

# --- rubric + members (from JSON) -------------------------------------------
var _criteria: Array = []              # [{id,name,weight,advisory,desc}]
var _members: Array = []               # [{id,name,focus,stance}]
var _vo_dir: String = "res://assets/vo/"
var _vo_speakers: Array = []           # [{id,label}]

# --- last audit -------------------------------------------------------------
var _last_report: Dictionary = {}
var _cue_by_id: Dictionary = {}        # cue_id -> cue record

# --- cached sibling data (each system's declared source of truth) -----------
var _music_root: Dictionary = {}
var _ui_root: Dictionary = {}

var _font: FontFile = null

# --- self-instanced panel (built in code, lazy, guarded) --------------------
var _panel: CanvasLayer = null
var _panel_body: VBoxContainer = null
var _panel_sub: Label = null
var is_open: bool = false


func _ready() -> void:
	_load_font()
	_load_data()
	if not OS.get_environment("RH_SOUNDCOUNCIL_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_SOUNDCOUNCIL").is_empty():
		call_deferred("_run_env_demo")


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_criteria = _arr(_dict(root.get("rubric", {})).get("criteria", []))
	_members = _arr(root.get("members", []))
	var vl: Dictionary = _dict(root.get("voice_lines", {}))
	_vo_dir = str(vl.get("vo_dir", "res://assets/vo/"))
	_vo_speakers = _arr(vl.get("speakers", []))
	if _criteria.is_empty():
		push_warning("SoundCouncilSystem: no rubric criteria loaded from %s" % DATA_PATH)
	# Each sibling's own data file is its declared cue source of truth; read once,
	# guarded. The live autoloads are probed (guarded) at audit time for liveness.
	_music_root = _read_json(MUSIC_JSON)
	_ui_root = _read_json(UI_JSON)


# --- Rubric / members accessors ---------------------------------------------

func rubric() -> Array:
	return _criteria.duplicate(true)


func members() -> Array:
	return _members.duplicate(true)


# --- The audit (walk every declared cue) ------------------------------------

## Walk every declared audio cue across all sources and check whether its file is
## actually on disk. Returns the coverage report and emits council_audited. Safe
## with no world, no player, and with any/all sibling audio systems absent.
func audit() -> Dictionary:
	var cues: Array = []
	_collect_music(cues)
	_collect_ui(cues)
	_collect_voice(cues)

	var by_source: Dictionary = {}
	var missing_list: Array = []
	var present: int = 0
	_cue_by_id.clear()
	for c_v: Variant in cues:
		var c: Dictionary = c_v
		var src: String = str(c.get("source", "?"))
		if not by_source.has(src):
			by_source[src] = {
				"label": str(c.get("source_label", src)),
				"total": 0, "present": 0, "missing": 0,
			}
		var bucket: Dictionary = by_source[src]
		bucket["total"] = int(bucket["total"]) + 1
		if bool(c.get("present", false)):
			present += 1
			bucket["present"] = int(bucket["present"]) + 1
		else:
			bucket["missing"] = int(bucket["missing"]) + 1
			missing_list.append(c)
		_cue_by_id[str(c.get("id", ""))] = c

	var total: int = cues.size()
	var report: Dictionary = {
		"total": total,
		"present": present,
		"missing": total - present,
		"coverage_pct": (100.0 * float(present) / float(total)) if total > 0 else 0.0,
		"by_source": by_source,
		"missing_list": missing_list,
		"cues": cues,
		"systems": _systems_live(),
	}
	_last_report = report
	council_audited.emit(report)
	return report


## Probe the sibling audio autoloads (guarded) so the report can note which are
## actually live. Never a dependency -- purely informational.
func _systems_live() -> Dictionary:
	return {
		"MusicSystem": get_node_or_null("/root/MusicSystem") != null,
		"UISoundSystem": get_node_or_null("/root/UISoundSystem") != null,
		"VoiceRegistry": get_node_or_null("/root/VoiceRegistry") != null,
		"Voice": get_node_or_null("/root/Voice") != null,
	}


# --- Source collectors (each self-contained + guarded) ----------------------

func _collect_music(out: Array) -> void:
	var md: Node = get_node_or_null("/root/MusicSystem")
	var states: Dictionary = _dict(_music_root.get("states", {}))
	var stingers: Dictionary = _dict(_music_root.get("stingers", {}))
	var zones: Dictionary = _dict(_music_root.get("zones", {}))
	var regions: Dictionary = _dict(_music_root.get("regions", {}))
	var biomes: Dictionary = _dict(_music_root.get("biomes", {}))

	# State beds -- prefer the live system's id list (guarded), fall back to JSON.
	var state_ids: Array = _ids_from(md, "state_ids", states)
	for sid_v: Variant in state_ids:
		var sid: String = str(sid_v)
		var path: String = str(_dict(states.get(sid, {})).get("track", ""))
		out.append(_cue("music_state", "MusicSystem: state beds", "state:" + sid, path))

	# Stingers.
	var sting_ids: Array = _ids_from(md, "stinger_ids", stingers)
	for stid_v: Variant in sting_ids:
		var stid: String = str(stid_v)
		var path2: String = str(_dict(stingers.get(stid, {})).get("track", ""))
		out.append(_cue("music_stinger", "MusicSystem: stingers", "stinger:" + stid, path2))

	# Per-zone / region / biome exploration beds (declared in the score plan).
	for zid_v: Variant in zones.keys():
		out.append(_cue("music_zone", "MusicSystem: zone beds",
			"zone:" + str(zid_v), str(zones[zid_v])))
	for rid_v: Variant in regions.keys():
		out.append(_cue("music_region", "MusicSystem: region beds",
			"region:" + str(rid_v), str(regions[rid_v])))
	for bid_v: Variant in biomes.keys():
		out.append(_cue("music_biome", "MusicSystem: biome beds",
			"biome:" + str(bid_v), str(biomes[bid_v])))


func _collect_ui(out: Array) -> void:
	var ud: Node = get_node_or_null("/root/UISoundSystem")
	var cues: Dictionary = _dict(_ui_root.get("cues", {}))
	var ids: Array = _ids_from(ud, "cue_ids", cues)
	for cid_v: Variant in ids:
		var cid: String = str(cid_v)
		# UISoundSystem exposes resolve() publicly -- use it when live (guarded).
		var path: String = ""
		if ud != null and ud.has_method("resolve"):
			path = str(ud.call("resolve", cid))
		if path == "":
			path = str(_dict(cues.get(cid, {})).get("stream", ""))
		out.append(_cue("ui_cue", "UISoundSystem: menu/HUD cues", "ui:" + cid, path))


func _collect_voice(out: Array) -> void:
	# A speaker is 'present' when at least one baked line exists in its VO dir.
	for sp_v: Variant in _vo_speakers:
		var sp: Dictionary = sp_v
		var sid: String = str(sp.get("id", ""))
		if sid == "":
			continue
		var dir_path: String = _vo_dir.path_join(sid)
		var baked: int = _count_baked(dir_path)
		var rec: Dictionary = _cue_present("voice", "VoiceRegistry: NPC voices",
			"voice:" + sid, dir_path, baked > 0)
		rec["label"] = str(sp.get("label", sid))
		rec["baked_lines"] = baked
		out.append(rec)


func _ids_from(sys: Node, method: String, fallback: Dictionary) -> Array:
	if sys != null and sys.has_method(method):
		var v: Variant = sys.call(method)
		if v is Array:
			return v
	return fallback.keys()


func _count_baked(dir_path: String) -> int:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return 0
	var n: int = 0
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		if not d.current_is_dir() and f.get_extension().to_lower() == "ogg":
			n += 1
		f = d.get_next()
	d.list_dir_end()
	return n


func _cue(source: String, source_label: String, id: String, path: String) -> Dictionary:
	return _cue_present(source, source_label, id, path,
		path != "" and ResourceLoader.exists(path))


func _cue_present(source: String, source_label: String, id: String, path: String, present: bool) -> Dictionary:
	return {
		"source": source,
		"source_label": source_label,
		"id": id,
		"path": path,
		"present": present,
	}


# --- Review a single cue against the rubric + lenses (advisory) --------------

## Score one cue. `cue` may be a cue record Dictionary (from audit) or a cue id
## String (resolved from the last audit). Returns an advisory verdict with a
## per-criterion breakdown and one short line from each council member lens.
func review(cue: Variant) -> Dictionary:
	var rec: Dictionary = _resolve_cue(cue)
	if rec.is_empty():
		var v0: Dictionary = {
			"cue": str(cue), "present": false, "score": 0.0,
			"grade": "UNKNOWN", "advisory": true,
			"summary": "no such declared cue",
			"criteria": [], "lenses": [],
		}
		cue_reviewed.emit(str(cue), v0)
		return v0

	var present: bool = bool(rec.get("present", false))
	var crit_out: Array = []
	var weighted: float = 0.0
	var wsum: float = 0.0
	for c_v: Variant in _criteria:
		var crit: Dictionary = c_v
		var cid: String = str(crit.get("id", ""))
		var w: float = float(crit.get("weight", 0.0))
		var advisory: bool = bool(crit.get("advisory", true))
		var score: float = 0.0
		var note: String = ""
		if cid == "exists":
			score = 1.0 if present else 0.0
			note = "on disk, imports" if present else "MISSING -- this cue is silent"
		elif present:
			# The file exists but its content is not metered here -- advisory pass,
			# deliberately short of full marks so nothing is auto-approved by ear.
			score = 0.75
			note = "advisory: assumed OK -- needs a metered ear"
		else:
			score = 0.0
			note = "cannot assess -- file absent"
		weighted += score * w
		wsum += w
		crit_out.append({
			"id": cid, "name": str(crit.get("name", cid)),
			"score": score, "advisory": advisory, "note": note,
		})
	var final_score: float = (weighted / wsum) if wsum > 0.0 else 0.0

	var lenses: Array = []
	for m_v: Variant in _members:
		var m: Dictionary = m_v
		var focus: String = str(m.get("focus", ""))
		var lnote: String = ("authored -- awaiting an ear on %s" % focus) if present \
			else ("SILENT -- %s cannot be judged until it is authored" % focus)
		lenses.append({
			"member": str(m.get("id", "")), "name": str(m.get("name", "")),
			"focus": focus, "note": lnote,
		})

	var grade: String = "SILENT"
	if present:
		grade = "READY" if final_score >= 0.9 else "NEEDS EAR"

	var verdict: Dictionary = {
		"cue": str(rec.get("id", "")),
		"source": str(rec.get("source_label", rec.get("source", ""))),
		"path": str(rec.get("path", "")),
		"present": present,
		"score": final_score,
		"grade": grade,
		"advisory": true,
		"criteria": crit_out,
		"lenses": lenses,
		"summary": "%s -- %.0f%% (advisory)" % [grade, final_score * 100.0],
	}
	cue_reviewed.emit(str(rec.get("id", "")), verdict)
	return verdict


func _resolve_cue(cue: Variant) -> Dictionary:
	if cue is Dictionary and (cue as Dictionary).has("id"):
		return cue
	if cue is String:
		if _cue_by_id.is_empty():
			audit()
		return _dict(_cue_by_id.get(str(cue), {}))
	return {}


# --- Convenience report accessors -------------------------------------------

func coverage() -> Dictionary:
	if _last_report.is_empty():
		return audit()
	return _last_report


func cue_ids() -> Array:
	var out: Array = []
	for c_v: Variant in coverage().get("cues", []):
		out.append(str((c_v as Dictionary).get("id", "")))
	return out


func missing_cues() -> Array:
	return _arr(coverage().get("missing_list", [])).duplicate()


# --- Coverage panel (self-instanced CanvasLayer, built entirely in code) -----

func open_council(_actor: Node = null) -> void:
	var report: Dictionary = audit()
	_ensure_panel()
	if _panel == null:
		return
	_rebuild_panel(report)
	_panel.visible = true
	is_open = true


func close_council() -> void:
	is_open = false
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = CanvasLayer.new()
	_panel.name = "SoundCouncilPanel"
	_panel.layer = 95
	_panel.visible = false
	add_child(_panel)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COL_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -400.0
	frame.offset_right = 400.0
	frame.offset_top = -300.0
	frame.offset_bottom = 300.0
	frame.add_theme_stylebox_override("panel", _parchment_box(16))
	root.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	frame.add_child(col)

	var head := Label.new()
	head.text = "THE SOUND COUNCIL"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", COL_BEZEL)
	_font_on(head, 28)
	col.add_child(head)

	_panel_sub = Label.new()
	_panel_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_sub.add_theme_color_override("font_color", COL_INK_DIM)
	_font_on(_panel_sub, 15)
	col.add_child(_panel_sub)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(760, 470)
	col.add_child(scroll)

	_panel_body = VBoxContainer.new()
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_panel_body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close_council)
	col.add_child(close_btn)


func _rebuild_panel(report: Dictionary) -> void:
	if _panel_body == null or not is_instance_valid(_panel_body):
		return
	for c: Node in _panel_body.get_children():
		c.queue_free()

	var total: int = int(report.get("total", 0))
	var present: int = int(report.get("present", 0))
	var missing: int = int(report.get("missing", 0))
	if _panel_sub != null and is_instance_valid(_panel_sub):
		_panel_sub.text = "%d cues reviewed  --  %d authored  --  %d SILENT  (%.0f%% covered)" % [
			total, present, missing, float(report.get("coverage_pct", 0.0))]

	# Per-source coverage rows.
	_add_heading("Coverage by source")
	var by_source: Dictionary = _dict(report.get("by_source", {}))
	for src_v: Variant in by_source.keys():
		var b: Dictionary = _dict(by_source[src_v])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.text = str(b.get("label", src_v))
		lbl.custom_minimum_size = Vector2(360, 0)
		lbl.add_theme_color_override("font_color", COL_INK)
		_font_on(lbl, 15)
		row.add_child(lbl)
		var counts := Label.new()
		counts.text = "present %d / silent %d / total %d" % [
			int(b.get("present", 0)), int(b.get("missing", 0)), int(b.get("total", 0))]
		var all_present: bool = int(b.get("missing", 0)) == 0 and int(b.get("total", 0)) > 0
		counts.add_theme_color_override("font_color",
			COL_PRESENT if all_present else COL_MISSING)
		_font_on(counts, 15)
		row.add_child(counts)
		_panel_body.add_child(row)

	# Top silent cues -- exactly what still needs authoring.
	var missing_list: Array = _arr(report.get("missing_list", []))
	_add_heading("Top silent cues (%d) -- these need authoring" % missing_list.size())
	if missing_list.is_empty():
		_add_line("Every declared cue is authored. The council rests.", COL_PRESENT, 15)
	else:
		var shown: int = mini(14, missing_list.size())
		for i in range(shown):
			var c: Dictionary = missing_list[i]
			_add_line("  %s   ->   %s" % [str(c.get("id", "")), str(c.get("path", ""))],
				COL_MISSING, 13)
		if missing_list.size() > shown:
			_add_line("  ... and %d more" % [missing_list.size() - shown], COL_INK_DIM, 13)

	# The council's four lenses (who is judging).
	_add_heading("The council")
	for m_v: Variant in _members:
		var m: Dictionary = m_v
		_add_line("  %s (%s) -- %s" % [
			str(m.get("name", "")), str(m.get("focus", "")), str(m.get("stance", ""))],
			COL_INK_DIM, 13)


func _add_heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COL_BEZEL)
	_font_on(l, 18)
	_panel_body.add_child(l)


func _add_line(text: String, col: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	_font_on(l, size)
	_panel_body.add_child(l)


func _font_on(l: Label, size: int) -> void:
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)


func _parchment_box(pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PARCH_BG
	sb.border_color = COL_BEZEL
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


# --- helpers ----------------------------------------------------------------

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("SoundCouncilSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Env demo / screenshot hook ---------------------------------------------

func _run_env_demo() -> void:
	open_council()


# --- Self-test (RH_SOUNDCOUNCIL_TEST=1) -------------------------------------

func _run_selftest() -> void:
	var ok: bool = true
	var notes: Array = []

	# 1) audit() returns a coverage report with cues and a missing_list, no crash
	#    even though most stems are absent on disk.
	var report: Dictionary = audit()
	var total: int = int(report.get("total", 0))
	var present: int = int(report.get("present", 0))
	var missing: int = int(report.get("missing", 0))
	var has_missing_list: bool = report.has("missing_list") and report["missing_list"] is Array
	var has_sources: bool = not _dict(report.get("by_source", {})).is_empty()
	ok = ok and total > 0 and has_missing_list and has_sources and (present + missing == total)
	notes.append("audit total=%d present=%d missing=%d sources=%d" % [
		total, present, missing, _dict(report.get("by_source", {})).size()])

	# 2) review one cue (prefer a silent one so the SILENT path is exercised).
	var target: Variant = null
	var mlist: Array = _arr(report.get("missing_list", []))
	if not mlist.is_empty():
		target = mlist[0]
	elif not _arr(report.get("cues", [])).is_empty():
		target = _arr(report.get("cues", []))[0]
	var got_review: Array = [false]
	var rcb := func(_id: Variant, _v: Variant) -> void: got_review[0] = true
	cue_reviewed.connect(rcb)
	var verdict: Dictionary = review(target)
	var review_ok: bool = verdict.has("score") and verdict.has("grade") \
		and verdict.has("criteria") and (verdict["criteria"] as Array).size() > 0 \
		and got_review[0]
	cue_reviewed.disconnect(rcb)
	ok = ok and review_ok
	notes.append("review cue=%s grade=%s score=%.2f" % [
		str(verdict.get("cue", "?")), str(verdict.get("grade", "?")),
		float(verdict.get("score", 0.0))])

	# 3) open the panel -> it instances in code with no world/player.
	open_council()
	var panel_ok: bool = _panel != null and is_instance_valid(_panel) \
		and _panel_body != null and _panel_body.get_child_count() > 0
	ok = ok and panel_ok
	notes.append("panel=%s children=%d" % [
		str(panel_ok), _panel_body.get_child_count() if _panel_body != null else -1])
	close_council()

	print("SOUNDCOUNCIL SELFTEST %s total=%d present=%d missing=%d ; %s" % [
		"PASS" if ok else "FAIL", total, present, missing, " | ".join(notes)])
