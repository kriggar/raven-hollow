extends Node
## UISoundSystem -- autoload (/root/UISoundSystem). Backlog #86
## "Menu/UI sounds via TTS-server pipeline, AAA grade".
##
## An AAA-style UI SFX layer: named menu/HUD cues (hover, click, confirm, cancel,
## error, open_panel, close_panel, purchase, equip, level_up_chime, quest_accept,
## page_turn) each mapped in data/ui_sounds.json to a logical .ogg stem + mix
## volume. The real audio is authored LATER (the TTS/foley pipeline, per the
## backlog); until those files land on disk this manager DEGRADES SILENTLY -- it
## records `last_cue`, emits `ui_cue_played`, and simply plays nothing, exactly
## like MusicSystem's guarded-silent beds.
##
## Playback rides a small pool of AudioStreamPlayer voices CREATED IN CODE, all in
## the "ui" group and PROCESS_MODE_ALWAYS so cues sound through the pause menu and
## other paused UI. The whole thing is self-contained and boot-safe: with no world,
## no player and no sibling systems it is a pure API you can call by hand.
##
## Public API:
##   play(cue, opts := {}) -> String     fire a cue; returns the resolved stem ("" if silent/absent)
##   hover() / click() / confirm() / cancel() / error()   convenience one-shots
##   open() / close() / purchase() / equip() / level_up() / quest_accept() / page_turn()
##   has_cue(cue) -> bool / cue_ids() -> Array / resolve(cue) -> String
##   set_muted(on) / is_muted() / set_master_db(db)
##   stop_all()                          silence every pool voice
##   wire_group()                        (re)connect buttons in the "ui_sfx" group
## Signals:
##   ui_cue_played(cue, track)           track == "" means it played silently (stem absent/muted)

signal ui_cue_played(cue, track)

const DATA_PATH := "res://data/ui_sounds.json"
const DEFAULT_POOL := 6

# --- cue plan (from JSON) ---------------------------------------------------
var _cues: Dictionary = {}          # cue_id -> {stream, volume_db, throttle_ms}
var _aliases: Dictionary = {}       # alias -> canonical cue_id
var _bus: String = "Master"
var _default_db: float = -10.0
var _throttle_ms: int = 40
var _pool_size: int = DEFAULT_POOL

# --- live state -------------------------------------------------------------
var last_cue: String = ""
var last_track: String = ""
var _muted: bool = false
var _master_db: float = 0.0
var _last_play_ms: Dictionary = {}  # cue_id -> ticks_msec of last audible fire

# --- audio nodes (created in code) ------------------------------------------
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _stream_cache: Dictionary = {}  # path -> AudioStream (or null when absent)


func _ready() -> void:
	_load_data()
	_build_pool()
	# Optional, fully guarded: hook any pre-tagged UI buttons. Never required.
	call_deferred("wire_group")
	# Global auto-wire: every BaseButton in the game gets hover/click cues for free,
	# now and as new ones enter the tree. Fully guarded + degrade-safe.
	call_deferred("_wire_global")
	if not OS.get_environment("RH_UISOUND_TEST").is_empty():
		call_deferred("_run_selftest")


func _load_data() -> void:
	var root: Dictionary = _read_json(DATA_PATH)
	_cues = _dict(root.get("cues", {}))
	_aliases = _dict(root.get("aliases", {}))
	_bus = str(root.get("bus", "Master"))
	_default_db = float(root.get("default_volume_db", -10.0))
	_throttle_ms = int(root.get("throttle_ms", 40))
	_pool_size = maxi(1, int(root.get("pool_size", DEFAULT_POOL)))
	if _cues.is_empty():
		push_warning("UISoundSystem: no cues loaded from %s" % DATA_PATH)


func _build_pool() -> void:
	# A safe bus fallback: if the authored bus is absent, ride Master.
	var bus_name: String = _bus if AudioServer.get_bus_index(_bus) != -1 else "Master"
	_bus = bus_name
	for i in range(_pool_size):
		var p := AudioStreamPlayer.new()
		p.name = "UIVoice%d" % i
		p.bus = bus_name
		p.process_mode = Node.PROCESS_MODE_ALWAYS   # cues sound through the pause menu
		p.add_to_group("ui")                          # options volume control can reach us
		add_child(p)
		_pool.append(p)


