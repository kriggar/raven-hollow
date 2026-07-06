extends Node
## BattleSystem -- autoload (/root/BattleSystem). Backlog #50 "THE GREAT BATTLE".
## The scripted army set-piece ("The Second Cooperation", design/GREAT_BATTLE.md):
## a data-driven battle director that plays waves of allied-vs-enemy pressure with
## objectives (survive N seconds / defend an NPC / push the line), a scripted boss
## finale, and morale + reinforcement counters -- then grants rewards on victory.
## It fires the CinematicSystem at the start and on victory (guarded), self-instances
## a battle HUD (objective text + ally/enemy counters + a morale bar) that stays
## hidden until a battle is active, and drives everything from data/great_battle.json.
##
## Everything here is additive and null-safe: no other system's file is edited.
## Enemy waves spawn real Enemy nodes when a live world + player exist (guarded via
## Enemy.create); otherwise the battle runs as a pure simulation (headless / the
## selftest), spawning nothing. Reward granting routes through LootSystem +
## StatsSystem + TitleSystem when they are present, and no-ops when they are not.
##
## Public API:
##   start_battle(id := "") -> void   run a battle to win/lose (awaitable coroutine)
##   abort() -> void                   cancel the running battle
##   is_active() -> bool
##   current() -> String               id of the running battle ("" if idle)
##   morale() -> float / ally_count() -> int / enemy_count() -> int
##   battle_def(id) -> Dictionary / ids() -> Array
## Signals: battle_started(id), objective_updated(text, current, total),
##   battle_won(id), battle_lost(id).

signal battle_started(id)
signal objective_updated(text, current, total)
signal battle_won(id)
signal battle_lost(id)

const DATA_PATH := "res://data/great_battle.json"
const FONT_PATH := "res://assets/fonts/alagard.ttf"
const CANVAS_LAYER := 82

const PLAYER_DPS_EST := 16.0            # the player's own per-tick contribution
const MORALE_LOSS_PER_BREAKTHROUGH := 1.4
const BOSS_MORALE_DRAIN := 0.5
const TICK_GUARD := 400                 # per-phase safety cap (never hang)

var _battles: Dictionary = {}           # id -> battle def
var _cfg: Dictionary = {}
var _default_id: String = ""

var _active: bool = false
var _battle_id: String = ""
var _def: Dictionary = {}
var _time_scale: float = 1.0            # <1.0 accelerates (selftest)
var _visual: bool = true               # spawn/keep world nodes (off in selftest)
var _won_flag: bool = false
var _obj_events: int = 0

# --- Live battle state ---
var _morale: float = 100.0
var _ally_count: int = 0
var _enemy_alive: int = 0
var _reinforcements: int = 0
var _spawned: Array = []                # live Enemy / marker nodes

# --- Self-instanced HUD (built lazily) ---
var _hud_layer: CanvasLayer = null
var _obj_label: Label = null
var _ally_label: Label = null
var _enemy_label: Label = null
var _reinf_label: Label = null
var _morale_fill: ColorRect = null
var _morale_bg: ColorRect = null


func _ready() -> void:
	_load_data()
	if not OS.get_environment("RH_BATTLE_TEST").is_empty() \
			or not OS.get_environment("RH_BATTLE").is_empty():
		call_deferred("_run_env_hooks")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_cfg = _dict(root.get("config", {}))
	_battles = _dict(root.get("battles", {}))
	var keys: Array = _battles.keys()
	_default_id = str(keys[0]) if not keys.is_empty() else ""
	if _battles.is_empty():
		push_warning("BattleSystem: no battles loaded from %s" % DATA_PATH)


# --- Public API -------------------------------------------------------------

func ids() -> Array:
	return _battles.keys()


func battle_def(id: String) -> Dictionary:
	return _dict(_battles.get(id, {}))


func is_active() -> bool:
	return _active


func current() -> String:
	return _battle_id


func morale() -> float:
	return _morale


func ally_count() -> int:
	return _ally_count


func enemy_count() -> int:
	return _enemy_alive


