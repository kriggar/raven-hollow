#!/usr/bin/env python3
"""
GRIDCUT  --  the PERFECT-CUTTING pipeline (owner standard, 2026-07-05, non-negotiable):
"fiecare in patratelul lui, taiat perfect" -- every frame sits in its OWN uniform grid
cell, centered, fully isolated (transparent bg, binary alpha, zero halo), ZERO bleed into
neighbouring cells, uniform cell size across the sheet, consistent registration frame-to-frame.

This module is GENERIC (no spell knowledge). It takes a list of raw frame images (PIL RGBA,
e.g. straight from a ComfyUI render or a procedural compositor) and produces:
  * a clean uniform-grid sprite sheet  (cell x cell cells, `cols` wide, row-major)
  * a per-frame JSON manifest          (cell, cols, rows, count, fw, fh, fps, loop, bboxes)
  * a bleed verification               (rejects if any frame's alpha touches a cell border)
  * a grid-overlay montage             (grid lines + frame numbers drawn, the owner's gate)

Cutting guarantees, by construction:
  1. QUANTIZE, NEVER BLUR  -- every frame is nearest/lanczos-downscaled then palette-quantized
     and hard alpha-thresholded => strictly binary alpha (0 or 255), no anti-alias halo/fringe.
  2. UNIFORM CELLS         -- every cell is exactly `cell` x `cell`.
  3. CENTERED + ISOLATED   -- each frame is cropped to its own alpha bbox and centered in its cell.
  4. CONSISTENT SCALE      -- ONE global scale across the whole sequence (the animation never
     "pumps"); computed from the largest frame so the biggest frame still clears the margin.
  5. ZERO BLEED            -- a `margin`-px transparent ring is guaranteed around every cell;
     the bleed check re-verifies it and the fitter shrinks-and-recuts until it passes.

Reused from interpret.py: binary-alpha cleaning, despeckle, gothic palette quantize.

Run with the ComfyUI venv python (PIL + numpy):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/gridcut.py --help
"""
from __future__ import annotations
import os, sys, json, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I   # alpha_bbox, _despeckle, quantize_gothic, cleanliness helpers


# ---------------------------------------------------------------------------------------
# frame cleaning -- binary alpha, no blur, gothic-cohesive palette
# ---------------------------------------------------------------------------------------
def clean_frame(im: Image.Image, n_colors: int = 32, nudge: float = 0.18,
                alpha_thr: int = 110, min_blob: int = 4,
                quantize: bool = True) -> Image.Image:
    """Cut a single raw frame to the spotless bar WITHOUT rescaling (gridcut owns scale).
    Binary alpha -> zero halo. Optional gothic-nudged palette quantize kills render mush."""
    im = im.convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 255 if v >= alpha_thr else 0)          # binary alpha => no fringe
    if quantize:
        rgb = I.quantize_gothic(Image.merge("RGB", (r, g, b)), n_colors=n_colors, nudge=nudge)
        r, g, b = rgb.split()
    out = Image.merge("RGBA", (r, g, b, a))
    out = I._despeckle(out, min_blob=min_blob)                   # drop orphan dust
    return out


def _resize_rgba(im: Image.Image, w: int, h: int) -> Image.Image:
    """Scale keeping alpha strictly binary afterwards (downscale can re-introduce a soft edge)."""
    w, h = max(1, w), max(1, h)
    up = im.width < w or im.height < h
    im = im.resize((w, h), Image.NEAREST if up else Image.LANCZOS)
    r, g, b, a = im.split()
    a = a.point(lambda v: 255 if v >= 128 else 0)
    return Image.merge("RGBA", (r, g, b, a))


