# tools/studio/paint.py  —  THE STAGED PAINTER (Blueprint #110)
#
#   MODEL = semantics only (which Fable clusters, what story, what mood)
#   CODE  = ALL geometry (Stage C assembly solver: where things physically go)
#   WALLS = studio.py's def_author validators reject anything substandard
#
# Stage A (model)  : brief -> cluster CONCEPTS (roles, moods, names, hints).
# Stage B (model)  : gap-fill LOCAL prop offsets, only when no template fits.
# Stage C (python) : select Fable templates -> poisson-disc place cluster
#                    centres honouring roads -> footprint relaxation with the
#                    type-aware radii from studio.validate() -> auto lamps /
#                    smoke / edge fill / quadrant anchors -> run the full walls.
#
# Output is def_author-shaped JSON so render_draft.py consumes it directly:
#   {zone_id, roads, landmarks:[{type,x,y,count?}], vignettes:[{kind,x,y}]}
#
#   python tools/studio/paint.py --brief brief.json -o out.json
#   python tools/studio/paint.py --brief brief.json --no-model -o out.json
import argparse
import io
import json
import math
import os
import random
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import studio  # noqa: E402  reuse ask() + the def_author validators (the walls)
import extract_patterns as ep  # noqa: E402  shared radii + role tagging

ROOT = ep.ROOT
LIB_PATH = os.path.join(ROOT, "_downloads", "_studio", "pattern_library.json")

# ---- geometry constants ------------------------------------------------------
ROAD_HALF = 44.0     # slab half-width (zone_builder draws 88px slab rects)
ROAD_CLEAR = 60.0    # Bible II.5: keep 60px clear of slab edges
EDGE = 180.0         # keep members >=180px from zone bounds (render clamp is 180)
rad = ep.rad         # type-aware footprint radius (mirrors studio.validate)


def mass(t):
    return 4.0 if t in ep.BIG else (2.0 if t in ep.MID else 1.0)


# ---- biome legality (mirror studio.py) + native filler for dressing ----------
FORBID = {
    "bog": {"lava_vent", "forge", "lichen_glow", "spire", "gift_field", "copper_well"},
    "deadforest": {"lava_vent", "forge", "lichen_glow", "pier", "boat", "salt_pan"},
    "tundra": {"lava_vent", "gift_field", "lichen_glow", "salt_pan"},
    "volcanic": {"lichen_glow", "pond", "salt_pan", "pier", "boat"},
    "cave": {"pier", "boat", "wreck", "chimney_smoke", "lava_vent", "salt_pan",
             "gift_field", "lone_tree"},
    "port": {"lava_vent", "lichen_glow", "gift_field", "copper_well"},
    "moor": {"lava_vent", "lichen_glow", "pier", "boat", "salt_pan"},
    "steppe": {"lava_vent", "lichen_glow", "pier", "boat", "salt_pan", "gift_field"},
    "ridge": {"lava_vent", "lichen_glow", "pier", "boat", "salt_pan", "gift_field"},
}
# role -> a legal, universally-safe substitute prop (used when a template member
# is forbidden in the target biome: same SHAPE, native prop — Blueprint Stage 0)
ROLE_SWAP = {
    "market": "stall", "sacred": "stone_row", "industry": "workshop",
    "dwelling": "cottage", "watch": "brazier", "grave": "graves",
    "curiosity": "rocks", "dread": "bones",
}
UNIVERSAL = "rocks"  # legal in every biome
KNOWN = studio.KNOWN_TYPES  # the canonical type authority (the walls)

# biome-native scattered decals (Bible III.9 / I.1) — all small, all biome-legal
BIOME_DECALS = {
    "bog": ["stump", "rocks", "bones"], "moor": ["rocks", "bones", "cairn"],
    "farmland": ["rocks", "stump", "bones"], "tundra": ["rocks", "cairn", "bones"],
    "volcanic": ["rocks", "ore_rocks", "bones"], "port": ["rocks", "cargo", "bones"],
    "deadforest": ["stump", "bones", "rocks"], "ridge": ["rocks", "bones", "cairn"],
    "steppe": ["rocks", "bones", "cairn"], "cave": ["rocks", "bones", "cairn"],
    "wilds": ["rocks", "stump", "bones"],
}


