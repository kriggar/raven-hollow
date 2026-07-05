# Fable-approved video-gen fleet downloader. Sequential, resumable, disk-guarded.
# Run detached: supervisor .bat pattern. Log: D:/ComfyUI-models/_fleet_download.log
import os, shutil, subprocess, sys, time, urllib.request, json

DEST = "D:/ComfyUI-models"
LOG = os.path.join(DEST, "_fleet_download.log")
FLOOR_GB = 30

ITEMS = [
    # (url, subdir, filename, expected_gb)
    ("https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q4_K_M.gguf",
     "diffusion_models", "Wan2.2-I2V-A14B-HighNoise-Q4_K_M.gguf", 9.65),
    ("https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/LowNoise/Wan2.2-I2V-A14B-LowNoise-Q4_K_M.gguf",
     "diffusion_models", "Wan2.2-I2V-A14B-LowNoise-Q4_K_M.gguf", 9.65),
    ("https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors",
     "vae", "wan_2.1_vae.safetensors", 0.25),
    ("https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-2b-0.9.8-distilled.safetensors",
     "checkpoints", "ltxv-2b-0.9.8-distilled.safetensors", 6.34),
    ("https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors",
     "text_encoders", "t5xxl_fp8_e4m3fn.safetensors", 4.89),
    ("https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt",
     "animatediff_models", "v3_sd15_mm.ckpt", 1.67),
    ("https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_adapter.ckpt",
     "loras", "v3_sd15_adapter.ckpt", 0.10),
    ("https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_sparsectrl_rgb.ckpt",
     "controlnet", "v3_sd15_sparsectrl_rgb.ckpt", 1.99),
]

def log(msg):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")

def free_gb():
    return shutil.disk_usage("D:/").free / 1e9

def fetch(url, path, expected_gb):
    if os.path.exists(path) and abs(os.path.getsize(path)/1e9 - expected_gb) < expected_gb*0.08:
        log(f"SKIP (exists, size ok): {os.path.basename(path)}")
        return True
    if free_gb() - expected_gb < FLOOR_GB:
        log(f"ABORT (disk floor): {os.path.basename(path)} needs {expected_gb}GB, free {free_gb():.1f}GB")
        return False
    for attempt in range(5):
        r = subprocess.run(["curl", "-L", "--retry", "3", "-C", "-", "-o", path, url],
                           capture_output=True, text=True, timeout=7200)
        if r.returncode == 0 and os.path.exists(path):
            got = os.path.getsize(path)/1e9
            if abs(got - expected_gb) < expected_gb*0.08 or expected_gb < 0.2:
                log(f"OK {os.path.basename(path)} {got:.2f}GB")
                return True
            log(f"SIZE MISMATCH {os.path.basename(path)} got {got:.2f} want {expected_gb} (attempt {attempt})")
        else:
            log(f"CURL rc={r.returncode} attempt {attempt} {os.path.basename(path)}")
        time.sleep(10)
    return False

def civitai(model_id, subdir, expected_gb, name_hint):
    # resolve primary file downloadUrl via public API
    try:
        with urllib.request.urlopen(f"https://civitai.com/api/v1/models/{model_id}", timeout=60) as r:
            d = json.load(r)
        mv = d["modelVersions"][0]
        f0 = sorted(mv["files"], key=lambda f: -f.get("sizeKB", 0))[0]
        url = f0["downloadUrl"]
        fname = f0["name"]
        log(f"civitai {model_id} -> {fname} ({f0.get('sizeKB',0)/1e6:.2f}GB) url={url}")
        return fetch(url, os.path.join(DEST, subdir, fname), expected_gb)
    except Exception as e:
        log(f"CIVITAI FAIL {model_id}: {e}")
        return False

def hf_repo_loras():
    # styly-agents/Wan2-2-pixel-animate: list files via HF API, take safetensors + json
    try:
        with urllib.request.urlopen("https://huggingface.co/api/models/styly-agents/Wan2-2-pixel-animate", timeout=60) as r:
            d = json.load(r)
        ok = True
        for s in d.get("siblings", []):
            fn = s["rfilename"]
            if fn.endswith(".safetensors"):
                ok &= fetch(f"https://huggingface.co/styly-agents/Wan2-2-pixel-animate/resolve/main/{fn}",
                            os.path.join(DEST, "loras", os.path.basename(fn)), 2.3)
            elif fn.endswith(".json"):
                fetch(f"https://huggingface.co/styly-agents/Wan2-2-pixel-animate/resolve/main/{fn}",
                      os.path.join(DEST, "workflows", os.path.basename(fn)), 0.001)
        return ok
    except Exception as e:
        log(f"HF LORA FAIL: {e}")
        return False

def main():
    os.makedirs(DEST, exist_ok=True)
    log(f"=== FLEET DOWNLOAD START free={free_gb():.1f}GB ===")
    results = []
    for url, subdir, fname, gb in ITEMS:
        os.makedirs(os.path.join(DEST, subdir), exist_ok=True)
        results.append((fname, fetch(url, os.path.join(DEST, subdir, fname), gb)))
    results.append(("Wan2-2-pixel-animate", hf_repo_loras()))
    results.append(("PixelArtSpriteDiffusion", civitai(129057, "checkpoints", 3.97, "pixel sprite")))
    results.append(("PixelAttackSpriteLoRA", civitai(2085866, "loras", 0.146, "attack lora")))
    fails = [n for n, ok in results if not ok]
    log(f"=== DONE free={free_gb():.1f}GB fails={fails or 'none'} ===")
    print("FLEET_DONE", "FAILS:", fails or "none")

if __name__ == "__main__":
    main()
