#!/usr/bin/env python3
"""cartograph.py - build the Raven Hollow zone map as real vector cartography.

WHY THIS EXISTS
---------------
Five earlier attempts were rejected. Every one of them hand-rolled its own
rasteriser: a pixel classifier over a screenshot, then GDI+ primitives, then
integer Bresenham in GDScript. That is not how maps are made. A cartographer
does GEOMETRY first - buffer the centreline, union the network, difference the
blocks, simplify the outline - and only then hands finished shapes to a renderer
that knows how to stroke and fill them properly.

So this file uses the tools that exist for exactly this job:

    shapely   real planar geometry: buffer with proper joins and caps,
              unary_union so a road network MERGES at junctions instead of
              stacking overlapping stripes, difference so streets are cut out
              of blocks, simplify (Douglas-Peucker) for generalisation.
    svg       the map is emitted as a vector document with honest paths,
              gradients and pattern fills - not as pixels poked into a buffer.
    resvg     a production SVG renderer. It does the antialiasing, the miter
              joins and the even-odd fills, and it does them correctly.
    pillow    supersample down and, where a pixel-art plate is wanted, quantise.

Input is the geometry dump written by scripts/tools/map_dump.gd (RH_MAPDUMP),
which exports the town's own authored vectors - street centrelines, canals, the
river, field rects, building footprints, trees, walls.

Usage:
    python tools/chart/cartograph.py --geom <town_geom.json> --out <sheet.png>
"""

import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

from shapely.geometry import (LineString, MultiPolygon, Point, Polygon,
                              MultiLineString, box)
from shapely.ops import unary_union
from shapely import affinity

# --------------------------------------------------------------------------
# PALETTE. Warm, desaturated, and built as a value ramp rather than a set of
# hues, so the sheet reads at a squint. Water is the only cool family and it is
# the darkest mass: land and water being the same tan was the single most
# fundamental failure of the rejected versions.
# --------------------------------------------------------------------------
PAL = {
    "paper_hi":   "#f4ecd8",
    "paper":      "#e8dcc0",
    "paper_2":    "#d8c9a4",
    "paper_3":    "#c2ad83",
    "burn":       "#a08a68",
    "ink":        "#2a2018",
    "ink_2":      "#493826",
    "ink_3":      "#6d5738",
    "ink_4":      "#9a8060",
    "built":      "#8d5340",
    "built_hi":   "#a8674f",
    "built_deep":  "#5a2a22",
    "roof_shadow": "#3c2119",
    "water":      "#7d97a4",
    "water_deep": "#4c6577",
    "water_hi":   "#a8bcc4",
    "field":      "#b9bf8c",
    "field_2":    "#a7ae79",
    "wood":       "#5d7049",
    "wood_deep":  "#3f4e32",
    "wood_hi":    "#74874f",
}


def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------
def line(pts):
    return LineString([(p[0], p[1]) for p in pts])


def clean(geom):
    """Repair self-intersections that a naive buffer union can produce."""
    if geom.is_empty:
        return geom
    if not geom.is_valid:
        geom = geom.buffer(0)
    return geom


def to_polys(geom):
    if geom.is_empty:
        return []
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    return [g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)]


def path_d(geom, prec=1):
    """SVG path data for a polygon or multipolygon, holes included."""
    parts = []
    for poly in to_polys(geom):
        for ring in [poly.exterior] + list(poly.interiors):
            cs = list(ring.coords)
            if len(cs) < 3:
                continue
            parts.append("M" + " L".join(
                "%.*f %.*f" % (prec, x, prec, y) for x, y in cs) + " Z")
    return " ".join(parts)


def line_d(geom, prec=1):
    parts = []
    geoms = [geom] if isinstance(geom, LineString) else list(
        getattr(geom, "geoms", []))
    for ls in geoms:
        cs = list(ls.coords)
        if len(cs) < 2:
            continue
        parts.append("M" + " L".join(
            "%.*f %.*f" % (prec, x, prec, y) for x, y in cs))
    return " ".join(parts)


