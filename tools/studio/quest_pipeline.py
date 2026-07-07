#!/usr/bin/env python3
"""QUEST PRODUCTION SYSTEM (BACKLOG #79) — the reusable pipeline that authored the
1,000-quest wave. Three stages, each a subcommand:

  pools    -> extract the REAL id space (NPCs per zone, creatures per zone, item
              ids, zone ids) that quests must reference, to _quest_pools.json.
  validate -> check a batch of generated quests against those pools + the engine
              schema; REPAIR fixable id refs (swap to a real zone npc/creature/
              item), DROP the unrepairable, write <in>_clean.json.
  merge    -> fold a validated batch into data/quests.json (keyed by id, skips
              collisions), preserving existing quests.

The design principle (the "writers council"): the model writes prose + premises;
CODE guarantees every referenced id exists, so nothing broken reaches the game.
This is how the studio keeps producing quests toward the 2,000 target without a
human re-checking every id by hand.

Usage:
  python tools/studio/quest_pipeline.py pools
  python tools/studio/quest_pipeline.py validate <generated.json>
  python tools/studio/quest_pipeline.py merge <generated_clean.json>
"""
import json, sys, os, re, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "data")
POOLS_PATH = os.path.join(DATA, "_quest_pools.json")
QUESTS_JSON = os.path.join(DATA, "quests.json")

# Zone order (mirrors scripts/zone_defs.gd build order).
ZONES = ["iron_vein","vetka","copper_wells","stonepath","chamber_depths","grey_marches",
    "western_lowlands","angel_wings","famine_fields","riverfork","listening_steppe","threadlands",
    "black_night","gravemark_tundra","bloodstone_pit","whisper_passes","eastern_ridges","blestem",
    "lichenreach","transcub_vale","bloodroad","basaltfang","sangeroasa","the_gift","ashvents",
    "greyhollow","drowned_quarter","canal_maze","grey_piers","salt_fens","dead_timber","ledger_roads",
    "morven_reach","the_archive","anchorfall","finalized_fields","coldharbor_deep","orange_fog","last_hearth"]


def build_pools():
    cast = json.load(open(os.path.join(DATA, "npc_cast.json"), encoding="utf-8"))
    npcs = cast.get("npcs", cast)
    if isinstance(npcs, dict):
        npcs = list(npcs.values())
    npc_by_zone, npc_names = {}, {}
    for n in npcs:
        z = n.get("zone") or n.get("map") or "?"
        nid = n.get("id", "?")
        npc_by_zone.setdefault(z, []).append(nid)
        npc_names[nid] = n.get("name", nid)

    best = json.load(open(os.path.join(DATA, "bestiary.json"), encoding="utf-8"))["creatures"]
    cre_by_zone, cre_names = {}, {}
    for cid, c in best.items():
        cre_names[cid] = c.get("name", cid)
        for z in c.get("zones", []):
            cre_by_zone.setdefault(z, []).append(cid)

    item_ids = set()
    for f in ["loot_tables.json", "crafting.json", "items.json"]:
        p = os.path.join(DATA, f)
        if not os.path.exists(p):
            continue
        for m in re.findall(r'"(?:id|item|material|drop)"\s*:\s*"([a-z_0-9]+)"',
                            json.dumps(json.load(open(p, encoding="utf-8")))):
            item_ids.add(m)

    pools = {"zones": ZONES, "npc_by_zone": npc_by_zone, "npc_names": npc_names,
             "creatures_by_zone": cre_by_zone, "creature_names": cre_names,
             "item_ids": sorted(item_ids)}
    json.dump(pools, open(POOLS_PATH, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"pools -> {POOLS_PATH}: {len(ZONES)} zones, "
          f"{len(npc_names)} npcs, {len(cre_names)} creatures, {len(item_ids)} items")
    return pools


def _load_pools():
    if not os.path.exists(POOLS_PATH):
        return build_pools()
    return json.load(open(POOLS_PATH, encoding="utf-8"))


def validate(path):
    pools = _load_pools()
    npc_by_zone = pools["npc_by_zone"]; cre_by_zone = pools["creatures_by_zone"]
    all_npcs = set(pools["npc_names"]); all_cre = set(pools["creature_names"])
    all_items = set(pools["item_ids"]); zones = set(pools["zones"])

    data = json.load(open(path, encoding="utf-8"))
    quests = data.get("quests", data) if isinstance(data, dict) else data
    kept, dropped, repaired, seen = [], [], 0, set()

    for q in quests:
        zone, qid, problems = q.get("zone", ""), q.get("id", ""), []
        if not qid or qid in seen:
            problems.append("dup/empty id")
        if q.get("giver") not in all_npcs:
            z = npc_by_zone.get(zone, [])
            if z:
                q["giver"] = z[0]; q["giver_name"] = pools["npc_names"].get(z[0], ""); repaired += 1
            else:
                problems.append(f"giver {q.get('giver')} not real")
        for o in q.get("objectives", []):
            k = o.get("kind")
            if k == "kill" and o.get("target") not in all_cre:
                z = cre_by_zone.get(zone, [])
                if z: o["target"] = z[0]; repaired += 1
                else: problems.append("kill target not real")
            if k == "collect" and o.get("item") not in all_items:
                if all_items: o["item"] = sorted(all_items)[0]; repaired += 1
                else: problems.append("collect item not real")
            if k == "talk" and o.get("npc") not in all_npcs:
                z = npc_by_zone.get(zone, [])
                if z: o["npc"] = z[0]; repaired += 1
                else: problems.append("talk npc not real")
            if k == "reach":
                if o.get("map") not in zones:
                    o["map"] = zone if zone in zones else sorted(zones)[0]; repaired += 1
                if not isinstance(o.get("pos"), list) or len(o.get("pos", [])) != 2:
                    o["pos"] = [900, 900]; repaired += 1
                o.setdefault("radius", 90)
        r = q.get("rewards", {})
        if isinstance(r.get("items"), list):
            r["items"] = [it for it in r["items"] if it in all_items]
        if problems:
            dropped.append((qid, problems)); continue
        seen.add(qid); kept.append(q)

    outp = path.replace(".json", "_clean.json")
    json.dump({"quests": kept}, open(outp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"validate: IN {len(quests)} KEPT {len(kept)} DROPPED {len(dropped)} REPAIRS {repaired}")
    for qid, probs in dropped[:15]:
        print(f"  DROP {qid}: {probs}")
    print(f"  -> {outp}")


def merge(path):
    clean = json.load(open(path, encoding="utf-8"))
    new_list = clean.get("quests", clean) if isinstance(clean, dict) else clean
    db = json.load(open(QUESTS_JSON, encoding="utf-8"))
    qmap = db["quests"]
    added, skipped = 0, 0
    for q in new_list:
        qid = q.get("id")
        if not qid or qid in qmap:
            skipped += 1; continue
        entry = {k: v for k, v in q.items() if k != "id"}
        entry.setdefault("giver_name", str(entry.get("giver", "")).replace("_", " ").title())
        qmap[qid] = entry; added += 1
    json.dump(db, open(QUESTS_JSON, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(f"merge: +{added} skipped {skipped} -> TOTAL {len(qmap)}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "pools"
    if cmd == "pools":
        build_pools()
    elif cmd == "validate":
        validate(sys.argv[2])
    elif cmd == "merge":
        merge(sys.argv[2])
    else:
        print(__doc__)
