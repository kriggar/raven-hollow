# Harvest instruction pairs from the project's own corpus -> train.jsonl
# (see README.md in this folder for the honest scope of this fine-tune).
import io
import json
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "_downloads", "_studio")
os.makedirs(OUT, exist_ok=True)
samples = []


def add(instr, out):
    samples.append({"instruction": instr.strip(), "output": out.strip()})


# 1. zone defs: each built zone becomes (brief -> landmarks JSON)
defs = io.open(os.path.join(ROOT, "scripts", "zone_defs.gd"), encoding="utf-8").read()
for m in re.finditer(r'\n\t"(\w+)": \{\n\t\t"built": true(.*?)\n\t\},', defs, re.S):
    zid, body = m.group(1), m.group(2)
    name = re.search(r'"name": "([^"]+)"', body)
    biome = re.search(r'"biome": "(\w+)"', body)
    lms = re.findall(r'\{"type": "(\w+)", "pos": Vector2\((\d+), (\d+)\)(?:, "count": (\d+))?', body)
    if not (name and biome and lms):
        continue
    out = json.dumps({"zone_id": zid, "landmarks": [
        {"type": t, "x": int(x), "y": int(y), **({"count": int(c)} if c else {})}
        for t, x, y, c in lms]}, indent=1)
    add("Author the landmark layout for '%s' (%s biome) in Raven Hollow. "
        "Return the JSON layout." % (name.group(1), biome.group(1)), out)

# 2. design docs: each doc section becomes (ask -> section) for style transfer
for doc in ("NARRATIVE_VOICE.md", "QUEST_EXEMPLARS.md", "ITEM_PROGRESSION.md",
            "LOOT_TABLES.md", "CALENDAR_EVENTS.md", "HIDDEN_DEBUFFS.md"):
    p = os.path.join(ROOT, "design", doc)
    if not os.path.exists(p):
        continue
    text = io.open(p, encoding="utf-8", errors="replace").read()
    for sec in re.split(r"\n## ", text)[1:]:
        title = sec.split("\n", 1)[0][:80]
        body = sec.split("\n", 1)[1][:2500] if "\n" in sec else ""
        if len(body) < 200:
            continue
        add("Write the '%s' section of Raven Hollow's %s in the project's house style."
            % (title, doc.replace(".md", "").replace("_", " ").title()), body)

# 3. VO lines: emotion-tagged lines become (character brief -> line)
vo = os.path.join(ROOT, "_downloads", "_vo_v2_tagged.json")
if os.path.exists(vo):
    data = json.load(io.open(vo, encoding="utf-8"))
    items = data.items() if isinstance(data, dict) else enumerate(data)
    for _, entry in items:
        if isinstance(entry, dict) and "speaker" in entry and "text" in entry:
            add("Write one in-character line for %s in Raven Hollow (period-true, "
                "gothic Eastern-European tone)." % entry["speaker"], entry["text"])

path = os.path.join(OUT, "train.jsonl")
with io.open(path, "w", encoding="utf-8") as fh:
    for s in samples:
        fh.write(json.dumps(s) + "\n")
print("dataset: %d samples -> %s" % (len(samples), path))
