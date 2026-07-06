extends Node
## TalentSystem (autoload) — the 21-tree talent engine for Raven Hollow
## (design/TALENTS_SPELLS.md, BACKLOG #41). 3 lore-named trees x 7 classes,
## classic 31-point shape (7 tiers, 5-pts-per-tier gate, 1 capstone ability per
## tree). Pure data + math + per-actor build state; no scene code.
##
## Data lives in data/talents.json (generated from the design doc). Each talent:
##   {id, name, tier(1..7), col(0..2), max_ranks, requires, kind, per_rank, desc,
##    ability?}   kind = passive | proc | ability_mod | ability(capstone).
##
## Point rules (meta in the JSON):
##   - 1 talent point per level from 10..60 = 51 points.
##   - Tree tier N unlocks at 5*(N-1) points spent IN THAT TREE; the capstone
##     (tier 7) needs 30 in-tree points spent.
##   - grant_point() adds bonus points (quest / debug); reset() refunds all.
##
## Effects: on learn / reset the actor's UNCONDITIONAL passive stat-mods are
## (re)applied through StatsSystem.add_modifier (one source key per talent+stat),
## so armor/stamina/mana/crit_pct/... flow into the derived stats immediately.
## Conditional passives ("when"), procs, ability_mods and capstone abilities are
## carried as data for the spellbook/talent UI and the combat resolver.
##
## API: learn / can_learn / get_points / get_spent / grant_point / reset /
##      get_ranks / points_in_tree / notify_level_up / trees_for / get_talent /
##      get_tree_def / spellbook_for / capstones_for / class_of / rank_value.
## Signals: talent_learned(actor, id, ranks), points_changed(actor),
##          talents_reset(actor).

signal talent_learned(actor, talent_id, ranks)
signal points_changed(actor)
signal talents_reset(actor)

const DATA_PATH := "res://data/talents.json"

## Stat keys StatsSystem models as real derived stats (the rest are still stored
## in its modifier pool and read back via modifier_bonus(), so every unconditional
## passive is provable — see debug_selftest()).
const _APPLY_SKIP := ["when"]

var _meta: Dictionary = {}
var _class_data: Dictionary = {}          # class_id -> {trees:Array, spellbook:Array}
var _talent_by_id: Dictionary = {}        # talent_id -> talent dict
var _tree_by_id: Dictionary = {}          # tree_id -> tree dict
var _tree_of_talent: Dictionary = {}      # talent_id -> tree_id

## instance_id -> {ref:WeakRef, class_id:String, level_points:int,
##                 bonus_points:int, spent:int, build:{id:ranks}, mod_keys:Array}
var _state: Dictionary = {}


