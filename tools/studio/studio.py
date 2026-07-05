# Raven Hollow LOCAL STUDIO worker (BACKLOG #95/#96).
# Narrow-role production on a local Ollama model, held to the bar by
# validators + retry, primed by the repo's own style bibles and exemplars.
# Free per token. Fable reviews the output; it does not write it.
#
#   python tools/studio/studio.py <role> "<task>" [-o out.json]
#   python tools/studio/studio.py --batch tasks.jsonl [-o outdir]
#
# Requires: Ollama serving at localhost:11434 (see README.md).
import argparse
import io
import json
import os
import re
import sys
import urllib.request

OLLAMA = os.environ.get("STUDIO_OLLAMA", "http://localhost:11434")
MODEL = os.environ.get("STUDIO_MODEL", "qwen2.5-coder:14b")
# Prose roles ride the strongest local writer; code/data roles ride the coder.
MODEL_PROSE = os.environ.get("STUDIO_MODEL_PROSE", "qwen3:14b")
ROLE_MODEL = {"quest_writer": MODEL_PROSE, "bark_writer": MODEL_PROSE,
              "item_smith": MODEL_PROSE, "def_author": MODEL, "qa_triage": MODEL}

RUBRIC = (
    "QUALITY RUBRIC (the house bar): 1) CANON-GROUNDED - names, places, dread "
    "specific to Raven Hollow, never generic fantasy filler. 2) CONCRETE - "
    "objects, numbers, places; no vague mysticism ('secrets', 'destiny', "
    "'shadows stir'). 3) PERIOD VOICE - medieval Eastern-European cadence, "
    "no modern idiom. 4) SURPRISING-BUT-INEVITABLE - one image or turn the "
    "player will remember. 5) ECONOMY - no wasted words.")
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAX_TRIES = 3

KNOWN_TYPES = {
    "tavern", "cottage", "manor", "shop", "workshop", "hamlet", "stall", "plaza",
    "statue", "fountain", "well", "copper_well", "inscription_stone", "stone_row",
    "dolmen", "camp", "graves", "bones", "pond", "stump", "trunk_hollow",
    "ore_rocks", "rocks", "cabin", "dark_keep", "thread_lines", "spire", "lamp",
    "lichen_glow", "lava_vent", "forge", "pit", "gift_field", "brazier", "cairn",
    "signboard", "chimney_smoke", "barn", "shed", "pier", "boat", "wreck",
    "warehouse", "crane", "cargo", "salt_pan", "drowned_fence", "ledger_tablet",
    "lone_tree",
}
ENEMIES = {"skeleton", "skeleton_rogue", "skeleton_mage", "skeleton_warrior",
           "wolf", "orc_rogue", "orc_shaman", "orc_warrior", "boar"}
ANACHRONISMS = re.compile(
    r"\b(ok(ay)?|guys?|cool|awesome|yeah|hey there|robot|electric|gun|police)\b", re.I)


def _read(rel, limit=6000):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return ""
    return io.open(p, encoding="utf-8", errors="replace").read()[:limit]


# ------------------------------------------------------------------ roles ---
def _sys_quest():
    return (
        "You are a quest writer for 'Raven Hollow', a gothic Eastern-European dark-fantasy "
        "pixel RPG (Witcher heavy-cheerful tone, Tolkien wonder, GoT intrigue without sexuality). "
        "Write ONE quest as pure JSON: {\"id\": snake_case, \"title\", \"zone\", \"giver\", "
        "\"summary\", \"steps\": [{\"objective\", \"detail\"}], \"dialogue\": {\"offer\", "
        "\"progress\", \"complete\"}, \"rewards\": {\"xp\": int, \"gold\": int, \"item\": str|null}}. "
        "3-5 steps. Concrete objectives (kill N / fetch / examine at a place), no fetch-boredom "
        "without a twist. Ground every quest in the zone's canon.\n\nSTYLE BIBLE (registers):\n"
        + _read("design/NARRATIVE_VOICE.md", 3500)
        + "\n\nEXEMPLARS (imitate structure and voice):\n"
        + _read("design/QUEST_EXEMPLARS.md", 4500))


