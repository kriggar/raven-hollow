# tools/studio/extract_patterns.py  —  THE FABLE PATTERN LIBRARY (Blueprint #110, Stage 0)
#
# Parse every BUILT zone in scripts/zone_defs.gd, chain-link landmarks that sit
# within <350px into CLUSTER TEMPLATES, and store each with its members'
# EXACT relative offsets (Fable's hand, preserved to the pixel), biome, role
# tag, footprint radius, source zone, and parametrization fields. The geometry
# floor of a machine-painted town is Fable-identical BY CONSTRUCTION: the
# painter never invents geometry, it composes these.
#
#   python tools/studio/extract_patterns.py            # build + stats
#   python tools/studio/extract_patterns.py --verify   # + offset spot-check
#
# Output: _downloads/_studio/pattern_library.json
import io
import json
import math
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
ZONE_DEFS = os.path.join(ROOT, "scripts", "zone_defs.gd")
OUT = os.path.join(ROOT, "_downloads", "_studio", "pattern_library.json")

LINK_DIST = 350.0          # chain-link threshold (Blueprint Stage 0)

# ---- footprint radii: MIRROR studio.py validate() def_author (keep in sync) --
BIG = {"tavern", "cottage", "manor", "shop", "workshop", "warehouse",
       "barn", "cabin", "dark_keep", "forge", "spire", "shed", "hamlet"}
MID = {"statue", "fountain", "well", "copper_well", "dolmen", "pit",
       "graves", "stall", "plaza", "crane", "wreck", "boat"}


def rad(t):
    return 150.0 if t in BIG else (90.0 if t in MID else 40.0)


# ---- Stage C owns these; templates never store them (auto-placed by rule) ----
MECHANICAL = {"lamp", "chimney_smoke"}

# ---- role tagging (Blueprint's 8 tags). Disjoint type -> role assignment. ----
ROLE_TYPES = {
    "market":    {"stall", "plaza", "fountain", "signboard", "shop"},
    "sacred":    {"inscription_stone", "dolmen", "statue", "stone_row",
                  "cairn", "gift_field", "copper_well"},
    "industry":  {"forge", "workshop", "lava_vent", "ore_rocks", "warehouse",
                  "crane", "cargo", "salt_pan", "barn", "shed", "pier", "boat"},
    "dwelling":  {"cottage", "manor", "tavern", "cabin", "hamlet", "well"},
    "watch":     {"camp", "brazier"},
    "grave":     {"graves", "bones"},
    "curiosity": {"lone_tree", "trunk_hollow", "pond", "stump", "rocks"},
    "dread":     {"pit", "lichen_glow", "drowned_fence", "wreck", "spire",
                  "dark_keep", "thread_lines", "ledger_tablet"},
}
ROLE_PRIORITY = ["dread", "grave", "sacred", "industry", "market",
                 "dwelling", "watch", "curiosity"]
_TYPE_ROLE = {t: r for r, ts in ROLE_TYPES.items() for t in ts}


def role_of(types):
    score = {r: 0 for r in ROLE_TYPES}
    for t in types:
        r = _TYPE_ROLE.get(t)
        if r:
            score[r] += 1
    best = max(score.values())
    if best == 0:
        return "curiosity"
    for r in ROLE_PRIORITY:
        if score[r] == best:
            return r
    return "curiosity"


# --------------------------------------------------------------- parsing ------
_ZONE_RE = re.compile(r'\n\t"(\w+)": \{\n\t\t"built": true(.*?)\n\t\},', re.S)
_LM_RE = re.compile(
    r'\{"type": "(\w+)", "pos": Vector2\((-?\d+), (-?\d+)\)([^}]*)\}')
_VIG_RE = re.compile(
    r'\{"kind": "(\w+)", "pos": Vector2\((-?\d+), (-?\d+)\)\}')


def _extract_roads(body):
    m = re.search(r'"roads":\s*\[', body)
    if not m:
        return []
    i = m.end() - 1
    depth = 0
    start = i
    while i < len(body):
        if body[i] == "[":
            depth += 1
        elif body[i] == "]":
            depth -= 1
            if depth == 0:
                break
        i += 1
    block = body[start:i + 1]
    roads = []
    for inner in re.finditer(r'\[((?:\s*Vector2\(-?\d+,\s*-?\d+\)\s*,?)+)\]', block):
        pts = re.findall(r'Vector2\((-?\d+),\s*(-?\d+)\)', inner.group(1))
        if pts:
            roads.append([[int(x), int(y)] for x, y in pts])
    return roads


