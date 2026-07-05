# tools/studio/test_solver.py  —  Stage C solver unit test (Blueprint #110, test a)
#
# Exercises the ASSEMBLY SOLVER with NO model: 20 randomized synthetic cluster
# sets across random zones/roads/biomes. For every produced layout it asserts:
#   * zero footprint violations (every pair >= rad(a)+rad(b), studio radii)
#   * zero road overlaps        (every landmark footprint clear of the slab)
#   * all landmarks in bounds
#
#   python tools/studio/test_solver.py
import math
import os
import random
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import paint  # noqa: E402
import extract_patterns as ep  # noqa: E402

rad = paint.rad
ROAD_HALF = paint.ROAD_HALF

# a spread of legal landmark types to build synthetic clusters from
TYPES = sorted(ep.BIG | ep.MID | {"lamp", "cairn", "bones", "rocks", "stump",
                                  "brazier", "signboard", "camp", "lone_tree"})


def random_zone(rng):
    tw = rng.randint(120, 320)
    th = rng.randint(96, 256)
    W, H = tw * 32, th * 32
    # 1-3 random gate-to-gate road polylines
    roads = []
    for _ in range(rng.randint(1, 3)):
        if rng.random() < 0.5:  # horizontal-ish
            y = rng.uniform(H * 0.2, H * 0.8)
            roads.append([[120, y], [W / 2, y + rng.uniform(-200, 200)], [W - 120, y]])
        else:                    # vertical-ish
            x = rng.uniform(W * 0.2, W * 0.8)
            roads.append([[x, 120], [x + rng.uniform(-200, 200), H / 2], [x, H - 120]])
    return W, H, tw, th, roads


def random_clusters(rng):
    """Directly drive the solver: place N synthetic templates as concept
    clusters, using stage_b_fill-style member rings + real library templates."""
    n = rng.randint(4, 8)
    clusters = []
    hints = ["roadside", "far-from-road", "corner", "center"]
    for _ in range(n):
        m = rng.randint(2, 7)
        members = []
        for k in range(m):
            ang = 2 * math.pi * k / m + rng.uniform(-0.3, 0.3)
            r = rng.uniform(0, 260)
            members.append({"type": rng.choice(TYPES),
                            "dx": int(r * math.cos(ang)),
                            "dy": int(r * math.sin(ang))})
        radius = 40.0
        for mm in members:
            radius = max(radius, math.hypot(mm["dx"], mm["dy"]) + rad(mm["type"]))
        clusters.append({"members": members, "radius": radius,
                         "hint": rng.choice(hints)})
    return clusters


def assemble(W, H, roads, biome, clusters, seed):
    """Run the solver's placement + enforce exactly as paint() does."""
    solver = paint.Solver(W, H, roads, biome, seed=seed)
    items = []
    for c in sorted(clusters, key=lambda c: -c["radius"]):
        cx, cy = solver.place_center(c["radius"], c["hint"])
        solver.centers.append((cx, cy, c["radius"], "test"))
        for m in c["members"]:
            items.append({"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]})
    solver.enforce(items)
    for it in items:
        it["x"] = int(round(min(max(it["x"], paint.EDGE), W - paint.EDGE)))
        it["y"] = int(round(min(max(it["y"], paint.EDGE), H - paint.EDGE)))
    return items


def check(items, W, H, roads):
    viol = {"footprint": [], "road": [], "bounds": []}
    for i in range(len(items)):
        a = items[i]
        # bounds
        if not (120 <= a["x"] <= W - 120 and 120 <= a["y"] <= H - 120):
            viol["bounds"].append((a["type"], a["x"], a["y"]))
        # road: footprint must be clear of the slab
        rd, _ = paint.road_near((a["x"], a["y"]), roads)
        if rd < ROAD_HALF + rad(a["type"]):
            viol["road"].append((a["type"], round(rd, 1), round(ROAD_HALF + rad(a["type"]), 1)))
        for j in range(i + 1, len(items)):
            b = items[j]
            need = rad(a["type"]) + rad(b["type"])
            d = math.hypot(a["x"] - b["x"], a["y"] - b["y"])
            if d < need:
                viol["footprint"].append((a["type"], b["type"], round(d, 1), round(need, 1)))
    return viol


def main():
    biomes = ["bog", "moor", "farmland", "tundra", "volcanic", "port",
              "deadforest", "ridge", "steppe", "cave"]
    total_lm = 0
    fails = 0
    for t in range(20):
        rng = random.Random(1000 + t)
        W, H, tw, th, roads = random_zone(rng)
        biome = biomes[t % len(biomes)]
        clusters = random_clusters(rng)
        items = assemble(W, H, roads, biome, clusters, seed=1000 + t)
        total_lm += len(items)
        viol = check(items, W, H, roads)
        nbad = sum(len(v) for v in viol.values())
        status = "OK " if nbad == 0 else "BAD"
        print("  [%s] test %2d  zone %dx%d %-10s clusters=%d landmarks=%3d  "
              "footprint=%d road=%d bounds=%d"
              % (status, t, tw, th, biome, len(clusters), len(items),
                 len(viol["footprint"]), len(viol["road"]), len(viol["bounds"])))
        if nbad:
            fails += 1
            for kind, lst in viol.items():
                for v in lst[:4]:
                    print("        %s: %r" % (kind, v))
    print("\n  20 synthetic scenes, %d total landmarks placed." % total_lm)
    assert fails == 0, "%d/20 scenes had violations" % fails
    print("  ALL GREEN: zero footprint violations, zero road overlaps, all in bounds.")


if __name__ == "__main__":
    main()
