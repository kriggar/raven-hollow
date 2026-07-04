# RAVEN HOLLOW — STATUS EFFECTS: THE BUFF/DEBUFF FRAMEWORK
Design doc for the general status-effect system: stacking, durations, DoT/HoT
ticks, stat modifiers, dispel schools, immunities, creature **proc passives**
(the wolf-bite → Infected canon), the HUD buff/debuff rows, the exact
`StatusEffects` component API, and save/load.

**Grounded in (read before writing):**
- `scripts/player.gd` — the current one-slot buff (`_buff_left`/`_speed_mult`/
  `_damage_mult`/`_absorb`/`_buff_fx`, `_do_buff`, fire-and-forget HoT timers),
  `take_damage` (armor soak → absorb → `_invuln = 0.5`), `_apply_equipment()`
  stat re-derivation, `_stat_damage()`, `_next_hit_bonus` spender.
- `scripts/enemy.gd` — `apply_slow(mult, dur)` / `apply_root(dur)` (`_slow_mult/
  _slow_left/_root_left`), `take_damage` (knockback + aggro hold), `_tick_windup`
  strike point, `Enemy.create(cfg)` cfg-dict pattern, Nameplate.
- `scripts/combat.gd` — `Combat.deal_damage`, faction-aware `Projectile`
  (`on_hit` Callable opt-in), Scarecrow (`own_damage_numbers` meta, never dies).
- `scripts/class_defs.gd` — 10 `kind:"buff"` abilities (war_cry, iron_bulwark,
  shroud, mana_shield, lay_on_hands, divine_shield, holy_dome, bone_armor,
  hunters_mark, rejuvenation, bear_form) whose params this system absorbs.
- `scripts/hud.gd` — unit-frame geometry (118×42 at (8,8), target at x=132,
  XP bar at y=52..61), the bottom-anchored cooldown-sweep pattern, the
  in-scene `_ability_tip` tooltip, `_load_icon` (`pixel:` → IconsPixel).
- `scripts/items.gd` / `scripts/inventory.gd` — item dict shape + `effect` id
  hooks, `STAT_KEYS`, `stat_totals()`; `scripts/save_system.gd` — v1 JSON
  shape, `collect_state` / `apply_player_state`, duck-typed system snapshots.
- `design/COMBAT_PACING.md` — TTK contract (8–15 s normals), mob scaling
  formulas (`mob_damage(level)`), archetypes, §5 ability upgrades this doc
  must carry (enrage, pack bonus, sunder guard-break, charge slow), §9.1
  i-frame fix (per-attacker crediting) that DoT ticks must not re-break.
- `design/ITEM_PROGRESSION.md` — stat budget language, act/material lexicon
  (thread-touched, blackglass strigoi, the Hungering, finalized fields), the
  `crafting.gd` "extension keys ignored by core" layering precedent.

---

## 1. Audit — the status-shaped code that already exists

| Fact | Source | Verdict |
|---|---|---|
| Player has exactly ONE buff slot: `_do_buff` overwrites `_buff_left/_speed_mult/_damage_mult/_absorb` wholesale | `player.gd:853` | War Cry then Iron Bulwark **silently eats War Cry**. Must become a container. |
| HoTs are fire-and-forget scene-tree timers (`heal_per_sec` loop) | `player.gd:865` | No icon, no dispel, survives nothing, invisible to the HUD. Migrate. |
| Enemy CC is two ad-hoc fields: `_slow_mult/_slow_left`, `_root_left` | `enemy.gd:78–80, 409–420` | Good call-sites (`apply_slow`/`apply_root` are duck-called from `player.gd:_aoe_pulse`) — keep the method names as wrappers, move the state into the component. |
| `_next_hit_bonus`/`_bonus_left` (Shield Charge / Shadowstep) | `player.gd:197–198` | A *spender*, not a duration aura. Stays as-is; gets a HUD icon via a hidden mirror effect (§9.5). |
| No debuff model on the player at all; no icons anywhere; nothing persists | — | The whole point of this doc. |
| `take_damage` on both sides is the single choke point; Scarecrow has no `apply_*` methods and callers already guard with `has_method` | `player.gd:1076`, `enemy.gd:426`, `player.gd:808` | Same guard pattern protects `status.apply()` — a target without the component is simply immune to everything. |
| SaveSystem rebuilds items from ids and tolerates unknown keys; systems snapshot via duck-typed `serialize()`/`deserialize()` | `save_system.gd` | The status block rides the same patterns (§10). |
| COMBAT_PACING retunes mob damage 11→254 across 1–60 | COMBAT_PACING §4 | Creature debuff numbers must be **coefficients of the applier's damage**, never absolutes, or they die at level 12 (§3.6). |

---

## 2. Vocabulary and rules (the contract)

### 2.1 Effect kinds and dispel schools

Every effect is a `kind`: `"buff"` (helpful, right of the player frame,
gold-rimmed) or `"debuff"` (harmful, its own row, school-colored rim).
Every **debuff** carries a `dispel` school — the removal language:

| School | Rim color (HUD §9) | Removed by | Lore register |
|---|---|---|---|
| `bleed` | `Color(0.62, 0.16, 0.12)` (HP_FILL red) | bandage items, full heal to 100%, expiry | claws, gore, blackglass edges |
| `poison` | `Color(0.35, 0.65, 0.30)` | Restorative Draught, healer NPC | fangs, smuggler ash, bog rot |
| `disease` | `Color(0.62, 0.52, 0.22)` (ochre) | Restorative Draught, healer NPC | infected bites, bad wells, mange |
| `curse` | `Color(0.52, 0.30, 0.66)` (epic purple) | Chalk Ward, chapel shrine, healer NPC | thread-work, hexes, leverage-marks |
| `magic` | `Color(0.30, 0.50, 0.90)` (rare blue) | (post-demo: class dispels/trainers) | chills, filings, arcane slows |
| `none` | `SLOT_BORDER` grey-brown | expiry only (or leaving the field) | dread auras, enrages, physical states |

`purge(school)` (§4) is the single API every cure calls. Class-kit dispels are
post-demo trainer content; at ship, cures are **consumables + healer NPCs +
the chapel shrine** — gold and travel are the cost of a cleanse, Classic-style.

### 2.2 Stacking rules (one per def, no hybrid)

| `stack_rule` | On re-apply | Use |
|---|---|---|
| `"refresh"` (default) | duration resets, stacks stay 1 | most CC, marks, food |
| `"add"` | stacks +1 (cap `max_stacks`), duration resets | Bite, Rend, Mange, Finalized Chill — the "pressure builds" verbs |
| `"add_time"` | remaining += duration, capped at 2× duration | channel-fed effects (none at ship; reserved) |

Cross-effect exclusivity uses `group`: applying a member of a group removes
any other active member (`"food"`, `"drink"`, `"form"`). One meal, one tea,
one form — the WoW Well-Fed rule, and it keeps the buff row honest.

Same effect from two different mobs shares one instance (single-player game,
per-caster bookkeeping buys nothing) — **except** `per_source: true` defs
(leverage_mark), whose damage bonus only honors the marker (§6.4).