def parse_zones(text):
    zones = []
    for m in _ZONE_RE.finditer(text):
        zid, body = m.group(1), m.group(2)
        name = re.search(r'"name": "([^"]+)"', body)
        biome = re.search(r'"biome": "(\w+)"', body)
        region = re.search(r'"region": "(\w+)"', body)
        cont = re.search(r'"continent": (\d+)', body)
        tiles = re.search(r'"tiles_w": (\d+), "tiles_h": (\d+)', body)
        if not (name and biome and tiles):
            continue
        lms = []
        for lm in _LM_RE.finditer(body):
            t, x, y, rest = lm.group(1), int(lm.group(2)), int(lm.group(3)), lm.group(4)
            cnt = re.search(r'"count": (\d+)', rest)
            live = re.search(r'"live": (true|false)', rest)
            d = {"type": t, "x": x, "y": y}
            if cnt:
                d["count"] = int(cnt.group(1))
            if live:
                d["live"] = (live.group(1) == "true")
            lms.append(d)
        vigs = [{"kind": v.group(1), "x": int(v.group(2)), "y": int(v.group(3))}
                for v in _VIG_RE.finditer(body)]
        zones.append({
            "id": zid, "name": name.group(1), "biome": biome.group(1),
            "region": region.group(1) if region else "",
            "continent": int(cont.group(1)) if cont else 1,
            "capital": '"capital": true' in body,
            "tiles_w": int(tiles.group(1)), "tiles_h": int(tiles.group(2)),
            "landmarks": lms, "vignettes": vigs, "roads": _extract_roads(body),
        })
    return zones


# ------------------------------------------------------------- clustering -----
def chain_clusters(points, link=LINK_DIST):
    """Union-find: two points chain-link if within `link` px. Returns groups
    of indices (connected components)."""
    n = len(points)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for i in range(n):
        for j in range(i + 1, n):
            dx = points[i]["x"] - points[j]["x"]
            dy = points[i]["y"] - points[j]["y"]
            if dx * dx + dy * dy < link * link:
                union(i, j)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


def _size(n):
    return "solo" if n <= 1 else "small" if n <= 3 else "medium" if n <= 6 else "large"


def build_templates(zone):
    struct = [lm for lm in zone["landmarks"] if lm["type"] not in MECHANICAL]
    if not struct:
        return []
    groups = chain_clusters(struct)
    templates = []
    for k, idxs in enumerate(sorted(groups, key=lambda g: -len(g))):
        members = [struct[i] for i in idxs]
        cx = round(sum(m["x"] for m in members) / len(members))
        cy = round(sum(m["y"] for m in members) / len(members))
        # exact relative offsets — Fable's hand preserved to the pixel
        out_members = []
        for m in members:
            d = {"type": m["type"], "dx": m["x"] - cx, "dy": m["y"] - cy}
            if "count" in m:
                d["count"] = m["count"]
            if "live" in m:
                d["live"] = m["live"]
            out_members.append(d)
        out_members.sort(key=lambda d: (d["dy"], d["dx"]))
        types = [m["type"] for m in members]
        role = role_of(types)
        # footprint radius = furthest member edge from cluster centre
        radius = 0.0
        for m in members:
            radius = max(radius, math.hypot(m["x"] - cx, m["y"] - cy) + rad(m["type"]))
        # span = widest pairwise gap (a tightness measure)
        span = 0.0
        for i in range(len(members)):
            for j in range(i + 1, len(members)):
                span = max(span, math.hypot(members[i]["x"] - members[j]["x"],
                                            members[i]["y"] - members[j]["y"]))
        # attach the nearest vignette(s) to this cluster (Fable's story pairing)
        vigs = []
        for v in zone["vignettes"]:
            near = min((math.hypot(v["x"] - m["x"], v["y"] - m["y"]) for m in members),
                       default=1e9)
            if near <= LINK_DIST + 60:
                vigs.append({"kind": v["kind"], "dx": v["x"] - cx, "dy": v["y"] - cy})
        # name from composition
        tcount = {}
        for t in types:
            tcount[t] = tcount.get(t, 0) + 1
        top = sorted(tcount.items(), key=lambda kv: (-kv[1], kv[0]))
        name = "%s: %s" % (role, "+".join("%s%s" % (t, ("x%d" % c if c > 1 else ""))
                                          for t, c in top[:3]))
        has_big = any(m["type"] in BIG for m in members)
        templates.append({
            "id": "%s_c%d" % (zone["id"], k),
            "source_zone": zone["id"], "name": name, "role": role,
            "biome": zone["biome"], "region": zone["region"],
            "continent": zone["continent"], "capital": zone["capital"],
            "center": [cx, cy],
            "members": out_members,
            "vignettes": vigs,
            "n_members": len(members),
            "radius": round(radius, 1), "span": round(span, 1),
            "size": _size(len(members)),
            "scalable_types": sorted({m["type"] for m in members if "count" in m}),
            "jitter": 12,
            "mirror_x_ok": True,
            "rotate_ok": not has_big,
        })
    return templates


