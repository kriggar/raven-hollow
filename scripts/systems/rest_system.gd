extends Node
## RestManager -- resting + hearth downtime for Raven Hollow (BACKLOG #70).
## Instanced as a child of the FactionSystem autoload (which forwards start_rest /
## is_resting / stop_rest); it cannot be its own autoload without editing
## project.godot, and resting is a small companion to the standing systems.
##
## Two rest qualities: "inn" (a bed / an innkeeper NPC -- the Ember Hearth's Marta)
## and "hearth" (a campfire prop out in the world -- downtime). Resting restores
## health and mana over time (inn recovers faster) and grants a "Well Rested"
## buff: a real StatusSystem effect (visible, timed, +Spirit/+Stamina recovery)
## PLUS a lingering XP multiplier a future XP grant can read (xp_multiplier()).
## The buff is applied THROUGH StatusSystem when that autoload is present -- the
## effect def is injected at runtime (guarded) so no status_effects.json edit is
## needed. Moving away from the rest spot (or a null host) breaks the rest.
##
## A small prompt ("[T] Rest -- The Ember Hearth") appears when the player stands
## near a rest spot; T starts the rest and a resting overlay shows the recovery.
##
## API (actor optional -> the player):
##   start_rest(actor, quality) -> bool
##   is_resting(actor) -> bool
##   stop_rest(actor) -> bool
##   rest_quality(actor) -> String ; xp_multiplier(actor) -> float
## Signals: rest_started(actor, quality), rest_stopped(actor, quality),
##   well_rested_applied(actor, quality, xp_mult).

signal rest_started(actor, quality)
signal rest_stopped(actor, quality)
signal well_rested_applied(actor, quality, xp_mult)

const REST_KEY := KEY_T
const PROMPT_POLL_S := 0.2
const BREAK_DIST := 46.0          # move this far from the spot and the rest ends
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const PANEL_TEX := "res://assets/art/ui/panel_brown.png"

## Per-quality tuning: hp/mana restored per second (as a fraction of the max) and
## the Well Rested payload (buff seconds + XP multiplier).
const QUALITY := {
	"inn":    {"regen": 0.14, "buff_dur": 900.0, "xp_mult": 1.5,  "label": "The Ember Hearth"},
	"hearth": {"regen": 0.07, "buff_dur": 600.0, "xp_mult": 1.25, "label": "the campfire"},
}

## The Well Rested StatusSystem def, injected into StatusSystem at runtime so the
## buff routes through the real framework without editing status_effects.json.
const WELL_RESTED_DEF := {
	"id": "well_rested",
	"name": "Well Rested",
	"kind": "buff",
	"dispel_type": "none",
	"duration": 900.0,
	"tick_interval": 0.0,
	"stack_max": 1,
	"stack_rule": "refresh",
	"on_apply": {"stat_mods": {"spirit": 2.0, "stamina": 1.0}},
	"on_tick": {},
	"on_expire": {},
	"threshold": {},
	"icon_hint": "well_rested",
}

## instance_id -> {resting, quality, spot: Vector2, xp_mult}
var _state: Dictionary = {}
var _poll_accum: float = 0.0

# Prompt UI (built in code, self-contained CanvasLayer).
var _layer: CanvasLayer = null
var _prompt_panel: Control = null
var _prompt_label: Label = null
var _near_spot: Dictionary = {}   # {found, quality, pos, name} for the current frame


func _ready() -> void:
	set_process(true)
	_build_prompt()
	if not OS.get_environment("RH_REST").is_empty() \
			or OS.get_environment("RH_SHOT").to_lower().find("rest") >= 0:
		call_deferred("_run_env_hooks")


# --- Rest lifecycle ---------------------------------------------------------

