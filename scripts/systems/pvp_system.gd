extends Node
## PvPSystem -- autoload (/root/PvPSystem). Build #46 "the Reckoning Floor".
## The Arena + the Accord Roll (design/PVP_RANKS_TITLES.md). One venue, strictly
## 1v1, best-of-3 on the Reckoning Floor; a joint military ladder -- the Accord
## Roll, 14 ranks earned by Rank Points (RP) with a skill axis of arena Elo. Ranks
## and rating load from data/pvp_ranks.json.
##
## There is no netcode yet (owner-deferred Sim pillar), so a match is resolved
## against a drawn ROSTER opponent (a persistent ~100-adventurer procedural ladder
## that lives between sessions) using the same Elo the player rides -- one pool.
## enter_arena() runs a best-of-3, applies the result, moves the wager gold and
## returns a summary the panel narrates. This is the §6.5 seam: when the Sim ships
## it replaces the opponent generator and NOTHING here changes.
##
## Everything is additive and null-safe: no other system's file is edited. player.gd
## is only READ (class_def, gold). Rank titles are handed off to TitleSystem via the
## rank_changed signal (TitleSystem listens); PvP feats (Bloodletter, Ledger-Long,
## the Flawless) are granted with a GUARDED TitleSystem.grant_title call. A rank
## ladder panel (scenes/ui/pvp.tscn) is self-instanced here and toggled with 'N'.
##
## Public API (actor = the player node, group "player"):
##   enter_arena(actor, stake_id="free") -> Dictionary   run a best-of-3, apply result
##   record_result(actor, win, opp_rating=-1.0) -> Dictionary   apply one match outcome
##   get_rank(actor) -> int                     current Accord Roll rank (1..14)
##   get_points(actor) -> int                   Rank Points (RP)
##   get_rating(actor) -> float / get_season_high(actor) -> float
##   rank_def(n) / rank_name(n) / all_ranks() / rank_count()
##   rank_progress(actor) -> Dictionary         bar data (rp into/needed to next)
##   stakes() / stake_def(id) / current_season() / standings_percentile(actor)
##   open_panel(actor) / close_panel() / toggle_panel()
## Signals:
##   rank_changed(new_rank)                     TitleSystem grants the rank title
##   match_resolved(won, rating_delta)

signal rank_changed(new_rank)
signal match_resolved(won, rating_delta)

const DATA_PATH := "res://data/pvp_ranks.json"
const PANEL_SCENE := "res://scenes/ui/pvp.tscn"
const HISTORY_MAX := 20

var _ranks: Array = []                # [{n,id,name,wow,rp_required,rating_gate,duty,reward}]
var _elo: Dictionary = {}
var _rp_cfg: Dictionary = {}
var _match_cfg: Dictionary = {}
var _roster_cfg: Dictionary = {}
var _stakes: Array = []
var _tithe_pct: float = 0.10
var _win_stake_mult: float = 1.8
var _daily_profit_cap: int = 500

## Per-actor ladder state, keyed by instance id (see serialize()).
var _actors: Dictionary = {}
var _roster: Array = []               # the living ladder (persistent opponents)
var _season: int = 1

var _rng := RandomNumberGenerator.new()
var _panel: Node = null

const _NAMES_FIRST := [
	"Dragoslav", "Branka", "Vasa", "Neagu", "Osana", "Cazimir", "Mirela", "Radu",
	"Ileana", "Stefan", "Ana", "Petru", "Sorina", "Vlad", "Dorina", "Emil",
	"Lupu", "Corvin", "Marta", "Andrei", "Ruxandra", "Bogdan", "Sanda", "Horia",
	"Zamfira", "Toma", "Valcu", "Dana", "Irinel", "Gavril",
]
const _NAMES_LAST := [
	"of the Bloodroad", "the Iron", "Ledger-Hand", "One-Ear", "Fog-Born", "the Quiet",
	"Grate-Walker", "of Basaltfang", "Coppertongue", "the Untithed", "Sand-Fed",
	"of the Twelfth Row", "Lamp-Shy", "the Patient", "Hollow-Voiced",
]
const _CLASSES := ["warrior", "rogue", "mage", "paladin", "necromancer", "rookwarden", "druid"]
const _KINGDOMS := ["sangeroasa", "blestem", "black_night", "angelwings"]


