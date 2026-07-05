#!/usr/bin/env python3
"""
COMFYUI GENERATION PIPELINE  (BACKLOG #114 / owner "lead with generation", 2026-07-05).

The real "massive library" unlock: drive the local ComfyUI (SDXL + Pixel Art XL LoRA on the
owner's RTX 5070 Ti, $0, unlimited) to mass-produce style-locked, top-down, gothic-palette
assets that fix zone sparsity and replace the lean ColorRect composites in zone_builder.gd
(pier / cargo / crane / salt_pan / ledger_tablet ...).

Two lanes:
  * INANIMATE  (props / buildings / tiles / monuments): SDXL+PixelArtXL single render ->
    interpret.clean_sprite() (cutout, pixel-snap, quantize, alpha-trim, de-fringe) ->
    interpret.cleanliness_report() SPOTLESS gate -> library.json.  Fast, the bulk.
  * ANIMATED   (creatures): SDXL base pose -> Wan2.2 TI2V img2vid (proven-consistent motion,
    memory: project_local_image_gen) -> pixel-snap 8 frames/state -> per-frame clean+verify ->
    animated strip + GIF + library entry {animated:true, states, frames_per_state}. Heavy/slow.

HONESTY: inanimate is fast & reliable and scales. Animated frames are REAL Wan-video-derived
frames (not procedural squash, not static-labelled-animated); throughput is limited by VRAM/RAM,
reported truthfully. If a clip fails, it is dropped, not faked.

Run with the ComfyUI venv python (PIL + numpy + rembg):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/generate.py --batch sample
"""
from __future__ import annotations
import os, sys, io, json, time, argparse, urllib.request, urllib.parse
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I   # clean_sprite, cleanliness_report, montage, animated_strip_montage, library_add, ASSETLIB
import gauntlet as _GAUNTLET   # the vision gauntlet (#115) — final unanimous gate

COMFY = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
# Disk law (owner): bulk/raw output goes to D:, NEVER C:. Only the small committed deliverables
# (library.json + verified montages) stay in the repo on C:.
RAW = os.environ.get("RH_GEN_OUTPUT", r"D:\raven hollow\gen_output")
COMFY_OUTPUT_DIR = r"C:\Users\vstef\ComfyUI\output"
VERIFIED = os.path.join(I.ASSETLIB, "verified")
os.makedirs(RAW, exist_ok=True)
os.makedirs(VERIFIED, exist_ok=True)


def _prune_comfy(info):
    """Delete ComfyUI's on-disk copy (C:) of a fetched render — keep C lean during marathons."""
    try:
        p = os.path.join(COMFY_OUTPUT_DIR, info.get("subfolder", ""), info["filename"])
        if os.path.exists(p):
            os.remove(p)
    except Exception:
        pass

STYLE = ("pixel art, top-down three-quarter view video game asset, ONE single centered object only, "
         "muted gothic dark-fantasy palette, mud brown moss green cold slate grey warm lantern gold, "
         "desaturated weathered aged, clean flat shaded pixels, crisp dark outline, "
         "isolated on a plain uniform solid flat {bg} screen background, "
         "no ground, no floor, no shadow, no drop shadow, no cast shadow, no scenery")
NEG = ("blurry, jpeg artifacts, anti-aliasing, smooth gradient, 3d render, octane, photo, realistic, "
       "multiple objects, two, three, row of objects, duplicated, group, collection, set, grid of items, "
       "cluttered scene, landscape, horizon, ground, floor, drop shadow, cast shadow, ground shadow, "
       "reflection, text, letters, numbers, watermark, "
       "signature, ui, frame, border, bright saturated neon colors, rainbow, glow, lens flare, "
       "person, human, face, animal, deformed, extra parts")

BGWORDS = {"green": "chroma green", "magenta": "magenta"}


# ---------------------------------------------------------------------------------------
# ComfyUI HTTP client
# ---------------------------------------------------------------------------------------
def _post(path, payload):
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def _get(path):
    return json.loads(urllib.request.urlopen(COMFY + path, timeout=60).read())