def legal_swap(t, role, biome):
    if t not in KNOWN:                       # drop non-canon library types (plankv)
        t = ROLE_SWAP.get(role, UNIVERSAL)
    bad = FORBID.get(biome, set())
    if t not in bad:
        return t
    for cand in (ROLE_SWAP.get(role, UNIVERSAL), UNIVERSAL, "cairn", "stone_row"):
        if cand not in bad:
            return cand
    return UNIVERSAL


# =============================================================== geometry =====
def seg_dist(p, a, b):
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay), (ax, ay)
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy), (cx, cy)


def road_near(p, roads):
    """min distance from p to any road segment, and the closest road point."""
    best, bpt = 1e18, None
    for poly in roads:
        if len(poly) == 1:
            d = math.hypot(p[0] - poly[0][0], p[1] - poly[0][1])
            if d < best:
                best, bpt = d, tuple(poly[0])
            continue
        for i in range(len(poly) - 1):
            d, pt = seg_dist(p, poly[i], poly[i + 1])
            if d < best:
                best, bpt = d, pt
    return (best, bpt) if bpt else (1e18, None)


# ==================================================== Stage C: the solver =====
class Solver:
    """Pure-python assembly. Given a zone (W,H,roads,biome) and a list of
    concept clusters already bound to Fable templates, produce a validator-clean
    landmark layout. No model is touched here."""

    def __init__(self, W, H, roads, biome, seed=0):
        self.W, self.H, self.roads, self.biome = W, H, roads, biome
        self.rng = random.Random(seed)
        self.centers = []   # placed cluster centres [(x,y,radius,role)]

    # -- place one cluster centre honouring roads/spacing/bounds/hint ----------
    def place_center(self, radius, hint):
        W, H = self.W, self.H
        margin = radius + 200.0
        lo_x, hi_x = margin, max(margin + 1, W - margin)
        lo_y, hi_y = margin, max(margin + 1, H - margin)
        road_floor = radius + ROAD_HALF + ROAD_CLEAR   # every member 60px clear
        # progressively relax constraints so a spot is ALWAYS found
        for phase in range(5):
            for _ in range(2500):
                x = self.rng.uniform(lo_x, hi_x)
                y = self.rng.uniform(lo_y, hi_y)
                if hint == "corner":
                    x = lo_x if self.rng.random() < 0.5 else hi_x
                    y = lo_y if self.rng.random() < 0.5 else hi_y
                    x += self.rng.uniform(0, (hi_x - lo_x) * 0.25) * (1 if x == lo_x else -1)
                    y += self.rng.uniform(0, (hi_y - lo_y) * 0.25) * (1 if y == lo_y else -1)
                elif hint == "center":
                    x = (lo_x + hi_x) / 2 + self.rng.uniform(-1, 1) * (hi_x - lo_x) * 0.18
                    y = (lo_y + hi_y) / 2 + self.rng.uniform(-1, 1) * (hi_y - lo_y) * 0.18
                rd, _ = road_near((x, y), self.roads)
                if rd < road_floor:
                    continue
                if phase < 3 and hint == "far-from-road" and rd < 650:
                    continue
                if phase < 2 and hint == "roadside" and rd > road_floor + 340:
                    continue
                ok = True
                for (cx, cy, cr, _r) in self.centers:
                    need = radius + cr + 140.0 - phase * 40.0
                    if math.hypot(x - cx, y - cy) < need:
                        ok = False
                        break
                if ok:
                    return x, y
        # last resort: centre of the zone
        return (lo_x + hi_x) / 2, (lo_y + hi_y) / 2

    # -- the enforce loop: zero footprint clips, zero road overlap, in bounds --
    def enforce(self, items, iters=240):
        W, H = self.W, self.H
        for _ in range(iters):
            moved = False
            n = len(items)
            for i in range(n):
                ti = items[i]["type"]
                ri = rad(ti)
                for j in range(i + 1, n):
                    tj = items[j]["type"]
                    # PAD keeps pairs a hair beyond the wall so int-rounding at
                    # the end never drops a pair below studio.validate's strict
                    # `d < need` clip test.
                    need = ri + rad(tj) + 2.5
                    dx = items[i]["x"] - items[j]["x"]
                    dy = items[i]["y"] - items[j]["y"]
                    d = math.hypot(dx, dy)
                    if d < need - 0.5:
                        if d < 1e-6:
                            ang = self.rng.uniform(0, 2 * math.pi)
                            ux, uy, d = math.cos(ang), math.sin(ang), 1e-6
                        else:
                            ux, uy = dx / d, dy / d
                        push = (need - d) / 2.0 + 0.3
                        mi, mj = mass(ti), mass(tj)
                        tot = mi + mj
                        items[i]["x"] += ux * push * 2 * mj / tot
                        items[i]["y"] += uy * push * 2 * mj / tot
                        items[j]["x"] -= ux * push * 2 * mi / tot
                        items[j]["y"] -= uy * push * 2 * mi / tot
                        moved = True
            # road repulsion
            for it in items:
                minrd = ROAD_HALF + rad(it["type"]) + ROAD_CLEAR
                rd, pt = road_near((it["x"], it["y"]), self.roads)
                if pt and rd < minrd:
                    if rd < 1e-6:
                        ux, uy, rd = 1.0, 0.0, 1e-6
                    else:
                        ux, uy = (it["x"] - pt[0]) / rd, (it["y"] - pt[1]) / rd
                    it["x"] += ux * (minrd - rd + 0.6)
                    it["y"] += uy * (minrd - rd + 0.6)
                    moved = True
            # bounds
            for it in items:
                nx = min(max(it["x"], EDGE), W - EDGE)
                ny = min(max(it["y"], EDGE), H - EDGE)
                if nx != it["x"] or ny != it["y"]:
                    it["x"], it["y"] = nx, ny
                    moved = True
            if not moved:
                break
        return items