# --- Public API -------------------------------------------------------------

## Fire a UI cue. Resolves aliases, honors a small per-cue throttle (so a rapid
## hover storm does not machine-gun), and plays through the next free pool voice
## when the stem is on disk. Unknown cues, muted state, or an absent stem are all
## a guarded no-op that STILL records last_cue and emits ui_cue_played("").
## Returns the resolved stem path actually played, or "" when silent.
func play(cue: String, opts: Dictionary = {}) -> String:
	var id: String = _canonical(cue)
	if id == "" or not _cues.has(id):
		# Still record + emit so callers/tests see a consistent event, silently.
		last_cue = cue
		last_track = ""
		ui_cue_played.emit(cue, "")
		return ""
	last_cue = id
	var def: Dictionary = _dict(_cues[id])
	var track: String = str(def.get("stream", ""))
	var played_track: String = ""
	if not _muted and not _is_throttled(id, def):
		var stream: AudioStream = _load_stream(track)
		if stream != null:
			var voice: AudioStreamPlayer = _claim_voice()
			if voice != null:
				voice.stream = stream
				var vol: float = float(opts.get("volume_db", def.get("volume_db", _default_db)))
				voice.volume_db = vol + _master_db
				voice.pitch_scale = float(opts.get("pitch_scale", 1.0))
				voice.play()
				played_track = track
				_last_play_ms[id] = Time.get_ticks_msec()
	last_track = played_track
	ui_cue_played.emit(id, played_track)
	return played_track


# Convenience one-shots (the common HUD/menu verbs).
func hover() -> String: return play("hover")
func click() -> String: return play("click")
func confirm() -> String: return play("confirm")
func cancel() -> String: return play("cancel")
func error() -> String: return play("error")
func open() -> String: return play("open_panel")
func close() -> String: return play("close_panel")
func purchase() -> String: return play("purchase")
func equip() -> String: return play("equip")
func level_up() -> String: return play("level_up_chime")
func quest_accept() -> String: return play("quest_accept")
func page_turn() -> String: return play("page_turn")


func has_cue(cue: String) -> bool:
	return _cues.has(_canonical(cue))


func cue_ids() -> Array:
	return _cues.keys()


## The stem path a cue maps to (whether or not it exists on disk). "" if unknown.
func resolve(cue: String) -> String:
	var id: String = _canonical(cue)
	if not _cues.has(id):
		return ""
	return str(_dict(_cues[id]).get("stream", ""))


func set_muted(on: bool) -> void:
	_muted = on
	if on:
		stop_all()


func is_muted() -> bool:
	return _muted


## Global trim added to every cue's authored volume (options slider hook).
func set_master_db(db: float) -> void:
	_master_db = db


func stop_all() -> void:
	for p: AudioStreamPlayer in _pool:
		if p != null and p.playing:
			p.stop()


# --- Optional auto-wire (buttons in group "ui_sfx") -------------------------

## Best-effort, fully optional: any BaseButton placed in the "ui_sfx" group gets
## hover + click cues wired for free. Requires nothing -- if the group is empty
## (the usual case) this is a silent no-op. Safe to call repeatedly.
func wire_group() -> void:
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group("ui_sfx"):
		if n is BaseButton:
			var b := n as BaseButton
			if not b.is_connected("mouse_entered", _on_button_hover):
				b.connect("mouse_entered", _on_button_hover)
			if not b.is_connected("pressed", _on_button_pressed):
				b.connect("pressed", _on_button_pressed)


func _on_button_hover() -> void:
	hover()


func _on_button_pressed() -> void:
	click()


# --- Global auto-wire (EVERY BaseButton, no per-scene edits) -----------------

## Make the whole UI audio-reactive without touching any other file. We connect
## once to the tree's node_added signal (so every button spawned later is wired
## the moment it enters), then do a single sweep over the current tree. Buttons
## are deduped -- each hover/click is bound at most once -- and every step is
## guarded so odd nodes, freed nodes, or a missing tree can never crash this.
func _wire_global() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if not tree.is_connected("node_added", _on_node_added):
		tree.connect("node_added", _on_node_added)
	# Initial pass over everything already in the tree.
	var root: Node = tree.root
	if root != null:
		_wire_subtree(root)


