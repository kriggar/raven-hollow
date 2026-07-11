#!/usr/bin/env python3
"""
INTERPRETER HORDE  (BACKLOG #112) + the SPOTLESS cleaning bar (owner, 2026-07-05).

For every sprite (scouted or ComfyUI-generated) this module:
  1. CLEANS it to the spotless bar   -> cutout / pixel-snap / quantize / alpha-trim / de-fringe
  2. INTERPRETS its geometry          -> grid, rows, per-row facing, frame count, feet-line, bounds
  3. VERIFIES it against a fixed rubric (cleanliness checks; a vision pass adds the perceptual gate)
  4. MONTAGES it for a human eyeball  -> _downloads/_assetlib/verified/<pack>/<id>_montage.png
  5. INDEXES the passers into         -> _downloads/_assetlib/library.json

It runs standalone (CLI over a directory of PNGs) OR is imported by generate.py, which
calls clean_sprite() + cleanliness_report() before an asset is allowed into the library.

Run with the ComfyUI venv python (has PIL + numpy + rembg):
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/interpret.py --help

Truth-over-hype law: nothing enters library.json unless it PASSES. Rejections are logged with a reason.
"""
from __future__ import annotations
import os, sys, json, math, argparse, glob
from collections import deque
from PIL import Image

# ----------------------------------------------------------------------------------------
# THE GOTHIC MASTER PALETTE  (design/LEVEL_PAINTING_BIBLE.md: muted gothic Eastern-European
# -- mud browns, moss greens, cold slate, warm lantern gold, stone, bone, deep shadow, rust)
# Used for (a) a gentle cohesion nudge after quantize, (b) palette-compatibility scoring.
# ----------------------------------------------------------------------------------------
GOTHIC = [
    (0x1a, 0x17, 0x20), (0x24, 0x1f, 0x2b), (0x2b, 0x27, 0x2e),   # deep shadow / near-black
    (0x3a, 0x2a, 0x1e), (0x5a, 0x46, 0x32), (0x7a, 0x5c, 0x3a), (0x9a, 0x7a, 0x4e),  # mud browns
    (0x2e, 0x3a, 0x24), (0x47, 0x55, 0x2f), (0x5f, 0x6b, 0x3a), (0x7c, 0x8a, 0x4a),  # moss greens
    (0x22, 0x2a, 0x30), (0x2b, 0x33, 0x3b), (0x3f, 0x4a, 0x54), (0x5a, 0x67, 0x73), (0x88, 0x95, 0xa0),  # cold slate
    (0x4a, 0x46, 0x40), (0x6b, 0x66, 0x5c), (0x8f, 0x89, 0x7c), (0xb3, 0xac, 0x9d),  # stone greys
    (0x9a, 0x6f, 0x20), (0xc9, 0x92, 0x2e), (0xe6, 0xb8, 0x4c), (0xf2, 0xd2, 0x7a),  # warm lantern gold
    (0xcd, 0xbf, 0xa0), (0xe3, 0xd8, 0xbd),   # bone / parchment
    (0x6e, 0x2a, 0x22), (0x8f, 0x3a, 0x2a),   # dried-blood / rust accents (use sparingly)
]

# a chroma background we ask ComfyUI to render props on (never appears in the gothic palette)
CHROMA = (0x1f, 0xd0, 0x57)   # bright key-green


# ========================================================================================
# CLEANING  --  the SPOTLESS bar
# ========================================================================================
def _corners(im):
    w, h = im.size
    px = im.load()
    return [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]


