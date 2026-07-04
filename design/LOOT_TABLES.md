# RAVEN HOLLOW — LOOT TABLES (WoW-Classic Spirit, Draconia Canon)
Design deliverable for the item-progression pillar. Companion docs: `WORLD_PLAN.md` (zones,
creature families), `scripts/items.gd` (item dict shape, rarity colors), `scripts/crafting.gd`
(materials, current `DROP_TABLES`), `scripts/xp_system.gd` (brackets/pacing), `scripts/enemy.gd`
(`_grant_kill_rewards()` — the hook this replaces).

OWNER MANDATES honored here:
1. **WoW-spirit progression** — five rarity tiers, meaningful upgrades, SLOW acquisition
   (rares are events, epics are stories you tell).
2. **Loot window, not auto-pickup** — a corpse holds a rolled loot list; the player opens it
   and SEES rarity-colored names, clicks to take. Tables below are written for that pipeline.
3. **Every fight is a fight** — per-kill loot value is budgeted against a 8–20 s time-to-kill
   for trash, so a "worthless" kill never happens: at minimum the corpse pays vendor-junk,
   materials, or gold consistent with the effort.

---

## 1. Pipeline: current state → target state

**Today** (`enemy.gd:476` `_grant_kill_rewards`): on `_die()`, XP is granted, then
`Crafting.drop_for_kill(inv, type_name)` **silently auto-grants** materials from
`Crafting.DROP_TABLES` (crafting.gd:340 — wolf/boar/skeleton/orc/bear only) and toasts them.
No gold, no gear drops, no loot window, corpse fades in ~1 s.

**Target**:

```
enemy._die()
  └─ var loot: Dictionary = LootTables.roll_for(type_name, display_name, zone_id)
       # rolled ONCE at death, stored on the corpse — deterministic thereafter
  └─ corpse persists as a lootable (sparkle glint while loot remains; the existing
     smoke-poof + fade runs only after the window is emptied/closed, or 60 s timeout)
  └─ player right-clicks corpse in range → LootWindowUI.open(loot)
       # rows: coin row first, then items sorted rarity desc, names tinted via
       # Items.rarity_color(); click row = take (BoP rows confirm first);
       # "Take All" button; window follows WoW rules (one looter — it's single-player,
       # so simply: the killer loots)
```

`Crafting.drop_for_kill` is **retired** from the kill path (kept for quest-scripted grants).
Its material tables are absorbed into the family tables below — same ids, same generosity
for crafting mats, so existing recipes (crafting.gd:285 `RECIPES`) keep working unchanged.

Everything a loot row hands to `Inventory.add_item()` uses the **exact items.gd dict shape**
(`{id, name, slot, rarity, icon, stats, flavor, stackable, effect}`, materials additionally
`type`/`count`), plus one new optional key: `bind` (see §7). `Inventory` ignores unknown keys,
so `bind` is non-breaking.

---

## 2. Rarity pacing (the WoW-Classic feel, in numbers)

Per **trash kill** in an at-level zone (gear roll only — junk/materials/gold are separate,
see schema):

| Rarity | Share of gear rolls | Effective per-kill chance | Expected kills per drop | Feel |
|---|---|---|---|---|
| common (grey-white gear) | 79% | ~7.1% | ~14 | routine, vendor fodder + fill slots |
| uncommon (green) | 18% | ~1.6% | ~62 | a good session has 1–3 |
| rare (blue) | 2.8% | ~0.25% | ~400 | an EVENT — screenshot moment |
| epic (purple) | 0.2% | ~0.018% | ~5,500 | world-epic legend; most players see one per character |
| legendary (orange) | 0% from trash | — | — | **never drops**: quest-line earned only (matches items.gd — the 5 legendaries are quest rewards) |

- Base **gear_chance ≈ 9%** on trash (tuned per family below; elites 18%, rare spawns 100%,
  bosses use guaranteed slots).
- Killing **grey-level mobs** (≥6 levels below player) halves gear_chance and zeroes the
  rare+ shares — no farming level-1 wolves for blues.
- Rarity means a real stat-budget step (items.gd examples already follow this):
  common ≈ 1.0× budget for its level, uncommon ≈ 1.35×, rare ≈ 1.8× + a secondary stat
  (crit/speed/mana), epic ≈ 2.3× + two secondaries, legendary = hand-authored + `effect`.

---

## 3. Level brackets ↔ zones (cap 60)

Loot tables are keyed `family/bracket`. Bracket = the ZONE's bracket (creature level lives in
the zone's `creature_table`; loot follows the zone, so a Grey Marches greywolf and a
Basaltfang obsidian wolf share a family but not a table).

