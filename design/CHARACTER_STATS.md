# RAVEN HOLLOW — CHARACTER STATS SYSTEM (Primaries 1–60)
WoW-Classic-style primary attributes for the seven classes: **Stamina, Strength,
Agility, Intellect, Spirit** — layered UNDER the existing derived stats, not
replacing them. Level cap 60.

**Grounded in (read before implementing):**
- `scripts/player.gd` — `_totals` cache (`Inventory.stat_totals()`), `_apply_equipment()`
  (max_hp = `_base_max_hp` + totals.hp, etc.), `_stat_damage()` (totals.damage +
  `level_damage_bonus`), crit rolls in `_deal_player_damage`/`_arm_ranged`, flat armor
  soak in `take_damage`, `apply_level_passives()` (+6% hp/mana compounding, +1 dmg).
- `scripts/class_defs.gd` — per-class `max_hp/max_mana/speed/hp_regen/mana_regen`.
- `scripts/inventory.gd` — `STAT_KEYS` (7 keys), `stat_totals()` (loops STAT_KEYS).
- `scripts/items.gd` — item dict shape; stats dict carries all keys.
- `scripts/xp_system.gd` — `grant_xp` / `apply_level_passives` / `reapply_level_bonuses`
  call order (level is `set()` **before** `_recompute_stats()` → our derivation is safe).
- `scripts/save_system.gd` — saves `xp/level/gold` + inventory dicts only; primaries
  derive from level, so **no schema change**.
- `scripts/character_sheet_ui.gd` — panel 200×264, stage 112×196 at (44,26), six-stat
  strip at y 228; right slot column ends at y 212 (trinket) — layout math in §8.
- `design/COMBAT_PACING.md` — the pacing contract this must honor:
  `PlayerRefDPS(L) = 25·1.046^(L−1)`, `PlayerRefEHP(L) = 120·1.055^(L−1)` (±15%).
- `design/ITEM_PROGRESSION.md` — BP budget `(2.4 + 0.62·ilvl)·SLOT_W·RARITY_M`,
  stat costs (damage 1.0, hp 0.2/pt, mana 0.2/pt, mana_regen 4.0, …).

---

## 1. Audit — the flat-stat model we are extending

What exists today, measured from the live code:

| Fact | Source | Consequence |
|---|---|---|
| Player power = class constants + 7 gear keys (`damage/armor/hp/mana/speed_pct/crit_pct/mana_regen`) | `inventory.gd STAT_KEYS`, `player.gd _apply_equipment` | No attribute layer: every class consumes gear identically; "+10 HP" reads the same to a mage and a warrior. |
| Level growth = `_base_max_hp *= 1.06`, `_base_max_mana *= 1.06`, `level_damage_bonus += 1.0` per level | `player.gd apply_level_passives` | At 60: warrior hp 140·1.06⁵⁹ ≈ **4 357** vs RefEHP 2 830 (+54% hot); mage mana ≈ 3 734 (mana never matters). The ×1.06 was demo-cap-10 tuning — it explodes at 60. |
| Flat +1 dmg/level is linear; RefDPS is exponential (1.046) | `xp_system.gd`, COMBAT_PACING §3 | Level damage overshoots early, undershoots late; COMBAT_PACING already assigns the remainder to gear + ability ranks. |
| No condition/attrition mechanic — debuffs are only `apply_slow`/`apply_root` on ENEMIES | `player.gd`, `enemy.gd` | Nothing in the world can weaken the player over time; the owner's "Infected"-style disease debuffs have no resource to bite. |
| Compounding level bonuses must be re-applied "exactly once per player instance" on load | `xp_system.gd reapply_level_bonuses` docstring | A documented footgun. Pure derivation from `level` (this doc) deletes it. |

**Key discovery (drives the whole design):** the shipped `class_defs.gd` numbers
decompose *exactly* into primary-attribute form with the engine's own defaults as
floors (`player.gd` defaults `hp 30.0`, `mana 20.0`):

```
max_hp    = 30 + 10 × Stamina₁        (all 7 classes, exact)
max_mana  = 20 + 10 × Intellect₁      (all 7 classes, exact)
mana_regen = 0.5 × Spirit₁            (all 7 classes, exact)
```

So at level 1 **nothing changes** for the player — migration is a re-labeling of
numbers they already have, plus a corrected growth curve to 60.

---

## 2. The five primaries — exact derived effects

Primaries are a layer BETWEEN sources (class base by level, gear, buffs) and the
derived values `player.gd` already consumes. The seven existing gear stats stay
as **secondary** stats and keep working unchanged; every formula below ends in a
field or read-site that already exists.

Constants referenced below live in `CharacterStats` (§6 full listing).

### 2.1 Stamina — the body

| Effect | Formula | Lands in |
|---|---|---|
| Health | `max_hp = 30.0 + 10.0 * prim.stamina + totals.hp` | `player.max_hp` (replaces `_base_max_hp + totals.hp` in `_apply_equipment`) |
| **Condition pool** | Debuffs like **Infected** drain Stamina points directly; each drained point = −10 max_hp live (hp clamps via the existing `hp = minf(hp, max_hp)`). Drain is capped at **40% of total Stamina** — attrition weakens, never executes. Drained points recover **out of combat only**, `1 pt / 3 s × spirit_ratio` (§5). | new `player._stam_drained`, subtracted inside `CharacterStats.effective_primaries` |

Stamina is the tank stat AND the disease/curse resource: a player who ignores the
Hungering's bites walks into the next camp at 60–70% of their health pool.

### 2.2 Strength — melee power

| Effect | Formula | Lands in |
|---|---|---|
| Attack Power | `ap = Σ AP_WEIGHTS[class][s] * prim[s]` — Strength carries weight 1.0 for warrior/paladin, partial for rogue/hunter/druid (§2.6) | — |
| Flat damage | `bonus_flat = max(0, ap − ap_at_L1_base) / 2.0` (2 AP = +1 damage on every ability hit) | `player._stat_damage()` (replaces `level_damage_bonus`) |

The `− ap_at_L1_base` baseline means the class ability tables (Cleave 12, Spark 9,
…) are defined as "your damage at level-1 physique" — L1 combat is byte-identical
to today. Gear/buff primaries at L1 DO add damage (they exceed the baseline).

### 2.3 Agility — precision and reflex

