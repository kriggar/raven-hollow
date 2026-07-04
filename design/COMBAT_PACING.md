# COMBAT PACING — Fights That Teach
Raven Hollow · Draconia canon · level cap 60 · WoW-Classic pacing.
Grounded in: `scripts/combat.gd`, `scripts/enemy.gd`, `scripts/player.gd`,
`scripts/class_defs.gd`, `scripts/xp_system.gd`, `scripts/zone_defs.gd`, `WORLD_PLAN.md`.

Owner mandates served here:
- **No one-hit trash.** Every creature fight is 8s+ of real decisions at-level.
- **Every fight teaches the class** — creature families are tutors: wolves teach kiting,
  casters teach interrupt/gap-close, guarded bruisers teach burst windows, swarms teach AoE.
- Numbers below are paste-ready for `zone_defs.gd` / `combat.gd`; ability upgrades are an
  implementable checklist for `enemy.gd`.

---

## 1. Audit — why current combat fails the mandate

Measured from the live code:

| Fact | Source | Consequence |
|---|---|---|
| Mob HP 20–52 (wolf 30, boar 26, orc_warrior 52) | `zone_defs.gd` creature tables | Warrior Cleave = 12 dmg / 0.5 s ⇒ wolf dies in **3 swings ≈ 1.5 s**. One-hit trash feel. |
| Mob damage 5–11 per hit, one melee swing type | `zone_defs.gd`, `enemy.gd` | Warrior (140 hp, flat armor soak) needs ~20 unanswered hits ≈ 32 s to die. Zero death pressure. |
| Single enemy attack: 0.4 s windup → strike → 1.2 s cooldown | `enemy.gd` `WINDUP_TIME` / `ATTACK_COOLDOWN` | Only one behavior to learn; 0.4 s is below reaction threshold, so "dodging" never happens. |
| `skeleton_mage` / `orc_shaman` ("Entranced Pilgrim", "Cult Zealot") are **melee** with speed 18–24 | `enemy.gd` has no ranged/cast AI | Nothing in the world teaches interrupts, gap-close, or line-of-sight. |
| `player.take_damage`: `_invuln = INVULN_TIME` (0.5 s) after **any** hit | `player.gd:53,1094` | Incoming DPS is hard-capped at 2 hits/sec **total** — a wolf pack of 3 hits no harder than 1.2 wolves. Packs can never threaten. Must fix (§9.1). |
| Dodge check exists: strike re-checks `HIT_RANGE` (30 px) at windup end | `enemy.gd:_tick_windup` | Good bones — telegraphs just need to be long enough to react to. Keep this mechanism. |
| Aggro 120 px, leash 280 px, wolves ×2 aggro at night | `enemy.gd` | Good bones — extend per-archetype (§5). |
| Kill XP flat per family (skeleton 12 … bear 60), cap 10, 1.6× curve | `xp_system.gd` | Doesn't scale to 60; no level-difference falloff (gray mobs). §8 re-anchors. |

**Verdict:** the state machine, telegraph plumbing (windup + tint + lean + strike-time range
re-check), CC hooks (`apply_slow`/`apply_root`), faction-aware `Combat.Projectile` (already
targets group `"player"` when `faction != "player"`), and Nameplate are all reusable. What's
missing is: HP/damage an order of magnitude too low, enemy ability variety, and pack pressure.

---

## 2. Target TTK per bracket (the pacing contract)

TTK = time-to-kill an **at-level** mob by a normally-geared player of that level, playing the
rotation (not just basic-attack mashing). "Real decisions" = at least one dodge, one
cooldown choice, and one positioning choice per fight.

| Rank | TTK at-level | Decisions the fight must force | Player HP cost (played well) |
|---|---|---|---|
| Normal (levels 1–5) | **8–9 s** | 1 telegraph dodge OR 1 ability weave | 15–30 % |
| Normal (levels 6–20) | **10–12 s** | dodge + resource choice + positioning | 20–35 % |
| Normal (21–60) | **12–15 s** | full loop: opener, dodge, CC, burst window | 20–35 % |
| **Elite** (camp anchors, quest targets) | **25–40 s** | defensive cooldown mandatory; 2+ mechanics | 40–70 %, survivable only with actives |
| **Rare** (named, 1 per zone, slow respawn) | **60 s+** | everything the zone taught, chained | should kill players who ignore mechanics |
| Swarm member | 4–6 s each, but spawn 3–5 | AoE + target priority + footwork | pack is lethal if facetanked |

