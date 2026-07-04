# FREEDOM & PHYSICS — GTA Freedom + Zelda Physics
Raven Hollow · Draconia canon · Godot 4.6 · composes with COMBAT_PACING / MOUNTS / WORLD_PLAN.

Owner mandates served (MANDATES.md § Freedom & Physics):
- **GTA-grade player freedom** — go anywhere, no artificial gates, emergent systems.
- **Real physics, Zelda-style** — pushable/rollable/burnable world props, physical
  interactions that COMBINE (fire + wind + hay; barrel + barrel + slag-walker).
- Engineering Law: everything below ships with headless asserts + build-time validators.

Grounded in (read before implementing):
- `scripts/zone_builder.gd` — `_build_border_wall` (edge forest + `border_gaps`),
  `_build_roads`/`_build_river` polylines, `_validate_forty_second_rule` (the validator
  pattern §5 copies), static prop helpers (`_sprite`/`_atlas` — no bodies on props today).
- `scripts/map_registry.gd` + `scripts/main.gd:601` — travel loop: `[E]` prompt inside a
  28–40 px radius point → `change_map(to_map, to_point)`. **No level/quest checks — keep.**
- `scripts/zone_defs.gd` — per-zone `border_gaps: [Rect2]` + `travel_points`; the two are
  hand-kept in sync today (a validator below makes that law).
- `scripts/travel_system.gd` — discovery-gated waystations (soft gate, correct as-is).
- `scripts/weather.gd` — `WeatherController` (group `"weather"`): `Type.{CLEAR,RAIN,STORM,
  SNOW,FOG,ASH}`, `current_type()`, `_intensity`, `_wind` (-1..1, drives rain slant).
  §9/§10 read these; `_wind` gets a public getter.
- `scripts/player.gd` — CharacterBody2D, `speed 90`, sprint ×1.55, `collision_layer = 2`,
  `collision_mask = 1`, `MOTION_MODE_FLOATING`; `take_damage` (no knockback on player yet).
- `scripts/enemy.gd` — `collision_layer = 1<<3`, `collision_mask = 1`; `take_damage`
  already nudges via `move_and_collide(away * KNOCKBACK_PX)` (upgrade path §10.3);
  leash/aggro per COMBAT_PACING §5.8.
- `scripts/combat.gd` — `Projectile extends Area2D` (`collision_mask = 1`, faction-aware);
  wind drift hooks in §10.2. `Combat.deal_damage` is the single damage funnel — knockback
  rides it.
- `design/COMBAT_PACING.md` §5.1 heavy/signature telegraphs (knockback composition §10.3),
  §5.3 charge, §5.8 leashes. `design/MOUNTS.md` §1.2 mount rules (§6.3 extends).
- `_lore_extract.txt` / WORLD_PLAN canon: Thread filaments, warm ground, copper wells,
  the Debt Pit ledger, Greyhollow canals, the Gift, Ashvents heat-hides-the-signal.

---

# PART A — GTA FREEDOM

## 1. Freedom audit — every gate that exists today

| # | Gate | Source | Verdict |
|---|---|---|---|
| A | **Zone seams are doors, not borders.** Crossing requires standing in a 28–40 px circle and pressing E (`main.gd:601`, `travel_points`). Between two zones the world is a wall with one doorbell. | `map_registry.gd`, `main.gd` travel loop | **FIX §3** — seams become walk-through gaps |
| B | **Border forest ring** with authored `border_gaps` — honest (visible trees, real colliders, gaps where roads exit). But gap count is uneven: `grey_marches` has **1** gap (`zone_defs.gd:549`) while its WORLD_PLAN neighbors imply 2. No validator enforces gap ↔ travel-point ↔ neighbor agreement. | `zone_builder.gd:_build_border_wall`, `zone_defs.gd` | **KEEP mechanism, LAW §3.2** |
| C | **No level walls, no quest walls.** `change_map` has zero requirement checks. A level-1 can stand in Riverfork today (L15–18 mobs). | `main.gd:468` | **CORRECT — freeze as Law F1** |
| D | **Fast travel discovery gate** — waystations must be walked to first; routes BFS over discovered graph. | `travel_system.gd` | **KEEP** (soft gate = earned convenience, not a wall) |
| E | **Rivers have no collision** (Line2D visuals only) — currently walk-over-water everywhere; canals in C2 will read absurd. | `zone_builder.gd:_build_river` | **FIX §6.4** — water slows, never blocks |
| F | **Mount gates**: riding at 40/60 for gold (MOUNTS §1.1). Feet are never gated. | MOUNTS.md | **KEEP** (progression, not a wall) |
| G | **Landmark buildings have no colliders** in ZoneBuilder zones (`_sprite` adds occluders only) — walk-through houses. Freedom by accident, jank in effect. | `zone_builder.gd:_sprite` | **FIX via §7** props pass (solid tier) |
| H | Camera bounds per zone (`built["bounds"]`) | `main.gd` | KEEP (zones tile the continent; seams handle egress) |
| I | Enemy leash 280–340 px (COMBAT_PACING §5.8) — mobs give up, players can always disengage. | `enemy.gd` | **KEEP — this is a freedom system** |

