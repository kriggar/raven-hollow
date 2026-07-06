extends Node
## DungeonSystem -- autoload (/root/DungeonSystem). Build #74 "Dungeons & Raids"
## (design/BLUEPRINT_74_DUNGEONS_RAIDS.md).
##
## Ten instanced dungeons + three raids (data/dungeons.json), each themed to a real
## zone id from scripts/zone_defs.gd. A dungeon is a single active INSTANCE at a
## time: trash waves, then one or more BOSSES, each of which runs a phase state
## machine -- phases open at hp-fraction thresholds (enter_at), an enrage timer ticks
## while the boss is engaged, and each phase's mechanics are broadcast as telegraph
## signals on a cadence so the combat/FX layer (or a bot) can react. Raids carry a
## weekly LOCKOUT (per-actor, wall-clock) and min/max player counts.
##
## Everything is additive and null-safe -- no other system's file is edited. Rewards
## on a clear are granted through the existing LootSystem (roll_loot), XPSystem
## (grant_xp) and StatsSystem (a temporary "dungeon blessing" modifier, reversible),
## all READ/called and each individually guarded so a missing system just degrades.
##
## A minimal dungeon HUD is self-instanced here as a CanvasLayer child (boss frame +
## HP bar + enrage/elapsed timer + an Enter-Dungeon debug list), hidden until an
## instance is active. Backslash toggles the debug browser.
##
## Public API (actor optional -> defaults to the player):
##   enter_dungeon(id, actor=null, force=false) -> Dictionary {ok, reason}
##   exit_dungeon()                              tear the active instance down
##   is_active() -> bool ; current_id() -> String ; current_is_raid() -> bool
##   advance_wave() -> Dictionary                clear the next trash wave
##   engage_boss(index=-1) -> Dictionary         pull the current/indexed boss
##   damage_boss(amount) -> Dictionary           apply damage, drive phases/death
##   current_boss() -> Dictionary                live boss runtime snapshot
##   wipe() -> void                              party wipe: reset the instance
##   reset_instance() -> void                    rebuild bosses+waves from the def
##   is_locked(id, actor=null) -> bool ; lockout_remaining(id, actor=null) -> float
##   clear_lockout(id, actor=null)               (debug) drop a lockout
##   all_dungeons() / all_raids() / dungeon_def(id) / dungeon_ids() / raid_ids()
##   open_browser() / close_browser() / toggle_browser()
## Signals:
##   dungeon_entered(id), boss_phase_changed(id, boss_name, phase_index, phase_name),
##   dungeon_cleared(id), party_wiped(id), boss_engaged(id, boss_name),
##   boss_defeated(id, boss_name), boss_enraged(id, boss_name),
##   boss_mechanic_telegraphed(id, boss_name, mechanic), wave_cleared(id, wave_index)

signal dungeon_entered(id)
signal boss_phase_changed(id, boss_name, phase_index, phase_name)
signal dungeon_cleared(id)
signal party_wiped(id)
signal boss_engaged(id, boss_name)
signal boss_defeated(id, boss_name)
signal boss_enraged(id, boss_name)
signal boss_mechanic_telegraphed(id, boss_name, mechanic)
signal wave_cleared(id, wave_index)

const DATA_PATH := "res://data/dungeons.json"

var _dungeons: Dictionary = {}          # id -> def (kind == "dungeon")
var _raids: Dictionary = {}             # id -> def (kind == "raid")
var _all: Dictionary = {}               # id -> def (both)
var _dungeon_order: Array = []          # ids in file order
var _raid_order: Array = []
var _settings: Dictionary = {}

## The single live instance, or {} when none. Rebuilt by reset_instance().
## {id, def, is_raid, boss_index, bosses:Array, wave_index, cleared, wiped, actor_iid}
var _active: Dictionary = {}

## Per-actor lockouts: instance_id -> {dungeon_id: unlock_unix_seconds}.
var _lockouts: Dictionary = {}

var _hud: CanvasLayer = null
var _browser_open: bool = false
# HUD sub-nodes (looked up by name, all optional).
var _boss_name_lbl: Label = null
var _phase_lbl: Label = null
var _timer_lbl: Label = null
var _telegraph_lbl: Label = null
var _hp_fill: ColorRect = null
var _hp_back: ColorRect = null
var _browser_panel: Control = null


