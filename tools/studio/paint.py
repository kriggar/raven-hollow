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


# per-biome canopy density (Fable sets this per zone: iron_vein bog 1.25,
# greyhollow port 0.25) — the verticals + sway layer that fills open ground
TREE_DENSITY = {
    "farmland": 0.7, "bog": 1.0, "moor": 0.5, "deadforest": 1.1, "wilds": 1.1,
    "tundra": 0.28, "volcanic": 0.16, "port": 0.26, "steppe": 0.34, "ridge": 0.4,
    "cave": 0.0,
}


# The pond sprite is a hard-edged 128px square (owner's "no partial textures"
# law) and its razor edge shows at close-up. Water comes from river shores now;
# a curiosity "pond" becomes a soft natural feature instead.
POND_ALT = {"bog": "stump", "deadforest": "stump", "farmland": "lone_tree",
            "moor": "lone_tree", "wilds": "lone_tree"}


def legal_swap(t, biome, fallback_role="curiosity"):
    """Role-PRESERVING biome swap: a forbidden/non-canon prop is replaced only
    by a prop of the SAME role tag (a camp bedroll can never become a grave)."""
    if t == "pond":
        t = POND_ALT.get(biome, "rocks")
    if t not in KNOWN:                       # drop non-canon library types (plankv)
        role = ep._TYPE_ROLE.get(t, fallback_role)
        t = ROLE_SWAP.get(role, UNIVERSAL)
    bad = FORBID.get(biome, set())
    if t not in bad:
        return t
    role = ep._TYPE_ROLE.get(t, fallback_role)   # the PROP's own role — preserved
    for cand in (ROLE_SWAP.get(role, UNIVERSAL), UNIVERSAL, "cairn", "stone_row"):
        if cand not in bad and cand in KNOWN:
            return cand
    return UNIVERSAL