| Bracket | Levels | Zones (WORLD_PLAN numbering) |
|---|---|---|
| **b1** | 1–6 | Raven Hollow (1), Vetka (2) |
| **b2** | 5–12 | Iron Vein (3), Copper Wells (4), Chamber Depths (5, dungeon 10–12), Stonepath (6) |
| **b3** | 10–20 | Grey Marches (9), Western Lowlands (8), Angel Wings outskirts (7), Famine Fields (10), Riverfork (11) |
| **b4** | 18–28 | Listening Steppe (14), Threadlands (13), Black Night (12), Gravemark Tundra (15) |
| **b5** | 26–36 | Whisper Passes (21), Eastern Ridges (18), Blestem (17), Lichenreach (19), Transcub Vale (20) |
| **b6** | 34–44 | Bloodroad (26), Basaltfang (25), Sangeroasa (22), The Gift (23), Ashvents (24) |
| **b7** | 45–54 | Grey Piers (30), Greyhollow (27), Drowned Quarter (28), Canal Maze (29), Salt Fens (31), Dead Timber (32), Ledger Roads (33), Morven Reach (34) |
| **b8** | 55–60 | The Archive (35), Anchorfall (36), Finalized Fields (37), Coldharbor Deep (38, dungeon), Orange Fog (39), Bloodstone Pit (16, endgame dungeon) |

(Last Hearth (40) has no hostiles — no tables. Demo cap is 10 today (`XPSystem.MAX_LEVEL`);
b1–b2 tables are shippable now, the rest are authored ahead.)

---

## 4. Exact data schema (GDScript)

New static class `scripts/loot_tables.gd`, mirroring the items.gd/class_defs.gd pattern
(pure data + tiny helpers, no scene code):

```gdscript
class_name LootTables
## Static loot database. Keyed "family/bracket" (e.g. "wolf/b1").
## Rolled ONCE per corpse by roll_for(); result is stored on the corpse and
## consumed by LootWindowUI. All item ids resolve through item_lookup(): a
## chain of Items._DB -> Crafting.MATERIALS/CONSUMABLES/RECIPE_SCROLLS/
## CRAFTED_GEAR -> LootTables.JUNK -> LootTables.GEAR (new world-drop gear db).

## Table row semantics — every key optional except where noted:
##   gold:      {chance: float, min: int, max: int} or null (beasts carry no coin)
##   always:    [ {id, min, max} ]          # 100% rows (crafting-mat floor, boss mats)
##   junk:      [ {id, chance, min, max} ]  # grey vendor trash (type "junk", has "sell")
##   materials: [ {id, chance, min, max} ]  # crafting mats (Crafting.MATERIALS + §6 ids)
##   gear_chance: float                     # one gear roll per corpse (0.09 trash baseline)
##   gear_rarity: {common: w, uncommon: w, rare: w, epic: w}   # weights, sum ~100
##   gear_pool: String                      # GEAR_POOLS key, e.g. "world_b2"
##   special:   [ {id, chance} ]            # recipes, rare cosmetics, quest-starting items
##   guaranteed: [ [ {id, weight}, ... ] ]  # BOSSES ONLY: each inner array = one
##                                          # guaranteed slot, weighted pick of candidates
##   rarity_floor: String                   # BOSSES ONLY: min rarity of slot-1 pick

const TABLES := {
	"wolf/b1": { ... },        # §8 exemplars
	# ... one entry per family x bracket that actually spawns (sparse, ~60 tables at ship)
}

## Family resolution: supersedes Crafting._drop_family. Longest-prefix match on
## the enemy's type_name (engine sprite type), then display_name overrides for
## re-skinned sprites (zone_defs re-uses skeleton_mage for "Entranced Pilgrim"
## and "The Hungering" — loot must follow the FICTION, not the sprite).
const FAMILY_BY_TYPE := {
	"wolf": "wolf", "boar": "boar", "bear": "bear",
	"skeleton": "skeleton", "orc": "bandit", "bat": "bat",
	"strigoi": "strigoi", "varcolac": "varcolac", "shell": "thread_shell",
	"finalized": "finalized", "wraith": "wraith", "canal": "canal_thing",
}
const FAMILY_BY_NAME := {   # display_name contains-match, checked FIRST
	"entranced": "possessed", "hungering": "possessed", "pilgrim": "possessed",
	"thread-touched": "thread_shell", "cult": "cultist", "zealot": "cultist",
	"bandit": "bandit", "smuggler": "bandit", "cutpurse": "bandit",
	"deserter": "bandit", "enforcer": "bandit", "starving dog": "wolf",
}

## Gear pools: authored id lists per bracket, split by rarity. Ids live in the
## GEAR db below (same items.gd dict shape + "bind"). Pool pick: roll rarity
## from gear_rarity weights, then uniform pick within that rarity's list.
const GEAR_POOLS := {
	"world_b1": {
		"common":   ["cracked_buckler", "mudstained_hood", "splitleather_gloves",
		             "bent_iron_knife", "threadbare_cloak_chest", "marsh_waders"],
		"uncommon": ["bogiron_shortblade", "hollowbark_targe", "poachers_cap",
		             "ratskin_leggings"],
		"rare":     ["ferrymans_hook", "vetka_wardens_jack"],
		"epic":     ["the_bent_oars_luck"],       # trinket; world-epic, BoE
	},
	"world_b2": { ... },   # bog-iron weapon tier, first mana gear
	# ... "world_b3" .. "world_b8"
}

static func roll_for(type_name: String, display_name: String, zone_id: String) -> Dictionary:
	## -> {"gold": int, "items": Array[Dictionary]}  (items = full item dicts,
	## stackables carry "count"). Applies grey-level nerf via the player's level
	## vs ZoneDefs bracket. Rare-spawn display_names route to RARE_SPAWNS (§9),
	## boss type_names to BOSS_TABLES (§10) before the family tables.
```