func _wire_subtree(n: Node) -> void:
	if not is_instance_valid(n):
		return
	_try_wire_button(n)
	for child: Node in n.get_children():
		_wire_subtree(child)


func _on_node_added(n: Node) -> void:
	_try_wire_button(n)


## Auto-connect a single node's button signals to the UI cues, if it is a button.
## Idempotent (is_connected dedupe) and fully guarded.
func _try_wire_button(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if not (n is BaseButton):
		return
	var b := n as BaseButton
	if not b.is_connected("mouse_entered", _on_button_hover):
		b.connect("mouse_entered", _on_button_hover)
	if not b.is_connected("pressed", _on_button_pressed):
		b.connect("pressed", _on_button_pressed)


# --- internals --------------------------------------------------------------

func _canonical(cue: String) -> String:
	if cue == "":
		return ""
	if _cues.has(cue):
		return cue
	if _aliases.has(cue):
		return str(_aliases[cue])
	return cue


func _is_throttled(id: String, def: Dictionary) -> bool:
	var window: int = int(def.get("throttle_ms", _throttle_ms))
	if window <= 0:
		return false
	if not _last_play_ms.has(id):
		return false
	return (Time.get_ticks_msec() - int(_last_play_ms[id])) < window


func _claim_voice() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	# Prefer a free (idle) voice; otherwise round-robin over the pool.
	for i in range(_pool.size()):
		var idx: int = (_next + i) % _pool.size()
		var p: AudioStreamPlayer = _pool[idx]
		if p != null and not p.playing:
			_next = (idx + 1) % _pool.size()
			return p
	var v: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	return v


func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	var res: AudioStream = null
	if ResourceLoader.exists(path):
		res = ResourceLoader.load(path) as AudioStream
	_stream_cache[path] = res
	return res


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("UISoundSystem: missing data file '%s'" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


# --- Self-test (RH_UISOUND_TEST=1) ------------------------------------------

func _run_selftest() -> void:
	var errs: Array[String] = []
	var fired: Array = []
	var cb := func(cue: Variant, track: Variant) -> void:
		fired.append([str(cue), str(track)])
	ui_cue_played.connect(cb)

	print("[UISOUND] ===== Raven Hollow UI sound manager self-test =====")
	print("[UISOUND] cues loaded = %d ; pool = %d ; bus = %s" % [
		_cues.size(), _pool.size(), _bus])

	if _pool.is_empty():
		errs.append("audio pool not created")

	# Fire every authored cue. All stems are absent on disk in a fresh checkout,
	# so each should be a no-crash silent play that still records + emits.
	var ids: Array = cue_ids()
	var n: int = 0
	for cid_v: Variant in ids:
		var cid: String = str(cid_v)
		var before: int = fired.size()
		# Bypass the throttle so each distinct cue registers deterministically.
		_last_play_ms.erase(cid)
		var tr: String = play(cid)
		n += 1
		if last_cue != cid:
			errs.append("last_cue not updated for '%s'" % cid)
		if fired.size() != before + 1:
			errs.append("ui_cue_played not emitted for '%s'" % cid)
		var mark: String = tr if tr != "" else "(silent/absent)"
		print("[UISOUND] play('%s') -> %s" % [cid, mark])

	# Convenience wrappers must route to real cues.
	hover()
	click()
	confirm()
	if last_cue != "confirm":
		errs.append("convenience confirm() did not set last_cue")

	# Alias resolution.
	if _aliases.size() > 0:
		var a: String = str(_aliases.keys()[0])
		play(a)
		if last_cue != str(_aliases[a]):
			errs.append("alias '%s' did not resolve" % a)

	# Unknown cue: guarded no-op, still records + emits silently, no crash.
	var ub: int = fired.size()
	var ur: String = play("does_not_exist")
	if ur != "" or fired.size() != ub + 1:
		errs.append("unknown cue not handled as silent no-op")

	# Mute path + stop_all must not crash.
	set_muted(true)
	play("click")
	set_muted(false)
	stop_all()

	ui_cue_played.disconnect(cb)

	if errs.is_empty():
		print("[UISOUND] SELFTEST PASS cues=%d" % n)
	else:
		print("[UISOUND] SELFTEST FAIL cues=%d %s" % [n, str(errs)])
	print("[UISOUND] ===== self-test complete =====")
