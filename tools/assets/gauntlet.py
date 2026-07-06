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

# THE ART BAR (owner #115): reference sheets become STYLE ANCHORS. Drop class/zone/monster reference
# PNGs into either dir and the anchor lens auto-activates — candidates are compared to the owner's
# actual reference palette. Until refs appear, the lens abstains (heuristic+VLM lenses still gate).
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REFERENCE_DIRS = [r"D:\raven hollow\reference", os.path.join(_REPO, "_downloads", "reference")]
_anchor_state = {"loaded": False, "palette": None}


def set_style_anchor(dirs):
    """Point the style-anchor lens at a SPECIFIC reference folder (owner biome-anchoring, 2026-07-06).
    Pass a dir path or list of dirs (e.g. the one biome's reference/<biome>/ folder) and the anchor
    palette is rebuilt from ONLY those images on the next lens call. Resets the cache so a prior
    (whole-reference-tree) palette does not leak. Call with the default REFERENCE_DIRS to restore."""
    global REFERENCE_DIRS
    REFERENCE_DIRS = [dirs] if isinstance(dirs, str) else list(dirs)
    _anchor_state["loaded"] = False
    _anchor_state["palette"] = None


def _load_reference_palette():
    if _anchor_state["loaded"]:
        return _anchor_state["palette"]
    _anchor_state["loaded"] = True
    import glob
    pal = []
    for d in REFERENCE_DIRS:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "**", "*.png"), recursive=True) + \
                 glob.glob(os.path.join(d, "**", "*.jpg"), recursive=True):
            try:
                q = Image.open(f).convert("RGB").quantize(colors=48, method=Image.MEDIANCUT)
                p = q.getpalette()[:48 * 3]
                pal += [(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)]
            except Exception:
                pass
    _anchor_state["palette"] = pal or None
    if pal:
        sys.stderr.write(f"[gauntlet] style anchors loaded: {len(pal)} reference colours\n")
    return _anchor_state["palette"]


def lens_style_anchor(im):
    """Compare the candidate's palette to the owner's REFERENCE sheets (the art bar). Only active when
    reference images exist. Passes when enough of the candidate's colours sit near a reference colour."""
    ref = _load_reference_palette()
    if not ref:
        return None, "style_anchor: abstain (no reference sheets yet)"
    pts, w, h, px = _opaque_pixels(im)
    if not pts:
        return False, "empty"
    cols = set(c[:3] for _, _, c in pts)
    near = sum(1 for c in cols if min(I._cdist(c, r) for r in ref) <= 80)
    frac = near / len(cols)
    if frac < 0.5:
        return False, f"off art-bar palette ({frac:.2f} <0.50 near reference)"
    return True, f"art-bar palette ok ({frac:.2f} near reference)"


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
HEURISTIC_LENSES = [("pixel_art", lens_pixel_art), ("palette", lens_palette), ("ambience", lens_ambience),
                    ("style_anchor", lens_style_anchor)]
def lens_vlm_identity(im, subject):
    """IDENTITY GATE (owner, 2026-07-06, after the flame-blob fireball): style compliance is not
    enough — the asset must READ as the thing it claims to be. Parameterized per asset."""
    return _vlm_yesno(im, f"This is a video-game sprite that is supposed to be: {subject}. "
                          f"Does it clearly READ as that (correct shape, silhouette and key features "
                          f"a player would instantly recognize)?", "vlm_identity")


VLM_LENSES = [("vlm_style", lens_vlm_style), ("vlm_perspective", lens_vlm_perspective)]