# --------------------------------------------------------------------------
# the map
# --------------------------------------------------------------------------
class Sheet:
    def __init__(self, geom, width_px):
        self.g = geom
        b = geom["bounds"]
        self.W = float(b["w"])
        self.H = float(b["h"])
        self.px = width_px
        self.scale = width_px / self.W
        self.out = []

    # ---- world units are used throughout; the SVG viewBox does the mapping
    def add(self, s):
        self.out.append(s)

    def _wood_from_density(self, trees):
        """Woodland = the top of the tree-density field, not every tree.

        Counts stems into ~200 px cells, blurs the count field so a wood is a
        region rather than a checkerboard, and keeps only cells well above the
        mean. Anything left smaller than a copse is dropped, because a map
        should not draw what it would have to label as "three trees".
        """
        import numpy as np
        if not trees:
            return Polygon()
        cell = 200.0
        nx = int(math.ceil(self.W / cell))
        ny = int(math.ceil(self.H / cell))
        grid = np.zeros((ny, nx), dtype=float)
        for t in trees:
            ix = min(nx - 1, max(0, int(t["x"] / cell)))
            iy = min(ny - 1, max(0, int(t["y"] / cell)))
            grid[iy, ix] += 1.0
        # a 3x3 box blur, twice: turns a stem count into a canopy field
        for _ in range(2):
            pad = np.pad(grid, 1, mode="edge")
            grid = sum(pad[a:a + ny, b:b + nx]
                       for a in range(3) for b in range(3)) / 9.0
        thresh = max(4.0, float(np.percentile(grid[grid > 0], 78)))
        cells = []
        for iy in range(ny):
            for ix in range(nx):
                if grid[iy, ix] >= thresh:
                    cells.append(box(ix * cell, iy * cell,
                                     (ix + 1) * cell, (iy + 1) * cell))
        if not cells:
            return Polygon()
        w = clean(unary_union(cells))
        # round the blocky grid off into something a hand would draw
        w = w.buffer(150, quad_segs=4).buffer(-210, quad_segs=4)
        w = w.buffer(90, quad_segs=4).simplify(30.0)
        keep = [q for q in to_polys(clean(w)) if q.area > 900000.0]
        return unary_union(keep) if keep else Polygon()

    # ------------------------------------------------------------------ build
    def build(self):
        g = self.g
        W, H = self.W, self.H

        # ---- roads: buffer the centreline, then UNION the class so the
        # network merges at every junction. This is the operation that the
        # hand-rolled versions could not do, and it is why their junctions had
        # stacked casings and lollipop stubs.
        major = unary_union([line(s["pts"]).buffer(58, cap_style=2,
                                                   join_style=1)
                             for s in g["streets"] if s.get("class") == "major"
                             and len(s["pts"]) > 1])
        minor = unary_union([line(s["pts"]).buffer(38, cap_style=2,
                                                   join_style=1)
                             for s in g["streets"] if s.get("class") != "major"
                             and len(s["pts"]) > 1])
        roads = clean(unary_union([major, minor]))
        roads = roads.simplify(6.0)

        # ---- water: the river band, the canals, the basin
        waters = []
        for w in g.get("water", []):
            if len(w["pts"]) < 2:
                continue
            half = float(w.get("half", 40))
            if w.get("class") == "river":
                y = w["pts"][0][1]
                waters.append(box(0, y - half, W, H))
            else:
                waters.append(line(w["pts"]).buffer(half, cap_style=2,
                                                   join_style=1))
        for p in g.get("ponds", []):
            waters.append(Point(p["x"], p["y"]).buffer(1.0))
            waters[-1] = affinity.scale(waters[-1], p["rx"], p["ry"])
        water = clean(unary_union(waters)).simplify(5.0)

        # ---- woodland, from DENSITY rather than from presence.
        # The city has 4,328 trees over 7168x5120, a mean spacing of about 44
        # world px, so buffering and unioning them swallows the entire sheet -
        # which is exactly what happened, twice. Street trees and garden trees
        # are not a forest. A wood is where the density is genuinely high, so
        # it is measured on a grid and thresholded well above the mean.
        wood = self._wood_from_density(g.get("trees", []))
        wood = wood.difference(water).difference(roads)

        # ---- fields
        fields = unary_union([box(f["x"], f["y"], f["x"] + f["w"],
                                  f["y"] + f["h"]) for f in g.get("fields", [])])
        fields = clean(fields).difference(water).difference(roads)

        # ---- blocks: union the footprints into terraces, erode so blocks
        # separate, then cut the streets out of them
        foots = []
        for b2 in g.get("buildings", []):
            if b2["w"] > W * 0.4 or b2["h"] > H * 0.4:
                continue
            fh = max(8.0, b2["h"] * 0.68)
            foots.append(box(b2["x"], b2["y"] + b2["h"] - fh,
                             b2["x"] + b2["w"], b2["y"] + b2["h"]))
        for r in g.get("built", []):
            foots.append(box(r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        blocks = clean(unary_union([f.buffer(26, join_style=2) for f in foots]))
        blocks = blocks.buffer(-14, join_style=2).simplify(8.0)
        blocks = blocks.difference(roads).difference(water)

        # ---- the dark anchor: civic mass, authored, and the only place the
        # darkest red is spent
        anchor_rects = [
            (3300, 240, 620, 560),
            (5140, 420, 540, 520),
            (2980, 1020, 900, 230),
            (5180, 2400, 500, 300),
        ]
        anchor = unary_union([box(x, y, x + w, y + h)
                              for x, y, w, h in anchor_rects])
        anchor = clean(anchor).intersection(blocks.buffer(60))
        blocks = blocks.difference(anchor)

        # ---- emit
        self._defs()
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="url(#paper)"/>' % (W, H))
        self._layer(fields, PAL["field"], stroke=PAL["ink_4"], sw=5,
                    pattern="url(#furrow)")
        self._wood(wood)
        self._water(water)
        self._roads(roads, major, minor)
        self._blocks(blocks, anchor)
        self._walls()
        self._frame()
        return self._svg()

    # ------------------------------------------------------------------ defs
    def _defs(self):
        W, H = self.W, self.H
        self.add('<defs>')
        # paper: a warm radial so the eye is told where the light is
        self.add(
            '<radialGradient id="paper" cx="50%%" cy="36%%" r="78%%">'
            '<stop offset="0%%" stop-color="%s"/>'
            '<stop offset="58%%" stop-color="%s"/>'
            '<stop offset="100%%" stop-color="%s"/></radialGradient>'
            % (PAL["paper_hi"], PAL["paper"], PAL["paper_3"]))
        # ridge and furrow for arable, at world scale
        self.add(
            '<pattern id="furrow" width="46" height="46" '
            'patternUnits="userSpaceOnUse" patternTransform="rotate(8)">'
            '<rect width="46" height="46" fill="%s"/>'
            '<rect width="46" height="22" fill="%s" opacity="0.55"/>'
            '</pattern>' % (PAL["field"], PAL["field_2"]))
        # canopy: a dense stipple so a wood has texture without 4,000 sprites
        self.add(
            '<pattern id="canopy" width="58" height="58" '
            'patternUnits="userSpaceOnUse">'
            '<rect width="58" height="58" fill="%s"/>'
            '<circle cx="15" cy="15" r="13" fill="%s" opacity="0.85"/>'
            '<circle cx="44" cy="30" r="15" fill="%s" opacity="0.75"/>'
            '<circle cx="24" cy="46" r="12" fill="%s" opacity="0.8"/>'
            '<circle cx="12" cy="12" r="5" fill="%s" opacity="0.5"/>'
            '<circle cx="41" cy="27" r="6" fill="%s" opacity="0.45"/>'
            '</pattern>' % (PAL["wood"], PAL["wood_deep"], PAL["wood_deep"],
                            PAL["wood_deep"], PAL["wood_hi"], PAL["wood_hi"]))
        # ruled water
        self.add(
            '<pattern id="ripple" width="120" height="64" '
            'patternUnits="userSpaceOnUse">'
            '<rect width="120" height="64" fill="%s"/>'
            '<path d="M0 20 q30 -9 60 0 t60 0" stroke="%s" stroke-width="4" '
            'fill="none" opacity="0.30"/>'
            '<path d="M0 48 q30 -9 60 0 t60 0" stroke="%s" stroke-width="4" '
            'fill="none" opacity="0.22"/>'
            '</pattern>' % (PAL["water"], PAL["water_hi"], PAL["water_hi"]))
        # the vignette that seats the sheet on a dark table
        self.add(
            '<radialGradient id="burn" cx="50%%" cy="50%%" r="72%%">'
            '<stop offset="62%%" stop-color="%s" stop-opacity="0"/>'
            '<stop offset="100%%" stop-color="%s" stop-opacity="0.55"/>'
            '</radialGradient>' % (PAL["burn"], PAL["burn"]))
        self.add('</defs>')

    # ------------------------------------------------------------------ parts
    def _layer(self, geom, fill, stroke=None, sw=0, pattern=None, op=1.0):
        d = path_d(geom)
        if not d:
            return
        f = pattern if pattern else fill
        s = ' stroke="%s" stroke-width="%d" stroke-linejoin="round"' % (
            stroke, sw) if stroke else ''
        self.add('<path d="%s" fill="%s" fill-rule="evenodd" opacity="%.2f"%s/>'
                 % (d, f, op, s))

    def _wood(self, wood):
        d = path_d(wood)
        if not d:
            return
        # the cast shadow is what makes a canopy stand up off the ground
        self.add('<g transform="translate(26,30)">'
                 '<path d="%s" fill="%s" fill-rule="evenodd" opacity="0.30"/></g>'
                 % (d, PAL["ink"]))
        self.add('<path d="%s" fill="url(#canopy)" fill-rule="evenodd"/>' % d)
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="5" '
                 'stroke-linejoin="round" opacity="0.55"/>' % (d, PAL["wood_deep"]))

    def _water(self, water):
        d = path_d(water)
        if not d:
            return
        # a lighter shelf inside the bank, then the bank itself: the clearest
        # signal that a body of water has an edge
        self.add('<path d="%s" fill="url(#ripple)" fill-rule="evenodd"/>' % d)
        inner = clean(water.buffer(-46))
        di = path_d(inner)
        if di:
            self.add('<path d="%s" fill="%s" fill-rule="evenodd" opacity="0.72"/>'
                     % (di, PAL["water_deep"]))
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="7" '
                 'stroke-linejoin="round"/>' % (d, PAL["ink"]))

    def _roads(self, roads, major, minor):
        d = path_d(roads)
        if not d:
            return
        # casing then carriageway. Because the network was unioned first, the
        # casing is the OUTLINE of the whole network and therefore breaks
        # correctly at every junction instead of drawing across it.
        self.add('<path d="%s" fill="%s" fill-rule="evenodd" stroke="%s" '
                 'stroke-width="12" stroke-linejoin="round"/>'
                 % (d, PAL["paper_hi"], PAL["ink_2"]))
        dm = path_d(clean(major).simplify(6.0))
        if dm:
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="3" '
                     'stroke-dasharray="26 22" opacity="0.35"/>'
                     % (dm, PAL["ink_3"]))
        for t in self.g.get("tracks", []):
            if len(t["pts"]) < 2:
                continue
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="7" '
                     'stroke-dasharray="22 18" stroke-linecap="butt"/>'
                     % (line_d(line(t["pts"]).simplify(8.0)), PAL["ink_4"]))

    def _blocks(self, blocks, anchor):
        d = path_d(blocks)
        if d:
            self.add('<g transform="translate(14,18)">'
                     '<path d="%s" fill="%s" fill-rule="evenodd" opacity="0.38"/></g>'
                     % (d, PAL["roof_shadow"]))
            self.add('<path d="%s" fill="%s" fill-rule="evenodd" stroke="%s" '
                     'stroke-width="6" stroke-linejoin="round"/>'
                     % (d, PAL["built"], PAL["ink"]))
        da = path_d(anchor)
        if da:
            self.add('<g transform="translate(16,20)">'
                     '<path d="%s" fill="%s" fill-rule="evenodd" opacity="0.45"/></g>'
                     % (da, PAL["ink"]))
            self.add('<path d="%s" fill="%s" fill-rule="evenodd" stroke="%s" '
                     'stroke-width="7" stroke-linejoin="round"/>'
                     % (da, PAL["built_deep"], PAL["ink"]))

    def _walls(self):
        W, H = self.W, self.H
        runs = [[(104, 136), (7064, 136)],
                [(104, 5080), (7064, 5080)],
                [(40, 136), (40, 5080)]]
        for r in runs:
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="22" '
                     'stroke-linecap="square"/>' % (line_d(line(r)), PAL["ink"]))
        gy = 2600.0
        for seg in [[(7064, 136), (7064, gy - 150)],
                    [(7064, gy + 150), (7064, 5080)]]:
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="22" '
                     'stroke-linecap="square"/>' % (line_d(line(seg)), PAL["ink"]))
        for cx, cy in [(104, 136), (7064, 136), (104, 5080), (7064, 5080),
                       (7064, gy - 150), (7064, gy + 150)]:
            self.add('<circle cx="%d" cy="%d" r="40" fill="%s"/>'
                     % (cx, cy, PAL["ink"]))

    def _frame(self):
        W, H = self.W, self.H
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="url(#burn)"/>'
                 % (W, H))
        # A drawn sheet has a margin. Without one the props sitting on the
        # world''s edge print into the frame and the map reads as a crop.
        m = 120.0
        self.add('<path d="M0 0 H%.0f V%.0f H0 Z M%.0f %.0f H%.0f V%.0f H%.0f Z" '
                 'fill="%s" fill-rule="evenodd"/>'
                 % (W, H, m, m, W - m, H - m, m, PAL["paper"]))
        self.add('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" '
                 'stroke="%s" stroke-width="10"/>'
                 % (m * 0.55, m * 0.55, W - m * 1.1, H - m * 1.1, PAL["ink"]))
        self.add('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" '
                 'stroke="%s" stroke-width="4"/>'
                 % (m * 0.82, m * 0.82, W - m * 1.64, H - m * 1.64, PAL["ink_3"]))

    def _svg(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
                'viewBox="0 0 %.0f %.0f">\n%s\n</svg>\n'
                % (self.px, int(round(self.px * self.H / self.W)),
                   self.W, self.H, "\n".join(self.out)))


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geom", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=1680)
    ap.add_argument("--super", type=int, default=2,
                    help="supersample factor; the render is downsampled with "
                         "Lanczos, which is what gives clean edges")
    ap.add_argument("--resvg", default="")
    args = ap.parse_args()

    geom = json.loads(Path(args.geom).read_text(encoding="utf-8"))
    sheet = Sheet(geom, args.width * args.super)
    svg = sheet.build()

    svg_path = Path(args.out).with_suffix(".svg")
    svg_path.parent.mkdir(parents=True, exist_ok=True)
    svg_path.write_text(svg, encoding="utf-8")
    print("svg   %s  (%d KB)" % (svg_path, len(svg) // 1024))

    resvg = args.resvg or os.environ.get("RESVG", "resvg")
    big = Path(args.out).with_name(Path(args.out).stem + "_big.png")
    r = subprocess.run([resvg, str(svg_path), str(big)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print("resvg failed:", r.stderr[:800])
        sys.exit(1)

    from PIL import Image
    im = Image.open(big).convert("RGB")
    if args.super > 1:
        im = im.resize((im.width // args.super, im.height // args.super),
                       Image.LANCZOS)
    im.save(args.out)
    big.unlink(missing_ok=True)
    print("png   %s  %dx%d" % (args.out, im.width, im.height))

    # report the value plan the critiques measured us on
    import numpy as np
    a = np.asarray(im).astype(float)
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    q = np.percentile(lum, [25, 50, 75])
    print("lum   p25=%.0f p50=%.0f p75=%.0f  iqr span=%.0f (want >= 28)"
          % (q[0], q[1], q[2], q[2] - q[0]))
    print("dark  %.1f%% below L80 (want a real dark mass, not confetti)"
          % (100.0 * (lum < 80).mean()))


if __name__ == "__main__":
    main()
