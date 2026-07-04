# RAVEN HOLLOW — ITEM PROGRESSION SYSTEM (1–60)
Design doc for the WoW-Classic-spirit item game: rarity tiers, item-level math,
slot budgets, class affinities, Draconia naming language, lore sets, and 40
fully-statted exemplars in the exact `items.gd` data shape.

**Grounded in (read before writing):**
- `scripts/items.gd` — item dict shape `{id, name, slot, rarity, icon, stats, flavor, stackable, effect}`;
  stats `{damage, armor, hp, mana, speed_pct, crit_pct}` (+ optional `mana_regen`); `RARITY_COLORS`;
  5 shipped legendaries (Emberfall, Rook's Talon, Gravekeeper's Band, Bulwark, Bloody Dagger).
- `scripts/inventory.gd` — 9 equip slots `head/chest/legs/boots/main_hand/off_hand/ring1/ring2/trinket`;
  item slot TYPES (`ring` maps onto ring1/ring2); `STAT_KEYS`; `stat_totals()`.
- `scripts/player.gd` — `_apply_equipment()`: hp/mana add to class maxima, `speed_pct` multiplies
  move speed, flat `damage` adds to every ability, `crit_pct` rolls 1.5x crits; `+1 dmg / +6% hp+mana` per level.
- `scripts/class_defs.gd` — 7 classes: warrior, rogue, mage, paladin, necromancer, rookwarden (Hunter), druid.
- `scripts/xp_system.gd` — demo cap 10 (post-demo 60), kill-XP families, quest XP 50–150.
- `scripts/crafting.gd` — the "extension keys ignored by core" layering pattern (`type`, `count`)
  this doc reuses for `ilvl`, `req_level`, `set_id`, `value`.
- `scripts/enemy.gd` / `combat.gd` — mob HP 30–48 dmg 6–9 at L1–10; `_grant_kill_rewards()` is
  where the loot roll (and the future loot window) hooks in.
- `WORLD_PLAN.md` — 40 zones, 2 continents, build-order arms (the act/bracket spine below).

---

## 1. RARITY TIERS

Six tiers, WoW color language adapted to the Graveyard-Keeper muted palette.
The existing grey `common` value **is** WoW's poor-grey (`#9e9e9e` ≈ `9d9d9d`) —
so the grey moves down to the new `poor` tier and `common` becomes muted white.

```gdscript
# items.gd — RARITY_COLORS, extended (only "poor" is NEW; "common" recolors):
const RARITY_COLORS := {
	"poor":      Color(0.62, 0.62, 0.62),  # WoW #9d9d9d grey  (the old common value)
	"common":    Color(0.92, 0.91, 0.87),  # WoW #ffffff white, muted for the GK palette
	"uncommon":  Color(0.35, 0.75, 0.35),  # WoW #1eff00 green  (unchanged)
	"rare":      Color(0.3, 0.5, 0.9),     # WoW #0070dd blue   (unchanged)
	"epic":      Color(0.62, 0.35, 0.85),  # WoW #a335ee purple (unchanged)
	"legendary": Color(1.0, 0.55, 0.1),    # WoW #ff8000 orange (unchanged)
}
```

Migration: nothing in the codebase branches on rarity except `rarity_color()`
and tooltips, so adding `poor` is additive. Existing `common` items keep their
tier and simply render white — correct, they are white-quality starters.

### Drop philosophy per tier (the loot-window contract)

Every creature death opens the loot window (per owner mandate — rarity-colored
names, click to take). These rates are what the window shows; they are tuned so
green text is a small event, blue text is a shout, purple is a screenshot.

| Tier | Sources & rates | Feel target |
|---|---|---|
| **Poor** | 45–60% of any kill: pelts-with-mange, cracked bones, waterlogged junk. Slot `none` or barely-statted gear. Exists to be sold — the coin engine. | "The bog pays in scraps." Every loot window has *something*. |
| **Common** | ~8% of level-appropriate kills; the default vendor stock; early quest filler. 1–2 stats, full budget, no personality. | Honest gear. You wear it because the alternative is nothing. |
| **Uncommon** | 2–4% world drop; the standard early-quest reward; most craft outputs. Full budget + suffix identity ("of the Vigil"). | The workhorse upgrade tier for 1–40. A green in the window still quickens the pulse at 60 (disenchant fodder later). |
| **Rare** | 0.3–0.5% world drop; 15–30% from zone rare-elites ("the Digging Creature"); **guaranteed** from dungeon bosses (Chamber Depths, the Pit, Coldharbor); capstone quest-chain rewards. | Blue = a story. You remember where each one came from. Slot upgrades that last 8–12 levels. |
| **Epic** | 0.02–0.05% open-world ("world epic" — a tale told at the Bent Oar); end-boss of each act's dungeon; the final reward of an act-long chain; lore-set pieces. Never on a vendor. | Purple = a character milestone, ~1 per act if you do everything, 2–3 if you farm. |
| **Legendary** | **Never a random roll.** One narrative capstone per act, earned through its questline (the 5 demo legendaries set this precedent). Effect hook mandatory (`effect` id handled in player.gd). | Orange = the act remembers you. 6–8 exist per character lifetime. |

Additional loot-window rules:
- Poor/common auto-roll silently INTO the window list, never onto the ground.
- Crafting materials (`Crafting.drop_for_kill`) list in the window too, colored by their rarity.
- Money is a window line ("4 silver, 20 copper" style; we use gold — see §7 vendor math).

---

## 2. ITEM LEVEL & STAT-BUDGET FORMULA (exact math)

### 2.1 The stat shape (unchanged, extended)

Every item keeps the exact `items.gd` shape. Four **extension keys** are added
after `effect`, following the `crafting.gd` layering precedent (core code
ignores unknown keys; only tooltips/vendors/loot read them):

```gdscript
"ilvl": 10,          # int   — the item's power level, drives the budget below
"req_level": 10,     # int   — player level gate (BagUI greys + blocks equip)
"set_id": "",        # String — lore-set membership ("" = not a set piece), §5
"value": 12,         # int   — vendor SELL price in gold (buy = 4x), §7
```

### 2.2 Budget formula

An item's total **budget points (BP)**:

```
BP(ilvl, slot, rarity) = (2.4 + 0.62 * ilvl) * SLOT_W[slot] * RARITY_M[rarity]
```