def run_gauntlet(im, use_vlm=True, subject=None):
    """Unanimous vision gate. Returns (passed, verdicts:list[(lens,pass_or_None,reason)]).
    A lens that ABSTAINS (returns None — VLM unavailable, or no reference sheets yet) does NOT block.
    Any explicit False blocks. VLM lenses (~1.3s/asset) toggle via RH_GAUNTLET_VLM=0; the heuristic
    lenses always run (they alone caught the mush/off-palette rejects)."""
    verdicts = []
    ok = True
    for name, fn in HEURISTIC_LENSES:
        p, reason = fn(im)
        verdicts.append((name, p, reason))
        if p is False:
            ok = False
    use_vlm = use_vlm and os.environ.get("RH_GAUNTLET_VLM", "1") != "0"
    if use_vlm and _vlm_available():
        for name, fn in VLM_LENSES:
            p, reason = fn(im)
            verdicts.append((name, p, reason))
            if p is False:
                ok = False
        if subject:
            p, reason = lens_vlm_identity(im, subject)
            verdicts.append(("vlm_identity", p, reason))
            if p is False:
                ok = False
    return ok, verdicts


def verdict_reasons(verdicts, only_fail=True):
    return "; ".join(r for _, p, r in verdicts if (p is False) or (not only_fail))


# ============================================================================
# VFX MODE  (owner VFX_PIPELINE.md sections 1+4, First Build Step 2, 2026-07-06)
# ----------------------------------------------------------------------------
# A VFX-mode council for emissive spell/impact frames. It REUSES lens_pixel_art
# + lens_style_anchor (pointed at the fire reference pack), REPLACES the gothic
# desaturation ceiling with the EMISSIVE EXEMPTION (require a vivid hot core AND
# measure a smoke periphery), and ADDS temporal / AI-mush lenses across the frame
# set: partial-alpha, off-ramp dE2000, sub-pixel drift, palette Jaccard, single-
# dominant-blob silhouette, sparkle. Bands are calibrated in vfx_bar.json off the
# Foozle CC0 control; the gate scores the Foozle control every run and requires a
# candidate to score >= (a tolerance of) the control. dE2000 + Hasler-Susstrunk
# are implemented INLINE (numpy only; no scipy / no heavy installs). Honest-degrade
# holds: an abstain (None) never blocks; only an explicit False from a HARD lens
# blocks; soft lenses are calibrated generous to the control; VLM stays advisory.
# ============================================================================
import numpy as _np

_VFX_BAR_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vfx_bar.json")
_VFX_DEFAULTS = {
    "flat_run_floor": 0.50, "n_colors_ceil": 110, "partial_alpha_ceil": 0.005,
    "offramp_de2000_gt": 10.0, "offramp_ceil": 0.03, "core_colourf_floor": 45.0,
    "whole_colourf_floor": 80.0, "dominant_frac_floor": 0.45,
    "orphan_speckle_advisory_max": 9, "drift_ceil": 5.0, "jaccard_floor": 0.80,
    "palette_quantize_colors": 24, "bright_percentile": 80, "periphery_percentile": 25,
}
_vfx_bar_cache = {"loaded": False, "bar": None}


def _vfx_bar():
    if _vfx_bar_cache["loaded"]:
        return _vfx_bar_cache["bar"]
    _vfx_bar_cache["loaded"] = True
    bar = dict(_VFX_DEFAULTS)
    try:
        with open(_VFX_BAR_PATH, "r", encoding="utf-8") as fh:
            j = json.load(fh)
        bar.update(j.get("thresholds", {}))
    except Exception as e:
        sys.stderr.write(f"[vfx-gauntlet] vfx_bar.json not loaded ({e}); using defaults\n")
    _vfx_bar_cache["bar"] = bar
    return bar


# ----------------------------------------------------------- inline colour math
def _vfx_srgb_to_lab(rgb):
    arr = _np.asarray(rgb, dtype=_np.float64) / 255.0
    m = arr > 0.04045
    lin = _np.where(m, ((arr + 0.055) / 1.055) ** 2.4, arr / 12.92)
    R, G, B = lin[..., 0], lin[..., 1], lin[..., 2]
    X = R * 0.4124564 + G * 0.3575761 + B * 0.1804375
    Y = R * 0.2126729 + G * 0.7151522 + B * 0.0721750
    Z = R * 0.0193339 + G * 0.1191920 + B * 0.9503041
    X /= 0.95047; Z /= 1.08883
    d = 6.0 / 29.0

    def f(t):
        return _np.where(t > d ** 3, _np.cbrt(t), t / (3 * d * d) + 4.0 / 29.0)
    fx, fy, fz = f(X), f(Y), f(Z)
    return _np.stack([116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)], axis=-1)


