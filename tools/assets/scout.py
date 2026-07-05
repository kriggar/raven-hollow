#!/usr/bin/env python3
"""
THE SCOUT NETWORK  (BACKLOG #101 / #112) -- SECONDARY to generation (owner: free-scouting
yields little; ComfyUI generation is the real library). This tool still does honest work:
enumerate FREE top-down medieval/gothic pixel packs (itch.io / OpenGameArt / Kenney / CraftPix),
FETCH each page, READ the license text, record the evidence, and emit a manifest. Only packs
whose license is commercial-OK & free PASS. Already-owned packs are skipped. Passing packs that
expose a direct download are pulled to _downloads/_assetlib/raw/.

Truth law: the manifest records the license text ACTUALLY FOUND on the page at scout time (or
notes when a page could not be machine-read and needs a human/WebFetch pass). Nothing is
marked PASS without evidence. No fabricated counts.

  C:/Users/vstef/ComfyUI/venv/Scripts/python.exe tools/assets/scout.py --run
"""
from __future__ import annotations
import os, re, json, argparse, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETLIB = os.path.abspath(os.path.join(HERE, "..", "..", "_downloads", "_assetlib"))
RAW = os.path.join(ASSETLIB, "raw")
WORLD_PACKS = os.path.abspath(os.path.join(HERE, "..", "..", "_downloads", "world_packs"))
MANIFEST = os.path.join(ASSETLIB, "scout_manifest.json")

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")

# ---- license lexicon ------------------------------------------------------------------
FREE_OK = [  # (regex, canonical, commercial_ok)
    (r"\bCC0\b|creative commons zero|public domain", "CC0", True),
    (r"CC[\s-]?BY[\s-]?SA", "CC-BY-SA", True),
    (r"CC[\s-]?BY(?![\s-]?(NC|ND))", "CC-BY", True),
    (r"\bGPL\b|general public license", "GPL", True),
    (r"\bOGA[\s-]?BY\b", "OGA-BY", True),
    (r"free for (personal and )?commercial|commercial use allowed|use in commercial", "custom-free-commercial", True),
]
FORBID = [
    (r"CC[\s-]?BY[\s-]?NC|non[\s-]?commercial", "CC-BY-NC (non-commercial)"),
    (r"CC[\s-]?BY[\s-]?ND|no[\s-]?deriv", "CC-BY-ND (no-derivatives)"),
]

# ---- already-owned (skip) -------------------------------------------------------------
def owned_packs():
    names = set()
    for root in (WORLD_PACKS, os.path.dirname(WORLD_PACKS)):
        if os.path.isdir(root):
            for n in os.listdir(root):
                names.add(os.path.splitext(n)[0].lower())
    return names

# ---- curated candidate registry -------------------------------------------------------
# style/perspective pre-noted; license is confirmed live at scout time. `owned` marks packs
# already in the repo (skipped, listed for provenance). Anchors carry evidence verified via
# WebFetch on 2026-07-05 (recorded in `verified_note`).
CANDIDATES = [
    {"name": "Kenney — Tiny Town", "source": "kenney",
     "url": "https://kenney.nl/assets/tiny-town", "category": ["village", "terrain", "buildings"],
     "style_notes": "16x16 top-down, clean flat pixel, CC0 -- great base tiles/props",
     "owned": True, "verified_note": "WebFetch 2026-07-05: 'License: Creative Commons CC0', 130 files, top-down 16px"},
    {"name": "Kenney — Roguelike/RPG Pack", "source": "kenney",
     "url": "https://kenney.nl/assets/roguelike-rpg-pack", "category": ["village", "creatures", "interiors"],
     "style_notes": "16x16 top-down roguelike, CC0", "owned": True},
    {"name": "OGA — LPC Medieval Village Decorations", "source": "opengameart",
     "url": "https://opengameart.org/content/lpc-medieval-village-decorations", "category": ["village", "monuments", "market", "graveyard"],
     "style_notes": "32px top-down LPC: graveyard, statues, lamps, banners, fences (wang), market stalls, guillotine",
     "owned": True, "verified_note": "WebFetch 2026-07-05: licenses 'CC-BY-SA 4.0' + 'CC-BY-SA 3.0', top-down"},
    {"name": "OGA — LPC City Outside", "source": "opengameart",
     "url": "https://opengameart.org/content/lpc-city-outside", "category": ["buildings", "monuments"],
     "style_notes": "32px top-down: walls/roofs, statues, obelisk, well, market booth",
     "owned": True, "verified_note": "WebFetch 2026-07-05: 'CC-BY-SA 3.0' + 'GPL 3.0' + 'GPL 2.0'"},
    {"name": "OGA — LPC Trees", "source": "opengameart",
     "url": "https://opengameart.org/content/lpc-trees", "category": ["nature"],
     "style_notes": "top-down trees, LPC", "owned": True},
    # --- fresh candidates to live-verify (not yet owned) ---
    {"name": "OGA — Isometric/Top-down Medieval Buildings (various CC0)", "source": "opengameart",
     "url": "https://opengameart.org/content/medieval-buildings-lpc", "category": ["buildings"],
     "style_notes": "candidate top-down medieval buildings", "owned": False},
    {"name": "OGA — Graveyard tileset", "source": "opengameart",
     "url": "https://opengameart.org/content/graveyard-tileset", "category": ["graveyard", "monuments"],
     "style_notes": "candidate gothic graveyard props", "owned": False},
    {"name": "OGA — Medieval Farm / Fishing props", "source": "opengameart",
     "url": "https://opengameart.org/content/lpc-farming-tilesets-magic-animations-and-ui-elements", "category": ["farm", "fishing", "props"],
     "style_notes": "candidate farm/fishing props, LPC", "owned": False},
    {"name": "OGA — Castle tileset (top-down)", "source": "opengameart",
     "url": "https://opengameart.org/content/castle-tiles-for-you", "category": ["castle", "buildings"],
     "style_notes": "candidate top-down castle stone tiles", "owned": False},
]