func start_rest(actor: Node, quality: String = "inn") -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if not QUALITY.has(quality):
		quality = "inn"
	var q: Dictionary = QUALITY[quality]
	var st: Dictionary = _st(actor)
	st["resting"] = true
	st["quality"] = quality
	st["xp_mult"] = float(q.get("xp_mult", 1.5))
	st["spot"] = _pos(actor)
	# Apply the Well Rested buff (the XP buff) through StatusSystem when present.
	_apply_well_rested(actor, quality)
	# A guarded, future-proof hook: if the actor ever exposes an XP-rest field,
	# feed it the multiplier so a later XP grant can honor rested XP.
	if _has_prop(actor, "xp_rest_mult"):
		actor.set("xp_rest_mult", float(st["xp_mult"]))
	rest_started.emit(actor, quality)
	well_rested_applied.emit(actor, quality, float(st["xp_mult"]))
	return true


func is_resting(actor: Node) -> bool:
	return actor != null and bool(_st(actor).get("resting", false))


func stop_rest(actor: Node) -> bool:
	if actor == null:
		return false
	var st: Dictionary = _st(actor)
	if not bool(st.get("resting", false)):
		return false
	var q: String = str(st.get("quality", "inn"))
	st["resting"] = false
	if _has_prop(actor, "xp_rest_mult"):
		actor.set("xp_rest_mult", 1.0)
	rest_stopped.emit(actor, q)
	return true


func rest_quality(actor: Node) -> String:
	return str(_st(actor).get("quality", "")) if is_resting(actor) else ""


## The XP multiplier the actor's Well Rested state grants (1.0 = none). Reads the
## live StatusSystem buff when present so it drains exactly with the buff.
func xp_multiplier(actor: Node) -> float:
	if actor == null:
		return 1.0
	if _well_rested_active(actor):
		return float(_st(actor).get("xp_mult", 1.5))
	return 1.0


# --- Regen tick + break + prompt --------------------------------------------

func _process(delta: float) -> void:
	# Recover HP/mana for every resting actor; break rest on movement / dead host.
	for iid: int in _state.keys():
		var st: Dictionary = _state[iid]
		if not bool(st.get("resting", false)):
			continue
		var actor: Object = instance_from_id(iid)
		if actor == null or not is_instance_valid(actor):
			st["resting"] = false
			continue
		if bool(actor.get("_dead")) or _pos(actor).distance_to(st.get("spot", _pos(actor))) > BREAK_DIST:
			stop_rest(actor as Node)
			continue
		var q: Dictionary = QUALITY.get(str(st.get("quality", "inn")), QUALITY["inn"])
		var rate: float = float(q.get("regen", 0.1))
		_recover(actor, "hp", "max_hp", rate, delta)
		_recover(actor, "mana", "max_mana", rate, delta)

	# Proximity prompt (throttled).
	_poll_accum += delta
	if _poll_accum >= PROMPT_POLL_S:
		_poll_accum = 0.0
		_update_prompt()


func _recover(actor: Object, cur_prop: String, max_prop: String, rate: float, delta: float) -> void:
	if not (_has_prop(actor, cur_prop) and _has_prop(actor, max_prop)):
		return
	var mx: float = float(actor.get(max_prop))
	var cur: float = float(actor.get(cur_prop))
	if cur < mx:
		actor.set(cur_prop, minf(mx, cur + mx * rate * delta))


# --- Well Rested buff via StatusSystem --------------------------------------

func _apply_well_rested(actor: Node, quality: String) -> void:
	var ss: Node = get_node_or_null("/root/StatusSystem")
	if ss == null or not ss.has_method("apply"):
		return
	# Inject the def once (guarded), then apply through the real framework.
	if ss.has_method("get_def") and (ss.call("get_def", "well_rested") as Dictionary).is_empty():
		var defs: Variant = ss.get("_defs")
		if defs is Dictionary:
			var d: Dictionary = WELL_RESTED_DEF.duplicate(true)
			d["duration"] = float(QUALITY.get(quality, {}).get("buff_dur", 900.0))
			(defs as Dictionary)["well_rested"] = d
	ss.call("apply", actor, "well_rested")


func _well_rested_active(actor: Node) -> bool:
	var ss: Node = get_node_or_null("/root/StatusSystem")
	if ss != null and ss.has_method("has"):
		return bool(ss.call("has", actor, "well_rested"))
	# No StatusSystem -> fall back to our own resting flag.
	return is_resting(actor)