def _vfx_ciede2000(lab1, lab2):
    L1, a1, b1 = lab1[..., 0], lab1[..., 1], lab1[..., 2]
    L2, a2, b2 = lab2[..., 0], lab2[..., 1], lab2[..., 2]
    avg_Lp = (L1 + L2) / 2.0
    C1 = _np.sqrt(a1 ** 2 + b1 ** 2); C2 = _np.sqrt(a2 ** 2 + b2 ** 2)
    avg_C = (C1 + C2) / 2.0
    G = 0.5 * (1 - _np.sqrt(avg_C ** 7 / (avg_C ** 7 + 25.0 ** 7)))
    a1p = (1 + G) * a1; a2p = (1 + G) * a2
    C1p = _np.sqrt(a1p ** 2 + b1 ** 2); C2p = _np.sqrt(a2p ** 2 + b2 ** 2)
    avg_Cp = (C1p + C2p) / 2.0
    h1p = _np.degrees(_np.arctan2(b1, a1p)) % 360
    h2p = _np.degrees(_np.arctan2(b2, a2p)) % 360
    dLp = L2 - L1; dCp = C2p - C1p
    dhp = h2p - h1p
    dhp = _np.where(dhp > 180, dhp - 360, dhp)
    dhp = _np.where(dhp < -180, dhp + 360, dhp)
    dhp = _np.where((C1p * C2p) == 0, 0.0, dhp)
    dHp = 2 * _np.sqrt(C1p * C2p) * _np.sin(_np.radians(dhp) / 2.0)
    avg_hp = h1p + h2p
    hp_diff = _np.abs(h1p - h2p)
    avg_hp = _np.where((C1p * C2p) == 0, avg_hp,
                       _np.where(hp_diff <= 180, avg_hp / 2.0,
                                 _np.where(avg_hp < 360, (avg_hp + 360) / 2.0, (avg_hp - 360) / 2.0)))
    T = (1 - 0.17 * _np.cos(_np.radians(avg_hp - 30)) + 0.24 * _np.cos(_np.radians(2 * avg_hp))
         + 0.32 * _np.cos(_np.radians(3 * avg_hp + 6)) - 0.20 * _np.cos(_np.radians(4 * avg_hp - 63)))
    d_theta = 30 * _np.exp(-(((avg_hp - 275) / 25.0) ** 2))
    R_c = 2 * _np.sqrt(avg_Cp ** 7 / (avg_Cp ** 7 + 25.0 ** 7))
    S_l = 1 + (0.015 * (avg_Lp - 50) ** 2) / _np.sqrt(20 + (avg_Lp - 50) ** 2)
    S_c = 1 + 0.045 * avg_Cp; S_h = 1 + 0.015 * avg_Cp * T
    R_t = -_np.sin(_np.radians(2 * d_theta)) * R_c
    return _np.sqrt((dLp / S_l) ** 2 + (dCp / S_c) ** 2 + (dHp / S_h) ** 2
                    + R_t * (dCp / S_c) * (dHp / S_h))


def _vfx_colourfulness(px):
    """Hasler-Susstrunk colourfulness M (verified metric; anchors 0/15/33/45/59/82/109)."""
    if len(px) == 0:
        return 0.0
    p = _np.asarray(px, dtype=_np.float64)
    rg = p[:, 0] - p[:, 1]
    yb = 0.5 * (p[:, 0] + p[:, 1]) - p[:, 2]
    sigma = _np.sqrt(rg.std() ** 2 + yb.std() ** 2)
    mu = _np.sqrt(rg.mean() ** 2 + yb.mean() ** 2)
    return float(sigma + 0.3 * mu)


