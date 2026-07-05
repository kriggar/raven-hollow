#!/usr/bin/env python3
"""
ANIMATION FINISHING CHAIN  (sorceress.games-derived, owner MAX-EFFORT law, 2026-07-06).

Applied to EXTRACTED VIDEO FRAMES (Wan2.2 TI2V clips, or any per-frame set / GIF) *BEFORE* the
razor cut (interpret.py) or the grid cut (gridcut.py). It turns a raw, flickering, wobbling video
clip into a clean, temporally-locked pixel-art animation the way a hand pixel-artist would finish it:

  1. SHARED-PALETTE TEMPORAL LOCK  — build ONE palette from all frames (or a designated key frame),
     max N colours, then quantize EVERY frame against that single palette. Kills the inter-frame
     colour flicker Wan produces (each frame otherwise quantizes to a slightly different palette).
     Ordered/error-diffusion dithering is OFF by default (flat pixel art), toggle with dither=True.
  2. SILHOUETTE-PRESERVING DOWNSCALE — area-average (BOX) downscale to the target cell size, THEN
     re-snap to the shared palette. Never a bilinear-only shrink (that smears the silhouette).
  3. HARD-EDGE PASS — after the downscale the alpha is binarised (0 or 255, no half-tones); every
     edge pixel is assigned fully in or fully out. Zero anti-alias halo by construction.
  4. ANCHOR ALIGNMENT (anti-wobble) — compute the opaque-pixel CENTROID (or the bottom-center FEET
     anchor) of reference frame 0, then integer-pixel-shift every other frame so its anchor coincides
     with frame 0's. Kills the 1-3px per-frame drift that makes a Wan sprite "swim". Max drift logged.
  5. TEMPORAL OUTLIER SMOOTHING — a pixel that differs from BOTH its temporal neighbours while those
     two agree is a single-frame sparkle; it is replaced with the agreed value. Conservative: only
     fires when neighbours strictly agree, endpoints untouched.

Input frames may already carry alpha (a prior key) OR be flat RGB / opaque RGBA on a uniform key or
checkerboard background (e.g. a montage GIF) — in the latter case the background is auto-keyed first.

CLI:
  python tools/assets/anim_finish.py <frames_dir|gif> --cell 64 --colors 24 --anchor feet --out DIR
Importable:
  from anim_finish import finish_animation, load_frames, before_after_filmstrip

Run with the ComfyUI venv python (PIL + numpy):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/anim_finish.py --help
"""
from __future__ import annotations
import os, sys, json, glob, re, argparse
from collections import deque, Counter
from PIL import Image, ImageDraw, ImageSequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I   # _cdist, _defringe, _despill, _despeckle, alpha_bbox, _checker

# PIL resample-constant compat (Pillow moved these under Image.Resampling).
_R = getattr(Image, "Resampling", Image)
BOX, NEAREST, LANCZOS = _R.BOX, _R.NEAREST, _R.LANCZOS
try:
    DITHER_NONE = Image.Dither.NONE
    DITHER_FS = Image.Dither.FLOYDSTEINBERG
except AttributeError:                      # very old Pillow
    DITHER_NONE, DITHER_FS = Image.NONE, Image.FLOYDSTEINBERG


# ========================================================================================
# INGEST  — load a GIF or a directory of PNG frames; key any flat/checker background to alpha
# ========================================================================================
def _natkey(p):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", p)]