# ============================================= Stage C helpers: instances =====
def instantiate(template, biome, hint, rng, size_hint=None):
    """Turn a library template into a concrete cluster: biome dressing swaps,
    count-scaling, +-jitter, optional mirror. Returns local members + vignettes
    (offsets from cluster centre) and the footprint radius."""
    scale = {"small": 0.9, "medium": 1.0, "large": 1.35}.get(size_hint or template["size"], 1.0)
    mirror = template.get("mirror_x_ok") and rng.random() < 0.4
    members = []
    for m in template["members"]:
        t = legal_swap(m["type"], template["role"], biome)
        dx = m["dx"] * (-1 if mirror else 1) + rng.randint(-template["jitter"], template["jitter"])
        dy = m["dy"] + rng.randint(-template["jitter"], template["jitter"])
        out = {"type": t, "dx": dx, "dy": dy}
        if "count" in m:
            out["count"] = max(3, min(14, int(round(m["count"] * scale))))
        members.append(out)
    vigs = [{"kind": v["kind"], "dx": v["dx"] * (-1 if mirror else 1), "dy": v["dy"]}
            for v in template["vignettes"]]
    radius = 40.0
    for m in members:
        radius = max(radius, math.hypot(m["dx"], m["dy"]) + rad(m["type"]))
    return members, vigs, radius


