# LEARNED_PRINCIPLES — Zone Painting Synthesis

> **DRAFT — review-gated by Fable before entering the Painting Bible.** Deduped synthesis of six research passes (Graveyard Keeper, Stardew/Witchbrook, Darkest Dungeon/Diablo 2, Eastward, Godot 4 technique, environmental storytelling). Sections and bullets ordered by leverage across our 41 zones.

**Highest leverage overall:** one-hue-per-zone palette discipline · S-curve roads with the perceived-event 40s rule · density gradients + fractal clusters · light-as-promise budget · three-beat vignette grammar.

## Ground

- **One hue family per zone, one reserved accent.** Every `_PALETTES` entry's tint/tree_tint/dusk_tint sits in a single family (bog grey-green, blestem violet-grey, volcanic ash-brown); exactly one complementary accent is reserved for lights and story props — never two accent hues in one screen. *(Bourassa, GameSpot "Gothic Sensibilities of DD")*
- **Ban dead gray and pure black in fills.** Warm every dark toward parchment: shift pit/void fills to ~(0.07,0.05,0.03), bias all biome tints 3–5% yellow/red so the Necromancer-sheet anchor reads "old manuscript," not concrete. *(Bourassa, GameSpot)*
- **Desaturate the ground, never the actors.** Biome tints mute terrain and vegetation only; interactables, NPCs, and story props keep full saturation so they pop off the muted field. *(D3 art-controversy — Lee/Wilson, Shacknews)*
- **Zone identity comes from grading shared assets, not new assets.** GK ships one sprite set + 10 LUTs per hour AND per zone: make every biome's (day tint, dusk_tint) pair deliberately distinct, keep DAY warm even in gothic zones, tint deco/landmark props per zone, and hue-shift light colors per biome (copper-orange in Iron Vein, cold green in bog). *(Cherkasov, GK graphics devblog, gamedeveloper.com)*
- **Seasons are a palette layer over fixed geometry, ramped not flipped.** Per-season sub-dicts in `_PALETTES` (Stardew's seasonal tilesheet swap); decor density and dusk_tint lerp across the season toward a festival peak; seasonal decor attaches to fixtures at fixed offsets (garland on lantern at (0,−40), snow cap on well) — never free-scattered. *(Stardew Wiki Modding:Maps; Witchbrook winter/simulation devblogs)*
- **Ground never reads flat, and stains have causes.** Keep `_ground_breakup` blob alpha ≤0.2 at z −9; make decals context-aware (rust/soot inside forge/crane keep_clears, moss under tree clusters); add a slow multiply-blend cloud-shadow layer (alpha ~0.12). *(SLYNYRD Pixelblog 20/43; GCORES 140317)*
- **Engine guardrails:** ground/road TileMapLayers never y-sorted (PR #73813: 60→800 fps), `rendering_quadrant_size = 32`; dual-grid 16-tile blending for procedural road/ground edges instead of Godot's 47-tile terrain solver. *(Godot PR #73813 + docs; jess::codes dual-grid)*

## Roads

- **Ban the straight line.** Every roads[] polyline gets ≥3 interior waypoints, alternating ±80–160px lateral offsets, bearing kinks of 20–40° every 400–700px, final segment aimed within ~150px of its destination; gentle wide bends in safe biomes, sharp >45° bends in hostile ones. *(Piaskiewicz, "Composition in Level Design"; Bellard, GDC 2019; Pointnthink on DD expressionism)*
- **40-second rule counts what is PERCEIVED.** Extend `_validate_forty_second_rule` anchors with ambient_spawns and road-sample points every ~800px (worn road + tufts is an event); require a landmark or vignette per 15–20s of road; resource landmarks ≤2 screens from a road; shrink any zone def that can't fill the quota — GK's most-cited failure is empty sprawl. *(Ochman, noclip Witcher 3 doc; Gaming Nexus GK review)*
- **Tease, then deliver.** The player sees the next landmark 15–20s before the road reaches it — a river polyline or rocky keep_clear forces the detour so the payoff is glimpsed, then earned. *(MY.GAMES "Follow the breadcrumbs"; Erdtree reward-and-denial)*
- **Roads are NPC rails.** Every inhabited landmark pos sits within ~150px of a road vertex (add 2-point spurs); NPC patrol paths reuse the same polylines so trodden roads and visible life coincide. *(wckdy Stardew villager paths; Witchbrook simulation devblog)*
- **Every exit is a built gateway and a stark first shot.** Terminate a polyline inside each border gap, pair it with sign + two lit lanterns; compose the entrance screen as the zone's highest-contrast statement — dark verticals framing the gap, one warm light, dominant hue declared before any enemy. *(Stardew Wiki; Witchbrook "Back to School" white bridge; Bourassa)*
- **Bridges where roads cross rivers; a broken_bridge variant is data-only progression gating.** *(Stardew Wiki beach bridge)*
- **Breadcrumb the final approach:** 3–5 instances of one lore-themed prop (cairns, bone piles, copper pans) at 150–250px intervals flanking the last road segment before each landmark; keep a ≥64px clear corridor from road edge to every landmark's front face. *(MY.GAMES; Steam GK layout culture)*

## Clusters & Density

- **Density is a gradient — the Witchbrook density bar.** `density_rings` in zone defs: ~0.2× vegetation near the hub, 1.0 mid-zone, 1.4–1.6× in the outer 25–30% ring; plus a doubled-chance ring 96–128px outside each keep_clear rect so clearings read as rooms with vegetation walls. *(Witchbrook Mossport map reveal; GK refugee-camp clearing, Neoseeker)*
- **Asymmetric fractal clusters, never scatter or rows.** Seed ~40% of trees, spawn 3/5 companions at 20–60px offsets with 1.0/0.7/0.45 scale falloff and flips; auto-jitter any deco without explicit values (scale 0.92–1.08, tint ±5%); lint identical tex within 600px — players notice repeated clutter before repeated buildings. *(Level Design Book env-art; Burgess & Purkeypile, GDC 2013)*
- **Tangent ban:** sprites either overlap >25% of width or separate by >20px of ground; grow building keep_clears ~44px so trees never kiss rooflines. *(Bellard, GDC 2019)*
- **Slot grammar for dressing hubs:** snap deco to a 64px sub-grid on the keep_clear PERIMETER — L-shapes at rect corners, lit lantern at path corners, pairs flanking entrances, never rows through the middle. *(GK Wiki graveyard 2×2 decor slots)*
- **Negative space is a placed asset.** One authored quiet-quarter rect per zone (breakup + sway + weather only, validator-exempt, no creature areas) plus 2–3 calm clearing rects so clusters never tile wall-to-wall. *(Level Design Book pacing; GDC "The Importance of Nothing")*
- **POI diversity beats density:** never two same-type set-pieces consecutively along a road without an occluder between; rotate habitation → ritual → nature → wreckage categories. *(MY.GAMES POI diversity; RE Village)*
- **Link props into worked places:** any cluster of 3+ props gets one physical connector — sagging rope/chain catenary (gallows-rope between gateposts, bell-rope, gutter pipe ending in a drip bucket). *(Eastward's Kowloon wires — Nintendo/IGF interviews)*
- **Buy density with verticality + engine hygiene:** mix prop heights, route roads north of tall landmarks so the player slips behind trunks; sort origin at the FOOT (offset texture up); one shared sway ShaderMaterial, y-weighted amplitude, world-pos phase hash, player-proximity bend; ground-hugging tufts become per-chunk MultiMeshInstance2D; coarse 4-point CCW occluders on trunk bases only. *(Pixpil, Game Developer interview; Godot docs; Cherkasov)*

## Light

- **Light only what canonically burns — every light is a promise.** PointLight2D attaches solely to functional landmarks (waystation fire, forge, tavern, quest stones); at night the zone's light set must equal its interaction set; dead vignettes (cold_camp, murder_scene) get NO light — the unlit hearth IS the story beat. *(Cherkasov, GK devblog; MY.GAMES; Sigman GDC 2016 torch-as-sanity)*
- **Hard budget — sun plus 3.** ~One warm light per 1280px screen, no point inside >3 light radii, lint >4 lights per screen; shadow_enabled opt-in on 3–5 lights per zone (hub only), SHADOW_FILTER_NONE for 32px pixel art. *(Cherkasov + HN thread; Godot 2D lights docs)*
- **Hierarchy of hued pools is the focus system:** per cluster, ONE dominant warm light + ≤2 dimmer hue-shifted accents; the brightest pool marks the landmark the 40s rule wants found; formalize energies — deco 0.3–0.5, narrative-live 0.18–0.35, quest-critical 0.55+. *(GameRes Eastward analysis)*
- **Cheap glows below the threshold:** deco entries <0.35 energy become additive-blend gradient sprites ("significantly faster"), ≥0.4 keep PointLight2D; anchor every light at the prop's foot line so the pool lands on the ground in front, not on the sprite's chest. *(Godot 2D lights docs; GK vertical falloff trick)*
- **Night is a blue-graded gradient, never a flat darken:** CanvasModulate driven by a gradient with a blue night key so each warm pool reads as a destination. *(Cherkasov)*
- **Fog is stacked bands that spare silhouettes:** 2–3 scrolling fog strips at staggered z, thinner toward frame top, so 96–128px hub landmarks poke through and weather re-dresses familiar zones instead of erasing them. *(Cherkasov; Rapid Reviews UK GK review)*

## Story

- **Three-beat grammar, staged along the approach vector.** Every vignette kind emits a ground trace (z −6 decal/prints), a y-sorted subject, and one small off-axis payload — trace on the road side, payload 60–120px deeper, so the scene reads in causal order as the player walks in; lint kinds emitting <3 roles. *(Worch & Smith, GDC 2010 "What Happened Here?")*
- **Absence sits where the life belonged.** Author vignettes as offsets of named landmarks — murder_scene by the farmhouse door, cold_camp beside the waystation it never reached; every entry names whose absence it marks. *(Diablo Wiki Tristram corpse placement; PC Gamer)*
- **Echo the zone's one-line premise.** Every vignette must be derivable from the zone's canon line (famine → full_granary); reject kinds that could paste into any zone; give each of the 41 defs a one-line real-world reference annotation that dictates its prop logic. *(Worch & Smith; Pixpil, Gamersky interview)*
- **Curiosity pairs with a closability signal:** life vignettes 60–120px off-road facing it; dark/lore vignettes ≥300px off-road behind vegetation, hooked by a cheap road-side question element (boot_prints, dropped cart) plus a faint light or print-trail proving the gap can be closed. *(Loewenstein 1994; wckdy Stardew paths; Witchbrook dev update)*
- **Aftermath only — never stage a verb the engine can't honor:** spent, cold, broken, sealed states (the courier's UNBROKEN seal is honest); live-affordance props route through the physics system or use broken variants. *(Worch & Smith "minimize disconnects")*
- **One culturally-legible anchor prop per scene** — the only element allowed to break the local palette (4×4px wax red on grey-brown is the template); support props inherit biome tint or Necromancer-sheet neutrals. *(Worch & Smith; Gaynor on Gone Home)*
- **Pair every ruin with current life, and nothing ships fully static:** each dead landmark gets one alive element in/adjacent to its keep_clear (lit lantern, tended plant, fresh prints — validator fails pure decay); every vignette contains one animated or emissive element (drip timer, ember flicker, sway cloth). *(Pixpil, Road to the IGF; 80.lv; GCORES 141712)*

## Capitals

- **One anchor per zone, never two hubs.** A single hub landmark ON the road polyline with 3–5 functional satellites within 300–500px; far-flung landmarks are lone discoverables (dolmen, bones), not second hubs. *(gamepressure GK map; GK Wiki Dead Horse tavern)*
- **The square is the shared road vertex.** Services within ~1 screen of the intersection of 2+ roads; keep the square's rect clear so festival vignettes can swap in without touching layout. *(Stardew Wiki Pelican Town; mygamerank)*
- **One headline silhouette, off-center, taller than everything.** `headline: true` per def: tallest sprite class (96–128px), own light, a road terminating at it, top z-indexed above canopy and fog; no two tall-class landmarks within 1000px — big silhouettes orient the mental map, small occluders hide surprises behind them. *(Cherkasov fog; Stardew Wizard's Tower; BotW CEDEC 2017 triangle rule)*
- **Mix 2–3 eras, unify with one emblem micro-prop:** per-region 32px motif (raven totem, rope knot, antler sign) pinned beside every major landmark; one ruined-era landmark per town implies history. *(Witchbrook "Back to School")*
- **Signposts at junctions and seam approaches** with per-zone iconography — diegetic wayfinding that tutorializes the ROUTES travel graph. *(GameRes Eastward signage)*
- **Compose the first screen at every seam by thirds:** dominant landmark ~1/3 in from the seam edge, counterpoint vignette on the opposite third, road exiting frame toward the next POI; verify with a 3×3 grid overlay screenshot per zone review. *(Bellard, GDC 2019 "Spatial Cinematography")*

## Caves & Dread Zones

- **Pooling black owns the perimeter; light lives in the middle.** `gloom` flag: low-alpha dark modulate ring 6–10 tiles deep at the map rim, fires toward the interior — walking to the seam walks into the dark. *(Bourassa, Dark RPGs interview)*
- **Space pools farther apart than their radius:** lit landmarks every 1200–2000px along the road (2–4 pool-widths of darkness between); enemy_spawns live only in the dark gaps — light = safe, dark = spawn territory. *(Kelly Johnson, Shacknews "Stay Awhile and Listen")*
- **Dark needs a bright counterpoint to read as dark:** lint any zone with tint luminance <0.5 lacking at least one warm light per screen-width — never ship flat dark with nothing to measure it against. *(D3 controversy, Shacknews/diablowiki)*
- **Overcast the sky, not just the sprites.** Dread wilderness pairs three def knobs: cold dusk_tint override (~0.6,0.6,0.7), persistent fog/drizzle weather, dead-wind ambience bed — prop tinting alone can't beat the green-grass safety signal. *(Brevik/Schaefer, Shacknews)*
- **Loneliness is a composition budget:** dread landmarks get a second falloff ring (~300px at 25% density) so the monolith stands in visibly empty ground; one hero landmark per screen, ≥1280px spacing. *(Bourassa "no landmarks within view")*
- **Render the ordinary as ravaged, crookedly:** 10–15% dead tree stock in every biome tree_set, a broken-variant prop family (drowned_fence idiom → broken_cart, leaning stones), tall thin dead trees at the rim as jagged sway silhouettes; no more than 2 same props on an axis-aligned line, per-instance jitter + occasional missing member. *(GameSpot DD; PC Gamer Blood Moor; Pointnthink expressionism)*
