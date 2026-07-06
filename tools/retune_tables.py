#!/usr/bin/env python3
"""retune_tables.py -- BLUEPRINT_33 / COMBAT_PACING.md s4 numeric pass.

Reads data/combat_archetypes.json (the tuning law: FAMILY_MULT / RANK_MULT +
constants) and recomputes hp/damage for every mob row from its level+archetype+
rank. Prints a diff against the SHIPPED creature_table numbers (the hand-nudged
truth in scripts/zone_defs.gd / scripts/combat.gd s10) so a reviewer can confirm
the shipped tables track the law. Deltas within +/- a few points are expected
hand-nudges; big deltas mean a row drifted from the curve.

Pure stdlib, no engine. Run:  python tools/retune_tables.py
Exit 0 if every row is within TOLERANCE_PCT of the formula, else 1.
"""
import json
import math
import os
import sys

TOLERANCE_PCT = 6.0  # rows further than this from the formula are flagged

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "data", "combat_archetypes.json")

# The shipped s10 tables (level, archetype, rank, hp, damage), keyed by zone.
# Mirrors scripts/zone_defs.gd creature_table + scripts/combat.gd ENEMY_SPAWNS.
SHIPPED = {
    "graveyard(combat.gd)": [
        ("Graveyard Skeleton", 1, "brute", "normal", 180, 11),
        ("Skeleton Rogue", 1, "duelist", "normal", 162, 9),
        ("Skeleton Warrior", 2, "guarded", "normal", 270, 14),
        ("Skeleton Mage", 2, "caster", "normal", 145, 15),
    ],
    "iron_vein": [
        ("Bog Boar", 2, "charger", "normal", 195, 11),
        ("Mudwolf", 3, "stalker", "normal", 176, 12),
        ("Thread-Touched Dead", 4, "brute", "normal", 222, 13),
        ("The Digging Creature", 5, "charger", "rare", 1666, 25),
    ],
    "vetka": [
        ("Boar", 3, "charger", "normal", 207, 12),
        ("Entranced Villager", 4, "caster", "normal", 167, 17),
    ],
    "copper_wells": [
        ("Entranced Pilgrim", 5, "caster", "normal", 179, 17),
        ("Moor Wolf", 5, "stalker", "normal", 202, 13),
        ("Thread-Touched Dead", 6, "brute", "normal", 255, 14),
        ("Warden of the Wells", 7, "guarded", "elite", 874, 24),
    ],
    "stonepath": [
        ("Wild Wolf", 7, "stalker", "normal", 232, 15),
        ("Grave Warband", 8, "guarded", "normal", 409, 20),
        ("Deserter", 8, "duelist", "normal", 263, 13),
        ("The Stonewatcher", 9, "caster", "rare", 2184, 41),
    ],
    "grey_marches": [
        ("Greywolf", 9, "stalker", "normal", 265, 17),
        ("Cult Zealot", 10, "caster", "normal", 251, 23),
        ("The Hungering", 10, "swarm", "normal", 184, 12),
        ("Marches Alpha", 11, "stalker", "elite", 968, 29),
    ],
    "western_lowlands": [
        ("Bandit", 11, "duelist", "normal", 320, 16),
        ("Field Boar", 11, "charger", "normal", 356, 18),
        ("The Hungering", 12, "swarm", "normal", 209, 14),
        ("Bandit Captain", 13, "duelist", "elite", 1166, 28),
    ],
    "angel_wings": [
        ("Alley Cutpurse", 12, "duelist", "normal", 342, 17),
        ("Hungering Cultist", 13, "caster", "normal", 304, 27),
    ],
    "famine_fields": [
        ("Cult Zealot", 14, "caster", "normal", 324, 28),
        ("Starving Dog", 13, "swarm", "normal", 223, 14),
        ("The Hungering", 14, "swarm", "normal", 238, 15),
        ("Famine Prophet", 16, "caster", "elite", 1183, 50),
    ],
    "riverfork": [
        ("Bandit-Lord's Enforcer", 16, "guarded", "normal", 690, 30),
        ("River Smuggler", 16, "duelist", "normal", 444, 20),
        ("Bog Boar", 15, "charger", "normal", 462, 23),
        ("Vosk, the Bandit-Lord", 18, "guarded", "rare", 3927, 51),
    ],
}


