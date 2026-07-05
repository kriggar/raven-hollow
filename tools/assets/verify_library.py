#!/usr/bin/env python3
"""
LIBRARY VERIFIER (owner PRIORITY 2, 2026-07-06) — audit the whole asset library after the razor-clean
re-pass: (1) library.json <-> files consistency (no dangling refs, no orphan PNGs), (2) every static
sprite passes the razor-clean cleanliness rubric, (3) every static sprite passes the unanimous Gauntlet.
Truth over hype: prints exact counts + every failure. This is the "Gauntlet live-gated on every asset"
evidence pass.

  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/verify_library.py [--gauntlet]
"""
from __future__ import annotations
import os, sys, json, glob, argparse
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I
import gauntlet as GA

LIB = I.LIBRARY_JSON
ASSETLIB = I.ASSETLIB


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gauntlet", action="store_true", help="also run the vision gauntlet on every static sprite")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()

    lib = json.load(open(LIB, encoding="utf-8"))
    assets = lib.get("assets", [])
    print(f"library.json: {len(assets)} assets")

    # 1) consistency: referenced paths exist
    missing, static_paths = [], set()
    for asset in assets:
        p = os.path.join(ASSETLIB, asset["path"])
        if asset.get("animated"):
            if not os.path.exists(p):
                missing.append(asset["id"])
            continue
        if not os.path.exists(p):
            missing.append(asset["id"])
        else:
            static_paths.add(os.path.abspath(p))
    print(f"  missing referenced files: {len(missing)}" + (f"  {missing[:8]}" if missing else ""))

    # 2) orphans: PNGs in verified/gen_* not referenced (ignore montages/_prefixed)
    orphans = []
    for f in glob.glob(os.path.join(ASSETLIB, "verified", "**", "*.png"), recursive=True):
        b = os.path.basename(f)
        if b.startswith("_") or "montage" in b or b.endswith(".import"):
            continue
        if os.path.abspath(f) not in static_paths:
            orphans.append(os.path.relpath(f, ASSETLIB))
    print(f"  orphan PNGs (on disk, not in library): {len(orphans)}" + (f"  e.g. {orphans[:5]}" if orphans else ""))

    # 3) razor-clean cleanliness on every static sprite (+ optional gauntlet)
    static = [x for x in assets if not x.get("animated")]
    if a.limit:
        static = static[: a.limit]
    clean_pass = clean_fail = g_pass = g_fail = 0
    fails = []
    for x in static:
        p = os.path.join(ASSETLIB, x["path"])
        if not os.path.exists(p):
            continue
        im = Image.open(p)
        lacy = x.get("category") in ("nature",) or any(k in x["id"] for k in ("net", "reed", "fence", "cattail"))
        cok, cs = I.cleanliness_report(im, require_single_subject=not lacy)
        clean_pass += cok; clean_fail += (not cok)
        cfail = [k for k, v in cs["checks"].items() if not v]
        gok = None
        if a.gauntlet:
            gok, gv = GA.run_gauntlet(im)
            g_pass += gok; g_fail += (not gok)
        if not cok or (a.gauntlet and not gok):
            fails.append((x["id"], cfail, GA.verdict_reasons(gv, only_fail=True) if a.gauntlet else ""))
    print(f"\ncleanliness (razor-clean): {clean_pass} PASS / {clean_fail} FAIL of {len(static)} static")
    if a.gauntlet:
        print(f"gauntlet (unanimous):      {g_pass} PASS / {g_fail} FAIL of {len(static)} static")
    for fid, cfail, gr in fails[:40]:
        print(f"  FAIL {fid}: clean={cfail} gauntlet={gr}")
    print(f"\nSUMMARY: {len(assets)} assets | missing={len(missing)} orphans={len(orphans)} "
          f"clean_fail={clean_fail}" + (f" gauntlet_fail={g_fail}" if a.gauntlet else ""))


if __name__ == "__main__":
    main()