**Roll procedure** (one pass, all rows independent — WoW trash behavior):
1. resolve family (name-match first, then type prefix) + bracket from `zone_id`;
2. `gold`: roll chance, then `randi_range(min, max)`;
3. `always` rows granted; `junk`/`materials`/`special` rows each rolled independently;
4. ONE `gear_chance` roll → rarity from weights → uniform pick in pool;
5. cap visible rows at 6 (gold + 5 items; overflow discards lowest rarity first —
   in practice unreachable on trash).

---

## 5. Gold economy

Single integer currency (player.gd:178 `var gold: int`, already saved by SaveSystem).
Displayed as "coins". WoW rule adopted: **beasts carry no coin** (they carry hides/meat);
**humanoids carry full coin**; **undead/shells carry old coin** at reduced chance
("the dead were people; some were buried with their purses").

| Bracket | Humanoid (90% chance) | Undead/shell (45%) | Beast |
|---|---|---|---|
| b1 | 1–3 | 1–2 | — |
| b2 | 2–6 | 1–4 | — |
| b3 | 4–10 | 2–7 | — |
| b4 | 7–16 | 4–11 | — |
| b5 | 12–24 | 7–16 | — |
| b6 | 18–36 | 10–24 | — |
| b7 | 28–55 | 16–36 | — |
| b8 | 40–80 | 24–52 | — |

Sinks (to keep coin meaningful, WoW-Classic style): waystation fares (WORLD_PLAN travel
system — "small coin cost per hop"), vendor recipes, repair costs (future durability),
Grey Ferry fare (a deliberately steep era-crossing toll), and b6+ crafting catalysts sold
by faction vendors. Target: a trash-grind hour at level nets ~40× the bracket's single-kill
average, and one zone's coach fares + consumables should consume roughly a third of it.

---

## 6. Zone-themed materials (feeding future crafting)

All use the Crafting.MATERIALS dict shape (`type: "material"`, stackable, count). Existing
five (wolf_pelt, boar_hide, bone, ember_dust, iron_scrap) stay b1–b2 staples. New ids by
region — these are the *crafting spine* for post-demo profession recipes:

| Region (brackets) | Material ids | Lore hook |
|---|---|---|
| Border (b1–b2) | `bog_iron_lump` — "River-fed iron, the color of old blood."; `marsh_lichen`; `raven_feather`; `copper_scale` (flakes off poisoned-well stone) | the Iron Vein's metallic river; copper wells |
| West (b3) | `linen_scrap`; `grain_sack_seal` (stamped, from a granary that never opened); `river_pearl`; `cult_wax` (candle-stub of the hungering rites) | famine amid full granaries |
| North (b4) | `thread_filament` — "Blue. It is still faintly warm."; `cold_iron_shard`; `kerbstone_chip` (Underlanguage-carved); `snowwolf_undercoat` | visible Thread; Great-War graves |
| East (b5) | `luminous_lichen` — Strigoi export, glows faintly in the bag; `blackvein_ore`; `bat_membrane`; `riddle_ink` (Lower Market information-currency) | Lichenreach caverns; Blestem markets |
| South (b6) | `blackglass_shard` — knapped obsidian off Basaltfang; `gift_grain` — "Red at the root. Do not ask the soil why."; `slag_iron`; `ashvent_salt` | the Gift's dead-fed fields; forge-city slag |
| Continent 2 (b7–b8) | `debt_tablet_fragment` — "A name, half a sum, no receipt."; `grey_timber`; `salt_rot_plank`; `ledger_ink`; `anchor_lead` (Anchorfall foundry stock) | the Debt System; drowned economy |

Rule of thumb per table: the zone's signature material sits at 25–45% on the zone's
signature family, so ~1 stack (10) per focused hour — crafting an at-bracket uncommon
should cost about an evening of that zone.

---

## 7. Bind rules

New optional item key `bind: ""|"equip"|"pickup"` (absent = ""):

| Source | Bind |
|---|---|
| junk, materials, consumables, recipes, gold | never bind |
| world gear common/uncommon | none — free trade/mule economy |
| world gear rare/epic (pool drops) | `"equip"` (BoE — the classic "sell it or wear it" decision) |
| boss `guaranteed` slots | `"pickup"` (BoP) |
| rare-spawn signature drops | `"pickup"` except where marked BoE in §9 |
| quest rewards / legendaries | `"pickup"` (already de-facto: quest-granted) |