### 2.3 Thresholds — the proc-chain primitive

A def may carry `threshold: {at: int, apply: String, clear: bool}`. When
`apply()` raises the effect to `at` stacks, the component immediately applies
`threshold.apply` (a different effect id) and, if `clear`, removes itself.
This one field is the whole wolf canon:

> **Bite** (`stack_rule:"add"`, `max_stacks:3`, `threshold:{at:3,
> apply:"infected", clear:true}`) — three wolf bites land, the Bite counter
> pops, and the player is **Infected** (disease, −1 Stamina) until cured or
> expired. §7 walks the full call chain.

### 2.4 Durations and ticks

- Durations count down in the component's `_physics_process` — so they pause
  with the tree exactly like ability cooldowns (frozen pause menu = frozen
  buffs; no special casing).
- `tick_interval > 0` runs the `tick` payload every interval, **first tick
  one interval after application** (no apply-tick double-dip on stacking).
- **DoT ticks are not hits.** They route through `take_tick_damage()` (§5.3),
  which bypasses the player's `_invuln` gate, armor soak, knockback, camera
  shake and the red flash — but **does** drain absorb pools first and does
  show a small school-colored damage number. This keeps COMBAT_PACING §9.1
  honest: ticks can never eat the per-attacker hit credit, and armor can
  never zero a bleed.
- HoT ticks heal the host directly, clamped to `max_hp` (never resurrect:
  `_dead` hosts tick nothing; death clears all non-persist effects §5.4).

### 2.5 Stat modifiers — where they plug in

`stat_mods` uses the **exact `Inventory.STAT_KEYS` vocabulary** (`damage`,
`armor`, `hp`, `mana`, `speed_pct`, `crit_pct`, `mana_regen`) plus three
status-only keys:

| Key | Meaning | Applied where |
|---|---|---|
| `stamina` | vitality alias: **1 Stamina = 10 max HP** (`STAMINA_HP := 10.0`). When a real Stamina attribute ships, the alias re-points; defs never change. | expanded into `hp` inside `stat_delta()` |
| `damage_dealt_pct` | ±% outgoing damage (multiplicative bucket) | `damage_dealt_mult()` |
| `damage_taken_pct` | ±% incoming damage (multiplicative bucket) | `damage_taken_mult(source)` |

Flat mods are **additive**; percentage buckets are **multiplicative products**
(two 15% slows = 0.85 × 0.85, not 0.70). Caps enforced at read time:
- player total slow floor **0.5** (a played character is never slowed below
  half speed — kiting stays possible, per the COMBAT_PACING death-pressure
  rules which assume footwork is always available);
- enemy slow floor stays **0.05** (the existing `apply_slow` clamp);
- `damage_taken_pct` on the player caps at +50%.

The player integrates flat mods by extending `_apply_equipment()` (§5.2) —
the same "re-derive everything from caches" pattern gear already uses, so
`max_hp` clamping, HUD bars and tooltips all keep working for free.

### 2.6 Immunities

Hosts expose `status_immunities: Array[String]` — matched against **both**
the effect id and its dispel school. Enemy cfg gains an `"immunities"` key
(zone tables pass it through beside `hp`/`damage`, the COMBAT_PACING §9.5
passthrough). Canon table:

| Family | Immune to | Why |
|---|---|---|
| Thread-touched dead / skeletons | `bleed`, `poison`, `disease` | no blood, no gut, no fever |
| The Hungering | `poison`, `disease` | emptiness cannot sicken |
| Strigoi (Act IV) | `curse` | you cannot mortgage what already holds the lien |
| The Finalized (Act VI) | `bleed`, `poison`, `disease`, `curse` | filed, stamped, closed to amendment |
| Beasts (wolf/boar/bear), humans | — | fully vulnerable |
| Training Scarecrow, ambient fauna | everything | no component attached — `apply()` no-ops (§4, mirrors the `has_method("apply_slow")` guard precedent) |

Rares/act bosses additionally take **root duration ×0.5** and hard-cap
`damage_taken_pct` debuffs at +25% (`"boss_cc": true` in cfg) so the exam
fights can't be trivially perma-controlled.

---

## 3. Effect definition shape (exact)

`scripts/status_defs.gd` — pure static data + tiny helpers, mirroring
`class_defs.gd`/`items.gd` (no scene code). Icon law identical to items:
**icon id == effect id**, one `IconsPixel.REGISTRY` cell each, PIL-verified.

```gdscript
class_name StatusDefs
## Static status-effect registry for Raven Hollow (STATUS_EFFECTS.md §3).
## Def shape (every def carries every key; {} / 0.0 / "" when unused):
##   {
##     id, name, icon,                  # icon "pixel:<id>" — IconsPixel law
##     kind,                            # "buff" | "debuff"
##     dispel,                          # "bleed"|"poison"|"disease"|"curse"|"magic"|"none"
##     duration,                        # seconds (0 = until removed, e.g. field auras)
##     max_stacks, stack_rule,          # "refresh" | "add" | "add_time"
##     group,                           # exclusivity group ("" = none): "food"|"drink"|"form"
##     tick_interval,                   # 0 = no ticks
##     tick: {
##       damage_coeff,                  # per stack, x instance potency (§3.6)
##       heal_flat, heal_coeff,         # flat hp / x potency per tick
##       mana_flat,                     # mana per tick (+/-)
##       leech,                         # fraction of tick damage healed to the SOURCE
##       school,                        # damage-number color key (= dispel school)
##     },
##     stat_mods: {},                   # STAT_KEYS + stamina/damage_dealt_pct/damage_taken_pct,
##                                      #   PER STACK, snapshot-free (read live)
##     absorb,                          # damage-absorb pool granted on apply (Iron Bulwark line)
##     threshold: {at, apply, clear},   # §2.3 proc-chain ({} = none)
##     per_source,                      # damage_taken_pct only counts the marking source
##     persist,                         # serializes into the save (§10)
##     combat_only,                     # cleared when the host dies/respawns
##     hidden,                          # no HUD icon (engine-internal states)
##     fx_loop, fx_tint,                # FXLib looping aura id + tint (player.gd _buff_fx pattern)
##   }

const STAMINA_HP: float = 10.0    # 1 Stamina = 10 max HP (alias, §2.5)

const DISPEL_COLORS := {
	"bleed":   Color(0.62, 0.16, 0.12),
	"poison":  Color(0.35, 0.65, 0.30),
	"disease": Color(0.62, 0.52, 0.22),
	"curse":   Color(0.52, 0.30, 0.66),
	"magic":   Color(0.30, 0.50, 0.90),
	"none":    Color(0.30, 0.22, 0.12),  # HUD SLOT_BORDER
}

static func get_def(id: String) -> Dictionary:
	if not _DEFS.has(id):
		push_warning("StatusDefs.get_def: unknown effect id '%s'" % id)
		return {}
	return _DEFS[id]  # defs are read-only; instances never mutate them
```

### 3.6 Potency — how numbers survive levels 1–60

Every damaging/healing instance snapshots a **potency** at apply time:

- creature-applied → the applier's `damage` stat (already retuned per level
  by COMBAT_PACING §4's `mob_damage(level)`);
