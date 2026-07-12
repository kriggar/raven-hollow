"""THE ZONE MAP PAINTER — WoW-grade parchment zone maps from zone_defs data.

Paints assets/art/maps/<zone>.png (1024px wide) for every built zone:
parchment base with fiber noise + stain blotches + burnt edge, biome wash,
sea bands, ink rivers, CLEARLY PAINTED roads (dark outline + tan core),
landmark glyphs in ink, waystation labels + zone title in Alagard.

Fable authors the look; this code is the brush (visual law).
Usage: python tools/map_painter.py [zone_id ...]   (default: all built zones)
"""
import json
import math
import os
import random
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(GAME, "assets", "art", "maps")
FONT = os.path.join(GAME, "assets", "fonts", "alagard.ttf")
W = 1024

PARCH = (222, 206, 168)
PARCH_DARK = (196, 178, 138)
INK = (58, 42, 28)
INK_SOFT = (94, 72, 48)
ROAD_CORE = (188, 150, 96)
RIVER_CORE = (96, 118, 138)
RIVER_DARK = (52, 66, 82)
SEA = (128, 142, 152)
BLOOD = (122, 44, 34)

BIOME_WASH = {
    "bog": (150, 148, 108), "moor": (168, 164, 118), "wilds": (160, 166, 116),
    "farmland": (178, 172, 120), "steppe": (188, 172, 112), "tundra": (196, 198, 196),
    "volcanic": (150, 122, 104), "ridge": (162, 154, 128), "deadforest": (152, 146, 118),
    "port": (160, 160, 132), "cave": (110, 104, 100), "village": (170, 164, 118),
}


def load_geo():
    src = open(os.path.join(GAME, "scripts", "zone_defs.gd"), encoding="utf-8").read().replace("\r\n", "\n")
    ids = re.findall(r'^\t"([a-z_0-9]+)": \{', src, re.M)
    zones = {}
    for i, z in enumerate(ids):
        start = src.index('"%s": {' % z)
        end = src.index('"%s": {' % ids[i + 1]) if i + 1 < len(ids) else len(src)
        b = src[start:end]
        if '"built": true' not in b[:200]:
            continue
        m = re.search(r'"tiles_w":\s*(\d+),\s*"tiles_h":\s*(\d+)', b)
        name = re.search(r'"name":\s*"([^"]+)"', b)
        biome = re.search(r'"biome":\s*"([a-z_]+)"', b)
        zones[z] = {
            "name": name.group(1) if name else z,
            "biome": biome.group(1) if biome else "wilds",
            "w": int(m.group(1)) * 32, "h": int(m.group(2)) * 32,
            "roads": _polys(b, "roads"),
            "river": _pts(b, "river"),
            "landmarks": [(t, float(x), float(y)) for t, x, y in
                          re.findall(r'\{"type":\s*"([a-z_]+)",\s*(?:"tex":\s*"[^"]*",\s*)?"pos":\s*Vector2\(([\d.]+),\s*([\d.]+)\)', b)],
            "decos": [(os.path.basename(t), float(x), float(y)) for t, x, y in
                      re.findall(r'"tex":\s*"([^"]+)",\s*"pos":\s*Vector2\(([\d.]+),\s*([\d.]+)\)', b)],
            "ways": re.findall(r'\{"id":\s*"([a-z_0-9]+)",\s*"pos":\s*Vector2\(([\d.]+),\s*([\d.]+)\)\}', b),
        }
    return zones


def _polys(b, key):
    k = b.find('"%s":' % key)
    if k == -1:
        return []
    j = b.index("[", k)
    depth, e = 0, j
    for c in range(j, len(b)):
        if b[c] == "[":
            depth += 1
        elif b[c] == "]":
            depth -= 1
            if depth == 0:
                e = c
                break
    seg = b[j:e + 1]
    out, d, cur = [], 0, None
    for c in range(1, len(seg)):
        if seg[c] == "[":
            d += 1
            if d == 1:
                cur = c
        elif seg[c] == "]":
            if d == 1 and cur is not None:
                pts = re.findall(r"Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)", seg[cur:c])
                if pts:
                    out.append([(float(x), float(y)) for x, y in pts])
            d -= 1
    return out


def _pts(b, key):
    m = re.search(r'"%s":\s*\[(.*?)\],\n' % key, b, re.S)
    if not m:
        return []
    return [(float(x), float(y)) for x, y in re.findall(r"Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)", m.group(1))]