## Run a full battle. Awaitable: the selftest and scripted callers may
## `await start_battle(id)`; fire-and-forget callers just kick it off.
func start_battle(id: String = "") -> void:
	if _active:
		return
	if id == "":
		id = _default_id
	var def: Dictionary = battle_def(id)
	if def.is_empty():
		push_warning("BattleSystem: unknown battle '%s'" % id)
		return
	_active = true
	_battle_id = id
	_def = def
	_won_flag = false
	_obj_events = 0
	_morale = float(def.get("start_morale", 100.0))
	_ally_count = int(def.get("start_allies", 12))
	_reinforcements = int(def.get("reinforcements", 30))
	_enemy_alive = 0
	_ensure_hud()
	_hud_layer.visible = true
	_trigger_cinematic(str(def.get("intro_cinematic", "")))
	battle_started.emit(id)
	_refresh_hud("The muster forms...")
	await _run_battle()


func abort() -> void:
	if not _active:
		return
	_active = false
	_cleanup()


# --- Battle spine -----------------------------------------------------------

func _run_battle() -> void:
	for wave_v: Variant in _arr(_def.get("waves", [])):
		if not _active:
			return
		await _run_wave(_dict(wave_v))
		if not _active:
			return   # lost mid-wave
	if not _active:
		return
	await _run_boss(_dict(_def.get("boss", {})))
	if not _active:
		return
	_win()


func _run_wave(wave: Dictionary) -> void:
	var objective: String = str(wave.get("objective", "survive"))
	var text: String = str(wave.get("objective_text", "Hold the line"))
	var enemy_total: int = int(wave.get("enemy_count", 10))
	var ally_dps: float = float(wave.get("ally_dps", 6.0))
	var spawn_interval: float = maxf(0.25, float(wave.get("spawn_interval", 2.0)))
	var tick_interval: float = maxf(0.1, float(_cfg.get("tick_interval", 1.0)))
	var spawn_per_tick: int = maxi(1, int(ceil(tick_interval / spawn_interval)))

	var enemy_spawned: int = 0
	var obj_timer: float = 0.0
	var line: float = 0.0
	var npc_hp: float = float(wave.get("npc_hp", 200.0))
	var seconds: float = float(wave.get("seconds", 20.0))
	var distance: float = float(wave.get("distance", 100.0))

	_emit_objective(text)
	var guard: int = 0
	while _active and guard < TICK_GUARD:
		guard += 1
		# Spawn.
		if enemy_spawned < enemy_total:
			var n: int = mini(spawn_per_tick, enemy_total - enemy_spawned)
			enemy_spawned += n
			_enemy_alive += n
			_spawn_units(wave, n)
		# Combat resolution (abstract units per tick).
		var kill_power: int = maxi(3, int(round((ally_dps + PLAYER_DPS_EST) * 0.4)))
		_enemy_alive = maxi(0, _enemy_alive - kill_power)
		var breakthrough: int = maxi(0, _enemy_alive - _ally_count)
		_morale = maxf(0.0, _morale - float(breakthrough) * MORALE_LOSS_PER_BREAKTHROUGH)
		_take_casualties(breakthrough)
		_reinforce()
		# Objective progress.
		var done: bool = false
		match objective:
			"survive":
				obj_timer += tick_interval
				done = obj_timer >= seconds
				_emit_objective("%s (%ds/%ds)" % [text, int(obj_timer), int(seconds)])
			"defend_npc":
				npc_hp = maxf(0.0, npc_hp - float(maxi(0, _enemy_alive - 4)) * 4.0)
				if npc_hp <= 0.0:
					_morale = maxf(0.0, _morale - 2.0)   # fail-forward: wounded, not lost
				done = enemy_spawned >= enemy_total and _enemy_alive <= 0
				_emit_objective("%s -- %d%% health" % [text, int(npc_hp / maxf(1.0, float(wave.get("npc_hp", 200.0))) * 100.0)])
			"push_line":
				line += (12.0 if _enemy_alive < 6 else 4.0)
				done = line >= distance
				_emit_objective("%s (%d%%)" % [text, int(minf(100.0, line / maxf(1.0, distance) * 100.0))])
			_:
				done = enemy_spawned >= enemy_total and _enemy_alive <= 0
		_refresh_hud("")
		if _morale <= 0.0:
			_lose()
			return
		if done:
			break
		await _tick_wait(tick_interval)


