extends Node
## Voice (autoload) — plays NPC voice lines for Raven Hollow.
##   BAKED-FIRST: res://assets/vo/<speaker>/<line_hash>.ogg (shipped).
##   LIVE-FALLBACK: POST the local FastAPI TTS server, but ONLY in the editor or
##     when RH_VO_LIVE=1 — shipped players have no server, so it's baked-only and
##     a missing clip is a silent no-op (never a crash).
## Autoload order (project.godot): VoiceRegistry BEFORE Voice.

const VO_DIR := "res://assets/vo/"
const SERVER := "http://127.0.0.1:8123/tts"
const FMT := "ogg"
const BARK_COOLDOWN_MS := 2500

var _dvo: AudioStreamPlayer          # dialogue voice (non-spatial)
var _live := false
var _dlg_token := 0                   # bumps on speak/stop to cancel stale live fetches
var _bark_cd: Dictionary = {}         # npc instance_id -> next-allowed msec


func _ready() -> void:
	_dvo = AudioStreamPlayer.new()
	_dvo.name = "DialogueVO"
	add_child(_dvo)
	_live = OS.has_feature("editor") or not OS.get_environment("RH_VO_LIVE").is_empty()


## FNV-1a 32-bit over utf8("speaker|text") — deterministic and reproducible in
## Python (the bake tool), so baked filenames match at runtime.
func line_hash(speaker: String, text: String) -> String:
	var s: PackedByteArray = (speaker + "|" + text.strip_edges()).to_utf8_buffer()
	var h: int = 2166136261
	for b: int in s:
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return "%08x" % h


func _baked_path(speaker: String, text: String) -> String:
	return VO_DIR + speaker + "/" + line_hash(speaker, text) + ".ogg"


# ------------------------------------------------------------ dialogue VO ----

## Speak one dialogue line for npc_id. Cancels any current dialogue VO first.
func speak(npc_id: String, text: String) -> void:
	stop()
	if text.strip_edges().is_empty():
		return
	var v: Dictionary = VoiceRegistry.voice_for(npc_id)
	var speaker: String = String(v.get("speaker", "default"))
	_dvo.pitch_scale = float(v.get("pitch", 1.0))
	_dvo.volume_db = float(v.get("volume_db", 0.0))
	var st: AudioStream = _load_baked(speaker, text)
	if st != null:
		_dvo.stream = st
		_dvo.play()
	elif _live:
		_fetch(speaker, text, _dvo, _dlg_token)


func stop() -> void:
	_dlg_token += 1
	if _dvo != null and _dvo.playing:
		_dvo.stop()


# ---------------------------------------------------------------- barks ------

## Spatial WoW-style bark on an npc node (per-npc cooldown, non-overlapping).
func bark(npc: Node2D, npc_id: String, text: String) -> void:
	if npc == null or not is_instance_valid(npc) or text.strip_edges().is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var key: int = npc.get_instance_id()
	if int(_bark_cd.get(key, 0)) > now:
		return
	_bark_cd[key] = now + BARK_COOLDOWN_MS
	var v: Dictionary = VoiceRegistry.voice_for(npc_id)
	var speaker: String = String(v.get("speaker", "default"))
	var p := AudioStreamPlayer2D.new()
	p.pitch_scale = float(v.get("pitch", 1.0))
	p.max_polyphony = 1
	p.max_distance = 420.0
	npc.add_child(p)
	var st: AudioStream = _load_baked(speaker, text)
	if st != null:
		p.stream = st
		p.play()
	elif _live:
		_fetch(speaker, text, p, -1)
	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


# ---------------------------------------------------------------- internal ---

func _load_baked(speaker: String, text: String) -> AudioStream:
	var path: String = _baked_path(speaker, text)
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


## Live TTS fetch. guard >= 0 means dialogue: drop the result if _dlg_token
## advanced (page moved on) before it arrived. guard < 0 = fire-and-forget bark.
func _fetch(speaker: String, text: String, target: Node, guard: int) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, data: PackedByteArray) -> void:
		if is_instance_valid(req):
			req.queue_free()
		if guard >= 0 and guard != _dlg_token:
			return  # dialogue advanced; this take is stale
		if not is_instance_valid(target) or code != 200 or data.is_empty():
			return
		var st := AudioStreamOggVorbis.load_from_buffer(data)
		if st != null:
			target.set("stream", st)
			target.call("play"))
	var body := JSON.stringify({"text": text, "speaker": speaker, "format": FMT})
	var err := req.request(SERVER, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK and is_instance_valid(req):
		req.queue_free()
