#!/usr/bin/env python3
"""cartograph.py - the Raven Hollow zone map, painted in the game's own colours.

WHY THIS VERSION EXISTS
-----------------------
Five maps were rejected. Asked what was wrong, the owner's answer was
"it doesn't look like the game", and the measurement backs that up exactly:

    tools/chart/palette_from_game.py reads the actual sprites and reports the
    mean of all the game's art as #654936 - hue 24 degrees, saturation 30%,
    LIGHTNESS 31%.

Every map I had made was light parchment at roughly 85% lightness. It was not a
question of style; the sheet was in a different colour world from the game it
described. So this file takes its whole palette from that measurement:

    roof     #6c483c   with #301824 in shadow and #9c7848 catching the light
    wall     #785448 / #483024
    foliage  #6c6c18   with #54540c under and #848430 on top
    grass    #6c6c18
    road     #84543c / #6c3c24
    water    #487884 / #24546c

and it is a WoW-style ZONE MAP: painted terrain, relief from a consistent
upper-left light, roads as warm ribbons, and - the thing that makes a town read
as a town rather than as a diagram - every building drawn as a ROOF with a
ridge and two slopes, in the game's roof browns.

Geometry is done properly with Shapely (buffer, unary_union, difference,
simplify), the document is emitted as SVG, and resvg renders it. See
tools/chart/README.md.
"""

import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

from shapely.geometry import LineString, MultiPolygon, Point, Polygon, box
from shapely.ops import unary_union
from shapely import affinity

# the embeddable Python ignores PYTHONPATH, so the sibling module is added
# to the path explicitly rather than relying on the environment
sys.path.insert(0, str(Path(__file__).resolve().parent))
from plots import town_plots

# --------------------------------------------------------------------------
# THE PALETTE, measured from the game's own sprites. Do not invent colours
# here; run palette_from_game.py and use what it reports.
# --------------------------------------------------------------------------
PAL = {
    # ground
    "grass":      "#6c6c18",
    "grass_hi":   "#848430",
    "grass_lo":   "#54540c",
    "earth":      "#84543c",
    "earth_lo":   "#6c3c24",
    "earth_hi":   "#9c7848",
    # woodland
    "wood":       "#54540c",
    "wood_hi":    "#6f7a1e",
    "wood_lo":    "#34380c",
    # water
    "water":      "#487884",
    "water_deep": "#24546c",
    "water_hi":   "#6a9aa4",
    # built
    "roof":       "#6b3a2c",
    "roof_hi":    "#a8654a",
    "roof_lo":    "#2a1418",
    "wall":       "#785448",
    "civic":      "#54483c",
    "civic_hi":   "#84684c",
    # ink and chrome
    "ink":        "#1c1410",
    "ink_2":      "#301824",
    "parch":      "#c8b48c",
    "parch_lo":   "#9c7848",
    "parch_hi":   "#e0cca4",
}


# --------------------------------------------------------------------------
# THE GAME'S OWN TERRAIN, used as the map's fill.
#
# The owner's one-line verdict on five rejected maps was "it doesn't look like
# the game". Flat SVG colour never will, however well the hue is matched,
# because the game's ground is TEXTURED pixel art. So the ground, the woods,
# the roads and the water are filled with the actual tiles out of
# assets/art/terrain/lpc_terrain_v7.png - the same sheet TerrainPainter uses to
# paint the world - embedded in the document and drawn with nearest-neighbour
# so they stay pixels instead of turning to mush.
#
# Coordinates are the CENTRE tile of each 3x3 autotile block, which is the
# solid fill for that material.
# --------------------------------------------------------------------------
TILE = 32
TILES = {
    "grass":  (1, 10),
    "grass2": (4, 10),
    "wood":   (7, 10),
    "earth":  (10, 10),
    "earth2": (13, 10),
    "stone":  (25, 10),
    "water":  (22, 19),
    "water2": (1, 19),
    "sand":   (16, 10),
}
_TILE_CACHE = {}