def _cdist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def _border_floodfill_key(im, key, tol=60):
    """Remove the background by flood-filling from every border pixel that matches `key`.
    This is safe (won't punch holes in same-colored interior regions the way a global
    color test would). Returns a new RGBA with keyed pixels made transparent."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        if _cdist((r, g, b), key) > tol:
            continue
        px[x, y] = (r, g, b, 0)
        if x > 0:
            dq.append((x - 1, y))
        if x < w - 1:
            dq.append((x + 1, y))
        if y > 0:
            dq.append((x, y - 1))
        if y < h - 1:
            dq.append((x, y + 1))
    # despill: any surviving pixel that is still strongly green -> neutralise the green cast
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and g > r + 30 and g > b + 30:
                px[x, y] = (r, min(g, max(r, b)), b, a)
    return im


def _opaque_fraction(im):
    a = im.split()[3]
    hist = a.histogram()
    opaque = sum(hist[16:])          # a >= 16
    return opaque / float(im.width * im.height)


def _dominant_border_color(im):
    """Most common colour among the 1px frame -- the presumed flat background."""
    w, h = im.size
    px = im.load()
    from collections import Counter
    c = Counter()
    for x in range(w):
        c[px[x, 0][:3]] += 1
        c[px[x, h - 1][:3]] += 1
    for y in range(h):
        c[px[0, y][:3]] += 1
        c[px[w - 1, y][:3]] += 1
    return c.most_common(1)[0][0]


def _chroma_kind(col):
    """Classify a border colour as a chroma KEY: 'green', 'magenta', or 'neutral'."""
    r, g, b = col[:3]
    if g > 90 and g > r + 35 and g > b + 35:
        return "green"
    if r > 90 and b > 90 and g + 30 < r and g + 30 < b:
        return "magenta"
    return "neutral"


def detect_key_color(im):
    """Sorceress adaptive chroma detection. Returns (kind, border_col, collision_frac) where kind is
    'green'|'magenta'|'neutral' and collision_frac is the fraction of the SPRITE's interior opaque
    pixels that share the key hue (i.e. would be wrongly eaten by a naive global colour key). A high
    collision means the render should have used the OTHER key screen — we log it and stay spatial."""
    im = im.convert("RGBA")
    bgcol = _dominant_border_color(im)
    kind = _chroma_kind(bgcol)
    if kind == "neutral":
        return kind, bgcol, 0.0
    keyed = _border_floodfill_key(im.copy(), bgcol, tol=96)     # spatial removal (safe interior)
    px = keyed.load(); w, h = keyed.size
    survive = collide = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            survive += 1
            if kind == "green" and g > r + 24 and g > b + 24:
                collide += 1
            elif kind == "magenta" and r > g + 24 and b > g + 24:
                collide += 1
    return kind, bgcol, (collide / survive if survive else 0.0)


def adaptive_chroma_key(im, tol=96):
    """Remove a uniform green/magenta key screen by border flood-fill (spatial: cannot punch holes in
    same-hued interior detail the way a global colour test would), then RGB-despill the survivors so
    no coloured fringe leaks from the key. Returns (keyed_rgba, info). Neutral bg falls back to cutout."""
    im = im.convert("RGBA")
    kind, bgcol, coll = detect_key_color(im)
    if kind == "neutral":
        return cutout(im), {"key": "neutral", "collision_frac": 0.0}
    keyed = _despill(_border_floodfill_key(im.copy(), bgcol, tol=tol))
    if coll > 0.15:
        sys.stderr.write(f"[interpret] chroma collision {coll:.2f}: sprite shares the {kind} key hue — "
                         f"render on the OTHER key for a cleaner cut (keying stayed spatial)\n")
    return keyed, {"key": kind, "border": list(bgcol), "collision_frac": round(coll, 3)}


def cutout(im):
    """Isolate the subject on transparent. Collects candidate cuts -- an ADAPTIVE CHROMA-KEY pass
    (green/magenta detected + despilled), border flood-fill from the dominant border colour (two
    tolerances), an explicit near-white key when the border is bright, and rembg (u2net) -- keeps
    the VALID ones (0.03..0.90 opaque) and returns the one that removed the MOST background. This
    defeats the 'raw white render slips through' failure: a flat light background is always keyed."""
    im = im.convert("RGBA")
    bgcol = _dominant_border_color(im)
    kind = _chroma_kind(bgcol)
    cands = []
    if kind != "neutral":                          # adaptive chroma-key candidate (despilled)
        k = _despill(_border_floodfill_key(im.copy(), bgcol, tol=96))
        f = _opaque_fraction(k)
        if 0.03 < f < 0.90:
            cands.append((f, k))
    for tol in (72, 112):
        k = _border_floodfill_key(im.copy(), bgcol, tol=tol)
        if kind != "neutral":
            k = _despill(k)
        f = _opaque_fraction(k)
        if 0.03 < f < 0.90:
            cands.append((f, k))
    if min(bgcol[:3]) > 208:                      # bright border -> also try a pure-white key
        k = _border_floodfill_key(im.copy(), (255, 255, 255), tol=64)
        f = _opaque_fraction(k)
        if 0.03 < f < 0.90:
            cands.append((f, k))
    try:
        from rembg import remove
        o = remove(im)
        f = _opaque_fraction(o)
        if 0.02 < f < 0.90:
            cands.append((f, o))
    except Exception as e:
        sys.stderr.write(f"[interpret] rembg unavailable: {e}\n")
    if cands:
        cands.sort(key=lambda t: t[0])            # smallest opaque frac = most bg removed
        return cands[0][1]
    return _border_floodfill_key(im.copy(), bgcol, tol=96)   # least-bad fallback


def _has_uncut_background(im):
    """True if the sprite still carries a flat near-white or leftover chroma background block
    (bg-removal failed). Near-white uses a high threshold (>236) so bone/parchment/salt (~224)
    is NOT flagged; gothic props are brown/grey/olive so this only fires on genuine unremoved bg."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_bg(c):
        r, g, b, a = c
        if a < 128:
            return False
        if r > 236 and g > 236 and b > 236:              # near-white
            return True
        if g > 150 and g > r + 40 and g > b + 40:         # chroma green
            return True
        if r > 150 and b > 150 and g < 110:               # chroma magenta
            return True
        return False

    edge_hits = edge_tot = 0
    for x in range(w):
        for y in (1, h - 2):
            edge_tot += 1; edge_hits += is_bg(px[x, y])
    for y in range(h):
        for x in (1, w - 2):
            edge_tot += 1; edge_hits += is_bg(px[x, y])
    bgpix = tot = 0
    for yy in range(0, h, 2):
        for xx in range(0, w, 2):
            tot += 1; bgpix += is_bg(px[xx, yy])
    return (edge_hits / max(1, edge_tot) > 0.14) or (bgpix / max(1, tot) > 0.18)