def _key_background(im, tol=80):
    """Flood-fill from the border, keying any border-connected pixel within `tol` of ANY of the
    (few) dominant border colours. Handles a UNIFORM key screen (green/magenta/black) AND a 2-colour
    montage CHECKERBOARD in one pass. Interior sprite pixels far from the border colours survive."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    c = Counter()
    for x in range(w):
        c[px[x, 0][:3]] += 1
        c[px[x, h - 1][:3]] += 1
    for y in range(h):
        c[px[0, y][:3]] += 1
        c[px[w - 1, y][:3]] += 1
    keys = [col for col, _ in c.most_common(4)]     # checkerboard = 2, uniform = 1
    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        dq.append((x, 0)); dq.append((x, h - 1))
    for y in range(h):
        dq.append((0, y)); dq.append((w - 1, y))
    while dq:
        x, y = dq.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        if min(I._cdist((r, g, b), k) for k in keys) > tol:
            continue
        px[x, y] = (r, g, b, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                dq.append((nx, ny))
    return im


def _opaque_fraction(im):
    a = im.split()[3]
    return sum(a.histogram()[16:]) / float(im.width * im.height)


def _ensure_alpha(im, tol=80):
    """If a frame carries no meaningful transparency (>=99% opaque) it is a flat render on a key/
    checker bg — key it. Frames that already have an alpha matte pass through untouched (+ despill)."""
    im = im.convert("RGBA")
    if _opaque_fraction(im) >= 0.99:
        im = _key_background(im, tol=tol)
    return I._despill(im)


def load_frames(source, tol=80):
    """Load animation frames from a GIF path or a directory of PNGs (natural-sorted).
    Returns a list of RGBA frames, each with a real alpha matte (background auto-keyed if needed),
    all normalised to a common canvas size (centre-padded)."""
    frames = []
    if isinstance(source, (list, tuple)):
        frames = [f.convert("RGBA") for f in source]
    elif os.path.isdir(source):
        files = [f for f in sorted(glob.glob(os.path.join(source, "*.png")), key=_natkey)
                 if not f.endswith(".import")]
        frames = [Image.open(f).convert("RGBA") for f in files]
    elif source.lower().endswith(".gif"):
        frames = [f.convert("RGBA") for f in ImageSequence.Iterator(Image.open(source))]
    else:
        frames = [Image.open(source).convert("RGBA")]
    if not frames:
        raise ValueError(f"no frames found in {source}")
    frames = [_ensure_alpha(f, tol=tol) for f in frames]
    # normalise to a common canvas (centre-pad) so downstream pixel ops line up
    W = max(f.width for f in frames)
    H = max(f.height for f in frames)
    norm = []
    for f in frames:
        if f.size == (W, H):
            norm.append(f)
        else:
            c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            c.alpha_composite(f, ((W - f.width) // 2, (H - f.height) // 2))
            norm.append(c)
    return norm


# ========================================================================================
# 1. SHARED-PALETTE TEMPORAL LOCK
# ========================================================================================
def build_shared_palette(frames, colors=24, key_frame=None):
    """Build ONE median-cut palette (<= `colors`) from the opaque pixels of ALL frames, or from a
    single designated key frame index. Returns a PIL 'P' image usable as a quantize palette."""
    src = [frames[key_frame]] if key_frame is not None else frames
    pixels = []
    for f in src:
        f = f.convert("RGBA")
        px = f.load()
        for y in range(f.height):
            for x in range(f.width):
                r, g, b, a = px[x, y]
                if a >= 128:
                    pixels.append((r, g, b))
    if not pixels:
        return Image.new("RGB", (1, 1), (0, 0, 0)).quantize(colors=max(2, colors))
    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    return strip.quantize(colors=max(2, colors), method=Image.MEDIANCUT, dither=DITHER_NONE)


def snap_to_palette(frame, master, dither=False):
    """Re-snap a frame's RGB to the shared master palette (temporal lock). Alpha is preserved as-is;
    the hard-edge pass binarises it afterwards."""
    frame = frame.convert("RGBA")
    r, g, b, a = frame.split()
    rgb = Image.merge("RGB", (r, g, b))
    q = rgb.quantize(palette=master, dither=(DITHER_FS if dither else DITHER_NONE)).convert("RGB")
    return Image.merge("RGBA", (*q.split(), a))


# ========================================================================================
# 2. SILHOUETTE-PRESERVING DOWNSCALE  (area-average BOX, never bilinear-only)
# ========================================================================================
def _union_bbox(frames, thr=128):
    """Union of every frame's opaque bounding box — cropping ALL frames to this shared box keeps
    inter-frame registration (the object never jumps because of an independent per-frame crop)."""
    box = None
    for f in frames:
        bb = I.alpha_bbox(f, thr)
        if not bb:
            continue
        box = bb if box is None else (min(box[0], bb[0]), min(box[1], bb[1]),
                                      max(box[2], bb[2]), max(box[3], bb[3]))
    return box


def area_downscale_all(frames, cell):
    """Crop every frame to the shared union bbox, defringe (so edge averaging can't pull in keyed
    background colour), then area-average (BOX) downscale by ONE global scale to fit `cell`.
    Returns (scaled_frames, scale). All outputs share a uniform size."""
    box = _union_bbox(frames)
    if box is None:
        return [f.copy() for f in frames], 1.0
    uw, uh = box[2] - box[0], box[3] - box[1]
    scale = min(1.0, cell / float(max(uw, uh)))
    tw, th = max(1, round(uw * scale)), max(1, round(uh * scale))
    out = []
    for f in frames:
        crop = f.crop(box)
        crop = I._defringe(crop)                       # fill transparent RGB w/ mean obj colour
        out.append(crop.resize((tw, th), BOX))         # AREA-AVERAGE, not bilinear
    return out, scale


# ========================================================================================
# 3. HARD-EDGE PASS
# ========================================================================================
def hard_edge(frame, alpha_thr=128):
    """Binarise alpha: every edge pixel is fully in (>=thr -> 255) or fully out (<thr -> 0)."""
    frame = frame.convert("RGBA")
    r, g, b, a = frame.split()
    a = a.point(lambda v: 255 if v >= alpha_thr else 0)
    return Image.merge("RGBA", (r, g, b, a))


# ========================================================================================
# 4. ANCHOR ALIGNMENT  (anti-wobble)
# ========================================================================================
def _anchor_point(frame, anchor="centroid", thr=128):
    """Return the (x, y) anchor of a frame's opaque mass.
    centroid = mean of opaque pixels; feet = bottom-center (mean x, lowest opaque row)."""
    px = frame.load()
    w, h = frame.size
    sx = sy = n = 0
    max_y = -1
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= thr:
                sx += x; sy += y; n += 1
                if y > max_y:
                    max_y = y
    if n == 0:
        return None
    cx = sx / n
    if anchor == "feet":
        # mean x of the pixels on / near the lowest opaque row = the "feet" x
        fxs = [x for x in range(w) if any(px[x, yy][3] >= thr for yy in range(max(0, max_y - 1), max_y + 1))]
        fx = sum(fxs) / len(fxs) if fxs else cx
        return (fx, float(max_y))
    return (cx, sy / n)


def anchor_align(frames, anchor="centroid", margin=6):
    """Integer-pixel-shift every frame so its anchor coincides with reference frame 0's anchor.
    Frames are re-composited onto a uniform (w+2m)x(h+2m) canvas. Returns (aligned, report)."""
    if not frames:
        return frames, {"anchor": anchor, "max_drift_px": 0, "shifts": []}
    w, h = frames[0].size
    cw, ch = w + 2 * margin, h + 2 * margin
    ref = _anchor_point(frames[0], anchor)
    aligned, shifts, max_drift = [], [], 0
    for i, f in enumerate(frames):
        ap = _anchor_point(f, anchor)
        if ref is None or ap is None:
            dx = dy = 0
        else:
            dx = int(round(ref[0] - ap[0]))
            dy = int(round(ref[1] - ap[1]))
        # clamp so the shift can never push content off the padded canvas
        dx = max(-margin, min(margin, dx))
        dy = max(-margin, min(margin, dy))
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(f, (margin + dx, margin + dy))
        aligned.append(canvas)
        shifts.append([dx, dy])
        max_drift = max(max_drift, abs(dx), abs(dy))
    return aligned, {"anchor": anchor, "max_drift_px": max_drift, "shifts": shifts}


# ========================================================================================
# 5. TEMPORAL OUTLIER SMOOTHING  (single-frame sparkle removal)
# ========================================================================================
_CLEAR = (0, 0, 0, 0)


def _canon(px):
    """Canonicalise a pixel for temporal comparison: any transparent pixel (a<128) collapses to a
    single CLEAR sentinel so junk RGB behind the matte can't count as a difference."""
    return _CLEAR if px[3] < 128 else px