def _sys_bark():
    return (
        "You write one-line NPC street barks for 'Raven Hollow' (medieval gothic Romanian vibe; "
        "vendors, guards, children, drunks). Return pure JSON: {\"barks\": [{\"speaker_kind\", "
        "\"line\", \"mood\"}]}. Max 12 words per line. Period-true language, no modern words. "
        "Mix mundane life with the world's quiet dread (the stone, the fog, the threads).\n\nTONE:\n"
        + _read("design/NARRATIVE_VOICE.md", 2500))


def _sys_def():
    return (
        "You author landmark layouts for zones in 'Raven Hollow'. Return pure JSON: "
        "{\"zone_id\", \"landmarks\": [{\"type\", \"x\": int, \"y\": int, \"count\": int?}], "
        "\"vignettes\": [{\"kind\", \"x\", \"y\", \"concept\"}]}. "
        "Allowed types: " + ", ".join(sorted(KNOWN_TYPES)) + ". "
        "Allowed vignette kinds: standing_farmer, cold_camp, boot_prints, empty_stall, "
        "full_granary, chalk_handprints, rows_of_twelve, childs_shoe, burned_farmstead, "
        "courier_seal. Coordinates in world px, keep 700px from the stated zone bounds, "
        "cluster things that tell one story. EXEMPLAR (mirror the density and storytelling):\n"
        + _read("scripts/zone_defs.gd", 5000))


def _sys_item():
    return (
        "You design items for 'Raven Hollow' (WoW-style progression, D2 dark-gold artifacts). "
        "Return pure JSON: {\"items\": [{\"id\", \"name\", \"slot\", \"ilvl\": int, \"rarity\", "
        "\"stats\": {}, \"flavor\"}]}. Budget law: total stat points = (2.4 + 0.62*ilvl) * "
        "slot_mult * rarity_mult (slot_mult: weapon 1.0, chest 0.9, other 0.65; rarity_mult: "
        "common 0.7, uncommon 0.85, rare 1.0, epic 1.15, artifact 1.3). Flavor lines are one "
        "sentence, concrete, canon-grounded.\n\nCANON REFERENCE:\n"
        + _read("design/ITEM_PROGRESSION.md", 3000))


def _sys_triage():
    return (
        "You are QA triage for 'Raven Hollow'. Given inspection findings JSON, group them by "
        "root cause, rank by severity x frequency, and return pure JSON: {\"groups\": "
        "[{\"root_cause\", \"count\", \"severity\", \"zones\": [], \"suggested_fix\"}]}. "
        "Be mechanical and specific; do not invent findings.")


ROLES = {
    "quest_writer": _sys_quest,
    "bark_writer": _sys_bark,
    "def_author": _sys_def,
    "item_smith": _sys_item,
    "qa_triage": _sys_triage,
}


# ------------------------------------------------------------- validators ---
def _extract_json(text):
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        raise ValueError("no JSON object in reply")
    return json.loads(m.group(0))


def validate(role, obj):
    if role == "quest_writer":
        for k in ("id", "title", "zone", "giver", "steps", "dialogue", "rewards"):
            if k not in obj:
                raise ValueError("missing key: " + k)
        if not (3 <= len(obj["steps"]) <= 6):
            raise ValueError("need 3-5 steps")
        blob = json.dumps(obj)
        if ANACHRONISMS.search(blob):
            raise ValueError("anachronistic language: " + ANACHRONISMS.search(blob).group(0))
    elif role == "bark_writer":
        for b in obj.get("barks", []):
            if len(b.get("line", "").split()) > 14:
                raise ValueError("bark too long: " + b["line"])
            if ANACHRONISMS.search(b.get("line", "")):
                raise ValueError("anachronism: " + b["line"])
        if not obj.get("barks"):
            raise ValueError("no barks")
    elif role == "def_author":
        for lm in obj.get("landmarks", []):
            if lm.get("type") not in KNOWN_TYPES:
                raise ValueError("unknown landmark type: %s" % lm.get("type"))
            if not (isinstance(lm.get("x"), int) and isinstance(lm.get("y"), int)):
                raise ValueError("non-integer coords")
        if len(obj.get("landmarks", [])) < 8:
            raise ValueError("too sparse: give 8+ landmarks (Witchbrook bar)")
    elif role == "item_smith":
        for it in obj.get("items", []):
            for k in ("id", "name", "slot", "ilvl", "rarity", "stats", "flavor"):
                if k not in it:
                    raise ValueError("item missing " + k)
    return obj


