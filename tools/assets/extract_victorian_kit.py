"""Extract city street furniture from [LPC] Victorian Town Decorations (CC-BY-SA 4.0,
bluecarrot16 + 22 contributors; see CREDITS-decorations-victorian.txt in the pack).

Regions are cut into alpha-connected components (dilated by 2px so lanterns keep their
brackets); the N largest components of each region are saved as <name>_<k>.png plus a
labelled montage _screens/kit_victorian_<name>.png so crops can be picked by eye.
Source: _downloads/mass_2026_07/oga_lpc_bundles/lpc_victorian_town_decorations/
Output: assets/art/world/street/
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

BASE = "_downloads/mass_2026_07/oga_lpc_bundles/lpc_victorian_town_decorations/lpc-victorian-decoration/"
OUT = "assets/art/world/street"
os.makedirs(OUT, exist_ok=True)
os.makedirs("_screens", exist_ok=True)
font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 12)

REGIONS = {
    # streets sheet
    "banner":   ("victorian-streets.png", (200, 0, 345, 170), 12),
    "flag":     ("victorian-streets.png", (0, 60, 200, 200), 8),
    "lamp":     ("victorian-streets.png", (0, 185, 260, 255), 8),
    "board":    ("victorian-streets.png", (250, 250, 320, 320), 4),
    "signboard": ("victorian-streets.png", (0, 315, 200, 385), 6),
    "signicon": ("victorian-streets.png", (0, 380, 230, 440), 14),
    "wallamp":  ("victorian-streets.png", (0, 435, 260, 560), 16),
    "ironfence": ("victorian-streets.png", (0, 920, 512, 1024), 10),
    # garden sheet
    "urn":      ("victorian-garden.png", (0, 255, 70, 320), 4),
    "pot":      ("victorian-garden.png", (60, 275, 400, 385), 20),
    "bed":      ("victorian-garden.png", (0, 380, 330, 520), 14),
    "hedge":    ("victorian-garden.png", (0, 640, 200, 1024), 12),
    "flowerbed": ("victorian-garden.png", (215, 650, 512, 850), 12),
    "stalk":    ("victorian-garden.png", (320, 850, 512, 960), 6),
    # market sheet
    "awning":   ("victorian-market.png", (0, 1024, 512, 1275), 12),
    "umbrella": ("victorian-market.png", (0, 1274, 512, 1340), 8),
    "stall":    ("victorian-market.png", (0, 1334, 512, 1430), 10),
    "goods":    ("victorian-market.png", (0, 1440, 512, 1560), 14),
    "crate":    ("victorian-market.png", (0, 1554, 260, 1660), 12),
    "barrel":   ("victorian-market.png", (260, 1650, 512, 1800), 10),
    "haybale":  ("victorian-market.png", (300, 1840, 512, 1920), 6),
    "bench":    ("victorian-market.png", (0, 1980, 512, 2048), 8),
}

sheets = {}
for name, (sheet, box, n) in REGIONS.items():
    if sheet not in sheets:
        sheets[sheet] = Image.open(BASE + sheet).convert("RGBA")
    reg = sheets[sheet].crop(box)
    a = np.array(reg)[:, :, 3] > 8
    lab, cnt = ndimage.label(ndimage.binary_dilation(a, iterations=2))
    comps = []
    for i in range(1, cnt + 1):
        ys, xs = np.where(lab == i)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        if (x1 - x0) * (y1 - y0) < 100:
            continue
        comps.append((x0, y0, x1, y1))
    comps.sort(key=lambda b: (b[1] // 24, b[0]))
    comps = comps[:n]
    Z = 2
    cw = max((b[2] - b[0]) * Z for b in comps) + 8
    ch = max((b[3] - b[1]) * Z for b in comps) + 20
    cols = min(8, len(comps))
    rows = (len(comps) + cols - 1) // cols
    mont = Image.new("RGBA", (cols * cw, rows * ch), (50, 50, 60, 255))
    d = ImageDraw.Draw(mont)
    for k, (x0, y0, x1, y1) in enumerate(comps):
        piece = reg.crop((x0, y0, x1, y1))
        fn = f"{name}_{k}.png"
        piece.save(os.path.join(OUT, fn))
        t = piece.resize((piece.width * Z, piece.height * Z), Image.NEAREST)
        mx = (k % cols) * cw
        my = (k // cols) * ch
        mont.paste(t, (mx + 4, my + 16), t)
        d.text((mx + 2, my + 2), f"{name}_{k} {piece.width}x{piece.height}", fill=(255, 230, 150, 255), font=font)
    mont.save(f"_screens/kit_victorian_{name}.png")
    print(name, len(comps))
print("done")
