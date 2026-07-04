# THE ASSET GAUNTLET — 1000-bot military roster (owner mandate).
# All start as Recruits under 1 General. Promotions come from decisions later
# validated by the Prime-Mandate swarm; the General rotates every 3 rounds
# (steps down to rank 1; the highest-ranked bot takes command).
import json, random
rng = random.Random(20260705)
RANKS = ["Recruit", "Lamp-Private", "Lamp-Corporal", "Ward-Sergeant", "Stone-Lieutenant",
         "Vein-Captain", "Marsh-Major", "Gate-Colonel", "Vigil-Commander", "General of the Vigil"]
FIRST = ["Ansel","Borek","Cazma","Dorel","Emeric","Florin","Grigore","Horia","Ilinca","Jder",
         "Kriva","Luca","Mirel","Nandru","Oana","Petru","Radu","Sorina","Tudor","Ursu",
         "Vasilca","Zamfir","Anca","Bogdan","Codrin","Doina","Estera","Fane","Gavril","Hana"]
LAST = ["of the Border","Wellwatcher","Stonewary","Ledgerhand","Rookfriend","the Incurious",
        "Ashwalker","Thredsworn","Copperwise","Lampbearer","of Vetka","of the Marches",
        "Bogstrider","Kerbreader","Fogborn","the Unlistening","Veinguard","Greyhand",
        "of the Vigil","Nightcounter"]
bots = []
for i in range(1000):
    name = f"{rng.choice(FIRST)} {rng.choice(LAST)} #{i:04d}"
    bots.append({"id": i, "name": name, "rank": 0, "reviews": 0, "approvals": 0,
                 "rejections": 0, "validated_good": 0, "validated_bad": 0})
bots[0]["rank"] = 9
bots[0]["name"] = "General Vasilca of the Vigil #0000"
ledger = {"round": 0, "general_id": 0, "general_rounds_served": 0, "ranks": RANKS,
          "rules": {
              "unanimity": "every reviewing bot in the chain must approve; one rejection quarantines the pack",
              "final_sign": "only the top-ranked commanding officer grants PASS",
              "promotion": "+1 rank when a bot's approval is later validated clean by the Prime-Mandate swarm (or a rejection is validated correct); -1 rank when validated wrong",
              "rotation": "after 3 review rounds the General steps down to rank 1 (Lamp-Private); the highest-ranked bot takes command",
          },
          "bots": bots, "reviews": []}
with open(r"c:/Users/vstef/Desktop/rpg/medieval_rpg/tools/asset_gauntlet/roster.json", "w") as f:
    json.dump(ledger, f, indent=1)
print("roster: 1000 bots enlisted; General Vasilca commands (rotation every 3 rounds)")