func _ready() -> void:
	_load_data()
	set_process(true)
	if not OS.get_environment("RH_DUNGEON_TEST").is_empty():
		call_deferred("_run_selftest")
	elif not OS.get_environment("RH_DUNGEON").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_settings = _dict(root.get("settings", {}))
	_dungeons = _dict(root.get("dungeons", {}))
	_raids = _dict(root.get("raids", {}))
	_dungeon_order = _dungeons.keys()
	_raid_order = _raids.keys()
	_all.clear()
	for id: String in _dungeon_order:
		var d: Dictionary = _dict(_dungeons[id])
		d["_kind"] = "dungeon"
		_all[id] = d
	for id: String in _raid_order:
		var d: Dictionary = _dict(_raids[id])
		d["_kind"] = "raid"
		_all[id] = d
	if _all.is_empty():
		push_warning("DungeonSystem: no dungeons loaded from %s" % DATA_PATH)


# --- Data queries -----------------------------------------------------------

func all_dungeons() -> Dictionary:
	return _dungeons


func all_raids() -> Dictionary:
	return _raids


func dungeon_ids() -> Array:
	return _dungeon_order.duplicate()


func raid_ids() -> Array:
	return _raid_order.duplicate()


func dungeon_def(id: String) -> Dictionary:
	return _dict(_all.get(id, {}))


func is_raid(id: String) -> bool:
	return str(dungeon_def(id).get("_kind", "")) == "raid"


func telegraph_interval() -> float:
	return float(_settings.get("telegraph_interval_s", 4.0))


# --- Instance lifecycle -----------------------------------------------------

## Enter a dungeon/raid. Guards on unknown id, active-instance conflict and (for
## raids and any lockout_hours>0 content) the per-actor lockout. `force` bypasses
## the lockout (debug browser / self-test). Returns {ok, reason}.
func enter_dungeon(id: String, actor: Node = null, force: bool = false) -> Dictionary:
	if not _all.has(id):
		return {"ok": false, "reason": "unknown dungeon '%s'" % id}
	if is_active():
		return {"ok": false, "reason": "already in '%s'" % current_id()}
	var a: Node = _resolve(actor)
	if not force and is_locked(id, a):
		return {"ok": false, "reason": "on lockout (%.1fh left)" % (lockout_remaining(id, a) / 3600.0)}
	_active = _build_instance(id, a)
	_ensure_hud()
	_show_hud(true)
	_update_hud()
	dungeon_entered.emit(id)
	return {"ok": true, "reason": ""}


func _build_instance(id: String, actor: Node) -> Dictionary:
	var def: Dictionary = dungeon_def(id)
	var inst: Dictionary = {
		"id": id, "def": def, "is_raid": is_raid(id),
		"boss_index": 0, "bosses": [], "wave_index": 0,
		"cleared": false, "wiped": false,
		"actor_iid": actor.get_instance_id() if actor != null else 0,
	}
	for b: Variant in _arr(def.get("bosses", [])):
		(inst["bosses"] as Array).append(_build_boss(_dict(b)))
	return inst


func _build_boss(bdef: Dictionary) -> Dictionary:
	var hp: float = maxf(1.0, float(bdef.get("hp", 1000.0)))
	return {
		"def": bdef,
		"name": str(bdef.get("name", "Boss")),
		"hp": hp, "max_hp": hp,
		"phase_index": 0,
		"engaged": false, "alive": true,
		"enrage_s": float(bdef.get("enrage_s", 180.0)),
		"elapsed": 0.0, "enraged": false,
		"telegraph_accum": 0.0, "mech_cursor": 0,
	}


func exit_dungeon() -> void:
	_active = {}
	_show_hud(false)


func reset_instance() -> void:
	# Wipe/retry: rebuild bosses and waves from the def, keep the instance open.
	if not is_active():
		return
	var def: Dictionary = _dict(_active.get("def", {}))
	var rebuilt: Array = []
	for b: Variant in _arr(def.get("bosses", [])):
		rebuilt.append(_build_boss(_dict(b)))
	_active["bosses"] = rebuilt
	_active["boss_index"] = 0
	_active["wave_index"] = 0
	_active["cleared"] = false
	_active["wiped"] = false
	_update_hud()


func is_active() -> bool:
	return not _active.is_empty()


func current_id() -> String:
	return str(_active.get("id", "")) if is_active() else ""


func current_is_raid() -> bool:
	return bool(_active.get("is_raid", false)) if is_active() else false


# --- Trash waves ------------------------------------------------------------

## Clear the next trash wave. Returns {ok, wave_index, cleared_all}.
func advance_wave() -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "no active instance"}
	var waves: Array = _arr(_dict(_active["def"]).get("trash_waves", []))
	var idx: int = int(_active["wave_index"])
	if idx >= waves.size():
		return {"ok": true, "wave_index": idx, "cleared_all": true}
	_active["wave_index"] = idx + 1
	wave_cleared.emit(current_id(), idx)
	_update_hud()
	return {"ok": true, "wave_index": idx + 1, "cleared_all": (idx + 1) >= waves.size()}


