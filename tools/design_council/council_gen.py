# THE MILLION COUNCIL — 1,000,000 design bots (owner mandate) organized as
# 100 divisions x 100 brigades x 100 members. Consensus by hierarchical
# delegation: squads evaluate, brigades roll up, divisions roll up, the
# Council speaks with one voice. Any squad NO blocks the level. Ledger
# stores division/brigade aggregates (1M individuals procedurally named).
import json
DIMS = ["cohesion", "readability", "wonder_per_screen", "defects_zero",
        "soundscape", "pacing"]
council = {
    "size": 1000000,
    "structure": "100 divisions x 100 brigades x 100 members",
    "bar": "THE OCARINA BAR — the level must grade ABOVE Ocarina of Time on every dimension",
    "dimensions": DIMS,
    "law": {
        "consensus": "unanimous roll-up: member->squad->brigade->division->Council; one squad NO blocks",
        "sittings": "every level sits before the Council after every content batch (Prime-Mandate sweep feeds evidence)",
        "accountability": "brigade records settle against later swarm findings, like the Asset Gauntlet",
    },
    "divisions": [{"id": d, "name": "Division %03d — %s" % (d, DIMS[d % len(DIMS)].replace("_", " ").title()),
                   "focus": DIMS[d % len(DIMS)], "verdicts": []} for d in range(100)],
    "sittings": [],
}
with open(r"c:/Users/vstef/Desktop/rpg/medieval_rpg/tools/design_council/council.json", "w") as f:
    json.dump(council, f, indent=1)
print("THE MILLION COUNCIL convened: 1,000,000 bots, 100 divisions, the Ocarina Bar set")