def parchment(w, h, rng):
    im = Image.new("RGB", (w, h), PARCH)
    d = ImageDraw.Draw(im)
    # fiber noise
    for _ in range(w * h // 160):
        x, y = rng.randrange(w), rng.randrange(h)
        c = rng.randint(-14, 10)
        d.point((x, y), fill=(PARCH[0] + c, PARCH[1] + c, PARCH[2] + c))
    # stain blotches
    for _ in range(10):
        bx, by = rng.randrange(w), rng.randrange(h)
        br = rng.randint(40, 160)
        blot = Image.new("L", (br * 2, br * 2), 0)
        bd = ImageDraw.Draw(blot)
        bd.ellipse((0, 0, br * 2, br * 2), fill=rng.randint(10, 26))
        blot = blot.filter(ImageFilter.GaussianBlur(br // 3))
        im.paste(Image.new("RGB", blot.size, PARCH_DARK), (bx - br, by - br), blot)
    return im


def burnt_edge(im, rng):
    w, h = im.size
    edge = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(edge)
    m = 26
    d.rectangle((0, 0, w, m), fill=255)
    d.rectangle((0, h - m, w, h), fill=255)
    d.rectangle((0, 0, m, h), fill=255)
    d.rectangle((w - m, 0, w, h), fill=255)
    edge = edge.filter(ImageFilter.GaussianBlur(18))
    dark = Image.new("RGB", (w, h), (96, 74, 48))
    im.paste(dark, (0, 0), edge.point(lambda v: v * 0.75))
    # ragged ink border line
    d2 = ImageDraw.Draw(im)
    pts = []
    step = 24
    for x in range(m, w - m, step):
        pts.append((x, m + rng.randint(-3, 3)))
    for y in range(m, h - m, step):
        pts.append((w - m + rng.randint(-3, 3), y))
    d2.rectangle((m, m, w - m, h - m), outline=INK_SOFT, width=2)
    return im


def wash(im, color, rng):
    w, h = im.size
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    for _ in range(26):
        bx, by = rng.randrange(w), rng.randrange(h)
        br = rng.randint(70, 220)
        d.ellipse((bx - br, by - int(br * 0.7), bx + br, by + int(br * 0.7)), fill=rng.randint(16, 34))
    layer = layer.filter(ImageFilter.GaussianBlur(60))
    im.paste(Image.new("RGB", (w, h), color), (0, 0), layer)
    return im


def draw_poly(d, poly, sx, sy, width, color, joint=True):
    pts = [(x * sx, y * sy) for x, y in poly]
    if len(pts) < 2:
        return
    d.line(pts, fill=color, width=width, joint="curve" if joint else None)


def glyph(d, kind, x, y, f_small):
    """Tiny ink glyphs, WoW-map style."""
    if kind == "house":
        d.polygon([(x - 5, y), (x, y - 6), (x + 5, y)], fill=INK)
        d.rectangle((x - 4, y, x + 4, y + 5), fill=INK_SOFT)
    elif kind == "tower":
        d.rectangle((x - 3, y - 9, x + 3, y + 4), fill=INK_SOFT)
        d.polygon([(x - 4, y - 9), (x, y - 14), (x + 4, y - 9)], fill=INK)
    elif kind == "church":
        d.rectangle((x - 4, y - 4, x + 4, y + 4), fill=INK_SOFT)
        d.line((x, y - 12, x, y - 4), fill=INK, width=2)
        d.line((x - 3, y - 9, x + 3, y - 9), fill=INK, width=2)
    elif kind == "grave":
        d.line((x, y - 5, x, y + 3), fill=INK, width=2)
        d.line((x - 3, y - 2, x + 3, y - 2), fill=INK, width=2)
    elif kind == "camp":
        d.polygon([(x - 5, y + 3), (x, y - 5), (x + 5, y + 3)], outline=INK)
    elif kind == "pond":
        d.ellipse((x - 6, y - 3, x + 6, y + 3), fill=RIVER_CORE, outline=RIVER_DARK)
    elif kind == "anchor":
        d.line((x, y - 5, x, y + 4), fill=INK, width=2)
        d.arc((x - 4, y, x + 4, y + 7), 20, 160, fill=INK, width=2)
    elif kind == "statue":
        d.line((x, y - 8, x, y + 3), fill=INK, width=2)
        d.ellipse((x - 2, y - 10, x + 2, y - 6), fill=INK)
    elif kind == "fire":
        d.polygon([(x - 3, y + 2), (x, y - 5), (x + 3, y + 2)], fill=BLOOD)
    elif kind == "cave":
        d.arc((x - 6, y - 6, x + 6, y + 6), 180, 360, fill=INK, width=3)
    elif kind == "dot":
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=INK_SOFT)


GLYPH_BY_TYPE = {
    "cottage": "house", "tavern": "house", "barn": "house", "shed": "house",
    "well": "dot", "copper_well": "dot", "camp": "camp", "graves": "grave",
    "pond": "pond", "dolmen": "statue", "inscription_stone": "statue",
    "monument": "statue", "cairn": "dot", "stone_row": "dot", "pier": "anchor",
    "boat": "anchor", "wreck": "anchor", "warehouse": "house", "crane": "anchor",
    "lava_vent": "fire", "forge": "fire", "brazier": "fire", "gift_field": "dot",
    "lichen_glow": "dot", "lone_tree": "dot", "watchtower": "tower",
}
GLYPH_BY_TEX = [
    ("church", "church"), ("chapel", "church"), ("tower", "tower"),
    ("cottage", "house"), ("house", "house"), ("warehouse", "house"),
    ("windmill", "tower"), ("statue", "statue"), ("obelisk", "statue"),
    ("grave", "grave"), ("coffin", "grave"), ("shrine", "church"),
    ("boat", "anchor"), ("pier", "anchor"), ("cauldron", "fire"),
    ("brazier", "fire"), ("torch", "fire"), ("market", "house"), ("stall", "house"),
]


def paint(zid, g):
    rng = random.Random(zid)
    sx = W / g["w"]
    h = int(g["h"] * sx)
    sy = h / g["h"]
    im = parchment(W, h, rng)
    im = wash(im, BIOME_WASH.get(g["biome"], BIOME_WASH["wilds"]), rng)
    d = ImageDraw.Draw(im)

    # rivers under roads: dark ink bank + steel core
    if len(g["river"]) >= 2:
        draw_poly(d, g["river"], sx, sy, 13, RIVER_DARK)
        draw_poly(d, g["river"], sx, sy, 8, RIVER_CORE)

    # ROADS — clearly painted: wide dark outline, tan core, dashed centre ink
    for poly in g["roads"]:
        draw_poly(d, poly, sx, sy, 11, INK_SOFT)
    for poly in g["roads"]:
        draw_poly(d, poly, sx, sy, 7, ROAD_CORE)
    for poly in g["roads"]:
        pts = [(x * sx, y * sy) for x, y in poly]
        for i in range(len(pts) - 1):
            ax, ay = pts[i]
            bx, by = pts[i + 1]
            seg = math.dist(pts[i], pts[i + 1])
            n = max(1, int(seg / 26))
            for k in range(n):
                t0, t1 = k / n, (k + 0.45) / n
                d.line((ax + (bx - ax) * t0, ay + (by - ay) * t0,
                        ax + (bx - ax) * t1, ay + (by - ay) * t1), fill=INK, width=2)

    # landmark glyphs (typed + deco textures)
    f_small = ImageFont.truetype(FONT, 17)
    seen = []
    def place(kind, x, y):
        px, py = x * sx, y * sy
        for qx, qy in seen:
            if abs(qx - px) < 14 and abs(qy - py) < 14:
                return
        seen.append((px, py))
        glyph(d, kind, px, py, f_small)
    for t, x, y in g["landmarks"]:
        k = GLYPH_BY_TYPE.get(t)
        if k:
            place(k, x, y)
    for tex, x, y in g["decos"]:
        for key, k in GLYPH_BY_TEX:
            if key in tex:
                place(k, x, y)
                break

    # waystation labels (discoverable POI names, WoW-style)
    for wid, x, y in g["ways"]:
        px, py = float(x) * sx, float(y) * sy
        label = wid.replace("_", " ").title()
        tw = d.textlength(label, font=f_small)
        for ox, oy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            d.text((px - tw / 2 + ox, py + 10 + oy), label, font=f_small, fill=PARCH)
        d.text((px - tw / 2, py + 10), label, font=f_small, fill=INK)
        d.ellipse((px - 3, py - 3, px + 3, py + 3), fill=BLOOD, outline=INK)

    # zone title, top centre
    f_big = ImageFont.truetype(FONT, 44)
    title = g["name"].upper()
    tw = d.textlength(title, font=f_big)
    tx, ty = (W - tw) / 2, 34
    for ox, oy in ((2, 2), (-2, 2), (2, -2), (-2, -2)):
        d.text((tx + ox, ty + oy), title, font=f_big, fill=PARCH_DARK)
    d.text((tx, ty), title, font=f_big, fill=INK)

    im = burnt_edge(im, rng)
    im.save(os.path.join(OUT, "%s.png" % zid))
    return h


def main():
    os.makedirs(OUT, exist_ok=True)
    zones = load_geo()
    only = set(sys.argv[1:])
    for zid, g in zones.items():
        if only and zid not in only:
            continue
        h = paint(zid, g)
        print("%s: %dx%d" % (zid, W, h))


if __name__ == "__main__":
    main()