# --- Prompt UI --------------------------------------------------------------

func _build_prompt() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.name = "RestPromptLayer"
	add_child(_layer)

	var frame := NinePatchRect.new()
	frame.texture = load(PANEL_TEX) as Texture2D
	frame.patch_margin_left = 8
	frame.patch_margin_right = 8
	frame.patch_margin_top = 8
	frame.patch_margin_bottom = 8
	frame.size = Vector2(240.0, 30.0)
	# Bottom-center of the 640x360 base viewport.
	frame.position = Vector2(320.0 - 120.0, 300.0)
	_layer.add_child(frame)
	_prompt_panel = frame

	var lbl := Label.new()
	lbl.add_theme_font_override("font", load(FONT_PATH) as FontFile)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.68, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(lbl)
	_prompt_label = lbl
	_prompt_panel.visible = false


func _update_prompt() -> void:
	var pl: Node = _player()
	if pl == null or _prompt_panel == null:
		return
	# While resting, show a recovery overlay instead of the prompt.
	if is_resting(pl):
		var q: String = rest_quality(pl)
		var hp: float = float(pl.get("hp")) if _has_prop(pl, "hp") else 0.0
		var mx: float = float(pl.get("max_hp")) if _has_prop(pl, "max_hp") else 1.0
		_prompt_label.text = "Resting at %s  HP %d/%d  (move to rise)" % [
			str(QUALITY.get(q, {}).get("label", "rest")), int(hp), int(mx)]
		_prompt_panel.visible = true
		return
	_near_spot = _find_rest_spot(pl)
	if bool(_near_spot.get("found", false)):
		_prompt_label.text = "[T] Rest -- %s" % str(_near_spot.get("name", "rest"))
		_prompt_panel.visible = true
	else:
		_prompt_panel.visible = false


## Nearest rest spot to the player: the innkeeper NPC (inn) or a campfire prop
## (hearth). Returns {found, quality, pos, name, dist}.
func _find_rest_spot(pl: Node) -> Dictionary:
	var best: Dictionary = {"found": false}
	var best_d: float = INF
	var here: Vector2 = _pos(pl)
	# Inn: the innkeeper NPC (node name / display name), radius 60.
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if not (n is Node2D):
			continue
		if not _is_innkeeper(n):
			continue
		var d: float = (n as Node2D).global_position.distance_to(here)
		if d < 60.0 and d < best_d:
			best_d = d
			best = {"found": true, "quality": "inn", "pos": (n as Node2D).global_position,
					"name": "The Ember Hearth", "dist": d}
	# Hearth: any campfire prop in the world, radius 48.
	for n: Node in _campfire_nodes():
		if not (n is Node2D):
			continue
		var d2: float = (n as Node2D).global_position.distance_to(here)
		if d2 < 48.0 and d2 < best_d:
			best_d = d2
			best = {"found": true, "quality": "hearth", "pos": (n as Node2D).global_position,
					"name": "the campfire", "dist": d2}
	return best


func _is_innkeeper(n: Node) -> bool:
	if str(n.name).to_lower().find("innkeeper") >= 0:
		return true
	var did: Variant = n.get("_id")
	if did != null and str(did) == "innkeeper":
		return true
	var dn: Variant = n.get("display_name")
	return dn != null and str(dn).to_lower().find("marta") >= 0


func _campfire_nodes() -> Array:
	var out: Array = []
	for grp: String in ["campfire", "campfires", "hearths", "rest_points"]:
		for n: Node in get_tree().get_nodes_in_group(grp):
			out.append(n)
	return out


# --- Input (T = rest when a spot is near) -----------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != REST_KEY:
		return
	var pl: Node = _player()
	if pl == null or _panel_blocking():
		return
	if is_resting(pl):
		get_viewport().set_input_as_handled()
		stop_rest(pl)
		_update_prompt()
		return
	var spot: Dictionary = _find_rest_spot(pl)
	if bool(spot.get("found", false)):
		get_viewport().set_input_as_handled()
		start_rest(pl, str(spot.get("quality", "inn")))
		_update_prompt()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui", "reputation_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- helpers ----------------------------------------------------------------

