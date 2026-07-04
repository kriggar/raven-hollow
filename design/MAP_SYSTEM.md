# RAVEN HOLLOW — MULTI-SCALE MAP SYSTEM (WoW map behavior on gothic parchment)
The Map Masterpiece, tier two: one map that ZOOMS — per-zone parchment ↔ continent sheet ↔ the
two-continent world chart — with the player marker burning on every tier. Owner law (MANDATES,
UI & Presentation): **the player KNOWS WHERE THEY ARE AT ALL TIMES**, and the map is
**mandatory, iterate forever** — this spec is v1 of the multi-scale behavior on top of the shipped
parchment v2.

**Grounded in (read before writing):**
- `design/MANDATES.md` — map law: position ALWAYS known; ZOOM zone ↔ continent ↔ world; minimap
  same polish. Gothic Romanian parchment style is locked (v2 shipped).
- `tools/map_gen.py` — the world parchment v2 (2048×1152 → `assets/art/ui/world_map.png`): aged
  parchment + iron-gall ink (`INK (52,38,24)`, `BLOOD (112,32,24)`), `rough_poly` hand-jitter lines,
  woodcut glyph kit (`mountains/trees/waves/snow_hatch/keep`), Alagard lettering with parchment
  halo, double-rule frame w/ corner diamonds, compass rose, rhumb lines, raven, Bloodstone wax seal.
  **This file is the style bible — every new map sheet reuses its exact helpers and palette.**
- `scripts/zone_defs.gd` — the 40-zone registry (`_ZONES`): per built zone `tiles_w/tiles_h`
  (world px = tiles × 32), `roads` (Array of polylines), `river` + `river_width/river_color`,
  `landmarks` ({type, pos, count?, live?}), `vignettes`, `waystations` ({id, pos}), `border_gaps`,
  `travel_points`, `capital`, `region`, `biome`. `ROUTES` = waystation graph. 10 playable maps
  today: `town`, `wilderness` + 8 built zones (border ring + west chain to Riverfork).
- `scripts/minimap.gd` — layer 8 minimap (64 px, `MapView` inner class, arrow/dots/diamonds) +
  layer 12 M-key `WorldMapOverlay` (520×330 panel, `OverlayMarks`, district labels, quest-pin
  duck-type `quests.map_pins(map_id)`). `set_map(map_id, bounds, travel_points, display_name)` is
  the integration surface; `is_world_map_open()` gates pause-menu Esc. **This overlay is what the
  multi-scale map replaces; the 64 px minimap frame stays and gets the §9 polish.**
- `scripts/map_registry.gd` — playable-map defs; `travel_points()` per map; zone defs merged via
  `ZoneDefs.map_defs()`.
- `scripts/travel_system.gd` — autoload; station registry + discovery (90 px radius,
  `station_discovered` signal), `can_travel()` BFS over `ZoneDefs.ROUTES`, `travel_to()` via
  `main.change_map_to_pos`, `save_state()/load_state()`.
- `scripts/main.gd` — `change_map(map_id, entry_point_id)`, autosave on change_map, layer bands
  (HUD/minimap 8 · bag/sheet 9 · dialogue 10 · **map overlay 12** · fade 25 · menus 30), 640×360
  design viewport, integer scaling.
- `WORLD_PLAN.md` §Travel — "M opens a two-continent parchment map; zones fill in as discovered;
  waystation nodes lit/unlit; click a lit node to travel (if connected)."
- `tools/dump_vo_lines.gd` + `tools/vo_lines.json` — the proven headless-dump pattern the zone-map
  generator reuses to read GDScript data from Python.

---

## 0. Design tenets

1. **Never lost.** Opening the map ALWAYS starts on the zone tier, centered on the player, arrow
   pulsing. Every tier renders the player marker — zooming out never loses "you are here."
2. **One manuscript.** All three tiers are pages of the same iron-gall atlas: same parchment, same
   ink constants, same Alagard, same frame language. A zone map must look like a *detail leaf*
   cut from the world chart, not a different game's UI.
3. **The map is data-honest.** Zone sheets are generated from the SAME hand-authored zone defs the
   ZoneBuilder builds from — roads on the map are the roads under your boots. No drift, ever:
   regenerate the sheet when the def changes.
