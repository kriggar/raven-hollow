"""Extract the Szadi art. Houses Pack modules for the city rowhouse generator.

Source: _downloads/scout_2026_07/capital_civic/szadi_houses_pack/extracted/houses.png
(1024x1024; three colourways in columns ~340 px apart: purple, slate, red).
License: Szadi art. custom free license — free for personal + commercial use, editable,
no resale of the pack itself (quoted in _downloads/scout_2026_07/ASSESS_MANIFEST.md).
Output: assets/art/world/houses/<module>_<colour>.png. Crops picked on the 32px grid
(_screens/szadi_houses_grid.png). Run from the repo root, then godot --headless --import.
"""
import os
from PIL import Image

SRC = "_downloads/scout_2026_07/capital_civic/szadi_houses_pack/extracted/houses.png"
OUT = "assets/art/world/houses"
os.makedirs(OUT, exist_ok=True)
sheet = Image.open(SRC).convert("RGBA")
COLS = {"purple": 0, "slate": 340, "red": 680}


def trim(im, margin=0):
    bb = im.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - margin), max(0, y0 - margin), min(im.width, x1 + margin), min(im.height, y1 + margin)))


# module boxes for the PURPLE column (x offsets added per colourway)
MODULES = {
    "roof_cross": (28, 148, 274, 394),     # wide cross-gabled roof (~246x246)
    "roof_gable": (70, 408, 234, 604),     # tall gable roof with round window (~164x196)
    "roof_flat": (68, 18, 234, 122),       # flat-topped tile roof band (shed / annex)
    "wall_side": (0, 418, 58, 512),        # narrow wall strip with windows
    "dormer": (238, 468, 302, 512),        # small gable dormer
    "plaster_upper": (82, 666, 236, 742),  # plaster band, two storeys of arched windows
    "door_module": (254, 702, 332, 746),   # wooden door + open doorway + step
    "timber_ground": (50, 762, 342, 814),  # plank ground floor with door and barn door (planks + sill)
    "windows_row": (58, 828, 304, 852),    # six shuttered windows + small door
    "chimney_a": (276, 8, 304, 34),
    "chimney_b": (276, 64, 304, 98),
    "chimney_c": (306, 64, 334, 98),
    "pole": (40, 844, 62, 932),
}

for colour, dx in COLS.items():
    for name, (x0, y0, x1, y1) in MODULES.items():
        box = (x0 + dx, y0, min(1024, x1 + dx), y1)
        im = trim(sheet.crop(box))
        im.save(os.path.join(OUT, f"{name}_{colour}.png"))
        print(f"{name}_{colour}", im.size)
print("done")