Integration: `item_tooltip.gd` adds a "Binds when equipped/picked up" line;
LootWindowUI shows a confirm dialog before taking a BoP row; `Inventory.equip_from_bag`
stamps `bind:"equip"` items to `bind:"pickup"` on first equip. (Single-player today, so
bind is forward-armor for trading/multiplayer and mule-proofing — cheap to carry now,
painful to retrofit.)

---

## 8. THE 12 EXEMPLAR TABLES (ship-ready GDScript)

Junk ids referenced here live in a new `LootTables.JUNK` db — items.gd shape with
`type:"junk"`, `sell:<coins>`, grey name, flavor mandatory (junk is a lore channel).

```gdscript
const TABLES := {
	# ---- 1. WOLF / b1 — Raven Hollow wilds, Vetka fringes -------------------
	"wolf/b1": {
		"gold": null,
		"junk": [
			{"id": "cracked_wolf_tooth", "chance": 0.30, "min": 1, "max": 2},  # sell 1
			{"id": "matted_grey_fur",    "chance": 0.25, "min": 1, "max": 1},  # sell 1
		],
		"materials": [
			{"id": "wolf_pelt",   "chance": 0.55, "min": 1, "max": 1},
			{"id": "lean_haunch", "chance": 0.30, "min": 1, "max": 1},  # cooking mat
		],
		"gear_chance": 0.08,
		"gear_rarity": {"common": 80.0, "uncommon": 17.5, "rare": 2.3, "epic": 0.2},
		"gear_pool": "world_b1",
		"special": [{"id": "recipe_hunters_stew", "chance": 0.02}],
	},

	# ---- 2. BOAR / b1 — Raven Hollow, Vetka ---------------------------------
	"boar/b1": {
		"gold": null,
		"junk": [
			{"id": "broken_tusk",  "chance": 0.35, "min": 1, "max": 2},   # sell 1
			{"id": "mud_caked_bristles", "chance": 0.20, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "boar_hide",    "chance": 0.55, "min": 1, "max": 1},
			{"id": "fatty_haunch", "chance": 0.35, "min": 1, "max": 1},
		],
		"gear_chance": 0.07,   # boars root up lost things, rarely wearables
		"gear_rarity": {"common": 82.0, "uncommon": 16.0, "rare": 1.9, "epic": 0.1},
		"gear_pool": "world_b1",
	},

	# ---- 3. SKELETON / b2 — Thread-Touched Dead (Iron Vein, Copper Wells) ---
	"skeleton/b2": {
		"gold": {"chance": 0.45, "min": 1, "max": 4},   # buried with their purses
		"junk": [
			{"id": "grave_soil_clod",  "chance": 0.30, "min": 1, "max": 1},
			{"id": "rotted_burial_shroud", "chance": 0.22, "min": 1, "max": 1},  # sell 2
		],
		"materials": [
			{"id": "bone",          "chance": 0.65, "min": 1, "max": 2},
			{"id": "ember_dust",    "chance": 0.35, "min": 1, "max": 1},
			{"id": "bog_iron_lump", "chance": 0.25, "min": 1, "max": 1},  # rusted grave goods
		],
		"gear_chance": 0.10,   # the dead were buried wearing things
		"gear_rarity": {"common": 78.0, "uncommon": 18.5, "rare": 3.2, "epic": 0.3},
		"gear_pool": "world_b2",
	},

	# ---- 4. BANDIT / b3 — Lowlands bandits, Riverfork smugglers, deserters --
	"bandit/b3": {
		"gold": {"chance": 0.90, "min": 4, "max": 10},
		"junk": [
			{"id": "marked_playing_bones", "chance": 0.25, "min": 1, "max": 1},  # sell 3
			{"id": "toll_receipt_forged",  "chance": 0.20, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "iron_scrap",  "chance": 0.40, "min": 1, "max": 2},
			{"id": "linen_scrap", "chance": 0.35, "min": 1, "max": 2},
		],
		"gear_chance": 0.12,   # humanoids in gear DROP gear — WoW rule
		"gear_rarity": {"common": 76.0, "uncommon": 20.0, "rare": 3.6, "epic": 0.4},
		"gear_pool": "world_b3",
		"special": [{"id": "sealed_smugglers_manifest", "chance": 0.03}],  # quest-starter
	},

	# ---- 5. CULTIST / b3 — Cult Zealots (Grey Marches, Famine Fields) -------
	"cultist/b3": {
		"gold": {"chance": 0.80, "min": 3, "max": 8},   # tithed most of it away
		"junk": [
			{"id": "guttered_candle_stub", "chance": 0.35, "min": 1, "max": 2},
			{"id": "knotted_fasting_cord", "chance": 0.25, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "cult_wax",   "chance": 0.40, "min": 1, "max": 1},
			{"id": "ember_dust", "chance": 0.30, "min": 1, "max": 1},
		],
		"gear_chance": 0.11,
		"gear_rarity": {"common": 74.0, "uncommon": 21.0, "rare": 4.4, "epic": 0.6},
		"gear_pool": "world_b3",
		"special": [
			{"id": "recipe_ashen_poultice", "chance": 0.04},
			{"id": "hunger_psalm_page",     "chance": 0.05},  # collectible lore set
		],
	},

	# ---- 6. POSSESSED / b2 — Entranced Pilgrims, the Hungering --------------
	# Design intent: they were NEIGHBORS. Loot is deliberately poor and sad —
	# household junk, keepsakes, almost no coin, never weapons. Killing them
	# should feel like robbing the dead. That discomfort is canon.
	"possessed/b2": {
		"gold": {"chance": 0.25, "min": 1, "max": 3},
		"junk": [
			{"id": "flat_grey_bread",      "chance": 0.40, "min": 1, "max": 1},  # sell 1
			{"id": "childs_carved_toy",    "chance": 0.15, "min": 1, "max": 1},  # sell 1; it hurts
			{"id": "house_key_unlabeled",  "chance": 0.20, "min": 1, "max": 1},
		],
		"materials": [{"id": "copper_scale", "chance": 0.30, "min": 1, "max": 1}],
		"gear_chance": 0.04,   # commons/greens only — clothes, not arms
		"gear_rarity": {"common": 88.0, "uncommon": 12.0, "rare": 0.0, "epic": 0.0},
		"gear_pool": "world_b2_cloth",
		"special": [{"id": "pilgrims_last_letter", "chance": 0.06}],  # quest chain vector
	},

	# ---- 7. THREAD_SHELL / b4 — Threadlands, Gravemark Tundra ---------------
	"thread_shell/b4": {
		"gold": {"chance": 0.45, "min": 4, "max": 11},
		"junk": [
			{"id": "frost_seized_buckle", "chance": 0.30, "min": 1, "max": 1},
			{"id": "blue_stained_wrappings", "chance": 0.25, "min": 1, "max": 2},
		],
		"materials": [
			{"id": "thread_filament",   "chance": 0.40, "min": 1, "max": 2},  # zone signature
			{"id": "cold_iron_shard",   "chance": 0.30, "min": 1, "max": 1},
			{"id": "bone",              "chance": 0.45, "min": 1, "max": 2},
		],
		"gear_chance": 0.10,
		"gear_rarity": {"common": 77.0, "uncommon": 19.0, "rare": 3.6, "epic": 0.4},
		"gear_pool": "world_b4",
	},

	# ---- 8. STRIGOI / b5 — Blestem patrols, cave-strigoi, assassins ---------
	"strigoi/b5": {
		"gold": {"chance": 0.90, "min": 12, "max": 24},   # information is currency; so is coin
		"junk": [
			{"id": "emptied_vial_red_residue", "chance": 0.30, "min": 1, "max": 1},
			{"id": "lamp_oil_flask_dented",    "chance": 0.25, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "luminous_lichen", "chance": 0.35, "min": 1, "max": 2},
			{"id": "blackvein_ore",   "chance": 0.28, "min": 1, "max": 1},
			{"id": "riddle_ink",      "chance": 0.20, "min": 1, "max": 1},
		],
		"gear_chance": 0.13,   # elite-leaning family: fewer, harder, better-paid fights
		"gear_rarity": {"common": 72.0, "uncommon": 22.0, "rare": 5.2, "epic": 0.8},
		"gear_pool": "world_b5",
		"special": [{"id": "sealed_market_secret", "chance": 0.02}],  # tradeable lore-currency
	},

	# ---- 9. VARCOLAC / b6 — Basaltfang hunters, pit-bosses, convoys ---------
	"varcolac/b6": {
		"gold": {"chance": 0.90, "min": 18, "max": 36},
		"junk": [
			{"id": "snapped_debt_ledger_line", "chance": 0.30, "min": 1, "max": 1},
			{"id": "singed_pack_harness",      "chance": 0.25, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "blackglass_shard", "chance": 0.38, "min": 1, "max": 2},  # zone signature
			{"id": "slag_iron",        "chance": 0.32, "min": 1, "max": 2},
			{"id": "gift_grain",       "chance": 0.18, "min": 1, "max": 1},  # convoy cargo
		],
		"gear_chance": 0.12,
		"gear_rarity": {"common": 73.0, "uncommon": 21.0, "rare": 5.2, "epic": 0.8},
		"gear_pool": "world_b6",
	},

	# ---- 10. SLAG_WALKER / b6 — Ashvents dead-still-working, forge-thralls --
	"slag_walker/b6": {
		"gold": {"chance": 0.45, "min": 10, "max": 24},   # wages never collected
		"junk": [
			{"id": "fused_coin_lump",   "chance": 0.35, "min": 1, "max": 1},  # sell 8 — melted purse
			{"id": "warped_tool_haft",  "chance": 0.28, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "slag_iron",     "chance": 0.50, "min": 1, "max": 2},
			{"id": "ashvent_salt",  "chance": 0.30, "min": 1, "max": 1},
			{"id": "ember_dust",    "chance": 0.35, "min": 1, "max": 2},
		],
		"gear_chance": 0.09,
		"gear_rarity": {"common": 78.0, "uncommon": 18.0, "rare": 3.6, "epic": 0.4},
		"gear_pool": "world_b6",
	},

	# ---- 11. FINALIZED / b7 — Greyhollow rows, Drowned Quarter surfacing ----
	"finalized/b7": {
		"gold": {"chance": 0.45, "min": 16, "max": 36},   # accounts "settled", pockets not emptied
		"junk": [
			{"id": "stamped_ledger_line", "chance": 0.35, "min": 1, "max": 1},  # stamped/un-stamped/stamped
			{"id": "waterlogged_shoe",    "chance": 0.25, "min": 1, "max": 1},
		],
		"materials": [
			{"id": "debt_tablet_fragment", "chance": 0.40, "min": 1, "max": 2},  # continent signature
			{"id": "grey_timber",          "chance": 0.22, "min": 1, "max": 1},
			{"id": "anchor_lead",          "chance": 0.18, "min": 1, "max": 1},
		],
		"gear_chance": 0.11,
		"gear_rarity": {"common": 74.0, "uncommon": 20.5, "rare": 4.8, "epic": 0.7},
		"gear_pool": "world_b7",
		"special": [{"id": "uncancelled_debt_anchor", "chance": 0.01}],  # BoE trinket, server-legend tier
	},
}

# ---- 12. BOSS EXEMPLAR — THE DIGGING CREATURE (herald boss; Iron Vein night
# spawn b2 / Listening Steppe b4 recurrence). Bosses use BOSS_TABLES: same
# shape + "guaranteed" slots. Slot 1 is the rarity-floored gear slot.
const BOSS_TABLES := {
	"digging_creature/b2": {
		"gold": {"chance": 1.0, "min": 25, "max": 40},
		"always": [
			{"id": "burrower_chitin_plate", "min": 2, "max": 3},   # boss crafting mat
			{"id": "copper_scale",          "min": 2, "max": 4},
		],
		"rarity_floor": "rare",
		"guaranteed": [
			# slot 1 — the drop: one of three curated rares (all bind:"pickup")
			[
				{"id": "carapace_kite_shield", "weight": 34},  # off_hand: armor 5, hp 18
				{"id": "tunnelers_claws",      "weight": 33},  # main_hand: dmg 6, speed 6%
				{"id": "wells_warning_band",   "weight": 33},  # ring: mana 12, hp 8
			],
			# slot 2 — always: the quest/lore token
			[{"id": "underlanguage_etched_talon", "weight": 100}],  # starts "What Digs Below"
		],
		"special": [{"id": "recipe_chitin_jack", "chance": 0.15}],
		"gear_chance": 0.25,   # bonus normal world-roll on top (jackpot feel)
		"gear_rarity": {"common": 0.0, "uncommon": 80.0, "rare": 18.0, "epic": 2.0},
		"gear_pool": "world_b2",
	},
}
```