def alpha_bbox(im, thr=16):
    a = im.split()[3]
    bb = a.point(lambda v: 255 if v >= thr else 0).getbbox()
    return bb


def quantize_gothic(rgb_im, n_colors=24, nudge=0.34):
    """Quantize to a crisp adaptive palette (kills JPEG/anti-alias mush), then gently pull
    each palette entry toward the nearest gothic anchor for library-wide cohesion."""
    q = rgb_im.convert("RGB").quantize(colors=n_colors, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = q.getpalette()[: n_colors * 3]
    newpal = []
    for i in range(0, len(pal), 3):
        c = (pal[i], pal[i + 1], pal[i + 2])
        anchor = min(GOTHIC, key=lambda g: _cdist(c, g))
        newpal.extend(int(round(c[k] * (1 - nudge) + anchor[k] * nudge)) for k in range(3))
    q.putpalette(newpal + pal[len(newpal):])
    return q.convert("RGB")


def _defringe(im):
    """Fill transparent RGB with the average object colour so LANCZOS downscale blends edges
    toward the object (not the chroma/white background) -> no coloured halo after threshold."""
    im = im.convert("RGBA")
    w, h = im.size
    a = im.split()[3]
    mask = a.point(lambda v: 255 if v >= 128 else 0)
    rgb = im.convert("RGB")
    px = rgb.load(); mp = mask.load()
    rs = gs = bs = cnt = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if mp[x, y]:
                r, g, b = px[x, y]; rs += r; gs += g; bs += b; cnt += 1
    fill = (rs // cnt, gs // cnt, bs // cnt) if cnt else (60, 55, 50)
    bg = Image.new("RGB", im.size, fill)
    bg.paste(rgb, (0, 0), mask)
    return Image.merge("RGBA", (*bg.split(), a))


def isolate_fullres(src_im, min_blob_full=48):
    """Cutout + binarize alpha + despeckle at render resolution -> a transparent-bg isolate."""
    im = cutout(src_im.convert("RGBA"))
    a = im.split()[3].point(lambda v: 255 if v >= 128 else 0)
    im = Image.merge("RGBA", (*im.convert("RGB").split(), a))
    return _despeckle(im, min_blob=min_blob_full)


def extract_objects(iso, merge_gap=4, min_area_frac=0.22, min_abs=110):
    """Split an isolate into its ALPHA-CONNECTED-COMPONENT objects (owner: one sprite per cell).
    A MaxFilter dilation of `merge_gap` bridges tiny gaps first, so a boat+resting-oar stay ONE
    object while three separated boats become THREE objects. Returns object crops, largest first."""
    from PIL import ImageFilter
    w, h = iso.size
    binm = iso.split()[3].point(lambda v: 255 if v >= 128 else 0)
    dil = binm.filter(ImageFilter.MaxFilter(2 * merge_gap + 1))
    dp = dil.load(); op = binm.load()
    lab = [0] * (w * h)
    areas = {}
    cur = 0
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if lab[i0] or dp[sx, sy] == 0:
                continue
            cur += 1
            area = 0
            dq = deque([(sx, sy)])
            lab[i0] = cur
            while dq:
                x, y = dq.popleft()
                if op[x, y]:
                    area += 1
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not lab[j] and dp[nx, ny]:
                                lab[j] = cur
                                dq.append((nx, ny))
            areas[cur] = area
    if not areas:
        return []
    maxa = max(areas.values())
    keep = [l for l, ar in areas.items() if ar >= max(min_abs, min_area_frac * maxa)]
    px = iso.load()
    out = []
    for l in keep:
        obj = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ob = obj.load()
        minx = miny = 10 ** 9; maxx = maxy = -1
        for yy in range(h):
            base = yy * w
            for xx in range(w):
                if lab[base + xx] == l and op[xx, yy]:
                    ob[xx, yy] = px[xx, yy]
                    if xx < minx: minx = xx
                    if xx > maxx: maxx = xx
                    if yy < miny: miny = yy
                    if yy > maxy: maxy = yy
        if maxx >= minx:
            out.append((areas[l], obj.crop((minx, miny, maxx + 1, maxy + 1))))
    out.sort(key=lambda t: -t[0])
    return [o for _, o in out]


def _despill(im):
    """Neutralise chroma spill (green/magenta bg tint) on kept pixels — sorceress 'chroma cleanup'.
    Stops a coloured fringe leaking from the keyed background."""
    im = im.convert("RGBA")
    px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if g > r + 16 and g > b + 16:            # green spill
                px[x, y] = (r, max(r, b), b, a)
            elif r > g + 26 and b > g + 26:          # magenta spill
                px[x, y] = (r, min(r, (r + b) // 2), b, a)
    return im


def _object_luma_median(im):
    px = im.load(); w, h = im.size
    lums = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a >= 128:
                lums.append(0.299 * r + 0.587 * g + 0.114 * b)
    if not lums:
        return 128.0
    lums.sort()
    return lums[len(lums) // 2]


def _dehalo(im, passes=2):
    """SORCERESS 'no half-tones' EDGE CLEANUP: iteratively strip silhouette pixels that are
    LIGHT + LOW-SATURATION (the pale bg halo) while PRESERVING dark detail (dark outlines stay).
    Removed pixels go fully outside; survivors stay fully inside — a hard matte edge."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    med = _object_luma_median(im)
    # CONSERVATIVE: only NEAR-WHITE, very-low-saturation edge pixels that are clearly brighter than
    # the object body = true bg halo. Light-but-coloured object edges (pale wood hulls) are KEPT.
    hi = max(206, med + 70)
    for _ in range(passes):
        rem = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                edge = False
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                            edge = True
                            break
                    if edge:
                        break
                if not edge:
                    continue
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                sat = max(r, g, b) - min(r, g, b)
                if lum >= hi and sat < 24:          # near-white low-sat halo -> outside (drop)
                    rem.append((x, y))
        if not rem:
            break
        for x, y in rem:
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)
    return im


def _erode1(im):
    """Remove the outermost 1px opaque ring (owner: 'erode alpha 1px'). Applied only to SOLID
    sprites (guarded) so it never eats thin features (net ropes, crane arm, fence rails)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    rem = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                    rem.append((x, y))
                    break
    for x, y in rem:
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
    return im


def strip_shadow(im):
    """Remove a baked drop-shadow: an opaque low-saturation grey blob in the lower band reading as
    ground-shade under the object. Soft (semi-transparent) shadows are already gone via the hard
    matte; this catches an opaque grey one. Conservative — only lower rows, only low-sat greys with
    little object body directly above them in that column."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    band0 = int(h * 0.60)
    for x in range(w):
        col_top = None
        for y in range(h):
            if px[x, y][3] >= 128:
                col_top = y
                break
        for y in range(band0, h):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            sat = max(r, g, b) - min(r, g, b)
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if sat < 26 and 40 <= lum <= 155 and (col_top is None or y - col_top > int(h * 0.45)):
                px[x, y] = (r, g, b, 0)
    return im


def _keep_largest_component(im):
    """Keep ONLY the largest alpha-connected component (owner: one object per cell). Kills stray
    fragments and detached shadow blobs. NOT used for lacy/porous single objects (nets/fences)."""
    im = im.convert("RGBA")
    w, h = im.size
    a = im.split()[3].load()
    px = im.load()
    seen = bytearray(w * h)
    best = []
    best_sz = 0
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if seen[i0] or a[sx, sy] < 128:
                continue
            comp = []
            dq = deque([(sx, sy)])
            seen[i0] = 1
            while dq:
                x, y = dq.popleft()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            j = ny * w + nx
                            if not seen[j] and a[nx, ny] >= 128:
                                seen[j] = 1
                                dq.append((nx, ny))
            if len(comp) > best_sz:
                best_sz = len(comp)
                best = comp
    keep = set(best)
    for y in range(h):
        for x in range(w):
            if a[x, y] and (x, y) not in keep:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return im


def finish_object(obj, target_px=64, n_colors=24, nudge=0.34, alpha_thr=230, min_blob=8, keep_largest=True):
    """One object -> RAZOR-CLEAN sprite (owner mandate + sorceress 'hard matte / no half-tones'):
      despill -> defringe -> downscale -> quantize+cohesion -> HARD MATTE (alpha<230=0) ->
      conservative de-halo (drop only NEAR-WHITE bg halo, keep the object's own light/dark edges) ->
      despeckle -> keep-largest-component (one object) -> tight trim (+1px margin).
    The hard matte at 230 is what erodes the soft anti-aliased ring — no blind erosion (it ate light
    hulls) and no aggressive shadow-strip (soft shadows die at the matte; detached ones die at
    keep-largest). Binary alpha, no pale fringe, no shadow, one object."""
    bb = alpha_bbox(obj, 128)
    if bb:
        obj = obj.crop(bb)
    obj = _despill(obj)
    obj = _defringe(obj)
    scale = target_px / float(max(obj.size))
    nw, nh = max(1, round(obj.width * scale)), max(1, round(obj.height * scale))
    obj = obj.resize((nw, nh), Image.LANCZOS)
    r, g, b, a = obj.split()
    rgb = quantize_gothic(Image.merge("RGB", (r, g, b)), n_colors=n_colors, nudge=nudge)
    a = a.point(lambda v: 255 if v >= alpha_thr else 0)          # HARD MATTE — no half-tones
    out = Image.merge("RGBA", (*rgb.split(), a))
    out = _dehalo(out, passes=1)
    out = _despeckle(out, min_blob=min_blob)
    if keep_largest:
        out = _keep_largest_component(out)
    bb = alpha_bbox(out, 200)
    if bb:
        out = out.crop(bb)
    pad = Image.new("RGBA", (out.width + 2, out.height + 2), (0, 0, 0, 0))
    pad.alpha_composite(out, (1, 1))
    return pad


def process_render(src_im, target_px=64, n_colors=24, nudge=0.34, work_px=480, split=True):
    """Full spotless pipeline -> a LIST of clean, isolated, single-object sprites.
    Multi-object renders are split (owner: one sprite per cell); each object is independently
    downscaled to target_px so sizing is correct regardless of how the render laid things out."""
    iso = isolate_fullres(src_im)
    if max(iso.size) > work_px:
        s = work_px / float(max(iso.size))
        iso = iso.resize((max(1, int(iso.width * s)), max(1, int(iso.height * s))), Image.LANCZOS)
        r, g, b, a = iso.split()
        iso = Image.merge("RGBA", (r, g, b, a.point(lambda v: 255 if v >= 128 else 0)))
    objs = extract_objects(iso) if split else ([iso.crop(alpha_bbox(iso, 128))] if alpha_bbox(iso, 128) else [])
    return [finish_object(o, target_px, n_colors, nudge) for o in objs]


def clean_sprite(src_im, target_px=64, n_colors=24, nudge=0.34, **_):
    """Back-compat single-sprite entry (returns the largest object) for callers that want one."""
    objs = process_render(src_im, target_px, n_colors, nudge)
    return objs[0] if objs else None


def _despeckle(im, min_blob=6):
    """Drop opaque connected components smaller than min_blob px (orphan fringe/dust)."""
    w, h = im.size
    a = im.split()[3].load()
    px = im.load()
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if seen[i0] or a[sx, sy] == 0:
                continue
            comp = []
            dq = deque([(sx, sy)])
            seen[i0] = 1
            while dq:
                x, y = dq.popleft()
                comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and a[nx, ny] > 0:
                            seen[j] = 1
                            dq.append((nx, ny))
            if len(comp) < min_blob:
                for x, y in comp:
                    r, g, b, _ = px[x, y]
                    px[x, y] = (r, g, b, 0)
    return im


# ========================================================================================
# CLEANLINESS RUBRIC  --  the hard gate before library.json (owner's SPOTLESS bar)
# ========================================================================================
def largest_blob_fraction(im):
    """Fraction of opaque area occupied by the single largest connected component.
    Low value => the sprite is several separate objects (e.g. a row of 3 boats) rather
    than one placeable subject."""
    w, h = im.size
    a = im.split()[3].load()
    seen = bytearray(w * h)
    total = 0
    biggest = 0
    for sy in range(h):
        for sx in range(w):
            if a[sx, sy] < 128:
                continue
            total += 1
            i0 = sy * w + sx
            if seen[i0]:
                continue
            sz = 0
            dq = deque([(sx, sy)])
            seen[i0] = 1
            while dq:
                x, y = dq.popleft()
                sz += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and a[nx, ny] >= 128:
                            seen[j] = 1
                            dq.append((nx, ny))
            biggest = max(biggest, sz)
    return (biggest / total) if total else 0.0


def _fringe_edge_fraction(im):
    """Fraction of silhouette (edge) pixels that are pale/low-saturation HALO — the fringe the owner
    rejected. Low = razor-clean. Preserves dark detail (dark edges are not counted as fringe)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    med = _object_luma_median(im)
    hi = max(206, med + 70)                       # match _dehalo: only near-white halo counts
    edge = fringe = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            is_edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] < 128:
                    is_edge = True
                    break
            if not is_edge:
                continue
            edge += 1
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            sat = max(r, g, b) - min(r, g, b)
            if lum >= hi and sat < 24:
                fringe += 1
    return (fringe / edge) if edge else 0.0


def cleanliness_report(im, require_single_subject=True):
    """Return (passed:bool, scores:dict). Machine half of the verification; a vision pass
    (the montage eyeball) is the perceptual half. `require_single_subject` is disabled for
    intentionally lacy/porous single objects (nets, reeds, fences) whose one true object has
    a naturally low largest-connected-component fraction."""
    im = im.convert("RGBA")
    w, h = im.size
    a = im.split()[3]
    hist = a.histogram()
    n = w * h
    semi = sum(hist[8:248])                 # count of semi-transparent pixels
    opaque = sum(hist[248:])
    frac = opaque / float(n)
    # unique visible colours (proxy for "quantized, not a blurry render")
    rgb = im.convert("RGB")
    vis = Image.composite(rgb, Image.new("RGB", im.size, (255, 0, 255)), a.point(lambda v: 255 if v >= 128 else 0))
    ncolors = len(set(vis.getdata())) if frac > 0 else 0
    # border margin: outermost ring should be empty (=trimmed)
    border_op = 0
    ap = a.load()
    for x in range(w):
        border_op += (ap[x, 0] >= 128) + (ap[x, h - 1] >= 128)
    for y in range(h):
        border_op += (ap[0, y] >= 128) + (ap[w - 1, y] >= 128)
    # palette compatibility: fraction of visible colours within tol of a gothic anchor
    compat = 0
    cols = list(set(vis.getdata())) if frac > 0 else []
    for c in cols:
        if min(_cdist(c, g) for g in GOTHIC) <= 96:
            compat += 1
    compat_frac = compat / len(cols) if cols else 0.0

    blob_frac = largest_blob_fraction(im) if frac > 0 else 0.0
    uncut_bg = _has_uncut_background(im) if frac > 0 else False
    fringe = _fringe_edge_fraction(im) if frac > 0 else 0.0
    checks = {
        "edge_clean_no_halo": semi == 0,                       # strictly binary alpha
        "has_content": 0.02 <= frac <= 0.93,                   # not empty, bg actually removed
        "quantized": 2 <= ncolors <= 96,                       # clean palette, not mush
        "alpha_trimmed": border_op == 0,                       # tight bounds + margin
        "palette_compatible": compat_frac >= 0.45,             # sits in the gothic family
        "single_subject": (blob_frac >= 0.40) or not require_single_subject,
        "no_uncut_background": not uncut_bg,                    # no leftover white/chroma bg block
        "razor_edge": fringe <= 0.06,                          # <=6% of edge is pale halo (owner: zero-fringe)
        # Library-audit round 1 (2026-07-11): dominant defect = tiny fragment
        # shards from the component split (52% of fences_walls, 55% of
        # signage rejected). A real prop is never smaller than half a tile.
        "not_fragment": w >= 16 and h >= 16 and (w * h) >= 400,
    }
    scores = {
        "opaque_fraction": round(frac, 4),
        "semi_transparent_px": semi,
        "n_colors": ncolors,
        "border_opaque_px": border_op,
        "palette_compat_frac": round(compat_frac, 3),
        "largest_blob_frac": round(blob_frac, 3),
        "uncut_background": uncut_bg,
        "fringe_frac": round(fringe, 3),
        "size": [w, h],
    }
    passed = all(checks.values())
    scores["checks"] = checks
    return passed, scores


# ========================================================================================
# GEOMETRY INTERPRETATION  --  #112 machine manifest (grid / rows / facing / feet / bounds)
# ========================================================================================
FACING_BY_ROW = {   # convention for 4-dir sheets, top-to-bottom (LPC-style default)
    4: ["down", "left", "right", "up"],
    1: ["down"],
}


def geometry_manifest(im, grid=None, facing=None):
    """For an animation SHEET: infer/accept a grid, then per-row report frame count,
    feet-line (lowest opaque row within the cell), and per-frame tight bounds.
    grid = (cols, rows) if known; else a single-sprite (prop) manifest is returned."""
    im = im.convert("RGBA")
    W, H = im.size
    if not grid:
        return {"kind": "prop", "size": [W, H], "bounds": alpha_bbox(im, 128), "frames": 1}
    cols, rows = grid
    fw, fh = W // cols, H // rows
    facing = facing or FACING_BY_ROW.get(rows, [f"row{r}" for r in range(rows)])
    rowinfo = []
    for r in range(rows):
        cells = []
        feet = 0
        used = 0
        for c in range(cols):
            cell = im.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
            bb = alpha_bbox(cell, 128)
            if bb:
                used += 1
                feet = max(feet, bb[3])
                cells.append({"frame": c, "bounds": bb})
        rowinfo.append({
            "row": r,
            "facing": facing[r] if r < len(facing) else f"row{r}",
            "frames_used": used,
            "feet_line": feet,
            "cells": cells,
        })
    return {"kind": "sheet", "size": [W, H], "grid": [cols, rows],
            "frame_size": [fw, fh], "rows": rowinfo}


# ========================================================================================
# MONTAGE  --  the human eyeball artifact
# ========================================================================================
def _checker(w, h, s=8):
    bg = Image.new("RGB", (w, h))
    px = bg.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = (58, 54, 60) if ((x // s + y // s) & 1) else (44, 40, 46)
    return bg


def montage(sprites, cols=6, cell=140, title=None):
    """Grid montage of cleaned sprites on a checker so alpha + edges are inspectable.
    Each sprite is nearest-neighbour upscaled to fill the cell (shows the true pixels)."""
    n = len(sprites)
    rows = max(1, math.ceil(n / cols))
    pad = 8
    header = 26 if title else 0
    W = cols * cell + pad * (cols + 1)
    Hh = rows * cell + pad * (rows + 1) + header
    canvas = Image.new("RGBA", (W, Hh), (30, 27, 33, 255))
    for i, sp in enumerate(sprites):
        cx = pad + (i % cols) * (cell + pad)
        cy = header + pad + (i // cols) * (cell + pad)
        tile = _checker(cell, cell).convert("RGBA")
        s = min((cell - 8) / sp.width, (cell - 8) / sp.height)
        nw, nh = max(1, int(sp.width * s)), max(1, int(sp.height * s))
        up = sp.resize((nw, nh), Image.NEAREST)
        tile.alpha_composite(up, ((cell - nw) // 2, (cell - nh) // 2))
        canvas.alpha_composite(tile, (cx, cy))
    return canvas


def animated_strip_montage(frames, scale=4, checker=True):
    """Lay a creature's frames left-to-right at NEAREST scale so a reviewer can see the cycle
    AND the transparent background (checkerboard). Also returns a GIF-ready frame list."""
    if not frames:
        return None, []
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    strip = (_checker(cw * len(frames) * scale, ch * scale).convert("RGBA")
             if checker else Image.new("RGBA", (cw * len(frames) * scale, ch * scale), (30, 27, 33, 255)))
    gif_frames = []
    for i, f in enumerate(frames):
        up = f.resize((f.width * scale, f.height * scale), Image.NEAREST)
        ox = i * cw * scale + (cw * scale - up.width) // 2
        oy = (ch * scale - up.height)
        strip.alpha_composite(up, (ox, oy))
        gf = _checker(cw * scale, ch * scale).convert("RGBA")
        gf.alpha_composite(up, ((cw * scale - up.width) // 2, ch * scale - up.height))
        gif_frames.append(gf.convert("P", palette=Image.ADAPTIVE))
    return strip, gif_frames


# ========================================================================================
# LIBRARY INDEX
# ========================================================================================
ASSETLIB = os.path.join(os.path.dirname(__file__), "..", "..", "_downloads", "_assetlib")
ASSETLIB = os.path.abspath(ASSETLIB)
LIBRARY_JSON = os.path.join(ASSETLIB, "library.json")


def load_library():
    if os.path.exists(LIBRARY_JSON):
        with open(LIBRARY_JSON, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"version": 1, "assets": []}


def save_library(lib):
    os.makedirs(ASSETLIB, exist_ok=True)
    lib["assets"].sort(key=lambda a: (a.get("category", ""), a.get("id", "")))
    lib["count"] = len(lib["assets"])
    with open(LIBRARY_JSON, "w", encoding="utf-8") as f:
        json.dump(lib, f, indent=2)


def library_add(entry):
    lib = load_library()
    lib["assets"] = [a for a in lib["assets"] if a.get("id") != entry["id"]]
    lib["assets"].append(entry)
    save_library(lib)
    return lib["count"] if "count" in lib else len(lib["assets"])


# ========================================================================================
# ANIMATION CALL-THROUGH  --  optional finishing chain for animation batches (sorceress)
# ========================================================================================
def finish_animation_frames(source, cell=64, colors=24, anchor="centroid", **kw):
    """Optional call-through to the animation finishing chain (palette-lock + silhouette downscale +
    hard-edge + anchor-align + temporal de-sparkle) for animation batches, BEFORE the frames are cut.
    Lazily imports anim_finish to avoid a circular import. Returns (finished_frames, report)."""
    import anim_finish as AF
    return AF.finish_animation(source, cell=cell, colors=colors, anchor=anchor, **kw)


# ========================================================================================
# CLI  --  interpret a directory of already-existing PNGs (scouted or generated)
# ========================================================================================
def _cli():
    ap = argparse.ArgumentParser(description="Interpreter Horde: clean + verify + montage + index")
    ap.add_argument("path", help="dir of PNGs or a single PNG")
    ap.add_argument("--category", default="misc")
    ap.add_argument("--source", default="unknown")
    ap.add_argument("--license", default="unverified")
    ap.add_argument("--clean", action="store_true", help="run the spotless cleaner first")
    ap.add_argument("--target-px", type=int, default=64)
    ap.add_argument("--out", default=None, help="verified/<pack> dir (default derives from path)")
    args = ap.parse_args()

    files = [args.path] if args.path.lower().endswith(".png") else sorted(glob.glob(os.path.join(args.path, "*.png")))
    files = [f for f in files if not f.endswith(".import")]
    pack = os.path.basename(os.path.normpath(args.path))
    outdir = args.out or os.path.join(ASSETLIB, "verified", pack)
    os.makedirs(outdir, exist_ok=True)

    passed_sprites, results = [], []
    for f in files:
        im = Image.open(f)
        if args.clean:
            im = clean_sprite(im, target_px=args.target_px)
        ok, scores = cleanliness_report(im)
        results.append({"file": os.path.basename(f), "pass": ok, "scores": scores})
        if ok:
            passed_sprites.append(im)
            aid = f"{pack}__{os.path.splitext(os.path.basename(f))[0]}"
            outp = os.path.join(outdir, os.path.basename(f))
            im.save(outp)
            library_add({
                "id": aid, "category": args.category, "path": os.path.relpath(outp, ASSETLIB),
                "size": scores["size"], "animated": False, "states": [], "frames_per_state": {},
                "facing": "n/a", "biome_fit": [], "source": args.source, "license": args.license,
                "cleanliness": scores, "verdict": "PASS",
            })
        print(f"  {'PASS' if ok else 'FAIL'}  {os.path.basename(f)}  {scores['checks']}")

    if passed_sprites:
        m = montage(passed_sprites, title=pack)
        mp = os.path.join(outdir, f"{pack}_montage.png")
        m.convert("RGB").save(mp)
        print(f"[interpret] montage -> {mp}")
    with open(os.path.join(outdir, "_interpret_report.json"), "w", encoding="utf-8") as fp:
        json.dump(results, fp, indent=2)
    npass = sum(1 for r in results if r["pass"])
    print(f"[interpret] {npass}/{len(results)} PASS in {pack}")


if __name__ == "__main__":
    _cli()