- player-applied → `player._stat_damage() + ability base` (gear + level,
  exactly what direct hits use);
- consumables → a flat potency baked into the item's bracket (§8).

Tick damage = `potency × tick.damage_coeff × stacks`. A def never contains
an absolute damage number, so the same `bite` def is correct on a L3 Mudwolf
(12 dmg → ~1.4 per tick per stack) and a L30 varcolac (≈60 dmg → ~7). This
is the composition contract with COMBAT_PACING: **retuning zone tables
retunes every proc for free.**

**DoT budget law** (keeps TTK/death-pressure intact): a normal mob's debuff
may contribute at most **~1.5 melee hits' worth** of damage over its full
duration (`duration/interval × coeff × max_stacks ≤ 1.5`). Elite/rare
signature debuffs may reach 2.5×. All §6 numbers obey this — a 12 s fight
played well still costs 20–35% HP, bleeds included.

---

## 4. The component — `scripts/status_effects.gd` (exact API)

One node class, attached as a child of **both** `Player` and `Enemy` (host
duck-typing throughout, matching the codebase style). ~230 lines, no scene
dependencies beyond VFX/FXLib.

```gdscript
class_name StatusEffects
extends Node
## Per-combatant status container (STATUS_EFFECTS.md). Owns durations, stacks,
## DoT/HoT ticks, stat-mod aggregation, absorb pools, dispel/purge, immunities,
## threshold proc-chains and (de)serialization. Hosts without this component
## are immune to everything (Scarecrow, ambient fauna) — callers use
## `Status.of(node)` which returns null for them, same guard style as the
## existing has_method("apply_slow") checks.

signal effects_changed          ## fired on apply/stack/expire/purge — HUD + host re-derive

const PLAYER_SLOW_FLOOR := 0.5
const ENEMY_SLOW_FLOOR := 0.05
const TAKEN_MULT_CAP := 1.5

var host: Node2D = null
var _active: Dictionary = {}    ## id -> instance dict (see below)
## Instance shape:
##   {"id", "left": float, "stacks": int, "tick_t": float,
##    "potency": float, "absorb_left": float, "src_iid": int, "fx": Node2D|null}

static func attach(to: Node2D) -> StatusEffects:
	var s := StatusEffects.new()
	s.name = "Status"
	s.host = to
	to.add_child(s)
	return s

static func of(node: Node) -> StatusEffects:
	## Null for hosts that never attached one (= blanket immunity).
	if node == null or not is_instance_valid(node):
		return null
	return node.get_node_or_null("Status") as StatusEffects

# --- Application -----------------------------------------------------------

func apply(id: String, ctx: Dictionary = {}) -> bool:
	## ctx: {"source": Node2D, "potency": float, "stacks": int, "left": float}
	## (left/stacks are the deserialize path). Returns false when immune/unknown.
	var def: Dictionary = StatusDefs.get_def(id)
	if def.is_empty() or _immune(def):
		return false
	var inst: Dictionary = _active.get(id, {})
	if inst.is_empty():
		inst = {"id": id, "left": float(def.get("duration", 0.0)),
				"stacks": maxi(1, int(ctx.get("stacks", 1))),
				"tick_t": float(def.get("tick_interval", 0.0)),
				"potency": float(ctx.get("potency", _default_potency(ctx.get("source")))),
				"absorb_left": float(def.get("absorb", 0.0)),
				"src_iid": _src_iid(ctx.get("source")), "fx": null}
		_evict_group(def)          # food replaces food, form replaces form
		_active[id] = inst
		_start_fx(inst, def)
	else:
		match str(def.get("stack_rule", "refresh")):
			"add":
				inst["stacks"] = mini(int(inst["stacks"]) + 1, int(def.get("max_stacks", 1)))
				inst["left"] = float(def.get("duration", 0.0))
			"add_time":
				inst["left"] = minf(float(inst["left"]) + float(def.get("duration", 0.0)),
						2.0 * float(def.get("duration", 0.0)))
			_:
				inst["left"] = float(def.get("duration", 0.0))
		inst["potency"] = maxf(float(inst["potency"]),
				float(ctx.get("potency", _default_potency(ctx.get("source")))))
		inst["src_iid"] = _src_iid(ctx.get("source"))
	# §2.3 threshold proc-chain (the wolf-bite canon).
	var th: Dictionary = def.get("threshold", {})
	if not th.is_empty() and int(inst["stacks"]) >= int(th.get("at", 999)):
		if bool(th.get("clear", true)):
			remove(id)
		apply(str(th.get("apply", "")), ctx)
	effects_changed.emit()
	return true

func remove(id: String) -> void:
	var inst: Dictionary = _active.get(id, {})
	if inst.is_empty():
		return
	_stop_fx(inst)
	_active.erase(id)
	effects_changed.emit()

func purge(dispel: String, max_removed: int = 99) -> int:
	## Removes debuffs of one school (cure potions, shrine, healer NPC).
	var n: int = 0
	for id: String in _active.keys().duplicate():
		var def: Dictionary = StatusDefs.get_def(id)
		if str(def.get("kind", "")) == "debuff" and str(def.get("dispel", "none")) == dispel:
			remove(id)
			n += 1
			if n >= max_removed:
				break
	return n

func clear_on_death() -> void:
	## Death/respawn: everything combat_only or non-persist drops; diseases
	## and food survive (dying does not cure the Infected — find the draught).
	for id: String in _active.keys().duplicate():
		var def: Dictionary = StatusDefs.get_def(id)
		if bool(def.get("combat_only", true)) or not bool(def.get("persist", false)):
			remove(id)

# --- Queries (hosts read these instead of their old ad-hoc fields) ----------

func has(id: String) -> bool: return _active.has(id)
func stacks(id: String) -> int: return int(_active.get(id, {}).get("stacks", 0))

func stat_delta(key: String) -> float:
	## Sum of flat stat_mods (per stack), with the stamina->hp alias expanded.
	var total: float = 0.0
	for id: String in _active:
		var mods: Dictionary = StatusDefs.get_def(id).get("stat_mods", {})
		var st: float = float(int(_active[id]["stacks"]))
		total += float(mods.get(key, 0.0)) * st
		if key == "hp":
			total += float(mods.get("stamina", 0.0)) * StatusDefs.STAMINA_HP * st
	return total

func speed_mult(is_player: bool) -> float:
	var m: float = 1.0
	for id: String in _active:
		var mods: Dictionary = StatusDefs.get_def(id).get("stat_mods", {})
		m *= pow(1.0 + float(mods.get("speed_pct", 0.0)) / 100.0,
				float(int(_active[id]["stacks"])))
	return maxf(m, PLAYER_SLOW_FLOOR if is_player else ENEMY_SLOW_FLOOR)

func damage_dealt_mult() -> float:
	var m: float = 1.0
	for id: String in _active:
		var mods: Dictionary = StatusDefs.get_def(id).get("stat_mods", {})
		m *= pow(1.0 + float(mods.get("damage_dealt_pct", 0.0)) / 100.0,
				float(int(_active[id]["stacks"])))
	return m

func damage_taken_mult(source: Node) -> float:
	## per_source marks (leverage_mark) only amplify their own marker's hits.
	var m: float = 1.0
	var sid: int = _src_iid(source)
	for id: String in _active:
		var def: Dictionary = StatusDefs.get_def(id)
		var pct: float = float(def.get("stat_mods", {}).get("damage_taken_pct", 0.0))
		if pct == 0.0:
			continue
		if bool(def.get("per_source", false)) and int(_active[id]["src_iid"]) != sid:
			continue
		m *= pow(1.0 + pct / 100.0, float(int(_active[id]["stacks"])))
	return minf(m, TAKEN_MULT_CAP)

func absorb_damage(amount: float) -> float:
	## Drains absorb pools oldest-first; pops the effect when spent (the
	## Divine Shield wrap-free behavior moves here). Returns the remainder.
	var left: float = amount
	for id: String in _active.keys().duplicate():
		if left <= 0.0:
			break
		var pool: float = float(_active[id].get("absorb_left", 0.0))
		if pool <= 0.0:
			continue
		var soaked: float = minf(pool, left)
		_active[id]["absorb_left"] = pool - soaked
		left -= soaked
		if pool - soaked <= 0.0:
			remove(id)
	return left

func rooted() -> bool: return has("rooted") or has("filed")

func active_list() -> Array[Dictionary]:
	## HUD contract: visible instances, buffs first, each
	## {id, name, icon, kind, dispel, left, duration, stacks}.
	var out: Array[Dictionary] = []
	for id: String in _active:
		var def: Dictionary = StatusDefs.get_def(id)
		if bool(def.get("hidden", false)):
			continue
		out.append({"id": id, "name": str(def.get("name", id)),
				"icon": str(def.get("icon", "")), "kind": str(def.get("kind", "debuff")),
				"dispel": str(def.get("dispel", "none")),
				"left": float(_active[id]["left"]),
				"duration": float(def.get("duration", 0.0)),
				"stacks": int(_active[id]["stacks"])})
	out.sort_custom(func(a, b): return a["kind"] < b["kind"])  # buff < debuff
	return out

# --- Ticking -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if host == null or not is_instance_valid(host) or host.get("is_dead") == true \
			or host.get("_dead") == true:
		return
	var changed: bool = false
	for id: String in _active.keys().duplicate():
		var inst: Dictionary = _active[id]
		var def: Dictionary = StatusDefs.get_def(id)
		if float(def.get("duration", 0.0)) > 0.0:
			inst["left"] = float(inst["left"]) - delta
			if float(inst["left"]) <= 0.0:
				remove(id)
				changed = true
				continue
		var interval: float = float(def.get("tick_interval", 0.0))
		if interval > 0.0:
			inst["tick_t"] = float(inst["tick_t"]) - delta
			if float(inst["tick_t"]) <= 0.0:
				inst["tick_t"] = float(inst["tick_t"]) + interval
				_run_tick(inst, def)
	if changed:
		effects_changed.emit()

func _run_tick(inst: Dictionary, def: Dictionary) -> void:
	var tick: Dictionary = def.get("tick", {})
	var stacks_f: float = float(int(inst["stacks"]))
	var dmg: float = float(inst["potency"]) * float(tick.get("damage_coeff", 0.0)) * stacks_f
	if dmg > 0.0 and host.has_method("take_tick_damage"):
		host.call("take_tick_damage", dmg, str(tick.get("school", "none")))
		var leech: float = float(tick.get("leech", 0.0))
		if leech > 0.0:
			_heal_source(inst, dmg * leech)
	var heal: float = float(tick.get("heal_flat", 0.0)) \
			+ float(inst["potency"]) * float(tick.get("heal_coeff", 0.0)) * stacks_f
	if heal > 0.0:
		_heal_host(heal)
	var mana: float = float(tick.get("mana_flat", 0.0))
	if mana != 0.0 and host.get("mana") != null:
		host.set("mana", clampf(float(host.get("mana")) + mana, 0.0,
				float(host.get("max_mana"))))

# --- Save/load (§10) ---------------------------------------------------------

func serialize() -> Array:
	var out: Array = []
	for id: String in _active:
		if bool(StatusDefs.get_def(id).get("persist", false)):
			out.append({"id": id, "left": float(_active[id]["left"]),
					"stacks": int(_active[id]["stacks"]),
					"potency": float(_active[id]["potency"])})
	return out

func deserialize(arr: Array) -> void:
	for e_v: Variant in arr:
		if e_v is Dictionary:
			var e: Dictionary = e_v
			apply(str(e.get("id", "")), {"potency": float(e.get("potency", 0.0)),
					"stacks": int(e.get("stacks", 1)), "left": float(e.get("left", 0.0))})
			if _active.has(str(e.get("id", ""))) and float(e.get("left", 0.0)) > 0.0:
				_active[str(e.get("id", ""))]["left"] = float(e.get("left", 0.0))
```