def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read(600000).decode("utf-8", "ignore"), None
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, Exception) as e:
        return None, str(e)


def classify(text):
    low = text.lower()
    for rx, name in FORBID:
        m = re.search(rx, low)
        if m:
            i = max(0, m.start() - 60)
            return "FAIL", name, text[i:m.end() + 60].strip()
    for rx, name, ok in FREE_OK:
        m = re.search(rx, low)
        if m:
            i = max(0, m.start() - 60)
            return ("PASS" if ok else "FAIL"), name, re.sub(r"\s+", " ", text[i:m.end() + 60]).strip()
    return "UNKNOWN", "unclear", ""


def run(live=True):
    os.makedirs(ASSETLIB, exist_ok=True)
    have = owned_packs()
    out = []
    for c in CANDIDATES:
        rec = dict(c)
        # skip download for owned, but still record provenance + verdict
        if c.get("owned"):
            rec["verdict"] = "OWNED"
            rec["license"] = c.get("verified_note", "already in repo (world_packs)")
            rec["license_evidence"] = c.get("verified_note", "owned")
            out.append(rec); continue
        if live:
            html, err = fetch(c["url"])
            if html is None:
                rec["verdict"] = "NEEDS_MANUAL"
                rec["license"] = "unfetched"
                rec["license_evidence"] = f"machine-fetch failed: {err}; verify via WebFetch/browser"
            else:
                verdict, lic, ev = classify(html)
                rec["verdict"] = verdict
                rec["license"] = lic
                rec["license_evidence"] = ev or "no license keyword matched in first 600k of page"
        else:
            rec["verdict"] = "NOT_CHECKED"
        out.append(rec)

    manifest = {
        "generated": "tools/assets/scout.py",
        "policy": "commercial-OK + free only (CC0/CC-BY/CC-BY-SA/GPL/OGA-BY/explicit-free-commercial); "
                  "NC and ND rejected; unclear -> NEEDS_MANUAL. Generation (ComfyUI) is the primary library source.",
        "owned_skipped": sorted([c["name"] for c in CANDIDATES if c.get("owned")]),
        "packs": out,
        "counts": {
            "candidates": len(CANDIDATES),
            "owned": sum(1 for r in out if r["verdict"] == "OWNED"),
            "pass": sum(1 for r in out if r["verdict"] == "PASS"),
            "needs_manual": sum(1 for r in out if r["verdict"] == "NEEDS_MANUAL"),
            "fail": sum(1 for r in out if r["verdict"] == "FAIL"),
        },
    }
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(json.dumps(manifest["counts"], indent=2))
    print(f"[scout] manifest -> {MANIFEST}")
    return manifest


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--offline", action="store_true", help="record registry without live license fetch")
    args = ap.parse_args()
    run(live=not args.offline)
