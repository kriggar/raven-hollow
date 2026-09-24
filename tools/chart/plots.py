"""plots.py - turn the gaps between streets into a town's worth of buildings.

WHY
---
Compared side by side with Watabou's Medieval Fantasy City Generator - the tool
the owner picked as the bar - the single biggest difference was not colour or
frame or texture. It was DENSITY AND IRREGULARITY. That generator packs
thousands of small, varied, non-axis-aligned plots into the blocks its street
network encloses. Every map I had made drew about 1,200 identical axis-aligned
rectangles, which is why they read as a diagram.

So this borrows the method rather than the picture: take the polygons the real
street network encloses, and recursively bisect each one into plots the size of
a burgage, the way a medieval town actually subdivided. The streets are Raven
Hollow's own, so the result still matches the world the player walks through.

The algorithm is the standard one (and is what TownGeneratorOS does):

    subdivide(block):
        if block is small enough: it is a plot
        else: cut it with a line across its LONGEST axis, jittered off centre
              and off perpendicular, and recurse on both halves

Two details do most of the work of making it look hand-made rather than
computed: the cut is never exactly at the midpoint, and it is never exactly
perpendicular. Perfect bisection produces a grid, and a grid reads as a
spreadsheet.
"""

import math
import random

from shapely.geometry import LineString, Polygon, MultiPolygon
from shapely.ops import split, unary_union


def _polys(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, MultiPolygon):
        return list(g.geoms)
    return [p for p in getattr(g, "geoms", []) if isinstance(p, Polygon)]


def _clean(g):
    if g.is_empty:
        return g
    return g if g.is_valid else g.buffer(0)


def _long_axis(poly):
    """Direction and centre of the polygon's longest extent.

    Uses the minimum rotated rectangle, which is what gives a plot its sense of
    fronting a street rather than sitting at an arbitrary angle.
    """
    mrr = poly.minimum_rotated_rectangle
    if not isinstance(mrr, Polygon):
        c = poly.centroid
        return 0.0, (c.x, c.y), 1.0
    cs = list(mrr.exterior.coords)[:4]
    best = None
    for i in range(4):
        x0, y0 = cs[i]
        x1, y1 = cs[(i + 1) % 4]
        d = math.hypot(x1 - x0, y1 - y0)
        if best is None or d > best[0]:
            best = (d, math.atan2(y1 - y0, x1 - x0))
    c = poly.centroid
    return best[1], (c.x, c.y), best[0]


def subdivide(poly, min_area, rng, depth=0, max_depth=9):
    """Recursively bisect a block into plots."""
    if depth >= max_depth or poly.area <= min_area or not poly.is_valid:
        return [poly]
    ang, (cx, cy), length = _long_axis(poly)
    # cut ACROSS the long axis, so plots end up long and narrow like burgages
    cut = ang + math.pi / 2.0
    # never exactly at the middle and never exactly square: perfect bisection
    # makes a grid, and a grid reads as a spreadsheet rather than a town
    off = (rng.random() - 0.5) * 0.34
    cut += (rng.random() - 0.5) * 0.30
    ox = cx + math.cos(ang) * length * off
    oy = cy + math.sin(ang) * length * off
    r = length * 4.0 + 1000.0
    ln = LineString([(ox - math.cos(cut) * r, oy - math.sin(cut) * r),
                     (ox + math.cos(cut) * r, oy + math.sin(cut) * r)])
    try:
        parts = _polys(split(poly, ln))
    except Exception:
        return [poly]
    if len(parts) < 2:
        return [poly]
    out = []
    for p in parts:
        if p.area < min_area * 0.16:
            continue
        out.extend(subdivide(p, min_area, rng, depth + 1, max_depth))
    return out or [poly]


def town_plots(roads, water, town_area, min_area=26000.0, inset=16.0,
               seed=7, keep=0.80):
    """Every building in the town, derived from the gaps between its streets.

    roads      the unioned road network polygon
    water      the unioned water polygon
    town_area  where the town IS - anything outside this is left as country
    min_area   target plot size in world px squared
    inset      how far a building stands back from its plot boundary
    keep       fraction of plots that are actually built on; the rest are
               yards, gardens and gaps, and leaving them out is what stops the
               fabric reading as a solid mat
    """
    rng = random.Random(seed)
    free = _clean(town_area.difference(roads).difference(water))
    plots = []
    for block in _polys(free):
        if block.area < min_area * 0.8:
            continue
        # a block that is a long thin sliver is a verge, not a place to build
        mrr = block.minimum_rotated_rectangle
        if isinstance(mrr, Polygon) and block.area / max(mrr.area, 1.0) < 0.30:
            continue
        for p in subdivide(block, min_area, rng):
            if p.area < min_area * 0.30:
                continue
            if rng.random() > keep:
                continue
            b = p.buffer(-inset, join_style=2)
            for q in _polys(_clean(b)):
                if q.area > min_area * 0.16:
                    plots.append(q.simplify(3.0))
    return plots
