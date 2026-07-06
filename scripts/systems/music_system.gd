extends Node
## MusicSystem -- autoload (/root/MusicSystem). Build #53 "Dynamic Music Director".
## design/SCORE_BIBLE.md's adaptive layer system, delivered as a self-contained,
## boot-safe state machine. It owns a small pool of AudioStreamPlayer nodes it
## CREATES IN CODE (two crossfade beds + one stinger voice) and drives them from a
## per-zone / per-state score plan loaded from data/music.json.
##
## The whole system DEGRADES SILENTLY: the real .ogg stems are authored later
## (SCORE_BIBLE section 8), so almost every track path resolves to a file that is
## not on disk yet. When ResourceLoader.exists() says a track is absent, the
## director does NOT error -- it records `current_track`, emits its signals, and
## plays nothing. Every world hook (combat proximity, day/night, zone changes,
## quests, level-ups, deaths, discoveries, battle wins) is a GUARDED, optional
## reaction: with no live world/player it is a pure API you can call by hand.
##
## Public API:
##   set_state(state, force := false)      switch the ambient/tension/combat bed
##   push_stinger(id)                      fire a one-shot (level_up/quest_complete/death/discovery)
##   set_zone(zone_id)                     choose the per-zone exploration bed
##   duck(amount_db, seconds)              momentary music duck (whisper beats)
##   state() / zone() / track() / is_playing()
##   state_ids() / stinger_ids() / has_state(id) / has_stinger(id)
##   set_auto_react(on)                    enable/disable the world hooks
## Signals:
##   music_state_changed(old_state, new_state)
##   stinger_played(stinger_id, track)

signal music_state_changed(old_state, new_state)
signal stinger_played(stinger_id, track)

const DATA_PATH := "res://data/music.json"
const SILENT_DB := -60.0        # "off" floor for a crossfade voice
const POLL_S := 0.25            # world-reaction poll cadence (~4 Hz)
const COMBAT_SIGHT := 620.0     # px: an enemy within this pulls us into combat

# --- score plan (from JSON) -------------------------------------------------
var _states: Dictionary = {}         # state_id -> {track, volume_db, loop, ...}
var _crossfades: Dictionary = {}     # state_id -> seconds
var _zones: Dictionary = {}          # zone_id -> explore track path
var _regions: Dictionary = {}        # region -> track path
var _biomes: Dictionary = {}         # biome -> track path
var _stingers: Dictionary = {}       # stinger_id -> {track, volume_db, duck_db, duration}
var _town_zones: Dictionary = {}     # zone_id -> true
var _default_db: float = -14.0
var _ambient_state: String = "explore"
var _combat_release_s: float = 4.0

# --- live state -------------------------------------------------------------
var current_state: String = "explore"
var current_zone: String = ""
var current_track: String = ""
var last_stinger: String = ""
var last_stinger_track: String = ""

# --- audio nodes (created in code) ------------------------------------------
var _beds: Array[AudioStreamPlayer] = []   # two crossfade voices
var _cur_bed: int = 0
var _bed_tweens: Array[Tween] = [null, null]
var _bed_target_db: Array[float] = [SILENT_DB, SILENT_DB]
var _stinger_player: AudioStreamPlayer = null

# --- world reaction ---------------------------------------------------------
var _auto: bool = true
var _poll_accum: float = 0.0
var _combat_off_timer: float = 0.0
var _victory_hold: float = 0.0
var _last_seen_level: int = -1
var _was_alive: bool = true
var _last_zone_probe: String = ""

# --- optional debug HUD (RH_MUSIC_HUD) --------------------------------------
var _hud: CanvasLayer = null
var _hud_label: Label = null