func waves_cleared() -> bool:
	if not is_active():
		return false
	var waves: Array = _arr(_dict(_active["def"]).get("trash_waves", []))
	return int(_active["wave_index"]) >= waves.size()


# --- Boss encounter / phase state machine -----------------------------------

func current_boss() -> Dictionary:
	if not is_active():
		return {}
	var bosses: Array = _active["bosses"]
	var i: int = int(_active["boss_index"])
	if i < 0 or i >= bosses.size():
		return {}
	return _boss_snapshot(_dict(bosses[i]))


func _boss_snapshot(b: Dictionary) -> Dictionary:
	return {
		"name": str(b.get("name", "")),
		"hp": float(b.get("hp", 0.0)),
		"max_hp": float(b.get("max_hp", 1.0)),
		"hp_frac": float(b.get("hp", 0.0)) / maxf(1.0, float(b.get("max_hp", 1.0))),
		"phase_index": int(b.get("phase_index", 0)),
		"phase_name": _phase_name(b, int(b.get("phase_index", 0))),
		"engaged": bool(b.get("engaged", false)),
		"alive": bool(b.get("alive", true)),
		"enraged": bool(b.get("enraged", false)),
		"elapsed": float(b.get("elapsed", 0.0)),
		"enrage_s": float(b.get("enrage_s", 0.0)),
	}


## Pull the current boss (or the boss at `index`). Emits boss_engaged and opens
## phase 0. Returns {ok, name} or an error.
func engage_boss(index: int = -1) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "no active instance"}
	if index >= 0:
		_active["boss_index"] = index
	var bosses: Array = _active["bosses"]
	var i: int = int(_active["boss_index"])
	if i < 0 or i >= bosses.size():
		return {"ok": false, "reason": "no such boss"}
	var b: Dictionary = _dict(bosses[i])
	if not bool(b.get("alive", true)):
		return {"ok": false, "reason": "boss already dead"}
	b["engaged"] = true
	b["elapsed"] = 0.0
	b["phase_index"] = 0
	b["telegraph_accum"] = 0.0
	boss_engaged.emit(current_id(), str(b.get("name", "")))
	boss_phase_changed.emit(current_id(), str(b.get("name", "")), 0, _phase_name(b, 0))
	_update_hud()
	return {"ok": true, "name": str(b.get("name", ""))}


## Apply `amount` damage to the engaged boss. Drives the phase state machine
## (opens deeper phases as hp crosses each phase's enter_at fraction) and handles
## death -> next boss / dungeon clear. Returns a boss snapshot + {ok, killed}.
func damage_boss(amount: float) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "no active instance"}
	var bosses: Array = _active["bosses"]
	var i: int = int(_active["boss_index"])
	if i < 0 or i >= bosses.size():
		return {"ok": false, "reason": "no boss"}
	var b: Dictionary = _dict(bosses[i])
	if not bool(b.get("alive", true)):
		return {"ok": false, "reason": "boss dead"}
	if not bool(b.get("engaged", false)):
		b["engaged"] = true
	b["hp"] = maxf(0.0, float(b.get("hp", 0.0)) - maxf(0.0, amount))
	_evaluate_phase(b)
	var killed: bool = false
	if float(b["hp"]) <= 0.0:
		killed = true
		_on_boss_death(b)
	_update_hud()
	var snap: Dictionary = _boss_snapshot(b)
	snap["ok"] = true
	snap["killed"] = killed
	return snap


## Recompute the boss's phase from its hp fraction. Phases are authored with
## descending enter_at thresholds (1.0, 0.5, ...); the current phase is the
## deepest one whose enter_at is >= the live fraction. Emits boss_phase_changed
## when the phase advances.
func _evaluate_phase(b: Dictionary) -> void:
	var phases: Array = _arr(_dict(b.get("def", {})).get("phases", []))
	if phases.is_empty():
		return
	var frac: float = float(b.get("hp", 0.0)) / maxf(1.0, float(b.get("max_hp", 1.0)))
	var target: int = 0
	for pi: int in range(phases.size()):
		if frac <= float(_dict(phases[pi]).get("enter_at", 1.0)) + 0.0001:
			target = pi
	if target > int(b.get("phase_index", 0)):
		b["phase_index"] = target
		b["telegraph_accum"] = 0.0
		b["mech_cursor"] = 0
		boss_phase_changed.emit(current_id(), str(b.get("name", "")), target, _phase_name(b, target))