(`_immune` checks `host.get("status_immunities")` against id + dispel;
`_default_potency` reads `source.damage` for enemies or duck-calls
`_stat_damage()` for the player; `_start_fx`/`_stop_fx` own the FXLib
`fx_loop` aura exactly the way `player._buff_fx`/`_clear_buff_fx` do today —
that pair migrates in wholesale.)

### 4.1 `StatusField` — standing auras in the world

Listening dread near live stones needs a *place*, not a proc. Tiny inner
class (same file):

```gdscript
class StatusField extends Node2D:
	## Refreshes `effect` on the player every 0.5 s while within `radius`.
	## The effect's own short duration (1.2 s) makes leaving the field the cure
	## — no exit bookkeeping. Zone builders emit built["status_fields"]
	## ({pos, radius, effect}); main.gd instantiates beside enemy spawns.
	var effect: String = ""
	var radius: float = 90.0
	var _t: float = 0.0

	func _physics_process(delta: float) -> void:
		_t -= delta
		if _t > 0.0: return
		_t = 0.5
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and is_instance_valid(p) \
				and p.global_position.distance_to(global_position) <= radius:
			var s := StatusEffects.of(p)
			if s != null:
				s.apply(effect)
```

---

## 5. Wiring the damage paths (exact call-site diffs)

### 5.1 `Enemy.create` / cfg / zone tables

```gdscript
# enemy.gd — new fields + attach (in create(), beside the Nameplate):
e.status_immunities.assign(cfg.get("immunities", []))
e._procs = cfg.get("procs", [])            # Array[Dictionary], §6.1
e._status = StatusEffects.attach(e)

# zone_builder.gd:_enemy_spawns — passthrough (same 1-liners as
# COMBAT_PACING §9.5's level/archetype/rank):
#   "procs", "immunities"  ride from creature_table rows into the cfg.
```

`apply_slow` / `apply_root` keep their signatures (duck-called from
`player.gd:_aoe_pulse` — **no player-side change needed**) but become
wrappers: `apply_slow` applies `chilled` with a potency-encoded magnitude,
`apply_root` applies `rooted`. `_speed_now()` becomes
`speed * _status.speed_mult(false)`; the `_root_left` branch in
`_physics_process` reads `_status.rooted()`.

