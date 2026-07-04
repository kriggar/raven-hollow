class_name XPSystem
## Static XP / level system for Raven Hollow — Phase C demo (SPEC_PHASE_C_DEMO §6).
## Pure data + logic, no scene code (mirrors class_defs.gd / items.gd).
##
## Model (demo cap: level 10; cap 60 + trainers are post-demo):
##   - player.level: 1..MAX_LEVEL.
##   - player.xp: progress INTO the current level (NOT a lifetime total) —
##     simplest to save/restore and to draw as a bar.
##   - Curve per spec: reaching L2 costs 100 xp, each later level costs
##     x1.6 the previous one (rounded): 100, 160, 256, 410, 655, 1049,
##     1678, 2684, 4295. Cumulative: 6,992 to reach L9, 11,287 to reach
##     L10 (the spec's "~7.5k" estimate matches the L9 cumulative; the
##     x1.6 formula is the authoritative rule and is what ships).
##   - Per level gained: +6% base max hp & mana (compounding), +1 flat
##     damage, full heal. Gold VFX burst + "Level N" banner + chime are
##     presentation and live behind the on_level_up hook (see below).
##
## ============================= INTEGRATION =============================
## Contract for the integration pass — this file touches none of the files
## below; the integrator wires these exact hooks:
##
## 1. player.gd — add progression fields (read/written via get()/set() here,
##    and serialized by SaveSystem):
##        var xp: int = 0                       # progress into CURRENT level
##        var level: int = 1                    # 1..XPSystem.MAX_LEVEL
##        var level_damage_bonus: float = 0.0   # +1.0 per level-up
##    and include the flat bonus in damage, i.e. _stat_damage() becomes:
##        return float(_totals.get("damage", 0.0)) + level_damage_bonus
##    OPTIONAL richer hooks (XPSystem prefers them when present):
##        func apply_level_passives() -> void
##            # ONE level's worth of passive growth (+6% hp/mana, +1 dmg).
##            # Called once per level gained AND once per level on load —
##            # keep it side-effect free (no heal, no VFX).
##        func on_level_up(new_level: int) -> void
##            # Presentation only: gold glint burst (FXLib), "Level N"
##            # Alagard banner via DialogueUI/HUD, level-up chime. Called
##            # ONCE per grant_xp call that leveled (with the final level).
##    Without them XPSystem falls back to mutating _base_max_hp /
##    _base_max_mana (x1.06 each), level_damage_bonus (+1.0) and calling
##    _apply_equipment() to re-derive max_hp/max_mana — all of which exist
##    in player.gd today.
##
## 2. enemy.gd — kill XP, in _die() (once, before the corpse fade):
##        var killer: Node = get_tree().get_first_node_in_group("player")
##        XPSystem.grant_xp(killer, XPSystem.xp_for_kill(type_name))
##    type_name is the existing enemy field ("skeleton_warrior", "orc",
##    "wolf", ... — family prefix match, see xp_for_kill). The training
##    scarecrow and ambient fauna resolve to 0 xp (unknown families).
##
## 3. quests.gd — quest XP on turn-in, amount from quest_defs.gd (spec
##    range QUEST_XP_MIN..QUEST_XP_MAX):
##        XPSystem.grant_xp(player, int(def.get("xp", 0)))
##
## 4. hud.gd — xp bar / level readout: XPSystem.xp_progress(player) ->
##    {level, xp, needed, frac}; the "Level N" banner triggers from
##    player.on_level_up (hook 1), not from polling.
##
## 5. save flow — SaveSystem.apply_player_state() calls
##    XPSystem.reapply_level_bonuses(player, level) exactly once on a
##    freshly created (level-1) player so saved levels re-derive the same
##    maxima WITHOUT the full heal / banner.
## =======================================================================

## Demo level cap (post-demo: 60).
const MAX_LEVEL: int = 10
## XP cost of reaching level 2 (the curve's anchor).
const BASE_LEVEL_COST: int = 100
## Each later level costs this multiple of the previous one.
const LEVEL_COST_GROWTH: float = 1.6
## Passive growth per level gained: +6% base max hp and mana (compounding).
const HP_MANA_BONUS_PCT: float = 0.06
## Passive growth per level gained: +1 flat damage.
const DAMAGE_PER_LEVEL: float = 1.0

## Kill XP by enemy FAMILY (spec §6). Matched by prefix against the
## enemy's type_name, so "skeleton_warrior"/"skeleton_mage" pay the
## skeleton rate and "orc_shaman" pays the orc rate. Unknown families
## (scarecrow, ambient deer/fox/rabbits/birds) pay 0.
const KILL_XP: Dictionary = {
	"skeleton": 12,
	"orc": 18,
	"wolf": 10,
	"boar": 14,
	"bear": 60,
}

## Spec guidance for quest_defs.gd reward tuning (quests carry explicit
## per-quest xp values inside this range).
const QUEST_XP_MIN: int = 50
const QUEST_XP_MAX: int = 150


## XP required to advance FROM (level - 1) TO `level`.
## xp_for_level(2) == 100, xp_for_level(3) == 160, ... Returns 0 for
## level < 2 and for levels past the cap (nothing left to buy).
static func xp_for_level(level: int) -> int:
	if level < 2 or level > MAX_LEVEL:
		return 0
	return roundi(float(BASE_LEVEL_COST) * pow(LEVEL_COST_GROWTH, float(level - 2)))