func _run_boss(boss: Dictionary) -> void:
	if boss.is_empty():
		return
	var boss_hp: float = float(boss.get("hp", 800.0))
	var boss_max: float = boss_hp
	var player_dps: float = float(boss.get("player_dps", 45.0))
	var ally_dps: float = float(boss.get("ally_dps", 10.0))
	var text: String = str(boss.get("objective_text", "Break the champion"))
	var tick_interval: float = maxf(0.1, float(_cfg.get("tick_interval", 1.0)))
	_enemy_alive = 1
	_spawn_units({"enemy_type": str(boss.get("type", "skeleton_warrior")),
			"enemy_name": str(boss.get("name", "Champion")),
			"enemy_hp": boss_max, "enemy_level": int(boss.get("level", 58)),
			"rank": str(boss.get("rank", "elite")), "is_boss": true}, 1)
	_emit_objective(text)
	var guard: int = 0
	while _active and boss_hp > 0.0 and guard < TICK_GUARD:
		guard += 1
		boss_hp = maxf(0.0, boss_hp - (player_dps + ally_dps))
		_morale = maxf(0.0, _morale - BOSS_MORALE_DRAIN)
		_reinforce()
		_emit_objective("%s -- %d%%" % [text, int(boss_hp / maxf(1.0, boss_max) * 100.0)])
		_refresh_hud("")
		if _morale <= 0.0:
			_lose()
			return
		await _tick_wait(tick_interval)
	_enemy_alive = 0
	_clear_spawned()


func _take_casualties(pressure: int) -> void:
	var losses: int = mini(_ally_count, int(floor(float(pressure) * 0.5)))
	_ally_count = maxi(0, _ally_count - losses)


func _reinforce() -> void:
	var threshold: int = int(_cfg.get("reinforce_threshold", 6))
	var batch: int = int(_cfg.get("reinforce_batch", 4))
	while _ally_count < threshold and _reinforcements > 0:
		var take: int = mini(batch, _reinforcements)
		_reinforcements -= take
		_ally_count += take


# --- Win / lose -------------------------------------------------------------

func _win() -> void:
	_won_flag = true
	_grant_rewards()
	_trigger_cinematic(str(_def.get("victory_cinematic", "")))
	_refresh_hud("Victory -- the door stands open")
	_active = false
	battle_won.emit(_battle_id)
	_cleanup()


func _lose() -> void:
	_refresh_hud("The line breaks...")
	_active = false
	battle_lost.emit(_battle_id)
	_cleanup()


func _grant_rewards() -> void:
	var pl: Node = _player()
	var r: Dictionary = _dict(_def.get("rewards", {}))
	# XP (guarded: only a leveling actor).
	if pl != null and _has_prop(pl, "level"):
		XPSystem.grant_xp(pl, int(r.get("xp", 0)))
	# Gold.
	if pl != null and _has_prop(pl, "gold"):
		pl.set("gold", _gold(pl) + int(r.get("gold", 0)))
	# Loot via LootSystem (table + explicit items).
	var ls: Node = get_node_or_null("/root/LootSystem")
	if ls != null:
		var table: String = str(r.get("loot_table", ""))
		if table != "" and ls.has_method("roll_loot"):
			for it_v: Variant in _arr(ls.call("roll_loot", table, 0.0)):
				_file_item(pl, it_v)
		if ls.has_method("roll_item"):
			for iid_v: Variant in _arr(r.get("items", [])):
				var it: Variant = ls.call("roll_item", str(iid_v), "")
				if it is Dictionary and not (it as Dictionary).is_empty():
					_file_item(pl, it)
	# StatsSystem: a lasting Battle-Honor buff (guarded, reversible source key).
	var ss: Node = get_node_or_null("/root/StatsSystem")
	if ss != null and pl != null and ss.has_method("add_modifier"):
		ss.call("add_modifier", pl, "great_battle:honor", "strength", 5.0)
	# TitleSystem war-title (unknown ids fail silently).
	var ts: Node = get_node_or_null("/root/TitleSystem")
	if ts != null and pl != null and ts.has_method("grant_title") and str(r.get("title", "")) != "":
		ts.call("grant_title", pl, str(r.get("title", "")))


func _file_item(pl: Node, item_v: Variant) -> void:
	if pl == null or not (item_v is Dictionary):
		return
	var item: Dictionary = item_v
	var inv: Variant = pl.get("inventory")
	if inv is Object and (inv as Object).has_method("add_item"):
		(inv as Object).call("add_item", item)
		return
	var isys: Node = get_node_or_null("/root/InventorySystem")
	if isys != null and isys.has_method("add_item"):
		isys.call("add_item", pl, item)


# --- Enemy spawning (guarded; real nodes only with a live world) ------------