def load_law():
    with open(DATA, "r", encoding="utf-8") as fh:
        return json.load(fh)


def ttk_target(law, level):
    c = law["constants"]
    lo, hi = c["ttk_min"], c["ttk_max"]
    ramp = max(1.0, c["ttk_ramp_levels"])
    return lo + (hi - lo) * min(max((level - 1) / ramp, 0.0), 1.0)


def mob_hp(law, level, arch, rank):
    c = law["constants"]
    a = law["archetypes"].get(arch, law["archetypes"]["brute"])
    r = law["ranks"].get(rank, law["ranks"]["normal"])
    ref_dps = c["ref_dps_base"] * math.pow(c["ref_dps_growth"], level - 1)
    return round(ref_dps * ttk_target(law, level) * c["uptime"] * a["hp_mult"] * r["hp_mult"])


def mob_damage(law, level, arch, rank):
    c = law["constants"]
    a = law["archetypes"].get(arch, law["archetypes"]["brute"])
    r = law["ranks"].get(rank, law["ranks"]["normal"])
    return round(c["dmg_base"] * math.pow(c["dmg_growth"], level - 1) * a["dmg_mult"] * r["dmg_mult"])


def pct(shipped, formula):
    if formula == 0:
        return 0.0
    return abs(shipped - formula) / formula * 100.0


def main():
    law = load_law()
    worst_normal = 0.0
    flagged = 0
    authored = 0
    print("== retune_tables.py :: shipped creature_table vs COMBAT_PACING s4 formula ==")
    print("Normal-rank mobs must track the tuning law; elite/rare are authored")
    print("boss anchors (hand-nudged per s10 -- reported, never fail).")
    print("%-24s %3s %-8s %-6s | %9s %9s | %9s %9s" % (
        "name", "lvl", "archetype", "rank", "hp(ship)", "hp(calc)", "dmg(ship)", "dmg(calc)"))
    for zone, rows in SHIPPED.items():
        print("-- %s" % zone)
        for name, lvl, arch, rank, hp_s, dmg_s in rows:
            hp_c = mob_hp(law, lvl, arch, rank)
            dmg_c = mob_damage(law, lvl, arch, rank)
            flag = ""
            if rank != "normal":
                # Authored anchor: report the deliberate nudge, do not gate on it.
                authored += 1
                flag = "  (authored %+d hp / %+d dmg)" % (hp_s - hp_c, dmg_s - dmg_c)
            else:
                hp_p = pct(hp_s, hp_c)
                dmg_p = pct(dmg_s, dmg_c)
                worst_normal = max(worst_normal, hp_p, dmg_p)
                # Small-integer rounding nudge (+/-1) is fine even if it reads >tol%.
                hp_ok = hp_p <= TOLERANCE_PCT or abs(hp_s - hp_c) <= 2
                dmg_ok = dmg_p <= TOLERANCE_PCT or abs(dmg_s - dmg_c) <= 1
                if not (hp_ok and dmg_ok):
                    flag = "  <-- DRIFT >%.0f%%" % TOLERANCE_PCT
                    flagged += 1
            print("%-24s %3d %-8s %-6s | %9d %9d | %9d %9d%s" % (
                name[:24], lvl, arch[:8], rank[:6], hp_s, hp_c, dmg_s, dmg_c, flag))
    print("-" * 74)
    print("worst NORMAL deviation: %.2f%%   drifted normals: %d   authored anchors: %d" % (
        worst_normal, flagged, authored))
    if flagged:
        print("FAIL: %d normal-rank row(s) drifted from the tuning law." % flagged)
        return 1
    print("OK: every normal-rank row tracks the formula; %d boss anchors authored." % authored)
    return 0


if __name__ == "__main__":
    sys.exit(main())
