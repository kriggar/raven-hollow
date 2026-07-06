# -*- coding: utf-8 -*-
"""
BLUEPRINT_99 collision audit / validator.

Cross-checks data/collision_map.json against the prop/landmark/vignette types
that scripts/zone_builder.gd actually emits (its match arms are the source of
truth), then prints the audit table: every type -> collision_kind + footprint.

FAILS (exit 1) if the builder emits a type with no collision_map entry, i.e.
coverage is incomplete. Pure static analysis -- no Godot required. ASCII only
(cp1252 console safe).

Usage:  python tools/collision_audit.py
"""
import io, os, re, json, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP_PATH = os.path.join(ROOT, "data", "collision_map.json")
BUILDER = os.path.join(ROOT, "scripts", "zone_builder.gd")

ARM_RE = re.compile(r'^\t+"([a-z_]+)":\s*$')


def read(path):
    with io.open(path, "r", encoding="utf-8") as f:
        return f.read()


def match_arms(src, func_name):
    """Type strings from the `match` block inside a static func."""
    m = re.search(r'static func %s\b' % re.escape(func_name), src)
    if not m:
        return []
    start = m.start()
    nxt = re.search(r'\nstatic func ', src[start + 10:])
    end = start + 10 + nxt.start() if nxt else len(src)
    arms = []
    for line in src[start:end].splitlines():
        am = ARM_RE.match(line)
        if am:
            arms.append(am.group(1))
    # de-dup, keep order
    seen = set()
    out = []
    for a in arms:
        if a not in seen:
            seen.add(a)
            out.append(a)
    return out


def fmt_shape(entry):
    k = entry.get("kind", "none")
    if k in ("none", "building"):
        return ""
    if k == "circle":
        return "r=%g off_y=%g" % (entry.get("w", 0), entry.get("off_y", 0))
    if k in ("ellipse", "ring"):
        return "rx=%g ry=%g off_y=%g" % (entry.get("w", 0), entry.get("h", 0), entry.get("off_y", 0))
    if k == "strip":
        return "%gx%g off_y=%g" % (entry.get("w", 0), entry.get("h", 0), entry.get("off_y", 0))
    if k == "pushable":
        return "%gx%g mass=%g" % (entry.get("w", 0), entry.get("h", 0), entry.get("mass", 0))
    return ""


def main():
    try:
        cmap = json.loads(read(MAP_PATH))
    except Exception as e:
        print("FAIL: cannot parse %s: %s" % (MAP_PATH, e))
        return 1

    src = read(BUILDER)
    land_types = match_arms(src, "_build_landmarks")
    vig_types = match_arms(src, "_build_vignettes")

    land_map = cmap.get("landmarks", {})
    vig_map = cmap.get("vignettes", {})
    scatter = cmap.get("scatter", {})

    missing = []
    rows = []

    def add(section, emitted, table):
        for t in emitted:
            if t in table:
                e = table[t]
                rows.append((section, t, e.get("kind", "none"), fmt_shape(e)))
            else:
                rows.append((section, t, "MISSING", "!! no collision_map entry"))
                missing.append("%s:%s" % (section, t))

    add("landmark", land_types, land_map)
    add("vignette", vig_types, vig_map)
    for k, e in scatter.items():
        rows.append(("scatter", k, e.get("kind", "none"), fmt_shape(e)))

    # ---- print table -------------------------------------------------------
    kinds = {}
    for _, _, k, _s in rows:
        kinds[k] = kinds.get(k, 0) + 1

    print("=" * 74)
    print("BLUEPRINT_99 PROP-COLLISION AUDIT  (footprint per prop class)")
    print("  map:     data/collision_map.json")
    print("  builder: scripts/zone_builder.gd  (%d landmark + %d vignette types)"
          % (len(land_types), len(vig_types)))
    print("=" * 74)
    print("%-9s %-20s %-10s %s" % ("SECTION", "TYPE", "KIND", "FOOTPRINT"))
    print("-" * 74)
    order = {"landmark": 0, "vignette": 1, "scatter": 2}
    for section, t, k, shp in sorted(rows, key=lambda r: (order[r[0]], r[2] == "none", r[1])):
        print("%-9s %-20s %-10s %s" % (section, t, k, shp))
    print("-" * 74)
    print("kind totals: " + ", ".join("%s=%d" % (k, v) for k, v in sorted(kinds.items())))
    print("  (building = solid strip auto-added by _sprite for /buildings/ + log_cabin)")
    print("  (none     = walkable dressing: no collider, unchanged behavior)")

    # ---- coverage verdict --------------------------------------------------
    print("=" * 74)
    if missing:
        print("FAIL: %d builder type(s) missing from collision_map: %s"
              % (len(missing), ", ".join(missing)))
        return 1
    print("PASS: every builder-emitted landmark & vignette type is mapped.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