**Strike point** (the only place enemy melee lands, `_tick_windup`):

```gdscript
if to_p.length() <= HIT_RANGE:
	...
	Combat.deal_damage(player, damage * _status.damage_dealt_mult(), self)
	_fire_procs("hit", player)          # §6.1 — Bite lives here
```

**take_damage** gains two lines: incoming
`amount *= _status.damage_taken_mult(source)` (Sundered, marks) and a
`take_tick_damage(amount, school)` sibling that skips knockback and the
aggro-reset but keeps `_aggro_left = AGGRO_HOLD_TIME`, the number, and the
death check — bleeds keep mobs angry but never juggle them.

Enrage (COMBAT_PACING §5.6) and pack bonus (§5.4) become self-applied
statuses (`enrage`, `pack_frenzy`) instead of bespoke fields — they show on
the target frame's row (§9.3), which is exactly the legibility the pacing
doc asks for ("finish it or kite the last sliver" needs a visible cue).

### 5.2 Player integration

```gdscript
# player.gd — Player.create(), after inventory:
p.status = StatusEffects.attach(p)
p.status.effects_changed.connect(p._apply_equipment)

# _apply_equipment() — status joins the gear re-derivation:
max_hp = _base_max_hp + float(_totals.get("hp", 0.0)) + status.stat_delta("hp")
max_mana = _base_max_mana + float(_totals.get("mana", 0.0)) + status.stat_delta("mana")
speed = _base_speed * (1.0 + (float(_totals.get("speed_pct", 0.0))
		+ status.stat_delta("speed_pct")) / 100.0)
_mana_regen = _base_mana_regen + float(_totals.get("mana_regen", 0.0)) \
		+ status.stat_delta("mana_regen")

# _stat_damage() — flat status damage joins gear + level:
return float(_totals.get("damage", 0.0)) + level_damage_bonus + status.stat_delta("damage")

# _physics_process velocity line — _speed_mult retires:
velocity = input_dir * speed * status.speed_mult(true) * (...sprint...)
# plus a root gate right above it:
if status.rooted():
	velocity = Vector2.ZERO

# damage funnels (_do_melee_arc/_do_projectile/_do_aoe_ring/_do_volley) —
# _damage_mult retires:
var dmg: float = (base + _stat_damage()) * status.damage_dealt_mult()

# take_damage — _absorb retires; taken-mults slot after armor:
amt = maxf(1.0, amt - armor)
amt *= status.damage_taken_mult(_source)
amt = status.absorb_damage(amt)

# crit roll (_deal_player_damage/_arm_ranged):
var crit_pct: float = float(_totals.get("crit_pct", 0.0)) + status.stat_delta("crit_pct")
```

New sibling (the DoT funnel, §2.4):

```gdscript
func take_tick_damage(amount: float, school: String) -> void:
	## DoT tick: no i-frames, no armor, no shake/flash — absorbs still soak.
	if _dead:
		return
	var amt: float = status.absorb_damage(amount)
	if amt <= 0.0:
		return
	hp -= amt
	var parent := get_parent()
	if parent != null:
		VFX.damage_number(parent, global_position + Vector2(0.0, -26.0),
				int(round(amt)), StatusDefs.DISPEL_COLORS.get(school, Combat.DMG_ON_PLAYER))
	if hp <= 0.0:
		hp = 0.0
		_die()
```

`_die()`/`_respawn()` call `status.clear_on_death()` (replacing the manual
`_buff_left/_speed_mult/_damage_mult/_absorb` reset block at
`player.gd:1149–1152`). Note the design point hiding in `clear_on_death`:
**diseases and food persist through death** — dying in the bog does not cure
copper-sickness; the draught or the healer does.

### 5.3 `_do_buff` migration — class kits move in

