# Draconia world-map generator — THE parchment masterpiece (iterative).
# Gothic Eastern-European manuscript style: aged parchment, iron-gall ink,
# woodcut terrain glyphs, Alagard gothic lettering, ornamented frame.
# Output: assets/art/ui/world_map.png (2048x1152, shown 3.2x downscaled).
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2048, 1152
rng = random.Random(20260705)

INK = (52, 38, 24)          # iron-gall brown-black
INK_SOFT = (52, 38, 24, 150)
INK_FAINT = (52, 38, 24, 70)
BLOOD = (112, 32, 24)       # rubric red for seals/accents
SEA_TINT = (196, 186, 152)

font_path = r"c:/Users/vstef/Desktop/rpg/medieval_rpg/assets/fonts/alagard.ttf"
F_TITLE = ImageFont.truetype(font_path, 92)
F_KINGDOM = ImageFont.truetype(font_path, 54)
F_ZONE = ImageFont.truetype(font_path, 26)
F_SMALL = ImageFont.truetype(font_path, 20)

# ----------------------------------------------------------------- parchment
def parchment() -> Image.Image:
    img = Image.new("RGB", (W, H), (214, 192, 148))
    px = img.load()
    for y in range(H):
        for x in range(0, W, 2):  # coarse noise, cheap
            n = rng.randint(-9, 9)
            r, g, b = px[x, y]
            px[x, y] = (r + n, g + n, b + n - 2)
            if x + 1 < W:
                px[x + 1, y] = (r + n, g + n, b + n - 2)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    d = ImageDraw.Draw(img, "RGBA")
    # blotches / staining
    for _ in range(120):
        bx, by = rng.randint(0, W), rng.randint(0, H)
        br = rng.randint(24, 130)
        alpha = rng.randint(5, 16)
        tone = rng.choice([(120, 96, 58), (160, 130, 80), (90, 70, 44)])
        d.ellipse([bx - br, by - int(br * 0.7), bx + br, by + int(br * 0.7)],
                  fill=tone + (alpha,))
    img = img.filter(ImageFilter.GaussianBlur(6))
    # edge burn (vignette)
    vig = Image.new("L", (W, H), 0)
    dv = ImageDraw.Draw(vig)
    dv.rectangle([0, 0, W, H], fill=110)
    dv.rounded_rectangle([50, 44, W - 50, H - 44], radius=90, fill=0)
    vig = vig.filter(ImageFilter.GaussianBlur(48))
    dark = Image.new("RGB", (W, H), (96, 74, 44))
    img = Image.composite(dark, img, vig.point(lambda v: min(255, int(v * 1.1))))
    # central fold crease
    d = ImageDraw.Draw(img, "RGBA")
    d.line([(W // 2, 60), (W // 2, H - 60)], fill=(90, 70, 44, 40), width=3)
    return img

# ------------------------------------------------------------- ink helpers
def rough_poly(d, pts, width=4, color=INK, jitter=3.0, close=True):
    """Hand-drawn line: subdivide + jitter so nothing is CAD-straight."""
    out = []
    n = len(pts)
    seg = n if close else n - 1
    for i in range(seg):
        a, b = pts[i], pts[(i + 1) % n]
        steps = max(2, int(math.dist(a, b) / 26))
        for s in range(steps):
            t = s / steps
            x = a[0] + (b[0] - a[0]) * t + rng.uniform(-jitter, jitter)
            y = a[1] + (b[1] - a[1]) * t + rng.uniform(-jitter, jitter)
            out.append((x, y))
    if close:
        out.append(out[0])
    d.line(out, fill=color, width=width, joint="curve")
    return out

def mountains(d, cx, cy, count, spread_x, spread_y, size=(16, 30)):
    for _ in range(count):
        mx = cx + rng.uniform(-spread_x, spread_x)
        my = cy + rng.uniform(-spread_y, spread_y)
        s = rng.uniform(*size)
        d.line([(mx - s, my), (mx, my - s * 1.15), (mx + s, my)], fill=INK, width=3, joint="curve")
        d.line([(mx, my - s * 1.15), (mx + s * 0.28, my - s * 0.45)], fill=INK_SOFT, width=2)

def trees(d, cx, cy, count, spread_x, spread_y, dead=False):
    for _ in range(count):
        tx = cx + rng.uniform(-spread_x, spread_x)
        ty = cy + rng.uniform(-spread_y, spread_y)
        s = rng.uniform(9, 15)
        if dead:
            d.line([(tx, ty), (tx, ty - s * 1.5)], fill=INK, width=2)
            d.line([(tx, ty - s * 0.9), (tx - s * 0.55, ty - s * 1.35)], fill=INK, width=2)
            d.line([(tx, ty - s * 1.1), (tx + s * 0.5, ty - s * 1.5)], fill=INK, width=2)
        else:
            d.polygon([(tx - s * 0.62, ty), (tx + s * 0.62, ty), (tx, ty - s * 1.6)],
                      outline=INK, width=2)
            d.line([(tx, ty), (tx, ty + s * 0.42)], fill=INK, width=2)

def waves(d, region, count):
    x0, y0, x1, y1 = region
    for _ in range(count):
        wx = rng.uniform(x0, x1)
        wy = rng.uniform(y0, y1)
        s = rng.uniform(9, 17)
        d.arc([wx, wy, wx + s * 2, wy + s], 190, 350, fill=INK_SOFT, width=2)

def snow_hatch(d, cx, cy, count, spread_x, spread_y):
    for _ in range(count):
        hx = cx + rng.uniform(-spread_x, spread_x)
        hy = cy + rng.uniform(-spread_y, spread_y)
        s = rng.uniform(3, 6)
        d.line([(hx - s, hy), (hx + s, hy)], fill=INK_SOFT, width=2)
        d.line([(hx, hy - s), (hx, hy + s)], fill=INK_SOFT, width=2)

def label(d, xy, text, font, color=INK, halo=True, anchor="mm"):
    if halo:  # parchment halo so ink never fights terrain strokes
        for ox in (-2, 0, 2):
            for oy in (-2, 0, 2):
                d.text((xy[0] + ox, xy[1] + oy), text, font=font,
                       fill=(214, 196, 152, 235), anchor=anchor)
    d.text(xy, text, font=font, fill=color, anchor=anchor)

# ------------------------------------------------------------------ compose
img = parchment()
d = ImageDraw.Draw(img, "RGBA")

# === CONTINENT 1: DRACONIA (left 2/3) — cardinal kingdoms around the Border
DRACONIA = [
    (255, 320), (400, 250), (520, 235), (600, 262), (700, 228), (850, 240),
    (990, 285), (1105, 360), (1175, 430), (1215, 520), (1190, 610),
    (1230, 680), (1150, 760), (1060, 800), (985, 900), (900, 870),
    (820, 960), (700, 930), (620, 985), (500, 940), (420, 950),
    (330, 860), (300, 770), (215, 700), (240, 620), (180, 540),
    (215, 430), (170, 380),
]
# subtle land tint inside the coast
d.polygon(DRACONIA, fill=(206, 186, 140, 90))
coast = rough_poly(d, DRACONIA, width=5, jitter=4.0)
# coast hatching (woodcut sea-shadow)
for i in range(0, len(coast) - 4, 3):
    x, y = coast[i]
    cx, cy = 700, 560
    vx, vy = x - cx, y - cy
    L = math.hypot(vx, vy) or 1
    d.line([(x, y), (x + vx / L * 13, y + vy / L * 13)], fill=INK_FAINT, width=2)

# terrain per canon: N tundra, E ridges, S volcanic, W farm, interior bog
snow_hatch(d, 640, 300, 90, 300, 90)          # north — Black Night tundra
mountains(d, 1080, 480, 26, 90, 150)          # east — Carpathian spine (Blestem)
mountains(d, 830, 810, 16, 150, 70, (13, 22)) # south — Basaltfang
# volcano: Sangeroasa vent
d.line([(870, 770), (905, 700), (940, 770)], fill=INK, width=4)
smoke = [(905, 695)]
for k in range(1, 7):
    smoke.append((905 + math.sin(k * 1.4) * 10 + k * 4, 695 - k * 16))
d.line(smoke, fill=INK_SOFT, width=2, joint="curve")
trees(d, 360, 560, 26, 130, 130)              # west — lowland woods
trees(d, 700, 570, 20, 120, 100, dead=True)   # border — dying birch
# the Iron Vein river: NE ridges -> interior -> west delta
river = [(1010, 420), (900, 470), (790, 540), (700, 600), (560, 640), (430, 640), (330, 610)]
trib = [(760, 760), (720, 680), (700, 600)]
rough_poly(d, river, width=7, color=(70, 54, 38), jitter=2.0, close=False)
rough_poly(d, [(p[0], p[1] - 2) for p in river], width=2, color=(96, 82, 66), jitter=1.0, close=False)
rough_poly(d, trib, width=4, color=(70, 54, 38), jitter=2.0, close=False)
d.line([(330, 610), (300, 580)], fill=(78, 60, 40), width=3)
d.line([(330, 610), (295, 635)], fill=(78, 60, 40), width=3)

# coach routes (dotted): the western travel spine + stonepath crossing
ROUTES_PTS = [
    [(700, 600), (790, 648), (860, 700), (960, 660)],           # border ring
    [(700, 600), (560, 615), (470, 560), (380, 545), (300, 545)],  # to Angel Wings
    [(960, 660), (1080, 560), (1128, 520)],                     # to Blestem
    [(860, 700), (905, 780)],                                   # to Sangeroasa
    [(700, 600), (660, 480), (640, 300)],                       # to Black Night
]
for route in ROUTES_PTS:
    for i in range(len(route) - 1):
        a, b = route[i], route[i + 1]
        steps = max(4, int(math.dist(a, b) / 16))
        for st in range(0, steps, 2):
            t0, t1 = st / steps, min(1.0, (st + 0.9) / steps)
            d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                    (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)],
                   fill=(90, 60, 40, 170), width=2)

# kingdom capitals — gothic keep glyphs
def keep(d, x, y, s=20):
    d.rectangle([x - s, y - s * 0.7, x + s, y + s * 0.55], outline=INK, width=3)
    d.polygon([(x - s, y - s * 0.7), (x - s * 0.45, y - s * 1.25), (x + s * 0.1, y - s * 0.7)], outline=INK, width=3)
    d.polygon([(x + s * 0.05, y - s * 0.7), (x + s * 0.5, y - s * 1.35), (x + s, y - s * 0.7)], outline=INK, width=3)
    d.line([(x + s * 0.5, y - s * 1.35), (x + s * 0.5, y - s * 1.7)], fill=INK, width=2)
    d.polygon([(x + s * 0.5, y - s * 1.7), (x + s * 0.95, y - s * 1.55), (x + s * 0.5, y - s * 1.42)], fill=BLOOD)

keep(d, 640, 272)    # Black Night (N)
keep(d, 1128, 520)   # Blestem (E)
keep(d, 930, 830)    # Sangeroasa (S)
keep(d, 300, 545)    # Angel Wings (W)
d.ellipse([694, 594, 706, 606], outline=INK, width=3)  # Raven Hollow / Border hub

# kingdom labels
label(d, (640, 318), "BLACK NIGHT", F_KINGDOM)
label(d, (640, 350), "the city over the grave", F_SMALL, INK_SOFT)
d.rounded_rectangle([1006, 396, 1240, 462], radius=8, fill=(214, 196, 152, 210), outline=INK, width=2)
label(d, (1122, 420), "BLESTEM", F_KINGDOM)
label(d, (1122, 448), "the listening city", F_SMALL, INK_SOFT)
label(d, (930, 892), "SANGEROASA", F_KINGDOM)
label(d, (930, 924), "the forge that eats", F_SMALL, INK_SOFT)
label(d, (300, 480), "ANGEL WINGS", F_KINGDOM)
label(d, (300, 511), "the underestimated west", F_SMALL, INK_SOFT)
d.ellipse([688, 588, 712, 612], outline=INK, width=3)
d.ellipse([696, 596, 704, 604], fill=BLOOD)
label(d, (700, 568), "Raven Hollow", F_ZONE)
label(d, (790, 648), "Vetka", F_SMALL, INK_SOFT)
label(d, (860, 700), "the Copper Wells", F_SMALL, INK_SOFT)
label(d, (960, 640), "the Stonepath", F_SMALL, INK_SOFT)
label(d, (545, 672), "Iron Vein", F_SMALL, INK_SOFT)
label(d, (470, 540), "the Grey Marches", F_SMALL, INK_SOFT)
label(d, (330, 668), "Riverfork", F_SMALL, INK_SOFT)
label(d, (985, 760), "the Gift", F_SMALL, INK_SOFT)
label(d, (640, 400), "the Threadlands", F_SMALL, INK_SOFT)
label(d, (1000, 355), "the Whisper Passes", F_SMALL, INK_SOFT)
label(d, (485, 262), "the Listening Steppe", F_SMALL, INK_SOFT)
label(d, (815, 265), "Gravemark Tundra", F_SMALL, INK_SOFT)
label(d, (1105, 480), "the Eastern Ridges", F_SMALL, INK_SOFT)
label(d, (1210, 500), "Lichenreach", F_SMALL, INK_SOFT)
label(d, (1170, 560), "the Transcub Vale", F_SMALL, INK_SOFT)
label(d, (880, 745), "the Bloodroad", F_SMALL, INK_SOFT)
label(d, (838, 790), "Basaltfang Range", F_SMALL, INK_SOFT)
label(d, (1075, 838), "the Ashvents", F_SMALL, INK_SOFT)
label(d, (395, 445), "the Western Lowlands", F_SMALL, INK_SOFT)
label(d, (250, 590), "the Famine Fields", F_SMALL, INK_SOFT)

# === CONTINENT 2: THE COLLECTOR'S COAST (right, smaller, drowned)
COAST2 = [
    (1530, 440), (1610, 400), (1680, 420), (1740, 385), (1830, 410),
    (1900, 470), (1885, 540), (1930, 600), (1895, 680), (1905, 740),
    (1820, 790), (1750, 770), (1700, 830), (1620, 800), (1560, 830),
    (1515, 750), (1540, 680), (1480, 620), (1500, 540), (1465, 500),
]
d.polygon(COAST2, fill=(198, 180, 138, 80))
c2 = rough_poly(d, COAST2, width=5, jitter=4.0)
for i in range(0, len(c2) - 4, 3):
    x, y = c2[i]
    vx, vy = x - 1700, y - 610
    L = math.hypot(vx, vy) or 1
    d.line([(x, y), (x + vx / L * 12, y + vy / L * 12)], fill=INK_FAINT, width=2)
trees(d, 1620, 500, 16, 90, 60, dead=True)    # the Dead Timber
# drowned islets off the coast
for ix, iy, ir in [(1445, 790, 16), (1500, 850, 12), (1585, 878, 10)]:
    pts = [(ix + math.cos(a) * ir * rng.uniform(0.8, 1.2), iy + math.sin(a) * ir * rng.uniform(0.7, 1.1))
           for a in [k * math.pi / 4 for k in range(8)]]
    rough_poly(d, pts, width=2, jitter=1.5)
# canal grid of Greyhollow (the drowned ledger's ruled lines)
for gx in range(4):
    d.line([(1665 + gx * 26, 690), (1665 + gx * 26, 752)], fill=INK_SOFT, width=2)
for gy in range(3):
    d.line([(1660, 696 + gy * 24), (1748 + 12, 696 + gy * 24)], fill=INK_SOFT, width=2)
keep(d, 1720, 660)                            # Greyhollow
label(d, (1700, 330), "THE COLLECTOR'S COAST", F_ZONE, INK)
d.line([(1560, 352), (1660, 348)], fill=INK_SOFT, width=2)
d.line([(1740, 348), (1850, 352)], fill=INK_SOFT, width=2)
label(d, (1680, 616), "GREYHOLLOW", F_KINGDOM)
label(d, (1680, 647), "the drowned ledger", F_SMALL, INK_SOFT)
# — Continent 2 zones per the canonical Batch-G topology grid —
keep(d, 1760, 415)   # the Archive (N capital)
label(d, (1760, 452), "THE ARCHIVE", F_KINGDOM)
label(d, (1760, 483), "preserve, then finalize", F_SMALL, INK_SOFT)
label(d, (1682, 520), "the Finalized Fields", F_SMALL, INK_SOFT)
label(d, (1852, 528), "the Last Hearth", F_SMALL, INK_SOFT)
label(d, (1740, 556), "the Ledger Roads", F_SMALL, INK_SOFT)
label(d, (1872, 592), "the Orange Fog", F_SMALL, INK_SOFT)
label(d, (1512, 585), "Morven Reach", F_SMALL, INK_SOFT)
label(d, (1510, 662), "the Canal Maze", F_SMALL, INK_SOFT)
label(d, (1852, 668), "the Salt Fens", F_SMALL, INK_SOFT)
label(d, (1528, 710), "the Drowned Quarter", F_SMALL, INK_SOFT)
label(d, (1645, 748), "the Grey Piers", F_SMALL, INK_SOFT)
mountains(d, 1790, 700, 5, 42, 26)
label(d, (1822, 748), "Anchorfall", F_SMALL, INK_SOFT)
label(d, (1552, 508), "Dead Timber", F_SMALL, INK_SOFT)

# sea + the Grey Ferry route (era-crossing)
waves(d, (1240, 260, 1480, 940), 80)
waves(d, (120, 990, 1920, 1100), 40)
# rhumb lines from compass
for ang in range(0, 360, 45):
    a = math.radians(ang)
    d.line([(235 + math.cos(a) * 70, 950 + math.sin(a) * 70),
            (235 + math.cos(a) * 560, 950 + math.sin(a) * 560)], fill=(52, 38, 24, 26), width=1)
# sea serpent (woodcut humps + head) in the strait
ssx, ssy = 1330, 880
for h in range(3):
    d.arc([ssx + h * 44, ssy - 18, ssx + 36 + h * 44, ssy + 18], 180, 360, fill=INK, width=4)
d.line([(ssx + 132, ssy), (ssx + 156, ssy - 22)], fill=INK, width=4)
d.polygon([(ssx + 156, ssy - 22), (ssx + 174, ssy - 16), (ssx + 158, ssy - 6)], fill=INK)
d.line([(ssx - 8, ssy), (ssx - 26, ssy - 14)], fill=INK, width=3)

ferry = [(1240, 640), (1330, 660), (1420, 680), (1500, 690)]
for i in range(len(ferry) - 1):
    a, b = ferry[i], ferry[i + 1]
    steps = 7
    for s in range(0, steps, 2):
        t0, t1 = s / steps, (s + 1) / steps
        d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=INK, width=3)
