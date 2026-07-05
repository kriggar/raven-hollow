# RAVEN HOLLOW — TALENT TREES & THE WOW-SCALE SPELLBOOK
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic spirit.
Grounded in: `scripts/class_defs.gd` (7 classes × 8 abilities, exact ability shape),
`scripts/player.gd` (8-slot casting, `_ability(i)` resolution, `_damage_mult`, buffs,
`on_level_up`), `design/COMBAT_PACING.md` (TTK contract, `PlayerRefDPS`, "gear and new
ability ranks carry the rest"), `design/STATUS_EFFECTS.md` (stat-mod buckets, proc/threshold
primitives, dispel schools), `design/ITEM_PROGRESSION.md` (budget-law style, vendor math),
`design/NPC_CAST.md` (trainer roster, `T()` role tags), `design/ZONE_QUEST_MATRIX.md`
(region level bands), `_lore_extract.txt` (naming language).

Owner mandates served here:
- **Talent trees per class** — 3 lore-named trees × 7 classes, classic 31-point shape:
  7 tiers, 5 points per tier gate, passives + procs + ability-modifiers, **1 capstone
  ability per tree**. All 21 trees fully statted below.
- **"Same number of spells as WoW"** — each class grows from 8 abilities to a ~15-spell
  book whose trained entries (spells + ranks, Fireball I–VI style) land in the
  **36–45 learnable-entries band** — WoW-Classic scale, audited in §9.
- Everything trains at **class trainers** placed on the NPC_CAST roster, tiered along the
  ZONE_QUEST_MATRIX leveling bands; all numbers respect the COMBAT_PACING TTK contract (§8).

---

## 1. Audit — what ships today

| Fact | Source | Consequence for this design |
|---|---|---|
| 7 classes × 8 abilities (`abilities[0]` = basic, mana 0), full kit granted at creation | `class_defs.gd` | The 8 become the **core book**, re-gated by trainer level (§4.2); 7 new utility spells per class join them. |
| Ability shape is closed: `{id,name,icon,cooldown,mana_cost,range,damage,kind,params}`; 7 kinds | `class_defs.gd` header | New spells reuse the 7 kinds + additive params only (crafting.gd "extension keys" precedent). Engine deltas listed in §7. |
| Input = `attack` + `skill_1..7`, cooldown arrays sized to kit (`_ab_n`) | `player.gd:376-570` | Hardware stays 8 slots. A **spellbook UI** assigns any known spell to slots 2–8 (§7.4). No input rework. |
| Damage = `ability.damage + gear + level` (+1 flat/level), `_damage_mult` bucket exists | `player.gd:_stat_damage` | Rank system multiplies `ability.damage`; talents ride the `_damage_mult`/StatusEffects buckets. |
| COMBAT_PACING §3: `PlayerRefDPS(L)=25·1.046^(L-1)`, and "**gear and new ability ranks carry the rest**" | COMBAT_PACING.md | Ranks are not optional garnish — they are the *planned carrier* of the 1.046 curve. Rank law in §4.3 implements exactly this. |
| StatusEffects framework: stat-mod buckets (`damage_dealt_pct`, `damage_taken_pct`, stamina alias), thresholds, dispel schools, potency | STATUS_EFFECTS.md §2–3 | Talents apply as **hidden permanent status instances** — zero new stat plumbing (§3.4). |
| No `skill_tree*.gd` exists in this Godot repo (the pygame predecessor shipped one; verified by glob) | `scripts/` | TalentTreeUI is a new scene; reuse `character_sheet_ui.gd`/`pause_menu.gd` ornate-panel patterns and the predecessor's 3-column layout conventions. |
| Trainer roster: 16 `T()` NPCs across 40 zones; "capitals need trainers"; North deliberately trainer-poor | NPC_CAST.md | §6 maps every class to a 5-tier trainer chain using existing cast + 4 new NPC ids. |
| Leveling bands: Border 1–15 · West 13–26 · East 24–35 · South 33–44 · North 42–60 · C2 48–60 | ZONE_QUEST_MATRIX.md | Trainer tiers and rank levels follow these bands, not the demo's cap-10 world. |

---

## 2. SYSTEM RULES (the contract)

### 2.1 Talent points
- **1 talent point per level from 10 to 60 = 51 points** (classic 51-point budget).
- A tree's tier N unlocks at **5×(N−1) points spent in that tree**; capstone (tier 7)
  requires **30 in-tree points + 1** = the classic "31-point talent".
- 51 points = one capstone + a 20-point off-tree dip (31/20/0), or a deep hybrid (26/25).
- Points bank if unspent. Level-down never happens; refunds only via respec.

### 2.2 Respec
At any class trainer: first respec **1g**, doubling per respec, **cap 25g** (ITEM_PROGRESSION
§7 gold reality: a capital recipe is 100g — respeccing stays a decision, not a wall).
Decays one step per real-time week played, WoW-style forgiveness.

### 2.3 Talent budget law (TTK compliance, audited §8)
- A full 31-point **offense** tree may add at most **+12% sustained DPS** from passives,
  **+3% effective** from procs, and one capstone button (a cooldown, not a rotation multiplier).
- A full **defense** tree: at most **+15% EHP** + one defensive capstone.
- A **utility** tree buys speed, resource economy, CC amplification — never more than
  **+6% sustained DPS** as a side effect.
- COMBAT_PACING's normal-mob TTK bands (8–9s → 12–15s) assume a *talented, normally
  geared* player at 60 — talents live **inside** the ±15% RefDPS tolerance, they do not
  stack on top of it. Untalented play = up to ~15% slower kills, never outside the
  "still threatens you" envelope.

### 2.4 Spellbook rules
- The shipped 8-ability kit is re-gated: abilities unlock by **training** at levels
  1/4/8/12/16/20/24/30 (kit order as authored in `class_defs.gd`; basic attack is free at 1).
  New characters start with basic + first trainer visit — the WoW "two buttons at level 1" feel.
- **Ranks**: damage/heal/absorb-bearing spells re-train at higher levels (Roman numerals:
  Fireball I–V). Rank cadence and math in §4.3.
- 7 new **utility spells** per class (buffs, snares, dispels, movement, interrupts,
  pull-tools) train at the levels listed per class — these give every class its answer to
  the COMBAT_PACING curriculum (interrupt, kite, careful pull, burst window).
- Capstone abilities (from talents) are **not trained and have no ranks** — they scale
  continuously: resolution applies `pow(1.046, level-1)` to their base damage (§4.3 law,
  applied per-cast). One rule, zero rank tables for capstones.