# =================================================== Stage A / B: the model ====
STAGE_A_SYS = (
    "You are the CONCEPT DIRECTOR for painting a town in 'Raven Hollow', a "
    "gothic Eastern-European dark-fantasy pixel RPG. You DO NOT place anything "
    "in space and you invent NO coordinates. You choose which Fable story-"
    "clusters belong in this town and give each a name, mood and story.\n"
    "Return PURE JSON only:\n"
    '{"clusters":[{"name":str,"role":one of '
    "[market,sacred,industry,dwelling,watch,grave,curiosity,dread],"
    '"mood":str,"size":one of [small,medium,large],'
    '"placement_hint":one of [roadside,far-from-road,corner,center],'
    '"story":one short line}],'
    '"vignettes":[{"kind":one of [murder_scene,boot_prints,cold_camp,'
    "standing_farmer,empty_stall,chalk_handprints,rows_of_twelve,childs_shoe,"
    'full_granary,burned_farmstead],"attach_to":cluster name}]}\n'
    "Rules: 5-7 clusters; every quadrant of a town wants an anchor so spread the "
    "placement_hints; include EXACTLY one grave OR sacred identity core; include "
    "at least one dread cluster to host a crime; 3-4 vignettes with exactly one "
    "murder_scene. Ground moods in the biome and the brief. No coordinates.")

CURIOSITY_VIGS = ["boot_prints", "cold_camp", "standing_farmer", "empty_stall",
                  "chalk_handprints", "childs_shoe", "full_granary"]
VALID_ROLES = set(ep.ROLE_TYPES)
VALID_VIGS = {"murder_scene", "boot_prints", "cold_camp", "standing_farmer",
              "empty_stall", "chalk_handprints", "rows_of_twelve", "childs_shoe",
              "full_granary", "burned_farmstead", "courier_seal"}


def _extract_json(text):
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S)
    depth = start = 0
    for i, ch in enumerate(text):
        if ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start:i + 1])
                except Exception:
                    continue
    raise ValueError("no JSON object")


def stage_a_model(brief, biome, temperature=0.5):
    user = ("BRIEF: %s\nBIOME: %s\n\nPick the story-clusters. Pure JSON only."
            % (brief, biome))
    raw = studio.ask(STAGE_A_SYS, user, temperature=temperature, model="qwen3:14b")
    obj = _extract_json(raw)
    clusters = []
    for c in obj.get("clusters", []):
        role = str(c.get("role", "")).strip().lower()
        if role not in VALID_ROLES:
            continue
        clusters.append({
            "name": str(c.get("name", role))[:60],
            "role": role,
            "mood": str(c.get("mood", ""))[:60],
            "size": c.get("size") if c.get("size") in ("small", "medium", "large") else "medium",
            "placement_hint": c.get("placement_hint") if c.get("placement_hint") in
            ("roadside", "far-from-road", "corner", "center") else "roadside",
            "story": str(c.get("story", ""))[:120],
        })
    vigs = []
    for v in obj.get("vignettes", []):
        k = str(v.get("kind", "")).strip().lower()
        if k in VALID_VIGS:
            vigs.append({"kind": k, "attach_to": str(v.get("attach_to", ""))})
    if len(clusters) < 4:
        raise ValueError("model returned too few valid clusters")
    return {"clusters": clusters, "vignettes": vigs, "_source": "model"}


# keyword -> role bias, so the deterministic concept honours the brief text
KW_ROLE = [
    (r"graveyard|grave|cemet|barrow|cairn|tomb", "grave"),
    (r"church|chapel|shrine|sacred|altar|monument|stones?|ritual|thread|listen", "sacred"),
    (r"market|square|stall|bazaar|trade", "market"),
    (r"forge|smith|smelt|kiln|foundry|ore|mine", "industry"),
    (r"warehouse|dock|port|wharf|cargo|crane|salt|pier", "industry"),
    (r"tavern|inn|cottage|house|home|farm|hamlet|dwelling|village", "dwelling"),
    (r"watch|guard|outpost|tower|beacon|camp|gate", "watch"),
    (r"ruin|dread|wreck|pit|keep|spire|haunt|curse|drown", "dread"),
    (r"tree|pond|well|hollow|curio|standing", "curiosity"),
]


