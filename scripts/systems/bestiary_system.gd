extends Node
## BestiarySystem -- autoload (/root/BestiarySystem). BACKLOG #76
## "Bestiary framework" (the FRAMEWORK only: creature registry + unique signature
## debuffs + spawn tables + discovery codex UI). The ~1500 sprites/anims are a
## later art pass and are NOT part of this system.
##
## Loads data/bestiary.json: ~63 SIGNATURE creatures spread across every biome and
## all seven families (undead, beast, insectoid, cultist, construct, aberration,
## spectral). Each carries id/name/family/biome+zones/tier/base stats, an archetype
## (references data/combat_archetypes.json AI), a UNIQUE signature debuff (references
## data/status_effects.json or a documented new_debuffs entry with an existing
## 'base' effect), a loot_table ref, a death_anim placeholder, and a lore blurb.
##
## Everything here is additive and null-safe. No other system's file is edited --
## StatusSystem and its data are READ (guarded) only. The codex UI is a self-
## instanced CanvasLayer built entirely in code, so a headless boot with no world
## or player never crashes.
##
## Public API:
##   creature(id) -> Dictionary            the full creature def ({} if unknown)
##   family(f) -> Array                     creature ids in a family
##   for_biome(b) -> Array                  creature ids native to a biome
##   for_zone(z) -> Array                   creature ids that spawn in a zone
##   spawn_table_for(zone) -> Array         [{id, weight}] for a zone (or biome)
##   all_ids() -> Array ; creature_count() -> int ; families() -> Array
##   family_name(f) -> String ; debuff_def(id) -> Dictionary
##   -- discovery / codex --
##   discover(id) -> bool                   mark seen (guarded, once); emits
##   is_discovered(id) -> bool ; discovered_count() -> int
##   apply_signature(attacker_id, target, force := false) -> Dictionary
##                                          route the creature's unique debuff
##                                          through StatusSystem (guarded fallback)
##   open_codex() / close_codex() / toggle_codex()
## Signals: creature_discovered(id), signature_applied(attacker_id, target, debuff),
##   codex_opened().

signal creature_discovered(id)
signal signature_applied(attacker_id, target, debuff)
signal codex_opened()

const DATA_PATH := "res://data/bestiary.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"

# --- gold-bezel fantasy palette (matches the studio UI kit) -------------------
const COL_BG := Color(0.10, 0.09, 0.07, 0.96)
const COL_CARD := Color(0.15, 0.13, 0.10, 0.94)
const COL_BEZEL := Color(0.66, 0.52, 0.28, 1.0)
const COL_INK := Color(0.90, 0.84, 0.67, 1.0)
const COL_INK_DIM := Color(0.72, 0.66, 0.52, 1.0)
const COL_LOCKED := Color(0.42, 0.40, 0.36, 1.0)

# family -> a readable accent for its header
const FAMILY_COLORS := {
	"undead": Color(0.62, 0.74, 0.60),
	"beast": Color(0.80, 0.58, 0.34),
	"insectoid": Color(0.74, 0.78, 0.36),
	"cultist": Color(0.78, 0.42, 0.40),
	"construct": Color(0.62, 0.66, 0.74),
	"aberration": Color(0.70, 0.44, 0.78),
	"spectral": Color(0.55, 0.78, 0.82),
}

var _creatures: Dictionary = {}       # id -> def dict
var _new_debuffs: Dictionary = {}     # id -> {name, kind, base, dispel_type, note}
var _families_order: Array = []       # family ids in codex order
var _family_names: Dictionary = {}    # family -> display name

var _by_family: Dictionary = {}       # family -> [ids]
var _by_biome: Dictionary = {}        # biome -> [ids]
var _by_zone: Dictionary = {}         # zone -> [ids]

var _discovered: Dictionary = {}      # id -> true

var _rng := RandomNumberGenerator.new()
var _font: FontFile = null

# self-instanced codex UI (built in code, lazy, guarded)
var _codex: CanvasLayer = null
var _codex_list: VBoxContainer = null
var _codex_sub: Label = null
var _is_open: bool = false