- Training cost: `cost_gold = max(1, round(0.35 * req_level * RANK_M))` where RANK_M is
  1.0 for a new spell, 0.6 for a rank. (~1g at 10, ~7g ranks in the 30s, ~15g at 56 —
  tracks ITEM_PROGRESSION's 25–40g/hr at bracket 30.)

---

## 3. DATA SCHEMA — `scripts/talent_defs.gd` (new, statics only)

```gdscript
class_name TalentDefs
## Talent registries for the 21 trees (TALENTS_SPELLS.md). Pure data + helpers.
##
## Tree def shape (exact):
##   {id, name, class_id, lore,               # tree identity
##    talents: Array[Dictionary]}             # ordered tier-major
##
## Talent def shape (exact):
##   {id,                  # "<class>_<tree3>_<slug>", e.g. "war_pit_openers"
##    name, icon,          # icon "pixel:<talent id>" — IconsPixel law holds
##    tier,                # 1..7 (tier N needs 5*(N-1) pts in-tree)
##    col,                 # 0..2 — UI column (3-wide grid, predecessor layout)
##    max_ranks,           # 1..5
##    requires,            # "" or a talent id that must be at max_ranks
##    kind,                # "passive" | "proc" | "ability_mod" | "ability"
##    per_rank,            # kind-specific payload, values PER RANK (below)
##    ability}             # kind=="ability" only: full class_defs ability dict
##
## per_rank payloads:
##   passive:     stat-mod dict — STATUS_EFFECTS §2.5 keys (damage, armor, hp,
##                mana, speed_pct, crit_pct, hp_regen, mana_regen, stamina,
##                damage_dealt_pct, damage_taken_pct) + two NEW keys the
##                status stat_delta() gains: max_hp_pct, max_mana_pct.
##                Optional "when": "target_below_hp:0.35" | "night" | "" —
##                conditional passives (evaluated at damage time).
##   proc:        {on,                 # "basic_hit"|"any_hit"|"crit"|"kill"|
##                                     # "dodge"|"hit_taken"|"cast"|"ability:<id>"
##                 chance_pct,         # per rank
##                 effect,             # StatusDefs id applied to self or target…
##                 target,             # "self"|"target"
##                 cdr: {ability, s},  # …or cooldown shave (either/or effect)
##                 icd}                # internal cooldown, s (anti-degeneracy)
##   ability_mod: {ability,            # ability id this modifies
##                 damage_pct, cooldown_pct, mana_cost_pct, range_pct,
##                 duration_pct,       # buffs/rings
##                 add_params: {}}     # merged into params at resolve time
##
## Helpers: trees_for(class_id) -> Array, get_talent(id) -> Dictionary,
##          points_in_tree(build: Dictionary, tree_id) -> int,
##          validate(build) -> bool   (tier gates + requires + 51-pt budget)
```

### 3.1 Spellbook schema — extensions to `class_defs.gd`
Additive keys on every ability dict (core code ignores unknown keys — the
`crafting.gd` layering precedent, same as ITEM_PROGRESSION's `ilvl`):

```gdscript
"req_level": 8,          # int    — trained at this level (kit re-gate, §2.4)
"rank_levels": [8, 20, 32, 44, 56],   # Array[int] — where ranks I..N train
                                       # ([] = single-rank utility spell)
"trainer_verb": "snare", # String — spellbook-UI grouping label ("" for core)
```

New per-class const in `class_defs.gd` (or a sibling `spell_defs.gd` if the file
budget matters): `SPELLBOOK := {class_id: Array[ability_dict]}` — the 7 new
utility spells per class, exact dicts in §5. Kit abilities stay in `_DEFS`.

### 3.2 Rank resolution (the ONLY damage-math change)
```gdscript
## class_defs.gd — rank law (TALENTS_SPELLS.md §4.3). Applied by player.gd
## at cast time, before gear/level/talent additives:
static func rank_value(base: float, learn_level: int, rank_level: int) -> float:
	return roundf(base * pow(1.046, float(rank_level - learn_level)))
## rank_level = the highest trained rank's level (from "rank_levels");
## capstone abilities pass rank_level = player level (continuous scaling).
## Applies to: damage, heal / heal_per_sec, absorb, minion_hp, minion_damage.
## mana_cost scales by the same factor ×0.85 (pools grow 6%/level — casting
## gets slightly cheaper relative to pool, the Classic "downrank never needed" feel).
```

### 3.3 Player state (`player.gd` + `save_system.gd`)
```gdscript
var talent_build: Dictionary = {}    # talent_id -> ranks taken
var talent_points_spent: int = 0     # derived; serialized for cheap UI
var known_spells: Dictionary = {}    # ability_id -> highest rank index (0-based)
var action_bar: Array[String] = []   # ability ids assigned to slots 1..7 (slot 0 = basic)
var respec_count: int = 0
```
Items serialize as dicts already; these four keys ride the same save path.

### 3.4 Talent application — zero new stat plumbing
On load / talent change, `player.gd` builds ONE hidden permanent status instance
per talent with passive `per_rank` × ranks as `stat_mods` (`hidden: true,
duration: 0, persist: false` — rebuilt from `talent_build`, never saved).
Procs register with the StatusEffects threshold/proc pipeline. `ability_mod`s
are merged in `_ability(i)`: after fetching the dict, overlay every applicable
mod (sum `*_pct` buckets, deep-merge `add_params`) — one ~20-line resolver,
cached per ability, invalidated on talent change.

---

## 4. THE SPELLBOOK EXPANSION — 8 → ~15 spells, ~40 trained entries

### 4.1 The verb grid (why these 7 utility spells per class)
COMBAT_PACING teaches with creature families; every class needs the answer key.
Each class's 7 new spells cover, in some class-flavored form:

| Verb | Teaches against | Every class gets |
|---|---|---|
| **Ranged opener / pull** | careful pulling (§5.4 packs) | a cheap, low-damage pull tool |
| **Snare** | stalkers, kiting | a slow (projectile or ring) |
| **Interrupt** | casters (§5.2) | a cast-canceling hit (melee kits) or silence (caster kits) |
| **Second defensive** | duelists, elites | absorb/heal/mitigation on a separate cooldown |
| **Second mobility** | chargers, signatures | dash/sprint/disengage |
| **Long buff** | downtime economy | a 10-min self-buff (armor/regen "blessing" tier) |
| **Cleanse / special** | DoT families, class identity | dispel (STATUS_EFFECTS schools) or a signature trick |

### 4.2 Kit re-gate (applies to all 7 classes, kit order as authored)
| Kit slot | 1 (basic) | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Trains at | 1 (free) | 4 | 8 | 12 | 16 | 20 | 24 | 30 |

### 4.3 Rank cadence (the 1.046 carrier)
- **Basic attack**: ranks at 1 / 12 / 24 / 36 / 48 — 5 ranks.
- **Damage/heal/absorb kit spells**: rank I at learn level, then **+12 levels** per rank
  while ≤ 58 → 3–5 ranks each (a spell learned at 30 gets ranks at 30/42/54 = 3).
- **Utility spells**: single rank, except damage-bearing ones (marked in §5 tables)
  which get one "II" at learn+20.
- Rank values from `rank_value()` (§3.2). Example, Mage Fireball (base 22, learn 8):
  I 22 → II (20) 37 → III (32) 64 → IV (44) 110 → V (56) 189. At 56 with ~+80 flat
  (level+gear) that's a ~270-damage nuke on a 5 s cooldown vs 3 870-hp trash — the
  §8 audit shows this holds the 11–12 s TTK line.

---

## 5. THE SEVEN CLASSES — trees, capstones, new spells, trainer lists

Format per class: tree table columns are **Tier (pts gate) · Talent · Rks · Kind ·
Per-rank effect · Notes**. Point audit: every tree offers 33 buyable points through
tier 6 + 1-point capstone (31-point builds always reachable, with slack for taste).
Capstone ability dicts are exact `class_defs.gd` shape (compact druid-style).
"Spell ledger" = the trainer list by level: one row per learnable spell, ranks column
per §4.3 cadence. Trainer chains per class in §6.

---

### 5.1 WARRIOR — Shield of the Hollow
Trees (owner-mandated names): **Pit-Fighter** (offense — the Debt-Pit fighting circuits
of Sangeroasa), **Shieldwall** (protection — the palisade that burned and the man who
didn't), **Warcaller** (shouts/economy — the drill-yard's stubbornness, out loud).

#### Pit-Fighter (offense)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Dirty Openers | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Pit Instinct | 3 | passive | `crit_pct +1` | |
| 2 (5) | Heavy Hands | 5 | ability_mod | Cleave `damage_pct +3` | basics +15% at max |
| 2 (5) | Wide Swing | 2 | ability_mod | Cleave `add_params.arc_degrees +10` | 110°→130° |
| 3 (10) | Opened Vein | 3 | proc | on `crit`, 100%: bleed on target, 4 s, ticking 3%/rank of the crit per s | StatusDefs `talent_bleed`, school bleed |
| 3 (10) | Sundering Depth | 2 | ability_mod | Sunder `add_params.guard_break_s +1.0` | feeds COMBAT_PACING §5.5 armor-break |
| 4 (15) | Blood Rhythm | 3 | proc | on `kill`: `speed_pct +5` for 4 s | icd 0 — chain-pull juice |
| 4 (15) | Lean Economy | 2 | ability_mod | ALL warrior abilities `mana_cost_pct -4` | `ability:"*"` wildcard |
| 5 (20) | Executioner's Eye | 3 | passive | `damage_dealt_pct +2` when `target_below_hp:0.35` | conditional passive (§3) |
| 5 (20) | Whirl of Iron | 2 | ability_mod | Whirlwind `cooldown_pct -15` | 6 s → 4.2 s |
| 6 (25) | Red Sand Rhythm | 3 | proc | on `basic_hit`, 100%: `cdr {sunder, 0.2 s}` | requires Sundering Depth |
| 7 (30) | **Executioner's Toll** | 1 | ability | capstone below | |

```gdscript
{ "id": "executioners_toll", "name": "Executioner's Toll", "icon": "pixel:executioners_toll",
	"cooldown": 20.0, "mana_cost": 25.0, "range": 30.0, "damage": 30.0, "kind": "melee_arc",
	"params": { "arc_degrees": 60.0, "execute_below": 0.35, "execute_mult": 3.0,
		"fx": "executioners_toll", "fx_tint": Color(0.72, 0.20, 0.16), "color": Color(0.70, 0.24, 0.20) } },
```

#### Shieldwall (protection)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Quilted Under-Plate | 5 | passive | `armor +1` | |
| 1 (0) | Stubborn Yard | 3 | passive | `stamina +2` (+20 hp) | STATUS_EFFECTS stamina alias |
| 2 (5) | Shield Discipline | 5 | passive | `damage_taken_pct -1` | |
| 2 (5) | Charge the Line | 2 | ability_mod | Shield Charge `cooldown_pct -14` | 7 s → 5 s |
| 3 (10) | Brace | 3 | proc | on `hit_taken`, 10%: absorb 5% max hp, 4 s | icd 6 s |
| 3 (10) | Bulwark Weight | 2 | ability_mod | Iron Bulwark `add_params.absorb +8` | scales with ranks |
| 4 (15) | Hollow's Constitution | 3 | passive | `hp_regen +0.5` | |
| 4 (15) | Riposte | 2 | proc | on `dodge` (enemy strike whiffs the range re-check): `damage_dealt_pct +10` for 3 s | rewards the §5.1 telegraph game |
| 5 (20) | Palisade Footing | 3 | passive | slow/root durations on you -10% | small StatusEffects hook (§7) |
| 5 (20) | Charge Momentum | 2 | ability_mod | Shield Charge `add_params.arrive_absorb +15` | |
| 6 (25) | Iron Constitution | 3 | passive | `max_hp_pct +2` | new stat key (§3) |
| 7 (30) | **Last Palisade** | 1 | ability | capstone below | |

```gdscript
{ "id": "last_palisade", "name": "Last Palisade", "icon": "pixel:last_palisade",
	"cooldown": 60.0, "mana_cost": 30.0, "range": 0.0, "damage": 0.0, "kind": "buff",
	"params": { "duration": 8.0, "damage_taken_pct": -50.0, "cc_immune": true,
		"fx_loop": "iron_bulwark", "fx_tint": Color(0.60, 0.64, 0.68), "color": Color(0.58, 0.62, 0.66) } },
```

#### Warcaller (shouts / economy)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Drillmaster's Pace | 5 | passive | `speed_pct +1` | |
| 1 (0) | Loud Lungs | 3 | passive | `mana +5` | warrior pool 55 — real % |
| 2 (5) | Carrying Voice | 5 | ability_mod | War Cry `duration_pct +10` | 5 s → 7.5 s |
| 2 (5) | Second Wind Drill | 2 | ability_mod | War Cry `add_params.heal_per_sec +2` | shout heals while up |
| 3 (10) | Cadence | 3 | proc | on `cast`, 10%: next basic +30% (one hit) | icd 3 s |
| 3 (10) | Warning Bark | 2 | ability_mod | Cowing Shout (§ spells) `range_pct +15` | talents may mod trained spells |
| 4 (15) | Marching Order | 3 | passive | out-of-combat `speed_pct +3` | downtime pacing, COMBAT_PACING §2.5 |
| 4 (15) | Rousing Cry | 2 | ability_mod | War Cry `add_params.absorb +10` | |
| 5 (20) | Veteran's Economy | 3 | passive | `mana_regen +0.5` | |
| 5 (20) | Echoing Cry | 2 | ability_mod | War Cry `cooldown_pct -12` | |
| 6 (25) | Voice of the Palisade | 3 | ability_mod | War Cry `add_params.damage_mult +0.05` | 1.3 → 1.45 at max |
| 7 (30) | **Gallows Horn** | 1 | ability | capstone below | |

```gdscript
{ "id": "gallows_horn", "name": "Gallows Horn", "icon": "pixel:gallows_horn",
	"cooldown": 45.0, "mana_cost": 40.0, "range": 70.0, "damage": 20.0, "kind": "aoe_ring",
	"params": { "at_aim": false, "slow_mult": 0.5, "slow_duration": 3.0,
		"reset_cooldown": "shield_charge", "fx": "war_cry", "fx_tint": Color(0.90, 0.58, 0.30),
		"color": Color(0.86, 0.52, 0.26) } },
```

#### Warrior — 7 new trained spells (exact dicts)
```gdscript
"warrior": [
	{ "id": "hurled_axe", "name": "Hurled Axe", "icon": "pixel:hurled_axe",
		"cooldown": 8.0, "mana_cost": 8.0, "range": 200.0, "damage": 10.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "pull",
		"params": { "speed": 260.0, "projectile": "arrow", "thin": true, "slow_mult": 0.7, "slow_duration": 3.0,
			"fx": "hurled_axe", "color": Color(0.66, 0.60, 0.52) } },
	{ "id": "second_wind", "name": "Second Wind", "icon": "pixel:second_wind",
		"cooldown": 25.0, "mana_cost": 15.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 10, "rank_levels": [10, 30, 50], "trainer_verb": "defensive",
		"params": { "duration": 8.0, "heal_per_sec": 4.0, "fx": "heal_bloom", "color": Color(0.72, 0.52, 0.36) } },
	{ "id": "hobbling_strike", "name": "Hobbling Strike", "icon": "pixel:hobbling_strike",
		"cooldown": 10.0, "mana_cost": 10.0, "range": 26.0, "damage": 6.0, "kind": "melee_arc",
		"req_level": 14, "rank_levels": [14, 34, 54], "trainer_verb": "snare",
		"params": { "arc_degrees": 60.0, "slow_mult": 0.4, "slow_duration": 4.0,
			"fx": "hobbling_strike", "color": Color(0.70, 0.56, 0.44) } },
	{ "id": "cowing_shout", "name": "Cowing Shout", "icon": "pixel:cowing_shout",
		"cooldown": 20.0, "mana_cost": 18.0, "range": 55.0, "damage": 0.0, "kind": "aoe_ring",
		"req_level": 18, "rank_levels": [], "trainer_verb": "special",
		"params": { "at_aim": false, "enemy_damage_dealt_pct": -15.0, "debuff_duration": 6.0,
			"fx": "war_cry", "fx_tint": Color(0.52, 0.48, 0.44), "color": Color(0.54, 0.50, 0.46) } },
	{ "id": "batter", "name": "Batter", "icon": "pixel:batter",
		"cooldown": 12.0, "mana_cost": 12.0, "range": 26.0, "damage": 8.0, "kind": "melee_arc",
		"req_level": 22, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "arc_degrees": 45.0, "interrupt": true, "fx": "batter", "color": Color(0.78, 0.70, 0.58) } },
	{ "id": "bloodrush", "name": "Bloodrush", "icon": "pixel:bloodrush",
		"cooldown": 30.0, "mana_cost": 12.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 34, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "duration": 4.0, "speed_mult": 1.4, "break_snares": true,
			"fx": "war_cry", "fx_tint": Color(0.80, 0.30, 0.22), "color": Color(0.76, 0.32, 0.24) } },
	{ "id": "ironhide_stance", "name": "Ironhide Stance", "icon": "pixel:ironhide_stance",
		"cooldown": 45.0, "mana_cost": 20.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 42, "rank_levels": [], "trainer_verb": "long_buff",
		"params": { "duration": 30.0, "damage_taken_pct": -15.0, "damage_dealt_pct": -10.0, "group": "form",
			"fx_loop": "iron_bulwark", "color": Color(0.56, 0.58, 0.60) } },
],
```

#### Warrior spell ledger (trainer list by level) — 36 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Cleave (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Shield Charge | 4 | 4 (utility — no ranks) | 1 |
| Sunder | 8 | 8 / 20 / 32 / 44 / 56 | 5 |
| Whirlwind | 12 | 12 / 24 / 36 / 48 | 4 |
| War Cry | 16 | 16 | 1 |
| Iron Bulwark | 20 | 20 / 32 / 44 / 56 (absorb ranks) | 4 |
| Earthshaker | 24 | 24 / 36 / 48 | 3 |
| Hurled Axe | 6 | 6 / 26 / 46 | 3 |
| Second Wind | 10 | 10 / 30 / 50 | 3 |
| Hobbling Strike | 14 | 14 / 34 / 54 | 3 |
| Cowing Shout | 18 | — | 1 |
| Batter | 22 | — | 1 |
| Bloodrush | 34 | — | 1 |
| Ironhide Stance | 42 | — | 1 |
| **Total** | | | **36** ✓ band |

*(Warrior and Rogue kits are 7 abilities, so the §4.2 slot-8/L30 gate is unused for them —
their last kit ability trains at 24. The other five classes carry 8-ability kits and use
the L30 gate.)*

---

### 5.2 ROGUE — Knife in the Fog
Trees: **Knifework** (burst — the quiet knife that settles what loud men cannot),
**Noxious Trade** (poisons — vials from the fog-alleys behind the tavern),
**Fogwalk** (evasion/mobility — the shadows that owe him favors, collected nightly).

#### Knifework (burst)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Honed Edges | 5 | passive | `crit_pct +1` | |
| 1 (0) | Alley Discipline | 3 | passive | `damage_dealt_pct +1` | |
| 2 (5) | Deep Angles | 5 | ability_mod | Backstab `damage_pct +4` | +20% at max |
| 2 (5) | Quick Wrists | 2 | ability_mod | Quick Slash `cooldown_pct -8` | 0.35 → 0.30 s cadence |
| 3 (10) | Opened Vein | 3 | proc | on `crit`: bleed 4 s, 3%/rank of the crit per s | shares StatusDefs `talent_bleed` |
| 3 (10) | Collector's Patience | 2 | passive | `damage_dealt_pct +3` when `target_below_hp:0.35` | |
| 4 (15) | Knife-Fan Craft | 3 | ability_mod | Fan of Knives `damage_pct +5` | |
| 4 (15) | Fresh Favors | 2 | proc | on `kill`: refund 8 mana | icd 0 |
| 5 (20) | Twist the Blade | 3 | passive | crit multiplier 1.5 → +0.05/rank | crit-mult hook (§7) |
| 5 (20) | Step Into Murder | 2 | ability_mod | Shadowstep `add_params.next_hit_mult +0.25` | 2.0 → 2.5 |
| 6 (25) | Red Ledger Habits | 3 | proc | on `ability:backstab` hit vs bleeding target: `cdr {shadowstep, 1.0 s}` | requires Opened Vein |
| 7 (30) | **Red Ledger** | 1 | ability | capstone below | |

```gdscript
{ "id": "red_ledger", "name": "Red Ledger", "icon": "pixel:red_ledger",
	"cooldown": 25.0, "mana_cost": 25.0, "range": 28.0, "damage": 34.0, "kind": "melee_arc",
	"params": { "arc_degrees": 45.0, "bonus_vs_bleeding_mult": 2.0,
		"fx": "backstab", "fx_tint": Color(0.62, 0.12, 0.12), "color": Color(0.60, 0.16, 0.16) } },
```

#### Noxious Trade (poisons / attrition)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Practiced Mixing | 5 | passive | poison/bleed school ticks you cause +2% | school-scoped passive (§7) |
| 1 (0) | Iron Stomach | 3 | passive | poison/disease durations on you -10% | |
| 2 (5) | Thicker Vials | 5 | ability_mod | Noxious Vial `damage_pct +6` | tick damage |
| 2 (5) | Wider Splash | 2 | ability_mod | Noxious Vial `range_pct +10` | ring radius |
| 3 (10) | Smeared Blades | 3 | proc | on `basic_hit`, 15%/rank: poison 3 s, 2/s tick | StatusDefs `talent_poison` |
| 3 (10) | Lingering Stock | 2 | ability_mod | Noxious Vial `duration_pct +25` | 4 s → 6 s |
| 4 (15) | Cutpurse Cardio | 3 | passive | `max_hp_pct +2` | attrition fights run longer |
| 4 (15) | Cheap Reagents | 2 | ability_mod | Noxious Vial + Grit Toss `mana_cost_pct -10` | |
| 5 (20) | Fester | 3 | passive | your poison ticks +8% per other DoT on the target | threshold hook (STATUS_EFFECTS §2.3) |
| 5 (20) | Choking Cloud | 2 | ability_mod | Noxious Vial `add_params`: `slow_mult -0.05`, `slow_duration +0.4` | 0.6→0.5 / 1.2→2.0 |
| 6 (25) | Apothecary's Ledger | 3 | proc | on death of a target your poison ticks on, 33%/rank: nearest enemy ≤60 px inherits the poison, fresh | the swarm-clear engine |
| 7 (30) | **Plaguebloom Vial** | 1 | ability | capstone below | |

```gdscript
{ "id": "plaguebloom_vial", "name": "Plaguebloom Vial", "icon": "pixel:plaguebloom_vial",
	"cooldown": 40.0, "mana_cost": 40.0, "range": 44.0, "damage": 9.0, "kind": "aoe_ring",
	"params": { "at_aim": true, "cast_range": 130.0, "tick_interval": 0.5, "duration": 6.0,
		"slow_mult": 0.6, "slow_duration": 1.5, "fx": "venom_cloud",
		"fx_tint": Color(0.44, 0.58, 0.26), "color": Color(0.46, 0.60, 0.28) } },
```

#### Fogwalk (evasion / mobility)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Fog-Alley Feet | 5 | passive | `speed_pct +1` | |
| 1 (0) | Thin Silhouette | 3 | passive | `damage_taken_pct -1` | |
| 2 (5) | Longer Shadows | 5 | ability_mod | Shadowstep `range_pct +8` | 70 → 98 px |
| 2 (5) | Ash Economy | 2 | ability_mod | Shroud of Ash `mana_cost_pct -15` | |
| 3 (10) | Slip the Hit | 3 | proc | on `hit_taken`, 6%/rank: absorb the NEXT hit entirely (2 s window) | icd 8 s |
| 3 (10) | Quiet Landing | 2 | ability_mod | Tumble (§ spells) `cooldown_pct -15` | |
| 4 (15) | Fog Discipline | 3 | ability_mod | Shroud `duration_pct +15` | 4 s → 5.8 s |
| 4 (15) | Debts Collected Nightly | 2 | passive | `damage_dealt_pct +2` at night | day_night.gd flag; canon nightwork |
| 5 (20) | Vanish Reflex | 3 | proc | on `dodge`: `speed_pct +8` for 3 s | |
| 5 (20) | Second Step | 2 | ability_mod | Shadowstep `cooldown_pct -12` | 5 s → 3.8 s |
| 6 (25) | Never Seen Twice | 3 | passive | after any dash: `damage_taken_pct -8` for 3 s | |
| 7 (30) | **Become the Fog** | 1 | ability | capstone below | |

```gdscript
{ "id": "become_the_fog", "name": "Become the Fog", "icon": "pixel:become_the_fog",
	"cooldown": 60.0, "mana_cost": 30.0, "range": 0.0, "damage": 0.0, "kind": "buff",
	"params": { "duration": 4.0, "damage_taken_pct": -50.0, "speed_mult": 1.3,
		"next_hit_mult": 3.0, "bonus_duration": 6.0, "fx": "shroud",
		"fx_tint": Color(0.22, 0.22, 0.26), "color": Color(0.40, 0.40, 0.46) } },
```

#### Rogue — 7 new trained spells
```gdscript
"rogue": [
	{ "id": "flick_knife", "name": "Flick Knife", "icon": "pixel:flick_knife",
		"cooldown": 6.0, "mana_cost": 6.0, "range": 180.0, "damage": 8.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "pull",
		"params": { "speed": 300.0, "projectile": "fan_of_knives", "thin": true,
			"fx": "flick_knife", "color": Color(0.76, 0.78, 0.82) } },
	{ "id": "grit_toss", "name": "Grit Toss", "icon": "pixel:grit_toss",
		"cooldown": 14.0, "mana_cost": 12.0, "range": 30.0, "damage": 0.0, "kind": "aoe_ring",
		"req_level": 10, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "at_aim": true, "cast_range": 100.0, "root_duration": 1.2, "interrupt": true,
			"fx": "grit_toss", "fx_tint": Color(0.62, 0.56, 0.46), "color": Color(0.60, 0.54, 0.44) } },
	{ "id": "tumble", "name": "Tumble", "icon": "pixel:tumble",
		"cooldown": 9.0, "mana_cost": 8.0, "range": 55.0, "damage": 0.0, "kind": "dash",
		"req_level": 14, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "smoke": false, "fx": "tumble", "color": Color(0.58, 0.58, 0.62) } },
	{ "id": "garrote", "name": "Garrote", "icon": "pixel:garrote",
		"cooldown": 12.0, "mana_cost": 14.0, "range": 24.0, "damage": 6.0, "kind": "melee_arc",
		"req_level": 20, "rank_levels": [20, 40, 58], "trainer_verb": "dot",
		"params": { "arc_degrees": 45.0, "bleed_per_sec": 4.0, "bleed_duration": 6.0,
			"fx": "garrote", "color": Color(0.64, 0.22, 0.20) } },
	{ "id": "smoke_bomb", "name": "Smoke Bomb", "icon": "pixel:smoke_bomb",
		"cooldown": 30.0, "mana_cost": 22.0, "range": 50.0, "damage": 0.0, "kind": "aoe_ring",
		"req_level": 28, "rank_levels": [], "trainer_verb": "defensive",
		"params": { "at_aim": false, "enemy_damage_dealt_pct": -50.0, "debuff_duration": 4.0,
			"fx": "shroud", "fx_tint": Color(0.30, 0.30, 0.34), "color": Color(0.36, 0.36, 0.40) } },
	{ "id": "distracting_whistle", "name": "Distracting Whistle", "icon": "pixel:distracting_whistle",
		"cooldown": 15.0, "mana_cost": 8.0, "range": 220.0, "damage": 0.0, "kind": "projectile",
		"req_level": 36, "rank_levels": [], "trainer_verb": "special",
		"params": { "speed": 400.0, "projectile": "spark", "thin": true, "single_pull": true,
			"fx": "distracting_whistle", "color": Color(0.58, 0.62, 0.66) } },
	{ "id": "deathmark", "name": "Deathmark", "icon": "pixel:deathmark",
		"cooldown": 35.0, "mana_cost": 20.0, "range": 200.0, "damage": 0.0, "kind": "projectile",
		"req_level": 44, "rank_levels": [], "trainer_verb": "mark",
		"params": { "speed": 400.0, "projectile": "soul_bolt", "thin": true,
			"mark_damage_taken_pct": 15.0, "mark_duration": 8.0, "per_source": true,
			"fx": "deathmark", "color": Color(0.66, 0.30, 0.30) } },
],
```

#### Rogue spell ledger — 36 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Quick Slash (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Backstab | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Shadowstep | 8 | 8 (utility) | 1 |
| Noxious Vial | 12 | 12 / 24 / 36 / 48 | 4 |
| Fan of Knives | 16 | 16 / 28 / 40 / 52 | 4 |
| Shroud of Ash | 20 | 20 / 36 / 52 (absorb ranks) | 3 |
| Death Blossom | 24 | 24 / 36 / 48 | 3 |
| Flick Knife | 6 | 6 / 26 / 46 | 3 |
| Grit Toss | 10 | — | 1 |
| Tumble | 14 | — | 1 |
| Garrote | 20 | 20 / 40 / 58 | 3 |
| Smoke Bomb | 28 | — | 1 |
| Distracting Whistle | 36 | — | 1 |
| Deathmark | 44 | — | 1 |
| **Total** | | | **36** ✓ band |

---

### 5.3 MAGE — Keeper of the Violet Flame
Trees: **Emberscript** (fire — the forbidden script she copied until the candle answered),
**Hoarfrost** (frost/control — the cold the North teaches whether you ask or not),
**Threadwork** (arcane/economy — filament-sight, mana as a woven thing; the discipline
the council distrusts most).

#### Emberscript (fire)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Candle Discipline | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Warm Study | 3 | passive | `mana +8` | |
| 2 (5) | Legible Flame | 5 | ability_mod | Fireball `damage_pct +3` | |
| 2 (5) | Fat Splash | 2 | ability_mod | Fireball `add_params.aoe_radius +6` | 30 → 42 px |
| 3 (10) | Ignite | 3 | proc | on `crit` with fire spells: burn 4 s, 5%/rank of the crit per s | StatusDefs `talent_burn`; THE fire talent |
| 3 (10) | Quick Quill | 2 | ability_mod | Fireball `cooldown_pct -10` | 5 s → 4 s |
| 4 (15) | Violet Intensity | 3 | passive | `crit_pct +1` | |
| 4 (15) | Strike the Page | 2 | ability_mod | Flame Strike `damage_pct +6` | |
| 5 (20) | Emberfall Memory | 3 | passive | `damage_dealt_pct +2` vs burning targets | conditional (§3) |
| 5 (20) | Cheap Ink | 2 | ability_mod | fire spells `mana_cost_pct -6` | scoped wildcard |
| 6 (25) | Cinder Momentum | 3 | proc | on `kill` with fire: next Fireball instant-ish (`cdr {fireball, full}`), 33%/rank | icd 6 s |
| 7 (30) | **Pyroclasm** | 1 | ability | capstone below | |

```gdscript
{ "id": "pyroclasm", "name": "Pyroclasm", "icon": "pixel:pyroclasm",
	"cooldown": 30.0, "mana_cost": 45.0, "range": 240.0, "damage": 40.0, "kind": "projectile",
	"params": { "speed": 180.0, "projectile": "fireball", "aoe_radius": 50.0,
		"fx": "pyroclasm", "fx_tint": Color(0.72, 0.36, 0.62), "color": Color(0.80, 0.40, 0.44) } },
```

#### Hoarfrost (frost / control)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Northern Patience | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Cold Blood | 3 | passive | `stamina +2` | frost is the survival school |
| 2 (5) | Deep Chill | 5 | ability_mod | Ice Lance `add_params`: `slow_mult 0.7`, `slow_duration +0.4/rank` | Ice Lance becomes a snare |
| 2 (5) | Long Lance | 2 | ability_mod | Ice Lance `range_pct +8` | |
| 3 (10) | Shatter | 3 | passive | `damage_dealt_pct +5` vs slowed/rooted targets | the frost payoff loop |
| 3 (10) | Wide Nova | 2 | ability_mod | Frost Nova `range_pct +10` | |
| 4 (15) | Rimeguard | 3 | proc | on `hit_taken`, 10%/rank: attacker slowed 30%, 2 s | icd 2 s |
| 4 (15) | Nova Economy | 2 | ability_mod | Frost Nova `cooldown_pct -12`, `mana_cost_pct -8` | |
| 5 (20) | Hoarfrost Sight | 3 | passive | `crit_pct +1`; +1 more vs slowed targets | conditional half |
| 5 (20) | Winter's Grip | 2 | ability_mod | Frost Nova `add_params.root_duration +0.5` | nova roots at max |
| 6 (25) | Everwinter | 3 | passive | your slows last +15% and are 5% stronger | slow-amp hook (§7) |
| 7 (30) | **Winter's Vice** | 1 | ability | capstone below | |

```gdscript
{ "id": "winters_vice", "name": "Winter's Vice", "icon": "pixel:winters_vice",
	"cooldown": 35.0, "mana_cost": 45.0, "range": 50.0, "damage": 30.0, "kind": "aoe_ring",
	"params": { "at_aim": true, "cast_range": 150.0, "root_duration": 2.0,
		"bonus_vs_cc_mult": 1.5, "fx": "frost_nova", "fx_tint": Color(0.62, 0.80, 0.92),
		"color": Color(0.58, 0.76, 0.88) } },
```

#### Threadwork (arcane / economy)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Filament Sense | 5 | passive | `mana_regen +0.4` | |
| 1 (0) | Woven Reserves | 3 | passive | `max_mana_pct +3` | new stat key (§3) |
| 2 (5) | Spark Economy | 5 | ability_mod | Spark `damage_pct +4` | basic carries arcane builds |
| 2 (5) | Short Stitch | 2 | ability_mod | Blink `cooldown_pct -12` | 6 s → 4.6 s |
| 3 (10) | Clarity | 3 | proc | on `cast`, 4%/rank: next spell costs 0 mana | icd 4 s; classic Clearcasting |
| 3 (10) | Woven Ward | 2 | ability_mod | Mana Shield `add_params.absorb +10` | |
| 4 (15) | Thread-Sight | 3 | passive | `crit_pct +1` | seeing the weave |
| 4 (15) | Double Stitch | 2 | ability_mod | Blink `range_pct +10` | 90 → 108 px |
| 5 (20) | Unravel | 3 | passive | your interrupts/silences last +0.4 s | Counterspell amp |
| 5 (20) | Loom Discipline | 2 | passive | `damage_taken_pct -2` while Mana Shield holds | conditional |
| 6 (25) | The Candle Answers | 3 | proc | on `hit_taken` below 35% hp: free Blink (`cdr {blink, full}`), 33%/rank | icd 20 s |
| 7 (30) | **Thread-Sever** | 1 | ability | capstone below | |

```gdscript
{ "id": "thread_sever", "name": "Thread-Sever", "icon": "pixel:thread_sever",
	"cooldown": 30.0, "mana_cost": 35.0, "range": 240.0, "damage": 22.0, "kind": "projectile",
	"params": { "speed": 340.0, "projectile": "soul_bolt", "interrupt": true, "silence_duration": 3.0,
		"dispel_target_buffs": 1, "fx": "thread_sever", "fx_tint": Color(0.52, 0.58, 0.90),
		"color": Color(0.56, 0.52, 0.86) } },
```

#### Mage — 7 new trained spells
```gdscript
"mage": [
	{ "id": "ember_sigil", "name": "Ember Sigil", "icon": "pixel:ember_sigil",
		"cooldown": 10.0, "mana_cost": 20.0, "range": 40.0, "damage": 5.0, "kind": "aoe_ring",
		"req_level": 6, "rank_levels": [6, 18, 30, 42, 54], "trainer_verb": "dot",
		"params": { "at_aim": true, "cast_range": 130.0, "tick_interval": 0.5, "duration": 4.0,
			"fx": "consecration", "fx_tint": Color(0.78, 0.42, 0.60), "color": Color(0.80, 0.44, 0.36) } },
	{ "id": "frost_armor", "name": "Frost Armor", "icon": "pixel:frost_armor",
		"cooldown": 3.0, "mana_cost": 15.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 10, "rank_levels": [10, 30, 50], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "armor": 4.0, "chill_attackers_mult": 0.7, "chill_duration": 2.0,
			"group": "armor", "fx_loop": "mana_shield", "fx_tint": Color(0.58, 0.76, 0.88),
			"color": Color(0.56, 0.74, 0.86) } },
	{ "id": "firebrand", "name": "Firebrand", "icon": "pixel:firebrand",
		"cooldown": 3.0, "mana_cost": 18.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 14, "rank_levels": [14, 34, 54], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "basic_burn_per_sec": 2.0, "basic_burn_duration": 3.0,
			"group": "armor", "fx_loop": "bone_ward", "fx_tint": Color(0.88, 0.48, 0.28),
			"color": Color(0.86, 0.46, 0.26) } },
	{ "id": "counterspell", "name": "Counterspell", "icon": "pixel:counterspell",
		"cooldown": 18.0, "mana_cost": 15.0, "range": 240.0, "damage": 0.0, "kind": "projectile",
		"req_level": 18, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "speed": 420.0, "projectile": "spark", "thin": true, "interrupt": true,
			"silence_duration": 2.0, "fx": "counterspell", "color": Color(0.60, 0.48, 0.84) } },
	{ "id": "ring_of_rime", "name": "Ring of Rime", "icon": "pixel:ring_of_rime",
		"cooldown": 16.0, "mana_cost": 24.0, "range": 46.0, "damage": 4.0, "kind": "aoe_ring",
		"req_level": 26, "rank_levels": [], "trainer_verb": "snare",
		"params": { "at_aim": true, "cast_range": 150.0, "slow_mult": 0.5, "slow_duration": 4.0,
			"fx": "frost_nova", "fx_tint": Color(0.62, 0.78, 0.90), "color": Color(0.60, 0.76, 0.88) } },
	{ "id": "mirror_wisp", "name": "Mirror Wisp", "icon": "pixel:mirror_wisp",
		"cooldown": 40.0, "mana_cost": 30.0, "range": 60.0, "damage": 0.0, "kind": "summon",
		"req_level": 36, "rank_levels": [], "trainer_verb": "defensive",
		"params": { "minion_type": "wisp", "lifetime": 6.0, "minion_hp": 30.0, "minion_damage": 0.0,
			"minion_speed": 0.0, "decoy": true, "fx": "blink", "fx_tint": Color(0.64, 0.46, 0.84),
			"color": Color(0.62, 0.44, 0.82) } },
	{ "id": "violet_clarity", "name": "Violet Clarity", "icon": "pixel:violet_clarity",
		"cooldown": 60.0, "mana_cost": 0.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 44, "rank_levels": [], "trainer_verb": "special",
		"params": { "duration": 10.0, "free_casts": 3, "fx": "mana_shield",
			"fx_tint": Color(0.66, 0.44, 0.86), "color": Color(0.64, 0.42, 0.84) } },
],
```

#### Mage spell ledger — 45 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Spark (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Ice Lance | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Fireball | 8 | 8 / 20 / 32 / 44 / 56 | 5 |
| Flame Strike | 12 | 12 / 24 / 36 / 48 | 4 |
| Frost Nova | 16 | 16 / 28 / 40 / 52 | 4 |
| Blink | 20 | 20 (utility) | 1 |
| Mana Shield | 24 | 24 / 36 / 48 (absorb ranks) | 3 |
| Ember Sigil | 6 | 6 / 18 / 30 / 42 / 54 | 5 |
| Frost Armor | 10 | 10 / 30 / 50 (armor ranks) | 3 |
| Firebrand | 14 | 14 / 34 / 54 (burn ranks) | 3 |
| Counterspell | 18 | — | 1 |
| Ring of Rime | 26 | — | 1 |
| Mirror Wisp | 36 | — | 1 |
| Violet Clarity | 44 | — | 1 |
| Cinderfall | 30 | 30 / 42 / 54 | 3 |
| **Total** | | | **45** ✓ band top (caster-fattest book, like Classic mage) |

*(Mage kit is 8 abilities — Cinderfall takes the §4.2 slot-8/L30 gate.)*

---

### 5.4 PALADIN — Lantern of the Ashen Chapel
Trees: **Lantern** (holy sustain — the light carried, not brandished), **Vigil**
(protection — the watch that does not end; Twelfth-Watcher liturgy), **Dawnfire**
(retribution — the consecrated hammer's answer; Emberdawn rites).

#### Lantern (holy sustain)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Kept Flame | 5 | passive | `mana_regen +0.4` | |
| 1 (0) | Chapel Vows | 3 | passive | `mana +8` | |
| 2 (5) | Gentle Hands | 5 | ability_mod | Lay on Hands `add_params.heal +6` | 50 → 80 at max (I-rank base) |
| 2 (5) | Quick Litany | 2 | ability_mod | Lay on Hands `cooldown_pct -12` | |
| 3 (10) | Warming Light | 3 | proc | on `ability:holy_smite` hit, 33%/rank: heal self 3% max hp | icd 3 s |
| 3 (10) | Oil Economy | 2 | ability_mod | Consecration `mana_cost_pct -12` | |
| 4 (15) | Lantern-Bearer | 3 | passive | `hp_regen +0.5` | |
| 4 (15) | Sheltering Glow | 2 | ability_mod | Divine Shield `duration_pct +15` | |
| 5 (20) | Unspent Wick | 3 | proc | on `cast`, 5%/rank: refund the spell's mana | icd 5 s |
| 5 (20) | Consecrated Ground | 2 | ability_mod | Consecration `add_params.self_heal_per_tick +2` | stand in your own fire |
| 6 (25) | The Light That Stays | 3 | passive | healing you cast +8% | heal-amp bucket (§7) |
| 7 (30) | **Beacon of the Ashen Chapel** | 1 | ability | capstone below | |

```gdscript
{ "id": "ashen_beacon", "name": "Beacon of the Ashen Chapel", "icon": "pixel:ashen_beacon",
	"cooldown": 45.0, "mana_cost": 45.0, "range": 50.0, "damage": 8.0, "kind": "aoe_ring",
	"params": { "at_aim": false, "tick_interval": 0.5, "duration": 6.0, "self_heal_per_tick": 4.0,
		"fx": "consecration", "fx_loop": "consecration_loop", "fx_tint": Color(0.96, 0.88, 0.58),
		"color": Color(0.94, 0.84, 0.54) } },
```

#### Vigil (protection)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Dented Faith | 5 | passive | `armor +1` | |
| 1 (0) | Watch Rations | 3 | passive | `stamina +2` | |
| 2 (5) | Stand the Line | 5 | passive | `damage_taken_pct -1` | |
| 2 (5) | Shield Drills | 2 | ability_mod | Divine Shield `add_params.absorb +8` | |
| 3 (10) | Twelfth Posture | 3 | proc | on `hit_taken`, 8%/rank: absorb 5% max hp, 4 s | icd 6 s |
| 3 (10) | Judged and Held | 2 | ability_mod | Judgment `add_params.root_duration +0.35` | 1.25 → 1.95 s |
| 4 (15) | Lantern Oil Constitution | 3 | passive | `max_hp_pct +2` | |
| 4 (15) | Bulwark Liturgy | 2 | ability_mod | Sacred Bulwark `cooldown_pct -12` | |
| 5 (20) | Unmoved | 3 | passive | slow/root durations on you -10% | |
| 5 (20) | Punish the Lapse | 2 | proc | on `dodge`: `damage_dealt_pct +10` for 3 s | telegraph reward |
| 6 (25) | The Watch Does Not End | 3 | passive | below 30% hp: `damage_taken_pct -4` | conditional |
| 7 (30) | **The Unbroken Vigil** | 1 | ability | capstone below | |

```gdscript
{ "id": "unbroken_vigil", "name": "The Unbroken Vigil", "icon": "pixel:unbroken_vigil",
	"cooldown": 90.0, "mana_cost": 40.0, "range": 0.0, "damage": 0.0, "kind": "buff",
	"params": { "duration": 10.0, "absorb": 120.0, "reflect_pct": 20.0,
		"fx_loop": "holy_dome", "fx_tint": Color(0.92, 0.82, 0.50), "color": Color(0.90, 0.78, 0.46) } },
```

#### Dawnfire (retribution)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Morning Drill | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Zeal | 3 | passive | `crit_pct +1` | |
| 2 (5) | Heavier Verdicts | 5 | ability_mod | Hammer Blow `damage_pct +3` | |
| 2 (5) | Throwing Arm | 2 | ability_mod | Holy Smite `cooldown_pct -12` | 3 s → 2.3 s |
| 3 (10) | Emberdawn Brand | 3 | proc | on `crit`: holy burn 4 s, 4%/rank of the crit per s | StatusDefs `talent_holyfire` |
| 3 (10) | Judgment Weight | 2 | ability_mod | Judgment `damage_pct +8` | |
| 4 (15) | Righteous Pace | 3 | passive | `speed_pct +1` | |
| 4 (15) | Grave-Lit | 2 | passive | `damage_dealt_pct +3` vs undead/thread-touched families | enemy-family tag (§7) |
| 5 (20) | Dawnbreak Discipline | 3 | ability_mod | Dawnbreak `cooldown_pct -8`, `damage_pct +3` | |
| 5 (20) | Sparks from the Anvil | 2 | proc | on `ability:judgment` hit: `cdr {holy_smite, full}` | |
| 6 (25) | The Hammer Remembers | 3 | proc | on `kill`: next Judgment free + `damage_pct +15` (one cast), 33%/rank | icd 8 s |
| 7 (30) | **Emberdawn Verdict** | 1 | ability | capstone below | |

```gdscript
{ "id": "emberdawn_verdict", "name": "Emberdawn Verdict", "icon": "pixel:emberdawn_verdict",
	"cooldown": 25.0, "mana_cost": 30.0, "range": 30.0, "damage": 32.0, "kind": "melee_arc",
	"params": { "arc_degrees": 90.0, "bonus_vs_families": ["skeleton", "thread"], "family_mult": 1.75,
		"fx": "dawnbreak_pillar", "fx_tint": Color(1.0, 0.90, 0.55), "color": Color(0.96, 0.84, 0.48) } },
```

#### Paladin — 7 new trained spells
```gdscript
"paladin": [
	{ "id": "chapels_censure", "name": "Chapel's Censure", "icon": "pixel:chapels_censure",
		"cooldown": 7.0, "mana_cost": 8.0, "range": 200.0, "damage": 9.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "pull",
		"params": { "speed": 260.0, "projectile": "bolt", "bonus_vs_families": ["skeleton"],
			"family_mult": 1.5, "fx": "holy_smite", "color": Color(0.90, 0.80, 0.48) } },
	{ "id": "blessing_of_the_hearth", "name": "Blessing of the Hearth", "icon": "pixel:blessing_of_the_hearth",
		"cooldown": 3.0, "mana_cost": 15.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 10, "rank_levels": [10, 30, 50], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "hp_regen": 2.0, "group": "blessing",
			"fx": "holy_bloom", "color": Color(0.92, 0.84, 0.56) } },
	{ "id": "blessing_of_iron", "name": "Blessing of Iron", "icon": "pixel:blessing_of_iron",
		"cooldown": 3.0, "mana_cost": 15.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 18, "rank_levels": [], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "armor": 4.0, "group": "blessing",
			"fx": "holy_bloom", "color": Color(0.78, 0.74, 0.62) } },
	{ "id": "cleanse", "name": "Cleanse", "icon": "pixel:cleanse",
		"cooldown": 10.0, "mana_cost": 14.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 14, "rank_levels": [], "trainer_verb": "dispel",
		"params": { "duration": 0.1, "dispel_schools": ["poison", "disease", "curse"], "dispel_count": 1,
			"fx": "holy_bloom", "color": Color(0.94, 0.90, 0.70) } },
	{ "id": "hammer_of_the_gallows", "name": "Hammer of the Gallows", "icon": "pixel:hammer_of_the_gallows",
		"cooldown": 22.0, "mana_cost": 20.0, "range": 200.0, "damage": 10.0, "kind": "projectile",
		"req_level": 24, "rank_levels": [24, 44], "trainer_verb": "stun",
		"params": { "speed": 240.0, "projectile": "bolt", "root_on_hit": 1.5, "interrupt": true,
			"fx": "hammer_blow", "fx_tint": Color(1.0, 0.90, 0.55), "color": Color(0.92, 0.78, 0.44) } },
	{ "id": "aegis_step", "name": "Aegis Step", "icon": "pixel:aegis_step",
		"cooldown": 18.0, "mana_cost": 16.0, "range": 80.0, "damage": 0.0, "kind": "dash",
		"req_level": 32, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "arrive_absorb": 25.0, "fx": "shield_charge", "fx_tint": Color(0.90, 0.80, 0.50),
			"color": Color(0.88, 0.76, 0.46) } },
	{ "id": "litany_of_dawn", "name": "Litany of Dawn", "icon": "pixel:litany_of_dawn",
		"cooldown": 30.0, "mana_cost": 35.0, "range": 55.0, "damage": 14.0, "kind": "aoe_ring",
		"req_level": 42, "rank_levels": [42, 56], "trainer_verb": "special",
		"params": { "at_aim": false, "heal_per_enemy_hit": 6.0, "fx": "dawnbreak_pillar",
			"fx_tint": Color(0.98, 0.90, 0.60), "color": Color(0.94, 0.86, 0.54) } },
],
```

#### Paladin spell ledger — 44 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Hammer Blow (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Holy Smite | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Judgment | 8 | 8 / 20 / 32 / 44 / 56 | 5 |
| Consecration | 12 | 12 / 24 / 36 / 48 | 4 |
| Lay on Hands | 16 | 16 / 28 / 40 / 52 (heal ranks) | 4 |
| Divine Shield | 20 | 20 / 36 / 52 (absorb ranks) | 3 |
| Sacred Bulwark | 24 | 24 / 44 (absorb ranks) | 2 |
| Dawnbreak | 30 | 30 / 42 / 54 | 3 |
| Chapel's Censure | 6 | 6 / 26 / 46 | 3 |
| Blessing of the Hearth | 10 | 10 / 30 / 50 | 3 |
| Cleanse | 14 | — | 1 |
| Blessing of Iron | 18 | — | 1 |
| Hammer of the Gallows | 24 | 24 / 44 | 2 |
| Aegis Step | 32 | — | 1 |
| Litany of Dawn | 42 | 42 / 56 | 2 |
| **Total** | | | **44** ✓ band (ledgers count the learn level as rank I) |

*(Paladin kit is 8 abilities — Dawnbreak takes the §4.2 slot-8/L30 gate.)*

---

### 5.5 NECROMANCER — Warden of the Old Graves
Trees (owner-mandated names): **Thread** (command — the invisible leash Lilith taught the
world; will-driven shells, worked politely), **Grave** (attrition — drains, curses, and
debts the ledger can't close), **Bone** (defense/nova — the neighbors' donated armor).

#### Thread (command / minions)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Threadwise | 5 | passive | `mana_regen +0.4` | |
| 1 (0) | Steady Hands | 3 | passive | `mana +8` | |
| 2 (5) | Firmer Knots | 5 | ability_mod | Raise Dead `add_params.minion_damage +1` | 6 → 11 at max |
| 2 (5) | Longer Leash | 2 | ability_mod | Raise Dead `add_params.lifetime +5` | 20 s → 30 s |
| 3 (10) | Sturdier Puppets | 3 | ability_mod | Raise Dead `add_params.minion_hp +8` | 35 → 59 |
| 3 (10) | Spare Thread | 2 | proc | on `kill`: `cdr {raise_dead, 2.0 s}` | icd 0 — chain-pull economy |
| 4 (15) | Two Graves Deep | 3 | passive | your minions' damage +4% | minion-scoped passive (§7.2) |
| 4 (15) | Quiet Work | 2 | ability_mod | Raise Dead `mana_cost_pct -10` | |
| 5 (20) | Warden's Etiquette | 3 | passive | `damage_dealt_pct +2` while a minion of yours lives | conditional passive (§3) |
| 5 (20) | Second Shovel | 2 | ability_mod | rank 2: Raise Dead `add_params.max_active` 1 → **2** | rank 1 = minions taunt-pulse on summon |
| 6 (25) | Tucked Back In | 3 | proc | on `minion_death` (yours), 33%/rank: refund 15 mana + heal 3% max hp | new proc event (§7.2); "always tucks them back in" |
| 7 (30) | **The Threaded Host** | 1 | ability | capstone below | |

```gdscript
{ "id": "threaded_host", "name": "The Threaded Host", "icon": "pixel:threaded_host",
	"cooldown": 60.0, "mana_cost": 50.0, "range": 80.0, "damage": 0.0, "kind": "summon",
	"params": { "minion_type": "skeleton", "count": 3, "lifetime": 15.0, "minion_hp": 30.0,
		"minion_damage": 7.0, "minion_speed": 80.0, "fx": "raise_dead", "fx_loop": "raise_dead_loop",
		"fx_tint": Color(0.40, 0.58, 0.34), "color": Color(0.48, 0.70, 0.40) } },
```

#### Grave (attrition / drain)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Grave-Tender's Patience | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Cold Comfort | 3 | passive | `hp_regen +0.4` | |
| 2 (5) | Deeper Draw | 5 | ability_mod | Drain Life `damage_pct +3` | |
| 2 (5) | Thirsty Roots | 2 | ability_mod | Drain Life `add_params.lifesteal +0.05` | 0.35 → 0.45 |
| 3 (10) | Old Debts | 3 | proc | on `kill`, 100%: heal 2%/rank max hp | icd 0 |
| 3 (10) | Wider Pall | 2 | ability_mod | Withering Curse `range_pct +10` | ring radius |
| 4 (15) | Lead in the Veins | 3 | passive | your curse/shadow school ticks +4% | school-scoped passive (§7.2) |
| 4 (15) | Grave Economy | 2 | ability_mod | Withering Curse `mana_cost_pct -10` | |
| 5 (20) | Both Feet in the Earth | 3 | passive | `damage_dealt_pct +2` vs slowed/rooted/cursed targets | the necro Shatter |
| 5 (20) | Unfinished Business | 2 | proc | on `hit_taken` below 35% hp, 50%/rank: free Drain Life (`cdr {drain_life, full}`) | icd 15 s |
| 6 (25) | The Ledger Never Closes | 3 | passive | ALL damage you deal leeches +1%/rank as healing | lifesteal bucket (§7.2) |
| 7 (30) | **Grave-Debt** | 1 | ability | capstone below | |

```gdscript
{ "id": "grave_debt", "name": "Grave-Debt", "icon": "pixel:grave_debt",
	"cooldown": 30.0, "mana_cost": 35.0, "range": 220.0, "damage": 34.0, "kind": "projectile",
	"params": { "speed": 200.0, "projectile": "soul_bolt", "lifesteal": 1.0,
		"reset_on_kill": true, "fx": "grave_debt", "fx_tint": Color(0.54, 0.36, 0.62),
		"color": Color(0.56, 0.38, 0.64) } },
```
*(`reset_on_kill`: if the bolt kills, the cooldown refunds — a debt collected closes the
entry. The one mechanic in the game named for what Kriggar is.)*

#### Bone (defense / nova)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Marrow Lessons | 5 | passive | `armor +1` | |
| 1 (0) | Calcified Will | 3 | passive | `stamina +2` | |
| 2 (5) | Sharper Splinters | 5 | ability_mod | Bone Nova `damage_pct +4` | |
| 2 (5) | Wide Scatter | 2 | ability_mod | Bone Nova `range_pct +8` | 55 → 64 px |
| 3 (10) | Splinter Guard | 3 | proc | on `hit_taken`, 8%/rank: absorb 5% max hp, 4 s | icd 6 s |
| 3 (10) | Heavier Plating | 2 | ability_mod | Bone Armor `add_params.absorb +8` | |
| 4 (15) | Ossified | 3 | passive | `max_hp_pct +2` | |
| 4 (15) | Cheap Calcium | 2 | ability_mod | Bone Armor `cooldown_pct -10`, `mana_cost_pct -10` | |
| 5 (20) | Jagged Mantle | 3 | passive | while Bone Armor holds: melee attackers take 3 flat/rank per hit | conditional thorns (§7.2) |
| 5 (20) | Numb to It | 2 | passive | slow/root durations on you -10% | |
| 6 (25) | Splinter Reflex | 3 | proc | when your absorb breaks, 33%/rank: free self-centered Bone Nova | new proc event `absorb_break` (§7.2), icd 10 s |
| 7 (30) | **Ossuary Cage** | 1 | ability | capstone below | |

```gdscript
{ "id": "ossuary_cage", "name": "Ossuary Cage", "icon": "pixel:ossuary_cage",
	"cooldown": 35.0, "mana_cost": 45.0, "range": 48.0, "damage": 26.0, "kind": "aoe_ring",
	"params": { "at_aim": true, "cast_range": 130.0, "root_duration": 2.0,
		"fx": "bone_nova", "fx_tint": Color(0.86, 0.84, 0.74), "color": Color(0.82, 0.80, 0.72) } },
```

#### Necromancer — 7 new trained spells
```gdscript
"necromancer": [
	{ "id": "corpse_lance", "name": "Corpse Lance", "icon": "pixel:corpse_lance",
		"cooldown": 7.0, "mana_cost": 8.0, "range": 240.0, "damage": 9.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "pull",
		"params": { "speed": 300.0, "projectile": "soul_bolt", "thin": true, "slow_mult": 0.75,
			"slow_duration": 2.0, "fx": "corpse_lance", "color": Color(0.70, 0.72, 0.62) } },
	{ "id": "corpse_pact", "name": "Corpse Pact", "icon": "pixel:corpse_pact",
		"cooldown": 25.0, "mana_cost": 10.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 10, "rank_levels": [], "trainer_verb": "defensive",
		"params": { "duration": 0.1, "consume_minion": true, "heal_pct_max_hp": 25.0,
			"fx": "raise_dead", "fx_tint": Color(0.46, 0.62, 0.38), "color": Color(0.48, 0.64, 0.40) } },
	{ "id": "stifle", "name": "Stifle", "icon": "pixel:stifle",
		"cooldown": 18.0, "mana_cost": 15.0, "range": 220.0, "damage": 0.0, "kind": "projectile",
		"req_level": 14, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "speed": 420.0, "projectile": "soul_bolt", "thin": true, "interrupt": true,
			"silence_duration": 2.0, "fx": "stifle", "color": Color(0.44, 0.50, 0.44) } },
	{ "id": "curse_of_lead", "name": "Curse of Lead", "icon": "pixel:curse_of_lead",
		"cooldown": 14.0, "mana_cost": 16.0, "range": 200.0, "damage": 0.0, "kind": "projectile",
		"req_level": 18, "rank_levels": [18, 38], "trainer_verb": "snare",
		"params": { "speed": 400.0, "projectile": "soul_bolt", "thin": true,
			"slow_mult": 0.7, "slow_duration": 8.0, "enemy_damage_dealt_pct": -10.0, "debuff_duration": 8.0,
			"fx": "withering_curse", "fx_tint": Color(0.48, 0.50, 0.42), "color": Color(0.50, 0.52, 0.44) } },
	{ "id": "wraithwalk", "name": "Wraithwalk", "icon": "pixel:wraithwalk",
		"cooldown": 22.0, "mana_cost": 14.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 28, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "duration": 3.0, "speed_mult": 1.5, "break_snares": true,
			"fx": "shadowstep", "fx_tint": Color(0.36, 0.44, 0.38), "color": Color(0.40, 0.48, 0.42) } },
	{ "id": "gravekeepers_patience", "name": "Gravekeeper's Patience", "icon": "pixel:gravekeepers_patience",
		"cooldown": 3.0, "mana_cost": 18.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 34, "rank_levels": [], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "hp_regen": 1.5, "mana_regen": 1.5, "group": "blessing",
			"fx_loop": "bone_ward", "fx_tint": Color(0.58, 0.66, 0.48), "color": Color(0.58, 0.66, 0.48) } },
	{ "id": "borrowed_shroud", "name": "Borrowed Shroud", "icon": "pixel:borrowed_shroud",
		"cooldown": 60.0, "mana_cost": 20.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 42, "rank_levels": [], "trainer_verb": "special",
		"params": { "duration": 4.0, "untargetable": true, "speed_mult": 0.6,
			"fx": "shroud", "fx_tint": Color(0.30, 0.34, 0.30), "color": Color(0.36, 0.40, 0.36) } },
],
```
*(Borrowed Shroud = the necromancer's feign: enemies drop him from their aggro table for
4 s while he shuffles off looking convincingly dead. Cancelled by casting.)*

#### Necromancer spell ledger — 42 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Soul Bolt (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Drain Life | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Withering Curse | 8 | 8 / 20 / 32 / 44 / 56 | 5 |
| Bone Nova | 12 | 12 / 24 / 36 / 48 | 4 |
| Grave Grasp | 16 | 16 / 28 / 40 / 52 | 4 |
| Bone Armor | 20 | 20 / 36 / 52 (absorb ranks) | 3 |
| Raise Dead | 24 | 24 / 36 / 48 (minion ranks) | 3 |
| Soul Harvest | 30 | 30 / 42 / 54 | 3 |
| Corpse Lance | 6 | 6 / 26 / 46 | 3 |
| Corpse Pact | 10 | — | 1 |
| Stifle | 14 | — | 1 |
| Curse of Lead | 18 | 18 / 38 | 2 |
| Wraithwalk | 28 | — | 1 |
| Gravekeeper's Patience | 34 | — | 1 |
| Borrowed Shroud | 42 | — | 1 |
| **Total** | | | **42** ✓ band |

*(Necromancer kit is 8 abilities — Soul Harvest takes the §4.2 slot-8/L30 gate.)*

---

### 5.6 ROOKWARDEN (Hunter) — Rookwarden of the Hollow
Trees: **Gallows-Eye** (marksman — chosen at the gallows-tree, and the eye that earned it),
**Rookery** (companion — the rooks choose one warden a generation), **Snarewood**
(traps/survival — the weathered coat, the wire, the paths only wardens walk).

#### Gallows-Eye (marksman)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Dead Eye | 5 | passive | `crit_pct +1` | |
| 1 (0) | Fletcher's Care | 3 | passive | `damage_dealt_pct +1` | |
| 2 (5) | Heavier Draw | 5 | ability_mod | Piercing Shot `damage_pct +3` | |
| 2 (5) | Long Sight | 2 | ability_mod | Loosed Arrow `range_pct +6` | 260 → 291 px |
| 3 (10) | Gallows Patience | 3 | passive | `damage_dealt_pct +2` vs targets beyond 140 px | conditional passive (§3); rewards range discipline |
| 3 (10) | Clean Pierce | 2 | ability_mod | Piercing Shot `add_params.aoe_radius +6` | 20 → 32 px |
| 4 (15) | Raven's Whisper | 3 | proc | on `crit`, 33%/rank: next Loosed Arrow +50% (one shot) | icd 3 s |
| 4 (15) | Quick Quiver | 2 | ability_mod | Piercing Shot `cooldown_pct -10` | 6 s → 4.8 s |
| 5 (20) | Marked for the Rope | 3 | ability_mod | Hunter's Mark `add_params.damage_mult +0.05` | 1.35 → 1.50 at max |
| 5 (20) | One Loosed Breath | 2 | passive | crit multiplier +0.05 | crit-mult hook (§7.2) |
| 6 (25) | The Rooks Point | 3 | proc | on `kill`, 33%/rank: free Piercing Shot (`cdr {piercing_shot, full}`) + `speed_pct +6` 4 s | icd 6 s |
| 7 (30) | **Gallows Shot** | 1 | ability | capstone below | |

```gdscript
{ "id": "gallows_shot", "name": "Gallows Shot", "icon": "pixel:gallows_shot",
	"cooldown": 25.0, "mana_cost": 28.0, "range": 320.0, "damage": 36.0, "kind": "projectile",
	"params": { "speed": 460.0, "projectile": "arrow", "thin": true,
		"execute_below": 0.35, "execute_mult": 2.5, "fx": "gallows_shot",
		"fx_tint": Color(0.30, 0.34, 0.38), "color": Color(0.30, 0.44, 0.48) } },
```

#### Rookery (companion)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Carrion Bond | 5 | passive | `mana_regen +0.4` | |
| 1 (0) | Feathered Watch | 3 | passive | `speed_pct +1` | |
| 2 (5) | Stronger Wings | 5 | ability_mod | Rook Companion `add_params.minion_damage +1` | 8 → 13 |
| 2 (5) | Longer Visit | 2 | ability_mod | Rook Companion `add_params.lifetime +4` | 18 s → 26 s |
| 3 (10) | Beak and Claw | 3 | ability_mod | Rook Companion `add_params.minion_hp +8` | 45 → 69 |
| 3 (10) | Shared Eyes | 2 | proc | on `minion_hit` (yours), 15%/rank: your next shot +20% (one shot) | new proc event (§7.2), icd 3 s |
| 4 (15) | Unkind Memory | 3 | passive | your minions' damage +4% | minion-scoped passive |
| 4 (15) | Whistle Economy | 2 | ability_mod | Rook Companion `cooldown_pct -10`, `mana_cost_pct -10` | |
| 5 (20) | Hunt as One | 3 | passive | `damage_dealt_pct +2` while your companion lives | conditional |
| 5 (20) | Second Rook | 2 | ability_mod | rank 2: Rook Companion `add_params.max_active` 1 → **2** | rank 1 = rook revives once per summon at 50% hp |
| 6 (25) | Fed at the Gallows | 3 | proc | on `kill`, 33%/rank: rook heals to full + its damage +15% for 5 s | icd 0 |
| 7 (30) | **The Unkindness** | 1 | ability | capstone below | |

```gdscript
{ "id": "the_unkindness", "name": "The Unkindness", "icon": "pixel:the_unkindness",
	"cooldown": 45.0, "mana_cost": 45.0, "range": 130.0, "damage": 10.0, "kind": "volley",
	"params": { "count": 16, "pattern": "rain", "radius": 60.0, "duration": 1.8, "speed": 280.0,
		"projectile": "arrow_storm", "fx": "the_unkindness", "fx_tint": Color(0.16, 0.17, 0.20),
		"color": Color(0.22, 0.26, 0.30) } },
```
*(Sixteen ravens fall on the area like a verdict — an unkindness is the collective noun,
and the rooks are never wrong.)*

#### Snarewood (traps / survival)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Warden's Paths | 5 | passive | `speed_pct +1` | |
| 1 (0) | Weathered Coat | 3 | passive | `damage_taken_pct -1` | |
| 2 (5) | Cruel Teeth | 5 | ability_mod | Snare Trap `damage_pct +6` | |
| 2 (5) | Wider Jaws | 2 | ability_mod | Snare Trap `range_pct +10` | ring radius |
| 3 (10) | Patient Wire | 3 | ability_mod | Snare Trap `add_params.root_duration +0.2` | 1.6 → 2.2 s |
| 3 (10) | Light Step | 2 | ability_mod | Raven Dash `cooldown_pct -10` | 5 s → 4 s |
| 4 (15) | Living off the Hollow | 3 | passive | `hp_regen +0.5` | |
| 4 (15) | Feathered Escape | 2 | proc | on `hit_taken`, 8%/rank: free Raven Dash (`cdr {raven_dash, full}`) | icd 10 s |
| 5 (20) | Forager's Constitution | 3 | passive | `max_hp_pct +2` | |
| 5 (20) | Double Line | 2 | ability_mod | rank 2: Snare Trap `add_params.charges` 1 → **2** | rank 1 = trap arms 30% faster |
| 6 (25) | The Wood Remembers | 3 | passive | `damage_dealt_pct +2` vs rooted/slowed targets | the hunter Shatter — traps feed shots |
| 7 (30) | **Warden's Snarewood** | 1 | ability | capstone below | |

```gdscript
{ "id": "wardens_snarewood", "name": "Warden's Snarewood", "icon": "pixel:wardens_snarewood",
	"cooldown": 40.0, "mana_cost": 40.0, "range": 55.0, "damage": 4.0, "kind": "aoe_ring",
	"params": { "at_aim": true, "cast_range": 140.0, "root_duration": 1.5,
		"tick_interval": 0.5, "duration": 4.0, "slow_mult": 0.5, "slow_duration": 2.0,
		"fx": "snare_trap", "fx_tint": Color(0.38, 0.50, 0.30), "color": Color(0.42, 0.54, 0.34) } },
```

#### Rookwarden — 7 new trained spells
```gdscript
"rookwarden": [
	{ "id": "barbed_arrow", "name": "Barbed Arrow", "icon": "pixel:barbed_arrow",
		"cooldown": 9.0, "mana_cost": 12.0, "range": 260.0, "damage": 6.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "dot",
		"params": { "speed": 320.0, "projectile": "arrow", "thin": true,
			"bleed_per_sec": 3.0, "bleed_duration": 6.0, "fx": "barbed_arrow",
			"color": Color(0.62, 0.50, 0.40) } },
	{ "id": "concussive_shot", "name": "Concussive Shot", "icon": "pixel:concussive_shot",
		"cooldown": 10.0, "mana_cost": 12.0, "range": 240.0, "damage": 7.0, "kind": "projectile",
		"req_level": 10, "rank_levels": [10, 30, 50], "trainer_verb": "snare",
		"params": { "speed": 300.0, "projectile": "arrow", "thin": true,
			"slow_mult": 0.5, "slow_duration": 4.0, "fx": "concussive_shot",
			"color": Color(0.58, 0.60, 0.56) } },
	{ "id": "salt_shot", "name": "Salt Shot", "icon": "pixel:salt_shot",
		"cooldown": 16.0, "mana_cost": 14.0, "range": 240.0, "damage": 4.0, "kind": "projectile",
		"req_level": 14, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "speed": 420.0, "projectile": "arrow", "thin": true, "interrupt": true,
			"fx": "salt_shot", "color": Color(0.80, 0.80, 0.76) } },
	{ "id": "disengage", "name": "Disengage", "icon": "pixel:disengage",
		"cooldown": 14.0, "mana_cost": 10.0, "range": 70.0, "damage": 0.0, "kind": "dash",
		"req_level": 18, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "feathers": true, "backward": true, "break_snares": true,
			"fx": "raven_dash", "color": Color(0.30, 0.50, 0.52) } },
	{ "id": "thicket_veil", "name": "Thicket Veil", "icon": "pixel:thicket_veil",
		"cooldown": 30.0, "mana_cost": 18.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 26, "rank_levels": [], "trainer_verb": "defensive",
		"params": { "duration": 6.0, "absorb": 35.0, "speed_mult": 1.15,
			"fx": "shroud", "fx_tint": Color(0.34, 0.44, 0.30), "color": Color(0.38, 0.48, 0.34) } },
	{ "id": "wardens_gait", "name": "Warden's Gait", "icon": "pixel:wardens_gait",
		"cooldown": 3.0, "mana_cost": 16.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 36, "rank_levels": [], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "speed_pct": 6.0, "crit_pct": 2.0, "group": "aspect",
			"fx_loop": "rook_companion_loop", "fx_tint": Color(0.26, 0.42, 0.44),
			"color": Color(0.28, 0.46, 0.48) } },
	{ "id": "flush_the_quarry", "name": "Flush the Quarry", "icon": "pixel:flush_the_quarry",
		"cooldown": 25.0, "mana_cost": 18.0, "range": 46.0, "damage": 0.0, "kind": "aoe_ring",
		"req_level": 44, "rank_levels": [], "trainer_verb": "special",
		"params": { "at_aim": true, "cast_range": 150.0, "mark_damage_taken_pct": 10.0,
			"mark_duration": 8.0, "reveal_stealth": true, "fx": "flush_the_quarry",
			"fx_tint": Color(0.52, 0.58, 0.42), "color": Color(0.50, 0.56, 0.40) } },
],
```

#### Rookwarden spell ledger — 37 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Loosed Arrow (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Piercing Shot | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Snare Trap | 8 | 8 (utility) | 1 |
| Raven Dash | 12 | 12 (utility) | 1 |
| Hunter's Mark | 16 | 16 / 28 / 40 / 52 (mult ranks, WoW-style) | 4 |
| Rook Companion | 20 | 20 / 32 / 44 / 56 (minion ranks) | 4 |
| Arrow Storm | 24 | 24 / 36 / 48 | 3 |
| Storm of Feathers | 30 | 30 / 42 / 54 | 3 |
| Barbed Arrow | 6 | 6 / 26 / 46 | 3 |
| Concussive Shot | 10 | 10 / 30 / 50 | 3 |
| Salt Shot | 14 | — | 1 |
| Disengage | 18 | — | 1 |
| Thicket Veil | 26 | — | 1 |
| Warden's Gait | 36 | — | 1 |
| Flush the Quarry | 44 | — | 1 |
| **Total** | | | **37** ✓ band |

*(Rookwarden kit is 8 abilities — Storm of Feathers takes the §4.2 slot-8/L30 gate.)*

---

### 5.7 DRUID — Warden of the Wildwood
Trees: **Wildwood** (feral — root and claw; the forest older than the walls),
**Stormcall** (balance/storm — gale and thunder answer her call), **Mirebloom**
(restoration — the blight crept up out of the mire, and she is what pushes it back).

#### Wildwood (feral)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Thick Hide | 5 | passive | `armor +1` | |
| 1 (0) | Old Strength | 3 | passive | `damage_dealt_pct +1` | |
| 2 (5) | Heavier Paw | 5 | ability_mod | Maul `damage_pct +3` | |
| 2 (5) | Broad Swipe | 2 | ability_mod | Maul `add_params.arc_degrees +10` | 115° → 135° |
| 3 (10) | Rending Claws | 3 | proc | on `crit`: bleed 4 s, 3%/rank of the crit per s | shares StatusDefs `talent_bleed` |
| 3 (10) | Longer Rage | 2 | ability_mod | Bear Form `duration_pct +15` | 8 s → 10.4 s |
| 4 (15) | Wild Constitution | 3 | passive | `max_hp_pct +2` | |
| 4 (15) | Bear's Economy | 2 | ability_mod | Bear Form `cooldown_pct -10`, `mana_cost_pct -10` | |
| 5 (20) | Scarred Bark | 3 | passive | `damage_taken_pct -1` | |
| 5 (20) | Forest's Fury | 2 | ability_mod | Bear Form `add_params.damage_mult +0.05` | 1.4 → 1.5 |
| 6 (25) | Apex Memory | 3 | proc | on `kill`: heal 2%/rank max hp + `speed_pct +5` 4 s | icd 0 |
| 7 (30) | **The Forest's Price** | 1 | ability | capstone below | |

```gdscript
{ "id": "forests_price", "name": "The Forest's Price", "icon": "pixel:forests_price",
	"cooldown": 90.0, "mana_cost": 45.0, "range": 0.0, "damage": 0.0, "kind": "buff",
	"params": { "duration": 12.0, "damage_mult": 1.5, "speed_mult": 1.15, "absorb": 60.0,
		"group": "form", "price_hp_pct": 10.0, "fx": "bear_form",
		"fx_tint": Color(0.42, 0.34, 0.22), "color": Color(0.48, 0.38, 0.26) } },
```
*(`price_hp_pct`: when the form ends, the forest takes 10% of your max hp — it always
names its price. Cannot kill; leaves you at 1 hp minimum.)*

#### Stormcall (balance / storm)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Sky Reader | 5 | passive | `damage_dealt_pct +1` | |
| 1 (0) | Charged Air | 3 | passive | `mana +8` | |
| 2 (5) | Gathering Gale | 5 | ability_mod | Gale `damage_pct +3` | |
| 2 (5) | Split Wind | 2 | ability_mod | Gale `add_params.aoe_radius +5` | 26 → 36 px |
| 3 (10) | Static Recoil | 3 | proc | on `hit_taken`, 10%/rank: attacker slowed 30%, 2 s | icd 2 s |
| 3 (10) | Thunder Weight | 2 | ability_mod | Stormbolt `damage_pct +6` | |
| 4 (15) | Storm Sight | 3 | passive | `crit_pct +1` | |
| 4 (15) | Far Front | 2 | ability_mod | Stormbolt `add_params.cast_range +20` | 200 → 240 px |
| 5 (20) | Grounded Prey | 3 | passive | `damage_dealt_pct +2` vs slowed/rooted targets | the druid Shatter |
| 5 (20) | Rolling Thunder | 2 | proc | on `ability:stormbolt` hit, 50%/rank: `cdr {gale, full}` | icd 4 s |
| 6 (25) | Tempest Momentum | 3 | proc | on `kill` with storm spells, 33%/rank: next Stormbolt free | icd 6 s |
| 7 (30) | **Skybreak** | 1 | ability | capstone below | |

```gdscript
{ "id": "skybreak", "name": "Skybreak", "icon": "pixel:skybreak",
	"cooldown": 35.0, "mana_cost": 50.0, "range": 44.0, "damage": 42.0, "kind": "aoe_ring",
	"params": { "at_aim": true, "cast_range": 200.0, "slow_mult": 0.5, "slow_duration": 3.0,
		"fx": "skybreak", "fx_tint": Color(0.74, 0.82, 0.94), "color": Color(0.68, 0.78, 0.90) } },
```

#### Mirebloom (restoration)
| Tier | Talent | Rks | Kind | Per rank | Notes |
|---|---|---|---|---|---|
| 1 (0) | Mire Lessons | 5 | passive | `mana_regen +0.4` | |
| 1 (0) | Deep Roots | 3 | passive | `stamina +2` | |
| 2 (5) | Fuller Bloom | 5 | ability_mod | Rejuvenation `add_params.heal_per_sec +1` | 7 → 12 |
| 2 (5) | Longer Season | 2 | ability_mod | Rejuvenation `duration_pct +15` | 6 s → 7.8 s |
| 3 (10) | Blightwarden | 3 | passive | poison/disease durations on you -10% | the anti-blight vow |
| 3 (10) | Thorn Tithe | 2 | ability_mod | Thornroot `damage_pct +8` | |
| 4 (15) | Green Clarity | 3 | proc | on `cast`, 4%/rank: next spell costs 0 mana | icd 4 s (Clearcasting mirror) |
| 4 (15) | Pact Vigor | 2 | ability_mod | Spirit Beast `add_params.minion_hp +8` | 42 → 58 |
| 5 (20) | The Wood Provides | 3 | passive | healing you cast +4% | heal-amp bucket (§7.2) |
| 5 (20) | Waking Wrath | 2 | proc | when your own spell heals you: `damage_dealt_pct +6` for 3 s | icd 3 s; resto druids still bite |
| 6 (25) | Second Sap | 3 | proc | on `hit_taken` below 35% hp, 33%/rank: free Rejuvenation (`cdr {rejuvenation, full}`) | icd 20 s |
| 7 (30) | **Heartwood Bloom** | 1 | ability | capstone below | |

```gdscript
{ "id": "heartwood_bloom", "name": "Heartwood Bloom", "icon": "pixel:heartwood_bloom",
	"cooldown": 45.0, "mana_cost": 50.0, "range": 50.0, "damage": 10.0, "kind": "aoe_ring",
	"params": { "at_aim": false, "tick_interval": 0.5, "duration": 6.0, "self_heal_per_tick": 5.0,
		"fx": "heal_bloom", "fx_loop": "spirit_beast_loop", "fx_tint": Color(0.52, 0.76, 0.46),
		"color": Color(0.50, 0.74, 0.44) } },
```

#### Druid — 7 new trained spells
```gdscript
"druid": [
	{ "id": "thornlash", "name": "Thornlash", "icon": "pixel:thornlash",
		"cooldown": 7.0, "mana_cost": 8.0, "range": 220.0, "damage": 8.0, "kind": "projectile",
		"req_level": 6, "rank_levels": [6, 26, 46], "trainer_verb": "pull",
		"params": { "speed": 280.0, "projectile": "spark", "thin": true, "slow_mult": 0.75,
			"slow_duration": 2.0, "fx": "thornlash", "color": Color(0.44, 0.56, 0.32) } },
	{ "id": "clinging_mire", "name": "Clinging Mire", "icon": "pixel:clinging_mire",
		"cooldown": 15.0, "mana_cost": 20.0, "range": 44.0, "damage": 0.0, "kind": "aoe_ring",
		"req_level": 10, "rank_levels": [], "trainer_verb": "snare",
		"params": { "at_aim": true, "cast_range": 140.0, "slow_mult": 0.45, "slow_duration": 4.0,
			"fx": "clinging_mire", "fx_tint": Color(0.36, 0.42, 0.28), "color": Color(0.38, 0.44, 0.30) } },
	{ "id": "skyclap", "name": "Skyclap", "icon": "pixel:skyclap",
		"cooldown": 16.0, "mana_cost": 14.0, "range": 30.0, "damage": 5.0, "kind": "aoe_ring",
		"req_level": 14, "rank_levels": [], "trainer_verb": "interrupt",
		"params": { "at_aim": true, "cast_range": 160.0, "interrupt": true,
			"fx": "stormbolt", "fx_tint": Color(0.76, 0.84, 0.94), "color": Color(0.72, 0.80, 0.90) } },
	{ "id": "cleanse_blight", "name": "Cleanse Blight", "icon": "pixel:cleanse_blight",
		"cooldown": 10.0, "mana_cost": 14.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 18, "rank_levels": [], "trainer_verb": "dispel",
		"params": { "duration": 0.1, "dispel_schools": ["poison", "disease"], "dispel_count": 1,
			"fx": "heal_bloom", "color": Color(0.56, 0.74, 0.48) } },
	{ "id": "stag_form", "name": "Stag Form", "icon": "pixel:stag_form",
		"cooldown": 6.0, "mana_cost": 12.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 22, "rank_levels": [], "trainer_verb": "mobility",
		"params": { "duration": 10.0, "speed_mult": 1.4, "break_snares": true, "group": "form",
			"cancel_on_cast": true, "fx": "spirit_beast", "fx_tint": Color(0.52, 0.60, 0.42),
			"color": Color(0.50, 0.58, 0.40) } },
	{ "id": "barkskin", "name": "Barkskin", "icon": "pixel:barkskin",
		"cooldown": 30.0, "mana_cost": 20.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 34, "rank_levels": [], "trainer_verb": "defensive",
		"params": { "duration": 8.0, "damage_taken_pct": -20.0,
			"fx_loop": "bone_ward", "fx_tint": Color(0.46, 0.42, 0.30), "color": Color(0.48, 0.44, 0.32) } },
	{ "id": "mark_of_the_wildwood", "name": "Mark of the Wildwood", "icon": "pixel:mark_of_the_wildwood",
		"cooldown": 3.0, "mana_cost": 18.0, "range": 0.0, "damage": 0.0, "kind": "buff",
		"req_level": 42, "rank_levels": [42, 56], "trainer_verb": "long_buff",
		"params": { "duration": 600.0, "stamina": 4.0, "hp_regen": 1.0, "group": "blessing",
			"fx": "heal_bloom", "color": Color(0.42, 0.58, 0.36) } },
],
```

#### Druid spell ledger — 41 trained entries
| Spell | Learn | Ranks at | Entries |
|---|---|---|---|
| Maul (basic) | 1 | 1 / 12 / 24 / 36 / 48 | 5 |
| Gale | 4 | 4 / 16 / 28 / 40 / 52 | 5 |
| Thornroot | 8 | 8 / 28 / 48 | 3 |
| Stormbolt | 12 | 12 / 24 / 36 / 48 | 4 |
| Rejuvenation | 16 | 16 / 28 / 40 / 52 (heal ranks) | 4 |
| Spirit Beast | 20 | 20 / 32 / 44 / 56 (minion ranks) | 4 |
| Bear Form | 24 | 24 / 40 / 56 (absorb ranks) | 3 |
| Tempest | 30 | 30 / 42 / 54 | 3 |
| Thornlash | 6 | 6 / 26 / 46 | 3 |
| Clinging Mire | 10 | — | 1 |
| Skyclap | 14 | — | 1 |
| Cleanse Blight | 18 | — | 1 |
| Stag Form | 22 | — | 1 |
| Barkskin | 34 | — | 1 |
| Mark of the Wildwood | 42 | 42 / 56 | 2 |
| **Total** | | | **41** ✓ band |

*(Druid kit is 8 abilities — Tempest takes the §4.2 slot-8/L30 gate.)*

---

## 6. CLASS TRAINERS — who teaches what, where

### 6.1 Trainer tiers (ZONE_QUEST_MATRIX bands)
A trainer teaches **every spellbook entry of their class whose level ≤ their tier cap**.
Tier caps track the region bands; the North teaches nothing by design (NPC_CAST: "the
North doesn't teach, it takes" — players train for northern content behind them).

| Tier | Region | Levels served | Cap |
|---|---|---|---|
| T1 Novice | Border ring (Raven Hollow + starter hubs) | 1–15 | 15 |
| T2 Journeyman | West — Angel Wings capital | 13–26 | 26 |
| T3 Adept | East — Blestem capital | 24–35 | 35 |
| T4 Expert | South — Sangeroasa capital | 33–44 | 44 |
| T5 Master | The Last Hearth (C2 safe hub) + capital grandmasters | 44–60 | 60 |

### 6.2 The trainer roster (existing NPC_CAST ids + 4 new)
NPC_CAST already fields class-taggable trainers; four **new** principal ids fill the
caster gaps (zone-prefixed snake_case per the id convention; `role_tags` additive):

| Id | Name | Zone | Teaches | Status |
|---|---|---|---|---|
| `rh_codrin` | Veteran Codrin | Raven Hollow | T1 martial: warrior, rogue, paladin, rookwarden | existing (`T(combat)`) |
| `rh_candlekeeper` | Candle-Keeper Anica | Raven Hollow | T1 caster: mage, necromancer, druid | **new** — keeps the chapel candles and older habits; "the candle answered her too, once" |
| `aw_captain` | Guard-Captain Osric | Angel Wings | T2 warrior + paladin | existing (`T(warrior)` += paladin) |
| `aw_healer` | Sister Casilda | Angel Wings | T2 paladin (Lantern tree flavor) | existing (`T(healer)`) |
| `aw_magistra` | Magistra Odeta | Angel Wings | T2 mage, necromancer, druid; T2 rogue+rookwarden via her "quiet door" clerk | **new** — council-licensed, teaches the violet fire officially and disapproves of it personally |
| `bl_handler` | Quarter-Handler Iepure | Blestem | T3 rogue | existing (`T(rogue)`) |
| `bl_chirurgeon` | Chirurgeon Alba | Blestem | T3 paladin/healer-side | existing (`T(healer)`) |
| `bl_listener` | The Listening Tutor | Blestem | T3 mage, necromancer, warrior, rookwarden, druid | **new** — Cazimir-web adjacent; teaches beautifully, reports attendance |
| `sg_huntmistress` | Hunt-Mistress Rada | Sangeroasa | T4 rookwarden | existing (`T(hunter)`) |
| `sg_forgemaster` | Forge-Master Hrodun | Sangeroasa | T4 warrior (the hammer as language) | existing (`T(smith)` += warrior) |
| `bf_shaman` | Cliff-Shaman Vraja | South (Boiling Fields) | T4 druid + necromancer | existing (`T(shaman)`) |
| `sg_bladedancer` | Pit-Mother Ancuța | Sangeroasa | T4 rogue, mage, paladin | **new** — runs the 1v1 arena's training floor; the Debt-Pit circuit's last honest coach |
| `lh_drillmother` | The Hearth Drill-Mother | The Last Hearth (C2) | **T5 ALL seven classes** | **new-adjacent** — the hearth-hall keeps the last of every discipline (Last Hearth is the 48–60 safe hub) |
| `bn_threadtender` | Thread-Tender Neluș | Black Night | necromancer lore-trainer: teaches nothing trainable, sells the *respec* ritual at cost | existing (`T(detection)`) — the North exception that proves the rule |
| `mr_trainer`, `gh_counter` | Blank-Face Bătrâna, The Counter-Teacher | C2 | T5 alternates: rogue / mage respectively | existing |

*(Net new principal ids: `rh_candlekeeper`, `aw_magistra`, `bl_listener`, `sg_bladedancer`
— 4, as budgeted in §1. `lh_drillmother` fills an existing Last Hearth roster slot from
NPC_CAST's C2 tables rather than adding a 5th principal.)*

### 6.3 Per-class chains (T1 → T5)
| Class | T1 (≤15) | T2 (≤26) | T3 (≤35) | T4 (≤44) | T5 (≤60) |
|---|---|---|---|---|---|
| Warrior | rh_codrin | aw_captain | bl_listener | sg_forgemaster | lh_drillmother |
| Rogue | rh_codrin | aw_magistra (quiet door) | bl_handler | sg_bladedancer | lh_drillmother / mr_trainer |
| Mage | rh_candlekeeper | aw_magistra | bl_listener | sg_bladedancer | lh_drillmother / gh_counter |
| Paladin | rh_codrin | aw_captain + aw_healer | bl_chirurgeon | sg_bladedancer | lh_drillmother |
| Necromancer | rh_candlekeeper | aw_magistra | bl_listener | bf_shaman | lh_drillmother (+ bn_threadtender, respec) |
| Rookwarden | rh_codrin | aw_magistra (quiet door) | bl_listener | sg_huntmistress | lh_drillmother |
| Druid | rh_candlekeeper | aw_magistra | bl_listener | bf_shaman | lh_drillmother |

Rhythm check: the §4.3 rank cadence (+12 levels) and §4.2 kit gates mean a player
outgrows a trainer's cap roughly once per region — the classic "ride back to town to
train" loop lands on the ZONE_QUEST_MATRIX travel spine without a single detour zone.
Trainer NPCs get `role_tags: ["T(<class>)"]` and a `trains: {class_id: tier_cap}` dict —
additive keys the current NPC loader ignores (NPC_CAST §5 registry pattern).

### 6.4 Trainer UI + quest hooks
- Reuse `dialogue_ui.gd` with a "Train" branch (the vendor pattern): list = every entry
  with `req_level`/rank level ≤ trainer cap, greyed if level-short, gold cost per §2.4.
- Each NEW spell taught fires a `quest_defs` hook (`train_<ability_id>`) so QUEST_ARCHITECTURE
  class quests can gate on it — the 🔄 "class starting experiences that TEACH the class"
  mandate plugs in here: the L4–L8 class quest chain walks the player from trainer to
  first kill with each early verb (feeds STARTING_ZONES).
- Capstones never appear at trainers (§2.4) — the talent UI grants them.

---

## 7. ENGINE DELTAS — everything above, costed

### 7.1 New ability params the resolver must learn (`player.gd` / `combat.gd`)
Grouped by mechanism; every param is CONCRETE-TOOLTIPS legible (exact numbers shown).

| Params | Mechanism | Cost |
|---|---|---|
| `interrupt`, `silence_duration` | on hit: cancel enemy cast (COMBAT_PACING §5.2 already defines cancel rules); silence = StatusDefs debuff blocking casts | S — enemy.gd has the cast state |
| `slow_mult`/`slow_duration`/`root_on_hit` on **projectile** kind | apply on impact (aoe_ring already does this) | S |
| `bleed_per_sec`/`bleed_duration`, `basic_burn_per_sec` | StatusDefs DoT instance on hit (talent_bleed/burn/poison/holyfire ids) | S — STATUS_EFFECTS pipeline |
| `execute_below`/`execute_mult` | damage mult when target hp% < threshold | S |
| `enemy_damage_dealt_pct` + `debuff_duration` | ring/projectile applies an enemy damage-down StatusDefs debuff | S |
| `mark_damage_taken_pct`/`mark_duration` (+`per_source`) | debuff: target takes +X% (from you only if per_source) | S |
| `lifesteal` (projectile — exists for drain_life), lifesteal bucket | heal caster for X× damage dealt | exists / S |
| `heal_pct_max_hp`, `self_heal_per_tick`, `heal_per_enemy_hit` | self-heal variants | S |
| `arrive_absorb` (dash), `reflect_pct`, `cc_immune`, `break_snares`, `untargetable` | buff/dash extras; untargetable = drop from enemy aggro + no new aggro | M — aggro-table touch in enemy.gd |
| `group` ("form"/"armor"/"blessing"/"aspect") | exclusive buff groups: applying one removes the group-mate | S |
| `duration: 600` long buffs | StatusEffects already handles timed buffs; persist through zone travel via save keys | S |
| `count`, `max_active`, `charges` | multi-summon; concurrent-minion cap; multi-charge ground spell | M — summon bookkeeping |
| `consume_minion` | Corpse Pact: kill your oldest minion as the cast cost (fails without one) | S |
| `single_pull`, `decoy`, `reveal_stealth` | aggro-only projectile; taunt-dummy summon; anti-stealth flag (future PvP) | M |
| `reset_on_kill`, `reset_cooldown`, `free_casts`, `cancel_on_cast` | cooldown/economy tricks | S each |
| `bonus_vs_families`/`family_mult`, `bonus_vs_bleeding_mult`, `bonus_vs_cc_mult`, `price_hp_pct` | conditional damage mults; end-of-buff cost | S |
| `backward` (dash) | dash away from aim instead of toward | S |
| `chill_attackers_mult`/`chill_duration` | Frost Armor: melee attackers get slowed | S |

### 7.2 Talent plumbing (beyond §3.4's hidden-status trick)
1. **Proc events**: emit `basic_hit`, `any_hit`, `crit`, `kill`, `dodge` (enemy whiff —
   `enemy.gd` strike re-check already knows), `hit_taken`, `cast`, `ability:<id>`,
   `minion_hit`, `minion_death`, `absorb_break` through one `Combat.proc_event(name, ctx)`
   bus; talents register listeners with chance + icd. **M** — the single biggest new piece.
2. **Crit**: CHARACTER_STATS owns `crit_pct`; talents need a crit-multiplier hook
   (base 1.5 + Twist the Blade / One Loosed Breath). **S**.
3. **Scoped passives**: school-scoped (+X% to poison/curse/fire ticks), minion-scoped
   (+X% minion damage), conditional `when` (`target_below_hp`, `night`, `range>140`,
   `while_minion_alive`, `while_absorb_holds`, `vs slowed/rooted`) — evaluated in the
   damage pipeline where StatusEffects potency already multiplies. **M**.
4. **Slow-amp / CC-duration hooks**: "your slows last +15%", "slow/root on you -10%" —
   two multipliers read at apply_slow/apply_root time. **S**.
5. **Heal-amp bucket**: `healing_done_pct` alongside `damage_dealt_pct`. **S**.

### 7.3 UI (new scenes, ornate-UI kit patterns)
1. **TalentTreeUI** — 3 tabs (trees), 3-column × 7-tier grid, rank pips, requires-arrows,
   point counter, respec button (trainer-gated). Data-driven from `TalentDefs`; the
   predecessor project's 3-column skill-tree layout is the visual reference. **L**.
2. **SpellbookUI** — trained entries grouped by `trainer_verb`, current rank shown
   (Fireball IV), drag/assign to action bar slots 2–8 (`action_bar` array, §3.3). **M**.
3. **Trainer dialogue branch** (§6.4). **S–M**.
4. **HUD**: no change — 8 slots stay; `hud.gd` reads `action_bar` instead of kit order. **S**.

### 7.4 Save / persistence
`talent_build`, `known_spells`, `action_bar`, `respec_count` (§3.3) ride the existing
dict-based `save_system.gd` path; long-buff remainders serialize with StatusEffects. **S**.

### 7.5 Rollout order
1. §3 schemas + rank law + kit re-gate + trainer dialogue (the book exists; world trains it).
2. §7.2.1 proc bus + hidden-status passives → TalentTreeUI (trees go live).
3. §7.1 param batch A (interrupt/snare/DoT/execute — the COMBAT_PACING curriculum answers).
4. Utility spells per class, batch by verb; §7.1 batch B (summon bookkeeping, decoy/pull).
5. Capstones + §8 re-audit playtest gates.

---

## 8. TTK COMPLIANCE AUDIT (COMBAT_PACING contract)

Reference: `PlayerRefDPS(L) = 25·1.046^(L-1)` **assumes the talented, normally-geared
rotation** (§2.3); normal-brute mob HP from COMBAT_PACING §4; TTK bands §2 there.

| L | Mob hp (brute) | RefDPS | TTK @Ref | Untalented (×0.87) | Full-offense ceiling (×1.15) | Band |
|---|---|---|---|---|---|---|
| 5 | 238 | 30 | 7.9 s | 9.1 s | 6.9 s* | 8–9 s ✓ (talents start at 10) |
| 20 | 634 | 59 | 10.7 s | 12.3 s | 9.3 s | 10–12 s ✓ |
| 40 | 1 570 | 145 | 10.8 s | 12.4 s | 9.4 s | 12–15 s ✓ (COMBAT_PACING's own ≈11 s midline) |
| 60 | 3 870 | 358 | 10.8 s | 12.4 s | 9.4 s | 12–15 s ✓ (their §4 sanity: ≈11 s) |

*L5 has zero talent points — the ×1.15 column doesn't exist below 10; bands hold exactly.

- **Offense ceiling**: +12% passive +3% proc (§2.3) = ×1.15 ⇒ fastest builds shave ~1.4 s
  off a 10.8 s fight — kills never drop below ~9.3 s, above the 8 s "real fight" floor.
- **Defense ceiling**: +15% EHP ⇒ facetank 28 s → ~32 s vs the ~30 s death-pressure law;
  two-mob facetank still lethal (2× incoming), pack math unchanged. ✓
- **Rank law is the curve, not a bonus**: Fireball base 22 learned at 8 → rank V at 56 =
  `22·1.046^48 ≈ 190` — ranks + gear + flat/level land inside the ±15% RefDPS tolerance
  ITEM_PROGRESSION budgets around; skipping trainer visits ≈ falling off the gear curve,
  the intended WoW-Classic pressure.
- **Capstones**: every capstone is a ≥20 s-cooldown button; amortized DPS contribution
  ≤4% (e.g. Pyroclasm: 40 base / 30 s vs Spark 9 / 0.5 s ≈ +7% burst, ~3.7% sustained).
  Burst windows vs elites/guarded (COMBAT_PACING §5.5) is exactly where they belong. ✓
- **CC creep check**: capstone roots (Ossuary Cage 2.0 s, Winter's Vice 2.0 s) stay under
  elite signature windups (1.1 s) + recovery — you buy one skipped mechanic, not a stunlock;
  root_duration on trash caps at 2.2 s talented (Patient Wire). ✓

## 9. SPELL-COUNT AUDIT (the "same number as WoW" mandate)

| Class | Kit entries | New-spell entries | Total trained | WoW-Classic band 30–45 |
|---|---|---|---|---|
| Warrior | 23 | 13 | **36** | ✓ |
| Rogue | 25 | 11 | **36** | ✓ |
| Mage | 30 | 15 | **45** | ✓ (fattest book — Classic mage feel) |
| Paladin | 31 | 13 | **44** | ✓ |
| Necromancer | 32 | 10 | **42** | ✓ |
| Rookwarden | 26 | 11 | **37** | ✓ |
| Druid | 31 | 10 | **41** | ✓ |
| **Average** | | | **40.1** | mid-band ✓ |

Every class: 14–15 distinct spells (7–8 kit + 7 trained utilities) + 2–3 talent capstone
abilities = **16–18 buttons known at 60**, 8 slotted — loadout choice without hardware
changes. Distinct-VFX law: all 21 capstones and 49 utility spells carry unique `fx` ids
(SPELL-VFX UNIQUENESS mandate — no palette-swaps; VFX_AAA_PLAN sources the sheets).

---

## 10. OPEN HOOKS FOR SIBLING DOCS
- **STARTING_ZONES**: L4–8 class-quest chains should each teach one §4.1 verb per quest,
  ending at the T1 trainer (the 🔄 class-experience mandate).
- **ITEM_PROGRESSION**: training gold (§2.4) joins repair/mount sinks in the gold-flow
  table; ~55g lifetime training spend per class at current cost law.
- **HIDDEN_DEBUFFS**: Cleanse / Cleanse Blight interact with hidden instances per its
  fairness laws (dispelling reveals the name — symptom-first surprise preserved).
- **PVP_RANKS_TITLES / arenas**: `reveal_stealth`, `per_source` marks, and CC-duration
  hooks are the PvP-safe versions, specced now to avoid a rework later.
- **QA_AUTOMATION**: `TalentDefs.validate()` + a headless audit script asserting §8's
  budget law over all 21 trees (sum per-rank passives ≤ tree caps) and §9's entry counts
  — run at build time like the 40-second rule.