func _spawn_units(cfg: Dictionary, n: int) -> void:
	if not _visual or n <= 0:
		return
	var parent: Node = _world_parent()
	if parent == null:
		return
	var use_real: bool = _player() != null and parent == get_tree().current_scene
	var anchor: Vector2 = _anchor_pos()
	for i in range(n):
		var off := Vector2(randf_range(-260.0, 260.0), randf_range(-220.0, -60.0))
		var node: Node2D = null
		if use_real:
			node = _make_real_enemy(cfg, anchor + off)
		if node == null:
			node = _make_marker(cfg, anchor + off)
		if node != null:
			parent.add_child(node)
			_spawned.append(node)


func _make_real_enemy(cfg: Dictionary, pos: Vector2) -> Node2D:
	var ecfg := {
		"type": str(cfg.get("enemy_type", "skeleton")),
		"display_name": str(cfg.get("enemy_name", "Thread-Slipped Dead")),
		"pos": pos,
		"hp": float(cfg.get("enemy_hp", 120.0)),
		"damage": 14.0,
		"speed": 60.0,
		"level": int(cfg.get("enemy_level", 55)),
		"rank": str(cfg.get("rank", "normal")),
		"archetype": "brute",
	}
	var e: Enemy = Enemy.create(ecfg)
	return e


func _make_marker(cfg: Dictionary, pos: Vector2) -> Node2D:
	var holder := Node2D.new()
	holder.name = "BattleMarker"
	holder.global_position = pos
	holder.z_index = 40
	holder.add_to_group("enemies")
	var big: bool = bool(cfg.get("is_boss", false))
	var body := Polygon2D.new()
	var r: float = 22.0 if big else 10.0
	body.polygon = _ellipse(r * 0.6, r, Vector2(0.0, -r))
	body.color = Color(0.55, 0.16, 0.16) if big else Color(0.35, 0.3, 0.34)
	holder.add_child(body)
	return holder


func _clear_spawned() -> void:
	for n: Variant in _spawned:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_spawned.clear()


# --- Cinematic trigger (guarded) --------------------------------------------

func _trigger_cinematic(cine_id: String) -> void:
	if cine_id == "":
		return
	var cs: Node = get_node_or_null("/root/CinematicSystem")
	if cs != null and cs.has_method("has_cinematic") and cs.has_method("play") \
			and bool(cs.call("has_cinematic", cine_id)):
		cs.call("play", cine_id)   # fire-and-forget; the battle HUD sits behind it


# --- HUD --------------------------------------------------------------------

func _ensure_hud() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = CANVAS_LAYER
	_hud_layer.visible = false
	add_child(_hud_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root)

	# Objective banner (top center).
	var obj_panel := _panel(Color(0.06, 0.05, 0.04, 0.9), Color(0.62, 0.5, 0.28, 0.9))
	obj_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	obj_panel.position = Vector2(-230.0, 20.0)
	obj_panel.custom_minimum_size = Vector2(460.0, 0.0)
	root.add_child(obj_panel)
	_obj_label = _make_label("", 15, Color(0.92, 0.78, 0.42))
	_obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_label.custom_minimum_size = Vector2(440.0, 0.0)
	obj_panel.add_child(_obj_label)

	# Counters + morale (top left).
	var info := _panel(Color(0.06, 0.05, 0.04, 0.9), Color(0.5, 0.42, 0.28, 0.8))
	info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info.position = Vector2(20.0, 20.0)
	root.add_child(info)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	info.add_child(vb)
	_ally_label = _make_label("Allies: 0", 12, Color(0.6, 0.82, 0.6))
	vb.add_child(_ally_label)
	_enemy_label = _make_label("Enemy: 0", 12, Color(0.86, 0.5, 0.42))
	vb.add_child(_enemy_label)
	_reinf_label = _make_label("Reinforcements: 0", 11, Color(0.78, 0.74, 0.64))
	vb.add_child(_reinf_label)
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(220.0, 16.0)
	vb.add_child(bar_holder)
	_morale_bg = ColorRect.new()
	_morale_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	_morale_bg.position = Vector2.ZERO
	_morale_bg.size = Vector2(220.0, 16.0)
	_morale_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.add_child(_morale_bg)
	_morale_fill = ColorRect.new()
	_morale_fill.color = Color(0.72, 0.6, 0.24, 0.95)
	_morale_fill.position = Vector2.ZERO
	_morale_fill.size = Vector2(220.0, 16.0)
	_morale_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.add_child(_morale_fill)
	var morale_cap := _make_label("MORALE", 9, Color(0.95, 0.92, 0.85))
	morale_cap.position = Vector2(4.0, 1.0)
	bar_holder.add_child(morale_cap)