# ------------------------------------------------- connected components (no scipy)
def _vfx_cc(mask):
    h, w = mask.shape
    labels = _np.zeros((h, w), dtype=_np.int32)
    cur = 0
    mv = mask
    for y0 in range(h):
        for x0 in range(w):
            if mv[y0, x0] and labels[y0, x0] == 0:
                cur += 1
                stack = [(y0, x0)]
                labels[y0, x0] = cur
                while stack:
                    y, x = stack.pop()
                    if y > 0 and mv[y - 1, x] and labels[y - 1, x] == 0:
                        labels[y - 1, x] = cur; stack.append((y - 1, x))
                    if y < h - 1 and mv[y + 1, x] and labels[y + 1, x] == 0:
                        labels[y + 1, x] = cur; stack.append((y + 1, x))
                    if x > 0 and mv[y, x - 1] and labels[y, x - 1] == 0:
                        labels[y, x - 1] = cur; stack.append((y, x - 1))
                    if x < w - 1 and mv[y, x + 1] and labels[y, x + 1] == 0:
                        labels[y, x + 1] = cur; stack.append((y, x + 1))
    if cur == 0:
        return labels, 0, []
    sizes = [int(s) for s in _np.bincount(labels.ravel(), minlength=cur + 1)[1:]]
    return labels, cur, sizes


# --------------------------------------------------------------- per-frame metrics
def _vfx_arr(im, maxdim=128):
    im = im.convert("RGBA")
    if max(im.size) > maxdim:          # safety: bound compute; frames should be sprite-scale
        s = maxdim / max(im.size)
        im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
    return _np.asarray(im)


def _vfx_flatrun(arr):
    a = arr[:, :, 3] >= 128
    rgb = arr[:, :, :3].astype(_np.int32)
    h, w = a.shape
    eq = _np.zeros((h, w), dtype=bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ys = slice(max(0, dy), h + min(0, dy)); xs = slice(max(0, dx), w + min(0, dx))
        yt = slice(max(0, -dy), h + min(0, -dy)); xt = slice(max(0, -dx), w + min(0, -dx))
        s = _np.zeros((h, w), dtype=bool)
        s[ys, xs] = _np.all(rgb[ys, xs] == rgb[yt, xt], axis=2) & a[ys, xs] & a[yt, xt]
        eq |= s
    n = int(a.sum())
    if n == 0:
        return 0.0, 0
    ncol = len(_np.unique(rgb[a].reshape(-1, 3), axis=0))
    return int((eq & a).sum()) / n, ncol


def _vfx_partial_alpha(arr):
    al = arr[:, :, 3]
    nz = int((al > 0).sum())
    return (int(((al > 0) & (al < 255)).sum()) / nz) if nz else 0.0


def _vfx_quant_pal(arr, colors):
    a = arr[:, :, 3] >= 128
    if a.sum() == 0:
        return _np.zeros((0, 3))
    q = Image.fromarray(arr[:, :, :3]).convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT)
    p = q.getpalette()[:colors * 3]
    return _np.array([(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)], dtype=_np.float64)


def _vfx_offramp(arr, colors, thresh):
    a = arr[:, :, 3] >= 128
    n = int(a.sum())
    if n == 0:
        return 0.0
    pix = arr[:, :, :3][a].reshape(-1, 3).astype(_np.float64)
    if len(pix) > 8000:                # sample for speed on oversized frames
        idx = _np.random.RandomState(0).choice(len(pix), 8000, replace=False)
        pix = pix[idx]
    pal = _vfx_quant_pal(arr, colors)
    if len(pal) == 0:
        return 0.0
    lp = _vfx_srgb_to_lab(pix); la = _vfx_srgb_to_lab(pal)
    K = len(la); off = 0; CH = 2000
    for i in range(0, len(lp), CH):
        c = lp[i:i + CH]; m = len(c)
        d = _vfx_ciede2000(_np.repeat(c, K, axis=0), _np.tile(la, (m, 1))).reshape(m, K)
        off += int((d.min(axis=1) > thresh).sum())
    return off / len(pix)


