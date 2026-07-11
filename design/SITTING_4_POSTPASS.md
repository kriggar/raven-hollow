# SITTING #4 — POST-PASS MACRO INSPECTION (2026-07-11, 40/41 zones; verifiers died at limit)

Grades: {'C': 1, 'D': 31, 'F': 8} | wallpaper still true: 38/40


## town — C (wallpaper=True)
one_image: YES — the fenced graveyard set piece at x665-1240, y440-1040: crooked fence, hooded mourner statue, wolf statue, open graves, and the clock embedded in a dead twisted tree; distinctive and screenshot-worthy. The plaza+fo
- CRITICAL: Ground reads as one flat olive field at macro — measured grass luminance sd is only 3.7 (NE open field x2700,y500) to 8.4 (SW x900,y1500); detail decals are ~1 tiny tuft per 100px, invisible zoomed out.
  fix: In zone_builder ground pass, add 2-3 grass tone variant tiles plus macro-scale dirt/clover/leaf-litter patches at 5-10% coverage with 100-300px blob sizes so tonal variation survives zoom-out; bias pa
- CRITICAL: The east road dead-ends in open grass ~70px short of the zone's only gate — the cobble band stops at x~3200 while the CULT gate mouth starts at x~3270, leaving a bare grass strip in front of the portcullis.
  fix: In zone_defs, snap the road_east endpoint to the gate anchor and extend paving through the arch to world x=2240 (zone edge) so the road actually runs gate-to-gate.
- MAJOR: No road reaches the west, north, or south zone edges; the south road fizzles into staggered single-cobble stubs ending in open grass short of the well, and the west path ends at a lone signpost stub — dead-ends in open ground.
  fix: If zone_defs declares south/west exits, route roads to those edges; otherwise terminate the south road ON the well/garden cluster (not 100px before it) and the west spur AT the graveyard gate so every
- MAJOR: NE quadrant is ~75% anchor-less dead space — a huge empty meadow between the north treeline and the smithy/manor, whose anchors hug the quadrant's bottom-left sliver.
  fix: In zone_builder, either pull the forest mask inward to shrink the field, or drop one story cluster there (shrine, hunter camp, standing stones, hay meadow with cart) sized ~200-300 world px.
- MAJOR: Confetti in the SW meadow: four orphan props (crate, brick stack, log, rock) scattered singly with no relationship — even sprinkle, not a story cluster.
  fix: In zone_defs prop pass, replace the singles with one composed cluster (e.g. abandoned woodcutter camp: stump + log pile + crate stack together) and leave the rest of the meadow honestly empty.
- MAJOR: The plaza is a razor-edged flat pale slab — a solid light-grey rectangle, the brightest thing on the map, dressed with only a fountain, two benches and one crate stack; at macro it reads as a debug rectangle.
  fix: In zone_builder, break the slab: mix 2-3 cobble tone variants, erode the corners/edges with grass intrusions, and add interior dressing (market spill, cracked flagstones, moss seams) so it reads as wo
