extends Node
## VoiceRegistry (autoload) — maps an npc_id to a voice config for the TTS
## pipeline. `speaker` is the key into the server's voices.json (per-voice
## reference clip / seed / expressiveness). `pitch` is applied CLIENT-side at
## playback for cheap extra differentiation and is deliberately NOT part of the
## baked-line hash (only `speaker` + text are). `barks` are short WoW-style
## one-liners played on click/interact.
##
## Autoload order (project.godot): VoiceRegistry BEFORE Voice.

const DEFAULT := {"speaker": "default", "pitch": 1.0, "volume_db": 0.0}
const VOICE_MAP_PATH := "res://data/voice_map.json"

## Per-NPC voice assignment for the full 384-NPC cast (BACKLOG #85), loaded from
## data/voice_map.json at boot. Each NPC gets a role-appropriate voice archetype
## (gruff smith, warm innkeeper, dry chronicler, brisk merchant, on-duty guard...)
## with a deterministic per-npc pitch jitter so no two share an identical voice.
## The hand-designed hero voices in VOICES below OVERRIDE the map.
var _voice_map: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open(VOICE_MAP_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_voice_map = (parsed as Dictionary).get("voices", {})

# npc_id -> voice. Quest-givers get their own designed voice; generic townsfolk
# share "default"/"narrator" with a pitch nudge so they don't sound identical.
# Keyed on the REAL npc_id (role-based, from npc_data.gd), NOT display names.
const VOICES := {
	"innkeeper":  {"speaker": "marta",      "pitch": 1.0,  "volume_db": 0.0},  # Marta
	"blacksmith": {"speaker": "goran",      "pitch": 0.96, "volume_db": 0.0},  # Goran
	"gravekeeper":{"speaker": "vasile",     "pitch": 0.92, "volume_db": 0.0},  # Vasile
	"farmer":     {"speaker": "ansel",      "pitch": 1.0,  "volume_db": 0.0},  # Ansel
	"wanderer1":  {"speaker": "petra",      "pitch": 1.04, "volume_db": 0.0},  # Old Petra (quest 4)
	"gatewarden": {"speaker": "gatewarden", "pitch": 0.98, "volume_db": 0.0},  # Iosif
	"mira":       {"speaker": "mira",       "pitch": 1.02, "volume_db": 0.0},  # Mira
	# generic villagers -> bank voices + distinct pitch
	"merchant":   {"speaker": "narrator",   "pitch": 0.94, "volume_db": 0.0},  # Tibalt
	"maid":       {"speaker": "default",    "pitch": 1.14, "volume_db": 0.0},  # Elsbeth
	"wanderer2":  {"speaker": "default",    "pitch": 1.02, "volume_db": 0.0},  # Emeric
}

# Generic greeting barks, picked by hash for variety (used when an NPC has no
# bespoke bark set). Kept lore-flavoured and short.
const GENERIC_BARKS := [
	"Hm?", "Aye?", "What is it?", "Speak, then.", "You need something?",
	"Keep your wits about you.", "Cold night coming.", "Mind the dark.",
]


func voice_for(npc_id: String) -> Dictionary:
	# Hand-designed hero voices win; then the per-NPC map (all 384); then default.
	if VOICES.has(npc_id):
		return VOICES[npc_id]
	if _voice_map.has(npc_id):
		return _voice_map[npc_id]
	return DEFAULT


func speaker_for(npc_id: String) -> String:
	return String(voice_for(npc_id).get("speaker", "default"))


## A deterministic bark line for this npc + call index (so repeated clicks vary
## but stay reproducible for baking).
func bark_line(npc_id: String, salt: int) -> String:
	var pool: Array = GENERIC_BARKS
	var idx: int = abs(hash(npc_id) + salt) % pool.size()
	return String(pool[idx])