def temporal_smooth(frames):
    """A pixel that differs from BOTH temporal neighbours while those two AGREE is a single-frame
    sparkle -> replaced with the agreed value. Comparison ignores RGB behind the alpha matte, so
    only genuine visible/silhouette flicker is corrected. Endpoints untouched. Returns (frames, n)."""
    if len(frames) < 3:
        return [f.copy() for f in frames], 0
    w, h = frames[0].size
    loads = [f.load() for f in frames]
    out = [f.copy() for f in frames]
    outloads = [o.load() for o in out]
    fixed = 0
    for i in range(1, len(frames) - 1):
        prev, cur, nxt = loads[i - 1], loads[i], loads[i + 1]
        ol = outloads[i]
        for y in range(h):
            for x in range(w):
                p, c, n = _canon(prev[x, y]), _canon(cur[x, y]), _canon(nxt[x, y])
                if p == n and c != p:          # neighbours agree, this frame disagrees
                    ol[x, y] = prev[x, y]      # adopt the neighbour's actual pixel
                    fixed += 1
    return out, fixed


# ========================================================================================
# ORCHESTRATION
# ========================================================================================
def finish_animation(source, cell=64, colors=24, anchor="centroid", dither=False,
                     key_frame=None, margin=6, alpha_thr=128, tol=80):
    """Full finishing chain. `source` is a GIF path, a frames dir, or a list of PIL frames.
    Returns (finished_frames, report). Frames are uniform-size RGBA, temporally locked, hard-edged,
    anchor-aligned and de-sparkled — ready for interpret.py / gridcut.py / godot_export.py."""
    raw = load_frames(source, tol=tol) if not isinstance(source, (list, tuple)) else load_frames(source)
    n_in = len(raw)
    scaled, scale = area_downscale_all(raw, cell)
    master = build_shared_palette(scaled, colors=colors, key_frame=key_frame)
    pal_n = len(set(master.convert("RGB").getdata()))
    snapped = [hard_edge(snap_to_palette(f, master, dither=dither), alpha_thr) for f in scaled]
    aligned, align_rep = anchor_align(snapped, anchor=anchor, margin=margin)
    smoothed, fixed = temporal_smooth(aligned)
    report = {
        "frames_in": n_in, "frames_out": len(smoothed),
        "cell": cell, "colors_requested": colors, "palette_size": pal_n,
        "global_scale": round(scale, 4), "dither": bool(dither),
        "anchor": anchor, "max_drift_px": align_rep["max_drift_px"],
        "anchor_shifts": align_rep["shifts"],
        "temporal_sparkles_fixed": fixed,
        "frame_size": list(smoothed[0].size) if smoothed else [0, 0],
    }
    return smoothed, report


