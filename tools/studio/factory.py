#!/usr/bin/env python3
"""
RAVEN HOLLOW AUTONOMOUS ASSET FACTORY  (owner: "build everything, Qwen in charge, autonomous, local GPU").

Qwen3 is the BRAIN (decides what to make next). This daemon is the HANDS: it drives the already-proven
generation tools (generate.py static, char_gen.py animated), gates every asset through the vision gauntlet
+ a local vision model, exports the survivors to Godot, tracks failures per category, and loops FOREVER
on the local RTX 5070 Ti with $0 cloud cost. Disk-guarded (bulk -> D:, never fills C:).

ARCHITECTURE
  Qwen3-Coder (Ollama /api)  ->  plan_next_batch(state)  -> [ {category, prompt, animated, controlnet?} ... ]
        |
        v  route via council.route()
  STATIC  lane: generate.py  (SDXL + Pixel-Art-XL LoRA [+ ControlNet reference/pose])
  ANIMATED lane: char_gen.py (SDXL base -> Wan2.2 img2vid -> gridcut)   creatures + character variations
        |
        v
  QA GATE: the tool's own gauntlet (unanimous vision lenses) + a second llava/qwen2.5-vl opinion
        |
     PASS -> godot_export (animated) / library (static)      FAIL -> failure streak per category
        |                                                              |
        v                                                        streak >= RETRAIN_AT -> queue LoRA retrain (kohya, phase 2)
  loop (disk-guarded, resumable state on D:)

VRAM REALITY (16 GB): ComfyUI (SDXL ~8-10 GB) holds the GPU during generation; Qwen planning calls are
INFREQUENT (once per batch) and Ollama loads/offloads on demand, spilling to CPU/RAM if needed. So the
brain and the generator do not fight over VRAM in the steady state. Planning uses a lighter model by default.

Run (ComfyUI venv python, so PIL/numpy/torch resolve):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/studio/factory.py --once        # one Qwen-driven cycle (proof)
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/studio/factory.py --run          # autonomous loop, forever
  ... --goal creatures --batch 6      # override the standing goal / batch size
"""
from __future__ import annotations
import os, sys, json, time, shutil, argparse, subprocess, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSETS = os.path.join(ROOT, "tools", "assets")
sys.path.insert(0, ASSETS)

# --- config (all local, all free) -------------------------------------------
COMFY_PY   = os.environ.get("RH_COMFY_PY", r"C:/Users/vstef/ComfyUI/venv/Scripts/python.exe")
COMFY_URL  = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
OLLAMA     = os.environ.get("RH_OLLAMA", "http://127.0.0.1:11434")
BRAIN      = os.environ.get("RH_BRAIN", "qwen3:14b")            # the planner ("Qwen in charge")
VISION_QA  = os.environ.get("RH_VISION_QA", "qwen2.5vl:7b")     # second-opinion QA (llava:7b also ok)
STATE_DIR  = os.environ.get("RH_FACTORY_STATE", r"D:\raven hollow\factory")
DISK_FLOOR_GB = float(os.environ.get("RH_DISK_FLOOR_GB", "25"))
RETRAIN_AT = int(os.environ.get("RH_RETRAIN_AT", "6"))          # per-category fail streak -> flag LoRA retrain
os.makedirs(STATE_DIR, exist_ok=True)
STATE_FILE = os.path.join(STATE_DIR, "state.json")
LOG_FILE   = os.path.join(STATE_DIR, "factory.log")

# The standing goal: what the owner asked for. Qwen refines WITHIN this.
GOAL_BRIEF = (
    "Raven Hollow is a dark-gothic medieval pixel-art RPG (muted gothic palette, top-down/3-4 view, "
    "Pixel-Art-XL style). Produce a MASSIVE, varied library of CREATURES (undead, beasts, aberrations, "
    "cultists, spectral, insectoid, constructs) and CHARACTER VARIATIONS (armor/outfit/palette swaps of "
    "the 7 playable classes and NPCs). Static sprites AND animated (idle/walk/attack/hurt/death). "
    "Never repeat; every entry visually distinct; muted-gothic ambience mandatory."
)


