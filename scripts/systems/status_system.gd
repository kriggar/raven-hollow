extends Node
## StatusSystem (autoload) — buff / debuff / disease framework for Raven Hollow
## (design/STATUS_EFFECTS.md, BACKLOG #35).
##
## Effect definitions live in data/status_effects.json. Each effect carries a
## kind (buff / debuff / disease), a dispel_type, a duration, an optional
## tick_interval (DoT/HoT), stacking rules, on_apply stat modifiers (routed
## through StatsSystem.add_modifier so e.g. Infected's -1 Stamina becomes
## -10 max health), on_tick damage/heal, and an optional threshold proc-chain.
##
## The seeded catalog includes the canon disease chain: three wolf bites raise
## `wolf_bite` to 3 stacks, tripping its threshold -> the stacks clear and the
## victim becomes `infected` (disease, -1 Stamina) until it expires or is cured.
##
## Actor-keyed and fully guarded: an actor with no effects registers nothing, a
## host without take_tick_damage/take_damage simply takes no tick damage, and a
## null/freed host is pruned. tick(delta) is driven from _process, and is also
## callable directly (deterministic self-test).
##
## API: apply / remove / has / stacks / list_effects / tick.
## Signals: status_applied(actor, effect_id), status_removed(actor, effect_id).

signal status_applied(actor, effect_id)
signal status_removed(actor, effect_id)

const DATA_PATH := "res://data/status_effects.json"

