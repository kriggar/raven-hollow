#!/usr/bin/env python3
"""
ROGUE SPELL-KIT VFX GENERATOR  (BACKLOG #83 rogue rework + #56 VFX-uniqueness law).

Produces the 6 rogue spell VFX as PERFECTLY-CUT animation sheets (owner cutting standard),
each VISUALLY UNIQUE (no palette-swap reuse -- MANDATES SPELL-VFX UNIQUENESS), in the rogue's
cohesive gothic palette: VENOM GREEN + VIOLET SHADOW + STEEL, muted (never neon).

Method (honest):
  1. ComfyUI (SDXL + Pixel Art XL LoRA, owner's 5070 Ti, $0) renders clean SHAPE ELEMENTS
     -- a slash streak, a dagger, a throwing knife, a smoke puff, a rune sigil, an energy
     burst -- each cut to transparent. Elements are cached so reruns are free.
  2. Each element is RECOLOURED by luminance ramp into the spell's exact gothic palette
     (this is what guarantees the palette law + per-spell uniqueness -- the SHAPE is generated,
     the IDENTITY is authored), then ANIMATED into 8 distinct frames by an effect-appropriate
     motion model (arc sweep / venom coat+drip / radial throw / billow+rise / directional trail
     / mark-then-execute). Real generated art; deterministic, smooth, perfectly griddable motion.
  3. gridcut.build_sheet cuts every frame into its own uniform 96x96 cell, centred, zero bleed,
     and renders the grid-overlay montage the owner reviews before Godot.

6 spells: backstab, poison_blade, fan_of_knives, vanish, shadowstep, deathmark.

Run:  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/rogue_vfx.py --only backstab
      C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/rogue_vfx.py            # all 6
"""
from __future__ import annotations
import os, sys, io, json, time, math, argparse, urllib.request, urllib.parse
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I
import gridcut as G

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ELEM_DIR = os.path.join(HERE, "_rogue_elements")
SHEET_DIR = os.path.join(REPO, "assets", "art", "vfx", "rogue_kit")
MONT_DIR = os.path.join(REPO, "_screens", "rogue_kit", "sheets")
for d in (ELEM_DIR, SHEET_DIR, MONT_DIR):
    os.makedirs(d, exist_ok=True)

COMFY = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
CANVAS = 220            # generous compositor canvas; gridcut crops+fits into the cell
CELL = 96
FRAMES = 8

# ---- the rogue palette (muted gothic; every colour sits in interpret.GOTHIC) --------------
VENOM   = [(0.00, (0x1a, 0x20, 0x16)), (0.40, (0x47, 0x55, 0x2f)),
           (0.72, (0x7c, 0x8a, 0x4a)), (1.00, (0xc0, 0xd8, 0x72))]   # deep -> venom -> bright bloom
VIOLET  = [(0.00, (0x1a, 0x17, 0x20)), (0.42, (0x3a, 0x2f, 0x4e)),
           (0.74, (0x60, 0x50, 0x7c)), (1.00, (0x9c, 0x8c, 0xb4))]   # shadow -> violet -> pale
STEEL   = [(0.00, (0x22, 0x2a, 0x30)), (0.45, (0x5a, 0x67, 0x73)),
           (0.78, (0x88, 0x95, 0xa0)), (1.00, (0xcd, 0xcf, 0xc6))]   # dark -> steel -> bright edge
BLOODST = [(0.00, (0x24, 0x1f, 0x2b)), (0.40, (0x6e, 0x2a, 0x22)),
           (0.72, (0x8f, 0x3a, 0x2a)), (1.00, (0xe6, 0x9a, 0x6a))]   # dried blood -> hot edge


# =========================================================================================
# ComfyUI client (SDXL + Pixel Art XL) -- polite single-job queueing
# =========================================================================================
STYLE = ("pixel art game vfx element, single centered shape, plain solid flat chroma green "
         "background, no ground, no shadow, no scenery, clean flat shaded pixels, crisp edges")
NEG = ("blurry, jpeg artifacts, anti-aliasing, smooth gradient, 3d render, photo, realistic, "
       "multiple objects, cluttered, landscape, horizon, text, letters, numbers, watermark, "
       "signature, ui, frame, border, person, human, face, deformed")


def _post(path, payload):
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def _get(path):
    return json.loads(urllib.request.urlopen(COMFY + path, timeout=60).read())