func _st(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _state.has(key):
		_state[key] = {"resting": false, "quality": "", "spot": Vector2.ZERO, "xp_mult": 1.0}
	return _state[key]


func _pos(actor: Object) -> Vector2:
	if actor is Node2D:
		return (actor as Node2D).global_position
	return Vector2.ZERO


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


# --- Env self-test / screenshot hooks ---------------------------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	# Park the player on the inn spot so the prompt/overlay reads on a screenshot.
	var spot: Dictionary = _find_rest_spot(pl)
	if not bool(spot.get("found", false)) and pl is Node2D:
		# No innkeeper found near spawn: pull the player to the innkeeper so the
		# rest UI can be demonstrated regardless of spawn point.
		for n: Node in get_tree().get_nodes_in_group("npcs"):
			if n is Node2D and _is_innkeeper(n):
				(pl as Node2D).global_position = (n as Node2D).global_position + Vector2(0.0, 22.0)
				break
	if not OS.get_environment("RH_REST").is_empty():
		_self_test(pl)
	# Show the resting overlay for the capture.
	if not is_resting(pl):
		start_rest(pl, "inn")
	_update_prompt()


func _self_test(pl: Node) -> void:
	print("[REST_TEST] ===== Raven Hollow resting self-test =====")
	var ss: Node = get_node_or_null("/root/StatusSystem")
	if _has_prop(pl, "hp") and _has_prop(pl, "max_hp"):
		pl.set("hp", maxf(1.0, float(pl.get("max_hp")) * 0.35))
	if _has_prop(pl, "mana") and _has_prop(pl, "max_mana"):
		pl.set("mana", maxf(0.0, float(pl.get("max_mana")) * 0.20))
	var hp0: float = float(pl.get("hp")) if _has_prop(pl, "hp") else -1.0
	var mp0: float = float(pl.get("mana")) if _has_prop(pl, "mana") else -1.0
	print("[REST_TEST] before rest: hp=%.1f/%.1f mana=%.1f/%.1f" % [
		hp0, float(pl.get("max_hp")), mp0, float(pl.get("max_mana"))])
	start_rest(pl, "inn")
	print("[REST_TEST] start_rest(inn): is_resting=%s quality=%s xp_mult=x%.2f" % [
		str(is_resting(pl)), rest_quality(pl), xp_multiplier(pl)])
	var buff_on: bool = ss != null and ss.has_method("has") and bool(ss.call("has", pl, "well_rested"))
	print("[REST_TEST] Well Rested buff applied via StatusSystem = %s" % str(buff_on))
	if buff_on and ss.has_method("list_effects"):
		for e: Variant in ss.call("list_effects", pl):
			if str((e as Dictionary).get("id", "")) == "well_rested":
				print("[REST_TEST]   buff: %s (kind=%s, %.0fs left)" % [
					str((e as Dictionary).get("name", "")), str((e as Dictionary).get("kind", "")),
					float((e as Dictionary).get("left", 0.0))])
	# Recover for ~3 simulated seconds (deterministic: drive _process by hand).
	for _i in range(180):
		_process(1.0 / 60.0)
	print("[REST_TEST] after ~3s rest: hp=%.1f/%.1f mana=%.1f/%.1f (recovered=%s)" % [
		float(pl.get("hp")), float(pl.get("max_hp")), float(pl.get("mana")), float(pl.get("max_mana")),
		str(float(pl.get("hp")) > hp0)])
	stop_rest(pl)
	print("[REST_TEST] stop_rest: is_resting=%s (buff lingers=%s)" % [
		str(is_resting(pl)),
		str(ss != null and ss.has_method("has") and bool(ss.call("has", pl, "well_rested")))])
	print("[REST_TEST] ===== self-test complete =====")
