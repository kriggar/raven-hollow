# Raven Hollow — Voice (TTS) pipeline

Local, commercial-safe TTS. **Chatterbox** (MIT) ships the lines; **Maya1**
(Apache-2.0) designs the distinct character reference voices. Everything bakes
to OGG offline — shipped players never run a server.

## Runtime (dev / bake only)
- venv: `C:\Users\vstef\tts\venv` (Python 3.10 + torch 2.11.0+cu128 for Blackwell sm_120)
- server: `python -m uvicorn tts_server:app --host 127.0.0.1 --port 8123` (from C:\Users\vstef\tts)
- POST /tts {text, speaker, format:"ogg"} -> audio/ogg bytes. voices.json holds
  per-speaker {ref, seed, exaggeration, cfg_weight}.

## In-game (scripts/)
- `voice_registry.gd` (autoload VoiceRegistry): npc_id -> {speaker, pitch, volume_db}.
- `voice_client.gd` (autoload Voice): speak(npc_id, text) for dialogue, bark(npc, id, text)
  for spatial WoW barks. BAKED-FIRST (res://assets/vo/<speaker>/<hash>.ogg),
  live-fallback to the server only in editor / RH_VO_LIVE=1.
- dialogue_ui.gd voices each page; npc.gd threads its _id into show_dialogue.
- QA: RH_VO_LIVE=1 (enable live), RH_SAY="<voice_id>|<text>".

## TODO (next)
- Maya1 voice bank: design 8-12 reference clips -> voices.json `ref` paths.
- bake_vo: headless walk of NPCData/QuestDefs lines -> POST server -> res://assets/vo/**.
- barks on click-to-target.