func _ready() -> void:
	_rng.randomize()
	_load_font()
	_load_data()
	if not OS.get_environment("RH_BESTIARY_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_BESTIARY").is_empty():
		call_deferred("_run_env_demo")


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as FontFile


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_creatures = _dict(root.get("creatures", {}))
	_new_debuffs = _dict(root.get("new_debuffs", {}))
	_families_order = _arr(root.get("families_order", []))
	_family_names = _dict(root.get("family_names", {}))
	_build_indices()
	if _creatures.is_empty():
		push_warning("BestiarySystem: no creatures loaded from %s" % DATA_PATH)


func _build_indices() -> void:
	_by_family.clear()
	_by_biome.clear()
	_by_zone.clear()
	for id: String in _creatures.keys():
		var c: Dictionary = _dict(_creatures[id])
		var fam: String = str(c.get("family", ""))
		var bio: String = str(c.get("biome", ""))
		if fam != "":
			_push(_by_family, fam, id)
		if bio != "":
			_push(_by_biome, bio, id)
		for z_v: Variant in _arr(c.get("zones", [])):
			var z: String = str(z_v)
			if z != "":
				_push(_by_zone, z, id)
	# Any family declared in families_order but empty still registers an entry so
	# the codex renders its (empty) section deterministically.
	for fam_v: Variant in _families_order:
		var fam2: String = str(fam_v)
		if not _by_family.has(fam2):
			_by_family[fam2] = []


# --- Registry queries --------------------------------------------------------

func creature(id: String) -> Dictionary:
	return _dict(_creatures.get(id, {}))


func all_ids() -> Array:
	return _creatures.keys()


func creature_count() -> int:
	return _creatures.size()


func families() -> Array:
	if not _families_order.is_empty():
		return _families_order.duplicate()
	return _by_family.keys()


func family(f: String) -> Array:
	return (_arr(_by_family.get(f, []))).duplicate()


func family_name(f: String) -> String:
	return str(_family_names.get(f, f.capitalize()))


func for_biome(b: String) -> Array:
	return (_arr(_by_biome.get(b, []))).duplicate()


func for_zone(z: String) -> Array:
	return (_arr(_by_zone.get(z, []))).duplicate()


func biomes() -> Array:
	return _by_biome.keys()


## A weighted spawn table for a zone. Prefers the creatures that list this zone;
## falls back to the whole biome when `zone` names a biome instead. Weight favors
## lower tiers (common trash spawns more than an elite): weight = max(1, 6 - tier).
## Returns [] for an unknown zone/biome so a caller degrades to nothing.
func spawn_table_for(zone: String) -> Array:
	var ids: Array = _arr(_by_zone.get(zone, []))
	if ids.is_empty():
		ids = _arr(_by_biome.get(zone, []))
	var out: Array = []
	for id_v: Variant in ids:
		var id: String = str(id_v)
		var tier: int = int(creature(id).get("tier", 1))
		out.append({"id": id, "weight": maxi(1, 6 - tier), "tier": tier})
	return out


## The full debuff definition for a signature id: prefer the documented new_debuffs
## entry, else the live StatusSystem catalog def (guarded). {} if neither knows it.
func debuff_def(id: String) -> Dictionary:
	if _new_debuffs.has(id):
		return _dict(_new_debuffs[id])
	var ss: Node = _status_system()
	if ss != null and ss.has_method("get_def"):
		var d: Variant = ss.call("get_def", id)
		if d is Dictionary:
			return d
	return {}


# --- Discovery (codex "seen" state, guarded) --------------------------------

## Mark a creature discovered the FIRST time it is encountered. Returns true only
## on the transition (repeat calls are a silent no-op). Guarded against unknown ids.
func discover(id: String) -> bool:
	if not _creatures.has(id) or _discovered.has(id):
		return false
	_discovered[id] = true
	creature_discovered.emit(id)
	if _is_open:
		_rebuild_codex_list()
	return true


func is_discovered(id: String) -> bool:
	return _discovered.has(id)


func discovered_count() -> int:
	return _discovered.size()


# --- Signature debuff routing (through StatusSystem, guarded + fallback) ------