4. **Discovery is the reward.** Undiscovered zones are blank vellum bearing only a name — walking
   the world literally inks the atlas in (WoW map-fill dopamine, manuscript flavor).
5. **The map is a tool, not a screenshot.** Waystation pins fast-travel, regions click-zoom, quest
   pins guide. Everything interactive answers hover with a parchment-halo highlight.

---

## 1. The three tiers

| Tier | Name | Texture | Source | Player marker |
|---|---|---|---|---|
| 0 | **WORLD** — "Draconia & the Drowned Coast" | `assets/art/ui/world_map.png` (2048×1152, shipped v2) | `tools/map_gen.py` (unchanged output) | gold-ember dot + pulse ring at the zone's world anchor |
| 1 | **CONTINENT** — one sheet per continent | `assets/art/ui/continent_1.png`, `continent_2.png` (~2048×1456) | `tools/map_gen.py` v3 (§4 — re-render of each continent crop at 2× ink density, + zone borders/labels) | small gold arrow at anchor + intra-zone offset |
| 2 | **ZONE** — one parchment leaf per zone | `assets/art/maps/zones/<zone_id>.png` (≤2048 wide, zone aspect) | `tools/zone_map_gen.py` (§3 — NEW, auto-generated from the zone def) | full gold arrow (heading), identical to today's overlay arrow |

Tier order for zoom: `ZONE (2) ⇄ CONTINENT (1) ⇄ WORLD (0)`. M opens at ZONE. The two legacy maps
(`town`, `wilderness`) participate as zone-tier leaves: `town` keeps its shipped `town.png` (later
upgraded to a generated parchment leaf via a hand-written def), both get world anchors (§5).

---

## 2. Zone tier — the parchment leaf

What the player sees when M opens: the current zone as a manuscript detail page.

Contents (all generated, §3):
- **Terrain**: biome glyph fields (trees/dead trees/mountains/snow-hatch/waves per biome), the
  zone's `river` polyline as a double rough-ink stroke, `roads` as dashed cart-track strokes.
- **Landmarks**: every entry in the def's `landmarks` array rendered as a woodcut glyph (§3.2
  vocabulary) — the tavern is a little inn glyph exactly where the Bent Oar stands.
- **Waystations**: coach-lantern glyph + name scroll (live pin behavior in §7).
- **Border gaps**: each `border_gaps` rect becomes an ink arrow through the frame + the neighbor's
  name in small Alagard ("→ Vetka") pulled from the matching travel_point's `to_map`.