- MINOR: Road texture decays into isolated single cobble tiles scattered in grass on the graveyard spur — reads as speckle, not a worn path, and the graveyard (the zone's best set piece) has no legible road link, its gate opening onto bare grass.
  fix: Give the graveyard spur a continuous 2-tile-wide worn-dirt-plus-cobble path in zone_defs, keeping cobble density >=70% along its spine.
- MINOR: East wall exists only as disconnected segments with walk-around grass gaps beside the gate tower, so the fortified gate reads unfinished and enforces nothing.
  fix: In zone_builder, run the wall segment continuously along the east edge for the gate's flank length, or replace the stubs with dense impassable treeline butted against the tower.
- MINOR: Skeleton NPCs idle in the open NW meadow far from any encounter context, reading like leftover spawner placement at macro.
  fix: In zone_defs spawn regions, tether skeleton spawns to the graveyard interior/perimeter where they tell a story, not to open grass.

## western_lowlands — D (wallpaper=True)
one_image: Closest candidate is the road/river crossing vignette at ~x1272,y1100 (lantern glow on the road, mausoleum grave, dead snags, shrine+barrels upstream at x1325,y845) — but the missing bridge and capsule river break the sh
- CRITICAL: The main east-west road has no bridge where it crosses the river — the river capsule is drawn over the road tiles, so the road visually dead-ends into water and resumes on the far bank.
  fix: Add a bridge prop/tile span at the road-river intersection in zone_builder and z-sort it above the water polyline; this is also the zone's natural hero composition.
- CRITICAL: The river is a debug stroke, not a river: uniform-width grey capsule with rounded end caps poking into out-of-bounds padding at both zone edges, flat fill with a single lighter center streak, hard dark outline, one sharp polyline kink, zero bank treatment (no 
  fix: Replace the stroked polyline with river autotile/painted water in zone_defs: vary width, add bank transition tiles plus reed/rock/dead-tree dressing along both shores, and clip the geometry at zone bo
- MAJOR: The road reads as a pale debug strip: razor-straight top and bottom edges for the entire zone width, flagstone chunks chopped mid-slab along the bottom edge, and it fails gate-to-gate — stopping ~50px of grass short of the west edge and ~40px short of the east
  fix: Rebuild in zone_builder as a worn dirt/cart path: dithered irregular edges, wheel-rut wear, slight meander, and extend both ends flush to the zone-edge gates.
- MAJOR: Zero secondary paths: every settlement floats on untouched grass with no path, trampled ground, or yard wear connecting it to the main road — the only road in the zone serves nothing.
  fix: Add spur paths from the main road to each cluster in zone_builder plus trampled-dirt underlay decals beneath yards and door thresholds.
- MAJOR: Tree confetti: single trees sprinkled at near-uniform density across the entire 7680x5120 with almost no copses (rare pairs at best) and no honest empty meadow — even sprinkle everywhere.
  fix: Change the zone_defs scatter to clustered distribution (clumps of 3-7 with shared canopy), clear buffers around settlements and along the road, and leave deliberate open meadow between clumps.
- MAJOR: Farmland biome with no farms: no crop fields, no tilled plots, no fenced pasture, no haystacks anywhere; the only agrarian signals are one barn with chickens and two orphan fence segments that enclose nothing — a random screen reads as generic olive grassland,
  fix: Add signature farmland set pieces in zone_builder: tilled crop plots with row texture around the barn and hamlet, completed fence enclosures with livestock, haystacks and a scarecrow — these double as
- MAJOR: NW quadrant is effectively anchor-empty: the region x355-1750, y33-1000 (~quarter of the zone) contains only confetti trees and a three-gravestone micro-plot; the nearest structure sits on the quadrant's inner boundary.
  fix: Place one real anchor (windmill, ruined farmstead, or fenced graveyard expanding the existing grave trio) around x900,y500 in zone_defs.
- MINOR: Ground breakup is a single low-contrast dark-smudge pass of the same olive hue plus micro-speckle that vanishes at distance — the macro read is one flat olive wallpaper with vignette dirt, no second ground material anywhere.
  fix: Add 2-3 ground material layers in zone_defs (dry-grass patches, exposed dirt, clover/weed tone shifts) with enough value contrast to survive zoom-out.
- MINOR: Micro-vignettes are pasted on raw grass with no ground treatment: grave trios, ruin pillars, and the roadside market all sit with no dirt/rubble underlay, reading as floating sprites.
  fix: Add underlay decals (dirt, rubble, worn grass) and small enclosures (low fence around graves) in zone_builder.
- MINOR: Orphan crates scattered as singles near the east road terminus with no cluster logic — prop confetti.
  fix: Consolidate into one story cluster (overturned cart / smuggler stockpile) beside the road end in zone_builder.

## vetka — D (wallpaper=False)
one_image: Closest candidate: the dark idol ringed by four stone cairns and a rock pile, with boars prowling and an NPC nearby, at ~x2765,y1530 — a genuine composed vignette. The lantern-lit crossroads (well + bench + glow + two ca
- MAJOR: Road network fails gate-to-gate: both road ends dead-end in open grass short of the zone edge — the west road stops ~3 tiles inside the map, the south road stops ~2 tiles above the bottom edge.
  fix: In zone_builder path defs, extend the W-road spline to the x=0 gate and the S-road to the y=4096 gate so slabs touch the zone boundary.
- MAJOR: No road serves the north or east edges at all — the entire east ~45% of the map is roadless, leaving the NE homestead, the lone grave, and the SE idol monument unconnected to the network.
  fix: Add at least one N or E gate road in zone_defs, routed past the homestead and idol so the L-shaped skeleton becomes a through-route.
- MAJOR: The E-W road reads as a pale razor-edged debug strip: perfectly straight top/bottom edges, repeating rectangular slab tile, no dirt fringe or wear, and a hard misaligned seam where two segments join offset by a full slab row with a visible tone shift.
  fix: Swap to the worn-path brush (irregular edge tiles, dirt blend layer under slabs, occasional missing/broken slab), and align the two path segments to one baseline in zone_builder.
- MAJOR: Confetti trees: single trees sprinkled at near-uniform density across the whole 5632x4096 world with almost no massed copses and no deliberate clearings — even sprinkle everywhere.
  fix: Rerun tree scatter in cluster mode: 5-8 copses of 8-15 trees with overlapping canopies, then clear the meadows between them to honest open space.
- MAJOR: Ground breakup relies solely on soft blurry dark decals; the base is one mustard grass tile with no second material (heather, dirt, mud, puddles) visible anywhere at macro, so the field between decals still reads flat (measured luminance std ~7.5 including pro
  fix: Add 2-3 macro-visible ground materials in zone_defs ground layers (heath patches, bare dirt around vignettes, mud along roads) instead of only shadow-blob decals.
- MAJOR: Zone identity is thin: the signature 'witch-moor' kit (open graves + campfire, cauldron circle, dark idol with cairns) exists in only ~4 tiny vignettes, so a random screen almost anywhere shows unidentifiable flat olive grass and a generic tree.
  fix: Repeat signature props (cairns, open graves, standing stones, heather) in zone_builder along roads and inside tree copses at 3-4x current density.
- MINOR: A tree and its shadow are rendered outside the zone bounds in the NW corner padding, with the shadow drawing as an opaque maroon blob over void.
  fix: Clamp prop placement to zone bounds in zone_builder scatter pass.
- MINOR: Three bare tan crate sprites float unanchored in open grass near the west road end, reading as leftover placement tests rather than a story cluster.
  fix: Attach them to a cart/roadside-camp vignette on the road shoulder, or delete them.
- MINOR: Two large anchor-free dead pockets: the NW corner region and the far-SE corner contain nothing but confetti trees for ~700px stretches, so anchors pass the quadrant test only barely, near quadrant centers.
  fix: Drop one small anchor per pocket (ruin, standing stone circle, bog pit) in zone_defs.

## famine_fields — D (wallpaper=True)
one_image: NONE. Closest candidate is the NE farm hamlet (x2250-2780, y540-960): four timber farmhouses plus an open barn with good sprite detail, but it floats on untouched grass with no road, yards, fences, or fields, so it reads
- CRITICAL: Ground is wallpaper: one exact RGB value (115,112,18) covers 52.7% of sampled ground (top-8 near-identical mustard tones = 77%), and the only breakup is ~15 formless airbrushed dark blobs (e.g. a ~350px-wide soot smudge at x1650-2050, y60-360) that read as sme
  fix: zone_builder ground pass: add 2-3 farmland ground materials (dead-crop plots, tilled-dirt rectangles, dry-grass patches) painted as hard-edged field shapes covering 25-40% of open ground; delete or re
- CRITICAL: Road fails every road law: a single east-west flagstone strip (y~1105-1145) that is razor-edged, uniform-width, and perfectly straight across the entire 7168px world (debug-strip look; reads as a grey wall at macro), stops ~120 world px short of the west edge 
  fix: zone_defs: reroute as a worn dirt path with curvature and noisy edges, extend to the west gate, add spur paths to hamlet/homestead/cemetery/windmill; add a N-S path if north/south gates exist.
- MAJOR: Tree scatter is confetti: near-uniform one-tree-per-50-100px density across the whole zone with no copses and no honest empty space, plus strays — a tree planted directly on the road pavement (x~620, y~1095), a tree straddling the world boundary at the NW corn
  fix: zone_builder scatter pass: replace uniform density with 5-8 deliberate tree clusters and keep the starved open fields genuinely empty; add road/boundary exclusion masks to the scatter; group the crate
- MAJOR: SE quadrant has no macro-readable anchor: its largest features are a knee-high stone column (x~2215, y~1305), a well (x~2530, y~1400), and three coffin-planters (x~2985, y~1435) — all invisible at zoom-out, leaving the quadrant reading as empty grass.
  fix: zone_defs: add one building-scale anchor to the SE (ruined barn, plague pit, or burnt farmstead) and promote the column/well into its supporting cluster.
- MAJOR: Zone identity is carried by palette alone: a farmland zone with zero visible fields — no crop plots, field fences, haystacks, or scarecrows anywhere at macro — and healthy green trees; the famine story exists only in tiny vignettes (windmill + grain baskets x2
  fix: zone_defs/zone_builder: lay out actual withered field plots with fence lines and scarecrows as the zone's signature repeated element; swap a percentage of tree sprites to dead/bare variants to sell bl
- MAJOR: Every anchor floats on wallpaper: the NE hamlet's five buildings sit directly on untouched grass with no yards, dirt aprons, fences, or paths between doors; the lone SW house (x1490-1560, y1290-1400) and the mid-left homestead (x1360-1500, y930-1030, only ~70p
  fix: zone_builder: stamp dirt/trampled-grass aprons under each building, run worn paths door-to-door and to the main road, and add yard clutter (fences, woodpiles, pens) around each anchor.
- MINOR: Prop rendered out of bounds: a tree at the map's NW corner straddles the world boundary with its canopy drawn over the grey out-of-bounds padding.
  fix: zone_builder: clamp scatter placement to the world rect inset by each prop's half-width.
- MINOR: Copy-paste gravestone stamps: near-identical tidy gravestone rows/grids dropped on bare grass with no fence, dirt, or enclosure in at least four places, reading as a repeated brush stamp rather than burial sites.
  fix: zone_defs: vary each cemetery's layout and size, enclose with fence/wall fragments and a dirt ground patch, and tie one into the famine narrative as a mass grave.
- MINOR: Unresolved dithered grey speckle squares (withered-patch decals?) read as rendering artifacts at multiple spots, e.g. near the windmill and in the NE corner.
  fix: zone_builder: replace the dithered square decal with an irregular-silhouette withered-grass texture, or remove.

## angel_wings — D (wallpaper=True)
one_image: NONE — the closest attempt is the crossroads market square (six stone-ringed garden beds, a small grey statue, five lit awning stalls, image x1990-2270, y990-1190), but the beds are empty rings and the stalls float on ba
- CRITICAL: Capital fails the CITY read completely: ~35-40 buildings scattered as farm hamlets over the whole 10240x8192 world, densest cluster is 6 huts, and the 'urban core' at the central crossroads is six empty stone garden beds, five stalls and one small statue on ba
  fix: Mirror blestem/sangeroasa density conventions in zone_defs: multi-row street-fronting houses along both road axes for ~2000 world px around the crossroads, paved plaza under the square, wall/gate post
- CRITICAL: All three stone paths dead-end in open grass at BOTH ends and none reaches a zone edge: horizontal path spans x965 to x3105 at y~1085 (map edges x611/x3228), west vertical path y380-y1807 at x~1717, east vertical path y485-y1685 at x~2254.
  fix: Extend path polylines in zone_defs gate-to-gate (zone edges) and terminate interior spurs at landmarks (manor door, cemetery, hamlets), never mid-field.
- CRITICAL: The only edge-to-edge artery (the N-S blue-grey capsule) reads as a debug Line2D, not a worn road: perfectly uniform width, razor dark outline, rounded end caps, and at macro it is illegible whether it is a road or a river ([75,81,82] slate fill).
  fix: In zone_builder give it worn-path treatment (width jitter, ragged edges, rut tones, dirt blending) or, if it is a river, add bank decals/reeds so identity reads; clip the polyline to world bounds.
- MAJOR: Ground reads as one flat mustard-olive field at macro: the only breakup is sparse soft airbrushed dark blobs and uniform tree speckle; farmland biome shows zero tilled fields, crop rows, fences, or plot boundaries anywhere on the map.
  fix: Add mid-scale variation in the zone_builder ground pass: tilled-plot and crop-row decal fields, mowed patches, dirt aprons under building clusters, field-boundary fence lines.
- MAJOR: A house renders near-solid black while every neighbor is normally lit — at macro it reads as a hole/missing-texture blob, not a building.
  fix: Fix the modulate/texture on that landmark in zone_defs; if it is meant to be a burnt house, use a readable charred sprite with visible edge detail.
- MAJOR: Tree placement is uniform confetti: identical single trees sprinkled at even density across the entire map with no groves, hedgerows, or orchard rows, so no honest open space reads either.
  fix: Rebucket tree scatter in zone_builder into clustered groves and field-edge lines (orchard rows fit the farmland biome), leaving genuinely clean fields between.
- MAJOR: Zone identity is mute: nothing says 'Angel Wings' at macro — the probable angel statue at the square is ~35px and unreadable, and the palette/props are generic farmland identical to any other farmland zone.
  fix: Scale the signature up: one or more large angel monuments readable at macro, white-stone accent paving/props around the core, wing-motif landmark silhouettes.
- MAJOR: SW quadrant has no distinct anchor — only generic hut clusters and a ~20px shrine with two pillars; the entire bottom band of the map is near-empty grass.
  fix: Place a real SW landmark in zone_defs (windmill, barn complex, or an angel monument) and one bottom-band point of interest near the S road gate.
- MINOR: Orphan prop patches float on bare grass: a 7-gravestone patch with no fence, dirt, or chapel, and a second 4-stone cemetery with statue that also sits on raw ground next to a path dead-end.
  fix: Give each cemetery a dirt/ground apron and fence in the landmark composite, and connect it to the path network.
- MINOR: Untextured flat colored squares (placeholder quads) float on the grass in three spots — raw ColorRects with no sprite.
  fix: Find the ColorRect-only props in the zone_builder landmark composites and assign their intended sprites.
- MINOR: Path geometry glitches at ends: the horizontal path's west end has a doubled, vertically offset strip stack, and the east vertical path's final tile jogs half a width to the right.
  fix: Align polyline segment endpoints/tiling origin in the zone_builder path pass so end segments share one axis.

## stonepath — D (wallpaper=True)
one_image: The central crossroads at ~x1915,y1100: lit shrine with warm glow, market stall with sacks, statue trio below (x1930-1990,y1280-1320), and gravestone rows flanking the crossing. It is the only deliberately composed momen
- CRITICAL: Roads fail gate-to-gate on ALL FOUR arms — every arm dead-ends in open grass short of the zone edge (north arm stops ~315 world px short with trees beyond the terminus; west ~150-220; east ~100; south ~65).
  fix: In zone_defs road spec, extend each arm's run to the actual zone boundary/gate coordinates so the last road tile touches the edge; validate_travel-style check that road endpoints == gate positions.
- CRITICAL: Wallpaper ground: ~96% of the map sits within ~5 RGB points of one olive (106,105,17); macro-downsampled luminance stdev is only 4.7. Zoomed out, the zone is one flat pea-green sheet with a few faint shadow blobs.
  fix: Add a macro tonal pass in zone_builder: 2-3 large grass-tone patches, dirt aprons under the graves/camp/crossroads, darker ground under tree groups, and denser scatter decals — variation must survive 
- MAJOR: Roads are razor-edged debug strips: constant 25-26 px width over the full ~2700 px runs, perfectly straight, hard slab edge butting directly into grass with zero wear, fringe, or width variation.
  fix: Road pass in zone_builder: dirt-fringe decals along edges, occasional worn/widened patches, slight centerline jitter per segment so it reads as a used path, not a painted stripe.
- MAJOR: Road segments are misaligned: the horizontal arm jogs ~13 px (~32 world px) north where east half (y1080-1104) meets west half (y1093-1118); the vertical arm has doubled/offset columns near its north end (width balloons 25→73 px across y150-300) and a half-wid
  fix: Snap every segment of an arm to a single centerline constant in zone_defs; the builder should derive segment x/y from one axis value instead of per-segment offsets.
- MAJOR: Tree confetti: single trees sprinkled at near-uniform density across the entire zone — no groves, no clearings, no forest edge, identical rhythm in all four quadrants.
  fix: Replace uniform scatter with cluster-seeded placement (Poisson around grove seeds): mass ~60-70% of trees into 5-8 groves with darker ground beneath, leave honest open meadow between them.
- MAJOR: Anchor rubber-stamping: three of four quadrants use the IDENTICAL oversized grave sprite (headstone + dirt bed) as their anchor; the only other candidates are single small sprites (obelisk+cairn NE, tiny dark hut NW, campfire SW). No building-scale anchor exis
  fix: Differentiate quadrant anchors in zone_defs — e.g. ruined toll-house/waystation, gallows, stone circle — and scale at least one into a true landmark composite in zone_builder.
- MINOR: Bare peach/orange untextured squares floating alone in open grass west of the crossroads — they read as missing-texture placeholder quads at every zoom level.
  fix: Find the prop entry in zone_defs (crates/clay?) and assign its real sprite, or delete the placements.
- MINOR: Unreadable prop grid: 2 rows x 6 identical small brown ticks in a perfect grid — fence posts without a fence or debug plot markers; means nothing at any distance.
  fix: Replace with a readable prop (fence line with rails, planted plot composite) or remove; if it is a fence landmark, the builder is dropping the rail sprites.
- MINOR: Gravestone groups near the crossroads are stamped in dead-straight, evenly spaced rows parallel to the roads (5-stone row, 6-stone row, 4-stone row NE) — reads as copy-paste, not a burial ground.
  fix: Jitter positions and spacing, vary headstone sprites, break rows into 2-3 stone clumps with uneven gaps in the zone_defs placements.
- MINOR: Soft shadow-blob decals render ON TOP of the road, visually severing it — near x2600 the horizontal arm disappears entirely under a blob at macro scale.
  fix: In zone_builder, draw the cloud-shadow/vignette layer beneath road tiles, or exclude road bounds from blob placement.

## riverfork — D (wallpaper=True)
one_image: NONE. Closest candidate is the roadside farmstead/market strip at ~(1500-2400, 800-1050) — tavern, cottage, stalls, well, hay cart strung along the road bend — but it is a loose linear scatter with no composed focal poin
- CRITICAL: Zone is named Riverfork but contains no river and no fork — the only water evidence is two rowboats beached on plain grass beside the road, so the zone's entire identity is missing.
  fix: zone_defs: declare the river+fork as a required signature feature; zone_builder: carve a forking river (e.g. enter north edge, fork near the road kink at ~(2230,1120), exit west and south), add a ford
- CRITICAL: Ground reads as one flat mustard-olive wallpaper at macro — only variation is sub-pixel speckle and large soft feathered dark blobs that read as lens smudges, not material; no dirt, no tilled fields, no meadow tone shifts despite farmland biome.
  fix: zone_builder ground pass: add 10-20% coverage of hard-edged secondary materials (tilled soil plots near the farmsteads, dirt scuffs along the road, dry-grass patches); replace the soft-brush smudge bl
- MAJOR: Road is a debug strip, not a worn path: uniform-width pale grey asphalt ribbon with anti-aliased gradient edges, dark outline, and rounded pill endcaps visible at both gates; zero wear, ruts, or edge breakup along its ~2800px length, and the grey palette clash
  fix: zone_builder road pass: swap to worn dirt/gravel material with irregular eroded edges and wheel ruts; suppress endcap rounding so the road visibly runs off-map at gates.
- MAJOR: Only one gate axis exists (west-east road); no north or south connection at all, and the road's mid kink is a bend, not a fork — ironic for a zone called Riverfork.
  fix: zone_defs: add at least one north or south gate; zone_builder: branch a secondary path off the existing kink at ~(2230,1120) to that edge.
- MAJOR: Trees and bushes are an even Poisson confetti sprinkle across the entire map — density is identical in every 600px window, with no copses, hedgerows, windbreaks, or honest empty meadow.
  fix: zone_builder scatter pass: consolidate into 4-6 story clusters (copse, hedgerow lines along field edges, lone landmark tree) and clear the space between to zero.
- MAJOR: Bottom ~40% of the map is anchor-dead: no building or monument below y~1250; SW quadrant's only content is a 3-bedroll campfire and SE's off-road content is a small cauldron camp — both invisible at macro scale.
  fix: zone_defs: add one real anchor per southern quadrant — e.g. upgrade the SW campfire into a wayfarer/bandit camp with tents and cart, and grow the SE cauldron into a witch hut with garden.
- MAJOR: Long pale stone slab strip runs parallel to the road with mechanical alternating tiles, razor edges, and random stepped notches; it crosses under the road and dies mid-field at both ends — reads as unfinished placeholder paving, not a wall or fence.
  fix: zone_builder: replace with a proper stone-wall/fence sprite set (posts, capstones, a gate where the road passes through) and terminate ends at buildings or corner posts, never mid-grass.
- MAJOR: Flat solid-color untextured quads (tan/brown/grey squares) float in open grass near the east gate — they read as missing-texture placeholder props and are visible even at macro zoom.
  fix: audit prop ids in zone_defs near the east gate; re-point to real crate/rock sprites or delete.
- MINOR: Identical open-grave stamp (headstone + dirt pit + two stones) is copy-pasted at multiple spots, plus loose headstone groups, all floating context-free in open grass — reads as grave confetti rather than burial sites.
  fix: zone_builder: vary each grave layout and ground it with context (broken fence, dead tree, dirt spur off the road), or consolidate into one roadside burial plot.
- MINOR: A tree is placed outside the map bounds, rendering in the grey out-of-bounds padding at the top-left corner, and its shadow renders as a dark maroon blob instead of a shadow tone.
  fix: zone_builder: clamp scatter placement to zone bounds; fix shadow tint on that tree sprite.
- MINOR: A bright white-striped panel beside the road is the single brightest object on the map and pulls the eye harder than any anchor at macro scale.
  fix: tone down the sprite's whites toward the zone palette or replace with a weathered notice-board variant.

## copper_wells — D (wallpaper=True)
one_image: NONE. Closest candidate is the center crossroads at img (1500-2100, 850-1150): signpost + lantern glow at (1905,1040), campfire sparks at (1640-1675,1057), winch wells, cart, log pile and boars — but the props are strewn
- CRITICAL: Entire ground reads as one flat olive-mustard field at macro — measured grass luminance std is ~4 on mean 86 (<5% variation); the only breakup is faint soft grey smudge blobs that read as unfinished shadow decals, with zero dirt/peat/heather/copper-stain patch
  fix: In zone_builder ground pass add a macro breakup layer for the moor biome: large low-frequency peat/dry-grass tonal patches plus copper-oxide stain decals radiating from each well prop; raise decal con
- MAJOR: Roads are pale razor-edged rectangular slab strips — constant width, dead straight (the E road runs ~1350 img px / ~3000 world px with zero curve, x1950-3302 at y~1075), right-angle doglegs, high contrast against the grass, no dirt fringe or wear; exactly the 
  fix: Swap the road brush in zone_defs from stone-slab to worn_dirt/packed-earth with ragged alpha edges, grass overgrowth tufts along borders, and add per-segment curvature jitter to the road polylines.
- MAJOR: The entire western half of the zone (x523-1860, ~50% of the map) has no road at all — the horizontal road only runs from the center junction east, so no west gate is served and the N-S road is the sole spine.
  fix: Extend the E-W road polyline in zone_defs from the junction (1905,1060) to the west edge x523, routing it past the NW three-shaft plot at (930,455) or the SW graves to give it story.
- MAJOR: Tree placement is classic confetti: single trees sprinkled at near-uniform density across the entire zone with almost no multi-tree groves and no honest open meadows — density looks identical in every quadrant.
  fix: Replace uniform scatter in zone_builder with poisson-cluster placement: groves of 3-7 trees with overlapping canopies, and deliberately cleared meadows around the wells cluster and graveyards.
- MAJOR: NW quadrant interior is effectively anchorless — its only feature is a tiny 3-plot framed-shaft prop at (905-960, 440-470); the wells/workshop cluster credited to this quadrant sits at the extreme map center (1520-1900, 860-1130), leaving ~1300x900 img px (~29
  fix: Add a real anchor in zone_defs to the NW interior (~x1000,y450 img): promote the three shaft plots into a derelict copper-mine head with winch tower, spoil heap, and a spur path.
- MAJOR: Zone identity collapses outside one screen: the well/copper theme exists only in the center cluster (winch wells, cauldron, vat at 1520-1900,860-1130) and the shrine (2070,1470); any random screen elsewhere is anonymous olive moor indistinguishable from any ot
  fix: Distribute signature props zone-wide in zone_defs: 1-2 lone winch wells or dry well-heads per quadrant with copper-stain ground decals, so every screen answers 'Copper Wells'.
- MINOR: The N-S road stops short of both gates: top end at y76 vs map edge y32 (~3 tiles of grass before the gate) and bottom end at y2098 vs edge y2127 (~2 tiles), so it does not run gate-to-gate.
  fix: Extend the road polyline endpoints in zone_defs to the actual zone boundary rows so slabs touch the gate tiles.
- MINOR: A full tree sprite with an opaque dark shadow blob is placed outside the world bounds, rendering in the grey out-of-bounds padding at the top-left corner.
  fix: Clamp prop placement in zone_builder to world bounds, or add a margin check that rejects props whose sprite rect exits the zone rect.
- MINOR: The two NE cabins are the same house sprite duplicated (one mirrored), placed diagonally 200 px apart with no yard, fence, path, or connective props — reads as copy-paste, not a homestead.
  fix: Vary one cabin variant in zone_defs and bind them with a homestead micro-cluster: dirt yard decal, fence segments, and a spur path to the E road at y~1060.
- MINOR: SW graveyard is a mechanical lineup: 5 headstones in a perfectly straight, evenly spaced row with two coffins beneath, floating on plain grass with no fence, dirt, or path connection.
  fix: Use a graveyard cluster template in zone_builder: jittered stone rows on a dirt/dead-grass patch, low fence or wall fragments, and a footpath spur toward the S road.
- MINOR: A uniform 2x6 grid of small dark rectangular ticks sits below the glowing shrine — evenly spaced identical marks that read as a debug/placeholder grid rather than votive props at this scale.
  fix: Replace the grid stamp with jittered candle/offering sprites of mixed sizes, some lit to feed the shrine's existing glow.

## iron_vein — D (wallpaper=True)
one_image: Closest candidate: the half-timbered foundry at ~(1900,780) — smelter cauldron with ember glow, barrels, campfire, gravel apron and a lantern signpost on the slab path below it. It is the only deliberate composition in t
- CRITICAL: Tree/bush layer is uniform confetti across the entire zone — single trees and tufts every ~150-250px with no copses, no clearings, no density gradient, and no honest empty space anywhere.
  fix: In zone_builder scatter pass, replace uniform random scatter with clustered placement (Poisson cluster centers, 5-12 trees per copse, 150-300 world-px radius), define 6-10 named copses in zone_defs, a
- CRITICAL: Ground is wallpaper: one cracked-slab brown dirt motif tiles the entire 6656x4608 world; measured block-mean luminance std across a 12x8 grid is 1.82 — no macro tonal zoning, no wet/dark/stained regions, reads as a single flat brown field zoomed out.
  fix: In zone_defs ground layers add 3-4 macro patches with organic borders — dark wet bog mud, rust/ore-stained earth radiating from the vein, pale trampled ground around the forge — plus per-region tile t
- MAJOR: Zone identity fails both halves of its name: biome=bog but there is zero water, reeds, or mud sheen anywhere, and 'Iron Vein' has no ore signature outside the one forge — no exposed veins, minecarts, slag heaps, or pit heads; a random screen reads as generic b
  fix: In zone_defs add signature prop sets: organic-shaped bog pools (replace the rectangular moss decals), ore outcrop rocks with rust streaks, slag piles and an abandoned minecart or two repeated along th
- MAJOR: Main road reads as a vector debug strip, not a worn path: uniform-width dark band with razor edges and a smooth center-lane gradient, perfectly straight polyline segments, and stadium-style rounded end caps where it meets both map edges.
  fix: In zone_builder road brush: worn-path rendering with ragged/eroded edges, width jitter, wheel ruts and breakup patches; square the road off flush at gate edges instead of capsule caps.
- MAJOR: A second parallel E-W stone-slab path duplicates the main road ~200px to the north, dead-ends in open ground short of the west edge, and is built from razor-edged rectangular segments that jog vertically in abrupt half-width steps; the two parallel roads never
  fix: In zone_defs either demote the slab path to a short paver apron in front of the forge with a spur linking it to the main road, or make it a real gate-to-gate road: extend to the west edge, smooth the 
- MAJOR: Anchor coverage fails: NE quadrant has no anchor (its largest features are a lone grave, a 3-coffin prop, and a log camp — all micro-props), and the entire southern band below y~1750 across the full map width is anchorless sprinkle.
  fix: In zone_defs add one anchor-scale POI in NE (~2700,500 — pit head, collapsed mine shaft, or watchtower) and one in the deep south (~1900,1950 — flooded quarry pit or ruin) with their own ground aprons
- MINOR: Props placed on road surfaces: live trees stand in the middle of the main road in two places, a dead tree sits on the slab path, and a campfire+barrel camp sits directly on the road edge.
  fix: Add a road-mask exclusion to the zone_builder scatter pass and nudge the roadside camp ~40 world-px off the carriageway.
- MINOR: A tree and its shadow blob are placed out of bounds, rendering on the grey padding beyond the NW map corner.
  fix: Clamp zone_builder scatter coordinates to zone bounds (inset by max prop half-width).
- MINOR: SE cemetery headstones sit in a mechanically aligned grid with no enclosure or framing, reading as pasted stamps rather than a burial ground.
  fix: Jitter positions/spacing in the zone_defs cemetery cluster, mix stone variants, and frame with a broken fence or dead-tree pair.

## grey_marches — D (wallpaper=True)
one_image: Weak candidate only: the grave-robbers' coffin campfire at ~x2660,y1520 (three coffins ringed around a glowing fire) is the sole deliberate composition, but it is prop-scale and floats in blank field — nothing in the zon
- CRITICAL: Ground is wallpaper: one flat olive fill — open-ground per-tile luminance std is 1.13 (~1.6% of mean) over 805 samples; only a few soft smudge blobs break 2933x2096px of a single color.
  fix: In zone_defs add large-scale ground breakup: 2-3 alternate ground tones (grey silt, dead-grass tan, mud) painted as big irregular patch decals plus standing-water pools; smudges alone are invisible at
- CRITICAL: Zone identity failure: 'The Grey Marches' (deadforest) reads as a green summer meadow — ground hue RGB(94,93,16) is generic grassland olive; no grey, no marsh, no water, no mist, no signature prop set beyond stock dead trees.
  fix: Shift ground base toward grey-brown silt in the biome palette, add bog pools/reeds/mist ColorRect tint in the zone def so a random screen answers 'marsh', not 'field'.
- CRITICAL: Confetti, not clusters: trees/bushes are an even sprinkle — all 48 density-grid cells populated, CV 0.33, no cell empty and none dense; zero thickets and zero honest clearings across the whole 7168x5120 zone.
  fix: Rework zone_builder scatter to cluster seeds: 5-8 dense groves + large exclusion zones of genuinely bare ground; delete ~40% of the singleton trees.
- MAJOR: Road is a pale razor-edged slab strip, not a worn path: hard straight edges for its full ~2900px run, meandering only via abrupt one-tile 90-degree jogs, worst where two slab rows overlap in a notch.
  fix: Swap slab strip for dirt-path tiles with ragged grass-blended edges and wear decals; curve via gradual half-tile offsets, never full-row steps.
- MAJOR: Road west terminus dead-ends in open grass ~100 world px short of the west zone edge instead of running gate-to-gate; zone also has no north-south route at all.
  fix: Extend road west to the map edge in zone_defs; if N/S gates exist, add a connecting path — currently top/bottom edges (y33,y2129) are pathless.
- MAJOR: A dead tree is planted directly on the road slabs, blocking the path, and the road has bald slab gaps nearby.
  fix: Add road-corridor exclusion to the tree scatter in zone_builder; patch the missing slab runs.
- MAJOR: Five to six flat untextured colored rectangles (brown/grey/tan, ~8-10px) read as missing-texture placeholders clustered near the east road end.
  fix: Identify the landmark/prop defs emitting bare ColorRects there and give them real sprites, or remove them.
- MAJOR: Stray out-of-bounds prop: a healthy LIVE green tree (wrong biome sprite set) renders outside the playable rect, rooted in the grey padding at the NW corner.
  fix: Clamp scatter coordinates to zone bounds in zone_builder and use the deadforest tree set; this one is also the only lush-green tree in the whole zone.
- MAJOR: Anchor poverty: the entire 7168x5120 zone contains exactly one building (the chapel); NW and SE quadrant 'anchors' are 3-piece grave micro-vignettes, prop-scale rather than landmark-scale.
  fix: Add one landmark-scale composite per quadrant (ruined watchtower, sunken chapel, plague pit ringed with stakes) mirroring existing landmark defs.
- MINOR: Nothing connects to the road: the chapel floats ~430px north of it and the gravestone plot ~300px south, with no spur trails; the plot itself is a mechanically perfect 3x3 grid with no fence or wear.
  fix: Add short dirt spurs from the road to both sites and jitter the gravestone grid, adding a fence segment or two.

## threadlands — D (wallpaper=True)
one_image: NONE — the closest candidate is the dark manor with the small graveyard at its feet (x1290-1560, y1180-1400), but it floats in blank snow with no approach path, and the exact same manor sprite is copy-pasted at (2420,185
- CRITICAL: Zero roads: the only linear feature in the entire zone is a razor-edged uniform grey stone strip (reads as wall/debug causeway, not a worn path) running N-S at x1892-1965, and it dead-ends short of BOTH map edges — stops ~50px below the north edge (gap visible
  fix: zone_builder: run a proper road pass — trampled-snow/dirt path texture with ragged verges, routed gate-to-gate N-S AND E-W, snapped to zone edges, with spurs into the NE hamlet and both manors; keep t
- CRITICAL: Wallpaper ground: the whole 7680x5632 zone reads as one flat pale-lavender sheet at macro — only sub-pixel speckle noise and a few faint soft blotches; no ice sheets, exposed rock, deep-snow drifts, or tonal patches break the field anywhere.
  fix: zone_defs: add 2-3 macro-scale ground variants for tundra (packed ice, dark frozen earth, blue shadow-snow) and have zone_builder blob-paint them in large organic patches (10-20% coverage each) so ton
- MAJOR: Confetti not clusters: trees, bushes, barrels, rocks, and gravestones are sprinkled as evenly-spaced singletons at near-constant density across the whole map — no forest masses, no honest empty ground; the handful of real clusters (camp, graveyards, hamlet) dr
  fix: zone_builder: replace uniform scatter with cluster-based placement — 4-8 dense dead-tree copses of 6-12 trees, prop groups tied to POIs, and enforce large deliberately-empty snow fields between them.
- MAJOR: Copy-paste anchors: the large U-shaped dark manor at (1380,1265) is pixel-identical to the one at (2420,1850), and the campfire-with-3-bedrolls camp at (1030,570) is duplicated at (2128,1300) — the zone's two biggest anchors and two of its POIs are literal rep
  fix: zone_defs: give each manor a variant skin/footprint (one ruined/burnt, one intact) or swap one for a different large structure; re-dress the second camp (abandoned, snow-buried, corpses) so the two re
- MAJOR: NW quadrant has no real anchor: its largest features are a campfire with bedrolls (1030,570) and a tiny 3-piece roadside shrine (1080,1010) — no building, monument of scale, or pit; the quadrant is otherwise ~1450x1050px of sprinkle.
  fix: zone_builder: place one sizeable anchor in the NW — e.g. a ruined watchtower, frozen-loom monument, or collapsed longhouse — and grow the existing shrine into a small story cluster around it.
- MAJOR: Zone identity fails away from POIs: a random interior screen shows only flat pale snow plus one gnarled black tree — indistinguishable from any generic snow zone; the presumed signature 'thread' props (thin pale-blue curling filaments on the ground) are nearly
  fix: zone_defs: promote the thread motif to macro-readable props — large colored thread-lines crossing the ground, thread-wrapped trees, loom monuments — and set a minimum signature-prop density so every s
- MINOR: The grey wall strip has abrupt half-width lateral jogs where segments misalign, reading as tiling errors rather than construction.
  fix: zone_builder: align wall segments to a consistent spine, or dress jogs with rubble/corner pieces so offsets read as ruin, not bug.
- MINOR: The 8-headstone graveyard is stamped in a rigid 3x3 grid with uniform spacing — reads mechanically generated next to the organic manor graveyard at (1300,1360).
  fix: zone_builder: jitter gravestone positions/rotations and mix stone variants; add a fence fragment or dead tree to frame it.
- MINOR: Loose crates are strewn without framing west of the wall's south terminus near a lamppost glow — reads as spilled debug loot rather than a smuggler/supply story beat.
  fix: zone_builder: gather the crates into a stacked cache against the wall with a tarp/cart and tracks leading to the wall gap.

## listening_steppe — D (wallpaper=True)
one_image: NONE - the closest candidate is the SE grave-digger hamlet (img x2200-2650, y1560-1950: three timber houses, a statue/headstone row, a coffin trio, and a glowing cross-grave at x2720,y1730), but it floats unfenced and un
- CRITICAL: Ground reads as one flat mustard-olive field across the entire map; only sparse soft dark airbrush blotches (e.g. x830,y1790 and x2870,y700) with no dirt patches, grass-tone variants, or steppe scrub visible at macro.
  fix: zone_builder ground pass: add 2-3 grass tint variants plus dry-earth/dirt patch blobs (10-40 tiles each) at a density that still reads at full-zone zoom; bake the existing smudge layer into actual til
- MAJOR: NE quadrant has no anchor: largest objects are a single ornate grave (x2870,y540), a 6-headstone plot (x2585,y705), a grave pair (x3260,y520) and a campfire (x2500,y1005) - nothing building/monument scale in a quarter of the zone.
  fix: Add one anchor to zone_defs in NE (e.g. listening-stone circle, barrow mound, or ruined watch post) around world (5000-5600, 1200-1600) and have zone_builder cluster the existing graves around it.
- MAJOR: Trees/shrubs are an even confetti sprinkle - 200+ singletons at near-uniform 150-200px spacing over the whole map, with no copses and no meaningful clearings; only the hand-placed camps/hamlet form clusters.
  fix: zone_builder scatter rule: group 60-70% of tree budget into 3-8-tree copses with clear halos, leave honest open steppe between clusters; keep singleton rate low.
- MAJOR: The only road is a single 1-tile-wide slab strip, ruler-straight down the map meridian with razor tile edges and mechanical 1-tile jogs (e.g. jog at x1905,y870) - reads as a pale debug strip, not a worn path.
  fix: zone_builder road brush: widen to 2-3 tiles of worn-dirt tiles, ragged grass-blended edges, gentle meander instead of tile-snap jogs.
- MAJOR: Road fails gate-to-gate: top terminus is a blunt squared cap at (1915,80) leaving ~48px of grass to the top edge (y=32); bottom terminus is an L-shaped cap at (1915,2102) leaving ~24px to the bottom edge (y=2126); and there is no east-west road at all across a
  fix: Extend the road polyline to the actual gate coordinates at both edges in zone_builder; if zone_defs declares E/W gates, add the horizontal road; otherwise add spurs (see anchor-connection finding).
- MAJOR: Anchors are pathless: the chapel (x1570,y550) sits ~330px west of the road with no spur, the SE hamlet (x2210-2620,y1560-1950) sits ~300-500px east with no spur, and both campfire camps float in open grass; only the SW tower (x1822,y1680) touches the road.
  fix: zone_builder: add worn-path spurs from the main road to the chapel door and to the hamlet center; a short trampled-grass trail to each camp.
- MAJOR: Biome mismatch on the zone's most visible landmark: the NW chapel has a snow-covered roof in a green steppe - it reads as a winter asset pasted into summer grass.
  fix: Swap to the non-snow roof variant of this building in the zone_defs prop entry (or retint the roof in the sprite atlas).
- MAJOR: Zone identity fails the random-screen test: the grave-digger signature content (open graves, coffins, headstone plots, statue row) is all sub-20px props, so any screen away from the 4-5 POIs is anonymous olive grass plus generic trees; the 'Listening' theme ha
  fix: Promote a signature prop to mid-frequency scatter in zone_defs: rows/arcs of listening-stone monoliths repeated 8-12 times across the steppe, plus lone-grave-with-marker micro-vignettes.
- MINOR: Stray tree planted exactly at the map origin corner with its canopy and shadow bleeding into the grey out-of-bounds padding.
  fix: Clamp zone_builder scatter placement to map bounds minus a 1-2 tile margin; reject props whose sprite bounds cross the zone rectangle.

## transcub_vale — D (wallpaper=True)
one_image: NONE - the closest candidate is the roadside keeper's hut vignette (dark hut, lantern, cauldron, woodpile, fence beside the flagstone road) at img x1990,y650, but it is a minor beat lost in empty field, not a composed sc
- CRITICAL: The only road dead-ends in open grass at both ends: it starts ~125 world px below the north edge (img y~83) and stops ~890 world px short of the south edge (img y~1762, x~1910), so it connects no gate to no gate; there is no east-west road at all.
  fix: In zone_defs extend the road spec to true edge coords (y=0 to y=5120 world) so zone_builder paints it gate-to-gate; add an E-W branch to whichever side gates exist, and add short spur paths from the r
- CRITICAL: SW quadrant has no anchor - its only content is a knee-high cauldron campfire vignette; the whole southern strip (img y>1800) and eastern third (img x>2800) are landmark-free tree-sprinkled grass.
  fix: Add at least one real landmark def in the SW (ruined watchtower, barrow mound, shepherd stead) and one in the deep SE/E; mirror an existing landmark entry in zone_defs and let zone_builder compose it.
- MAJOR: Ground reads as a single flat olive field at macro: base grass is one tone with only soft dark smudge overlays (macro luminance p5-p95 = 72-85); no second ground material, no dirt aprons, no rock outcrops despite biome 'ridge'.
  fix: Add scattered ground-breakup decals in zone_defs (dirt patches, lighter grass swathes, exposed ridge-rock shelves) as decal scatter, not sheet accents (sheet accents stripe, per the wallpaper pothole)
- MAJOR: Trees are an even single-tree confetti sprinkle across the full 7168x5120 with near-constant spacing - no groves, no forest masses, no deliberate clearings, so nothing clusters into story.
  fix: Rework the tree scatter in the zone def into 4-6 dense grove blobs plus open meadow between them; thin the uniform background scatter by half.
- MAJOR: Zone identity fails: both anchors are the identical manor+barn composite duplicated, and away from them any random screen is generic green meadow - nothing says 'Transcub Vale' or 'ridge'.
  fix: Swap one duplicate for a distinct landmark type and add a signature prop family (e.g. ridge cairns / vale shrine posts) repeated along the road so screens self-identify.
- MAJOR: Mechanical debug-looking prop rows: five identical cross headstones in a perfectly even horizontal line, and three open graves evenly spaced in a row, both floating in open grass with no fence, dirt, or framing.
  fix: Jitter positions/rotations, vary headstone sprites, and dress each as a micro-graveyard (fence segments, dirt patch, one tree) in the landmark composite instead of raw row placement.
- MAJOR: An open grave with headstone is placed directly on top of the road slabs - the flagstones run under its frame, reading as a placement collision between the road strip and the grave prop.
  fix: Offset the grave 100-150 world px east of the road edge in zone_defs, or if the on-road grave is a deliberate story beat, break the slabs around it and dress it (dirt spill, boards) so it reads intend
- MINOR: Road geometry is a plumb-straight vertical line for its entire ~4100 world px length with only single-slab jogs - worn texture is fine, but the perfectly straight spine reads artificial at macro.
  fix: Add 2-3 gentle waypoint bends to the road polyline in the zone def so zone_builder lays a wandering path.
- MINOR: Loose single crates are sprinkled in open grass around the north gate approach with nothing to belong to (confetti props).
  fix: Pull the crates into the existing lantern-sign vignette at (1985,165) or the camp glow, stacking 2-3 together with a tarp/barrel.
- MINOR: A tree is rendered outside the playable rectangle - its canopy and shadow draw over the grey out-of-bounds padding at the map's top-left corner.
  fix: Clamp scatter placement to world bounds minus half the sprite footprint in zone_builder, or nudge this tree def inside.

## whisper_passes — D (wallpaper=True)
one_image: NONE — closest candidate is the ruined watchtower + broken column pair at x2690,y730 (NE), but it floats in undifferentiated grass with no framing, and the alternative (round waystation tower at x1217,y960) is a 3-prop k
- CRITICAL: The zone's only road fails gate-to-gate: it begins at x506 and dies at x3346, dead-ending in open grass ~180 world px short of the west edge (x433) and ~107 world px short of the east edge (x3390), and there are zero north-south roads, so no gate on any edge i
  fix: In zone_defs, snap the road polyline's first/last nodes to the actual west/east gate positions on the zone boundary; if N/S gates exist, add spur paths from the road to them in zone_builder.
- CRITICAL: The road reads as a pale razor-edged debug strip, not a worn path: uniform ~61 world px width, perfectly horizontal for 2840 image px, hard slab edges against grass, with abrupt one-slab-row staircase jogs (band jumps 1067-1054-1080-1094-1117) that at macro ma
  fix: Replace straight-line road generation with a meandering spline in zone_builder's road pass; add dirt-shoulder/wear decals along both edges, vary width, and remove the one-row vertical offset jitter th
- MAJOR: Ground is wallpaper: one flat olive tile (RGB ~92,94,16, luminance stdev ~7) across the entire 7168x5120; the only variation is a repeated soft dark ellipse smudge that reads as a vignette artifact, and there is no second ground material anywhere — no dirt, sc
  fix: Add 2-3 ground variants in zone_builder's terrain pass (dry grass, dirt, rocky scree patches) painted in large organic patches, and cut the airbrush shadow-blob decal or raise its contrast/shape varie
- MAJOR: Confetti vegetation: trees, bushes and rocks are an even single-sprite sprinkle at near-constant density over the whole map — trees almost never touch, there are no groves, treelines, or deliberate clearings, so every screen looks identical.
  fix: Replace uniform scatter with cluster-based placement in zone_builder: 3-8 tree clumps with overlapping canopies, dense treelines flanking the pass, and honest empty meadows between clusters.
- MAJOR: Zone identity is absent: biome is 'ridge' and the name is 'The Whisper Passes', but there are no cliffs, elevation lines, rock faces, scree fields, or any pass geometry — a random screen answers 'generic bright-green meadow', and the chartreuse palette is not 
  fix: Give the pass its geometry: cliff/ridge edge tiles walling the north and south thirds so the road actually runs through a pass; add ridge-biome signature props (rockfalls, wind-bent pines, mist decals
- MAJOR: Copy-paste anchor kits: the identical round-tower + red flower stand + signpost + container kit appears twice, the identical campfire + three-coffin camp appears twice, and gravestones are placed in razor-straight evenly-spaced rows three times — placement rea
  fix: Differentiate the two waystations in zone_defs (one intact, one ruined/looted with different prop set); jitter grave positions/rotations and anchor each row to context (fence, dead tree, path spur) vi
- MAJOR: All anchors hug the road corridor: the entire bottom band (y~1700-2130, roughly 1000x7168 world px, 3+ full screens) and the top band above y~450 contain nothing but tree sprinkle — no destination, no reason to walk there.
  fix: Either shrink the zone in zone_defs or seed one anchor per outer band in zone_builder (e.g., a rockslide shrine in the south, an abandoned lookout in the north) with a dirt trail spur connecting each 
- MINOR: Grave props float context-free in open grass: the three stone-framed open graves sit alone with no fence, path, or marker explaining them, weakening what could be the zone's best story beat.
  fix: Wrap the open-grave trio into a cluster template (broken fence, mourning lantern, trampled-ground decal, footpath spur to the road) in zone_builder.
- MINOR: A tree sprite renders outside the map bounds in the out-of-bounds padding at the extreme NW corner, suggesting a prop placed at/beyond the world origin edge.
  fix: Clamp prop placement in zone_builder to keep full sprite bounds inside the world rect, or add an edge margin equal to the largest sprite half-width in zone_defs.

## The — D (wallpaper=True)
one_image: Intended composition exists on the central axis — the black maw of the pit ringed by radial bone arcs with the mirrored manor looming above (img x1600-2250, y330-1060) — but it does not fire: at native cave brightness th
- CRITICAL: The zone's single road dead-ends at both ends in open ground: it starts ~400 world px south of the pit and stops ~100 world px short of the south edge, touching no gate and connecting neither the manor nor the pit; there is no E-W road at all.
  fix: In zone_defs road_spec, route the path gate-to-gate: extend north through the pit rim apron up to the manor door and the north gate, extend south to actually touch the south edge, and add at least one
- CRITICAL: Zone identity is missing its namesake: a saturated-red pixel scan finds zero bloodstone anywhere — the only crystals are cyan-green, the pit is a featureless black ellipse with faint BLUE rim pebbles, and a random open-ground screen is anonymous flat mauve cav
  fix: In zone_builder swap the crystal_cluster prop set to a red bloodstone variant (or add red clusters at the pit rim), add a red under-glow emitter inside the pit mouth, and tint the pit-adjacent ground 
- CRITICAL: Wallpaper: the ground is one flat color field — block-median luminance spread is 1.7/255 across the entire 5120px map, a single repeating plate texture with uniform mottle; no second ground material, stain field, or tonal zone anywhere, so the flatness is not 
  fix: Add zone_defs ground_patch layers: dark tailings/blood staining radiating from the pit, a worn apron around the manor, and 2-3 large irregular tonal patches (damp rock, ash, moss) so the macro view br
- MAJOR: The road reads as a pale razor-edged debug strip: uniform-width rectangular slabs running perfectly straight, and it is one of the brightest elements in the raw frame.
  fix: Replace road material in zone_builder with worn_path tiles: width jitter, broken/missing slabs, dark edge blending, and drop its albedo toward the ground tone.
- MAJOR: Glow budget ignores the anchor: the pit and its bone ring and the manor's hanging lanterns are all unlit and invisible at native cave darkness, while the four glow pops (two orange lantern shrines, two green crystal patches) mark generic filler spots instead.
  fix: In zone_defs light_spec, give the pit an interior red glow and rim ember lights, light the manor lanterns, and let the shrine/crystal glows become secondary.
- MAJOR: Anchor coverage is thin: NE quadrant's only anchor is a tiny obelisk vignette, SW quadrant has no building/monument/pit at all (just a crystal patch and a cauldron camp), and the outer ~25% ring of the map is dead pebble-sprinkled wallpaper.
  fix: Add one real anchor per weak quadrant in zone_defs (e.g. collapsed mine head SW, bone shrine or crane NE) and push at least one story cluster into each dead edge band near the gates.
- MAJOR: The manor is a perfect mirror-stamp — west wing is the east wing flipped — and it fronts onto nothing: no path from its doors to the road 500 world px south.
  fix: In zone_builder break the symmetry (asymmetric annex, collapsed wing, side scaffold) and lay a worn path from the entrance down past the pit to the road spine.
- MINOR: Two gravestone groups are ruler-straight single-file rows with even spacing that read as stamped strips rather than story clusters; lone skeletons/cultists are sprinkled singly across open ground.
  fix: Re-seed these prop groups with jittered rotation/spacing and cluster the loose figures into 2-3 scene vignettes (dig site, ambush, procession).
- MINOR: Bright cream-colored crates scattered diagonally in open ground near the road's south stub read as unthemed placeholder props and are among the brightest sprites in the raw frame.
  fix: Swap to the cave-palette crate/sack variants and group them against the road end or a cart to justify them.
- MINOR: A tiny two-row glyph/dash decal south of the pit resolves to nothing at any zoom and looks like leftover debug text or markers.
  fix: Remove the decal or replace it with a readable prop (warning sign, rune circle) in zone_builder.

## lichenreach — D (wallpaper=True)
one_image: WEAK YES: hooded statue on plinth with four stone cairns, flanked by twin lichen glow-mounds, at approx x2400-2650, y1600-1780 (image px). It is the only deliberate composition in the zone, but the focal statue sits in t
- CRITICAL: Ground is pure wallpaper: the entire 4096px floor is one uniform cave-tile stamp with zero macro tonal variation — at native exposure the map reads as a solid black rectangle, and even gamma-lifted it is one flat mauve field with no second material, no moss/da
  fix: add a ground-breakup pass in zone_builder: 2-3 floor variants (damp stone, moss carpet, bone-gravel) painted in 5-15 tile organic blobs at 15-25% coverage, plus large soft tonal noise; bias moss varia
- MAJOR: The zone's single road fails gate-to-gate: its north terminus stops in open ground ~560 world px short of the north edge (it ends at a small grave+lantern marker, not at a gate), while only the south end reaches the map edge.
  fix: extend the road spline in zone_defs to the north gate coordinate so it exits the zone edge; keep the grave+lantern as a way-shrine BESIDE the road rather than as its stopper
- MAJOR: Road reads as a pale razor-edged debug strip: uniform flat light-grey rectangular slabs with hairline outlines in a perfectly straight one-slab-wide vertical column, no wear, no width variation, no edge blending — it is the brightest non-glow element on the ma
  fix: swap the road stamp in zone_builder for a worn-path material: darker desaturated fill closer to floor value, broken/dithered edges, occasional missing slabs, dirt verge decals, and 1-2 tile lateral me
- MAJOR: Only one road exists in the whole zone; there is no E-W route at all, leaving both the entire west half (x838-1900) and east half (x1970-2974) — over 90% of the area, including every lichen cluster and the statue set piece — roadless and unconnected.
  fix: add at least one E-W road entry in zone_defs connecting side gates through the well plaza (x2005,y1235), with a branch toward the statue set piece and sarcophagi in the SE
- MAJOR: NE quadrant has no anchor: nothing but a single lichen cluster, two small rock piles, and confetti sprigs across a quarter of the zone.
  fix: add one anchor entry in zone_defs for the NE (collapsed mine shaft, bone pit, or crystal formation) roughly at x2500-2700, y300-600
- MAJOR: SW quadrant has no anchor: two lichen clusters, a few rock piles and a lone plank-debris scrap across a quarter of the zone.
  fix: add one anchor entry in zone_defs for the SW (sinkhole/pit, abandoned camp, or fallen pillar field) roughly at x1200-1500, y1500-1800
- MAJOR: Small-prop confetti: lone skeletons are sprinkled one-by-one at near-even ~150px spacing with no story grouping, and single red-cap mushrooms plus 1-tile yellow sprigs repeat the same even sprinkle across the west half.
  fix: replace uniform scatter with cluster scatter in zone_builder: pull the skeletons into 2-3 battle/ritual tableaux (heap + gravestone + dropped gear), group mushrooms in rings of 3-5, and cut sprig dens
- MINOR: Zone identity is carried entirely by the green lichen glow stamp — 13 near-identical clusters at identical glow radius; both warm amber accents hug the central road spine, so the east and west thirds have zero warm contrast and any random screen off the spine 
  fix: vary the glow vocabulary in zone_defs: 2-3 lichen cluster sizes/hues (teal, sickly yellow-green), and add 1-2 off-road warm accents (abandoned lantern, brazier) in the E and W thirds
- MINOR: Three upright sarcophagi stand in a razor-straight row isolated in bare open ground — no path, no ground treatment, no supporting props connecting them to anything.
  fix: anchor them: give the trio a dirt/flagstone apron, candle or bone props, and a worn spur path from the main road in zone_builder
- MINOR: Untextured placeholder-looking flat pale squares (single-tile grey/tan quads with no sprite detail) float around the south road exit with no cluster logic.
  fix: verify these prop ids in zone_defs — they render as bare colored quads at this scale; replace with actual crate/rubble sprites or delete
- MINOR: A regular 5x3 grid of tiny grey dots sits beside the road — reads as a debug marker or unresolved decal, not set dressing.
  fix: remove or replace with an organic rubble-scatter decal in zone_builder
- MINOR: A stray rock prop straddles the map's NW corner, more than half of it hanging in the out-of-bounds grey padding — a failed spawn at/near origin (0,0).
  fix: clamp prop spawns to zone bounds in zone_builder, and hunt for the entry with position ~(0,0) in zone_defs

## bloodroad — D (wallpaper=True)
one_image: Closest candidate is the road checkpoint at ~x1985,y455: stone watchtower with thatched roof, glowing brazier stand, two dark-red banners, barrel and signpost beside the road. It is the only authored composition in the z
- CRITICAL: Ground is one flat grey-taupe field (avg ~RGB 77,77,73) across the entire 7168x5120 zone; the only variation is soft airbrushed dark smudges that read as compression artifacts, and detail decals are stamped on a perfect per-tile grid, producing visible dotted 
  fix: zone_builder ground pass: paint 2-3 organic volcanic material fields (ash beds, basalt, scorched earth) at 10-20% coverage with irregular borders; replace grid decal placement with jittered density-no
- CRITICAL: Confetti, not clusters: dead trees, yellow shrubs, and rocks are sprinkled at uniform density over the whole zone with no honest voids and almost no story groupings (only ~4 real clusters exist: checkpoint, two campfire camps, NW ruin).
  fix: zone_defs scatter: switch uniform scatter to cluster scatter (Poisson groups of 3-8 props sharing a story: burnt copse, rock spill, wrecked wagon) separated by deliberate 400-800 world px empty gaps.
- CRITICAL: Zone identity fails: biome is 'volcanic' but there is no lava, ember vent, ash, or basalt anywhere; palette is generic grey wasteland, and the 'blood' motif exists only as 4-5 tiny red banners hugging the road — any off-road screen is unidentifiable.
  fix: zone_defs: retint ground toward ash/charcoal with ember-crack decals or vent props as biome signature; string red war-banners/impaled markers down the full road length at readable spacing and add bloo
- MAJOR: SE quadrant has no anchor: its only features are an ember glow at x2413,y1326 and a hanging cage at x2246,y1133; the entire eastern half of the quadrant (x2450-3334, ~2200 world px wide) is pure confetti.
  fix: zone_builder: place one real anchor (gallows field, ruined toll fort, or sacrificial pit) around x2800,y1600, and promote the ember glow into a proper vent/pyre cluster.
- MAJOR: The single road is a 5120-world-px dead-straight vertical strip with razor edges, squared half-tile jogs, and repeating L-shaped dark seam artifacts from broken autotiling — it reads as debug geometry, not a worn trade road (color itself is fine, near ground v
  fix: zone_builder road spline: add gentle S-curves and width variation, blend edges with wear/rut decals and roadside debris; fix the road autotile so interior seams stop rendering.
- MAJOR: No secondary paths: NW ruin tower (x875,y880), SW camp (x1540,y1760) and NE camp (x2166,y682) all float 600-2600 world px from the road with no connecting trail, and no E/W route exists (both side edges verified clean) — every off-road anchor is a traffic dead
  fix: zone_builder: add worn spur trails from the main road to each camp/ruin; if zone_defs declares E/W gates, add the missing cross-road gate-to-gate.
- MAJOR: Stray off-biome prop rendered outside the playable rectangle: a lush green-canopy deciduous tree with a dark red shadow blob sits over the map's top-left corner, mostly in out-of-bounds padding — classic un-positioned prop defaulting to world origin (0,0), and
  fix: zone_builder placement bug: find the prop instance with default/negative coords in bloodroad's prop list and delete or re-place it; add a build-time assert that all props fall inside world bounds.
- MINOR: The one composed beat (checkpoint tower) is under-dressed and disconnected: tower, brazier, banners, and barrel are loosely scattered and the tower does not sit on or gate the road, so the composition has no focal framing.
  fix: zone_defs cluster def: rebuild checkpoint as a road-gate composition — tower flush to road edge, banner pair flanking the road, wagon/crate queue on the road, guard corpse or blood decal to seed the z

## ashvents — D (wallpaper=True)
one_image: Weak but present: gravedigger camp at ~x2745,y1840 (SE quadrant) — campfire ringed by three freshly dug open graves, an NPC, and clawed dead trees; plus a candle-trail leading to a lone open grave at x2087,y1407. Both ar
- CRITICAL: The zone's only road is a single razor-straight vertical plank strip that dead-ends in open ash at y1602 (~550px above the south edge) and starts ~54px short of the north edge at y82 — no road touches any zone edge, and there is no east-west road at all on a 7
  fix: In zone_builder, route the main road from the actual north gate to the south gate coords in zone_defs (full gate-to-gate), and add an E-W road through the NE hamlet connecting west/east gates; forbid 
- CRITICAL: Zone identity failure: 'The Ashvents' contains no visible vent, fissure, lava, fumarole, or smoke column anywhere at macro — the namesake signature prop is absent and the zone reads as generic grey waste, interchangeable with grey_marches/gravemark_tundra.
  fix: Add 3-5 large vent set pieces to the ashvents prop table in zone_defs (glowing fissure crater + smoke particle emitter + scorched-ring decal) and have zone_builder place one per quadrant as anchors.
- MAJOR: Wallpaper ground: base reads as one flat grey field; the only breakup is a rigid periodic grid of identical dark tick-marks (visible mechanical tiling at macro) plus a few faint soot smudges.
  fix: In zone_builder ground pass, blend 2-3 ash tones (dark basalt patches, pale ash drifts, scorch decals) as irregular blobs, and jitter/randomize the detail-tick scatter instead of stamping it on a fixe
- MAJOR: Confetti scatter: dead trees, sulfur bushes, and single rocks are sprinkled at near-uniform density across the whole map with no massed groves, no rockfields, and no honest empty ash flats between.
  fix: Replace uniform scatter with cluster-based placement (Poisson-disc cluster seeds, 4-8 props per clump, cleared flats between) in zone_builder's prop scatter for the volcanic biome.
- MAJOR: Empty quadrants: NW and SW quadrants contain no anchor — no building, monument, or pit; only confetti scatter, a lone small obelisk (x983,y1465) and pin-sized campfires. All structures sit in the NE (silo x1985,y440; chapel x2290,y515).
  fix: Add one anchor per empty quadrant in zone_defs POI list, e.g. a collapsed vent-mine head in NW and a sulfur quarry pit in SW, and make zone_builder assert >=1 anchor per quadrant.
- MINOR: Road seam defect: the road column has a hard lateral half-width jog (upper and lower segments misaligned), and its uniform pale plank fill with razor edges reads as a debug strip rather than a worn ash path.
  fix: Give the road painter meander waypoints and edge dithering/wear decals; snap consecutive road segments to a shared centerline so segment joins can't offset.
- MINOR: Stray off-biome prop: a bright green leafy tree sits at the extreme NW map corner, half-clipping into the out-of-bounds padding — palette-breaking and likely an origin/(0,0) fallback spawn.
  fix: Remove it and add a zone_builder guard rejecting prop spawns within N tiles of the map origin or outside biome palette whitelist.
- MINOR: Contextless loot litter: 4-5 orange crates float in open ground near the road top with no camp, cart, or structure explaining them.
  fix: Attach loot crates to story clusters (the road-top signpost camp or NE hamlet) in zone_builder rather than scattering them as free props.

## canal_maze — D (wallpaper=True)
one_image: NONE. Closest candidate is the fishing camp in SW (~x1300,y1420: hut + well + tent + beached boat + wolf pack) but it is prop-scale, unframed, and pathless; the road/canal T-junction (~x1950,y1100) is a bare butt-joint w
- CRITICAL: Zone identity failure: 'The Canal Maze' contains exactly ONE dead-straight canal (x~1955-2010, y32-2127) — no branches, no junctions, no maze, and zero port dressing (no docks, quays, moorings, cranes, cargo) anywhere on its 2100px length; any screen off the c
  fix: zone_defs: define a branching canal network (3+ waterways, junctions, at least one island loop) as the zone skeleton; zone_builder: dress every bank segment with port-biome props (dock planks, mooring
- CRITICAL: Road dead-ends at the canal with no bridge, and the entire west half of the zone (x453-1950, ~50% of world) has zero roads — the only road starts at the canal's east bank (x~1950,y1090) and runs east to the gate at x3386; four west-side buildings sit completel
  fix: zone_builder: place a bridge prop at the crossing (x~1980,y1095), continue the road west to the west gate, and route path spurs to each building; roads must terminate only at gates or anchors.
- CRITICAL: Confetti vegetation: single trees sprinkled at near-uniform density across all four quadrants with no groves, no clearings, no honest space — textbook even-sprinkle defect over the whole 2933x2095 map area.
  fix: zone_builder: switch tree scatter to Poisson-cluster/blue-noise-cluster placement (groves of 5-12 with 300-600px empty gaps), cull isolated singletons.
- MAJOR: Ground reads as one flat olive-green field at macro; only micro-speckle noise and faint soft smudges exist, no dirt patches, mud, sand, or grass-variant fields visible zoomed out — and for a port biome there is no coastal/wet material anywhere.
  fix: zone_defs: add 2-3 macro ground-breakup layers (mud/dirt blotches along canal banks, worn grass fields) with patch sizes >=200px so variation survives zoom-out.
- MAJOR: Canal is drawn as a stroked capsule, not water: ruler-straight, uniform dark-brown outline, and rounded end-caps that overshoot the map bounds into the grey out-of-bounds padding at both ends.
  fix: zone_builder: render water as terrain-integrated polygons with bank/edge tiles, clip to zone bounds; kill the capsule line-stroke rendering.
- MAJOR: Enemy critters (rats) are standing on the canal water surface at the road crossing.
  fix: zone_builder: subtract water polygons from spawn-region navmesh/spawn masks.
- MAJOR: Road looks like a debug strip: pale razor-edged rectangular flagstone slabs of perfectly uniform width with hard dark outlines, no wear, no edge dithering into grass; plus a broken stutter of isolated slab fragments along the canal's east bank forming a dead-e
  fix: zone_builder: use worn-path brush (irregular width, dithered edges, grass overgrowth breaks); make the towpath continuous or remove the orphan slabs.
- MAJOR: SW quadrant anchor is the weakest on the map — a tiny hut camp is the only structure anchoring a quarter of the world; meanwhile gravestone mini-clusters (3-6 stones) are scattered across 5+ unrelated spots instead of forming one honest cemetery.
  fix: zone_defs: promote SW to a real anchor (lock-keeper's house or boathouse on the canal); consolidate grave scatters into one cemetery story-cluster with fence/statue.
- MINOR: Same dark barn sprite repeated 4x as the anchor of both northern quadrants — identical silhouettes at macro flatten zone identity.
  fix: zone_defs: vary anchor building variants per quadrant (mill, warehouse, chapel) from the building set.
- MINOR: Stray tree sprite rendered fully in the out-of-bounds grey padding beyond the map's top-left corner.
  fix: zone_builder: clamp prop placement to zone bounds minus prop half-extent.

## dead_timber — D (wallpaper=True)
one_image: Closest candidate, not yet deliberate: the road ambush at x2700,y650 — campfire, strewn coffins and loot ON the road, with the small graveyard just up-road at x2990,y495 — a genuine story beat that would be screenshot-wo
- CRITICAL: SE quadrant contains zero anchors — nothing but evenly sprinkled dead trees, bushes and pebbles over ~1250x950px of bare grass.
  fix: zone_builder: drop a real anchor set in SE (ruined sawmill, logging pit, or burnt watchtower + yard) around x2800,y1650 world-equivalent; clear a glade around it and route a spur path to it.
- CRITICAL: The one road is a debug capsule, not a worn path: uniform-width blue-slate stroke with razor vector edges and literal rounded polyline end-caps visible at both terminals; the asphalt-blue color belongs to no biome palette on this map.
  fix: zone_builder road pass: swap to worn-dirt/mud road texture with dithered, frayed edges and width jitter; remove round caps by running the road through gate props flush to both edges.
- CRITICAL: Trees are pure confetti — single dead trees at uniform Poisson spacing across the entire map, no copses, no clearings, no density gradient; fatal for a zone literally named The Dead Timber (density reads as open meadow, not forest).
  fix: zone_defs scatter: replace uniform scatter with clustered noise — 10-15 dense deadwood copses (5-12 trees each) with honest empty ground between, 3-4x density toward map edges, clearings carved around
- MAJOR: Ground reads as one flat olive wallpaper at macro; only variation is faint airbrushed dark smudges, several of which are visibly the same soft-circle stamp repeated.
  fix: zone_defs ground layer: add 2-3 real breakup tiles (dead grass, mud, ash patches) painted in irregular blotches plus decal litter (leaves, roots); retire the soft-circle shadow stamp.
- MAJOR: Palette contradicts deadforest identity: bright olive-green grass plus healthy leafy green trees make random screens read as generic plains — a screenshot from the south half cannot answer 'which zone is this?'.
  fix: zone_defs biome tint: shift ground to desaturated grey-brown/sickly ochre deadforest ramp; swap green-canopy tree sprites for deadwood variants.
- MAJOR: Mid-map stone wall is ruler-straight for ~2800px and dead-ends floating in open grass on BOTH sides, reaching neither edge — reads as an unfinished procedural strip.
  fix: zone_builder: extend wall to both map edges or terminate each end in a collapsed rubble mound/broken tower; add per-segment jitter and a couple of ragged breach gaps so it stops being one straight lin
- MAJOR: No road serves north or south gates — single E-W road only — and no building is connected: the village houses and the NW cabin sit in open grass with zero spur paths (dead-end anchors instead of dead-end roads).
  fix: zone_builder: add worn spur paths from the main road to the cabin, village yards, and south through the existing wall gap toward the SW campfire/graves; if N/S gates exist in zone_defs, run a crossing
- MINOR: Placeholder-looking anchor at the road bend: a flat brown rectangle with a crenellated top edge, reading as an unfinished fort footprint / missing sprite.
  fix: replace with a finished ruin-fort prop, or dress the footprint with rubble, floor tiles and wall stubs in zone_builder.
- MINOR: Bare colored square props (orange/tan quads) floating in open ground near the wall's east end — read as debug crates.
  fix: remove, or fold into a proper smuggler-cache cluster (tarp, barrels, cart) tucked against the wall end.
- MINOR: Isolated red banner props standing alone in empty grass with no context — singleton confetti.
  fix: attach banners to the road, wall, or ambush camp clusters, or delete them.

## greyhollow — D (wallpaper=True)
one_image: The black-pit funeral at ~(1920,980): a crowd of mourners ringing a black chasm inside the graveyard, with an open grave, cross headstone, and a lone tree — genuinely staged and the only screenshot-worthy moment in the z
- CRITICAL: Capital identity failure: Greyhollow is a capital with biome=port but reads as a scattered rural hamlet — ~25 buildings total, the 'urban core' is one street of ~12 row-houses, and there is zero port signature (no docks, quay, boats, or harbor; only water is a
  fix: In zone_defs mark greyhollow density=city: zone_builder should block out a street grid (3+ intersecting streets, 40-60 buildings, shared walls, plaza) around the crossroads, and add a docks district a
- CRITICAL: Gate-to-gate broken on the main E-W road: it starts ~33px inside the west edge (razor-cut start in open grass) and stops ~33px short of the east edge — the entire road floats, touching neither gate; there is also NO road at all to the north edge.
  fix: zone_builder road pass must snap road spline endpoints to the gate coordinates in zone_defs (clamp to zone bounds), and add a north arm from the crossroads (x~1927) to the north gate so all four edges
- CRITICAL: River severs the E-W road with no bridge or ford — road tiles butt into the west bank at x~1800 and resume at x~1845, and a torch lamp post stands inside the river channel at the crossing.
  fix: zone_builder needs a road-x-water intersection pass that stamps a bridge prop at every crossing and excludes the river polygon from the lamp/prop scatter mask.
- MAJOR: Wallpaper ground: the entire 10240x8192 field is one flat olive-green with only faint airbrushed dark smudges — at macro it reads as a single color with no dirt patches, tile variation, or biome transitions.
  fix: Add a ground-breakup layer in zone_builder: second grass tint, dirt/mud patches around buildings and road shoulders, coastal sand/shingle near the river, worn earth under the graveyard — target visibl
- MAJOR: Nothing is connected: the NW manor, NE house, SE estates, and the black-pit graveyard all float in open grass with no path, trail, or dirt spur linking them to the road network.
  fix: zone_builder should generate a dirt-path spur from the nearest road to every anchor listed in zone_defs (manor, chapel, estates, graveyard) so anchors sit on the movement graph.
- MAJOR: Ruined building foundation is stamped directly across the N-S road just south of the crossroads (rubble walls covering the roadbed), and four identical hay market stalls are placed in perfect mirror symmetry around the junction — reads as two generators ignori
  fix: Add road polygon to the ruin/foundation exclusion mask in zone_builder, and jitter/vary market stall placement (different rotations, counts, offsets) instead of 4-corner mirroring.
- MAJOR: Tree confetti: single trees sprinkled at near-uniform density across the whole map — no copses, no forest blobs, no honest clearings; small graveyard patches (3-9 stones) likewise float context-free in open grass in four separate spots.
  fix: Switch tree scatter to clustered distribution (poisson + clump kernel) forming 3-5 named copses with open meadow between; merge the stray gravestone patches into the central pit-graveyard or fence the
- MAJOR: Dead outer ring: roughly 60% of the map (far SW, far SE, far N corners) is empty grass with only confetti trees — all content is clumped within ~15% of the crossroads.
  fix: Either shrink the zone bounds in zone_defs or have zone_builder place one secondary POI per outer region (farmstead, shipwreck, shrine, log camp) with a path spur.
- MINOR: South road terminus is ambiguous: paving fades out at y~1878 (~40px above the south edge) with loose crates scattered in grass at the end — reads as a dead-end rather than a gate.
  fix: Extend the road spline to the south gate coordinate and move the crate dressing to the road shoulder.
- MINOR: Prop-on-road collisions: gravestones and statues stand on the E-W road surface west of the river, and one gravestone clips into the river bank.
  fix: Add road and water polygons to the gravestone scatter exclusion mask in zone_builder.
- MINOR: The black pit centerpiece renders as a featureless soft-edged flat black ellipse — at macro it looks like a missing texture / render hole rather than a chasm.
  fix: Give the pit sprite interior detail (depth rings, cracked rim tiles, faint interior glow) so it reads as a chasm at zoom-out.
- MINOR: East-side street houses are fused into one continuous vertical wall of overlapping roofs (~5 buildings stacked with roofs intersecting), reading as a z-sort pile-up rather than a terrace.
  fix: Enforce minimum vertical spacing (or explicit row-house terrace prefab) in zone_builder building placement along N-S streets.

## drowned_quarter — D (wallpaper=True)
one_image: NONE as-shipped; the closest candidate is the overgrown twin-gabled dark manor flanked by a ruined stone watchtower and a broken pillar at (2580-3000, 500-730) — good silhouette and decay dressing, but it floats in bare 
- CRITICAL: The only N-S road dead-ends in open grass at BOTH ends — it starts at y98 (map top edge is y32) and stops at y2061 (bottom edge y2127); it never touches a gate.
  fix: In zone_defs, snap the road spline's first/last nodes to the zone boundary (y<=0 and y>=5120 world) so zone_builder stamps gate-to-gate; add gate props at both exits.
- CRITICAL: The E-W road also dead-ends in open grass ~230 world px short of the east edge, and west of the crossroads there are ZERO roads in the entire west half of the map — none of the five building clusters (NW hamlet, NW manor, SW tower, NE manor) is connected to an
  fix: Extend the east arm to the east gate; add a west branch from the crossroads (1920,1085) to the coast, with spurs to the NW hamlet (1290-1470,760-980) and NE manor (2630-2990,560-720).
- CRITICAL: The river crosses the only road with NO bridge — pale road slabs are visible through the translucent water band, so the road just fords 60px of open river.
  fix: zone_builder: stamp a bridge prefab wherever a road spline intersects the river spline; make it a rule, not a manual placement.
- CRITICAL: The river terminates in a rounded debug-capsule cap in open ground just short of the east edge, and its west mouth is a second capsule cap stamped ON TOP of the sea with its own dark outline ring instead of merging into coast water.
  fix: Extend the river polyline past zone bounds on the east; at the west mouth, clip the river's outline/cap against the sea layer so water merges seamlessly.
- CRITICAL: Port-biome zone named 'The Drowned Quarter' contains zero port or drowned signifiers: the sea is a featureless flat navy strip with a razor-straight vertical shoreline for the full 5120px — no beach/mud transition, no dock, pier, boat, wreck, net, crate, or fl
  fix: zone_defs signature-prop set: shoreline transition tiles, a dock/pier prefab with moored boats, a half-sunk wreck, waterlogged ruins/stagnant pools inland to sell 'drowned'.
- MAJOR: Wallpaper ground: the grass reads as one flat olive field at macro — measured per-channel std is only ~5-7 in open patches, so the faint cloud-shadow mottle vanishes when zoomed out.
  fix: Add higher-contrast grass variant tiles plus dirt/mud/waterlogged dark patches in the ground pass; drowned theme wants boggy discoloration near the coast and river.
- MAJOR: Confetti trees: single trees sprinkled at near-uniform 80-150px spacing across the entire map, no forest mass, no honest clearing; tiny pebble/twig litter is evenly sprinkled the same way.
  fix: Noise-masked density scatter in zone_builder: copses of 5-12 trees with tight spacing, wide empty meadows between, litter only around clusters/roads.
- MAJOR: SE quadrant has no anchor — only a campfire ringed by three coffins and a vat-with-coffins cache; no building, monument, or pit in the whole quarter.
  fix: Place one anchor prefab in zone_defs for this quadrant (drowned chapel, tide-pit, or salvage yard) and hang the existing coffin-fire scene off it.
- MAJOR: Roads read as pale razor-edged debug strips: uniform width flat slabs, hard straight edges, right-angle stair-step jogs, and repeating crenellated edge decals — nothing reads as a worn path.
  fix: Worn-path road brush: irregular edge dithering into grass, wheel-rut center-line, occasional missing slabs, curve the splines instead of right-angle jogs.
- MINOR: SW quadrant's main anchor renders as a near-black illegible silhouette against mid-green grass — reads as a missed lighting/tint pass, not a deliberate burnt husk.
  fix: Lift its sprite tint toward the NE manor's readable dark-brown values, or add rim light/window glow so its shape reads at macro.
- MINOR: Formal hedge-parterre garden with fountain floats in open grass, attached to no building, wall, or path — a set piece without a story owner.
  fix: Move it against the NE manor grounds or fence it and run a spur path to it.
- MINOR: A tree sprite is rendered in the out-of-bounds grey padding at the map's top-left corner.
  fix: Clamp prop scatter to zone bounds minus prop half-width in zone_builder.

## grey_piers — D (wallpaper=True)
one_image: NONE. Closest candidates: the twin-gabled black warehouse complex at (x2880,y920) NE — a strong sprite floating in featureless grass with no framing — and the riverbank fishing camp at (x1500-1930,y1720-1930) SW, the onl
- CRITICAL: Zone identity is absent: 'The Grey Piers' (port biome) contains zero piers, docks, jetties, quays, or ships anywhere — the sea is a featureless flat navy rectangle and the whole map reads as a generic green meadow hamlet, indistinguishable from any inland zone
  fix: In zone_defs, build the signature waterfront: stone quay strip along the coast, 2-4 timber piers extending into the sea water, moored boats, cargo/net/crane clusters at pier roots; shift coastal groun
- CRITICAL: No road reaches any zone edge — every terminal dead-ends in open grass ~150 world px short of the boundary, and no road at all goes south to the waterfront (the vertical road L-turns west at the crossroads instead of continuing to the coast).
  fix: In zone_builder, extend all road terminals to their gate tiles at the map edge, and route the vertical road south from the crossroads (x1920,y1400) down to the future quay so the port is connected gat
- MAJOR: Ground reads as one flat olive-green field at macro — only sparse blurry blob-shadows break it; huge blocks are pure flat fill, and the grass hard-cuts to the sea in a razor-straight full-width line with no sand/mud/rock shore transition.
  fix: Add macro-scale ground breakup in zone_defs (dirt/mud patches, dry grass tone islands, coastal shingle band 100-200px deep along the shore) so tonal variation survives zoom-out.
- MAJOR: Tree placement is confetti: near-uniformly spaced single trees sprinkled across the entire zone with no copses, treelines, or clearings.
  fix: In zone_builder, replace even sprinkle with 3-6 tree story clusters (grove, windbreak line along a road, lone sentinel tree) and leave honest empty meadow between them.
- MAJOR: Roads look like debug strips: pale razor-edged rectangular slabs with dark seams, perfectly uniform width, and the diagonal is an axis-aligned staircase of rectangles; no wear, edge dithering, or grass blending.
  fix: Swap road tiles to a worn-path style in zone_defs: irregular edges, wheel-rut center tone, grass encroachment tiles at borders, true diagonal segments instead of stepped rectangles.
- MAJOR: Almost no building addresses the road network — the NW hamlet, north chapel, NE warehouse complex, central manor, and all three SE warehouses float in open grass with not even a path stub to a door.
  fix: In zone_builder, add short dirt spur paths from each cluster's entrance to the nearest road and orient door-side props along the spur.
- MAJOR: SE quadrant anchor is a copy-paste row: three near-identical dark warehouse sprites evenly spaced in a straight line, each with no yard, props, or variation.
  fix: Vary the trio in zone_defs (rotate/swap one variant, offset spacing, add cargo yard + fence + carts between them) or consolidate into one warehouse court composition.
- MAJOR: Props float on the river surface: barrels and a crate chest sit on open water past the bank line, bushes sprout mid-channel, and trees stand trunk-deep in the river.
  fix: Add the river polygon to the prop-placement exclusion mask in zone_builder, or snap bank props to the shore line.
- MAJOR: The river reads as a grey capsule/pipe: uniform ~230-world-px width, flat slate fill with long horizontal streak bands, uniform dark border, and its west end terminates in a fully visible rounded pill cap at the map edge instead of flowing off-map.
  fix: Run the west end through the map boundary at full width in zone_defs, vary channel width, and add ripple/foam and bank-transition tiles.
- MINOR: Untextured tan placeholder squares (missing-sprite look) float in open grass at four separate spots.
  fix: Identify the prop id resolving to the blank tan quad in zone_defs and restore its sprite or delete the instances.
- MINOR: A stray tree renders outside the map rectangle in the out-of-bounds padding at the NW corner, with a corrupt dark-red shadow blob under it.
  fix: Clamp prop spawn positions to zone bounds in zone_builder; remove this instance.
- MINOR: Context-free stamped prop groups: an 8-headstone grave grid in neat rows sits in empty grass with no fence/path/dead tree, and the SW market has two perfect speckled-rubble rectangles with red mushrooms planted in straight rows plus the same checkered-tent spr
  fix: Give the graveyard context (fence, gate path, willow) or move it beside the chapel; break rubble stamps into irregular scatters; swap one tent for a boat or drying-rack variant.

## salt_fens — D (wallpaper=True)
one_image: NONE — closest candidate is the white-gabled chapel at the boardwalk T-junction (image ~x1890,y985) with graves, bench and stakes, but the props are scattered, the junction is a T of two mismatched road tile sets, and no
- CRITICAL: NE quadrant has zero anchors — no building, monument or pit anywhere in image x1927-3362, y32-1080 (~19% of the world); only a lone grave marker at (2900,684) and five small gravestones at (2755-2820,830-855), everything else is confetti trees.
  fix: zone_defs: add at least one NE anchor (ruined salt-house, sunken chapel, or peat-cut pit) near image (2650,550) / world (~5800,1400), and let zone_builder grow the existing gravestone patch at (2780,8
- CRITICAL: The canal/river reads as a debug polyline, not water: uniform ~80-world-px steel-grey stroke with a hard dark outline and fully visible rounded end caps at both map edges; no banks, no marsh transition, no water texture — it is the largest single feature on th
  fix: zone_defs: replace the stroke-rendered river with bog-water tiles plus a mud/reed bank transition strip on both shores; run the water polyline past the map edges so no rounded cap is ever visible in-b
- MAJOR: Roads do not run gate-to-gate: the vertical boardwalk dead-ends in open ground ~150 world px short of the north edge (top at y≈88 vs edge 32) and ~165 world px short of the south edge (ends y≈2065 vs edge 2127); the horizontal road dead-ends ~145 world px shor
  fix: zone_defs: extend all three road polylines to the actual zone-edge gates, and either add an east arm to the T-junction at (1890,1095) reaching the east edge or justify the dead half with terrain.
- MAJOR: No bridge at the map's only road-water crossing — the vertical boardwalk visibly passes underneath the river stroke, whose dark outline runs unbroken across the road (z-order collision, reads as a bug).
  fix: zone_builder: place a plank-bridge prop or causeway tile segment over the canal where the boardwalk crosses, breaking the water outline.
- MAJOR: Confetti, not clusters: trees, dead trees, bushes and skeleton props are sprinkled at near-uniform density across the entire 7680x5632 with no story clusters larger than 3-6 props and no honest empty space; the macro view is a uniform speckle field.
  fix: zone_builder: replace the uniform scatter pass with cluster-seeded placement (dead-tree groves, reed stands along the canal, cleared salt flats) and enforce large prop-free gaps between clusters.
- MAJOR: Wallpaper ground: one brown cracked-cobble tile repeats over the whole map with only faint low-contrast smoke smudges (e.g. around 1670,810 and 3110,575); at macro the ground reads as a single flat brown sheet with zero bog material — no pools, no wet mud, no 
  fix: zone_defs: add 2-3 ground material variants (wet dark mud, moss/algae, standing-water pockets) and paint them in irregular patches, concentrated along the canal and around the salt pans.
- MAJOR: Zone identity fails: the only 'Salt Fens' signal is three small cream ellipses plus one rack/barrel confined to a single SW spot; the dry-brown badlands palette contradicts the bog biome, and a random screen anywhere else reads as generic brown wasteland indis
  fix: zone_defs: repeat salt-pan + harvesting-rack clusters along both banks of the canal in every quadrant and shift the ground palette toward wet grey-olive so the fen reads from any screen.
- MINOR: The horizontal road is built from two mismatched rows (dark slab row over a pale flat row) with razor edges — at macro it reads as a pale debug strip with black dashes, and it uses a completely different tile vocabulary from the vertical plank boardwalk.
  fix: zone_defs: unify both routes on one worn boardwalk/causeway tile set with ragged, broken edges.
- MINOR: Stray tree prop sits on the map's top-left corner, overlapping the out-of-bounds grey padding — looks like a prop defaulted to world origin.
  fix: zone_builder: delete or reposition the prop; add a guard against placements at/outside zone bounds (origin-default check).
- MINOR: Salt pans are flat anti-aliased cream vector ellipses with no crust rim, texture or edge break-up — they read as placeholder blobs even at macro.
  fix: zone_defs: replace the ellipse decals with textured salt-crust patches (rim highlights, cracked interior, irregular silhouette).

## anchorfall — D (wallpaper=True)
one_image: NONE. Closest candidates — the black pit at ~(1640,1650) and the SE manor pair at (2380-2940, 1390-1605) — are both uncomposed: the pit is an unlit flat black oval with a procedural rock ring, and the manors float on bar
- CRITICAL: Road network is an incomplete L that serves nothing: vertical road runs north edge (x~1930,y96) to a junction at (1945,1103), horizontal road runs west from it and dead-ends at (519,1100) ~130 world px short of the west edge; east of the junction the road cuts
  fix: In zone_defs, declare gates on all used edges (N, W, E-or-S harbor gate) and make zone_builder route gate-to-gate through waypoints: junction -> SE manor pair -> waterfront, plus a spur to the pit and
- CRITICAL: Ground is wallpaper: 61% of all map pixels fall in a single color bin (72,72,72) with only +/-8 neighbors; the only breakup is the tile texture's own repeating dot/tick grid (reads as mechanical print pattern at macro) and a few soft airbrush smoke smudges.
  fix: Add 2-3 macro ground layers in zone_builder: large irregular ash/scorch patches, basalt-flow tongues, and cooled-lava cracks at 300-800 world-px blob scale with distinct value shifts; kill or vary the
- CRITICAL: Zone identity absent: biome is 'volcanic' but nothing volcanic is visible — no lava, embers, vents, or basalt, palette is neutral grey/khaki graveyard-wasteland; the 'Anchorfall' harbor read also fails: south water is one flat navy fill with no dock, ship, or 
  fix: Swap/extend the biome tile set in zone_defs with volcanic signatures (ember-glow fissures, lava pools, ash drifts, charred ground) and add a harbor set-piece cluster on the south shore: pier, wrecked 
- MAJOR: Confetti not clusters: dead trees, yellow bushes, and pebbles are sprinkled at near-constant density across the entire 7168px width with no honest empty ground and no dense groves; the few real clusters (gravestone patches at ~(900,800) and ~(2065,1590), coffi
  fix: Replace the uniform scatter pass in zone_builder with cluster generators (Poisson-disk cluster seeds, 5-15 props per seed, falloff density) plus explicit keep-clear zones; cut total scatter count ~40%
- MAJOR: NW quadrant has no anchor: across a quarter of the world the largest built object is a ~40-image-px hut at (1296,838) and a 6-stone grave patch at (900,800); the top-north band (y82-500) is empty except the road strip.
  fix: Add at least one anchor to the NW quadrant's zone_defs anchor list — e.g. a ruined watchtower, ash-buried chapel, or steaming vent field — placed on/near the existing road so the road earns its route.
- MAJOR: The signature pit is a flat pure-black ellipse with a suspiciously even ring of ~10 rocks and no rim shading, depth gradient, or glow — reads as a paint blob, and as a volcanic-zone pit it is inexplicably lightless.
  fix: Give the pit a rendered rim (banded depth shading, broken edge tiles) and an interior ember/lava glow in zone_builder; jitter or hand-place the rock ring; route the road spur to it to promote it to th
- MAJOR: Anchors are unmoored set-dressing: both SE manors, the chapel and well sit directly on bare wallpaper with no yards, fences, ground aprons, or connecting paths, and the black tower at (2986-3066,1160-1325) is a near-solid silhouette that reads as an unfinished
  fix: In zone_builder, stamp each anchor with a ground apron (dirt/flagstone), a fence or wall fragment, and a path link to the road graph; give the tower readable lit detail (windows, ember glow, roof high
- MINOR: Roads are razor-edged uniform-width flagstone strips, perfectly axis-aligned for their entire length with zero edge wear, fray, or meander — debug-strip look.
  fix: Enable edge-dither/wear pass and low-amplitude waypoint jitter in the zone_builder road brush; scatter wheel-rut and trampled-grass decals along shoulders.
- MINOR: Procedural placement tells: a straight row of 8 evenly spaced NPCs at (2066-2156,1690) reads as a debug spawn line, matching the evenly spaced rock ring at the pit.
  fix: Add position jitter and pose variety to NPC spawn groups in zone_defs, or bind them to a story cluster (funeral procession at the graves) instead of a raster line.

## the_archive — D (wallpaper=True)
one_image: Marginal yes: the ceremonial N-S axis at image x~1915 — dark manor (1870-2010, 290-390), glowing shrine (1915,460), gatehouse house (1915,605), mossy checkerboard plaza (1860-1975, 730-840), south hall — flanked by twin 
- CRITICAL: Capital reads as a 7-building hamlet, not a city: 1 manor, 4 houses, 2 tiny chapels loosely scattered around an unpaved plaza with open snow between every structure — no dense urban core, no streets, no walls or districts.
  fix: zone_builder needs a capital-core template for the_archive: 20+ buildings in ring/grid blocks around the plaza, internal paved streets connecting doors, fences/walls enclosing the core so a random scr
- CRITICAL: Road network fails gate-to-gate: the only road is one N-S segment reaching just the south edge; it dead-ends in open snow at the top, ~700 world px short of the plaza, and there is no road to the north, east, or west edges and no E-W road anywhere on a 10240px
  fix: in zone_defs extend the road north through the statue avenue and plaza to the north gate; add an E-W gate-to-gate road crossing at the plaza; spur short paths to each building door.
- CRITICAL: Vegetation is pure confetti: single trees, rocks, and moss tufts sprinkled at near-constant density across the entire zone with zero groves, zero clearings — every tree stands alone at ~400-600 world px spacing.
  fix: replace uniform scatter in zone_builder with clustered placement (Poisson-disk cluster seeds, 5-15 trees per grove, varied density) and leave honest empty snowfields between groves.
- MAJOR: Road looks like a debug strip, not a worn path: uniform 1-tile width, razor edges, dead straight for ~4000 world px with two abrupt 1-tile lateral jogs; no wear, fading, or width variation.
  fix: worn-path pass: dither road edges into snow, jitter width, add gentle curvature and trampled-snow verges in the road painter.
- MAJOR: Ground reads as one flat pale-lavender field at macro: the only breakup is pixel-scale speckle and faint fog mottling, both invisible zoomed out; no macro-scale material patches.
  fix: add large (300-800 world px) tonal patches to zone_defs ground layers — packed snow, ice sheets, exposed frozen earth, drift banks — so variation survives zoom-out.
- MAJOR: Bilateral mirror-stamping about the road axis: identical chapel + 3x3 graveyard + 5-stone-row kit duplicated symmetrically left/right, plus twin gravestone rows and twin huts, reading as procedural stamping rather than story placement.
  fix: break the symmetry in zone_builder: randomize per-side counts, rotations, and offsets, or replace one member of each pair with a different POI.
- MAJOR: Dead flanks: all anchors hug the central axis; the west third (x611-1350) and east third (x2500-3228) — roughly 40% of the map — contain nothing but confetti except a 3-prop coffin camp and one tiny ruin tower.
  fix: add one mid-size anchor per flank in zone_defs (frozen library ruin, excavation pit, watchtower) at roughly x~1000 and x~2900 latitudes.
- MAJOR: Zone identity fails at macro: nothing visible says Archive — generic gothic houses, graveyards, and snow could be any tundra zone; no shelf rows, scroll racks, scriptorium, or other archive-signature props readable when zoomed out.
  fix: add archive-signature set-pieces to the prop palette: ruined giant bookshelf walls, ledger-crate stacks, lectern monuments, paper-strewn courtyards near the plaza and along the road.
- MINOR: Lamp and campfire glows are blown-out white discs (~230 world px radius) that outshine every building at macro and read as rendering artifacts on daytime snow.
  fix: reduce glow energy and radius, warm the tint, use additive falloff instead of a saturated white core.
- MINOR: Stray out-of-bounds prop: a bright-green summer-palette leafy tree renders in the grey padding at the exact NW map corner — likely a prop defaulting to world (0,0), and wrong biome palette for tundra.
  fix: guard zone_builder against unplaced props falling back to origin; ensure tundra tree variants only.
- MINOR: The dressed road terminus (lamp, signpost, crates) and the flanking statue avenue sit on bare snow — the paired statue rows start ~70 image px north of where pavement ends, so the avenue frames nothing.
  fix: extend the pavement through the statue avenue as part of the north road connection.

## ledger_roads — D (wallpaper=True)
one_image: Borderline, effectively NONE. The only candidate is the central crossroads (img 1650-2400 x 880-1420): crossing slabs, two manors, lamp glow, torch-bearing figures, red cart. It is undermined by the two manors being the 
- CRITICAL: Confetti, textbook case: single dead trees, bone-white snags and tufts sprinkled at near-uniform ~150-300 world-px spacing across the entire 7680x5632 field, with only three honest clusters in the whole zone (campfire vignette img ~1160,705; grave clusters img
  fix: In zone_builder scatter pass, replace uniform random scatter with cluster seeding: 3-8 tree copses with clearings between, pull ~60% of singles into copses hugging road edges and anchors, and leave ge
- CRITICAL: Anchor distribution fails: SW quadrant has no anchor at all (only a lone glowing framed grave at img 1233,1435 and a 5-headstone row at img 1565,1650 — neither is a building/monument/pit), and every real anchor (both manors img 1786,902 and 2085,1250, tower ru
  fix: Add landmark defs in zone_defs: SW quadrant a toll-house or watch ruin near world (1600,4600); far NE a ruined waystation near world (6200,1400); far SE a pit or chapel ruin near world (6300,4700). Mi
- CRITICAL: Three untextured flat-color quads (one tan ~27 world px, one grey, one light-tan) render as solid squares with zero pixel detail at 6x zoom — missing-texture sprites or leftover debug ColorRects sitting in open grass by the south road end.
  fix: Locate the south-gate props in the zone_defs composite whose texture path fails to resolve (or stray ColorRects in the builder composite) and point them at real crate/signpost sprites or delete them.
- MAJOR: Roads do not run gate-to-gate: all four arms stop ~160 world px (~5 tiles) inside the zone boundary and dead-end in open grass with no gate dressing — W end img x=551, E end img x=3287, N end img y=91, S end img y=2068 against map rect img 492-3347 x 32-2127.
  fix: Extend road segment endpoints in zone_defs to world 0/7680 (x) and 0/5632 (y) so slabs touch the seams, and drop gate posts or waystones at each of the four exits.
- MAJOR: Roads read as debug strips: pale grey slab bands with razor-straight parallel edges for their full ~7000 world px length, no wear, no dirt shoulder, no overgrowth breaks; the horizontal road (wide, large-slab tile) and vertical road (narrower, small-slab tile)
  fix: In the zone_builder road painter: jitter/erode edge tiles, scatter dirt-wear and grass-encroachment decals along shoulders, break slabs randomly, and use one slab set for both axes at the junction.
- MAJOR: Ground is one olive-green tone across the entire world; the only macro variation is soft dark smudge blobs that read as camera vignette, not ground material — no dirt patches, dead-grass tone, or litter visible zoomed out, and the pea-green base is bright for 
  fix: Add second/third ground tones as scattered macro-scale decals (dry-dirt patches, dead-grass swathes, leaf litter) per the ground-breakup rule — decals, not accent tiles in the sheet (stripe pothole).
- MAJOR: Zone identity is anonymous and its only two buildings are the same manor sprite duplicated a half-screen apart; nothing on screen says 'Ledger Roads' — no toll barrier, signposts, milestones, or notice boards along either road; any screen away from the crossin
  fix: Swap one manor for a distinct landmark (toll house with barrier arm, ledger-office ruin) and seed signpost/milestone/notice-board props at intervals along both roads as the zone signature in zone_defs
- MAJOR: Stray default-position prop: a lush green summer-canopy tree sits at the exact NW map corner, half outside the playfield, in a palette alien to the deadforest biome — classic sprite spawned at world (0,0).
  fix: Find the prop entry with missing/zeroed position in the zone def (or a builder spawn that defaults to Vector2.ZERO), remove or re-place it, and use a deadforest tree sprite if kept.
- MINOR: Five identical gravestones stand in a perfectly straight, evenly spaced line floating in open field — mechanical placement with no fence, mound, or framing.
  fix: Jitter positions and spacing, mix stone variants, and enclose with fence stubs, a mound, or a dead tree so it reads as a burial plot, not an array loop.
- MINOR: Neither manor connects to the adjacent road: no path, apron, or trampled approach from the doors to the slabs; both buildings float on untouched grass beside the highway.
  fix: Add short dirt-path connector strips and door aprons to the manor landmark composite in zone_builder.

## coldharbor_deep — D (wallpaper=True)
one_image: NONE at standard. Nearest candidate: the NE funerary ensemble — blue tomb with open dirt grave (img ~2255,620), grave pair (~2045,870), glowing brazier shrine with amphora and two luminous plants (~2160,990), row of 5 he
- CRITICAL: Zone has zero roads: no path of any kind reaches any of the four edges, and no gate markers are visible on any edge — the entire 4096px map is trackless open rock.
  fix: zone_defs: define N/S/E/W gates and add gate-to-gate worn-path splines (cave dirt / trodden stone, irregular edges) routed past the NE funerary core and both crystal pockets; zone_builder: stamp path 
- CRITICAL: The only linear feature is a one-tile-wide pale slate strip, razor-edged and untextured, that dead-ends in open ground at BOTH ends — top stops ~200 world px short of the north edge, bottom dies at map center; it reads as a debug divider, not a wall or road.
  fix: zone_builder: either commit it as a ruin wall (add corner returns, rubble piles and a proper breach at both terminations, connect top to the north edge) or delete it; if it was meant as a road, swap t
- CRITICAL: NW quadrant has no anchor: its upper ~80% contains only pebble/moss confetti, one candle-lit note, and a corner-clipped rock pile; the sole POI (small 3-crystal glow pocket) sits on the quadrant's south boundary.
  fix: zone_defs: add 1-2 anchors in NW — e.g. collapsed mine-head or wrecked boat (fits 'Coldharbor') plus a crystal vein cluster — around img (1300,500) / world (~890,950).
- MAJOR: Ground is wallpaper: one rock material edge-to-edge with visibly repeating plate/tile grid; brightened luminance interquartile range is ~0.007 — only variation is two barely-perceptible teal fog washes.
  fix: zone_builder ground pass: blob-brush a 2nd/3rd terrain at 10-20% coverage (dark silt, cold gravel, standing black-water pools per the zone name) and seed moss/lichen fields radiating from the crystal 
- MAJOR: Confetti scatter: tiny props (pebbles, moss tufts, yellow sprigs, lone papers) sprinkled at near-even density across all open rock, plus isolated crate stacks floating with zero story context.
  fix: zone_builder: cull ~60% of singleton scatter, re-seed the remainder into clusters hugging anchors and future roads; give every crate stack a camp/cart/excavation context or delete it.
- MAJOR: Zone identity fails the random-screen test: outside 5-6 small POIs every screen is anonymous dark rock — could be any cave zone; despite the name 'Coldharbor Deep' there is no water, dock, ice, or harbor motif anywhere.
  fix: zone_defs: define a signature kit (black-water pools, mooring posts/wreck timbers, pale-blue crystal runs) and repeat it along roads so any screen carries at least one identity prop.
- MAJOR: No composed 'one image': the best material (tomb, brazier shrine, headstone row) is diluted into four mini-groups separated by 200-400px of empty rock, and the headstone row sits in an unnaturally straight line detached from everything.
  fix: zone_builder: compress the ensemble into one ~600x500 world-px composition — tomb as centerpiece, headstones arced around it, brazier as key light — and tie it together with fencing and a path spur.
- MINOR: Rock-pile prop at the exact NW map corner is more than half clipped outside the playable rect, overhanging the out-of-bounds border.
  fix: zone_builder: nudge the prop fully inside bounds or delete it; add a bounds-overlap check to prop placement.
- MINOR: Razor-edged pale squares (white/blue and beige tiles) float context-free in open rock near the north-center — at macro they read as untextured placeholder/debug tiles.
  fix: zone_builder: replace with real sprites (note, crate, rune tile) placed within a cluster, or remove; audit for other unresolved placeholder IDs.
- MINOR: Glow rhythm is lopsided for a cave: west third (x<1300) is entirely unlit, and no glow marks any entrance/exit, so navigation reads dead on the left half of the map.
  fix: zone_defs: place a glow beacon (brazier or crystal) at each gate and add 1-2 crystal pockets in the west third to establish a light cadence.

## morven_reach — D (wallpaper=True)
one_image: NONE — the only candidate is the charred twin-gabled ruin at (2905,1700), a genuinely distinctive silhouette, but it floats unframed on empty flat lawn with no approach path, no burnt-ground ring, no supporting props, so
- CRITICAL: Port identity is absent: the entire 'sea' is a bare ~105px flat navy strip (x490-595, full map height) with zero docks, piers, boats, quays, or waterfront buildings, and no settlement faces the water — a random screen reads as generic inland meadow, never as a
  fix: zone_builder: build a harbor set piece as the zone's signature — pier planks extending into the water, 2-3 moored boats, stacked cargo crates/nets, a quay-side warehouse row facing the shore; widen th
- CRITICAL: Road network fails gate-to-gate everywhere: the zone has one T-shaped road whose west arm dead-ends at the corner house mid-map (x1930,y1090), whose east arm stops at x3289 — 58px of open grass short of the east edge (3347) with a razor-flat cut end, and whose
  fix: zone_defs: place gate nodes on all four edges (west gate = harbor); zone_builder: extend east and south arms through the boundary, run a west arm from the junction to the waterfront, and spur worn pat
- MAJOR: Ground reads as wallpaper: a single grass hue over the whole ~2850x2100 field (sampled sd ~5.5/255); the only variation is soft dark blob smudges that read as cloud shadows or leftover fog, not ground material — no dirt, sand, or coastal transition anywhere, a
  fix: zone_builder ground pass: add a sandy strand band along the west shore, trampled dirt under and around every building cluster, and 2-3 meadow-tone patch variants scattered at readable macro scale.
- MAJOR: Confetti trees: the same single oak sprite is sprinkled at near-uniform density across the entire map with almost no doubles or copses and no deliberate clearings — classic even sprinkle.
  fix: zone_defs scatter: replace uniform density with 4-6 clustered woods (6-12 overlapping-canopy trees each) plus honest open meadow between; keep lone trees only as deliberate accents near set pieces.
- MAJOR: SW quadrant has no anchor: from x490-1918 / y1073-2127 the only content is a small campfire-and-coffins camp (1430-1500,1590-1650) and a ~6-headstone patch (900-935,1140-1175) — no building, monument, or pit of anchor weight.
  fix: zone_defs: add one building-scale anchor tied to the biome — a fisherman's shack with slipway on the shore (~x650,y1700), or a beached wreck hull on the stream bank.
- MAJOR: The stream is rendered as a debug pipe: uniform-width blue-grey polyline with rounded line caps — its west end is a blunt round cap butted onto the sea strip (no river mouth), banks are razor-parallel with no ripple/foam/bank texture even at native resolution,
  fix: zone_builder: rebuild as tiled water with irregular banks, open the west end into a proper mouth/delta at the sea, add ripple decals, and place a plank bridge where the new west road crosses it.
- MAJOR: All building groups float on untouched lawn: the NW four-cottage village (1350-1680,480-900), NE manor (2160-2480,475-590), white chapel (2655-2720,395-485), and SE ruin (2800-3010,1635-1770) have no dirt aprons, yards, fences, or door-stub paths — they read a
  fix: zone_builder: stamp trampled-earth aprons under each cluster, add fence/garden clutter at edges, and run path stubs from every doorway into the road network.
- MINOR: Untextured placeholder blocks: five or six flat single-color squares (orange/tan/grey cubes with no sprite detail) are scattered beside the south road terminus, reading as unfinished debug props.
  fix: swap for real crate/barrel/sack sprites in zone_defs prop table, or delete.
- MINOR: Stray tree planted at the exact zone origin corner, half-overhanging the out-of-bounds grey and the sea corner — a scatter clamp bug.
  fix: clamp scatter placement to the land mask in zone_builder; remove this instance.
- MINOR: Horizontal road weaves via abrupt half-width vertical jogs where segments misalign — it reads as a staircase of offset rectangles, not a worn curve; edges elsewhere are dead straight over ~1400px.
  fix: zone_builder road pass: smooth segment anchors or add transition tiles at jogs; add edge-noise/wear decals along the full run.
- MINOR: Identical thin cyan wave ticks repeat down one column of the sea strip at fixed ~240px intervals — an unrandomized decal column that reads as a tiling artifact.
  fix: jitter wave-decal x/y and rotation in the water scatter pass.

## last_hearth — D (wallpaper=True)
one_image: YES, barely — the crossroads south of the longhouse tavern at image ~(1750-2150, y 950-1250): burning campfires, fallen red war-banners on the road, lantern posts, sheep and the shrine statues behind. It reads as a delib
- CRITICAL: The entire road network touches zero zone edges: the west arm dead-ends in open grass at image x~596 (~160 world px short of the west edge at x~523) and the south arm dead-ends at y~2054 (~155 world px short of the south edge at y~2124), so the L-shaped road c
  fix: In zone_defs, define road polylines gate-to-gate and have zone_builder snap both endpoints to the actual edge-gate coordinates (west gate and south gate), extending each arm the last ~5 tiles to the b
- CRITICAL: Wallpaper ground: the whole 6144x4608 field is one flat olive fill with only soft shadow blobs — no second grass tone, dirt patches, heather, or tile variation visible at macro, and nothing says 'moor' for a moor-biome zone.
  fix: Add a ground-breakup pass in zone_builder: noise-driven splats of a darker/browner grass variant plus moor signature patches (heather, peat/bog stains, scattered sedge) at 10-20% coverage so the macro
- MAJOR: Confetti not clusters: outside the village core (~65% of the map) trees are an even one-at-a-time sprinkle with no copses, clearings, or story groupings — the NW quadrant especially is ~3000x2300 world px of nothing but evenly spaced single trees.
  fix: Replace uniform scatter with clustered placement in zone_builder (Poisson cluster seeds, 3-7 trees per copse with honest empty moor between) and thin the singles by ~40%.
- MAJOR: NW quadrant has no anchor: its only content is spillover from the village longhouse at its extreme SE corner plus four orphan crates — no building, monument, or pit anywhere in the quadrant body.
  fix: Add one anchor to zone_defs in the NW body (ruined watchtower, standing stones, or an abandoned croft) around world coords matching image ~x1100,y500, and hang the existing crates off it as dressing.
- MAJOR: Roads read as pale razor-edged debug strips, not worn paths: hard straight outer edges, brick-wall seam pattern in the slabs, and inconsistent width (horizontal arm ~2 tiles wide, vertical arm ~1 tile wide).
  fix: Swap the road brush in zone_builder to a worn-dirt/cobble-mix tile with dithered grass-eaten edges, unify width to one standard, and break the straight edges with edge-noise and wheel-rut variants.
- MAJOR: Zone identity collapses outside the center: a random screen from the outer ring shows generic olive lawn plus one tree and could be any zone — the hearth/fire identity ('The Last Hearth') exists only in the central ~15% of the map.
  fix: Seed signature identity props through the ring in zone_defs: extinguished/abandoned campfires, burnt cart wrecks, cairn waymarkers along the road, distant smoke plumes — 1 per screen-sized cell so eve
- MAJOR: All secondary POIs float pathless in open field: the hermit shack, the 5-stone graveyard, and the gibbet/judgement cluster have no trail, fence, or ground-wear connecting them to the village or road.
  fix: Have zone_builder stamp worn dirt footpath splines from the vertical road to each POI, and give the graveyard a low fence + dead tree + gate so it reads as a place rather than pasted stamps.
- MINOR: Four pale crates sit evenly spaced on a diagonal in open grass north of the west road with zero context — reads as ctrl-V confetti, not a story beat.
  fix: Either delete them or convert to a story cluster in zone_defs: overturned cart + spilled crates + crows at the road's west end, tying into the dead-end fix.
- MINOR: A stray tree with a corrupt-looking dark maroon shadow blob renders on the grey out-of-bounds padding at the map's NW corner, outside the playable rect.
  fix: Clamp prop placement in zone_builder to the world rect (reject/reproject any prop whose AABB crosses the zone boundary) and delete this instance from zone_defs.
- MINOR: A single orphan road-slab tile floats in open grass ~25px south of the west road arm — leftover debug/misplaced paint.
  fix: Remove the stray cell from the road layer; add a zone_builder lint that flags road tiles with no orthogonal road neighbor.

## finalized_fields — D (wallpaper=False)
one_image: YES — the chapel funeral west of the crossroads, centered ~image (1680,1055): tiny gabled chapel, six mourners, a lit candle row, lamp post, dead snag, pedestal monuments and a signpost, with the road glow to the east. S
- CRITICAL: All three road arms stop ~65 image px (~160 world px, ~5 tiles) short of the zone edges and dead-end in open grass — pixel-verified: N end at y=98 vs map top y=32, S end at y=2061 vs bottom y=2127, E end at x=3319 vs right edge x=3386; the identical shortfall 
  fix: In the finalized_fields road spec (zone_defs) or the road-length math in zone_builder, extend each arm to the true world edge (y=0, y=5120, x=7168) instead of edge-minus-margin; re-run validate_travel
- MAJOR: The entire west half of the zone (image x453-1920 = world x0-3585) contains zero road; the 'crossroads' at map center is really a 3-arm T, and the zone's main anchor (chapel + funeral at x1665,y1045) floats 250px from the road with no connecting path.
  fix: Add a west arm gate-to-gate in the road spec, or at minimum a worn dirt spur from the junction to the chapel forecourt so the funeral scene is road-connected.
- MAJOR: Eight near-identical rectangular headstone-grid stamps are laid out on a regular ~490px lattice — same sprites, same neat rows, no rotation/jitter, no fence/dirt/wear beneath — reading at macro as a repeated wallpaper motif instead of story clusters.
  fix: In the grave-cluster landmark def, randomize per-instance count/footprint/stone mix, add underlays (dirt, dead grass, low fence, leaning stones), and break the lattice: pull most plots toward the road
- MAJOR: Trees and withered-shrub props are even-sprinkled at near-uniform density across the whole 7168x5120 map — singles every ~100-200px everywhere, no copses, no deliberate clearings — textbook confetti distribution.
  fix: Replace the uniform scatter in zone_builder's prop pass with a clustered distribution (noise-masked or Poisson-cluster): 4-6 tree copses of 5-12, a few lone sentinels, and large kept-empty moor stretc
- MAJOR: SW quadrant has no anchor: only repeated grave stamps, a razor-straight evenly-spaced row of 5 identical headstones, and 12 NPCs standing in two perfect parade rows in open grass (reads as a spawn grid, not a scene).
  fix: Add one real anchor to SW in zone_defs (gravedigger's hut, mass-grave trench, bone pit); jitter the headstone row and scatter/pose the NPC formation around a focal prop.
- MAJOR: Roads are dead-straight, uniform single-slab-width strips with razor edges for their full 2000px length — textured, but zero wear, fray, grass encroachment, missing slabs, or curvature, so at macro they read as debug scanlines rather than worn paths.
  fix: In the road painter, add edge-break decals (grass tongues, cracked/missing slabs), slight width variation, and a small jog or curve near the junction.
- MINOR: Ground breakup is a single technique — soft dark airbrush blobs that read as cloud shadows (g-channel stdev only ~5 on mean 94) — and the outer thirds of the map read near-flat olive with no second material anywhere (no dirt scuffs, heather, tall-grass patches
  fix: Keep the base sheet uniform per the Bible and add scattered decal accents (dirt scuffs, heather tufts, stone flecks, dead-grass patches) as a second breakup layer in the ground pass.
- MINOR: SE quadrant's only anchor is a knee-high cross-memorial group (two crosses, a pedestal, a snag) — no building, pit, or setpiece; it barely registers at macro.
  fix: Upgrade the SE memorial to a proper monument composite (ossuary, ruined arch, sunken crypt entrance) or relocate a unique setpiece there in zone_defs.
- MINOR: The road junction sits at the exact geometric center of the map (junction rect x1920-1958,y1080-1105 vs map center 1920,1080) and the grave stamps sit on a grid around it, giving the whole layout a centered, procedural silhouette at macro.
  fix: Offset the junction and chapel cluster off-center in the def (e.g. NW third) and let the arms run unequal lengths so the macro silhouette reads authored.

## wilderness — D (wallpaper=True)
one_image: SE goblin camp at ~(2470-2900, 1600-1870): six striped tents ringing a stone plaza with a central bonfire plus a second campfire glow, goblins milling — the only deliberately composed shot in the zone, though it is weake
- CRITICAL: Road network fails gate-to-gate: it touches only the west edge; the east branch dead-ends at a lone gravestone ~50px short of the east edge, the south branch dead-ends in open grass ~80px before the goblin camp plaza, and no road exists toward the north or sou
  fix: In zone_defs, define gate nodes on E and S (and N if a neighbor exists) edges and make zone_builder route roads edge-to-edge through them; extend the S spur the last 80px into the goblin plaza paving 
- CRITICAL: Ground is wallpaper: one flat olive color field across the entire 2240x1760 world — clearings are pure flat fill with only sparse 2px grass tufts, no leaf litter under the dense canopy, no dirt scuffing around camps or the graveyard.
  fix: Add ground-breakup layers in zone_builder: 2-3 tonal grass variant patches (blue-noise blobs, not per-tile noise), leaf-litter/soil decals auto-stamped under tree clusters, and trampled-dirt aprons un
- MAJOR: Roads read as pale razor-edged debug strips: cold light-grey checker tiles in uniform 3-tile-wide dead-straight runs with perfect 90-degree corners, forming a sterile rectangle loop that encircles nothing but trees and serves no destination on its ring.
  fix: Swap the road material in zone_defs to a worn dirt/track palette closer in value to the grass, add width jitter and edge raggedness in zone_builder, and replace the pure rectangle with a curved route 
- MAJOR: Confetti forest: two tree sprites (leafy + twisted-dead) tiled at near-uniform density over the whole map, with dead trees sprinkled evenly instead of grouped; no density gradient, no honest meadows except the rectangular carved POI clearings with abrupt edges
  fix: In zone_builder, drive tree placement with clustered density noise (dense groves vs open glades), gather the twisted dead trees into 2-3 blighted-grove story clusters, and feather clearing edges with 
- MAJOR: SW quadrant is functionally empty: its only anchor, the burnt foundation at (1614-1934, 1404-1574), hugs the quadrant's NE corner and reads as a flat dark smudge with no vertical element; the remaining ~1000x1000px far-SW mass has zero POIs, roads, or landmark
  fix: Add a proper anchor in zone_defs for the far SW (hunter's lodge, standing ruined tower, or shrine) with a path spur, and give the burnt foundation a standing wall corner/chimney so it reads at macro.
- MAJOR: West gate composition is broken: the portcullis archway faces south into solid unbroken forest, the road attaches to the wall's east end rather than passing through the arch, and the wall fragment terminates abruptly mid-forest.
  fix: Reorient or re-place the gate prop in zone_defs so the road passes through the archway toward the west boundary, and extend the wall segment to the map edge so it reads as a real border fortification.
- MINOR: The central graveyard vignette (knight statue, open grave, headstone ring) — the zone's second-best composition — is orphaned from the road network with a ~150px grass gap to the nearest road corner.
  fix: Have zone_builder emit a short worn-path spur from the loop's NE corner to the graveyard entrance.
- MINOR: Faction identity bleed: the hostile goblin camp's tents use the identical cheerful green/white and red/white striped market-stall canvas as the friendly NW trader stall, so the enemy camp reads as a farmers' market from any distance.
  fix: Add a goblin tent variant in zone_defs (dirty hide, patched red-brown canvas, crooked poles) and reserve the striped canvas for merchant props.

## chamber_depths — F (wallpaper=True)
one_image: Closest candidate: the road's north terminus — a lantern-lit open grave with headstone, two flanking gravestones and hanging roots at x1907,y522 ('the road ends at an open grave' is a genuinely strong beat) — but it is u
- CRITICAL: Zone is ~85-90% empty: outside a thin center band the entire map is bare repeating cave tile with an even 1-tuft-per-few-tiles sprinkle (pure confetti, zero story clusters).
  fix: In zone_builder, raise prop budget ~4-5x and replace the uniform scatter pass with cluster generators (cairn fields, bone piles, collapsed pillars, crystal veins) anchored to 8-12 seeded POIs; enforce
- CRITICAL: Road network fails gate-to-gate: the single N-S road dead-ends at a lit open grave ~900 world px short of the north edge, there are zero E-W roads, and the cave-entrance gate clipped into the NW corner has no road serving it at all.
  fix: In zone_defs set road endpoints to actual gate records on the north and south edges (extend N segment y522 to map top y32) and add at least one E-W spine; route a spur from the NW corner entrance to t
- MAJOR: Ground is wallpaper: one identical cobble tile edge-to-edge over 4096 px with no second material, no rubble/dirt/moss fields, no tonal zones — at native cave exposure it reads as a single flat near-black plane (lum std ~4/255) and even gamma-brightened it is o
  fix: Add 2-3 ground-variation layers in zone_builder (darker wet-stone patches, pale dust/bone-dust aprons around POIs, scree fields near walls) as large blobby masks so breakup survives zoom-out; caves ma
- MAJOR: Road reads as a pale razor-edged debug strip: uniform 2-tile-wide rectangular grey slabs, full-contrast against near-black ground, with mechanical 1-tile jogs, no wear, no edge dithering, and it stops ~70 px short of the south edge.
  fix: Swap road material to a worn-path tileset 2-3 shades above ground value (not near-white), add edge transition tiles and width jitter in zone_builder's road pass, and extend the final segment to the ac
- MAJOR: NW quadrant has no real anchor: its only feature is one small lit grave sprite; no building, monument, or pit — and the entire map contains zero structures of any kind.
  fix: Add a proper anchor entry in zone_defs for NW (collapsed chapel ruin, bone pit, or mine-shaft head) and at least one large set-piece structure map-wide; a 30 px lantern-grave is dressing, not an ancho
- MAJOR: Untextured solid-color placeholder squares (flat tan/beige/blue-grey chips with no sprite art) are scattered on open ground near the south road.
  fix: These prop IDs are resolving to missing textures — fix the sprite references in zone_defs prop table or remove the entries; they read as debug chips at macro.
- MINOR: Two picket-fence rows flanking the road render at ~40% opacity — ghost-transparent white dashes that read as a broken alpha/render bug.
  fix: Check the fence prop's modulate/alpha in zone_builder placement; either restore full opacity or replace with the standard grave-fence sprite.
- MINOR: Thin pale root/vine props float disconnected on open floor around the road corridor, reading as stray scratch/debug lines at macro since they touch no wall or ceiling context.
  fix: Constrain the hanging-root prop rule in zone_builder to spawn adjacent to wall/edge tiles or above POIs, not on open floor.
- MINOR: Both 5-gravestone rows are ruler-straight, evenly spaced identical combs — obviously procedural, no burial-plot layout logic.
  fix: Give the graveyard cluster generator row jitter, mixed headstone sprites, and 1-2 open/disturbed plots so rows read hand-placed.
- MINOR: All six glow POIs (3 lantern-graves, brazier, 2 crystal patches) sit in the center third of the map; the outer ~60% of a dark cave has zero light pops, so at native exposure those regions are unreadable void with no landmark to navigate by.
  fix: Redistribute 3-4 additional glow sources (crystal veins, fungal patches) into the outer ring in zone_defs, one per empty corner, to give the darkness navigational rhythm.

## black_night — F (wallpaper=True)
one_image: NONE — the closest candidate is the north manor at (1914,730) framed by flanking gravestone rows at the road head, but the identical manor sprite repeated six more times below it and the symmetric layout kill any sense o
- CRITICAL: black_night is a capital but reads as a sparse hamlet: 7 copies of the SAME large manor sprite plus 4 identical tiny huts arranged in near-mirror symmetry around a bare road crosshair, with no dense urban core, no plaza, no walls, no building variety.
  fix: In zone_defs give black_night a city-core spec: dense district of 15+ varied building footprints (use every tundra/gothic building variant, not one manor stamp), a paved plaza at the crossroads, perim
- CRITICAL: Roads are pale razor-edged uniform debug strips forming a perfect geometric cross, and three of five road ends dead-end in open ground instead of running gate-to-gate: mid horizontal road's west end dies mid-field ~560px short of the west edge; east end stops 
  fix: In zone_builder replace straight-line road segments with gate-to-gate splines that touch all four zone edges, render as worn dirt/gravel path tiles with jittered edges and wear decals; delete or exten
- MAJOR: Wallpaper ground: the entire 10240x8192 tundra reads as one flat pale-lavender field at macro; only faint soft blotches, no visible drifts, ice, or exposed-earth breakup.
  fix: Add a ground-breakup pass in zone_builder: large snow-drift patches, ice sheets, dark frozen-earth scars and frost tone variation at 2-3 scales so variation survives zoom-out.
- MAJOR: Confetti scatter: tiny props (twigs, lone gravestones, pebbles, shrubs) are sprinkled at uniform density across the whole map with almost no story clusters outside the center band.
  fix: Switch zone_builder scatter from uniform random to cluster-based rules: grave copses, frozen thickets, ruin piles of 5-15 props with honest empty snow between clusters; cull the singleton sprinkle.
- MAJOR: All anchors are compressed into the central ~25% of the map; the outer ring of every quadrant is anchor-free (SW's only outlying feature is one small campfire, SE and far NW/NE have nothing).
  fix: Add one peripheral anchor per quadrant in zone_defs (frozen monument, collapsed watchtower, burial pit) and hang the existing grave clusters off them.
- MAJOR: Zone identity fails the random-screen test: any screen outside the center shows featureless pale snow with speckles, indistinguishable from generic tundra; no signature props sell 'Black Night', and the palette is the brightest possible for a zone named for da
  fix: Define 2-3 signature props for black_night in zone_defs (black obelisks, dark banners, crow-covered gallows) and seed them across all quadrants; shift ground/ambient tint darker to match the zone name
- MINOR: Road segment misalignment seams: the upper road steps up then back down mid-span, and the east arm of the mid road has a doubled, vertically offset strip overlapping the main road.
  fix: Snap road segment y-coordinates to a single spline in zone_builder and dedupe overlapping segment entries.
- MINOR: No building is connected to the road network: all manors and huts float in open snow with no door paths, yards, or fences tying them to the cross.
  fix: Have zone_builder emit short worn-path stubs from each building entrance to the nearest road plus yard clutter (fence, woodpile) around each footprint.

## eastern_ridges — F (wallpaper=True)
one_image: NONE — closest candidate is the snow-roofed lodge with the campfire camp at x2620-2840, y680-850, but it is two uncomposed elements on blank grass
- CRITICAL: Zero roads in the entire zone — no gate-to-gate path, no worn track to the lodge, watchtower, or graveyard, nothing reaching any map edge.
  fix: zone_builder road pass: carve one E-W worn dirt road edge-to-edge past the lodge (x2650,y812) and one N-S road through the wall, with soft dirt-blend edges; connect watchtower (x1360,y1125) and gravey
- CRITICAL: Full-width stone wall bisects the zone horizontally with no visible gate or opening and no road meeting it; both sides are identical meadow, so it reads as an arbitrary debug divider, and its segments step/misalign vertically (row offset near x600, seam ~x2410
  fix: zone_defs: add a gatehouse/arch aligned to a N-S road; snap wall segments to one baseline or make each step terminate in a tower; extend ends to the zone boundary
- CRITICAL: Zone identity failure: 'Eastern Ridges' (biome: ridge) contains no ridges — no cliff lines, elevation banding, plateaus, scree, or slope shadows anywhere; a random screen is indistinguishable from generic summer meadow. The lone snow-roofed alpine lodge is the
  fix: zone_defs: add 2-3 NE-SW cliff/ledge tile bands with terraced elevation, rock outcrop fields, and altitude tint on upper terraces; snow-dust the ground around the lodge or swap its roof
- CRITICAL: Confetti scatter: trees, shrubs, and rocks sprinkled at near-uniform density across the full map — no copses, no treelines, no clearings; every corner crop shows the same even spacing.
  fix: zone_builder scatter pass with noise-threshold masks: 5-8 dense copses/pine stands with honest empty meadow between, density ramping toward ridge lines
- MAJOR: Wallpaper ground: single olive-green field with only faint soft dark blotches; no second ground material (dirt, scree, dry grass, rock shelf) visible at macro.
  fix: paint large irregular fields of 2-3 ground variants (scree, dry-grass, packed dirt) in zone_defs ground layers, biased along the future ridge bands
- MAJOR: SE quadrant has no readable anchor — only knee-high props (stone obelisk, open grave plot, pair of crypt doors) that vanish at zoom-out; no building/monument/pit mass.
  fix: place one real anchor (barrow mound cluster, mine pit, or ruined tower) around x2700,y1800 and fold the loose crypt props into it
- MAJOR: NW quadrant anchor is a single tiny ruin fragment (broken tower + one pillar) that does not read at macro; the surrounding ~1400x1000px of the quadrant is empty sprinkle.
  fix: grow into a ruin complex: collapsed wall lines, rubble field, 2-3 standing pillars, so the silhouette reads at zoom-out
- MAJOR: No 'one image': the best candidate — snow lodge plus campfire camp — is two elements dropped on bare grass with no framing, path, fence, or foreground interest.
  fix: compose the lodge scene: trodden path to the door, woodpile, fence line, framing pines, and a worn trail linking the campfire camp to the lodge
- MINOR: Isolated single props floating in open ground with no supporting story: lone red-roofed stall, unfenced 5-headstone micro-graveyard, and detached grave plot.
  fix: merge each into its nearest cluster or dress with 3-5 supporting props (fence, lantern, cart ruts, dead tree)

## blestem — F (wallpaper=True)
one_image: Near-candidate only: the lamplit village street in the west-center — houses fronting the road, three gravestones, lamp glows (img ~1250-1500, 1050-1200) — is the one deliberate composition, but it is hamlet-scale. The ob
- CRITICAL: Blestem is a capital but reads as scattered rural hamlets: only ~28 buildings across the whole 10240x8192 map, no dense urban core, no plaza, no walls, no continuous street frontage; the densest cluster is ~10 houses.
  fix: zone_builder: consolidate a walled urban core around the central crossroads (img ~x1915,y1100 / world ~5130,4280) at 3-4x current density, buildings snapped to street frontage, plaza at the crossing; 
- CRITICAL: Zero roads reach a zone edge — the entire network is an internal cross with 7 dead-ends in open ground (vertical road stops at a shrine top img 1913,533 and in bare grass bottom img 1915,1685; north road ends img 1327,795 and 2540,790; south road ends img 1372
  fix: zone_defs: define gate anchors on all four edges and extend each road arm gate-to-gate; delete or terminate stub ends at real destinations.
- CRITICAL: Wallpaper ground: 92% of map pixels sit within ~±4 RGB of one flat navy value (measured std 2-4/255); the only breakup is a per-tile speckle repeated on the tile grid, which reads as a regular dot lattice, not terrain.
  fix: zone_builder ground pass: 2-3 tone ridge palette (rock shelves, scree, dry grass patches) in large organic blobs; randomize decor phase so speckles stop aligning to the tile grid.
- CRITICAL: Confetti vegetation: one identical tree sprite sprinkled at near-uniform spacing across the whole map with no groves, no treelines, no clearings.
  fix: zone_builder: regroup trees into 5-8 tree groves and ridge-line strips with honest empty ground between; vary species/scale.
- MAJOR: Bottom ~40% of the map is an anchor void — a full-width empty band with nothing but confetti trees, spanning the south of both S quadrants.
  fix: zone_defs: add at least one south anchor per S quadrant (graveyard, pit, watchtower ruin) and run the south gate road through it.
- MAJOR: The signature anchor — the black cursed tower — is pitch black on near-black ground, invisible at zone lighting, floats off-road with no spur or composed approach; only a stray lamppost glows south of it.
  fix: zone_builder: give the tower rim-light/window glow and bat silhouettes against a lit sky-fog patch; add a paved spur from the vertical road with 2 lamps framing the approach.
- MAJOR: The same twin-gable manor sprite is copy-pasted ~12-13 times at identical orientation, none road-adjacent, spread at even intervals across the north half — confetti of buildings.
  fix: zone_builder: cut count in half, vary building types/flips, pull survivors onto road frontage or into 2-3 estate clusters with yards and fences.
- MINOR: Roads are pale razor-edged slab strips of uniform 1-tile width with visible half-tile alignment jogs where segments misregister.
  fix: zone_builder: worn-path treatment (edge dithering into ground, wheel-rut center, occasional missing slabs) and fix the offset segment seams.
- MINOR: Four identical huts placed in a perfectly straight equal-gap row — reads as grid placement, not a settlement.
  fix: zone_builder: jitter positions/rotations, add yard props between them.

## gravemark_tundra — F (wallpaper=True)
one_image: Closest candidate, not hero-grade: the gravedigger camp at image (3030-3110, 1740-1800) — a burning campfire with three coffins arranged as benches, a dead tree and light halo. It is the only deliberate story composition
- CRITICAL: Road network fails gate-to-gate: the zone's single road dead-ends in open snow at BOTH ends and connects to nothing.
  fix: In zone_defs declare west/east gate nodes on the zone border (plus at least one N/S gate); have zone_builder route the road edge-to-edge through the cabin and chapel POIs and spur to the campfire; for
- CRITICAL: Confetti, not clusters: the entire map is a statistically uniform sprinkle of dead trees, olive bushes, stumps, twigs and identical round ice puddles with no density modulation and no honest empty space.
  fix: Replace the uniform scatter pass in zone_builder with cluster seeding (Poisson-disk seeds; dead-tree copses of 5-9, fenced grave plots, ice-sheet fields), zero out scatter density between clusters, an
- CRITICAL: Wallpaper ground: the snow is one flat color field — RGB (202,207,236) is pixel-identical at samples (600,300), (1000,500), (2500,600) and (2800,1800); the only texture is 1px speck noise invisible at macro.
  fix: Add macro-scale breakup layers in zone_builder: snowdrift ridges, exposed frozen-earth/dead-grass patches and ice sheets 200-600px (image scale) wide, plus a low-frequency tonal variation pass so the 
- MAJOR: The one road reads as a pale razor-edged debug strip, not a worn path: perfectly straight grey slab tiles for ~2170px with hard 1px edges, and two copy-paste seams where segments overlap misaligned by one tile row.
  fix: Swap to worn dirt/gravel path tiles with irregular blended edges, allow curvature/waviness in the road spline, and fix segment row-snapping in zone_builder so joints align.
- MAJOR: NE quadrant has no anchor: its largest features are an 8-headstone grid and a 4-stone row — props, not a building/monument/pit.
  fix: Place one anchor-grade structure in NE via zone_defs (ruined watchtower, frozen crypt, or excavation pit) and dress it with its grave clusters.
- MAJOR: Zone identity dilutes to 'generic empty snow': outside ~6 small grave clusters, a random screen shows only flat lavender snow and 2-3 dead trees — the 'Gravemark' signature is absent from most of the map.
  fix: Multiply fenced grave-plot clusters and give each a ground patch/fence so graves read at distance; make headstones the dominant scatter element instead of an occasional one.
- MINOR: Off-biome, out-of-bounds prop: a full-leaf green summer tree straddles the NW map corner, rendered mostly in the grey out-of-bounds padding; map-wide saturated olive-green bushes also read summer, not tundra.
  fix: Clamp prop placement to zone bounds in zone_builder and restrict the tundra flora set to snow-dusted/dead variants.
- MINOR: Placeholder litter near road start: two flat untextured brown rectangles and one orphan grey slab tile floating on snow.
  fix: Remove them or replace with real crate/dirt-mound sprites tied to the signpost scene at (588,1116).
- MINOR: Anchors float undressed: the cabin sits on blank snow with no yard, path, fence, woodpile or ground stain; the glowing grave and obelisk likewise have no supporting props.
  fix: Give each anchor a dressing kit in zone_defs (trampled-snow ground patch, fence segments, 3-5 support props) and connect it to the road network.

## Basaltfang — F (wallpaper=True)
one_image: NONE. Nearest miss is the SW camp vignette (campfire + three caskets + corpse sprites + crates) at ~x1400,y1740, but it sits in featureless grey with nothing behind it; the only prominent building is a wrong-biome snow c
- CRITICAL: Ground is one flat grey field: 90% of the map rect is within +/-6 of a single color (79,79,76), and that color is only ~5 units from the out-of-bounds padding grey (77,77,77), so the playable area is nearly indistinguishable from OOB; the only macro variation 
  fix: zone_defs ground: replace single base tile with 2-3 value-shifted basalt/ash variants plus macro splats (cooled lava flows, scoria patches, ash drifts) at 200-600 world-px scale; shift base palette of
- CRITICAL: Volcanic biome has no volcanic identity: zero lava, zero fissures, zero ember fields — exactly two tiny glowing ember-rock props in the whole 7680x5632 zone; palette reads as generic grey wasteland, unanswerable as 'Basaltfang'.
  fix: zone_defs signature set: add lava-crack glow decals, a lava pool/fumarole anchor, obsidian/basalt-column spires, scorched-red tint zones; zone_builder should seed ember rocks in clusters radiating fro
- CRITICAL: Road network is a single razor-straight vertical strip that dead-ends in open ground at BOTH ends (top terminus y~80 vs map edge y=32, ~130 world px short; bottom terminus y~2090 vs edge y=2127, ~100 world px short) and there is no east-west road at all — the 
  fix: zone_builder road pass: snap road spline endpoints to gate nodes on the N and S zone edges; add at least one E-W route gate-to-gate; route it past the existing anchors (waystation tower, chapel) inste
- CRITICAL: Confetti scatter: single moss tufts, rocks and dead trees sprinkled at near-uniform spacing across all 560 sampled 100px cells (only 1 empty cell); barely 4 genuine story clusters exist (SW camp, road waystation, NE chapel, SE coffin trio) — no honest empty gr
  fix: zone_builder scatter: switch from uniform random to clustered seeding (Poisson-disk cluster centers, 3-10 props per cluster, 60%+ of ground left bare); tie clusters to features (embers near fissures, 
- MAJOR: Road reads as a tile-stamped debug strip, not a worn path: perfectly straight for ~5500 world px with abrupt one-tile lateral jogs and width flicker where segments misalign/overlap; hard razor edges, zero wear, no blending into ground.
  fix: zone_builder: rebuild as a jittered spline with gentle curvature, edge dithering into the ash, rut/wear decals; kill the half-tile segment offsets.
- MAJOR: The brightest, most prominent building in this volcanic zone is a snow-roofed cabin — a wrong-biome asset that actively contradicts zone identity (it is also the only thing the eye lands on at macro).
  fix: zone_defs: swap to a charred/basalt-roof variant of the cabin, or re-skin roof with ash; reserve the bright-value silhouette for a deliberate volcanic landmark instead.
- MAJOR: Anchor coverage fails in the south and west: SW quadrant's only feature is a knee-high campfire camp, SE has only a coffin trio and a small grave shrine (no building/monument mass), and the entire western third (x<1500, ~2800x5600 world px) contains zero struc
  fix: zone_defs anchors: add one building/pit-grade anchor per weak quadrant — e.g. a lava-mine head or collapsed caldera pit in the SW, a ruined basalt watch-bastion mid-west, and grow the SE shrine into a
- MINOR: Stray prop rendered at/over the map corner into out-of-bounds padding: a healthy green summer-canopy tree — the only green tree in the zone and the wrong biome flora.
  fix: zone_builder: clamp scatter placement to zone bounds minus prop half-extent; remove green deciduous tree from the volcanic prop palette.
- MINOR: Road-to-ground contrast is so low (road (82,71,57) vs ground (79,79,76)) that the only road half-vanishes under the smoke overlays at macro, while its razor edges still read mechanical up close — worst of both.
  fix: zone_defs: raise the worn-path material's value/texture contrast slightly (darker rut core, lighter dust fringe) so the route reads at map scale without becoming a pale strip.

## the_gift — F (wallpaper=True)
one_image: NONE. Closest candidate is the twin-gabled timbered church at ~(1660-1770, 915-1060) with grain sacks and a cauldron below it — a good sprite set, but it floats on flat grey with no dirt apron, no fence, no lantern, no p
- CRITICAL: Wallpaper ground: the entire zone is one flat grey-olive fill (mean RGB 78,78,74; p5-p95 spread only 5 levels) that is nearly indistinguishable from the out-of-bounds padding grey (77,77,77), broken only by a machine-regular lattice of tiny dark tick decals al
  fix: In zone_defs give the_gift a volcanic multi-tone base (ash grey + darker basalt + rust-brown) laid as irregular macro blotches, and make zone_builder scatter the tick/pebble decals with clustered blue
- CRITICAL: Road dead-ends in open ground: the zone's only road stops at image y=1853, ~670 world px (~21 tiles) short of the south edge, and its north end starts ~127 world px below the top edge — it reaches neither gate.
  fix: Extend the road def's polyline to the actual gate rows at both zone edges (y=0 and y=5120 world), or terminate the south end at a real destination anchor instead of bare field.
- CRITICAL: No road network: one perfectly straight, constant-width, razor-edged N-S strip on the exact map midline; no E-W route, no curvature, no wear fringe, and zero spurs — the church, cabin, stone hut, shrine field, and stall are all unconnected to it.
  fix: Add jittered/curved path polylines in zone_defs: E-W gate-to-gate if side gates exist, plus short spurs road-to-church, road-to-hut, road-to-shrine-field; have zone_builder feather road edges with dir
- CRITICAL: Confetti scatter: tufts, bare trees, rocks, and bone piles are an even Poisson sprinkle across the whole 7168x5120 map with no story clusters and no honest empty space outside the church and shrine field.
  fix: Change zone_builder scatter for this zone to clustered distribution: groups of 3-8 props (dead-tree copses, rock outcrops, bone fields) with large deliberate gaps between clusters.
- MAJOR: SW quadrant has no anchor: roughly a quarter of the zone contains only one small red patch and a single lone grave sprite in open sprinkle.
  fix: Add one landmark composite to SW in zone_defs — e.g. a lava fissure, ruined watchtower, or burnt farmstead — mirroring an existing landmark def.
- MAJOR: Volcanic identity unreadable: no lava, embers, glow, basalt, fumaroles, or ash drifts anywhere; palette is neutral grey plus olive tufts and generic gothic props, so a random screen cannot be identified as the_gift or even as volcanic.
  fix: Add a volcanic signature set to the builder: ember-glow decals with PointLight2D, lava-crack decals, charred tree variants, ash-drift blotches; commit the red 'gift' patches as the zone's signature mo
- MAJOR: Red 'gift' patches are raw tile stamps: all four rectangles have razor 90-degree tile-boundary edges with zero transition into the grey ground, and carry bright lush-green summer trees that clash with the muted dead palette — they read as misplaced carpet swat
  fix: In zone_builder blend patch borders with dithered/irregular edge tiles and a scorch ring; either recolor the trees toward the zone palette or consolidate the motif into one larger composed 'Gift' site
- MAJOR: All three buildings float in the north half with no ground treatment: church, log cabin, and stone hut each sit alone on bare wallpaper with no yard, fence, dirt apron, path, or outbuildings; south half of the zone has zero structures.
  fix: For each building def add a precinct: dirt-apron decal under the footprint, fence segments, a lantern light, 1-2 satellite props, and a path spur; move or add one structure south of y1080.
- MINOR: Loose crates float on open ground near the north road end — flat saturated orange/grey boxes that read as untextured placeholders scattered singly rather than a stack.
  fix: Cluster the crates beside the existing lantern signpost at x1968,y167 as one caravan-drop composite (stacked, with tarp decal), or delete them.
- MINOR: Lone market stall with a bright gold-striped awning is the most saturated object in the zone and stands alone in an empty field beside the road with no context.
  fix: Mute the awning palette toward the zone tones and merge the stall into the shrine-field POI just north of it, or add companions (cart, barrels, an NPC) in the def.
- MINOR: Large soft dark smudge overlays — the only macro tonal variation — read as dirty-screen smears rather than ash clouds or terrain shading; they have no shape language and no relation to features below.
  fix: Replace the blob vignettes with shaped ash-cloud shadows or tie dark ground-tone blotches to terrain features (around fissures, under prop clusters) in the builder's shading pass.

## sangeroasa — F (wallpaper=True)
one_image: NONE — the natural candidate is the central pit + road bend + signpost lantern at ~(1920,800), but the pit is an untreated pure-black ellipse with no rim, ember glow, or lava, so nothing on the map is screenshot-worthy.
- CRITICAL: Sangeroasa is a capital but reads as a scattered hamlet: ~14 detached cottages across the whole 10240x8192 world, and the densest area is just 4 free-standing cottages with campfires — no urban core, no adjacent buildings, no plaza, walls, or street grid anywh
  fix: zone_builder: build a real city core around the crossroad (~x1920,y1080 image) — 30+ row-house/shared-wall footprints, plaza with market props, perimeter wall or gate arches; demote current cottages t
- CRITICAL: No road arm reaches any zone edge (zero gates): east arm ends in a blunt squared terminus in open ground; the west direction has no road at all (the horizontal road just turns 90 degrees south); south arm dead-ends squared-off in open ground; SW stub dies in o
  fix: zone_defs: extend all four arms to gate nodes on the zone edges; either delete the SW stub or route it to the hidden cabin at (1145,1855).
- CRITICAL: Wallpaper ground: luminance 25th-75th percentile is 52-53 (IQR ~1/255) — the cracked-slab tile detail is far too low-contrast to survive zoom-out, so the entire map reads as one flat mud-brown field with zero macro tonal patches (no ash fields, basalt darks, o
  fix: zone_builder ground pass: paint macro-scale tonal blobs (ash grey, scorch black, iron-red scoria) at multi-tile scale with 20+ luminance spread so breakup reads at map zoom.
- MAJOR: The central pit — the zone's only unique landmark — is a featureless pure-black ellipse with no rim tiles, no ember glow, no lava; it reads as a missing texture / debug void.
  fix: zone_builder: crater treatment — lava/ember core glow, rock lip ring, scorch gradient radiating outward; make it the hero composition.
- MAJOR: Confetti two ways: decor speckles are stamped on a mechanically regular diagonal/vertical grid across the entire map (obvious repeating dot lattice), and single yellow bushes / dead shrubs are sprinkled one-at-a-time at near-constant density with no groves and
  fix: zone_builder scatter: replace grid-pattern decal scatter with jittered/Poisson placement; group flora into 3-7 item story clumps with deliberate bare ground between.
- MAJOR: Anchor distribution collapses to the center band: every anchor sits within x1250-2600 y550-1550, leaving the outer ~45% ring (north band y<550, west band x<1250, east band x>2600, south band y>1550) with no anchor at all — each quadrant passes only via center-
  fix: zone_defs: place one anchor per outer band — e.g. vent field or lava fissure east, gatehouse ruin at each new road gate, shrine or crashed cart south.
- MAJOR: Volcanic identity absent: palette is generic grey-brown mud, green-canopy trees and green bushes grow in the biome (wrong flora), and there are no lava, ash, or ember signature props — a random screen in the outer ring cannot be identified as Sangeroasa or eve
  fix: zone_defs: swap green flora for charred/dead variants; add lava-crack decals, ember emitters, and obsidian rock sets as signature props zone-wide.
- MINOR: Road dressing: all roads are uniform-width, ruler-straight strips with razor edges, right-angle corners, and visible rectangular tile seams — laid tile geometry, not worn paths.
  fix: zone_builder: width jitter, edge-erosion transition tiles, curved corners instead of 90-degree turns.
- MINOR: No building is connected to a road: the SE manor sits ~100px east of the road with no approach path, and every SW/SE cottage floats pathless in open ground.
  fix: zone_defs: add door-to-road spur path segments for every structure.
- MINOR: Suspected untextured placeholder props: four flat single-color rectangles (brown, grey, orange) near the north road show zero texture even at 3x magnification — likely missing crate/prop sprites.
  fix: zone_defs: verify sprite assignments for these prop entries; replace with textured crate/rock assets.