# ---------------------------------------------------------------------------------------
# THE FITTER  -- crop to bbox, one global scale, centre in a uniform cell, no bleed
# ---------------------------------------------------------------------------------------
def cut(frames, cell: int = 96, cols: int | None = None, margin: int = 6,
        n_colors: int = 32, nudge: float = 0.18, quantize: bool = True,
        anchor: str = "center"):
    """Place `frames` into a uniform `cell` x `cell` grid.
    anchor: "center" (VFX bursts) or "bottom" (feet-line registration for characters).
    Returns (sheet: RGBA, manifest: dict). Guarantees the bleed check passes.
    """
    cleaned = [clean_frame(f, n_colors=n_colors, nudge=nudge, quantize=quantize) for f in frames]
    boxed = []
    for c in cleaned:
        bb = I.alpha_bbox(c, thr=128)
        boxed.append(c.crop(bb) if bb else Image.new("RGBA", (1, 1), (0, 0, 0, 0)))

    avail = cell - 2 * margin                       # max content span that clears the margin
    if avail < 4:
        raise ValueError("cell too small for margin")
    # ONE global scale for the whole sequence (no per-frame pumping).
    max_span = max((max(b.width, b.height) for b in boxed), default=1)
    scale = min(1.0, avail / float(max_span))       # only ever downscale to fit; never blow up

    n = len(boxed)
    cc = cols if cols else min(n, 8)
    rows = max(1, math.ceil(n / cc))
    sheet = Image.new("RGBA", (cc * cell, rows * cell), (0, 0, 0, 0))
    frame_meta = []
    for i, b in enumerate(boxed):
        nw, nh = max(1, round(b.width * scale)), max(1, round(b.height * scale))
        # hard safety clamp so a rounding wobble can NEVER breach the margin ring
        nw, nh = min(nw, avail), min(nh, avail)
        fit = _resize_rgba(b, nw, nh) if (nw != b.width or nh != b.height) else b
        cx0 = (i % cc) * cell
        cy0 = (i // cc) * cell
        ox = cx0 + (cell - fit.width) // 2
        if anchor == "bottom":
            oy = cy0 + (cell - margin - fit.height)
        else:
            oy = cy0 + (cell - fit.height) // 2
        sheet.alpha_composite(fit, (ox, oy))
        frame_meta.append({"index": i, "cell": [i % cc, i // cc],
                           "content_size": [fit.width, fit.height],
                           "offset_in_cell": [ox - cx0, oy - cy0]})

    manifest = {
        "cell": cell, "cols": cc, "rows": rows, "count": n,
        "fw": cell, "fh": cell, "margin": margin, "anchor": anchor,
        "global_scale": round(scale, 4), "frames": frame_meta,
    }
    return sheet, manifest


# ---------------------------------------------------------------------------------------
# BLEED CHECK  -- the hard cutting gate: no opaque pixel may touch a cell border
# ---------------------------------------------------------------------------------------
def bleed_check(sheet: Image.Image, cell: int, cols: int, rows: int, count: int):
    """Return (ok, violations). A violation = a cell whose 1px border ring has an opaque
    pixel (=> the frame bleeds into / touches a neighbouring cell)."""
    a = sheet.split()[3].point(lambda v: 255 if v >= 128 else 0).load()
    W, H = sheet.size
    violations = []
    for idx in range(count):
        cx = (idx % cols) * cell
        cy = (idx // cols) * cell
        touched = 0
        for x in range(cx, cx + cell):
            if cy < H and a[x, cy]:
                touched += 1
            if cy + cell - 1 < H and a[x, cy + cell - 1]:
                touched += 1
        for y in range(cy, cy + cell):
            if cx < W and a[cx, y]:
                touched += 1
            if cx + cell - 1 < W and a[cx + cell - 1, y]:
                touched += 1
        if touched:
            violations.append({"frame": idx, "border_opaque_px": touched})
    return (len(violations) == 0), violations


# ---------------------------------------------------------------------------------------
# GRID-OVERLAY MONTAGE  -- the owner sees this FIRST (before Godot): grid lines + numbers
# ---------------------------------------------------------------------------------------
def _checker(w, h, s=8):
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = bg.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = (58, 54, 60, 255) if ((x // s + y // s) & 1) else (40, 37, 43, 255)
    return bg


def grid_overlay(sheet: Image.Image, cell: int, cols: int, rows: int, count: int,
                 up: int = 3, title: str = "", ok: bool = True, subtitle: str = ""):
    """Nearest-upscale the sheet onto a checker, draw the cell grid + frame numbers so the
    owner can confirm every frame is perfectly inside its cell. Green = bleed check PASS."""
    cu = cell * up
    W, H = cols * cu, rows * cu
    header = 40 if title else 0
    footer = 26
    canvas = Image.new("RGBA", (W, header + H + footer), (26, 23, 29, 255))
    board = _checker(W, H)
    up_sheet = sheet.resize((sheet.width * up, sheet.height * up), Image.NEAREST)
    board.alpha_composite(up_sheet, (0, 0))
    canvas.alpha_composite(board, (0, header))

    d = ImageDraw.Draw(canvas)
    line = (232, 210, 120, 255)          # lantern gold grid
    for c in range(cols + 1):
        x = c * cu
        d.line([(x, header), (x, header + H)], fill=line, width=1)
    for r in range(rows + 1):
        y = header + r * cu
        d.line([(0, y), (W, y)], fill=line, width=1)
    for idx in range(count):
        cx = (idx % cols) * cu
        cy = header + (idx // cols) * cu
        d.rectangle([cx + 2, cy + 2, cx + 15, cy + 13], fill=(20, 18, 24, 220))
        d.text((cx + 4, cy + 3), str(idx), fill=(240, 224, 170, 255))
    if title:
        d.text((6, 6), title, fill=(236, 216, 189, 255))
        badge = "CUT: PASS  (zero bleed)" if ok else "CUT: FAIL  (bleed!)"
        d.text((6, 22), badge, fill=((150, 210, 130, 255) if ok else (220, 90, 80, 255)))
    if subtitle:
        d.text((6, header + H + 6), subtitle, fill=(150, 143, 160, 255))
    return canvas


# ---------------------------------------------------------------------------------------
# top-level: cut a sequence -> sheet + manifest + montage, with a bleed gate + auto-shrink
# ---------------------------------------------------------------------------------------
def build_sheet(frames, name: str, out_dir: str, montage_dir: str,
                cell: int = 96, cols: int | None = None, margin: int = 6,
                fps: float = 14.0, loop: bool = False, anchor: str = "center",
                n_colors: int = 32, nudge: float = 0.18, quantize: bool = True,
                extra_meta: dict | None = None):
    """Full deliverable for one animation: clean+cut -> bleed-gate (shrink&recut on fail) ->
    write sheet PNG + manifest JSON, and render the grid-overlay montage. Returns a report."""
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(montage_dir, exist_ok=True)
    tries = []
    m = margin
    for attempt in range(4):
        sheet, manifest = cut(frames, cell=cell, cols=cols, margin=m,
                              n_colors=n_colors, nudge=nudge, quantize=quantize, anchor=anchor)
        ok, violations = bleed_check(sheet, cell, manifest["cols"], manifest["rows"], manifest["count"])
        tries.append({"margin": m, "ok": ok, "violations": len(violations)})
        if ok:
            break
        m += 3                                   # widen the safety ring and recut
    sheet_path = os.path.join(out_dir, f"{name}.png")
    sheet.save(sheet_path)
    manifest.update({"name": name, "fps": fps, "loop": loop,
                     "sheet": os.path.basename(sheet_path),
                     "bleed_ok": ok, "bleed_violations": violations, "fit_attempts": tries})
    if extra_meta:
        manifest.update(extra_meta)
    with open(os.path.join(out_dir, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    sub = (f"cell {cell}x{cell}  |  {manifest['cols']}x{manifest['rows']} grid  |  "
           f"{manifest['count']} frames  |  scale {manifest['global_scale']}  |  margin {m}px")
    mont = grid_overlay(sheet, cell, manifest["cols"], manifest["rows"], manifest["count"],
                        title=name, ok=ok, subtitle=sub)
    mont_path = os.path.join(montage_dir, f"{name}.png")
    mont.convert("RGB").save(mont_path)
    return {"name": name, "sheet": sheet_path, "manifest": os.path.join(out_dir, f"{name}.json"),
            "montage": mont_path, "bleed_ok": ok, "cols": manifest["cols"], "rows": manifest["rows"],
            "count": manifest["count"], "cell": cell}


# ---------------------------------------------------------------------------------------
# CLI: cut a directory of PNG frames (natural sort) into a sheet + montage
# ---------------------------------------------------------------------------------------
def _cli():
    import argparse, glob, re
    ap = argparse.ArgumentParser(description="Gridcut: perfect uniform-grid sprite-sheet cutter")
    ap.add_argument("frames_dir", help="dir of per-frame PNGs (sorted naturally)")
    ap.add_argument("--name", default=None)
    ap.add_argument("--out", default=None, help="sheet/manifest dir")
    ap.add_argument("--montage", default=None, help="montage dir")
    ap.add_argument("--cell", type=int, default=96)
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--margin", type=int, default=6)
    ap.add_argument("--fps", type=float, default=14.0)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--anchor", default="center", choices=["center", "bottom"])
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.frames_dir, "*.png")),
                   key=lambda p: [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", p)])
    if not files:
        print("no PNG frames found"); return
    frames = [Image.open(f).convert("RGBA") for f in files]
    name = args.name or os.path.basename(os.path.normpath(args.frames_dir))
    out = args.out or args.frames_dir
    mont = args.montage or args.frames_dir
    rep = build_sheet(frames, name, out, mont, cell=args.cell,
                      cols=(args.cols or None), margin=args.margin, fps=args.fps,
                      loop=args.loop, anchor=args.anchor)
    print(json.dumps(rep, indent=2))


if __name__ == "__main__":
    _cli()
