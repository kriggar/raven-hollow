extends SceneTree
## Dump every voiced (speaker, text) line to tools/vo_lines.json for bake_vo.py.
## Walks NPCData flavor dialogue + QuestDefs pages, attributing each line to the
## right voice via VoiceRegistry. Run:
##   godot --headless --path <proj> -s res://tools/dump_vo_lines.gd

## npc_id -> speaker. MUST mirror voice_registry.gd VOICES (autoloads aren't
## attached during a -s script's _init, so we can't call VoiceRegistry here).
const SPEAKER_MAP := {
	"innkeeper": "marta", "blacksmith": "goran", "gravekeeper": "vasile",
	"farmer": "ansel", "wanderer1": "petra", "gatewarden": "gatewarden",
	"mira": "mira", "merchant": "narrator", "maid": "default", "wanderer2": "default",
}
## Mirror of voice_registry.gd GENERIC_BARKS.
const BARKS := [
	"Hm?", "Aye?", "What is it?", "Speak, then.", "You need something?",
	"Keep your wits about you.", "Cold night coming.", "Mind the dark.",
]

func _init() -> void:
	var vr: Node = null
	var out: Array = []
	var seen: Dictionary = {}

	# NPC flavor / ambient dialogue.
	for def: Dictionary in NPCData.cast():
		var spk: String = _spk(vr, String(def.get("id", "")))
		for t: Variant in def.get("dialogue", []):
			_add(out, seen, spk, str(t))

	# Quest pages (offer / objective / turn-in / finale / arrive-note).
	for q: Variant in QuestDefs.all().values():
		_harvest(vr, q, _spk(vr, String((q as Dictionary).get("giver", ""))), out, seen)

	# Ambient barks: every generic bark for each speaker any NPC uses.
	var speakers: Dictionary = {}
	for s: Variant in SPEAKER_MAP.values():
		speakers[String(s)] = true
	for spk: String in speakers.keys():
		for b: String in BARKS:
			_add(out, seen, spk, b)

	var f := FileAccess.open("res://tools/vo_lines.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("VO_LINES %d" % out.size())
	quit()


func _spk(_vr: Node, id: String) -> String:
	return String(SPEAKER_MAP.get(id, "default"))


func _add(out: Array, seen: Dictionary, spk: String, text: String) -> void:
	text = text.strip_edges()
	if text.is_empty() or text == "...":
		return
	var key: String = spk + "|" + text
	if seen.has(key):
		return
	seen[key] = true
	out.append({"speaker": spk, "text": text})


## Recursive harvest that tracks the current giver voice and routes turn-in /
## finale / arrive-note lines to their proper speaker.
func _harvest(vr: Node, node: Variant, voice: String, out: Array, seen: Dictionary) -> void:
	if node is Array:
		for e: Variant in node:
			_harvest(vr, e, voice, out, seen)
	elif node is Dictionary:
		var d: Dictionary = node
		var v: String = voice
		if d.has("giver"):
			v = _spk(vr, String(d["giver"]))
		for k: Variant in d.keys():
			var key: String = String(k)
			var child: Variant = d[k]
			if key == "arrive_note":
				_add(out, seen, "narrator", str(child))
				continue
			var kv: String = v
			if key == "turn_in_pages" and d.has("turn_in_npc"):
				kv = _spk(vr, String(d["turn_in_npc"]))
			elif key == "finale_pages" and d.has("finale_speaker"):
				kv = _spk(vr, String(d["finale_speaker"]))
			if child is Array and key.ends_with("pages"):
				for s: Variant in child:
					_add(out, seen, kv, str(s))
			else:
				_harvest(vr, child, v, out, seen)
