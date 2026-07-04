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
  **36–44 learnable-entries band** — WoW-Classic scale, audited in §9.
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

#### Warrior spell ledger (trainer list by level) — 41 trained entries
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

*(All classes ship basic + 7 kit abilities, so the §4.2 slot-8/L30 gate is unused;
the last kit ability trains at 24 game-wide.)*

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