def _vfx_silhouette(arr, min_speckle=4):
    a = arr[:, :, 3] >= 128
    _, count, sizes = _vfx_cc(a)
    if not sizes:
        return 0, 0.0, 0
    tot = sum(sizes)
    return count, max(sizes) / tot, sum(1 for s in sizes if s < min_speckle)


def _vfx_hotcore(arr, pct):
    a = arr[:, :, 3] >= 128
    rgb = arr[:, :, :3]
    if a.sum() == 0:
        return 0.0, 0.0, 0.0
    val = rgb.max(axis=2).astype(_np.float64)
    whole = _vfx_colourfulness(rgb[a].reshape(-1, 3))
    thr = _np.percentile(val[a], pct)
    bright = a & (val >= thr)
    if bright.sum() == 0:
        return 0.0, 0.0, whole
    _, count, sizes = _vfx_cc(bright)
    if not sizes:
        return 0.0, 0.0, whole
    biggest = int(_np.argmax(sizes)) + 1
    lab, _, _ = _vfx_cc(bright)
    core = lab == biggest
    return _vfx_colourfulness(rgb[core].reshape(-1, 3)), core.sum() / int(a.sum()), whole


def _vfx_periph_meansat(arr, pct):
    a = arr[:, :, 3] >= 128
    rgb = arr[:, :, :3]
    if a.sum() == 0:
        return 0.0
    val = rgb.max(axis=2).astype(_np.float64)
    thr = _np.percentile(val[a], pct)
    periph = a & (val <= thr)
    if periph.sum() == 0:
        return 0.0
    pix = rgb[periph].astype(_np.int32)
    return float((pix.max(axis=1) - pix.min(axis=1)).mean())


def _vfx_centroid(arr):
    a = (arr[:, :, 3] >= 128)
    if a.sum() == 0:
        return None
    ys, xs = _np.nonzero(a)
    return xs.mean(), ys.mean()


def _vfx_drift(a, b):
    ca, cb = _vfx_centroid(a), _vfx_centroid(b)
    if ca is None or cb is None:
        return 0.0
    return float(_np.hypot(ca[0] - cb[0], ca[1] - cb[1]))


def _vfx_jaccard(a, b, colors):
    pa = _vfx_quant_pal(a, colors); pb = _vfx_quant_pal(b, colors)
    if len(pa) == 0 or len(pb) == 0:
        return 1.0
    la, lb = _vfx_srgb_to_lab(pa), _vfx_srgb_to_lab(pb)
    Ka, Kb = len(la), len(lb)
    d = _vfx_ciede2000(_np.repeat(la, Kb, axis=0), _np.tile(lb, (Ka, 1))).reshape(Ka, Kb)
    inter = (int((d.min(axis=1) <= 10).sum()) + int((d.min(axis=0) <= 10).sum())) / 2.0
    union = Ka + Kb - inter
    return inter / union if union > 0 else 1.0


# --------------------------------------------------- frame-set loader + fire anchor
def _vfx_as_frames(x):
    """Accept: PIL Image | list[Image] | dir path | .png path | list[path]."""
    import glob as _glob
    if isinstance(x, Image.Image):
        return [x]
    if isinstance(x, str):
        if os.path.isdir(x):
            fs = sorted(_glob.glob(os.path.join(x, "*.png")))
            return [Image.open(f) for f in fs]
        return [Image.open(x)]
    out = []
    for it in x:
        out.append(it if isinstance(it, Image.Image) else Image.open(it))
    return out


_FIRE_REF_DIRS = [
    os.environ.get("RH_VFX_FIRE_REF", ""),
    os.path.join(_REPO, "_downloads", "vfx_packs", "foozle_pixel_magic", "extracted",
                 "Foozle_2DE0001_Pixel_Magic_Effects", "Fire_Ball"),
]
_fire_state = {"loaded": False, "palette": None, "frames": None, "control": None}