def sep_rad(t):
    """Solver-only SEPARATION radius: bigger than the validator footprint for
    buildings, because a building SPRITE (~250-300px) is wider than its 150px
    footprint — spacing them at only the wall's floor merges their roofs."""
    r = rad(t)
    return r * 1.34 if t in ep.BIG else (r * 1.08 if t in ep.MID else r)


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
        self.river = None   # water shore polyline [[x,y],...]
        self.river_width = 0.0
        self.river_color = None
        self.water_top = None

    def add_water(self, biome):
        """A river SHORE along the bottom edge (feathered banks + sheen come free
        from zone_builder._build_river). Water occupies y in [water_top, ...]."""
        W, H = self.W, self.H
        cy = H - 150
        self.water_top = cy - 100          # bank line: land above, water below
        self.river = [[0, cy - 12], [W // 2, cy], [W, cy - 8]]
        self.river_width = 200.0
        self.river_color = {"bog": [0.30, 0.25, 0.20, 0.93],
                            "port": [0.17, 0.22, 0.30, 0.92]}.get(
                                biome, [0.20, 0.28, 0.34, 0.92])

    def water_dist(self, x, y):
        if not self.river:
            return 1e18
        return road_near((x, y), [self.river])[0]

    # -- place one cluster centre honouring roads/spacing/bounds/hint/quadrant --
    def place_center(self, radius, hint, quad=None):
        W, H = self.W, self.H
        short = min(W, H)
        # margin small enough that centres can reach quadrant cores (~25%/75%);
        # members that overrun bounds are clamped later (EDGE) — corners fill.
        margin = min(radius * 0.55 + 170.0, short * 0.30)
        lo_x, hi_x = margin, max(margin + 1, W - margin)
        lo_y, hi_y = margin, max(margin + 1, H - margin)
        road_floor = radius + ROAD_HALF + ROAD_CLEAR   # every member 60px clear

        def _sample(phase):
            if quad is not None and phase < 3:
                qx, qy = quad
                x0 = lo_x if qx == 0 else (lo_x + hi_x) / 2
                x1 = (lo_x + hi_x) / 2 if qx == 0 else hi_x
                y0 = lo_y if qy == 0 else (lo_y + hi_y) / 2
                y1 = (lo_y + hi_y) / 2 if qy == 0 else hi_y
                return self.rng.uniform(x0, x1), self.rng.uniform(y0, y1)
            if hint == "corner":
                x = lo_x if self.rng.random() < 0.5 else hi_x
                y = lo_y if self.rng.random() < 0.5 else hi_y
                x += self.rng.uniform(0, (hi_x - lo_x) * 0.25) * (1 if x == lo_x else -1)
                y += self.rng.uniform(0, (hi_y - lo_y) * 0.25) * (1 if y == lo_y else -1)
                return x, y
            if hint == "center":
                return ((lo_x + hi_x) / 2 + self.rng.uniform(-1, 1) * (hi_x - lo_x) * 0.18,
                        (lo_y + hi_y) / 2 + self.rng.uniform(-1, 1) * (hi_y - lo_y) * 0.18)
            return self.rng.uniform(lo_x, hi_x), self.rng.uniform(lo_y, hi_y)

        for phase in range(6):
            for _ in range(2500):
                x, y = _sample(phase)
                rd, _ = road_near((x, y), self.roads)
                if rd < road_floor:
                    continue
                if phase < 3 and hint == "far-from-road" and rd < 620:
                    continue
                ok = True
                for (cx, cy, cr, _r) in self.centers:
                    need = radius + cr + 120.0 - phase * 40.0
                    if math.hypot(x - cx, y - cy) < need:
                        ok = False
                        break
                if ok:
                    return x, y
        return (lo_x + hi_x) / 2, (lo_y + hi_y) / 2

    # -- the enforce loop: zero footprint clips, zero road overlap, in bounds --
    def enforce(self, items, iters=240):
        W, H = self.W, self.H
        for _ in range(iters):
            moved = False
            n = len(items)
            for i in range(n):
                ti = items[i]["type"]
                ri = sep_rad(ti)
                for j in range(i + 1, n):
                    tj = items[j]["type"]
                    # sep_rad > wall footprint for buildings (sprites are wider);
                    # PAD keeps pairs a hair beyond so int-rounding never drops a
                    # pair below studio.validate's strict `d < need` clip test.
                    need = ri + sep_rad(tj) + 2.5
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

    def enforce_footprint_only(self, items, iters=160):
        """Final guarantee: pairwise separation on the EXACT validator radii
        (rad, +margin), no road/bounds tug-of-war — so the walls always pass."""
        for _ in range(iters):
            moved = False
            n = len(items)
            for i in range(n):
                ti = items[i]["type"]
                ri = rad(ti)
                for j in range(i + 1, n):
                    need = ri + rad(items[j]["type"]) + 2.0
                    dx = items[i]["x"] - items[j]["x"]
                    dy = items[i]["y"] - items[j]["y"]
                    d = math.hypot(dx, dy)
                    if d < need:
                        if d < 1e-6:
                            ang = self.rng.uniform(0, 2 * math.pi)
                            ux, uy, d = math.cos(ang), math.sin(ang), 1e-6
                        else:
                            ux, uy = dx / d, dy / d
                        push = (need - d) / 2.0 + 0.3
                        mi, mj = mass(ti), mass(items[j]["type"])
                        tot = mi + mj
                        items[i]["x"] += ux * push * 2 * mj / tot
                        items[i]["y"] += uy * push * 2 * mj / tot
                        items[j]["x"] -= ux * push * 2 * mi / tot
                        items[j]["y"] -= uy * push * 2 * mi / tot
                        moved = True
            if not moved:
                return True
        return False


# ============================================= Stage C helpers: instances =====
def instantiate(template, biome, hint, rng, size_hint=None):
    """Turn a library template into a concrete cluster: biome dressing swaps,
    count-scaling, +-jitter, optional mirror. Returns local members + vignettes
    (offsets from cluster centre) and the footprint radius."""
    scale = {"small": 0.9, "medium": 1.0, "large": 1.35}.get(size_hint or template["size"], 1.0)
    mirror = template.get("mirror_x_ok") and rng.random() < 0.4
    members = []
    for m in template["members"]:
        t = legal_swap(m["type"], biome)
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


# ============================================ MOOD + ROLE-QUOTAS (owner law) ===
# The geometry solver is sound; SEMANTICS are gated here. A fishing hamlet must
# read as a place fishermen LIVE — not a funeral. Every brief carries a mood;
# mood drives validator-enforced role quotas and forbids off-tone templates.
MOOD_COZY, MOOD_WILD, MOOD_DREAD = "inhabited-cozy", "wild", "dread"
# dread-only props/vignettes forbidden in inhabited-cozy briefs
DREAD_PROPS = {"thread_lines", "spire", "pit", "wreck", "lichen_glow", "dark_keep"}
DREAD_VIGS = {"rows_of_twelve", "chalk_handprints", "burned_farmstead"}
COZY_VIGS = ["standing_farmer", "empty_stall", "childs_shoe", "full_granary", "boot_prints"]


def infer_mood(brief):
    low = brief.lower()
    if re.search(r"hamlet|village|town|cottage|fishing|forge camp|warehouse|"
                 r"dockwork|smiths?\b|market town|farmstead|inn\b", low):
        return MOOD_COZY
    if re.search(r"graveyard|grave field|barrow|tomb field|entranced|the drowned|"
                 r"massacre|ossuar|field of graves|charnel", low):
        return MOOD_DREAD
    if re.search(r"outpost|watch|patrol|beacon|listener|frontier|scout", low):
        return MOOD_WILD
    return MOOD_WILD


def infer_livelihood(brief):
    low = brief.lower()
    if re.search(r"fish|net\b|weir|trawl|\bboat|pier|angler", low):
        return "fishing"
    if re.search(r"forge|smith|smelt|foundry|\bore\b|anvil", low):
        return "forge"
    if re.search(r"warehouse|dock|cargo|crane|wharf|freight", low):
        return "port"
    if re.search(r"farm|barn|granary|harvest|field", low):
        return "farm"
    return "none"


def _pack(layout, biome, rng, jitter=16):
    members = []
    for spec in layout:
        t, dx, dy = spec[0], spec[1], spec[2]
        d = {"type": legal_swap(t, biome), "dx": dx + rng.randint(-jitter, jitter),
             "dy": dy + rng.randint(-jitter, jitter)}
        if len(spec) > 3:
            d["count"] = spec[3]
        members.append(d)
    radius = 40.0
    for m in members:
        radius = max(radius, math.hypot(m["dx"], m["dy"]) + rad(m["type"]))
    return members, [], radius


def synth_dwelling(biome, rng):
    """A lived-in homestead: 2-3 cottages + an outbuilding, chimneys added later."""
    layout = [("cottage", -150, -70), ("cottage", 170, -30), ("cottage", 20, 190)]
    if rng.random() < 0.7:
        layout.append(("shed", -210, 170))
    if rng.random() < 0.5:
        layout.append(("well", 150, 200))
    rng.shuffle(layout)
    return _pack(layout, biome, rng)


# props that REQUIRE a water context (owner's water-adjacency law); if one lands
# far from water it is swapped to a land equivalent (never a beached boat)
WATER_PROPS = {"boat", "pier", "wreck", "drowned_fence", "salt_pan"}
LAND_SWAP = {"boat": "cargo", "pier": "signboard", "wreck": "bones",
             "drowned_fence": "stone_row", "salt_pan": "rocks"}


def place_dock(solver, kind, biome, rng, items):
    """Place the livelihood ON THE SHORE: land props (sheds/warehouses/barrels)
    above the bank, pier reaching DOWN into the water, boats ON the water, nets
    along the bank. Guarantees water-adjacency by construction. Returns
    (water_prop_refs, center, radius)."""
    W, H = solver.W, solver.H
    bank = solver.water_top
    cx = rng.uniform(W * 0.32, W * 0.68)
    cy = bank - 40                          # cluster centre just above the bank
    if kind == "port":
        land = [("warehouse", -250, -180), ("workshop", 260, -200),
                ("cargo", -60, -110, 4), ("crane", 80, -30)]
        water = [("pier", -70, 70, "s"), ("boat", 240, 150), ("boat", -240, 140),
                 ("drowned_fence", 70, 210)]
    else:  # fishing
        land = [("shed", -250, -180), ("cottage", 230, -200), ("cargo", -60, -100, 3)]
        water = [("pier", 0, 70, "s"), ("boat", 250, 140), ("boat", -250, 130),
                 ("drowned_fence", -100, 200), ("drowned_fence", 100, 200),
                 ("drowned_fence", 0, 270)]
    refs = []
    radius = 40.0
    for spec in land + water:
        t = legal_swap(spec[0], biome)
        x = cx + spec[1] + rng.randint(-12, 12)
        y = cy + spec[2] + rng.randint(-8, 8)
        it = {"type": t, "x": x, "y": y}
        if len(spec) > 3 and isinstance(spec[3], int):
            it["count"] = spec[3]
        if len(spec) > 3 and isinstance(spec[3], str):
            it["dir"] = spec[3]
        if spec[0] in WATER_PROPS:
            refs.append(it)
        items.append(it)
        radius = max(radius, math.hypot(spec[1], spec[2]) + rad(t))
    return refs, (cx, cy), radius


def synth_livelihood(kind, biome, rng):
    """Land livelihood (forge/farm). Water livelihoods use place_dock instead."""
    if kind == "forge":
        layout = [("forge", 0, 0), ("workshop", -220, 40), ("ore_rocks", 200, 90, 5),
                  ("brazier", -60, 150), ("cottage", 200, -150)]
    elif kind == "port":
        layout = [("warehouse", 0, 0), ("crane", 210, -40), ("cargo", -180, 120, 4),
                  ("cargo", 120, 160, 3), ("workshop", -230, -110)]
    elif kind == "farm":
        layout = [("barn", 0, 0), ("shed", 210, 60), ("cottage", -200, -30),
                  ("well", 60, 190), ("stall", -120, 200)]
    else:
        return synth_social(biome, rng)
    return _pack(layout, biome, rng)


def synth_social(biome, rng):
    """A place people gather: a small market or a tavern-and-well."""
    if rng.random() < 0.5:
        layout = [("tavern", 0, 0), ("stall", -180, 140), ("stall", 180, 140),
                  ("well", 0, 210), ("signboard", 150, -110)]
    else:
        layout = [("well", 0, 0), ("stall", -160, 60), ("stall", 160, 60),
                  ("stall", 0, 200), ("signboard", -140, -120)]
    return _pack(layout, biome, rng)


def synth_grave_small(biome, rng):
    """ONE tiny churchyard plot — the cozy limit (a family plot, not a field)."""
    layout = [("graves", 0, 0, 3), ("inscription_stone", -120, -40),
              ("statue", 40, -160)]
    return _pack(layout, biome, rng)


SYNTH = {"dwelling": synth_dwelling, "social": synth_social,
         "grave_small": synth_grave_small}


def enforce_quotas(concept, mood, livelihood, biome, log):
    """VALIDATOR (not a hint): repair the Stage-A concept to satisfy this mood's
    role quotas and strip off-tone clusters/vignettes. Records the gaps it fixed."""
    cl = concept["clusters"]
    gaps = []
    if mood == MOOD_COZY:
        before = len(cl)
        # cozy allows only lived-in roles; drop dread/watch/sacred sprawl
        keep = []
        graves_kept = 0
        for c in cl:
            r = c["role"]
            if r in ("dread", "watch"):
                continue
            if r == "sacred":            # a cozy "church" is the small grave plot
                continue
            if r == "grave":
                if graves_kept >= 1:
                    continue
                graves_kept += 1
                c["synth"] = "grave_small"
                c["size"] = "small"
            if r == "livelihood":
                c["synth"] = "livelihood"
                c.setdefault("kind", livelihood)
            if r in ("industry", "market"):
                # fold model's industry/market into the social anchor
                c["role"] = "social"
                c["synth"] = "social"
            if r == "social":
                c["synth"] = "social"
            if r == "dwelling":
                c["synth"] = "dwelling"
            if r == "curiosity":
                c.pop("synth", None)          # library/ curiosity, not synthesised
            keep.append(c)
        cl = keep
        if before != len(cl):
            gaps.append("cozy: dropped %d off-tone clusters" % (before - len(cl)))
        # QUOTA: >=1 livelihood matching the brief
        if livelihood != "none" and not any(c.get("kind") == livelihood for c in cl):
            cl.insert(0, {"name": "the %s" % livelihood, "role": "livelihood",
                          "kind": livelihood, "synth": "livelihood", "size": "medium",
                          "placement_hint": "roadside", "mood": mood})
            gaps.append("added livelihood:%s" % livelihood)
        # QUOTA: >=3 dwelling clusters
        while sum(1 for c in cl if c["role"] == "dwelling") < 3:
            cl.append({"name": "cottage row", "role": "dwelling", "synth": "dwelling",
                       "size": "medium", "placement_hint": "roadside", "mood": mood})
            gaps.append("added dwelling")
        # QUOTA: >=1 social anchor
        if not any(c["role"] == "social" for c in cl):
            cl.append({"name": "the commons", "role": "social", "synth": "social",
                       "size": "small", "placement_hint": "center", "mood": mood})
            gaps.append("added social")
        # QUOTA: one small churchyard (identity)
        if not any(c["role"] == "grave" for c in cl):
            cl.append({"name": "the churchyard", "role": "grave", "synth": "grave_small",
                       "size": "small", "placement_hint": "corner", "mood": mood})
            gaps.append("added grave_small")
        if not any(c["role"] == "curiosity" for c in cl):
            cl.append({"name": "the old stones", "role": "curiosity", "size": "small",
                       "placement_hint": "far-from-road", "mood": mood})
        # strip dread vignettes
        concept["vignettes"] = [v for v in concept["vignettes"]
                                if v["kind"] not in DREAD_VIGS]
    elif mood == MOOD_WILD:
        # cap grave clusters to 2, rows_of_twelve to 1; ensure a watch anchor
        graves = [c for c in cl if c["role"] == "grave"]
        if len(graves) > 2:
            cl = [c for c in cl if c["role"] != "grave"] + graves[:2]
            gaps.append("wild: capped graves to 2")
        if not any(c["role"] in ("watch", "dread") for c in cl):
            cl.append({"name": "the watch", "role": "watch", "size": "medium",
                       "placement_hint": "roadside", "mood": mood})
            gaps.append("added watch")
        seen_r12 = 0
        vv = []
        for v in concept["vignettes"]:
            if v["kind"] == "rows_of_twelve":
                seen_r12 += 1
                if seen_r12 > 1:
                    continue
            vv.append(v)
        concept["vignettes"] = vv
    # dread: no cozy quotas — grave fields / thread networks are the point
    concept["clusters"] = cl
    log["quota_gaps"] = gaps
    return concept


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
    "Rules: 5-7 clusters; spread the placement_hints across quadrants.\n"
    "MOOD LAW (obey exactly):\n"
    " * inhabited-cozy (a hamlet/town/camp where people LIVE): MOST clusters are "
    "dwelling; include the brief's livelihood (industry) and a market; AT MOST "
    "one grave; NO dread clusters; NO rows_of_twelve/thread horror. Vignettes are "
    "everyday life (standing_farmer, empty_stall, childs_shoe, full_granary) plus "
    "ONE murder_scene.\n"
    " * wild (an outpost/frontier): a watch anchor, some dwelling, curiosity, up "
    "to two grave and one dread.\n"
    " * dread (a graveyard field/haunt): grave & sacred lead; dread welcome.\n"
    "One murder_scene always. Ground it in the biome and brief. No coordinates.")

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


def stage_a_model(brief, biome, mood, livelihood, temperature=0.5):
    user = ("BRIEF: %s\nBIOME: %s\nMOOD: %s\nLIVELIHOOD: %s\n\n"
            "Pick the story-clusters obeying the MOOD LAW. Pure JSON only."
            % (brief, biome, mood, livelihood))
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


def stage_a_fallback(brief, biome, mood, livelihood):
    """Deterministic mood-correct skeleton (quotas satisfied by construction)."""
    hints = ["center", "roadside", "corner", "far-from-road", "roadside",
             "corner", "far-from-road", "roadside"]
    if mood == MOOD_COZY:
        roles = [("livelihood", livelihood), ("dwelling", None), ("dwelling", None),
                 ("dwelling", None), ("social", None), ("curiosity", None),
                 ("grave", None)]
    elif mood == MOOD_DREAD:
        roles = [("grave", None), ("sacred", None), ("grave", None), ("dread", None),
                 ("curiosity", None), ("watch", None), ("sacred", None)]
    else:  # wild
        roles = [("watch", None), ("dwelling", None), ("sacred", None),
                 ("grave", None), ("curiosity", None), ("dread", None)]
    SYNTH_ROLE = {"livelihood": "livelihood", "dwelling": "dwelling",
                  "social": "social", "grave": "grave_small"}
    clusters = []
    for i, (r, kind) in enumerate(roles):
        c = {"name": "%s %d" % (r, i), "role": r, "mood": mood,
             "size": "medium", "placement_hint": hints[i % len(hints)],
             "story": "%s in the %s" % (r, biome)}
        if kind:
            c["kind"] = kind
        if mood == MOOD_COZY and r in SYNTH_ROLE:
            c["synth"] = SYNTH_ROLE[r]
        clusters.append(c)
    host = next((c["name"] for c in clusters if c["role"] in ("grave", "dread", "curiosity")),
                clusters[0]["name"])
    if mood == MOOD_COZY:
        vigs = [{"kind": "murder_scene", "attach_to": host},
                {"kind": "standing_farmer", "attach_to": clusters[1]["name"]},
                {"kind": "childs_shoe", "attach_to": clusters[2]["name"]},
                {"kind": "full_granary", "attach_to": clusters[0]["name"]}]
    else:
        vigs = [{"kind": "murder_scene", "attach_to": host},
                {"kind": "boot_prints", "attach_to": host},
                {"kind": "cold_camp", "attach_to": clusters[-1]["name"]},
                {"kind": "standing_farmer", "attach_to": clusters[1]["name"]}]
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
        members.append({"type": legal_swap(base, biome),
                        "dx": int(r * math.cos(ang)), "dy": int(r * math.sin(ang))})
    radius = 240 + rad(base)
    return members, [], radius


# ============================================ template selection (Stage C) =====
def _cozy_safe(c):
    """Cozy briefs never pull a template carrying dread props or dread vignettes."""
    if any(m["type"] in DREAD_PROPS for m in c["members"]):
        return False
    if any(v["kind"] in DREAD_VIGS for v in c.get("vignettes", [])):
        return False
    return True


def select_template(role, size, biome, lib, rng, maxr=1e9, mood=None):
    clusters = lib["clusters"]
    if mood == MOOD_COZY:
        clusters = [c for c in clusters if _cozy_safe(c)]
    cores = [c for c in clusters if c["role"] == role and c["n_members"] >= 2]
    exact = [c for c in cores if c["biome"] == biome]
    pool = exact or cores
    if not pool:
        pool = [c for c in clusters if c["role"] == role]  # solos of the role
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

    # -- STAGE A: concept (mood-conditioned) ----------------------------------
    mood = brief_obj.get("mood") or infer_mood(brief_obj["brief"])
    livelihood = brief_obj.get("livelihood") or infer_livelihood(brief_obj["brief"])
    log["mood"] = mood
    log["livelihood"] = livelihood
    concept = None
    if use_model:
        try:
            concept = stage_a_model(brief_obj["brief"], biome, mood, livelihood)
        except Exception as exc:  # noqa: BLE001
            log["stage_a_model_error"] = str(exc)[:160]
    if concept is None:
        concept = stage_a_fallback(brief_obj["brief"], biome, mood, livelihood)
    log["stage_a_source"] = concept["_source"]
    log["n_concept_raw"] = len(concept["clusters"])
    # VALIDATOR: enforce mood role-quotas + strip off-tone clusters/vignettes
    concept = enforce_quotas(concept, mood, livelihood, biome, log)
    log["n_concept_clusters"] = len(concept["clusters"])

    # zone-size adaptivity: budget the per-cluster radius (so a big Fable core
    # never overruns a small zone) and the cluster count to the zone AREA (so a
    # zone stays densely filled — Bible I.1 40-second rule — not sparse).
    short = min(W, H)
    maxr = max(200.0, min(360.0, short / 4.0))
    n_cap = int(max(5, min(9, (W * H) / 620000.0)))
    if mood == MOOD_COZY:
        n_cap = max(n_cap, 7)                # never trim below the cozy quota set
    # trim extras (never a required quota role) if over cap — drop surplus
    # curiosity first, then surplus dwellings beyond 3
    cl = concept["clusters"]
    if len(cl) > n_cap:
        def _drop_pri(c):
            if c["role"] == "curiosity":
                return 0
            if c["role"] == "dwelling":
                return 1
            return 2
        keep = sorted(range(len(cl)), key=lambda i: (_drop_pri(cl[i]), -i))
        dwell = sum(1 for c in cl if c["role"] == "dwelling")
        drop = set()
        for i in keep:
            if len(cl) - len(drop) <= n_cap:
                break
            if cl[i]["role"] == "dwelling" and dwell - sum(
                    1 for j in drop if cl[j]["role"] == "dwelling") <= 3:
                continue
            if cl[i]["role"] in ("livelihood", "social", "grave"):
                continue
            drop.add(i)
        cl = [c for i, c in enumerate(cl) if i not in drop]
    concept["clusters"] = cl
    log["maxr"] = round(maxr, 1)
    log["n_clusters_capped"] = len(concept["clusters"])

    # -- STAGE B+C: bind templates, place centres, map to global --------------
    solver = Solver(W, H, roads, biome, seed=seed)
    # WATER-ADJACENCY LAW: a fishing/harbour brief gets a real river shore, and
    # its dock is built ON the water (owner directive). No water = no boats.
    water_needed = livelihood in ("fishing", "port") or biome == "port"
    if water_needed:
        solver.add_water(biome)
    dock_water_refs = []
    items = []           # global landmark dicts {type,x,y,count?}
    out_vigs = []        # {kind,x,y}
    stage_b_used = 0
    cluster_records = []
    # place identity/large clusters first for good packing; assign quadrants
    # round-robin so anchors spread across the zone (Bible II.7, not a centre band)
    order = sorted(concept["clusters"],
                   key=lambda c: {"large": 0, "medium": 1, "small": 2}.get(c["size"], 1))
    quad_seq = [(0, 0), (1, 1), (1, 0), (0, 1)]
    name_to_center = {}
    for idx, c in enumerate(order):
        csize = "medium" if (short < 2400 and c["size"] == "large") else c["size"]
        synth = c.get("synth")
        # water livelihood -> built directly on the shore (dock), not via place_center
        if synth == "livelihood" and water_needed and c.get("kind") in ("fishing", "port"):
            refs, (cx, cy), radius = place_dock(solver, c["kind"], biome, rng, items)
            dock_water_refs.extend(refs)
            solver.centers.append((cx, cy, radius, "livelihood"))
            name_to_center[c["name"]] = (cx, cy, "livelihood")
            cluster_records.append({"name": c["name"], "role": "livelihood",
                                    "src": "dock:%s" % c["kind"], "center": (cx, cy),
                                    "radius": radius})
            continue
        if synth == "livelihood":
            members, vigs, radius = synth_livelihood(c.get("kind", "none"), biome, rng)
            src = "synth:livelihood:%s" % c.get("kind")
        elif synth in SYNTH:
            members, vigs, radius = SYNTH[synth](biome, rng)
            src = "synth:%s" % synth
        else:
            tpl = select_template(c["role"], csize, biome, lib, rng, maxr=maxr, mood=mood)
            if tpl and tpl["n_members"] >= 2:
                members, vigs, radius = instantiate(tpl, biome, c["placement_hint"], rng, csize)
                src = tpl["id"]
            elif tpl:
                members, vigs, radius = instantiate(tpl, biome, c["placement_hint"], rng, csize)
                src = tpl["id"] + "(solo)"
            else:
                members, vigs, radius = stage_b_fill(c["role"], biome, rng)
                src = "stageB"
                stage_b_used += 1
        quad = quad_seq[idx % len(quad_seq)]
        cx, cy = solver.place_center(radius, c["placement_hint"], quad=quad)
        solver.centers.append((cx, cy, radius, c["role"]))
        name_to_center[c["name"]] = (cx, cy, c["role"])
        for m in members:
            g = {"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]}
            if "count" in m:
                g["count"] = m["count"]
            items.append(g)
        for v in vigs:
            out_vigs.append({"kind": v["kind"], "x": cx + v["dx"], "y": cy + v["dy"]})
        # satellites (Bible II.7 — every anchor gets 2-5 small props): native
        # decals ringing the cluster, so anchors read as inhabited, not lonely.
        sat_types = [d for d in BIOME_DECALS.get(biome, ["rocks"]) if d in KNOWN]
        for _ in range(rng.randint(2, 4)):
            ang = rng.uniform(0, 2 * math.pi)
            rr = radius + rng.uniform(30, 150)   # OUTSIDE the footprint (less crowding)
            items.append({"type": rng.choice(sat_types),
                          "x": cx + rr * math.cos(ang), "y": cy + rr * math.sin(ang)})
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
    INHABITED = ("dwelling", "market", "watch", "industry", "social", "livelihood")
    for r in cluster_records:
        if r["role"] in INHABITED:
            cx, cy = r["center"]
            items.append({"type": "lamp", "x": cx + 40, "y": cy - int(r["radius"] * 0.35)})
    # lamps along roads every ~700px through settled ground (Bible IV / step 3)
    settled = [(r["center"][0], r["center"][1]) for r in cluster_records
               if r["role"] in INHABITED]
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

    # -- WATER-ADJACENCY LAW: any water-prop NOT the dock's and far from water
    #    becomes a land prop (no beached boats / dry piers) --------------------
    orphans = _swap_orphan_water(items, solver, biome, dock_water_refs)
    log["water_orphans_swapped"] = orphans

    # -- STAGE C.2: relax footprints / roads / bounds -------------------------
    # (vignettes are narrative decals — boot_prints legitimately cross roads —
    #  so they are NOT footprint/road constrained)
    solver.enforce(items)

    # -- STAGE C: quadrant anchors (Bible II.7 — no dead quadrant) ------------
    _fill_dead_quadrants(items, solver, lib, biome, rng, maxr, mood)

    # -- STAGE C.3b: scattered biome-native decals (Bible III.9 / I.1 40s rule;
    #    also satisfies Bible II.4 repetition — real places repeat props) ------
    _scatter_decals(items, solver, biome, rng)
    solver.enforce(items)

    # -- vignettes: guarantee murder + >=3 total (Bible V.15) -----------------
    _ensure_vignettes(out_vigs, concept, name_to_center, cluster_records, rng, mood)

    # -- final strict footprint guarantee (exact validator metric) ------------
    solver.enforce_footprint_only(items)

    # -- finalise: ints, in-bounds --------------------------------------------
    for it in items:
        it["x"] = int(round(min(max(it["x"], EDGE), W - EDGE)))
        it["y"] = int(round(min(max(it["y"], EDGE), H - EDGE)))
    for v in out_vigs:
        v["x"] = int(round(min(max(v["x"], EDGE), W - EDGE)))
        v["y"] = int(round(min(max(v["y"], EDGE), H - EDGE)))
    # ULTIMATE guarantee on the exact integer grid the validator inspects.
    # Dock props start deep in the water band, so int_repair's small nudges keep
    # them within the water-adjacency threshold (no beaching).
    items, dropped = _int_repair(items, W, H)
    log["footprint_dropped"] = dropped

    # focus hint = the identity cluster (livelihood > grave/dread > largest) so
    # the exam close-up frames the town's signature, not a random dense pocket
    focus_rec = next((r for r in cluster_records if r["role"] == "livelihood"), None)
    if focus_rec is None:
        focus_rec = next((r for r in cluster_records if r["role"] in ("grave", "dread")),
                         max(cluster_records, key=lambda r: r["radius"]) if cluster_records else None)
    draft = {
        "zone_id": brief_obj.get("zone_id", "studio_canvas"),
        "tree_density": brief_obj.get("tree_density", TREE_DENSITY.get(biome, 0.4)),
        "focus": [int(focus_rec["center"][0]), int(focus_rec["center"][1])] if focus_rec else None,
        "roads": roads,
        "landmarks": items,
        "vignettes": out_vigs,
    }
    if solver.river:
        draft["river"] = [[int(p[0]), int(p[1])] for p in solver.river]
        draft["river_width"] = solver.river_width
        draft["river_color"] = solver.river_color
        # frame the dock (identity of a water town) in the exam close-up
        if dock_water_refs:
            draft["focus"] = [int(sum(r["x"] for r in dock_water_refs) / len(dock_water_refs)),
                              int(sum(r["y"] for r in dock_water_refs) / len(dock_water_refs)) - 120]
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


def _fill_dead_quadrants(items, solver, lib, biome, rng, maxr=1e9, mood=None):
    W, H = solver.W, solver.H
    quads = [(0, 0), (1, 0), (0, 1), (1, 1)]
    have = set()
    for it in items:
        have.add((0 if it["x"] < W / 2 else 1, 0 if it["y"] < H / 2 else 1))
    ylimit = (solver.water_top - 220) if solver.water_top else (H - 200)
    # cozy dead-quadrant fill stays lived-in (no dread/grave sprawl)
    roles = ["curiosity", "dwelling"] if mood == MOOD_COZY else \
        ["curiosity", "grave", "sacred", "watch"]
    for qx, qy in quads:
        if (qx, qy) in have:
            continue
        role = rng.choice(roles)
        if role == "dwelling":
            members, _v, radius = synth_dwelling(biome, rng)
            cx = rng.uniform(radius + 220, W / 2 - 160) + (W / 2 if qx else 0)
            cy = rng.uniform(radius + 220, H / 2 - 160) + (H / 2 if qy else 0)
            cx = min(max(cx, radius + 180), W - radius - 180)
            cy = min(max(cy, radius + 180), min(H - radius - 180, ylimit))
            for m in members:
                items.append({"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]})
            solver.centers.append((cx, cy, radius, role))
            continue
        tpl = select_template(role, "small", biome, lib, rng, maxr=min(maxr, 300), mood=mood)
        if not tpl:
            continue
        members, _v, radius = instantiate(tpl, biome, "far-from-road", rng, "small")
        # centre roughly in the quadrant
        cx = rng.uniform(radius + 220, W / 2 - 200) + (W / 2 if qx else 0)
        cy = rng.uniform(radius + 220, H / 2 - 200) + (H / 2 if qy else 0)
        cx = min(max(cx, radius + 200), W - radius - 200)
        cy = min(max(cy, radius + 200), min(H - radius - 200, ylimit))
        rd, _ = road_near((cx, cy), solver.roads)
        if rd < radius + ROAD_HALF + ROAD_CLEAR:
            cx, cy = solver.place_center(radius, "far-from-road")
        solver.centers.append((cx, cy, radius, role))
        for m in members:
            g = {"type": m["type"], "x": cx + m["dx"], "y": cy + m["dy"]}
            if "count" in m:
                g["count"] = m["count"]
            items.append(g)


def _swap_orphan_water(items, solver, biome, keep):
    """A water-prop that is not part of the dock and sits far from water is a
    beached boat / dry pier — swap it to a land equivalent (owner's law)."""
    keep_ids = {id(r) for r in keep}
    thresh = (solver.river_width / 2 + 150) if solver.river else -1
    n = 0
    for it in items:
        if it["type"] in WATER_PROPS and id(it) not in keep_ids:
            if not solver.river or solver.water_dist(it["x"], it["y"]) > thresh:
                it["type"] = legal_swap(LAND_SWAP.get(it["type"], "rocks"), biome)
                it.pop("dir", None)
                n += 1
    return n


def _int_repair(items, W, H, max_iters=1200):
    """The ultimate footprint guarantee: on the exact INTEGER grid the walls
    inspect, resolve every pair d < rad(a)+rad(b). Moves the lighter prop; if a
    pair proves unresolvable (both pinned at a bound) after repeated attempts,
    drops the lighter prop (a decal). Guarantees studio.validate passes."""
    stuck = {}
    dropped = 0
    for _ in range(max_iters):
        bad = None
        for i in range(len(items)):
            ri = rad(items[i]["type"])
            for j in range(i + 1, len(items)):
                need = ri + rad(items[j]["type"])
                dx = items[i]["x"] - items[j]["x"]
                dy = items[i]["y"] - items[j]["y"]
                d = math.hypot(dx, dy)
                if d < need:
                    bad = (i, j, need, d, dx, dy)
                    break
            if bad:
                break
        if not bad:
            break
        i, j, need, d, dx, dy = bad
        # move the lighter prop away
        k, o = (i, j) if mass(items[i]["type"]) <= mass(items[j]["type"]) else (j, i)
        sgn = 1 if k == i else -1
        if d < 1e-6:
            ux, uy = 1.0, 0.0
        else:
            ux, uy = sgn * dx / d, sgn * dy / d
        shift = need - d + 2.0
        nx = int(round(min(max(items[k]["x"] + ux * shift, EDGE), W - EDGE)))
        ny = int(round(min(max(items[k]["y"] + uy * shift, EDGE), H - EDGE)))
        key = tuple(sorted((i, j)))
        stuck[key] = stuck.get(key, 0) + 1
        moved = (nx != items[k]["x"] or ny != items[k]["y"])
        items[k]["x"], items[k]["y"] = nx, ny
        if stuck[key] > 6 or not moved:
            # unresolvable — drop the lighter, less important prop
            drop_idx = k if rad(items[k]["type"]) <= rad(items[o]["type"]) else o
            items.pop(drop_idx)
            dropped += 1
            stuck = {}
    return items, dropped


def _scatter_decals(items, solver, biome, rng):
    """Scatter native ground decals through open ground: breaks up dead space
    and guarantees repeated types (Bible II.4). Two types x 3-4 each."""
    W, H = solver.W, solver.H
    decals = [d for d in BIOME_DECALS.get(biome, ["rocks", "bones"]) if d in KNOWN][:2]
    if not decals:
        return
    per = 4 if min(W, H) > 3000 else 3
    ymax = (solver.water_top - 70) if solver.water_top else (H - EDGE - 60)
    for dt in decals:
        placed = 0
        for _ in range(600):
            if placed >= per:
                break
            x = rng.uniform(EDGE + 60, W - EDGE - 60)
            y = rng.uniform(EDGE + 60, ymax)   # never scatter on the water
            rd, _ = road_near((x, y), solver.roads)
            if rd < ROAD_HALF + 90:
                continue
            near = min((math.hypot(x - it["x"], y - it["y"]) for it in items), default=1e9)
            if near < 200:      # keep decals out of cluster footprints
                continue
            items.append({"type": dt, "x": x, "y": y})
            placed += 1


def _ensure_vignettes(out_vigs, concept, name_to_center, records, rng, mood=None):
    kinds = {v["kind"] for v in out_vigs}
    # map concept vignettes to cluster centres
    for cv in concept.get("vignettes", []):
        c = name_to_center.get(cv.get("attach_to"))
        if c and cv["kind"] not in kinds:
            out_vigs.append({"kind": cv["kind"],
                             "x": c[0] + rng.randint(-90, 90),
                             "y": c[1] + rng.randint(-90, 90)})
            kinds.add(cv["kind"])
    # host the ONE crime at a grave/dread cluster if present, else the first
    host = next((r for r in records if r["role"] in ("dread", "grave")), records[0])
    hx, hy = host["center"]
    if "murder_scene" not in kinds:
        out_vigs.append({"kind": "murder_scene", "x": hx + rng.randint(-120, 120),
                         "y": hy + rng.randint(-120, 120)})
        kinds.add("murder_scene")
    # fill with mood-appropriate curiosity vignettes (cozy = everyday life)
    pool = COZY_VIGS if mood == MOOD_COZY else CURIOSITY_VIGS
    ci = 0
    while len(out_vigs) < 4 and ci < 40:
        k = pool[ci % len(pool)]
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