func _ready() -> void:
	_rng.randomize()
	_load_data()
	if not OS.get_environment("RH_PVP").is_empty() \
			or not OS.get_environment("RH_PVP_TEST").is_empty() \
			or _shot_wants_pvp():
		call_deferred("_run_env_hooks")


func _shot_wants_pvp() -> bool:
	var shot: String = OS.get_environment("RH_SHOT").to_lower()
	return shot.find("pvp") >= 0 or shot.find("arena") >= 0 or shot.find("rank") >= 0


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_ranks = _arr(root.get("ranks", []))
	_ranks.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_dict(a).get("n", 0)) < int(_dict(b).get("n", 0)))
	_elo = _dict(root.get("elo", {}))
	_rp_cfg = _dict(root.get("rp", {}))
	_match_cfg = _dict(root.get("match", {}))
	_roster_cfg = _dict(root.get("roster", {}))
	_stakes = _arr(root.get("stakes", []))
	_tithe_pct = float(root.get("tithe_pct", 0.10))
	_win_stake_mult = float(root.get("win_stake_mult", 1.8))
	_daily_profit_cap = int(root.get("daily_profit_cap", 500))
	if _ranks.is_empty():
		push_warning("PvPSystem: no ranks loaded from %s" % DATA_PATH)
	_ensure_roster()


# --- Ladder data helpers ----------------------------------------------------

func all_ranks() -> Array:
	return _ranks


func rank_count() -> int:
	return _ranks.size()


func rank_def(n: int) -> Dictionary:
	for r_v: Variant in _ranks:
		if int(_dict(r_v).get("n", 0)) == n:
			return _dict(r_v)
	return {}


func rank_name(n: int) -> String:
	return str(rank_def(n).get("name", "Unranked"))


func stakes() -> Array:
	return _stakes.duplicate()


func stake_def(id: String) -> Dictionary:
	for s_v: Variant in _stakes:
		if str(_dict(s_v).get("id", "")) == id:
			return _dict(s_v)
	return {}


func current_season() -> int:
	return _season


# --- Per-actor getters ------------------------------------------------------

func get_rank(actor: Node) -> int:
	return int(_state(actor).get("rank", 1))


func get_points(actor: Node) -> int:
	return int(_state(actor).get("rp", 0))


func get_rating(actor: Node) -> float:
	return float(_state(actor).get("rating", _elo_start()))


func get_season_high(actor: Node) -> float:
	return float(_state(actor).get("season_high", _elo_start()))


func wins(actor: Node) -> int:
	return int(_state(actor).get("wins", 0))


func losses(actor: Node) -> int:
	return int(_state(actor).get("losses", 0))


## Bar data for the panel: the RP earned into the current rank and what the next
## rung costs (plus the season-high rating gate, if any).
func rank_progress(actor: Node) -> Dictionary:
	var st: Dictionary = _state(actor)
	var rank: int = int(st.get("rank", 1))
	var rp: int = int(st.get("rp", 0))
	var cur_req: int = int(rank_def(rank).get("rp_required", 0))
	var nxt: Dictionary = rank_def(rank + 1)
	if nxt.is_empty():
		return {"rank": rank, "rp": rp, "into": rp - cur_req, "span": 1, "frac": 1.0,
			"is_max": true, "next_req": cur_req, "next_gate": 0}
	var next_req: int = int(nxt.get("rp_required", cur_req))
	var span: int = maxi(1, next_req - cur_req)
	var into: int = clampi(rp - cur_req, 0, span)
	return {
		"rank": rank, "rp": rp, "into": into, "span": span,
		"frac": clampf(float(into) / float(span), 0.0, 1.0),
		"is_max": false, "next_req": next_req,
		"next_gate": int(nxt.get("rating_gate", 0)),
	}


# --- The arena: run a match -------------------------------------------------

