extends Node
## ClassKitSystem -- autoload (/root/ClassKitSystem). Build #82 + #83
## "class kit reworks: Rogue (stealth/dagger-poison/vanish/assassinate) +
## Druid (CAT & BEAR forms)".
##
## Two combat kits load from data/class_kits.json:
##   ROGUE -- enter/exit STEALTH (a move-speed + stealth-rating swing on the
##     StatsSystem bus), a dagger POISON DoT (rides the existing StatusSystem
##     'poison' effect, with a stat-mod fallback), VANISH (breaks combat + a
##     brief invisibility that also re-stealths), and ASSASSINATE (a from-stealth
##     damage multiplier -- the opener bonus).
##   DRUID -- shape SHIFTING between CASTER / CAT / BEAR forms. Each form is a
##     reversible StatsSystem modifier-set (a whole stat PROFILE applied under one
##     source key and wiped clean on the next shift), a swapped ability bar
##     (carried as data for the action-bar UI), and a modulate tint placeholder
##     standing in for the Fable transform art.
##
## Every write is guarded and additive: no other system's file is edited
## (StatsSystem + StatusSystem are READ / called only, both looked up with
## get_node_or_null so this degrades to no-ops when they are absent). A null actor
## is always a no-op. A tiny code-built CanvasLayer pip echoes the player's
## current form / stealth state (placeholder for the Fable HUD art).
##
## Public API (actor = any Node; the player is group "player"):
##   enter_stealth(actor) -> bool / exit_stealth(actor) -> bool
##   is_stealthed(actor) -> bool
##   apply_poison(actor, target) -> bool        dagger poison DoT on a target
##   vanish(actor) -> bool                       break combat + brief invis + restealth
##   assassinate(actor, target, base_damage := 0.0) -> Dictionary
##   shift_form(actor, form) -> bool             "cat" | "bear" | "caster"
##   current_form(actor) -> String
##   form_abilities(actor) -> Array              the swapped ability bar
##   kit_for(class_id) -> Dictionary / has_kit(class_id) -> bool
## Signals:
##   stealth_changed(actor, active)
##   form_changed(actor, form, prev_form)
##   poison_applied(actor, target)
##   assassinate_fired(actor, target, result)

signal stealth_changed(actor, active)
signal form_changed(actor, form, prev_form)
signal poison_applied(actor, target)
signal assassinate_fired(actor, target, result)

const DATA_PATH := "res://data/class_kits.json"
const STEALTH_SRC := "classkit_stealth"
const FORM_SRC := "classkit_form"
const POISON_FALLBACK_SRC := "classkit_poison"

var _kits: Dictionary = {}          # class_id -> kit def

## instance_id -> {stealthed:bool, form:String, invis_left:float,
##                 orig_modulate:Color, has_orig:bool}
var _actors: Dictionary = {}

var _indicator: CanvasLayer = null
var _indicator_label: Label = null