# ------------------------------------------------------------------ model ---
def ask(system, user, temperature=0.5, model=None):
    req = urllib.request.Request(
        OLLAMA + "/api/chat",
        data=json.dumps({
            "model": model or MODEL, "stream": False,
            "options": {"temperature": temperature, "num_ctx": 8192},
            "messages": [{"role": "system", "content": system},
                         {"role": "user", "content": user}],
        }).encode("utf-8"),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())["message"]["content"]


def run_task(role, task):
    system = ROLES[role]()
    model = ROLE_MODEL.get(role, MODEL)
    err = ""
    obj = None
    for attempt in range(MAX_TRIES):
        user = task if not err else (
            task + "\n\nYour previous answer FAILED validation: %s\n"
            "Return corrected pure JSON only." % err)
        try:
            obj = validate(role, _extract_json(ask(system, user, model=model)))
            break
        except Exception as exc:  # noqa: BLE001 - feed anything back to the model
            err = str(exc)
            if "404" in err and model != MODEL:
                model = MODEL  # requested model not pulled yet - fall back
                err = ""
    if obj is None:
        raise SystemExit("FAILED after %d tries: %s" % (MAX_TRIES, err))
    # CRITIQUE-AND-REVISE (the house-bar pass): the model attacks its own
    # draft against the rubric, then rewrites. The revision ships only if
    # it still validates; otherwise the original draft stands.
    try:
        crit = ask(system,
                   task + "\n\nHere is a draft:\n" + json.dumps(obj) +
                   "\n\n" + RUBRIC +
                   "\nList the draft's 3 worst failures against the rubric, "
                   "then return the IMPROVED version as pure JSON only.",
                   temperature=0.6, model=model)
        obj2 = validate(role, _extract_json(crit))
        return obj2, MAX_TRIES + 1
    except Exception:  # noqa: BLE001 - revision failed, original stands
        return obj, MAX_TRIES


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("role", nargs="?", choices=sorted(ROLES))
    ap.add_argument("task", nargs="?")
    ap.add_argument("--batch", help="JSONL of {role, task}")
    ap.add_argument("-o", "--out", default="")
    args = ap.parse_args()
    if args.batch:
        outdir = args.out or "_downloads/_studio"
        os.makedirs(os.path.join(ROOT, outdir), exist_ok=True)
        for i, line in enumerate(io.open(args.batch, encoding="utf-8")):
            if not line.strip():
                continue
            spec = json.loads(line)
            obj, tries = run_task(spec["role"], spec["task"])
            p = os.path.join(ROOT, outdir, "%s_%03d.json" % (spec["role"], i))
            io.open(p, "w", encoding="utf-8").write(json.dumps(obj, indent=1))
            print("OK[%d try%s] %s" % (tries, "" if tries == 1 else "s", p))
        return
    if not (args.role and args.task):
        ap.error("role + task required (or --batch)")
    obj, tries = run_task(args.role, args.task)
    text = json.dumps(obj, indent=1)
    if args.out:
        io.open(args.out, "w", encoding="utf-8").write(text)
        print("OK[%d tries] -> %s" % (tries, args.out))
    else:
        print(text)


if __name__ == "__main__":
    main()