## Route a creature's UNIQUE signature debuff onto `target`. Rolls the on-hit
## chance (bypassed by `force`). Resolution, in order:
##   1) the debuff id is a live StatusSystem effect  -> apply it (via "status")
##   2) it is a documented new_debuff with a real base -> apply the base (via "fallback")
##   3) neither -> emit the signal only (via "signal"), so the framework still
##      records the intent for the art/design pass.
## Encountering a creature also discovers it. Returns
## {applied, via, debuff, rolled, chance}.
func apply_signature(attacker_id: String, target: Object, force: bool = false) -> Dictionary:
	discover(attacker_id)
	var c: Dictionary = creature(attacker_id)
	var sig: Dictionary = _dict(c.get("signature", {}))
	var debuff: String = str(sig.get("debuff", ""))
	var chance: float = float(sig.get("chance", 0.0))
	var res: Dictionary = {"applied": false, "via": "none", "debuff": debuff,
			"rolled": false, "chance": chance}
	if debuff == "":
		return res
	var rolled: bool = force or _rng.randf() < chance
	res["rolled"] = rolled
	if not rolled:
		res["via"] = "no_roll"
		return res
	var ss: Node = _status_system()
	# 1) direct: the debuff itself is in the live StatusSystem catalog.
	if ss != null and ss.has_method("get_def") and ss.has_method("apply") \
			and not _dict(ss.call("get_def", debuff)).is_empty():
		if _valid_target(target):
			var ok: bool = bool(ss.call("apply", target, debuff, _self_source(attacker_id)))
			res["applied"] = ok
			res["via"] = "status"
		signature_applied.emit(attacker_id, target, debuff)
		return res
	# 2) fallback: a documented new debuff routed onto its existing base effect.
	var base: String = str(_dict(_new_debuffs.get(debuff, {})).get("base", ""))
	if base != "" and ss != null and ss.has_method("get_def") and ss.has_method("apply") \
			and not _dict(ss.call("get_def", base)).is_empty():
		if _valid_target(target):
			var ok2: bool = bool(ss.call("apply", target, base, _self_source(attacker_id)))
			res["applied"] = ok2
			res["via"] = "fallback"
			res["base"] = base
		signature_applied.emit(attacker_id, target, debuff)
		return res
	# 3) neither known: record intent only (still a real signal for listeners).
	res["via"] = "signal"
	signature_applied.emit(attacker_id, target, debuff)
	return res


func _valid_target(target: Object) -> bool:
	return target != null and is_instance_valid(target)


## StatusSystem uses a source object's `damage` for tick potency; there is no live
## creature Node here (framework, not a spawned enemy), so signatures apply with a
## null source and lean on the effect's flat tick. Returns null (kept as a seam).
func _self_source(_attacker_id: String) -> Object:
	return null


func _status_system() -> Node:
	return get_node_or_null("/root/StatusSystem")


# --- Codex UI (self-instanced CanvasLayer, built entirely in code) -----------

func open_codex() -> void:
	_ensure_codex()
	if _codex == null:
		return
	_is_open = true
	_codex.visible = true
	_rebuild_codex_list()
	codex_opened.emit()


func close_codex() -> void:
	_is_open = false
	if _codex != null and is_instance_valid(_codex):
		_codex.visible = false


func toggle_codex() -> void:
	if _is_open:
		close_codex()
	else:
		open_codex()


func _ensure_codex() -> void:
	if _codex != null and is_instance_valid(_codex):
		return
	_codex = CanvasLayer.new()
	_codex.name = "BestiaryCodex"
	_codex.layer = 96
	_codex.visible = false
	add_child(_codex)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.66)
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
	frame.add_theme_stylebox_override("panel", _bezel_box(COL_BG, 14))
	root.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	frame.add_child(col)

	var head := Label.new()
	head.text = "THE HOLLOW BESTIARY"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_color", COL_BEZEL)
	_font_it(head, 28)
	col.add_child(head)

	_codex_sub = Label.new()
	_codex_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codex_sub.add_theme_color_override("font_color", COL_INK_DIM)
	_font_it(_codex_sub, 14)
	col.add_child(_codex_sub)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(760, 500)
	col.add_child(scroll)

	_codex_list = VBoxContainer.new()
	_codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_codex_list)


