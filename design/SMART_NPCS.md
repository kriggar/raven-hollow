# RAVEN HOLLOW — SMART NPCs & LIVING CAPITALS
Design doc for the town-that-breathes layer: daily schedules, vendors with real
shops, reputation-priced haggling, a contextual reaction (bark) system, the
Angel Wings density plan, schedule-driven crowd flow, and the event behaviors
(storm shelter, festivals, funeral vigils) that make it read as *smart*.

**Grounded in (read before writing):**
- `scripts/npc.gd` — `NPC.create(def)` code-built villagers; def keys `id, display_name,
  sheet, variant, pos, wander_radius, dialogue, facing, palette`; `WALK_SPEED 40`,
  idle/walk wander loop with per-leg time cap; `_tick_bark()` → `Voice.bark(self, _id,
  VoiceRegistry.bark_line(_id, salt))` on a 24–44 s cooldown inside `BARK_RANGE 78`;
  `interact()` quest-first dialogue; `_apply_night()` pulls wanderers home at
  `night_changed` (radius × 0.25); escort-lite `set_follow_target()`; lazy `_hook_systems()`
  polling for the `quests` / `day_night` groups; collision layer 3, mask 1 (walls only),
  `MOTION_MODE_FLOATING`, no navigation.
- `scripts/npc_data.gd` — static cast of 10; `pos`/`wander_radius` filled by `main.gd`
  from the builder's `npc_spawns`; the unique-villager contract (named cast = no palette;
  taken combos: female1:0, male2:1, male3:2, male4:0, male2:3, female2:1, male1:2,
  male4:1, female1:2, MAID, player-reserved male1:0).
- `scripts/main.gd` — `_post_build_map()` calls `_spawn_npc_cast(world, built.npc_spawns)`;
  roles without a spawn silently skipped; quest rewards write `player.gold` directly;
  singletons are Main children discovered by group (`day_night`, `weather`, `quests`).
- `scripts/day_night.gd` — 24 h in 600 s real (1 game-hour = 25 s); `time_of_day` float,
  `is_night` = 19:30→5:30, `night_changed(bool)`, `set_time()`, `clock_text()`,
  save via `get_save_data()/apply_save_data()`. **No day counter exists yet** (§2.6).
- `scripts/weather.gd` — `Type {CLEAR, RAIN, STORM, SNOW, FOG, ASH}`,
  `signal weather_changed(type)`, per-map/biome tables, group `"weather"`.
- `scripts/items.gd` + `design/ITEM_PROGRESSION.md` — item dict shape; §7 vendor math
  (`value` = sell gold, buy = 4×); §6 vendor rules (poor tools + common gear + one
  rotating uncommon "stock special" per capital; consumables/recipes are the gold sinks).
- `scripts/inventory.gd` — `add_item()`, `free_slots()`, `bag_changed`; `BAG_SIZE 20`;
  `DragCtx` shared drag state.
- `scripts/bag_ui.gd` — the ornate-kit constants this doc's VendorUI must reuse:
  `GOLD (0.85,0.68,0.35)`, `BOX_BG`, `SLOT 24`, `GAP 3`, `PAD 12`, `GRID_TOP 27`,
  `panel_brown.png` 9-patch, Alagard 8/16, `ItemTooltip`, `DRAG_LAYER 15`.
- `scripts/voice_registry.gd` / `voice_client.gd` — `VOICES[npc_id] -> {speaker,pitch}`;
  baked-clip hash = `speaker + text` (pitch excluded); `Voice.bark(npc, npc_id, text)`
  with per-instance client cooldown; `bark_line(npc_id, salt)` deterministic pick.
- `scripts/quests.gd` — signals `quest_started/updated/completed`, `rewards_granted`,
  `cinematic_beat`; `set_flag()/_flags`; `serialize()/deserialize()` save contract.
- `scripts/save_system.gd` — opaque per-system `serialize()/deserialize()` pattern
  (quests/recipes/weather precedent); items ride as dicts.