def _fetch(info):
    q = urllib.parse.urlencode({"filename": info["filename"], "subfolder": info.get("subfolder", ""),
                                "type": info.get("type", "output")})
    raw = urllib.request.urlopen(COMFY + "/view?" + q, timeout=60).read()
    return Image.open(io.BytesIO(raw)).convert("RGBA")


def _sdxl_wf(pos, seed, w=768, h=768):
    return {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "10": {"class_type": "LoraLoader", "inputs": {"lora_name": "pixel-art-xl.safetensors",
               "strength_model": 1.0, "strength_clip": 1.0, "model": ["4", 0], "clip": ["4", 1]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["10", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["10", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 26, "cfg": 7.0,
              "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0,
              "model": ["10", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "rh_rogue_elem", "images": ["8", 0]}},
    }


def _run(wf, timeout=600):
    t0 = time.time()
    pid = _post("/prompt", {"prompt": wf}).get("prompt_id")
    if not pid:
        return None
    while time.time() - t0 < timeout:
        h = _get(f"/history/{pid}")
        if pid in h:
            st = h[pid].get("status", {}).get("status_str")
            outs = h[pid].get("outputs", {}).get("9", {})
            if outs.get("images"):
                return outs["images"]
            if st == "error":
                sys.stderr.write("[rogue_vfx] EXEC ERROR\n"); return None
        time.sleep(1.5)
    return None


def gen_element(elem_id: str, prompt: str, seeds=(700, 1607, 4241), regen=False) -> Image.Image:
    """Render an element (a few seeds), cut clean, pick the best-formed, cache to disk."""
    cache = os.path.join(ELEM_DIR, f"{elem_id}.png")
    if os.path.exists(cache) and not regen:
        return Image.open(cache).convert("RGBA")
    best, best_score = None, -1.0
    for s in seeds:
        imgs = _run(_sdxl_wf(f"{prompt}, " + STYLE, s))
        if not imgs:
            print(f"  [elem] {elem_id} seed{s}: gen failed", flush=True); continue
        cut = I.cutout(_fetch(imgs[0]))
        bb = I.alpha_bbox(cut, 24)
        if bb:
            cut = cut.crop(bb)
        frac = I._opaque_fraction(cut)
        blob = I.largest_blob_fraction(cut)
        score = blob - abs(frac - 0.35)            # prefer one solid shape, moderate fill
        print(f"  [elem] {elem_id} seed{s}: frac={frac:.3f} blob={blob:.3f} score={score:.3f}", flush=True)
        if score > best_score:
            best, best_score = cut, score
    if best is None:
        raise RuntimeError(f"element {elem_id} failed to generate")
    best.save(cache)
    return best


# =========================================================================================
# frame-compositing helpers (numpy + PIL)
# =========================================================================================
def luma_ramp(im: Image.Image, stops, gain: float = 1.0) -> Image.Image:
    """Recolour by luminance into a palette gradient (keeps shape + alpha)."""
    arr = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb, a = arr[..., :3], arr[..., 3]
    lum = np.clip((0.30 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]) / 255.0 * gain, 0, 1)
    ts = [s[0] for s in stops]
    cs = np.array([s[1] for s in stops], np.float32)
    out = np.stack([np.interp(lum, ts, cs[:, k]) for k in range(3)], axis=-1)
    res = np.concatenate([out, a[..., None]], axis=-1)
    return Image.fromarray(np.clip(res, 0, 255).astype(np.uint8), "RGBA")


def fit_long(im: Image.Image, px: int) -> Image.Image:
    bb = I.alpha_bbox(im, 24)
    if bb:
        im = im.crop(bb)
    s = px / float(max(im.size))
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def xform(im, scale=1.0, rot_deg=0.0, alpha=1.0):
    if scale != 1.0:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    if rot_deg:
        im = im.rotate(rot_deg, expand=True, resample=Image.BICUBIC)
    if alpha != 1.0:
        r, g, b, a = im.split()
        a = a.point(lambda v: int(v * alpha))
        im = Image.merge("RGBA", (r, g, b, a))
    return im


def blank():
    return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))