## Draw an opponent within the matchmaking band, run a best-of-3, apply the
## result and move the wager gold. Returns a summary the panel narrates.
func enter_arena(actor: Node, stake_id: String = "free") -> Dictionary:
	if actor == null:
		actor = _player()
	if actor == null:
		return {"ok": false, "reason": "no fighter"}
	_enlist(actor)                                   # first visit = enlistment (§7.5)
	var you: float = get_rating(actor)
	var opp: Dictionary = _draw_opponent(you)
	var opp_rating: float = float(opp.get("rating", you))
	# Escrow the stake.
	var stake: Dictionary = stake_def(stake_id)
	var cost: int = int(stake.get("cost", 0))
	var stake_gate: int = int(stake.get("gate_rank", 1))
	if get_rank(actor) < stake_gate:
		stake = stake_def("free")
		cost = 0
		stake_id = "free"
	if cost > 0 and _gold(actor) < cost:
		stake = stake_def("free")
		cost = 0
		stake_id = "free"
	if cost > 0 and _has_prop(actor, "gold"):
		actor.set("gold", _gold(actor) - cost)
	# Fight.
	var sim: Dictionary = _simulate_match(you, opp_rating)
	var won: bool = bool(sim.get("won", false))
	# Payout.
	var payout: int = 0
	if won and cost > 0:
		payout = int(round(float(cost) * _win_stake_mult))
		if _has_prop(actor, "gold"):
			actor.set("gold", _gold(actor) + payout)
		_state(actor)["wager"]["profit_today"] = int(_state(actor)["wager"].get("profit_today", 0)) + (payout - cost)
	# Ladder result.
	var res: Dictionary = record_result(actor, won, opp_rating)
	# Flawless feat (2-0, no round lost, clean).
	if won and bool(sim.get("flawless", false)):
		_grant_title(actor, "flawless")
	# History row (last 20).
	_push_history(actor, {
		"opp": str(opp.get("id", "")), "opp_name": str(opp.get("name", "Duelist")),
		"opp_class": str(opp.get("class_id", "")), "won": won,
		"stake": cost, "rounds": sim.get("rounds", []),
		"rating_after": res.get("rating_after", you),
	})
	var summary: Dictionary = {
		"ok": true, "won": won,
		"opp_name": str(opp.get("name", "Duelist")), "opp_class": str(opp.get("class_id", "")),
		"opp_rating": int(round(opp_rating)),
		"rounds": sim.get("rounds", []), "flawless": bool(sim.get("flawless", false)),
		"stake_id": stake_id, "stake_cost": cost, "payout": payout,
	}
	summary.merge(res, true)
	return summary


## Best-of-3. Round win chance is the Elo expectation, softened toward a coin so
## the underdog always has a puncher's chance (COMBAT_PACING: the 8 s mirror burn).
func _simulate_match(you: float, opp: float) -> Dictionary:
	var p: float = _expected(you, opp)
	var p_round: float = clampf(0.5 + (p - 0.5) * 0.9, 0.08, 0.92)
	var yr: int = 0
	var orr: int = 0
	var rounds: Array = []
	while yr < 2 and orr < 2:
		if _rng.randf() < p_round:
			yr += 1
			rounds.append(1)
		else:
			orr += 1
			rounds.append(0)
	var won: bool = yr >= 2
	# "Flawless": a 2-0 sweep that also reads clean (skill roll over the round edge).
	var flawless: bool = won and orr == 0 and _rng.randf() < clampf(p, 0.1, 0.9)
	return {"won": won, "rounds": rounds, "flawless": flawless}


