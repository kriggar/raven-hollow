# Render a level_painter draft through the REAL zone engine: draft JSON ->
# temporary "studio_canvas" zone injected into zone_defs.gd -> boot it with
# RH_MAP=studio_canvas and screenshot. Clean up afterwards with:
#   git checkout -- scripts/zone_defs.gd
# Usage: python tools/studio/render_draft.py <draft.json> <tiles_w> <tiles_h> <biome>
import io
import json
import sys

draft = json.load(io.open(sys.argv[1], encoding="utf-8"))
tw, th, biome = int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
W, H = tw * 32, th * 32

L = []
L.append('\t"studio_canvas": {')
L.append('\t\t"built": true,')
L.append('\t\t"name": "Studio Canvas",')
L.append('\t\t"continent": 1, "region": "border", "biome": "%s",' % biome)
L.append('\t\t"tiles_w": %d, "tiles_h": %d,' % (tw, th))
L.append('\t\t"dusk_tint": Color(0.9, 0.85, 0.75),')
L.append('\t\t"player_spawn": Vector2(%d.0, %d.0),' % (W // 2, H // 2))
L.append('\t\t"tree_density": %s,' % float(draft.get("tree_density", 0.4)))
# water: a river shore (feathered banks + sheen via zone_builder._build_river)
river = draft.get("river")
if river:
    L.append('\t\t"river": [%s],' % ", ".join(
        "Vector2(%d, %d)" % (int(p[0]), int(p[1])) for p in river))
    L.append('\t\t"river_width": %s,' % float(draft.get("river_width", 190.0)))
    rc = draft.get("river_color", [0.20, 0.28, 0.34, 0.92])
    L.append('\t\t"river_color": Color(%s, %s, %s, %s),' % (rc[0], rc[1], rc[2], rc[3]))
if draft.get("sea_edges"):
    L.append('\t\t"sea_edges": [%s],' % ", ".join(
        "Rect2(%d, %d, %d, %d)" % (int(r[0]), int(r[1]), int(r[2]), int(r[3]))
        for r in draft["sea_edges"]))
roads = draft.get("roads") or [[[140, H // 2], [W // 2, H // 2 + 20], [W - 140, H // 2]]]
L.append('\t\t"roads": [')
for rd in roads:
    L.append('\t\t\t[%s],' % ", ".join(
        "Vector2(%d, %d)" % (int(p[0]), int(p[1])) for p in rd))
L.append('\t\t],')
L.append('\t\t"landmarks": [')
for lm in draft.get("landmarks", []):
    extra = ""
    if lm.get("count"):
        extra += ', "count": %d' % int(lm["count"])
    if lm.get("dir"):
        extra += ', "dir": "%s"' % lm["dir"]
    x = max(180, min(W - 180, int(lm["x"])))
    y = max(180, min(H - 180, int(lm["y"])))
    L.append('\t\t\t{"type": "%s", "pos": Vector2(%d, %d)%s},' % (lm["type"], x, y, extra))
L.append('\t\t],')
L.append('\t\t"warm_patches": [],')
L.append('\t\t"vignettes": [')
for v in draft.get("vignettes", []):
    x = max(180, min(W - 180, int(v["x"])))
    y = max(180, min(H - 180, int(v["y"])))
    L.append('\t\t\t{"kind": "%s", "pos": Vector2(%d, %d)},' % (v["kind"], x, y))
L.append('\t\t],')
L.append('\t\t"waystations": [], "border_gaps": [], "travel_points": [], "creature_table": [],')
L.append('\t},')
block = "\n".join(L) + "\n"

Z = "scripts/zone_defs.gd"
z = io.open(Z, encoding="utf-8").read()
if '"studio_canvas"' in z:
    print("studio_canvas already injected - run: git checkout -- scripts/zone_defs.gd")
    sys.exit(1)
anchor = '\t"iron_vein": {'
assert z.count(anchor) == 1
z = z.replace(anchor, block + anchor, 1)
io.open(Z, "w", encoding="utf-8", newline="\n").write(z)
print("injected studio_canvas (%dx%d %s) | verdict: %s"
      % (tw, th, biome, draft.get("_gate_verdict", "PASSED GATES")))