def tile_uri(name, root):
    """A terrain tile from the game's sheet, as a base64 PNG data URI."""
    import base64
    import io
    if name in _TILE_CACHE:
        return _TILE_CACHE[name]
    from PIL import Image
    sheet = Path(root) / "assets" / "art" / "terrain" / "lpc_terrain_v7.png"
    col, row = TILES[name]
    im = Image.open(sheet).convert("RGBA")
    t = im.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
    buf = io.BytesIO()
    t.save(buf, format="PNG")
    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    _TILE_CACHE[name] = uri
    return uri


def line(pts):
    return LineString([(p[0], p[1]) for p in pts])


def clean(g):
    if g.is_empty:
        return g
    return g if g.is_valid else g.buffer(0)


def to_polys(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, MultiPolygon):
        return list(g.geoms)
    return [q for q in getattr(g, "geoms", []) if isinstance(q, Polygon)]


def path_d(g, prec=1):
    parts = []
    for poly in to_polys(g):
        for ring in [poly.exterior] + list(poly.interiors):
            cs = list(ring.coords)
            if len(cs) < 3:
                continue
            parts.append("M" + " L".join("%.*f %.*f" % (prec, x, prec, y)
                                         for x, y in cs) + " Z")
    return " ".join(parts)


def line_d(g, prec=1):
    parts = []
    geoms = [g] if isinstance(g, LineString) else list(getattr(g, "geoms", []))
    for ls in geoms:
        cs = list(ls.coords)
        if len(cs) >= 2:
            parts.append("M" + " L".join("%.*f %.*f" % (prec, x, prec, y)
                                         for x, y in cs))
    return " ".join(parts)