**Death-pressure rules** (the "mobs must threaten" contract):
1. One at-level normal mob kills an AFK/facetanking player in **~30 s** (squishy classes ~20 s).
   A played 12 s fight costs 20–35 % HP — pulling the next mob is a *decision*.
2. Two at-level mobs facetanked without cooldowns = **death**. Cooldowns/kiting make it winnable.
3. Three-mob pack (wolves, swarm) = death unless the player uses AoE, CC, or terrain. This is
   the WoW-Classic "careful pulling" muscle.
4. Elites deal ~1.6× normal per-hit damage and have a must-dodge signature ability: eating two
   signatures ≈ death for any class.
5. Downtime is part of pacing: after that 30 % HP fight the player regens for ~10–15 s
   (out-of-combat regen, §9.2) — the eat/drink rhythm of Classic without food items yet.

---

## 3. Player reference power curve (assumptions the item/XP docs must honor)

From code: basic-attack damage = `ability.damage + gear damage + level_damage_bonus`
(`player.gd:_stat_damage`, +1 flat/level), basics swing every 0.35–0.6 s, HP = class base
× 1.06^(level−1) + gear HP. Class bases: warrior 140/paladin 120/druid 100/rookwarden 95/
rogue 90/necromancer 85/mage 80.

Reference curves used by every formula below (ITEM_PROGRESSION.md must budget gear so a
normally-geared player lands within ±15 % of these):

```
PlayerRefDPS(L) = 25.0 * pow(1.046, L - 1)     # sustained rotation DPS, normal gear
PlayerRefEHP(L) = 120.0 * pow(1.055, L - 1)    # effective HP incl. armor soak, mid-class
```

| Level | RefDPS | RefEHP |
|---|---|---|
| 1 | 25 | 120 |
| 5 | 30 | 149 |
| 10 | 37 | 194 |
| 20 | 59 | 332 |
| 40 | 145 | 969 |
| 60 | 358 | 2 830 |

The +1 flat damage/level in `xp_system.gd` covers only part of the 1.046 growth; **gear and
new ability ranks carry the rest** — that is the WoW spirit (upgrades feel mandatory).

---

## 4. Level-scaling formulas 1–60 (paste-ready)

Add to `enemy.gd` (or a new `scripts/mob_scaling.gd` — statics, no scene code):

```gdscript
## --- Mob scaling (COMBAT_PACING.md §4) --------------------------------------
## Normal-mob targets: TTK ramps 8s (L1) -> 12s (L20+) vs PlayerRefDPS;
## per-hit damage kills a facetanking mid-class player in ~30s.

const RANK_MULT := {           # rank -> [hp_mult, dmg_mult, xp_mult]
	"normal": [1.0, 1.0, 1.0],
	"elite":  [3.2, 1.6, 5.0],
	"rare":   [7.0, 1.9, 12.0],
}

const FAMILY_MULT := {         # archetype -> [hp_mult, dmg_mult]
	"brute":    [1.00, 1.00],  # skeletons, thread-touched: slow, steady
	"stalker":  [0.85, 1.00],  # wolves: fast, flanking packs
	"charger":  [1.00, 1.00],  # boars: telegraphed line charge + enrage
	"caster":   [0.75, 1.30],  # entranced/zealots: ranged casts, interruptible
	"duelist":  [0.90, 0.85],  # rogues/bandits: fast cadence (0.9s swing)
	"guarded":  [1.40, 1.25],  # warriors/enforcers: front block, punish windows
	"swarm":    [0.55, 0.70],  # dogs, the Hungering: 3-5 pulls, AoE food
}

static func ttk_target(level: int) -> float:
	return 8.0 + 4.0 * clampf(float(level - 1) / 19.0, 0.0, 1.0)  # 8s -> 12s

static func mob_hp(level: int, archetype: String = "brute", rank: String = "normal") -> float:
	var ref_dps: float = 25.0 * pow(1.046, float(level - 1))
	var fam: Array = FAMILY_MULT.get(archetype, [1.0, 1.0])
	var rk: Array = RANK_MULT.get(rank, [1.0, 1.0, 1.0])
	# 0.9 = damage uptime (player repositions during telegraphs)
	return roundf(ref_dps * ttk_target(level) * 0.9 * float(fam[0]) * float(rk[0]))

static func mob_damage(level: int, archetype: String = "brute", rank: String = "normal") -> float:
	var fam: Array = FAMILY_MULT.get(archetype, [1.0, 1.0])
	var rk: Array = RANK_MULT.get(rank, [1.0, 1.0, 1.0])
	# 10.8 = 120 EHP / 30s facetank * 1.6s swing cadence, at L1
	return roundf(10.8 * pow(1.055, float(level - 1)) * float(fam[1]) * float(rk[1]))
```