## Apply one match outcome: Elo, RP, counts, rank re-evaluation, signals. Public so
## a future Bloodroad battleground can drive the same ladder (grant_rp analog).
func record_result(actor: Node, win: bool, opp_rating: float = -1.0) -> Dictionary:
	if actor == null:
		actor = _player()
	var st: Dictionary = _state(actor)
	var before_rating: float = float(st.get("rating", _elo_start()))
	var before_rp: int = int(st.get("rp", 0))
	var before_rank: int = int(st.get("rank", 1))
	var opp: float = opp_rating if opp_rating >= 0.0 else before_rating
	# --- Elo ---
	var k: float = _k_factor(int(st.get("rated_matches_total", 0)))
	var expected: float = _expected(before_rating, opp)
	var score: float = 1.0 if win else 0.0
	var after_rating: float = maxf(_elo_floor(), before_rating + k * (score - expected))
	st["rating"] = after_rating
	st["rated_matches_total"] = int(st.get("rated_matches_total", 0)) + 1
	st["season_high"] = maxf(float(st.get("season_high", _elo_start())), after_rating)
	# --- Counts ---
	st["duels_total"] = int(st.get("duels_total", 0)) + 1
	if win:
		st["wins"] = int(st.get("wins", 0)) + 1
		st["season_wins"] = int(st.get("season_wins", 0)) + 1
	else:
		st["losses"] = int(st.get("losses", 0)) + 1
		st["season_losses"] = int(st.get("season_losses", 0)) + 1
	# --- RP ---
	var rp_gain: int = 0
	if win:
		var base: float = float(_rp_cfg.get("per_win_base", 15.0))
		var clamp_v: float = float(_rp_cfg.get("diff_clamp", 0.5))
		var denom: float = float(_rp_cfg.get("diff_denominator", 400.0))
		var diff: float = clampf((opp - before_rating) / denom, -clamp_v, clamp_v)
		rp_gain = int(round(base * (1.0 + diff)))
		# First win of the day.
		var today: String = _today()
		if str(st.get("first_win_day", "")) != today:
			st["first_win_day"] = today
			rp_gain += int(_rp_cfg.get("first_win_day_bonus", 30.0))
	# Weekly quota (10 rated matches this week -> a lump of RP, once).
	rp_gain += _weekly_tick(st)
	st["rp"] = int(st.get("rp", 0)) + rp_gain
	# --- Rank re-eval ---
	var after_rank: int = _rank_for(int(st["rp"]), float(st["season_high"]))
	st["rank"] = after_rank
	# --- Signals + feats ---
	match_resolved.emit(win, after_rating - before_rating)
	if after_rank != before_rank and after_rank > before_rank:
		rank_changed.emit(after_rank)
	if int(st.get("wins", 0)) >= 100:
		_grant_title(actor, "bloodletter")
	if int(st.get("duels_total", 0)) >= 1000:
		_grant_title(actor, "ledger_long")
	return {
		"rating_before": before_rating, "rating_after": after_rating,
		"rating_delta": after_rating - before_rating,
		"rp_before": before_rp, "rp_after": int(st["rp"]), "rp_gain": rp_gain,
		"rank_before": before_rank, "rank_after": after_rank,
	}


## The battleground/objective RP entry point (design 7.3): additive service RP that
## doesn't care where it was earned. Re-evaluates rank + fires rank_changed.
func grant_rp(actor: Node, amount: int, _source: String = "") -> int:
	var st: Dictionary = _state(actor)
	var before_rank: int = int(st.get("rank", 1))
	st["rp"] = int(st.get("rp", 0)) + maxi(0, amount)
	var after_rank: int = _rank_for(int(st["rp"]), float(st.get("season_high", _elo_start())))
	st["rank"] = after_rank
	if after_rank > before_rank:
		rank_changed.emit(after_rank)
	return int(st["rp"])


# --- Ranks / Elo math -------------------------------------------------------

func _rank_for(rp: int, season_high: float) -> int:
	var best: int = 1
	for r_v: Variant in _ranks:
		var r: Dictionary = _dict(r_v)
		if rp >= int(r.get("rp_required", 0)) and season_high >= float(r.get("rating_gate", 0)):
			best = maxi(best, int(r.get("n", 1)))
	return best


func _expected(you: float, opp: float) -> float:
	var denom: float = float(_elo.get("denominator", 400.0))
	return 1.0 / (1.0 + pow(10.0, (opp - you) / denom))


func _k_factor(rated_played: int) -> float:
	if rated_played < int(_elo.get("early_matches", 20)):
		return float(_elo.get("k_early", 32.0))
	return float(_elo.get("k_late", 16.0))


func _elo_start() -> float:
	return float(_elo.get("start", 1200.0))


func _elo_floor() -> float:
	return float(_elo.get("floor", 800.0))


func _enlist(actor: Node) -> void:
	var st: Dictionary = _state(actor)
	if bool(st.get("enlisted", false)):
		return
	st["enlisted"] = true
	st["rank"] = maxi(1, int(st.get("rank", 1)))
	rank_changed.emit(int(st["rank"]))            # grants Lamplighter via TitleSystem