| Effect | Formula | Lands in |
|---|---|---|
| Attack Power | via `AP_WEIGHTS` (1.0-class stat for nobody; 0.8 for rogue/hunter) | `_stat_damage()` |
| Crit | `+1% crit per 20 Agility` for the five physical classes (§2.6 `CRIT_PRIMARY`) | the two crit-roll sites (`_deal_player_damage`, `_arm_ranged`) via new `_crit_chance()` |
| Armor | `+1 armor per 20 Agility` (flat soak, same as gear armor) | `take_damage` armor read via new `_armor_total()` |

### 2.4 Intellect — the thread

| Effect | Formula | Lands in |
|---|---|---|
| Mana | `max_mana = 20.0 + 10.0 * prim.intellect + totals.mana` | `player.max_mana` |
| Spell power | via `AP_WEIGHTS` (1.0 for mage/necromancer, 0.7 for druid) | `_stat_damage()` — damage is unified in this engine (flat adds to every ability), so "spell power" is the same pipe, gated by class weights |
| Crit (casters) | `+1% crit per 20 Intellect` for mage/necromancer | `_crit_chance()` |

### 2.5 Spirit — the well

| Effect | Formula | Lands in |
|---|---|---|
| Mana regen | `_mana_regen = 0.5 * prim.spirit + totals.mana_regen` | `player._mana_regen` (decomposes today's class values exactly) |
| HP regen | `_hp_regen = class_def.hp_regen * spirit_ratio` where `spirit_ratio = prim.spirit / base_spirit(class, level)` (1.0 ungeared — today's values exactly) | `player._hp_regen` |
| Downtime | Out-of-combat regen (COMBAT_PACING §9.2) scales: `ooc_hp = 0.05 * max_hp * spirit_ratio /s`; Stamina-drain recovery rate ×`spirit_ratio` | the §9.2 OOC tick |

Spirit is deliberately the slowest-growing primary (§3): it buys **shorter
breathers**, never in-combat throughput — fights stay winnable by the kit only.

### 2.6 Per-class conversion tables

```gdscript
## Which primaries convert to Attack Power, and at what weight (2 AP = +1 flat).
const AP_WEIGHTS := {
	"warrior":     {"strength": 1.0},
	"paladin":     {"strength": 1.0},
	"rogue":       {"strength": 0.4, "agility": 0.8},
	"rookwarden":  {"strength": 0.25, "agility": 0.8},
	"mage":        {"intellect": 1.0},
	"necromancer": {"intellect": 1.0},
	"druid":       {"strength": 0.7, "intellect": 0.7},
}
## Which primary feeds the crit roll (+1% per 20 points).
const CRIT_PRIMARY := {
	"warrior": "agility", "paladin": "agility", "rogue": "agility",
	"rookwarden": "agility", "druid": "agility",
	"mage": "intellect", "necromancer": "intellect",
}
```

**Speed is untouched by primaries.** `speed = _base_speed * (1 + totals.speed_pct/100)`
stays exactly as shipped — kiting power remains a scarce gear/buff resource
(ITEM_PROGRESSION soft-caps it at ~25% worn for good reason).

### 2.7 The full derivation (one screen)

```
prim[s]      = base_primary(class, s, level) + gear[s] + buff[s]     (s ∈ 5 primaries)
prim.stamina = max(prim.stamina · 0.6,  prim.stamina − stam_drained) (drain floor 60%)

max_hp       = 30 + 10·prim.stamina  + totals.hp
max_mana     = 20 + 10·prim.intellect + totals.mana
flat_damage  = max(0, ap(prim) − ap(L1 base)) / 2  + totals.damage
crit_pct     = prim[CRIT_PRIMARY]/20 + totals.crit_pct
armor        = prim.agility/20 + totals.armor
speed        = base_speed · (1 + totals.speed_pct/100)                (unchanged)
mana_regen   = 0.5·prim.spirit + totals.mana_regen
hp_regen     = class_def.hp_regen · (prim.spirit / base_spirit(class, level))
```

---

## 3. Class base arrays + growth to 60

### 3.1 Level-1 bases (decomposed from the shipped `class_defs.gd` — exact)

Order: `[stamina, strength, agility, intellect, spirit]`.

```gdscript
const BASE := {
	"warrior":     [11.0, 12.0,  6.0,  3.5,  8.0],
	"rogue":       [ 6.0,  7.0, 12.0,  3.0, 10.0],
	"mage":        [ 5.0,  4.0,  6.0, 10.0, 16.0],
	"paladin":     [ 9.0, 10.0,  6.0,  5.0, 10.0],
	"necromancer": [ 5.5,  4.0,  6.0,  9.0, 14.0],
	"rookwarden":  [ 6.5,  6.0, 11.0,  6.0, 12.0],
	"druid":       [ 7.0,  8.0,  7.0,  9.0, 13.0],
}
```

Decomposition proof (must hold — assert it in the smoke test):

| Class | 30+10·STA = max_hp | 20+10·INT = max_mana | 0.5·SPI = mana_regen |
|---|---|---|---|
| warrior | 30+110 = **140** ✓ | 20+35 = **55** ✓ | **4.0** ✓ |
| rogue | 30+60 = **90** ✓ | 20+30 = **50** ✓ | **5.0** ✓ |
| mage | 30+50 = **80** ✓ | 20+100 = **120** ✓ | **8.0** ✓ |
| paladin | 30+90 = **120** ✓ | 20+50 = **70** ✓ | **5.0** ✓ |
| necromancer | 30+55 = **85** ✓ | 20+90 = **110** ✓ | **7.0** ✓ |
| rookwarden | 30+65 = **95** ✓ | 20+60 = **80** ✓ | **6.0** ✓ |
| druid | 30+70 = **100** ✓ | 20+90 = **110** ✓ | **6.5** ✓ |

Strength and Agility have no shipped analogue (free authoring): tuned for class
fantasy + the AP math in §10's audit.

### 3.2 Growth constants (per stat, shared by all classes)

Multiplicative per-level growth preserves class ratios at every level (the
warrior is always 140/80 = 1.75× the mage's health) and matches the compounding
style the codebase already uses (`×1.06`), re-anchored to the pacing contract:

```gdscript
const GROWTH := {
	"stamina":   1.052,  # EHP contract: RefEHP grows 1.055 incl. armor + gear hp
	"strength":  1.046,  # DPS contract: RefDPS grows exactly 1.046
	"agility":   1.046,  # same lane as strength
	"intellect": 1.040,  # mana pools grow slower than throughput (mana must matter)
	"spirit":    1.025,  # downtime-only stat: deliberately the flattest curve
}
```

### 3.3 The 7×60 generation formula (the law — tables are never hand-authored)

```gdscript
## Primary value for a class at a level, BEFORE gear/buffs/drain.
## This one line IS the growth table; §3.4 is generated from it.
static func base_primary(class_id: String, stat: String, level: int) -> float:
	var arr: Array = BASE.get(class_id, BASE["warrior"])
	var i: int = PRIMARIES.find(stat)
	return float(arr[i]) * pow(float(GROWTH[stat]), float(clampi(level, 1, 60) - 1))

## Full 7-class x 5-stat x 60-level table, generated on demand
## (debug dumps, balance audits, the tests/ stats harness).
static func growth_table() -> Dictionary:
	var out: Dictionary = {}
	for cid: String in BASE.keys():
		var per_stat: Dictionary = {}
		for s: String in PRIMARIES:
			var col := PackedFloat32Array()
			col.resize(60)
			for l: int in range(1, 61):
				col[l - 1] = base_primary(cid, s, l)
			per_stat[s] = col
		out[cid] = per_stat
	return out
```

Display rule: the character sheet shows `roundi(value)`; all math stays float.

### 3.4 Anchor-level reference (generated from §3.3 — sanity print, not source)

Growth multipliers at the anchors:

| L | ×STA (1.052) | ×STR/AGI (1.046) | ×INT (1.040) | ×SPI (1.025) |
|---|---|---|---|---|
| 1 | 1.000 | 1.000 | 1.000 | 1.000 |
| 10 | 1.578 | 1.499 | 1.423 | 1.249 |
| 20 | 2.620 | 2.350 | 2.107 | 1.599 |
| 30 | 4.350 | 3.685 | 3.119 | 2.046 |
| 40 | 7.222 | 5.778 | 4.616 | 2.620 |
| 50 | 11.99 | 9.060 | 6.833 | 3.353 |
| 60 | 19.91 | 14.21 | 10.12 | 4.292 |

Per class at L1 / L20 / L40 / L60 (STA·STR·AGI·INT·SPI, rounded):

| Class | L1 | L20 | L40 | L60 |
|---|---|---|---|---|
| warrior | 11·12·6·3.5·8 | 29·28·14·7·13 | 79·69·35·16·21 | 219·171·85·35·34 |
| rogue | 6·7·12·3·10 | 16·16·28·6·16 | 43·40·69·14·26 | 119·99·171·30·43 |
| mage | 5·4·6·10·16 | 13·9·14·21·26 | 36·23·35·46·42 | 100·57·85·101·69 |
| paladin | 9·10·6·5·10 | 24·24·14·11·16 | 65·58·35·23·26 | 179·142·85·51·43 |
| necromancer | 5.5·4·6·9·14 | 14·9·14·19·22 | 40·23·35·42·37 | 109·57·85·91·60 |
| rookwarden | 6.5·6·11·6·12 | 17·14·26·13·19 | 47·35·64·28·31 | 129·85·156·61·52 |
| druid | 7·8·7·9·13 | 18·19·16·19·21 | 51·46·40·42·34 | 139·114·99·91·56 |

Spot checks at 60 (no gear): warrior hp 30+2 190 = **2 220**; mage hp **1 025**
(0.46× warrior — the L1 ratio held); mage mana 20+1 010 = **1 030** (vs 3 734
under the old ×1.06 — mana is scarce again); rogue crit from agility
171/20 ≈ **8.5%** before gear.

---

## 4. How items and buffs feed primaries

### 4.1 Items — one-const extension, zero logic changes

Primaries ride the SAME `stats` dict every item already carries.
`Inventory.stat_totals()` loops `STAT_KEYS`, so the entire gear pipe is:

```gdscript
# inventory.gd — STAT_KEYS gains the five primaries (stat_totals() and the
# defaults dict get the same five keys; nothing else in the file changes):
const STAT_KEYS: Array[String] = [
	"damage", "armor", "hp", "mana", "speed_pct", "crit_pct", "mana_regen",
	"stamina", "strength", "agility", "intellect", "spirit",
]
```

Items may mix primaries and secondaries freely ("+4 Stamina, +3 Armor" — the
classic statline shape). `hp`/`mana` lines remain legal and stack additively
AFTER the primary conversion (see §2.7) — **no shipped item changes**.

### 4.2 ITEM_PROGRESSION §2.3 cost-table extension (budget points per point)

Priced from what each point actually converts to in `player.gd`, so the §2
budget formula keeps balancing itself:

| Stat | Cost | Derivation |
|---|---|---|
| `stamina` 1.0 | **2.0** | = 10 hp × 0.2/hp, exactly. Consistent by construction. |
| `strength` 1.0 | **0.6** | 0.5 flat damage for a weight-1.0 class (= 0.5) + premium rounding. |
| `agility` 1.0 | **0.7** | ≤0.4 flat (0.8-weight classes) + 0.05 crit + 0.05 armor. |
| `intellect` 1.0 | **2.2** | 10 mana (2.0) + caster AP/crit margin (0.2). |
| `spirit` 1.0 | **2.0** | 0.5 mana_regen/s (mana_regen is priced 4.0 per 1/s) — **rare+ only, per-item cap 8**, same gate as `mana_regen` (sustained-casting is legendary-line territory). |

Authoring guidance: primaries appear from **uncommon** up (poor/common stay on
raw hp/armor/damage — "honest gear"); a class-slanted item spends ≥60% of budget
in the class's primary line per the ITEM_PROGRESSION §4 affinity table, which
maps 1:1 onto primaries: Warrior STR/STA · Paladin STA/STR · Rogue AGI ·
Mage INT/SPI · Necromancer INT/STA · Hunter AGI · Druid STA/INT.

New Draconia suffixes for primary statlines (extends §5.2 of ITEM_PROGRESSION):

| Suffix | Statline (budget share) | Affinity |
|---|---|---|
| *of the Gravedigger* | strength 50% / stamina 50% | Warrior, Paladin |
| *of the Rookwatch* | agility 70% / spirit 30% (rare+) | Rogue, Hunter |
| *of the Violet Flame* | intellect 70% / spirit 30% (rare+) | Mage, Necromancer |
| *of the Old Roads* | stamina 60% / spirit 40% (rare+) | Druid, anyone leveling |

Budget-verified exemplars (exact `items.gd` shape, §2 extension keys included):

```gdscript
	"bearhide_jerkin": {
		"id": "bearhide_jerkin", "name": "Bearhide Jerkin", "slot": "chest",
		"rarity": "uncommon", "icon": "pixel:bearhide_jerkin",
		"stats": {"damage": 0.0, "armor": 3.0, "hp": 0.0, "mana": 0.0,
			"speed_pct": 0.0, "crit_pct": 0.0,
			"stamina": 4.0, "strength": 2.0},
		"flavor": "The bear minded. Briefly.",
		"stackable": false, "effect": "",
		"ilvl": 14, "req_level": 14, "set_id": "", "value": 6,
		# BP 12.0: armor 3 + sta 4(8.0) + str 2(1.2) = 12.2. Warrior/Paladin slant.
	},
	"rookwatch_signet": {
		"id": "rookwatch_signet", "name": "Rookwatch Signet", "slot": "ring",
		"rarity": "rare", "icon": "pixel:rookwatch_signet",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 0.0,
			"speed_pct": 0.0, "crit_pct": 1.0,
			"agility": 8.0, "spirit": 2.0},
		"flavor": "The rooks countersign nothing. They remember everything.",
		"stackable": false, "effect": "",
		"ilvl": 20, "req_level": 20, "set_id": "", "value": 10,
		# BP 10.7: agi 8(5.6) + spi 2(4.0) + crit 1 = 10.6. Rogue/Hunter slant.
	},
	"violet_novices_cowl": {
		"id": "violet_novices_cowl", "name": "Violet Novice's Cowl", "slot": "head",
		"rarity": "uncommon", "icon": "pixel:violet_novices_cowl",
		"stats": {"damage": 0.0, "armor": 0.0, "hp": 0.0, "mana": 10.0,
			"speed_pct": 0.0, "crit_pct": 0.0,
			"intellect": 3.0},
		"flavor": "Sized for a head that still fits through doors.",
		"stackable": false, "effect": "",
		"ilvl": 12, "req_level": 12, "set_id": "", "value": 5,
		# BP 8.9: int 3(6.6) + mana 10(2.0) = 8.6. Mage/Necromancer slant.
	},
```

### 4.3 Buffs — `params.primaries`, same layering pattern as `fx`/`fx_tint`

Buff abilities gain one optional params key (unknown keys are already ignored by
every other consumer — the `crafting.gd` extension-key precedent):

```gdscript
# class_defs.gd — e.g. Bear Form gains the tank-attribute identity:
"params": { "duration": 8.0, "damage_mult": 1.4, "speed_mult": 1.1,
	"absorb": 35.0, "primaries": {"stamina": 25.0}, ... }
```

```gdscript
# player.gd — _do_buff(), after the existing _absorb line:
	var prims_v: Variant = params.get("primaries", {})
	if prims_v is Dictionary and not (prims_v as Dictionary).is_empty():
		_buff_prims = (prims_v as Dictionary).duplicate()
		_apply_equipment()   # re-derive: +25 sta = +250 max_hp for the duration

# player.gd — _tick_timers(), inside the `_buff_left <= 0.0` expiry branch
# (next to _speed_mult/_damage_mult resets), and in _respawn():
	if not _buff_prims.is_empty():
		_buff_prims = {}
		_apply_equipment()   # hp = minf(hp, max_hp) clamps — WoW behavior exactly
```

Buff primaries are FLAT points (never percentages), so they stack with gear
through the one `effective_primaries` sum and stay printable on the sheet.

---

## 5. Stamina as the condition resource — Infected and friends

The attrition layer the flat model couldn't express. All numbers are **fractions
of BASE Stamina** so drains stay meaningful at 60 without per-level tables.

### 5.1 Rules

1. A condition drains Stamina points over time or instantly. Each drained point
   is −10 max_hp, applied live through `_apply_equipment` (current hp clamps
   down; it is **never reduced below the new max by more than the drain** — the
   existing `hp = minf(hp, max_hp)` line does this for free).
2. **Drain floor: 60% of total Stamina.** Conditions weaken; only hits kill.
3. Drained Stamina recovers **out of combat only** (COMBAT_PACING §9.2's 5-second
   no-damage-dealt-or-taken timer): `1 pt / 3 s × spirit_ratio`. Spirit is the
   recover-from-the-marsh stat.
4. Cures: the hearth/forge rest interaction (instant full restore), a
   `consumable` item line (`"effect": "cure_condition"` — Crafting hook), and
   later priest NPCs. Death also clears (`_respawn` resets `_stam_drained`).
5. UI: sheet STA reads `eff/total` in sickly green (§8.4); HUD hp-bar end-cap
   darkens over the drained fraction (optional polish, hud.gd).

### 5.2 Condition catalog v1 (wired to COMBAT_PACING §5 archetypes)

| Condition | Source (archetype) | Drain | Telegraph |
|---|---|---|---|
| **Infected** | swarm bites (Starving Dogs, the Hungering) — 15% per landed hit, 1 stack max | 1.6% of base STA every 2 s for 10 s (total **8%**) | green drip particles on the player, sickly STA readout |
| **Grave-Chill** | brute heavy swing (Thread-Touched Dead, §5.1 heavy telegraph) | instant **5%** of base STA | frost puff + blue flash |
| **Withering** | rare/elite casters (the Stonewatcher signature) | **12%** over 6 s, ignores the 1-stack rule | purple wisp spiral |

At L20 (druid, base STA 18.3): Infected = −1.5 STA ≈ −15 max_hp of a 213+gear
pool — noticeable, not lethal. Three unanswered swarm fights before resting
stack to the 40% cap: pool down ~73 hp. That is the "cure or retreat" decision.

### 5.3 Player API (exact)

```gdscript
# player.gd — new fields:
var _stam_drained: float = 0.0     # points currently drained (NOT saved; transient)
var _buff_prims: Dictionary = {}   # active buff primaries ({} = none)
var _ooc_t: float = 999.0          # seconds since last damage dealt/taken (§9.2 timer)

## Condition hook: enemies/zones drain Stamina points. Clamped so effective
## Stamina never falls below 60% of the undrained total (rule 2).
func drain_stamina(points: float, _source: Node = null) -> void:
	if _dead or points <= 0.0:
		return
	var full: float = CharacterStats.base_primary(_class_id(), "stamina", level) \
			+ float(_totals.get("stamina", 0.0)) + float(_buff_prims.get("stamina", 0.0))
	_stam_drained = minf(_stam_drained + points, full * CharacterStats.DRAIN_CAP_FRAC)
	_apply_equipment()

## Fraction-of-base convenience for enemy.gd (condition catalog uses fractions).
func drain_stamina_frac(frac: float, source: Node = null) -> void:
	drain_stamina(frac * CharacterStats.base_primary(_class_id(), "stamina", level), source)

func _class_id() -> String:
	return str(class_def.get("id", "warrior"))

# _tick_timers(), after the regen lines — recovery rides the OOC timer:
	if _stam_drained > 0.0 and _ooc_t >= 5.0:
		var ratio: float = CharacterStats.spirit_ratio(_class_id(), level, _prim)
		_stam_drained = maxf(0.0, _stam_drained - delta * ratio / CharacterStats.DRAIN_RECOVER_SECS)
		if fmod(_sway_t, 0.5) < delta:   # cheap throttle: re-derive twice a second
			_apply_equipment()
```

(`_ooc_t` is reset to 0 in `take_damage` and `_deal_player_damage` and
accumulates in `_tick_timers` — it is the same timer COMBAT_PACING §9.2 needs;
implement once, share.)

---

## 6. `scripts/character_stats.gd` — the full static class (exact)

Pure data + math, no scene code — the `class_defs.gd`/`xp_system.gd` house style.

```gdscript
class_name CharacterStats
## WoW-Classic primary attributes for Raven Hollow (design/CHARACTER_STATS.md).
## Stamina / Strength / Agility / Intellect / Spirit: base arrays decomposed
## EXACTLY from class_defs.gd (30 + 10*STA == max_hp, 20 + 10*INT == max_mana,
## 0.5*SPI == mana_regen — asserted by the smoke test), grown multiplicatively
## per level, summed with gear (Inventory.stat_totals) and buff primaries, then
## converted to the derived values player.gd consumes. Pure statics, no scenes.

const PRIMARIES: Array[String] = ["stamina", "strength", "agility", "intellect", "spirit"]

const HP_FLOOR: float = 30.0            # player.gd's own default hp
const MANA_FLOOR: float = 20.0          # player.gd's own default mana
const HP_PER_STAMINA: float = 10.0
const MANA_PER_INTELLECT: float = 10.0
const AP_PER_FLAT_DAMAGE: float = 2.0   # 2 attack power = +1 flat damage
const CRIT_DIVISOR: float = 20.0        # 20 crit-primary points = +1% crit
const ARMOR_PER_AGILITY: float = 20.0   # 20 agility = +1 flat armor soak
const MANA_REGEN_PER_SPIRIT: float = 0.5
const DRAIN_CAP_FRAC: float = 0.4       # conditions stop at 40% of stamina
const DRAIN_RECOVER_SECS: float = 3.0   # OOC: 1 drained point back per 3 s (x spirit_ratio)
const MAX_LEVEL: int = 60

## L1 bases [stamina, strength, agility, intellect, spirit] — see the
## decomposition table in CHARACTER_STATS.md §3.1. Class hp/mana/mana_regen in
## class_defs.gd are DERIVED from these at L1 and must stay in lockstep.
const BASE := {
	"warrior":     [11.0, 12.0,  6.0,  3.5,  8.0],
	"rogue":       [ 6.0,  7.0, 12.0,  3.0, 10.0],
	"mage":        [ 5.0,  4.0,  6.0, 10.0, 16.0],
	"paladin":     [ 9.0, 10.0,  6.0,  5.0, 10.0],
	"necromancer": [ 5.5,  4.0,  6.0,  9.0, 14.0],
	"rookwarden":  [ 6.5,  6.0, 11.0,  6.0, 12.0],
	"druid":       [ 7.0,  8.0,  7.0,  9.0, 13.0],
}

## Per-level multiplicative growth per stat (shared by all classes; class
## identity lives in BASE so class ratios hold at every level).
const GROWTH := {
	"stamina": 1.052, "strength": 1.046, "agility": 1.046,
	"intellect": 1.040, "spirit": 1.025,
}

## primary -> attack-power weight per class (2 AP = +1 flat damage on every hit).
const AP_WEIGHTS := {
	"warrior":     {"strength": 1.0},
	"paladin":     {"strength": 1.0},
	"rogue":       {"strength": 0.4, "agility": 0.8},
	"rookwarden":  {"strength": 0.25, "agility": 0.8},
	"mage":        {"intellect": 1.0},
	"necromancer": {"intellect": 1.0},
	"druid":       {"strength": 0.7, "intellect": 0.7},
}

## Which primary feeds the crit roll (+1% per CRIT_DIVISOR points).
const CRIT_PRIMARY := {
	"warrior": "agility", "paladin": "agility", "rogue": "agility",
	"rookwarden": "agility", "druid": "agility",
	"mage": "intellect", "necromancer": "intellect",
}


## Class base for one stat at a level (no gear/buffs). THE growth formula.
static func base_primary(class_id: String, stat: String, level: int) -> float:
	var arr: Array = BASE.get(class_id, BASE["warrior"])
	var i: int = PRIMARIES.find(stat)
	if i < 0:
		return 0.0
	return float(arr[i]) * pow(float(GROWTH[stat]), float(clampi(level, 1, MAX_LEVEL) - 1))


static func base_primaries(class_id: String, level: int) -> Dictionary:
	var out: Dictionary = {}
	for s: String in PRIMARIES:
		out[s] = base_primary(class_id, s, level)
	return out


## Effective primaries: class base + gear totals + buff points, stamina reduced
## by the current condition drain (floored at (1 - DRAIN_CAP_FRAC) of total).
## `gear` is Inventory.stat_totals() (unknown keys read 0.0 — safe pre-migration).
static func effective_primaries(class_id: String, level: int, gear: Dictionary,
		buffs: Dictionary, stam_drained: float) -> Dictionary:
	var out: Dictionary = {}
	for s: String in PRIMARIES:
		out[s] = base_primary(class_id, s, level) \
				+ float(gear.get(s, 0.0)) + float(buffs.get(s, 0.0))
	var sta: float = float(out["stamina"])
	out["stamina"] = maxf(sta * (1.0 - DRAIN_CAP_FRAC), sta - maxf(0.0, stam_drained))
	return out


static func attack_power(class_id: String, prim: Dictionary) -> float:
	var ap: float = 0.0
	var weights: Dictionary = AP_WEIGHTS.get(class_id, AP_WEIGHTS["warrior"])
	for s: String in weights:
		ap += float(weights[s]) * float(prim.get(s, 0.0))
	return ap


## Flat damage from primaries: AP ABOVE the class's level-1 baseline (the
## ability damage tables already price in L1 physique), 2 AP = +1 damage.
static func bonus_flat_damage(class_id: String, prim: Dictionary) -> float:
	var ap0: float = attack_power(class_id, base_primaries(class_id, 1))
	return maxf(0.0, attack_power(class_id, prim) - ap0) / AP_PER_FLAT_DAMAGE


static func crit_from_primaries(class_id: String, prim: Dictionary) -> float:
	var key: String = str(CRIT_PRIMARY.get(class_id, "agility"))
	return float(prim.get(key, 0.0)) / CRIT_DIVISOR


static func armor_from_primaries(prim: Dictionary) -> float:
	return floorf(float(prim.get("agility", 0.0)) / ARMOR_PER_AGILITY)


## Geared-spirit / base-spirit: 1.0 ungeared. Scales hp_regen, OOC regen and
## stamina-drain recovery (Spirit's whole identity is shorter downtime).
static func spirit_ratio(class_id: String, level: int, prim: Dictionary) -> float:
	var base: float = base_primary(class_id, "spirit", level)
	if base <= 0.0:
		return 1.0
	return maxf(0.25, float(prim.get("spirit", base)) / base)


## Full 7x60 table, generated (never hand-authored) — audits + debug dumps.
static func growth_table() -> Dictionary:
	var out: Dictionary = {}
	for cid: String in BASE.keys():
		var per_stat: Dictionary = {}
		for s: String in PRIMARIES:
			var col := PackedFloat32Array()
			col.resize(MAX_LEVEL)
			for l: int in range(1, MAX_LEVEL + 1):
				col[l - 1] = base_primary(cid, s, l)
			per_stat[s] = col
		out[cid] = per_stat
	return out
```

---

## 7. `player.gd` integration — exact patches

New fields (next to `_totals`): `_prim: Dictionary = {}`, `_stam_drained`,
`_buff_prims`, `_ooc_t` (§5.3). Then four surgical edits:

### 7.1 `_apply_equipment()` — the derivation swap

```gdscript
func _apply_equipment() -> void:
	## Cache gear totals, derive effective primaries, then every derived value.
	_totals = inventory.stat_totals() if inventory != null else {}
	_prim = CharacterStats.effective_primaries(
			_class_id(), level, _totals, _buff_prims, _stam_drained)
	max_hp = CharacterStats.HP_FLOOR \
			+ CharacterStats.HP_PER_STAMINA * float(_prim.get("stamina", 0.0)) \
			+ float(_totals.get("hp", 0.0))
	hp = minf(hp, max_hp)
	max_mana = CharacterStats.MANA_FLOOR \
			+ CharacterStats.MANA_PER_INTELLECT * float(_prim.get("intellect", 0.0)) \
			+ float(_totals.get("mana", 0.0))
	mana = minf(mana, max_mana)
	speed = _base_speed * (1.0 + float(_totals.get("speed_pct", 0.0)) / 100.0)
	_mana_regen = CharacterStats.MANA_REGEN_PER_SPIRIT * float(_prim.get("spirit", 0.0)) \
			+ float(_totals.get("mana_regen", 0.0))
	_hp_regen = float(class_def.get("hp_regen", 0.0)) \
			* CharacterStats.spirit_ratio(_class_id(), level, _prim)
	_refresh_weapon()
	_refresh_shield()
	_refresh_chest_tint()
```

`_base_max_hp/_base_max_mana/_base_mana_regen` become dead for hp/mana/regen
(keep the fields one release for save-compat inertness; `_base_speed` stays live).

### 7.2 `_stat_damage()` + the crit/armor read sites

```gdscript
func _stat_damage() -> float:
	## Gear flat damage + attack power from primaries (replaces level_damage_bonus).
	return float(_totals.get("damage", 0.0)) \
			+ CharacterStats.bonus_flat_damage(_class_id(), _prim)

func _crit_chance() -> float:
	return float(_totals.get("crit_pct", 0.0)) \
			+ CharacterStats.crit_from_primaries(_class_id(), _prim)

func _armor_total() -> float:
	return float(_totals.get("armor", 0.0)) + CharacterStats.armor_from_primaries(_prim)
```

- In `_deal_player_damage` and `_arm_ranged`: replace both
  `randf() * 100.0 < float(_totals.get("crit_pct", 0.0))` with
  `randf() * 100.0 < _crit_chance()`.
- In `take_damage`: replace `var armor: float = float(_totals.get("armor", 0.0))`
  with `var armor: float = _armor_total()`.

### 7.3 Level hooks — XPSystem needs **zero changes**

`XPSystem.grant_xp` sets `player.level` **before** calling `_recompute_stats`
(which calls `_apply_equipment`), and `SaveSystem.apply_player_state` sets
`level` before `reapply_level_bonuses` — pure derivation from `level` slots
straight in:

```gdscript
func apply_level_passives() -> void:
	## Primaries derive from `level` inside _apply_equipment (CHARACTER_STATS.md);
	## nothing compounds anymore. Kept as an intentional no-op so XPSystem's
	## preferred hook keeps firing (contract §6) without the fallback mutating
	## _base_max_hp. The old +6%/level and level_damage_bonus are retired.
	pass
```

`level_damage_bonus`: keep the field declared at `0.0` (SaveSystem never
serialized it; XPSystem's fallback never runs because the method above exists).
Delete after one release. The docstring footgun in `reapply_level_bonuses`
("call exactly once — bonuses compound") is now moot: the loop no-ops.

### 7.4 UI feed

```gdscript
## Character-sheet feed (CharacterSheetUI reads this instead of raw stat_totals).
func stat_sheet() -> Dictionary:
	var base: Dictionary = CharacterStats.base_primaries(_class_id(), level)
	return {
		"primaries": _prim.duplicate(),      # effective (gear+buffs, drain applied)
		"base": base,                        # class-at-level (tooltip breakdown)
		"drained": _stam_drained,
		"derived": {
			"damage": _stat_damage(), "armor": _armor_total(),
			"max_hp": max_hp, "max_mana": max_mana,
			"crit_pct": _crit_chance(),
			"speed_pct": float(_totals.get("speed_pct", 0.0)),
			"hp_regen": _hp_regen, "mana_regen": _mana_regen,
		},
	}
```

---

## 8. Character-sheet UI additions (`character_sheet_ui.gd`)

The panel is 200×264 with the stage at (44,26) 112×196 and the six-stat strip at
y 228. The right slot column's trinket box ends at y 212 (label to ~222), so a
full-width second strip cannot sit above y 228. Layout that fits:

### 8.1 Geometry changes (exact)

| Constant | Old | New | Why |
|---|---|---|---|
| `STAGE_H` | 196.0 | **168.0** | frees a 24 px band under the stage |
| `_glow.size` | (STAGE_W−8, 140) | (STAGE_W−8, **116**) | keep the glow inside the shorter stage |
| `_glow.position` | (4, 28) | (4, **24**) | recentre on the preview |
| new `PRIM_Y` | — | **200.0** | primaries strip top |
| new `PRIM_H` | — | **24.0** | 5 columns of 22.4 px within the stage span |

The primaries strip spans **x = STAGE_X (44) … STAGE_X+STAGE_W (156)** — stage
width only, so it never collides with the left (bottom y 208 incl. labels) or
right (bottom y 222) slot columns. The XP bar stays at `STAGE_H − 14` inside the
stage and moves up with it automatically. The derived strip at y 228 is untouched.

### 8.2 `_build_primaries_strip()` (same construction style as `_build_stats_strip`)

```gdscript
const PRIM_KEYS: Array[String] = ["stamina", "strength", "agility", "intellect", "spirit"]
const PRIM_LABELS: Array[String] = ["STA", "STR", "AGI", "INT", "SPI"]
const PRIM_COLORS: Array[Color] = [
	Color(0.82, 0.55, 0.30),  # stamina — hearth amber
	Color(0.75, 0.30, 0.22),  # strength — ember red
	Color(0.45, 0.70, 0.40),  # agility — moss green
	Color(0.45, 0.55, 0.85),  # intellect — thread blue
	Color(0.70, 0.65, 0.85),  # spirit — pale violet
]
const DRAIN_GREEN := Color(0.55, 0.75, 0.35)  # Infected/sickly readout

var _prim_values: Array[Label] = []

func _build_primaries_strip() -> void:
	var strip := Panel.new()
	strip.name = "PrimariesStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(STAGE_X, PRIM_Y)
	strip.size = Vector2(STAGE_W, PRIM_H)
	# StyleBoxFlat identical to the stats strip (STRIP_BG / SLOT_BORDER / 1 px).
	_panel.add_child(strip)
	var col_w: float = STAGE_W / 5.0
	for i in range(PRIM_KEYS.size()):
		var x: float = roundf(float(i) * col_w)
		# glyph (4 px diamond, PRIM_COLORS[i]) + name label (font 6, GOLD) +
		# value label (font 8, PARCHMENT) — exact _build_stats_strip pattern,
		# name at y 1, value at y 11, column width col_w.
		# Hover: a Control overlay per column connects mouse_entered ->
		# _on_prim_hover(i) / mouse_exited -> _on_prim_unhover (tooltip §8.3).
		...
		_prim_values.append(value_label)
```

Call it from `_ready()` between `_build_stage()` and `_build_stats_strip()`.

### 8.3 Refresh + tooltips

`_refresh_stats()` now reads the PLAYER's derived truth, not raw gear totals
(the old strip silently lied once primaries convert into hp/damage/crit):

```gdscript
func _refresh_stats() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("stat_sheet"):
		return  # pre-migration fallback: keep the old totals path
	var sheet: Dictionary = player.call("stat_sheet")
	var prim: Dictionary = sheet.get("primaries", {})
	var base: Dictionary = sheet.get("base", {})
	var drained: float = float(sheet.get("drained", 0.0))
	for i in range(PRIM_KEYS.size()):
		var key: String = PRIM_KEYS[i]
		var eff: int = roundi(float(prim.get(key, 0.0)))
		var lbl: Label = _prim_values[i]
		if key == "stamina" and drained > 0.05:
			var full: int = roundi(float(prim.get(key, 0.0)) + drained)
			lbl.text = "%d/%d" % [eff, full]          # e.g. "26/29" — Infected
			lbl.add_theme_color_override("font_color", DRAIN_GREEN)
		else:
			lbl.text = str(eff)
			var geared: bool = eff > roundi(float(base.get(key, 0.0)))
			lbl.add_theme_color_override("font_color",
					Color(0.55, 0.85, 0.55) if geared else PARCHMENT)  # green = gear/buffs
	var d: Dictionary = sheet.get("derived", {})
	# Derived strip: DMG _stat_damage / ARM armor_total / HP max_hp / MP max_mana /
	# SPD speed_pct / CRIT crit_pct — final values, "%d" ("+%d%%" for the _pct pair).
```

Hover tooltip per primary column (reuse the ItemTooltip panel styling — dark
box, Alagard, parchment lines; a plain 3-line Label panel is enough, no item
dict): line 1 name in the column color, line 2 `"29 (23 base + 6 gear)"`, line 3
the conversion — STA `"+290 Health"` · STR/AGI/INT `"+14 Attack Power"` (plus
`"+2.1% Crit"` on the class's `CRIT_PRIMARY`, `"+8 Armor"` on Agility) · SPI
`"+21.5 Mana Regen · rest recovery x1.3"`. When drained, STA appends
`"Infected: -3 Stamina (recovers while rested)"` in `DRAIN_GREEN`.

### 8.4 Tooltip rows for items (`item_tooltip.gd`)

`STAT_ROWS` gains five entries after `crit_pct` (display order: primaries last,
the WoW statline shape):

```gdscript
	["stamina", "Stamina", false], ["strength", "Strength", false],
	["agility", "Agility", false], ["intellect", "Intellect", false],
	["spirit", "Spirit", false],
```

---

## 9. Migration from the flat stats (ordered, each step shippable)

1. **Add `scripts/character_stats.gd`** (§6) + smoke-test assertions: for all 7
   classes `HP_FLOOR + HP_PER_STAMINA*BASE[c][0] == class_defs.max_hp`,
   `MANA_FLOOR + MANA_PER_INTELLECT*BASE[c][3] == max_mana`,
   `MANA_REGEN_PER_SPIRIT*BASE[c][4] == mana_regen` (§3.1 table). Also assert
   `bonus_flat_damage(c, base_primaries(c,1)) == 0.0` — L1 combat unchanged.
2. **`inventory.gd`**: extend `STAT_KEYS` + the `stat_totals()` defaults dict
   with the five primaries (§4.1). Additive — old items read 0.0.
3. **`player.gd`**: §7 patches (fields, `_apply_equipment`, `_stat_damage`,
   `_crit_chance`/`_armor_total` read-site swaps, no-op `apply_level_passives`,
   `drain_stamina`, `_do_buff` primaries, `stat_sheet`). `_respawn()` additionally
   resets `_stam_drained = 0.0` and `_buff_prims = {}` before `_apply_equipment()`.
4. **`xp_system.gd` / `save_system.gd`: no changes.** Verified against the code:
   `grant_xp` sets `level` before `_recompute_stats`; `apply_player_state` sets
   `level` before `reapply_level_bonuses`; neither serializes `level_damage_bonus`
   or `_base_max_hp`. Old saves load correctly: derived maxima come out LOWER
   than the old ×1.06 curve above L1, and the existing `hp = minf(hp, max_hp)`
   clamp absorbs the difference silently. (Raise `XPSystem.MAX_LEVEL` to 60
   together with COMBAT_PACING §8's curve re-anchor — that doc owns it.)
5. **UI**: `character_sheet_ui.gd` §8; `item_tooltip.gd` §8.4.
6. **Conditions**: `drain_stamina_frac` calls from `enemy.gd` per the §5.2
   catalog — ship WITH COMBAT_PACING's §5 archetype upgrades (swarm bites need
   swarms that threaten). `"effect": "cure_condition"` consumable in `items.gd`.
7. **Item DB**: primaries appear on NEW items only (§4.2 costs); the 40
   ITEM_PROGRESSION exemplars and all shipped items keep their statlines —
   their `hp/mana/damage` lines remain fully functional forever.
8. **`class_defs.gd`**: unchanged. Its `max_hp/max_mana/mana_regen` keys stay as
   the L1 floor values `Player.create` seeds before `_apply_equipment`
   re-derives; the step-1 assertions keep them honest against `BASE`.

Rollback safety: every consumer guards with `.get(..., 0.0)` / `has_method`, so
each step degrades to current behavior if the next one hasn't landed.

---

## 10. Balance audit — the contract check

### 10.1 EHP vs `PlayerRefEHP(L) = 120·1.055^(L−1)` (±15% incl. gear + armor soak)

Naked max_hp (30 + 10·STA), typical gear hp per ITEM_PROGRESSION budgets in
parentheses:

| L | RefEHP | warrior new (old ×1.06) | druid (mid) new | mage new |
|---|---|---|---|---|
| 1 | 120 | 140 (140) | 100 | 80 |
| 10 | 194 | 204 (237) | 140 | 109 |
| 20 | 332 | 318 (424) | 213 | 161 |
| 40 | 969 | 824 (1 358) | 535 | 391 |
| 60 | 2 830 | 2 220 +gear ~600 (4 357!) | 1 423 +gear ~500, ×~1.35 armor ≈ 2 600 | 1 025 +gear ~300 |

Mid-class lands within −8% of RefEHP at 60 once gear hp and the armor-soak
factor (~1.35 at 60) are counted — the old curve was +54% over. The L10–20 dip
vs the old numbers is intentional and pairs with COMBAT_PACING §10's mob retune.

### 10.2 Flat damage vs the old `+1/level` (COMBAT_PACING assumed ~59 + gear at 60)

`bonus_flat = (AP − AP_L1)/2`, no gear:

| L | old (+1/lvl) | warrior | paladin | rogue | rookwarden | mage | necro | druid |
|---|---|---|---|---|---|---|---|---|
| 10 | 9 | 3.0 | 2.5 | 3.1 | 2.6 | 2.1 | 1.9 | 2.5 |
| 20 | 19 | 8.1 | 6.8 | 8.4 | 7.0 | 5.5 | 5.0 | 6.6 |
| 40 | 39 | 28.7 | 23.9 | 29.6 | 24.6 | 18.1 | 16.3 | 21.5 |
| 60 | 59 | 79.2 | 66.0 | 81.9 | 68.0 | 45.6 | 41.0 | 60.4 |

Mid-levels sit BELOW the old linear bonus (exponential-under-linear between
anchors) while gear damage grows on the *linear* ilvl budget curve — the two
deliberately offset, and casters' lower AP is paid back as intellect-crit + mana
pool. Acceptance stays COMBAT_PACING's playtest gate: 10 at-level kills in
Copper Wells at 9–11 s avg, re-run at L20/L40 brackets, ±15% of RefDPS.

### 10.3 Mana sanity

Mage at 60: pool 1 030 (+gear), regen 0.5·69 ≈ 34/s vs today's flat 25-mana
Fireball — costs are trivialized *by design at cap* until ability RANKS scale
`mana_cost` with rank (that is the ability-progression doc's contract; note it
there: **rank N cost ≈ base_cost · 1.35^(N−1)** keeps cast-per-pool roughly
constant against the intellect curve).

### 10.4 Audit harness

`tests/stats_audit.gd` (headless, `--script`): print `growth_table()` at the
anchor levels, recompute §10.1/§10.2, assert the §9.1 decomposition equalities,
and diff against this doc's tables — the same pattern as `tests/profile_run.py`
for perf. Any tuning change edits `BASE`/`GROWTH` and re-runs the harness; the
markdown tables are regenerated, never hand-edited.