class Sheet:
    def __init__(self, geom, width_px, root):
        self.root = root
        self.g = geom
        b = geom["bounds"]
        self.W = float(b["w"])
        self.H = float(b["h"])
        self.px = width_px
        self.out = []

    def add(self, s):
        self.out.append(s)

    # ------------------------------------------------------------------ woods
    def _wood_from_density(self, trees):
        """Woodland is the top of the tree-DENSITY field, never every tree.

        4,328 trees at a mean spacing of 44 world px: buffering and unioning
        them swallows the whole sheet, which happened twice. Street trees and
        garden trees are not a forest.
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
        for _ in range(2):
            pad = np.pad(grid, 1, mode="edge")
            grid = sum(pad[a:a + ny, b:b + nx]
                       for a in range(3) for b in range(3)) / 9.0
        thresh = max(4.0, float(np.percentile(grid[grid > 0], 74)))
        cells = [box(ix * cell, iy * cell, (ix + 1) * cell, (iy + 1) * cell)
                 for iy in range(ny) for ix in range(nx)
                 if grid[iy, ix] >= thresh]
        if not cells:
            return Polygon()
        w = clean(unary_union(cells))
        w = w.buffer(150, quad_segs=4).buffer(-210, quad_segs=4)
        w = w.buffer(90, quad_segs=4).simplify(30.0)
        keep = [q for q in to_polys(clean(w)) if q.area > 700000.0]
        return unary_union(keep) if keep else Polygon()

    # ------------------------------------------------------------------ build
    def build(self):
        g = self.g
        W, H = self.W, self.H

        major = unary_union([line(s["pts"]).buffer(56, cap_style=2, join_style=1)
                             for s in g["streets"]
                             if s.get("class") == "major" and len(s["pts"]) > 1])
        minor = unary_union([line(s["pts"]).buffer(36, cap_style=2, join_style=1)
                             for s in g["streets"]
                             if s.get("class") != "major" and len(s["pts"]) > 1])
        roads = clean(unary_union([major, minor])).simplify(6.0)

        waters = []
        for w in g.get("water", []):
            if len(w["pts"]) < 2:
                continue
            half = float(w.get("half", 40))
            if w.get("class") == "river":
                waters.append(box(0, w["pts"][0][1] - half, W, H))
            else:
                waters.append(line(w["pts"]).buffer(half, cap_style=2,
                                                    join_style=1))
        for p in g.get("ponds", []):
            waters.append(affinity.scale(Point(p["x"], p["y"]).buffer(1.0),
                                         p["rx"], p["ry"]))
        water = clean(unary_union(waters)).simplify(5.0)

        wood = self._wood_from_density(g.get("trees", []))
        wood = wood.difference(water)

        fields = unary_union([box(f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])
                              for f in g.get("fields", [])])
        fields = clean(fields).difference(water).difference(roads)

        self._defs()
        self._ground(fields, roads)
        self._wood(wood)
        self._water(water)
        self._roads(roads)
        self._buildings(roads, water)
        self._walls()
        self._chrome()
        return self._svg()

    # ------------------------------------------------------------------- defs
    def _tile_pattern(self, pid, name, span, tint=None, op=1.0):
        """A pattern that repeats one game tile every `span` WORLD px.

        The tile is 32 px of world art; at map scale that is about five output
        pixels, which reads as noise. Blowing it up to `span` keeps the texture
        legible as texture while staying the game's own art.
        """
        uri = tile_uri(name, self.root)
        extra = ('<rect width="%d" height="%d" fill="%s" opacity="%.2f"/>'
                 % (span, span, tint, op)) if tint else ""
        self.add('<pattern id="%s" width="%d" height="%d" '
                 'patternUnits="userSpaceOnUse">'
                 '<image href="%s" x="0" y="0" width="%d" height="%d" '
                 'image-rendering="pixelated"/>%s</pattern>'
                 % (pid, span, span, uri, span, span, extra))

    def _defs(self):
        self.add("<defs>")
        self._tile_pattern("t_grass", "grass", 104)
        self._tile_pattern("t_wood", "wood", 128)
        self._tile_pattern("t_earth", "earth", 96)
        self._tile_pattern("t_water", "water", 112)
        self._tile_pattern("t_stone", "stone", 88)
        # the ground is olive and DARK, like the game. The light comes from the
        # upper left and everything on the sheet is lit by it.
        self.add(
            '<radialGradient id="ground" cx="42%%" cy="30%%" r="86%%">'
            '<stop offset="0%%" stop-color="%s"/>'
            '<stop offset="55%%" stop-color="%s"/>'
            '<stop offset="100%%" stop-color="%s"/></radialGradient>'
            % (PAL["grass_hi"], PAL["grass"], PAL["grass_lo"]))
        self.add(
            '<pattern id="canopy" width="150" height="150" '
            'patternUnits="userSpaceOnUse">'
            '<rect width="150" height="150" fill="%s"/>'
            '<circle cx="38" cy="40" r="34" fill="%s"/>'
            '<circle cx="34" cy="34" r="22" fill="%s"/>'
            '<circle cx="104" cy="70" r="38" fill="%s"/>'
            '<circle cx="98" cy="62" r="24" fill="%s"/>'
            '<circle cx="60" cy="116" r="32" fill="%s"/>'
            '<circle cx="55" cy="110" r="20" fill="%s"/>'
            '<circle cx="128" cy="18" r="24" fill="%s"/>'
            '</pattern>'
            % (PAL["wood_lo"], PAL["wood"], PAL["wood_hi"], PAL["wood"],
               PAL["wood_hi"], PAL["wood"], PAL["wood_hi"], PAL["wood"]))
        self.add(
            '<linearGradient id="deep" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0%%" stop-color="%s"/>'
            '<stop offset="100%%" stop-color="%s"/></linearGradient>'
            % (PAL["water"], PAL["water_deep"]))
        self.add(
            '<pattern id="furrow" width="70" height="70" '
            'patternUnits="userSpaceOnUse" patternTransform="rotate(9)">'
            '<rect width="70" height="70" fill="%s"/>'
            '<rect width="70" height="34" fill="%s" opacity="0.5"/>'
            '</pattern>' % (PAL["earth"], PAL["earth_lo"]))
        self.add(
            '<radialGradient id="vig" cx="50%%" cy="48%%" r="74%%">'
            '<stop offset="52%%" stop-color="#000000" stop-opacity="0"/>'
            '<stop offset="100%%" stop-color="#000000" stop-opacity="0.45"/>'
            '</radialGradient>')
        self.add("</defs>")

    # ----------------------------------------------------------------- layers
    def _ground(self, fields, roads):
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="url(#t_grass)"/>'
                 % (self.W, self.H))
        # the painted light over the real texture, not instead of it
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="url(#ground)" '
                 'opacity="0.22"/>' % (self.W, self.H))
        d = path_d(fields)
        if d:
            self.add('<path d="%s" fill="url(#furrow)" fill-rule="evenodd" '
                     'opacity="0.85"/>' % d)
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="5" '
                     'opacity="0.5"/>' % (d, PAL["ink_2"]))

    def _wood(self, wood):
        d = path_d(wood)
        if not d:
            return
        # a wood without a cast shadow is a green rug. Offset down-right,
        # because the light on this sheet comes from the upper left and every
        # other element obeys the same rule.
        self.add('<g transform="translate(34,42)"><path d="%s" fill="#000" '
                 'fill-rule="evenodd" opacity="0.38"/></g>' % d)
        self.add('<path d="%s" fill="url(#t_wood)" fill-rule="evenodd"/>' % d)
        self.add('<path d="%s" fill="url(#canopy)" fill-rule="evenodd" '
                 'opacity="0.55"/>' % d)
        # a lit rim along the north-west edge
        self.add('<g transform="translate(-10,-12)"><path d="%s" fill="none" '
                 'stroke="%s" stroke-width="12" opacity="0.30" '
                 'stroke-linejoin="round"/></g>' % (d, PAL["wood_hi"]))

    def _water(self, water):
        d = path_d(water)
        if not d:
            return
        self.add('<path d="%s" fill="url(#t_water)" fill-rule="evenodd"/>' % d)
        self.add('<path d="%s" fill="url(#deep)" fill-rule="evenodd" '
                 'opacity="0.45"/>' % d)
        shal = clean(water.buffer(-70))
        ds = path_d(shal)
        if ds:
            self.add('<path d="%s" fill="%s" fill-rule="evenodd" opacity="0.55"/>'
                     % (ds, PAL["water_deep"]))
        # the lit shoreline, then the bank
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="9" '
                 'opacity="0.55" stroke-linejoin="round"/>' % (d, PAL["water_hi"]))
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="5" '
                 'stroke-linejoin="round"/>' % (d, PAL["ink"]))

    def _roads(self, roads):
        d = path_d(roads)
        if not d:
            return
        # warm packed earth, lighter than the ground so the eye follows it -
        # which is what a road is FOR on a zone map
        self.add('<g transform="translate(6,8)"><path d="%s" fill="#000" '
                 'fill-rule="evenodd" opacity="0.30"/></g>' % d)
        self.add('<path d="%s" fill="url(#t_earth)" fill-rule="evenodd"/>' % d)
        inner = clean(roads.buffer(-12))
        di = path_d(inner)
        if di:
            # a bright dry core. Roads and roofs are both brown here, so the
            # road has to win on VALUE or the town reads as one brown mass.
            self.add('<path d="%s" fill="%s" fill-rule="evenodd"/>'
                     % (di, PAL["earth_hi"]))
            self.add('<path d="%s" fill="#d8bc90" fill-rule="evenodd" '
                     'opacity="0.35"/>' % di)
        self.add('<path d="%s" fill="none" stroke="%s" stroke-width="4" '
                 'opacity="0.75" stroke-linejoin="round"/>' % (d, PAL["ink_2"]))
        for t in self.g.get("tracks", []):
            if len(t["pts"]) > 1:
                self.add('<path d="%s" fill="none" stroke="%s" stroke-width="12" '
                         'stroke-dasharray="34 26" opacity="0.5"/>'
                         % (line_d(line(t["pts"]).simplify(8.0)), PAL["earth_lo"]))

    # -------------------------------------------------------------- buildings
    def _buildings(self, roads, water):
        """Every building is drawn as a ROOF: a ridge with two slopes, lit from
        the upper left, in the game's own roof browns. A flat rectangle is what
        made five maps look like a diagram - a pitched roof with a ridge line
        reads as a building instantly, even at 25 px.
        """
        civic = [box(3300, 240, 3920, 800), box(5140, 420, 5680, 940),
                 box(2980, 1020, 3880, 1250), box(5180, 2400, 5680, 2700)]
        civic_u = unary_union(civic)

        # WHERE the town is: a generous hull around the real footprints.
        # Outside it the land stays country, which is what gives a town an edge.
        seeds = [box(b["x"], b["y"], b["x"] + b["w"], b["y"] + b["h"])
                 for b in self.g.get("buildings", [])
                 if b["w"] < self.W * 0.4 and b["h"] < self.H * 0.4]
        seeds += [box(r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
                  for r in self.g.get("built", [])]
        # tight, not generous: a hull that reaches 190 px past every outlying
        # barn spreads the town over the commons and the woods, which is what
        # the first pass did. Grow just enough to close the gaps between
        # neighbours, then pull most of it back.
        town = clean(unary_union([q.buffer(150, join_style=2) for q in seeds]))
        town = town.buffer(-118, join_style=2).simplify(24.0)

        # PLOTS, NOT RECTANGLES. Set beside Watabou's generator - the bar the
        # owner picked - the decisive difference was never palette or frame. It
        # was that a real city map packs thousands of small IRREGULAR plots into
        # the blocks its streets enclose, while every map I had made drew about
        # 1,200 identical axis-aligned boxes. Same method here, our streets.
        # a plot about 90 world px across, which is 15 px on the finished
        # sheet - the size Watabou's generator draws a house at
        plots = town_plots(roads, water, town, min_area=8200.0, inset=9.0,
                           seed=7, keep=0.86)
        print("plots %d" % len(plots))

        shadows = []
        roofs = []
        for poly in sorted(plots, key=lambda q: q.bounds[3]):
            x0, y0, x1, y1 = poly.bounds
            w, h = x1 - x0, y1 - y0
            if w < 24 or h < 24:
                continue
            is_civic = civic_u.intersects(poly)
            c_mid = PAL["civic"] if is_civic else PAL["roof"]
            c_hi = PAL["civic_hi"] if is_civic else PAL["roof_hi"]
            d = path_d(poly)
            if not d:
                continue
            shadows.append('<path d="%s" fill="#000" opacity="0.42"/>'
                           % path_d(affinity.translate(poly, 13, 16)))
            roofs.append('<path d="%s" fill="%s"/>' % (d, c_mid))
            # the sunward slope: the plot cut in half across its long axis, so
            # the ridge follows the building rather than the page
            if w >= h:
                half = poly.intersection(box(x0, y0, x1, (y0 + y1) * 0.5))
            else:
                half = poly.intersection(box(x0, y0, (x0 + x1) * 0.5, y1))
            dh = path_d(clean(half))
            if dh:
                roofs.append('<path d="%s" fill="%s"/>' % (dh, c_hi))
            roofs.append('<path d="%s" fill="none" stroke="%s" stroke-width="4" '
                         'stroke-linejoin="round"/>' % (d, PAL["ink"]))
        self.add('<g>%s</g>' % "".join(shadows))
        self.add('<g>%s</g>' % "".join(roofs))

    def _walls(self):
        runs = [[(104, 136), (7064, 136)], [(104, 5080), (7064, 5080)],
                [(40, 136), (40, 5080)],
                [(7064, 136), (7064, 2450)], [(7064, 2750), (7064, 5080)]]
        for r in runs:
            self.add('<path d="%s" fill="none" stroke="#000" stroke-width="30" '
                     'opacity="0.35" transform="translate(8,10)" '
                     'stroke-linecap="square"/>' % line_d(line(r)))
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="26" '
                     'stroke-linecap="square"/>' % (line_d(line(r)), PAL["wall"]))
            self.add('<path d="%s" fill="none" stroke="%s" stroke-width="8" '
                     'stroke-linecap="square" opacity="0.8"/>'
                     % (line_d(line(r)), PAL["ink"]))
        for cx, cy in [(104, 136), (7064, 136), (104, 5080), (7064, 5080),
                       (7064, 2450), (7064, 2750)]:
            self.add('<circle cx="%d" cy="%d" r="52" fill="%s" stroke="%s" '
                     'stroke-width="8"/>' % (cx, cy, PAL["wall"], PAL["ink"]))

    def _chrome(self):
        W, H = self.W, self.H
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="url(#vig)"/>'
                 % (W, H))
        # a parchment border around a dark map, which is the WoW arrangement
        m = 108.0
        self.add('<path d="M0 0 H%.0f V%.0f H0 Z M%.0f %.0f H%.0f V%.0f H%.0f Z" '
                 'fill="%s" fill-rule="evenodd"/>'
                 % (W, H, m, m, W - m, H - m, m, PAL["parch"]))
        self.add('<rect x="0" y="0" width="%.0f" height="%.0f" fill="none" '
                 'stroke="%s" stroke-width="26"/>' % (W, H, PAL["parch_lo"]))
        self.add('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" '
                 'stroke="%s" stroke-width="9"/>'
                 % (m - 14, m - 14, W - (m - 14) * 2, H - (m - 14) * 2, PAL["ink"]))
        self.add('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" '
                 'stroke="%s" stroke-width="4" opacity="0.7"/>'
                 % (m - 40, m - 40, W - (m - 40) * 2, H - (m - 40) * 2,
                    PAL["parch_hi"]))

    def _svg(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
                'viewBox="0 0 %.0f %.0f">\n%s\n</svg>\n'
                % (self.px, int(round(self.px * self.H / self.W)),
                   self.W, self.H, "\n".join(self.out)))


def grade(im, target_mean=79.0):
    """Final colour grade, aimed at a measured target rather than at taste.

    A zone map has to be BRIGHTER and more saturated than the world it
    describes, because it is read at a glance and at a quarter of the size.
    Rendered straight, this sheet measured a mean luminance of 56 against the
    game art's 79 - it was correct in hue and wrong in exposure, which reads as
    muddy. So: lift the midtones with a gamma solved to hit the target, widen
    the range with a mild S-curve, and put back the saturation that averaging
    always costs.
    """
    import numpy as np
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    cur = float(lum.mean()) * 255.0
    if cur > 1.0:
        # solve gamma so the mean lands on target
        gamma = math.log(max(target_mean, 1.0) / 255.0) / math.log(
            max(cur, 1.0) / 255.0)
        gamma = min(max(gamma, 0.45), 1.6)
        a = np.power(a, gamma)
    # gentle S-curve for separation
    a = np.clip(a, 0.0, 1.0)
    a = a * a * (3.0 - 2.0 * a) * 0.30 + a * 0.70
    # saturation back up
    l2 = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2])[..., None]
    # 1.28 pushed the game's muted olive into a bright grass green. The point
    # of the grade is exposure, not a different colour world.
    a = np.clip(l2 + (a - l2) * 1.04, 0.0, 1.0)
    from PIL import Image
    return Image.fromarray((a * 255.0 + 0.5).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geom", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=1194)
    ap.add_argument("--super", type=int, default=3)
    ap.add_argument("--resvg", default="")
    args = ap.parse_args()

    geom = json.loads(Path(args.geom).read_text(encoding="utf-8"))
    root = Path(__file__).resolve().parents[2]
    svg = Sheet(geom, args.width * args.super, root).build()
    svg_path = Path(args.out).with_suffix(".svg")
    svg_path.parent.mkdir(parents=True, exist_ok=True)
    svg_path.write_text(svg, encoding="utf-8")
    print("svg   %s  (%d KB)" % (svg_path, len(svg) // 1024))

    resvg = args.resvg or os.environ.get("RESVG", "resvg")
    big = Path(args.out).with_name(Path(args.out).stem + "_big.png")
    r = subprocess.run([resvg, str(svg_path), str(big)], capture_output=True,
                       text=True)
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

    im = grade(im, target_mean=74.0)
    im.save(args.out)

    import numpy as np
    a = np.asarray(im).astype(float)
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    q = np.percentile(lum, [25, 50, 75])
    print("lum   p25=%.0f p50=%.0f p75=%.0f  iqr=%.0f   mean L=%.0f "
          "(the game's art means 79)" % (q[0], q[1], q[2], q[2] - q[0], lum.mean()))


if __name__ == "__main__":
    main()