def _load_fire_reference():
    """Foozle CC0 Fire_Ball = the fire reference pack: palette (for style anchor) +
    frames (for the control score). Cached. Abstains cleanly if the pack is absent."""
    if _fire_state["loaded"]:
        return _fire_state
    _fire_state["loaded"] = True
    import glob as _glob
    frames, pal = [], []
    for d in _FIRE_REF_DIRS:
        if not d or not os.path.isdir(d):
            continue
        for f in sorted(_glob.glob(os.path.join(d, "*.png"))):
            try:
                im = Image.open(f).convert("RGBA")
                frames.append(im)
                q = Image.fromarray(_np.asarray(im)[:, :, :3]).convert("RGB").quantize(
                    colors=24, method=Image.MEDIANCUT)
                p = q.getpalette()[:24 * 3]
                pal += [(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)]
            except Exception:
                pass
        if frames:
            break
    _fire_state["frames"] = frames or None
    _fire_state["palette"] = pal or None
    if frames:
        sys.stderr.write(f"[vfx-gauntlet] fire reference loaded: {len(frames)} control frames, "
                         f"{len(pal)} palette colours\n")
    return _fire_state


def _lens_style_anchor_fire(cols):
    """REUSE of lens_style_anchor logic, pointed at the FIRE reference pack. Soft lens:
    flags a wildly off-fire palette (e.g. a purple mush blob). Abstains if no fire pack."""
    ref = _load_fire_reference()["palette"]
    if not ref:
        return None, "style_anchor(fire): abstain (no fire reference pack)"
    if not cols:
        return None, "style_anchor(fire): abstain (no colours)"
    near = sum(1 for c in cols if min(I._cdist(c, r) for r in ref) <= 80)
    frac = near / len(cols)
    if frac < 0.40:
        return False, f"off fire-ref palette ({frac:.2f} <0.40 near fire reference)"
    return True, f"fire-ref palette ok ({frac:.2f} near reference)"


# --------------------------------------------------------------- the metric bundle
def _vfx_measure(frames):
    bar = _vfx_bar()
    colors = int(bar["palette_quantize_colors"])
    arrs = [_vfx_arr(im) for im in frames]
    flat, ncol, palpha, off, dom, orph, corec, wholec, periph = ([] for _ in range(9))
    allcols = set()
    for a in arrs:
        fr, nc = _vfx_flatrun(a); flat.append(fr); ncol.append(nc)
        palpha.append(_vfx_partial_alpha(a))
        off.append(_vfx_offramp(a, colors, float(bar["offramp_de2000_gt"])))
        _, dmf, o = _vfx_silhouette(a); dom.append(dmf); orph.append(o)
        cc, _, wc = _vfx_hotcore(a, int(bar["bright_percentile"])); corec.append(cc); wholec.append(wc)
        periph.append(_vfx_periph_meansat(a, int(bar["periphery_percentile"])))
        m = a[:, :, 3] >= 128
        for c in _np.unique(a[:, :, :3][m].reshape(-1, 3), axis=0):
            allcols.add((int(c[0]), int(c[1]), int(c[2])))
    drifts, jacc = [], []
    for i in range(1, len(arrs)):
        drifts.append(_vfx_drift(arrs[i - 1], arrs[i]))
        jacc.append(_vfx_jaccard(arrs[i - 1], arrs[i], colors))
    med = lambda v: float(_np.median(v)) if v else 0.0
    mean = lambda v: float(_np.mean(v)) if v else 0.0
    return dict(
        n=len(frames), flat_med=med(flat), ncol_max=max(ncol) if ncol else 0,
        palpha_mean=mean(palpha), off_mean=mean(off),
        dom_med=med(dom), orphan_max=max(orph) if orph else 0,
        core_peak=max(corec) if corec else 0.0, whole_mean=mean(wholec),
        periph_mean=mean(periph), drift_max=max(drifts) if drifts else 0.0,
        jacc_mean=mean(jacc) if jacc else 1.0, palette_colours=sorted(allcols),
    )


