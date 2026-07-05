#!/usr/bin/env python3
"""
THE MODEL MATRIX  (owner law #115.3) — run the SAME subject through EVERY feasible free model on the
16 GB card, produce ONE labelled montage = the Generation Council's scorecard. Truth: real outputs,
real skips documented. Weights already under ComfyUI/models (Wan/Flux big weights would go to
D:/raven hollow/models if newly fetched — none are fetched here; we test what's installed).

  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/model_matrix.py
Output: _screens/model_matrix.png  + _screens/model_matrix_scores.json
"""
from __future__ import annotations
import os, sys, io, json, time, traceback
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I
import generate as G
import gauntlet as GA

STILL_SUBJECT = ("a gothic medieval market stall with striped awning and wooden counter, "
                 "top-down three-quarter view")
SCREENS = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "_screens"))
os.makedirs(SCREENS, exist_ok=True)


def sdxl(subject, lora, seed=4242):
    pos = f"{subject}, " + G.STYLE.format(bg=G.BGWORDS["green"])
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["4", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": G.NEG, "clip": ["4", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 28, "cfg": 7.0, "sampler_name": "euler",
              "scheduler": "normal", "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0],
              "negative": ["7", 0], "latent_image": ["5", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "mm_sdxl", "images": ["8", 0]}},
    }
    if lora:
        wf["10"] = {"class_type": "LoraLoader", "inputs": {"lora_name": lora, "strength_model": 1.0,
                    "strength_clip": 1.0, "model": ["4", 0], "clip": ["4", 1]}}
        wf["6"]["inputs"]["clip"] = ["10", 1]
        wf["7"]["inputs"]["clip"] = ["10", 1]
        wf["3"]["inputs"]["model"] = ["10", 0]
    return wf


def flux(subject, lora, seed=4242):
    pos = f"pixel art, {subject}, muted gothic dark fantasy, desaturated, clean flat pixels, on plain green background"
    wf = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "flux1-dev-fp8.safetensors"}},
        "10": {"class_type": "LoraLoader", "inputs": {"lora_name": lora, "strength_model": 1.0,
               "strength_clip": 1.0, "model": ["4", 0], "clip": ["4", 1]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": pos, "clip": ["10", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["10", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 20, "cfg": 1.0, "sampler_name": "euler",
              "scheduler": "simple", "denoise": 1.0, "model": ["10", 0], "positive": ["6", 0],
              "negative": ["7", 0], "latent_image": ["5", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "mm_flux", "images": ["8", 0]}},
    }
    return wf


STILL_MODELS = [
    ("SDXL+PixelArtXL", lambda: sdxl(STILL_SUBJECT, "pixel-art-xl.safetensors")),
    ("SDXL base (no LoRA)", lambda: sdxl(STILL_SUBJECT, None)),
    ("FLUX-dev + 2DHD-pixel LoRA", lambda: flux(STILL_SUBJECT, "flux_2DHD_pixel_art.safetensors")),
    ("FLUX-dev + topdown-pixel LoRA", lambda: flux(STILL_SUBJECT, "flux_topdown_pixel.safetensors")),
]

SKIPS = {
    "SD1.5": "not installed (no v1-5 checkpoint in ComfyUI/models)",
    "AnimateDiff": "custom nodes not installed",
    "LTX-Video": "not installed (would need ~ multi-GB fetch)",
    "CogVideoX-2B": "not installed (would need fetch + nodes)",
    "Flux-schnell": "not installed (only flux1-dev-fp8 present)",
    "Hunyuan3D-v2": "image->3D model, not a text->2D-sprite generator (out of scope for the 2D matrix)",
}


