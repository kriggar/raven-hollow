#!/usr/bin/env python3
"""Raven Hollow TTS server — Chatterbox-backed /tts, dev/bake-time only.

The Godot client only ever sends {text, speaker, format}; ALL per-voice
expressiveness (reference clip, seed, exaggeration, cfg_weight) lives here in
voices.json keyed by `speaker`, so re-tuning a voice never changes the client
or the line hash. Returns raw OGG/Vorbis bytes (what Godot's
AudioStreamOggVorbis.load_from_buffer eats), falling back to WAV if the local
libsndfile lacks Vorbis.

Run:  C:/Users/vstef/tts/venv/Scripts/python.exe -m uvicorn tts_server:app --host 127.0.0.1 --port 8123
"""
import io, json, os
import torch, soundfile as sf
from fastapi import FastAPI
from fastapi.responses import Response, JSONResponse
from pydantic import BaseModel
from chatterbox.tts import ChatterboxTTS

HERE = os.path.dirname(os.path.abspath(__file__))
VOICES_PATH = os.path.join(HERE, "voices.json")

app = FastAPI(title="Raven Hollow TTS")
_model = None
_voices = {}
_ogg_ok = True


def _resolve_ref(ref: str) -> str:
    if not ref:
        return ""
    p = ref if os.path.isabs(ref) else os.path.join(HERE, ref)
    return p if os.path.exists(p) else ""


def _load():
    global _model, _voices
    print("[tts] loading Chatterbox on cuda...")
    _model = ChatterboxTTS.from_pretrained(device="cuda")
    if os.path.exists(VOICES_PATH):
        _voices = json.load(open(VOICES_PATH, encoding="utf-8"))
    print("[tts] ready. voices:", list(_voices.keys()))


class TTSReq(BaseModel):
    text: str
    speaker: str = "default"
    format: str = "ogg"


@app.get("/health")
def health():
    return {"ok": _model is not None, "voices": list(_voices.keys()), "ogg": _ogg_ok, "sr": (_model.sr if _model else 0)}


@app.post("/tts")
def tts(req: TTSReq):
    global _ogg_ok
    if _model is None:
        return JSONResponse({"error": "model not loaded"}, status_code=503)
    v = dict(_voices.get(req.speaker, {}))
    seed = int(v.get("seed", 0))
    if seed:
        torch.manual_seed(seed)
    kw = {}
    ref = _resolve_ref(str(v.get("ref", "")))
    if ref:
        kw["audio_prompt_path"] = ref
    if "exaggeration" in v:
        kw["exaggeration"] = float(v["exaggeration"])
    if "cfg_weight" in v:
        kw["cfg_weight"] = float(v["cfg_weight"])
    try:
        wav = _model.generate(req.text, **kw)
    except Exception as e:  # noqa: BLE001
        return JSONResponse({"error": "generate failed: %s" % e}, status_code=500)
    arr = wav.squeeze(0).detach().cpu().float().numpy()
    want_ogg = req.format.lower() == "ogg" and _ogg_ok
    buf = io.BytesIO()
    try:
        if want_ogg:
            sf.write(buf, arr, _model.sr, format="OGG", subtype="VORBIS")
            return Response(content=buf.getvalue(), media_type="audio/ogg")
    except Exception:
        _ogg_ok = False  # libsndfile has no Vorbis on this box; fall through to WAV
        buf = io.BytesIO()
    sf.write(buf, arr, _model.sr, format="WAV", subtype="PCM_16")
    return Response(content=buf.getvalue(), media_type="audio/wav")


_load()