func _ready() -> void:
	_load()
	if not OS.get_environment("RH_TALENT_TEST").is_empty():
		_run_selftest_deferred()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("TalentSystem: cannot open %s" % DATA_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("TalentSystem: bad JSON in %s" % DATA_PATH)
		return
	var root: Dictionary = parsed
	_meta = root.get("meta", {})
	_class_data = root.get("classes", {})
	for cid: String in _class_data:
		var cd: Dictionary = _class_data[cid]
		for tr: Variant in cd.get("trees", []):
			var tree: Dictionary = tr
			_tree_by_id[str(tree.get("id", ""))] = tree
			for t: Variant in tree.get("talents", []):
				var tal: Dictionary = t
				var tid: String = str(tal.get("id", ""))
				_talent_by_id[tid] = tal
				_tree_of_talent[tid] = str(tree.get("id", ""))


# --- meta helpers -----------------------------------------------------------


func point_start_level() -> int:
	return int(_meta.get("point_start_level", 10))


func tier_gate_step() -> int:
	return int(_meta.get("tier_gate_step", 5))


## Rank value law (design §3.2): base * growth^(rank_level - learn_level).
func rank_value(base: float, learn_level: int, rank_level: int) -> float:
	var g: float = float(_meta.get("rank_growth", 1.046))
	return roundf(base * pow(g, float(rank_level - learn_level)))


# --- registry queries -------------------------------------------------------


func trees_for(class_id: String) -> Array:
	var cd: Dictionary = _class_data.get(class_id, {})
	return cd.get("trees", [])


func spellbook_for(class_id: String) -> Array:
	var cd: Dictionary = _class_data.get(class_id, {})
	return cd.get("spellbook", [])


## The 3 capstone ability dicts (kind == "ability") for a class.
func capstones_for(class_id: String) -> Array:
	var out: Array = []
	for tr: Variant in trees_for(class_id):
		for t: Variant in (tr as Dictionary).get("talents", []):
			var tal: Dictionary = t
			if str(tal.get("kind", "")) == "ability" and tal.has("ability"):
				out.append(tal["ability"])
	return out


func get_talent(talent_id: String) -> Dictionary:
	return _talent_by_id.get(talent_id, {})


func get_tree_def(tree_id: String) -> Dictionary:
	return _tree_by_id.get(tree_id, {})


func tree_of(talent_id: String) -> String:
	return str(_tree_of_talent.get(talent_id, ""))


func all_class_ids() -> Array:
	return _class_data.keys()


# --- actor state ------------------------------------------------------------


func class_of(actor: Object) -> String:
	if actor == null:
		return ""
	var iid: int = actor.get_instance_id()
	if _state.has(iid):
		return str(_state[iid]["class_id"])
	return _read_class(actor)


func _read_class(actor: Object) -> String:
	if actor == null:
		return ""
	var cd_v: Variant = actor.get("class_def")
	if cd_v is Dictionary:
		var cid: String = str((cd_v as Dictionary).get("id", ""))
		if cid != "":
			return cid
	var cid_v: Variant = actor.get("class_id")
	if cid_v is String:
		return cid_v
	return ""


func _st(actor: Object) -> Dictionary:
	## Fetch-or-create the per-actor state record.
	var iid: int = actor.get_instance_id()
	if not _state.has(iid):
		_state[iid] = {
			"ref": weakref(actor),
			"class_id": _read_class(actor),
			"level_points": 0,
			"bonus_points": 0,
			"spent": 0,
			"build": {},
			"mod_keys": [],
		}
	else:
		# keep class in sync if it was unknown at first touch
		if str(_state[iid]["class_id"]) == "":
			_state[iid]["class_id"] = _read_class(actor)
	return _state[iid]


func is_registered(actor: Object) -> bool:
	return actor != null and _state.has(actor.get_instance_id())


## Explicit registration (optional; learn/grant auto-register too).
func register(actor: Object, class_id: String = "") -> void:
	if actor == null:
		return
	var s: Dictionary = _st(actor)
	if class_id != "":
		s["class_id"] = class_id


func unregister(actor: Object) -> void:
	if actor == null:
		return
	var iid: int = actor.get_instance_id()
	if _state.has(iid):
		for k: Variant in (_state[iid]["mod_keys"] as Array):
			StatsSystem.remove_modifier(str(k))
		_state.erase(iid)


# --- point economy ----------------------------------------------------------


func _granted(s: Dictionary) -> int:
	return int(s["level_points"]) + int(s["bonus_points"])


func get_points(actor: Object) -> int:
	## Points available to spend.
	if actor == null:
		return 0
	var s: Dictionary = _st(actor)
	return maxi(0, _granted(s) - int(s["spent"]))


func get_spent(actor: Object) -> int:
	if actor == null:
		return 0
	return int(_st(actor)["spent"])


func get_granted(actor: Object) -> int:
	if actor == null:
		return 0
	return _granted(_st(actor))


## Add bonus points (quest reward / debug). Emits points_changed.
func grant_point(actor: Object, n: int = 1) -> void:
	if actor == null or n == 0:
		return
	var s: Dictionary = _st(actor)
	s["bonus_points"] = maxi(0, int(s["bonus_points"]) + n)
	points_changed.emit(actor)


## Level-up hook (design §2.1): 1 point per level from point_start_level..cap.
## Idempotent — recomputes the level-derived pool from the current level, so a
## save-load or repeated calls never double-grant.
func notify_level_up(actor: Object, level: int) -> void:
	if actor == null:
		return
	var s: Dictionary = _st(actor)
	var start: int = point_start_level()
	var total: int = int(_meta.get("points_total", 51))
	var lp: int = clampi(level - (start - 1), 0, total)
	if lp != int(s["level_points"]):
		s["level_points"] = lp
		points_changed.emit(actor)


# --- learn / can_learn ------------------------------------------------------


func get_ranks(actor: Object, talent_id: String) -> int:
	if actor == null:
		return 0
	var build: Dictionary = _st(actor)["build"]
	return int(build.get(talent_id, 0))


func points_in_tree(actor: Object, tree_id: String) -> int:
	if actor == null:
		return 0
	var total: int = 0
	var build: Dictionary = _st(actor)["build"]
	for tid: Variant in build:
		if tree_of(str(tid)) == tree_id:
			total += int(build[tid])
	return total


## Points required to unlock a talent's tier (5*(tier-1)).
func tier_requirement(tier: int) -> int:
	return tier_gate_step() * maxi(0, tier - 1)


## Full guard: points available + tier gate + prerequisite maxed + not maxed +
## same class as the talent's tree.
func can_learn(actor: Object, talent_id: String) -> bool:
	if actor == null:
		return false
	var tal: Dictionary = _talent_by_id.get(talent_id, {})
	if tal.is_empty():
		return false
	var s: Dictionary = _st(actor)
	var tree_id: String = tree_of(talent_id)
	var tree: Dictionary = _tree_by_id.get(tree_id, {})
	if str(tree.get("class_id", "")) != str(s["class_id"]):
		return false
	if int(build_ranks(s, talent_id)) >= int(tal.get("max_ranks", 1)):
		return false
	if get_points(actor) <= 0:
		return false
	if points_in_tree(actor, tree_id) < tier_requirement(int(tal.get("tier", 1))):
		return false
	var req: String = str(tal.get("requires", ""))
	if req != "":
		var req_tal: Dictionary = _talent_by_id.get(req, {})
		if int(build_ranks(s, req)) < int(req_tal.get("max_ranks", 1)):
			return false
	return true


func build_ranks(s: Dictionary, talent_id: String) -> int:
	return int((s["build"] as Dictionary).get(talent_id, 0))


## Spend one point into a talent. Returns true on success. Emits talent_learned
## + points_changed and re-applies the actor's passive stat-mods.
func learn(actor: Object, talent_id: String) -> bool:
	if not can_learn(actor, talent_id):
		return false
	var s: Dictionary = _st(actor)
	var build: Dictionary = s["build"]
	build[talent_id] = int(build.get(talent_id, 0)) + 1
	s["spent"] = int(s["spent"]) + 1
	_rebuild_mods(actor)
	talent_learned.emit(actor, talent_id, int(build[talent_id]))
	points_changed.emit(actor)
	return true


## Wipe the whole build, refund every spent point, strip all talent stat-mods.
func reset(actor: Object) -> void:
	if actor == null:
		return
	var s: Dictionary = _st(actor)
	(s["build"] as Dictionary).clear()
	s["spent"] = 0
	_rebuild_mods(actor)
	talents_reset.emit(actor)
	points_changed.emit(actor)


# --- passive stat-mod application ------------------------------------------


func _rebuild_mods(actor: Object) -> void:
	if actor == null:
		return
	var s: Dictionary = _st(actor)
	# strip previous
	for k: Variant in (s["mod_keys"] as Array):
		StatsSystem.remove_modifier(str(k))
	var keys: Array = []
	var build: Dictionary = s["build"]
	for tid: Variant in build:
		var ranks: int = int(build[tid])
		if ranks <= 0:
			continue
		var tal: Dictionary = _talent_by_id.get(str(tid), {})
		if str(tal.get("kind", "")) != "passive":
			continue
		var per: Dictionary = tal.get("per_rank", {})
		if per.has("when"):
			continue  # conditional passive — applied by the combat resolver
		for stat: Variant in per:
			if str(stat) in _APPLY_SKIP:
				continue
			var v: Variant = per[stat]
			if not (v is int or v is float):
				continue
			var amount: float = float(v) * float(ranks)
			var src: String = "talent:%d:%s:%s" % [actor.get_instance_id(), str(tid), str(stat)]
			StatsSystem.add_modifier(actor, src, str(stat), amount)
			keys.append(src)
	s["mod_keys"] = keys


## Flat sum of an unconditional passive stat across the whole build (debug/UI).
func passive_total(actor: Object, stat: String) -> float:
	if actor == null:
		return 0.0
	var total: float = 0.0
	var build: Dictionary = _st(actor)["build"]
	for tid: Variant in build:
		var tal: Dictionary = _talent_by_id.get(str(tid), {})
		if str(tal.get("kind", "")) != "passive":
			continue
		var per: Dictionary = tal.get("per_rank", {})
		if per.has("when") or not per.has(stat):
			continue
		total += float(per[stat]) * float(build[tid])
	return total


# --- debug / self-test ------------------------------------------------------


func _run_selftest_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	debug_selftest()


## Proves the learn->StatsSystem pipeline without needing a live player: makes a
## throwaway mage actor, grants points, learns two tier-1 passives and prints the
## resulting derived-stat deltas. cp1252-safe (ASCII only).
func debug_selftest() -> void:
	var dummy := Node.new()
	dummy.name = "TalentSelfTestActor"
	add_child(dummy)
	StatsSystem.register(dummy, "mage", 10)
	register(dummy, "mage")
	grant_point(dummy, 10)
	var mana0: float = StatsSystem.get_derived(dummy, "max_mana")
	var dd0: float = StatsSystem.modifier_bonus(dummy, "damage_dealt_pct")
	print("[TalentSelfTest] class=mage L10 points=%d" % get_points(dummy))
	print("[TalentSelfTest] before: max_mana=%.1f damage_dealt_pct=%.1f" % [mana0, dd0])
	var ok1: bool = learn(dummy, "mag_ember_warm")     # mana +8 x1
	var ok2: bool = learn(dummy, "mag_ember_candle")   # damage_dealt_pct +1 x1
	learn(dummy, "mag_ember_warm")                     # rank 2 -> mana +16 total
	var mana1: float = StatsSystem.get_derived(dummy, "max_mana")
	var dd1: float = StatsSystem.modifier_bonus(dummy, "damage_dealt_pct")
	print("[TalentSelfTest] learned Warm Study r%d (%s), Candle Discipline r%d (%s)" % [
		get_ranks(dummy, "mag_ember_warm"), str(ok1),
		get_ranks(dummy, "mag_ember_candle"), str(ok2)])
	print("[TalentSelfTest] after:  max_mana=%.1f (+%.1f) damage_dealt_pct=%.1f (+%.1f)" % [
		mana1, mana1 - mana0, dd1, dd1 - dd0])
	print("[TalentSelfTest] spent=%d available=%d in Emberscript=%d" % [
		get_spent(dummy), get_points(dummy), points_in_tree(dummy, "mag_ember")])
	# tier gate proof: a tier-3 talent must be locked with only 3 in-tree points
	print("[TalentSelfTest] can_learn tier3 Ignite (needs 10 in-tree)? %s" % str(
		can_learn(dummy, "mag_ember_ignite")))
	reset(dummy)
	print("[TalentSelfTest] after reset: spent=%d available=%d max_mana=%.1f" % [
		get_spent(dummy), get_points(dummy), StatsSystem.get_derived(dummy, "max_mana")])
	unregister(dummy)
	StatsSystem.unregister(dummy)
	dummy.queue_free()