func _weekly_tick(st: Dictionary) -> int:
	var wk: Dictionary = _dict(st.get("weekly", {}))
	var wid: String = _week_id()
	if str(wk.get("week_id", "")) != wid:
		wk = {"week_id": wid, "rated_matches": 0, "quota_paid": false}
	wk["rated_matches"] = int(wk.get("rated_matches", 0)) + 1
	var bonus: int = 0
	var quota: int = int(_rp_cfg.get("weekly_quota_matches", 10))
	if not bool(wk.get("quota_paid", false)) and int(wk["rated_matches"]) >= quota:
		wk["quota_paid"] = true
		bonus = int(_rp_cfg.get("weekly_quota_bonus", 150.0))
	st["weekly"] = wk
	return bonus


# --- Roster (the living ladder; the Sim seam, §6.5) -------------------------

func _ensure_roster() -> void:
	if not _roster.is_empty():
		return
	var n: int = int(_roster_cfg.get("count", 100))
	var mean: float = float(_roster_cfg.get("rating_mean", 1350.0))
	var sd: float = float(_roster_cfg.get("rating_sd", 250.0))
	var lo: float = float(_roster_cfg.get("rating_min", 900.0))
	var hi: float = float(_roster_cfg.get("rating_max", 2300.0))
	var gen := RandomNumberGenerator.new()
	gen.seed = 0x2EC4B17            # stable roster between boots
	for i in range(n):
		var rating: float = clampf(gen.randfn(mean, sd), lo, hi)
		var fn: String = _NAMES_FIRST[gen.randi() % _NAMES_FIRST.size()]
		var ln: String = _NAMES_LAST[gen.randi() % _NAMES_LAST.size()]
		var cls: String = _CLASSES[gen.randi() % _CLASSES.size()]
		var king: String = _KINGDOMS[gen.randi() % _KINGDOMS.size()]
		_roster.append({
			"id": "adv_%03d" % i, "name": "%s %s" % [fn, ln],
			"class_id": cls, "kingdom": king, "rating": rating,
			"rank": _rank_for_rating_only(rating),
		})


## A coarse "what rank is this rating worth" for roster flavor only (roster bots
## don't earn RP in this build; the standings use rating).
func _rank_for_rating_only(rating: float) -> int:
	return clampi(1 + int((rating - 900.0) / 100.0), 1, 14)


func _draw_opponent(you: float) -> Dictionary:
	if _roster.is_empty():
		return {"id": "dummy", "name": "Instructor Branka", "class_id": "warrior",
			"kingdom": "sangeroasa", "rating": you}
	var band: float = float(_match_cfg.get("matchmaking_band", 150.0))
	var pool: Array = []
	var widen: float = band
	while pool.is_empty() and widen < 2000.0:
		for e_v: Variant in _roster:
			var e: Dictionary = _dict(e_v)
			if absf(float(e.get("rating", you)) - you) <= widen:
				pool.append(e)
		widen += band
	if pool.is_empty():
		pool = _roster
	return _dict(pool[_rng.randi() % pool.size()])


## Your standing among the ~100-adventurer roster (0..100, lower is better) --
## the single-player analog of a server ladder percentile (§7.4).
func standings_percentile(actor: Node) -> float:
	if _roster.is_empty():
		return 50.0
	var you: float = get_season_high(actor)
	var below: int = 0
	for e_v: Variant in _roster:
		if you >= float(_dict(e_v).get("rating", 0.0)):
			below += 1
	var beat_frac: float = float(below) / float(_roster.size())
	return clampf((1.0 - beat_frac) * 100.0, 0.0, 100.0)


func _push_history(actor: Node, row: Dictionary) -> void:
	var st: Dictionary = _state(actor)
	var h: Array = _arr(st.get("history", []))
	h.push_front(row)
	while h.size() > HISTORY_MAX:
		h.pop_back()
	st["history"] = h


func history(actor: Node) -> Array:
	return _arr(_state(actor).get("history", [])).duplicate()


# --- Title hand-off (guarded) -----------------------------------------------

func _grant_title(actor: Node, id: String) -> void:
	var ts: Node = get_node_or_null("/root/TitleSystem")
	if ts != null and ts.has_method("grant_title"):
		ts.call("grant_title", actor, id)


# --- Panel UI ---------------------------------------------------------------