def _vfx_composite(m):
    """Convenience 0-100 (SPEC). Excludes resolution-sensitive flat-run from the
    weighting (it stays a binary hard lens); vividness normalised to the Foozle mean."""
    bar = _vfx_bar()
    clip = lambda v: max(0.0, min(1.0, v))
    s_pix = 1.0 if (m["ncol_max"] <= bar["n_colors_ceil"] and m["flat_med"] >= bar["flat_run_floor"]) else 0.0
    s_alpha = 1.0 if m["palpha_mean"] <= bar["partial_alpha_ceil"] else 0.0
    s_off = 1.0 if m["off_mean"] <= bar["offramp_ceil"] else 0.0
    s_vivid = clip((m["whole_mean"] - 60.0) / (106.0 - 60.0))
    s_sil = clip(m["dom_med"])
    s_jac = clip(m["jacc_mean"])
    return 100.0 * (0.30 * s_pix + 0.20 * s_alpha + 0.15 * s_off + 0.20 * s_vivid
                    + 0.075 * s_sil + 0.075 * s_jac)


def _control_score():
    """Composite score of the Foozle CC0 control, computed once and cached. This is
    the reference ceiling a candidate must reach (neutralises absolute-threshold drift)."""
    st = _load_fire_reference()
    if st["control"] is not None:
        return st["control"]
    if not st["frames"]:
        st["control"] = None
        return None
    st["control"] = _vfx_composite(_vfx_measure(st["frames"]))
    return st["control"]