`class_defs.gd` buff abilities gain one params key, `"status": "<effect id>"`
(defaults to the ability id). `_do_buff` shrinks to: play `params.fx`
one-shot, then `status.apply(status_id)` — duration/absorb/mults/`fx_loop`
now live in the def (§6.6 mapping table). `heal` (Lay on Hands' instant 50)
stays an inline params read — instant heals are not statuses. The
`_next_hit_bonus` spender also stays inline, but §9.5 gives it an icon.

---

## 6. The effect catalog (26 defs, lore-grounded)

Coefficients are per §3.6 (× applier damage per stack unless noted).
`P` = persists in the save; `C` = combat_only.

### 6.1 Creature proc passives — cfg syntax first

```gdscript
# creature_table rows (zone_defs.gd) — beside level/archetype/rank:
"procs": [
	{"on": "hit", "apply": "bite", "chance": 1.0},
	# "on": "hit" (every landed melee), "hit_heavy" (COMBAT_PACING §5.1
	# heavy swings only), "was_hit" (retaliation, melee attackers only),
	# "cast_hit" (caster bolt impact — rides Projectile.on_hit §5.4-style).
]

# enemy.gd:
func _fire_procs(when: String, victim: Node2D) -> void:
	var vs := StatusEffects.of(victim)
	if vs == null:
		return                       # scarecrow/fauna: immune by absence
	for p_v: Variant in _procs:
		if p_v is Dictionary and str(p_v.get("on", "")) == when \
				and randf() < float(p_v.get("chance", 1.0)):
			vs.apply(str(p_v.get("apply", "")), {"source": self})
```

### 6.2 Beast & border families (Acts I–II — the shipped nine zones)

| id | Name | kind/dispel | Applier (proc) | Stack/dur | Payload |
|---|---|---|---|---|---|
| `bite` | Bite | debuff/bleed | wolves, all (`on:hit`) | add ×3, 12 s | tick 0.12×dmg / 3 s per stack; **threshold {at:3, apply:"infected", clear:true}** |
| `infected` | Infected | debuff/disease | via Bite threshold | refresh ×1, 300 s, **P** | `stat_mods {"stamina": -1}` (−10 max HP) until cured/expired |
| `gore` | Gored | debuff/bleed | boars, on charge hit (`hit_heavy`) | add ×2, 8 s | tick 0.2×dmg / 2 s; pairs with the charge's 50% slow (COMBAT_PACING §5.3) |
| `mange` | Mange | debuff/disease | starving dogs (`on:hit`, 35%) | add ×5, 20 s | `stat_mods {"armor": -2}` per stack — swarm chip that makes facetanking packs decay |
| `smugglers_ash` | Smuggler's Ash | debuff/poison | river smugglers/cutpurses (`on:hit`, 25%) | refresh, 10 s | tick 0.1×dmg / 2 s + `speed_pct: -10` — duelists teach disengage twice over |
| `grave_rust` | Grave-Rust | debuff/none | Grave Warband heavy swing (`hit_heavy`) | add ×3, 15 s | `stat_mods {"armor": -3}` per stack — the guarded family strips your guard back |

### 6.3 The named canon (owner's list)

| id | Name | kind/dispel | Source | Stack/dur | Payload |
|---|---|---|---|---|---|
| `thread_touch` | Thread-Touch | debuff/curse | thread-touched dead heavy swing; Entranced bolts (`cast_hit`, 50%) | refresh, 4 s, C | `speed_pct: -30` — blue filament clings, the leg forgets its errand. The first slow the player ever eats (Iron Vein), and the tutorial for curse cures |
| `copper_sickness` | Copper-Sickness | debuff/disease | **environment**: drinking from a tainted Copper Wells well (E-interact: restores 25% hp, 60% chance of this — a real decision) | refresh, 240 s, **P** | `mana_regen: -50%` of base (impl: `stat_mods {"mana_regen": -3}`) + nausea tick 1 dmg-flat / 10 s. Cured at Vetka's healer for coin |
| `listening_dread` | Listening Dread | debuff/none | **StatusField** (r=90) around live inscription stones (Copper Wells, Stonepath) | refresh, 1.2 s (field-refreshed) | `damage_dealt_pct: -10, crit_pct: -5` — near the stone, your hands listen instead of working. Leaving the ring is the cure; the Warden of the Wells elite lairs inside one |
| `varcolac_rend` | Rend | debuff/bleed | varcolac (Act III+ wolf-kin elites), `hit_heavy` | add ×5, 12 s | tick 0.22×dmg / 2 s per stack — at 5 stacks it out-damages the swing; the "don't eat two signatures" rule (COMBAT_PACING §2) in DoT form |
| `leverage_mark` | Leverage-Mark | debuff/curse | strigoi cast (Act IV), 1.6 s interruptible | refresh, 30 s, `per_source: true` | `damage_taken_pct: +15` **from the marker only** — the strigoi holds your note, no one else can collect. Interrupt the cast or chalk-ward it |
| `finalized_chill` | Finalized Chill | debuff/magic | the Finalized (Act VI), `on:hit` | add ×5, 6 s | `speed_pct: -8` per stack; **threshold {at:5, apply:"filed", clear:true}** |
| `filed` | Filed | debuff/magic | via Finalized Chill | refresh, 1.5 s, C | hard root (`rooted()` includes it) — "stamped, closed to amendment." The Act VI kiting exam |
| `hungering_touch` | Hungering Touch | debuff/none | the Hungering (`on:hit`) | refresh, 6 s | tick 0.15×dmg / 2 s with `leech: 1.0` — it eats what you are; swarm math (×4 pulls) makes AoE-or-die literal |
| `zealot_hex` | Hex of the Thin Harvest | debuff/curse | Cult Zealot cast (Grey Marches+), interruptible | refresh, 12 s | `damage_dealt_pct: -15` — the kill-order/interrupt curriculum gets teeth: leave the healer up AND hexed and the fight stalls |

### 6.4 Enemy-side states (player-applied + self-buffs)

| id | Name | kind/dispel | Source | Payload |
|---|---|---|---|---|
| `chilled` | Chilled | debuff/magic | migration target of every `apply_slow` call (Frost Nova, Earthshaker, Stormbolt…) | `speed_pct` encoded from the old `mult` arg; refresh, per-ability duration, C |
| `rooted` | Rooted | debuff/magic | migration of `apply_root` (Thornroot, Grave Grasp, Snare Trap) | hard root; refresh; C; rares ×0.5 duration (§2.6) |
| `sundered` | Sundered | debuff/none | warrior Sunder / Judgment-class hits (the COMBAT_PACING §5.5 `"sunder": true` payload becomes `status.apply("sundered")`) | 4 s: suppresses the guarded front + `damage_taken_pct: +10`. Visible on the target frame = burst-window legibility |
| `enrage` | Enraged | buff(enemy)/none | self, at <30% hp (chargers, some brutes) | `speed_pct: +35, damage_dealt_pct: +40`, until death; red tint via `fx_tint` |
| `pack_frenzy` | Pack Frenzy | buff(enemy)/none | self, per living packmate in 120 px | add ×3, `damage_dealt_pct: +10`/stack, re-evaluated on the §5.4 pack tick — killing adds visibly strips stacks off the alpha's plate row |

### 6.5 Player consumables & world buffs

| id | Name | kind/dispel | Source | Stack/dur | Payload |
|---|---|---|---|---|---|
| `well_fed` | Well Fed | buff | Bent Oar stew, hearth-cooked meals (crafting) | group `food`, 600 s, **P** | `stamina: +1` (+10 max HP) per bracket tier (Act III+ recipes: +2/+3) |
| `travelers_ration` | Hard Ration | buff | vendor food (the poor-tier coin sink pays back) | group `food`, 600 s, **P** | `hp regen` tick `heal_flat: 1.0` / 2 s **out of combat only** (`combat_gate: true` — tick checks the COMBAT_PACING §9.2 ooc flag) |
| `embersalve` | Embersalve | buff | crafted potion (basaltfang line, Act V materials scale it) | 30 s | HoT: `heal_flat` = bracket-tiered (L10 pot: 4/2 s) — the mid-fight answer bleeds demand |
| `swiftroot_tea` | Swiftroot Tea | buff | crafted drink | group `drink`, 300 s, **P** | `speed_pct: +8` — travel QoL, the kiting cheat for slow classes |
| `chalk_ward` | Chalk Ward | buff | Maren's chalk (Act II vendor/quest item — "a ring of chalk keeps nothing out; it marks who was kept in") | 300 s, **P** | absorbs the **next curse application** (component checks wards before applying `dispel:"curse"` defs; consumed on trigger) |
| `restorative_draught` | — (instant) | item effect | vendor/craft potion | — | `status.purge("disease"); status.purge("poison")` — not a status itself; the standing answer to Infected/copper-sickness |

### 6.6 Class-kit migration map (the 10 shipped `kind:"buff"` abilities)

Same numbers, new home — `params` keeps `fx`/`fx_tint`, the def takes
duration/absorb/mults/`fx_loop`:

| Ability (class_defs.gd) | New def id | Def payload (verbatim from params) |
|---|---|---|
| war_cry (warrior) | `war_cry` | 5 s, `speed_pct:+40, damage_dealt_pct:+30` |
| iron_bulwark (warrior) | `iron_bulwark` | 6 s, `absorb: 40`, fx_loop iron_bulwark |
| shroud (rogue) | `shroud` | 4 s, `speed_pct:+35, damage_dealt_pct:+20, absorb:30` |
| mana_shield (mage) | `mana_shield` | 6 s, `absorb: 55` |
| lay_on_hands (paladin) | — stays instant (`heal: 50` in params) |
| divine_shield (paladin) | `divine_shield` | 6 s, `absorb: 40`, fx_loop divine_shield |
| holy_dome (paladin) | `holy_dome` | 8 s, `absorb: 70, speed_pct:+20`, fx_loop holy_dome |
| bone_armor (necromancer) | `bone_armor` | 8 s, `absorb: 45, damage_dealt_pct:+15`, fx_loop bone_ward |
| hunters_mark (rookwarden) | `hunters_mark` | 6 s, `speed_pct:+10, damage_dealt_pct:+35` |
| rejuvenation (druid) | `rejuvenation` | 6 s, tick 1 s `heal_flat: 7` (+ instant 18 stays in params) |
| bear_form (druid) | `bear_form` | group `form`, 8 s, `damage_dealt_pct:+40, speed_pct:+10, absorb:35` |

Payoff: **buffs now stack across abilities** (War Cry + Iron Bulwark
coexist), every one shows an icon with a sweep, absorbs share one pool
mechanism, and Rejuvenation survives a map change instead of living in a
scene-tree timer.

### 6.7 Canonical exemplar defs (paste-ready, the wolf chain + one of each shape)

```gdscript
	"bite": {
		"id": "bite", "name": "Bite", "icon": "pixel:bite",
		"kind": "debuff", "dispel": "bleed",
		"duration": 12.0, "max_stacks": 3, "stack_rule": "add", "group": "",
		"tick_interval": 3.0,
		"tick": {"damage_coeff": 0.12, "school": "bleed"},
		"stat_mods": {}, "absorb": 0.0,
		"threshold": {"at": 3, "apply": "infected", "clear": true},
		"per_source": false, "persist": false, "combat_only": true, "hidden": false,
		"fx_loop": "", "fx_tint": Color(0.62, 0.16, 0.12),
	},
	"infected": {
		"id": "infected", "name": "Infected", "icon": "pixel:infected",
		"kind": "debuff", "dispel": "disease",
		"duration": 300.0, "max_stacks": 1, "stack_rule": "refresh", "group": "",
		"tick_interval": 0.0, "tick": {},
		"stat_mods": {"stamina": -1.0}, "absorb": 0.0,
		"threshold": {}, "per_source": false,
		"persist": true, "combat_only": false, "hidden": false,
		"fx_loop": "", "fx_tint": Color(0.62, 0.52, 0.22),
	},
	"leverage_mark": {
		"id": "leverage_mark", "name": "Leverage-Mark", "icon": "pixel:leverage_mark",
		"kind": "debuff", "dispel": "curse",
		"duration": 30.0, "max_stacks": 1, "stack_rule": "refresh", "group": "",
		"tick_interval": 0.0, "tick": {},
		"stat_mods": {"damage_taken_pct": 15.0}, "absorb": 0.0,
		"threshold": {}, "per_source": true,
		"persist": false, "combat_only": true, "hidden": false,
		"fx_loop": "", "fx_tint": Color(0.52, 0.30, 0.66),
	},
	"well_fed": {
		"id": "well_fed", "name": "Well Fed", "icon": "pixel:well_fed",
		"kind": "buff", "dispel": "none",
		"duration": 600.0, "max_stacks": 1, "stack_rule": "refresh", "group": "food",
		"tick_interval": 0.0, "tick": {},
		"stat_mods": {"stamina": 1.0}, "absorb": 0.0,
		"threshold": {}, "per_source": false,
		"persist": true, "combat_only": false, "hidden": false,
		"fx_loop": "", "fx_tint": Color(0.85, 0.68, 0.35),
	},
	"war_cry": {
		"id": "war_cry", "name": "War Cry", "icon": "pixel:war_cry",
		"kind": "buff", "dispel": "none",
		"duration": 5.0, "max_stacks": 1, "stack_rule": "refresh", "group": "",
		"tick_interval": 0.0, "tick": {},
		"stat_mods": {"speed_pct": 40.0, "damage_dealt_pct": 30.0}, "absorb": 0.0,
		"threshold": {}, "per_source": false,
		"persist": false, "combat_only": true, "hidden": false,
		"fx_loop": "", "fx_tint": Color(0.90, 0.58, 0.30),
	},
```

---

## 7. The canonical walkthrough — wolf bite to Infected

Zone table (`iron_vein` Mudwolves, COMBAT_PACING §10.2) gains one key:

```gdscript
{"type": "wolf", "name": "Mudwolf", ..., "archetype": "stalker",
	"procs": [{"on": "hit", "apply": "bite", "chance": 1.0}], ...},
```

1. Wolf's windup resolves in `enemy.gd:_tick_windup` → `Combat.deal_damage`
   → `_fire_procs("hit", player)` → `player.status.apply("bite",
   {"source": self})`. Potency snapshots the wolf's `damage` (12 at L3).
2. Instance: 1 stack, 12 s. Every 3 s, `take_tick_damage(1.4, "bleed")` —
   no i-frames touched, red-tinted small number, HUD debuff icon with a
   bleed-red rim and a "1" pip.
3. Second bite inside 12 s → `stack_rule:"add"` → 2 stacks, duration
   refreshes, ticks now 2.9. The pip reads "2". The player is learning what
   the stalker family teaches: stop tanking, start kiting.
4. Third bite → stacks hit `threshold.at = 3` → Bite clears itself and
   `apply("infected")` fires. The gold-less ochre icon appears: **Infected**,
   −1 Stamina → `_apply_equipment` re-derives `max_hp` −10 on the spot (the
   HP bar visibly shrinks — the WoW disease feel).
5. Infected persists 5 minutes, through zone travel, saves (§10), and death.
   Cures: Restorative Draught (right-click in bag → `purge("disease")`),
   or the Vetka healer NPC for coin.
6. Pack math: 3 mudwolves biting = stacks build ~3× faster — the disease is
   nearly guaranteed in a facetanked pack pull, nearly impossible if the
   player kites and AoEs. The proc **is** the curriculum.

Budget check (§3.6): full Bite uptime at 3 stacks ≈ 0.12×3 ≈ one extra wolf
hit every 3 s ≈ +22% pack DPS — inside the 1.5-hit law, and Infected's −10
max HP ≈ 5% of a L5 mid-class pool: felt, not lethal.

---

## 8. Consumables — item plumbing

Items reuse the existing `effect` id hook (the legendary precedent in
`player.gd:_slot_effect`) but for bag right-click "use", which BagUI already
supports for the weeping_dagger bury interaction. Convention:

```gdscript
"restorative_draught": {
	"id": "restorative_draught", "name": "Restorative Draught", "slot": "none",
	"rarity": "common", "icon": "pixel:restorative_draught",
	"stats": {...all zeros...},
	"flavor": "Bitter as a paid debt. Works like one too.",
	"stackable": true, "effect": "use:cure_disease_poison",
	"ilvl": 6, "req_level": 1, "set_id": "", "value": 2,
},
```

`effect` ids beginning `use:` route through a small `_use_consumable(item)`
in bag_ui → player: `cure_disease_poison` → two purges; `apply:<status_id>`
→ `status.apply(...)` (well_fed, embersalve, swiftroot_tea, chalk_ward).
Food/potion potency tiers ship per act bracket like every other item line
(ITEM_PROGRESSION §6 vendor rules: food is the consumable coin sink).

---

## 9. HUD — buff/debuff rows (640×360, gold-bezel kit)

### 9.1 Placement (from shipped geometry)

- **Player rows**: two rows of up to 8 cells, left-aligned at
  `x = UF_MARGIN (8)`, starting `y = 63` — directly under the XP bar
  (which ends at y=61). Row 1 = buffs, row 2 (y = 79) = debuffs. Cells are
  **14×14** (12 px icon + 1 px rim), 2 px gap — 8 cells span 126 px, clear
  of the tracker/minimap column on the right.
- **Target row**: one row of up to 8 cells under the target frame at
  `x = 132, y = 52` — shows the target's list (Sundered, Chilled, Enrage,
  Pack Frenzy...). This is the burst-window readout COMBAT_PACING §9.4 wants.