func open_panel(actor: Node = null, side: String = "center") -> void:
	if actor == null:
		actor = _player()
	# Never sit on the titles picker: split the screen when both are up.
	if side == "center":
		var ts: Node = get_node_or_null("/root/TitleSystem")
		if ts != null and ts.has_method("is_picker_open") and bool(ts.call("is_picker_open")):
			side = "left"
			ts.call("open_picker", actor, "right")
	_ensure_panel()
	if _panel != null and _panel.has_method("present"):
		_panel.call("present", self, actor, side)


func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel) and bool(_panel.get("is_open"))


func close_panel() -> void:
	if _panel != null and _panel.has_method("close"):
		_panel.call("close")


func toggle_panel() -> void:
	_ensure_panel()
	if _panel == null:
		return
	if bool(_panel.get("is_open")):
		close_panel()
	else:
		open_panel(_player())


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	if not ResourceLoader.exists(PANEL_SCENE):
		push_warning("PvPSystem: panel scene missing (%s)" % PANEL_SCENE)
		return
	var scn: PackedScene = load(PANEL_SCENE) as PackedScene
	if scn == null:
		return
	_panel = scn.instantiate()
	add_child(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	# Was KEY_N, but three autoloads bound N (Narrative/PvP/Calendar) and the
	# last-registered sibling (Calendar) consumed it first, leaving this dead.
	# Reassigned to the free apostrophe key; the Menu panel is the discoverable path.
	if not key.pressed or key.echo or key.keycode != KEY_APOSTROPHE:
		return
	if _player() == null or _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_panel()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- Env self-test (RH_PVP screenshot / RH_PVP_TEST proof) ------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(300):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	if pl == null:
		return
	if _has_prop(pl, "gold"):
		pl.set("gold", maxi(int(pl.get("gold")), 500))
	# Seed a mid-ladder standing so the panel reads populated for the shot.
	var st: Dictionary = _state(pl)
	_enlist(pl)
	st["rating"] = 1520.0
	st["season_high"] = 1560.0
	st["rp"] = 3350
	st["wins"] = 84
	st["losses"] = 61
	st["rank"] = _rank_for(3350, 1560.0)
	if not OS.get_environment("RH_PVP_TEST").is_empty():
		_self_test(pl)
	open_panel(pl, "left")


func _self_test(pl: Node) -> void:
	print("[PVP_TEST] ===== Raven Hollow Accord Roll self-test =====")
	print("[PVP_TEST] ranks loaded = %d ; roster = %d ; season = %d" % [
		rank_count(), _roster.size(), current_season()])
	# Reset to a clean enlistment so the climb is legible.
	var st: Dictionary = _state(pl)
	st["rp"] = 0
	st["rank"] = 1
	st["wins"] = 0
	st["losses"] = 0
	st["duels_total"] = 0
	st["rated_matches_total"] = 0
	st["season_high"] = _elo_start()
	st["rating"] = _elo_start()
	st["first_win_day"] = ""
	st["weekly"] = {}
	print("[PVP_TEST] start: rank %d (%s), RP %d, rating %.0f" % [
		get_rank(pl), rank_name(get_rank(pl)), get_points(pl), get_rating(pl)])
	var crossed: Array = []
	var conn := func(new_rank: int) -> void:
		crossed.append("rank %d %s" % [new_rank, rank_name(new_rank)])
	rank_changed.connect(conn)
	# Record wins vs a weaker field so RP accrues and the rank ladder is crossed.
	for i in range(14):
		var r: Dictionary = record_result(pl, true, 1250.0)
		if int(r.get("rank_after", 1)) != int(r.get("rank_before", 1)):
			print("[PVP_TEST]   win %2d -> RP %d (+%d), rating %.0f, RANK UP %d->%d (%s)" % [
				i + 1, int(r["rp_after"]), int(r["rp_gain"]), float(r["rating_after"]),
				int(r["rank_before"]), int(r["rank_after"]), rank_name(int(r["rank_after"]))])
	rank_changed.disconnect(conn)
	print("[PVP_TEST] rank_changed fired for: %s" % str(crossed))
	print("[PVP_TEST] after 14 wins: rank %d (%s), RP %d, rating %.0f, W/L %d/%d" % [
		get_rank(pl), rank_name(get_rank(pl)), get_points(pl), get_rating(pl),
		wins(pl), losses(pl)])
	var prog: Dictionary = rank_progress(pl)
	print("[PVP_TEST] progress to next: %d/%d RP (%.0f%%)" % [
		int(prog.get("into", 0)), int(prog.get("span", 1)), float(prog.get("frac", 0.0)) * 100.0])
	# One full arena match through enter_arena (draws a roster opponent).
	var m: Dictionary = enter_arena(pl, "free")
	print("[PVP_TEST] enter_arena vs %s (%s, %d): won=%s rounds=%s dRating=%+.0f RP+%d" % [
		str(m.get("opp_name", "?")), str(m.get("opp_class", "?")), int(m.get("opp_rating", 0)),
		str(m.get("won", false)), str(m.get("rounds", [])),
		float(m.get("rating_delta", 0.0)), int(m.get("rp_gain", 0))])
	print("[PVP_TEST] standings: better than %.0f%% of the roster" % (100.0 - standings_percentile(pl)))
	print("[PVP_TEST] ===== self-test complete =====")


# --- Save contract (SaveSystem group pattern; inert until wired) ------------

func serialize() -> Dictionary:
	var pl: Node = _player()
	if pl == null:
		return {}
	var st: Dictionary = _state(pl)
	return {
		"season": _season,
		"rating": float(st.get("rating", _elo_start())),
		"season_high": float(st.get("season_high", _elo_start())),
		"rp": int(st.get("rp", 0)), "rank": int(st.get("rank", 1)),
		"wins": int(st.get("wins", 0)), "losses": int(st.get("losses", 0)),
		"season_wins": int(st.get("season_wins", 0)),
		"season_losses": int(st.get("season_losses", 0)),
		"duels_total": int(st.get("duels_total", 0)),
		"rated_matches_total": int(st.get("rated_matches_total", 0)),
		"enlisted": bool(st.get("enlisted", false)),
		"first_win_day": str(st.get("first_win_day", "")),
		"weekly": _dict(st.get("weekly", {})),
		"wager": _dict(st.get("wager", {})),
		"history": _arr(st.get("history", [])),
	}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	_season = int(d.get("season", _season))
	var st: Dictionary = _state(pl)
	st["rating"] = float(d.get("rating", _elo_start()))
	st["season_high"] = float(d.get("season_high", _elo_start()))
	st["rp"] = int(d.get("rp", 0))
	st["rank"] = int(d.get("rank", 1))
	st["wins"] = int(d.get("wins", 0))
	st["losses"] = int(d.get("losses", 0))
	st["season_wins"] = int(d.get("season_wins", 0))
	st["season_losses"] = int(d.get("season_losses", 0))
	st["duels_total"] = int(d.get("duels_total", 0))
	st["rated_matches_total"] = int(d.get("rated_matches_total", 0))
	st["enlisted"] = bool(d.get("enlisted", false))
	st["first_win_day"] = str(d.get("first_win_day", ""))
	st["weekly"] = _dict(d.get("weekly", {}))
	st["wager"] = _dict(d.get("wager", {}))
	st["history"] = _arr(d.get("history", []))


# --- helpers ----------------------------------------------------------------

func _state(actor: Node) -> Dictionary:
	var key: int = actor.get_instance_id() if actor != null else 0
	if not _actors.has(key):
		_actors[key] = {
			"rating": _elo_start(), "season_high": _elo_start(),
			"rp": 0, "rank": 1, "wins": 0, "losses": 0,
			"season_wins": 0, "season_losses": 0,
			"duels_total": 0, "rated_matches_total": 0, "enlisted": false,
			"first_win_day": "", "weekly": {},
			"wager": {"day": _today(), "profit_today": 0}, "history": [],
		}
	return _actors[key]


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _gold(actor: Node) -> int:
	if _has_prop(actor, "gold"):
		var g: Variant = actor.get("gold")
		if g is int or g is float:
			return int(g)
	return 0


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _today() -> String:
	return Time.get_date_string_from_system()


func _week_id() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	var doy: int = _day_of_year(int(d.get("year", 1970)), int(d.get("month", 1)), int(d.get("day", 1)))
	var week: int = int(floor(float(doy - 1) / 7.0)) + 1
	return "%04d-W%02d" % [int(d.get("year", 1970)), week]


func _day_of_year(year: int, month: int, day: int) -> int:
	var mdays: Array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
		mdays[1] = 29
	var doy: int = day
	for i in range(month - 1):
		doy += int(mdays[i])
	return doy


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("PvPSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
