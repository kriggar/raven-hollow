"""THE FULL-LIBRARY DEFECT CHECK (Pipeline Order Law stage 2, owner 2026-07-11).

Sweeps every PNG in the asset library for mechanical defects, then renders
per-category montage sheets for the human/Fable eyeball pass. Run AFTER the
generation marathon completes, BEFORE any painting resumes.

Checks per asset:
  tiny        — bounding box under MIN_DIM px (fragment cuts, e.g. bad signage)
  empty       — fewer than MIN_OPAQUE opaque pixels
  halo        — too many semi-transparent pixels (alpha 8..247) = fringe/glow
                left by a bad cutout (binary-alpha law, #112)
  duplicate   — 8x8 average-hash collision with an earlier asset (cross-file)
  oversize    — larger than MAX_DIM (uncut sheet leaked through)

Output:
  _screens/library_audit/report.json + report.md   (verdicts, counts)
  _screens/library_audit/<category>_pageNN.png     (montages, 10x10 grid)

Usage:
  python tools/assets/library_audit.py [--root "D:/raven hollow/assetlib"]
                                       [--purge]   # move rejects to _rejects/
"""
import argparse
import json
import os
import sys

from PIL import Image

MIN_DIM = 12
MIN_OPAQUE = 40
MAX_DIM = 640
HALO_FRACTION = 0.18
CELL = 110
GRID = 10


def ahash(im: Image.Image) -> int:
    g = im.convert("L").resize((8, 8), Image.BILINEAR)
    px = list(g.getdata())
    avg = sum(px) / 64.0
    bits = 0
    for i, v in enumerate(px):
        if v >= avg:
            bits |= 1 << i
    return bits


def check(path: str, seen_hashes: dict) -> tuple:
    """returns (verdict, reason) — verdict OK/REJECT"""
    try:
        im = Image.open(path).convert("RGBA")
    except Exception as e:  # unreadable = defect
        return "REJECT", "unreadable:%s" % e
    w, h = im.size
    if w > MAX_DIM or h > MAX_DIM:
        return "REJECT", "oversize %dx%d" % (w, h)
    a = im.getchannel("A")
    hist = a.histogram()
    opaque = sum(hist[248:])
    if opaque < MIN_OPAQUE:
        return "REJECT", "empty (%d opaque px)" % opaque
    semi = sum(hist[8:248])
    total_visible = opaque + semi
    if total_visible and semi / float(total_visible) > HALO_FRACTION:
        return "REJECT", "halo (%.0f%% semi-alpha)" % (100.0 * semi / total_visible)
    bbox = a.getbbox()
    if bbox is None or (bbox[2] - bbox[0]) < MIN_DIM or (bbox[3] - bbox[1]) < MIN_DIM:
        return "REJECT", "tiny bbox %s" % (bbox,)
    hsh = ahash(im)
    if hsh in seen_hashes:
        return "REJECT", "duplicate of %s" % seen_hashes[hsh]
    seen_hashes[hsh] = os.path.basename(path)
    return "OK", ""


def montage(files: list, out_path: str) -> None:
    sheet = Image.new("RGBA", (GRID * CELL, ((len(files) + GRID - 1) // GRID) * CELL), (48, 48, 52, 255))
    for i, f in enumerate(files):
        try:
            im = Image.open(f).convert("RGBA")
        except Exception:
            continue
        im.thumbnail((CELL - 10, CELL - 10))
        sheet.paste(im, ((i % GRID) * CELL + 5, (i // GRID) * CELL + 5), im)
    sheet.save(out_path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=r"D:\raven hollow\assetlib")
    ap.add_argument("--purge", action="store_true", help="move rejects to <root>/_rejects/<category>/")
    ap.add_argument("--montages", action="store_true", help="also render montage sheets (slow at 30k)")
    args = ap.parse_args()

    out_dir = os.path.join(os.path.dirname(__file__), "..", "..", "_screens", "library_audit")
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    report = {"root": args.root, "categories": {}, "total": 0, "ok": 0, "rejects": 0}
    reject_rows = []
    for cat in sorted(os.listdir(args.root)):
        cdir = os.path.join(args.root, cat)
        if not os.path.isdir(cdir) or cat.startswith("_"):
            continue
        seen = {}  # per-category hash space (cross-category lookalikes are fine)
        ok_files = []
        cat_rej = 0
        files = sorted(f for f in os.listdir(cdir) if f.endswith(".png"))
        for f in files:
            p = os.path.join(cdir, f)
            verdict, reason = check(p, seen)
            report["total"] += 1
            if verdict == "OK":
                report["ok"] += 1
                ok_files.append(p)
            else:
                report["rejects"] += 1
                cat_rej += 1
                reject_rows.append((cat, f, reason))
                if args.purge:
                    rdir = os.path.join(args.root, "_rejects", cat)
                    os.makedirs(rdir, exist_ok=True)
                    os.replace(p, os.path.join(rdir, f))
        report["categories"][cat] = {"files": len(files), "ok": len(ok_files), "rejects": cat_rej}
        if args.montages:
            for page in range((len(ok_files) + 99) // 100):
                montage(ok_files[page * 100:(page + 1) * 100],
                        os.path.join(out_dir, "%s_page%02d.png" % (cat, page)))
        print("%s: %d files, %d ok, %d rejects" % (cat, len(files), len(ok_files), cat_rej))

    with open(os.path.join(out_dir, "report.json"), "w", encoding="utf-8") as f:
        json.dump({"report": report, "rejects": reject_rows}, f, indent=1)
    with open(os.path.join(out_dir, "report.md"), "w", encoding="utf-8") as f:
        f.write("# LIBRARY AUDIT\n\ntotal %(total)d | ok %(ok)d | rejects %(rejects)d\n\n" % report)
        for cat, row in sorted(report["categories"].items()):
            f.write("- %s: %d files, %d ok, %d rejects\n" % (cat, row["files"], row["ok"], row["rejects"]))
        f.write("\n## Rejects\n")
        for cat, fn, reason in reject_rows:
            f.write("- %s/%s — %s\n" % (cat, fn, reason))
    print("TOTAL %(total)d | OK %(ok)d | REJECTS %(rejects)d" % report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
