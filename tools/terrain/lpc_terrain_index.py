"""Build data/lpc_terrain_v7.json from the LPC Terrains v7 Tiled tileset.

Each tile in terrain-v7.tsx carries terrain="tl,tr,bl,br" (corner terrain ids).
The JSON gives the painter a corner-combo -> tile-id lookup (dual-grid autotile).
Source: _downloads/scout_2026_07/terrain/lpc_terrains (CC-BY-SA 3.0/4.0, credited
in assets/art/terrain/CREDITS_LPC_TERRAINS.txt). Run from the repo root.
"""
import json, os, sys, shutil
import xml.etree.ElementTree as ET

SRC = "_downloads/scout_2026_07/terrain/lpc_terrains/lpc-terrains"
OUT_JSON = "data/lpc_terrain_v7.json"
OUT_PNG = "assets/art/terrain/lpc_terrain_v7.png"

root = ET.parse(os.path.join(SRC, "terrain-v7.tsx")).getroot()
names = [t.attrib["name"] for t in root.findall("./terraintypes/terrain")]
cols = int(root.attrib["columns"])
tiles = {}
by_combo = {}
for t in root.findall("tile"):
    if "terrain" not in t.attrib:
        continue
    tid = int(t.attrib["id"])
    c = [int(v) if v != "" else -1 for v in t.attrib["terrain"].split(",")]
    if any(v < 0 for v in c):
        continue
    tiles[tid] = c
    by_combo.setdefault(",".join(map(str, c)), []).append(tid)
# Drop blank tiles (the sheet has empty white/transparent cells that still
# carry a terrain attribute) so the painter never stamps a hole.
try:
    from PIL import Image
    _img = Image.open(os.path.join(SRC, "terrain-v7.png")).convert("RGBA")
    def _blank(tid):
        x = (tid % cols) * 32; y = (tid // cols) * 32
        px = list(_img.crop((x, y, x + 32, y + 32)).getdata())
        opaque = [q for q in px if q[3] > 8]
        if len(opaque) < 512:
            return True
        m = sum(q[0] + q[1] + q[2] for q in opaque) / (3 * len(opaque))
        var = sum((q[0] + q[1] + q[2]) / 3 - m for q in opaque)
        spread = max(max(q[:3]) for q in opaque) - min(min(q[:3]) for q in opaque)
        return m > 240 and spread < 12
    _drop = [tid for tid in tiles if _blank(tid)]
    for tid in _drop:
        c = tiles.pop(tid)
        key = ",".join(map(str, c))
        by_combo[key] = [t for t in by_combo[key] if t != tid]
        if not by_combo[key]:
            del by_combo[key]
    print("dropped blank tiles:", _drop)
except ImportError:
    print("PIL missing: blank-tile filter skipped")
pairs = {}
for tid, c in tiles.items():
    s = sorted(set(c))
    if len(s) == 2:
        pairs.setdefault(f"{s[0]},{s[1]}", set()).add(tid)
data = {
    "sheet": "res://assets/art/terrain/lpc_terrain_v7.png",
    "columns": cols,
    "tile": 32,
    "names": names,
    "tiles": {str(k): v for k, v in sorted(tiles.items())},
    "by_combo": by_combo,
    "pairs": {k: sorted(v) for k, v in pairs.items()},
}
os.makedirs("data", exist_ok=True)
with open(OUT_JSON, "w", encoding="utf-8") as f:
    json.dump(data, f, separators=(",", ":"))
if not os.path.exists(OUT_PNG):
    shutil.copyfile(os.path.join(SRC, "terrain-v7.png"), OUT_PNG)
# KEYED OVERLAY SHEET: every mixed tile that has Grass at a corner gets its
# grass pixels made transparent, so cobble/soil edges can be layered directly
# over dirt or any other base (the sheet has no Dirt<->Cobble pair).
OUT_KEYED = "assets/art/terrain/lpc_terrain_v7_keyed.png"
try:
    from PIL import Image
    img = Image.open(os.path.join(SRC, "terrain-v7.png")).convert("RGBA")
    grass_id = names.index("Grass")
    palette = set()
    for tid in by_combo.get(f"{grass_id},{grass_id},{grass_id},{grass_id}", []):
        x = (tid % cols) * 32; y = (tid // cols) * 32
        for q in img.crop((x, y, x + 32, y + 32)).getdata():
            if q[3] > 8:
                palette.add(q[:3])
    keyed = img.copy()
    px = keyed.load()
    changed = 0
    for tid, c in tiles.items():
        if grass_id not in c or all(v == grass_id for v in c):
            continue
        x0 = (tid % cols) * 32; y0 = (tid // cols) * 32
        for yy in range(y0, y0 + 32):
            for xx in range(x0, x0 + 32):
                r, g, b, a = px[xx, yy]
                if a > 8 and (r, g, b) in palette:
                    px[xx, yy] = (r, g, b, 0)
                    changed += 1
    keyed.save(OUT_KEYED)
    data["sheet_keyed"] = "res://" + OUT_KEYED
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    print("keyed sheet:", OUT_KEYED, "grass palette colours", len(palette), "pixels keyed", changed)
except ImportError:
    print("PIL missing: keyed sheet skipped")
print("terrains", len(names), "tiles", len(tiles), "combos", len(by_combo), "pairs", len(pairs))
print("wrote", OUT_JSON, "and", OUT_PNG)