```gdscript
const SLOT_W := {           # slot weight — main_hand is the yardstick (1.0)
	"main_hand": 1.00,
	"chest":     0.90,
	"legs":      0.80,
	"head":      0.75,
	"off_hand":  0.70,
	"boots":     0.60,
	"trinket":   0.55,
	"ring":      0.50,      # two ring slots -> each ring is half a slot
}
const RARITY_M := {
	"poor": 0.5, "common": 1.0, "uncommon": 1.2,
	"rare": 1.45, "epic": 1.7, "legendary": 2.0,
}
```

### 2.3 Stat costs (points per unit)

| Stat | Cost | Rationale (from player.gd behavior) |
|---|---|---|
| `damage` 1.0 | **1.0** | Adds flat to EVERY ability hit — the premium stat. |
| `armor` 1.0 | **1.0** | Flat reduction per incoming hit (min 1) — mirror of damage. |
| `hp` 1.0 | **0.2** (5 hp = 1 pt) | Additive to max_hp; hp pools are ~10x damage numbers. |
| `mana` 1.0 | **0.2** (5 mana = 1 pt) | Same scale as hp. |
| `speed_pct` 1% | **1.0** | Multiplies move speed — kiting power; per-item cap 8, worn total soft-cap ~25. |
| `crit_pct` 1% | **1.0** | 1.5x crit rolls; per-item cap 10, worn total soft-cap ~30. |
| `mana_regen` 1.0/s | **4.0** | Sustains infinite casting — priced like a legendary line (Gravekeeper's Band precedent); rare+ only. |

Stat-count guideline by rarity: poor 0–1 stats · common 1–2 · uncommon 2–3 ·
rare 3–4 · epic 3–5 · legendary 3–4 **+ effect hook**.

### 2.4 Retro-fit validation (the formula reproduces the shipped DB)

| Existing item | Slot/rarity | Stats → points | Solved ilvl |
|---|---|---|---|
| Rusted Shortsword | MH common | 3 dmg = 3.0 | **i1** ✓ starter |
| Padded Breeches | legs common | 1 armor + 5 hp = 2.0 | **i1** ✓ |
| Pinewood Buckler | OH uncommon | 2 armor + 10 hp = 4.0 | **i4** ✓ |
| Coppervein Ring | ring uncommon | 10 hp + 8 mana = 3.6 | **i6** ✓ quest 1 |
| Iron Cuirass | chest rare | 4 armor + 15 hp = 7.0 | **i6** ✓ |
| Goran's Targe | OH rare | 4 armor + 12 hp = 6.4 | **i6** ✓ quest reward |
| Emberfall | MH legendary | 12 dmg + 5 crit = 17.0 | **i10** ✓ demo capstone at cap 10 |
| Bulwark | OH legendary | 8 armor + 25 hp = 13.0 | **i11** ✓ |
| Bloody Dagger | MH legendary | 7 dmg + 8 crit = 15.0 | **i9** ✓ |
| Rook's Talon | MH legendary | 9 dmg + 10 spd = 19.0 | **i12** — slightly ahead, correct for a legendary that should carry into Act II |
| Raven's Eye | trinket epic | 5 spd + 5 crit = 10.0 | **i13** — deliberately ahead of curve (quest 4A capstone) |
| Gravekeeper's Band | ring legendary | 20 mana + 2 regen = 12.0 | **i15** — the "grows with you" outlier; keep |

The demo DB sits exactly on this curve. **Existing items need zero stat edits** —
they only gain `ilvl/req_level/value` annotations.

### 2.5 The curve at a glance (main_hand damage, pure-damage build)

| ilvl | BP base | common MH dmg | rare MH dmg | epic MH dmg | legendary MH dmg |
|---|---|---|---|---|---|
| 1 | 3.0 | 3 | 4 | 5 | 6 |
| 10 | 8.6 | 8 | 12 | 14 | 17 |
| 20 | 14.8 | 14 | 21 | 25 | 29 |
| 30 | 21.0 | 21 | 30 | 35 | 42 |
| 40 | 27.2 | 27 | 39 | 46 | 54 |
| 50 | 33.4 | 33 | 48 | 56 | 66 |
| 60 | 39.6 | 39 | 57 | 67 | 79 |

Combat-scaling note (for the combat doc, not this one): player flat damage at 60
≈ 59 (level bonus) + ~40 (epic MH, split statline) + ~15 (rest of kit) ≈ 115 on
top of ability base — bracket-60 trash needs 600–900 HP to honor the
"no one-hit trash" mandate.

---

## 3. SLOT COVERAGE & UPGRADE CADENCE

### 3.1 Slots (aligned to `inventory.gd` — no new equip slots)

9 paper-doll slots / 8 item slot-types: `head, chest, legs, boots, main_hand,
off_hand, ring (x2), trinket`. `slot: "none"` remains junk/quest/material space.
No two-handers, wands, capes or shoulders — off_hand covers shields, tomes,
fetishes and quivers via flavor (a Necromancer's off_hand rare is a
"grave-fetish", statted like a caster shield).

### 3.2 Upgrade cadence at classic pacing

Design law: **a slot upgrade should feel earned, not scheduled.** Targets:

| Bracket | Expected upgrades/level (all 9 slots) | Median slot age when replaced | Where upgrades come from |
|---|---|---|---|
| 1–10 | ~1.2 | 5 levels | quests mostly (demo pattern) |
| 10–20 | ~1.0 | 7 levels | quest + first crafted blues |
| 20–30 | ~0.9 | 8 levels | drops overtake quests |
| 30–40 | ~0.8 | 9 levels | dungeon rares, set hunting starts |
| 40–50 | ~0.7 | 10 levels | dungeon/elite farming |
| 50–60 | ~0.5 | 12+ levels | act-VI chains, epics trickle |

Item-level offsets (what the loot window rolls at, per source):
- World-drop gear: `ilvl = mob level`, rarity does NOT raise ilvl (rarity raises budget — that's the whole point).
- Quest reward: `ilvl = quest level` (on-curve, choice of 2–3 class-slanted options).
- Zone rare-elite: `ilvl = mob level + 2`.
- Dungeon boss: `ilvl = boss level + 3`; act-end boss `+5`.
- `req_level = ilvl` everywhere (clean rule; twinking is throttled by acquisition, not math).

---

## 4. CLASS–STAT AFFINITIES (7 classes)

Stats are universal (no str/agi/int) — affinity is expressed through **which
statlines drop where a class hunts, and which quest options exist**, not
through class-locking. Quest rewards offer 2–3 options slanted per table below;
suffix items (§5.2) implement these lines.

| Class | Primary line | Secondary line | Avoids | Signature suffixes |
|---|---|---|---|---|
| **Warrior** | damage, armor | hp | mana_regen | *of the Bulwark, of the Ember* |
| **Paladin** | armor, hp | mana | speed_pct | *of the Vigil, of the Dawn* |
| **Rogue** | damage, crit_pct | speed_pct | armor, mana | *of the Whisper, of the Rookery* |
| **Mage** | mana, crit_pct | mana_regen | armor | *of the Thread, of the Ember* |
| **Necromancer** | mana, hp | mana_regen | speed_pct | *of the Grave, of the Thread* |
| **Hunter (Rookwarden)** | damage, speed_pct | crit_pct, mana | armor | *of the Rookery, of the Whisper* |
| **Druid** | hp, mana | armor, speed_pct | crit_pct | *of the Wildwood, of the Vigil* |

Rule of thumb when authoring an item: pick a target class pair, spend ≥60% of
the budget in their primary line, and the item self-sorts in the loot window.

---

## 5. DRACONIA NAMING LANGUAGE & LORE SETS

### 5.1 Material lexicon (prefix vocabulary, act-anchored)

Poor/common items are `material + noun`; uncommon adds a suffix; rare names a
place or person; epic gets an artifact name + clause flavor; legendary is a
single evocative name (Emberfall precedent). Dread stays ambient — no clean wins.

| Material | Act / region | Reads as |
|---|---|---|
| **bog-iron** | I — Border (Iron Vein) | river-smelted, rust-veined, honest |
| **grave-silver** | I/III — graveyards, Gravemark | tarnishes black the week someone lies |
| **lead-lined** | II — Angel Wings (the Lead Vault) | heavy, warded against *using* power |
| **thread-touched / thread-silver** | III — Black Night | faint blue filament in the metal; cold |
| **blackglass** | IV — Blestem | Strigoi obsidian; edges that remember |
| **lichen-steel** | IV — Lichenreach | pale luminous sheen in the dark |
| **basaltfang / emberforged** | V — Sangeroasa | forge-black, warm long after |
| **ledger-brass / salt-oak** | VI — Collector's Coast | stamped, filed, never quite dry |

### 5.2 Suffix table (stat identity, budget split)

| Suffix | Statline (budget share) | Affinity |
|---|---|---|
| *of the Vigil* | armor 40% / hp 60% | Paladin, Druid |
| *of the Ember* | damage 70% / crit 30% | Warrior, Mage |
| *of the Rookery* | speed 50% / damage 50% | Hunter, Rogue |
| *of the Whisper* | crit 60% / speed 40% | Rogue, Hunter |
| *of the Thread* | mana 60% / mana_regen 40% (rare+) | Mage, Necromancer |
| *of the Grave* | hp 50% / mana 50% | Necromancer |
| *of the Wildwood* | hp 50% / mana 30% / armor 20% | Druid |
| *of the Bog* | hp 100% | anyone leveling |
| *of the Hollow* | even 4-way split | the balanced fallback |

### 5.3 Lore sets (one per act, 3 pieces each — the §8 exemplars carry them)

Sets need one engine extension, same pattern as `effect`:

```gdscript
# items.gd — set registry; Inventory.stat_totals() gains ~10 lines: count
# equipped items per set_id, then add every bonuses[n] dict with n <= count
# into the totals (bonus dicts use STAT_KEYS, so the sum loop is reused).
const SETS := {
	"gravekeepers_rounds": {
		"name": "The Gravekeeper's Rounds",
		"pieces": ["gravekeepers_coat", "gravekeepers_mudboots", "gravekeepers_lantern"],
		"bonuses": {2: {"hp": 15.0}, 3: {"mana_regen": 1.0}},
	},
	"marens_vigil": {
		"name": "Maren's Vigil",
		"pieces": ["marens_kerchief", "marens_patched_shawl", "marens_chalk_ring"],
		"bonuses": {2: {"armor": 3.0}, 3: {"hp": 40.0}},
	},
	"vigil_of_the_twelve": {
		"name": "Vigil of the Twelve",
		"pieces": ["twelfth_watchers_halfhelm", "twelfth_watchers_greaves", "twelfth_watchers_ward"],
		"bonuses": {2: {"hp": 30.0}, 3: {"armor": 8.0}},
	},
	"riddlers_blackglass": {
		"name": "The Riddler's Blackglass",
		"pieces": ["riddlers_blackglass_mask", "riddlers_softstep_boots", "riddlers_obsidian_loop"],
		"bonuses": {2: {"speed_pct": 4.0}, 3: {"crit_pct": 6.0}},
	},
	"forgefathers_toll": {
		"name": "The Forgefather's Toll",
		"pieces": ["forgefathers_facemask", "forgefathers_apron", "forgefathers_pavise"],
		"bonuses": {2: {"armor": 6.0}, 3: {"damage": 10.0}},
	},
	"collectors_accord": {
		"name": "The Collector's Accord",
		"pieces": ["accordkeepers_grey_cowl", "accordkeepers_treads", "accordkeepers_seal"],
		"bonuses": {2: {"mana": 30.0}, 3: {"mana_regen": 2.0}},
	},
}
```

| Act | Set | Pieces (slots) | Story hook | Who wants it |
|---|---|---|---|---|
| I (1–10) | **The Gravekeeper's Rounds** | chest, boots, trinket | Vasile's working clothes — pairs with the Gravekeeper's Band legendary (4-piece *feel* without 4-piece code) | Necromancer, Druid |
| II (10–20) | **Maren's Vigil** | head, chest, ring | The orphanage safehouse; the chalk handprints wall | Paladin, Druid |
| III (20–30) | **Vigil of the Twelve** | head, legs, off_hand | Armor of the Iele who stand in rows of twelve — wearing it, you're mistaken for one of the still | Warrior, Paladin |
| IV (30–40) | **The Riddler's Blackglass** | head, boots, ring | Blestem's disorientation-engine district; the mask has no eye-holes and you see fine | Rogue, Hunter |
| V (40–50) | **The Forgefather's Toll** | head, chest, off_hand | Debt-Pit foreman plate; the ledger line for each piece reads "collected" | Warrior, Paladin |
| VI (50–60) | **The Collector's Accord** | head, boots, ring | Greyhollow clerical regalia — the cure that curdled | Mage, Necromancer |

Set-piece acquisition (classic spirit): every piece from a DIFFERENT source
within the act — one dungeon boss, one quest-chain capstone, one rare-elite/world
drop — so completing a set is an act-long project.

---

## 6. ACQUISITION MIX PER BRACKET

Share of a leveling player's actual slot upgrades, by source:

| Bracket (Act, zones) | Vendor | Craft | Drop | Quest | Notes |
|---|---|---|---|---|---|
| 1–10 (I — Border ring, z1–6) | 10% | 15% | 30% | **45%** | Demo pattern: quests carry you; vendor sells common fillers for empty slots. |
| 10–20 (II — West arm, z7–11) | 10% | 20% | 35% | 35% | First crafted blues (wolf-fang line extends); bandit gear drops. |
| 20–30 (III — North arm, z12–16) | 5% | 20% | **45%** | 30% | Drops overtake; Gravemark warbands are the first gear-farm spot. |
| 30–40 (IV — East arm, z17–21) | 5% | 25% | **45%** | 25% | Lichenreach cave runs = repeatable rare source; blackglass craft recipes. |
| 40–50 (V — South arm, z22–26) | 5% | 25% | **50%** | 20% | Forge-city crafting peak (emberforged line); Debt Pit elite circuits. |
| 50–60 (VI — Continent 2, z27–40) | 0–5% | 20% | **55%** | 20% | Dungeon-driven endgame (Coldharbor Deep); vendors only sell consumables/fillers. |

Vendor rules: vendors stock **poor tools and common gear only** (+1 uncommon
"stock special" per capital, rotating) — gold is for repairs-later, mounts-later,
recipes and consumables, never for progression jumps. Craft outputs are
uncommon by default, rare with drop-gated reagents (the recipe-scroll drop
pattern `crafting.gd` already ships).

---

## 7. VENDOR MATH (`value` key)

```
value (SELL, gold) = max(1, round(0.35 * ilvl * RARITY_M[rarity]))   # gear
value (poor junk)  = max(1, round(0.25 * ilvl))                      # the coin engine
buy price          = value * 4
```

At kill rates of ~60% junk, a bracket-30 clear-and-vendor loop yields ~25–40g/hr
— tuned so a 100g capital recipe is a session's decision, matching classic's
"gold is scarce, gold is real" feel.

---

## 8. EXEMPLARS — 40 FULLY-STATTED ITEMS (exact `items.gd` shape)

All entries verified against §2 budget math (spend within ±1 pt of BP).
Icons follow the repo law `icon id == item id` → each needs an
`IconsPixel.REGISTRY` cell (PIL-verify on the Shikashi sheets, per the
`crafting.gd` integration precedent). Every `stats` dict carries all six base
keys; `mana_regen` only where spent (Gravekeeper's Band precedent).
`ilvl/req_level/set_id/value` are the §2.1 extension keys.

```gdscript
	# ==================================================================
	# ACT I — BORDER RING (ilvl 1-10) — 7 items
	# ==================================================================
	"cracked_femur": {
		"id": "cracked_femur", "name": "Cracked Femur", "slot": "none",
		"rarity": "poor", "icon": "pixel:cracked_femur",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Whoever it was, they walked a long way on it first.",
		"stackable": true, "effect": "",
		"ilvl": 1, "req_level": 1, "set_id": "", "value": 1,
		# source: skeleton-family junk roll (~50%). Loot-window filler; vendor coin.
	},
	"waterlogged_boots": {
		"id": "waterlogged_boots", "name": "Waterlogged Boots", "slot": "boots",
		"rarity": "poor", "icon": "pixel:waterlogged_boots",
		"stats": {"damage": 0.0, "armor": 1.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Fished out of the Iron Vein. Nobody came asking.",
		"stackable": false, "effect": "",
		"ilvl": 3, "req_level": 1, "set_id": "", "value": 1,
		# BP 1.3: armor 1. source: bog-mob junk roll. Wearable-in-a-pinch grey.
	},
	"bogiron_cleaver": {
		"id": "bogiron_cleaver", "name": "Bog-Iron Cleaver", "slot": "main_hand",
		"rarity": "common", "icon": "pixel:bogiron_cleaver",
		"stats": {"damage": 7.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "River-smelted. The rust is the color the water always was.",
		"stackable": false, "effect": "",
		"ilvl": 8, "req_level": 8, "set_id": "", "value": 3,
		# BP 7.4: dmg 7. source: Bent Oar vendor stock / Iron Vein world drop.
	},
	"wardens_quilted_cap": {
		"id": "wardens_quilted_cap", "name": "Warden's Quilted Cap", "slot": "head",
		"rarity": "uncommon", "icon": "pixel:wardens_quilted_cap",
		"stats": {"damage": 0.0, "armor": 3.0, "hp": 15.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Stitched thick over the ears. Better not to hear the stones.",
		"stackable": false, "effect": "",
		"ilvl": 8, "req_level": 8, "set_id": "", "value": 3,
		# BP 6.6: armor 3 + hp 15(3) = 6. source: Copper Wells quest reward.
	},
	"gravekeepers_coat": {
		"id": "gravekeepers_coat", "name": "Gravekeeper's Coat", "slot": "chest",
		"rarity": "rare", "icon": "pixel:gravekeepers_coat",
		"stats": {"damage": 0.0, "armor": 5.0, "hp": 25.0, "mana": 5.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Vasile's spare. He says he never lost a coat. Note the 'lost'.",
		"stackable": false, "effect": "",
		"ilvl": 10, "req_level": 10, "set_id": "gravekeepers_rounds", "value": 5,
		# BP 11.2: 5 + 25hp(5) + 5mana(1) = 11. source: Chamber Depths boss.
	},
	"gravekeepers_mudboots": {
		"id": "gravekeepers_mudboots", "name": "Gravekeeper's Mudboots", "slot": "boots",
		"rarity": "uncommon", "icon": "pixel:gravekeepers_mudboots",
		"stats": {"damage": 0.0, "armor": 2.0, "hp": 10.0, "mana": 0.0, "speed_pct": 2.0, "crit_pct": 0.0},
		"flavor": "The mud of a thousand mornings. He counts them.",
		"stackable": false, "effect": "",
		"ilvl": 9, "req_level": 9, "set_id": "gravekeepers_rounds", "value": 3,
		# BP 5.7: 2 + 10hp(2) + spd2 = 6. source: graveyard rare-elite drop.
	},
	"gravekeepers_lantern": {
		"id": "gravekeepers_lantern", "name": "Gravekeeper's Lantern", "slot": "trinket",
		"rarity": "rare", "icon": "pixel:gravekeepers_lantern",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 10.0, "mana": 15.0, "speed_pct": 0.0, "crit_pct": 2.0},
		"flavor": "It gutters when you pass the new rows. Only the new ones.",
		"stackable": false, "effect": "",
		"ilvl": 10, "req_level": 10, "set_id": "gravekeepers_rounds", "value": 5,
		# BP 6.9: 10hp(2) + 15mana(3) + crit2 = 7. source: Act I chain capstone.
	},

	# ==================================================================
	# ACT II — WEST / ANGEL WINGS (ilvl 10-20) — 7 items
	# ==================================================================
	"famine_field_sickle": {
		"id": "famine_field_sickle", "name": "Famine-Field Sickle", "slot": "main_hand",
		"rarity": "common", "icon": "pixel:famine_field_sickle",
		"stats": {"damage": 9.0, "armor": 0.0, "hp": 5.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Sharpened for a harvest that never came in.",
		"stackable": false, "effect": "",
		"ilvl": 12, "req_level": 12, "set_id": "", "value": 4,
		# BP 9.8: dmg 9 + 5hp(1) = 10. source: Famine Fields world drop / vendor.
	},
	"lowland_poachers_hood": {
		"id": "lowland_poachers_hood", "name": "Lowland Poacher's Hood", "slot": "head",
		"rarity": "uncommon", "icon": "pixel:lowland_poachers_hood",
		"stats": {"damage": 0.0, "armor": 4.0, "hp": 20.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 2.0},
		"flavor": "The Queen's wardens hang poachers. The hoods they keep.",
		"stackable": false, "effect": "",
		"ilvl": 14, "req_level": 14, "set_id": "", "value": 6,
		# BP 10.0: 4 + 20hp(4) + crit2 = 10. Hunter/Rogue slant. source: bandit drops.
	},
	"riverfork_toll_blade": {
		"id": "riverfork_toll_blade", "name": "Riverfork Toll-Blade", "slot": "main_hand",
		"rarity": "rare", "icon": "pixel:riverfork_toll_blade",
		"stats": {"damage": 14.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 4.0},
		"flavor": "The toll was never coin.",
		"stackable": false, "effect": "",
		"ilvl": 16, "req_level": 16, "set_id": "", "value": 8,
		# BP 17.9: dmg 14 + crit4 = 18. source: Riverfork bandit-chief rare-elite.
	},
	"marens_kerchief": {
		"id": "marens_kerchief", "name": "Maren's Kerchief", "slot": "head",
		"rarity": "rare", "icon": "pixel:marens_kerchief",
		"stats": {"damage": 0.0, "armor": 5.0, "hp": 30.0, "mana": 15.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Chalk dust in the weave. It never washes out. She never tried.",
		"stackable": false, "effect": "",
		"ilvl": 17, "req_level": 17, "set_id": "marens_vigil", "value": 9,
		# BP 14.1: 5 + 30hp(6) + 15mana(3) = 14. source: orphanage quest chain.
	},
	"marens_patched_shawl": {
		"id": "marens_patched_shawl", "name": "Maren's Patched Shawl", "slot": "chest",
		"rarity": "rare", "icon": "pixel:marens_patched_shawl",
		"stats": {"damage": 0.0, "armor": 8.0, "hp": 40.0, "mana": 10.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Every patch a child's outgrown coat. One patch is copper-stained.",
		"stackable": false, "effect": "",
		"ilvl": 18, "req_level": 18, "set_id": "marens_vigil", "value": 9,
		# BP 17.7: 8 + 40hp(8) + 10mana(2) = 18. source: Angel Wings act boss.
	},
	"marens_chalk_ring": {
		"id": "marens_chalk_ring", "name": "Maren's Chalk Ring", "slot": "ring",
		"rarity": "rare", "icon": "pixel:marens_chalk_ring",
		"stats": {"damage": 0.0, "armor": 1.0, "hp": 25.0, "mana": 20.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "A ring of chalk keeps nothing out. It marks who was kept in.",
		"stackable": false, "effect": "",
		"ilvl": 18, "req_level": 18, "set_id": "marens_vigil", "value": 9,
		# BP 9.8: 1 + 25hp(5) + 20mana(4) = 10. source: Lead Vault rare-elite.
	},
	"lead_vault_band": {
		"id": "lead_vault_band", "name": "Lead Vault Band", "slot": "ring",
		"rarity": "epic", "icon": "pixel:lead_vault_band",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 15.0, "mana": 25.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 1.0},
		"flavor": "Forged in the room built around not using power. It hums anyway.",
		"stackable": false, "effect": "",
		"ilvl": 20, "req_level": 20, "set_id": "", "value": 12,
		# BP 12.6: 15hp(3) + 25mana(5) + regen1(4) = 12. source: Act II epic chain.
	},

	# ==================================================================
	# ACT III — NORTH / BLACK NIGHT (ilvl 20-30) — 7 items
	# ==================================================================
	"snowwolf_leggings": {
		"id": "snowwolf_leggings", "name": "Snow-Wolf Leggings", "slot": "legs",
		"rarity": "uncommon", "icon": "pixel:snowwolf_leggings",
		"stats": {"damage": 0.0, "armor": 7.0, "hp": 30.0, "mana": 0.0, "speed_pct": 2.0, "crit_pct": 0.0},
		"flavor": "Skinned in the Threadlands. The fur still bristles at dusk.",
		"stackable": false, "effect": "",
		"ilvl": 22, "req_level": 22, "set_id": "", "value": 9,
		# BP 15.4: 7 + 30hp(6) + spd2 = 15. source: Threadlands craft (snow-wolf pelts).
	},
	"still_market_soles": {
		"id": "still_market_soles", "name": "Still-Market Soles", "slot": "boots",
		"rarity": "rare", "icon": "pixel:still_market_soles",
		"stats": {"damage": 0.0, "armor": 5.0, "hp": 25.0, "mana": 0.0, "speed_pct": 6.0, "crit_pct": 0.0},
		"flavor": "Cobbled for a market where no one walks. Someone did.",
		"stackable": false, "effect": "",
		"ilvl": 26, "req_level": 26, "set_id": "", "value": 13,
		# BP 16.1: 5 + 25hp(5) + spd6 = 16. source: Black Night quest capstone.
	},
	"twelfth_watchers_halfhelm": {
		"id": "twelfth_watchers_halfhelm", "name": "Twelfth Watcher's Halfhelm", "slot": "head",
		"rarity": "rare", "icon": "pixel:twelfth_watchers_halfhelm",
		"stats": {"damage": 0.0, "armor": 9.0, "hp": 45.0, "mana": 15.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Eleven stand where they are told. The twelfth watches you count.",
		"stackable": false, "effect": "",
		"ilvl": 28, "req_level": 28, "set_id": "vigil_of_the_twelve", "value": 15,
		# BP 21.5: 9 + 45hp(9) + 15mana(3) = 21. source: Gravemark warband rare-elite.
	},
	"twelfth_watchers_greaves": {
		"id": "twelfth_watchers_greaves", "name": "Twelfth Watcher's Greaves", "slot": "legs",
		"rarity": "rare", "icon": "pixel:twelfth_watchers_greaves",
		"stats": {"damage": 0.0, "armor": 10.0, "hp": 50.0, "mana": 0.0, "speed_pct": 3.0, "crit_pct": 0.0},
		"flavor": "Standing still is a discipline. These have never needed it.",
		"stackable": false, "effect": "",
		"ilvl": 28, "req_level": 28, "set_id": "vigil_of_the_twelve", "value": 15,
		# BP 22.9: 10 + 50hp(10) + spd3 = 23. source: Listening Steppe chain.
	},
	"twelfth_watchers_ward": {
		"id": "twelfth_watchers_ward", "name": "Twelfth Watcher's Ward", "slot": "off_hand",
		"rarity": "rare", "icon": "pixel:twelfth_watchers_ward",
		"stats": {"damage": 0.0, "armor": 13.0, "hp": 40.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Blue-black stone. Warmer on the side that faces the Pit.",
		"stackable": false, "effect": "",
		"ilvl": 29, "req_level": 29, "set_id": "vigil_of_the_twelve", "value": 16,
		# BP 20.7: 13 + 40hp(8) = 21. source: the Grave & Bloodstone Pit boss.
	},
	"gravemark_kerbstone": {
		"id": "gravemark_kerbstone", "name": "Gravemark Kerbstone", "slot": "trinket",
		"rarity": "epic", "icon": "pixel:gravemark_kerbstone",
		"stats": {"damage": 6.0, "armor": 0.0, "hp": 30.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 6.0},
		"flavor": "A palm-sized kerb carved in Underlanguage. Do not read it aloud. Do not read it.",
		"stackable": false, "effect": "",
		"ilvl": 28, "req_level": 28, "set_id": "", "value": 17,
		# BP 18.5: dmg6 + 30hp(6) + crit6 = 18. source: world epic (Gravemark Tundra).
	},
	"vasiles_spade": {
		"id": "vasiles_spade", "name": "Vasile's Spade", "slot": "main_hand",
		"rarity": "epic", "icon": "pixel:vasiles_spade",
		"stats": {"damage": 26.0, "armor": 0.0, "hp": 25.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 5.0},
		"flavor": "He asked for it back politely, once. This is the second time.",
		"stackable": false, "effect": "",
		"ilvl": 30, "req_level": 30, "set_id": "", "value": 18,
		# BP 35.7: dmg 26 + 25hp(5) + crit5 = 36. source: Act III end-boss (the Pit, first kill chain).
	},

	# ==================================================================
	# ACT IV — EAST / BLESTEM (ilvl 30-40) — 7 items
	# ==================================================================
	"whisper_pass_treads": {
		"id": "whisper_pass_treads", "name": "Whisper-Pass Treads", "slot": "boots",
		"rarity": "uncommon", "icon": "pixel:whisper_pass_treads",
		"stats": {"damage": 0.0, "armor": 6.0, "hp": 25.0, "mana": 0.0, "speed_pct": 5.0, "crit_pct": 0.0},
		"flavor": "Up there, sound carries wrong. These carry none at all.",
		"stackable": false, "effect": "",
		"ilvl": 32, "req_level": 32, "set_id": "", "value": 13,
		# BP 16.0: 6 + 25hp(5) + spd5 = 16. source: Whisper Passes world drop.
	},
	"transcub_penitents_robe": {
		"id": "transcub_penitents_robe", "name": "Transcub Penitent's Robe", "slot": "chest",
		"rarity": "rare", "icon": "pixel:transcub_penitents_robe",
		"stats": {"damage": 0.0, "armor": 10.0, "hp": 20.0, "mana": 60.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 1.5},
		"flavor": "'I only wanted to know what it said.' The altar is still warm.",
		"stackable": false, "effect": "",
		"ilvl": 36, "req_level": 36, "set_id": "", "value": 18,
		# BP 32.3: 10 + 20hp(4) + 60mana(12) + regen1.5(6) = 32. Mage/Necro line. source: Transcub Vale chain.
	},
	"blackglass_stiletto": {
		"id": "blackglass_stiletto", "name": "Blackglass Stiletto", "slot": "main_hand",
		"rarity": "epic", "icon": "pixel:blackglass_stiletto",
		"stats": {"damage": 30.0, "armor": 0.0, "hp": 0.0, "mana": 0.0, "speed_pct": 4.0, "crit_pct": 8.0},
		"flavor": "Strigoi glass takes an edge once. It has never needed a second.",
		"stackable": false, "effect": "",
		"ilvl": 36, "req_level": 36, "set_id": "", "value": 21,
		# BP 42.0: dmg 30 + spd4 + crit8 = 42. Rogue capstone. source: Blestem act boss.
	},
	"riddlers_blackglass_mask": {
		"id": "riddlers_blackglass_mask", "name": "Riddler's Blackglass Mask", "slot": "head",
		"rarity": "epic", "icon": "pixel:riddlers_blackglass_mask",
		"stats": {"damage": 3.0, "armor": 8.0, "hp": 60.0, "mana": 0.0, "speed_pct": 3.0, "crit_pct": 7.0},
		"flavor": "No eye-holes. You see fine. That is the riddle.",
		"stackable": false, "effect": "",
		"ilvl": 38, "req_level": 38, "set_id": "riddlers_blackglass", "value": 23,
		# BP 33.1: dmg3 + 8 + 60hp(12) + spd3 + crit7 = 33. source: Riddler's Quarter dungeon boss.
	},
	"riddlers_softstep_boots": {
		"id": "riddlers_softstep_boots", "name": "Riddler's Softstep Boots", "slot": "boots",
		"rarity": "epic", "icon": "pixel:riddlers_softstep_boots",
		"stats": {"damage": 0.0, "armor": 7.0, "hp": 60.0, "mana": 0.0, "speed_pct": 7.0, "crit_pct": 0.0},
		"flavor": "Twelve boot-prints faced a dead-end wall. These made the thirteenth.",
		"stackable": false, "effect": "",
		"ilvl": 38, "req_level": 38, "set_id": "riddlers_blackglass", "value": 23,
		# BP 26.5: 7 + 60hp(12) + spd7 = 26. source: Blestem epic quest chain.
	},
	"riddlers_obsidian_loop": {
		"id": "riddlers_obsidian_loop", "name": "Riddler's Obsidian Loop", "slot": "ring",
		"rarity": "epic", "icon": "pixel:riddlers_obsidian_loop",
		"stats": {"damage": 8.0, "armor": 0.0, "hp": 45.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 5.0},
		"flavor": "Worn on whichever finger you cannot feel today.",
		"stackable": false, "effect": "",
		"ilvl": 39, "req_level": 39, "set_id": "riddlers_blackglass", "value": 24,
		# BP 22.6: dmg8 + 45hp(9) + crit5 = 22. source: Lichenreach rare-elite (cave-strigoi lord).
	},
	"whisper_listeners_ear": {
		"id": "whisper_listeners_ear", "name": "Whisper-Listener's Ear", "slot": "trinket",
		"rarity": "rare", "icon": "pixel:whisper_listeners_ear",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 40.0, "mana": 10.0, "speed_pct": 4.0, "crit_pct": 5.0},
		"flavor": "Dried, pierced, strung. It still leans toward the passes.",
		"stackable": false, "effect": "",
		"ilvl": 34, "req_level": 34, "set_id": "", "value": 17,
		# BP 18.7: 40hp(8) + 10mana(2) + spd4 + crit5 = 19. source: listener watch-post drops.
	},

	# ==================================================================
	# ACT V — SOUTH / SANGEROASA (ilvl 40-50) — 7 items
	# ==================================================================
	"slagwalkers_band": {
		"id": "slagwalkers_band", "name": "Slag-Walker's Band", "slot": "ring",
		"rarity": "uncommon", "icon": "pixel:slagwalkers_band",
		"stats": {"damage": 0.0, "armor": 8.0, "hp": 45.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Pried from a hand that was still working. It kept working.",
		"stackable": false, "effect": "",
		"ilvl": 42, "req_level": 42, "set_id": "", "value": 18,
		# BP 17.1: 8 + 45hp(9) = 17. source: Ashvents world drop.
	},
	"ashvent_striders": {
		"id": "ashvent_striders", "name": "Ashvent Striders", "slot": "boots",
		"rarity": "rare", "icon": "pixel:ashvent_striders",
		"stats": {"damage": 0.0, "armor": 8.0, "hp": 55.0, "mana": 0.0, "speed_pct": 7.0, "crit_pct": 0.0},
		"flavor": "Soled in vent-leather. The warm ground reads them as its own.",
		"stackable": false, "effect": "",
		"ilvl": 44, "req_level": 44, "set_id": "", "value": 22,
		# BP 25.8: 8 + 55hp(11) + spd7 = 26. source: emberforged craft (vent reagents).
	},
	"giftfield_reapers_hook": {
		"id": "giftfield_reapers_hook", "name": "Gift-Field Reaper's Hook", "slot": "main_hand",
		"rarity": "rare", "icon": "pixel:giftfield_reapers_hook",
		"stats": {"damage": 33.0, "armor": 0.0, "hp": 20.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 4.0},
		"flavor": "The harvest is red and good. Do not ask the furrows why.",
		"stackable": false, "effect": "",
		"ilvl": 42, "req_level": 42, "set_id": "", "value": 21,
		# BP 41.2: dmg 33 + 20hp(4) + crit4 = 41. source: the Gift field-warden rare-elite.
	},
	"forgefathers_facemask": {
		"id": "forgefathers_facemask", "name": "Forgefather's Facemask", "slot": "head",
		"rarity": "epic", "icon": "pixel:forgefathers_facemask",
		"stats": {"damage": 6.0, "armor": 15.0, "hp": 90.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "When all the hammers stop for a count of three, it is listening.",
		"stackable": false, "effect": "",
		"ilvl": 46, "req_level": 46, "set_id": "forgefathers_toll", "value": 27,
		# BP 39.4: dmg6 + 15 + 90hp(18) = 39. source: Debt Pit dungeon boss.
	},
	"forgefathers_apron": {
		"id": "forgefathers_apron", "name": "Forgefather's Apron", "slot": "chest",
		"rarity": "epic", "icon": "pixel:forgefathers_apron",
		"stats": {"damage": 11.0, "armor": 18.0, "hp": 90.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Ledger line: one apron, issued. Marked 'collected'. Worn since.",
		"stackable": false, "effect": "",
		"ilvl": 46, "req_level": 46, "set_id": "forgefathers_toll", "value": 27,
		# BP 47.3: dmg11 + 18 + 90hp(18) = 47. source: Sangeroasa act-boss chain.
	},
	"forgefathers_pavise": {
		"id": "forgefathers_pavise", "name": "Forgefather's Pavise", "slot": "off_hand",
		"rarity": "epic", "icon": "pixel:forgefathers_pavise",
		"stats": {"damage": 0.0, "armor": 22.0, "hp": 75.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 0.0},
		"flavor": "Basaltfang plate. It remembers the Killing Floors. It approves of you.",
		"stackable": false, "effect": "",
		"ilvl": 47, "req_level": 47, "set_id": "forgefathers_toll", "value": 28,
		# BP 37.5: 22 + 75hp(15) = 37. source: Bloodroad convoy rare-elite.
	},
	"debt_pit_ledgerblade": {
		"id": "debt_pit_ledgerblade", "name": "Debt-Pit Ledgerblade", "slot": "main_hand",
		"rarity": "epic", "icon": "pixel:debt_pit_ledgerblade",
		"stats": {"damage": 40.0, "armor": 0.0, "hp": 35.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 8.0},
		"flavor": "Every notch on the spine is a name struck through.",
		"stackable": false, "effect": "",
		"ilvl": 48, "req_level": 48, "set_id": "", "value": 29,
		# BP 54.7: dmg 40 + 35hp(7) + crit8 = 55. source: Debt Pit end boss.
	},

	# ==================================================================
	# ACT VI — THE COLLECTOR'S COAST (ilvl 50-60) — 5 items
	# ==================================================================
	"coldharbor_greaves": {
		"id": "coldharbor_greaves", "name": "Coldharbor Greaves", "slot": "legs",
		"rarity": "rare", "icon": "pixel:coldharbor_greaves",
		"stats": {"damage": 2.0, "armor": 16.0, "hp": 100.0, "mana": 0.0, "speed_pct": 3.0, "crit_pct": 0.0},
		"flavor": "Black water beads off them and crawls back toward the docks.",
		"stackable": false, "effect": "",
		"ilvl": 54, "req_level": 54, "set_id": "", "value": 27,
		# BP 41.6: dmg2 + 16 + 100hp(20) + spd3 = 41. source: Coldharbor Deep boss.
	},
	"accordkeepers_grey_cowl": {
		"id": "accordkeepers_grey_cowl", "name": "Accordkeeper's Grey Cowl", "slot": "head",
		"rarity": "epic", "icon": "pixel:accordkeepers_grey_cowl",
		"stats": {"damage": 0.0, "armor": 12.0, "hp": 40.0, "mana": 90.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 2.0},
		"flavor": "Grey as ledger-paper. The stamp inside the hem is not the Archive's.",
		"stackable": false, "effect": "",
		"ilvl": 55, "req_level": 55, "set_id": "collectors_accord", "value": 33,
		# BP 46.5: 12 + 40hp(8) + 90mana(18) + regen2(8) = 46. source: the Archive dungeon boss.
	},
	"accordkeepers_treads": {
		"id": "accordkeepers_treads", "name": "Accordkeeper's Treads", "slot": "boots",
		"rarity": "epic", "icon": "pixel:accordkeepers_treads",
		"stats": {"damage": 0.0, "armor": 12.0, "hp": 80.0, "mana": 0.0, "speed_pct": 8.0, "crit_pct": 0.0},
		"flavor": "Gaslight never reaches the ground here. These have never been seen.",
		"stackable": false, "effect": "",
		"ilvl": 54, "req_level": 54, "set_id": "collectors_accord", "value": 32,
		# BP 36.6: 12 + 80hp(16) + spd8 = 36. source: Morven Reach epic chain.
	},
	"accordkeepers_seal": {
		"id": "accordkeepers_seal", "name": "Accordkeeper's Seal", "slot": "ring",
		"rarity": "epic", "icon": "pixel:accordkeepers_seal",
		"stats": {"damage": 0.0, "armor": 3.0, "hp": 40.0, "mana": 60.0, "speed_pct": 0.0, "crit_pct": 0.0, "mana_regen": 2.0},
		"flavor": "Stamped, un-stamped, stamped again. The third impression holds.",
		"stackable": false, "effect": "",
		"ilvl": 56, "req_level": 56, "set_id": "collectors_accord", "value": 33,
		# BP 31.6: 3 + 40hp(8) + 60mana(12) + regen2(8) = 31. source: Finalized Fields rare-elite.
	},
	"ledger_of_final_account": {
		"id": "ledger_of_final_account", "name": "The Ledger of Final Account", "slot": "main_hand",
		"rarity": "legendary", "icon": "pixel:ledger_of_final_account",
		"stats": {"damage": 55.0, "armor": 0.0, "hp": 70.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 10.0},
		"flavor": "Already collected. Why is it still walking?",
		"stackable": false, "effect": "final_account",
		"ilvl": 60, "req_level": 60, "set_id": "", "value": 60,
		# BP 79.2: dmg 55 + 70hp(14) + crit10 = 79. Effect "final_account"
		# (player.gd hook, per emberfall precedent): killing blows mark the
		# target "collected" — the next different enemy hit within 4 s takes
		# 20% of that kill's max_hp as bonus damage (the account carries over).
		# source: the Act VI / campaign-end questline capstone, from the Pit
		# over black water. Never drops.
	},
```

**Coverage audit:** 40 items. Slots: head 6, chest 4, legs 3, boots 7, main_hand 8,
off_hand 2 (+3 shipped), ring 6 (+3 shipped), trinket 3 (+1 shipped), none 1
(+2 shipped quest items). Rarities: poor 2, common 2, uncommon 6, rare 15,
epic 14, legendary 1 (+5 shipped legendaries anchor Act I). Brackets: every
6-level band from 1 to 60 has at least two entries. All six lore sets fully statted.

---

## 9. INTEGRATION CHECKLIST (for the implementation pass)

1. `items.gd` — add `poor` to `RARITY_COLORS`, recolor `common` white; add the
   `SETS` const (§5.3); append the 40 exemplar entries; annotate existing items
   with `ilvl/req_level/value` (no stat changes).
2. `icons_pixel.gd` — 40 new REGISTRY cells, PIL-verified (icon id == item id law).
3. `inventory.gd` — `stat_totals()` set-bonus extension (§5.3, ~10 lines);
   `req_level` gate belongs in BagUI/equip call-sites, not in `slot_accepts`
   (keep the static contract pure).
4. Loot window (owner mandate, separate deliverable) — hooks in
   `enemy.gd::_grant_kill_rewards()`; rolls per §1 tables; renders names through
   `Items.rarity_color()`; poor junk + materials + coin all appear as window lines.
5. `player.gd` — one new legendary effect id (`final_account`); `req_level` check
   on equip; tooltip lines for ilvl / set membership ("Vigil of the Twelve (2/3)").
6. Vendors — stock from §6/§7 (`value` * 4 buy, poor/common only + rotating uncommon).
7. `save_system.gd` — no change needed: items serialize as dicts already; the
   extension keys ride along.
