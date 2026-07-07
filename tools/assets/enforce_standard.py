#!/usr/bin/env python3
"""
STANDARD ENFORCER (owner mandate 2026-07-07: "auto-delete everything not up to standard").

Sweeps generated-asset directories, runs EVERY sprite through the vision gauntlet (the same
unanimous quality gate the factory uses), and DELETES anything that fails. This makes "up to
standard" mechanical + self-cleaning: sub-bar art cannot accumulate.

SAFETY (hard rules, non-negotiable):
  * Only ever touches PNG image files UNDER the whitelisted asset roots below. Never .gd/.json/
    .py/.tscn, never anything outside those roots, never the repo source.
  * DRY-RUN by default (prints what WOULD die). Pass --commit to actually delete.
  * Every deletion is logged (path + the killing inspector's reason) to _screens/enforce_log.txt.
  * Skips montages/strips/sheets/reference frames (multi-sprite composites aren't single-sprite gated).

Run (ComfyUI venv python for PIL/numpy):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/enforce_standard.py            # dry-run
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/enforce_standard.py --commit    # delete for real
"""
from __future__ import annotations
import os, sys, glob, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from PIL import Image
import gauntlet as GAUNT

# ONLY these roots are ever swept/deleted from. Add generated-asset dirs here, nothing else.
ASSET_ROOTS = [
    os.path.join(ROOT, "_downloads", "_assetlib", "verified"),
    r"D:\raven hollow\assetlib\verified",
    r"D:\raven hollow\gen_output",
]
LOG = os.path.join(ROOT, "_screens", "enforce_log.txt")
SKIP = ("montage", "strip", "sheet", "filmstrip", "_raw", "contact")


def log(msg: str) -> None:
    print(msg, flush=True)
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(msg + "\n")


def is_safe_target(path: str) -> bool:
    ap = os.path.abspath(path)
    if not ap.lower().endswith(".png"):
        return False
    if any(s in os.path.basename(ap).lower() for s in SKIP):
        return False
    return any(ap.startswith(os.path.abspath(r)) for r in ASSET_ROOTS if os.path.isdir(r))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--commit", action="store_true", help="actually delete (default: dry-run)")
    ap.add_argument("--no-vlm", action="store_true", help="skip the slow VLM lens (faster sweep)")
    a = ap.parse_args()
    mode = "COMMIT (deleting)" if a.commit else "DRY-RUN (no deletion)"
    log(f"=== STANDARD ENFORCER {mode} ===")
    kept = killed = skipped = 0
    for r in ASSET_ROOTS:
        if not os.path.isdir(r):
            continue
        for p in glob.glob(os.path.join(r, "**", "*.png"), recursive=True):
            if not is_safe_target(p):
                skipped += 1
                continue
            try:
                im = Image.open(p).convert("RGBA")
            except Exception as e:
                log(f"KILL (unreadable {e}): {p}")
                if a.commit:
                    try: os.remove(p)
                    except Exception: pass
                killed += 1
                continue
            ok, verdict = GAUNT.run_gauntlet(im, use_vlm=not a.no_vlm)
            if ok:
                kept += 1
            else:
                reason = verdict if isinstance(verdict, str) else GAUNT.verdict_reasons(verdict) if hasattr(GAUNT, "verdict_reasons") else str(verdict)
                log(f"KILL ({reason}): {p}")
                if a.commit:
                    try: os.remove(p)
                    except Exception as e: log(f"  (delete failed: {e})")
                killed += 1
    log(f"=== done: kept={kept} killed={killed} skipped(non-target)={skipped} | {mode} ===")
    if not a.commit and killed:
        log("Re-run with --commit to actually delete the failing sprites.")


if __name__ == "__main__":
    main()