func _rebuild_codex_list() -> void:
	if _codex_list == null or not is_instance_valid(_codex_list):
		return
	for ch: Node in _codex_list.get_children():
		ch.queue_free()
	if _codex_sub != null and is_instance_valid(_codex_sub):
		_codex_sub.text = "%d of %d creatures recorded" % [discovered_count(), creature_count()]
	for fam_v: Variant in families():
		var fam: String = str(fam_v)
		var ids: Array = family(fam)
		# Header for the family band.
		var hdr := Label.new()
		var seen: int = 0
		for id_v: Variant in ids:
			if is_discovered(str(id_v)):
				seen += 1
		hdr.text = "%s   (%d/%d)" % [family_name(fam).to_upper(), seen, ids.size()]
		hdr.add_theme_color_override("font_color", FAMILY_COLORS.get(fam, COL_BEZEL))
		_font_it(hdr, 20)
		_codex_list.add_child(hdr)
		ids.sort_custom(_sort_by_tier)
		for id_v2: Variant in ids:
			_codex_list.add_child(_build_creature_card(str(id_v2)))


func _sort_by_tier(a: Variant, b: Variant) -> bool:
	return int(creature(str(a)).get("tier", 0)) < int(creature(str(b)).get("tier", 0))


func _build_creature_card(id: String) -> PanelContainer:
	var c: Dictionary = creature(id)
	var known: bool = is_discovered(id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _bezel_box(COL_CARD, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)

	var title := Label.new()
	if known:
		title.text = "%s      [Tier %d - %s]" % [
				str(c.get("name", id)), int(c.get("tier", 1)),
				str(c.get("biome", "")).capitalize()]
		title.add_theme_color_override("font_color", COL_INK)
	else:
		title.text = "???      [undiscovered]"
		title.add_theme_color_override("font_color", COL_LOCKED)
	_font_it(title, 18)
	box.add_child(title)

	if not known:
		var hint := Label.new()
		hint.text = "A %s of the %s. Defeat one to record it." % [
				family_name(str(c.get("family", ""))).to_lower(),
				str(c.get("biome", "")).capitalize()]
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", COL_LOCKED)
		_font_it(hint, 13)
		box.add_child(hint)
		return card

	var st: Dictionary = _dict(c.get("stats", {}))
	var stat_line := Label.new()
	stat_line.text = "HP %d   DMG %d   SPD %d   ARM %d   |   AI: %s" % [
			int(st.get("hp", 0)), int(st.get("dmg", 0)), int(st.get("speed", 0)),
			int(st.get("armor", 0)), str(c.get("archetype", "-"))]
	stat_line.add_theme_color_override("font_color", COL_INK_DIM)
	_font_it(stat_line, 14)
	box.add_child(stat_line)

	var sig: Dictionary = _dict(c.get("signature", {}))
	var dbg: String = str(sig.get("debuff", ""))
	var dd: Dictionary = debuff_def(dbg)
	var sig_line := Label.new()
	sig_line.text = "Signature: %s  (%d%% on hit)" % [
			str(dd.get("name", dbg.capitalize())),
			int(round(float(sig.get("chance", 0.0)) * 100.0))]
	sig_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sig_line.add_theme_color_override("font_color", FAMILY_COLORS.get(str(c.get("family", "")), COL_BEZEL))
	_font_it(sig_line, 14)
	box.add_child(sig_line)

	var note: String = str(dd.get("note", ""))
	if note != "":
		var note_l := Label.new()
		note_l.text = "   " + note
		note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_l.add_theme_color_override("font_color", COL_INK_DIM)
		_font_it(note_l, 12)
		box.add_child(note_l)

	var lore := Label.new()
	lore.text = str(c.get("lore", ""))
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_color_override("font_color", COL_INK)
	_font_it(lore, 13)
	box.add_child(lore)
	return card


func _bezel_box(bg: Color, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = COL_BEZEL
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


func _font_it(l: Label, size: int) -> void:
	if _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)


# --- Input ('B' toggles the codex; Esc closes) ------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _is_open:
		get_viewport().set_input_as_handled()
		close_codex()
		return
	if key.keycode != KEY_B:
		return
	if not _is_open and _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_codex()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui", "mounts_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env demo / screenshot hook ---------------------------------------------

func _run_env_demo() -> void:
	# Seed a spread so the codex reads part-full (some ??? still), then open it.
	var seeded: int = 0
	for id: String in _creatures.keys():
		discover(id)
		seeded += 1
		if seeded >= int(float(_creatures.size()) * 0.6):
			break
	open_codex()


# --- Self-test (RH_BESTIARY_TEST=1) -----------------------------------------

func _run_selftest() -> void:
	var ok: bool = true
	var notes: Array = []

	# 1) registry has at least 50 signature creatures.
	var n: int = creature_count()
	var reg_ok: bool = n >= 50
	ok = ok and reg_ok
	notes.append("registry=%d(>=50:%s)" % [n, str(reg_ok)])

	# 2) every biome represented in the data has at least one creature.
	var biome_min: int = 999
	for b_v: Variant in biomes():
		biome_min = mini(biome_min, for_biome(str(b_v)).size())
	if biomes().is_empty():
		biome_min = 0
	var biomes_ok: bool = biomes().size() > 0 and biome_min >= 1
	ok = ok and biomes_ok
	notes.append("biomes=%d min_per=%d(%s)" % [biomes().size(), biome_min, str(biomes_ok)])

	# 3) all seven families present and non-empty.
	var fam_ok: bool = true
	for f_v: Variant in ["undead", "beast", "insectoid", "cultist", "construct", "aberration", "spectral"]:
		if family(str(f_v)).is_empty():
			fam_ok = false
	ok = ok and fam_ok
	notes.append("families7=%s" % str(fam_ok))

	# 4) spawn table for a real zone returns weighted picks.
	var st: Array = spawn_table_for("stonepath")
	var st_ok: bool = st.size() >= 1 and int(_dict(st[0]).get("weight", 0)) >= 1
	ok = ok and st_ok
	notes.append("spawn(stonepath)=%d(%s)" % [st.size(), str(st_ok)])

	# 5) apply a signature debuff to a fake target -> StatusSystem call or fallback.
	var target := Node.new()
	target.name = "BestiaryTestTarget"
	add_child(target)
	# A direct-catalog signature (stonepath_wolf -> wolf_bite exists in StatusSystem).
	var r_direct: Dictionary = apply_signature("stonepath_wolf", target, true)
	# A new-debuff signature that must fall back onto its base (hollow_stag ->
	# hemorrhage -> bleed). bleed has no on_apply stat mods, so it lands cleanly on
	# an unregistered fake target without touching StatsSystem.
	var r_fallback: Dictionary = apply_signature("hollow_stag", target, true)
	var ss_present: bool = _status_system() != null
	var routed_ok: bool
	if ss_present:
		# With StatusSystem live, at least one route must actually land an effect.
		routed_ok = (str(r_direct.get("via", "")) in ["status", "fallback"] and bool(r_direct.get("applied", false))) \
				or (str(r_fallback.get("via", "")) in ["status", "fallback"] and bool(r_fallback.get("applied", false)))
	else:
		# No StatusSystem in this boot: the guarded path still emits the signal.
		routed_ok = str(r_direct.get("via", "")) == "signal"
	ok = ok and routed_ok
	notes.append("sig_direct=%s sig_fallback=%s ss=%s(%s)" % [
			str(r_direct.get("via", "")), str(r_fallback.get("via", "")),
			str(ss_present), str(routed_ok)])
	target.queue_free()

	# 6) discovery + codex instancing.
	var first_id: String = _first_key(_creatures)
	# discover() was already tripped for the two signature attackers; use a fresh id.
	var disc: bool = discover(first_id) or is_discovered(first_id)
	open_codex()
	var codex_ok: bool = _codex != null and is_instance_valid(_codex) \
			and _codex_list != null and _codex_list.get_child_count() > 0
	ok = ok and disc and codex_ok
	notes.append("discover=%s codex_children=%d" % [
			str(disc), (_codex_list.get_child_count() if _codex_list != null else 0)])
	close_codex()

	print("BESTIARY SELFTEST %s creatures=%d biomes=%d ; %s" % [
			"PASS" if ok else "FAIL", n, biomes().size(), " | ".join(notes)])


# --- helpers ----------------------------------------------------------------

func _push(index: Dictionary, key: String, id: String) -> void:
	if not index.has(key):
		index[key] = []
	(index[key] as Array).append(id)


func _first_key(d: Dictionary) -> String:
	for k: Variant in d.keys():
		return str(k)
	return ""


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("BestiarySystem: missing data file '%s'" % path)
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
	return {"discovered": _discovered.keys()}


func deserialize(d: Dictionary) -> void:
	for id_v: Variant in _arr(d.get("discovered", [])):
		var id: String = str(id_v)
		if _creatures.has(id):
			_discovered[id] = true