func _refresh_hud(obj_override: String) -> void:
	if _hud_layer == null:
		return
	if obj_override != "" and _obj_label != null:
		_obj_label.text = obj_override
	if _ally_label != null:
		_ally_label.text = "Allies: %d" % _ally_count
	if _enemy_label != null:
		_enemy_label.text = "Enemy: %d" % _enemy_alive
	if _reinf_label != null:
		_reinf_label.text = "Reinforcements: %d" % _reinforcements
	if _morale_fill != null:
		var frac: float = clampf(_morale / 100.0, 0.0, 1.0)
		_morale_fill.size = Vector2(220.0 * frac, 16.0)
		_morale_fill.color = Color(0.72, 0.6, 0.24, 0.95) if frac > 0.35 else Color(0.75, 0.28, 0.2, 0.95)


func _emit_objective(text: String) -> void:
	if _obj_label != null:
		_obj_label.text = text
	_obj_events += 1
	objective_updated.emit(text, _enemy_alive, _ally_count)


func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var f: FontFile = load(FONT_PATH) as FontFile
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _cleanup() -> void:
	_clear_spawned()
	if _hud_layer != null and is_instance_valid(_hud_layer):
		# Leave the final banner up a moment in real play; hide immediately headless.
		if _visual and get_tree() != null:
			await get_tree().create_timer(3.0).timeout
		if is_instance_valid(_hud_layer):
			_hud_layer.visible = false


# --- Env self-test / autostart hooks ----------------------------------------

func _run_env_hooks() -> void:
	for _i in range(30):
		if get_tree() == null:
			return
		await get_tree().process_frame
	if not OS.get_environment("RH_BATTLE_TEST").is_empty():
		await _selftest()
		return
	var id: String = OS.get_environment("RH_BATTLE")
	if id == "1" or id == "true":
		id = _default_id
	if not battle_def(id).is_empty():
		await start_battle(id)


func _selftest() -> void:
	print("[BATTLE_TEST] ===== Raven Hollow great-battle self-test =====")
	print("[BATTLE_TEST] loaded %d battles: %s" % [_battles.size(), str(ids())])
	var started := {"v": false}
	var won := {"v": false}
	var lost := {"v": false}
	battle_started.connect(func(_id: String) -> void: started["v"] = true)
	battle_won.connect(func(_id: String) -> void: won["v"] = true)
	battle_lost.connect(func(_id: String) -> void: lost["v"] = true)
	_time_scale = 0.01
	_visual = false                       # pure sim: spawn no world nodes
	var id: String = _default_id
	var def: Dictionary = battle_def(id)
	var waves: int = _arr(def.get("waves", [])).size()
	print("[BATTLE_TEST] '%s': %d waves + boss; start morale %.0f, allies %d, reinf %d" % [
			str(def.get("name", id)), waves, float(def.get("start_morale", 0.0)),
			int(def.get("start_allies", 0)), int(def.get("reinforcements", 0))])
	await start_battle(id)
	var ok: bool = started["v"] and won["v"] and not lost["v"] and _won_flag \
			and not _active and _obj_events >= waves + 1 and _morale > 0.0
	print("[BATTLE_TEST] started=%s won=%s lost=%s obj_updates=%d final_morale=%.0f" % [
			str(started["v"]), str(won["v"]), str(lost["v"]), _obj_events, _morale])
	print("BATTLE SELFTEST %s" % ("PASS" if ok else "FAIL"))
	print("[BATTLE_TEST] ===== self-test complete =====")
	if get_tree() != null:
		get_tree().quit(0 if ok else 1)


# --- Save contract (SaveSystem group pattern; inert until wired) -------------

func serialize() -> Dictionary:
	return {"won": _won_flag and not _active, "last": _battle_id}


func deserialize(_d: Dictionary) -> void:
	pass


# --- helpers ----------------------------------------------------------------

func _tick_wait(t: float) -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(maxf(0.001, t * _time_scale)).timeout


func _anchor_pos() -> Vector2:
	var pl: Node = _player()
	if pl is Node2D:
		return (pl as Node2D).global_position
	var vp: Viewport = get_viewport()
	if vp != null:
		var cam: Camera2D = vp.get_camera_2d()
		if cam != null:
			return cam.global_position
	return Vector2.ZERO


func _world_parent() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _player() -> Node:
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null


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


func _ellipse(rx: float, ry: float, center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("BattleSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []
