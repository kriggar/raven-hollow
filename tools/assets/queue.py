#!/usr/bin/env python3
"""
THE PERSISTENT ASSET QUEUE  (#114 — owner: build toward a 150,000-asset gothic library).

Runs continuously (detached .bat supervisor) on the RTX 5070 Ti, $0. Each cycle:
  pick a category under quota -> compose a randomized gothic-medieval prompt ->
  BATCH-generate (batch_size images/job to fill VRAM, model stays resident) ->
  process_render() SPLIT into one-sprite-per-cell -> SPOTLESS gate -> perceptual-hash DEDUP ->
  save final PNG to D:/raven_assets/<category>/ + append library -> **DELETE THE RAW IMMEDIATELY**
  (ComfyUI output file pruned) -> log assets/hr + count-toward-150k.

DISK LAW (owner): keep ONLY final spotless PNGs + JSON. Raws are ~1-2MB x 150k = ~225GB = would
blow the disk, so every raw is deleted the instant its sprite is cut & verified. A disk guard stops
the run if free space on the library drive drops below DISK_MIN_GB.

  # one burst of N accepted assets (stress test), synchronous:
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/queue.py --burst 200
  # run forever toward the target:
  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/queue.py --target 150000
"""
from __future__ import annotations
import os, sys, io, json, time, random, shutil, argparse, urllib.request, urllib.parse
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import interpret as I
import generate as G   # reuse comfy client + sdxl workflow + STYLE/NEG/BGWORDS
import gauntlet as GAUNTLET   # the vision gauntlet (#115) — final unanimous gate
import council as COUNCIL     # generation-council routing (#115)

# ---------------------------------------------------------------------------- storage (D:)
LIB_ROOT = os.environ.get("RH_ASSETLIB_ROOT", r"D:\raven hollow\assetlib")
LIB_JSON = os.path.join(LIB_ROOT, "library.json")
PHASH_JSON = os.path.join(LIB_ROOT, "phash_index.json")
MANIFEST = os.path.join(LIB_ROOT, "queue_manifest.json")
LOG = os.path.join(LIB_ROOT, "queue.log")
COMFY_OUT = r"C:\Users\vstef\ComfyUI\output"
DISK_MIN_GB = 20
TARGET_DEFAULT = 150_000
BATCH = int(os.environ.get("RH_BATCH", "4"))          # images per ComfyUI job (VRAM fill)
DHASH_MIN_DISTANCE = 6                                  # nearer than this (same cat) = duplicate

# ---------------------------------------------------------------------------- category quotas -> 150k
# gothic / dark-medieval-eastern-european ONLY (owner: NOT school/beach). Quotas sum to 150,000.
QUOTAS = {
    "containers":   13000, "furniture":   12000, "lighting":     7000, "market_food": 10000,
    "tools":         9000, "graveyard":    9000, "monuments":    9000, "ruins":        9000,
    "buildings":    12000, "harbor":       9000, "nature":      12000, "fences_walls": 6000,
    "decor":         8000, "religious":    5000, "farm":         5000, "tavern":       4000,
    "containers_stacked": 3000, "signage":  2000, "wagons":       3000, "misc_gothic":  3000,
}
assert sum(QUOTAS.values()) == 150000, sum(QUOTAS.values())

# ---------------------------------------------------------------------------- subject bank (huge combinatorial space)
BANK = {
  "containers": (["barrel","cask","keg","wooden crate","iron-bound chest","treasure coffer","wicker basket",
    "burlap sack","clay urn","amphora","water bucket","cooking pot","storage bin","wooden box","ale tankard",
    "grain barrel","salt crate","oil jar","herb pot","apple basket"], 60),
  "furniture": (["wooden table","tavern chair","milking stool","long bench","straw bed","wardrobe","bookshelf",
    "cabinet","writing desk","carved throne","church pew","wooden cradle","chest of drawers","dresser",
    "round table","stool","footlocker","coat rack","weapon rack","spinning stool"], 55),
  "lighting": (["wall torch","iron brazier","hanging lantern","candelabra","wall sconce","street lamp post",
    "candle stub","oil lamp","fire pit","bonfire logs","lantern on a hook","tallow candle","chandelier"], 45),
  "market_food": (["bread loaf","cheese wheel","hanging sausages","fish on a rack","meat haunch","vegetable crate",
    "wine rack","fruit basket","hanging herbs","market stall","butcher block","grain sacks pile","egg basket",
    "pumpkin pile","onion braid","dried fish stack","honey pots","spice sacks"], 55),
  "tools": (["blacksmith anvil","grindstone wheel","wooden plow","scythe","spinning wheel","weaving loom",
    "forge bellows","whetstone","carpenter saw horse","wood chopping block","pitchfork in hay","hammer and tongs",
    "mortar and pestle","fishing net rack","butter churn","hand mill"], 40),
  "graveyard": (["weathered gravestone","gothic grave cross","stone tomb","sarcophagus","stone mausoleum",
    "pile of skulls","bone heap","open coffin","memorial slab","cracked headstone","iron grave fence",
    "candle-lit grave","withered wreath","crypt door","ossuary urn"], 55),
  "monuments": (["stone obelisk","hooded stone statue","roadside shrine","stone altar","dry fountain","stone well",
    "sundial","standing stone","stone cairn","carved pillar","triumphal arch","memorial column","idol statue",
    "rune stone","boundary marker"], 50),
  "ruins": (["broken stone column","rubble pile","collapsed wall","cracked archway","fallen statue","ruined tower base",
    "crumbled foundation","toppled pillar","ruined well","shattered gate","overgrown ruin block","broken staircase"], 50),
  "buildings": (["thatched cottage","stone townhouse","gothic chapel","gothic church","round watchtower",
    "blacksmith forge","timber tavern","windmill","barn","stable","gatehouse","harbor warehouse","ruined house",
    "guard house","manor house","bakery","apothecary hut","mill house","toll house","chapel ruin"], 45),
  "harbor": (["rowboat","fishing sailboat","dock pier deck","harbor crane","fishing net","mooring post","buoy",
    "ship anchor","cargo crate","fish barrel","lighthouse","rope coil","lobster pots","dock bollard"], 45),
  "nature": (["tree stump","mossy boulder","dead bush","fern cluster","cattail reeds","toadstool cluster","fallen log",
    "gnarled roots","hanging vines","moss patch","bramble thicket","lily pads","cracked rock","thorn bush",
    "dead sapling","mushroom ring","peat mound","reed clump"], 55),
  "fences_walls": (["wooden split-rail fence","dry-stone wall","iron gate","wooden palisade","hedge row",
    "picket fence","broken fence","stone gateposts","wattle fence","garden wall"], 45),
  "decor": (["hanging banner","cloth flag","wooden signpost","scarecrow","flower box","potted plant","door wreath",
    "hanging chains","bird cage","hourglass","stack of books","rolled scrolls","tapestry","rug","curtain"], 45),
  "religious": (["stone altar","prayer candles","gothic reliquary","censer","icon shrine","holy water font",
    "carved crucifix","offering bowl","kneeling bench","bell in a frame"], 40),
  "farm": (["hay bale","wheat sheaf","scarecrow","water trough","chicken coop","pig trough","milk churns",
    "vegetable patch","plow and yoke","fence gate","seed sacks","apple crate"], 40),
  "tavern": (["ale barrel row","tankard shelf","bar counter","hanging mugs","wine cask rack","fireplace",
    "round tavern table","stool set","dartboard","keg stack"], 40),
  "containers_stacked": (["stack of barrels","stack of crates","pile of sacks","stacked chests","pyramid of pots",
    "heap of baskets","tower of boxes"], 35),
  "signage": (["hanging tavern sign","wooden shop sign","crossroads signpost","warning post","milestone stone"], 35),
  "wagons": (["wooden hand cart","two-wheel wagon","covered cart","wheelbarrow","hay wagon","ox cart","broken wagon"], 35),
  "misc_gothic": (["gallows","stocks","pillory","wooden cage","gibbet","execution block","plague cart","raven perch"], 40),
}
MATERIAL = ["oak","pine","iron-bound","weathered grey","mossy","rotting","ancient","cracked","frost-rimed",
            "ash-dusted","blood-stained","rusted iron","gilded","tar-blackened","lichen-covered","sun-bleached",""]
STATE = ["","old and worn","half-buried","overgrown with weeds","charred","draped in cobwebs","chipped",
         "wind-battered","empty","full","tied with rope","bound in chains"]

CAT_TARGET_PX = {"buildings": 118, "harbor": 96, "monuments": 84, "ruins": 88, "graveyard": 64,
                 "furniture": 64, "wagons": 76, "tavern": 72, "religious": 68}
LACY = {"fences_walls", "nature"}   # bias these to single (no split) sometimes

# ---------------------------------------------------------------------------- BIOME ANCHORING (owner, 2026-07-06)
# --biome <name> makes every asset ZONE-MATCHED (owner law #1): the prompt carries a per-biome
# palette DESCRIPTOR, each cut sprite is PALETTE-LOCKED to that biome's reference palette (extracted
# from D:\raven hollow\reference\<biome>\*.png) BEFORE the gauntlet, and the gauntlet's style_anchor
# is pointed at the same biome folder. Category selection is narrowed to biome-legal categories so a
# bog run yields stumps/logs/stones/reeds/mushrooms/cairns — not tavern kegs tinted brown.
BIOME_REF_ROOT = os.environ.get("RH_BIOME_REF_ROOT", r"D:\raven hollow\reference")
BIOME_DESC = {
    "bog":        "muddy brown grey-green desaturated swamp, peat and stagnant water, wet rot",
    "cave":       "wet black stone, dripstone grey, pale fungal glow, lightless damp",
    "deadforest": "grey bark bone-pale leafless, ashen dead wood, colourless gloom",
    "farmland":   "tilled brown earth, straw gold, muted green crop, worn timber",
    "moor":       "heather purple-grey, wet peat brown, wind-bent olive grass, low fog",
    "port":       "weathered grey driftwood, tarred rope, brine-bleached salt, sea-slick stone",
    "ridge":      "cold slate-grey stone, pale lichen, thin alpine, wind-scoured rock",
    "steppe":     "dry tan grass, dust ochre, pale sun-bleached bone, sparse scrub",
    "tundra":     "pale snow frost, ice blue-grey, rimed stone, colourless cold",
    "volcanic":   "ash black char, scorched rock, ember-orange glow, cinder grey",
    "wilds":      "deep moss green overgrowth, tangled dark brush, damp bark, wet loam",
}
# biome-legal category whitelist (which props read as that biome). None = all categories.
BIOME_CATS = {
    "bog":        ["nature", "monuments"],
    "cave":       ["nature", "monuments", "ruins", "misc_gothic"],
    "deadforest": ["nature", "graveyard", "monuments", "ruins"],
    "farmland":   ["farm", "nature", "fences_walls", "tools", "containers"],
    "moor":       ["nature", "monuments", "graveyard", "ruins"],
    "port":       ["harbor", "nature", "containers", "fences_walls"],
    "ridge":      ["monuments", "ruins", "nature", "religious"],
    "steppe":     ["nature", "monuments", "fences_walls", "wagons"],
    "tundra":     ["nature", "monuments", "ruins", "graveyard"],
    "volcanic":   ["ruins", "monuments", "nature", "misc_gothic"],
    "wilds":      ["nature", "monuments", "ruins", "graveyard"],
}

_biome_pal_cache = {}


def biome_palette(biome, n=24):
    """Extract ~n dominant colours from a biome's reference art (owner law #1: zone-matched palette).
    Near-white extremes (rain streaks / alignment markers) are dropped so a lock never reintroduces a
    pale background block. Cached per biome. Returns a colour list or None (no reference art present)."""
    if biome in _biome_pal_cache:
        return _biome_pal_cache[biome]
    import glob as _glob
    d = os.path.join(BIOME_REF_ROOT, biome)
    files = sorted(_glob.glob(os.path.join(d, "*.png")) + _glob.glob(os.path.join(d, "*.jpg")))
    cols = []
    for f in files:
        try:
            q = Image.open(f).convert("RGB").quantize(colors=n, method=Image.MEDIANCUT)
            p = q.getpalette()[: n * 3]
            cols += [(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)]
        except Exception:
            pass
    cols = [c for c in cols if min(c) < 232]      # drop rain-white / marker-white
    _biome_pal_cache[biome] = cols or None
    return _biome_pal_cache[biome]


def palette_lock(im, palette):
    """Nearest-colour map every OPAQUE pixel onto the biome reference palette (binary alpha preserved).
    Runs on each cut sprite BEFORE the gauntlet so the asset physically sits in the zone's colours."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    cache = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            key = (r, g, b)
            nc = cache.get(key)
            if nc is None:
                nc = min(palette, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
                cache[key] = nc
            px[x, y] = (nc[0], nc[1], nc[2], a)
    return im


def _log(msg):
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# ---------------------------------------------------------------------------- perceptual hash (dedup)
def dhash(im, n=8):
    g = im.convert("L").resize((n + 1, n), Image.LANCZOS)
    px = list(g.getdata())
    bits = 0
    for r in range(n):
        row = r * (n + 1)
        for c in range(n):
            bits = (bits << 1) | (1 if px[row + c] > px[row + c + 1] else 0)
    return bits


def hamming(a, b):
    return bin(a ^ b).count("1")


# ---------------------------------------------------------------------------- state
def load_state():
    os.makedirs(LIB_ROOT, exist_ok=True)
    man = {"counts": {c: 0 for c in QUOTAS}, "total": 0, "generated": 0, "rejected": 0,
           "dedup_hits": 0, "started": time.time()}
    if os.path.exists(MANIFEST):
        try:
            man.update(json.load(open(MANIFEST, encoding="utf-8")))
        except Exception:
            pass
    ph = {c: [] for c in QUOTAS}
    if os.path.exists(PHASH_JSON):
        try:
            raw = json.load(open(PHASH_JSON, encoding="utf-8"))
            for c in QUOTAS:
                ph[c] = [int(x) for x in raw.get(c, [])]
        except Exception:
            pass
    return man, ph


def save_state(man, ph):
    json.dump(man, open(MANIFEST, "w", encoding="utf-8"), indent=2)
    json.dump({c: [str(x) for x in v] for c, v in ph.items()}, open(PHASH_JSON, "w", encoding="utf-8"))


def load_lib():
    if os.path.exists(LIB_JSON):
        try:
            return json.load(open(LIB_JSON, encoding="utf-8"))
        except Exception:
            pass
    return {"version": 1, "target": TARGET_DEFAULT, "assets": []}


def disk_free_gb(path):
    try:
        return shutil.disk_usage(os.path.splitdrive(path)[0] + os.sep).free / (1024 ** 3)
    except Exception:
        return 999


# ---------------------------------------------------------------------------- prompt + prune
def compose(cat, biome=None):
    subs, tpx = BANK[cat]
    base = random.choice(subs)
    mat = random.choice(MATERIAL)
    st = random.choice(STATE)
    subject = " ".join(x for x in [mat, base, st] if x).strip()
    bg = "magenta" if cat == "nature" and random.random() < 0.5 else "green"
    desc = BIOME_DESC.get(biome) if biome else None
    prefix = f"{subject}, {desc}, " if desc else f"{subject}, "
    pos = prefix + G.STYLE.format(bg=G.BGWORDS[bg])
    return subject, pos, CAT_TARGET_PX.get(cat, tpx if isinstance(tpx, int) else 60)


def prune_raw(info):
    """Delete the ComfyUI output file for a fetched image (disk law: keep only final sprites)."""
    try:
        sub = info.get("subfolder", "")
        p = os.path.join(COMFY_OUT, sub, info["filename"])
        if os.path.exists(p):
            os.remove(p)
    except Exception:
        pass


# ---------------------------------------------------------------------------- one job
def run_one(cat, man, ph, lib, biome=None, palette=None, saved=None):
    subject, pos, tpx = compose(cat, biome)
    seed = random.randint(1, 2_000_000_000)
    wf = G.sdxl_workflow(pos, G.NEG, seed, w=1024, h=1024)
    wf["5"]["inputs"]["batch_size"] = BATCH
    imgs = G.run_workflow(wf)
    accepted = 0
    if not imgs:
        return 0
    for info in imgs:
        try:
            full = G._fetch_image(info)
        finally:
            prune_raw(info)                       # DELETE RAW IMMEDIATELY
        man["generated"] += 1
        # Biome runs ALWAYS split (one-sprite-per-cell) so a grid/contact-sheet render is cut into
        # individual props instead of stored as an uncut card — the LACY single-mode shortcut is off.
        single = False if biome else (cat in LACY and random.random() < 0.5)
        objs = I.process_render(full, target_px=tpx, split=not single)
        for obj in objs:
            if palette:
                obj = palette_lock(obj, palette)          # BIOME PALETTE-LOCK — before the gauntlet
            ok, sc = I.cleanliness_report(obj, require_single_subject=not single)
            if not ok:
                man["rejected"] += 1
                continue
            gok, gv = GAUNTLET.run_gauntlet(obj)          # THE VISION GAUNTLET — unanimous or rejected
            if not gok:
                man["rejected"] += 1
                man.setdefault("gauntlet_rejected", 0)
                man["gauntlet_rejected"] += 1
                continue
            h = dhash(obj)
            if any(hamming(h, e) <= DHASH_MIN_DISTANCE for e in ph[cat]):
                man["dedup_hits"] += 1
                continue
            ph[cat].append(h)
            n = man["counts"][cat]
            aid = f"{cat}_{n:06d}"
            cdir = os.path.join(LIB_ROOT, cat)
            os.makedirs(cdir, exist_ok=True)
            outp = os.path.join(cdir, aid + ".png")
            obj.save(outp)
            entry = {
                "id": aid, "category": cat, "path": f"{cat}/{aid}.png", "size": sc["size"],
                "animated": False, "subject": subject, "source": "comfyui:sdxl+pixelartxl",
                "license": "generated-original (CC0, owner-owned)", "dhash": str(h), "verdict": "PASS",
            }
            if biome:
                entry["biome"] = biome
            lib["assets"].append(entry)
            if saved is not None:
                saved.append({"id": aid, "category": cat, "path": outp, "subject": subject})
            man["counts"][cat] += 1
            man["total"] += 1
            accepted += 1
    return accepted


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", type=int, default=TARGET_DEFAULT)
    ap.add_argument("--burst", type=int, default=0, help="stop after N accepted (stress test)")
    ap.add_argument("--report", action="store_true", help="print manifest + throughput and exit")
    ap.add_argument("--biome", default=None, help="zone-match assets to a biome (bog, volcanic, port, "
                    "tundra, deadforest, ...): biome prompt descriptor + reference palette-lock + "
                    "biome-anchored gauntlet style-anchor + biome-legal categories only")
    args = ap.parse_args()

    man, ph = load_state()
    lib = load_lib()
    lib["target"] = args.target

    # ---- biome anchoring setup (owner law #1, 2026-07-06) -------------------------------------
    biome = args.biome
    palette = None
    biome_saved = None
    allowed_cats = None
    if biome:
        if biome not in BIOME_DESC:
            _log(f"!! unknown biome '{biome}'. Known: {', '.join(sorted(BIOME_DESC))}"); return
        palette = biome_palette(biome)
        refdir = os.path.join(BIOME_REF_ROOT, biome)
        GAUNTLET.set_style_anchor([refdir])               # point the style-anchor at THIS biome only
        allowed_cats = BIOME_CATS.get(biome)
        biome_saved = []
        _log(f"BIOME={biome} | palette={len(palette) if palette else 0} colours from {refdir} | "
             f"cats={allowed_cats or 'ALL'} | {'palette-lock ON' if palette else 'NO REF PALETTE (lock off)'}")

    if args.report:
        el = max(1e-9, time.time() - man["started"])
        print(json.dumps({"total": man["total"], "counts": man["counts"], "generated": man["generated"],
                          "rejected": man["rejected"], "dedup_hits": man["dedup_hits"]}, indent=2))
        return

    start_total = man["total"]
    t0 = time.time()
    save_every = 0
    while man["total"] < args.target:
        if args.burst and (man["total"] - start_total) >= args.burst:
            break
        free = disk_free_gb(LIB_ROOT)
        if free < DISK_MIN_GB:
            _log(f"!! DISK GUARD: {free:.1f}GB free < {DISK_MIN_GB}GB — STOPPING. (#97 disk-watcher)")
            break
        # pick the category furthest from its quota (fill evenly), skip full ones; a biome run is
        # narrowed to that biome's legal categories so props read as the zone.
        rem = [(c, QUOTAS[c] - man["counts"][c]) for c in QUOTAS
               if man["counts"][c] < QUOTAS[c] and (allowed_cats is None or c in allowed_cats)]
        if not rem:
            _log("TARGET QUOTAS ALL MET."); break
        cat = random.choices([c for c, _ in rem], weights=[max(1, r) for _, r in rem])[0]
        try:
            acc = run_one(cat, man, ph, lib, biome=biome, palette=palette, saved=biome_saved)
        except Exception as e:
            _log(f"job error ({cat}): {e}"); time.sleep(3); continue
        save_every += 1
        if save_every % 3 == 0 or args.burst:
            save_state(man, ph)
            json.dump(lib, open(LIB_JSON, "w", encoding="utf-8"))
        made = man["total"] - start_total
        el = time.time() - t0
        rate = made / el * 3600 if el > 0 else 0
        _log(f"+{acc} {cat}  total={man['total']}  this_run={made}  gen={man['generated']} "
             f"rej={man['rejected']} dup={man['dedup_hits']}  {rate:.0f} assets/hr  free={free:.0f}GB")

    save_state(man, ph)
    json.dump(lib, open(LIB_JSON, "w", encoding="utf-8"))
    if biome and biome_saved is not None:
        sidecar = os.path.join(LIB_ROOT, f"_biome_last_{biome}.json")
        json.dump({"biome": biome, "count": len(biome_saved), "assets": biome_saved},
                  open(sidecar, "w", encoding="utf-8"), indent=2)
        _log(f"BIOME {biome}: {len(biome_saved)} accepted this run -> sidecar {sidecar}")
    made = man["total"] - start_total
    el = time.time() - t0
    rate = made / el * 3600 if el > 0 else 0
    remain = max(0, args.target - man["total"])
    days = remain / rate / 24 if rate > 0 else float("inf")
    _log(f"== run end: +{made} accepted in {el/60:.1f} min | {rate:.0f} assets/hr | "
         f"gen={man['generated']} rej={man['rejected']} dup={man['dedup_hits']} | "
         f"total={man['total']}/{args.target} | projected {days:.1f} days to target ==")


if __name__ == "__main__":
    main()
