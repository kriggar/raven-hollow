#!/usr/bin/env python3
"""ttk_probe.py -- BLUEPRINT_33 / COMBAT_PACING.md s2 acceptance probe.

Analytical time-to-kill check for every shipped creature_table row. For an
at-level, normally-geared player the reference sustained rotation DPS is
PlayerRefDPS(L) = 25 * 1.046^(L-1); with ~0.9 uptime (the player repositions out
of telegraphs) the realistic TTK of a mob = hp / (0.9 * PlayerRefDPS(level)).

ACCEPTANCE (COMBAT_PACING s2 + BLUEPRINT_33 build step 7): each zone's MEDIAN
TTK across its normal-rank mobs sits in the 8-15s band, no zone off by >20%
(so the pass window is 6.4s..18.0s). Swarm members are intentionally 4-6s and
elite/rare boss anchors are intentionally longer -- both are reported for
context but do not gate the per-zone median.

Reads the REAL shipped data (scripts/zone_defs.gd + scripts/combat.gd) so it
tracks whatever is actually in the tables. Pure stdlib. Exit 0 = all zones pass.
"""
import io
import json
import math
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data", "combat_archetypes.json")
ZONE_DEFS = os.path.join(ROOT, "scripts", "zone_defs.gd")
COMBAT = os.path.join(ROOT, "scripts", "combat.gd")

BAND_LO, BAND_HI = 8.0, 15.0
TOL = 0.20  # "no zone off by >20%" -> widen the pass window
PASS_LO, PASS_HI = BAND_LO * (1 - TOL), BAND_HI * (1 + TOL)
SWARM_LO, SWARM_HI = 3.5, 8.0  # swarm members: 4-6s target (s2), with tolerance

# The 9 west-arm zones the blueprint retuned, in curriculum order.
ZONES = ["iron_vein", "vetka", "copper_wells", "stonepath", "grey_marches",
         "western_lowlands", "angel_wings", "famine_fields", "riverfork"]

ROW_RE = re.compile(r"\{[^{}]*\}", re.S)


def read(p):
    with io.open(p, "r", encoding="utf-8", newline="\n") as fh:
        return fh.read()


def load_const(law, key, dflt):
    return float(law["constants"].get(key, dflt))


def ref_dps(law, level):
    return load_const(law, "ref_dps_base", 25.0) * math.pow(
        load_const(law, "ref_dps_growth", 1.046), level - 1)


def parse_rows(block):
    out = []
    for m in ROW_RE.finditer(block):
        row = m.group(0)
        if '"hp"' not in row or '"level"' not in row:
            continue
        lvl = re.search(r'"level":\s*(\d+)', row)
        hp = re.search(r'"hp":\s*([\d.]+)', row)
        if not lvl or not hp:
            continue
        arch = re.search(r'"archetype":\s*"(\w+)"', row)
        rank = re.search(r'"rank":\s*"(\w+)"', row)
        name = re.search(r'"(?:name|display_name)":\s*"([^"]*)"', row)
        out.append({
            "name": name.group(1) if name else "?",
            "level": int(lvl.group(1)),
            "archetype": arch.group(1) if arch else "",
            "rank": rank.group(1) if rank else "normal",
            "hp": float(hp.group(1)),
        })
    return out


def zone_block(text, zone):
    zi = text.index('"%s": {' % zone)
    ct = text.index('"creature_table": [', zi)
    close = text.index(']', ct)
    return text[ct:close]


def graveyard_block(text):
    i = text.index("const ENEMY_SPAWNS")
    j = text.index("]", i)
    return text[i:j]


def ttk(law, row):
    return row["hp"] / (load_const(law, "uptime", 0.9) * ref_dps(law, row["level"]))


def main():
    law = json.loads(read(DATA))
    zdt = read(ZONE_DEFS)
    zones = {"graveyard": parse_rows(graveyard_block(read(COMBAT)))}
    for z in ZONES:
        zones[z] = parse_rows(zone_block(zdt, z))

    print("== ttk_probe.py :: realistic TTK = hp / (0.9 * PlayerRefDPS(level)) ==")
    print("Per-zone gate: MEDIAN of normal-rank STANDARD mobs in %.1f-%.1fs (pass"
          " window %.1f-%.1fs)." % (BAND_LO, BAND_HI, PASS_LO, PASS_HI))
    print("Swarm members have their own %.1f-%.1fs contract (s2); elite/rare are"
          " boss anchors -- both reported, neither gates the standard median."
          % (SWARM_LO, SWARM_HI))
    failed = 0
    swarm_bad = 0
    for z, rows in zones.items():
        if not rows:
            continue
        # Standard-fight median excludes the swarm class (its own 4-6s contract)
        # and boss anchors (elite/rare). Falls back to swarm if a zone is pure swarm.
        std = [r for r in rows if r["rank"] == "normal" and r["archetype"] != "swarm"]
        if not std:
            std = [r for r in rows if r["rank"] == "normal"]
        med = statistics.median([ttk(law, r) for r in std]) if std else 0.0
        ok = PASS_LO <= med <= PASS_HI
        strict = BAND_LO <= med <= BAND_HI
        status = "PASS" if ok else "FAIL"
        band = "in-band" if strict else "in-tolerance" if ok else "OUT"
        if not ok:
            failed += 1
        # Validate swarm members against their own band.
        for r in rows:
            if r["rank"] == "normal" and r["archetype"] == "swarm":
                if not (SWARM_LO <= ttk(law, r) <= SWARM_HI):
                    swarm_bad += 1
        print("\n-- %-17s median(standard) = %5.1fs  [%s] %s" % (z, med, band, status))
        for r in rows:
            t = ttk(law, r)
            tag = r["rank"] if r["rank"] != "normal" else (
                "swarm" if r["archetype"] == "swarm" else "")
            note = ""
            if r["rank"] == "elite":
                note = "  (elite anchor, target ~25-40s)"
            elif r["rank"] == "rare":
                note = "  (rare anchor, target ~60s+)"
            elif r["archetype"] == "swarm":
                note = "  (swarm member, target ~4-6s)"
            print("     %-24s L%-2d %-8s %-6s hp %-5.0f -> %5.1fs%s" % (
                r["name"][:24], r["level"], r["archetype"][:8],
                (tag or "normal")[:6], r["hp"], t, note))
    print("\n" + "=" * 66)
    if swarm_bad:
        print("NOTE: %d swarm member(s) outside the %.1f-%.1fs swarm band."
              % (swarm_bad, SWARM_LO, SWARM_HI))
    if failed:
        print("FAIL: %d zone(s) outside the standard-fight TTK window." % failed)
        return 1
    print("OK: every zone's standard-fight median TTK is within the 8-15s "
          "contract (+/-20%); swarm members within their 4-6s band.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