func _on_boss_death(b: Dictionary) -> void:
	b["hp"] = 0.0
	b["alive"] = false
	b["engaged"] = false
	boss_defeated.emit(current_id(), str(b.get("name", "")))
	var bosses: Array = _active["bosses"]
	var next_i: int = int(_active["boss_index"]) + 1
	if next_i < bosses.size():
		_active["boss_index"] = next_i   # next boss ready; caller engages it
		return
	_on_dungeon_cleared()


func _on_dungeon_cleared() -> void:
	if bool(_active.get("cleared", false)):
		return
	_active["cleared"] = true
	var id: String = current_id()
	var actor: Node = _active_actor()
	_grant_rewards(id, actor)
	_set_lockout(id, actor)
	dungeon_cleared.emit(id)


## Party wipe: announce it and reset the instance so the group can retry. Any
## lockout is unaffected (the raid stays locked once cleared, not on a wipe).
func wipe() -> void:
	if not is_active():
		return
	var id: String = current_id()
	_active["wiped"] = true
	party_wiped.emit(id)
	reset_instance()


# --- Enrage + mechanic telegraphs (driven while a boss is engaged) -----------

func _process(delta: float) -> void:
	if not is_active():
		return
	var bosses: Array = _active["bosses"]
	var i: int = int(_active["boss_index"])
	if i < 0 or i >= bosses.size():
		return
	var b: Dictionary = _dict(bosses[i])
	if not bool(b.get("engaged", false)) or not bool(b.get("alive", true)):
		_update_timer_label(b)
		return
	# Enrage timer.
	b["elapsed"] = float(b.get("elapsed", 0.0)) + delta
	if not bool(b.get("enraged", false)) and float(b["elapsed"]) >= float(b.get("enrage_s", 1e9)):
		b["enraged"] = true
		boss_enraged.emit(current_id(), str(b.get("name", "")))
	# Mechanic telegraph cadence.
	b["telegraph_accum"] = float(b.get("telegraph_accum", 0.0)) + delta
	if float(b["telegraph_accum"]) >= telegraph_interval():
		b["telegraph_accum"] = 0.0
		_telegraph_next(b)
	_update_timer_label(b)


## Broadcast the next mechanic in the boss's current phase (cycled) as a signal.
func _telegraph_next(b: Dictionary) -> Dictionary:
	var mechs: Array = _current_mechanics(b)
	if mechs.is_empty():
		return {}
	var cur: int = int(b.get("mech_cursor", 0)) % mechs.size()
	b["mech_cursor"] = cur + 1
	var m: Dictionary = _dict(mechs[cur])
	boss_mechanic_telegraphed.emit(current_id(), str(b.get("name", "")), m)
	if _telegraph_lbl != null:
		_telegraph_lbl.text = "%s: %s" % [str(m.get("name", "?")), str(m.get("telegraph", ""))]
	return m


func _current_mechanics(b: Dictionary) -> Array:
	var phases: Array = _arr(_dict(b.get("def", {})).get("phases", []))
	var pi: int = int(b.get("phase_index", 0))
	if pi < 0 or pi >= phases.size():
		return []
	return _arr(_dict(phases[pi]).get("mechanics", []))


func _phase_name(b: Dictionary, index: int) -> String:
	var phases: Array = _arr(_dict(b.get("def", {})).get("phases", []))
	if index < 0 or index >= phases.size():
		return ""
	return str(_dict(phases[index]).get("name", "Phase %d" % (index + 1)))


# --- Raid lockouts ----------------------------------------------------------

func is_locked(id: String, actor: Node = null) -> bool:
	return lockout_remaining(id, actor) > 0.0


func lockout_remaining(id: String, actor: Node = null) -> float:
	var a: Node = _resolve(actor)
	if a == null:
		return 0.0
	var map: Dictionary = _dict(_lockouts.get(a.get_instance_id(), {}))
	var expiry: float = float(map.get(id, 0.0))
	return maxf(0.0, expiry - Time.get_unix_time_from_system())


func clear_lockout(id: String, actor: Node = null) -> void:
	var a: Node = _resolve(actor)
	if a == null:
		return
	var map: Dictionary = _dict(_lockouts.get(a.get_instance_id(), {}))
	map.erase(id)
	_lockouts[a.get_instance_id()] = map


func _set_lockout(id: String, actor: Node) -> void:
	if actor == null:
		return
	var hours: float = float(dungeon_def(id).get("lockout_hours", 0.0))
	if hours <= 0.0:
		return
	var map: Dictionary = _dict(_lockouts.get(actor.get_instance_id(), {}))
	map[id] = Time.get_unix_time_from_system() + hours * 3600.0
	_lockouts[actor.get_instance_id()] = map


# --- Rewards (LootSystem + XPSystem + StatsSystem, each guarded) --------------