Reference outputs (normal brute): L1 180 hp / 11 dmg · L5 238/13 · L10 334/18 ·
L20 634/30 · L40 1 570/87 · L60 3 870/254. Sanity: at 60, 3 870 hp / 358 RefDPS ≈ 11 s TTK;
254 dmg × ~11 hits ≈ 2 830 EHP ≈ 28 s facetank. The contract holds at both ends of the curve.

**Zone tables stay hand-authored** (owner's "hand-crafted" rule): §10 numbers were generated
from these formulas and then hand-nudged — the formulas are the tuning law, the tables are
the shipped truth. New zones: pick mob level from the zone bracket, call the formulas, nudge.

---

## 5. Enemy ability upgrades — implementable list for `enemy.gd`

All build on existing plumbing: windup state + strike-time `HIT_RANGE` re-check (dodge already
works mechanically), `apply_slow`/`apply_root`, `Combat.spawn_projectile` (faction-aware),
`VFX.ground_circle`/`ring`/`slash_arc`, Nameplate.

**Config:** `Enemy.create(cfg)` gains three keys, passed through from zone tables by
`zone_builder._enemy_spawns` (one-line additions next to `"hp"`/`"damage"`):
`"level": int`, `"archetype": String`, `"rank": String`.

### 5.1 Telegraph standard (reaction windows)
| Tier | Windup | Use | Player counter |
|---|---|---|---|
| Light swing | 0.4 s (current) | default melee, low dmg | facetank-able, costs HP |
| **Heavy swing** | **0.8 s**, every 3rd attack, 1.6× dmg, bigger lean + `VFX.slash_arc` pre-draw at target spot | all melee archetypes | step out 30 px (`HIT_RANGE` re-check already whiffs it) |
| Signature (elite/rare) | 1.1 s, `VFX.ground_circle` decal | stomp/eruption | must move out |
| Cast (caster) | 1.5–2.0 s cast bar | bolt / heal | interrupt or LoS |

Implementation: add `_swing_count`, branch in `_start_windup` (`WINDUP_HEAVY := 0.8`,
`HEAVY_MULT := 1.6`, `HEAVY_EVERY := 3`); tint `WINDUP_TINT` stronger + draw the arc decal at
windup start so the ground shows where the hit lands.

### 5.2 Caster archetype (state additions: `"kite"`, `"cast"`)
- Preferred range 140 px; if player < 70 px, walk away (kite) at 0.8× speed; if 70–180 px, cast.
- Cast = 1.6 s channel, cast bar on Nameplate (add `cast_frac` + a 2 px gold bar under the HP
  bar), then `Combat.spawn_projectile` with `faction: "enemy"`, speed 180, the existing
  Projectile already targets group `"player"`.
- **Interrupt rules** (this is the teaching hook): during a cast, (a) `apply_root`/`apply_slow`
  cancels it, (b) any melee-arc or dash-delivered hit cancels it, (c) ranged chip damage only
  pushes the bar back 20 %. Cancelled cast = 2.5 s recovery doing nothing. Every class kit has
  an answer: warrior Shield Charge, rogue Shadowstep, mage Blink+melee/Frost Nova, paladin
  Judgment root, necro Grave Grasp, hunter Snare Trap/Raven Dash, druid Thornroot.
- `orc_shaman`-family casters ("Cult Zealot") additionally **heal**: packmate < 60 % hp within
  160 px → 2 s cast restores 25 % of its max — makes kill-order and interrupts matter.

### 5.3 Charge (charger archetype; also stalker alphas)
- Trigger when player is 90–160 px away, off cooldown (6 s): 0.7 s telegraph (paw ground,
  draw a fading line/ring at the locked destination), then dash at `speed * 3.2` toward the
  **locked** point (no homing — sidestep beats it), 1.5× damage + 50 % slow 1 s on hit.
- On miss: 1.2 s recovery, takes +25 % damage (set `_vulnerable_left`, check in
  `take_damage`) — dodging is *rewarded*, not just survived.
- Root/snare during telegraph cancels the charge (trap answer for slow classes).

### 5.4 Pack tactics (stalker archetype)
- **Social aggro**: aggroing one pack member pulls packmates within 90 px (a
  `_call_pack()` on entering chase). Careful-pull gameplay.
- **Flanking**: each pack member offsets its chase target point by ±55° around the player
  (index-based), so wolves surround instead of conga-lining.
- **Pack bonus**: +10 % damage per other living packmate in combat within 120 px (cap +30 %).
  Killing adds *first* visibly weakens the pack.
- Night aggro ×2 already exists for wolves — keep, it's canon ("wolves hunt in the dark").

### 5.5 Guarded front (guarded archetype — skeleton_warrior, orc_warrior/enforcers)
- Damage arriving from the front 120° cone (compare source position to facing) is reduced
  **65 %**, with a metallic tink + tiny gray number (needs a `reduced` flag through
  `take_damage` → damage-number color).
- After its own swing resolves (hit or whiff) the guard **drops for 1.5 s** (brief stance
  flash): full damage from any side. Teaches burst windows — bait the swing, then unload.
- Positional bypass: hits from behind always ignore guard (rogue Backstab identity).
- "Armor-break" bypass: Sunder (warrior) and Judgment/Stormbolt-class hits suppress guard 4 s.
  Implement as: any hit flagged `"sunder": true` in its payload sets `_guard_broken_left`.

### 5.6 Enrage (charger + some brutes)
- At < 30 % hp: +35 % speed, +40 % damage, red tint pulse. Finish it or kite the last sliver.

### 5.7 Elite / rare rank plumbing
- `rank` drives `RANK_MULT` (§4), a Nameplate frame treatment (silver ticks elite / gold rare),
  and grants a **signature**: elites get one §5.1 signature AoE (stomp: 1.1 s
  `VFX.ground_circle`, radius 44, 2.2× damage inside); rares chain two archetype kits (e.g.
  the Bandit-Lord is guarded *and* summons two swarm adds at 50 %).
- Rares: 1 per zone, fixed lair, ~20 min respawn, guaranteed rarity-boosted loot roll
  (hook for LOOT_WINDOW/ITEM_PROGRESSION docs).

### 5.8 Per-archetype aggro/leash (replaces the single 120 px constant)
| archetype | aggro px | leash px | notes |
|---|---|---|---|
| brute | 100 | 280 | slow, ignorable — teaches pathing around |
| stalker | 150 (×2 night) | 340 | punishes careless travel |
| charger | 120 | 280 | |
| caster | 170 | 320 | opens fire before you close — forces gap-close |
| duelist | 130 | 300 | |
| guarded | 100 | 280 | |
| swarm | 130 + social 140 | 300 | |

---

## 6. How each creature family teaches class mechanics

Every class kit (class_defs.gd) has the same verb set: **basic · burst · dash · root/slow ·
defensive · AoE**. Families are tutors for one verb each; zone order (§7) sequences the
curriculum.

| Family (zones) | Behavior (§5) | Verb it teaches | Per-class answer |
|---|---|---|---|
| **Boars** (Iron Vein, Vetka, Lowlands, Riverfork) | line charge + enrage | *sidestep telegraphs; save burst for the enrage* | any dash (Shield Charge, Shadowstep, Blink, Raven Dash); roots cancel the charge (Thornroot, Snare Trap, Grave Grasp) |
| **Wolves** (Iron Vein, Copper Wells, Stonepath, Marches) | pack social aggro + flanking + night ×2 | *kiting, careful pulls, target priority* | slows/AoE: Frost Nova, Earthshaker, Fan of Knives, Whirlwind, Bone Nova, Arrow Storm, Gale |
| **Thread-touched dead / skeletons** (Iron Vein, Copper Wells, graveyard) | slow brute, heavy 3rd swing | *rotation fundamentals, resource management, dodge rhythm* | the basic loop; mana pacing over a 10 s fight |
| **Entranced / the Hungering / Cult Zealots** (Copper Wells, Marches, Famine Fields — casters) | ranged cast + kite-away + pack heal | *interrupt, gap-close, LoS, kill-order* | dash-hit or root to interrupt (every class, §5.2); kill the healer first |
| **Grave Warband / Enforcers** (Stonepath, Riverfork — guarded) | front block + punish window + backstab bypass | *burst windows, positioning, armor-break* | Sunder/Judgment guard-break; Backstab identity hit; everyone else baits the swing then bursts |
| **Starving dogs / the Hungering swarms** (Famine Fields, Marches, Lowlands) | 3–5-pull swarm, weak singly | *AoE usage and when NOT to AoE (adds)* | Whirlwind, Death Blossom, Flame Strike, Consecration, Bone Nova/Soul Harvest, Arrow Storm, Tempest |
| **Duelists — deserters, bandits, cutpurses** (Stonepath, Lowlands, Angel Wings) | 0.9 s fast swings, low per-hit | *sustained mitigation: absorbs, self-heals, disengage* | Iron Bulwark, Shroud, Mana Shield, Lay on Hands, Bone Armor, Rejuvenation, Bear Form |
| **Bears / rares** (rare lairs) | rank mechanics chained | *the exam: everything above in one 60 s+ fight* | full kit or die |

Necromancer/druid/hunter pets add a taunt-less off-tank: casters teach *them* pet
positioning (send the pet in while you strafe the bolt).

---

## 7. Zone level brackets (the 9 built zones + hub)

Follows the WORLD_PLAN travel spine; west arm is the first of four 40-zone arms.

| Zone | Bracket | Curriculum focus |
|---|---|---|
| Raven Hollow graveyard (`combat.gd`) | 1–2 | rotation on brutes; scarecrow = training |
| The Iron Vein | 2–4 | charge-dodging (boars), first packs (mudwolves) |
| Vetka | 3–5 | first caster ("the first monster is a symptom" — an entranced villager) |
| The Copper Wells | 4–7 | interrupts proper (Entranced Pilgrims), night wolves |
| The Stonepath | 6–9 | guarded mobs (Grave Warband) + duelists; first rare |
| The Grey Marches | 8–11 | caster+healer packs (Cult Zealots), swarm intro |
| The Western Lowlands | 10–13 | mixed pulls: duelist camps + swarms |
| Angel Wings (outskirts) | 11–14 | city-edge duelists/cultists, light density (capital) |
| The Famine Fields | 12–16 | swarm mastery + healer kill-order (Famine Prophet elite) |
| Riverfork | 15–18 | guard-break finals (Enforcers) + the Bandit-Lord rare |

---

## 8. XP curve alignment (cap 60)

`xp_system.gd` today: cap 10, 1.6× geometric (unusable at 60 — 1.6⁵⁸ ≈ 10¹²), flat per-family
kill XP, no level falloff. Re-anchor (keeps the same public API shapes):

```gdscript
const MAX_LEVEL: int = 60

## Cost to advance FROM (level-1) TO level. Quadratic-ish like Classic:
## grind-only kills-to-level = 8 + 1.1*L (quests are designed to cover ~half).
static func xp_for_level(level: int) -> int:
	if level < 2 or level > MAX_LEVEL:
		return 0
	var l := float(level - 1)
	return roundi((8.0 + 1.1 * l) * (14.0 + 4.0 * l))
	# L2:164  L10:895  L20:2260  L40:7570  L60:18225  (total 1->60 ≈ 292k)

## Kill XP now scales with MOB level and rank, with WoW gray-out falloff.
static func xp_for_kill_scaled(mob_level: int, rank: String, player_level: int) -> int:
	var base: float = 14.0 + 4.0 * float(mob_level)
	var rank_mult: float = float((RANK_MULT.get(rank, [1,1,1.0]))[2])   # elite x5, rare x12
	var diff: int = player_level - mob_level
	var falloff: float = clampf(1.0 - 0.15 * float(maxi(0, diff - 2)), 0.10, 1.0)
	return roundi(base * rank_mult * falloff)
```

Wiring: `enemy.gd:_grant_kill_rewards` passes `level`/`rank` (now on the Enemy from cfg)
instead of only `type_name`; the old family `KILL_XP` dict retires. Pacing check: at-level
kill ≈ 12 s fight + ~12 s regen/travel ⇒ a pure-grind level takes ~9 kills × 25 s ≈ 4 min at
L1 rising to ~74 kills ≈ 35 min at 59; with quests (~55 % of XP per the quest architecture)
that's ~20 min/level early, ~75 min/level in the 50s — Classic-feel, cap ≈ 5–6 days /played.

---

## 9. Engine fixes required (blockers for the pacing contract)

1. **`player.gd` i-frames** (`INVULN_TIME = 0.5`, set on every hit): replace global
   invulnerability with per-attacker crediting — keep a 0.15 s global grace vs true
   double-applications, and let each enemy's own swing cadence (1.6 s) do the gating.
   Without this, packs and elites mathematically cannot threaten (2 hits/s cap).
2. **Out-of-combat regen** (`player.gd` regen tick): after 5 s without dealing/taking damage,
   hp regen becomes `max_hp * 0.05/s` (mana ×3). In-combat regen unchanged (fights must be
   won with the kit, not out-regenerated). This creates the deliberate 10–15 s post-fight
   breather instead of 40 s of boredom at the new HP costs.
3. **Nameplate cast bar** (`enemy.gd` Nameplate): 2 px gold bar under the HP bar driven by
   `cast_frac`; flashes white on interrupt. Required by §5.2.
4. **Damage-number variants**: gray small number for guarded-reduced hits, gold flash on
   guard-break — the feedback that makes §5.5 legible.
5. **`zone_builder.gd:_enemy_spawns`**: pass through `"level"`, `"archetype"`, `"rank"`
   from creature_table rows into the Enemy cfg (3 lines beside `"hp"`).
6. **`combat.gd` Projectile**: already faction-aware — no change; enemy casters reuse it.

---

## 10. Retuned spawn tables — paste into `zone_defs.gd`

Generated from §4 formulas at each mob's level, hand-nudged. New keys `level`/`archetype`/
`rank` require §9.5. `count`/`pack` retuned for pull design (swarms 4–5, wolves 3, guarded 2).
Speeds: stalkers stay > player-walk (they catch you; you kite with slows), casters slow
(they don't chase, they cast), brutes lumber.

### 10.1 Raven Hollow graveyard — `combat.gd` `ENEMY_SPAWNS` (L1–2)

```gdscript
const ENEMY_SPAWNS: Array[Dictionary] = [
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(140.0, 300.0),
		"level": 1, "archetype": "brute", "hp": 180.0, "damage": 11.0, "speed": 56.0, "patrol_radius": 55.0},
	{"type": "skeleton_rogue", "display_name": "Skeleton Rogue", "pos": Vector2(125.0, 435.0),
		"level": 1, "archetype": "duelist", "hp": 162.0, "damage": 9.0, "speed": 74.0, "patrol_radius": 65.0},
	{"type": "skeleton_warrior", "display_name": "Skeleton Warrior", "pos": Vector2(185.0, 495.0),
		"level": 2, "archetype": "guarded", "hp": 270.0, "damage": 14.0, "speed": 52.0, "patrol_radius": 45.0},
	{"type": "skeleton_mage", "display_name": "Skeleton Mage", "pos": Vector2(330.0, 165.0),
		"level": 2, "archetype": "caster", "hp": 145.0, "damage": 15.0, "speed": 48.0, "patrol_radius": 60.0},
	{"type": "skeleton", "display_name": "Graveyard Skeleton", "pos": Vector2(520.0, 155.0),
		"level": 1, "archetype": "brute", "hp": 180.0, "damage": 11.0, "speed": 58.0, "patrol_radius": 80.0},
]
```

### 10.2 `iron_vein` (bracket 2–4)

```gdscript
"creature_table": [
	{"type": "boar", "name": "Bog Boar", "count": 8, "pack": 2, "level": 2, "archetype": "charger",
		"hp": 195, "damage": 11, "speed": 72, "patrol": 90, "area": Rect2(800, 2600, 2400, 1400)},
	{"type": "wolf", "name": "Mudwolf", "count": 6, "pack": 3, "level": 3, "archetype": "stalker",
		"hp": 176, "damage": 12, "speed": 96, "patrol": 120, "area": Rect2(4200, 800, 2000, 1000)},
	{"type": "skeleton", "name": "Thread-Touched Dead", "count": 5, "pack": 1, "level": 4, "archetype": "brute",
		"hp": 222, "damage": 13, "speed": 50, "patrol": 60, "area": Rect2(4800, 3000, 1600, 1200)},
	# Canon apex: rare night-spawn near the dolmen. 7x hp, 1.9x dmg (rank mult applied).
	{"type": "boar", "name": "The Digging Creature", "count": 1, "pack": 1, "level": 5,
		"archetype": "charger", "rank": "rare",
		"hp": 1666, "damage": 25, "speed": 84, "patrol": 60, "area": Rect2(1600, 700, 500, 500)},
],
```

### 10.3 `vetka` (bracket 3–5)

```gdscript
"creature_table": [
	{"type": "boar", "name": "Boar", "count": 4, "pack": 2, "level": 3, "archetype": "charger",
		"hp": 207, "damage": 12, "speed": 72, "patrol": 80, "area": Rect2(4300, 2900, 1100, 1000)},
	# "The first monster is a symptom" — the first caster the player ever meets.
	{"type": "skeleton_mage", "name": "Entranced Villager", "count": 3, "pack": 1, "level": 4, "archetype": "caster",
		"hp": 167, "damage": 17, "speed": 44, "patrol": 30, "area": Rect2(3800, 3100, 1200, 800)},
],
```

### 10.4 `copper_wells` (bracket 4–7)

```gdscript
"creature_table": [
	{"type": "skeleton_mage", "name": "Entranced Pilgrim", "count": 6, "pack": 1, "level": 5, "archetype": "caster",
		"hp": 179, "damage": 17, "speed": 44, "patrol": 24, "area": Rect2(3000, 2900, 1200, 900)},
	{"type": "wolf", "name": "Moor Wolf", "count": 6, "pack": 3, "level": 5, "archetype": "stalker",
		"hp": 202, "damage": 13, "speed": 96, "patrol": 120, "area": Rect2(800, 1200, 1600, 1400)},
	{"type": "skeleton", "name": "Thread-Touched Dead", "count": 4, "pack": 2, "level": 6, "archetype": "brute",
		"hp": 255, "damage": 14, "speed": 50, "patrol": 70, "area": Rect2(4800, 3200, 1200, 1100)},
	# Elite anchor at the live inscription stone (quest target).
	{"type": "skeleton_warrior", "name": "Warden of the Wells", "count": 1, "pack": 1, "level": 7,
		"archetype": "guarded", "rank": "elite",
		"hp": 874, "damage": 24, "speed": 56, "patrol": 40, "area": Rect2(3300, 3100, 300, 300)},
],
```

### 10.5 `stonepath` (bracket 6–9)

```gdscript
"creature_table": [
	{"type": "wolf", "name": "Wild Wolf", "count": 9, "pack": 3, "level": 7, "archetype": "stalker",
		"hp": 232, "damage": 15, "speed": 98, "patrol": 130, "area": Rect2(600, 800, 2400, 1600)},
	{"type": "skeleton_warrior", "name": "Grave Warband", "count": 6, "pack": 2, "level": 8, "archetype": "guarded",
		"hp": 409, "damage": 20, "speed": 56, "patrol": 90, "area": Rect2(4200, 3200, 1800, 1400)},
	{"type": "orc_rogue", "name": "Deserter", "count": 4, "pack": 2, "level": 8, "archetype": "duelist",
		"hp": 263, "damage": 13, "speed": 84, "patrol": 100, "area": Rect2(4800, 900, 1400, 1100)},
	# Rare at the shortening inscription — the zone exam.
	{"type": "skeleton_mage", "name": "The Stonewatcher", "count": 1, "pack": 1, "level": 9,
		"archetype": "caster", "rank": "rare",
		"hp": 2184, "damage": 41, "speed": 52, "patrol": 30, "area": Rect2(3200, 2350, 300, 300)},
],
```

### 10.6 `grey_marches` (bracket 8–11)

```gdscript
"creature_table": [
	{"type": "wolf", "name": "Greywolf", "count": 10, "pack": 3, "level": 9, "archetype": "stalker",
		"hp": 265, "damage": 17, "speed": 98, "patrol": 130, "area": Rect2(1000, 800, 3200, 1600)},
	{"type": "orc_shaman", "name": "Cult Zealot", "count": 5, "pack": 2, "level": 10, "archetype": "caster",
		"hp": 251, "damage": 23, "speed": 60, "patrol": 90, "area": Rect2(4600, 3200, 1800, 1200)},
	{"type": "skeleton_mage", "name": "The Hungering", "count": 6, "pack": 3, "level": 10, "archetype": "swarm",
		"hp": 184, "damage": 12, "speed": 40, "patrol": 24, "area": Rect2(2200, 2800, 1400, 1000)},
	{"type": "wolf", "name": "Marches Alpha", "count": 1, "pack": 1, "level": 11,
		"archetype": "stalker", "rank": "elite",
		"hp": 968, "damage": 29, "speed": 102, "patrol": 80, "area": Rect2(1400, 900, 400, 400)},
],
```

### 10.7 `western_lowlands` (bracket 10–13)

```gdscript
"creature_table": [
	{"type": "orc_rogue", "name": "Bandit", "count": 8, "pack": 3, "level": 11, "archetype": "duelist",
		"hp": 320, "damage": 16, "speed": 86, "patrol": 110, "area": Rect2(800, 800, 2400, 1400)},
	{"type": "boar", "name": "Field Boar", "count": 6, "pack": 2, "level": 11, "archetype": "charger",
		"hp": 356, "damage": 18, "speed": 74, "patrol": 90, "area": Rect2(4800, 3600, 2200, 1200)},
	{"type": "skeleton_mage", "name": "The Hungering", "count": 5, "pack": 3, "level": 12, "archetype": "swarm",
		"hp": 209, "damage": 14, "speed": 40, "patrol": 24, "area": Rect2(5600, 1200, 1600, 1000)},
	{"type": "orc_rogue", "name": "Bandit Captain", "count": 1, "pack": 1, "level": 13,
		"archetype": "duelist", "rank": "elite",
		"hp": 1166, "damage": 28, "speed": 88, "patrol": 70, "area": Rect2(1200, 1000, 400, 400)},
],
```

### 10.8 `angel_wings` (bracket 11–14, capital outskirts — light density)

```gdscript
"creature_table": [
	{"type": "orc_rogue", "name": "Alley Cutpurse", "count": 4, "pack": 2, "level": 12, "archetype": "duelist",
		"hp": 342, "damage": 17, "speed": 86, "patrol": 90, "area": Rect2(1800, 6000, 1600, 1400)},
	{"type": "orc_shaman", "name": "Hungering Cultist", "count": 3, "pack": 1, "level": 13, "archetype": "caster",
		"hp": 304, "damage": 27, "speed": 60, "patrol": 70, "area": Rect2(2200, 6400, 1200, 900)},
],
```

### 10.9 `famine_fields` (bracket 12–16)

```gdscript
"creature_table": [
	{"type": "orc_shaman", "name": "Cult Zealot", "count": 6, "pack": 2, "level": 14, "archetype": "caster",
		"hp": 324, "damage": 28, "speed": 60, "patrol": 90, "area": Rect2(1000, 1000, 2000, 1400)},
	{"type": "wolf", "name": "Starving Dog", "count": 8, "pack": 4, "level": 13, "archetype": "swarm",
		"hp": 223, "damage": 14, "speed": 100, "patrol": 130, "area": Rect2(4200, 3200, 2200, 1200)},
	{"type": "skeleton_mage", "name": "The Hungering", "count": 7, "pack": 3, "level": 14, "archetype": "swarm",
		"hp": 238, "damage": 15, "speed": 40, "patrol": 24, "area": Rect2(3600, 1600, 2200, 1400)},
	# Elite caster at the cult fire: heal-interrupt exam before Riverfork.
	{"type": "orc_shaman", "name": "Famine Prophet", "count": 1, "pack": 1, "level": 16,
		"archetype": "caster", "rank": "elite",
		"hp": 1183, "damage": 50, "speed": 58, "patrol": 50, "area": Rect2(1500, 1500, 300, 300)},
],
```

### 10.10 `riverfork` (bracket 15–18)

```gdscript
"creature_table": [
	{"type": "orc_warrior", "name": "Bandit-Lord's Enforcer", "count": 5, "pack": 2, "level": 16, "archetype": "guarded",
		"hp": 690, "damage": 30, "speed": 70, "patrol": 100, "area": Rect2(900, 3000, 1800, 1400)},
	{"type": "orc_rogue", "name": "River Smuggler", "count": 6, "pack": 2, "level": 16, "archetype": "duelist",
		"hp": 444, "damage": 20, "speed": 88, "patrol": 110, "area": Rect2(4400, 1400, 1800, 1200)},
	{"type": "boar", "name": "Bog Boar", "count": 4, "pack": 2, "level": 15, "archetype": "charger",
		"hp": 462, "damage": 23, "speed": 74, "patrol": 90, "area": Rect2(3200, 3400, 1800, 1000)},
	# Zone rare at the bandit-lord fire: guarded + summons 2 smuggler adds at 50%.
	{"type": "orc_warrior", "name": "Vosk, the Bandit-Lord", "count": 1, "pack": 1, "level": 18,
		"archetype": "guarded", "rank": "rare",
		"hp": 3927, "damage": 51, "speed": 74, "patrol": 60, "area": Rect2(1300, 3500, 300, 300)},
],
```

---

## 11. Rollout order

1. §9.1 i-frame fix + §9.2 out-of-combat regen (without these the retune just makes fights longer, not threatening).
2. §4 scaling statics + §9.5 cfg passthrough + §10 tables (world instantly stops being trash).
3. §5.1 heavy-swing telegraph + §5.4 pack tactics (cheap: extends existing windup/chase code).
4. §5.2 caster + cast bar + interrupts (biggest teaching win — Vetka's Entranced Villager is the first lesson).
5. §5.3 charge, §5.5 guarded, §5.6 enrage.
6. §5.7 elite/rare ranks + §8 XP re-anchor (ship together — rank XP needs the new formula).

Playtest gates per step: time 10 at-level kills with a L5 warrior and L5 mage in Copper Wells
(want 9–11 s avg, ≤ 40 % HP cost); facetank test (30 s ± 5); 3-wolf pack must kill a
no-cooldown player.