**The one real violation of the GTA principle is A** (+ its authoring hygiene B). Everything
else is already danger-shaped, not wall-shaped.

## 2. The Freedom Law (five laws, frozen)

- **F1 — Any zone on foot from level 1.** No `change_map` requirement checks, ever.
  Danger is the gate: Riverfork mobs con red to a level 3; the road still exists.
- **F2 — No invisible walls.** Every collider the player can touch has visible art
  (trees, cliffs, buildings, water). Border rings must have gaps; gaps must be findable
  by following any road to the zone edge.
- **F3 — Roads are promises.** Every road polyline that reaches a zone edge ends in a
  border gap + seam. A road that dead-ends into forest wall is a build error (§3.2).
- **F4 — Danger cons honestly.** The mob tells you it will kill you (con colors §4);
  the world never pretends you can't *try*.
- **F5 — Everything that gates must be crossable by skill or nerve.** Aggro can be
  outrun (leashes), water can be waded (slow), elites can be walked past (aggro radii
  are dodgeable corridors), night doubles wolf aggro but the road is still there.

## 3. Seams v2 — walk-through borders

### 3.1 Mechanic
Today's point-and-press travel points become **seam rects**: walking through a border gap
IS the transition. Implementation (small change, `main.gd` travel loop):

```gdscript
## zone_defs.gd travel_points gain: "seam": Rect2 (the border_gap rect, or a sub-rect).
## main.gd _physics_process travel loop replaces the radius check:
for tp: Dictionary in MapRegistry.travel_points(current_map_id):
    if tp.has("seam"):
        if (tp["seam"] as Rect2).has_point(ppos) and not _changing_map:
            change_map(str(tp["to_map"]), str(tp["to_point"]))   # no prompt needed
    elif ppos.distance_to(tp["pos"]) <= float(tp["radius"]):     # legacy points (ferry,
        _show_travel_prompt(tp)                                   # dungeon doors) keep [E]
```

