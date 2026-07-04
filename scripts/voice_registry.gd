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

# npc_id -> voice. Quest-givers get their own designed voice; generic townsfolk
# share "default"/"narrator" with a pitch nudge so they don't sound identical.
const VOICES := {
	"marta":      {"speaker": "marta",      "pitch": 1.0,  "volume_db": 0.0},
	"goran":      {"speaker": "goran",      "pitch": 0.94, "volume_db": 0.0},
	"vasile":     {"speaker": "vasile",     "pitch": 0.9,  "volume_db": 0.0},
	"ansel":      {"speaker": "ansel",      "pitch": 1.0,  "volume_db": 0.0},
	"petra":      {"speaker": "petra",      "pitch": 1.06, "volume_db": 0.0},
	"gatewarden": {"speaker": "gatewarden", "pitch": 0.96, "volume_db": 0.0},
	"mira":       {"speaker": "mira",       "pitch": 1.04, "volume_db": 0.0},
	# generic villagers -> shared voices with distinct pitch
	"tibalt":     {"speaker": "default",    "pitch": 0.92, "volume_db": 0.0},
	"elsbeth":    {"speaker": "default",    "pitch": 1.10, "volume_db": 0.0},
	"emeric":     {"speaker": "narrator",   "pitch": 0.98, "volume_db": 0.0},
}

# Generic greeting barks, picked by hash for variety (used when an NPC has no
# bespoke bark set). Kept lore-flavoured and short.
const GENERIC_BARKS := [
	"Hm?", "Aye?", "What is it?", "Speak, then.", "You need something?",
	"Keep your wits about you.", "Cold night coming.", "Mind the dark.",
]


func voice_for(npc_id: String) -> Dictionary:
	return VOICES.get(npc_id, DEFAULT)


func speaker_for(npc_id: String) -> String:
	return String(voice_for(npc_id).get("speaker", "default"))


## A deterministic bark line for this npc + call index (so repeated clicks vary
## but stay reproducible for baking).
func bark_line(npc_id: String, salt: int) -> String:
	var pool: Array = GENERIC_BARKS
	var idx: int = abs(hash(npc_id) + salt) % pool.size()
	return String(pool[idx])
