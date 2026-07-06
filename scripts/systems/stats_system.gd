extends Node
## StatsSystem (autoload) — WoW-Classic primary attributes + derived stats for
## the seven playable classes (design/CHARACTER_STATS.md, BACKLOG #34).
##
## Five primaries — Stamina, Strength, Agility, Intellect, Spirit — are grown
## multiplicatively per level from per-class L1 bases in data/classes_stats.json
## (whose bases decompose class_defs.gd's hp/mana/mana_regen EXACTLY at L1), then
## summed with modifiers (gear / buffs / status effects) and converted to the
## derived values combat consumes: max_health, max_mana, attack_power,
## spell_power, crit_chance, armor, hp_regen, mana_regen.
##
## Actor-keyed registry. Every query is guarded: unregistered actors read 0.0 and
## modifier_bonus() reads only the modifier delta, so integration hooks in
## player.gd/combat never crash and never double-count the class-def base.
##
## API: register / apply_level / get_stat / get_derived / add_modifier /
## remove_modifier / modifier_bonus. Signal: stat_changed(actor, stat).
## Pure data + math, no scene code.

signal stat_changed(actor, stat)

const DATA_PATH := "res://data/classes_stats.json"

var _cfg: Dictionary = {}
var _primaries: Array = []
var _growth: Dictionary = {}
var _const: Dictionary = {}
var _classes: Dictionary = {}