def stage_a_fallback(brief, biome):
    """Deterministic Bible-compliant town skeleton, biased by brief keywords."""
    low = brief.lower()
    wanted = []
    for pat, role in KW_ROLE:
        if re.search(pat, low):
            wanted.append(role)
    # guarantee an identity core + a life core + a dread host
    skeleton = ["grave" if "grave" in wanted else "sacred", "market",
                "dwelling", "dwelling", "industry", "curiosity", "dread"]
    for r in wanted:
        if r not in skeleton:
            skeleton.append(r)
    # de-dup preserving order, cap 7
    seen, roles = set(), []
    for r in skeleton:
        if r not in seen:
            seen.add(r)
            roles.append(r)
        if len(roles) >= 7:
            break
    hints = ["center", "roadside", "roadside", "corner", "far-from-road",
             "far-from-road", "corner"]
    sizes = ["large", "medium", "medium", "small", "medium", "small", "medium"]
    clusters = [{"name": "%s quarter" % r, "role": r, "mood": biome,
                 "size": sizes[i], "placement_hint": hints[i],
                 "story": "%s in the %s" % (r, biome)}
                for i, r in enumerate(roles)]
    dread_name = next((c["name"] for c in clusters if c["role"] in ("dread", "grave")),
                      clusters[0]["name"])
    vigs = [{"kind": "murder_scene", "attach_to": dread_name},
            {"kind": "boot_prints", "attach_to": dread_name},
            {"kind": "cold_camp", "attach_to": clusters[-1]["name"]},
            {"kind": "standing_farmer", "attach_to": clusters[2]["name"]}]
    return {"clusters": clusters, "vignettes": vigs, "_source": "fallback"}


def stage_b_fill(role, biome, rng):
    """Gap-fill: only reached when the library has NO template for a role.
    Synthesise a tiny legal ring of role-appropriate props (offsets 0-260)."""
    base = ROLE_SWAP.get(role, "rocks")
    n = rng.randint(3, 5)
    members = []
    for k in range(n):
        ang = 2 * math.pi * k / n
        r = rng.uniform(120, 240)
        members.append({"type": legal_swap(base, role, biome),
                        "dx": int(r * math.cos(ang)), "dy": int(r * math.sin(ang))})
    radius = 240 + rad(base)
    return members, [], radius