- **Cartouche**: zone name (F_KINGDOM size) + region epithet line (small, `INK_SOFT`), corner
  compass sliver, thin double-rule frame (the world frame's little sibling).
- **Vignette marks**: NOT rendered (they are discoveries, not chart features). Exception: `capital`
  zones get their keep glyph.

Runtime overlays on top of the texture (drawn by `MapMarks`, §10): player arrow, waystation pins,
quest pins, party members (future), ping rings.

**Undiscovered zone leaf**: never shown (you cannot open the zone tier of a zone you have not
stood in; region-click on such a zone whispers `uncharted` — §6).

---

## 3. `tools/zone_map_gen.py` — the zone-leaf generator (NEW)

### 3.1 Data path (GDScript → Python, the vo_lines pattern)
Python cannot read `zone_defs.gd`. Reuse the proven dump pattern:

- **NEW `tools/dump_zone_defs.gd`** (EditorScript / `--headless --script`): serializes
  `ZoneDefs._ZONES` for every zone with `built:true` (plus `town`/`wilderness` synthetic defs) to
  **`tools/zone_defs.json`**. Vector2 → `[x, y]`, Rect2 → `[x, y, w, h]`, Color → `[r,g,b,a]`.
  Run: `godot --headless --path medieval_rpg --script res://tools/dump_zone_defs.gd`.
- `tools/zone_map_gen.py` reads the JSON, emits one PNG per zone into `assets/art/maps/zones/`.
  Regeneration is part of every zone-batch checklist (WORLD_PLAN build order): flip `built:true`
  → dump → generate → commit the leaf.

### 3.2 Shared style module
Refactor, don't fork: extract from `map_gen.py` into **`tools/map_style.py`** —
`parchment(w, h)`, `rough_poly`, `mountains`, `trees`, `waves`, `snow_hatch`, `label`, `keep`,
the ink/blood/sea constants, and the font loaders. `map_gen.py` v3 and `zone_map_gen.py` both
import it. **Same rng-seed discipline**: seed per sheet = `hash(zone_id) ^ 20260705` so a leaf is
reproducible until its def changes.

Landmark glyph vocabulary (woodcut, all built from `map_style` primitives — each ~24–40 px at
render scale, `INK` strokes, `BLOOD` accents only where noted):

| def `type` | glyph |
|---|---|
| `tavern` / `shop` / `workshop` | gabled house, chimney smoke curl; tavern adds a hanging-sign tick |
| `cottage` / `shed` / `barn` | smaller gable; barn wider w/ cross-brace |
| `hamlet` (count n) | cluster of `min(n,4)` tiny gables |
| `manor` | two-gable keep-let with banner line |
| `plaza` / `fountain` | open square outline / basin circle w/ 3 water ticks |
| `stall` | lean-to stroke pair (skip if within 40 px of plaza glyph — declutter) |
| `well` / `copper_well` | circle + winch bar; copper_well adds `BLOOD` rim (the rot is on the chart) |
| `graves` (count) | `min(count,5)` latin crosses, staggered |
| `inscription_stone` | standing slab; `live:true` adds a faint `BLOOD` halo ring |
| `dolmen` / `stone_row` (count) | Π-stones / row of `min(count,6)` ticks |
| `camp` | tent triangle + fire dot |
| `bones` | rib-arc pair |
| `pond` | small ragged ellipse, `SEA_TINT` fill + one wave arc |
| `stump` / `trunk_hollow` | (skip — sub-chart-scale clutter) |
| `statue` | plinth + figure stroke |
| waystation | coach lantern: diamond on a post + name in F_SMALL on a halo scroll |

### 3.3 Layout algorithm
1. Canvas: zone world size = `tiles_w×32 by tiles_h×32`; render scale `s = min(2048/w_px, 1408/h_px)`
   (iron_vein 6656×4608 → ~0.31 → 2048×1418 leaf). Inner chart rect inset 72 px for the frame.
2. `parchment()` base → biome tint wash (bog: faint green-brown blotches; tundra: pale + snow_hatch
   field; volcanic: ash-grey blotches + ember `BLOOD` specks; farmland: warm; deadforest: grey).
3. Rivers first (under roads): `rough_poly(width=int(river_width*s*0.5)+3, color=river_color→ink-mixed,
   close=False)` twice with 2 px offset = double-stroke manuscript river; delta ticks at ends.
4. Roads: dashed strokes (draw alternate subdivided segments, the Grey Ferry dash technique from
   `map_gen.py`), width 3.
5. Biome glyph fields: scatter `trees`/`mountains`/etc. in the walkable field, density from
   `tree_density`, **excluding** 90 px around any landmark/road/river point (glyphs never collide
   with authored marks; simple poisson-reject with the def polylines rasterized to a keep-out mask).
6. Landmarks: glyph per table, then name-less (labels only for waystations, capitals, and any
   landmark the QUEST_ARCHITECTURE pass promotes to named POI later — hook: optional `map_label`
   key in the def entry, rendered F_SMALL `INK_SOFT`).
7. Border gaps → frame-piercing arrows + neighbor names; cartouche (zone `name` + a per-region
   epithet table in the generator: border "the seam that holds", west "the underestimated west",
   north "under the un-light", east "the listening stones", south "the forge-lands", coast "the
   drowned ledger"); compass sliver bottom-left; double-rule frame + corner diamonds.
8. Save PNG. Print the leaf's px-per-world-px so the runtime never guesses (also embedded: the
   chart rect inset is a generator constant `CHART_INSET = 72` mirrored in GDScript, §5.3).

---

## 4. Continent tier — `map_gen.py` v3

`map_gen.py` grows two more outputs (same script, three `save()`s; world sheet unchanged):

- **`continent_1.png` — DRACONIA**: re-render (not upscale) of the Draconia landmass at 2× glyph
  density into a 2048×1456 sheet. Adds what the world chart omits: **zone borders** — faint
  `INK_FAINT` rough_poly partitions of the landmass into the 25 continent-1 zone footprints — and
  a **zone name in F_ZONE per footprint** (planned zones too: the atlas admits the whole kingdom
  exists; discovery only controls *fill*, §6). Waystation nodes drawn as small lantern diamonds.
- **`continent_2.png` — THE COLLECTOR'S COAST**: same treatment, 1536×1456 (smaller landmass),
  14 coast zones, Greyhollow canal grid kept.

**Footprint authority**: the zone partition polygons live in the generator as
`FOOTPRINTS_C1/_C2 = {zone_id: [(x,y), ...]}` in **world-sheet px** (single hand-tuned table,
iterated visually like v2 was), and the generator ALSO writes them to
**`tools/map_anchors.json`** together with each zone's anchor point and the continent crop
transforms — the runtime consumes that JSON baked into `map_anchors.gd` (§5.2). One authoring
site, zero drift between Python art and GDScript hit-testing.

Continent↔world transform: `CONT_CROPS` (world-sheet px) `{1: Rect2(96,180,1180,880),
2: Rect2(1390,330,610,580)}`; continent-sheet px = `(p_world_px - crop.pos) * sheet_size/crop.size`.

---

## 5. "You are here" on every tier — the coordinate chain

### 5.1 The chain
```
player.global_position  (zone world px)
  → uv = (pos - zone_bounds.position) / zone_bounds.size        # 0..1 in-zone
  TIER 2: leaf_px  = chart_rect.position + uv * chart_rect.size # chart_rect = leaf minus CHART_INSET frame
  TIER 1: cont_px  = footprint_anchor + (uv - 0.5) * footprint_extent   # fine position INSIDE the footprint
  TIER 0: world_px = ANCHORS[zone].world + (uv - 0.5) * Vector2(26, 20) # subtle in-zone wobble at world scale
```
The world-tier wobble is deliberate: even fully zoomed out, walking across the Iron Vein visibly
slides the ember dot — the law is *knows where they are*, not *knows which blob they're in*.

### 5.2 `scripts/map_anchors.gd` (NEW, `class_name MapAnchors`)
Static table generated from `tools/map_anchors.json` (checked in, hand-editable): per zone —
`world: Vector2` (anchor on world_map.png), `footprint: PackedVector2Array` (continent-sheet
polygon), `continent: int`. Plus `CONT_CROPS`. Seed values for the 12 playable maps (world px,
matching the v2 chart's inked labels — hand-tune against the art on first render):

| map/zone | world anchor | note |
|---|---|---|
| `town` (Raven Hollow) | (700, 600) | the double-ring hub mark |
| `wilderness` | (662, 614) | the Emberfall Road, west of the hub |
| `iron_vein` | (566, 652) | on the Iron Vein river label |
| `vetka` | (790, 648) | inked "Vetka" |
| `copper_wells` | (860, 700) | inked "the Copper Wells" |
| `stonepath` | (960, 640) | inked "the Stonepath" |
| `grey_marches` | (470, 540) | inked "the Grey Marches" |
| `western_lowlands` | (392, 588) | between Marches and the capital |
| `angel_wings` | (300, 545) | the western keep |
| `famine_fields` | (258, 606) | SW of the capital |
| `riverfork` | (330, 660) | inked "Riverfork" |
| `chamber_depths` | (700, 620) | under the hub (dungeon; world dot only) |

Remaining 28 zones: anchors land batch-by-batch with their footprints (the generator warns on any
`built:true` zone missing from the table — the same honesty discipline as zone stubs).

### 5.3 Constants mirrored, once
`CHART_INSET = 72` (leaf frame), footprint extents, crop rects: all live in `map_anchors.json`,
written by the Python side, loaded by `map_anchors.gd`. **Never hand-copy a number between
`tools/` and `scripts/` — the JSON is the treaty.**

---

## 6. Discovery & fog-of-war

- **Unit of discovery = the zone.** `main.change_map()` marks the target map id discovered
  (NEW `MapAnchors`-adjacent runtime set on the Minimap/MapSystem singleton; persisted by
  `save_system.gd` as `"discovered_maps": [...]` next to the current-map id; `town` + `wilderness`
  discovered from a new game — the demo start).
- **Zone tier**: only openable for the CURRENT zone and other discovered zones (breadcrumb/region
  navigation may browse any discovered leaf).
- **Continent tier**: discovered zones render normally. Undiscovered zones render as **blank
  vellum**: the footprint filled with a slightly lighter parchment tone (no terrain, no glyphs,
  no borders inside), bearing ONLY the zone name in `INK_FAINT` Alagard — the atlas leaves you the
  page to earn. Implementation: the generator writes `continent_N.png` fully inked PLUS
  `continent_N_veil.png` (same size, the blank-vellum version); runtime composites per zone by
  stenciling the footprint polygon from the veil sheet over the inked sheet for undiscovered ids
  (one `Polygon2D`-clipped `TextureRect` per undiscovered zone, rebuilt on discovery — ≤39 cheap
  nodes, zero shader work, GL Compatibility safe).
- **World tier**: no veiling (it is the frontispiece; kingdoms are public knowledge) — but only
  discovered zones show their ember anchor dots lit; undiscovered anchors are unmarked.
- **Discovery moment**: first entry to a zone plays the map-fill flourish if the map is open (veil
  patch fades 0.6 s + ink-spread ping, §10) and always shows the existing location banner.

---

## 7. Waystation pins & fast travel (the TravelSystem face)

Every tier shows waystations; the ZONE and CONTINENT tiers make them clickable:

- **Pin states** (drawn by `MapMarks`): `undiscovered` — not drawn at all (WoW rule: you learn the
  coach stop by standing at it; `TravelSystem.is_discovered`); `discovered` — gold lantern diamond
  + name on hover; `reachable` — discovered AND `TravelSystem.can_travel(nearest_discovered_here,
  id)` from the player's current zone's discovered station: rendered with a `BLOOD` wick dot +
  slow 1.5 s glow pulse; `current` (station in player's zone within 90 px) — ringed.
- **Click a reachable pin** → confirmation strip slides up inside the panel footer: `"Take the
  coach to Vetka Square — [E] ride · [Esc] stay"` (Alagard, gold on dark wood). Confirm →
  `TravelSystem.travel_to(id)` → main fades, map closes, autosave fires (existing change_map path).
  Coin cost line reserved in the strip (economy hook, greyed "— " until charged).
- **Route ink**: on CONTINENT tier, discovered-to-discovered `ROUTES` edges draw as the dashed
  Grey-Ferry-style track between station pins — the coach network becomes visible as you unlock it.
- TravelSystem needs one addition: `station_ids() -> Array[String]` + station data already exposed
  (`station_pos/station_zone`) — pins derive entirely from the autoload; **no new state**.

---

## 8. Quest pins (hook now, content later)

Keep the shipped duck-type and widen it one notch (QUEST_ARCHITECTURE lands ~1000 quests later):

```gdscript
# quests.gd (group "quests") MAY implement — all optional, probed with has_method:
func map_pins(map_id: String) -> Array          # shipped: [{pos: Vector2, label: String}]
func zone_pins(zone_id: String) -> Array        # NEW same shape — zone-tier pins
func overview_pins() -> Array                   # NEW [{zone_id, kind: "main"|"side"|"event"}]
```
- ZONE tier: `zone_pins` (falls back to `map_pins`) → gold `!` exactly as today (`OverlayMarks`
  drawing moves into `MapMarks` unchanged).
- CONTINENT/WORLD tiers: `overview_pins` → a small `!` beside the zone anchor (main quests
  `BLOOD`-tinted, sides gold). No per-pin positions above zone scale — zones are the resolution.
- Minimap: unchanged (edge-clamped quest arrows are a later minimap iteration, noted §9).

---

## 9. Minimap polish (same-polish mandate)

The 64 px frame stays layer 8 top-right; three upgrades, all inside `minimap.gd`:

1. **Circular gothic bezel (option)**: `minimap_style: "square"|"round"` in `user://settings.cfg`
   (OPTIONS_SUITE Gameplay tab picks it up). Round mode: `MapView` gains an `_is_round` flag —
   `_draw()` builds a 32-seg circle polygon and draws the map texture through
   `draw_colored_polygon` UV-mapping (or simpler: draw as today then overpaint the corner mask in
   `BOX_BG` — GL-compat safe, zero shaders), player arrow unchanged; the square NinePatch rim is
   replaced by a generated **`assets/art/ui/minimap_bezel_round.png`** (74×74): iron-gall ring,
   four tiny corner diamonds at the cardinals, `BLOOD` gem at N — generated by a 30-line addition
   to the Python style kit so it matches the atlas ink.
2. **Zone-name plate**: a small parchment banner directly under the clock (`PARCHMENT` text,
   Alagard 9, dark halo) showing the current map's `display_name`; on `set_map` it types in with a
   0.4 s fade and gently fades to 60 % alpha after 4 s (always legible, never loud). Owner law
   served at a glance: name + clock + arrow = you always know where AND when you are.
3. **Ping animation**: `Minimap.ping(world_pos: Vector2, color := GOLD)` — three expanding rough
   rings (draw_arc, 0.7 s, ease-out) on the minimap AND on the open map tier at the mapped
   coordinates. Emitters: waystation discovery (via `TravelSystem.station_discovered`), quest
   updates (quests.gd may call it), zone discovery flourish (§6). Also player-initiated: clicking
   the minimap frame pings your own position (an MMO habit that costs nothing).

---

## 10. Scene / node structure

`minimap.gd` keeps the minimap frame + clock + name plate. The overlay half is EXTRACTED into
**`scripts/map_system.gd`** (`class_name MapSystem extends CanvasLayer`, layer 12, group
`"map_system"`), built in code like every UI in this repo:

```
MapSystem (CanvasLayer, layer 12, group "map_system")
├─ Dim (ColorRect, MOUSE_FILTER_STOP, black 0.55)
└─ MapPanel (Control, centered 560×340 in the 640×360 design space)
   ├─ Parchment (Panel, PARCH_BG — visible only as letterbox behind the sheet)
   ├─ Header (Panel, dark wood 24 px)
   │   ├─ Breadcrumb (Label, gold Alagard 12): "Draconia  ›  The Border  ›  The Iron Vein"
   │   └─ TierButtons (HBox right-aligned): [–] [+] parchment buttons (wheel equivalents)
   ├─ Viewport (Control, clip_contents, CONTENT = Rect2(12, 36, 536, 274))
   │   ├─ Sheet (TextureRect, EXPAND_IGNORE_SIZE) — current tier texture, aspect-fit
   │   ├─ VeilLayer (Control) — undiscovered-zone stencils (continent tier only, §6)
   │   ├─ RegionHits (Control) — invisible polygon hit areas (continent: zone footprints;
   │   │                          world: the two landmass hulls) + hover highlight draw
   │   ├─ MapMarks (Control, custom _draw) — player arrow/dot, waystation pins, route ink,
   │   │                          quest pins, ping rings  (OverlayMarks, promoted)
   │   └─ TravelStrip (Panel, hidden) — fast-travel confirm footer (§7)
   └─ Hint (Label): "[M] close · [wheel] zoom · [click] enter region"
```

State machine: `enum Tier { ZONE, CONTINENT, WORLD }` + `_focus_zone: String` (whose leaf the
zone tier shows) + `_focus_continent: int`. Textures load lazily
(`assets/art/maps/zones/<id>.png` via the existing `_load_map_texture` raw-PNG fallback) and an
LRU of 3 zone leaves stays resident (leaves are ~1.5 MB; world+continent sheets stay loaded while
the panel is open, freed on close — 60 FPS law untouched: the map only redraws `MapMarks` while
open, `_process` early-outs when hidden).

### Zoom & navigation UX
- **M** opens at ZONE tier, player-centered, arrow pulsing (0.5 s triple-ring ping on open — the
  law made visible). **M/Esc** close (Esc precedence via `is_world_map_open()` exactly as today).
- **Wheel up / [+] / double-click a region**: zoom in one tier. From WORLD, clicking a landmass
  hull focuses that continent; from CONTINENT, clicking a **discovered** footprint opens its leaf;
  clicking an undiscovered footprint nudges a faint `uncharted` label at the cursor (0.8 s fade) —
  no leaf for unearned pages.
- **Wheel down / [–] / right-click**: zoom out one tier (ZONE→CONTINENT of that zone→WORLD).
- **Hover** (continent tier): footprint fills with a 6 % `INK_FAINT` wash + name label brightens;
  cursor over a pin shows its name scroll.
- **Tier transition**: 0.18 s — outgoing sheet scales toward the clicked anchor (1.0→1.12 in,
  1.0→0.92 out) with a crossfade. No scrolling INSIDE a tier in v1 (each sheet aspect-fits whole);
  a pan-when-zoomed iteration is explicitly deferred to the next map pass (iterate-forever law).
- **Keyboard**: arrows step focus between discovered zones along `ROUTES` adjacency; Enter opens.

---

## 11. Integration points (exact)

1. **`main.gd`** `_bootstrap_world()`: `add_child(MapSystem.new())` right after the Minimap.
   `change_map()` additions (one call site):
   ```gdscript
   var ms: Node = get_tree().get_first_node_in_group("map_system")
   if ms != null:
       ms.call("set_zone", map_id, info.bounds)   # also marks map_id discovered
   ```
   `set_zone` re-anchors all three tiers and rebuilds veils if a discovery happened.
2. **`minimap.gd`**: `_build_overlay/_layout_overlay_map/_rebuild_district_labels/OverlayMarks`
   and the M-key handling move to `map_system.gd` (DISTRICTS labels become zone-leaf generator
   input for town; the runtime label path is deleted). Minimap keeps `set_map` (frame only) and
   gains `ping()`, the name plate, and the round-bezel option (§9). `is_world_map_open()` is
   re-exported by Minimap delegating to MapSystem so `pause_menu.gd` needs no change.
3. **`save_system.gd`**: persist/restore `"discovered_maps"` (MapSystem `save_state()/load_state()`
   mirroring TravelSystem's shape). New game seeds `["town", "wilderness"]`.
4. **`travel_system.gd`**: add `station_ids()`; MapSystem connects `station_discovered` →
   repaint pins + `Minimap.ping(station_pos)`.
5. **`quests.gd`** (when QUEST_ARCHITECTURE lands): implement §8 probes; zero map-side changes.
6. **`project.godot`**: nothing — `map` action exists; no new inputs beyond wheel/clicks the
   overlay consumes itself.
7. **Tools pipeline** (per zone batch, appended to the WORLD_PLAN batch checklist):
   `dump_zone_defs.gd → zone_defs.json → zone_map_gen.py → leaves` + retune
   `map_anchors.json` footprints for the new zones → `map_gen.py` v3 re-emits continent sheets.

---

## 12. Build order & acceptance

**Stage 1 — generators** (pure Python + one dump script; no game risk):
`map_style.py` refactor → `dump_zone_defs.gd` → `zone_map_gen.py` → 8 zone leaves + town/wilderness
anchors → `map_gen.py` v3 continent sheets + veils + `map_anchors.json`.
*Accept*: every built zone has a leaf whose roads/rivers/landmarks visibly match a play-through
screenshot; all sheets share the v2 ink language side-by-side.

**Stage 2 — MapSystem overlay**: extraction from minimap.gd → tier state machine → coordinate
chain (§5) → zoom UX → veils/discovery persistence.
*Accept*: M anywhere in the 10 maps shows the correct leaf with the arrow on your position; wheel
out twice reaches the world chart with your ember dot lit and moving as you walk; undiscovered
zones are blank vellum + name; reload preserves discovery.

**Stage 3 — pins & travel**: waystation pins/states, route ink, TravelStrip fast travel, quest
probes wired dormant.
*Accept*: discover Bent Oar + Vetka Square on foot → both pins lit, route inked, click → coach
ride with fade + autosave; undiscovered stations invisible.

**Stage 4 — minimap polish**: round bezel option + name plate + ping; OPTIONS_SUITE row.
*Accept*: style toggles live without restart; discovery pings fire on minimap and open map.

**Mandate check**: position always known (arrow/dot every tier, minimap plate + clock) ✅ · zoom
zone↔continent↔world (three tiers, wheel/buttons/click) ✅ · parchment masterpiece, iterate
forever (same ink kit; deferred pan/label passes named) ✅ · minimap same polish (§9) ✅ ·
WoW travel law respected (discovered stations + route graph only) ✅ · 60 FPS (static textures,
marks-only redraw, lazy LRU) ✅.