# --------------------------------------------------------------------- the gate
def run_vfx_gauntlet(frames_or_im, subject=None, use_vlm=True):
    """VFX-mode gate (VFX_PIPELINE.md sec 4). Input: a list of finished frames (or a
    dir / a single image / list of paths). Returns (passed, verdicts) exactly like
    run_gauntlet. Bands from vfx_bar.json (calibrated off the Foozle control).

    Lens roles (honest-degrade): HARD lenses block on explicit False
    {pixel_art, partial_alpha, offramp, emissive_vivid}; SOFT lenses are calibrated
    generous to the control and block only on worse-than-reference
    {silhouette, drift, jaccard, beats_control}; ADVISORY lenses log but never block
    {periphery_desat, sparkle, style_anchor(fire), vlm_identity}. An abstain (None)
    never blocks.
    """
    frames = _vfx_as_frames(frames_or_im)
    bar = _vfx_bar()
    verdicts = []
    ok = True

    def add(name, p, reason, hard):
        nonlocal ok
        verdicts.append((name, p, reason))
        if p is False and hard:
            ok = False

    if len(frames) == 0:
        return False, [("input", False, "no frames")]

    m = _vfx_measure(frames)

    # -- reused per-frame lens: pixel_art (n_colours ceiling is THE primary mush gate)
    npass = 0
    for im in frames:
        p, _ = lens_pixel_art(im)
        npass += 1 if p else 0
    frac_pix = npass / len(frames)
    pix_ok = (frac_pix >= 0.5) and (m["ncol_max"] <= bar["n_colors_ceil"]) and (m["flat_med"] >= bar["flat_run_floor"])
    add("pixel_art", bool(pix_ok),
        f"pixel_art {'ok' if pix_ok else 'FAIL'} (frames-pass {frac_pix:.2f}, "
        f"flat_med {m['flat_med']:.2f}>= {bar['flat_run_floor']}, ncol_max {m['ncol_max']}<= {bar['n_colors_ceil']})",
        hard=True)

    # -- reused lens: style_anchor pointed at the fire reference pack (ADVISORY/soft)
    sp, sr = _lens_style_anchor_fire(m["palette_colours"])
    add("style_anchor_fire", sp, sr, hard=False)

    # -- HARD: partial-alpha (the cheapest AI-mush discriminator)
    pa_ok = m["palpha_mean"] <= bar["partial_alpha_ceil"]
    add("partial_alpha", bool(pa_ok),
        f"partial-alpha {'ok' if pa_ok else 'FAIL'} ({m['palpha_mean']*100:.2f}% <= {bar['partial_alpha_ceil']*100:.1f}%)",
        hard=True)

    # -- HARD: off-ramp dE2000>10 ratio
    off_ok = m["off_mean"] <= bar["offramp_ceil"]
    add("offramp", bool(off_ok),
        f"off-ramp {'ok' if off_ok else 'FAIL'} ({m['off_mean']*100:.2f}% dE2000>10 <= {bar['offramp_ceil']*100:.0f}%)",
        hard=True)

    # -- HARD: EMISSIVE EXEMPTION (replaces the gothic desaturation ceiling)
    core_ok = m["core_peak"] >= bar["core_colourf_floor"]
    vivid_ok = m["whole_mean"] >= bar["whole_colourf_floor"]
    em_ok = core_ok and vivid_ok
    add("emissive_vivid", bool(em_ok),
        f"emissive {'ok' if em_ok else 'FAIL'} (hot-core colourfulness peak {m['core_peak']:.0f}>= "
        f"{bar['core_colourf_floor']:.0f}, whole colourfulness mean {m['whole_mean']:.0f}>= {bar['whole_colourf_floor']:.0f})",
        hard=True)

    # -- ADVISORY: smoke/ash periphery (two-sided design note; refs vary so never blocks)
    add("periphery_desat", None,
        f"periphery mean-sat {m['periph_mean']:.0f} (advisory; gothic-band ref <=118)", hard=False)

    # -- SOFT: single-dominant-blob silhouette (generous to Foozle spark frames)
    sil_ok = m["dom_med"] >= bar["dominant_frac_floor"]
    add("silhouette", bool(sil_ok),
        f"silhouette {'ok' if sil_ok else 'FAIL'} (dominant-blob median {m['dom_med']:.2f}>= "
        f"{bar['dominant_frac_floor']}, orphan-speckle max {m['orphan_max']})", hard=True)

    # -- SOFT: temporal drift (calibrated to the travelling control)
    dr_ok = m["drift_max"] <= bar["drift_ceil"]
    add("drift", bool(dr_ok),
        f"drift {'ok' if dr_ok else 'FAIL'} (max {m['drift_max']:.2f}px <= {bar['drift_ceil']}px)", hard=True)

    # -- SOFT: temporal palette Jaccard (inter-frame colour stability)
    jac_ok = m["jacc_mean"] >= bar["jaccard_floor"]
    add("jaccard", bool(jac_ok),
        f"jaccard {'ok' if jac_ok else 'FAIL'} (mean {m['jacc_mean']:.2f}>= {bar['jaccard_floor']})", hard=True)

    # -- SOFT: candidate must reach the Foozle control ceiling (drift-neutraliser).
    cand = _vfx_composite(m)
    ctrl = _control_score()
    if ctrl is None:
        add("beats_control", None, f"beats_control: abstain (no fire control pack); score {cand:.1f}", hard=False)
        strict = None
    else:
        bc_ok = cand >= 0.90 * ctrl              # 0.90 tolerance: don't reject legit refs below the hand-authored ceiling
        strict = cand >= ctrl
        add("beats_control", bool(bc_ok),
            f"beats_control {'ok' if bc_ok else 'FAIL'} (score {cand:.1f} vs control {ctrl:.1f}; "
            f"strict>=control: {'yes' if strict else 'no'})", hard=True)

    # -- ADVISORY: sparkle (post-smooth single-frame outliers). Approximated as an
    # orphan-speckle spike far above the set; logged, never blocks (temporal_smooth
    # in anim_finish is the real enforcer).
    add("sparkle", None, f"sparkle advisory (orphan-speckle max {m['orphan_max']})", hard=False)

    # -- ADVISORY: VLM identity (softest signal; never the sole gate)
    use_vlm = use_vlm and os.environ.get("RH_GAUNTLET_VLM", "1") != "0"
    if subject and use_vlm and _vlm_available():
        p, reason = lens_vlm_identity(frames[len(frames) // 2], subject)
        verdicts.append(("vlm_identity", p, reason))     # advisory: does not flip ok
    elif subject:
        verdicts.append(("vlm_identity", None, "vlm_identity: advisory abstain (no VLM)"))

    return ok, verdicts


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
