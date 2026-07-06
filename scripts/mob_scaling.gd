class_name MobScaling
## Mob scaling + archetype tuning law for Raven Hollow (BLUEPRINT_33 / COMBAT_PACING.md s4).
## Pure static data + math (no scene code, mirrors XPSystem / Combat). Reads the
## data-driven tuning table data/combat_archetypes.json once, caches it.
##
## The zone creature_table rows carry the SHIPPED hp/damage (hand-nudged truth);
## these formulas are the TUNING LAW that generated them and that new zones call.
## Behavior params (aggro/leash/telegraph/cast/charge/pack/enrage) are read by
## enemy.gd through the archetype()/tele()/cast_cfg()/pack_cfg()/enrage_cfg() views.
##
## TTK contract: player TTK vs an at-level normal mob ramps 8s (L1) -> 12s (L20+)
## against PlayerRefDPS = 25 * 1.046^(L-1); a facetanking mid-class player dies to
## one at-level normal in ~30s. See COMBAT_PACING.md sections 2-4.

const DATA_PATH := "res://data/combat_archetypes.json"

static var _cache: Dictionary = {}


## Lazy-loads + caches the tuning table. Returns {} only if the file is missing
## (every accessor below degrades to safe defaults on {} so combat never crashes).
static func data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("MobScaling: cannot open %s" % DATA_PATH)
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("MobScaling: bad JSON in %s" % DATA_PATH)
		return {}
	_cache = parsed
	return _cache


static func _const(key: String, dflt: float) -> float:
	var c: Dictionary = data().get("constants", {})
	return float(c.get(key, dflt))


## Per-archetype record ({} default -> brute). Behavior params + hp/dmg mults.
static func archetype(name: String) -> Dictionary:
	var arch: Dictionary = data().get("archetypes", {})
	if arch.has(name):
		return arch[name]
	return arch.get("brute", {})


static func has_archetype(name: String) -> bool:
	return data().get("archetypes", {}).has(name)


static func rank(name: String) -> Dictionary:
	var ranks: Dictionary = data().get("ranks", {})
	if ranks.has(name):
		return ranks[name]
	return ranks.get("normal", {"hp_mult": 1.0, "dmg_mult": 1.0, "xp_mult": 1.0, "plate": "none"})


static func tele() -> Dictionary:
	return data().get("telegraph", {})


static func cast_cfg() -> Dictionary:
	return data().get("cast", {})


static func pack_cfg() -> Dictionary:
	return data().get("pack", {})


static func enrage_cfg() -> Dictionary:
	return data().get("enrage", {})


static func hard_reset_px() -> float:
	return float((data().get("leash", {}) as Dictionary).get("hard_reset_px", 1400.0))


static func aggro_px(name: String) -> float:
	return float(archetype(name).get("aggro_px", 120.0))


static func leash_px(name: String) -> float:
	return float(archetype(name).get("leash_px", 280.0))


static func behaviors(name: String) -> Array:
	return archetype(name).get("behaviors", [])


static func has_behavior(name: String, behavior: String) -> bool:
	return behaviors(name).has(behavior)


static func telegraph_kind(name: String) -> String:
	return str(archetype(name).get("telegraph", "light"))


# --- The tuning law (COMBAT_PACING.md s4) -----------------------------------


static func ttk_target(level: int) -> float:
	var lo: float = _const("ttk_min", 8.0)
	var hi: float = _const("ttk_max", 12.0)
	var ramp: float = maxf(1.0, _const("ttk_ramp_levels", 19.0))
	return lo + (hi - lo) * clampf(float(level - 1) / ramp, 0.0, 1.0)


static func ref_dps(level: int) -> float:
	return _const("ref_dps_base", 25.0) * pow(_const("ref_dps_growth", 1.046), float(level - 1))


static func mob_hp(level: int, arch: String = "brute", rank_id: String = "normal") -> float:
	var a: Dictionary = archetype(arch)
	var r: Dictionary = rank(rank_id)
	# 0.9 = damage uptime (player repositions during telegraphs).
	return roundf(ref_dps(level) * ttk_target(level) * _const("uptime", 0.9)
			* float(a.get("hp_mult", 1.0)) * float(r.get("hp_mult", 1.0)))


static func mob_damage(level: int, arch: String = "brute", rank_id: String = "normal") -> float:
	var a: Dictionary = archetype(arch)
	var r: Dictionary = rank(rank_id)
	# 10.8 = 120 EHP / 30s facetank * 1.6s swing cadence, at L1.
	return roundf(_const("dmg_base", 10.8) * pow(_const("dmg_growth", 1.055), float(level - 1))
			* float(a.get("dmg_mult", 1.0)) * float(r.get("dmg_mult", 1.0)))


static func rank_xp_mult(rank_id: String) -> float:
	return float(rank(rank_id).get("xp_mult", 1.0))