def tile(label, raw, sprite, cell_w=300):
    """Compose a labelled tile: model name, raw render (small), cleaned sprite (nearest zoom)."""
    ch = 360
    t = Image.new("RGBA", (cell_w, ch), (30, 27, 33, 255))
    d = ImageDraw.Draw(t)
    d.text((6, 4), label, fill=(240, 220, 150, 255))
    if raw is not None:
        r = raw.convert("RGBA"); r.thumbnail((cell_w - 12, 200))
        t.alpha_composite(r, ((cell_w - r.width) // 2, 22))
    if sprite is not None:
        s = sprite
        z = max(1, min((cell_w - 12) // max(1, s.width), 120 // max(1, s.height)))
        up = s.resize((s.width * z, s.height * z), Image.NEAREST)
        # checker behind sprite
        chk = I._checker(cell_w, 120).convert("RGBA")
        chk.alpha_composite(up, ((cell_w - up.width) // 2, (120 - up.height) // 2))
        t.alpha_composite(chk, (0, ch - 122))
        d.text((6, ch - 138), "cleaned sprite:", fill=(170, 200, 170, 255))
    return t


def main():
    tiles = []
    scores = {}
    # STILL models
    for label, wf_fn in STILL_MODELS:
        print(f"[matrix] {label} ...", flush=True)
        try:
            t0 = time.time()
            imgs = G.run_workflow(wf_fn(), timeout=400)
            if not imgs:
                tiles.append(tile(label + " (FAILED)", None, None)); scores[label] = {"status": "failed"}; continue
            raw = G._fetch_image(imgs[0])
            objs = I.process_render(raw, target_px=96, split=True)
            sprite = objs[0] if objs else None
            gok, gv = (GA.run_gauntlet(sprite) if sprite else (False, []))
            dt = time.time() - t0
            tiles.append(tile(f"{label}  {dt:.0f}s", raw, sprite))
            scores[label] = {"status": "ok", "seconds": round(dt, 1), "gauntlet_pass": gok,
                             "gauntlet": GA.verdict_reasons(gv, only_fail=False)}
            print(f"[matrix] {label} done {dt:.0f}s gauntlet={gok}", flush=True)
        except Exception as e:
            traceback.print_exc()
            tiles.append(tile(label + " (ERROR)", None, None)); scores[label] = {"status": f"error: {e}"}

    # VIDEO model: Wan torch flame (animated subject)
    print("[matrix] Wan2.2 TI2V (video: torch flame) ...", flush=True)
    try:
        base = I.cutout(G._fetch_image(G.run_workflow(G.sdxl_workflow(
            "a lit wooden wall torch with flame, " + G.STYLE.format(bg=G.BGWORDS["green"]), G.NEG, 55, w=768, h=768))[0]))
        start = G._prep_start(base, 512, 512)
        fr = G.run_workflow(G.wan_workflow(start,
              "pixel art torch flame flickering, single centered torch, plain green background, dark fantasy",
              55, 512, 512, 25), timeout=900)
        if fr:
            frames = G.pixelsnap_frames([G._fetch_image(x) for x in fr], count=5, target_px=64)
            strip, _ = I.animated_strip_montage(frames, scale=3)
            vt = Image.new("RGBA", (max(300, strip.width + 12), 360), (30, 27, 33, 255))
            ImageDraw.Draw(vt).text((6, 4), "Wan2.2 TI2V-5B (VIDEO: torch x5)", fill=(240, 220, 150, 255))
            s2 = strip.convert("RGBA"); s2.thumbnail((vt.width - 12, 300))
            vt.alpha_composite(s2, (6, 30))
            tiles.append(vt)
            scores["Wan2.2 TI2V-5B (video)"] = {"status": "ok", "frames": len(frames)}
            print("[matrix] Wan done", flush=True)
    except Exception as e:
        traceback.print_exc()
        scores["Wan2.2 TI2V-5B (video)"] = {"status": f"error: {e}"}

    # compose montage
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    cw = max(t.width for t in tiles); ch = max(t.height for t in tiles)
    pad = 10
    canvas = Image.new("RGBA", (cols * cw + pad * (cols + 1), rows * ch + pad * (rows + 1) + 60), (18, 16, 20, 255))
    d = ImageDraw.Draw(canvas)
    d.text((14, 16), "RAVEN HOLLOW — MODEL MATRIX (same subject: gothic market stall) — Generation Council scorecard",
           fill=(240, 225, 160, 255))
    d.text((14, 36), "SKIPPED: " + " | ".join(f"{k} ({v})" for k, v in SKIPS.items())[:180], fill=(170, 160, 150, 255))
    for i, t in enumerate(tiles):
        cx = pad + (i % cols) * (cw + pad)
        cy = 60 + pad + (i // cols) * (ch + pad)
        canvas.alpha_composite(t, (cx, cy))
    outp = os.path.join(SCREENS, "model_matrix.png")
    canvas.convert("RGB").save(outp)
    json.dump({"scores": scores, "skipped": SKIPS}, open(os.path.join(SCREENS, "model_matrix_scores.json"), "w"), indent=2)
    print(f"[matrix] -> {outp}")
    print(json.dumps(scores, indent=2))


if __name__ == "__main__":
    main()