- `design/COMBAT_PACING.md` — Angel Wings outskirts = bracket 11–14, city-edge duelists,
  light density *outside*; the capital interior is a safe hub (this doc's stage).
- `WORLD_PLAN.md` — z7 **Angel Wings** (CAPITAL — MASSIVE): the Lead Vault, Maren's
  Orphanage (chalk handprints wall), river docks, grain markets, thatch sprawl.

**Design laws inherited:** everything is code-built (no scenes); systems are Main-child
singleton nodes found by group and duck-typed (`get_first_node_in_group` + `call`),
never hard preloads across systems; def dicts carry extension keys that core code
ignores (the `crafting.gd` layering precedent); gold economy per ITEM_PROGRESSION §7
is law — nothing here may mint gold faster than the ~25–40 g/hr clear-and-vendor loop.

---

## 0. THE PITCH IN ONE PARAGRAPH

Raven Hollow's villagers already wander, bark, quest, and go home at night. This
layer gives them **somewhere to be** (schedules against the DayNight clock),
**something to sell** (typed vendor stock on the bag kit, priced by reputation),
**something to say about *you* and *today*** (contextual barks through the existing
TTS pipeline), and **the sense to react to the world** (shelter from storms, gather
for festivals, stand vigil for the dead). One new director node per concern, four
def-dict extension keys, and the NPC class itself grows by ~80 lines. Angel Wings
ships first as the proof: 19 souls whose days visibly interlock.

Architecture in one line: **NPCs stay dumb, directors get smart.** `npc.gd` gains
only a movement primitive (`travel_route`) and an anchor setter; every decision
about *where/when/what to say* lives in three Main-child directors (Schedule,
Vendors, Reactions) plus one event coordinator (TownEvents), all following the
DayNight/WeatherController singleton pattern.

```
Main
 ├─ DayNight            (shipped)           group "day_night"
 ├─ Weather             (shipped)           group "weather"
 ├─ Quests              (shipped)           group "quests"
 ├─ ScheduleDirector    (NEW, §2)           group "npc_schedule"
 ├─ Vendors             (NEW, §3)           group "vendors"     ← owns Reputation (§4)
 ├─ ReactionDirector    (NEW, §5)           group "npc_reactions"
 └─ TownEvents          (NEW, §8)           group "town_events"
World
 └─ NPC ×N              (extended, §1)      group "npcs"
CanvasLayer(9)
 └─ VendorUI            (NEW, §3.4)         group "vendor_ui"
```

---

## 1. NPC CLASS EXTENSIONS (npc.gd — the only touched shipped file)

The NPC stays a dumb actor. It gains three public primitives and two def keys,
and its two existing "brains" (`_tick_bark`, `_apply_night`) each learn to defer
to a director *when one exists* — with the shipped behavior as the no-director
fallback, so the demo town keeps working with zero data authored.

### 1.1 New def extension keys (read by directors, ignored by NPC.create)

```gdscript
# npc def, after "facing" — all optional, core NPC ignores them entirely:
"schedule": [                       # §2 — daily anchor blocks, hours 0..24
    {"h": 7.0,  "at": "aw_forge",        "r": 14.0},
    {"h": 12.5, "at": "aw_market_sq",    "r": 24.0},
    {"h": 19.0, "at": "aw_taproom",      "r": 10.0},
    {"h": 23.0, "at": "aw_home_row3",    "r": 0.0, "indoor": true},
],
"patrol": ["aw_gate_w", "aw_market_sq", "aw_docks", "aw_gate_w"],  # §6 guards —
                                    # loops anchor-to-anchor forever; overrides
                                    # "schedule" while set (guards keep watch in rain)
"vendor": "weaponsmith",            # §3 — Vendors stock-table id ("" / absent = none)
"react_tags": ["dockhand", "pious"] # §5 — extra bark-pool tags beyond the auto ones
```

### 1.2 New members + API

```gdscript
# --- npc.gd additions -------------------------------------------------------
var _route: Array[Vector2] = []       # waypoint queue; empty = wander mode
var _hidden: bool = false             # "indoors" (§1.4)
var _player_cache: Node2D = null      # replaces the 3 per-frame group lookups

## ScheduleDirector's single lever: re-home the NPC. The wander loop is untouched —
## it just orbits a new _home. travel==true walks there via `route` (road-following
## waypoints, §2.3); false teleports (used only on map build / load / big time skips).
func apply_anchor(pos: Vector2, radius: float, route: PackedVector2Array,
        travel: bool = true) -> void:
    _home = pos
    _base_wander_radius = radius
    _wander_radius = radius
    if not travel:
        global_position = pos
        _route.clear()
        return
    _route.assign(Array(route))       # last element == pos
    _walking = false                  # next _physics_process pops the route

## Indoors: invisible, intangible, un-interactable — but still ticking its
## schedule. Buildings are painted façades with no interiors (town_builder law),
## so "inside" == removed from the street at the door anchor.
func set_hidden(hide: bool) -> void:
    _hidden = hide
    visible = not hide
    _sprite.visible = not hide        # belt & braces vs. y-sort quirks
    set_collision_layer_value(3, not hide)
    _name_label.visible = false
    if _marker_label != null:         # quest ! / ? suppressed while inside
        _marker_label.visible = not hide and _marker_label.text != ""

func is_hidden() -> bool:
    return _hidden
```

### 1.3 Route-following (extends the existing walk loop, ~20 lines)

In `_physics_process`, before the wander branch:

```gdscript
if not _route.is_empty():
    if not _walking:
        _target = _route[0]
        _walk_time_left = (_target - global_position).length() / WALK_SPEED * 2.0 + 1.0
        _walking = true
    # ...existing walk step runs unchanged; in _stop_walking():
    #   if not _route.is_empty(): _route.pop_front()   # arrive → next leg
    #   (only fall into the idle timer when the route is exhausted)
```

The per-leg `* 2.0 + 1.0` time cap is kept verbatim — it is the shipped
anti-wall-stall safety, and it means a blocked NPC *skips* to the next leg
instead of walking in place. Routes are authored along roads (§2.3) so this
fires rarely, and the failure mode is invisible (NPC cuts a corner).

**Interaction rules while routed:** `interact()` already zeroes velocity and
sets `_talking`; a routed NPC pauses mid-route to chat and resumes (route queue
survives `_talking`). Escort (`_follow_target`) outranks routes — the existing
early-return order becomes: talking > follow > route > wander.

### 1.4 Existing-brain deferrals

- `_apply_night()` (shipped night pull-home): becomes the **fallback** — it
  no-ops when `ScheduleDirector` has a schedule for this `_id` (checked via the
  `npc_schedule` group, duck-typed `has_schedule(_id)`). NPCs with no schedule
  (demo town cast until Phase S1 data lands, one-off zone NPCs) keep the exact
  shipped behavior.
- `_tick_bark()`: line selection swaps from `vr.bark_line(_id, salt)` to
  `ReactionDirector.line_for(_id, salt)` when the `npc_reactions` group is
  non-empty; else the shipped VoiceRegistry path. The 24–44 s cooldown, the
  78 px range, and `Voice.bark()` are untouched — reactions ride the exact
  shipped audio pipeline.
- `_update_name_tag()` / `_tick_bark()` player lookup: cache
  `get_first_node_in_group("player")` in `_player_cache`, refresh only when
  invalid. With 19 NPCs in Angel Wings the shipped 3-lookups-per-NPC-per-frame
  pattern is measurable; the cache makes NPC count a non-cost.

---

## 2. DAILY SCHEDULES (ScheduleDirector)

### 2.1 The clock we schedule against

DayNight runs 24 h in 10 real minutes → **1 game-hour = 25 real seconds**. A
four-block day (home → work → square/tavern → home) means an NPC visibly
relocates every ~2–4 real minutes: fast enough that a player standing in the
market *sees* the town change, slow enough that each tableau reads.

Canonical civilian day (per-NPC hours jittered ±0.4 h by `hash(id)` so the
street never moves in lockstep — same trick as the shipped wander stagger):

| Block | Hours | Where | Notes |
|---|---|---|---|
| Sleep | 22:30–6:30 | home anchor, `indoor: true` | hidden (§1.4); street empties |
| Work | 6:30–12:30 | stall / forge / docks | vendors **open** (§3.6) |
| Midday | 12:30–14:00 | market square / well | the daily crowd peak — the postcard hour |
| Work | 14:00–19:00 | back to stall | second vendor window |
| Evening | 19:00–22:30 | taproom / square benches | dovetails with the shipped `is_night` 19:30 flip |
| — | any | weather/event overrides | §8 outranks all of the above |

Guards (§6) and the innkeeper run counter-schedules (night shifts) so the town
is never fully dead — a WoW-Classic capital reads alive at 3 a.m. because
*someone* is walking a beat.

### 2.2 ScheduleDirector API

```gdscript
class_name ScheduleDirector
extends Node
## Main-child singleton (group "npc_schedule"), DayNight-pattern. Owns every
## NPC's daily anchor. Ticks at 1 Hz (Timer), not per-frame — schedules are
## coarse. Holds the anchor/route tables the map builder hands over per map.

signal block_changed(npc_id: String, anchor_id: String)  # ReactionDirector + debug

const TICK_S := 1.0
const JITTER_H := 0.4          # per-npc block-start jitter, seeded by hash(id)

var _anchors: Dictionary = {}  # anchor_id -> {pos: Vector2, indoor: bool}
var _routes: Dictionary = {}   # "a>b" -> PackedVector2Array (§2.3)
var _schedules: Dictionary = {} # npc_id -> Array[block]  (from def "schedule")
var _patrols: Dictionary = {}   # npc_id -> Array[String] (from def "patrol")
var _overrides: Dictionary = {} # npc_id -> {anchor_id, radius, until_h} (§8)
var _current: Dictionary = {}   # npc_id -> anchor_id (dedup: only act on change)

## main.gd _post_build_map(): hand over the builder tables + register the cast.
func on_map_built(anchors: Dictionary, routes: Dictionary) -> void
func register(npc_id: String, def: Dictionary) -> void   # reads schedule/patrol keys
func has_schedule(npc_id: String) -> bool                 # npc.gd night-fallback gate

## §8 TownEvents lever: pin npc(s) to an anchor until game-hour `until_h`
## (wrap-aware). priority: "storm" < "festival" < "vigil" — a higher class
## replaces a lower, never vice versa. Pass npc_id == "*" for everyone-with-
## a-schedule. clear_override restores the timetable next tick.
func push_override(npc_id: String, anchor_id: String, radius: float,
        until_h: float, priority: String) -> void
func clear_override(npc_id: String, priority: String) -> void

## Where is (or should be) this NPC now — Quests/debug can ask.
func current_anchor(npc_id: String) -> String

func serialize() -> Dictionary      # {_overrides} only — blocks derive from time
func deserialize(d: Dictionary) -> void
```

Tick logic (the whole brain, ~40 lines): for each registered NPC, resolve the
active block for `DayNight.time_of_day` (wrap-around scan, same shape as
`DayNight._segment`), apply the override layer, and if the resolved anchor
differs from `_current[id]`, look the NPC up in group `"npcs"` by node name
(== `_id`, guaranteed by `NPC.create`) and call
`apply_anchor(pos, radius, route_between(current, next))`, then
`set_hidden(anchor.indoor)` **on arrival** (the director watches distance-to-home
< 12 px on subsequent ticks before hiding — NPCs walk *to* the door, never
vanish mid-street). On `quest marker != ""` the hide is skipped: an NPC with a
`!`/`?` stays outside their door so quests are never soft-locked by a timetable
(WoW rule: quest givers keep shop hours, quest *access* doesn't).

**Map transitions:** NPCs are freed with the World (shipped behavior); on
rebuild, `register()` re-runs and the first tick calls
`apply_anchor(..., travel=false)` — everyone *starts* where the clock says they
should be, not at their def spawn. This is the detail that sells persistence:
leave at noon, return at midnight, the market is empty and the taproom glows.

### 2.3 Anchors & routes (builder contract)

`town_builder.gd` / `zone_builder.gd` gain two output tables next to the
existing `npc_spawns`:

```gdscript
built["npc_anchors"] = {   # anchor_id -> world-space point + indoor flag
    "aw_market_sq": {"pos": Vector2(1210, 780), "indoor": false},
    "aw_forge":     {"pos": Vector2(980, 640),  "indoor": false},
    "aw_home_row3": {"pos": Vector2(1493, 512), "indoor": true},   # a door
    ...
}
built["npc_routes"] = {    # directed "from>to" -> road-following waypoints
    "aw_forge>aw_market_sq": PackedVector2Array([...]),
    ...
}
```

Routes are **hand-authored polylines along the roads** (the town revamp shipped
a real road network; anchors sit on it). No navmesh, no avoidance — NPC
collision only masks walls (layer-1), NPCs pass through each other and the
player by design (shipped contract, keep it: 20 bodies avoiding each other in
alleys is a jitter farm). Missing route lookup falls back to reversed `"b>a"`,
then to a straight 1-point route (the leg time-cap absorbs the risk). Rule of
thumb: a capital needs anchors ≈ NPCs and routes ≈ 1.5× anchors, because most
routes chain through 1–2 hub anchors (everything routes via the market square).

---

## 3. VENDOR SYSTEM (Vendors + VendorUI)

### 3.1 Vendor types & stock tables

A vendor def key (`"vendor": "weaponsmith"`) binds an NPC to a stock table.
Tables live in `Vendors.STOCK_TABLES`, item ids reference `items.gd` (with the
ITEM_PROGRESSION `value` annotations as the price source of truth):

| Vendor type | Stocks (per ITEM_PROGRESSION §6: poor tools + common gear only) | Angel Wings holder |
|---|---|---|
| `weaponsmith` | common main_hand ×3 brackets, whetstone (poor tool) | Smith Codrina |
| `armorer` | common chest/head/legs/boots spread | Armorer Bogdan |
| `general` | poor tools (rope, torch, shovel), bag fillers, trade junk | Chandler Ilse |
| `alchemist` | consumables: minor/lesser healing + mana draughts (the gold sink) | Herbalist Sorina |
| `provisioner` | food/drink consumables, cheapest sink, tavern flavor | Innkeep Radu |
| `leatherworker` | common boots/legs + crafting reagent packs | Tanner Vlad |
| `tradegoods` | crafting mats (thread, salt, lead scrap) + **recipe scrolls** | Dockmaster Neagu |
| `collector` | BUYS anything at value, SELLS nothing — the junk hose | Rag-and-Bone Petrica |

Each table entry: `{"id": "bogiron_cleaver", "count": 3, "restock": 3}` —
`count` = current stock, `restock` = daily refill target. Plus per capital the
rotating **stock special**: exactly one uncommon item, picked from a small
curated pool seeded by `hash(capital_id + str(day_index))`, count 1, no
restock — "come back tomorrow" retention, per ITEM_PROGRESSION's
"+1 uncommon stock special per capital, rotating".

### 3.2 Vendors API

```gdscript
class_name Vendors
extends Node
## Main-child singleton (group "vendors"). Owns stock, prices, reputation (§4),
## restock, and the buy/sell transaction — VendorUI is a dumb view over this.

signal stock_changed(npc_id: String)
signal transaction(npc_id: String, kind: String, item_id: String, gold: int)

const BUY_MULT := 4.0            # ITEM_PROGRESSION §7 law: buy = value * 4
const SELL_MULT := 1.0           # sell = value (the doc's `value` IS sell price)

func is_vendor(npc_id: String) -> bool
func vendor_type(npc_id: String) -> String
func open_hours(npc_id: String) -> Vector2      # (6.5, 19.0) — mirrors schedule
func is_open(npc_id: String) -> bool            # clock + not in a §8 vigil

## Live stock: Array of {item: Dictionary, count: int, price: int} — price is
## final (rep + haggle applied), so the UI never does math.
func stock_for(npc_id: String) -> Array

## Transactions. Both validate gold / bag space / stock and emit on success.
## buy(): player.gold -= price; Inventory.add_item(item.duplicate(true)).
## sell(): any item with value ≥ 1 (equipables AND poor junk — the §7 coin
## engine); collectors take everything, typed vendors take everything too
## (kindness rule: no "wrong shop" sell rejection; WoW got this right).
func buy(npc_id: String, stock_idx: int, player: Node) -> bool
func sell(npc_id: String, bag_idx: int, player: Node) -> bool

func price_buy(item: Dictionary, npc_id: String) -> int
    # ceil(value * BUY_MULT * rep_buy_mult() * haggle_mult(npc_id)), min value+1
func price_sell(item: Dictionary) -> int
    # max(1, floor(value * SELL_MULT * rep_sell_mult()))

func serialize() -> Dictionary   # stock counts, day_index, special ids, haggle state, rep
func deserialize(d: Dictionary) -> void
```

### 3.3 Restock & the day counter

Restock runs at the 06:00 crossing: every entry refills toward `restock`, the
special re-rolls. DayNight has **no day counter** — Vendors derives one by
counting `night_changed(false)` dawn edges into `_day_index: int`
(serialized). This deliberately avoids touching the frozen `day_night.gd`; if
DayNight ever grows `days_elapsed`, Vendors switches to reading it and drops
the local counter (one-line change, noted in code).

### 3.4 VendorUI — the shop on the bag kit

A `CanvasLayer(9)` panel built from the **exact BagUI vocabulary** — same
`panel_brown.png` 9-patch, `GOLD`/`OUTLINE_DARK`/`SLOT_BG` colors, Alagard 8,
24 px slots with 3 px gaps, `ItemTooltip` reuse, `DragCtx` integration:

```
┌─ Alagard title: "SMITH CODRINA — WEAPONSMITH" ──────────┐
│  [stock grid 4×3: icon + count badge + price in gold    │
│   text under-slot, rarity-colored names in tooltip]     │
│  ───────────────────────────────────────────────        │
│  Your gold: 137 g          [ Haggle ]  (§4.2)           │
└──────────────────────────────────────────────────────────┘
   (player's own BagUI auto-opens beside it, shipped panel)
```

- **Buy**: click a stock slot (or drag stock → bag via `DragCtx`, `from_kind:
  "vendor"` — a third value next to the shipped `"bag"`/`"equip"`).
- **Sell**: with VendorUI open, right-click a bag item sells it (BagUI's
  `_on_slot_right_click` gains a `vendor_ui` group check *before* the shipped
  equip/bury branches); tooltip shows the sell line in `GOLD`. Drag bag → stock
  panel also sells.
- **Poor-junk affordance**: while VendorUI is open, poor-rarity bag items get
  a faint gold corner glint — "this is money" (the §7 coin engine made legible).
- Opens from `NPC.interact()`: after the quest-first check returns `{}`, if
  `Vendors.is_vendor(_id) and Vendors.is_open(_id)`, show page 1 of dialogue as
  the greeting, then open VendorUI on dialogue close. If closed for hours/vigil:
  a single bark-page — "Come back when the forge is lit." / "Not today. We are
  burying Anska today." — through the normal dialogue UI, no shop.

### 3.5 Economy guardrails (compose with ITEM_PROGRESSION)

- Buy floor `value + 1` and the mult clamps below guarantee **buy > sell at
  every rep/haggle combination** — no buy-sell arbitrage, ever
  (worst case: buy 3.0×, sell 1.25× — a 2.4× spread).
- Vendors never stock uncommon+ gear beyond the single special — progression
  comes from drops/quests/craft (§6 acquisition mix), gold buys consumables,
  recipes, and later repairs/mounts.
- Stock counts are finite per day (no infinite consumable faucet inside one
  dungeon attempt; a 10-minute day makes "tomorrow" mercifully short anyway).

---

## 4. REPUTATION & HAGGLING

### 4.1 Reputation — one counter per capital, quest-fed

Scope control: **not** a faction matrix. One int per capital (`"raven_hollow"`,
`"angel_wings"`, …), owned by Vendors (it exists to price things; barks read
it too), fed automatically:

```gdscript
# Vendors listens once (lazy hook, npc.gd pattern) to the quests group:
#   rewards_granted(quest_id, rewards) -> rep[current_capital] += REP_QUEST (5)
# plus explicit deed hooks quests can call by flag convention:
#   set_flag("rep_angel_wings_+3", true) — Quests-side one-liner, Vendors polls
#   flags at tick; keeps quests.gd's public surface unchanged.
func rep(capital: String) -> int
func rep_tier(capital: String) -> String   # thresholds 0 / 10 / 25 / 50
```

| Tier | Rep | Buy mult | Sell mult | Feel |
|---|---|---|---|---|
| Outsider | 0–9 | 4.0× | 1.0× | book price; barks are wary (§5) |
| Known | 10–24 | 3.8× | 1.05× | greeted by trade, not name |
| Trusted | 25–49 | 3.5× | 1.15× | first-name barks; special shown a day early |
| Friend of the Hollow | 50+ | 3.2× | 1.25× | vendors bark thanks for named deeds |

Rep tiers also gate reaction pools (§5.4) — the *audible* reward matters more
than the ~7 % discount; classic taught that reputation is mostly theater, and
the theater is the point.

### 4.2 Haggling — one button, one roll, one game-day

On VendorUI: the **[ Haggle ]** button, enabled once per vendor per day
(state in Vendors, serialized, reset at the 06:00 restock).

```
success_chance = 0.25 + 0.10 * tier_index      (25 / 35 / 45 / 55 %)
success → haggle_mult 0.90 for THIS vendor until dawn; bark: "For you, then."
failure → haggle_mult 1.05 until dawn; bark: "My price was fair. Now it is firm."
```

Seeded `hash(npc_id + str(day_index) + str(rep))` — deterministic per day
(save-scumming a 25-second day is pointless by construction). Cheap to build,
creates a daily ritual, and gives reputation a *verb*.

---

## 5. REACTION SYSTEM (ReactionDirector — barks that know what day it is)

### 5.1 Contract

The shipped bark pipeline is untouched end-to-end: `_tick_bark()` cooldowns →
`Voice.bark()` → baked `assets/vo/<speaker>/<hash>.ogg` or live TTS. The
**only** change is where the *line* comes from (§1.4). ReactionDirector picks
from tag-matched pools instead of the single `GENERIC_BARKS` list.

**Bake law:** every line below is a **static string** — no interpolation, no
player name, no numbers — so the existing `hash(speaker + text)` bake pipeline
covers all of it. The full reaction corpus is bakeable in one offline pass per
speaker. (Class reactions get 7 static variants, not a `%s`.)

### 5.2 Context assembly (one dict per tick, shared by all NPCs)

```gdscript
class_name ReactionDirector
extends Node
## Main-child singleton (group "npc_reactions"). Rebuilds a context snapshot
## at 1 Hz from shipped singletons — NPCs never poll the world themselves.

var _ctx: Dictionary = {}   # rebuilt per tick:
# {
#   "weather": "storm",         # Weather group: Type enum -> tag string
#   "night": true,              # DayNight.is_night
#   "hour_band": "evening",     # dawn/morning/midday/evening/night
#   "player_class": "rogue",    # player.class_def.get("id")  (ClassDefs id)
#   "deeds": ["saved_mira"],    # §5.5 recent-deed tags with day-based expiry
#   "event": "festival_harvest" # §8 TownEvents active event ("" = none)
#   "rep_tier": "trusted",      # §4 current-capital tier
# }

## npc.gd calls this from _tick_bark (duck-typed, salt keeps determinism):
func line_for(npc_id: String, salt: int) -> String
```

### 5.3 Pool selection — strict priority, deterministic pick

`line_for()` walks pools in priority order, takes the **first non-empty
match**, and picks within it by the shipped `abs(hash(npc_id) + salt) % size`
so repeated barks vary but stay bake-reproducible:

```
1. event        (funeral vigil > festival — §8 sets exactly one)
2. deed         (recent player deeds, §5.5 — the "they noticed" magic)
3. weather      (storm/ash first; rain/snow/fog)
4. player_class (rolled in only ~30% of picks via salt parity, so class
                 comments stay a spice, not a broken record)
5. npc react_tags + hour_band   (dockhand-at-dawn lines)
6. rep_tier greetings
7. GENERIC_BARKS (shipped list — the eternal fallback)
```

### 5.4 Pool data (VoiceRegistry extension — same file, same style)

```gdscript
# voice_registry.gd — new consts beside GENERIC_BARKS:
const REACT_POOLS := {
    "weather_rain":  ["This rain has opinions.", "The thatch will drink well tonight.", ...],
    "weather_storm": ["Get inside, fool!", "The sky is settling a debt.", ...],
    "weather_snow":  ["Cold enough to keep the dead patient.", ...],
    "weather_fog":   ["Mind the fog. It minds you.", ...],
    "night":         ["Be indoors soon.", "The lanterns are lit for a reason.", ...],
    "class_warrior": ["That blade has seen work.", ...],
    "class_rogue":   ["I count my purse when you pass. No offense.", ...],
    "class_mage":    ["Keep your sparks off my thatch.", ...],
    "class_necromancer": ["You smell of the graveyard hill. Vasile's friend, I hope.", ...],
    "class_paladin": ["Bless the road you walked in on.", ...],
    "class_rookwarden": ["Keep that bird away from my stall.", ...],
    "class_druid":   ["The pear tree leans toward you. I saw it.", ...],
    "rep_outsider":  ["New face. Stay honest.", ...],
    "rep_trusted":   ["Good to see you again, friend.", ...],
    "festival":      ["The whole Hollow is out tonight!", "Save me a seat by the fire!", ...],
    "vigil":         ["Not today. Today we stand quiet.", "Walk soft near the hill.", ...],
    "tag_dockhand":  ["The river is high and lying about it.", ...],
    "tag_orphan":    ["Maren says chalk washes off. It doesn't!", "Watch me! Watch!", ...],
    "tag_guard":     ["Move along.", "The wall holds. I make sure.", ...],
}
const DEED_POOLS := {   # deed tag -> lines (§5.5)
    "saved_mira":    ["You brought the miller's girl home. We don't forget that here.", ...],
    "cleared_wolves":["The road east breathes easier. Your doing, I hear.", ...],
}
```

Per-NPC bespoke overrides stay possible later (named-cast pools keyed
`"<npc_id>:weather_storm"` checked first) — data-only, no code change.

### 5.5 Recent deeds — quests → street talk

ReactionDirector listens to `quest_completed(quest_id)` and maps ids through a
small const (`DEED_TAGS := {"q5_listener": "saved_mira", ...}`) into
`_deeds: Array` with a **3-game-day expiry** (day index from Vendors §3.3).
For a week of real minutes after a quest, the town talks about it; then it
fades to history. On a quest with a *death* outcome, the same table can emit a
`"mourn_<id>"` deed **and** ask TownEvents for a vigil (§8.3) — one wire, two
payoffs. Serialized with TownEvents.

---

## 6. CAPITAL DENSITY PLAN — ANGEL WINGS FIRST (19 NPCs)

Angel Wings (WORLD_PLAN z7) is the proving ground: poor, crowded, ordinary —
density must read as *working city*, not parade. 19 NPCs across four districts
(grain market / river docks / thatch sprawl / Maren's Orphanage, with the Lead
Vault as a guarded, *empty* landmark — its emptiness is the story).

Sheet/variant law (npc_data.gd contract): named-cast combos are taken
(f1:0, m2:1, m3:2, m4:0, m2:3, f2:1, m1:2, m4:1, f1:2, MAID, player m1:0).
Angel Wings uses the **remaining 14 RAMPS-verified pairs** plus palette-swapped
reuse of taken pairs — every (sheet, variant, palette) triple unique, palettes
drawn from `NPC.OUTFIT_COLORS/HAIR_COLORS/SKIN_TONES`.

| # | id | Name | Role / vendor | Sheet:variant + palette | Day anchor → evening |
|---|---|---|---|---|---|
| 1 | `aw_smith` | Smith Codrina | `weaponsmith` | f2:0 (oxblood/charcoal) | forge → taproom |
| 2 | `aw_armorer` | Armorer Bogdan | `armorer` | m3:0 (slate/black) | armory stall → taproom |
| 3 | `aw_chandler` | Chandler Ilse | `general` | f1:1 (dun/ash_grey) | market row → home |
| 4 | `aw_herbalist` | Herbalist Sorina | `alchemist` | f2:2 (moss/chestnut) | herb stall → home |
| 5 | `aw_innkeep` | Innkeep Radu | `provisioner` | m2:0 (umber/dark_brown) | taproom **all day**, sleeps 4:00–10:00 |
| 6 | `aw_tanner` | Tanner Vlad | `leatherworker` | m4:2 (umber/black) | tannery → taproom |
| 7 | `aw_dockmaster` | Dockmaster Neagu | `tradegoods` | m3:1 (charcoal/ash_grey) | dock office → dock office (sells there) |
| 8 | `aw_ragman` | Rag-and-Bone Petrica | `collector` | m1:3 (charcoal/white) | roams market ↔ docks (mobile junk-buyer) |
| 9 | `aw_trainer_war` | Sword-Mistress Vela | martial trainer (war/rog/pal placeholder-dialogue) | f1:3 (wine/black) | training yard → taproom |
| 10 | `aw_trainer_arc` | Lector Anghel | arcane trainer (mage/necro) | m3:3 (faded_teal/white) | Lead Vault steps → home |
| 11 | `aw_trainer_wild` | Warden Codru | wild trainer (druid/rookwarden) | m4:3 (moss/dark_auburn) | riverbank → taproom |
| 12 | `aw_guard_gate` | Gate-Guard Stanca | guard, static post | f2:3 (slate/black) | west gate, `patrol` absent, 24 h counter-shift |
| 13 | `aw_guard_1` | Watchman Dregan | guard, `patrol` A | m2:2 (charcoal/black) | gate→market→docks loop, day shift |
| 14 | `aw_guard_2` | Watchman Fira | guard, `patrol` B | f2:1 + palette (charcoal/ash) | market→orphanage→sprawl loop, **night shift** |
| 15 | `aw_maren` | Maren | orphanage matron; quest hub (Maren's Vigil set chain, LOOT_TABLES donation turn-in) | f1:0 + palette (ash/white) | orphanage yard, r=16, never leaves |
| 16 | `aw_orphan_1` | Luca | orphan | m1:1 **scale 0.8** (see below) | orphanage yard chase-play → indoors 20:00 |
| 17 | `aw_orphan_2` | Bina | orphan | f1:1 + palette (faded_teal) scale 0.8 | orphanage yard → indoors 20:00 |
| 18 | `aw_dockhand_1` | Stevedore Mihu | dock worker | m2:1 + palette (slate/black) | docks (crate route, `react_tags:["dockhand"]`) → taproom |
| 19 | `aw_dockhand_2` | Stevedore Oana | dock worker | f2:0 + palette (dun/chestnut) | docks → home |

**Orphans, honestly:** there is no child sheet. Plan A is `_sprite.scale = 0.8`
on the shipped szadi frames — at 640×360 integer-pixel scale this shows
fractional-pixel shimmer, so it ships **behind a look-check screenshot**
(RH_* harness). Plan B (preferred, budgeted): one 32×48 child sheet through the
established ComfyUI/Pixel-Art-XL sprite pipeline, palette-swappable with a new
RAMPS entry. The design does not gate on it: orphans are 2 of 19.

**Orphan play behavior** (the postcard): both orphans share the yard anchor
(r=20); every 20–40 s one gets a 1.4× WALK_SPEED burst toward the other
(a `_route` of one point — reuses §1.3 verbatim, no new movement code), with
`tag_orphan` barks on a shortened 12–20 s cooldown. Cost: ~15 lines in
ScheduleDirector, reads as tag.

**Guard patrols:** `patrol` key (§1.1) loops anchors at WALK_SPEED with a
15–25 s post-stand at each (facing outward via the def `facing` at anchor
metadata). Guards ignore storm overrides (`react_tags: ["guard"]` +
weatherproof check in §8.2), keep `_apply_night` disabled, and their two
shifts guarantee a moving lantern at any hour.

**Density calibration vs. shipped town:** Raven Hollow demo town runs 9 spawned
NPCs; Angel Wings' 19 + routes stays trivially cheap (19 CharacterBody2Ds with
one `move_and_slide` each; the directors tick at 1 Hz). COMBAT_PACING puts
combat *outside* the walls — inside, the frame budget belongs to crowd and UI.

---

## 7. CROWD FLOW — MAKING 19 READ AS A CITY

Schedule design rules that turn timetables into *streets*:

1. **Hub-and-spoke routing.** Nearly every route chains through the market
   square or the dock stair — so transitions put 2–4 NPCs on the same road at
   once. Crowd = shared corridors, not raw count.
2. **The two commutes.** 6:30–7:30 everyone walks *to* work (dockhands cross
   the market against the stall-keepers); 19:00–20:00 the reverse tide flows
   into the taproom. Jitter (±0.4 h) turns columns into trickles.
3. **The midday pulse.** 12:30–14:00 five schedules share the square anchor
   with wide radii — the market *fills*, barks overlap (per-NPC cooldowns keep
   it from becoming noise), and this is when the rotating stock special is
   freshest. Screenshot hour, by design.
4. **Counter-phase lonely souls.** Petrica the rag-man roams while others
   stand; night-shift Fira walks while the town sleeps; Radu's taproom never
   closes during waking hours. There is no hour at which the town is static.
5. **Districts have accents.** Dockhands' `react_tags` pools differ from the
   market's; orphan noise stays near Maren's; the Lead Vault street is
   deliberately silent (no anchors) — negative space is also flow design.

---

## 8. SMART BEHAVIORS (TownEvents — the moments players screenshot)

```gdscript
class_name TownEvents
extends Node
## Main-child singleton (group "town_events"). Small state machine over
## ScheduleDirector.push_override + ReactionDirector context. One active
## event max; priority vigil > festival > storm (storm is weather-driven
## and re-asserts when a higher event ends mid-rain).

signal event_started(id: String)
signal event_ended(id: String)

func active_event() -> String          # "" | "storm_shelter" | "festival_*" | "vigil_*"
func request_vigil(dead_name: String) -> void     # §8.3 — quests calls this
func serialize() -> Dictionary
func deserialize(d: Dictionary) -> void
```

### 8.1 Storm shelter (the everyday one)

On `Weather.weather_changed(STORM)` (and RAIN at intensity ≥ 0.8, polled at
tick): `push_override("*", "<nearest shelter>", r=6, until=clear, "storm")` —
each scheduled NPC diverts to the nearest `indoor: true` anchor **or** a tagged
awning anchor (`shelter: true`, e.g. the taproom porch, the dock office
overhang — some NPCs visibly waiting out the rain beats everyone vanishing).
Guards and anyone with `react_tags: ["guard"]` are exempt and keep patrol.
Weather clearing pops the override; everyone walks back to where the clock
says. Barks flip to `weather_storm` automatically via §5 priority — the system
*announces itself*.

### 8.2 Festivals (the calendar one)

Data-driven const in TownEvents: `FESTIVALS := {"harvest_fair": {"every_days": 7,
"from_h": 18.0, "to_h": 23.0, "anchor": "aw_market_sq"}}` — day index from
Vendors §3.3. During the window: override all civilians to the festival anchor
(wide r=30), `festival` bark pool engages, vendors **stay open late** with
`is_open()` honoring the event, and the existing world-lights group already
makes the square glow at night (DayNight light scale 1.3). The shipped demo
town's fountain/harvest-fair dialogue lines (Marta, Ansel, Elsbeth all mention
the fair) finally cash the check the writing already wrote.
Hook for later content: `event_started` is a quest trigger surface
(festival-only quests), zero extra plumbing.

### 8.3 Funeral vigils (the one nobody expects a pixel game to do)

When a quest resolves with a named death (quest_defs already carries
choice-dependent aftermaths; the mapping table in §5.5 flags which outcomes
kill whom), `Quests` calls `TownEvents.request_vigil(name)`. Next game-day
18:00–19:30: civilians override to the graveyard-gate anchor with r=8 and a
director-forced `idle_up` facing (one extra `apply_anchor` param, or simply
anchors carrying a `face: "up"` hint consumed on arrival) — a quiet crowd
standing unnaturally still, name tags off (suppress at the vigil anchor).
`vigil` pool owns all barks; **vendors read `is_open() == false`** with the
"we are burying Anska" line (§3.4); festival due the same day is skipped, not
moved. 90 game-minutes ≈ 37 real seconds — long enough to walk into, short
enough to never annoy. One-shot; serialized so save/load can't dodge or repeat
a funeral.

### 8.4 Already-shipped smart behavior, formalized

Night pull-home (`_apply_night`) stays as the **no-schedule fallback** tier of
the same idea — this doc's stack supersedes it only where schedule data exists
(§1.4). The escort-lite controller keeps top movement priority (a vigil never
kidnaps Mira mid-escort).

---

## 9. SAVE / LOAD (save_system.gd pattern — no core changes)

Each new singleton ships the established opaque pair, discovered by group like
weather/quests:

| System | serialize() payload |
|---|---|
| ScheduleDirector | active overrides only (blocks derive from `time_of_day`, already saved by DayNight) |
| Vendors | stock counts, `day_index`, special item ids, haggle state per vendor, **rep per capital** |
| ReactionDirector | `_deeds` with expiry day stamps |
| TownEvents | active event + pending/done vigils |

Load order note: DayNight restores `time_of_day` first (shipped); directors'
first tick then snaps every NPC to the correct anchor via
`apply_anchor(travel=false)` — a load never shows the whole town commuting.

---

## 10. ROLLOUT ORDER (each phase ships playable, screenshot-gated via RH_* harness)

| Phase | Ships | Depends on | Proof shot |
|---|---|---|---|
| **S1 — Legs** | npc.gd extensions (§1: route queue, `apply_anchor`, `set_hidden`, player cache) + ScheduleDirector + anchors/routes for the **existing demo town** (9 NPCs get 3-block days) | nothing new | Marta behind the bar at 20:00; empty square at 02:00; Goran walking to the forge at dawn |
| **S2 — Voices** | ReactionDirector + VoiceRegistry pools (§5) + `_tick_bark` deferral; weather/night/class/rep pools; bake pass | S1 (block_changed), shipped TTS | storm rolls in, three NPCs grumble about the sky in their own voices |
| **S3 — Shops** | Vendors + VendorUI + restock/day counter (§3); demo-town vendors (Marta = provisioner, Goran = weaponsmith, Tibalt = general) | ITEM_PROGRESSION checklist items 1 & 6 (`value` keys in items.gd) | buy a Bog-Iron Cleaver; sell five pelts; gold ticks on the HUD |
| **S4 — Faces** | Reputation + haggling (§4); deed pools (§5.5) | S2, S3, quests signals (shipped) | finish quest 5, walk the square, hear "you brought the miller's girl home" |
| **S5 — Weather-wise** | TownEvents: storm shelter + festival (§8.1–8.2) | S1, S2 | rain starts, the square drains to the awnings; fair night crowd shot |
| **S6 — The Vigil** | funeral vigils (§8.3) + quest-death mapping | S5, quest_defs aftermath audit | the graveyard-gate crowd, heads up-facing, vendors shut |
| **S7 — Angel Wings** | z7 build: 19-NPC roster (§6), district anchors/routes, capital stock tables + special, orphan play, guard shifts; child-sheet decision (Plan A/B) | S1–S6 proven in demo town; zone_builder z7 | the midday market pulse; the 6:30 dock commute; night-shift Fira's lantern |

S1–S6 all land in the *shipped demo town first* — the 9-NPC cast is the test
bench, Angel Wings is the payoff, and every phase before S7 makes the current
game visibly better on its own.

---

## 11. INTEGRATION CHECKLIST (implementation pass, file by file)

1. `npc.gd` — §1: `_route`/`_hidden`/`_player_cache`, `apply_anchor`, `set_hidden`,
   route branch in `_physics_process`, `_stop_walking` route pop, `_apply_night`
   schedule-gate, `_tick_bark` director deferral. (~80 lines; nothing removed.)
2. `scripts/schedule_director.gd` (NEW) — §2.2. `main.gd _spawn_systems()` adds it;
   `_post_build_map()` calls `on_map_built(built.npc_anchors, built.npc_routes)`
   and `register()` per spawned NPC def.
3. `town_builder.gd` — §2.3 anchors + routes for the demo town (S1) ; door anchors
   at existing house façades; `zone_builder.gd` same contract for z7 (S7).
4. `scripts/vendors.gd` (NEW) — §3–§4; `scripts/vendor_ui.gd` (NEW) — §3.4 on the
   BagUI kit; `bag_ui.gd` right-click sell branch + `DragCtx.from_kind "vendor"`.
5. `voice_registry.gd` — §5.4 pools consts; new speakers (`aw_*` roster + `"orphan"`);
   `scripts/reaction_director.gd` (NEW) — §5.2–5.5; bake pass for the corpus.
6. `scripts/town_events.gd` (NEW) — §8; `quests.gd` gains only the one-line
   `request_vigil` call site in `_complete()` per the death-mapping table.
7. `npc_data.gd` — schedule/vendor/react_tags keys on the demo cast (S1/S3);
   new `angel_wings_cast()` returning the §6 roster (S7); `main.gd
   _spawn_npc_cast` reads the per-map cast from the map def (one-line switch).
8. `save_system.gd` — zero code: the four new groups ride the shipped
   serialize/deserialize discovery.
9. QA — `RH_WEATHER=storm` env hook (shipped) + a new `RH_TIME=<hour>` env hook
   through `DayNight.set_time()` for schedule screenshots; `tests/` probe:
   tick a full 24 h at speed, assert every scheduled NPC visited every anchor
   and ended hidden at home.
