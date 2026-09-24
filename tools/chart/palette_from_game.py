#!/usr/bin/env python3
"""palette_from_game.py - derive the map palette from the game's own art.

The owner's verdict on five rejected maps was that they "don't look like the
game". They were right, and the cause was simple: I invented a palette each
time. A map that belongs to a game is painted in that game's colours, so this
reads the actual sprites - the half-timbered houses, the foliage, the terrain
sheets - and reports the dominant colours of each material.

Usage:  python tools/chart/palette_from_game.py [--json out.json]
"""

import argparse
import colorsys
import json
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"

# What to sample, and which band of each sprite is that material. Houses are
# read in two bands because the roof and the wall are different materials and
# averaging them gives a muddy brown that is neither.
GROUPS = {
    "roof":    [("buildings/house_%02d.png" % i, (0.00, 0.42)) for i in range(8)],
    "wall":    [("buildings/house_%02d.png" % i, (0.55, 0.95)) for i in range(8)],
    "foliage": [("vegetation/plant_%02d.png" % i, (0.00, 0.80))
                for i in (0, 1, 2, 3, 4, 5, 8)],
}
TERRAIN = ["terrain/cainos_grass.png", "terrain/cainos_stone_ground.png",
           "terrain/lpc_road_organic.png", "terrain/lpc_sea_organic.png"]


def top_colours(pixels, n=6):
    """Dominant colours, quantised so near-identical shades group together."""
    if len(pixels) == 0:
        return []
    # uint8 arithmetic silently wraps, which collapsed every material to a
    # single colour on the first run. Everything here is int.
    q = ((np.asarray(pixels, dtype=int) // 12) * 12)
    counts = Counter(map(tuple, q))
    out = []
    for rgb, c in counts.most_common(n * 4):
        if len(out) >= n:
            break
        # skip anything too close to one already taken
        if any(sum((int(a) - int(b)) ** 2 for a, b in zip(rgb, o[0])) < 900 for o in out):
            continue
        out.append((rgb, c))
    return out


def sample(rel, band):
    p = ART / rel
    if not p.exists():
        return np.zeros((0, 3), dtype=int)
    im = Image.open(p).convert("RGBA")
    a = np.asarray(im)
    h = a.shape[0]
    y0, y1 = int(h * band[0]), max(int(h * band[1]), int(h * band[0]) + 1)
    a = a[y0:y1]
    rgb = a[..., :3].reshape(-1, 3)
    alpha = a[..., 3].reshape(-1)
    keep = alpha > 200
    rgb = rgb[keep]
    if len(rgb) == 0:
        return rgb
    lum = 0.299 * rgb[:, 0] + 0.587 * rgb[:, 1] + 0.114 * rgb[:, 2]
    # drop the near-black outline pixels, which every sprite has a lot of and
    # which would otherwise dominate every material
    return rgb[lum > 26]


def hexs(rgb):
    return "#%02x%02x%02x" % tuple(int(v) for v in rgb)


def report(name, pixels):
    tops = top_colours(pixels)
    if not tops:
        print("  %-9s (no pixels)" % name)
        return []
    total = sum(c for _, c in tops)
    cols = []
    parts = []
    for rgb, c in tops:
        cols.append(hexs(rgb))
        parts.append("%s %4.1f%%" % (hexs(rgb), 100.0 * c / total))
    print("  %-9s %s" % (name, "  ".join(parts)))
    return cols


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    print("the game's own palette, read from its sprites")
    out = {}
    for name, items in GROUPS.items():
        px = np.concatenate([sample(rel, band) for rel, band in items]
                            or [np.zeros((0, 3), int)])
        out[name] = report(name, px)
    for rel in TERRAIN:
        px = sample(rel, (0.0, 1.0))
        out[Path(rel).stem] = report(Path(rel).stem, px)

    # the single most useful number: what the whole game averages to, which is
    # the paper tone a map of it should sit on
    allpx = np.concatenate([sample(rel, b) for items in GROUPS.values()
                            for rel, b in items] or [np.zeros((0, 3), int)])
    if len(allpx):
        mean = allpx.mean(axis=0)
        h, l, s = colorsys.rgb_to_hls(*(mean / 255.0))
        print("\n  mean of all art  %s   hue %.0f deg  sat %.0f%%  light %.0f%%"
              % (hexs(mean), h * 360, s * 100, l * 100))
        out["mean"] = hexs(mean)

    if args.json:
        Path(args.json).write_text(json.dumps(out, indent=2), encoding="utf-8")
        print("\nwrote", args.json)


if __name__ == "__main__":
    main()
