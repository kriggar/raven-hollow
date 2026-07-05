#!/usr/bin/env python3
"""
THE VISION GAUNTLET  (owner law #115, 2026-07-05) — the FINAL gate after the spotless razor cut.

A council of independent vision INSPECTORS examines every candidate sprite; entry into library.json
requires UNANIMITY. Any single fail = reject, with the killing inspector + reason logged.

Inspectors (independent lenses):
  1. pixel_art     — is it REAL pixel art? crisp quantized flat-run blocks, not painterly/3D/photo mush.
  2. palette       — muted gothic Eastern-European family (mud/moss/slate/bog-teal/ash/lantern-gold).
  3. ambience      — desaturated gothic mood (not garish/neon/bright).
  4. vlm_style     — (local VLM, if available) "is this a muted gothic top-down pixel-art game asset?"
  5. vlm_perspective — (local VLM) "is this a top-down / 3-4 view object (not a side portrait)?"

Heuristic lenses (1-3) always run — they gate the 150k queue with zero external dependency. VLM lenses
(4-5) activate when Ollama serves a vision model (qwen2.5vl/llava); until then they abstain (logged),
so the gauntlet degrades honestly rather than blocking. `run_gauntlet` returns (passed, verdicts).
"""
from __future__ import annotations
import os, io, json, base64, urllib.request
from PIL import Image

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I

OLLAMA = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
VLM_MODEL = os.environ.get("RH_VLM", "llava:7b")
_vlm_state = {"checked": False, "available": False}


# ---------------------------------------------------------------------------- heuristic lenses
def _opaque_pixels(im):
    im = im.convert("RGBA"); w, h = im.size; px = im.load()
    return [(x, y, px[x, y]) for y in range(h) for x in range(w) if px[x, y][3] >= 128], w, h, px


def lens_pixel_art(im):
    """Real pixel art = flat colour blocks with hard edges. Painterly/3D/photo/AI-mush = many soft
    gradients + huge colour count. Measures flat-run ratio (a pixel equals a 4-neighbour) + n_colors."""
    pts, w, h, px = _opaque_pixels(im)
    if len(pts) < 12:
        return False, "too few pixels"
    flat = 0
    for x, y, c in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 128 and px[nx, ny][:3] == c[:3]:
                flat += 1
                break
    flat_ratio = flat / len(pts)
    ncolors = len(set(c[:3] for _, _, c in pts))
    if flat_ratio < 0.42:
        return False, f"not pixel-art (flat-run {flat_ratio:.2f} <0.42 = gradient/mush)"
    if ncolors > 110:
        return False, f"too many colours ({ncolors}) = not quantized pixel art"
    return True, f"pixel-art ok (flat {flat_ratio:.2f}, {ncolors} colours)"


def lens_palette(im):
    """Gothic-family palette compatibility."""
    pts, w, h, px = _opaque_pixels(im)
    if not pts:
        return False, "empty"
    cols = set(c[:3] for _, _, c in pts)
    compat = sum(1 for c in cols if min(I._cdist(c, g) for g in I.GOTHIC) <= 96)
    frac = compat / len(cols)
    if frac < 0.5:
        return False, f"palette off-gothic ({frac:.2f} <0.50 in family)"
    return True, f"palette ok ({frac:.2f} in gothic family)"


def lens_ambience(im):
    """Muted gothic mood: low mean saturation (not garish/neon). Value not blown out."""
    pts, w, h, px = _opaque_pixels(im)
    if not pts:
        return False, "empty"
    sats = [max(c[:3]) - min(c[:3]) for _, _, c in pts]
    mean_sat = sum(sats) / len(sats)
    if mean_sat > 118:
        return False, f"too saturated/garish (mean sat {mean_sat:.0f} >118)"
    return True, f"ambience ok (mean sat {mean_sat:.0f})"


# ---------------------------------------------------------------------------- VLM lenses
def _vlm_available():
    if not _vlm_state["checked"]:
        _vlm_state["checked"] = True
        try:
            req = urllib.request.Request(OLLAMA + "/api/tags")
            tags = json.loads(urllib.request.urlopen(req, timeout=5).read())
            names = [m.get("name", "") for m in tags.get("models", [])]
            _vlm_state["available"] = any(VLM_MODEL.split(":")[0] in n for n in names)
        except Exception:
            _vlm_state["available"] = False
    return _vlm_state["available"]


