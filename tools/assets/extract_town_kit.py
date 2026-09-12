"""Extract the Raven Hollow town polish kit from verified-free packs.

Sources (all under _downloads/scout_2026_07, licenses in ASSESS_MANIFEST.md):
  - Szadi art. "Fantasy Lands Houses Demo" (custom free license, commercial ok):
      thatch market awning, hanging cloth line.
  - [LPC] Farming tilesets (Daniel Eddeland, CC-BY-SA 3.0 / GPL 3.0):
      mature crops, sprouts, corn, reeds.
Output: assets/art/world/town/*.png (alpha-trimmed, 1px margin). Run from repo root,
then `godot --headless --import`.
"""
import os
from PIL import Image

SZ = "_downloads/scout_2026_07/capital_civic/szadi_fantasy_lands_houses_demo/extracted/Exterrior/walls_roofs_and_other.png"
LPC = "_downloads/scout_2026_07/village/lpc_farming_tilesets_daneeklu/submission_daneeklu/tilesets/"
OUT = "assets/art/world/town"
os.makedirs(OUT, exist_ok=True)


def trim(im, margin=1):
    bb = im.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    x0 = max(0, x0 - margin); y0 = max(0, y0 - margin)
    x1 = min(im.width, x1 + margin); y1 = min(im.height, y1 + margin)
    return im.crop((x0, y0, x1, y1))


def save(im, name):
    p = os.path.join(OUT, name + ".png")
    im.save(p)
    print(name, im.size)


sz = Image.open(SZ).convert("RGBA")
save(trim(sz.crop((382, 62, 480, 150))), "szadi_awning")
save(trim(sz.crop((126, 126, 190, 258))), "szadi_cloth_line")

plants = Image.open(LPC + "plants.png").convert("RGBA")
def cell(img, c, r, w=1, h=1):
    return img.crop((c * 32, r * 32, (c + w) * 32, (r + h) * 32))
names = ["tomato", "carrot", "lettuce", "cabbage", "pepper", "cucumber"]
for c, n in enumerate(names):
    save(trim(cell(plants, c, 7)), "crop_" + n)
    save(trim(cell(plants, c, 5)), "sprout_" + n)
save(trim(cell(plants, 6, 6, 1, 2)), "crop_corn")
save(trim(cell(plants, 6, 3, 1, 2)), "sprout_corn")

reed = Image.open(LPC + "reed.png").convert("RGBA")
save(trim(cell(reed, 0, 0, 1, 2)), "reed_a")
save(trim(cell(reed, 0, 5, 1, 2)), "reed_b")
save(trim(cell(reed, 0, 3)), "reed_bank")
print("done")
