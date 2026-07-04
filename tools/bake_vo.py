#!/usr/bin/env python3
"""Bake every voiced line to res://assets/vo/<speaker>/<fnv>.ogg via the TTS
server. Reads tools/vo_lines.json (from dump_vo_lines.gd). FNV-1a hash matches
voice_client.gd::line_hash so the game finds the baked clips at runtime.
Idempotent: existing non-empty clips are skipped (regenerate = delete + rerun).
"""
import json, os, sys, time, urllib.request

REPO = r"C:\Users\vstef\Desktop\rpg\medieval_rpg"
LINES = os.path.join(REPO, "tools", "vo_lines.json")
VO = os.path.join(REPO, "assets", "vo")
SERVER = "http://127.0.0.1:8123/tts"


def fnv(speaker, text):
    s = (speaker + "|" + text.strip()).encode("utf-8")
    h = 2166136261
    for b in s:
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return "%08x" % h


lines = json.load(open(LINES, encoding="utf-8"))
made = skipped = failed = 0
t0 = time.time()
for i, ln in enumerate(lines):
    spk, text = ln["speaker"], ln["text"]
    h = fnv(spk, text)
    d = os.path.join(VO, spk)
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, h + ".ogg")
    if os.path.exists(p) and os.path.getsize(p) > 0:
        skipped += 1
        continue
    body = json.dumps({"text": text, "speaker": spk, "format": "ogg"}).encode()
    req = urllib.request.Request(SERVER, data=body, headers={"Content-Type": "application/json"})
    try:
        data = urllib.request.urlopen(req, timeout=180).read()
        open(p, "wb").write(data)
        made += 1
        print("[%d/%d] %-9s %s %6db  %s" % (i + 1, len(lines), spk, h, len(data), text[:44]), flush=True)
    except Exception as e:  # noqa: BLE001
        failed += 1
        print("FAIL %s %s %s" % (spk, h, e), flush=True)
json.dump({"count": len(lines), "made": made, "skipped": skipped},
          open(os.path.join(VO, "vo_manifest.json"), "w"))
print("BAKE_DONE made=%d skipped=%d failed=%d total=%d in %.0fs"
      % (made, skipped, failed, len(lines), time.time() - t0))