# ----------------------------------------------------------------- main -------
def build_library():
    text = io.open(ZONE_DEFS, encoding="utf-8").read()
    zones = parse_zones(text)
    clusters = []
    for z in zones:
        clusters.extend(build_templates(z))
    by_role, by_biome, by_size = {}, {}, {}
    for c in clusters:
        by_role[c["role"]] = by_role.get(c["role"], 0) + 1
        by_biome[c["biome"]] = by_biome.get(c["biome"], 0) + 1
        by_size[c["size"]] = by_size.get(c["size"], 0) + 1
    lib = {
        "source": "scripts/zone_defs.gd",
        "link_dist": LINK_DIST,
        "n_zones": len(zones),
        "n_clusters": len(clusters),
        "by_role": by_role,
        "by_biome": by_biome,
        "by_size": by_size,
        "roles": sorted(ROLE_TYPES),
        "clusters": clusters,
    }
    return lib, zones


def print_stats(lib):
    print("FABLE PATTERN LIBRARY")
    print("  zones parsed     : %d" % lib["n_zones"])
    print("  cluster templates: %d" % lib["n_clusters"])
    print("  by role :")
    for r in ROLE_PRIORITY:
        print("     %-10s %3d" % (r, lib["by_role"].get(r, 0)))
    print("  by biome:")
    for b, n in sorted(lib["by_biome"].items(), key=lambda kv: -kv[1]):
        print("     %-10s %3d" % (b, n))
    print("  by size :")
    for s in ("solo", "small", "medium", "large"):
        print("     %-10s %3d" % (s, lib["by_size"].get(s, 0)))


def verify(lib, zones):
    """Spot-dump 5 templates and assert each member's reconstructed absolute
    position (center + offset) matches a real landmark in the source zone."""
    zmap = {z["id"]: z for z in zones}
    print("\nOFFSET VERIFICATION (reconstruct center+offset -> source landmark):")
    # pick 5 diverse templates: largest per a few roles
    picks = []
    seen_roles = set()
    for c in sorted(lib["clusters"], key=lambda c: -c["n_members"]):
        if c["role"] not in seen_roles or len(picks) < 5:
            picks.append(c)
            seen_roles.add(c["role"])
        if len(picks) >= 5:
            break
    ok_all = True
    for c in picks:
        z = zmap[c["source_zone"]]
        src = {(lm["x"], lm["y"], lm["type"]) for lm in z["landmarks"]}
        cx, cy = c["center"]
        miss = []
        for m in c["members"]:
            key = (cx + m["dx"], cy + m["dy"], m["type"])
            if key not in src:
                miss.append(key)
        status = "PASS" if not miss else "FAIL %r" % miss
        ok_all = ok_all and not miss
        print("  [%s] %s  (%s, %d members, r=%.0f)  ->  %s"
              % (status, c["id"], c["role"], c["n_members"], c["radius"], status))
        # dump the template body compactly
        print("       biome=%s size=%s center=%s scalable=%s vigs=%s"
              % (c["biome"], c["size"], c["center"], c["scalable_types"],
                 [v["kind"] for v in c["vignettes"]]))
        for m in c["members"][:8]:
            print("         %-16s dx=%-5d dy=%-5d %s"
                  % (m["type"], m["dx"], m["dy"],
                     ("count=%d" % m["count"]) if "count" in m else ""))
        if len(c["members"]) > 8:
            print("         ... +%d more" % (len(c["members"]) - 8))
    print("  OFFSET VERIFY: %s" % ("ALL PASS" if ok_all else "FAILURES ABOVE"))
    return ok_all


def main():
    lib, zones = build_library()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, "w", encoding="utf-8").write(json.dumps(lib, indent=1))
    print_stats(lib)
    print("\n  -> %s" % OUT)
    if "--verify" in sys.argv:
        ok = verify(lib, zones)
        assert lib["n_clusters"] >= 100, "need >=100 clusters, got %d" % lib["n_clusters"]
        print("  ASSERT n_clusters >= 100: PASS (%d)" % lib["n_clusters"])
        if not ok:
            raise SystemExit("offset verification FAILED")


if __name__ == "__main__":
    main()