def paste_c(canvas, im, cx, cy):
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def teardrop(size, color):
    """A small procedural venom droplet (no ComfyUI needed)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    a = np.zeros((size, size), np.float32)
    cx = size / 2.0
    for y in range(size):
        for x in range(size):
            ty = y / (size - 1)
            rad = 0.16 + 0.30 * (ty ** 1.6)                  # narrow top, round bottom
            if ((x - cx) / (rad * size)) ** 2 + ((y - size * 0.62) / (size * 0.42)) ** 2 <= 1.0:
                a[y, x] = 255
    rgb = np.zeros((size, size, 3), np.float32) + np.array(color, np.float32)
    hl = np.array([[max(0, 1 - ((x - cx * 0.8) ** 2 + (y - size * 0.4) ** 2) / (size * 0.5) ** 2)
                    for x in range(size)] for y in range(size)], np.float32)
    rgb = rgb * (0.7 + 0.5 * hl[..., None])
    out = np.concatenate([np.clip(rgb, 0, 255), a[..., None]], axis=-1)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def streak(w, h, color, feather=0.5):
    """A thin horizontal motion streak: bright core, fading tail to the left."""
    im = np.zeros((h, w, 4), np.float32)
    for x in range(w):
        tx = x / (w - 1)
        edge = math.sin(math.pi * tx) ** 0.6
        head = tx ** 1.4                                     # brighter toward the leading (right) edge
        for y in range(h):
            ty = abs(y - h / 2) / (h / 2)
            v = max(0.0, (1 - ty ** 1.5)) * edge * (0.35 + 0.65 * head)
            im[y, x, :3] = np.array(color, np.float32) * min(1.0, v * 1.4)
            im[y, x, 3] = 255 * min(1.0, v)
    return Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGBA")


def spark(size, color, rays=4):
    """A sharp procedural hit-spark: bright core + thin radiating spikes (crit flash)."""
    im = np.zeros((size, size, 4), np.float32)
    cx = cy = (size - 1) / 2.0
    col = np.array(color, np.float32)
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy) / (size / 2.0)
            if r > 1.0:
                continue
            ang = math.atan2(dy, dx)
            spike = abs(math.cos(rays / 2.0 * ang)) ** 6          # thin star spikes
            core = max(0.0, 1 - r * 3.2)                          # hot round core
            v = max(core, spike * max(0.0, 1 - r) ** 1.3)
            im[y, x, :3] = np.clip(col * (0.5 + 1.1 * v), 0, 255)
            im[y, x, 3] = 255 * min(1.0, v * 1.5)
    return Image.fromarray(im.astype(np.uint8), "RGBA")


def ease(t):      # smoothstep
    return t * t * (3 - 2 * t)


def env(t, up=0.25, down=0.7):
    """0->1 rise by `up`, hold, ->0 fade after `down` (alpha envelope)."""
    if t < up:
        return ease(t / up)
    if t > down:
        return 1 - ease((t - down) / (1 - down))
    return 1.0


def bell(t, lo=0.14, span=0.72):
    """A half-sine that is VISIBLE at both ends (birth + lingering dissipation) and peaks
    mid-cycle -- so no animation frame is ever fully empty (every grid cell earns its place)."""
    return math.sin(math.pi * (lo + span * max(0.0, min(1.0, t))))


# =========================================================================================
# THE 6 SPELLS -- each returns a list of FRAMES frames (PIL RGBA on CANVAS)
# =========================================================================================
def fx_backstab(E):
    """Crit slash: a steel crescent sweeps through an arc, a blood-red crit spark flashes at the
    blade tip on impact. Visible from frame 0 (fast 20fps one-shot; no empty cells)."""
    smear = luma_ramp(fit_long(E["slash"], 150), STEEL)
    crit = spark(90, (0xe6, 0x86, 0x6a), rays=4)         # sharp blood-red crit flash (procedural accent)
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        ang = -60 + 128 * ease(t)                        # sweep the arc across the whole cycle
        sc = 0.72 + 0.42 * ease(min(1.0, t * 1.4))
        a = 0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.05))   # bright mid, still lit at ends
        paste_c(c, xform(smear, scale=sc, rot_deg=ang, alpha=min(1.0, a)), CANVAS / 2, CANVAS / 2)
        if 0.34 <= t <= 0.80:                            # crit spark rides the blade tip on impact
            k = (t - 0.34) / 0.46
            rad = 48 * sc
            tx = CANVAS / 2 + math.cos(math.radians(ang - 18)) * rad
            ty = CANVAS / 2 + math.sin(math.radians(ang - 18)) * rad
            paste_c(c, xform(crit, scale=0.5 + 0.9 * k, alpha=math.sin(math.pi * k)), tx, ty)
        frames.append(c)
    return frames


def fx_poison_blade(E):
    """Venom coat: a steel dagger, a green glaze blooms down the blade, then venom drips fall."""
    blade = luma_ramp(fit_long(E["dagger"], 150), STEEL)
    glaze = luma_ramp(fit_long(E["dagger"], 150), VENOM, gain=1.15)
    drop = teardrop(20, (0x9a, 0xc4, 0x5a))
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        paste_c(c, blade, CANVAS / 2, CANVAS / 2)
        coat = xform(glaze, alpha=0.85 * env(t, 0.2, 0.85))
        paste_c(c, coat, CANVAS / 2, CANVAS / 2)
        if t > 0.4:                                      # drips detach and fall with gravity
            for k, phase in enumerate((0.40, 0.55, 0.70)):
                if t >= phase:
                    dt = (t - phase) / (1 - phase)
                    dx = CANVAS / 2 + (k - 1) * 16
                    dy = CANVAS / 2 + 20 + 70 * (dt ** 1.7)
                    paste_c(c, xform(drop, scale=0.7 + 0.3 * dt, alpha=1 - 0.6 * dt), dx, dy)
        frames.append(c)
    return frames


def fx_fan_of_knives(E):
    """Radial burst: eight steel knives fly outward, spinning, venom-tipped, fading at the rim."""
    knife = luma_ramp(fit_long(E["knife"], 60), STEEL)
    # venom-tipped: overlay a green glow on the blade tip region
    kv = luma_ramp(fit_long(E["knife"], 60), VENOM)
    knife = Image.alpha_composite(knife, xform(kv, alpha=0.35))
    N = 8
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        rad = 8 + 90 * ease(t)                           # tight cluster (frame 0) -> full rim (frame 7)
        a = min(1.0, 0.6 + 0.4 * math.sin(math.pi * min(1.0, t * 1.05)))
        for k in range(N):
            base = k * (360 / N)
            ang = base + 40 * t                          # slight rotational drift
            kk = xform(knife, rot_deg=-(ang + 90), alpha=a)     # point outward
            kx = CANVAS / 2 + math.cos(math.radians(ang)) * rad
            ky = CANVAS / 2 + math.sin(math.radians(ang)) * rad
            paste_c(c, kk, kx, ky)
        frames.append(c)
    return frames


def fx_vanish(E):
    """Smoke vanish: violet-black puffs billow outward and up, bloom, then dissipate."""
    puff = luma_ramp(fit_long(E["smoke"], 130), VIOLET)
    seeds = [(-24, 6, 0.0), (22, 10, 0.0), (0, -12, 0.06), (-6, 24, 0.10), (14, -2, 0.03)]
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        for (ox, oy, ph) in seeds:
            lt = max(0.0, min(1.0, (t - ph) / (1 - ph + 1e-6)))
            sc = 0.34 + 1.15 * ease(lt)
            rise = -28 * lt
            a = 0.95 * bell(lt, lo=0.22, span=0.56)      # dense small puff (f0) -> bloom -> dispersing wisp (f7); floor > cut threshold
            paste_c(c, xform(puff, scale=sc, rot_deg=ox * 2, alpha=a),
                    CANVAS / 2 + ox * (0.4 + lt), CANVAS / 2 + oy * (0.4 + lt) + rise)
        frames.append(c)
    return frames


def fx_shadowstep(E):
    """Directional dash: a steel-violet streak sweeps L->R with fading shadow afterimage puffs."""
    puff = luma_ramp(fit_long(E["smoke"], 90), VIOLET)
    strk = streak(180, 44, (0xb6, 0xa8, 0xcc))
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        headx = 28 + 150 * ease(t)                       # dash begins on-screen (f0) -> exits right (f7)
        # trailing afterimage puffs (fade the further back they are)
        for k in range(4):
            back = headx - 26 * (k + 1)
            if back < 16:
                continue
            a = bell(t, lo=0.16, span=0.72) * (0.75 - 0.15 * k)
            paste_c(c, xform(puff, scale=0.72 - 0.08 * k, alpha=max(0.0, a)), back, CANVAS / 2 + 6)
        paste_c(c, xform(strk, alpha=0.5 + 0.5 * bell(t, lo=0.2, span=0.6)), headx - 60, CANVAS / 2)
        frames.append(c)
    return frames


def fx_deathmark(E):
    """Mark, then execute: a violet rune sigil forms and rotates, then a blood-red burst erupts."""
    mark = luma_ramp(fit_long(E["rune"], 150), VIOLET)
    burst = luma_ramp(fit_long(E["burst"], 160), BLOODST)
    frames = []
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        c = blank()
        # phase 1: the mark is already forming at f0 (visible), spins, fades as the burst takes over
        ma = math.sin(math.pi * (0.20 + 0.50 * min(1.0, t / 0.62))) * (1 - max(0.0, (t - 0.5) / 0.5))
        paste_c(c, xform(mark, scale=0.78 + 0.22 * ease(min(1, t / 0.5)), rot_deg=-70 * t,
                         alpha=max(0.0, ma)), CANVAS / 2, CANVAS / 2)
        # phase 2: the execute burst erupts through the mark (embers still lit at f7)
        if t > 0.42:
            bt = (t - 0.42) / 0.58
            paste_c(c, xform(burst, scale=0.4 + 1.0 * ease(bt), rot_deg=30 * bt,
                             alpha=bell(bt, lo=0.22, span=0.56)), CANVAS / 2, CANVAS / 2)
        frames.append(c)
    return frames


SPELLS = {
    "backstab":      {"fn": fx_backstab,      "fps": 20.0, "loop": False,
                      "needs": ["slash", "burst"], "desc": "crit slash arc (steel + blood-red)"},
    "poison_blade":  {"fn": fx_poison_blade,  "fps": 14.0, "loop": False,
                      "needs": ["dagger"],    "desc": "venom coat + drip (venom green + steel)"},
    "fan_of_knives": {"fn": fx_fan_of_knives, "fps": 18.0, "loop": False,
                      "needs": ["knife"],     "desc": "radial blade burst (steel + venom tip)"},
    "vanish":        {"fn": fx_vanish,        "fps": 16.0, "loop": False,
                      "needs": ["smoke"],     "desc": "smoke-puff vanish (violet shadow)"},
    "shadowstep":    {"fn": fx_shadowstep,    "fps": 20.0, "loop": False,
                      "needs": ["smoke"],     "desc": "dash smoke trail (violet + steel streak)"},
    "deathmark":     {"fn": fx_deathmark,     "fps": 16.0, "loop": False,
                      "needs": ["rune", "burst"], "desc": "mark + execute burst (violet + blood)"},
}

ELEM_PROMPTS = {
    "slash": "a single curved crescent slash streak, sharp motion blur blade sweep, thin pointed ends",
    "dagger": "a single slender dagger weapon, straight double edged blade pointing up, small crossguard and grip",
    "knife": "a single small throwing knife, narrow pointed blade pointing straight up, tiny handle",
    "smoke": "a single soft round puff of billowing smoke cloud, wispy feathered edges",
    "rune": "a single circular occult rune sigil, thin arcane geometric glyph ring, hollow center",
    "burst": "a single sharp starburst explosion of jagged energy spikes radiating from center",
}


def elements_for(names, regen=False):
    return {n: gen_element(n, ELEM_PROMPTS[n], regen=regen) for n in names}


def build(only=None, regen=False):
    todo = [only] if only else list(SPELLS.keys())
    need = sorted({e for k in todo for e in SPELLS[k]["needs"]})
    print(f"[rogue_vfx] elements needed: {need}", flush=True)
    E = elements_for(need, regen=regen)
    reports = []
    for name in todo:
        spec = SPELLS[name]
        print(f"[rogue_vfx] composing {name} ...", flush=True)
        frames = spec["fn"](E)
        rep = G.build_sheet(frames, name, SHEET_DIR, MONT_DIR, cell=CELL, cols=FRAMES,
                            margin=6, fps=spec["fps"], loop=spec["loop"], anchor="center",
                            extra_meta={"spell": name, "palette": "rogue venom/violet/steel",
                                        "desc": spec["desc"], "source": "comfyui:sdxl+pixelartxl+authored-motion"})
        tag = "OK" if rep["bleed_ok"] else "BLEED!"
        print(f"  -> {name}: {rep['cols']}x{rep['rows']} @ {CELL}px  CUT={tag}", flush=True)
        print(f"     sheet   {rep['sheet']}", flush=True)
        print(f"     montage {rep['montage']}", flush=True)
        reports.append(rep)
    with open(os.path.join(SHEET_DIR, "_rogue_kit_report.json"), "w", encoding="utf-8") as f:
        json.dump(reports, f, indent=2)
    allok = all(r["bleed_ok"] for r in reports)
    print(f"[rogue_vfx] DONE {len(reports)} sheets  |  all-cut-clean={allok}", flush=True)
    return reports


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None, help="single spell id (early gate)")
    ap.add_argument("--regen", action="store_true", help="force re-render elements")
    args = ap.parse_args()
    build(only=args.only, regen=args.regen)
