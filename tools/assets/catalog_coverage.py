#!/usr/bin/env python3
"""Fill the <!-- AUTO:COVERAGE --> block of design/ASSET_LIBRARY.md with REAL counts from
library.json. No fabricated numbers -- this is the honest tally."""
import json, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.abspath(os.path.join(HERE, "..", "..", "_downloads", "_assetlib", "library.json"))
DOC = os.path.abspath(os.path.join(HERE, "..", "..", "design", "ASSET_LIBRARY.md"))

lib = json.load(open(LIB, encoding="utf-8"))
assets = lib["assets"]
by_cat = collections.Counter(a["category"] for a in assets)
animated = [a for a in assets if a.get("animated")]
inan = [a for a in assets if not a.get("animated")]
replaces = collections.Counter(a["replaces_composite"] for a in assets if a.get("replaces_composite"))

lines = []
lines.append(f"**Total verified sprites in `library.json`: {len(assets)}**  "
             f"({len(inan)} inanimate, {len(animated)} animated creature sheets).\n")
lines.append("| category | verified sprites |")
lines.append("|---|---|")
for c, n in sorted(by_cat.items(), key=lambda t: -t[1]):
    lines.append(f"| {c} | {n} |")
lines.append("")
if replaces:
    lines.append("**ColorRect composites now covered** (generated replacements exist): "
                 + ", ".join(f"`{k}`×{v}" for k, v in sorted(replaces.items())) + ".\n")
if animated:
    lines.append("**Animated creatures** (real Wan-video-derived frames, per-frame verified):")
    for a in animated:
        states = ", ".join(f"{s}:{a['frames_per_state'].get(s,'?')}f" for s in a.get("states", []))
        lines.append(f"- `{a['id']}` — states: {states}")
    lines.append("")

block = "<!-- AUTO:COVERAGE -->\n" + "\n".join(lines) + "<!-- /AUTO:COVERAGE -->"
doc = open(DOC, encoding="utf-8").read()
import re
doc = re.sub(r"<!-- AUTO:COVERAGE -->.*?<!-- /AUTO:COVERAGE -->", block, doc, flags=re.S)
open(DOC, "w", encoding="utf-8").write(doc)
print(f"coverage filled: {len(assets)} assets, {len(by_cat)} categories, {len(animated)} animated")