func _ready() -> void:
	_load_data()
	set_process(true)
	_build_indicator()
	if not OS.get_environment("RH_CLASSKIT_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_kits = _dict(root.get("kits", {}))
	if _kits.is_empty():
		push_warning("ClassKitSystem: no kits loaded from %s" % DATA_PATH)


# --- Kit queries ------------------------------------------------------------

func has_kit(class_id: String) -> bool:
	return _kits.has(class_id)


func kit_for(class_id: String) -> Dictionary:
	return _dict(_kits.get(class_id, {}))


func _actor_kit(actor: Node) -> Dictionary:
	return kit_for(_class_id(actor))


# --- Rogue: stealth ---------------------------------------------------------

func is_stealthed(actor: Node) -> bool:
	return actor != null and bool(_state(actor).get("stealthed", false))


func enter_stealth(actor: Node) -> bool:
	if actor == null:
		return false
	var st: Dictionary = _state(actor)
	if bool(st.get("stealthed", false)):
		return false
	var kit: Dictionary = _actor_kit(actor)
	var s: Dictionary = _dict(kit.get("stealth", {}))
	var src: String = _src(STEALTH_SRC, actor)
	_stat_clear(src)
	_stat_add(actor, src, "speed_pct", float(s.get("speed_pct", -30.0)))
	# Stealth rating is stored on the mod bus so a detection check can read it.
	_stat_add(actor, src, "stealth_rating", float(s.get("stealth_rating", 40.0)))
	st["stealthed"] = true
	_apply_tint(actor, s.get("modulate", [0.55, 0.58, 0.72, 0.55]))
	stealth_changed.emit(actor, true)
	_refresh_indicator(actor)
	return true


func exit_stealth(actor: Node) -> bool:
	if actor == null:
		return false
	var st: Dictionary = _state(actor)
	if not bool(st.get("stealthed", false)):
		return false
	_stat_clear(_src(STEALTH_SRC, actor))
	st["stealthed"] = false
	st["invis_left"] = 0.0
	# Fall back to the current form's tint (or the original modulate).
	_restore_form_tint(actor)
	stealth_changed.emit(actor, false)
	_refresh_indicator(actor)
	return true


# --- Rogue: dagger poison ---------------------------------------------------

func apply_poison(actor: Node, target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var kit: Dictionary = _actor_kit(actor)
	var p: Dictionary = _dict(kit.get("poison", {}))
	var status_id: String = str(p.get("status", "poison"))
	var stacks: int = int(p.get("stacks", 1))
	var applied: bool = false
	var ss: Node = _status()
	if ss != null and ss.has_method("get_def") and ss.has_method("apply"):
		if not _dict(ss.call("get_def", status_id)).is_empty():
			applied = bool(ss.call("apply", target, status_id, actor, maxi(1, stacks)))
	if not applied:
		# Fallback: a plain slowing debuff on the StatsSystem bus (no DoT engine).
		var fb: Dictionary = _dict(p.get("fallback", {}))
		var src: String = _src(POISON_FALLBACK_SRC, target)
		_stat_clear(src)
		for stat: Variant in fb:
			_stat_add(target, src, str(stat), float(fb[stat]))
		applied = not fb.is_empty()
	if applied:
		poison_applied.emit(actor, target)
	return applied


# --- Rogue: vanish ----------------------------------------------------------

func vanish(actor: Node) -> bool:
	if actor == null:
		return false
	var kit: Dictionary = _actor_kit(actor)
	var v: Dictionary = _dict(kit.get("vanish", {}))
	var st: Dictionary = _state(actor)
	# Break combat: announce a drop (a combat/aggro system can read this signal).
	if bool(v.get("break_combat", true)):
		st["in_combat"] = false
	# Re-stealth (classic vanish restealths even mid-fight).
	if bool(v.get("restealth", true)) and not bool(st.get("stealthed", false)):
		var src: String = _src(STEALTH_SRC, actor)
		var s: Dictionary = _dict(kit.get("stealth", {}))
		_stat_clear(src)
		_stat_add(actor, src, "speed_pct", float(s.get("speed_pct", -30.0)))
		_stat_add(actor, src, "stealth_rating", float(s.get("stealth_rating", 40.0)))
		st["stealthed"] = true
		stealth_changed.emit(actor, true)
	# Brief invisibility (a deeper tint fade; timed out in _process).
	st["invis_left"] = float(v.get("invis_duration", 3.0))
	_apply_tint(actor, v.get("modulate", [0.45, 0.48, 0.62, 0.28]))
	_refresh_indicator(actor)
	return true


# --- Rogue: assassinate -----------------------------------------------------

## Fire an assassinate. When the actor is stealthed the opener multiplier applies
## (the bonus). Deals to `target` if it exposes take_damage. Breaks stealth after.
func assassinate(actor: Node, target: Node, base_damage: float = 0.0) -> Dictionary:
	var res: Dictionary = {"fired": false, "damage": 0.0, "from_stealth": false, "mult": 1.0, "base": 0.0}
	if actor == null:
		return res
	var kit: Dictionary = _actor_kit(actor)
	var a: Dictionary = _dict(kit.get("assassinate", {}))
	var from_stealth: bool = is_stealthed(actor)
	var mult: float = float(a.get("open_mult", 2.5)) if from_stealth else float(a.get("normal_mult", 1.0))
	var base: float = base_damage
	if base <= 0.0:
		base = _derive_base_damage(actor, float(a.get("base_damage", 24.0)))
	var dmg: float = base * mult
	if target != null and is_instance_valid(target) and target.has_method("take_damage") and dmg > 0.0:
		target.call("take_damage", dmg, actor)
	if from_stealth and bool(a.get("breaks_stealth", true)):
		exit_stealth(actor)
	res = {"fired": true, "damage": dmg, "from_stealth": from_stealth, "mult": mult, "base": base}
	assassinate_fired.emit(actor, target, res)
	return res


func _derive_base_damage(actor: Node, dflt: float) -> float:
	var ss: Node = _stats()
	if ss != null and ss.has_method("is_registered") and ss.has_method("get_derived") \
			and bool(ss.call("is_registered", actor)):
		var ap: float = float(ss.call("get_derived", actor, "attack_power"))
		if ap > 0.0:
			return ap
	return dflt


# --- Druid: form shifting ---------------------------------------------------

func current_form(actor: Node) -> String:
	if actor == null:
		return "caster"
	return str(_state(actor).get("form", _default_form(actor)))


func form_abilities(actor: Node) -> Array:
	var kit: Dictionary = _actor_kit(actor)
	var forms: Dictionary = _dict(kit.get("forms", {}))
	var f: Dictionary = _dict(forms.get(current_form(actor), {}))
	return _arr(f.get("abilities", [])).duplicate()


## Shift the actor into `form` ("cat" | "bear" | "caster"). Wipes the previous
## form's modifier-set clean and applies the new profile under one source key,
## swaps the ability bar, and re-tints. Returns false for a null actor / unknown
## form / a class with no druid kit.
func shift_form(actor: Node, form: String) -> bool:
	if actor == null:
		return false
	var kit: Dictionary = _actor_kit(actor)
	var forms: Dictionary = _dict(kit.get("forms", {}))
	if not forms.has(form):
		return false
	var st: Dictionary = _state(actor)
	var prev: String = str(st.get("form", _default_form(actor)))
	# Reversible profile swap: one source key, fully cleared then re-applied.
	var src: String = _src(FORM_SRC, actor)
	_stat_clear(src)
	var profile: Dictionary = _dict(_dict(forms.get(form, {})).get("profile", {}))
	for stat: Variant in profile:
		_stat_add(actor, src, str(stat), float(profile[stat]))
	st["form"] = form
	_apply_tint(actor, _dict(forms.get(form, {})).get("modulate", [1.0, 1.0, 1.0, 1.0]))
	form_changed.emit(actor, form, prev)
	_refresh_indicator(actor)
	return true


func _default_form(actor: Node) -> String:
	return str(_actor_kit(actor).get("default_form", "caster"))


# --- Invisibility timeout ---------------------------------------------------

func _process(delta: float) -> void:
	if _actors.is_empty():
		return
	for iid: Variant in _actors.keys():
		var st: Dictionary = _actors[iid]
		var left: float = float(st.get("invis_left", 0.0))
		if left <= 0.0:
			continue
		left -= delta
		st["invis_left"] = left
		if left <= 0.0:
			var actor: Object = instance_from_id(int(iid))
			if actor is Node and is_instance_valid(actor):
				# Invis lapses; stay in whatever stealth/form tint still holds.
				if bool(st.get("stealthed", false)):
					var s: Dictionary = _dict(_actor_kit(actor as Node).get("stealth", {}))
					_apply_tint(actor as Node, s.get("modulate", [0.55, 0.58, 0.72, 0.55]))
				else:
					_restore_form_tint(actor as Node)
				_refresh_indicator(actor as Node)


# --- StatsSystem / StatusSystem bus (guarded) -------------------------------

func _stats() -> Node:
	return get_node_or_null("/root/StatsSystem")


func _status() -> Node:
	return get_node_or_null("/root/StatusSystem")


func _stat_add(actor: Node, src: String, stat: String, amount: float) -> void:
	if absf(amount) < 0.0001:
		return
	var ss: Node = _stats()
	if ss != null and ss.has_method("add_modifier"):
		ss.call("add_modifier", actor, src, stat, amount)


func _stat_clear(src: String) -> void:
	var ss: Node = _stats()
	if ss != null and ss.has_method("remove_modifier"):
		ss.call("remove_modifier", src)


func _src(prefix: String, actor: Node) -> String:
	return "%s:%d" % [prefix, actor.get_instance_id() if actor != null else 0]


# --- Tint placeholder (Fable transform / stealth art hook) ------------------

func _apply_tint(actor: Node, rgba: Variant) -> void:
	if not (actor is CanvasItem):
		return
	var st: Dictionary = _state(actor)
	if not bool(st.get("has_orig", false)):
		st["orig_modulate"] = (actor as CanvasItem).modulate
		st["has_orig"] = true
	(actor as CanvasItem).modulate = _color(rgba)


func _restore_form_tint(actor: Node) -> void:
	if not (actor is CanvasItem):
		return
	var forms: Dictionary = _dict(_actor_kit(actor).get("forms", {}))
	var f: Dictionary = _dict(forms.get(current_form(actor), {}))
	if f.has("modulate"):
		(actor as CanvasItem).modulate = _color(f.get("modulate"))
		return
	var st: Dictionary = _state(actor)
	if bool(st.get("has_orig", false)):
		(actor as CanvasItem).modulate = st.get("orig_modulate", Color(1, 1, 1, 1))
	else:
		(actor as CanvasItem).modulate = Color(1, 1, 1, 1)


# --- State HUD pip (code-built CanvasLayer; placeholder for Fable HUD) -------

func _build_indicator() -> void:
	_indicator = CanvasLayer.new()
	_indicator.layer = 90
	_indicator.name = "ClassKitIndicator"
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -70.0
	panel.offset_right = 70.0
	panel.offset_top = 34.0
	panel.offset_bottom = 60.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_label = Label.new()
	_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicator_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62))
	panel.add_child(_indicator_label)
	_indicator.add_child(panel)
	_indicator.visible = false
	add_child(_indicator)