## instance_id -> {"ref": WeakRef, "class_id": String, "level": int}
var _actors: Dictionary = {}
## source_key(String) -> {"iid": int, "stats": {stat_name: amount}}
var _mods: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("StatsSystem: cannot open %s" % DATA_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("StatsSystem: bad JSON in %s" % DATA_PATH)
		return
	_cfg = parsed
	_primaries = _cfg.get("primaries", [])
	_growth = _cfg.get("growth", {})
	_const = _cfg.get("constants", {})
	_classes = _cfg.get("classes", {})


func _c(key: String, dflt: float) -> float:
	return float(_const.get(key, dflt))


func max_level() -> int:
	return int(_c("max_level", 60.0))


# --- Registration -----------------------------------------------------------


## Register (or update) an actor. Idempotent: repeated calls just sync class/level.
func register(actor: Object, class_id: String, level: int = 1) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	var lv: int = clampi(level, 1, max_level())
	var rec: Dictionary = _actors.get(iid, {})
	var changed: bool = rec.is_empty() \
			or int(rec.get("level", 0)) != lv \
			or str(rec.get("class_id", "")) != class_id
	rec["ref"] = weakref(actor)
	rec["class_id"] = class_id
	rec["level"] = lv
	_actors[iid] = rec
	if changed:
		_emit_all(actor)


func is_registered(actor: Object) -> bool:
	return actor != null and _actors.has(actor.get_instance_id())


func unregister(actor: Object) -> void:
	if actor != null:
		_actors.erase(actor.get_instance_id())


## Update an actor's level (re-derives everything from the new level).
func apply_level(actor: Object, level: int) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	if not _actors.has(iid):
		return
	var lv: int = clampi(level, 1, max_level())
	if int(_actors[iid]["level"]) == lv:
		return
	_actors[iid]["level"] = lv
	_emit_all(actor)


func _emit_all(actor: Object) -> void:
	for s: Variant in _primaries:
		stat_changed.emit(actor, str(s))
	stat_changed.emit(actor, "level")


# --- Base attribute math (pure, level-scaled) -------------------------------


## Class base for one primary at a level, before modifiers. THE growth formula.
func base_primary(class_id: String, stat: String, level: int) -> float:
	var cls: Dictionary = _classes.get(class_id, _classes.get("warrior", {}))
	var base: Array = cls.get("base", [])
	var i: int = _primaries.find(stat)
	if i < 0 or i >= base.size():
		return 0.0
	var g: float = float(_growth.get(stat, 1.0))
	var lv: int = clampi(level, 1, max_level())
	return float(base[i]) * pow(g, float(lv - 1))


func base_primaries(class_id: String, level: int) -> Dictionary:
	var out: Dictionary = {}
	for s: Variant in _primaries:
		out[str(s)] = base_primary(class_id, str(s), level)
	return out


# --- Modifiers (gear / buffs / status effects) ------------------------------


## Add (or replace) a flat modifier to `stat` from `source`, for `actor`.
## `source` may be a String key or an Object (its instance id keys it). One
## (source, stat) pair per entry; re-adding the same pair overwrites it, which
## is how status stacks refresh cleanly.
func add_modifier(actor: Object, source: Variant, stat: String, amount: float) -> void:
	if actor == null:
		return
	var key: String = _src_key(source)
	var rec: Dictionary = _mods.get(key, {"iid": actor.get_instance_id(), "stats": {}})
	rec["iid"] = actor.get_instance_id()
	(rec["stats"] as Dictionary)[stat] = amount
	_mods[key] = rec
	stat_changed.emit(actor, stat)


## Remove every stat entry contributed by `source`.
func remove_modifier(source: Variant) -> void:
	var key: String = _src_key(source)
	if not _mods.has(key):
		return
	var rec: Dictionary = _mods[key]
	var iid: int = int(rec.get("iid", 0))
	var actor: Object = instance_from_id(iid) if iid != 0 else null
	_mods.erase(key)
	if actor != null and is_instance_valid(actor):
		for stat: Variant in (rec.get("stats", {}) as Dictionary):
			stat_changed.emit(actor, str(stat))


func _modifier_sum(iid: int, stat: String) -> float:
	var total: float = 0.0
	for key: Variant in _mods:
		var rec: Dictionary = _mods[key]
		if int(rec.get("iid", 0)) == iid:
			total += float((rec.get("stats", {}) as Dictionary).get(stat, 0.0))
	return total


func _src_key(source: Variant) -> String:
	if source is String:
		return source
	if source is Object and is_instance_valid(source):
		return "obj:%d" % (source as Object).get_instance_id()
	return str(source)


# --- Queries ----------------------------------------------------------------


## Effective value of a primary (base + modifiers). Non-primary keys read their
## flat modifier pool. 0.0 for unregistered actors.
func get_stat(actor: Object, name: String) -> float:
	if actor == null or not _actors.has(actor.get_instance_id()):
		return 0.0
	var iid: int = actor.get_instance_id()
	var rec: Dictionary = _actors[iid]
	var base: float = 0.0
	if _primaries.has(name):
		base = base_primary(str(rec["class_id"]), name, int(rec["level"]))
	return base + _modifier_sum(iid, name)


func _eff_primaries(iid: int, rec: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var cid: String = str(rec["class_id"])
	var lv: int = int(rec["level"])
	for s: Variant in _primaries:
		out[str(s)] = base_primary(cid, str(s), lv) + _modifier_sum(iid, str(s))
	return out


## Derived stat from effective primaries. Names: max_health / max_mana /
## attack_power / spell_power / flat_damage / crit_chance / armor / hp_regen /
## mana_regen / regen / speed_pct. Unknown names fall back to the flat mod pool.
func get_derived(actor: Object, name: String) -> float:
	if actor == null or not _actors.has(actor.get_instance_id()):
		return 0.0
	var iid: int = actor.get_instance_id()
	var rec: Dictionary = _actors[iid]
	var cid: String = str(rec["class_id"])
	var lv: int = int(rec["level"])
	var p: Dictionary = _eff_primaries(iid, rec)
	var cls: Dictionary = _classes.get(cid, {})
	match name:
		"max_health", "max_hp":
			return _c("hp_floor", 30.0) + _c("hp_per_stamina", 10.0) * float(p["stamina"]) \
					+ _modifier_sum(iid, "hp")
		"max_mana":
			return _c("mana_floor", 20.0) + _c("mana_per_intellect", 10.0) * float(p["intellect"]) \
					+ _modifier_sum(iid, "mana")
		"attack_power":
			return _power(cls, p, ["strength", "agility"]) + _modifier_sum(iid, "attack_power")
		"spell_power":
			return _power(cls, p, ["intellect"]) + _modifier_sum(iid, "spell_power")
		"flat_damage":
			var cur: float = _power(cls, p, ["strength", "agility", "intellect"])
			var base_p: float = _base_power(cid, cls)
			return maxf(0.0, cur - base_p) / _c("ap_per_flat_damage", 2.0) + _modifier_sum(iid, "damage")
		"crit_chance", "crit_pct":
			var key: String = str(cls.get("crit_primary", "agility"))
			return float(p.get(key, 0.0)) / _c("crit_divisor", 20.0) + _modifier_sum(iid, "crit_pct")
		"armor":
			return floorf(float(p["agility"]) / _c("armor_per_agility", 20.0)) + _modifier_sum(iid, "armor")
		"mana_regen":
			return _c("mana_regen_per_spirit", 0.5) * float(p["spirit"]) + _modifier_sum(iid, "mana_regen")
		"hp_regen", "regen":
			return float(cls.get("hp_regen", 0.0)) * _spirit_ratio(cid, lv, p)
		"speed_pct":
			return _modifier_sum(iid, "speed_pct")
		_:
			return _modifier_sum(iid, name)


func _power(cls: Dictionary, p: Dictionary, keys: Array) -> float:
	var w: Dictionary = cls.get("ap_weights", {})
	var ap: float = 0.0
	for k: Variant in keys:
		ap += float(w.get(k, 0.0)) * float(p.get(k, 0.0))
	return ap


func _base_power(cid: String, cls: Dictionary) -> float:
	var w: Dictionary = cls.get("ap_weights", {})
	var ap: float = 0.0
	for k: Variant in w:
		ap += float(w[k]) * base_primary(cid, str(k), 1)
	return ap


func _spirit_ratio(cid: String, lv: int, p: Dictionary) -> float:
	var b: float = base_primary(cid, "spirit", lv)
	if b <= 0.0:
		return 1.0
	return maxf(0.25, float(p.get("spirit", b)) / b)


# --- Integration convenience ------------------------------------------------


## ONLY the delta a derived value gains from modifiers (statuses/buffs), so
## player.gd can add it on top of its own class-def base without double-counting
## the base primaries. Works with or without register() (0 when no modifiers).
func modifier_bonus(actor: Object, derived_name: String) -> float:
	if actor == null:
		return 0.0
	var iid: int = actor.get_instance_id()
	match derived_name:
		"max_health", "max_hp":
			return _modifier_sum(iid, "stamina") * _c("hp_per_stamina", 10.0) + _modifier_sum(iid, "hp")
		"max_mana":
			return _modifier_sum(iid, "intellect") * _c("mana_per_intellect", 10.0) + _modifier_sum(iid, "mana")
		"mana_regen":
			return _modifier_sum(iid, "spirit") * _c("mana_regen_per_spirit", 0.5) + _modifier_sum(iid, "mana_regen")
		"crit_chance", "crit_pct":
			return _modifier_sum(iid, "crit_pct")
		"armor":
			return _modifier_sum(iid, "armor")
		"speed_pct":
			return _modifier_sum(iid, "speed_pct")
		_:
			return _modifier_sum(iid, derived_name)


## Full 7-class x 5-primary table at a level (audits / debug dumps).
func growth_table(level: int) -> Dictionary:
	var out: Dictionary = {}
	for cid: Variant in _classes:
		out[str(cid)] = base_primaries(str(cid), level)
	return out