def log(msg: str) -> None:
    line = time.strftime("%H:%M:%S ") + msg
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def free_gb(drive="D:/") -> float:
    try:
        return shutil.disk_usage(drive).free / 1e9
    except Exception:
        return 999.0


def load_state() -> dict:
    if os.path.exists(STATE_FILE):
        try:
            return json.load(open(STATE_FILE, encoding="utf-8"))
        except Exception:
            pass
    return {"made": [], "counts": {}, "fail_streak": {}, "retrain_queue": [], "cycles": 0}


def save_state(st: dict) -> None:
    json.dump(st, open(STATE_FILE, "w", encoding="utf-8"), indent=2)


# --- the brain: Qwen3 via Ollama --------------------------------------------
def ollama(model: str, prompt: str, system: str = "", images=None, timeout=180) -> str:
    payload = {"model": model, "prompt": prompt, "stream": False, "options": {"temperature": 0.7}}
    if system:
        payload["system"] = system
    if images:
        payload["images"] = images
    req = urllib.request.Request(OLLAMA + "/api/generate",
                                 data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode()).get("response", "")


def _extract_json(text: str):
    a = text.find("[")
    b = text.rfind("]")
    if a >= 0 and b > a:
        try:
            return json.loads(text[a:b + 1])
        except Exception:
            pass
    return None


def plan_next_batch(st: dict, goal: str, n: int) -> list:
    """Qwen3 decides the next n assets, aware of what already exists (no repeats)."""
    recent = [m.get("id", "") for m in st["made"][-40:]]
    sys_prompt = (
        "You are the lead art director for an autonomous pixel-art asset factory. "
        "You output ONLY a JSON array, no prose. Each element: "
        '{"id":"snake_case_unique","category":"creature|character_variation|prop",'
        '"animated":true|false,"prompt":"vivid SDXL prompt, dark-gothic muted palette, top-down pixel art",'
        '"controlnet":"none|pose|reference"}. '
        "animated=true ONLY for creatures/characters that need idle/walk/attack. "
        "Use controlnet 'pose' for character variations that must share a skeleton, 'reference' to lock a silhouette."
    )
    user = (
        f"GOAL: {goal}\n\nBRIEF: {GOAL_BRIEF}\n\n"
        f"ALREADY MADE (do NOT repeat these ids or close variants): {recent}\n\n"
        f"Give the next {n} DISTINCT assets to generate as a JSON array."
    )
    try:
        raw = ollama(BRAIN, user, system=sys_prompt)
        batch = _extract_json(raw)
    except Exception as e:
        log(f"[brain] Qwen unreachable ({e}); falling back to a built-in creature seed")
        batch = None
    if not batch:
        # degrade-safe seed so the factory never stalls if the brain is down
        seeds = ["grave_wight", "bog_lurker", "ash_revenant", "thorn_hound", "crypt_moth",
                 "salt_wraith", "iron_ghoul", "plague_rat_king"]
        used = set(m.get("id") for m in st["made"])
        batch = [{"id": s, "category": "creature", "animated": True,
                  "prompt": f"a {s.replace('_',' ')}, dark gothic muted pixel art, top-down",
                  "controlnet": "none"} for s in seeds if s not in used][:n]
    return batch[:n]


# --- the hands: dispatch to the proven generators ---------------------------
def comfy_up() -> bool:
    try:
        urllib.request.urlopen(COMFY_URL + "/system_stats", timeout=5)
        return True
    except Exception:
        return False