### 9.2 Cell anatomy (all existing patterns, no new art tech)

| Part | Implementation |
|---|---|
| Icon | `HUD._load_icon(def.icon)` — IconsPixel Shikashi cells, `TEXTURE_FILTER_LINEAR` at 12 px exactly like the 26 px ability-bar icons (the painterly-downscale rule) |
| Rim | 1 px `StyleBoxFlat` border: buffs `GOLD`-brown (`SLOT_BORDER` warmed), debuffs `StatusDefs.DISPEL_COLORS[dispel]` — the school IS the rim, no text needed |
| Duration sweep | the ability-bar cooldown pattern verbatim: bottom-anchored `COOLDOWN_SHADE` ColorRect whose height = `(1 - left/duration) × 14` — shade rises as time drains |
| Stack pips | Alagard 8, `PARCHMENT`, 2 px dark outline, bottom-right, only when stacks > 1 |
| Expiry blink | `left < 3 s` → modulate alpha pulses at 3 Hz (tween, the `_flash_tween` idiom) |
| Tooltip | reuse `_ability_tip` (panel already exists): name, school line ("Disease — cured by a Restorative Draught"), effect line, time left. Cells use `MOUSE_FILTER_PASS` like ability slots so LMB still attacks through them |

### 9.3 Update loop