# ========================================================================================
# BEFORE / AFTER FILMSTRIP  (the human eyeball artifact)
# ========================================================================================
def _row_strip(frames, up, label, cell_w, cell_h, checker=True):
    n = len(frames)
    W = n * cell_w
    strip = (I._checker(W, cell_h) if checker else Image.new("RGB", (W, cell_h), (30, 27, 33))).convert("RGBA")
    for i, f in enumerate(frames):
        f = f.convert("RGBA")
        s = min((cell_w - 4) / f.width, (cell_h - 4) / f.height, up)
        nw, nh = max(1, int(f.width * s)), max(1, int(f.height * s))
        u = f.resize((nw, nh), NEAREST)
        strip.alpha_composite(u, (i * cell_w + (cell_w - nw) // 2, (cell_h - nh) // 2))
    return strip


def before_after_filmstrip(before, after, out_path, up=4, title="anim_finish"):
    """One PNG: top row = BEFORE frames (raw, on checker), bottom row = AFTER frames (finished),
    labelled, same frame order. The reviewer sees the flicker/wobble kill at a glance."""
    n = max(len(before), len(after))
    bw = max((f.width for f in before), default=1)
    bh = max((f.height for f in before), default=1)
    aw = max((f.width for f in after), default=1)
    ah = max((f.height for f in after), default=1)
    cell_w = max(bw, aw) * up + 8
    cell_h = max(bh, ah) * up + 8
    label_h = 20
    header = 26
    W = n * cell_w
    H = header + (label_h + cell_h) * 2
    canvas = Image.new("RGBA", (W, H), (24, 21, 27, 255))
    d = ImageDraw.Draw(canvas)
    d.text((6, 6), f"{title}   ({len(before)} frames in -> {len(after)} out)", fill=(236, 216, 189, 255))
    y = header
    d.text((6, y + 4), "BEFORE (raw extracted frames)", fill=(210, 150, 140, 255))
    canvas.alpha_composite(_row_strip(before, up, "BEFORE", cell_w, cell_h), (0, y + label_h))
    y += label_h + cell_h
    d.text((6, y + 4), "AFTER (palette-lock + downscale + hard-edge + anchor-align + de-sparkle)",
           fill=(150, 210, 130, 255))
    canvas.alpha_composite(_row_strip(after, up, "AFTER", cell_w, cell_h), (0, y + label_h))
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    canvas.convert("RGB").save(out_path)
    return out_path


# ========================================================================================
# OUTPUT HELPERS
# ========================================================================================
def pack_row_sheet(frames):
    """Pack finished (uniform-size) frames left-to-right into one row sheet. Returns (sheet, cw, ch)."""
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    sheet = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, (ch - f.height) // 2))
    return sheet, cw, ch


def write_frames(frames, out_dir, name="frame"):
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for i, f in enumerate(frames):
        p = os.path.join(out_dir, f"{name}_{i:03d}.png")
        f.save(p)
        paths.append(p)
    return paths


# ========================================================================================
# CLI
# ========================================================================================
def _cli():
    ap = argparse.ArgumentParser(description="Animation finishing chain (palette lock, downscale, "
                                             "hard-edge, anchor align, temporal smoothing)")
    ap.add_argument("source", help="frames dir OR .gif")
    ap.add_argument("--cell", type=int, default=64, help="target cell (long-side) px")
    ap.add_argument("--colors", type=int, default=24, help="max palette colours (temporal lock)")
    ap.add_argument("--anchor", default="centroid", choices=["centroid", "feet"])
    ap.add_argument("--dither", action="store_true", help="error-diffusion dither (default off: flat)")
    ap.add_argument("--key-frame", type=int, default=None, help="build palette from this frame only")
    ap.add_argument("--margin", type=int, default=6, help="anti-wobble canvas margin px")
    ap.add_argument("--out", required=True, help="output dir for finished frames + sheet + report")
    ap.add_argument("--name", default=None, help="animation name (defaults to source basename)")
    ap.add_argument("--filmstrip", action="store_true", help="also write a before/after filmstrip PNG")
    args = ap.parse_args()

    name = args.name or os.path.splitext(os.path.basename(os.path.normpath(args.source)))[0]
    before = load_frames(args.source)
    finished, report = finish_animation(args.source, cell=args.cell, colors=args.colors,
                                        anchor=args.anchor, dither=args.dither,
                                        key_frame=args.key_frame, margin=args.margin)
    os.makedirs(args.out, exist_ok=True)
    frames_dir = os.path.join(args.out, "frames")          # keep frames separate from sheet/filmstrip
    write_frames(finished, frames_dir, name=name)
    sheet, cw, ch = pack_row_sheet(finished)
    sheet.save(os.path.join(args.out, f"{name}_sheet.png"))
    report.update({"name": name, "sheet_cell": [cw, ch], "sheet": f"{name}_sheet.png",
                   "frames_dir": "frames", "cols": len(finished), "rows": 1})
    with open(os.path.join(args.out, f"{name}_finish.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    if args.filmstrip:
        before_after_filmstrip(before, finished, os.path.join(args.out, f"{name}_filmstrip.png"),
                               title=f"anim_finish: {name}")
    print(json.dumps(report, indent=2))
    print(f"[anim_finish] {name}: {report['frames_in']} in -> {report['frames_out']} out, "
          f"palette {report['palette_size']}, drift {report['max_drift_px']}px, "
          f"sparkles fixed {report['temporal_sparkles_fixed']} -> {args.out}")


if __name__ == "__main__":
    _cli()