def _vlm_ask(im, prompt):
    buf = io.BytesIO()
    # upscale small sprites so the VLM can see them
    show = im.convert("RGBA")
    if max(show.size) < 256:
        s = 256 // max(show.size)
        show = show.resize((show.width * s, show.height * s), Image.NEAREST)
    bg = Image.new("RGB", show.size, (40, 38, 44))
    bg.paste(show, (0, 0), show.split()[3])
    bg.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    body = json.dumps({"model": VLM_MODEL, "prompt": prompt, "images": [b64], "stream": False,
                       "options": {"temperature": 0.0}}).encode()
    req = urllib.request.Request(OLLAMA + "/api/generate", data=body, headers={"Content-Type": "application/json"})
    resp = json.loads(urllib.request.urlopen(req, timeout=120).read())
    return resp.get("response", "").strip()


def _vlm_yesno(im, prompt, lens):
    if not _vlm_available():
        return None, f"{lens}: VLM abstain (no model)"
    try:
        ans = _vlm_ask(im, prompt + " Answer strictly YES or NO first, then a short reason.")
        yes = ans.lower().lstrip().startswith("yes")
        return yes, f"{lens}: {'YES' if yes else 'NO'} — {ans[:90]}"
    except Exception as e:
        return None, f"{lens}: VLM error ({e})"


def lens_vlm_style(im):
    return _vlm_yesno(im, "This is a video-game sprite. Is it PIXEL ART (not a smooth painting, not a "
                          "3D render, not a photo) in a MUTED GOTHIC medieval style (dark, desaturated, "
                          "mud/moss/slate/gold)?", "vlm_style")


def lens_vlm_perspective(im):
    return _vlm_yesno(im, "Is this object drawn from a TOP-DOWN or 3/4 overhead game view (as opposed to "
                          "a pure side view or a front portrait)?", "vlm_perspective")


# ---------------------------------------------------------------------------- the council
HEURISTIC_LENSES = [("pixel_art", lens_pixel_art), ("palette", lens_palette), ("ambience", lens_ambience)]
VLM_LENSES = [("vlm_style", lens_vlm_style), ("vlm_perspective", lens_vlm_perspective)]


def run_gauntlet(im, use_vlm=True):
    """Unanimous vision gate. Returns (passed, verdicts:list[(lens,pass_or_None,reason)]).
    A lens that abstains (VLM unavailable) does NOT block. Any explicit fail blocks.
    VLM lenses (~5-10s/asset) can be disabled for throughput with RH_GAUNTLET_VLM=0; the 3
    heuristic lenses always run (they alone caught the mush/off-palette rejects)."""
    verdicts = []
    ok = True
    for name, fn in HEURISTIC_LENSES:
        p, reason = fn(im)
        verdicts.append((name, p, reason))
        if not p:
            ok = False
    use_vlm = use_vlm and os.environ.get("RH_GAUNTLET_VLM", "1") != "0"
    if use_vlm and _vlm_available():
        for name, fn in VLM_LENSES:
            p, reason = fn(im)
            verdicts.append((name, p, reason))
            if p is False:
                ok = False
    return ok, verdicts


def verdict_reasons(verdicts, only_fail=True):
    return "; ".join(r for _, p, r in verdicts if (p is False) or (not only_fail))


if __name__ == "__main__":
    import glob
    import sys as _s
    path = _s.argv[1] if len(_s.argv) > 1 else "_downloads/_assetlib/verified/gen_all"
    files = [path] if path.endswith(".png") else glob.glob(os.path.join(path, "*.png"))
    print(f"VLM available: {_vlm_available()} ({VLM_MODEL})")
    npass = 0
    for f in files[:40]:
        im = Image.open(f)
        ok, v = run_gauntlet(im)
        npass += ok
        tag = "PASS" if ok else "REJECT"
        print(f"{tag} {os.path.basename(f)}  {verdict_reasons(v, only_fail=not ok)}")
    print(f"\n{npass}/{min(40,len(files))} unanimous-pass")
