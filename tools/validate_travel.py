# Travel-seam validator (QA stack, BACKLOG #48/#98 support).
# Parses scripts/zone_defs.gd and checks that every travel_point in every
# built zone round-trips: A.p -> B.q implies B.q -> A.p. A typo here is a
# one-way door the player can fall through — catch it before boot.
# Usage: python tools/validate_travel.py   (exit 1 on any failure)
import io
import re
import sys

DEFS = "scripts/zone_defs.gd"


def main() -> int:
    s = io.open(DEFS, encoding="utf-8").read()
    zones = {}
    for zm in re.finditer(r'\n\t"(\w+)": \{', s):
        zid = zm.group(1)
        nxt = re.search(r'\n\t"(\w+)": \{', s[zm.end():])
        block = s[zm.start(): zm.end() + (nxt.start() if nxt else len(s))]
        if '"built": true' not in block:
            continue
        tp_m = re.search(r'"travel_points": \[(.*?)\n\t\t\],', block, re.S)
        pts = {}
        if tp_m:
            for pm in re.finditer(
                    r'"id": "(\w+)",.*?"to_map": "(\w+)", "to_point": "(\w+)"',
                    tp_m.group(1), re.S):
                pts[pm.group(1)] = (pm.group(2), pm.group(3))
        zones[zid] = pts

    bad = 0
    for zid, pts in zones.items():
        for pid, (tm, tp) in pts.items():
            if tm in ("town", "wilderness"):  # legacy maps own their gates
                continue
            if tm not in zones:
                print(f"MISSING ZONE: {zid}.{pid} -> {tm}")
                bad += 1
            elif tp not in zones[tm]:
                print(f"MISSING POINT: {zid}.{pid} -> {tm}.{tp}")
                bad += 1
            elif zones[tm][tp] != (zid, pid):
                print(f"NON-RECIPROCAL: {zid}.{pid} -> {tm}.{tp} "
                      f"(returns to {zones[tm][tp]})")
                bad += 1
    print(f"{len(zones)} built zones; "
          + ("ALL SEAMS RECIPROCAL - PASS" if bad == 0 else f"{bad} FAILURES"))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