## Cumulative XP spent to stand at `level` (from a fresh level-1 start).
static func total_xp_for_level(level: int) -> int:
	var total: int = 0
	for l: int in range(2, clampi(level, 1, MAX_LEVEL) + 1):
		total += xp_for_level(l)
	return total


## Kill XP for an enemy type_name — family prefix match against KILL_XP.
## Unknown types (scarecrow, ambient fauna) return 0.
static func xp_for_kill(enemy_type: String) -> int:
	var t: String = enemy_type.strip_edges().to_lower()
	if t.is_empty():
		return 0
	for family: String in KILL_XP.keys():
		if t == family or t.begins_with(family):
			return int(KILL_XP[family])
	return 0


## Grants `amount` xp to the player, resolving any level-ups (each applies
## the passive bonuses; a full heal + the on_level_up hook fire once when
## at least one level was gained). Returns the number of levels gained.
## Degrades gracefully pre-integration: if the player has no xp/level
## fields yet, warns and returns 0. At the cap, xp is discarded.
static func grant_xp(player: Node, amount: int) -> int:
	if player == null or amount <= 0:
		return 0
	var xp_v: Variant = player.get("xp")
	var level_v: Variant = player.get("level")
	if not (xp_v is int or xp_v is float) or not (level_v is int or level_v is float):
		push_warning("XPSystem.grant_xp: player lacks xp/level fields (integration pending) — %d xp dropped." % amount)
		return 0
	var level: int = clampi(int(level_v), 1, MAX_LEVEL)
	if level >= MAX_LEVEL:
		return 0
	var xp: int = maxi(0, int(xp_v)) + amount
	var gained: int = 0
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		xp -= xp_for_level(level + 1)
		level += 1
		gained += 1
		_apply_passive_bonuses(player)
	if level >= MAX_LEVEL:
		xp = 0  # capped: leftover progress is meaningless, keep the bar clean
	player.set("xp", xp)
	player.set("level", level)
	if gained > 0:
		_recompute_stats(player)
		_full_heal(player)
		if player.has_method("on_level_up"):
			player.call("on_level_up", level)
	return gained


## Re-applies the PASSIVE part of every level-up on a freshly created
## (level-1) player — the save/load path. No heal, no on_level_up hook.
## Call exactly once per player instance (bonuses compound).
static func reapply_level_bonuses(player: Node, level: int) -> void:
	if player == null:
		return
	var target: int = clampi(level, 1, MAX_LEVEL)
	for _l: int in range(2, target + 1):
		_apply_passive_bonuses(player)
	_recompute_stats(player)


## HUD helper: {level: int, xp: int, needed: int, frac: float} for the
## current level's progress bar. At the cap: needed 0, frac 1.0.
static func xp_progress(player: Node) -> Dictionary:
	var out: Dictionary = {"level": 1, "xp": 0, "needed": xp_for_level(2), "frac": 0.0}
	if player == null:
		return out
	var level_v: Variant = player.get("level")
	if level_v is int or level_v is float:
		out["level"] = clampi(int(level_v), 1, MAX_LEVEL)
	var xp_v: Variant = player.get("xp")
	if xp_v is int or xp_v is float:
		out["xp"] = maxi(0, int(xp_v))
	var lvl: int = int(out["level"])
	if lvl >= MAX_LEVEL:
		out["needed"] = 0
		out["frac"] = 1.0
		return out
	var needed: int = xp_for_level(lvl + 1)
	out["needed"] = needed
	if needed > 0:
		out["frac"] = clampf(float(int(out["xp"])) / float(needed), 0.0, 1.0)
	else:
		out["frac"] = 1.0
	return out


## One level's worth of passive growth. Prefers the player's own
## apply_level_passives() (integration hook 1); otherwise mutates the
## base-stat fields that exist in player.gd today. set() on a missing
## property is a silent no-op, so this never crashes pre-integration.
static func _apply_passive_bonuses(player: Node) -> void:
	if player.has_method("apply_level_passives"):
		player.call("apply_level_passives")
		return
	var base_hp: Variant = player.get("_base_max_hp")
	if base_hp is float:
		player.set("_base_max_hp", float(base_hp) * (1.0 + HP_MANA_BONUS_PCT))
	var base_mana: Variant = player.get("_base_max_mana")
	if base_mana is float:
		player.set("_base_max_mana", float(base_mana) * (1.0 + HP_MANA_BONUS_PCT))
	var dmg_bonus: Variant = player.get("level_damage_bonus")
	if dmg_bonus is float:
		player.set("level_damage_bonus", float(dmg_bonus) + DAMAGE_PER_LEVEL)


## Re-derives max_hp/max_mana/speed from bases + gear after base stats moved.
static func _recompute_stats(player: Node) -> void:
	if player.has_method("_apply_equipment"):
		player.call("_apply_equipment")


static func _full_heal(player: Node) -> void:
	var max_hp: Variant = player.get("max_hp")
	if max_hp is float:
		player.set("hp", max_hp)
	var max_mana: Variant = player.get("max_mana")
	if max_mana is float:
		player.set("mana", max_mana)