label(d, (1360, 620), "the Grey Ferry", F_SMALL, INK_SOFT)

# === ORNAMENT: title cartouche, compass, frame, seal, raven
# double-rule frame with corner diamonds
d.rectangle([64, 58, W - 64, H - 58], outline=INK, width=4)
d.rectangle([78, 72, W - 78, H - 72], outline=INK_SOFT, width=2)
for cx, cy in [(64, 58), (W - 64, 58), (64, H - 58), (W - 64, H - 58)]:
    d.polygon([(cx, cy - 16), (cx + 16, cy), (cx, cy + 16), (cx - 16, cy)], outline=INK, width=3)
    d.polygon([(cx, cy - 7), (cx + 7, cy), (cx, cy + 7), (cx - 7, cy)], fill=BLOOD)

for tx in range(120, W - 100, 64):
    d.polygon([(tx, 72), (tx + 5, 77), (tx, 82), (tx - 5, 77)], outline=INK, width=1)
    d.polygon([(tx, H - 82), (tx + 5, H - 77), (tx, H - 72), (tx - 5, H - 77)], outline=INK, width=1)

# title
label(d, (W // 2, 118), "D R A C O N I A", F_TITLE)
label(d, (W // 2, 176), "the four kingdoms & the drowned coast", F_ZONE, INK_SOFT)
for dxo in (-470, 470):
    d.polygon([(W // 2 + dxo, 170), (W // 2 + dxo + 7, 176), (W // 2 + dxo, 182), (W // 2 + dxo - 7, 176)], fill=BLOOD)
d.line([(W // 2 - 360, 205), (W // 2 - 40, 205)], fill=INK, width=2)
d.line([(W // 2 + 40, 205), (W // 2 + 360, 205)], fill=INK, width=2)
d.polygon([(W // 2, 197), (W // 2 + 10, 205), (W // 2, 213), (W // 2 - 10, 205)], fill=BLOOD)

# compass rose (eight-point, Orthodox-star flavor), lower-left sea
ccx, ccy = 235, 950
for i in range(8):
    a = i * math.pi / 4
    L = 62 if i % 2 == 0 else 36
    x2, y2 = ccx + math.cos(a) * L, ccy + math.sin(a) * L
    d.line([(ccx, ccy), (x2, y2)], fill=INK, width=3 if i % 2 == 0 else 2)
d.ellipse([ccx - 12, ccy - 12, ccx + 12, ccy + 12], outline=INK, width=3)
d.ellipse([ccx - 4, ccy - 4, ccx + 4, ccy + 4], fill=BLOOD)
label(d, (ccx, ccy - 84), "N", F_ZONE)

# raven silhouette (top-right sky)
rvx, rvy = 1830, 200
d.polygon([(rvx, rvy), (rvx - 46, rvy - 12), (rvx - 18, rvy + 2), (rvx - 30, rvy + 22),
           (rvx - 6, rvy + 8), (rvx + 26, rvy + 26), (rvx + 12, rvy + 4), (rvx + 40, rvy - 8)],
          fill=INK)

# wax seal (bottom-right): the Bloodstone sigil
sx, sy = 1870, 1000
d.ellipse([sx - 52, sy - 52, sx + 52, sy + 52], fill=(122, 34, 26))
d.ellipse([sx - 52, sy - 52, sx + 52, sy + 52], outline=(70, 18, 14), width=4)
d.ellipse([sx - 40, sy - 40, sx + 40, sy + 40], outline=(160, 60, 46), width=2)
d.polygon([(sx, sy - 24), (sx + 20, sy), (sx, sy + 24), (sx - 20, sy)], outline=(230, 190, 160), width=3)
d.line([(sx, sy - 24), (sx, sy + 24)], fill=(230, 190, 160), width=2)

img.save(r"c:/Users/vstef/Desktop/rpg/medieval_rpg/assets/art/ui/world_map.png")
print("world_map.png written", img.size)