func _grant_rewards(id: String, actor: Node) -> Dictionary:
	var def: Dictionary = dungeon_def(id)
	var out: Dictionary = {"loot": [], "xp": 0, "gold": 0, "blessing": false}
	# 1) Loot roll through the existing LootSystem table.
	var loot: Node = get_node_or_null("/root/LootSystem")
	var items: Array = []
	if loot != null and loot.has_method("roll_loot"):
		items = _arr(loot.call("roll_loot", str(def.get("loot_table", "elite_b3")), 0.0))
	out["loot"] = items
	# Deposit gear into the bag; sum any gold line.
	var inv: Node = get_node_or_null("/root/InventorySystem")
	for it_v: Variant in items:
		if not (it_v is Dictionary):
			continue
		var it: Dictionary = it_v
		if str(it.get("kind", "")) == "gold" or it.has("gold_amount"):
			out["gold"] = int(out["gold"]) + int(it.get("amount", it.get("gold_amount", 0)))
		elif inv != null and inv.has_method("add_item") and actor != null:
			inv.call("add_item", actor, it)
	# Flat gold reward on top (guarded write to player.gold).
	out["gold"] = int(out["gold"]) + int(def.get("gold_reward", 0))
	if actor != null and int(out["gold"]) > 0 and _has_prop(actor, "gold"):
		actor.set("gold", int(actor.get("gold")) + int(out["gold"]))
	# 2) XP through the global XPSystem (no-op if the actor lacks xp/level).
	var xp: int = int(def.get("xp_reward", 0))
	if actor != null and xp > 0:
		XPSystem.grant_xp(actor, xp)
		out["xp"] = xp
	# 3) A temporary "dungeon blessing" via StatsSystem (a reversible modifier).
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and actor != null and ss.has_method("add_modifier"):
		if ss.has_method("register") and ss.has_method("is_registered") \
				and not bool(ss.call("is_registered", actor)):
			ss.call("register", actor, _class_id(actor), _level(actor))
		ss.call("add_modifier", actor, _blessing_src(actor), "damage", _blessing_amount(id))
		out["blessing"] = true
	return out


func _blessing_src(actor: Node) -> String:
	return "dungeon_blessing:%d" % (actor.get_instance_id() if actor != null else 0)


func _blessing_amount(id: String) -> float:
	# Scales gently with content level so an endgame clear feels stronger.
	return 2.0 + float(dungeon_def(id).get("level", 5)) * 0.1


# --- Dungeon HUD (self-instanced CanvasLayer; boss frame + timer + browser) ---

func _ensure_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	_hud = CanvasLayer.new()
	_hud.name = "DungeonHUD"
	_hud.layer = 60
	_hud.visible = false

	# Boss frame -- top center.
	var frame := ColorRect.new()
	frame.name = "BossFrame"
	frame.color = Color(0.06, 0.05, 0.07, 0.82)
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.position = Vector2(-220.0, 14.0)
	frame.size = Vector2(440.0, 62.0)
	_hud.add_child(frame)

	_boss_name_lbl = Label.new()
	_boss_name_lbl.name = "BossName"
	_boss_name_lbl.position = Vector2(10.0, 4.0)
	_boss_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	frame.add_child(_boss_name_lbl)

	_phase_lbl = Label.new()
	_phase_lbl.name = "PhaseName"
	_phase_lbl.position = Vector2(10.0, 22.0)
	_phase_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.86))
	frame.add_child(_phase_lbl)

	_hp_back = ColorRect.new()
	_hp_back.name = "HpBack"
	_hp_back.color = Color(0.15, 0.04, 0.05, 0.95)
	_hp_back.position = Vector2(10.0, 44.0)
	_hp_back.size = Vector2(420.0, 12.0)
	frame.add_child(_hp_back)

	_hp_fill = ColorRect.new()
	_hp_fill.name = "HpFill"
	_hp_fill.color = Color(0.70, 0.14, 0.16, 1.0)
	_hp_fill.position = Vector2(0.0, 0.0)
	_hp_fill.size = Vector2(420.0, 12.0)
	_hp_back.add_child(_hp_fill)

	_timer_lbl = Label.new()
	_timer_lbl.name = "Timer"
	_timer_lbl.position = Vector2(330.0, 4.0)
	_timer_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	frame.add_child(_timer_lbl)

	_telegraph_lbl = Label.new()
	_telegraph_lbl.name = "Telegraph"
	_telegraph_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_telegraph_lbl.position = Vector2(-220.0, 80.0)
	_telegraph_lbl.add_theme_color_override("font_color", Color(0.98, 0.70, 0.30))
	_hud.add_child(_telegraph_lbl)

	# Enter-Dungeon debug browser -- left side, hidden until toggled.
	_browser_panel = _build_browser()
	_hud.add_child(_browser_panel)

	add_child(_hud)