func _ready() -> void:
	_load_data()
	_build_players()
	current_state = ""
	# Selftest wants a deterministic, world-free API run: disable the poll hooks.
	if not OS.get_environment("RH_MUSIC_TEST").is_empty():
		_auto = false
	# Establish the opening bed (default explore/ambient) without a real world.
	set_state(str(_first_nonempty(_ambient_state, "explore")), true)
	if OS.get_environment("RH_MUSIC_HUD") != "":
		_build_hud()
	set_process(_auto)
	if _auto:
		call_deferred("_connect_world")
	if not OS.get_environment("RH_MUSIC_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_states = _dict(root.get("states", {}))
	_crossfades = _dict(root.get("crossfades", {}))
	_zones = _dict(root.get("zones", {}))
	_regions = _dict(root.get("regions", {}))
	_biomes = _dict(root.get("biomes", {}))
	_stingers = _dict(root.get("stingers", {}))
	_default_db = float(root.get("default_volume_db", -14.0))
	_ambient_state = str(root.get("ambient_state", "explore"))
	_combat_release_s = float(root.get("combat_release_s", 4.0))
	for z_v: Variant in _arr(root.get("town_zones", [])):
		_town_zones[str(z_v)] = true
	if _states.is_empty():
		push_warning("MusicSystem: no states loaded from %s" % DATA_PATH)


func _build_players() -> void:
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.name = "MusicBed%d" % i
		p.bus = "Master"
		p.volume_db = SILENT_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS   # music plays through pause menu
		p.add_to_group("music")                      # pause_menu volume control reaches it
		add_child(p)
		_beds.append(p)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = "MusicStinger"
	_stinger_player.bus = "Master"
	_stinger_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_stinger_player.add_to_group("music")
	add_child(_stinger_player)


# --- Public API -------------------------------------------------------------

## Switch the running bed to `state`. Unknown states are a guarded no-op. Setting
## the same state again is ignored unless `force`. Always records current_track
## and emits music_state_changed; only actually plays audio when the stem exists.
func set_state(state: String, force := false) -> void:
	if not _states.has(state):
		push_warning("MusicSystem.set_state: unknown state '%s'" % state)
		return
	if state == current_state and not force:
		return
	var prev: String = current_state
	current_state = state
	var track: String = _resolve_track(state)
	var vol: float = float(_dict(_states.get(state, {})).get("volume_db", _default_db))
	var loop: bool = bool(_dict(_states.get(state, {})).get("loop", true))
	_crossfade_to(track, _fade_for(state), loop, vol)
	if state == "victory":
		_victory_hold = float(_dict(_states.get(state, {})).get("hold", 6.0))
	music_state_changed.emit(prev, state)
	_update_hud()


## Fire a one-shot stinger over the current bed (guarded, silent if absent).
func push_stinger(id: String) -> void:
	if not _stingers.has(id):
		push_warning("MusicSystem.push_stinger: unknown stinger '%s'" % id)
		return
	var d: Dictionary = _dict(_stingers[id])
	var track: String = str(d.get("track", ""))
	last_stinger = id
	last_stinger_track = track
	var stream: AudioStream = _load_stream(track)
	if stream != null and _stinger_player != null:
		_stinger_player.stream = stream
		_stinger_player.volume_db = float(d.get("volume_db", -8.0))
		_stinger_player.play()
		duck(float(d.get("duck_db", -6.0)), float(d.get("duration", 2.0)))
	stinger_played.emit(id, track)
	_update_hud()


## Choose the per-zone exploration bed. If we are currently sitting on an ambient
## state (explore/town/night), re-resolve it so the new zone's bed takes over.
func set_zone(zone_id: String) -> void:
	if zone_id == current_zone:
		return
	current_zone = zone_id
	if _is_ambient_state(current_state):
		set_state(_ambient_for_zone(), true)
	_update_hud()


## Momentary music duck (whisper beats / hammers-stop). Lowers the active bed by
## `amount_db` and restores it over the same span. Guarded: no-op with no stream.
func duck(amount_db: float, seconds: float) -> void:
	var p: AudioStreamPlayer = _beds[_cur_bed]
	if p == null or p.stream == null or not p.playing:
		return
	var base: float = _bed_target_db[_cur_bed]
	_kill_bed_tween(_cur_bed)
	var half: float = maxf(0.05, seconds * 0.35)
	var tw := create_tween()
	_bed_tweens[_cur_bed] = tw
	tw.tween_property(p, "volume_db", base + amount_db, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, seconds - half * 2.0))
	tw.tween_property(p, "volume_db", base, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func set_auto_react(on: bool) -> void:
	_auto = on
	set_process(on)


func state() -> String:
	return current_state


func zone() -> String:
	return current_zone


func track() -> String:
	return current_track


func is_playing() -> bool:
	for p: AudioStreamPlayer in _beds:
		if p != null and p.playing:
			return true
	return false


func state_ids() -> Array:
	return _states.keys()


func stinger_ids() -> Array:
	return _stingers.keys()


func has_state(id: String) -> bool:
	return _states.has(id)


func has_stinger(id: String) -> bool:
	return _stingers.has(id)


# --- Track resolution -------------------------------------------------------

func _resolve_track(state: String) -> String:
	# Ambient states ride the per-zone bed; combat-family states use the global stem.
	if _is_ambient_state(state):
		if state == "town" or state == "night":
			var t: String = str(_dict(_states.get(state, {})).get("track", ""))
			# A zone bed still wins for town/night if the zone author gave one and
			# the global town/night stem is missing on disk (keeps it local).
			if t != "" and ResourceLoader.exists(t):
				return t
			var zt: String = _zone_track()
			return zt if zt != "" else t
		var zbed: String = _zone_track()
		if zbed != "":
			return zbed
	return str(_dict(_states.get(state, {})).get("track", ""))


func _zone_track() -> String:
	if current_zone == "":
		return str(_dict(_states.get("explore", {})).get("track", ""))
	if _zones.has(current_zone):
		return str(_zones[current_zone])
	var zdef: Dictionary = _zone_def(current_zone)
	var region: String = str(zdef.get("region", ""))
	if region != "" and _regions.has(region):
		return str(_regions[region])
	var biome: String = str(zdef.get("biome", ""))
	if biome != "" and _biomes.has(biome):
		return str(_biomes[biome])
	return str(_dict(_states.get("explore", {})).get("track", ""))


## Region/biome for a zone id, read from the ZoneDefs global class (parse-safe;
## it is a project class_name). {} for an unknown id.
func _zone_def(zone_id: String) -> Dictionary:
	if zone_id == "":
		return {}
	var v: Variant = ZoneDefs.zone(zone_id)
	return v if v is Dictionary else {}


func _is_ambient_state(state: String) -> bool:
	return state == "explore" or state == "town" or state == "night"


func _ambient_for_zone() -> String:
	# Town beds for capital/village zones; night bed when the world says it is night.
	if _town_zones.has(current_zone) or bool(_zone_def(current_zone).get("capital", false)):
		if _states.has("town"):
			return "town"
	if _is_night() and _states.has("night"):
		return "night"
	return "explore"


func _fade_for(state: String) -> float:
	if _crossfades.has(state):
		return float(_crossfades[state])
	return float(_crossfades.get("default", 1.5))


# --- Crossfade engine -------------------------------------------------------

func _crossfade_to(new_track: String, fade: float, loop: bool, vol: float) -> void:
	current_track = new_track
	var stream: AudioStream = _load_stream(new_track)
	var new_idx: int = 1 - _cur_bed
	var old_idx: int = _cur_bed
	var np: AudioStreamPlayer = _beds[new_idx]
	var op: AudioStreamPlayer = _beds[old_idx]
	_kill_bed_tween(new_idx)
	_kill_bed_tween(old_idx)
	# Fade the outgoing voice down (and stop it once silent) if it is sounding.
	if op != null and op.playing:
		_tween_bed(old_idx, SILENT_DB, fade, true)
	elif op != null:
		op.stop()
	# Bring up the incoming voice, or stay silent if the stem is not on disk.
	if stream != null and np != null:
		_apply_loop(stream, loop)
		np.stream = stream
		np.volume_db = SILENT_DB
		np.play()
		_tween_bed(new_idx, vol, fade, false)
	elif np != null:
		np.stop()
		np.stream = null
		_bed_target_db[new_idx] = vol
	_cur_bed = new_idx


func _tween_bed(idx: int, to_db: float, dur: float, stop_after: bool) -> void:
	var p: AudioStreamPlayer = _beds[idx]
	if p == null:
		return
	_bed_target_db[idx] = to_db
	_kill_bed_tween(idx)
	if dur <= 0.0:
		p.volume_db = to_db
		if stop_after:
			p.stop()
		return
	var tw := create_tween()
	_bed_tweens[idx] = tw
	tw.tween_property(p, "volume_db", to_db, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if stop_after:
		tw.tween_callback(p.stop)


func _kill_bed_tween(idx: int) -> void:
	var tw: Tween = _bed_tweens[idx]
	if tw != null and tw.is_valid():
		tw.kill()
	_bed_tweens[idx] = null


func _load_stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	return res as AudioStream


func _apply_loop(stream: AudioStream, loop: bool) -> void:
	if stream == null:
		return
	# OggVorbis/MP3 expose `loop`; WAV exposes `loop_mode`. Set whichever exists.
	if _has_prop(stream, "loop"):
		stream.set("loop", loop)
	elif _has_prop(stream, "loop_mode"):
		stream.set("loop_mode", 1 if loop else 0)   # 1 = LOOP_FORWARD on AudioStreamWAV


# --- World reactions (all guarded; pure API when the world is absent) --------

func _connect_world() -> void:
	# Quests -> quest_complete stinger.
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs != null and qs.has_signal("quest_completed") \
			and not qs.is_connected("quest_completed", _on_quest_completed):
		qs.connect("quest_completed", _on_quest_completed)
	# Travel discoveries -> discovery stinger.
	var ts: Node = get_node_or_null("/root/TravelSystem")
	if ts != null and ts.has_signal("station_discovered") \
			and not ts.is_connected("station_discovered", _on_station_discovered):
		ts.connect("station_discovered", _on_station_discovered)
	# Map zone reveals -> discovery stinger.
	var ms: Node = get_node_or_null("/root/MapSystem")
	if ms != null and ms.has_signal("zone_revealed") \
			and not ms.is_connected("zone_revealed", _on_zone_revealed):
		ms.connect("zone_revealed", _on_zone_revealed)
	# Scripted battles -> victory bed on a win.
	var bs: Node = get_node_or_null("/root/BattleSystem")
	if bs != null and bs.has_signal("battle_won") \
			and not bs.is_connected("battle_won", _on_battle_won):
		bs.connect("battle_won", _on_battle_won)
	# Day/night -> re-pick the ambient bed when not fighting.
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	if dn != null and dn.has_signal("night_changed") \
			and not dn.is_connected("night_changed", _on_night_changed):
		dn.connect("night_changed", _on_night_changed)


func _process(delta: float) -> void:
	if not _auto:
		return
	if _victory_hold > 0.0:
		_victory_hold -= delta
	_poll_accum += delta
	if _poll_accum < POLL_S:
		return
	var dt: float = _poll_accum
	_poll_accum = 0.0
	var pl: Node = _player()
	if pl == null:
		return   # no world -> pure API, do not drive states
	_probe_zone()
	_probe_level_and_death(pl)
	_drive_combat(pl, dt)


func _probe_zone() -> void:
	var scn: Node = get_tree().current_scene
	if scn == null or not _has_prop(scn, "current_map_id"):
		return
	var mid: String = str(scn.get("current_map_id"))
	if mid != "" and mid != _last_zone_probe:
		_last_zone_probe = mid
		set_zone(mid)


func _probe_level_and_death(pl: Node) -> void:
	if _has_prop(pl, "level"):
		var lv: int = int(pl.get("level"))
		if _last_seen_level < 0:
			_last_seen_level = lv
		elif lv > _last_seen_level:
			_last_seen_level = lv
			push_stinger("level_up")
	if _has_prop(pl, "hp"):
		var alive: bool = float(pl.get("hp")) > 0.0
		if _was_alive and not alive:
			push_stinger("death")
		_was_alive = alive


func _drive_combat(pl: Node, dt: float) -> void:
	if _victory_hold > 0.0:
		return   # let a victory bed breathe before combat can re-grab
	var ppos: Vector2 = _node_pos(pl)
	var in_combat: bool = false
	var boss_near: bool = false
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or bool(n.get("is_dead")):
			continue
		if _node_pos(n).distance_to(ppos) > COMBAT_SIGHT:
			continue
		in_combat = true
		if str(n.get("rank")) == "boss":
			boss_near = true
			break
	if in_combat:
		_combat_off_timer = _combat_release_s
		var want: String = "boss" if boss_near else "combat"
		if current_state != want:
			set_state(want)
	else:
		if _combat_off_timer > 0.0:
			_combat_off_timer -= dt
		elif current_state == "combat" or current_state == "boss" or current_state == "tension":
			set_state(_ambient_for_zone())


func _on_quest_completed(_a: Variant = null, _b: Variant = null) -> void:
	push_stinger("quest_complete")


func _on_station_discovered(_station_id: Variant = null) -> void:
	push_stinger("discovery")


func _on_zone_revealed(_zone_id: Variant = null) -> void:
	push_stinger("discovery")


func _on_battle_won(_id: Variant = null) -> void:
	set_state("victory")


func _on_night_changed(_is_night_now: Variant = null) -> void:
	if _is_ambient_state(current_state):
		set_state(_ambient_for_zone(), true)


# --- optional debug HUD -----------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "MusicHUD"
	_hud.layer = 90
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.modulate = Color(1, 1, 1, 0.85)
	_hud.add_child(panel)
	_hud_label = Label.new()
	_hud_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(_hud_label)
	_update_hud()


func _update_hud() -> void:
	if _hud_label == null:
		return
	var mark: String = "PLAY" if is_playing() else "silent"
	_hud_label.text = "MUSIC  state=%s  zone=%s  [%s]\n%s" % [
		current_state, current_zone if current_zone != "" else "-", mark,
		current_track if current_track != "" else "(none)"]


# --- helpers ----------------------------------------------------------------

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _is_night() -> bool:
	var dn: Node = get_tree().get_first_node_in_group("day_night")
	return dn != null and bool(dn.get("is_night"))


func _node_pos(n: Node) -> Vector2:
	if n is Node2D:
		return (n as Node2D).global_position
	return Vector2.ZERO


func _first_nonempty(a: String, b: String) -> String:
	return a if a != "" else b


func _has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == prop:
			return true
	return false


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("MusicSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _arr(v: Variant) -> Array:
	return v if v is Array else []


# --- Self-test (RH_MUSIC_TEST=1) --------------------------------------------

func _run_selftest() -> void:
	var errs: Array[String] = []
	# Capture the state/stinger signals to prove they fire.
	var got_states: Array = []
	var got_stingers: Array = []
	var scb := func(_old: Variant, new_s: Variant) -> void: got_states.append(str(new_s))
	var pcb := func(sid: Variant, _t: Variant) -> void: got_stingers.append(str(sid))
	music_state_changed.connect(scb)
	stinger_played.connect(pcb)

	print("[MUSIC] ===== Raven Hollow dynamic music director self-test =====")
	print("[MUSIC] states loaded = %d ; stingers = %d ; zones = %d" % [
		_states.size(), _stingers.size(), _zones.size()])

	# Pick a zone bed (guarded; no world needed).
	set_zone("vetka")
	print("[MUSIC] set_zone('vetka') -> zone=%s bed=%s" % [current_zone, current_track])

	# Drive the arc and assert current_track changes on each transition.
	var seq: Array[String] = ["explore", "combat", "boss", "victory"]
	var tracks: Array[String] = []
	var prev_track: String = "<none>"
	for st: String in seq:
		set_state(st, true)
		var tr: String = current_track
		var changed: bool = tr != prev_track
		print("[MUSIC] state '%s' -> track '%s'  changed=%s  playing=%s" % [
			st, tr if tr != "" else "(silent/absent)", str(changed), str(is_playing())])
		if current_state != st:
			errs.append("state did not apply: %s" % st)
		if not changed:
			errs.append("track unchanged at state: %s" % st)
		tracks.append(tr)
		prev_track = tr

	# Push a stinger over the current bed.
	push_stinger("level_up")
	print("[MUSIC] push_stinger('level_up') -> last=%s track=%s" % [
		last_stinger, last_stinger_track if last_stinger_track != "" else "(absent)"])
	if last_stinger != "level_up":
		errs.append("stinger not recorded")
	if got_stingers.is_empty():
		errs.append("stinger_played never emitted")

	# Signal-count sanity: 1 (opening explore in _ready is pre-connect) + 4 here.
	if got_states.size() < seq.size():
		errs.append("music_state_changed under-emitted (%d < %d)" % [got_states.size(), seq.size()])

	# Duck must not crash with an absent/silent bed.
	duck(-8.0, 1.0)

	music_state_changed.disconnect(scb)
	stinger_played.disconnect(pcb)

	if errs.is_empty():
		print("[MUSIC] SELFTEST PASS  arc=%s stinger=%s no-crash-silent=OK" % [
			str(seq), last_stinger])
	else:
		print("[MUSIC] SELFTEST FAIL  %s" % str(errs))
	print("[MUSIC] ===== self-test complete =====")