var _defs: Dictionary = {}
## instance_id -> {"ref": WeakRef, "effects": {effect_id: instance}}
## instance: {"stacks": int, "left": float, "tick_t": float, "potency": float, "src_iid": int}
var _actors: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("StatusSystem: cannot open %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_defs = d.get("effects", d)
	else:
		push_error("StatusSystem: bad JSON in %s" % DATA_PATH)


func get_def(id: String) -> Dictionary:
	return _defs.get(id, {})


func _process(delta: float) -> void:
	tick(delta)


# --- Application ------------------------------------------------------------


## Apply (or stack/refresh) `effect_id` on `actor`. `source` (optional) supplies
## tick potency (its `damage` stat). Returns false for unknown effect / null host.
func apply(actor: Object, effect_id: String, source: Object = null, stacks: int = 1) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var def: Dictionary = _defs.get(effect_id, {})
	if def.is_empty():
		push_warning("StatusSystem.apply: unknown effect '%s'" % effect_id)
		return false
	var iid: int = actor.get_instance_id()
	var rec: Dictionary = _actors.get(iid, {"ref": weakref(actor), "effects": {}})
	rec["ref"] = weakref(actor)
	var effects: Dictionary = rec["effects"]
	var potency: float = _potency(source)
	var src_iid: int = source.get_instance_id() if (source is Object and is_instance_valid(source)) else 0
	var stack_max: int = int(def.get("stack_max", 1))
	var newly: bool = false
	if effects.has(effect_id):
		var inst: Dictionary = effects[effect_id]
		match str(def.get("stack_rule", "refresh")):
			"add":
				inst["stacks"] = mini(int(inst["stacks"]) + maxi(1, stacks), stack_max)
				inst["left"] = float(def.get("duration", 0.0))
			"add_time":
				inst["left"] = minf(float(inst["left"]) + float(def.get("duration", 0.0)),
						2.0 * float(def.get("duration", 0.0)))
			_:
				inst["left"] = float(def.get("duration", 0.0))
		inst["potency"] = maxf(float(inst["potency"]), potency)
		inst["src_iid"] = src_iid
	else:
		effects[effect_id] = {
			"stacks": clampi(maxi(1, stacks), 1, stack_max),
			"left": float(def.get("duration", 0.0)),
			"tick_t": float(def.get("tick_interval", 0.0)),
			"potency": potency,
			"src_iid": src_iid,
		}
		newly = true
	_actors[iid] = rec
	# (Re)apply on_apply stat modifiers, scaled by current stacks.
	_apply_stat_mods(actor, effect_id, def, int(effects[effect_id]["stacks"]))
	if newly:
		status_applied.emit(actor, effect_id)
	_notify_host(actor)
	# Threshold proc-chain (the wolf_bite -> infected canon).
	var th: Dictionary = def.get("threshold", {})
	if not th.is_empty() and int(effects[effect_id]["stacks"]) >= int(th.get("at", 999)):
		var next_id: String = str(th.get("apply", ""))
		if th.get("clear", true):
			remove(actor, effect_id)
		if next_id != "":
			apply(actor, next_id, source)
	return true


func remove(actor: Object, effect_id: String) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	if not _actors.has(iid):
		return
	var effects: Dictionary = _actors[iid]["effects"]
	if not effects.has(effect_id):
		return
	_clear_stat_mods(effect_id, iid)
	effects.erase(effect_id)
	if is_instance_valid(actor):
		status_removed.emit(actor, effect_id)
		_notify_host(actor)


func has(actor: Object, effect_id: String) -> bool:
	if actor == null:
		return false
	var iid: int = actor.get_instance_id()
	return _actors.has(iid) and (_actors[iid]["effects"] as Dictionary).has(effect_id)


func stacks(actor: Object, effect_id: String) -> int:
	if not has(actor, effect_id):
		return 0
	return int(_actors[actor.get_instance_id()]["effects"][effect_id]["stacks"])


## HUD/debug contract: visible effects on an actor, buffs first.
func list_effects(actor: Object) -> Array:
	var out: Array = []
	if actor == null or not _actors.has(actor.get_instance_id()):
		return out
	var effects: Dictionary = _actors[actor.get_instance_id()]["effects"]
	for eid: Variant in effects:
		var d: Dictionary = _defs.get(str(eid), {})
		var inst: Dictionary = effects[eid]
		out.append({
			"id": str(eid), "name": str(d.get("name", eid)),
			"kind": str(d.get("kind", "debuff")),
			"dispel": str(d.get("dispel_type", "none")),
			"stacks": int(inst["stacks"]), "left": float(inst["left"]),
			"duration": float(d.get("duration", 0.0)),
			"icon_hint": str(d.get("icon_hint", "")),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["kind"]) < str(b["kind"]))
	return out


## Remove every debuff of one dispel school (cure potions, shrine, healer NPC).
func purge(actor: Object, dispel_type: String) -> int:
	if actor == null or not _actors.has(actor.get_instance_id()):
		return 0
	var effects: Dictionary = _actors[actor.get_instance_id()]["effects"]
	var n: int = 0
	for eid: Variant in effects.keys().duplicate():
		var d: Dictionary = _defs.get(str(eid), {})
		if str(d.get("kind", "")) != "buff" and str(d.get("dispel_type", "none")) == dispel_type:
			remove(actor, str(eid))
			n += 1
	return n


# --- Ticking ----------------------------------------------------------------


## Advance all effects on all actors by `delta`. Called from _process and
## directly (self-test). Expires elapsed effects, runs DoT/HoT ticks.
func tick(delta: float) -> void:
	for iid: Variant in _actors.keys().duplicate():
		var rec: Dictionary = _actors[iid]
		var actor: Object = (rec["ref"] as WeakRef).get_ref()
		if actor == null or not is_instance_valid(actor):
			_actors.erase(iid)
			continue
		if actor.get("_dead") == true or actor.get("is_dead") == true:
			continue
		var effects: Dictionary = rec["effects"]
		for eid: Variant in effects.keys().duplicate():
			var inst: Dictionary = effects[eid]
			var def: Dictionary = _defs.get(str(eid), {})
			var dur: float = float(def.get("duration", 0.0))
			if dur > 0.0:
				inst["left"] = float(inst["left"]) - delta
				if float(inst["left"]) <= 0.0:
					_clear_stat_mods(str(eid), int(iid))
					effects.erase(eid)
					status_removed.emit(actor, str(eid))
					_notify_host(actor)
					continue
			var iv: float = float(def.get("tick_interval", 0.0))
			if iv > 0.0:
				inst["tick_t"] = float(inst["tick_t"]) - delta
				if float(inst["tick_t"]) <= 0.0:
					inst["tick_t"] = float(inst["tick_t"]) + iv
					_run_tick(actor, def, inst)


func _run_tick(actor: Object, def: Dictionary, inst: Dictionary) -> void:
	var t: Dictionary = def.get("on_tick", {})
	if t.is_empty():
		return
	var st: float = float(int(inst["stacks"]))
	var dmg: float = float(t.get("damage_flat", 0.0)) * st \
			+ float(inst["potency"]) * float(t.get("damage_coeff", 0.0)) * st
	if dmg > 0.0:
		var src: Object = null
		var sid: int = int(inst.get("src_iid", 0))
		if sid != 0:
			src = instance_from_id(sid)
		_deal_tick_damage(actor, dmg, str(def.get("dispel_type", "none")), src)
	var heal: float = float(t.get("heal_flat", 0.0)) * st \
			+ float(inst["potency"]) * float(t.get("heal_coeff", 0.0)) * st
	if heal > 0.0:
		_heal(actor, heal)


func _deal_tick_damage(actor: Object, dmg: float, school: String, source: Object) -> void:
	if actor.has_method("take_tick_damage"):
		actor.call("take_tick_damage", dmg, school)
	elif actor.has_method("take_damage"):
		actor.call("take_damage", dmg, source)
	elif actor.get("hp") != null:
		actor.set("hp", maxf(0.0, float(actor.get("hp")) - dmg))


func _heal(actor: Object, amount: float) -> void:
	if actor.get("hp") != null and actor.get("max_hp") != null:
		actor.set("hp", minf(float(actor.get("max_hp")), float(actor.get("hp")) + amount))


# --- Stat modifiers (via StatsSystem) ---------------------------------------


func _apply_stat_mods(actor: Object, eid: String, def: Dictionary, stack_count: int) -> void:
	var mods: Dictionary = (def.get("on_apply", {}) as Dictionary).get("stat_mods", {})
	if mods.is_empty():
		return
	var base: String = "status:%s:%d" % [eid, actor.get_instance_id()]
	for stat: Variant in mods:
		StatsSystem.add_modifier(actor, "%s:%s" % [base, str(stat)],
				str(stat), float(mods[stat]) * float(stack_count))


func _clear_stat_mods(eid: String, iid: int) -> void:
	var mods: Dictionary = (_defs.get(eid, {}).get("on_apply", {}) as Dictionary).get("stat_mods", {})
	var base: String = "status:%s:%d" % [eid, iid]
	for stat: Variant in mods:
		StatsSystem.remove_modifier("%s:%s" % [base, str(stat)])


# --- Helpers ----------------------------------------------------------------


func _notify_host(actor: Object) -> void:
	## Let a host re-derive its maxima (picks up StatsSystem modifier bonuses).
	if actor.has_method("_apply_equipment"):
		actor.call("_apply_equipment")


func _potency(source: Object) -> float:
	if source != null and source is Object and is_instance_valid(source):
		var d: Variant = source.get("damage")
		if d != null:
			return float(d)
	return 0.0
