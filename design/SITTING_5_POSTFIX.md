# SITTING #5 — POST-FIX INSPECTION (2026-07-12, 41 zones; verify pass partial, resets 4:30am)

Grades: {'C': 2, 'D': 34, 'F': 5} | wallpaper flags: 39/41


## stonepath — C (wallpaper=False)
one_image: YES — the crossroads burial scene at map center, img (1850-2100, 980-1260): signpost, coffin cart, a grave dug into the road itself, mourner NPCs, statue with cairns, warm lantern glow against olive d
- CRITICAL: Roads fail gate-to-gate on ALL FOUR arms — every arm dead-stops in open grass with a razor cut and no gate/waystone: north arm ends at y=163 leaving ~320 world px of bare grass to the edge, west ends at x=624 (~160 world px short), east at 
- MAJOR: Road geometry is a mechanical plus-sign: two perfectly straight orthogonal strips crossing at the exact map center, razor-straight edges over 6656 world px, with dark accent tiles stamped as full hard-edged squares — reads as a textured deb
- MAJOR: Broken decal artifact: neat 2x6 grids of tiny floating grey rectangles sit in open grass — looks like a fence/cobble composite rendering as placeholder rects; at least two clear instances plus a probable third.
- MAJOR: Copy-paste anchor: the identical 'fresh dirt grave + large cross headstone' composite is stamped four times at the same size, one per quadrant — generator fingerprint visible even at macro.
- MAJOR: Gravestone groups placed as ruler-straight, evenly spaced single-file rows of identical sprites floating on bare grass — one row abuts the road's south edge with no plot, dirt, or fence context; mechanical confetti-in-a-line.
- MAJOR: SE quadrant has no anchor of weight: its only landmark is one small grave composite; a ~2000x650 world-px region east of it is entirely empty olive except three pebbles.
- MAJOR: Tree placement is dominated by even single-tree sprinkle 80-160 world px apart with vast bare plains between; only four honest copses exist (SW campfire copse, NE corner, SE corner, south-center), so quadrant interiors read as confetti + vo
- MINOR: Orphan terrain tiles: four isolated single squares (tan/brown/grey road-accent tiles) stamped in open grass near the west road terminus, disconnected from any road.
- MINOR: Prop leaks out of bounds: a full tree (with shadow) renders on the grey out-of-bounds padding beyond the NW corner of the map rect.
- MINOR: Zone identity is carried only by the center-strip burial motif; the path itself is plain brown dirt — nothing 'stone' about The Stonepath, and any screen away from the road is anonymous olive grass + lone tree.
- MINOR: Base grass between the soft dark smudges is near-flat at macro — tonal breakup relies almost entirely on large vignette blotches, several of which read as caster-less shadow smears rather than terrain.

## town — C (wallpaper=True)
one_image: YES — the fountain plaza (orig ~x1920, y1075): "Old Peira" fountain centered among benches and four lantern posts, two striped market stalls flanking the west edge, inn facade closing the north side. 
- CRITICAL: Roads fail gate-to-gate: the zone's only gate (east gatehouse) is missed — cobbles fade and stop ~50-70px short of the arch with bare grass between, and no road reaches the north, west, or south map edges at all (pixel-scanned).
- CRITICAL: Ground reads as pure wallpaper: one flat olive field across the entire 2240x1600 world — no tonal grass variation, no dirt scuffing along roads or building aprons, no darker litter band under the forest fringe; only tree canopies break the 
- MAJOR: NE quadrant is a dead void: ~1300x620 image px of empty grass with ~8 lone birches in an even sprinkle (confetti); the quadrant's only anchors (forge shed, gatehouse) hug its south/east fringe.
- MAJOR: SW quadrant is near-empty meadow whose only content is an orphan prop trio — crates, a log, and a stone dropped context-free in open grass (textbook confetti, no story).
- MAJOR: Dead-end road in open ground: the south corridor frays into grass short of the well and community garden it obviously serves, leaving both destinations disconnected by ~60-100px of bare ground.
- MINOR: Roads read as pale rigid grid strips: uniform-width corridors with razor-straight edges and perfect 90-degree corners (a full rectangular circuit south of the square), in a value far lighter than the ground.
- MINOR: Central plaza is one flat pale slab — wear/missing-tile treatment exists only on the outer fringe, so the interior reads as an empty grey rectangle at macro despite the fountain.