- Arrival placement: spawn 48 px *inside* the destination gap along the entry direction
  (existing `change_map` nudge logic, direction from the seam's edge normal) — walking
  back immediately re-crosses; no trap.
- Signage stays: the signpost + `[E]`-era prompt text becomes a floating zone-name label
  at the gap ("The Stonepath ⟶"), plus the zone banner on arrival (already exists).
- Boats/dungeon entrances/thread-gate remain `[E]` points (deliberate thresholds).

### 3.2 Authoring law + validator (build-time, like the 40s rule)
Every zone def must satisfy — `ZoneBuilder._validate_freedom(def)` warns otherwise:
1. Every WORLD_PLAN-adjacent zone pair has **≥1 seam pair** whose `to_map`/`to_point`
   round-trips (A→B names a point in B that returns to A).
2. Every `travel_point` with a `seam` lies inside a `border_gaps` rect of its zone
   (else the player faces tree colliders inside the "gap").
3. Every road polyline endpoint within 200 px of the zone edge lies inside a gap (F3).
4. Every border edge facing an adjacent zone has **≥2 gaps**: the road gap (seam) and at
   least one **wild gap** — an unmarked hole in the tree ring for players who hug the
   forest instead of the road. Wild gaps carry a seam too (same destination, offset
   entry pos). *GTA principle: the fence has holes everywhere, not just at the gate.*
5. `grey_marches` (audit B) gets its second gap in the same batch this ships.

## 4. Danger is the gate — the con system

Level-difference con colors on nameplates + target frame (WoW law, honest signage):

| Δ = mob − player | Con | Nameplate |
|---|---|---|
| ≤ −8 (gray-out per XP falloff) | Gray | no XP, ignores you unless struck |
| −7…−3 | Green | easy |
| −2…+1 | Yellow | fair fight (COMBAT_PACING TTK contract) |
| +2…+4 | Orange | hard — expect 50 %+ HP cost |
| +5…+9 | **Red** | will probably kill you; *paths still exist* |
| ≥ +10 | **Skull** | flee on sight; aggro radius shown as a faint ring when targeted |

- Implementation: `Nameplate` tint from `mob_level - player.level` (levels already flow
  into Enemy cfg per COMBAT_PACING §9.5). Skull-con mobs draw their aggro radius (one
  `VFX.ring`, 0.08 alpha) when the player targets them — running red zones becomes a
  readable stealth game, not a dice roll.
- **Road-shy spawns** (the GTA freeway rule): creature-table `area` rects must sit so
  that no pack anchor is within `aggro_px + 40` of a road polyline (validator warning).
  Roads through red zones are dangerous *corridors*, not death sentences — wolves lunge
  from the treeline, they don't picnic on the cobbles. Named exceptions allowed
  (ambush camps, toll-forts) — flag the row `"road_ambush": true` to silence the check.

## 5. Climb-free topology — zone-authoring rules + reachability validator

2D top-down has no jump; "climbable" means *routable*. Frozen rules for every zone def:

- **T1 — One walkable component.** All walkable ground in a zone is a single connected
  region. No collider loop may close (courtyards need archways; cliff lines need ramp
  gaps every ≤ 1,750 px — same constant as the 40s rule, they compose).
- **T2 — Water never disconnects.** Rivers/canals get fords or bridges every ≤ 1,750 px
  of polyline; water elsewhere is wade-slow (§6.4), so even a missing bridge is a slog,
  not a wall.
- **T3 — Landmarks are touchable.** Every landmark/vignette/waystation anchor is
  reachable and has ≥ 24 px of walkable ring (quest objects can never be sealed off).
- **T4 — Solid props never tile into walls.** §7 solid-tier props must keep ≥ 48 px
  (1.5 player widths) between collider edges unless they are part of an authored
  building footprint.

Build-time validator (runs with the 40s rule, same warn-and-backfill loop):

```gdscript
## ZoneBuilder._validate_reachability(parent, def, w, h) — after all builds.
## Rasterize static colliders into a 32px bool grid (physics-free: iterate the
## StaticBody2D shapes ZoneBuilder itself placed), flood-fill from player_spawn.
static func _validate_reachability(grid: Array, def: Dictionary) -> void:
    var reach := _flood_fill(grid, def["player_spawn"])         # BFS, 4-neighbour
    var total_walkable: int = _count_walkable(grid)
    if float(reach.size()) < 0.97 * float(total_walkable):
        push_warning("ZoneBuilder[topo]: zone '%s' — %d%% of walkable ground unreachable"
                % [def.get("id"), 100 - int(100.0 * reach.size() / total_walkable)])
    for lm_v: Variant in def.get("landmarks", []):              # T3
        if not _cell_reachable(reach, (lm_v as Dictionary)["pos"]):
            push_warning("ZoneBuilder[topo]: landmark sealed off at %s" % str(lm_v))
```

Plus one **world-graph validator** (`tools/validate_world_graph.gd`, headless): BFS the
seam graph from `raven_hollow`; assert all built zones reachable on foot; assert every
seam round-trips (§3.2.1). Runs in `tests/smoke` per the Engineering Law.

## 6. Emergent freedom systems

### 6.1 Aggro anything
Everything with a nameplate can be attacked, including neutral fauna and faction guards:
- **Guards** (capitals, toll-forts): skull-con elites using COMBAT_PACING guarded/duelist
  kits. Attacking one calls nearby guards (pack social aggro §5.4 reused, radius 220).
  They leash back to post like any mob. Dying to guards is the GTA wanted-level analog —
  no permanent faction damage in v1 (bots/faction rep is a deferred owner session).
- **Named quest NPCs**: attackable, fight back with a duelist kit, at 1 HP they *yield*
  (kneel, 60 s, then recover — quest web of ~1000 interconnected quests must not be
  breakable). Everything unnamed can die and respawns on zone rebuild.
- **Neutral fauna** (deer, crows, dogs) flee when struck — they're `stalker` archetype
  with `flee: true` (chase vector inverted). Chasing dinner into a wolf pack is the
  emergent-story generator.

### 6.2 Flee anywhere
- Leashes (COMBAT_PACING §5.8) already guarantee escape by distance. Frozen additions:
  **mobs never cross seams** (chase stops at border gaps — the forest ring is theirs,
  the seam is yours), and **combat never blocks travel** — seam crossing, waystation
  use (if already discovered), and mounting-up-out-of-combat-range all work while red.
- **Train mechanic stays legal**: dragging 9 wolves through a camp is allowed; social
  aggro does what it does. Freedom includes the freedom to cause problems.

### 6.3 Mount anywhere outdoors
Extends MOUNTS §1.2: mounting is legal in **every outdoor zone including hostile
capitals and red zones** — only interiors/dungeons block (`def["indoor"] = true`).
Combat rule unchanged (can't *begin* mounting within 5 s of combat). A level-1 on foot
crossing the Bloodroad and a level-60 on a tier-II mount use the same doors.

### 6.4 Water never walls (fixes audit E)
Rivers/ponds/canals gain an `Area2D` ribbon along the polyline (width = `river_width`):
inside it, player/enemy `_speed_mult` ×0.45 ("wading"), fauna unaffected if aquatic.
Deep water (C2 canals, `"deep": true`): ×0.30 + damage-over-time for metal-armored?
No — simpler and kinder: ×0.30 and abilities locked (arms busy swimming). Bridges and
fords are *faster*, never *required*. Canal Skiff mount (MOUNTS #23) trivializes C2 water.

### 6.5 Death is a wager, not a wall
Deep red-zone tourism needs a stake: on death, release to the nearest discovered
waystation's spirit and **corpse-run** (ghost is unaggroable, 1.5× walk speed); rez at
corpse restores 100 %. No durability loss v1, no XP loss ever. The level-4 who sneaks
into Sangeroasa risks a long walk, not their progress.

### 6.6 The Pilgrimage Probe (QA, Engineering Law)
`tools/pilgrimage_probe.gd` (headless): auto-walks a level-1 warrior along road
polylines Vetka → Stonepath → Bloodroad → Sangeroasa gate, no combat inputs, fleeing on
aggro (run vector = road direction). Asserts: arrival possible within N deaths (deaths
allowed — corpse runs resume the walk), zero stuck-frames (position must progress every
5 s), every seam crossed emits the zone banner. This test IS the freedom mandate,
executable. Runs per world batch.

---

# PART B — ZELDA PHYSICS

## 7. InteractiveProp — the component

One scene-free class (Zone/Town/Wilderness builders all spawn it), `scripts/interactive_prop.gd`:

```gdscript
class_name InteractiveProp
extends RigidBody2D
## Tiered physical world-prop. Top-down: gravity_scale = 0, damping does the work.
## cfg = {tier, texture|atlas+region, mass, flammable, explosive, roll_axis, hp,
##        loot_table, on_break_vfx}

enum Tier { SOLID, PUSHABLE, ROLLING, EXPLOSIVE, BURNABLE_STATIC }

const LAYER_PROP := 1 << 4                # physics layer 5 (§8)

static func create(cfg: Dictionary) -> InteractiveProp:
    var p := InteractiveProp.new()
    p.gravity_scale = 0.0                 # top-down world: no "down"
    p.collision_layer = LAYER_PROP
    p.collision_mask = 1 | LAYER_PROP     # world + other props (actors push via §8.2)
    p.lock_rotation = cfg.get("tier") != Tier.ROLLING
    p.linear_damp = 6.0                   # pushed props coast ~0.3 s then stop
    p.angular_damp = 3.0
    p.mass = float(cfg.get("mass", 8.0))
    p.can_sleep = true                    # PERF: sleeping rigid ≈ free
    match int(cfg.get("tier", Tier.PUSHABLE)):
        Tier.SOLID:
            p.freeze = true               # static collider with prop art (audit G fix)
        Tier.ROLLING:
            p.linear_damp = 1.2           # logs coast — momentum is the mechanic
        Tier.EXPLOSIVE:
            p.set_meta("explosive", cfg.get("blast", {"radius": 90.0, "damage": 120.0}))
    if bool(cfg.get("flammable", false)):
        FireManager.register_fuel(p, float(cfg.get("burn_s", 6.0)))
    # sprite/shape from cfg (art idiom identical to zone_builder._sprite; y-sorted)
    return p

func take_damage(amount: float, source: Node) -> void:
    ## Props are in the damage funnel: crates break (loot), barrels detonate (§10.5),
    ## fuel ignites from fire-school hits ("fire": true in the ability payload).
    hp -= amount
    if has_meta("explosive") and (hp <= 0.0 or _last_hit_was_fire):
        FireManager.detonate(self)
    elif hp <= 0.0:
        _break_apart(source)              # VFX.smoke + loot roll + queue_free
```

**Tiers & the prop mass table** (feel targets: crate shoves like Link's, cart is a lean):

| Tier | Props | Mass | Behavior |
|---|---|---|---|
| SOLID | building footprints, statues, wells, anvils | frozen | collider + art; fixes audit G |
| PUSHABLE | crates, barrels, sacks, coffins, debt-tablets | 6–14 | shove ~1 tile per bump, high damp |
| ROLLING | logs, ale kegs (side-on), boulders | 30–45 | coast with momentum, damage on impact ≥ 120 px/s (`mass × speed` scaled), knock actors |
| EXPLOSIVE | forge-barrels, powder kegs, ash-vent casks | 12 | detonate on fire/break: blast radius, chain to other explosives, big knockback |
| BURNABLE_STATIC | hay bales, thatch, grass patches, thread filaments, oil pools | — | FireManager fuel cells (§9); static until burned, leave scorch decal |

**Authoring**: zone defs gain `"physics_props": [{type, pos, tier?, ...}]` rows; builders
also *upgrade in place* — existing static crate/barrel/cart art in TownBuilder/
WildernessBuilder camps (`szadi_prop_08/09/10` etc.) is respawned as `InteractiveProp`
by a shared lookup table `PROP_DEFS = {"crate": {...}, "barrel": {...}}` so the whole
shipped world becomes interactive in one pass, no per-zone edits.

## 8. PhysicsLayer plan

Name the layers in `project.godot` (`layer_names/2d_physics/layer_*`) — today only raw
bits are used (audit of `collision_layer` sites in Grounded-in header):

| # | Bit | Name | Who's on it today/planned |
|---|---|---|---|
| 1 | 1 | `world` | static colliders: border trees, buildings, gates (unchanged) |
| 2 | 2 | `player` | player (unchanged, `player.gd:233`) |
| 3 | 4 | `npc` | NPCs (unchanged, `npc.gd:345`) |
| 4 | 8 | `enemy` | enemies (unchanged, `enemy.gd:98`); scarecrow keeps `1|8` |
| 5 | 16 | `prop` | InteractiveProp all tiers |
| 6 | 32 | `projectile` | Combat.Projectile (today layer 0 / mask 1 — gains `|16` mask so bolts hit barrels) |
| 7 | 64 | `hazard` | fire cells, ice patches, blast zones (Area2D, monitor-only) |
| 8 | 128 | `water` | river/canal ribbons (Area2D, §6.4) |

**Mask updates** (the entire integration diff):
- `player.collision_mask = 1 | 16` — collides with world + props.
- `enemy.collision_mask = 1 | 16` — mobs path around/into props (shoving a crate line
  into a wolf lane is legal tower defense).
- `Projectile.collision_mask = 1 | 16`.
- Hazard/water Area2Ds monitor layers `2|4|8|16` (actors + props: logs can slide on ice,
  fire ignites props).

### 8.2 Player/enemy pushing (CharacterBody2D → RigidBody2D coupling)
`move_and_slide` doesn't push rigid bodies; add the standard impulse pass to
`player.gd` (and `enemy.gd` — mobs barge through crates, heavier ones shove harder):

```gdscript
# after move_and_slide(), in _physics_process:
for i in range(get_slide_collision_count()):
    var col := get_slide_collision(i)
    var body := col.get_collider() as RigidBody2D
    if body != null and not body.freeze:
        var push: float = 22.0 * clampf(8.0 / body.mass, 0.1, 1.0)   # mass-scaled
        body.apply_central_impulse(-col.get_normal() * push)
```

Feel target: an 8-mass crate moves at ~0.6× walk speed while pushed; a 120-mass cart
needs the deliberate cart-push interaction (§10.7) — bumping barely rocks it.

## 9. Fire propagation (torch → hay → grass, weather-honest)

`FireManager` autoload, cell-based (no per-blade physics):

```gdscript
## scripts/fire_manager.gd (autoload). Fuel = registered cells (BURNABLE_STATIC props,
## grass patches from zone defs, flammable InteractiveProps). Grid keyed by pos/32.
## ignite(pos, source): starts a burning cell if fuel exists there and weather allows.
## Tick (0.5 s): each burning cell rolls spread to fuel cells within SPREAD_PX,
## biased by wind; burns burn_s then dies -> scorch decal + fuel consumed until rebuild.

const SPREAD_PX := 52.0
const TICK := 0.5
const MAX_BURNING := 64            # perf cap: oldest cells snuff first past this

func _spread_chance(dir_to_target: Vector2) -> float:
    var w: WeatherController = get_tree().get_first_node_in_group("weather")
    var base := 0.35
    if w != null:
        match w.current_type():
            WeatherController.Type.RAIN:  base *= (1.0 - 0.8 * w.intensity())
            WeatherController.Type.STORM: base *= (1.0 - 0.9 * w.intensity())
            WeatherController.Type.SNOW:  base *= 0.25
            WeatherController.Type.ASH:   base *= 1.3       # Ashvents canon: embers
        # Wind bias: downwind spread up to 2.2x, upwind down to 0.3x.
        var wind_v := Vector2(w.wind(), 0.0)                # wind() = public _wind getter
        base *= clampf(1.0 + 1.2 * dir_to_target.normalized().dot(wind_v), 0.3, 2.2)
    return base

## Rain EXTINGUISHES live fires: each tick, burning cells roll
## 0.15 * intensity (rain) / 0.3 * intensity (storm) to snuff out early.
```

- **Burning cell** = flame sprite (existing `FIRE_FRAMES` atlas anim) + hazard Area2D
  (layer 64) dealing `6 + zone_bracket` damage/s to actors inside + **light budget**:
  only the 8 cells nearest the camera get a `PointLight2D` (shadows off), rest are
  sprite-only (perf, §11).
- **Ignition sources**: torch-carry item (equip: off-hand torch, lights the way — dark
  zones reward it), fire-school abilities (payload `"fire": true`), campfires (standing
  landmark fires ignite adjacent fuel — camps are dangerous neighbors by design),
  lightning strikes in STORM (the `_strike()` hook picks a random on-screen fuel cell,
  0.3 chance — rain usually wins the race, ASH storms don't rain).
- **Enemies/players catch fire**: 2 s in a burning cell applies Burning (STATUS_EFFECTS
  DoT, 4 %/s, 4 s); mobs on fire panic-run 1.5× speed in a random-walk (spreading it —
  emergent, capped by MAX_BURNING).
- **Canon**: Thread filaments burn **cold blue**, spread only along the filament line
  (their own fuel chain, wind-immune — the Thread doesn't care about weather), and
  never damage — burning Thread *reveals* (§12.1). Warm-ground patches ignite fuel on
  contact at 0.05/tick — the land itself is a slow arsonist where the signal runs.

## 10. The remaining physics systems

### 10.1 Ice patches (slide)
Authored `{"type": "ice", "pos", "radius"}` hazard rows (tundra/ridge zones; also a
STORM/SNOW overnight effect on ponds — pond landmarks freeze while SNOW intensity > 0.6).
Area2D (layer 64) sets `_surface_friction = 0.08` on actors inside (default 1.0):

```gdscript
# player.gd movement: velocity chases input instead of snapping to it.
var target := input_dir * speed * _speed_mult
velocity = velocity.lerp(target, clampf(_surface_friction * 14.0 * delta, 0.0, 1.0))
```

Enemies use the same field — kite bone-hounds onto a frozen pond and their lunges skate
past you (charge §5.3 on ice = comedy + tactics). ROLLING props on ice: damp ×0.15
(logs glide the whole pond).

### 10.2 Wind gusts on projectiles (storms)
`Combat.Projectile._physics_process` gains drift when weather is STORM (both factions —
fair symmetry; listeners' bolts in the Whisper Passes miss too):

```gdscript
var w := Engine.get_main_loop().root.get_tree().get_first_node_in_group("weather")
if w != null and w.current_type() == WeatherController.Type.STORM:
    velocity.x += w.wind() * 90.0 * w.intensity() * delta * 60.0 * 0.016  # px/s^2 drift
```

Plus **gust events**: in STORM, every 6–14 s the WeatherController emits
`gust(strength)` — a 0.8 s impulse that shoves PUSHABLE props ≤ 14 mass 20–40 px
downwind, flutters banners harder, and adds ±25 % to the projectile drift. The world
visibly leans when the sky does.

### 10.3 Knockback (composes with COMBAT_PACING §5.1/§5.3)
One shared funnel in `combat.gd` — replaces enemy.gd's raw `KNOCKBACK_PX` nudge:

```gdscript
## Combat.knockback(target, from_pos, px, dur=0.18): CharacterBody2D gets a decaying
## _knockback velocity component (added to move vectors, tween to zero over dur);
## RigidBody2D gets apply_central_impulse(dir * px * mass_ref). Mass-scaled:
## effective_px = px * clampf(90.0 / target_mass_or_90, 0.4, 1.5). Knocked actors
## crossing burning cells ignite; hitting a prop transfers half the impulse to it.
```

| Hit | Knockback | Source hook |
|---|---|---|
| player basic hits | 6 px (current feel, kept) | `deal_damage` default |
| player **crit** / burst finishers | 26 px | crit branch `player.gd:1242` |
| Sunder-class guard-breakers | 0 (they stagger, not shove — guard-break is the payoff) | COMBAT_PACING §5.5 |
| enemy **heavy swing** (every 3rd, 1.6×) | 40 px on player | §5.1 heavy branch |
| **charger** connect | 70 px + the existing 50 % slow | §5.3 |
| elite **signature** AoE | 90 px radial from decal center | §5.7 |
| explosion (§10.5) | 140 px radial, falls off with distance | FireManager.detonate |

Player knockback respects walls (it's velocity, `move_and_slide` resolves) — being
knocked into your own crate line, off ice, or into a canal (§6.4 wading = combat
positioning) all just work because everything shares the funnel.

### 10.4 Rolling logs
ROLLING props: pushing gives momentum (low damp); impacts ≥ 120 px/s deal
`0.4 * mass * speed/100` damage + knockback along travel direction to layer 2/4 bodies,
then lose 60 % speed. Authored **log ramps** (slope decals) auto-shove ROLLING props
downslope on entry — the Zelda boulder-corridor, used in §12.4/§12.13.

### 10.5 Explosive forge-barrels (chain reactions)
`FireManager.detonate(prop)`: `VFX` flash + smoke, blast Area2D one frame
(radius 90, damage 120 scaled to zone bracket ×`(1 + level/12)`), 140 px radial
knockback, ignites all fuel in radius, and **queues detonation of other EXPLOSIVE props
in radius at 0.25 s intervals** (the chain is watchable, not simultaneous — Zelda law:
readable causality). Chains are capped at 8 per second (perf + comedy pacing).
Forge-barrels also cook off after 3 s of standing in fire (fuse hiss + blink white).

### 10.6 Fishing bobbers
Yes — cheap and it sells water as *matter*: fishing (future Draconia profession hook)
casts a 0.2-mass bobber: not a RigidBody, a `Node2D` with a bob tween (sine + noise)
clamped to the water Area2D. On bite: 3 sharp dips (0.2 s) then the catch window
(0.8 s, `[E]`). In the Iron Vein the ripples ring **copper-dark** (river canon); in
Greyhollow canals a "catch" is sometimes a debt-tablet (§12.11). Zero physics cost.

### 10.7 Cart-pushing
Carts (mass 120) are PUSHABLE but bump-immune (§8.2 math). Interacting (`[E] Push cart`)
enters **cart-mode**: player locks to the handle anchor, walk speed ×0.55, cart becomes
kinematic-follow of the player along its facing axis (steering ±30°/s). Release on `[E]`
/ damage taken. Used by escort/delivery quests, the ore-cart interaction (§12.13), and
the debt-ledger cart (§12.2). Enemies attack the cart (it has hp) — escort pressure
without escort-AI pathing pain.

## 11. Performance budget (CPU-bound project — frozen numbers)

| System | Budget | Enforcement |
|---|---|---|
| Active (awake) RigidBody2D | ≤ 40/zone visible-set | `can_sleep = true`, damp 6.0 sleeps pushed props in <1 s; props beyond 1,200 px of player are `freeze = true` (existing proximity-spawn culling pattern) |
| Physics frame | ≤ 1.5 ms | `Performance.TIME_PHYSICS_PROCESS` assert in `tests/profile_run.py` scene with 40 props + 3 detonations |
| Burning cells | ≤ 64 (`MAX_BURNING`) | oldest-snuff; spread rolls stop at cap |
| Fire lights | ≤ 8 PointLight2D (no shadows) | nearest-to-camera; rest sprite-only |
| Fire tick | 0.5 s, O(burning × fuel-in-radius) via grid buckets | cell grid keyed `pos/32`, neighbor lookup only |
| Detonations | ≤ 8/s chain-queue | FireManager queue |
| Hazard Area2Ds | pooled, ≤ 24 live | fire cells share one pooled set |
| Water/ice areas | static, built once per zone | no per-frame cost beyond overlap events |

Zero cost when idle: a zone with no player interaction runs 0 awake bodies, 0 burning
cells — identical to today's frame.

## 12. Fifteen designed interactions (canon-flavored)

1. **Burning a Thread-filament** *(Threadlands)* — touch a torch to a blue filament:
   cold-blue fire crawls the filament line (wind-immune, §9 canon), and every
   thread-shell the line fed collapses mid-stride as it passes. No loot. The fire dies
   at a buried junction and the ground there goes **warm** — you didn't cut the Thread,
   you told it where you are. (Quest hook: HIDDEN_DEBUFFS "Marked" applies.)
2. **The debt-ledger cart into the canal** *(Greyhollow)* — cart-mode a collection cart
   off the pier edge: splash, tablets sink, the ledger line reads *un-stamped*.
   Collection-agents within earshot aggro (skull-con); every *finalized* in the block
   stops walking for sixty seconds — nobody holds their account. One surfaces a day
   later, warm (§12.11 fishes it up).
3. **Forge-barrel chain on the Killing Floors** *(Sangeroasa)* — the arsenal's powder
   kegs line the blood channels. One fire arrow: 8-barrel chain down the row, 140 px
   knockback bowling slag-walkers into the channels. All hammers stop for a count of
   three (canon vignette) — then the pit-bosses come.
4. **Log-ford the Iron Vein** *(Iron Vein)* — shove a bog log (ROLLING) down the bank
   ramp into the shallows: it lodges at the ford line and becomes a walk-fast crossing
   (water-slow suppressed on its cells). The river takes it back on zone rebuild —
   crossings you make are yours for the visit, not forever.
5. **Frozen-pond kiting** *(Gravemark Tundra)* — constant SNOW freezes ponds (§10.1);
   bone-hound lunges skate past you at 0.08 friction. The Marches Alpha's charge on ice
   carries him clean off the far bank — dodge-rewarded like COMBAT_PACING §5.3 wants.
6. **Hay-wall against the charge** *(Western Lowlands)* — torch the hay line as bandit
   duelists close: a burning fence they path around, funneling them through your AoE.
   If it's RAINING, the hay sputters out and you learn to check the sky first —
   weather is a combat stat.
7. **Collapse the digging-tunnel** *(Copper Wells)* — push the boundary-stone (mass 45,
   ROLLING) into the Digging Creature's tunnel mouth: its rare night-spawn surfaces at
   the *other* mound, furious (enrage pre-applied) but predictable — you chose the arena.
8. **Storm archery** *(Whisper Passes)* — in STORM, your arrows and the listeners' bolts
   both bow downwind (§10.2). The watch-posts were built assuming still air; attack in
   weather and their kill-zone geometry is wrong. Sound carries strangely — aggro radii
   +30 % in this zone, canon.
9. **Ashvent cook-off** *(the Ashvents)* — grass self-ignites near live vents (warm-
   ground arson, §9); carrying the quest cask of lamp-oil through the vent field means
   pathing cold ground, reading the land like the canon demands. Drop it in a hot patch:
   3 s hiss, then §10.5. The heat hides the signal here — and everything else.
10. **Boar into the dolmen** *(Iron Vein)* — sidestep the charge so it connects with a
    SOLID standing stone: self-knockback + 1.2 s stun (charge-miss vulnerability §5.3,
    doubled). The stone doesn't notice. Teaching moment: the world is a weapon.
11. **Fishing the ledger route** *(Greyhollow canals)* — bobber dips copper-dark; the
    catch table includes moor-eels, boots, and (0.5 %) a **warm debt-tablet** — a
    RUNEWORDS-adjacent curiosity that Records will pay for, or that the Morven will
    notice you holding. The river tastes of coins (canon).
12. **Barrel splash lure** *(the Grey Piers)* — shove pier barrels into black water:
    canal-things converge on the splash point for 20 s. Cross the drowned quarter behind
    the noise. Emergent stealth from three systems (push + water + aggro), zero new code.
13. **Ore-cart brake-out** *(Sangeroasa, the Debt Pit rim)* — a loaded ore-cart on the
    ramp holds a wedge-crate (PUSHABLE). Kick the wedge: the cart (ROLLING, mass 120)
    runs the rail down the spiral, scattering forge-thralls (impact knockback), and
    breaches the tally-master's toll gate at the bottom — the freight route into the
    Pit that doesn't involve the ledger. The ledger notices anyway.
14. **The full granary burns** *(Famine Fields)* — the canon vignette (a famine village
    with a FULL granary) becomes a choice: torch it and wind-driven fire eats the cult's
    grain — the Cult Zealot camp starves out (respawns halved for the visit), but so do
    the villagers' rations you could have quest-delivered. Heavy-cheerful, Witcher-law:
    both outcomes are somebody's bad winter.
15. **Lamp-oil alleys** *(Blestem)* — the maze-city's oil sellers stack casks in the
    Riddler's Quarter. Split one (BURNABLE oil pool) and lay a line back the way you
    came: when the corridor "reorders" behind you (dungeon canon), the burning line
    still marks *your* path through the disorientation-engine — fire is the one thing
    the maze can't shuffle. Strigoi enforcers won't cross it; the walled will.

## 13. Rollout order + QA gates (Engineering Law)

1. **§8 layers + §7 InteractiveProp + §8.2 push pass** — world's existing crates/barrels
   go live (PROP_DEFS upgrade table). *Gate:* headless — spawn crate, apply player-walk
   impulses 1 s, assert moved > 24 px and asleep < 1.5 s later; 40-prop physics frame
   ≤ 1.5 ms.
2. **§3 seams v2 + §3.2/§5 validators + §6.4 water** — freedom laws live. *Gate:*
   world-graph BFS green; walk-through seam screenshot QA; wade-speed assert.
3. **§10.3 knockback funnel** (ships beside COMBAT_PACING §5.1 heavy swings — same
   branch). *Gate:* heavy-swing knocks player 40±5 px; knock-into-fire ignites.
4. **§9 FireManager + BURNABLE props + weather coupling.** *Gate:* headless — ignite hay
   in CLEAR, assert 3-cell spread; same seed in RAIN 1.0, assert extinguished ≤ 4 ticks;
   wind 1.0 assert downwind-only spread; MAX_BURNING cap holds at 64.
5. **§10.5 explosives + §10.4 rolling + §10.1 ice + §10.2 wind-drift.** *Gate:* 3-barrel
   chain detonates at 0.25 s spacing; projectile drift px within ±10 % of formula.
6. **§10.7 carts + §10.6 bobbers + §4 con colors + §6 systems (guards, flee, corpse-run,
   mount-outdoors).** *Gate:* the **Pilgrimage Probe** (§6.6) — a level-1 reaches
   Sangeroasa's gate. That green check is the mandate, proven.

Every interaction in §12 that ships gets one line in the zone's vignette QA screenshot
set (fire visible, prop displaced) — same batch discipline as WORLD_PLAN builds.