func _refresh_indicator(actor: Node) -> void:
	# Only mirror the player's state (fake selftest dummies never show a pip).
	if _indicator == null or not is_instance_valid(_indicator):
		return
	var pl: Node = _player()
	if actor == null or actor != pl:
		return
	var parts: Array = []
	if is_stealthed(actor):
		parts.append("STEALTH")
	var form: String = current_form(actor)
	if form != _default_form(actor):
		var forms: Dictionary = _dict(_actor_kit(actor).get("forms", {}))
		parts.append(str(_dict(forms.get(form, {})).get("name", form)).to_upper())
	if parts.is_empty():
		_indicator.visible = false
	else:
		_indicator_label.text = "  ".join(parts)
		_indicator.visible = true


# --- state / helpers --------------------------------------------------------

func _state(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _actors.has(key):
		_actors[key] = {
			"stealthed": false, "form": _default_form(actor), "invis_left": 0.0,
			"orig_modulate": Color(1, 1, 1, 1), "has_orig": false, "in_combat": false,
		}
	return _actors[key]


func _class_id(actor: Node) -> String:
	if actor == null:
		return ""
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary and (cd as Dictionary).has("id"):
		return str((cd as Dictionary)["id"])
	var ci: Variant = actor.get("class_id")
	if ci is String and ci != "":
		return ci
	return ""


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var alpha: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(1, 1, 1, 1)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("ClassKitSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Fake actor for the deterministic self-test -----------------------------

class _KitDummy:
	extends Node2D
	var class_def: Dictionary = {}
	var speed: float = 100.0
	var hp: float = 100.0
	var max_hp: float = 100.0
	var last_damage: float = 0.0
	func take_damage(amount: float, _src: Object = null) -> void:
		last_damage = amount
		hp = maxf(0.0, hp - amount)


# --- Self-test (RH_CLASSKIT_TEST=1) -----------------------------------------

func _run_selftest() -> void:
	var rogue_ok: bool = _selftest_rogue()
	var druid_ok: bool = _selftest_druid()
	var verdict: String = "PASS" if (rogue_ok and druid_ok) else "FAIL"
	print("CLASSKIT SELFTEST %s rogue=%s druid=%s" % [verdict, str(rogue_ok), str(druid_ok)])


func _selftest_rogue() -> bool:
	var ss: Node = _stats()
	var rog := _KitDummy.new()
	rog.class_def = {"id": "rogue"}
	add_child(rog)
	var ok: bool = true

	# 1) Stealth applies a real speed_pct swing on the StatsSystem bus.
	var speed_before: float = _mod_bonus(ss, rog, "speed_pct")
	var entered: bool = enter_stealth(rog)
	var speed_after: float = _mod_bonus(ss, rog, "speed_pct")
	var want_speed: float = float(_dict(kit_for("rogue").get("stealth", {})).get("speed_pct", -30.0))
	var stealth_ok: bool = entered and is_stealthed(rog) and is_equal_approx(speed_after - speed_before, want_speed)
	print("[CLASSKIT] rogue stealth: speed_pct %.0f -> %.0f (delta %.0f, want %.0f) stealthed=%s" % [
			speed_before, speed_after, speed_after - speed_before, want_speed, str(is_stealthed(rog))])
	ok = ok and stealth_ok

	# 2) Assassinate from stealth carries the opener multiplier (the bonus).
	var tgt := _KitDummy.new()
	add_child(tgt)
	var res: Dictionary = assassinate(rog, tgt, 20.0)
	var open_mult: float = float(_dict(kit_for("rogue").get("assassinate", {})).get("open_mult", 2.5))
	var assn_ok: bool = bool(res.get("fired", false)) and bool(res.get("from_stealth", false)) \
			and is_equal_approx(float(res.get("mult", 0.0)), open_mult) \
			and is_equal_approx(float(res.get("damage", 0.0)), 20.0 * open_mult) \
			and is_equal_approx(tgt.last_damage, 20.0 * open_mult)
	print("[CLASSKIT] rogue assassinate: base=20 mult=%.1f dmg=%.1f from_stealth=%s (breaks_stealth -> stealthed=%s)" % [
			float(res.get("mult", 0.0)), float(res.get("damage", 0.0)),
			str(res.get("from_stealth", false)), str(is_stealthed(rog))])
	ok = ok and assn_ok

	# 3) Poison lands as a StatusSystem effect, or the stat-mod fallback.
	var pos: bool = apply_poison(rog, tgt)
	var status_ok: bool = false
	var ss2: Node = _status()
	if ss2 != null and ss2.has_method("has"):
		status_ok = bool(ss2.call("has", tgt, "poison"))
	var fallback_ok: bool = absf(_mod_bonus(ss, tgt, "speed_pct")) > 0.0001
	var poison_ok: bool = pos and (status_ok or fallback_ok)
	print("[CLASSKIT] rogue poison: applied=%s status_effect=%s fallback_mod=%s" % [
			str(pos), str(status_ok), str(fallback_ok)])
	ok = ok and poison_ok

	# 4) Vanish re-stealths + arms invis.
	exit_stealth(rog)
	var van: bool = vanish(rog)
	var vanish_ok: bool = van and is_stealthed(rog)
	print("[CLASSKIT] rogue vanish: restealthed=%s invis_armed=%s" % [
			str(is_stealthed(rog)), str(float(_state(rog).get("invis_left", 0.0)) > 0.0)])
	ok = ok and vanish_ok

	rog.queue_free()
	tgt.queue_free()
	return ok


func _selftest_druid() -> bool:
	var ss: Node = _stats()
	var dru := _KitDummy.new()
	dru.class_def = {"id": "druid"}
	add_child(dru)
	var ok: bool = true

	# CAT: agility + speed profile applies.
	var cat: bool = shift_form(dru, "cat")
	var cat_agi: float = _mod_bonus(ss, dru, "agility")
	var cat_spd: float = _mod_bonus(ss, dru, "speed_pct")
	var want_cat_agi: float = float(_form_profile("cat").get("agility", 0.0))
	var cat_ok: bool = cat and current_form(dru) == "cat" and is_equal_approx(cat_agi, want_cat_agi)
	print("[CLASSKIT] druid CAT: agility=%.0f (want %.0f) speed_pct=%.0f form=%s" % [
			cat_agi, want_cat_agi, cat_spd, current_form(dru)])
	ok = ok and cat_ok

	# BEAR: profile swaps cleanly (cat's agility gone, bear's armor in).
	var bear: bool = shift_form(dru, "bear")
	var bear_armor: float = _mod_bonus(ss, dru, "armor")
	var bear_agi: float = _mod_bonus(ss, dru, "agility")
	var want_bear_armor: float = float(_form_profile("bear").get("armor", 0.0))
	var bear_ok: bool = bear and current_form(dru) == "bear" \
			and is_equal_approx(bear_armor, want_bear_armor) and is_equal_approx(bear_agi, 0.0)
	print("[CLASSKIT] druid BEAR: armor=%.0f (want %.0f) agility=%.0f (cat reverted -> 0) form=%s" % [
			bear_armor, want_bear_armor, bear_agi, current_form(dru)])
	ok = ok and bear_ok

	# CASTER: reverts to baseline -- every form mod cleared.
	var caster: bool = shift_form(dru, "caster")
	var c_armor: float = _mod_bonus(ss, dru, "armor")
	var c_agi: float = _mod_bonus(ss, dru, "agility")
	var c_spd: float = _mod_bonus(ss, dru, "speed_pct")
	var caster_ok: bool = caster and current_form(dru) == "caster" \
			and is_equal_approx(c_armor, 0.0) and is_equal_approx(c_agi, 0.0) and is_equal_approx(c_spd, 0.0)
	print("[CLASSKIT] druid CASTER: armor=%.0f agility=%.0f speed_pct=%.0f (all revert to 0) form=%s" % [
			c_armor, c_agi, c_spd, current_form(dru)])
	print("[CLASSKIT] druid bar swaps: cat=%s bear=%s" % [
			str(_form_abilities_of("cat")), str(_form_abilities_of("bear"))])
	ok = ok and caster_ok

	dru.queue_free()
	return ok


func _form_profile(form: String) -> Dictionary:
	return _dict(_dict(_dict(kit_for("druid").get("forms", {})).get(form, {})).get("profile", {}))


func _form_abilities_of(form: String) -> Array:
	return _arr(_dict(_dict(kit_for("druid").get("forms", {})).get(form, {})).get("abilities", []))


func _mod_bonus(ss: Node, actor: Node, stat: String) -> float:
	if ss != null and ss.has_method("modifier_bonus"):
		return float(ss.call("modifier_bonus", actor, stat))
	return 0.0