func _build_browser() -> Control:
	var panel := ColorRect.new()
	panel.name = "Browser"
	panel.color = Color(0.05, 0.05, 0.07, 0.9)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12.0, 96.0)
	panel.size = Vector2(300.0, 460.0)
	panel.visible = false

	var box := VBoxContainer.new()
	box.name = "List"
	box.position = Vector2(10.0, 8.0)
	box.size = Vector2(280.0, 440.0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "-- DUNGEONS & RAIDS --"
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	box.add_child(title)

	for id: String in _dungeon_order + _raid_order:
		var d: Dictionary = dungeon_def(id)
		var btn := Button.new()
		var tag: String = "RAID" if is_raid(id) else str(d.get("tier", "normal")).to_upper()
		btn.text = "L%d [%s] %s" % [int(d.get("level", 1)), tag, str(d.get("name", id))]
		var did: String = id
		btn.pressed.connect(func() -> void: _on_browser_pick(did))
		box.add_child(btn)
	return panel


func _on_browser_pick(id: String) -> void:
	if is_active():
		exit_dungeon()
	enter_dungeon(id, _player(), true)


func _show_hud(show_it: bool) -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = show_it or _browser_open


func _update_hud() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	var snap: Dictionary = current_boss()
	if _boss_name_lbl != null:
		var wave: int = int(_active.get("wave_index", 0)) if is_active() else 0
		var head: String = str(snap.get("name", "")) if not snap.is_empty() else "%s (wave %d)" % [current_id(), wave]
		_boss_name_lbl.text = head
	if _phase_lbl != null:
		_phase_lbl.text = str(snap.get("phase_name", "")) if not snap.is_empty() else ""
	if _hp_fill != null:
		var frac: float = float(snap.get("hp_frac", 0.0)) if not snap.is_empty() else 0.0
		_hp_fill.size = Vector2(420.0 * clampf(frac, 0.0, 1.0), 12.0)
	_update_timer_label(_current_boss_runtime())


func _current_boss_runtime() -> Dictionary:
	if not is_active():
		return {}
	var bosses: Array = _active["bosses"]
	var i: int = int(_active["boss_index"])
	return _dict(bosses[i]) if i >= 0 and i < bosses.size() else {}


func _update_timer_label(b: Dictionary) -> void:
	if _timer_lbl == null:
		return
	if b.is_empty():
		_timer_lbl.text = ""
		return
	var remain: float = maxf(0.0, float(b.get("enrage_s", 0.0)) - float(b.get("elapsed", 0.0)))
	if bool(b.get("enraged", false)):
		_timer_lbl.text = "ENRAGED"
	elif bool(b.get("engaged", false)):
		_timer_lbl.text = "%02d:%02d" % [int(remain) / 60, int(remain) % 60]
	else:
		_timer_lbl.text = ""


func open_browser() -> void:
	_ensure_hud()
	_browser_open = true
	if _browser_panel != null:
		_browser_panel.visible = true
	if _hud != null:
		_hud.visible = true


func close_browser() -> void:
	_browser_open = false
	if _browser_panel != null:
		_browser_panel.visible = false
	if _hud != null:
		_hud.visible = is_active()


func toggle_browser() -> void:
	if _browser_open:
		close_browser()
	else:
		open_browser()


# --- Input (backslash toggles the debug browser) ----------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_BACKSLASH:
		return
	if not _browser_open and _panel_blocking():
		return
	get_viewport().set_input_as_handled()
	toggle_browser()


func _panel_blocking() -> bool:
	for grp: String in ["dialogue_ui", "bag_ui", "sheet_ui", "crafting_ui", "shop_ui"]:
		var n: Node = get_tree().get_first_node_in_group(grp)
		if n != null and bool(n.get("is_open")):
			return true
	return false


# --- helpers ----------------------------------------------------------------

func _resolve(actor: Node) -> Node:
	return actor if actor != null else _player()


func _active_actor() -> Node:
	if not is_active():
		return _player()
	var iid: int = int(_active.get("actor_iid", 0))
	if iid != 0:
		var o: Object = instance_from_id(iid)
		if o is Node and is_instance_valid(o):
			return o
	return _player()


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _class_id(actor: Node) -> String:
	if actor == null:
		return "warrior"
	var cd: Variant = actor.get("class_def")
	if cd is Dictionary and (cd as Dictionary).has("id"):
		return str((cd as Dictionary)["id"])
	return "warrior"


func _level(actor: Node) -> int:
	return int(actor.get("level")) if _has_prop(actor, "level") else 1


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("DungeonSystem: missing data file '%s'" % path)
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
	var pl: Node = _player()
	if pl == null:
		return {}
	return {"lockouts": _dict(_lockouts.get(pl.get_instance_id(), {})).duplicate()}


func deserialize(d: Dictionary) -> void:
	var pl: Node = _player()
	if pl == null:
		return
	var src: Dictionary = _dict(d.get("lockouts", {}))
	var map: Dictionary = {}
	for id_v: Variant in src:
		var id: String = str(id_v)
		if _all.has(id):
			map[id] = float(src[id_v])
	_lockouts[pl.get_instance_id()] = map


# --- Env screenshot hook (RH_DUNGEON opens the browser) ----------------------

func _run_env_hooks() -> void:
	var pl: Node = null
	for _i in range(240):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	open_browser()


# --- Self-test (RH_DUNGEON_TEST=1) ------------------------------------------

func _run_selftest() -> void:
	var pl: Node = null
	for _i in range(300):
		pl = _player()
		if pl != null:
			break
		await get_tree().process_frame
	var fails: Array = []
	print("[DUNGEON_TEST] ===== Raven Hollow dungeons & raids self-test =====")
	print("[DUNGEON_TEST] loaded %d dungeons + %d raids ; player=%s" % [
		_dungeons.size(), _raids.size(), str(pl != null)])

	if _dungeons.size() < 5:
		fails.append("need >=5 dungeons, have %d" % _dungeons.size())
	if _raids.size() < 2:
		fails.append("need >=2 raids, have %d" % _raids.size())

	# --- 1) Enter a dungeon, clear waves, walk the boss through its phases. -----
	var did := "rat_cellars"
	var phase_log: Array = []
	var pcb := func(_id: Variant, _bn: Variant, pidx: Variant, pname: Variant) -> void:
		phase_log.append("%d:%s" % [int(pidx), str(pname)])
	boss_phase_changed.connect(pcb)
	var mech_hits: Array = [0]
	var mcb := func(_id: Variant, _bn: Variant, _m: Variant) -> void:
		mech_hits[0] = int(mech_hits[0]) + 1
	boss_mechanic_telegraphed.connect(mcb)

	var ev: Dictionary = enter_dungeon(did, pl, true)
	print("[DUNGEON_TEST] enter '%s' -> ok=%s" % [did, str(ev.get("ok"))])
	if not bool(ev.get("ok", false)):
		fails.append("enter_dungeon failed: %s" % str(ev.get("reason")))

	var guard := 0
	while not waves_cleared() and guard < 20:
		advance_wave()
		guard += 1
	print("[DUNGEON_TEST] trash waves cleared = %s" % str(waves_cleared()))
	if not waves_cleared():
		fails.append("waves did not clear")

	var eng: Dictionary = engage_boss(0)
	print("[DUNGEON_TEST] engage boss -> %s (phase '%s')" % [
		str(eng.get("name")), str(current_boss().get("phase_name"))])

	# Drive the mechanic telegraph loop by hand (advance a few _process frames).
	for _f in range(3):
		_dbg_tick(1.5)
	# Damage the boss down in chunks; every chunk re-evaluates the phase machine.
	var boss_max: float = float(current_boss().get("max_hp", 1.0))
	var killed := false
	guard = 0
	while not killed and guard < 40:
		var r: Dictionary = damage_boss(boss_max * 0.12)
		killed = bool(r.get("killed", false))
		guard += 1
	var boss1_name: String = str(eng.get("name", ""))
	print("[DUNGEON_TEST] boss '%s' killed=%s ; phases seen=%s ; telegraphs=%d" % [
		boss1_name, str(killed), str(phase_log), int(mech_hits[0])])
	if not killed:
		fails.append("could not kill boss")
	if phase_log.size() < 2:
		fails.append("expected >=2 phase transitions, saw %d" % phase_log.size())
	if int(mech_hits[0]) < 1:
		fails.append("no mechanic telegraphs fired")

	# Clearing the last boss should have granted rewards + cleared the instance.
	var cleared_dungeon: bool = bool(_active.get("cleared", false))
	print("[DUNGEON_TEST] single-boss dungeon cleared flag = %s" % str(cleared_dungeon))
	if not cleared_dungeon:
		fails.append("dungeon not marked cleared after boss death")
	exit_dungeon()

	# --- 2) Reward grant proof (LootSystem + XPSystem + StatsSystem). -----------
	var lvl_before: int = _level(pl)
	var gold_before: int = int(pl.get("gold")) if _has_prop(pl, "gold") else 0
	var rw: Dictionary = _grant_rewards(did, pl)
	var lvl_after: int = _level(pl)
	var gold_after: int = int(pl.get("gold")) if _has_prop(pl, "gold") else 0
	print("[DUNGEON_TEST] reward: loot_items=%d gold %d->%d xp+%d level %d->%d blessing=%s" % [
		_arr(rw.get("loot", [])).size(), gold_before, gold_after,
		int(rw.get("xp", 0)), lvl_before, lvl_after, str(rw.get("blessing"))])
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and ss.has_method("modifier_bonus"):
		var bonus: float = float(ss.call("modifier_bonus", pl, "damage"))
		print("[DUNGEON_TEST] StatsSystem 'damage' includes dungeon blessing bonus = %.1f" % bonus)
	if not bool(rw.get("blessing", false)) and ss != null:
		fails.append("dungeon blessing modifier not applied")

	# --- 3) Multi-boss RAID: clear all bosses, prove weekly lockout. ------------
	var rid := "bloodstone_pit"
	var rev: Dictionary = enter_dungeon(rid, pl, true)
	print("[DUNGEON_TEST] enter raid '%s' -> ok=%s (bosses=%d, %d-%d players)" % [
		rid, str(rev.get("ok")), _arr(dungeon_def(rid).get("bosses", [])).size(),
		int(dungeon_def(rid).get("min_players", 0)), int(dungeon_def(rid).get("max_players", 0))])
	while not waves_cleared():
		advance_wave()
	var boss_count: int = _arr(dungeon_def(rid).get("bosses", [])).size()
	var downed := 0
	guard = 0
	while is_active() and not bool(_active.get("cleared", false)) and guard < 200:
		engage_boss(int(_active.get("boss_index", 0)))
		var bmax: float = float(current_boss().get("max_hp", 1.0))
		var k := false
		var g2 := 0
		while not k and g2 < 40:
			k = bool(damage_boss(bmax * 0.2).get("killed", false))
			g2 += 1
		if k:
			downed += 1
		guard += 1
	print("[DUNGEON_TEST] raid bosses downed = %d/%d ; cleared=%s" % [
		downed, boss_count, str(_active.get("cleared", false))])
	if downed < boss_count:
		fails.append("raid: downed %d of %d bosses" % [downed, boss_count])

	# The lockout is stamped on clear; leave the cleared instance, then prove a
	# fresh entry without force is refused until the lockout is cleared.
	var locked: bool = is_locked(rid, pl)
	exit_dungeon()
	var reenter: Dictionary = enter_dungeon(rid, pl, false)
	print("[DUNGEON_TEST] raid locked after clear = %s ; re-enter blocked = %s (%s)" % [
		str(locked), str(not bool(reenter.get("ok"))), str(reenter.get("reason"))])
	if not locked:
		fails.append("raid lockout not set after clear")
	if bool(reenter.get("ok", false)):
		fails.append("raid re-entry not blocked by lockout")
	if is_active():
		exit_dungeon()   # in case the guarded re-enter somehow opened an instance
	clear_lockout(rid, pl)
	print("[DUNGEON_TEST] lockout cleared (debug) -> locked now = %s" % str(is_locked(rid, pl)))

	# --- 4) Wipe / reset proof. -------------------------------------------------
	enter_dungeon("wolf_warrens", pl, true)
	engage_boss(0)
	damage_boss(float(current_boss().get("max_hp", 1.0)) * 0.5)
	var hp_mid: float = float(current_boss().get("hp", 0.0))
	var wiped_flag: Array = [false]
	var wcb := func(_id: Variant) -> void:
		wiped_flag[0] = true
	party_wiped.connect(wcb)
	wipe()
	party_wiped.disconnect(wcb)
	var hp_reset: float = float(current_boss().get("hp", 0.0))
	print("[DUNGEON_TEST] wipe: hp %.0f -> reset %.0f ; party_wiped signal=%s" % [
		hp_mid, hp_reset, str(wiped_flag[0])])
	if not bool(wiped_flag[0]):
		fails.append("party_wiped signal did not fire")
	if hp_reset <= hp_mid:
		fails.append("boss hp not reset after wipe")
	exit_dungeon()

	boss_phase_changed.disconnect(pcb)
	boss_mechanic_telegraphed.disconnect(mcb)

	if fails.is_empty():
		print("DUNGEON SELFTEST PASS - %d dungeons + %d raids, phases/enrage/telegraph/lockout/wipe/rewards all verified" % [
			_dungeons.size(), _raids.size()])
	else:
		print("DUNGEON SELFTEST FAIL - %s" % str(fails))
	print("[DUNGEON_TEST] ===== self-test complete =====")


## Test helper: manually pump one _process step of `dt` seconds so the enrage
## timer + telegraph cadence advance deterministically inside the self-test.
func _dbg_tick(dt: float) -> void:
	_process(dt)
