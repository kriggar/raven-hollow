# THE LEVEL-PAINTING BIBLE — Fable's doctrine, encoded (owner priority #1)

This is how Raven Hollow levels are painted. Every rule below was earned in
production (sittings #1-#3, Batches A-G). The studio's level_painter role is
primed with this file; its output is a DRAFT for Fable's hand (visual law).

## I. THE READ — what a screen must do
1. **40-second rule**: from any point, something worth walking to is visible
   within one screen-width. Emptiness is a defect, not a mood. Mood comes
   from WHAT fills the space, not absence.
2. **Zone identity in one screen**: any random screenshot must answer "which
   zone is this?" — via palette, signature prop (threads/vents/lichen/red
   soil), and weather. If a screen could be any zone, it fails.
3. **Witchbrook bar**: layered density — ground breakup + mid props +
   verticals + light + motion (sway/smoke/particles) in every composition.

## II. COMPOSITION — how to place
4. **Story clusters, not confetti**: place landmarks in groups of 3-7 that
   tell ONE story (a camp = fire + bedrolls + rack + prints; a shrine =
   stone + offerings + kneeling-worn ground). Never sprinkle singles evenly
   — even spacing reads as generated. Cluster tightly (60-300px), then leave
   honest travel space between clusters.
5. **Roads are the spine**: content hangs off roads at varied depths
   (20-600px). Nothing sits ON the road; keep 60px clear of slab edges.
   Roads run gate-to-gate — a road must never begin or end in open ground.
6. **Face the camera's truth**: this is top-down 3/4. Tall things read best
   NORTH of open space; never put a tall prop 0-80px south of a small one
   (occlusion soup). Y-sort handles overlap but composition must not rely
   on it.
7. **Rule of anchors**: every quadrant of a zone gets ≥1 anchor (building,
   monument, vent, pit). Anchors get satellites (2-5 small props) and, if
   inhabited, light.
8. **Asymmetry law**: grids and perfect rows are reserved for MEANING (the
   Archive files, the Finalized rows, rows-of-twelve). Everything organic
   must jitter: position ±rng, scale 0.85-1.2, rotation for decals only
   (never rotate architecture).

## III. GROUND — the canvas itself
9. **No wallpaper**: ground sheets must be uniform fills; any accent tile in
   a block-tiled sheet becomes a visible stripe grid. Accents are placed as
   scattered DECALS (alpha 0.35-0.7, z below props), 1 per ~200k px².
10. **Edges are seams**: every material transition (road/grass, water/bank,
    soil/field) gets a blending pass — tufts, pebbles, stains straddling
    the line at ~20-30% frequency. A razor edge is a defect.
11. **Keep-clear is sacred**: ponds, roads, landmark footprints register
    keep-clear rects. Nothing spawns inside another thing's footprint.
    Min distances: pond-pond 420px, building-building 180px (unless a
    deliberate packed district), monument-monument 220px.

## IV. LIGHT & MOTION — the life pass
12. Every inhabited cluster: ≥1 light source with a VISIBLE emitter (lamp,
    fire, forge, window). A light with no emitter sprite is a defect
    (the floating-glow class). Uninhabited dread zones: light comes only
    from canon sources (live stones orange, lichen teal, vents ember).
13. Motion quota per screen: ≥2 of {tree sway, smoke, particles, water
    sheen, animated prop}. Static screens read dead.
14. Ambient discipline: cold zones carry a cool bias; caves are dark with
    glow pops; locked-ambient cities (Blestem dusk, Sangeroasa forge-haze)
    never break their hour.

## V. STORY — the Fable layer (drafts must attempt it; Fable perfects it)
15. Per zone: ≥2 curiosity sites (something that makes the player walk over:
    a ring of cairns, one living tree, a door in a hill) and ≥1 murder/crime
    scene (stain + remains + drag-marks + the dropped thing). All derived
    from zone canon — grep the lore extract first.
16. **The one image**: each zone needs one composition the player will
    screenshot (the Pit ringed by clerks; boot-prints ending at the edge;
    the grave out of line). Design it deliberately; give it space and light.
17. Vignettes never explain themselves. No signs saying "massacre here".
    The scene IS the sentence.

## VI. ASSETS — sourcing law
18. VERIFIED FREE ONLY: read the license text on the page; commercial-ok;
    evidence quoted in the manifest. Name-your-price at $0 counts. No
    unclear-license or NC-only packs, ever.
19. Style gate before use: ~32px top-down painterly-pixel, muted gothic
    palette. Recolor toward palette with modulate, never palette-swap
    spell/creature art (illegal per mandate).
20. Extraction discipline: crop → alpha-trim → assets/art/world/<biome>/,
    then `godot --headless --import` BEFORE use; re-import after rewrites.

## VII-A. LEARNED — Academy 2026-07-11, Fable-gated (sources in LEARNED_PRINCIPLES_DRAFT_2026-07-11.md)
22. **One hue family per zone, one reserved accent.** Zone palettes live in a
    single family; exactly one complementary accent is reserved for lights and
    story props. Never two accent hues in one screen. (Darkest Dungeon)
23. **No dead grey, no pure black in fills.** Warm every dark toward parchment
    (~(0.07,0.05,0.03) floor); the anchor sheet reads "old manuscript", not
    concrete. Desaturate the GROUND, never the actors — interactables/NPCs keep
    saturation so they pop off the muted field. (D2/D3 lesson)
24. **Zone identity = grading shared assets, not new assets.** Distinct
    (day tint, dusk_tint) pairs per biome; DAY stays warm even in gothic zones;
    hue-shift light colors per biome (copper in Iron Vein, teal in caves).
    (Graveyard Keeper LUT method)
25. **Ban the straight road.** Every road polyline gets ≥3 interior waypoints,
    ±80-160px lateral offsets, 20-40° kinks every 400-700px; wide gentle bends
    in safe biomes, sharp bends in hostile ones. Tease: the next landmark is
    glimpsed 15-20s before the road delivers it.
26. **Light is a promise — sun plus 3.** Lights attach only to what canonically
    burns; at night the light set == the interaction set; ~one warm light per
    screen, never >4; dead vignettes get NO light — the unlit hearth IS the
    beat.
27. **Tangent ban + slot grammar.** Sprites overlap >25% or separate >20px —
    never kiss. Dress hub perimeters in L-shapes at corners, pairs flanking
    entrances; never rows through the middle.
28. **Negative space is a placed asset.** One authored quiet-quarter per zone
    (breakup + sway + weather only) so clusters never tile wall-to-wall.
29. **POI diversity rotation.** Never two same-type set-pieces consecutively
    along a road; rotate habitation → ritual → nature → wreckage.
30. **Breadcrumb the approach.** 3-5 instances of one lore-themed prop at
    150-250px intervals flanking the last road segment before each landmark.
31. **Density is a gradient.** Sparser near hubs (~0.2x), 1.0 mid-zone,
    1.4-1.6x at the wild outer ring; vegetation walls ring clearings.
Engineering follow-ups (not composition rules): ground/road TileMapLayers never
y-sorted; MultiMesh for tuft fields; dual-grid edge blending; cloud-shadow
multiply layer; seasonal palette layers. → BACKLOG.

## VII. VERIFICATION — no claim without eyes
21. Boot the zone, screenshot the money spots, LOOK at them. Run the
    40-second validator (prints on boot) and the seam validator. A pass you
    didn't look at is not a pass.