Poll-based like everything else in `hud.gd:_process`: read
`player.get("status")`, call `active_list()`, diff against the built cells
(cheap: rebuild only when `effects_changed` fired — HUD connects the signal
and sets a dirty flag; per-frame work is just sweep heights and pip text).
Target row reads `StatusEffects.of(player.target)` — null (scarecrow) hides
the row. Pre-build 8+8+8 hidden cells in `_ready` (the `_tracker_entries`
pre-build pattern), so runtime never allocates Controls.

### 9.4 Nameplate hint (cheap, optional first pass)

Enemy Nameplates gain up to 3 4×4 px squares right of the HP bar, colored by
dispel school of active debuffs — enough to see "my bleed is still rolling"
across a pack without reading the target frame. Drawn in the existing
`Nameplate._draw` (it already redraws on frac changes).

### 9.5 Spender icon

`_next_hit_bonus` (Shield Charge/Shadowstep) gets a `hidden:false, duration:
bonus_duration` mirror def `empowered_strike` applied alongside the field —
purely cosmetic (the field stays authoritative), so the "your next hit is
loaded" state finally has UI. One line in `_do_dash`.

---

## 10. Save / load

Rides SaveSystem v1 unchanged (tolerant reads; additive key):

```gdscript
# save_system.gd:collect_state() — inside the "player" block:
"status": _collect_status(player),          # -> Array (JSON-safe)

static func _collect_status(player: Node) -> Array:
	var s: Node = (player as Node2D).get_node_or_null("Status")
	if s != null and s.has_method("serialize"):
		var v: Variant = s.call("serialize")
		if v is Array:
			return v
	return []

# _normalize(): pass raw player.status through if it is an Array (else []).

# apply_player_state() — step 3.5, after inventory / before vitals (so the
# stamina/hp mods are live before hp clamps to max_hp):
var st: Node = (player as Node2D).get_node_or_null("Status")
if st != null and st.has_method("deserialize"):
	var arr_v: Variant = p.get("status")
	if arr_v is Array:
		st.call("deserialize", arr_v)
```

Rules recap: only `persist: true` defs serialize (`infected`,
`copper_sickness`, `well_fed`, `travelers_ration`, `swiftroot_tea`,
`chalk_ward`); entries are `{id, left, stacks, potency}` — plain JSON
scalars, id-keyed against the def registry exactly like items reconstruct
from `Items._DB`, so balance patches to defs reach old saves and unknown ids
degrade with a warning, never a crash. Combat CC never saves; autosave on
travel therefore never freezes a root into a save file.

---

## 11. Composition audit (the other docs' contracts, honored)

| Contract | How this doc keeps it |
|---|---|
| COMBAT_PACING TTK 8–15 s / HP-cost 20–35% | DoT budget law §3.6 (≤1.5 hits/duration for normals); slows floor at 0.5 on the player so kiting is never impossible; enrage/pack numbers are the pacing doc's own, just re-homed |
| §9.1 per-attacker i-frame fix | ticks bypass the hit gate entirely (`take_tick_damage`) — DoTs neither consume nor grant hit credit |
| §9.2 out-of-combat regen | food regen defs gate on the same ooc flag; Well Fed's +Stamina is the "eat before the elite" beat that makes the regen rhythm a *choice* |
| §5.5 guard-break payload | `"sunder": true` becomes `sundered` status — one mechanism, now visible |
| ITEM_PROGRESSION stat language | `stat_mods` speaks `STAT_KEYS` verbatim; Stamina alias documented (1 = 10 hp) so future gear/food tiers share one word |
| Icon law | effect icon id == effect id, IconsPixel REGISTRY cells, PIL-verified — same checklist row as the 40 item exemplars |
| SaveSystem duck-typed systems | component exposes `serialize()/deserialize()`; player-block key is additive and tolerant |
| Scarecrow / fauna safety | no component → `StatusEffects.of()` null → immune, mirroring the existing `has_method("apply_slow")` guard |

---

## 12. Rollout order

1. **Component + defs + player wiring** (`status_effects.gd`,
   `status_defs.gd`, §5.2 player diffs) with the 10 class-kit migrations —
   pure refactor, provable by the existing feel (War Cry still War Cries),
   plus the multi-buff fix lands immediately.
2. **Enemy wiring** (§5.1): attach, `apply_slow`/`apply_root` wrappers,
   `take_tick_damage`, `_fire_procs`, cfg passthrough in `zone_builder`.
3. **The wolf canon** (§7): `bite` + `infected` + Restorative Draught +
   Vetka healer dialogue line. Playtest gate: 3-wolf Iron Vein pack infects
   a facetanker ~100% and a kiter ~rarely; draught cures; save/reload keeps
   the disease.
4. **HUD rows** (§9): player buffs/debuffs, target row, tooltips, sweep +
   pips + blink. (Ship 3 and 4 together — an invisible disease is a bug
   report, not a mechanic.)
5. **Catalog wave 1** (shipped zones): gore, mange, thread_touch,
   copper_sickness wells, listening_dread fields, zealot_hex,
   hungering_touch, smugglers_ash, grave_rust; enrage/pack_frenzy/sundered
   re-homes; food/potion/tea/chalk items.
6. **Catalog wave 2** (with their acts): varcolac_rend, leverage_mark,
   finalized_chill/filed — each ships alongside its creature family, not
   before.
7. **Save block** (§10) — lands with step 3 (Infected must persist on day 1).

Playtest gates: Copper Wells L5 warrior — a played 3-pull with wolves ends
≤40% HP with Bite ticking (pacing intact); an ignored Infected across two
zones is noticed on the HP bar; buff row never exceeds 6 live icons in
normal play (if it does, more `hidden: true`, not smaller icons).