---

## 9. Rare spawns — first 9 built zones (zone_defs.gd `built: true`)

WoW-style rare spawns: **one spawn point among 2–3 candidates, 45–90 min respawn timer
(persisted via SaveSystem), silver-dragon-style nameplate accent, ~3× family HP, +1 extra
ability/tell** (they must TEACH: each forces a class mechanic harder than trash does).
Signature drops are **100%** (that is the reward for finding them); each also runs its
family table at 2× gear_chance. Raven Hollow's own rare is already live: **Old Mother**
(bear, wilderness) — recipe_wolf_fang_dagger + 2 pelts (crafting.gd:345) — pattern-setter.

```gdscript
const RARE_SPAWNS := {
	# zone_id: [ {name, base_type, family, level, respawn_min, spawn_hint, teaches, drops[]} ]
	"iron_vein": [
		{"name": "Rusca the Drowned Sow", "base_type": "boar", "level": 7, "respawn_min": 60,
		 "spawn_hint": "the pond shallows south of the Bent Oar",
		 "teaches": "charge telegraph — long straight-line rush; sidestep or root it",
		 "drops": [
			{"id": "rust_cured_hide_cloak", "rarity": "rare", "slot": "chest", "bind": "pickup"},
			{"id": "boar_hide", "count": 3}]},
		{"name": "The Courier's Horse", "base_type": "skeleton", "level": 8, "respawn_min": 90,
		 "spawn_hint": "night only, on the graves row east of the fords",   # it kept walking
		 "teaches": "enrage at 30% hp — a burn-phase check (cooldowns / execute abilities)",
		 "drops": [
			{"id": "saddlebag_buckle_band", "rarity": "rare", "slot": "ring", "bind": "pickup"},
			{"id": "sealed_satchel_strap", "rarity": "uncommon", "slot": "none"}]},  # lore token
	],
	"vetka": [
		{"name": "Bellwether", "base_type": "boar", "level": 5, "respawn_min": 45,
		 "spawn_hint": "the fallow field behind Gren's barn",
		 "teaches": "summons 2 piglets mid-fight — target-switching lesson",
		 "drops": [
			{"id": "bellwethers_brass_bell", "rarity": "uncommon", "slot": "trinket", "bind": "equip"},
			{"id": "fatty_haunch", "count": 2}]},
	],
	"copper_wells": [
		{"name": "The First Pilgrim", "base_type": "skeleton_mage", "family": "possessed",
		 "level": 9, "respawn_min": 60,
		 "spawn_hint": "circling the live inscription stone",
		 "teaches": "channels a 3 s cast you MUST interrupt or line-of-sight",
		 "drops": [
			{"id": "pilgrims_copper_stained_wraps", "rarity": "rare", "slot": "boots", "bind": "pickup"},
			{"id": "copper_scale", "count": 3}]},
		{"name": "Copper-Tongue", "base_type": "wolf", "level": 8, "respawn_min": 60,
		 "spawn_hint": "drinks at the one clean well at dusk",
		 "teaches": "applies a bleed — first sustained-damage check (heal/potion discipline)",
		 "drops": [{"id": "coppertongue_pelt_mantle", "rarity": "rare", "slot": "head", "bind": "pickup"},
			{"id": "wolf_pelt", "count": 2}]},
	],
	"stonepath": [
		{"name": "Whitepelt", "base_type": "wolf", "level": 11, "respawn_min": 60,
		 "spawn_hint": "leads the northern pack — kill the pack and she comes",
		 "teaches": "pack fight: she howls, buffing pack speed — AoE and kill-order lesson",
		 "drops": [{"id": "whitepelt_cloak", "rarity": "rare", "slot": "chest", "bind": "pickup"},
			{"id": "recipe_winter_stew", "chance_note": "always"}]},
		{"name": "The Stonereader", "base_type": "skeleton_warrior", "level": 12, "respawn_min": 90,
		 "spawn_hint": "kneels at the shortening inscription; stands when you read it",
		 "teaches": "shielded until knocked off the stone — positioning/knockback lesson",
		 "drops": [{"id": "kerbstone_greatblade", "rarity": "rare", "slot": "main_hand", "bind": "pickup"},
			{"id": "kerbstone_chip", "count": 2}]},
	],
	"grey_marches": [
		{"name": "Mourncoat", "base_type": "wolf", "level": 14, "respawn_min": 60,
		 "spawn_hint": "the graves clearing, always alone",   # greywolves are never alone. this one is.
		 "teaches": "fade — untargetable 2 s stealth windows; retarget fast or kite blind",
		 "drops": [{"id": "mourncoat_ruff", "rarity": "rare", "slot": "head", "bind": "pickup"}]},
		{"name": "Brother Cinder", "base_type": "orc_shaman", "family": "cultist",
		 "level": 15, "respawn_min": 90,
		 "spawn_hint": "tends the cult fire at night",
		 "teaches": "drops fire zones — sustained movement while dealing damage",
		 "drops": [{"id": "cinderbrand_rod", "rarity": "rare", "slot": "main_hand", "bind": "pickup"},
			{"id": "cult_wax", "count": 3}]},
	],
	"western_lowlands": [
		{"name": "Two-Knife Vasca", "base_type": "orc_rogue", "family": "bandit",
		 "level": 16, "respawn_min": 60,
		 "spawn_hint": "walks the west bank road between the hamlets, disguised as a trader",
		 "teaches": "gap-closer + disarm-style slow: a duelist that punishes face-tanking",
		 "drops": [{"id": "vascas_second_knife", "rarity": "rare", "slot": "main_hand", "bind": "pickup"},
			{"id": "toll_receipt_forged", "count": 1}]},
		{"name": "The Granary Rat", "base_type": "boar", "level": 13, "respawn_min": 45,
		 "spawn_hint": "under the full granary, fat beyond reason",
		 "teaches": "huge hp sponge, weak damage — an endurance/resource-management check",
		 "drops": [{"id": "overfed_hide_belt", "rarity": "uncommon", "slot": "legs", "bind": "equip"},
			{"id": "gift_grain", "count": 1}]},   # foreshadows the South. wrong grain, wrong soil.
	],
	"angel_wings": [
		{"name": "The Guildless", "base_type": "orc_rogue", "family": "bandit",
		 "level": 17, "respawn_min": 90,
		 "spawn_hint": "the thatch alleys south of the docks, night only",
		 "teaches": "pickpockets a random bag item mid-fight — kill him to get it back (loot window returns it + his)",
		 "drops": [{"id": "guildless_gloves", "rarity": "rare", "slot": "boots", "bind": "pickup"},
			{"id": "lifted_orphanage_donation", "rarity": "uncommon", "slot": "none"}]},  # turn-in: Maren rep
	],
	"famine_fields": [
		{"name": "The Fasting Man", "base_type": "orc_shaman", "family": "cultist",
		 "level": 18, "respawn_min": 90,
		 "spawn_hint": "kneels in the burned farmstead, facing the lead box scratches",
		 "teaches": "damage-share aura with 2 acolytes — kill order under pressure",
		 "drops": [{"id": "fasting_cord_cinch", "rarity": "rare", "slot": "legs", "bind": "pickup"},
			{"id": "hunger_psalm_page", "count": 2}]},
		{"name": "Ribcage", "base_type": "wolf", "level": 16, "respawn_min": 45,
		 "spawn_hint": "trails the starving-dog packs; they scatter when it feeds",
		 "teaches": "frenzy stacks — dps race; the longer the fight the harder it hits",
		 "drops": [{"id": "ribcage_collar", "rarity": "rare", "slot": "trinket", "bind": "pickup"}]},
	],
	"riverfork": [
		{"name": "Toll-Taker Dragan", "base_type": "orc_warrior", "family": "bandit",
		 "level": 19, "respawn_min": 90,
		 "spawn_hint": "mans the toll post at dawn, counting nothing",
		 "teaches": "shield-wall stance windows — hit him only when the guard drops (timing)",
		 "drops": [{"id": "dragans_toll_hammer", "rarity": "rare", "slot": "main_hand", "bind": "pickup"},
			{"id": "strongbox_key_bent", "rarity": "uncommon", "slot": "none"}]},  # opens the toll strongbox once
		{"name": "The Undertow", "base_type": "boar", "family": "river_drake",
		 "level": 20, "respawn_min": 90,
		 "spawn_hint": "surfaces at the fork where the two arms argue, rain only",
		 "teaches": "submerges every 25% hp, adds spawn — phase fight in miniature",
		 "drops": [{"id": "drakescale_round_shield", "rarity": "rare", "slot": "off_hand", "bind": "pickup"},
			{"id": "river_pearl", "count": 2}]},
	],
}
```

