"""Extract the Raven Hollow CITY kit from the LPC Castle Mega Pack (dark set).

Source: _downloads/mass_2026_07/oga_lpc_bundles/lpc_castle_mega_pack (castle8dark.png,
castle-extras.png). License: CC-BY-SA 3.0 / GPL 3.0 (LPC) — see LICENSE_EVIDENCE.txt
there and CREDITS.md ("LPC Castle Mega Pack"). Output: assets/art/world/castle/*.png.
Crops were picked by eye on the 32px grid (_screens/castle_q_*.png, castle_cands.png).
Run from the repo root, then `godot --headless --import`.
"""
import os
from PIL import Image

SRC = "_downloads/mass_2026_07/oga_lpc_bundles/lpc_castle_mega_pack/"
OUT = "assets/art/world/castle"
os.makedirs(OUT, exist_ok=True)
dark = Image.open(SRC + "castle8dark.png").convert("RGBA")
extras = Image.open(SRC + "castle-extras.png").convert("RGBA")


def trim(im, margin=0):
    bb = im.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - margin), max(0, y0 - margin), min(im.width, x1 + margin), min(im.height, y1 + margin)))


def save(im, name):
    im.save(os.path.join(OUT, name + ".png"))
    print(name, im.size)


# --- curtain wall (front face, parapet on top) and tileable brick band
save(dark.crop((0, 96, 64, 192)), "wall_face_a")        # 64x96 plain brick, parapet top
save(dark.crop((64, 96, 128, 192)), "wall_face_b")      # 64x96 brick with crest
save(dark.crop((0, 128, 64, 192)), "wall_band")         # 64x64 brick, no parapet (N-S runs)
save(trim(dark.crop((0, 192, 64, 224))), "wall_cren")   # parapet strip cap
# --- towers
save(trim(dark.crop((192, 96, 320, 224))), "tower_sq")      # 128x128 battlemented square tower
save(trim(dark.crop((320, 96, 384, 224))), "tower_narrow")  # 64x128
save(trim(dark.crop((448, 96, 512, 224))), "tower_round")   # 64x128 round battlemented
save(trim(dark.crop((256, 640, 384, 768))), "tower_round_big")  # 128x128 round body w/ door
# --- gates
save(trim(dark.crop((256, 448, 320, 512))), "gate_arch")     # 64x64 arch (open)
save(trim(dark.crop((352, 448, 416, 512))), "gate_doors")    # 64x64 arch with double doors
save(trim(dark.crop((448, 448, 512, 512))), "gate_small")    # 64x64 small door arch
save(trim(dark.crop((352, 352, 480, 448))), "wall_window")   # 128x96 wall with window + stairs
# --- bridge, cathedral, spires, roofs
save(trim(dark.crop((0, 832, 256, 1024))), "bridge_arch")    # 256x192 stone arch bridge (front)
save(trim(dark.crop((256, 832, 320, 1024))), "gothic_tower")     # 64x192 gothic facade tower (lancets)
save(trim(dark.crop((320, 832, 384, 1024))), "spire_tall")       # 64x192 tall cone spire
save(trim(dark.crop((384, 832, 448, 896))), "spire_a")
save(trim(dark.crop((448, 832, 512, 896))), "spire_b")
save(trim(dark.crop((160, 224, 320, 320))), "roof_slate")    # diagonal slate roof slab
# --- extras: cone roofs (dark + tan), plank decks, iron fence, railing, cobble ground
save(trim(extras.crop((128, 292, 256, 512))), "roof_cone_dark")   # big cone only (small caps row excluded)
save(trim(extras.crop((384, 292, 512, 512))), "roof_cone_tan")
save(trim(extras.crop((192, 128, 320, 256))), "deck_round")
save(trim(extras.crop((320, 128, 448, 256))), "deck_frame")
save(trim(extras.crop((448, 128, 512, 256))), "railing_wood")
save(trim(extras.crop((128, 0, 256, 64))), "fence_iron_a")
save(trim(extras.crop((256, 0, 384, 64))), "fence_iron_b")
save(extras.crop((0, 0, 128, 128)), "cobble_brown_128")
print("done")