def _fetch_image(info, prune=True):
    q = urllib.parse.urlencode({"filename": info["filename"], "subfolder": info.get("subfolder", ""),
                                "type": info.get("type", "output")})
    raw = urllib.request.urlopen(COMFY + "/view?" + q, timeout=60).read()
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    if prune:
        _prune_comfy(info)          # keep C: lean — the bytes are already in memory
    return im


def sdxl_workflow(pos, neg, seed, w=1024, h=1024, lora_strength=1.0):
    return {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "10": {"class_type": "LoraLoader", "inputs": {"lora_name": "pixel-art-xl.safetensors",
               "strength_model": lora_strength, "strength_clip": lora_strength, "model": ["4", 0], "clip": ["4", 1]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["10", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": neg, "clip": ["10", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 28, "cfg": 7.0,
              "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0,
              "model": ["10", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "rh_asset", "images": ["8", 0]}},
    }


def run_workflow(wf, out_node="9", timeout=600):
    t0 = time.time()
    pid = _post("/prompt", {"prompt": wf}).get("prompt_id")
    if not pid:
        return None
    while time.time() - t0 < timeout:
        h = _get(f"/history/{pid}")
        if pid in h:
            st = h[pid].get("status", {}).get("status_str")
            outs = h[pid].get("outputs", {}).get(out_node, {})
            if outs.get("images"):
                return outs["images"]
            if st == "error":
                sys.stderr.write("[gen] EXEC ERROR: " + json.dumps(h[pid].get("status", {}))[:400] + "\n")
                return None
        time.sleep(1.5)
    return None


# ---------------------------------------------------------------------------------------
# INANIMATE lane
# ---------------------------------------------------------------------------------------
def gen_prop(spec, seed):
    """Generate one render, then SPLIT it into its clean single-object sprites (owner: one
    sprite per cell). Returns (list_of_clean_sprites, raw_path)."""
    bg = spec.get("bg", "green")
    pos = f"{spec['subject']}, " + STYLE.format(bg=BGWORDS[bg])
    imgs = run_workflow(sdxl_workflow(pos, NEG, seed))
    if not imgs:
        return None, None
    full = _fetch_image(imgs[0])
    catdir = os.path.join(RAW, spec["category"])
    os.makedirs(catdir, exist_ok=True)
    rawp = os.path.join(catdir, f"{spec['id']}_{seed}_raw.png")
    full.convert("RGBA").save(rawp)
    objs = I.process_render(full, target_px=spec.get("target_px", 64),
                            n_colors=spec.get("n_colors", 24), nudge=spec.get("nudge", 0.34),
                            split=not spec.get("single", False))
    return objs, rawp


def run_inanimate(specs, tag):
    outdir = os.path.join(VERIFIED, f"gen_{tag}")
    os.makedirs(outdir, exist_ok=True)
    passed, rejected, sprites = [], [], []
    for spec in specs:
        n = spec.get("count", 2)
        for k in range(n):
            seed = spec.get("seed", 1000) + k * 7919
            objs, rawp = gen_prop(spec, seed)
            if not objs:
                rejected.append((spec["id"], seed, "gen_failed_or_empty"))
                print(f"  GENFAIL {spec['id']} seed{seed}", flush=True)
                continue
            for j, clean in enumerate(objs):
                ok, scores = I.cleanliness_report(clean, require_single_subject=not spec.get("single", False))
                suffix = f"_{seed}" + (f"_{j}" if len(objs) > 1 else "")
                gok, gv = _GAUNTLET.run_gauntlet(clean) if ok else (False, [])
                if ok and not gok:
                    ok = False
                    scores["gauntlet"] = _GAUNTLET.verdict_reasons(gv)
                if ok:
                    aid = f"{spec['id']}{suffix}"
                    outp = os.path.join(outdir, aid + ".png")
                    clean.save(outp)
                    sprites.append(clean)
                    I.library_add({
                        "id": aid, "category": spec["category"], "path": os.path.relpath(outp, I.ASSETLIB),
                        "size": scores["size"], "animated": False, "states": [], "frames_per_state": {},
                        "facing": "n/a", "biome_fit": spec.get("biome_fit", []),
                        "source": "comfyui:sdxl+pixelartxl", "license": "generated-original (CC0, owner-owned)",
                        "replaces_composite": spec.get("replaces"), "subject": spec["subject"],
                        "cleanliness": scores, "verdict": "PASS",
                    })
                    passed.append(aid)
                    print(f"  PASS {aid}  colors={scores['n_colors']} blob={scores['largest_blob_frac']} compat={scores['palette_compat_frac']}", flush=True)
                else:
                    fails = [k2 for k2, v in scores["checks"].items() if not v]
                    extra = (" | gauntlet: " + scores["gauntlet"]) if scores.get("gauntlet") else ""
                    rejected.append((f"{spec['id']}{suffix}", seed, ",".join(fails) + extra))
                    print(f"  REJECT {spec['id']}{suffix}  fails={fails}{extra}", flush=True)
    if sprites:
        m = I.montage(sprites, cols=6, title=f"gen_{tag}")
        mp = os.path.join(outdir, f"gen_{tag}_montage.png")
        m.convert("RGB").save(mp)
        print(f"[gen] montage -> {mp}", flush=True)
    print(f"[gen] {tag}: {len(passed)} PASS / {len(rejected)} reject", flush=True)
    return passed, rejected


# ---------------------------------------------------------------------------------------
# ANIMATED lane  (Wan2.2 TI2V img2vid -> pixel-snap frames)
# ---------------------------------------------------------------------------------------
WAN_NEG = ("static, still, frozen, blurry, low quality, jpeg artifacts, watermark, text, deformed, "
           "extra limbs, duplicate, morphing, changing background, ground, floor, shadow, terrain, "
           "grass, scenery, fire, flames, torch, glow, glowing, magic, aura, lens flare, smoke, "
           "particles, color change, recolor")

# ---------------------------------------------------------------------------------------
# WAN ENVELOPE  (owner MAX-EFFORT law, sorceress-derived, 2026-07-06)
# Wan2.2-TI2V-5B is happiest inside a fixed envelope: latent length must be 4k+1 (the temporal VAE
# packs 4 frames per latent + 1 anchor), 24 fps, 720p base. We SNAP any requested length to 4k+1 and
# WARN, and the seed is always logged + settable so a clip is reproducible / retry-routable (part E).
# ---------------------------------------------------------------------------------------
WAN_FPS = 24
WAN_DEFAULT_RES = (1280, 720)          # 720p envelope default (sprite lane overrides to a square)


def snap_wan_length(n):
    """Snap a requested frame length to the nearest valid Wan 4k+1 value (min 5). Returns
    (snapped, changed:bool) so the caller can warn."""
    n = max(5, int(n))
    k = max(1, round((n - 1) / 4.0))
    snapped = k * 4 + 1
    return snapped, (snapped != n)


# Frame-budget presets: each sets the EXTRACTION frame count (how many keyframes we pull from the
# clip for the sprite) + a motion prompt hint. `vfx` = free (keep all usable frames). The Wan clip
# LENGTH is independent and always snapped to the 4k+1 envelope.
PRESETS = {
    "idle":   {"frames": 4, "hint": "subtle idle breathing, gentle sway, minimal motion, weight shift"},
    "walk4":  {"frames": 4, "hint": "4-pose walk cycle, legs striding, contact-pass-contact-pass"},
    "walk8":  {"frames": 8, "hint": "smooth 8-frame walk cycle, legs striding, gentle body bob"},
    "attack": {"frames": 6, "hint": "attack swing, wind-up then strike then recover, clear silhouette"},
    "vfx":    {"frames": 0, "hint": "roiling energy, layered particles, glow falloff, secondary motion"},
}


# ---------------------------------------------------------------------------------------
# RETRY ROUTES  (owner law, part E — never fail a whole batch for one item)
# On a gauntlet FAIL of an animation item: attempts 1-2 re-roll the SEED (same settings); attempt 3
# switches the SETTINGS route (more steps + different cfg/denoise). Route history is logged. A single
# item that exhausts its routes is DROPPED (returns None) — the batch keeps going.
# ---------------------------------------------------------------------------------------
def plan_routes(base_seed, max_attempts=3):
    routes = []
    for i in range(max_attempts):
        seed = (int(base_seed) + i * 104729) % 2_000_000_000
        if i < 2:
            settings = {"steps": 28, "cfg": 5.0, "denoise": 1.0}
            why = ("primary route" if i == 0 else "alternate seed (settings held)")
        else:
            settings = {"steps": 36, "cfg": 6.0, "denoise": 0.9}
            why = "alternate settings route (steps 36 / cfg 6.0 / denoise 0.9)"
        routes.append({"attempt": i + 1, "seed": seed, "settings": settings, "why": why})
    return routes


def run_with_retry(item_id, attempt_fn, base_seed, max_attempts=3, log=None):
    """Run attempt_fn(seed, settings) -> (ok:bool, payload, detail:str) across the retry plan.
    Logs every route, returns (payload_or_None, history). NEVER raises for a single item."""
    log = log or (lambda m: print(m, flush=True))
    history = []
    for r in plan_routes(base_seed, max_attempts):
        try:
            ok, payload, detail = attempt_fn(r["seed"], r["settings"])
        except Exception as e:
            ok, payload, detail = False, None, f"exception: {e}"
        history.append({"attempt": r["attempt"], "seed": r["seed"], "why": r["why"],
                        "ok": bool(ok), "detail": detail})
        log(f"[retry] {item_id} attempt {r['attempt']} seed={r['seed']} ({r['why']}): "
            f"{'PASS' if ok else 'FAIL'} - {detail}")
        if ok:
            return payload, history
    log(f"[retry] {item_id}: all {max_attempts} routes failed - item DROPPED, batch continues")
    return None, history


def _prep_start(clean_char, W, H):
    im = clean_char.convert("RGBA")
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    th = int(H * 0.82)
    sc = th / im.height
    nw, nh = max(1, int(im.width * sc)), max(1, int(im.height * sc))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 255, 0, 255))
    canvas.alpha_composite(im, ((W - nw) // 2, H - nh - int(H * 0.05)))
    name = f"rh_wan_start_{int(time.time()*1000)}.png"
    canvas.convert("RGB").save(os.path.join(r"C:\Users\vstef\ComfyUI\input", name))
    return name


def wan_workflow(start_name, pos, seed, W, H, length, steps=28, cfg=5.0, denoise=1.0):
    length, changed = snap_wan_length(length)
    if changed:
        sys.stderr.write(f"[wan] envelope: snapped length -> {length} (must be 4k+1)\n")
    sys.stderr.write(f"[wan] seed={seed} {W}x{H} length={length} fps={WAN_FPS} steps={steps} cfg={cfg} denoise={denoise}\n")
    return {
        "37": {"class_type": "UNETLoader", "inputs": {"unet_name": "wan2.2_ti2v_5B_fp16.safetensors", "weight_dtype": "default"}},
        "38": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan", "device": "default"}},
        "39": {"class_type": "VAELoader", "inputs": {"vae_name": "wan2.2_vae.safetensors"}},
        "48": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["37", 0], "shift": 8.0}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["38", 0]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": WAN_NEG, "clip": ["38", 0]}},
        "55": {"class_type": "LoadImage", "inputs": {"image": start_name}},
        "63": {"class_type": "Wan22ImageToVideoLatent", "inputs": {"vae": ["39", 0], "width": W, "height": H, "length": length, "batch_size": 1, "start_image": ["55", 0]}},
        "3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "uni_pc", "scheduler": "simple", "denoise": denoise, "model": ["48", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["63", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["39", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "rh_wan_frames"}},
    }


def _chroma_key_green(im):
    im = im.convert("RGBA"); px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if g > 90 and g > r + 35 and g > b + 35:
                px[x, y] = (r, g, b, 0)
            elif g > max(r, b):
                px[x, y] = (r, max(r, b), b, a)
    return im


def pixelsnap_frames(frame_imgs, count=8, target_px=56, n_colors=32, skip=6):
    usable = frame_imgs[skip:len(frame_imgs) - 4] or frame_imgs
    idx = [round(i * (len(usable) - 1) / max(1, count - 1)) for i in range(count)]
    picked = [usable[i] for i in idx]
    # shared master palette across the whole cycle => color-constant character
    keyed = []
    for f in picked:
        k = _chroma_key_green(f)          # remove green screen if Wan kept it
        if I._opaque_fraction(k) > 0.9:   # Wan invented a dark/opaque bg instead -> robust cutout
            k = I.cutout(f)
        k = I._defringe(k)
        bb = I.alpha_bbox(k, 24)
        if bb:
            k = k.crop(bb)
        sc = target_px / float(k.height)
        k = k.resize((max(1, int(k.width * sc)), target_px), Image.LANCZOS)
        keyed.append(k)
    mont = Image.new("RGB", (sum(k.width for k in keyed), target_px), (0, 0, 0))
    x = 0
    for k in keyed:
        bgc = Image.new("RGB", k.size, (0, 0, 0)); bgc.paste(k.convert("RGB"), (0, 0), k.split()[3])
        mont.paste(bgc, (x, 0)); x += k.width
    master = mont.quantize(colors=n_colors, method=Image.MEDIANCUT, dither=Image.NONE)
    frames = []
    for k in keyed:
        q = k.convert("RGB").quantize(palette=master, dither=Image.NONE).convert("RGB")
        a = k.split()[3].point(lambda v: 255 if v >= 110 else 0)
        rgba = Image.merge("RGBA", (*q.split(), a))
        rgba = I._despeckle(rgba, min_blob=5)
        bb = I.alpha_bbox(rgba, 128)
        if bb:
            rgba = rgba.crop(bb)
        pad = Image.new("RGBA", (rgba.width + 2, rgba.height + 2), (0, 0, 0, 0))  # 1px margin -> alpha_trimmed
        pad.alpha_composite(rgba, (1, 1))
        frames.append(pad)
    return frames


def gen_creature(spec, preset=None, seed=None):
    """base pose -> Wan clip per state -> pixel-snap -> clean frames -> strip + gif + library.
    `preset` (idle|walk4|walk8|attack|vfx) sets the extraction frame budget + a motion hint;
    `seed` overrides spec's seed (retry routing, part E). The Wan length is snapped to the 4k+1
    envelope inside wan_workflow and the seed is logged there."""
    W = spec.get("wan_w", 512); H = spec.get("wan_h", 512)
    length, _ = snap_wan_length(spec.get("wan_len", 41))
    use_seed = seed if seed is not None else spec.get("seed", 700)
    pre = PRESETS.get(preset, {})
    base_pos = f"{spec['subject']}, full body, side view, " + STYLE.format(bg=BGWORDS["green"])
    imgs = run_workflow(sdxl_workflow(base_pos, NEG, use_seed, w=768, h=768))
    if not imgs:
        print(f"  [wan] {spec['id']}: base gen failed", flush=True); return None
    base = I.cutout(_fetch_image(imgs[0]))
    outdir = os.path.join(VERIFIED, "gen_creatures", spec["id"])
    os.makedirs(outdir, exist_ok=True)
    base.save(os.path.join(outdir, "_base.png"))

    states = spec.get("states", {"walk": "walking, legs striding, gentle body bob"})
    n_extract = pre.get("frames") or spec.get("frames", 8)
    if not n_extract:          # vfx preset (0) -> keep the default budget of usable frames
        n_extract = spec.get("frames", 8)
    min_frac = spec.get("gauntlet_min_frac", 0.7)
    lib_states, fps_map, all_first, routes_log = {}, {}, [], {}
    for st, motion in states.items():
        hint = (motion + ", " + pre["hint"]) if pre.get("hint") else motion
        pos = (f"pixel art, retro RPG creature sprite, {spec['subject']}, {hint}, "
               "single centered character only, plain solid flat chroma green background, "
               "no ground no floor no shadow, consistent character, smooth looping animation, dark fantasy gothic")

        def _attempt(clip_seed, settings, _st=st, _pos=pos):
            """One clip generation + gauntlet gate. Returns (ok, frames, detail) for the retry harness."""
            start = _prep_start(base, W, H)
            print(f"  [wan] {spec['id']}/{_st}: {W}x{H}x{length} seed={clip_seed} preset={preset} "
                  f"steps={settings['steps']} denoise={settings['denoise']} generating...", flush=True)
            fr = run_workflow(wan_workflow(start, _pos, clip_seed, W, H, length, **settings), timeout=1200)
            if not fr:
                return False, None, "no frames from Wan"
            frame_imgs = [_fetch_image(x) for x in fr]
            frames = pixelsnap_frames(frame_imgs, count=n_extract, target_px=spec.get("target_px", 56))
            n = len(frames)
            clean_ok = sum(1 for f in frames if I.cleanliness_report(f)[0])
            gpass = sum(1 for f in frames if _GAUNTLET.run_gauntlet(f)[0])
            frac = gpass / n if n else 0.0
            ok = (clean_ok == n) and (frac >= min_frac)
            return ok, frames, f"{clean_ok}/{n} clean, {gpass}/{n} gauntlet ({frac:.2f} vs min {min_frac})"

        frames, history = run_with_retry(f"{spec['id']}/{st}", _attempt, use_seed,
                                         max_attempts=spec.get("max_attempts", 3))
        routes_log[st] = history
        if not frames:
            print(f"  [wan] {spec['id']}/{st}: DROPPED after retries (batch continues)", flush=True)
            continue
        clean_ok = sum(1 for f in frames if I.cleanliness_report(f)[0])
        strip, gif = I.animated_strip_montage(frames, scale=4)
        strip.convert("RGB").save(os.path.join(outdir, f"{st}_strip.png"))
        if gif:
            gif[0].save(os.path.join(outdir, f"{st}.gif"), save_all=True, append_images=gif[1:], duration=120, loop=0, disposal=2)
        # save frames as one horizontal sheet
        cw = max(f.width for f in frames); ch = max(f.height for f in frames)
        sheet = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, ch - f.height))
        sheet.save(os.path.join(outdir, f"{st}_sheet.png"))
        lib_states[st] = {"frames": len(frames), "frame_size": [cw, ch], "clean_frames": clean_ok,
                          "sheet": os.path.relpath(os.path.join(outdir, f"{st}_sheet.png"), I.ASSETLIB),
                          "route_history": routes_log.get(st, [])}
        fps_map[st] = len(frames)
        all_first.append(frames[0])
        print(f"  [wan] {spec['id']}/{st}: {len(frames)} frames, {clean_ok} clean -> {st}_sheet.png", flush=True)

    if not lib_states:
        return None
    I.library_add({
        "id": spec["id"], "category": "creature", "path": os.path.relpath(outdir, I.ASSETLIB),
        "size": spec.get("target_px", 56), "animated": True, "states": list(lib_states.keys()),
        "frames_per_state": fps_map, "state_detail": lib_states, "facing": "right (mirror for left)",
        "biome_fit": spec.get("biome_fit", []), "source": "comfyui:sdxl-base+wan2.2-ti2v+pixelsnap",
        "license": "generated-original (CC0, owner-owned)", "subject": spec["subject"], "verdict": "PASS",
    })
    return outdir


# ---------------------------------------------------------------------------------------
# SPEC CATALOG
# ---------------------------------------------------------------------------------------
from asset_specs import SPECS, CREATURE_SPECS, batch_for


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch", default="sample", help="sample | props | harbor | buildings | all | animated")
    ap.add_argument("--limit", type=int, default=0, help="cap number of specs (0=all)")
    ap.add_argument("--preset", default=None, choices=list(PRESETS.keys()),
                    help="frame-budget preset for the animated lane (idle|walk4|walk8|attack|vfx)")
    ap.add_argument("--seed", type=int, default=None, help="override the Wan/base seed (reproducible)")
    args = ap.parse_args()

    if args.batch == "animated":
        done = []
        for cs in (CREATURE_SPECS[: args.limit] if args.limit else CREATURE_SPECS):
            d = gen_creature(cs, preset=args.preset, seed=args.seed)
            if d:
                done.append(cs["id"])
        print(f"[gen] animated done: {done}", flush=True)
        return

    specs = batch_for(args.batch)
    if args.limit:
        specs = specs[: args.limit]
    run_inanimate(specs, args.batch)


if __name__ == "__main__":
    main()