Signature-item stat language (bracket-appropriate, rare = 1.8× budget + secondary):
e.g. `vascas_second_knife` {damage 6.0, crit 8%}, `drakescale_round_shield`
{armor 5.0, hp 20}, `whitepelt_cloak` {armor 4.0, hp 12, speed 4%} — concrete stats
authored at item-DB time using items.gd budget precedents (iron_cuirass rare-b1
= armor 4/hp 15 is the calibration point).

---

## 10. Boss rules (dungeon & zone bosses, all brackets)

1. **Guaranteed slot 1**: one gear piece, rarity floor **rare** (b1–b6) / **rare with
   20% epic upgrade chance** (b7) / **epic floor** (b8 endgame: Bloodstone Pit, Coldharbor
   Deep finals). Curated 3–4 candidate list per boss, weighted — WoW's "his loot table"
   that players learn and farm.
2. **Guaranteed slot 2**: lore/quest token or boss crafting material ×2–3 (feeds the
   bracket's flagship recipes).
3. **Guaranteed gold** at 4–6× the bracket humanoid max.
4. All guaranteed gear is **BoP**; the bonus world-roll (gear_chance 0.25) stays BoE.
5. Lockout: rare-spawn timer rules for outdoor bosses; dungeon bosses re-kill freely in
   demo (daily lockout post-demo).
6. Legendaries NEVER on boss tables — quest lines only (owner's slow-progression law;
   bosses may drop the quest-STARTING item, e.g. `underlanguage_etched_talon`).

---

## 11. Integration checklist (exact touch points)

1. **`scripts/loot_tables.gd`** — new static class: `TABLES`, `BOSS_TABLES`, `RARE_SPAWNS`,
   `GEAR_POOLS`, `GEAR`, `JUNK` dbs + `roll_for()`, `item_lookup()`, `family_for()`.
2. **`enemy.gd`** — `_grant_kill_rewards()` (line 476): keep XP + quest report; REPLACE the
   `Crafting.drop_for_kill` block with `_loot = LootTables.roll_for(type_name, display_name,
   zone_id)`; corpse enters "lootable" state (glint via existing VFX sparkle; `queue_free`
   deferred until looted/timeout). Add an `interact` hit area on the corpse.
3. **New `scripts/loot_window_ui.gd`** — the WoW loot list: coin row + rarity-tinted rows
   (`Items.rarity_color()`), click-to-take → `Inventory.add_item()`, full-bag rows stay in
   the window (WoW behavior), Take All, Esc/walk-away closes without losing loot.
4. **`item_tooltip.gd`** — bind line; junk items show sell value line.
5. **`save_system.gd`** — persist rare-spawn respawn timestamps + looted-corpse nothing
   (corpses are transient; un-taken loot is forfeit on save/zone-change, WoW-style).
6. **`icons_pixel.gd`** — new Shikashi cells for junk/material/gear ids (follow the
   crafting.gd `FALLBACK_ICON_CELLS` promotion pattern).
7. **Tuning hook**: expected-value spreadsheet check — per bracket, (gold EV + junk sell EV
   + material vendor EV) per kill must land at 55–75% of a same-bracket coach fare per
   10 kills, so travel never becomes free but grinding always pays.