# ============================================ template selection (Stage C) =====
def select_template(role, size, biome, lib, rng, maxr=1e9):
    cores = [c for c in lib["clusters"] if c["role"] == role and c["n_members"] >= 2]
    exact = [c for c in cores if c["biome"] == biome]
    pool = exact or cores
    if not pool:
        pool = [c for c in lib["clusters"] if c["role"] == role]  # solos of the role
    if not pool:
        return None
    # respect the zone's radius budget so a big Fable core never overruns a
    # small zone (would force footprint clips that fail the walls)
    fit = [c for c in pool if c["radius"] <= maxr]
    pool = fit or sorted(pool, key=lambda c: c["radius"])[:3]
    # prefer size match; keep the richest few; pick weighted-random for variety
    order = {"small": 0, "medium": 1, "large": 2}
    tgt = order.get(size, 1)
    pool = sorted(pool, key=lambda c: (abs(order.get(c["size"], 1) - tgt), -c["n_members"]))
    top = pool[:max(3, len(pool) // 3)]
    return rng.choice(top)


# ==================================================== the full pipeline ========
def paint(brief_obj, use_model=True, seed=None):
    biome = brief_obj["biome"]
    W = brief_obj["tiles_w"] * 32
    H = brief_obj["tiles_h"] * 32
    roads = brief_obj.get("roads") or [[[140, H // 2], [W // 2, H // 2 + 20], [W - 140, H // 2]]]
    seed = seed if seed is not None else brief_obj.get("seed", 7)
    rng = random.Random(seed)
    lib = json.load(io.open(LIB_PATH, encoding="utf-8"))
    log = {"biome": biome, "W": W, "H": H, "seed": seed}

    # -- STAGE A: concept -----------------------------------------------------
    concept = None
    if use_model:
        try:
            concept = stage_a_model(brief_obj["brief"], biome)
        except Exception as exc:  # noqa: BLE001
            log["stage_a_model_error"] = str(exc)[:160]
    if concept is None:
        concept = stage_a_fallback(brief_obj["brief"], biome)
    log["stage_a_source"] = concept["_source"]
    log["n_concept_clusters"] = len(concept["clusters"])

    # zone-size adaptivity: a small zone can't hold many big Fable cores without
    # forcing clips. Budget the per-cluster radius and the cluster count to the
    # zone so the town stays clean and Fable-scaled.
    short = min(W, H)
    maxr = max(220.0, min(520.0, short / 3.0))
    n_cap = 4 if short < 2400 else (5 if short < 3400 else 7)
    # keep the identity core (grave/sacred) + diverse roles up to n_cap
    picked, seen_roles = [], set()
    for c in sorted(concept["clusters"],
                    key=lambda c: 0 if c["role"] in ("grave", "sacred") else 1):
        if len(picked) < n_cap and (c["role"] not in seen_roles or len(picked) < n_cap - 1):
            picked.append(c)
            seen_roles.add(c["role"])
    concept["clusters"] = picked[:n_cap]
    log["maxr"] = round(maxr, 1)
    log["n_clusters_capped"] = len(concept["clusters"])

    # -- STAGE B+C: bind templates, place centres, map to global --------------
    solver = Solver(W, H, roads, biome, seed=seed)
    items = []           # global landmark dicts {type,x,y,count?}
    out_vigs = []        # {kind,x,y}
    stage_b_used = 0
    cluster_records = []
    # place identity/large clusters first for good packing
    order = sorted(concept["clusters"],
                   key=lambda c: {"large": 0, "medium": 1, "small": 2}.get(c["size"], 1))
    name_to_center = {}
    for c in order:
        csize = "medium" if (short < 2400 and c["size"] == "large") else c["size"]
        tpl = select_template(c["role"], csize, biome, lib, rng, maxr=maxr)
        if tpl and tpl["n_members"] >= 2:
            members, vigs, radius = instantiate(tpl, biome, c["placement_hint"], rng, csize)
            src = tpl["id"]
        elif tpl:  # only a solo template exists -> use it, then dress
            members, vigs, radius = instantiate(tpl, biome, c["placement_hint"], rng, csize)
            src = tpl["id"] + "(solo)"
        else:      # Stage B gap-fill (no template of this role at all)
            members, vigs, radius = stage_b_fill(c["role"], biome, rng)
            src = "stageB"
            stage_b_used += 1
        cx, cy = solver.place_center(radius, c["placement_hint"])
        solver.centers.append((cx, cy, radius, c["role"]))
        name_to_center[c["name"]] = (cx, cy, c["role"])
        for m in members:
            g = {"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]}
            if "count" in m:
                g["count"] = m["count"]
            items.append(g)
        for v in vigs:
            out_vigs.append({"kind": v["kind"], "x": cx + v["dx"], "y": cy + v["dy"]})
        cluster_records.append({"name": c["name"], "role": c["role"], "src": src,
                                "center": (cx, cy), "radius": radius})
    log["stage_b_fills"] = stage_b_used
    log["templates"] = [(r["name"], r["role"], r["src"]) for r in cluster_records]

    # -- STAGE C.3: mechanical Bible rules become code ------------------------
    # chimney_smoke snapped above every cottage/manor/tavern (+68,-285)
    if biome != "cave":
        for it in list(items):
            if it["type"] in ("cottage", "manor", "tavern"):
                items.append({"type": "chimney_smoke", "x": it["x"] + 68, "y": it["y"] - 285})
    # >=1 light emitter per inhabited cluster (Bible IV.12)
    for r in cluster_records:
        if r["role"] in ("dwelling", "market", "watch", "industry"):
            cx, cy = r["center"]
            items.append({"type": "lamp", "x": cx + 40, "y": cy - int(r["radius"] * 0.35)})
    # lamps along roads every ~700px through settled ground (Bible IV / step 3)
    settled = [(r["center"][0], r["center"][1]) for r in cluster_records
               if r["role"] in ("dwelling", "market", "watch")]
    if settled:
        for poly in roads:
            acc = 0.0
            for i in range(len(poly) - 1):
                a, b = poly[i], poly[i + 1]
                seg = math.hypot(b[0] - a[0], b[1] - a[1])
                steps = max(1, int(seg / 60))
                for s in range(steps):
                    acc += seg / steps
                    if acc < 700:
                        continue
                    acc = 0.0
                    t = (s + 1) / steps
                    px = a[0] + (b[0] - a[0]) * t
                    py = a[1] + (b[1] - a[1]) * t
                    if min((math.hypot(px - sx, py - sy) for sx, sy in settled)) > 950:
                        continue
                    nx, ny = -(b[1] - a[1]), (b[0] - a[0])
                    nl = math.hypot(nx, ny) or 1
                    side = 1 if (s % 2 == 0) else -1
                    off = ROAD_HALF + ROAD_CLEAR + 46
                    items.append({"type": "lamp",
                                  "x": px + nx / nl * off * side,
                                  "y": py + ny / nl * off * side})

    # -- STAGE C.2: relax footprints / roads / bounds -------------------------
    # (vignettes are narrative decals — boot_prints legitimately cross roads —
    #  so they are NOT footprint/road constrained)
    solver.enforce(items)

    # -- STAGE C: quadrant anchors (Bible II.7 — no dead quadrant) ------------
    _fill_dead_quadrants(items, solver, lib, biome, rng, maxr)

    # -- STAGE C.3b: scattered biome-native decals (Bible III.9 / I.1 40s rule;
    #    also satisfies Bible II.4 repetition — real places repeat props) ------
    _scatter_decals(items, solver, biome, rng)
    solver.enforce(items)

    # -- vignettes: guarantee murder + >=3 total (Bible V.15) -----------------
    _ensure_vignettes(out_vigs, concept, name_to_center, cluster_records, rng)

    # -- finalise: ints, in-bounds --------------------------------------------
    for it in items:
        it["x"] = int(round(min(max(it["x"], EDGE), W - EDGE)))
        it["y"] = int(round(min(max(it["y"], EDGE), H - EDGE)))
    for v in out_vigs:
        v["x"] = int(round(min(max(v["x"], EDGE), W - EDGE)))
        v["y"] = int(round(min(max(v["y"], EDGE), H - EDGE)))

    draft = {
        "zone_id": brief_obj.get("zone_id", "studio_canvas"),
        "roads": roads,
        "landmarks": items,
        "vignettes": out_vigs,
    }
    log["n_landmarks"] = len(items)
    log["n_vignettes"] = len(out_vigs)

    # -- STAGE: run the FULL walls (studio.py def_author validators) ----------
    os.environ["STUDIO_BIOME"] = biome
    walls = {"landmarks": [dict(it) for it in items], "vignettes": out_vigs}
    try:
        studio.validate("def_author", walls)
        log["walls"] = "PASS"
    except Exception as exc:  # noqa: BLE001
        log["walls"] = "FAIL: " + str(exc)
    return draft, log


def _fill_dead_quadrants(items, solver, lib, biome, rng, maxr=1e9):
    W, H = solver.W, solver.H
    quads = [(0, 0), (1, 0), (0, 1), (1, 1)]
    have = set()
    for it in items:
        have.add((0 if it["x"] < W / 2 else 1, 0 if it["y"] < H / 2 else 1))
    for qx, qy in quads:
        if (qx, qy) in have:
            continue
        role = rng.choice(["curiosity", "grave", "sacred", "watch"])
        tpl = select_template(role, "small", biome, lib, rng, maxr=min(maxr, 300))
        if not tpl:
            continue
        members, _v, radius = instantiate(tpl, biome, "far-from-road", rng, "small")
        # centre roughly in the quadrant
        cx = rng.uniform(radius + 220, W / 2 - 200) + (W / 2 if qx else 0)
        cy = rng.uniform(radius + 220, H / 2 - 200) + (H / 2 if qy else 0)
        cx = min(max(cx, radius + 200), W - radius - 200)
        cy = min(max(cy, radius + 200), H - radius - 200)
        rd, _ = road_near((cx, cy), solver.roads)
        if rd < radius + ROAD_HALF + ROAD_CLEAR:
            cx, cy = solver.place_center(radius, "far-from-road")
        solver.centers.append((cx, cy, radius, role))
        for m in members:
            g = {"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]}
            if "count" in m:
                g["count"] = m["count"]
            items.append(g)


def _scatter_decals(items, solver, biome, rng):
    """Scatter native ground decals through open ground: breaks up dead space
    and guarantees repeated types (Bible II.4). Two types x 3-4 each."""
    W, H = solver.W, solver.H
    decals = [d for d in BIOME_DECALS.get(biome, ["rocks", "bones"]) if d in KNOWN][:2]
    if not decals:
        return
    per = 4 if min(W, H) > 3000 else 3
    for dt in decals:
        placed = 0
        for _ in range(600):
            if placed >= per:
                break
            x = rng.uniform(EDGE + 60, W - EDGE - 60)
            y = rng.uniform(EDGE + 60, H - EDGE - 60)
            rd, _ = road_near((x, y), solver.roads)
            if rd < ROAD_HALF + 90:
                continue
            near = min((math.hypot(x - it["x"], y - it["y"]) for it in items), default=1e9)
            if near < 200:      # keep decals out of cluster footprints
                continue
            items.append({"type": dt, "x": x, "y": y})
            placed += 1


def _ensure_vignettes(out_vigs, concept, name_to_center, records, rng):
    kinds = {v["kind"] for v in out_vigs}
    # map concept vignettes to cluster centres
    for cv in concept.get("vignettes", []):
        c = name_to_center.get(cv.get("attach_to"))
        if c and cv["kind"] not in kinds:
            out_vigs.append({"kind": cv["kind"],
                             "x": c[0] + rng.randint(-90, 90),
                             "y": c[1] + rng.randint(-90, 90)})
            kinds.add(cv["kind"])
    # host: a dread/grave cluster if present, else the first
    host = next((r for r in records if r["role"] in ("dread", "grave")), records[0])
    hx, hy = host["center"]
    if "murder_scene" not in kinds:
        out_vigs.append({"kind": "murder_scene", "x": hx + rng.randint(-120, 120),
                         "y": hy + rng.randint(-120, 120)})
        kinds.add("murder_scene")
    ci = 0
    while len(out_vigs) < 4:
        k = CURIOSITY_VIGS[ci % len(CURIOSITY_VIGS)]
        ci += 1
        if k in kinds:
            continue
        r = rng.choice(records)
        out_vigs.append({"kind": k, "x": r["center"][0] + rng.randint(-140, 140),
                         "y": r["center"][1] + rng.randint(-140, 140)})
        kinds.add(k)


# ================================================================= CLI =========
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--brief", required=True, help="JSON brief file")
    ap.add_argument("-o", "--out", default="")
    ap.add_argument("--no-model", action="store_true", help="skip Ollama, deterministic")
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()
    brief_obj = json.load(io.open(args.brief, encoding="utf-8"))
    draft, log = paint(brief_obj, use_model=not args.no_model, seed=args.seed)
    if args.out:
        io.open(args.out, "w", encoding="utf-8", newline="\n").write(json.dumps(draft, indent=1))
    sys.stderr.write(json.dumps(log, indent=1) + "\n")
    print("WALLS: %s | landmarks=%d vignettes=%d | stageA=%s | -> %s"
          % (log["walls"], log["n_landmarks"], log["n_vignettes"],
             log["stage_a_source"], args.out or "(stdout)"))
    if not args.out:
        print(json.dumps(draft, indent=1))
    if not log["walls"].startswith("PASS"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