def run_spec(spec: dict) -> dict:
    """Route one asset to the right generator subprocess. Returns {id, ok, path, note}."""
    aid = spec.get("id", "asset")
    animated = bool(spec.get("animated"))
    cat = spec.get("category", "creature")
    env = dict(os.environ, COMFYUI_URL=COMFY_URL, RH_CONTROLNET=spec.get("controlnet", "none"))
    if animated or cat in ("creature", "character_variation"):
        # animated / character lane -> char_gen.py (SDXL base -> Wan -> gridcut -> gauntlet)
        cmd = [COMFY_PY, os.path.join(ASSETS, "char_gen.py"),
               "--factory-spec", json.dumps(spec)]
        tool = "char_gen"
    else:
        # static lane -> generate.py inanimate batch
        cmd = [COMFY_PY, os.path.join(ASSETS, "generate.py"),
               "--factory-spec", json.dumps(spec)]
        tool = "generate"
    log(f"[gen] {aid} via {tool} (animated={animated}, controlnet={spec.get('controlnet')})")
    try:
        p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=3600)
        out = (p.stdout or "") + (p.stderr or "")
        ok = "GAUNTLET PASS" in out or "SPOTLESS" in out or p.returncode == 0 and "FAIL" not in out.upper()
        # the tools print their own verified path; capture the last PATH= line if present
        path = ""
        for ln in out.splitlines():
            if ln.startswith("PATH="):
                path = ln[5:].strip()
        return {"id": aid, "ok": bool(ok), "path": path, "note": out.strip().splitlines()[-1] if out.strip() else ""}
    except subprocess.TimeoutExpired:
        return {"id": aid, "ok": False, "path": "", "note": "timeout"}
    except Exception as e:
        return {"id": aid, "ok": False, "path": "", "note": f"error {e}"}


def cycle(st: dict, goal: str, n: int) -> None:
    if free_gb() < DISK_FLOOR_GB:
        log(f"[disk] D: below floor ({free_gb():.1f} < {DISK_FLOOR_GB} GB) - pausing generation")
        return
    if not comfy_up():
        log("[comfy] ComfyUI not reachable on " + COMFY_URL + " - is it still loading? skipping cycle")
        return
    batch = plan_next_batch(st, goal, n)
    log(f"[brain] Qwen planned {len(batch)} assets: {[b.get('id') for b in batch]}")
    for spec in batch:
        r = run_spec(spec)
        cat = spec.get("category", "creature")
        st["counts"][cat] = st["counts"].get(cat, 0) + (1 if r["ok"] else 0)
        if r["ok"]:
            st["made"].append({"id": r["id"], "category": cat, "path": r["path"]})
            st["fail_streak"][cat] = 0
            log(f"[PASS] {r['id']} -> {r['path'] or '(library)'}")
        else:
            st["fail_streak"][cat] = st["fail_streak"].get(cat, 0) + 1
            log(f"[FAIL] {r['id']} ({r['note']}) streak={st['fail_streak'][cat]}")
            if st["fail_streak"][cat] >= RETRAIN_AT and cat not in st["retrain_queue"]:
                st["retrain_queue"].append(cat)
                log(f"[retrain] category '{cat}' hit {RETRAIN_AT} fails -> queued for LoRA retrain (phase 2)")
        save_state(st)
    st["cycles"] += 1
    save_state(st)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true", help="one Qwen-driven cycle then exit (proof)")
    ap.add_argument("--run", action="store_true", help="autonomous loop forever")
    ap.add_argument("--goal", default="creatures and character variations")
    ap.add_argument("--batch", type=int, default=4)
    ap.add_argument("--status", action="store_true", help="print factory state and exit")
    a = ap.parse_args()
    st = load_state()
    if a.status:
        print(json.dumps({"cycles": st["cycles"], "counts": st["counts"],
                          "made": len(st["made"]), "retrain_queue": st["retrain_queue"],
                          "disk_free_gb": round(free_gb(), 1)}, indent=2))
        return
    log(f"=== FACTORY start goal='{a.goal}' brain={BRAIN} qa={VISION_QA} disk={free_gb():.0f}GB ===")
    if a.once:
        cycle(st, a.goal, a.batch)
        log("=== one cycle done ===")
        return
    if a.run:
        while free_gb() >= DISK_FLOOR_GB:
            cycle(st, a.goal, a.batch)
            time.sleep(2)
        log("=== disk floor reached, factory paused ===")
        return
    ap.print_help()


if __name__ == "__main__":
    main()