## western_lowlands — D (wallpaper=True)
one_image: NONE — the nearest candidate is the chapel + farmstead yard row along the south road at image (2195-2700, 1100-1250) (cross-gabled chapel, shed, cottage, fenced well/barrel yard, villagers), but it is
- CRITICAL: Ground is wallpaper: one flat mustard-olive fill (RGB ~114,110,19) across the entire 7680x5120 world — 92.8% of pixels within +-6 luminance of median; the only variation is faint blurry dark smudges and 1-2px specks; no second ground materi
- CRITICAL: E-W road is a razor-edged debug strip: a dead-straight 1-tile band of randomly alternating hard-edged tan/brown full tiles (checkerboard mosaic), zero edge feathering, zero curvature over the full 7680px width, with a visible shade disconti
- MAJOR: N-S road reads as cold slate-grey asphalt (uniform blue-grey fill, lengthwise streaks, hard dark border lines) — palette-alien to the farmland; it crosses the E-W road with no junction/bridge treatment (grey slab simply overlays the tan til
- MAJOR: Farmland identity is absent: zero crop fields, fence lines, haystacks, or plots visible at macro — a random screen in the west or south shows pure olive void indistinguishable from any grass zone; the one windmill and the sheep pair are too
- MAJOR: Massive dead zones: the lower two-thirds of the SE quadrant is empty olive with only two tiny grave clusters, and the western third of the NW quadrant has nothing but a clipped stray sprite — each dead area spans roughly 1500x1000+ image px
- MAJOR: Every building cluster floats on bare grass with no connecting path, yard, or ground transition — the NE hamlet, the barn, the NE farmhouse, and the SW farmhouse are all disconnected islands ~150-350px from the nearest road.
- MINOR: Confetti noise: 1-2px pebble/twig specks are sprinkled evenly across the whole field, and single lone trees dot open ground between the honest 2-5 tree clumps — an even sprinkle rather than story clusters.
- MINOR: Two gravestone clusters float in open field with no fence, path, or tree framing — they read as misplaced props rather than burial vignettes.
- MINOR: Placeholder artifacts: flat hard-edged tan/blue rectangles float near the east gate (read as unrendered decals), plus a thin clipped brown sliver sprite alone in the NW void.

## famine_fields — D (wallpaper=False)
one_image: Closest candidate is the famine tableau at orig px (2200-2620, 1290-1510): ruined column, cairn, dead stumps, empty granary basket, open pit, glowing brazier, rat/boar packs. It is the only deliberate
- CRITICAL: The zone's only road dead-ends in open grass short of BOTH zone edges — west end stops at image x506 (map edge x453, ~130 world px gap), east end stops at x3359 (edge x3386, ~66 world px gap) — violating gate-to-gate and creating two dead-e
- CRITICAL: Zone identity failure: a farmland biome named Famine Fields contains zero visible fields — no tilled plots, no crop rows (living or dead), no furrows, no fences anywhere in the 7168x5120 world; the famine story exists only in micro props (r
- MAJOR: Four stray razor-edged single ground tiles (one grey stone, three tan dirt) float in open grass south of the road's east end — they read as debug/leftover tile stamps and break the fiction.
- MAJOR: No N-S circulation and no connecting paths: the NE hamlet (2350-2640, 620-890), NW farmstead (1363,982), NW tower camp (838,442), and SW barn (1513,1370) all float on bare grass with no worn path linking them to the single E-W road.
- MAJOR: The southern third of the map is a near-empty void — no anchor, no cluster, only isolated tufts and one copy-pasted campfire; the SE quadrant below y1500 is completely empty.
- MAJOR: Ground breakup relies solely on large soft dark vignette blobs over flat olive — no mid-frequency material variation (dirt patches, dry-grass tone shifts, tilled earth), so screen-sized stretches between blobs still read as bare wallpaper.
- MINOR: Copy-paste motif repetition: the identical campfire+3-benches set appears twice ((1103,692) and (1063,1925)) and small identical gravestone rows are stamped at least four times ((1373,647), (3050,347), (798,1790), (1653,1560)).
- MINOR: Road geometry is a dead-straight one-tile-wide strip across the entire map with a single blocky right-angle jog — reads mechanical rather than worn, despite good tan/brown mottling in the texture itself.

## iron_vein — D (wallpaper=True)
one_image: Candidate only: the half-built foundry/mine office at ~x1770-2060,y700-1010 (timber headframe roof, lit smelter pot, barrels, cart, lantern post, signpost, NPC) is the sole deliberate composition — bu
- CRITICAL: The grey road is an untextured flat vector slab (solid fill, razor edges, no pixel-art wear) that overshoots the world rect and hangs ~260px in the out-of-bounds void on BOTH sides.
- CRITICAL: The second road (yellow-tan strip) reads as a pale razor-edged debug strip of randomly recolored square tiles, stops ~100 world px short of the west edge (dead-end in open ground), and degenerates into a crude two-row jog at the east end; s
- CRITICAL: Zero north-south roads: both arteries run east-west in one ~300px band across the middle, leaving the whole north third and south half pathless — any N/S gates are unreached, and the two parallel roads never even connect to each other.
- MAJOR: Wallpaper ground: 17 sampled patches across the full 6656px map all sit within ~8 RGB points of (106,78,57); the slab-tile sheet repeats identically with no macro tonal zones, and despite biome=bog there is no wetness, moss, or mire variati
- MAJOR: Zone identity fails outside one building: biome says bog but there is no water/marsh/reeds anywhere, and 'Iron Vein' is signaled only by the single central foundry — no pits, ore carts, rails, spoil heaps, or slag elsewhere; a random screen
- MAJOR: Confetti not clusters: single tufts, lone rocks, and one-off trees are sprinkled evenly across the whole field, with isolated orphan props (single giant barrel; lone cart) standing alone in open ground.
- MAJOR: Three of four quadrants have only prop-scale set dressing, no true anchor: NE has an arch + coffin doors + barrel, SW a coffin campfire, SE an eight-headstone mini-plot; the only building-scale anchor is the central foundry.
- MINOR: The grey road's lighter inner band terminates in a hard rectangle mid-road and again exactly at both map edges while the dark slab continues — visible layer seams.
- MINOR: Props spawned on the roadbed: trees, brush, and a figure stand directly on the grey road surface, plus grass tufts growing out of the asphalt-like fill.
- MINOR: A tree with its dirt decal is placed entirely outside the world bounds, floating in the grey void at the NW corner.

## copper_wells — D (wallpaper=True)
one_image: CANDIDATE, under-composed: the wells camp west of the crossroads (image ~x1500-1930, y830-1080) — five wellheads, cart, log pile, cauldron, shack, lantern glows, NPCs. Right ingredients for the signat
- CRITICAL: Wallpaper ground: 58% of all map pixels are the single RGB [99,96,14] and the top 8 colors (~78% of pixels) sit within +/-4 units of it — the moor reads as one flat olive field at macro, with only soft vignette smudges for variation.
- CRITICAL: Roads fail gate-to-gate: north end dead-ends in open grass at y=76 (~97 world px short of the top edge), south end dead-ends at y=2098 (~64 world px short of the bottom edge), east end stops at x=3302 (~31 world px short), and the western h
- CRITICAL: Roads read as debug strips: 1-2 tile wide columns/bands of square cells with razor-straight edges for hundreds of px and a mechanical alternating dark-accent-tile pattern — no width jitter, no worn edges, no edge scatter.
- CRITICAL: Anchor-empty quadrants: SW quadrant has no building/monument/pit at all (only two loose tombstone rows); NW quadrant's body is empty except three door-graves in a row — its only substantial content (the wells camp) sits at the exact map cen
- MAJOR: Copy-paste confetti clusters: the identical razor-straight, evenly-spaced row of 5 white cross gravestones is stamped twice (SW and SE), and NW has 3 identical door-grave markers in a perfect row — they read as debug placement rows, not sto
- MAJOR: NE hamlet is undressed: the two cabins stand on bare grass with no yard props, fences, gardens, or path stubs, and no connection to the road 150+ px away — they read as dropped sprites, not homes.
- MAJOR: Stray isolated single tiles floating in open grass near the north road end — one grey stone cell and two brown/tan road cells disconnected from any path.
- MAJOR: A full tree sprite with its shadow renders entirely outside the map rectangle in the grey out-of-bounds padding at the top-left corner — a prop placed at/near origin or negative coords.
- MINOR: Row of pale white/peach square particle dots floating over empty grass with no emitter context — reads as dropped pixels at macro.
- MINOR: The dark tonal blobs are soft structureless vignette smudges that read as screen dirt rather than terrain shading — with the flat ground they are the only macro variation and make the flatness worse.
- MINOR: Zone identity collapses away from the center: any random screen in the west or south fields shows anonymous flat olive moor with a lone bush — nothing copper- or well-related outside the single central camp.

## riverfork — D (wallpaper=True)
one_image: NONE — the closest candidate is the roadside market/farmstead cluster at ~(2280-2450, 920-1040) with its stalls, barrels and well, but it is a loose string along the road with no framing, no focal lig
- CRITICAL: Zone is named Riverfork but contains no river, no water of any kind (programmatic scan of the full map rect found 0 water-hued pixels), and no fork — the single road never branches; the zone's namesake feature simply does not exist.
- CRITICAL: The road is a pale razor-edged debug strip, not a worn path: uniform cold asphalt-grey fill (~RGB 80,73,66), perfectly parallel hard dark outlines ~60px wide, and a misaligned lighter inner-lane overlay that starts and stops with abrupt rec
- CRITICAL: The entire southern ~45% of the zone is dead space: below y~1300 there are no buildings, no roads, no fields — only sprinkled tufts, tree clumps, and two tiny vignettes; SW quadrant's sole feature is a campfire with three coffins, SE's is a
- MAJOR: Wallpaper ground: the whole zone reads as one flat acid-olive field — base color is identical (115,112,18) at every sampled point and regional averages differ by under 2 RGB; the dark blotch decals are too sparse and low-contrast to break i
- MAJOR: The 'farm field' dirt band is a ragged checkerboard of 1-2 tile brown rects with random dark-tile accents that starts abruptly in open grass and dead-ends abruptly in open grass — it reads as tile noise / a broken second road, not tilled fi
- MAJOR: Untextured placeholder squares: flat single-color grey/tan/salmon ~12px squares with zero sprite detail float in open grass near the east gate — they look like raw ColorRects or missing-texture fallbacks and are visible even at macro zoom.
- MAJOR: Copy-paste landmark repetition: the identical stone-arch grave monument (grey arch with brown dirt inset, two flanking stones) appears twice pixel-for-pixel, and the same loose cluster of 5-6 uniform grey blocks repeats in at least three sp
- MINOR: Confetti scatter: micro-props (rocks, tufts, specks, lone saplings) are sprinkled at near-uniform density across all open ground instead of thickening around the story clusters, flattening the composition.
- MINOR: The road geometry extends roughly 250px past the playable rect into the out-of-bounds padding on both the west and east gates, indicating the road polyline endpoints overshoot the zone bounds.

## vetka — D (wallpaper=True)
one_image: Closest candidate: the fenced NE farmstead vignette (thatch cottage + lantern glow + well + hand cart + woodpile + trough, zone_defs deco cluster world 3785-4099,617-710) at image ~(2420-2590, 300-420
- CRITICAL: All three roads are full hard-edged square dirt tiles alternating three tones (pale tan / mid brown / red-brown), reading as a razor-edged checkerboard/barcode debug strip, with single-tile stepping-stone diagonals at the junction.
- CRITICAL: Ground reads as one flat olive color field: 94.7% of the zone is grass with luminance std 2.8 (p5-p95 spread ~5.5 levels); vignette AO blobs are ~5% darker and nearly invisible at macro.
- MAJOR: Road dead-ends in open grass: the NE spur (roads[2] start Vector2(2400,1800)) stops ~100 world px short of Old Marta's cottage, terminating in featureless ground.
- MAJOR: West road fails to reach the zone edge/gate: it starts at world x~96 leaving a visible grass strip to the border, and there are no gate posts or arch marking west_entry, so the road's west end reads as a dead-end near the edge.
- MAJOR: Vast anchorless voids: the far-NW (~40% of the NW quadrant) contains only tree clumps and a smear; the SE-of-SE corner is empty grass with two boars; props+roads cover only 5.3% of the whole 5632x4096 zone.
- MAJOR: Zone identity fails: biome is 'moor' but the screen reads as generic bright-olive grassland with healthy green deciduous trees — no heather, bog pools, peat, scrub, or mist; a random screen answers 'any grass zone', not Vetka.
- MAJOR: The village core does not read as a village: six buildings (chapel, Marta's, shed, Torn's, Dorica's, barn) ring the junction 300-500 image px apart with empty grass between, only two connected by road — reads as randomly dropped houses, not
- MINOR: Quest props render as floating flat rectangles in featureless grass: ledger_tablet reads as a grey UI-icon square and signboard as a maroon block, both unanchored to any path or building — they look like debug placeholders at macro.
- MINOR: Orphan/broken decals: three flat untextured pale squares near the spawn, a solid hard-edged black square by the west road, and a stray grey tile near the west border — all read as missing-texture blocks.
- MINOR: The 'stump' landmark renders as an unreadable pale vertical smear that looks like a paint error at macro (both instances).

## chamber_depths — D (wallpaper=True)
one_image: The south ritual camp at image ~(1930-2015, 1395-1485): campfire, standing brazier, cauldron, dead shrubs, four congregants, gravestone cluster just SE — the only deliberate composition in the zone, b
- CRITICAL: The single road reaches no zone edge: the north end dead-ends in open ground at a lantern-grave ~880 world px below the top edge, the south end stops ~65 world px short of the bottom edge, and there is no east-west road at all — gate-to-gat
- CRITICAL: Wallpaper ground: the entire 4096x4096 floor is one repeating cave-block tile — at macro it reads as a single flat near-black field (ground std ~3/255 excluding glows) with zero regional tonal variation; only the glow pops break it.
- CRITICAL: Zone named Chamber Depths has no chambers: not one cave wall, rock formation, pillar, or stalagmite mass subdivides the plane — the whole zone is a single open void, so no random screen can answer which zone this is beyond generic dark cave
- MAJOR: Road reads as a pale razor-edged debug strip: perfectly straight 2-tile edges with rectangular checker steps, and south of the ritual camp it disintegrates into a dashed confetti of disconnected tan tiles; stray single road/accent tiles flo
- MAJOR: Unreadable placeholder-looking props: thin 1-px pale-blue bezier polylines with tiny anchor sprites arcing across the floor, two rows of semi-transparent grey rectangles flanking the road, and a floating grey lined note sprite — none reads 
- MAJOR: Confetti not clusters: identical tiny pebbles, moss patches, and grass tufts are sprinkled at even intervals across all four quadrants with no grouping logic, while genuine clusters (mushroom groves, gravestone rows) sit isolated among the 
- MAJOR: Anchor-weak quadrants: NW's only anchor is a single lantern-grave and SE's is a 5-gravestone row — neither quadrant has a building/monument/pit-scale anchor (NE has the statue+cairn shrine, SW the obelisk).
- MINOR: A boulder/stalagmite prop sits at the exact world (0,0) corner, clipped by the map boundary and overhanging into the out-of-bounds padding — reads as a default-position spawn bug.

## angel_wings — D (wallpaper=True)
one_image: Closest candidate is the central crossroads plaza at image (1980,1030)-(2280,1200): a grid of six ruined stone plot-foundations, a crumbled pale angel statue at (2113,1048), four drying racks, benches
- CRITICAL: Ground reads as one flat mustard field at macro: measured ground luminance p5-p95 spread is only 76.7-82.0 (about 5/255) over 95 percent of the frame; the only breakup is sub-pixel noise and faint soft smudge blobs that vanish zoomed out.
- CRITICAL: No dirt road reaches any zone edge and every dirt path dead-ends blunt in open grass: horizontal main road stops at x962 (about 1370 world px short of west edge) and at x3196 (about 125 world px short of east edge); vertical path 1 runs (17
- CRITICAL: All roads look like debug strips, not worn paths: dirt roads are 1-tile-wide razor-straight ribbons with a repeating light/dark checkerboard accent-tile alternation, and the grey N-S ribbon is a uniform flat band with a pale center streak, 
- MAJOR: One cabin renders as a near-solid black silhouette at noon while identical neighbors 60px away are fully lit - a modulate/lighting bug or an unreadable burnt-house placeholder.
- MAJOR: Orphan single tiles float detached in open grass at the road's east terminus: a bright salmon square, tan squares, and a grey square - reads as misplaced tileset-index debris.
- MAJOR: Trees are an even sprinkle of isolated singles and pairs across the whole map with almost no copses or woods, and lone cabins drift between hamlets, so the outer field reads as thin confetti over void.
- MAJOR: Anchors crowd the middle band leaving the outer third of the zone anchorless void: west third of NW quadrant, SW quadrant's bottom-left, the entire bottom half of SE, and NE's east half (only a tiny windmill camp) are empty; quadrants techn
- MAJOR: Zone identity is weak: the namesake angel statue is a single tiny crumbled sprite, housing is the same generic cabin set as any farmland zone, and the palette is undifferentiated mustard - a random screen away from the center plaza cannot a
- MINOR: Hamlets cluster correctly but sit on bare flat green with no yards, fences, dirt aprons, or connecting ground story, so each cluster floats.
- MINOR: Clipped sprite fragment bleeds into the map's NW corner from out of bounds, and the NE windmill camp's barrels are arranged in an artificial neat semicircle with no path serving it.

## threadlands — D (wallpaper=True)
one_image: Borderline, not NONE: the dark twin-gable manor with its gravestone row and dead-tree clump at ~x1380,y1280 is the only composed shot in the zone — and it is undercut by an exact duplicate of the same
- CRITICAL: Road network fails gate-to-gate: one lone N-S strip at x~1930 whose ends stop 1-2 tiles short of both map edges (flat dead-end cuts at ~x1930,y80 and ~x1945,y2100), zero E-W road across a 7680px-wide zone, and none of the four settlement si
- CRITICAL: Confetti, not clusters: 1-tile props (wood posts, planks, pebbles, olive bushes, lone graves, ice discs) are sprinkled at near-constant density across the entire open field — every quadrant has the same even static, with only a handful of h
- MAJOR: Wallpaper ground: at macro the snow reads as one flat pale-lavender sheet — the per-tile speckle noise disappears when zoomed out and the faint blue cloud blotches are too low-contrast to register as terrain variation.
- MAJOR: Duplicate anchor asset: the SW and SE quadrant anchors are the identical multi-gable manor sprite, both even dressed with the same gravestone-row motif, destroying landmark-based navigation within the zone.
- MAJOR: NW quadrant has no real anchor: its largest features are a coffin-sled campfire vignette and a knee-high tomb monument — no building/monument/pit at map-readable scale, leaving the quadrant visually empty from zoom-out.
- MAJOR: NE hamlet reads pasted, not lived-in: four houses float on blank snow with no yard paths, fences, woodpiles, or dirt aprons between them, and two of the four are the same A-frame asset.
- MINOR: Road cosmetics: razor-straight edges for hundreds of px broken by abrupt 1-tile staircase jogs (y~250, y~915, y~1140 at x~1930), interior variation is rectangular tile-swatch patches rather than wear, and grey smudge decals overlap the road
- MINOR: Prop repetition breaks biome read: the identical olive-green summer bush sprite repeats 100+ times at uniform size on snow with no snow-dusted variant, and ice ponds are identical small circles scattered as polka dots (e.g. x1970,y860; x305
- MINOR: Orphan gravestone rows float in open field with zero context — no fence, mound, dead tree, or path leading to them.

## listening_steppe — D (wallpaper=True)
one_image: Closest candidate is the SE hamlet at image (2100-2560, 1600-1980): three timber farmhouses, cross gravestones, three framed grave plots, and a small wood to the west. It is the only screen-sized comp
- CRITICAL: Ground is pure wallpaper: 93% of map pixels sit within +/-8 RGB of a single olive base (115,107,13), luminance stddev 5.7, and the only variation is faint airbrushed dark smudges that read as grease stains, not material — zoomed out the zon
- CRITICAL: Road network is one single north-south strip; there is no east-west route at all, the west and east zone edges have zero road connections, and the SE hamlet (the zone's biggest anchor) has no path connecting it to anything.
- MAJOR: The one road reads as a debug strip: razor-edged 2-tile-wide column, perfectly vertical for ~5600 world px with only two 1-tile jogs, wear tiles alternating in a mechanical checker pattern, and it stops short of both edges (starts y=80, 48p
- MAJOR: Confetti scatter: single trees, lone pebbles, and 2-3-tile clumps are dusted at near-uniform spacing across the whole field; genuine woods are rare (only NE diagonal band x2840-3060,y660-870 and SW clump x1270-1440,y1090-1250 qualify) so th
- MAJOR: Zone identity fails the random-screen test: the signature props that sell 'Listening Steppe' (cairn-ringed dark statue, open-grave coffin campfires) exist at only ~4 spots, so roughly 70% of possible screens show nothing but flat olive and 
- MINOR: Three isolated single ground tiles (two tan dirt, one grey stone) float in open grass east of the road's south end — they read as leftover debug or misplaced patch tiles.
- MINOR: A full tree is planted at the exact NW map corner with its canopy overhanging into the out-of-bounds grey padding, sitting on a harsh maroon shadow blob — reads as a default-coordinates (0,0) placement bug.
- MINOR: The NW cabin's roof and porch rail are bright white and read as a snow-covered winter-variant asset, which clashes with the dry mustard steppe biome.

## grey_marches — D (wallpaper=True)
one_image: Midnight gravediggers: a campfire ringed by three freshly dug open coffin-graves with a pink-hooded digger and red-clad mourners, dead trees framing the NE side — img ~(2662,1520), world ~(5400,3640).
- CRITICAL: The single road is a pale razor-edged debug strip: perfectly straight at world y~2560 across the entire 7168px width, 2 tiles tall, with high-contrast dark accent tiles block-tiling into a checkerboard of rectangles, and band-offset seams w
- CRITICAL: Road fails gate-to-gate: it dead-ends in open grass ~100 world px before the west zone edge and ~65 world px before the east edge (ends on a stair-stepped orphan segment), so neither gate approach has road under it.
- CRITICAL: Wallpaper ground: 92% of the zone is one flat olive grass fill; measured macro tonal variation is only ~2% luminance (32px cell-mean std 1.53 on mean 85), so the airbrush smudges and sparse tufts vanish and the whole map reads as a single c
- MAJOR: Zone identity contradiction: 'The Grey Marches' (deadforest) renders as a warm summer pasture — bright olive-green ground plus healthy green-canopy trees mixed among the dead scrub; a random grass-only screen could be any grassland zone.
- MAJOR: Confetti, not clusters: dead-scrub clumps of 2-6 sprites are sprinkled evenly over the whole map (39% of 156-world-px cells occupied, median 13 dark px/cell, no stand larger than ~one screen), so there is no massed woodland and no honest em
- MAJOR: Six orphan placeholder tiles (bare grey and tan 1-tile squares, razor-edged, no context) float in open grass right at the east gate approach — first thing a player sees entering from the east.
- MAJOR: The zone's only building, the chapel, floats ~460 world px north of the road with no spur path, and the lychgate arch stands on the road's south shoulder facing south into open grass with no path through it — both are implied connections th
- MINOR: Gravestone formation is a rigid 3x3 grid of 8 headstones with identical spacing — reads machine-placed, and sits on clean grass with no plot dirt, fence, or path.
- MINOR: Stone vignettes (ruined watchtower + broken column, isolated open-grave plots, mausoleum-door trio) sit on pristine grass with zero grounding — no rubble aprons, ash, or trampled dirt (the chapel's root skirt shows the correct pattern).

## eastern_ridges — D (wallpaper=True)
one_image: Closest candidate: the campfire camp (fire glow + bedrolls) above the white timbered chapel in a birch stand, NE quadrant at ~x2795,y705 / x2640,y815 image px — it is the only deliberate composition, 
- CRITICAL: The only road is a perfectly straight horizontal debug strip: large razor-edged rectangular tile blocks in 3 alternating tan/brown shades (checkerboard read), constant band rows y1056-1103 across the whole 2876px map width, zero curvature, 
- CRITICAL: Ground reads as one flat olive color field at macro: bare-ground std is only ~2.3-3.1 grey levels; the sole breakup is ~15-20 soft airbrushed dark blobs that read as smudge/blur artifacts, not terrain, plus sub-pixel litter that vanishes at
- MAJOR: Road fails gate-to-gate: it dead-ends in open grass 68px short of the west zone edge (starts x539, edge x471) and 35px short of the east edge (ends x3312, edge x3347), and there is no north-south road at all — north and south edges are comp
- MAJOR: SE quadrant has no anchor: its only structures are a small tomb gate hugging the quadrant's extreme NW corner (x2125,y1355) and a 3-gravestone row (x2940,y1680); the remaining ~90% of the quadrant (roughly x2300-3347, y1400-2127) is anchor-
- MAJOR: Zero zone identity: biome is 'ridge' but there is no ridge language anywhere — no elevation banding, cliff lines, rock strata, outcrops, or scree; palette is generic olive meadow indistinguishable from any grassland zone, so a random screen
- MAJOR: Confetti not clusters: trees and boulders are an even sprinkle of single tufts and lone rocks across the whole field; genuine multi-tree stands are rare (chapel ring at x2640,y815, a stand at x3010,y1170, a few on the west edge), and the sp
- MINOR: A full tree is rendered half inside the out-of-bounds grey padding at the map's NW corner, i.e. placed at/above the zone's top edge.
- MINOR: Roadside interest is bunched into one 500px stretch (silo tower, red-roof shrine, cart at x1360-2070 along the road) while the remaining ~2300px of road frontage is bare, amplifying the debug-strip read.

## black_night — D (wallpaper=True)
one_image: NONE as-shot. The only candidate is the great manor at the head of the north avenue (x1917,y671) with the vertical road running to its door — right idea, but it is unframed: the flanking headstone row
- CRITICAL: Capital fails the city test: the entire settlement is ~20 buildings loosely strewn around one crossroads, and 6 of them are the identical large manor sprite placed in mirror-symmetric pairs about the N-S road (x1324/x2500 at y~1131, x1733/x
- CRITICAL: Ground reads as one flat lavender wallpaper: measured 32px-block snow luminance std is 1.9 on a mean of 206 (p5-p95 spread only 203-208); the sole breakup is 1px dither specks and rare pale ice dots that vanish completely at macro zoom.
- MAJOR: Main E-W road dead-ends in open snow at its west end — stops 557 image px (~2200 world px) short of the west map edge with no gate, no terminus POI, nothing at the stub.
- MAJOR: Upper E-W road dead-ends in open field at BOTH ends (connects only to the vertical road), and has a visible ~6px vertical misalignment seam where two straight segments butt together.
- MAJOR: No road serves the north edge — the vertical road stops at the manor (y~680) leaving the entire north third (y33-550) roadless; the main road's east end also stops 59px short of the east edge, finishing with a 1-tile stepped stub instead of
- MAJOR: Confetti sprinkle: ~3,250 tiny (<40px) prop specks — single bushes, stumps, logs, barrels, ice dots — spread at near-uniform density across all quadrants (NW 567 / NE 736 / SE 992 / SW 957) with no honest empty space between clusters.
- MAJOR: Outer ~70% of the map is anchor-free: every building-scale component sits inside x1324-2500, y552-1661; quadrants only pass the anchor test via structures hugging the centerlines, while the periphery offers nothing but tree clumps (x2270,y3
- MINOR: Roads read as razor-edged debug strips: perfectly axis-aligned, uniform ~15px width, hard straight edges, no wear widening at the intersection or at any building door.
- MINOR: Buildings do not address the streets: the row of four large manors floats midway between the two E-W roads, ~130-150px from either, with no yard paths linking doors to a road.
- MINOR: The same 'row of 4-6 headstones' micro-motif is copy-pasted floating in open snow at least five times with no fence, yard, or chapel context.

## bloodstone_pit — D (wallpaper=True)
one_image: YES — the Pit tableau at image ~(1922,807): black void ringed by pale rim-stones, a candelabrum, shrouded mourners and a goat at the south rim, red-robed cultists nearby, bone-white scratch marks radi
- CRITICAL: The single road dead-ends in open ground at BOTH ends — it touches no zone edge (no gate-to-gate) and never reaches the pit, the building, or anything else.
- CRITICAL: Ground is wallpaper: one repeating cobble/boulder tile at uniform hue across the entire 5120px world — at native cave exposure it reads as a single flat near-black field with zero macro breakup.
- MAJOR: Road reads as a pale razor-edged debug strip: one tile wide, high-saturation tan against dark mauve, hard square edges, and ~6 detached placeholder-bright squares floating off-road near its south end.
- MAJOR: Zone identity contradicts its name: 'Bloodstone' Pit has cyan/teal crystal glows and a completely unlit black pit — a random screen reads as a generic ice/moss crystal cave, and the namesake anchor is invisible at game exposure.
- MAJOR: Templated mirror symmetry instead of story clusters: lantern shrines, open-grave shrines, and headstone rows are placed in near-perfect mirror pairs about the map's vertical axis, reading as procedural stamping.
- MAJOR: Dead perimeter bands: the entire east strip and the west half of the SW quadrant are empty tile with nothing but specks; SW quadrant's only anchors are glow blobs and a tiny campfire (no built structure).
- MINOR: Debug-looking NPC parade: two perfectly aligned horizontal rows of ~7 characters each standing beside the road — reads as a spawn lineup left in the level.
- MINOR: Unreadable placeholder mark: two grid-aligned rows of six grey dashes on bare ground near the pit, not identifiable as any prop.
- MINOR: In-world floating text string rendered at the SE campfire camp, baked into the composition shot.
- MINOR: Rock prop placed at the exact NW zone corner, clipping outside the playable rect into the out-of-bounds padding.

## whisper_passes — D (wallpaper=True)
one_image: Closest candidate: the listener watch-camp / murder scene at ~x1763,y617 — campfire glow over three grave plots, twin headstones, and mourner NPCs is the only authored story beat that composes. But it
- CRITICAL: The road renders as a razor-edged debug strip: a checkerboard of full-square light-tan tiles with randomly substituted dark red-brown accent squares, hard 90-degree one-tile jogs, and zero edge blending into grass — the exact 'accent tiles 
- CRITICAL: Ground is wallpaper: prop-free regions measure luminance std 1.9-5.1 with p5-p95 spread of 4-9 levels — one flat olive field; the only breakup is sparse diffuse dark smudges that read as compression artifacts, and there is no second ground 
- MAJOR: Confetti not clusters: trees are a uniform single-tree sprinkle at ~200-400px spacing across the whole map with tiny 4-8px tuft/pebble specks evenly seeded everywhere; only 3-4 incidental copses exist (e.g. x600,y310; x340,y420; x2200,y120)
- MAJOR: Zone identity fails: biome is 'ridge' and the name is 'The Whisper Passes', but the screen shows a flat generic green meadow — no ridge walls, no scree bands, no elevation read, no corridor; the signature props (cairns, stone rows, mossy ro
- MAJOR: Road dead-ends in open grass short of both zone edges: it starts abruptly at x506 (~130 world px of bare grass to the west edge, right at player spawn) and ends at x3346 with a stray half-tile stub jutting south (x3321-3346,y1080-1106), ~98
- MAJOR: Full-size trees are planted on the road: a tree pair at x1295,y1085 and x1313,y1100 stands with trunks at the band's south edge and canopy overlapping the roadway; more canopies clip the band near x2870,y1110.
- MINOR: Untextured placeholder quads sit in open grass by the west gate: a solid grey square at x487,y1027 and solid tan squares at x578,y1032 and x492,y1151 read as unskinned ColorRects floating near the border gap and spawn.
- MINOR: Mechanical set-dressing reads: both stone_rows render as dead-straight, evenly spaced identical pale slabs (rows at x2935,y672 and x2310,y1570); the cold_camp vignette is three identical perfectly aligned grave-plot rectangles (x1188,y532);
- MINOR: SW quadrant anchors are technically present but unreadable at macro: its only anchors are sub-40px monuments (dolmen x1026,y1504; obelisk+cairns x1385,y1848; stone ring x1485,y1794) with no building, so the quadrant reads as near-empty gree

## transcub_vale — D (wallpaper=True)
one_image: NONE. The nearest miss is the roadside woodcutter waystation at image ~(1993,653) — stone hut, log pile, cart, brew cauldron, fence fragment, scarecrow, and three NPCs beside the road — a genuine stor
- CRITICAL: The only road in the zone dead-ends in open grass ~865 world px (17% of zone height) short of the south edge — fails gate-to-gate, and there is no E-W road at all in a 7168px-wide zone.
- CRITICAL: Wallpaper ground: 55.9% of all map pixels are the literal identical RGB (92,94,16) and 93.7% are within +/-8 of it — the ground is one flat olive field; the only 'breakup' is sparse 1-2px specks and soft airbrushed smudge blobs, one of whic
- MAJOR: Road reads as a debug strip: ruler-straight vertical, uniform width, razor edges for its entire ~1700px run, with dark 'wear' squares stamped in a near-checkerboard rhythm; plus orphan single road tiles floating in grass disconnected from t
- MAJOR: Copy-paste anchors: the exact same manor sprite is stamped twice, each with the same statue companion at the same SE offset, and neither manor has any path, yard, fence, or dirt apron connecting it to the road — both float on bare grass.
- MAJOR: SW quadrant has no anchor — its only content is a 4-prop mushroom-cauldron vignette, and the far SW plus the entire south third of the zone is a featureless void; NE quadrant's sole anchor (stone-hut waystation) sits 75px from the quadrant 
- MAJOR: Mechanical prop placement instead of story clusters: five identical headstones in a perfectly straight, evenly spaced row; seven headstones in a rigid grid with no fence, dirt, or path context; elsewhere props are an even sprinkle of lone p
- MAJOR: Zone identity failure: biome is 'ridge' but there is zero ridge signature anywhere — no cliffs, elevation bands, rock faces, or scree; the palette is a single generic meadow green, so any random screen away from the two manors is unidentifi
- MINOR: Road also stops ~98 world px short of the north edge, with loose crate/vendor props scattered in the gap rather than a gate composition.

## lichenreach — D (wallpaper=True)
one_image: Yes, one modest candidate: the north road terminus at img (1920,415) — a lone cross-topped grave over open earth, lit by a hanging lantern, where the road dies into darkness. It is the only framed, de
- CRITICAL: Road fails gate-to-gate: the single N-S road dead-ends in open ground ~600-750 world px short of the north edge (terminus at img x1920,y330-415, at the grave/lantern) and stops ~80 world px short of the south edge (img x1993,y2086); there a
- MAJOR: SW quadrant has zero anchors — only two lichen clusters and pebble/twig litter across a quarter of the map.
- MAJOR: Ground is a single repeating cobble tile over the entire 4096px zone with no tonal variation or secondary material — even inside the lit glow pools (where the floor IS readable in-game) it is bare uniform cobble; no lichen ground-stain unde
- MAJOR: Cluster confetti at the macro scale: ~11 clones of the same lichen-patch motif, same size and same glow radius, spread at near-even spacing across the whole map, with an even sprinkle of single micro-props (pebbles, sprigs, lone skeletons, 
- MINOR: Stray orphan tiles: isolated single pale grey/tan floor tiles floating in open dark ground near the south road, disconnected from any path or structure — read as leftover brush/debug paint.
- MINOR: Glow gap on the road: the southern third (~1100 world px) has no light source at all, while the rest averages one torch per ~800-1000 world px — the south run vanishes at game exposure.
- MINOR: Lichen props are flat square decal tiles (some axis-aligned, some rotated) that read as hard-edged green squares rather than organic growth when lit.

## ashvents — D (wallpaper=True)
one_image: NONE. Closest candidate is the bandit camp at x2700-2780, y1815-1885 (campfire, three bedrolls, one figure), but it is a 4-prop vignette with no backdrop, framing, or landmark — not screenshot-worthy.
- CRITICAL: Ground is one flat grey field across the entire zone; the only 'texture' is a mechanically regular grid of dark tick-marks repeating at sheet period, which reads as a debug/registration grid at macro, plus a few soft fog smudges — zero tona
- CRITICAL: The zone's ONLY road is a single razor-edged vertical strip that fails gate-to-gate at BOTH ends: it stops ~85px short of the north edge (ending amid floating crates) and dead-ends in open ground mid-map with no plaza or anchor; no road tou
- CRITICAL: NW and SW quadrants have no anchor: NW's largest features are two faint campfire glows, SW's are a one-tile obelisk and three grave doors — nothing reads as a building/monument/pit at macro; all structures (two small towers, one bandit camp
- MAJOR: Zone identity fails: for a volcanic zone named 'The Ashvents' exactly ONE small lava fissure with faint glow is visible on the whole map; the rest is grey-olive moorland palette with generic dead trees and green-yellow tufts — a random scre
- MAJOR: Confetti scatter: dead trees, tufts, and rocks are sprinkled at near-uniform density over the entire map with no honest empty ground and no massed story clusters; the few clumps (NW rock pile, SE tree lines) are 3-5 props and dissolve at ma
- MINOR: Stray wrong-biome prop: a full green/red-canopy deciduous tree sits at the extreme NW corner, straddling the map boundary into out-of-bounds padding.
- MINOR: Floating crates north of the road terminus sit ungrounded in open grey with a lone lantern — reads as an unfinished gate camp vignette.

## bloodroad — D (wallpaper=True)
one_image: NONE — closest candidate is the road-side toll post at x1890-2120, y380-560 (round stone watchtower, red tables, brazier, chest, signpost, NPC beside the road); it is the only deliberate composition i
- CRITICAL: Ground is one flat grey field — sampled ground (79,79,76) is within 5 RGB points of the out-of-bounds padding grey (77,77,77), and the only breakup is a tick decal stamped on a strict grid (autocorrelation peaks at 13px and 52px image spaci
- CRITICAL: The zone's namesake and only road dead-ends in open ground at BOTH ends: road spans y83-2087 while ground extends y32-2127, leaving a ~51px gap at the north edge and ~40px gap at the south edge — it reaches neither gate.
- CRITICAL: No east-west road exists anywhere in a 7168px-wide zone (max road pixels in any row: 58, all from the one vertical strip) — the entire west half and east half have zero path network and the E/W edges are unreachable by road.
- CRITICAL: SW quadrant has no anchor — its largest feature is a five-headstone micro patch — and SE quadrant is effectively anchorless too, its largest feature being a single 30px ember pile; both quadrants are ~1500x1000px of sprinkle.
- CRITICAL: Volcanic biome identity is absent: exactly one magma/ember prop exists in the whole zone, no lava flows, fissures, vents, or red rock — the palette (grey ground, mustard bushes, burnt trees) reads as generic ash-blight indistinguishable fro
- MAJOR: The road reads as a pale debug strip: razor-straight vertical edges for ~2000 image px with only two single-tile jogs, bright saddle-brown against grey ground, and 'wear' rendered as full-tile dark square stamps.
- MAJOR: Confetti scatter: single yellow bushes and lone burnt trees sprinkled at near-uniform density across the entire map with no honest empty ground between the few genuine clusters.
- MAJOR: A healthy green leafy tree — the only green foliage in the zone — sits at the exact world origin corner, half-embedded in the out-of-bounds padding, with a hard maroon shadow blob: a prop spawned at default (0,0).
- MAJOR: Every POI floats on untouched wallpaper: the stone house, toll tower, open-grave trio, headstone patch, and bonfire camp all sit directly on bare ground with no dirt apron, yard, fence, or connecting path.
- MINOR: Three open graves are perfectly aligned and evenly spaced in the middle of open nothing — sterile machine arrangement with no supporting context.
- MINOR: Atmosphere smudges are identical soft dark ovals repeated across the map, reading as smudge stamps rather than drifting ash/smoke at macro.

## greyhollow — D (wallpaper=True)
one_image: The Hollow itself: black burial pit at (1917,947) ringed by mourners, flanked by gravestone rows, a fresh grave, an obelisk, and a walled grave-garden grid just south of the crossroads (1810-2170, 880
- CRITICAL: Greyhollow is a capital but reads as a roadside hamlet: ~25 buildings total on one T-junction street, no dense urban core, no walls/plaza/landmark civic mass; 70%+ of the 10240x8192 world is empty grass.
- CRITICAL: Biome is 'port' but there is no port: no sea, harbor, docks, piers, boats or warehouses anywhere; the only water is a ~14px canal-river with nothing built on its banks.
- CRITICAL: The east-west highway is severed by the river with no bridge — road tiles stop at one bank and resume on the other, water flows through the gap.
- CRITICAL: No road reaches any zone edge: west end dead-ends at x=652 (edge 611), east end at x=3188 (edge 3228), south end at y=2087 (edge 2126) — a systematic ~155-world-px shortfall on all three ends, so every gate road dead-ends in open grass.
- CRITICAL: Ground is wallpaper: one flat olive field across the whole world; the only variation is soft airbrushed cloud smudges — zero second ground material (no dirt, moss, sand, rock patches) off-road.
- MAJOR: Roads read as debug strips: perfectly straight, razor-edged, uniform-width tan bands with rectangular tile blotches; the south road degrades into a 1-tile dashed line with orphan road-tile squares floating in open grass beside it.
- MAJOR: A building is planted directly on the highway — the road passes through its footprint (market stall/porch sits mid-road, tiles continue under and past it).
- MAJOR: North half of the zone has no roads at all: both northern anchors (dark manor and the under-construction manor) float in open field with no path connecting them to anything, and there is no north gate road from the crossroads.
- MAJOR: Confetti scatter: orphan 4-9-stone grave clusters and single 1-tile shrubs sprinkled evenly across empty field with no context (no fence, path, or chapel), plus lone glowing lanterns standing in open grass.
- MAJOR: SW cottage row is building-scale confetti: 7 near-identical cottages evenly spaced in a loose grid, 60-200px off the road, none connected by paths, no yards, fences, or clutter between them.
- MAJOR: Dead outer ring: all anchors cluster within ~1000px of the center cross; every far corner is empty grass (SE corner alone is ~620x620 image px containing one 3x3 gravestone grid and a tree clump).
- MINOR: River reads as an engineered canal — uniform width, hard polyline bends, flat streaked water — and its geometry overshoots the world bounds, drawing over the out-of-bounds padding on the west and south.

## canal_maze — D (wallpaper=True)
one_image: Weak candidate only: the road-meets-canal junction at ~(1850-2100, 1060-1260) has four moored rowboats, a signpost with lantern, and NPCs — the zone's one deliberate beat — but with no bridge, no dock
- CRITICAL: Zone is named 'The Canal Maze' but contains exactly ONE straight north-south canal with zero branches, junctions, basins, locks, or dead-end channels — there is no maze, and the port biome reads as generic green meadow everywhere more than 
- CRITICAL: Road network fails gate-to-gate three ways: the E-W road dead-ends into the canal's east bank with no bridge (crossing impossible), it also stops ~64px short of the east map edge, and the entire western half of the zone (1465px wide) has no
- MAJOR: Road reads as a debug strip: perfectly horizontal, constant width, razor-straight top/bottom edges for its full 1350px length, with fill made of tile-quantized checkerboard noise (whole tiles of alternating red-brown/tan) instead of worn-pa
- MAJOR: North-south towpath along the canal's east bank is a single-tile-wide ragged checker strip that starts mid-field (y~370) from nothing and its southern thin-line continuation stops at y~2062 before the bottom edge — two dead-ends in open gro
- MAJOR: Clusters-not-confetti fails: props are an even sprinkle of isolated single bushes/rocks/stumps across the whole field, and gravestones are stamped as neat 5-in-a-row lines in open grass with no fence, church, or context (4 such rows), readi
- MAJOR: SW quadrant anchor is only a single tiny shack + cart + gibbet micro-cluster; the entire western half of the SW quadrant (x453-1200, y1064-2127) and the bottom-left region (~x455-1450, y1900-2127) are empty grass.
- MAJOR: Ground tonal variation at macro comes only from soft-edged blurry dark smudge decals that read like screen dirt/vignette blobs, not material breakup; there is no second ground material anywhere (no mud, sand, cobble, or reed marsh) despite 
- MINOR: Two NPCs are standing inside the canal water surface.
- MINOR: Orphaned tan tile/crate props float in open grass just past the road's abrupt east terminus.
- MINOR: Out-of-bounds render bleed: the canal strip continues past the bottom zone boundary into the grey padding, and a stray tree sprite sits in the padding at the NW corner left of the map edge.
- MINOR: A sail-boat prop sits on a tiny isolated water puddle in the middle of open grass, disconnected from the canal by ~1100px — reads as a misplaced spawn rather than a story beat.

## the_gift — D (wallpaper=True)
one_image: YES, one candidate: twin-gabled gothic chapel with cauldron, grain-sack row, skull on the road and blood smear beside it, image (1560-2000, 850-1200) at map center. It is the only deliberate compositi
- CRITICAL: The zone's only road fails gate-to-gate at BOTH ends: top terminus stops ~120 world px short of the north edge (image y=84 vs edge y=33) and the bottom dead-ends in open ground ~680 world px short of the south edge (terminus at x1920,y1852;
- CRITICAL: Ground is wallpaper: one flat grey-olive field across the entire 7168x5120 zone, with only a mechanically regular per-tile dark speck grid (reads as graph paper at zoom, as nothing at macro) and soft vignette smudges — zero tonal variation,
- CRITICAL: Zone identity fails for biome 'volcanic': no lava, no ember glow, no vents, no volcanic palette anywhere; the only red is four bucket-fill rectangular scoria patches with razor stair-step edges, and they are planted with bright spring-GREEN
- MAJOR: Confetti scatter across the entire western half and far east: single yellow lichen bushes and lone twigs evenly sprinkled with no story clusters and no honest empty space contrast — far NW and far SW quadrant sweeps show pure even sprinkle 
- MAJOR: Anchor distribution collapses to the center column: every anchor (chapel, NE cabin, tower-house pair, monument row, grave/column/campfire) sits between image x1500-2700; the outer west third of NW and SW and the far SE corner have zero buil
- MAJOR: Five orphan road-texture tiles plus one grey stone tile float disconnected in open ground around the road's north end — reads as a road-stamping bug / debug leftovers.
- MINOR: The road is a perfectly straight vertical line for its entire ~4400 world px length with razor edges — surface has checkered dark tiles but the geometry is a debug strip, not a worn path.
- MINOR: A healthy green tree sprite with shadow is placed in the out-of-bounds padding at the map's top-left corner, outside the playable rectangle.

## grey_piers — D (wallpaper=True)
one_image: NONE — the closest fragment is the fishing camp (nets, drying racks, shack, fire glow) at x1010-1440, y1380-1800, but it is diffused over 400px of flat green with no framing; the inn+statue crossroads
- CRITICAL: Zone is named 'The Grey Piers' (biome: port) and contains zero piers, docks, jetties, ships, or harbor structures — the entire sea band is a featureless navy strip and the river bank has only one rowboat and a small camp, so no random scree
- CRITICAL: The road network never touches the water in a port zone: no road reaches the south edge, the shoreline, or the fishing camp, and no bridge/ford crosses the river anywhere along its full width, leaving the entire southern third (fishing camp
- MAJOR: Ground reads as one flat olive wallpaper: a 550x500px open sample puts ~85% of pixels in three near-identical color buckets (mean RGB 83,86,17, luminance SD ~11); the only macro variation is soft dark smudge blobs that read as cloud-shadow 
- MAJOR: Roads read as pale razor-edged debug strips: constant one-tile width (~25 image px), hard straight edges, repeating rectangular checker patches, a ruler-straight 1200px N-S segment, and a hard 90-degree corner where the south branch turns w
- MAJOR: Not a single building connects to the road network — every structure floats in open grass with no spur, yard, or doorstep path.
- MAJOR: Tree/shrub placement is confetti — single small trees and bushes sprinkled at near-uniform density across the whole field with only 2-3 honest groves, and the three SE barns are near-identical sprites evenly spaced in a row (copy-paste rhyt
- MAJOR: Large dead tracts despite each quadrant technically having an anchor: the east half of the NE quadrant holds only a 6-stone micro-graveyard, and the east band between the road and the river is near-empty.
- MINOR: Both west road endpoints stop ~60px short of the map boundary, leaving visible grass gaps that read as dead-ends instead of gates.
- MINOR: Stray orphan road tiles float disconnected in grass near the north gate, and the two fishing-net racks are placed directly on/overlapping the SW roadbed.

## salt_fens — D (wallpaper=True)
one_image: Salt-harvest camp vignette in SW: three salt pans + cart/barrel/cauldron work camp + rowboat on the river, image region x950-1750, y1250-1800. It exists and is the only deliberate composition, but it 
- CRITICAL: No road terminus reaches a zone edge — all three ends stop ~58-60px (≈155 world px) short of the boundary, leaving dead-ends in open mud instead of gates.
- CRITICAL: River is drawn outside zone bounds on BOTH sides, overhanging the out-of-bounds padding by ~215px, with a water-highlight seam exactly at each map edge.
- CRITICAL: The north-south road crosses the river with no bridge or ford — the river ribbon is layered over the road column and the road resumes on the far bank.
- MAJOR: Roads read as pale razor-edged debug strips: constant 1-2 tile width, perfectly straight runs, hard 90° T-junction, and random full dark-brown tiles inserted along the length that read as checkerboard corruption rather than wear.
- MAJOR: NE quadrant has no anchor: nothing but confetti bushes, one rigid 4-headstone row and one lone grave across the entire quadrant; the huge stretch x2900-3347/y100-800 is completely empty.
- MAJOR: Ground is wallpaper: a single mud-plate tile family at one tone covers 100% of the world — measured mean luminance 79.1-79.6 identical in all four quadrants (macro std ~5), and the biome is 'bog' yet there is zero visible wetness besides th
- MAJOR: East half of the map is prop confetti: singleton bushes/tufts at near-even spacing with no cluster-vs-void rhythm (west half shows honest tree stands, so the scatter pass is inconsistent).
- MINOR: A tree with its dirt patch is rendered fully out of bounds, floating in the grey padding above/left of the map rect corner.
- MINOR: Salt pans — the zone's signature prop — are smooth antialiased cream ovals with no crust rim or ground transition, reading as vector clipart pasted on pixel art.
- MINOR: Five stray single-tile orange/grey blocks float unclustered near the west road end, reading as dropped debug tiles attached to nothing.

## dead_timber — D (wallpaper=True)
one_image: NONE — the closest candidate is the wayside shrine (statue + cairn ring) with a wolf pack at the road/path crossing (~1680,1128), but it reads as accidental scatter, not a framed composition; the inte
- CRITICAL: Zone identity fails its own name: 'The Dead Timber' is a bright olive summer-meadow with dead trees as sparse 1-3 sprite specks — no forest mass anywhere, palette reads pasture, not deadforest.
- CRITICAL: The horizontal dirt path is a razor-edged block-tile debug strip (the mapped 'wallpaper stripe' pothole: checkered accent tiles) that dead-ends in open grass at BOTH ends without reaching a gate, and it visually steps/shifts a tile row midw
- CRITICAL: The main diagonal artery is an untextured vector strip — uniform slate fill, razor edges, ambiguous between road and river (wolves, coffins and a campfire stand ON it, yet it has water-like sheen and bank-brown edges) — and it overshoots th
- CRITICAL: SE quadrant has zero anchors — nothing but tree confetti, tufts and pebbles across roughly a quarter of the world.
- MAJOR: Ground reads as one flat olive color field at macro — the dark smudge vignettes are too faint and the tuft/pebble specks vanish when zoomed out.
- MAJOR: Coffin-seller/pyre vignette is placed directly ON the artery — campfire, two laid coffins and a row of three upright coffins block the full band width, and dead trees grow out of the band surface.
- MAJOR: Building/artery collisions and an orphaned wall: the tall barn's left edge sits on the band, and a single floating stone gate/wall fragment with nothing attached sits beside the road.
- MAJOR: Cluster of flat untextured color rectangles (tan/orange/grey placeholder squares) floating in open grass near the dirt path's east dead-end — missing prop textures rendering as raw ColorRects.
- MINOR: No junction treatment where the dirt path crosses the artery — the tile strip just disappears under the band like two pieces of tape.
- MINOR: Central hamlet is loose confetti, not a story cluster: three buildings spaced on bare lawn with a stray fence-with-hay-target and a lone table floating between them.
- MINOR: Stray green tree sprite rendered outside the map rect in the out-of-bounds padding corner.

## drowned_quarter — D (wallpaper=True)
one_image: NONE — closest candidate is the NW inn+cottage pair with lantern glow at img (1450-1780, 300-520), which has genuinely good building art, but it floats on unbroken flat grass with no path, yard, fence
- CRITICAL: Total zone-identity failure: a port zone called 'The Drowned Quarter' reads as sunny inland farmland — the entire 2095px western waterfront has zero docks, piers, ships, nets, warehouses, or flooded ruins, and the shoreline is a hard razor-
- CRITICAL: Wallpaper ground: measured luminance std of 2.5 across the whole map — the ground is one flat olive fill with only faint soft blotches, no readable breakup at macro.
- CRITICAL: Roads do not run gate-to-gate: vertical road spans img y98-2061 against map y32-2127 (66px dead-end in open grass at BOTH top and bottom), and the east road ends at x3320 vs edge x3386 — a consistent ~160-world-px inset at all three termini
- CRITICAL: Road crosses the river with no bridge — road tiles run straight into/under the water band and resume on the far bank.
- CRITICAL: SE quadrant has no anchor: nothing but a stocks/barrels prop row, a campfire glow, and sprinkled bushes across ~1.5M px of empty field.
- MAJOR: The entire west half of the zone has zero roads or paths — the NW inn+cottage, SW black church, and graveyard all float unconnected on bare grass with no route to the T-road or to any gate.
- MAJOR: Road texture reads as a debug strip: razor-edged, perfectly axis-aligned, uniform-width band of checkered square tiles — no wear, no edge feathering, no curvature over its full 1963px run.
- MAJOR: Both water bodies are flat fills: the sea strip is one solid navy rectangle with ~6 tiny ripple ticks over 2095px, the river is a razor-edged two-tone grey band that reads as asphalt highway, and the two use mismatched palettes that overlap
- MAJOR: SW anchor building is a near-black unreadable silhouette sitting on bright green — at macro it reads as a hole in the map rather than a church/warehouse.
- MAJOR: Confetti not clusters: SE and central-south fields are an even sprinkle of single bushes, pebbles, and tufts with no story grouping and no honest empty space between groups.
- MINOR: Stray road-tile confetti floats in open grass beyond the road's north terminus, including one grey stone tile — reads as leaked debug tiles.
- MINOR: Rowboat prop stranded in the middle of a dry grass field ~200px (490 world px) from the nearest water — currently reads as a misplaced prop rather than flood storytelling.

## finalized_fields — D (wallpaper=True)
one_image: Funeral at the crypt, image ~(1690,1090): stone crypt, mourner crowd, flower wreaths, lamp post, cross headstones — genuinely composed scene, but it floats on flat undressed grass ~250px off the road,
- CRITICAL: No road reaches any zone edge — all three terminals stop ~65 image px (~160 world px) short of the boundary, so every gate is visually disconnected.
- CRITICAL: Entire west half of the zone has no road — the network is a T serving only N/S/E, and the east arm is a dead-end stub; the west edge strip is pure grass with no gate.
- MAJOR: Ground reads as one flat olive color field at macro; the only tonal variation is soft blurred dark smudge decals that read as dirt on the lens, not material breakup.
- MAJOR: Copy-paste confetti: eight near-identical 3x3 gravestone plots distributed on a regular ~490px lattice across the zone — the meta-pattern of clusters is itself an even grid.
- MAJOR: SW and SE quadrants have zero anchors — nothing but gravestone plots, tree clumps, and a stray coffin; no building, monument, or pit south of the centerline.
- MAJOR: Roads read as debug strips: razor-straight, uniform 1-tile width, with random full-tile dark-brown squares swapped in as 'noise' that reads as checkerboard corruption at macro, not wear.
- MINOR: Blank pure-white notice board is the highest-contrast object in the zone and reads as an untextured placeholder sprite at macro.
- MINOR: Tree planted exactly at the zone's NW corner with canopy and shadow rendering into out-of-bounds padding — classic prop-at-origin (0,0) placement bug.
- MINOR: Open dug grave with headstone sits directly on the south road blocking the path, flanked by two rows of disconnected grey fence ticks that read as floating dashes.
- MINOR: Orphan single road/debris tiles floating in open grass near the south gate, disconnected from any path.
- MINOR: Rank of six identical cross gravestones in a perfectly straight evenly-spaced line — mechanical repetition readable even at macro.
- MINOR: Lone grey-green slab prop (door/stone?) standing in the middle of the east road with no context.

## morven_reach — D (wallpaper=True)
one_image: The crossroads tavern at ~(2010,1070): half-timbered ruined inn sitting on the 90-degree road corner with a market stall, three NPCs and warm lantern glow — the only deliberate composition in the zone
- CRITICAL: Road network fails gate-to-gate: the only road is one L-shape whose east arm stops at x=3288 in open grass ~60px (≈160 world px) short of the east edge (3347), and whose south arm stops at y≈2065, ~62px short of the south edge (2127), disin
- CRITICAL: Entire west half and all major POIs are roadless: the 5-building NW village (1459-1670, 614-749), the NE ruined manor (2175-2337, 487-575), the SE burnt ruin (2740-3010, 1590-1810), and the white cottage (2660-2712, 405-480) have no path co
- CRITICAL: Zone identity 'port' is invisible: the sea is a featureless flat navy band (x492-605, full height) with a razor-straight vertical shoreline, no sand/mud transition, and not a single pier, dock, ship or waterfront prop along its entire 2095p
- MAJOR: SW quadrant has no anchor: largest features are a lone campfire at (1450,1642) and a stranded cart at (950,1680); no building, monument or pit anywhere in the quadrant.
- MAJOR: Wallpaper: one grass material covers the whole 7680x5632 world; the soft dark tonal blotches that exist are so low-contrast the map reads as a single flat olive field at macro, with no second ground material (dirt, sand, mud, coastal rock) 
- MAJOR: River is uncrossable and seals off the SW wedge: no bridge exists anywhere from the sea junction (528,1480) to the south-edge exit (1650,2120), so all land south-west of the river — including the crate POI at (941,1709) and several tree clu
- MAJOR: Cemetery is a mechanical copy-paste lattice: 12 near-identical gravestones in a perfect 3x4 grid floating on bare grass with no fence, dirt, path or chapel grounding it.
- MAJOR: Road reads as a tiled debug strip, not a worn path: uniform-width pale tan band with full dark-brown tiles checkered in, razor-straight edges broken only by single-tile jogs, and a sharp 90-degree corner at (1955,1105).
- MINOR: White-roofed cottage reads as snow-covered in a green summer meadow — palette mismatch with the port biome.
- MINOR: Orphan wooden deck/dock floor stranded mid-field, connected to nothing, with off-palette saturated cyan pixel specks scattered just above it.
- MINOR: Water-layer placement bugs: a tree stands in the river at (1632-1660,1910-1945); another tree straddles the NW map corner rendered over out-of-bounds padding (466-530, 0-95); a grave-dig POI with a baked-in white selection outline sits on t
- MINOR: River ribbon overlaps the sea band unblended — lighter colour, hard outline, rounded end-cap poking into the grey padding — and shows polygonal elbow joints instead of curves.
- MINOR: Confetti micro-props in open field: two standing coffins alone at (2450-2485,1405-1430), isolated grave-pairs at (902-941,1142-1181) and (2573-2611,1776-1814), and loose stall bits at (1123-1229,1373-1385) — singles with no scene around the

## ledger_roads — D (wallpaper=True)
one_image: Crossroads vignette at img (1680-2350, 950-1350): lantern signpost with gathered NPCs, torch posts along both roads, dark manor hugging the SE corner and a small crypt-and-column ruin NE of it. It is 
- CRITICAL: Roads do not run gate-to-gate: all four road ends stop ~60 image px (~160 world px) short of the zone edge and dead-end in open grass.
- MAJOR: Both roads are perfectly axis-aligned, constant-width (~70 world px) strips with razor-straight edges for their entire run and rectangular darker patch tiles inside — they read as debug strips, not worn paths.
- MAJOR: Ground reads as one flat olive-green field at macro: breakup is limited to sparse 1px tufts and faint soft shadow clouds; no second grass tone, no dirt/litter patches visible zoomed out.
- MAJOR: Anchor duplication: the two quadrant anchor buildings are the exact same twin-gabled manor sprite placed twice, 400 px apart on opposite corners of the same crossroads.
- MAJOR: Grave props are confetti, not clusters: 5 identical headstones in a machine-straight evenly spaced row, a loose 7-stone grid, and 3 identical upright coffins in an even row — all floating on plain grass with no fence, dirt pad, or context.
- MAJOR: Dead outer ring: every anchor sits within ~700 image px of the crossroads; the far NE, deep SW, and SE corners are near-empty grass stretches of roughly 2000x1300 world px each.
- MINOR: Two flat grey list/hamburger icons render in-world as floating UI-grey squares — read as placeholder or debug markers at macro.
- MINOR: Orphan single dirt/stone tiles stranded in grass near the south road terminus, disconnected from the road body.
- MINOR: Neither manor connects to the road: both float on plain grass with no spur path, yard, or threshold wear despite being the zone's main buildings.
- MINOR: The signature glowing open-grave prop is reused verbatim in two quadrants, identical sprite and glow.

## last_hearth — D (wallpaper=True)
one_image: Candidate exists: the great-hall composition at x1810-2060, y870-1220 — longhouse inn with statue behind the roofline (x1930,y880), torches, chickens, angled market stalls, and the big bonfire at x202
- CRITICAL: Road network touches ZERO zone edges: the west arm dead-ends in open grass at x597,y1095 (~190 world px short of the west edge), the south arm stops at x1930,y2054 (~160 world px short of the south edge), and there is no road at all toward 
- MAJOR: Ground reads as wallpaper: empty-region luminance stdev is only 3-4 (measured over SE void and north band), one uniform olive hue with breakup limited to faint same-hue airbrush smudges — and it is generic green grass, not a moor (no heathe
- MAJOR: West housing is grid confetti, not a settlement: six identical chalets in two razor-aligned rows of three (same footprint, roofs recolored grey/red/blue like a variant test sheet), no yards, fences, clutter, or spur paths connecting any hou
- MAJOR: Roughly 40% of the map is contentless olive void: the full-width north band, the deep SE corner, and the east band below the woodcutter camp contain only sparse tree clumps and smudges — vast honest-space with nothing to walk toward.
- MINOR: Five orphan tiles floating in open grass near the west road terminus: four dirt tiles at ~(565,1012), (601,1030), (635,1025), (676,1038) and one lone grey stone tile at (602,1128) — stray tile-painter droppings with no connection to anythin
- MINOR: A tree is placed at the world-origin corner with its canopy rendering into the out-of-bounds padding — classic stray prop at default coords (0,0).
- MINOR: Road texture reads tile-stamped rather than worn: uniform ~2-tile width with a checkerboard of darker squares and perfectly straight edges; also the road ends at the L-junction, so the three east houses (x2150-2430,y1050-1300) and the marke
- MINOR: Two satellite clusters float unanchored: the NW stone chapel stands alone in blank grass with no approach path, and the SE 'graveyard' is just five gravestones in a tight unfenced clump with no path — both read as dropped props rather than 

## coldharbor_deep — D (wallpaper=True)
one_image: Central camp at image x1830-2130, y1000-1160: road terminus into a bonfire with a skeleton/cultist congregation, stone well (1984,984), gravestone row and dead tree beside it. It is the only deliberat
- CRITICAL: Road network fails gate-to-gate: the only road (x1920-1952) runs y114-1145, stops ~160 world px short of the north edge, dead-ends at the central camp, and no road exists to the south, east, or west edges — the whole south half of the zone 
- CRITICAL: NW quadrant (x861-1912, y31-1081) has no anchor — only two mushroom prop clusters and a lone roadside torch (1789,729); SE quadrant is nearly as empty, its largest feature being three coffins (2111,1770) and four gravestones (1944,1669).
- MAJOR: Road reads as a pale razor-edged debug strip: perfectly straight for 1000+ px, hard vertical edges, extreme contrast against the near-black floor, brick-red wrong-material squares embedded in it, plus orphan disconnected road tiles floating
- MAJOR: Wallpaper failure: outside glow radii the entire floor is a single repeating cobble tile with zero macro tonal variation — the raw screenshot ground is one flat near-black field, and even brightened there is no second material or large-scal
- MAJOR: No cave enclosure at all: not one rock-wall mass, stalagmite field, or chasm — the open floor runs flat to all four map edges, so at macro the zone reads as an empty dark plane rather than a cavern, and zone identity is unanswerable on most
- MAJOR: Confetti between clusters: singleton props (lone rocks, single scree decals, lone skeletons, floating scroll/note icons e.g. (2202,850)) are evenly peppered across the field with no story grouping.
- MINOR: Glow distribution is formulaic: six teal mushroom clusters are all the same size (4-6 caps) and identical halo radius, spaced one-per-region like a grid — reads as even sprinkle at cluster scale.
- MINOR: Debug-looking artifact: a 2-row x 7-column grid of identical tiny pale ticks sits beside the road, evenly spaced — reads as a spawn-marker array, not a prop.
- MINOR: Razor-straight prop rows: five identical evenly-spaced gravestones in one line, a dead-straight horizontal bone-scatter line at the campfire, and three identical coffins in a row.
- MINOR: Glow without subject: the large warm halo south of center contains only a tiny torch and two skeletons, and the mid-road halo is a lone torch — big light pops promising content that is not there.

## The — D (wallpaper=True)
one_image: YES, one genuine composition: the firelit burial scene at x1026,y690 (NW) — bonfire, two freshly dug open graves at skewed angles, a corpse laid in a third, torch, and two mourner NPCs. It is the only
- CRITICAL: The zone's only road is an L-shape that dead-ends in open grass at BOTH termini and touches no map edge: pixel scan of all four edge strips found zero road pixels; the west arm stops at x~519,y~1145 (~66 img px / ~160 world px short of the 
- CRITICAL: Zero zone identity: a zone named 'The Orange Fog' shows no orange and no fog anywhere — the whole map is generic olive-green meadow (base RGB 94,94,16) with faint dark-olive smudges; a random screen is indistinguishable from any grassland z
- CRITICAL: Wallpaper ground: one exact pixel value (94,94,16) covers 52.9% of the map and 91.3% of all pixels fall inside a single narrow olive bucket; the only variation is sparse soft dark smudges and tiny tufts, so at macro the ground reads as one 
- MAJOR: Road reads as a pale razor-edged debug strip: both arms have perfectly straight edges with zero raggedness, and the 'wear' is full-tile dark-brown squares dropped in a checker pattern along the strip.
- MAJOR: Stray untextured placeholder squares floating alone in open grass near the road's west stub: a solid flat grey square and solid flat tan squares with no texture or outline (read as raw ColorRects), plus a large blank-white notice-board face
- MAJOR: Repeated-stamp confetti: the identical glowing lone-grave composite (headstone + framed dirt plot + warm halo) is stamped at least 5 times evenly across the zone, and the SE cemetery is a sterile 3x2 grid of 6 headstones floating on bare gr
- MAJOR: Anchor gaps and dead space: NE quadrant has no building/monument at all (its only anchors are the grave stamps), and huge regions are empty flat green — the full-width south band, the SE corner, and the SW corner contain no anchor or cluste
- MINOR: Deadforest biome with almost no forest: roughly 30 small dead-tree clumps across the entire 7168x5120 zone (non-ground coverage 2.5-5.6% per quadrant, much of that smudges); the tree clumps that exist do cluster honestly, but density is a h
- MINOR: Thin pale-blue curved lines with small stake sprites radiate around the SE arch; at 1:1 they read as unfinished Line2D debug primitives rather than webs/wards.

## anchorfall — D (wallpaper=True)
one_image: NONE — closest candidate is the SE manor + stone turret + lit lantern grouping (x2385-2660, y1395-1620), but it floats on blank grey ground with no path, no framing props, and no volcanic dressing; th
- CRITICAL: Ground is a single flat grey field: sampled empty patches average RGB (78,77,75) with std ~4-5, statistically indistinguishable from the out-of-bounds padding grey (77,77,77), so at macro the playable map dissolves into the void; the only g
- CRITICAL: Road system fails every road law: the only road is one L-shaped bright-ochre razor-edged strip with checkerboard dark patches (debug-strip look) that dead-ends ~65px (~160 world px) short of BOTH the north edge (strip ends y=97, edge y=32) 
- CRITICAL: Volcanic biome identity does not read: neutral grey ground, cold NAVY BLUE canal and sea along the south, and a lush green deciduous tree at the NW corner; the only volcanic tells on the whole 7168x5120 map are one ~40px lava well (995,645)
- MAJOR: South canal/sea geometry is broken: the canal ribbon overflows the zone bounds on BOTH sides (west end cap at x~220, east end cap at x~3510, zone edges x453/x3386), renders as a razor-edged ribbon with a straight pale center stripe like a h
- MAJOR: Debug-grid placement: two perfect ranks of 6 NPCs each standing in formation in open ground, directly below a rigid 2-column gravestone grid; elsewhere a ruler-straight row of 7 identical cross gravestones and a 3x3 gravestone block — spawn
- MAJOR: The SW pit anchor is unfinished: a solid pure-black ellipse with a slightly lighter inner ellipse and a rim of identical evenly-spaced pebbles — no depth shading, no lava/ember glow despite the volcanic biome, no scorch ring or debris; read
- MAJOR: Confetti not clusters: outside the four building spots, all props (sulfur tufts, dead trees, pebbles) are an even low-density sprinkle across the whole field, and the buildings themselves float on bare ground with no yards, fences, paths, o
- MAJOR: Anchor variety is fake: the two NE houses are the same sprite placed twice, the two SE manors are the same sprite placed twice, and the large SE tower renders as a near-black unreadable silhouette at macro.
- MINOR: Weak/absent anchors in two areas: the NW quadrant's only anchors are knee-high grave props (largest monument x1160-1220 y510-570, small mausoleum x1285-1345 y815-880) with no built structure, and the inside-east band is a dead field with no
- MINOR: Out-of-bounds prop: a lush green tree sits in the padding above/left of the NW map corner, half outside the playable rect (also the only green-canopy tree on a volcanic map).
- MINOR: Stray white UI/debug glyph (small rectangle with lines, like a list/scroll icon) floats in open ground with no owner prop.

## wilderness — D (wallpaper=True)
one_image: The goblin camp at x2400-2980, y1420-1900: five striped canopies ringing a dark cobbled fire-square with twin campfires, brick piles, and ~8 goblin figures — a deliberate, readable composition with gl
- CRITICAL: The entire road network is an axis-aligned debug grid of pale razor-edged stone slabs — four hard 90-degree corners forming a pointless rectilinear zigzag through the forest, with several segments rendered as checkerboard half-alpha tiles t
- CRITICAL: Roads do not run gate-to-gate: no road touches the north or south zone edges at all (solid tree wall the full width), and the east arm dead-stops in open grass roughly one tile short of the east edge with no gate object.
- MAJOR: West gate is not integrated: the stone gatehouse arch opens onto plain grass while the road runs parallel BEHIND the wall and never passes under the arch, and the wall fragment terminates in a raw vertical brick slice.
- MAJOR: Wallpaper ground: every open clearing reads as one flat olive field at macro — breakup is limited to 1-2px grass tufts and rare flowers, invisible zoomed out.
- MAJOR: Tree confetti: roughly two-thirds of the map is a uniform-density carpet of one leafy tree sprite with twisted dead trees sprinkled at near-even spacing — even sprinkle, no story clusters, no shaped groves or honest gaps.
- MAJOR: Zone-identity conflict: both camps use identical pristine town-market stall canopies (bright green-white and red-white stripes — the most saturated pixels on the map), so the goblin raider camp and the wilds waypoint camp both read as a vil
- MINOR: Road stub approaching the goblin camp dead-stops in open grass ~85px before the camp's cobble fire-square — a dead-end short of its destination.
- MINOR: Stray render artifact: a perfectly straight 1px bright yellow-green vertical line ~75px tall floating over grass beside a twisted tree.
- MINOR: Anchor distribution is edge-hugging: SW quadrant's only anchors (gate, ruin floor) sit on its northern boundary, leaving the entire bottom band and the far-NW block as featureless forest oceans; the ruin itself is floor-only rubble that rea

## gravemark_tundra — F (wallpaper=True)
one_image: Campfire ringed by coffins with two figures and a warm glow at (3075,1760) — the only deliberate composition in the zone, but it is tiny, unconnected to any path, and floats in blank snow.
- CRITICAL: The zone's single road dead-ends in open snow mid-map — it stops at x2677,y1095, roughly 24% of the map width short of the east edge, and no road exists to the north, south, or east edges at all.
- CRITICAL: Confetti not clusters: single dead trees, stumps, moss bushes, pebbles, and ice discs are sprinkled at near-uniform density across the entire 7168x5120 field with no grouping rhythm and no honest empty space between story beats.
- CRITICAL: Wallpaper ground: the tundra reads as one flat pale-lavender field at macro; the only texture is a fine dot-speckle that vanishes when zoomed out, with no drifts, ice sheets, or exposed-earth patches breaking the field.
- MAJOR: NE quadrant has no anchor — nothing larger than a 5-headstone row, a small grave grid, and a birdbath; no building, monument, or pit.
- MAJOR: Road reads as a debug strip, not a worn path: perfectly straight, razor-edged, uniform ~66-world-px width for its full length, built from rectangular dirt tiles with harsh maroon blocks, plus visible segment mis-steps where the strip jumps 
- MAJOR: Zone contains exactly one building — a lone cabin floating in blank snow with no path, yard, or fence — so three of four quadrants have no built structure and the zone has no settlement-scale focal point.
- MINOR: Two orphaned rectangles of road material float in open snow above the road's west start, disconnected from anything.
- MINOR: A summer-green leafy tree sits outside the map rectangle on the grey out-of-bounds padding at the NW corner — wrong biome palette and outside the playfield, likely a prop placed at/near world (0,0).
- MINOR: Ice ponds are identical perfect light-blue circles (~30 world px) scattered as confetti across the map, reading as debug dots rather than frozen pools.

## blestem — F (wallpaper=True)
one_image: NONE that is composed. Closest candidates: the black tower beside the crossroads at (2010,860) — the only prop with real silhouette presence, but it floats in blank grass off the road with no framed a
- CRITICAL: No road reaches any zone edge — the entire network (3 horizontal strips + 1 vertical) floats in the interior with six dead-end termini in open ground, so gate-to-gate is failed at every gate.
- CRITICAL: Wallpaper ground: 91.5% of the zone is within ~6 RGB of a single navy color (31,30,52); per-quadrant std is 2.5–6.5, and the only 'texture' is a uniform dark tick stamped on a visible regular grid, which reads as tiling artifact, not breaku
- CRITICAL: Blestem is a capital but reads as a one-street hamlet: the entire 'urban core' is a single row of ~7 rowhouses on one side of one road plus a dark gateway; no second street, no plaza, no density gradient, and every other building in the zon
- MAJOR: The same twin-gable U-shaped house cluster is copy-pasted ~12 times at identical orientation, evenly sprinkled across the mid band — confetti at cluster scale — and none of the outlying instances connects to the road network (no path, yard,
- MAJOR: The eastern quarter of the zone (~24% of its width, full height) contains zero anchors — only stray tree tufts on blank ground; the S third of SW (below y~1600) and the NW corner are similarly void.
- MAJOR: Roads are 1-tile-wide, razor-edged, axis-aligned strips with square corners and single-tile 90-degree jogs; the western end even leaves floating orphan road tiles disconnected in the grass.
- MINOR: The zone's best vignette — campfire with three benches and figures — is marooned ~500px from anything, and the black tower landmark sits offset in blank grass beside (not fronting) the vertical road, so neither composes into a deliberate im
- MINOR: A stray tree prop bleeds over the zone boundary into out-of-bounds padding at the top-left corner.

## basaltfang — F (wallpaper=True)
one_image: NONE — the closest candidate is the stone watchtower + covered wagon + signpost camp at (1840,760), but it is a single small cluster with no framing, no ground treatment, and empty flat grey in every 
- CRITICAL: Ground is one flat grey-olive field across the entire map; the only 'texture' is a tick-mark detail pattern repeating in perfect tile-grid alignment plus a few soft smudge decals — no second ground material, no ash fields, no basalt patches
- CRITICAL: The zone's only road is a ruler-straight, single-tile-wide N-S strip with razor edges and random dark checker tiles that reads as a debug strip, and it reaches NEITHER gate: it starts at y~80 (map top edge is y~28) and dead-ends at y~2094 w
- CRITICAL: Zone identity fails completely: a zone named Basaltfang Range (volcanic biome) shows zero lava, zero basalt formations, no vents, no ash fields, and no elevation/ridge read at macro — the only volcanic tell is one tiny ember pile — while of
- MAJOR: No east-west road and no spur paths at all: every anchor (watchtower camp, cottage, chapel/tower, coffin camps) floats unconnected in open ground — the cottage sits ~420px from the road with nothing linking it — and the E and W zone edges a
- MAJOR: Confetti scatter: yellow moss/sulfur blobs, pebbles, and small dead scrub are sprinkled at near-uniform density over the whole map with almost no honest clusters and no deliberate empty ground between them.
- MAJOR: SE quadrant has no anchor — its only feature is three upright display coffins floating context-free in open ground — and SW's only anchor is a small campfire-and-coffins camp with no structure.
- MINOR: A stray full-canopy tree renders in the out-of-bounds padding at the map's NW corner, outside the world rectangle, with a broken hard-edged dark-maroon rectangle for a shadow — looks like an origin-spawn/off-by-one placement bug.
- MINOR: A flat grey untextured placeholder square tile sits in open ground near the north road head.

## sangeroasa — F (wallpaper=True)
one_image: NONE that is currently screenshot-worthy. The only deliberate composition is the road S-bending around the black chasm below the village strip (pit at ~x1916,y797, curve x1870-2010,y700-950) — right i
- CRITICAL: Capital fails the city test: the entire 'urban core' is ~12 buildings in a single-file strip hugging the north road (with sprites overlapping/stacking into each other) plus a 4-hut glow hamlet — it reads as a roadside hamlet, not a capital;
- CRITICAL: Road network dead-ends on 3 of 4 arms — only the north arm reaches a zone edge, so the capital has effectively one gate; south, east and west arms all terminate in bare open ground.
- CRITICAL: Wallpaper failure: ground reads as one murky grey-brown field at macro; the only per-tile 'texture' is a mechanical evenly-spaced dot-grid pattern (dot columns ~30px apart, visible in every 1:1 crop) plus soft fog blotches — zero volcanic g
- MAJOR: Roads read as debug strips, not worn paths: uniform ~1-tile orange-brown ribbon with razor edges, a perfectly straight ~1300px horizontal run, and stair-step 90-degree corners; no width variation, no edge dithering, no wear.
- MAJOR: Zone identity fails: nothing on screen says 'volcanic' or 'Sangeroasa' — palette is undifferentiated mud-brown, signature landforms absent; a random screen anywhere outside x1800-2400/y200-1100 is an anonymous brown void indistinguishable f
- MAJOR: Confetti, not clusters: SW huts are one-building islands evenly spread with no yards, fences, or path spurs; an unanchored 8-stone micro-graveyard floats in the void with no path to it; debris/speck props are sprinkled at even density acros
- MAJOR: Outer ring is dead space: NE and SE quadrant anchors hug the center meridian (nothing east of x~2400 except campfire glows), so the eastern third and the southern band — roughly 40% of the zone — are empty wallpaper with no anchor, road, or
- MINOR: West road stub terminates at destination-less furniture — a campfire and two benches mark the end of a road that goes nowhere, advertising the dead-end.

## the_archive — F (wallpaper=True)
one_image: Closest candidate: the manor complex at x1650-2260, y260-1000 — five manors around a snow-dusted checkerboard plaza with four torch glows and a glowing shrine door at (2020,395). It is the only delibe
- CRITICAL: Roads fail gate-to-gate 0/4: a full-map scan finds exactly one road in the entire 10240x8192 capital, a vertical strip at x1920-1935 running y1080-2085, touching no map edge; N, E and W edges have no road at all.
- CRITICAL: Road dead-ends in open snow at both ends: north tip stops at (1930,1080) beside a lamppost/signpost ~100px south of the manor complex (which has zero road connection), and the south tip stops at (1927,2085), ~40 image px (~160 world px) sho
- CRITICAL: Capital does not read as a city: The Archive shows only ~20 buildings strung in a single-building-wide north-south line (6-manor complex + one strip village straddling the road); no street grid, no dense block core, no walls or districts — 
- CRITICAL: Wallpaper ground: 97% of the map is bare ground with luminance sd ~5 on mean 199 (~2.5% contrast) — at macro it reads as one flat pale-lavender field edge to edge; the only breakup is sub-pixel dither speckle and faint cloud shading, no dri
- MAJOR: Confetti scatter: 1-3px props (twigs, pebbles, olive tufts, small ice discs) are sprinkled at near-uniform density across the whole field, including between and around the few honest tree clumps (e.g. clusters near (1725,205), (1610,995), (
- MAJOR: Anchor void in NE quadrant: east of x~2570 there is nothing but confetti for the entire quadrant height — the NE's only anchors (small chapel with cross-graves at (2415,780), lamp scene at (2385,790)) hug the center column; far-west NW (x61
- MAJOR: Road is a razor-edged debug strip with a misalignment bug: constant ~8 image px (~31 world px) width with dead-straight vertical edges for ~1000 image px, and at y1400-1410 the whole strip jogs one full road-width west (x1928-1935 above, x1
- MAJOR: Stamped duplicate prop set: an identical ~8-stone graveyard mini-grid is copy-pasted at four near-mirror positions around the road ((1478,1200), (2350,1170), (1490,1475), (2355,1440)) plus mirrored 6-stone rows inside the manor complex — re
- MINOR: Zone identity is generic tundra, not 'Archive': no macro-readable signature props (great library mass, shelf yards, scriptorium, scroll carts); dominant signatures are graveyard grids, which read as a cemetery zone; palette alone cannot dis
- MINOR: Twelve villagers stand in two perfect rows of six straddling the road — reads as an undispersed NPC spawn grid at macro scale.
- MINOR: South-town east column has buildings stacked single-file with rooflines interpenetrating (large manor's base merges into the building below), no yards or gaps between footprints.